extends Area3D

@export_multiline var message: String = "Hello."
@export var use_timed_dialogue: bool = true
@export var duration: float = 2.0
@export var freeze_player: bool = false
@export var trigger_once: bool = true

var used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if trigger_once and used:
		return

	if not body.is_in_group("player"):
		return

	used = true

	if use_timed_dialogue:
		DialogueManager.show_timed(message, duration, freeze_player)
	else:
		DialogueManager.show_continue(message, freeze_player)
