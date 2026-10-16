extends Node
class_name InventoryUIController

signal inspect_requested(slot_data: Dictionary)

var player: Node = null

var inventory_open: bool = false
## Height of a row of the list (two lines of a long name fit).
const ROW_HEIGHT: float = 48.0
const DESCRIPTION_HEIGHT: float = 120.0

## One row per item carried (see `refresh`).
var inventory_slot_buttons: Array[Button] = []
var item_list: VBoxContainer = null
var empty_label: Label = null
var description_label: Label = null
var current_slots: Array[Dictionary] = []
var current_inspect_data: Dictionary = {}
var inspect_return_to_inventory: bool = false


var inventory_ui_layer: CanvasLayer = null
var inventory_root: Control = null
var inventory_panel: PanelContainer = null

var header_label: Label = null
var inventory_content: VBoxContainer = null
var inspect_content: VBoxContainer = null
var inspect_title_label: Label = null
var inspect_description_label: RichTextLabel = null
var inspect_hint_label: Label = null


func setup(player_node: Node) -> void:
	player = player_node
	_connect_language_settings()
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

	if inventory_ui_layer != null:
		inventory_ui_layer.visible = true

	if inventory_root != null:
		inventory_root.visible = true

	if header_label != null:
		header_label.text = tr("INVENTORY_TITLE")

	if inventory_content != null:
		inventory_content.visible = true

	if inspect_content != null:
		inspect_content.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh(slots)
	_focus_first_item.call_deferred()


## The state of looking at an item (the inventory is closed, or comes back when the
## item is put away). The item's name, description and hints are drawn by the
## inspect view itself, over the item, so nothing else is shown here.
func show_inspect(slot_data: Dictionary, from_inventory: bool) -> void:
	inventory_open = from_inventory
	inspect_return_to_inventory = from_inventory
	current_inspect_data = slot_data

	if inventory_ui_layer != null:
		inventory_ui_layer.visible = true

	if inventory_root != null:
		inventory_root.visible = false

	if header_label != null:
		header_label.text = tr("INVENTORY_INSPECT")

	if inventory_content != null:
		inventory_content.visible = false

	if inspect_content != null:
		inspect_content.visible = true

	if inspect_title_label != null:
		inspect_title_label.text = tr(
			str(slot_data.get("name", ""))
		)

	if inspect_description_label != null:
		inspect_description_label.text = tr(
			str(slot_data.get("description", ""))
		)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	inventory_open = false
	inspect_return_to_inventory = false
	current_inspect_data = {}

	if inventory_ui_layer != null:
		inventory_ui_layer.visible = false

	if inventory_root != null:
		inventory_root.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Rebuilds the list: one row per item carried, in the order they were picked up. There is no
## limit; a long list scrolls. The row under the pointer or the keyboard (one cursor, see
## ThemeManager) shows its description under the list.
func refresh(slots: Array[Dictionary]) -> void:
	current_slots = slots

	if item_list == null:
		return

	for row: Button in inventory_slot_buttons:
		item_list.remove_child(row)
		row.free()

	inventory_slot_buttons.clear()

	var shown: int = 0
	for i in range(slots.size()):
		var slot_data: Dictionary = slots[i]
		if str(slot_data.get("id", "")).is_empty():
			continue

		var row: Button = Button.new()
		row.name = "Item%d" % (shown + 1)
		row.text = tr(str(slot_data.get("name", "")))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.clip_text = false
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		row.set_meta(&"slot_index", i)
		row.pressed.connect(_on_slot_button_pressed.bind(i))
		row.focus_entered.connect(_show_description.bind(i))
		item_list.add_child(row)
		inventory_slot_buttons.append(row)
		shown += 1

	if empty_label != null:
		empty_label.visible = shown == 0
		empty_label.text = tr("INVENTORY_EMPTY")

	_show_description(-1)


func _show_description(slot_index: int) -> void:
	if description_label == null:
		return

	if slot_index < 0 or slot_index >= current_slots.size():
		description_label.text = ""
		return

	description_label.text = tr(str(current_slots[slot_index].get("description", "")))


## The keyboard cursor starts on the first item, so Up/Down work at once.
func _focus_first_item() -> void:
	if not inventory_slot_buttons.is_empty() and inventory_open:
		inventory_slot_buttons[0].grab_focus()


func _remove_existing_runtime_ui() -> void:
	var old_inventory_ui_runtime: Node = player.get_node_or_null("InventoryUIRuntime")
	if old_inventory_ui_runtime != null:
		old_inventory_ui_runtime.queue_free()

	var old_inventory_root: Node = player.get_node_or_null("InventoryRoot")
	if old_inventory_root != null:
		old_inventory_root.queue_free()

	inventory_slot_buttons.clear()
	item_list = null
	empty_label = null
	description_label = null
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
	header_label.text = tr("INVENTORY_TITLE")
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.custom_minimum_size = Vector2(0.0, 40.0)
	main_vbox.add_child(header_label)

	inventory_content = VBoxContainer.new()
	inventory_content.name = "InventoryContent"
	inventory_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_theme_constant_override("separation", 16)
	main_vbox.add_child(inventory_content)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	inventory_content.add_child(scroll)

	item_list = VBoxContainer.new()
	item_list.name = "Items"
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 6)
	scroll.add_child(item_list)

	empty_label = Label.new()
	empty_label.name = "Empty"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.theme_type_variation = &"HintLabel"
	empty_label.visible = false
	inventory_content.add_child(empty_label)

	# What the item under the cursor is, in a fixed-height box so the list does not jump.
	description_label = Label.new()
	description_label.name = "Description"
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(0.0, DESCRIPTION_HEIGHT)
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description_label.theme_type_variation = &"HintLabel"
	inventory_content.add_child(description_label)

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
	inspect_hint_label.text = InputBindings.format_text(tr("INVENTORY_INSPECT_HINT"))
	inspect_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_vbox.add_child(inspect_hint_label)


func _connect_language_settings() -> void:
	if not GameSettings.text_language_changed.is_connected(
		_on_text_language_changed
	):
		GameSettings.text_language_changed.connect(
			_on_text_language_changed
		)


func _on_text_language_changed(_locale: String) -> void:
	if inspect_hint_label != null:
		inspect_hint_label.text = InputBindings.format_text(
			tr("INVENTORY_INSPECT_HINT")
		)

	if (
		inspect_content != null
		and inspect_content.visible
		and not current_inspect_data.is_empty()
	):
		show_inspect(
			current_inspect_data,
			inspect_return_to_inventory
		)
		return

	if header_label != null:
		header_label.text = tr("INVENTORY_TITLE")

	refresh(current_slots)


## Clicking an item opens it in the inspect view; there is nothing else to do
## with an item from the inventory.
func _on_slot_button_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= current_slots.size():
		return

	var slot_data: Dictionary = current_slots[slot_index]
	if str(slot_data.get("id", "")).is_empty():
		return

	inspect_requested.emit(slot_data)
