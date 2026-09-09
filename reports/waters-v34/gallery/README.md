# Waters v34 gallery

Actual Godot desktop renders, not phone screenshots. Frozen in-memory fixtures do not alter the player's save. Counts and catches shown here are test data.

[Willow Pond](willow-ready-720.png) · [Atlantic inlet](hatteras-ready-720.png) · [Scrolling waters](waters-locked-top-720.png) · [Full fish collection, page 2](records-page2-full-safe180-720.png)

## Rendered screens

| Capture | Actual pixels | Process receipt |
| --- | --- | --- |
| [catch-black-crappie-720](./catch-black-crappie-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-crappie.json) |
| [catch-bluefish-720](./catch-bluefish-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-bluefish.json) |
| [catch-brown-bullhead-720](./catch-brown-bullhead-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-bullhead.json) |
| [catch-pumpkinseed-720](./catch-pumpkinseed-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-pumpkinseed.json) |
| [catch-red-drum-720](./catch-red-drum-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-reddrum.json) |
| [catch-spotted-seatrout-720](./catch-spotted-seatrout-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-seatrout.json) |
| [field-notes-red-drum-safe180-720](./field-notes-red-drum-safe180-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-fieldnotes-reddrum-safe180.json) |
| [hatteras-bite-720](./hatteras-bite-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-hatteras-bite.json) |
| [hatteras-high-720](./hatteras-high-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-hatteras-high.json) |
| [hatteras-ready-720](./hatteras-ready-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-hatteras-ready.json) |
| [records-page1-empty-720](./records-page1-empty-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-records-page1-empty.json) |
| [records-page1-full-720](./records-page1-full-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-records-page1-full.json) |
| [records-page2-720](./records-page2-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-records-page2.json) |
| [records-page2-full-safe180-720](./records-page2-full-safe180-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-records-page2-full-safe180.json) |
| [waters-locked-bottom-720](./waters-locked-bottom-720.png) | 720×1280 | [PASS](../validation/waters-v34-locked-bottom-final2.json) |
| [waters-locked-bottom-safe180-720](./waters-locked-bottom-safe180-720.png) | 720×1280 | [PASS](../validation/waters-v34-locked-bottom-safe180-final.json) |
| [waters-locked-safe180-960x1706](./waters-locked-safe180-960x1706.png) | 960×1706 | [PASS](../validation/waters-v34-locked-safe180-final2-actual.json) |
| [waters-locked-top-720](./waters-locked-top-720.png) | 720×1280 | [PASS](../validation/waters-v34-locked-top-final2.json) |
| [waters-unlocked-bottom-720](./waters-unlocked-bottom-720.png) | 720×1280 | [PASS](../validation/waters-v34-unlocked-bottom-final2.json) |
| [willow-approach-720](./willow-approach-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-willow-approach-waterband.json) |
| [willow-danger-720](./willow-danger-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-willow-danger-waterband.json) |
| [willow-ready-720](./willow-ready-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-willow-ready.json) |
| [world-page2-720](./world-page2-720.png) | 720×1280 | [PASS](../validation/waters-v34-capture-world-page2.json) |

The tall picker requested a 960×2142 desktop window; Godot preserved a 960×1706 game viewport. The filename and dimensions above reflect the actual captured pixels. `safe180` is a synthetic 180px virtual safe top.

The primary review checked the selector, all six new catches, corrected pond water contact, visible tension, both populated record pages, empty/mixed silhouettes, World Records, and Field Notes. An initial pond capture put the bobber on its far bank; the selected corrected capture and its later receipt supersede that result. These checks do not establish physical gesture/haptic feel, Android touch comfort, native-ad layout, cloud-sync completion, or human aesthetic approval.

## Selected generated masters

- [willow-pond-photo-v01.png](../../../art/ui_v1/runtime_source/willow-pond-photo-v01.png) — 941×1672.
- [hatteras-inlet-photo-v01.png](../../../art/ui_v1/runtime_source/hatteras-inlet-photo-v01.png) — 941×1672.
- [cedar-river-michigan-v01.png](../../../art/ui_v1/runtime_source/cedar-river-michigan-v01.png) — 941×1672.
- [willow-fish-atlas-v01.png](../../../art/ui_v1/runtime_source/willow-fish-atlas-v01.png) — 1024×1536.
- [ocean-fish-atlas-v01.png](../../../art/ui_v1/runtime_source/ocean-fish-atlas-v01.png) — 1024×1536.
- [waters-scroll-v34.png](../../../art/ui_v1/mockups/waters-scroll-v34.png) — 941×1672, composition reference only; excluded from APK.

[Exact prompt set and provenance](../art-provenance.json) · [Capture dimensions and hashes](../capture-manifest.json) · [Independent domain check](../validation/primary-v34-domain.json) · [Import check](../validation/primary-v34-import.json) · [Release receipt](../README-v34.md)
