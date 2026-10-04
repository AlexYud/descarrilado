extends Area3D
class_name SpatialTrigger

## Volume that reports when the player walks in or out.
##
## It only raises signals; level controllers decide what happens. Give it a
## CollisionShape3D child. Use `persistent_id` with `trigger_once` for triggers
## that must stay spent after saving and loading.

signal player_entered(player: Node3D)
signal player_exited(player: Node3D)

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_inside_tree():
			set_deferred("monitoring", enabled)

@export var trigger_once: bool = false
@export var persistent_id: StringName = &""

var player_inside: bool = false

var _spent: bool = false


func _ready() -> void:
	if not persistent_id.is_empty():
		_spent = bool(SaveManager.get_state_value(
			&"triggers",
			persistent_id,
			false
		))

	monitoring = enabled and not (trigger_once and _spent)
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return

	player_inside = true

	if trigger_once:
		if _spent:
			return

		_spent = true
		if not persistent_id.is_empty():
			SaveManager.set_state_value(&"triggers", persistent_id, true)

	player_entered.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return

	player_inside = false
	player_exited.emit(body)
