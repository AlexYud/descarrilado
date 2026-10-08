extends Node3D
class_name UnfinishedHouseSequence

## Orchestrates the unfinished house (the second dream puzzle): two scares and
## the time capsule at the end. The pieces (doors, items, the lock) only raise
## signals; every decision lives here. Sounds are generated placeholders.
##
## Reading the kitchen recipe only gives Juliana's comment: nothing happens.
##
## Scares (each plays once and is remembered across saves):
## - the master key (closing its view): every open door in the house slams shut at
##   once (a bang at each, a jolt of the camera) and the flashlight dies; the
##   player can switch it back on. The next time the player opens the pantry door
##   a black head and one shoulder are at the window at the end of the corridor,
##   outside, tilted and peering in, backlit by the glow behind it, with a weak
##   light from the window casting its shadow into the corridor. Total silence.
##   A second and a half later it ducks out of sight;
## - Lucas's diary (the moment its view opens): someone runs through the house
##   and down the corridor towards the master bedroom, the footsteps getting
##   louder and closer while the player reads.
##
## Taking the unclaimed bus ticket from the capsule raises `sequence_completed`.
## The house stays as it is; nothing else happens.

signal sequence_completed

const STATE_SECTION: StringName = &"puzzles"
const KEY_KEY_DONE: StringName = &"house_key_scare_done"
const KEY_SILHOUETTE_DONE: StringName = &"house_silhouette_done"
const KEY_DIARY_DONE: StringName = &"house_diary_scare_done"
const KEY_TICKET_TAKEN: StringName = &"house_ticket_taken"

@export_category("Clues")
## `inspect_id` metadata of the Visual of each clue.
@export var key_id: StringName = &"master_key"
@export var diary_id: StringName = &"lucas_diary"
@export var ticket_id: StringName = &"bus_ticket_unclaimed"

@export_category("Key: every door slams shut")
## Parent of the house's doors (every DoorController child slams shut).
@export var doors_root: Node3D
@export var scare_delay_seconds: float = 1.2

@export_category("Pantry door: the silhouette")
@export var pantry_door: DoorController
## The glow outside the corridor window that backlights the silhouette.
@export var hall_glow: Node3D
## The weak light from the window into the corridor (casts the head's shadow).
@export var hall_light: Light3D
@export var figure: Node3D
## Where the head is (outside the west wall, just above the sill of the
## corridor window) and how far below that it ducks, hidden by the wall.
@export var figure_position: Vector3 = Vector3(-0.45, 0.85, 7.6)
@export var figure_hidden_offset: Vector3 = Vector3(0.0, -0.65, 0.0)
## How long the head stays at the window after the pantry door opens.
@export var figure_wait_seconds: float = 1.5

@export_category("Diary: running footsteps")
@export var run_steps: AudioStreamPlayer3D
## Where the runner comes from (the living room) and where it ends (the master
## bedroom door), through the hallway.
@export var run_path: Array[Vector3] = [
	Vector3(4.65, 0.1, 13.5), Vector3(2.325, 0.1, 9.6), Vector3(2.325, 0.1, 7.3625),
	Vector3(7.44, 0.1, 7.3625), Vector3(7.44, 0.1, 6.4),
]
@export var run_stride: float = 1.3
@export var run_step_seconds: float = 0.27

## Set when the player is not the node found by group "player".
@export var player: Node3D

var _key_done: bool = false
var _silhouette_done: bool = false
var _diary_done: bool = false
var _ticket_taken: bool = false
var _silhouette_armed: bool = false

var _run_step: AudioStreamWAV = null


func _ready() -> void:
	_key_done = _read_flag(KEY_KEY_DONE)
	_silhouette_done = _read_flag(KEY_SILHOUETTE_DONE)
	_diary_done = _read_flag(KEY_DIARY_DONE)
	_ticket_taken = _read_flag(KEY_TICKET_TAKEN)

	# Loaded after the doors slammed but before the silhouette was seen.
	_silhouette_armed = _key_done and not _silhouette_done

	_run_step = PlaceholderAudio.make_run_step()
	figure.visible = false
	hall_glow.visible = false
	hall_light.visible = false
	pantry_door.opened_by_player.connect(_on_pantry_door_opened)
	_connect_to_player.call_deferred()


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
		inspect.inspect_opened.connect(_on_inspect_opened)
		inspect.inspect_closed.connect(_on_inspect_closed)


## The diary's scare starts the moment the player starts reading.
func _on_inspect_opened(opened_id: String) -> void:
	if StringName(opened_id) == diary_id and not _diary_done:
		_diary_done = true
		_write_flag(KEY_DIARY_DONE)
		_run_diary_footsteps()


func _on_inspect_closed(closed_id: String) -> void:
	var id: StringName = StringName(closed_id)

	if id == key_id and not _key_done:
		_key_done = true
		_write_flag(KEY_KEY_DONE)
		_run_door_scare()
	elif id == ticket_id and not _ticket_taken:
		_ticket_taken = true
		_write_flag(KEY_TICKET_TAKEN)
		sequence_completed.emit()


# ============================================================
# THE KEY: EVERY DOOR SLAMS SHUT, THE LIGHT DIES
# ============================================================

func _run_door_scare() -> void:
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
	_silhouette_armed = not _silhouette_done


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
# THE PANTRY DOOR: THE SILHOUETTE AT THE WINDOW
# ============================================================

func _on_pantry_door_opened() -> void:
	if not _silhouette_armed or _silhouette_done:
		return

	_silhouette_armed = false
	_silhouette_done = true
	_write_flag(KEY_SILHOUETTE_DONE)
	_run_silhouette()


func _run_silhouette() -> void:
	# Someone is crouched outside the window. A head and one shoulder are there,
	# tilted, black against the glow, the moment the door opens. No sound at all.
	var rest: Vector3 = figure_position
	figure.position = rest
	figure.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	hall_glow.visible = true
	hall_light.visible = true
	figure.visible = true

	await _wait(figure_wait_seconds)

	# Then it ducks out of sight.
	var sink: Tween = create_tween()
	sink.tween_property(figure, "position", rest + figure_hidden_offset, 0.2)
	await sink.finished

	figure.visible = false
	hall_glow.visible = false
	hall_light.visible = false

# ============================================================
# THE DIARY: SOMEONE RUNS TOWARDS THE MASTER BEDROOM
# ============================================================

func _run_diary_footsteps() -> void:
	await _wait(1.0)

	var total: float = _path_length(run_path)
	var steps: int = int(ceilf(total / run_stride))
	for i: int in steps + 1:
		var distance: float = minf(float(i) * run_stride, total)
		run_steps.position = _point_at(run_path, distance)
		run_steps.stream = _run_step
		# Quiet and far at first, loud and close at the end.
		run_steps.volume_db = lerpf(-18.0, 2.0, distance / total)
		run_steps.pitch_scale = randf_range(1.05, 1.25)
		run_steps.play()
		await _wait(run_step_seconds)


# ============================================================
# HELPERS
# ============================================================

func _path_length(path: Array[Vector3]) -> float:
	var length: float = 0.0
	for i: int in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])

	return length


## The point `distance` metres along a polyline (clamped to its ends).
func _point_at(path: Array[Vector3], distance: float) -> Vector3:
	var remaining: float = maxf(distance, 0.0)
	for i: int in range(1, path.size()):
		var segment: float = path[i - 1].distance_to(path[i])
		if remaining <= segment:
			return path[i - 1].lerp(path[i], remaining / maxf(segment, 0.0001))

		remaining -= segment

	return path[path.size() - 1]


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
