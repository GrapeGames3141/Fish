# Willow Pond water-motion preview v02

This is preview-only work, not game integration. It starts from the approved 720 × 1280 Willow Pond LINE OUT capture and keeps the header, sky, trees, shore, rod, line, bobber, hand and reel protected from the water shader.

Open the [viewer](gallery/view-water-motion-v02.html). It defaults to the [six-second looping GIF](gallery/willow-water-motion-v02.gif); use the **Full-colour video** button or [MP4 companion](gallery/willow-water-motion-v02.mp4) if a Drive/browser GIF preview is static. [Frame 0](gallery/willow-water-motion-v02-frame-000.png), [frame 20](gallery/willow-water-motion-v02-frame-020.png), [frame 40](gallery/willow-water-motion-v02-frame-040.png), [frame 60](gallery/willow-water-motion-v02-frame-060.png), [frame 80](gallery/willow-water-motion-v02-frame-080.png), and the [water mask](gallery/willow-water-motion-v02-mask.png) are retained for review.

The shader uses traveling, non-uniform wind ripples at capped 4–5px near-water displacement plus a restrained crest light lift. It gates movement by both source and destination water-mask alpha/luminance, so it does not borrow shore or tackle colours at its edges. The animation is deterministic: 120 frames at 20fps, repeating in six seconds. A 360px-wide viewer check measured a 4.0065 channel delta in water over 1.3 seconds while the top chrome remained unchanged.

The [Drive delivery verification](validation/drive-delivery.md) records the locally verified GIF and MP4 copies.
