@tool
extends RefCounted
class_name ForestBoundaryBuilder

## Builds the invisible map limit around the trail: a smooth wall that follows
## the face of the tall vegetation.
##
## 1. Walkable region = ground within `max_reach` metres of the path that is
##    not covered by tall plants (bushes, tall plants, ferns, trees), plus a
##    clear strip around the path itself. Only the part connected to the path
##    counts.
## 2. The region is blurred and traced into polygons, so its outline is
##    rounded instead of following the 0.5 m grid steps.
## 3. A vertical wall (one concave collision shape, solid from both sides) is
##    placed along every polygon edge, except edges lying on the zone border
##    so the path stays open where it leaves the zone.
##
## Open ground (a fork, a plaza) stays walkable up to `max_reach`; the wall
## only stands at the vegetation, or at that distance where there is none.

const CELL: float = 0.5
const HIRES: float = 0.25

## Area to wall. Starts past the gate (the train and yard have fences).
var zone: Rect2 = Rect2(12.0, -95.0, 205.0, 190.0)

## The path itself and this margin around it are always walkable.
var path_clear: float = 0.9

## Open ground is walkable up to this far from the path.
var max_reach: float = 4.5

var dirt_texture_id: int = 1
var wall_below: float = 2.0
var wall_above: float = 4.0

## Plants that form the wall: Terrain3D mesh id -> footprint radius at scale 1.
var wall_plants: Dictionary = {
	0: 1.0, 4: 1.0, 7: 0.4, 13: 0.4, 9: 0.8, 1: 0.6, 2: 0.6, 3: 0.8, 14: 0.8,
}

## Plants smaller than this (scale on Y) do not count as wall.
var min_plant_scale: float = 0.8

## Gaps up to this wide (metres) between wall plants are closed.
var close_gap: float = 1.2

## Outline simplification, in metres, and blur strength (passes of 1 cell).
var simplify: float = 0.3
var blur_passes: int = 2

## Outlines smaller than this (m²) are dropped (isolated bits of vegetation).
var min_loop_area: float = 6.0

## Wall ends on the zone border are tied to the nearest of these points. They
## are on the fence pieces two steps from the door (f62 north, f79 south), not
## on the door fence itself, so the walls stay clear of the door while it swings
## open (it sweeps x 10.6 to 12.8, z 4.9 to 7.1) and still close the playable
## area. Each connector overlaps the anchor slightly.
var border_anchors: Array[Vector2] = [
	Vector2(8.6, 3.1),
	Vector2(7.8, 8.5),
]

var _data: Terrain3DData = null
var _cols: int = 0
var _rows: int = 0
var _path_distance: PackedFloat32Array = PackedFloat32Array()
var _blocked: PackedByteArray = PackedByteArray()
var _field: PackedFloat32Array = PackedFloat32Array()


## Returns {"scene": PackedScene, "faces": int, "segments": int, "loops": int}.
func build(terrain: Terrain3D) -> Dictionary:
	_data = terrain.data
	_cols = int(ceilf(zone.size.x / CELL))
	_rows = int(ceilf(zone.size.y / CELL))

	_compute_path_distance()
	_compute_blocked(terrain)
	_compute_field()

	var vertices: PackedVector3Array = PackedVector3Array()
	var stats: Dictionary = _trace_walls(vertices)

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
		"segments": int(stats["segments"]),
		"loops": int(stats["loops"]),
	}


# ============================================================
# PATH DISTANCE
# ============================================================

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


func _cell_center(col: int, row: int) -> Vector2:
	return zone.position + Vector2(
		(float(col) + 0.5) * CELL,
		(float(row) + 0.5) * CELL
	)


func _compute_path_distance() -> void:
	var count: int = _cols * _rows
	_path_distance.resize(count)
	for row: int in range(_rows):
		for col: int in range(_cols):
			var center: Vector2 = _cell_center(col, row)
			_path_distance[row * _cols + col] = (
				0.0 if _is_path(center.x, center.y) else INF
			)

	var diagonal: float = CELL * 1.4142
	for row: int in range(_rows):
		for col: int in range(_cols):
			var i: int = row * _cols + col
			var best: float = _path_distance[i]
			if col > 0:
				best = minf(best, _path_distance[i - 1] + CELL)
			if row > 0:
				best = minf(best, _path_distance[i - _cols] + CELL)
				if col > 0:
					best = minf(best, _path_distance[i - _cols - 1] + diagonal)
				if col < _cols - 1:
					best = minf(best, _path_distance[i - _cols + 1] + diagonal)
			_path_distance[i] = best

	for row: int in range(_rows - 1, -1, -1):
		for col: int in range(_cols - 1, -1, -1):
			var i: int = row * _cols + col
			var best: float = _path_distance[i]
			if col < _cols - 1:
				best = minf(best, _path_distance[i + 1] + CELL)
			if row < _rows - 1:
				best = minf(best, _path_distance[i + _cols] + CELL)
				if col < _cols - 1:
					best = minf(best, _path_distance[i + _cols + 1] + diagonal)
				if col > 0:
					best = minf(best, _path_distance[i + _cols - 1] + diagonal)
			_path_distance[i] = best


# ============================================================
# VEGETATION
# ============================================================

## Marks the cells covered by wall plants, then closes narrow gaps.
func _compute_blocked(terrain: Terrain3D) -> void:
	var count: int = _cols * _rows
	_blocked.resize(count)
	_blocked.fill(0)
	var region_size: float = float(terrain.region_size) * terrain.vertex_spacing

	for region: Terrain3DRegion in _data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		if not Rect2(offset, Vector2(region_size, region_size)).intersects(zone):
			continue

		var instances: Dictionary = region.get_instances()
		for mesh_id: Variant in wall_plants:
			if not instances.has(mesh_id):
				continue

			var radius_at_unit: float = float(wall_plants[mesh_id])
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				for transform: Transform3D in cells[cell][0]:
					var scale: float = transform.basis.get_scale().y
					if scale < min_plant_scale:
						continue

					_stamp(
						Vector2(
							transform.origin.x + offset.x,
							transform.origin.z + offset.y
						),
						radius_at_unit * minf(scale, 1.6)
					)

	# Close narrow gaps between plants: dilate, then erode.
	var reach: int = maxi(1, int(ceilf(close_gap / CELL / 2.0)))
	_blocked = _morph(_morph(_blocked, reach, true), reach, false)


func _stamp(center: Vector2, radius: float) -> void:
	var c0: int = int(floorf((center.x - radius - zone.position.x) / CELL))
	var c1: int = int(floorf((center.x + radius - zone.position.x) / CELL))
	var r0: int = int(floorf((center.y - radius - zone.position.y) / CELL))
	var r1: int = int(floorf((center.y + radius - zone.position.y) / CELL))
	for row: int in range(maxi(r0, 0), mini(r1, _rows - 1) + 1):
		for col: int in range(maxi(c0, 0), mini(c1, _cols - 1) + 1):
			if _cell_center(col, row).distance_to(center) <= radius:
				_blocked[row * _cols + col] = 1


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


# ============================================================
# WALKABLE FIELD
# ============================================================

## 1 where walkable, 0 where blocked, blurred so the outline is round.
func _compute_field() -> void:
	var count: int = _cols * _rows
	var walkable: PackedByteArray = PackedByteArray()
	walkable.resize(count)
	walkable.fill(0)

	# Walkable ground: close to the path and free of tall plants, or the path's
	# own clear strip, whatever grows on it.
	for i: int in range(count):
		var d: float = _path_distance[i]
		if d <= path_clear or (d <= max_reach and _blocked[i] == 0):
			walkable[i] = 1

	# Keep only the part connected to the path.
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(count)
	keep.fill(0)
	var queue: PackedInt32Array = PackedInt32Array()
	for i: int in range(count):
		if _path_distance[i] <= 0.0 and walkable[i] == 1:
			keep[i] = 1
			queue.append(i)

	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var col: int = i % _cols
		var row: int = i / _cols
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: int = col + step.x
			var r: int = row + step.y
			if c < 0 or r < 0 or c >= _cols or r >= _rows:
				continue

			var j: int = r * _cols + c
			if keep[j] == 0 and walkable[j] == 1:
				keep[j] = 1
				queue.append(j)

	_field.resize(count)
	for i: int in range(count):
		_field[i] = float(keep[i])

	for _pass: int in range(blur_passes):
		_blur()


func _blur() -> void:
	var tmp: PackedFloat32Array = _field.duplicate()
	for row: int in range(_rows):
		for col: int in range(_cols):
			var sum: float = 0.0
			for dc: int in range(-1, 2):
				sum += _sample_cell(col + dc, row)
			tmp[row * _cols + col] = sum / 3.0

	for row: int in range(_rows):
		for col: int in range(_cols):
			var sum: float = 0.0
			for dr: int in range(-1, 2):
				sum += _sample_tmp(tmp, col, row + dr)
			_field[row * _cols + col] = sum / 3.0


## Outside the zone counts as walkable (value 1), so no wall closes the edge.
func _sample_cell(col: int, row: int) -> float:
	if col < 0 or row < 0 or col >= _cols or row >= _rows:
		return 1.0

	return _field[row * _cols + col]


func _sample_tmp(tmp: PackedFloat32Array, col: int, row: int) -> float:
	if col < 0 or row < 0 or col >= _cols or row >= _rows:
		return 1.0

	return tmp[row * _cols + col]


# ============================================================
# OUTLINE AND WALLS
# ============================================================

func _field_at(point: Vector2) -> float:
	# Bilinear sample of the field at a world position.
	var fx: float = (point.x - zone.position.x) / CELL - 0.5
	var fy: float = (point.y - zone.position.y) / CELL - 0.5
	var c0: int = int(floorf(fx))
	var r0: int = int(floorf(fy))
	var tx: float = fx - float(c0)
	var ty: float = fy - float(r0)
	var a: float = lerpf(_sample_cell(c0, r0), _sample_cell(c0 + 1, r0), tx)
	var b: float = lerpf(_sample_cell(c0, r0 + 1), _sample_cell(c0 + 1, r0 + 1), tx)
	return lerpf(a, b, ty)


func _trace_walls(vertices: PackedVector3Array) -> Dictionary:
	# Pad the bitmap by 2 m of walkable ground, so outlines never hug its edge.
	var pad: int = int(2.0 / HIRES)
	var width: int = int(ceilf(zone.size.x / HIRES)) + pad * 2
	var height: int = int(ceilf(zone.size.y / HIRES)) + pad * 2
	var bitmap: BitMap = BitMap.new()
	bitmap.create(Vector2i(width, height))

	for y: int in range(height):
		for x: int in range(width):
			var point: Vector2 = zone.position + Vector2(
				(float(x - pad) + 0.5) * HIRES,
				(float(y - pad) + 0.5) * HIRES
			)
			# Opaque = blocked (vegetation); its outline is the wall.
			bitmap.set_bit(x, y, _field_at(point) < 0.5)

	var polygons: Array = bitmap.opaque_to_polygons(
		Rect2i(0, 0, width, height),
		simplify / HIRES
	)

	var segments: int = 0
	var loops: int = 0
	var border_ends: Array[Vector2] = []
	for polygon_variant: Variant in polygons:
		var polygon: PackedVector2Array = polygon_variant
		if absf(_polygon_area(polygon)) * HIRES * HIRES < min_loop_area:
			continue

		loops += 1
		var world: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in polygon:
			world.append(zone.position + (p - Vector2(float(pad), float(pad))) * HIRES)

		for i: int in range(world.size()):
			var a: Vector2 = world[i]
			var b: Vector2 = world[(i + 1) % world.size()]
			if _on_zone_border(a) and _on_zone_border(b):
				continue

			_add_wall(vertices, a, b)
			segments += 1

			# A kept edge that touches the zone border is a wall end: the path
			# leaves the zone here, so it must be tied to the fences or the door.
			if _on_zone_border(a) != _on_zone_border(b):
				border_ends.append(a if _on_zone_border(a) else b)

	segments += _connect_border_ends(vertices, border_ends)
	return {"segments": segments, "loops": loops}


func _polygon_area(polygon: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		area += a.x * b.y - b.x * a.y

	return area * 0.5


## True when a point is on the edge of the zone, where the path leaves it. The
## border is only treated as an edge on the sides the paths cross.
func _on_zone_border(point: Vector2) -> bool:
	var tolerance: float = 0.6
	return (
		absf(point.x - zone.position.x) <= tolerance
		or absf(point.x - zone.end.x) <= tolerance
		or absf(point.y - zone.position.y) <= tolerance
		or absf(point.y - zone.end.y) <= tolerance
	)


func _add_wall(vertices: PackedVector3Array, start: Vector2, finish: Vector2) -> void:
	# Split long edges so the wall follows the terrain height.
	var length: float = start.distance_to(finish)
	var pieces: int = maxi(1, int(ceilf(length / 3.0)))
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


## Joins each wall end on the zone border to the nearest anchor with a wall.
func _connect_border_ends(vertices: PackedVector3Array, ends: Array[Vector2]) -> int:
	if border_anchors.is_empty():
		return 0

	var added: int = 0
	var done: Array[Vector2] = []
	for end: Vector2 in ends:
		var duplicate: bool = false
		for other: Vector2 in done:
			if other.distance_to(end) < 0.8:
				duplicate = true

		if duplicate:
			continue

		done.append(end)
		var best: Vector2 = border_anchors[0]
		for anchor: Vector2 in border_anchors:
			if anchor.distance_to(end) < best.distance_to(end):
				best = anchor

		# Overshoot the anchor a little so the wall overlaps the fence.
		var direction: Vector2 = (best - end).normalized()
		_add_wall(vertices, end, best + direction * 0.3)
		added += 1

	return added
