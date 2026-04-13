extends Interactable
class_name Inspectable

@export var inspect_name: String = "Inspectable Item"
@export_multiline var inspect_description: String = ""


func get_visual_node() -> Node3D:
	return get_node_or_null("Visual") as Node3D


func get_inspect_data() -> Dictionary:
	return {
		"name": inspect_name,
		"description": inspect_description
	}


func interact(player: Node) -> void:
	if player == null:
		return

	if player.has_method("start_world_inspect"):
		player.call("start_world_inspect", self)
