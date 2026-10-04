class_name PlaceholderAudio
extends RefCounted

## Generates simple stand-in sounds in code, so a scene can be played and tested
## before its recorded audio exists. Every function returns a new
## AudioStreamWAV; callers keep the one they need. Replace the call with a real
## stream (an exported AudioStream) once the recording is ready.

const MIX_RATE: int = 22050

## The three-note melody Sophia hums.
const MELODY_NOTES: PackedFloat32Array = [293.66, 349.23, 261.63]


## A soft hummed phrase: one note after another, then `tail_seconds` of silence.
## With `loop` the phrase repeats forever (the tail is the pause between turns).
static func make_melody(
	notes_hz: PackedFloat32Array,
	note_seconds: float = 0.75,
	tail_seconds: float = 0.0,
	loop: bool = false
) -> AudioStreamWAV:
	var note_samples: int = int(note_seconds * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(note_samples * notes_hz.size() + int(tail_seconds * MIX_RATE))

	for note_index: int in notes_hz.size():
		var frequency: float = notes_hz[note_index]
		for i: int in note_samples:
			var t: float = float(i) / MIX_RATE
			var envelope: float = minf(t / 0.08, 1.0) * exp(-t * 2.4)
			var vibrato: float = 1.0 + 0.004 * sin(TAU * 5.0 * t)
			var phase: float = TAU * frequency * vibrato * t
			var tone: float = (
				sin(phase)
				+ 0.35 * sin(2.0 * phase)
				+ 0.12 * sin(3.0 * phase)
			)
			samples[note_index * note_samples + i] = tone * envelope * 0.4

	return _to_wav(samples, loop)


## A short mechanical click, like a cassette key or a photo corner snapping.
static func make_click() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.09 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0) * exp(-t * 90.0)
		var thump: float = 0.6 * sin(TAU * 180.0 * t) * exp(-t * 60.0)
		samples[i] = (noise * 0.5 + thump) * 0.8

	return _to_wav(samples, false)


## A heavier stop: the tape mechanism clunking to a halt.
static func make_clunk() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.25 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var body: float = sin(TAU * 85.0 * t) * exp(-t * 22.0)
		var grit: float = rng.randf_range(-1.0, 1.0) * exp(-t * 55.0) * 0.4
		samples[i] = (body + grit) * 0.8

	return _to_wav(samples, false)


## A fast tape whirr that rises in pitch, for rewinding.
static func make_rewind(seconds: float = 2.2) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var phase: float = 0.0

	for i: int in samples.size():
		var progress: float = float(i) / samples.size()
		var frequency: float = lerpf(380.0, 1100.0, progress)
		phase += TAU * frequency / MIX_RATE
		var flutter: float = 0.6 + 0.4 * sin(TAU * 38.0 * progress * seconds)
		var envelope: float = minf(progress * 8.0, 1.0) * minf((1.0 - progress) * 8.0, 1.0)
		samples[i] = (1.0 if sin(phase) > 0.0 else -1.0) * flutter * envelope * 0.12

	return _to_wav(samples, false)


## Soft filtered noise that loops seamlessly: steady rain on metal.
static func make_rain_loop(seconds: float = 4.0) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var smoothed: float = 0.0

	for i: int in samples.size():
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.35)
		samples[i] = smoothed * 0.35

	return _to_wav(samples, true)


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes

	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()

	return wav


## A fire's soft hiss with random pops, looping seamlessly.
static func make_fire_crackle(seconds: float = 4.0) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 47
	var smoothed: float = 0.0
	var pop_left: int = 0
	var pop_gain: float = 0.0

	for i: int in samples.size():
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.12)
		if pop_left <= 0 and rng.randf() < 0.0009:
			pop_left = int(rng.randf_range(0.002, 0.012) * MIX_RATE)
			pop_gain = rng.randf_range(0.25, 0.7)

		var pop: float = 0.0
		if pop_left > 0:
			pop = rng.randf_range(-1.0, 1.0) * pop_gain * (float(pop_left) / MIX_RATE * 90.0)
			pop_left -= 1

		samples[i] = smoothed * 0.16 + pop * 0.5

	return _to_wav(samples, true)
