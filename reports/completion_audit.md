# Completion Audit — Gate 1

| Requirement | Evidence | Status |
| --- | --- | --- |
| Core fishing state loop | `tests/test_runner.gd`; `gate1-domain-final` logs | Verified headlessly |
| Sensor/haptic runtime | Deterministic motion traces and injected haptic scheduler tests; live Pixel log diagnosis; final v3 package/install evidence | Final v3 package declares `VIBRATE` and `dumpsys` reports it granted. Physical vibration remains unvalidated because the v3 device launch relocked before app interaction and vibrator history has zero app matches. |
| Eyes-up haptic cadence | `tests/test_runner.gd`; `gate1-haptic-cadence-domain` stdout/stderr | Verified headlessly: bounded phrase queue, normal/high/red reset, disabled suppression, and distinct terminal cues |
| Native AdMob | Pinned adapter + test ID + zero-reserve contract; deterministic SDK-completion seam; final v3 package audit | Headless sequencing verified: no banner before SDK completion and one request after it. Final package contains 10 `MediationExtras` entries; foreground UMP/banner validation remains pending. |
| Concept direction | `concepts/gate1/pine-lake-reel-concept-v01.png` | Pending human approval |
| Portrait greybox captures | `screenshots/selected/gate1-{ready,reeling,caught,synthetic-reserve}.png` | Reviewed, code-native Gate 1 evidence |
| Android export/device | `build/android/CastAndCrank-Gate1-debug.apk`; final process log; `reports/device_install_log.md` | Final 0.1.2-gate1 signed arm64 APK is 38,963,779 bytes (SHA-256 `714F7199…CBAE913`), versionCode 3, installed on the connected Pixel 9 Pro with VIBRATE granted. It retains runtime mediation and excludes audited reports prefixes. The relocked launch trace is not foreground validation; sensor, haptic, touch, lifecycle, UMP, banner, and visual behavior remain pending. |
