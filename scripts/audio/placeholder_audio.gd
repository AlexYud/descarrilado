class_name PlaceholderAudio
extends RefCounted

## Generates simple stand-in sounds in code, so a scene can be played and tested
## before its recorded audio exists. Every function returns a new
## AudioStreamWAV; callers keep the one they need. Replace the call with a real
## stream (an exported AudioStream) once the recording is ready.

const MIX_RATE: int = 22050


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


## A heavy boot landing on wooden boards: a low thump with a dry knock.
static func make_footstep() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.34 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 61
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var thump: float = sin(TAU * 62.0 * t) * exp(-t * 16.0)
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.25)
		var knock: float = smoothed * exp(-t * 34.0) * 0.7
		var board: float = sin(TAU * 140.0 * t) * exp(-t * 26.0) * 0.35
		samples[i] = (thump + knock + board) * 0.85

	return _to_wav(samples, false)


## A heavy door slammed shut: one deep boom with a splintering crack on top.
static func make_slam() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.9 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 37
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var boom: float = sin(TAU * 48.0 * t) * exp(-t * 7.0)
		var thud: float = sin(TAU * 95.0 * t) * exp(-t * 13.0) * 0.7
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.6)
		var crack: float = smoothed * exp(-t * 40.0) * 1.1
		samples[i] = clampf((boom + thud + crack) * 0.95, -1.0, 1.0)

	return _to_wav(samples, false)


## A hard, quick running footfall on boards: lighter and sharper than a walking step.
static func make_run_step() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.2 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 71
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var thump: float = sin(TAU * 88.0 * t) * exp(-t * 24.0)
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.4)
		var slap: float = smoothed * exp(-t * 55.0) * 0.8
		var board: float = sin(TAU * 190.0 * t) * exp(-t * 38.0) * 0.4
		samples[i] = (thump + slap + board) * 0.9

	return _to_wav(samples, false)


## A door hinge complaining: a falling, wavering scrape.
static func make_creak(seconds: float = 1.6) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var phase: float = 0.0

	for i: int in samples.size():
		var progress: float = float(i) / samples.size()
		var wobble: float = 1.0 + 0.08 * sin(TAU * 7.0 * progress * seconds)
		var frequency: float = lerpf(310.0, 170.0, progress) * wobble
		phase += TAU * frequency / MIX_RATE
		var saw: float = fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var envelope: float = minf(progress * 6.0, 1.0) * minf((1.0 - progress) * 4.0, 1.0)
		samples[i] = saw * envelope * 0.16

	return _to_wav(samples, false)


## A knuckle or fingernail tapping glass: short, bright and metallic.
static func make_tap() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.22 * MIX_RATE))

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var ring: float = sin(TAU * 1850.0 * t) + 0.6 * sin(TAU * 2760.0 * t)
		var body: float = sin(TAU * 420.0 * t) * 0.8
		samples[i] = (ring * exp(-t * 55.0) + body * exp(-t * 90.0)) * 0.55

	return _to_wav(samples, false)


## Something large moving through dry leaves and undergrowth, then gone.
static func make_rustle(seconds: float = 2.4) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 83
	var smoothed: float = 0.0

	for i: int in samples.size():
		var progress: float = float(i) / samples.size()
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.5)
		var crackle: float = 1.0 if rng.randf() < 0.02 else 0.25
		var envelope: float = minf(progress * 10.0, 1.0) * (1.0 - progress)
		samples[i] = smoothed * crackle * envelope * 0.4

	return _to_wav(samples, false)


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
