# Device Install Log — Gate 1

Date: 2026-08-29

- ADB wireless discovered and connected a Google Pixel 9 Pro (`caiman`) running Android 17 / API 37.
- Wireless endpoint: `192.168.1.234:43875`.
- Installed `build/android/CastAndCrank-Gate1-debug.apk` with `adb install -r` at `20:57:06`; exit `0`, `Success`.
- Verified local APK: 38,946,409 bytes; SHA-256 `63C1AB6CCC2301E9C0885E1A90B8D21A6B58DA6721D65628D3674E0AD5F1AB19`.
- Verified the device package path exists for `com.tak.castandcrank`.
- Package facts: versionCode `2`, versionName `0.1.1-gate1`, minSdk `24`, targetSdk `36`, debuggable. The launcher resolves to `com.godot.game.GodotAppLauncher`.

A locked/doze launch of the identical-code export left Android PID `28318` alive after 15 seconds with no current-process fatal matches, but Android immediately paused/stopped it for keyguard. A later foreground trace exposed a packaging regression: `MediationExtras` was excluded even though `AdRequest.gd` requires it. The current installed-v2 log also repeatedly reports `GodotNativeBridge: SecurityException: VIBRATE permission not found. Make sure it is declared in the manifest or enabled in the export preset.` Haptic code/default/invocations are otherwise correct. The first slim v2 APK is superseded by the corrected 0.1.2-gate1 configuration, which retains mediation and declares `permissions/vibrate=true`; it has not yet been exported or installed. Neither trace is a foreground playtest or makes a claim about sensor, haptic, touch, lifecycle, UMP, banner, or visual behavior.
