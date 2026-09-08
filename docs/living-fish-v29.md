# Living fish and field journal — v29

## Checkpoint

`0.5.0-livingfish1` makes the motion-only fishing loop responsive to the fish rather than rewarding a held-back phone. It adds distance-aware habitat encounters, independently rolled size, a touch-free terminal recast gate, and a bounded recent-catch field journal. Calibration remains the existing two-cast flow; no practice pond, new water, audio system, or motion-threshold change is included.

## Evidence matrix

| Requirement | Evidence | Status |
| --- | --- | --- |
| Species run/lull fights; pull/ease beats holds | `reports/living-fish-v29/validation/v29-domain-final7.json`; all six at 30/60/120 Hz, phase rolls `0/.37/.83`, delayed 300ms tension response and 100ms load ramp | Automated pass |
| Constant hard/moderate pull loses or underperforms | Same deterministic matrix | Automated pass |
| Pike relief and no-load/pause behavior | Same deterministic matrix | Automated pass |
| Habitat weighting, independent size rolls, terminal motion recast, v4→v5 history migration/sanitation | `reports/living-fish-v29/validation/v29-domain-final7.json` | Automated pass |
| History cap/migration-compatible aggregates | Same domain test | Automated pass |
| Empty/mixed/full journal, detail history, active compact UI, terminal recast, safe/reduced variants | [gallery index](../reports/living-fish-v29/gallery/README.md) | Deterministic render reviewed by agent |
| Independent parser/domain confirmation | `reports/living-fish-v29/validation/primary-v29-{parser,domain}.json`: exit `0`, marker `null`, no task PIDs/windows | Primary automated pass |
| Android package audit | `0.5.0-livingfish1` arm64 debug APK: 54,273,006 bytes, SHA-256 `A0F0B504972D044E676D5EB26AF900E2993A43C6113D97E121F41654C93EFB7E`; v2 debug-signed; package `com.tak.castandcrank`, code `29`, min/target `24/36`, VIBRATE, 818 ZIP entries, no reports/tests/docs/tools/concepts/screenshots/mockups or obsolete `records-screen-v02` | Primary audit pass |
| Physical cast/hook/fight/haptic feel and visual approval | Not run | Pending human/device review |

The known Godot headless teardown warnings (12 ObjectDB instances / 5 resources) match prior checks; scripts exit successfully and no parser/runtime script error is present.

## Runtime art provenance

| Runtime art | Built-in ImageGen prompt purpose | SHA-256 |
| --- | --- | --- |
| [records-screen-v03-empty-slots.png](../art/ui_v1/runtime_source/records-screen-v03-empty-slots.png) | Opaque Catch Records journal, exact baked title, six empty two-column slots; no fish/text besides title | `4568321A5942225584A83C925B04982A10D67DC663750C21CA7A8A7A4A47A354` |
| [journal-detail-v01.png](../art/ui_v1/runtime_source/journal-detail-v01.png) | Opaque Field Notes page with a large fish area and notes area; no species/value text | `A4CCA67E2561A1D1AAFAFF04CC2D5A399ABD72FED8170CF8AB5B08D7D39D786D` |

Both were generated with the built-in ImageGen workflow, inspected before promotion, and intentionally contain no baked dynamic fish, records, or dates. Their static title/framing is opaque; runtime overlays only own the changing fish, names, values, history, and safe-aware controls.

Both durable files exactly match their tool-managed C: generation outputs by SHA-256 and byte length: Records `2,683,974` bytes; Detail `2,787,108` bytes. The verified C: duplicates were then removed under the E: durable-storage rule. Both masters are 941×1672 opaque PNGs; human aesthetic approval remains pending.

### Exact ImageGen requests

Records request, recovered verbatim from the session response-item custom tool call:

```text
Use case: ui-mockup
Asset type: portrait 720x1280 runtime game journal background plate
Primary request: Create one cohesive, fully opaque illustrated field-journal page for a calm fishing game. It must be a clean standalone background for a Catch Records screen: antique open book, deep teal outer background, warm parchment pages, hand-tooled brass and wood trim, engraved fish-scale accents, subtle lake reeds. Bake a tasteful ornate title plaque at the top reading exactly "CATCH RECORDS". Below title, arrange six empty matched record slots in a 2-column by 3-row grid. Each slot has an elegant parchment inset and a small empty brass nameplate area near its lower edge, but absolutely no fish, no fish silhouettes, no labels, no numbers, no body text, no buttons, and no UI words besides the title. Leave generous blank central space in every slot for one runtime fish sprite plus native dynamic record values. Strictly no duplicate card layering, no transparency, no gradients that obscure text, no watermarks. Refined painterly game illustration, legible high contrast, composition designed for 720x1280 portrait safe top area.
```

Detail request, recovered verbatim from the same session record:

```text
Use case: ui-mockup
Asset type: portrait 720x1280 runtime game species journal detail background plate matching an antique fishing field journal
Primary request: Create one cohesive, fully opaque illustrated page for a fishing game’s species record detail. Same visual family as an ornate Catch Records book: deep teal lake edge outside the book, warm parchment, brass fish-scale trim, reeds, aged wood. At top bake an elegant brass title plaque reading exactly "FIELD NOTES". Leave one large blank parchment illustration rectangle in the upper-middle for one runtime fish sprite. Below it create a single broad blank parchment notes area and a small empty brass label plaque. Do not include any fish, silhouettes, species labels, stats, dates, buttons, body text, numbers, or UI words other than FIELD NOTES. No duplicate cards, no transparency, no watermark. High readability for native text, portrait safe area, refined painterly game UI.
```
