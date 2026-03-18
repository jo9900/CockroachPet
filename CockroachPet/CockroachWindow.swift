import AppKit
import SwiftUI

/// Transparent floating window that hosts a single cockroach.
class CockroachWindow: NSWindow {
    let cockroach: Cockroach
    private var hostingView: NSHostingView<CockroachContentView>!
    private var trackingArea: NSTrackingArea?
    private var isDragging = false
    private var dragStartPos: CGPoint = .zero
    private var pendingClickWork: DispatchWorkItem?

    init(cockroach: Cockroach) {
        self.cockroach = cockroach

        let windowSize = cockroach.size * 3
        let frame = NSRect(x: cockroach.position.x - windowSize / 2,
                           y: cockroach.position.y - windowSize / 2,
                           width: windowSize, height: windowSize)

        super.init(contentRect: frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)

        // Transparent, floating, click-through on transparent areas
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = CockroachContentView(cockroach: cockroach, window: self)
        hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowSize, height: windowSize)
        self.contentView = hostingView

        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: self.contentView?.bounds ?? .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.contentView?.addTrackingArea(area)
        self.trackingArea = area
    }

    func updatePosition() {
        let isFlying = cockroach.state == .flying
        let windowSize = isFlying ? cockroach.size * 6 : cockroach.size * 3
        // When flying, offset window upward to keep the lifted body centered
        let flyCompensation = isFlying ? cockroach.flyHeight * 0.5 : 0
        let origin = NSPoint(
            x: cockroach.position.x - windowSize / 2,
            y: cockroach.position.y - windowSize / 2 + flyCompensation
        )
        let newFrame = NSRect(x: origin.x, y: origin.y, width: windowSize, height: windowSize)
        self.setFrame(newFrame, display: false)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowSize, height: windowSize)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        if CockroachManager.shared.exterminatorMode {
            cockroach.handleExterminate()
            return
        }

        if event.clickCount == 2 {
            // Cancel pending single-click so it doesn't fire
            pendingClickWork?.cancel()
            pendingClickWork = nil

            let result = cockroach.handleDoubleClick(currentCount: CockroachManager.shared.cockroaches.count)
            if result.babies > 0 {
                CockroachManager.shared.spawnBabies(count: result.babies, near: cockroach.position)
            }
        } else {
            isDragging = false
            dragStartPos = NSEvent.mouseLocation
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            let screenBounds = NSScreen.main?.visibleFrame ?? .zero
            cockroach.handleDragEnd(screenBounds: screenBounds)
        } else if event.clickCount == 1 && !CockroachManager.shared.exterminatorMode {
            // Delay single-click to allow double-click to cancel it
            let work = DispatchWorkItem { [weak self] in
                self?.cockroach.handleClick()
            }
            pendingClickWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if CockroachManager.shared.exterminatorMode { return }

        let currentPos = NSEvent.mouseLocation
        let distance = hypot(currentPos.x - dragStartPos.x, currentPos.y - dragStartPos.y)

        if distance > 5 {
            if !isDragging {
                isDragging = true
                cockroach.handleDragStart()
            }
            cockroach.handleDragMove(to: currentPos)
        }
    }
}

/// SwiftUI wrapper for the cockroach content inside the window.
struct CockroachContentView: View {
    @ObservedObject var cockroach: Cockroach
    weak var window: CockroachWindow?

    var body: some View {
        CockroachView(cockroach: cockroach)
            .allowsHitTesting(true)
    }
}
