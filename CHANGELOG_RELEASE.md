# SwingPulse 0.1.3

Release date: 2026-07-21

## Summary

This release focuses on timing accuracy validation, low-noise diagnostics, and quality-of-life command updates.

## Added

- Live debug traces for swing combat events and reset timing points.
- Drift measurement (`driftMs`) showing predicted-vs-observed swing alignment per reset.
- Rolling drift summary every 5 swings with average, min, and max values.
- Tick-trace toggle command: `/swingpulse ticks <on|off>`.

## Changed

- Improved timer restart behavior with bounded latency compensation.
- Reduced debug chat noise by default while preserving high-value traces.
- Updated command/help documentation to include tick trace controls.

## Testing Notes

- Main-hand alignment validated on both slower and faster weapon speeds.
- Typical measured drift remained near zero on average, with occasional combat outliers expected in live play.

## Known Limits

- Extreme one-off drift spikes can occur during crowd-control movement, target pathing, or delayed combat log delivery.
- This release does not include a full graphical configuration panel by design.