extends Interactable
class_name SignalLever

## One lever of a LeverBox, as an interactable in the 3D scene. The prompt says
## what using it does ("Pull lever 2 down" / "Push lever 2 up"); using it swings
## the lever on the box. Put it as a child of the LeverBox, with an `InteractArea`
## in front of the lever.

## Which lever of the box this is (0 based).
@export var index: int = 0

var _box: LeverBox = null


func _ready() -> void:
	_box = get_parent() as LeverBox


func can_interact(_player: Node) -> bool:
	return _box != null and not _box.is_unlocked


func get_prompt_text() -> String:
	if _box == null or index >= _box.states.size():
		return prompt_text

	var key: String = "PROMPT_LEVER_PULL_DOWN" if _box.states[index] else "PROMPT_LEVER_PUSH_UP"
	return tr(key) % (index + 1)


func interact(_player: Node) -> void:
	if _box != null:
		_box.toggle_lever(index)


## Takes the lever out of the interaction ray's reach (the box is solved).
func disable() -> void:
	var area: Node = get_node_or_null(^"InteractArea")
	if area == null:
		return

	for shape: Node in area.get_children():
		if shape is CollisionShape3D:
			(shape as CollisionShape3D).set_deferred("disabled", true)
