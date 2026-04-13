extends Node
class_name PlayerInspectController

enum InspectState {
	CLOSED,
	OPENING,
	VIEWING,
	CLOSING
}

@export var inspect_distance: float = 0.28
@export var min_inspect_distance: float = 0.20
@export var max_inspect_distance: float = 0.45
@export var zoom_step: float = 0.03
@export var transition_speed: float = 6.0
@export var rotate_speed: float = 0.01

var player: CharacterBody3D = null
var camera: Camera3D = null
var inventory_ui_controller: InventoryUIController = null
var inventory_controller: PlayerInventoryController = null

var inspect_anchor: Node3D = null
var inspect_overlay_layer: CanvasLayer = null
var inspect_overlay_root: Control = null
var close_button: Button = null

var current_visual_copy: Node3D = null
var source_visual: Node3D = null

var state: int = InspectState.CLOSED
var is_dragging: bool = false
var transition_t: float = 0.0
var keep_mouse_visible_on_finish: bool = false
var current_inspect_distance: float = 0.28

var from_transform: Transform3D
var to_transform: Transform3D


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	camera = player.get_node("Head/Camera3D") as Camera3D
	inventory_ui_controller = player.get_node("InventoryUIController") as InventoryUIController
	inventory_controller = player.get_node("InventoryController") as PlayerInventoryController

	_remove_old_runtime_nodes()
	_build_inspect_anchor()
	_build_overlay()
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
	current_visual_copy.global_transform = source_visual.global_transform

	from_transform = source_visual.global_transform
	to_transform = _get_inspect_target_transform(current_visual_copy)

	transition_t = 0.0
	state = InspectState.OPENING
	is_dragging = false
	keep_mouse_visible_on_finish = false

	if inspect_overlay_layer != null:
		inspect_overlay_layer.visible = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	return true


func open_inventory(slot_data: Dictionary) -> bool:
	var template_variant: Variant = slot_data.get("inspect_visual_template", null)
	var template_node: Node3D = template_variant as Node3D

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
	_get_runtime_parent().add_child(current_visual_copy)

	from_transform = _get_inventory_spawn_transform(current_visual_copy)
	to_transform = _get_inspect_target_transform(current_visual_copy)
	current_visual_copy.global_transform = from_transform

	transition_t = 0.0
	state = InspectState.OPENING
	is_dragging = false
	keep_mouse_visible_on_finish = true

	if inspect_overlay_layer != null:
		inspect_overlay_layer.visible = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	return true


func close(keep_mouse_visible: bool = false) -> void:
	if state == InspectState.CLOSED or current_visual_copy == null:
		_force_close_immediate()
		if keep_mouse_visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	from_transform = current_visual_copy.global_transform

	if is_instance_valid(source_visual):
		to_transform = source_visual.global_transform
	else:
		to_transform = _get_inventory_spawn_transform(current_visual_copy)

	transition_t = 0.0
	state = InspectState.CLOSING
	is_dragging = false
	keep_mouse_visible_on_finish = keep_mouse_visible


func handle_input(event: InputEvent) -> void:
	if state != InspectState.VIEWING or current_visual_copy == null:
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton

		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = mouse_button.pressed
			return

		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_inspect_distance(current_inspect_distance - zoom_step)
			current_visual_copy.global_position = inspect_anchor.global_position
			return

		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_inspect_distance(current_inspect_distance + zoom_step)
			current_visual_copy.global_position = inspect_anchor.global_position
			return

	elif event is InputEventMouseMotion and is_dragging:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		current_visual_copy.rotate_y(-mouse_motion.relative.x * rotate_speed)
		current_visual_copy.rotate_x(-mouse_motion.relative.y * rotate_speed)


func _process(delta: float) -> void:
	if state == InspectState.OPENING:
		transition_t = minf(transition_t + delta * transition_speed, 1.0)
		_apply_interpolated_transform(from_transform, to_transform, transition_t)

		if transition_t >= 1.0:
			state = InspectState.VIEWING

	elif state == InspectState.CLOSING:
		transition_t = minf(transition_t + delta * transition_speed, 1.0)
		_apply_interpolated_transform(from_transform, to_transform, transition_t)

		if transition_t >= 1.0:
			_finish_close()


func _apply_interpolated_transform(start_transform: Transform3D, end_transform: Transform3D, t: float) -> void:
	if current_visual_copy == null:
		return

	var start_pos: Vector3 = start_transform.origin
	var end_pos: Vector3 = end_transform.origin
	var pos: Vector3 = start_pos.lerp(end_pos, t)

	var start_quat: Quaternion = start_transform.basis.get_rotation_quaternion()
	var end_quat: Quaternion = end_transform.basis.get_rotation_quaternion()
	var rot: Quaternion = start_quat.slerp(end_quat, t)

	var start_scale: Vector3 = start_transform.basis.get_scale()
	var end_scale: Vector3 = end_transform.basis.get_scale()
	var scale: Vector3 = start_scale.lerp(end_scale, t)

	current_visual_copy.global_transform = Transform3D(Basis(rot).scaled(scale), pos)


func _get_inspect_target_transform(reference_node: Node3D) -> Transform3D:
	var target_rotation: Quaternion = inspect_anchor.global_transform.basis.get_rotation_quaternion()
	var target_scale: Vector3 = reference_node.global_transform.basis.get_scale()
	return Transform3D(Basis(target_rotation).scaled(target_scale), inspect_anchor.global_transform.origin)


func _get_inventory_spawn_transform(reference_node: Node3D) -> Transform3D:
	var cam_basis: Basis = camera.global_transform.basis
	var spawn_pos: Vector3 = camera.global_position + (-cam_basis.z * 0.22) + (cam_basis.x * 0.16) + (-cam_basis.y * 0.16)
	var target_rotation: Quaternion = inspect_anchor.global_transform.basis.get_rotation_quaternion()
	var target_scale: Vector3 = reference_node.global_transform.basis.get_scale()
	return Transform3D(Basis(target_rotation).scaled(target_scale), spawn_pos)


func _get_runtime_parent() -> Node:
	if player.get_tree().current_scene != null:
		return player.get_tree().current_scene
	return player.get_parent()


func _set_inspect_distance(new_distance: float) -> void:
	current_inspect_distance = clampf(new_distance, min_inspect_distance, max_inspect_distance)

	if inspect_anchor != null:
		inspect_anchor.position = Vector3(0.0, 0.0, -current_inspect_distance)


func _finish_close() -> void:
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

	if keep_mouse_visible_on_finish:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _force_close_immediate() -> void:
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


func _remove_old_runtime_nodes() -> void:
	var old_anchor: Node = camera.get_node_or_null("InspectAnchor")
	if old_anchor != null:
		old_anchor.queue_free()

	var old_overlay: Node = player.get_node_or_null("InspectOverlayRuntime")
	if old_overlay != null:
		old_overlay.queue_free()


func _build_inspect_anchor() -> void:
	inspect_anchor = Node3D.new()
	inspect_anchor.name = "InspectAnchor"
	camera.add_child(inspect_anchor)


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

	close_button = Button.new()
	close_button.text = "OK"
	close_button.anchor_left = 0.5
	close_button.anchor_top = 1.0
	close_button.anchor_right = 0.5
	close_button.anchor_bottom = 1.0
	close_button.offset_left = -70.0
	close_button.offset_top = -70.0
	close_button.offset_right = 70.0
	close_button.offset_bottom = -20.0
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_on_close_button_pressed)
	inspect_overlay_root.add_child(close_button)


func _on_close_button_pressed() -> void:
	var return_to_inventory: bool = inventory_ui_controller != null and inventory_ui_controller.should_return_to_inventory_after_inspect()

	close(return_to_inventory)

	if return_to_inventory and inventory_controller != null and inventory_ui_controller != null:
		inventory_ui_controller.show_inventory(inventory_controller.get_slots())
	elif inventory_ui_controller != null:
		inventory_ui_controller.close()
