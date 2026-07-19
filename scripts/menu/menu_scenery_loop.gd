extends Node3D
class_name MenuSceneryLoop


# ============================================================
# MOVEMENT
# ============================================================

@export_category("Movement")

## Normal scenery travel speed in metres per second.
@export_range(0.0, 30.0, 0.1)
var movement_speed: float = 12.0

## Change this if the scenery moves in the wrong direction.
@export var move_toward_positive_z: bool = true

@export var active: bool = true


# ============================================================
# CHUNK LAYOUT
# ============================================================

@export_category("Chunk Layout")

## Every chunk must represent this amount of local Z distance.
@export_range(4.0, 100.0, 0.5)
var chunk_length: float = 32.0

## Only direct children beginning with this name are moved.
@export var chunk_name_prefix: String = "Chunk"

## Automatically positions all chunks when the scene begins.
@export var auto_arrange_on_ready: bool = true


# ============================================================
# CAMERA FOLLOWING
# ============================================================

@export_category("Camera Following")

## Uses the active Camera3D as the recycling reference.
@export var follow_active_camera: bool = true

## Updates the reference continuously while the camera moves.
@export var update_camera_reference_every_frame: bool = true

## Used when Follow Active Camera is disabled.
@export var manual_reference_z: float = 0.0

## Number of complete chunks maintained behind the camera.
##
## Keep this at 1 for the menu cutscene.
@export_range(0, 4, 1)
var chunks_behind_camera: int = 1

## Extra safety distance before a rear chunk is recycled.
@export_range(0.0, 32.0, 0.5)
var recycle_margin: float = 4.0


# ============================================================
# DEBUG
# ============================================================

@export_category("Debug")

@export var print_setup_summary: bool = true


# ============================================================
# RUNTIME
# ============================================================

var chunks: Array[Node3D] = []

var current_speed: float = 0.0
var reference_z: float = 0.0

var active_camera: Camera3D = null
var stop_tween: Tween = null


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	current_speed = absf(movement_speed)

	_collect_chunks()

	# Wait for MenuController to make MenuCamera current.
	call_deferred("_finish_setup")


func _finish_setup() -> void:
	_find_active_camera()
	_update_reference_z()

	if auto_arrange_on_ready:
		_arrange_chunks()

	_validate_setup()

	if print_setup_summary:
		_print_summary()


# ============================================================
# MOVEMENT
# ============================================================

func _process(delta: float) -> void:
	if follow_active_camera:
		if (
			active_camera == null
			or not is_instance_valid(active_camera)
			or not active_camera.current
		):
			_find_active_camera()

	if update_camera_reference_every_frame:
		_update_reference_z()

	# Recycle even when movement is stopped in case the camera
	# itself moved a large distance during the current frame.
	_recycle_chunks_relative_to_camera()

	if not active:
		return

	if is_zero_approx(current_speed):
		return

	var direction: float = 1.0

	if not move_toward_positive_z:
		direction = -1.0

	var displacement: float = (
		current_speed
		* direction
		* delta
	)

	_move_chunks(displacement)
	_recycle_chunks_relative_to_camera()


func _move_chunks(displacement: float) -> void:
	if chunks.is_empty():
		return

	if is_zero_approx(displacement):
		return

	for chunk: Node3D in chunks:
		if not _is_valid_chunk(chunk):
			continue

		chunk.position.z += displacement


# ============================================================
# CAMERA-RELATIVE RECYCLING
# ============================================================

func _recycle_chunks_relative_to_camera() -> void:
	if chunks.size() < 2:
		return

	if move_toward_positive_z:
		_recycle_positive_z()
	else:
		_recycle_negative_z()


func _recycle_positive_z() -> void:
	var behind_limit: float = (
		reference_z
		+ float(chunks_behind_camera) * chunk_length
		+ chunk_length * 0.5
		+ recycle_margin
	)

	var safety_count: int = 0
	var maximum_iterations: int = chunks.size() * 3

	while safety_count < maximum_iterations:
		var rear_chunk: Node3D = _get_maximum_z_chunk()

		if rear_chunk == null:
			return

		if rear_chunk.position.z <= behind_limit:
			return

		var frontmost_z: float = _get_minimum_chunk_z()

		rear_chunk.position.z = (
			frontmost_z
			- chunk_length
		)

		safety_count += 1


func _recycle_negative_z() -> void:
	var behind_limit: float = (
		reference_z
		- float(chunks_behind_camera) * chunk_length
		- chunk_length * 0.5
		- recycle_margin
	)

	var safety_count: int = 0
	var maximum_iterations: int = chunks.size() * 3

	while safety_count < maximum_iterations:
		var rear_chunk: Node3D = _get_minimum_z_chunk()

		if rear_chunk == null:
			return

		if rear_chunk.position.z >= behind_limit:
			return

		var frontmost_z: float = _get_maximum_chunk_z()

		rear_chunk.position.z = (
			frontmost_z
			+ chunk_length
		)

		safety_count += 1


func _get_minimum_chunk_z() -> float:
	var minimum_z: float = INF

	for chunk: Node3D in chunks:
		if not _is_valid_chunk(chunk):
			continue

		minimum_z = minf(
			minimum_z,
			chunk.position.z
		)

	return minimum_z


func _get_maximum_chunk_z() -> float:
	var maximum_z: float = -INF

	for chunk: Node3D in chunks:
		if not _is_valid_chunk(chunk):
			continue

		maximum_z = maxf(
			maximum_z,
			chunk.position.z
		)

	return maximum_z


func _get_minimum_z_chunk() -> Node3D:
	var result: Node3D = null
	var minimum_z: float = INF

	for chunk: Node3D in chunks:
		if not _is_valid_chunk(chunk):
			continue

		if chunk.position.z < minimum_z:
			minimum_z = chunk.position.z
			result = chunk

	return result


func _get_maximum_z_chunk() -> Node3D:
	var result: Node3D = null
	var maximum_z: float = -INF

	for chunk: Node3D in chunks:
		if not _is_valid_chunk(chunk):
			continue

		if chunk.position.z > maximum_z:
			maximum_z = chunk.position.z
			result = chunk

	return result


func _is_valid_chunk(chunk: Node3D) -> bool:
	return (
		chunk != null
		and is_instance_valid(chunk)
	)


# ============================================================
# CHUNK COLLECTION
# ============================================================

func _collect_chunks() -> void:
	chunks.clear()

	for child: Node in get_children():
		var chunk: Node3D = child as Node3D

		if chunk == null:
			continue

		if not str(chunk.name).begins_with(
			chunk_name_prefix
		):
			continue

		chunks.append(chunk)

	chunks.sort_custom(_sort_chunks_by_name)


func _sort_chunks_by_name(
	first_value: Variant,
	second_value: Variant
) -> bool:
	var first_chunk: Node = first_value as Node
	var second_chunk: Node = second_value as Node

	if first_chunk == null or second_chunk == null:
		return false

	return (
		str(first_chunk.name)
		< str(second_chunk.name)
	)


# ============================================================
# CAMERA REFERENCE
# ============================================================

func _find_active_camera() -> void:
	active_camera = get_viewport().get_camera_3d()


func _update_reference_z() -> void:
	reference_z = manual_reference_z

	if not follow_active_camera:
		return

	if (
		active_camera == null
		or not is_instance_valid(active_camera)
	):
		_find_active_camera()

	if active_camera == null:
		return

	var camera_local_position: Vector3 = to_local(
		active_camera.global_position
	)

	reference_z = camera_local_position.z


# ============================================================
# INITIAL ARRANGEMENT
# ============================================================

func _arrange_chunks() -> void:
	if chunks.is_empty():
		return

	var safe_length: float = maxf(
		chunk_length,
		0.001
	)

	var safe_behind_count: int = clampi(
		chunks_behind_camera,
		0,
		maxi(chunks.size() - 1, 0)
	)

	if move_toward_positive_z:
		var first_z: float = (
			reference_z
			- safe_length
			* float(
				chunks.size()
				- 1
				- safe_behind_count
			)
		)

		for index: int in range(chunks.size()):
			var chunk: Node3D = chunks[index]

			if not _is_valid_chunk(chunk):
				continue

			chunk.position.z = (
				first_z
				+ float(index) * safe_length
			)
	else:
		var first_z: float = (
			reference_z
			+ safe_length
			* float(
				chunks.size()
				- 1
				- safe_behind_count
			)
		)

		for index: int in range(chunks.size()):
			var chunk: Node3D = chunks[index]

			if not _is_valid_chunk(chunk):
				continue

			chunk.position.z = (
				first_z
				- float(index) * safe_length
			)


# ============================================================
# BRAKING API
# ============================================================

## MenuController calls this during the braking sequence.
func smooth_stop(duration: float = 0.8) -> void:
	_cancel_stop_tween()

	var stop_duration: float = maxf(
		duration,
		0.0
	)

	if stop_duration <= 0.0:
		stop_immediate()
		return

	if is_zero_approx(current_speed):
		active = false
		return

	active = true

	var starting_speed: float = current_speed

	stop_tween = create_tween()

	stop_tween.tween_method(
		_set_current_speed,
		starting_speed,
		0.0,
		stop_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	await stop_tween.finished

	current_speed = 0.0
	active = false
	stop_tween = null


func stop_immediate() -> void:
	_cancel_stop_tween()

	current_speed = 0.0
	active = false


func resume_loop() -> void:
	_cancel_stop_tween()

	current_speed = absf(movement_speed)
	active = not is_zero_approx(current_speed)


func set_loop_speed(new_speed: float) -> void:
	_cancel_stop_tween()

	movement_speed = absf(new_speed)
	current_speed = movement_speed
	active = not is_zero_approx(current_speed)


func _set_current_speed(new_speed: float) -> void:
	current_speed = maxf(
		new_speed,
		0.0
	)


func _cancel_stop_tween() -> void:
	if stop_tween == null:
		return

	if stop_tween.is_valid():
		stop_tween.kill()

	stop_tween = null


# ============================================================
# VALIDATION
# ============================================================

func _validate_setup() -> void:
	if chunks.is_empty():
		push_error(
			"MenuSceneryLoop: No direct child nodes beginning "
			+ "with '%s' were found."
			% chunk_name_prefix
		)
		return

	if chunks.size() < 4:
		push_warning(
			"MenuSceneryLoop: Only %d chunks were found. "
			+ "Use 5 for the long camera cutscene."
			% chunks.size()
		)

	if chunk_length <= 0.0:
		push_error(
			"MenuSceneryLoop: Chunk Length must be above zero."
		)

	if chunks_behind_camera >= chunks.size():
		push_warning(
			"MenuSceneryLoop: Chunks Behind Camera leaves "
			+ "no chunks ahead of the camera."
		)


func _print_summary() -> void:
	var ahead_count: int = maxi(
		chunks.size() - chunks_behind_camera,
		0
	)

	print(
		"MenuSceneryLoop: ",
		chunks.size(),
		" pooled chunks, ",
		ahead_count,
		" camera/current-or-ahead, ",
		chunks_behind_camera,
		" behind, speed ",
		current_speed,
		", reference Z ",
		reference_z,
		"."
	)
