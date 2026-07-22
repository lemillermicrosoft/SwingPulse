# SwingPulse

SwingPulse is a minimal World of Warcraft melee swing timer addon with one primary bar and an optional off-hand bar when dual-wielding is active.

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
- `/swingpulse debug` toggles verbose chat diagnostics.

## Notes

- Main-hand swings are tracked from combat log swing events.
- Off-hand tracking is enabled only while a valid off-hand attack speed is available.
- Known on-next-swing abilities are treated as main-hand swing consumers, and Slam is treated as a swing reset signal.