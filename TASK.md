# Gate 1 — foundation, playable greybox, and concept direction

## Acceptance

- A portrait 720×1280 Godot 4.7.1 project runs a complete Pine Lake Bluegill loop: arm/cast, wait for bite, hook, physically lower then pull the rod through the fight, catch or escape, then cast again.
- Motion uses one gravity-compensated accelerometer/gyroscope sample per update, learned axis matching, and deterministic simulated traces. Android has no cast or hook touch fallback: first run automatically settles then learns two real cock-back/snap casts; keyboard simulation is desktop-only. A smaller learned back gesture hooks only during the hook window.
- A two-pulse bite vibration, one hook cue, data-driven fish fight cadence with quiet gaps, escalating high/red tension warnings, distinct caught/escaped cues, 1.5-second hook window, alternating lower/pull rod fight, active lower-rod tension relief, forgiving tension, and 1.25-second red escape are observable. A controlled Bluegill fight targets 10–20 seconds. Haptics-off clears queued feedback. Android defaults to a cached direct `AndroidRuntime` vibrator emitter with explicit non-touch attributes: API 33+ uses media usage, API 24–32 uses game/sonification audio attributes, then falls back safely when unavailable.
- Local versioned save retains settings, a validated motion profile, catches, and personal best; v1 saves preserve progress but recalibrate. Settings expose sensitivity, haptics, audio, reduced motion, and an explicit recalibration row.
- The AdMob adapter pins Poing 5.0.0 and Google’s test banner ID, documents UMP/general-audience PG configuration, and preserves native-bottom zero-reserve ownership. After consent, the SDK completion callback must run before one native banner request; desktop fallback is safe.
- The signed debug package is arm64-only with compressed native libraries, Android `VIBRATE` permission, and excludes non-runtime evidence/editor/demo material while retaining runtime AdMob dependencies. Its export size and signing evidence must be recorded before any replacement install.
- Automated domain tests and deterministic 720×1280 captures exist. Device/motion/haptic/native-ad claims remain pending physical-device evidence.

## Gate decision

Human review is required now for the temporary concept direction and motion/greybox feel before production art families are generated or promoted.
