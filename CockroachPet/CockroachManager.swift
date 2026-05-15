import AppKit
import SwiftUI

/// Central manager for all cockroaches — spawning, killing, persistence, animation loop.
class CockroachManager: ObservableObject {
    static let shared = CockroachManager()

    @Published var cockroaches: [Cockroach] = []
    @Published var exterminatorMode: Bool = false

    private var windows: [UUID: CockroachWindow] = [:]
    private var timer: Timer?
    private var lastUpdateTime: TimeInterval = 0
    private let mouseTracker = MouseTracker()
    private var clipboardTimer: Timer?
    private var lastClipboardCount: Int = 0
    private var nightSpawnAccumulator: TimeInterval = 0

    private init() {
        startAnimationLoop()
    }

    // MARK: - Animation Loop

    private func startAnimationLoop() {
        // Use a Timer at ~60fps for the main update loop
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = now - lastUpdateTime
        lastUpdateTime = now

        let screenBounds = NSScreen.main?.visibleFrame ?? .zero
        let mousePos = mouseTracker.position
        let mouseSpeed = mouseTracker.speed

        var toRemove: [UUID] = []

        for cockroach in cockroaches {
            cockroach.update(dt: dt, mousePosition: mousePos, mouseSpeed: mouseSpeed, screenBounds: screenBounds)

            // Update window position + cursor-based hit test.
            if let window = windows[cockroach.id] {
                window.updatePosition()

                // The cockroach window is `size * 3` large to leave room for
                // animations, but most of it is transparent. Without this
                // gate, clicking that transparent halo would still hit the
                // window and block underlying apps. Toggle click-through
                // every tick based on cursor proximity to the actual bug.
                let dxw = mousePos.x - cockroach.position.x
                let dyw = mousePos.y - cockroach.position.y
                let cursorDist = hypot(dxw, dyw)
                let hitRadius = cockroach.size * 0.5 + 8
                let onCockroach = cursorDist <= hitRadius
                // Keep events active while being dragged so the drag doesn't
                // drop if the cursor wobbles past the radius for one frame.
                let inDrag = cockroach.state == .dragged
                window.ignoresMouseEvents = !(onCockroach || inDrag)
            }

            // Trigger fear scatter on first frame of dying
            if cockroach.state == .dying && cockroach.stateTimer < 0.02 {
                fearScatter(near: cockroach.position)
            }

            // Remove dead cockroaches
            if cockroach.state == .dead {
                toRemove.append(cockroach.id)
            }
        }

        // Update poop particles
        PoopManager.shared.update(cockroaches: cockroaches)

        for id in toRemove {
            removeCockroach(id: id)
        }

        updateNightAutoSpawn(dt: dt)

        // Advance / clean up the feeding cake.
        CakeManager.shared.update()
    }

    /// While red eye / night mode is active, push out a new cockroach from a
    /// random screen edge every `nightAutoSpawnInterval` seconds.
    private func updateNightAutoSpawn(dt: TimeInterval) {
        guard ActiveBuffs.redEyesVisible else {
            nightSpawnAccumulator = 0
            return
        }
        nightSpawnAccumulator += dt
        if nightSpawnAccumulator >= Constants.nightAutoSpawnInterval {
            nightSpawnAccumulator = 0
            spawnAtRandomEdge()
        }
    }

    private func spawnAtRandomEdge() {
        guard cockroaches.count < Constants.maxCockroaches else { return }
        guard let screen = NSScreen.main?.visibleFrame else { return }

        // Pick one of the four edges and a random offset along it.
        let edge = Int.random(in: 0..<4)
        let position: CGPoint
        switch edge {
        case 0: // top
            position = CGPoint(x: .random(in: screen.minX + 50...screen.maxX - 50), y: screen.maxY)
        case 1: // bottom
            position = CGPoint(x: .random(in: screen.minX + 50...screen.maxX - 50), y: screen.minY)
        case 2: // left
            position = CGPoint(x: screen.minX, y: .random(in: screen.minY + 50...screen.maxY - 50))
        default: // right
            position = CGPoint(x: screen.maxX, y: .random(in: screen.minY + 50...screen.maxY - 50))
        }

        let variant: SizeVariant = Double.random(in: 0...1) < 0.1 ? .large : .normal
        let roach = Cockroach(position: position, sizeVariant: variant)
        roach.transitionTo(.dash)
        roach.pickRandomTarget(within: screen)
        addCockroach(roach)
    }

    // MARK: - Spawning

    func summonCockroach() {
        guard cockroaches.count < Constants.maxCockroaches else { return }

        let screenBounds = NSScreen.main?.visibleFrame ?? .zero
        // Start from bottom edge
        let startX = CGFloat.random(in: screenBounds.minX + 50...screenBounds.maxX - 50)
        let startY = screenBounds.minY

        let variant: SizeVariant = Double.random(in: 0...1) < 0.1 ? .large : .normal
        let roach = Cockroach(position: CGPoint(x: startX, y: startY), sizeVariant: variant)
        roach.transitionTo(.entering)
        addCockroach(roach)
    }

    func spawnBabies(count: Int, near position: CGPoint) {
        for _ in 0..<count {
            guard cockroaches.count < Constants.maxCockroaches else { break }

            let offset = CGPoint(
                x: CGFloat.random(in: -30...30),
                y: CGFloat.random(in: -30...30)
            )
            let babyPos = CGPoint(x: position.x + offset.x, y: position.y + offset.y)
            let baby = Cockroach(position: babyPos, sizeVariant: .baby)
            baby.transitionTo(.dash)
            baby.pickRandomTarget(within: NSScreen.main?.visibleFrame)
            addCockroach(baby)
        }
    }

    private func addCockroach(_ cockroach: Cockroach) {
        cockroaches.append(cockroach)

        let window = CockroachWindow(cockroach: cockroach)
        windows[cockroach.id] = window
        window.orderFront(nil)

        // If there's a cake on screen, recruit this newcomer too (90% chance),
        // so cockroaches spawned via clipboard / babies / night auto-spawn /
        // ⌘N also join the feast instead of ignoring the cake.
        if CakeManager.shared.cake != nil {
            switch cockroach.state {
            case .dying, .dead, .dragged, .falling, .flipped, .struggling, .exiting:
                break
            default:
                cockroach.feedOffset = CakeManager.shared.randomEatingOffset()
                cockroach.transitionTo(.feeding)
            }
        }
    }

    private func removeCockroach(id: UUID) {
        cockroaches.removeAll { $0.id == id }
        if let window = windows[id] {
            window.orderOut(nil)
            windows.removeValue(forKey: id)
        }
    }

    // MARK: - Exit Animation

    func exitAll() {
        let screenBounds = NSScreen.main?.visibleFrame ?? .zero
        for cockroach in cockroaches {
            if cockroach.state != .dead && cockroach.state != .dying {
                cockroach.startExiting(screenBounds: screenBounds)
            }
        }
    }

    // MARK: - Kill All

    func killAll() {
        for cockroach in cockroaches {
            if cockroach.state != .dead && cockroach.state != .dying {
                cockroach.handleExterminate()
            }
        }
    }

    // MARK: - Fear Scatter

    func fearScatter(near point: CGPoint) {
        let scatterRadius: CGFloat = 200
        for cockroach in cockroaches {
            guard cockroach.state != .dead && cockroach.state != .dying && cockroach.state != .dragged else { continue }
            let dist = hypot(cockroach.position.x - point.x, cockroach.position.y - point.y)
            if dist < scatterRadius {
                let awayAngle = atan2(cockroach.position.y - point.y, cockroach.position.x - point.x)
                cockroach.transitionTo(.fleeing)
                cockroach.angle = awayAngle
                cockroach.targetPosition = CGPoint(
                    x: cockroach.position.x + cos(awayAngle) * 200,
                    y: cockroach.position.y + sin(awayAngle) * 200
                )
                cockroach.stateDuration = Double.random(in: 1.0...1.5)
            }
        }
    }

    // MARK: - Exterminator Mode

    func setExterminatorCursor() {
        // Push crosshair cursor so it shows everywhere
        NSCursor.crosshair.push()
    }

    func removeExterminatorCursor() {
        NSCursor.pop()
    }

    // MARK: - Clipboard Summoning

    func startClipboardMonitor() {
        lastClipboardCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        if currentCount != lastClipboardCount {
            lastClipboardCount = currentCount
            summonCockroach()
        }
    }

    // MARK: - Persistence

    func saveState() {
        let saveData = cockroaches
            .filter { $0.state != .dead && $0.state != .dying }
            .map { $0.toSaveData() }
        if let encoded = try? JSONEncoder().encode(saveData) {
            UserDefaults.standard.set(encoded, forKey: Constants.saveKey)
        }
    }

    func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: Constants.saveKey),
              let savedRoaches = try? JSONDecoder().decode([Cockroach.SaveData].self, from: data) else {
            return
        }

        for saveData in savedRoaches {
            let roach = Cockroach.fromSaveData(saveData)
            addCockroach(roach)
        }
    }
}

