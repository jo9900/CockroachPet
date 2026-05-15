import Foundation

enum Constants {
    static let cockroachSize: CGFloat = 160
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
    static let nightSpeedMultiplier: CGFloat = 1.5
    static let nightDashBoost: Double = 0.15
    static let nightAutoSpawnInterval: TimeInterval = 45

    // Red eye mode (manual toggle, shares boosts with night mode)
    static let redEyeSpeedMultiplier: CGFloat = 1.5

    // Squish reproduction (double-click kill spawning babies)
    static let squishBabySpawnChance: Double = 0.4

    // Cursor reaction tuning
    static let fleeSpeedThreshold: CGFloat = 200

    // Gravity for the falling state (px/s², accelerative)
    static let fallGravity: CGFloat = 800

    // Window edge crawl (sticking to other apps' window borders)
    static let windowCrawlDetectionDistance: CGFloat = 80
    static let windowCrawlEdgeInset: CGFloat = 8
    static let windowCrawlChance: Double = 0.18

    // Poop trails
    static let poopMaxCount = 150
    static let poopChancePerFrame: Double = 0.003
    static let poopMinLifetime: TimeInterval = 30
    static let poopMaxLifetime: TimeInterval = 40
    static let poopMinSpeed: CGFloat = 0.3
}
