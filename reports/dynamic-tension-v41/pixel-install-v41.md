# Pixel v41 installation — 2026-09-10

## Verified installation

- Target: paired Pixel 9 Pro (`caiman`), wireless ADB discovery at
  `192.168.1.234:43803`.
- Updated `com.tak.castandcrank` from version 40 / `0.8.0-waters2` to version
  41 / `0.8.1-tension1` with `adb install -r`; result `Success`.
- APK: `build/android/Hooked-0.8.1-tension1-arm64-debug.apk`, 76,232,563 bytes.
  SHA-256: `6A400B3298C3C83C7300B37AAC7531280D9ADD63B37EE136C08696A65C75F951`.
- Android confirms min/target SDK 24/36 and VIBRATE granted.
- Before and immediately after installation, the existing player save had the
  identical SHA-256
  `f14ac98be1f6a8eb82209b0004f516c1eb11fdd0bc198ae68a477ee8e511a9bd`.
  No uninstall, data clear, save rewrite, or raw motion-trace read occurred.

## Launch and shutdown observations

`am start -W -n com.tak.castandcrank/com.godot.game.GodotAppLauncher`
returned `Status: ok`, `LaunchState: COLD`, total/wait 557/560 ms. Android PID
11376 was initially top-resumed and the keyguard was not showing. The log
identified Godot 4.7.1 stable, commit `a13da4feb`, Android arm64, OpenGL ES
compatibility renderer on Mali-G715; the main loop started at 18:02:50.877.

At 18:02:52 the activity became invisible, paused/stopped, and destroyed its
Godot engine. A shutdown log entry then reported:

> FORTIFY: pthread_mutex_lock called on a destroyed mutex

Android exit-info reports PID 11376 ended at 18:02:53.109 for
`USER REQUESTED / REMOVE TASK`, status 0. These are separate observations:
the installation succeeded, but sustained runtime stability was not verified.
The available app-scoped raw log is retained at
[pixel-v41-pid11376-raw.log](validation/pixel-v41-pid11376-raw.log).
Earlier startup entries were inspected before log-buffer rotation; the retained
log is a partial buffer snapshot, not the complete launch transcript.

The native error's cause is unresolved. No symbolized stack or tombstone was
available in this install check, so it is not attributed to the tension feature.
No gameplay/engine fix, reinstall, or further app launch was attempted after
the task removal. Physical motion, haptic feel, and dynamic-zone fairness
remain user playtest gates. No phone screenshots or Drive copy were made.

## Process scope

No local Godot process was launched. The only Android game PID started by this
check was 11376, with observed rendering thread 11421; the process was absent
at the final check. The user's existing ADB pairing was reused.
