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
- `/swingpulse colors <ember|tide|ash>` switches color presets.
- `/swingpulse reset` restores default settings.
- `/swingpulse debug` toggles swing timing diagnostics in chat.
- `/swingpulse ticks <on|off>` toggles high-frequency tick trace output.

## Notes

- Main-hand swings are tracked from combat log swing events.
- Off-hand tracking is shown on the same sync bar only while a valid off-hand attack speed is available.
- The center marker helps align both swing icons for dual-wield sync timing.
- Known on-next-swing abilities are treated as main-hand swing consumers, and Slam is treated as a swing reset signal.

## Timing Validation

- Enable diagnostics with `/swingpulse debug`.
- For clean tests, use auto attacks only with no special abilities.
- Review `reset ... driftMs=...` lines to verify per-swing alignment.
- Review `drift ... samples=... avg=... min=... max=...` every 5 swings to see aggregate timing quality.
- Disable noisy traces with `/swingpulse ticks off`.