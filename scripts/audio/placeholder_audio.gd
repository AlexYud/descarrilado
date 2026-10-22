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


## A subtle burst of radio static with a stutter, like a memory failing to line up: noise gated
## in uneven chunks, a little bit-crushed, a low dropout hum under it. About 0.55 s, quiet.
static func make_static_glitch() -> AudioStreamWAV:
	var seconds: float = 0.55
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	var smoothed: float = 0.0
	var held: float = 0.0
	# The gate: chunk lengths in seconds, alternating open and shut.
	var chunks: Array[float] = [0.07, 0.03, 0.11, 0.05, 0.05, 0.02, 0.14, 0.08]
	var chunk_ends: Array[float] = []
	var total: float = 0.0
	for length: float in chunks:
		total += length
		chunk_ends.append(total)

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var open: bool = true
		for k: int in chunk_ends.size():
			if t < chunk_ends[k]:
				open = k % 2 == 0
				break

		var noise: float = rng.randf_range(-1.0, 1.0)
		smoothed = lerpf(smoothed, noise, 0.6)
		# Every few samples the value is held: a rough, crushed texture.
		if i % 3 == 0:
			held = smoothed

		var envelope: float = clampf(1.0 - t / seconds, 0.0, 1.0)
		var hum: float = sin(TAU * 55.0 * t) * 0.12 * envelope
		samples[i] = ((held * 0.32 if open else 0.0) + hum) * envelope

	return _to_wav(samples, false)


## One bright metallic clink, a small token set down on wood: a ringing overtone pair over a
## tiny knock, decaying in about a second.
static func make_metal_clink() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(1.0 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 512

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var ring: float = (
			sin(TAU * 3120.0 * t) * 0.55
			+ sin(TAU * 4710.0 * t) * 0.3
			+ sin(TAU * 6330.0 * t) * 0.14
		) * exp(-t * 9.0)
		var knock: float = rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.5
		samples[i] = clampf((ring + knock) * 0.7, -1.0, 1.0)

	return _to_wav(samples, false)


## Muffled arguing in another room: low, rounded syllables in two alternating voices, some of them
## raised, heard through a wall. Loops (it starts and ends in near silence).
static func make_muffled_argument(seconds: float = 9.0) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 808

	# The syllables: start, length, which voice (pitch), how loud.
	var syllables: Array[Dictionary] = []
	var at: float = 0.25
	var voice: int = 0
	while at < seconds - 0.7:
		var turn_end: float = minf(at + rng.randf_range(1.0, 1.9), seconds - 0.5)
		var raised: float = rng.randf_range(0.7, 1.0) if rng.randf() < 0.4 else rng.randf_range(0.35, 0.6)
		while at < turn_end:
			var length: float = rng.randf_range(0.07, 0.2)
			syllables.append({"at": at, "len": length, "voice": voice, "level": raised * rng.randf_range(0.7, 1.0)})
			at += length + rng.randf_range(0.02, 0.09)
		at += rng.randf_range(0.12, 0.4)
		voice = 1 - voice

	var buzz_phase: Array[float] = [0.0, 0.0]
	var pitches: Array[float] = [118.0, 176.0]
	var low_a: float = 0.0
	var low_b: float = 0.0
	var rumble: float = 0.0
	var index: int = 0
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		while index < syllables.size() - 1 and t > float(syllables[index]["at"]) + float(syllables[index]["len"]):
			index += 1

		var level: float = 0.0
		var which: int = 0
		var s: Dictionary = syllables[index]
		var local: float = t - float(s["at"])
		if local >= 0.0 and local <= float(s["len"]):
			var q: float = local / float(s["len"])
			level = sin(PI * q) * float(s["level"])
			which = int(s["voice"])

		# A buzzing voice whose pitch wanders a little; a sawtooth, then rounded off by the wall.
		var pitch: float = pitches[which] * (1.0 + 0.12 * sin(TAU * 3.1 * t + float(which)))
		buzz_phase[which] = fmod(buzz_phase[which] + pitch / MIX_RATE, 1.0)
		var saw: float = buzz_phase[which] * 2.0 - 1.0
		low_a = lerpf(low_a, saw, 0.07)
		low_b = lerpf(low_b, low_a, 0.12)
		rumble = lerpf(rumble, rng.randf_range(-1.0, 1.0), 0.02)
		samples[i] = clampf(low_b * level * 3.0 + rumble * 0.25 * (0.4 + level), -1.0, 1.0)

	# Near silence at both ends so the loop has no click.
	var fade: int = int(0.05 * MIX_RATE)
	for i: int in fade:
		var k: float = float(i) / float(fade)
		samples[i] *= k
		samples[samples.size() - 1 - i] *= k

	return _to_wav(samples, true)


## A heavy iron latch thrown open: a hard metallic clack on a deep knock, with a short ring.
static func make_iron_clack() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.8 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2310
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var knock: float = sin(TAU * 74.0 * t) * exp(-t * 9.0)
		var body: float = sin(TAU * 190.0 * t) * exp(-t * 20.0) * 0.6
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.8)
		var crack: float = smoothed * exp(-t * 90.0) * 1.0
		var ring: float = (sin(TAU * 1180.0 * t) * 0.35 + sin(TAU * 2310.0 * t) * 0.22 + sin(TAU * 3720.0 * t) * 0.12) * exp(-t * 14.0)
		samples[i] = clampf((knock + body + crack + ring) * 0.9, -1.0, 1.0)

	return _to_wav(samples, false)


## A voice on a telephone line, as a placeholder (it says nothing: syllables of a buzzing voice through a
## narrow band, over a little hiss). `warm` is slow, low, soft and breathy, with long pauses; any other
## kind is the desperate one: high, fast, loud, rough, with a tremble. `seconds` is how long it talks.
static func make_phone_voice(warm: bool, seconds: float) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5150 if warm else 6260

	var pitch: float = 172.0 if warm else 236.0
	var syllables: Array[Dictionary] = []
	var at: float = 0.15
	while at < seconds - 0.3:
		var length: float = rng.randf_range(0.14, 0.3) if warm else rng.randf_range(0.07, 0.16)
		var level: float = rng.randf_range(0.35, 0.6) if warm else rng.randf_range(0.7, 1.0)
		syllables.append({"at": at, "len": length, "level": level})
		at += length + (rng.randf_range(0.05, 0.16) if warm else rng.randf_range(0.015, 0.05))
		# Phrases: a breath between them.
		if rng.randf() < (0.22 if warm else 0.12):
			at += rng.randf_range(0.35, 0.8) if warm else rng.randf_range(0.15, 0.3)

	var phase: float = 0.0
	var low: float = 0.0
	var high_prev: float = 0.0
	var band: float = 0.0
	var breath: float = 0.0
	var index: int = 0
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		while index < syllables.size() - 1 and t > float(syllables[index]["at"]) + float(syllables[index]["len"]):
			index += 1

		var level: float = 0.0
		var s: Dictionary = syllables[index]
		var local: float = t - float(s["at"])
		if local >= 0.0 and local <= float(s["len"]):
			level = sin(PI * local / float(s["len"])) * float(s["level"])

		var wobble: float = 0.06 * sin(TAU * 4.5 * t) if warm else 0.1 * sin(TAU * 8.0 * t + sin(t * 3.0))
		phase = fmod(phase + pitch * (1.0 + wobble + 0.15 * sin(TAU * 1.3 * t)) / MIX_RATE, 1.0)
		var voice: float = phase * 2.0 - 1.0
		breath = lerpf(breath, rng.randf_range(-1.0, 1.0), 0.5)
		var source: float = voice * (0.55 if warm else 0.8) + breath * (0.45 if warm else 0.3)
		# A narrow telephone band: roll off the lows and the highs.
		low = lerpf(low, source, 0.32)
		var rolled: float = low - high_prev
		high_prev = lerpf(high_prev, low, 0.06)
		band = lerpf(band, rolled, 0.9)
		samples[i] = clampf(band * level * (1.4 if warm else 2.2) + rng.randf_range(-1.0, 1.0) * 0.012, -1.0, 1.0)

	return _to_wav(samples, false)


## The line being cut at the other end: a soft, hollow click, and the hiss drops away.
static func make_disconnect_click() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.45 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 909
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var hollow: float = sin(TAU * 310.0 * t) * exp(-t * 38.0) * 0.8
		var body: float = sin(TAU * 150.0 * t) * exp(-t * 26.0) * 0.5
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.3)
		var tick: float = smoothed * exp(-t * 160.0) * 0.5
		var line: float = rng.randf_range(-1.0, 1.0) * 0.05 * exp(-t * 14.0)
		samples[i] = clampf(hollow + body + tick + line, -1.0, 1.0)

	return _to_wav(samples, false)


## Heavy rain pounding on a wooden roof from underneath: a deep roar with big drops drumming on the
## boards. Loops.
static func make_roof_rain(seconds: float = 5.0) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1313
	var smoothed: float = 0.0
	var deep: float = 0.0
	# Drops: when, how hard, which note.
	var drops: Array[Vector3] = []
	var at: float = 0.0
	while at < seconds:
		drops.append(Vector3(at, rng.randf_range(0.4, 1.0), rng.randf_range(70.0, 190.0)))
		at += rng.randf_range(0.012, 0.05)

	var drop_index: int = 0
	var ringing: Array[Vector3] = []
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		while drop_index < drops.size() and drops[drop_index].x <= t:
			ringing.append(Vector3(t, drops[drop_index].y, drops[drop_index].z))
			drop_index += 1

		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.3)
		deep = lerpf(deep, rng.randf_range(-1.0, 1.0), 0.04)
		var value: float = smoothed * 0.16 + deep * 0.7
		var kept: Array[Vector3] = []
		for drop: Vector3 in ringing:
			var age: float = t - drop.x
			if age < 0.09:
				value += sin(TAU * drop.z * age) * exp(-age * 55.0) * drop.y * 0.22
				kept.append(drop)
		ringing = kept
		samples[i] = clampf(value, -1.0, 1.0)

	# A seamless loop: blend the end into the start.
	var blend: int = int(0.25 * MIX_RATE)
	for i: int in blend:
		var k: float = float(i) / float(blend)
		samples[i] = lerpf(samples[samples.size() - blend + i], samples[i], k)

	return _to_wav(samples.slice(0, samples.size() - blend), true)


## Someone crying quietly: breathy, shaky sobs with a catch of breath between them. Loops.
static func make_sobbing(seconds: float = 6.0) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7070
	var sobs: Array[Dictionary] = []
	var at: float = 0.3
	while at < seconds - 1.2:
		var run: int = rng.randi_range(2, 4)
		for k: int in run:
			sobs.append({"at": at, "len": rng.randf_range(0.22, 0.34), "pitch": rng.randf_range(250.0, 330.0), "level": rng.randf_range(0.5, 0.8) * (1.0 - 0.15 * k)})
			at += rng.randf_range(0.34, 0.5)
		at += rng.randf_range(0.7, 1.2)

	var phase: float = 0.0
	var breath: float = 0.0
	var low: float = 0.0
	var index: int = 0
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		while index < sobs.size() - 1 and t > float(sobs[index]["at"]) + float(sobs[index]["len"]):
			index += 1

		var level: float = 0.0
		var pitch: float = 280.0
		var s: Dictionary = sobs[index]
		var local: float = t - float(s["at"])
		if local >= 0.0 and local <= float(s["len"]):
			var q: float = local / float(s["len"])
			level = sin(PI * q) * float(s["level"])
			# The pitch falls through a sob and trembles.
			pitch = float(s["pitch"]) * (1.15 - 0.3 * q) * (1.0 + 0.05 * sin(TAU * 14.0 * t))

		phase = fmod(phase + pitch / MIX_RATE, 1.0)
		breath = lerpf(breath, rng.randf_range(-1.0, 1.0), 0.45)
		var voice: float = (phase * 2.0 - 1.0) * 0.5 + breath * 0.5
		low = lerpf(low, voice, 0.28)
		samples[i] = clampf(low * level * 1.6, -1.0, 1.0)

	var fade: int = int(0.06 * MIX_RATE)
	for i: int in fade:
		var k: float = float(i) / float(fade)
		samples[i] *= k
		samples[samples.size() - 1 - i] *= k

	return _to_wav(samples, true)


## The soft mechanical ticking of a pocket watch, `seconds` long: a tick and a lower tock every quarter of a second,
## each a tiny metallic click that rings for a few milliseconds. It does not loop.
static func make_watch_ticking(seconds: float = 3.0) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7007
	var beat: float = 0.25
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var phase: float = fmod(t, beat)
		var frequency: float = 3100.0 if int(t / beat) % 2 == 0 else 2350.0
		var click: float = 0.0
		if phase < 0.025:
			var envelope: float = exp(-phase * 300.0)
			click = (sin(TAU * frequency * phase) * 0.6 + rng.randf_range(-1.0, 1.0) * 0.3) * envelope

		samples[i] = click * 0.5 * clampf((seconds - t) / 0.05, 0.0, 1.0)

	return _to_wav(samples, false)


## A breathy whisper of seven syllables ("you're not sup-posed to be here"): shaped noise, no pitch.
static func make_whisper() -> AudioStreamWAV:
	var seconds: float = 1.9
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3003
	# Syllable starts and lengths, and how bright each is (a hiss for the s and h sounds).
	var syllables: Array[Vector3] = [
		Vector3(0.10, 0.18, 0.3), Vector3(0.36, 0.2, 0.2), Vector3(0.66, 0.14, 0.7), Vector3(0.84, 0.18, 0.4),
		Vector3(1.08, 0.14, 0.7), Vector3(1.26, 0.12, 0.3), Vector3(1.46, 0.3, 0.9),
	]
	var low: float = 0.0
	var band: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var level: float = 0.0
		var brightness: float = 0.4
		for syllable: Vector3 in syllables:
			var local: float = t - syllable.x
			if local >= 0.0 and local <= syllable.y:
				level = sin(PI * local / syllable.y)
				brightness = syllable.z

		var noise: float = rng.randf_range(-1.0, 1.0)
		# Brighter syllables keep more of the highs.
		low = lerpf(low, noise, lerpf(0.18, 0.7, brightness))
		band = lerpf(band, noise - low, 0.5)
		samples[i] = clampf((band * 1.2 + low * 0.5) * level * 0.9, -1.0, 1.0)

	return _to_wav(samples, false)


## A violent grab: a deep boom, a crack and a dissonant shriek that falls away. As loud as it gets.
static func make_grab_impact() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(1.1 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6661
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var boom: float = sin(TAU * 41.0 * t) * exp(-t * 4.5)
		var thud: float = sin(TAU * 88.0 * t) * exp(-t * 11.0) * 0.8
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.75)
		var crack: float = smoothed * exp(-t * 28.0) * 1.1
		var sweep: float = 1.0 - 0.45 * minf(t * 1.8, 1.0)
		var shriek: float = (
			sin(TAU * 910.0 * sweep * t) + sin(TAU * 1337.0 * sweep * t) * 0.8 + sin(TAU * 2120.0 * sweep * t) * 0.5
		) * exp(-t * 3.2) * 0.3
		samples[i] = clampf((boom + thud + crack + shriek) * 0.95, -1.0, 1.0)

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


## The faint hiss and hum of a telephone line, looping.
static func make_line_hiss(seconds: float = 3.0) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 97
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.55)
		var hum: float = sin(TAU * 100.0 * t) * 0.05
		var crackle: float = rng.randf_range(-1.0, 1.0) * 0.5 if rng.randf() < 0.0008 else 0.0
		samples[i] = smoothed * 0.09 + hum + crackle

	return _to_wav(samples, true)


## A receiver lifted off its hook or put back: a short plastic knock and a click.
static func make_receiver_knock() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.3 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 101

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var knock: float = sin(TAU * 210.0 * t) * exp(-t * 38.0) * 0.7
		var plastic: float = rng.randf_range(-1.0, 1.0) * exp(-t * 130.0) * 0.4
		var click: float = sin(TAU * 1700.0 * (t - 0.14)) * exp(-(t - 0.14) * 160.0) * 0.25 if t > 0.14 else 0.0
		samples[i] = knock + plastic + click

	return _to_wav(samples, false)


## The electrical hum of a failing street lamp's ballast, looping: a low mains buzz with
## its harmonics and a slow, uneven waver.
static func make_lamp_hum(seconds: float = 2.0) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 131
	var grit: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		grit = lerpf(grit, rng.randf_range(-1.0, 1.0), 0.3)
		# Whole numbers of cycles in the loop, so it joins without a click.
		var buzz: float = (
			sin(TAU * 100.0 * t) * 0.5
			+ sin(TAU * 200.0 * t) * 0.3
			+ sin(TAU * 300.0 * t) * 0.18
			+ sin(TAU * 500.0 * t) * 0.08
		)
		var waver: float = 0.75 + 0.25 * sin(TAU * 1.0 * t)
		samples[i] = buzz * waver * 0.55 + grit * 0.06

	return _to_wav(samples, true)


## A lamp striking again after darkness: a sharp electric snap and a short ring.
static func make_lamp_pop() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.35 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 137

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var snap: float = rng.randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.9
		var zap: float = sin(TAU * 2600.0 * t) * exp(-t * 90.0) * 0.35
		var thump: float = sin(TAU * 90.0 * t) * exp(-t * 28.0) * 0.5
		samples[i] = snap + zap + thump

	return _to_wav(samples, false)


## A spring latch letting go: a sharp CLICK, then the SHRK of a steel catch scraping back along its slot
## (filtered noise that brightens as it goes, with a short ring of the spring behind it).
static func make_spring_latch() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.55 * MIX_RATE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1889
	var smoothed: float = 0.0

	for i: int in samples.size():
		var t: float = float(i) / MIX_RATE
		var click: float = (
			rng.randf_range(-1.0, 1.0) * exp(-t * 300.0) * 0.6
			+ sin(TAU * 2900.0 * t) * exp(-t * 150.0) * 0.5
			+ sin(TAU * 240.0 * t) * exp(-t * 80.0) * 0.4
		)
		var scrape: float = 0.0
		var late: float = t - 0.07
		if late > 0.0 and late < 0.3:
			var progress: float = late / 0.3
			smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), lerpf(0.12, 0.85, progress))
			scrape = smoothed * sin(PI * progress) * 0.75 * (0.7 + 0.3 * sin(TAU * 38.0 * late))

		var spring: float = 0.0
		if late > 0.0:
			spring = sin(TAU * (1250.0 + 220.0 * exp(-late * 18.0)) * late) * exp(-late * 16.0) * 0.18

		samples[i] = clampf(click + scrape + spring, -1.0, 1.0)

	return _to_wav(samples, false)
