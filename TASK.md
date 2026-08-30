# Gate 1 — foundation, playable greybox, and concept direction

## Acceptance

- A portrait 720×1280 Godot 4.7.1 project runs a complete Pine Lake Bluegill loop: arm/cast, wait for bite, hook, physically lower then pull the rod through the fight, catch or escape, then cast again.
- Motion uses one gravity-compensated accelerometer/gyroscope sample per update, learned axis matching, and deterministic simulated traces. Android has no cast or hook touch fallback: first run automatically settles then learns two real cock-back/snap casts; keyboard simulation is desktop-only. A smaller learned back gesture hooks only during the hook window.
- A two-pulse bite vibration, one hook cue, data-driven fish fight cadence with quiet gaps, escalating high/red tension warnings, distinct caught/escaped cues, 1.5-second hook window, and a continuous physical rod-load fight are observable. Raising/cocking the rod advances the fish but drives tension; tilting forward/down eases tension with little progress. A controlled Bluegill pull/ease rhythm targets 10–20 seconds; sustained hard pull resolves quickly by landing or red-line escape. Haptics-off clears queued feedback. Android defaults to a cached direct `AndroidRuntime` vibrator emitter with explicit non-touch attributes: API 33+ uses media usage, API 24–32 uses game/sonification audio attributes, then falls back safely when unavailable.
- Local versioned save retains settings, a validated motion profile, catches, and personal best; v1 saves preserve progress but recalibrate. Settings expose sensitivity, haptics, audio, reduced motion, and an explicit recalibration row.
- The AdMob adapter pins Poing 5.0.0 and Google’s test banner ID, documents UMP/general-audience PG configuration, and preserves native-bottom zero-reserve ownership. After consent, the SDK completion callback must run before one native banner request; desktop fallback is safe.
- The signed debug package is arm64-only with compressed native libraries, Android `VIBRATE` permission, and excludes non-runtime evidence/editor/demo material while retaining runtime AdMob dependencies. Its export size and signing evidence must be recorded before any replacement install.
- Automated domain tests and deterministic 720×1280 captures exist. Device/motion/haptic/native-ad claims remain pending physical-device evidence.

## UI production checkpoint

- The user explicitly authorizes a first-pass, versioned ImageGen UI family: icon, splash, gameplay, catch, and records presentation. Keep dynamic copy as native UI text.
- Gameplay remains motion-only: no cast, hook, or fight touch fallback. Build layered animated pond, rod, line, and bobber states, including bite submerge, fight ripples/splash, and rod bend; provide a glanceable styled motion hint.
- Records must show count and best for every planned fish, not only the active Bluegill. Produce fresh 720×1280 captures and a fresh build after implementation.
- Record image prompts/provenance and keep the delivered first visual pass pending human aesthetic approval before any broader art promotion.

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
