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


## A stiff iron lever thrown over: a dull thud and a short scrape of metal.
static func make_lever() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.32 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 47
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.18)
		var scrape: float = smoothed * minf(t * 14.0, 1.0) * exp(-t * 9.0) * 0.5
		var thud: float = sin(TAU * 120.0 * t) * exp(-t * 40.0) * 0.7 if t > 0.16 else 0.0
		var ring: float = sin(TAU * 640.0 * t) * exp(-t * 35.0) * 0.12 if t > 0.16 else 0.0
		samples[i] = scrape + thud + ring

	return _to_wav(samples, false)


## A heavy mechanical CLANK-THUD that echoes away down the rails.
static func make_iron_clank() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(1.8 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 61

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var clank: float = (
			sin(TAU * 310.0 * t) + 0.7 * sin(TAU * 477.0 * t) + 0.5 * sin(TAU * 913.0 * t)
		) * exp(-t * 9.0) * 0.38
		var thud: float = sin(TAU * 62.0 * t) * exp(-t * 14.0) * 0.9 if t > 0.12 else 0.0
		var grit: float = rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.35
		# An echo of the clank, fainter and later.
		var echo_t: float = t - 0.55
		var echo: float = 0.0
		if echo_t > 0.0:
			echo = (sin(TAU * 308.0 * echo_t) + 0.6 * sin(TAU * 475.0 * echo_t)) * exp(-echo_t * 7.0) * 0.12
		samples[i] = clampf(clank + thud + grit + echo, -1.0, 1.0)

	return _to_wav(samples, false)


## A brass token dropping into a metal tray and rattling to rest.
static func make_coin_clatter() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.7 * MIX_RATE))
	var hits: Array[float] = [0.0, 0.11, 0.2, 0.27, 0.32]

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var value: float = 0.0
		for h: int in hits.size():
			var local: float = t - hits[h]
			if local < 0.0:
				continue

			var strength: float = 0.5 / (1.0 + h * 1.4)
			value += (
				sin(TAU * (2400.0 - h * 160.0) * local)
				+ 0.5 * sin(TAU * (3650.0 - h * 200.0) * local)
			) * exp(-local * 70.0) * strength

		samples[i] = clampf(value, -1.0, 1.0)

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


# ----------------------------------------------------------------------
# Doors and locks
# ----------------------------------------------------------------------
## The latch bolt pulled back by the handle: a small tick, then a duller one.
static func make_door_latch() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.16 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 83

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var first: float = (
			rng.randf_range(-1.0, 1.0) * exp(-t * 260.0) * 0.5
			+ sin(TAU * 2300.0 * t) * exp(-t * 170.0) * 0.45
		)
		var late: float = t - 0.055
		var second: float = 0.0
		if late > 0.0:
			second = (
				sin(TAU * 950.0 * late) * exp(-late * 110.0) * 0.4
				+ sin(TAU * 150.0 * late) * exp(-late * 70.0) * 0.5
			)
		samples[i] = clampf(first + second, -1.0, 1.0)

	return _to_wav(samples, false)


## A door pulled shut: the latch bolt snapping home in its keeper.
static func make_door_latch_close() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.3 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 89

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var knock: float = sin(TAU * 105.0 * t) * exp(-t * 38.0) * 0.8
		var ring: float = (
			sin(TAU * 1500.0 * t) + 0.5 * sin(TAU * 2350.0 * t)
		) * exp(-t * 85.0) * 0.3
		var grit: float = rng.randf_range(-1.0, 1.0) * exp(-t * 190.0) * 0.45
		samples[i] = clampf(knock + ring + grit, -1.0, 1.0)

	return _to_wav(samples, false)


## A heavy door coming to rest against the wall or its frame.
static func make_door_thud() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.45 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 97
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.3)
		var body: float = sin(TAU * 58.0 * t) * exp(-t * 12.0)
		var wood: float = sin(TAU * 140.0 * t) * exp(-t * 26.0) * 0.4
		var slap: float = smoothed * exp(-t * 45.0) * 0.5
		samples[i] = clampf((body + wood + slap) * 0.8, -1.0, 1.0)

	return _to_wav(samples, false)


## A key sliding into a lock: a thin metal scrape that ends on a tick as it seats.
static func make_key_insert() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.42 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 101
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.55)
		var ridges: float = 0.55 + 0.45 * sin(TAU * 62.0 * t)
		var scrape: float = 0.0
		if t < 0.33:
			scrape = smoothed * ridges * minf(t * 30.0, 1.0) * minf((0.33 - t) * 30.0, 1.0) * 0.32

		var seated: float = t - 0.34
		var tick: float = 0.0
		if seated > 0.0:
			tick = (
				sin(TAU * 2700.0 * seated) * exp(-seated * 190.0) * 0.5
				+ sin(TAU * 420.0 * seated) * exp(-seated * 120.0) * 0.4
			)
		samples[i] = clampf(scrape + tick, -1.0, 1.0)

	return _to_wav(samples, false)


## A key forced round in a stiff old lock: grinding that catches and slips.
static func make_key_turn(seconds: float = 0.7) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 107
	var slip_phase: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var pole: float = 0.986

	for i: int in samples.size():
		var progress: float = float(i) / samples.size()
		var strain: float = 0.5 + 0.5 * sin(TAU * 4.0 * progress + 1.0)
		var drive: float = sin(PI * progress) * (0.5 + 0.5 * strain)
		slip_phase += (16.0 + 14.0 * drive) / MIX_RATE
		var knock: float = 0.0
		if slip_phase >= 1.0:
			slip_phase -= 1.0
			knock = rng.randf_range(0.5, 1.0) * drive

		var omega: float = TAU * (1150.0 + 250.0 * strain) / MIX_RATE
		var y: float = knock + 2.0 * pole * cos(omega) * y1 - pole * pole * y2
		y2 = y1
		y1 = y
		var grind: float = rng.randf_range(-1.0, 1.0) * drive * 0.025
		samples[i] = clampf(y * 0.22 + grind, -1.0, 1.0)

	return _to_wav(samples, false)


## The lock's bolt thrown back: one heavy metallic knock.
static func make_bolt_throw() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.4 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 113

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var thunk: float = sin(TAU * 78.0 * t) * exp(-t * 24.0) * 0.9
		var ring: float = (
			sin(TAU * 640.0 * t) + 0.6 * sin(TAU * 1480.0 * t)
		) * exp(-t * 38.0) * 0.28
		var grit: float = rng.randf_range(-1.0, 1.0) * exp(-t * 150.0) * 0.4
		samples[i] = clampf(thunk + ring + grit, -1.0, 1.0)

	return _to_wav(samples, false)


## A locked door tried hard: the latch rattling in its keeper, three times, weaker.
static func make_locked_rattle() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.5 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 127
	var hits: Array[float] = [0.0, 0.13, 0.26]

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var value: float = 0.0
		for h: int in hits.size():
			var local: float = t - hits[h]
			if local < 0.0:
				continue

			var strength: float = 0.9 / (1.0 + h * 0.9)
			value += (
				(sin(TAU * 880.0 * local) + 0.6 * sin(TAU * 1730.0 * local)) * exp(-local * 52.0) * 0.3
				+ sin(TAU * 120.0 * local) * exp(-local * 45.0) * 0.5
				+ rng.randf_range(-1.0, 1.0) * exp(-local * 170.0) * 0.35
			) * strength

		samples[i] = clampf(value, -1.0, 1.0)

	return _to_wav(samples, false)
