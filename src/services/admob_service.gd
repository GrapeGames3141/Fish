class_name AdMobService
extends RefCounted

const PLUGIN_VERSION := "5.0.0"
const TEST_BANNER_AD_UNIT := "ca-app-pub-3940256099942544/6300978111"
const CONTRACT := "native_bottom_owns_creative_and_safe_inset"

var available := false
var initialized := false
var native_height_px := 0.0
var banner = null
var consent_state := "desktop_inert"
var diagnostic := ""
var banner_requested := false
var _sdk_initializing := false
var _sdk_callback_consumed := false
var _sdk_generation := 0
var _initialization_request: Callable
var _banner_request: Callable

func _init(initialization_request: Callable = Callable(), banner_request: Callable = Callable()) -> void:
	_initialization_request = initialization_request
	_banner_request = banner_request

func initialize() -> void:
	destroy()
	diagnostic = ""
	available = OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMob") and Engine.has_singleton("PoingGodotAdMobConsentInformation") and Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform")
	if not available:
		initialized = false
		diagnostic = "Android AdMob/UMP singleton unavailable; banner remains disabled."
		return
	consent_state = "updating"
	var request_configuration := RequestConfiguration.new()
	request_configuration.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG
	request_configuration.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	request_configuration.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.FALSE
	MobileAds.set_request_configuration(request_configuration)
	var consent_request := ConsentRequestParameters.new()
	consent_request.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(consent_request, _on_consent_updated, _on_consent_error)

func _on_consent_updated() -> void:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.NOT_REQUIRED or status == ConsentInformation.ConsentStatus.OBTAINED:
		_load_banner_after_consent()
	elif UserMessagingPlatform.consent_information.get_is_consent_form_available():
		consent_state = "form_loading"
		UserMessagingPlatform.load_consent_form(_show_consent_form, _on_consent_error)
	else:
		_on_consent_error(null)

func _show_consent_form(form: ConsentForm) -> void:
	consent_state = "form_showing"
	form.show(func(error):
		if error != null: _on_consent_error(error)
		else: _on_consent_updated()
	)

func _on_consent_error(error) -> void:
	destroy()
	consent_state = "failed_closed"
	diagnostic = "UMP consent unavailable: %s" % str(error)
	initialized = false

func _load_banner_after_consent() -> void:
	_begin_sdk_initialization()

func begin_sdk_initialization_for_test() -> void:
	destroy()
	diagnostic = ""
	available = true
	consent_state = "consent_obtained_test"
	_begin_sdk_initialization()

func _begin_sdk_initialization() -> void:
	if not available or _sdk_initializing or _sdk_callback_consumed or banner_requested:
		return
	_sdk_initializing = true
	consent_state = "sdk_initializing"
	var generation := _sdk_generation
	var completed := func(status): _on_sdk_initialized(generation, status)
	if _initialization_request.is_valid():
		_initialization_request.call(completed)
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = completed
	MobileAds.initialize(listener)

func _on_sdk_initialized(generation: int, _status) -> void:
	if generation != _sdk_generation or not _sdk_initializing or _sdk_callback_consumed or banner_requested:
		return
	_sdk_callback_consumed = true
	_sdk_initializing = false
	_request_native_bottom_banner()

func _request_native_bottom_banner() -> void:
	if not available or banner_requested:
		return
	if _banner_request.is_valid():
		_banner_request.call()
	else:
		var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
		banner = AdView.new(TEST_BANNER_AD_UNIT, size, AdPosition.BOTTOM)
		banner.load_ad(AdRequest.new())
	banner_requested = true
	initialized = true
	consent_state = "banner_requested"
	diagnostic = "SDK initialized; native-bottom test banner requested."

func _invalidate_pending_initialization() -> void:
	_sdk_generation += 1
	_sdk_initializing = false
	_sdk_callback_consumed = false

func refresh_native_banner_diagnostics() -> void:
	if banner != null:
		native_height_px = maxf(0.0, float(banner.get_height_in_pixels()))

func destroy() -> void:
	_invalidate_pending_initialization()
	if banner != null:
		banner.destroy()
		banner = null
	banner_requested = false
	initialized = false
	native_height_px = 0.0

func game_content_reserve_height() -> float:
	return 0.0

func native_banner_height() -> float:
	return native_height_px

func describe_desktop_fallback() -> String:
	return "AdMob native singleton unavailable; desktop fallback keeps reserve at 0."
