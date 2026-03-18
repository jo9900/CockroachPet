# Electron Feature Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port 8 features from the Electron cockroach pet to the native macOS Swift version and fix the Settings menu bug.

**Architecture:** Extend existing state machine with 2 new states (playingDead, grooming), add 3 new singleton managers (NightModeManager, PoopManager, ClipboardMonitor embedded in CockroachManager), replace `isBaby: Bool` with `sizeVariant` enum, and add fear scatter + enhanced squish visuals. Settings bug fixed by creating a manual NSWindow instead of relying on broken sendAction selector.

**Tech Stack:** Swift 5.9, SwiftUI Canvas, AppKit (NSWindow, NSPanel, NSPasteboard, NSEvent)

**Spec:** `docs/superpowers/specs/2026-03-18-electron-feature-port-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `CockroachPetApp.swift` | Modify | Fix Settings window creation; night mode menu bar icon |
| `Cockroach.swift` | Modify | Add `playingDead`/`grooming` states; `SizeVariant` enum replacing `isBaby`; `groomPhase`; night mode speed multiplier; fear scatter transition |
| `CockroachView.swift` | Modify | Red eye glow; grooming leg animation; playing dead visual; large variant colors; enhanced squish splat |
| `CockroachManager.swift` | Modify | `fearScatter()`; clipboard monitor; large variant spawning logic |
| `CockroachWindow.swift` | No change | — |
| `MouseTracker.swift` | No change | — |
| `Constants.swift` | Modify | Poop constants; night mode hours |
| `NightModeManager.swift` | **Create** | Singleton: time-based night mode detection, speed multiplier, published state |
| `PoopManager.swift` | **Create** | Singleton: poop particle array, spawn/expire logic, full-screen rendering window |

---

### Task 1: Fix Settings Window Bug

**Files:**
- Modify: `CockroachPet/CockroachPetApp.swift:139-148` (openSettings method)
- Modify: `CockroachPet/CockroachPetApp.swift:75` (AppDelegate — add settingsWindow property)

- [ ] **Step 1: Replace `openSettings()` in AppDelegate**

The current implementation uses `NSApp.sendAction(Selector(("showSettingsWindow:")))` which fails in `.accessory` mode. Replace with a manually managed `NSWindow`:

```swift
// Add property to AppDelegate class
private var settingsWindow: NSWindow?

@objc private func openSettings() {
    // If window already exists, just bring it front
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
    window.title = "CockroachPet Settings"
    window.contentView = hostingView
    window.center()
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)

    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    self.settingsWindow = window

    // Watch for window close to revert activation policy
    NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification,
        object: window,
        queue: .main
    ) { [weak self] _ in
        NSApp.setActivationPolicy(.accessory)
        self?.settingsWindow = nil
    }
}
```

- [ ] **Step 2: Verify Settings window opens**

Build and run (Cmd+R in Xcode), click the menu bar 🪳 icon → Settings. The window should appear and be interactive. Closing it should hide the Dock icon again.

- [ ] **Step 3: Commit**

```bash
git add CockroachPet/CockroachPetApp.swift
git commit -m "fix: Settings window not opening in accessory mode"
```

---

### Task 2: Night Mode Manager

**Files:**
- Create: `CockroachPet/NightModeManager.swift`
- Modify: `CockroachPet/Constants.swift` (add night mode constants)

- [ ] **Step 1: Add night mode constants**

In `Constants.swift`, add inside the `Constants` enum:

```swift
static let nightStartHour = 20  // 8 PM
static let nightEndHour = 7     // 7 AM
static let nightSpeedMultiplier: CGFloat = 1.3
static let nightDashBoost: Double = 0.15
```

- [ ] **Step 2: Create NightModeManager.swift**

```swift
import Foundation
import Combine

final class NightModeManager: ObservableObject {
    static let shared = NightModeManager()

    @Published private(set) var isNightMode: Bool = false

    var speedMultiplier: CGFloat {
        isNightMode ? Constants.nightSpeedMultiplier : 1.0
    }

    private var timer: Timer?

    private init() {
        checkTime()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkTime()
        }
    }

    private func checkTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        let newValue = hour >= Constants.nightStartHour || hour < Constants.nightEndHour
        if newValue != isNightMode {
            isNightMode = newValue
        }
    }
}
```

- [ ] **Step 3: Add NightModeManager.swift to Xcode project**

The file must be added to the Xcode project's compile sources. Create the file at `CockroachPet/NightModeManager.swift`. Xcode should auto-detect it if it's in the same directory as other sources.

- [ ] **Step 4: Commit**

```bash
git add CockroachPet/NightModeManager.swift CockroachPet/Constants.swift
git commit -m "feat: add NightModeManager for time-based night mode"
```

---

### Task 3: Wire Night Mode into Cockroach AI

**Files:**
- Modify: `CockroachPet/Cockroach.swift:128-135` (transitionTo speed assignments)
- Modify: `CockroachPet/Cockroach.swift:449-461` (pickNextIdleBehavior)

- [ ] **Step 1: Apply speed multiplier in transitionTo**

In `Cockroach.swift`, in the `transitionTo` method, multiply all speed assignments by the night mode multiplier. For each case that sets `speed`:

```swift
case .patrol:
    speed = (isBaby ? 40 : 25) * NightModeManager.shared.speedMultiplier
    // ... rest unchanged
case .dash:
    speed = (isBaby ? 200 : 150) * NightModeManager.shared.speedMultiplier
    // ... rest unchanged
case .wallFollow:
    speed = (isBaby ? 35 : 20) * NightModeManager.shared.speedMultiplier
    // ... rest unchanged
case .fleeing:
    speed = (isBaby ? 250 : 180) * NightModeManager.shared.speedMultiplier
    // ... rest unchanged
case .curious:
    speed = (isBaby ? 20 : 12) * NightModeManager.shared.speedMultiplier
    // ... rest unchanged
case .exiting:
    speed = (isBaby ? 250 : 180) * NightModeManager.shared.speedMultiplier
case .entering:
    speed = (isBaby ? 60 : 40) * NightModeManager.shared.speedMultiplier
    // ... rest unchanged
case .flying:
    speed = (isBaby ? 300 : 220) * NightModeManager.shared.speedMultiplier
    // ... rest unchanged
```

- [ ] **Step 2: Boost dash probability at night**

In `pickNextIdleBehavior`, apply `nightDashBoost`:

```swift
private func pickNextIdleBehavior(screenBounds: CGRect) {
    let roll = Double.random(in: 0...1)
    let dashBoost = NightModeManager.shared.isNightMode ? Constants.nightDashBoost : 0
    if roll < 0.3 {
        transitionTo(.idle)
    } else if roll < 0.65 {
        transitionTo(.patrol)
        pickRandomTarget(within: screenBounds)
    } else if roll < 0.85 - dashBoost {
        transitionTo(.wallFollow)
    } else {
        transitionTo(.dash)
        pickRandomTarget(within: screenBounds)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add CockroachPet/Cockroach.swift
git commit -m "feat: apply night mode speed multiplier and dash boost to AI"
```

---

### Task 4: Night Mode Visuals (Red Eyes + Menu Bar Icon)

**Files:**
- Modify: `CockroachPet/CockroachView.swift:209-217` (eyes section)
- Modify: `CockroachPet/CockroachPetApp.swift:99-101` (menu bar setup)

- [ ] **Step 1: Red eye glow in CockroachView**

Replace the normal eyes drawing section (lines ~209-217) with night-mode-aware rendering:

```swift
// MARK: - Eyes
let eyeSize: CGFloat = 3.0 * scale
let isNight = NightModeManager.shared.isNightMode
for side in [-1.0, 1.0] {
    let eyeX = center.x + bodyW * 0.38
    let eyeY = center.y + CGFloat(side) * bodyH * 0.2 - raiseOffset - flyOffset

    if isNight {
        // Red glow background
        let glowSize = eyeSize * 3
        let glowRect = CGRect(x: eyeX - glowSize / 2, y: eyeY - glowSize / 2,
                              width: glowSize, height: glowSize)
        context.fill(Path(ellipseIn: glowRect),
                    with: .color(Color.red.opacity(0.3)))
        // Bright red eye
        let eyeRect = CGRect(x: eyeX - eyeSize / 2, y: eyeY - eyeSize / 2,
                              width: eyeSize, height: eyeSize)
        context.fill(Path(ellipseIn: eyeRect), with: .color(Color.red))
    } else {
        let eyeRect = CGRect(x: eyeX - eyeSize / 2, y: eyeY - eyeSize / 2,
                              width: eyeSize, height: eyeSize)
        context.fill(Path(ellipseIn: eyeRect), with: .color(.black))
    }
}
```

- [ ] **Step 2: Update menu bar icon for night mode**

In `AppDelegate.setupMenuBar()`, after setting up the status item, add a timer to update the icon:

```swift
// In setupMenuBar(), after statusItem.button?.title = "🪳"
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    self?.updateMenuBarIcon()
}
updateMenuBarIcon()
```

Add method to AppDelegate:

```swift
private func updateMenuBarIcon() {
    statusItem.button?.title = NightModeManager.shared.isNightMode ? "🪳🌙" : "🪳"
}
```

- [ ] **Step 3: Commit**

```bash
git add CockroachPet/CockroachView.swift CockroachPet/CockroachPetApp.swift
git commit -m "feat: red eye glow and moon menu icon during night mode"
```

---

### Task 5: Playing Dead State

**Files:**
- Modify: `CockroachPet/Cockroach.swift` (add state, update logic, idle behavior)
- Modify: `CockroachPet/CockroachView.swift` (visual for playing dead)

- [ ] **Step 1: Add `playingDead` to CockroachState enum**

In `Cockroach.swift`, add after `curious`:

```swift
case playingDead    // lying still, surprise dash if cursor approaches
```

- [ ] **Step 2: Add transition and update logic**

In `transitionTo`, add case:

```swift
case .playingDead:
    speed = 0
    stateDuration = Double.random(in: 3.0...8.0)
    // Curl legs slightly (reuse flipProgress at low value for leg curl)
    flipProgress = 0.3
```

In `update` switch, add case:

```swift
case .playingDead:
    updatePlayingDead(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed)
```

Add the update method:

```swift
private func updatePlayingDead(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat) {
    let dx = mousePosition.x - position.x
    let dy = mousePosition.y - position.y
    let dist = hypot(dx, dy)

    // Surprise! Dash away if cursor gets close
    if dist < 60 {
        flipProgress = 0
        transitionTo(.dash)
        angle = atan2(-dy, -dx)
        targetPosition = CGPoint(
            x: position.x + cos(angle) * 200,
            y: position.y + sin(angle) * 200
        )
        return
    }

    if stateTimer >= stateDuration {
        flipProgress = 0
        transitionTo(.idle)
    }
}
```

- [ ] **Step 3: Wire into pickNextIdleBehavior**

Adjust probabilities to include playingDead (8%):

```swift
private func pickNextIdleBehavior(screenBounds: CGRect) {
    let roll = Double.random(in: 0...1)
    let dashBoost = NightModeManager.shared.isNightMode ? Constants.nightDashBoost : 0
    if roll < 0.22 {
        transitionTo(.idle)
    } else if roll < 0.55 {
        transitionTo(.patrol)
        pickRandomTarget(within: screenBounds)
    } else if roll < 0.72 - dashBoost {
        transitionTo(.wallFollow)
    } else if roll < 0.80 - dashBoost {
        transitionTo(.playingDead)
    } else {
        transitionTo(.dash)
        pickRandomTarget(within: screenBounds)
    }
}
```

- [ ] **Step 4: Add visual in CockroachView**

Playing dead reuses the slight flip visual (legs slightly curled via `flipProgress = 0.3`). The existing leg rendering already handles this since `flipProgress > 0` triggers different leg angles. No additional view code needed — the existing flip logic handles the visual at `flipProgress = 0.3`.

- [ ] **Step 5: Commit**

```bash
git add CockroachPet/Cockroach.swift
git commit -m "feat: add playingDead state with surprise dash mechanic"
```

---

### Task 6: Grooming State

**Files:**
- Modify: `CockroachPet/Cockroach.swift` (add state, groomPhase property, update logic)
- Modify: `CockroachPet/CockroachView.swift` (grooming leg animation)

- [ ] **Step 1: Add state and property**

In `CockroachState` enum, add after `playingDead`:

```swift
case grooming       // cleaning antennae with front leg
```

Add property to `Cockroach` class:

```swift
@Published var groomPhase: CGFloat = 0
```

- [ ] **Step 2: Add transition and update logic**

In `transitionTo`:

```swift
case .grooming:
    speed = 0
    stateDuration = Double.random(in: 2.0...4.0)
    groomPhase = 0
```

In `update` switch:

```swift
case .grooming:
    updateGrooming(dt: dt, mousePosition: mousePosition, mouseSpeed: mouseSpeed)
```

Add update method:

```swift
private func updateGrooming(dt: TimeInterval, mousePosition: CGPoint, mouseSpeed: CGFloat) {
    groomPhase += CGFloat(dt) * 4.0  // cycling speed
    checkMouseReaction(mousePosition: mousePosition, mouseSpeed: mouseSpeed)
    if stateTimer >= stateDuration {
        transitionTo(.idle)
    }
}
```

- [ ] **Step 3: Wire into pickNextIdleBehavior**

Adjust probabilities to include grooming (12%):

```swift
private func pickNextIdleBehavior(screenBounds: CGRect) {
    let roll = Double.random(in: 0...1)
    let dashBoost = NightModeManager.shared.isNightMode ? Constants.nightDashBoost : 0
    if roll < 0.20 {
        transitionTo(.idle)
    } else if roll < 0.48 {
        transitionTo(.patrol)
        pickRandomTarget(within: screenBounds)
    } else if roll < 0.60 - dashBoost {
        transitionTo(.wallFollow)
    } else if roll < 0.68 - dashBoost {
        transitionTo(.playingDead)
    } else if roll < 0.80 - dashBoost {
        transitionTo(.grooming)
    } else {
        transitionTo(.dash)
        pickRandomTarget(within: screenBounds)
    }
}
```

- [ ] **Step 4: Add grooming animation in CockroachView**

In `CockroachView.swift`, inside the leg drawing loop, add special handling for the front-right leg during grooming:

After the existing leg drawing loop (after `context.stroke(legPath, ...)`), add:

```swift
// MARK: - Grooming animation (front leg reaches to antenna)
if cockroach.state == .grooming {
    let groomReach = sin(cockroach.groomPhase) * 0.5 + 0.5  // 0..1 cycling
    let groomBaseX = center.x + 0.28 * bodyW
    let groomBaseY = center.y - bodyH * 0.35 - raiseOffset - flyOffset

    // Leg reaches up toward antenna area
    let groomTipX = groomBaseX + bodyW * 0.3 + groomReach * bodyW * 0.15
    let groomTipY = groomBaseY - legLength * 0.3 - groomReach * legLength * 0.4
    let groomMidX = groomBaseX + bodyW * 0.15
    let groomMidY = groomBaseY - legLength * 0.4

    var groomPath = Path()
    groomPath.move(to: CGPoint(x: groomBaseX, y: groomBaseY))
    groomPath.addLine(to: CGPoint(x: groomMidX, y: groomMidY))
    groomPath.addLine(to: CGPoint(x: groomTipX, y: groomTipY))
    context.stroke(groomPath, with: .color(legColor), lineWidth: legWidth * 1.2)
}
```

- [ ] **Step 5: Commit**

```bash
git add CockroachPet/Cockroach.swift CockroachPet/CockroachView.swift
git commit -m "feat: add grooming state with front leg antenna cleaning animation"
```

---

### Task 7: Fear Scatter

**Files:**
- Modify: `CockroachPet/CockroachManager.swift` (add fearScatter method)
- Modify: `CockroachPet/Cockroach.swift` (call fearScatter when dying)

- [ ] **Step 1: Add fearScatter to CockroachManager**

```swift
func fearScatter(near point: CGPoint) {
    let scatterRadius: CGFloat = 200
    for cockroach in cockroaches {
        guard cockroach.state != .dead && cockroach.state != .dying && cockroach.state != .dragged else { continue }
        let dist = hypot(cockroach.position.x - point.x, cockroach.position.y - point.y)
        if dist < scatterRadius {
            let awayAngle = atan2(cockroach.position.y - point.y, cockroach.position.x - point.x)
            cockroach.transitionTo(.fleeing)
            cockroach.angle = awayAngle
            cockroach.targetPosition = CGPoint(
                x: cockroach.position.x + cos(awayAngle) * 200,
                y: cockroach.position.y + sin(awayAngle) * 200
            )
            cockroach.stateDuration = Double.random(in: 1.0...1.5)
        }
    }
}
```

- [ ] **Step 2: Trigger fear scatter when cockroach dies**

In `CockroachManager.tick()`, before removing dead cockroaches, trigger fear scatter:

```swift
// In tick(), right after the cockroach update loop, before toRemove processing:
for cockroach in cockroaches {
    // ... existing update code ...

    if cockroach.state == .dead {
        toRemove.append(cockroach.id)
    }

    // Trigger fear scatter when entering dying state
    if cockroach.state == .dying && cockroach.stateTimer < 0.02 {
        fearScatter(near: cockroach.position)
    }
}
```

Note: `stateTimer < 0.02` ensures scatter triggers only on the first frame of dying.

- [ ] **Step 3: Make stateTimer accessible**

`stateTimer` is already `var` (not private) in `Cockroach.swift`, so it's accessible from `CockroachManager`. No change needed.

- [ ] **Step 4: Commit**

```bash
git add CockroachPet/CockroachManager.swift
git commit -m "feat: add fear scatter — nearby cockroaches flee when one dies"
```

---

### Task 8: Enhanced Squish Animation

**Files:**
- Modify: `CockroachPet/Cockroach.swift` (improve dying transition)
- Modify: `CockroachPet/CockroachView.swift` (splat particles)

- [ ] **Step 1: Add splat particle data to Cockroach**

Add property:

```swift
var splatParticles: [(offset: CGPoint, opacity: CGFloat)] = []
```

In `transitionTo(.dying)`, generate splat particles:

```swift
case .dying:
    speed = 0
    isSquished = true
    scaleY = 0.15
    stateDuration = 2.0
    // Generate splat particles
    splatParticles = (0..<Int.random(in: 5...8)).map { _ in
        (offset: CGPoint(
            x: CGFloat.random(in: -20...20),
            y: CGFloat.random(in: -20...20)
        ), opacity: CGFloat(1.0))
    }
```

- [ ] **Step 2: Fade splat particles in updateDying**

```swift
private func updateDying(dt: TimeInterval) {
    opacity = max(0, opacity - CGFloat(dt) * 0.5)
    // Fade splat particles
    for i in splatParticles.indices {
        splatParticles[i].opacity = max(0, splatParticles[i].opacity - CGFloat(dt))
    }
    if opacity <= 0 {
        state = .dead
    }
}
```

- [ ] **Step 3: Render splat particles in CockroachView**

Add after the body drawing section (before eyes), when dying:

```swift
// MARK: - Splat particles
if cockroach.state == .dying || cockroach.state == .dead {
    let splatColor = Color(red: 0.35, green: 0.2, blue: 0.08)
    for particle in cockroach.splatParticles {
        let px = center.x + particle.offset.x * scale
        let py = center.y + particle.offset.y * scale - raiseOffset - flyOffset
        let pSize: CGFloat = 3 * scale
        let pRect = CGRect(x: px - pSize / 2, y: py - pSize / 2, width: pSize, height: pSize)
        context.fill(Path(ellipseIn: pRect), with: .color(splatColor.opacity(Double(particle.opacity))))
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add CockroachPet/Cockroach.swift CockroachPet/CockroachView.swift
git commit -m "feat: enhanced squish animation with splat particles"
```

---

### Task 9: Size Variants

**Files:**
- Modify: `CockroachPet/Cockroach.swift` (SizeVariant enum, replace isBaby, colors)
- Modify: `CockroachPet/CockroachView.swift` (large variant colors, scale)
- Modify: `CockroachPet/CockroachManager.swift` (10% large spawn chance)

- [ ] **Step 1: Add SizeVariant enum and replace isBaby**

In `Cockroach.swift`, add before the class:

```swift
enum SizeVariant: String, Codable {
    case baby
    case normal
    case large
}
```

In `Cockroach` class, replace `@Published var isBaby: Bool` with:

```swift
@Published var sizeVariant: SizeVariant
```

Update computed `size`:

```swift
var size: CGFloat {
    switch sizeVariant {
    case .baby: return Constants.cockroachSize / 3
    case .normal: return Constants.cockroachSize
    case .large: return Constants.cockroachSize * 1.5
    }
}

var isBaby: Bool { sizeVariant == .baby }
var isLarge: Bool { sizeVariant == .large }

var speedScale: CGFloat {
    switch sizeVariant {
    case .baby: return 1.3   // babies are fast
    case .normal: return 1.0
    case .large: return 1.1  // large slightly faster
    }
}
```

Update `init`:

```swift
init(id: UUID = UUID(), position: CGPoint, sizeVariant: SizeVariant = .normal) {
    self.id = id
    self.position = position
    self.sizeVariant = sizeVariant
}
```

- [ ] **Step 2: Update all speed references to use speedScale**

In `transitionTo`, replace `isBaby ? X : Y` patterns with speed scale:

```swift
case .patrol:
    speed = 25 * speedScale * NightModeManager.shared.speedMultiplier
```

Apply same pattern to: `.dash` (base 150), `.wallFollow` (base 20), `.fleeing` (base 180), `.curious` (base 12), `.exiting` (base 180), `.entering` (base 40), `.flying` (base 220).

- [ ] **Step 3: Update growUp method**

```swift
private func growUp() {
    sizeVariant = .normal  // babies always grow to normal, not large
    transitionTo(.idle)
}
```

- [ ] **Step 4: Update baby growth check**

```swift
if sizeVariant == .baby {
    let growthSeconds = TimeInterval(Constants.growthTimeMinutes * 60)
    if Date().timeIntervalSince(bornAt) >= growthSeconds {
        growUp()
    }
}
```

- [ ] **Step 5: Update SaveData**

```swift
struct SaveData: Codable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let sizeVariant: SizeVariant
}

func toSaveData() -> SaveData {
    SaveData(id: id.uuidString, x: position.x, y: position.y, sizeVariant: sizeVariant)
}

static func fromSaveData(_ data: SaveData) -> Cockroach {
    let roach = Cockroach(
        id: UUID(uuidString: data.id) ?? UUID(),
        position: CGPoint(x: data.x, y: data.y),
        sizeVariant: data.sizeVariant
    )
    roach.state = .idle
    roach.transitionTo(.idle)
    return roach
}
```

- [ ] **Step 6: Update CockroachView for large variant colors**

In `CockroachView.swift`, update color logic:

```swift
let bodyColor: Color
switch cockroach.sizeVariant {
case .baby:
    bodyColor = Color(red: 0.72, green: 0.52, blue: 0.32)   // lighter brown
case .normal:
    bodyColor = Color(red: 0.45, green: 0.25, blue: 0.1)    // dark brown
case .large:
    bodyColor = Color(red: 0.35, green: 0.18, blue: 0.05)   // even darker
}
```

Update scale:

```swift
let scale: CGFloat
switch cockroach.sizeVariant {
case .baby: scale = 0.33
case .normal: scale = 1.0
case .large: scale = 1.5
}
```

- [ ] **Step 7: Update CockroachManager spawning**

In `summonCockroach()`:

```swift
func summonCockroach() {
    guard cockroaches.count < Constants.maxCockroaches else { return }

    let screenBounds = NSScreen.main?.visibleFrame ?? .zero
    let startX = CGFloat.random(in: screenBounds.minX + 50...screenBounds.maxX - 50)
    let startY = screenBounds.minY

    // 10% chance of large variant
    let variant: SizeVariant = Double.random(in: 0...1) < 0.1 ? .large : .normal
    let roach = Cockroach(position: CGPoint(x: startX, y: startY), sizeVariant: variant)
    roach.transitionTo(.entering)
    addCockroach(roach)
}
```

In `spawnBabies`:

```swift
let baby = Cockroach(position: babyPos, sizeVariant: .baby)
```

- [ ] **Step 8: Commit**

```bash
git add CockroachPet/Cockroach.swift CockroachPet/CockroachView.swift CockroachPet/CockroachManager.swift
git commit -m "feat: add size variants — 10% large cockroaches with darker colors"
```

---

### Task 10: Poop Trail System

**Files:**
- Create: `CockroachPet/PoopManager.swift`
- Modify: `CockroachPet/Constants.swift` (poop constants)
- Modify: `CockroachPet/CockroachManager.swift` (integrate poop spawning and window)

- [ ] **Step 1: Add poop constants**

In `Constants.swift`:

```swift
static let poopMaxCount = 150
static let poopChancePerFrame: Double = 0.003
static let poopMinLifetime: TimeInterval = 30
static let poopMaxLifetime: TimeInterval = 40
static let poopMinSpeed: CGFloat = 0.3
```

- [ ] **Step 2: Create PoopManager.swift**

```swift
import AppKit
import SwiftUI

struct PoopParticle {
    let position: CGPoint
    let birthTime: TimeInterval
    let lifetime: TimeInterval
}

final class PoopManager {
    static let shared = PoopManager()

    private(set) var particles: [PoopParticle] = []
    private var window: NSPanel?
    private var hostingView: NSHostingView<PoopCanvasView>?

    private init() {
        setupWindow()
    }

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let canvasView = PoopCanvasView(manager: self)
        let hosting = NSHostingView(rootView: canvasView)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = hosting
        panel.orderFront(nil)

        self.window = panel
        self.hostingView = hosting
    }

    func update(cockroaches: [Cockroach]) {
        let now = CACurrentMediaTime()

        // Remove expired particles
        particles.removeAll { now - $0.birthTime >= $0.lifetime }

        // Spawn new poop from moving cockroaches
        for cockroach in cockroaches {
            guard cockroach.speed >= Constants.poopMinSpeed,
                  cockroach.state != .dead && cockroach.state != .dying && cockroach.state != .dragged && cockroach.state != .falling,
                  particles.count < Constants.poopMaxCount,
                  Double.random(in: 0...1) < Constants.poopChancePerFrame else { continue }

            let particle = PoopParticle(
                position: cockroach.position,
                birthTime: now,
                lifetime: TimeInterval.random(in: Constants.poopMinLifetime...Constants.poopMaxLifetime)
            )
            particles.append(particle)
        }

        // Refresh the canvas
        if let hosting = hostingView {
            hosting.rootView = PoopCanvasView(manager: self)
        }
    }
}

struct PoopCanvasView: View {
    let manager: PoopManager

    var body: some View {
        Canvas { context, size in
            let now = CACurrentMediaTime()
            let screen = NSScreen.main?.frame ?? .zero

            for particle in manager.particles {
                let age = now - particle.birthTime
                let lifeRatio = age / particle.lifetime
                let alpha = max(0, 0.6 * (1.0 - lifeRatio))

                // Convert screen coords to view coords (flip Y)
                let x = particle.position.x - screen.minX
                let y = size.height - (particle.position.y - screen.minY)

                let dotSize: CGFloat = 2.5
                let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 0.29, green: 0.14, blue: 0.03).opacity(alpha))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 3: Integrate into CockroachManager tick**

In `CockroachManager.tick()`, after updating all cockroaches and before removing dead ones:

```swift
// Update poop particles
PoopManager.shared.update(cockroaches: cockroaches)
```

- [ ] **Step 4: Commit**

```bash
git add CockroachPet/PoopManager.swift CockroachPet/Constants.swift CockroachPet/CockroachManager.swift
git commit -m "feat: add poop trail system with fading particles"
```

---

### Task 11: Clipboard Summoning

**Files:**
- Modify: `CockroachPet/CockroachManager.swift` (clipboard monitor)

- [ ] **Step 1: Add clipboard monitoring to CockroachManager**

Add properties:

```swift
private var clipboardTimer: Timer?
private var lastClipboardCount: Int = 0
```

Add method:

```swift
func startClipboardMonitor() {
    lastClipboardCount = NSPasteboard.general.changeCount
    clipboardTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        self?.checkClipboard()
    }
}

private func checkClipboard() {
    let currentCount = NSPasteboard.general.changeCount
    if currentCount != lastClipboardCount {
        lastClipboardCount = currentCount
        summonCockroach()
    }
}
```

- [ ] **Step 2: Start monitor in AppDelegate**

In `CockroachPetApp.swift`, in `applicationDidFinishLaunching`, after existing code:

```swift
manager.startClipboardMonitor()
```

- [ ] **Step 3: Commit**

```bash
git add CockroachPet/CockroachManager.swift CockroachPet/CockroachPetApp.swift
git commit -m "feat: clipboard change summons a new cockroach"
```

---

### Task 12: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update CLAUDE.md**

Update the state machine diagram to show 18 states, add notes about new files (`NightModeManager.swift`, `PoopManager.swift`), update the architecture section to mention night mode, poop trails, size variants, clipboard summoning, and fear scatter.

- [ ] **Step 2: Update docs/changelog**

Create or update `docs/changelog-0.2.0.md` with all changes made.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md docs/changelog-0.2.0.md
git commit -m "docs: update CLAUDE.md and changelog for v0.2.0 features"
```
