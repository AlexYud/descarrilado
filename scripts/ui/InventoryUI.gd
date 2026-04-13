extends Node
class_name InventoryUIController

signal use_requested(slot_data: Dictionary)
signal inspect_requested(slot_data: Dictionary)

var player: Node = null

var inventory_open: bool = false
var inventory_slot_buttons: Array[Button] = []
var current_slots: Array[Dictionary] = []
var selected_slot_index: int = -1
var inspect_return_to_inventory: bool = false

var inventory_ui_layer: CanvasLayer = null
var inventory_root: Control = null
var inventory_panel: PanelContainer = null

var header_label: Label = null
var inventory_content: VBoxContainer = null
var inspect_content: VBoxContainer = null
var action_popup: PanelContainer = null
var use_button: Button = null
var inspect_button: Button = null
var inspect_title_label: Label = null
var inspect_description_label: RichTextLabel = null
var inspect_hint_label: Label = null


func setup(player_node: Node) -> void:
	player = player_node
	_remove_existing_runtime_ui()
	_build_inventory_ui()
	close()


func is_inventory_open() -> bool:
	return inventory_open


func should_return_to_inventory_after_inspect() -> bool:
	return inspect_return_to_inventory


func toggle(slots: Array[Dictionary]) -> void:
	if inventory_open:
		close()
	else:
		show_inventory(slots)


func show_inventory(slots: Array[Dictionary]) -> void:
	inventory_open = true
	inspect_return_to_inventory = false
	current_slots = slots
	selected_slot_index = -1

	if inventory_ui_layer != null:
		inventory_ui_layer.visible = true

	if inventory_root != null:
		inventory_root.visible = true

	if header_label != null:
		header_label.text = "Inventory"

	if inventory_content != null:
		inventory_content.visible = true

	if inspect_content != null:
		inspect_content.visible = false

	if action_popup != null:
		action_popup.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh(slots)


func show_inspect(slot_data: Dictionary, from_inventory: bool) -> void:
	inventory_open = from_inventory
	inspect_return_to_inventory = from_inventory

	if inventory_ui_layer != null:
		inventory_ui_layer.visible = true

	if inventory_root != null:
		inventory_root.visible = true

	if header_label != null:
		header_label.text = "Inspect"

	if inventory_content != null:
		inventory_content.visible = false

	if inspect_content != null:
		inspect_content.visible = true

	if action_popup != null:
		action_popup.visible = false

	if inspect_title_label != null:
		inspect_title_label.text = str(slot_data.get("name", ""))

	if inspect_description_label != null:
		inspect_description_label.text = str(slot_data.get("description", ""))

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	inventory_open = false
	selected_slot_index = -1
	inspect_return_to_inventory = false

	if inventory_ui_layer != null:
		inventory_ui_layer.visible = false

	if inventory_root != null:
		inventory_root.visible = false

	if action_popup != null:
		action_popup.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func refresh(slots: Array[Dictionary]) -> void:
	current_slots = slots

	if inventory_slot_buttons.is_empty():
		return

	for i in range(inventory_slot_buttons.size()):
		var slot_data: Dictionary = slots[i]
		var item_name: String = str(slot_data.get("name", ""))

		if item_name == "":
			inventory_slot_buttons[i].text = "Slot %d\nEmpty" % (i + 1)
		else:
			inventory_slot_buttons[i].text = "Slot %d\n%s" % [i + 1, item_name]


func _remove_existing_runtime_ui() -> void:
	var old_inventory_ui_runtime: Node = player.get_node_or_null("InventoryUIRuntime")
	if old_inventory_ui_runtime != null:
		old_inventory_ui_runtime.queue_free()

	var old_inventory_root: Node = player.get_node_or_null("InventoryRoot")
	if old_inventory_root != null:
		old_inventory_root.queue_free()

	inventory_slot_buttons.clear()
	inventory_ui_layer = null
	inventory_root = null
	inventory_panel = null


func _build_inventory_ui() -> void:
	inventory_slot_buttons.clear()

	inventory_ui_layer = CanvasLayer.new()
	inventory_ui_layer.name = "InventoryUIRuntime"
	inventory_ui_layer.layer = 10
	player.add_child(inventory_ui_layer)

	inventory_root = Control.new()
	inventory_root.name = "InventoryRoot"
	inventory_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_root.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_ui_layer.add_child(inventory_root)

	inventory_panel = PanelContainer.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.anchor_left = 1.0
	inventory_panel.anchor_top = 0.0
	inventory_panel.anchor_right = 1.0
	inventory_panel.anchor_bottom = 1.0
	inventory_panel.offset_left = -400.0
	inventory_panel.offset_top = 0.0
	inventory_panel.offset_right = 0.0
	inventory_panel.offset_bottom = 0.0
	inventory_root.add_child(inventory_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 20.0
	margin.offset_top = 20.0
	margin.offset_right = -20.0
	margin.offset_bottom = -20.0
	inventory_panel.add_child(margin)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 18)
	margin.add_child(main_vbox)

	header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.text = "Inventory"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.custom_minimum_size = Vector2(0.0, 40.0)
	main_vbox.add_child(header_label)

	inventory_content = VBoxContainer.new()
	inventory_content.name = "InventoryContent"
	inventory_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_theme_constant_override("separation", 16)
	main_vbox.add_child(inventory_content)

	var grid_center: CenterContainer = CenterContainer.new()
	grid_center.name = "GridCenter"
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_child(grid_center)

	var slots_grid: GridContainer = GridContainer.new()
	slots_grid.name = "Slots"
	slots_grid.columns = 2
	slots_grid.add_theme_constant_override("h_separation", 14)
	slots_grid.add_theme_constant_override("v_separation", 14)
	grid_center.add_child(slots_grid)

	for i in range(6):
		var slot_button: Button = Button.new()
		slot_button.name = "Slot%d" % (i + 1)
		slot_button.custom_minimum_size = Vector2(150.0, 124.0)
		slot_button.text = "Slot %d\nEmpty" % (i + 1)
		slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_button.pressed.connect(_on_slot_button_pressed.bind(i))
		slots_grid.add_child(slot_button)

		inventory_slot_buttons.append(slot_button)

	inspect_content = VBoxContainer.new()
	inspect_content.name = "InspectContent"
	inspect_content.visible = false
	inspect_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(inspect_content)

	var inspect_margin: MarginContainer = MarginContainer.new()
	inspect_margin.name = "InspectMargin"
	inspect_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspect_margin.add_theme_constant_override("margin_left", 10)
	inspect_margin.add_theme_constant_override("margin_top", 8)
	inspect_margin.add_theme_constant_override("margin_right", 10)
	inspect_margin.add_theme_constant_override("margin_bottom", 8)
	inspect_content.add_child(inspect_margin)

	var inspect_vbox: VBoxContainer = VBoxContainer.new()
	inspect_vbox.name = "InspectVBox"
	inspect_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspect_vbox.add_theme_constant_override("separation", 14)
	inspect_margin.add_child(inspect_vbox)

	inspect_title_label = Label.new()
	inspect_title_label.name = "InspectTitleLabel"
	inspect_title_label.text = ""
	inspect_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_title_label.custom_minimum_size = Vector2(0.0, 50.0)
	inspect_vbox.add_child(inspect_title_label)

	inspect_description_label = RichTextLabel.new()
	inspect_description_label.name = "InspectDescriptionLabel"
	inspect_description_label.bbcode_enabled = false
	inspect_description_label.fit_content = false
	inspect_description_label.scroll_active = true
	inspect_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspect_vbox.add_child(inspect_description_label)

	inspect_hint_label = Label.new()
	inspect_hint_label.name = "InspectHintLabel"
	inspect_hint_label.text = "Left drag: rotate    Wheel: zoom    Right click: back"
	inspect_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_vbox.add_child(inspect_hint_label)

	action_popup = PanelContainer.new()
	action_popup.name = "ActionPopup"
	action_popup.visible = false
	action_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_root.add_child(action_popup)

	var popup_margin: MarginContainer = MarginContainer.new()
	popup_margin.offset_left = 8.0
	popup_margin.offset_top = 8.0
	popup_margin.offset_right = 8.0
	popup_margin.offset_bottom = 8.0
	action_popup.add_child(popup_margin)

	var popup_vbox: VBoxContainer = VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", 8)
	popup_margin.add_child(popup_vbox)

	use_button = Button.new()
	use_button.text = "Use"
	use_button.custom_minimum_size = Vector2(110.0, 38.0)
	use_button.pressed.connect(_on_use_button_pressed)
	popup_vbox.add_child(use_button)

	inspect_button = Button.new()
	inspect_button.text = "Inspect"
	inspect_button.custom_minimum_size = Vector2(110.0, 38.0)
	inspect_button.pressed.connect(_on_inspect_button_pressed)
	popup_vbox.add_child(inspect_button)


func _on_slot_button_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= current_slots.size():
		return

	var slot_data: Dictionary = current_slots[slot_index]
	var item_id: String = str(slot_data.get("id", ""))

	if item_id == "":
		selected_slot_index = -1
		if action_popup != null:
			action_popup.visible = false
		return

	selected_slot_index = slot_index
	_show_action_popup()


func _show_action_popup() -> void:
	if action_popup == null:
		return

	var mouse_pos: Vector2 = player.get_viewport().get_mouse_position()
	action_popup.position = mouse_pos + Vector2(12.0, 12.0)
	action_popup.visible = true


func _on_use_button_pressed() -> void:
	if selected_slot_index < 0 or selected_slot_index >= current_slots.size():
		return

	if action_popup != null:
		action_popup.visible = false

	use_requested.emit(current_slots[selected_slot_index])


func _on_inspect_button_pressed() -> void:
	if selected_slot_index < 0 or selected_slot_index >= current_slots.size():
		return

	if action_popup != null:
		action_popup.visible = false

	inspect_requested.emit(current_slots[selected_slot_index])
