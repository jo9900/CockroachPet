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
}
