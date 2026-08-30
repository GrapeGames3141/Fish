class_name FishingSession
extends RefCounted

enum State { READY, CAST_ARMED, LINE_OUT, BITE, HOOK_WINDOW, REELING, CAUGHT, ESCAPED }

const HOOK_WINDOW_SECONDS := 1.5
const RED_ESCAPE_SECONDS := 1.25
const CATCH_PROGRESS := 1.0
const MIN_CAST_DISTANCE_M := 8.0
const MAX_CAST_DISTANCE_M := 40.0
const MIN_LANDING_SECONDS := 10.0
const PULL_PROGRESS := 0.12

var state: int = State.READY
var fish: FishDefinition = FishDefinition.bluegill()
var elapsed: float = 0.0
var bite_elapsed: float = 0.0
var tension: float = 0.12
var red_elapsed: float = 0.0
var fight_progress: float = 0.0
var fight_elapsed: float = 0.0
var rod_load: float = 0.0
var lower_ready := false
var cast_quality: float = 0.0
var cast_distance_m: float = 0.0
var last_reason: String = ""

func arm_cast() -> bool:
	if state != State.READY:
		return false
	state = State.CAST_ARMED
	return true

func release_cast(quality: float) -> bool:
	if state != State.CAST_ARMED:
		return false
	cast_quality = clampf(quality, 0.0, 1.0)
	cast_distance_m = lerpf(MIN_CAST_DISTANCE_M, MAX_CAST_DISTANCE_M, cast_quality)
	state = State.LINE_OUT
	elapsed = 0.0
	return true

func tick(delta: float) -> void:
	if state == State.LINE_OUT:
		elapsed += delta
		if elapsed >= fish.bite_delay_seconds:
			state = State.BITE
			bite_elapsed = 0.0
	elif state == State.BITE:
		state = State.HOOK_WINDOW
		bite_elapsed = 0.0
	elif state == State.HOOK_WINDOW:
		bite_elapsed += delta
		if bite_elapsed > HOOK_WINDOW_SECONDS:
			escape("The fish spit the hook.")
	elif state == State.REELING:
		fight_elapsed += delta
		var surge := fish.fight_strength * delta * (0.24 + sin(fight_elapsed * 3.1) * 0.16)
		var raised_pressure := maxf(0.0, rod_load - 0.35) * delta * 0.16
		var lowering_relief := maxf(0.0, 0.42 - rod_load) * delta * 0.34
		tension = clampf(tension + surge + raised_pressure - lowering_relief, 0.0, 1.0)
		elapsed += delta
		if tension >= 0.9:
			red_elapsed += delta
			if red_elapsed >= RED_ESCAPE_SECONDS:
				escape("Line snapped under too much tension.")
		else:
			red_elapsed = maxf(0.0, red_elapsed - delta * 2.0)

func set_hook() -> bool:
	if state != State.HOOK_WINDOW:
		return false
	state = State.REELING
	elapsed = 0.0
	fight_elapsed = 0.0
	fight_progress = 0.0
	rod_load = 1.0
	lower_ready = false
	tension = maxf(tension, 0.3)
	return true

func set_rod_load(value: float) -> void:
	if state == State.REELING:
		rod_load = clampf(value, 0.0, 1.0)

func lower_rod() -> bool:
	if state != State.REELING:
		return false
	lower_ready = true
	rod_load = 0.0
	tension = maxf(0.0, tension - 0.045)
	return true

func complete_pull() -> bool:
	if state != State.REELING or not lower_ready:
		return false
	lower_ready = false
	rod_load = 1.0
	fight_progress = clampf(fight_progress + PULL_PROGRESS, 0.0, CATCH_PROGRESS)
	if fight_progress >= CATCH_PROGRESS and fight_elapsed >= MIN_LANDING_SECONDS:
		state = State.CAUGHT
		last_reason = "Bluegill landed!"
	return true

func escape(reason: String) -> void:
	state = State.ESCAPED
	last_reason = reason

func reset() -> void:
	state = State.READY
	elapsed = 0.0
	bite_elapsed = 0.0
	tension = 0.12
	red_elapsed = 0.0
	fight_progress = 0.0
	fight_elapsed = 0.0
	rod_load = 0.0
	lower_ready = false
	cast_quality = 0.0
	cast_distance_m = 0.0
	last_reason = ""
