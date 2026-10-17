extends Control
class_name OptionsPanelController

signal back_requested

const QUALITY_LOW: int = 0
const QUALITY_MEDIUM: int = 1
const QUALITY_HIGH: int = 2
const QUALITY_ULTRA: int = 3

const DISPLAY_WINDOWED: int = 0
const DISPLAY_FULLSCREEN: int = 1
const DISPLAY_EXCLUSIVE_FULLSCREEN: int = 2

const TEXT_LANGUAGE_TAB_INDEX: int = 3

const COMMON_WINDOW_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

@onready var controls_tab: ControlsSettingsTab = (
	$OptionsMargin/OptionsVBox/OptionsTabs/Controls/ControlsVBox
)

@onready var options_tabs: TabContainer = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
)

@onready var master_volume_slider: HSlider = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Audio
	/AudioVBox
	/MasterVolumeRow
	/MasterVolumeSlider
)

@onready var quality_option: OptionButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/QualityRow
	/QualityOption
)

@onready var display_mode_option: OptionButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/DisplayModeRow
	/DisplayModeOption
)

@onready var resolution_label: Label = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/ResolutionRow
	/ResolutionLabel
)

@onready var resolution_option: OptionButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/ResolutionRow
	/ResolutionOption
)

@onready var vsync_check_button: CheckButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/VSyncRow
	/VSyncCheckButton
)

@onready var ui_scale_option: OptionButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/UIScaleRow
	/UIScaleOption
)

@onready var fps_limit_option: OptionButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/FPSLimitRow
	/FPSLimitOption
)

@onready var brightness_slider: HSlider = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/BrightnessRow
	/BrightnessSlider
)

@onready var brightness_value_label: Label = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/BrightnessRow
	/BrightnessValueLabel
)

@onready var depth_of_field_check_button: CheckButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/DepthOfFieldRow
	/DepthOfFieldCheckButton
)

@onready var motion_blur_check_button: CheckButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Graphics
	/GraphicsVBox
	/MotionBlurRow
	/MotionBlurCheckButton
)

@onready var back_button: Button = (
	$OptionsMargin
	/OptionsVBox
	/OptionsBackButton
)

@onready var text_language_option: OptionButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Language
	/LanguageVBox
	/TextLanguageRow
	/TextLanguageOption
)

@onready var voice_language_option: OptionButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Language
	/LanguageVBox
	/VoiceLanguageRow
	/VoiceLanguageOption
)

@onready var captions_check_button: CheckButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Language
	/LanguageVBox
	/CaptionsRow
	/CaptionsCheckButton
)

@onready var caption_preview_label: Label = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Language
	/LanguageVBox
	/CaptionPreviewRow
	/CaptionPreviewPanel
	/CaptionPreviewLabel
)

@onready var caption_size_option: OptionButton = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Language
	/LanguageVBox
	/CaptionSizeRow
	/CaptionSizeOption
)

var syncing_controls: bool = false
var available_resolutions: Array[Vector2i] = []
var available_text_locales: PackedStringArray = []
var available_voice_locales: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_configure_sliders()
	_populate_graphics_options()
	_populate_language_options()
	_update_tab_titles()
	_connect_control_signals()
	_connect_settings_signals()
	get_viewport().size_changed.connect(_fit_window)
	_sync_controls_from_settings()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Listening for a new key owns every key, Escape included.
	if controls_tab.is_listening():
		return

	if event.is_action_pressed("ui_cancel"):
		_request_back()
		get_viewport().set_input_as_handled()


## The window's fixed size: never smaller than the .tscn minimum (the content fits it), and on a big
## screen it grows with it (80% of the height, half the width), so the Controls tab's long list of
## key bindings has room. It is the SAME size on every tab.
const WINDOW_MIN_SIZE: Vector2 = Vector2(860.0, 650.0)
const WINDOW_SCREEN_HEIGHT: float = 0.8
const WINDOW_SCREEN_WIDTH: float = 0.5


func _fit_window() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	custom_minimum_size = Vector2(
		maxf(WINDOW_MIN_SIZE.x, screen.x * WINDOW_SCREEN_WIDTH),
		maxf(WINDOW_MIN_SIZE.y, screen.y * WINDOW_SCREEN_HEIGHT)
	)


func open() -> void:
	_fit_window()
	_refresh_localized_options()
	controls_tab.refresh()
	_sync_controls_from_settings()
	show()
	_focus_current_tab()


func close() -> void:
	GameSettings.save_settings()
	hide()


func is_open() -> bool:
	return visible


func _configure_sliders() -> void:
	master_volume_slider.min_value = 0.0
	master_volume_slider.max_value = 100.0
	master_volume_slider.step = 1.0

	brightness_slider.min_value = (
		GameSettings.MIN_BRIGHTNESS_PERCENT
	)
	brightness_slider.max_value = (
		GameSettings.MAX_BRIGHTNESS_PERCENT
	)
	brightness_slider.step = 1.0


func _populate_graphics_options() -> void:
	quality_option.clear()
	quality_option.add_item(tr("QUALITY_LOW"), QUALITY_LOW)
	quality_option.add_item(tr("QUALITY_MEDIUM"), QUALITY_MEDIUM)
	quality_option.add_item(tr("QUALITY_HIGH"), QUALITY_HIGH)
	quality_option.add_item(tr("QUALITY_ULTRA"), QUALITY_ULTRA)

	display_mode_option.clear()
	display_mode_option.add_item(
		tr("DISPLAY_WINDOWED"),
		DISPLAY_WINDOWED
	)
	display_mode_option.add_item(
		tr("DISPLAY_BORDERLESS_FULLSCREEN"),
		DISPLAY_FULLSCREEN
	)
	display_mode_option.add_item(
		tr("DISPLAY_EXCLUSIVE_FULLSCREEN"),
		DISPLAY_EXCLUSIVE_FULLSCREEN
	)

	ui_scale_option.clear()
	ui_scale_option.add_item(tr("OPTIONS_UI_SIZE_SMALL"))
	ui_scale_option.add_item(tr("OPTIONS_UI_SIZE_MEDIUM"))
	ui_scale_option.add_item(tr("OPTIONS_UI_SIZE_LARGE"))

	fps_limit_option.clear()
	fps_limit_option.add_item("30", 30)
	fps_limit_option.add_item("60", 60)
	fps_limit_option.add_item("120", 120)
	fps_limit_option.add_item(tr("FPS_UNCAPPED"), 0)

	_populate_resolution_options()


func _populate_language_options() -> void:
	available_text_locales = (
		GameSettings.get_supported_text_locales()
	)
	available_voice_locales = (
		GameSettings.get_supported_voice_locales()
	)

	text_language_option.clear()
	for locale: String in available_text_locales:
		text_language_option.add_item(
			_get_language_display_name(locale)
		)

	voice_language_option.clear()
	for locale: String in available_voice_locales:
		voice_language_option.add_item(
			_get_language_display_name(locale)
		)

	caption_size_option.clear()
	caption_size_option.add_item(tr("OPTIONS_CAPTION_SIZE_SMALL"))
	caption_size_option.add_item(tr("OPTIONS_CAPTION_SIZE_MEDIUM"))
	caption_size_option.add_item(tr("OPTIONS_CAPTION_SIZE_LARGE"))
	caption_size_option.add_item(tr("OPTIONS_CAPTION_SIZE_EXTRA_LARGE"))


func _get_language_display_name(locale: String) -> String:
	match locale:
		GameSettings.LOCALE_ENGLISH:
			return "English"
		GameSettings.LOCALE_BRAZILIAN_PORTUGUESE:
			return "Português (Brasil)"
		_:
			var locale_name: String = (
				TranslationServer.get_locale_name(locale)
			)
			return locale if locale_name.is_empty() else locale_name


func _update_tab_titles() -> void:
	options_tabs.set_tab_title(0, tr("OPTIONS_TAB_AUDIO"))
	options_tabs.set_tab_title(1, tr("OPTIONS_TAB_GRAPHICS"))
	options_tabs.set_tab_title(2, tr("OPTIONS_TAB_CONTROLS"))
	options_tabs.set_tab_title(3, tr("OPTIONS_TAB_LANGUAGE"))


func _refresh_localized_options() -> void:
	var was_syncing: bool = syncing_controls
	syncing_controls = true
	_populate_graphics_options()
	_populate_language_options()
	_update_tab_titles()
	_sync_controls_from_settings()
	controls_tab.refresh()
	syncing_controls = was_syncing


func _populate_resolution_options() -> void:
	resolution_option.clear()
	available_resolutions.clear()

	var current_screen: int = (
		DisplayServer.window_get_current_screen()
	)
	var usable_size: Vector2i = (
		DisplayServer.screen_get_usable_rect(
			current_screen
		).size
	)

	for resolution: Vector2i in COMMON_WINDOW_RESOLUTIONS:
		if (
			resolution.x <= usable_size.x
			and resolution.y <= usable_size.y
		):
			_add_resolution_option(resolution)

	var saved_resolution: Vector2i = (
		GameSettings.get_window_resolution()
	)

	if not available_resolutions.has(saved_resolution):
		_add_resolution_option(saved_resolution)


func _add_resolution_option(resolution: Vector2i) -> void:
	available_resolutions.append(resolution)
	resolution_option.add_item(
		"%d x %d" % [resolution.x, resolution.y]
	)


func _connect_control_signals() -> void:
	if not master_volume_slider.value_changed.is_connected(
		_on_master_volume_slider_changed
	):
		master_volume_slider.value_changed.connect(
			_on_master_volume_slider_changed
		)

	if not master_volume_slider.drag_ended.is_connected(
		_on_master_volume_drag_ended
	):
		master_volume_slider.drag_ended.connect(
			_on_master_volume_drag_ended
		)

	if not quality_option.item_selected.is_connected(
		_on_quality_option_selected
	):
		quality_option.item_selected.connect(
			_on_quality_option_selected
		)

	if not display_mode_option.item_selected.is_connected(
		_on_display_mode_option_selected
	):
		display_mode_option.item_selected.connect(
			_on_display_mode_option_selected
		)

	if not resolution_option.item_selected.is_connected(
		_on_resolution_option_selected
	):
		resolution_option.item_selected.connect(
			_on_resolution_option_selected
		)

	if not vsync_check_button.toggled.is_connected(
		_on_vsync_toggled
	):
		vsync_check_button.toggled.connect(
			_on_vsync_toggled
		)

	if not depth_of_field_check_button.toggled.is_connected(
		_on_depth_of_field_toggled
	):
		depth_of_field_check_button.toggled.connect(
			_on_depth_of_field_toggled
		)

	if not motion_blur_check_button.toggled.is_connected(
		_on_motion_blur_toggled
	):
		motion_blur_check_button.toggled.connect(
			_on_motion_blur_toggled
		)

	if not ui_scale_option.item_selected.is_connected(_on_ui_scale_option_selected):
		ui_scale_option.item_selected.connect(_on_ui_scale_option_selected)

	if not fps_limit_option.item_selected.is_connected(
		_on_fps_limit_option_selected
	):
		fps_limit_option.item_selected.connect(
			_on_fps_limit_option_selected
		)

	if not brightness_slider.value_changed.is_connected(
		_on_brightness_slider_changed
	):
		brightness_slider.value_changed.connect(
			_on_brightness_slider_changed
		)

	if not brightness_slider.drag_ended.is_connected(
		_on_brightness_drag_ended
	):
		brightness_slider.drag_ended.connect(
			_on_brightness_drag_ended
		)

	if not text_language_option.item_selected.is_connected(
		_on_text_language_option_selected
	):
		text_language_option.item_selected.connect(
			_on_text_language_option_selected
		)

	if not voice_language_option.item_selected.is_connected(
		_on_voice_language_option_selected
	):
		voice_language_option.item_selected.connect(
			_on_voice_language_option_selected
		)

	if not captions_check_button.toggled.is_connected(
		_on_captions_toggled
	):
		captions_check_button.toggled.connect(
			_on_captions_toggled
		)

	if not caption_size_option.item_selected.is_connected(
		_on_caption_size_option_selected
	):
		caption_size_option.item_selected.connect(
			_on_caption_size_option_selected
		)

	if not options_tabs.tab_changed.is_connected(
		_on_tab_changed
	):
		options_tabs.tab_changed.connect(
			_on_tab_changed
		)

	if not back_button.pressed.is_connected(
		_on_back_button_pressed
	):
		back_button.pressed.connect(
			_on_back_button_pressed
		)


func _connect_settings_signals() -> void:
	if not GameSettings.master_volume_changed.is_connected(
		_on_saved_master_volume_changed
	):
		GameSettings.master_volume_changed.connect(
			_on_saved_master_volume_changed
		)

	if not GameSettings.text_language_changed.is_connected(
		_on_saved_text_language_changed
	):
		GameSettings.text_language_changed.connect(
			_on_saved_text_language_changed
		)

	if not GameSettings.voice_language_changed.is_connected(
		_on_saved_voice_language_changed
	):
		GameSettings.voice_language_changed.connect(
			_on_saved_voice_language_changed
		)


func _sync_controls_from_settings() -> void:
	syncing_controls = true

	master_volume_slider.value = (
		GameSettings.get_master_volume_percent()
	)

	_select_option_by_id(
		quality_option,
		GameSettings.get_quality_preset()
	)
	_select_option_by_id(
		display_mode_option,
		GameSettings.get_display_mode()
	)
	_select_resolution(
		GameSettings.get_window_resolution()
	)

	vsync_check_button.set_pressed_no_signal(
		GameSettings.get_vsync_enabled()
	)

	_select_option_by_id(
		fps_limit_option,
		GameSettings.get_fps_limit()
	)

	ui_scale_option.select(GameSettings.get_ui_size_index())

	depth_of_field_check_button.set_pressed_no_signal(
		GameSettings.get_depth_of_field_enabled()
	)
	motion_blur_check_button.set_pressed_no_signal(
		GameSettings.get_motion_blur_enabled()
	)

	brightness_slider.value = (
		GameSettings.get_brightness_percent()
	)
	_update_brightness_value_label(
		brightness_slider.value
	)
	_update_resolution_enabled()
	_select_locale(
		text_language_option,
		available_text_locales,
		GameSettings.get_text_locale()
	)
	_select_locale(
		voice_language_option,
		available_voice_locales,
		GameSettings.get_voice_locale()
	)
	captions_check_button.set_pressed_no_signal(
		GameSettings.get_captions_enabled()
	)
	caption_size_option.select(GameSettings.get_caption_size())
	caption_size_option.disabled = (
		not GameSettings.get_captions_enabled()
	)
	_update_caption_preview()

	syncing_controls = false


func _select_option_by_id(
	option_button: OptionButton,
	item_id: int
) -> void:
	var item_index: int = option_button.get_item_index(
		item_id
	)

	if item_index >= 0:
		option_button.select(item_index)


func _select_resolution(resolution: Vector2i) -> void:
	var item_index: int = available_resolutions.find(
		resolution
	)

	if item_index >= 0:
		resolution_option.select(item_index)


func _select_locale(
	option_button: OptionButton,
	locales: PackedStringArray,
	locale: String
) -> void:
	var item_index: int = locales.find(locale)

	if item_index >= 0:
		option_button.select(item_index)


func _update_resolution_enabled() -> void:
	var is_windowed: bool = (
		GameSettings.get_display_mode()
		== DISPLAY_WINDOWED
	)

	resolution_option.disabled = not is_windowed
	resolution_label.modulate.a = (
		1.0 if is_windowed else 0.5
	)


func _update_brightness_value_label(value: float) -> void:
	brightness_value_label.text = (
		"%d%%" % roundi(value)
	)


func _focus_current_tab() -> void:
	match options_tabs.current_tab:
		1:
			quality_option.grab_focus()
		2:
			controls_tab.focus_first()
		TEXT_LANGUAGE_TAB_INDEX:
			text_language_option.grab_focus()
		_:
			master_volume_slider.grab_focus()


func _on_master_volume_slider_changed(value: float) -> void:
	if syncing_controls:
		return

	GameSettings.set_master_volume_percent(
		value,
		false
	)


func _on_master_volume_drag_ended(
	value_changed: bool
) -> void:
	if value_changed:
		GameSettings.save_settings()


func _on_quality_option_selected(index: int) -> void:
	if syncing_controls:
		return

	GameSettings.set_quality_preset(
		quality_option.get_item_id(index)
	)


func _on_display_mode_option_selected(index: int) -> void:
	if syncing_controls:
		return

	GameSettings.set_display_mode(
		display_mode_option.get_item_id(index)
	)
	_update_resolution_enabled()


func _on_resolution_option_selected(index: int) -> void:
	if syncing_controls:
		return

	if (
		index < 0
		or index >= available_resolutions.size()
	):
		return

	GameSettings.set_window_resolution(
		available_resolutions[index]
	)


func _on_vsync_toggled(enabled: bool) -> void:
	if syncing_controls:
		return

	GameSettings.set_vsync_enabled(enabled)


func _on_depth_of_field_toggled(enabled: bool) -> void:
	if syncing_controls:
		return

	GameSettings.set_depth_of_field_enabled(enabled)


func _on_motion_blur_toggled(enabled: bool) -> void:
	if syncing_controls:
		return

	GameSettings.set_motion_blur_enabled(enabled)


func _on_ui_scale_option_selected(index: int) -> void:
	if syncing_controls:
		return

	GameSettings.set_ui_size_index(index)


func _on_fps_limit_option_selected(index: int) -> void:
	if syncing_controls:
		return

	GameSettings.set_fps_limit(
		fps_limit_option.get_item_id(index)
	)


func _on_brightness_slider_changed(value: float) -> void:
	_update_brightness_value_label(value)

	if syncing_controls:
		return

	GameSettings.set_brightness_percent(
		value,
		false
	)


func _on_brightness_drag_ended(
	value_changed: bool
) -> void:
	if value_changed:
		GameSettings.save_settings()


func _on_text_language_option_selected(index: int) -> void:
	if syncing_controls:
		return

	if index < 0 or index >= available_text_locales.size():
		return

	GameSettings.set_text_locale(
		available_text_locales[index]
	)


func _on_voice_language_option_selected(index: int) -> void:
	if syncing_controls:
		return

	if index < 0 or index >= available_voice_locales.size():
		return

	GameSettings.set_voice_locale(
		available_voice_locales[index]
	)


func _on_captions_toggled(enabled: bool) -> void:
	if syncing_controls:
		return

	GameSettings.set_captions_enabled(enabled)
	caption_size_option.disabled = not enabled
	_update_caption_preview()


func _on_caption_size_option_selected(index: int) -> void:
	if syncing_controls:
		return

	GameSettings.set_caption_size(index)
	_update_caption_preview()


## The sample line shows the chosen size (dimmed while captions are off), so it can be judged here.
func _update_caption_preview() -> void:
	caption_preview_label.add_theme_font_size_override(
		&"font_size",
		GameSettings.get_caption_font_size()
	)
	caption_preview_label.modulate.a = (
		1.0 if GameSettings.get_captions_enabled() else 0.35
	)


func _on_tab_changed(_tab: int) -> void:
	controls_tab.cancel_listening()
	if visible:
		_focus_current_tab()


func _on_saved_master_volume_changed(
	percent: float
) -> void:
	if syncing_controls:
		return

	if is_equal_approx(
		master_volume_slider.value,
		percent
	):
		return

	syncing_controls = true
	master_volume_slider.value = percent
	syncing_controls = false


func _on_saved_text_language_changed(_locale: String) -> void:
	_refresh_localized_options()


func _on_saved_voice_language_changed(locale: String) -> void:
	var was_syncing: bool = syncing_controls
	syncing_controls = true
	_select_locale(
		voice_language_option,
		available_voice_locales,
		locale
	)
	syncing_controls = was_syncing


func _on_back_button_pressed() -> void:
	_request_back()


func _request_back() -> void:
	GameSettings.save_settings()
	back_requested.emit()
