extends Node


# ============================================================
# FIXED DREAM INTRO NODE PATHS
# ============================================================

const PLAYER_PATH := NodePath("Player")

const PLAYER_CAMERA_PATH := NodePath(
	"Player/Head/Camera3D"
)

const HEAD_RAISE_ANIMATION_PLAYER_PATH := NodePath(
	"Player/Head/HeadRaiseAnimationPlayer"
)

const PLAYER_FLASHLIGHT_PATH := NodePath(
	"Player/Hand/SpotLight3D"
)

const TRAIN_ROOT_PATH := NodePath("Train")
const UI_LAYER_PATH := NodePath("UI")

const BLACKOUT_RECT_PATH := NodePath(
	"TransitionBlackout/BlackoutRect"
)


# ============================================================
# SCENE TRANSITION
# ============================================================

@export_category("Scene Transition")

## Briefly remains black while the new scene finishes loading.
@export var initial_black_hold_duration: float = 0.04

## Fast reveal designed to resemble one of the light flickers.
@export var scene_fade_in_duration: float = 0.10


# ============================================================
# HEAD RAISE
# ============================================================

@export_category("Head Raise")

@export var play_head_raise_animation: bool = true

## Must exactly match the animation name inside:
## Player/Head/HeadRaiseAnimationPlayer
@export var head_raise_animation_name: StringName = &"HeadRaise"


# ============================================================
# PLAYER GROUNDING
# ============================================================

@export_category("Player Grounding")

## Grounds the CharacterBody3D while the screen is still black.
## This prevents gravity from causing a visible drop when gameplay begins.
@export var snap_player_to_floor_before_intro: bool = true

## Maximum downward distance checked for the train floor.
@export_range(0.1, 5.0, 0.1) var player_floor_snap_distance: float = 2.0


# ============================================================
# WAGON LIGHT CONTINUITY
# ============================================================

@export_category("Wagon Light Continuity")

## Restarts the wagon-light malfunction in the new scene so
## the scene transition appears to be one continuous event.
@export var continue_wagon_flicker_during_head_raise: bool = true

## Time spent violently flickering after DreamIntro appears.
@export var continuity_panic_flicker_duration: float = 0.70

## Final unstable flicker before the wagon becomes dark.
@export var continuity_final_flicker_duration: float = 0.35

## Keeps every wagon light permanently off after the sequence.
@export var force_train_lights_off_after_flicker: bool = true


# ============================================================
# FLASHLIGHT TUTORIAL
# ============================================================

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


# ============================================================
# RESPONSIVE UI
# ============================================================

@export_category("Responsive UI")

@export var reference_resolution: Vector2 = Vector2(
	1920.0,
	1080.0
)

@export var min_ui_scale: float = 0.85
@export var max_ui_scale: float = 1.35


# ============================================================
# NODE REFERENCES
# ============================================================

var dream_root: Node = null

var player: Node = null
var player_camera: Camera3D = null
var head_raise_animation_player: AnimationPlayer = null
var player_flashlight: SpotLight3D = null

var train_root: Node = null
var ui_layer: CanvasLayer = null
var blackout_rect: ColorRect = null

var train_light_flickers: Array[TrainLightFlicker] = []

var tutorial_prompt_label: Label = null
var tutorial_prompt_tween: Tween = null
var tutorial_prompt_visible: bool = false

var head_raise_finished: bool = true

var continuity_light_tween: Tween = null
var continuity_light_sequence_finished: bool = true


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	dream_root = get_parent()

	_find_scene_nodes()
	_collect_train_light_flickers()
	_connect_head_raise_signal()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if player_camera != null:
		player_camera.current = true

	_prepare_blackout()

	_set_player_enabled(false)
	_set_flashlight_input_enabled(false)

	# Set the player camera to the lowered first frame while
	# the screen is still completely black.
	_prepare_head_raise_start_pose()

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

	# Allow all wagon and light scripts to complete their _ready()
	# functions before beginning the continuation flicker.
	await get_tree().process_frame
	await get_tree().physics_frame

	_snap_player_to_floor_before_intro()
	_prepare_train_for_transition()

	await _begin_playable_scene()


# ============================================================
# FIND NODES
# ============================================================

func _find_scene_nodes() -> void:
	if dream_root == null:
		push_error(
			"DreamIntroController: DreamIntro root was not found."
		)
		return

	player = dream_root.get_node_or_null(PLAYER_PATH)

	player_camera = (
		dream_root.get_node_or_null(PLAYER_CAMERA_PATH)
		as Camera3D
	)

	head_raise_animation_player = (
		dream_root.get_node_or_null(
			HEAD_RAISE_ANIMATION_PLAYER_PATH
		)
		as AnimationPlayer
	)

	player_flashlight = (
		dream_root.get_node_or_null(PLAYER_FLASHLIGHT_PATH)
		as SpotLight3D
	)

	train_root = dream_root.get_node_or_null(
		TRAIN_ROOT_PATH
	)

	ui_layer = (
		dream_root.get_node_or_null(UI_LAYER_PATH)
		as CanvasLayer
	)

	blackout_rect = (
		dream_root.get_node_or_null(BLACKOUT_RECT_PATH)
		as ColorRect
	)

	# Fallback searches in case a node was moved slightly.
	if player == null:
		player = dream_root.find_child(
			"Player",
			true,
			false
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

	if (
		head_raise_animation_player == null
		and player != null
	):
		head_raise_animation_player = (
			player.find_child(
				"HeadRaiseAnimationPlayer",
				true,
				false
			)
			as AnimationPlayer
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

	if train_root == null:
		train_root = dream_root.find_child(
			"Train",
			true,
			false
		)

	if ui_layer == null:
		ui_layer = (
			dream_root.find_child(
				"UI",
				true,
				false
			)
			as CanvasLayer
		)

	if blackout_rect == null:
		blackout_rect = (
			dream_root.find_child(
				"BlackoutRect",
				true,
				false
			)
			as ColorRect
		)

	_validate_scene_nodes()


func _validate_scene_nodes() -> void:
	if player == null:
		push_error(
			"DreamIntroController: Player was not found."
		)

	if player_camera == null:
		push_error(
			"DreamIntroController: Player Camera3D was not found."
		)

	if head_raise_animation_player == null:
		push_warning(
			"DreamIntroController: "
			+ "HeadRaiseAnimationPlayer was not found at: "
			+ str(HEAD_RAISE_ANIMATION_PLAYER_PATH)
		)
	elif (
		play_head_raise_animation
		and not head_raise_animation_player.has_animation(
			head_raise_animation_name
		)
	):
		push_warning(
			"DreamIntroController: Head raise animation '%s' "
			+ "was not found."
			% head_raise_animation_name
		)

	if player_flashlight == null:
		push_warning(
			"DreamIntroController: Player flashlight was not found."
		)

	if train_root == null:
		push_warning(
			"DreamIntroController: Train root was not found."
		)

	if train_light_flickers.is_empty():
		push_warning(
			"DreamIntroController: No TrainLightFlicker nodes "
			+ "were found under Train."
		)

	if ui_layer == null:
		push_warning(
			"DreamIntroController: UI CanvasLayer was not found. "
			+ "The flashlight tutorial cannot be displayed."
		)

	if blackout_rect == null:
		push_error(
			"DreamIntroController: BlackoutRect was not found at: "
			+ str(BLACKOUT_RECT_PATH)
		)


# ============================================================
# BLACKOUT
# ============================================================

func _prepare_blackout() -> void:
	if blackout_rect == null:
		return

	blackout_rect.visible = true
	blackout_rect.color = Color.BLACK
	blackout_rect.modulate.a = 1.0
	blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var blackout_parent: Node = blackout_rect.get_parent()

	if blackout_parent is CanvasLayer:
		(blackout_parent as CanvasLayer).layer = 1000


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


# ============================================================
# PLAYER GROUNDING
# ============================================================

func _snap_player_to_floor_before_intro() -> void:
	if not snap_player_to_floor_before_intro:
		return

	var player_body: CharacterBody3D = player as CharacterBody3D

	if player_body == null:
		push_warning(
			"DreamIntroController: Player is not a CharacterBody3D. "
			+ "The pre-intro floor snap was skipped."
		)
		return

	var snap_distance: float = maxf(
		player_floor_snap_distance,
		0.0
	)

	if snap_distance <= 0.0:
		return

	var snap_motion: Vector3 = Vector3.DOWN * snap_distance
	var floor_collision: KinematicCollision3D = (
		player_body.move_and_collide(
			snap_motion,
			true
		)
	)

	if floor_collision == null:
		push_warning(
			(
				"DreamIntroController: No floor was found within "
				+ "%.2f meters below Player. "
				+ "The pre-intro floor snap was skipped."
			)
			% snap_distance
		)
		return

	if floor_collision.get_normal().dot(Vector3.UP) < 0.4:
		push_warning(
			"DreamIntroController: The collision found below Player "
			+ "does not look like a floor. The pre-intro snap was skipped."
		)
		return

	player_body.velocity = Vector3.ZERO
	player_body.move_and_collide(snap_motion)
	player_body.velocity = Vector3.ZERO


# ============================================================
# HEAD RAISE ANIMATION
# ============================================================

func _connect_head_raise_signal() -> void:
	if head_raise_animation_player == null:
		return

	if not head_raise_animation_player.animation_finished.is_connected(
		_on_head_raise_animation_finished
	):
		head_raise_animation_player.animation_finished.connect(
			_on_head_raise_animation_finished
		)


func _prepare_head_raise_start_pose() -> void:
	if not _head_raise_is_available():
		head_raise_finished = true
		return

	var head_raise_animation: Animation = (
		head_raise_animation_player.get_animation(
			head_raise_animation_name
		)
	)

	if head_raise_animation != null:
		head_raise_animation.loop_mode = Animation.LOOP_NONE

	head_raise_finished = false

	head_raise_animation_player.play(
		head_raise_animation_name
	)

	head_raise_animation_player.seek(0.0, true)
	head_raise_animation_player.pause()


func _start_head_raise_animation() -> void:
	if not _head_raise_is_available():
		head_raise_finished = true
		return

	head_raise_finished = false

	head_raise_animation_player.play(
		head_raise_animation_name
	)

	head_raise_animation_player.seek(0.0, true)


func _head_raise_is_available() -> bool:
	if not play_head_raise_animation:
		return false

	if head_raise_animation_player == null:
		return false

	return head_raise_animation_player.has_animation(
		head_raise_animation_name
	)


func _on_head_raise_animation_finished(
	animation_name: StringName
) -> void:
	if animation_name != head_raise_animation_name:
		return

	head_raise_finished = true


func _wait_for_head_raise_animation() -> void:
	if head_raise_finished:
		return

	if not _head_raise_is_available():
		head_raise_finished = true
		return

	var maximum_wait: float = 2.0

	var head_raise_animation: Animation = (
		head_raise_animation_player.get_animation(
			head_raise_animation_name
		)
	)

	if head_raise_animation != null:
		maximum_wait = maxf(
			head_raise_animation.length + 0.50,
			0.50
		)

	var elapsed_time: float = 0.0

	while (
		not head_raise_finished
		and elapsed_time < maximum_wait
	):
		await get_tree().process_frame
		elapsed_time += get_process_delta_time()

	head_raise_finished = true


# ============================================================
# PLAYABLE SCENE SEQUENCE
# ============================================================

func _begin_playable_scene() -> void:
	if initial_black_hold_duration > 0.0:
		await get_tree().create_timer(
			initial_black_hold_duration
		).timeout

	# All three begin together:
	# wagon malfunction, head raise, and fast black reveal.
	_start_continuity_light_sequence()
	_start_head_raise_animation()

	await _fade_from_black()

	# The reveal finishes quickly, but input remains disabled
	# until the head movement and light malfunction are complete.
	await _wait_for_head_raise_animation()
	await _wait_for_continuity_light_sequence()

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


# ============================================================
# TRAIN LIGHT CONTINUITY
# ============================================================

func _collect_train_light_flickers() -> void:
	train_light_flickers.clear()

	if train_root == null:
		return

	_find_train_light_flickers_recursive(train_root)


func _find_train_light_flickers_recursive(
	node: Node
) -> void:
	var flicker: TrainLightFlicker = (
		node as TrainLightFlicker
	)

	if flicker != null:
		if not train_light_flickers.has(flicker):
			train_light_flickers.append(flicker)

	for child: Node in node.get_children():
		_find_train_light_flickers_recursive(child)


func _prepare_train_for_transition() -> void:
	if (
		continue_wagon_flicker_during_head_raise
		and not train_light_flickers.is_empty()
	):
		for flicker: TrainLightFlicker in train_light_flickers:
			if flicker == null or not is_instance_valid(flicker):
				continue

			flicker.process_mode = Node.PROCESS_MODE_INHERIT

		return

	_force_train_dark()


func _start_continuity_light_sequence() -> void:
	if (
		not continue_wagon_flicker_during_head_raise
		or train_light_flickers.is_empty()
	):
		continuity_light_sequence_finished = true
		_force_train_dark()
		return

	if (
		continuity_light_tween != null
		and continuity_light_tween.is_valid()
	):
		continuity_light_tween.kill()

	continuity_light_sequence_finished = false

	for flicker: TrainLightFlicker in train_light_flickers:
		if flicker == null or not is_instance_valid(flicker):
			continue

		flicker.process_mode = Node.PROCESS_MODE_INHERIT

		if flicker.has_method("start_panic_flicker"):
			flicker.call("start_panic_flicker")

	var panic_duration: float = maxf(
		continuity_panic_flicker_duration,
		0.0
	)

	var final_duration: float = maxf(
		continuity_final_flicker_duration,
		0.0
	)

	continuity_light_tween = create_tween()

	if panic_duration > 0.0:
		continuity_light_tween.tween_interval(
			panic_duration
		)

	continuity_light_tween.tween_callback(
		_begin_continuity_final_flicker
	)

	if final_duration > 0.0:
		continuity_light_tween.tween_interval(
			final_duration
		)

	continuity_light_tween.tween_callback(
			_complete_continuity_light_sequence
	)


func _begin_continuity_final_flicker() -> void:
	var final_duration: float = maxf(
		continuity_final_flicker_duration,
		0.0
	)

	for flicker: TrainLightFlicker in train_light_flickers:
		if flicker == null or not is_instance_valid(flicker):
			continue

		if flicker.has_method("blackout_with_final_flicker"):
			flicker.call(
				"blackout_with_final_flicker",
				final_duration
			)


func _complete_continuity_light_sequence() -> void:
	_force_train_dark()
	continuity_light_sequence_finished = true


func _wait_for_continuity_light_sequence() -> void:
	if continuity_light_sequence_finished:
		return

	var maximum_wait: float = (
		maxf(continuity_panic_flicker_duration, 0.0)
		+ maxf(continuity_final_flicker_duration, 0.0)
		+ 0.75
	)

	var elapsed_time: float = 0.0

	while (
		not continuity_light_sequence_finished
		and elapsed_time < maximum_wait
	):
		await get_tree().process_frame
		elapsed_time += get_process_delta_time()

	if not continuity_light_sequence_finished:
		_complete_continuity_light_sequence()


func _force_train_dark() -> void:
	if not force_train_lights_off_after_flicker:
		continuity_light_sequence_finished = true
		return

	for flicker: TrainLightFlicker in train_light_flickers:
		if flicker == null or not is_instance_valid(flicker):
			continue

		if flicker.has_method("blackout_with_final_flicker"):
			flicker.call(
				"blackout_with_final_flicker",
				0.0
			)

		# Prevent the stopped train from turning its lights back on.
		flicker.process_mode = Node.PROCESS_MODE_DISABLED

	if train_root != null:
		_disable_train_lights_recursive(train_root)

	continuity_light_sequence_finished = true


func _disable_train_lights_recursive(
	node: Node
) -> void:
	var light: Light3D = node as Light3D

	if light != null:
		light.visible = false
		light.light_energy = 0.0

	for child: Node in node.get_children():
		_disable_train_lights_recursive(child)


# ============================================================
# FLASHLIGHT TUTORIAL
# ============================================================

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


# ============================================================
# PLAYER CONTROL
# ============================================================

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


# ============================================================
# RESPONSIVE UI
# ============================================================

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
