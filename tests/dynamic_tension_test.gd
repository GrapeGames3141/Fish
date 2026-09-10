extends SceneTree

const FishDefinition = preload("res://src/domain/fish_definition.gd")
const FishingSession = preload("res://src/domain/fishing_session.gd")
const FightChallenge = preload("res://src/domain/fight_challenge.gd")
const HapticService = preload("res://src/services/haptic_service.gd")

const FRAME_RATES := [30, 60, 120]
const SIZES := [0.12, 0.50, 0.96]
const BEHAVIORS := [0.0, 0.37, 0.83]
const SAMPLE_SECONDS := [0.0, 0.82, 1.20, 2.4, 4.8, 7.2, 10.8, 16.0]

var failures: Array[String] = []
var profile_cases := 0
var measured := {}

func _init() -> void:
	_test_live_profile_invariants()
	_test_live_profile_fps_and_pause_stability()
	_test_dynamic_edge_exposure_and_reward()
	_test_haptic_profile_parity()
	if failures.is_empty():
		print("DYNAMIC_TENSION " + JSON.stringify({"profile_cases": profile_cases, "tarpon": measured}))
		print("PASS: dynamic tension v41")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d dynamic tension assertions" % failures.size())
		quit(1)

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _fight(fish: FishDefinition, challenge: String, size_fraction: float, behavior: float) -> FishingSession:
	var game := FishingSession.new()
	game.set_location(fish.location_id, 0.0)
	game.set_next_cast_challenge(challenge)
	game.set_encounter_rolls(0.0, size_fraction, behavior, 0.50, 0.50)
	game.arm_cast(); game.release_cast(0.50)
	# This focused domain probe assigns the planned fish after production release;
	# selection odds are tested separately. Fight profile always uses this real fish.
	game.fish = fish
	game.behavior_roll = behavior
	game.catch_length_cm = snappedf(lerpf(fish.min_length_cm, fish.max_length_cm, size_fraction), 0.1)
	game.state = FishingSession.State.HOOK_WINDOW
	game.set_hook()
	return game

func _test_live_profile_invariants() -> void:
	for fish in FishDefinition.all_planned():
		for challenge in FightChallenge.IDS:
			for size_fraction in SIZES:
				for behavior in BEHAVIORS:
					var game := _fight(fish, challenge, size_fraction, behavior)
					var base_before := JSON.stringify(game.challenge_profile)
					for seconds in SAMPLE_SECONDS:
						game.fight_elapsed = seconds
						game.refresh_live_challenge_profile()
						var live := game.live_challenge_profile
						expect(FightChallenge.has_ordered_bounds(live), "ordered live bounds for %s/%s size %.2f behavior %.2f at %.2fs" % [fish.id, challenge, size_fraction, behavior, seconds])
						expect(float(live.high_warning) - float(live.low_warning) >= FightChallenge.MIN_GREEN_WIDTH - 0.0001, "viable green width for %s/%s" % [fish.id, challenge])
						expect(float(live.low_warning) - float(live.low_critical) >= FightChallenge.MIN_WARNING_BUFFER - 0.0001 and float(live.high_critical) - float(live.high_warning) >= FightChallenge.MIN_WARNING_BUFFER - 0.0001, "warning buffers survive moving red edges for %s/%s" % [fish.id, challenge])
						profile_cases += 1
					expect(JSON.stringify(game.challenge_profile) == base_before, "base profile remains immutable for %s/%s" % [fish.id, challenge])

func _profile_after_steps(fish: FishDefinition, challenge: String, size_fraction: float, behavior: float, fps: int, seconds: float) -> Dictionary:
	var game := _fight(fish, challenge, size_fraction, behavior)
	var delta := 1.0 / float(fps)
	for _frame in range(roundi(seconds * fps)):
		game.fight_elapsed += delta
		game.refresh_live_challenge_profile()
	return game.live_challenge_profile

func _test_live_profile_fps_and_pause_stability() -> void:
	var tarpon := FishDefinition.all_planned().filter(func(fish): return fish.id == "atlantic_tarpon")[0] as FishDefinition
	var reference := _profile_after_steps(tarpon, "expert", 0.96, 0.83, 60, 8.0)
	for fps in FRAME_RATES:
		var profile := _profile_after_steps(tarpon, "expert", 0.96, 0.83, fps, 8.0)
		for key in ["target_center", "low_critical", "low_warning", "high_warning", "high_critical"]:
			expect(is_equal_approx(float(profile[key]), float(reference[key])), "live profile is FPS-stable at %dHz (%s)" % [fps, key])
	var paused := _fight(tarpon, "expert", 0.96, 0.83)
	paused.fight_elapsed = 7.0; paused.refresh_live_challenge_profile()
	var before_pause := JSON.stringify(paused.live_challenge_profile)
	paused.tick(0.0)
	expect(JSON.stringify(paused.live_challenge_profile) == before_pause, "tick(0) / pause does not advance the live target")
	# Sweep every challenge and behavior phase through startup blend plus a full
	# cycle for the strongest catalog fish. This mirrors session refresh directly,
	# avoiding a simulated-player oracle while bounding worst physical edge speed.
	var strongest: FishDefinition = tarpon
	for candidate in FishDefinition.all_planned():
		if candidate.fight_strength > strongest.fight_strength: strongest = candidate
	var max_velocity := 0.0
	for challenge in FightChallenge.IDS:
		var base := FightChallenge.profile(challenge)
		for phase_step in range(21):
			var behavior := float(phase_step) / 20.0
			var last: Dictionary = {}
			for step in range(1301):
				var seconds := float(step) * 0.01
				var dynamic := FightChallenge.dynamic_profile(base, strongest.fight_strength, 0.96, behavior, seconds)
				var live := FightChallenge.blend_profile(base, dynamic, smoothstep(float(base.startup_grace), float(base.startup_grace) + 2.40, seconds))
				if not last.is_empty():
					for key in ["low_critical", "low_warning", "high_warning", "high_critical"]:
						max_velocity = maxf(max_velocity, absf(float(live[key]) - float(last[key])) / 0.01)
				last = live
	measured["max_edge_velocity"] = max_velocity
	expect(max_velocity <= 0.085, "all live band edges remain below 8.5 percentage points/second through startup blending and phase sweep")

func _test_dynamic_edge_exposure_and_reward() -> void:
	var tarpon := FishDefinition.all_planned().filter(func(fish): return fish.id == "atlantic_tarpon")[0] as FishDefinition
	var game := _fight(tarpon, "expert", 0.96, 0.83)
	var centers: Array[float] = []
	var widths: Array[float] = []
	var lows: Array[float] = []
	var highs: Array[float] = []
	for step in range(40):
		game.fight_elapsed = 2.1 + float(step) * 0.32
		game.refresh_live_challenge_profile()
		var profile := game.live_challenge_profile
		centers.append(float(profile.target_center)); widths.append(float(profile.high_warning) - float(profile.low_warning)); lows.append(float(profile.low_critical)); highs.append(float(profile.high_critical))
	var center_span: float = float(centers.max()) - float(centers.min())
	var width_span: float = float(widths.max()) - float(widths.min())
	var low_span: float = float(lows.max()) - float(lows.min())
	var high_span: float = float(highs.max()) - float(highs.min())
	measured.merge({"center_span": center_span, "green_width_min": widths.min(), "green_width_max": widths.max(), "low_critical_span": low_span, "high_critical_span": high_span}, true)
	expect(center_span >= 0.025 and center_span <= 0.095, "large Expert Tarpon center drifts visibly but stays bounded")
	expect(width_span >= 0.020 and widths.min() <= float(game.challenge_profile.high_warning) - float(game.challenge_profile.low_warning) - 0.045, "large Expert Tarpon green zone breathes and narrows mechanically")
	expect(low_span >= 0.018 and high_span >= 0.018, "both red failure edges grow and shrink over the fight")
	var live := game.live_challenge_profile
	var reward_center := FightChallenge.center_reward(float(live.target_center), live)
	var reward_edge := FightChallenge.center_reward(float(live.high_warning), live)
	expect(reward_center > reward_edge, "landing reward peaks at the moving live center rather than fixed middle")
	# An edge that moves over a held tension changes exposure through the same live
	# threshold the red dwell timer reads; it cannot be merely a painted animation.
	var high_exposure := _edge_exposure_game(tarpon, "high")
	var low_exposure := _edge_exposure_game(tarpon, "low")
	expect(high_exposure != null and low_exposure != null, "Tarpon supplies both shrinking high and growing low critical-edge phases")
	if high_exposure != null:
		var high_game: FishingSession = high_exposure
		var high_before_base := high_game.tension < float(high_game.challenge_profile.high_critical)
		high_game.tick(0.001)
		expect(high_before_base and high_game.state == FishingSession.State.REELING and high_game.red_elapsed > 0.0, "a shrunken live high red edge begins dwell below the base edge without instant failure")
		high_game.red_elapsed = float(high_game.challenge_profile.danger_seconds) - 0.0005
		high_game.tick(0.001)
		expect(high_game.state == FishingSession.State.ESCAPED, "high failure uses the live moved red boundary after its configured dwell")
	if low_exposure != null:
		var low_game: FishingSession = low_exposure
		var low_above_base := low_game.tension > float(low_game.challenge_profile.low_critical)
		low_game.tick(0.001)
		expect(low_above_base and low_game.state == FishingSession.State.REELING and low_game.slack_elapsed > 0.0, "a grown live low red edge begins dwell above the base edge without instant failure")
		low_game.slack_elapsed = float(low_game.challenge_profile.slack_seconds) - 0.0005
		low_game.tick(0.001)
		expect(low_game.state == FishingSession.State.ESCAPED, "low failure uses the live moved red boundary after its configured dwell")
	game.set_next_cast_challenge("relaxed")
	expect(game.challenge_id == "expert" and game.challenge_profile.id == "expert", "settings cannot change the immutable active-cast base profile")
	game.state = FishingSession.State.HOOK_WINDOW; game.set_hook()
	expect(JSON.stringify(game.live_challenge_profile) == JSON.stringify(game.challenge_profile), "re-hook clears previous dynamic state back to the cast baseline")
	game.reset()
	expect(JSON.stringify(game.live_challenge_profile) == JSON.stringify(game.challenge_profile), "reset clears prior live profile state")
	var bluegill := FishDefinition.bluegill()
	var ordinary := _fight(bluegill, "standard", 0.50, 0.37)
	ordinary.fight_elapsed = 8.0; ordinary.refresh_live_challenge_profile()
	expect(JSON.stringify(ordinary.live_challenge_profile) == JSON.stringify(ordinary.challenge_profile), "ordinary Bluegill retains a stable baseline profile")

func _edge_exposure_game(fish: FishDefinition, edge: String) -> FishingSession:
	var game := _fight(fish, "expert", 0.96, 0.83)
	for step in range(160):
		game.fight_elapsed = 2.1 + float(step) * 0.10
		game.refresh_live_challenge_profile()
		if edge == "high" and float(game.live_challenge_profile.high_critical) < float(game.challenge_profile.high_critical) - 0.015:
			game.tension = (float(game.live_challenge_profile.high_critical) + float(game.challenge_profile.high_critical)) * 0.5
			game.set_rod_load(0.72)
			return game
		if edge == "low" and float(game.live_challenge_profile.low_critical) > float(game.challenge_profile.low_critical) + 0.015:
			game.tension = (float(game.live_challenge_profile.low_critical) + float(game.challenge_profile.low_critical)) * 0.5
			game.set_rod_load(0.0)
			return game
	return null

func _test_haptic_profile_parity() -> void:
	var tarpon := FishDefinition.all_planned().filter(func(fish): return fish.id == "atlantic_tarpon")[0] as FishDefinition
	var game := _fight(tarpon, "expert", 0.96, 0.83)
	var selected: Dictionary = {}
	for step in range(80):
		game.fight_elapsed = 2.1 + float(step) * 0.25; game.refresh_live_challenge_profile()
		var live := game.live_challenge_profile
		if float(live.high_warning) < float(game.challenge_profile.high_warning) - 0.015:
			selected = live; break
	expect(not selected.is_empty(), "dynamic profile supplies a shifted high warning for haptic parity")
	if selected.is_empty(): return
	var tension := (float(selected.high_warning) + float(game.challenge_profile.high_warning)) * 0.5
	var emitted: Array[Dictionary] = []
	var haptics := HapticService.new(func(duration, amplitude): emitted.append({"duration": duration, "amplitude": amplitude}))
	haptics.start_fight(tarpon, game.challenge_profile)
	haptics.update_fight(0.30, tarpon, tension, 1.0, 1.0, selected)
	expect(haptics.warning_tier == FightChallenge.tier(tension, selected) and haptics.warning_tier in ["ease", "snap"], "haptics use the same shifted live ease tier as the meter")
	haptics.update_fight(0.10, tarpon, tension, 0.20, 1.0, game.challenge_profile)
	expect(haptics.warning_tier == FightChallenge.tier(tension, game.challenge_profile) and not haptics.pending.any(func(pulse): return int(pulse.duration) == 58), "returning to the base tier cancels stale ease-warning pulses")
	var low_selected: Dictionary = {}
	for step in range(80):
		game.fight_elapsed = 2.1 + float(step) * 0.25; game.refresh_live_challenge_profile()
		if float(game.live_challenge_profile.low_warning) > float(game.challenge_profile.low_warning) + 0.015:
			low_selected = game.live_challenge_profile; break
	expect(not low_selected.is_empty(), "dynamic profile supplies a shifted low warning for haptic parity")
	if low_selected.is_empty(): return
	var low_tension := (float(game.challenge_profile.low_warning) + float(low_selected.low_warning)) * 0.5
	haptics.update_fight(0.10, tarpon, low_tension, 1.0, 1.0, low_selected)
	expect(haptics.warning_tier == "pull", "haptics use the same shifted live pull tier as the meter")
	haptics.update_fight(0.10, tarpon, low_tension, 0.20, 1.0, game.challenge_profile)
	expect(haptics.warning_tier == "steady" and not haptics.pending.any(func(pulse): return int(pulse.duration) == 90), "returning from pull cancels stale pull-warning pulses")
