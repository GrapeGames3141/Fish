# Hooked v34 — Waters

Version `0.7.0-waters1` / Android code `34`. Development build; physical motion/haptic feel and human aesthetic approval remain pending.

## Waters and progression

| Water | Regional setting | Fish |
| --- | --- | --- |
| Willow Pond | Hudson Valley, New York | Pumpkinseed, Black Crappie, Brown Bullhead |
| Pine Lake | Champlain Valley, Vermont | Bluegill, Largemouth Bass, Channel Catfish |
| Cedar River | Upper Peninsula, Michigan | Rainbow Trout, Smallmouth Bass, Northern Pike |
| Hatteras Inlet | Outer Banks, North Carolina — Atlantic inlet | Red Drum, Spotted Seatrout, Bluefish |

The spots are fictional interpretations of real regions, not literal photographs of named fishing sites. Regional species references: [NYDEC](https://dec.ny.gov/places/buckingham-pond), [UVM Lake Champlain study](https://www.uvm.edu/d10-files/documents/2025-09/Lake_Champlain_Angler_Study.pdf), [Michigan DNR](https://www.michigan.gov/dnr/things-to-do/fishing/where/better-fishing-waters), and [NC Sea Grant](https://ncseagrant.ncsu.edu/hooklinescience/will-the-big-fish-have-enough-to-eat/).

Fresh saves start at Willow. Each later water requires landing every species from **all earlier waters**: 3 for Pine, 6 for Cedar, 9 for Hatteras. Duplicates and merely hooked fish do not qualify. The scrollable picker shows caught checkmarks, missing species, locked state, and selected water. It clips both drawing and hit targets; swipes do not select cards.

Save v6 migrates genuine v1–5 progress without inventing catches or dates. Existing Willow/Pine/Cedar access is grandfathered; valid selected water, counts, bests, settings, calibration, and history survive reload. Hatteras still requires all nine earlier species. Unknown IDs and malformed values are sanitized.

## Presentation and gameplay

New photographic pond, Atlantic inlet, and Michigan river plates match their regional settings; the existing Pine photograph is retained. Six new fish have true-alpha art and distinct data-driven fight/vibration profiles. The established motion-only cast/hook/fight logic and top tension meter are retained. Willow uses its own visual depth range so long casts, line contact, approaching shadows, and ripples remain on the pond rather than its far bank. Gameplay cast distance is unchanged.

Records and World Records use two six-fish pages, with Field Notes/history supporting all 12 species. The optional Play Games configuration now requires 12 distinct real owner-supplied leaderboard IDs (superseding the six-board v31 setup). Defaults remain empty/offline; no leaderboards, owner credentials, fabricated scores, native bridge activation, or historical backfill were created.

The screen-first workflow kept existing authored opaque wood/paper framing, reused exact draw/hit geometry, and required in-game captures. This caught and corrected the initial Willow far-bank bobber placement before packaging.

## Art and evidence

[Full exact ImageGen prompt set, source identities, dimensions, SHA-256 hashes, crop metadata, and rejected-edit reasons](../reports/waters-v34/art-provenance.json).

Built-in ImageGen generated the selected assets on 2026-09-09. No specific model/version/tier selector was exposed. Runtime masters are byte-identical E: copies; the picker mockup is reference-only and excluded from Android export. Willow atlas rows are deliberately 543/535/458 pixels high to preserve its fins; ocean rows are 512 pixels each. Both contained fish drawing and tail animation share these regions. Two attempted atlas edits with baked checkerboards were rejected.

| Selected master | Size | SHA-256 |
| --- | --- | --- |
| [willow-pond-photo-v01.png](../art/ui_v1/runtime_source/willow-pond-photo-v01.png) | 941×1672; 2818946 bytes | `6736F53DDFAF81AF3EE5247F99625E1F3F85124934D8EDD09492CB99CDF8D7FE` |
| [hatteras-inlet-photo-v01.png](../art/ui_v1/runtime_source/hatteras-inlet-photo-v01.png) | 941×1672; 2365598 bytes | `BFB3C478688FDE34C15E63B38FF90E5F6BA8365EA47FD0A673E35F82E2FC65AD` |
| [cedar-river-michigan-v01.png](../art/ui_v1/runtime_source/cedar-river-michigan-v01.png) | 941×1672; 3080556 bytes | `090120A787DBDE4C0A3E1A4E18B9FE6EA3C87AA83CE7401F8EC8A7AFBA928F1B` |
| [willow-fish-atlas-v01.png](../art/ui_v1/runtime_source/willow-fish-atlas-v01.png) | 1024×1536; 2642599 bytes | `524E3DA0F1B7D2C3391187D5328A4FBAFD6988EAFCC6258321047663B9DE35A1` |
| [ocean-fish-atlas-v01.png](../art/ui_v1/runtime_source/ocean-fish-atlas-v01.png) | 1024×1536; 2377410 bytes | `88577F5D2C919EC4B7C466BEACCEB3A653F95320214AEB7459A61110CD018E72` |
| [waters-scroll-v34.png](../art/ui_v1/mockups/waters-scroll-v34.png) | 941×1672; 3102461 bytes | `3E49409632A90E5D56D8264257FAF94FDCA4974768A1A340B5228822E354CB7F` |

[Desktop gallery](../reports/waters-v34/gallery/README.md) covers the scroller, six new catches, pond/ocean gameplay, tension, both record pages, empty/mixed states, World Records, and Field Notes.

Independent final [domain tests](../reports/waters-v34/validation/primary-v34-domain.json) and [editor/import](../reports/waters-v34/validation/primary-v34-import.json) pass with no remaining task PIDs or windows. Domain stderr contains only the established 12 ObjectDB / 5 resource shutdown notices; parser stderr is empty. Tests cover regional catalog/near-mid-far reachability, landed-only/duplicate/persistent unlocks, migration, malformed saves, page navigation, clipped scrolling, haptics, motion, fight timing, and export contracts.

Device installation, APK audit, DriveFS delivery, and final process inventory are recorded separately in the release receipt. No phone screenshots were taken.
