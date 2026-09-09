class_name FishingSession
extends RefCounted

const FightChallenge = preload("res://src/domain/fight_challenge.gd")

enum State { READY, CAST_ARMED, LINE_OUT, BITE, HOOK_WINDOW, REELING, CAUGHT, ESCAPED }
enum FightStage { OPENING_RUN, WORKING, LAST_SURGE, LANDING }
const HOOK_WINDOW_SECONDS := 1.8
const BITE_CUE_HOLD_SECONDS := 0.42
const CATCH_PROGRESS := 1.0
const MIN_CAST_DISTANCE_M := 8.0
const MAX_CAST_DISTANCE_M := 40.0
const MIN_LANDING_SECONDS := 10.0
const TERMINAL_RECAST_DWELL_SECONDS := 2.35
const TERMINAL_STILL_SECONDS := 0.46
var state := State.READY
var fish: FishDefinition = FishDefinition.bluegill()
var location_id := "pine_lake"
var selection_roll := 0.0
var size_roll := 0.0
var behavior_roll := 0.0
var bite_roll := 0.5
var wildlife_roll := 0.5
var bite_wait_seconds := 8.0
var shadow_visit_start := -1.0
var shadow_visit_duration := 0.0
var challenge_id := FightChallenge.DEFAULT_ID
var challenge_profile: Dictionary = FightChallenge.profile(FightChallenge.DEFAULT_ID)
var elapsed := 0.0
var bite_elapsed := 0.0
var tension := 0.12
var strain := 0.0
var red_elapsed := 0.0
var slack_elapsed := 0.0
var fight_progress := 0.0
var fight_elapsed := 0.0
var rod_load := 0.0
var cast_quality := 0.0
var cast_distance_m := 0.0
var catch_length_cm := 0.0
var fight_running := false
var fight_effort := 0.0
var fight_phase_offset := 0.0
var fight_stage := FightStage.OPENING_RUN
var land_opportunity := false
var last_surge_started := false
var last_surge_remaining := 0.0
var terminal_elapsed := 0.0
var terminal_still_elapsed := 0.0
var last_reason := ""
func set_location(value: String, roll: float = 0.0) -> bool:
	if state not in [State.READY, State.CAUGHT, State.ESCAPED] or FishDefinition.for_location(value).is_empty(): return false
	location_id = value; selection_roll = clampf(roll, 0.0, 0.999999)
	# Hidden placeholder keeps deterministic capture fixtures addressable; release
	# always replaces it with the distance-aware encounter before any fish is shown.
	fish = FishDefinition.select_weighted(location_id, selection_roll); return true
func set_encounter_rolls(fish_roll: float, length_roll: float, behavior: float, bite_wait_roll := 0.5, wildlife := 0.5) -> void:
	selection_roll = clampf(fish_roll, 0.0, 0.999999); size_roll = clampf(length_roll, 0.0, 0.999999); behavior_roll = clampf(behavior, 0.0, 0.999999)
	bite_roll = clampf(bite_wait_roll, 0.0, 0.999999); wildlife_roll = clampf(wildlife, 0.0, 0.999999)

func set_next_cast_challenge(value: Variant) -> void:
	# Only called while safely between casts. release_cast snapshots the profile.
	if state in [State.READY, State.CAST_ARMED]: challenge_id = FightChallenge.sanitize(value)
func arm_cast() -> bool:
	if state != State.READY: return false
	state = State.CAST_ARMED; return true
func cancel_cast() -> bool:
	if state != State.CAST_ARMED: return false
	state = State.READY; return true
func release_cast(quality: float) -> bool:
	if state != State.CAST_ARMED: return false
	cast_quality = clampf(quality, 0.0, 1.0); cast_distance_m = lerpf(MIN_CAST_DISTANCE_M, MAX_CAST_DISTANCE_M, cast_quality)
	# Encounter selection happens only after the line reaches a habitat band.
	fish = FishDefinition.select_weighted(location_id, selection_roll, cast_distance_m)
	catch_length_cm = _rolled_length(size_roll)
	fight_phase_offset = behavior_roll * maxf(0.20, fish.run_seconds + fish.lull_seconds)
	challenge_profile = FightChallenge.profile(challenge_id)
	# A dedicated per-cast roll prevents fish size/behavior from accidentally
	# choosing bite timing. Species retain only a modest, bounded character offset.
	bite_wait_seconds = clampf(5.0 + bite_roll * 9.0 + clampf(fish.bite_delay_seconds - 2.8, -0.65, 0.65), 5.0, 14.0)
	# A shadow is wildlife, not a promise: it arrives independently, passes the
	# float, and may be long gone before the real bite begins.
	shadow_visit_duration = lerpf(1.4, 3.2, wildlife_roll)
	shadow_visit_start = clampf(1.0 + fmod(wildlife_roll * 11.0, 5.2), 1.0, maxf(1.0, bite_wait_seconds - shadow_visit_duration - 0.45))
	state = State.LINE_OUT; elapsed = 0.0; return true
func _rolled_length(roll: float) -> float:
	# Common ordinary fish, rare upper-tail fish; distance is only a slight nudge.
	var habitat_bonus := 0.035 if cast_distance_m >= 30.0 else (-0.018 if cast_distance_m < 18.0 else 0.0)
	var distribution := pow(clampf(roll, 0.0, 0.999999), 1.85)
	return snappedf(lerpf(fish.min_length_cm, fish.max_length_cm, clampf(0.07 + distribution * 0.88 + habitat_bonus, 0.03, 0.98)), 0.1)
func tick(delta: float) -> void:
	# Preserve elapsed time for deterministic replays; callers supply ordinary frame
	# deltas and the fight math itself is rate-based.
	delta = maxf(delta, 0.0)
	if state == State.LINE_OUT:
		elapsed += delta
		if elapsed >= bite_wait_seconds: state = State.BITE; bite_elapsed = 0.0
	elif state == State.BITE:
		bite_elapsed += delta
		if bite_elapsed >= BITE_CUE_HOLD_SECONDS:
			state = State.HOOK_WINDOW; bite_elapsed = 0.0
	elif state == State.HOOK_WINDOW:
		bite_elapsed += delta
		if bite_elapsed >= HOOK_WINDOW_SECONDS: escape("The %s spit the hook." % fish.display_name)
	elif state == State.REELING:
		_tick_fight(delta)
	elif state in [State.CAUGHT, State.ESCAPED]:
		terminal_elapsed += delta

func _tick_fight(delta: float) -> void:
	fight_elapsed += delta
	# A readable, deterministic arc: an opening run, working runs/lulls, and only
	# some behavior rolls get one modest final surge before landing. It is a cue to
	# ease, never a hidden timed loss gate.
	if fight_progress >= 0.92:
		fight_stage = FightStage.LANDING; land_opportunity = true; last_surge_remaining = 0.0
	elif last_surge_remaining > 0.0:
		last_surge_remaining = maxf(0.0, last_surge_remaining - delta)
		fight_stage = FightStage.LAST_SURGE if last_surge_remaining > 0.0 else FightStage.WORKING; land_opportunity = false
	elif not last_surge_started and behavior_roll >= 0.72 and fight_progress >= 0.70 and fight_elapsed >= 7.0:
		last_surge_started = true; last_surge_remaining = 0.35
		fight_stage = FightStage.LAST_SURGE; land_opportunity = false
	elif fight_elapsed < 1.15:
		fight_stage = FightStage.OPENING_RUN; land_opportunity = false
	else:
		fight_stage = FightStage.WORKING; land_opportunity = false
	var cycle := maxf(0.20, fish.run_seconds + fish.lull_seconds)
	var phase := fmod(fight_elapsed + fight_phase_offset, cycle)
	fight_running = phase < fish.run_seconds
	var headshake := fight_running and phase < minf(0.18, fish.run_seconds * 0.32)
	fight_effort = 1.0 if fight_running else 0.22
	if headshake: fight_effort = 1.18
	if fight_stage == FightStage.OPENING_RUN and tension < 0.65:
		fight_running = true; fight_effort = maxf(fight_effort, 0.94)
	elif fight_stage == FightStage.LAST_SURGE:
		# One short forced run makes the optional surge physically legible, then the
		# explicit landing stage quiets rather than trapping the player at the end.
		fight_running = true
	elif fight_stage == FightStage.LANDING:
		fight_running = false; fight_effort = 0.18
	var pull := clampf(rod_load, 0.0, 1.0)
	var sustained_pull := maxf(0.0, pull - 0.34) / 0.66
	# A held-back rod accumulates strain; a genuine forward/ease pose clears it fast.
	strain = clampf(strain + sustained_pull * fish.strain_rate * (0.72 + fight_effort * 0.55) * delta - maxf(0.0, 0.48 - pull) / 0.48 * fish.recovery_rate * delta, 0.0, 1.0)
	var fish_pressure := fish.run_pressure * (0.22 + fight_effort * 0.78)
	if fight_stage == FightStage.LAST_SURGE and fight_running: fish_pressure *= 1.06
	if fight_stage == FightStage.LANDING: fish_pressure *= 0.52
	var rod_pressure := sustained_pull * (0.052 + fish.fight_strength * 0.035) + strain * 0.105
	# Even the pike's strongest run must visibly ease within a second or two when
	# the player lowers the rod; this is stronger than any single run pressure.
	var relief := maxf(0.0, 0.52 - pull) / 0.52 * (0.50 + fish.recovery_rate * 0.30)
	tension = clampf(tension + (fish_pressure + rod_pressure - relief) * delta, 0.0, 1.0)
	var protected_start := fight_elapsed < float(challenge_profile.startup_grace)
	if tension >= float(challenge_profile.high_critical) and not protected_start:
		red_elapsed += delta
		if red_elapsed >= float(challenge_profile.danger_seconds):
			escape("The line snapped under %s's pull." % fish.display_name)
			return
	else:
		red_elapsed = maxf(0.0, red_elapsed - delta * 2.8)
	if tension <= float(challenge_profile.low_critical) and not protected_start:
		slack_elapsed += delta
		if slack_elapsed >= float(challenge_profile.slack_seconds):
			escape("The line went slack and %s shook free." % fish.display_name)
			return
	else:
		slack_elapsed = maxf(0.0, slack_elapsed - delta * 2.2)
	var pull_window := 0.32 if fight_running else 1.0
	var size_factor := 1.0
	if catch_length_cm > 0.0:
		# Ordinary fish keep the proven 10–20s rhythm; only the bounded upper tail
		# carries a small additional pull requirement.
		size_factor += maxf(0.0, inverse_lerp(fish.min_length_cm, fish.max_length_cm, catch_length_cm) - 0.85) * 0.25
	var center_work := FightChallenge.center_reward(tension, challenge_profile)
	var danger_penalty := 1.0 - maxf(0.0, tension - float(challenge_profile.high_warning)) * 1.25
	var efficiency := fish.pull_efficiency / size_factor * pull_window * center_work * (1.0 - strain * 0.72) * danger_penalty
	if fight_stage == FightStage.LANDING: efficiency *= 1.24
	fight_progress = clampf(fight_progress + sustained_pull * efficiency * delta, 0.0, CATCH_PROGRESS)
	# The red-line check happens before landing: a simultaneous snap never becomes a catch.
	if fight_progress >= CATCH_PROGRESS and fight_elapsed >= MIN_LANDING_SECONDS and FightChallenge.tier(tension, challenge_profile) not in ["slack", "snap"]:
		state = State.CAUGHT; last_reason = "%s landed!" % fish.display_name
func set_hook() -> bool:
	if state != State.HOOK_WINDOW: return false
	state = State.REELING; elapsed = 0.0; fight_elapsed = 0.0; fight_progress = 0.0; fight_stage = FightStage.OPENING_RUN; land_opportunity = false; last_surge_started = false; last_surge_remaining = 0.0; rod_load = 1.0; tension = 0.50; strain = 0.0; red_elapsed = 0.0; slack_elapsed = 0.0; return true
func set_rod_load(value: float) -> void: if state == State.REELING: rod_load = clampf(value, 0.0, 1.0)
func credit_terminal_still(delta: float, quiet: bool) -> void:
	if state not in [State.CAUGHT, State.ESCAPED]: return
	if quiet: terminal_still_elapsed = minf(TERMINAL_STILL_SECONDS, terminal_still_elapsed + clampf(delta, 0.0, 0.08))
	else: terminal_still_elapsed = 0.0
func can_recast_from_motion() -> bool:
	return state in [State.CAUGHT, State.ESCAPED] and terminal_elapsed >= TERMINAL_RECAST_DWELL_SECONDS and terminal_still_elapsed >= TERMINAL_STILL_SECONDS
func escape(reason: String) -> void: state = State.ESCAPED; last_reason = reason
func reset() -> void: state = State.READY; elapsed = 0.0; bite_elapsed = 0.0; tension = 0.12; strain = 0.0; red_elapsed = 0.0; slack_elapsed = 0.0; fight_progress = 0.0; fight_elapsed = 0.0; fight_stage = FightStage.OPENING_RUN; land_opportunity = false; last_surge_started = false; last_surge_remaining = 0.0; rod_load = 0.0; cast_quality = 0.0; cast_distance_m = 0.0; catch_length_cm = 0.0; fight_running = false; fight_effort = 0.0; terminal_elapsed = 0.0; terminal_still_elapsed = 0.0; last_reason = ""
