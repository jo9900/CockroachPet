import SwiftUI
import AppKit

@main
struct CockroachPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window scene — everything is managed via AppDelegate
        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @State private var maxCockroaches: Double = Double(Constants.maxCockroaches)
    @State private var growthMinutes: Double = Double(Constants.growthTimeMinutes)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CockroachPet 设置 / Settings")
                .font(.title2)
                .fontWeight(.bold)

            // Max cockroaches slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🪳 最大数量 / Max Cockroaches")
                    Spacer()
                    Text("\(Int(maxCockroaches))")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(value: $maxCockroaches, in: 1...99, step: 1) { editing in
                    if !editing {
                        Constants.setMaxCockroaches(Int(maxCockroaches))
                    }
                }
                Text("当前存活 / Currently alive: \(CockroachManager.shared.cockroaches.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Growth time slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🐣 幼虫成长时间 / Baby Growth Time")
                    Spacer()
                    Text("\(Int(growthMinutes)) 分 / min")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(value: $growthMinutes, in: 1...60, step: 1) { editing in
                    if !editing {
                        Constants.setGrowthTimeMinutes(Int(growthMinutes))
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Text("v2.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 360, height: 280)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var nightModeTimer: Timer?
    private var redEyeMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()

        // Start polling other apps' window bounds for window-edge crawl behavior.
        WindowTracker.shared.start()

        // Restore saved state or summon first cockroach
        let manager = CockroachManager.shared
        manager.restoreState()
        if manager.cockroaches.isEmpty {
            manager.summonCockroach()
        }
        manager.startClipboardMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // State is already saved in quitApp; this handles unexpected termination
        CockroachManager.shared.saveState()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🪳"

        nightModeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateMenuBarIcon()
        }
        updateMenuBarIcon()

        let menu = NSMenu()

        let summonItem = NSMenuItem(title: "🪳 召唤蟑螂 / Summon Cockroach", action: #selector(summonCockroach), keyEquivalent: "n")
        summonItem.target = self
        menu.addItem(summonItem)

        let killAllItem = NSMenuItem(title: "☠️ 全部消灭 / Kill All", action: #selector(killAllCockroaches), keyEquivalent: "k")
        killAllItem.target = self
        menu.addItem(killAllItem)

        let dropCakeItem = NSMenuItem(title: "🍰 聚餐模式 / Feeding Time", action: #selector(dropCake), keyEquivalent: "d")
        dropCakeItem.target = self
        menu.addItem(dropCakeItem)

        menu.addItem(NSMenuItem.separator())

        let redEyeItem = NSMenuItem(title: "🔴 红眼模式 / Red Eye Mode", action: #selector(toggleRedEyeMode), keyEquivalent: "r")
        redEyeItem.target = self
        redEyeItem.state = RedEyeModeManager.shared.isActive ? .on : .off
        menu.addItem(redEyeItem)
        redEyeMenuItem = redEyeItem

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "⚙️ 设置 / Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "❌ 退出 / Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateMenuBarIcon() {
        statusItem.button?.title = NightModeManager.shared.isNightMode ? "🪳🌙" : "🪳"
    }

    @objc private func dropCake() {
        CakeManager.shared.dropCake()
    }

    @objc private func toggleRedEyeMode() {
        RedEyeModeManager.shared.toggle()
        redEyeMenuItem?.state = RedEyeModeManager.shared.isActive ? .on : .off
    }

    @objc private func summonCockroach() {
        let manager = CockroachManager.shared
        if manager.cockroaches.count < Constants.maxCockroaches {
            manager.summonCockroach()
        }
    }

    @objc private func killAllCockroaches() {
        CockroachManager.shared.killAll()
    }

    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 280)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "CockroachPet 设置 / Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            NSApp.setActivationPolicy(.accessory)
            self?.settingsWindow = nil
        }
    }

    @objc private func quitApp() {
        // Save state first (before exit animation changes positions)
        CockroachManager.shared.saveState()
        // Play exit animation, then terminate
        CockroachManager.shared.exitAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.terminate(nil)
        }
    }
}
