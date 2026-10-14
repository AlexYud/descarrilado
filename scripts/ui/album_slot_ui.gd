extends PanelContainer
class_name AlbumSlotUI

## An empty space on an album page in the close-up: a drop target that shows
## the photograph placed there, if any.

const SLOT_SIZE: Vector2 = Vector2(264.0, 176.0)

var index: int = 0

var _view: AlbumView = null


func setup(owner_view: AlbumView, slot_number: int) -> void:
	_view = owner_view
	index = slot_number
	custom_minimum_size = SLOT_SIZE

	var style: StyleBoxFlat = UIConfig.panel_style(UIConfig.color_border, 0.9, Vector2i(4, 4))
	style.set_border_width_all(2)
	add_theme_stylebox_override(&"panel", style)


## Shows the photograph in this slot (`info` is the album's photo info), or the
## empty space when `info` is empty.
func show_photo(info: Dictionary, item_id: String) -> void:
	for child: Node in get_children():
		child.queue_free()

	if info.is_empty():
		return

	var card_size: Vector2 = info["card_size"] as Vector2
	var frame: AspectRatioContainer = AspectRatioContainer.new()
	frame.ratio = card_size.x / card_size.y
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var card: PhotoCardUI = PhotoCardUI.new()
	card.setup(_view, info, item_id, index)
	frame.add_child(card)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _view.can_drop_on_slot(index, data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_view.drop_on_slot(index, data)
