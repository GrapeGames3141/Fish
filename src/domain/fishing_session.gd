class_name FishingSession
extends RefCounted

enum State { READY, CAST_ARMED, LINE_OUT, BITE, HOOK_WINDOW, REELING, CAUGHT, ESCAPED }

const HOOK_WINDOW_SECONDS := 1.5
const RED_ESCAPE_SECONDS := 1.25
const CATCH_PROGRESS := 1.0

var state: int = State.READY
var fish: FishDefinition = FishDefinition.bluegill()
var elapsed: float = 0.0
var bite_elapsed: float = 0.0
var tension: float = 0.12
var red_elapsed: float = 0.0
var reel_progress: float = 0.0
var cast_quality: float = 0.0
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
		var surge := fish.fight_strength * delta * (0.42 + sin(elapsed * 3.1) * 0.25)
		tension = clampf(tension + surge - delta * 0.075, 0.0, 1.0)
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
	tension = maxf(tension, 0.3)
	return true

func add_reel_turns(clockwise_turns: float, delta: float) -> bool:
	if state != State.REELING or clockwise_turns <= 0.0:
		return false
	var speed := clockwise_turns / maxf(delta, 0.01)
	reel_progress = clampf(reel_progress + clockwise_turns * 0.25, 0.0, CATCH_PROGRESS)
	tension = clampf(tension + clockwise_turns * 0.17 + maxf(0.0, speed - 2.2) * 0.04, 0.0, 1.0)
	if reel_progress >= CATCH_PROGRESS:
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
	reel_progress = 0.0
	cast_quality = 0.0
	last_reason = ""
