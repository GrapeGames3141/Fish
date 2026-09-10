# Selected water motion v37 gallery

All images are native 720x1280 Godot runtime captures. The two GIFs are short
three-second looping samples rendered from actual sequential Godot frames;
they are not mockups or baked preview art.

## Motion samples

- [Willow Pond runtime GIF](willow-runtime-v37.gif) — 48 frames, 3000ms, 6,420,289 bytes.
- [Hatteras Inlet runtime GIF](ocean-runtime-v37.gif) — 48 frames, 3000ms, 13,777,152 bytes.

## Selected frames and state coverage

- [Willow frame 16](willow-time1.png) and [Hatteras frame 16](ocean-time1.png) — representative motion-sample frames.
- [Willow LINE_OUT](primary-willow-review.png) — accepted split float: dry upper dome/cap and submerged lower red hemisphere.
- [Hatteras LINE_OUT](primary-ocean-review.png) — ocean swell/crest profile.
- [Cedar River LINE_OUT](cedar-final.png) — directed-current profile.
- [Pine Lake LINE_OUT](pine-final.png) — stronger wind-chop profile.
- [Bite](bite-final.png) and [fight, safe top](fight-final.png) — float absent in active Bite/Reeling states.
- [Reduced motion](reduced-final.png) — ambient water/bobber animation frozen.

Source provenance: these retain the existing runtime location photos from
`art/ui_v1/runtime_source/`; motion is applied by `WaterSurface` with the
reproducible hand-authored masks in
`art/ui_v1/runtime_source/water-motion-v01/`. The user-approved preview source
is [water-motion-preview-v02](../../water-motion-preview-v02/), but it is not
used as a shipped runtime screen.
