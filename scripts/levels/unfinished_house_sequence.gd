extends Node3D
class_name UnfinishedHouseSequence

## Orchestrates the unfinished house (the second dream puzzle). The pieces (doors, the postcard, items, the capsule) only
## raise signals; every decision lives here. Sounds are generated placeholders, and nothing is voiced yet: the lines are
## subtitles (CaptionTracks), with optional voice hooks (`memory_voice`) for the recordings to come.
##
## Room by room:
##  1. Kitchen: the recipe lies on a plank beside the sink. The first time it is read (its view closed), something falls
##     behind the player, then a latch gives at the pantry: the pantry door, locked until now, swings part way open and
##     its bare bulb comes on (and stays on for good). Reading it again plays nothing.
##  2. Pantry: once the player is all the way in, the door swings gently shut behind them (once, before the note is
##     read). The folded note and the bedroom key (`master_key`) are on the shelves; the key can be taken at any time.
##     From the moment the note is read, muffled arguing comes from the hallway whenever the player is in the pantry
##     with its door shut; opening the door cuts it at once, shutting it again brings it back. The bulb stays on and the
##     flashlight is never touched.
##  3. Bedroom: the key opens the door. Lucas's notebook lies on the bed and the nightstand drawer is empty (both
##     optional: nothing happens). Reading Lucas's unsent postcard on the nightstand plays one continuous directed scene, once,
##     with the controls taken away from beginning to end, almost still (no shaking anywhere):
##       - she is walked to the nightstand; through her eyes the postcard is taken up in one movement (she bows to it, the hand
##         lifts it, the head rises) and comes close until the paper is all there is to see, with no stop to read;
##       - under the paper the time changes (`_dissolve` of the paper alone): the scene's camera sees the postcard on the
##         nightstand exactly as she held it (`_fill_camera`), and draws slowly back into the warm room, to one held shot of the
##         postcard, the lamp and a little of the bed; Lucas and Sophia talk, unseen (subtitles, `HOUSE_BEDROOM_MEMORY`);
##       - after the last line the camera pushes back into the paper; under it, her eyes again, in the cold room; she lowers
##         the postcard back onto the nightstand; a while on the dark room;
##       - a hard cut, with the first footstep, to a camera far back, on the door's middle line and square on to the shut
##         bedroom door, which starts a slow, straight approach (the whole door always in the picture); slow, heavy steps come
##         along the hallway and stop outside; her flashlight, which points back at the nightstand where she stands, comes
##         slowly round to the door after a few steps; the handle goes down once, slowly, and stays down; the latch gives; the
##         door opens slowly, wide (about 45 degrees), and no one is there;
##       - the door camera then goes slowly to where her own camera is, turning and widening to her lens, looking at the same
##         spot, and when it is there the view is hers and the controls with it. The time capsule is unlocked from then
##         on (no key); the door is put back shut the first moment none of it is in her view.
##     Saving is blocked throughout.
##  4. Living room: the time capsule, unlocked by the scene (its own interaction): the advertisement, the two tickets and
##     Lucas's Ficha. Taking the Ficha raises `sequence_completed`. No door is ever locked by the story.
##
## Saved state (section `puzzles`): `house_recipe_done`, `house_pantry_closed_on_entry`, `house_argument_active`,
## `house_bedroom_memory_done` (the bedroom scene played, by the postcard now, or by the clock or the drawer of earlier versions),
## `house_ficha_taken`, and `house_migrated` (games saved by the old sequence are converted once, see `_migrate_legacy`). The
## capsule saves its own lid; it is unlocked by the story (no key) once the bedroom scene is done.

signal sequence_completed

const STATE_SECTION: StringName = &"puzzles"
const KEY_RECIPE_DONE: StringName = &"house_recipe_done"
const KEY_PANTRY_CLOSED: StringName = &"house_pantry_closed_on_entry"
const KEY_ARGUMENT_ACTIVE: StringName = &"house_argument_active"
const KEY_MEMORY_DONE: StringName = &"house_bedroom_memory_done"
const KEY_FICHA_TAKEN: StringName = &"house_ficha_taken"
const KEY_MIGRATED: StringName = &"house_migrated"
## Written by the old sequence (read once, by `_migrate_legacy`).
const LEGACY_KEY_STAGE: StringName = &"house_stage"
const LEGACY_KEY_PANTRY_BEAT: StringName = &"house_pantry_beat"

## The rooms, in the house's own frame (metres; see UnfinishedHouseBuilder).
const KITCHEN_AREA: AABB = AABB(Vector3(0.3, -1.0, 0.3), Vector3(4.1, 4.0, 5.7))
const PANTRY_AREA: AABB = AABB(Vector3(9.39, -1.0, 6.29), Vector3(2.235, 4.0, 2.92))

@export_category("Clues")
## `inspect_id` metadata of the Visual of each clue.
@export var recipe_id: StringName = &"kitchen_recipe"
@export var pantry_note_id: StringName = &"pantry_note"
@export var ficha_id: StringName = &"lucas_ficha"

@export_category("Pieces")
## Every door of the house (a DoorController child each).
@export var doors_root: Node3D
@export var pantry_door: DoorController
@export var bedroom_door: DoorController
@export var capsule: TimeCapsule
## Shown only while the room is not the memory.
@export var night_only: Array[Node3D] = []

@export_category("Kitchen: the pantry opens")
## The pantry's bare bulb: off until the recipe is read, then on for good. `pantry_lamp` is the bulb's prop (its glass glows).
## The light casts shadows (the walls and the ceiling keep it in the pantry and the hallway).
@export var pantry_light: OmniLight3D
@export var pantry_lamp: Node3D
@export var pantry_light_energy: float = 1.0
@export var pantry_bulb_glow: float = 2.5
## After the recipe is put away: the fall behind the player, the latch at the pantry, the door opening.
@export var fall_delay_seconds: float = 0.6
## How far behind the player the fall is heard (kept inside the kitchen).
@export var fall_distance: float = 2.2
@export var latch_delay_seconds: float = 1.6
@export var open_after_latch_seconds: float = 0.7
## The pantry door opens only this far by itself.
@export var pantry_ajar_degrees: float = 55.0

@export_category("Pantry: the door and the arguing")
## The door closes behind the player once they are in the pantry and at least this far from its hinge (out of its swing).
@export var pantry_close_clearance: float = 1.34
## Speed of that swing (lower is gentler; see `DoorController.slam_shut`).
@export var pantry_close_speed: float = 1.4
## Muffled arguing from the hallway (it plays only while the note has been read, the door is shut and the player is in).
@export var argument_voices: AudioStreamPlayer3D
@export var voices_db: float = -9.0
@export var voices_fade_in_seconds: float = 1.5
@export var voices_cut_seconds: float = 0.08
## The door counts as shut (for the arguing) within this many degrees of closed.
@export var shut_tolerance_degrees: float = 2.0

@export_category("Bedroom: the postcard scene")
## Lucas's unsent postcard on the nightstand: reading it plays the scene (once; afterwards it is read like any note).
@export var postcard: Postcard
## The warm room: the dressing (bedding, chair, cups, lamp) and its light, shown only during the memory, and only ever changed
## while the paper fills the picture. The light casts shadows (the walls keep it in the bedroom).
@export var memory_root: Node3D
@export var memory_light: OmniLight3D
@export var memory_light_energy: float = 1.6
## The memory's one held shot: where the camera stands and what it looks at (the postcard in front, the lamp to one side, a little
## of the bed behind), with `memory_fov`.
@export var memory_eye: Marker3D
@export var memory_aim: Marker3D
@export var memory_fov: float = 42.0
## Before it is picked up she is walked (slowly, looking at the postcard) to where she stands over the nightstand, as the doors
## walk her to their handle: this marker, the walk's speed, and how long it may take.
@export var postcard_stand: Marker3D
@export var approach_speed: float = 0.8
@export var approach_timeout_seconds: float = 6.0
## The door shot: where the scene's camera stands at the cut (as far back as the bed allows, the whole door in the picture) and
## where its slow, straight approach ends (still the whole door in the picture). It always looks along the shut door's normal, from
## the door's middle line, so the frame stays square on, through one lens (`door_fov`).
@export var door_front_wide: Marker3D
@export var door_front_tight: Marker3D
## The master bedroom's light for the door shot (cold fill, moon through the window, a dim pool on the door, haze, vignette): in at the
## cut over `door_light_in_seconds`, out over the walk back to her eyes.
@export var door_lighting: HouseDoorLighting
@export var door_light_in_seconds: float = 0.4
## Her flashlight in the door shot. She is standing at the nightstand, so at the cut the beam points back there (`beam_start_height`
## above the postcard), away from the door; `beam_delay_seconds` later (a few steps) it comes slowly round to the door
## (`beam_end_offset`, from its middle) over `beam_sweep_seconds`, the way a hand brings it up (an arc, never a straight line, slow
## at both ends); before and after it sways and trembles a little (`beam_sway`, metres at the door).
@export var beam_delay_seconds: float = 1.0
@export var beam_sweep_seconds: float = 2.5
@export var beam_start_height: float = 0.3
@export var beam_end_offset: Vector3 = Vector3(0.0, 0.05, 0.0)
@export var beam_arc: float = 0.3
@export var beam_sway: float = 0.06
## Optional voice hooks (empty: subtitles only). The memory recording is timed like HOUSE_BEDROOM_MEMORY from its start.
@export var memory_voice: AudioStream
@export var memory_voice_player: AudioStreamPlayer3D

@export_group("The postcard in her hands")
## The postcard is picked up in one movement, the putting down of it played backwards (`lift_seconds`): she bows to the nightstand,
## the hand takes it up with a small arc (`held_arc`), the head rises, and the card comes close (`fill_distance`) while her lens
## narrows, until the paper covers the whole picture (`fill_margin` of the card's width or height is all the picture shows,
## whichever is tighter for the screen), tipped `fill_tilt_degrees` towards her. A moment still (`fill_hold_seconds`), and the
## matched change of time under the paper (`paper_dissolve_seconds`, the paper only).
@export var lift_seconds: float = 3.0
@export var held_arc: float = 0.05
## The bow: the camera sinks and tips down, and rises again, down quicker than up, never at a constant speed.
@export var bow_offset: Vector3 = Vector3(0.0, -0.07, -0.1)
@export var bow_pitch_degrees: float = -10.0
## Where the card is between the nightstand and the close pose: `read_distance` away and `read_low` under her eyes.
@export var read_distance: float = 0.26
@export var read_low: float = 0.0
## Once it is held at the reading distance the picture zooms in on it (the lens narrows, the card does not move) until the paper is
## all there is to see: `zoom_seconds`.
@export var zoom_seconds: float = 2.0
@export var fill_distance: float = 0.26
@export var fill_tilt_degrees: float = 12.0
@export_range(0.5, 1.0, 0.01) var fill_margin: float = 0.86
@export var fill_hold_seconds: float = 2.3
@export var paper_dissolve_seconds: float = 0.8
## From the paper the camera draws slowly back to the memory shot; the voices begin `conversation_after_seconds` into it.
@export var pullback_seconds: float = 6.0
@export var conversation_after_seconds: float = 4.0

@export_group("Back to the night")
## After the last line (and its hold, which is in the track): the slow push back into the paper, still, the change back under it,
## a moment, the postcard lowered back onto the nightstand, and her own eyes on the dark room before the first step.
@export var push_seconds: float = 4.0
@export var push_hold_seconds: float = 0.3
@export var return_hold_seconds: float = 0.4
@export var lower_seconds: float = 3.0
@export var night_seconds: float = 2.0

@export_group("The door")
## The door camera's one lens (degrees); its slow approach from the cut to the open door (`door_approach_seconds`).
@export var door_fov: float = 40.0
@export var door_approach_seconds: float = 20.0
## The footsteps in the hallway, house-local points: towards the bedroom door, a step every `step_interval_seconds` (slowing
## to `step_interval_end_seconds` at the door), `step_stride` metres apart, louder as they come. The first is heard with the cut.
## The sound is the player's own indoor step (`walk.wav`), lower and heavier. They are heard from the door camera
## (`step_unit_size`: louder further off; `step_max_distance`).
@export var footstep_path: Array[Vector3] = [Vector3(1.4, 0.08, 8.0), Vector3(2.6, 0.08, 7.35), Vector3(6.0, 0.08, 7.3), Vector3(7.45, 0.08, 6.9)]
@export var step_stride: float = 0.8
## The run begins this long before the cut to the door, while the postcard is being put away (heard far off, from her eyes).
@export var steps_lead_seconds: float = 3.6
@export var step_interval_seconds: float = 0.62
@export var step_interval_end_seconds: float = 0.7
## How uneven the running is (a share of the interval, either way), so it is never a metronome.
@export_range(0.0, 0.4, 0.01) var step_unevenness: float = 0.06
@export var first_step_db: float = -4.0
@export var last_step_db: float = 14.0
@export var step_unit_size: float = 5.0
@export var step_max_distance: float = 30.0
@export var step_pitch: Vector2 = Vector2(0.8, 0.9)
## The outside (wind, night) is pushed back this much while the steps and the door play (`OutdoorAmbience.set_muffle`).
@export_range(0.0, 1.0, 0.05) var footsteps_duck: float = 0.6
## From the cut to the handle moving; the press; held down; the latch; the door opening, slowly, to `crack_degrees` (about 45:
## wide open, and no one on the other side); held open `open_hold_seconds`. The whole runs about `door_approach_seconds`.
## The handle moves this long after the steps stop (a breath), quickly: only the door's opening is slow.
@export var handle_after_steps_seconds: float = 0.4
## The tension recording (`placeholder_string_tension`): in as the door begins to open over `tension_in_seconds`, out over the walk to her eyes.
@export var tension_db: float = 0.0
@export var tension_in_seconds: float = 3.0
## The handle's sound at the press (a little slower, heavier) and when it is let go.
@export var handle_sound_pitch: float = 0.75
@export var handle_release_seconds: float = 1.2
## The handle comes back up (and the tension begins) this long into the opening, once the door has moved a few centimetres: it is unlocked, and only needs pushing.
@export var handle_release_delay_seconds: float = 1.6
@export var handle_press_seconds: float = 0.7
@export var handle_hold_seconds: float = 0.4
@export var latch_pause_seconds: float = 0.15
@export var crack_degrees: float = 45.0
@export var crack_seconds: float = 13.0
@export var open_hold_seconds: float = 2.0

@export_group("Back to her eyes")
## The door camera goes slowly to where her own camera is (`eyes_blend_seconds`), turning and widening to her lens as it goes, the
## two looking at the same spot (the open door). When it is there the view is hers, and the controls with it.
@export var eyes_blend_seconds: float = 5.0

## Set when the player is not the node found by group "player".
@export var player: Node3D

var _recipe_done: bool = false
var _pantry_closed: bool = false
var _argument_active: bool = false
var _memory_done: bool = false
var _ficha_taken: bool = false

var _connected: bool = false
var _connect_retry: float = 0.0
var _kitchen_running: bool = false
var _awaiting_latch: bool = false
var _voices_on: bool = false
var _voices_tween: Tween = null

## The scene in the bedroom: true while it plays; each run has its own number, so a cancelled one stops at its next step.
var memory_running: bool = false
var _run: int = 0
var _tweens: Array[Tween] = []
var _held: Node = null
var _held_view_locked: bool = false
var _held_scripted_flashlight: bool = false
var _held_save_block: bool = false
var _held_motion_still: bool = false
## What the scene did, in order (for tests): {"beat": StringName, "time": seconds since it began}.
var memory_log: Array[Dictionary] = []
## Seconds of game time since the scene began (it stands still while the game is paused).
var scene_clock: float = 0.0
## The room as the memory has it (warm), or the night.
var in_memory: bool = false

# The scene's camera (made when it starts), the one showing (null: the player's own eyes), and its shot: a move from one
# transform to another and a lens from one field of view to another, each over its own time (eased in and out).
var _cinema: Camera3D = null
var _cam: Camera3D = null
var _move_from: Transform3D = Transform3D.IDENTITY
var _move_to: Transform3D = Transform3D.IDENTITY
var _move_t: float = 1.0
var _move_seconds: float = 0.0
var _lens_from: float = 75.0
var _lens_to: float = 75.0
var _lens_t: float = 1.0
var _lens_seconds: float = 0.0
## The still of the last frame that the dissolves fade away (see `_dissolve`).
var _freeze_layer: CanvasLayer = null
## The postcard in her hands (a copy of its model; the postcard itself is hidden meanwhile). Where it is held is worked out every
## frame from her eyes (`_place_held_card`): `_held_weight` from the nightstand (0) to her hands (1), `_held_near` from reading (0)
## to filling the picture (1). `_fill_at` is the scene camera that sees the postcard on the nightstand as her eyes see the held one
## at its closest (`_fill_rel`: the postcard in that camera's frame), through `_fill_fov` (her lens narrows to it; `_fill_fov_used`
## is the lens actually reached at the change of time). `_base_fov` is her own lens.
var held_card: Node3D = null
var _held_weight: float = 0.0
var _held_near: float = 0.0
var _held_from: Transform3D = Transform3D.IDENTITY
var _fill_at: Transform3D = Transform3D.IDENTITY
var _fill_rel: Transform3D = Transform3D.IDENTITY
var _fill_fov: float = 30.0
var _fill_fov_used: float = 30.0
var _base_fov: float = 75.0
## Left for after the scene: the door put back shut, the first moment it is out of her sight.
var _door_reset_pending: bool = false
var _ducking: bool = false

var _flashlight: Node = null
var _flashlight_scripted: bool = false
var _flashlight_available: bool = false
var _step_sound: AudioStream = null
## The head bowed to the nightstand, 0 to 1 (see `bow_offset`), and whether she is being walked to it.
var _bow: float = 0.0
var _approaching: bool = false
var _approach_save_block: bool = false
var _held_gesture_direct: bool = false
## The flashlight's sweep to the door.
var _beam_on: bool = false
## The walker has stopped outside the door: the handle goes at once.
var _steps_done: bool = false
var _tension: AudioStreamPlayer = null
const TENSION_PATH: String = "res://assets/audios/placeholder_string_tension.mp3"
var _beam_time: float = 0.0
var _beam_from: Vector3 = Vector3.ZERO
var _beam_to: Vector3 = Vector3.ZERO


func _ready() -> void:
	_migrate_legacy()
	_recipe_done = _get_flag(KEY_RECIPE_DONE)
	_pantry_closed = _get_flag(KEY_PANTRY_CLOSED)
	_argument_active = _get_flag(KEY_ARGUMENT_ACTIVE)
	_memory_done = _get_flag(KEY_MEMORY_DONE)
	_ficha_taken = _get_flag(KEY_FICHA_TAKEN)

	if argument_voices != null:
		argument_voices.stream = PlaceholderAudio.make_muffled_argument()
		argument_voices.stop()

	if postcard != null:
		postcard.scene_requested.connect(_on_postcard_scene_requested)

	_restore()
	_connect_to_player.call_deferred()


## Puts the house as the saved story left it.
func _restore() -> void:
	_set_pantry_lamp(_recipe_done, false)
	# The kitchen beat was cut short (a save in the second between reading and the latch): the pantry opens now.
	if _recipe_done and pantry_door != null and pantry_door.is_locked:
		pantry_door.unlock()
		pantry_door.force_open(0.0, pantry_ajar_degrees)

	_set_room(false)
	_unlock_capsule()
	if postcard != null:
		postcard.plays_scene = not _memory_done


## Games saved by the old sequence (`house_stage`, `house_pantry_beat`) are converted once: what was reached is kept,
## what no longer exists (the red light, the trap, the locked exit) is dropped. Safe to run on any game, any number of
## times (it marks itself done).
func _migrate_legacy() -> void:
	if _get_flag(KEY_MIGRATED):
		return

	var stage: int = int(SaveManager.get_state_value(STATE_SECTION, LEGACY_KEY_STAGE, 0))
	var beat: int = int(SaveManager.get_state_value(STATE_SECTION, LEGACY_KEY_PANTRY_BEAT, 0))
	var recipe_read: bool = bool(SaveManager.get_state_value(&"triggers", &"house_recipe_open", false))

	if stage >= 1 or beat >= 1 or recipe_read:
		_set_flag(KEY_RECIPE_DONE, true)
	if beat >= 1:
		_set_flag(KEY_ARGUMENT_ACTIVE, true)
		_set_flag(KEY_PANTRY_CLOSED, true)
	# The old climax came after the bedroom was opened with its key.
	if stage >= 2 and bedroom_door != null:
		bedroom_door.unlock()
	# The capsule already stands open: there is nothing for the scene to unlock.
	if _capsule_open():
		_set_flag(KEY_MEMORY_DONE, true)

	# The old trap locked every door until the Ficha was taken; nothing locks them now.
	for door: DoorController in _doors():
		if door != pantry_door and door != bedroom_door and door.is_locked:
			door.unlock()

	_set_flag(KEY_MIGRATED, true)


func _connect_to_player() -> void:
	var target: Node = _get_player()
	if target == null:
		return

	var inspect: PlayerInspectController = target.get("inspect_controller") as PlayerInspectController
	if inspect == null:
		return

	if not inspect.inspect_opened.is_connected(_on_inspect_opened):
		inspect.inspect_opened.connect(_on_inspect_opened)
	if not inspect.inspect_closed.is_connected(_on_inspect_closed):
		inspect.inspect_closed.connect(_on_inspect_closed)
	_connected = true


func _exit_tree() -> void:
	_cancel_memory()


func _process(delta: float) -> void:
	if not _connected:
		_connect_retry -= delta
		if _connect_retry <= 0.0:
			_connect_retry = 0.5
			_connect_to_player()

	if memory_running and _held != null and is_instance_valid(_held):
		if bool(_held.call("is_inventory_open")):
			# The inventory is the one thing a held view still lets the player open: not during this scene.
			var inventory_ui: Node = _held.get("inventory_ui_controller") as Node
			if inventory_ui != null:
				inventory_ui.call("close")

		scene_clock += delta
		_drive_camera(delta)
		_place_held_card()
		_apply_bow()
		if _beam_on:
			_drive_beam(delta)
	if _door_reset_pending:
		_settle_pending(false)


func _physics_process(_delta: float) -> void:
	_update_pantry()


# ============================================================
# INSPECT: THE CLUES
# ============================================================

func _on_inspect_opened(opened_id: String) -> void:
	# Reading the pantry note: from now on the arguing is heard whenever the player is shut in the pantry.
	if StringName(opened_id) == pantry_note_id and not _argument_active:
		_argument_active = true
		_set_flag(KEY_ARGUMENT_ACTIVE, true)


func _on_inspect_closed(closed_id: String) -> void:
	var id: StringName = StringName(closed_id)
	if id == recipe_id:
		if not _recipe_done and not _kitchen_running:
			_run_kitchen_beat()
	elif id == ficha_id and not _ficha_taken:
		_ficha_taken = true
		_set_flag(KEY_FICHA_TAKEN, true)
		sequence_completed.emit()


# ============================================================
# THE KITCHEN: SOMETHING FALLS, THE PANTRY OPENS
# ============================================================

func _run_kitchen_beat() -> void:
	_kitchen_running = true
	# The state first: a save from here on finds the pantry open (see `_restore`).
	_recipe_done = true
	_set_flag(KEY_RECIPE_DONE, true)

	await _wait(fall_delay_seconds)
	_play_fall_behind_player()

	await _wait(latch_delay_seconds)
	if pantry_door != null:
		_play_at(PlaceholderAudio.make_bolt_throw(), pantry_door.global_position + Vector3(0.0, 1.0, 0.0), 2.0, 1.0, 10.0, 50.0)
		pantry_door.unlock()

	await _wait(open_after_latch_seconds)
	if pantry_door != null:
		pantry_door.force_open(0.0, pantry_ajar_degrees)
	_set_pantry_lamp(true, true)
	_kitchen_running = false


## Behind the player, on the kitchen floor: a foot slipping, a body hitting the boards, something small rolling away.
func _play_fall_behind_player() -> void:
	var target: Node3D = _get_player()
	var camera: Camera3D = _get_camera()
	if target == null:
		return

	var back: Vector3 = camera.global_basis.z if camera != null else target.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var local: Vector3 = to_local(target.global_position + back * fall_distance)
	local = local.clamp(KITCHEN_AREA.position, KITCHEN_AREA.end)
	local.y = 0.15
	var at: Vector3 = to_global(local)

	_play_at(PlaceholderAudio.make_footstep(), at, -6.0, 1.3)
	_play_at_later(PlaceholderAudio.make_door_thud(), at, -2.0, 0.75, 0.12)
	_play_at_later(PlaceholderAudio.make_coin_clatter(), at + Vector3(0.3, 0.0, 0.2), -14.0, 0.7, 0.45)


## The bulb on or off (`fade`: it comes up over a moment, as an old filament does).
func _set_pantry_lamp(on: bool, fade: bool) -> void:
	var glass: StandardMaterial3D = _bulb_material()
	if pantry_light != null:
		pantry_light.visible = on
		if on and fade:
			pantry_light.light_energy = 0.0
			_track(create_tween()).tween_property(pantry_light, "light_energy", pantry_light_energy, 0.35)
		else:
			pantry_light.light_energy = pantry_light_energy if on else 0.0

	if glass != null:
		glass.emission_energy_multiplier = pantry_bulb_glow if on else 0.0


func _bulb_material() -> StandardMaterial3D:
	if pantry_lamp == null:
		return null

	var bulb: MeshInstance3D = pantry_lamp.get_node_or_null(^"Bulb") as MeshInstance3D
	return bulb.material_override as StandardMaterial3D if bulb != null else null


func is_pantry_lamp_on() -> bool:
	return pantry_light != null and pantry_light.visible and pantry_light.light_energy > 0.0


# ============================================================
# THE PANTRY: THE DOOR CLOSES, THE ARGUING
# ============================================================

func _update_pantry() -> void:
	if pantry_door == null:
		return

	var inside: bool = is_player_in_pantry()

	# Once, on the way in: the door swings shut behind the player (before the note is read).
	if _recipe_done and not _pantry_closed and inside and not _kitchen_running:
		if not pantry_door.is_open:
			# The player shut it themselves.
			_mark_pantry_closed()
		elif not pantry_door.is_busy() and _clear_of_pantry_door():
			_mark_pantry_closed()
			pantry_door.slam_shut(pantry_close_speed)
			_awaiting_latch = true

	if _awaiting_latch:
		if pantry_door.is_open:
			_awaiting_latch = false
		elif _door_offset_degrees(pantry_door) < 1.0:
			_awaiting_latch = false
			_play_at(PlaceholderAudio.make_door_latch_close(), pantry_door.global_position + Vector3(0.0, 1.0, 0.0), -8.0)

	var wanted: bool = _argument_active and inside and is_pantry_door_shut()
	if wanted != _voices_on:
		_set_voices(wanted)


func _mark_pantry_closed() -> void:
	_pantry_closed = true
	_set_flag(KEY_PANTRY_CLOSED, true)


## The player is far enough from the hinge that the swinging leaf cannot touch them.
func _clear_of_pantry_door() -> bool:
	var target: Node3D = _get_player()
	if target == null:
		return false

	var flat: Vector3 = target.global_position - pantry_door.global_position
	flat.y = 0.0
	return flat.length() >= pantry_close_clearance


func is_player_in_pantry() -> bool:
	var target: Node3D = _get_player()
	return target != null and PANTRY_AREA.has_point(to_local(target.global_position))


## Shut, and not just swinging towards shut.
func is_pantry_door_shut() -> bool:
	return pantry_door != null and not pantry_door.is_open and _door_offset_degrees(pantry_door) <= shut_tolerance_degrees


func is_argument_playing() -> bool:
	return _voices_on


func _door_offset_degrees(door: DoorController) -> float:
	if door.hinge == null:
		return 0.0

	return absf(angle_difference(deg_to_rad(door.hinge.rotation_degrees.y), deg_to_rad(door.closed_rotation_degrees.y))) * 180.0 / PI


## Fades the arguing in, or cuts it (an opening door cuts it at once).
func _set_voices(on: bool) -> void:
	_voices_on = on
	if argument_voices == null:
		return

	if _voices_tween != null and _voices_tween.is_valid():
		_voices_tween.kill()

	_voices_tween = create_tween()
	if on:
		argument_voices.volume_db = -60.0
		argument_voices.play()
		_voices_tween.tween_property(argument_voices, "volume_db", voices_db, voices_fade_in_seconds)
	else:
		_voices_tween.tween_property(argument_voices, "volume_db", -60.0, voices_cut_seconds)
		_voices_tween.tween_callback(argument_voices.stop)


# ============================================================
# THE BEDROOM: THE POSTCARD AND THE DOOR
# ============================================================

func _on_postcard_scene_requested(_who: Node) -> void:
	if not _memory_done and not memory_running:
		_play_memory()


## For the developer console (`house_postcard`): plays the scene again from where the player stands. Nothing else is reset (a key
## already taken does not come back). False when it is already playing or there is nobody to show it to.
func replay_bedroom_scene() -> bool:
	if memory_running or _get_movement() == null:
		return false

	_memory_done = false
	_play_memory()
	return memory_running


func _play_memory() -> void:
	var target: Node = _get_player()
	var movement: PlayerMovementController = _get_movement()
	if target == null or movement == null or movement.camera == null or postcard == null or memory_eye == null or memory_aim == null or door_front_wide == null or door_front_tight == null:
		# Nobody to show it to: the key is simply there.
		_finish_memory_state()
		return

	# Whatever the last scene left for later is done now.
	_settle_pending(true)
	_run += 1
	var run: int = _run
	memory_running = true
	memory_log.clear()
	scene_clock = 0.0
	# Walked to the nightstand first, as the doors walk her to the handle (before she is held: a held view does not walk).
	if not await _walk_to_nightstand(run, target, movement):
		return
	# (The postcard's reading stays the scene's until it is over: using it again meanwhile asks for the scene, which is
	# already playing, and nothing happens.)

	if not await _shot_read(run): return
	if not await _shot_conversation(run): return
	if not await _shot_return(run): return
	if not await _shot_door(run): return
	if not await _shot_to_eyes(run): return

	# What the scene leaves behind is settled before the player can save again.
	memory_running = false
	_tweens.clear()
	_finish_memory_state()
	_release_player()
	_log(&"released")


# ---- Walking up to the nightstand ---------------------------------------------------------------------------------

## She is walked, slowly and looking at the postcard, to where she stands over the nightstand, unless she is already there. Saving
## is blocked from the first step; the walk ends as the sequence holds her. False if the scene was cancelled meanwhile.
func _walk_to_nightstand(run: int, target: Node, movement: PlayerMovementController) -> bool:
	_approach_save_block = bool(target.get("manual_save_blocked"))
	target.call("set_manual_save_blocked", true)
	_approaching = true
	if postcard_stand != null:
		var stand: Vector3 = postcard_stand.global_position
		stand.y = (target as Node3D).global_position.y
		var flat: Vector3 = (target as Node3D).global_position - stand
		flat.y = 0.0
		if flat.length() > 0.12 and movement.begin_guided_walk(stand, postcard.global_position, approach_speed, approach_timeout_seconds):
			_log(&"approach")
			var waited: float = 0.0
			while movement.is_guided_walking() and waited < approach_timeout_seconds + 1.0:
				await get_tree().process_frame
				waited += get_process_delta_time()
				if not _still(run):
					return false
			movement.cancel_guided_walk()
	_approaching = false
	if not _still(run):
		return false
	# (Held next: `_hold_player` takes saving back as it found it.)
	target.call("set_manual_save_blocked", _approach_save_block)
	# The frame the player sees now is where the reading starts.
	_hold_player(target)
	CaptionManager.clear()
	_log(&"start")
	return true


# ---- The postcard in her hands, and into the memory ---------------------------------------------------------------

## Through her eyes the postcard comes up from the nightstand into her hands, written side to her, and she reads it; she brings it
## close until the paper is all there is to see; under the paper the time changes (the scene's camera sees the postcard on the
## nightstand exactly as she held it: the same writing on the same pixels), and the camera draws slowly back from it into the warm
## room. The bedroom door is shut while the paper covers everything.
func _shot_read(run: int) -> bool:
	_log(&"lift")
	var card: Transform3D = postcard.get_visual_node().global_transform
	_fill_at = _fill_camera()
	_fill_fov = _fill_lens()
	_fill_rel = _fill_at.affine_inverse() * card
	_base_fov = _get_camera().fov
	_take_up_card()
	# One movement, the putting down of it played backwards: she bows to the nightstand, the hand takes the card up (slow at both
	# ends), the head rises, and the card comes close until the paper is all there is to see; no stop to read it.
	_tween_held(&"_bow", 1.0, lift_seconds * 0.3, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_bow", 0.0, lift_seconds * 0.58, lift_seconds * 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_held_weight", 1.0, lift_seconds * 0.62, lift_seconds * 0.18, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	# Held at the reading distance, the picture then zooms in on it until the paper fills the picture.
	_tween_held(&"_held_near", 1.0, zoom_seconds, lift_seconds * 0.85, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await _wait(lift_seconds * 0.85 + zoom_seconds + fill_hold_seconds)
	if not _still(run):
		return false

	_log(&"dissolve_in")
	_fill_fov_used = _get_camera().fov
	_dissolve(paper_dissolve_seconds)
	_set_room(true)
	held_card.visible = false
	postcard.visible = true
	_show_camera(_fill_at, _fill_fov_used)
	if bedroom_door != null:
		bedroom_door.close_instantly()
	_log(&"door_closed")
	await _wait(paper_dissolve_seconds)
	if not _still(run):
		return false

	_log(&"pullback")
	_move_camera(_memory_shot(), pullback_seconds)
	_change_lens(memory_fov, pullback_seconds)
	await _wait(conversation_after_seconds)
	return _still(run)


## The camera that has the postcard on the nightstand fill the picture: straight over its written side, tipped
## `fill_tilt_degrees` towards the foot of the writing, `fill_distance` away, the writing upright.
func _fill_camera() -> Transform3D:
	var card: Transform3D = postcard.get_visual_node().global_transform
	var normal: Vector3 = card.basis.z.normalized()
	var up: Vector3 = card.basis.y.normalized()
	var tilt: float = deg_to_rad(fill_tilt_degrees)
	var eye: Vector3 = card.origin + (normal * cos(tilt) - up * sin(tilt)) * fill_distance
	return Transform3D(Basis.looking_at(card.origin - eye, up), eye)


## The lens (vertical field of view, degrees) at which the paper, `fill_distance` away, covers the whole picture with a margin.
func _fill_lens() -> float:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = size.x / maxf(size.y, 1.0)
	var tilt: float = deg_to_rad(fill_tilt_degrees)
	var height: float = minf(HouseProps.POSTCARD_SIZE.y * cos(tilt), HouseProps.POSTCARD_SIZE.x / aspect) * fill_margin
	return rad_to_deg(2.0 * atan(height * 0.5 / fill_distance))


func _memory_shot() -> Transform3D:
	var eye: Vector3 = memory_eye.global_position
	return Transform3D(Basis.looking_at(memory_aim.global_position - eye, Vector3.UP), eye)


## A copy of the postcard's model, where the postcard lies, in place of it.
func _take_up_card() -> void:
	_drop_held_card()
	var visual: Node3D = postcard.get_visual_node()
	held_card = visual.duplicate() as Node3D
	held_card.name = "HeldPostcard"
	add_child(held_card)
	_held_from = visual.global_transform
	_held_weight = 0.0
	_held_near = 0.0
	held_card.global_transform = _held_from
	postcard.visible = false


func _tween_held(property: StringName, value: float, seconds: float, delay: float = 0.0, trans: Tween.TransitionType = Tween.TRANS_SINE, ease_kind: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	var move: Tween = _track(create_tween())
	move.tween_property(self, NodePath(String(property)), value, maxf(seconds, 0.01)).set_delay(delay).set_trans(trans).set_ease(ease_kind)


## Where the held postcard is, every frame, from her eyes: between the nightstand (`_held_weight` 0) and her hands (1), and in her
## hands between reading (`_held_near` 0) and filling the picture (1), her lens narrowing with it.
func _place_held_card() -> void:
	if held_card == null or not is_instance_valid(held_card) or not held_card.visible:
		return

	var eye: Transform3D = _get_camera().global_transform.orthonormalized()
	var near: float = clampf(_held_near, 0.0, 1.0)
	var back: Vector3 = Vector3(0.0, -read_low, -(read_distance - fill_distance)) * (1.0 - near)
	var held: Transform3D = eye * Transform3D(Basis.IDENTITY, back) * _fill_rel
	var weight: float = clampf(_held_weight, 0.0, 1.0)
	var pose: Transform3D = _held_from.interpolate_with(held, weight)
	# Up a little on the way, as a hand lifts a thing and sets it down (nothing at either end).
	pose.origin += Vector3.UP * sin(PI * weight) * held_arc
	held_card.global_transform = pose
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		movement.scripted_fov = lerpf(_base_fov, _fill_fov, near) if near > 0.0 else 0.0
		# Her lens follows at once (the controller's own easing would lag a little behind the card, and the paper must be where the
		# scene's camera will have it).
		if near > 0.0 and movement.camera != null:
			movement.camera.fov = movement.scripted_fov


## The bow: the head sinks to the nightstand and tips down, as a gesture the movement controller applies as it is (direct).
func _apply_bow() -> void:
	var movement: PlayerMovementController = _get_movement()
	if movement == null or _held == null:
		return

	movement.gesture_direct = true
	movement.gesture_offset = bow_offset * _bow
	movement.gesture_pitch_degrees = bow_pitch_degrees * _bow


## The held copy goes and the postcard lies on the nightstand again; her lens is her own.
func _drop_held_card() -> void:
	if held_card != null and is_instance_valid(held_card):
		held_card.queue_free()
	held_card = null
	if postcard != null:
		postcard.visible = true
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		movement.scripted_fov = 0.0


# ---- The conversation ---------------------------------------------------------------------------------------------

## The voices, over the one held shot of the postcard (the track ends with a held silence after the last line).
func _shot_conversation(run: int) -> bool:
	_log(&"conversation")
	if memory_voice != null and memory_voice_player != null:
		memory_voice_player.stream = memory_voice
		memory_voice_player.play()
	await CaptionManager.play_scripted_and_wait(CaptionTracks.HOUSE_BEDROOM_MEMORY)
	return _still(run)


# ---- Back to the night --------------------------------------------------------------------------------------------

## The camera pushes slowly back into the paper; under it the time changes back (her eyes, the postcard in her hands, close, in
## the cold room); she lowers it back onto the nightstand; her eyes rest on the dark room a while.
func _shot_return(run: int) -> bool:
	_log(&"return")
	if memory_voice_player != null:
		memory_voice_player.stop()
	_move_camera(_fill_at, push_seconds)
	_change_lens(_fill_fov_used, push_seconds)
	await _wait(push_seconds + push_hold_seconds)
	if not _still(run):
		return false

	_log(&"dissolve_out")
	_dissolve(paper_dissolve_seconds)
	_set_room(false)
	postcard.visible = false
	_held_weight = 1.0
	_held_near = 1.0
	held_card.visible = true
	var camera: Camera3D = _get_camera()
	_get_movement().scripted_fov = _fill_fov_used
	camera.fov = _fill_fov_used
	_place_held_card()
	_show_eyes()
	_log(&"night")
	await _wait(paper_dissolve_seconds + return_hold_seconds)
	if not _still(run):
		return false

	_log(&"lower")
	_steps_after(run, maxf(lower_seconds + night_seconds - steps_lead_seconds, 0.0))
	_tween_held(&"_held_near", 0.0, lower_seconds * 0.34, 0.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_held_weight", 0.0, lower_seconds * 0.62, lower_seconds * 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	_tween_held(&"_bow", 1.0, lower_seconds * 0.58, lower_seconds * 0.12, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_tween_held(&"_bow", 0.0, lower_seconds * 0.3, lower_seconds * 0.7, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await _wait(lower_seconds)
	if not _still(run):
		return false
	_drop_held_card()
	_log(&"settled")
	await _wait(night_seconds)
	return _still(run)


## The running begins part way through the putting away, so it is heard far off before the cut.
func _steps_after(run: int, delay: float) -> void:
	await _wait(delay)
	if not _still(run):
		return
	_duck_outside(true)
	_walk_to_door(run)


# ---- The door -----------------------------------------------------------------------------------------------------

## A hard cut, with the first footstep, to the door square on from far back; the camera starts its slow, straight approach at once.
## The steps come along the hallway and stop, the light under the door is broken, the handle goes down once and stays down, the
## latch gives, a crack opens slowly, and an edge begins to come in.
func _shot_door(run: int) -> bool:
	# Her eyes turn to the door unseen (her flashlight lights it for the door shot), and settle before the cut.
	_look_at_point(_door_middle(), 0.0)
	await get_tree().physics_frame
	if not _still(run):
		return false

	_duck_outside(true)
	if door_lighting != null:
		door_lighting.fade_to(1.0, door_light_in_seconds)
	var facing: Basis = _door_facing(door_front_wide.global_position)
	_show_camera(Transform3D(facing, door_front_wide.global_position), door_fov)
	_move_camera(Transform3D(facing, door_front_tight.global_position), door_approach_seconds)
	_log(&"door")
	_beam_start()

	while not _steps_done and _still(run):
		await get_tree().process_frame
	if not _still(run):
		return false
	await _wait(handle_after_steps_seconds)
	if not _still(run):
		return false
	_log(&"handle")
	bedroom_door.play_handle_sound(handle_sound_pitch)

	var press: Tween = _track(create_tween())
	press.tween_method(bedroom_door.set_handle_turn, 0.0, 1.0, handle_press_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await press.finished
	if not _still(run):
		return false
	await _wait(handle_hold_seconds)
	if not _still(run):
		return false

	_log(&"latch")

	await _wait(latch_pause_seconds)
	if not _still(run):
		return false

	_log(&"crack")
	var crack: Tween = _track(create_tween())
	crack.tween_property(bedroom_door, "ajar_degrees", crack_degrees, crack_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(handle_release_delay_seconds)
	if not _still(run):
		return false
	_log(&"handle_release")
	_tension_start()
	bedroom_door.play_handle_sound(handle_sound_pitch * 0.9)
	var release: Tween = _track(create_tween())
	release.tween_method(bedroom_door.set_handle_turn, 1.0, 0.0, handle_release_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await crack.finished
	if not _still(run):
		return false

	# Wide open, and no one there.
	_log(&"open")
	# The door stays as it is: an ordinary open door from here on.
	await _wait(open_hold_seconds)
	if not _still(run):
		return false

	bedroom_door.ajar_degrees = 0.0
	bedroom_door.force_open(0.0, crack_degrees)
	return true


## Square on to the shut door from `eye`: looking along the door's normal, towards it.
func _door_facing(eye: Vector3) -> Basis:
	var normal: Vector3 = bedroom_door.global_basis.z
	normal.y = 0.0
	normal = normal.normalized()
	if normal.dot(bedroom_door.global_position - eye) < 0.0:
		normal = -normal
	return Basis.looking_at(normal, Vector3.UP)


## Someone walks along the hallway to the bedroom door, slowly and heavily, louder as they come, and stops outside it; with the
## last steps their the camera is square on to the shut door.
func _walk_to_door(run: int) -> void:
	var points: Array[Vector3] = _path_points(footstep_path, step_stride)
	if _step_sound == null:
		_step_sound = _indoor_step()

	_log(&"steps")
	_steps_done = false
	for index: int in points.size():
		var along: float = float(index) / float(maxi(points.size() - 1, 1))
		var at: Vector3 = to_global(points[index])
		var loudness: float = along
		_play_at(_step_sound, at, lerpf(first_step_db, last_step_db, loudness), randf_range(step_pitch.x, step_pitch.y), step_unit_size, step_max_distance)
		if index == points.size() - 1:
			break

		var interval: float = lerpf(step_interval_seconds, step_interval_end_seconds, along)
		await _wait(interval * randf_range(1.0 - step_unevenness, 1.0 + step_unevenness))
		if not _still(run):
			return
	_log(&"steps_end")
	_steps_done = true


## The tension recording, a flat (not placed) sound that comes in from the last step and goes out as the view goes back to her.
func _tension_start() -> void:
	if _tension == null:
		_tension = AudioStreamPlayer.new()
		_tension.stream = load(TENSION_PATH) as AudioStream
		add_child(_tension)
	_tension.volume_db = -60.0
	_tension.play()
	var rise: Tween = _track(create_tween())
	rise.tween_property(_tension, "volume_db", tension_db, tension_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _tension_stop(seconds: float) -> void:
	if _tension == null or not _tension.playing:
		return
	if seconds <= 0.0:
		_tension.stop()
		return
	var fall: Tween = _track(create_tween())
	fall.tween_property(_tension, "volume_db", -60.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.tween_callback(_tension.stop)


## The player's own indoor footstep (the default of their `sfx_walk`), for the walker in the hallway.
func _indoor_step() -> AudioStream:
	var body: Node3D = _get_player()
	var audio: Node = body.get("audio_controller") as Node if body != null else null
	if audio != null:
		var step: AudioStream = audio.get("_default_step") as AudioStream
		if step != null:
			return step
		var walk: AudioStreamPlayer = audio.get("sfx_walk") as AudioStreamPlayer
		if walk != null and walk.stream != null:
			return walk.stream
	return PlaceholderAudio.make_footstep()


# ---- The flashlight in the door shot ---------------------------------------------------------------------------------

## The beam starts pointing back at the nightstand, away from the door; `_drive_beam` brings it round to the door.
func _beam_start() -> void:
	if _flashlight == null or not is_instance_valid(_flashlight) or not _flashlight_scripted:
		return

	# She is standing at the nightstand, so the light points back there, away from the door the camera sees.
	_beam_from = postcard.global_position + Vector3(0.0, beam_start_height, 0.0)
	_beam_to = _door_middle() + beam_end_offset
	_beam_time = 0.0
	_beam_on = true
	_flashlight.set("scripted_aim_on", true)
	_flashlight.set("scripted_aim_speed", 2.5)
	_flashlight.set("smoothed_aim_target", _beam_from)
	_flashlight.set("has_smoothed_aim_target", true)
	_drive_beam(0.0)


## Every frame: where the beam points. After `beam_delay_seconds` (a few steps) it travels to the door over `beam_sweep_seconds`, with a
## smooth start and stop, rising on an arc; a little sway and tremble all the while, more while it moves.
func _drive_beam(delta: float) -> void:
	if _flashlight == null or not is_instance_valid(_flashlight):
		_beam_on = false
		return

	_beam_time += delta
	var s: float = clampf((_beam_time - beam_delay_seconds) / maxf(beam_sweep_seconds, 0.01), 0.0, 1.0)
	var eased: float = s * s * s * (s * (s * 6.0 - 15.0) + 10.0)
	var point: Vector3 = _beam_from.lerp(_beam_to, eased)
	point += Vector3.UP * sin(PI * eased) * beam_arc
	var t: float = _beam_time
	var moving: float = 1.0 + 1.2 * sin(PI * eased)
	var sway: Vector3 = Vector3(
		sin(t * 1.3) * 0.7 + sin(t * 2.9 + 1.0) * 0.4 + sin(t * 7.1 + 0.4) * 0.12,
		sin(t * 1.7 + 2.0) * 0.5 + sin(t * 3.7 + 0.6) * 0.3 + sin(t * 8.3 + 1.5) * 0.12,
		0.0
	)
	point += sway * beam_sway * moving
	var hand: Vector3 = (_flashlight as Node3D).global_position
	_flashlight.set("scripted_aim_direction", (point - hand).normalized())


func _beam_stop() -> void:
	_beam_on = false
	if _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.set("scripted_aim_on", false)
		_flashlight.set("scripted_aim_speed", 1.0)


## The middle of the bedroom door, at the height of the handle.
func _door_middle() -> Vector3:
	var handle: Vector3 = bedroom_door.get_handle_position_facing(_get_camera().global_position)
	var hinge: Vector3 = bedroom_door.global_position
	return Vector3((hinge.x + handle.x) * 0.5, handle.y + 0.1, (hinge.z + handle.z) * 0.5)


# ---- Back to her eyes ---------------------------------------------------------------------------------------------

## The door camera goes slowly to her eyes: it travels to where her own camera is, turning and widening to her own lens, and looks at
## the same spot (the open door, which her view was set on when the shot began). When it is there the view is hers, with no cut, and
## the controls come back at once. The capsule is unlocked (no key), and the door put back the first moment none of it is in her view.
func _shot_to_eyes(run: int) -> bool:
	_log(&"to_eyes")
	_tension_stop(eyes_blend_seconds)
	if door_lighting != null:
		door_lighting.fade_to(0.0, eyes_blend_seconds)
	_move_camera(_get_camera().global_transform.orthonormalized(), eyes_blend_seconds)
	_change_lens(_base_fov, eyes_blend_seconds)
	await _wait(eyes_blend_seconds)
	if not _still(run):
		return false

	_show_eyes()
	_log(&"cut_to_eyes")
	_beam_stop()
	_duck_outside(false)
	_log(&"glance_end")
	return true


## The door put back shut when none of it can be seen from her eyes (`now`: at once, whatever is seen).
func _settle_pending(now: bool) -> void:
	if _door_reset_pending:
		var touched: bool = bedroom_door != null and (bedroom_door.is_open or bedroom_door.is_busy())
		if now or touched or not _door_in_view():
			_door_reset_pending = false
			if touched:
				bedroom_door.ajar_degrees = 0.0
				bedroom_door.set_handle_turn(0.0)
			else:
				_reset_bedroom_door()
			_log(&"door_reset")


## True while any corner of the bedroom door's leaf, or of its doorway, is in the player's view.
func _door_in_view() -> bool:
	var camera: Camera3D = _get_camera()
	if camera == null or bedroom_door == null:
		return false

	var corners: Array[Vector3] = []
	for along: float in [0.0, 0.45, 0.9]:
		for height: float in [0.0, 1.0, 2.0]:
			corners.append(bedroom_door.to_global(Vector3(along, height, 0.0)))
			corners.append(bedroom_door.door_root.to_global(Vector3(along - 0.45, height - 1.0, 0.0)))
	for corner: Vector3 in corners:
		if camera.is_position_in_frustum(corner):
			return true

	return false


func _reset_bedroom_door() -> void:
	if bedroom_door != null:
		bedroom_door.close_instantly()


## The outside pushed back while the steps and the door play (so the steps are not lost under the wind), and let back.
func _duck_outside(on: bool) -> void:
	if on == _ducking or not is_inside_tree():
		return

	_ducking = on
	get_tree().call_group(OutdoorAmbience.GROUP, "set_muffle", &"house_footsteps", footsteps_duck if on else 0.0)


# ---- The scene's outcome ------------------------------------------------------------------------------------------

## The scene's outcome, whether it played or was skipped: done for good, the capsule unlocked, and the postcard is only a
## postcard again.
func _finish_memory_state() -> void:
	_memory_done = true
	_set_flag(KEY_MEMORY_DONE, true)
	_set_room(false)
	_unlock_capsule()
	if postcard != null:
		postcard.plays_scene = false


## For the developer console and the tests: whatever the house is doing, the bedroom scene is over at once (the player is
## let go, the capsule unlocked), and the pantry and the bedroom are open to them.
func force_finish_memory() -> void:
	_cancel_memory()
	_settle_pending(true)
	if not _recipe_done:
		_recipe_done = true
		_set_flag(KEY_RECIPE_DONE, true)
		_set_pantry_lamp(true, false)
	for door: DoorController in [pantry_door, bedroom_door]:
		if door != null and door.is_locked:
			door.unlock()
	_finish_memory_state()


## Stops a scene that is playing and gives everything back (the cameras, the player, the postcard, the door, the room). Not
## done: the postcard can be read to play it from the start.
func _cancel_memory() -> void:
	if not memory_running:
		return

	_run += 1
	memory_running = false
	if _approaching:
		_approaching = false
		var walker: PlayerMovementController = _get_movement()
		if walker != null:
			walker.cancel_guided_walk()
		if _get_player() != null:
			_get_player().call("set_manual_save_blocked", _approach_save_block)
	_bow = 0.0
	_beam_stop()
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()

	_clear_freeze()
	_drop_held_card()
	if memory_voice_player != null:
		memory_voice_player.stop()
	if is_inside_tree():
		CaptionManager.clear()
	_duck_outside(false)
	_tension_stop(0.0)
	if door_lighting != null:
		door_lighting.fade_to(0.0, 0.0)
	_set_room(false)
	_door_reset_pending = false
	if bedroom_door != null:
		bedroom_door.ajar_degrees = 0.0
		bedroom_door.set_handle_turn(0.0)
	_unlock_capsule()
	if postcard != null:
		postcard.plays_scene = not _memory_done
	_release_player()


func _still(run: int) -> bool:
	return memory_running and run == _run and is_inside_tree()


## The room as the memory has it (the dressing and the lamp, the notebook gone, the flashlight out), or the night (the
## flashlight back). Changed all at once: only ever while a dissolve covers it, or with the room out of the shot.
func _set_room(memory: bool) -> void:
	in_memory = memory
	if memory_root != null:
		memory_root.visible = memory
	if memory_light != null:
		memory_light.light_energy = memory_light_energy if memory else 0.0
	for node: Node3D in night_only:
		if node != null and is_instance_valid(node):
			node.visible = not memory
	if _flashlight_scripted and _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.call("set_scripted_light", _flashlight_available and not memory, 1.0)


## Once the bedroom scene is done the capsule opens to the player, with no key.
func _unlock_capsule() -> void:
	if capsule != null and is_instance_valid(capsule):
		capsule.story_unlocked = _memory_done


func _capsule_open() -> bool:
	if capsule != null:
		return capsule.is_open

	return bool(SaveManager.get_state_value(STATE_SECTION, &"time_capsule_open", false))


# ============================================================
# THE PLAYER, HELD
# ============================================================

## The player is held as a scene holds them: no walking, looking, interacting or saving, and the flashlight is the scene's
## (on while the room is the night, out in the memory). Their body's own motion is stilled for the shots through their eyes.
## What another system had set is remembered and put back.
func _hold_player(target: Node) -> void:
	_held = target
	_held_view_locked = bool(target.get("view_locked"))
	_held_scripted_flashlight = bool(target.get("scripted_flashlight"))
	_held_save_block = bool(target.get("manual_save_blocked"))
	target.set("scripted_flashlight", true)
	target.call("set_view_locked", true)
	target.call("set_manual_save_blocked", true)

	var movement: PlayerMovementController = _get_movement()
	_held_motion_still = movement.view_motion_still
	movement.view_motion_still = true
	_held_gesture_direct = movement.gesture_direct
	_bow = 0.0

	_flashlight = target.get("flashlight_controller") as Node
	_flashlight_scripted = false
	_flashlight_available = false
	if _flashlight != null and _flashlight.has_method("begin_scripted_light"):
		# She has the flashlight (and may use it): it lights the night shots, whatever its switch was.
		_flashlight_available = bool(_flashlight.get("flashlight_input_enabled")) and bool(_flashlight.call("_player_has_flashlight"))
		_flashlight.call("begin_scripted_light")
		_flashlight_scripted = true
		_flashlight.call("set_scripted_light", _flashlight_available, 1.0)


## Gives the player back: their own eyes (the view already where the scene left it, so the first mouse movement turns from
## there), their flashlight (left on if it lit the scene), and whatever was held before.
func _release_player() -> void:
	_clear_freeze()
	_cam = null
	_bow = 0.0
	_beam_stop()
	var movement: PlayerMovementController = _get_movement()
	if movement != null and movement.camera != null and movement.camera.is_inside_tree():
		movement.camera.make_current()
		movement.scripted_fov = 0.0
		movement.gesture_offset = Vector3.ZERO
		movement.gesture_pitch_degrees = 0.0
		movement.gesture_direct = _held_gesture_direct
		movement.view_motion_still = _held_motion_still
	_free_cinema_camera()

	if _flashlight_scripted and _flashlight != null and is_instance_valid(_flashlight):
		if _flashlight_available:
			_flashlight.set("flashlight_on", true)
		_flashlight.call("end_scripted_light")
	_flashlight_scripted = false

	if _held == null or not is_instance_valid(_held):
		_held = null
		return

	_held.call("set_view_locked", _held_view_locked)
	_held.set("scripted_flashlight", _held_scripted_flashlight)
	_held.call("set_manual_save_blocked", _held_save_block)
	_held = null


## Juliana's view turns to look at `point` over `seconds` (0: at once), eased in and out: her own, authored head turn, on the
## same physics step the player's look is applied on.
func _look_at_point(point: Vector3, seconds: float) -> void:
	_turn_view(_look_angles(point), seconds)


func _turn_view(angles: Vector2, seconds: float) -> void:
	var movement: PlayerMovementController = _get_movement()
	if movement == null:
		return

	var from: Vector2 = Vector2(movement.look_yaw, movement.look_pitch)
	var to: Vector2 = Vector2(from.x + wrapf(angles.x - from.x, -180.0, 180.0), clampf(angles.y, -35.0, 75.0))
	if seconds <= 0.0:
		movement.look_yaw = to.x
		movement.look_pitch = to.y
		return

	var turn: Tween = _track(create_tween())
	turn.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	turn.tween_method(
		func(value: Vector2) -> void:
			movement.look_yaw = value.x
			movement.look_pitch = value.y,
		from, to, seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Yaw and pitch (the movement controller's degrees) that look from the player's eye at `point`.
func _look_angles(point: Vector3) -> Vector2:
	var movement: PlayerMovementController = _get_movement()
	var body: Node3D = _get_player()
	var eye: Vector3 = movement.camera.global_position
	var d: Vector3 = body.global_basis.inverse() * (point - eye)
	var yaw: float = rad_to_deg(atan2(d.x, -d.z))
	var pitch: float = clampf(rad_to_deg(atan2(-d.y, Vector2(d.x, d.z).length())), -35.0, 75.0)
	return Vector2(yaw, pitch)


# ---- The cameras ---------------------------------------------------------------------------------------------------

## Cuts to the scene's camera, at `at` with field of view `fov`, standing still.
func _show_camera(at: Transform3D, fov: float) -> void:
	var camera: Camera3D = _cinema_camera()
	_cam = camera
	_move_from = at
	_move_to = at
	_move_t = 1.0
	_move_seconds = 0.0
	_lens_from = fov
	_lens_to = fov
	_lens_t = 1.0
	_lens_seconds = 0.0
	camera.global_transform = at
	camera.fov = fov
	camera.make_current()


## The scene's camera, made the first time: the player's lens settings (exposure included), without their depth of field
## (it follows what the player aims at), and a near plane close enough for things held in the hands.
func _cinema_camera() -> Camera3D:
	if _cinema != null and is_instance_valid(_cinema):
		return _cinema

	_cinema = Camera3D.new()
	_cinema.name = "CinemaCamera"
	var eyes: Camera3D = _get_camera()
	if eyes != null:
		_cinema.cull_mask = eyes.cull_mask
		_cinema.far = eyes.far
		_cinema.keep_aspect = eyes.keep_aspect
		_cinema.environment = eyes.environment
		_cinema.compositor = eyes.compositor
		if eyes.attributes != null:
			var lens: CameraAttributes = eyes.attributes.duplicate() as CameraAttributes
			if lens is CameraAttributesPractical:
				(lens as CameraAttributesPractical).dof_blur_far_enabled = false
				(lens as CameraAttributesPractical).dof_blur_near_enabled = false
			_cinema.attributes = lens
	_cinema.near = 0.02
	add_child(_cinema)
	return _cinema


func _free_cinema_camera() -> void:
	if _cinema != null and is_instance_valid(_cinema):
		_cinema.queue_free()
	_cinema = null


## Cuts to Juliana's own eyes (where her look already is; her body still).
func _show_eyes() -> void:
	_cam = null
	var camera: Camera3D = _get_camera()
	if camera != null:
		camera.make_current()


## The shot moves from where it is now to `to` over `seconds`, eased in and out.
func _move_camera(to: Transform3D, seconds: float) -> void:
	_move_from = _shot_between(_move_from, _move_to, _ease(_move_t))
	_move_to = to
	_move_t = 0.0
	_move_seconds = maxf(seconds, 0.001)


func _change_lens(fov: float, seconds: float) -> void:
	_lens_from = lerpf(_lens_from, _lens_to, _ease(_lens_t))
	_lens_to = fov
	_lens_t = 0.0
	_lens_seconds = maxf(seconds, 0.001)


## Every frame: the one writer of the scene's camera, its move and its lens.
func _drive_camera(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return

	_move_t = minf(_move_t + delta / maxf(_move_seconds, 0.001), 1.0)
	_lens_t = minf(_lens_t + delta / maxf(_lens_seconds, 0.001), 1.0)
	_cam.global_transform = _shot_between(_move_from, _move_to, _ease(_move_t))
	_cam.fov = lerpf(_lens_from, _lens_to, _ease(_lens_t))


func _ease(t: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0))


## A camera `weight` of the way from one transform to another: the position along the straight line, the aim turned by its
## heading and its tilt (never rolling, which turning the whole orientation the shortest way would do part way).
func _shot_between(from: Transform3D, to: Transform3D, weight: float) -> Transform3D:
	if weight >= 1.0:
		return to

	var a: Vector3 = -from.basis.z.normalized()
	var b: Vector3 = -to.basis.z.normalized()
	var yaw_a: float = atan2(-a.x, -a.z)
	var yaw: float = yaw_a + angle_difference(yaw_a, atan2(-b.x, -b.z)) * weight
	var pitch: float = lerpf(asin(clampf(a.y, -1.0, 1.0)), asin(clampf(b.y, -1.0, 1.0)), weight)
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), from.origin.lerp(to.origin, weight))


## The matched dissolve: a still of the last frame shown (the picture as it is now) over the live one, and faded away over
## `seconds`. Whatever changes under it in the same frame is revealed through the dissolve, not seen happening. (Nothing to
## take a still of without a screen: then it is a plain cut.)
func _dissolve(seconds: float) -> void:
	_clear_freeze()
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return

	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return

	_freeze_layer = CanvasLayer.new()
	_freeze_layer.name = "DissolveStill"
	# Over the world, its filters and the motion blur, under the subtitles and the menus.
	_freeze_layer.layer = 1
	var still: TextureRect = TextureRect.new()
	still.texture = ImageTexture.create_from_image(image)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_SCALE
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still.set_anchors_preset(Control.PRESET_FULL_RECT)
	_freeze_layer.add_child(still)
	add_child(_freeze_layer)

	var layer: CanvasLayer = _freeze_layer
	var fade: Tween = _track(create_tween())
	fade.tween_property(still, "modulate:a", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		if _freeze_layer == layer:
			_freeze_layer = null)


func _clear_freeze() -> void:
	if _freeze_layer != null and is_instance_valid(_freeze_layer):
		_freeze_layer.queue_free()
	_freeze_layer = null


func _log(beat: StringName) -> void:
	memory_log.append({"beat": beat, "time": scene_clock})


# ============================================================
# HELPERS
# ============================================================

func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


## Points along a polyline (house-local) every `stride` metres, from its start to its end.
func _path_points(path: Array[Vector3], stride: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if path.is_empty():
		return points

	points.append(path[0])
	var carried: float = 0.0
	for i: int in range(1, path.size()):
		var from: Vector3 = path[i - 1]
		var length: float = from.distance_to(path[i])
		var at: float = stride - carried
		while at <= length:
			points.append(from.lerp(path[i], at / length))
			at += stride
		carried = length - (at - stride)
	if points[points.size() - 1].distance_to(path[path.size() - 1]) > stride * 0.4:
		points.append(path[path.size() - 1])
	return points


## One sound at a point; the player removes itself when done.
func _play_at(stream: AudioStream, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0, unit_size: float = 5.0, max_distance: float = 30.0) -> AudioStreamPlayer3D:
	if stream == null or not is_inside_tree():
		return null

	var sound: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.volume_db = volume_db
	sound.pitch_scale = pitch
	sound.unit_size = unit_size
	sound.max_distance = max_distance
	sound.max_db = maxf(3.0, volume_db + 3.0)
	add_child(sound)
	sound.global_position = at
	sound.finished.connect(sound.queue_free)
	sound.play()
	return sound


func _play_at_later(stream: AudioStream, at: Vector3, volume_db: float, pitch: float, delay: float) -> void:
	await _wait(delay)
	_play_at(stream, at, volume_db, pitch)


func _doors() -> Array[DoorController]:
	var doors: Array[DoorController] = []
	if doors_root != null:
		for child: Node in doors_root.get_children():
			if child is DoorController:
				doors.append(child as DoorController)

	return doors


func _get_flag(key: StringName) -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, key, false))


func _set_flag(key: StringName, value: bool) -> void:
	SaveManager.set_state_value(STATE_SECTION, key, value)


func _get_player() -> Node3D:
	if player != null:
		return player

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group(&"player") as Node3D


func _get_movement() -> PlayerMovementController:
	var target: Node3D = _get_player()
	return target.get("movement_controller") as PlayerMovementController if target != null else null


func _get_camera() -> Camera3D:
	var movement: PlayerMovementController = _get_movement()
	return movement.camera if movement != null else null


func _wait(seconds: float) -> void:
	# Not "process always": the pause menu also pauses the house.
	await get_tree().create_timer(maxf(seconds, 0.0), false).timeout
