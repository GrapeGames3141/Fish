class_name HapticService
extends RefCounted

const FightChallenge = preload("res://src/domain/fight_challenge.gd")

## Deterministic, injectable haptic scheduler. A fight phrase is scheduled only
## once per fish cadence, leaving a deliberate quiet gap between phrases.
const MAX_PENDING_PULSES := 3
const INITIAL_FIGHT_DELAY_SECONDS := 0.22
const HIGH_WARNING_CYCLE_SECONDS := 0.8
const RED_WARNING_CYCLE_SECONDS := 0.5
const MOTION_SETTLE_SECONDS := 0.30

static func standard_high_tension() -> float: return float(FightChallenge.profile(FightChallenge.DEFAULT_ID).high_warning)
static func standard_red_tension() -> float: return float(FightChallenge.profile(FightChallenge.DEFAULT_ID).high_critical)

var enabled := true
var emitter: Callable
var pending: Array[Dictionary] = []
var elapsed := 0.0
var fighting := false
var active_fish: FishDefinition
var next_phrase_at := 0.0
var warning_tier := "steady"
var active_profile: Dictionary = FightChallenge.profile(FightChallenge.DEFAULT_ID)
var phrase_started := false
var _motion_guard_remaining := 0.0
var _android_vibrator = null
var _android_vibration_effect = null
var _android_vibrator_checked := false
var _android_sdk_int := -1
var _android_vibration_attributes = null
var _android_audio_attributes = null

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
	elif name == "hook_miss":
		pattern = [{"duration": 34, "amplitude": 0.28}, {"duration": 34, "amplitude": 0.24, "gap": 0.12}]
	elif name == "calibration_tick" or name == "cock":
		pattern = [{"duration": 22, "amplitude": 0.24}]
	elif name == "capture_countdown":
		pattern = [{"duration": 20, "amplitude": 0.22}]
	elif name == "capture_window":
		pattern = [{"duration": 32, "amplitude": 0.38}, {"duration": 42, "amplitude": 0.50, "gap": 0.10}]
	elif name == "capture_complete":
		pattern = [{"duration": 38, "amplitude": 0.42}, {"duration": 58, "amplitude": 0.60, "gap": 0.10}, {"duration": 78, "amplitude": 0.78, "gap": 0.10}]
	elif name == "caught":
		pattern = [{"duration": 45, "amplitude": 0.5}, {"duration": 75, "amplitude": 0.75, "gap": 0.1}, {"duration": 120, "amplitude": 0.95, "gap": 0.1}]
	elif name == "escaped":
		pattern = [{"duration": 170, "amplitude": 0.3}]
	_schedule_phrase(pattern)

func start_fight(fish: FishDefinition, profile_data: Dictionary = {}) -> void:
	if not enabled or fish == null:
		return
	fighting = true
	active_fish = fish
	active_profile = profile_data.duplicate(true) if not profile_data.is_empty() else FightChallenge.profile(FightChallenge.DEFAULT_ID)
	warning_tier = "steady"
	phrase_started = false
	next_phrase_at = elapsed + INITIAL_FIGHT_DELAY_SECONDS

func update_fight(delta: float, fish: FishDefinition, tension: float, effort := 1.0, size_factor := 1.0, profile_data: Dictionary = {}) -> void:
	# Decide lull/warning priority before dispatching any overdue normal pulse.
	elapsed += maxf(delta, 0.0)
	_motion_guard_remaining = maxf(0.0, _motion_guard_remaining - maxf(delta, 0.0))
	if not enabled or not fighting or fish == null:
		if not enabled: pending.clear()
		return
	active_fish = fish
	if not profile_data.is_empty(): active_profile = profile_data
	var next_tier := _tier_for_tension(tension)
	if next_tier != warning_tier:
		warning_tier = next_tier
		pending.clear()
		if phrase_started:
			next_phrase_at = elapsed
	# Fish lulls are intentionally quiet. The universal high/red warnings remain
	# immediate so a player can learn one relief cue by feel across all species.
	if warning_tier == "steady" and effort < 0.42:
		# A run can end between pulses. Those normal-effort fish pulses describe
		# the run, so never replay an overdue phrase when it resumes. High/red
		# warnings are deliberately outside this branch and remain immediate.
		pending.clear()
		next_phrase_at = maxf(next_phrase_at, elapsed + 0.08)
		return
	if elapsed >= next_phrase_at and pending.is_empty():
		_schedule_phrase(_phrase_for_tier(warning_tier, effort, size_factor))
		phrase_started = true
		next_phrase_at = elapsed + _cycle_for_tier(warning_tier)
	_dispatch_due()

func tick(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	_motion_guard_remaining = maxf(0.0, _motion_guard_remaining - maxf(delta, 0.0))
	if not enabled:
		pending.clear()
		_motion_guard_remaining = 0.0
		return
	_dispatch_due()

func is_motion_guarded() -> bool:
	return _motion_guard_remaining > 0.0

func motion_guard_seconds() -> float:
	return _motion_guard_remaining

func stop() -> void:
	pending.clear()
	_motion_guard_remaining = 0.0
	fighting = false
	active_fish = null
	warning_tier = "steady"
	phrase_started = false
	next_phrase_at = elapsed

func _tier_for_tension(tension: float) -> String:
	return FightChallenge.tier(tension, active_profile)

func _phrase_for_tier(tier: String, effort := 1.0, size_factor := 1.0) -> Array[Dictionary]:
	# Slack is deliberately a slow long pulse + tiny tap; overload remains the
	# fast paired warning. With eyes on the water a player can tell which way to
	# move without looking at the meter.
	if tier == "snap":
		return [{"duration": 90, "amplitude": 1.0}, {"duration": 90, "amplitude": 1.0, "gap": 0.16}]
	if tier == "ease":
		return [{"duration": 58, "amplitude": 0.85}, {"duration": 58, "amplitude": 0.85, "gap": 0.22}]
	if tier == "slack":
		return [{"duration": 145, "amplitude": 0.66}, {"duration": 30, "amplitude": 0.35, "gap": 0.28}]
	if tier == "pull":
		return [{"duration": 90, "amplitude": 0.52}, {"duration": 24, "amplitude": 0.30, "gap": 0.34}]
	if active_fish == null: return []
	# Species phrases stay recognizable (flutter / punch / heavy pull / triplet /
	# double headshake / abrupt run), while larger or active-stage fish add only a
	# mild physical weight rather than collapsing every cadence into one warning.
	var weighted: Array[Dictionary] = []
	var amplitude_scale := clampf(0.90 + maxf(0.0, effort - 0.22) * 0.10 + maxf(0.0, size_factor - 1.0) * 0.20, 0.90, 1.10)
	for pulse in active_fish.fight_pulse:
		weighted.append({"duration": int(pulse.duration), "amplitude": clampf(float(pulse.amplitude) * amplitude_scale, 0.05, 1.0), "gap": float(pulse.get("gap", 0.0))})
	return weighted

func _cycle_for_tier(tier: String) -> float:
	if tier == "snap":
		return RED_WARNING_CYCLE_SECONDS
	if tier == "ease":
		return HIGH_WARNING_CYCLE_SECONDS
	if tier == "slack":
		return 0.76
	if tier == "pull":
		return 1.05
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
		_motion_guard_remaining = maxf(_motion_guard_remaining, float(pulse.duration) / 1000.0 + MOTION_SETTLE_SECONDS)
		if emitter.is_valid():
			emitter.call(int(pulse.duration), float(pulse.amplitude))
		elif not _try_android_vibrate(int(pulse.duration), float(pulse.amplitude)):
			Input.vibrate_handheld(int(pulse.duration), float(pulse.amplitude))

static func android_amplitude(amplitude: float) -> int:
	return clampi(roundi(clampf(amplitude, 0.0, 1.0) * 255.0), 1, 255)

func _try_android_vibrate(duration_ms: int, amplitude: float) -> bool:
	if OS.get_name() != "Android":
		return false
	if not _android_vibrator_checked:
		_android_vibrator_checked = true
		var android_runtime = Engine.get_singleton("AndroidRuntime")
		if android_runtime == null:
			return false
		var context = android_runtime.getApplicationContext()
		if context == null:
			return false
		_android_vibrator = context.getSystemService("vibrator")
		if _android_vibrator == null or not _android_vibrator.hasVibrator():
			_android_vibrator = null
			return false
		var build_version = JavaClassWrapper.wrap("android.os.Build$VERSION")
		if build_version == null:
			_android_vibrator = null
			return false
		_android_sdk_int = int(build_version.SDK_INT)
		if _android_sdk_int >= 26:
			_android_vibration_effect = JavaClassWrapper.wrap("android.os.VibrationEffect")
		if _android_sdk_int >= 33:
			_android_vibration_attributes = _create_vibration_attributes()
		elif _android_sdk_int >= 24:
			_android_audio_attributes = _create_audio_attributes()
	if _android_vibrator == null or _android_sdk_int < 0:
		return false
	if _android_sdk_int >= 26:
		if _android_vibration_effect == null:
			return false
		var effect = _android_vibration_effect.createOneShot(maxi(1, duration_ms), android_amplitude(amplitude))
		if _android_sdk_int >= 33 and _android_vibration_attributes != null:
			_android_vibrator.vibrate(effect, _android_vibration_attributes)
		elif _android_sdk_int >= 24 and _android_audio_attributes != null:
			_android_vibrator.vibrate(effect, _android_audio_attributes)
		else:
			_android_vibrator.vibrate(effect)
	else:
		if _android_audio_attributes != null:
			_android_vibrator.vibrate(maxi(1, duration_ms), _android_audio_attributes)
		else:
			_android_vibrator.vibrate(maxi(1, duration_ms))
	return true

func _create_vibration_attributes():
	var attributes_class = JavaClassWrapper.wrap("android.os.VibrationAttributes")
	if attributes_class == null:
		return null
	var attributes = attributes_class.createForUsage(attributes_class.USAGE_MEDIA)
	if JavaClassWrapper.get_exception() != null:
		return null
	return attributes

func _create_audio_attributes():
	var attributes_class = JavaClassWrapper.wrap("android.media.AudioAttributes")
	var builder_class = JavaClassWrapper.wrap("android.media.AudioAttributes$Builder")
	if attributes_class == null or builder_class == null:
		return null
	var builder = builder_class.Builder()
	if builder == null:
		return null
	var attributes = builder.setUsage(attributes_class.USAGE_GAME).setContentType(attributes_class.CONTENT_TYPE_SONIFICATION).build()
	if JavaClassWrapper.get_exception() != null:
		return null
	return attributes
