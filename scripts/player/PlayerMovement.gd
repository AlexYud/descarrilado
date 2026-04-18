extends Node
class_name PlayerMovementController

const WALK_SPEED: float = 2.0
const SPRINT_SPEED: float = 4.0
const CROUCH_SPEED: float = 1.0

const CROUCH_HEIGHT: float = -0.25
const CROUCH_ACC: float = 8.0
const STAND_HEIGHT: float = 2.0
const CROUCH_COLLIDER_HEIGHT: float = 1.2

const BOB_FREQ: float = 4.0
const BOB_AMP: float = 0.1

const BASE_FOV: float = 75.0
const FOV_CHANGE: float = 1.5

@export var player_acceleration: float = 5.0
@export var camera_sensitivity: float = 0.15
@export var jump_force: float = 3.0
@export var gravity_force: float = 10.0
@export var flashlight_lerp_speed: float = 6.0
@export var camera_lerp_speed: float = 10.0

var player: CharacterBody3D = null
var audio_controller: PlayerAudioController = null

var head: Node3D = null
var camera: Camera3D = null
var hand: Node3D = null
var flashlight: SpotLight3D = null
var collider: CollisionShape3D = null

var look_yaw: float = 0.0
var look_pitch: float = 0.0

var is_crouching: bool = false
var crouch_offset: float = 0.0
var bob_time: float = 0.0

var original_camera_position: Vector3 = Vector3.ZERO
var original_hand_position: Vector3 = Vector3.ZERO


func setup(player_node: CharacterBody3D, audio_node: PlayerAudioController) -> void:
	player = player_node
	audio_controller = audio_node

	head = player.get_node("Head") as Node3D
	camera = player.get_node("Head/Camera3D") as Camera3D
	hand = player.get_node("Hand") as Node3D
	flashlight = player.get_node("Hand/SpotLight3D") as SpotLight3D
	collider = player.get_node("CollisionShape3D") as CollisionShape3D

	original_camera_position = camera.position
	original_hand_position = hand.position


func handle_input(event: InputEvent, block_look: bool) -> void:
	if block_look:
		return

	if event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		look_yaw += mouse_event.relative.x * camera_sensitivity
		look_pitch += mouse_event.relative.y * camera_sensitivity
		look_pitch = clampf(look_pitch, -35.0, 75.0)


func physics_update(delta: float, movement_frozen: bool) -> void:
	_apply_look(delta)

	if movement_frozen:
		_apply_gravity_only(delta)
		_update_frozen_view(delta)
		player.move_and_slide()
		return

	var move_dir: Vector3 = _get_move_direction()
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	var wants_sprint: bool = Input.is_action_pressed("sprint") and not wants_crouch
	var current_speed: float = _get_current_speed(wants_crouch, wants_sprint)

	_apply_horizontal_movement(move_dir, current_speed, delta)
	_apply_vertical_movement(delta, wants_crouch)
	_update_crouch(delta, wants_crouch)
	_update_view_effects(delta, move_dir, wants_crouch, wants_sprint)

	player.move_and_slide()


func _apply_look(delta: float) -> void:
	head.rotation.y = -deg_to_rad(look_yaw)
	camera.rotation.x = -deg_to_rad(look_pitch)

	flashlight.rotation.x = lerpf(flashlight.rotation.x, camera.rotation.x, delta * flashlight_lerp_speed)
	flashlight.rotation.y = lerpf(flashlight.rotation.y, head.rotation.y, delta * flashlight_lerp_speed)


func _get_move_direction() -> Vector3:
	var input_x: float = Input.get_axis("left", "right")
	var input_z: float = Input.get_axis("down", "up")

	var dir: Vector3 = head.basis.x * input_x + (-head.basis.z * input_z)
	dir.y = 0.0

	if dir.length() > 0.0:
		return dir.normalized()

	return Vector3.ZERO


func _get_current_speed(wants_crouch: bool, wants_sprint: bool) -> float:
	if wants_crouch:
		return CROUCH_SPEED
	if wants_sprint:
		return SPRINT_SPEED
	return WALK_SPEED


func _apply_horizontal_movement(move_dir: Vector3, speed: float, delta: float) -> void:
	var target_velocity: Vector3 = move_dir * speed
	player.velocity.x = lerpf(player.velocity.x, target_velocity.x, player_acceleration * delta)
	player.velocity.z = lerpf(player.velocity.z, target_velocity.z, player_acceleration * delta)


func _apply_vertical_movement(delta: float, wants_crouch: bool) -> void:
	if not player.is_on_floor():
		player.velocity.y -= gravity_force * delta
	elif Input.is_action_just_pressed("jump") and not wants_crouch:
		player.velocity.y = jump_force
	else:
		player.velocity.y = 0.0


func _apply_gravity_only(delta: float) -> void:
	player.velocity.x = lerpf(player.velocity.x, 0.0, player_acceleration * delta)
	player.velocity.z = lerpf(player.velocity.z, 0.0, player_acceleration * delta)

	if not player.is_on_floor():
		player.velocity.y -= gravity_force * delta
	else:
		player.velocity.y = 0.0


func _update_crouch(delta: float, wants_crouch: bool) -> void:
	is_crouching = wants_crouch

	var target_offset: float = CROUCH_HEIGHT if wants_crouch else 0.0
	crouch_offset = lerpf(crouch_offset, target_offset, delta * CROUCH_ACC)

	if collider != null and collider.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collider.shape as CapsuleShape3D
		var crouch_amount: float = clampf(absf(crouch_offset / CROUCH_HEIGHT), 0.0, 1.0)
		var target_height: float = lerpf(STAND_HEIGHT, CROUCH_COLLIDER_HEIGHT, crouch_amount)
		capsule.height = lerpf(capsule.height, target_height, delta * CROUCH_ACC * 1.5)


func _update_view_effects(delta: float, move_dir: Vector3, wants_crouch: bool, wants_sprint: bool) -> void:
	var final_offset: Vector3 = Vector3(0.0, crouch_offset, 0.0)
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()

	if move_dir.length() > 0.01 and player.is_on_floor():
		bob_time += delta * maxf(horizontal_speed, 1.0)
		final_offset += _headbob(bob_time)
		audio_controller.update_footsteps(bob_time, wants_crouch, wants_sprint)
	else:
		bob_time = 0.0
		audio_controller.stop_footsteps()

	camera.position = camera.position.lerp(original_camera_position + final_offset, delta * camera_lerp_speed)
	hand.position = hand.position.lerp(original_hand_position + final_offset, delta * camera_lerp_speed)

	var fov_speed: float = clampf(horizontal_speed, 0.0, SPRINT_SPEED * 2.0)
	var target_fov: float = BASE_FOV + FOV_CHANGE * fov_speed
	camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)


func _update_frozen_view(delta: float) -> void:
	bob_time = 0.0
	audio_controller.stop_footsteps()

	var final_offset: Vector3 = Vector3(0.0, crouch_offset, 0.0)

	camera.position = camera.position.lerp(original_camera_position + final_offset, delta * camera_lerp_speed)
	hand.position = hand.position.lerp(original_hand_position + final_offset, delta * camera_lerp_speed)
	camera.fov = lerpf(camera.fov, BASE_FOV, delta * 8.0)


func _headbob(time: float) -> Vector3:
	var pos: Vector3 = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2.0) * BOB_AMP
	return pos
