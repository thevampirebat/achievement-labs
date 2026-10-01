# Achievement Labs enhancements

This branch integrates the enhancements previously applied to the supplied
Windows executables into the fork's public source baseline. The base commit is
`9885476517d74542a66e72385773e33a3352294c`, which identifies itself as 1.0.3.
It retains that baseline's Xbox PC app attachment and OAuth fallback. The
separately supplied 1.0.4 executable uses different names and sign-in behaviour;
this source branch does not claim to reproduce that release.

## Features

- Retry mapped event achievements already marked unlocked; checkbox batch
  selection with select-all, clear, retained selection and sequential submission.
- Achievement name sorting, filters, scroll safety, and green base-game/DLC
  sections for Call of Duty: Ghosts Xbox One, title ID 572802557.
- Ghosts DLC ID correction, including Hat Trick. Reviewed edition remaps for
  Infinite Warfare Xbox One (796798669), Modern Warfare Remastered Xbox One
  (2154930), and 14 Escapists: The Walking Dead achievements (125965001).
  Catalog/payload validation rejects changed or unrecognised mappings.
- Read-only export of the connected account's entire game/achievement history,
  progress, pause/resume, account-specific checkpoints, skip-saved-title scans
  and optional refresh. Xbox Title ID and available SCID identify exported rows;
  a Microsoft Store product ID is not used as the join key.
- Xbox-recorded playtime in total hours/minutes on the Spoofer page, with manual
  and periodic refresh and an unavailable state when no statistic is returned.
- Experimental event-token retrieval from the current Windows user's Gaming
  Services cache, account/expiry checks, masked Paste event token input and
  reveal control. Automatic retrieval is off by default for new installations;
  existing explicit preferences are retained. Background refresh preserves both
  manual input and a saved/manual active token. Saving a token remains explicit.
- Heartbeat diagnostics and a read-only Xbox profile authorization check.
- Open Auto Unlock fills the selected game's Title ID and opens the queue page
  without starting work. Saved queues load stopped for review. Stopped queues
  support checklist removal, persisted edits, index/delay preservation and
  rollback when saving fails.

## Integration

`src/AchievementLabs.Enhancements` contains the existing enhancement library and
reviewed mapping signatures. Its assembly name and namespace remain
`AchievementLabs.MultiSelect` for compatibility with the reviewed tests.
The desktop constructor attaches its UI controls, the visible achievement
getter applies sorting/grouping, and the shared catalog client applies the
same normalization and payload validation used in the earlier builds.
The queue loader and heartbeat diagnostics are called directly from source.
No executable injection, dnlib patching or custom bundle repacking is needed.

The library uses reflection adapters for the desktop model's existing fields
and methods. Regression tests exercise those adapters against the actual
source-built model and window, rather than only fake models. Keep those tests
when changing the desktop or queue model. No Events/Data.json or standalone
event template is changed by this port.

## Build and test

Install .NET 9 SDK and use the upstream build instructions. Run all enhancement
regressions from the repository root:

```powershell
pwsh -File ./tools/Test-Enhancements.ps1
```

The test executable accepts `--scroll`, `--mapping`, `--editions`,
`--queue-tools`, `--auto-token`, `--playtime`, `--port`, `--export`, and
`--integration`. No argument runs selection/sorting tests. The `--scroll`
case includes actual-window integration and 546 scroll targets.
Fixtures are copied into the test output directory. `AL_TEST_ROOT` optionally
selects a different built app directory for integration/catalog tests.

Actual-window checks set `AchievementLabs.OfflineChecks` in AppContext before
constructing the window. That switch disables the normal startup sign-in and
Xbox app monitor for this test process. All service tests use synthetic
credentials and intercepted responses, with no live account requests.

Validated on 1 October 2026: source build, selection/sorting, actual window and
scrolling, all 91 Ghosts IDs, 152 reviewed edition translations, queue editing,
bulk export, playtime parsing, token checks and manual-token preservation.
The full clean builds of both upstream and this branch report the same 112
warnings in upstream/vendored code and zero errors; the added projects have no
reported compiler warnings. Live Windows authentication/cache decryption,
heartbeat and unlock operations have not been tested.

## Remaining limitations

Cached-user-token retrieval is not XAU's preferred WAM user-plus-device flow.
A token's format and matching account do not prove achievement-credit
capability. Disable automatic retrieval when using a working manual token.
Heartbeat HTTP 401 is diagnosed, not repaired by this port.

General automatic DLC classification is not implemented. No guessed event
data for 7 Days to Die (60633334) is supplied. Ten unverified/missing Escapists
entries remain blocked. Reviewed remaps are supported by catalog/metadata
evidence, not live unlock verification, and cannot undo previous unlocks.

This branch prepares source changes and offline tests; it does not publish a
release, change the licensing service, deploy the website or send announcements.
