extends SceneTree

const FishingSession = preload("res://src/domain/fishing_session.gd")
const FightChallenge = preload("res://src/domain/fight_challenge.gd")
const SaveService = preload("res://src/services/save_service.gd")
const AdMobService = preload("res://src/services/admob_service.gd")
const MotionService = preload("res://src/services/motion_service.gd")
const FishDefinition = preload("res://src/domain/fish_definition.gd")
const HapticService = preload("res://src/services/haptic_service.gd")
const CastCaptureService = preload("res://src/services/cast_capture_service.gd")
const GameMain = preload("res://src/ui/main.gd")
const WaterSurface = preload("res://src/ui/water_surface.gd")
const LeaderboardService = preload("res://src/services/leaderboard_service.gd")
const PlayGamesConfig = preload("res://addons/play_games/play_games_config.gd")

class MockPlayGamesBridge extends RefCounted:
	signal play_games_event(raw_json: String)
	var calls: Array[Dictionary] = []
	func initialize(request_id: int, generation: int) -> void: calls.append({"method": "initialize", "request_id": request_id, "generation": generation})
	func isAuthenticated(request_id: int, generation: int) -> void: calls.append({"method": "isAuthenticated", "request_id": request_id, "generation": generation})
	func signIn(request_id: int, generation: int) -> void: calls.append({"method": "signIn", "request_id": request_id, "generation": generation})
	func requestLeaderboard(fish_id: String, leaderboard_id: String, weekly: bool, request_id: int, generation: int, account_id: String) -> void:
		calls.append({"method": "requestLeaderboard", "fish_id": fish_id, "leaderboard_id": leaderboard_id, "weekly": weekly, "request_id": request_id, "generation": generation, "account_id": account_id})
	func submitScore(fish_id: String, leaderboard_id: String, score_mm: int, request_id: int, generation: int, account_id: String) -> void:
		calls.append({"method": "submitScore", "fish_id": fish_id, "leaderboard_id": leaderboard_id, "score_mm": score_mm, "request_id": request_id, "generation": generation, "account_id": account_id})
	func emit_payload(payload: Dictionary) -> void: play_games_event.emit(JSON.stringify(payload))

var failures: Array[String] = []

func _init() -> void:
	_test_state_transitions_and_timing()
	_test_pump_and_recover_fight()
	_test_fight_challenge_contract()
	_test_save_round_trip()
	_test_waters_catalog_and_unlocks()
	_test_catch_record_progression()
	_test_ui_presentation_contract()
	_test_water_surface_presentation()
	_test_ui_controller_interactions()
	_test_cast_capture_service()
	_test_injectable_motion()
	_test_physical_cast_profile_motion()
	_test_haptic_signatures()
	_test_leaderboard_service()
	_test_admob_contract()
	_test_project_source_settings()
	if failures.is_empty():
		print("PASS: Cast & Crank Gate 1 domain tests")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d test assertions" % failures.size())
		quit(1)

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _test_water_surface_presentation() -> void:
	var point := Vector2(500, 760)
	var samples := {"willow_pond": [], "pine_lake": [], "cedar_river": [], "hatteras_inlet": [], "mangrove_flats": [], "cypress_bayou": [], "moonlit_reservoir": [], "bluewater_offshore": []}
	var energy := {"willow_pond": 0.0, "pine_lake": 0.0, "cedar_river": 0.0, "hatteras_inlet": 0.0, "mangrove_flats": 0.0, "cypress_bayou": 0.0, "moonlit_reservoir": 0.0, "bluewater_offshore": 0.0}
	var travel := {"willow_pond": 0.0, "pine_lake": 0.0, "cedar_river": 0.0, "hatteras_inlet": 0.0, "mangrove_flats": 0.0, "cypress_bayou": 0.0, "moonlit_reservoir": 0.0, "bluewater_offshore": 0.0}
	for frame in range(120):
		var time := float(frame) / 12.0
		for location_id in samples:
			var sample: Dictionary = WaterSurface.sample(location_id, point, time, false)
			samples[location_id].append(sample.offset)
			energy[location_id] += sample.offset.length_squared()
			if frame > 0: travel[location_id] += sample.offset.distance_to(samples[location_id][frame - 1])
			var cap := 45.01 if location_id == "hatteras_inlet" else (12.51 if location_id == "bluewater_offshore" else 5.01)
			expect(sample.offset.length() <= cap, "water profile %s keeps bobber displacement bounded" % location_id)
	var pond_rms := sqrt(float(energy.willow_pond) / 120.0)
	var lake_rms := sqrt(float(energy.pine_lake) / 120.0)
	var ocean_rms := sqrt(float(energy.hatteras_inlet) / 120.0)
	var offshore_rms := sqrt(float(energy.bluewater_offshore) / 120.0)
	var still_a: Dictionary = WaterSurface.sample("hatteras_inlet", point, 2.3, true)
	var still_b: Dictionary = WaterSurface.sample("hatteras_inlet", point, 8.7, true)
	var shore_motion := WaterSurface.ocean_surf_weight(Vector2(650, 1200))
	var swash_motion := WaterSurface.ocean_surf_weight(Vector2(400, 1170))
	var dry_sand := WaterSurface.ocean_surf_weight(Vector2(460, 1258))
	var dry_grass := WaterSurface.ocean_surf_weight(Vector2(245, 1250))
	var surf_start := WaterSurface.ocean_surf_offset(Vector2(650, 1200), .001, false)
	var surf_loop := WaterSurface.ocean_surf_offset(Vector2(650, 1200), 5.999, false)
	var short_cast_point := Vector2(446, 780)
	var short_cast: Dictionary = WaterSurface.sample("hatteras_inlet", short_cast_point, 2.4, false)
	var short_common: Vector2 = short_cast.common_offset
	var short_shore: Vector2 = short_cast.shore_offset
	expect(WaterSurface.profile_id("willow_pond") == 0 and WaterSurface.profile_id("pine_lake") == 1 and WaterSurface.profile_id("cedar_river") == 2 and WaterSurface.profile_id("hatteras_inlet") == 3 and WaterSurface.profile_id("mangrove_flats") == 4 and WaterSurface.profile_id("cypress_bayou") == 5 and WaterSurface.profile_id("moonlit_reservoir") == 6 and WaterSurface.profile_id("bluewater_offshore") == 7, "water presentation maps all eight location profiles deterministically")
	expect(lake_rms > pond_rms, "lake wind chop is stronger than the pond over a deterministic ten-second sample")
	expect(float(travel.cedar_river) > float(travel.pine_lake), "river current changes faster than lake chop over a deterministic ten-second sample")
	expect(ocean_rms > lake_rms, "ocean rolling swell has more displacement than lake chop over a deterministic ten-second sample")
	expect(offshore_rms > lake_rms and float(energy.mangrove_flats) > 0.01 and float(energy.cypress_bayou) > 0.01 and float(energy.moonlit_reservoir) > 0.01, "new flats, bayou, moonlit, and bluewater profiles animate with distinct bounded motion")
	expect(WaterSurface.sample("bluewater_offshore", point, 2.3, false).shore_offset == Vector2.ZERO and WaterSurface.sample("hatteras_inlet", point, 2.3, false).shore_offset != Vector2.ZERO, "Hatteras alone retains shoreline wash while Bluewater uses open-ocean swell")
	expect((short_cast.offset - short_common).is_equal_approx(short_shore) and short_shore.is_equal_approx(WaterSurface.ocean_surf_offset(short_cast_point, 2.4, false)), "Hatteras short-cast bobber and line share the exact bounded offshore shore-surf displacement")
	expect(still_a.offset == Vector2.ZERO and is_zero_approx(still_a.tilt) and is_zero_approx(still_a.submerge) and still_b == still_a, "reduced motion freezes ambient bobber offset, tilt, and submergence at every presentation time")
	expect(shore_motion > 0.5 and swash_motion > 0.1 and is_zero_approx(dry_sand) and is_zero_approx(dry_grass), "Hatteras shore controls animate bottom-right water and a narrow foam swash while leaving foreground sand and grass dry")
	expect(surf_start.distance_to(surf_loop) < 0.05 and is_equal_approx(WaterSurface.ocean_surf_cycle(0.0, false), WaterSurface.ocean_surf_cycle(6.0, false)) and not is_equal_approx(WaterSurface.ocean_surf_cycle(1.0, false), WaterSurface.ocean_surf_cycle(3.0, false)) and is_zero_approx(WaterSurface.ocean_surf_cycle(4.0, true)), "shore surf stays continuous across the six-second phase seam and reduced motion disables it")
	var mapping_points: Array[Vector2] = [Vector2(400, 1165), Vector2(650, 1200), Vector2(650, 1240)]
	var mapping_times: Array[float] = [.15, 1.5, 2.4, 3.8, 5.85]
	for mapping_time: float in mapping_times:
		for mapping_point: Vector2 in mapping_points:
			# The shader samples at p-offset, so this finite-difference map catches
			# local inversions rather than merely asserting a bounded CPU offset.
			var mapped: Vector2 = mapping_point - WaterSurface.ocean_surf_offset(mapping_point, mapping_time, false)
			var mapped_x: Vector2 = mapping_point + Vector2.RIGHT - WaterSurface.ocean_surf_offset(mapping_point + Vector2.RIGHT, mapping_time, false)
			var mapped_y: Vector2 = mapping_point + Vector2.DOWN - WaterSurface.ocean_surf_offset(mapping_point + Vector2.DOWN, mapping_time, false)
			var dx: Vector2 = mapped_x - mapped
			var dy: Vector2 = mapped_y - mapped
			expect(dx.cross(dy) > 0.25 and dx.length() < 1.75 and dy.length() < 1.75, "Hatteras shore sampling map stays locally non-folding at %s, t=%.2f" % [mapping_point, mapping_time])
	var shader_source := FileAccess.get_file_as_string("res://src/ui/water_surface.gdshader")
	var surface_source := FileAccess.get_file_as_string("res://src/ui/water_surface.gd")
	var main_source := FileAccess.get_file_as_string("res://src/ui/main.gd")
	expect("mask_at(UV - offset)" in shader_source and "texture(TEXTURE, clamp(UV - offset" in shader_source and "p.y / 1280.0" in surface_source and "* perspective" in surface_source, "CPU bobber and shader use the top-down, source/destination-gated displacement convention")
	var sample_body := surface_source.substr(surface_source.find("static func sample"), surface_source.find("func _draw") - surface_source.find("static func sample"))
	expect("if (profile == 3)" in shader_source and "ocean_shore_weight(px)" in shader_source and "shore_offset" in shader_source and "28.0 * run_cycle" in shader_source and "if profile == 3: drift += shore_offset" in sample_body, "shore surf is Hatteras-only, uses a bounded single-coordinate shorewash, and gives Hatteras tackle the matching shared offset")
	expect("var submerged := s.state in [FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING]" in main_source and "if not submerged and controller.bobber_texture" in main_source, "float is visible only while line-out and stays hidden in bite, hook-window, and reeling states")

func _max_emitted_amplitude(pulses: Array[Dictionary]) -> float:
	var maximum := 0.0
	for pulse in pulses:
		maximum = maxf(maximum, float(pulse.amplitude))
	return maximum

func _motion_sample(linear: Vector3, gyro := Vector3(0, 0, 0.72)) -> Dictionary:
	var gravity := Vector3(0, -9.8, 0)
	return {"gravity": gravity, "accelerometer": gravity + linear, "gyro": gyro}

func _leaderboard_config(internal_testboard := false) -> Dictionary:
	return {"game_id": "1234567890", "internal_testboard": internal_testboard, "leaderboards": {
		"pumpkinseed": "mock-board-pumpkinseed", "black_crappie": "mock-board-crappie", "brown_bullhead": "mock-board-bullhead",
		"bluegill": "mock-board-bluegill", "largemouth_bass": "mock-board-largemouth", "channel_catfish": "mock-board-catfish",
		"rainbow_trout": "mock-board-trout", "smallmouth_bass": "mock-board-smallmouth", "northern_pike": "mock-board-pike",
		"red_drum": "mock-board-reddrum", "spotted_seatrout": "mock-board-seatrout", "bluefish": "mock-board-bluefish",
		"common_snook": "mock-board-snook", "mangrove_snapper": "mock-board-snapper", "atlantic_tarpon": "mock-board-tarpon",
		"bowfin": "mock-board-bowfin", "longnose_gar": "mock-board-gar", "flathead_catfish": "mock-board-flathead",
		"walleye": "mock-board-walleye", "striped_bass": "mock-board-striper", "blue_catfish": "mock-board-bluecat",
		"mahi_mahi": "mock-board-mahi", "yellowfin_tuna": "mock-board-yellowfin", "atlantic_sailfish": "mock-board-sailfish"
	}}

func _board_event(request_id: int, generation: int, fish_id: String, period: String, empty := false, account_id := "player-a") -> Dictionary:
	return {"kind": "board", "request_id": request_id, "account_generation": generation, "fish_id": fish_id, "period": period,
		"top_score_mm": 0 if empty else 426, "top_rank": 1, "top_name": "River Pro", "player_score_mm": 0 if empty else 318,
		"player_rank": 7, "player_name": "Tak", "empty": empty, "account_id": account_id}

func _test_leaderboard_service() -> void:
	var owner_json := JSON.stringify(_leaderboard_config())
	var resolved_owner: Dictionary = PlayGamesConfig.configuration_from_json(owner_json)
	expect(PlayGamesConfig.is_valid(resolved_owner) and str(resolved_owner.game_id) == "1234567890" and PlayGamesConfig.FISH_IDS.size() == 24, "owner JSON resolves one validated twenty-four-board configuration for both export and runtime")
	expect(PlayGamesConfig.matches_build_receipt(resolved_owner, {"configured": true, "game_id": "1234567890", "sha256": "ABCD"}, "abcd") and not PlayGamesConfig.matches_build_receipt(resolved_owner, {"configured": true, "game_id": "123", "sha256": "ABCD"}, "abcd"), "configured export receipt must match the resolved owner game ID and AAR hash")
	if FileAccess.file_exists(PlayGamesConfig.OWNER_CONFIG_PATH):
		expect(PlayGamesConfig.matches_bundled_aar(PlayGamesConfig.as_dictionary(), "res://addons/play_games/bin/cast-and-crank-play-games-release.aar", "res://addons/play_games/bin/build_receipt.json"), "owner configuration, helper-built AAR hash receipt, and runtime PCK injection gate agree before a configured export")
	var invalid := LeaderboardService.new(MockPlayGamesBridge.new(), {"game_id": "0", "leaderboards": {}})
	invalid.open_records()
	expect(invalid.status == LeaderboardService.STATUS_UNAVAILABLE, "leaderboards stay unavailable until one numeric game ID and all twenty-four distinct board IDs are owner-configured")
	var duplicate := _leaderboard_config(); duplicate.leaderboards.northern_pike = duplicate.leaderboards.bluegill
	expect(not LeaderboardService._valid_configuration(duplicate), "leaderboard configuration rejects duplicate board IDs instead of accepting a twenty-four-entry dictionary")
	var mock := MockPlayGamesBridge.new()
	var service := LeaderboardService.new(mock, _leaderboard_config())
	service.open_records()
	expect(mock.calls.size() == 1 and str(mock.calls[0].method) == "initialize" and service.status == LeaderboardService.STATUS_CONNECTING, "opening World Records performs a quiet auth check without prompting during fishing")
	var auth_request := int(mock.calls[0].request_id)
	mock.emit_payload({"kind": "auth", "request_id": auth_request, "account_generation": 0, "state": "unauthenticated", "account_id": ""})
	expect(service.status == LeaderboardService.STATUS_NO_AUTH and service.account_id.is_empty(), "cancelled or unavailable sign-in reports no-auth without inventing a player")
	service.begin_sign_in()
	expect(str(mock.calls.back().method) == "signIn", "only the explicit World Connect control invokes Play Games sign-in")
	var sign_in_request := int(mock.calls.back().request_id)
	mock.emit_payload({"kind": "auth", "request_id": sign_in_request, "account_generation": int(mock.calls.back().generation), "state": "authenticated", "account_id": "player-a"})
	var board_calls: Array[Dictionary] = []
	for call in mock.calls:
		if str(call.method) == "requestLeaderboard": board_calls.append(call)
	expect(board_calls.size() == LeaderboardService.FISH_IDS.size() and service.account_generation == 2, "authenticated account requests top and player scores for all twenty-four fish with a fresh account generation")
	var first_request := board_calls[0]
	mock.emit_payload(_board_event(int(first_request.request_id), 1, str(first_request.fish_id), "ALL TIME"))
	expect(service.board_for(str(first_request.fish_id)).is_empty(), "stale account-generation board callbacks cannot overwrite the current player cache")
	mock.emit_payload(_board_event(int(first_request.request_id), 2, str(first_request.fish_id), "WEEKLY"))
	expect(service.board_for(str(first_request.fish_id)).is_empty(), "wrong-period board callbacks cannot overwrite the selected period")
	for call in board_calls:
		mock.emit_payload(_board_event(int(call.request_id), 2, str(call.fish_id), "ALL TIME"))
	expect(service.status == LeaderboardService.STATUS_READY and int(service.board_for("bluegill").player_rank) == 7 and str(service.board_for("bluegill").top_name) == "River Pro", "online player rank and global angler/length are cached separately from local records")
	service.set_period(LeaderboardService.PERIOD_WEEKLY)
	var weekly_calls: Array[Dictionary] = []
	for call in mock.calls:
		if str(call.method) == "requestLeaderboard" and bool(call.weekly): weekly_calls.append(call)
	expect(weekly_calls.size() == LeaderboardService.FISH_IDS.size(), "weekly selector requests all twenty-four boards, not only Bluegill")
	for call in weekly_calls: mock.emit_payload(_board_event(int(call.request_id), 2, str(call.fish_id), "WEEKLY", true))
	expect(service.status == LeaderboardService.STATUS_EMPTY and service.board_for("northern_pike").get("empty", false), "empty weekly boards render as an honest online empty state")
	service.open_records()
	var account_check: Dictionary = mock.calls.back()
	mock.emit_payload({"kind": "auth", "request_id": int(account_check.request_id), "account_generation": 2, "state": "authenticated", "account_id": "player-b"})
	expect(service.account_id == "player-b" and service.account_generation == 3 and service.board_for("bluegill").is_empty(), "account changes clear old account caches before requesting fresh boards")
	var fresh_call: Dictionary = mock.calls.back()
	mock.emit_payload({"kind": "error", "request_id": int(fresh_call.request_id), "account_generation": 3, "operation": "leaderboard", "reason": "network"})
	expect(service.status == LeaderboardService.STATUS_ERROR and service.last_error == "network", "matching native errors surface an honest retry state")
	var public_context := {"landed": true, "motion_cast": true, "motion_hook": true, "motion_fight": true, "fight_seconds": 12.0, "android": true, "debug": false, "capture": false, "fixture": false, "legacy": false, "simulated": false, "catch_token": 77}
	service.account_id = "player-b"
	expect(service.submit_landed("bluegill", 25.04, public_context), "new legitimate Android motion-loop catch submits in integer millimetres")
	var submit: Dictionary = mock.calls.back()
	expect(str(submit.method) == "submitScore" and int(submit.score_mm) == 250 and not service.submit_landed("bluegill", 25.04, public_context), "one landed catch submits once with 0.1cm-to-mm precision")
	var blocked_context := public_context.duplicate(true); blocked_context.fixture = true
	expect(not service.can_submit("bluegill", 25.0, blocked_context), "capture fixtures, desktop/debug simulations, legacy aggregates, and invalid catches never backfill public boards")
	blocked_context = public_context.duplicate(true); blocked_context.debug = true
	expect(not service.can_submit("bluegill", 25.0, blocked_context), "ordinary debug APK catches stay off public boards")
	var test_service := LeaderboardService.new(MockPlayGamesBridge.new(), _leaderboard_config(true)); test_service.account_id = "internal-player"
	expect(test_service.can_submit("bluegill", 25.0, blocked_context), "an explicit owner internal-testboard configuration is the only debug submission exception")
	expect(LeaderboardService.score_millimetres(25.04) == 250 and LeaderboardService.score_millimetres(25.05) == 251, "leaderboard unit conversion is stable at one-decimal fish precision")

func _test_cast_capture_service() -> void:
	var path := "user://cast_tuning_capture_test_%d.json" % Time.get_ticks_msec()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var capture := CastCaptureService.new(path)
	expect(capture.phase == "idle" and not FileAccess.file_exists(path), "capture recorder is idle and stores nothing by default")
	expect(capture.start({"left_handed": false, "sensitivity": 1.2, "motion_profile": {"forward_axis": [-0.85, 0.27, -0.45]}}), "explicit Settings-style start begins a fresh capture")
	expect(capture.phase == "countdown" and not FileAccess.file_exists(path), "countdown does not overwrite a prior capture")
	var event: Dictionary = {}
	for frame in range(30): event = capture.update(0.10)
	expect(capture.phase == "active" and str(event.get("cue", "")) == "capture_window" and capture.casts.is_empty(), "countdown transitions into the first haptic-cued active window without sampling early")
	var last_event: Dictionary = {}
	for cast_number in range(CastCaptureService.CAST_COUNT):
		for frame in range(20):
			capture.queue_sample(_motion_sample(Vector3(-1.5 - cast_number * 0.1, 0.2, -0.3), Vector3(0.1, 0.2, 0.7)))
			last_event = capture.update(0.10)
		if cast_number < CastCaptureService.CAST_COUNT - 1:
			capture.queue_sample(_motion_sample(Vector3(99, 0, 0)))
			var rest_queued := capture.queued_samples.size()
			for frame in range(11): last_event = capture.update(0.10)
			expect(capture.phase == "active" and str(last_event.get("cue", "")) == "capture_window" and capture.queued_samples.size() == rest_queued, "rest windows do not sample and advance automatically to the next capture cue")
			capture.queued_samples.pop_front()
	expect(capture.phase == "saved" and bool(last_event.get("saved", false)) and capture.write_count == 1, "exactly ten active windows complete and write once")
	expect(capture.casts.size() == CastCaptureService.CAST_COUNT, "capture contains exactly ten cast groups")
	for group in capture.casts:
		expect(group.samples.size() > 0 and group.samples.size() <= CastCaptureService.MAX_SAMPLES_PER_CAST, "active capture group is nonempty and bounded")
		var sample: Dictionary = group.samples[0]
		expect(sample.has("t_ms") and sample.has("gravity") and sample.has("accelerometer") and sample.has("linear") and sample.has("gyro"), "captured samples retain timestamped sensor and derived-linear fields")
	last_event = capture.update(0.10)
	expect(capture.write_count == 1 and not bool(last_event.get("saved", false)), "completed capture is one-shot and does not rewrite while idle")
	var file := FileAccess.open(path, FileAccess.READ); var json := JSON.new(); var parse_error := json.parse(file.get_as_text()); file.close()
	expect(parse_error == OK and typeof(json.data) == TYPE_DICTIONARY and int(json.data.get("version", 0)) == CastCaptureService.VERSION and bool(json.data.get("completed", false)) and json.data.get("metadata", {}).get("handedness", "") == "right" and json.data.get("casts", []).size() == CastCaptureService.CAST_COUNT, "completed explicit capture writes valid metadata and ten groups")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _runtime_sweep(motion: MotionService, linear: Vector3, gyro := Vector3(0, 0, 0.72), frames := 3, delta := 0.04) -> Dictionary:
	var event := {"cast_arm": false, "cast_quality": 0.0}
	for frame in range(frames):
		motion.queue_sample(_motion_sample(linear, gyro))
		event = motion.update(delta, true, false)
	return event

func _physical_back_sweep(motion: MotionService, strength_multiplier := 1.20, frames := 3, delta := 0.04) -> Dictionary:
	return _runtime_sweep(motion, motion._back_axis_direction() * motion._physical_cock_threshold() * strength_multiplier, Vector3(0, 0, 0.72), frames, delta)

func _learned_snap_sweep(motion: MotionService, strength := -1.0, frames := 3, delta := 0.04) -> Dictionary:
	var axis := Vector3(motion.profile.forward_axis[0], motion.profile.forward_axis[1], motion.profile.forward_axis[2]).normalized()
	if strength < 0.0:
		strength = motion._runtime_snap_threshold() * 2.0
	return _runtime_sweep(motion, axis * strength, Vector3(0, 0, 0.72), frames, delta)

func _hook_sweep(motion: MotionService, multiplier := 1.4, frames := 3, delta := 0.05) -> Dictionary:
	var event := {"hook": false}
	var linear := motion._back_axis_direction() * motion._hook_threshold() * multiplier
	for frame in range(frames):
		motion.queue_sample(_motion_sample(linear, Vector3(0, 0, 0.5)))
		event = motion.update(delta, false, true)
	return event

func _calibrated_motion() -> MotionService:
	var motion := MotionService.new()
	motion.begin_calibration()
	for frame in range(3):
		motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
		motion.update(0.25, false, false)
	for pair in [[Vector3(3.0, 0, 0), Vector3(-5.0, 0, 0)], [Vector3(3.2, 0, 0), Vector3(-5.4, 0, 0)]]:
		motion.queue_sample(_motion_sample(pair[0]))
		motion.update(0.01, false, false)
		motion.queue_sample(_motion_sample(pair[1]))
		motion.update(0.18, false, false)
	return motion

func _diagonal_motion() -> MotionService:
	var motion := MotionService.new()
	motion.begin_calibration()
	for frame in range(3):
		motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
		motion.update(0.25, false, false)
	var cock := Vector3(4.5, 4.5, 1.5)
	for pair in [[cock, -cock * 1.70], [cock * 1.04, -cock * 1.76]]:
		motion.queue_sample(_motion_sample(pair[0]))
		motion.update(0.01, false, false)
		motion.queue_sample(_motion_sample(pair[1]))
		motion.update(0.18, false, false)
	return motion

func _left_calibrated_motion() -> MotionService:
	var motion := MotionService.new(); motion.left_handed = true; motion.begin_calibration()
	for frame in range(3): motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); motion.update(0.25, false, false)
	for pair in [[Vector3(-3.0, 0, 0), Vector3(5.0, 0, 0)], [Vector3(-3.2, 0, 0), Vector3(5.4, 0, 0)]]:
		motion.queue_sample(_motion_sample(pair[0])); motion.update(0.01, false, false); motion.queue_sample(_motion_sample(pair[1])); motion.update(0.18, false, false)
	return motion

func _test_state_transitions_and_timing() -> void:
	var game = FishingSession.new()
	expect(game.arm_cast(), "READY arms")
	expect(game.release_cast(0.85), "armed cast releases")
	expect(game.cast_distance_m > FishingSession.MIN_CAST_DISTANCE_M and game.cast_distance_m <= FishingSession.MAX_CAST_DISTANCE_M, "cast quality maps to a bounded distance")
	game.tick(game.bite_wait_seconds)
	expect(game.state == FishingSession.State.BITE, "line reaches bite")
	game.tick(FishingSession.BITE_CUE_HOLD_SECONDS - 0.01)
	expect(game.state == FishingSession.State.BITE, "bite holds hook detection until the two-pulse cue has completed")
	game.tick(0.01)
	expect(game.state == FishingSession.State.HOOK_WINDOW and is_zero_approx(game.bite_elapsed), "bite advances only after the .42 second cue hold and resets the full hook timer")
	expect(game.set_hook(), "hook succeeds in 1.8s window")
	expect(game.state == FishingSession.State.REELING, "hook enters reeling")
	game.reset(); game.arm_cast(); game.release_cast(0.4); game.tick(game.bite_wait_seconds + 0.01); game.tick(FishingSession.BITE_CUE_HOLD_SECONDS); game.tick(FishingSession.HOOK_WINDOW_SECONDS + 0.1)
	expect(game.state == FishingSession.State.ESCAPED, "hook timeout escapes")
	var boundary = FishingSession.new(); boundary.arm_cast(); boundary.release_cast(0.5); boundary.tick(boundary.bite_wait_seconds + 0.01); boundary.tick(FishingSession.BITE_CUE_HOLD_SECONDS); boundary.tick(1.79); expect(boundary.state == FishingSession.State.HOOK_WINDOW, "hook remains available for the full 1.8 seconds after the bite cue hold"); boundary.tick(0.02); expect(boundary.state == FishingSession.State.ESCAPED, "hook closes at 1.8 seconds after the cue hold")
	var guarded_bite = FishingSession.new(); guarded_bite.arm_cast(); guarded_bite.release_cast(0.8); guarded_bite.tick(guarded_bite.bite_wait_seconds)
	var bite_guard_motion := _calibrated_motion(); bite_guard_motion.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.5)))
	expect(not bite_guard_motion.update(0.05, false, guarded_bite.state == FishingSession.State.HOOK_WINDOW).hook and guarded_bite.state == FishingSession.State.BITE, "BITE does not activate hook detection while the bite haptic chain is still protected")
	guarded_bite.tick(FishingSession.BITE_CUE_HOLD_SECONDS)
	expect(guarded_bite.state == FishingSession.State.HOOK_WINDOW and _hook_sweep(bite_guard_motion).hook, "hook detection starts only after the bite cue hold completes and a deliberate sweep arrives")
	var cancellation_motion := _calibrated_motion(); var cancellation_arm := _physical_back_sweep(cancellation_motion)
	var cancellation_session := FishingSession.new(); cancellation_session.arm_cast()
	cancellation_motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); var cancellation_event := cancellation_motion.update(MotionService.RUNTIME_MAX_REVERSAL_SECONDS + 0.01, true, false)
	expect(cancellation_arm.cast_arm and bool(cancellation_event.get("cast_cancel", false)) and cancellation_session.cancel_cast() and cancellation_session.state == FishingSession.State.READY, "timed-out reversal emits cast_cancel and returns CAST_ARMED to READY without progress")
	var stale_snap := _runtime_sweep(cancellation_motion, Vector3(-80.0, 0, 0), Vector3(0, 0, 0.72))
	expect(float(stale_snap.cast_quality) == 0.0 and not stale_snap.cast_arm, "a snap after cancellation cannot cast without a fresh cock")
	var pine_rolls := [0.0, 0.60, 0.90]
	var cedar_rolls := [0.0, 0.65, 0.93]
	var selected_ids: Array[String] = []
	for roll in pine_rolls:
		selected_ids.append(FishDefinition.select_weighted("pine_lake", roll).id)
	for roll in cedar_rolls:
		selected_ids.append(FishDefinition.select_weighted("cedar_river", roll).id)
	expect(selected_ids == ["bluegill", "largemouth_bass", "channel_catfish", "rainbow_trout", "smallmouth_bass", "northern_pike"], "deterministic weighted boundaries make every planned species reachable across Pine Lake and Cedar River")
	var pine := FishDefinition.select_weighted("pine_lake", 0.0); var cedar := FishDefinition.select_weighted("cedar_river", 0.99)
	expect(pine.location_id == "pine_lake" and cedar.id == "northern_pike" and cedar.max_length_cm > pine.max_length_cm, "deterministic weighted location selection exposes distinct species and size ranges")
	var near_pine := FishDefinition.select_weighted("pine_lake", 0.70, 12.0)
	var far_pine := FishDefinition.select_weighted("pine_lake", 0.70, 36.0)
	expect(near_pine.id != far_pine.id, "near and far Pine Lake habitat weights can change encounter selection")
	var tiny_far := FishingSession.new(); tiny_far.set_location("cedar_river"); tiny_far.set_encounter_rolls(0.1, 0.05, 0.0); tiny_far.arm_cast(); tiny_far.release_cast(0.95)
	var giant_near := FishingSession.new(); giant_near.set_location("cedar_river"); giant_near.set_encounter_rolls(0.1, 0.98, 0.0); giant_near.arm_cast(); giant_near.release_cast(0.15)
	expect(tiny_far.catch_length_cm < giant_near.catch_length_cm, "independent size roll prevents long casts from guaranteeing larger catches")
	var terminal_recast := FishingSession.new(); terminal_recast.state = FishingSession.State.CAUGHT; terminal_recast.tick(FishingSession.TERMINAL_RECAST_DWELL_SECONDS)
	for frame in range(6): terminal_recast.credit_terminal_still(0.08, true)
	expect(terminal_recast.can_recast_from_motion(), "terminal recast requires dwell plus valid still sensor credit")
	terminal_recast.credit_terminal_still(0.01, false)
	expect(not terminal_recast.can_recast_from_motion(), "terminal movement resets recast readiness until a fresh quiet settle")

func _fight_session(fish: FishDefinition, behavior_roll := 0.0, challenge := FightChallenge.DEFAULT_ID) -> FishingSession:
	var game := FishingSession.new()
	game.set_location(fish.location_id, 0.0); game.set_next_cast_challenge(challenge); game.set_encounter_rolls(0.0, 0.50, behavior_roll, 0.50, 0.50); game.arm_cast(); game.release_cast(0.50)
	game.fish = fish; game.behavior_roll = behavior_roll; game.catch_length_cm = snappedf(lerpf(fish.min_length_cm, fish.max_length_cm, 0.50), 0.1); game.fight_phase_offset = behavior_roll * (fish.run_seconds + fish.lull_seconds); game.state = FishingSession.State.HOOK_WINDOW; game.set_hook()
	return game
func _simulate_fight_policy(fish: FishDefinition, fps: int, policy: String, behavior_roll := 0.0, size_fraction := 0.50, challenge := FightChallenge.DEFAULT_ID) -> FishingSession:
	var game := _fight_session(fish, behavior_roll, challenge)
	game.catch_length_cm = snappedf(lerpf(fish.min_length_cm, fish.max_length_cm, size_fraction), 0.1)
	var delta := 1.0 / float(fps)
	var target := 0.82 if policy == "strong_reactive" else (0.62 if policy == "reactive" else (1.0 if policy == "hard" else 0.70))
	var delayed_sample: Dictionary = {"tension": game.tension, "tier": FightChallenge.tier(game.tension, game.live_challenge_profile), "low_warning": game.live_challenge_profile.low_warning, "high_warning": game.live_challenge_profile.high_warning}
	var next_decision := 0.10
	var tension_history: Array[Dictionary] = []
	for frame in range(50 * fps):
		if game.state != FishingSession.State.REELING: break
		tension_history.append({"at": game.fight_elapsed, "tension": game.tension, "tier": FightChallenge.tier(game.tension, game.live_challenge_profile), "low_warning": game.live_challenge_profile.low_warning, "high_warning": game.live_challenge_profile.high_warning})
		if policy in ["reactive", "strong_reactive"] and game.fight_elapsed >= next_decision:
			# A 300ms-old warning sample plus a 100ms load ramp models a human response.
			for sample in tension_history:
				if float(sample.at) <= game.fight_elapsed - 0.30: delayed_sample = sample
			var ease_target := 0.10 if policy == "strong_reactive" else 0.10
			var pull_target := 0.82 if policy == "strong_reactive" else 0.68
			# Decision is based on the 300ms-old heard/seen tier, never the current
			# profile after it has drifted under the simulated player's feet.
			var delayed_tier := str(delayed_sample.tier)
			target = ease_target if delayed_tier in ["ease", "snap"] else (pull_target if delayed_tier in ["pull", "slack"] else target)
			next_decision += 0.10
		var current := game.rod_load
		game.set_rod_load(move_toward(current, target, delta / 0.10))
		game.tick(delta)
	return game
func _test_pump_and_recover_fight() -> void:
	var timings: Dictionary = {}
	for fish in FishDefinition.all_planned():
		for challenge in FightChallenge.IDS:
			for fps in [30, 60, 120]:
				for behavior_roll in [0.0, 0.37, 0.83]:
					var reactive := _simulate_fight_policy(fish, fps, "reactive", behavior_roll, 0.50, challenge)
					var strong_reactive := _simulate_fight_policy(fish, fps, "strong_reactive", behavior_roll, 0.50, challenge)
					var hard := _simulate_fight_policy(fish, fps, "hard", behavior_roll, 0.50, challenge)
					var moderate := _simulate_fight_policy(fish, fps, "moderate", behavior_roll, 0.50, challenge)
					var ceiling := 20.0 if challenge == "standard" else 24.0
					# `fight_elapsed` is frame accumulation; 20.0000000000001 is the same
					# physical 20.0s boundary, not an extended timing allowance.
					expect(reactive.state == FishingSession.State.CAUGHT and reactive.fight_elapsed >= 10.0 and reactive.fight_elapsed <= ceiling + 0.000001, "300ms-delayed pull/ease lands %s for %s at %dHz / roll %.2f (state=%d elapsed=%.2f)" % [fish.id, challenge, fps, behavior_roll, reactive.state, reactive.fight_elapsed])
					expect(strong_reactive.state == FishingSession.State.CAUGHT and strong_reactive.fight_elapsed >= 10.0 and strong_reactive.fight_elapsed <= 24.0, "a stronger .82/.10 delayed pull/ease remains catch-capable for %s %s at %dHz / roll %.2f" % [challenge, fish.id, fps, behavior_roll])
					if challenge == "standard":
						expect(hard.state == FishingSession.State.ESCAPED or hard.fight_elapsed > reactive.fight_elapsed + 2.0, "constant hard pull underperforms responsive %s at %dHz" % [fish.id, fps])
						expect(moderate.state == FishingSession.State.ESCAPED or moderate.fight_elapsed > reactive.fight_elapsed + 1.0, "constant moderate pull underperforms responsive %s at %dHz" % [fish.id, fps])
					for policy_pair in [["reactive", reactive], ["strong", strong_reactive]]:
						var key := "%s_%s" % [challenge, policy_pair[0]]
						var value: float = float(policy_pair[1].fight_elapsed)
						if not timings.has(key): timings[key] = {"min": value, "max": value}
						else: timings[key].min = minf(float(timings[key].min), value); timings[key].max = maxf(float(timings[key].max), value)
		var upper_tail := _fight_session(fish, 0.37)
		upper_tail.catch_length_cm = snappedf(lerpf(fish.min_length_cm, fish.max_length_cm, 0.96), 0.1)
		var responsive_large := _simulate_fight_policy(fish, 60, "reactive", 0.37, 0.96)
		expect(upper_tail.catch_length_cm <= fish.max_length_cm and is_equal_approx(upper_tail.catch_length_cm, snappedf(upper_tail.catch_length_cm, 0.1)) and responsive_large.state == FishingSession.State.CAUGHT and responsive_large.fight_elapsed >= 10.0 and responsive_large.fight_elapsed <= 24.0, "upper-tail %s stays bounded, one-decimal precise, and modestly demanding" % fish.id)
	var staged := _fight_session(_fish_by_id("largemouth_bass"), 0.83)
	staged.fight_elapsed = 7.0; staged.fight_progress = 0.71; staged.tick(0.01)
	expect(staged.fight_stage == FishingSession.FightStage.LAST_SURGE and staged.last_surge_started and staged.last_surge_remaining > 0.0, "eligible behavior has one bounded perceptible last surge")
	staged.tick(0.40)
	expect(staged.last_surge_started and is_zero_approx(staged.last_surge_remaining) and staged.fight_stage != FishingSession.FightStage.LAST_SURGE, "last surge completes once rather than becoming an end-fight trap")
	staged.fight_progress = 0.93; staged.tick(0.01)
	expect(staged.fight_stage == FishingSession.FightStage.LANDING and staged.land_opportunity and staged.fight_effort <= 0.22, "landing stage is an explicit quiet opportunity")
	var pike := _fight_session(_fish_by_id("northern_pike"), 0.0)
	pike.tension = 0.82; pike.strain = 0.78; pike.set_rod_load(0.04)
	for frame in range(60): pike.tick(1.0 / 60.0)
	expect(pike.tension <= 0.66 and pike.strain < 0.60, "even a pike run visibly recovers within one second of lowering")
	var no_load := _fight_session(FishDefinition.bluegill()); no_load.set_rod_load(0.0); no_load.tick(5.0)
	expect(is_zero_approx(no_load.fight_progress), "no-load fight time never gains landing progress")
	var paused := _fight_session(FishDefinition.bluegill()); var before := paused.tension; paused.tick(0.0)
	expect(is_equal_approx(before, paused.tension) and is_zero_approx(paused.fight_elapsed), "zero-delta menu pause leaves fight state untouched")
	print("V35_FIGHT_TIMINGS %s" % JSON.stringify(timings))

func _test_fight_challenge_contract() -> void:
	var relaxed := FightChallenge.profile("relaxed")
	var standard := FightChallenge.profile("standard")
	var expert := FightChallenge.profile("expert")
	expect(float(relaxed.low_critical) < float(standard.low_critical) and float(standard.low_critical) < float(expert.low_critical) and float(relaxed.high_critical) > float(standard.high_critical) and float(standard.high_critical) > float(expert.high_critical), "challenge profiles narrow both red ends from Relaxed through Expert")
	expect(FightChallenge.tier(0.50, standard) == "steady" and FightChallenge.tier(0.05, standard) == "slack" and FightChallenge.tier(0.95, standard) == "snap", "shared profile provides middle, slack, and overload tiers")
	var snap := _fight_session(FishDefinition.bluegill()); snap.tension = 0.99; snap.set_rod_load(1.0)
	for frame in range(180):
		if snap.state == FishingSession.State.REELING: snap.tick(1.0 / 60.0)
	expect(snap.state == FishingSession.State.ESCAPED, "sustained high red exposure loses a fish after startup grace")
	var slack := _fight_session(FishDefinition.bluegill()); slack.tension = 0.0; slack.set_rod_load(0.0)
	for frame in range(240):
		if slack.state == FishingSession.State.REELING: slack.tick(1.0 / 60.0)
	expect(slack.state == FishingSession.State.ESCAPED, "sustained zero tension eventually loses a fish instead of being a free rest")
	var protected := _fight_session(FishDefinition.bluegill()); protected.fight_progress = 1.0; protected.fight_elapsed = FishingSession.MIN_LANDING_SECONDS; protected.tension = 0.0; protected.tick(0.01)
	expect(protected.state != FishingSession.State.CAUGHT, "landing is blocked at a red slack edge even before its escape dwell completes")
	var tight_landing := _fight_session(FishDefinition.bluegill()); tight_landing.fight_progress = 1.0; tight_landing.fight_elapsed = FishingSession.MIN_LANDING_SECONDS; tight_landing.tension = 0.99; tight_landing.tick(0.01)
	expect(tight_landing.state != FishingSession.State.CAUGHT, "landing is blocked at the high red edge before its escape dwell completes")
	var brief_ease := _fight_session(FishDefinition.bluegill()); brief_ease.set_rod_load(0.0); brief_ease.tension = 0.0
	for frame in range(75): brief_ease.tick(1.0 / 60.0)
	var slack_before_recovery := brief_ease.slack_elapsed; brief_ease.set_rod_load(0.72)
	for frame in range(75):
		if brief_ease.state == FishingSession.State.REELING: brief_ease.tick(1.0 / 60.0)
	expect(brief_ease.state == FishingSession.State.REELING and slack_before_recovery > 0.0 and brief_ease.tension > float(brief_ease.challenge_profile.low_critical), "a brief actual zero-load ease can physically pull tension back above the slack edge before the longer escape dwell")
	var opening_grace := _fight_session(FishDefinition.bluegill()); opening_grace.tension = 0.99; opening_grace.set_rod_load(1.0); opening_grace.tick(0.70)
	expect(opening_grace.state == FishingSession.State.REELING and is_zero_approx(opening_grace.red_elapsed) and is_zero_approx(opening_grace.slack_elapsed), "opening grace prevents immediate high or low exposure debt at hook entry")
	var cast := FishingSession.new(); cast.set_next_cast_challenge("expert"); cast.arm_cast(); cast.release_cast(0.6); var snapshotted := cast.challenge_id; cast.set_next_cast_challenge("relaxed")
	expect(snapshotted == "expert" and cast.challenge_id == "expert", "challenge selection snapshots on release and cannot change an active cast")
	var wait_a := FishingSession.new(); wait_a.set_encounter_rolls(0.2, 0.2, 0.2, 0.0, 0.10); wait_a.arm_cast(); wait_a.release_cast(0.5)
	var wait_b := FishingSession.new(); wait_b.set_encounter_rolls(0.2, 0.2, 0.2, 0.999, 0.70); wait_b.arm_cast(); wait_b.release_cast(0.5)
	expect(wait_a.bite_wait_seconds >= 5.0 and wait_b.bite_wait_seconds <= 14.0 and wait_b.bite_wait_seconds > wait_a.bite_wait_seconds and wait_a.shadow_visit_start >= 1.0 and wait_a.shadow_visit_start + wait_a.shadow_visit_duration < wait_a.bite_wait_seconds, "independent per-cast bite and wildlife rolls produce bounded waits and pass-bys before a later bite")
	var challenge_save := SaveService.new(); var invalid_challenge := challenge_save._migrate({"version": SaveService.VERSION, "settings": {"fight_challenge": "impossible"}}); var expert_challenge := challenge_save._migrate({"version": SaveService.VERSION, "settings": {"fight_challenge": "expert"}})
	expect(str(invalid_challenge.settings.fight_challenge) == "standard" and str(expert_challenge.settings.fight_challenge) == "expert", "save migration sanitizes challenge values while retaining valid profile selections")

func _test_save_round_trip() -> void:
	var path := "user://gate1-test-%d.json" % Time.get_ticks_usec()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var save = SaveService.new(path)
	expect(save.load_data().version == SaveService.VERSION, "missing save returns defaults")
	for fish in FishDefinition.all_planned():
		expect(int(save.data.catches.get(fish.id, -1)) == 0 and float(save.data.best_cm.get(fish.id, -1.0)) == 0.0, "new save has a zero record for " + fish.id)
	save.data.settings.sensitivity = 1.4
	save.data.settings.left_handed = true; save.data.selected_location_id = "cedar_river"; save.data.unlocked_location_ids = ["willow_pond", "pine_lake", "cedar_river"]
	save.data.motion_profile = _calibrated_motion().get_profile()
	save.data.calibrated = true
	save.record_bluegill(24.2)
	save.record_catch("northern_pike", 74.5)
	var restored = SaveService.new(path)
	restored.load_data()
	expect(float(restored.data.settings.sensitivity) == 1.4 and restored.data.settings.left_handed and restored.data.selected_location_id == "cedar_river", "save restores expanded settings and selected location")
	expect(int(restored.data.catches.bluegill) >= 1, "save restores catch count")
	expect(float(restored.data.best_cm.bluegill) >= 24.2, "save restores best fish")
	expect(int(restored.data.catches.northern_pike) == 1 and float(restored.data.best_cm.northern_pike) == 74.5, "generic record_catch persists every planned species")
	expect(restored.data.calibrated and SaveService.is_motion_profile_valid(restored.data.motion_profile), "save restores a validated motion profile")
	var legacy := FileAccess.open(path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "calibrated": true, "settings": {"sensitivity": 1.2, "haptics": false}, "catches": {"bluegill": 4}, "best_cm": {"bluegill": 29.5}}))
	legacy.close()
	var migrated := SaveService.new(path); migrated.load_data()
	expect(migrated.data.version == SaveService.VERSION and not migrated.data.calibrated and migrated.data.motion_profile.is_empty(), "v1 save migrates to uncalibrated without losing unsafe profile state")
	expect(float(migrated.data.settings.sensitivity) == 1.2 and not migrated.data.settings.haptics and int(migrated.data.catches.bluegill) == 4 and float(migrated.data.best_cm.bluegill) == 29.5 and int(migrated.data.catches.northern_pike) == 0, "v1 migration preserves settings/catch progress and adds zero planned records")
	var legacy_v4 := FileAccess.open(path, FileAccess.WRITE)
	legacy_v4.store_string(JSON.stringify({"version": 4, "calibrated": true, "settings": {"sensitivity": 1.3, "haptics": false, "reduced_motion": true, "left_handed": true}, "selected_location_id": "cedar_river", "motion_profile": _calibrated_motion().get_profile(), "catches": {"bluegill": 7}, "best_cm": {"bluegill": 30.5}}))
	legacy_v4.close()
	var migrated_v4 := SaveService.new(path); migrated_v4.load_data()
	expect(migrated_v4.data.version == SaveService.VERSION and int(migrated_v4.data.catches.bluegill) == 7 and is_equal_approx(float(migrated_v4.data.best_cm.bluegill), 30.5) and bool(migrated_v4.data.settings.left_handed) and bool(migrated_v4.data.settings.reduced_motion) and migrated_v4.data.selected_location_id == "cedar_river" and migrated_v4.data.calibrated and migrated_v4.data.catch_history.is_empty(), "v4 to v5 preserves aggregate/profile/settings without inventing catch dates")
	var legacy_v5 := FileAccess.open(path, FileAccess.WRITE)
	legacy_v5.store_string(JSON.stringify({"version": 5, "calibrated": true, "settings": {"sensitivity": 1.6, "haptics": false, "audio": false, "reduced_motion": true, "left_handed": true}, "selected_location_id": "cedar_river", "motion_profile": _calibrated_motion().get_profile(), "catches": {"bluegill": 8, "northern_pike": 2}, "best_cm": {"bluegill": 31.5, "northern_pike": 82.0}, "catch_history": [{"fish_id": "northern_pike", "length_cm": 82.0, "location_id": "cedar_river", "timestamp_utc": 1700000000, "fight_seconds": 22.5, "cast_distance_m": 31.0}]}))
	legacy_v5.close()
	var migrated_v5 := SaveService.new(path); migrated_v5.load_data(); migrated_v5.save_data()
	var reloaded_v5 := SaveService.new(path); reloaded_v5.load_data()
	expect(reloaded_v5.data.version == SaveService.VERSION and reloaded_v5.data.unlocked_location_ids == ["willow_pond", "pine_lake", "cedar_river"] and reloaded_v5.data.selected_location_id == "cedar_river" and is_equal_approx(float(reloaded_v5.data.settings.sensitivity), 1.6) and not bool(reloaded_v5.data.settings.haptics) and not bool(reloaded_v5.data.settings.audio) and bool(reloaded_v5.data.settings.reduced_motion) and bool(reloaded_v5.data.settings.left_handed) and reloaded_v5.data.calibrated and int(reloaded_v5.data.catches.northern_pike) == 2 and is_equal_approx(float(reloaded_v5.data.best_cm.northern_pike), 82.0) and reloaded_v5.data.catch_history.size() == 1, "genuine v5 saves grandfather three prior waters and preserve selected water, settings, calibration, totals, bests, and valid history through reload")
	var v6_before_waters := FileAccess.open(path, FileAccess.WRITE)
	v6_before_waters.store_string(JSON.stringify({"version": 6, "selected_location_id": "hatteras_inlet", "unlocked_location_ids": ["willow_pond", "pine_lake", "cedar_river", "hatteras_inlet"], "catches": {"bluegill": 4, "red_drum": 2}, "best_cm": {"bluegill": 29.5, "red_drum": 68.0}}))
	v6_before_waters.close()
	var migrated_v6 := SaveService.new(path); migrated_v6.load_data()
	expect(migrated_v6.data.version == SaveService.VERSION and migrated_v6.data.selected_location_id == "hatteras_inlet" and migrated_v6.data.unlocked_location_ids == ["willow_pond", "pine_lake", "cedar_river", "hatteras_inlet"] and int(migrated_v6.data.catches.bluegill) == 4 and int(migrated_v6.data.catches.common_snook) == 0 and is_zero_approx(float(migrated_v6.data.best_cm.atlantic_sailfish)), "v6 saves preserve earned original waters and progress while additive new catalog fields begin empty")
	var malformed_history := FileAccess.open(path, FileAccess.WRITE)
	malformed_history.store_string(JSON.stringify({"version": SaveService.VERSION, "catches": {"bluegill": 2}, "best_cm": {"bluegill": 25.0}, "catch_history": [{"fish_id": "bluegill", "length_cm": 25.04, "location_id": "pine_lake", "timestamp_utc": 1700000000, "fight_seconds": 11.26, "cast_distance_m": 21.24}, {"fish_id": "unknown", "length_cm": 99.0, "location_id": "pine_lake", "timestamp_utc": 1700000001}, {"fish_id": "bluegill", "length_cm": 0.0, "location_id": "pine_lake", "timestamp_utc": 1700000002}, {"fish_id": "bluegill", "length_cm": 18.0, "location_id": "ocean", "timestamp_utc": 1700000003}, {"fish_id": "bluegill", "length_cm": 18.0, "location_id": "pine_lake", "timestamp_utc": 0}]}))
	malformed_history.close()
	var sanitized_history := SaveService.new(path); sanitized_history.load_data()
	expect(sanitized_history.data.catch_history.size() == 1 and is_equal_approx(float(sanitized_history.data.catch_history[0].length_cm), 25.0) and is_equal_approx(float(sanitized_history.data.catch_history[0].fight_seconds), 11.3) and is_equal_approx(float(sanitized_history.data.catch_history[0].cast_distance_m), 21.2), "v5 reload discards malformed history and sanitizes valid bounded fields")
	var invalid := FileAccess.open(path, FileAccess.WRITE)
	invalid.store_string(JSON.stringify({"version": SaveService.VERSION, "settings": {"sensitivity": 1.1}, "catches": {"bluegill": 6}, "best_cm": {"bluegill": 30.0}, "motion_profile": {"forward_axis": [1.0, 0.0, 0.0], "back_peak": 0.1, "forward_peak": 5.0}}))
	invalid.close()
	var invalid_restored := SaveService.new(path); invalid_restored.load_data()
	expect(not invalid_restored.data.calibrated and invalid_restored.data.motion_profile.is_empty() and int(invalid_restored.data.catches.bluegill) == 6, "invalid motion profiles recalibrate without losing progress")
	var typed_corrupt := FileAccess.open(path, FileAccess.WRITE)
	typed_corrupt.store_string(JSON.stringify({"version": {}, "settings": {"sensitivity": "fast", "haptics": [], "audio": 1, "reduced_motion": null}, "motion_profile": {"forward_axis": [1.0, {}, "not-a-number"], "back_peak": [], "forward_peak": 2.0}, "catches": {"pumpkinseed": 2, "bluegill": {}, "red_drum": []}, "best_cm": {"pumpkinseed": 22.0, "bluegill": "huge"}, "unlocked_location_ids": {}, "catch_history": [{"fish_id": "bluegill", "length_cm": 21.0, "location_id": "pine_lake", "timestamp_utc": 1700000000, "fight_seconds": {}, "cast_distance_m": []}]}))
	typed_corrupt.close()
	var typed_restored := SaveService.new(path); typed_restored.load_data()
	expect(typed_restored.data.version == SaveService.VERSION and typed_restored.data.selected_location_id == "willow_pond" and typed_restored.data.unlocked_location_ids == ["willow_pond"] and is_equal_approx(float(typed_restored.data.settings.sensitivity), 1.0) and bool(typed_restored.data.settings.haptics) and int(typed_restored.data.catches.pumpkinseed) == 2 and int(typed_restored.data.catches.bluegill) == 0 and typed_restored.data.catch_history.size() == 1 and is_zero_approx(float(typed_restored.data.catch_history[0].fight_seconds)) and is_zero_approx(float(typed_restored.data.catch_history[0].cast_distance_m)), "corrupt v6 numeric/settings/profile values cannot throw, fake legacy state, or discard independently valid totals/history")
	var nonfinite_migrated := SaveService.new(path)._migrate({"version": NAN, "settings": {"sensitivity": INF}, "catches": {"bluegill": NAN}, "best_cm": {"bluegill": INF}})
	expect(nonfinite_migrated.selected_location_id == "willow_pond" and is_equal_approx(float(nonfinite_migrated.settings.sensitivity), 1.0) and int(nonfinite_migrated.catches.bluegill) == 0 and is_zero_approx(float(nonfinite_migrated.best_cm.bluegill)), "nonfinite in-memory parsed values are rejected before numeric conversion")
	var corrupt := FileAccess.open(path, FileAccess.WRITE); corrupt.store_string("not json"); corrupt.close()
	expect(SaveService.new(path).load_data().version == SaveService.VERSION, "corrupt save falls back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_catch_record_progression() -> void:
	var path := "user://catch-progress-%d.json" % Time.get_ticks_usec()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var catch_save := SaveService.new(path); catch_save.load_data()
	catch_save.record_catch("largemouth_bass", 31.5)
	expect(int(catch_save.data.catches.largemouth_bass) == 1 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 31.5), "first catch stores one catch and its initial best")
	catch_save.record_catch("largemouth_bass", 31.5)
	expect(int(catch_save.data.catches.largemouth_bass) == 2 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 31.5), "exact tied length increments once without changing the saved best")
	catch_save.record_catch("largemouth_bass", 31.46)
	expect(int(catch_save.data.catches.largemouth_bass) == 3 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 31.5), "lower catch increments count without replacing the saved best")
	catch_save.record_catch("largemouth_bass", 31.54)
	expect(int(catch_save.data.catches.largemouth_bass) == 4 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 31.54) and is_equal_approx(snappedf(31.54, 0.1), snappedf(31.5, 0.1)), "near-tie keeps precise saved best while presentation can compare the same one-decimal value")
	catch_save.record_catch("largemouth_bass", 32.1)
	expect(int(catch_save.data.catches.largemouth_bass) == 5 and is_equal_approx(float(catch_save.data.best_cm.largemouth_bass), 32.1), "higher catch replaces best after preserving all prior catches")
	var history_save := SaveService.new(path, func() -> int: return 1700000000); history_save.load_data()
	history_save.record_catch("bluegill", 22.4, {"location_id": "pine_lake", "fight_seconds": 13.2, "cast_distance_m": 18.0})
	var blue_history := history_save.history_for_fish("bluegill")
	expect(blue_history.size() == 1 and int(blue_history[0].timestamp_utc) == 1700000000 and is_equal_approx(float(blue_history[0].fight_seconds), 13.2), "recent catch history records injected UTC, water, fight time, and cast distance")
	var reloaded_history := SaveService.new(path); reloaded_history.load_data()
	expect(reloaded_history.history_for_fish("bluegill").size() == 1 and int(reloaded_history.history_for_fish("bluegill")[0].timestamp_utc) == 1700000000, "persisted recent history reloads without changing its aggregate catch record")
	for index in range(SaveService.MAX_CATCH_HISTORY + 3): history_save.record_catch("bluegill", 18.0 + index * 0.01, {"location_id": "pine_lake", "fight_seconds": 10.0, "cast_distance_m": 12.0})
	expect(history_save.history_for_fish("bluegill").size() == SaveService.MAX_CATCH_HISTORY, "recent history is bounded while aggregate totals remain unbounded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fish_by_id(fish_id: String) -> FishDefinition:
	for fish in FishDefinition.all_planned():
		if fish.id == fish_id: return fish
	return FishDefinition.bluegill()

func _test_waters_catalog_and_unlocks() -> void:
	var fresh := SaveService.default_data()
	expect(fresh.selected_location_id == "willow_pond" and fresh.unlocked_location_ids == ["willow_pond"] and FishDefinition.all_planned().size() == 24, "fresh v6 save starts at Willow and the catalog contains all twenty-four fish")
	var catalog_location_ids := {}; var catalog_fish_ids := {}
	for location in LocationDefinition.all():
		var location_id := str(location.get("id", "")); var species: Array = location.get("species_ids", [])
		catalog_location_ids[location_id] = true
		for fish_id in species: catalog_fish_ids[str(fish_id)] = true
		expect(location_id in SaveService.LOCATION_IDS and species.size() == 3 and LocationDefinition.by_id(location_id) == location, "catalog location has one known ID and exactly three listed species: %s" % location_id)
	expect(catalog_location_ids.size() == 8 and catalog_fish_ids.size() == 24 and catalog_fish_ids.keys().all(func(fish_id): return fish_id in SaveService.PLANNED_FISH_IDS), "catalog location and fish membership is unique and complete")
	for location_id in SaveService.LOCATION_IDS:
		for distance in [12.0, 24.0, 36.0]:
			var seen := {}
			for roll_step in range(40): seen[FishDefinition.select_weighted(location_id, float(roll_step) / 40.0, distance).id] = true
			expect(seen.size() == 3, "every %s species is reachable in its %.0fm band" % [location_id, distance])
	var progress := SaveService.new("user://waters-unlock-%d.json" % Time.get_ticks_usec()); progress.data = SaveService.default_data()
	progress.record_catch("pumpkinseed", 18.0); progress.record_catch("pumpkinseed", 18.0); progress.record_catch("black_crappie", 25.0)
	expect(not "pine_lake" in progress.data.unlocked_location_ids, "duplicates do not bypass the every-species Pine unlock")
	progress.record_catch("brown_bullhead", 32.0)
	expect("pine_lake" in progress.data.unlocked_location_ids and not "cedar_river" in progress.data.unlocked_location_ids, "one landed catch of every earlier fish unlocks only the next water")
	for fish_id in ["bluegill", "largemouth_bass", "channel_catfish"]: progress.record_catch(fish_id, 35.0)
	expect("cedar_river" in progress.data.unlocked_location_ids and not "hatteras_inlet" in progress.data.unlocked_location_ids, "all six prior species unlock Cedar but not Hatteras")
	for fish_id in ["rainbow_trout", "smallmouth_bass", "northern_pike"]: progress.record_catch(fish_id, 35.0)
	expect("hatteras_inlet" in progress.data.unlocked_location_ids and not "mangrove_flats" in progress.data.unlocked_location_ids, "all nine earlier fish unlock Hatteras without fake catches")
	for fish_id in ["red_drum", "spotted_seatrout", "bluefish"]: progress.record_catch(fish_id, 55.0)
	expect("mangrove_flats" in progress.data.unlocked_location_ids and not "cypress_bayou" in progress.data.unlocked_location_ids, "all twelve prior species unlock Mangrove Flats without inventing a new catch")
	for fish_id in ["common_snook", "mangrove_snapper", "atlantic_tarpon"]: progress.record_catch(fish_id, 75.0)
	expect("cypress_bayou" in progress.data.unlocked_location_ids and not "moonlit_reservoir" in progress.data.unlocked_location_ids, "all fifteen prior species unlock Cypress Bayou")
	for fish_id in ["bowfin", "longnose_gar", "flathead_catfish"]: progress.record_catch(fish_id, 75.0)
	expect("moonlit_reservoir" in progress.data.unlocked_location_ids and not "bluewater_offshore" in progress.data.unlocked_location_ids, "all eighteen prior species unlock Moonlit Reservoir")
	for fish_id in ["walleye", "striped_bass", "blue_catfish"]: progress.record_catch(fish_id, 75.0)
	expect("bluewater_offshore" in progress.data.unlocked_location_ids, "all twenty-one prior species unlock Bluewater Offshore")
	var reloaded_progress := SaveService.new(progress.path); reloaded_progress.load_data()
	expect(reloaded_progress.data.unlocked_location_ids == SaveService.LOCATION_IDS, "earned eight-water unlocks persist after reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))

func _test_ui_presentation_contract() -> void:
	expect(GameMain.catch_status_for(0, 0.0, 24.0).begins_with("FIRST CATCH"), "first catch presentation is distinct")
	expect(GameMain.catch_status_for(2, 31.5, 31.5).begins_with("MATCHED BEST"), "exact displayed tie does not claim a new best")
	expect(GameMain.catch_status_for(2, 31.5, 31.54).begins_with("MATCHED BEST"), "one-decimal near-tie does not claim a hidden-precision new best")
	expect(GameMain.catch_status_for(2, 31.5, 31.6).begins_with("NEW BEST"), "larger displayed catch claims a new best")
	expect(GameMain.catch_status_for(2, 31.5, 30.0).begins_with("3 CAUGHT"), "lower catch preserves the existing displayed best")
	var min_landed := GameMain.presentation_bobber_y(FishingSession.MIN_CAST_DISTANCE_M, 0.0, false, 1.0)
	var mid_landed := GameMain.presentation_bobber_y(24.0, 0.0, false, 1.0)
	var max_landed := GameMain.presentation_bobber_y(FishingSession.MAX_CAST_DISTANCE_M, 0.0, false, 1.0)
	expect(max_landed < mid_landed and mid_landed < min_landed, "farther casts place the landed bobber farther up the water")
	expect(GameMain.presentation_bobber_y(FishingSession.MIN_CAST_DISTANCE_M, 1.0, true, 1.0) > min_landed and GameMain.presentation_bobber_y(FishingSession.MAX_CAST_DISTANCE_M, 1.0, true, 1.0) > max_landed, "fight progress brings every landed bobber nearer the rod")
	expect(is_equal_approx(mid_landed, 595.0), "reduced motion uses the settled logical landing endpoint without travel animation")
	for location_id in ["willow_pond", "pine_lake", "cedar_river", "hatteras_inlet"]:
		var near_water := GameMain.presentation_bobber_y(FishingSession.MIN_CAST_DISTANCE_M, 0.0, false, 1.0, location_id)
		var mid_water := GameMain.presentation_bobber_y(24.0, 0.0, false, 1.0, location_id)
		var far_water := GameMain.presentation_bobber_y(FishingSession.MAX_CAST_DISTANCE_M, 0.0, false, 1.0, location_id)
		expect(near_water > mid_water and mid_water > far_water and far_water >= (570.0 if location_id == "willow_pond" else 410.0), "presentation bobber endpoints stay ordered in the open-water band for %s" % location_id)
	expect(GameMain.accepts_primary_press(true, true, true, 0) and not GameMain.accepts_primary_press(false, true, true, InputEvent.DEVICE_ID_EMULATION), "raw touch dispatches once while the matching emulated mouse press is ignored")
	expect(GameMain.accepts_primary_press(false, true, true, 0) and not GameMain.accepts_primary_press(false, true, false, 0) and not GameMain.accepts_primary_press(false, false, true, 0), "desktop primary click dispatches once while right-click and release are inert")
	var terminal := FishingSession.new(); terminal.state = FishingSession.State.CAUGHT
	expect(terminal.set_location("cedar_river", 0.0), "terminal state can select a new water before the controller resets its presentation")
	terminal.reset(); expect(terminal.state == FishingSession.State.READY and terminal.set_location("cedar_river", 0.0) and terminal.location_id == "cedar_river", "water selection resets terminal catch state without touching saved records")
	var armed := FishingSession.new(); armed.arm_cast(); armed.cancel_cast()
	expect(armed.state == FishingSession.State.READY, "opening a pause menu can cancel an armed cast before it leaves a stale snap prompt")

func _test_ui_controller_interactions() -> void:
	var controller := GameMain.new()
	controller.session = FishingSession.new(); controller.motion = MotionService.new(); controller.haptics = HapticService.new(); controller.preview_haptics = HapticService.new(); controller.cast_capture = CastCaptureService.new("user://ui-controller-capture-%d.json" % Time.get_ticks_usec(), Callable(controller.motion, "sample"))
	controller.save = SaveService.new("user://ui-controller-%d.json" % Time.get_ticks_usec()); controller.save.data = SaveService.default_data()
	var view = GameMain.FishingView.new(); view.controller = controller; view.size = Vector2(720, 1280); view.font = ThemeDB.fallback_font; view.metal_header_font = FontVariation.new(); view.metal_header_font.base_font = load("res://art/fonts/cinzel/Cinzel[wght].ttf") as Font; view.metal_header_font.variation_opentype = {"wght": 680}; controller.view = view
	controller.session.fish = _fish_by_id("pumpkinseed"); controller.session.catch_length_cm = 20.0; controller.session.state = FishingSession.State.REELING; controller.caught_recorded = false; controller._record_catch_once()
	expect(int(controller.save.data.catches.pumpkinseed) == 0, "hooked or reeling fish cannot persist a catch or unlock progress")
	controller.save.record_catch("pumpkinseed", 20.0); controller.save.record_catch("black_crappie", 29.0)
	controller.session.fish = _fish_by_id("brown_bullhead"); controller.session.catch_length_cm = 34.0; controller.session.state = FishingSession.State.CAUGHT; controller.caught_recorded = false; controller.ui_notice = ""; controller._record_catch_once(); controller._record_catch_once()
	expect(int(controller.save.data.catches.brown_bullhead) == 1 and "pine lake unlocked" in controller.ui_notice.to_lower(), "terminal final pond catch records once and announces the newly earned Pine unlock")
	controller.session.state = FishingSession.State.READY; view.overlay = "settings"; view._refresh_modal_layout(); var challenge_before := str(controller.save.data.settings.fight_challenge); view._handle_press(view.settings_challenge_rect.get_center())
	var reloaded_challenge_save := SaveService.new(controller.save.path); reloaded_challenge_save.load_data()
	expect(str(controller.save.data.settings.fight_challenge) != challenge_before and controller.ui_notice.contains("NEXT CAST") and str(reloaded_challenge_save.data.settings.fight_challenge) == str(controller.save.data.settings.fight_challenge), "Settings fight-challenge row persists the selected next-cast profile across a reload")
	expect(is_equal_approx(view.tension_meter_value(-0.2), 0.0) and is_equal_approx(view.tension_meter_value(1.4), 1.0) and view.tension_status(0.12) == "SLACK" and view.tension_status(0.50) == "STEADY" and view.tension_status(0.75) == "EASE" and view.tension_status(0.90) == "TOO TIGHT", "tension meter clamps its fill/marker and exposes standard slack, middle, ease, and tight bands")
	for tension_safe_top in [0.0, 91.0, 180.0]:
		view.safe_top_override = tension_safe_top; view._refresh_tension_meter_geometry()
		var bar_end: float = tension_safe_top + 108.0
		var label_baseline: float = view.tension_meter_rect.position.y - 11.0
		expect(view.tension_meter_rect.position.y == tension_safe_top + 146.0 and label_baseline > bar_end and view.tension_meter_rect.end.x <= 720.0 and view.tension_meter_rect.end.y <= 1280.0, "tension label and meter clear the full shared header at %.0f" % tension_safe_top)
	var fight_visible := FishingSession.new(); fight_visible.state = FishingSession.State.REELING; view.overlay = ""
	expect(view.should_draw_tension_meter(fight_visible), "tension meter is visible only during live reeling")
	view.overlay = "settings"; expect(not view.should_draw_tension_meter(fight_visible), "ordinary overlays suppress the tension meter")
	view.overlay = ""
	for safe_top in [0.0, 91.0, 180.0]:
		controller.session.state = FishingSession.State.READY
		view.safe_top_override = safe_top; view.overlay = ""; view._refresh_top_nav_geometry()
		var engraved_points := [Vector2(440.0, safe_top + 60.0), Vector2(539.0, safe_top + 60.0), Vector2(637.0, safe_top + 60.0)]
		expect(view.records_rect.has_point(engraved_points[0]) and view.locations_rect.has_point(engraved_points[1]) and view.settings_rect.has_point(engraved_points[2]), "shared top-nav hit bounds contain the rendered ledger/map/gear plaque interiors at safe-top %.0f" % safe_top)
		view._handle_press(engraved_points[0])
		expect(view.overlay == "records", "engraved ledger plaque opens Records through the shared current geometry at safe-top %.0f" % safe_top)
		view.overlay = ""; view._handle_press(engraved_points[1])
		expect(view.overlay == "locations", "engraved map plaque opens Waters through the shared current geometry at safe-top %.0f" % safe_top)
		view.overlay = ""; view._handle_press(engraved_points[2])
		expect(view.overlay == "settings", "Settings press routes through its current shared safe-top target at %.0f" % safe_top)
		view._refresh_modal_layout()
		var controls := [view.settings_haptics_rect, view.settings_reduced_motion_rect, view.settings_handedness_rect, view.settings_challenge_rect, view.settings_test_haptics_rect, view.settings_motion_setup_rect, view.settings_footer_close_rect]
		var all_inside: bool = view.modal_panel_rect.end.y <= 1280.0 and view.settings_footer_close_rect.position.y >= view.modal_panel_rect.position.y and view.settings_footer_close_rect.end.y <= view.modal_panel_rect.end.y and view.settings_footer_close_rect.size.y >= 64.0 and view.settings_footer_close_rect == view.modal_footer_rect
		for control_index in range(controls.size()):
			all_inside = all_inside and controls[control_index].position.x >= view.modal_panel_rect.position.x and controls[control_index].end.x <= view.modal_panel_rect.end.x and controls[control_index].position.y >= safe_top and controls[control_index].end.y <= view.modal_panel_rect.end.y
			for later_index in range(control_index + 1, controls.size()): all_inside = all_inside and not controls[control_index].intersects(controls[later_index])
		expect(all_inside and view.settings_test_haptics_rect.position.y >= view.modal_panel_rect.position.y + 490.0 and view.settings_motion_setup_rect.position.y >= view.modal_panel_rect.position.y + 590.0, "safe-aware Settings layout keeps one baked footer target and clear nonoverlapping controls at %.0f" % safe_top)
		view._handle_press(view.settings_footer_close_rect.get_center())
		expect(view.overlay == "", "current Settings baked-footer target closes exactly once at safe-top %.0f" % safe_top)
		controller._close_overlay()
		view.overlay = ""; view._handle_press(view.settings_rect.position - Vector2(1, 1)); expect(view.overlay == "", "nav boundary outside is inert at safe-top %.0f" % safe_top)
	# Every normal state draws and routes through the same safe-area wood rail.  The
	# active pair stays visibly present but preserves the existing notice-only gate.
	for header_safe_top in [0.0, 91.0, 180.0]:
		view.safe_top_override = header_safe_top
		var clear_plaque := Rect2(70, header_safe_top + 30, 280, 64)
		var title_rect := view._top_location_title_rect(false)
		var quiet_title_rect := view._top_location_title_rect(true)
		var hint_rect := view._top_hint_rect(1)
		var title_bounds_valid: bool = clear_plaque.encloses(title_rect) and clear_plaque.encloses(quiet_title_rect) and clear_plaque.encloses(hint_rect) and not title_rect.intersects(hint_rect)
		for location_name in ["WILLOW POND", "PINE LAKE", "CEDAR RIVER", "HATTERAS INLET"]:
			var metal_size: int = view._metal_location_font_size(location_name, title_rect.size.x - 6.0)
			var metal_width: float = view.metal_header_font.get_string_size(location_name, HORIZONTAL_ALIGNMENT_LEFT, -1, metal_size).x
			title_bounds_valid = title_bounds_valid and metal_width <= title_rect.size.x - 6.0
		expect(title_bounds_valid and view.metal_header_font.base_font != null, "metal location headers and compact native hints stay within the left wood clear span at safe-top %.0f" % header_safe_top)
		for header_state in [FishingSession.State.READY, FishingSession.State.CAST_ARMED, FishingSession.State.LINE_OUT, FishingSession.State.BITE, FishingSession.State.HOOK_WINDOW, FishingSession.State.REELING, FishingSession.State.CAUGHT, FishingSession.State.ESCAPED]:
			controller.session.state = header_state; view.overlay = ""; view.safe_top_override = header_safe_top; view._refresh_top_nav_geometry()
			var expected_rail := Rect2(0, header_safe_top, 720, 108)
			var fixed_icons: bool = view.records_rect == Rect2(398, header_safe_top + 17, 85, 86) and view.locations_rect == Rect2(496, header_safe_top + 17, 87, 86) and view.settings_rect == Rect2(594, header_safe_top + 17, 86, 86)
			expect(view.top_nav_strip_rect == expected_rail and fixed_icons, "all normal fishing states retain one full rail and fixed icon targets at safe-top %.0f" % header_safe_top)
		controller.session.state = FishingSession.State.LINE_OUT; view.overlay = ""; view.safe_top_override = header_safe_top; controller.ui_notice = ""; controller.ui_notice_remaining = 0.0; view._handle_press(view.records_rect.get_center())
		expect(view.overlay == "" and controller.ui_notice == "FINISH THIS CAST", "active Records stays visibly locked and notice-gated at safe-top %.0f" % header_safe_top)
		controller.ui_notice = ""; controller.ui_notice_remaining = 0.0; view._handle_press(view.locations_rect.get_center())
		expect(view.overlay == "" and controller.ui_notice == "FINISH THIS CAST", "active Waters stays visibly locked and notice-gated at safe-top %.0f" % header_safe_top)
		view._handle_press(view.settings_rect.get_center())
		expect(view.overlay == "settings", "fixed active-fishing Settings target remains routable at safe-top %.0f" % header_safe_top)
		controller._close_overlay()
		controller.session.state = FishingSession.State.CAUGHT; view.overlay = ""; view._refresh_top_nav_geometry(); view._handle_press(view.records_rect.get_center())
		expect(view.overlay == "records", "terminal catch exposes its fixed Records target at safe-top %.0f" % header_safe_top)
	controller.session.state = FishingSession.State.READY; view.overlay = ""; view.safe_top_override = 0.0
	view.safe_top_override = 180.0; view.overlay = "motion_setup"; view._refresh_modal_layout()
	var motion_controls := [view.motion_sensitivity_rect, view.motion_recalibrate_rect, view.motion_capture_rect, view.motion_diagnostics_rect, view.motion_back_rect]
	var motion_inside: bool = view.motion_back_rect == view.modal_footer_rect and view.motion_back_rect.size.y >= 64.0
	for motion_index in range(motion_controls.size()):
		motion_inside = motion_inside and view.modal_panel_rect.encloses(motion_controls[motion_index])
		for later_motion_index in range(motion_index + 1, motion_controls.size()): motion_inside = motion_inside and not motion_controls[motion_index].intersects(motion_controls[later_motion_index])
	expect(motion_inside, "Motion Setup uses the same safe-aware baked footer geometry at safe-top 180")
	var motion_title_width: float = view.font.get_string_size("MOTION SETUP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var motion_footer_size: int = view._modal_footer_font_size("BACK TO MOTION SETUP")
	var motion_footer_width: float = view.font.get_string_size("BACK TO MOTION SETUP", HORIZONTAL_ALIGNMENT_LEFT, -1, motion_footer_size).x
	expect(motion_title_width <= view.modal_header_rect.size.x - 100.0 and motion_footer_width <= view.modal_footer_rect.size.x - 96.0, "Motion Setup title and long return label fit inside the baked plaque clear spans at safe-top 180 (title=%.1f footer=%d/%.1f)" % [motion_title_width, motion_footer_size, motion_footer_width])
	view._handle_press(view.motion_back_rect.get_center()); expect(view.overlay == "settings", "Motion Setup footer routes through the current baked-footer target")
	view.overlay = "diagnostics"; view._refresh_modal_layout(); view._handle_press(view.motion_back_rect.get_center())
	expect(view.overlay == "motion_setup", "Diagnostics returns through the refreshed shared motion footer target")
	view.overlay = "capture_saved"; view._refresh_modal_layout(); view._handle_press(view.motion_back_rect.get_center())
	expect(view.overlay == "motion_setup", "Saved capture returns through the refreshed shared motion footer target")
	view.safe_top_override = 0.0; view.overlay = "settings"; view._refresh_modal_layout()
	var fixed_footer: Rect2 = view.settings_footer_close_rect
	view.safe_top_override = 180.0; view.overlay = "settings"
	view._handle_press(fixed_footer.get_center())
	expect(view.overlay == "", "full-source Settings footer remains the current routable target after an immediate safe-top change")
	for world_safe_top in [0.0, 91.0, 180.0]:
		view.safe_top_override = world_safe_top; view.overlay = "world_records"; view._refresh_world_records_geometry()
		var world_rows_valid: bool = view.world_status_rect.position.y >= world_safe_top and view.world_status_rect.end.y < view.world_row_rects[0].position.y and view.world_row_rects[5].end.y < view.world_retry_rect.position.y
		for row in view.world_row_rects: world_rows_valid = world_rows_valid and row.position.y >= world_safe_top and row.end.y <= view.world_retry_rect.position.y
		expect(world_rows_valid and view.world_retry_rect.end.y <= view.world_back_rect.position.y and view.world_period_rect.end.y <= view.world_back_rect.position.y and not view.world_retry_rect.intersects(view.world_period_rect) and view.world_back_rect == view.modal_footer_rect, "World Records shared geometry keeps paper rows and controls separate at safe-top %.0f" % world_safe_top)
	for records_safe_top in [0.0, 91.0, 180.0]:
		view.safe_top_override = records_safe_top; view.overlay = "records"; view._refresh_records_geometry(records_safe_top)
		var page := view._journal_page_rect(records_safe_top)
		var record_bounds_valid: bool = view.records_world_rect.position.y >= records_safe_top and view.back_to_fishing_rect.position.y >= records_safe_top and view.records_world_rect.end.y <= page.end.y and view.back_to_fishing_rect.end.y <= page.end.y
		for index in range(view.journal_slot_rects.size()):
			record_bounds_valid = record_bounds_valid and page.encloses(view.journal_fish_rects[index]) and page.encloses(view.journal_name_rects[index]) and page.encloses(view.journal_stats_rects[index]) and view.journal_slot_rects[index].has_point(view.journal_fish_rects[index].get_center()) and view.journal_slot_rects[index].has_point(view.journal_name_rects[index].get_center()) and view.journal_slot_rects[index].has_point(view.journal_stats_rects[index].get_center())
		expect(record_bounds_valid, "Records fish, wood-name, paper-stats, footer, and union targets share the safe-top %.0f page transform" % records_safe_top)
		view._handle_press(view.journal_stats_rects[0].get_center()); expect(view.overlay == "journal_detail", "Records stat strip routes through its shared union target at safe-top %.0f" % records_safe_top)
		view.overlay = "records"; view._handle_press(view.records_world_rect.get_center()); expect(view.overlay == "world_records", "Records World footer routes through shared geometry at safe-top %.0f" % records_safe_top)
		view.overlay = "records"; view._handle_press(view.back_to_fishing_rect.get_center()); expect(view.overlay == "", "Records Back footer routes through shared geometry at safe-top %.0f" % records_safe_top)
	view.safe_top_override = 0.0; view.overlay = "records"; view.journal_page_index = 0; view._refresh_records_geometry(0.0)
	view._handle_press(view.records_next_rect.get_center())
	expect(view.journal_page_index == 1, "Records next-page control exposes the second six-fish page")
	view._refresh_records_geometry(0.0); view._handle_press(view.journal_slot_rects[0].get_center())
	expect(view.overlay == "journal_detail" and view.journal_fish_id == FishDefinition.all_planned()[6].id, "Records page two opens the seventh catalog fish without out-of-bounds indexing")
	view.overlay = "records"; view._refresh_records_geometry(0.0); view._handle_press(view.records_next_rect.get_center()); view._handle_press(view.records_next_rect.get_center())
	expect(view.journal_page_index == 3, "Records reaches the fourth six-fish page")
	view._refresh_records_geometry(0.0); view._handle_press(view.journal_slot_rects[2].get_center())
	expect(view.overlay == "journal_detail" and view.journal_fish_id == FishDefinition.all_planned()[20].id, "Records page four opens the twenty-first catalog fish")
	view.overlay = "records"; view._refresh_records_geometry(0.0); view._handle_press(view.records_next_rect.get_center())
	expect(view.journal_page_index == 3, "Records next-page control is clamped on the fourth and final page")
	view._handle_press(view.records_previous_rect.get_center())
	expect(view.journal_page_index == 2, "Records previous-page control returns from page four")
	for notes_safe_top in [0.0, 91.0, 180.0]:
		view.safe_top_override = notes_safe_top; view.overlay = "journal_detail"; view._refresh_field_notes_geometry()
		var notes_valid: bool = view.journal_detail_fish_rect.position.y >= notes_safe_top and view.journal_detail_note_rect.end.y < view.journal_detail_back_rect.position.y and not view.journal_detail_back_rect.intersects(view.journal_detail_next_rect)
		expect(notes_valid, "Field Notes contained history and two action targets remain clear at safe-top %.0f" % notes_safe_top)
		view._handle_press(view.journal_detail_back_rect.get_center()); expect(view.overlay == "records", "Field Notes Back routes through its shared current geometry at safe-top %.0f" % notes_safe_top)
	view.safe_top_override = 0.0
	var world_bridge := MockPlayGamesBridge.new(); controller.leaderboards = LeaderboardService.new(world_bridge, _leaderboard_config())
	view.overlay = "world_records"; view.world_page_index = 0; view._refresh_world_records_geometry(); view._handle_press(view.world_next_rect.get_center())
	expect(view.world_page_index == 1, "World Records next-page control exposes the second six-fish page")
	view._handle_press(view.world_next_rect.get_center()); view._handle_press(view.world_next_rect.get_center()); expect(view.world_page_index == 3, "World Records reaches its fourth six-fish page")
	view._handle_press(view.world_next_rect.get_center()); expect(view.world_page_index == 3, "World Records next-page control is clamped on the fourth and final page")
	view._handle_press(view.world_previous_rect.get_center()); expect(view.world_page_index == 2, "World Records previous-page control returns from page four")
	view.overlay = "world_records"; controller.leaderboards.status = LeaderboardService.STATUS_NO_AUTH; view._refresh_world_records_geometry(); view._handle_press(view.world_retry_rect.get_center())
	expect(not world_bridge.calls.is_empty() and str(world_bridge.calls.back().method) == "signIn", "World Connect invokes explicit sign-in only from NO_AUTH")
	controller.leaderboards.status = LeaderboardService.STATUS_ERROR; view.overlay = "world_records"; view._refresh_world_records_geometry(); view._handle_press(view.world_retry_rect.get_center())
	expect(str(world_bridge.calls.back().method) in ["initialize", "isAuthenticated"], "World Retry reopens records for an offline/error state")
	controller.leaderboards = null; view.overlay = "world_records"; view._refresh_world_records_geometry(); view._handle_press(view.world_retry_rect.get_center())
	expect(view.overlay == "world_records", "World retry stays inert when no native bridge is present")
	var long_name := "ANUNBROKENONLINEANGLERHANDLETHATCANNOTFIT"
	var compact_name := view._fit_text(long_name, 120.0, 11)
	expect(compact_name.ends_with("…") and view.font.get_string_size(compact_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 120.0, "World Records character-ellipsizes a long unbroken online name")
	view.safe_top_override = 0.0; view.overlay = "settings"; view._refresh_modal_layout()
	var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.index = 0; touch.device = 0; touch.position = view.settings_haptics_rect.get_center()
	var emulated_mouse := InputEventMouseButton.new(); emulated_mouse.pressed = true; emulated_mouse.button_index = MOUSE_BUTTON_LEFT; emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION; emulated_mouse.position = touch.position
	var original_haptics := bool(controller.save.data.settings.haptics); view._gui_input(touch); view._gui_input(emulated_mouse)
	expect(bool(controller.save.data.settings.haptics) != original_haptics, "raw touch plus matching emulated mouse toggles a Settings control exactly once")
	var right_click := InputEventMouseButton.new(); right_click.pressed = true; right_click.button_index = MOUSE_BUTTON_RIGHT; right_click.device = 0; right_click.position = touch.position; var after_touch := bool(controller.save.data.settings.haptics); view._gui_input(right_click)
	expect(bool(controller.save.data.settings.haptics) == after_touch, "right click is inert on Settings targets")
	view._handle_press(Vector2(90, 780)); expect(view.overlay == "settings", "blank Settings gap is inert")
	controller.session.state = FishingSession.State.CAST_ARMED; controller._open_settings()
	expect(controller.session.state == FishingSession.State.READY and view.overlay == "settings", "opening Settings cancels CAST_ARMED before stale snap input can survive pause")
	controller.motion = _calibrated_motion(); var pull_pose := Vector3(0, -9.8, 0); controller.motion.begin_fight(pull_pose); controller.session.state = FishingSession.State.REELING; controller._open_settings(); controller._close_overlay()
	expect(controller.session.state == FishingSession.State.REELING and controller.menu_motion_settle_remaining >= HapticService.MOTION_SETTLE_SECONDS, "settings pause preserves an active fight while return owns a motion-settle guard")
	controller.motion.queue_sample({"gravity": pull_pose, "accelerometer": pull_pose, "gyro": Vector3(0, 0, 0.5)})
	var resumed_pull := controller.motion.update(0.1, false, false, true)
	expect(float(resumed_pull.fight_load) >= 0.95, "a real fight pose still maps to pull load after settings return preserves fight anchors")
	controller.loading_active = false; controller.capture_freeze = false; controller.session.state = FishingSession.State.HOOK_WINDOW; controller.session.bite_elapsed = FishingSession.HOOK_WINDOW_SECONDS - 0.05; controller.menu_motion_settle_remaining = 0.30; view.overlay = ""; controller._process(0.20)
	expect(controller.session.state == FishingSession.State.HOOK_WINDOW and controller.session.bite_elapsed <= FishingSession.HOOK_WINDOW_SECONDS - 0.05, "menu settle pauses a near-expiry hook window rather than consuming it")
	controller._process(0.11); controller._process(0.01)
	expect(controller.session.state == FishingSession.State.HOOK_WINDOW, "hook window resumes only after its menu settle guard finishes")
	controller.preview_haptics.set_enabled(true); controller.preview_haptics.cue("bite"); controller.preview_haptics.tick(0.01); var preview_guard := controller.preview_haptics.motion_guard_seconds(); controller._close_overlay()
	expect(controller.menu_motion_settle_remaining >= preview_guard and controller.preview_haptics.pending.is_empty(), "closing immediately after preview preserves its motor guard and clears delayed preview work")
	controller.save.data.settings.haptics = true; controller.haptics.set_enabled(true); controller.preview_haptics.set_enabled(true); controller.preview_haptics.cue("bite"); controller.preview_haptics.tick(0.01); controller._toggle_setting("haptics")
	expect(not controller.preview_haptics.enabled and controller.preview_haptics.pending.is_empty(), "turning haptics off stops the preview channel before later pulses leak")
	controller.session.state = FishingSession.State.LINE_OUT; controller.session.location_id = "pine_lake"; view.overlay = "locations"; view._refresh_location_card_rects(0.0); view._handle_press(view.location_cedar_rect.get_center())
	expect(controller.session.location_id == "pine_lake" and view.overlay == "locations", "active fishing blocks water selection through the Locations overlay")
	controller.session.state = FishingSession.State.READY; controller.save.data.unlocked_location_ids.append("unknown_water"); controller._select_location("unknown_water")
	expect(controller.session.location_id == "pine_lake" and view.overlay == "locations", "unknown location IDs cannot bypass controller selection even if malformed save data names them unlocked")
	controller.session.state = FishingSession.State.READY; view.overlay = "locations"
	for waters_safe_top in [0.0, 91.0, 180.0]:
		view.safe_top_override = waters_safe_top; view.waters_scroll = 0.0; view._refresh_location_card_rects(waters_safe_top)
		var top_reachable: bool = view.waters_viewport_rect.encloses(view.location_card_rects[0].intersection(view.waters_viewport_rect))
		view._scroll_waters(9999.0)
		var last_location_index := LocationDefinition.all().size() - 1
		var bottom_reachable: bool = view.location_card_rects[last_location_index].intersects(view.waters_viewport_rect)
		expect(top_reachable and bottom_reachable and view.back_to_fishing_rect.position.y >= waters_safe_top, "scrolling picker reaches first and last water with fixed Back at safe-top %.0f" % waters_safe_top)
	view.safe_top_override = 0.0; view.waters_scroll = 0.0; controller.save.data.unlocked_location_ids = ["willow_pond", "pine_lake"]; controller.session.set_location("willow_pond", 0.0); view._refresh_location_card_rects(0.0)
	var pine_before_drag := controller.session.location_id
	var pine_point: Vector2 = view.location_card_rects[1].get_center()
	view._handle_waters_touch(pine_point, true); view._handle_waters_drag(pine_point + Vector2(18, 0)); view._handle_waters_touch(pine_point + Vector2(18, 0), false)
	expect(controller.session.location_id == pine_before_drag, "horizontal travel over 12px is a drag and cannot select a water")
	view._handle_waters_touch(pine_point, true); view._handle_waters_touch(pine_point + Vector2(14, 0), false)
	expect(controller.session.location_id == pine_before_drag, "release travel without a drag event still cannot select a water")
	view.waters_scroll = 0.0; view._refresh_location_card_rects(0.0); pine_point = view.location_card_rects[1].get_center()
	view._handle_waters_touch(pine_point, true); view._handle_waters_drag(pine_point + Vector2(0, -84)); view._handle_waters_touch(pine_point + Vector2(0, -84), false)
	expect(view.waters_scroll > 0.0 and controller.session.location_id == pine_before_drag, "vertical travel scrolls the picker without selecting the pressed water")
	view.waters_scroll = 0.0; view._refresh_location_card_rects(0.0); pine_point = view.location_card_rects[1].get_center()
	var primary_down := InputEventScreenTouch.new(); primary_down.index = 0; primary_down.pressed = true; primary_down.device = 0; primary_down.position = pine_point
	var secondary_down := InputEventScreenTouch.new(); secondary_down.index = 1; secondary_down.pressed = true; secondary_down.device = 0; secondary_down.position = pine_point + Vector2(20, 20)
	var secondary_up := InputEventScreenTouch.new(); secondary_up.index = 1; secondary_up.pressed = false; secondary_up.device = 0; secondary_up.position = secondary_down.position
	var primary_up := InputEventScreenTouch.new(); primary_up.index = 0; primary_up.pressed = false; primary_up.device = 0; primary_up.position = pine_point
	view._gui_input(primary_down); view._gui_input(secondary_down); view._gui_input(secondary_up); view._gui_input(primary_up)
	expect(controller.session.location_id == pine_before_drag, "a second touch cancels the pending primary water tap")
	var waters_scroll_before_wheel: float = float(view.waters_scroll)
	var emulated_wheel := InputEventMouseButton.new(); emulated_wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; emulated_wheel.pressed = true; emulated_wheel.device = InputEvent.DEVICE_ID_EMULATION; emulated_wheel.position = pine_point
	var released_wheel := InputEventMouseButton.new(); released_wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; released_wheel.pressed = false; released_wheel.device = 0; released_wheel.position = pine_point
	var outside_wheel := InputEventMouseButton.new(); outside_wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; outside_wheel.pressed = true; outside_wheel.device = 0; outside_wheel.position = Vector2(12, 450)
	view._gui_input(emulated_wheel); view._gui_input(released_wheel); view._gui_input(outside_wheel)
	expect(is_equal_approx(view.waters_scroll, waters_scroll_before_wheel), "emulated, released, and out-of-viewport wheel events leave Waters scrolling unchanged")
	view._scroll_waters(9999.0)
	var top_card_offscreen: bool = not view.location_card_rects[0].intersects(view.waters_viewport_rect)
	expect(top_card_offscreen and view._waters_location_at(view.location_card_rects[0].get_center()).is_empty(), "fully clipped card copy and hit target cannot be reached offscreen")
	controller.session.state = FishingSession.State.CAUGHT; controller.save.data.catches.bluegill = 3; controller.save.data.unlocked_location_ids = ["willow_pond", "pine_lake", "cedar_river"]; controller._select_location("cedar_river")
	expect(controller.session.state == FishingSession.State.READY and controller.session.location_id == "cedar_river" and int(controller.save.data.catches.bluegill) == 3, "terminal catch selection resets the result without losing saved records")
	controller.session.state = FishingSession.State.CAUGHT; controller.session.location_id = "pine_lake"; controller.session.fish = FishDefinition.bluegill(); controller.session.catch_length_cm = 25.0; controller.caught_recorded = false; controller._snapshot_catch_record(); controller._record_catch_once(); controller._record_catch_once()
	expect(int(controller.save.data.catches.bluegill) == 4 and controller.save.history_for_fish("bluegill").size() == 1, "catch record handler persists aggregate and history exactly once")
	controller.motion = _calibrated_motion(); controller.session.state = FishingSession.State.CAUGHT; controller.session.terminal_elapsed = 0.0; controller.session.terminal_still_elapsed = 0.0; controller.caught_recorded = true; controller.terminal_motion_ready = false; controller.prior_state = FishingSession.State.CAUGHT; view.overlay = ""
	for frame in range(60): controller.motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); controller._process(0.05)
	expect(controller.terminal_motion_ready, "terminal controller waits through dwell and valid quiet samples before accepting a new gesture")
	for frame in range(3): controller.motion.queue_sample(_motion_sample(controller.motion._back_axis_direction() * controller.motion._physical_cock_threshold() * 1.2)); controller._process(0.04)
	expect(controller.session.state == FishingSession.State.CAST_ARMED, "settled terminal controller accepts a fresh physical cock")
	var forward := Vector3(controller.motion.profile.forward_axis[0], controller.motion.profile.forward_axis[1], controller.motion.profile.forward_axis[2]).normalized()
	for frame in range(3): controller.motion.queue_sample(_motion_sample(forward * controller.motion._runtime_snap_threshold() * 2.0)); controller._process(0.04)
	expect(controller.session.state == FishingSession.State.LINE_OUT, "terminal cock followed by snap launches a motion-only next cast")
	controller.session.state = FishingSession.State.CAUGHT; controller.session.terminal_elapsed = FishingSession.TERMINAL_RECAST_DWELL_SECONDS; controller.terminal_motion_ready = false
	for frame in range(12): controller.motion.queue_sample({"gravity": Vector3.ZERO, "accelerometer": Vector3.ZERO, "gyro": Vector3.ZERO}); controller._process(0.05)
	expect(not controller.terminal_motion_ready, "gravity-zero desktop samples never credit terminal stillness")
	controller.haptics.stop(); controller.motion = _calibrated_motion(); controller.session.state = FishingSession.State.CAUGHT; controller.session.terminal_elapsed = FishingSession.TERMINAL_RECAST_DWELL_SECONDS; controller.session.terminal_still_elapsed = 0.0; controller.terminal_motion_ready = false; controller.prior_state = FishingSession.State.CAUGHT
	for frame in range(12): controller.motion.queue_sample(_motion_sample(Vector3(0.9, 0, 0), Vector3.ZERO)); controller._process(0.05)
	expect(not controller.terminal_motion_ready and controller.session.terminal_still_elapsed == 0.0, "noisy valid-gravity terminal samples cannot arm recast readiness")
	controller.session.terminal_still_elapsed = FishingSession.TERMINAL_STILL_SECONDS; controller.save.data.settings.haptics = true; controller.haptics.set_enabled(true); controller.haptics.cue("bite"); controller.haptics.tick(0.0); controller.motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); controller._process(0.04)
	expect(not controller.terminal_motion_ready and controller.haptics.is_motion_guarded(), "terminal motor guard rejects a ready-looking quiet frame until the haptic tail clears")
	controller.haptics.stop(); controller.motion = _left_calibrated_motion(); controller.session.state = FishingSession.State.CAUGHT; controller.session.terminal_elapsed = 0.0; controller.session.terminal_still_elapsed = 0.0; controller.terminal_motion_ready = false; controller.prior_state = FishingSession.State.CAUGHT
	for frame in range(60): controller.motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); controller._process(0.05)
	for frame in range(3): controller.motion.queue_sample(_motion_sample(controller.motion._back_axis_direction() * controller.motion._physical_cock_threshold() * 1.2)); controller._process(0.04)
	var left_forward := Vector3(controller.motion.profile.forward_axis[0], controller.motion.profile.forward_axis[1], controller.motion.profile.forward_axis[2]).normalized()
	for frame in range(3): controller.motion.queue_sample(_motion_sample(left_forward * controller.motion._runtime_snap_threshold() * 2.0)); controller._process(0.04)
	expect(controller.session.state == FishingSession.State.LINE_OUT, "left-handed terminal recast also requires and accepts its mirrored fresh cock then snap")
	controller.session.terminal_still_elapsed = FishingSession.TERMINAL_STILL_SECONDS; controller._open_settings(); controller._close_overlay()
	expect(not controller.terminal_motion_ready and is_zero_approx(controller.session.terminal_still_elapsed), "menu return clears terminal readiness for a fresh still settle")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(controller.save.path)); view.free(); controller.free()

func _test_injectable_motion() -> void:
	var motion := _calibrated_motion()
	expect(motion.is_calibrated() and motion.calibration_progress == 2, "two physical calibration traces build a validated profile")
	expect(float(motion.profile.forward_axis[0]) < -0.70, "calibration stores an explicit left/negative-X forward axis")
	expect(MotionService.validate_profile({"forward_axis": [-0.85, 0.27, -0.445], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "existing negative-X saved profile remains valid")
	expect(MotionService.validate_profile({"forward_axis": [-0.52, -0.80, -0.28], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "clearly left-handed diagonal saved profile remains valid")
	expect(not MotionService.validate_profile({"forward_axis": [1.0, 0.0, 0.0], "back_peak": 3.0, "forward_peak": 5.0, "gyro_peak": 0.7, "transition_seconds": 0.2, "noise_floor": 0.1, "direction_tolerance": 0.62}), "wrong-handed saved profile is rejected and recalibrates")
	var left_motion := _left_calibrated_motion()
	expect(left_motion.is_calibrated() and float(left_motion.profile.get("forward_axis", [0.0])[0]) > 0.70, "left-handed calibration mirrors the saved profile axis profile=%s phase=%s" % [str(left_motion.profile), left_motion.calibration_phase])
	var left_arm := _physical_back_sweep(left_motion)
	var left_cast := _learned_snap_sweep(left_motion)
	expect(left_arm.cast_arm and float(left_cast.cast_quality) > 0.0, "left-handed cock-left snap-right cast mirrors right-handed behavior")
	var thresholds := _calibrated_motion(); thresholds.profile.noise_floor = 1.0; thresholds.profile.back_peak = 4.0; thresholds.profile.forward_peak = 6.0; thresholds.profile.gyro_peak = 4.0; thresholds.sensitivity = 2.0
	expect(is_equal_approx(thresholds._back_threshold(), 1.16) and is_equal_approx(thresholds._forward_threshold(), 1.26) and is_equal_approx(thresholds._hook_threshold(), 0.8) and is_equal_approx(thresholds._gyro_threshold(), 0.32) and is_equal_approx(thresholds._snap_gyro_threshold(), 0.32), "gate-restoration thresholds apply sensitivity to each complete strict max formula")
	thresholds.sensitivity = 0.5; expect(is_equal_approx(thresholds._gyro_threshold(), 0.60) and is_equal_approx(thresholds._snap_gyro_threshold(), 0.60), "restored snap gyro exactly matches the normal cast gyro gate")
	var pixel_profile := {"forward_axis": [-0.8526, 0.2737, -0.4452], "back_peak": 2.1457, "forward_peak": 3.6814, "gyro_peak": 4.2315, "transition_seconds": 0.375, "noise_floor": 0.6437, "direction_tolerance": 0.62}
	var pixel_thresholds := MotionService.new(); expect(pixel_thresholds.set_profile(pixel_profile), "inherited Pixel v3 profile remains valid without recalibration")
	expect(absf(pixel_thresholds._back_threshold() - 1.244506) <= 0.001 and absf(pixel_thresholds._forward_threshold() - 1.546188) <= 0.001 and absf(pixel_thresholds._runtime_snap_threshold() - 37.108512) <= 0.002 and is_equal_approx(pixel_thresholds._snap_axis_tolerance(), 0.78) and is_equal_approx(pixel_thresholds._snap_polarity_tolerance(), 0.62) and is_equal_approx(pixel_thresholds._gyro_threshold(), 0.60) and is_equal_approx(pixel_thresholds._snap_gyro_threshold(), 0.60) and is_equal_approx(pixel_thresholds._gyro_threshold() * 0.65, 0.39), "Pixel v25 keeps the strict runtime threshold and raises only snap axis/polarity floors to .78/.62")
	expect(is_equal_approx(MotionService.RUNTIME_COCK_MIN_IMPULSE_FACTOR, 0.045) and is_equal_approx(MotionService.RUNTIME_SNAP_MIN_IMPULSE_FACTOR, 0.055), "capture build restores the physically known v18 sweep energy: cock 4.5% and snap 5.5%")
	var pixel_axis := Vector3(-0.8526, 0.2737, -0.4452).normalized()
	var ramped_pixel_gesture := MotionService.new(); ramped_pixel_gesture.set_profile(pixel_profile)
	ramped_pixel_gesture.queue_sample(_motion_sample(-pixel_axis * 1.10, Vector3(0, 0, 0.61)))
	var weak_cock := ramped_pixel_gesture.update(0.04, true, false)
	var ramped_cock := _physical_back_sweep(ramped_pixel_gesture, 1.20, 3)
	ramped_pixel_gesture.queue_sample(_motion_sample(pixel_axis * 1.00, Vector3(0, 0, 0.40)))
	var weak_snap := ramped_pixel_gesture.update(0.05, true, false)
	var ramped_snap := _runtime_sweep(ramped_pixel_gesture, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3)
	expect(not weak_cock.cast_arm and ramped_cock.cast_arm and float(weak_snap.cast_quality) == 0.0 and float(ramped_snap.cast_quality) > 0.0, "a sub-v24 snap stays inert, then a shaped runtime-threshold sweep casts without a quiet gap")
	var spike_motion := MotionService.new(); spike_motion.set_profile(pixel_profile)
	var one_cock_spike := _physical_back_sweep(spike_motion, 1.20, 1)
	var two_cock_spikes := _physical_back_sweep(spike_motion, 1.20, 1)
	var deliberate_cock := _physical_back_sweep(spike_motion, 1.20, 1)
	var one_snap_spike := _runtime_sweep(spike_motion, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1)
	var two_snap_spikes := _runtime_sweep(spike_motion, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1)
	var deliberate_snap := _runtime_sweep(spike_motion, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1)
	expect(not one_cock_spike.cast_arm and not two_cock_spikes.cast_arm and deliberate_cock.cast_arm and float(one_snap_spike.cast_quality) == 0.0 and float(two_snap_spikes.cast_quality) == 0.0 and float(deliberate_snap.cast_quality) > 0.0, "runtime cock and snap require three deliberate directional samples rather than one/two-frame spikes")
	var cock_gap_reset := MotionService.new(); cock_gap_reset.set_profile(pixel_profile)
	var cock_before_gap := _physical_back_sweep(cock_gap_reset, 1.20, 2)
	cock_gap_reset.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); cock_gap_reset.update(0.01, true, false)
	var cock_after_gap_two := _physical_back_sweep(cock_gap_reset, 1.20, 2)
	var cock_after_gap_three := _physical_back_sweep(cock_gap_reset, 1.20, 1)
	expect(not cock_before_gap.cast_arm and not cock_after_gap_two.cast_arm and cock_after_gap_three.cast_arm, "an exact-zero cock frame clears partial sweep credit before the next three-sample burst")
	var snap_gap_reset := MotionService.new(); snap_gap_reset.set_profile(pixel_profile)
	_physical_back_sweep(snap_gap_reset)
	var snap_before_gap := _runtime_sweep(snap_gap_reset, pixel_axis * 80.0, Vector3(0, 0, 0.61), 2, 0.03)
	snap_gap_reset.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); snap_gap_reset.update(0.01, true, false)
	var snap_after_gap_two := _runtime_sweep(snap_gap_reset, pixel_axis * 80.0, Vector3(0, 0, 0.61), 2, 0.03)
	var snap_after_gap_three := _runtime_sweep(snap_gap_reset, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1, 0.03)
	expect(float(snap_before_gap.cast_quality) == 0.0 and float(snap_after_gap_two.cast_quality) == 0.0 and float(snap_after_gap_three.cast_quality) > 0.0, "an exact-zero snap frame clears partial credit without disarming the cast, so a new three-sample burst casts within the runtime window")
	var low_impulse := MotionService.new(); low_impulse.set_profile(pixel_profile)
	_physical_back_sweep(low_impulse)
	var low_impulse_snap := _runtime_sweep(low_impulse, pixel_axis * 1.55, Vector3(0, 0, 0.61), 6, 0.01)
	expect(float(low_impulse_snap.cast_quality) == 0.0, "near-threshold multi-frame snap without enough capped impulse remains inert")
	var cock_gyro_recovery := MotionService.new(); cock_gyro_recovery.set_profile(pixel_profile)
	cock_gyro_recovery.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	var recovery_cock_vector := cock_gyro_recovery._back_axis_direction() * cock_gyro_recovery._physical_cock_threshold() * 1.20
	_runtime_sweep(cock_gyro_recovery, recovery_cock_vector, Vector3(0, 0, 0.10), 3)
	# The first sweep had a low gyro and its final frame can recover once gyro clears.
	var recovered_cock_same_burst := _runtime_sweep(cock_gyro_recovery, recovery_cock_vector, Vector3(0, 0, 0.72), 1)
	var cock_recovery_counts: Dictionary = cock_gyro_recovery.get_diagnostics()
	expect(recovered_cock_same_burst.cast_arm and int(cock_recovery_counts.cock_attempts) == 1 and int(cock_recovery_counts.reasons.gyro) == 1, "an above-threshold cock gyro miss can recover on a later valid frame in the same rightward burst with one attempt/failure")
	var varied_pixel_snap := MotionService.new(); varied_pixel_snap.set_profile(pixel_profile)
	var varied_left_direction := Vector3(-0.20, 0.98, 0.0).normalized()
	var varied_match := varied_left_direction.dot(pixel_axis)
	var varied_polarity := varied_left_direction.dot(MotionService.RIGHT_HANDED_FORWARD_AXIS)
	_physical_back_sweep(varied_pixel_snap)
	var varied_pixel_rejected := _runtime_sweep(varied_pixel_snap, varied_left_direction * 3.0, Vector3(0, 0, 0.61))
	var varied_pixel_recovered := _runtime_sweep(varied_pixel_snap, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3)
	expect(varied_match >= 0.4216 and varied_match < 0.62 and varied_polarity >= 0.081 and float(varied_pixel_rejected.cast_quality) == 0.0 and float(varied_pixel_recovered.cast_quality) > 0.0, "a below-.62 varied snap remains rejected while a later strict-axis frame recovers in the same burst")
	var below_axis_direction := (pixel_axis * 0.30 + Vector3(-0.305, -0.952, 0.0) * 0.954).normalized()
	var gyro_recovery := MotionService.new(); gyro_recovery.set_profile(pixel_profile)
	_physical_back_sweep(gyro_recovery)
	_runtime_sweep(gyro_recovery, pixel_axis * 80.0, Vector3(0, 0, 0.10), 3)
	expect(float(_runtime_sweep(gyro_recovery, pixel_axis * 80.0, Vector3(0, 0, 0.61), 1).cast_quality) > 0.0, "an above-threshold snap gyro miss can recover on a later valid frame after shape buildup")
	var below_axis_snap := MotionService.new(); below_axis_snap.set_profile(pixel_profile)
	_physical_back_sweep(below_axis_snap)
	expect(float(_runtime_sweep(below_axis_snap, below_axis_direction * 3.0, Vector3(0, 0, 0.61)).cast_quality) == 0.0, "a snap below the restored .62 learned-axis gate remains rejected")
	var polarity_profile := pixel_profile.duplicate(true); polarity_profile.forward_axis = [-0.50, 0.866, 0.0]
	var wrong_polarity_snap := MotionService.new(); wrong_polarity_snap.set_profile(polarity_profile)
	_physical_back_sweep(wrong_polarity_snap)
	expect(float(_runtime_sweep(wrong_polarity_snap, Vector3(0.05, 0.9987, 0.0) * 3.0, Vector3(0, 0, 0.61)).cast_quality) == 0.0, "a learned-axis-compatible snap with the wrong physical left polarity remains rejected")
	var fast_timing := MotionService.new(); fast_timing.set_profile(pixel_profile)
	_physical_back_sweep(fast_timing)
	var fast_timing_cast := _runtime_sweep(fast_timing, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3, 0.06)
	var late_timing := MotionService.new(); late_timing.set_profile(pixel_profile)
	_physical_back_sweep(late_timing)
	var late_timing_cast := _runtime_sweep(late_timing, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3, 0.18)
	var expired_timing := MotionService.new(); expired_timing.set_profile(pixel_profile)
	_physical_back_sweep(expired_timing)
	var expired_timing_cast := _runtime_sweep(expired_timing, pixel_axis * 80.0, Vector3(0, 0, 0.61), 3, 0.22)
	var fast_distance_session := FishingSession.new(); fast_distance_session.arm_cast(); fast_distance_session.release_cast(float(fast_timing_cast.cast_quality))
	var late_distance_session := FishingSession.new(); late_distance_session.arm_cast(); late_distance_session.release_cast(float(late_timing_cast.cast_quality))
	expect(float(fast_timing_cast.cast_quality) >= 0.99 and float(late_timing_cast.cast_quality) > 0.0 and float(late_timing_cast.cast_quality) < float(fast_timing_cast.cast_quality) and float(expired_timing_cast.cast_quality) == 0.0 and fast_distance_session.cast_distance_m > late_distance_session.cast_distance_m, "runtime reversal timing gives full fast casts, short late casts, and rejects over-.65-second reversals")
	var switched := _calibrated_motion(); switched.set_left_handed(true)
	expect(switched.left_handed and not switched.is_calibrated() and switched.calibration_phase == "settling", "switching handedness deliberately clears a v3-compatible profile and starts calibration")
	var robust_gyro := MotionService.new(); robust_gyro._calibration_examples = [{"gyro_peak": 0.42}, {"gyro_peak": 8.0}]
	expect(is_equal_approx(robust_gyro._robust_gyro_peak(), 0.42), "two practice casts use the lower gyro peak to reject a one-off outlier")
	var diagnostic_motion := _calibrated_motion(); diagnostic_motion.queue_sample(_motion_sample(Vector3(12.0, 100.0, 0), Vector3(0, 0, 0.72))); diagnostic_motion.update(0.05, true, false)
	var diagnostic_counts: Dictionary = diagnostic_motion.get_diagnostics()
	expect(diagnostic_counts.has("cock_attempts") and diagnostic_counts.has("reasons") and not str(diagnostic_counts).contains("Vector3"), "motion diagnostics keep derived counters/reasons without raw sensor vectors")
	var still_motion := _calibrated_motion(); still_motion.reset_gesture(); still_motion.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	expect(not still_motion._new_candidate("cock", 0.0, still_motion._back_threshold()), "zero directional projection cannot enter a cock candidate")
	for frame in range(1200): still_motion.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); still_motion.update(0.05, true, true)
	var still_counts: Dictionary = still_motion.get_diagnostics()
	expect(int(still_counts.cock_attempts) == 0 and int(still_counts.hook_attempts) == 0 and int(still_counts.completed_casts) == 0 and int(still_counts.reasons.linear) + int(still_counts.reasons.axis) + int(still_counts.reasons.polarity) + int(still_counts.reasons.gyro) + int(still_counts.reasons.timeout) == 0, "60 seconds of still samples creates no gesture attempts or failure counts: %s" % str(still_counts))
	var burst_motion := _calibrated_motion(); burst_motion.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	for frame in range(4): burst_motion.queue_sample(_motion_sample(Vector3(12.0, 100.0, 0), Vector3(0, 0, 0.72))); burst_motion.update(0.05, true, false)
	var burst_counts: Dictionary = burst_motion.get_diagnostics()
	expect(int(burst_counts.cock_attempts) == 1 and int(burst_counts.reasons.linear) + int(burst_counts.reasons.axis) + int(burst_counts.reasons.polarity) == 1, "one off-axis/under-threshold candidate burst records one attempt/reason across high frames")
	var quiet_cock_recovery := _calibrated_motion()
	quiet_cock_recovery.queue_sample(_motion_sample(Vector3(12.0, 100.0, 0), Vector3(0, 0, 0.72)))
	quiet_cock_recovery.update(0.05, true, false)
	quiet_cock_recovery.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
	quiet_cock_recovery.update(0.05, true, false)
	var recovered_cock := _physical_back_sweep(quiet_cock_recovery)
	var recovered_cast := _learned_snap_sweep(quiet_cock_recovery)
	expect(recovered_cock.cast_arm and float(recovered_cast.cast_quality) > 0.0, "a zero quiet frame clears a rejected cock burst so the next valid cock and snap cast")
	var hook_burst := _calibrated_motion(); hook_burst.diagnostics = {"cock_attempts": 0, "completed_casts": 0, "hook_attempts": 0, "reasons": {"linear": 0, "axis": 0, "polarity": 0, "gyro": 0, "timeout": 0}}
	for frame in range(4): hook_burst.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.4))); hook_burst.update(0.05, false, true)
	expect(int(hook_burst.get_diagnostics().hook_attempts) == 1, "one hook candidate burst counts one hook attempt")
	var two_window_hook := _calibrated_motion()
	# The first bite window receives a deliberately wrong-polarity high burst;
	# ending that window must clear its candidate latch without needing a quiet
	# sample, so the next window sees its first real hook.
	two_window_hook.queue_sample(_motion_sample(Vector3(-1.35, 0, 0), Vector3(0, 0, 0.4)))
	expect(not two_window_hook.update(0.05, false, true).hook, "first hook window rejects a wrong-polarity candidate")
	two_window_hook.queue_sample(_motion_sample(Vector3(-1.35, 0, 0), Vector3(0, 0, 0.4)))
	two_window_hook.update(0.05, false, false)
	expect(_hook_sweep(two_window_hook).hook and int(two_window_hook.get_diagnostics().hook_attempts) == 1, "a prior opposite hook-window burst cannot suppress the first deliberate hook candidate in the next window")
	var calibration_reject := MotionService.new()
	calibration_reject.begin_calibration()
	for frame in range(3):
		calibration_reject.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO))
		calibration_reject.update(0.25, false, false)
	calibration_reject.queue_sample(_motion_sample(Vector3(-3.4, -5.2, -1.8)))
	calibration_reject.update(0.01, false, false)
	expect(calibration_reject.calibration_phase.ends_with("_back") and calibration_reject.calibration_progress == 0, "reversed diagonal left snap is rejected during right-cock calibration")
	var diagonal_motion := _diagonal_motion()
	expect(diagonal_motion.is_calibrated() and float(diagonal_motion.profile.forward_axis[0]) < -0.48, "diagonal signed right-cock/left-snap examples calibrate a compatible profile")
	var diagonal_cock := Vector3(4.5, 4.5, 1.5)
	var diagonal_arm := _physical_back_sweep(diagonal_motion)
	var diagonal_cast := _learned_snap_sweep(diagonal_motion)
	expect(diagonal_arm.cast_arm and float(diagonal_cast.cast_quality) > 0.0, "natural diagonal right cock then left snap passes learned-axis recognition without the old narrow X cone")
	var residual_cock_motion := _calibrated_motion()
	var residual_arm := _physical_back_sweep(residual_cock_motion)
	for residual in [Vector3(2.5, 0, 0), Vector3(2.1, 0, 0), Vector3(1.6, 0, 0), Vector3(1.2, 0, 0)]:
		residual_cock_motion.queue_sample(_motion_sample(residual, Vector3(0, 0, 0.45)))
		residual_cock_motion.update(0.04, true, false)
	var residual_snap := _learned_snap_sweep(residual_cock_motion)
	expect(residual_arm.cast_arm and float(residual_snap.cast_quality) > 0.0, "residual cock/tail frames with no quiet gap cannot consume the natural forward snap candidate")
	var opposite_recovery := _calibrated_motion()
	opposite_recovery.queue_sample(_motion_sample(Vector3(-3.2, 0, 0), Vector3(0, 0, 0.5)))
	var rejected_opposite := opposite_recovery.update(0.05, true, false)
	var recovered_arm := _physical_back_sweep(opposite_recovery)
	var recovered_snap := _learned_snap_sweep(opposite_recovery)
	expect(not rejected_opposite.cast_arm and recovered_arm.cast_arm and float(recovered_snap.cast_quality) > 0.0, "an opposite-direction burst cannot suppress the next correct cock/snap candidate")
	var off_axis_multi := _calibrated_motion()
	for frame in range(4):
		off_axis_multi.queue_sample(_motion_sample(Vector3(0, 3.5, 0), Vector3(0, 0, 0.5)))
		off_axis_multi.update(0.05, true, false)
	expect(int(off_axis_multi.get_diagnostics().completed_casts) == 2 and not bool(off_axis_multi.update(0.01, true, false).cast_arm), "off-axis multi-frame energy cannot arm or cast")
	var diagonal_right_snap := _diagonal_motion()
	_physical_back_sweep(diagonal_right_snap)
	var right_snap_event := _runtime_sweep(diagonal_right_snap, diagonal_cock * 1.70)
	expect(float(right_snap_event.cast_quality) == 0.0, "rightward diagonal snap remains rejected after cock")
	var diagonal_off_axis := _diagonal_motion()
	_physical_back_sweep(diagonal_off_axis)
	var diagonal_off_axis_event := _runtime_sweep(diagonal_off_axis, Vector3(-0.10, 0.0, -1.0).normalized() * 12.0)
	expect(float(diagonal_off_axis_event.cast_quality) == 0.0, "left-polarity diagonal noise below the snap axis floor remains rejected")
	var diagonal_hook_motion := _diagonal_motion()
	var diagonal_hook := _hook_sweep(diagonal_hook_motion)
	expect(diagonal_hook.hook, "deliberate diagonal right hook uses the signed physical direction without the old narrow X cone")
	var diagonal_wrong_hook := _diagonal_motion()
	diagonal_wrong_hook.queue_sample(_motion_sample(Vector3(-1.6, -2.45, -0.85), Vector3(0, 0, 0.5)))
	expect(not diagonal_wrong_hook.update(0.05, false, true).hook, "left diagonal snap remains rejected as a hook")
	var diagonal_off_axis_hook := _diagonal_motion()
	diagonal_off_axis_hook.queue_sample(_motion_sample(Vector3(0.10, -0.74, 0.84), Vector3(0, 0, 0.5)))
	expect(not diagonal_off_axis_hook.update(0.05, false, true).hook, "right-polarity off-axis hook still fails the learned-axis match")
	motion.queue_sample(_motion_sample(Vector3(0.35, 0, 0), Vector3(0, 0, 0.05)))
	var noise := motion.update(0.05, true, false)
	expect(not noise.cast_arm and float(noise.cast_quality) == 0.0, "noise does not arm a cast")
	var wrong_order_motion := _calibrated_motion()
	var wrong_order := _runtime_sweep(wrong_order_motion, Vector3(-4.2, 0, 0))
	expect(not wrong_order.cast_arm and float(wrong_order.cast_quality) == 0.0, "left snap without a right cock is rejected")
	var wrong_direction_motion := _calibrated_motion()
	var wrong_direction := _runtime_sweep(wrong_direction_motion, Vector3(0, 3.5, 0))
	expect(not wrong_direction.cast_arm and float(wrong_direction.cast_quality) == 0.0, "off-axis motion is rejected")
	var reversed_motion := _calibrated_motion()
	var slow_back := _physical_back_sweep(reversed_motion)
	var reversed_snap := _runtime_sweep(reversed_motion, Vector3(4.2, 0, 0))
	expect(slow_back.cast_arm and float(reversed_snap.cast_quality) == 0.0, "rightward snap after a right cock is rejected")
	var slow_motion := _calibrated_motion()
	_physical_back_sweep(slow_motion)
	var slow_snap := _learned_snap_sweep(slow_motion, 80.0, 3, 0.08)
	expect(float(slow_snap.cast_quality) > 0.0, "right cock then left snap arms and casts")
	var fast_motion := _calibrated_motion()
	_physical_back_sweep(fast_motion)
	var fast_snap := _learned_snap_sweep(fast_motion, 80.0, 3, 0.06)
	expect(float(slow_snap.cast_quality) < float(fast_snap.cast_quality), "faster accepted snap has higher quality")
	var slow_session := FishingSession.new(); slow_session.arm_cast(); slow_session.release_cast(float(slow_snap.cast_quality))
	var fast_session := FishingSession.new(); fast_session.arm_cast(); fast_session.release_cast(float(fast_snap.cast_quality))
	expect(slow_session.cast_distance_m < fast_session.cast_distance_m, "faster snap maps to farther cast distance")
	var too_slow_motion := _calibrated_motion()
	_physical_back_sweep(too_slow_motion)
	var too_slow := _learned_snap_sweep(too_slow_motion, 80.0, 3, 0.22)
	expect(float(too_slow.cast_quality) == 0.0, "slow back-to-snap transition is rejected")
	var hook_motion := _calibrated_motion()
	var hook_event := _hook_sweep(hook_motion)
	var hook_session := FishingSession.new(); hook_session.state = FishingSession.State.HOOK_WINDOW
	expect(hook_event.hook and hook_session.set_hook() and int(hook_event.hook_sweep_samples) >= 3 and not str(hook_event).contains("Vector3"), "smaller calibrated right gesture hooks only after a derived three-sample sweep")
	var wrong_hook_motion := _calibrated_motion()
	wrong_hook_motion.queue_sample(_motion_sample(Vector3(-1.35, 0, 0), Vector3(0, 0, 0.4)))
	var wrong_hook := wrong_hook_motion.update(0.05, false, true)
	expect(not wrong_hook.hook, "left snap is rejected as a hook gesture")
	var off_axis_hook_motion := _calibrated_motion()
	off_axis_hook_motion.queue_sample(_motion_sample(Vector3(0, 1.6, 0), Vector3(0, 0, 0.4)))
	var off_axis_hook := off_axis_hook_motion.update(0.05, false, true)
	expect(not off_axis_hook.hook, "off-axis movement is rejected as a hook gesture")
	motion.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.4)))
	var inactive_hook := motion.update(0.05, false, false)
	expect(not inactive_hook.hook, "hook gesture is inactive outside the hook window contract")
	var sensitivity_motion := _calibrated_motion()
	sensitivity_motion.sensitivity = 1.5
	var easier_back := _physical_back_sweep(sensitivity_motion)
	expect(easier_back.cast_arm, "larger sensitivity lowers learned motion thresholds")

	var fight_motion := _calibrated_motion()
	var pull_pose := Vector3(0, -9.8, 0)
	var left_lower_pose := Vector3(-3.4, -9.19, 0)
	fight_motion.begin_fight(pull_pose)
	fight_motion.queue_sample({"gravity": pull_pose, "accelerometer": pull_pose, "gyro": Vector3(0, 0, 0.5)})
	var shake := fight_motion.update(0.25, false, false, true)
	expect(not shake.fight_lower and not shake.fight_pull and float(shake.fight_load) >= 0.95, "right hook pose begins a continuous pull without a false marker")
	fight_motion.queue_sample({"gravity": Vector3(0, -7.0, 6.8), "accelerometer": Vector3(0, -7.0, 6.8), "gyro": Vector3(0, 0, 0.5)})
	var pitch_only := fight_motion.update(0.25, false, false, true)
	expect(not pitch_only.fight_lower and float(pitch_only.fight_load) >= 0.95, "pitch/YZ-only pose cannot ease tension")
	fight_motion.queue_sample({"gravity": Vector3(3.4, -9.19, 0), "accelerometer": Vector3(3.4, -9.19, 0), "gyro": Vector3(0, 0, 0.5)})
	var rightward := fight_motion.update(0.25, false, false, true)
	expect(not rightward.fight_lower and float(rightward.fight_load) >= 0.95, "rightward pose cannot become an ease reference")
	fight_motion.queue_sample({"gravity": left_lower_pose, "accelerometer": left_lower_pose, "gyro": Vector3(0, 0, 0.05)})
	var no_gyro := fight_motion.update(0.25, false, false, true)
	expect(not no_gyro.fight_lower, "left ease pose without gyro corroboration is rejected")
	fight_motion.queue_sample({"gravity": left_lower_pose, "accelerometer": left_lower_pose, "gyro": Vector3(0, 0, 0.5)})
	var lowered := fight_motion.update(0.25, false, false, true)
	expect(lowered.fight_lower and lowered.fight_phase == "PULL BACK" and is_zero_approx(float(lowered.fight_load)), "left lower captures an exact zero-load ease reference")
	var pitch_after_lower_pose := Vector3(-3.4, -7.84, 4.81)
	fight_motion.queue_sample({"gravity": pitch_after_lower_pose, "accelerometer": pitch_after_lower_pose, "gyro": Vector3(0, 0, 0.5)})
	var pitch_after_lower := fight_motion.update(0.25, false, false, true)
	expect(not pitch_after_lower.fight_pull and float(pitch_after_lower.fight_load) <= 0.05, "pitch/YZ after lower cannot add signed load or emit pull")
	var quarter_pose := Vector3(-2.55, -9.46, 0)
	fight_motion.queue_sample({"gravity": quarter_pose, "accelerometer": quarter_pose, "gyro": Vector3(0, 0, 0.5)})
	var quarter_return := fight_motion.update(0.25, false, false, true)
	expect(not quarter_return.fight_pull and absf(float(quarter_return.fight_load) - 0.5) <= 0.06, "quarter rightward return maps through sqrt response to useful half load")
	var halfway_pose := Vector3(-1.7, -9.65, 0)
	fight_motion.queue_sample({"gravity": halfway_pose, "accelerometer": halfway_pose, "gyro": Vector3(0, 0, 0.5)})
	var halfway := fight_motion.update(0.25, false, false, true)
	expect(not halfway.fight_pull and float(halfway.fight_load) > 0.55 and float(halfway.fight_load) < 0.75, "monotonic signed mapping amplifies a halfway rightward return")
	var partial_right_return := Vector3(-0.8, -9.77, 0)
	fight_motion.queue_sample({"gravity": partial_right_return, "accelerometer": partial_right_return, "gyro": Vector3(0, 0, 0.5)})
	var pulled := fight_motion.update(0.25, false, false, true)
	expect(pulled.fight_pull and pulled.fight_phase == "LOWER ROD" and float(pulled.fight_load) > 0.60, "only directional rightward return marks a pull")
	fight_motion.queue_sample({"gravity": partial_right_return, "accelerometer": partial_right_return, "gyro": Vector3(0, 0, 0.5)})
	var fixed_pose_after_marker := fight_motion.update(0.25, false, false, true)
	expect(not fixed_pose_after_marker.fight_pull and is_equal_approx(float(fixed_pose_after_marker.fight_load), float(pulled.fight_load)), "guidance phase change cannot jump continuous load at a fixed pose")

func _test_admob_contract() -> void:
	var ads = AdMobService.new()
	ads.initialize()
	expect(ads.game_content_reserve_height() == 0.0, "native bottom banner owns safe inset")
	expect(ads.TEST_BANNER_AD_UNIT == "ca-app-pub-3940256099942544/6300978111", "Google test banner ID is pinned")
	expect("desktop fallback" in ads.describe_desktop_fallback(), "desktop fallback is documented")
	expect(not ads.available and not ads.initialized, "desktop ads remain inert")

	var initialization_callbacks: Array[Callable] = []
	var banner_requests: Array[bool] = []
	var sequenced_ads := AdMobService.new(
		func(on_complete: Callable): initialization_callbacks.append(on_complete),
		func(): banner_requests.append(true)
	)
	sequenced_ads.begin_sdk_initialization_for_test()
	expect(sequenced_ads.consent_state == "sdk_initializing" and initialization_callbacks.size() == 1 and banner_requests.is_empty(), "banner waits for SDK initialization completion")
	var stale_callback := initialization_callbacks[0]
	sequenced_ads.begin_sdk_initialization_for_test()
	stale_callback.call(null)
	expect(banner_requests.is_empty() and not sequenced_ads.initialized, "reinitialize destroys and invalidates a pending SDK callback")
	expect(initialization_callbacks.size() == 2 and banner_requests.is_empty(), "reinitialize creates one current SDK callback")
	stale_callback.call(null)
	expect(banner_requests.is_empty(), "stale SDK callback remains inert after restart")
	initialization_callbacks[0].call(null)
	initialization_callbacks[1].call(null)
	expect(sequenced_ads.consent_state == "banner_requested" and sequenced_ads.initialized and banner_requests.size() == 1, "SDK completion requests exactly one native banner")
	initialization_callbacks[1].call(null)
	expect(banner_requests.size() == 1, "duplicate SDK completion callback is ignored")

func _test_physical_cast_profile_motion() -> void:
	var pixel_profile := {"forward_axis": [-0.8526, 0.2737, -0.4452], "back_peak": 2.1457, "forward_peak": 3.6814, "gyro_peak": 4.2315, "transition_seconds": 0.375, "noise_floor": 0.6437, "direction_tolerance": 0.62}
	var pixel := MotionService.new()
	expect(pixel.set_profile(pixel_profile), "inherited right-handed Pixel v3 profile remains valid without recalibration")
	expect(is_equal_approx(MotionService.RUNTIME_PHYSICAL_COCK_THRESHOLD_FACTOR, 6.0) and is_equal_approx(MotionService.RUNTIME_SNAP_THRESHOLD_FACTOR, 24.0) and absf(pixel._back_threshold() - 1.244506) <= 0.001 and absf(pixel._physical_cock_threshold() - 7.467036) <= 0.002 and absf(pixel._forward_threshold() - 1.546188) <= 0.001 and absf(pixel._runtime_snap_threshold() - 37.108512) <= 0.002 and is_equal_approx(pixel._gyro_threshold(), 0.60), "physical cock remains 6x while v24 requires a 24x learned-axis runtime snap threshold and unchanged gyro")
	expect(is_equal_approx(MotionService.RUNTIME_COCK_MIN_IMPULSE_FACTOR, 0.045) and is_equal_approx(MotionService.RUNTIME_SNAP_MIN_IMPULSE_FACTOR, 0.055) and MotionService.RUNTIME_SWEEP_MIN_SAMPLES == 3, "physical cock preserves the v18 three-sample .045 sweep while snap preserves .055")

	var under_six := MotionService.new(); under_six.set_profile(pixel_profile)
	var under_event := _runtime_sweep(under_six, Vector3(7.40, 2.0, 0.0), Vector3(0, 0, 0.72), 4)
	expect(not under_event.cast_arm, "rightward cock below the 6x physical threshold remains inert")
	var wrong_physical_side := MotionService.new(); wrong_physical_side.set_profile(pixel_profile)
	var wrong_side_event := _runtime_sweep(wrong_physical_side, Vector3(-11.0, 4.0, 0.0), Vector3(0, 0, 0.72), 4)
	expect(not wrong_side_event.cast_arm, "leftward energy cannot arm a right-handed physical cock")

	# This is intentionally off the learned 3D back axis but remains a natural
	# signed-right cock: the physical-X alignment clears .18 and the X projection
	# clears the 6x threshold. The opposite snap still uses the learned profile.
	var natural := MotionService.new(); natural.set_profile(pixel_profile)
	var natural_cock := Vector3(10.0, 30.0, 0.0)
	var learned_back_axis := -Vector3(pixel_profile.forward_axis[0], pixel_profile.forward_axis[1], pixel_profile.forward_axis[2]).normalized()
	expect(natural_cock.normalized().dot(learned_back_axis) < float(pixel_profile.direction_tolerance), "natural physical cock fixture is intentionally outside the learned back-axis cone")
	var natural_arm := _runtime_sweep(natural, natural_cock, Vector3(0, 0, 0.72), 3)
	var natural_snap := _learned_snap_sweep(natural, 80.0, 3, 0.04)
	expect(natural_arm.cast_arm and float(natural_snap.cast_quality) > 0.0 and float(natural_snap.snap_projection) >= natural._runtime_snap_threshold() and float(natural_snap.snap_axis_match) >= 0.62 and float(natural_snap.snap_polarity_match) >= 0.18 and float(natural_snap.snap_gyro) >= 0.60 and float(natural_snap.reversal_seconds) > 0.0 and float(natural_snap.cock_projection) >= natural._physical_cock_threshold() and not str(natural_snap).contains("Vector3"), "6x signed physical cock arms and an accepted v24 cast exposes only derived final-snap and reversal telemetry")
	var below_runtime := MotionService.new(); below_runtime.set_profile(pixel_profile); _physical_back_sweep(below_runtime, 1.25, 3, 0.04)
	var below_runtime_snap := _learned_snap_sweep(below_runtime, below_runtime._runtime_snap_threshold() * 0.98, 3, 0.04)
	expect(float(below_runtime_snap.cast_quality) == 0.0, "a shaped learned-axis snap below the v24 runtime threshold remains rejected")
	var captured_axis := [0.9171, 0.8203, 0.8413, 0.8589, 0.9712, 0.9623, 0.9949, 0.9804, 0.9939, 0.9468]
	var captured_polarity := [0.8989, 0.6668, 0.712, 0.6943, 0.8435, 0.8699, 0.8113, 0.858, 0.8989, 0.8445]
	for index in range(captured_axis.size()):
		expect(float(captured_axis[index]) >= MotionService.RUNTIME_SNAP_AXIS_MIN and float(captured_polarity[index]) >= MotionService.RUNTIME_SNAP_POLARITY_MIN, "each of the ten replay-derived intended snap fixtures clears the v25 axis/polarity floors")
	expect(is_equal_approx(captured_axis.min(), 0.8203) and is_equal_approx(captured_polarity.min(), 0.6668), "replay-derived intended snap minima are retained as scalar evidence for the new floors")
	var false_signature := MotionService.new(); false_signature.set_profile(pixel_profile); _physical_back_sweep(false_signature, 1.25, 3, 0.04)
	var false_direction := Vector3(-0.51, 0.858, -0.043).normalized()
	var false_event := _runtime_sweep(false_signature, false_direction * 80.0, Vector3(0, 0, 0.72), 3, 0.04)
	var intentional_signature := MotionService.new(); intentional_signature.set_profile(pixel_profile); _physical_back_sweep(intentional_signature, 1.25, 3, 0.04)
	var intentional_event := _learned_snap_sweep(intentional_signature, 80.0, 3, 0.04)
	expect(is_equal_approx(MotionService.RUNTIME_SNAP_AXIS_MIN, 0.78) and is_equal_approx(MotionService.RUNTIME_SNAP_POLARITY_MIN, 0.62) and false_direction.dot(Vector3(pixel_profile.forward_axis[0], pixel_profile.forward_axis[1], pixel_profile.forward_axis[2]).normalized()) < MotionService.RUNTIME_SNAP_AXIS_MIN and false_direction.dot(MotionService.RIGHT_HANDED_FORWARD_AXIS) < MotionService.RUNTIME_SNAP_POLARITY_MIN and float(false_event.cast_quality) == 0.0 and float(intentional_event.cast_quality) > 0.0, "the observed v24-like .69/.51 false signature is rejected while intended replay-like snaps clear both v25 floors")

	var spike := MotionService.new(); spike.set_profile(pixel_profile)
	var one_spike := _physical_back_sweep(spike, 1.25, 1)
	var two_spike := _physical_back_sweep(spike, 1.25, 1)
	var three_spike := _physical_back_sweep(spike, 1.25, 1)
	expect(not one_spike.cast_arm and not two_spike.cast_arm and three_spike.cast_arm, "physical cock still rejects one/two-frame spikes before its third sweep sample")
	var gapped := MotionService.new(); gapped.set_profile(pixel_profile)
	_physical_back_sweep(gapped, 1.25, 2)
	gapped.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); gapped.update(0.01, true, false)
	var gapped_two := _physical_back_sweep(gapped, 1.25, 2)
	var gapped_three := _physical_back_sweep(gapped, 1.25, 1)
	expect(not gapped_two.cast_arm and gapped_three.cast_arm, "a quiet frame resets physical cock partial sweep credit")

	var mirrored := _left_calibrated_motion()
	var mirrored_arm := _physical_back_sweep(mirrored, 1.25, 3)
	var mirrored_snap := _learned_snap_sweep(mirrored, 80.0, 3, 0.04)
	expect(mirrored.left_handed and mirrored_arm.cast_arm and float(mirrored_snap.cast_quality) > 0.0, "left-handed mode mirrors physical cock left while retaining its learned-axis snap right")

	var right_hook := MotionService.new(); right_hook.set_profile(pixel_profile)
	expect(_hook_sweep(right_hook).hook, "right-handed hook uses the signed physical-right back direction after a deliberate sweep")
	var wrong_hook := MotionService.new(); wrong_hook.set_profile(pixel_profile)
	wrong_hook.queue_sample(_motion_sample(Vector3(-1.50, 4.0, 0.0), Vector3(0, 0, 0.50)))
	expect(not wrong_hook.update(0.05, false, true).hook, "physical-left movement remains rejected during a right-handed hook window")
	var left_hook := _left_calibrated_motion()
	expect(_hook_sweep(left_hook).hook, "left-handed hook mirrors to physical-left after a deliberate sweep")
	var hook_shape := MotionService.new(); hook_shape.set_profile(pixel_profile)
	var one_hook_frame := _hook_sweep(hook_shape, 1.4, 1)
	var two_hook_frames := _hook_sweep(hook_shape, 1.4, 1)
	var third_hook_frame := _hook_sweep(hook_shape, 1.4, 1)
	expect(not one_hook_frame.hook and not two_hook_frames.hook and third_hook_frame.hook and int(third_hook_frame.hook_sweep_samples) >= 3, "hook recognition rejects one/two-frame impulses and accepts the third deliberate physical sweep sample")

	var fast := MotionService.new(); fast.set_profile(pixel_profile); _physical_back_sweep(fast, 1.25, 3, 0.04)
	var fast_cast := _learned_snap_sweep(fast, 80.0, 3, 0.04)
	var late := MotionService.new(); late.set_profile(pixel_profile); _physical_back_sweep(late, 1.25, 3, 0.04)
	var late_cast := _learned_snap_sweep(late, 80.0, 3, 0.18)
	var expired := MotionService.new(); expired.set_profile(pixel_profile); _physical_back_sweep(expired, 1.25, 3, 0.04)
	var expired_cast := _learned_snap_sweep(expired, 80.0, 3, 0.22)
	expect(float(fast_cast.cast_quality) >= 0.99 and float(late_cast.cast_quality) > 0.0 and float(late_cast.cast_quality) < float(fast_cast.cast_quality) and float(expired_cast.cast_quality) == 0.0, "physical cock retains .22s full quality, late short-cast, and over-.65s rejection timing")

	var still := MotionService.new(); still.set_profile(pixel_profile)
	for frame in range(1200): still.queue_sample(_motion_sample(Vector3.ZERO, Vector3.ZERO)); still.update(0.05, true, true)
	var counts: Dictionary = still.get_diagnostics()
	expect(int(counts.cock_attempts) == 0 and int(counts.hook_attempts) == 0 and int(counts.completed_casts) == 0 and int(counts.reasons.linear) + int(counts.reasons.axis) + int(counts.reasons.polarity) + int(counts.reasons.gyro) + int(counts.reasons.timeout) == 0, "60 seconds of still samples creates no physical cock/hook attempts or derived failures")

	var fight_motion := _calibrated_motion()
	var pull_pose := Vector3(0, -9.8, 0)
	fight_motion.begin_fight(pull_pose)
	fight_motion.queue_sample({"gravity": pull_pose, "accelerometer": pull_pose, "gyro": Vector3(0, 0, 0.5)})
	var raised := fight_motion.update(0.25, false, false, true)
	fight_motion.queue_sample({"gravity": Vector3(-3.4, -9.19, 0), "accelerometer": Vector3(-3.4, -9.19, 0), "gyro": Vector3(0, 0, 0.5)})
	var lowered := fight_motion.update(0.25, false, false, true)
	expect(float(raised.fight_load) >= 0.95 and lowered.fight_lower and is_zero_approx(float(lowered.fight_load)), "unchanged fight path still starts raised and recognizes signed leftward easing")

func _test_haptic_signatures() -> void:
	expect(HapticService.android_amplitude(-0.2) == 1 and HapticService.android_amplitude(0.0) == 1, "Android haptic amplitude has a nonzero lower bound")
	expect(HapticService.android_amplitude(0.5) == 128 and HapticService.android_amplitude(1.0) == 255 and HapticService.android_amplitude(2.0) == 255, "Android haptic amplitude maps and clamps to 1..255")
	var keys: Dictionary = {}
	for fish in FishDefinition.all_planned():
		var signature := str(fish.fight_pulse) + "|" + str(fish.fight_cycle_seconds)
		expect(not keys.has(signature), "planned fish signature and cadence are unique: " + fish.id)
		expect(fish.fight_cycle_seconds > 0.0, "planned fish has an intentional cadence: " + fish.id)
		keys[signature] = true
	var fired: Array[Dictionary] = []
	var haptics := HapticService.new(func(duration, amplitude): fired.append({"duration": duration, "amplitude": amplitude}))
	var bluegill := FishDefinition.bluegill()
	haptics.start_fight(bluegill)
	var max_pending := 0
	for frame in range(300):
		haptics.update_fight(0.01, bluegill, 0.5)
		max_pending = maxi(max_pending, haptics.pending.size())
	expect(max_pending <= HapticService.MAX_PENDING_PULSES, "fight queue remains bounded")
	expect(fired.size() >= 4 and fired.size() <= 6, "fight cadence avoids per-frame vibration spam")
	# Each profile uses its own shared thresholds; low phrases remain physically
	# distinguishable from the paired high-tension warning.
	for profile_id in FightChallenge.IDS:
		var profile := FightChallenge.profile(profile_id)
		var low_warning_tension := lerpf(float(profile.low_critical), float(profile.low_warning), 0.5)
		var high_tension := lerpf(float(profile.high_warning), float(profile.high_critical), 0.5)
		var steady_pulses: Array[Dictionary] = []
		var steady_haptics := HapticService.new(func(duration, amplitude): steady_pulses.append({"duration": duration, "amplitude": amplitude}))
		steady_haptics.start_fight(bluegill, profile); steady_haptics.update_fight(0.23, bluegill, 0.50, 1.0, 1.0, profile)
		expect(steady_haptics.warning_tier == "steady" and not steady_pulses.is_empty() and int(steady_pulses[0].duration) == 38, "%s profile retains recognizable steady fish feedback" % profile_id)
		var pull_pulses: Array[Dictionary] = []
		var pull_haptics := HapticService.new(func(duration, amplitude): pull_pulses.append({"duration": duration, "amplitude": amplitude}))
		pull_haptics.start_fight(bluegill, profile); pull_haptics.update_fight(0.23, bluegill, low_warning_tension, 0.20, 1.0, profile)
		expect(pull_haptics.warning_tier == "pull" and pull_pulses.size() == 1 and int(pull_pulses[0].duration) == 90 and pull_haptics.pending.size() <= HapticService.MAX_PENDING_PULSES, "%s low warning overrides a quiet lull with a bounded pull cue" % profile_id)
		var slack_pulses: Array[Dictionary] = []
		var slack_haptics := HapticService.new(func(duration, amplitude): slack_pulses.append({"duration": duration, "amplitude": amplitude}))
		slack_haptics.start_fight(bluegill, profile); slack_haptics.update_fight(0.23, bluegill, float(profile.low_critical) * 0.5, 0.20, 1.0, profile); slack_haptics.update_fight(0.45, bluegill, float(profile.low_critical) * 0.5, 0.20, 1.0, profile)
		expect(slack_haptics.warning_tier == "slack" and slack_pulses.size() >= 2 and int(slack_pulses[0].duration) == 145 and int(slack_pulses[1].duration) == 30, "%s critical slack is a distinct long-plus-tap phrase" % profile_id)
		var high_pulses: Array[Dictionary] = []
		var profile_high := HapticService.new(func(duration, amplitude): high_pulses.append({"duration": duration, "amplitude": amplitude}))
		profile_high.start_fight(bluegill, profile); profile_high.update_fight(0.23, bluegill, high_tension, 0.20, 1.0, profile); profile_high.update_fight(0.30, bluegill, high_tension, 0.20, 1.0, profile)
		expect(profile_high.warning_tier == "ease" and high_pulses.size() >= 2 and int(high_pulses[0].duration) == 58 and int(high_pulses[1].duration) == 58, "%s high warning stays the distinguishable fast paired ease cue" % profile_id)
		var cancellation := HapticService.new()
		cancellation.start_fight(_fish_by_id("northern_pike"), profile); cancellation.update_fight(0.23, _fish_by_id("northern_pike"), 0.50, 1.0, 1.0, profile)
		cancellation.update_fight(0.01, _fish_by_id("northern_pike"), float(profile.low_critical) * 0.5, 0.20, 1.0, profile)
		expect(cancellation.warning_tier == "slack" and cancellation.pending.size() <= HapticService.MAX_PENDING_PULSES, "%s low transition cancels stale queued fish feedback before scheduling its warning" % profile_id)
		cancellation.update_fight(0.01, _fish_by_id("northern_pike"), 0.50, 1.0, 1.0, profile)
		expect(cancellation.warning_tier == "steady" and cancellation.pending.size() <= HapticService.MAX_PENDING_PULSES, "%s slack-to-steady immediately discards the stale long-plus-tap warning" % profile_id)
		cancellation.update_fight(0.01, _fish_by_id("northern_pike"), high_tension, 0.20, 1.0, profile)
		expect(cancellation.warning_tier == "ease" and cancellation.pending.size() <= HapticService.MAX_PENDING_PULSES, "%s low warning transition immediately replaces stale pulses with the high paired cue" % profile_id)
		cancellation.stop(); cancellation.set_enabled(false)
		expect(cancellation.pending.is_empty() and not cancellation.fighting, "%s stop/disable clears warning queue and fight scheduler" % profile_id)

	var high_fired: Array[Dictionary] = []
	var high_haptics := HapticService.new(func(duration, amplitude): high_fired.append({"duration": duration, "amplitude": amplitude}))
	var bass := _fish_by_id("largemouth_bass")
	high_haptics.start_fight(bass)
	for frame in range(60):
		high_haptics.update_fight(0.05, bass, 0.76)
	expect(high_haptics.warning_tier == "ease" and high_fired.size() >= 6 and int(high_fired[0].duration) == 58, "high warning repeats on its universal cadence")

	var red_fired: Array[Dictionary] = []
	var red_haptics := HapticService.new(func(duration, amplitude): red_fired.append({"duration": duration, "amplitude": amplitude}))
	var channel := _fish_by_id("channel_catfish")
	red_haptics.start_fight(channel)
	for frame in range(60):
		red_haptics.update_fight(0.05, channel, 0.95)
	expect(red_haptics.warning_tier == "snap" and red_fired.size() >= 10 and int(red_fired[0].duration) == 90, "red warning repeats on its universal cadence")
	expect(red_fired.size() > high_fired.size(), "red warning cadence is faster than high across fish")
	var normal_max := _max_emitted_amplitude(fired)
	var high_max := _max_emitted_amplitude(high_fired)
	var red_max := _max_emitted_amplitude(red_fired)
	expect(normal_max < high_max and high_max < red_max and bluegill.fight_cycle_seconds > HapticService.HIGH_WARNING_CYCLE_SECONDS and HapticService.HIGH_WARNING_CYCLE_SECONDS > HapticService.RED_WARNING_CYCLE_SECONDS and is_equal_approx(HapticService.standard_high_tension(), float(FightChallenge.profile("standard").high_warning)), "emitted haptic amplitude rises and warning interval shortens from normal to high to red")

	var reset_fired: Array[Dictionary] = []
	var reset_haptics := HapticService.new(func(duration, amplitude): reset_fired.append({"duration": duration, "amplitude": amplitude}))
	reset_haptics.start_fight(bluegill)
	reset_haptics.update_fight(0.23, bluegill, 0.76)
	reset_haptics.update_fight(0.30, bluegill, 0.76)
	expect(reset_haptics.warning_tier == "ease" and reset_fired.size() == 2 and int(reset_fired[0].duration) == 58, "high tension overrides species rhythm")
	reset_fired.clear()
	reset_haptics.update_fight(0.01, bluegill, 0.95)
	reset_haptics.update_fight(0.30, bluegill, 0.95)
	expect(reset_haptics.warning_tier == "snap" and reset_fired.size() == 2 and int(reset_fired[0].duration) == 90, "red tension emits urgent override")
	reset_fired.clear()
	reset_haptics.update_fight(0.01, bluegill, 0.5)
	expect(reset_haptics.warning_tier == "steady" and not reset_fired.is_empty() and int(reset_fired[0].duration) == 38, "falling tension restores species rhythm")

	var hook_fired: Array[Dictionary] = []
	var hook_haptics := HapticService.new(func(duration, amplitude): hook_fired.append({"duration": duration, "amplitude": amplitude}))
	hook_haptics.cue("hook")
	hook_haptics.start_fight(bluegill)
	hook_haptics.update_fight(0.01, bluegill, 0.5)
	expect(hook_fired.size() == 1 and int(hook_fired[0].duration) == 55, "hook cue does not overlap first fish phrase")
	hook_haptics.update_fight(0.22, bluegill, 0.5)
	expect(hook_fired.size() == 2 and int(hook_fired[1].duration) == 38, "species phrase begins after hook delay")
	var lull_fired: Array[Dictionary] = []
	var lull_haptics := HapticService.new(func(duration, amplitude): lull_fired.append({"duration": duration, "amplitude": amplitude}))
	var pike := _fish_by_id("northern_pike")
	lull_haptics.start_fight(pike)
	lull_haptics.update_fight(0.22, pike, 0.50, 1.0) # Starts a two-pulse normal phrase.
	lull_haptics.update_fight(0.05, pike, 0.50, 0.20) # Enters a lull before its second pulse is due.
	expect(lull_fired.size() == 1 and lull_haptics.pending.is_empty(), "entering a normal-effort lull drops every unfinished fish pulse immediately")
	lull_haptics.update_fight(0.68, pike, 0.50, 1.0)
	expect(lull_fired.size() == 2 and int(lull_fired[1].duration) == 150 and lull_haptics.pending.size() == 1, "the resumed normal phrase starts fresh instead of replaying its stale second pulse")

	var before_disable := reset_fired.size()
	reset_haptics.set_enabled(false)
	for frame in range(120):
		reset_haptics.update_fight(0.01, bluegill, 0.95)
	expect(reset_haptics.pending.is_empty() and reset_fired.size() == before_disable, "disabled haptics clear and suppress pending cues")

	var bite_guard_fired: Array[Dictionary] = []
	var bite_guard := HapticService.new(func(duration, amplitude): bite_guard_fired.append({"duration": duration, "amplitude": amplitude}))
	bite_guard.cue("bite")
	bite_guard.tick(0.0)
	expect(bite_guard_fired.size() == 1 and bite_guard.is_motion_guarded(), "the first bite pulse starts a deterministic motion settle guard")
	bite_guard.tick(0.239)
	expect(bite_guard.is_motion_guarded(), "the first bite guard survives through its pulse duration plus settle margin")
	bite_guard.tick(0.002)
	expect(bite_guard_fired.size() == 2 and bite_guard.is_motion_guarded(), "the second bite pulse extends the motion guard through its own duration and settle margin")
	bite_guard.tick(0.404)
	expect(bite_guard.is_motion_guarded(), "the second bite guard remains active until its exact deterministic boundary")
	bite_guard.tick(0.002)
	expect(not bite_guard.is_motion_guarded(), "the motion guard expires deterministically after the final bite pulse settle interval")
	bite_guard.start_fight(bluegill)
	bite_guard.update_fight(0.23, bluegill, 0.50)
	expect(bite_guard.fighting and bite_guard.is_motion_guarded(), "fight phrase scheduling remains active while the sensor guard is only used for ready/hook motion")
	bite_guard.stop()
	bite_guard.cue("bite"); bite_guard.tick(0.0); bite_guard.set_enabled(false)
	expect(not bite_guard.is_motion_guarded() and bite_guard.pending.is_empty(), "disabling haptics clears any active motion guard immediately")
	bite_guard.set_enabled(true); bite_guard.cue("bite"); bite_guard.tick(0.0); bite_guard.stop()
	expect(not bite_guard.is_motion_guarded() and bite_guard.pending.is_empty(), "stopping haptics clears its sensor guard immediately")
	var guarded_hook_motion := _calibrated_motion()
	guarded_hook_motion.queue_sample(_motion_sample(Vector3(1.35, 0, 0), Vector3(0, 0, 0.5)))
	var hook_while_guarded := guarded_hook_motion.update(0.05, false, false)
	var hook_after_guard := _hook_sweep(guarded_hook_motion)
	expect(not hook_while_guarded.hook and hook_after_guard.hook, "the haptic guard can suppress hook recognition while the fight motion path remains independently enabled")

	var terminal: Array[Dictionary] = []
	var terminal_haptics := HapticService.new(func(duration, amplitude): terminal.append({"duration": duration, "amplitude": amplitude}))
	terminal_haptics.start_fight(bluegill)
	terminal_haptics.update_fight(0.01, bluegill, 0.5)
	terminal.clear()
	terminal_haptics.cue("caught")
	terminal_haptics.tick(1.0)
	var caught_signature := str(terminal)
	expect(not terminal_haptics.fighting and terminal.size() == 3, "caught stops the fight and emits a lift cue")
	terminal.clear()
	terminal_haptics.cue("escaped")
	terminal_haptics.tick(1.0)
	expect(terminal.size() == 1 and caught_signature != str(terminal), "escaped terminal cue is distinct")
	terminal.clear(); terminal_haptics.cue("hook_miss"); terminal_haptics.tick(1.0)
	expect(terminal.size() == 2 and str(terminal) != caught_signature, "hook miss has a distinct two-pulse cue")
	terminal.clear(); terminal_haptics.cue("cock"); terminal_haptics.tick(0.1)
	expect(terminal.size() == 1 and int(terminal[0].duration) == 22, "accepted cast cock has one subtle haptic cue")
	terminal.clear(); terminal_haptics.cue("capture_window"); terminal_haptics.tick(1.0)
	expect(terminal.size() == 2 and int(terminal[0].duration) == 32, "each explicit capture window has a distinct two-pulse haptic cue")
	terminal.clear(); terminal_haptics.cue("capture_complete"); terminal_haptics.tick(1.0)
	expect(terminal.size() == 3 and int(terminal[2].duration) == 78, "explicit capture completion has a distinct saved cue")
	var preview_guard := HapticService.new(); preview_guard.cue("bite"); preview_guard.tick(0.01)
	expect(preview_guard.motion_guard_seconds() >= HapticService.MOTION_SETTLE_SECONDS and preview_guard.is_motion_guarded(), "preview haptics expose their remaining motor-settle period for menu return protection")
	preview_guard.stop()
	expect(is_zero_approx(preview_guard.motion_guard_seconds()), "stopping a haptic channel clears only that channel after its guard has been captured")

func _test_project_source_settings() -> void:
	var config := ConfigFile.new()
	expect(config.load("res://project.godot") == OK, "project settings load")
	expect(config.get_value("android", "package/unique_name") == "com.tak.castandcrank", "Android package is correct")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	expect("orientation=1" in project_source, "portrait orientation is enabled")
	expect(config.get_value("input_devices", "sensors/enable_accelerometer"), "accelerometer enabled")
	expect(config.get_value("input_devices", "sensors/enable_gravity"), "gravity enabled")
	expect(config.get_value("input_devices", "sensors/enable_gyroscope"), "gyroscope enabled")
	var export_config := ConfigFile.new(); expect(export_config.load("res://export_presets.cfg") == OK, "export settings load")
	expect(export_config.get_value("preset.0.options", "permissions/internet"), "Internet permission enabled")
	expect(export_config.get_value("preset.0.options", "permissions/access_network_state"), "network-state permission enabled")
	expect(export_config.get_value("preset.0.options", "permissions/vibrate"), "Android VIBRATE permission enabled")
	expect(int(export_config.get_value("preset.0.options", "version/code")) == 41 and export_config.get_value("preset.0.options", "version/name") == "0.8.1-tension1" and export_config.get_value("preset.0.options", "package/name") == "Hooked", "Tension v41 package version and visible Android label retain the package identifier")
	expect(export_config.get_value("preset.0.options", "package/signed"), "debug package requests signing")
	expect(export_config.get_value("preset.0.options", "gradle_build/compress_native_libraries"), "native libraries are compressed")
	expect(export_config.get_value("preset.0.options", "architectures/arm64-v8a") and not export_config.get_value("preset.0.options", "architectures/armeabi-v7a") and not export_config.get_value("preset.0.options", "architectures/x86") and not export_config.get_value("preset.0.options", "architectures/x86_64"), "debug package exports arm64 only")
	var excluded := str(export_config.get_value("preset.0", "exclude_filter"))
	var included := str(export_config.get_value("preset.0", "include_filter"))
	expect(included == "art/fonts/cinzel/OFL.txt" and FileAccess.file_exists("res://art/fonts/cinzel/Cinzel[wght].ttf") and FileAccess.file_exists("res://art/fonts/cinzel/OFL.txt"), "Cinzel's OFL license is narrowly included with the bundled runtime display font")
	expect("build/**" in excluded and "reports/**" in excluded and "tools/**" in excluded and "art/ui_v1/mockups/**" in excluded and "art/ui_v1/runtime_source/catch-frame-clean-v01.png" in excluded and "art/ui_v1/runtime_source/bluegill-v01.png" in excluded and "art/ui_v1/runtime_source/app-icon-v01.png" in excluded and "art/ui_v1/runtime_source/records-screen-v01.png" in excluded and "art/ui_v1/runtime_source/rod-bend-strip-v01.png" in excluded and "addons/admob/internal/editor/**" in excluded and "addons/admob/internal/mock/**" in excluded and not "addons/admob/gdscript/src/mediation/**" in excluded, "tools, mockups, and superseded unreferenced masters are excluded while runtime mediation dependencies remain")
	expect("addons/play_games/bin/**" in excluded and "addons/play_games/local_play_games_config.json" in excluded and not "addons/play_games/play_games_config.gd" in excluded, "Play Games owner material stays out of the PCK while the runtime config loader remains available")
	expect("res://addons/play_games/plugin.cfg" in str(config.get_value("editor_plugins", "enabled")) and FileAccess.file_exists("res://addons/play_games/export_plugin.gd") and FileAccess.file_exists("res://addons/play_games/play_games_config.gd"), "Play Games EditorExportPlugin is registered while its runtime config script is packaged")
	var play_games_export_source := FileAccess.get_file_as_string("res://addons/play_games/export_plugin.gd")
	expect("add_file(Config.RUNTIME_CONFIG_PATH" in play_games_export_source and "_configured_aar_matches" in play_games_export_source and "matches_bundled_aar" in play_games_export_source, "configured exports inject only the validated sanitized runtime Play Games config into the PCK")
	expect(config.get_value("application", "config/icon") == "res://art/ui_v1/runtime_source/app-icon-runtime-512.png" and config.get_value("application", "boot_splash/image") == "res://art/ui_v1/runtime_source/cedar-river-michigan-v01.png", "optimized runtime icon and approved Michigan Cedar splash are configured")
	var runtime_assets := {
		"res://art/ui_v1/runtime_source/pine-lake-clean-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/cedar-river-clean-v02.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/pine-fish-atlas-v02.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime_source/cedar-fish-atlas-v02.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime_source/waters-v40/mangrove_flats-photo-v01.png": Vector2i(948, 1659),
		"res://art/ui_v1/runtime_source/waters-v40/cypress_bayou-photo-v01.png": Vector2i(948, 1659),
		"res://art/ui_v1/runtime_source/waters-v40/moonlit_reservoir-photo-v01.png": Vector2i(948, 1659),
		"res://art/ui_v1/runtime_source/waters-v40/bluewater_offshore-photo-v01.png": Vector2i(948, 1660),
		"res://art/ui_v1/runtime_source/waters-v40/mangrove_flats-fish-atlas-v01.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime_source/waters-v40/cypress_bayou-fish-atlas-v01.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime_source/waters-v40/moonlit_reservoir-fish-atlas-v01.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime_source/waters-v40/bluewater_offshore-fish-atlas-v01.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime/control-kit-alpha-v01.png": Vector2i(1024, 1536),
		"res://art/ui_v1/runtime_source/rod-bend-strip-v01.png": Vector2i(1536, 1024),
		"res://art/ui_v1/runtime_source/rod-bend-repacked-v02.png": Vector2i(1536, 1024),
		"res://art/ui_v1/runtime_source/bobber-v01.png": Vector2i(1230, 1278),
		"res://art/ui_v1/runtime_source/water-reaction-strip-v01.png": Vector2i(2172, 724),
		"res://art/ui_v1/runtime_source/catch-frame-clean-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/bluegill-v01.png": Vector2i(1536, 1024),
		"res://art/ui_v1/runtime_source/app-icon-v01.png": Vector2i(1254, 1254),
		"res://art/ui_v1/runtime_source/app-icon-runtime-512.png": Vector2i(512, 512),
		"res://art/ui_v1/runtime_source/loading-splash-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/records-screen-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/records-screen-v02.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/records-screen-v03-empty-slots.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/journal-detail-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/top-nav-rustic-v01.png": Vector2i(2172, 724),
		"res://art/ui_v1/runtime_source/rustic-clipboard-blank-v01.png": Vector2i(941, 1672),
		"res://art/ui_v1/runtime_source/pine-lake-photoreal-v03.png": Vector2i(941, 1672)
	}
	for asset_path in runtime_assets:
		var texture := load(asset_path) as Texture2D
		var image := texture.get_image() if texture else Image.new()
		expect(not image.is_empty() and image.get_size() == runtime_assets[asset_path], "runtime UI asset has the expected dimensions: " + asset_path)
	for transparent_asset in ["res://art/ui_v1/runtime_source/rod-bend-strip-v01.png", "res://art/ui_v1/runtime_source/bobber-v01.png", "res://art/ui_v1/runtime_source/water-reaction-strip-v01.png", "res://art/ui_v1/runtime_source/bluegill-v01.png"]:
		var transparent_texture := load(transparent_asset) as Texture2D
		var transparent_image := transparent_texture.get_image() if transparent_texture else Image.new()
		expect(transparent_image.detect_alpha() != Image.ALPHA_NONE, "runtime animated asset retains alpha: " + transparent_asset)
	for atlas_asset in ["res://art/ui_v1/runtime_source/pine-fish-atlas-v02.png", "res://art/ui_v1/runtime_source/cedar-fish-atlas-v02.png", "res://art/ui_v1/runtime_source/waters-v40/mangrove_flats-fish-atlas-v01.png", "res://art/ui_v1/runtime_source/waters-v40/cypress_bayou-fish-atlas-v01.png", "res://art/ui_v1/runtime_source/waters-v40/moonlit_reservoir-fish-atlas-v01.png", "res://art/ui_v1/runtime_source/waters-v40/bluewater_offshore-fish-atlas-v01.png"]:
		var atlas_texture := load(atlas_asset) as Texture2D
		var atlas_image := atlas_texture.get_image() if atlas_texture else Image.new()
		var clear_boundaries := true
		for y in [511, 512, 1023, 1024]:
			for x in range(1024):
				if atlas_image.get_pixel(x, y).a != 0.0: clear_boundaries = false
		expect(not atlas_image.is_empty() and atlas_image.get_size() == Vector2i(1024, 1536) and atlas_image.get_pixel(0, 0).a == 0.0 and atlas_image.get_pixel(512, 768).a > 0.0 and clear_boundaries, "repacked fish atlas has transparent exact-cell boundaries and opaque per-row content: " + atlas_asset)
	var control_texture := load("res://art/ui_v1/runtime/control-kit-alpha-v01.png") as Texture2D
	var control_image := control_texture.get_image() if control_texture else Image.new()
	expect(not control_image.is_empty() and control_image.get_size() == Vector2i(1024, 1536) and control_image.get_pixel(0, 0).a == 0.0, "derived control-kit atlas retains transparent matte corners")
	var nav_texture := load("res://art/ui_v1/runtime_source/top-nav-rustic-v01.png") as Texture2D
	var nav_image := nav_texture.get_image() if nav_texture else Image.new()
	expect(not nav_image.is_empty() and nav_image.get_size() == Vector2i(2172, 724) and nav_image.detect_alpha() == Image.ALPHA_NONE, "rustic top navigation beam is one opaque authored runtime plate")
	var source := FileAccess.get_file_as_string("res://src/services/admob_service.gd")
	expect("ConsentInformation" in source and "MAX_AD_CONTENT_RATING_PG" in source and "failed_closed" in source and "game_content_reserve_height" in source and "OnInitializationCompleteListener" in source and "sdk_initializing" in source and "banner_requested" in source, "consent-first SDK-sequenced AdMob contract retained")
	var haptic_source := FileAccess.get_file_as_string("res://src/services/haptic_service.gd")
	expect("AndroidRuntime" in haptic_source and "getSystemService(\"vibrator\")" in haptic_source and "VibrationEffect" in haptic_source and "createOneShot" in haptic_source and "Build$VERSION" in haptic_source and "SDK_INT" in haptic_source and "VibrationAttributes" in haptic_source and "createForUsage" in haptic_source and "USAGE_MEDIA" in haptic_source and "AudioAttributes$Builder" in haptic_source and "USAGE_GAME" in haptic_source and "CONTENT_TYPE_SONIFICATION" in haptic_source and "vibrate(effect, _android_vibration_attributes)" in haptic_source and "vibrate(effect, _android_audio_attributes)" in haptic_source and "_android_vibrator.vibrate(maxi(1, duration_ms), _android_audio_attributes)" in haptic_source and "Input.vibrate_handheld" in haptic_source and "capture_window" in haptic_source and "capture_complete" in haptic_source, "Android explicit non-touch attributes and capture haptic cues are retained")
	expect("MOTION_SETTLE_SECONDS := 0.30" in haptic_source and "is_motion_guarded" in haptic_source and "motion_guard_seconds" in haptic_source and "_motion_guard_remaining" in haptic_source, "haptic pulses expose the deterministic sensor-settle guard for safe menu return")
	var main_source := FileAccess.get_file_as_string("res://src/ui/main.gd")
	expect(not "rod-bend-repacked-v02.png" in main_source and not "water-reaction-strip-v01.png" in main_source and not "control-kit-alpha-v01.png" in main_source and not "catch-rustic-v01.png" in main_source, "normal runtime no longer loads assets excluded from the Android PCK")
	var motion_source := FileAccess.get_file_as_string("res://src/services/motion_service.gd")
	var capture_source := FileAccess.get_file_as_string("res://src/services/cast_capture_service.gd")
	expect("randf()" in main_source and not "haptics.cue(\"cock\")" in main_source and "haptics.cue(\"bite\")" in main_source and "haptics.cue(\"hook\")" in main_source and "menu_motion_settle_remaining" in main_source and "MOTION_CAST_CANCEL reason=timeout" in main_source and "snap_projection=%.2f" in main_source and "cock_projection=%.2f" in main_source and "MOTION_HOOK state=REELING projection=%.2f alignment=%.2f gyro=%.2f sweep_samples=%d" in main_source, "physical arm selects a fresh weighted fish without motor feedback and menu return owns a deterministic motion settle guard")
	expect("PROFILE_HANDEDNESS_ALIGNMENT" in motion_source and "CALIBRATION_HANDEDNESS_ALIGNMENT" in motion_source and "RUNTIME_X_POLARITY_ALIGNMENT" in motion_source and "RUNTIME_PHYSICAL_COCK_THRESHOLD_FACTOR := 6.0" in motion_source and "RUNTIME_SNAP_THRESHOLD_FACTOR := 24.0" in motion_source and "RUNTIME_SNAP_AXIS_MIN := 0.78" in motion_source and "RUNTIME_SNAP_POLARITY_MIN := 0.62" in motion_source and "RUNTIME_HOOK_MIN_IMPULSE_FACTOR := 0.055" in motion_source and "_physical_cock_threshold" in motion_source and "_runtime_snap_threshold" in motion_source and "linear.dot(_back_axis_direction())" in motion_source and "_back_axis = _back_axis_direction()" in motion_source and "RUNTIME_SWEEP_MIN_SAMPLES" in motion_source and "RUNTIME_COCK_MIN_IMPULSE_FACTOR" in motion_source and "RUNTIME_SNAP_MIN_IMPULSE_FACTOR" in motion_source and is_equal_approx(MotionService.RUNTIME_COCK_MIN_IMPULSE_FACTOR, 0.045) and is_equal_approx(MotionService.RUNTIME_SNAP_MIN_IMPULSE_FACTOR, 0.055) and "_sweep_ready(\"hook\"" in motion_source and "hook_projection" in motion_source and "hook_sweep_samples" in motion_source and "_sweep_ready" in motion_source and "_snap_axis_tolerance" in motion_source and "_snap_polarity_tolerance" in motion_source and "_snap_gyro_threshold" in motion_source and "RUNTIME_FULL_REVERSAL_SECONDS" in motion_source and "RUNTIME_MAX_REVERSAL_SECONDS" in motion_source and "cast_cancel" in motion_source and "snap_projection" in motion_source and "_burst_failure_latched" in motion_source and "MOTION_FAIL stage=%s reason=%s count=%d" in motion_source and not "SNAP_MIN_AXIS_TOLERANCE" in motion_source and not "MOTION_FAIL linear=" in motion_source and not "MOTION_FAIL gyro=" in motion_source and "sqrt(raw_fight_load)" in motion_source, "v25 retains signed physical cock with replay-backed snap floors and derived-only three-sample hook telemetry")
	expect("CAST_COUNT := 10" in capture_source and "ACTIVE_WINDOW_SECONDS := 2.0" in capture_source and "REST_WINDOW_SECONDS := 1.0" in capture_source and "MAX_SAMPLES_PER_CAST" in capture_source and "completed" in capture_source and "accelerometer" in capture_source and "linear" in capture_source and not "print(" in capture_source, "raw samples are bounded and retained only by the explicit capture service without logging")
	var waters_input_source := main_source.get_slice("func _gui_input(event: InputEvent) -> void:", 1).get_slice("func _scroll_waters", 0)
	expect(not "HOLD TO CAST" in main_source and not "SET HOOK" in main_source and not "SAFE BYPASS" in main_source and not "cast_rect" in main_source and not "reel_center" in main_source and "if overlay == \"locations\"" in waters_input_source and "InputEventScreenDrag" in waters_input_source and "_handle_waters_drag" in waters_input_source and not "_handle_drag" in main_source and not "reel_fallback" in main_source and "TILT RIGHT, THEN SNAP LEFT" in main_source and "TILT LEFT, THEN SNAP RIGHT" in main_source and not "COCK RIGHT, THEN SNAP LEFT" in main_source and "FISH ON — WAIT FOR THE PULSES" in main_source and "BITE — PULL RIGHT" in main_source and "session.state == FishingSession.State.HOOK_WINDOW" in main_source and "TILT LEFT TO EASE" in main_source and "TILT RIGHT TO PULL" in main_source and "MOTION_FIGHT caught elapsed=" in main_source and "MOTION_FIGHT escaped elapsed=" in main_source and "_record_catch_once" in main_source and "records-screen-rustic-v01.png" in main_source and "rustic-clipboard-blank-v01.png" in main_source and "ROD_TIP_ANCHORS" in main_source and "_rod_tip_for_frame" in main_source and "RECORD 10 CASTS" in main_source and "cast_capture.is_active()" in main_source and "_start_cast_capture" in main_source and not "DIAGNOSTIC_AUTO_CAPTURE_ON_ANDROID" in main_source and "DisplayServer.get_display_safe_area" in main_source and "_virtual_safe_top" in main_source and "set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)" in main_source and "mouse_filter = Control.MOUSE_FILTER_STOP" in main_source and "font = ThemeDB.fallback_font" in main_source and "queue_redraw()" in main_source and "can_recast_from_motion" in main_source, "Tilt instructions stay motion-only in gameplay while Waters alone accepts drag scrolling")
	expect("willow_pond_texture" in main_source and "hatteras_inlet_texture" in main_source and "mangrove_flats_texture" in main_source and "cypress_bayou_texture" in main_source and "moonlit_reservoir_texture" in main_source and "bluewater_offshore_texture" in main_source and "waters-v40/mangrove_flats-fish-atlas-v01.png" in main_source and "waters-v40/bluewater_offshore-fish-atlas-v01.png" in main_source and "_draw_fish_atlas_contained" in main_source and "_fish_atlas_region" in main_source and "atlantic_tarpon" in main_source and "atlantic_sailfish" in main_source and not "row * 512" in main_source, "all twenty-four fish use explicit shared atlas regions and correct location art")
	var gameplay_chrome_source := main_source.get_slice("func _draw_top_chrome(s: FishingSession) -> void:", 1).get_slice("func _draw_glance_hint", 0)
	var glance_source := main_source.get_slice("func _draw_glance_hint(s: FishingSession) -> void:", 1).get_slice("func _draw_top_hint_lines", 0)
	var catch_source := main_source.get_slice("func _draw_catch_reveal(s: FishingSession) -> void:", 1).get_slice("func _draw_escape_card", 0)
	expect("s.location_id.replace" in gameplay_chrome_source and not "s.fish.display_name" in gameplay_chrome_source and "_draw_metal_location_header" in gameplay_chrome_source and "quiet_location_sign" in gameplay_chrome_source, "gameplay chrome remains neutral and centers the state-aware location sign without revealing the selected fish")
	expect("if s.state == FishingSession.State.LINE_OUT: return" in glance_source and not "habitat_name" in glance_source and not "cast_distance_m" in glance_source and "TILT %s, THEN SNAP %s" in glance_source and "FISH ON — WAIT FOR PULSES" in glance_source, "line-out leaves only the centered location sign while other states retain compact motion guidance")
	expect(not "CAST\"" in catch_source and not "cast_distance_m" in catch_source, "catch reveal retains fish length and record status without repeating a cast-distance caption")
	expect("CINZEL_VARIABLE_FONT" in main_source and "FontVariation.new()" in main_source and "variation_opentype = {\"wght\": 680}" in main_source and "_centered_outlined_text_in_rect" in main_source, "the bundled Cinzel metal title and outlined readable motion guidance use separate native text treatments")
	expect(not "catch-frame-clean-v01.png" in main_source and not "catch_frame_texture" in main_source and "FIRST CATCH" in main_source and "NEW BEST" in main_source and "MATCHED BEST" in main_source and "catch_prior_best_cm" in main_source, "catch reveal uses a scenic native plaque with prior-record status rather than a trophy frame")
	var records_source := main_source.get_slice("func _draw_records() -> void:", 1).get_slice("func _fish_definition", 0)
	expect("records-screen-rustic-v01.png" in main_source and "rustic-clipboard-blank-v01.png" in main_source and "UNDISCOVERED" in records_source and "_draw_fish_atlas_contained" in records_source and "_refresh_records_geometry" in records_source and "journal_fish_rects" in records_source and "journal_slot_rects" in main_source and not "_text(\"CATCH RECORDS\"" in records_source, "Records uses one opaque blank-slot master with shared fish/name/stats/tap geometry")
	expect("_draw_location_card" in main_source and "mangrove_ready" in main_source and "bayou_line_out" in main_source and "moonlit_reeling" in main_source and "offshore_reduced" in main_source and "mangrove_tarpon_catch" in main_source and "bayou_flathead_catch" in main_source and "moonlit_bluecat_catch" in main_source and "offshore_sailfish_catch" in main_source and "records_page3" in main_source and "records_page4" in main_source and "waters_middle_safe180" in main_source and "waters_bottom_safe180" in main_source and "records_empty" in main_source and "_clear_capture_records" in main_source and "cast_armed" in main_source and "line_out" in main_source and "hook_window" in main_source and "reduced_bite" in main_source and "reduced_reeling_high" in main_source and "reduced_catch" in main_source, "capture scenarios cover all twenty-four species, four record pages, water-scroll endpoints, motion states, and reduced-motion variants without a save write")
	expect("FISH GOT AWAY" in main_source and "Ease forward when warning pulses speed up." in main_source and not "THE LINE WENT SLACK" in main_source, "escape card presents one neutral reason with motion-first recovery guidance")
	expect("SELECTED" in main_source and "rect.intersection(waters_viewport_rect).grow(-4)" in main_source and "_waters_location_at" in main_source, "location cards retain selected geometry and clipped selection hit routing")
	var rod_repacked := load("res://art/ui_v1/runtime_source/rod-bend-repacked-v02.png") as Texture2D
	var rod_repacked_image := rod_repacked.get_image() if rod_repacked else Image.new()
	var rod_boundaries_clear := true
	for x in [511, 512, 1023, 1024]:
		for y in range(0, 1024, 16):
			if rod_repacked_image.get_pixel(x, y).a != 0.0: rod_boundaries_clear = false
	expect(not rod_repacked_image.is_empty() and rod_repacked_image.get_size() == Vector2i(1536, 1024) and rod_boundaries_clear, "repacked rod atlas has strict transparent frame boundaries")
	expect("rod-photoreal-alpha-v01.png" in main_source and "_draw_photoreal_rod" in main_source and "_photoreal_rod_point" in main_source and "draw_polygon(points" in main_source and not "draw_texture_rect(rod_frames[rod_region]" in main_source, "fight uses one continuous photoreal textured rod mesh and shares its deformed terminal-guide mapping with mono")
	expect(not "control-kit-alpha-v01.png" in main_source and "_draw_wood_control" in main_source and "TEST VIBRATION" in main_source and "MOTION SETUP" in main_source and "BACK TO FISHING" in main_source and "SETTINGS" in main_source and "SELECTED • " in main_source and not "_text(\"⚙\"" in main_source, "rustic wood controls replace obsolete control-kit skins across Settings and exits")
	var top_chrome_source := main_source.get_slice("func _draw_top_chrome(s: FishingSession) -> void:", 1).get_slice("func _draw_glance_hint", 0)
	expect("top-nav-rustic-v01.png" in main_source and "_refresh_top_nav_geometry()" in main_source and "_handle_press(pos: Vector2)" in main_source and "records_rect" in main_source and "locations_rect" in main_source and "settings_rect" in main_source and not "_draw_top_nav_label" in top_chrome_source and not "\"RECORDS\"" in top_chrome_source and not "\"WATERS\"" in top_chrome_source and not "\"SETTINGS\"" in top_chrome_source and "FINISH THIS CAST" in main_source and "controller._open_settings()" in main_source and "controller._can_open_records()" in main_source and not "_can_open_journal" in main_source and not "menu_medallion" in main_source, "icon-only rustic top navigation shares current safe-area geometry for drawing and hits; Settings remains available while Records and Waters explain active-fishing gates")
	var locations_source := main_source.get_slice("func _draw_locations() -> void:", 1).get_slice("func _draw_location_card", 0)
	expect("records_safe_top" in main_source and "safe_top_override = 91.0" in main_source and "_journal_map_y" in main_source and "back_to_fishing_rect = Rect2(32, safe_top + 18" in locations_source and "waters_viewport_rect = Rect2(30, safe_top + 124" in locations_source and "_draw_wood_control(Rect2(0, safe_top, 720, 108))" in locations_source and "BACK TO FISHING" in main_source and not "back_medallion" in records_source and not "back_medallion" in locations_source and not "_text(\"BACK\"" in locations_source, "Records and Waters retain shared safe-aware Back to Fishing controls without page-turn arrows")
	expect("top_nav_ready" in main_source and "top_nav_safe_top" in main_source and "settings_button_line_out_safe_top" in main_source and "waters_button_ready_safe_top" in main_source and "records_button_ready_safe_top" in main_source and "top_nav_active_locked" in main_source and "_capture_top_nav_press" in main_source and "view._handle_press(view.settings_rect.get_center())" in main_source and "view._handle_press(view.locations_rect.get_center())" in main_source and "view._handle_press(view.records_rect.get_center())" in main_source, "deterministic navigation capture fixtures use the same current-geometry press handler")
	expect("_refresh_modal_layout()" in main_source and "_draw_modal_panel()" in main_source and "modal_footer_rect" in main_source and "settings_footer_close_rect.has_point(pos)" in main_source and "settings_haptics_rect.has_point(pos)" in main_source and "motion_sensitivity_rect.has_point(pos)" in main_source and not "draw_style_box(_control_style(\"plaque_normal\"), settings_footer_close_rect)" in main_source, "Settings and Motion Setup route through one safe-aware baked-footer target without a duplicate runtime plaque")
