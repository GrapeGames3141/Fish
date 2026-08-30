# Gate 1 — foundation, playable greybox, and concept direction

## Acceptance

- A portrait 720×1280 Godot 4.7.1 project runs a complete Pine Lake Bluegill loop: arm/cast, wait for bite, hook, reel, catch or escape, then cast again.
- Motion uses accelerometer/gravity/gyroscope when present and has deterministic simulated traces plus touch/keyboard fallbacks. First run presents two safe practice casts before play.
- A two-pulse bite vibration, 1.5-second hook window, clockwise lift/resume reel control, forgiving tension, and 1.25-second red escape are observable.
- Local versioned save retains settings, calibration, catches, and personal best. Settings expose sensitivity, haptics, audio, and reduced motion.
- The AdMob adapter pins Poing 5.0.0 and Google’s test banner ID, documents UMP/general-audience PG configuration, and preserves native-bottom zero-reserve ownership. Desktop fallback is safe.
- Automated domain tests and deterministic 720×1280 captures exist. Device/motion/haptic/native-ad claims remain pending physical-device evidence.

## Gate decision

Human review is required now for the temporary concept direction and motion/greybox feel before production art families are generated or promoted.
