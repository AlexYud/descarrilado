extends PanelContainer
class_name AlbumTrayUI

## The photographs the player holds, in the album close-up. Dropping a photo
## taken from a slot here takes it out of the album and back into the
## player's hands.

var _view: AlbumView = null


func setup(owner_view: AlbumView) -> void:
	_view = owner_view


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _view.can_drop_on_tray(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_view.drop_on_tray(data)
