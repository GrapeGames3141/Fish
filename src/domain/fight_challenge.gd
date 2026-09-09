class_name FightChallenge
extends RefCounted

## One source of truth for the fight's visible danger bands, timing and haptics.
## The selected profile is snapped into FishingSession at the start of a cast so
## changing Settings cannot make an already-hooked fish easier halfway through.
const IDS := ["relaxed", "standard", "expert"]
const DEFAULT_ID := "standard"

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
		"relaxed": return {"id": "relaxed", "low_critical": 0.08, "low_warning": 0.22, "high_warning": 0.78, "high_critical": 0.92, "danger_seconds": 1.20, "slack_seconds": 2.00, "startup_grace": 1.15}
		"expert": return {"id": "expert", "low_critical": 0.18, "low_warning": 0.34, "high_warning": 0.66, "high_critical": 0.82, "danger_seconds": 0.72, "slack_seconds": 1.20, "startup_grace": 0.82}
	return {"id": "standard", "low_critical": 0.12, "low_warning": 0.28, "high_warning": 0.72, "high_critical": 0.88, "danger_seconds": 0.90, "slack_seconds": 1.65, "startup_grace": 1.00}

static func tier(tension: float, profile_data: Dictionary) -> String:
	var value := clampf(tension, 0.0, 1.0)
	if value <= float(profile_data.low_critical): return "slack"
	if value < float(profile_data.low_warning): return "pull"
	if value >= float(profile_data.high_critical): return "snap"
	if value > float(profile_data.high_warning): return "ease"
	return "steady"

static func center_reward(tension: float, profile_data: Dictionary) -> float:
	# Keep the actual best work around the middle, while allowing a generous green
	# zone for ordinary phone motion. This never rewards either red end.
	var distance := absf(clampf(tension, 0.0, 1.0) - 0.50) / 0.50
	# A centered rod is clearly best, not a razor-thin perfect pose. The danger
	# bands and strain still punish held extremes; this gentle slope keeps a
	# delayed human correction viable across all fish.
	return clampf(1.38 - distance * 0.55, 0.30, 1.38)
