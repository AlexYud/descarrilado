extends CanvasLayer
class_name AlbumView

## Close-up of a PhotoAlbum: the empty spaces on two pages, each with a faded
## pencil caption, and a tray with the photographs the player holds. Photos
## are dragged from the tray onto any space, between spaces, or back to the
## tray. The view never says whether a placement is right; PhotoAlbum decides
## when the whole order is correct and locks.
##
## The UI is built in code, like the inventory panel. Everything the mouse can
## do goes through `drop_on_slot()` / `drop_on_tray()`, so tests can drive it.

const VIEW_LAYER: int = 20
const COMPLETE_CLOSE_DELAY: float = 0.9
const TRAY_CARD_HEIGHT: float = 120.0
const TRAY_CARD_MIN_WIDTH: float = 130.0

var album: PhotoAlbum = null

var _player: Node = null
var _open: bool = false

var _title_label: Label = null
var _tray_title_label: Label = null
var _tray_empty_label: Label = null
var _hint_label: Label = null
var _back_button: Button = null
var _tray: AlbumTrayUI = null
var _tray_row: HBoxContainer = null
var _slot_uis: Array[AlbumSlotUI] = []
var _caption_labels: Array[Label] = []


func setup(owner_album: PhotoAlbum) -> void:
	album = owner_album
	layer = VIEW_LAYER
	visible = false
	_build_ui()

	album.completed.connect(_on_album_completed)
	GameSettings.text_language_changed.connect(_on_text_language_changed)


func is_open() -> bool:
	return _open


func is_locked() -> bool:
	return album.locked


func open(player: Node) -> void:
	if _open:
		return

	_open = true
	_player = player
	visible = true
	_player.call("set_modal_ui_open", true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()
	album.opened.emit()


func close() -> void:
	if not _open:
		return

	_open = false
	visible = false
	_player.call("set_modal_ui_open", false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	album.closed.emit()


# ============================================================
# DRAG AND DROP
# ============================================================

func can_drop_on_slot(slot_index: int, data: Variant) -> bool:
	if album.locked or not data is Dictionary:
		return false

	var drag: Dictionary = data as Dictionary
	return drag.has("item_id") and slot_index >= 0 and slot_index < album.slots.size()


func can_drop_on_tray(data: Variant) -> bool:
	if album.locked or not data is Dictionary:
		return false

	return int((data as Dictionary).get("from_slot", -1)) >= 0


## Drops a photograph on a slot. `data` is {"item_id", "from_slot"}; from_slot
## is -1 for a photograph from the player's hands.
func drop_on_slot(slot_index: int, data: Variant) -> bool:
	if not can_drop_on_slot(slot_index, data):
		return false

	var drag: Dictionary = data as Dictionary
	var item_id: String = str(drag["item_id"])
	var from_slot: int = int(drag.get("from_slot", -1))

	if from_slot >= 0:
		album.move_between(from_slot, slot_index)
	else:
		if not bool(_player.call("has_inventory_item", item_id)):
			return false

		_player.call("consume_inventory_item", item_id)
		var displaced: String = album.place_from_hand(slot_index, item_id)
		if not displaced.is_empty():
			album.give_back(_player, displaced)

	_refresh()
	return true


## Drops a photograph from a slot back into the player's hands.
func drop_on_tray(data: Variant) -> bool:
	if not can_drop_on_tray(data):
		return false

	if not bool(_player.call("has_inventory_space")):
		DialogueManager.show_timed("ALBUM_NO_ROOM", 2.0)
		return false

	var taken: String = album.take_out(int((data as Dictionary)["from_slot"]))
	if taken.is_empty():
		return false

	album.give_back(_player, taken)
	_refresh()
	return true


# ============================================================
# EVENTS
# ============================================================

func _input(event: InputEvent) -> void:
	if not _open:
		return

	var closes: bool = event.is_action_pressed("ui_cancel")
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
		and not get_viewport().gui_is_dragging()
	):
		closes = true

	if closes:
		close()
		get_viewport().set_input_as_handled()


func _on_album_completed() -> void:
	_refresh()
	if not _open:
		return

	await get_tree().create_timer(COMPLETE_CLOSE_DELAY).timeout
	close()


func _on_text_language_changed(_locale: String) -> void:
	_apply_texts()
	_refresh()


# ============================================================
# UI
# ============================================================

func _refresh() -> void:
	if not _open:
		return

	for i: int in _slot_uis.size():
		var item_id: String = album.arrangement[i]
		var info: Dictionary = (
			album.get_photo_info(item_id) if not item_id.is_empty() else {}
		)
		_slot_uis[i].show_photo(info, item_id)

	_refresh_tray()


func _refresh_tray() -> void:
	for child: Node in _tray_row.get_children():
		child.queue_free()

	var shown: int = 0
	for item_id: String in album.get_photo_ids():
		if not bool(_player.call("has_inventory_item", item_id)):
			continue

		var info: Dictionary = album.get_photo_info(item_id)
		var card_size: Vector2 = info["card_size"] as Vector2
		var card: PhotoCardUI = PhotoCardUI.new()
		card.setup(self, info, item_id, -1)
		card.custom_minimum_size = Vector2(
			maxf(TRAY_CARD_HEIGHT * card_size.x / card_size.y, TRAY_CARD_MIN_WIDTH),
			TRAY_CARD_HEIGHT
		)
		_tray_row.add_child(card)
		shown += 1

	_tray_empty_label.visible = shown == 0


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 18)
	center.add_child(column)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override(&"font_size", 28)
	column.add_child(_title_label)

	column.add_child(_build_book())
	column.add_child(_build_tray())

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	column.add_child(_hint_label)

	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(160.0, 40.0)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(close)
	column.add_child(_back_button)

	_apply_texts()


## Two pages: the first slot on the left page, the others on the right page.
func _build_book() -> Control:
	var book: PanelContainer = PanelContainer.new()
	book.add_theme_stylebox_override(
		&"panel",
		_make_style(Color(0.16, 0.1, 0.08), Color(0.08, 0.05, 0.04), 3)
	)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	book.add_child(margin)

	var pages: HBoxContainer = HBoxContainer.new()
	pages.add_theme_constant_override(&"separation", 16)
	margin.add_child(pages)

	var left_page: HBoxContainer = _make_page(pages)
	var right_page: HBoxContainer = _make_page(pages)

	for i: int in album.slots.size():
		var block: VBoxContainer = VBoxContainer.new()
		block.add_theme_constant_override(&"separation", 8)
		(left_page if i == 0 else right_page).add_child(block)

		var slot_ui: AlbumSlotUI = AlbumSlotUI.new()
		slot_ui.setup(self, i)
		block.add_child(slot_ui)
		_slot_uis.append(slot_ui)

		var caption: Label = Label.new()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.custom_minimum_size = Vector2(AlbumSlotUI.SLOT_SIZE.x, 0.0)
		caption.add_theme_color_override(&"font_color", Color(0.85, 0.8, 0.65, 0.5))
		block.add_child(caption)
		_caption_labels.append(caption)

	return book


func _make_page(parent: Control) -> HBoxContainer:
	var page: PanelContainer = PanelContainer.new()
	page.add_theme_stylebox_override(
		&"panel",
		_make_style(Color(0.3, 0.28, 0.22), Color(0.2, 0.18, 0.14), 2)
	)
	parent.add_child(page)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	page.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	margin.add_child(row)
	return row


func _build_tray() -> Control:
	_tray = AlbumTrayUI.new()
	_tray.setup(self)
	_tray.custom_minimum_size = Vector2(0.0, TRAY_CARD_HEIGHT + 56.0)
	_tray.add_theme_stylebox_override(
		&"panel",
		_make_style(Color(0.1, 0.1, 0.11), Color(0.25, 0.25, 0.27), 2)
	)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_tray.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	margin.add_child(box)

	_tray_title_label = Label.new()
	_tray_title_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	box.add_child(_tray_title_label)

	_tray_row = HBoxContainer.new()
	_tray_row.add_theme_constant_override(&"separation", 14)
	box.add_child(_tray_row)

	_tray_empty_label = Label.new()
	_tray_empty_label.modulate = Color(1.0, 1.0, 1.0, 0.45)
	box.add_child(_tray_empty_label)
	return _tray


func _apply_texts() -> void:
	_title_label.text = tr("ALBUM_VIEW_TITLE")
	_tray_title_label.text = tr("ALBUM_VIEW_TRAY_TITLE")
	_tray_empty_label.text = tr("ALBUM_VIEW_TRAY_EMPTY")
	_hint_label.text = tr("ALBUM_VIEW_HINT")
	_back_button.text = tr("OPTIONS_BACK")

	for i: int in _caption_labels.size():
		_caption_labels[i].text = tr(album.slots[i].caption_key)


func _make_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style
