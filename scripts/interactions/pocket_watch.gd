extends Inspectable
class_name PocketWatch

## The stopped brass pocket watch on the signal tower's back shelf, beside the tin with the Foggy Platform photograph.
## The player looks at it as at any item (its lid is engraved: "For Juli. So you always know when to meet me.").
## When they CLOSE the inspect view, once in the whole game, it begins to tick: three seconds of soft, mechanical
## ticking from where it lies, and under the last of them a faint whisper (the caption `TOWER_WALKIE_TALKIE`: "She
## never came back to the tower, Juli..."). Then every sound is stopped and it is dead silent: nothing loops and
## nothing is left playing. That it has been heard is remembered in the save.

## Raised when the whisper has finished and the watch is silent again.
signal beat_finished

const STATE_SECTION: StringName = &"triggers"
const STATE_KEY: StringName = &"tower_walkie_beat"
const CAPTION_KEY: String = "TOWER_WALKIE_TALKIE"
## The `inspect_id` metadata of the item's Visual.
const INSPECT_ID: String = "pocket_watch"

@export var ticking_seconds: float = 3.0
@export var ticking_db: float = -13.0
@export var whisper_db: float = -17.0
## How long after the ticking starts the whisper begins (it overlaps the last of the ticks).
@export var whisper_delay_seconds: float = 2.2

## True from the moment the view is closed until the whisper has ended.
var beat_running: bool = false

var _played: bool = false
var _controller: PlayerInspectController = null


func interact(player: Node) -> void:
	super.interact(player)
	_listen_for_close(player)


## Whether the beat has been heard in this game (or in this run, when there is no save).
func has_played() -> bool:
	return _played or bool(SaveManager.get_state_value(STATE_SECTION, STATE_KEY, false))


## Plays the beat unless it has been played. Returns whether it began.
func start_beat() -> bool:
	if beat_running or has_played():
		return false

	_played = true
	beat_running = true
	SaveManager.set_state_value(STATE_SECTION, STATE_KEY, true)
	_run_beat()
	return true


func _listen_for_close(player: Node) -> void:
	if _controller != null or has_played() or player == null:
		return

	_controller = player.get("inspect_controller") as PlayerInspectController
	if _controller != null:
		_controller.inspect_closed.connect(_on_inspect_closed)


func _on_inspect_closed(closed_id: String) -> void:
	if closed_id != INSPECT_ID:
		return

	if _controller != null and _controller.inspect_closed.is_connected(_on_inspect_closed):
		_controller.inspect_closed.disconnect(_on_inspect_closed)

	_controller = null
	start_beat()


func _run_beat() -> void:
	var ticking: AudioStreamPlayer3D = _make_player(PlaceholderAudio.make_watch_ticking(ticking_seconds), ticking_db)
	ticking.play()
	await get_tree().create_timer(whisper_delay_seconds).timeout
	if not is_inside_tree():
		return

	var whisper: AudioStreamPlayer3D = _make_player(PlaceholderAudio.make_whisper(), whisper_db)
	whisper.play()
	CaptionManager.say(CAPTION_KEY)
	# The whisper outlasts the ticking by a moment. Timed by the streams' length rather than their `finished` signal,
	# which a machine without sound never raises.
	await get_tree().create_timer(maxf(whisper.stream.get_length(), ticking_seconds - whisper_delay_seconds) + 0.15).timeout
	if not is_inside_tree():
		return

	# Everything stops at once: the sounds are checked untyped, as the first may have freed itself.
	for sound: Variant in [ticking, whisper]:
		if is_instance_valid(sound):
			(sound as AudioStreamPlayer3D).stop()
			(sound as AudioStreamPlayer3D).queue_free()

	beat_running = false
	beat_finished.emit()


## A one shot sound at the watch that frees itself when it ends.
func _make_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "WatchSound"
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 2.0
	player.max_distance = 12.0
	add_child(player)
	player.finished.connect(player.queue_free)
	return player
