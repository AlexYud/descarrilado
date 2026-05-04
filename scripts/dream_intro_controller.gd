extends Node

@export var reference_resolution: Vector2 = Vector2(1920.0, 1080.0)

@export var title_base_font_size: int = 120
@export var button_base_font_size: int = 32

@export var min_ui_scale: float = 0.85
@export var max_ui_scale: float = 1.35

@export var menu_fade_duration: float = 2.0
@export var player_menu_settle_physics_frames: int = 6

@export var menu_camera_path: String = "MenuCamera"
@export var camera_animation_player_path: String = "CameraAnimationPlayer"
@export var intro_camera_animation_name: String = "Intro"

@export var intro_camera_animation_start_delay: float = 0.0

@export var train_root_path: String = "Train"
@export var outside_loop_path: String = "Train/OutsideLoop"

@export var train_lights_path: String = "Train/TrainWagonBlockout/Lights"

@export var player_flashlight_path: String = "Player/Hand/SpotLight3D"

@export var train_slowdown_duration: float = 4.0
@export var align_train_stop_to_loop_start: bool = true

# Lights go out during the slowdown, before the train fully stops.
@export var blackout_during_slowdown_delay: float = 1.2
@export var blackout_final_flicker_duration: float = 0.6

@export var train_stop_settle_delay: float = 0.5

@export var show_flashlight_tutorial_prompt: bool = true
@export var flashlight_action_name: String = "flashlight"
@export var flashlight_button_text: String = "F"
@export var flashlight_tutorial_text: String = "Press %s to turn on the flashlight"
@export var tutorial_prompt_font_size: int = 26
@export var tutorial_prompt_bottom_margin: float = 90.0
@export var tutorial_prompt_fade_duration: float = 0.35

var dream_root: Node = null
var player: Node = null

var menu_camera: Camera3D = null
var player_camera: Camera3D = null
var camera_animation_player: AnimationPlayer = null

var player_flashlight: SpotLight3D = null
var main_menu_ui: Control = null
var ui_layer: CanvasLayer = null

var outside_loop: OutsideTrainLoop = null
var train_light_flickers: Array[TrainLightFlicker] = []

var title_label: Label = null
var start_button: Button = null
var quit_button: Button = null
var tutorial_prompt_label: Label = null
var tutorial_prompt_tween: Tween = null

var start_transition_running: bool = false
var tutorial_prompt_visible: bool = false


func _ready() -> void:
	dream_root = get_parent()

	player = _get_node_from_dream_root("Player")
	main_menu_ui = _get_node_from_dream_root("UI/MainMenuUI") as Control
	ui_layer = _get_node_from_dream_root("UI") as CanvasLayer

	if player != null:
		player_camera = player.get_node_or_null("Head/Camera3D") as Camera3D

	_find_sequence_nodes()
	_find_menu_nodes()
	_connect_buttons()
	_create_tutorial_prompt()

	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_responsive_ui):
		get_viewport().size_changed.connect(_apply_responsive_ui)

	_set_flashlight_input_enabled(false)

	call_deferred("_enter_menu_state")


func _process(_delta: float) -> void:
	if not tutorial_prompt_visible:
		return

	if not InputMap.has_action(flashlight_action_name):
		return

	if Input.is_action_just_pressed(flashlight_action_name):
		_hide_flashlight_tutorial_prompt()


func _get_node_from_dream_root(path_text: String) -> Node:
	if dream_root == null:
		return null

	if path_text.strip_edges().is_empty():
		return null

	return dream_root.get_node_or_null(NodePath(path_text))


func _find_sequence_nodes() -> void:
	if dream_root == null:
		return

	menu_camera = _get_node_from_dream_root(menu_camera_path) as Camera3D

	if menu_camera == null:
		menu_camera = _get_node_from_dream_root("MenuCamera") as Camera3D

	if menu_camera == null:
		push_warning("DreamIntroController: MenuCamera not found.")

	camera_animation_player = _get_node_from_dream_root(camera_animation_player_path) as AnimationPlayer

	if camera_animation_player == null:
		camera_animation_player = _get_node_from_dream_root("CameraAnimationPlayer") as AnimationPlayer

	if camera_animation_player == null:
		push_warning("DreamIntroController: CameraAnimationPlayer not found.")

	outside_loop = _get_node_from_dream_root(outside_loop_path) as OutsideTrainLoop

	if outside_loop == null:
		outside_loop = dream_root.find_child("OutsideLoop", true, false) as OutsideTrainLoop

	if outside_loop == null:
		push_warning("DreamIntroController: OutsideLoop not found.")

	_collect_train_light_flickers()

	player_flashlight = _get_node_from_dream_root(player_flashlight_path) as SpotLight3D

	if player_flashlight == null and player != null:
		player_flashlight = player.find_child("SpotLight3D", true, false) as SpotLight3D

	if player_flashlight == null:
		push_warning("DreamIntroController: Player flashlight SpotLight3D not found.")


func _collect_train_light_flickers() -> void:
	train_light_flickers.clear()

	var fallback_lights: TrainLightFlicker = _get_node_from_dream_root(train_lights_path) as TrainLightFlicker

	if fallback_lights != null:
		_add_train_light_flicker(fallback_lights)

	var train_root: Node = _get_node_from_dream_root(train_root_path)

	if train_root == null:
		train_root = _get_node_from_dream_root("Train")

	if train_root == null:
		push_warning("DreamIntroController: Train root not found. Cannot collect wagon lights.")
		return

	_find_train_light_flickers_recursive(train_root)

	if train_light_flickers.is_empty():
		push_warning("DreamIntroController: No TrainLightFlicker nodes found. Wagon blackout will not affect train lights.")


func _find_train_light_flickers_recursive(node: Node) -> void:
	var flicker: TrainLightFlicker = node as TrainLightFlicker

	if flicker != null:
		_add_train_light_flicker(flicker)

	for child in node.get_children():
		_find_train_light_flickers_recursive(child)


func _add_train_light_flicker(flicker: TrainLightFlicker) -> void:
	if flicker == null:
		return

	if not train_light_flickers.has(flicker):
		train_light_flickers.append(flicker)


func _find_menu_nodes() -> void:
	if main_menu_ui == null:
		push_warning("DreamIntroController: MainMenuUI not found.")
		return

	title_label = main_menu_ui.find_child("TitleLabel", true, false) as Label
	start_button = main_menu_ui.find_child("StartButton", true, false) as Button
	quit_button = main_menu_ui.find_child("QuitButton", true, false) as Button

	if title_label == null:
		push_warning("DreamIntroController: TitleLabel not found.")

	if start_button == null:
		push_warning("DreamIntroController: StartButton not found.")

	if quit_button == null:
		push_warning("DreamIntroController: QuitButton not found.")


func _connect_buttons() -> void:
	if start_button != null and not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)

	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)


func _create_tutorial_prompt() -> void:
	if ui_layer == null:
		push_warning("DreamIntroController: UI CanvasLayer not found. Tutorial prompt will not be created.")
		return

	tutorial_prompt_label = Label.new()
	tutorial_prompt_label.name = "FlashlightTutorialPrompt"
	tutorial_prompt_label.visible = false
	tutorial_prompt_label.modulate.a = 0.0
	tutorial_prompt_label.text = flashlight_tutorial_text % flashlight_button_text
	tutorial_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tutorial_prompt_label.anchor_left = 0.0
	tutorial_prompt_label.anchor_right = 1.0
	tutorial_prompt_label.anchor_top = 1.0
	tutorial_prompt_label.anchor_bottom = 1.0

	tutorial_prompt_label.offset_left = 0.0
	tutorial_prompt_label.offset_right = 0.0
	tutorial_prompt_label.offset_top = -tutorial_prompt_bottom_margin
	tutorial_prompt_label.offset_bottom = -tutorial_prompt_bottom_margin + 40.0

	tutorial_prompt_label.add_theme_font_size_override("font_size", tutorial_prompt_font_size)
	tutorial_prompt_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88, 1.0))
	tutorial_prompt_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	tutorial_prompt_label.add_theme_constant_override("outline_size", 6)

	ui_layer.add_child(tutorial_prompt_label)


func _enter_menu_state() -> void:
	start_transition_running = false
	tutorial_prompt_visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_set_flashlight_input_enabled(false)
	_reset_intro_camera_animation_to_start()

	if tutorial_prompt_label != null:
		tutorial_prompt_label.visible = false
		tutorial_prompt_label.modulate.a = 0.0

	if main_menu_ui != null:
		main_menu_ui.visible = false
		main_menu_ui.modulate.a = 1.0

	if menu_camera != null:
		menu_camera.current = true

	if player_camera != null:
		player_camera.current = false

	if start_button != null:
		start_button.disabled = true

	if quit_button != null:
		quit_button.disabled = true

	await _settle_player_for_menu()

	_set_player_enabled(false)

	if main_menu_ui != null:
		main_menu_ui.visible = true
		main_menu_ui.modulate.a = 1.0

	if start_button != null:
		start_button.disabled = false

	if quit_button != null:
		quit_button.disabled = false

	_apply_responsive_ui()


func _settle_player_for_menu() -> void:
	if player == null:
		return

	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.set_physics_process(true)

	for i in range(player_menu_settle_physics_frames):
		await get_tree().physics_frame


func _on_start_button_pressed() -> void:
	if start_transition_running:
		return

	start_transition_running = true

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_flashlight_input_enabled(false)

	if start_button != null:
		start_button.disabled = true

	if quit_button != null:
		quit_button.disabled = true

	_start_game_transition()


func _start_game_transition() -> void:
	await _fade_out_menu()
	await _play_intro_camera_animation_after_delay()
	_switch_to_player_camera()
	await _run_train_stop_sequence()
	_finish_start_transition()


func _fade_out_menu() -> void:
	if main_menu_ui == null:
		return

	var tween: Tween = create_tween()

	tween.tween_property(
		main_menu_ui,
		"modulate:a",
		0.0,
		menu_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	main_menu_ui.visible = false


func _reset_intro_camera_animation_to_start() -> void:
	if camera_animation_player == null:
		return

	if not camera_animation_player.has_animation(intro_camera_animation_name):
		return

	camera_animation_player.play(intro_camera_animation_name)
	camera_animation_player.seek(0.0, true)
	camera_animation_player.pause()


func _play_intro_camera_animation_after_delay() -> void:
	if intro_camera_animation_start_delay > 0.0:
		await get_tree().create_timer(intro_camera_animation_start_delay).timeout

	await _play_intro_camera_animation()


func _play_intro_camera_animation() -> void:
	if camera_animation_player == null:
		return

	if not camera_animation_player.has_animation(intro_camera_animation_name):
		push_warning("DreamIntroController: Intro camera animation not found: %s" % intro_camera_animation_name)
		return

	camera_animation_player.play(intro_camera_animation_name)
	camera_animation_player.seek(0.0, true)

	await camera_animation_player.animation_finished


func _switch_to_player_camera() -> void:
	if player_camera != null:
		player_camera.current = true

	if menu_camera != null:
		menu_camera.current = false


func _run_train_stop_sequence() -> void:
	var slowdown_time: float = maxf(train_slowdown_duration, 0.0)
	var blackout_delay: float = clampf(blackout_during_slowdown_delay, 0.0, slowdown_time)
	var blackout_duration: float = maxf(blackout_final_flicker_duration, 0.0)

	# Lights start flickering only after the camera intro animation is finished.
	for flicker: TrainLightFlicker in train_light_flickers:
		if flicker != null and is_instance_valid(flicker):
			flicker.start_panic_flicker()

	var alignment_wait: float = 0.0

	if align_train_stop_to_loop_start and outside_loop != null:
		if outside_loop.has_method("get_alignment_wait_for_smooth_stop"):
			alignment_wait = float(outside_loop.call("get_alignment_wait_for_smooth_stop", slowdown_time))

	if alignment_wait > 0.001:
		await get_tree().create_timer(alignment_wait).timeout

	if outside_loop != null:
		outside_loop.call("smooth_stop", slowdown_time)

	if blackout_delay > 0.0:
		await get_tree().create_timer(blackout_delay).timeout

	if not train_light_flickers.is_empty():
		for flicker: TrainLightFlicker in train_light_flickers:
			if flicker != null and is_instance_valid(flicker):
				flicker.blackout_with_final_flicker(blackout_duration)

		if blackout_duration > 0.0:
			await get_tree().create_timer(blackout_duration).timeout
	elif blackout_duration > 0.0:
		await get_tree().create_timer(blackout_duration).timeout

	var remaining_slowdown_time: float = slowdown_time - blackout_delay - blackout_duration

	if remaining_slowdown_time > 0.0:
		await get_tree().create_timer(remaining_slowdown_time).timeout

	if train_stop_settle_delay > 0.0:
		await get_tree().create_timer(train_stop_settle_delay).timeout


func _finish_start_transition() -> void:
	if main_menu_ui != null:
		main_menu_ui.visible = false

	_switch_to_player_camera()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_set_player_enabled(true)
	_set_flashlight_input_enabled(true)

	if show_flashlight_tutorial_prompt:
		_show_flashlight_tutorial_prompt()

	start_transition_running = false


func _show_flashlight_tutorial_prompt() -> void:
	if tutorial_prompt_label == null:
		return

	if tutorial_prompt_tween != null and tutorial_prompt_tween.is_valid():
		tutorial_prompt_tween.kill()

	tutorial_prompt_visible = true

	tutorial_prompt_label.text = flashlight_tutorial_text % flashlight_button_text
	tutorial_prompt_label.visible = true
	tutorial_prompt_label.modulate.a = 0.0

	tutorial_prompt_tween = create_tween()
	tutorial_prompt_tween.tween_property(
		tutorial_prompt_label,
		"modulate:a",
		1.0,
		tutorial_prompt_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_flashlight_tutorial_prompt() -> void:
	if tutorial_prompt_label == null:
		return

	if tutorial_prompt_tween != null and tutorial_prompt_tween.is_valid():
		tutorial_prompt_tween.kill()

	tutorial_prompt_visible = false

	tutorial_prompt_tween = create_tween()
	tutorial_prompt_tween.tween_property(
		tutorial_prompt_label,
		"modulate:a",
		0.0,
		tutorial_prompt_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tutorial_prompt_tween.tween_callback(func() -> void:
		if tutorial_prompt_label != null:
			tutorial_prompt_label.visible = false
	)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _set_player_enabled(enabled: bool) -> void:
	if player == null:
		return

	player.set_process_input(enabled)
	player.set_physics_process(enabled)
	player.set_process_unhandled_input(enabled)


func _set_flashlight_input_enabled(enabled: bool) -> void:
	if player_flashlight == null:
		return

	if player_flashlight.has_method("set_flashlight_input_enabled"):
		player_flashlight.call("set_flashlight_input_enabled", enabled)


func _apply_responsive_ui() -> void:
	if get_viewport() == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var width_scale: float = viewport_size.x / reference_resolution.x
	var height_scale: float = viewport_size.y / reference_resolution.y
	var ui_scale: float = clampf(minf(width_scale, height_scale), min_ui_scale, max_ui_scale)

	var title_size: int = int(round(float(title_base_font_size) * ui_scale))
	var button_size: int = int(round(float(button_base_font_size) * ui_scale))
	var prompt_size: int = int(round(float(tutorial_prompt_font_size) * ui_scale))

	if title_label != null:
		title_label.add_theme_font_size_override("font_size", title_size)

	if start_button != null:
		start_button.add_theme_font_size_override("font_size", button_size)

	if quit_button != null:
		quit_button.add_theme_font_size_override("font_size", button_size)

	if tutorial_prompt_label != null:
		tutorial_prompt_label.add_theme_font_size_override("font_size", prompt_size)
