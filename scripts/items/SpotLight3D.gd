extends SpotLight3D

@export var required_item_id: String = "flashlight"
@export var flashlight_starts_on: bool = false
@export var flashlight_input_enabled: bool = true

@export var flicker_enabled: bool = false
@export var flicker_chance_percent: int = 10
@export var flicker_interval_min: float = 0.05
@export var flicker_interval_max: float = 0.2

# 0m = most centered
# 3m or more = default hand feel
@export var shift_reference_distance: float = 3.0

# Flashlight uses its own long probe
@export var probe_distance: float = 8.0
@export var probe_origin_offset: float = 0.05

@export var center_forward_offset: float = 0.08
@export var center_right_offset: float = 0.05
@export var center_down_offset: float = -0.04

@export var follow_speed: float = 12.0
@export var aim_follow_speed: float = 6.0
@export var distance_follow_speed: float = 8.0
@export var shift_follow_speed: float = 8.0

# Occlusion-aware correction
@export var occlusion_check_steps: int = 6
@export var beam_start_offset: float = 0.03
@export var beam_end_tolerance: float = 0.06

var flashlight_on: bool = true
var flicker_timer: float = 0.0
var flicker_forced_off: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var player: Node = null
var camera: Camera3D = null

# Store the flashlight's original position relative to the camera.
var original_camera_local_position: Vector3 = Vector3.ZERO
var has_camera_local_position: bool = false

var smoothed_distance: float = 0.0
var has_smoothed_distance: bool = false

var current_shift_t: float = 0.0
var has_shift_t: bool = false

var smoothed_aim_target: Vector3 = Vector3.ZERO
var has_smoothed_aim_target: bool = false

var ray_exclude_rids: Array[RID] = []

var probed_target_point: Vector3 = Vector3.ZERO
var probed_distance: float = 0.0


func _ready() -> void:
	rng.randomize()
	flashlight_on = flashlight_starts_on
	player = _find_player()

	_refresh_references()
	visible = false


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()
		_refresh_references()
	elif camera == null or not is_instance_valid(camera):
		_refresh_references()

	if camera != null and not has_camera_local_position:
		original_camera_local_position = camera.to_local(global_position)
		has_camera_local_position = true

	if _can_toggle_flashlight() and Input.is_action_just_pressed("flashlight"):
		flashlight_on = not flashlight_on

	_update_dynamic_flashlight(delta)

	if _should_emit_light():
		_update_flicker(delta)
	else:
		flicker_timer = 0.0
		flicker_forced_off = false
		visible = false


func set_flashlight_input_enabled(enabled: bool) -> void:
	flashlight_input_enabled = enabled

	if not flashlight_input_enabled:
		flashlight_on = false
		flicker_timer = 0.0
		flicker_forced_off = false
		visible = false


func _refresh_references() -> void:
	if player != null:
		camera = player.get_node_or_null("Head/Camera3D") as Camera3D
		_refresh_ray_excludes()

		if camera != null and not has_camera_local_position:
			original_camera_local_position = camera.to_local(global_position)
			has_camera_local_position = true
	else:
		camera = null
		ray_exclude_rids.clear()


func _update_dynamic_flashlight(delta: float) -> void:
	if camera == null or not has_camera_local_position:
		return

	_probe_focus_from_camera()

	var raw_distance: float = min(probed_distance, shift_reference_distance)

	if not has_smoothed_distance:
		smoothed_distance = raw_distance
		has_smoothed_distance = true
	else:
		var distance_weight: float = clamp(delta * distance_follow_speed, 0.0, 1.0)
		smoothed_distance = lerp(smoothed_distance, raw_distance, distance_weight)

	# Base shift from view distance:
	# 3m = 0 shift
	# 0m = 1 shift
	var base_shift_t: float = 1.0 - (smoothed_distance / max(shift_reference_distance, 0.001))
	base_shift_t = clamp(base_shift_t, 0.0, 1.0)

	var camera_forward: Vector3 = -camera.global_transform.basis.z
	var camera_right: Vector3 = camera.global_transform.basis.x
	var camera_up: Vector3 = camera.global_transform.basis.y

	# Default flashlight position rebuilt from camera space
	var default_pos: Vector3 = camera.to_global(original_camera_local_position)

	# Close-up centered position
	var centered_pos: Vector3 = (
		camera.global_position
		+ (camera_forward * center_forward_offset)
		+ (camera_right * center_right_offset)
		+ (camera_up * center_down_offset)
	)

	# Smart correction:
	# If the beam from the current/right-sided position to the looked-at point is blocked,
	# shift inward only as much as needed to clear the obstacle.
	var target_shift_t: float = _find_required_shift_for_clear_path(
		default_pos,
		centered_pos,
		base_shift_t,
		probed_target_point
	)

	if not has_shift_t:
		current_shift_t = target_shift_t
		has_shift_t = true
	else:
		var shift_weight: float = clamp(delta * shift_follow_speed, 0.0, 1.0)
		current_shift_t = lerp(current_shift_t, target_shift_t, shift_weight)

	var desired_pos: Vector3 = default_pos.lerp(centered_pos, current_shift_t)
	var pos_weight: float = clamp(delta * follow_speed, 0.0, 1.0)
	global_position = global_position.lerp(desired_pos, pos_weight)

	# Far away: aim more like a normal hand flashlight, roughly parallel to view
	# Close up / corrected: aim more at the exact camera probe hit point
	var far_aim_target: Vector3 = global_position + (camera_forward * max(probed_distance, 0.25))
	var near_aim_target: Vector3 = probed_target_point
	var desired_aim_target: Vector3 = far_aim_target.lerp(near_aim_target, current_shift_t)

	if not has_smoothed_aim_target:
		smoothed_aim_target = desired_aim_target
		has_smoothed_aim_target = true
	else:
		var aim_weight: float = clamp(delta * aim_follow_speed, 0.0, 1.0)
		smoothed_aim_target = smoothed_aim_target.lerp(desired_aim_target, aim_weight)

	if global_position.distance_squared_to(smoothed_aim_target) > 0.0001:
		look_at(smoothed_aim_target, Vector3.UP)


func _find_required_shift_for_clear_path(
	default_pos: Vector3,
	centered_pos: Vector3,
	base_shift_t: float,
	target_point: Vector3
) -> float:
	var start_pos: Vector3 = default_pos.lerp(centered_pos, base_shift_t)

	# If already clear, keep the normal distance-based shift
	if _is_light_path_clear(start_pos, target_point):
		return base_shift_t

	# Otherwise, search for the minimum extra shift needed to get a clear beam
	var steps: int = max(occlusion_check_steps, 1)

	for i in range(1, steps + 1):
		var step_t: float = float(i) / float(steps)
		var candidate_shift_t: float = lerp(base_shift_t, 1.0, step_t)
		var candidate_pos: Vector3 = default_pos.lerp(centered_pos, candidate_shift_t)

		if _is_light_path_clear(candidate_pos, target_point):
			return candidate_shift_t

	# If nothing cleared it, fall back to the most centered position
	return 1.0


func _is_light_path_clear(from_pos: Vector3, to_pos: Vector3) -> bool:
	var direction: Vector3 = to_pos - from_pos
	var total_distance: float = direction.length()

	if total_distance <= 0.001:
		return true

	var dir: Vector3 = direction / total_distance
	var ray_from: Vector3 = from_pos + (dir * beam_start_offset)
	var ray_to: Vector3 = to_pos

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = ray_exclude_rids

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return true

	var hit_pos: Vector3 = result["position"]
	return hit_pos.distance_to(to_pos) <= beam_end_tolerance


func _probe_focus_from_camera() -> void:
	if camera == null:
		probed_target_point = global_position + (-global_transform.basis.z * probe_distance)
		probed_distance = probe_distance
		return

	var from: Vector3 = camera.global_position + (-camera.global_transform.basis.z * probe_origin_offset)
	var to: Vector3 = from + (-camera.global_transform.basis.z * probe_distance)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = ray_exclude_rids

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		probed_target_point = to
		probed_distance = probe_distance
	else:
		probed_target_point = result["position"]
		probed_distance = from.distance_to(probed_target_point)


func _refresh_ray_excludes() -> void:
	ray_exclude_rids.clear()

	if player != null:
		_add_excluded_rids(player)


func _add_excluded_rids(node: Node) -> void:
	var collision_object: CollisionObject3D = node as CollisionObject3D
	if collision_object != null:
		ray_exclude_rids.append(collision_object.get_rid())

	for child in node.get_children():
		_add_excluded_rids(child)


func _update_flicker(delta: float) -> void:
	if not flicker_enabled:
		visible = true
		return

	flicker_timer -= delta

	if flicker_timer <= 0.0:
		flicker_forced_off = rng.randi_range(0, 100) < flicker_chance_percent
		flicker_timer = rng.randf_range(flicker_interval_min, flicker_interval_max)

	visible = not flicker_forced_off


func _should_emit_light() -> bool:
	return flashlight_input_enabled and _player_has_flashlight() and not _player_flashlight_blocked() and flashlight_on


func _can_toggle_flashlight() -> bool:
	return flashlight_input_enabled and _player_has_flashlight() and not _player_flashlight_blocked()


func _player_has_flashlight() -> bool:
	#if player != null and player.has_method("has_inventory_item"):
	#	return bool(player.call("has_inventory_item", required_item_id))
	#return false
	return true


func _player_flashlight_blocked() -> bool:
	if player != null and player.has_method("is_flashlight_blocked"):
		return bool(player.call("is_flashlight_blocked"))
	return false


func _find_player() -> Node:
	var current: Node = self

	while current != null:
		if current is CharacterBody3D:
			return current
		current = current.get_parent()

	return null
