import Foundation
import AppKit

// MARK: - State Machine

enum CockroachState: String, Codable {
    case entering       // crawling in from screen edge
    case idle           // standing still, antennae moving
    case patrol         // slow random walk
    case dash           // sudden fast run
    case wallFollow     // walking along screen edge
    case windowCrawl    // walking along another app's window edge
    case alert          // noticed cursor nearby
    case fleeing        // running away from cursor
    case flipped        // on back after click
    case struggling     // trying to right itself
    case dragged        // picked up by user
    case falling        // dropped and falling
    case curious        // approaching still cursor
    case playingDead    // lying still, surprise dash if cursor approaches
    case grooming       // cleaning antennae with front leg
    case dying          // squish/death animation
    case dead           // fading out
    case exiting        // running to edge to disappear
    case flying         // airborne escape when cornered
    case feeding        // walking to and eating the cake
}

// MARK: - Size Variants

enum SizeVariant: String, Codable {
    case baby
    case normal
    case large
}

// MARK: - Cockroach Model

class Cockroach: ObservableObject, Identifiable {
    let id: UUID
    @Published var position: CGPoint
    @Published var angle: CGFloat = 0          // radians, 0 = right
    @Published var state: CockroachState = .entering
    @Published var sizeVariant: SizeVariant
    var bornAt: Date = Date()
    @Published var opacity: CGFloat = 1.0
    @Published var isSquished: Bool = false
    @Published var flipProgress: CGFloat = 0   // 0 = normal, 1 = fully flipped
    @Published var legPhase: CGFloat = 0       // animation phase for leg movement
    @Published var antennaPhase: CGFloat = 0   // animation phase for antennae
    @Published var bodyRaise: CGFloat = 0      // how much body is raised (alert)
    @Published var scaleY: CGFloat = 1.0       // for squish effect

    var size: CGFloat {
        let base: CGFloat
        switch sizeVariant {
        case .baby: base = Constants.cockroachSize * 2 / 3
        case .normal: base = Constants.cockroachSize
        case .large: base = Constants.cockroachSize * 3.0
        }
        return base * growthScale
    }

    /// Cumulative size multiplier from eating cakes (every 2 cakes -> ×1.2).
    @Published var growthScale: CGFloat = 1.0
    /// Cakes eaten since last level-up. Resets to 0 when growthScale steps up.
    var cakesEaten: Int = 0
    /// Counts down a level-up visual flourish (seconds).
    @Published var levelUpTimer: TimeInterval = 0

    var isBaby: Bool { sizeVariant == .baby }
    var isLarge: Bool { sizeVariant == .large }

    var speedScale: CGFloat {
        switch sizeVariant {
        case .baby: return 1.3
        case .normal: return 1.0
        case .large: return 1.1
        }
    }
    var speed: CGFloat = 0
    var targetPosition: CGPoint?
    var stateTimer: TimeInterval = 0
    var stateDuration: TimeInterval = 0
    @Published var enteringPhase: CGFloat = 0   // 0..1 for entering animation

    // Drag state
    var dragOffset: CGPoint = .zero

    // For curious behavior
    var cursorStillTimer: TimeInterval = 0
    @Published var groomPhase: CGFloat = 0

    // For cornered flying
    var corneredTimer: TimeInterval = 0
    var corneredFlyTime: TimeInterval = 0  // when to trigger fly
    var flyHeight: CGFloat = 0
    var splatParticles: [(offset: CGPoint, opacity: CGFloat)] = []

    // For window edge crawl
    var windowCrawlRect: CGRect?
    var windowCrawlEdge: WindowEdge?
    var windowCrawlDirection: CGFloat = 1  // +1 or -1 along the edge

    // For accelerative gravity in `falling`
    var fallVelocity: CGFloat = 0

    // For feeding around a cake — store the offset from the cake so the
    // cockroach naturally follows when the user drags the cake to a new spot.
    var feedOffset: CGPoint?

    init(id: UUID = UUID(), position: CGPoint, sizeVariant: SizeVariant = .normal) {
        self.id = id
        self.position = position
        self.sizeVariant = sizeVariant
    }

    // MARK: - AI Update (called every frame)

    func update(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat, screenBounds: CGRect) {
        stateTimer += dt

        // Drain the level-up visual flourish.
        if levelUpTimer > 0 {
            levelUpTimer = max(0, levelUpTimer - dt)
        }

        // Baby growth check
        if isBaby {
            let growthSeconds = TimeInterval(Constants.growthTimeMinutes * 60)
            if Date().timeIntervalSince(bornAt) >= growthSeconds {
                growUp()
            }
        }
        legPhase += dt * (speed > 0 ? speed * 0.5 : 1.0)
        antennaPhase += dt * 2.0

        switch state {
        case .entering:
            updateEntering(dt: dt, screenBounds: screenBounds)
        case .idle:
            updateIdle(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed, screenBounds: screenBounds)
        case .patrol:
            updatePatrol(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed, screenBounds: screenBounds)
        case .dash:
            updateDash(dt: dt, screenBounds: screenBounds)
        case .wallFollow:
            updateWallFollow(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed, screenBounds: screenBounds)
        case .windowCrawl:
            updateWindowCrawl(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed, screenBounds: screenBounds)
        case .feeding:
            updateFeeding(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        case .alert:
            updateAlert(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        case .fleeing:
            updateFleeing(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed, screenBounds: screenBounds)
        case .flipped:
            updateFlipped(dt: dt)
        case .struggling:
            updateStruggling(dt: dt)
        case .dragged:
            break // position updated externally
        case .falling:
            updateFalling(dt: dt, screenBounds: screenBounds)
        case .curious:
            updateCurious(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        case .playingDead:
            updatePlayingDead(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        case .grooming:
            updateGrooming(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        case .dying:
            updateDying(dt: dt)
        case .dead:
            break
        case .exiting:
            updateExiting(dt: dt, screenBounds: screenBounds)
        case .flying:
            updateFlying(dt: dt, screenBounds: screenBounds)
        }
    }

    // MARK: - State Transitions

    func transitionTo(_ newState: CockroachState) {
        state = newState
        stateTimer = 0

        switch newState {
        case .idle:
            speed = 0
            stateDuration = Double.random(in: 1.0...4.0)
            bodyRaise = 0
        case .patrol:
            speed = 25 * speedScale * ActiveBuffs.speedMultiplier
            stateDuration = Double.random(in: 2.0...6.0)
            pickRandomTarget(within: nil)
        case .dash:
            speed = 150 * speedScale * ActiveBuffs.speedMultiplier
            stateDuration = Double.random(in: 0.3...0.8)
            pickRandomTarget(within: nil)
        case .wallFollow:
            speed = 20 * speedScale * ActiveBuffs.speedMultiplier
            stateDuration = Double.random(in: 3.0...8.0)
        case .windowCrawl:
            speed = 22 * speedScale * ActiveBuffs.speedMultiplier
            stateDuration = Double.random(in: 4.0...9.0)
            windowCrawlDirection = Bool.random() ? 1 : -1
            // Snap to the assigned edge if one was provided before the transition.
            applyWindowCrawlSnap()
        case .feeding:
            speed = 40 * speedScale * ActiveBuffs.speedMultiplier
            stateDuration = Cake.totalLifetime
            bodyRaise = 0
            if let cake = CakeManager.shared.cake, let offset = feedOffset {
                let target = CGPoint(x: cake.position.x + offset.x, y: cake.position.y + offset.y)
                angle = atan2(target.y - position.y, target.x - position.x)
            }
        case .alert:
            speed = 0
            bodyRaise = 0.3
            stateDuration = Double.random(in: 0.5...1.5)
        case .fleeing:
            speed = 180 * speedScale * ActiveBuffs.speedMultiplier
            stateDuration = Double.random(in: 0.5...1.2)
        case .flipped:
            speed = 0
            flipProgress = 1.0
            stateDuration = Double.random(in: 1.5...3.0)
        case .struggling:
            speed = 0
            stateDuration = Double.random(in: 0.5...1.0)
        case .curious:
            speed = 12 * speedScale * ActiveBuffs.speedMultiplier
            stateDuration = Double.random(in: 2.0...5.0)
        case .playingDead:
            speed = 0
            stateDuration = Double.random(in: 3.0...8.0)
            flipProgress = 0.3
        case .grooming:
            speed = 0
            stateDuration = Double.random(in: 2.0...4.0)
            groomPhase = 0
        case .dying:
            speed = 0
            isSquished = true
            scaleY = 0.15
            stateDuration = 2.0
            splatParticles = (0..<Int.random(in: 5...8)).map { _ in
                (offset: CGPoint(
                    x: CGFloat.random(in: -20...20),
                    y: CGFloat.random(in: -20...20)
                ), opacity: CGFloat(1.0))
            }
        case .exiting:
            speed = 180 * speedScale * ActiveBuffs.speedMultiplier
        case .entering:
            speed = 40 * speedScale * ActiveBuffs.speedMultiplier
            enteringPhase = 0
        case .flying:
            speed = 220 * speedScale * ActiveBuffs.speedMultiplier
            flyHeight = 0
            stateDuration = Double.random(in: 0.8...1.5)
            // Pick a random landing spot away from corners
            let screenBounds = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
            let padding: CGFloat = 100
            targetPosition = CGPoint(
                x: CGFloat.random(in: screenBounds.minX + padding...screenBounds.maxX - padding),
                y: CGFloat.random(in: screenBounds.minY + padding...screenBounds.maxY - padding)
            )
            if let target = targetPosition {
                angle = atan2(target.y - position.y, target.x - position.x)
            }
        default:
            break
        }
    }

    // MARK: - State Updates

    private func updateEntering(dt: TimeInterval, screenBounds: CGRect) {
        // Phase 0..0.3: antennae peek out (slow), 0.3..1.0: body crawls up (faster)
        let phaseSpeed: CGFloat = enteringPhase < 0.3 ? 0.8 : 2.0
        enteringPhase += CGFloat(dt) * phaseSpeed
        if enteringPhase >= 1.0 {
            enteringPhase = 1.0
            transitionTo(.dash)
            // Dash to a random position on screen
            let padding: CGFloat = 60
            targetPosition = CGPoint(
                x: CGFloat.random(in: screenBounds.minX + padding...screenBounds.maxX - padding),
                y: CGFloat.random(in: screenBounds.minY + padding...screenBounds.maxY - padding)
            )
        }
        // Move upward from bottom — slow peek then faster crawl
        let moveSpeed = enteringPhase < 0.3 ? speed * 0.3 : speed
        position.y += CGFloat(dt) * moveSpeed
        // Face upward during entry
        angle = .pi / 2
    }

    private func updateIdle(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat, screenBounds: CGRect) {
        checkMouseReaction(mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        if stateTimer >= stateDuration {
            pickNextIdleBehavior(screenBounds: screenBounds)
        }
    }

    private func updatePatrol(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat, screenBounds: CGRect) {
        checkMouseReaction(mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        moveTowardTarget(dt: dt, screenBounds: screenBounds)
        if stateTimer >= stateDuration || targetReached() {
            pickNextIdleBehavior(screenBounds: screenBounds)
        }
    }

    private func updateDash(dt: TimeInterval, screenBounds: CGRect) {
        moveTowardTarget(dt: dt, screenBounds: screenBounds)
        if stateTimer >= stateDuration || targetReached() {
            transitionTo(.idle)
        }
    }

    private func updateWallFollow(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat, screenBounds: CGRect) {
        checkMouseReaction(mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        // Move along the nearest edge
        moveAlongEdge(dt: dt, screenBounds: screenBounds)
        if stateTimer >= stateDuration {
            transitionTo(.idle)
        }
    }

    private func updateAlert(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat) {
        // Face the cursor
        let dx = mousePosition.x - position.x
        let dy = mousePosition.y - position.y
        angle = atan2(dy, dx)
        bodyRaise = 0.3

        if mouseSpeed > Constants.fleeSpeedThreshold {
            // Cursor moved fast — flee!
            transitionTo(.fleeing)
            // Flee in opposite direction
            angle = atan2(-dy, -dx)
            targetPosition = CGPoint(
                x: position.x + cos(angle) * 200,
                y: position.y + sin(angle) * 200
            )
        } else if stateTimer >= stateDuration {
            let dist = hypot(dx, dy)
            if dist > Constants.alertDistance {
                transitionTo(.idle)
            } else if dist < Constants.alertDistance && mouseSpeed < 5 {
                transitionTo(.curious)
            }
        }
    }

    private func updateFleeing(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat, screenBounds: CGRect) {
        checkCorneredFlight(mousePosition: mousePosition)
        moveTowardTarget(dt: dt, screenBounds: screenBounds)
        if stateTimer >= stateDuration || targetReached() {
            transitionTo(.idle)
        }
    }

    private func updateFlipped(dt: TimeInterval) {
        // Legs flailing animation is handled by legPhase
        if stateTimer >= stateDuration {
            transitionTo(.struggling)
        }
    }

    private func updateStruggling(dt: TimeInterval) {
        flipProgress = max(0, flipProgress - CGFloat(dt) * 2.0)
        if flipProgress <= 0 {
            flipProgress = 0
            transitionTo(.fleeing)
            let randomAngle = CGFloat.random(in: 0...(2 * .pi))
            angle = randomAngle
            targetPosition = CGPoint(
                x: position.x + cos(randomAngle) * 150,
                y: position.y + sin(randomAngle) * 150
            )
        }
    }

    private func updateFalling(dt: TimeInterval, screenBounds: CGRect) {
        // Accelerative gravity — feels more like a real drop than a constant fall.
        let physicalBottom = NSScreen.main?.frame.minY ?? 0
        fallVelocity += Constants.fallGravity * CGFloat(dt)
        position.y -= fallVelocity * CGFloat(dt)
        if position.y <= physicalBottom + 10 {
            position.y = physicalBottom + 10
            fallVelocity = 0
            transitionTo(.flipped)
        }
    }

    private func updateCurious(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat) {
        if mouseSpeed > 30 {
            transitionTo(.alert)
            return
        }
        // Move toward cursor slowly
        let dx = mousePosition.x - position.x
        let dy = mousePosition.y - position.y
        let dist = hypot(dx, dy)
        angle = atan2(dy, dx)

        if dist > 20 {
            position.x += cos(angle) * speed * CGFloat(dt)
            position.y += sin(angle) * speed * CGFloat(dt)
        }
        if stateTimer >= stateDuration {
            transitionTo(.idle)
        }
    }

    private func updatePlayingDead(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat) {
        let dx = mousePosition.x - position.x
        let dy = mousePosition.y - position.y
        let dist = hypot(dx, dy)

        if dist < 60 {
            flipProgress = 0
            transitionTo(.dash)
            angle = atan2(-dy, -dx)
            targetPosition = CGPoint(
                x: position.x + cos(angle) * 200,
                y: position.y + sin(angle) * 200
            )
            return
        }

        if stateTimer >= stateDuration {
            flipProgress = 0
            transitionTo(.idle)
        }
    }

    private func updateGrooming(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat) {
        groomPhase += CGFloat(dt) * 4.0
        checkMouseReaction(mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        if stateTimer >= stateDuration {
            transitionTo(.idle)
        }
    }

    private func updateDying(dt: TimeInterval) {
        opacity = max(0, opacity - CGFloat(dt) * 0.5)
        for i in splatParticles.indices {
            splatParticles[i].opacity = max(0, splatParticles[i].opacity - CGFloat(dt))
        }
        if opacity <= 0 {
            state = .dead
        }
    }


    private func updateFlying(dt: TimeInterval, screenBounds: CGRect) {
        guard let target = targetPosition else {
            transitionTo(.idle)
            return
        }
        
        // Fly in an arc toward target
        let progress = CGFloat(stateTimer / stateDuration)
        flyHeight = sin(progress * .pi) * 40 // arc height (moderate lift)
        
        // Move toward target
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = hypot(dx, dy)
        
        if dist > 5 {
            angle = atan2(dy, dx)
            position.x += cos(angle) * speed * CGFloat(dt)
            position.y += sin(angle) * speed * CGFloat(dt)
        }
        
        // Clamp to screen
        position.x = min(max(position.x, screenBounds.minX + 5), screenBounds.maxX - 5)
        position.y = min(max(position.y, screenBounds.minY + 5), screenBounds.maxY - 5)
        
        if stateTimer >= stateDuration || dist < 10 {
            flyHeight = 0
            transitionTo(.idle)
        }
    }

    private func updateExiting(dt: TimeInterval, screenBounds: CGRect) {
        // Move toward target WITHOUT clamping (must go offscreen)
        guard let target = targetPosition else { return }
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = hypot(dx, dy)

        if dist > 2 {
            angle = atan2(dy, dx)
            position.x += cos(angle) * speed * CGFloat(dt)
            position.y += sin(angle) * speed * CGFloat(dt)
        }

        // Check if reached/passed edge
        let margin: CGFloat = 10
        if position.x <= screenBounds.minX - margin || position.x >= screenBounds.maxX + margin ||
           position.y <= screenBounds.minY - margin || position.y >= screenBounds.maxY + margin {
            state = .dead
            opacity = 0
        }
    }

    // MARK: - Feeding

    private func updateFeeding(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat) {
        // Cake gone? back to idle.
        guard let cake = CakeManager.shared.cake else {
            feedOffset = nil
            transitionTo(.idle)
            return
        }

        // No assigned offset yet — pick a spot in a ring around the cake
        // and remember it relative to the cake (so it follows when dragged).
        if feedOffset == nil {
            feedOffset = CakeManager.shared.randomEatingOffset()
        }
        guard let offset = feedOffset else { return }

        let target = CGPoint(x: cake.position.x + offset.x, y: cake.position.y + offset.y)
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = hypot(dx, dy)

        if dist > 4 {
            // Walk over.
            angle = atan2(dy, dx)
            position.x += cos(angle) * speed * CGFloat(dt)
            position.y += sin(angle) * speed * CGFloat(dt)
        } else {
            // Arrived — face the cake and nibble.
            speed = 0
            angle = atan2(cake.position.y - position.y, cake.position.x - position.x)
            // Tiny nibble wobble so it looks alive.
            angle += sin(stateTimer * 12) * 0.08
        }
    }

    // MARK: - Window Edge Crawl

    private func updateWindowCrawl(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat, screenBounds: CGRect) {
        // Cursor reaction takes priority.
        checkMouseReaction(mousePosition: mousePosition, mouseSpeed: mouseSpeed)
        if state != .windowCrawl { return }

        // Bail if the window vanished (closed, minimized, hidden behind another app).
        guard let rect = windowCrawlRect, let edge = windowCrawlEdge,
              WindowTracker.shared.contains(rect) else {
            clearWindowCrawlState()
            transitionTo(.idle)
            return
        }

        let inset = Constants.windowCrawlEdgeInset
        let step = speed * CGFloat(dt) * windowCrawlDirection

        switch edge {
        case .top:
            position.y = rect.maxY + inset
            position.x += step
            angle = windowCrawlDirection > 0 ? 0 : .pi
            if position.x < rect.minX - inset || position.x > rect.maxX + inset {
                clearWindowCrawlState()
                transitionTo(.idle)
                return
            }
        case .bottom:
            position.y = rect.minY - inset
            position.x += step
            angle = windowCrawlDirection > 0 ? 0 : .pi
            if position.x < rect.minX - inset || position.x > rect.maxX + inset {
                clearWindowCrawlState()
                transitionTo(.idle)
                return
            }
        case .left:
            position.x = rect.minX - inset
            position.y += step
            angle = windowCrawlDirection > 0 ? .pi / 2 : -.pi / 2
            if position.y < rect.minY - inset || position.y > rect.maxY + inset {
                clearWindowCrawlState()
                transitionTo(.idle)
                return
            }
        case .right:
            position.x = rect.maxX + inset
            position.y += step
            angle = windowCrawlDirection > 0 ? .pi / 2 : -.pi / 2
            if position.y < rect.minY - inset || position.y > rect.maxY + inset {
                clearWindowCrawlState()
                transitionTo(.idle)
                return
            }
        }

        // Slight angle wobble for visual life.
        angle += sin(stateTimer * 3) * 0.02

        if stateTimer >= stateDuration {
            clearWindowCrawlState()
            transitionTo(.idle)
        }
    }

    private func applyWindowCrawlSnap() {
        guard let rect = windowCrawlRect, let edge = windowCrawlEdge else { return }
        let inset = Constants.windowCrawlEdgeInset
        switch edge {
        case .top:
            position.y = rect.maxY + inset
            position.x = min(max(position.x, rect.minX), rect.maxX)
            angle = windowCrawlDirection > 0 ? 0 : .pi
        case .bottom:
            position.y = rect.minY - inset
            position.x = min(max(position.x, rect.minX), rect.maxX)
            angle = windowCrawlDirection > 0 ? 0 : .pi
        case .left:
            position.x = rect.minX - inset
            position.y = min(max(position.y, rect.minY), rect.maxY)
            angle = windowCrawlDirection > 0 ? .pi / 2 : -.pi / 2
        case .right:
            position.x = rect.maxX + inset
            position.y = min(max(position.y, rect.minY), rect.maxY)
            angle = windowCrawlDirection > 0 ? .pi / 2 : -.pi / 2
        }
    }

    private func clearWindowCrawlState() {
        windowCrawlRect = nil
        windowCrawlEdge = nil
    }

    // MARK: - Helpers


    /// Check if cornered near screen edge with cursor nearby — trigger flight escape
    private func checkCorneredFlight(mousePosition: CGPoint) {
        // Babies don't have working wings yet.
        if isBaby { return }

        let screenBounds = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let dx = mousePosition.x - position.x
        let dy = mousePosition.y - position.y
        let dist = hypot(dx, dy)
        
        let cornerThreshold: CGFloat = 150
        let nearLeft = position.x - screenBounds.minX < cornerThreshold
        let nearRight = screenBounds.maxX - position.x < cornerThreshold
        let nearBottom = position.y - screenBounds.minY < cornerThreshold
        let nearTop = screenBounds.maxY - position.y < cornerThreshold
        let againstWall = nearLeft || nearRight || nearBottom || nearTop

        if againstWall && dist < Constants.alertDistance * 2.5 {
            if corneredTimer == 0 {
                corneredFlyTime = Double.random(in: 1.0...2.5)
            }
            corneredTimer += 1.0 / 60.0
            if corneredTimer >= corneredFlyTime {
                corneredTimer = 0
                corneredFlyTime = 0
                transitionTo(.flying)
            }
        } else {
            corneredTimer = 0
            corneredFlyTime = 0
        }
    }

    private func checkMouseReaction(mousePosition: CGPoint, mouseSpeed: CGFloat) {
        let dx = mousePosition.x - position.x
        let dy = mousePosition.y - position.y
        let dist = hypot(dx, dy)

        // Check cornered flight
        checkCorneredFlight(mousePosition: mousePosition)

        if dist < Constants.alertDistance {
            if mouseSpeed > Constants.fleeSpeedThreshold {
                transitionTo(.fleeing)
                angle = atan2(-dy, -dx)
                targetPosition = CGPoint(
                    x: position.x + cos(angle) * 200,
                    y: position.y + sin(angle) * 200
                )
            } else if mouseSpeed > 10 {
                transitionTo(.alert)
            } else if mouseSpeed < 3 {
                cursorStillTimer += 1.0 / 60.0
                if cursorStillTimer > 3.0 {
                    cursorStillTimer = 0
                    transitionTo(.curious)
                }
            }
        } else {
            cursorStillTimer = 0
        }
    }

    private func pickNextIdleBehavior(screenBounds: CGRect) {
        // First, with windowCrawlChance, try to grab a nearby window edge.
        if Double.random(in: 0...1) < Constants.windowCrawlChance,
           let found = WindowTracker.shared.nearestEdge(
               to: position,
               maxDistance: Constants.windowCrawlDetectionDistance
           ) {
            windowCrawlRect = found.rect
            windowCrawlEdge = found.edge
            transitionTo(.windowCrawl)
            return
        }

        let roll = Double.random(in: 0...1)
        let dashBoost = ActiveBuffs.dashBoost
        if roll < 0.20 {
            transitionTo(.idle)
        } else if roll < 0.48 {
            transitionTo(.patrol)
            pickRandomTarget(within: screenBounds)
        } else if roll < 0.60 - dashBoost {
            transitionTo(.wallFollow)
        } else if roll < 0.68 - dashBoost {
            transitionTo(.playingDead)
        } else if roll < 0.80 - dashBoost {
            transitionTo(.grooming)
        } else {
            transitionTo(.dash)
            pickRandomTarget(within: screenBounds)
        }
    }

    func pickRandomTarget(within bounds: CGRect?) {
        let screenBounds = bounds ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let padding: CGFloat = 30
        targetPosition = CGPoint(
            x: CGFloat.random(in: screenBounds.minX + padding...screenBounds.maxX - padding),
            y: CGFloat.random(in: screenBounds.minY + padding...screenBounds.maxY - padding)
        )
        if let target = targetPosition {
            angle = atan2(target.y - position.y, target.x - position.x)
        }
    }

    private func moveTowardTarget(dt: TimeInterval, screenBounds: CGRect) {
        guard let target = targetPosition else { return }
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = hypot(dx, dy)

        if dist > 2 {
            angle = atan2(dy, dx)
            position.x += cos(angle) * speed * CGFloat(dt)
            position.y += sin(angle) * speed * CGFloat(dt)
        }

        // Clamp to screen bounds
        let padding: CGFloat = 5
        position.x = min(max(position.x, screenBounds.minX + padding), screenBounds.maxX - padding)
        position.y = min(max(position.y, screenBounds.minY + padding), screenBounds.maxY - padding)
    }

    private func moveAlongEdge(dt: TimeInterval, screenBounds: CGRect) {
        let padding: CGFloat = 10
        // Find nearest edge and walk along it
        let distLeft = position.x - screenBounds.minX
        let distRight = screenBounds.maxX - position.x
        let distBottom = position.y - screenBounds.minY
        let distTop = screenBounds.maxY - position.y
        let minDist = min(distLeft, distRight, distBottom, distTop)

        if minDist == distLeft || minDist == distRight {
            // Walk vertically
            position.y += speed * CGFloat(dt) * (angle > 0 ? 1 : -1)
            position.x = minDist == distLeft ? screenBounds.minX + padding : screenBounds.maxX - padding
            angle = angle > 0 ? .pi / 2 : -.pi / 2
        } else {
            // Walk horizontally
            position.x += speed * CGFloat(dt) * (cos(angle) > 0 ? 1 : -1)
            position.y = minDist == distBottom ? screenBounds.minY + padding : screenBounds.maxY - padding
            angle = cos(angle) > 0 ? 0 : .pi
        }

        // Clamp
        position.x = min(max(position.x, screenBounds.minX + padding), screenBounds.maxX - padding)
        position.y = min(max(position.y, screenBounds.minY + padding), screenBounds.maxY - padding)
    }

    private func targetReached() -> Bool {
        guard let target = targetPosition else { return true }
        return hypot(target.x - position.x, target.y - position.y) < 5
    }

    // MARK: - User Interaction

    func handleClick() {
        if state == .dying || state == .dead { return }
        transitionTo(.flipped)
    }

    /// Returns true if the cockroach died, false if it recovered.
    /// Returns nil + baby count if egg sac spawned.
    func handleDoubleClick(currentCount: Int) -> (died: Bool, babies: Int) {
        if state == .dying || state == .dead { return (false, 0) }

        // Double-click always kills. Babies just die.
        if isBaby {
            transitionTo(.dying)
            return (true, 0)
        }

        // Adults always die too — the squishBabySpawnChance only decides
        // whether an egg sac bursts and spawns babies along the way.
        transitionTo(.dying)
        let burstsEggs = Double.random(in: 0...1) < Constants.squishBabySpawnChance
        if burstsEggs && currentCount < Constants.maxCockroaches {
            let babyCount = Int.random(in: 3...5)
            return (true, babyCount)
        }
        return (true, 0)
    }

    func handleDragStart() {
        transitionTo(.dragged)
    }

    func handleDragMove(to point: CGPoint) {
        position = point
    }

    func handleDragEnd(screenBounds: CGRect) {
        // Always drop with falling animation — cockroaches survive falls!
        transitionTo(.falling)
    }

    func handleExterminate() {
        transitionTo(.dying)
    }

    func startExiting(screenBounds: CGRect) {
        // Find nearest edge
        let distLeft = position.x - screenBounds.minX
        let distRight = screenBounds.maxX - position.x
        let distBottom = position.y - screenBounds.minY
        let distTop = screenBounds.maxY - position.y
        let minDist = min(distLeft, distRight, distBottom, distTop)

        if minDist == distLeft {
            targetPosition = CGPoint(x: screenBounds.minX - 50, y: position.y)
        } else if minDist == distRight {
            targetPosition = CGPoint(x: screenBounds.maxX + 50, y: position.y)
        } else if minDist == distBottom {
            targetPosition = CGPoint(x: position.x, y: screenBounds.minY - 50)
        } else {
            targetPosition = CGPoint(x: position.x, y: screenBounds.maxY + 50)
        }
        if let target = targetPosition {
            angle = atan2(target.y - position.y, target.x - position.x)
        }
        transitionTo(.exiting)
    }

    // MARK: - Persistence

    private func growUp() {
        sizeVariant = .normal
        transitionTo(.idle)
    }

    struct SaveData: Codable {
        let id: String
        let x: CGFloat
        let y: CGFloat
        let sizeVariant: SizeVariant
    }

    func toSaveData() -> SaveData {
        SaveData(id: id.uuidString, x: position.x, y: position.y, sizeVariant: sizeVariant)
    }

    static func fromSaveData(_ data: SaveData) -> Cockroach {
        let roach = Cockroach(
            id: UUID(uuidString: data.id) ?? UUID(),
            position: CGPoint(x: data.x, y: data.y),
            sizeVariant: data.sizeVariant
        )
        roach.state = .idle
        roach.transitionTo(.idle)
        return roach
    }
}
