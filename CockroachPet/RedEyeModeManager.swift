import Foundation
import Combine

/// Manually togglable "red eye mode" — independent of clock-based night mode.
/// When active, cockroaches get a speed boost and stat bias toward aggressive behaviors.
final class RedEyeModeManager: ObservableObject {
    static let shared = RedEyeModeManager()

    private static let storageKey = "redEyeModeEnabled"

    @Published private(set) var isActive: Bool

    private init() {
        self.isActive = UserDefaults.standard.bool(forKey: Self.storageKey)
    }

    func toggle() {
        setActive(!isActive)
    }

    func setActive(_ value: Bool) {
        guard value != isActive else { return }
        isActive = value
        UserDefaults.standard.set(value, forKey: Self.storageKey)
    }

    /// Speed multiplier contribution from red eye mode alone.
    var speedMultiplier: CGFloat {
        isActive ? Constants.redEyeSpeedMultiplier : 1.0
    }
}

/// Convenience: combined buff multiplier from night mode + red eye mode.
/// The two stack by taking the maximum, so toggling red eye during the day
/// matches the speed of a true night, and toggling at night doesn't double-buff.
enum ActiveBuffs {
    static var speedMultiplier: CGFloat {
        max(NightModeManager.shared.speedMultiplier, RedEyeModeManager.shared.speedMultiplier)
    }

    static var dashBoost: Double {
        let night = NightModeManager.shared.isNightMode ? Constants.nightDashBoost : 0
        let red = RedEyeModeManager.shared.isActive ? Constants.nightDashBoost : 0
        return max(night, red)
    }

    static var redEyesVisible: Bool {
        NightModeManager.shared.isNightMode || RedEyeModeManager.shared.isActive
    }
}
