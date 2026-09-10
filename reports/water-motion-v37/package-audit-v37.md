# Water motion v37 package audit

[`Hooked-0.7.3-water1-arm64-debug.apk`](../../build/android/Hooked-0.7.3-water1-arm64-debug.apk)
was exported by [`primary-v37-export-final.json`](validation/primary-v37-export-final.json): root PID `124252`, exit 0, empty stderr marker, no remaining task PIDs/windows.

| Field | Verified value |
| --- | --- |
| Size | 65,444,082 bytes (`+34,339` vs v36) |
| SHA-256 | `D72010D55EF69463E9A98C79419E897CB25623563079202ED10574E3C32A75BA` |
| Package | `com.tak.castandcrank` |
| Version | code `37`, name `0.7.3-water1` |
| SDK / ABI | min `24`, target `36`, arm64-v8a only |
| Signing | v2, existing debug certificate `c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc` |
| Permission | `android.permission.VIBRATE` present |
| Archive | 841 entries; both native libraries compressed |

The audit found all four imported water-mask `.ctex/.import` resources plus
`water_surface.gdc` and `water_surface.gdshader` in the package. It found no
`reports`, `tests`, `docs`, `tools`, `concepts`, `screenshots`, GIF, or MP4
content. `libgodot` is 76,177,376 bytes (27,833,653 compressed) and
`libc++_shared` is 1,374,336 bytes (501,772 compressed).

The first export attempt is retained as a superseded C:/E: Android SDK
environment mismatch. The final retry used process-scoped E: SDK/JDK/Gradle
paths and completed cleanly. No install, Drive copy, remote push, or device
acceptance is claimed.
