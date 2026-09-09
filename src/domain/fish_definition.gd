class_name FishDefinition
extends RefCounted

var id := "bluegill"
var display_name := "Bluegill"
var location_id := "pine_lake"
var rarity := 1.0
var min_length_cm := 14.0
var max_length_cm := 31.0
var fight_strength := 0.32
var bite_delay_seconds := 2.4
var fight_pulse: Array[Dictionary] = [{"duration": 42, "amplitude": 0.35}, {"duration": 72, "amplitude": 0.6, "gap": 0.12}]
var fight_cycle_seconds := 1.4
## Per-species fight cadence. Values are deliberately data-only so deterministic
## replays can inject a behavior roll without reaching into UI code.
var run_seconds := 0.82
var lull_seconds := 0.72
var run_pressure := 0.16
var strain_rate := 0.22
var recovery_rate := 0.46
var pull_efficiency := 0.17
var habitat_near := 1.0
var habitat_mid := 1.0
var habitat_far := 1.0

static func bluegill() -> FishDefinition:
	return make("bluegill", "Bluegill", "pine_lake", 4.2, 14.0, 31.0, 0.32, 2.4, [{"duration": 38, "amplitude": 0.30}, {"duration": 62, "amplitude": 0.58, "gap": 0.12}], 1.40, [0.48, 0.92, 0.10, 0.18, 0.58, 0.30, 1.65, 1.05, 0.55])

static func all_planned() -> Array[FishDefinition]:
	return [make("pumpkinseed", "Pumpkinseed", "willow_pond", 3.4, 12.0, 25.0, 0.28, 2.0, [{"duration": 24, "amplitude": 0.28}, {"duration": 30, "amplitude": 0.38, "gap": 0.10}], 0.72, [0.40, 0.95, 0.08, 0.14, 0.62, 0.25, 1.4, 1.1, 0.8]), make("black_crappie", "Black Crappie", "willow_pond", 2.8, 18.0, 36.0, 0.38, 2.4, [{"duration": 28, "amplitude": 0.42}, {"duration": 28, "amplitude": 0.42, "gap": 0.08}, {"duration": 28, "amplitude": 0.42, "gap": 0.08}], 0.84, [0.56, 0.80, 0.12, 0.18, 0.55, 0.29, 1.1, 1.5, 0.7]), make("brown_bullhead", "Brown Bullhead", "willow_pond", 2.2, 24.0, 44.0, 0.47, 2.8, [{"duration": 90, "amplitude": 0.48}], 1.35, [0.72, 0.70, 0.14, 0.22, 0.48, 0.34, 1.0, 0.9, 1.35]), bluegill(), make("largemouth_bass", "Largemouth Bass", "pine_lake", 2.1, 28.0, 61.0, 0.58, 2.9, [{"duration": 92, "amplitude": 0.78}, {"duration": 36, "amplitude": 0.45, "gap": 0.18}], 1.15, [1.20, 0.70, 0.18, 0.28, 0.40, 0.31, 1.35, 1.20, 0.80]), make("channel_catfish", "Channel Catfish", "pine_lake", 1.2, 32.0, 76.0, 0.70, 3.4, [{"duration": 140, "amplitude": 0.68}], 1.80, [1.55, 0.45, 0.16, 0.31, 0.30, 0.52, 0.65, 0.95, 1.55]), make("rainbow_trout", "Rainbow Trout", "cedar_river", 3.6, 23.0, 53.0, 0.46, 2.1, [{"duration": 30, "amplitude": 0.48}, {"duration": 30, "amplitude": 0.48, "gap": 0.09}, {"duration": 30, "amplitude": 0.48, "gap": 0.09}], 0.90, [0.42, 0.62, 0.20, 0.23, 0.60, 0.30, 1.45, 1.15, 0.65]), make("smallmouth_bass", "Smallmouth Bass", "cedar_river", 2.2, 24.0, 52.0, 0.63, 2.6, [{"duration": 58, "amplitude": 0.82}, {"duration": 86, "amplitude": 0.50, "gap": 0.15}], 1.05, [0.86, 0.62, 0.20, 0.29, 0.44, 0.31, 0.80, 1.30, 1.10]), make("northern_pike", "Northern Pike", "cedar_river", 0.9, 46.0, 103.0, 0.88, 3.7, [{"duration": 150, "amplitude": 1.0}, {"duration": 55, "amplitude": 0.72, "gap": 0.16}], 0.72, [1.05, 0.48, 0.30, 0.39, 0.34, 0.72, 0.35, 0.85, 1.80]), make("red_drum", "Red Drum", "hatteras_inlet", 2.5, 40.0, 86.0, 0.82, 3.0, [{"duration": 120, "amplitude": 0.92}, {"duration": 70, "amplitude": 0.70, "gap": 0.16}], 1.10, [1.10, 0.55, 0.28, 0.36, 0.36, 0.58, 0.9, 1.2, 1.35]), make("spotted_seatrout", "Spotted Seatrout", "hatteras_inlet", 3.0, 28.0, 58.0, 0.60, 2.2, [{"duration": 24, "amplitude": 0.58}, {"duration": 24, "amplitude": 0.58, "gap": 0.07}], 0.68, [0.50, 0.68, 0.20, 0.26, 0.52, 0.36, 1.25, 1.1, 0.85]), make("bluefish", "Bluefish", "hatteras_inlet", 2.1, 35.0, 74.0, 0.76, 2.5, [{"duration": 36, "amplitude": 0.86}, {"duration": 36, "amplitude": 0.86, "gap": 0.06}, {"duration": 36, "amplitude": 0.86, "gap": 0.06}], 0.58, [0.90, 0.42, 0.32, 0.38, 0.34, 0.62, 1.0, 1.2, 1.15])]

static func for_location(location: String) -> Array[FishDefinition]:
	var result: Array[FishDefinition] = []
	for fish in all_planned():
		if fish.location_id == location: result.append(fish)
	return result

static func select_weighted(location: String, roll: float, distance_m := -1.0) -> FishDefinition:
	var candidates := for_location(location)
	if candidates.is_empty(): return bluegill()
	var total := 0.0
	for fish in candidates: total += fish.rarity * fish.habitat_weight(distance_m)
	var target := clampf(roll, 0.0, 0.999999) * total
	for fish in candidates:
		target -= fish.rarity * fish.habitat_weight(distance_m)
		if target <= 0.0: return fish
	return candidates.back()

func habitat_weight(distance_m: float) -> float:
	if distance_m < 0.0: return 1.0
	if distance_m < 18.0: return habitat_near
	if distance_m < 30.0: return habitat_mid
	return habitat_far

func habitat_name(distance_m: float) -> String:
	if location_id == "willow_pond":
		if distance_m < 18.0: return "LILY SHADE"
		if distance_m < 30.0: return "POND EDGE"
		return "MUDDY DROP"
	if location_id == "cedar_river":
		if distance_m < 18.0: return "NEAR EDDY"
		if distance_m < 30.0: return "CURRENT SEAM"
		return "DEEP RUN"
	if location_id == "hatteras_inlet":
		if distance_m < 18.0: return "FOAM LINE"
		if distance_m < 30.0: return "TIDAL SEAM"
		return "OUTER CHANNEL"
	if distance_m < 18.0: return "REED EDGE"
	if distance_m < 30.0: return "OPEN POCKET"
	return "OUTER COVER"

static func make(fish_id: String, name: String, location: String, weight: float, min_size: float, max_size: float, strength: float, delay: float, pulse: Array[Dictionary], cycle: float, behavior: Array[float] = []) -> FishDefinition:
	var fish := FishDefinition.new()
	fish.id = fish_id; fish.display_name = name; fish.location_id = location; fish.rarity = weight
	fish.min_length_cm = min_size; fish.max_length_cm = max_size; fish.fight_strength = strength; fish.bite_delay_seconds = delay
	fish.fight_pulse = pulse; fish.fight_cycle_seconds = cycle
	if behavior.size() == 9:
		fish.run_seconds = behavior[0]; fish.lull_seconds = behavior[1]; fish.run_pressure = behavior[2]; fish.strain_rate = behavior[3]; fish.recovery_rate = behavior[4]; fish.pull_efficiency = behavior[5]; fish.habitat_near = behavior[6]; fish.habitat_mid = behavior[7]; fish.habitat_far = behavior[8]
	return fish
