extends Node3D
class_name Interactable

## Every usable thing is in this group, so that the interaction marks (`InteractionReticle`) can find the ones near the player.
const GROUP: StringName = &"interactables"

@export var prompt_text: String = "PROMPT_INTERACT"


func _enter_tree() -> void:
	add_to_group(GROUP)


func can_interact(_player: Node) -> bool:
	return true


func get_prompt_text() -> String:
	return prompt_text


func interact(_player: Node) -> void:
	pass
