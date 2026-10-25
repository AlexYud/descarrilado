extends Node3D
class_name TrainLightFlicker

@export var flicker_enabled: bool = true

@export var base_energy: float = 2
@export var min_energy: float = 0.15
@export var max_energy: float = 0.9

#@export var flicker_chance: float = 0.09
@export var flicker_chance: float = 0
@export var min_wait_time: float = 0.08
@export var max_wait_time: float = 0.35

#@export var hard_flicker_chance: float = 0.04
@export var hard_flicker_chance: float = 0
@export var hard_flicker_duration: float = 0.06

@export var panic_flicker_chance: float = 0.75
@export var panic_min_energy: float = 0.0
@export var panic_max_energy: float = 1.1
@export var panic_min_wait_time: float = 0.025
@export var panic_max_wait_time: float = 0.12
@export var panic_hard_flicker_chance: float = 0.22
@export var panic_hard_flicker_duration: float = 0.08

var lights: Array[OmniLight3D] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var flicker_timer: float = 0.0

var panic_flicker_active: bool = false
var blackout_active: bool = false
var hard_flicker_running: bool = false

## The scripted failure (`play_horror_sequence`): a list of beats, each a duration in seconds and the light's level
## (1 is the usual brightness, 0 is dark, above 1 a surge), played one after the other.
const SURGE_LEVEL: float = 1.7
var horror_running: bool = false
var horror_beats: Array[Vector2] = []
var _beat_index: int = 0
var _beat_left: float = 0.0
var _beat_level: float = 0.0


func _ready() -> void:
	rng.randomize()
	_collect_lights()
	_reset_timer()

	for light: OmniLight3D in lights:
		light.light_energy = base_energy
		light.visible = true


func _process(delta: float) -> void:
	if horror_running:
		_advance_horror(delta)
		return

	if not flicker_enabled:
		return

	if blackout_active:
		return

	if hard_flicker_running:
		return

	flicker_timer -= delta

	if flicker_timer > 0.0:
		return

	_do_flicker()
	_reset_timer()


func start_panic_flicker() -> void:
	if horror_running:
		stop_horror_sequence()

	blackout_active = false
	panic_flicker_active = true
	flicker_enabled = true
	flicker_timer = 0.0

	for light: OmniLight3D in lights:
		light.visible = true


func stop_panic_flicker() -> void:
	if horror_running:
		stop_horror_sequence()

	panic_flicker_active = false
	hard_flicker_running = false
	flicker_timer = 0.0

	for light: OmniLight3D in lights:
		light.visible = true
		light.light_energy = base_energy


func blackout_lights() -> void:
	if horror_running:
		stop_horror_sequence()

	panic_flicker_active = false
	hard_flicker_running = false
	blackout_active = true

	for light: OmniLight3D in lights:
		light.light_energy = 0.0
		light.visible = false


func blackout_with_final_flicker(duration: float = 0.8) -> void:
	if horror_running:
		stop_horror_sequence()

	blackout_active = false
	panic_flicker_active = true
	flicker_enabled = true
	flicker_timer = 0.0

	if duration > 0.0:
		await get_tree().create_timer(
			duration,
			false
		).timeout

	blackout_lights()


func restore_lights() -> void:
	if horror_running:
		stop_horror_sequence()

	blackout_active = false
	panic_flicker_active = false
	hard_flicker_running = false
	flicker_enabled = true
	flicker_timer = 0.0

	for light: OmniLight3D in lights:
		light.visible = true
		light.light_energy = base_energy


func _collect_lights() -> void:
	lights.clear()

	for child in get_children():
		var light: OmniLight3D = child as OmniLight3D

		if light != null:
			lights.append(light)


func _do_flicker() -> void:
	if lights.is_empty():
		return

	var current_flicker_chance: float = flicker_chance
	var current_min_energy: float = min_energy
	var current_max_energy: float = max_energy
	var current_hard_chance: float = hard_flicker_chance
	var current_hard_duration: float = hard_flicker_duration

	if panic_flicker_active:
		current_flicker_chance = panic_flicker_chance
		current_min_energy = panic_min_energy
		current_max_energy = panic_max_energy
		current_hard_chance = panic_hard_flicker_chance
		current_hard_duration = panic_hard_flicker_duration

	if rng.randf() > current_flicker_chance:
		for light: OmniLight3D in lights:
			light.visible = true
			light.light_energy = base_energy
		return

	var hard_flicker: bool = rng.randf() <= current_hard_chance

	if hard_flicker:
		hard_flicker_running = true

		if panic_flicker_active:
			for light: OmniLight3D in lights:
				light.visible = true
				light.light_energy = panic_min_energy
		else:
			for light: OmniLight3D in lights:
				light.visible = false
				light.light_energy = 0.0

		await get_tree().create_timer(
			current_hard_duration,
			false
		).timeout

		if blackout_active:
			hard_flicker_running = false
			return

		for light: OmniLight3D in lights:
			light.visible = true
			light.light_energy = base_energy

		hard_flicker_running = false
		return

	for light: OmniLight3D in lights:
		light.visible = true
		light.light_energy = rng.randf_range(current_min_energy, current_max_energy)


func _reset_timer() -> void:
	if panic_flicker_active:
		flicker_timer = rng.randf_range(panic_min_wait_time, panic_max_wait_time)
	else:
		flicker_timer = rng.randf_range(min_wait_time, max_wait_time)


# ============================================================
# THE SCRIPTED FAILURE
# ============================================================

## The wagon's power failing the way it does in a horror film, over `total_seconds`: a strobe, a false calm, a cut to
## dark with a surge as it comes back, a stretch of heavy flicker, a long blackout with stray flashes, a weak, struggling
## restart, an erratic stutter that falls apart, and a dying flicker that ends dark. The same `sequence_seed` gives the
## same failure, so every light fitting of a train can fail together. It makes no sound.
func play_horror_sequence(sequence_seed: int, total_seconds: float) -> void:
	horror_beats = build_horror_beats(sequence_seed, total_seconds)
	_beat_index = -1
	_beat_left = 0.0
	_beat_level = 0.0
	blackout_active = false
	panic_flicker_active = false
	hard_flicker_running = false
	flicker_enabled = true
	horror_running = true
	_advance_horror(0.0)


func stop_horror_sequence() -> void:
	horror_running = false


## The beats of the failure: (duration in seconds, level) pairs adding up to `total_seconds`, the level 0 for dark,
## 1 for the usual brightness. Static, so that a test can look at the pattern without playing it.
static func build_horror_beats(sequence_seed: int, total_seconds: float) -> Array[Vector2]:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = sequence_seed
	var beats: Array[Vector2] = []

	# 1. The strobe: dark and lit, a few hundredths of a second each.
	var elapsed: float = 0.0
	while elapsed < 0.7:
		var dark: float = random.randf_range(0.02, 0.07)
		var lit: float = random.randf_range(0.02, 0.08)
		beats.append(Vector2(dark, 0.0 if random.randf() < 0.8 else random.randf_range(0.1, 0.3)))
		beats.append(Vector2(lit, random.randf_range(0.6, 1.4)))
		elapsed += dark + lit

	# 2. A false calm: steady, with a faint buzz in the level, and one dip that is over almost at once.
	beats.append(Vector2(0.22, 0.95))
	beats.append(Vector2(0.18, 0.88))
	beats.append(Vector2(0.05, 0.25))
	beats.append(Vector2(0.25, 0.97))

	# 3. The cut: dark for a long moment, then a surge as it comes back, then steady again.
	beats.append(Vector2(0.75, 0.0))
	beats.append(Vector2(0.12, SURGE_LEVEL))
	beats.append(Vector2(0.18, 1.0))

	# 4. Heavy flicker: dark flashes, long dim glows and bright bursts, in no order.
	elapsed = 0.0
	while elapsed < 1.1:
		var roll: float = random.randf()
		var beat: Vector2
		if roll < 0.4:
			beat = Vector2(random.randf_range(0.03, 0.1), 0.0)
		elif roll < 0.7:
			beat = Vector2(random.randf_range(0.1, 0.3), random.randf_range(0.08, 0.3))
		else:
			beat = Vector2(random.randf_range(0.04, 0.12), random.randf_range(0.8, 1.4))
		beats.append(beat)
		elapsed += beat.x

	# 5. A long blackout, with two flashes of a hundredth of a second of light in it.
	beats.append(Vector2(random.randf_range(0.4, 0.5), 0.0))
	beats.append(Vector2(0.04, 0.4))
	beats.append(Vector2(random.randf_range(0.3, 0.4), 0.0))
	beats.append(Vector2(0.035, 0.55))
	beats.append(Vector2(random.randf_range(0.25, 0.35), 0.0))

	# 6. A weak restart: the light struggles up, falls back and holds on, dim.
	beats.append(Vector2(0.14, 0.3))
	beats.append(Vector2(0.18, 0.6))
	beats.append(Vector2(0.12, 0.12))
	beats.append(Vector2(0.55, 0.62))

	# 7. One last stutter, with long dark gaps.
	beats.append(Vector2(0.08, 1.0))
	beats.append(Vector2(0.22, 0.0))
	beats.append(Vector2(0.06, 0.8))
	beats.append(Vector2(0.4, 0.0))

	# 8. Dying: one weak flicker and then nothing.
	beats.append(Vector2(0.05, 0.3))
	beats.append(Vector2(0.5, 0.0))

	# The pattern is stretched or squeezed to the time there is, and ends dark.
	var pattern_length: float = 0.0
	for beat: Vector2 in beats:
		pattern_length += beat.x

	var stretch: float = maxf(total_seconds - 0.2, 0.2) / pattern_length
	var scaled: Array[Vector2] = []
	for beat: Vector2 in beats:
		scaled.append(Vector2(beat.x * stretch, beat.y))

	scaled.append(Vector2(0.2, 0.0))
	return scaled


func _advance_horror(delta: float) -> void:
	_beat_left -= delta
	while _beat_left <= 0.0:
		_beat_index += 1
		if _beat_index >= horror_beats.size():
			blackout_lights()
			return

		var beat: Vector2 = horror_beats[_beat_index]
		_beat_left += beat.x
		_beat_level = beat.y
		_apply_horror_level(_beat_level)


func _apply_horror_level(level: float) -> void:
	for light: OmniLight3D in lights:
		light.visible = level > 0.01
		light.light_energy = base_energy * level
