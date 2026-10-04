@tool
extends RefCounted
class_name OverlookBuilder

## Builds the scenic overlook at the end of the paths: it paints dirt that
## connects the path ends to a small plaza, then saves a scene with a curved
## fence along the edge facing the city and a bench looking out over it.
##
## The scene stores world-space positions (heights are read from the terrain),
## so instance it at the scene origin. Run it again after changing the terrain.

const FENCE_SCENE_PATH: String = (
	"res://assets/models/wooden_structures/barbed_fence_big_no_angle/"
	+ "barbed_fence_big_no_angle_collision.tscn"
)
const BENCH_SCENE_PATH: String = (
	"res://assets/models/wooden_structures/bench/bench.glb"
)

## The fence origin sits at mid-height, so it is lifted by half its height.
const FENCE_HALF_HEIGHT: float = 0.64
const FENCE_PIECE_LENGTH: float = 1.77

## World XZ of the viewpoint, and the direction toward the city.
var origin: Vector2 = Vector2(168.0, 27.0)
var direction: Vector2 = Vector2(0.686, -0.727).normalized()

## Last dirt cell of each path that should lead to the overlook.
var path_ends: Array[Vector2] = [Vector2(148.0, 18.0), Vector2(188.0, 36.0)]

var dirt_texture_id: int = 1

## Plaza ellipse: metres along the view direction and across it, and how far
## its centre sits toward the city from the viewpoint.
var plaza_along: float = 6.5
var plaza_across: float = 7.5
var plaza_center_offset: float = 1.5

## Fence line: distance from the viewpoint, half length, and the radius of its
## gentle curve (larger is flatter).
var fence_distance: float = 8.2
var fence_half_span: float = 10.5
var fence_curve_radius: float = 22.0

## Bench distance from the viewpoint toward the city.
var bench_distance: float = 5.0

## The fence and bench are meant for level ground. The terrain is flattened in
## a box spanning these distances along the view direction from the viewpoint
## and half this width across it, then blends back to its natural shape over
## flatten_blend metres so there is no visible step.
var flat_along_min: float = -6.0
var flat_along_max: float = 9.8
var flat_half_width: float = 11.5
var flatten_blend: float = 9.0

var path_half_width: float = 1.2
var seed_value: int = 77

var _terrain: Terrain3D = null
var _data: Terrain3DData = null
var _noise: FastNoiseLite = FastNoiseLite.new()
var _control_value: int = 0
var _painted: int = 0


## Paints dirt for the connecting paths and the plaza. Returns painted cells.
func paint_paths(terrain: Terrain3D) -> int:
	_terrain = terrain
	_data = terrain.data
	_painted = 0
	_noise.seed = seed_value
	_noise.frequency = 0.35

	if not _find_reference_control():
		push_error("OverlookBuilder: no dirt found near the path ends to copy.")
		return 0

	for end_point: Vector2 in path_ends:
		_paint_curve(end_point, origin)

	_paint_plaza()
	_mark_regions_modified(Terrain3DRegion.TYPE_CONTROL)
	return _painted


## Levels the ground under the plaza, bench and fence, blending smoothly back
## into the surrounding slope. Run it before generating vegetation and before
## build_scene, since both read the terrain height. Returns the target height.
func flatten_ground(terrain: Terrain3D) -> float:
	_terrain = terrain
	_data = terrain.data

	var across: Vector2 = Vector2(-direction.y, direction.x)
	var center_along: float = (flat_along_min + flat_along_max) * 0.5
	var half_along: float = (flat_along_max - flat_along_min) * 0.5
	var reach: int = int(ceilf(
		maxf(flat_along_max - flat_along_min, flat_half_width * 2.0)
		+ flatten_blend * 2.0
	))

	# Aim for the average height of the level area, so little earth moves.
	var total: float = 0.0
	var count: int = 0
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: Vector2 = Vector2(floorf(origin.x) + dx, floorf(origin.y) + dz)
			if _box_distance(cell, across, center_along, half_along) > 0.0:
				continue

			var height: float = _data.get_height(Vector3(cell.x, 0.0, cell.y))
			if not is_nan(height):
				total += height
				count += 1

	if count == 0:
		return NAN

	var target: float = total / float(count)

	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: Vector2 = Vector2(floorf(origin.x) + dx, floorf(origin.y) + dz)
			var distance: float = _box_distance(cell, across, center_along, half_along)
			if distance >= flatten_blend:
				continue

			var point: Vector3 = Vector3(cell.x, 0.0, cell.y)
			var current: float = _data.get_height(point)
			if is_nan(current):
				continue

			var weight: float = 1.0 - smoothstep(0.0, flatten_blend, distance)
			_data.set_height(point, lerpf(current, target, weight))

	_mark_regions_modified(Terrain3DRegion.TYPE_HEIGHT)
	_data.calc_height_range(true)
	return target


## Builds and saves the fence and bench scene.
func build_scene(terrain: Terrain3D, save_path: String) -> Error:
	_terrain = terrain
	_data = terrain.data

	var fence_scene: PackedScene = load(FENCE_SCENE_PATH) as PackedScene
	var bench_scene: PackedScene = load(BENCH_SCENE_PATH) as PackedScene
	if fence_scene == null or bench_scene == null:
		push_error("OverlookBuilder: fence or bench scene could not be loaded.")
		return ERR_FILE_NOT_FOUND

	var root: Node3D = Node3D.new()
	root.name = "Overlook"

	var fence_root: Node3D = Node3D.new()
	fence_root.name = "Fence"
	root.add_child(fence_root)
	fence_root.owner = root

	var across: Vector2 = Vector2(-direction.y, direction.x)
	var piece_count: int = int(ceilf((fence_half_span * 2.0) / FENCE_PIECE_LENGTH))
	for i: int in range(piece_count):
		var s: float = -fence_half_span + (float(i) + 0.5) * FENCE_PIECE_LENGTH
		var center: Vector2 = _fence_point(s, across)
		var ahead: Vector2 = _fence_point(s + 0.5, across)
		var behind: Vector2 = _fence_point(s - 0.5, across)
		var tangent: Vector2 = (ahead - behind).normalized()
		var height: float = _data.get_height(Vector3(center.x, 0.0, center.y))
		if is_nan(height):
			continue

		var piece: Node3D = fence_scene.instantiate() as Node3D
		piece.name = "FencePiece%02d" % i
		fence_root.add_child(piece)
		piece.owner = root
		piece.transform = Transform3D(
			Basis(Vector3.UP, atan2(tangent.x, tangent.y)),
			Vector3(center.x, height + FENCE_HALF_HEIGHT, center.y)
		)

	var bench_position: Vector2 = origin + direction * bench_distance
	var bench_height: float = _data.get_height(
		Vector3(bench_position.x, 0.0, bench_position.y)
	)
	var bench_body: StaticBody3D = StaticBody3D.new()
	bench_body.name = "Bench"
	root.add_child(bench_body)
	bench_body.owner = root

	# The bench seat faces local -X, so turn it until -X points at the city.
	bench_body.transform = Transform3D(
		Basis(Vector3.UP, atan2(direction.y, -direction.x)),
		Vector3(bench_position.x, bench_height, bench_position.y)
	)

	var bench_visual: Node3D = bench_scene.instantiate() as Node3D
	bench_visual.name = "Visual"
	bench_body.add_child(bench_visual)
	bench_visual.owner = root

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.1, 1.0, 2.5)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	collision.position = Vector3(0.08, 0.5, 0.0)
	bench_body.add_child(collision)
	collision.owner = root

	var packed: PackedScene = PackedScene.new()
	var pack_result: Error = packed.pack(root)
	root.free()
	if pack_result != OK:
		return pack_result

	return ResourceSaver.save(packed, save_path)


# ============================================================
# FENCE
# ============================================================

## Point on the fence curve at signed distance s along the edge. The ends bend
## back toward the viewpoint, so the fence wraps the plaza.
func _fence_point(s: float, across: Vector2) -> Vector2:
	var bend: float = (s * s) / (2.0 * fence_curve_radius)
	return origin + direction * (fence_distance - bend) + across * s


# ============================================================
# PAINTING
# ============================================================

func _find_reference_control() -> bool:
	for end_point: Vector2 in path_ends:
		for radius: int in range(0, 6):
			for dz: int in range(-radius, radius + 1):
				for dx: int in range(-radius, radius + 1):
					var point: Vector3 = Vector3(end_point.x + dx, 0.0, end_point.y + dz)
					if _is_dirt(point):
						_control_value = _data.get_control(point)
						return true

	return false


func _is_dirt(point: Vector3) -> bool:
	if is_nan(_data.get_height(point)):
		return false

	# Same rule as the vegetation generator: solid dirt only, not soft blends.
	var ids: Vector3 = _data.get_texture_id(point)
	if ids.z < 0.5:
		return int(ids.x) == dirt_texture_id

	return int(ids.y) == dirt_texture_id and ids.z > 0.85


func _paint_cell(x: float, z: float) -> void:
	var point: Vector3 = Vector3(x, 0.0, z)
	if is_nan(_data.get_height(point)):
		return

	_data.set_control(point, _control_value)
	_painted += 1


func _paint_disc(center: Vector2, radius: float) -> void:
	var reach: int = int(ceilf(radius))
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			if Vector2(dx, dz).length() <= radius:
				_paint_cell(floorf(center.x) + dx, floorf(center.y) + dz)


## A slightly bent path from an existing path end to the viewpoint.
func _paint_curve(start: Vector2, finish: Vector2) -> void:
	var middle: Vector2 = (start + finish) * 0.5
	var along: Vector2 = (finish - start)
	var side: Vector2 = Vector2(-along.y, along.x).normalized()
	var bend: float = clampf(along.length() * 0.12, 1.0, 4.0)
	var control: Vector2 = middle + side * bend

	var steps: int = int(ceilf(along.length() * 2.0))
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var point: Vector2 = (
			start * (1.0 - t) * (1.0 - t)
			+ control * 2.0 * (1.0 - t) * t
			+ finish * t * t
		)
		var wobble: float = _noise.get_noise_2d(point.x, point.y) * 0.3
		_paint_disc(point, path_half_width + wobble)


func _paint_plaza() -> void:
	var center: Vector2 = origin + direction * plaza_center_offset
	var across: Vector2 = Vector2(-direction.y, direction.x)
	var reach: int = int(ceilf(maxf(plaza_along, plaza_across))) + 2

	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var offset: Vector2 = Vector2(dx, dz)
			var u: float = offset.dot(direction) / plaza_along
			var v: float = offset.dot(across) / plaza_across
			var edge: float = 1.0 + _noise.get_noise_2d(
				center.x + dx,
				center.y + dz
			) * 0.12
			if u * u + v * v <= edge * edge:
				_paint_cell(floorf(center.x) + dx, floorf(center.y) + dz)


## Signed distance from a point to the level box (negative inside), in metres.
func _box_distance(
	cell: Vector2,
	across: Vector2,
	center_along: float,
	half_along: float
) -> float:
	var offset: Vector2 = cell - origin
	var q: Vector2 = Vector2(
		absf(offset.dot(direction) - center_along) - half_along,
		absf(offset.dot(across)) - flat_half_width
	)
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0)


func _mark_regions_modified(map_type: int) -> void:
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var span: float = maxf(plaza_along, plaza_across) + 40.0
	var low: Vector2 = Vector2(origin.x - span, origin.y - span)
	var high: Vector2 = Vector2(origin.x + span, origin.y + span)

	var x: float = low.x
	while x <= high.x + region_size:
		var z: float = low.y
		while z <= high.y + region_size:
			var region: Terrain3DRegion = _data.get_regionp(Vector3(x, 0.0, z))
			if region != null:
				region.set_modified(true)

			z += region_size

		x += region_size

	_data.update_maps(map_type, true, false)
