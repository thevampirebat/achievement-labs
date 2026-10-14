# Follow-up edition review, 14 October 2026

Read-only review of the bundled raw catalogue; no Xbox requests. Existing runtime Ghosts, Infinite Warfare, Modern Warfare Remastered, Escapists and Dishonored corrections remain applied and must not be treated as unresolved raw errors.

Minecraft Xbox One Edition 345903534: all 123 REPLACEDATA event bodies match Minecraft Windows 10 896928775 after removing titleId and serviceConfigId and substituting transport placeholders for comparison. This includes Cupid (69). The Xbox One body includes editionType win10; template application metadata identifies Windows Minecraft. The user confirmed that routing this edition to the original app's catalogue service works. That route remains reserved from automatic imports.

Minecraft Nintendo Switch 2047319603: 40 of 95 comparable ordinary event bodies match Windows 10 under the same normalization, and metadata uses win10. This is a candidate for live comparison, not a confirmed defect: Bedrock editions share telemetry and other recipes differ. No changes made.

Other Minecraft editions: application metadata is often Windows-derived, but Pocket Android/Kindle/iOS/Gear VR data includes its own edition values. No tested ordinary body matched Windows 10 exactly. That does not prove correctness or rule out problems. The current Bedrock Xbox entry also shares some bodies (19 of 65 comparable ordinary recipes), which can be expected with shared code and is not equivalent to the legacy-edition mismatch.

Prey Xbox 907086072 remains a strong review candidate: five direct criteria match other saved achievement IDs (see previous audit). Its template is borrowed and the catalogue marks it Testing; an unverified remap was not added.

Dishonored 2 Xbox 527255540: extracted game assets explicitly confirm all 50 Xbox achievement IDs. Its catalogue source refers to Death of the Outsider PC and template executable metadata remains from that game. Xbox event schema remains unverified; no speculative change made.

The previous whole-catalogue audit also found ineffective metadata replacements in Halo MCC PC/China, and raw recipe/template incompatibility for Cities: Skylines Remastered, Quantum Break PC and The Evil Within 2 Xbox. Existing validation blocks the known unresolved-placeholder/wrong-title cases. These require title-specific review rather than assuming another edition's values will work.
