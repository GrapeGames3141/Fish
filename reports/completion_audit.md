# Completion Audit — Gate 1

| Requirement | Evidence | Status |
| --- | --- | --- |
| Core fishing state loop | `tests/test_runner.gd`; `gate1-domain-final` logs | Verified headlessly |
| Sensor/haptic runtime | Deterministic motion traces and injected haptic scheduler tests; species cadence/warning/terminal contracts; live Pixel log diagnosis | Headless logic verified. Installed v2 log reports missing Android `VIBRATE` permission; corrected v3 config declares it, but replacement export/install and physical vibration validation remain pending. |
| Eyes-up haptic cadence | `tests/test_runner.gd`; `gate1-haptic-cadence-domain` stdout/stderr | Verified headlessly: bounded phrase queue, normal/high/red reset, disabled suppression, and distinct terminal cues |
| Native AdMob | Pinned adapter + test ID + zero-reserve contract; deterministic SDK-completion seam | Headless sequencing verified: no banner before SDK completion and one request after it. The first slim v2 foreground trace exposed an excluded runtime mediation dependency, so that APK is superseded; corrected export and foreground UMP/banner validation remain pending. |
| Concept direction | `concepts/gate1/pine-lake-reel-concept-v01.png` | Pending human approval |
| Portrait greybox captures | `screenshots/selected/gate1-{ready,reeling,caught,synthetic-reserve}.png` | Reviewed, code-native Gate 1 evidence |
| Android export/device | `build/android/CastAndCrank-Gate1-debug.apk`; final process log; `reports/device_install_log.md` | First 0.1.1-gate1 slim signed arm64 APK measured 38,946,409 bytes (57.77% below the 0.1.0 baseline) and was installed on a connected Pixel 9 Pro, but a foreground trace found its excluded `MediationExtras` runtime dependency and live logs found missing `VIBRATE`. It is superseded by corrected 0.1.2-gate1 configuration; replacement export/install and sensor, haptic, touch, lifecycle, UMP, banner, and foreground visual validation remain pending. |
