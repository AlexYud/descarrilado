extends Interactable
class_name DoorKnobInteractable

@export var door_controller: DoorController

var cached_prompt_text: String = "[E] Interact"


func _ready() -> void:
	if door_controller == null:
		door_controller = _find_door_controller()


func can_interact(player: Node) -> bool:
	if door_controller == null or not door_controller.is_usable():
		cached_prompt_text = prompt_text
		return false

	cached_prompt_text = door_controller.get_prompt_text_for_player(player)
	return true


func get_prompt_text() -> String:
	return cached_prompt_text


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
