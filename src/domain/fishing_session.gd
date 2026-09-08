class_name FishingSession
extends RefCounted

enum State { READY, CAST_ARMED, LINE_OUT, BITE, HOOK_WINDOW, REELING, CAUGHT, ESCAPED }
const HOOK_WINDOW_SECONDS := 1.8
const BITE_CUE_HOLD_SECONDS := 0.42
const RED_ESCAPE_SECONDS := 0.90
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
var elapsed := 0.0
var bite_elapsed := 0.0
var tension := 0.12
var strain := 0.0
var red_elapsed := 0.0
var fight_progress := 0.0
var fight_elapsed := 0.0
var rod_load := 0.0
var cast_quality := 0.0
var cast_distance_m := 0.0
var catch_length_cm := 0.0
var fight_running := false
var fight_effort := 0.0
var fight_phase_offset := 0.0
var terminal_elapsed := 0.0
var terminal_still_elapsed := 0.0
var last_reason := ""
func set_location(value: String, roll: float = 0.0) -> bool:
	if state not in [State.READY, State.CAUGHT, State.ESCAPED] or FishDefinition.for_location(value).is_empty(): return false
	location_id = value; selection_roll = clampf(roll, 0.0, 0.999999)
	# Hidden placeholder keeps deterministic capture fixtures addressable; release
	# always replaces it with the distance-aware encounter before any fish is shown.
	fish = FishDefinition.select_weighted(location_id, selection_roll); return true
func set_encounter_rolls(fish_roll: float, length_roll: float, behavior: float) -> void:
	selection_roll = clampf(fish_roll, 0.0, 0.999999); size_roll = clampf(length_roll, 0.0, 0.999999); behavior_roll = clampf(behavior, 0.0, 0.999999)
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
	state = State.LINE_OUT; elapsed = 0.0; return true
func _rolled_length(roll: float) -> float:
	# Common ordinary fish, rare upper-tail fish; distance is only a slight nudge.
	var habitat_bonus := 0.035 if cast_distance_m >= 30.0 else (-0.018 if cast_distance_m < 18.0 else 0.0)
	var distribution := pow(clampf(roll, 0.0, 0.999999), 1.85)
	return lerpf(fish.min_length_cm, fish.max_length_cm, clampf(0.07 + distribution * 0.88 + habitat_bonus, 0.03, 0.98))
func tick(delta: float) -> void:
	# Preserve elapsed time for deterministic replays; callers supply ordinary frame
	# deltas and the fight math itself is rate-based.
	delta = maxf(delta, 0.0)
	if state == State.LINE_OUT:
		elapsed += delta
		if elapsed >= fish.bite_delay_seconds: state = State.BITE; bite_elapsed = 0.0
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
	var cycle := maxf(0.20, fish.run_seconds + fish.lull_seconds)
	var phase := fmod(fight_elapsed + fight_phase_offset, cycle)
	fight_running = phase < fish.run_seconds
	var headshake := fight_running and phase < minf(0.18, fish.run_seconds * 0.32)
	fight_effort = 1.0 if fight_running else 0.22
	if headshake: fight_effort = 1.18
	var pull := clampf(rod_load, 0.0, 1.0)
	var sustained_pull := maxf(0.0, pull - 0.34) / 0.66
	# A held-back rod accumulates strain; a genuine forward/ease pose clears it fast.
	strain = clampf(strain + sustained_pull * fish.strain_rate * (0.72 + fight_effort * 0.55) * delta - maxf(0.0, 0.48 - pull) / 0.48 * fish.recovery_rate * delta, 0.0, 1.0)
	var fish_pressure := fish.run_pressure * (0.22 + fight_effort * 0.78)
	var rod_pressure := sustained_pull * (0.052 + fish.fight_strength * 0.035) + strain * 0.105
	# Even the pike's strongest run must visibly ease within a second or two when
	# the player lowers the rod; this is stronger than any single run pressure.
	var relief := maxf(0.0, 0.52 - pull) / 0.52 * (0.50 + fish.recovery_rate * 0.30)
	tension = clampf(tension + (fish_pressure + rod_pressure - relief) * delta, 0.0, 1.0)
	if tension >= 0.90:
		red_elapsed += delta
		if red_elapsed >= RED_ESCAPE_SECONDS:
			escape("The line snapped under %s's pull." % fish.display_name)
			return
	else:
		red_elapsed = maxf(0.0, red_elapsed - delta * 2.8)
	var pull_window := 0.32 if fight_running else 1.0
	var efficiency := fish.pull_efficiency * pull_window * (1.0 - strain * 0.72) * (1.0 - maxf(0.0, tension - 0.76) * 0.9)
	fight_progress = clampf(fight_progress + sustained_pull * efficiency * delta, 0.0, CATCH_PROGRESS)
	# The red-line check happens before landing: a simultaneous snap never becomes a catch.
	if fight_progress >= CATCH_PROGRESS and fight_elapsed >= MIN_LANDING_SECONDS and tension < 0.90:
		state = State.CAUGHT; last_reason = "%s landed!" % fish.display_name
func set_hook() -> bool:
	if state != State.HOOK_WINDOW: return false
	state = State.REELING; elapsed = 0.0; fight_elapsed = 0.0; fight_progress = 0.0; rod_load = 1.0; tension = maxf(tension, 0.3); strain = 0.0; return true
func set_rod_load(value: float) -> void: if state == State.REELING: rod_load = clampf(value, 0.0, 1.0)
func credit_terminal_still(delta: float, quiet: bool) -> void:
	if state not in [State.CAUGHT, State.ESCAPED]: return
	if quiet: terminal_still_elapsed = minf(TERMINAL_STILL_SECONDS, terminal_still_elapsed + clampf(delta, 0.0, 0.08))
	else: terminal_still_elapsed = 0.0
func can_recast_from_motion() -> bool:
	return state in [State.CAUGHT, State.ESCAPED] and terminal_elapsed >= TERMINAL_RECAST_DWELL_SECONDS and terminal_still_elapsed >= TERMINAL_STILL_SECONDS
func escape(reason: String) -> void: state = State.ESCAPED; last_reason = reason
func reset() -> void: state = State.READY; elapsed = 0.0; bite_elapsed = 0.0; tension = 0.12; strain = 0.0; red_elapsed = 0.0; fight_progress = 0.0; fight_elapsed = 0.0; rod_load = 0.0; cast_quality = 0.0; cast_distance_m = 0.0; catch_length_cm = 0.0; fight_running = false; fight_effort = 0.0; terminal_elapsed = 0.0; terminal_still_elapsed = 0.0; last_reason = ""
