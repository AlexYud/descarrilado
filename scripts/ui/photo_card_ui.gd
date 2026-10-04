extends PanelContainer
class_name PhotoCardUI

## A photograph in the album close-up: in the player's hands (tray) or in a
## slot. It can be dragged; dropping something on it counts as dropping on the
## place it sits in, so a card never blocks its slot or the tray.

const BORDER_COLOR: Color = Color(0.86, 0.82, 0.7)
const LABEL_FONT_SIZE: int = 14

var item_id: String = ""

## Slot the card sits in, or -1 while it is in the player's hands.
var slot_index: int = -1

var _view: AlbumView = null


func setup(
	owner_view: AlbumView,
	info: Dictionary,
	id: String,
	slot: int
) -> void:
	_view = owner_view
	item_id = id
	slot_index = slot

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = info["card_color"] as Color
	style.set_border_width_all(6)
	style.border_color = BORDER_COLOR
	style.set_corner_radius_all(2)
	add_theme_stylebox_override(&"panel", style)

	var label: Label = Label.new()
	label.text = tr(str(info["card_label"]))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", LABEL_FONT_SIZE)
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	add_child(label)

	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = ""


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _view.is_locked():
		return null

	# The preview keeps the card's current size: a bare duplicate would be
	# stretched by the container the engine puts it in, so it is wrapped in a
	# plain Control and pinned to the card's size, centred on the cursor.
	var card: Control = duplicate() as Control
	card.custom_minimum_size = size
	card.size = size
	card.position = -size * 0.5
	card.modulate.a = 0.85
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview: Control = Control.new()
	preview.add_child(card)
	set_drag_preview(preview)
	return {"item_id": item_id, "from_slot": slot_index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if slot_index < 0:
		return _view.can_drop_on_tray(data)

	return _view.can_drop_on_slot(slot_index, data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if slot_index < 0:
		_view.drop_on_tray(data)
	else:
		_view.drop_on_slot(slot_index, data)
