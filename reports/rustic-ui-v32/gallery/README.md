# Rustic UI v32 gallery

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

## Scope still pending

These captures cover only the Cedar gameplay/top-chrome checkpoint. Rustic
Settings/Motion/World modal skin, Waters, Catch, Records/detail/Field Notes,
and Hooked loading integration still require implementation and review. No
rustic UI APK, phone install, or device interaction validation has been done.
