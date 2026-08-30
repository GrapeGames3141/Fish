# Device Install Log — Gate 1

Date: 2026-08-29

- ADB wireless discovered and connected a Google Pixel 9 Pro (`caiman`) running Android 17 / API 37.
- Installed `build/android/CastAndCrank-Gate1-debug.apk` with `adb install -r`; exit `0`, `Success`.
- Verified local APK: 92,226,005 bytes; SHA-256 `99E9A948291D5C20866927A9C25CF94E278B39C5CFCB289ED4DABAA8DFF44AEC`.
- Verified the device package path exists for `com.tak.castandcrank`.
- Package facts: versionCode `1`, versionName `0.1.0-gate1`, minSdk `24`, targetSdk `36`, firstInstallTime / lastUpdateTime `2026-08-29 20:14:39`, debuggable. The launcher resolves to `com.godot.game.GodotAppLauncher`.

The app was installed but not launched or playtested. This record makes no claim about sensor, haptic, touch, lifecycle, UMP, or banner behavior.
