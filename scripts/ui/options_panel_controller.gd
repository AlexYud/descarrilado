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
	_sync_controls_from_settings()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_request_back()
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh_localized_options()
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
			back_button.grab_focus()
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


func _on_tab_changed(_tab: int) -> void:
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
