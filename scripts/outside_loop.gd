extends Node3D
class_name OutsideTrainLoop


@export_category("Movement")

@export var movement_speed: float = 5.0
@export var loop_length: float = 16.0
@export var active: bool = true


@export_category("Runtime Chunk Pool")

# Uses a predictable, small number of chunks instead of calculating
# a large amount from the total upstream/downstream distance.
@export var use_fixed_chunk_count: bool = true

# Six chunks cover 96 metres when Loop Length is 16.
@export_range(2, 12, 1)
var fixed_chunks_per_group: int = 6

# Starting arrangement for positive movement:
# -48, -32, -16, 0, 16, 32
@export var upstream_start_distance: float = 48.0

# Chunks wrap after passing this position.
@export var downstream_despawn_distance: float = 32.0

# Only used when Use Fixed Chunk Count is disabled.
@export var minimum_chunks_per_group: int = 6

# Runtime copies are scenery controlled by this script.
# They normally do not need their own processing.
@export var disable_runtime_copy_processing: bool = true


@export_category("Chunk Visibility")

# Only the closest chunks in each group are rendered.
# The remaining chunks continue moving invisibly and are ready to wrap.
@export var limit_visible_chunks: bool = true

# Four visible chunks cover approximately 64 metres.
# Increase this to 5 if the fog does not hide transitions enough.
@export_range(1, 12, 1)
var visible_chunks_per_group: int = 4

# We do not need to recalculate visibility every frame.
@export_range(1, 30, 1)
var visibility_update_every_frames: int = 3

@export var print_runtime_summary: bool = true


@export_category("Stop Alignment")

@export var use_stop_alignment_marker: bool = true
@export var stop_alignment_marker_path: NodePath = ^""
@export var stop_alignment_marker_name: String = "StopGapMarker"
@export var stop_target_global_z: float = -5.2

# Small fine tuning only.
# Example: -0.5, 0.0, 0.5.
@export var stop_alignment_offset: float = 0.0


var chunk_groups: Dictionary = {}

var current_movement_speed: float = 0.0
var stop_request_id: int = 0

var visibility_frame_counter: int = 0
var visibility_camera_z: float = 0.0


func _ready() -> void:
	current_movement_speed = movement_speed

	_collect_chunk_groups()
	_expand_runtime_chunks()
	_arrange_chunks()

	call_deferred("_finish_runtime_setup")


func _process(delta: float) -> void:
	if active and not is_zero_approx(current_movement_speed):
		_apply_chunk_displacement(current_movement_speed * delta)

	_update_visibility_timer()


func _finish_runtime_setup() -> void:
	_update_chunk_visibility()

	if print_runtime_summary:
		_print_runtime_summary()


func get_alignment_wait_for_smooth_stop(
	stop_duration: float
) -> float:
	if not use_stop_alignment_marker:
		return 0.0

	var speed: float = current_movement_speed

	if is_zero_approx(speed):
		return 0.0

	var markers: Array[Node3D] = _get_stop_alignment_markers()

	if markers.is_empty():
		push_warning(
			"OutsideTrainLoop: No StopGapMarker found. "
			+ "Alignment wait will be 0."
		)
		return 0.0

	var duration: float = maxf(stop_duration, 0.0)
	var slowdown_distance: float = speed * duration * 0.5

	var final_target_z: float = (
		stop_target_global_z
		+ stop_alignment_offset
	)

	var required_marker_z_when_slowdown_starts: float = (
		final_target_z
		- slowdown_distance
	)

	var best_wait: float = INF
	var found_valid_marker: bool = false

	for marker: Node3D in markers:
		if marker == null or not is_instance_valid(marker):
			continue

		var marker_z: float = marker.global_position.z

		var distance_to_slowdown_start: float = (
			required_marker_z_when_slowdown_starts
			- marker_z
		)

		if speed > 0.0:
			if distance_to_slowdown_start < 0.0:
				continue

			var wait_time: float = (
				distance_to_slowdown_start
				/ speed
			)

			if wait_time < best_wait:
				best_wait = wait_time
				found_valid_marker = true
		else:
			if distance_to_slowdown_start > 0.0:
				continue

			var negative_wait_time: float = (
				distance_to_slowdown_start
				/ speed
			)

			if negative_wait_time < best_wait:
				best_wait = negative_wait_time
				found_valid_marker = true

	if not found_valid_marker:
		push_warning(
			"OutsideTrainLoop: No valid StopGapMarker behind "
			+ "slowdown start point. Alignment wait will be 0."
		)
		return 0.0

	return maxf(best_wait, 0.0)


func smooth_stop(duration: float = 4.0) -> void:
	stop_request_id += 1
	var my_stop_request_id: int = stop_request_id

	var stop_duration: float = maxf(duration, 0.0)
	var start_speed: float = current_movement_speed

	if stop_duration <= 0.0 or is_zero_approx(start_speed):
		current_movement_speed = 0.0
		active = false
		return

	active = false

	var elapsed: float = 0.0

	while elapsed < stop_duration:
		await get_tree().process_frame

		if my_stop_request_id != stop_request_id:
			return

		var delta: float = get_process_delta_time()
		var previous_elapsed: float = elapsed

		elapsed = minf(
			elapsed + delta,
			stop_duration
		)

		var previous_t: float = (
			previous_elapsed
			/ stop_duration
		)

		var current_t: float = (
			elapsed
			/ stop_duration
		)

		# Linear deceleration distance curve:
		# distance factor = t - 0.5t².
		var previous_distance_factor: float = (
			previous_t
			- (0.5 * previous_t * previous_t)
		)

		var current_distance_factor: float = (
			current_t
			- (0.5 * current_t * current_t)
		)

		var displacement: float = (
			start_speed
			* stop_duration
			* (
				current_distance_factor
				- previous_distance_factor
			)
		)

		_apply_chunk_displacement(displacement)

		current_movement_speed = lerpf(
			start_speed,
			0.0,
			current_t
		)

	current_movement_speed = 0.0
	active = false

	_update_chunk_visibility()


func resume_loop() -> void:
	stop_request_id += 1

	current_movement_speed = movement_speed
	active = true


func set_loop_speed(new_speed: float) -> void:
	stop_request_id += 1

	movement_speed = new_speed
	current_movement_speed = new_speed
	active = not is_zero_approx(new_speed)


func refresh_chunk_visibility() -> void:
	_update_chunk_visibility()


func _get_stop_alignment_markers() -> Array[Node3D]:
	var markers: Array[Node3D] = []

	if not str(stop_alignment_marker_path).is_empty():
		var marker_from_path: Node3D = get_node_or_null(
			stop_alignment_marker_path
		) as Node3D

		if marker_from_path != null:
			markers.append(marker_from_path)

	# Also search runtime copies.
	# The visible entrance can be on a copied RightTreesB.
	_find_markers_by_name(
		self,
		stop_alignment_marker_name,
		markers
	)

	return markers


func _find_markers_by_name(
	node: Node,
	marker_name: String,
	results: Array[Node3D]
) -> void:
	for child: Node in node.get_children():
		var child_node_3d: Node3D = child as Node3D

		if (
			child_node_3d != null
			and str(child_node_3d.name) == marker_name
		):
			if not results.has(child_node_3d):
				results.append(child_node_3d)

		_find_markers_by_name(
			child,
			marker_name,
			results
		)


func _apply_chunk_displacement(displacement: float) -> void:
	if is_zero_approx(displacement):
		return

	for group_key: Variant in chunk_groups.keys():
		var chunks: Array = chunk_groups[group_key]

		if chunks.is_empty():
			continue

		for chunk_obj: Variant in chunks:
			var chunk: Node3D = chunk_obj as Node3D

			if chunk == null:
				continue

			chunk.position.z += displacement

		_wrap_chunks(chunks, displacement)


func _wrap_chunks(
	chunks: Array,
	displacement: float
) -> void:
	if is_zero_approx(loop_length):
		return

	if displacement > 0.0:
		var wrapped: bool = true

		while wrapped:
			wrapped = false

			for chunk_obj: Variant in chunks:
				var chunk: Node3D = chunk_obj as Node3D

				if chunk == null:
					continue

				if (
					chunk.position.z
					> downstream_despawn_distance
				):
					chunk.position.z = (
						_get_backmost_z(chunks)
						- loop_length
					)

					wrapped = true

	elif displacement < 0.0:
		var wrapped_negative: bool = true

		while wrapped_negative:
			wrapped_negative = false

			for chunk_obj: Variant in chunks:
				var chunk_negative: Node3D = (
					chunk_obj as Node3D
				)

				if chunk_negative == null:
					continue

				if (
					chunk_negative.position.z
					< -downstream_despawn_distance
				):
					chunk_negative.position.z = (
						_get_frontmost_z(chunks)
						+ loop_length
					)

					wrapped_negative = true


func _collect_chunk_groups() -> void:
	chunk_groups.clear()

	for child: Node in get_children():
		var chunk: Node3D = child as Node3D

		if chunk == null:
			continue

		if str(chunk.name).contains("RuntimeCopy"):
			continue

		var group_key: String = _get_group_key(chunk.name)

		if not chunk_groups.has(group_key):
			chunk_groups[group_key] = []

		chunk_groups[group_key].append(chunk)

	for group_key: Variant in chunk_groups.keys():
		var chunks: Array = chunk_groups[group_key]
		chunks.sort_custom(_sort_chunks_by_name)


func _sort_chunks_by_name(
	a: Variant,
	b: Variant
) -> bool:
	var node_a: Node = a as Node
	var node_b: Node = b as Node

	if node_a == null or node_b == null:
		return false

	return str(node_a.name) < str(node_b.name)


func _expand_runtime_chunks() -> void:
	minimum_chunks_per_group = maxi(
		minimum_chunks_per_group,
		2
	)

	fixed_chunks_per_group = maxi(
		fixed_chunks_per_group,
		2
	)

	for group_key: Variant in chunk_groups.keys():
		var chunks: Array = chunk_groups[group_key]

		if chunks.is_empty():
			continue

		var original_pattern: Array[Node3D] = []

		for chunk_obj: Variant in chunks:
			var original_chunk: Node3D = (
				chunk_obj as Node3D
			)

			if original_chunk != null:
				original_pattern.append(original_chunk)

		if original_pattern.is_empty():
			continue

		var required_count: int = _get_required_chunk_count(
			original_pattern.size()
		)

		var copy_index: int = 0

		while chunks.size() < required_count:
			var pattern_index: int = (
				chunks.size()
				% original_pattern.size()
			)

			var source_chunk: Node3D = (
				original_pattern[pattern_index]
			)

			if source_chunk == null:
				break

			var copied_node: Node = source_chunk.duplicate()
			var copied_chunk: Node3D = copied_node as Node3D

			if copied_chunk == null:
				break

			copied_chunk.name = "%sRuntimeCopy%d" % [
				str(source_chunk.name),
				copy_index
			]

			add_child(copied_chunk)

			if disable_runtime_copy_processing:
				copied_chunk.process_mode = (
					Node.PROCESS_MODE_DISABLED
				)

			chunks.append(copied_chunk)
			copy_index += 1


func _arrange_chunks() -> void:
	for group_key: Variant in chunk_groups.keys():
		var chunks: Array = chunk_groups[group_key]

		if chunks.is_empty():
			continue

		for i: int in range(chunks.size()):
			var chunk: Node3D = chunks[i] as Node3D

			if chunk == null:
				continue

			if movement_speed >= 0.0:
				chunk.position.z = (
					-upstream_start_distance
					+ (float(i) * loop_length)
				)
			else:
				chunk.position.z = (
					upstream_start_distance
					- (float(i) * loop_length)
				)


func _get_required_chunk_count(
	original_pattern_size: int
) -> int:
	if use_fixed_chunk_count:
		return maxi(
			fixed_chunks_per_group,
			original_pattern_size
		)

	var safe_loop_length: float = maxf(
		absf(loop_length),
		0.001
	)

	var total_distance: float = (
		upstream_start_distance
		+ downstream_despawn_distance
	)

	var needed_count: int = int(
		ceil(total_distance / safe_loop_length)
	) + 1

	return maxi(
		maxi(
			needed_count,
			minimum_chunks_per_group
		),
		original_pattern_size
	)


func _update_visibility_timer() -> void:
	if not limit_visible_chunks:
		return

	visibility_frame_counter += 1

	if (
		visibility_frame_counter
		< visibility_update_every_frames
	):
		return

	visibility_frame_counter = 0
	_update_chunk_visibility()


func _update_chunk_visibility() -> void:
	if not limit_visible_chunks:
		_set_all_chunks_visible()
		return

	var current_camera: Camera3D = (
		get_viewport().get_camera_3d()
	)

	if current_camera == null:
		return

	visibility_camera_z = current_camera.global_position.z

	for group_key: Variant in chunk_groups.keys():
		var chunks: Array = chunk_groups[group_key]

		if chunks.is_empty():
			continue

		var ordered_chunks: Array = chunks.duplicate()
		ordered_chunks.sort_custom(
			_sort_chunks_by_camera_distance
		)

		var allowed_visible_count: int = mini(
			visible_chunks_per_group,
			ordered_chunks.size()
		)

		for i: int in range(ordered_chunks.size()):
			var chunk: Node3D = (
				ordered_chunks[i] as Node3D
			)

			if chunk == null:
				continue

			chunk.visible = i < allowed_visible_count


func _sort_chunks_by_camera_distance(
	a: Variant,
	b: Variant
) -> bool:
	var chunk_a: Node3D = a as Node3D
	var chunk_b: Node3D = b as Node3D

	if chunk_a == null or chunk_b == null:
		return false

	var distance_a: float = absf(
		chunk_a.global_position.z
		- visibility_camera_z
	)

	var distance_b: float = absf(
		chunk_b.global_position.z
		- visibility_camera_z
	)

	return distance_a < distance_b


func _set_all_chunks_visible() -> void:
	for group_key: Variant in chunk_groups.keys():
		var chunks: Array = chunk_groups[group_key]

		for chunk_obj: Variant in chunks:
			var chunk: Node3D = chunk_obj as Node3D

			if chunk != null:
				chunk.visible = true


func _print_runtime_summary() -> void:
	var total_chunk_count: int = 0
	var currently_visible_count: int = 0

	for group_key: Variant in chunk_groups.keys():
		var chunks: Array = chunk_groups[group_key]

		total_chunk_count += chunks.size()

		for chunk_obj: Variant in chunks:
			var chunk: Node3D = chunk_obj as Node3D

			if chunk != null and chunk.visible:
				currently_visible_count += 1

	print(
		"OutsideTrainLoop: ",
		chunk_groups.size(),
		" groups, ",
		total_chunk_count,
		" pooled chunks, ",
		currently_visible_count,
		" currently visible chunks."
	)


func _get_backmost_z(chunks: Array) -> float:
	var backmost_z: float = INF

	for chunk_obj: Variant in chunks:
		var chunk: Node3D = chunk_obj as Node3D

		if chunk == null:
			continue

		backmost_z = minf(
			backmost_z,
			chunk.position.z
		)

	return backmost_z


func _get_frontmost_z(chunks: Array) -> float:
	var frontmost_z: float = -INF

	for chunk_obj: Variant in chunks:
		var chunk: Node3D = chunk_obj as Node3D

		if chunk == null:
			continue

		frontmost_z = maxf(
			frontmost_z,
			chunk.position.z
		)

	return frontmost_z


func _get_group_key(node_name: StringName) -> String:
	var text: String = str(node_name)

	if text.length() <= 1:
		return text

	var last_char: String = text.substr(
		text.length() - 1,
		1
	)

	if (
		last_char == "A"
		or last_char == "B"
		or last_char == "C"
		or last_char == "D"
	):
		return text.substr(
			0,
			text.length() - 1
		)

	return text
