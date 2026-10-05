extends Node3D
class_name CassetteRecorder

## A battery-less portable cassette recorder. The level drives it: it can turn or
## stop its reels, click, and rewind. Sounds are generated placeholders until
## real streams are assigned to the exports below.

@export_category("Audio (null = placeholder sound)")
@export var click_stream: AudioStream
@export var clunk_stream: AudioStream
@export var rewind_stream: AudioStream

@export_category("Reels")
## Idle speed, radians per second.
@export var reel_speed: float = 2.5

@onready var left_reel: Node3D = $Body/LeftReel
@onready var right_reel: Node3D = $Body/RightReel
@onready var effect_player: AudioStreamPlayer3D = $EffectPlayer

var _turning: bool = false
var _speed_scale: float = 1.0


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

