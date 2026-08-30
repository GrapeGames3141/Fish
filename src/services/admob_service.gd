class_name AdMobService
extends RefCounted

const PLUGIN_VERSION := "5.0.0"
const TEST_BANNER_AD_UNIT := "ca-app-pub-3940256099942544/6300978111"
const CONTRACT := "native_bottom_owns_creative_and_safe_inset"

var available := false
var initialized := false
var native_height_px := 0.0
var banner = null

func initialize() -> void:
	available = Engine.has_singleton("PoingGodotAdMob") or Engine.has_singleton("AdMob")
	if not available:
		initialized = false
		return
	# UMP consent must be requested before this method in a production release.
	MobileAds.initialize()
	var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	banner = AdView.new(TEST_BANNER_AD_UNIT, size, AdPosition.BOTTOM)
	banner.load_ad(AdRequest.new())
	initialized = true

func refresh_native_banner_diagnostics() -> void:
	if banner != null:
		native_height_px = maxf(0.0, float(banner.get_height_in_pixels()))

func destroy() -> void:
	if banner != null:
		banner.destroy()
		banner = null

func game_content_reserve_height() -> float:
	return 0.0

func native_banner_height() -> float:
	return native_height_px

func describe_desktop_fallback() -> String:
	return "AdMob native singleton unavailable; desktop fallback keeps reserve at 0."
