@tool
extends Node3D

@export var stair_size: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var num_stairs: int = 10
@export var generate_ramp_collision: bool = true

@export var ramp_surface_epsilon: float = 0.1
@export var ramp_top_surface_offset: float = 0.01
@export var ramp_front_extension: float = 0.20
@export var ramp_top_extension: float = 0.00
@export var ramp_thickness: float = 0.12

var _cur_stair_size: Vector3 = Vector3.ZERO
var _cur_num_stairs: int = -1
var _cur_generate_ramp_collision: bool = false
var _cur_ramp_surface_epsilon: float = -1.0
var _cur_ramp_top_surface_offset: float = -1.0
var _cur_ramp_front_extension: float = -1.0
var _cur_ramp_top_extension: float = -1.0
var _cur_ramp_thickness: float = -1.0


func _ready() -> void:
	make_stairs()


func make_stairs() -> void:
	num_stairs = clampi(num_stairs, 0, 999)
	ramp_surface_epsilon = maxf(ramp_surface_epsilon, 0.0)
	ramp_front_extension = maxf(ramp_front_extension, 0.0)
	ramp_top_extension = maxf(ramp_top_extension, 0.0)
	ramp_thickness = maxf(ramp_thickness, 0.02)

	var base_csg: CSGBox3D = get_node_or_null("VisualCSG/StairBaseCSG") as CSGBox3D
	var stairs_poly: CSGPolygon3D = get_node_or_null("VisualCSG/StairBaseCSG/StairsSubtractCSG") as CSGPolygon3D
	var ramp_body: StaticBody3D = get_node_or_null("RampBody") as StaticBody3D
	var ramp_collision: CollisionShape3D = get_node_or_null("RampBody/RampCollision") as CollisionShape3D

	if base_csg == null:
		push_warning("Stairs: missing child node 'VisualCSG/StairBaseCSG'.")
		return

	if stairs_poly == null:
		push_warning("Stairs: missing child node 'VisualCSG/StairBaseCSG/StairsSubtractCSG'.")
		return

	if ramp_body == null or ramp_collision == null:
		push_warning("Stairs: missing 'RampBody/RampCollision'.")
		return

	base_csg.size = stair_size
	base_csg.use_collision = false
	stairs_poly.use_collision = false

	var point_arr: PackedVector2Array = PackedVector2Array()

	if num_stairs == 0:
		point_arr.append(Vector2(stair_size.x, stair_size.y))
		point_arr.append(Vector2(0.0, stair_size.y))
		point_arr.append(Vector2(0.0, 0.0))
	else:
		var step_height: float = stair_size.y / float(num_stairs)
		var step_width: float = stair_size.x / float(num_stairs)

		for i in range(num_stairs - 1):
			point_arr.append(Vector2(i * step_width, (i + 1) * step_height))
			point_arr.append(Vector2((i + 1) * step_width, (i + 1) * step_height))

		point_arr.append(Vector2(stair_size.x - step_width, stair_size.y))
		point_arr.append(Vector2(0.0, stair_size.y))

	stairs_poly.polygon = point_arr
	stairs_poly.depth = stair_size.z
	stairs_poly.position = Vector3(-stair_size.x / 2.0, -stair_size.y / 2.0, stair_size.z / 2.0)

	_update_ramp_collision(ramp_body, ramp_collision)

	_cur_stair_size = stair_size
	_cur_num_stairs = num_stairs
	_cur_generate_ramp_collision = generate_ramp_collision
	_cur_ramp_surface_epsilon = ramp_surface_epsilon
	_cur_ramp_top_surface_offset = ramp_top_surface_offset
	_cur_ramp_front_extension = ramp_front_extension
	_cur_ramp_top_extension = ramp_top_extension
	_cur_ramp_thickness = ramp_thickness


func _update_ramp_collision(ramp_body: StaticBody3D, ramp_collision: CollisionShape3D) -> void:
	ramp_body.position = Vector3.ZERO
	ramp_body.rotation = Vector3.ZERO
	ramp_collision.disabled = not generate_ramp_collision

	if not generate_ramp_collision:
		return

	var box_shape: BoxShape3D = ramp_collision.shape as BoxShape3D
	if box_shape == null:
		box_shape = BoxShape3D.new()
		ramp_collision.shape = box_shape

	var half_x: float = stair_size.x / 2.0
	var half_y: float = stair_size.y / 2.0

	var base_start: Vector2 = Vector2(
		-half_x,
		-half_y + ramp_surface_epsilon
	)

	var base_end: Vector2 = Vector2(
		half_x,
		half_y + ramp_top_surface_offset
	)

	var surface_start: Vector2 = base_start
	var surface_end: Vector2 = base_end

	if ramp_front_extension > 0.0:
		var start_slope: float = 0.0
		if not is_zero_approx(base_end.x - base_start.x):
			start_slope = (base_end.y - base_start.y) / (base_end.x - base_start.x)

		surface_start.x -= ramp_front_extension
		surface_start.y -= start_slope * ramp_front_extension

	if ramp_top_extension > 0.0:
		surface_end.x += ramp_top_extension

	var ramp_vector: Vector2 = surface_end - surface_start
	var ramp_length: float = ramp_vector.length()
	var ramp_angle: float = atan2(ramp_vector.y, ramp_vector.x)

	box_shape.size = Vector3(ramp_length, ramp_thickness, stair_size.z)

	var surface_mid: Vector2 = (surface_start + surface_end) * 0.5
	var surface_normal: Vector2 = Vector2(-sin(ramp_angle), cos(ramp_angle))
	var box_center: Vector2 = surface_mid - surface_normal * (ramp_thickness * 0.5)

	ramp_collision.position = Vector3(box_center.x, box_center.y, 0.0)
	ramp_collision.rotation = Vector3(0.0, 0.0, ramp_angle)


func _process(_delta: float) -> void:
	if _cur_stair_size != stair_size \
	or _cur_num_stairs != num_stairs \
	or _cur_generate_ramp_collision != generate_ramp_collision \
	or not is_equal_approx(_cur_ramp_surface_epsilon, ramp_surface_epsilon) \
	or not is_equal_approx(_cur_ramp_top_surface_offset, ramp_top_surface_offset) \
	or not is_equal_approx(_cur_ramp_front_extension, ramp_front_extension) \
	or not is_equal_approx(_cur_ramp_top_extension, ramp_top_extension) \
	or not is_equal_approx(_cur_ramp_thickness, ramp_thickness):
		make_stairs()
