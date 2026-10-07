@tool
extends Node3D
class_name ProceduralProp

## Fills this node with a stand-in model from HouseProps. Put it on the
## `Visual` node of an inspectable (so the model is what the inspect view
## shows) or on a furniture node.
##
## The models are built in code, so they are not saved in the scene; the
## editor shows them while the scene is open. A copy of a built node (the
## inspect view duplicates `Visual`) already has its children and is left alone.

@export var kind: StringName = &""


func _ready() -> void:
	if get_child_count() > 0 or kind.is_empty():
		return

	HouseProps.build(kind, self)
