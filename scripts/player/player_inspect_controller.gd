extends Node
class_name PlayerInspectController


enum InspectState {
	CLOSED,
	OPENING,
	VIEWING,
	CLOSING
}


## Emitted when the object has settled in front of the camera. `inspect_id`
## comes from the metadata of the inspected Visual node ("" when not set).
signal inspect_opened(inspect_id: String)
signal inspect_closed(inspect_id: String)
## Emitted once per inspection when the object has been turned to show its back.
signal back_revealed(inspect_id: String)
## Emitted when the player opens a readable spot of the item (an engraving, a note
## on the back...). `spot_id` is the id set on the `ReadableSpot`.
signal spot_read(inspect_id: String, spot_id: StringName)

## Metadata a Visual can carry: `inspect_id` (String) names it for reactions,
## `inspect_back_normal` (Vector3, local space) is the direction its back faces.
const META_INSPECT_ID: StringName = &"inspect_id"
const META_BACK_NORMAL: StringName = &"inspect_back_normal"

## How directly the back must face the viewer, and for how long, to count.
const BACK_FACING_DOT: float = 0.6
const BACK_FACING_SECONDS: float = 0.5

const INSPECT_RENDER_LAYER_NUMBER: int = 20
const INSPECT_RENDER_LAYER_MASK: int = 1 << 19

## `inspect_mode` metadata of a Visual: `read` for a flat document, which is shown
## facing the viewer, only tilts a little and can be turned over; anything else is
## `examine`d: turned freely in every direction (also the default).
const META_INSPECT_MODE: StringName = &"inspect_mode"
## `inspect_fit_scale` metadata of a Visual: a multiplier on the size the item first comes up at (below 1: smaller).
const META_FIT_SCALE: StringName = &"inspect_fit_scale"

## `readable_text` (a localization key, with BBCode) is the writing on a document or
## an inscription on an object; `art_language` the language the art itself is in
## (the art is made once). See `_readable_is_active`.
const META_READABLE_TEXT: StringName = &"readable_text"
const META_ART_LANGUAGE: StringName = &"art_language"
const MODE_EXAMINE: StringName = &"examine"
const MODE_READ: StringName = &"read"

## Fallback viewing distance. Each item is placed at the distance that makes it fill
## a comfortable part of the view (see `_fit_distance_for`); the player can zoom
## in and out around that.
@export var inspect_distance: float = 0.28
## Absolute limits of the viewing distance.
@export var min_inspect_distance: float = 0.07
@export var max_inspect_distance: float = 0.9
## Each wheel notch changes the distance by this fraction.
@export var zoom_fraction: float = 0.1
@export var transition_speed: float = 6.0
## Radians of turn per pixel of mouse travel.
@export var rotate_speed: float = 0.011

@export_category("Handling")
## How much of the view height the largest side of an object fills at first. A
## paper is read, so it is shown bigger than an object that is turned in the hand.
@export_range(0.15, 0.9, 0.01) var fit_height_examine: float = 0.42
@export_range(0.15, 0.9, 0.01) var fit_height_read: float = 0.60
## Where the middle of the item sits on the screen (0 is the top, 1 the bottom). The
## item has the view to itself; only the bottom row (name, way back) is below it.
@export_range(0.1, 0.9, 0.01) var center_examine: float = 0.46
@export_range(0.1, 0.9, 0.01) var center_read: float = 0.47
## How long the controls stay on screen when an item comes up.
@export var controls_hint_seconds: float = 4.0
## Everything sits in a column this wide, as a fraction of the screen's height
## (0.5625 is a vertical 9:16 crop), so a vertical video of the game loses nothing.
@export var column_height_ratio: float = 0.56
## The reading size as a fraction of the screen's height (at the default caption
## size).
@export var body_font_ratio: float = 0.0172
## The player can zoom in to this fraction of the first distance (an object can never be zoomed to
## fill the whole screen) and out to `zoom_out_limit` times it. A paper is read, so it may come closer.
@export var zoom_in_limit_examine: float = 0.65
@export var zoom_in_limit_read: float = 0.8
@export var zoom_out_limit: float = 1.6
## How quickly a released object stops turning (higher is stiffer).
@export var inertia_damping: float = 3.5
## Turning with the movement keys, in radians per second.
@export var key_rotate_speed: float = 1.9
## A paper can only be tilted a little, and springs back when let go.
@export var read_tilt_limit_degrees: float = 24.0


# ============================================================
# INSPECTION LIGHT
# ============================================================

@export_category("Inspection Light")

## Hidden presentation light styled like the player's flashlight.
@export var inspect_light_enabled: bool = true

@export var inspect_light_color: Color = Color("#d7e5ff")

@export_range(0.0, 16.0, 0.1)
var inspect_light_energy: float = 2.0

@export_range(0.1, 5.0, 0.05)
var inspect_light_range: float = 1.25

## This is the cone's angular radius, not its full diameter.
@export_range(5.0, 89.0, 1.0)
var inspect_light_angle: float = 48.0

@export_range(0.0, 2.0, 0.05)
var inspect_light_distance_attenuation: float = 0.65

@export_range(0.0, 2.0, 0.05)
var inspect_light_angle_attenuation: float = 0.80

## Slightly offset from the camera for more natural highlights.
@export var inspect_light_position: Vector3 = Vector3(
	0.055,
	0.045,
	0.015
)


var player: CharacterBody3D = null
var camera: Camera3D = null
var inventory_ui_controller: InventoryUIController = null
var inventory_controller: PlayerInventoryController = null

var inspect_anchor: Node3D = null
var inspect_light: SpotLight3D = null
var inspect_overlay_layer: CanvasLayer = null
var inspect_overlay_root: Control = null
var title_label: Label = null
var close_hint: KeyHint = null
var read_hint: KeyHint = null
var rotate_hint: KeyHint = null
var controls_label: Label = null
var readables: InspectReadables = null

var current_visual_copy: Node3D = null
var source_visual: Node3D = null

var state: int = InspectState.CLOSED
var is_dragging: bool = false
var transition_t: float = 0.0
var keep_mouse_visible_on_finish: bool = false
var current_inspect_id: String = ""
var open_reported: bool = false
var back_reported: bool = false
var back_facing_time: float = 0.0
var current_inspect_distance: float = 0.28

var inspect_mode: StringName = MODE_EXAMINE
var _fit_scale: float = 1.0
var _caption_name_key: String = ""

# A document's writing: the art is made once, in `_art_language`, and its words
# are on the art. For a player of another language the same writing is shown again
# as an easy-to-read overlay, `_readable_key` being its (translated) text.
var _readable_key: String = ""
var _art_language: String = ""
var _readable_on: bool = false
var _shift_current: Vector2 = Vector2.ZERO
var _shift_target: Vector2 = Vector2.ZERO
var _largest: float = 0.1
var _controls_tween: Tween = null

# How the item sits in front of the camera, all relative to the camera so that it
# turns the way the player expects whatever it has been through before.
var _orientation_local: Basis = Basis.IDENTITY
var _item_scale: Vector3 = Vector3.ONE
## The middle of the item in its own space; it turns about this, not its origin.
var _center_local: Vector3 = Vector3.ZERO
var _fit_distance: float = 0.28
var _zoom_min: float = 0.07
var _zoom_max: float = 0.9
var _angular_velocity: Vector2 = Vector2.ZERO
var _last_motion_msec: int = 0
var _tilt: Vector2 = Vector2.ZERO
var _flip_angle: float = 0.0
var _flip_target: float = 0.0
var _resetting: bool = false

var from_transform: Transform3D
var to_transform: Transform3D


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	camera = player.get_node("Head/Camera3D") as Camera3D

	inventory_ui_controller = (
		player.get_node("InventoryUIController")
		as InventoryUIController
	)

	inventory_controller = (
		player.get_node("InventoryController")
		as PlayerInventoryController
	)

	_remove_old_runtime_nodes()
	_build_inspect_anchor()
	_build_inspect_light()
	_build_overlay()
	_connect_language_settings()
	_set_inspect_distance(inspect_distance)

	set_process(true)


func is_open() -> bool:
	return state != InspectState.CLOSED


func open_world(inspectable: Inspectable) -> bool:
	if inspectable == null:
		return false

	var visual: Node3D = inspectable.get_visual_node()

	if visual == null:
		return false

	_force_close_immediate()
	_set_inspect_distance(inspect_distance)

	var duplicated: Node = visual.duplicate()
	var visual_copy: Node3D = duplicated as Node3D

	if visual_copy == null:
		if duplicated != null:
			duplicated.queue_free()

		return false

	source_visual = visual
	source_visual.visible = false

	current_visual_copy = visual_copy
	_get_runtime_parent().add_child(current_visual_copy)
	_prepare_visual_for_inspection(current_visual_copy)
	_configure_for_item(current_visual_copy)
	_show_title(inspectable.inspect_name)
	_begin_tracking()

	current_visual_copy.global_transform = (
		source_visual.global_transform
	)

	from_transform = source_visual.global_transform

	to_transform = _get_inspect_target_transform(
		current_visual_copy
	)

	transition_t = 0.0
	state = InspectState.OPENING
	is_dragging = false
	keep_mouse_visible_on_finish = false

	if inspect_overlay_layer != null:
		inspect_overlay_layer.visible = true

	_set_inspect_light_active(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	return true


## `start_transform` (a Transform3D, optional) makes the item fly in from where it
## lay in the world; without it the item comes from the inventory corner.
func open_inventory(
	slot_data: Dictionary,
	start_transform: Variant = null
) -> bool:
	var template_variant: Variant = slot_data.get(
		"inspect_visual_template",
		null
	)

	var template_node: Node3D = (
		template_variant as Node3D
	)

	if template_node == null:
		return false

	_force_close_immediate()
	_set_inspect_distance(inspect_distance)

	var duplicated: Node = template_node.duplicate()
	var visual_copy: Node3D = duplicated as Node3D

	if visual_copy == null:
		if duplicated != null:
			duplicated.queue_free()

		return false

	source_visual = null
	current_visual_copy = visual_copy

	_get_runtime_parent().add_child(
		current_visual_copy
	)

	_prepare_visual_for_inspection(
		current_visual_copy
	)
	_configure_for_item(current_visual_copy)
	_show_title(str(slot_data.get("name", "")))
	_begin_tracking()

	if start_transform is Transform3D:
		from_transform = start_transform as Transform3D
	else:
		from_transform = _get_inventory_spawn_transform(
			current_visual_copy
		)

	to_transform = _get_inspect_target_transform(
		current_visual_copy
	)

	current_visual_copy.global_transform = from_transform

	transition_t = 0.0
	state = InspectState.OPENING
	is_dragging = false
	keep_mouse_visible_on_finish = true

	if inspect_overlay_layer != null:
		inspect_overlay_layer.visible = true

	_set_inspect_light_active(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	return true


func close(
	keep_mouse_visible: bool = false
) -> void:
	if (
		state == InspectState.CLOSED
		or current_visual_copy == null
	):
		_force_close_immediate()

		if keep_mouse_visible:
			Input.set_mouse_mode(
				Input.MOUSE_MODE_VISIBLE
			)

		return

	_report_closed()

	from_transform = (
		current_visual_copy.global_transform
	)

	if is_instance_valid(source_visual):
		to_transform = source_visual.global_transform
	else:
		to_transform = _get_inventory_spawn_transform(
			current_visual_copy
		)

	transition_t = 0.0
	state = InspectState.CLOSING
	is_dragging = false
	keep_mouse_visible_on_finish = keep_mouse_visible


func handle_input(event: InputEvent) -> void:
	if state != InspectState.VIEWING or current_visual_copy == null:
		return

	# The readable spots (the prompt, the open text) take the first chance.
	if readables != null and readables.handle_input(event):
		return

	if event.is_action_pressed("inspect_flip"):
		_flip()
		return

	if event.is_action_pressed("inspect_reset"):
		_reset_view()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton

		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = mouse_button.pressed
			if mouse_button.pressed:
				_angular_velocity = Vector2.ZERO
				_resetting = false
				_last_motion_msec = Time.get_ticks_msec()
				# A double click brings the item back to how it was first shown.
				if mouse_button.double_click:
					_reset_view()
			return

		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_inspect_distance(current_inspect_distance * (1.0 - zoom_fraction))
			return

		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_inspect_distance(current_inspect_distance * (1.0 + zoom_fraction))
			return

	elif event is InputEventMouseMotion and is_dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var turn: Vector2 = motion.relative * rotate_speed
		_resetting = false

		if inspect_mode == MODE_READ:
			# A paper only tilts, up to a limit.
			var limit: float = deg_to_rad(read_tilt_limit_degrees)
			_tilt = Vector2(
				clampf(_tilt.x + turn.x * 0.6, -limit, limit),
				clampf(_tilt.y + turn.y * 0.6, -limit, limit)
			)
			return

		# Turned about the camera's own axes: the surface under the cursor follows
		# it, whatever side is showing. (Turning about the object's own axes, as
		# before, makes a second drag feel like a different control.)
		_rotate_item(turn)

		# The speed of the drag, so that a flick keeps the item turning for a moment.
		var now: int = Time.get_ticks_msec()
		var seconds: float = clampf(float(now - _last_motion_msec) / 1000.0, 0.004, 0.06)
		_last_motion_msec = now
		_angular_velocity = (_angular_velocity * 0.4 + (turn / seconds) * 0.6).limit_length(14.0)


func _process(delta: float) -> void:
	if state == InspectState.OPENING:
		transition_t = minf(
			transition_t
			+ delta * transition_speed,
			1.0
		)

		_apply_interpolated_transform(
			from_transform,
			to_transform,
			transition_t
		)

		if transition_t >= 1.0:
			state = InspectState.VIEWING
			_report_opened()

	elif state == InspectState.VIEWING:
		_update_view(delta)
		_update_back_tracking(delta)

	elif state == InspectState.CLOSING:
		transition_t = minf(
			transition_t
			+ delta * transition_speed,
			1.0
		)

		_apply_interpolated_transform(
			from_transform,
			to_transform,
			transition_t
		)

		if transition_t >= 1.0:
			_finish_close()


func _apply_interpolated_transform(
	start_transform: Transform3D,
	end_transform: Transform3D,
	t: float
) -> void:
	if current_visual_copy == null:
		return

	var start_pos: Vector3 = (
		start_transform.origin
	)

	var end_pos: Vector3 = (
		end_transform.origin
	)

	var pos: Vector3 = start_pos.lerp(
		end_pos,
		t
	)

	var start_quat: Quaternion = (
		start_transform.basis
		.get_rotation_quaternion()
	)

	var end_quat: Quaternion = (
		end_transform.basis
		.get_rotation_quaternion()
	)

	var rot: Quaternion = start_quat.slerp(
		end_quat,
		t
	)

	var start_scale: Vector3 = (
		start_transform.basis.get_scale()
	)

	var end_scale: Vector3 = (
		end_transform.basis.get_scale()
	)

	var scale: Vector3 = start_scale.lerp(
		end_scale,
		t
	)

	current_visual_copy.global_transform = (
		Transform3D(
			Basis(rot).scaled(scale),
			pos
		)
	)


func _get_inspect_target_transform(
	reference_node: Node3D
) -> Transform3D:
	var target_rotation: Quaternion = _steady_basis().get_rotation_quaternion()

	var target_scale: Vector3 = (
		reference_node.global_transform.basis
		.get_scale()
	)

	var target_basis: Basis = Basis(target_rotation).scaled(target_scale)

	return Transform3D(
		target_basis,
		inspect_anchor.global_transform.origin
		+ _steady_basis() * Vector3(_shift_target.x, _shift_target.y, 0.0)
		- target_basis * _center_local
	)


func _get_inventory_spawn_transform(
	reference_node: Node3D
) -> Transform3D:
	var cam_basis: Basis = (
		camera.global_transform.basis
	)

	var spawn_pos: Vector3 = (
		camera.global_position
		+ (-cam_basis.z * 0.22)
		+ (cam_basis.x * 0.16)
		+ (-cam_basis.y * 0.16)
	)

	var target_rotation: Quaternion = _steady_basis().get_rotation_quaternion()

	var target_scale: Vector3 = (
		reference_node.global_transform.basis
		.get_scale()
	)

	return Transform3D(
		Basis(target_rotation).scaled(target_scale),
		spawn_pos
	)


func _get_runtime_parent() -> Node:
	if player.get_tree().current_scene != null:
		return player.get_tree().current_scene

	return player.get_parent()


func _set_inspect_distance(
	new_distance: float
) -> void:
	current_inspect_distance = clampf(new_distance, _zoom_min, _zoom_max)

	if inspect_anchor != null:
		inspect_anchor.position = Vector3(
			0.0,
			0.0,
			-current_inspect_distance
		)

	_aim_inspect_light()


func _begin_tracking() -> void:
	current_inspect_id = str(
		current_visual_copy.get_meta(META_INSPECT_ID, "")
	)
	open_reported = false
	back_reported = false
	back_facing_time = 0.0


func _report_opened() -> void:
	if open_reported or current_inspect_id.is_empty():
		return

	open_reported = true
	inspect_opened.emit(current_inspect_id)


func _report_closed() -> void:
	if not open_reported:
		return

	open_reported = false
	inspect_closed.emit(current_inspect_id)


## Fires `back_revealed` once the object's back faces the viewer for a moment.
func _update_back_tracking(delta: float) -> void:
	if (
		back_reported
		or current_inspect_id.is_empty()
		or current_visual_copy == null
		or not current_visual_copy.has_meta(META_BACK_NORMAL)
	):
		return

	var back_normal: Vector3 = (
		current_visual_copy.global_basis
		* (current_visual_copy.get_meta(META_BACK_NORMAL) as Vector3)
	).normalized()

	# The camera looks down -Z, so +Z of its basis points at the viewer.
	if back_normal.dot(camera.global_basis.z) >= BACK_FACING_DOT:
		back_facing_time += delta
	else:
		back_facing_time = 0.0

	if back_facing_time >= BACK_FACING_SECONDS:
		back_reported = true
		back_revealed.emit(current_inspect_id)


func _finish_close() -> void:
	if readables != null:
		readables.end()

	if is_instance_valid(source_visual):
		source_visual.visible = true

	if is_instance_valid(current_visual_copy):
		current_visual_copy.queue_free()

	current_visual_copy = null
	source_visual = null
	state = InspectState.CLOSED
	is_dragging = false

	if inspect_overlay_layer != null:
		inspect_overlay_layer.visible = false
	_show_title("")

	_set_inspect_light_active(false)

	if keep_mouse_visible_on_finish:
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE
		)
	else:
		Input.set_mouse_mode(
			Input.MOUSE_MODE_CAPTURED
		)


func _force_close_immediate() -> void:
	if readables != null:
		readables.end()

	_report_closed()

	if is_instance_valid(source_visual):
		source_visual.visible = true

	if is_instance_valid(current_visual_copy):
		current_visual_copy.queue_free()

	current_visual_copy = null
	source_visual = null
	state = InspectState.CLOSED
	is_dragging = false
	transition_t = 0.0
	keep_mouse_visible_on_finish = false

	if inspect_overlay_layer != null:
		inspect_overlay_layer.visible = false
	_show_title("")

	_set_inspect_light_active(false)


# ============================================================
# RUNTIME NODES
# ============================================================

func _remove_old_runtime_nodes() -> void:
	var old_anchor: Node = (
		camera.get_node_or_null("InspectAnchor")
	)

	if old_anchor != null:
		old_anchor.queue_free()

	var old_light: Node = (
		camera.get_node_or_null(
			"InspectLightRuntime"
		)
	)

	if old_light != null:
		old_light.queue_free()

	var old_overlay: Node = (
		player.get_node_or_null(
			"InspectOverlayRuntime"
		)
	)

	if old_overlay != null:
		old_overlay.queue_free()


func _build_inspect_anchor() -> void:
	inspect_anchor = Node3D.new()
	inspect_anchor.name = "InspectAnchor"
	camera.add_child(inspect_anchor)


func _build_inspect_light() -> void:
	inspect_light = SpotLight3D.new()
	inspect_light.name = "InspectLightRuntime"
	inspect_light.position = inspect_light_position
	inspect_light.light_color = inspect_light_color
	inspect_light.light_energy = inspect_light_energy
	inspect_light.light_indirect_energy = 0.0
	inspect_light.light_specular = 0.45
	inspect_light.light_volumetric_fog_energy = 0.0

	inspect_light.light_bake_mode = (
		Light3D.BAKE_DISABLED
	)

	inspect_light.light_cull_mask = (
		INSPECT_RENDER_LAYER_MASK
	)

	inspect_light.spot_range = (
		inspect_light_range
	)

	inspect_light.spot_angle = (
		inspect_light_angle
	)

	inspect_light.spot_attenuation = (
		inspect_light_distance_attenuation
	)

	inspect_light.spot_angle_attenuation = (
		inspect_light_angle_attenuation
	)

	inspect_light.shadow_enabled = false
	inspect_light.visible = false

	camera.add_child(inspect_light)

	camera.cull_mask |= (
		INSPECT_RENDER_LAYER_MASK
	)


func _set_inspect_light_active(
	is_active: bool
) -> void:
	if inspect_light == null:
		return

	inspect_light.visible = (
		is_active
		and inspect_light_enabled
	)


func _aim_inspect_light() -> void:
	if (
		inspect_light == null
		or inspect_anchor == null
	):
		return

	if not inspect_light.is_inside_tree():
		return

	if inspect_light.global_position.is_equal_approx(
		inspect_anchor.global_position
	):
		return

	inspect_light.look_at(
		inspect_anchor.global_position,
		Vector3.UP
	)


func _prepare_visual_for_inspection(
	node: Node
) -> void:
	var visual_instance: VisualInstance3D = (
		node as VisualInstance3D
	)

	if (
		visual_instance != null
		and not (visual_instance is Light3D)
	):
		visual_instance.set_layer_mask_value(
			INSPECT_RENDER_LAYER_NUMBER,
			true
		)

	for child in node.get_children():
		_prepare_visual_for_inspection(child)


func _build_overlay() -> void:
	inspect_overlay_layer = CanvasLayer.new()
	inspect_overlay_layer.name = "InspectOverlayRuntime"
	inspect_overlay_layer.layer = 15
	inspect_overlay_layer.visible = false
	player.add_child(inspect_overlay_layer)

	inspect_overlay_root = Control.new()
	inspect_overlay_root.name = "InspectOverlayRoot"
	inspect_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	inspect_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_overlay_layer.add_child(inspect_overlay_root)

	# The prompt to read and the text view come first, so that the bottom row (the
	# name and the way back) stays above the dark veil that the text brings.
	readables = InspectReadables.new()
	readables.name = "Readables"
	readables.controller = self
	add_child(readables)
	readables.build_ui(inspect_overlay_root)
	readables.spot_read.connect(func(spot_id: StringName) -> void: spot_read.emit(current_inspect_id, spot_id))
	readables.reading_changed.connect(_on_reading_changed)
	readables.read_availability_changed.connect(_layout_overlay)

	_build_bottom_row()

	var viewport: Viewport = player.get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_layout_overlay):
		viewport.size_changed.connect(_layout_overlay)

	_refresh_overlay_text()


## The whole of the chrome: the item's name at the bottom left and the way back at the
## bottom right, in the one central column (no wider than a vertical 9:16 crop of the
## screen, so nothing essential is lost when the game is shown on a phone). The
## controls are said once, quietly, when the item comes up, and then fade away.
func _build_bottom_row() -> void:
	title_label = Label.new()
	title_label.name = "InspectTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.theme_type_variation = &"ItemTitleLabel"
	inspect_overlay_root.add_child(title_label)

	close_hint = KeyHint.new()
	close_hint.name = "InspectClose"
	close_hint.pressed.connect(_on_close_button_pressed)
	inspect_overlay_root.add_child(close_hint)

	# The two things to do with the item, in the same key-cap style as Close: read (when it has plain
	# writing) and rotate. Centred in the column, a row above the name and Close.
	read_hint = KeyHint.new()
	read_hint.name = "InspectRead"
	read_hint.pressed.connect(_on_read_hint_pressed)
	inspect_overlay_root.add_child(read_hint)

	rotate_hint = KeyHint.new()
	rotate_hint.name = "InspectRotate"
	rotate_hint.pressed.connect(_flip)
	inspect_overlay_root.add_child(rotate_hint)

	controls_label = Label.new()
	controls_label.name = "InspectControls"
	controls_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls_label.theme_type_variation = &"HintLabel"
	inspect_overlay_root.add_child(controls_label)


## Sets (and remembers, for a change of language) the item's name. Empty hides it.
## Objects are not described: the item itself is what the player looks at.
func _show_title(name_key: String) -> void:
	_caption_name_key = name_key
	_refresh_overlay_text()
	_show_controls_hint()


## The controls, for a few seconds.
func _show_controls_hint() -> void:
	if controls_label == null:
		return

	if _controls_tween != null and _controls_tween.is_valid():
		_controls_tween.kill()

	controls_label.modulate.a = 1.0
	_controls_tween = create_tween()
	_controls_tween.tween_interval(controls_hint_seconds)
	_controls_tween.tween_property(controls_label, "modulate:a", 0.0, 1.2)


func _refresh_overlay_text() -> void:
	if title_label == null:
		return

	_update_readable_state(false)
	title_label.text = get_item_title()
	controls_label.text = get_hint_text()
	_layout_overlay()


## What the player can do with the item in front of them, with their own keys.
func get_hint_text() -> String:
	var key: String = (
		"INSPECT_HINT_READ" if inspect_mode == MODE_READ else "INSPECT_HINT_EXAMINE"
	)
	return InputBindings.format_text(tr(key))


## The item's name in the player's language ("" if it has none).
func get_item_title() -> String:
	return tr(_caption_name_key) if not _caption_name_key.is_empty() else ""


## The font of the inspect view: the game's UI font (UIConfig), regular or bold.
func get_ui_font(bold: bool) -> Font:
	return UIConfig.font(UIConfig.weight_title if bold else UIConfig.weight_body, UIConfig.spacing_body)


# -- Layout: one central column --------------------------------------------

func _screen_size() -> Vector2:
	var size: Vector2 = player.get_viewport().get_visible_rect().size
	return Vector2(maxf(size.x, 320.0), maxf(size.y, 240.0))


## The width of the column: a 9:16 crop of the screen, whatever the screen.
func _column_width() -> float:
	var size: Vector2 = _screen_size()
	return minf(size.x * 0.94, size.y * column_height_ratio)


## The reading size: a fraction of the screen's height (so it looks the same at any
## resolution), scaled by the player's caption-size setting.
func _body_font_size() -> int:
	var default_size: float = float(GameSettings.CAPTION_FONT_SIZES[GameSettings.DEFAULT_CAPTION_SIZE])
	var scale: float = float(GameSettings.get_caption_font_size()) / default_size
	return maxi(int(round(_screen_size().y * body_font_ratio * scale)), 13)


func _layout_overlay() -> void:
	if title_label == null or close_hint == null or controls_label == null:
		return

	var screen: Vector2 = _screen_size()
	var column: float = _column_width()
	var left: float = (screen.x - column) * 0.5
	var body: int = _body_font_size()
	var row_top: float = screen.y * 0.915

	# The way back: "Esc  Close" on the item, "Esc  Back" from a text.
	var verb_key: String = (
		"INSPECT_BACK" if readables != null and readables.is_text_open() else "INSPECT_VERB_CLOSE"
	)
	close_hint.set_hint(tr("KEY_NAME_ESCAPE"), tr(verb_key), body, get_ui_font(false))
	close_hint.position = Vector2(left + column - close_hint.size.x, row_top)

	var title_width: float = maxf(column - close_hint.size.x - 28.0, 40.0)
	title_label.add_theme_font_size_override("font_size", int(body * 1.2))
	title_label.position = Vector2(left, row_top)
	title_label.size = Vector2(title_width, close_hint.size.y)

	controls_label.add_theme_font_override("font", get_ui_font(false))
	controls_label.add_theme_font_size_override("font_size", maxi(int(body * 0.85), 12))
	controls_label.position = Vector2(left, row_top - body * 7.6)
	controls_label.size = Vector2(column, body * 1.6)

	_layout_action_row(left, column, row_top, body)

	if readables != null:
		readables.relayout()


## "[E] Read   [R] Rotate", centred a row above the name and Close. Rotate is always there; Read only
## while there is plain writing facing the player (a ticket, either side; a photograph once turned to
## its back). Hidden details (a whistle's engraving) never add a Read: they are found by turning the
## item. No row while a text is open (Back is the only choice then).
func _layout_action_row(left: float, column: float, row_top: float, body: int) -> void:
	if read_hint == null or rotate_hint == null:
		return

	var can_read: bool = readables != null and readables.has_obvious_reading()
	var reading: bool = readables != null and readables.is_text_open()
	var show_row: bool = not reading

	read_hint.visible = show_row and can_read
	rotate_hint.visible = show_row
	if not show_row:
		return

	var font: Font = get_ui_font(false)
	read_hint.set_hint(InputBindings.get_binding_label(&"interact", -1, true), tr("INSPECT_VERB_READ"), body, font)
	rotate_hint.set_hint(InputBindings.get_binding_label(&"inspect_flip", -1, true), tr("INSPECT_VERB_ROTATE"), body, font)

	# Two fixed places, Read then Rotate, centred as a pair whether or not Read is showing: when Read
	# appears or goes it only fades in or out, nothing moves.
	var gap: float = body * 2.0
	var width: float = read_hint.size.x + gap + rotate_hint.size.x
	var x: float = left + (column - width) * 0.5
	var y: float = row_top - body * 5.3
	read_hint.position = Vector2(x, y)
	rotate_hint.position = Vector2(x + read_hint.size.x + gap, y)


func _on_read_hint_pressed() -> void:
	if readables != null:
		readables.activate()
		_layout_overlay()


func _on_reading_changed(_is_reading: bool) -> void:
	_layout_overlay()
	if controls_label != null:
		controls_label.visible = not _is_reading


func _connect_language_settings() -> void:
	if not GameSettings.readable_text_mode_changed.is_connected(_on_reading_setting_changed):
		GameSettings.readable_text_mode_changed.connect(_on_reading_setting_changed)
	if not GameSettings.caption_size_changed.is_connected(_on_reading_setting_changed):
		GameSettings.caption_size_changed.connect(_on_reading_setting_changed)

	if not GameSettings.text_language_changed.is_connected(
		_on_text_language_changed
	):
		GameSettings.text_language_changed.connect(
			_on_text_language_changed
		)


func _on_text_language_changed(_locale: String) -> void:
	_refresh_overlay_text()


func _on_reading_setting_changed(_value: int) -> void:
	_refresh_overlay_text()


func _on_close_button_pressed() -> void:
	# From a text, back goes to the item, as the Esc key does.
	if try_close_text_overlay():
		return

	var return_to_inventory: bool = (
		inventory_ui_controller != null
		and inventory_ui_controller
		.should_return_to_inventory_after_inspect()
	)

	close(return_to_inventory)

	if (
		return_to_inventory
		and inventory_controller != null
		and inventory_ui_controller != null
	):
		inventory_ui_controller.show_inventory(
			inventory_controller.get_slots()
		)

	elif inventory_ui_controller != null:
		inventory_ui_controller.close()


# ============================================================
# HANDLING THE ITEM
# ============================================================

## Works out how this item is to be shown: its mode (a document is read, anything
## else is turned in the hand), the middle it turns about, and the distance that
## makes it fill a comfortable part of the view, so a key and a lantern both come
## to a sensible size.
func _configure_for_item(item: Node3D) -> void:
	var mode: String = str(item.get_meta(META_INSPECT_MODE, "examine"))
	inspect_mode = MODE_READ if mode == "read" else MODE_EXAMINE
	_item_scale = item.global_basis.get_scale()
	_fit_scale = clampf(float(item.get_meta(META_FIT_SCALE, 1.0)), 0.2, 1.5)

	var bounds: AABB = _local_bounds(item)
	_center_local = bounds.get_center()

	var largest: float = maxf(
		bounds.size.x * _item_scale.x,
		maxf(bounds.size.y * _item_scale.y, bounds.size.z * _item_scale.z)
	)
	_largest = largest

	_orientation_local = Basis.IDENTITY
	_angular_velocity = Vector2.ZERO
	_tilt = Vector2.ZERO
	_flip_angle = 0.0
	_flip_target = 0.0
	_resetting = false

	readables.begin(item)
	_readable_key = str(item.get_meta(META_READABLE_TEXT, ""))
	_art_language = str(item.get_meta(META_ART_LANGUAGE, ""))
	_readable_on = false
	_update_readable_state(true)
	_refresh_overlay_text()


## The box around everything visible in the item, in the item's own space.
func _local_bounds(item: Node3D) -> AABB:
	var result: AABB = AABB()
	var found: bool = false
	var to_local: Transform3D = item.global_transform.affine_inverse()

	var nodes: Array[Node] = [item]
	nodes.append_array(item.find_children("*", "VisualInstance3D", true, false))

	for node: Node in nodes:
		var visual: VisualInstance3D = node as VisualInstance3D
		if visual == null or visual is Light3D:
			continue

		var box: AABB = (to_local * visual.global_transform) * visual.get_aabb()
		result = box if not found else result.merge(box)
		found = true

	if not found:
		return AABB(Vector3(-0.05, -0.05, -0.05), Vector3(0.1, 0.1, 0.1))

	return result


## Turns the item about the camera's up and right axes by `turn` radians.
func _rotate_item(turn: Vector2) -> void:
	_orientation_local = (
		Basis(Vector3.UP, turn.x) * Basis(Vector3.RIGHT, turn.y) * _orientation_local
	).orthonormalized()


## Turns the item over to show its back (and again to show its front).
func _flip() -> void:
	if state != InspectState.VIEWING:
		return

	_flip_target += PI
	_resetting = false
	_angular_velocity = Vector2.ZERO


## Back to how the item was first shown, at the first distance.
func _reset_view() -> void:
	if state != InspectState.VIEWING:
		return

	_resetting = true
	_flip_angle = 0.0
	_flip_target = 0.0
	_angular_velocity = Vector2.ZERO


func _update_view(delta: float) -> void:
	# Reading a spot: the item eases round to show it squarely and nothing turns it.
	if readables != null and readables.is_focusing():
		var follow: float = 1.0 - exp(-7.0 * delta)
		var target: Quaternion = readables.get_focus_orientation().get_rotation_quaternion()
		_orientation_local = Basis(_orientation_local.get_rotation_quaternion().slerp(target, follow))
		_angular_velocity = Vector2.ZERO
		_tilt = _tilt.lerp(Vector2.ZERO, follow)
		_resetting = false
		_flip_target = _flip_angle
		_apply_pose()
		return

	if inspect_mode == MODE_EXAMINE:
		var keys: Vector2 = Vector2(
			Input.get_axis("left", "right"),
			Input.get_axis("up", "down")
		)

		if keys != Vector2.ZERO:
			_resetting = false
			_angular_velocity = Vector2.ZERO
			_rotate_item(keys * key_rotate_speed * delta)
		elif not is_dragging:
			# Let go: the item keeps turning for a moment and slows down.
			if _angular_velocity.length() > 0.03:
				_rotate_item(_angular_velocity * delta)
				_angular_velocity *= exp(-inertia_damping * delta)
			else:
				_angular_velocity = Vector2.ZERO
	elif not is_dragging:
		_tilt = _tilt.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))

	if not is_equal_approx(_flip_angle, _flip_target):
		var next_angle: float = lerpf(_flip_angle, _flip_target, 1.0 - exp(-9.0 * delta))
		if absf(next_angle - _flip_target) < 0.004:
			next_angle = _flip_target

		_rotate_item(Vector2(next_angle - _flip_angle, 0.0))
		_flip_angle = next_angle

	if _resetting:
		var follow: float = 1.0 - exp(-8.0 * delta)
		var quaternion: Quaternion = _orientation_local.get_rotation_quaternion().slerp(
			Quaternion.IDENTITY, follow
		)
		_orientation_local = Basis(quaternion)
		_tilt = _tilt.lerp(Vector2.ZERO, follow)
		_set_inspect_distance(lerpf(current_inspect_distance, _fit_distance, follow))

		if quaternion.angle_to(Quaternion.IDENTITY) < 0.01 and absf(current_inspect_distance - _fit_distance) < 0.002:
			_orientation_local = Basis.IDENTITY
			_set_inspect_distance(_fit_distance)
			_resetting = false

	# With the overlay text on the left the item sits in the middle of what is left.
	_shift_target = _shift_for_distance(current_inspect_distance)
	_shift_current = _shift_current.lerp(_shift_target, 1.0 - exp(-8.0 * delta))

	if readables != null:
		readables.update(delta)

	_apply_pose()


## Puts the item where the orientation says, with its middle on the anchor.
func _apply_pose() -> void:
	if current_visual_copy == null or inspect_anchor == null:
		return

	var local: Basis = _orientation_local
	if inspect_mode == MODE_READ:
		local = Basis(Vector3.UP, _tilt.x) * Basis(Vector3.RIGHT, _tilt.y) * local

	var item_basis: Basis = (_steady_basis() * local).orthonormalized().scaled(_item_scale)
	current_visual_copy.global_transform = Transform3D(
		item_basis,
		inspect_anchor.global_position
		+ _steady_basis() * Vector3(_shift_current.x, _shift_current.y, 0.0)
		- item_basis * _center_local
	)


## The camera's direction without its roll: the breathing sway and the small
## leans of the player's view must not tilt a paper held up to read.
func _steady_basis() -> Basis:
	return Basis.looking_at(-camera.global_basis.z, Vector3.UP)


# ============================================================
# THE WRITING ON A DOCUMENT
# ============================================================
#
# A document's art is made once, in one language, with its words on it. A player of
# that language sees it as it is. A player of another language sees the same art
# (the handwriting, the stains, the marks) and, next to it, the writing as an overlay
# in their own language, big and easy to read, as modern games do. An object with an
# inscription works the same way; an object without writing needs nothing (its name
# and description are the caption, and they always follow the language).

## Whether the overlay is shown for this item: the item has a text and, by the
## player's choice, always; never; or (the default) when the art is in another
## language than the player's.
func _readable_is_active() -> bool:
	if _readable_key.is_empty() or current_visual_copy == null:
		return false

	match GameSettings.get_readable_text_mode():
		GameSettings.ReadableText.NEVER:
			return false
		GameSettings.ReadableText.ALWAYS:
			return true

	return not _art_language.is_empty() and _art_language != GameSettings.get_text_locale()


func _update_readable_state(immediately: bool) -> void:
	var active: bool = _readable_is_active()
	var changed: bool = active != _readable_on

	if changed or immediately:
		_readable_on = active
		# With the overlay on, the words made in the world as stand-in art step aside
		# (final art has none of these).
		_set_model_text_visible(not active)
		_reframe(immediately)


## Where the item sits and how big it first is. It is framed inside the central
## column (a vertical crop of the screen), in the middle: large when it is a
## document, smaller when it is an object to turn in the hand. The first size is
## deliberately modest; the player can zoom in to look closer.
func _reframe(immediately: bool) -> void:
	var half_view: float = tan(deg_to_rad(camera.fov * 0.5))
	var screen: Vector2 = _screen_size()
	var aspect: float = screen.x / screen.y

	var height_fraction: float = fit_height_examine
	if inspect_mode == MODE_READ:
		height_fraction = fit_height_read

	var width_fraction: float = _column_width() * 0.96 / screen.x
	# A few items are shown smaller than the rule gives them (`inspect_fit_scale` metadata on the Visual).
	height_fraction *= _fit_scale
	width_fraction *= _fit_scale

	_fit_distance = inspect_distance
	if _largest > 0.001:
		var for_height: float = _largest / height_fraction / (2.0 * half_view)
		var for_width: float = _largest / width_fraction / (2.0 * half_view * aspect)
		_fit_distance = maxf(for_height, for_width)

	_fit_distance = clampf(_fit_distance, min_inspect_distance, max_inspect_distance)
	var zoom_in_limit: float = zoom_in_limit_read if inspect_mode == MODE_READ else zoom_in_limit_examine
	_zoom_min = maxf(min_inspect_distance, _fit_distance * zoom_in_limit)
	_zoom_max = minf(max_inspect_distance, _fit_distance * zoom_out_limit)
	_set_inspect_distance(_fit_distance)

	_shift_target = _shift_for_distance(_fit_distance)
	if immediately:
		_shift_current = _shift_target


## How far above the middle of the view the item sits, in metres at this distance,
## to put its middle at the height that suits what is shown with it.
func _shift_for_distance(distance: float) -> Vector2:
	var center: float = center_examine
	if inspect_mode == MODE_READ:
		center = center_read

	return Vector2(0.0, (0.5 - center) * 2.0 * distance * tan(deg_to_rad(camera.fov * 0.5)))


## Hides or shows the written words that the world's stand-in documents carry (a
## ParagraphStack or a label whose text is a localization key); signs that are the
## same in every language, like a circled digit, stay.
func _set_model_text_visible(is_visible: bool) -> void:
	if current_visual_copy == null:
		return

	for node: Node in current_visual_copy.find_children("*", "Node3D", true, false):
		if node is ParagraphStack:
			(node as ParagraphStack).visible = is_visible
		elif node is Label3D:
			var text: String = (node as Label3D).text
			if text.contains("_") and text == text.to_upper() and not text.contains(" "):
				(node as Label3D).visible = is_visible


# ============================================================
# READABLE SPOTS (see InspectReadables)
# ============================================================

## True while the text of a readable spot is open (or fading out).
func is_reading_text() -> bool:
	return readables != null and readables.is_reading()


## Closes the text of a readable spot if one is open, and says whether it did. The
## player's Back keys (Esc, right click, the inventory key) call this first, so they
## go back from the text to the item before they leave the item.
func try_close_text_overlay() -> bool:
	return readables != null and readables.close_text()


## The geometry the readable overlay shares with the rest of the inspect view.
func get_screen_size() -> Vector2:
	return _screen_size()


func get_column_width() -> float:
	return _column_width()


func get_body_font_size() -> int:
	return _body_font_size()


## True when the item has writing that is offered to be read (see
## `_readable_is_active`): the player is offered it with the interact key.
func has_document_text() -> bool:
	return _readable_on


func get_document_text_key() -> String:
	return _readable_key


## The middle of the item in the world, where its prompt belongs.
func get_item_center_world() -> Vector3:
	if current_visual_copy == null:
		return inspect_anchor.global_position if inspect_anchor != null else Vector3.ZERO

	return current_visual_copy.global_transform * _center_local


## How far from the camera the item is (the depth the blur keeps sharp), and half of
## its largest side.
func get_focus_distance() -> float:
	return maxf(camera.global_position.distance_to(get_item_center_world()), 0.05)


func get_item_radius() -> float:
	return _largest * 0.5
