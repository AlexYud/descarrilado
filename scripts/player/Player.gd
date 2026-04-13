extends CharacterBody3D

@onready var movement_controller: PlayerMovementController = $MovementController
@onready var interaction_controller: PlayerInteractionController = $InteractionController
@onready var inventory_controller: PlayerInventoryController = $InventoryController
@onready var inventory_ui_controller: InventoryUIController = $InventoryUIController
@onready var audio_controller: PlayerAudioController = $AudioController
@onready var inspect_controller: PlayerInspectController = $InspectController

var dialogue_frozen: bool = false


func _ready() -> void:
	if not DialogueManager.player_freeze_changed.is_connected(_on_dialogue_freeze_changed):
		DialogueManager.player_freeze_changed.connect(_on_dialogue_freeze_changed)

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

	if inventory_ui_controller != null:
		if not inventory_ui_controller.use_requested.is_connected(_on_inventory_use_requested):
			inventory_ui_controller.use_requested.connect(_on_inventory_use_requested)

		if not inventory_ui_controller.inspect_requested.is_connected(_on_inventory_inspect_requested):
			inventory_ui_controller.inspect_requested.connect(_on_inventory_inspect_requested)

		if inventory_controller != null:
			inventory_ui_controller.refresh(inventory_controller.get_slots())

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if inspect_controller != null and inspect_controller.is_open():
		var return_to_inventory: bool = false
		if inventory_ui_controller != null:
			return_to_inventory = inventory_ui_controller.should_return_to_inventory_after_inspect()

		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			inspect_controller.close(return_to_inventory)
			if inventory_ui_controller != null:
				if return_to_inventory and inventory_controller != null:
					inventory_ui_controller.show_inventory(inventory_controller.get_slots())
				else:
					inventory_ui_controller.close()
			return

		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			inspect_controller.close(return_to_inventory)
			if inventory_ui_controller != null:
				if return_to_inventory and inventory_controller != null:
					inventory_ui_controller.show_inventory(inventory_controller.get_slots())
				else:
					inventory_ui_controller.close()
			return

		if event.is_action_pressed("inventory"):
			inspect_controller.close(return_to_inventory)
			if inventory_ui_controller != null:
				if return_to_inventory and inventory_controller != null:
					inventory_ui_controller.show_inventory(inventory_controller.get_slots())
				else:
					inventory_ui_controller.close()
			return

		inspect_controller.handle_input(event)
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
		return

	if not dialogue_frozen and inventory_ui_controller != null and inventory_controller != null and event.is_action_pressed("inventory"):
		inventory_ui_controller.toggle(inventory_controller.get_slots())
		if interaction_controller != null:
			interaction_controller.clear_prompt()
		return

	if dialogue_frozen:
		return

	var block_look: bool = false
	if inventory_ui_controller != null and inventory_ui_controller.is_inventory_open():
		block_look = true
	if inspect_controller != null and inspect_controller.is_open():
		block_look = true

	if movement_controller != null:
		movement_controller.handle_input(event, block_look)


func _physics_process(delta: float) -> void:
	var interaction_blocked: bool = false
	if inventory_ui_controller != null and inventory_ui_controller.is_inventory_open():
		interaction_blocked = true
	if inspect_controller != null and inspect_controller.is_open():
		interaction_blocked = true

	if interaction_controller != null:
		interaction_controller.update_state(dialogue_frozen, interaction_blocked)

	var movement_frozen: bool = dialogue_frozen
	if inspect_controller != null and inspect_controller.is_open():
		movement_frozen = true

	if movement_controller != null:
		movement_controller.physics_update(delta, movement_frozen)

	if not dialogue_frozen \
	and inventory_ui_controller != null \
	and not inventory_ui_controller.is_inventory_open() \
	and inspect_controller != null \
	and not inspect_controller.is_open() \
	and Input.is_action_just_pressed("interact"):
		if interaction_controller != null:
			interaction_controller.try_interact(self)


func _on_dialogue_freeze_changed(is_frozen: bool) -> void:
	dialogue_frozen = is_frozen

	if dialogue_frozen:
		if audio_controller != null:
			audio_controller.stop_footsteps()

		if interaction_controller != null:
			interaction_controller.clear_prompt()

		if inspect_controller != null and inspect_controller.is_open():
			inspect_controller.close(false)
			if inventory_ui_controller != null:
				inventory_ui_controller.close()

		if inventory_ui_controller != null and inventory_ui_controller.is_inventory_open():
			inventory_ui_controller.close()


func has_inventory_space() -> bool:
	if inventory_controller == null:
		return false

	return inventory_controller.has_space()


func has_inventory_item(item_id: String) -> bool:
	if inventory_controller == null:
		return false

	return inventory_controller.has_item(item_id)


func is_inventory_open() -> bool:
	if inventory_ui_controller == null:
		return false

	return inventory_ui_controller.is_inventory_open()


func is_flashlight_blocked() -> bool:
	if dialogue_frozen:
		return true

	if inventory_ui_controller != null and inventory_ui_controller.is_inventory_open():
		return true

	if inspect_controller != null and inspect_controller.is_open():
		return true

	return false


func add_item_to_inventory(item_id: String, item_name: String, item_description: String = "", inspect_visual_template: Node3D = null) -> bool:
	if inventory_controller == null:
		return false

	var added: bool = inventory_controller.add_item(item_id, item_name, item_description, inspect_visual_template)

	if added and inventory_ui_controller != null:
		inventory_ui_controller.refresh(inventory_controller.get_slots())

	return added


func start_world_inspect(inspectable: Inspectable) -> bool:
	if inspectable == null:
		return false

	if inventory_ui_controller != null and inventory_ui_controller.is_inventory_open():
		return false

	if interaction_controller != null:
		interaction_controller.clear_prompt()

	if inspect_controller == null:
		return false

	var opened: bool = inspect_controller.open_world(inspectable)
	if opened and inventory_ui_controller != null:
		inventory_ui_controller.show_inspect(inspectable.get_inspect_data(), false)

	return opened


func _on_inventory_use_requested(_slot_data: Dictionary) -> void:
	pass


func _on_inventory_inspect_requested(slot_data: Dictionary) -> void:
	if inspect_controller == null:
		return

	var opened: bool = inspect_controller.open_inventory(slot_data)

	if opened and inventory_ui_controller != null:
		inventory_ui_controller.show_inspect(slot_data, true)
