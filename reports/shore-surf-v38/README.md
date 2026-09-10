# Hatteras shore surf v38

This is the first code-native follow-up to the user’s report that the lower
right Hatteras water was frozen. It changes no location photo, exported build,
or gameplay rule.

## Implementation

- `hatteras-mask.svg` now follows the photographed foreground shoreline from
  canonical `(0,930)` through `(600,1230)`, reaches the bottom-right water
  edge, and admits only a 36–46px x-aware swash band shoreward of that original
  line. It keeps the lower-left grass and dry sand outside the water mask.
- The first sharp front capture passed mechanically but was visually rejected:
  `E:\CodexCache\haptic-fish-surf-v38\ocean-frames1\frame-020.png` showed
  marbled/stretch-fold artifacts. It remains provenance, not aesthetic proof.
- The corrected Hatteras-only shader now uses a broad, cosine shorewash with a
  0–28px run-up, low-frequency alongshore lag, a 70px shoreward / 210px
  offshore fade, and a separate <=7px broad offshore ridge. It samples the
  photo once at the final coordinate: no high-contrast double image mix,
  white-line foam, opaque overlay, image swap, or new raster asset is used.
- Source and destination mask tests prevent dry shore pixels being sampled into
  the moving water. The finite-difference test checks the actual `p-offset`
  sampling map over five phases so shorewash does not fold. Hatteras bobber and
  line now add the exact same bounded surf offset after their existing common
  drift cap; inland profiles remain unchanged. Reduced Motion returns the
  original still plate.
- `hatteras_reduced_line_out` and `hatteras_short_line_out` are available for
  deterministic frozen and tackle-coherence captures. The next build is code
  `38`, name `0.7.4-surf1`.

## Required primary review

Primary captured the corrected 120-frame/20fps Hatteras sample and accepted
the source frames for photographic texture. Parser `117672`, final domain
`116536`, corrected clip `1760`, Reduced Motion `96224`, Willow regression
`114744`, and Hatteras short-cast `84776` all exit 0 with no stderr marker,
remaining task PID, or window. The intermediate `domain2` parse failure
(`121304`) is superseded by the explicit-type correction and final domain pass.
The gallery and pixel audit are indexed in [`gallery/README.md`](gallery/README.md).

The fresh signed arm64 `38` / `0.7.4-surf1` export/package audit is complete:
[`Hooked-0.7.4-surf1-arm64-debug.apk`](../../build/android/Hooked-0.7.4-surf1-arm64-debug.apk)
is 65,445,378 bytes, SHA-256
`6DC9E20860925FB0D517F6990513DC534C5E1ADF68CE0261346069C256B6A004`.
See [`package-audit-v38.md`](package-audit-v38.md). Device performance and user
visual approval remain pending; no phone install, Drive copy, or push occurred.
