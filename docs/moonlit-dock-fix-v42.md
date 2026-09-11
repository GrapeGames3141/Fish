# Moonlit dock water-mask fix v42

## Scope

This narrow fix changes only
`art/ui_v1/runtime_source/water-motion-v01/moonlit-mask.svg`. The measured
water-side contour now follows the Moonlit Reservoir dock/post silhouette with
a small static-wood margin. The shared water shader, every other location's
mask, gameplay, UI, package version, and Android configuration are unchanged.

## Evidence

- Original 720x1280 `moonlit_ready` motion baseline: 24 frames at 8 fps,
  `v42-moonlit-before-motion` (root `100192`, exit 0).
- After the final contour edit, Godot reimported `moonlit-mask.svg` through
  `v42-moonlit-import-postcap-final` (root `114752`, exit 0), then produced
  fresh normal and Reduced Motion 24-frame captures: roots `119124` and
  `114708`, both exit 0. The accepted post-edit frames are not from a stale
  imported texture.
- The parameterized focused test, `v42-moonlit-mask-postcap-final` (root
  `125964`, exit 0), probes all 24 frames using tight 3x3 patches along the
  measured post and stepped dock edge plus an exact-pixel source-photo
  classifier across the whole lower-left dock area. It found post, sampled
  edge, and all 1,696,296 classified wood comparisons at maximum RGB delta
  `0.0` with zero changed samples. Adjacent open water retained a maximum
  channel delta of `228.0` with 1,494 changed samples. Reduced Motion recorded
  `0.0` and zero changed samples for post, dock edge, classified wood, and
  nearby water.
- The same classified wood in the original baseline had maximum channel delta
  `164.0` and 25,104 changed comparisons, demonstrating that the original mask
  allowed dock motion rather than merely testing a static interior.
- Primary independently repeated the accepted frame scan as
  `primary-moonlit-final` (root `111428`, exit 0): it reproduced 1,696,296
  classified wood comparisons with zero changes/max `0`, sampled post/edge
  max `0`, and open-water max `228` with 1,494 changes. Its final scoped
  process inventory had no Godot or WerFault process.

Selected before/after/reduced stills are in
[`reports/moonlit-dock-fix-v42/gallery/`](../reports/moonlit-dock-fix-v42/gallery/README.md).
Full raw 24-frame sequences remain in the isolated E: cache
`E:\CodexCache\haptic-fish-moonlit-dock-fix-v42` rather than the shipped tree.

## Limits

This is deterministic desktop visual evidence, not a phone screenshot or a
physical-device/human aesthetic approval. Early post-edit captures and the
first dense test are retained in the validation folder as superseded: root
`38684` reused a stale imported SVG texture; root `122436` followed fresh
import root `8064` but used an intermediate contour with a remaining dock-edge
leak; and the first dense test exposed only a test-harness bounds error.
Primary sparse edge check `primary-moonlit-edge-regression` (root `106480`)
passed its 17 patches but is superseded by the full classified-pixel review.
None is used for final acceptance.

## 0.8.2-dock1 build and delivery

- Fresh import root `127252` and full domain root `43752` passed. The latter
  includes the updated export contract for code `42` / `0.8.2-dock1`; its only
  shutdown notices are the established ObjectDB/resource baseline.
- The first export root `54516` failed before producing an APK because
  `ANDROID_HOME` and inherited `ANDROID_SDK_ROOT` pointed to different SDKs.
  The retry set both to the established E: SDK and passed: root `111388`,
  75.0 seconds, no stderr marker. Its idle task-owned Gradle daemon `126376`
  was explicitly stopped after export.
- `Hooked-0.8.2-dock1-arm64-debug.apk` is 76,232,403 bytes, SHA-256
  `A42B7F57E9D2ACB4A760613EA5589A2582FF47BE99D48DBD8B88C9A0B969CB75`.
  Manifest/signature audit confirms Hooked / `com.tak.castandcrank` / code 42
  / `0.8.2-dock1`, SDK 24/36, arm64 only, VIBRATE, and valid v2 signing with
  the preexisting debug certificate. The embedded imported Moonlit mask hash
  `954ECE73BBE5DAAD82DBD497B029B9C072B5065169C217B95906FECA2DFE86BC` matches
  the current local import; the 868-entry APK contains no forbidden evidence
  or owner payload.
- Primary installed the update on the Pixel 9 Pro with its player save SHA
  unchanged, confirmed a successful cold launch/main loop and a roughly
  40-second alive dwell, then copied the APK to the designated DriveFS folder
  with matching byte/hash verification. This is a verified local DriveFS copy,
  not a cloud-sync claim. No phone screenshot or human physical-feel approval
  is claimed. See the standalone
  [delivery note](../reports/moonlit-dock-fix-v42/README-0.8.2-dock1.md).
