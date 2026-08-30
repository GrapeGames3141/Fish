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
var fight_pulse: Array[Dictionary] = [{"duration": 42, "amplitude": 0.35}, {"duration": 72, "amplitude": 0.6}]
var fight_cycle_seconds := 1.4

static func bluegill() -> FishDefinition:
	return make("bluegill", "Bluegill", "pine_lake", 4.2, 14.0, 31.0, 0.32, 2.4, [{"duration": 38, "amplitude": 0.30}, {"duration": 62, "amplitude": 0.58}], 1.40)

static func all_planned() -> Array[FishDefinition]:
	return [bluegill(), make("largemouth_bass", "Largemouth Bass", "pine_lake", 2.1, 28.0, 61.0, 0.58, 2.9, [{"duration": 92, "amplitude": 0.78}, {"duration": 36, "amplitude": 0.45}], 1.15), make("channel_catfish", "Channel Catfish", "pine_lake", 1.2, 32.0, 76.0, 0.70, 3.4, [{"duration": 140, "amplitude": 0.68}], 1.80), make("rainbow_trout", "Rainbow Trout", "cedar_river", 3.6, 23.0, 53.0, 0.46, 2.1, [{"duration": 30, "amplitude": 0.48}, {"duration": 30, "amplitude": 0.48}, {"duration": 30, "amplitude": 0.48}], 0.90), make("smallmouth_bass", "Smallmouth Bass", "cedar_river", 2.2, 24.0, 52.0, 0.63, 2.6, [{"duration": 58, "amplitude": 0.82}, {"duration": 86, "amplitude": 0.50}], 1.05), make("northern_pike", "Northern Pike", "cedar_river", 0.9, 46.0, 103.0, 0.88, 3.7, [{"duration": 150, "amplitude": 1.0}, {"duration": 55, "amplitude": 0.72}], 0.72)]

static func for_location(location: String) -> Array[FishDefinition]:
	var result: Array[FishDefinition] = []
	for fish in all_planned():
		if fish.location_id == location: result.append(fish)
	return result

static func select_weighted(location: String, roll: float) -> FishDefinition:
	var candidates := for_location(location)
	if candidates.is_empty(): return bluegill()
	var total := 0.0
	for fish in candidates: total += fish.rarity
	var target := clampf(roll, 0.0, 0.999999) * total
	for fish in candidates:
		target -= fish.rarity
		if target <= 0.0: return fish
	return candidates.back()

static func make(fish_id: String, name: String, location: String, weight: float, min_size: float, max_size: float, strength: float, delay: float, pulse: Array[Dictionary], cycle: float) -> FishDefinition:
	var fish := FishDefinition.new()
	fish.id = fish_id; fish.display_name = name; fish.location_id = location; fish.rarity = weight
	fish.min_length_cm = min_size; fish.max_length_cm = max_size; fish.fight_strength = strength; fish.bite_delay_seconds = delay
	fish.fight_pulse = pulse; fish.fight_cycle_seconds = cycle
	return fish
