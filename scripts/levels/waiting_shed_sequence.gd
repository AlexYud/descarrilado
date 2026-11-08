extends Node3D
class_name WaitingShedSequence

## THE INVESTIGATION (see "THE INVESTIGATION" below; Prompts 25 and 26): documents -> videotape (under the main clipping) -> the first cinematic -> the physical camcorder, hidden in planting, whose lens is
## where the recording's first shot stands: through its viewfinder (reached by an assisted walk and a lean of the eye, masked by black), after the cinematic, the empty bloodstained shelter and a drag
## trail that ends under a small cover of leaves by the front-west pillar -> the leaves slide aside -> the family's reply (only read: it starts and releases nothing) -> the telephone token, which lies
## all along in a real recess behind the shelter, around a blind corner. The tape, after the first cinematic, is also a voluntary review (Play/Pause/Stop/Rewind/Fast-forward, with a rear segment before the
## excerpt). SUPERSEDED and removed: the token falling from the letter, the forced turn toward the camcorder, the camcorder's fill light.
## The text below this header is older: where it says "the box", read "the bench"; where it says the token is freed or released, it lies in its recess from the start.
##
## The waiting shed, "The Shelter Stayed Open" (the middle route, Sophia's). The player finds a railway waiting shelter with
## Sophia's things on its bench: her notebook, a newspaper clipping (both optional), her closed backpack, and a small hinged
## box that opens with a plain interaction. The videotape lies in the open box on top of the telephone token.
##
## Examining the tape is the one interaction that matters. The FIRST time that view is closed the scene takes the player's eyes
## and plays once, without giving control back between its parts (all subtitles for now; the voice clips are optional hooks):
##   1. The tape set down beside the box, the notebook in the shot; Juliana remembers Sophia showing her the copy.
##   2. The recording itself, about 31 s, a worn, copied home-video tape (`ArchiveVideoOverlay`: coarse picture, bleeding colour, tracking lines, dropouts, 12 frames a second), silent, in four shots
##      and three hard cuts (`ShelterFootage` performs it on one clock): a hidden, locked camera watches Emily sit on the bench, and after five seconds she turns toward her right and greets
##      someone out of the picture with a short wave (to 10 s); a camera carried forward, pointed at the forest floor (to 16 s); the empty, bloodstained shelter with its bench broken, from the
##      aftermath photograph's own viewpoint, held by someone who walks slowly from side to side showing it, the head bobbing a little (to 23 s); and the carried camera again over the forest floor,
##      along another strip (to 31 s), where the tape ends. Only the tape's own noise (`placeholder_video_tape`, looped) is heard in it; no caption speaks for it.
##   3. The tape stops (static, the machine's last sound) and starts AGAIN at once: the second viewing, with PLAY on it, from `replay_from_seconds` (just before Emily turns). Just as Juliana begins
##      to ask Sophia to stop ("Não. Pode parar, por favor.") the picture is held, with PAUSE on it, on the greeting; the machine stops, and the talk goes on over the held picture.
##   4. A moment after Juliana's "Sophia…" the picture cuts to the photograph (the print mounted on Sophia's clipping, the shelter after the body was taken away, blood on the bench, the floor and the
##      pillar's foot) and stays there through the rest of the conversation, to its last word. Then the view is hers again, at once (a short dissolve to her own eyes): nothing more is played.
##      The machine's own sounds (placeholder_tape_player_sounds, see `TapePlayerSounds`): the first viewing begins 2.30 s after the machine starts (static, the
##      machine taking the tape, the play button), the running sound loops for as long as the tape plays and the last part plays when it ends or is stopped.
## The wind and the night chorus are silent from the first shot to the last (the scene is a memory). The scene never runs twice. Its completion is
## saved apart from the token's collection. The token is the same Collectible as before (`sophia_ficha`); it cannot be taken while the tape lies on
## it, nor during the scene.
##
## Emily in the recording, the blood of its last shot and the ferns that hide its first camera are never in the present: they are shown only inside the recording
## and are hidden (the cast put back at its first frame) before any cut to the present, on finishing, on cancelling and on leaving. The
## shelter has three looks that never mix (see `WorldState`): the recording's, the present's, and the aftermath that the shipped
## photograph was captured in (only a developer's capture tool ever asks for that one).
##
## Saved (section `puzzles`): `shelter_clipping_read`, `shelter_recording_done` (the first cinematic is over; it no longer frees the token), `shelter_leaf_revealed`, `shelter_letter_read`, `shelter_rear_seen` (the review reached the rear segment) and `shelter_review_playhead` (the review's excerpt-clock position, nothing else reads it);
## `junction_switch_box_open` is the old hinged box's key and is not read any more. Older saves are mapped, see
## `migrate_saved_state`. Every length of time below is an export, to be tuned in play.

signal recording_started
signal recording_finished
## The Ficha's view was closed (the token taken and looked at). Unchanged from the older puzzle; nothing listens for it yet.
signal sequence_completed

enum Stage { AVAILABLE, RUNNING, DONE }

const STATE_SECTION: StringName = &"puzzles"
const KEY_RECORDING_DONE: StringName = &"shelter_recording_done"
## The old hinged box's own key (nothing of the shed reads it any more: the box is gone, and it proves nothing about the new investigation).
const KEY_BOX_OPEN: StringName = &"junction_switch_box_open"
## The investigation's stages (see "THE INVESTIGATION"): the main clipping was read (the tape is exposed); the leaf cover was slid aside (the letter is exposed); the letter was read (the token's reveal is resolved).
const KEY_CLIPPING_READ: StringName = &"shelter_clipping_read"
const KEY_LEAF_REVEALED: StringName = &"shelter_leaf_revealed"
const KEY_LETTER_READ: StringName = &"shelter_letter_read"
## The rear segment of the tape was seen in review (a record of discovery, not a lock) and where the review last stood (seconds of the excerpt's clock).
const KEY_REAR_SEEN: StringName = &"shelter_rear_seen"
const KEY_REVIEW_PLAYHEAD: StringName = &"shelter_review_playhead"
const CLIPPING_INSPECT_ID: StringName = &"shed_clipping"
const LETTER_INSPECT_ID: StringName = &"shed_family_letter"
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
## The videotape: it lies on the bench under the main clipping and offers nothing until that clipping has been read.
@export var vhs: ShedTape
## The telephone token: Sophia's one collectible. It lies in a recess behind the shelter from the start (a real hiding place: nothing but the lip of the recess and the return wall keeps it from being found early).
@export var ficha: Collectible
## Where the tape lies on the bench (a marker in the space of `effects_root`; its position and rotation are the tape's). Where the scene puts it down is where it lay: it is never carried.
@export var vhs_set_down: Marker3D
## Everything of Sophia's on the bench: hidden while the recording shows the bench as it was.
@export var effects_root: Node3D
## What only the recording and the aftermath photograph show: the bench's front plank before it was replaced (`Intact` in the recording,
## `Damaged` in the aftermath). Kept hidden in the present.
@export var archive_dressing: Node3D
## The bench's replaced plank (hidden while the recording shows the old one).
@export var replaced_plank: Node3D
## The ferns close to the recording's lens: they exist only inside the recording.
@export var archive_foreground: Node3D
## The camcorder on its tripod, and its turning `Head` (found in its model).
@export var camcorder: ShedCamcorder
## The performance inside the recording (two actors) and the clock it is a function of.
@export var footage: ShelterFootage

@export_category("Shots")
## Where each shot stands, what it looks at and its lens (see ShotMarker). The scene's camera is placed from them.
@export var shot_copy: ShotMarker
## The recording's camera is FIXED: this one marker, for the whole excerpt (no reframe, no zoom, no shake).
@export var shot_recording: ShotMarker
## The close view of the photograph's print among Sophia's things.
@export var shot_photo: ShotMarker

@export_category("Look of the shots")
## A faint cold light on the bench for the shot over the notebook, the tape and the box (shot 1), at the camera: the lamp alone leaves the box dark.
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
@export var tape_stalls: PackedFloat32Array = PackedFloat32Array()
## The tape ends in static over this many last seconds of the footage.
@export var tape_end_seconds: float = 0.5
## The machine's sounds (`TapePlayerSounds`): their level. The first viewing's picture comes after the machine's first part (static meanwhile), 2.30 s.
@export var machine_volume_db: float = -3.0
## The second viewing (section 3): the picture is held (PAUSE, the machine stops) this long after Juliana's first "Não." begins (CAPTION_SHED_REPLAY_08),
## and the photograph cuts in this long after the end of her "Você não devia ficar vendo esse tipo de coisa." (CAPTION_SHED_TALK_01).
@export var replay_stop_after_start_seconds: float = 0.25
@export var photo_after_replay_seconds: float = 1.0
## The frame of the excerpt (seconds of the EXCERPT's clock) the second viewing is held on: while she waves. Where the replay begins is worked out from it (it is that much earlier than the hold, by the time the hold takes).
@export var replay_hold_source_seconds: float = 13.6
## The faint light the carried camera (the recording's second shot) throws on the ground ahead of it.
@export var walk_light_energy: float = 1.6
## A faint fill at the last shot's camera so that the blood and the broken bench read through the tape (the photograph was taken with a flash).
@export var aftermath_light_energy: float = 0.0
## How much brighter the ambient is in the aftermath and the rear segment (a soft, even light replaces the lamp's hotspot).
@export var aftermath_ambient_boost: float = 2.7
@export var aftermath_light_range: float = 9.0
## The rest of the performance (its length and every moment of it) is on the `Footage` node (`ShelterFootage`); its three cameras are the markers `shot_a`, the strip
## `walk_start` to `walk_end`, and `shot_c` there (`shot_recording` is shot A: where the recording begins).

@export_category("Investigation (evidence, camcorder, review, rear)")
## The main clipping lying over the tape: reading it once exposes the tape (it is moved to `clipping_aside`, a marker in the space of `effects_root`).
@export var clipping: Inspectable
@export var clipping_aside: Marker3D
## The family's reply under the leaf cover at the foot of the cracked front pillar. Reading it is only reading it: nothing is released by it.
@export var letter: GatedInspectable
## The leaf cover over the letter: its children named `Leaves*` slide aside by `leaf_aside_offset` (metres, in the cover's space) when the cover is revealed; the other children (ferns) stay.
@export var leaf_cover: Node3D
@export var leaf_aside_offset: Vector3 = Vector3(0.12, 0.0, -0.5)
## What exists only in some looks of the shelter. `investigation_root` (the leaves and the letter) is in the present and in the viewfinder, not in the recording; `camcorder_cover` (the plants round the
## camcorder) in the present only; `rear_annex` (the return wall, the repair patch, the token's recess and the token) in the present and in the viewfinder, and in the recording only in its rear segment.
@export var investigation_root: Node3D
@export var camcorder_cover: Node3D
@export var rear_annex: Node3D
## The viewfinder: after the first cinematic, this long (seconds) the picture is held for reading before the leaves start to slide, then this long (seconds) they take.
@export var viewfinder_read_seconds: float = 2.5
@export var leaf_slide_seconds: float = 1.0
## Putting the eye to the eyecup: the walk (when she is not already at the rear of the device) is the project's guided walk; then the lean takes this long (seconds), and a short black occlusion (the eyecup)
## hides the cut to the lens. Stepping back takes `viewfinder_exit_seconds`. A fresh movement input is accepted this long (seconds) after the view has settled.
@export var viewfinder_enter_seconds: float = 1.5
@export var viewfinder_exit_seconds: float = 0.55
@export var viewfinder_input_guard_seconds: float = 0.35
@export var viewfinder_occlusion_seconds: float = 0.25
## How far the body stops behind the eyecup (metres): the eye goes the rest of the way.
@export var viewfinder_stand_back_metres: float = 0.55
## The word on the viewfinder's picture (the machine's own, not a translated text).
@export var viewfinder_label: String = "CAM"
## The scene that uncovers the tape (shed-local): where the camera stands and what it looks at, the lens, how long the paper takes to slide aside and how long the tape is then held in view.
@export var clipping_shot_position: Vector3 = Vector3(-4.12, 1.08, -4.95)
@export var clipping_shot_target: Vector3 = Vector3(-4.2, 0.5, -5.78)
@export var clipping_shot_fov: float = 40.0
@export var clipping_slide_seconds: float = 1.4
@export var clipping_hold_seconds: float = 2.0
## The forest's plants within `vegetation_clear_inner` metres of the tape's camera shrink away, up to `vegetation_clear_outer` partly (no leaf passes through the lens).
@export var vegetation_clear_inner: float = 1.0
@export var vegetation_clear_outer: float = 2.4
## The fill light of the viewfinder after the first cinematic (at the lens, over the slab), stronger than the recording's own so that the dark drag trail reads against the slab through the tape look.
@export var viewfinder_light_energy: float = 7.0
## The pale ambient of the recording's environment is raised by this factor in the post-video viewfinder only (the camera's own environment: nothing global), again for the trail to read.
@export var viewfinder_ambient_boost: float = 2.4
## After the first cinematic: control and ambience come back, and this long (seconds) afterwards the camcorder, behind her, makes a small mechanical sound. Its level (dB) and how far it carries (metres).
@export var camcorder_cue_delay_seconds: float = 1.5
@export var camcorder_cue_volume_db: float = 2.0
@export var camcorder_cue_distance: float = 30.0
## The voluntary tape review: the speed of a rewind or a fast-forward search (times the tape's own), the faint light of the rear segment's camera, and where the first review starts (seconds of the EXCERPT's clock: 0 is
## the first frame of the Emily excerpt, which the tape reaches `rear_prefix_seconds` after its own start).
@export var review_search_speed: float = 4.0
@export var review_start_excerpt_seconds: float = 0.0
@export var rear_light_energy: float = 2.4
@export var rear_light_range: float = 7.0

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
var _ducking: bool = false

# The investigation. `_aux_mode` is what holds the player OUTSIDE the first cinematic: the camcorder's viewfinder (TRANSITION while she walks, leans or withdraws, VIEWFINDER once the picture has settled), or
# the voluntary tape review. `_aux_run` cancels a coroutine of either; `_cue_run` the camcorder's sound after the first cinematic.
enum AuxMode { NONE, VIEWFINDER, REVIEW, TRANSITION }
var _aux_mode: AuxMode = AuxMode.NONE
var _aux_run: int = 0
var _cue_run: int = 0
var _cue_player: AudioStreamPlayer3D = null
var _prompt_layer: CanvasLayer = null
var _prompt_label: Label = null
var _leaf_tween: Tween = null
var _leaf_busy: bool = false
## True while the paper over the tape is being moved aside (the saved flag is written at the end; until then the paper stays over the tape).
var _clipping_busy: bool = false
var _clipping_tween: Tween = null
var _leaf_sheets: Array[Node3D] = []
var _leaf_home: Array[Transform3D] = []
var _clipping_home: Transform3D = Transform3D.IDENTITY
# The viewfinder's entry and exit: where her view was, how far the eye goes, the black over the cut, when a fresh input is accepted.
var _vf_phase: StringName = &""
var _vf_saved_yaw: float = 0.0
var _vf_saved_pitch: float = 0.0
var _vf_full_offset: Vector3 = Vector3.ZERO
var _vf_ready_ms: int = 0
var _occlusion_layer: CanvasLayer = null
var _occlusion_rect: ColorRect = null
# The review: the playhead (seconds of the EXCERPT's clock, negative in the rear segment), the state (play, pause, stop, rew, ff), its UI and sound.
var _review_time: float = 0.0
var _review_state: StringName = &"pause"
var _review_ui: VhsReviewUi = null
var _review_machine_on: bool = false
var _review_held_actions: Dictionary = {}
var _review_ready_ms: int = 0
var _mouse_before: int = Input.MOUSE_MODE_CAPTURED

# The footage clock: what the recording shows is a function of `_footage_time`, advanced here frame by frame while the footage plays (and so
# stopped by the pause). Nothing else keeps time for the picture.
var _footage_playing: bool = false
## The vegetation wind (frozen while a tape picture is held) and the strength it had.
var _wind: Node = null
var _token_tape_material: StandardMaterial3D = null
var _wind_tween: Tween = null
var _wind_home: float = -1.0
var _footage_time: float = 0.0

# The shelter's three looks. They never mix; only changed under a cut (or with nothing of them in view).
enum WorldState { PRESENT, RECORDING, PHOTO_CAPTURE, VIEWFINDER }
var _world_state: WorldState = WorldState.PRESENT

# The audio layers: each its own player. The recording has none of its own (nor a rewind: it is not replayed).
var _remembered_player: AudioStreamPlayer = null
var _tape_player: AudioStreamPlayer = null
var _machine_player: AudioStreamPlayer = null
## True while the second viewing is on (the sequence's own flag, for the tests and the pause menu's sake).
var replay_running: bool = false


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
	TapePlayerSounds.prepare()
	_set_recording_world(false)
	_set_camcorder_light(false)
	_align_camcorder()
	if vhs != null and not vhs.review_requested.is_connected(_on_review_requested):
		vhs.review_requested.connect(_on_review_requested)
	if camcorder != null and not camcorder.viewfinder_requested.is_connected(_on_viewfinder_requested):
		camcorder.viewfinder_requested.connect(_on_viewfinder_requested)
	_remember_investigation_poses()
	_apply_investigation_state()
	_connect_to_player.call_deferred()
	# The cast of the recording and the blood of the viewfinder are built and posed now, out of sight, so that nothing is made while the scene is being watched.
	if footage != null:
		footage.prepare.call_deferred()


func _exit_tree() -> void:
	_cancel_recording()
	_abort_aux()
	if _leaf_tween != null and _leaf_tween.is_valid():
		_leaf_tween.kill()
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
	if _aux_mode == AuxMode.REVIEW:
		_review_process(delta)

	if (_stage == Stage.RUNNING or _aux_mode != AuxMode.NONE) and _held != null and is_instance_valid(_held):
		if bool(_held.call("is_inventory_open")):
			# The inventory is the one thing a held view still lets the player open: not while a scene holds the view.
			var inventory_ui: Node = _held.get("inventory_ui_controller") as Node
			if inventory_ui != null:
				inventory_ui.call("close")


## The viewfinder's and the review's own keys (see `_viewfinder_input`, `_review_input`). Nothing here touches Esc, which is the pause menu's.
func _input(event: InputEvent) -> void:
	if _aux_mode == AuxMode.VIEWFINDER:
		_viewfinder_input(event)
	elif _aux_mode == AuxMode.REVIEW:
		_review_input(event)


# ============================================================
# SAVED STATE
# ============================================================

## Maps an older save onto this scene, before the token reads it. In the older puzzle the token came out of a lever box (`junction_signal_box_open`) and was taken with a view
## (`junction_ficha_taken`); a token already taken or put in the payphone is gone for good. Any of these means the recording is over (it never replays, and nothing asks for the
## removed levers). THE INVESTIGATION IS NOT FINISHED BY AN OLD FLAG: the first cinematic being done only enables the camcorder; the hinged box's old key proves nothing. Only a token that is
## already gone (taken, or in the payphone) resolves every stage, so that nothing of the letter respawns. Nothing is wiped or renamed.
static func migrate_saved_state() -> void:
	var done: bool = bool(SaveManager.get_state_value(STATE_SECTION, KEY_RECORDING_DONE, false))
	done = done or bool(SaveManager.get_state_value(STATE_SECTION, KEY_FICHA_TAKEN, false))
	done = done or bool(SaveManager.get_state_value(STATE_SECTION, KEY_LEVER_BOX_OPEN, false))
	var token_gone: bool = bool(SaveManager.get_state_value(STATE_SECTION, KEY_FICHA_TAKEN, false))
	token_gone = token_gone or bool(SaveManager.get_state_value(&"collectibles", StringName(TOKEN_ID), false))
	var inserted: Variant = SaveManager.get_state_value(STATE_SECTION, KEY_FICHAS, [])
	if inserted is Array and TOKEN_ID in (inserted as Array):
		token_gone = true

	if done or token_gone:
		SaveManager.set_state_value(STATE_SECTION, KEY_RECORDING_DONE, true)
		SaveManager.set_state_value(STATE_SECTION, KEY_CLIPPING_READ, true)
	if token_gone:
		SaveManager.set_state_value(STATE_SECTION, KEY_LEAF_REVEALED, true)
		SaveManager.set_state_value(STATE_SECTION, KEY_LETTER_READ, true)


func _is_done() -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, KEY_RECORDING_DONE, false))


func is_recording_running() -> bool:
	return _stage == Stage.RUNNING


func is_recording_done() -> bool:
	return _stage == Stage.DONE


func _flag(key: StringName) -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, key, false))


func _set_flag(key: StringName) -> void:
	SaveManager.set_state_value(STATE_SECTION, key, true)


## The tape on the bench where it lay (it is never carried: only the first reading of the clipping, which uncovers it, and this put it anywhere).
func _set_tape_beside_box() -> void:
	if vhs == null or not is_instance_valid(vhs) or vhs_set_down == null:
		return

	vhs.transform = vhs_set_down.transform


## The tape as it lay before the recording (the scene was cut short before it finished): the same place.
func _set_tape_in_box() -> void:
	_set_tape_beside_box()


## For the developer console and the tests: the first cinematic is put back to "not seen" (the tape exposed and examinable, the camcorder showing the ordinary shelter), with the rest of the
## investigation undone, if nothing is playing and the token is not collected.
func reset_for_replay() -> bool:
	if _stage == Stage.RUNNING or _aux_mode != AuxMode.NONE:
		return false

	SaveManager.set_state_value(STATE_SECTION, KEY_RECORDING_DONE, false)
	SaveManager.set_state_value(STATE_SECTION, KEY_LEAF_REVEALED, false)
	SaveManager.set_state_value(STATE_SECTION, KEY_LETTER_READ, false)
	SaveManager.set_state_value(STATE_SECTION, KEY_REAR_SEEN, false)
	_stage = Stage.AVAILABLE
	_apply_investigation_state()
	return true


## For the developer console: whatever the first cinematic is doing, it is over at once (the player is let go). The rest of the investigation is NOT done by it.
func force_finish() -> void:
	if _stage == Stage.RUNNING:
		_mark_done()
		_cancel_recording()
	_stage = Stage.DONE
	_mark_done()
	_apply_investigation_state()


## For the developer console: every stage of the investigation is over at once (the leaves are aside, the reply is read). The token is not touched: it lies in its recess behind the shelter, to be found.
func force_resolve() -> void:
	_abort_aux()
	force_finish()
	_set_flag(KEY_LEAF_REVEALED)
	_set_flag(KEY_LETTER_READ)
	_apply_investigation_state()


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
		if _stage == Stage.AVAILABLE and not _is_done() and _aux_mode == AuxMode.NONE:
			_begin_recording()
	elif id == CLIPPING_INSPECT_ID:
		# The first reading of the essential clipping uncovers the tape, in a short scene (`_begin_clipping_reveal`): the paper is first set down where it lay (the item flies back to its source) and then moved aside by hand.
		if not _flag(KEY_CLIPPING_READ) and _stage != Stage.RUNNING and _aux_mode == AuxMode.NONE:
			_begin_clipping_reveal()
		elif not _flag(KEY_CLIPPING_READ):
			_set_flag(KEY_CLIPPING_READ)
			_apply_investigation_state()
	elif id == LETTER_INSPECT_ID:
		# Reading the family's reply is only reading it: it is remembered, and nothing starts, moves or is released.
		if not _flag(KEY_LETTER_READ):
			_set_flag(KEY_LETTER_READ)
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
	_set_camcorder_enabled()
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

	# Shot 3: the tape again, the talk over the held picture, and (after "Pode.") the photograph, which stays to the end of the conversation.
	await _shot_conversation(run)
	if not _alive(run):
		return

	# Then the view is hers: the scene's work done and the controls back, with a short dissolve from the last shot to her own eyes (the still it fades
	# is the last frame drawn, so it is taken after the change is made, in the same frame).
	_back_to_her_eyes()
	_mark_done()
	_finish_recording()
	_dissolve(dissolve_into_scene_seconds)
	# Her own eyes, as they were when she looked at the bench: no turn, no instruction. A moment later the camcorder behind her makes a small sound (see `_start_camcorder_cue`).
	_start_camcorder_cue()


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


## The recording: the machine starts (its first part: static on the screen, the tape taken, the play button down), and at 2.30 s the picture comes with PLAY on it and the
## footage clock runs from zero to the footage's length, frame by frame (and stops with the pause); the machine's running sound loops under it with the tape's own noise.
## No caption speaks for it and no voice. At its end the machine's last part plays once. Nothing is a timer that could drift from the picture.
func _shot_footage(run: int) -> void:
	CaptionManager.clear()
	_footage_time = 0.0
	_footage_playing = false
	_start_machine(true)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set_paused(false)
		_overlay.set_burst(1.0)
	await _wait_for_machine(run)
	if not _alive(run):
		return

	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set_burst(0.0)
	_apply_footage(0.0)
	_footage_playing = true
	_start_tape_sound()
	var length: float = footage.length_seconds if footage != null else 0.0
	while _alive(run) and _footage_playing and _footage_time < length:
		await get_tree().process_frame
	if _alive(run):
		_footage_playing = false
		_apply_footage(length)
	_stop_tape_sound()
	_stop_machine()
	# The machine's last part plays over the static; when it is over the tape starts again at once.
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set_burst(1.0)
	await _wait(TapePlayerSounds.stop_stream().get_length())


## The conversation, remembered, on the caption track's one clock, in two shots. The tape starts again at once (the same camera, the picture from replay_from, PLAY
## on it, the machine's running sound): a few seconds later Juliana asks Sophia to stop, the picture is held with PAUSE on it and the machine's last part plays, and the talk
## goes on over the held picture until "Você não devia ficar vendo esse tipo de coisa." and a pause; then a hard cut to the photograph (the present, with Sophia's things, whole again before it is seen; the cast put
## away), which stays through the rest of the conversation to its last word. The marks come from the cues of the track.
func _shot_conversation(run: int) -> void:
	_play_voice(_remembered_player, _pick_voice(voice_talk, voice_talk_en))
	CaptionManager.clear()
	CaptionManager.play_scripted(CaptionTracks.SHED_REMEMBERED_TALK)
	var total: float = CaptionTracks.get_length(CaptionTracks.SHED_REMEMBERED_TALK)
	var stop_at: float = replay_stop_seconds()
	var photo_at: float = photo_cut_seconds()

	# The tape starts again.
	replay_running = true
	var from: float = replay_from()
	_footage_time = from
	_apply_footage(from)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set_paused(false)
		_overlay.set_burst(0.0)
	_footage_playing = true
	_start_machine(false)
	_start_tape_sound()
	await _wait(stop_at)
	if not _alive(run):
		replay_running = false
		return

	# A quarter of a second into her first "Não.": the picture is held on the greeting (the cut to the walking shot never comes), the machine says PAUSE and stops; her request and the next line are said over the held frame.
	_footage_playing = false
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set_paused(true)
	_freeze_wind(true)
	_stop_tape_sound()
	_stop_machine()
	await _wait(maxf(photo_at - stop_at, 0.0))
	if not _alive(run):
		replay_running = false
		return

	# The photograph, to the end.
	_set_recording_world(false)
	_show_overlay(false)
	_show_camera(shot_photo)
	_set_shot_light(true, photo_light_energy)
	replay_running = false
	await _wait(maxf(total - photo_at, 0.0))
	if _alive(run):
		_remembered_player.stop()


## Where in the footage (the excerpt's clock) the second viewing begins: early enough that, `replay_stop_seconds()` later, it is at `replay_hold_source_seconds` (held on her wave). Never before the start of the excerpt, never past the first cut.
func replay_from() -> float:
	return clampf(replay_hold_source_seconds - replay_stop_seconds(), 0.0, footage.cut_walk_seconds - 0.5) if footage != null else 0.0


## When the second viewing is held, in seconds of the conversation's track: a moment after her first "Não." begins (`CAPTION_SHED_REPLAY_08`). From the cue, not from a number kept here.
func replay_stop_seconds() -> float:
	return _cue_time(&"CAPTION_SHED_REPLAY_08", "start") + replay_stop_after_start_seconds


## When the picture cuts to the printed photograph, in seconds of the track: `photo_after_replay_seconds` after the end of "Você não devia ficar vendo esse tipo de coisa." (`CAPTION_SHED_TALK_01`).
func photo_cut_seconds() -> float:
	return _cue_time(&"CAPTION_SHED_TALK_01", "end") + photo_after_replay_seconds


## When a cue of the conversation's track starts or ends ("start" or "end"), in seconds of the track; 0 if the track has no such cue.
func _cue_time(key: StringName, edge: String) -> float:
	for cue: Dictionary in CaptionTracks.get_cues(CaptionTracks.SHED_REMEMBERED_TALK):
		if StringName(str(cue["key"])) == key:
			return float(cue[edge])
	return 0.0


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
	_apply_investigation_state()
	recording_finished.emit()


## The first cinematic is over (even if it is cut short) and the state is saved: the camcorder's viewfinder now shows what the tape left. The token is NOT freed by it: that is the end of the
## investigation (the final letter). Nothing is added to the inventory.
func _mark_done() -> void:
	SaveManager.set_state_value(STATE_SECTION, KEY_RECORDING_DONE, true)
	SaveManager.set_state_value(STATE_SECTION, KEY_CLIPPING_READ, true)
	_set_tape_beside_box()
	_apply_investigation_state()


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
	else:
		_set_tape_in_box()
	_apply_investigation_state()
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
	_stop_tape_sound()
	_freeze_wind(false, true)
	_stop_tape_sound()
	if _machine_player != null:
		_machine_player.stop()


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
	var shown: float = _tape_time(time)
	if footage != null:
		footage.seek(shown)
	if _overlay != null and is_instance_valid(_overlay) and footage != null:
		var left: float = footage.length_seconds - time
		_overlay.set_burst(smoothstep(tape_end_seconds, 0.0, left) if left < tape_end_seconds else 0.0)
	# Each shot has its own camera, a pure function of the source time (locked, walking, drifting), and its own shelter: the intact bench and the ferns at the lens in the first, the broken bench
	# and the blood in the last. Only while the recording is on screen (the photograph's camera and the player's are never touched). The window may change: the lens follows it so that the
	# picture's own 4:3 frame stays the designed one.
	if _world_state == WorldState.RECORDING and footage != null:
		var passage: StringName = footage.passage_at(shown)
		_set_shot_dressing(passage, shown)
		if _cinema != null and is_instance_valid(_cinema):
			var state: Dictionary = footage.camera_at(shown)
			_cinema.global_transform = state["transform"] as Transform3D
			_cinema.fov = ArchiveVideoOverlay.matched_fov(float(state["fov"]), get_viewport().get_visible_rect().size)
			_clear_vegetation_round(true, _cinema.global_position)


## The shelter as the shot shows it: the bench whole and the ferns near the lens in the first, the bench broken (and the blood, which the footage shows with its last shot) in the last.
func _set_shot_dressing(passage: StringName, shown_time: float = 0.0) -> void:
	# The bench is whole in the first shot and broken in the last two (the second walk is later than the aftermath, by an unknown time).
	var aftermath: bool = passage == &"aftermath" or passage == &"walk2"
	if archive_dressing != null:
		var intact: Node3D = archive_dressing.get_node_or_null("Intact") as Node3D
		var damaged: Node3D = archive_dressing.get_node_or_null("Damaged") as Node3D
		if intact != null:
			intact.visible = not aftermath
		if damaged != null:
			damaged.visible = aftermath
	if archive_foreground != null:
		archive_foreground.visible = passage == &"A"
	# The rear annex (the return wall, the repair patch, the recess) is in the recording's rear segment only.
	if rear_annex != null:
		rear_annex.visible = passage == &"rear"
	# The carried camera sees the ground by a faint light of its own (the lamp of a camcorder), in both of its shots; shot A has none.
	_set_shot_light(passage == &"walk" or passage == &"walk2", walk_light_energy)
	if passage == &"aftermath":
		_set_shot_light(true, aftermath_light_energy)
	elif passage == &"rear":
		# The lamp of the camera shows only when the lens comes down to the recess: a narrow beam, brought up over a second, on the token (a wide lamp close to a wall is a white hotspot).
		_set_shot_light(true, rear_light_energy * smoothstep(footage.rear_lamp_from_seconds, footage.rear_lamp_from_seconds + 1.0, shown_time + footage.rear_prefix_seconds))
	if _shot_light != null and is_instance_valid(_shot_light):
		_shot_light.spot_range = aftermath_light_range if passage == &"aftermath" else (rear_light_range if passage == &"rear" else shot_light_range)
		# The aftermath and the rear segment are lit mostly by the night itself (an even ambient) and only a little by the lamp, which is wide and soft: a lamp close to a wall or the ground makes a white
		# hotspot where its cone ends, and plants near the lens go white.
		var soft: bool = passage == &"aftermath" or passage == &"rear"
		_shot_light.spot_angle = 16.0 if passage == &"rear" else (80.0 if soft else shot_light_angle)
		_shot_light.spot_attenuation = 1.0 if passage == &"rear" else (0.25 if soft else 0.8)
		_shot_light.light_specular = 1.0 if passage == &"rear" else (0.0 if soft else 0.5)
	if _archive_environment != null:
		_archive_environment.ambient_light_energy = archive_ambient_energy * (aftermath_ambient_boost if (passage == &"aftermath" or passage == &"rear") else 1.0)

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
## camera, its exposure, its ferns and picture), without taking the player. `time` is the EXCERPT's clock (0 is the Emily excerpt's first frame); the rear segment is at negative times down to `-rear_prefix_seconds`.
## `end_preview` puts the view back. Not while the scene runs.
func preview_footage(time: float) -> bool:
	if _stage == Stage.RUNNING or footage == null or _aux_mode != AuxMode.NONE:
		return false

	footage.prepare()
	if not footage.is_prepared():
		return false

	_show_camera(shot_recording, true)
	_set_recording_world(true)
	_set_shot_light(false)
	_apply_footage(maxf(time, -footage.rear_prefix_seconds))
	_show_overlay(true)
	return true


func end_preview() -> bool:
	if _stage == Stage.RUNNING or _aux_mode != AuxMode.NONE:
		return false

	_stop_footage()
	_set_recording_world(false)
	_show_overlay(false)
	_set_shot_light(false)
	_free_cinema_camera()
	var eyes: Camera3D = _get_camera()
	if eyes != null:
		eyes.make_current()
	return true


# ============================================================
# THE WORLD, AS THE RECORDING HAS IT
# ============================================================

## The recording's version of the shelter, or the present's. Only ever changed under a cut (or with nothing of it in view).
func _set_recording_world(recording: bool) -> void:
	set_world_state(WorldState.RECORDING if recording else WorldState.PRESENT)


## The shelter's look: PRESENT (Sophia's things, the replaced plank, the camcorder), RECORDING (an ordinary bench with its old plank whole, the
## cast, the ferns at the lens; no belongings, no blood), PHOTO_CAPTURE (the bench as the aftermath photograph shows it: the old plank
## broken, no cast, no belongings; the blood itself is dressed by the developer's capture tool, `ShelterAftermathDressing`, and nowhere else) or VIEWFINDER
## (what the camcorder's viewfinder shows after the first cinematic: the old plank broken, no belongings, no camcorder, nobody, and the footage's blood and the drag trail,
## as a static dressing with no clock). The four never mix; only the capture tool asks for PHOTO_CAPTURE.
func set_world_state(state: WorldState) -> void:
	_world_state = state
	if state != WorldState.RECORDING:
		_clear_vegetation_round(false)
	_set_token_tape_look(state == WorldState.RECORDING)
	var present: bool = state == WorldState.PRESENT
	var recording: bool = state == WorldState.RECORDING
	var viewfinder: bool = state == WorldState.VIEWFINDER
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
			damaged.visible = state == WorldState.PHOTO_CAPTURE or viewfinder
	# The ferns at the lens and the two people exist only in the recording: shown with it, and put away (the cast at its first frame) with it.
	if archive_foreground != null:
		archive_foreground.visible = recording
	# What exists in some looks only. The present and the viewfinder have the leaves, the letter and the rear annex (with the token); the recording has the annex in its rear segment only
	# (`_set_shot_dressing` shows it); the plants round the camcorder are the present's alone.
	if investigation_root != null:
		investigation_root.visible = present or viewfinder
	if camcorder_cover != null:
		camcorder_cover.visible = present
	if rear_annex != null:
		rear_annex.visible = present or viewfinder
	if footage != null:
		if viewfinder:
			footage.set_blood_view(true)
		else:
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


func _set_camcorder_light(on: bool) -> void:
	if camcorder != null:
		ShedRecordingProps.camcorder_set_recording(camcorder, on)


# ============================================================
# THE PLAYER, HELD
# ============================================================

## The player is held as a scene holds them: no walking, looking, interacting or saving; the flashlight is the scene's. What another
## system had set is remembered and put back.
func _hold_player(target: Node) -> void:
	_record_player(target)
	_lock_player()


## Notes what the player had (so that everything can be given back exactly) without holding them yet: the assisted walk to the camcorder needs a free, walking body (a locked view freezes the walk).
func _record_player(target: Node) -> void:
	_held = target
	_held_view_locked = bool(target.get("view_locked"))
	_held_scripted_flashlight = bool(target.get("scripted_flashlight"))
	_held_save_block = bool(target.get("manual_save_blocked"))
	target.call("set_manual_save_blocked", true)
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		_held_motion_still = movement.view_motion_still
		_held_gesture_direct = movement.gesture_direct


## Holds the player: the view locked, the motion still, the flashlight in the scene's hands.
func _lock_player() -> void:
	var target: Node = _held
	if target == null or not is_instance_valid(target):
		return

	target.set("scripted_flashlight", true)
	target.call("set_view_locked", true)
	target.call("set_manual_save_blocked", true)
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		movement.view_motion_still = true

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
		_archive_environment.ambient_light_energy = archive_ambient_energy
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
	_machine_player = _make_player("TapeMachine")


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


## Waits until the machine's first part is over: the picture begins when its sound has played to 2.30 s exactly (the machine's own clock, not a timer's: they
## would drift apart). Without a running sound (no audio) it waits 2.30 s of the scene's time; never more than a few seconds whatever happens.
func _wait_for_machine(run: int) -> void:
	var waited: float = 0.0
	while _alive(run) and waited < TapePlayerSounds.LOOP_BEGIN + 2.0:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		if _machine_player != null and _machine_player.playing:
			if _machine_player.get_playback_position() >= TapePlayerSounds.LOOP_BEGIN - 0.008:
				return
		elif waited >= TapePlayerSounds.LOOP_BEGIN:
			return


## The machine starts: its first part and then its running sound looped (`with_intro`), or only the running sound (the second viewing: the tape is only played again).
func _start_machine(with_intro: bool) -> void:
	if _machine_player == null:
		return

	_machine_player.stream = TapePlayerSounds.start_stream()
	_machine_player.volume_db = machine_volume_db
	_machine_player.play(0.0 if with_intro else TapePlayerSounds.LOOP_BEGIN)


## The machine stops: the running sound goes and its last part plays once.
func _stop_machine() -> void:
	if _machine_player == null:
		return

	_machine_player.stop()
	_machine_player.stream = TapePlayerSounds.stop_stream()
	_machine_player.volume_db = machine_volume_db
	_machine_player.play()


# ============================================================
# THE INVESTIGATION (documents, tape, camcorder, family reply, tape review, the rear)
# ============================================================
#
# Stages (saved in `puzzles`): the main clipping is read (`shelter_clipping_read`: the tape is exposed and offers its inspection) -> the first cinematic is over
# (`shelter_recording_done`: the camcorder's viewfinder shows the blood trail, and the tape becomes the entry to the voluntary review) -> the leaf cover has slid aside (`shelter_leaf_revealed`:
# the family's reply is exposed) -> the reply is read (`shelter_letter_read`: nothing is released by it) -> the rear segment of the tape was seen in review (`shelter_rear_seen`: a record, not a lock)
# -> the token behind the shelter is collected (the ordinary `collectibles.sophia_ficha`, `junction_ficha_taken`). The token is a real object from the start, hidden by real geometry.
# Every stage is written when it STARTS, and `_apply_investigation_state` puts the world as the flags say, so that a cancelled animation, a load or a revisit can neither lose nor repeat anything.
# (SUPERSEDED, removed: the token falling from the letter, and the forced turn toward the camcorder.)

## Remembers where the scene put what it moves (before anything is moved).
func _remember_investigation_poses() -> void:
	if clipping != null:
		_clipping_home = clipping.transform
	_leaf_sheets.clear()
	_leaf_home.clear()
	if leaf_cover != null:
		for child: Node in leaf_cover.get_children():
			var sheet: Node3D = child as Node3D
			if sheet != null and String(sheet.name).begins_with("Leaves"):
				_leaf_sheets.append(sheet)
				_leaf_home.append(sheet.transform)


## The shed as the saved flags (and what is running) say: the clipping over the tape or aside, the tape examinable (or, after the first cinematic, reviewable) or not, the leaves over the reply or aside, the reply
## hidden or exposed, and whether the camcorder may be used. The token is not here: it is a real object that nothing but its hiding place keeps from being found. Safe to call at any time.
func _apply_investigation_state() -> void:
	var clipping_read: bool = _flag(KEY_CLIPPING_READ) or _is_done()
	var leaf_done: bool = _flag(KEY_LEAF_REVEALED)
	if clipping != null and not _clipping_busy:
		clipping.transform = clipping_aside.transform if clipping_read and clipping_aside != null else _clipping_home
	if vhs != null:
		vhs.set_interaction_enabled(clipping_read)
		vhs.review_mode = _is_done()
		if _is_done():
			_set_tape_beside_box()
	# A slide of the leaves in progress is left to finish (its end sets the same state).
	if not _leaf_busy:
		_place_leaves(leaf_done)
	if letter != null:
		letter.visible = leaf_done
		letter.set_interaction_enabled(leaf_done and not _leaf_busy)
	_set_camcorder_enabled()


func _place_leaves(displaced: bool) -> void:
	for i: int in _leaf_sheets.size():
		if is_instance_valid(_leaf_sheets[i]):
			_leaf_sheets[i].transform = _leaf_displaced(i) if displaced else _leaf_home[i]


## Where a leaf sheet lies once the cover has slid aside: pushed along `leaf_aside_offset` (a little further, and turned a little, for each sheet, so that it reads as a gust and not a rigid move).
func _leaf_displaced(index: int) -> Transform3D:
	var home: Transform3D = _leaf_home[index]
	var spread: float = 1.0 + 0.18 * float(index)
	var turned: Basis = Basis(Vector3.UP, deg_to_rad(14.0 * float(index + 1))) * home.basis
	return Transform3D(turned, home.origin + leaf_aside_offset * spread)


func _set_camcorder_enabled() -> void:
	if camcorder != null:
		camcorder.viewfinder_enabled = _stage != Stage.RUNNING and _aux_mode == AuxMode.NONE


## Turns the physical camcorder so that its LENS is where the recording's first shot's camera is and its axis is that shot's: the head is turned to the shot's direction (yaw and pitch), then the
## whole device is moved so that the front of the lens glass (`LensMarker`) lies exactly on the shot's position. The recording's camera is never moved to match the device.
func _align_camcorder() -> void:
	if camcorder == null or shot_recording == null or not is_inside_tree():
		return

	var head: Node3D = camcorder.get_head()
	var lens: Marker3D = camcorder.get_lens_marker()
	if head == null or lens == null:
		return

	var view: Transform3D = shot_recording.aimed_transform()
	var scale_of_head: Vector3 = head.scale
	head.global_transform = Transform3D(view.basis.orthonormalized().scaled(scale_of_head), head.global_position)
	camcorder.global_position += view.origin - lens.global_position


## The camcorder's lens, axis, eyecup and the place the body stands to use it, in the shed's space (for the tests and the tools).
func get_camcorder_view() -> Dictionary:
	var head: Node3D = camcorder.get_head() if camcorder != null else null
	var lens: Marker3D = camcorder.get_lens_marker() if camcorder != null else null
	var eye: Marker3D = camcorder.get_eye_marker() if camcorder != null else null
	var stand: Marker3D = camcorder.get_stand_marker() if camcorder != null else null
	if head == null or lens == null or eye == null:
		return {}
	return {"lens": to_local(lens.global_position), "axis": (global_transform.basis.inverse() * (-head.global_basis.z)).normalized(), "eye": to_local(eye.global_position), "stand": to_local(stand.global_position) if stand != null else Vector3.ZERO}


# ---- The camcorder's own sound after the first cinematic ----

## A moment after the control comes back (`camcorder_cue_delay_seconds`), a small mechanical sound comes from the physical camcorder, behind her: the machine's first part, from its motor to the click of its
## button (the project's placeholder, `TapePlayerSounds`), from a 3D player on the device's head. No dialogue, no forced look; it can be missed, and the device stays there to find. Pause stops it with the rest.
func _start_camcorder_cue() -> void:
	_cue_run += 1
	_camcorder_cue(_cue_run)


func _camcorder_cue(run: int) -> void:
	await _wait(camcorder_cue_delay_seconds)
	if run != _cue_run or not is_inside_tree() or camcorder == null or _aux_mode != AuxMode.NONE or _stage == Stage.RUNNING:
		return

	var head: Node3D = camcorder.get_head()
	if head == null:
		return

	if _cue_player == null or not is_instance_valid(_cue_player):
		_cue_player = AudioStreamPlayer3D.new()
		_cue_player.name = "CueSound"
		_cue_player.unit_size = 9.0
		_cue_player.max_distance = camcorder_cue_distance
		head.add_child(_cue_player)
	_cue_player.stream = TapePlayerSounds.start_stream()
	_cue_player.volume_db = camcorder_cue_volume_db
	_cue_player.play(1.2)
	await _wait(1.3)
	if run == _cue_run and _cue_player != null and is_instance_valid(_cue_player):
		_cue_player.stop()


func _stop_cue() -> void:
	_cue_run += 1
	if _cue_player != null and is_instance_valid(_cue_player):
		_cue_player.stop()


# ---- The viewfinder ----

## Using the camcorder: Juliana walks (if she is not already behind it) to the rear of the device, bends her eye to the eyecup, and a short black occlusion hides the cut to the lens: a fixed, static look through
## it from the recording's first viewpoint (the scene's own camera, its 4:3 picture and tape look). Before the first cinematic it shows the ordinary shelter; after it, the empty bloodstained shelter with the
## drag trail. It never plays the source and has no clock of its own: the dressing is only shown.
func _on_viewfinder_requested() -> void:
	if _stage == Stage.RUNNING or _aux_mode != AuxMode.NONE:
		return

	var target: Node3D = _get_player()
	if target == null or bool(target.get("view_locked")):
		return

	_stop_cue()
	_aux_mode = AuxMode.TRANSITION
	_vf_phase = &"entering"
	_aux_run += 1
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		_vf_saved_yaw = movement.look_yaw
		_vf_saved_pitch = movement.look_pitch
	# Recorded, not yet locked: the assisted walk needs a free body (a locked view freezes it). The lock comes when she stands at the eyepiece.
	_record_player(target)
	_set_camcorder_enabled()
	_enter_viewfinder(_aux_run)


## Where a ray at knee height between two points meets nothing solid (the player's own body ignored).
func _path_clear(from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + Vector3(0.0, 0.35, 0.0), to + Vector3(0.0, 0.35, 0.0))
	if _held is CollisionObject3D:
		query.exclude = [(_held as CollisionObject3D).get_rid()]
	return space.intersect_ray(query).is_empty()


## The project's guided walk to `target` looking at `look`; true when she is there. Never more than a few seconds, and it gives up (false) when something is in the way.
func _walk_to(target: Vector3, look: Vector3, run: int) -> bool:
	var movement: PlayerMovementController = _get_movement()
	if movement == null or _held == null:
		return false

	if Vector2(_held.global_position.x - target.x, _held.global_position.z - target.z).length() < 0.1:
		return true

	# The walk cannot begin in the air (a jump, a step down): she is given a moment to land before it is given up.
	var landing: float = 0.0
	while not movement.begin_guided_walk(target, look, PlayerMovementController.WALK_SPEED * 0.8, 3.0):
		await get_tree().process_frame
		landing += get_process_delta_time()
		if landing > 1.0 or not _aux_alive(run):
			return false

	while movement.is_guided_walking() and _aux_alive(run):
		await get_tree().process_frame
		# Something else took the view meanwhile (a reading, the inventory, the pause): she is given back at once.
		var inspect: PlayerInspectController = _get_inspect()
		if inspect != null and inspect.is_open():
			_abort_aux()
			return false
	if not _aux_alive(run):
		return false

	return Vector2(_held.global_position.x - target.x, _held.global_position.z - target.z).length() < 0.2


func _enter_viewfinder(run: int) -> void:
	var movement: PlayerMovementController = _get_movement()
	var head: Node3D = camcorder.get_head() if camcorder != null else null
	var eye_marker: Marker3D = camcorder.get_eye_marker() if camcorder != null else null
	if movement == null or head == null or eye_marker == null or _held == null or not is_instance_valid(_held):
		_abort_aux()
		return

	var eye_world: Vector3 = eye_marker.global_position
	var axis: Vector3 = (-head.global_basis.z).normalized()
	var back: Vector3 = Vector3(-axis.x, 0.0, -axis.z).normalized()
	var root_at: Vector3 = camcorder.global_position
	var from: Vector3 = _held.global_position
	var stand: Vector3 = Vector3(eye_world.x, from.y, eye_world.z) + back * viewfinder_stand_back_metres
	# Not through the tripod: from the front half (the lens side) or with something in the way she goes round by the side first.
	var ahead: float = Vector2(from.x - root_at.x, from.z - root_at.z).dot(Vector2(axis.x, axis.z))
	var route: Array[Vector3] = []
	if ahead > 0.15 or not _path_clear(from, stand):
		var side: Vector3 = Vector3(-back.z, 0.0, back.x)
		if Vector3(from.x - root_at.x, 0.0, from.z - root_at.z).dot(side) < 0.0:
			side = -side
		route.append(Vector3(root_at.x, from.y, root_at.z) + side * 1.05 + back * 0.25)
	route.append(stand)
	var look_at_device: Vector3 = head.global_position
	for waypoint: Vector3 in route:
		var reached: bool = await _walk_to(waypoint, look_at_device, run)
		if not _aux_alive(run):
			return
		if not reached:
			break
	if Vector2(_held.global_position.x - stand.x, _held.global_position.z - stand.z).length() > 0.45:
		# Something is in the way: nothing is teleported; she is simply given back.
		_abort_aux()
		return

	# She stands at the eyepiece: from here the view is held. The lean: the eye goes to the eyecup and the gaze onto the lens's axis, smoothly (no tremor), and the eyecup's black closes over the last part.
	_lock_player()
	movement.gesture_direct = true
	var local_axis: Vector3 = _held.global_transform.basis.inverse() * axis
	var yaw_from: float = -deg_to_rad(movement.look_yaw)
	var pitch_from: float = movement.look_pitch
	var yaw_to: float = atan2(-local_axis.x, -local_axis.z)
	var pitch_to: float = clampf(-rad_to_deg(asin(clampf(local_axis.y, -1.0, 1.0))), -35.0, 75.0)
	var head_node: Node3D = movement.get("head") as Node3D
	var duration: float = maxf(viewfinder_enter_seconds, 0.3)
	var occlusion: float = minf(viewfinder_occlusion_seconds, duration * 0.4)
	var elapsed: float = 0.0
	while elapsed < duration:
		await get_tree().process_frame
		if not _aux_alive(run):
			return
		if get_tree().paused:
			continue
		elapsed += get_process_delta_time()
		var u: float = smoothstep(0.0, 1.0, clampf(elapsed / duration, 0.0, 1.0))
		movement.look_yaw = -rad_to_deg(lerp_angle(yaw_from, yaw_to, u))
		movement.look_pitch = lerpf(pitch_from, pitch_to, u)
		_vf_full_offset = head_node.to_local(eye_world) - movement.original_camera_position
		movement.gesture_offset = _vf_full_offset * u
		_set_occlusion(smoothstep(duration - occlusion, duration, elapsed))

	# Under the black: the cut from her eye to the lens.
	_set_occlusion(1.0)
	_show_viewfinder_picture()
	_show_viewfinder_prompt(true)
	var fade: float = 0.0
	while fade < occlusion:
		await get_tree().process_frame
		if not _aux_alive(run):
			return
		if get_tree().paused:
			continue
		fade += get_process_delta_time()
		_set_occlusion(1.0 - smoothstep(0.0, occlusion, fade))
	_set_occlusion(0.0)
	_aux_mode = AuxMode.VIEWFINDER
	_vf_phase = &"settled"
	_vf_ready_ms = Time.get_ticks_msec() + int(viewfinder_input_guard_seconds * 1000.0)
	# After the first cinematic, with the leaves still over the reply: a short time to read the picture, then the cover slides.
	if _flag(KEY_RECORDING_DONE) and not _flag(KEY_LEAF_REVEALED):
		await _wait(viewfinder_read_seconds)
		if _aux_alive(run) and _aux_mode == AuxMode.VIEWFINDER and not _flag(KEY_LEAF_REVEALED):
			_begin_leaf_reveal()


## The lens's own picture: the scene's camera at shot A with the 4:3 overlay; the ordinary shelter before the first cinematic, the bloodstained one after.
func _show_viewfinder_picture() -> void:
	var after_video: bool = _flag(KEY_RECORDING_DONE)
	if footage != null:
		footage.prepare()
	_show_camera(shot_recording, true)
	if after_video:
		set_world_state(WorldState.VIEWFINDER)
		_recording_environment().ambient_light_energy = archive_ambient_energy * viewfinder_ambient_boost
		_set_shot_light(true, viewfinder_light_energy)
		if _shot_light != null and is_instance_valid(_shot_light):
			_shot_light.spot_range = aftermath_light_range
	else:
		set_world_state(WorldState.PRESENT)
		# Looking through the lens: the device itself is not in the picture.
		if camcorder != null:
			camcorder.visible = false
		_set_shot_light(false)
	_show_overlay(true)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set_burst(0.0)
		_overlay.set_paused(false)
		_overlay.set_label_text(viewfinder_label)


## A fresh movement input (any of the four movement actions, pressed anew: not a key that was already held when the view began, and not the press that began it) steps back. Esc is the pause menu's.
func _viewfinder_input(event: InputEvent) -> bool:
	if _aux_mode != AuxMode.VIEWFINDER or _vf_phase != &"settled" or event.is_echo():
		return false

	if Time.get_ticks_msec() < _vf_ready_ms:
		return false

	for action: StringName in [&"up", &"down", &"left", &"right"]:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_exit_viewfinder()
			return true
	return false


## Steps back from the viewfinder: a short black, the ordinary world restored UNDER it (before anything of the present is seen), then the eye comes back from the eyecup, and only then the control.
func _exit_viewfinder() -> void:
	if _aux_mode != AuxMode.VIEWFINDER or _vf_phase != &"settled":
		return

	_aux_mode = AuxMode.TRANSITION
	_vf_phase = &"exiting"
	_aux_run += 1
	_leave_viewfinder(_aux_run)


func _leave_viewfinder(run: int) -> void:
	_show_viewfinder_prompt(false)
	var close_in: float = 0.0
	while close_in < 0.12:
		await get_tree().process_frame
		if not _aux_alive(run):
			return
		if get_tree().paused:
			continue
		close_in += get_process_delta_time()
		_set_occlusion(smoothstep(0.0, 0.12, close_in))
	_set_occlusion(1.0)
	set_world_state(WorldState.PRESENT)
	_show_overlay(false)
	_set_shot_light(false)
	if _archive_environment != null:
		_archive_environment.ambient_light_energy = archive_ambient_energy
	var camera: Camera3D = _get_camera()
	if camera != null:
		camera.make_current()
	_free_cinema_camera()
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		var duration: float = maxf(viewfinder_exit_seconds, 0.2)
		var yaw_from: float = -deg_to_rad(movement.look_yaw)
		var yaw_to: float = -deg_to_rad(_vf_saved_yaw)
		var pitch_from: float = movement.look_pitch
		var elapsed: float = 0.0
		while elapsed < duration:
			await get_tree().process_frame
			if not _aux_alive(run):
				return
			if get_tree().paused:
				continue
			elapsed += get_process_delta_time()
			var u: float = smoothstep(0.0, 1.0, clampf(elapsed / duration, 0.0, 1.0))
			movement.gesture_offset = _vf_full_offset * (1.0 - u)
			movement.look_yaw = -rad_to_deg(lerp_angle(yaw_from, yaw_to, u))
			movement.look_pitch = lerpf(pitch_from, _vf_saved_pitch, u)
			_set_occlusion(1.0 - smoothstep(0.0, duration * 0.6, elapsed))
	_finish_aux()


## Everything given back after a mode that held the player (the viewfinder, the review): the black away, the world as the present, the control.
func _finish_aux() -> void:
	_set_occlusion(0.0)
	_aux_run += 1
	_aux_mode = AuxMode.NONE
	_vf_phase = &""
	_release_player()
	_apply_investigation_state()


func _set_occlusion(alpha: float) -> void:
	if alpha <= 0.001:
		if _occlusion_layer != null and is_instance_valid(_occlusion_layer):
			_occlusion_layer.visible = false
		return

	if _occlusion_layer == null or not is_instance_valid(_occlusion_layer):
		_occlusion_layer = CanvasLayer.new()
		_occlusion_layer.name = "EyecupOcclusion"
		# Over the viewfinder's picture and its hint, under the subtitles and the menus.
		_occlusion_layer.layer = 14
		add_child(_occlusion_layer)
		_occlusion_rect = ColorRect.new()
		_occlusion_rect.color = Color(0.0, 0.0, 0.0, 1.0)
		_occlusion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_occlusion_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_occlusion_layer.add_child(_occlusion_rect)
	_occlusion_layer.visible = true
	_occlusion_rect.color.a = clampf(alpha, 0.0, 1.0)


## The first reading of the clipping: the view is hers no longer from the moment its reading is closed. The paper is set down over the tape where it lay (the inspect view flies it back to its source), then a still
## shot from over the bench shows a hand move it aside, the way anyone would clear a paper off what lies under it (lifted a little, slid, turned a little, set down), and the tape is held in view before the view is
## hers again. The stage is written at the end (or at once if the scene is cut short), and `_apply_investigation_state` then puts the paper where it lies.
func _begin_clipping_reveal() -> void:
	var target: Node3D = _get_player()
	if target == null or clipping == null or clipping_aside == null:
		_set_flag(KEY_CLIPPING_READ)
		_apply_investigation_state()
		return

	_aux_mode = AuxMode.TRANSITION
	_vf_phase = &"clipping"
	_aux_run += 1
	_clipping_busy = true
	_hold_player(target)
	_set_camcorder_enabled()
	_clipping_reveal(_aux_run)


func _clipping_reveal(run: int) -> void:
	# The reading's view flies the paper back before anything else happens.
	var inspect: PlayerInspectController = _get_inspect()
	var waited: float = 0.0
	while inspect != null and inspect.is_open() and waited < 6.0:
		await get_tree().process_frame
		if not _aux_alive(run):
			return
		waited += get_process_delta_time()
	await _wait(0.15)
	if not _aux_alive(run):
		return

	_dissolve(0.4)
	var camera: Camera3D = _cinema_camera()
	var look_from: Vector3 = to_global(clipping_shot_position)
	camera.global_transform = Transform3D(Basis.IDENTITY, look_from).looking_at(to_global(clipping_shot_target), Vector3.UP)
	camera.fov = clipping_shot_fov
	var eyes: Camera3D = _get_camera()
	camera.environment = eyes.environment if eyes != null else null
	camera.make_current()
	_set_shot_light(true, photo_light_energy + 1.1)
	await _wait(0.9)
	if not _aux_alive(run):
		return

	var from: Transform3D = _clipping_home
	var to: Transform3D = clipping_aside.transform
	var lift: float = 0.022
	if _clipping_tween != null and _clipping_tween.is_valid():
		_clipping_tween.kill()
	_clipping_tween = create_tween()
	_clipping_tween.tween_method(func(u: float) -> void:
		if clipping == null or not is_instance_valid(clipping):
			return
		# Slow to start (the paper is taken up), a steady slide, then set down: eased both ends, lifted over the middle.
		var eased: float = smoothstep(0.0, 1.0, u)
		var placed: Transform3D = from.interpolate_with(to, eased)
		placed.origin.y += sin(PI * clampf(u * 1.15, 0.0, 1.0)) * lift
		clipping.transform = placed, 0.0, 1.0, maxf(clipping_slide_seconds, 0.2))
	await _clipping_tween.finished
	if not _aux_alive(run):
		return

	clipping.transform = to
	await _wait(clipping_hold_seconds)
	if not _aux_alive(run):
		return

	_clipping_busy = false
	_set_flag(KEY_CLIPPING_READ)
	_dissolve(0.4)
	_set_shot_light(false)
	_back_to_her_eyes()
	_finish_aux()


## The leaves slide aside: a visible, physical move of the cover over the end of the trail (a short gust, no test, no hotspot). It is written at its START and finishes by itself whatever the player does
## (they may step back from the viewfinder during it); the reply is exposed (and offers its reading) when it is over.
func _begin_leaf_reveal() -> void:
	if _flag(KEY_LEAF_REVEALED):
		return

	_set_flag(KEY_LEAF_REVEALED)
	_leaf_busy = true
	if letter != null:
		letter.visible = true
		letter.set_interaction_enabled(false)
	if _leaf_tween != null and _leaf_tween.is_valid():
		_leaf_tween.kill()
	_leaf_tween = create_tween().set_parallel(true)
	for i: int in _leaf_sheets.size():
		var target: Transform3D = _leaf_displaced(i)
		_leaf_tween.tween_property(_leaf_sheets[i], "transform", target, maxf(leaf_slide_seconds, 0.05)).set_delay(0.12 * float(i)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_leaf_tween.chain().tween_callback(_on_leaves_moved)


func _on_leaves_moved() -> void:
	_leaf_busy = false
	_apply_investigation_state()


## The viewfinder's exit hint, with the keys really bound to the four movement actions (`[W/A/S/D] Step back` by default): a fresh movement input is what steps back.
func _show_viewfinder_prompt(on: bool) -> void:
	if on:
		if _prompt_layer == null:
			_prompt_layer = CanvasLayer.new()
			_prompt_layer.name = "ViewfinderPrompt"
			_prompt_layer.layer = 12
			add_child(_prompt_layer)
			_prompt_label = Label.new()
			_prompt_label.name = "Exit"
			_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			_prompt_label.offset_top = -86.0
			_prompt_label.offset_bottom = -34.0
			_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_prompt_label.add_theme_font_size_override(&"font_size", 26)
			_prompt_label.add_theme_color_override(&"font_color", Color(0.9, 0.92, 0.86, 0.9))
			_prompt_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
			_prompt_label.add_theme_constant_override(&"outline_size", 6)
			_prompt_layer.add_child(_prompt_label)
		_prompt_label.text = InputBindings.format_text("[{up}/{left}/{down}/{right}] " + tr("PROMPT_VIEWFINDER_EXIT"))
	if _prompt_layer != null:
		_prompt_layer.visible = on


# ---- The voluntary tape review ----

## The tape, after the first cinematic: a dedicated mode with a transport row. The picture is the SAME deterministic rendering of the footage at a time the player chooses (the excerpt's clock runs from
## `-rear_prefix_seconds`, the rear segment, to the excerpt's end): the camera, the cast and the dressing are pure functions of it, so reversing, pausing and searching are exact. No remembered dialogue, no captions.
## The first visit is cued on the first frame of the Emily excerpt (the tape's counter says so: it is not at zero); later visits resume where it was left. Nothing physical happens because of a frame.
func _on_review_requested() -> void:
	if _stage == Stage.RUNNING or _aux_mode != AuxMode.NONE or not _is_done():
		return

	var target: Node3D = _get_player()
	if target == null or bool(target.get("view_locked")) or footage == null:
		return

	_stop_cue()
	_aux_mode = AuxMode.REVIEW
	_aux_run += 1
	_hold_player(target)
	_set_camcorder_enabled()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dissolve(0.2)
	footage.prepare()
	_show_camera(shot_recording, true)
	_set_recording_world(true)
	_set_shot_light(false)
	_footage_playing = false
	_freeze_wind(true)
	var saved: Variant = SaveManager.get_state_value(STATE_SECTION, KEY_REVIEW_PLAYHEAD, null)
	_review_time = clampf(float(saved), -footage.rear_prefix_seconds, footage.length_seconds) if saved != null else review_start_excerpt_seconds
	_review_state = &"pause"
	_review_machine_on = false
	_review_held_actions.clear()
	_show_overlay(true)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.set_burst(0.0)
	if _review_ui == null or not is_instance_valid(_review_ui):
		_review_ui = VhsReviewUi.new()
		add_child(_review_ui)
		_review_ui.play_pause_requested.connect(_review_toggle_play)
		_review_ui.stop_requested.connect(_review_stop)
		_review_ui.search_started.connect(_review_search_start)
		_review_ui.search_ended.connect(_review_search_end)
		_review_ui.close_requested.connect(_exit_review)
	_review_ui.refresh_text()
	_review_ui.visible = true
	_review_ready_ms = Time.get_ticks_msec() + int(viewfinder_input_guard_seconds * 1000.0)
	_review_apply()


## The tape's time as a machine's counter: minutes and seconds from the start of the whole tape.
func review_counter_text(excerpt_time: float) -> String:
	var tape: int = int(floorf(maxf(footage.tape_time_of(excerpt_time), 0.0)))
	var total: int = int(floorf(footage.tape_length()))
	return "%02d:%02d / %02d:%02d" % [tape / 60, tape % 60, total / 60, total % 60]


## Shows the tape at the playhead: the picture (an exact function of the time), the word and the counter, the buttons. A tape that was never seen before this point notes that the rear segment exists.
func _review_apply() -> void:
	_apply_footage(_review_time)
	if _overlay != null and is_instance_valid(_overlay):
		var word: String = {&"play": "PLAY", &"pause": "PAUSE", &"stop": "STOP", &"rew": "REW", &"ff": "FF"}.get(_review_state, "PAUSE")
		_overlay.set_label_text(word)
		_overlay.set_counter_text(review_counter_text(_review_time))
		_overlay.set_no_picture(_review_state == &"stop")
	if _review_ui != null and is_instance_valid(_review_ui):
		_review_ui.set_state(_review_state)
	if _review_time < 0.0 and not _flag(KEY_REAR_SEEN):
		_set_flag(KEY_REAR_SEEN)


## Space, and the button on screen: play from a pause or a stop, pause from playing. While a search is held it does nothing.
func _review_toggle_play() -> void:
	if _aux_mode != AuxMode.REVIEW:
		return

	if _review_state == &"rew" or _review_state == &"ff":
		return

	if _review_state == &"play":
		_review_set_state(&"pause")
	else:
		if _review_time >= footage.length_seconds - 0.01:
			return
		_review_set_state(&"play")


func _review_stop() -> void:
	if _aux_mode == AuxMode.REVIEW:
		_review_set_state(&"stop")


func _review_search_start(direction: int) -> void:
	if _aux_mode == AuxMode.REVIEW:
		_review_set_state(&"rew" if direction < 0 else &"ff")


## Releasing a search holds a readable frame (a pause), as a machine does.
func _review_search_end() -> void:
	if _aux_mode == AuxMode.REVIEW and (_review_state == &"rew" or _review_state == &"ff"):
		_review_set_state(&"pause")


func _review_set_state(state: StringName) -> void:
	_review_state = state
	_review_sound()
	_review_apply()
	_freeze_wind(state == &"pause" or state == &"stop")


## Restrained mechanical sounds, separate from the tape: the machine running while it plays or searches, and its last part when it stops. The recorded picture itself stays silent.
func _review_sound() -> void:
	var running: bool = _review_state == &"play" or _review_state == &"rew" or _review_state == &"ff"
	if running and not _review_machine_on:
		_start_machine(false)
	elif not running and _review_machine_on:
		_stop_machine()
	_review_machine_on = running
	if _review_state == &"play":
		if _tape_player != null and not _tape_player.playing:
			_start_tape_sound()
	else:
		_stop_tape_sound()


## Time passing in review: 1x while it plays, `review_search_speed` times that while a search is held. It stops at the tape's two ends.
func _review_process(delta: float) -> void:
	if _review_state == &"pause" or _review_state == &"stop" or footage == null:
		return

	var step: float = delta * (1.0 if _review_state == &"play" else review_search_speed)
	if _review_state == &"rew":
		_review_time -= step
		if _review_time <= -footage.rear_prefix_seconds:
			_review_time = -footage.rear_prefix_seconds
			_review_set_state(&"pause")
			return
	else:
		_review_time += step
		if _review_time >= footage.length_seconds:
			_review_time = footage.length_seconds
			_review_set_state(&"pause")
			return
	_review_apply()


## Keys of the review: Space (play/pause), the left and right movement actions held (rewind, fast-forward), the down action (stop), the interact action (close). Nothing else of the game sees them.
func _review_input(event: InputEvent) -> bool:
	if _aux_mode != AuxMode.REVIEW:
		return false

	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_review_toggle_play()
		return true

	for action: StringName in [&"left", &"right"]:
		if event.is_action_pressed(action) and not event.is_echo():
			get_viewport().set_input_as_handled()
			_review_held_actions[action] = true
			_review_search_start(-1 if action == &"left" else 1)
			return true
		if event.is_action_released(action):
			get_viewport().set_input_as_handled()
			_review_held_actions.erase(action)
			if _review_held_actions.is_empty():
				_review_search_end()
			else:
				_review_search_start(-1 if _review_held_actions.has(&"left") else 1)
			return true

	if event.is_action_pressed(&"down") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_review_stop()
		return true

	if event.is_action_pressed(&"interact") and not event.is_echo() and Time.get_ticks_msec() >= _review_ready_ms:
		get_viewport().set_input_as_handled()
		_exit_review()
		return true

	# The review owns the keys it uses and the rest of the movement keys do nothing (the player is held anyway).
	return false


## Leaves the review: the playhead is saved, the sounds stop, the ordinary world is restored first, then the control comes back.
func _exit_review() -> void:
	if _aux_mode != AuxMode.REVIEW:
		return

	SaveManager.set_state_value(STATE_SECTION, KEY_REVIEW_PLAYHEAD, _review_time)
	if vhs != null:
		vhs.ignore_use_until_msec = Time.get_ticks_msec() + 450
	_review_cleanup()
	_finish_aux()


func _review_cleanup() -> void:
	_review_state = &"pause"
	_review_held_actions.clear()
	if _review_machine_on and _machine_player != null:
		_machine_player.stop()
	_review_machine_on = false
	_stop_tape_sound()
	_footage_playing = false
	_freeze_wind(false, true)
	if _review_ui != null and is_instance_valid(_review_ui):
		_review_ui.visible = false
	if footage != null:
		footage.show_cast(false)
		footage.seek(0.0)
	set_world_state(WorldState.PRESENT)
	_show_overlay(false)
	_set_shot_light(false)
	var camera: Camera3D = _get_camera()
	if camera != null and is_inside_tree():
		camera.make_current()
	_free_cinema_camera()
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and _mouse_before != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = _mouse_before


# ---- Holding the player outside the first cinematic ----

func _aux_alive(run: int) -> bool:
	return _aux_mode != AuxMode.NONE and run == _aux_run and is_inside_tree()


## Whatever holds the player outside the first cinematic is put away at once, from ANY phase (the walk, the lean, the picture, the withdrawal, the review; the scene is left, a save is loaded, a developer
## command): the world is the ordinary one, the control is given back, and the stages already written decide what lies where.
func _abort_aux() -> void:
	_stop_cue()
	if _aux_mode == AuxMode.NONE:
		return

	var was_review: bool = _aux_mode == AuxMode.REVIEW
	_aux_run += 1
	if _clipping_busy:
		_clipping_busy = false
		_set_flag(KEY_CLIPPING_READ)
		if _clipping_tween != null and _clipping_tween.is_valid():
			_clipping_tween.kill()
	_aux_mode = AuxMode.NONE
	_vf_phase = &""
	_show_viewfinder_prompt(false)
	var movement: PlayerMovementController = _get_movement()
	if movement != null:
		movement.cancel_guided_walk()
	_clear_freeze()
	if was_review:
		SaveManager.set_state_value(STATE_SECTION, KEY_REVIEW_PLAYHEAD, _review_time)
		_review_cleanup()
	else:
		_set_recording_world(false)
		_show_overlay(false)
		_set_shot_light(false)
		if is_inside_tree():
			var camera: Camera3D = _get_camera()
			if camera != null:
				camera.make_current()
		_free_cinema_camera()
	_set_occlusion(0.0)
	if _held != null:
		_release_player()
	_apply_investigation_state()


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


# ---- The wind in a held picture ----

## The vegetation's wind is a shader that runs on the clock, not on the tape's: a paused or stopped tape would show the plants still swaying. While the picture is held the wind's strength eases to
## nothing (the plants stand straight, as in still air) and comes back as it plays again. `immediate` puts it back at once (leaving, cancelling).
func _freeze_wind(frozen: bool, immediate: bool = false) -> void:
	if _wind_node() == null:
		return

	if _wind_tween != null and _wind_tween.is_valid():
		_wind_tween.kill()
	if frozen and _wind_home < 0.0:
		_wind_home = float(_wind.get("strength"))
	if _wind_home < 0.0:
		return

	var target: float = 0.0 if frozen else _wind_home
	if immediate or not is_inside_tree():
		_wind.set("strength", target)
	else:
		_wind_tween = create_tween()
		_wind_tween.tween_property(_wind, "strength", target, 0.35)
	if not frozen:
		_wind_home = -1.0


## The vegetation's wind controller of the level, if it has one (the dream intro does; the playtest scene does not).
func _wind_node() -> Node:
	if _wind == null or not is_instance_valid(_wind):
		var found: Array[Node] = get_tree().root.find_children("*", "VegetationWind", true, false) if is_inside_tree() else []
		_wind = found[0] if not found.is_empty() else null
	return _wind


## Keeps the forest's plants out of the lens of the tape's camera (`VegetationWind.set_camera_clearing`): none shrinks unless the camera of the recording is on screen and walks past it. `on` false puts them all back.
func _clear_vegetation_round(on: bool, camera_position: Vector3 = Vector3.ZERO) -> void:
	var wind: Node = _wind_node()
	if wind != null and wind.has_method("set_camera_clearing"):
		wind.call("set_camera_clearing", camera_position, vegetation_clear_inner if on else 0.0, vegetation_clear_outer)


## In the recording the telephone token (polished brass, which looks black under the tape's flat light: a metal shows only what it reflects) is a bright, slightly glowing brass, so that it reads as a coin. Only on
## the recording's picture; the token itself, its material and its place are untouched in the present.
func _set_token_tape_look(on: bool) -> void:
	if ficha == null or not is_instance_valid(ficha):
		return

	if _token_tape_material == null:
		_token_tape_material = StandardMaterial3D.new()
		_token_tape_material.albedo_color = Color(0.9, 0.72, 0.3)
		_token_tape_material.metallic = 0.1
		_token_tape_material.roughness = 0.5
		_token_tape_material.emission_enabled = true
		_token_tape_material.emission = Color(0.55, 0.42, 0.14)
		_token_tape_material.emission_energy_multiplier = 0.9
	for node: Node in ficha.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _token_tape_material if on else null
