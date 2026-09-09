# Hooked — Fish Icon Preview v01

## Decision and status

The user selected **Hooked** as the display/launcher/loading title on September
8, 2026. Android package `com.tak.castandcrank`, save migration behavior and
internal paths are deliberately unchanged at this preview checkpoint.

The fish artwork below is **review-only**. It has not replaced the production
icon, is excluded from Android exports, and still awaits user acceptance before
any launcher or runtime integration.

## Durable artifact

- Preview: [fish-icon-preview-v01.png](../art/ui_v1/mockups/fish-icon-preview-v01.png)
- Dimensions: 1254 x 1254 px
- Size: 2,678,805 bytes
- SHA-256: `0DE8AE41C79FD113100EC2DB7BE23E4D54E432CF2A99AB8EB1679C4746CF1209`
- The durable E: copy was SHA-256 verified against the built-in generator's
  tool-managed original before the exact disposable original was removed.

## Generation provenance

- Tool mode: built-in ImageGen; the model identifier is not exposed by the
  tool.
- Invocation count: one.
- Reference: `rustic-gameplay-master-v01.png`, used only for the natural dark
  river, daylight and material mood.
- Exact prompt:

```text
Use case: photorealistic-natural
Asset type: square Android adaptive-icon concept preview only, not a production icon
Input image: rustic gameplay master is only a lighting/material reference for its natural dark river and forest atmosphere.
Primary request: Create one square launcher-icon composition. A photoreal recognizable largemouth bass breaks the surface of a dark, natural woodland river. Its head and bold silhouette are clear at small icon scale, with enough realistic body and tail visible to unmistakably read as a fish. Center the fish within a generous Android adaptive-icon central safe region; use a restrained subtle ripple and small natural splash beneath it.
Style/medium: real outdoor wildlife photography quality; muted river greens/blues, warm but restrained daylight, realistic wet scales and water.
Composition: square, centered close subject, clean edge falloff/background, strong readable fish shape with no tiny busy details.
Constraints: no rod, reel, hand, bobber, wooden plaque, text, letters, logo, border, trophy, fantasy creature, oversharpened HDR, cartoon rendering or UI controls.
```

## Future integration guard

If accepted, only user-facing display resources should become `Hooked`. Keep
the Android application ID, existing save/profile migration paths and internal
source identifiers stable until explicit migration validation covers both
Android and desktop user-data locations.
