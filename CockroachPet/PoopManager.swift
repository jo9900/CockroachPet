import AppKit
import SwiftUI

struct PoopParticle {
    let position: CGPoint
    let birthTime: TimeInterval
    let lifetime: TimeInterval
}

final class PoopManager {
    static let shared = PoopManager()

    private(set) var particles: [PoopParticle] = []
    private var window: NSPanel?
    private var hostingView: NSHostingView<PoopCanvasView>?

    private init() {
        setupWindow()
    }

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let canvasView = PoopCanvasView(manager: self)
        let hosting = NSHostingView(rootView: canvasView)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = hosting
        panel.orderFront(nil)

        self.window = panel
        self.hostingView = hosting
    }

    func update(cockroaches: [Cockroach]) {
        let now = CACurrentMediaTime()

        // Remove expired particles
        particles.removeAll { now - $0.birthTime >= $0.lifetime }

        // Spawn new poop from moving cockroaches
        for cockroach in cockroaches {
            guard cockroach.speed >= Constants.poopMinSpeed,
                  cockroach.state != .dead && cockroach.state != .dying && cockroach.state != .dragged && cockroach.state != .falling,
                  particles.count < Constants.poopMaxCount,
                  Double.random(in: 0...1) < Constants.poopChancePerFrame else { continue }

            let particle = PoopParticle(
                position: cockroach.position,
                birthTime: now,
                lifetime: TimeInterval.random(in: Constants.poopMinLifetime...Constants.poopMaxLifetime)
            )
            particles.append(particle)
        }
    }
}

/// Canvas wrapper that uses TimelineView to force a redraw every animation tick.
/// Without this, SwiftUI's Canvas caches and the poop dots never appear.
struct PoopCanvasView: View {
    let manager: PoopManager

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let now = CACurrentMediaTime()
                let screen = NSScreen.main?.frame ?? .zero

                for particle in manager.particles {
                    let age = now - particle.birthTime
                    let lifeRatio = age / particle.lifetime
                    let alpha = max(0, 0.6 * (1.0 - lifeRatio))

                    // Convert screen coords to view coords (flip Y).
                    let x = particle.position.x - screen.minX
                    let y = size.height - (particle.position.y - screen.minY)

                    let dotSize: CGFloat = 2.5
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(red: 0.29, green: 0.14, blue: 0.03).opacity(alpha))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
