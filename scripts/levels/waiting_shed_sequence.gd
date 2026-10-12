extends Node3D
class_name WaitingShedSequence

## Orchestrates the waiting shed and signal box (the third dream puzzle). There
## are no scares and no ambient sounds of its own: the dream intro's night and
## fog are the atmosphere. The pieces (journal, clue items, the lever box) only
## raise signals; every decision lives here.
##
## Puzzle: the journal gives only the order of a secret code (light the track,
## punch the ticket, blow the signal), which is the order of the levers. The
## lantern, the ticket puncher (in a closed box under the bench) and the whistle
## (on the back of the mile marker) each carry one phrase whose words say up or
## down. The signal box releases Sophia's Ficha when its levers read UP, DOWN, UP.
## Taking the Ficha (closing its view) raises `sequence_completed`. The clearing
## stays as it is; nothing else happens.

signal sequence_completed

const STATE_SECTION: StringName = &"puzzles"
const KEY_FICHA_TAKEN: StringName = &"junction_ficha_taken"

@export_category("Clues")
## `inspect_id` metadata of the Visual of the Ficha.
@export var ficha_id: StringName = &"sophia_ficha"

@export_category("Ground")
## How the ground under the shed is tilted, as the rise in metres per metre going
## east (x) and south (z). The dream intro grades its terrain to a gentle plane;
## the platform under the shelter stays level at the plane's height, the railway
## lies on the plane (pitched and rolled), and the mile marker stands on it. Zero (the default)
## is flat ground, as in the playtest scene.
@export var ground_slope: Vector2 = Vector2.ZERO
@export var platform: Node3D
## The middle of the platform (the shelter), in the scene's metres.
@export var platform_anchor: Vector2 = Vector2(-3.0, -5.5)
@export var track: Node3D
@export var marker_group: Node3D

## Set when the player is not the node found by group "player".
@export var player: Node3D

var _ficha_taken: bool = false


func _ready() -> void:
	_apply_ground()
	_ficha_taken = bool(SaveManager.get_state_value(STATE_SECTION, KEY_FICHA_TAKEN, false))
	_connect_to_player.call_deferred()


## Sets the heights and the railway's tilt from `ground_slope` (see above).
func _apply_ground() -> void:
	if platform != null:
		platform.position.y = ground_slope.x * platform_anchor.x + ground_slope.y * platform_anchor.y

	if track != null:
		track.position.y = ground_slope.x * track.position.x
		# Pitched along the railway and rolled across it, onto the same plane.
		track.rotation = Vector3(-atan(ground_slope.y), 0.0, atan(ground_slope.x))

	if marker_group != null:
		marker_group.position.y = (
			ground_slope.x * marker_group.position.x + ground_slope.y * marker_group.position.z
		)


func _connect_to_player() -> void:
	var target: Node = _get_player()
	if target == null:
		await get_tree().process_frame
		target = _get_player()

	if target == null:
		push_warning("WaitingShedSequence: no player found.")
		return

	var inspect: PlayerInspectController = target.get("inspect_controller") as PlayerInspectController
	if inspect != null:
		inspect.inspect_closed.connect(_on_inspect_closed)


func _on_inspect_closed(closed_id: String) -> void:
	if StringName(closed_id) == ficha_id and not _ficha_taken:
		_ficha_taken = true
		SaveManager.set_state_value(STATE_SECTION, KEY_FICHA_TAKEN, true)
		sequence_completed.emit()


func _get_player() -> Node3D:
	if player != null:
		return player

	return get_tree().get_first_node_in_group(&"player") as Node3D
