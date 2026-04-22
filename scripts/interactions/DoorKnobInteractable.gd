extends Interactable
class_name DoorKnobInteractable

@export var door_controller: DoorController


func _ready() -> void:
	if door_controller == null:
		door_controller = _find_door_controller()


func can_interact(_player: Node) -> bool:
	return door_controller != null and door_controller.is_usable()


func get_prompt_text() -> String:
	if door_controller == null:
		return ""

	return door_controller.get_prompt_text()


func interact(player: Node) -> void:
	if door_controller != null:
		door_controller.interact(player)


func _find_door_controller() -> DoorController:
	var current: Node = get_parent()

	while current != null:
		if current is DoorController:
			return current as DoorController
		current = current.get_parent()

	return null
