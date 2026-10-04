extends Node3D
class_name AlbumSlot

## One empty space on a photo album page, as seen in the 3D world. It only
## shows what the album's arrangement says; PhotoAlbum owns the logic.

## Unique within the game.
@export var slot_id: StringName = &""

## Inventory item id of the one photograph that belongs here. The puzzle is
## solved when every slot holds its own.
@export var correct_item_id: String = ""

## Faded pencil note beside the space: a hint about when its photo was taken.
## Shown on the 3D page and in the album close-up.
@export var caption_key: String = ""

## Room for a photograph; larger ones are scaled down to fit.
@export var slot_size: Vector2 = Vector2(0.16, 0.11)

@onready var empty_marker: Node3D = $EmptyMarker
@onready var photo_anchor: Node3D = $PhotoAnchor
@onready var caption_label: Label3D = $Caption


func _ready() -> void:
	caption_label.text = caption_key


## Shows `photo_visual` (the Visual of a photograph scene) lying flat in the
## slot, or the empty outline when it is null.
func show_photo(photo_visual: Node3D, photo_size: Vector2) -> void:
	for child: Node in photo_anchor.get_children():
		child.queue_free()

	empty_marker.visible = photo_visual == null
	if photo_visual == null:
		return

	var fit: float = minf(
		minf(slot_size.x / photo_size.x, slot_size.y / photo_size.y),
		1.0
	)
	photo_visual.owner = null
	photo_visual.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	photo_visual.position = Vector3.ZERO
	photo_visual.scale = Vector3.ONE * fit
	photo_anchor.add_child(photo_visual)
