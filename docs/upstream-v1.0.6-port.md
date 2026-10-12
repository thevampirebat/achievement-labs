# Upstream v1.0.6 port

Base source: upstream tag v1.0.6, commit 938a9ba0f746fcb20cee3588f992356df92bf38b. Its refreshed downloadable EXE is build 1.0.6.1; the supplied EXE SHA-256 matches the release notes.

Preserves all fork upgrades and incorporates PR #14 event-collector acknowledgement diagnostics. Adds upstream Xbox 360 USB/profile workflows, native GFWL workspace, verified title search, Windows 8 history/alias improvements and verified standalone updates. The updater is restricted to this fork and expects vMAJOR.MINOR.PATCH-fork.REVISION tags with matching update.json, asset size and SHA-256. Existing upstream update/install/rollback checks run offline in CI.

The upstream public list declares 413 titles (263 Supported, 147 Testing, 3 Coming Soon). Its tagged recipe source contains an older set: 397 locally enabled title templates. Thirteen advertised mapped titles lack a complete public recipe/template pair and retain the existing catalogue-service fallback. Advertised status is never proof of successful achievement credit. Both 7 Days to Die mapped editions are classified Testing. No 7 Days to Die unlock correction has been confirmed.

Fork DLC/hub catalogues, completion colours/Mythic indicators, legacy progress retention, shared totals, export-all/checkpoints, sorting, account-aware token handling, retry/multiselection, corrected edition mappings, queue controls/scheduling, concurrent spoofing, Windows notifications and compact queue tiles are retained. GFWL shared lists keep edition distinctions; local Xbox 360 profile games are included in sorting. Settings and queue storage paths are unchanged.
