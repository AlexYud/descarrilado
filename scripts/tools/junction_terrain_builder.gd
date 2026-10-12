extends RefCounted

## Prepares the dream intro terrain for the waiting shed and signal box.
##
## The shed sits on the straight east-west stretch of the middle path (B), where the
## hillside falls about 16 degrees to the east. The clearing itself is level, so the
## shelter, the bench and the rails stand on solid ground (a tilted pad left the
## shelter floating above the downhill side); the path is graded to meet it:
## - the clearing is an irregular blob (an ellipse with a wavering outline), not a
##   circle, and small: just room for the shelter, the trail and the railway;
## - inside it the ground is level, at the hillside's average height, and blends
##   back into the hillside over a short run;
## - the path leaves it climbing west and descending east at a gentle grade
##   (`corridor_slope`), in a cutting or on an embankment, instead of the steep
##   ramps a flat pad would otherwise make;
## - the railway runs north to south, level, in a straight cutting that continues
##   into the forest on both sides, where the vegetation closes over it.
## It also paints the clearing as path (dirt base, so the vegetation and wall tools
## treat it as walkable), mixes its textures, scatters small plants, grows clumps of
## bushes along the rim and over the rails' ends, regrows the forest around it and
## rebuilds the invisible path walls.
## Run through relocate_puzzle_sites.gd.

const VegetationGenerator := preload("res://scripts/tools/forest_path_vegetation_generator.gd")
const BoundaryBuilder := preload("res://scripts/tools/forest_boundary_builder.gd")

# Terrain3D texture slots (see PROJECT_CONTEXT.md, ground textures).
const TEX_GRASS: int = 0
const TEX_FOREST_FLOOR: int = 2
const TEX_MOSS: int = 3
const TEX_HUMUS: int = 4
const TEX_PINE_MULCH: int = 5

# Terrain3D mesh ids used by the forest tools.
const BUSH_A: int = 0
const BUSH_B: int = 4
const PITANGUEIRA: int = 3
const FERN: int = 9
const LITTER: int = 5
const MEDIUM_PLANT: int = 6
const TALL_PLANT_A: int = 7
const TALL_PLANT_B: int = 13
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
		"name": "grass tufts", "ids": [GRASS_A, GRASS_B], "density": 1.6,
		"scale": Vector2(0.26, 0.7), "bias": 1.6, "align": 0.8, "tilt": 14.0,
	},
	{
		"name": "small ferns", "ids": [FERN], "density": 0.3,
		"scale": Vector2(0.16, 0.42), "bias": 1.3, "align": 0.6, "tilt": 10.0,
	},
	{
		"name": "flowers", "ids": [FLOWER_A, FLOWER_B], "density": 0.1,
		"scale": Vector2(0.4, 0.8), "bias": 1.0, "align": 0.3, "tilt": 8.0,
	},
	{
		"name": "leaf litter", "ids": [LITTER], "density": 0.5,
		"scale": Vector2(0.18, 0.34), "bias": 1.0, "align": 1.0, "tilt": 0.0,
		"max_slope": 14.0, "sink": -0.02,
	},
	{
		"name": "small stones", "ids": [ROCK_A, ROCK_B], "density": 0.04,
		"scale": Vector2(0.4, 0.8), "bias": 1.4, "align": 0.0, "tilt": 0.0,
	},
]

## Plants that grow along the rim, so the clearing's edge is ragged and green.
const RIM_PLANTS: Array[Dictionary] = [
	{"ids": [BUSH_A, BUSH_B], "scale": Vector2(0.7, 1.15), "weight": 3.0},
	{"ids": [TALL_PLANT_A, TALL_PLANT_B], "scale": Vector2(0.8, 1.3), "weight": 2.0},
	{"ids": [FERN], "scale": Vector2(0.8, 1.4), "weight": 3.0},
	{"ids": [MEDIUM_PLANT], "scale": Vector2(0.8, 1.3), "weight": 2.0},
	{"ids": [PITANGUEIRA], "scale": Vector2(0.7, 1.0), "weight": 0.3},
]

## Where things stand, in the shed scene's own metres (x east, z south, the origin
## at the middle of the clearing). Plants keep clear of these.
const PROP_CIRCLES: Array[Dictionary] = [
	{"position": Vector2(-8.5, -2.4), "radius": 1.6},
]
const PROP_RECTS: Array[Rect2] = [
	Rect2(-7.3, -8.5, 8.6, 6.0),
	Rect2(3.4, -22.0, 5.2, 44.0),
]

## Centre of the clearing: the shed scene's origin, on the middle path's straight
## east-west stretch (the path runs along z = -16 there). The railway runs north to
## south at x = center.x + 6 (71), on the line of the fig clearing and the house.
var center: Vector2 = Vector2(65.0, -16.0)

## The clearing: an ellipse (local centre and radii in metres) whose outline
## wavers; its edge is where `blob_field` is 1.
var blob_center: Vector2 = Vector2(-0.5, -3.2)
var blob_radii: Vector2 = Vector2(11.0, 8.0)

## How much of the hillside's own slope the clearing keeps along the path.
var path_tilt: float = 0.0
## The clearing sits this much above the hillside's average height (less cutting on
## the uphill side, where the path would otherwise climb steeply out of its cutting).
var pad_height_bias: float = 0.8
## The grade of the railway along its length (dy/dz) and where it lies.
var rails_slope_z: float = 0.0
var rails_x: float = 6.0
var rails_z_range: Vector2 = Vector2(-21.0, 21.0)
var rails_half_width: float = 2.8
var rails_blend: float = 5.0

## The flat platform under the shelter (local centre and size) and how far it
## blends into the tilted ground.
var platform_center: Vector2 = Vector2(-3.0, -5.5)
var platform_size: Vector2 = Vector2(8.6, 6.0)
var platform_blend: float = 2.5

## Distance over which the clearing's ground blends back into the hillside.
var blend_length: float = 14.0

## Half width of the worn dirt trail along the path through the clearing.
var trail_half_width: float = 1.3

var dirt_texture_id: int = 1

## Area whose plants are replaced; it must cover the clearing and the forest
## band around it (the vegetation tool grows plants up to 18 m from a path). Its
## north edge stops where the fig clearing's own area begins; it must also cover
## the whole graded area (the path out to 40 m each way, the railway 29 m each way).
var vegetation_zone: Rect2 = Rect2(22.0, -46.0, 86.0, 70.0)
var seed_value: int = 20261011

## The path leaves the clearing in a graded cutting (west) and embankment (east): it
## follows the hillside's profile and the offset between the clearing and the hillside
## eases away over `corridor_fade` metres (then `corridor_end` more); flat across.
var corridor_fade: float = 24.0
var corridor_end: float = 4.0
var corridor_half_width: float = 2.4
var corridor_blend: float = 7.0

## Filled in by flatten_ground(): the plane heights and tilt (flat: zero tilt).
var plane_height: float = 0.0
var plane_slope: Vector2 = Vector2.ZERO

var _terrain: Terrain3D = null
var _data: Terrain3DData = null
var _control_value: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _natural: Dictionary = {}


## Runs every step and returns what the scene needs: the instance height, the plane
## tilt, counts, and the walls scene; the caller saves the terrain data and walls.
func build(terrain: Terrain3D) -> Dictionary:
	_terrain = terrain
	_data = terrain.data
	_rng.seed = seed_value

	var grading: Dictionary = flatten_ground()
	var painted: int = paint_floor()

	var generator = VegetationGenerator.new()
	generator.zone = vegetation_zone
	generator.seed_value = seed_value
	var planted: Dictionary = generator.generate(terrain)

	# After the forest tool, which repaints the ground inside its zone.
	mix_floor_textures()
	var floor_plants: int = scatter_floor_plants()
	var rim_plants: int = scatter_rim()
	var cover: int = cover_rail_ends()

	var boundaries = BoundaryBuilder.new()
	var walls: Dictionary = boundaries.build(terrain)

	return {
		"height": plane_height,
		"slope": plane_slope,
		"grading": grading,
		"painted": painted,
		"removed": planted.get("removed", 0),
		"added": planted.get("added", 0),
		"floor_plants": floor_plants,
		"rim_plants": rim_plants,
		"cover_plants": cover,
		"boundaries": walls,
		"slopes": measure_slopes(),
	}


# ============================================================
# GRADING
# ============================================================

## The clearing's outline: 1 on the edge, below 1 inside. Distances are the
## ellipse's, stretched by a wavering radius.
func blob_field(local: Vector2) -> float:
	var d: Vector2 = Vector2(
		(local.x - blob_center.x) / blob_radii.x, (local.y - blob_center.y) / blob_radii.y
	)
	var angle: float = d.angle()
	var wobble: float = (
		1.0 + 0.07 * sin(2.0 * angle + 0.8) + 0.05 * sin(3.0 * angle + 2.1)
		+ 0.035 * sin(5.0 * angle + 4.0)
	)
	return d.length() / wobble


## Distance outside the blob's edge in metres (negative inside), roughly.
func _outside(local: Vector2) -> float:
	return (blob_field(local) - 1.0) * minf(blob_radii.x, blob_radii.y)


## Where the clearing's edge crosses the path line (local z = 0): [west x, east x].
func _pad_extent() -> Vector2:
	var west: float = 1000.0
	var east: float = -1000.0
	var x: float = -40.0
	while x <= 40.0:
		if blob_field(Vector2(x, 0.0)) <= 1.0:
			west = minf(west, x)
			east = maxf(east, x)

		x += 0.25

	return Vector2(west, east)


func _plane(local: Vector2) -> float:
	return plane_height + plane_slope.x * local.x + plane_slope.y * local.y


func _natural_at(local: Vector2) -> float:
	var key: Vector2i = Vector2i(roundi(local.x), roundi(local.y))
	return float(_natural.get(key, NAN))


## Fits the tilted plane to the hillside under the blob, grades the clearing, the
## platform and the railway, and blends them back into the hillside.
func flatten_ground() -> Dictionary:
	var min_x: int = -56
	var max_x: int = 56
	var min_z: int = -44
	var max_z: int = 40

	# The untouched hillside first: the grading reads it everywhere.
	_natural.clear()
	for lz: int in range(min_z, max_z + 1):
		for lx: int in range(min_x, max_x + 1):
			var h: float = _data.get_height(Vector3(center.x + lx, 0.0, center.y + lz))
			if not is_nan(h):
				_natural[Vector2i(lx, lz)] = h

	# Least-squares plane over the blob.
	var count: int = 0
	var sum_h: float = 0.0
	var sum_x: float = 0.0
	var sum_z: float = 0.0
	var sxx: float = 0.0
	var szz: float = 0.0
	var sxh: float = 0.0
	var szh: float = 0.0
	for key: Vector2i in _natural:
		var local: Vector2 = Vector2(key)
		if blob_field(local) > 1.0:
			continue

		var h2: float = float(_natural[key])
		count += 1
		sum_h += h2
		sum_x += local.x
		sum_z += local.y
		sxx += local.x * local.x
		szz += local.y * local.y
		sxh += local.x * h2
		szh += local.y * h2

	if count == 0:
		push_error("JunctionTerrainBuilder: no terrain under the clearing.")
		return {}

	var mean_h: float = sum_h / count
	var mean_x: float = sum_x / count
	var mean_z: float = sum_z / count
	var natural_gx: float = (sxh - count * mean_x * mean_h) / (sxx - count * mean_x * mean_x)
	var natural_gz: float = (szh - count * mean_z * mean_h) / (szz - count * mean_z * mean_z)
	plane_slope = Vector2(natural_gx * path_tilt, rails_slope_z)
	plane_height = mean_h - plane_slope.x * mean_x - plane_slope.y * mean_z + pad_height_bias

	var platform_rect: Rect2 = Rect2(platform_center - platform_size * 0.5, platform_size)
	var platform_height: float = _plane(platform_center)
	var pad_extent: Vector2 = _pad_extent()

	for key: Vector2i in _natural:
		var local: Vector2 = Vector2(key)
		var natural: float = float(_natural[key])

		var blob_weight: float = 1.0 - smoothstep(0.0, blend_length, _outside(local))
		var value: float = lerpf(natural, _plane(local), blob_weight)

		var platform_weight: float = 1.0 - smoothstep(
			0.0, platform_blend, _distance_to_rect(local, platform_rect)
		)
		value = lerpf(value, platform_height, platform_weight)

		# The railway bed: level, carried on past the clearing as a cutting into the
		# forest (the hillside rises to the north), flat across.
		var lateral: float = 1.0 - smoothstep(
			0.0, rails_blend, maxf(absf(local.x - rails_x) - rails_half_width, 0.0)
		)
		var along: float = (
			smoothstep(rails_z_range.x - 8.0, rails_z_range.x, local.y)
			* (1.0 - smoothstep(rails_z_range.y, rails_z_range.y + 8.0, local.y))
		)
		var rails_weight: float = lateral * along
		if rails_weight > 0.0:
			value = lerpf(value, _plane(local), rails_weight)

		# The path out of the clearing: it follows the hillside's own (smoothed)
		# profile, offset by how far the level clearing is from it at the edge, and
		# that offset eases away over `corridor_fade` metres, so the grade is the
		# hillside's plus a small, gentle extra. Flat across, then blended sideways.
		var lateral_path: float = 1.0 - smoothstep(
			0.0, corridor_blend, maxf(absf(local.y) - corridor_half_width, 0.0)
		)
		var edge_distance: float = maxf(maxf(pad_extent.x - local.x, local.x - pad_extent.y), 0.0)
		if edge_distance > 0.0:
			var edge_x: float = pad_extent.x if local.x < pad_extent.x else pad_extent.y
			var offset: float = plane_height - _smooth_natural(edge_x)
			var line: float = _smooth_natural(local.x) + offset * (
				1.0 - smoothstep(0.0, corridor_fade, edge_distance)
			)
			var path_weight: float = lateral_path * (
				1.0 - smoothstep(corridor_fade, corridor_fade + corridor_end, edge_distance)
			)
			if path_weight > 0.0:
				value = lerpf(value, line, path_weight)

		_data.set_height(Vector3(center.x + local.x, 0.0, center.y + local.y), value)

	_mark_regions_modified(Terrain3DRegion.TYPE_HEIGHT)
	_data.calc_height_range(true)
	return {
		"natural_slope": Vector2(natural_gx, natural_gz),
		"platform_height": platform_height,
		"cells": count,
	}


## The steepest slope (degrees over 3 m) along the east-west path and along the
## railway, read back from the graded terrain, for a report.
func measure_slopes() -> Dictionary:
	return {
		"path": _steepest(Vector2(-34.0, 0.0), Vector2(34.0, 0.0)),
		"rails": _steepest(Vector2(rails_x, rails_z_range.x), Vector2(rails_x, rails_z_range.y)),
	}


func _steepest(from: Vector2, to: Vector2) -> float:
	var worst: float = 0.0
	var steps: int = int(from.distance_to(to) / 0.5)
	for i: int in range(0, steps - 6):
		var a: Vector2 = center + from.lerp(to, float(i) / steps)
		var b: Vector2 = center + from.lerp(to, float(i + 6) / steps)
		var ha: float = _data.get_height(Vector3(a.x, 0.0, a.y))
		var hb: float = _data.get_height(Vector3(b.x, 0.0, b.y))
		worst = maxf(worst, absf(hb - ha) / a.distance_to(b))

	return rad_to_deg(atan(worst))


# ============================================================
# GROUND
# ============================================================

## Paints the clearing floor with the path's own control value (dirt base), so
## the tools see it as walkable ground.
func paint_floor() -> int:
	if not _find_reference_control():
		push_error("JunctionTerrainBuilder: no path dirt found near the clearing to copy.")
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
## walkable to the other tools. The trail along the path and the ground close to
## the props are worn bare.
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

		var local: Vector2 = cell - center
		var patch: float = patch_noise.get_noise_2d(cell.x, cell.y)
		var fine: float = fine_noise.get_noise_2d(cell.x, cell.y) * 0.5 + 0.5
		var rim: float = smoothstep(0.6, 1.0, blob_field(local))
		var worn: float = 1.0 - smoothstep(0.0, 1.6, _distance_to_props(local))
		var trail: float = 1.0 - smoothstep(0.0, 1.8, absf(local.y) - trail_half_width)
		worn = maxf(worn, trail)

		var overlay: int = TEX_HUMUS
		var blend: float = 0.18 + fine * 0.26
		var green: float = patch * 0.6 + rim * 0.8 + (fine - 0.5) * 0.5 - worn * 0.9
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


# ============================================================
# PLANTS
# ============================================================

## Scatters small plants over the clearing floor in loose clumps, keeping the
## props, the rails and the trail clear. Returns the number placed.
func scatter_floor_plants() -> int:
	var clump_noise: FastNoiseLite = FastNoiseLite.new()
	clump_noise.seed = seed_value + 31
	clump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	clump_noise.frequency = 0.3

	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var bounds: Rect2 = _blob_bounds()
	var placed: int = 0

	for layer: Dictionary in FLOOR_PLANTS:
		var ids: Array = layer["ids"]
		var per_mesh: Dictionary = {}
		var colors: Dictionary = {}

		# Twice as many candidates as needed; the clump noise rejects about half.
		var candidates: int = int(float(layer["density"]) * bounds.get_area() * 1.6)
		for i: int in candidates:
			var local: Vector2 = Vector2(
				_rng.randf_range(bounds.position.x, bounds.end.x),
				_rng.randf_range(bounds.position.y, bounds.end.y)
			)
			if blob_field(local) > 0.96 or _distance_to_props(local) < 0.0:
				continue

			# Nothing on the trail itself but the tiniest tufts.
			if absf(local.y) < trail_half_width and (layer["scale"] as Vector2).y > 0.3:
				continue

			var point: Vector2 = center + local
			if clump_noise.get_noise_2d(point.x + float(i % 7), point.y) < -0.1 + _rng.randf() * 0.5:
				continue

			var transform: Variant = _make_transform(point, layer, _rng.randf_range(0.78, 1.0))
			if transform == null:
				continue

			var mesh_id: int = int(ids[_rng.randi_range(0, ids.size() - 1)])
			if not per_mesh.has(mesh_id):
				var list: Array[Transform3D] = []
				per_mesh[mesh_id] = list
				colors[mesh_id] = PackedColorArray()

			(per_mesh[mesh_id] as Array[Transform3D]).append(transform[0] as Transform3D)
			(colors[mesh_id] as PackedColorArray).append(transform[1] as Color)

		for mesh_id: int in per_mesh:
			var transforms: Array[Transform3D] = per_mesh[mesh_id]
			instancer.add_transforms(mesh_id, transforms, colors[mesh_id])
			placed += transforms.size()

	return placed


## Clumps of bushes, tall plants and ferns along the clearing's rim (and a few just
## inside it), so the edge is ragged and green instead of a clean outline. The two
## ends of the path stay open. Returns the number placed.
func scatter_rim() -> int:
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var per_mesh: Dictionary = {}
	var colors: Dictionary = {}
	var total_weight: float = 0.0
	for plant: Dictionary in RIM_PLANTS:
		total_weight += float(plant["weight"])

	var clump_noise: FastNoiseLite = FastNoiseLite.new()
	clump_noise.seed = seed_value + 51
	clump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	clump_noise.frequency = 0.35

	var placed: int = 0
	for i: int in 420:
		var angle: float = _rng.randf() * TAU
		var local: Vector2 = blob_center + Vector2(
			cos(angle) * blob_radii.x, sin(angle) * blob_radii.y
		) * _rng.randf_range(0.88, 1.12)

		# Leave the path open where it enters and leaves, and the props alone.
		if absf(local.y) < 2.4 and absf(local.x) > 6.0:
			continue

		if _distance_to_props(local) < 0.8:
			continue

		var field: float = blob_field(local)
		if field < 0.82 or field > 1.18:
			continue

		if clump_noise.get_noise_2d(local.x, local.y) < -0.2 + _rng.randf() * 0.4:
			continue

		var pick: float = _rng.randf() * total_weight
		var chosen: Dictionary = RIM_PLANTS[0]
		for plant: Dictionary in RIM_PLANTS:
			pick -= float(plant["weight"])
			if pick <= 0.0:
				chosen = plant
				break

		var layer: Dictionary = {
			"scale": chosen["scale"], "bias": 1.0, "align": 0.3, "tilt": 6.0,
		}
		var made: Variant = _make_transform(center + local, layer, _rng.randf_range(0.8, 1.0))
		if made == null:
			continue

		var ids: Array = chosen["ids"]
		var mesh_id: int = int(ids[_rng.randi_range(0, ids.size() - 1)])
		if not per_mesh.has(mesh_id):
			var list: Array[Transform3D] = []
			per_mesh[mesh_id] = list
			colors[mesh_id] = PackedColorArray()

		(per_mesh[mesh_id] as Array[Transform3D]).append(made[0] as Transform3D)
		(colors[mesh_id] as PackedColorArray).append(made[1] as Color)

	for mesh_id: int in per_mesh:
		var transforms: Array[Transform3D] = per_mesh[mesh_id]
		instancer.add_transforms(mesh_id, transforms, colors[mesh_id])
		placed += transforms.size()

	return placed


## Dense bushes around the two ends of the rails, so the track runs into the
## vegetation and the last sleepers are never seen. Returns the number placed.
func cover_rail_ends() -> int:
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var per_mesh: Dictionary = {}
	var colors: Dictionary = {}
	var placed: int = 0

	for end_z: float in [rails_z_range.x, rails_z_range.y]:
		var outward: float = -1.0 if end_z < 0.0 else 1.0
		for i: int in 26:
			# A wide band across the track and a little before and beyond the end.
			var local: Vector2 = Vector2(
				rails_x + _rng.randf_range(-3.4, 3.4),
				end_z + outward * _rng.randf_range(-2.5, 3.5)
			)
			var kind: int = _rng.randi_range(0, 3)
			var ids: Array = [[BUSH_A, BUSH_B], [TALL_PLANT_A, TALL_PLANT_B], [FERN], [MEDIUM_PLANT]][kind]
			var layer: Dictionary = {
				"scale": Vector2(0.9, 1.5) if kind == 0 else Vector2(0.9, 1.4),
				"bias": 1.0, "align": 0.2, "tilt": 5.0,
			}
			var made: Variant = _make_transform(center + local, layer, _rng.randf_range(0.8, 1.0))
			if made == null:
				continue

			var mesh_id: int = int(ids[_rng.randi_range(0, ids.size() - 1)])
			if not per_mesh.has(mesh_id):
				var list: Array[Transform3D] = []
				per_mesh[mesh_id] = list
				colors[mesh_id] = PackedColorArray()

			(per_mesh[mesh_id] as Array[Transform3D]).append(made[0] as Transform3D)
			(colors[mesh_id] as PackedColorArray).append(made[1] as Color)

	for mesh_id: int in per_mesh:
		var transforms: Array[Transform3D] = per_mesh[mesh_id]
		instancer.add_transforms(mesh_id, transforms, colors[mesh_id])
		placed += transforms.size()

	return placed


## A plant's transform on the ground at `point` (world XZ), as [Transform3D, Color],
## or null where there is no terrain or it is too steep.
func _make_transform(point: Vector2, layer: Dictionary, shade: float) -> Variant:
	var world: Vector3 = Vector3(point.x, 0.0, point.y)
	var height: float = _data.get_height(world)
	if is_nan(height):
		return null

	var normal: Vector3 = _data.get_normal(world)
	if normal.y < cos(deg_to_rad(float(layer.get("max_slope", 55.0)))):
		return null

	var uniform_scale: float = lerpf(
		(layer["scale"] as Vector2).x,
		(layer["scale"] as Vector2).y,
		pow(_rng.randf(), float(layer.get("bias", 1.0)))
	)
	var up: Vector3 = Vector3.UP.lerp(normal, float(layer.get("align", 0.5))).normalized()
	var basis: Basis = Basis(Quaternion(Vector3.UP, up))
	basis = basis * Basis(Vector3.UP, _rng.randf() * TAU)
	var tilt: float = deg_to_rad(float(layer.get("tilt", 0.0)))
	if tilt > 0.0:
		basis = basis * Basis.from_euler(Vector3(
			_rng.randf_range(-tilt, tilt), 0.0, _rng.randf_range(-tilt, tilt)
		))

	var width_scale: float = uniform_scale * _rng.randf_range(0.9, 1.1)
	basis = basis.scaled_local(Vector3(width_scale, uniform_scale, width_scale))
	return [
		Transform3D(basis, Vector3(point.x, height + float(layer.get("sink", 0.0)), point.y)),
		Color(shade, shade, shade, 1.0),
	]


# ============================================================
# HELPERS
# ============================================================

## Local rectangle that contains the blob.
func _blob_bounds() -> Rect2:
	return Rect2(
		blob_center - blob_radii * 1.15, blob_radii * 2.3
	)


## Whole terrain cells (world) whose centre lies inside the clearing.
func _floor_cells() -> Array[Vector2]:
	var cells: Array[Vector2] = []
	var bounds: Rect2 = _blob_bounds()
	for lz: int in range(int(floorf(bounds.position.y)), int(ceilf(bounds.end.y)) + 1):
		for lx: int in range(int(floorf(bounds.position.x)), int(ceilf(bounds.end.x)) + 1):
			if blob_field(Vector2(lx, lz)) <= 1.0:
				cells.append(center + Vector2(lx, lz))

	return cells


## Distance from a point to the nearest prop's clearance area (negative when
## inside it); local metres.
func _distance_to_props(local: Vector2) -> float:
	var nearest: float = INF
	for prop: Dictionary in PROP_CIRCLES:
		nearest = minf(
			nearest, local.distance_to(prop["position"] as Vector2) - float(prop["radius"])
		)

	for rect: Rect2 in PROP_RECTS:
		if rect.has_point(local):
			nearest = minf(nearest, -1.0)
			continue

		nearest = minf(nearest, _distance_to_rect(local, rect))

	return nearest


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var dx: float = maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dz: float = maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dz).length()


## Copies the control value of existing path dirt on the middle path's straight stretch.
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
	var x: float = vegetation_zone.position.x
	while x <= vegetation_zone.end.x + region_size:
		var z: float = vegetation_zone.position.y
		while z <= vegetation_zone.end.y + region_size:
			var region: Terrain3DRegion = _data.get_regionp(Vector3(x, 0.0, z))
			if region != null:
				region.set_modified(true)

			z += region_size

		x += region_size


## The hillside's height along the path line at local x, averaged over a few metres
## along and across it (8 m each way along, 2 m across) so the hillside's bumps do not
## show in the graded path, which keeps an even grade.
func _smooth_natural(x: float) -> float:
	var total: float = 0.0
	var count: int = 0
	for dx: int in range(-8, 9):
		for dz: int in range(-2, 3):
			var key: Vector2i = Vector2i(roundi(x) + dx, dz)
			if _natural.has(key):
				total += float(_natural[key])
				count += 1

	return total / maxf(float(count), 1.0)
