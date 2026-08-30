# Completion Audit — Gate 1

| Requirement | Evidence | Status |
| --- | --- | --- |
| Core fishing state loop | `tests/test_runner.gd`; `gate1-domain-final` logs | Verified headlessly |
| Sensor/haptic runtime | Deterministic motion traces and injected haptic scheduler tests; species cadence/warning/terminal contracts | Headless logic verified; requires physical Android validation for real sensors and vibration |
| Eyes-up haptic cadence | `tests/test_runner.gd`; `gate1-haptic-cadence-domain` stdout/stderr | Verified headlessly: bounded phrase queue, normal/high/red reset, disabled suppression, and distinct terminal cues |
| Native AdMob | Pinned adapter + test ID + zero-reserve contract | Requires export/device + UMP validation |
| Concept direction | `concepts/gate1/pine-lake-reel-concept-v01.png` | Pending human approval |
| Portrait greybox captures | `screenshots/selected/gate1-{ready,reeling,caught,synthetic-reserve}.png` | Reviewed, code-native Gate 1 evidence |
| Android export/device | `build/android/CastAndCrank-Gate1-debug.apk`; final process log | Signed debug APK verified (v2, Android Debug certificate); physical device remains unavailable (ADB found none). |
