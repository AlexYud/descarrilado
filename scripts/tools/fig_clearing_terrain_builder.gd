extends RefCounted

## Prepares the dream intro terrain for the fig tree clearing: levels a disc of
## ground (blending back into the slope), paints it as path (dirt base, so the
## vegetation and wall tools treat it as walkable), mixes the floor textures,
## scatters small plants over it, regrows the forest around it and rebuilds the
## invisible path walls.
##
## The clearing sits on the top of the northern path's loop, so the path enters
## it from the west and leaves to the east; it is a pass-through with no gate.
## Editor entry point: build_fig_clearing_terrain.gd.

const VegetationGenerator := preload("res://scripts/tools/forest_path_vegetation_generator.gd")
const BoundaryBuilder := preload("res://scripts/tools/forest_boundary_builder.gd")

const CLEARING_SCENE_PATH: String = "res://scenes/levels/fig_clearing.tscn"

# Terrain3D texture slots (see PROJECT_CONTEXT.md, ground textures).
const TEX_GRASS: int = 0
const TEX_FOREST_FLOOR: int = 2
const TEX_MOSS: int = 3
const TEX_HUMUS: int = 4
const TEX_PINE_MULCH: int = 5

# Terrain3D mesh ids used by the forest tools.
const FERN: int = 9
const LITTER: int = 5
const GRASS_A: int = 11
const GRASS_B: int = 12
const FLOWER_A: int = 8
const FLOWER_B: int = 20
const ROCK_A: int = 17
const ROCK_B: int = 18

## Small plants on the clearing floor. `density` is plants per square metre;
## `bias` above 1 favours the small end of `scale`.
const FLOOR_PLANTS: Array[Dictionary] = [
	{
		"name": "grass tufts", "ids": [GRASS_A, GRASS_B], "density": 2.4,
		"scale": Vector2(0.26, 0.7), "bias": 1.6, "align": 0.8, "tilt": 14.0,
	},
	{
		"name": "small ferns", "ids": [FERN], "density": 0.5,
		"scale": Vector2(0.16, 0.42), "bias": 1.3, "align": 0.6, "tilt": 10.0,
	},
	{
		"name": "flowers", "ids": [FLOWER_A, FLOWER_B], "density": 0.2,
		"scale": Vector2(0.4, 0.8), "bias": 1.0, "align": 0.3, "tilt": 8.0,
	},
	{
		"name": "leaf litter", "ids": [LITTER], "density": 0.8,
		"scale": Vector2(0.18, 0.34), "bias": 1.0, "align": 1.0, "tilt": 0.0,
		"max_slope": 14.0, "sink": -0.02,
	},
	{
		"name": "small stones", "ids": [ROCK_A, ROCK_B], "density": 0.06,
		"scale": Vector2(0.4, 0.8), "bias": 1.4, "align": 0.0, "tilt": 0.0,
	},
]

## Nodes of the clearing scene that keep plants away, with a clearance radius
## in metres. Photographs and the cup lie on the ground and must stay visible.
const PROP_CLEARANCE: Dictionary = {
	"Scenery/Tent": 2.0,
	"Scenery/Tent2": 2.0,
	"Scenery/CampTable": 1.3,
	"Scenery/Campfire": 1.0,
	"Scenery/FigBase": 1.8,
	"Scenery/EnamelCup": 0.5,
	"Props/PhotoChildhood": 0.5,
	"Props/PhotoAdolescence": 0.5,
	"Props/PhotoRecent": 0.5,
}

## Centre of the clearing, on the straight top stretch of the northern loop.
## Kept west of x = 69: the ground drops about 7 m in 8 m east of x = 82.
var center: Vector2 = Vector2(64.0, -68.0)

## Radius of the level, painted ground (the clearing floor).
var flat_radius: float = 7.5

## Distance over which the level ground blends back into the hillside.
var flatten_blend: float = 8.0

var dirt_texture_id: int = 1

## Area whose plants are replaced; it must cover the clearing and the forest
## band around it (the vegetation tool grows plants up to 18 m from a path).
var vegetation_zone: Rect2 = Rect2(29.0, -92.0, 70.0, 48.0)
var seed_value: int = 20261004

var _terrain: Terrain3D = null
var _data: Terrain3DData = null
var _control_value: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _props: Array[Dictionary] = []


## Runs every step and returns {"height", "painted", "removed", "added",
## "floor_plants", "boundaries"}; the caller saves the terrain data and the
## walls scene.
func build(terrain: Terrain3D) -> Dictionary:
	_terrain = terrain
	_data = terrain.data
	_rng.seed = seed_value
	_read_props()

	var height: float = flatten_ground()
	var painted: int = paint_floor()

	var generator = VegetationGenerator.new()
	generator.zone = vegetation_zone
	generator.seed_value = seed_value
	var planted: Dictionary = generator.generate(terrain)

	# After the forest tool, which repaints the ground inside its zone.
	mix_floor_textures()
	var floor_plants: int = scatter_floor_plants()

	var boundaries = BoundaryBuilder.new()
	var walls: Dictionary = boundaries.build(terrain)

	return {
		"height": height,
		"painted": painted,
		"removed": planted.get("removed", 0),
		"added": planted.get("added", 0),
		"floor_plants": floor_plants,
		"boundaries": walls,
	}


## Levels the disc to the average height under it and blends outward.
## Returns the level height (NAN if the area has no terrain).
func flatten_ground() -> float:
	var reach: int = int(ceilf(flat_radius + flatten_blend))

	var total: float = 0.0
	var count: int = 0
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: Vector2 = Vector2(floorf(center.x) + dx, floorf(center.y) + dz)
			if cell.distance_to(center) > flat_radius:
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
			var cell: Vector2 = Vector2(floorf(center.x) + dx, floorf(center.y) + dz)
			var outside: float = cell.distance_to(center) - flat_radius
			if outside >= flatten_blend:
				continue

			var point: Vector3 = Vector3(cell.x, 0.0, cell.y)
			var current: float = _data.get_height(point)
			if is_nan(current):
				continue

			var weight: float = 1.0 - smoothstep(0.0, flatten_blend, maxf(outside, 0.0))
			_data.set_height(point, lerpf(current, target, weight))

	_mark_regions_modified(Terrain3DRegion.TYPE_HEIGHT)
	_data.calc_height_range(true)
	return target


## Paints the clearing floor with the path's own control value (dirt base), so
## the tools see it as walkable ground.
func paint_floor() -> int:
	if not _find_reference_control():
		push_error("FigClearingTerrainBuilder: no path dirt found near the clearing to copy.")
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


## Mixes the floor textures cell by cell: grass patches, moss, leaf litter,
## humus and needles, on small and large scales so no stretch reads as one flat
## colour. Every cell keeps dirt as its base texture, which is what marks it as
## walkable to the other tools. Ground close to the props is worn bare.
func mix_floor_textures() -> void:
	var patch_noise: FastNoiseLite = FastNoiseLite.new()
	patch_noise.seed = seed_value + 21
	patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patch_noise.frequency = 0.16

	var fine_noise: FastNoiseLite = FastNoiseLite.new()
	fine_noise.seed = seed_value + 22
	fine_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine_noise.frequency = 0.55

	for cell: Vector2 in _floor_cells():
		var world: Vector3 = Vector3(cell.x, 0.0, cell.y)
		if is_nan(_data.get_height(world)):
			continue

		var patch: float = patch_noise.get_noise_2d(cell.x, cell.y)
		var fine: float = fine_noise.get_noise_2d(cell.x, cell.y) * 0.5 + 0.5
		var rim: float = smoothstep(flat_radius - 3.5, flat_radius, cell.distance_to(center))
		var worn: float = 1.0 - smoothstep(0.0, 1.6, _distance_to_props(cell))

		var overlay: int = TEX_HUMUS
		var blend: float = 0.18 + fine * 0.26
		var green: float = patch * 0.6 + rim * 0.7 + (fine - 0.5) * 0.5 - worn * 0.9
		var is_green: bool = green > 0.32

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


## Scatters small plants over the clearing floor in loose clumps, keeping the
## props, the photographs and the cup clear. Returns the number placed.
func scatter_floor_plants() -> int:
	var clump_noise: FastNoiseLite = FastNoiseLite.new()
	clump_noise.seed = seed_value + 31
	clump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	clump_noise.frequency = 0.3

	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var area: float = PI * flat_radius * flat_radius
	var placed: int = 0

	for layer: Dictionary in FLOOR_PLANTS:
		var ids: Array = layer["ids"]
		var per_mesh: Dictionary = {}
		var colors: Dictionary = {}

		# Twice as many candidates as needed; the clump noise rejects about half.
		var candidates: int = int(float(layer["density"]) * area * 2.0)
		for i: int in candidates:
			var angle: float = _rng.randf() * TAU
			var radius: float = sqrt(_rng.randf()) * (flat_radius - 0.4)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius

			if _distance_to_props(point) < 0.0:
				continue

			if clump_noise.get_noise_2d(point.x + float(i % 7), point.y) < -0.1 + _rng.randf() * 0.5:
				continue

			var world: Vector3 = Vector3(point.x, 0.0, point.y)
			var height: float = _data.get_height(world)
			if is_nan(height):
				continue

			var normal: Vector3 = _data.get_normal(world)
			if normal.y < cos(deg_to_rad(float(layer.get("max_slope", 55.0)))):
				continue

			var uniform_scale: float = lerpf(
				(layer["scale"] as Vector2).x,
				(layer["scale"] as Vector2).y,
				pow(_rng.randf(), float(layer["bias"]))
			)
			var up: Vector3 = Vector3.UP.lerp(normal, float(layer["align"])).normalized()
			var basis: Basis = Basis(Quaternion(Vector3.UP, up))
			basis = basis * Basis(Vector3.UP, _rng.randf() * TAU)
			var tilt: float = deg_to_rad(float(layer["tilt"]))
			if tilt > 0.0:
				basis = basis * Basis.from_euler(Vector3(
					_rng.randf_range(-tilt, tilt), 0.0, _rng.randf_range(-tilt, tilt)
				))

			var width_scale: float = uniform_scale * _rng.randf_range(0.9, 1.1)
			basis = basis.scaled_local(Vector3(width_scale, uniform_scale, width_scale))

			var mesh_id: int = int(ids[_rng.randi_range(0, ids.size() - 1)])
			if not per_mesh.has(mesh_id):
				var list: Array[Transform3D] = []
				per_mesh[mesh_id] = list
				colors[mesh_id] = PackedColorArray()

			(per_mesh[mesh_id] as Array[Transform3D]).append(Transform3D(
				basis,
				Vector3(point.x, height + float(layer.get("sink", 0.0)), point.y)
			))
			var shade: float = _rng.randf_range(0.78, 1.0)
			(colors[mesh_id] as PackedColorArray).append(Color(shade, shade, shade, 1.0))

		for mesh_id: int in per_mesh:
			var transforms: Array[Transform3D] = per_mesh[mesh_id]
			instancer.add_transforms(mesh_id, transforms, colors[mesh_id])
			placed += transforms.size()

	return placed


# ============================================================
# HELPERS
# ============================================================

## Whole terrain cells whose centre lies inside the clearing floor.
func _floor_cells() -> Array[Vector2]:
	var cells: Array[Vector2] = []
	var reach: int = int(ceilf(flat_radius))
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: Vector2 = Vector2(floorf(center.x) + dx, floorf(center.y) + dz)
			if cell.distance_to(center) <= flat_radius:
				cells.append(cell)

	return cells


## Reads where the clearing scene puts its props, in world space.
func _read_props() -> void:
	_props.clear()
	var scene: Node = (load(CLEARING_SCENE_PATH) as PackedScene).instantiate()
	for path: String in PROP_CLEARANCE:
		var node: Node3D = scene.get_node_or_null(path) as Node3D
		if node == null:
			push_warning("FigClearingTerrainBuilder: '%s' is not in the clearing scene." % path)
			continue

		_props.append({
			"position": center + Vector2(node.position.x, node.position.z),
			"radius": float(PROP_CLEARANCE[path]),
		})

	scene.free()


## Distance from a point to the nearest prop's clearance circle (negative when
## inside it).
func _distance_to_props(point: Vector2) -> float:
	var nearest: float = INF
	for prop: Dictionary in _props:
		nearest = minf(
			nearest,
			point.distance_to(prop["position"] as Vector2) - float(prop["radius"])
		)

	return nearest


## Copies the control value of existing path dirt on the loop's top stretch.
func _find_reference_control() -> bool:
	for radius: int in range(0, 40):
		for dx: int in range(-radius, radius + 1):
			var point: Vector3 = Vector3(floorf(center.x) + dx, 0.0, center.y)
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


func _mark_regions_modified(map_type: int) -> void:
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var span: float = flat_radius + flatten_blend + 4.0
	var x: float = center.x - span
	while x <= center.x + span + region_size:
		var z: float = center.y - span
		while z <= center.y + span + region_size:
			var region: Terrain3DRegion = _data.get_regionp(Vector3(x, 0.0, z))
			if region != null:
				region.set_modified(true)

			z += region_size

		x += region_size
