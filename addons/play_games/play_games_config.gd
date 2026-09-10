class_name PlayGamesConfig
extends RefCounted

## Owner-supplied values only. Empty defaults keep the native library and all
## Google metadata out of ordinary debug exports; they never stand in for a
## public leaderboard configuration.
const GAME_ID := ""
const LEADERBOARDS := {}
const INTERNAL_TESTBOARD := false
## IDs remain empty until the owner configures real Play Games leaderboards for all 24 fish.
const FISH_IDS := ["pumpkinseed", "black_crappie", "brown_bullhead", "bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike", "red_drum", "spotted_seatrout", "bluefish", "common_snook", "mangrove_snapper", "atlantic_tarpon", "bowfin", "longnose_gar", "flathead_catfish", "walleye", "striped_bass", "blue_catfish", "mahi_mahi", "yellowfin_tuna", "atlantic_sailfish"]
const OWNER_CONFIG_PATH := "res://addons/play_games/local_play_games_config.json"
const RUNTIME_CONFIG_PATH := "res://addons/play_games/runtime_play_games_config.json"

static func as_dictionary() -> Dictionary:
	return resolve_configuration()

static func resolve_configuration(owner_path := OWNER_CONFIG_PATH, runtime_path := RUNTIME_CONFIG_PATH) -> Dictionary:
	var defaults := {"game_id": GAME_ID, "leaderboards": LEADERBOARDS.duplicate(true), "internal_testboard": INTERNAL_TESTBOARD}
	# The owner-only JSON is ignored by Git and excluded from ordinary exports. It
	# permits a real Console configuration without committing IDs to the game source.
	# A valid export injects only the sanitized runtime copy through add_file().
	for path in [owner_path, runtime_path]:
		var candidate := _read_configuration(path)
		if not candidate.is_empty(): return candidate
	return defaults

static func _read_configuration(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	return parsed.duplicate(true) if typeof(parsed) == TYPE_DICTIONARY else {}

static func configuration_from_json(raw_json: String) -> Dictionary:
	var parsed = JSON.parse_string(raw_json)
	return parsed.duplicate(true) if typeof(parsed) == TYPE_DICTIONARY else {}

static func is_valid(configuration: Dictionary = as_dictionary()) -> bool:
	var game_id := str(configuration.get("game_id", "")).strip_edges()
	if not game_id.is_valid_int() or int(game_id) <= 0: return false
	var ids: Dictionary = configuration.get("leaderboards", {})
	if ids.size() != FISH_IDS.size(): return false
	var seen := {}
	for fish_id in FISH_IDS:
		var board_id := str(ids.get(fish_id, "")).strip_edges()
		if board_id.is_empty() or seen.has(board_id): return false
		seen[board_id] = true
	return true

static func matches_build_receipt(configuration: Dictionary, receipt: Dictionary, aar_sha256: String) -> bool:
	return is_valid(configuration) and bool(receipt.get("configured", false)) and str(receipt.get("game_id", "")) == str(configuration.get("game_id", "")) and not aar_sha256.is_empty() and aar_sha256.to_upper() == str(receipt.get("sha256", "")).to_upper()

static func matches_bundled_aar(configuration: Dictionary, aar_path: String, receipt_path: String) -> bool:
	if not FileAccess.file_exists(aar_path) or not FileAccess.file_exists(receipt_path): return false
	var file := FileAccess.open(receipt_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	return typeof(parsed) == TYPE_DICTIONARY and matches_build_receipt(configuration, parsed, FileAccess.get_sha256(aar_path))
