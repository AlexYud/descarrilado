extends Node
class_name PlayerInventoryController

const INVENTORY_SIZE: int = 6
const ITEM_SCENE_PATHS := {
	"cellphone": "res://scenes/objects/cellphone.tscn",
	"flashlight": "res://scenes/objects/flashlight.tscn",
}

var inventory_slots: Array[Dictionary] = []


func setup() -> void:
	_free_inspect_visuals()
	inventory_slots.clear()

	for i in range(INVENTORY_SIZE):
		inventory_slots.append(_create_empty_inventory_slot())


func has_space() -> bool:
	for slot_data: Dictionary in inventory_slots:
		if _is_inventory_slot_empty(slot_data):
			return true

	return false


func has_item(item_id: String) -> bool:
	for slot_data: Dictionary in inventory_slots:
		if str(slot_data.get("id", "")) == item_id:
			return true

	return false


func add_item(
	item_id: String,
	item_name: String,
	item_description: String = "",
	inspect_visual_template: Node3D = null,
	item_scene_path: String = ""
) -> bool:
	for i in range(inventory_slots.size()):
		var slot_data: Dictionary = inventory_slots[i]

		if _is_inventory_slot_empty(slot_data):
			inventory_slots[i] = {
				"id": item_id,
				"name": item_name,
				"description": item_description,
				"inspect_visual_template": inspect_visual_template,
				"item_scene_path": item_scene_path,
			}
			return true

	return false


func remove_item(item_id: String) -> bool:
	for i in range(inventory_slots.size()):
		var slot_data: Dictionary = inventory_slots[i]

		if str(slot_data.get("id", "")) == item_id:
			_free_slot_inspect_visual(slot_data)
			inventory_slots[i] = _create_empty_inventory_slot()
			return true

	return false


func get_slots() -> Array[Dictionary]:
	return inventory_slots


func get_serializable_slots() -> Array[Dictionary]:
	var serialized_slots: Array[Dictionary] = []

	for slot_data: Dictionary in inventory_slots:
		serialized_slots.append({
			"id": str(slot_data.get("id", "")),
			"name": str(slot_data.get("name", "")),
			"description": str(slot_data.get("description", "")),
			"item_scene_path": str(
				slot_data.get("item_scene_path", "")
			),
		})

	return serialized_slots


func restore_serializable_slots(saved_slots: Array) -> void:
	setup()

	var slot_count: int = mini(saved_slots.size(), INVENTORY_SIZE)
	for index: int in range(slot_count):
		var saved_value: Variant = saved_slots[index]
		if not saved_value is Dictionary:
			continue

		var saved_slot: Dictionary = saved_value as Dictionary
		var item_id: String = str(saved_slot.get("id", ""))
		if item_id.is_empty():
			continue

		var item_scene_path: String = str(
			saved_slot.get("item_scene_path", "")
		)
		if item_scene_path.is_empty():
			item_scene_path = str(ITEM_SCENE_PATHS.get(item_id, ""))

		inventory_slots[index] = {
			"id": item_id,
			"name": str(saved_slot.get("name", "")),
			"description": str(saved_slot.get("description", "")),
			"inspect_visual_template": _create_inspect_visual(
				item_scene_path
			),
			"item_scene_path": item_scene_path,
		}


func _create_empty_inventory_slot() -> Dictionary:
	return {
		"id": "",
		"name": "",
		"description": "",
		"inspect_visual_template": null,
		"item_scene_path": "",
	}


func _is_inventory_slot_empty(slot_data: Dictionary) -> bool:
	return str(slot_data.get("id", "")) == ""


func _create_inspect_visual(item_scene_path: String) -> Node3D:
	if (
		item_scene_path.is_empty()
		or not ResourceLoader.exists(item_scene_path, "PackedScene")
	):
		return null

	var item_scene: PackedScene = load(item_scene_path) as PackedScene
	if item_scene == null:
		return null

	var item_root: Node = item_scene.instantiate()
	var source_visual: Node3D = item_root.get_node_or_null(
		"Visual"
	) as Node3D
	var inspect_visual: Node3D = null
	if source_visual != null:
		inspect_visual = source_visual.duplicate() as Node3D

	item_root.free()
	return inspect_visual


func _free_inspect_visuals() -> void:
	for slot_data: Dictionary in inventory_slots:
		_free_slot_inspect_visual(slot_data)


func _free_slot_inspect_visual(slot_data: Dictionary) -> void:
	var visual: Node3D = slot_data.get(
		"inspect_visual_template"
	) as Node3D
	if visual != null and is_instance_valid(visual):
		visual.free()


func _exit_tree() -> void:
	_free_inspect_visuals()
