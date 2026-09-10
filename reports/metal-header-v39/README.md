# Metal location header v39

The existing full-width rustic top rail remains the single artwork owner. This
pass replaces only the native left-plaque text: each location now uses a
measured Cinzel variable-font treatment with a blackened recess, dark
gunmetal face, and one narrow restrained rim for contrast on the wood. It adds
no new plate, opacity panel, raster screen asset, animation, or gameplay
behavior.

## Interaction contract

- `LINE_OUT` is a quiet, larger, vertically centered location sign only. The
  former habitat/channel label and metres are absent.
- Catch reveal no longer repeats a cast-distance caption; fish size and record
  status stay intact.
- Ready, armed, bite, hook, reel, escape, and UI-notice states retain a title
  in the upper left-plaque clear span and a single compact, outlined motion
  directive below it. The title and hint use separate measured rects.
- Top-rail and engraved icon hit geometry are unchanged at safe top `0`, `91`,
  and `180` canonical pixels.

## Font provenance and packaging

The authentic Google Fonts Cinzel variable font and unmodified OFL are stored
in [`art/fonts/cinzel`](../../art/fonts/cinzel/README.md). The font is loaded
as a Godot `FontVariation` at weight 680; `export_presets.cfg` narrowly
includes its OFL license. No generated or third-party raster art is added.

## Validation status

The corrected import passed after one typed-local parser repair. The full
deterministic domain suite passed again after the dark-metal refinement, with
only its established `12 ObjectDB` / `5 resource` shutdown notices. The
primary agent also visually accepted the final dark-gunmetal treatment in four
actual 720×1280 Godot captures indexed in [the gallery](gallery/README.md):
quiet Hatteras line-out, a safe-top-91 Ready instruction, a safe-top-180
fight with the existing tension meter, and an offscreen Hatteras catch.

The signed arm64 `39` / `0.7.5-sign1` export and package audit pass; the paired
Pixel 9 Pro was updated in place with its save hash preserved and a successful
cold launcher start. [Release/package details](release-audit-v39.md) and the
[Pixel receipt](pixel-install-v39.json) are linked separately. The scoped log
has no script/fatal/native-crash marker but does have one nonfatal abandoned
buffer-queue message; this UI pass does not claim human device
visual/performance review, physical motion/haptic feel, or broader gameplay
acceptance. Existing water, shoreline, motion, haptic, save, and Android
generated-source changes are deliberately outside this pass.
