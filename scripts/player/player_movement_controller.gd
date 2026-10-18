extends Node
class_name PlayerMovementController

## Raised when a guided walk ends; `reached` is false if it was stopped by an
## obstacle, a timeout or a cancel.
signal guided_walk_finished(reached: bool)

# Speeds in world units per second (the player is scaled 0.5 and one unit is
# about 1.27 m): walk is an unhurried ~1.65 m/s, "sprint" a brisk ~2.9 m/s walk.
const WALK_SPEED: float = 1.3
const SPRINT_SPEED: float = 2.3
## Backwards and sideways steps are slower than forward ones.
const STRAFE_SPEED_FACTOR: float = 0.88
const BACKWARD_SPEED_FACTOR: float = 0.72

# Distance covered by one step (world units): the step phase advances with the
# distance walked, so a slow walk gives slow steps and the feet never "slide".
const STEP_LENGTH_WALK: float = 0.65
const STEP_LENGTH_FAST: float = 0.8
const MIN_STEP_SPEED: float = 0.2

# Camera motion, in the camera's local units (the player is scaled 0.5, so one
# local unit is about 0.63 m). Roughly a 3 cm sway up and down, 2 cm sideways.
const BOB_VERTICAL: float = 0.02
const BOB_LATERAL: float = 0.024
const BOB_ROLL_DEGREES: float = 0.75
const BOB_NOISE_DEGREES: float = 0.12
const BOB_SPEED_EXPONENT: float = 0.8
const BOB_BLEND_IN: float = 8.0
const BOB_BLEND_OUT: float = 6.0
## Each footfall kicks a damped spring, so the head drops and settles.
const STEP_KICK: float = 0.35
const STEP_SPRING_STIFFNESS: float = 170.0
const STEP_SPRING_DAMPING: float = 13.0
const STEP_NOD_DEGREES_PER_UNIT: float = 30.0
const LANDING_KICK: float = 0.12
const LANDING_MAX_KICK: float = 0.7
const LANDING_MIN_FALL_SPEED: float = 2.0
const BREATH_RATE: float = 0.22
const BREATH_VERTICAL: float = 0.004
const BREATH_PITCH_DEGREES: float = 0.12
const GESTURE_SMOOTHING: float = 12.0

# Variety, so a thousand steps are never the same step. Every footfall rolls its
# own strength; slow drifts in stride, balance and cadence come from smooth noise;
# now and then the body does something small and unprompted.
const GAIT_AMOUNT_MIN: float = 0.8
const GAIT_AMOUNT_MAX: float = 1.22
const GAIT_ROLL_MIN: float = 0.7
const GAIT_ROLL_MAX: float = 1.3
const GAIT_FOLLOW_RATE: float = 4.0
## One foot lands a little harder than the other, and which one drifts over time.
const GAIT_ASYMMETRY: float = 0.14
const GAIT_CADENCE_DRIFT: float = 0.07
const FOOTFALL_KICK_MIN: float = 0.75
const FOOTFALL_KICK_MAX: float = 1.3
const NOISE_POSITION: float = 0.0016
const IDLE_SWAY: float = 0.003
const WALK_EVENT_SECONDS: Vector2 = Vector2(6.0, 15.0)
const IDLE_EVENT_SECONDS: Vector2 = Vector2(8.0, 18.0)

const BASE_FOV: float = 75.0
## The field of view widens only slightly when walking fast.
const FOV_FAST_WALK: float = 1.5

@export var player_acceleration: float = 4.0
@export var player_deceleration: float = 9.0
## Share of the ground acceleration that applies in the air.
@export var air_control: float = 0.3
@export var camera_sensitivity: float = 0.15
@export var gravity_force: float = 10.0
@export var flashlight_lerp_speed: float = 6.0
@export var camera_lerp_speed: float = 10.0

@export var stair_snap_length: float = 0.35
@export var max_floor_angle_degrees: float = 55.0
@export var grounded_stick_velocity: float = 0.1

var player: CharacterBody3D = null
var audio_controller: PlayerAudioController = null

var head: Node3D = null
var camera: Camera3D = null
var hand: Node3D = null
var flashlight: SpotLight3D = null
var collider: CollisionShape3D = null

var look_yaw: float = 0.0
var look_pitch: float = 0.0


## Steps taken since the walk began; the whole part counts footfalls.
var step_phase: float = 0.0

## Where an interaction (opening a door, turning a key) wants the view to be for a
## moment: leaning in, dipping towards a keyhole. Camera-local units and degrees.
## Interactions only set these targets; the controller eases towards them.
var gesture_offset: Vector3 = Vector3.ZERO
var gesture_pitch_degrees: float = 0.0
var gesture_roll_degrees: float = 0.0

var _gesture_offset_applied: Vector3 = Vector3.ZERO
var _gesture_pitch_applied: float = 0.0
var _gesture_roll_applied: float = 0.0

var _last_step_index: int = 0
var _bob_blend: float = 0.0
var _motion_time: float = 0.0
var _applied_bob: Vector3 = Vector3.ZERO
var _applied_hand_bob: Vector3 = Vector3.ZERO
var _step_spring: float = 0.0
var _step_spring_velocity: float = 0.0
var _view_pitch: float = 0.0
var _view_roll: float = 0.0
var _was_on_floor: bool = true
var _air_fall_speed: float = 0.0

var _noise: FastNoiseLite = FastNoiseLite.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _gait_amount: float = 1.0
var _gait_amount_target: float = 1.0
var _gait_roll: float = 1.0
var _gait_roll_target: float = 1.0
var _gait_asymmetry: float = 0.0
var _gait_asymmetry_target: float = 0.0
var _steps_until_asymmetry: int = 8
var _breath_phase: float = 0.0
var _view_yaw: float = 0.0

# The small unprompted movement being played, if any (see `_update_event`).
var _event_wait: float = 8.0
var _event_kind: StringName = &""
var _event_time: float = 0.0
var _event_length: float = 1.0
var _event_direction: float = 1.0

var original_camera_position: Vector3 = Vector3.ZERO
var original_hand_position: Vector3 = Vector3.ZERO
var gameplay_camera_rotation: Vector3 = Vector3.ZERO

var cutscene_camera_controlled: bool = false

## True while the player is walking fast (the sprint key held, or toggled on).
var is_sprinting: bool = false

var _sprint_toggled: bool = false

# The corridor lock (see `lock_to_corridor`).
var _corridor_active: bool = false
## Which way along the corridor the player is facing (1 along its axis, -1 back), kept while they look across it.
var _corridor_facing: float = 1.0
var _corridor_origin: Vector3 = Vector3.ZERO
var _corridor_axis: Vector3 = Vector3.FORWARD
var _corridor_min: float = 0.0
var _corridor_max: float = 0.0
## How fast the player walks while the corridor lock holds, as a fraction of the usual pace (and no
## sprinting): a slow walk builds tension.
var corridor_speed_scale: float = 1.0
## A developer multiplier on the walking speed (the dev console's `speed`); 1 in normal play.
var speed_multiplier: float = 1.0

# The guided walk: the player is walked to a spot at a slow, natural pace, looking
# where they will act (used to walk up to a door before pushing it).
var _guided_active: bool = false
var _guided_target: Vector3 = Vector3.ZERO
var _guided_look: Vector3 = Vector3.ZERO
var _guided_speed: float = 1.0
var _guided_time: float = 0.0
var _guided_timeout: float = 3.0
var _guided_best_distance: float = INF
var _guided_stalled_for: float = 0.0


func setup(
	player_node: CharacterBody3D,
	audio_node: PlayerAudioController
) -> void:
	player = player_node
	audio_controller = audio_node

	head = player.get_node("Head") as Node3D
	camera = player.get_node("Head/Camera3D") as Camera3D
	hand = player.get_node("Hand") as Node3D
	flashlight = player.get_node(
		"Hand/SpotLight3D"
	) as SpotLight3D
	collider = player.get_node(
		"CollisionShape3D"
	) as CollisionShape3D

	# The head-raise animation may already have applied its first key
	# before setup runs, so camera.position must not be captured here.
	original_camera_position = Vector3.ZERO
	gameplay_camera_rotation = Vector3.ZERO
	original_hand_position = hand.position

	_rng.randomize()
	_noise.seed = _rng.randi()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 1.0
	_event_wait = _rng.randf_range(IDLE_EVENT_SECONDS.x, IDLE_EVENT_SECONDS.y)

	_apply_floor_settings()


func handle_input(
	event: InputEvent,
	block_look: bool
) -> void:
	# During a guided walk the view is steered by the walk.
	if block_look or cutscene_camera_controlled or _guided_active:
		return

	if event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = (
			event as InputEventMouseMotion
		)

		var sensitivity: float = (
			camera_sensitivity
			* GameSettings.get_mouse_sensitivity_multiplier()
		)

		look_yaw += mouse_event.relative.x * sensitivity

		look_pitch += (
			mouse_event.relative.y
			* sensitivity
			* (-1.0 if GameSettings.get_invert_y() else 1.0)
		)

		look_pitch = clampf(
			look_pitch,
			-35.0,
			75.0
		)


func physics_update(
	delta: float,
	movement_frozen: bool
) -> void:
	_apply_floor_settings()

	if cutscene_camera_controlled:
		_apply_gravity_only(delta)
		player.move_and_slide()
		return

	_apply_look(delta)

	if movement_frozen:
		if _guided_active:
			cancel_guided_walk()
		is_sprinting = false
		_sprint_toggled = false
		_apply_gravity_only(delta)
		_update_frozen_view(delta)
		player.move_and_slide()
		return

	if _guided_active:
		_physics_guided_walk(delta)
		return

	var move_dir: Vector3 = _get_move_direction()
	var forward_dot: float = move_dir.dot(-head.basis.z)
	# Walking fast only makes sense while heading forward.
	var wants_sprint: bool = (
		_is_sprint_requested(move_dir.length() > 0.01)
		and forward_dot > 0.3
	)
	is_sprinting = wants_sprint
	var current_speed: float = _get_current_speed(
		wants_sprint
	) * _get_direction_speed_factor(forward_dot)

	_track_landing()
	_apply_horizontal_movement(
		move_dir,
		current_speed,
		delta
	)
	_apply_vertical_movement(delta)
	_update_view_effects(
		delta,
		wants_sprint
	)

	player.move_and_slide()
	_clamp_to_corridor()


## The corridor lock (the wagon's aisle in the finale): the player can only walk along a line, forward
## (the move-forward key goes along `axis`) and back, between two limits measured along it, and look
## around freely; sideways keys do nothing.
func lock_to_corridor(origin: Vector3, axis: Vector3, min_distance: float, max_distance: float) -> void:
	_corridor_origin = origin
	_corridor_axis = Vector3(axis.x, 0.0, axis.z).normalized()
	_corridor_min = min_distance
	_corridor_max = max_distance
	_corridor_active = true
	_corridor_facing = 1.0


func release_corridor() -> void:
	_corridor_active = false
	corridor_speed_scale = 1.0


func is_corridor_locked() -> bool:
	return _corridor_active


## How far along the corridor the player is.
func get_corridor_distance() -> float:
	return (player.global_position - _corridor_origin).dot(_corridor_axis)


func set_corridor_limits(min_distance: float, max_distance: float) -> void:
	_corridor_min = min_distance
	_corridor_max = max_distance


## Puts the player back inside the corridor's limits (the move-and-slide may have carried them past).
func _clamp_to_corridor() -> void:
	if not _corridor_active:
		return

	var distance: float = get_corridor_distance()
	var clamped: float = clampf(distance, _corridor_min, _corridor_max)
	if is_equal_approx(distance, clamped):
		return

	player.global_position += _corridor_axis * (clamped - distance)
	var along: float = player.velocity.dot(_corridor_axis)
	if (distance > clamped and along > 0.0) or (distance < clamped and along < 0.0):
		player.velocity -= _corridor_axis * along


func begin_cutscene_camera_control(
	final_camera_position: Vector3,
	final_camera_rotation: Vector3
) -> void:
	cancel_guided_walk()
	cutscene_camera_controlled = true

	original_camera_position = final_camera_position
	gameplay_camera_rotation = final_camera_rotation

	look_yaw = 0.0
	look_pitch = 0.0
	_reset_view_motion()

	if player != null:
		player.velocity.x = 0.0
		player.velocity.z = 0.0

	if head != null:
		head.rotation.y = 0.0

	if audio_controller != null:
		audio_controller.stop_footsteps()


func end_cutscene_camera_control() -> void:
	cutscene_camera_controlled = false

	look_yaw = 0.0
	look_pitch = -rad_to_deg(
		gameplay_camera_rotation.x
	)
	_reset_view_motion()

	var final_offset: Vector3 = Vector3.ZERO

	if head != null:
		head.rotation.y = 0.0

	if camera != null:
		camera.position = (
			original_camera_position
			+ final_offset
		)
		camera.rotation = gameplay_camera_rotation
		camera.fov = BASE_FOV

	if hand != null:
		hand.position = (
			original_hand_position
			+ final_offset
		)


func force_stop_immediately() -> void:
	if player == null:
		return

	player.velocity.x = 0.0
	player.velocity.z = 0.0

	if player.is_on_floor():
		player.velocity.y = 0.0

	_reset_view_motion()

	if audio_controller != null:
		audio_controller.stop_footsteps()

	if cutscene_camera_controlled:
		return

	var final_offset: Vector3 = Vector3.ZERO

	if camera != null:
		camera.position = (
			original_camera_position
			+ final_offset
		)
		camera.fov = BASE_FOV

	if hand != null:
		hand.position = (
			original_hand_position
			+ final_offset
		)


func get_save_state() -> Dictionary:
	return {
		"look_yaw": look_yaw,
		"look_pitch": look_pitch,
	}


func restore_save_state(save_data: Dictionary) -> void:
	look_yaw = float(save_data.get("look_yaw", 0.0))
	look_pitch = clampf(
		float(save_data.get("look_pitch", 0.0)),
		-35.0,
		75.0
	)
	_reset_view_motion()
	gameplay_camera_rotation = Vector3(
		-deg_to_rad(look_pitch),
		0.0,
		0.0
	)

	if player != null:
		player.velocity = Vector3.ZERO

	if head != null:
		head.rotation = Vector3(
			0.0,
			-deg_to_rad(look_yaw),
			0.0
		)

	var final_offset := Vector3.ZERO
	if camera != null:
		camera.position = original_camera_position + final_offset
		camera.rotation = gameplay_camera_rotation
		camera.fov = BASE_FOV

	if hand != null:
		hand.position = original_hand_position + final_offset


func _apply_floor_settings() -> void:
	if player == null:
		return

	player.floor_snap_length = stair_snap_length
	player.floor_max_angle = deg_to_rad(
		max_floor_angle_degrees
	)


func _apply_look(delta: float) -> void:
	head.rotation.y = -deg_to_rad(look_yaw)
	var aim_pitch: float = -deg_to_rad(look_pitch)
	camera.rotation.x = aim_pitch + _view_pitch
	camera.rotation.z = _view_roll
	camera.rotation.y = _view_yaw

	if flashlight != null:
		flashlight.rotation.x = lerpf(
			flashlight.rotation.x,
			aim_pitch,
			delta * flashlight_lerp_speed
		)

		flashlight.rotation.y = lerpf(
			flashlight.rotation.y,
			head.rotation.y,
			delta * flashlight_lerp_speed
		)


func _get_move_direction() -> Vector3:
	if _corridor_active:
		# Only forward and back, along the corridor: the sideways keys do nothing.
		# The forward key walks the way the player is looking (along the aisle one way or the other).
		var along_input: float = Input.get_axis("down", "up")
		var looking: float = (-head.basis.z).dot(_corridor_axis)
		if absf(looking) > 0.25:
			_corridor_facing = 1.0 if looking > 0.0 else -1.0

		return _corridor_axis * (along_input * _corridor_facing) if absf(along_input) > 0.01 else Vector3.ZERO

	var input_x: float = Input.get_axis(
		"left",
		"right"
	)
	var input_z: float = Input.get_axis(
		"down",
		"up"
	)

	var dir: Vector3 = (
		head.basis.x * input_x
		+ -head.basis.z * input_z
	)

	dir.y = 0.0

	if dir.length() > 0.0:
		return dir.normalized()

	return Vector3.ZERO


func _get_current_speed(wants_sprint: bool) -> float:
	if _corridor_active:
		return WALK_SPEED * corridor_speed_scale * speed_multiplier

	if wants_sprint:
		return SPRINT_SPEED * speed_multiplier

	return WALK_SPEED * speed_multiplier


## Backwards steps are slower than forward ones, sideways ones in between.
func _get_direction_speed_factor(forward_dot: float) -> float:
	if forward_dot >= 0.0:
		return lerpf(STRAFE_SPEED_FACTOR, 1.0, forward_dot)

	return lerpf(STRAFE_SPEED_FACTOR, BACKWARD_SPEED_FACTOR, -forward_dot)


func _apply_horizontal_movement(
	move_dir: Vector3,
	speed: float,
	delta: float
) -> void:
	var current: Vector2 = Vector2(player.velocity.x, player.velocity.z)
	var target: Vector2 = Vector2(move_dir.x, move_dir.z) * speed

	# Getting going takes a moment and stopping is quicker, as with a real body.
	var rate: float = (
		player_acceleration
		if target.length() > current.length()
		else player_deceleration
	)

	if not player.is_on_floor():
		rate *= air_control

	var next: Vector2 = current.lerp(target, clampf(rate * delta, 0.0, 1.0))
	player.velocity.x = next.x
	player.velocity.z = next.y


func _apply_vertical_movement(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= (
			gravity_force * delta
		)
	else:
		player.velocity.y = (
			-grounded_stick_velocity
		)


func _apply_gravity_only(delta: float) -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0

	if not player.is_on_floor():
		player.velocity.y -= (
			gravity_force * delta
		)
	else:
		player.velocity.y = (
			-grounded_stick_velocity
		)


func _update_view_effects(
	delta: float,
	wants_sprint: bool
) -> void:
	var horizontal_speed: float = Vector2(
		player.velocity.x,
		player.velocity.z
	).length()

	var walking: bool = (
		player.is_on_floor()
		and horizontal_speed > MIN_STEP_SPEED
	)

	if walking:
		_advance_steps(
			delta,
			horizontal_speed,
			wants_sprint
		)
	elif audio_controller != null:
		audio_controller.stop_footsteps()

	_apply_view_motion(
		delta,
		horizontal_speed,
		walking
	)

	# Walking fast widens the view only a touch; nothing like a run.
	var fast_walk: float = clampf(
		(horizontal_speed - WALK_SPEED)
		/ (SPRINT_SPEED - WALK_SPEED),
		0.0,
		1.0
	)

	camera.fov = lerpf(
		camera.fov,
		BASE_FOV + FOV_FAST_WALK * fast_walk,
		delta * 4.0
	)


func _update_frozen_view(delta: float) -> void:
	if audio_controller != null:
		audio_controller.stop_footsteps()

	_apply_view_motion(delta, 0.0, false)

	camera.fov = lerpf(
		camera.fov,
		BASE_FOV,
		delta * 8.0
	)


## The step phase advances with the distance walked (one per step), so the
## camera motion and the footsteps stay in time with how fast the body moves.
func _advance_steps(
	delta: float,
	horizontal_speed: float,
	wants_sprint: bool
) -> void:
	var step_length: float = STEP_LENGTH_WALK

	if wants_sprint:
		step_length = STEP_LENGTH_FAST

	# The cadence wanders a little, as a walker's does, instead of ticking like a clock.
	step_length *= 1.0 + GAIT_CADENCE_DRIFT * _noise_at(6.0, 0.12)

	step_phase += horizontal_speed * delta / step_length

	var step_index: int = int(floorf(step_phase))
	if step_index != _last_step_index:
		_last_step_index = step_index
		_on_footfall(horizontal_speed, wants_sprint)


func _on_footfall(
	horizontal_speed: float,
	wants_sprint: bool
) -> void:
	var strength: float = clampf(
		horizontal_speed / WALK_SPEED,
		0.4,
		1.6
	)

	# No two footfalls are alike: this one rolls its own weight, bob and sway.
	strength *= _rng.randf_range(FOOTFALL_KICK_MIN, FOOTFALL_KICK_MAX)
	_gait_amount_target = _rng.randf_range(GAIT_AMOUNT_MIN, GAIT_AMOUNT_MAX)
	_gait_roll_target = _rng.randf_range(GAIT_ROLL_MIN, GAIT_ROLL_MAX)

	_steps_until_asymmetry -= 1
	if _steps_until_asymmetry <= 0:
		_gait_asymmetry_target = _rng.randf_range(-GAIT_ASYMMETRY, GAIT_ASYMMETRY)
		_steps_until_asymmetry = _rng.randi_range(6, 14)

	_step_spring_velocity -= STEP_KICK * strength

	if audio_controller != null:
		audio_controller.trigger_footstep(wants_sprint, strength)


func _track_landing() -> void:
	var on_floor: bool = player.is_on_floor()

	if on_floor:
		if not _was_on_floor and _air_fall_speed >= LANDING_MIN_FALL_SPEED:
			_on_landed(_air_fall_speed)

		_air_fall_speed = 0.0
	else:
		_air_fall_speed = maxf(_air_fall_speed, -player.velocity.y)

	_was_on_floor = on_floor


func _on_landed(fall_speed: float) -> void:
	_step_spring_velocity -= minf(
		fall_speed * LANDING_KICK,
		LANDING_MAX_KICK
	)

	if audio_controller != null:
		audio_controller.trigger_footstep(false)


## Moves the camera and the hand the way a head and shoulders move while
## walking: a small sway that dips on every footfall and rolls from side to
## side, a little wobble that never repeats exactly, and slow breathing when
## standing still.
func _apply_view_motion(
	delta: float,
	horizontal_speed: float,
	walking: bool
) -> void:
	_motion_time += delta

	_bob_blend = lerpf(
		_bob_blend,
		1.0 if walking else 0.0,
		1.0 - exp(
			-(BOB_BLEND_IN if walking else BOB_BLEND_OUT)
			* delta
		)
	)

	if not walking and _bob_blend < 0.02:
		step_phase = 0.0
		_last_step_index = 0

	# Damped spring that the footfalls and landings kick downwards.
	var spring_accel: float = (
		-STEP_SPRING_STIFFNESS * _step_spring
		- STEP_SPRING_DAMPING * _step_spring_velocity
	)
	_step_spring_velocity += spring_accel * delta
	_step_spring += _step_spring_velocity * delta

	# Each footfall's own roll is eased in, so the change between steps never pops.
	var follow: float = 1.0 - exp(-GAIT_FOLLOW_RATE * delta)
	_gait_amount = lerpf(_gait_amount, _gait_amount_target, follow)
	_gait_roll = lerpf(_gait_roll, _gait_roll_target, follow)
	_gait_asymmetry = lerpf(_gait_asymmetry, _gait_asymmetry_target, follow * 0.3)

	var base_intensity: float = (
		pow(
			clampf(horizontal_speed / WALK_SPEED, 0.0, 1.6),
			BOB_SPEED_EXPONENT
		)
		* _bob_blend
	)
	var intensity: float = base_intensity * _gait_amount
	var roll_intensity: float = base_intensity * _gait_roll

	var stride_angle: float = TAU * step_phase
	# Sharp dip as the foot lands, a rounder rise over the next one; one foot
	# lands a little heavier than the other.
	var vertical: float = (
		(-cos(stride_angle) - 0.25 * cos(stride_angle * 2.0))
		* BOB_VERTICAL * 0.8 * intensity
		* (1.0 + _gait_asymmetry * cos(PI * step_phase))
	)
	# One period every two steps: the body shifts over the standing foot.
	var sway: float = sin(PI * step_phase)

	# Smooth noise that never repeats: the hand-held wobble, and the sway of a
	# body that is never quite still.
	var wobble_a: float = _noise_at(0.0, 0.9)
	var wobble_b: float = _noise_at(1.0, 1.1)
	var drift_x: float = _noise_at(2.0, 0.6)
	var drift_y: float = _noise_at(3.0, 0.7)

	_breath_phase += delta * BREATH_RATE * (1.0 + 0.2 * _noise_at(4.0, 0.05))
	var breath: float = sin(TAU * _breath_phase) * (1.0 + 0.4 * _noise_at(5.0, 0.07))
	var calm: float = 1.0 - _bob_blend

	var event: PackedFloat32Array = _update_event(delta, walking)

	var gesture_weight: float = 1.0 - exp(-GESTURE_SMOOTHING * delta)
	_gesture_offset_applied = _gesture_offset_applied.lerp(gesture_offset, gesture_weight)
	_gesture_pitch_applied = lerpf(_gesture_pitch_applied, gesture_pitch_degrees, gesture_weight)
	_gesture_roll_applied = lerpf(_gesture_roll_applied, gesture_roll_degrees, gesture_weight)

	# With head bobbing off only the scripted gestures (a door being opened) move the view.
	var motion: float = 1.0 if GameSettings.get_head_bob_enabled() else 0.0

	var procedural: Vector3 = Vector3(
		(
			sway * BOB_LATERAL * intensity
			+ wobble_a * NOISE_POSITION * _bob_blend
			+ drift_x * IDLE_SWAY * calm
			+ event[0]
		),
		(
			vertical + _step_spring
			+ breath * BREATH_VERTICAL * calm
			+ drift_y * IDLE_SWAY * 0.6 * calm
			+ event[1]
		),
		0.0
	)
	var bob: Vector3 = procedural * motion + _gesture_offset_applied

	_view_roll = -deg_to_rad(motion * (
		BOB_ROLL_DEGREES * sway * roll_intensity
		+ BOB_NOISE_DEGREES * wobble_a * (0.3 + 0.7 * _bob_blend)
		+ event[2]
	)) + deg_to_rad(_gesture_roll_applied)
	_view_pitch = deg_to_rad(motion * (
		_step_spring * STEP_NOD_DEGREES_PER_UNIT
		+ breath * BREATH_PITCH_DEGREES * calm
		+ BOB_NOISE_DEGREES * 0.7 * wobble_b * _bob_blend
		+ event[4]
	) + _gesture_pitch_applied)
	_view_yaw = deg_to_rad(motion * (
		BOB_NOISE_DEGREES * 0.8 * wobble_b * (0.4 + 0.6 * _bob_blend)
		+ event[3]
	))

	# The walking motion is added on top of the eased resting position without
	# being smoothed away.
	var base_offset: Vector3 = Vector3.ZERO
	var hand_bob: Vector3 = Basis(Vector3.UP, head.rotation.y) * bob

	camera.position = (
		(camera.position - _applied_bob).lerp(
			original_camera_position + base_offset,
			delta * camera_lerp_speed
		)
		+ bob
	)

	hand.position = (
		(hand.position - _applied_hand_bob).lerp(
			original_hand_position + base_offset,
			delta * camera_lerp_speed
		)
		+ hand_bob
	)

	_applied_bob = bob
	_applied_hand_bob = hand_bob


## Smooth noise from -1 to 1 that never repeats; `channel` picks an independent
## stream and `rate` how fast it drifts.
func _noise_at(channel: float, rate: float) -> float:
	return clampf(_noise.get_noise_2d(_motion_time * rate, channel * 17.3) * 1.5, -1.0, 1.0)


## The small unprompted movements of a living body, one at a time and far apart:
## a shoulder rolling, a glance, a toe catching the ground, a shifted weight, a
## deeper breath. Returns the offset x and y (camera units) and the roll, yaw and
## pitch (degrees) to add to the view right now.
func _update_event(delta: float, walking: bool) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])

	if _event_kind == &"":
		_event_wait -= delta
		if _event_wait <= 0.0:
			_start_event(walking)
		return out

	_event_time += delta
	var progress: float = clampf(_event_time / _event_length, 0.0, 1.0)
	var envelope: float = pow(sin(PI * progress), 2.0)
	var side: float = _event_direction

	match _event_kind:
		&"shoulder":
			out[0] = side * 0.012 * envelope
			out[2] = side * 0.6 * envelope
		&"glance":
			out[3] = side * 0.7 * envelope
			out[4] = 0.15 * envelope
		&"shift":
			out[0] = side * 0.015 * envelope
			out[1] = -0.004 * envelope
			out[2] = side * 0.4 * envelope
		&"sigh":
			out[1] = 0.006 * envelope
			out[4] = 0.25 * envelope

	if progress >= 1.0:
		_event_kind = &""
		_event_wait = _next_event_wait(walking)

	return out


func _start_event(walking: bool) -> void:
	var roll: float = _rng.randf()
	_event_time = 0.0
	_event_direction = 1.0 if _rng.randf() < 0.5 else -1.0

	if walking:
		if roll < 0.4:
			_event_kind = &"shoulder"
			_event_length = _rng.randf_range(1.1, 1.6)
		elif roll < 0.75:
			_event_kind = &"glance"
			_event_length = _rng.randf_range(1.0, 1.5)
		else:
			# A toe catches the ground: one stumbling dip, then back to the stride.
			_step_spring_velocity -= 0.28
			_event_wait = _next_event_wait(true)
	else:
		if roll < 0.4:
			_event_kind = &"shift"
			_event_length = _rng.randf_range(1.6, 2.4)
		elif roll < 0.7:
			_event_kind = &"glance"
			_event_length = _rng.randf_range(1.0, 1.5)
		else:
			_event_kind = &"sigh"
			_event_length = _rng.randf_range(2.4, 3.2)


func _next_event_wait(walking: bool) -> float:
	var range_seconds: Vector2 = WALK_EVENT_SECONDS if walking else IDLE_EVENT_SECONDS
	return _rng.randf_range(range_seconds.x, range_seconds.y)


func _reset_view_motion() -> void:
	step_phase = 0.0
	_last_step_index = 0
	_bob_blend = 0.0
	_applied_bob = Vector3.ZERO
	_applied_hand_bob = Vector3.ZERO
	_step_spring = 0.0
	_step_spring_velocity = 0.0
	_view_pitch = 0.0
	_view_roll = 0.0
	_air_fall_speed = 0.0
	is_sprinting = false
	_sprint_toggled = false
	_view_yaw = 0.0
	_event_kind = &""
	gesture_offset = Vector3.ZERO
	gesture_pitch_degrees = 0.0
	gesture_roll_degrees = 0.0
	_gesture_offset_applied = Vector3.ZERO
	_gesture_pitch_applied = 0.0
	_gesture_roll_applied = 0.0


## Whether the sprint control asks for walking fast right now. Held, the key must
## stay down. In toggle mode (an accessibility option) a press switches it on and
## it lasts until the player stops, like most modern games.
func _is_sprint_requested(moving: bool) -> bool:
	if GameSettings.get_sprint_toggle():
		if Input.is_action_just_pressed("sprint"):
			_sprint_toggled = not _sprint_toggled

		if not moving:
			_sprint_toggled = false

		return _sprint_toggled

	_sprint_toggled = false
	return Input.is_action_pressed("sprint")


# ----------------------------------------------------------------------
# Guided walk
# ----------------------------------------------------------------------

## Walks the player to `target` at `speed` (world units per second), slowing as
## they arrive, with their gaze easing towards `look_target`. They keep their
## footsteps, bob and weight: it is the normal walk, driven by the game instead of
## the keys. Returns false (and does nothing) if the player cannot be walked now.
## The mouse is ignored until `guided_walk_finished`.
func begin_guided_walk(
	target: Vector3,
	look_target: Vector3,
	speed: float = 1.0,
	timeout: float = 3.0
) -> bool:
	if player == null or cutscene_camera_controlled or not player.is_on_floor():
		return false

	_guided_active = true
	_guided_target = target
	_guided_look = look_target
	_guided_speed = speed
	_guided_time = 0.0
	_guided_timeout = timeout
	_guided_best_distance = INF
	_guided_stalled_for = 0.0
	return true


func is_guided_walking() -> bool:
	return _guided_active


func cancel_guided_walk() -> void:
	_finish_guided_walk(false)


func _finish_guided_walk(reached: bool) -> void:
	if not _guided_active:
		return

	_guided_active = false
	guided_walk_finished.emit(reached)


func _physics_guided_walk(delta: float) -> void:
	_guided_time += delta

	var to_target: Vector3 = _guided_target - player.global_position
	to_target.y = 0.0
	var distance: float = to_target.length()

	_steer_view_towards(_guided_look, delta)

	# Done when there, out of time, or stuck against something.
	if distance < _guided_best_distance - 0.02:
		_guided_best_distance = distance
		_guided_stalled_for = 0.0
	else:
		_guided_stalled_for += delta

	if distance < 0.05:
		_finish_guided_walk(true)
	elif _guided_time >= _guided_timeout or _guided_stalled_for > 0.6:
		_finish_guided_walk(false)

	var move_dir: Vector3 = to_target.normalized() if _guided_active else Vector3.ZERO
	var speed: float = _guided_speed * clampf(distance / 0.4, 0.25, 1.0)

	is_sprinting = false
	_track_landing()
	_apply_horizontal_movement(move_dir, speed, delta)
	_apply_vertical_movement(delta)
	_update_view_effects(delta, false)
	player.move_and_slide()


## Eases yaw and pitch so the camera looks at `point`.
func _steer_view_towards(point: Vector3, delta: float) -> void:
	var eye: Vector3 = camera.global_position
	var flat: Vector2 = Vector2(point.x - eye.x, point.z - eye.z)
	if flat.length() < 0.01:
		return

	var follow: float = 1.0 - exp(-5.0 * delta)
	var wanted_yaw: float = atan2(-flat.x, -flat.y)
	var yaw: float = lerp_angle(-deg_to_rad(look_yaw), wanted_yaw, follow)
	look_yaw = -rad_to_deg(yaw)

	var wanted_pitch: float = clampf(
		rad_to_deg(atan2(eye.y - point.y, flat.length())),
		-35.0,
		75.0
	)
	look_pitch = lerpf(look_pitch, wanted_pitch, follow)
