# Rustic UI v32 gallery

## Current v33 tension-meter review set

These are the current approved desktop-review captures for `0.6.2-tension1`.
They supersede older fight screenshots as current fight evidence; retained v32
menus below remain relevant for their respective screens. They are primary
visual-review evidence, not user aesthetic approval or v33 delivery evidence.

| Meter state | Capture | Receipt |
| --- | --- | --- |
| Pine low 32% | [primary-v33-low32.png](primary-v33-low32.png) | [receipt](../validation/primary-v33-low32.json) |
| Pine high 88% | [terra-v33-tension-high.png](terra-v33-tension-high.png) | [receipt](../validation/terra-v33-tension-high.json) |
| Pine danger 95% | [terra-v33-tension-danger95.png](terra-v33-tension-danger95.png) | [receipt](../validation/terra-v33-danger95.json) |
| Cedar high, safe top 180 | [terra-v33-tension-cedar180.png](terra-v33-tension-cedar180.png) | [receipt](../validation/terra-v33-cedar180.json) |
| Reduced high, 960×2142 | [primary-v33-reduced-tall.png](primary-v33-reduced-tall.png) | [receipt](../validation/primary-v33-reduced-tall.json) |

Independent suite [primary-v33-domain.json](../validation/primary-v33-domain.json)
root `114328` exited `0` with no marker, windows, or remaining task PID. The
low and reduced-tall review wrappers (roots `120052` and `107496`) had the same
clean process result. Known domain teardown diagnostics remain documented.

## Reviewed source art

- [Rustic top navigation beam](../../../art/ui_v1/runtime_source/top-nav-rustic-v01.png)
- [Rustic Catch Records plate](../../../art/ui_v1/runtime_source/records-screen-rustic-v01.png)
- [Rustic Settings master promoted for later blank-kit derivation](../../../art/ui_v1/runtime_source/settings-rustic-v01.png)

## Earlier compact/primary wood review captures

| State | Capture |
| --- | --- |
| Compact ready top chrome | [cedar-ready-compact-topnav.png](cedar-ready-compact-topnav.png) |
| Rustic ready top chrome | [cedar-ready-rustic-topnav.png](cedar-ready-rustic-topnav.png) |
| Rustic line-out top chrome | [cedar-line-out-rustic-topnav.png](cedar-line-out-rustic-topnav.png) |
| Primary ready review | [primary-v32-wood-ready.png](primary-v32-wood-ready.png) |
| Primary line-out review | [primary-v32-wood-line-out.png](primary-v32-wood-line-out.png) |

## Tilt / icon-only top chrome — September 8, 2026

Fresh deterministic desktop captures at 720×1280. They show the weathered
wood beam without native icon captions and with player-facing **Tilt** copy.
They are desktop render evidence, not phone screenshots or device acceptance.

| State | Capture | Validation receipt |
| --- | --- | --- |
| Cedar ready, safe top 0 | [tilt-ready-safe0.png](tilt-ready-safe0.png) | [receipt](../validation/v32-tilt-ready-safe0.json) |
| Cedar line out, safe top 0 | [tilt-active-safe0.png](tilt-active-safe0.png) | [receipt](../validation/v32-tilt-active-safe0.json) |
| Cedar ready, safe top 180 | [tilt-ready-safe180.png](tilt-ready-safe180.png) | [receipt](../validation/v32-tilt-ready-safe180.json) |
| Cedar line out, safe top 180 | [tilt-active-safe180.png](tilt-active-safe180.png) | [receipt](../validation/v32-tilt-active-safe180.json) |

The checkpoint suite is [v32-tilt-iconnav-domain-final2.json](../validation/v32-tilt-iconnav-domain-final2.json). The authoritative independent rerun is [primary-tilt-iconnav-domain.json](../validation/primary-tilt-iconnav-domain.json): root PID `94092`, exit `0`, marker `null`, no remaining task PIDs or windows. Both retain only the established 12 ObjectDB / 5 resource teardown diagnostics.

## Current integration review set — September 8, 2026

The rustic runtime integration is complete for desktop review. These selected
captures supersede the earlier WIP/cleared checkpoints above; all are desktop
renders, not phone screenshots or user aesthetic acceptance.

| State | Selected capture |
| --- | --- |
| Pine ready / revised Pine v03 | [terra-ready-pinev03.png](terra-ready-pinev03.png) |
| Cedar active, safe top 180 | [primary-cedar180-final.png](primary-cedar180-final.png) |
| Reduced-motion fight | [primary-reduced-fight-final.png](primary-reduced-fight-final.png) |
| Pine high fight | [primary-pinefight-review.png](primary-pinefight-review.png) |
| Settings, safe top 180 | [terra-final-settings180.png](terra-final-settings180.png) |
| Waters, safe top 180 | [terra-final-waters180.png](terra-final-waters180.png) |
| Catch Records, safe top 180 | [terra-final-records180.png](terra-final-records180.png) |
| World Records, offline | [terra-worldoffline-final.png](terra-worldoffline-final.png) |
| Field Notes | [terra-fieldnotes-final.png](terra-fieldnotes-final.png) |
| Long-species Catch | [terra-final-catchlong.png](terra-final-catchlong.png) |
| Hooked loading | [terra-final-loading.png](terra-final-loading.png) |

Primary review cleared the Pine v03 correction for implementation and cleared
the final Records and Waters layouts for this build review. Those review gates
do **not** claim user aesthetic acceptance.

## Delivery status

The signed `Hooked-0.6.1-rustic1-arm64-debug.apk` was exported, signature and
package-audited, replacement-installed on Pixel 9 Pro, and launcher smoke-tested
by primary review. The DriveFS copy to `H:\My Drive\AI Projects\Haptic Fish`
was size/hash verified locally. Physical UI/motion/haptics/native-ad testing,
cloud-sync completion, and human aesthetic acceptance are not claimed.
# Rustic UI v32 review gallery

- [Blank clipboard runtime source](../../../art/ui_v1/runtime_source/rustic-clipboard-blank-v01.png)
- [Photoreal Pine Lake runtime source](../../../art/ui_v1/runtime_source/pine-lake-photoreal-v02.png)
- [Pine Lake v03 runtime source — primary-cleared for implementation](../../../art/ui_v1/runtime_source/pine-lake-photoreal-v03.png)
- `terra-settings-cleared.png`: inspected Settings repair; opaque clipboard, visible wood actions, no gameplay chrome behind it.
- `terra-ready-cleared.png`: inspected Pine Lake/photoreal rod/top chrome repair.
- `terra-records-final2.png`: source-mapped records slots and paired footer review.

## Selected journal integration — September 8, 2026

These are fresh desktop review captures, personally inspected after the shared
Records, World Records, and Field Notes layout/routing conversion. They are
not phone captures or an APK acceptance claim.

| State | Capture | Wrapper receipt |
| --- | --- | --- |
| Catch Records, safe top 180 | [terra-recordsfull180-final.png](terra-recordsfull180-final.png) | [receipt](../validation/terra-v32-recordsfull180-final2.json) |
| World Records, offline | [terra-worldoffline-final.png](terra-worldoffline-final.png) | [receipt](../validation/terra-v32-worldoffline-final2.json) |
| Field Notes | [terra-fieldnotes-final.png](terra-fieldnotes-final.png) | [receipt](../validation/terra-v32-fieldnotes-final2.json) |

The functional geometry/routing suite is [terra-v32-journal-domain3.json](../validation/terra-v32-journal-domain3.json): exit `0`, no tracked task PIDs or windows. It retains only the established Godot teardown diagnostics (12 ObjectDB and 5 resources).
