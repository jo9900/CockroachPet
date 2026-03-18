# Feature Port: Pet-Electron → CockroachPet (macOS)

## Overview

Port 8 features from the Electron cockroach pet to the native macOS Swift version, plus fix the Settings menu bug.

## Bug Fix: Settings Window

**Root cause**: `NSApp.sendAction(Selector(("showSettingsWindow:")))` fails because `.accessory` activation policy has no window in the responder chain to handle that selector. Additionally, the code reverts to `.accessory` after 0.5s, which closes the Settings window.

**Fix**: Replace with `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` → use `SettingsLink` approach or manually create an `NSWindow` hosting `SettingsView`. The simplest reliable approach: create a standalone `NSWindow` with `NSHostingView<SettingsView>`, managed by `AppDelegate`. Activate the app, show the window, and keep `.regular` policy while the window is open.

## Feature 1: Red-Eye Mode (Night Mode)

**Trigger**: Automatic between 20:00–07:00 based on system clock.

**Changes**:
- New `NightModeManager` singleton — `Timer` checks time every 60s, publishes `isNightMode: Bool`
- **Visual**: Eyes glow red (`#FF0000` with `shadow(.drop(...))` glow) in `CockroachView`
- **Behavior**: `speedMultiplier = 1.3` applied to all movement speeds; dash probability +0.15 in `pickNextIdleBehavior`
- **Menu bar**: Tray icon switches to "🪳🌙" during night mode
- **Constants**: `nightStartHour = 20`, `nightEndHour = 7` (hardcoded, not user-configurable)

## Feature 2: Poop Trails

**New files**: `PoopManager.swift`, `PoopWindow.swift`

- `PoopManager` singleton manages up to 150 `PoopParticle` structs (position, birthTime, lifetime 30–40s)
- Each frame, 0.3% chance per moving cockroach to drop a poop particle at its position
- `PoopWindow`: Single full-screen transparent `NSPanel` with SwiftUI `Canvas` rendering all poop dots
- Rendering: brown semi-transparent circles (#4A2508, radius 2px, alpha fading with age)
- Particles removed when lifetime expires

## Feature 3: Playing Dead

**New state**: `playingDead` added to `CockroachState` enum.

- 8% probability from `pickNextIdleBehavior` (reduce patrol to compensate)
- Duration: 3–8 seconds, speed = 0, legs curl inward (rendered like flipped but face-down)
- If cursor approaches within 60px during play-dead → immediate `dash` away (surprise mechanic)
- Otherwise transitions back to `idle` after duration

## Feature 4: Grooming

**New state**: `grooming` added to `CockroachState` enum.

- 12% probability from `pickNextIdleBehavior` (reduce wallFollow to compensate)
- Duration: 2–4 seconds, speed = 0
- Animation: front leg reaches toward antenna area with sine-wave cycling motion
- New `groomPhase: CGFloat` property on `Cockroach` for animation tracking
- `CockroachView` draws special front leg position during grooming state

## Feature 5: Squish Animation (Enhanced Dying)

Enhance existing `dying` state visual instead of adding a new state.

- On `handleDoubleClick` kill: scaleY animates 1.0 → 0.15 over 0.3s, scaleX → 1.6 (already partially implemented via `isSquished`/`scaleY`)
- Add splat particle effect: 5–8 small brown dots scatter outward from body center, fade over 1s
- Managed within `CockroachView` using cockroach's state timer

## Feature 6: Fear Scatter

**New method** on `CockroachManager`: `fearScatter(near: CGPoint)`.

- Called when a cockroach enters `dying` state
- All cockroaches within 200px immediately `transitionTo(.fleeing)` away from the death point
- Flee duration: 1–1.5 seconds

## Feature 7: Size Variants

**New property** on `Cockroach`: `sizeVariant: SizeVariant` enum (`.normal`, `.large`, `.baby`).

- 10% chance on `summonCockroach` to create large variant
- Large: 1.5x visual scale, 1.1x speed multiplier, darker body colors
- Replaces current `isBaby` boolean with the enum
- `SaveData` updated to persist size variant
- Babies still grow into normal (not large)

## Feature 8: Clipboard Summoning

**New method** on `CockroachManager`: `startClipboardMonitor()`.

- Poll `NSPasteboard.general.changeCount` every 2 seconds via `Timer`
- On change: `summonCockroach()` (respects max population limit)
- Started in `applicationDidFinishLaunching`

## File Changes Summary

| File | Changes |
|------|---------|
| `CockroachPetApp.swift` | Fix Settings window; update menu bar icon for night mode |
| `Cockroach.swift` | Add `playingDead`, `grooming` states; `sizeVariant` enum; `groomPhase`; night mode speed multiplier |
| `CockroachView.swift` | Red eye glow; grooming animation; playing dead visual; large variant colors; enhanced squish |
| `CockroachManager.swift` | `fearScatter()`; clipboard monitor; size variant spawning |
| `Constants.swift` | Night mode hours; poop constants |
| **New**: `NightModeManager.swift` | Night mode singleton |
| **New**: `PoopManager.swift` | Poop particle system |
| **New**: `PoopWindow.swift` | Full-screen poop rendering window |

## State Machine (Updated — 18 states)

```
entering → idle ⇄ patrol ⇄ dash
                ⇄ wallFollow
                ⇄ alert → fleeing
                ⇄ curious
                ⇄ playingDead (→ dash if cursor near)
                ⇄ grooming
           idle → flying (when cornered)

(any) → flipped → struggling → idle
(any) → dragged → falling → flipped
double-click → dying → dead (+ spawn babies + fear scatter)
```
