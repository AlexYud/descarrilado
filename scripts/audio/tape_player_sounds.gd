class_name TapePlayerSounds
extends RefCounted

## The sounds of the tape player in the waiting shed's recording (placeholder_tape_player_sounds.mp3, 6.91 s), cut into the parts the machine plays:
##   0.00 - 2.30  the machine takes the tape and the play button goes down (the click at about 2.25 s): the recording's picture begins at 2.30 exactly;
##   2.30 - 6.20  the machine running: it loops, without a seam, for as long as the tape plays;
##   6.20 - 6.91  the stop (the tape's end, or the pause of the second viewing), played once.
## The mp3 is decoded once (AudioStreamPlayback.mix_audio) into two sample-accurate streams: start_stream (0 to 6.20 s, looping from 2.30 s to 6.20 s) and stop_stream
## (6.20 s to the end). A player that plays start_stream from 0 plays the first part and then loops the middle; from LOOP_BEGIN it only loops.

const PATH: String = "res://assets/audios/placeholder_tape_player_sounds.mp3"
## Where the middle part (the loop) begins and ends in the file, in seconds.
const LOOP_BEGIN: float = 2.30
const LOOP_END: float = 6.20

static var _start: AudioStreamWAV = null
static var _stop: AudioStreamWAV = null
static var _length: float = 0.0


## The first part and the loop, as one stream (it ends at LOOP_END and goes back to LOOP_BEGIN).
static func start_stream() -> AudioStreamWAV:
	_decode()
	return _start


## The last part, played once.
static func stop_stream() -> AudioStreamWAV:
	_decode()
	return _stop


## The whole file's length in seconds (0 if it could not be read).
static func length() -> float:
	_decode()
	return _length


## Decodes the file now (it is done once; the sequence asks for it while the level is built, so that nothing is decoded while the scene is watched).
static func prepare() -> void:
	_decode()


static func _decode() -> void:
	if _start != null:
		return

	var source: AudioStreamMP3 = load(PATH) as AudioStreamMP3
	if source == null:
		push_warning("TapePlayerSounds: %s is missing." % PATH)
		_start = AudioStreamWAV.new()
		_stop = AudioStreamWAV.new()
		return

	var rate: int = int(AudioServer.get_mix_rate())
	var playback: AudioStreamPlayback = source.instantiate_playback()
	playback.start(0.0)
	var frames: PackedVector2Array = playback.mix_audio(1.0, int(ceil((source.get_length() + 0.1) * float(rate))))
	_length = float(frames.size()) / float(rate)
	var loop_begin: int = int(round(LOOP_BEGIN * float(rate)))
	var loop_end: int = mini(int(round(LOOP_END * float(rate))), frames.size())
	_start = _wav(frames, 0, loop_end, rate)
	_start.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_start.loop_begin = loop_begin
	_start.loop_end = loop_end
	_stop = _wav(frames, loop_end, frames.size(), rate)


## Frames from to to (exclusive) as a 16-bit stereo stream.
static func _wav(frames: PackedVector2Array, from: int, to: int, rate: int) -> AudioStreamWAV:
	var count: int = maxi(to - from, 0)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 4)
	for i: int in count:
		var frame: Vector2 = frames[from + i]
		data.encode_s16(i * 4, int(clampf(frame.x, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(frame.y, -1.0, 1.0) * 32767.0))

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = rate
	stream.data = data
	return stream
