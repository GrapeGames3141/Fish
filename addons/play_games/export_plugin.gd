@tool
class_name PlayGamesRecordsExportPlugin
extends EditorExportPlugin

const Config = preload("res://addons/play_games/play_games_config.gd")
const AAR_PATH := "res://addons/play_games/bin/cast-and-crank-play-games-release.aar"
const BUILD_RECEIPT_PATH := "res://addons/play_games/bin/build_receipt.json"

func _get_name() -> String:
	return "PlayGamesRecordsExport"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray([AAR_PATH]) if _configured_aar_matches() else PackedStringArray()
func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["com.google.android.gms:play-services-games-v2:22.0.0"]) if _configured_aar_matches() else PackedStringArray()

func _configured_aar_matches() -> bool:
	var configuration := Config.as_dictionary()
	return Config.matches_bundled_aar(configuration, AAR_PATH, BUILD_RECEIPT_PATH)

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not _configured_aar_matches(): return
	var configuration := Config.as_dictionary()
	# IDs are public Play Games resource identifiers, not credentials. This is the
	# sole runtime config copy; the owner JSON remains excluded by the preset.
	var bytes := JSON.stringify({"game_id": str(configuration.get("game_id", "")), "leaderboards": configuration.get("leaderboards", {}), "internal_testboard": bool(configuration.get("internal_testboard", false))}).to_utf8_buffer()
	add_file(Config.RUNTIME_CONFIG_PATH, bytes, false)
