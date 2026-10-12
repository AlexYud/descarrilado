extends Area3D
class_name TutorialTrigger

## A volume that tells the player's tutorial hints that the moment for a lesson has
## come, the way level designers place teaching moments in modern games ("you are
## in the woods now: here is how to walk faster"). It builds its own box shape, so
## a trigger is one node with a size.
##
## The hint itself (wording, key, how long, remembering that it was learned) belongs
## to `TutorialHintController`; a hint with a trigger in the level waits for it, and
## without one it falls back to its own timing.

## Which lesson this starts (see `TutorialHintController.trigger`).
@export var hint_id: StringName = &"sprint"
@export var size: Vector3 = Vector3(4.0, 6.0, 4.0)


func _ready() -> void:
	add_to_group(group_name(hint_id))

	monitoring = true
	monitorable = false

	if get_child_count() == 0 or get_node_or_null("Shape") == null:
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "Shape"
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape.shape = box
		add_child(shape)

	body_entered.connect(_on_body_entered)


## The group that marks a level as having a trigger for `id`.
static func group_name(id: StringName) -> StringName:
	return StringName("tutorial_trigger_%s" % id)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return

	var hints: Node = body.get_node_or_null("TutorialHints")
	if hints != null and hints.has_method("trigger"):
		hints.call("trigger", hint_id)
