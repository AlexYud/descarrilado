extends Node3D
class_name WaitingShedSequence

## The waiting shed, "The Shelter Stayed Open" (the middle route, Sophia's). The player finds a railway waiting shelter with
## Sophia's things on its bench: her notebook, a newspaper clipping (both optional), her closed backpack, and a small hinged
## box that opens with a plain interaction. The videotape lies in the open box on top of the telephone token.
##
## Examining the tape is the one interaction that matters. The FIRST time that view is closed the scene takes the player's eyes
## and plays once, without giving control back between its parts (all subtitles for now; the voice clips are optional hooks):
##   1. The tape set down beside the box, the notebook in the shot; Juliana remembers Sophia showing her the copy.
##   2. The recording itself, about 50 s, a worn, copied home-video tape (`ArchiveVideoOverlay`: coarse picture, bleeding colour, tracking
##      lines, dropouts, 12 frames a second, with stalls) from a hidden camera that does not move, across the clearing where the camcorder stands:
##      the same shelter with an ordinary, usable bench, seen through a few ferns close to the lens. Marina sits on the bench, waiting, a long
##      time; someone (their head never in the picture) walks in on the near side, stops, stays a long time appearing to speak with her, and
##      walks out; she follows them with her head, waits alone, and slowly turns her face to the lens and stays so until the tape ends in static.
##      `ShelterFootage` performs it on one clock. Only the tape's own noise (`placeholder_video_tape`, looped) is heard in it; no caption speaks for it.
##   3. The photograph: a hard cut to the print mounted on Sophia's clipping, among her things, about 4 s, with no sound and no words. It
##      shows this shelter after the body was taken away, blood on the bench, the floor and the pillar's foot.
##   4. The conversation that followed, remembered, in one still shot over the notebook, the photograph, the tape and the open box.
##   Then the view is hers again, at once (a short dissolve to her own eyes): nothing more is played.
## The wind and the night chorus are silent from the first shot to the last (the scene is a memory). The scene never runs twice. Its completion is
## saved apart from the token's collection. The token is the same Collectible as before (`sophia_ficha`); it cannot be taken while the tape lies on
## it, nor during the scene.
##
## The two people in the recording and the ferns that hide its camera are never in the present: they are shown only inside the recording
## and are hidden (the cast put back at its first frame) before any cut to the present, on finishing, on cancelling and on leaving. The
## shelter has three looks that never mix (see `WorldState`): the recording's, the present's, and the aftermath that the shipped
## photograph was captured in (only a developer's capture tool ever asks for that one).
##
## Saved (section `puzzles`): `shelter_recording_done` (the scene is over; the tape stays beside the box, the token is free),
## `junction_switch_box_open` (the box is open: the OpenableContainer's own key). Older saves are mapped, see
## `migrate_saved_state`. Every length of time below is an export, to be tuned in play.

signal recording_started
signal recording_finished
## The Ficha's view was closed (the token taken and looked at). Unchanged from the older puzzle; nothing listens for it yet.
signal sequence_completed

enum Stage { AVAILABLE, RUNNING, DONE }

const STATE_SECTION: StringName = &"puzzles"
const KEY_RECORDING_DONE: StringName = &"shelter_recording_done"
const KEY_BOX_OPEN: StringName = &"junction_switch_box_open"
## Older keys: the token taken from the lever box, and the lever box solved.
const KEY_FICHA_TAKEN: StringName = &"junction_ficha_taken"
const KEY_LEVER_BOX_OPEN: StringName = &"junction_signal_box_open"
## The payphone's list of tokens already inserted (see OverlookPhoneSequence).
const KEY_FICHAS: StringName = &"orelhao_fichas"
const TOKEN_ID: String = "sophia_ficha"
const VHS_INSPECT_ID: StringName = &"sophia_vhs"
## The asker's name when the sequence silences the forest while the memory plays.
const MUFFLE_SOURCE: StringName = &"shed_recording"
const TAPE_SOUND_PATH: String = "res://assets/audios/placeholder_video_tape.mp3"

@export_category("Items")
## `inspect_id` metadata of the Ficha (its view being closed raises `sequence_completed`).
@export var ficha_id: StringName = &"sophia_ficha"
@export var container: OpenableContainer
## The videotape (it starts in the box's `Contents`, on top of the token).
@export var vhs: Inspectable
## The telephone token (also in `Contents`, under the tape).
@export var ficha: Collectible
## Where the tape is set down beside the box (a marker in the space of `effects_root`; its position and rotation are the tape's).
@export var vhs_set_down: Marker3D
## Everything of Sophia's and the box with what is in it: hidden while the recording shows the bench as it was.
@export var effects_root: Node3D
## What only the recording and the aftermath photograph show: the bench's front plank before it was replaced (`Intact` in the recording,
## `Damaged` in the aftermath). Kept hidden in the present.
@export var archive_dressing: Node3D
## The bench's replaced plank (hidden while the recording shows the old one).
@export var replaced_plank: Node3D
## The ferns close to the recording's lens: they exist only inside the recording.
@export var archive_foreground: Node3D
## The camcorder on its tripod, and its turning `Head` (found in its model).
@export var camcorder: Node3D
## The performance inside the recording (two actors) and the clock it is a function of.
@export var footage: ShelterFootage

@export_category("Shots")
## Where each shot stands, what it looks at and its lens (see ShotMarker). The scene's camera is placed from them.
@export var shot_copy: ShotMarker
## The recording's camera is FIXED: this one marker, for the whole excerpt (no reframe, no zoom, no shake).
@export var shot_recording: ShotMarker
## The close view of the photograph's print among Sophia's things.
@export var shot_photo: ShotMarker
## The remembered conversation: one still shot over the notebook, the photograph, the tape and the box.
@export var shot_talk: ShotMarker

@export_category("Look of the shots")
## A faint cold light on the bench for the shots over the notebook, the tape and the box (shots 1 and 4), at the camera: the lamp alone leaves the box dark.
@export var shot_light_energy: float = 1.8
## The same light for the close view of the print (nearer, so weaker).
@export var photo_light_energy: float = 0.7
@export var shot_light_range: float = 4.0
@export var shot_light_angle: float = 62.0
## The recording's own exposure, on its camera only (the game's fog and light are untouched): no fog, a pale ambient, a little brighter.
@export var archive_ambient_color: Color = Color(0.5, 0.56, 0.66)
@export var archive_ambient_energy: float = 1.0
@export var archive_brightness: float = 1.25

@export_category("Shot 1: the copy (remembered)")
## Cross-fade into the first shot, hiding the tape being set down.
@export var dissolve_into_scene_seconds: float = 0.4

@export_category("Shot 2: the recording (a worn tape)")
## The tape's own noise, looped under the whole recording (and only there): the placeholder recording when empty.
@export var tape_sound: AudioStream
@export var tape_volume_db: float = -4.0
@export var tape_fade_seconds: float = 0.4
## Stalls of the picture, as (start, seconds) pairs in footage seconds: the picture holds one frame (the tape's noise goes on) and then jumps on.
@export var tape_stalls: PackedFloat32Array = PackedFloat32Array([13.0, 0.8, 22.5, 1.2, 33.0, 0.6, 43.0, 1.6])
## The tape ends in static over this many last seconds of the footage.
@export var tape_end_seconds: float = 0.5
## The rest of the performance (its length and every moment of it) is on the `Footage` node (`ShelterFootage`), and its framing is the marker `shot_recording`.

@export_category("Shot 3: the photograph")
## How long the close view of the print is held (no sound, no words).
@export var photo_shot_seconds: float = 4.0

@export_category("Camcorder")
## The camcorder as the level has it (yaw in degrees of the head, from facing -Z), a little off the bench's middle. It is only a thing in the clearing.
@export var camcorder_start_yaw_degrees: float = 2.5

@export_category("Optional audio (assign later)")
## One clip per part, timed from the start of its shot. Empty: that part is subtitles only. The `_en` clips are used when the voice
## language is English; the plain ones (Portuguese) are the fallback. These are the girls' remembered voices: the recording has no
## voice at all (only the tape's noise, see `tape_sound`).
@export var voice_copy: AudioStream
@export var voice_copy_en: AudioStream
@export var voice_talk: AudioStream
@export var voice_talk_en: AudioStream

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

var _stage: Stage = Stage.AVAILABLE
var _run: int = 0
var _connected: bool = false
var _connect_retry: float = 0.0

# The player, held for the scene (what was set before is put back).
var _held: Node = null
var _held_view_locked: bool = false
var _held_scripted_flashlight: bool = false
var _held_save_block: bool = false
var _held_motion_still: bool = false
var _held_gesture_direct: bool = false
var _flashlight: Node = null
var _flash_was_on: bool = false
var _flash_scripted: bool = false

# The scene's own camera and the pieces it dresses.
var _cinema: Camera3D = null
var _shot_light: SpotLight3D = null
var _archive_environment: Environment = null
var _freeze_layer: CanvasLayer = null
var _overlay: ArchiveVideoOverlay = null
var _tweens: Array[Tween] = []
var _vhs_box_transform: Transform3D = Transform3D.IDENTITY
var _vhs_box_parent: Node = null
var _ducking: bool = false

# The footage clock: what the recording shows is a function of `_footage_time`, advanced here frame by frame while the footage plays (and so
# stopped by the pause). Nothing else keeps time for the picture.
var _footage_playing: bool = false
var _footage_time: float = 0.0

# The shelter's three looks. They never mix; only changed under a cut (or with nothing of them in view).
enum WorldState { PRESENT, RECORDING, PHOTO_CAPTURE }
var _world_state: WorldState = WorldState.PRESENT

# The audio layers: each its own player. The recording has none of its own (nor a rewind: it is not replayed).
var _remembered_player: AudioStreamPlayer = null
var _tape_player: AudioStreamPlayer = null


func _enter_tree() -> void:
	# Before the box and the token are ready (the parent enters first): they read the saved state as it is after this.
	migrate_saved_state()


func _ready() -> void:
	_apply_ground()
	_stage = Stage.DONE if _is_done() else Stage.AVAILABLE
	# The bench builds its replaced plank itself (in code), so it is looked for here, not wired in the scene.
	if replaced_plank == null:
		replaced_plank = get_node_or_null(^"Platform/Bench/ReplacedPlank") as Node3D
	_build_audio()
	_set_recording_world(false)
	_set_camcorder_yaw(camcorder_start_yaw_degrees)
	_set_camcorder_light(false)
	if vhs != null and vhs.get_parent() != null:
		_vhs_box_parent = vhs.get_parent()
		_vhs_box_transform = vhs.transform
	_apply_saved_scene_state()
	_connect_to_player.call_deferred()
	# The cast of the recording is built and posed now, out of sight, so that nothing is made while the scene is being watched.
	if footage != null and shot_recording != null:
		# The hidden camera's lens: where Marina, alone at the end of the tape, turns her face.
		footage.lens_point = shot_recording.global_position
	if _stage == Stage.AVAILABLE and footage != null:
		footage.prepare.call_deferred()


func _exit_tree() -> void:
	_cancel_recording()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.free()
		_overlay = null


func _process(delta: float) -> void:
	if not _connected:
		_connect_retry -= delta
		if _connect_retry <= 0.0:
			_connect_retry = 0.5
			_connect_to_player()

	_tick_footage(delta)

	if _stage == Stage.RUNNING and _held != null and is_instance_valid(_held):
		if bool(_held.call("is_inventory_open")):
			# The inventory is the one thing a held view still lets the player open: not during this scene.
			var inventory_ui: Node = _held.get("inventory_ui_controller") as Node
			if inventory_ui != null:
				inventory_ui.call("close")


# ============================================================
# SAVED STATE
# ============================================================

## Maps an older save onto this scene, before the box and the token read it. In the older puzzle the token came out of a lever
## box (`junction_signal_box_open`) and was taken with a view (`junction_ficha_taken`); a token already taken or put in the
## payphone is gone for good. Any of these means the recording is over (it never replays, and nothing asks for the removed levers):
## the box is open, the tape lies beside it, and the token is there to take unless it was taken. Nothing is wiped or renamed.
static func migrate_saved_state() -> void:
	var done: bool = bool(SaveManager.get_state_value(STATE_SECTION, KEY_RECORDING_DONE, false))
	done = done or bool(SaveManager.get_state_value(STATE_SECTION, KEY_FICHA_TAKEN, false))
	done = done or bool(SaveManager.get_state_value(STATE_SECTION, KEY_LEVER_BOX_OPEN, false))
	done = done or bool(SaveManager.get_state_value(&"collectibles", StringName(TOKEN_ID), false))
	var inserted: Variant = SaveManager.get_state_value(STATE_SECTION, KEY_FICHAS, [])
	if inserted is Array and TOKEN_ID in (inserted as Array):
		done = true

	if done:
		SaveManager.set_state_value(STATE_SECTION, KEY_RECORDING_DONE, true)
		SaveManager.set_state_value(STATE_SECTION, KEY_BOX_OPEN, true)


func _is_done() -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, KEY_RECORDING_DONE, false))


func is_recording_running() -> bool:
	return _stage == Stage.RUNNING


func is_recording_done() -> bool:
	return _stage == Stage.DONE


## The scene as the saved state has it: before the recording the tape lies on the token and the token cannot be taken; after it
## the tape lies beside the box and the token is free.
func _apply_saved_scene_state() -> void:
	if _stage == Stage.DONE:
		_set_tape_beside_box()
		_set_token_available(true)
	else:
		_set_token_available(false)


## The token can be taken (or not): its pickup and its interaction shape, locally gated so that neither the tape over it nor the
## scene lets it be selected early.
func _set_token_available(available: bool) -> void:
	if ficha == null or not is_instance_valid(ficha):
		return

	ficha.pickup_enabled = available
	var shape: CollisionShape3D = ficha.get_node_or_null(^"InteractArea/CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.set_deferred("disabled", not available)


## The tape on the bench beside the box (the hinged box stays open, the token showing).
func _set_tape_beside_box() -> void:
	if vhs == null or not is_instance_valid(vhs) or effects_root == null or vhs_set_down == null:
		return

	if vhs.get_parent() != effects_root:
		if vhs.get_parent() != null:
			vhs.get_parent().remove_child(vhs)
		effects_root.add_child(vhs)

	vhs.transform = vhs_set_down.transform


## The tape back in the box on the token (the scene was cut short before it finished).
func _set_tape_in_box() -> void:
	if vhs == null or not is_instance_valid(vhs) or _vhs_box_parent == null or not is_instance_valid(_vhs_box_parent):
		return

	if vhs.get_parent() != _vhs_box_parent:
		if vhs.get_parent() != null:
			vhs.get_parent().remove_child(vhs)
		_vhs_box_parent.add_child(vhs)

	vhs.transform = _vhs_box_transform


## For the developer console and the tests: the scene is put back as it was before the recording (the tape on the token), if it
## is not playing and the token is still in the box.
func reset_for_replay() -> bool:
	if _stage == Stage.RUNNING:
		return false

	if ficha == null or not is_instance_valid(ficha) or ficha.is_queued_for_deletion():
		return false

	SaveManager.set_state_value(STATE_SECTION, KEY_RECORDING_DONE, false)
	_stage = Stage.AVAILABLE
	_set_tape_in_box()
	_set_token_available(false)
	_set_camcorder_yaw(camcorder_start_yaw_degrees)
	return true


## For the developer console: whatever the scene is doing, it is over at once (the player is let go, the token is free).
func force_finish() -> void:
	if _stage == Stage.RUNNING:
		_mark_done()
		_cancel_recording()
	_stage = Stage.DONE
	SaveManager.set_state_value(STATE_SECTION, KEY_RECORDING_DONE, true)
	SaveManager.set_state_value(STATE_SECTION, KEY_BOX_OPEN, true)
	_set_tape_beside_box()
	_set_token_available(true)


# ============================================================
# GROUND
# ============================================================

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


# ============================================================
# THE PLAYER, AND WHAT THEY EXAMINE
# ============================================================

func _connect_to_player() -> void:
	var target: Node = _get_player()
	if target == null:
		return

	var inspect: PlayerInspectController = target.get("inspect_controller") as PlayerInspectController
	if inspect == null:
		return

	if not inspect.inspect_closed.is_connected(_on_inspect_closed):
		inspect.inspect_closed.connect(_on_inspect_closed)
	_connected = true


func _on_inspect_closed(closed_id: String) -> void:
	var id: StringName = StringName(closed_id)
	if id == VHS_INSPECT_ID:
		# `inspect_closed` is raised as the view starts to close: the player is taken in this very call, so that there is no
		# moment of walking or opening the inventory before the scene has them (it then waits for the view to be gone).
		if _stage == Stage.AVAILABLE and not _is_done():
			_begin_recording()
	elif id == ficha_id:
		if not bool(SaveManager.get_state_value(STATE_SECTION, KEY_FICHA_TAKEN, false)):
			SaveManager.set_state_value(STATE_SECTION, KEY_FICHA_TAKEN, true)
			sequence_completed.emit()


func _begin_recording() -> void:
	var target: Node3D = _get_player()
	if target == null:
		return

	_stage = Stage.RUNNING
	_run += 1
	_hold_player(target)
	# (Normally built long before, out of sight; this is only the fallback for a scene entered in the same frame.)
	if footage != null:
		footage.prepare()
	recording_started.emit()
	_play_recording(_run)


func _alive(run: int) -> bool:
	return _stage == Stage.RUNNING and run == _run and is_inside_tree()


# ============================================================
# THE SCENE
# ============================================================

func _play_recording(run: int) -> void:
	CaptionManager.clear()
	await _settle_inspect(run)
	if not _alive(run):
		return

	# Shot 1: the tape is set down beside the box under a cross-fade from the view the player had.
	_dissolve(dissolve_into_scene_seconds)
	_set_tape_beside_box()
	_show_camera(shot_copy)
	_set_shot_light(true)
	_duck_forest(true)
	await _shot_copy(run)
	if not _alive(run):
		return

	# Shot 2: the recording (its tape noise only). Everything of the present that is not in it goes under the cut, and the cast is posed at its first
	# frame before it is shown. The camera does not move from here to the end.
	_show_camera(shot_recording, true)
	_apply_footage(0.0)
	_set_recording_world(true)
	_show_overlay(true)
	_set_shot_light(false)
	await _shot_footage(run)
	if not _alive(run):
		return

	# Shot 3: the photograph. A hard cut (the present, with Sophia's things, is whole again before it is seen; the cast is put away).
	_set_recording_world(false)
	_show_overlay(false)
	_show_camera(shot_photo)
	_set_shot_light(true, photo_light_energy)
	await _shot_photo(run)
	if not _alive(run):
		return

	# Shot 4: the conversation, remembered, in one still shot (a cut back from the print to the notebook, the tape and the box).
	_show_camera(shot_talk)
	_set_shot_light(true)
	await _shot_talk(run)
	if not _alive(run):
		return

	# Then the view is hers: the scene's work done and the controls back, with a short dissolve from the last shot to her own eyes (the still it fades
	# is the last frame drawn, so it is taken after the change is made, in the same frame).
	_back_to_her_eyes()
	_mark_done()
	_finish_recording()
	_dissolve(dissolve_into_scene_seconds)


## Waits until the examined tape has flown back and the inspect view is gone (it is shut by the player; it is not closed for them here).
func _settle_inspect(run: int) -> void:
	var inspect: PlayerInspectController = _get_inspect()
	var waited: float = 0.0
	while inspect != null and inspect.is_open() and waited < 6.0:
		await get_tree().process_frame
		if run != _run:
			return
		waited += get_process_delta_time()


func _shot_copy(run: int) -> void:
	_play_voice(_remembered_player, _pick_voice(voice_copy, voice_copy_en))
	CaptionManager.clear()
	CaptionManager.play_scripted(CaptionTracks.SHED_REMEMBERED_COPY)
	await _wait(CaptionTracks.get_length(CaptionTracks.SHED_REMEMBERED_COPY))
	if _alive(run):
		_remembered_player.stop()


## The recording: the footage clock runs from zero to the footage's length, frame by frame (and stops with the pause). No caption speaks
## for it and no voice; the tape's own noise is looped under it. Nothing is a timer that could drift from the picture. It is not replayed.
func _shot_footage(run: int) -> void:
	CaptionManager.clear()
	_footage_time = 0.0
	_footage_playing = true
	_start_tape_sound()
	var length: float = footage.length_seconds if footage != null else 0.0
	while _alive(run) and _footage_playing and _footage_time < length:
		await get_tree().process_frame
	if _alive(run):
		_footage_playing = false
		_apply_footage(length)
	_stop_tape_sound()


## The photograph's print, held in a close view among Sophia's things (the real print, a model in the present world): no sound, no words.
func _shot_photo(run: int) -> void:
	CaptionManager.clear()
	await _wait(photo_shot_seconds)


## The remembered conversation, one still shot (no drift: the girls are not in the room).
func _shot_talk(run: int) -> void:
	_play_voice(_remembered_player, _pick_voice(voice_talk, voice_talk_en))
	CaptionManager.clear()
	CaptionManager.play_scripted(CaptionTracks.SHED_REMEMBERED_TALK)
	await _wait(CaptionTracks.get_length(CaptionTracks.SHED_REMEMBERED_TALK))
	if _alive(run):
		_remembered_player.stop()


## Back to the player's own camera, where her view was left (the shot cameras are gone).
func _back_to_her_eyes() -> void:
	CaptionManager.clear()
	_duck_forest(false)
	var camera: Camera3D = _get_camera()
	if camera != null:
		camera.make_current()
	_free_cinema_camera()


## The view is hers again; the token can be taken with the usual interaction.
func _finish_recording() -> void:
	_stage = Stage.DONE
	_cleanup_scene()
	_release_player()
	CaptionManager.clear()
	recording_finished.emit()


## The scene is over (even if it is cut short): the token is free and the state is saved. Nothing is added to the inventory.
func _mark_done() -> void:
	SaveManager.set_state_value(STATE_SECTION, KEY_RECORDING_DONE, true)
	SaveManager.set_state_value(STATE_SECTION, KEY_BOX_OPEN, true)
	_set_tape_beside_box()
	_set_token_available(true)


## For a scene that is left while the recording plays (the pause menu's way out, a scene change) and for the tests: see `_cancel_recording`.
func cancel_recording() -> void:
	_cancel_recording()


## Stops a scene that is playing and gives everything back. If it was not over (the token not yet freed), it is as before: the
## tape on the token, ready to be examined again; if it was over, the tape stays beside the box and the token is free.
func _cancel_recording() -> void:
	if _stage != Stage.RUNNING:
		return

	_run += 1
	var finished: bool = _is_done()
	_stage = Stage.DONE if finished else Stage.AVAILABLE
	_cleanup_scene()
	if finished:
		_set_tape_beside_box()
		_set_token_available(true)
	else:
		_set_tape_in_box()
		_set_token_available(false)
		_set_camcorder_yaw(camcorder_start_yaw_degrees)
	if is_inside_tree():
		CaptionManager.clear()
	_release_player()


## The recording's dressing, its overlay, its sounds, its cameras and the tweens, all put away. The present is shown whole.
func _cleanup_scene() -> void:
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_clear_freeze()
	_set_recording_world(false)
	_show_overlay(false)
	if _remembered_player != null:
		_remembered_player.stop()
	_stop_footage()
	_duck_forest(false)
	_set_camcorder_light(false)
	_stop_tape_sound()


# ============================================================
# THE FOOTAGE (one clock)
# ============================================================

## Advances the footage clock and shows the footage at it (frame by frame; the pause stops it). Nothing runs outside RUNNING.
func _tick_footage(delta: float) -> void:
	if _stage != Stage.RUNNING or footage == null or not _footage_playing:
		return

	_footage_time = minf(_footage_time + delta, footage.length_seconds)
	_apply_footage(_footage_time)


## The cast at `time`, as the tape shows it. A pure function of the time (the camera is fixed and has nothing to follow).
func _apply_footage(time: float) -> void:
	if footage != null:
		footage.seek(_tape_time(time))
	if _overlay != null and is_instance_valid(_overlay) and footage != null:
		var left: float = footage.length_seconds - time
		_overlay.set_burst(smoothstep(tape_end_seconds, 0.0, left) if left < tape_end_seconds else 0.0)
	# The camera is fixed, but the window may change: the lens follows it so that the picture's own 4:3 frame stays the designed one.
	if _world_state == WorldState.RECORDING and _cinema != null and is_instance_valid(_cinema) and shot_recording != null:
		_cinema.fov = ArchiveVideoOverlay.matched_fov(shot_recording.fov, get_viewport().get_visible_rect().size)


## The footage time the tape shows at `time`: the tape updates only `ArchiveVideoOverlay.TAPE_FPS` times a second, and holds the picture during a stall.
func _tape_time(time: float) -> float:
	var held: float = time
	for i: int in range(0, tape_stalls.size() - 1, 2):
		if time >= tape_stalls[i] and time < tape_stalls[i] + tape_stalls[i + 1]:
			held = tape_stalls[i]
			break
	return floorf(held * ArchiveVideoOverlay.TAPE_FPS) / ArchiveVideoOverlay.TAPE_FPS


## The footage stops and the cast is put away at its first frame, whatever it was doing.
func _stop_footage() -> void:
	_footage_playing = false
	if footage != null:
		footage.show_cast(false)
		footage.seek(0.0)


## For the developer console and for review: shows the recording at one moment of the footage, as it is in the scene (the recording's
## camera, its exposure, its ferns and picture), without taking the player. `time` below zero ends the preview. Not while the scene runs.
func preview_footage(time: float) -> bool:
	if _stage == Stage.RUNNING or footage == null:
		return false

	if time < 0.0:
		_stop_footage()
		_set_recording_world(false)
		_show_overlay(false)
		_free_cinema_camera()
		var eyes: Camera3D = _get_camera()
		if eyes != null:
			eyes.make_current()
		return true

	footage.prepare()
	if not footage.is_prepared():
		return false

	_show_camera(shot_recording, true)
	_apply_footage(time)
	_set_recording_world(true)
	_show_overlay(true)
	_set_shot_light(false)
	return true


# ============================================================
# THE WORLD, AS THE RECORDING HAS IT
# ============================================================

## The recording's version of the shelter, or the present's. Only ever changed under a cut (or with nothing of it in view).
func _set_recording_world(recording: bool) -> void:
	set_world_state(WorldState.RECORDING if recording else WorldState.PRESENT)


## The shelter's look: PRESENT (Sophia's things, the replaced plank, the camcorder), RECORDING (an ordinary bench with its old plank whole, the
## cast, the ferns at the lens; no belongings, no blood) or PHOTO_CAPTURE (the bench as the aftermath photograph shows it: the old plank
## broken, no cast, no belongings; the blood itself is dressed by the developer's capture tool, `ShelterAftermathDressing`, and nowhere else).
## Only the capture tool ever asks for the last one. The three never mix.
func set_world_state(state: WorldState) -> void:
	_world_state = state
	var present: bool = state == WorldState.PRESENT
	var recording: bool = state == WorldState.RECORDING
	if effects_root != null:
		effects_root.visible = present
	if camcorder != null:
		camcorder.visible = present
	if replaced_plank != null:
		replaced_plank.visible = present
	if archive_dressing != null:
		archive_dressing.visible = not present
		var intact: Node3D = archive_dressing.get_node_or_null("Intact") as Node3D
		var damaged: Node3D = archive_dressing.get_node_or_null("Damaged") as Node3D
		if intact != null:
			intact.visible = recording
		if damaged != null:
			damaged.visible = state == WorldState.PHOTO_CAPTURE
	# The ferns at the lens and the two people exist only in the recording: shown with it, and put away (the cast at its first frame) with it.
	if archive_foreground != null:
		archive_foreground.visible = recording
	if footage != null:
		footage.show_cast(recording)
		if not recording:
			footage.seek(0.0)


func get_world_state() -> WorldState:
	return _world_state


func _show_overlay(on: bool) -> void:
	if not on:
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.hide_overlay()
		return

	if _overlay == null or not is_instance_valid(_overlay):
		_overlay = ArchiveVideoOverlay.new()
		add_child(_overlay)
	_overlay.show_picture()


## The forest silent while the memory plays (no wind, no night chorus; the recording has its own sound), and let back for her own eyes.
func _duck_forest(on: bool) -> void:
	if on == _ducking or not is_inside_tree():
		return

	_ducking = on
	get_tree().call_group(OutdoorAmbience.GROUP, "set_silenced", MUFFLE_SOURCE, on)


func _head() -> Node3D:
	return camcorder.find_child("Head", true, false) as Node3D if camcorder != null else null


func _set_camcorder_yaw(degrees: float) -> void:
	var head: Node3D = _head()
	if head != null:
		head.rotation_degrees.y = degrees


func _set_camcorder_light(on: bool) -> void:
	if camcorder != null:
		ShedRecordingProps.camcorder_set_recording(camcorder, on)


# ============================================================
# THE PLAYER, HELD
# ============================================================

## The player is held as a scene holds them: no walking, looking, interacting or saving; the flashlight is the scene's. What another
## system had set is remembered and put back.
func _hold_player(target: Node) -> void:
	_held = target
	_held_view_locked = bool(target.get("view_locked"))
	_held_scripted_flashlight = bool(target.get("scripted_flashlight"))
	_held_save_block = bool(target.get("manual_save_blocked"))
	target.set("scripted_flashlight", true)
	target.call("set_view_locked", true)
	target.call("set_manual_save_blocked", true)

	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		_held_motion_still = movement.view_motion_still
		movement.view_motion_still = true
		_held_gesture_direct = movement.gesture_direct

	_flashlight = target.get("flashlight_controller") as Node
	_flash_scripted = false
	if _flashlight != null and _flashlight.has_method("begin_scripted_light"):
		_flash_was_on = bool(_flashlight.get("flashlight_on"))
		_flashlight.call("begin_scripted_light")
		_flash_scripted = true
		_set_flashlight_scene(false)


## The flashlight in the scene: out for the memory, on (at its usual strength, steady) for her own eyes.
func _set_flashlight_scene(on: bool) -> void:
	if _flash_scripted and _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.call("set_scripted_light", on and bool(_flashlight.get("flashlight_input_enabled")), 1.0)


## Gives the player back: their own eyes (the view where the scene left it, so the first mouse movement turns from there), their
## flashlight as it was, and whatever was held before.
func _release_player() -> void:
	var movement: PlayerMovementController = _get_movement()
	if movement != null and movement.camera != null and movement.camera.is_inside_tree():
		movement.camera.make_current()
		movement.scripted_fov = 0.0
		movement.gesture_offset = Vector3.ZERO
		movement.gesture_pitch_degrees = 0.0
		movement.gesture_direct = _held_gesture_direct
		movement.view_motion_still = _held_motion_still
	_free_cinema_camera()

	if _flash_scripted and _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.set("flashlight_on", _flash_was_on)
		_flashlight.call("end_scripted_light")
	_flash_scripted = false

	if _held == null or not is_instance_valid(_held):
		_held = null
		return

	_held.call("set_view_locked", _held_view_locked)
	_held.set("scripted_flashlight", _held_scripted_flashlight)
	_held.call("set_manual_save_blocked", _held_save_block)
	_held = null


# ============================================================
# THE SCENE'S CAMERA
# ============================================================

## Cuts to the scene's camera at a shot's marker, standing still. `recording` gives the camera the recording's own exposure (see `_recording_environment`).
func _show_camera(shot: ShotMarker, recording: bool = false) -> void:
	var camera: Camera3D = _cinema_camera()
	camera.global_transform = shot.aimed_transform()
	camera.fov = ArchiveVideoOverlay.matched_fov(shot.fov, get_viewport().get_visible_rect().size) if recording else shot.fov
	var eyes: Camera3D = _get_camera()
	camera.environment = _recording_environment() if recording else (eyes.environment if eyes != null else null)
	camera.make_current()


## The recording's environment: the level's own, copied, with no fog and a pale ambient. Only the recording's camera has it; nothing global changes.
func _recording_environment() -> Environment:
	if _archive_environment != null:
		return _archive_environment

	var source: Environment = get_world_3d().environment if get_world_3d() != null else null
	_archive_environment = (source.duplicate() as Environment) if source != null else Environment.new()
	_archive_environment.fog_enabled = false
	_archive_environment.volumetric_fog_enabled = false
	_archive_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_archive_environment.ambient_light_color = archive_ambient_color
	_archive_environment.ambient_light_energy = archive_ambient_energy
	_archive_environment.adjustment_enabled = true
	_archive_environment.adjustment_brightness = archive_brightness
	_archive_environment.adjustment_contrast = 1.08
	return _archive_environment


## The faint light of the two shots over the bench: on or off (it is a child of the scene's camera).
func _set_shot_light(on: bool, energy: float = -1.0) -> void:
	if _shot_light != null and is_instance_valid(_shot_light):
		_shot_light.visible = on
		_shot_light.light_energy = (shot_light_energy if energy < 0.0 else energy) if on else 0.0


## The scene's camera, made the first time: the player's lens settings (exposure included), without their depth of field (it
## follows what the player aims at), and a near plane close enough for the shots near the bench.
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
	_shot_light = SpotLight3D.new()
	_shot_light.name = "ShotLight"
	_shot_light.light_color = Color(0.82, 0.89, 1.0)
	_shot_light.spot_range = shot_light_range
	_shot_light.spot_angle = shot_light_angle
	_shot_light.spot_attenuation = 0.8
	_shot_light.shadow_enabled = false
	_shot_light.light_energy = 0.0
	_shot_light.visible = false
	_cinema.add_child(_shot_light)
	return _cinema


func _free_cinema_camera() -> void:
	if _cinema != null and is_instance_valid(_cinema):
		_cinema.queue_free()
	_cinema = null


## The matched dissolve: a still of the last frame shown over the live one and faded away over `seconds`. Whatever changes under it in
## the same frame is revealed through the dissolve, not seen happening. (Nothing to take a still of without a screen: a plain cut.)
func _dissolve(seconds: float) -> void:
	_clear_freeze()
	if seconds <= 0.0 or DisplayServer.get_name() == "headless" or not is_inside_tree():
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


# ============================================================
# SOUND
# ============================================================

## One player for each layer of the mix. They only play what is assigned (or a placeholder); nothing waits for any of them to finish.
func _build_audio() -> void:
	_remembered_player = _make_player("RememberedVoices")
	_tape_player = _make_player("TapeSound")


func _make_player(player_name: String) -> AudioStreamPlayer:
	var made: AudioStreamPlayer = AudioStreamPlayer.new()
	made.name = player_name
	add_child(made)
	return made


## The clip for this voice language: the English one when the voices are English and it is assigned, else the plain one.
func _pick_voice(default_clip: AudioStream, english_clip: AudioStream) -> AudioStream:
	if english_clip != null and GameSettings.get_voice_locale() == "en":
		return english_clip
	return default_clip


func _play_voice(target: AudioStreamPlayer, clip: AudioStream) -> void:
	if target == null or clip == null:
		return

	target.stream = clip
	target.play()


## The tape's noise comes in with the recording's first frame and loops until it ends.
func _start_tape_sound() -> void:
	if _tape_player == null:
		return

	var clip: AudioStream = tape_sound if tape_sound != null else load(TAPE_SOUND_PATH) as AudioStream
	if clip == null:
		return

	if clip is AudioStreamMP3:
		(clip as AudioStreamMP3).loop = true
	_tape_player.stream = clip
	_tape_player.volume_db = -60.0
	_tape_player.play()
	create_tween().tween_property(_tape_player, "volume_db", tape_volume_db, maxf(tape_fade_seconds, 0.01))


func _stop_tape_sound() -> void:
	if _tape_player != null and _tape_player.playing:
		_tape_player.stop()


# ============================================================
# HELPERS
# ============================================================

func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


## Not "process always": the pause menu also pauses the scene.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0), false).timeout


func _get_player() -> Node3D:
	if player != null:
		return player

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group(&"player") as Node3D


func _get_inspect() -> PlayerInspectController:
	var target: Node3D = _get_player()
	return target.get("inspect_controller") as PlayerInspectController if target != null else null


func _get_movement() -> PlayerMovementController:
	var target: Node3D = _get_player()
	return target.get("movement_controller") as PlayerMovementController if target != null else null


func _get_camera() -> Camera3D:
	var movement: PlayerMovementController = _get_movement()
	return movement.camera if movement != null else null
