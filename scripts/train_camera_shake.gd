extends Camera3D
class_name TrainCameraRideShake

@export var shake_enabled: bool = true

# Path from Player/Head/Camera3D to DreamIntro/Train/OutsideLoop.
@export var outside_loop_path: NodePath = ^"../../../Train/OutsideLoop"

@export var reference_train_speed: float = 5.0

@export var roll_amount_degrees: float = 0.1
@export var pitch_amount_degrees: float = 0.075
@export var yaw_amount_degrees: float = 0.075

@export var sway_speed: float = 1.15
@export var lurch_speed: float = 0.75

@export var vibration_speed: float = 22.0
@export var vibration_rotation_degrees: float = 0.008

@export var track_bump_interval: float = 1.25
@export var track_bump_roll_degrees: float = 0.025
@export var track_bump_pitch_degrees: float = 0.018
@export var track_bump_decay_speed: float = 10.0

@export var follow_speed: float = 5.0
@export var return_speed: float = 4.0

var outside_loop: Node = null

var base_rotation: Vector3 = Vector3.ZERO
var time_passed: float = 0.0

var track_bump_timer: float = 0.0
var track_bump_strength: float = 0.0
var track_bump_side: float = 1.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var has_base_rotation: bool = false


func _ready() -> void:
	rng.randomize()

	base_rotation = rotation
	has_base_rotation = true

	track_bump_timer = track_bump_interval
	outside_loop = get_node_or_null(outside_loop_path)


func _process(delta: float) -> void:
	if not has_base_rotation:
		base_rotation = rotation
		has_base_rotation = true

	if outside_loop == null or not is_instance_valid(outside_loop):
		outside_loop = get_node_or_null(outside_loop_path)

	time_passed += delta

	var strength: float = _get_shake_strength()

	if not shake_enabled or strength <= 0.001:
		_return_to_base(delta)
		return

	_update_track_bump(delta, strength)
	_apply_seated_train_motion(delta, strength)


func _get_shake_strength() -> float:
	if outside_loop == null:
		return 1.0

	var speed: float = 0.0
	var speed_value: Variant = outside_loop.get("current_movement_speed")

	if speed_value != null:
		speed = float(speed_value)
	else:
		var movement_speed_value: Variant = outside_loop.get("movement_speed")
		if movement_speed_value != null:
			speed = float(movement_speed_value)

	var safe_reference_speed: float = maxf(reference_train_speed, 0.001)
	return clampf(absf(speed) / safe_reference_speed, 0.0, 1.0)


func _update_track_bump(delta: float, strength: float) -> void:
	track_bump_timer -= delta * maxf(strength, 0.05)

	if track_bump_timer <= 0.0:
		track_bump_timer = track_bump_interval + rng.randf_range(-0.25, 0.35)
		track_bump_strength = 1.0
		track_bump_side = -1.0 if rng.randf() < 0.5 else 1.0

	track_bump_strength = move_toward(
		track_bump_strength,
		0.0,
		delta * track_bump_decay_speed
	)


func _apply_seated_train_motion(delta: float, strength: float) -> void:
	var sway_a: float = sin(time_passed * sway_speed)
	var sway_b: float = sin(time_passed * sway_speed * 0.43 + 1.9) * 0.35
	var sway: float = sway_a + sway_b

	var lurch: float = sin(time_passed * lurch_speed + 2.1)

	var vibration_a: float = sin(time_passed * vibration_speed)
	var vibration_b: float = sin(time_passed * vibration_speed * 1.37 + 0.8)
	var vibration: float = (vibration_a + vibration_b) * 0.5

	var bump_roll: float = track_bump_strength * track_bump_roll_degrees * track_bump_side
	var bump_pitch: float = track_bump_strength * track_bump_pitch_degrees

	var target_rotation: Vector3 = base_rotation

	target_rotation.z += deg_to_rad((sway * roll_amount_degrees + bump_roll) * strength)
	target_rotation.x += deg_to_rad((lurch * pitch_amount_degrees + bump_pitch) * strength)
	target_rotation.y += deg_to_rad((sway_b * yaw_amount_degrees) * strength)

	target_rotation.z += deg_to_rad(vibration * vibration_rotation_degrees * strength)
	target_rotation.x += deg_to_rad(vibration * vibration_rotation_degrees * 0.4 * strength)

	var weight: float = clampf(delta * follow_speed, 0.0, 1.0)
	rotation = rotation.lerp(target_rotation, weight)


func _return_to_base(delta: float) -> void:
	var weight: float = clampf(delta * return_speed, 0.0, 1.0)
	rotation = rotation.lerp(base_rotation, weight)
