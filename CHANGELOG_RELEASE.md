# SwingPulse 0.4.1

Release date: 2026-07-23

## Summary

This patch focuses on marker readability and quick accessibility control for players who need stronger visual emphasis.

## Added

- Marker brightness setting with persisted value (`marker_brightness`) and live render updates.
- Slash command aliases for brightness control: `/swingpulse bright <value>` and `/swingpulse brightness <value>`.
- In-game config panel slider: **Marker Brightness** (0.30 to 2.00).

## Changed

- Marker tint and alpha now scale by configurable brightness for both weapon-icon and spark marker modes.
- Help text and documentation now include the brightness command.

## Testing Notes

- Verify `/swingpulse bright 1.50` makes both MH/OH markers visibly brighter in combat.
- Verify `/swingpulse bright 0.50` reduces marker intensity and remains readable.
- Verify config panel brightness slider updates marker visibility live and persists after `/reload`.

## Known Limits

- Weapon icon mode still depends on equipped weapon textures; spark fallback is used when icon data is unavailable.
- Very high brightness values can visually saturate marker color channels by design.