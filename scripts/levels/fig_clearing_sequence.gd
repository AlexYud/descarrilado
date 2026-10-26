extends Node3D
class_name FigClearingSequence

## Orchestrates the fig tree clearing (script sequences 8 to 10): the album
## puzzle and the recorded memory.
##
## The reusable pieces (recorder, album, fire) only raise signals or do what they are told; every
## decision about what the clearing does lives here. Voice lines are captions
## until recorded audio exists, and the sounds are generated placeholders.
##
## Three photographs belong to the album, and nothing else stands in the way of it. Two are in the camp:
## Bus Stop Departure on the memory table beside the album, and Rain at the Station in the J & S lockbox on the log table,
## which stands open (`JSLockbox.starts_open`, `CampDressing`). The third, Scraped Knee, lies on the desk at the
## HQ in the ruined signal tower (`SignalTowerProps`), whose door opens like any door; Sophia's note on the thermos
## (`READABLE_THERMOS`) says it is there. So the camp and the HQ can be visited in either order.
##
## The album is judged when every space is full: right (Scraped Knee, Rain at the Station, Bus Stop
## Departure, in that order), the memory starts; wrong, a short burst of static says it does not line up, and the
## photographs stay where they are, to be moved.
##
## The memory: the tape stops, rewinds and plays the conversation (`CaptionTracks.FIG_RECORDING`, captions; an
## assigned clip on `recording_voice_player` plays from the recorder with them) with rain round it and the fire still
## burning. After Juliana's "Good." the reels stop and the rain with them. A moment of quiet, then Sophia's last line
## comes once more, plainly, from an empty log by the fire (`CaptionTracks.FIG_EMPTY_SEAT`; an assigned clip on
## `seat_voice_player` plays from `empty_seat`), not from the tape. Someone seems to get up from that log (a creak, a
## rustle), the fire is cold ash at once, and Juliana's Ficha (a telephone token scratched with "CALL HER") lies on the
## log where nobody sat (`ficha_spot`): the only thing the player takes from the clearing. The lantern, the radio and the
## flashlight are left as they are; the player is never held, turned or blinded, and may walk away at any time.
##
## Stages: EXPLORING (the cassette turns in silence, photos to find) > FINALE
## (album solved, tape rewinds) > RECORDING (the memory plays) > EMPTY_SEAT (the last line, the fire, the Ficha)
## > DONE. Saving is blocked from the album's solving until the Ficha lies on the log.

signal sequence_completed

enum Stage {
	EXPLORING,
	FINALE,
	RECORDING,
	EMPTY_SEAT,
	DONE,
}

const STATE_SECTION: StringName = &"puzzles"
const KEY_WHY_SAID: StringName = &"fig_clearing_why_said"
const KEY_RECORDING_DONE: StringName = &"fig_clearing_recording_done"

const LINE_WHY_THIS_PLACE: String = "CAPTION_JULIANA_WHY_THIS_PLACE"

@export_category("Puzzle")
@export var album: PhotoAlbum
@export var recorder: CassetteRecorder
## The campfire; it goes cold when the last line has been said.
@export var fire: CampfireFire

@export_category("Empty seat")
## The log by the fire the last line comes from (a node in the clearing, on one of `CampDressing`'s seats).
@export var empty_seat: Node3D
## Juliana's Ficha (a Collectible scene) and where it lies once the memory is over (on the empty seat's log).
@export var ficha_scene: PackedScene
@export var ficha_spot: Marker3D

@export_category("Voices (an empty stream = captions only)")
## Plays the recorded conversation (cues 1 to 6 of `FIG_RECORDING`) from the recorder, in step with its captions.
@export var recording_voice_player: AudioStreamPlayer3D
## Plays Sophia's last line (`FIG_EMPTY_SEAT`) from the empty seat, with no recording treatment.
@export var seat_voice_player: AudioStreamPlayer3D

@export_category("Recording")
@export var rain_player: AudioStreamPlayer

@export_category("Timing")
@export var finale_pause_seconds: float = 0.8
@export var silent_stop_seconds: float = 1.8
@export var rewind_seconds: float = 2.2
## The quiet between the tape stopping and the last line.
@export var seat_pause_seconds: float = 1.5
## After the last line, before someone seems to get up.
@export var stand_up_delay_seconds: float = 0.8
## After the creak, before the fire is cold and the Ficha lies on the log.
@export var fire_out_delay_seconds: float = 0.7

## Set when the player is not the node found by group "player".
@export var player: Node3D

var stage: Stage = Stage.EXPLORING

var _why_said: bool = false
var _recording_done: bool = false
var _ficha: Node3D = null
## True while this sequence holds the player's manual save block.
var _holding_save_block: bool = false


func _ready() -> void:
	_why_said = _read_flag(KEY_WHY_SAID)
	_recording_done = _read_flag(KEY_RECORDING_DONE)

	_connect_signals()
	_restore_stage()


## A sequence cut short (the clearing unloaded mid memory) gives back the save block it held, and only that.
func _exit_tree() -> void:
	if _holding_save_block:
		_set_saving_blocked(false)


func _connect_signals() -> void:
	album.opened.connect(_on_album_opened)
	album.completed.connect(_on_album_completed)
	album.wrong_arrangement.connect(_on_album_wrong)


## Resumes from saved progress. A memory already heard is never replayed: the fire is cold ash and the Ficha
## lies on the empty seat unless it has been taken (the Collectible removes itself then).
func _restore_stage() -> void:
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
# FINALE, RECORDING AND THE EMPTY SEAT
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
	await _play_empty_seat()

	_end_scene()


## The conversation, from the tape: rain round it, the fire still burning. It ends on Juliana's "Good.", and the
## reels and the rain stop together.
func _play_recording() -> void:
	stage = Stage.RECORDING
	_play_rain(true)
	_start_voice(recording_voice_player)

	await CaptionManager.play_scripted_and_wait(CaptionTracks.FIG_RECORDING)
	await _finish_voice(recording_voice_player)

	_play_rain(false)
	recorder.stop_turning()


## Sophia's last line, once, from the empty log; then someone seems to get up from it, the fire is cold ash and the
## Ficha lies where they sat.
func _play_empty_seat() -> void:
	stage = Stage.EMPTY_SEAT
	await _wait(seat_pause_seconds)

	_start_voice(seat_voice_player)
	await CaptionManager.play_scripted_and_wait(CaptionTracks.FIG_EMPTY_SEAT)
	await _finish_voice(seat_voice_player)

	await _wait(stand_up_delay_seconds)
	_play_stand_up()
	await _wait(fire_out_delay_seconds)

	fire.extinguish()
	_place_ficha(true)


## The memory is over and the Ficha is down: the state is saved as done, and only then may the player save again.
func _end_scene() -> void:
	_recording_done = true
	_write_flag(KEY_RECORDING_DONE)
	album.interaction_enabled = true
	stage = Stage.DONE
	_set_saving_blocked(false)
	sequence_completed.emit()


## Puts Juliana's Ficha on the empty seat's log, flat, unless she has taken it
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
		_play_at(ficha_spot, PlaceholderAudio.make_metal_clink(), -12.0, 3.0)


## Someone getting up from the log: the wood gives a short creak, and cloth and leaves shift. Quiet, from the seat only.
func _play_stand_up() -> void:
	var anchor: Node3D = empty_seat if empty_seat != null else ficha_spot
	if anchor == null:
		return

	_play_at(anchor, PlaceholderAudio.make_stair_creak(0.6, 7), -14.0, 2.0)
	_play_at(anchor, PlaceholderAudio.make_rustle(1.1), -20.0, 2.0, 0.15)


## A one shot sound at `anchor`, gone when it has played.
func _play_at(anchor: Node3D, stream: AudioStream, volume_db: float, unit_size: float, delay: float = 0.0) -> void:
	var sound: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.volume_db = volume_db
	sound.unit_size = unit_size
	sound.max_distance = 18.0
	anchor.add_child(sound)
	sound.finished.connect(sound.queue_free)
	if delay > 0.0:
		await _wait(delay)
		if not is_instance_valid(sound):
			return

	sound.play()


func _play_rain(enabled: bool) -> void:
	if rain_player == null:
		return

	if enabled:
		rain_player.stream = PlaceholderAudio.make_rain_loop()
		rain_player.volume_db = -16.0
		rain_player.play()
	else:
		rain_player.stop()


# ============================================================
# HELPERS
# ============================================================

## Plays a voice clip if one is assigned. With none, the captions alone carry the line.
func _start_voice(voice: AudioStreamPlayer3D) -> void:
	if voice != null and voice.stream != null:
		voice.play()


## Waits for a voice clip that is still playing after its captions, but never longer than the clip itself: a player with
## no stream, or one that has stopped, is not waited for.
func _finish_voice(voice: AudioStreamPlayer3D) -> void:
	if voice == null or voice.stream == null:
		return

	var left: float = voice.stream.get_length() + 0.25
	while is_instance_valid(voice) and voice.playing and left > 0.0:
		await _wait(0.1)
		left -= 0.1


func _set_saving_blocked(blocked: bool) -> void:
	_holding_save_block = blocked
	var target: Node = _get_player()
	if target != null and is_instance_valid(target) and target.has_method("set_manual_save_blocked"):
		target.call("set_manual_save_blocked", blocked)


func _get_player() -> Node3D:
	if player != null:
		return player

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group(&"player") as Node3D


func _wait(seconds: float) -> void:
	# Not "process always": the pause menu also pauses the sequence.
	await get_tree().create_timer(seconds, false).timeout


func _read_flag(key: StringName) -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, key, false))


func _write_flag(key: StringName) -> void:
	SaveManager.set_state_value(STATE_SECTION, key, true)
