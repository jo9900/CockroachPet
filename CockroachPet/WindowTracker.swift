import AppKit
import CoreGraphics

enum WindowEdge: String, Codable {
    case top, bottom, left, right
}

/// Polls CoreGraphics for the bounds of other apps' on-screen windows so
/// cockroaches can crawl along them. Works without Accessibility permission.
/// All rects are returned in AppKit coordinate space (origin bottom-left).
final class WindowTracker {
    static let shared = WindowTracker()

    private var cachedRects: [CGRect] = []
    private var timer: Timer?
    private let ownPID: pid_t = getpid()
    private let refreshInterval: TimeInterval = 1.0

    private init() {
        refresh()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    var allRects: [CGRect] { cachedRects }

    private func refresh() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            cachedRects = []
            return
        }

        // Total screen-space height across all displays (for Y flip).
        let totalHeight: CGFloat = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0

        var rects: [CGRect] = []
        for entry in raw {
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID else { continue }
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha < 0.5 { continue }
            guard let boundsDict = entry[kCGWindowBounds as String] as? [String: Any] else { continue }
            guard let cgRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // Skip tiny windows (tooltips, status overlays).
            if cgRect.width < 200 || cgRect.height < 150 { continue }

            // Flip Y: CGWindowList uses top-left origin, AppKit uses bottom-left.
            let appkitRect = CGRect(
                x: cgRect.minX,
                y: totalHeight - cgRect.maxY,
                width: cgRect.width,
                height: cgRect.height
            )
            rects.append(appkitRect)
        }
        cachedRects = rects
    }

    /// Find the nearest window edge to `point`. Only considers edges where
    /// `point` is within the edge's length range (not past its corners).
    /// Returns nil if no edge is within `maxDistance`.
    func nearestEdge(to point: CGPoint, maxDistance: CGFloat) -> (rect: CGRect, edge: WindowEdge)? {
        var bestRect: CGRect?
        var bestEdge: WindowEdge?
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for rect in cachedRects {
            let candidates: [(WindowEdge, CGFloat, Bool)] = [
                (.top,    abs(point.y - rect.maxY), point.x >= rect.minX && point.x <= rect.maxX),
                (.bottom, abs(point.y - rect.minY), point.x >= rect.minX && point.x <= rect.maxX),
                (.left,   abs(point.x - rect.minX), point.y >= rect.minY && point.y <= rect.maxY),
                (.right,  abs(point.x - rect.maxX), point.y >= rect.minY && point.y <= rect.maxY),
            ]
            for (edge, d, inRange) in candidates {
                guard inRange, d <= maxDistance, d < bestDist else { continue }
                bestDist = d
                bestEdge = edge
                bestRect = rect
            }
        }

        if let r = bestRect, let e = bestEdge {
            return (r, e)
        }
        return nil
    }

    /// Returns whether the supplied rect is still in the latest snapshot.
    func contains(_ rect: CGRect) -> Bool {
        for r in cachedRects {
            // Tolerate small jitter from animations / resize ticks.
            if abs(r.minX - rect.minX) < 4 && abs(r.minY - rect.minY) < 4
                && abs(r.width - rect.width) < 4 && abs(r.height - rect.height) < 4 {
                return true
            }
        }
        return false
    }
}
