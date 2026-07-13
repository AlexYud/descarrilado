extends Node

@export_category("Scene References")
@export var player_path: String = "Player"
@export var player_camera_path: String = "Head/Camera3D"
@export var player_flashlight_path: String = "Player/Hand/SpotLight3D"
@export var train_root_path: String = "Train"
@export var ui_layer_path: String = "UI"

## Existing node:
## DreamIntro/TransitionBlackout/BlackoutRect
@export var blackout_rect_path: NodePath

@export_category("Scene Transition")
@export var initial_black_hold_duration: float = 0.20
@export var scene_fade_in_duration: float = 0.50

@export_category("Stopped Train")
@export var force_train_lights_off: bool = true

@export_category("Flashlight Tutorial")
@export var show_flashlight_tutorial_prompt: bool = true
@export var tutorial_prompt_delay: float = 0.35

@export var flashlight_action_name: String = "flashlight"
@export var flashlight_button_text: String = "F"

@export var flashlight_tutorial_text: String = (
	"Press %s to turn on the flashlight"
)

@export var tutorial_prompt_font_size: int = 26
@export var tutorial_prompt_bottom_margin: float = 90.0
@export var tutorial_prompt_fade_duration: float = 0.35

@export_category("Responsive UI")
@export var reference_resolution: Vector2 = Vector2(1920.0, 1080.0)
@export var min_ui_scale: float = 0.85
@export var max_ui_scale: float = 1.35


var dream_root: Node = null

var player: Node = null
var player_camera: Camera3D = null
var player_flashlight: SpotLight3D = null

var train_root: Node = null
var ui_layer: CanvasLayer = null
var blackout_rect: ColorRect = null

var train_light_flickers: Array[TrainLightFlicker] = []

var tutorial_prompt_label: Label = null
var tutorial_prompt_tween: Tween = null
var tutorial_prompt_visible: bool = false


func _ready() -> void:
	dream_root = get_parent()

	_find_scene_nodes()
	_collect_train_light_flickers()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if player_camera != null:
		player_camera.current = true

	if blackout_rect != null:
		blackout_rect.visible = true
		blackout_rect.color = Color.BLACK
		blackout_rect.modulate.a = 1.0
		blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var blackout_parent: Node = blackout_rect.get_parent()

		if blackout_parent is CanvasLayer:
			(blackout_parent as CanvasLayer).layer = 1000

	_set_player_enabled(false)
	_set_flashlight_input_enabled(false)

	_force_train_dark()

	call_deferred("_finish_scene_setup")


func _process(_delta: float) -> void:
	if not tutorial_prompt_visible:
		return

	if not InputMap.has_action(flashlight_action_name):
		return

	if Input.is_action_just_pressed(flashlight_action_name):
		_hide_flashlight_tutorial_prompt()


func _finish_scene_setup() -> void:
	_create_tutorial_prompt()
	_connect_viewport_resize()

	# Other wagon/light scripts may initialize after this controller.
	# Reapply the dark state after their startup has completed.
	await get_tree().process_frame
	_force_train_dark()

	await get_tree().physics_frame
	_force_train_dark()

	await _begin_playable_scene()


func _find_scene_nodes() -> void:
	player = _get_node_from_root(player_path)
	train_root = _get_node_from_root(train_root_path)
	ui_layer = _get_node_from_root(ui_layer_path) as CanvasLayer

	if not blackout_rect_path.is_empty():
		blackout_rect = (
			get_node_or_null(blackout_rect_path)
			as ColorRect
		)

	if player == null and dream_root != null:
		player = dream_root.find_child(
			"Player",
			true,
			false
		)

	if train_root == null and dream_root != null:
		train_root = dream_root.find_child(
			"Train",
			true,
			false
		)

	if ui_layer == null and dream_root != null:
		ui_layer = (
			dream_root.find_child(
				"UI",
				true,
				false
			)
			as CanvasLayer
		)

	if blackout_rect == null and dream_root != null:
		blackout_rect = (
			dream_root.find_child(
				"BlackoutRect",
				true,
				false
			)
			as ColorRect
		)

	if player != null:
		player_camera = (
			player.get_node_or_null(
				NodePath(player_camera_path)
			)
			as Camera3D
		)

	if player_camera == null and player != null:
		player_camera = (
			player.find_child(
				"Camera3D",
				true,
				false
			)
			as Camera3D
		)

	player_flashlight = (
		_get_node_from_root(player_flashlight_path)
		as SpotLight3D
	)

	if player_flashlight == null and player != null:
		player_flashlight = (
			player.find_child(
				"SpotLight3D",
				true,
				false
			)
			as SpotLight3D
		)

	if player == null:
		push_error(
			"DreamIntroController: Player was not found."
		)

	if player_camera == null:
		push_error(
			"DreamIntroController: Player Camera3D was not found."
		)

	if player_flashlight == null:
		push_warning(
			"DreamIntroController: Player flashlight was not found."
		)

	if train_root == null:
		push_warning(
			"DreamIntroController: Train root was not found."
		)

	if ui_layer == null:
		push_warning(
			"DreamIntroController: UI CanvasLayer was not found. "
			+ "The flashlight tutorial cannot be displayed."
		)

	if blackout_rect == null:
		push_error(
			"DreamIntroController: BlackoutRect was not found. "
			+ "Assign Blackout Rect Path."
		)


func _get_node_from_root(path_text: String) -> Node:
	if dream_root == null:
		return null

	if path_text.strip_edges().is_empty():
		return null

	return dream_root.get_node_or_null(
		NodePath(path_text)
	)


func _collect_train_light_flickers() -> void:
	train_light_flickers.clear()

	if train_root == null:
		return

	_find_train_light_flickers_recursive(train_root)


func _find_train_light_flickers_recursive(node: Node) -> void:
	var flicker: TrainLightFlicker = node as TrainLightFlicker

	if flicker != null:
		if not train_light_flickers.has(flicker):
			train_light_flickers.append(flicker)

	for child: Node in node.get_children():
		_find_train_light_flickers_recursive(child)


func _force_train_dark() -> void:
	if not force_train_lights_off:
		return

	for flicker: TrainLightFlicker in train_light_flickers:
		if flicker == null or not is_instance_valid(flicker):
			continue

		if flicker.has_method("blackout_with_final_flicker"):
			flicker.call(
				"blackout_with_final_flicker",
				0.0
			)

		# DreamIntro is the parked scene. Its wagon lights must
		# remain in their final blackout state.
		flicker.process_mode = Node.PROCESS_MODE_DISABLED

	if train_root != null:
		_disable_train_lights_recursive(train_root)


func _disable_train_lights_recursive(node: Node) -> void:
	var light: Light3D = node as Light3D

	if light != null:
		light.visible = false
		light.light_energy = 0.0

	for child: Node in node.get_children():
		_disable_train_lights_recursive(child)


func _create_tutorial_prompt() -> void:
	if ui_layer == null:
		return

	tutorial_prompt_label = Label.new()
	tutorial_prompt_label.name = "FlashlightTutorialPrompt"
	tutorial_prompt_label.visible = false
	tutorial_prompt_label.modulate.a = 0.0

	tutorial_prompt_label.text = (
		flashlight_tutorial_text
		% flashlight_button_text
	)

	tutorial_prompt_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	tutorial_prompt_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	tutorial_prompt_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	tutorial_prompt_label.anchor_left = 0.0
	tutorial_prompt_label.anchor_right = 1.0
	tutorial_prompt_label.anchor_top = 1.0
	tutorial_prompt_label.anchor_bottom = 1.0

	tutorial_prompt_label.offset_left = 0.0
	tutorial_prompt_label.offset_right = 0.0

	tutorial_prompt_label.offset_top = (
		-tutorial_prompt_bottom_margin
	)

	tutorial_prompt_label.offset_bottom = (
		-tutorial_prompt_bottom_margin + 40.0
	)

	tutorial_prompt_label.add_theme_font_size_override(
		"font_size",
		tutorial_prompt_font_size
	)

	tutorial_prompt_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.92, 0.88, 1.0)
	)

	tutorial_prompt_label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.9)
	)

	tutorial_prompt_label.add_theme_constant_override(
		"outline_size",
		6
	)

	ui_layer.add_child(tutorial_prompt_label)


func _connect_viewport_resize() -> void:
	var viewport: Viewport = get_viewport()

	if viewport == null:
		return

	if not viewport.size_changed.is_connected(
		_apply_responsive_ui
	):
		viewport.size_changed.connect(
			_apply_responsive_ui
		)

	_apply_responsive_ui()


func _begin_playable_scene() -> void:
	if initial_black_hold_duration > 0.0:
		await get_tree().create_timer(
			initial_black_hold_duration
		).timeout

	_force_train_dark()

	await _fade_from_black()

	_force_train_dark()

	_set_player_enabled(true)
	_set_flashlight_input_enabled(true)

	if (
		show_flashlight_tutorial_prompt
		and tutorial_prompt_label != null
	):
		if tutorial_prompt_delay > 0.0:
			await get_tree().create_timer(
				tutorial_prompt_delay
			).timeout

		_show_flashlight_tutorial_prompt()


func _fade_from_black() -> void:
	if blackout_rect == null:
		return

	var fade_duration: float = maxf(
		scene_fade_in_duration,
		0.0
	)

	if fade_duration <= 0.0:
		blackout_rect.modulate.a = 0.0
		blackout_rect.visible = false
		return

	var tween: Tween = create_tween()

	tween.tween_property(
		blackout_rect,
		"modulate:a",
		0.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished

	blackout_rect.visible = false


func _show_flashlight_tutorial_prompt() -> void:
	if tutorial_prompt_label == null:
		return

	if (
		tutorial_prompt_tween != null
		and tutorial_prompt_tween.is_valid()
	):
		tutorial_prompt_tween.kill()

	tutorial_prompt_visible = true

	tutorial_prompt_label.text = (
		flashlight_tutorial_text
		% flashlight_button_text
	)

	tutorial_prompt_label.visible = true
	tutorial_prompt_label.modulate.a = 0.0

	tutorial_prompt_tween = create_tween()

	tutorial_prompt_tween.tween_property(
		tutorial_prompt_label,
		"modulate:a",
		1.0,
		tutorial_prompt_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)


func _hide_flashlight_tutorial_prompt() -> void:
	if tutorial_prompt_label == null:
		return

	if (
		tutorial_prompt_tween != null
		and tutorial_prompt_tween.is_valid()
	):
		tutorial_prompt_tween.kill()

	tutorial_prompt_visible = false

	tutorial_prompt_tween = create_tween()

	tutorial_prompt_tween.tween_property(
		tutorial_prompt_label,
		"modulate:a",
		0.0,
		tutorial_prompt_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	tutorial_prompt_tween.tween_callback(
		func() -> void:
			if tutorial_prompt_label != null:
				tutorial_prompt_label.visible = false
	)


func _set_player_enabled(enabled: bool) -> void:
	if player == null:
		return

	player.set_process_input(enabled)
	player.set_process_unhandled_input(enabled)
	player.set_physics_process(enabled)


func _set_flashlight_input_enabled(enabled: bool) -> void:
	if player_flashlight == null:
		return

	if player_flashlight.has_method(
		"set_flashlight_input_enabled"
	):
		player_flashlight.call(
			"set_flashlight_input_enabled",
			enabled
		)


func _apply_responsive_ui() -> void:
	if tutorial_prompt_label == null:
		return

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

	var prompt_size: int = int(
		round(
			float(tutorial_prompt_font_size)
			* ui_scale
		)
	)

	tutorial_prompt_label.add_theme_font_size_override(
		"font_size",
		prompt_size
	)
