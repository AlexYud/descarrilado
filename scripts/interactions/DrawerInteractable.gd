extends Interactable
class_name DrawerInteractable

@export var drawer_root: Node3D
@export var open_offset: Vector3 = Vector3(0.0, 0.0, -0.4)
@export var move_speed: float = 6.0
@export var starts_open: bool = false

@export var closed_prompt_text: String = "[E] Open"
@export var opened_prompt_text: String = "[E] Close"

var is_open: bool = false
var closed_local_position: Vector3 = Vector3.ZERO
var open_local_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	if drawer_root == null:
		drawer_root = get_node_or_null("DrawerRoot") as Node3D

	if drawer_root == null:
		push_warning("DrawerInteractable: drawer_root is not assigned.")
		set_process(false)
		return

	closed_local_position = drawer_root.position
	open_local_position = closed_local_position + open_offset

	is_open = starts_open

	if is_open:
		drawer_root.position = open_local_position
	else:
		drawer_root.position = closed_local_position


func _process(delta: float) -> void:
	if drawer_root == null:
		return

	var target_position: Vector3 = closed_local_position
	if is_open:
		target_position = open_local_position

	var weight: float = clamp(delta * move_speed, 0.0, 1.0)
	drawer_root.position = drawer_root.position.lerp(target_position, weight)

	if drawer_root.position.distance_squared_to(target_position) < 0.000001:
		drawer_root.position = target_position


func can_interact(_player: Node) -> bool:
	return drawer_root != null


func get_prompt_text() -> String:
	if is_open:
		return opened_prompt_text
	return closed_prompt_text


func interact(_player: Node) -> void:
	is_open = not is_open
