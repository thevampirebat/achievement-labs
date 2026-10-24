# Achievement Labs — unofficial fork

> **This is an independently maintained, unofficial fork of [Achievement-Labs/achievement-labs](https://github.com/Achievement-Labs/achievement-labs), the upstream/main project. It is not the official release repository.**
>
> Download this fork’s Windows, Android and iOS builds from [thevampirebat releases](https://github.com/thevampirebat/achievement-labs/releases). App update checks for this fork use this repository; event JSON updates come from the upstream Achievement Labs repository. Feature contributions are submitted as PRs to the upstream project.

Achievement, stat, presence, and save tooling for Windows PC and Xbox titles. The
desktop client uses Avalonia and includes Xbox, Xbox 360, Games for Windows Live,
Steam, Epic, and Ubisoft workflows.

**[Download this fork’s current feature batch — Windows 1.0.8.14 / Android 0.6.4 / iOS 0.12.6](https://github.com/thevampirebat/achievement-labs/releases/tag/v1.0.8-fork.14)**

This prerelease corresponds to [upstream PR #15](https://github.com/Achievement-Labs/achievement-labs/pull/15), which remains open. Earlier installed builds may still check the old official app-update feed; that routing is being corrected. Event JSON continues to come from upstream.

The Windows client includes a combined Game Session and customizable glass appearance. See [Game Session and appearance](docs/game-session-and-appearance.md) for controls, completion summaries and offline validation.

The desktop app runs on Windows; separate Android APK and unsigned iOS IPA downloads are provided in Releases. Editing achievement and stat data can carry account risk on a live
service. Use test accounts and keep the backups created by the application.

## Build from source

Install the .NET 9 SDK, then run:

```powershell
dotnet restore .\AchievementLabs.sln
dotnet build .\src\AchievementLabs.Desktop\AchievementLabs.Desktop.csproj -c Release
```

Create the self-contained single-file release candidate with:

```powershell
pwsh -File .\tools\Build-Release.ps1 -Version 1.0.8
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
