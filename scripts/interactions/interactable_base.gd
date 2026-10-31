extends Node3D
class_name Interactable

## Every usable thing is in this group, so that the interaction marks (`InteractionReticle`) can find the ones near the player.
const GROUP: StringName = &"interactables"

@export var prompt_text: String = "PROMPT_INTERACT"
## Where the interaction mark sits, from the middle of the thing's interaction shape, in that shape's own axes (zero: the middle). For
## something big, like a gate, it goes where the hand would go (a fixed place on the thing, so it is on the other side when it is seen from
## its other face).
@export var mark_offset: Vector3 = Vector3.ZERO
## How far (metres) from the eyes this thing's mark is shown, instead of the reticle's own distance (0: the reticle's). Only the mark: using it still
## takes the usual short reach. `mark_while_held` keeps the mark shown while a scene holds the player's view (a cinematic).
@export var mark_notice_distance: float = 0.0
@export var mark_while_held: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func can_interact(_player: Node) -> bool:
	return true


func get_prompt_text() -> String:
	return prompt_text


func interact(_player: Node) -> void:
	pass
