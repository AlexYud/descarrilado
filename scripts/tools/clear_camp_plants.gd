extends Node

## One-off terrain edit, run as a scene in a real window: `Godot --path . res://scripts/tools/clear_camp_plants.tscn` prints what it would remove; add
## `-- --apply` to write.
##
## The fig tree clearing's camp was laid out again (the seats, the kettle, the wood yard, the tents and their gear, the memory table with its lantern, the
## roots): the terrain was not, and ferns and grass that were planted for the old camp grew through the new things (a fern through a log, bushes through a
## tent). This removes the plants whose leaves would reach into something of the camp, and only those.
##
## What counts as something of the camp: every mesh under the clearing scene (`Scenery/FigClearing`) that comes within `REACH` of the ground (the canopy
## and the lantern's light are no business of the plants), measured from its real triangles, not from a box round it: a log lying across a path takes
## only the ground it lies on. A plant is removed when it stands closer to such a triangle (seen from above) than its own leaves reach: half the width of
## its model, times its scale, times `LEAF_REACH` (the leaves are thin at the edge).
## Nothing else is touched: the plants away from the camp, the trees and what the developer made by hand stay as they are (only mesh ids below
## `MAX_PLANT_ID` that are plants, rocks or trees are looked at; the tents, the campfire and the benches of the terrain's own list are not).
## It can be run again (it only removes).

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const CLEARING_PATH: NodePath = ^"Scenery/FigClearing"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
## Only plants inside this circle (x, z, radius) are looked at.
const AREA: Vector3 = Vector3(64.0, -68.0, 12.0)
## Triangles lower than this over the ground (metres) are in the plants' way.
const REACH: float = 1.3
## The grid the camp's footprint is drawn on, and how far a plant's leaves can reach (metres) at the most.
const CELL: float = 0.08
const MAX_REACH: float = 2.6
## Mesh ids of the terrain's own list that are scenery and not plants (the tent, the campfire, the bench): never removed.
const KEEP_IDS: Array[int] = [15, 16, 19]
## Ids of the far stands and the vista trees (from 21 up) are never in the clearing's way.
const MAX_PLANT_ID: int = 21
## How much of half the width of a plant's model its leaves really reach into a thing next to it.
const LEAF_REACH: float = 0.55
## The least reach, for a plant too small to count.
const MIN_REACH: float = 0.07

var _terrain: Terrain3D = null
var _origin: Vector2 = Vector2.ZERO
var _columns: int = 0
var _rows: int = 0
var _distance: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var apply: bool = OS.get_cmdline_user_args().has("--apply")
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	_terrain = scene.get_node("Terrain3D") as Terrain3D
	var clearing: Node3D = scene.get_node(CLEARING_PATH) as Node3D
	var triangles: int = _draw_footprint(clearing)
	print("FOOTPRINT triangles ", triangles, " cells ", _columns, "x", _rows)
	_measure_distance()
	var result: Dictionary = _remove(apply)
	print("PLANTS in the area ", result["looked_at"], ", REMOVED ", result["removed"], " by id ", result["by_id"])
	if apply:
		for location: Vector2i in result["regions"]:
			_terrain.data.save_region(location, TERRAIN_DIRECTORY)
			print("SAVED region ", location)

	get_tree().quit()


# ============================================================
# THE FOOTPRINT
# ============================================================

## Draws every triangle of the camp's meshes that is within reach of the plants onto a grid, seen from above. Returns how many it drew.
func _draw_footprint(clearing: Node3D) -> int:
	var half: float = AREA.z + MAX_REACH
	_origin = Vector2(AREA.x - half, AREA.y - half)
	_columns = int(ceil(half * 2.0 / CELL))
	_rows = _columns
	_distance.resize(_columns * _rows)
	_distance.fill(1e9)
	var drawn: int = 0
	for node: Node in clearing.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree() or instance.name == &"Ground":
			continue

		var faces: PackedVector3Array = instance.mesh.get_faces()
		var transform: Transform3D = instance.global_transform
		for index: int in range(0, faces.size() - 2, 3):
			var a: Vector3 = transform * faces[index]
			var b: Vector3 = transform * faces[index + 1]
			var c: Vector3 = transform * faces[index + 2]
			var ground: float = _ground_at((a + b + c) / 3.0)
			if is_nan(ground) or minf(a.y, minf(b.y, c.y)) > ground + REACH or maxf(a.y, maxf(b.y, c.y)) < ground - 0.3:
				continue

			_draw_triangle(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
			drawn += 1

	return drawn


func _ground_at(point: Vector3) -> float:
	return _terrain.data.get_height(Vector3(point.x, 0.0, point.z))


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - _origin.x) / CELL), floori((point.y - _origin.y) / CELL))


func _mark(cell: Vector2i) -> void:
	if cell.x >= 0 and cell.y >= 0 and cell.x < _columns and cell.y < _rows:
		_distance[cell.y * _columns + cell.x] = 0.0


## Marks the cells a triangle covers (its inside, and its edges, so that a sliver is not lost).
func _draw_triangle(a: Vector2, b: Vector2, c: Vector2) -> void:
	for edge: Array in [[a, b], [b, c], [c, a]]:
		var from_point: Vector2 = edge[0]
		var to_point: Vector2 = edge[1]
		var steps: int = maxi(int(from_point.distance_to(to_point) / (CELL * 0.5)), 1)
		for step: int in steps + 1:
			_mark(_cell_of(from_point.lerp(to_point, float(step) / float(steps))))

	var low: Vector2i = _cell_of(Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y))))
	var high: Vector2i = _cell_of(Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y))))
	low = Vector2i(maxi(low.x, 0), maxi(low.y, 0))
	high = Vector2i(mini(high.x, _columns - 1), mini(high.y, _rows - 1))
	var denominator: float = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(denominator) < 0.000001:
		return

	for row: int in range(low.y, high.y + 1):
		for column: int in range(low.x, high.x + 1):
			var p: Vector2 = _origin + Vector2((float(column) + 0.5) * CELL, (float(row) + 0.5) * CELL)
			var u: float = ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / denominator
			var v: float = ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / denominator
			if u >= 0.0 and v >= 0.0 and u + v <= 1.0:
				_distance[row * _columns + column] = 0.0


## The distance (metres) from every cell to the nearest cell of the footprint, out to `MAX_REACH` (a sweep over the grid).
func _measure_distance() -> void:
	var queue: Array[int] = []
	for index: int in _distance.size():
		if _distance[index] == 0.0:
			queue.append(index)

	var head: int = 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var x: int = index % _columns
		var z: int = index / _columns
		var here: float = _distance[index]
		if here > MAX_REACH:
			continue

		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				if dx == 0 and dz == 0:
					continue

				var nx: int = x + dx
				var nz: int = z + dz
				if nx < 0 or nz < 0 or nx >= _columns or nz >= _rows:
					continue

				var other: int = nz * _columns + nx
				var step: float = CELL if dx == 0 or dz == 0 else CELL * 1.4142
				if _distance[other] > here + step + 0.0001:
					_distance[other] = here + step
					queue.append(other)


func _distance_at(point: Vector2) -> float:
	var cell: Vector2i = _cell_of(point)
	if cell.x < 0 or cell.y < 0 or cell.x >= _columns or cell.y >= _rows:
		return 1e9

	return _distance[cell.y * _columns + cell.x]


# ============================================================
# THE PLANTS
# ============================================================

## Removes the plants whose leaves reach into the footprint. Returns how many were looked at and removed, by id, and the regions that changed.
func _remove(apply: bool) -> Dictionary:
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var looked_at: int = 0
	var removed: int = 0
	var by_id: Dictionary = {}
	var changed_regions: Array[Vector2i] = []
	var half_widths: Dictionary = {}
	for region: Terrain3DRegion in _terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		var region_changed: bool = false
		for mesh_id: int in instances.keys():
			if mesh_id >= MAX_PLANT_ID or KEEP_IDS.has(mesh_id):
				continue

			if not half_widths.has(mesh_id):
				var asset: Terrain3DMeshAsset = _terrain.assets.get_mesh_asset(mesh_id)
				var size: Vector3 = asset.get_mesh().get_aabb().size if asset != null and asset.get_mesh() != null else Vector3.ONE
				half_widths[mesh_id] = maxf(size.x, size.z) * 0.5

			var transforms: Array[Transform3D] = []
			var colors: PackedColorArray = PackedColorArray()
			var changed: bool = false
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in cell_transforms.size():
					var transform: Transform3D = cell_transforms[i]
					var world: Vector2 = Vector2(transform.origin.x + offset.x, transform.origin.z + offset.y)
					var inside: bool = world.distance_to(Vector2(AREA.x, AREA.y)) <= AREA.z
					var gone: bool = false
					if inside:
						looked_at += 1
						var scale: float = maxf(transform.basis.get_scale().x, transform.basis.get_scale().z)
						var reach: float = maxf(float(half_widths[mesh_id]) * scale * LEAF_REACH, MIN_REACH)
						gone = _distance_at(world) < reach

					if gone:
						removed += 1
						changed = true
						by_id[mesh_id] = int(by_id.get(mesh_id, 0)) + 1
						continue

					transforms.append(transform)
					colors.append(cell_colors[i] if i < cell_colors.size() else Color.WHITE)

			if apply and changed:
				instancer.clear_by_region(region, mesh_id)
				instancer.append_region(region, mesh_id, transforms, colors, true)
				region_changed = true

		if region_changed:
			changed_regions.append(region.location)

	return {"looked_at": looked_at, "removed": removed, "by_id": by_id, "regions": changed_regions}
