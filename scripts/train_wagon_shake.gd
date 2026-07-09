extends Node3D
class_name TrainWagonShake

@export var shake_enabled: bool = true
@export var auto_start: bool = true

# Use this to make wagon 1 shake first, then wagon 2, then wagon 3...
@export var wagon_index: int = 0
@export var wagon_delay_between_bumps: float = 0.12

# Constant train movement.
@export var continuous_roll_degrees: float = 0.42
@export var continuous_pitch_degrees: float = 0.17
@export var continuous_yaw_degrees: float = 0.12

@export var sway_speed: float = 1.2
@export var lurch_speed: float = 0.8
@export var vibration_speed: float = 18.0
@export var vibration_degrees: float = 0.03

# Occasional softer rail bumps.
@export var bump_interval: float = 4.2
@export var bump_random_time: float = 0.7
@export var bump_peak_strength: float = 0.55
@export var bump_roll_degrees: float = 0.38
@export var bump_pitch_degrees: float = 0.14
@export var bump_vertical_amount: float = 0.008
@export var bump_decay_speed: float = 2.8

@export var strength_fade_in_speed: float = 2.5
@export var strength_fade_out_speed: float = 0.9

@export var follow_speed: float = 6.5
@export var return_speed: float = 5.5

var base_position: Vector3 = Vector3.ZERO
var base_rotation: Vector3 = Vector3.ZERO

var time_passed: float = 0.0
var bump_timer: float = 0.0
var bump_strength: float = 0.0
var bump_side: float = 1.0

var current_strength: float = 0.0
var target_strength: float = 0.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()

	base_position = position
	base_rotation = rotation

	_reset_bump_timer(true)

	if auto_start:
		start_shake()
	else:
		stop_shake_immediate()


func _process(delta: float) -> void:
	time_passed += delta

	if shake_enabled:
		current_strength = move_toward(
			current_strength,
			target_strength,
			delta * strength_fade_in_speed
		)
	else:
		current_strength = move_toward(
			current_strength,
			0.0,
			delta * strength_fade_out_speed
		)

	if current_strength <= 0.001:
		_return_to_base(delta)
		return

	_update_bump(delta)
	_apply_train_motion(delta)


func start_shake() -> void:
	shake_enabled = true
	target_strength = 1.0


func stop_shake() -> void:
	shake_enabled = false
	target_strength = 0.0


func stop_shake_immediate() -> void:
	shake_enabled = false
	target_strength = 0.0
	current_strength = 0.0
	bump_strength = 0.0

	position = base_position
	rotation = base_rotation


func _update_bump(delta: float) -> void:
	bump_timer -= delta

	if bump_timer <= 0.0:
		_trigger_bump()
		_reset_bump_timer(false)

	bump_strength = move_toward(
		bump_strength,
		0.0,
		delta * bump_decay_speed
	)


func _trigger_bump() -> void:
	bump_strength = bump_peak_strength
	bump_side = -1.0 if rng.randf() < 0.5 else 1.0


func _reset_bump_timer(include_initial_wagon_delay: bool) -> void:
	var random_offset: float = 0.0

	if bump_random_time > 0.0:
		random_offset = rng.randf_range(-bump_random_time, bump_random_time)

	bump_timer = maxf(1.0, bump_interval + random_offset)

	if include_initial_wagon_delay:
		bump_timer += float(wagon_index) * wagon_delay_between_bumps


func _apply_train_motion(delta: float) -> void:
	var sway: float = sin(time_passed * sway_speed)
	var lurch: float = sin(time_passed * lurch_speed + 1.7)
	var yaw_sway: float = sin(time_passed * sway_speed * 0.55 + 2.2)
	var vibration: float = sin(time_passed * vibration_speed)

	var target_position: Vector3 = base_position
	var target_rotation: Vector3 = base_rotation

	target_rotation.z += deg_to_rad(sway * continuous_roll_degrees * current_strength)
	target_rotation.x += deg_to_rad(lurch * continuous_pitch_degrees * current_strength)
	target_rotation.y += deg_to_rad(yaw_sway * continuous_yaw_degrees * current_strength)

	target_rotation.z += deg_to_rad(vibration * vibration_degrees * current_strength)
	target_rotation.x += deg_to_rad(vibration * vibration_degrees * 0.5 * current_strength)

	target_rotation.z += deg_to_rad(bump_strength * bump_roll_degrees * bump_side * current_strength)
	target_rotation.x += deg_to_rad(bump_strength * bump_pitch_degrees * current_strength)

	target_position.y += bump_strength * bump_vertical_amount * current_strength

	var weight: float = clampf(delta * follow_speed, 0.0, 1.0)

	position = position.lerp(target_position, weight)
	rotation = rotation.lerp(target_rotation, weight)


func _return_to_base(delta: float) -> void:
	var weight: float = clampf(delta * return_speed, 0.0, 1.0)

	position = position.lerp(base_position, weight)
	rotation = rotation.lerp(base_rotation, weight)
