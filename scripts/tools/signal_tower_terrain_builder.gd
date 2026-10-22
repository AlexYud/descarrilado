extends "res://scripts/tools/fig_clearing_terrain_builder.gd"
class_name SignalTowerTerrainBuilder

## Prepares the dream intro terrain for the ruined signal tower: levels a small pad of ground in the bowl just
## east of the northern loop's east leg (the arrow the developer drew on the map), paints it and a short trail
## to the loop as path dirt (so the vegetation and wall tools treat it as walkable), mixes the floor textures,
## clears the forest plants off the pad and the trail, scatters small plants over it and rebuilds the invisible
## path walls. Unlike the clearing and the shed it does NOT regrow the forest round it: only the plants that
## would stand in the tower, its stairs or the trail are removed, everything else the developer planted stays.
##
## It is the fig clearing's builder with another place: the levelling, painting, texture mixing and floor plants
## are inherited. Editor entry point: build_signal_tower_terrain.gd (and the headless runner next to it).

## Where the tower's origin (the middle of its foot) stands, in world XZ, and how it is turned: its door (+Z in
## its own frame) faces west, to the loop, so its stairs and balcony are on the south side.
var tower_origin: Vector2 = Vector2(101.5, -36.0)
var tower_yaw_degrees: float = -90.0

## The tower's footprint (door side, stairs and balcony included) is 5.5 m by 5.8 m in its own frame, its middle
## at (0.65, 0.8) there; this is where it falls in the world.
const FOOTPRINT_MIDDLE_LOCAL: Vector2 = Vector2(0.65, 0.8)

## The trail from the loop's east leg to the tower's door: from `trail_from` to `trail_to`.
var trail_from: Vector2 = Vector2(94.0, -36.0)
var trail_half_width: float = 1.3

## Plants are cleared over the pad plus this margin (so no bush leans in through a wall or over the stairs).
var clear_margin: float = 1.2


func _init() -> void:
	center = tower_origin + _to_world(FOOTPRINT_MIDDLE_LOCAL)
	flat_radius = 4.9
	flatten_blend = 6.0
	seed_value = 20261019


## A point in the tower's frame (X right of the door, Z out of it) as an offset in the world.
func _to_world(local: Vector2) -> Vector2:
	var angle: float = deg_to_rad(tower_yaw_degrees)
	return Vector2(
		local.x * cos(angle) + local.y * sin(angle),
		-local.x * sin(angle) + local.y * cos(angle)
	)


## The point just in front of the door, where the trail ends.
func door_front() -> Vector2:
	return tower_origin + _to_world(Vector2(-0.5, 3.0))


func build(terrain: Terrain3D) -> Dictionary:
	_terrain = terrain
	_data = terrain.data
	_rng.seed = seed_value
	_read_props()

	var before: Dictionary = _snapshot_heights()
	var height: float = flatten_ground()
	var reseated: int = reseat_plants(before)
	var painted: int = paint_floor()
	var removed: int = clear_plants()
	mix_floor_textures()
	var floor_plants: int = scatter_floor_plants()

	return {
		"height": height,
		"painted": painted,
		"removed": removed,
		"reseated": reseated,
		"added": 0,
		"floor_plants": floor_plants,
	}


## The tower itself and the ground in front of its door keep the small plants away.
func _read_props() -> void:
	_props.clear()
	_props.append({"position": tower_origin + _to_world(FOOTPRINT_MIDDLE_LOCAL), "radius": 3.7})
	_props.append({"position": door_front(), "radius": 1.0})


## The pad and the trail.
func _floor_cells() -> Array[Vector2]:
	var cells: Array[Vector2] = super._floor_cells()
	var seen: Dictionary = {}
	for cell: Vector2 in cells:
		seen[cell] = true

	var to: Vector2 = door_front()
	var length: float = trail_from.distance_to(to)
	var steps: int = int(ceilf(length * 2.0))
	var reach: int = int(ceilf(trail_half_width))
	for i: int in steps + 1:
		var spot: Vector2 = trail_from.lerp(to, float(i) / float(maxi(steps, 1)))
		for dz: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				var cell: Vector2 = Vector2(floorf(spot.x) + dx, floorf(spot.y) + dz)
				if seen.has(cell):
					continue

				if _distance_to_segment(cell, trail_from, to) <= trail_half_width:
					seen[cell] = true
					cells.append(cell)

	return cells


func _distance_to_segment(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var segment: Vector2 = to_point - from_point
	var t: float = clampf((point - from_point).dot(segment) / maxf(segment.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(from_point + segment * t)


## The ground's height at every whole cell where levelling may change it (the pad and its blend), before it is
## changed: the plants there were planted on that ground and have to follow it.
func _snapshot_heights() -> Dictionary:
	var heights: Dictionary = {}
	var reach: int = int(ceilf(flat_radius + flatten_blend)) + 2
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: Vector2i = Vector2i(int(floorf(center.x)) + dx, int(floorf(center.y)) + dz)
			heights[cell] = _data.get_height(Vector3(float(cell.x), 0.0, float(cell.y)))

	return heights


## The old ground's height at any point (bilinear between the snapshot's cells, as the terrain does).
func _old_height(snapshot: Dictionary, point: Vector2) -> float:
	var cell: Vector2i = Vector2i(int(floorf(point.x)), int(floorf(point.y)))
	var fx: float = point.x - float(cell.x)
	var fz: float = point.y - float(cell.y)
	var h00: float = float(snapshot.get(cell, NAN))
	var h10: float = float(snapshot.get(cell + Vector2i(1, 0), NAN))
	var h01: float = float(snapshot.get(cell + Vector2i(0, 1), NAN))
	var h11: float = float(snapshot.get(cell + Vector2i(1, 1), NAN))
	if is_nan(h00) or is_nan(h10) or is_nan(h01) or is_nan(h11):
		return NAN

	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


## Puts every plant that stands where the ground was levelled back on it: it keeps its height above the old
## ground. (Without this the plants of the blend zone float over the lowered ground or sink into the raised.)
## Returns how many were moved.
func reseat_plants(snapshot: Dictionary) -> int:
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var reach: float = flat_radius + flatten_blend + 1.0
	var area: Rect2 = Rect2(center - Vector2.ONE * reach, Vector2.ONE * 2.0 * reach)
	var moved: int = 0

	for region: Terrain3DRegion in _data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		if not Rect2(offset, Vector2(region_size, region_size)).intersects(area):
			continue

		var instances: Dictionary = region.get_instances()
		for mesh_id: int in instances.keys():
			var all_transforms: Array[Transform3D] = []
			var all_colors: PackedColorArray = PackedColorArray()
			var moved_here: int = 0
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in range(cell_transforms.size()):
					var transform: Transform3D = cell_transforms[i]
					var world: Vector2 = Vector2(transform.origin.x + offset.x, transform.origin.z + offset.y)
					if area.has_point(world):
						var old_ground: float = _old_height(snapshot, world)
						var new_ground: float = _data.get_height(Vector3(world.x, 0.0, world.y))
						if not is_nan(old_ground) and not is_nan(new_ground) and absf(new_ground - old_ground) > 0.001:
							transform.origin.y += new_ground - old_ground
							moved_here += 1

					all_transforms.append(transform)
					all_colors.append(cell_colors[i] if i < cell_colors.size() else Color.WHITE)

			if moved_here == 0:
				continue

			instancer.clear_by_region(region, mesh_id)
			instancer.append_region(region, mesh_id, all_transforms, all_colors, true)
			moved += moved_here

	return moved


## Removes the forest plants (every mesh the forest tools place) standing on the pad (with `clear_margin`) or on
## the trail, keeping every other instance of the same mesh. Terrain3D stores an instance's X and Z relative to
## its region, so positions are converted to world space before the test. Returns how many were removed.
func clear_plants() -> int:
	var cleared_ids: Array[int] = VegetationGenerator.CLEARED_MESH_IDS
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var to: Vector2 = door_front()
	var removed: int = 0
	var area: Rect2 = Rect2(center - Vector2.ONE * (flat_radius + clear_margin + 1.0), Vector2.ONE * 2.0 * (flat_radius + clear_margin + 1.0)).merge(
		Rect2(trail_from - Vector2.ONE * 3.0, Vector2.ONE * 6.0)
	)

	for region: Terrain3DRegion in _data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		if not Rect2(offset, Vector2(region_size, region_size)).intersects(area):
			continue

		var instances: Dictionary = region.get_instances()
		for mesh_id: int in cleared_ids:
			if not instances.has(mesh_id):
				continue

			var kept_transforms: Array[Transform3D] = []
			var kept_colors: PackedColorArray = PackedColorArray()
			var removed_here: int = 0
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in range(cell_transforms.size()):
					var transform: Transform3D = cell_transforms[i]
					var world: Vector2 = Vector2(transform.origin.x + offset.x, transform.origin.z + offset.y)
					if (
						world.distance_to(center) <= flat_radius + clear_margin
						or _distance_to_segment(world, trail_from, to) <= trail_half_width + 0.6
					):
						removed_here += 1
						continue

					kept_transforms.append(transform)
					kept_colors.append(cell_colors[i] if i < cell_colors.size() else Color.WHITE)

			if removed_here == 0:
				continue

			instancer.clear_by_region(region, mesh_id)
			if not kept_transforms.is_empty():
				instancer.append_region(region, mesh_id, kept_transforms, kept_colors, true)

			removed += removed_here

	return removed


## Copies the control value of the loop's east leg: searched in rings round the trail's start (the clearing's
## search runs along one row only, which can step between the path's cells).
func _find_reference_control() -> bool:
	for radius: int in range(0, 14):
		for dz: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue

				var point: Vector3 = Vector3(floorf(trail_from.x) + dx, 0.0, floorf(trail_from.y) + dz)
				if _is_path_dirt(point):
					_control_value = _data.get_control(point)
					return true

	return false


# ============================================================
# WALLS: SPLICED, NOT REBUILT
# ============================================================

## The old walls were built from an earlier state of the forest, so building them all again moves every wall of
## the map by a metre or so, and the walls the builder derives from the plants round the pad were narrow
## diagonals that hugged the tower. So only the walls of the tower's neighbourhood are changed, by hand: the old
## triangles whose footprint touches `wall_gap` (the east wall of the loop where the trail leaves it) are taken
## out, and a clean ring (`ring_points`) is put in, from the old wall's north end round the tower to its south
## end: at least 4 m from the tower, its stairs and its balcony on every side, open to the west, to the loop.
## Everything else stays exactly as it was.
var wall_gap: Rect2 = Rect2(94.5, -40.0, 5.5, 8.0)

## The ring, from the old wall's north end (95, -41) round the east to its south end (96.5, -31.5).
var ring_points: Array[Vector2] = [
	Vector2(95.0, -41.0), Vector2(97.5, -43.5), Vector2(102.0, -44.5), Vector2(106.5, -43.5), Vector2(109.5, -40.0),
	Vector2(110.5, -35.5), Vector2(109.5, -31.0), Vector2(106.5, -28.0), Vector2(102.0, -26.8), Vector2(98.0, -28.0),
	Vector2(96.5, -31.5),
]
var wall_below: float = 2.0
var wall_above: float = 4.0


## The faces of a wall scene (the body `ForestBoundary` with one concave collision shape).
func faces_of(scene: PackedScene) -> PackedVector3Array:
	var body: Node = scene.instantiate()
	var faces: PackedVector3Array = PackedVector3Array()
	for child: Node in body.get_children():
		var shape: CollisionShape3D = child as CollisionShape3D
		if shape != null and shape.shape is ConcavePolygonShape3D:
			faces = (shape.shape as ConcavePolygonShape3D).get_faces()

	body.free()
	return faces


## The ring as wall triangles: a quad of every half metre of it, from `wall_below` under the ground to `wall_above`
## over it (the walls are one sided from nobody: the shape collides from both sides).
func ring_faces() -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	for i: int in ring_points.size() - 1:
		var from_point: Vector2 = ring_points[i]
		var to_point: Vector2 = ring_points[i + 1]
		var steps: int = maxi(int(ceilf(from_point.distance_to(to_point) / 0.5)), 1)
		for k: int in steps:
			var a: Vector2 = from_point.lerp(to_point, float(k) / float(steps))
			var c: Vector2 = from_point.lerp(to_point, float(k + 1) / float(steps))
			var ground_a: float = _data.get_height(Vector3(a.x, 0.0, a.y))
			var ground_c: float = _data.get_height(Vector3(c.x, 0.0, c.y))
			var a_low: Vector3 = Vector3(a.x, ground_a - wall_below, a.y)
			var a_high: Vector3 = Vector3(a.x, ground_a + wall_above, a.y)
			var c_low: Vector3 = Vector3(c.x, ground_c - wall_below, c.y)
			var c_high: Vector3 = Vector3(c.x, ground_c + wall_above, c.y)
			faces.append_array(PackedVector3Array([a_low, c_low, c_high, a_low, c_high, a_high]))

	return faces


## The old triangles minus the ones in the gap, plus the ring. Returns a wall scene like the builder's, and counts
## in `stats`: {"removed", "added", "kept"}.
func splice_walls(old_faces: PackedVector3Array, new_faces: PackedVector3Array, stats: Dictionary) -> PackedScene:
	var spliced: PackedVector3Array = PackedVector3Array()
	var kept: int = 0
	var removed: int = 0
	for i: int in range(0, old_faces.size() - 2, 3):
		if _triangle_box(old_faces, i).intersects(wall_gap):
			removed += 1
			continue

		spliced.append(old_faces[i])
		spliced.append(old_faces[i + 1])
		spliced.append(old_faces[i + 2])
		kept += 1

	var added: int = 0
	for i: int in range(0, new_faces.size() - 2, 3):
		spliced.append(new_faces[i])
		spliced.append(new_faces[i + 1])
		spliced.append(new_faces[i + 2])
		added += 1

	stats["removed"] = removed
	stats["added"] = added
	stats["kept"] = kept

	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(spliced)
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
	return packed


## The footprint (X and Z) of the triangle starting at index `i`, grown a hair so a flat wall has an area.
func _triangle_box(faces: PackedVector3Array, i: int) -> Rect2:
	var box: Rect2 = Rect2(Vector2(faces[i].x, faces[i].z), Vector2.ZERO)
	box = box.expand(Vector2(faces[i + 1].x, faces[i + 1].z))
	box = box.expand(Vector2(faces[i + 2].x, faces[i + 2].z))
	return box.grow(0.01)
