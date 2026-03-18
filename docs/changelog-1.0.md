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

## feat: add fear scatter and enhanced squish with splat particles

- When a cockroach dies, nearby cockroaches within 200pt scatter away in the opposite direction (fear scatter), triggered on the first frame of the dying state.
- Added `fearScatter(near:)` method to `CockroachManager` that transitions nearby living cockroaches to `.fleeing` with an away-angle trajectory.
- Enhanced squish animation: `scaleY` reduced from 0.3 to 0.15 for a flatter death look.
- Dying cockroaches now generate 5-8 splat particles (small brown ellipses) at random offsets, which fade out over 1 second.
- Splat particles rendered in `CockroachView` before the eyes layer so they appear beneath the body.

## feat: add poop trail system with fading particles

- Added `PoopManager` singleton that owns a full-screen transparent `NSPanel` overlay at `.floating` level.
- Cockroaches moving at or above `poopMinSpeed` (0.3) have a `poopChancePerFrame` (0.003) chance each frame to spawn a `PoopParticle` at their current position.
- Particles excluded from dead, dying, dragged, and falling cockroaches.
- Up to `poopMaxCount` (150) particles alive simultaneously; each lives 30–40 seconds and fades from 60% to 0% opacity over its lifetime.
- Rendered as 2.5pt dark-brown ellipses in a SwiftUI `Canvas` that ignores mouse events.
- New poop constants added to `Constants.swift`; `PoopManager.shared.update(cockroaches:)` called once per tick in `CockroachManager`.

## feat: add size variants — 10% large cockroaches with darker colors

- Replaced `isBaby: Bool` stored property with a `SizeVariant` enum (`.baby`, `.normal`, `.large`) across `Cockroach`, `CockroachView`, and `CockroachManager`.
- `isBaby` is now a computed property (`sizeVariant == .baby`), so existing baby-reading code works unchanged.
- Added `isLarge` computed property and `speedScale` (baby 1.3x, normal 1.0x, large 1.1x) to replace per-state ternary speed expressions.
- All speed assignments in `transitionTo` now use `baseSpeed * speedScale * nightMultiplier` instead of `(isBaby ? X : Y)`.
- Large cockroaches render at 1.5x scale with a darker body color (`0.35/0.18/0.05`).
- `summonCockroach()` now spawns large cockroaches with 10% probability.
- `SaveData` persists `sizeVariant` instead of `isBaby` (breaking change for saved state).
