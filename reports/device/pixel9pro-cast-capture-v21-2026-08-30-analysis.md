# Pixel 9 Pro v21 explicit cast-capture replay

## Evidence identity

- Input: `pixel9pro-cast-capture-v21-2026-08-30.json`, 340,379 bytes, SHA-256 `DA61E2A901E70266786D903DEC763132124B6BBB8B89A6B3B6A3DD9E69AD8F70`.
- Capture: schema v1, 10 completed independent 2-second windows; right-handed; sensitivity 1.
- Replay first-sample delta: 0.017s (median positive in-window `t_ms` delta); later deltas use adjacent timestamps and sweep integration caps each at 0.05s.
- This report contains only derived projections, timing, thresholds, and outcomes. Raw vectors remain only in the explicitly user-started input capture.

## Current v21 replay model

- Learned normalized forward axis: [-0.8526, 0.273686, -0.445162].
- Gates: cock 1.244478, snap 1.546186, gyro 0.6; learned-axis tolerance 0.62, physical-polarity tolerance 0.18.
- Shape: entry floor max(0.15, threshold × .35), at least 3 directed samples, each delta capped at .05s. Current factors: cock .045; snap .055. Final acceptance still requires threshold, learned-axis, physical-polarity, gyro, and .22s-full/.65s-fail reversal timing. A rejected qualified frame can recover later within its same directed burst.

## Factor grid — accepted windows / 10

| Cock factor \ snap factor | .055 | .0625 | .070 |
|---:|---:|---:|---:|
| 0.045 | 1 | 1 | 1 |
| 0.0475 | 1 | 1 | 1 |
| 0.05 | 1 | 1 | 1 |
| 0.0525 | 1 | 1 | 1 |
| 0.055 | 1 | 1 | 1 |

At the current v21 pair (.045/.055), 1/10 windows emit a cast (1 cast event(s)); 4/10 arm but do not complete a snap.

## Current v21 per-window replay (.045 cock / .055 snap)

| Window | Arms (time, projection, impulse, samples) | Casts (time, projection, impulse, samples, reversal, quality) | Result / first derived rejections |
|---:|---|---|---|
| 1 | — | — | cock:axis; cock:axis@1216ms |
| 2 | 1984ms p1.4586 i0.0667 n7 | — | no_qualified_sweep; — |
| 3 | 1417ms p4.0743 i0.1079 n3 | — | cock:axis; cock:axis@567ms |
| 4 | 1850ms p1.8359 i0.0662 n3 | — | cock:axis; cock:axis@750ms |
| 5 | — | — | no_qualified_sweep; — |
| 6 | 533ms p2.7031 i0.0957 n3 | 983ms p6.1265 i0.3068 n6; rev 450ms; q0.5293 | cast; snap:axis@950ms, cock:axis@1467ms |
| 7 | 1600ms p2.5807 i0.0878 n5 | — | cock:axis; cock:axis@783ms |
| 8 | — | — | cock:axis; cock:axis@650ms |
| 9 | — | — | cock:gyro; cock:gyro@1650ms |
| 10 | — | — | cock:axis; cock:axis@683ms |

## Natural trace envelope

| Derived measure | p10 | p25 | p50 | p75 | p90 | max |
|---|---:|---:|---:|---:|---:|---:|
| Back/right projection | -17.2883 | -5.5944 | -1.0111 | -0.02 | 0.8397 | 4.1519 |
| Forward/left projection | -0.8397 | 0.02 | 1.0111 | 5.5944 | 17.2883 | 112.1129 |
| Gyro magnitude | 0.0912 | 0.4847 | 1.3573 | 4.4223 | 9.7518 | 29.1686 |
| Linear magnitude | 0.4087 | 0.9124 | 2.9913 | 14.126 | 30.9335 | 118.4071 |

Per-window maxima and the bounded persistence-field reconstruction difference are retained in the machine-readable companion JSON. The replay uses the captured derived-linear field because CastCaptureService derives it before independently clamping persisted gravity/accelerometer/linear components; reconstructing it from two already-clamped source fields would distort saturated motion samples.

## Failure split and recommendation

- Current-pair replay derived failures: cock 8, snap 1. A missing stage means no final qualified burst rather than a raw-sensor diagnosis.
- The evidence does not support raising the cock impulse: all tested cock factors produce 1/10 accepted windows while snap remains 0.055. Keep cock at the known v18 factor 0.045 and keep snap at 0.055; investigate final direction/gyro/timing only if the detailed replay identifies those gates.
- Scope caution: these are deliberately intended-positive ten-cast traces. They establish repeatability and show whether quiet/pre-motion portions create premature events, but they do **not** prove false-positive rejection for incidental movement. Keep wrong-direction/off-axis/noise trace tests and physical negative testing as separate evidence.

## Asymmetric candidate: physical-X cock, learned-axis snap

For this right-handed capture only, the candidate cock uses signed `+X` rightward projection and normalized `+X` alignment (minimum `.18`), instead of the learned profile-axis cock match. The forward snap retains the exact learned 3D axis, final snap threshold, direction/polarity/gyro gates, shape entry/count/cap, and `.055` snap impulse factor from v21.
The selected physical-cock candidate is implemented in v22 source as a follow-up, but this report remains a replay of the v21 capture; it is not physical v22 evidence.

| Physical cock threshold multiplier \ impulse factor | .045 | .055 | .065 | .075 | .090 |
|---:|---:|---:|---:|---:|---:|
| 1× | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 |
| 1.5× | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 |
| 2× | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 |
| 3× | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 |
| 4× | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 |
| 5× | 10/10 | 10/10 | 10/10 | 8/8 | 8/8 |
| 6× | 10/10 | 9/9 | 8/8 | 7/7 | 6/6 |

Each cell is `cast-accepted windows / windows with an arm 0–650ms before that window’s dominant physical-left (`-X`) snap`. This timing measure tests whether the cock is positioned in the actual reversal interval; it is not a false-positive test.

Using final amplitude threshold as the primary strictness dimension (then sweep energy), the strictest grid variant with the best observed intended-example coverage is **6×** the current cock threshold (physical threshold 7.4669) and cock impulse **0.045**. It accepts 10/10 windows and arms timely for 10/10. A 5×/.065 candidate is an all-pass higher-impulse alternative, but not a higher final-amplitude gate. Keep snap impulse at **.055**: this grid changes only cock treatment, and no snap-factor evidence supports tightening it.

## Snap final-threshold grid — fixed physical cock 6× / .045

This grid fixes the selected physical cock at 6× the base cock threshold with .045 impulse. Every row retains the learned 3D snap axis, `.18` physical-polarity gate, `.60` gyro gate, three-sample sweep, `.055` snap impulse, and `.65s` reversal limit; only the snap **final amplitude threshold** is multiplied.

| Snap threshold multiplier | Final threshold | Accepted / timely arms | Cast events |
|---:|---:|---:|---:|
| 1× | 1.5462 | 10/10 | 10 |
| 2× | 3.0924 | 10/10 | 10 |
| 3× | 4.6386 | 10/10 | 10 |
| 4× | 6.1847 | 10/10 | 10 |
| 5× | 7.7309 | 10/10 | 10 |
| 6× | 9.2771 | 10/10 | 10 |
| 8× | 12.3695 | 10/10 | 10 |
| 10× | 15.4619 | 10/10 | 10 |
| 12× | 18.5542 | 10/10 | 10 |
| 16× | 24.739 | 10/10 | 10 |
| 20× | 30.9237 | 10/10 | 10 |
| 24× | 37.1085 | 10/10 | 10 |
| 32× | 49.4779 | 6/10 | 6 |

The strictest final snap threshold that still accepts and timely-arms all ten intended windows is **24×** (final threshold 37.1085). The .055 snap impulse remains fixed; this is amplitude-only evidence.

| All-pass snap multiplier | Quality min | p10 | p25 | p50 | p75 | p90 | max |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 2× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 3× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 4× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 5× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 6× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 8× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 10× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 12× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 16× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 20× | 0.8711 | 0.9005 | 0.9468 | 1 | 1 | 1 | 1 |
| 24× | 0.8711 | 0.8711 | 0.9207 | 1 | 1 | 1 | 1 |

These quality summaries are deterministic replay outputs, not player-feel evidence. Intended-positive examples alone cannot establish incidental-motion false-positive rejection.

| Window | Right-cock envelope (peak projection / +X alignment / time) | Learned-axis snap envelope (peak projection / alignment / time) | Dominant physical-left snap (projection / time) |
|---:|---|---|---|
| 1 | 13.0024 / 0.3789 / 1216ms | 102.025 / 0.9171 / 1333ms | 100 / 1333ms |
| 2 | 11.9616 / 0.2103 / 1100ms | 81.942 / 0.9406 / 1200ms | 82.4155 / 1200ms |
| 3 | 25.5322 / 0.4548 / 683ms | 94.1318 / 0.8413 / 783ms | 82.9998 / 800ms |
| 4 | 11.1312 / 0.5721 / 716ms | 97.4895 / 0.8589 / 950ms | 81.8669 / 983ms |
| 5 | 11.4505 / 0.3055 / 1017ms | 86.548 / 0.9712 / 1134ms | 75.1611 / 1134ms |
| 6 | 11.2539 / 0.2288 / 1567ms | 80.6176 / 0.9623 / 1667ms | 72.8785 / 1667ms |
| 7 | 10.4226 / 0.5449 / 766ms | 68.9433 / 0.7927 / 1033ms | 58.0481 / 1033ms |
| 8 | 16.1485 / 0.3415 / 850ms | 87.1493 / 0.9411 / 934ms | 70.019 / 934ms |
| 9 | 13.3308 / 0.28 / 967ms | 86.2677 / 0.8749 / 1033ms | 73.2989 / 1033ms |
| 10 | 16.3361 / 0.3775 / 866ms | 112.1129 / 0.9468 / 966ms | 100 / 966ms |

## Reproduction

```powershell
node tools/analyze_cast_capture.js reports/device/pixel9pro-cast-capture-v21-2026-08-30.json reports/device/pixel9pro-cast-capture-v21-2026-08-30-analysis.json reports/device/pixel9pro-cast-capture-v21-2026-08-30-analysis.md
```
