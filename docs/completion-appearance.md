# Achievement sections and completion appearance

Click a green section heading to collapse or expand it. Collapse state stays with the exact title/platform during the session. Search exposes matching rows, and exports and batch selection retain the full filtered list.

Settings provides automatic daily catalogue checks while the app is running and a force-refresh button. Both the ordinary catalogue and achievement hubs are refreshed. Valid cached/bundled definitions remain available if a download or validation fails.

Completion appearance has independent Mythic-style icon and DLC-background switches and saved colours. These are local indicators, not official Xbox awards. The icon uses verified original/base-game achievement IDs and names; later DLC and updates are excluded. Once locally verified, base completion is remembered per account. All-achievement completion also proves base completion, even for an unclassified list. Partial unknown lists are not inferred from ordering or 1,000 Gamerscore. Hubs without a base section do not receive a base-completion icon. DLC highlighting requires all identified additional achievements and a complete matching definition set.

Existing bulk exports are imported automatically for the connected account. Use saved export progress to reload them, or scan missing completion progress one title at a time. Cancelling retains completed scan results. Opening a game also refreshes its cached achievement progress. Legacy progress prefers explicit unlock flags; placeholder dates do not prove an unlock.

Confirmed GFWL Title IDs are labelled GFWL (PC). Shared Xbox 360/GFWL achievement lists keep their shared identity. Original device identifiers still select the appropriate Xbox API endpoint.

Settings > Debug contains report links, verified-totals export, event catalogue inspection and local replacement tests. New bulk-export error reports use the export's debug/scan-errors.csv path; existing files are not deleted or relocated.

The achievement page shows the same Mythic-style indicator beside its achievement count and respects the saved icon toggle and colour. Fable III PC (1297287434) is labelled GFWL; the Xbox 360 edition (1297287382) remains separate.

Legacy progress is read from both the definition catalogue and the separate earned-achievements endpoint using contract 1, then joined by exact achievement ID. Offline earned records do not require a timestamp. An unavailable earned list fails the read rather than publishing zero unlocks. A response below the known legacy library count retains that count and marks unconfirmed rows unavailable. Old legacy bulk-export checkpoints are reread once to obtain verified earned progress.

The library background now marks 100% completion of the entire achievement list: base game plus all DLC and title updates. Games with no DLC also receive the background when fully completed. Completing DLC alone does not highlight a game with locked base-game achievements. Known whole-list totals can prove 100% completion even without DLC grouping metadata; unknown or zero-achievement lists remain unmarked. The existing highlight toggle and saved background colour apply unchanged.
