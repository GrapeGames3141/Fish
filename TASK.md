# Gate 1 — foundation, playable greybox, and concept direction

## Waters v40

- Source implementation adds Mangrove Flats, Cypress Bayou, Moonlit Reservoir,
  and Bluewater Offshore after the original four waters: 24 fish in all,
  strict all-earlier-species unlocks at 12/15/18/21, four computed record
  pages, all-eight-water scroll endpoints, additive v6 save support, and
  optional offline-ready 24-fish Play Games configuration support. Capture
  fixtures seed only isolated in-memory review baselines; no live/player save,
  device, or unlock progression is invented.
- Generated scenery is one opaque owner per location; live tackle, bobber,
  header, fish, and native text remain separate. Location-specific water masks
  exclude banks, dock/post, and boat, with Hatteras-only shorewash. The full
  source/provenance/approval ledger is [docs/waters-v40.md](docs/waters-v40.md)
  and evidence is indexed in `reports/waters-v40/`.
- Parser/domain, visual-capture, and primary independent water-motion gates
  pass; the signed arm64-only v40 export and in-place Pixel 9 Pro update also
  pass while preserving the pre-launch save hash. Audit details and explicit
  pending delivery/acceptance limits are in
  [reports/waters-v40/release-audit-v40.md](reports/waters-v40/release-audit-v40.md).
  The local DriveFS copy is hash/size verified without claiming cloud sync;
  installed-base matching and repeated >30-second Pixel dwell pass, with three
  nonfatal SurfaceSyncGroup timeouts and one nonfatal BufferQueue warning
  retained in the audit. Physical motion/haptic feel and human visual acceptance
  remain separate gates.

## Metal location header v39

- Implemented for the next build: the existing full-width fishing rail retains
  its exact safe-area geometry and icon targets while its left wood plaque now
  carries measured Cinzel raised-metal location lettering. Quiet `LINE_OUT`
  and terminal catch center the location in the plaque; guided states reserve
  a non-overlapping lower line for high-contrast outlined motion guidance.
- `LINE_OUT` no longer repeats habitat/channel or cast-distance text, and the
  catch reveal no longer repeats a cast-distance caption. Fish size, records,
  saves, motion, fight, haptic, water, and Android layout behavior are
  intentionally unchanged.
- The authentic OFL Cinzel variable font and unmodified license are bundled
  with narrow export-license inclusion. Final parser/domain/capture review,
  signed arm64 `39` / `0.7.5-sign1` package audit, and in-place Pixel 9 Pro
  update pass; the save hash is preserved across the `adb install -r` update.
  [Evidence](reports/metal-header-v39/README.md) retains superseded parser,
  capture, and initial-export timeout receipts. The scoped post-launch log has
  no script/fatal/native-crash marker but one nonfatal abandoned buffer-queue
  message; human device visual/performance and physical motion/haptic/gameplay
  acceptance remain separate.

## Hatteras shore surf v38

- Corrected primary review replaces the rejected sharp surf front with a bounded single-coordinate photographic shorewash: 0–28px run-up, low-frequency alongshore lag, safe shoreline fades, and a <=7px broad offshore ridge. The original foam/photo moves rather than an image being swapped or an overlay being drawn. Hatteras short-cast bobber/line uses the same surf offset; Pond/Lake/River remain unchanged and Reduced Motion is still.
- The first full-screen capture passed mechanically but was visually rejected for foreground foam foldovers; the corrected 120-frame source capture is provisionally accepted for photographic texture and indexed in `reports/shore-surf-v38/`. Final parser/domain, short-cast, reduced-motion, inland-regression, browser playback, and signed arm64 `38` / `0.7.4-surf1` package audit pass. Device performance and user aesthetic validation remain pending. No install, Drive delivery, or push is claimed.

## Water motion v37

- Implemented for the next build: location-specific photographic water plates behind native tackle/UI, with shoreline masks, shared bobber heave/tilt, a genuinely submerged lower float hemisphere, and reduced-motion freezing. Willow/Pine/Cedar/Hatteras respectively use pond, lake, directed-river, and rolling-ocean profiles.
- User-approved v02 preview is preserved as provenance only; no preview frame/video is shipped. Focused deterministic coverage and a bounded 48-frame capture mode are in place.
- Final parser/domain, all four location stills, Bite/Reeling float absence, reduced-motion freeze, 48-frame Willow/Hatteras runtime samples, and signed arm64 `37` / `0.7.3-water1` package audit are verified in `reports/water-motion-v37/`. Device/profile review—especially the new ocean aesthetic—remains pending. No install, Drive delivery, push, or physical-feel claim is made by this checkpoint.

## Continuous wood-header v36

- Normal fishing states share one full-width, safe-area-aware authored wood rail; Records and Waters remain visibly locked during a cast/fight while Settings retains its fixed target.
- Bite/fight guidance remains native, centered on the left plaque, and the live tension label/meter clear the taller rail. Waters uses one contiguous header with its cards still scrollable below it.
- Scope is UI geometry and presentation only. Motion, fight simulation, haptics, Android packaging, and production art remain unchanged. Desktop render review and automated regression evidence are tracked in `reports/header-v36/`; physical-device and human visual review remain pending.

## Waters v34

- Implemented and independently verified: four regional waters, twelve fish, scrolling species-completion unlocks, v6 save migration, and paginated records. [Feature/art notes](docs/waters-v34.md), [desktop gallery](reports/waters-v34/gallery/README.md), and [signed v34 release receipt](reports/waters-v34/README-v34.md). APK and DriveFS copy are size/hash verified; Pixel install awaits a current wireless-debugging endpoint. Physical feel and human aesthetic approval remain pending.

## Acceptance

- A portrait 720×1280 Godot 4.7.1 project runs a complete Pine Lake Bluegill loop: arm/cast, wait for bite, hook, physically lower then pull the rod through the fight, catch or escape, then cast again.
- Motion uses one gravity-compensated accelerometer/gyroscope sample per update, learned axis matching, and deterministic simulated traces. Android has no cast or hook touch fallback: first run automatically settles then learns two real cock-back/snap casts; keyboard simulation is desktop-only. A smaller learned back gesture hooks only during the hook window.
- A two-pulse bite vibration, one hook cue, data-driven fish fight cadence with quiet gaps, escalating high/red tension warnings, distinct caught/escaped cues, 1.5-second hook window, and a continuous physical rod-load fight are observable. Raising/cocking the rod advances the fish but drives tension; tilting forward/down eases tension with little progress. A controlled Bluegill pull/ease rhythm targets 10–20 seconds; sustained hard pull resolves quickly by landing or red-line escape. Haptics-off clears queued feedback. Android defaults to a cached direct `AndroidRuntime` vibrator emitter with explicit non-touch attributes: API 33+ uses media usage, API 24–32 uses game/sonification audio attributes, then falls back safely when unavailable.
- Local versioned save retains settings, a validated motion profile, catches, and personal best; v1 saves preserve progress but recalibrate. Settings expose sensitivity, haptics, audio, reduced motion, and an explicit recalibration row.
- The AdMob adapter pins Poing 5.0.0 and Google’s test banner ID, documents UMP/general-audience PG configuration, and preserves native-bottom zero-reserve ownership. After consent, the SDK completion callback must run before one native banner request; desktop fallback is safe.
- The signed debug package is arm64-only with compressed native libraries, Android `VIBRATE` permission, and excludes non-runtime evidence/editor/demo material while retaining runtime AdMob dependencies. Its export size and signing evidence must be recorded before any replacement install.
- Automated domain tests and deterministic 720×1280 captures exist. Device/motion/haptic/native-ad claims remain pending physical-device evidence.

## UI production checkpoint

- Living-fish/journal v29 implementation, evidence matrix, selected captures, and runtime-art provenance: [docs/living-fish-v29.md](docs/living-fish-v29.md). Physical/device and human aesthetic acceptance remain separate from automated evidence.
- Settings footer v30 repair, safe-area geometry evidence, and selected desktop captures: [docs/settings-v30.md](docs/settings-v30.md). No new art; physical-device review remains pending.

- The user explicitly authorizes a first-pass, versioned ImageGen UI family: icon, splash, gameplay, catch, and records presentation. Keep dynamic copy as native UI text.
- Gameplay remains motion-only: no cast, hook, or fight touch fallback. Build layered animated pond, rod, line, and bobber states, including bite submerge, fight ripples/splash, and rod bend; provide a glanceable styled motion hint.
- Records must show count and best for every planned fish, not only the active Bluegill. Produce fresh 720×1280 captures and a fresh build after implementation.
- Record image prompts/provenance and keep the delivered first visual pass pending human aesthetic approval before any broader art promotion.

## UI v2 location-and-catch checkpoint

- The user authorized the first Pine Lake/Cedar River runtime art expansion: selected water changes its gameplay plate immediately, and the six planned species use shared transparent three-row atlases in scenic catch reveals only; Records uses the cohesive opaque authored journal with dynamic native stats.
- Immediate catches are scenic location results with one native data plaque; only CATCH RECORDS uses the field-journal/trophy treatment. Gameplay chrome intentionally identifies the water and motion state, never the preselected fish.
- The location selector uses substantial background-plate cards and native species copy. Records presents all six species in the authored journal grid, with native name/count/best values and an em dash for uncaught records.
- Verified: deterministic desktop capture review and signed v26 package/install evidence; the final Records screen uses one opaque integrated art plate with dynamic record text and a safe-area back control, while scenic catches retain no trophy frame or redundant transparency. The user-approved local DriveFS delivery to `H:\My Drive\AI Projects\Haptic Fish\CastAndCrank-0.4.0-ui3-arm64-debug.apk` is byte/hash verified; cloud-sync completion is not claimed. Human aesthetic approval and physical cast/hook/fight/haptic-feel acceptance remain pending.

## Gate decision

The user authorized generation and integration of this first ImageGen UI pass. Human review applies to the delivered first visual pass before broader art promotion or release.

## Expansion reliability/content checkpoint

- Implemented: mirrored left-handed calibration/motion option, rest-baseline thresholding, compact derived diagnostics, 1.8s hook window, generic species/location selection and records, and code-native non-Bluegill catch silhouettes.
- Verified headlessly: deterministic threshold, handedness, hook-window, fight, save migration, selection, and haptic-contract tests.
- Still pending: physical cast/hook rate and comfort, haptic feel, left-handed feel, full fight timing, native ad/UMP visual behavior, and human visual/art approval. No new production art is authorized by this checkpoint.

## Cast-recognition hotfix checkpoint

- Implemented for the next build: direction-aware candidate entry prevents residual cock frames from latching the expected forward snap; retuned learned-profile gates preserve existing v3 calibration data and reduce the Pixel-derived cock/snap/gyro gates.
- Still pending: physical cast/hook reliability confirmation on the paired device. This hotfix has no export, install, or user-feel claim yet.

## Snap-left follow-up checkpoint

- Implemented for the next build: only the post-cock forward snap has a lower learned-profile threshold and bounded relaxed final axis/polarity tolerances; cock, hook, gyro, and both handedness modes keep their prior contracts. Derived failures now name only the stage and reason.
- Signed v15 `0.3.2-snapfix1` is exported, audited, installed, and cold-launched on the paired Pixel 9 Pro. VIBRATE is granted and the scoped startup log has no fatal, script, parse, SIGSEGV, or crash marker.
- Still pending: physical snap-left reliability confirmation. No device-feel claim is made for this follow-up.

## Continuous-gesture follow-up checkpoint

- Implemented for the next build: continuous cock/snap bursts ignore rising sub-threshold frames, can recover from one bad above-threshold axis/gyro frame, and keep only one derived failure record per burst. Runtime cock/snap/gyro/timing gates are separately tuned from calibration.
- Signed v16 `0.3.3-gesturefix1` is exported, audited, installed, and cold-launched on the paired Pixel 9 Pro. VIBRATE is granted and the scoped startup log has no fatal, script, parse, SIGSEGV, or crash marker.
- Still pending: physical cast distance/recognition validation on the paired device. No device-feel claim is made for this follow-up.

## Gate-restoration follow-up checkpoint

- Physical v16 feedback: four accepted casts measured quality/distance `.40` / `20.9m`, `.75` / `31.9m`, `.84` / `34.8m`, and `.41` / `21.2m`; the user judged the recognition gate too easy after the burst-latch repair.
- Implemented for the next build: v17 retains the v16 continuous-burst recovery and timing curve while restoring strict learned-profile snap strength, axis, physical-polarity, and cast-gyro gates.
- Signed v17 `0.3.4-gaterestore1` is exported, audited, installed, and cold-launched on the paired Pixel 9 Pro. VIBRATE is granted and the scoped startup log has no fatal, script, parse, SIGSEGV, or crash marker.
- Still pending: physical v17 cast recognition, distance, and comfort validation. No device-feel claim is made for this follow-up.

## Deliberate-sweep follow-up checkpoint

- Physical v17 feedback: strict numerical gates still admitted a hair-trigger cast, with the retained log showing one accepted quality `.36` / `19.5m` near-floor result. The evidence points to momentary qualification rather than an overly low numeric gate.
- Implemented for the next build: runtime cock and snap now need a deliberate three-sample, capped-time directional impulse sweep before their unchanged strict final gates may recognize; hook remains a quick one-frame gesture.
- Signed v18 `0.3.5-shapefix1` is exported, audited, installed, and cold-launched on the paired Pixel 9 Pro. VIBRATE is granted and the scoped startup log has no fatal, script, parse, SIGSEGV, or crash marker.
- Still pending: physical v18 cast recognition, distance, and comfort validation. No device-feel claim is made for this follow-up.

## Sweep-energy tuning follow-up checkpoint

- Physical v18 feedback: casts remain a little too easy despite the three-sample shape gate.
- Implemented for the next build: retain all v17 gates, v18 shape parameters, timing, recovery, handedness, hook, and fight behavior while raising only the cock/snap impulse factors from `4.5%` / `5.5%` to `5.5%` / `7.0%`.
- Physical v19 feedback after installation: the higher impulse factors are too hard, so they are superseded by the proven v18 factors below. No broader comfort or haptic-feel claim is made for that check.

## Explicit ten-cast capture checkpoint

- Implemented for the next build: restore v18's `4.5%` / `5.5%` runtime sweep energy and add one Settings-only `RECORD 10 CASTS` workflow. After its countdown, ten automatic 2-second haptic-cued windows collect bounded raw gravity, accelerometer, derived-linear, and gyro samples; normal diagnostics remain derived-only.
- Signed v20 `0.3.7-capture1` is exported, audited, installed, and cold-launched on the paired Pixel 9 Pro. VIBRATE is granted, the scoped startup log has no fatal/script/parse/SIGSEGV/crash marker, and no raw trace exists before explicit capture starts.
- Still pending: the completed explicit capture file must be retrieved and reviewed before any further recognition tuning; no physical v20 recognition, distance, or comfort claim is made.

## Android diagnostic autocapture follow-up

- Device evidence: automated gear/record taps on the 960×2142 edge-to-edge Pixel did not create a capture file; the physical gear lies near y≈90 under the top cutout/mandatory gesture inset.
- Implemented for the next diagnostic build: Android-only, one-shot capture autostart waits for the existing splash to clear, then starts the same ten-cast countdown without any touch dependency. Desktop and scripted capture scenarios are excluded.
- Superseded outcome: v21 was exported, installed, and its explicit trace was retrieved. The permanent safe-inset/top-chrome gear repair remains separate work; v22 keeps trace capture explicit and awaits device confirmation.

## Physical cock-profile follow-up

- V21 `0.3.8-autocapture1` was exported, installed, and used to retrieve the explicit ten-cast capture `pixel9pro-cast-capture-v21-2026-08-30.json` (SHA-256 `DA61E2A901E70266786D903DEC763132124B6BBB8B89A6B3B6A3DD9E69AD8F70`). The current learned-axis cock replay accepted `1/10` intended windows; its failures were principally cock-axis rather than sweep-energy failures.
- The deterministic replay's asymmetric candidate keeps the learned 3D snap unchanged and substitutes signed physical right/left X only for cock/hook. Its strict final-amplitude-first `6×` physical cock threshold with `.045` cock impulse accepted and timely armed `10/10` captured windows; snap remains `.055`. The intended-positive trace is not false-positive evidence.
- Signed v22 `0.3.9-castprofile1` was exported, audited, and installed on the paired Pixel 9 Pro. Two text-only cold launches reproduced a deterministic self-cast/self-hook feedback loop (`MOTION_CAST quality=1.00`, then `MOTION_HOOK`) without a crash; that is regression evidence, not a physical acceptance claim.

## Motion-feedback guard follow-up

- V23 `0.3.10-motionguard1` was exported, audited, and installed after removing the physical cock motor cue, adding explicit `.65s` CAST_ARMED cancellation, and holding BITE for `.42s` before the independent full `1.8s` hook window.
- Repeated untouched v23 cold-launch dwell still produced false cast/hook behavior, so the build is regression evidence rather than acceptance. Physical cast/hook reliability, haptic feel, false-positive rejection, and safe-inset usability remain pending.

## Feedback-guard v24 follow-up

- V24 `0.3.11-feedbackguard2` was exported, audited, and installed. Its corrected untouched dwell (PID `25744`) still false-cast then self-hooked with derived telemetry `projection=95.62`, `axis=.69`, `polarity=.51`, `gyro=31.11`, `reversal=.115`, `cock=12.46`; no fatal marker was found. This is a false-positive regression, not a physical acceptance result.

## Profile-guard v25 follow-up

- The genuine ten-cast replay has minimum scalar snap axis `.8203` and physical polarity `.6668`. V25 `0.3.12-profileguard3` raises only the runtime snap floors to `.78` / `.62`, retaining all ten recorded intended examples while rejecting the v24 `.69` / `.51` false signature. Hooks now require a deliberate three-sample `.055` sweep and log derived scalar telemetry; haptic settle is `.30s`.
- V25 was exported, audited, and installed. Two corrected untouched 15-second dwells (PIDs `30931` and `31349`) recorded zero cast, hook, cancel, failure, and fatal markers. This does not establish physical cast/hook feel, comfort, or gameplay acceptance.

## UI v3 navigation correction

- Implemented in v27: a single opaque three-target ImageGen strip owns the closed-ledger `RECORDS`, waters-map `WATERS`, and gear `SETTINGS` artwork. Rendering and press handling refresh one shared safe-area geometry source; Records/Waters visibly lock while fishing is active, while Settings remains available in every normal world state.
- Records and water selection now exit through a safe-area-aware, art-backed `BACK TO FISHING` plaque. Existing motion-only gameplay controls are unchanged.
- Version `0.4.1-navfix1` / code `27` is exported, package-audited, installed, and text-only cold-launched on the paired Pixel 9 Pro. The existing pairing key was confirmed by mDNS discovery after a local ADB restart; `adb install -r` succeeded, VIBRATE is granted, PID `1133` remained alive, and the PID-scoped startup log has no fatal/script/parse/SIGSEGV/crash marker. Physical Settings/Records/Waters touch, safe-inset comfort, cast/hook/fight/haptic feel, ad behavior, human aesthetic approval, and any device visual review remain pending; no phone screenshot was taken.

## UI experience polish v28

- Source-only `0.4.2-uipolish1` / code `28` compacts gameplay chrome, keeps the authored nav as one opaque proportional plate, and gives every Settings, Motion Setup, catch, and overlay control a named shared draw/hit rect. Raw touch now ignores its matching emulated mouse event.
- Water cards show short water character and discovered species count. Switching is blocked during a cast/fight, while terminal results reset cleanly before the new water is selected. Catch copy snapshots prior progress before persistence and distinguishes first catch, displayed new best, displayed tie, and lower catch.
- Settings pauses safely: it cancels an armed cast, preserves a fight’s pose mapping, isolates preview haptics, and carries its remaining motor settle guard into return. Haptics-off clears preview work. Motion tuning is isolated in Motion Setup.
- Deterministic baseline/frozen 720×1280 desktop captures are in `reports/ui-v4-polish-720/`, including ready safe-top 0/91/180, bite/fight, settings/motion, water safe-top 0/91/180, records, and first/new-best/tie/long-species catches. Full domain plus controller/view interaction checks pass. Export, package audit, Pixel install, and human visual/motion/haptic acceptance remain pending.
- Primary delivery evidence: the signed arm64 v28 APK is `build/android/CastAndCrank-0.4.2-uipolish1-arm64-debug.apk`, 51,795,934 bytes, SHA-256 `F776269C33C747BD34A7973566BCF19EBFAD90D738A1F37D126035B66A01CB6A`. Parser/domain, all sixteen fresh desktop captures, export audit, and Pixel install/cold-start checks passed. DriveFS byte/hash delivery is verified at `H:\My Drive\AI Projects\Haptic Fish\CastAndCrank-0.4.2-uipolish1-arm64-debug.apk`; cloud-sync completion is not claimed. The Pixel was keyguarded with no resumed activity, so foreground touch, motion/haptic feel, ads, and human acceptance remain pending; no phone screenshot was taken.
