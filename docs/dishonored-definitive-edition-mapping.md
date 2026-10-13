# Dishonored Definitive Edition — Xbox One mapping correction

Xbox title: 1100121502. PC comparison edition: 1627819535. Xbox SCID: 88940100-b0a6-495b-9f60-d06b4192859e.

The original Xbox catalogue exposed 74 recipes under mismatched IDs. Exact unique achievement names in the reviewed grouping data pair all 80 Xbox achievements with the PC edition; all 74 old Xbox recipes have exact full-object PC counterparts. The hash-pinned in-memory override restores the named Xbox IDs and supplies six previously absent Brigmore Witches recipes. IDs are never derived from package enum positions.

The six additions are Changed Ways (81), Silence is Golden (82), Cleanest Hands (83), Enough Coin to Disappear (84), Parting Shot (85) and Wall of Flesh (86). They remain PC-backed console candidates.

## Package-derived direct criteria

The uploaded Microsoft Store PC 1.10.0.0 DishonoredGame.upk, SHA-256 ec64bd36be12d7063199cf2722a2b8f280100f1ed3f3c63404ac34980d7141e2, contains achievement enums with names differing from several catalogue criteria.

| Xbox ID | Achievement | Direct candidate criterion | Verification |
|---|---|---|---|
| 8 | Mostly Flesh and Steel | FleshAndSteel | Internal-name pairing inferred; live credit unverified |
| 9 | Wall of Sparks | WallOfDarkness | Internal-name pairing inferred; live credit unverified |
| 13 | Manipulator | Corruptor | Internal-name pairing inferred; live credit unverified |
| 23 | Art Dealer | Profiteer | Internal-name pairing inferred; live credit unverified |
| 57 | Mrs Pilsen's Remorse | DLC05MrsPilsenRemorse | Already present as an old alternative; single direct request now |
| 61 | By My Hand Alone | DLC05ByMyHandOnly | User reported Xbox unlock |
| 65 | Time Management | DLC05TimeManager | User reported Xbox unlock |
| 80 | All Come To Ruin | DLC07Judgment | Internal-name pairing inferred; live credit unverified |

Each of these eight uses one ordinary CriteriaReplacement operation and the original Xbox template's asId 778. Previous variants and changed application IDs are replaced only for these eight. Headhunter and all other Xbox recipes retain their original values and variants. Six newly requested candidates require individual confirmation; internal enum names alone do not prove the collector criteria or server rules.

The two reported successes followed an unsuccessful metadata-repair build and an unsuccessful application-context-only build. A format repair normalizes any retained CRLF metadata targets to the pinned LF Xbox template and verifies target presence.

The manifest pins original Xbox/PC recipes and Xbox template hashes; changed inputs disable this edition pending review. The standalone Xbox template, title/SCID, PC catalogue and unrelated games remain unchanged. No RawBody operations, new stat patterns or embedded templates are generated.

Offline tests verify all 80 name identities, the eight direct candidates, original application context, unchanged Headhunter/unrelated request values, Xbox title/SCID isolation, unchanged PC data and changed-input refusal. No live Xbox requests are sent by tests. No game binaries, full decompiled scripts or account data are committed.

The wider raw catalogue audit is in docs/catalogue-audit-2026-10-13.md.
