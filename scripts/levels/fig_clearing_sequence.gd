extends Node3D
class_name FigClearingSequence

## Orchestrates the fig tree clearing (script sequences 8 to 10): the album
## puzzle and the recorded memory.
##
## The reusable pieces (recorder, album) only raise signals; every
## decision about what the clearing does lives here. Voice lines are captions
## until recorded audio exists, and the sounds are generated placeholders.
##
## Six photographs lie about the clearing and only three belong in the album (the others are
## red herrings). The album is judged when every space is full: right, the finale starts; wrong,
## a short burst of static says the memory does not line up.
##
## The scene ends the moment the recording does: rain, campfire and flashlight cut out together,
## into total darkness. After `ficha_delay_seconds` of it a metallic CLINK sounds on the table,
## the flashlight comes back, and by its light the fire pit holds cold ash and Juliana's Ficha
## (a telephone token scratched with "CALL HER") lies beside the album: the only thing the player
## takes from the clearing. The photographs are never taken (they are only put in the album; the
## strays go when it is solved). Nothing else happens.
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

const LINE_WHY_THIS_PLACE: String = "CAPTION_JULIANA_WHY_THIS_PLACE"

@export_category("Puzzle")
@export var album: PhotoAlbum
@export var recorder: CassetteRecorder
## The campfire; it goes out when the recording ends.
@export var fire: CampfireFire

@export_category("Ficha")
## Juliana's Ficha (a Collectible scene) and where it lies once the recording is over.
@export var ficha_scene: PackedScene
@export var ficha_spot: Marker3D
## How long the dark lasts after the recording ends, before the clink and the Ficha.
@export var ficha_delay_seconds: float = 2.0
## How long after the clink the flashlight comes back on.
@export var flashlight_return_seconds: float = 0.45

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
var _ficha: Node3D = null


func _ready() -> void:
	_why_said = _read_flag(KEY_WHY_SAID)
	_recording_done = _read_flag(KEY_RECORDING_DONE)

	_connect_signals()
	_restore_stage()


func _connect_signals() -> void:
	album.opened.connect(_on_album_opened)
	album.completed.connect(_on_album_completed)
	album.wrong_arrangement.connect(_on_album_wrong)


## Resumes from saved progress. A recording already heard is never replayed.
func _restore_stage() -> void:
	# Whatever the state, a solved album has taken the strays (they must not clog the inventory).
	if _recording_done or album.locked:
		_remove_stray_photos.call_deferred()

	if _recording_done:
		fire.extinguish()
		_place_ficha()
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


## Every space is full and it is not right: a subtle burst of static, nothing else.
func _on_album_wrong() -> void:
	var glitch: AudioStreamPlayer = AudioStreamPlayer.new()
	glitch.stream = PlaceholderAudio.make_static_glitch()
	glitch.volume_db = -13.0
	add_child(glitch)
	glitch.finished.connect(glitch.queue_free)
	glitch.play()


# ============================================================
# FINALE AND RECORDING
# ============================================================

func _run_finale() -> void:
	if stage >= Stage.FINALE:
		return

	stage = Stage.FINALE
	_set_saving_blocked(true)
	album.interaction_enabled = false
	# Deferred: the album's close-up gives a displaced photograph back to the hands only after it has
	# raised `completed`.
	_remove_stray_photos.call_deferred()

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


## The scene is over: saving is allowed again. In the dark, then a clink, the flashlight and the Ficha.
func _end_scene() -> void:
	_recording_done = true
	_write_flag(KEY_RECORDING_DONE)
	_set_saving_blocked(false)
	album.interaction_enabled = true
	stage = Stage.DONE
	sequence_completed.emit()

	await _wait(ficha_delay_seconds)
	_place_ficha(true)
	await _wait(flashlight_return_seconds)
	_turn_flashlight_on()


## Puts Juliana's Ficha on the table beside the album, flat, unless she has taken it
## (the Collectible removes itself then). `with_sound` adds the small clink of it being
## set down.
func _place_ficha(with_sound: bool = false) -> void:
	if ficha_scene == null or ficha_spot == null or _ficha != null:
		return

	_ficha = ficha_scene.instantiate() as Node3D
	ficha_spot.get_parent().add_child(_ficha)
	_ficha.global_transform = ficha_spot.global_transform
	_ficha.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90.0))

	if with_sound and is_instance_valid(_ficha):
		var clink: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		clink.stream = PlaceholderAudio.make_metal_clink()
		clink.volume_db = -4.0
		clink.unit_size = 4.0
		ficha_spot.add_child(clink)
		clink.finished.connect(clink.queue_free)
		clink.play()


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
## with no fade, as if the scene had changed: total darkness (the fire pit is left with cold ash).
## The flashlight comes back by itself after the clink.
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


## The flashlight comes back after the dark (with its usual start-up flicker).
func _turn_flashlight_on() -> void:
	var flashlight: Node = _get_flashlight()
	if flashlight != null and flashlight.has_method("turn_on"):
		flashlight.call("turn_on")


## The photographs that are not in the solved album are gone from the player's hands and from the
## clearing: the album took them (they would otherwise fill three of the six inventory slots for
## the rest of the game).
func _remove_stray_photos() -> void:
	var stray: Array[String] = album.get_unplaced_photo_ids()
	var target: Node = _get_player()
	if target != null and target.has_method("consume_inventory_item"):
		for item_id: String in stray:
			while target.has_method("has_inventory_item") and bool(target.call("has_inventory_item", item_id)):
				if not bool(target.call("consume_inventory_item", item_id)):
					break

	for node: Node in find_children("*", "Collectible", true, false):
		var photo: Collectible = node as Collectible
		if photo != null and stray.has(photo.item_id):
			photo.queue_free()
