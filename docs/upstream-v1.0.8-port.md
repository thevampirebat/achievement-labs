# Upstream v1.0.8 integration

Integrates upstream release v1.0.8 (1a76574db3ca4d5ee02f162a63cf0ce3123b3db9) into the published fork v1.0.7-fork.1.

- Fixes event-token parsing and false account-mismatch rejection, retaining format/expiry checks, protected storage and Xbox rejection handling. A readable differing hash now produces the upstream warning. The fork's explicit connected-account retrieval, including account-change protection, is preserved.
- Imports the author's matching catalogue copies and standalone templates: Evil Within 2 event/UnlockId fixes, expanded Rocket League recipes, FRU, disabled GoldenEye 007 and Rare Replay entries. No title is promoted beyond the author's classifications.
- Keeps all fork UI, Mythic spacing, queues, library progress, edition mappings and hosted Minecraft route; keeps fork executable updates and bounded release-ZIP catalogue updates.
- Updates the bundled ZIP fingerprint and source revision to v1.0.8.
- Adds upstream synthetic token regressions to the Windows test run; executable version 1.0.8.1.

Previous integration choices and validation boundaries remain documented in [v1.0.7 integration](upstream-v1.0.7-port.md). Offline checks do not prove live Xbox achievement credit. No signing material is introduced.
