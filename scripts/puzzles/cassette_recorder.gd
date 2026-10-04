extends Node3D
class_name CassetteRecorder

## A battery-less portable cassette recorder. The level drives it: it can hum a
## melody, turn or stop its reels, click, and rewind. Sounds are generated
## placeholders until real streams are assigned to the exports below.

@export_category("Audio (null = placeholder sound)")
@export var melody_stream: AudioStream
@export var click_stream: AudioStream
@export var clunk_stream: AudioStream
@export var rewind_stream: AudioStream

@export_category("Reels")
## Idle speed, radians per second.
@export var reel_speed: float = 2.5

@onready var left_reel: Node3D = $Body/LeftReel
@onready var right_reel: Node3D = $Body/RightReel
@onready var voice_player: AudioStreamPlayer3D = $VoicePlayer
@onready var effect_player: AudioStreamPlayer3D = $EffectPlayer

var _turning: bool = false
var _speed_scale: float = 1.0
var _voice_tween: Tween = null


func _process(delta: float) -> void:
	if not _turning:
		return

	var step: float = -reel_speed * _speed_scale * delta
	left_reel.rotate_y(step)
	right_reel.rotate_y(step)


func is_turning() -> bool:
	return _turning


func start_turning() -> void:
	_turning = true
	_speed_scale = 1.0


## Stops the reels at once, with a mechanical clunk.
func stop_turning() -> void:
	_turning = false
	_play_effect(clunk_stream, PlaceholderAudio.make_clunk())


func play_click() -> void:
	_play_effect(click_stream, PlaceholderAudio.make_click())


## Hums the three-note melody forever, with a pause between each turn.
func play_melody() -> void:
	_kill_voice_tween()
	voice_player.stream = melody_stream if melody_stream != null else (
		PlaceholderAudio.make_melody(
			PlaceholderAudio.MELODY_NOTES, 0.75, 4.0, true
		)
	)
	voice_player.volume_db = -6.0
	voice_player.play()


func stop_melody(fade_seconds: float = 0.8) -> void:
	if not voice_player.playing:
		return

	_kill_voice_tween()
	_voice_tween = create_tween()
	_voice_tween.tween_property(voice_player, "volume_db", -45.0, fade_seconds)
	_voice_tween.tween_callback(voice_player.stop)


## Spins the reels backwards, fast, for `seconds`; the reels keep turning after.
func rewind(seconds: float) -> void:
	_turning = true
	_speed_scale = -7.0
	_play_effect(rewind_stream, PlaceholderAudio.make_rewind(seconds))

	await get_tree().create_timer(seconds).timeout
	_speed_scale = 1.0


func _play_effect(custom: AudioStream, fallback: AudioStream) -> void:
	effect_player.stream = custom if custom != null else fallback
	effect_player.play()


func _kill_voice_tween() -> void:
	if _voice_tween != null and _voice_tween.is_valid():
		_voice_tween.kill()

	_voice_tween = null
