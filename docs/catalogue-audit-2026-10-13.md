# Catalogue audit — 2026-10-13

Raw bundled public catalogue before runtime Dishonored and legacy edition corrections. Structural/name-reference audit only; no live requests. Standard Python JSON may reject syntax normalized by the app; those rows need comparison with Windows regression results.

## Coverage

Scanned all 397 locally enabled titles, 15,932 raw recipe entries and 30,907 request variants. The public status list advertises 413 titles. Exact saved achievement names were available for 133 of the enabled titles. Names alone cannot verify collector criteria; most titles have no executable/event-definition evidence here.

This audit scans the immutable ZIP before runtime corrections. Existing Dishonored, Ghosts, Infinite Warfare, Modern Warfare Remastered and Escapists edition guards must be considered before treating raw IDs as current app behavior. Windows regressions independently check effective payload construction. No account requests or live unlocks were sent.

## Priority findings

| Title | Finding | Interpretation |
|---|---|---|
| Prey, Xbox 907086072 | Five direct criteria match different saved Xbox achievement IDs. Engineer (1) sends NoNeedles (4); I and Thou (2) sends SplitAffinity (12); I and It (3) sends KnowThySelf (11); No Needles (4) sends Engineer (1); Do No Harm (5) sends IAndThou (2). | Strong mapping-review candidate. Catalogue labels these recipes testing; no automatic remap or live validation performed. |
| Halo MCC PC 1144039928 and CN 812065290 | REPLACEMETADATA is absent from both standalone templates; 3,596 and 3,144 metadata operations respectively do nothing. The templates retain fixed AchievementId metadata rather than each recipe's intended metadata. | Confirmed ineffective replacements; effect on server credit needs game-specific investigation. Recipes still produce parseable JSON. |
| Cities: Skylines Remastered 1936845110 | All 122 raw recipes miss their event/criterion targets and retain a different title ID/SCID in the resulting template payload. | Confirmed incompatible raw pair; existing title validation rejects these payloads. No speculative replacement template generated. |
| Quantum Break PC 333628240 | 103 raw requests across 19 recipes miss event, metadata and data targets, leaving unresolved placeholders. | Confirmed incompatible raw pair; existing unresolved-placeholder validation rejects them. |
| The Evil Within 2 Xbox 170773198 | All 51 raw recipes target REPLACEID, which is absent, and leave a different unresolved criterion placeholder. | Confirmed incompatible raw pair; existing validation rejects them. |
| Dishonored PC 1627819535 | Twelve metadata targets use CRLF while the standalone template uses LF. | Confirmed ineffective replacements. Xbox override handles this edition separately; PC raw recipes remain unchanged. |
| Other Minecraft editions, Terraria and MW2 Campaign Remastered | A small number of operations have absent targets. | Review individually; optional/redundant operations do not prove a broken achievement. |

## Signals needing interpretation

Found 168 groups of identical raw recipes. Identical recipes can be legitimate when one cumulative event satisfies multiple achievement thresholds; they are not automatically mapping errors.

Found 65 enabled title blocks carrying SourceTitleId metadata. This indicates provenance requiring edition review, not proof of a wrong mapping.

The Python parser flagged 648 request bodies. Some syntax is accepted and normalized by the app's Newtonsoft JSON parser, so this count is not a count of invalid app payloads. Likewise, unmatched-operation rows count individual operations and requests, not distinct broken achievements.

## Dishonored correction status

The user reported By My Hand Alone and Time Management credited after using the package-derived ByMyHandOnly and TimeManager criteria. Six additional Xbox-only candidates are included in the current test build: FleshAndSteel, WallOfDarkness, Corruptor, Profiteer, DLC05MrsPilsenRemorse and DLC07Judgment. The internal enum aliases do not establish Xbox collector rules. These six are not live verified; Mrs Pilsen's correct-name variant was already present in the old multi-request recipe. PC recipes, unrelated games and standalone templates remain unchanged.

## Reproduce

```text
python tools/Audit-EventCatalogue.py catalog/event-catalog-1.0.6.zip catalog/achievement-packs.json audit-raw.json
```

The script writes a detailed JSON report locally. The committed summary groups findings by title and keeps account data out of the audit.
