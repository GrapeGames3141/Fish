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

## V6 physical fight timing gate (superseded by unexported v7 tuning)

- On the physical v6 fight, the hook was recorded at `22:37:35.501`; the first lower marker followed at `0.40 s`.
- Pull markers arrived at `2.03`, `3.83`, `7.62`, `10.03`, `22.58`, `32.05`, `50.62`, `57.53`, and `66.42 s`. Lower recognition itself was prompt (`0.2–1.9 s` in the observed attempts), and correct lowering kept tension mostly low.
- The landed Bluegill at `66.42 s` missed Gate 1’s 10–20 second target because v6 required return within 8° of the original hook pose; later valid physical returns took `6.5–18.3 s` to meet that overly strict condition. A second fight was abandoned.

This is useful device evidence for v6 gesture recognition, not acceptance of its timing. Version `0.1.6-gate1` replaced the strict return with tolerant, continuous raised/lowered rod load; its subsequent physical result is recorded below.

## V7 installation and foreground launch

- Signed `0.1.6-gate1` / versionCode `7` APK: 38,974,951 bytes; SHA-256 `E0DBDF20E0F1318A1DF556659E5187F1D8E4C6485B52E3B477AD606BF0B56B32`.
- Package audit confirms `com.tak.castandcrank`, minSdk `24`, targetSdk `36`, arm64-only delivery, VIBRATE present, and v2 signing with the existing Android Debug certificate.
- Wireless pairing succeeded with the Pixel 9 Pro at `192.168.1.234`; `adb install -r` reported `Success` for versionCode `7` / versionName `0.1.6-gate1`.
- `dumpsys` confirms `android.permission.VIBRATE` is `granted=true`. The foreground application was PID `17207`, `com.tak.castandcrank/com.godot.game.GodotAppLauncher`; inspected launch output contained no `FATAL EXCEPTION` or `SCRIPT ERROR`.
- The existing calibration/save persisted across the replacement install.

This proves v7 package installation, permission delivery, foreground process launch, and persistence survival. The subsequent physical fight result is recorded below; UMP/banner geometry, visual comfort, lifecycle, and performance remain unvalidated.

## V7 physical cast/fight timing gate (superseded by the installed v8 response tuning)

- Real v7 sensor markers recorded a cast at `23:17:57.588` with quality `1.00` / `40 m`, then a hook at `23:18:00.554`. Lower/pull markers continued through `1.75 s` of the fight, proving the physical motion path operated after the hook.
- The persisted save catch count changed from `12` to `13`. Landing markers from `23:18:28.212` through `.723` imply roughly `28.17 s` hook-to-landing, outside the 10–20 second Gate 1 target.
- Pixel `vibrator_manager` recorded v7 `usage: MEDIA` pulses: normal fish pulses were finished or `cancelled_superseded` at cadence boundaries, and hook/terminal pulses were finished. They were not `ignored_for_settings`.

V7 therefore works physically for cast, hook, fight, landing, persistence, and haptic routing, but natural partial cock-backs made the fight too long. Version `0.1.7-gate1` applies a square-root partial-load response curve and adds terminal `MOTION_FIGHT` device markers; it is installed, but its terminal/timing and sustained-fight physical claims remain pending.

## V8 install and initial physical trace

- Signed `0.1.7-gate1` / versionCode `8` APK: 38,975,163 bytes; SHA-256 `B1AFD6DBDE8B0D6EEF04E0B47615A50FA70FC0E6300D52FAFFE815167484EB17`.
- Pixel installation with `adb install -r` reported `Success`; VIBRATE is `granted=true`. The app first ran as PID `25900`, then after restart as PID `26711`.
- A real v8 trace recorded `MOTION_CAST` at `23:41:08.719`, quality `1.00` / `40 m`; hook at `23:41:11.283`; and a lower marker at `23:41:12.149`, tension `0.34`, elapsed `0.87 s`.
- No caught/escaped terminal `MOTION_FIGHT` marker was captured before further testing was deferred. Catch count reaching `14` across the restart is not timing evidence.

This proves v8 export/install, permission delivery, and initial cast/hook/lower operation only. It does not establish v8 physical landing timing, terminal marker behavior, sustained fight haptics, or user acceptance.

## V9 UI build install and launch

- Optimized UI build `0.2.0-ui1` / versionCode `9`: 46,072,704 bytes; SHA-256 `9EA3732C31C97BC09EAA10DA89A4FE481CAFAF9A230FCD03EA925B623AC15063`.
- `adb install -r` succeeded on the Pixel 9 Pro (`caiman`, `192.168.1.234:43875`). `dumpsys` confirms versionCode `9` and `android.permission.VIBRATE` `granted=true`.
- The Godot activity displayed/launched and inspected output had no fatal exception or script-error marker.
- Secure lock / NotificationShade blocked an actual device visual capture. Desktop 720×1280 captures remain the visual evidence. Real v9 motion, haptic, and timing validation remains open for the next physical test session.

## V10 rod-line correction install and launch

- Signed `0.2.1-ui2` / versionCode `10` APK: 46,073,176 bytes; SHA-256 `12E40F6FD0B6467A767005F794D1CF1D1018FA49BE844E42CD397B2103EE3FD1`.
- After an in-sandbox `adb connect` failure (`10013`), restarting ADB outside the sandbox reconnected the Pixel 9 Pro (`caiman`, `192.168.1.234:43875`). `adb install -r` reported `Success`; `dumpsys` confirms versionCode `10` and VIBRATE `granted=true`.
- Launch intent was sent. The inspected 400-line log window had no fatal exception, script error, or parse marker.
- The phone remained locked, so this is not a physical visual, motion, haptic, or timing validation. No phone screenshot was taken or retained for this v10 pass; prior temporary lock-screen captures were deleted locally and from `/sdcard`. C: delivery copies of the APK and ready/reeling evidence match source size and SHA-256 where applicable.

## V24 feedback guard

`0.3.11-feedbackguard2` was exported, audited, and installed on the paired Pixel 9 Pro. The arm64 APK was 44,227,357 bytes (SHA-256 `E06EEA1BA736ADF7DABFD93C48630408551E8FBF6684E70B919F2ECA904068AB`), versionCode 24, min SDK 24, target SDK 36, VIBRATE-present, and v2-signed with the existing debug certificate.

The first dwell wrapper was invalid because PowerShell reserves `$PID`. The corrected untouched dwell on app PID `25744` recorded a false cast and self-hook with derived telemetry `projection=95.62`, `axis=.69`, `polarity=.51`, `gyro=31.11`, `reversal=.115`, and `cock=12.46`; no fatal marker was found. This is regression evidence only, not physical cast/hook acceptance.

## V25 profile guard

`0.3.12-profileguard3` was exported, audited, and installed on the paired Pixel. The arm64 APK was 44,228,117 bytes (SHA-256 `1487E48DEB317D27054C5F5156D22CB6B9C044B9261212F5B2F1E5ABE4CAE784`), versionCode 25, min SDK 24, target SDK 36, VIBRATE-present, 812 entries, zero forbidden entries, and v2-signed with the existing debug certificate.

Two corrected untouched 15-second dwells, app PIDs `30931` and `31349`, recorded zero cast, hook, cancellation, failure, and fatal markers. These text-only dwells do not establish physical cast/hook feel, comfort, or gameplay acceptance. No phone screenshot was taken.

## V26 UI v2 final optimized build

`0.4.0-ui3` / versionCode `26` was installed on the paired Pixel 9 Pro (`192.168.1.234:39865`) with `adb install -r` `Success`. The audited arm64-only APK is `49,959,406` bytes, SHA-256 `B81DA18B6A2DE2E15547C69009A3E0E51866455F77145524825551521B15694A`, minSdk `24`, targetSdk `36`, VIBRATE-present, and v2-signed by the existing debug certificate `c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc`. `dumpsys` confirms versionName `0.4.0-ui3` and VIBRATE `granted=true`.

Cold launch completed in `504ms`; Android PID `8535` remained alive and the scoped log scan has no FATAL EXCEPTION, SIGSEGV, Fatal signal, SCRIPT ERROR, Parse Error, or CRASH marker. No phone screenshot was taken. This validates package/install/startup only: physical cast, hook, fight timing, haptic feel, and user acceptance remain pending.

## V27 navigation install and startup

- The supplied pairing endpoint `192.168.1.234:39637` had already closed and two `adb pair` attempts returned protocol faults. Restarting only the local ADB daemon then rediscovered `_adb-tls-connect._tcp` service `adb-45291FDAP0080L-NMUskl` at `192.168.1.234:43705`; `adb devices -l` listed the previously paired Pixel 9 Pro as product/model/device `caiman` / `Pixel_9_Pro` / `caiman`.
- Exact source package `build/android/CastAndCrank-Gate1-debug.apk`: `51,793,264` bytes, SHA-256 `094A4B70A84B28F1083D1EB5256F31B546EC7DE1DA770C90125C8BAB5B3CE17F`, package `com.tak.castandcrank`, versionCode `27`, versionName `0.4.1-navfix1`, min/target SDK `24`/`36`, arm64-v8a only, VIBRATE-present, and v2-signed with the existing debug certificate.
- `adb install -r` returned `Success`; dumpsys confirms versionCode `27`, versionName `0.4.1-navfix1`, and `android.permission.VIBRATE` `granted=true`.
- Text-only cold launch of `com.tak.castandcrank/com.godot.game.GodotAppLauncher` returned `Status: ok`, `LaunchState: COLD`, activity `com.tak.castandcrank/com.godot.game.GodotApp`, `TotalTime: 544ms`, and `WaitTime: 548ms`. Android PID `1133` remained alive and the launcher was top-resumed. Its 283-line PID-scoped log had zero `FATAL EXCEPTION`, `SIGSEGV`, `Fatal signal`, `SCRIPT ERROR`, `Parse Error`, or `CRASH` markers.

This validates pairing continuity, package installation, permission delivery, and basic startup only. It does not validate physical Settings/Records/Waters touch, safe-inset behavior, cast/hook/fight/haptic feel, ads, device visual quality, or human aesthetic approval. No phone screenshot was taken.
