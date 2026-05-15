# Changelog — v2.0.0

## 2026-05-15

This is a feature-parity bump that pulls behaviors from the parallel Electron
build of CockroachPet (v1.1.0) and adds a brand-new interaction: cockroaches
crawling along the edges of other apps' open windows.

### New: window edge crawl

- Added `WindowTracker` (singleton) that polls `CGWindowListCopyWindowInfo`
  once a second to cache the bounds of every visible window owned by another
  app. Filters out our own windows, menubar/Dock layers (layer != 0), invisible
  windows, and tiny windows (< 200×150). Coordinates are flipped from CG
  top-left to AppKit bottom-left.
- Added `CockroachState.windowCrawl` and `Cockroach.updateWindowCrawl(...)`.
  When idle decides what to do next, there is a 18% chance to look for a
  window edge within 80 px and, if found, transition to `windowCrawl` and walk
  along that edge (top / bottom / left / right) for 4–9 s. Movement uses the
  same speed scale as `wallFollow` plus a slight angle wobble for life.
- The state cleans up gracefully: if the target window is moved/resized so
  much that it no longer matches its snapshot, or the cockroach walks past a
  corner, the cockroach returns to `idle`. Cursor proximity still steals it
  into `alert` / `fleeing` first.
- Sandbox is still disabled (`com.apple.security.app-sandbox = false`) so
  CGWindowList returns full window metadata without Screen Recording prompts.

### New: independent Red Eye Mode

- Added `RedEyeModeManager` (singleton) — a manually togglable mood that gives
  cockroaches a night-mode speed/aggression boost regardless of the clock.
  Setting persists in `UserDefaults` (`redEyeModeEnabled`).
- Added menubar item "🔴 Red Eye Mode" (⌘R) with a checkmark reflecting the
  current state. Toggling refreshes the menubar icon.
- Added `ActiveBuffs` helper that merges night mode and red-eye contributions
  for `speedMultiplier`, `dashBoost`, and `redEyesVisible`. They stack by
  taking the max, so red-eye during day matches a true night, and during night
  it doesn't double-buff.
- The cockroach's red eye render path now keys off `ActiveBuffs.redEyesVisible`
  instead of `NightModeManager.isNightMode` alone.
- Menubar icon stays as the original two-state 🪳 / 🪳🌙. Red eye state is shown
  by the checkmark on the menu item rather than as a separate icon variant —
  the icon strip stays calm.

### Tuning constants

- `Constants.redEyeSpeedMultiplier = 1.3` (matches `nightSpeedMultiplier`).
- `Constants.windowCrawlDetectionDistance = 80`.
- `Constants.windowCrawlEdgeInset = 8`.
- `Constants.windowCrawlChance = 0.18`.

### Behavior tuning to match Electron 1.1.0

The first cut of 2.0 only picked up the structurally-missing features and
left native's old tuning values intact. A second pass aligned the user-facing
numbers with the Electron build so the two feel like the same animal:

- `nightSpeedMultiplier` 1.3 → 1.5. Red eye uses the same multiplier.
- `squishBabySpawnChance` 0.20 → 0.40 (double-click kill now spawns babies
  40% of the time, matching Electron's `BABY_SPAWN_CHANCE`).
- New `fleeSpeedThreshold = 200` (px/s). `checkMouseReaction` and `updateAlert`
  used to trigger fleeing at 100 px/s, which made cockroaches twitchy. 200
  matches Electron and feels less reactive to slow cursor drift.
- New `fallGravity = 800` (px/s²). The `falling` state now uses real
  accumulating gravity via the new `Cockroach.fallVelocity` property instead
  of a constant 400 px/s. Drops accelerate and feel weightier.
- New `nightAutoSpawnInterval = 45 s`. Whenever red eye mode or clock-driven
  night mode is active, `CockroachManager` pushes out a new cockroach from a
  random screen edge every 45 seconds (capped by `maxCockroaches`). Mirrors
  Electron's `NIGHT_SPAWN_INTERVAL`. Implementation lives in
  `updateNightAutoSpawn(dt:)` and `spawnAtRandomEdge()`.

### Knowingly skipped (not worth diverging from native's choices)

- Electron's separate `wander` / `freeze` / `spawning` / `baby` states are
  functional duplicates of native's `idle` / `patrol` / `dying.spawnBabies` /
  `sizeVariant=.baby`. No user-visible difference.
- Native's `entering` / `struggling` / `exiting` states are native-only
  flourishes; the Electron build never had them. Kept as-is.
- Drag trigger remains "moved > 5 px" (native), not "held > 200 ms" (Electron).
  Movement-based is more discoverable.
- Initial spawn count stays at 1 (native) rather than Electron's 2-adults +
  1-baby triplet.

### New: Feeding Mode (🍰 cake)

- New `CakeManager` (singleton + small draggable `CakeWindow`). Menu bar item
  "🍰 聚餐模式 / Feeding Time (⌘D)" drops a single 🍰 at screen center.
- New `CockroachState.feeding`. **All** cockroaches (100%) in a redirectable
  state immediately transition to `feeding` and walk to a random offset around
  the cake. Newly spawned cockroaches (clipboard / ⌘N / babies / night
  auto-spawn) also auto-join while the cake exists.
- The cake's 30 s half-life / 60 s eaten timer only starts once the **first
  cockroach has actually reached its eating spot** (i.e. transitioned to
  `speed == 0` inside `updateFeeding`). Stops the cake shrinking while
  everyone is still walking over. Hard ceiling of 180 s from drop in case no
  one ever arrives.
- The cake can be **mouse-dragged** to a new spot. Cockroaches store a
  relative `feedOffset` (not absolute target), so they naturally follow when
  the cake moves.
- Half-eaten visual: same emoji size; right edge clipped by a subtle wavy
  `Path` mask so the cake looks "nibbled" instead of "shrunk".
- When the cake expires, every feeder scurries off in a random direction
  (`.dash`) instead of standing in place.

### New: Cake-driven level-up system

- Per-cockroach counter `cakesEaten`. Every 2 cakes eaten →
  `growthScale *= 1.2` (compounding, no cap), counter resets, `levelUpTimer`
  set to 1.5 s.
- `Cockroach.size` now multiplies by `growthScale`, so the per-cockroach
  `NSPanel` resizes the next tick via `updatePosition()`. `CockroachView`'s
  drawing `scale` is also multiplied by `growthScale`, so the visual matches.
- New level-up VFX in `CockroachView`: an expanding yellow ring + a softer
  inner ring + 8 sparkle dots rotating outward over 1.5 s.

### New: cursor-driven hit-test for cockroach windows

- Each `CockroachWindow` is `size * 3` to leave room for animations; the
  outer transparent halo used to block clicks to whatever was beneath.
  `CockroachManager.tick()` now toggles `window.ignoresMouseEvents = true`
  every frame unless the cursor is within `size / 2 + 8 px` of the cockroach
  (or it's currently being dragged). Restores click-through on transparent
  areas.

### Sizing

- `Constants.cockroachSize` bumped 60 → 160.
- Baby variant bumped from `cockroachSize / 3` to `cockroachSize * 2 / 3`,
  with matching SwiftUI scale 0.33 → 0.66, so babies are still smaller than
  adults but actually visible at the new scale.

### Other behavior fixes

- `Cockroach.handleDoubleClick` always kills now. The
  `squishBabySpawnChance` (40%) only decides whether the kill bursts an egg
  sac of 3-5 babies; it no longer triggers a "double-click just flips you"
  outcome that was indistinguishable from single-click.
- Babies are immune to the cornered-flight trigger — they never fly off the
  screen. (`checkCorneredFlight` returns early when `isBaby`.)
- Squishing a baby never spawns babies (early return in `handleDoubleClick`).
- Poop trails: `PoopCanvasView` now wraps its `Canvas` in
  `TimelineView(.animation)` so the dots actually re-render every frame
  inside the persistent `NSHostingView` — they had stopped showing up after
  earlier refactors because the `Canvas` was caching its drawing.

### Localization

- All menu bar items and the Settings panel labels are now bilingual
  ("中文 / English"). Window title too.

### Version

- Bumped `MARKETING_VERSION` 1.0 → 2.0.
- Bumped `CURRENT_PROJECT_VERSION` 2 → 3.
- Settings panel version label updated to v2.0.0.
- Bundle ID unchanged: `com.jo.cockroachpet.app` (upgrade path for existing
  App Store users).
