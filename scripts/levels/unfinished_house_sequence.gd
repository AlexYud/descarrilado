extends Node3D
class_name UnfinishedHouseSequence

## Orchestrates the unfinished house (the second dream puzzle): three scares
## that fire when the player closes the view of a clue, and the time capsule at
## the end. The pieces (doors, items, the lock) only raise signals; every
## decision lives here. Sounds are generated placeholders.
##
## Scares (each plays once and is remembered across saves):
## - the kitchen recipe: every door in the house slams shut at once (a bang, a
##   jolt of the camera) and the flashlight dies; the player can switch it back on;
## - the master key: three heavy steps come down the hallway towards the pantry;
## - Lucas's diary: a tap on the bedroom window and a black head against the
##   glass that ducks away the moment the flashlight finds it.
##
## Taking the unclaimed bus ticket from the capsule raises `sequence_completed`.
## The house stays as it is; nothing else happens.

signal sequence_completed

const STATE_SECTION: StringName = &"puzzles"
const KEY_RECIPE_DONE: StringName = &"house_recipe_scare_done"
const KEY_KEY_DONE: StringName = &"house_key_scare_done"
const KEY_DIARY_DONE: StringName = &"house_diary_scare_done"
const KEY_TICKET_TAKEN: StringName = &"house_ticket_taken"

@export_category("Clues")
## `inspect_id` metadata of the Visual of each clue.
@export var recipe_id: StringName = &"kitchen_recipe"
@export var key_id: StringName = &"master_key"
@export var diary_id: StringName = &"lucas_diary"
@export var ticket_id: StringName = &"bus_ticket_unclaimed"

@export_category("Kitchen: doors")
## Parent of the house's doors (every DoorController child slams shut).
@export var doors_root: Node3D

@export_category("Pantry: footsteps")
@export var hall_steps: AudioStreamPlayer3D
## Where the boots land in the hallway, coming towards the pantry.
@export var hall_path: Array[Vector3] = [
	Vector3(6.0, 0.1, 7.3625), Vector3(7.5, 0.1, 7.3625), Vector3(8.9, 0.1, 7.3625),
]
@export var hall_step_seconds: float = 1.0

@export_category("Bedroom window")
@export var window_tap: AudioStreamPlayer3D
@export var window_head: Node3D
@export var window_mist: Node3D
@export var flee_sound: AudioStreamPlayer3D
## How far from the flashlight's aim (degrees) still counts as shining on it.
@export var light_hit_angle_degrees: float = 11.0
@export var light_hit_distance: float = 9.0

@export_category("Timing")
@export var scare_delay_seconds: float = 1.2

## Set when the player is not the node found by group "player".
@export var player: Node3D

var _recipe_done: bool = false
var _key_done: bool = false
var _diary_done: bool = false
var _ticket_taken: bool = false

var _footstep: AudioStreamWAV = null
var _watching_window: bool = false
var _head_rest_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_recipe_done = _read_flag(KEY_RECIPE_DONE)
	_key_done = _read_flag(KEY_KEY_DONE)
	_diary_done = _read_flag(KEY_DIARY_DONE)
	_ticket_taken = _read_flag(KEY_TICKET_TAKEN)

	_footstep = PlaceholderAudio.make_footstep()
	_hide_scares()
	_connect_to_player.call_deferred()


func _process(_delta: float) -> void:
	if _watching_window and _flashlight_on_head():
		_watching_window = false
		_head_flees()


func _hide_scares() -> void:
	window_head.visible = false
	window_mist.visible = false
	_head_rest_position = window_head.position


func _connect_to_player() -> void:
	var target: Node = _get_player()
	if target == null:
		await get_tree().process_frame
		target = _get_player()

	if target == null:
		push_warning("UnfinishedHouseSequence: no player found.")
		return

	var inspect: PlayerInspectController = target.get("inspect_controller") as PlayerInspectController
	if inspect != null:
		inspect.inspect_closed.connect(_on_inspect_closed)


## Every scare starts when the view of its clue closes.
func _on_inspect_closed(closed_id: String) -> void:
	var id: StringName = StringName(closed_id)

	if id == recipe_id and not _recipe_done:
		_recipe_done = true
		_write_flag(KEY_RECIPE_DONE)
		_run_kitchen_scare()
	elif id == key_id and not _key_done:
		_key_done = true
		_write_flag(KEY_KEY_DONE)
		_run_pantry_footsteps()
	elif id == diary_id and not _diary_done:
		_diary_done = true
		_write_flag(KEY_DIARY_DONE)
		_run_window_scare()
	elif id == ticket_id and not _ticket_taken:
		_ticket_taken = true
		_write_flag(KEY_TICKET_TAKEN)
		sequence_completed.emit()


# ============================================================
# THE KITCHEN: EVERY DOOR SLAMS SHUT, THE LIGHT DIES
# ============================================================

func _run_kitchen_scare() -> void:
	await _wait(scare_delay_seconds)

	var slammed: bool = false
	var slam_positions: Array[Vector3] = []
	if doors_root != null:
		for child: Node in doors_root.get_children():
			var door: DoorController = child as DoorController
			if door == null or not door.is_open:
				continue

			door.slam_shut()
			slammed = true
			slam_positions.append(door.global_position + Vector3(0.0, 1.0, 0.0))

	await _wait(0.12)

	# Even if every door was already shut, something still hits them all.
	var target: Node3D = _get_player()
	if not slammed and target != null:
		slam_positions.append(target.global_position)

	for position_to_slam: Vector3 in slam_positions:
		_bang_at(position_to_slam)

	_jolt_camera(1.3)
	_cut_flashlight()


## One loud bang at a point; the sound player removes itself when done.
func _bang_at(world_position: Vector3) -> void:
	var bang: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	bang.stream = PlaceholderAudio.make_slam()
	bang.volume_db = 4.0
	bang.unit_size = 8.0
	bang.max_distance = 60.0
	add_child(bang)
	bang.global_position = world_position
	bang.finished.connect(bang.queue_free)
	bang.play()


## Shakes the view for a moment, strongest at first.
func _jolt_camera(strength: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var shake: Tween = create_tween()
	shake.tween_method(
		func(amount: float) -> void:
			if is_instance_valid(camera):
				camera.h_offset = randf_range(-1.0, 1.0) * 0.1 * strength * amount
				camera.v_offset = randf_range(-1.0, 1.0) * 0.1 * strength * amount,
		1.0, 0.0, 0.5
	)
	await shake.finished
	if is_instance_valid(camera):
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Puts the flashlight out. The player can switch it back on.
func _cut_flashlight() -> void:
	var target: Node = _get_player()
	var flashlight: Node = target.get("flashlight_controller") as Node if target != null else null
	if flashlight != null and flashlight.has_method("turn_off"):
		flashlight.call("turn_off")


# ============================================================
# THE PANTRY: THREE STEPS COMING DOWN THE HALLWAY
# ============================================================

func _run_pantry_footsteps() -> void:
	await _wait(scare_delay_seconds)

	for i: int in hall_path.size():
		hall_steps.position = hall_path[i]
		_step(hall_steps, -2.0 + i * 2.0)
		await _wait(hall_step_seconds)


# ============================================================
# THE BEDROOM: SOMETHING AT THE WINDOW
# ============================================================

func _run_window_scare() -> void:
	await _wait(scare_delay_seconds + 0.4)

	window_tap.stream = PlaceholderAudio.make_tap()
	window_tap.play()

	await _wait(0.9)
	window_head.position = _head_rest_position
	window_head.visible = true
	window_mist.visible = true
	_watching_window = true


## True while the flashlight is on and aimed at the head, with nothing between.
func _flashlight_on_head() -> bool:
	var target: Node = _get_player()
	if target == null:
		return false

	var flashlight: Node = target.get("flashlight_controller") as Node
	if flashlight == null or not bool(flashlight.get("flashlight_on")):
		return false

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return false

	var head_position: Vector3 = window_head.global_position + Vector3(0.0, 0.2, 0.0)
	var to_head: Vector3 = head_position - camera.global_position
	if to_head.length() > light_hit_distance:
		return false

	var forward: Vector3 = -camera.global_transform.basis.z
	if rad_to_deg(forward.angle_to(to_head)) > light_hit_angle_degrees:
		return false

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position, head_position
	)
	if target is CollisionObject3D:
		query.exclude = [(target as CollisionObject3D).get_rid()]

	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The head ducks below the sill and whatever it was runs off into the woods.
func _head_flees() -> void:
	await _wait(0.12)

	var duck: Tween = create_tween()
	duck.tween_property(window_head, "position:y", _head_rest_position.y - 0.9, 0.22)

	flee_sound.stream = PlaceholderAudio.make_rustle()
	flee_sound.position = window_head.position + Vector3(0.0, 0.0, -1.0)
	flee_sound.play()
	var run: Tween = create_tween()
	run.tween_property(flee_sound, "position:z", -14.0, 2.4)

	await duck.finished
	window_head.visible = false
	window_mist.visible = false


# ============================================================
# HELPERS
# ============================================================

## One footstep from `source`, a little different each time.
func _step(source: AudioStreamPlayer3D, volume_db: float) -> void:
	source.stream = _footstep
	source.volume_db = volume_db
	source.pitch_scale = randf_range(0.85, 1.1)
	source.play()


func _get_player() -> Node3D:
	if player != null:
		return player

	return get_tree().get_first_node_in_group(&"player") as Node3D


func _wait(seconds: float) -> void:
	# Not "process always": the pause menu also pauses the sequence.
	await get_tree().create_timer(seconds, false).timeout


func _read_flag(key: StringName) -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, key, false))


func _write_flag(key: StringName) -> void:
	SaveManager.set_state_value(STATE_SECTION, key, true)
