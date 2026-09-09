# Fight balance v35

`0.7.1-balance1` makes the meter a two-sided working band rather than a
one-sided redline. Standard has red slack below 12% and red overload above
88%, amber warning bands to 28% and from 72%, and the green middle is the
most efficient place to make landing progress. Relaxed widens the safe range
with red thresholds at 8%/92%; Expert narrows it to 18%/82%. The selected setting is saved and
is snapped at cast release, so changing Settings always applies to the next
cast.

Overload can break the line after 0.90 seconds after the opening grace;
continuous slack can lose the fish after 1.65 seconds. The longer slack dwell
allows a real forward recovery after the distinct low-tension warning, while
still preventing a zero-tension stall. Hooking starts at 50% tension.

Each cast independently rolls a bounded 5–14 second bite wait and a passive
shadow visit. A shadow can pass the float without biting. Bite hold and hook
window timings are unchanged.

The deterministic suite covers all twelve fish, all three profiles, 30/60/120
Hz, and three behavior rolls from the real hook entry point. Its 300ms-delayed,
100ms-ramped responsive policy measured: Relaxed 11.75–22.48s, Standard
10.66–19.50s, and Expert 10.78–17.53s. The stronger .82/.10 responsive policy
measured Relaxed 10.00–17.47s, Standard 10.00–15.73s, and Expert 10.00–15.37s.
Standard keeps the required 10–20 second window; the wider Relaxed profile is
allowed its documented 24-second variation. Haptic slack uses a slower long
pulse and small tap; overload retains the faster paired warning.

## Gallery

- [Slack rod and red low band](gallery/fight_slack.png)
- [Centered rod and green work band](gallery/fight_center.png)
- [Loaded rod and tight high band](gallery/reeling_high.png)
- [Expert Settings row](gallery/settings_expert.png)
- [Safe-top 180 Settings](gallery/settings_safe_top_180.png)
- [Passive shadow visit](gallery/shadow_pass.png)
- [Waiting after a shadow pass](gallery/wait_after_shadow.png)
- [Reduced-motion loaded pose](gallery/reduced_reeling_high.png)

The selected images are desktop render evidence only. Physical motion and
haptic feel remain a device/playtest gate.
