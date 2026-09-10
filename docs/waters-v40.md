# Waters v40 — regional expansion

## Scope and acceptance

`0.8.0-waters2` / Android code `40` expands Hooked from four locations and
twelve fish to eight locations and twenty-four fish. The original catalog and
its save progress remain intact. New waters are appended in this order:

| Water | Regional inspiration | New fish | Unlock requirement |
| --- | --- | --- | --- |
| Mangrove Flats | Ten Thousand Islands, Florida | Common Snook, Mangrove Snapper, Atlantic Tarpon | 12 earlier species landed |
| Cypress Bayou | Atchafalaya Basin, Louisiana | Bowfin, Longnose Gar, Flathead Catfish | 15 earlier species landed |
| Moonlit Reservoir | Ozark Plateau, Arkansas | Walleye, Striped Bass, Blue Catfish | 18 earlier species landed |
| Bluewater Offshore | Florida Straits | Mahi-mahi, Yellowfin Tuna, Atlantic Sailfish | 21 earlier species landed |

Unlocks require every earlier catalog species, never placeholder catches. The
records and World Records views calculate four six-fish pages from the catalog,
clamp their navigation, and the location picker scrolls through all eight
waters. Every fish keeps nonzero near/mid/far habitat weight. The existing
motion detector, haptic driver, fight state machine, and original twelve fish
profiles are unchanged; only the three new apex profiles are constrained to the
established pike-like fight envelope so standard reactive fights remain within
the intended duration range.

Save schema intentionally remains `VERSION = 6`: v6 saves preserve their
earned original unlock list and add zeroed fields for the twelve new species.
The older-version migration path remains responsible only for true legacy saves.

## Runtime art and provenance

All selected ImageGen outputs are durable runtime inputs under
`art/ui_v1/runtime_source/waters-v40/`; scenery plates are the sole opaque
environment owner. They contain no baked HUD, text, people, tackle, bobbers,
fish, or fish shadows. Runtime rod, external line, bobber, header, and native
gameplay UI remain live layers. First-pass source/art selection is internally
reviewed only; it is not a claim of human visual approval.

| Runtime asset | SHA-256 |
| --- | --- |
| `mangrove_flats-photo-v01.png` | `21A09940CAA6A1F0397CBB4B3EC3D3C72BEB15E117374042F6690FFDF01B2F3C` |
| `cypress_bayou-photo-v01.png` | `E0BED04808482A656886FAE0E49E3331C4300AE3C6596771D8B80DE4108A6249` |
| `moonlit_reservoir-photo-v01.png` | `32B9C2011BDE3BD9B27C1BCAC959176C4B138E294C64823053677C4AAE06F9DA` |
| `bluewater_offshore-photo-v01.png` | `3C7D3DB9446246739377F8A1A61014CFB7F7D2F1A19AAE46B9872BD9AEB29390` |
| `mangrove_flats-fish-atlas-v01.png` | `C1937FAF55520BF3CA6A04A22232508B468CDE1D7844751CDA67E1E3AA488A25` |
| `cypress_bayou-fish-atlas-v01.png` | `E6E77E90A1400F8129B1AD813CD3D41A4338DB42EEA26BF82FB30293BFF38346` |
| `moonlit_reservoir-fish-atlas-v01.png` | `04F15CFA7E1AB03783E206D1DE5E26EBF83DA3A11F222EF6E013EEA37ADE3134` |
| `bluewater_offshore-fish-atlas-v01.png` | `22AA4B63A7198D727F6EBB9BB2AF6523523893A34962F0DF16DF7CC29F813333` |

The four backgrounds were generated as opaque 9:16 photoreal environment
plates with clear central/right water, then selected from built-in ImageGen
without input images. The four fish sheets were generated as 1024x1536 true
RGBA, three lateral specimen rows (head left), with no water, labels, or
shadows. Original source sheets and their selection hashes are retained under
`reports/waters-v40/source-atlases/` and excluded from Android export. Because
the generated fish did not consistently fit exact 512px cells, the production
atlases were mechanically repacked by alpha-connected component: each whole
fish and its anti-aliased edge pixels were isolated, then resized with Lanczos
only as needed to fit a 512px row with 48px outer padding, and revalidated on
light/dark composites. This was deterministic alpha-aware extraction/resizing,
not repainting. `atlas-qa/` retains the
inspection composites; production checks scan every x coordinate at row
boundaries 511/512/1023/1024.

Water masks are source-specific, feathered SVGs under
`art/ui_v1/runtime_source/water-motion-v01/`. Mangrove covers its open tidal
channel; Bayou excludes dry bank; Moonlit excludes dock/post and starts under
the tree line; Offshore excludes the lower-left gunwale. Mangrove uses gentle
tide, Bayou slow murky drift, Moonlit silver ripples, and Bluewater broad swell.
Hatteras alone retains shoreline wash. The new generated plates suppress the
old synthetic crest highlight, avoiding repeated pale ovals; their photographic
features still move through the shared displacement shader. Moonlit only cools
and dims the live rod/hand art slightly for readable night lighting.

## Regional references

These are fictional game interpretations of real regions, not fishing
regulations or guidance: [Florida Fish and Wildlife Conservation Commission](https://myfwc.com/fishing/saltwater/outreach/wheretofish/), [Louisiana Department of Wildlife and Fisheries Atchafalaya plan](https://www.wlf.louisiana.gov/assets/Resources/Publications/Freshwater_Inland_Fish/Inland-Waterbody-Management-Plans/Atchafalaya-Basin-MP-A-2023.pdf), [Arkansas Game and Fish Commission](https://www.agfc.com/news/arkansas-wildlife-weekly-fishing-report-309/), and [NOAA Atlantic highly migratory species](https://www.fisheries.noaa.gov/topic/atlantic-highly-migratory-species).

## Evidence and approval state

`reports/waters-v40/` contains source-atlas, mask, and validation evidence.
The final import/parser and deterministic all-24-fish domain sweep pass. The
first domain sweep exposed new apex timing escapes and stale v39 assertions;
its receipt is retained as superseded diagnostic evidence. Broad render/export
and the in-place Pixel install pass; their audit is
[release-audit-v40.md](../reports/waters-v40/release-audit-v40.md). Drive
delivery is size/hash verified locally through DriveFS without claiming cloud
sync; post-launch device dwell/log and installed-base review also pass with
retained nonfatal startup warnings. Physical motion/haptic feel and human
visual acceptance remain separate gates and must be recorded only when actually
complete.

Primary independent domain validation also passed in 43.7 seconds (`root
125304`; only the established 12 ObjectDB / 5 resource teardown notices).
Six 32-frame, 8fps motion captures verified live water without moving chrome:
the header comparison ROI was exactly unchanged in every clip, and dry mask
ROIs were exactly unchanged. Bottom-right-water mean absolute RGB change ranges
were Mangrove 10.22622–13.51920, Bayou 0.80280–0.94381, Moonlit
1.95806–2.46030, and Offshore 11.77929–13.04228. Moonlit and Offshore
reduced-motion clips were whole-frame exact-zero deltas. Representative
intermediate frames retained photographic texture. Raw 192 motion frames remain
in the isolated E: cache rather than being committed as release evidence.
