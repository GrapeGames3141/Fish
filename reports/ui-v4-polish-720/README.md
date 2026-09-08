# UI v4 polish capture gallery

All captures are deterministic 720×1280 desktop renders. They use an in-memory default save and frozen gameplay progression after fixture setup, so they do not modify player progress.

| Area | Captures |
|---|---|
| Fishing chrome | [ready](top_nav_ready.png), [safe top 91](top_nav_safe_top.png), [safe top 180](top_nav_safe_top_180.png) |
| Fishing state | [bite](bite.png), [high tension](reeling_high.png) |
| Settings | [settings](settings.png), [settings safe top 180](settings_safe_top_180.png), [motion setup](motion_setup.png) |
| Waters | [waters](locations.png), [waters safe top 91](locations_safe_top_91.png), [waters safe top 180](locations_safe_top_180.png) |
| Records | [records](records.png) |
| Catch status | [first catch](catch_first.png), [new best](catch_new_best.png), [matched best](catch_tie.png), [long species](catch_long_species.png) |

Verified: all sixteen images are 720×1280; the authoritative primary parser/domain/render/export checks are recorded in `validation/primary-*.json`. The earlier `ui-v4-domain-final.json` is superseded because it exposed an uninitialized test-harness dependency. [Earlier orphan cleanup](validation/orphan-cleanup-20260907.json) and [primary export cleanup](validation/primary-build-cleanup.json) record the task-only process cleanup.

The domain stderr retains the inherited Godot teardown lines for 12 ObjectDB instances and 5 resources; the same lines are present in `reports/v25-domain2-stderr.log`. They are not treated as runtime Script/Parse errors.

Pending: physical foreground review, touch routing, cast/hook/fight motion, haptic feel, native ad behavior, and human acceptance remain separate gates. Desktop captures and a keyguard-limited startup check do not establish those outcomes.

Primary refreshed all sixteen final renders successfully (`validation/primary-render-*.json`): each is 720×1280, exit 0, has no stderr marker, and leaves no tracked task process. The malformed `primary-capture-top_nav_ready` attempt timed out with WASAPI errors and is superseded; use the `primary-render-*` ledgers. Package/export and Pixel startup evidence is summarized in [delivery.md](../../delivery.md). The Pixel keyguard prevented foreground review, so the remaining device interaction and feel gates still apply.
