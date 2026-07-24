# SwingPulse 0.5.0

Release date: 2026-07-23

## Summary

This patch focuses on marker readability and cleaner dual-wield sync feedback.

## Added

- Separate persisted marker brightness settings for MH and OH, with migration from the legacy shared brightness value.
- Slash command aliases for brightness control: `/swingpulse bright <value>`, `/swingpulse brightness <value>`, and `/swingpulse bright <mh|oh|all> <value>`.
- In-game config panel sliders: **MH Marker Brightness** and **OH Marker Brightness** (0.30 to 2.00).

## Changed

- Marker tint and alpha now scale independently for MH and OH in both weapon-icon and spark marker modes.
- Dual-wield sync now only shows green when MH is ahead of OH and still inside the configured sync window.
- The sync bar keeps a short completion grace to avoid false red flashes on clean swing resolutions.

## Testing Notes

- Verify `/swingpulse bright 1.50` makes both MH/OH markers visibly brighter in combat.
- Verify `/swingpulse bright mh 1.50` and `/swingpulse bright oh 0.50` adjust the two markers independently.
- Verify the sync bar only turns green when MH is leading OH within the configured window.
- Verify a clean synced finish does not flash red at swing end.

## Known Limits

- Weapon icon mode still depends on equipped weapon textures; spark fallback is used when icon data is unavailable.
- Very high brightness values can visually saturate marker color channels by design.