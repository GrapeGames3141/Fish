# Godot Process Log

Gate 1 invocations and their PIDs/results are appended after validation. The engine command is `E:\CodexCache\godot-android-4.7.1\godot\Godot_v4.7.1-stable_win64_console.exe`. This Godot build may not support a user-data override; commands use project-local retained logs and no source-mutating formatter.

| Gate | Console PID | Exit | Result |
| --- | ---: | ---: | --- |
| Import attempt | 38808 | 1 | Wrapper split the space-containing project path; no project load. |
| Import retry | 25212 | 0 | Initial scan completed; parser issue found in `main.gd`. |
| Parser/import final | 34404 | 0 | Main parser fix verified; iOS auto-download behavior was patched out for Android-only validation. |
| Domain attempt | 26340 | 1 | Missing local mock assets plus two test assertions; fixed with local required assets and targeted test changes. |
| Domain retry | 11728 | 0 | Assertions passed, but copied stale `.import` metadata made mock texture diagnostics. |
| Asset reimport | 28952 | 0 | Removed disposable copied metadata and reimported required mock assets. |
| Domain final | 36664 | 0 | `PASS: Cast & Crank Gate 1 domain tests`. Godot emitted existing ObjectDB/resource cleanup diagnostics; no task Godot or WerFault remained. |

Retained stdout, stderr, and engine logs are in `reports/runtime/`. No physical device, sensor, haptic, UMP, live banner, or Android export validation was performed. No task-created process or crash dialog remained after the final process inspection.

## Final Gate 1 validation evidence

| Gate | Exact process evidence | Result |
| --- | --- | --- |
| Domain | Console `36700`; children `42844` Godot worker and `5576` conhost | Exit `0`, `PASS: Cast & Crank Gate 1 domain tests`; remaining task processes `0`. Stderr retains Godot's 7 ObjectDB / 3 resource teardown diagnostics. |
| Import | Console `25780`; children `40744`, `38900` | Exit `0`, no stderr, remaining task processes `0`. |
| ADB | Non-destructive device check | No attached devices. Task-started ADB server was stopped. No device validation claim. |
| Android export | Task-owned export PIDs were cleaned | No APK produced. Initial export was blocked by conflicting `ANDROID_HOME=E:` and `ANDROID_SDK_ROOT=C:`; corrected E:-SDK attempt produced no success artifact before owner exit. |
