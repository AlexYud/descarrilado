extends SpotLight3D

@export var required_item_id: String = "flashlight"
@export var flashlight_starts_on: bool = false
@export var flicker_enabled: bool = true
@export var flicker_chance_percent: int = 10
@export var flicker_interval_min: float = 0.05
@export var flicker_interval_max: float = 0.2

var flashlight_on: bool = true
var flicker_timer: float = 0.0
var flicker_forced_off: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player: Node = null


func _ready() -> void:
	rng.randomize()
	flashlight_on = flashlight_starts_on
	player = _find_player()
	visible = false


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()

	if _can_toggle_flashlight() and Input.is_action_just_pressed("flashlight"):
		flashlight_on = not flashlight_on

	if _should_emit_light():
		_update_flicker(delta)
	else:
		flicker_timer = 0.0
		flicker_forced_off = false
		visible = false


func _update_flicker(delta: float) -> void:
	if not flicker_enabled:
		visible = true
		return

	flicker_timer -= delta

	if flicker_timer <= 0.0:
		flicker_forced_off = rng.randi_range(0, 100) < flicker_chance_percent
		flicker_timer = rng.randf_range(flicker_interval_min, flicker_interval_max)

	visible = not flicker_forced_off


func _should_emit_light() -> bool:
	return _player_has_flashlight() and not _player_flashlight_blocked() and flashlight_on


func _can_toggle_flashlight() -> bool:
	return _player_has_flashlight() and not _player_flashlight_blocked()


func _player_has_flashlight() -> bool:
	if player != null and player.has_method("has_inventory_item"):
		return bool(player.call("has_inventory_item", required_item_id))

	return false


func _player_flashlight_blocked() -> bool:
	if player != null and player.has_method("is_flashlight_blocked"):
		return bool(player.call("is_flashlight_blocked"))

	return false


func _find_player() -> Node:
	var current: Node = self

	while current != null:
		if current is CharacterBody3D:
			return current
		current = current.get_parent()

	return null
