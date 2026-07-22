# SwingPulse Plan

## Vision
SwingPulse gives melee players a minimal, movable, and sizeable swing timer with clear color states so they can optimize timing for weapon swings. The MVP supports a primary bar for single-weapon setups and an optional second bar for dual-wielding, with simple controls and low runtime overhead.

## Scope (MVP)
- Track and render player main-hand swing progress as a horizontal status bar.
- Support optional off-hand swing bar when dual-wielding is detected.
- Provide slash commands for size, lock/unlock, and color profile presets.
- Keep UI intentionally simple: no heavy config panel, no graph/history.
- Persist position, size, colors, and lock state with SavedVariables.

## Technical Tasks
1. Project bootstrap
- Create addon manifest (.toc) with metadata and load order.
- Add core files (Core.lua, Events.lua, UI.lua, Config.lua) with a single global namespace table.
- Initialize defaults in SavedVariables on ADDON_LOADED.

2. Data model
- Define runtime state for main-hand and off-hand timers (start, duration, progress).
- Define settings model: width, height, spacing, colors, alpha, locked.
- Add helper functions for default merge and safe clamping of values.

3. Event handling
- Register combat and equipment events required for swing tracking.
- Handle swing-reset and swing-consume conditions from combat log events.
- Detect dual-wield transitions and enable/disable off-hand bar accordingly.
- Recompute swing durations when weapon speed changes.

4. UI rendering
- Build one parent frame with one or two status bars.
- Implement color states (ready, active swing, latency-warning if enabled).
- Add drag-to-move behavior when unlocked.
- Implement real-time bar updates via OnUpdate with lightweight math.

5. Commands and settings
- Add slash commands: /swingpulse lock, /swingpulse size <w> <h>, /swingpulse scale <n>, /swingpulse colors <preset>, /swingpulse reset.
- Validate and clamp command inputs with friendly chat feedback.
- Save settings immediately after command updates.

6. Performance constraints
- Minimize per-frame work by short-circuiting OnUpdate when hidden/idle.
- Avoid table churn in hot paths; reuse state tables where possible.
- Keep event handlers narrow and branch early.

7. Error handling
- Guard against nil combat log fields and unavailable weapon info during zoning/loading.
- Fallback gracefully to single-bar mode if off-hand data is unavailable.
- Add optional debug flag for verbose chat diagnostics.

## QA and Validation
- Functional checks
  - Main-hand bar starts, progresses, and resets on expected swing events.
  - Off-hand bar appears only while dual-wielding and tracks independently.
  - Bars remain movable/resizable and settings persist after reload.
- Performance checks
  - Verify stable framerate impact in combat with frequent log events.
  - Confirm no excessive garbage generation in update loop.
- Edge-case checks
  - Weapon swap while in combat updates timer durations safely.
  - Zone transitions and reloads do not leave stale bar state.
  - Entering vehicle/forms with unusual weapon states does not error.

## Post-MVP Ideas
- Optional numeric countdown text per bar.
- Optional spark marker and configurable textures.
- Per-spec profiles and quick profile switching.
- Latency compensation tuning controls.
- Simple test mode that animates bars out of combat.

## Deliverables
- Loadable SwingPulse addon folder with a valid .toc.
- Core runtime modules for event tracking, timer state, and UI rendering.
- Slash-command based configuration and SavedVariables persistence.
- Minimal README notes with install and command usage.
