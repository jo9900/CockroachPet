# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CockroachPet is a native macOS menu bar desktop pet app. Cockroaches roam the screen, react to cursor movement, and can be clicked, dragged, flipped, and killed. Built entirely in Swift/SwiftUI with no external dependencies.

- **Platform**: macOS 14.0+ (Sonoma)
- **Language**: Swift 5.9+
- **Frameworks**: SwiftUI, AppKit (no external packages)
- **App mode**: `.accessory` (menu bar only, no Dock icon)
- **Bundle ID**: `com.jo.cockroachpet.app`

## Build & Run

Open `CockroachPet.xcodeproj` in Xcode 15+ and run (Cmd+R). No package manager setup needed.

```bash
# Build from command line
xcodebuild -project CockroachPet.xcodeproj -scheme CockroachPet -configuration Debug build

# Build and run (release)
xcodebuild -project CockroachPet.xcodeproj -scheme CockroachPet -configuration Release build
```

There are no tests, linting, or formatting tools configured.

## Architecture

All source lives in `CockroachPet/`. Nine Swift files, each with a clear responsibility:

### Core Loop

`CockroachManager` (singleton) drives everything:
1. Maintains the array of all `Cockroach` instances
2. Runs a 60fps animation loop via `Timer` + `CACurrentMediaTime` delta
3. Each tick: updates every cockroach's AI state, updates poop particles, refreshes windows
4. Handles spawning (10% large variant), killing, fear scatter, persistence (save/restore via UserDefaults)
5. Monitors clipboard — pasting anything summons a new cockroach

### Per-Cockroach Stack

Each cockroach is three objects working together:
- **`Cockroach`** — AI brain. An 18-state finite state machine that decides movement, reactions to mouse, and transitions. Contains all position/velocity/state data. Codable for persistence. Size is governed by `SizeVariant` enum (`.baby`, `.normal`, `.large`) with per-variant speed scaling via `speedScale`.
- **`CockroachWindow`** — An `NSPanel` (transparent, borderless, floating, click-through on transparent areas). Handles mouse click/drag events and forwards them to its `Cockroach`.
- **`CockroachView`** — SwiftUI `Canvas` that vector-draws the cockroach body, legs, antennae, wing casings, and eyes. No sprites; all procedural. Scale and color vary by `SizeVariant` (baby 0.33x light brown, normal 1.0x dark brown, large 1.5x darkest brown).

### Supporting Files

- **`MouseTracker`** — Singleton. Global `NSEvent` monitor tracking cursor position and speed. Cockroaches read this to decide alert/flee/curious behavior.
- **`Constants`** — User-configurable settings (max population, baby growth time) backed by `UserDefaults` with `@AppStorage`. Also holds night mode constants (hours, speed multiplier, dash boost).
- **`NightModeManager`** — Singleton. Checks the current hour every 60s and exposes `isNightMode` and `speedMultiplier`. Cockroach AI and view rendering both read this to adjust speed and visuals at night.
- **`PoopManager`** — Singleton. Owns a full-screen transparent `NSPanel` overlay. Each tick, moving cockroaches have a 0.3% chance to drop a poop particle. Up to 150 particles, each fading over 30-40s. Rendered as brown dots via SwiftUI Canvas.
- **`CockroachPetApp`** — App entry point. Sets up menu bar with Summon/Kill All/Settings/Quit. Contains the SwiftUI Settings view. Menu icon updates to show moon emoji during night mode. Settings window is manually managed via `NSWindow` (not SwiftUI Settings scene) to work in `.accessory` mode.

### State Machine (18 states)

```
entering → idle ⇄ patrol ⇄ dash
                ⇄ wallFollow
                ⇄ alert → fleeing
                ⇄ curious
                ⇄ playingDead (surprise dash if cursor approaches)
                ⇄ grooming (antenna cleaning animation)
           idle → flying (when cornered near screen edge)

(any) → flipped → struggling → idle
(any) → dragged → falling → flipped
double-click → dying → dead (+ spawn babies + fear scatter nearby)
```

### Key Design Decisions

- **One NSPanel per cockroach**: Each cockroach gets its own transparent window so it can float above all apps independently. The window is sized to the cockroach's bounding box and repositioned each frame.
- **Vector rendering, not sprites**: All drawing is code in SwiftUI Canvas. This allows smooth scaling (babies are 1/3 size), dynamic wing animation, and no asset management.
- **App Sandbox disabled**: The app needs unrestricted global mouse event access (`NSEvent.addGlobalMonitorForEvents`), which requires the sandbox to be off.
- **Persistence via UserDefaults**: Cockroach state (position, sizeVariant, birth time for babies) is saved on quit and restored on launch. No Core Data or files.
- **Night mode (20:00-07:00)**: `NightModeManager` singleton drives 1.3x speed multiplier, increased dash probability, red glowing eyes, and moon emoji in menu bar.
- **Fear scatter**: When a cockroach dies, all cockroaches within 200px flee in the opposite direction.
- **Clipboard summoning**: `CockroachManager` polls `NSPasteboard.general.changeCount` every 2s — any clipboard change spawns a new cockroach.

## Planned Features

See `TODO.md` and `DESIGN.md` for details:
- Cockroach social behavior
- Sound effects
- App Store submission
