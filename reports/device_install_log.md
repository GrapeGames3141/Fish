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

## Unlocked v4 haptic evidence and v5 correction pending

An unlocked v4 cast/bite/hook/fight loop created nine app-attributed vibrator entries with the expected pulse durations and amplitudes. Every entry was `ignored_for_settings` with `usage: TOUCH`. Pixel settings were `haptic_feedback_enabled=0`, `vibrate_on=1`, and `zen_mode=0`; this proves the direct v4 dispatch occurred but was classified as touch feedback. Version 0.1.4-gate1 uses explicit non-touch attributes: API 33+ media VibrationAttributes and API 24–32 game/sonification AudioAttributes. It has not been built or device-tested.

## Direct haptic correction pending

The installed v3 save has haptics enabled and Android VIBRATE is granted, but app vibration logs/history remain empty while the Pixel system has `haptic_feedback_enabled=0`, `vibrate_on=1`, and `zen_mode=0`. Version 0.1.3-gate1 replaces the default Android dispatch with the bundled Godot AndroidRuntime vibrator-service / VibrationEffect path. It has not been built or installed, so this is not physical-device haptic validation.

## Final v4 update

- Final 0.1.3-gate1 APK: 38,964,971 bytes; SHA-256 `B3823D65C96D502D9F2C70FCB0405D3AC6195F75864465FB7230AA9F64FBAB78`.
- Installed on the Pixel 9 Pro with `adb install -r` at `21:31:53`; installation succeeded.
- `dumpsys` confirms versionCode `4`, versionName `0.1.3-gate1`, and VIBRATE granted.
- Package inspection retains HapticService entries `2` and MediationExtras entries `10`.

The Pixel remained locked/asleep for this install. No physical haptic, foreground interaction, UMP, banner, touch, lifecycle, or visual validation is claimed.

## Final v5 motion and haptic validation

- Final `0.1.4-gate1` APK: 38,973,335 bytes; SHA-256 `CBCC74703FB5172454A276616AF4DB62720CEAB1FC0415D9C40A8BED2D749061`.
- The signed arm64-only package is `com.tak.castandcrank`, versionCode `5`, minSdk `24`, targetSdk `36`, v2-signed with Android Debug certificate SHA-256 `c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc`; VIBRATE is present.
- `adb install -r` succeeded on Pixel 9 Pro `192.168.1.234:43875`. `dumpsys` confirms versionCode `5`, versionName `0.1.4-gate1`, min/target SDK values, and VIBRATE granted. Android PID `28410` stayed alive with no inspected current-process `FATAL EXCEPTION`, crash, or script-error marker.
- The private v2 save is calibrated and preserved catches `8` / best `26.5`; its derived profile records back peak `2.14565`, forward peak `3.68140`, gyro `4.23146`, transition `0.375`, axis `[-0.8526, 0.27369, -0.44516]`, and noise `0.64370`.
- Actual sensor markers show hook-to-reeling at `22:14:39.950`, cast quality `0.79` / `33.4 m` at `22:14:57.906`, cast quality `1.00` / `40 m` at `22:15:06.038`, and hook-to-reeling at `22:15:09.171`.
- Pixel vibrator-manager evidence attributes the app to `usage: MEDIA`, with finished (not `ignored_for_settings`) bite pulses `70 ms` / `0.85` and `105 ms` / `0.95` at `22:15:00`, hook `55 ms` / `0.60` at `22:15:09`, and later fight/cadence cues including `38 ms` / `0.30` and `62 ms` / `0.58`. Adjacent cadence entries may be superseded as expected.

This validates installed-package delivery, real sensor calibration/cast/hook markers, and Pixel haptic playback routing. The user has not explicitly confirmed subjective haptic strength or feel. The final observed window was the launcher while the app PID remained alive; foreground visuals, UMP/AdMob banner geometry, touch comfort, lifecycle, and performance remain unvalidated.
