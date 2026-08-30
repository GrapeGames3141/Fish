# Device Install Log — Gate 1

Date: 2026-08-29

- ADB wireless discovered and connected a Google Pixel 9 Pro (`caiman`) running Android 17 / API 37.
- Wireless endpoint: `192.168.1.234:43875`.
- Installed `build/android/CastAndCrank-Gate1-debug.apk` with `adb install -r` at `20:57:06`; exit `0`, `Success`.
- Verified local APK: 38,946,409 bytes; SHA-256 `63C1AB6CCC2301E9C0885E1A90B8D21A6B58DA6721D65628D3674E0AD5F1AB19`.
- Verified the device package path exists for `com.tak.castandcrank`.
- Package facts: versionCode `2`, versionName `0.1.1-gate1`, minSdk `24`, targetSdk `36`, debuggable. The launcher resolves to `com.godot.game.GodotAppLauncher`.

A locked/doze launch of the identical-code export left Android PID `28318` alive after 15 seconds with no current-process fatal matches, but Android immediately paused/stopped it for keyguard. A later foreground trace exposed a packaging regression: `MediationExtras` was excluded even though `AdRequest.gd` requires it. The current installed-v2 log also repeatedly reports `GodotNativeBridge: SecurityException: VIBRATE permission not found. Make sure it is declared in the manifest or enabled in the export preset.` Haptic code/default/invocations are otherwise correct. The first slim v2 APK is superseded by the corrected 0.1.2-gate1 configuration, which retains mediation and declares `permissions/vibrate=true`; it has not yet been exported or installed. Neither trace is a foreground playtest or makes a claim about sensor, haptic, touch, lifecycle, UMP, banner, or visual behavior.

## Final v3 update

- Final 0.1.2-gate1 APK: 38,963,779 bytes; SHA-256 `714F7199526961C551E1075E80D109B960D328D8C187784844D21A6F6CBAE913`.
- Installed on the Pixel 9 Pro with `adb install -r` at `21:10:06`; installation succeeded.
- `dumpsys` confirms versionCode `3`, versionName `0.1.2-gate1`, and `android.permission.VIBRATE` `granted=true`.
- A v3 launch attempt created Android PID `4707` with zero bad-pattern matches, but the phone relocked and NotificationShade had focus; taps reached the lockscreen and vibrator history had zero app matches.

The final v3 install proves package/permission delivery only. It does not validate physical haptics, foreground interaction, UMP, banner layout, touch, lifecycle, or visuals.

## Direct haptic correction pending

The installed v3 save has haptics enabled and Android VIBRATE is granted, but app vibration logs/history remain empty while the Pixel system has `haptic_feedback_enabled=0`, `vibrate_on=1`, and `zen_mode=0`. Version 0.1.3-gate1 replaces the default Android dispatch with the bundled Godot AndroidRuntime vibrator-service / VibrationEffect path. It has not been built or installed, so this is not physical-device haptic validation.

## Final v4 update

- Final 0.1.3-gate1 APK: 38,964,971 bytes; SHA-256 `B3823D65C96D502D9F2C70FCB0405D3AC6195F75864465FB7230AA9F64FBAB78`.
- Installed on the Pixel 9 Pro with `adb install -r` at `21:31:53`; installation succeeded.
- `dumpsys` confirms versionCode `4`, versionName `0.1.3-gate1`, and VIBRATE granted.
- Package inspection retains HapticService entries `2` and MediationExtras entries `10`.

The Pixel remained locked/asleep for this install. No physical haptic, foreground interaction, UMP, banner, touch, lifecycle, or visual validation is claimed.
