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

The Get event token now button offers a Windows account picker and uses the broker's
MSA token with a signed RPS device exchange, user authentication, identity
verification and a user-plus-device events XSTS request. This follows the
Windows account route observed in the supplied XAU executable. It requires
Windows 10 build 19041 or newer and an account available to the Windows broker.
Silent broker failures leave the previous token intact; the app does not
silently substitute a cached-user token. No XAU binary or decompiled source is
bundled. The legacy cache option remains explicitly experimental. Background
cache retrieval cannot replace a token obtained through the Windows picker.
Account/hash and expiry checks do not prove achievement-credit capability;
live authentication and credit still need validation on the user's PC.
Heartbeat HTTP 401 is diagnosed, not repaired by this port.

Queue updates (4 October 2026): unlocked rows are green, the list remains
scrollable during execution, and delay inputs are disabled while running.
Spoofing and the Xbox queue can run concurrently. Their presence requests share
a gate: the spoofer takes precedence while active; stopping a queue preserves
the spoofer, and stopping the spoofer restores an active queue's title presence.
Saving an event token updates the queue account too and no longer clears the
input when the immutable session is replaced for the same account. Turning off
background retrieval preserves the current token.

The Xbox library has A-Z, Z-A and Last Played sorting using Xbox title-history
timestamps. Missing timestamps sort last; name ties are deterministic and all
existing search/platform filters remain effective.

The nine regression groups pass with synthetic credentials, including the
actual-window running-list and Save-session regression, both presence gates,
library ordering and signed device exchange with account/hash/expiry rejection.

General automatic DLC classification is not implemented. No guessed event
data for 7 Days to Die (60633334) is supplied. Ten unverified/missing Escapists
entries remain blocked. Reviewed remaps are supported by catalog/metadata
evidence, not live unlock verification, and cannot undo previous unlocks.

This branch prepares source changes and offline tests; it does not publish a
release, change the licensing service, deploy the website or send announcements.


## Queue status, remembered sort and Windows account matching

The Xbox library remembers A-Z, Z-A or Last Played automatically in a separate small preference file. Initial loading still retains title-history dates, and choosing Last Played refreshes Xbox activity.

Auto Unlock has its own status tile with progress, next achievement, time until next, estimated total remaining duration and estimated finish day/date/local time. Estimates exclude network request time. Loaded and stopped queues show an estimate if started now; delay edits and speed changes recalculate it. Speed editing is disabled during a run.

Get event token checks Windows broker accounts silently and accepts only the identity whose Xbox XUID matches the current connected account. An account mismatch is rejected before requesting an events token. Unavailable broker accounts are skipped; failure preserves the existing token. This requires the matching account to be signed in and available to the Windows broker; actual achievement credit still requires PC testing. No credentials are logged.

Title spoofer Look up title is available during Auto Unlock. This read-only request uses the existing shared request gate while write and disconnect guards remain protected.


### Game toolbar, library totals and queue failure controls
- Open Auto Unlock is one game-level shortcut beside achievement filters/search.
- Game titles are selectable text in Xbox library, achievement header and title search.
- Fill missing totals reads complete achievement definition pages, excludes challenges and saves counts by Xbox account/title ID. Stop scan keeps results already collected. Titles the service cannot return stay unavailable.
- Library progress text wraps inside its column.
- Xbox Auto Unlock offers failure toasts (on by default), stop on failure (off by default), and Save queue delays. Saved queues retain both options and custom delays. Stop on failure preserves the failed entry for retry; continuing reports failures in the final status.

- Missing-total scans check one title at a time, retry HTTP 429 responses, and use separate read-only clients so Auto Unlock can run alongside the scan.

- Optional event token recovery uses Windows broker identity matching for missing tokens or HTTP 401/403 and retries the same achievement once. It is off by default; exhausted recovery follows the notification/stop controls. The refreshed token appears in Settings and is active for the queue; Save event token persists it securely.
- Missing totals try the other modern/legacy endpoint on an empty list or HTTP 404. Export totals report includes title ID/name/platform, endpoint, count and sanitized result, plus a summary by failure reason. Scan caches remain local and profile-specific.
