import Foundation

enum Constants {
    static let cockroachSize: CGFloat = 30
    static let alertDistance: CGFloat = 100
    static let saveKey = "cockroachSaveData"

    // User settings with defaults
    static var maxCockroaches: Int {
        let val = UserDefaults.standard.integer(forKey: "maxCockroaches")
        return val > 0 ? val : 30
    }

    static var growthTimeMinutes: Int {
        let val = UserDefaults.standard.integer(forKey: "growthTimeMinutes")
        return val > 0 ? val : 10
    }

    static func setMaxCockroaches(_ value: Int) {
        UserDefaults.standard.set(min(max(value, 1), 99), forKey: "maxCockroaches")
    }

    static func setGrowthTimeMinutes(_ value: Int) {
        UserDefaults.standard.set(min(max(value, 1), 60), forKey: "growthTimeMinutes")
    }

    // Night mode
    static let nightStartHour = 20
    static let nightEndHour = 7
    static let nightSpeedMultiplier: CGFloat = 1.3
    static let nightDashBoost: Double = 0.15

    // Poop trails
    static let poopMaxCount = 150
    static let poopChancePerFrame: Double = 0.003
    static let poopMinLifetime: TimeInterval = 30
    static let poopMaxLifetime: TimeInterval = 40
    static let poopMinSpeed: CGFloat = 0.3
}
