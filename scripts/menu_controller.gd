extends Node


# ============================================================
# FIXED MENU SCENE PATHS
# ============================================================

const MENU_CAMERA_PATH := NodePath(
	"MovingTrainSystem/TrainPath/WagonFollow4/"
	+ "MenuCameraRig/MenuCamera"
)

const CAMERA_ANIMATION_PLAYER_PATH := NodePath(
	"MovingTrainSystem/TrainPath/WagonFollow4/"
	+ "MenuCameraRig/CameraAnimationPlayer"
)

const MOVING_TRAIN_PATH := NodePath(
	"MovingTrainSystem/TrainPath"
)

const BLACKOUT_RECT_PATH := NodePath(
	"TransitionBlackout/BlackoutRect"
)

const MAIN_MENU_UI_PATH := NodePath(
	"UI/MainMenuUI"
)

const LEFT_PANEL_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel"
)

const TITLE_LABEL_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/TitleLabel"
)

const START_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/StartButton"
)

const OPTIONS_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/OptionsButton"
)

const QUIT_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/QuitButton"
)

const OPTIONS_PANEL_PATH := NodePath(
	"UI/MainMenuUI/OptionsPanel"
)

const OPTIONS_BACK_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/OptionsPanel/OptionsMargin/"
	+ "OptionsVBox/OptionsBackButton"
)

const MASTER_VOLUME_SLIDER_PATH := NodePath(
	"UI/MainMenuUI/OptionsPanel/OptionsMargin/"
	+ "OptionsVBox/OptionsTabs/Audio/AudioVBox/"
	+ "MasterVolumeRow/MasterVolumeSlider"
)

const PERSISTENT_AUDIO_NAME := "PersistentAudio"


# ============================================================
# AUDIO
# ============================================================

@export_category("Audio")

@export var play_menu_idle_audio: bool = true
@export var menu_idle_fade_out_duration: float = 2.0

@export var play_intro_narration: bool = true
@export var intro_narration_start_delay: float = 0.0
@export var intro_narration_volume_db: float = -10.0


# ============================================================
# RESPONSIVE UI
# ============================================================

@export_category("Responsive UI")

@export var reference_resolution: Vector2 = Vector2(
	1920.0,
	1080.0
)

@export var title_base_font_size: int = 120
@export var button_base_font_size: int = 32

@export var min_ui_scale: float = 0.85
@export var max_ui_scale: float = 1.35


# ============================================================
# CAMERA CUTSCENES
# ============================================================

@export_category("Camera Cutscenes")

@export var intro_animation_name: StringName = &"Intro"
@export var brake_animation_name: StringName = &"BreakDip"

@export var play_brake_animation: bool = true

@export var menu_fade_duration: float = 2.0
@export var intro_animation_start_delay: float = 0.0


# ============================================================
# TRAIN MALFUNCTION
# ============================================================

@export_category("Train Stop Sequence")

@export var train_slowdown_duration: float = 0.8

## Panic flickering begins at the same moment as BrakeDip.
## This controls how long it flickers before the final blackout.
@export var blackout_during_slowdown_delay: float = 0.20

## Duration of the final light flicker before all lights stay off.
@export var blackout_final_flicker_duration: float = 0.35

## Full-screen fade used after the camera is looking down.
@export var screen_blackout_fade_duration: float = 0.06

## Fully black pause before DreamIntro loads.
@export var screen_blackout_hold_duration: float = 0.05


# ============================================================
# PLAYABLE SCENE
# ============================================================

@export_category("Playable Scene")

@export var change_scene_after_animation: bool = true

@export_file("*.tscn")
var playable_scene_path: String = (
	"res://scenes/demo/DreamIntro.tscn"
)


# ============================================================
# NODE REFERENCES
# ============================================================

var menu_root: Node = null

var menu_camera: Camera3D = null
var camera_animation_player: AnimationPlayer = null
var moving_train: Node = null

var blackout_rect: ColorRect = null

var main_menu_ui: Control = null
var left_panel: CanvasItem = null

var title_label: Label = null
var start_button: Button = null
var options_button: Button = null
var quit_button: Button = null

var options_panel: Control = null
var options_back_button: Button = null
var master_volume_slider: HSlider = null

var persistent_audio: Node = null

var train_light_flickers: Array[TrainLightFlicker] = []

var train_slowdown_tween: Tween = null

var transition_running: bool = false
var options_panel_open: bool = false
var updating_master_volume_slider: bool = false


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	menu_root = get_parent()

	_find_scene_nodes()
	_collect_train_light_flickers()
	_connect_buttons()
	_connect_viewport()
	_prepare_menu_state()


func _find_scene_nodes() -> void:
	if menu_root == null:
		push_error(
			"MenuController: Menu scene root was not found."
		)
		return

	menu_camera = (
		menu_root.get_node_or_null(MENU_CAMERA_PATH)
		as Camera3D
	)

	camera_animation_player = (
		menu_root.get_node_or_null(
			CAMERA_ANIMATION_PLAYER_PATH
		)
		as AnimationPlayer
	)

	moving_train = menu_root.get_node_or_null(
		MOVING_TRAIN_PATH
	)

	blackout_rect = (
		menu_root.get_node_or_null(BLACKOUT_RECT_PATH)
		as ColorRect
	)

	main_menu_ui = (
		menu_root.get_node_or_null(MAIN_MENU_UI_PATH)
		as Control
	)

	left_panel = (
		menu_root.get_node_or_null(LEFT_PANEL_PATH)
		as CanvasItem
	)

	title_label = (
		menu_root.get_node_or_null(TITLE_LABEL_PATH)
		as Label
	)

	start_button = (
		menu_root.get_node_or_null(START_BUTTON_PATH)
		as Button
	)

	options_button = (
		menu_root.get_node_or_null(OPTIONS_BUTTON_PATH)
		as Button
	)

	quit_button = (
		menu_root.get_node_or_null(QUIT_BUTTON_PATH)
		as Button
	)

	options_panel = (
		menu_root.get_node_or_null(OPTIONS_PANEL_PATH)
		as Control
	)

	options_back_button = (
		menu_root.get_node_or_null(
			OPTIONS_BACK_BUTTON_PATH
		)
		as Button
	)

	master_volume_slider = (
		menu_root.get_node_or_null(
			MASTER_VOLUME_SLIDER_PATH
		)
		as HSlider
	)

	_find_persistent_audio()
	_find_ui_fallbacks()
	_validate_scene_nodes()


func _find_persistent_audio() -> void:
	var tree_root: Window = get_tree().root

	if tree_root == null:
		return

	persistent_audio = tree_root.get_node_or_null(
		PERSISTENT_AUDIO_NAME
	)

	if persistent_audio != null:
		return

	for child: Node in tree_root.get_children():
		if (
			child.has_method("play_menu_idle")
			and child.has_method(
				"play_intro_narration_after_delay"
			)
		):
			persistent_audio = child
			return


func _find_ui_fallbacks() -> void:
	if main_menu_ui == null:
		return

	if title_label == null:
		title_label = (
			main_menu_ui.find_child(
				"TitleLabel",
				true,
				false
			)
			as Label
		)

	if start_button == null:
		start_button = (
			main_menu_ui.find_child(
				"StartButton",
				true,
				false
			)
			as Button
		)

	if options_button == null:
		options_button = (
			main_menu_ui.find_child(
				"OptionsButton",
				true,
				false
			)
			as Button
		)

	if quit_button == null:
		quit_button = (
			main_menu_ui.find_child(
				"QuitButton",
				true,
				false
			)
			as Button
		)

	if options_panel == null:
		options_panel = (
			main_menu_ui.find_child(
				"OptionsPanel",
				true,
				false
			)
			as Control
		)

	if options_back_button == null:
		options_back_button = (
			main_menu_ui.find_child(
				"OptionsBackButton",
				true,
				false
			)
			as Button
		)

	if master_volume_slider == null:
		master_volume_slider = (
			main_menu_ui.find_child(
				"MasterVolumeSlider",
				true,
				false
			)
			as HSlider
		)

	if master_volume_slider == null:
		master_volume_slider = (
			main_menu_ui.find_child(
				"MasterVolumeSlide",
				true,
				false
			)
			as HSlider
		)


func _validate_scene_nodes() -> void:
	if menu_camera == null:
		push_error(
			"MenuController: MenuCamera was not found at: "
			+ str(MENU_CAMERA_PATH)
		)

	if camera_animation_player == null:
		push_error(
			"MenuController: CameraAnimationPlayer was not "
			+ "found at: "
			+ str(CAMERA_ANIMATION_PLAYER_PATH)
		)

	if moving_train == null:
		push_error(
			"MenuController: TrainPath was not found at: "
			+ str(MOVING_TRAIN_PATH)
		)

	if blackout_rect == null:
		push_error(
			"MenuController: BlackoutRect was not found at: "
			+ str(BLACKOUT_RECT_PATH)
		)
	else:
		blackout_rect.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		var blackout_parent: Node = (
			blackout_rect.get_parent()
		)

		if blackout_parent is CanvasLayer:
			(blackout_parent as CanvasLayer).layer = 1000

	if main_menu_ui == null:
		push_error(
			"MenuController: MainMenuUI was not found."
		)

	if start_button == null:
		push_error(
			"MenuController: StartButton was not found."
		)

	if options_button == null:
		push_warning(
			"MenuController: OptionsButton was not found."
		)

	if quit_button == null:
		push_warning(
			"MenuController: QuitButton was not found."
		)

	if options_panel == null:
		push_warning(
			"MenuController: OptionsPanel was not found."
		)

	if options_back_button == null:
		push_warning(
			"MenuController: OptionsBackButton was not found."
		)

	if master_volume_slider == null:
		push_warning(
			"MenuController: MasterVolumeSlider was not found."
		)
	else:
		master_volume_slider.min_value = 0.0
		master_volume_slider.max_value = 100.0
		master_volume_slider.step = 1.0

	if persistent_audio == null:
		push_error(
			"MenuController: PersistentAudio Autoload was not "
			+ "found."
		)

	if (
		camera_animation_player != null
		and play_brake_animation
		and not camera_animation_player.has_animation(
			brake_animation_name
		)
	):
		push_warning(
			"MenuController: Brake animation '%s' was not found."
			% brake_animation_name
		)


# ============================================================
# TRAIN LIGHTS
# ============================================================

func _collect_train_light_flickers() -> void:
	train_light_flickers.clear()

	if moving_train == null:
		return

	_find_train_light_flickers_recursive(moving_train)

	if train_light_flickers.is_empty():
		push_warning(
			"MenuController: No TrainLightFlicker nodes "
			+ "were found under TrainPath."
		)


func _find_train_light_flickers_recursive(
	node: Node
) -> void:
	var light_flicker: TrainLightFlicker = (
		node as TrainLightFlicker
	)

	if light_flicker != null:
		if not train_light_flickers.has(light_flicker):
			train_light_flickers.append(light_flicker)

	for child: Node in node.get_children():
		_find_train_light_flickers_recursive(child)


# ============================================================
# MENU BUTTONS
# ============================================================

func _connect_buttons() -> void:
	if (
		start_button != null
		and not start_button.pressed.is_connected(
			_on_start_button_pressed
		)
	):
		start_button.pressed.connect(
			_on_start_button_pressed
		)

	if (
		options_button != null
		and not options_button.pressed.is_connected(
			_on_options_button_pressed
		)
	):
		options_button.pressed.connect(
			_on_options_button_pressed
		)

	if (
		options_back_button != null
		and not options_back_button.pressed.is_connected(
			_on_options_back_button_pressed
		)
	):
		options_back_button.pressed.connect(
			_on_options_back_button_pressed
		)

	if (
		master_volume_slider != null
		and not master_volume_slider.value_changed.is_connected(
			_on_master_volume_slider_value_changed
		)
	):
		master_volume_slider.value_changed.connect(
			_on_master_volume_slider_value_changed
		)

	if (
		quit_button != null
		and not quit_button.pressed.is_connected(
			_on_quit_button_pressed
		)
	):
		quit_button.pressed.connect(
			_on_quit_button_pressed
		)


func _on_start_button_pressed() -> void:
	if transition_running:
		return

	transition_running = true

	_set_options_panel_open(false)
	_set_main_menu_buttons_enabled(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_fade_out_menu_idle_audio()
	_start_intro_narration()

	await _fade_out_menu()

	if intro_animation_start_delay > 0.0:
		await get_tree().create_timer(
			intro_animation_start_delay
		).timeout

	await _play_intro_animation()
	await _run_train_stop_sequence()

	if change_scene_after_animation:
		_open_playable_scene()
	else:
		transition_running = false


func _on_options_button_pressed() -> void:
	if transition_running:
		return

	_set_options_panel_open(true)


func _on_options_back_button_pressed() -> void:
	if transition_running:
		return

	_set_options_panel_open(false)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


# ============================================================
# INITIAL MENU STATE
# ============================================================

func _prepare_menu_state() -> void:
	transition_running = false
	options_panel_open = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if menu_camera != null:
		menu_camera.current = true

	if main_menu_ui != null:
		main_menu_ui.visible = true
		main_menu_ui.modulate = Color.WHITE

	if left_panel != null:
		left_panel.visible = true
		left_panel.modulate = Color.WHITE

	if blackout_rect != null:
		blackout_rect.visible = true
		blackout_rect.color = Color.BLACK
		blackout_rect.modulate.a = 0.0

	_set_options_panel_open(false)
	_set_main_menu_buttons_enabled(true)

	_prepare_camera_animation()
	_sync_master_volume_slider_to_audio()
	_apply_responsive_ui()
	_start_menu_idle_audio()

	if start_button != null:
		start_button.call_deferred("grab_focus")


func _prepare_camera_animation() -> void:
	if camera_animation_player == null:
		return

	if not camera_animation_player.has_animation(
		intro_animation_name
	):
		push_error(
			"MenuController: Animation '%s' was not found."
			% intro_animation_name
		)
		return

	camera_animation_player.play(
		intro_animation_name
	)

	camera_animation_player.seek(0.0, true)
	camera_animation_player.pause()


# ============================================================
# OPTIONS PANEL
# ============================================================

func _set_options_panel_open(opened: bool) -> void:
	options_panel_open = opened

	if options_panel != null:
		options_panel.visible = opened

	_set_main_menu_buttons_visible(not opened)

	_set_main_menu_buttons_enabled(
		not opened and not transition_running
	)

	if opened:
		if options_back_button != null:
			options_back_button.grab_focus()
	else:
		if start_button != null and not transition_running:
			start_button.grab_focus()


func _set_main_menu_buttons_visible(
	buttons_visible: bool
) -> void:
	if start_button != null:
		start_button.visible = buttons_visible

	if options_button != null:
		options_button.visible = buttons_visible

	if quit_button != null:
		quit_button.visible = buttons_visible


func _set_main_menu_buttons_enabled(enabled: bool) -> void:
	if start_button != null:
		start_button.disabled = not enabled

	if options_button != null:
		options_button.disabled = not enabled

	if quit_button != null:
		quit_button.disabled = not enabled


# ============================================================
# MASTER VOLUME
# ============================================================

func _on_master_volume_slider_value_changed(
	value: float
) -> void:
	if updating_master_volume_slider:
		return

	if persistent_audio == null:
		return

	if persistent_audio.has_method(
		"set_master_volume_percent"
	):
		persistent_audio.call(
			"set_master_volume_percent",
			value,
			true
		)


func _sync_master_volume_slider_to_audio() -> void:
	if master_volume_slider == null:
		return

	updating_master_volume_slider = true

	if (
		persistent_audio != null
		and persistent_audio.has_method(
			"get_master_volume_percent"
		)
	):
		var saved_volume: Variant = persistent_audio.call(
			"get_master_volume_percent"
		)

		master_volume_slider.value = float(saved_volume)
	else:
		master_volume_slider.value = 100.0

	updating_master_volume_slider = false


# ============================================================
# AUDIO
# ============================================================

func _start_menu_idle_audio() -> void:
	if not play_menu_idle_audio:
		return

	if persistent_audio == null:
		return

	if persistent_audio.has_method("play_menu_idle"):
		persistent_audio.call("play_menu_idle")


func _fade_out_menu_idle_audio() -> void:
	if persistent_audio == null:
		return

	if persistent_audio.has_method("fade_out_menu_idle"):
		persistent_audio.call(
			"fade_out_menu_idle",
			menu_idle_fade_out_duration
		)


func _start_intro_narration() -> void:
	if not play_intro_narration:
		return

	if persistent_audio == null:
		return

	if _node_has_property(
		persistent_audio,
		&"intro_narration_volume_db"
	):
		persistent_audio.set(
			"intro_narration_volume_db",
			intro_narration_volume_db
		)

	if persistent_audio.has_method(
		"play_intro_narration_after_delay"
	):
		persistent_audio.call(
			"play_intro_narration_after_delay",
			intro_narration_start_delay
		)


# ============================================================
# MENU FADE AND INTRO CAMERA ANIMATION
# ============================================================

func _fade_out_menu() -> void:
	if main_menu_ui == null:
		return

	var tween: Tween = create_tween()

	tween.tween_property(
		main_menu_ui,
		"modulate:a",
		0.0,
		maxf(menu_fade_duration, 0.0)
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished

	main_menu_ui.visible = false


func _play_intro_animation() -> void:
	if camera_animation_player == null:
		push_error(
			"MenuController: CameraAnimationPlayer is missing."
		)
		return

	if not camera_animation_player.has_animation(
		intro_animation_name
	):
		push_error(
			"MenuController: Animation '%s' was not found."
			% intro_animation_name
		)
		return

	var intro_animation: Animation = (
		camera_animation_player.get_animation(
			intro_animation_name
		)
	)

	if (
		intro_animation != null
		and intro_animation.loop_mode
		!= Animation.LOOP_NONE
	):
		push_warning(
			"MenuController: Intro animation is looping. "
			+ "Disable looping."
		)
		return

	camera_animation_player.play(
		intro_animation_name
	)

	camera_animation_player.seek(0.0, true)

	await camera_animation_player.animation_finished


# ============================================================
# BRAKE ANIMATION
# ============================================================

func _start_brake_animation() -> void:
	if not play_brake_animation:
		return

	if camera_animation_player == null:
		return

	if not camera_animation_player.has_animation(
		brake_animation_name
	):
		push_warning(
			"MenuController: Brake animation '%s' was not found."
			% brake_animation_name
		)
		return

	camera_animation_player.play(
		brake_animation_name
	)

	camera_animation_player.seek(0.0, true)


func _wait_for_brake_animation() -> void:
	if not play_brake_animation:
		return

	if camera_animation_player == null:
		return

	if not camera_animation_player.is_playing():
		return

	if (
		camera_animation_player.current_animation
		!= String(brake_animation_name)
	):
		return

	await camera_animation_player.animation_finished


# ============================================================
# TRAIN STOP AND LIGHT BLACKOUT
# ============================================================

func _run_train_stop_sequence() -> void:
	var slowdown_time: float = maxf(
		train_slowdown_duration,
		0.0
	)

	var blackout_delay: float = clampf(
		blackout_during_slowdown_delay,
		0.0,
		slowdown_time
	)

	var final_flicker_time: float = maxf(
		blackout_final_flicker_duration,
		0.0
	)

	# All three start during the same frame:
	# camera impact, train braking, and light malfunction.
	_start_brake_animation()
	_begin_train_slowdown(slowdown_time)

	for light_flicker: TrainLightFlicker in (
		train_light_flickers
	):
		if (
			light_flicker != null
			and is_instance_valid(light_flicker)
		):
			light_flicker.start_panic_flicker()

	if blackout_delay > 0.0:
		await get_tree().create_timer(
			blackout_delay
		).timeout

	for light_flicker: TrainLightFlicker in (
		train_light_flickers
	):
		if (
			light_flicker != null
			and is_instance_valid(light_flicker)
		):
			light_flicker.blackout_with_final_flicker(
				final_flicker_time
			)

	if final_flicker_time > 0.0:
		await get_tree().create_timer(
			final_flicker_time
		).timeout

	var remaining_slowdown_time: float = maxf(
		slowdown_time
		- blackout_delay
		- final_flicker_time,
		0.0
	)

	if remaining_slowdown_time > 0.0:
		await get_tree().create_timer(
			remaining_slowdown_time
		).timeout

	_finish_train_stop()

	# Protect against very short slowdown settings.
	# The scene will not fade until BrakeDip has reached its floor pose.
	await _wait_for_brake_animation()

	await _fade_screen_to_black()

	if screen_blackout_hold_duration > 0.0:
		await get_tree().create_timer(
			screen_blackout_hold_duration
		).timeout


func _begin_train_slowdown(duration: float) -> void:
	if moving_train == null:
		return

	if moving_train.has_method("smooth_stop"):
		moving_train.call(
			"smooth_stop",
			duration
		)
		return

	if not _node_has_property(
		moving_train,
		&"movement_speed"
	):
		push_warning(
			"MenuController: TrainPath has no "
			+ "movement_speed property or smooth_stop() method."
		)
		return

	if train_slowdown_tween != null:
		train_slowdown_tween.kill()

	var current_speed: float = float(
		moving_train.get("movement_speed")
	)

	if duration <= 0.0:
		moving_train.set("movement_speed", 0.0)
		return

	train_slowdown_tween = create_tween()

	train_slowdown_tween.tween_method(
		_set_moving_train_speed,
		current_speed,
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


func _set_moving_train_speed(speed: float) -> void:
	if moving_train == null:
		return

	if _node_has_property(
		moving_train,
		&"movement_speed"
	):
		moving_train.set(
			"movement_speed",
			speed
		)


func _finish_train_stop() -> void:
	if moving_train == null:
		return

	if _node_has_property(
		moving_train,
		&"movement_speed"
	):
		moving_train.set(
			"movement_speed",
			0.0
		)

	if _node_has_property(
		moving_train,
		&"move_train"
	):
		moving_train.set(
			"move_train",
			false
		)


func _node_has_property(
	object: Object,
	property_name: StringName
) -> bool:
	if object == null:
		return false

	for property_data: Dictionary in object.get_property_list():
		var found_name := StringName(
			property_data.get("name", "")
		)

		if found_name == property_name:
			return true

	return false


func _fade_screen_to_black() -> void:
	if blackout_rect == null:
		return

	blackout_rect.visible = true
	blackout_rect.color = Color.BLACK

	var fade_duration: float = maxf(
		screen_blackout_fade_duration,
		0.0
	)

	if fade_duration <= 0.0:
		blackout_rect.modulate.a = 1.0
		return

	var tween: Tween = create_tween()

	tween.tween_property(
		blackout_rect,
		"modulate:a",
		1.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished


# ============================================================
# RESPONSIVE UI
# ============================================================

func _connect_viewport() -> void:
	var viewport: Viewport = get_viewport()

	if viewport == null:
		return

	if not viewport.size_changed.is_connected(
		_apply_responsive_ui
	):
		viewport.size_changed.connect(
			_apply_responsive_ui
		)


func _apply_responsive_ui() -> void:
	var viewport: Viewport = get_viewport()

	if viewport == null:
		return

	var viewport_size: Vector2 = (
		viewport.get_visible_rect().size
	)

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var width_scale: float = (
		viewport_size.x / reference_resolution.x
	)

	var height_scale: float = (
		viewport_size.y / reference_resolution.y
	)

	var ui_scale: float = clampf(
		minf(width_scale, height_scale),
		min_ui_scale,
		max_ui_scale
	)

	var title_size: int = int(
		round(
			float(title_base_font_size)
			* ui_scale
		)
	)

	var button_size: int = int(
		round(
			float(button_base_font_size)
			* ui_scale
		)
	)

	if title_label != null:
		title_label.add_theme_font_size_override(
			"font_size",
			title_size
		)

	if start_button != null:
		start_button.add_theme_font_size_override(
			"font_size",
			button_size
		)

	if options_button != null:
		options_button.add_theme_font_size_override(
			"font_size",
			button_size
		)

	if quit_button != null:
		quit_button.add_theme_font_size_override(
			"font_size",
			button_size
		)


# ============================================================
# SCENE CHANGE
# ============================================================

func _open_playable_scene() -> void:
	if playable_scene_path.strip_edges().is_empty():
		push_error(
			"MenuController: Playable scene path is empty."
		)
		transition_running = false
		return

	var result: Error = get_tree().change_scene_to_file(
		playable_scene_path
	)

	if result != OK:
		push_error(
			"MenuController: Failed to open '%s'. Error: %s"
			% [
				playable_scene_path,
				error_string(result)
			]
		)

		transition_running = false
