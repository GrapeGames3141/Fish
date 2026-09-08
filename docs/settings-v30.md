# Settings footer repair — v30

`0.5.1-settingsfix1` removes the duplicate runtime title/footer plaques that overlapped the existing opaque modal art. Settings and Motion Setup now draw the modal atlas once; native text and hit targets map to the baked header/footer through the same safe-area-aware layout function.

| Check | Evidence | Status |
| --- | --- | --- |
| Safe top 0/91/180 geometry, non-overlapping rows, single footer target, touch dedup, immediate inset-change hit, and font-fit bounds | `reports/settings-v30/validation/primary-v30-domain-final2.json` | Automated pass |
| Parser/import | `reports/settings-v30/validation/primary-v30-parser-final.json` | Automated pass |
| Settings safe top 0/91/180 and Motion Setup 180 | [gallery](../reports/settings-v30/gallery/README.md) | Desktop capture reviewed by agent |
| Android debug export | `reports/settings-v30/validation/v30-export-final.json` | Automated pass |
| Package audit | `CastAndCrank-0.5.1-settingsfix1-arm64-debug.apk` | 54,273,962 bytes; SHA-256 `6CD63A70EF5FDC4871D5C653DEE76F9DF2AD478856F15CB19082C3EE17A88F1C`; package `com.tak.castandcrank`; code/name `30` / `0.5.1-settingsfix1`; min/target `24` / `36`; arm64 only; VIBRATE present; 818 ZIP entries; v2 debug signature `c26373b2320fa530be93f5b6d255a4c8e10e6aa4476e430dedb6106a4de865dc` |
| Drive handoff | `H:\My Drive\AI Projects\Haptic Fish\CastAndCrank-0.5.1-settingsfix1-arm64-debug.apk` | Size/hash verified after copy; cloud-sync completion not claimed |
| Physical device review | Not run | Pending |

The final domain check exits successfully with only the established Godot 12 ObjectDB / 5 resource teardown diagnostics. The measured 22px Motion Setup title and fitted `BACK TO MOTION SETUP` label both stay inside their baked plaque clear spans. No new artwork was generated or changed.

Scoped source SHA-256: `src/ui/main.gd` `607592000E0DCDE8750CD2C75DB1A40F321AE0BC72BBDDCCECF25E2E79E4EB99`; `tests/test_runner.gd` `0FE99F48CE3787BE762FF2D63F715D38A44F04600405A741A7301EAE4F98CB48`; `export_presets.cfg` `F9DB4AFF2828E4D626E61572DAAFE3A9EC3F3A82F678AC3609784F9CC36DF214`.
