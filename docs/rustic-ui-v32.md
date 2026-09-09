# Rustic UI v32 — Screen-Family Masters

## Stage and approval

The user approved the photoreal tackle material direction on September 8, 2026
and asked to carry it into aged wooden signs and screen assets. This document
records the **composition-master stage only**. Generated files live under
`art/ui_v1/mockups/`, are excluded from Android exports. Primary visual review
accepted their rustic material/composition direction for first-pass integration;
the separate fish-icon concept remains user-review-only.

## Screen contract

| Screen | Static owner in master | Native/dynamic owner | Safe-area intent |
| --- | --- | --- | --- |
| Gameplay | Photographic river; weathered-wood hint/sign and three nav-sign regions; photoreal tackle direction | Location, hint, lock state, bobber/line beyond rod tip, fish shadow and effects | Keep top 180 px adaptable; water remains dominant below it. |
| Settings | One weathered cedar/oak clipboard-modal family with iron fittings and readable paper interior | Labels, values, accessibility state and controls | Entire panel reflows below top 0/91/180 inset. |
| Waters | One calm wood-and-paper location-selection layout | Water names, descriptions, selected/discovered state | Back/control targets stay native and safe-aware. |
| Catch | Scenic river and restrained wood measurement/ruler/sign family, never a trophy frame | Fish, species, length, first/PB state and actions | Result body begins below safe top; controls remain native. |
| Records | One opaque paper-and-weathered-wood field-record page, with baked `CATCH RECORDS` title and six empty slots | Exactly one fish/silhouette, name, count and best per slot | Whole page—not isolated labels—moves for top 0/91/180. |
| Field Notes / loading | Coherent carved-wood/paper framing and photographic river motif | Progress, recent history, empty state and localized copy | Fixed art supports native safe-aware labels. |

## Visual rules

- Photoreal graphite, cork and restrained metal tackle follows the approved
  preview. A rod’s baked guide line reaches only its terminal tip; runtime mono
  must begin there. The small red-and-white float is distant and fully
  submerged during the fight state.
- UI uses weathered cedar/oak, worn edges, shallow engraved or paint-filled
  lettering and muted iron. It avoids gold filigree, toy shine and cartoon
  outlines.
- Static framing has one opaque owner. Runtime layers are reserved for dynamic,
  localized, stateful, safe-area-aware or animated elements; Records does not
  duplicate baked title, fish or cards.
- Gameplay stays motion-only. This art pass adds no touch casting, hook or
  fight affordance and does not alter AdMob's native-bottom zero reserve.

## Tilt / icon-only chrome checkpoint

The user directed the player-facing term **Tilt** in place of Cock and chose
icon-only top navigation on September 8, 2026. The underlying motion fields,
telemetry, thresholds, save keys, and recognition sequence deliberately retain
their existing `cock` identifiers: this is a copy-only change, not a motion
retune. The weathered-wood ready beam now exposes only its closed ledger, map,
and gear engravings; native labels no longer overlap those icon plaques.

The same safe-aware geometry owns draw and press routing. At safe tops 0, 91,
and 180, deterministic interaction tests press rendered ledger/map/gear
interior points, verify Records/Waters/Settings routing, and keep the active
gear reachable while the other two targets are locked. The full suite passed
in [v32-tilt-iconnav-domain-final2.json](../reports/rustic-ui-v32/validation/v32-tilt-iconnav-domain-final2.json).
Fresh desktop-only 720×1280 review captures are indexed in
[the Tilt gallery](../reports/rustic-ui-v32/gallery/README.md). This validates
rendered geometry and copy only; device interaction, motion feel, and human
aesthetic acceptance remain pending.

## Master ledger

Each output was made with one separate built-in ImageGen request, copied to
E:, and SHA-256 verified against its tool-managed original before that
disposable original was removed. Built-in ImageGen does not expose a model ID.
All masters are 941 x 1672 px.

| Master | Purpose | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| [rustic-gameplay-master-v01.png](../art/ui_v1/mockups/rustic-gameplay-master-v01.png) | Full portrait active fishing | 2,946,643 | `D5DCEBFAE7509951D5DC0AA4411B142C7A6AD299A49BC818B4DF19DA801D41B1` |
| [rustic-settings-master-v01.png](../art/ui_v1/mockups/rustic-settings-master-v01.png) | Settings/motion family | 2,716,297 | `F0344C9EF29671FC406D4473E935362DEBF2399422F9374603397A83179194C2` |
| [rustic-waters-master-v01.png](../art/ui_v1/mockups/rustic-waters-master-v01.png) | Water selector | 3,038,526 | `E5C17770006ED9822845100AA7B4AB4D91D70CA7E2A3DE349356DAE972A29330` |
| [rustic-catch-master-v01.png](../art/ui_v1/mockups/rustic-catch-master-v01.png) | Scenic landing | 2,723,303 | `AE16BA35663FE335BEF1E062F7C573433E0294A4A97E38A5285A26ED0F819D2A` |
| [rustic-records-master-v01.png](../art/ui_v1/mockups/rustic-records-master-v01.png) | Blank six-slot records page | 2,726,845 | `36244E62A5DE4EA36B75C042D029609870E04E84429D196019813FE6EE90EB8D` |
| [rustic-records-master-v02.png](../art/ui_v1/mockups/rustic-records-master-v02.png) | Corrected records page: baked title and blank footer plaques | 2,560,835 | `FCD98807341832894A1D7110AF43252AA51259401B1108F6BA1D911A497F1C42` |
| [rustic-field-notes-loading-master-v01.png](../art/ui_v1/mockups/rustic-field-notes-loading-master-v01.png) | Field notes/loading family | 2,594,134 | `25A6D28069EBF47B9EB3F532788F9D7FC179DC442A86B00800B18EB1298C875B` |

## Selected runtime-art ledger

These selected runtime assets were generated with the built-in ImageGen tool,
copied to their durable `E:` paths, and retained as source assets for the
current checkpoint. The exact tool-call prompts for these three derived assets
are not recoverable verbatim from the retained local generation history; the
roles below are descriptive provenance, not reconstructed prompts. Built-in
ImageGen does not expose a model ID.

| Asset | Dimensions / bytes / SHA-256 | Alpha and runtime role | Current status |
| --- | --- | --- | --- |
| [top-nav-rustic-v01.png](../art/ui_v1/runtime_source/top-nav-rustic-v01.png) | 2172×724; 1,984,139 bytes; `427923720311F8573D1AABD0D86CC731D7B1B8DAC46E41862A4B450CE08744FF` | Opaque weathered wood/iron source. Runtime maps beam `Rect2(0,172,2172,323)` once for ready chrome; compact hint uses its blank wood region and active gear maps `Rect2(1793,223,249,257)`. No alpha keying. | Selected for the user-approved rustic direction; current desktop top-chrome integration reviewed. Human/device acceptance pending. |
| [rod-photoreal-alpha-v01.png](../art/ui_v1/runtime_source/rod-photoreal-alpha-v01.png) | 941×1672; 544,829 bytes; `55976AD81DE829D81E6FDF89CE7959FDB30CAAEF345A06F90B885382E7B2BEB4` | Genuine alpha first-person graphite/cork/reel tackle master; its baked guide line ends at terminal guide `(785,42)` and runtime mono begins there. | Selected after desktop composite edge review; runtime bending/device acceptance pending. |
| [bobber-photoreal-alpha-v01.png](../art/ui_v1/runtime_source/bobber-photoreal-alpha-v01.png) | 1374×1145; 305,198 bytes; `FD813E6C2EC6B381C4F45EAFADBDD89A8119C68A38CCBE34BE2B76A39CBE22C5` | Genuine alpha compact red/white float. Runtime uses padded visible-body source crop `Rect2(496,369,383,488)` so its 18–30px presentation scale measures the float, not transparent canvas. | Selected for first-pass runtime presentation; surface occlusion/fight and human/device acceptance pending. |

The source-art prompts emphasized photoreal weathered cedar/oak and iron for
top navigation, a graphite/cork spinning rod with its line only through the
terminal guide, and a compact realistic red/white float. They did not authorize
any change to motion controls or gameplay thresholds.

## Exact generation prompts

### Gameplay

```text
Use case: photorealistic-natural
Asset type: complete 9:16 portrait master for a motion-only mobile fishing game gameplay screen, screen-family concept only
Input images: Cedar River photograph is the background and natural-light reference. Photoreal tackle preview is the approved material/perspective reference for rod, cork, reel, line and float.
Primary request: Create ONE full true 9:16 active-fishing screen composition, not a diptych, not a collage. A calm photoreal Cedar River dominates the screen. In first-person, a matte graphite spinning rod with naturally pitted muted cork grip and restrained silver guides enters from the lower-left, with a partly visible realistic spinning reel. Its built-in guide line visibly continues only through the guides to the precise terminal tip. From that tip, a fine translucent monofilament line reaches a small distant red-and-white float in open water near the upper-right-middle.
UI family: At the upper safe header region, show only an understated weathered cedar sign for a short motion hint and three compact separate weathered oak navigation signs for records, waters and settings. Each sign has worn edges, shallow engraved/paint-filled readable lettering, and muted dark iron fittings. Do NOT use gold filigree, fantasy scrollwork, cartoon outlines, teal plastic, oversized UI, trophies, touch casting controls, or a huge opaque header. Leave clean locations for native text rather than baking legible words.
Composition/framing: true 9:16 portrait 720x1280-style composition. Keep the river and open water visually dominant. Reserve adaptable, low-detail top 180 px for the header/sign region and a low-detail lower edge for future native UI. Float small (roughly 18–30 px at phone scale), water contact natural and restrained. No fish, no visible person except the hand implied by the lower grip, no labels/logos/watermarks.
Style/medium: natural high-end outdoor photography merged with physically plausible game UI art direction; weathered real cedar/oak and matte metal.
Avoid: painterly style, hyper-detailed artificial texture, high-HDR glow, symmetrical rock staircases, fantasy glitter, yellow rope line, turquoise splash symbols.
```

### Settings

```text
Use case: ui-mockup
Asset type: complete true 9:16 portrait master for a rustic mobile fishing-game settings and motion-setup screen, screen-family concept only
Input images: Existing Settings screenshot is a layout and hierarchy reference only. Rustic gameplay master is the approved natural wood, iron and photographic family reference.
Primary request: Create ONE full 9:16 portrait settings screen, not a collage. A single weathered cedar/oak clipboard-style modal sits over a subdued photographic river. The modal has realistic worn wood edges, muted iron hinges/fittings and a warm worn-paper interior for readability. Use a single static header plaque and a single static footer plaque; leave them blank for native dynamic text. Include three broad simple horizontal row fields for settings values, an unobtrusive small explanatory-copy area, two medium action plaques, and the footer. Keep ample vertical spacing and at least phone-friendly 64px-equivalent touch areas.
Composition/framing: top 180 px must remain safe-area adaptable; the entire clipboard is positioned to reflow down as one coherent unit. No duplicate title plaques, no layered cards, no cutoff footer. All words/values must be omitted or represented by unreadable placeholder marks because runtime text stays native.
Style/medium: believable aged cedar/oak, shallow engraved or light paint-filled lettering surfaces, dark iron instead of gold, worn parchment/paper. Natural photographic river at low contrast behind it. Cohesive with the approved graphite/cork fishing tackle family.
Constraints: no teal plastic, no gold filigree, no fantasy leaves, no cartoon sheen, no text/logo/watermark, no gameplay controls.
```

### Waters

```text
Use case: ui-mockup
Asset type: complete true 9:16 portrait master for a rustic mobile fishing-game water selection screen, screen-family concept only
Input images: Existing locations screenshot is layout reference only. Rustic gameplay master is style reference.
Primary request: Create ONE complete 9:16 portrait water-selector screen. Present two large photographic water-location panels stacked vertically, each naturally framed by slim aged cedar/oak and muted iron rather than ornate cards. The upper card suggests a quiet lake cove and the lower card a cool current river, each with enough blank aged-paper or wood-caption area for native water names, short habitat hints, selection and discovered-count copy. A single compact blank back plaque belongs in the top safe region. Keep controls native-ready and leave all lettering blank.
Composition/framing: portrait 720x1280-style. Top 180 px adaptable. The two panels plus their caption regions are distinct, spacious, aligned and readable with no duplicated labels, no game rod crossing the selector, no trophy imagery. Preserve the visual family of weathered real wood, light paint-filled/engraved lettering surfaces, worn paper, dark iron fittings and restrained natural river photography.
Style/medium: realistic aged cedar/oak, muted iron hardware and outdoor photo scenes, not fantasy UI.
Constraints: no teal plastic, no gold trim/filigree, no cartoon outlines, no existing text/logos/watermarks, no extra map or gear icons.
```

### Catch

```text
Use case: ui-mockup
Asset type: complete true 9:16 portrait master for a scenic fishing-game catch landing screen, screen-family concept only
Input images: Existing catch screenshot gives state hierarchy only. Rustic gameplay master gives photographic river and wood/tackle family.
Primary request: Create ONE full 9:16 portrait scenic catch landing screen. A photoreal river fills the scene with natural calm late-afternoon light. Reserve a central-to-upper clear area for one runtime fish lift/reveal; do not bake a fish. Provide a slim rustic wooden measuring ruler/measurement strip beneath it, then a lower restrained dark-weathered-wood and warm-paper result area with clear blank native-text hierarchy zones and two compact blank action plaques. Add only a subtle carved first-catch/new-record accent zone, never a trophy frame.
Composition/framing: true portrait 720x1280 style, whole result body below a top safe area that can reach 180 px. Keep the river visible around the reveal and no duplicate cards over background. Leave all wording blank. The catch should feel like a memorable quiet landing, not an awards ceremony.
Style/medium: photoreal river scenery; weathered cedar/oak, worn paper, muted iron fittings, fine engraved/paint-fill surfaces. Cohesive with graphite/cork tackle but do not include a rod or fish as a permanent baked subject.
Constraints: no golden trophy, no gold filigree, no cartoon fish, no UI labels/logos/watermark, no bright teal panels, no huge opaque card.
```

### Records

```text
Use case: ui-mockup
Asset type: complete true 9:16 portrait master for a rustic fishing-game catch-records page, screen-family concept only
Input images: Existing Records screenshot is layout/ownership reference only. Rustic settings master gives weathered wood, paper and iron family.
Primary request: Create ONE full portrait 9:16 opaque Catch Records field-journal page. It must have a single baked static title crest at its top reading no legible words or leave a clear carved-title zone, then exactly SIX empty, equal record slots arranged in two columns by three rows. Each slot is a unified warm worn-paper panel inset into a realistic weathered cedar/oak ledger, with blank native-text strips/areas below its fish space. Do NOT bake fish, species names, counts, measurements, duplicate cards or decorative trophy frames. The page must feel like one cohesive old field notebook/wood clipboard, not stacked translucent layers. Include one discreet native-ready back control and a small reserved safe-aware World Records target that does not cover the crest.
Composition/framing: full true 9:16 page, readable at phone scale and arranged so the entire page can shift below a 0/91/180 top inset. Large clear fish spaces and consistent blank slots. Native text and runtime fish/silhouettes will be layered once only later.
Style/medium: aged cedar/oak ledger with worn parchment, muted black iron hardware, shallow engraved / light paint-fill title surfaces. No gold, no fantasy leaves, no cartoon gloss.
Constraints: no fish, no words/logos/watermark, no gold filigree, no trophy icons, no extra cards, no transparent overlays.
```

### Field Notes/loading

```text
Use case: ui-mockup
Asset type: complete true 9:16 portrait master for a rustic fishing-game field-notes and loading screen family, screen-family concept only
Input images: Rustic settings master defines aged wood/paper/iron materials. Cedar River photograph defines the natural photographic environment.
Primary request: Create ONE full 9:16 portrait field-notes/loading composition that can anchor both a quiet loading screen and a species-detail/field-notes page. It has a photographic Cedar River framed by a single weathered cedar/oak field notebook/clipboard, warm aged paper, muted black iron clips and a compact blank crest. Reserve a generous blank native-text title area, one broad blank illustration/species area, several orderly blank note/history lines, a single blank footer/back plaque and a small unobtrusive loading/progress zone. Keep the composition restful and readable; do not bake fish, player data, text, dates, rankings or fake loading percentage.
Composition/framing: one coherent portrait 720x1280-style screen. Keep top safe area adaptable to 180 px and footer clearly inside the panel. No stacked duplicate cards; each static region has one owner.
Style/medium: true weathered cedar/oak, old paper, functional iron hardware, natural forest-river photography. Matches the rustic gameplay/settings/records family.
Constraints: no gold, no fantasy foliate decoration, no trophy frame, no cartoon art, no UI words/logos/watermark, no extra touch controls.
```

### Records correction v02

```text
Use case: precise-object-edit
Asset type: corrected 9:16 rustic Catch Records composition master.
Input image: the provided rustic six-slot records master is the edit target.
Primary request: Change ONLY these elements: replace the fish engraving in the top wooden crest with the exact readable engraved and pale paint-filled title "CATCH RECORDS"; remove the circular arrow button at lower left; replace the whole footer control area with TWO matching blank weathered-wood rectangular sign plaques, one lower-left and one lower-right, with no words, arrows, symbols or text. Keep the six empty paper record slots, all existing geometry, wood/paper/iron material, blank native text strips and photographic background exactly consistent.
Constraints: preserve portrait 9:16 size and the single coherent opaque page. Do not add fish, trophy art, duplicate cards, labels, logos, watermark or gold decoration.
```

## Review findings to carry into derivation

- Gameplay's wide hint board must be blank and usable for native location and
  glance text; its generated fishing pictogram is concept-only. The user
  selected **icon-only** top navigation: Records uses a closed-ledger/book
  engraving—not a trophy goblet—and map/gear remain engraved symbols with no
  runtime captions over their plaques.
- Settings' generated row dashes/underlines are placeholders, not a surface for
  native labels. Production rows need genuinely blank wood/paper text regions.
- Waters' arrow is composition-only. Runtime must expose the explicit native
  `BACK TO FISHING` sign rather than a lone arrow.
- Catch retains the open fish-reveal zone above its ruler and its non-trophy
  wood/paper treatment. It must use the selected location's actual plate later,
  not silently substitute the concept river photograph.
- The Records master is suitable directionally because it has six empty slots,
  but v01's crest motif/footer arrow are superseded. Use v02's baked `CATCH
  RECORDS` title and blank paired footer plaques; dynamic fish,
  names/counts/bests remain single native/runtime owners.
- The combined Field Notes/loading v01 is style-only: its half-filled progress
  line is not valid for history. A later detail plate must omit fake progress;
  loading will be a separate photographic-river and wooden-sign composition.

## Review gate

Primary visual review has cleared the selected masters for bounded runtime
derivation. Runtime/device/human-aesthetic acceptance remains pending; final
captures must still prove safe-area geometry, dynamic ownership and no duplicate
layers before a package is considered.

## Current integration boundary

The approved rustic runtime family is integrated for desktop review: fixed
top chrome, continuous photoreal tackle, Pine v03/Cedar scenery, clipboard
ordinary screens, Waters cards, Records/World Records/Field Notes, Catch, and
Hooked loading. Primary review cleared the Pine v03 correction and the final
Records/Waters layouts for build review. This is **not** a claim that the user
has accepted the final aesthetics. Export, Android installation, Drive delivery,
and device acceptance remain pending verified primary receipts.

Independent v32 gate evidence recorded no markers, windows, or remaining task
PIDs: domain roots `111688`, `119980`, and `118224` all exited `0`; domain
stderr retains only the known 12 ObjectDB / 5 resource teardown diagnostics.

## Verified delivery receipt — September 8, 2026

This is the historical `0.6.1-rustic1` delivery receipt, not a claim that the
current `0.6.2-tension1` follow-up has been exported or installed.

## V33 tension-visibility follow-up

Version `0.6.2-tension1` / code `33` adds only the safe-aware native REELING
tension meter. It has static outlined text, clamped fill/marker, visible .65
high and .90 danger thresholds, and no enclosing panel or gameplay tuning
change. Primary visual review cleared low 32%, high 88%, danger 95%, Cedar
safe-180, and reduced-motion tall evidence. Independent domain receipt
`primary-v33-domain.json` (root `114328`) exited `0`, marker `null`, with no
remaining PID/window; capture wrappers `120052` and `107496` were equally
clean. V33 export, Pixel replacement installation, and local DriveFS delivery are verified in the [final release receipt](../reports/rustic-ui-v32/release-v33.md). Human aesthetic and physical-feature acceptance remain separate.

Primary export `primary-v32-export.json` completed at 22:11:09 local time:
root PID `124396`, exit `0`, empty stderr, no marker, no remaining task PID or
window. The tracked Gradle daemon `121164` used the E: JDK/Gradle cache for both
project builds and was stopped after the successful export; the final process
inspection found no Godot, Java, or WerFault process.

The signed deliverable is `build/android/Hooked-0.6.1-rustic1-arm64-debug.apk`
(58,138,120 bytes / 55.44 MiB, SHA-256
`A7A9673FD395DA94A8D98C0187D8F1D3407EB42D000E8166BCA4630DB3113EE3`).
`aapt` verified package `com.tak.castandcrank`, version code `32`, version name
`0.6.1-rustic1`, label `Hooked`, min SDK `24`, target SDK `36`, VIBRATE, and
arm64-only output. `apksigner` verified the existing certificate
`c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc`.

Pixel 9 Pro (`caiman`, 192.168.1.234:38467) replacement install succeeded;
code `32` and VIBRATE grant were confirmed. The existing save file hash matched
before and after install, before launch. Launcher cold start completed in 377 ms
(wait 381 ms), PID `25162` stayed stable after 20 seconds, top-resumed matched,
and current-process fatal/script/parse/SIGSEGV markers were zero. No phone
screenshots or raw-trace retrieval was performed.

The verified local DriveFS copy is
`H:\My Drive\AI Projects\Haptic Fish\Hooked-0.6.1-rustic1-arm64-debug.apk`;
bytes and SHA-256 match the local APK. Cloud-sync completion is not claimed.
Physical UI/motion/haptics/native-ad validation and final human aesthetic
acceptance remain separate. The old launcher icon remains pending approval and
the PGS owner configuration remains unconfigured.

## V32 promoted runtime derivatives — September 8, 2026

The user initially rejected the first desktop Settings/reeling composite because
it exposed legacy gameplay behind the board and had invisible actions. The
replacement integration uses one opaque clipboard board over only the selected
natural scenery, visible wood action planks, and native centered text. This is
agent visual-review evidence, not human approval.

| Asset | Dimensions / bytes / SHA-256 | Alpha / role / approval |
| --- | --- | --- |
| [rustic-clipboard-blank-v01.png](../art/ui_v1/runtime_source/rustic-clipboard-blank-v01.png) | 941×1672; 2,433,477 bytes; `4E07A5AB71E95BA08A8F0AE330BBA4A879B52FBA4B4B933D090E184C0ACECB0F` | Opaque, reusable single full-master map for Settings/Motion/diagnostics/capture/field notes. Primary visually approved its blank paper/header/footer for integration. |
| [pine-lake-photoreal-v02.png](../art/ui_v1/runtime_source/pine-lake-photoreal-v02.png) | 941×1672; 2,587,241 bytes; `7D1DFEC78DA2053FC95011642721D7DFF72C9411A322073CFD96727A929E76D0` | Superseded Pine provenance only; excluded from runtime/export in favor of v03. |

Both files were generated using the built-in image tool, copied to their durable
E: paths, SHA-256 matched to their tool-managed originals, then only those
verified disposable originals were removed. The built-in tool did not expose a
model identifier.

### Exact blank clipboard prompt

```text
Use case: precise-object-edit
Asset type: reusable runtime blank rustic clipboard background for a mobile fishing game
Input image: the immediately preceding settings-rustic-v01.png is the edit target.
Primary request: Preserve the photoreal weathered cedar/oak clipboard, black iron fittings, warm worn-paper interior, and subdued natural river background. Remove ALL interior baked UI marks: the three horizontal setting rows, dark value plates, action plaques, divider dashes, fish-divider, and every placeholder mark. Leave a single continuous blank warm-paper interior that is clean enough for readable native runtime text and controls. Preserve ONE blank wooden header plaque and ONE blank wooden footer plaque only. Keep the frame proportions and portrait composition unchanged.
Constraints: all header and footer wood must be completely blank; continuous blank paper interior; no text, symbols, fish, progress bars, row lines, cards, labels, logos, watermarks, gold filigree, teal tint, translucent overlay, or white matte. Keep the background opaque and naturally photographic.
```

### Exact Pine Lake prompt

```text
Use case: photorealistic-natural
Asset type: runtime portrait background plate for Pine Lake gameplay in a mobile fishing game
Input images: Image 1 is the old Pine Lake geography/layout reference; Image 2 is the approved Cedar River photographic lighting and realism reference.
Primary request: Create a photoreal, natural-light, quiet Pine Lake forest cove at true portrait 9:16. Preserve the old Pine Lake composition: open still water dominates the lower foreground and center for gameplay, reeds and lily pads are confined near the lower left/right banks, tall evergreen forest and low rocky banks frame a distant calm lake opening. Match the real outdoor photographic material and restrained lighting of the Cedar River reference, not its exact river geography.
Composition/framing: reserve clean open water from mid-frame through the lower center for a runtime rod, line, bobber and subtle ripples. Keep the top 180px visually simple enough for a separate wood header. No UI, signs, rod, hand, reel, line, bobber, fish, people, text, logo, watermark, illustration, cartoon treatment, high-HDR, fog band, teal plastic, or white matte.
Style/medium: believable high-end outdoor nature photography, realistic pine needles, reed detail, gently reflective lake water, muted late-afternoon natural light.
```

### Pine Lake v03 correction

After user feedback that the v02 pond used repetitive etched microtexture, the
primary reviewer approved the following targeted v03 derivative for current
implementation review: [pine-lake-photoreal-v03.png](../art/ui_v1/runtime_source/pine-lake-photoreal-v03.png), 941×1672, 2,499,723 bytes, SHA-256 `F933A9C5499986A36C60D42F76CFB9A8AA47B006479CBDD1E039DCAFF8F6EDEC`, opaque. It is the only Pine Lake gameplay asset referenced by runtime; v02 is excluded from export.

```text
Use case: precise-object-edit
Asset type: runtime Pine Lake portrait gameplay background
Input image: the immediately preceding pine-lake-photoreal-v02.png is the edit target.
Primary request: Preserve the portrait bank/open-water composition and clean center/lower water space for a runtime rod, line and bobber. Change only rendering/detail quality: make it read as a true natural camera photograph with softer lower-contrast distant tree detail, asymmetrical varied rock and vegetation forms, broad calm water patches interspersed with irregular reflections and ripples.
Constraints: remove the uniform etched or oversharpened high-frequency microtexture and any tiled/repeated pattern across water, rocks, trees, or shore. Do not blur everything; retain believable natural detail with varied scales. No UI, wood signs, rod, hand, reel, line, bobber, fish, people, text, logos, watermarks, illustration, cartoon treatment, HDR glow, teal tint, fog band, white matte, or extra subjects.
```
