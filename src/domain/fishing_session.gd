class_name FishingSession
extends RefCounted

enum State { READY, CAST_ARMED, LINE_OUT, BITE, HOOK_WINDOW, REELING, CAUGHT, ESCAPED }
const HOOK_WINDOW_SECONDS := 1.8
const BITE_CUE_HOLD_SECONDS := 0.42
const RED_ESCAPE_SECONDS := 1.25
const CATCH_PROGRESS := 1.0
const MIN_CAST_DISTANCE_M := 8.0
const MAX_CAST_DISTANCE_M := 40.0
const MIN_LANDING_SECONDS := 10.0
const FIGHT_PROGRESS_PER_SECOND := 0.145
const RAISED_PRESSURE_PER_SECOND := 0.04
const LOWERING_RELIEF_PER_SECOND := 0.16
var state := State.READY
var fish: FishDefinition = FishDefinition.bluegill()
var location_id := "pine_lake"
var selection_roll := 0.0
var elapsed := 0.0
var bite_elapsed := 0.0
var tension := 0.12
var red_elapsed := 0.0
var fight_progress := 0.0
var fight_elapsed := 0.0
var rod_load := 0.0
var cast_quality := 0.0
var cast_distance_m := 0.0
var catch_length_cm := 0.0
var last_reason := ""
func set_location(value: String, roll: float = 0.0) -> bool:
	if state not in [State.READY, State.CAUGHT, State.ESCAPED] or FishDefinition.for_location(value).is_empty(): return false
	location_id = value; selection_roll = clampf(roll, 0.0, 0.999999); fish = FishDefinition.select_weighted(location_id, selection_roll); return true
func arm_cast() -> bool:
	if state != State.READY: return false
	state = State.CAST_ARMED; return true
func cancel_cast() -> bool:
	if state != State.CAST_ARMED: return false
	state = State.READY; return true
func release_cast(quality: float) -> bool:
	if state != State.CAST_ARMED: return false
	cast_quality = clampf(quality, 0.0, 1.0); cast_distance_m = lerpf(MIN_CAST_DISTANCE_M, MAX_CAST_DISTANCE_M, cast_quality); state = State.LINE_OUT; elapsed = 0.0; return true
func tick(delta: float) -> void:
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
		fight_elapsed += delta; fight_progress = clampf(fight_progress + rod_load * FIGHT_PROGRESS_PER_SECOND * delta, 0.0, CATCH_PROGRESS)
		if fight_progress >= CATCH_PROGRESS and fight_elapsed >= MIN_LANDING_SECONDS:
			state = State.CAUGHT; catch_length_cm = lerpf(fish.min_length_cm, fish.max_length_cm, clampf(0.25 + cast_quality * 0.55 + fight_progress * 0.20, 0.0, 1.0)); last_reason = "%s landed!" % fish.display_name; return
		var surge := fish.fight_strength * delta * (0.07 + sin(fight_elapsed * 3.1) * 0.05); var pressure := rod_load * rod_load * delta * (RAISED_PRESSURE_PER_SECOND + fish.fight_strength * 0.015); var relief := maxf(0.0, 0.45 - rod_load) * delta * LOWERING_RELIEF_PER_SECOND
		tension = clampf(tension + surge + pressure - relief, 0.0, 1.0)
		if tension >= 0.9:
			red_elapsed += delta
			if red_elapsed >= RED_ESCAPE_SECONDS: escape("The line snapped under %s's pull." % fish.display_name)
		else: red_elapsed = maxf(0.0, red_elapsed - delta * 2.0)
func set_hook() -> bool:
	if state != State.HOOK_WINDOW: return false
	state = State.REELING; elapsed = 0.0; fight_elapsed = 0.0; fight_progress = 0.0; rod_load = 1.0; tension = maxf(tension, 0.3); return true
func set_rod_load(value: float) -> void: if state == State.REELING: rod_load = clampf(value, 0.0, 1.0)
func escape(reason: String) -> void: state = State.ESCAPED; last_reason = reason
func reset() -> void: state = State.READY; elapsed = 0.0; bite_elapsed = 0.0; tension = 0.12; red_elapsed = 0.0; fight_progress = 0.0; fight_elapsed = 0.0; rod_load = 0.0; cast_quality = 0.0; cast_distance_m = 0.0; catch_length_cm = 0.0; last_reason = ""
