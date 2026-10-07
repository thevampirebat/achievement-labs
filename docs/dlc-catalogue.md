# Shared achievement pack catalogue

`catalog/achievement-packs.json` contains public display metadata only. It never changes event payloads, unlock IDs, account progress, or tokens.

The first release retains the 91 verified Call of Duty: Ghosts Xbox One achievements: Base game (50), Onslaught (11), Devastation (10), Invasion (10), and Nemesis (10). Other games are supported by the reader but require reviewed catalogue entries; this is not a claim that every game has already been classified.

The desktop app reads the embedded catalogue offline, loads its local cache, and checks the public catalogue when attaching an account or refreshing the library. Successful checks are cached for 24 hours. New catalogue entries can therefore be delivered through this repository without rebuilding the executable. Invalid updates leave the prior catalogue usable.

Each title entry must contain its exact Xbox Title ID, matching Xbox platform names, a source URL, and named packs. Each achievement requires its Xbox achievement ID and name. Match the correct edition's Xbox definitions to a source such as TrueAchievements or XboxAchievements using names, descriptions and gamerscore; review ambiguities before publishing. Website achievement IDs and list positions must never be substituted for Xbox IDs.

Pack `kind` is `base`, `dlc`, or `update`. Exactly one base pack is required, and an achievement cannot appear in two packs. Partial coverage is allowed: unmapped IDs and mismatched names remain **Unclassified**. DLC sections and the multiselect picker both use the same verified mappings and green separators.

## Queue and game-page controls

- **Remove completed** removes completed entries from a stopped Auto Unlock queue, saves the queue, and preserves the next pending achievement's countdown. Failed saves restore the original entries and countdown. Pause before editing an active queue.
- Search and filter fields have an **×** control that clears their existing bound text.
- **Open Title Spoof** selects the current game's Title ID and opens the spoofing page without starting it. An active spoofer must be stopped before choosing another game; an Auto Unlock queue can remain active.
- The game header displays Xbox-recorded playtime using the connected account. Values are cached per account/title for five minutes; absent statistics display **Unavailable**, rather than an invented zero.

Xbox Mythic completion means all original achievements, excluding later DLC and updates. A future library badge should use verified base completion or authoritative Xbox Mythic status, not assume total gamerscore or current DLC-inclusive completion proves Mythic status.
