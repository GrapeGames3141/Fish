class_name HapticService
extends RefCounted

var enabled := true
var emitter: Callable
var pending: Array[Dictionary] = []
var elapsed := 0.0
var warning_active := false

func _init(custom_emitter: Callable = Callable()) -> void:
	emitter = custom_emitter

func enqueue(cue: String, fish: FishDefinition = null, tension: float = 0.0) -> void:
	if not enabled: return
	if tension >= 0.9 and cue == "fight":
		warning_active = true; pending = [{"at": elapsed, "duration": 90, "amplitude": 1.0}, {"at": elapsed + 0.16, "duration": 90, "amplitude": 1.0}]; return
	var pattern: Array[Dictionary] = []
	if cue == "bite": pattern = [{"duration": 70, "amplitude": 0.85}, {"duration": 105, "amplitude": 0.95, "gap": 0.17}]
	elif cue == "hook": pattern = [{"duration": 55, "amplitude": 0.6}]
	elif cue == "fight" and fish != null: pattern = fish.fight_pulse
	elif cue == "caught": pattern = [{"duration": 45, "amplitude": 0.5}, {"duration": 75, "amplitude": 0.75, "gap": 0.1}, {"duration": 120, "amplitude": 0.95, "gap": 0.1}]
	elif cue == "escaped": pattern = [{"duration": 170, "amplitude": 0.3}]
	var at := elapsed
	for pulse in pattern:
		at += float(pulse.get("gap", 0.0)); pending.append({"at": at, "duration": int(pulse.duration), "amplitude": float(pulse.amplitude)}); at += float(pulse.duration) / 1000.0

func tick(delta: float) -> void:
	elapsed += delta
	while not pending.is_empty() and float(pending[0].at) <= elapsed:
		var pulse: Dictionary = pending.pop_front()
		if emitter.is_valid(): emitter.call(int(pulse.duration), float(pulse.amplitude))
		else: Input.vibrate_handheld(int(pulse.duration), float(pulse.amplitude))

func stop() -> void:
	pending.clear(); warning_active = false
