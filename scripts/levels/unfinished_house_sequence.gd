extends Node3D
class_name UnfinishedHouseSequence

## Orchestrates the unfinished house (the second dream puzzle): the rooms open one after another as
## the story is read, and the climax is a trap in the dark. The pieces (doors, items, the capsule) only
## raise signals; every decision lives here. Sounds are generated placeholders.
##
## The progression, room by room:
##  1. Kitchen: the pantry door starts LOCKED. Reading the recipe in the sink (closing its inspect view)
##     unlocks it with an audible click (the pantry is out of sight from the kitchen, so the sound is
##     how the player knows) and it swings gently open.
##  2. Pantry: the folded note and the Rusty Key. The first time the note is inspected, muffled arguing
##     fades in from the hallway (the family shouting, as the letter says) and the pantry door quietly
##     closes by itself; the arguing goes on after the note is put away and fades out when the player
##     opens the closed pantry door.
##  3. Master bedroom: the key unlocks the bedroom door; the notebook is in the nightstand drawer.
##  4. Closing the notebook starts the climax: the bedroom light turns a vivid red, someone runs from
##     the bedroom down the hallway to the living room, and the time capsule's iron latch is thrown
##     open there (a loud clack).
##  5. The trap: as the player walks down the hallway towards the living room the flashlight dies. The
##     player can switch it back on as often as they like (nothing happens in the hallway). A still
##     figure stands over the capsule in the pitch dark; the moment the beam finds it (it lights it: anywhere in the lit cone), the light drops
##     to a weak glow that stutters for half a second and every time it comes back the figure has
##     moved (it turns its head, rises, is nearer): the eye never gets a clear look, a flickering view
##     of something wrong and unknown instead of a monster. Then the light dies, every door slams
##     shut and locks. The next time the player switches the flashlight on, everything is back to
##     normal: the figure is gone, the red light is gone, and the capsule stands open on its crate.
##  6. Lucas's Ficha lies on top of the capsule's contents: taking it (closing its view) ends the
##     scene and silently unlocks every door, the front one included.
##
## **It cannot get stuck** (it did, three times): the trap is the one place the story can dead-end (the capsule stays
## shut until it is resolved), so it does not trust any single step. Every stage has a watchdog in `_process`: the
## figure's trap springs by the beam, by looking its way, by standing near it, and at the very latest
## `trap_failsafe_seconds` after it appears; a reveal that does not finish within `reveal_failsafe_seconds` is finished
## at once; the house is put right as soon as the light is ON again (it is polled, not waited for as a signal); the link
## to the player's flashlight is retried until it holds; and a player already standing in the hallway when the trap arms
## is caught too. Each step sets its stage BEFORE its effects, so an effect that fails cannot leave the stage behind.
## Every change of stage is printed (`[UnfinishedHouse] ...`), and a watchdog that has to act says so as a warning.
##
## Everything in the capsule is read in place (the advertisement and both bus tickets) except the
## Ficha: the only thing the player takes from the house.

signal sequence_completed

enum Stage {
	START,
	PANTRY_OPEN,
	CLIMAX,
	TRAP_ARMED,
	TRAP_CUT,
	SLAMMING,
	SLAMMED,
	RESOLVED,
}

const STATE_SECTION: StringName = &"puzzles"
const KEY_STAGE: StringName = &"house_stage"
const KEY_FICHA_TAKEN: StringName = &"house_ficha_taken"
## The reveal (about half a second): the light's state at each beat (on or off, at this fraction of its
## strength), the pose the figure is in while it is lit, and how long the beat lasts. The figure
## changes only while the light is OFF, so it has always moved when the light comes back.
const REVEAL_STEPS: Array[Dictionary] = [
	{"on": true, "energy": 0.06, "seconds": 0.08, "pose": &"bowed"},
	{"on": false, "energy": 0.0, "seconds": 0.05, "pose": &"turned"},
	{"on": true, "energy": 0.08, "seconds": 0.07},
	{"on": false, "energy": 0.0, "seconds": 0.04, "pose": &"risen"},
	{"on": true, "energy": 0.10, "seconds": 0.08},
	{"on": false, "energy": 0.0, "seconds": 0.03, "pose": &"near"},
	{"on": true, "energy": 0.13, "seconds": 0.10},
	{"on": false, "energy": 0.0, "seconds": 0.05},
]
const REVEAL_SECONDS: float = 0.5

## Heights above the figure's feet the beam is judged against: feet, knees, chest, head.
const FIGURE_AIM_HEIGHTS: Array[float] = [0.2, 0.7, 1.1, 1.6]

## The figure's poses: the lean of the body, the head's pitch, yaw and roll, how far the arms swing
## out, how far the body is turned from facing the capsule, and how much of the approach it has made.
const FIGURE_POSES: Dictionary = {
	&"bowed": {"lean": -26.0, "head_pitch": -24.0, "head_yaw": 0.0, "head_roll": 0.0, "arms": 2.0, "body_yaw": 0.0, "near": 0.0},
	&"turned": {"lean": -26.0, "head_pitch": 0.0, "head_yaw": 180.0, "head_roll": 12.0, "arms": 3.0, "body_yaw": 0.0, "near": 0.0},
	&"risen": {"lean": -4.0, "head_pitch": 4.0, "head_yaw": 180.0, "head_roll": 24.0, "arms": 4.0, "body_yaw": 180.0, "near": 0.35},
	&"near": {"lean": 6.0, "head_pitch": -6.0, "head_yaw": 0.0, "head_roll": 38.0, "arms": 13.0, "body_yaw": 180.0, "near": 1.0},
}

## 0: not heard yet, 1: the arguing is going on (the pantry door is closed), 2: over.
const KEY_PANTRY_BEAT: StringName = &"house_pantry_beat"

@export_category("Clues")
## `inspect_id` metadata of the Visual of each clue.
@export var recipe_id: StringName = &"kitchen_recipe"
@export var pantry_note_id: StringName = &"pantry_note"
@export var diary_id: StringName = &"lucas_diary"
@export var ficha_id: StringName = &"lucas_ficha"

@export_category("Kitchen: the pantry opens")
## Every door of the house (a DoorController child each).
@export var doors_root: Node3D
@export var pantry_door: DoorController
## How long after the recipe is put away the pantry door unlocks and swings open.
@export var pantry_open_delay_seconds: float = 0.8
## The unlock click comes this long before the door starts to swing open.
@export var unlock_to_open_seconds: float = 0.8

@export_category("Pantry: reading the past")
## Muffled arguing from the hallway: from the first time the pantry note is inspected until the player
## opens the pantry door again.
@export var argument_voices: AudioStreamPlayer3D
## The arguing is this loud, and fades in and out over this long.
@export var voices_db: float = -9.0
@export var voices_fade_seconds: float = 2.0
## The pantry door closes this long after the note is first opened.
@export var pantry_close_delay_seconds: float = 1.0

@export_category("Bedroom: the climax")
## The string tension under the climax: it starts when the notebook is put away, together with the red light and the
## running footsteps, and plays through (about twelve seconds).
@export var tension_audio: AudioStream = preload("res://assets/audios/placeholder_string_tension.mp3")
@export var tension_volume_db: float = 0.0
## The bedroom's red light.
@export var bedroom_light: OmniLight3D
@export var red_energy: float = 3.2
@export var red_fade_in_seconds: float = 0.4
@export var red_fade_out_seconds: float = 1.6
@export var run_steps: AudioStreamPlayer3D
## From inside the bedroom, through the hallway, to the living room by the capsule.
@export var run_path: Array[Vector3] = [
	Vector3(6.0, 0.1, 3.0), Vector3(7.0, 0.1, 5.2), Vector3(7.0, 0.1, 7.3625),
	Vector3(2.325, 0.1, 7.3625), Vector3(2.325, 0.1, 9.6), Vector3(7.2, 0.1, 12.2),
]
@export var run_stride: float = 1.3
@export var run_step_seconds: float = 0.27
## The red light and the first steps come this long after the notebook is put away.
@export var climax_delay_seconds: float = 0.7
## The latch is thrown this long after the last footstep.
@export var clack_delay_seconds: float = 0.4
@export var capsule: TimeCapsule

@export_category("Hallway trap")
## The part of the hallway next to the living room: entering it with the climax under way cuts the light.
@export var hallway_trap: Area3D
## The figure standing over the capsule (see `HouseProps` kind `standing_silhouette`).
@export var silhouette: Node3D
## The beam has found the figure when it points within this many degrees of it, closer than this
## far, with nothing in between. Whenever the flashlight LIGHTS the figure (it is inside 90 percent of the
## light's own cone) it counts as found too, however far off the middle of the beam it stands: a figure the
## player can plainly see lit must never go unnoticed.
@export var beam_hit_degrees: float = 11.0
@export var beam_reach: float = 14.0
## Fallback so the reveal can never be missed: with the light on, within this far of the figure and
## looking within this many degrees of it for this long, it springs anyway.
@export var figure_dwell_distance: float = 10.0
@export var figure_dwell_degrees: float = 45.0
@export var figure_dwell_seconds: float = 1.5
## Last resort, so that the player can never be stuck: with the light on and this near the figure for this long,
## whatever the view or the beam, it springs. (Looking at it is what the trap is for; this only guarantees it.)
@export var figure_idle_distance: float = 7.0
@export var figure_idle_seconds: float = 6.0
## The very last resort: this long after the figure appears, the trap springs whatever the player does (or does not).
@export var trap_failsafe_seconds: float = 30.0
## The reveal lasts half a second; one that has not finished after this long is finished at once.
@export var reveal_failsafe_seconds: float = 3.0
## Where the figure stands, and how far towards the player it is by the end of the reveal.
@export var figure_approach_metres: float = 1.1

## Set when the player is not the node found by group "player".
@export var player: Node3D

var _stage: Stage = Stage.START
var _ficha_taken: bool = false
var _flashlight: Node = null
var _run_step: AudioStreamWAV = null
var _pantry_beat: int = 0
var _figure_dwell: float = 0.0
var _figure_idle: float = 0.0
var _trap_elapsed: float = 0.0
var _reveal_elapsed: float = 0.0
var _connected: bool = false
var _connecting: bool = false
var _connect_retry: float = 0.0
var _figure_base_position: Vector3 = Vector3.ZERO
var _figure_base_yaw: float = 0.0
var _figure_pose: StringName = &"bowed"
## What the last reveal did, beat by beat: {pose, on, energy, seconds} (for tests).
var reveal_log: Array[Dictionary] = []
var _voices_tween: Tween = null
## The tension sound's player (made when the climax starts; the tests look at it).
var tension_player: AudioStreamPlayer = null


func _ready() -> void:
	_stage = int(SaveManager.get_state_value(STATE_SECTION, KEY_STAGE, 0)) as Stage
	_ficha_taken = bool(SaveManager.get_state_value(STATE_SECTION, KEY_FICHA_TAKEN, false))
	_pantry_beat = int(SaveManager.get_state_value(STATE_SECTION, KEY_PANTRY_BEAT, 0))

	_run_step = PlaceholderAudio.make_run_step()
	argument_voices.stream = PlaceholderAudio.make_muffled_argument()
	bedroom_light.visible = false
	bedroom_light.light_energy = 0.0
	silhouette.visible = false
	hallway_trap.body_entered.connect(_on_trap_entered)
	pantry_door.opened_by_player.connect(_on_pantry_door_opened)
	_connect_to_player.call_deferred()
	_restore_stage.call_deferred()


func _connect_to_player() -> void:
	if _connected or _connecting:
		return

	_connecting = true
	var target: Node = _get_player()
	if target == null:
		await get_tree().process_frame
		target = _get_player()

	_connecting = false
	if target == null:
		# Tried again from `_process` until the player is there.
		return

	var inspect: PlayerInspectController = target.get("inspect_controller") as PlayerInspectController
	if inspect != null:
		if not inspect.inspect_opened.is_connected(_on_inspect_opened):
			inspect.inspect_opened.connect(_on_inspect_opened)

		if not inspect.inspect_closed.is_connected(_on_inspect_closed):
			inspect.inspect_closed.connect(_on_inspect_closed)

	_flashlight = target.get("flashlight_controller") as Node
	if _flashlight != null and _flashlight.has_signal("toggled_by_player"):
		if not _flashlight.is_connected("toggled_by_player", _on_flashlight_toggled):
			_flashlight.connect("toggled_by_player", _on_flashlight_toggled)

	# Without the flashlight there is nothing to watch: try again.
	_connected = inspect != null and _flashlight != null


## Picks the story up where a loaded game left it. The climax is never resumed half way (saving is
## blocked during it): a game loaded in the middle of it starts the trap over.
func _restore_stage() -> void:
	# A game loaded while the arguing was going on (the pantry door is still closed): it carries on.
	if _pantry_beat == 1:
		_fade_voices(true)

	if _ficha_taken:
		_unlock_all_doors()
		return

	match _stage:
		Stage.CLIMAX, Stage.TRAP_ARMED, Stage.TRAP_CUT, Stage.SLAMMING, Stage.SLAMMED:
			_unlock_all_doors()
			_enter_trap_armed(false)
		Stage.RESOLVED:
			# The doors stay locked until the Ficha is taken.
			for door: DoorController in _doors():
				if not door.is_locked:
					door.lock()


# ============================================================
# INSPECT: THE CLUES
# ============================================================

func _on_inspect_opened(opened_id: String) -> void:
	# The pantry note, the first time: the arguing fades in and the pantry door quietly closes.
	if StringName(opened_id) == pantry_note_id and _pantry_beat == 0 and _stage >= Stage.PANTRY_OPEN:
		_run_pantry_beat()


func _on_inspect_closed(closed_id: String) -> void:
	var id: StringName = StringName(closed_id)

	if id == recipe_id:
		if _stage == Stage.START:
			_open_pantry()
	elif id == diary_id:
		if _stage < Stage.CLIMAX:
			_run_climax()
	elif id == ficha_id and not _ficha_taken:
		_take_ficha()


# ============================================================
# THE KITCHEN: THE PANTRY OPENS
# ============================================================

func _open_pantry() -> void:
	_set_stage(Stage.PANTRY_OPEN)
	await _wait(pantry_open_delay_seconds)
	pantry_door.unlock()
	# The pantry is out of sight from the kitchen: a loud click at the door says it can be opened now.
	_unlock_click_at(pantry_door.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(unlock_to_open_seconds)
	pantry_door.force_open()


## The click of a lock giving way, loud enough to be heard from the next rooms.
func _unlock_click_at(world_position: Vector3) -> void:
	var click: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	click.stream = PlaceholderAudio.make_bolt_throw()
	click.volume_db = 4.0
	click.unit_size = 10.0
	click.max_distance = 50.0
	add_child(click)
	click.global_position = world_position
	click.finished.connect(click.queue_free)
	click.play()


# ============================================================
# THE PANTRY: THE ARGUING
# ============================================================

## The first time the pantry note is inspected: muffled arguing fades in from the hallway and, a moment
## later, the pantry door quietly closes by itself. It goes on until the player opens the door.
func _run_pantry_beat() -> void:
	_set_pantry_beat(1)
	_fade_voices(true)
	await _wait(pantry_close_delay_seconds)
	if pantry_door.is_open:
		# Slowly and with no sound (door sounds are off): the door closes behind the player.
		pantry_door.slam_shut(1.6)


## The player opens the closed pantry door: the arguing fades out and is over.
func _on_pantry_door_opened() -> void:
	if _pantry_beat == 1:
		_set_pantry_beat(2)
		_fade_voices(false)


func _set_pantry_beat(beat: int) -> void:
	_pantry_beat = beat
	SaveManager.set_state_value(STATE_SECTION, KEY_PANTRY_BEAT, beat)


## Fades the arguing in (starting it) or out (stopping it).
func _fade_voices(fade_in: bool) -> void:
	if _voices_tween != null and _voices_tween.is_valid():
		_voices_tween.kill()

	_voices_tween = create_tween()
	if fade_in:
		argument_voices.volume_db = -60.0
		argument_voices.play()
		_voices_tween.tween_property(argument_voices, "volume_db", voices_db, voices_fade_seconds)
	else:
		_voices_tween.tween_property(argument_voices, "volume_db", -60.0, voices_fade_seconds)
		_voices_tween.tween_callback(argument_voices.stop)


# ============================================================
# THE CLIMAX: RED LIGHT, RUNNING FOOTSTEPS, THE CLACK
# ============================================================

func _run_climax() -> void:
	_set_stage(Stage.CLIMAX)
	_set_saving_blocked(true)
	_set_red(true)
	_play_tension()
	await _wait(climax_delay_seconds)
	await _run_footsteps()
	await _wait(clack_delay_seconds)
	capsule.unlatch()
	_enter_trap_armed(true)


## The string tension, from the moment the notebook is put away.
func _play_tension() -> void:
	if tension_audio == null:
		return

	if tension_player == null:
		tension_player = AudioStreamPlayer.new()
		tension_player.name = "TensionSound"
		add_child(tension_player)

	tension_player.stream = tension_audio
	tension_player.volume_db = tension_volume_db
	tension_player.play()


## The red light, on or off (a quick fade in, a slow one out).
func _set_red(on: bool) -> void:
	var tween: Tween = create_tween()
	if on:
		bedroom_light.visible = true
		tween.tween_property(bedroom_light, "light_energy", red_energy, red_fade_in_seconds)
	else:
		tween.tween_property(bedroom_light, "light_energy", 0.0, red_fade_out_seconds)
		tween.tween_callback(func() -> void: bedroom_light.visible = false)


func _enter_trap_armed(from_climax: bool) -> void:
	if not from_climax:
		_set_saving_blocked(true)
		bedroom_light.visible = true
		bedroom_light.light_energy = red_energy
		capsule.unlatch(false)

	_set_stage(Stage.TRAP_ARMED)


## Running footsteps from inside the bedroom, down the hallway, into the living room: close and loud
## at first, fading away.
func _run_footsteps() -> void:
	var total: float = _path_length(run_path)
	var steps: int = int(ceilf(total / run_stride))
	for i: int in steps + 1:
		var distance: float = minf(float(i) * run_stride, total)
		run_steps.position = _point_at(run_path, distance)
		run_steps.stream = _run_step
		run_steps.volume_db = lerpf(2.0, -8.0, distance / total)
		run_steps.pitch_scale = randf_range(1.05, 1.25)
		run_steps.play()
		await _wait(run_step_seconds)


# ============================================================
# THE HALLWAY TRAP
# ============================================================

## Walking towards the living room: the flashlight dies and a still figure stands over the capsule.
func _on_trap_entered(body: Node3D) -> void:
	if _stage != Stage.TRAP_ARMED or not body.is_in_group(&"player"):
		return

	_set_stage(Stage.TRAP_CUT)
	_figure_dwell = 0.0
	_figure_idle = 0.0
	_trap_elapsed = 0.0
	_cut_flashlight()
	_figure_base_position = silhouette.position
	_figure_base_yaw = silhouette.rotation_degrees.y
	_pose_figure(&"bowed")
	silhouette.visible = true


## The watchdogs, one for each stage, in the idle frame (so they run whatever the physics are doing). They are the
## reason the trap cannot get stuck: see the header.
func _process(delta: float) -> void:
	if not _connected:
		_connect_retry -= delta
		if _connect_retry <= 0.0:
			_connect_retry = 0.5
			_connect_to_player()

	match _stage:
		Stage.TRAP_ARMED:
			# A player already standing in the hallway when the trap armed (they ran ahead of the climax) is caught here:
			# `body_entered` is only raised for one who comes in.
			var target: Node3D = _get_player()
			if target != null and hallway_trap.overlaps_body(target):
				_on_trap_entered(target)
		Stage.TRAP_CUT:
			_trap_elapsed += delta
			if _trap_elapsed >= trap_failsafe_seconds:
				push_warning("UnfinishedHouse: the trap sprang by its failsafe timer (%.0f s, flashlight %s, light on %s)." % [_trap_elapsed, str(_flashlight), str(_light_is_on())])
				_run_reveal()
		Stage.SLAMMING:
			_reveal_elapsed += delta
			if _reveal_elapsed >= reveal_failsafe_seconds:
				push_warning("UnfinishedHouse: the reveal did not finish in %.1f s; finishing it." % _reveal_elapsed)
				_finish_reveal_failsafe()
		Stage.SLAMMED:
			# Not waited for as a signal: the moment the light is on again, the house is put right.
			if _light_is_on():
				_resolve()


func _physics_process(delta: float) -> void:
	# The light can be switched on freely; the trap springs when the beam finds the figure.
	if _stage != Stage.TRAP_CUT:
		return

	if _figure_in_beam():
		_run_reveal()
		return

	# Never a soft-lock: lingering near the figure with the light on springs it anyway.
	if _light_is_on() and _figure_near_and_visible():
		_figure_dwell += delta
		if _figure_dwell >= figure_dwell_seconds:
			_run_reveal()
			return
	else:
		_figure_dwell = 0.0

	# And if even that cannot see it (some odd corner of the room), simply being near it with the light on is enough.
	var target: Node3D = _get_player()
	if target != null and _light_is_on() and target.global_position.distance_to(silhouette.global_position) <= figure_idle_distance:
		_figure_idle += delta
		if _figure_idle >= figure_idle_seconds:
			_run_reveal()
	else:
		_figure_idle = 0.0


func _on_flashlight_toggled(is_on: bool) -> void:
	# Only after the doors have slammed: the next light puts the house right.
	if is_on and _stage == Stage.SLAMMED:
		_resolve()


## The player's switch is on (the flicker that makes the lamp blink does not matter here).
func _light_is_on() -> bool:
	return _flashlight != null and bool(_flashlight.get("flashlight_on"))


## True when the flashlight is on and its beam points at the figure, near enough and in plain view.
## The beam is judged against the feet, the chest and the head, so a player standing close, looking
## at any part of it, finds it.
func _figure_in_beam() -> bool:
	var light: SpotLight3D = _flashlight as SpotLight3D
	if light == null or not silhouette.visible or not _light_is_on():
		return false

	var origin: Vector3 = light.global_position
	var forward: Vector3 = -light.global_basis.z
	var cone_degrees: float = _beam_cone_degrees(light)
	for height: float in FIGURE_AIM_HEIGHTS:
		var aim: Vector3 = silhouette.global_position + Vector3(0.0, height, 0.0)
		var to_figure: Vector3 = aim - origin
		if to_figure.length() > beam_reach:
			continue

		if rad_to_deg(forward.angle_to(to_figure)) > cone_degrees:
			continue

		if _clear_view_to(origin, aim):
			return true

	return false


## How far off the middle of the beam the figure may be and still count as found: the set angle, or most of
## the light's own cone, whichever is wider (so that whatever the light plainly lights is found).
func _beam_cone_degrees(light: SpotLight3D) -> float:
	return maxf(beam_hit_degrees, light.spot_angle * 0.9)


## Nothing solid in between (a wall or a door); the crate and the capsule around it do not count.
func _clear_view_to(origin: Vector3, aim: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, aim)
	var target: Node3D = _get_player()
	if target is CollisionObject3D:
		query.exclude = [(target as CollisionObject3D).get_rid()]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(aim) < 1.2


## The fallback: the player is close to the figure, looking its way within a wide cone, in plain view.
func _figure_near_and_visible() -> bool:
	var light: SpotLight3D = _flashlight as SpotLight3D
	if light == null or not silhouette.visible:
		return false

	var origin: Vector3 = light.global_position
	var aim: Vector3 = silhouette.global_position + Vector3(0.0, 1.0, 0.0)
	var to_figure: Vector3 = aim - origin
	if to_figure.length() > figure_dwell_distance:
		return false

	return rad_to_deg((-light.global_basis.z).angle_to(to_figure)) <= figure_dwell_degrees and _clear_view_to(origin, aim)


## The beam found it. For half a second the light is a weak, stuttering glow and each time it comes
## back the figure has changed: head bowed over the capsule, head turned right round to look back,
## standing, then nearer. Nothing is ever shown for long enough to be understood. The screen smears,
## then the light dies and every door slams shut and locks.
func _run_reveal() -> void:
	if _stage == Stage.SLAMMING or _stage == Stage.SLAMMED or _stage == Stage.RESOLVED:
		return

	_reveal_elapsed = 0.0
	_set_stage(Stage.SLAMMING)
	if _flashlight == null or not _flashlight.has_method("begin_scripted_light"):
		_slam_and_lock()
		return

	var horror: Node = get_node_or_null("/root/HorrorFilter")
	if horror != null and horror.has_method("pulse_unease"):
		horror.call("pulse_unease", 1.0, REVEAL_SECONDS)

	reveal_log.clear()
	_flashlight.call("begin_scripted_light")
	for step: Dictionary in REVEAL_STEPS:
		if step.has("pose"):
			_pose_figure(step["pose"] as StringName)
		_flashlight.call("set_scripted_light", bool(step["on"]), float(step["energy"]))
		reveal_log.append({"pose": _figure_pose, "on": bool(step["on"]), "energy": (_flashlight as SpotLight3D).light_energy, "seconds": float(step["seconds"])})
		await _wait(float(step["seconds"]))
		# The watchdog finished it already (something stalled): leave it be.
		if _stage != Stage.SLAMMING:
			return

	_flashlight.call("end_scripted_light")
	_cut_flashlight()
	_slam_and_lock()


## A reveal that stalled: the light is given back and put out, the doors slam and lock, the stage moves on.
func _finish_reveal_failsafe() -> void:
	if _flashlight != null and _flashlight.has_method("end_scripted_light"):
		_flashlight.call("end_scripted_light")

	_slam_and_lock()


## Poses the figure by name (it keeps the pose it ends on until the house is put right).
func _pose_figure(pose: StringName) -> void:
	var settings: Dictionary = FIGURE_POSES[pose]
	var lean: Node3D = silhouette.get_node("Lean") as Node3D
	var head: Node3D = silhouette.get_node("Lean/HeadPivot") as Node3D
	lean.rotation_degrees = Vector3(float(settings["lean"]), 0.0, 0.0)
	head.rotation_degrees = Vector3(float(settings["head_pitch"]), float(settings["head_yaw"]), float(settings["head_roll"]))
	(silhouette.get_node("Lean/ArmL") as Node3D).rotation_degrees = Vector3(0.0, 0.0, float(settings["arms"]))
	(silhouette.get_node("Lean/ArmR") as Node3D).rotation_degrees = Vector3(0.0, 0.0, -float(settings["arms"]))
	silhouette.rotation_degrees.y = _figure_base_yaw + float(settings["body_yaw"])
	# "Nearer" is towards the player (west, where the hallway is).
	silhouette.position = _figure_base_position + Vector3(-figure_approach_metres * float(settings["near"]), 0.0, 0.0)
	_figure_pose = pose


func _slam_and_lock() -> void:
	if _stage == Stage.SLAMMED or _stage == Stage.RESOLVED:
		return

	# The state first (the effects below can fail without leaving the house behind).
	_cut_flashlight()
	_set_stage(Stage.SLAMMED)
	for door: DoorController in _doors():
		_bang_at(door.global_position + Vector3(0.0, 1.0, 0.0))
		# An open door is slammed (fast); every door ends shut and locked.
		if door.is_open:
			door.slam_shut()
		door.lock()

	_jolt_camera(1.3)


## The house is put right: the figure is gone, the red light is gone, the capsule stands open (the Ficha can be taken).
## The essential steps come first and the decoration last.
func _resolve() -> void:
	if _stage == Stage.RESOLVED:
		return

	_set_stage(Stage.RESOLVED)
	silhouette.visible = false
	capsule.open_lid(false)
	_set_saving_blocked(false)
	_pose_figure(&"bowed")
	_set_red(false)


## For the developer console and the tests: whatever the state of the trap, the house is put right at once.
func force_resolve() -> void:
	if _flashlight != null and _flashlight.has_method("end_scripted_light"):
		_flashlight.call("end_scripted_light")

	_resolve()


# ============================================================
# THE EXIT
# ============================================================

## Lucas's Ficha is taken (its view closes): the doors unlock without a sound.
func _take_ficha() -> void:
	_ficha_taken = true
	SaveManager.set_state_value(STATE_SECTION, KEY_FICHA_TAKEN, true)
	_unlock_all_doors()
	sequence_completed.emit()


func _unlock_all_doors() -> void:
	for door: DoorController in _doors():
		door.unlock()


# ============================================================
# EFFECTS
# ============================================================

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
	if _flashlight != null and _flashlight.has_method("turn_off"):
		_flashlight.call("turn_off")


# ============================================================
# HELPERS
# ============================================================

func _set_stage(stage: Stage) -> void:
	_stage = stage
	SaveManager.set_state_value(STATE_SECTION, KEY_STAGE, int(stage))
	print("[UnfinishedHouse] stage -> ", Stage.keys()[int(stage)])


func _doors() -> Array[DoorController]:
	var doors: Array[DoorController] = []
	if doors_root != null:
		for child: Node in doors_root.get_children():
			if child is DoorController:
				doors.append(child as DoorController)

	return doors


func _set_saving_blocked(blocked: bool) -> void:
	var target: Node = _get_player()
	if target != null and target.has_method("set_manual_save_blocked"):
		target.call("set_manual_save_blocked", blocked)


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
