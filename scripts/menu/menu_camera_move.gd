extends Node3D

signal movement_finished

@export_category("Camera")
@export var menu_camera: Camera3D

@export_category("Movement")
## Positive or negative X movement used to enter the wagon.
@export var enter_x_meters: float = 2.5

## Positive or negative Z movement used to travel through the train.
@export var forward_z_meters: float = -8.0

@export var enter_duration: float = 4.0
@export var forward_duration: float = 12.0

@export_category("Final Camera Rotation")
@export var change_final_rotation: bool = true
@export var final_rotation_degrees: Vector3 = Vector3.ZERO

@export_category("Testing")
## Enable temporarily to test without connecting the Start button.
@export var play_automatically_for_test: bool = false

var _starting_position: Vector3
var _starting_rotation_degrees: Vector3
var _movement_tween: Tween
var _is_playing: bool = false


func _ready() -> void:
	if menu_camera == null:
		menu_camera = get_node_or_null("MenuCamera") as Camera3D

	if menu_camera == null:
		push_error(
			"MenuCameraMove: Assign MenuCamera in the Inspector."
		)
		return

	_starting_position = menu_camera.position
	_starting_rotation_degrees = menu_camera.rotation_degrees

	if play_automatically_for_test:
		await get_tree().process_frame
		play_camera_movement()


func play_camera_movement() -> void:
	if menu_camera == null or _is_playing:
		return

	_is_playing = true

	var inside_position: Vector3 = (
		menu_camera.position
		+ Vector3(enter_x_meters, 0.0, 0.0)
	)

	var final_position: Vector3 = (
		inside_position
		+ Vector3(0.0, 0.0, forward_z_meters)
	)

	_movement_tween = create_tween()
	_movement_tween.set_trans(Tween.TRANS_SINE)
	_movement_tween.set_ease(Tween.EASE_IN_OUT)

	# First movement: sideways through the wagon window or door.
	_movement_tween.tween_property(
		menu_camera,
		"position",
		inside_position,
		enter_duration
	)

	# Second movement: forward through the wagon interior.
	_movement_tween.tween_property(
		menu_camera,
		"position",
		final_position,
		forward_duration
	)

	if change_final_rotation:
		_movement_tween.parallel().tween_property(
			menu_camera,
			"rotation_degrees",
			final_rotation_degrees,
			forward_duration
		)

	_movement_tween.tween_callback(_on_movement_finished)


func reset_camera() -> void:
	if menu_camera == null:
		return

	if _movement_tween != null:
		_movement_tween.kill()

	menu_camera.position = _starting_position
	menu_camera.rotation_degrees = _starting_rotation_degrees

	_is_playing = false


func _on_movement_finished() -> void:
	_is_playing = false
	movement_finished.emit()
