@tool
extends RefCounted
class_name ForestBoundaryBuilder

## Builds invisible walls around everything walkable (the painted dirt paths
## and the overlook plaza), so the player cannot dive into the forest.
##
## A cell is walkable when it is within `margin` metres of path cells, using
## the same path rule as ForestPathVegetationGenerator (dirt is the base
## texture). Wherever a walkable cell touches a non-walkable one, a vertical
## wall is placed. Cells outside `zone` count as walkable, so no wall is built
## across the zone edge, around the train or in the gate yard.
##
## The result is one StaticBody3D with a single concave collision shape that
## collides from both sides, saved as a scene with world-space geometry (so it
## is instanced at the scene origin).

const CELL: float = 0.5

## Area to wall. Starts past the gate (the train and yard have fences).
var zone: Rect2 = Rect2(12.0, -95.0, 205.0, 190.0)

## Walls stand this far outside the path cells.
var margin: float = 0.7

var dirt_texture_id: int = 1
var wall_below: float = 2.0
var wall_above: float = 4.0

var _data: Terrain3DData = null
var _cols: int = 0
var _rows: int = 0
var _walkable: PackedByteArray = PackedByteArray()
var _distance: PackedFloat32Array = PackedFloat32Array()

## Walls only where tall vegetation stands, so gaps stay open and small and
## medium plants never block the player. Ids are Terrain3D mesh ids.
var use_vegetation: bool = true
var vegetation_ids: Array[int] = [0, 4, 7, 13, 9, 1, 2, 3, 14]
## Instances smaller than this (scale on Y) do not count as wall.
var min_plant_scale: float = 0.8
## Gaps up to this wide (metres) between wall plants are closed.
var close_gap: float = 8.0
var backing_distance: float = 2.0

## Circles (x, z, radius) where the wall is always built even without
## vegetation, such as the overlook plaza whose view is kept open.
var forced_zones: Array[Vector3] = [Vector3(168.0, 27.0, 24.0)]
var _vegetation: PackedByteArray = PackedByteArray()


## Returns {"scene": PackedScene, "faces": int, "segments": int}.
func build(terrain: Terrain3D) -> Dictionary:
	_data = terrain.data
	_cols = int(ceilf(zone.size.x / CELL))
	_rows = int(ceilf(zone.size.y / CELL))
	_compute_walkable()
	if use_vegetation:
		_compute_vegetation(terrain)

	var vertices: PackedVector3Array = PackedVector3Array()
	var segments: int = 0
	segments += _collect_walls(vertices, true)
	segments += _collect_walls(vertices, false)

	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(vertices)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ForestBoundary"
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body

	var packed: PackedScene = PackedScene.new()
	packed.pack(body)
	body.free()

	return {
		"scene": packed,
		"faces": vertices.size() / 3,
		"open_ends": _count_open_ends(vertices),
		"segments": segments,
	}


func _is_path(x: float, z: float) -> bool:
	var point: Vector3 = Vector3(x, 0.0, z)
	if is_nan(_data.get_height(point)):
		return false

	if _data.get_control_auto(point):
		return false

	var ids: Vector3 = _data.get_texture_id(point)
	if int(ids.x) == dirt_texture_id:
		return not (int(ids.y) == 2 and ids.z > 0.5)

	return int(ids.y) == dirt_texture_id and ids.z > 0.85


func _compute_walkable() -> void:
	var count: int = _cols * _rows
	_distance.resize(count)
	_walkable.resize(count)
	for row: int in range(_rows):
		for col: int in range(_cols):
			var center: Vector2 = _cell_center(col, row)
			_distance[row * _cols + col] = (
				0.0 if _is_path(center.x, center.y) else INF
			)

	var diagonal: float = CELL * 1.4142
	for row: int in range(_rows):
		for col: int in range(_cols):
			var i: int = row * _cols + col
			var best: float = _distance[i]
			if col > 0:
				best = minf(best, _distance[i - 1] + CELL)
			if row > 0:
				best = minf(best, _distance[i - _cols] + CELL)
				if col > 0:
					best = minf(best, _distance[i - _cols - 1] + diagonal)
				if col < _cols - 1:
					best = minf(best, _distance[i - _cols + 1] + diagonal)
			_distance[i] = best

	for row: int in range(_rows - 1, -1, -1):
		for col: int in range(_cols - 1, -1, -1):
			var i: int = row * _cols + col
			var best: float = _distance[i]
			if col < _cols - 1:
				best = minf(best, _distance[i + 1] + CELL)
			if row < _rows - 1:
				best = minf(best, _distance[i + _cols] + CELL)
				if col < _cols - 1:
					best = minf(best, _distance[i + _cols + 1] + diagonal)
				if col > 0:
					best = minf(best, _distance[i + _cols - 1] + diagonal)
			_distance[i] = best

	for i: int in range(count):
		_walkable[i] = 1 if _distance[i] <= margin else 0


func _cell_center(col: int, row: int) -> Vector2:
	return zone.position + Vector2(
		(float(col) + 0.5) * CELL,
		(float(row) + 0.5) * CELL
	)


## Out-of-zone cells are open, so nothing is walled at the zone edge.
func _is_open(col: int, row: int) -> bool:
	if col < 0 or row < 0 or col >= _cols or row >= _rows:
		return true

	return _walkable[row * _cols + col] == 1


## Walls on edges between a walkable cell and a blocked one, merged into long
## runs. `along_x` selects edges that run along X (between rows) or Z.
func _collect_walls(vertices: PackedVector3Array, along_x: bool) -> int:
	var segments: int = 0
	var outer: int = _rows + 1 if along_x else _cols + 1
	var inner: int = _cols if along_x else _rows

	for line: int in range(outer):
		var run_start: int = -1
		for step: int in range(inner + 1):
			var wall: bool = false
			if step < inner:
				var a_open: bool
				var b_open: bool
				if along_x:
					a_open = _is_open(step, line - 1)
					b_open = _is_open(step, line)
				else:
					a_open = _is_open(line - 1, step)
					b_open = _is_open(line, step)

				# A wall only where one side is the walkable cell and the
				# other is blocked ground inside the zone.
				wall = a_open != b_open and _inside(step, line, along_x)
				if wall and use_vegetation:
					# Only where the blocked side is covered by the vegetation wall.
					var blocked_col: int = step if along_x else (line if not a_open else line - 1)
					var blocked_row: int = (line if not a_open else line - 1) if along_x else step
					wall = _vegetated(blocked_col, blocked_row)

			if wall and run_start < 0:
				run_start = step
			elif not wall and run_start >= 0:
				_add_wall(vertices, line, run_start, step, along_x)
				segments += 1
				run_start = -1

	return segments


func _inside(step: int, line: int, along_x: bool) -> bool:
	var col: int = step if along_x else line
	var row: int = line if along_x else step
	var a_inside: bool = (
		col - (0 if along_x else 1) >= 0
		and row - (1 if along_x else 0) >= 0
		and col - (0 if along_x else 1) < _cols
		and row - (1 if along_x else 0) < _rows
	)
	var b_inside: bool = col >= 0 and row >= 0 and col < _cols and row < _rows
	return a_inside and b_inside


func _add_wall(
	vertices: PackedVector3Array,
	line: int,
	from_step: int,
	to_step: int,
	along_x: bool
) -> void:
	var start: Vector2
	var finish: Vector2
	if along_x:
		start = zone.position + Vector2(float(from_step), float(line)) * CELL
		finish = zone.position + Vector2(float(to_step), float(line)) * CELL
	else:
		start = zone.position + Vector2(float(line), float(from_step)) * CELL
		finish = zone.position + Vector2(float(line), float(to_step)) * CELL

	# Split long runs so the wall follows the terrain height.
	var length: float = start.distance_to(finish)
	var pieces: int = maxi(1, int(ceilf(length / 4.0)))
	for piece: int in range(pieces):
		var p0: Vector2 = start.lerp(finish, float(piece) / float(pieces))
		var p1: Vector2 = start.lerp(finish, float(piece + 1) / float(pieces))
		var h0: float = _data.get_height(Vector3(p0.x, 0.0, p0.y))
		var h1: float = _data.get_height(Vector3(p1.x, 0.0, p1.y))
		if is_nan(h0):
			h0 = 0.0
		if is_nan(h1):
			h1 = h0

		var low: float = minf(h0, h1) - wall_below
		var high: float = maxf(h0, h1) + wall_above
		var a: Vector3 = Vector3(p0.x, low, p0.y)
		var b: Vector3 = Vector3(p1.x, low, p1.y)
		var c: Vector3 = Vector3(p1.x, high, p1.y)
		var d: Vector3 = Vector3(p0.x, high, p0.y)
		vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))


func _vegetated(col: int, row: int) -> bool:
	var center: Vector2 = _cell_center(col, row)
	for zone_circle: Vector3 in forced_zones:
		if center.distance_to(Vector2(zone_circle.x, zone_circle.y)) <= zone_circle.z:
			return true

	if col < 0 or row < 0 or col >= _cols or row >= _rows:
		return false

	return _vegetation[row * _cols + col] == 1


## Marks cells covered by qualifying plants, then closes small gaps.
func _compute_vegetation(terrain: Terrain3D) -> void:
	var count: int = _cols * _rows
	_vegetation.resize(count)
	_vegetation.fill(0)
	var region_size: float = float(terrain.region_size) * terrain.vertex_spacing
	var seeds: int = 0

	for region: Terrain3DRegion in _data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		if not Rect2(offset, Vector2(region_size, region_size)).intersects(zone):
			continue

		var instances: Dictionary = region.get_instances()
		for mesh_id: int in vegetation_ids:
			if not instances.has(mesh_id):
				continue

			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				for transform: Transform3D in cells[cell][0]:
					if transform.basis.get_scale().y < min_plant_scale:
						continue

					var world: Vector2 = Vector2(
						transform.origin.x + offset.x,
						transform.origin.z + offset.y
					)
					var col: int = int(floorf((world.x - zone.position.x) / CELL))
					var row: int = int(floorf((world.y - zone.position.y) / CELL))
					if col >= 0 and row >= 0 and col < _cols and row < _rows:
						_vegetation[row * _cols + col] = 1
						seeds += 1

	# Close gaps: dilate by half the gap, then erode by the same amount.
	var reach: int = maxi(1, int(ceilf(close_gap / CELL / 2.0)) + 1)
	var dilated: PackedByteArray = _morph(_vegetation, reach, true)
	_vegetation = _morph(dilated, reach, false)
	# A wall stands at the path margin, so vegetation up to this far behind it
	# counts as its backing.
	_vegetation = _morph(_vegetation, int(ceilf(backing_distance / CELL)), true)


func _morph(source: PackedByteArray, reach: int, grow: bool) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(_cols * _rows)
	for row: int in range(_rows):
		for col: int in range(_cols):
			var result: int = 0 if grow else 1
			for dr: int in range(-reach, reach + 1):
				for dc: int in range(-reach, reach + 1):
					var c: int = col + dc
					var r: int = row + dr
					var value: int = 0
					if c >= 0 and r >= 0 and c < _cols and r < _rows:
						value = source[r * _cols + c]
					elif not grow:
						value = 1
					if grow and value == 1:
						result = 1
					elif not grow and value == 0:
						result = 0

			out[row * _cols + col] = result

	return out


## Number of wall ends that touch no other wall: each one is a gap the player
## could slip through. Counts bottom vertices shared by an odd number of quads.
func _count_open_ends(vertices: PackedVector3Array) -> int:
	var degree: Dictionary = {}
	for i: int in range(0, vertices.size(), 6):
		for corner: Vector3 in [vertices[i], vertices[i + 1]]:
			var key: Vector2i = Vector2i(
				int(roundf(corner.x / CELL)),
				int(roundf(corner.z / CELL))
			)
			degree[key] = int(degree.get(key, 0)) + 1

	var ends: int = 0
	for key: Vector2i in degree:
		if int(degree[key]) % 2 == 1:
			ends += 1

	return ends
