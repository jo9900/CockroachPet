import AppKit

/// Tracks global mouse position and speed for cockroach AI reactions.
class MouseTracker {
    private(set) var position: CGPoint = .zero
    private(set) var speed: CGFloat = 0
    private var lastPosition: CGPoint = .zero
    private var lastTime: TimeInterval = 0
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init() {
        position = NSEvent.mouseLocation
        lastPosition = position
        lastTime = CACurrentMediaTime()

        // Monitor global mouse movement
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.updateMouse()
        }

        // Also monitor local events (within our windows)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updateMouse()
            return event
        }
    }

    private func updateMouse() {
        let now = CACurrentMediaTime()
        let dt = now - lastTime
        guard dt > 0 else { return }

        let currentPos = NSEvent.mouseLocation
        let dx = currentPos.x - lastPosition.x
        let dy = currentPos.y - lastPosition.y
        let distance = hypot(dx, dy)

        // Smooth speed calculation
        let instantSpeed = distance / CGFloat(dt)
        speed = speed * 0.7 + instantSpeed * 0.3 // exponential smoothing

        lastPosition = currentPos
        position = currentPos
        lastTime = now
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
