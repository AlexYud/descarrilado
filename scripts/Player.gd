extends CharacterBody3D

const WALK_SPEED: float = 2.0
const SPRINT_SPEED: float = 4.0
const CROUCH_SPEED: float = 1.0

const CROUCH_HEIGHT: float = -0.5
const CROUCH_ACC: float = 8.0
const STAND_HEIGHT: float = 2.0
const CROUCH_COLLIDER_HEIGHT: float = 1.2

const BOB_FREQ: float = 4.0
const BOB_AMP: float = 0.1

const BASE_FOV: float = 75.0
const FOV_CHANGE: float = 1.5

const FOOTSTEP_PITCH_MIN: float = 0.9
const FOOTSTEP_PITCH_MAX: float = 1.1
const SPRINT_FOOTSTEP_PITCH_MIN: float = 1.15
const SPRINT_FOOTSTEP_PITCH_MAX: float = 1.35
const CROUCH_FOOTSTEP_PITCH_MIN: float = 0.8
const CROUCH_FOOTSTEP_PITCH_MAX: float = 1.0

@export var player_acceleration: float = 5.0
@export var camera_sensitivity: float = 0.15
@export var jump_force: float = 3.0
@export var gravity_force: float = 10.0
@export var flashlight_lerp_speed: float = 6.0
@export var camera_lerp_speed: float = 10.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand: Node3D = $Hand
@onready var flashlight: SpotLight3D = $Hand/SpotLight3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var sfx_walk: AudioStreamPlayer = $SoundEffects/sfx_walk
@onready var sfx_crouch_walk: AudioStreamPlayer = $SoundEffects/sfx_crouch_walk

var look_yaw: float = 0.0
var look_pitch: float = 0.0

var is_crouching: bool = false
var crouch_offset: float = 0.0

var bob_time: float = 0.0
var last_step_phase: bool = false

var original_camera_position: Vector3 = Vector3.ZERO
var original_hand_position: Vector3 = Vector3.ZERO

var audio_trigger_areas: Dictionary = {}


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	original_camera_position = camera.position
	original_hand_position = hand.position
	register_audio_triggers()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		look_yaw += event.relative.x * camera_sensitivity
		look_pitch += event.relative.y * camera_sensitivity
		look_pitch = clampf(look_pitch, -35.0, 35.0)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _physics_process(delta: float) -> void:
	_apply_look(delta)

	var move_dir: Vector3 = _get_move_direction()
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	var wants_sprint: bool = Input.is_action_pressed("sprint") and not wants_crouch
	var current_speed: float = _get_current_speed(wants_crouch, wants_sprint)

	_apply_horizontal_movement(move_dir, current_speed, delta)
	_apply_vertical_movement(delta, wants_crouch)
	_update_crouch(delta, wants_crouch)
	_update_view_effects(delta, move_dir, wants_crouch, wants_sprint)

	move_and_slide()


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
	velocity.x = lerpf(velocity.x, target_velocity.x, player_acceleration * delta)
	velocity.z = lerpf(velocity.z, target_velocity.z, player_acceleration * delta)


func _apply_vertical_movement(delta: float, wants_crouch: bool) -> void:
	if not is_on_floor():
		velocity.y -= gravity_force * delta
	elif Input.is_action_just_pressed("jump") and not wants_crouch:
		velocity.y = jump_force
	else:
		velocity.y = 0.0


func _apply_gravity_only(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, player_acceleration * delta)
	velocity.z = lerpf(velocity.z, 0.0, player_acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity_force * delta
	else:
		velocity.y = 0.0


func _update_crouch(delta: float, wants_crouch: bool) -> void:
	is_crouching = wants_crouch

	var target_offset: float = CROUCH_HEIGHT if wants_crouch else 0.0
	crouch_offset = lerpf(crouch_offset, target_offset, delta * CROUCH_ACC)

	if collider and collider.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collider.shape as CapsuleShape3D
		var crouch_amount: float = clampf(absf(crouch_offset / CROUCH_HEIGHT), 0.0, 1.0)
		var target_height: float = lerpf(STAND_HEIGHT, CROUCH_COLLIDER_HEIGHT, crouch_amount)
		capsule.height = lerpf(capsule.height, target_height, delta * CROUCH_ACC * 1.5)


func _update_view_effects(delta: float, move_dir: Vector3, wants_crouch: bool, wants_sprint: bool) -> void:
	var final_offset: Vector3 = Vector3(0.0, crouch_offset, 0.0)
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()

	if move_dir.length() > 0.01 and is_on_floor():
		bob_time += delta * maxf(horizontal_speed, 1.0)
		final_offset += _headbob(bob_time)
		_update_footsteps(wants_crouch, wants_sprint)
	else:
		bob_time = 0.0
		last_step_phase = false
		_stop_footsteps()

	camera.position = camera.position.lerp(original_camera_position + final_offset, delta * camera_lerp_speed)
	hand.position = hand.position.lerp(original_hand_position + final_offset, delta * camera_lerp_speed)

	var fov_speed: float = clampf(horizontal_speed, 0.0, SPRINT_SPEED * 2.0)
	var target_fov: float = BASE_FOV + FOV_CHANGE * fov_speed
	camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)


func _headbob(time: float) -> Vector3:
	var pos: Vector3 = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2.0) * BOB_AMP
	return pos


func _update_footsteps(wants_crouch: bool, wants_sprint: bool) -> void:
	var step_phase: bool = sin(bob_time * BOB_FREQ) > 0.9

	if step_phase and not last_step_phase:
		if wants_crouch:
			sfx_walk.stop()
			sfx_crouch_walk.pitch_scale = randf_range(CROUCH_FOOTSTEP_PITCH_MIN, CROUCH_FOOTSTEP_PITCH_MAX)
			sfx_crouch_walk.play()
		else:
			sfx_crouch_walk.stop()

			if wants_sprint:
				sfx_walk.pitch_scale = randf_range(SPRINT_FOOTSTEP_PITCH_MIN, SPRINT_FOOTSTEP_PITCH_MAX)
			else:
				sfx_walk.pitch_scale = randf_range(FOOTSTEP_PITCH_MIN, FOOTSTEP_PITCH_MAX)

			sfx_walk.play()

	last_step_phase = step_phase


func _stop_footsteps() -> void:
	if sfx_walk.playing:
		sfx_walk.stop()
	if sfx_crouch_walk.playing:
		sfx_crouch_walk.stop()


func play_3d_sound(sound_path: String, sound_position: Vector3, max_distance: float = 10.0, debug: bool = false) -> AudioStreamPlayer3D:
	var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var sound: Resource = load(sound_path)

	if sound == null:
		push_error("Sound not found: " + sound_path)
		return null

	audio_player.stream = sound
	audio_player.max_distance = max_distance
	audio_player.unit_size = 1.0
	audio_player.global_position = sound_position

	var audio_parent: Node = get_node_or_null("../house")
	if audio_parent == null:
		audio_parent = get_parent()

	audio_parent.add_child(audio_player)
	audio_player.play()

	if debug:
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.mesh = SphereMesh.new()
		marker.scale = Vector3(0.2, 0.2, 0.2)

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color.RED
		marker.material_override = mat
		marker.global_position = sound_position
		audio_parent.add_child(marker)

		audio_player.finished.connect(func():
			if is_instance_valid(marker):
				marker.queue_free()
			if is_instance_valid(audio_player):
				audio_player.queue_free()
		)
	else:
		audio_player.finished.connect(func():
			if is_instance_valid(audio_player):
				audio_player.queue_free()
		)

	return audio_player


func register_audio_triggers() -> void:
	var triggers: Array = get_tree().get_nodes_in_group("audio_triggers")

	for trigger in triggers:
		if trigger is Area3D:
			trigger.body_entered.connect(Callable(self, "_on_audio_trigger_entered").bind(trigger))
			trigger.body_exited.connect(Callable(self, "_on_audio_trigger_exited").bind(trigger))
			audio_trigger_areas[trigger.name] = false


func _on_audio_trigger_entered(body: Node3D, trigger: Area3D) -> void:
	if body != self:
		return

	var sound_path: String = str(trigger.get_meta("sound_path", "res://assets/audios/whisper.mp3"))
	var max_distance: float = float(trigger.get_meta("max_distance", 10.0))
	var one_time: bool = bool(trigger.get_meta("one_time", false))

	if sound_path != "" and (not one_time or not audio_trigger_areas.get(trigger.name, false)):
		play_3d_sound(sound_path, trigger.global_position, max_distance, false)
		audio_trigger_areas[trigger.name] = true


func _on_audio_trigger_exited(body: Node3D, trigger: Area3D) -> void:
	if body != self:
		return

	var one_time: bool = bool(trigger.get_meta("one_time", false))
	if not one_time:
		audio_trigger_areas[trigger.name] = false