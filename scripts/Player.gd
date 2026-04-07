extends CharacterBody3D

# Movement constants
const WALK_SPEED = 2.0
const SPRINT_SPEED = 4.0
const WALK_CAMERA_ACC = 2.0
const SPRINT_CAMERA_ACC = 5.0

# Crouch constants
const CROUCH_SPEED = 1.0
const CROUCH_HEIGHT = -0.5     
const CROUCH_ACC = 8.0         
const STAND_HEIGHT = 2.0
const CROUCH_COLLIDER_HEIGHT = 1.2

# Footsteps
const FOOTSTEP_PITCH_MIN = 0.9
const FOOTSTEP_PITCH_MAX = 1.1

@export var playerSpeed = 2.0
@export var playerAcceleration = 5.0
@export var cameraSensitivity = 0.15
@export var cameraAcceleration = 2.0
@export var jumpForce = 3.0
@export var gravity = 10.0

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var hand = $Hand
@onready var flashlight = $Hand/SpotLight3D
@onready var collider = $CollisionShape3D  
@onready var sfx_walk = $SoundEffects/sfx_walk
@onready var sfx_crouch_walk = $SoundEffects/sfx_crouch_walk

var direction = Vector3.ZERO
var head_y_axis = 0.0
var camera_x_axis = 0.0
var isHudVisible = false
# Bob variables
const BOB_FREQ = 4
const BOB_AMP = 0.1
var t_bob = 0.0
var last_step_phase = false   # track when to trigger footsteps
# FOV variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5


# 3d audio variables
var debug_lines = []
var debug_markers = []
var audio_trigger_areas = {}

# Crouch state
var is_crouching = false
var crouch_offset = 0.0 
var crouch_target = 0.0

# Store original positions
var original_camera_position = Vector3.ZERO
var original_hand_position = Vector3.ZERO

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Store original positions
	#play_3d_sound("res://assets/audios/what.wav", Vector3(6.545, 1.362, -5.231), 20.0)
	original_camera_position = camera.transform.origin
	original_hand_position = hand.transform.origin
	
	
	register_audio_triggers()

func _input(event):
	if event is InputEventMouseMotion:
		head_y_axis += event.relative.x * cameraSensitivity
		camera_x_axis += event.relative.y * cameraSensitivity
		camera_x_axis = clamp(camera_x_axis, -35.0, 35.0)
	
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
		
func _process(delta):
	if !isHudVisible:
		# Movement input
		direction = Input.get_axis("left", "right") * head.basis.x + Input.get_axis("up", "down") * head.basis.z

		# Normalize to prevent diagonal speed boost
		if direction.length() > 0:
			direction = direction.normalized()

		velocity = velocity.lerp(direction * playerSpeed + velocity.y * Vector3.UP, playerAcceleration * delta)

		head.rotation.y = -deg_to_rad(head_y_axis)
		camera.rotation.x = -deg_to_rad(camera_x_axis)

		flashlight.rotation.x = lerp(
			flashlight.rotation.x,
			camera.rotation.x,
			delta * 6.0   # adjust this value for speed (higher = snappier)
		)
		flashlight.rotation.y = lerp(
			flashlight.rotation.y,
			head.rotation.y,
			delta * 6.0
		)
		
		# Handle Sprint
		if Input.is_action_pressed("sprint") and !is_crouching:
			playerSpeed = SPRINT_SPEED
			cameraAcceleration = SPRINT_CAMERA_ACC
		else:
			playerSpeed = WALK_SPEED
			cameraAcceleration = WALK_CAMERA_ACC
		
		# Handle Crouch - only change the target
		if Input.is_action_pressed("crouch"):
			is_crouching = true
			playerSpeed = CROUCH_SPEED
			crouch_target = CROUCH_HEIGHT
		else:
			is_crouching = false
			crouch_target = 0.0
		
		# Smooth crouch transition
		var previous_crouch_offset = crouch_offset
		crouch_offset = lerp(crouch_offset, crouch_target, delta * CROUCH_ACC)
		
		# Smoothly interpolate collider height based on crouch progress
		if collider and collider.shape is CapsuleShape3D:
			# Calculate how far we are into the crouch (0 to 1)
			var crouch_progress = 0.0
			if crouch_target == CROUCH_HEIGHT: # Crouching down
				crouch_progress = 1.0 - (crouch_offset - CROUCH_HEIGHT) / -CROUCH_HEIGHT
			else: # Standing up
				crouch_progress = crouch_offset / CROUCH_HEIGHT
			
			crouch_progress = clamp(crouch_progress, 0.0, 1.0)
			
			# Smoothly interpolate collider height
			var target_collider_height = lerp(STAND_HEIGHT, CROUCH_COLLIDER_HEIGHT, crouch_progress)
			collider.shape.height = lerp(collider.shape.height, target_collider_height, delta * CROUCH_ACC * 1.5)
		
		# Handle Jump
		if Input.is_action_just_pressed("jump") and is_on_floor() and !is_crouching:
			velocity.y += jumpForce
		else:
			velocity.y -= gravity * delta
		
		# --- CAMERA POSITION (CROUCH + BOB COMBINED) ---
		var final_offset = Vector3(0, crouch_offset, 0)
		if direction.length() > 0.01 and is_on_floor():
			t_bob += delta * velocity.length()
			final_offset += _headbob(t_bob)

			# --- FOOTSTEP SOUND SYNC WITH BOB ---
			var step_phase = sin(t_bob * BOB_FREQ) > 0.9
			if step_phase and not last_step_phase:
				if is_crouching:
					sfx_crouch_walk.pitch_scale = randf_range(0.8, 1.2)
					sfx_crouch_walk.play()  # Play crouch sound
				elif Input.is_action_pressed("sprint"):
					sfx_walk.pitch_scale = randf_range(1.4, 2.2)
					sfx_walk.play()  # Play normal walk sound (sprinting)
				else:
					sfx_walk.pitch_scale = randf_range(0.4, 1.4)
					sfx_walk.play()  # Play normal walk sound (walking)
			last_step_phase = step_phase
		else:
			t_bob = 0.0
			last_step_phase = false
			sfx_walk.stop()
			sfx_crouch_walk.stop()  # Also stop crouch sound
		
		# Smoothly apply the combined offset to BOTH camera and hand
		camera.transform.origin = lerp(camera.transform.origin, final_offset, delta * 10.0)
		hand.transform.origin = lerp(hand.transform.origin, original_hand_position + final_offset, 10.0 * delta)
		
		# FOV
		var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
		var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
			
		move_and_slide()
		
	for line in debug_lines:
		if is_instance_valid(line):
			pass

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _on_canvas_layer_visibility_changed():
	isHudVisible = !isHudVisible
	
	
func play_3d_sound(sound_path: String, position: Vector3, max_distance: float = 10.0, debug: bool = true):
	# Create the audio player
	var audio_player = AudioStreamPlayer3D.new()
	
	var sound = load(sound_path)
	if sound == null:
		push_error("Sound not found: " + sound_path)
		return null
	
	audio_player.stream = sound
	audio_player.max_distance = max_distance
	audio_player.unit_size = 1.0
	audio_player.global_position = position
	$"../house".add_child(audio_player)
	audio_player.play()
	
	if debug:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = SphereMesh.new()
		mesh_instance.scale = Vector3(0.2, 0.2, 0.2)  # small sphere
		mesh_instance.material_override = StandardMaterial3D.new()
		mesh_instance.material_override.albedo_color = Color.RED
		mesh_instance.global_position = position
		$"../house".add_child(mesh_instance)

		audio_player.finished.connect(func():
			mesh_instance.queue_free()
			audio_player.queue_free()
		)
	else:
		audio_player.finished.connect(func():
			audio_player.queue_free()
		)
	
	
	audio_player.finished.connect(func(): 
		audio_player.queue_free()
	)
	
	return audio_player

func register_audio_triggers():
	# Find all AudioTrigger areas in the scene
	var triggers = get_tree().get_nodes_in_group("audio_triggers")
	for trigger in triggers:
		if trigger is Area3D:
			trigger.connect("body_entered", Callable(self, "_on_audio_trigger_entered").bind(trigger))
			trigger.connect("body_exited", Callable(self, "_on_audio_trigger_exited").bind(trigger))
			audio_trigger_areas[trigger.name] = false  # Track if triggered

func _on_audio_trigger_entered(body, trigger):
	if body == self:  # If the player entered the trigger
		var sound_path = trigger.get_meta("sound_path", "res://assets/audios/whisper.mp3")
		var max_distance = trigger.get_meta("max_distance", 10.0)
		var one_time = trigger.get_meta("one_time", false)
		
		
		if sound_path and (not one_time or not audio_trigger_areas.get(trigger.name, false)):
			play_3d_sound(sound_path, trigger.global_position, max_distance, false)
			audio_trigger_areas[trigger.name] = true  # Mark as triggered
