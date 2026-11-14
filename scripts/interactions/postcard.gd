extends Inspectable
class_name Postcard

## Lucas's unsent postcard, kept in the bedroom nightstand's drawer (the model is `HouseProps._build_postcard`, on the `Visual` child). It is read
## like any note, unless a scene has claimed the inspection (`plays_scene`): then using it raises `scene_requested` instead and the
## scene takes the view.
##
## In a drawer (`drawer`): it lies where the scene puts it with the drawer shut, and goes in and out with the drawer; it can only be used while the
## drawer is open.

## The player used the postcard while `plays_scene` was set.
signal scene_requested(player: Node)

## The drawer it lies in (none: it stays where it is).
@export var drawer: DrawerInteractable

## While set, using the postcard asks for the scene (`scene_requested`) instead of opening the inspect view.
var plays_scene: bool = false

## Where it lies in the drawer, in the drawer's sliding part's frame.
var _in_drawer: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	var visual: ProceduralProp = get_visual_node() as ProceduralProp
	if visual != null:
		visual.build_now()

	set_process(false)
	if drawer != null and drawer.drawer_root != null:
		# The scene places the card with the drawer SHUT (the drawer may already have been opened by a saved game when this runs).
		var shut: Transform3D = drawer.global_transform * Transform3D(drawer.drawer_root.basis, drawer.closed_local_position)
		_in_drawer = shut.affine_inverse() * global_transform
		set_process(true)
		_follow_drawer()


func _process(_delta: float) -> void:
	_follow_drawer()


func _follow_drawer() -> void:
	if drawer != null and drawer.drawer_root != null:
		global_transform = drawer.drawer_root.global_transform * _in_drawer


func can_interact(player: Node) -> bool:
	if drawer != null and not drawer.is_open:
		return false

	return super.can_interact(player)


func interact(player: Node) -> void:
	if plays_scene:
		scene_requested.emit(player)
		return

	super.interact(player)
