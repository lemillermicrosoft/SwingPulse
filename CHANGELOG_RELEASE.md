# SwingPulse 0.2.0

Release date: 2026-07-23

## Summary

This release focuses on practical sync/stagger play: clear 0.5s sync feedback, better moving markers, and explicit midpoint guidance for macro timing.

## Added

- Configurable sync window command: `/swingpulse sync <seconds>`.
- Marker style command: `/swingpulse icon <weapon|spark>`.
- Weapon icon marker mode with MH/OH overlays and spark fallback.
- High-visibility midpoint indicator (line + glow + MID label).

## Changed

- Dual-wield green state now reflects true sync logic: MH/OH within the configured window (default 0.5s), regardless of which hand lands first.
- Dual-wield status text now includes SYNC state, lead direction (MH first/OH first), and DIFF with higher precision.
- Marker textures now refresh on load and equipment/inventory changes.

## Testing Notes

- Verify dual-wield green state with `/swingpulse sync 0.5` and ensure green appears for any MH/OH pair within 0.5s.
- Verify midpoint visibility is clear enough to time the resync tap around midpoint.
- Verify `/swingpulse icon weapon` and `/swingpulse icon spark` both render correctly.

## Known Limits

- Weapon icon mode depends on equipped weapon textures; spark fallback is used when icon data is unavailable.
- This release keeps slash-command configuration by design and does not add a full options panel.