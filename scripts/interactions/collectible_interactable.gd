extends Interactable
class_name Collectible

@export var item_id: String = "item"
@export var item_name: String = "ITEM_GENERIC_NEW"
@export_multiline var item_description: String = ""
@export var pickup_prompt_text: String = "PROMPT_PICK_UP"


func _ready() -> void:
	if SaveManager.get_state_value(
		&"collectibles",
		StringName(item_id),
		false
	):
		queue_free()


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
		var added: bool = bool(player.call(
			"add_item_to_inventory",
			item_id,
			item_name,
			item_description,
			inspect_visual_template,
			scene_file_path
		))

		if added:
			SaveManager.set_state_value(
				&"collectibles",
				StringName(item_id),
				true
			)

			# Show what was taken, flying in from where it lay.
			if player.has_method("show_pickup_inspect"):
				var start_transform: Transform3D = (
					visual.global_transform
					if visual != null
					else global_transform
				)
				player.call(
					"show_pickup_inspect",
					item_id,
					start_transform
				)

			queue_free()
		elif inspect_visual_template != null:
			inspect_visual_template.free()
