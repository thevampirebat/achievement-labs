# Automatic upstream event additions

The app checks the original ethanwp28/achievement-labs main commit at startup and hourly when the Settings toggle is enabled (default on). Check now forces a retry. It only downloads Data.json when the commit changes or a check is forced. Data/template reads are pinned to the same immutable upstream commit. Downloads are bounded; no executable or upstream code is loaded.

Only newly supported numeric Title IDs absent from all bundled title blocks and public classifications are imported. Existing bundled mappings, runtime edition overrides and remote-only titles are reserved. Minecraft Xbox One Edition stays on its user-confirmed working upstream service path. Previously cached additions also remain unchanged; this is an additions updater, not automatic replacement of existing event mappings.

Every achievement of a candidate title must use ordinary deterministic Replace operations, all targets must exist, placeholders must resolve, every payload must parse as strict JSON, and event/baseData title identity and SCID syntax must be consistent. Missing/incompatible or unsupported schemas are skipped and counted. This establishes structural compatibility, not server credit. All imported titles are displayed as Testing. Review is needed for unsupported operation types and partially invalid title blocks.

The separate public-data cache is atomically replaced only after a successful snapshot check. SupportedTitleIDs remains last in cached Data. Corrupt cache files fail closed, failed or cancelled downloads keep existing data, and cached valid additions work offline after restart. Accounts, event tokens and live Xbox requests are not involved. Refresh a game's achievement page after new data arrives. New Testing titles may be built into an auto-unlock queue for review through the existing workflow.

Enter in either queue configuration field builds the queue only when both reference gamertag and Title ID are populated, the account is connected and the existing command/configuration controls permit it. It does not start the queue or spoofing. Existing disabled/busy guards and AsyncRelayCommand execution protection remain active.

Validation uses HTTP fixtures for new-title imports, existing-title protection, wrong title, missing templates, cache restart, throttle, malformed updates, network failure and cancellation. Windows CI covers the actual desktop window and release packaging. No events sent.
