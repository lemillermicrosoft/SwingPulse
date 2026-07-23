# SwingPulse

SwingPulse is a minimal World of Warcraft melee swing timer addon with a single sync bar, a center marker, and main-hand/off-hand swing icons.

## Install

1. Place the `SwingPulse` folder inside your `World of Warcraft/_classic_/Interface/AddOns` directory.
2. Reload the game UI with `/reload`.

## Commands

- `/swingpulse lock` toggles the frame lock state.
- `/swingpulse unlock` unlocks the frame for dragging.
- `/swingpulse size <width> <height>` sets the bar size.
- `/swingpulse scale <number>` sets the frame scale.
- `/swingpulse sync <seconds>` sets the sync window used for dual-wield green state (clamped 0.05 to 1.00).
- `/swingpulse icon <weapon|spark>` switches moving marker style between weapon icons and spark textures.
- `/swingpulse colors <ember|tide|ash>` switches color presets.
- `/swingpulse config` (or `/sp ui`) toggles the in-game configuration panel for bar settings.
- `/swingpulse reset` restores default settings.
- `/swingpulse debug` toggles swing timing diagnostics in chat.
- `/swingpulse ticks <on|off>` toggles high-frequency tick trace output.

## Notes

- Main-hand swings are tracked from combat log swing events.
- Off-hand tracking is shown on the same sync bar only while a valid off-hand attack speed is available.
- The midpoint is explicitly marked (line, glow, and MID label) because midpoint timing is used to gauge when to tap the resync macro.
- In dual wield, the bar turns green when MH and OH are within the configured sync window, and status text shows SYNC state plus which hand is first.
- Moving markers support MH/OH labels and can use current weapon inventory icons with spark fallback.
- Known on-next-swing abilities are treated as main-hand swing consumers, and Slam is treated as a swing reset signal.

## Timing Validation

- Enable diagnostics with `/swingpulse debug`.
- For clean tests, use auto attacks only with no special abilities.
- Review `reset ... driftMs=...` lines to verify per-swing alignment.
- Review `drift ... samples=... avg=... min=... max=...` every 5 swings to see aggregate timing quality.
- Disable noisy traces with `/swingpulse ticks off`.