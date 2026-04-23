extends Node
class_name PlayerInventoryController

const INVENTORY_SIZE: int = 6

var inventory_slots: Array[Dictionary] = []


func setup() -> void:
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


func add_item(item_id: String, item_name: String, item_description: String = "", inspect_visual_template: Node3D = null) -> bool:
	for i in range(inventory_slots.size()):
		var slot_data: Dictionary = inventory_slots[i]

		if _is_inventory_slot_empty(slot_data):
			inventory_slots[i] = {
				"id": item_id,
				"name": item_name,
				"description": item_description,
				"inspect_visual_template": inspect_visual_template
			}
			return true

	return false


func remove_item(item_id: String) -> bool:
	for i in range(inventory_slots.size()):
		var slot_data: Dictionary = inventory_slots[i]

		if str(slot_data.get("id", "")) == item_id:
			inventory_slots[i] = _create_empty_inventory_slot()
			return true

	return false


func get_slots() -> Array[Dictionary]:
	return inventory_slots


func _create_empty_inventory_slot() -> Dictionary:
	return {
		"id": "",
		"name": "",
		"description": "",
		"inspect_visual_template": null
	}


func _is_inventory_slot_empty(slot_data: Dictionary) -> bool:
	return str(slot_data.get("id", "")) == ""
