# 🪳 CockroachPet

A desktop pet cockroach for macOS. It roams your screen, reacts to your cursor, and is nearly impossible to get rid of — just like the real thing.

![macOS](https://img.shields.io/badge/macOS-14.0+-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)

## Features

- 🪳 **Realistic AI behavior** — patrol, idle, wall-following, sudden dashes
- 🖱️ **Mouse interaction** — cockroaches react to cursor proximity and speed
  - Move slowly → they get alert
  - Move fast → they flee
  - Stay still → they get curious and approach
- ✋ **Click interactions**
  - Single click → flip on their back (they'll struggle and recover)
  - Double click → 80% recover / 20% egg sac burst (3-5 baby cockroaches!)
  - Drag → pick them up, legs flailing. Release to drop
- ✈️ **Flight** — corner a cockroach near a screen edge and it will spread its wings and fly away
- 🐣 **Baby cockroaches** — hatch from egg sacs, grow into adults over time (default: 10 min)
- ☠️ **Kill All** — one button to eliminate them all (menu bar)
- 💾 **Persistence** — cockroaches survive app restarts
- ⚙️ **Settings** — customize max population (1-99) and baby growth time (1-60 min)

## Screenshots

*Coming soon*

## Installation

### From Source

1. Clone the repository
2. Open `CockroachPet.xcodeproj` in Xcode
3. Build and run (⌘R)

### Requirements

- macOS 14.0+
- Xcode 15.0+

## How It Works

CockroachPet is a menu bar app (no Dock icon). Each cockroach lives in its own transparent `NSPanel` window floating above all other windows.

### Architecture

| File | Description |
|------|-------------|
| `CockroachPetApp.swift` | App entry point, menu bar setup, Settings view |
| `Cockroach.swift` | AI state machine (16 states), mouse reaction, persistence |
| `CockroachView.swift` | Vector rendering via SwiftUI Canvas |
| `CockroachWindow.swift` | Transparent floating NSWindow, mouse event handling |
| `CockroachManager.swift` | Singleton manager — spawning, animation loop, state |
| `MouseTracker.swift` | Global cursor position and speed tracking |
| `Constants.swift` | User-configurable settings backed by UserDefaults |

### State Machine

```
entering → idle ⇄ patrol ⇄ dash
                ⇄ wallFollow
                ⇄ alert → fleeing
                ⇄ curious
           idle → flying (when cornered)
           
(any) → flipped → struggling → idle
(any) → dragged → falling → flipped
double-click → dying → dead (+ spawn babies)
```

### Rendering

Cockroaches are drawn programmatically using SwiftUI Canvas — no sprite sheets required. This means:

- Smooth scaling (babies are 1/3 size with no quality loss)
- Fluid leg/antenna animation computed per frame
- Wings appear dynamically during flight state

## Menu Bar

| Item | Shortcut | Description |
|------|----------|-------------|
| 🪳 Summon | ⌘N | Spawn a new cockroach |
| ☠️ Kill All | ⌘K | Eliminate all cockroaches |
| ⚙️ Settings | ⌘, | Open settings window |
| ❌ Quit | ⌘Q | Save state and exit |

## Roadmap

- [ ] Night mode (more active after 23:00)
- [ ] Cockroach social behavior
- [ ] Sound effects
- [ ] App Store release
- [ ] App icon

## License

MIT

---

*No real cockroaches were harmed in the making of this app.* 🪳
