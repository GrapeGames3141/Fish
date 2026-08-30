# Completion Audit — Gate 1

| Requirement | Evidence | Status |
| --- | --- | --- |
| Core fishing state loop | `tests/test_runner.gd`; `gate1-domain-final` logs | Verified headlessly |
| Sensor/haptic runtime | Deterministic motion traces and injected haptic scheduler tests; live Pixel log diagnosis; final v4 package/install evidence | Final v4 package retains two HapticService entries and VIBRATE is granted after install. Pixel remained locked/asleep, so physical vibration remains unvalidated. |
| Eyes-up haptic cadence | `tests/test_runner.gd`; `gate1-haptic-cadence-domain` stdout/stderr | Verified headlessly: bounded phrase queue, normal/high/red reset, disabled suppression, and distinct terminal cues |
| Native AdMob | Pinned adapter + test ID + zero-reserve contract; deterministic SDK-completion seam; final v4 package audit | Headless sequencing verified: no banner before SDK completion and one request after it. Final package contains 10 `MediationExtras` entries; foreground UMP/banner validation remains pending. |
| Concept direction | `concepts/gate1/pine-lake-reel-concept-v01.png` | Pending human approval |
| Portrait greybox captures | `screenshots/selected/gate1-{ready,reeling,caught,synthetic-reserve}.png` | Reviewed, code-native Gate 1 evidence |
| Android export/device | `build/android/CastAndCrank-Gate1-debug.apk`; final process log; `reports/device_install_log.md` | Final 0.1.3-gate1 signed arm64 APK is 38,964,971 bytes (SHA-256 `B3823D65…64FBAB78`), versionCode 4, installed on the connected Pixel 9 Pro with VIBRATE granted. It retains two HapticService and 10 MediationExtras entries while audited reports prefixes count 0. The locked/asleep install is not foreground validation; sensor, haptic, touch, lifecycle, UMP, banner, and visual behavior remain pending. |
