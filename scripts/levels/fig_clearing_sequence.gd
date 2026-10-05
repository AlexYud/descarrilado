extends Node3D
class_name FigClearingSequence

## Orchestrates the fig tree clearing (script sequences 8 to 10): the album
## puzzle and the recorded memory.
##
## The reusable pieces (recorder, album) only raise signals; every
## decision about what the clearing does lives here. Voice lines are captions
## until recorded audio exists, and the sounds are generated placeholders.
##
## The scene ends the moment the recording does: rain, campfire and flashlight
## cut out together and the album offers the last photograph
## as a keepsake. Nothing else happens.
##
## Stages: EXPLORING (the cassette turns in silence, photos to find) > FINALE
## (album solved, tape rewinds) > RECORDING (the memory plays) > DONE. Nothing
## ever blocks the player: they may walk away at any time and the scene still
## plays out.

signal sequence_completed

enum Stage {
	EXPLORING,
	FINALE,
	RECORDING,
	DONE,
}

const STATE_SECTION: StringName = &"puzzles"
const KEY_WHY_SAID: StringName = &"fig_clearing_why_said"
const KEY_RECORDING_DONE: StringName = &"fig_clearing_recording_done"
const KEY_PHOTO_TAKEN: StringName = &"fig_clearing_photo_taken"

const LINE_WHY_THIS_PLACE: String = "CAPTION_JULIANA_WHY_THIS_PLACE"
const LINE_TAKE_PHOTO: String = "CAPTION_JULIANA_TAKE_PHOTO"

@export_category("Puzzle")
@export var album: PhotoAlbum
@export var recorder: CassetteRecorder
## The campfire; it goes out when the recording ends.
@export var fire: CampfireFire

@export_category("Recording")
@export var rain_player: AudioStreamPlayer

@export_category("Timing")
@export var finale_pause_seconds: float = 0.8
@export var silent_stop_seconds: float = 1.8
@export var rewind_seconds: float = 2.2

## Set when the player is not the node found by group "player".
@export var player: Node3D

var stage: Stage = Stage.EXPLORING

var _why_said: bool = false
var _recording_done: bool = false
var _photo_taken: bool = false


func _ready() -> void:
	_why_said = _read_flag(KEY_WHY_SAID)
	_recording_done = _read_flag(KEY_RECORDING_DONE)
	_photo_taken = _read_flag(KEY_PHOTO_TAKEN)

	_connect_signals()
	_restore_stage()


func _connect_signals() -> void:
	album.opened.connect(_on_album_opened)
	album.completed.connect(_on_album_completed)
	album.keepsake_taken.connect(_on_keepsake_taken)


## Resumes from saved progress. A recording already heard is never replayed.
func _restore_stage() -> void:
	if _recording_done:
		fire.extinguish()
		album.keepsake_enabled = not _photo_taken
		stage = Stage.DONE
		return

	recorder.start_turning()

	# Loaded with the album solved but the memory unheard.
	if album.locked:
		_run_finale.call_deferred()


# ============================================================
# TRIGGERS AND ALBUM
# ============================================================

## Opening the album for the first time gives Juliana's first line.
func _on_album_opened() -> void:
	if stage != Stage.EXPLORING or _why_said:
		return

	_why_said = true
	_write_flag(KEY_WHY_SAID)
	CaptionManager.say(LINE_WHY_THIS_PLACE)


func _on_album_completed() -> void:
	_run_finale()


## Juliana takes the last photograph, the one that asks "will you come?".
func _on_keepsake_taken() -> void:
	_photo_taken = true
	_write_flag(KEY_PHOTO_TAKEN)
	CaptionManager.say(LINE_TAKE_PHOTO)


# ============================================================
# FINALE AND RECORDING
# ============================================================

func _run_finale() -> void:
	if stage >= Stage.FINALE:
		return

	stage = Stage.FINALE
	_set_saving_blocked(true)
	album.interaction_enabled = false

	# The album closes itself shortly after the last photo falls into place.
	if album.view.is_open():
		await album.closed

	await _wait(finale_pause_seconds)
	recorder.stop_turning()
	await _wait(silent_stop_seconds)

	await recorder.rewind(rewind_seconds)
	await _play_recording()

	_end_scene()


func _play_recording() -> void:
	stage = Stage.RECORDING
	_play_rain(true)

	await CaptionManager.play_scripted_and_wait(CaptionTracks.FIG_RECORDING)

	# Everything cuts in the same instant: rain, fire, flashlight, then the tape.
	_play_rain(false)
	_put_out_lights()
	recorder.stop_turning()


## The scene is over: saving is allowed again and the album can give up its keepsake.
func _end_scene() -> void:
	_recording_done = true
	_write_flag(KEY_RECORDING_DONE)
	_set_saving_blocked(false)
	album.keepsake_enabled = true
	album.interaction_enabled = true
	stage = Stage.DONE
	sequence_completed.emit()



func _play_rain(enabled: bool) -> void:
	if rain_player == null:
		return

	if enabled:
		rain_player.stream = PlaceholderAudio.make_rain_loop()
		rain_player.volume_db = -16.0
		rain_player.play()
	else:
		rain_player.stop()


## The campfire and the flashlight (if it is on) cut out in the same instant,
## with no fade, as if the scene had changed. The player can switch the
## flashlight back on.
func _put_out_lights() -> void:
	fire.extinguish()

	var flashlight: Node = _get_flashlight()
	if flashlight != null and flashlight.has_method("turn_off"):
		flashlight.call("turn_off")


# ============================================================
# HELPERS
# ============================================================

func _get_flashlight() -> Node:
	var target: Node = _get_player()
	if target == null:
		return null

	return target.get("flashlight_controller") as Node


func _set_saving_blocked(blocked: bool) -> void:
	var target: Node = _get_player()
	if target != null and target.has_method("set_manual_save_blocked"):
		target.call("set_manual_save_blocked", blocked)


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
