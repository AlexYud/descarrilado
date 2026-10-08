extends RefCounted

## Prepares the dream intro terrain for the unfinished house: levels a
## rectangle of ground (blending back into the slope) under the house, paints it
## and two short trail strips as path (dirt base, so the vegetation and wall tools
## treat it as walkable and keep plants off it), regrows the forest around it,
## mixes the floor textures and rebuilds the invisible path walls.
##
## The house sits across the southern path (C): its front door faces west (the
## train and the forest paths) and its back door faces east (the path to the city
## overlook). The house is rotated -90 degrees about Y, so its local X runs
## south and its local +Z runs west:
##   world = origin + (-local.z, local.y, local.x)
## Editor entry point: build_unfinished_house_terrain.gd.

const VegetationGenerator := preload("res://scripts/tools/forest_path_vegetation_generator.gd")
const BoundaryBuilder := preload("res://scripts/tools/forest_boundary_builder.gd")

const TEX_GRASS: int = 0
const TEX_FOREST_FLOOR: int = 2
const TEX_MOSS: int = 3
const TEX_HUMUS: int = 4
const TEX_PINE_MULCH: int = 5

# Terrain3D mesh ids used by the forest tools.
const FERN: int = 9
const BUSH_A: int = 0
const BUSH_B: int = 4
const PITANGUEIRA: int = 3
const TREE_A: int = 1
const TREE_B: int = 2
const MEDIUM_PLANT: int = 6
const TALL_PLANT_A: int = 7
const TALL_PLANT_B: int = 13
const RED_PLANT: int = 10
const GRASS_A: int = 11
const GRASS_B: int = 12
const ARAUCARIA: int = 14

## How far from the walls the overgrowth reaches.
const OVERGROWTH_REACH: float = 16.0

## Layers of extra growth around the house. `density` is plants per square metre
## of the whole ring; `d_min` / `d_max` are distances from the walls in metres
## (keeping trunks off the walls); `spacing` keeps big plants apart.
const OVERGROWTH: Array[Dictionary] = [
	{
		"name": "ferns", "ids": [FERN], "density": 0.9, "d_min": 0.5, "d_max": 7.0,
		"scale": Vector2(0.6, 1.2), "align": 0.4, "tilt": 8.0,
	},
	{
		"name": "leafy plants", "ids": [MEDIUM_PLANT], "density": 0.7, "d_min": 0.5, "d_max": 7.0,
		"scale": Vector2(0.7, 1.3), "align": 0.3, "tilt": 8.0,
	},
	{
		"name": "grass", "ids": [GRASS_A, GRASS_B], "density": 1.2, "d_min": 0.5, "d_max": 5.0,
		"scale": Vector2(0.5, 1.0), "align": 0.6, "tilt": 10.0,
	},
	{
		"name": "bushes", "ids": [BUSH_A, BUSH_B], "density": 0.42, "d_min": 0.7, "d_max": 8.0,
		"scale": Vector2(0.9, 1.6), "align": 0.0, "tilt": 4.0, "spacing": 1.3,
	},
	{
		"name": "tall plants", "ids": [TALL_PLANT_A, TALL_PLANT_B], "density": 0.3,
		"d_min": 0.6, "d_max": 8.0, "scale": Vector2(0.9, 1.6), "align": 0.2, "tilt": 6.0,
	},
	{
		"name": "red plants", "ids": [RED_PLANT], "density": 0.05, "d_min": 1.0, "d_max": 8.0,
		"scale": Vector2(0.8, 1.2), "align": 0.3,
	},
	{
		"name": "shrub trees", "ids": [PITANGUEIRA], "density": 0.06, "d_min": 1.6, "d_max": 12.0,
		"scale": Vector2(0.7, 1.0), "align": 0.0, "spacing": 3.2, "max_slope": 40.0,
	},
	{
		"name": "canopy trees", "ids": [TREE_A, TREE_B], "density": 0.085, "d_min": 2.2, "d_max": 14.0,
		"scale": Vector2(0.85, 1.25), "align": 0.0, "tilt": 3.0, "spacing": 3.2,
		"max_slope": 40.0, "sink": -0.15,
	},
	{
		# The native araucaria, as one common tree among the others, not a feature.
		"name": "araucaria", "ids": [ARAUCARIA], "density": 0.03, "d_min": 6.0, "d_max": 16.0,
		"scale": Vector2(0.7, 0.95), "align": 0.0, "tilt": 2.0, "spacing": 7.0,
		"max_slope": 40.0, "sink": -0.2,
	},
]

## The house's size in its own metres (X by Z), including nothing outside the walls.
const HOUSE_SIZE: Vector2 = Vector2(11.625, 15.5)
## Where the doors are along the house's local X: the front door is on the
## local +Z wall, the back door on the local -Z wall.
const FRONT_DOOR_LOCAL_X: float = 4.65
const BACK_DOOR_LOCAL_X: float = 2.325


## The roof overhangs the walls by this much.
const ROOF_OVERHANG: float = 0.5
## Extra distance kept between a plant's reach and the house.
const SAFE_GAP: float = 0.3
## No plant reaches further than this (the biggest trees), so only plants within
## this distance of the house are checked.
const MAX_PLANT_REACH: float = 9.0
## Colliders are baked for the plants within this distance of the walls.
const COLLIDER_REACH: float = 13.0

const TREE_IDS: Array[int] = [TREE_A, TREE_B, PITANGUEIRA, ARAUCARIA]

## Collider radius per plant at scale 1, in metres: the trunk for trees, the
## dense core for bushes and tall plants. Ferns, grass and small plants have no
## collider.
const COLLIDER_RADIUS: Dictionary = {
	TREE_A: 0.55, TREE_B: 0.4, PITANGUEIRA: 0.32, ARAUCARIA: 0.6,
	BUSH_A: 0.7, BUSH_B: 0.62, TALL_PLANT_A: 0.28, TALL_PLANT_B: 0.26,
}
## World XZ of the house's local origin (its north-east corner after the turn).
var origin: Vector2 = Vector2(141.0, 78.5)

## Ground painted beyond the walls, and the distance the level ground blends back
## into the hillside.
var margin: float = 0.6
var flatten_blend: float = 10.0
## East of the house the hillside climbs on, so it blends back over a longer run.
var flatten_blend_east: float = 18.0

## The trail strips painted from each door out to the existing path.
## How far below the trail, six metres before the front door, the house floor sits.
## The ground slopes down into the clearing, so the house is first seen from above.
var approach_drop: float = 1.8

var trail_half_width: float = 1.4
var trail_length: float = 8.0

var dirt_texture_id: int = 1

## Area whose plants are replaced; it must cover the house and the forest band
## around it (the vegetation tool grows plants up to 18 m from a path).
var vegetation_zone: Rect2 = Rect2(100.0, 60.0, 82.0, 54.0)
var seed_value: int = 20261007

var _terrain: Terrain3D = null
var _data: Terrain3DData = null
var _control_value: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _extents: Dictionary = {}


## World-space rectangle covered by the house's walls.
func footprint() -> Rect2:
	return Rect2(origin.x - HOUSE_SIZE.y, origin.y, HOUSE_SIZE.y, HOUSE_SIZE.x)


## World Z of the front and back doors (they open west and east).
func front_door_z() -> float:
	return origin.y + FRONT_DOOR_LOCAL_X


func back_door_z() -> float:
	return origin.y + BACK_DOOR_LOCAL_X


## Runs every step and returns {"height", "painted", "removed", "added",
## "boundaries"}; the caller saves the terrain data and the walls scene.
func build(terrain: Terrain3D) -> Dictionary:
	_terrain = terrain
	_data = terrain.data
	_rng.seed = seed_value

	var approach: Vector3 = Vector3(footprint().position.x - 6.0, 0.0, front_door_z())
	var height: float = flatten_ground(_data.get_height(approach) - approach_drop)
	var painted: int = paint_floor()

	var generator = VegetationGenerator.new()
	generator.zone = vegetation_zone
	generator.seed_value = seed_value
	var planted: Dictionary = generator.generate(terrain)

	# After the forest tool, which repaints the ground inside its zone.
	mix_floor_textures()
	var cleared: int = clear_unsafe_plants()
	var overgrown: int = scatter_overgrowth()
	var colliders: Dictionary = build_colliders()

	var boundaries = BoundaryBuilder.new()
	var walls: Dictionary = boundaries.build(terrain)

	return {
		"height": height,
		"painted": painted,
		"removed": planted.get("removed", 0),
		"added": planted.get("added", 0),
		"cleared_unsafe": cleared,
		"overgrowth": overgrown,
		"colliders": colliders["count"],
		"colliders_scene": colliders["scene"],
		"boundaries": walls,
	}


## Levels the pad (footprint plus margin) to `target` and
## blends outward. Returns the level height (NAN if the area has no terrain).
func flatten_ground(target: float) -> float:
	var pad: Rect2 = footprint().grow(margin)
	var reach: int = int(ceilf(maxf(flatten_blend, flatten_blend_east))) + 1
	if is_nan(target):
		return NAN


	for cell: Vector2 in _cells_in(pad.grow(float(reach))):
		var outside: float = _distance_to_rect(cell, pad)
		# The blend grows smoothly from the middle of the pad eastwards (no seam).
		var blend: float = lerpf(
			flatten_blend,
			flatten_blend_east,
			smoothstep(pad.get_center().x, pad.end.x + 6.0, cell.x)
		)
		if outside >= blend:
			continue

		var point: Vector3 = Vector3(cell.x, 0.0, cell.y)
		var current: float = _data.get_height(point)
		if is_nan(current):
			continue

		var weight: float = 1.0 - smoothstep(0.0, blend, outside)
		_data.set_height(point, lerpf(current, target, weight))

	_mark_regions_modified(Terrain3DRegion.TYPE_HEIGHT)
	_data.calc_height_range(true)
	return target


## Paints the pad and the two trail strips with the path's own control value
## (dirt base), so the tools see them as walkable ground.
func paint_floor() -> int:
	if not _find_reference_control():
		push_error("HouseTerrainBuilder: no path dirt found near the house to copy.")
		return 0

	var painted: int = 0
	for cell: Vector2 in _floor_cells():
		var point: Vector3 = Vector3(cell.x, 0.0, cell.y)
		if is_nan(_data.get_height(point)):
			continue

		_data.set_control(point, _control_value)
		painted += 1

	_mark_regions_modified(Terrain3DRegion.TYPE_CONTROL)
	return painted


## Mixes the floor textures cell by cell (humus, leaf litter, moss, needles and
## grass patches, mostly at the edges). Every cell keeps dirt as its base, which
## is what marks it as walkable to the other tools.
func mix_floor_textures() -> void:
	var patch_noise: FastNoiseLite = FastNoiseLite.new()
	patch_noise.seed = seed_value + 21
	patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patch_noise.frequency = 0.16

	var fine_noise: FastNoiseLite = FastNoiseLite.new()
	fine_noise.seed = seed_value + 22
	fine_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine_noise.frequency = 0.55

	var pad: Rect2 = footprint().grow(margin)
	for cell: Vector2 in _floor_cells():
		var world: Vector3 = Vector3(cell.x, 0.0, cell.y)
		if is_nan(_data.get_height(world)):
			continue

		var patch: float = patch_noise.get_noise_2d(cell.x, cell.y)
		var fine: float = fine_noise.get_noise_2d(cell.x, cell.y) * 0.5 + 0.5
		# Greener the further a cell is from the house.
		var edge: float = smoothstep(0.0, 3.0, _distance_to_rect(cell, pad))

		var overlay: int = TEX_HUMUS
		var blend: float = 0.18 + fine * 0.26
		var green: float = patch * 0.6 + edge * 0.7 + (fine - 0.5) * 0.5
		var is_green: bool = green > 0.34

		if is_green:
			# Grass or moss growing over the dirt; it still counts as path.
			overlay = TEX_GRASS if fine > 0.35 else TEX_MOSS
			blend = clampf(0.55 + green * 0.5, 0.55, 0.95)
		elif patch < -0.25:
			overlay = TEX_MOSS
			blend = 0.2 + fine * 0.22
		elif fine > 0.62:
			overlay = TEX_PINE_MULCH
			blend = 0.2 + (fine - 0.62) * 0.7
		elif patch > 0.1:
			overlay = TEX_FOREST_FLOOR
			blend = 0.2 + fine * 0.24

		blend += _rng.randf_range(-0.07, 0.07)
		# Only green cells may pass 50 %; anything else must stay dirt-dominant.
		if not is_green:
			blend = clampf(blend, 0.05, 0.46)

		_data.set_control_base_id(world, dirt_texture_id)
		_data.set_control_overlay_id(world, overlay)
		_data.set_control_blend(world, clampf(blend, 0.05, 0.95))
		_data.set_control_auto(world, false)

	_mark_regions_modified(Terrain3DRegion.TYPE_CONTROL)


# ============================================================
# HELPERS
# ============================================================

## Whole terrain cells to paint: the pad plus a trail strip from each door,
## west of the front door and east of the back door.
func _floor_cells() -> Array[Vector2]:
	var pad: Rect2 = footprint().grow(margin)
	var front: Rect2 = Rect2(
		pad.position.x - trail_length,
		front_door_z() - trail_half_width,
		trail_length + margin,
		trail_half_width * 2.0
	)
	var back: Rect2 = Rect2(
		pad.end.x - margin,
		back_door_z() - trail_half_width,
		trail_length + margin,
		trail_half_width * 2.0
	)

	var seen: Dictionary = {}
	var cells: Array[Vector2] = []
	for area: Rect2 in [pad, front, back]:
		for cell: Vector2 in _cells_in(area):
			if not seen.has(cell):
				seen[cell] = true
				cells.append(cell)

	return cells


## Whole terrain cells whose corner lies inside a rectangle.
func _cells_in(area: Rect2) -> Array[Vector2]:
	var cells: Array[Vector2] = []
	for z: int in range(int(floorf(area.position.y)), int(ceilf(area.end.y)) + 1):
		for x: int in range(int(floorf(area.position.x)), int(ceilf(area.end.x)) + 1):
			cells.append(Vector2(float(x), float(z)))

	return cells


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var dx: float = maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dz: float = maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dz).length()


## Copies the control value of existing path dirt near the house.
func _find_reference_control() -> bool:
	var center: Vector2 = footprint().get_center()
	for radius: int in range(0, 40):
		for dz: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue

				var point: Vector3 = Vector3(floorf(center.x) + dx, 0.0, floorf(center.y) + dz)
				if _is_path_dirt(point):
					_control_value = _data.get_control(point)
					return true

	return false


func _is_path_dirt(point: Vector3) -> bool:
	if is_nan(_data.get_height(point)):
		return false

	var ids: Vector3 = _data.get_texture_id(point)
	if ids.z < 0.5:
		return int(ids.x) == dirt_texture_id

	return int(ids.y) == dirt_texture_id and ids.z > 0.85


## Marks every region under the vegetation zone as modified so the data saves.
func _mark_regions_modified(map_type: int) -> void:
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


# ============================================================
# PLANTS UNDER AND AROUND THE HOUSE
# ============================================================

## Removes every plant too close to the house. How close is "too close" depends
## on the plant: a fern's leaves reach well past its stem, so a plant is removed
## when the house (walls plus roof overhang) is nearer than its own reach plus a
## small gap. Everything inside the footprint goes. Returns the count.
func clear_unsafe_plants() -> int:
	var house: Rect2 = footprint().grow(ROOF_OVERHANG)
	var area: Rect2 = house.grow(MAX_PLANT_REACH)
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var removed: int = 0

	for region: Terrain3DRegion in _data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		if not Rect2(offset, Vector2(region_size, region_size)).intersects(area):
			continue

		var instances: Dictionary = region.get_instances()
		for mesh_id: int in instances.keys():
			var kept_transforms: Array[Transform3D] = []
			var kept_colors: PackedColorArray = PackedColorArray()
			var removed_here: int = 0

			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in range(cell_transforms.size()):
					var transform: Transform3D = cell_transforms[i]
					var world: Vector2 = Vector2(
						transform.origin.x + offset.x, transform.origin.z + offset.y
					)
					var safe: float = plant_reach(mesh_id, transform.basis.get_scale()) + SAFE_GAP
					if _distance_to_rect(world, house) < safe:
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


## Dense growth around the house (ferns, leafy plants, grass, bushes, tall
## plants, shrub trees and canopy trees), so it looks like the forest has been
## reclaiming a house that was never meant to be there. Every plant keeps its own
## safe distance from the walls (see plant_reach); the two trail strips in front
## of the doors stay open. Returns the number of plants placed.
func scatter_overgrowth() -> int:
	var house: Rect2 = footprint().grow(ROOF_OVERHANG)
	var outer: Rect2 = footprint().grow(OVERGROWTH_REACH)
	var corridors: Array[Rect2] = _corridors()
	var clump_noise: FastNoiseLite = FastNoiseLite.new()
	clump_noise.seed = seed_value + 41
	clump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	clump_noise.frequency = 0.22

	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var placed: int = 0

	for layer: Dictionary in OVERGROWTH:
		var ids: Array = layer["ids"]
		var per_mesh: Dictionary = {}
		var colors: Dictionary = {}
		var taken: Array[Vector2] = []
		var spacing: float = float(layer.get("spacing", 0.0))

		var candidates: int = int(float(layer["density"]) * outer.get_area() * 1.6)
		for i: int in candidates:
			var point: Vector2 = Vector2(
				_rng.randf_range(outer.position.x, outer.end.x),
				_rng.randf_range(outer.position.y, outer.end.y)
			)
			var distance: float = _distance_to_rect(point, house)
			if distance > float(layer["d_max"]) or _in_any(point, corridors):
				continue

			var mesh_id: int = int(ids[_rng.randi_range(0, ids.size() - 1)])
			var uniform_scale: float = _rng.randf_range(
				(layer["scale"] as Vector2).x, (layer["scale"] as Vector2).y
			)
			var width_scale: float = uniform_scale * _rng.randf_range(0.9, 1.1)
			var reach: float = plant_reach(mesh_id, Vector3(width_scale, uniform_scale, width_scale))
			if distance < reach + SAFE_GAP:
				continue

			# Thin out with distance so the growth fades into the existing forest.
			var thin: float = distance / (float(layer["d_max"]) + 0.01)
			if _rng.randf() < thin * 0.6:
				continue

			if clump_noise.get_noise_2d(point.x + float(i % 5), point.y) < -0.35 + _rng.randf() * 0.5:
				continue

			if spacing > 0.0 and _too_close(point, taken, spacing):
				continue

			var world: Vector3 = Vector3(point.x, 0.0, point.y)
			var height: float = _data.get_height(world)
			if is_nan(height):
				continue

			var normal: Vector3 = _data.get_normal(world)
			if normal.y < cos(deg_to_rad(float(layer.get("max_slope", 55.0)))):
				continue

			var up: Vector3 = Vector3.UP.lerp(normal, float(layer["align"])).normalized()
			var basis: Basis = Basis(Quaternion(Vector3.UP, up))
			basis = basis * Basis(Vector3.UP, _rng.randf() * TAU)
			var tilt: float = deg_to_rad(float(layer.get("tilt", 0.0)))
			if tilt > 0.0:
				basis = basis * Basis.from_euler(Vector3(
					_rng.randf_range(-tilt, tilt), 0.0, _rng.randf_range(-tilt, tilt)
				))
			basis = basis.scaled_local(Vector3(width_scale, uniform_scale, width_scale))

			if not per_mesh.has(mesh_id):
				var list: Array[Transform3D] = []
				per_mesh[mesh_id] = list
				colors[mesh_id] = PackedColorArray()

			(per_mesh[mesh_id] as Array[Transform3D]).append(Transform3D(
				basis, Vector3(point.x, height + float(layer.get("sink", 0.0)), point.y)
			))
			var shade: float = _rng.randf_range(0.75, 1.0)
			(colors[mesh_id] as PackedColorArray).append(Color(shade, shade, shade, 1.0))
			taken.append(point)

		for mesh_id: int in per_mesh:
			var transforms: Array[Transform3D] = per_mesh[mesh_id]
			instancer.add_transforms(mesh_id, transforms, colors[mesh_id])
			placed += transforms.size()

	return placed


## How far a plant reaches sideways from its stem, in metres: the leaves of a
## fern or bush spread over most of the mesh's width, a tree's canopy over about
## 45 % of it (the rest is thin outer foliage).
func plant_reach(mesh_id: int, scale: Vector3) -> float:
	var extent: Vector3 = _mesh_extent(mesh_id)
	var width: float = maxf(extent.x, extent.z) * maxf(scale.x, scale.z)
	return width * (0.45 if mesh_id in TREE_IDS else 0.42)


## Bakes simple colliders for the trees, bushes and tall plants around the house
## into a scene (the Terrain3D plants have none): a cylinder for each trunk, and a
## narrower one for each bush or tall plant. Returns {"scene": PackedScene,
## "count": int}. The scene's coordinates are world coordinates; instance it at
## the origin of the level.
func build_colliders() -> Dictionary:
	var house: Rect2 = footprint()
	var area: Rect2 = house.grow(COLLIDER_REACH)
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "HouseForestColliders"
	var shapes: Dictionary = {}
	var count: int = 0

	for region: Terrain3DRegion in _data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		if not Rect2(offset, Vector2(region_size, region_size)).intersects(area):
			continue

		var instances: Dictionary = region.get_instances()
		for mesh_id: int in COLLIDER_RADIUS:
			if not instances.has(mesh_id):
				continue

			var is_tree: bool = mesh_id in TREE_IDS
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				for transform: Transform3D in cells[cell][0]:
					var world: Vector2 = Vector2(
						transform.origin.x + offset.x, transform.origin.z + offset.y
					)
					if not area.has_point(world):
						continue

					var scale: Vector3 = transform.basis.get_scale()
					var radius: float = snappedf(
						float(COLLIDER_RADIUS[mesh_id]) * maxf(scale.x, scale.z), 0.1
					)
					var height: float = 8.0 if is_tree else 3.0
					var key: String = "%.1f_%.1f" % [radius, height]
					if not shapes.has(key):
						var cylinder: CylinderShape3D = CylinderShape3D.new()
						cylinder.radius = maxf(radius, 0.1)
						cylinder.height = height
						shapes[key] = cylinder

					var shape: CollisionShape3D = CollisionShape3D.new()
					shape.shape = shapes[key] as CylinderShape3D
					shape.position = Vector3(
						world.x, transform.origin.y + height * 0.5 - 0.3, world.y
					)
					body.add_child(shape)
					count += 1

	for child: Node in body.get_children():
		child.owner = body

	var scene: PackedScene = PackedScene.new()
	scene.pack(body)
	body.free()
	return {"scene": scene, "count": count}


func _mesh_extent(mesh_id: int) -> Vector3:
	if _extents.has(mesh_id):
		return _extents[mesh_id] as Vector3

	var extent: Vector3 = Vector3.ONE
	var asset: Terrain3DMeshAsset = _terrain.assets.get_mesh_asset(mesh_id)
	if asset != null and asset.get_mesh() != null:
		extent = asset.get_mesh().get_aabb().size

	_extents[mesh_id] = extent
	return extent


## The two open strips in front of the doors (a bit wider than the trail).
func _corridors() -> Array[Rect2]:
	var house: Rect2 = footprint()
	var half: float = trail_half_width + 0.5
	return [
		Rect2(house.position.x - trail_length - 2.0, front_door_z() - half, trail_length + 2.0, half * 2.0),
		Rect2(house.end.x, back_door_z() - half, trail_length + 2.0, half * 2.0),
	]


func _in_any(point: Vector2, areas: Array[Rect2]) -> bool:
	for area: Rect2 in areas:
		if area.has_point(point):
			return true

	return false


func _too_close(point: Vector2, others: Array[Vector2], spacing: float) -> bool:
	for other: Vector2 in others:
		if point.distance_squared_to(other) < spacing * spacing:
			return true

	return false
