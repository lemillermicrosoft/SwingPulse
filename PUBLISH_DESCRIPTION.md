# SwingPulse Addon Description

SwingPulse is a minimal melee swing timer for World of Warcraft players who want clear swing cadence without UI clutter. It provides a compact, movable swing bar for main-hand attacks and automatically adds off-hand tracking when dual-wielding is active.

The addon is built for practical combat feedback:

- Sync-aware bar visuals with practical dual-wield timing states.
- Drag-to-move placement with lock/unlock control.
- Slash-command configuration with immediate persistence.
- Lightweight runtime behavior designed to avoid heavy per-frame work.

## Feature List

- Main-hand auto attack swing tracking.
- Optional off-hand tracking when dual-wield is detected.
- Dual-wield sync state based on MH/OH delta within the 0.5s default sync window (configurable).
- Lead-direction cue for stagger awareness (MH first or OH first).
- High-visibility midpoint marker (line, glow, MID label) to support macro timing practice.
- Moving MH/OH markers with player weapon icon mode and spark fallback.
- Saved settings for position, size, scale, color preset, lock state, and diagnostics options.
- Color presets: ember, tide, ash.
- Optional in-chat timing diagnostics for calibration and testing.

## Detailed Usage Guide

### Installation

1. Extract the SwingPulse release archive.
2. Copy the SwingPulse folder into your WoW AddOns path.
3. Reload the UI with `/reload`.

### Basic Setup

1. Run `/swingpulse unlock`.
2. Drag the bar to your preferred location.
3. Run `/swingpulse lock` after positioning.

### Sizing and Look

- `/swingpulse size <width> <height>` sets bar dimensions.
- `/swingpulse scale <number>` changes frame scale.
- `/swingpulse sync <seconds>` sets the sync window (clamped 0.05-1.00, default 0.50).
- `/swingpulse icon <weapon|spark>` switches marker style.
- `/swingpulse colors <ember|tide|ash>` applies a color preset.
- `/swingpulse reset` restores defaults.

### Diagnostics and Calibration

- `/swingpulse debug` toggles timing diagnostics.
- `/swingpulse ticks on` enables high-frequency tick lines for deep inspection.
- `/swingpulse ticks off` disables high-frequency tick lines to keep chat readable.

When debug is enabled:

- `reset MH ... driftMs=...` reports timing error per swing.
- `drift MH samples=... avg=... min=... max=...` reports rolling summary quality every 5 swings.

### Suggested Validation Flow

1. Attack with only auto attacks for at least 10 swings.
2. Watch rolling summary averages in chat.
3. Treat occasional large outliers as environmental unless they repeat consistently.

### Troubleshooting

- No bars visible: confirm addon is enabled and not blocked by outdated TOC for your client flavor.
- Bar not moving: run `/swingpulse unlock`.
- Too much debug spam: run `/swingpulse ticks off` or disable diagnostics with `/swingpulse debug`.

## Intended Scope

SwingPulse intentionally favors a lean slash-command workflow over a large in-game options panel.