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
            Text("CockroachPet Settings")
                .font(.title2)
                .fontWeight(.bold)

            // Max cockroaches slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🪳 Max Cockroaches")
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
                Text("Current: \(CockroachManager.shared.cockroaches.count) alive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Growth time slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🐣 Baby Growth Time")
                    Spacer()
                    Text("\(Int(growthMinutes)) min")
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
                Text("v0.1.0")
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()

        // Restore saved state or summon first cockroach
        let manager = CockroachManager.shared
        manager.restoreState()
        if manager.cockroaches.isEmpty {
            manager.summonCockroach()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // State is already saved in quitApp; this handles unexpected termination
        CockroachManager.shared.saveState()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🪳"

        let menu = NSMenu()

        let summonItem = NSMenuItem(title: "🪳 Summon Cockroach", action: #selector(summonCockroach), keyEquivalent: "n")
        summonItem.target = self
        menu.addItem(summonItem)

let killAllItem = NSMenuItem(title: "☠️ Kill All", action: #selector(killAllCockroaches), keyEquivalent: "k")
        killAllItem.target = self
        menu.addItem(killAllItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "⚙️ Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "❌ Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        // Open the SwiftUI Settings scene
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // Revert to accessory after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
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
