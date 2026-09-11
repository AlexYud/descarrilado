extends CharacterBody3D

@onready var movement_controller: PlayerMovementController = $MovementController
@onready var interaction_controller: PlayerInteractionController = $InteractionController
@onready var inventory_controller: PlayerInventoryController = $InventoryController
@onready var inventory_ui_controller: InventoryUIController = $InventoryUIController
@onready var audio_controller: PlayerAudioController = $AudioController
@onready var inspect_controller: PlayerInspectController = $InspectController
@onready var flashlight_controller: Node = $Hand/SpotLight3D

var dialogue_frozen: bool = false
var cutscene_frozen: bool = false
var manual_save_blocked: bool = false


func _ready() -> void:
	if not DialogueManager.player_freeze_changed.is_connected(
		_on_dialogue_freeze_changed
	):
		DialogueManager.player_freeze_changed.connect(
			_on_dialogue_freeze_changed
		)

	if audio_controller != null:
		audio_controller.setup(self)

	if movement_controller != null:
		movement_controller.setup(self, audio_controller)

	if interaction_controller != null:
		interaction_controller.setup(self)

	if inventory_controller != null:
		inventory_controller.setup()

	if inventory_ui_controller != null:
		inventory_ui_controller.setup(self)

	if inspect_controller != null:
		inspect_controller.setup(self)

	call_deferred("_restore_manual_save_state")

	if inventory_ui_controller != null:
		if not inventory_ui_controller.use_requested.is_connected(
			_on_inventory_use_requested
		):
			inventory_ui_controller.use_requested.connect(
				_on_inventory_use_requested
			)

		if not inventory_ui_controller.inspect_requested.is_connected(
			_on_inventory_inspect_requested
		):
			inventory_ui_controller.inspect_requested.connect(
				_on_inventory_inspect_requested
			)

		if inventory_controller != null:
			inventory_ui_controller.refresh(
				inventory_controller.get_slots()
			)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if cutscene_frozen:
		return

	if inspect_controller != null and inspect_controller.is_open():
		var return_to_inventory: bool = false

		if inventory_ui_controller != null:
			return_to_inventory = (
				inventory_ui_controller
				.should_return_to_inventory_after_inspect()
			)

		if event.is_action_pressed("ui_cancel"):
			inspect_controller.close(return_to_inventory)

			if inventory_ui_controller != null:
				if return_to_inventory and inventory_controller != null:
					inventory_ui_controller.show_inventory(
						inventory_controller.get_slots()
					)
				else:
					inventory_ui_controller.close()

			get_viewport().set_input_as_handled()
			return

		if (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_RIGHT
		):
			inspect_controller.close(return_to_inventory)

			if inventory_ui_controller != null:
				if return_to_inventory and inventory_controller != null:
					inventory_ui_controller.show_inventory(
						inventory_controller.get_slots()
					)
				else:
					inventory_ui_controller.close()

			return

		if event.is_action_pressed("inventory"):
			inspect_controller.close(return_to_inventory)

			if inventory_ui_controller != null:
				if return_to_inventory and inventory_controller != null:
					inventory_ui_controller.show_inventory(
						inventory_controller.get_slots()
					)
				else:
					inventory_ui_controller.close()

			return

		inspect_controller.handle_input(event)
		return

	if (
		event.is_action_pressed("ui_cancel")
		and inventory_ui_controller != null
		and inventory_ui_controller.is_inventory_open()
	):
		inventory_ui_controller.close()

		if interaction_controller != null:
			interaction_controller.clear_prompt()

		get_viewport().set_input_as_handled()
		return

	if (
		not dialogue_frozen
		and inventory_ui_controller != null
		and inventory_controller != null
		and event.is_action_pressed("inventory")
	):
		inventory_ui_controller.toggle(
			inventory_controller.get_slots()
		)

		if interaction_controller != null:
			interaction_controller.clear_prompt()

		return

	if dialogue_frozen:
		return

	var block_look: bool = false

	if (
		inventory_ui_controller != null
		and inventory_ui_controller.is_inventory_open()
	):
		block_look = true

	if inspect_controller != null and inspect_controller.is_open():
		block_look = true

	if movement_controller != null:
		movement_controller.handle_input(event, block_look)


func _physics_process(delta: float) -> void:
	var interaction_blocked: bool = cutscene_frozen

	if (
		inventory_ui_controller != null
		and inventory_ui_controller.is_inventory_open()
	):
		interaction_blocked = true

	if inspect_controller != null and inspect_controller.is_open():
		interaction_blocked = true

	var gameplay_frozen: bool = (
		dialogue_frozen
		or cutscene_frozen
	)

	if interaction_controller != null:
		interaction_controller.update_state(
			gameplay_frozen,
			interaction_blocked
		)

	var movement_frozen: bool = gameplay_frozen

	if inspect_controller != null and inspect_controller.is_open():
		movement_frozen = true

	if movement_controller != null:
		movement_controller.physics_update(
			delta,
			movement_frozen
		)

	if (
		not gameplay_frozen
		and inventory_ui_controller != null
		and not inventory_ui_controller.is_inventory_open()
		and inspect_controller != null
		and not inspect_controller.is_open()
		and Input.is_action_just_pressed("interact")
	):
		if interaction_controller != null:
			interaction_controller.try_interact(self)


func set_cutscene_frozen(is_frozen: bool) -> void:
	if cutscene_frozen == is_frozen:
		return

	cutscene_frozen = is_frozen

	if movement_controller != null:
		if cutscene_frozen:
			movement_controller.begin_cutscene_camera_control(
				Vector3.ZERO,
				Vector3.ZERO
			)
		else:
			movement_controller.end_cutscene_camera_control()

	if not cutscene_frozen:
		return

	if audio_controller != null:
		audio_controller.stop_footsteps()

	if interaction_controller != null:
		interaction_controller.clear_prompt()

	if inspect_controller != null and inspect_controller.is_open():
		inspect_controller.close(false)

		if inventory_ui_controller != null:
			inventory_ui_controller.close()

	if (
		inventory_ui_controller != null
		and inventory_ui_controller.is_inventory_open()
	):
		inventory_ui_controller.close()


func set_manual_save_blocked(blocked: bool) -> void:
	manual_save_blocked = blocked


func can_manual_save() -> bool:
	if not SaveManager.has_active_game():
		return false

	if manual_save_blocked or cutscene_frozen or dialogue_frozen:
		return false

	if DialogueManager.has_method("is_dialogue_active"):
		if DialogueManager.is_dialogue_active():
			return false

	if (
		inventory_ui_controller != null
		and inventory_ui_controller.is_inventory_open()
	):
		return false

	if inspect_controller != null and inspect_controller.is_open():
		return false

	var scene_path: String = get_current_save_scene_path()
	return (
		not scene_path.is_empty()
		and ResourceLoader.exists(scene_path, "PackedScene")
	)


func get_current_save_scene_path() -> String:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return ""

	return current_scene.scene_file_path


func get_manual_save_state() -> Dictionary:
	var inventory_data: Array[Dictionary] = []
	if inventory_controller != null:
		inventory_data = inventory_controller.get_serializable_slots()

	var movement_data: Dictionary = {}
	if movement_controller != null:
		movement_data = movement_controller.get_save_state()

	var flashlight_data: Dictionary = {}
	if (
		flashlight_controller != null
		and flashlight_controller.has_method("get_save_state")
	):
		flashlight_data = flashlight_controller.call("get_save_state")

	return {
		"position": _vector3_to_array(global_position),
		"rotation": _vector3_to_array(global_rotation),
		"movement": movement_data,
		"inventory": inventory_data,
		"flashlight": flashlight_data,
	}


func _restore_manual_save_state() -> void:
	var scene_path: String = get_current_save_scene_path()
	if scene_path.is_empty():
		return

	var save_data: Dictionary = SaveManager.get_manual_player_state(
		scene_path
	)
	if save_data.is_empty():
		return

	global_position = _array_to_vector3(
		save_data.get("position", []),
		global_position
	)
	global_rotation = _array_to_vector3(
		save_data.get("rotation", []),
		global_rotation
	)
	velocity = Vector3.ZERO

	var movement_value: Variant = save_data.get("movement", {})
	if movement_controller != null and movement_value is Dictionary:
		movement_controller.restore_save_state(
			movement_value as Dictionary
		)

	var inventory_value: Variant = save_data.get("inventory", [])
	if inventory_controller != null and inventory_value is Array:
		inventory_controller.restore_serializable_slots(
			inventory_value as Array
		)

	var flashlight_value: Variant = save_data.get("flashlight", {})
	if (
		flashlight_controller != null
		and flashlight_controller.has_method("restore_save_state")
		and flashlight_value is Dictionary
	):
		flashlight_controller.call(
			"restore_save_state",
			flashlight_value as Dictionary
		)

	if inventory_ui_controller != null and inventory_controller != null:
		inventory_ui_controller.refresh(
			inventory_controller.get_slots()
		)


func _vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_to_vector3(
	value: Variant,
	fallback: Vector3
) -> Vector3:
	if not value is Array or (value as Array).size() != 3:
		return fallback

	var components: Array = value as Array
	return Vector3(
		float(components[0]),
		float(components[1]),
		float(components[2])
	)


func _on_dialogue_freeze_changed(is_frozen: bool) -> void:
	dialogue_frozen = is_frozen

	if dialogue_frozen:
		if movement_controller != null:
			movement_controller.force_stop_immediately()

		if audio_controller != null:
			audio_controller.stop_footsteps()

		if interaction_controller != null:
			interaction_controller.clear_prompt()

		if inspect_controller != null and inspect_controller.is_open():
			inspect_controller.close(false)

			if inventory_ui_controller != null:
				inventory_ui_controller.close()

		if (
			inventory_ui_controller != null
			and inventory_ui_controller.is_inventory_open()
		):
			inventory_ui_controller.close()


func has_inventory_space() -> bool:
	if inventory_controller == null:
		return false

	return inventory_controller.has_space()


func has_inventory_item(item_id: String) -> bool:
	if inventory_controller == null:
		return false

	return inventory_controller.has_item(item_id)


func consume_inventory_item(item_id: String) -> bool:
	if inventory_controller == null:
		return false

	var removed: bool = inventory_controller.remove_item(
		item_id
	)

	if removed and inventory_ui_controller != null:
		inventory_ui_controller.refresh(
			inventory_controller.get_slots()
		)

	return removed


func is_inventory_open() -> bool:
	if inventory_ui_controller == null:
		return false

	return inventory_ui_controller.is_inventory_open()


func is_flashlight_blocked() -> bool:
	if cutscene_frozen:
		return true

	if dialogue_frozen:
		return true

	if (
		inventory_ui_controller != null
		and inventory_ui_controller.is_inventory_open()
	):
		return true

	if inspect_controller != null and inspect_controller.is_open():
		return true

	return false


func add_item_to_inventory(
	item_id: String,
	item_name: String,
	item_description: String = "",
	inspect_visual_template: Node3D = null,
	item_scene_path: String = ""
) -> bool:
	if inventory_controller == null:
		return false

	var added: bool = inventory_controller.add_item(
		item_id,
		item_name,
		item_description,
		inspect_visual_template,
		item_scene_path
	)

	if added and inventory_ui_controller != null:
		inventory_ui_controller.refresh(
			inventory_controller.get_slots()
		)

	return added


func start_world_inspect(inspectable: Inspectable) -> bool:
	if cutscene_frozen:
		return false

	if inspectable == null:
		return false

	if (
		inventory_ui_controller != null
		and inventory_ui_controller.is_inventory_open()
	):
		return false

	if interaction_controller != null:
		interaction_controller.clear_prompt()

	if inspect_controller == null:
		return false

	if movement_controller != null:
		movement_controller.force_stop_immediately()

	var opened: bool = inspect_controller.open_world(
		inspectable
	)

	if opened and inventory_ui_controller != null:
		inventory_ui_controller.show_inspect(
			inspectable.get_inspect_data(),
			false
		)

	return opened


func _on_inventory_use_requested(
	_slot_data: Dictionary
) -> void:
	pass


func _on_inventory_inspect_requested(
	slot_data: Dictionary
) -> void:
	if cutscene_frozen:
		return

	if inspect_controller == null:
		return

	if movement_controller != null:
		movement_controller.force_stop_immediately()

	var opened: bool = inspect_controller.open_inventory(
		slot_data
	)

	if opened and inventory_ui_controller != null:
		inventory_ui_controller.show_inspect(
			slot_data,
			true
		)
