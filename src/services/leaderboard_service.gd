class_name LeaderboardService
extends RefCounted

## Testable Play Games v2 boundary. It keeps local records independent and never
## fabricates online ranks, replays migrated catches, or persists an offline queue.
const FishDefinition = preload("res://src/domain/fish_definition.gd")
const FISH_IDS := ["pumpkinseed", "black_crappie", "brown_bullhead", "bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike", "red_drum", "spotted_seatrout", "bluefish", "common_snook", "mangrove_snapper", "atlantic_tarpon", "bowfin", "longnose_gar", "flathead_catfish", "walleye", "striped_bass", "blue_catfish", "mahi_mahi", "yellowfin_tuna", "atlantic_sailfish"]
const PERIOD_ALL_TIME := "ALL TIME"
const PERIOD_WEEKLY := "WEEKLY"
const STATUS_UNAVAILABLE := "UNAVAILABLE"
const STATUS_CONNECTING := "CONNECTING"
const STATUS_NO_AUTH := "NO_AUTH"
const STATUS_LOADING := "LOADING"
const STATUS_READY := "READY"
const STATUS_EMPTY := "EMPTY"
const STATUS_ERROR := "ERROR"

signal changed

var bridge = null
var config: Dictionary = {}
var configured := false
var status := STATUS_UNAVAILABLE
var period := PERIOD_ALL_TIME
var account_id := ""
var account_generation := 0
var period_generation := 0
var initialized := false
var capture_blocked := false
var internal_testboard := false
var request_serial := 0
var boards: Dictionary = {}
var board_cache: Dictionary = {}
var expected_requests: Dictionary = {}
var auth_requests: Dictionary = {}
var submitted_catches: Dictionary = {}
var submitted_requests: Dictionary = {}
var last_error := ""
var latest_auth_request := -1

func _init(custom_bridge = null, configuration: Dictionary = {}, is_capture := false) -> void:
	config = configuration.duplicate(true)
	capture_blocked = is_capture
	bridge = custom_bridge if custom_bridge != null else (Engine.get_singleton("PlayGamesRecords") if Engine.has_singleton("PlayGamesRecords") else null)
	configured = _valid_configuration(config)
	internal_testboard = bool(config.get("internal_testboard", false))
	if bridge != null and bridge.has_signal("play_games_event"):
		bridge.connect("play_games_event", Callable(self, "receive_native_json"))
	if configured and bridge != null and not capture_blocked: status = STATUS_CONNECTING

static func score_millimetres(length_cm: float) -> int:
	return roundi(snappedf(maxf(length_cm, 0.0), 0.1) * 10.0)

static func _valid_configuration(candidate: Dictionary) -> bool:
	var game_id := str(candidate.get("game_id", "")).strip_edges()
	if not game_id.is_valid_int() or int(game_id) <= 0: return false
	var ids: Dictionary = candidate.get("leaderboards", {})
	if ids.size() != FISH_IDS.size(): return false
	var seen := {}
	for fish_id in FISH_IDS:
		var board_id := str(ids.get(fish_id, "")).strip_edges()
		if board_id.is_empty() or seen.has(board_id): return false
		seen[board_id] = true
	return true

func _next_request() -> int:
	request_serial += 1
	return request_serial

func _bridge_call(method: String, arguments: Array) -> bool:
	if bridge == null or not bridge.has_method(method):
		last_error = "bridge_unavailable"; status = STATUS_UNAVAILABLE; changed.emit(); return false
	bridge.callv(method, arguments)
	return true

func open_records() -> void:
	if capture_blocked or not configured or bridge == null:
		status = STATUS_UNAVAILABLE; changed.emit(); return
	var request_id := _next_request()
	auth_requests[request_id] = true
	latest_auth_request = request_id
	status = STATUS_CONNECTING
	if not initialized:
		initialized = _bridge_call("initialize", [request_id, account_generation])
	else:
		_bridge_call("isAuthenticated", [request_id, account_generation])
	changed.emit()

## Explicit only: this is wired to the World Records Connect / Retry control.
func begin_sign_in() -> void:
	if capture_blocked or not configured or bridge == null:
		status = STATUS_UNAVAILABLE; changed.emit(); return
	var request_id := _next_request()
	auth_requests[request_id] = true
	latest_auth_request = request_id
	status = STATUS_CONNECTING
	_bridge_call("signIn", [request_id, account_generation])
	changed.emit()

func set_period(next_period: String) -> void:
	var resolved := PERIOD_WEEKLY if next_period == PERIOD_WEEKLY else PERIOD_ALL_TIME
	if resolved != period: period_generation += 1
	period = resolved
	boards.clear()
	if not account_id.is_empty():
		var cached: Dictionary = _cache_for_current()
		if not cached.is_empty():
			boards = cached.duplicate(true)
			for fish_id in boards:
				var cached_board: Dictionary = boards[fish_id]
				cached_board["cached"] = true
				boards[fish_id] = cached_board
	request_all(not boards.is_empty())

func request_all(retain_cached := false) -> void:
	if capture_blocked or not configured or bridge == null:
		status = STATUS_UNAVAILABLE; changed.emit(); return
	if account_id.is_empty():
		status = STATUS_NO_AUTH; changed.emit(); return
	status = STATUS_LOADING
	period_generation += 1
	expected_requests.clear()
	if not retain_cached: boards.clear()
	for fish_id in FISH_IDS: _request_board(fish_id)
	changed.emit()

func _request_board(fish_id: String) -> void:
	var request_id := _next_request()
	expected_requests[request_id] = {"fish_id": fish_id, "period": period, "period_generation": period_generation, "account_generation": account_generation, "account_id": account_id}
	_bridge_call("requestLeaderboard", [fish_id, str(config.leaderboards.get(fish_id, "")), period == PERIOD_WEEKLY, request_id, account_generation, account_id])

func board_for(fish_id: String) -> Dictionary:
	return boards.get(fish_id, {}).duplicate(true)

func _cache_for_current() -> Dictionary:
	return board_cache.get("%s|%s" % [account_id, period], {})

func _store_board(fish_id: String, payload: Dictionary) -> void:
	var key := "%s|%s" % [account_id, period]
	var cache: Dictionary = board_cache.get(key, {}).duplicate(true)
	cache[fish_id] = payload.duplicate(true)
	board_cache[key] = cache
	boards = cache.duplicate(true)

func _all_empty(candidate: Dictionary) -> bool:
	if candidate.size() != FISH_IDS.size(): return false
	for fish_id in FISH_IDS:
		var board: Dictionary = candidate.get(fish_id, {})
		if not bool(board.get("empty", false)): return false
	return true

func receive_native_json(raw_json: String) -> void:
	var json := JSON.new()
	if json.parse(raw_json) != OK or typeof(json.data) != TYPE_DICTIONARY:
		status = STATUS_ERROR; last_error = "invalid_native_event"; changed.emit(); return
	receive_native_event(json.data)

func receive_native_event(payload: Dictionary) -> void:
	var request_id := int(payload.get("request_id", -1))
	var generation := int(payload.get("account_generation", -1))
	if generation != account_generation:
		return # stale account result; never overwrite a newer player/period cache.
	var kind := str(payload.get("kind", ""))
	match kind:
		"auth": _receive_auth(request_id, payload)
		"board": _receive_board(request_id, payload)
		"submit": _receive_submit(request_id, payload)
		"error": _receive_error(request_id, payload)

func _receive_auth(request_id: int, payload: Dictionary) -> void:
	if not auth_requests.has(request_id) or request_id != latest_auth_request: return
	auth_requests.erase(request_id)
	var auth_state := str(payload.get("state", ""))
	if auth_state != "authenticated":
		account_id = ""; account_generation += 1; period_generation += 1; boards.clear(); expected_requests.clear(); submitted_requests.clear(); status = STATUS_NO_AUTH; changed.emit(); return
	var next_account := str(payload.get("account_id", "")).strip_edges()
	if next_account.is_empty():
		status = STATUS_ERROR; last_error = "missing_account"; changed.emit(); return
	if next_account != account_id:
		account_id = next_account; account_generation += 1; period_generation += 1; boards.clear(); expected_requests.clear(); submitted_requests.clear()
	status = STATUS_READY
	request_all()

func _receive_board(request_id: int, payload: Dictionary) -> void:
	var expected: Dictionary = expected_requests.get(request_id, {})
	if expected.is_empty(): return
	if str(expected.fish_id) != str(payload.get("fish_id", "")) or str(expected.period) != str(payload.get("period", "")) or int(expected.period_generation) != period_generation or str(expected.period) != period or int(expected.account_generation) != account_generation or str(expected.account_id) != account_id or str(payload.get("account_id", "")) != account_id:
		return
	expected_requests.erase(request_id)
	var board := {
		"fish_id": str(expected.fish_id), "period": str(expected.period),
		"top_score_mm": maxi(0, int(payload.get("top_score_mm", 0))), "top_rank": maxi(0, int(payload.get("top_rank", 0))), "top_name": str(payload.get("top_name", "")),
		"player_score_mm": maxi(0, int(payload.get("player_score_mm", 0))), "player_rank": maxi(0, int(payload.get("player_rank", 0))), "player_name": str(payload.get("player_name", "")),
		"empty": bool(payload.get("empty", false)), "cached": bool(payload.get("cached", false))
	}
	_store_board(str(expected.fish_id), board)
	if expected_requests.is_empty(): status = STATUS_ERROR if _has_error(boards) else (STATUS_EMPTY if _all_empty(boards) else STATUS_READY)
	changed.emit()

func _has_error(candidate: Dictionary) -> bool:
	for fish_id in FISH_IDS:
		if str(candidate.get(fish_id, {}).get("error", "")).length() > 0: return true
	return false

func _receive_submit(request_id: int, payload: Dictionary) -> void:
	var expected: Dictionary = submitted_requests.get(request_id, {})
	if expected.is_empty() or int(expected.account_generation) != account_generation or str(expected.account_id) != account_id or str(payload.get("account_id", "")) != account_id: return
	if str(expected.fish_id) != str(payload.get("fish_id", "")) or int(expected.score_mm) != int(payload.get("score_mm", -1)): return
	submitted_requests.erase(request_id)
	board_cache.erase("%s|%s" % [account_id, PERIOD_ALL_TIME]); board_cache.erase("%s|%s" % [account_id, PERIOD_WEEKLY])
	boards.clear()
	changed.emit()

func _receive_error(request_id: int, payload: Dictionary) -> void:
	var operation := str(payload.get("operation", ""))
	if auth_requests.has(request_id):
		if request_id != latest_auth_request: return
		auth_requests.erase(request_id); status = STATUS_ERROR; last_error = str(payload.get("reason", "unknown")); changed.emit(); return
	if expected_requests.has(request_id):
		var expected: Dictionary = expected_requests[request_id]
		if int(expected.period_generation) != period_generation or int(expected.account_generation) != account_generation or str(expected.account_id) != account_id: return
		expected_requests.erase(request_id)
		_store_board(str(expected.fish_id), {"fish_id": str(expected.fish_id), "period": str(expected.period), "error": str(payload.get("reason", "unknown")), "empty": false})
		last_error = str(payload.get("reason", "unknown"))
		status = STATUS_ERROR
		changed.emit(); return
	if operation == "submit" and submitted_requests.has(request_id):
		submitted_requests.erase(request_id); last_error = str(payload.get("reason", "unknown")); changed.emit()

func can_submit(fish_id: String, length_cm: float, context: Dictionary) -> bool:
	if capture_blocked or not configured or bridge == null or account_id.is_empty() or fish_id not in FISH_IDS: return false
	if not bool(context.get("landed", false)) or not bool(context.get("motion_cast", false)) or not bool(context.get("motion_hook", false)) or not bool(context.get("motion_fight", false)): return false
	if bool(context.get("capture", false)) or bool(context.get("fixture", false)) or bool(context.get("legacy", false)) or bool(context.get("simulated", false)): return false
	if not bool(context.get("android", false)): return false
	if bool(context.get("debug", false)) and not internal_testboard: return false
	var fight_seconds := float(context.get("fight_seconds", 0.0))
	if str(context.get("catch_token", "")).is_empty() or not is_finite(length_cm) or not is_finite(fight_seconds) or fight_seconds < 4.0 or fight_seconds > 180.0: return false
	for fish in FishDefinition.all_planned():
		if fish.id == fish_id: return length_cm >= fish.min_length_cm and length_cm <= fish.max_length_cm
	return false

func submit_landed(fish_id: String, length_cm: float, context: Dictionary) -> bool:
	if not can_submit(fish_id, length_cm, context): return false
	var millimetres := score_millimetres(length_cm)
	var catch_key := "%s:%d:%s" % [fish_id, millimetres, str(context.get("catch_token", ""))]
	if submitted_catches.has(catch_key): return false
	submitted_catches[catch_key] = true
	var request_id := _next_request()
	submitted_requests[request_id] = {"fish_id": fish_id, "score_mm": millimetres, "account_generation": account_generation, "account_id": account_id}
	if not _bridge_call("submitScore", [fish_id, str(config.leaderboards.get(fish_id, "")), millimetres, request_id, account_generation, account_id]):
		submitted_catches.erase(catch_key); submitted_requests.erase(request_id); return false
	return true
