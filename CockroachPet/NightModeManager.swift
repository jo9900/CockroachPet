import Foundation
import Combine

final class NightModeManager: ObservableObject {
    static let shared = NightModeManager()

    @Published private(set) var isNightMode: Bool = false

    var speedMultiplier: CGFloat {
        isNightMode ? Constants.nightSpeedMultiplier : 1.0
    }

    private var timer: Timer?

    private init() {
        checkTime()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkTime()
        }
    }

    private func checkTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        let newValue = hour >= Constants.nightStartHour || hour < Constants.nightEndHour
        if newValue != isNightMode {
            isNightMode = newValue
        }
    }
}
