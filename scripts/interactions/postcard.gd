extends Inspectable
class_name Postcard

## Lucas's unsent postcard on the bedroom nightstand (the model is `HouseProps._build_postcard`, on the `Visual` child). It is read
## like any note, unless a scene has claimed the inspection (`plays_scene`): then using it raises `scene_requested` instead and the
## scene takes the view.

## The player used the postcard while `plays_scene` was set.
signal scene_requested(player: Node)

## While set, using the postcard asks for the scene (`scene_requested`) instead of opening the inspect view.
var plays_scene: bool = false


func _ready() -> void:
	var visual: ProceduralProp = get_visual_node() as ProceduralProp
	if visual != null:
		visual.build_now()


func interact(player: Node) -> void:
	if plays_scene:
		scene_requested.emit(player)
		return

	super.interact(player)
