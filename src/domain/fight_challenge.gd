class_name FightChallenge
extends RefCounted

## One source of truth for the fight's visible danger bands, timing and haptics.
## The selected profile is snapped into FishingSession at the start of a cast so
## changing Settings cannot make an already-hooked fish easier halfway through.
const IDS := ["relaxed", "standard", "expert"]
const DEFAULT_ID := "standard"
const MIN_WARNING_BUFFER := 0.085
const MIN_GREEN_WIDTH := 0.24

static func sanitize(value: Variant) -> String:
	var id := str(value).to_lower()
	return id if id in IDS else DEFAULT_ID

static func display_name(value: Variant) -> String:
	match sanitize(value):
		"relaxed": return "RELAXED"
		"expert": return "EXPERT"
	return "STANDARD"

static func profile(value: Variant) -> Dictionary:
	match sanitize(value):
		"relaxed": return {"id": "relaxed", "target_center": 0.50, "dynamic_intensity": 0.0, "low_critical": 0.08, "low_warning": 0.22, "high_warning": 0.78, "high_critical": 0.92, "danger_seconds": 1.20, "slack_seconds": 2.00, "startup_grace": 1.15}
		"expert": return {"id": "expert", "target_center": 0.50, "dynamic_intensity": 0.0, "low_critical": 0.18, "low_warning": 0.34, "high_warning": 0.66, "high_critical": 0.82, "danger_seconds": 0.72, "slack_seconds": 1.20, "startup_grace": 0.82}
	return {"id": "standard", "target_center": 0.50, "dynamic_intensity": 0.0, "low_critical": 0.12, "low_warning": 0.28, "high_warning": 0.72, "high_critical": 0.88, "danger_seconds": 0.90, "slack_seconds": 1.65, "startup_grace": 1.00}

static func dynamic_profile(base_profile: Dictionary, fish_strength: float, relative_size: float, behavior: float, fight_seconds: float) -> Dictionary:
	# This is deliberately analytical rather than random. A cast's base profile is
	# never changed; its live copy has a readable multi-second drift that the meter,
	# reward, red dwell checks, and haptic warning tier can all share.
	var result := base_profile.duplicate(true)
	var challenge_scale: float = float({"relaxed": 0.45, "standard": 0.75, "expert": 1.0}.get(str(base_profile.get("id", DEFAULT_ID)), 0.75))
	var strength_factor := clampf((fish_strength - 0.45) / 0.55, 0.0, 1.0)
	var size_factor := clampf((relative_size - 0.62) / 0.38, 0.0, 1.0)
	var intensity := clampf((strength_factor * 0.68 + size_factor * 0.32) * float(challenge_scale), 0.0, 1.0)
	if intensity <= 0.0001:
		result["dynamic_intensity"] = 0.0
		return result
	var phase_seed := clampf(behavior, 0.0, 0.999999) * TAU
	var drift_phase := fight_seconds * TAU / 7.2 + phase_seed
	var width_phase := fight_seconds * TAU / 5.8 + phase_seed * 0.61
	var red_phase := fight_seconds * TAU / 6.6 + phase_seed * 1.37
	var base_center := float(base_profile.get("target_center", 0.50))
	var center := base_center + sin(drift_phase) * (0.045 * intensity)
	var base_green_width := float(base_profile.high_warning) - float(base_profile.low_warning)
	# Strong, upper-tail fish mechanically shrink the green zone by 6–10 absolute
	# percentage points. The lower floor keeps the 300ms human response playable.
	var narrowing := (0.06 + 0.04 * (0.5 + 0.5 * sin(width_phase))) * intensity
	var green_width := maxf(MIN_GREEN_WIDTH, base_green_width - narrowing)
	var low_warning := center - green_width * 0.5
	var high_warning := center + green_width * 0.5
	# A shared slow breath moves both critical edges. Positive breath makes both red
	# ends grow; negative breath gives a little relief. It never consumes warnings.
	var red_breath := sin(red_phase) * (0.025 * intensity)
	var low_buffer := maxf(MIN_WARNING_BUFFER, float(base_profile.low_warning) - float(base_profile.low_critical) - 0.015 * intensity - red_breath)
	var high_buffer := maxf(MIN_WARNING_BUFFER, float(base_profile.high_critical) - float(base_profile.high_warning) - 0.015 * intensity - red_breath)
	result["target_center"] = center
	result["low_warning"] = low_warning
	result["high_warning"] = high_warning
	result["low_critical"] = low_warning - low_buffer
	result["high_critical"] = high_warning + high_buffer
	result["dynamic_intensity"] = intensity
	return result

static func blend_profile(base_profile: Dictionary, dynamic: Dictionary, weight: float) -> Dictionary:
	var result := base_profile.duplicate(true)
	var blend := clampf(weight, 0.0, 1.0)
	for field in ["target_center", "low_critical", "low_warning", "high_warning", "high_critical", "dynamic_intensity"]:
		result[field] = lerpf(float(base_profile.get(field, 0.0)), float(dynamic.get(field, base_profile.get(field, 0.0))), blend)
	return result

static func has_ordered_bounds(profile_data: Dictionary) -> bool:
	return float(profile_data.low_critical) > 0.0 and float(profile_data.low_critical) < float(profile_data.low_warning) and float(profile_data.low_warning) < float(profile_data.get("target_center", 0.50)) and float(profile_data.get("target_center", 0.50)) < float(profile_data.high_warning) and float(profile_data.high_warning) < float(profile_data.high_critical) and float(profile_data.high_critical) < 1.0

static func tier(tension: float, profile_data: Dictionary) -> String:
	var value := clampf(tension, 0.0, 1.0)
	if value <= float(profile_data.low_critical): return "slack"
	if value < float(profile_data.low_warning): return "pull"
	if value >= float(profile_data.high_critical): return "snap"
	if value > float(profile_data.high_warning): return "ease"
	return "steady"

static func center_reward(tension: float, profile_data: Dictionary) -> float:
	# The true live center is best. A narrower live green zone has a modestly
	# sharper falloff, but remains forgiving enough for the delayed motion policy.
	var center := float(profile_data.get("target_center", 0.50))
	var half_green := maxf(0.01, (float(profile_data.high_warning) - float(profile_data.low_warning)) * 0.5)
	var distance := absf(clampf(tension, 0.0, 1.0) - center) / half_green
	return clampf(1.38 - distance * 0.24, 0.30, 1.38)
