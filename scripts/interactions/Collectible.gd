extends Interactable
class_name Collectible

@export var item_id: String = "item"
@export var item_name: String = "New Item"
@export_multiline var item_description: String = ""
@export var pickup_prompt_text: String = "[E] Pick up"


func can_interact(player: Node) -> bool:
	if player == null:
		return false

	if player.has_method("has_inventory_space"):
		return bool(player.call("has_inventory_space"))

	return true


func get_prompt_text() -> String:
	return pickup_prompt_text


func interact(player: Node) -> void:
	if player == null:
		return

	var inspect_visual_template: Node3D = null
	var visual: Node3D = get_node_or_null("Visual") as Node3D

	if visual != null:
		inspect_visual_template = visual.duplicate() as Node3D

	if player.has_method("add_item_to_inventory"):
		var added: bool = bool(player.call("add_item_to_inventory", item_id, item_name, item_description, inspect_visual_template))

		if added:
			queue_free()
		elif inspect_visual_template != null:
			inspect_visual_template.free()
