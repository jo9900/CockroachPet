# Changelog — v1.0

## fix: Settings window not opening in accessory mode

- Replaced `NSApp.sendAction(Selector(("showSettingsWindow:")))` call (which has no responder in `.accessory` policy) with a manually constructed `NSWindow` hosting `SettingsView`.
- Added `settingsWindow: NSWindow?` property to `AppDelegate` to track the window and prevent duplicates.
- Window reuse: if the settings window is already visible, it is brought to front instead of creating a new one.
- Activation policy is set to `.regular` when the window opens and reverted to `.accessory` when it closes, via `NSWindow.willCloseNotification`.

## feat: Wire night mode into AI, add red eyes, playingDead and grooming states

- All speed assignments in `Cockroach.transitionTo` now multiply by `NightModeManager.shared.speedMultiplier`, making cockroaches 30% faster at night.
- Added `playingDead` state: cockroach lies partially flipped; surprise-dashes away if cursor approaches within 60pt.
- Added `grooming` state: cockroach stays still and animates a front leg cleaning its antennae.
- `pickNextIdleBehavior` rebalanced with night-mode dash boost; new states integrated into the probability table.
- `CockroachView` eyes now glow red at night (red fill + red glow halo). Normal eyes remain black during daytime.
- Added grooming leg animation to `CockroachView` (extra articulated limb drawn when in grooming state).
- Menu bar icon updates every 60s to show moon emoji during night mode.
- Added `NightModeManager.swift` to the Xcode project build target (was previously missing).
