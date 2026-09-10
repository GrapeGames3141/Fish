# Water motion v37 evidence

This folder holds the runtime proof for the approved v02 water-animation port.
It is excluded from the Android PCK by `reports/**`.

## Completed validation

- Final parser/import: [`primary-v37-parser-review.json`](validation/primary-v37-parser-review.json), root PID `126756`, exit 0, empty stderr marker, no remaining task PIDs/windows.
- Final deterministic domain suite: [`primary-v37-domain-final.json`](validation/primary-v37-domain-final.json), root PID `112776`, exit 0 and `PASS: Cast & Crank Gate 1 domain tests`. Its stderr contains only the established 12 ObjectDB / 5-resource shutdown notices.
- Passing still captures: Cedar (`117128`), Pine (`107920`), Bite (`124240`), safe-top fight (`116832`), and reduced motion (`124932`), all exit 0 with empty stderr markers and no remaining task processes/windows.
- Two actual runtime clips use one Godot invocation per 48 sequential frames at 16fps (3 seconds): Willow (`119376`) and Hatteras (`63480`). Their raw frame sequences are retained in `E:\CodexCache\haptic-fish-water-v37\{willow,ocean}-frames`.

Sharp encoded the selected raw RGB frames as 720x1280 48-frame, 3000ms,
256-colour looping GIFs (`dither=.5`, `effort=4`, duplicates retained). These
are short runtime samples—not seamless loops. The ocean phase intentionally
uses a non-six-second-periodic rolling swell.

Independent frame checks show animated water without moving protected content:

| Evidence | Willow | Hatteras |
| --- | ---: | ---: |
| Raw frame 0 → 16 water ROI mean-channel delta | 7.3317 | 18.0307 |
| 360x640 GIF playback water mean delta | 5.4754 | 15.698 |
| Top 350px, foreground x<70/y>1100, hand/reel max delta | 0 | 0 |

Reduced-motion Bite frame 0 versus one second has entire-RGBA max delta 0.
Root visual review accepted the four locations and fight presentation for this
implementation pass. The signed arm64 build and package audit are complete:
[`Hooked-0.7.3-water1-arm64-debug.apk`](../../build/android/Hooked-0.7.3-water1-arm64-debug.apk)
is 65,444,082 bytes, SHA-256
`D72010D55EF69463E9A98C79419E897CB25623563079202ED10574E3C32A75BA`.
See [`package-audit-v37.md`](package-audit-v37.md). Physical-device review and
human judgement of the new ocean aesthetic remain pending; no install, Drive
delivery, or push occurred.

[`gallery/README.md`](gallery/README.md) indexes every selected visual.
Earlier `pine-lineout.png` and `willow-lineout-2.png` are retained only as
superseded, unknown-fixture READY captures; they are not final LINE_OUT proof.
