# Changelog — v1.0

## fix: Settings window not opening in accessory mode

- Replaced `NSApp.sendAction(Selector(("showSettingsWindow:")))` call (which has no responder in `.accessory` policy) with a manually constructed `NSWindow` hosting `SettingsView`.
- Added `settingsWindow: NSWindow?` property to `AppDelegate` to track the window and prevent duplicates.
- Window reuse: if the settings window is already visible, it is brought to front instead of creating a new one.
- Activation policy is set to `.regular` when the window opens and reverted to `.accessory` when it closes, via `NSWindow.willCloseNotification`.
