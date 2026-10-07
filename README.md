# Achievement Labs — Enhanced Fork

Achievement, stat, presence and save tooling for Windows PC and Xbox titles. The desktop client uses Avalonia and includes Xbox, Xbox 360, Games for Windows Live, Steam, Epic and Ubisoft workflows.

This is an unofficial fork of [ethanwp28/achievement-labs](https://github.com/ethanwp28/achievement-labs), with the improvements below added to the upstream 1.0.3 source.

**[Download the latest fork release](https://github.com/thevampirebat/achievement-labs/releases/latest)** · **[Download AchievementLabs.exe — fork.4](https://github.com/thevampirebat/achievement-labs/releases/download/v1.0.3-fork.4/AchievementLabs.exe)**

The latest published version is **v1.0.3-fork.4**, including the cumulative upgrades from PRs #1–#8. The application version remains **1.0.3**; the fork suffix identifies our release. Existing settings and saved queues are retained. Windows x64, Windows 10 build 19041 or newer; the executable is unsigned.

See the [release notes](docs/releases/v1.0.3-fork.4.md) and [implementation details](docs/enhancements.md).

## Improvements in this fork

### Achievements and event mappings

- **Retry already-unlocked event achievements** when mapped event data is available, for cases where the app reports an unlock that has not appeared on the profile.
- **Multi-select achievements** using checkboxes, Select all and Clear, with sequential batch submission.
- **A–Z and Z–A achievement sorting**, search/filter controls and selection preservation.
- **Achievement-list scrolling fixes**, including long and virtualized lists.
- **Call of Duty: Ghosts (Xbox One) base-game and DLC sections**, with green dividers and pack filtering instead of repeating the DLC name on every achievement.
- **Corrected Ghosts DLC event mappings**, including Hat-Trick and shifted mappings that could target the achievement below the selected one.
- **Reviewed edition-specific event mappings** for Infinite Warfare, Modern Warfare Remastered and The Escapists: The Walking Dead. Ambiguous entries remain unavailable; unexpected catalogue or payload changes stop submission.
- One **Open Auto Unlock** button in the game's achievement toolbar, opening the queue page with that game's Title ID filled in.
- **Selectable game titles** for copying from library, achievement and title-search views.

### Auto Unlock queue

- **Green highlighting for completed achievements** and a list that remains scrollable while unlocking.
- **Load saved queue for review** before choosing to start or resume.
- **Remove queued achievements** while the queue is stopped.
- **Custom delays and a manual Save queue delays button**.
- A separate **queue status tile** showing progress, next achievement, countdown, estimated time remaining and estimated completion date/local time. Estimates update with delays and speed settings and exclude network request time.
- **Optional unlock-failure notifications** and **Stop on unlock failure**. Stopping preserves the failed entry for retry.
- **Optional Refresh event token and retry** for missing tokens or HTTP 401/403: match the connected account, refresh and retry the same achievement once. Stopping cancels recovery.
- The queue uses the **current session token and the same event sender as manual unlocking**, checks all achievement requirements for event-based eligibility and loads reviewed edition mappings when restoring a queue.

### Title spoofing and Windows notifications

- **Run title spoofing and Auto Unlock together**. Presence requests are coordinated: the spoofer takes precedence while active, stopping a queue preserves spoofing, and stopping spoofing restores an active queue's title presence.
- **Look up title remains available during Auto Unlock**.
- A separate **spoofer status tile inside Auto Unlock**, showing the actual spoofed title and ID, session hours, last heartbeat and Xbox-recorded playtime. Open or stop the spoofer directly from this tile.
- A live **HH:MM:SS session timer on both pages**. It resets for a new session, retains the final duration after stopping and continues beyond 24 hours.
- **Xbox-recorded playtime in hours/minutes**, with manual refresh and automatic refresh every five minutes. Both pages share the existing reader without extra requests. Recorded playtime is separate from the current session timer and may update with a delay.
- **Heartbeat diagnostics** and a visible explanation when spoofing stops unexpectedly.
- **Native Windows notifications** for enabled unlock-failure alerts and unexpected spoofer stops. Manual stops and app shutdown do not trigger failure alerts.
- **Saved notification toggles** and **Test Windows notification** in Settings. Clicking a Windows alert opens or activates the app.

### Account and event-token handling

- **Windows broker event-token retrieval matched to the connected Xbox account**, rather than accepting an unrelated account when several are signed in on the PC.
- Account, token hash and expiry checks reject mismatches and preserve the existing token if retrieval fails.
- Retrieved tokens appear in the **masked Paste event token box** and remain there after saving; an explicit reveal control is available.
- Saving a token also updates the queue's account context. Turning off background retrieval preserves the current token.
- Read-only presence-login diagnostics help investigate Xbox app authorization problems.

### Library sorting and achievement totals

- **A–Z, Z–A and Last Played sorting**, with the last choice remembered.
- **Automatic activity refresh when selecting Last Played**; selection is preserved and the list no longer jumps to an A–Z entry such as #IDARB.
- **Fill missing totals** reads complete achievement-definition pages and excludes challenges from permanent achievement counts.
- Scans run **one title at a time**, can run alongside Auto Unlock, retry rate limits and try the alternate modern/legacy endpoint on empty or HTTP 404 responses. Stopping keeps results already collected.
- A shared catalogue of **937 verified definition totals**, matched by **Xbox Title ID and platform** so editions remain distinct.
- Shared totals are bundled for offline use and checked online when connecting or refreshing the library, with a 24-hour cache. Xbox/local counts take priority; **each account keeps its own unlocked progress**.
- **Export verified totals** includes earlier cached successes without XUID, event tokens or unlocked counts. No account data is automatically uploaded. The older Export totals report button has been removed.

### Bulk achievement export

- **Export all achievements across the library**, matched to their game/title identifiers.
- **Progress display, pause/resume and saved checkpoints**.
- Subsequent scans can **skip titles already completed**, avoiding opening and exporting every game individually.
- Modern/legacy achievement routes, paginated responses and CSV output are handled, with account-isolated checkpoints.

## Validation and current limits

All nine offline regression groups and the self-contained Windows build passed for fork.4 in [Actions run 37514873136](https://github.com/thevampirebat/achievement-labs/actions/runs/37514873136). These checks use synthetic credentials and intercepted requests, including real-window scrolling, timer bindings, queue state, mapping validation, token matching, exports and shared totals.

- DLC grouping is currently implemented for **Ghosts Xbox One**, rather than automatically classifying every game's DLC.
- Reviewed event mappings are supported by catalogue/metadata evidence and offline checks; this does not establish live Xbox achievement credit. Ten ambiguous Escapists entries remain unavailable.
- Missing event data is not invented. This fork does not add verified event recipes for **7 Days to Die (Title ID 60633334)**.
- Some titles may still lack totals when Xbox returns no usable definitions and no matching shared total exists. Shared definition totals do not supply another account's progress.
- Automatic event-token retrieval depends on the matching Windows broker account being available. Gaming Services cache retrieval remains experimental.
- Verify native notification delivery on your PC with **Settings → Test Windows notification**; Windows notification settings govern delivery.
- The fork does not provide achievement removal from an Xbox account.

Windows only. Editing achievement and stat data can carry account risk on a live service. Use test accounts and keep the backups created by the application.

## Build from source

Install the .NET 9 SDK, then run:

```powershell
dotnet restore .\AchievementLabs.sln
dotnet build .\src\AchievementLabs.Desktop\AchievementLabs.Desktop.csproj -c Release
```

Create the self-contained single-file release candidate with:

```powershell
pwsh -File .\tools\Build-Release.ps1
```

The release script builds the Avalonia desktop application, the x86 GFWL helper,
and the Steam idle helper. Its output stays under `releases/` and is not committed.

## Repository layout

- `src/AchievementLabs.Desktop/` — native Avalonia desktop client.
- `src/AchievementLabs.Core/` — shared Xbox, Steam, legacy, and catalog logic.
- `src/AchievementLabs.App/` — shared models, services, event templates, and stat catalogs used by the Avalonia client and hosted event service.
- `src/AchievementLabs.App/Events/` — current event catalog, `Data.json`, and one standalone template per title.
- `src/AchievementLabs.App/StatsCatalog/` — title and event stat classifications.
- `server/licensing/` — self-hosted event catalog and account service.
- `site/assets/games.json` — generated public game catalog embedded in the desktop client.
- `tools/` — release and catalog build tools required by the current application.
- `SteamAchievementManager-7.0.41/` — vendored upstream dependency with its license retained.

## Event support states

- **Supported**: mappings have been tested and are expected to work.
- **Testing**: the title has a usable template and mappings, but achievement IDs may
  not match and individual unlock requests may fail. Verify results one at a time.
- **Coming Soon**: no usable testing template is currently available.

`SupportedTitleIDs` must remain the final top-level property in every `Data.json`.
Each event title must use its own `Events/<titleId>.json` template.

## Local and private data

Authentication files, event tokens, service credentials, databases, research,
packet captures, build output, save backups, and machine-specific agent settings
are excluded through `.gitignore`.

## Support and credits

Questions and test results: [Achievement Labs Discord](https://discord.gg/EY6AJpNfVu)

Achievement Labs builds on ideas and prior work from the original Xbox Achievement
Unlocker project and includes Steam Achievement Manager code under its retained
upstream license.
