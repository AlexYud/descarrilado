extends RefCounted

## One-off terrain edit: replaces the long loop of the south path between the
## unfinished house and the city overlook with a short, gently curved path.
##
## 1. Finds the old loop: every path cell (the same rule as the vegetation
##    generator) connected to the loop from where it leaves the house's area, up
##    to the overlook plaza.
## 2. Turns those cells back into forest floor (the ground painting of step 4 then
##    gives them their final look) and paints the new path as dirt.
## 3. Regrows the forest over the old loop and along the new path with the
##    vegetation generator (zone below; the house and its baked colliders sit
##    outside it).
## 4. Rebuilds the invisible forest walls (the caller saves them).
##
## Run it with `build_path_shortcut.gd` from a clean start (the terrain as it was
## before): it reads the old loop from the painted ground, so a second run would
## find nothing to remove and only repaint the new path.

const VegetationGenerator := preload("res://scripts/tools/forest_path_vegetation_generator.gd")
const BoundaryBuilder := preload("res://scripts/tools/forest_boundary_builder.gd")

const DIRT: int = 1
const TEX_FOREST_FLOOR: int = 2

## Path cells west of this x belong to the house and its baked colliders; the loop
## is only removed from here on, and the new path starts at the loop's westmost cell.
var keep_west_of_x: float = 84.0

## Where the loop is searched for first (a point on it, east of the house).
var loop_seed_point: Vector2 = Vector2(95.0, 75.0)

## The overlook plaza (see overlook_builder.gd): cells inside it, grown by
## `plaza_margin`, are not part of the loop.
var plaza_origin: Vector2 = Vector2(168.0, 27.0)
var plaza_direction: Vector2 = Vector2(0.686, -0.727)
var plaza_center_offset: float = 1.5
var plaza_along: float = 6.5
var plaza_across: float = 7.5
var plaza_margin: float = 1.2

## The new path, from the loop's westmost cell: bends through these points (a
## smooth curve) and ends inside the plaza on its side away from the city.
var waypoints: Array[Vector2] = [
	Vector2(104.0, 66.0),
	Vector2(125.0, 57.0),
	Vector2(145.0, 47.0),
	Vector2(158.0, 37.0),
	Vector2(165.5, 30.0),
]

var path_half_width: float = 1.2
var seed_value: int = 20261012

## Where the forest is regrown: the old loop and the new path.
var vegetation_zone: Rect2 = Rect2(83.0, 15.0, 125.0, 80.0)

## Only low plants grow in the overlook's view cone (same as generate_forest_vegetation.gd).
var view_origin: Vector2 = Vector2(168.0, 27.0)
var view_direction: Vector2 = Vector2(0.686, -0.727)
var view_half_angle: float = 38.0
var view_length: float = 70.0

var _terrain: Terrain3D = null
var _data: Terrain3DData = null
var _noise: FastNoiseLite = FastNoiseLite.new()
var _dirt_control: int = 0
var _start: Vector2 = Vector2.ZERO


## Returns {"old_cells", "painted", "length", "removed", "added", "boundaries"}.
func build(terrain: Terrain3D) -> Dictionary:
	_terrain = terrain
	_data = terrain.data
	_noise.seed = seed_value
	_noise.frequency = 0.15

	var old_cells: Dictionary = _find_old_loop()
	if old_cells.is_empty():
		push_error("PathShortcutBuilder: the old loop was not found (already removed?).")
		return {"old_cells": 0}

	_start = _westmost(old_cells)
	_dirt_control = _find_dirt_control(old_cells)

	_reset_old_loop(old_cells)
	var centerline: Array[Vector2] = _make_centerline()
	var painted: int = _paint_new_path(centerline)
	_mark_regions_modified()

	var generator = VegetationGenerator.new()
	generator.zone = vegetation_zone
	generator.seed_value = seed_value
	var corridors: Array[Dictionary] = [{
		"origin": view_origin,
		"direction": view_direction.normalized(),
		"half_angle": view_half_angle,
		"length": view_length,
	}]
	generator.view_corridors = corridors
	var planted: Dictionary = generator.generate(terrain)

	var walls = BoundaryBuilder.new()
	var boundaries: Dictionary = walls.build(terrain)

	var length: float = 0.0
	for i: int in range(1, centerline.size()):
		length += centerline[i].distance_to(centerline[i - 1])

	return {
		"old_cells": old_cells.size(),
		"painted": painted,
		"length": length,
		"start": _start,
		"removed": planted.get("removed", 0),
		"added": planted.get("added", 0),
		"boundaries": boundaries,
	}


# ============================================================
# THE OLD LOOP
# ============================================================

## Same rule as the vegetation generator's path test.
func _is_path(x: int, z: int) -> bool:
	var point: Vector3 = Vector3(x, 0.0, z)
	if is_nan(_data.get_height(point)) or _data.get_control_auto(point):
		return false

	var ids: Vector3 = _data.get_texture_id(point)
	if int(ids.x) == DIRT:
		return not (int(ids.y) == TEX_FOREST_FLOOR and ids.z > 0.5)

	return int(ids.y) == DIRT and ids.z > 0.85


func _in_plaza(x: int, z: int) -> bool:
	var direction: Vector2 = plaza_direction.normalized()
	var across: Vector2 = Vector2(-direction.y, direction.x)
	var offset: Vector2 = Vector2(x, z) - (plaza_origin + direction * plaza_center_offset)
	var u: float = offset.dot(direction) / (plaza_along + plaza_margin)
	var v: float = offset.dot(across) / (plaza_across + plaza_margin)
	return u * u + v * v <= 1.0


## Path cells reachable from the seed over gaps of up to three cells (the painted
## path is a dithered strip), outside the house's area and the plaza.
func _find_old_loop() -> Dictionary:
	var seed_cell: Vector2i = Vector2i(-1, -1)
	var best: float = INF
	for z: int in range(int(loop_seed_point.y) - 15, int(loop_seed_point.y) + 15):
		for x: int in range(int(loop_seed_point.x) - 10, int(loop_seed_point.x) + 15):
			if _is_path(x, z):
				var distance: float = Vector2(x, z).distance_to(loop_seed_point)
				if distance < best:
					best = distance
					seed_cell = Vector2i(x, z)

	var found: Dictionary = {}
	if seed_cell.x < 0:
		return found

	found[seed_cell] = true
	var queue: Array[Vector2i] = [seed_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dz: int in range(-3, 4):
			for dx: int in range(-3, 4):
				var neighbour: Vector2i = cell + Vector2i(dx, dz)
				if found.has(neighbour) or float(neighbour.x) < keep_west_of_x:
					continue
				if _in_plaza(neighbour.x, neighbour.y):
					continue
				if neighbour.x > 260 or neighbour.y < -60 or neighbour.y > 140:
					continue
				if _is_path(neighbour.x, neighbour.y):
					found[neighbour] = true
					queue.append(neighbour)

	return found


func _westmost(cells: Dictionary) -> Vector2:
	var best: Vector2i = Vector2i(100000, 0)
	for cell: Vector2i in cells:
		if cell.x < best.x:
			best = cell

	return Vector2(best.x + 0.5, best.y + 0.5)


## A control value of plain path (dirt base, no overlay) next to the loop's start.
func _find_dirt_control(cells: Dictionary) -> int:
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for cell: Vector2i in cells:
		var ids: Vector3 = _data.get_texture_id(Vector3(cell.x, 0.0, cell.y))
		if int(ids.x) == DIRT and ids.z < 0.15:
			var distance: float = Vector2(cell).distance_to(_start)
			if distance < best_distance:
				best_distance = distance
				best = cell

	if best.x < 0:
		best = cells.keys()[0]

	return _data.get_control(Vector3(best.x, 0.0, best.y))


## Gives every cell of the old loop the ground of the nearest forest next to it.
func _reset_old_loop(cells: Dictionary) -> void:
	var assigned: Dictionary = {}
	for cell: Vector2i in cells:
		assigned[cell] = _nearest_forest_control(cell, cells)

	for cell: Vector2i in assigned:
		_data.set_control(Vector3(cell.x, 0.0, cell.y), int(assigned[cell]))


func _nearest_forest_control(cell: Vector2i, loop: Dictionary) -> int:
	for radius: int in range(3, 12):
		for dz: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue

				var neighbour: Vector2i = cell + Vector2i(dx, dz)
				if loop.has(neighbour) or _is_path(neighbour.x, neighbour.y):
					continue

				var point: Vector3 = Vector3(neighbour.x, 0.0, neighbour.y)
				if is_nan(_data.get_height(point)) or _data.get_control_auto(point):
					continue

				var ids: Vector3 = _data.get_texture_id(point)
				if int(ids.x) == DIRT or int(ids.y) == DIRT:
					continue

				return _data.get_control(point)

	return _data.get_control(Vector3(cell.x, 0.0, cell.y))


# ============================================================
# THE NEW PATH
# ============================================================

func _make_centerline() -> Array[Vector2]:
	var points: Array[Vector2] = [_start]
	points.append_array(waypoints)

	var result: Array[Vector2] = []
	for i: int in range(points.size() - 1):
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		for step: int in 16:
			var t: float = float(step) / 16.0
			var t2: float = t * t
			var t3: float = t2 * t
			result.append(
				0.5 * (
					2.0 * p1
					+ (-p0 + p2) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
				)
			)

	result.append(points[points.size() - 1])
	return result


func _paint_new_path(centerline: Array[Vector2]) -> int:
	var painted: Dictionary = {}
	for i: int in range(centerline.size() - 1):
		var from_point: Vector2 = centerline[i]
		var to_point: Vector2 = centerline[i + 1]
		var steps: int = int(ceilf(from_point.distance_to(to_point) * 4.0))
		for step: int in range(steps + 1):
			var point: Vector2 = from_point.lerp(to_point, float(step) / float(maxi(steps, 1)))
			var radius: float = path_half_width + _noise.get_noise_2d(point.x, point.y) * 0.35
			var reach: int = int(ceilf(radius))
			for dz: int in range(-reach, reach + 1):
				for dx: int in range(-reach, reach + 1):
					var cell: Vector2i = Vector2i(int(floorf(point.x)) + dx, int(floorf(point.y)) + dz)
					if Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(point) <= radius:
						painted[cell] = true

	for cell: Vector2i in painted:
		var world: Vector3 = Vector3(cell.x, 0.0, cell.y)
		if not is_nan(_data.get_height(world)):
			_data.set_control(world, _dirt_control)

	return painted.size()


func _mark_regions_modified() -> void:
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var x: float = vegetation_zone.position.x
	while x <= vegetation_zone.end.x + region_size:
		var z: float = vegetation_zone.position.y
		while z <= vegetation_zone.end.y + region_size:
			var region: Terrain3DRegion = _data.get_regionp(Vector3(x, 0.0, z))
			if region != null:
				region.set_modified(true)

			z += region_size

		x += region_size

	_data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)
