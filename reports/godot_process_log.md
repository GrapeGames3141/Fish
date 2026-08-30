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
| Android export (preliminary) | Console `1124`; worker `32360` | Exit `0`; emitted an unsigned artifact that `apksigner` rejected. Superseded by the final signed export below. |
| Eyes-up haptic cadence domain | Console `33628`; children `19020`, `39712` | Exit `0`, `PASS: Cast & Crank Gate 1 domain tests`; remaining task processes `0`. The suite covers universal high/red cadence and initial hook delay. Stderr has the known 7 ObjectDB / 3 resource teardown diagnostics only. Earlier successful correction run was console `40964`, children `41644`, `35404`; first launch `16852` exited `1` before project load because its wrapper argument construction was invalid, not because of project source. |
| Final eyes-up domain | Console `21740`; children `36012` Godot worker, `37008` conhost | Exit `0`, `PASS: Cast & Crank Gate 1 domain tests`; remaining task processes `0`. Stderr has the known 7 ObjectDB / 3 resource teardown diagnostics only. |
| Final signed Android export | Console `41924`; worker `32828` | Exit `0`; Gradle signing enabled and task daemon stopped. `build/android/CastAndCrank-Gate1-debug.apk` is 92,226,005 bytes, SHA-256 `99E9A948291D5C20866927A9C25CF94E278B39C5CFCB289ED4DABAA8DFF44AEC`. `apksigner` exit `0`, v2 signed, Android Debug certificate SHA-256 `c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc`. `aapt` confirms `com.tak.castandcrank`, version `1` / `0.1.0-gate1`, min SDK `24`, target SDK `36`. No task Godot, Java, ADB, or WerFault process remained. |
