extends Node3D
class_name Interactable

@export var prompt_text: String = "[E] Interact"


func can_interact(_player: Node) -> bool:
	return true


func get_prompt_text() -> String:
	return prompt_text


func interact(_player: Node) -> void:
	pass
