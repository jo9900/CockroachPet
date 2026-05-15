import AppKit
import SwiftUI

struct Cake {
    var position: CGPoint
    let bornAt: TimeInterval
    /// Wall-clock time when the first cockroach reached an eating spot. The
    /// 30 s half-life / 60 s gone-life counts from here, not from `bornAt`,
    /// so the cake doesn't shrink while everyone is still walking over.
    var eatingStartedAt: TimeInterval?

    static let totalLifetime: TimeInterval = 60
    static let halfTime: TimeInterval = 30
    /// Hard ceiling — if no cockroach ever arrives, the cake still vanishes
    /// after this many seconds so it doesn't sit there forever.
    static let maxIdleLifetime: TimeInterval = 180

    var ageFromBorn: TimeInterval { CACurrentMediaTime() - bornAt }
    var eatingAge: TimeInterval {
        guard let start = eatingStartedAt else { return 0 }
        return CACurrentMediaTime() - start
    }

    var isHalfEaten: Bool { eatingAge >= Cake.halfTime }
    var isFinished: Bool {
        eatingAge >= Cake.totalLifetime || ageFromBorn >= Cake.maxIdleLifetime
    }
}

/// Owns the (at most one) cake on screen. Uses a small draggable window so
/// the user can grab and move it out of the way.
final class CakeManager: ObservableObject {
    static let shared = CakeManager()

    static let windowSize: CGFloat = 120

    @Published private(set) var cake: Cake?
    private var window: CakeWindow?

    private init() {}

    func dropCake() {
        guard let screen = NSScreen.main?.visibleFrame else { return }

        let newCake = Cake(
            position: CGPoint(x: screen.midX, y: screen.midY),
            bornAt: CACurrentMediaTime(),
            eatingStartedAt: nil
        )
        cake = newCake

        // Open or reuse the cake window.
        let win = window ?? CakeWindow()
        win.reposition(to: newCake.position)
        win.onDragMove = { [weak self] newCenter in
            self?.moveCake(to: newCenter)
        }
        win.orderFront(nil)
        window = win

        // Recruit every cockroach that's in a state where it can be redirected.
        let manager = CockroachManager.shared
        for c in manager.cockroaches {
            switch c.state {
            case .dying, .dead, .dragged, .falling, .flipped, .struggling, .exiting:
                continue
            default:
                break
            }
            c.feedOffset = randomEatingOffset()
            c.transitionTo(.feeding)
        }
    }

    /// Called when the user drags the cake window — keep `cake.position` in sync
    /// so feeding cockroaches follow.
    func moveCake(to newCenter: CGPoint) {
        guard var current = cake else { return }
        current.position = newCenter
        cake = current
    }

    /// Called every tick from `CockroachManager.tick()`.
    func update() {
        guard let c = cake else { return }

        // Start the half-life countdown as soon as the first cockroach has
        // actually reached its eating spot (speed = 0 in .feeding).
        if c.eatingStartedAt == nil {
            let arrived = CockroachManager.shared.cockroaches.contains {
                $0.state == .feeding && $0.speed == 0
            }
            if arrived, var mutableCake = cake {
                mutableCake.eatingStartedAt = CACurrentMediaTime()
                cake = mutableCake
            }
        }

        if c.isFinished {
            cake = nil
            window?.orderOut(nil)
            for cock in CockroachManager.shared.cockroaches where cock.state == .feeding {
                // Credit this cake.
                cock.cakesEaten += 1
                if cock.cakesEaten >= 2 {
                    cock.cakesEaten = 0
                    cock.growthScale *= 1.2
                    cock.levelUpTimer = 1.5
                }
                cock.feedOffset = nil

                // Scurry off in a random direction so they don't just sit there
                // after their meal disappears.
                let randomAngle = CGFloat.random(in: 0...(2 * .pi))
                cock.angle = randomAngle
                cock.targetPosition = CGPoint(
                    x: cock.position.x + cos(randomAngle) * 150,
                    y: cock.position.y + sin(randomAngle) * 150
                )
                cock.transitionTo(.dash)
            }
        }
    }

    /// Returns a random offset in a ring (relative to the cake center).
    func randomEatingOffset() -> CGPoint {
        let r = CGFloat.random(in: 40...110)
        let theta = CGFloat.random(in: 0...(2 * .pi))
        return CGPoint(x: cos(theta) * r, y: sin(theta) * r)
    }
}

/// Small transparent NSPanel hosting the cake glyph. Accepts mouse drags so
/// the user can move the cake out of the way.
final class CakeWindow: NSPanel {
    var onDragMove: ((CGPoint) -> Void)?

    private var hostingView: NSHostingView<CakeBodyView>!
    private var dragOffset: NSPoint = .zero
    private var isDragging = false

    init() {
        let size = CakeManager.windowSize
        let frame = NSRect(x: 0, y: 0, width: size, height: size)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = false
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let body = CakeBodyView(manager: CakeManager.shared)
        hostingView = NSHostingView(rootView: body)
        hostingView.frame = frame
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reposition(to center: CGPoint) {
        let s = self.frame.size
        let newFrame = NSRect(
            x: center.x - s.width / 2,
            y: center.y - s.height / 2,
            width: s.width,
            height: s.height
        )
        setFrame(newFrame, display: false)
    }

    override func mouseDown(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        dragOffset = NSPoint(x: mouse.x - frame.midX, y: mouse.y - frame.midY)
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let mouse = NSEvent.mouseLocation
        let newCenter = CGPoint(x: mouse.x - dragOffset.x, y: mouse.y - dragOffset.y)
        onDragMove?(newCenter)
        reposition(to: newCenter)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }
}

/// SwiftUI body for the cake window — observes CakeManager so the half-eaten
/// state and tick-driven movement re-render automatically.
struct CakeBodyView: View {
    @ObservedObject var manager: CakeManager

    var body: some View {
        TimelineView(.animation) { _ in
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        let size = CakeManager.windowSize
        if let cake = manager.cake {
            ZStack {
                Color.clear
                cakeGlyph(isHalfEaten: cake.isHalfEaten)
            }
            .frame(width: size, height: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    /// The cake itself. Same size whether full or half — when half-eaten we
    /// clip a small jagged "bite" out of the upper-right rather than shrinking.
    @ViewBuilder
    private func cakeGlyph(isHalfEaten: Bool) -> some View {
        let glyphSize: CGFloat = 100
        if isHalfEaten {
            Text("🍰")
                .font(.system(size: glyphSize))
                .frame(width: glyphSize, height: glyphSize)
                .mask(biteMask)
        } else {
            Text("🍰")
                .font(.system(size: glyphSize))
                .frame(width: glyphSize, height: glyphSize)
        }
    }

    /// A subtle wavy edge cutting a thin slice off the right side.
    /// Right edge of "visible" region sits between ~70% and ~78% of the width,
    /// so only a sliver is missing — closer to a nibble than a chomp.
    private var biteMask: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width
                let h = geo.size.height
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: w * 0.78, y: 0))
                p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.18))
                p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.36))
                p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.54))
                p.addLine(to: CGPoint(x: w * 0.77, y: h * 0.72))
                p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.88))
                p.addLine(to: CGPoint(x: w * 0.78, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
            }
            .fill(Color.black)
        }
    }
}
