extends Node3D
class_name DoorController

@export var hinge: Node3D
@export var door_root: Node3D

@export var open_angle_degrees: float = 70.0
@export var rotate_speed: float = 0.70
@export var starts_open: bool = false
@export var starts_locked: bool = false
@export var required_key_id: String = ""
@export var persistent_id: StringName = &""

@export var closed_prompt_text: String = "PROMPT_OPEN"
@export var opened_prompt_text: String = "PROMPT_CLOSE"
@export var locked_prompt_text: String = "PROMPT_LOCKED"
@export var unlock_prompt_text: String = "PROMPT_UNLOCK"

var is_open: bool = false
var is_locked: bool = false

var closed_rotation_degrees: Vector3 = Vector3.ZERO
var current_open_rotation_degrees: Vector3 = Vector3.ZERO


func _ready() -> void:
	if hinge == null:
		hinge = get_node_or_null("Hinge") as Node3D

	if door_root == null:
		door_root = get_node_or_null("Hinge/DoorRoot") as Node3D

	if hinge == null or door_root == null:
		push_warning("DoorController: hinge or door_root is not assigned.")
		set_process(false)
		return

	closed_rotation_degrees = hinge.rotation_degrees
	current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, absf(open_angle_degrees), 0.0)

	is_locked = starts_locked
	is_open = starts_open and not is_locked

	if is_open:
		hinge.rotation_degrees = current_open_rotation_degrees
	else:
		hinge.rotation_degrees = closed_rotation_degrees

	_restore_persistent_state()


func _process(delta: float) -> void:
	if hinge == null:
		return

	var target_rotation: Vector3 = closed_rotation_degrees
	if is_open:
		target_rotation = current_open_rotation_degrees

	var weight: float = clamp(delta * rotate_speed, 0.0, 1.0)
	hinge.rotation_degrees = hinge.rotation_degrees.lerp(target_rotation, weight)

	if hinge.rotation_degrees.distance_squared_to(target_rotation) < 0.000001:
		hinge.rotation_degrees = target_rotation


func is_usable() -> bool:
	return hinge != null and door_root != null


func get_prompt_text() -> String:
	if is_locked:
		return locked_prompt_text

	if is_open:
		return opened_prompt_text

	return closed_prompt_text


func get_prompt_text_for_player(player: Node) -> String:
	if is_locked:
		if _player_can_unlock(player):
			return unlock_prompt_text
		return locked_prompt_text

	if is_open:
		return opened_prompt_text

	return closed_prompt_text


func interact(player: Node) -> void:
	if is_locked:
		var unlocked: bool = _try_unlock_with_player(player)
		if not unlocked:
			return

	if not is_open:
		_choose_open_side(player)

	is_open = not is_open
	_remember_persistent_state()


func unlock() -> void:
	is_locked = false
	_remember_persistent_state()


func lock() -> void:
	is_locked = true
	is_open = false
	_remember_persistent_state()


func _restore_persistent_state() -> void:
	if persistent_id.is_empty():
		return

	var saved_value: Variant = SaveManager.get_state_value(
		&"doors",
		persistent_id,
		{}
	)
	if not saved_value is Dictionary:
		return

	var saved_state: Dictionary = saved_value as Dictionary
	if saved_state.is_empty():
		return

	is_locked = bool(saved_state.get("is_locked", is_locked))
	is_open = (
		bool(saved_state.get("is_open", is_open))
		and not is_locked
	)
	var signed_open_angle: float = float(saved_state.get(
		"signed_open_angle_degrees",
		absf(open_angle_degrees)
	))
	current_open_rotation_degrees = (
		closed_rotation_degrees
		+ Vector3(0.0, signed_open_angle, 0.0)
	)
	hinge.rotation_degrees = (
		current_open_rotation_degrees
		if is_open
		else closed_rotation_degrees
	)


func _remember_persistent_state() -> void:
	if persistent_id.is_empty() or not SaveManager.has_active_game():
		return

	SaveManager.set_state_value(
		&"doors",
		persistent_id,
		{
			"is_open": is_open,
			"is_locked": is_locked,
			"signed_open_angle_degrees": (
				current_open_rotation_degrees.y
				- closed_rotation_degrees.y
			),
		}
	)


func _try_unlock_with_player(player: Node) -> bool:
	if not is_locked:
		return true

	if required_key_id == "":
		return false

	if not _player_has_required_key(player):
		return false

	if not _consume_required_key(player):
		return false

	unlock()
	return true


func _player_can_unlock(player: Node) -> bool:
	if not is_locked:
		return false

	if required_key_id == "":
		return false

	return _player_has_required_key(player)


func _player_has_required_key(player: Node) -> bool:
	if player == null:
		return false

	if not player.has_method("has_inventory_item"):
		return false

	return bool(player.call("has_inventory_item", required_key_id))


func _consume_required_key(player: Node) -> bool:
	if player == null:
		return false

	if not player.has_method("consume_inventory_item"):
		return false

	return bool(player.call("consume_inventory_item", required_key_id))


func _choose_open_side(player: Node) -> void:
	var angle_magnitude: float = absf(open_angle_degrees)

	if hinge == null or door_root == null:
		current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, angle_magnitude, 0.0)
		return

	if not (player is Node3D):
		current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, angle_magnitude, 0.0)
		return

	var player_node: Node3D = player as Node3D
	var player_position: Vector3 = player_node.global_position

	var positive_local_center: Vector3 = door_root.position.rotated(Vector3.UP, deg_to_rad(angle_magnitude))
	var negative_local_center: Vector3 = door_root.position.rotated(Vector3.UP, deg_to_rad(-angle_magnitude))

	var positive_global_center: Vector3 = hinge.to_global(positive_local_center)
	var negative_global_center: Vector3 = hinge.to_global(negative_local_center)

	var positive_distance_sq: float = player_position.distance_squared_to(positive_global_center)
	var negative_distance_sq: float = player_position.distance_squared_to(negative_global_center)

	if positive_distance_sq >= negative_distance_sq:
		current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, angle_magnitude, 0.0)
	else:
		current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, -angle_magnitude, 0.0)
