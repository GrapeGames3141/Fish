# Completion Audit — Gate 1

| Requirement | Evidence | Status |
| --- | --- | --- |
| Core fishing state loop | `tests/test_runner.gd`; `gate1-domain-final` logs | Verified headlessly |
| Sensor/haptic runtime | Deterministic motion traces and injected haptic scheduler tests; species cadence/warning/terminal contracts | Headless logic verified; requires physical Android validation for real sensors and vibration |
| Eyes-up haptic cadence | `tests/test_runner.gd`; `gate1-haptic-cadence-domain` stdout/stderr | Verified headlessly: bounded phrase queue, normal/high/red reset, disabled suppression, and distinct terminal cues |
| Native AdMob | Pinned adapter + test ID + zero-reserve contract; deterministic SDK-completion seam | Headless sequencing verified: no banner before SDK completion and one request after it. Requires rebuilt APK and device UMP/banner validation. |
| Concept direction | `concepts/gate1/pine-lake-reel-concept-v01.png` | Pending human approval |
| Portrait greybox captures | `screenshots/selected/gate1-{ready,reeling,caught,synthetic-reserve}.png` | Reviewed, code-native Gate 1 evidence |
| Android export/device | `build/android/CastAndCrank-Gate1-debug.apk`; final process log; `reports/device_install_log.md` | Signed debug APK verified and installed on a connected Pixel 9 Pro. The app was not launched or playtested, so sensor, haptic, touch, lifecycle, UMP, and banner behavior remain unvalidated. |
