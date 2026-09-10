# Water motion v37

## Scope

The approved v02 water-motion preview was accepted on 2026-09-09. This build
ports that presentation to the live photographic location plates without using
the full-screen preview as runtime art. `WaterSurface` is a CanvasItem behind
the native rod, mono, bobber, UI, and overlays; it uses each original location
photo plus a reproducible, shoreline-specific SVG mask.

## Profiles

- Willow Pond uses restrained, varied pond ripples derived from the approved v02 spectrum.
- Pine Lake increases the visible wind chop.
- Cedar River adds a faster, leftward-directed current on top of the ripple field.
- Hatteras Inlet adds a longer travelling swell, smaller chop, and restrained crest light.

The shader source and destination are both mask-gated, so shore/vegetation and
the native tackle cannot be sampled into moving water. The same canonical
720x1280 phase field drives the CPU bobber offset/tilt and the shader. Reduced
Motion freezes that ambient field while leaving state-critical bite/fight
presentation intact.

The float now uses its actual opaque source crop: the white dome and red cap
remain above water, while the lower red hemisphere is alpha-preserving, dimmed,
and compressed below the contact ripple. The float remains hidden in Bite,
Hook Window, and Reeling as before.

## Reproducibility and review

- Runtime code: `src/ui/water_surface.gd`, `src/ui/water_surface.gdshader`, and the focused integration in `src/ui/main.gd`.
- Masks: `art/ui_v1/runtime_source/water-motion-v01/`. They are hand-authored SVG geometry over the existing approved photos; no new ImageGen asset was introduced.
- Approved reference: `reports/water-motion-preview-v02/` (preview-only; not shipped).
- Final parser/domain, all location stills, Bite/Reeling float-absence, and
  reduced-motion captures are indexed in `reports/water-motion-v37/README.md`.
- 48-frame/16fps three-second Willow and Hatteras runtime samples are in
  `reports/water-motion-v37/gallery/`; their raw frames demonstrate only water
  movement while header, sky, shoreline, hand/reel, and protected foreground
  remain static.

The ocean clip is deliberately a short runtime sample, not a seamless loop:
its rolling-swell phase is not six-second periodic. The signed arm64 export
and package audit are recorded in
`reports/water-motion-v37/package-audit-v37.md`; four mask resources and the
water shader are packaged, while reports/tests/docs/tools and GIF/MP4 evidence
are excluded. Device review and human approval of each new location
profile—particularly the ocean aesthetic—remain separate from desktop evidence.
