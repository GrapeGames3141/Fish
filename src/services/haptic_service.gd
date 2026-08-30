class_name HapticService
extends RefCounted

## Deterministic, injectable haptic scheduler. A fight phrase is scheduled only
## once per fish cadence, leaving a deliberate quiet gap between phrases.
const HIGH_TENSION := 0.65
const RED_TENSION := 0.90
const MAX_PENDING_PULSES := 3
const INITIAL_FIGHT_DELAY_SECONDS := 0.22
const HIGH_WARNING_CYCLE_SECONDS := 0.8
const RED_WARNING_CYCLE_SECONDS := 0.5

var enabled := true
var emitter: Callable
var pending: Array[Dictionary] = []
var elapsed := 0.0
var fighting := false
var active_fish: FishDefinition
var next_phrase_at := 0.0
var warning_tier := "normal"
var phrase_started := false

func _init(custom_emitter: Callable = Callable()) -> void:
	emitter = custom_emitter

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop()

func cue(name: String) -> void:
	if not enabled:
		return
	if name == "caught" or name == "escaped":
		stop()
	var pattern: Array[Dictionary] = []
	if name == "bite":
		pattern = [{"duration": 70, "amplitude": 0.85}, {"duration": 105, "amplitude": 0.95, "gap": 0.17}]
	elif name == "hook":
		pattern = [{"duration": 55, "amplitude": 0.6}]
	elif name == "caught":
		pattern = [{"duration": 45, "amplitude": 0.5}, {"duration": 75, "amplitude": 0.75, "gap": 0.1}, {"duration": 120, "amplitude": 0.95, "gap": 0.1}]
	elif name == "escaped":
		pattern = [{"duration": 170, "amplitude": 0.3}]
	_schedule_phrase(pattern)

func start_fight(fish: FishDefinition) -> void:
	if not enabled or fish == null:
		return
	fighting = true
	active_fish = fish
	warning_tier = "normal"
	phrase_started = false
	next_phrase_at = elapsed + INITIAL_FIGHT_DELAY_SECONDS

func update_fight(delta: float, fish: FishDefinition, tension: float) -> void:
	tick(delta)
	if not enabled or not fighting or fish == null:
		return
	active_fish = fish
	var next_tier := _tier_for_tension(tension)
	if next_tier != warning_tier:
		warning_tier = next_tier
		pending.clear()
		if phrase_started:
			next_phrase_at = elapsed
	if elapsed >= next_phrase_at and pending.is_empty():
		_schedule_phrase(_phrase_for_tier(warning_tier))
		phrase_started = true
		next_phrase_at = elapsed + _cycle_for_tier(warning_tier)
	_dispatch_due()

func tick(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	if not enabled:
		pending.clear()
		return
	_dispatch_due()

func stop() -> void:
	pending.clear()
	fighting = false
	active_fish = null
	warning_tier = "normal"
	phrase_started = false
	next_phrase_at = elapsed

func _tier_for_tension(tension: float) -> String:
	if tension >= RED_TENSION:
		return "red"
	if tension >= HIGH_TENSION:
		return "high"
	return "normal"

func _phrase_for_tier(tier: String) -> Array[Dictionary]:
	if tier == "red":
		return [{"duration": 90, "amplitude": 1.0}, {"duration": 90, "amplitude": 1.0, "gap": 0.16}]
	if tier == "high":
		return [{"duration": 58, "amplitude": 0.85}, {"duration": 58, "amplitude": 0.85, "gap": 0.22}]
	return active_fish.fight_pulse if active_fish != null else []

func _cycle_for_tier(tier: String) -> float:
	if tier == "red":
		return RED_WARNING_CYCLE_SECONDS
	if tier == "high":
		return HIGH_WARNING_CYCLE_SECONDS
	return active_fish.fight_cycle_seconds if active_fish != null else HIGH_WARNING_CYCLE_SECONDS

func _schedule_phrase(pattern: Array[Dictionary]) -> void:
	if not enabled or pattern.is_empty():
		return
	pending.clear()
	var at := elapsed
	for pulse in pattern:
		if pending.size() >= MAX_PENDING_PULSES:
			break
		at += float(pulse.get("gap", 0.0))
		pending.append({"at": at, "duration": int(pulse.duration), "amplitude": float(pulse.amplitude)})
		at += float(pulse.duration) / 1000.0

func _dispatch_due() -> void:
	while not pending.is_empty() and float(pending[0].at) <= elapsed:
		var pulse: Dictionary = pending.pop_front()
		if emitter.is_valid():
			emitter.call(int(pulse.duration), float(pulse.amplitude))
		else:
			Input.vibrate_handheld(int(pulse.duration), float(pulse.amplitude))
