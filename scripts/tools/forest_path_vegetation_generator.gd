@tool
extends RefCounted
class_name ForestPathVegetationGenerator

## Scatters Atlantic-forest style vegetation around the dirt paths painted in
## a Terrain3D node, so level design starts from a dense, readable forest that
## can then be polished by hand with the Terrain3D instancer brush.
##
## It reads where the dirt texture is painted, measures every ground cell's
## distance to the nearest path, and fills each distance band with its own
## plants: ground litter and grass right at the edge, a fern and bush wall
## beside the trail, then trees further back. Everything goes through
## Terrain3DInstancer, so the result is ordinary painted instances.
##
## Only meshes listed in CLEARED_MESH_IDS are removed inside the zone before
## generating. Props (tent, campfire, bench) are never touched.
##
## Mesh IDs refer to the Terrain3D mesh asset list of the dream intro scene.

const FERN: int = 9
const BUSH_A: int = 0
const BUSH_B: int = 4
const PITANGUEIRA: int = 3
const TREE_A: int = 1
const TREE_B: int = 2
const ARAUCARIA: int = 14
const LITTER: int = 5
const GRASS_A: int = 11
const GRASS_B: int = 12
const MEDIUM_PLANT: int = 6
const TALL_PLANT_A: int = 7
const TALL_PLANT_B: int = 13
const RED_PLANT: int = 10
const FLOWER_A: int = 8
const FLOWER_B: int = 20
const ROCK_A: int = 17
const ROCK_B: int = 18

## Plants cleared inside the zone before generating. Props are excluded.
const CLEARED_MESH_IDS: Array[int] = [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 17, 18, 20,
]

## World-space XZ area to fill (x, z, width, depth in metres).
var zone: Rect2 = Rect2(12.0, -34.0, 46.0, 80.0)

## Open views that must stay clear of anything tall, such as the city overlook.
## Each entry: {"origin": Vector2, "direction": Vector2, "half_angle": degrees,
## "length": metres}. Layers marked "tall" are skipped inside a corridor, so only
## low plants remain there while trees and bushes frame the sides.
var view_corridors: Array[Dictionary] = []

## Areas that must stay empty, such as the train, tracks and fence door.
var exclusions: Array[Rect2] = []

## Only low plants (layers not flagged "tall") may grow here: both sides of
## fences, around gates, beside wagons, so structures stay visible and nothing
## tall clips into them.
var low_zones: Array[Rect2] = []

## No trees (layers with spacing) here, since their crowns are many metres wide.
var no_tree_zones: Array[Rect2] = []

## Invisible walkways: polylines treated as path when measuring distance, so a
## forest can be grown around something that is not a painted dirt path (the
## sides of a train). Nothing is painted or planted on the line itself.
var virtual_paths: Array[PackedVector2Array] = []
var virtual_path_half_width: float = 0.8

## Areas filled directly with the layers flagged "fill" (dense small plants),
## whatever their distance to a path. Used for the strips between a wagon and
## its fence, which the distance bands cannot reach.
var fill_zones: Array[Rect2] = []

## Texture slot painted as the dirt path in Terrain3D.
var dirt_texture_id: int = 1

## Plants farther than this from any path are skipped. The player stays on
## the trail and the fog hides the forest long before this distance, so there
## is no need to fill further.
## Keeping this small is what keeps the forest cheap.
var max_path_distance: float = 20.0

## Plants beside the path are scaled to this fraction of their size, growing to
## full size over edge_growth_distance metres from the path.
var edge_min_scale: float = 0.5
var edge_growth_distance: float = 2.6

## Remove existing plants inside the zone first, so reruns do not stack.
var clear_existing: bool = true

var seed_value: int = 20261003

var _terrain: Terrain3D = null
var _data: Terrain3DData = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _noise: FastNoiseLite = FastNoiseLite.new()

var _grid_origin: Vector2 = Vector2.ZERO
var _grid_size: Vector2i = Vector2i.ZERO
var _distance: PackedFloat32Array = PackedFloat32Array()
## Distance from ANY path cell (including its green edges), unlike _distance,
## which starts at the visible dirt. Medium and tall plants use this one so
## they never grow on ground people can walk on.
var _path_distance: PackedFloat32Array = PackedFloat32Array()

var _pending_transforms: Dictionary = {}
var _pending_colors: Dictionary = {}
var _tree_points: Array[Vector2] = []
var _placed_count: Dictionary = {}


func generate(terrain: Terrain3D) -> Dictionary:
	_terrain = terrain
	_data = terrain.data
	_rng.seed = seed_value
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.045

	_pending_transforms.clear()
	_pending_colors.clear()
	_tree_points.clear()
	_placed_count.clear()

	var path_cells: int = _build_distance_field()
	if path_cells == 0:
		push_error(
			"ForestPathVegetationGenerator: no dirt (texture %d) found near the zone."
			% dirt_texture_id
		)
		return {"error": "no path found"}

	var removed: int = 0
	if clear_existing:
		removed = _clear_existing_plants()

	# Ground first, so plants can follow the texture: more vegetation on grass,
	# none but tiny plants on the dirt strip people walk on.
	var painted_cells: int = 0
	if paint_ground_textures:
		painted_cells = _paint_ground()

	var layer_index: int = 0
	for layer: Dictionary in _get_layers():
		layer["noise_offset"] = Vector2(float(layer_index) * 173.3, float(layer_index) * 91.7)
		layer_index += 1
		_scatter_layer(layer)

	var added: int = _commit()

	if paint_ground_textures:
		_paint_tree_mulch()
		_data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)

	return {
		"path_cells": path_cells,
		"removed": removed,
		"added": added,
		"painted_ground_cells": painted_cells,
		"per_mesh": _placed_count.duplicate(),
	}


# ============================================================
# LAYERS
# ============================================================

## Each layer is a distance band measured from the path edge, in metres.
## - density: plants per square metre at the peak of the band.
## - taper: fraction of the band where density starts fading to zero.
## - clump: 0 = even, 1 = strong patches and gaps.
## - align: 0 = upright, 1 = follows the ground slope.
## - radius: half-width of the plant at scale 1. A plant is kept this far from
##   the path (times its scale) so its leaves reach the trail edge but never
##   cover the walking line.
## - spacing: minimum distance between trees (only for tree layers).
func _get_layers() -> Array[Dictionary]:
	return [
		{
			"name": "leaf litter",
			"ids": [LITTER],
			"d_min": 0.4, "d_max": 8.0, "density": 0.9, "taper": 0.5,
			"scale": Vector2(0.18, 0.34), "align": 1.0, "clump": 0.5, "radius": 0.1,
			# A flat card floats on slopes, so it only goes on near-level ground.
			"max_slope": 14.0, "sink": -0.02,
		},
		{
			"name": "grass tufts",
			"ids": [GRASS_A, GRASS_B],
			"d_min": 0.4, "d_max": 9.0, "density": 11.0, "taper": 0.4, "ramp": 0.6,
			"scale": Vector2(0.28, 0.85), "scale_bias": 1.8, "align": 0.8, "clump": 0.8, "radius": 0.25,
			"tilt": 14.0,
		},
		{
			"name": "small ferns",
			"ids": [FERN],
			"d_min": 0.8, "d_max": 3.0, "density": 1.6, "taper": 0.5, "ramp": 0.8,
			"scale": Vector2(0.14, 0.42), "scale_bias": 1.3, "align": 0.6, "clump": 0.9, "radius": 1.2,
			"tilt": 10.0,
		},
		{
			"name": "low leafy plants", "tall": true,
			"ids": [MEDIUM_PLANT],
			"d_min": 0.4, "d_max": 2.4, "density": 3.0, "taper": 0.5, "ramp": 0.6,
			"scale": Vector2(0.22, 0.55), "scale_bias": 1.3, "align": 0.3, "clump": 0.85, "radius": 0.3,
		},
		{
			"name": "low bushes", "tall": true,
			"ids": [BUSH_A, BUSH_B],
			"d_min": 2.2, "d_max": 11.0, "density": 1.1, "taper": 0.5,
			"scale": Vector2(0.7, 1.4), "scale_bias": 1.0, "align": 0.0, "clump": 0.8, "radius": 1.2,
		},
		{
			"name": "tall plant accents", "tall": true,
			"ids": [TALL_PLANT_A, TALL_PLANT_B],
			"d_min": 0.8, "d_max": 7.0, "density": 0.18, "taper": 0.4,
			"scale": Vector2(0.45, 0.95), "align": 0.2, "clump": 0.8, "radius": 0.3,
		},
		{
			"name": "red plant accents", "tall": true,
			"ids": [RED_PLANT],
			"d_min": 0.8, "d_max": 7.0, "density": 0.14, "taper": 0.4,
			"scale": Vector2(0.45, 0.8), "align": 0.3, "clump": 0.8, "radius": 0.4,
		},
		{
			"name": "flowers",
			"ids": [FLOWER_A, FLOWER_B],
			"d_min": 0.5, "d_max": 4.5, "density": 0.14, "taper": 0.3,
			"scale": Vector2(0.8, 1.2), "align": 0.3, "clump": 0.9, "radius": 0.3,
		},
		{
			"name": "rocks",
			"ids": [ROCK_A, ROCK_B],
			"d_min": 0.5, "d_max": 5.0, "density": 0.07, "taper": 0.3, "ramp": 0.6,
			"scale": Vector2(0.5, 1.4), "scale_bias": 1.8, "align": 1.0, "clump": 0.9, "radius": 0.2, "keep_size": true,
			"sink": -0.03,
		},
		# Growth on the path itself. Only the strip along its edges, so the walking
		# line stays clear but the trail is narrow and uneven, like a real trail.
		{
			"name": "path edge grass", "inside": true, "inner_max": 2,
			"ids": [GRASS_A, GRASS_B],
			"density": 4.2,
			"scale": Vector2(0.25, 0.7), "scale_bias": 1.6, "align": 0.8, "clump": 0.9, "tilt": 14.0,
		},
		{
			"name": "path edge ferns", "inside": true, "inner_max": 1,
			"ids": [FERN],
			"density": 0.3,
			"scale": Vector2(0.07, 0.17), "scale_bias": 1.3, "align": 0.6, "clump": 0.9, "tilt": 12.0,
		},
		{
			"name": "path edge sprouts", "inside": true, "inner_max": 2,
			"ids": [MEDIUM_PLANT],
			"density": 0.3,
			"scale": Vector2(0.1, 0.22), "scale_bias": 1.2, "align": 0.3, "clump": 0.9,
		},
		{
			"name": "path leaf litter", "inside": true, "inner_max": 2,
			"ids": [LITTER],
			"density": 0.4,
			"scale": Vector2(0.14, 0.3), "align": 1.0, "clump": 0.6, "max_slope": 20.0, "sink": -0.02,
		},
		# The wall of vegetation lining the trail: dense, medium to tall plants
		# starting right at the edge (never over the walking line), so the path
		# reads as a gap cut through the forest.
		{
			"name": "edge hedge bushes", "tall": true,
			"ids": [BUSH_A, BUSH_B],
			"d_min": 1.1, "d_max": 4.4, "density": 1.1, "taper": 0.5, "ramp": 0.6,
			"scale": Vector2(0.5, 1.0), "scale_bias": 1.0, "align": 0.0, "clump": 0.7, "radius": 0.9,
		},
		{
			"name": "edge hedge leafy plants", "tall": true,
			"ids": [MEDIUM_PLANT],
			"d_min": 0.9, "d_max": 4.0, "density": 1.8, "taper": 0.5, "ramp": 0.6,
			"scale": Vector2(0.75, 1.3), "scale_bias": 1.0, "align": 0.3, "clump": 0.7, "radius": 0.3,
		},
		{
			"name": "edge hedge tall plants", "tall": true,
			"ids": [TALL_PLANT_A, TALL_PLANT_B],
			"d_min": 1.5, "d_max": 5.5, "density": 0.65, "taper": 0.5, "ramp": 0.6,
			"scale": Vector2(0.65, 1.1), "scale_bias": 1.0, "align": 0.2, "clump": 0.8, "radius": 0.3,
		},
		{
			"name": "edge hedge ferns", "tall": true,
			"ids": [FERN],
			"d_min": 1.0, "d_max": 4.6, "density": 0.6, "taper": 0.5, "ramp": 0.6,
			"scale": Vector2(0.4, 0.85), "scale_bias": 1.0, "align": 0.5, "clump": 0.8, "radius": 0.9,
		},
		# The middle of the trail is where people walk: only tiny plants and the
		# odd pebble here, never anything medium or tall.
		{
			"name": "path centre tufts", "inside": true, "inner_max": 4,
			"ids": [GRASS_A, GRASS_B],
			"density": 0.9,
			"scale": Vector2(0.1, 0.24), "scale_bias": 1.2, "align": 0.8, "clump": 0.95, "tilt": 14.0,
		},
		# A few pebbles set into the trail.
		{
			"name": "path stones", "inside": true, "inner_max": 3,
			"ids": [ROCK_A, ROCK_B],
			"density": 0.06,
			"scale": Vector2(0.3, 0.8), "scale_bias": 1.6, "align": 1.0, "clump": 0.95, "sink": -0.025, "keep_size": true,
		},
		# Dense low growth in the fill zones (the strips between wagons and
		# their fences): wild but short, so the train looks like it stands in
		# the forest without plants reaching the wagon or hiding the fence.
		{
			"name": "strip grass", "fill": true, "keep_size": true,
			"ids": [GRASS_A, GRASS_B],
			"density": 14.0,
			"scale": Vector2(0.3, 0.9), "scale_bias": 1.3, "align": 0.8, "tilt": 14.0,
		},
		{
			"name": "strip ferns", "fill": true, "keep_size": true,
			"ids": [FERN],
			"density": 2.2,
			"scale": Vector2(0.16, 0.42), "scale_bias": 1.2, "align": 0.6, "tilt": 10.0,
		},
		{
			"name": "strip leafy plants", "fill": true, "keep_size": true,
			"ids": [MEDIUM_PLANT],
			"density": 3.2,
			"scale": Vector2(0.35, 1.0), "scale_bias": 1.0, "align": 0.3,
		},
		{
			"name": "strip low bushes", "fill": true, "keep_size": true,
			"ids": [BUSH_A, BUSH_B],
			"density": 1.0,
			"scale": Vector2(0.35, 0.85), "align": 0.0,
		},
		{
			"name": "strip flowers", "fill": true, "keep_size": true,
			"ids": [FLOWER_A, FLOWER_B],
			"density": 0.3,
			"scale": Vector2(0.8, 1.2), "align": 0.3,
		},
		# Backdrop: taller plants well behind the low understory, so the
		# trail is walled in by the forest instead of opening onto bare grass.
		{
			"name": "backdrop bushes", "tall": true,
			"ids": [BUSH_A, BUSH_B],
			"d_min": 2.4, "d_max": 15.0, "density": 1.3, "taper": 0.5,
			"scale": Vector2(1.1, 1.8), "align": 0.0, "clump": 0.6, "radius": 1.5,
		},
		{
			"name": "backdrop ferns", "tall": true,
			"ids": [FERN],
			"d_min": 2.4, "d_max": 13.0, "density": 0.9, "taper": 0.5,
			"scale": Vector2(0.9, 1.5), "align": 0.4, "clump": 0.6, "radius": 1.4,
		},
		{
			"name": "backdrop tall plants", "tall": true,
			"ids": [TALL_PLANT_A, TALL_PLANT_B],
			"d_min": 2.6, "d_max": 15.0, "density": 0.6, "taper": 0.5,
			"scale": Vector2(0.9, 1.5), "align": 0.2, "clump": 0.8, "radius": 0.3,
		},
		{
			"name": "backdrop red plants", "tall": true,
			"ids": [RED_PLANT],
			"d_min": 3.0, "d_max": 13.0, "density": 0.12, "taper": 0.5,
			"scale": Vector2(0.8, 1.2), "align": 0.3, "clump": 0.8, "radius": 0.4,
		},
		{
			"name": "shrub trees", "tall": true,
			"ids": [PITANGUEIRA],
			"d_min": 2.8, "d_max": 20.0, "density": 0.045, "taper": 0.6,
			"scale": Vector2(0.6, 0.95), "align": 0.0, "clump": 0.4, "radius": 3.2,
			"spacing": 4.0, "max_slope": 40.0,
		},
		{
			"name": "canopy trees", "tall": true,
			"ids": [TREE_A, TREE_B],
			"d_min": 2.4, "d_max": 20.0, "density": 0.1, "taper": 0.7,
			"scale": Vector2(0.8, 1.25), "align": 0.0, "clump": 0.3, "radius": 0.5,
			"spacing": 3.4, "tilt": 3.0, "max_slope": 40.0, "sink": -0.15,
		},
	]


# ============================================================
# DISTANCE TO PATH
# ============================================================

func _build_distance_field() -> int:
	var margin: float = max_path_distance
	var area: Rect2 = zone.grow(margin)
	_grid_origin = area.position.floor()
	_grid_size = Vector2i(
		ceili(area.size.x) + 1,
		ceili(area.size.y) + 1
	)

	var cell_count: int = _grid_size.x * _grid_size.y
	_distance.resize(cell_count)

	var path_cells: int = 0
	for gy: int in range(_grid_size.y):
		for gx: int in range(_grid_size.x):
			var index: int = gy * _grid_size.x + gx
			if _is_visible_dirt(_grid_to_world(gx, gy)) or _on_virtual_path(_grid_to_world(gx, gy)):
				_distance[index] = 0.0
				path_cells += 1
			else:
				_distance[index] = INF

	if path_cells == 0:
		return 0

	# Two-pass chamfer distance transform (approximate euclidean, in metres).
	var diagonal: float = 1.4142
	for gy: int in range(_grid_size.y):
		for gx: int in range(_grid_size.x):
			var index: int = gy * _grid_size.x + gx
			var best: float = _distance[index]
			if gx > 0:
				best = minf(best, _distance[index - 1] + 1.0)
			if gy > 0:
				best = minf(best, _distance[index - _grid_size.x] + 1.0)
				if gx > 0:
					best = minf(best, _distance[index - _grid_size.x - 1] + diagonal)
				if gx < _grid_size.x - 1:
					best = minf(best, _distance[index - _grid_size.x + 1] + diagonal)
			_distance[index] = best

	for gy: int in range(_grid_size.y - 1, -1, -1):
		for gx: int in range(_grid_size.x - 1, -1, -1):
			var index: int = gy * _grid_size.x + gx
			var best: float = _distance[index]
			if gx < _grid_size.x - 1:
				best = minf(best, _distance[index + 1] + 1.0)
			if gy < _grid_size.y - 1:
				best = minf(best, _distance[index + _grid_size.x] + 1.0)
				if gx < _grid_size.x - 1:
					best = minf(best, _distance[index + _grid_size.x + 1] + diagonal)
				if gx > 0:
					best = minf(best, _distance[index + _grid_size.x - 1] + diagonal)
			_distance[index] = best

	_build_path_field()
	return path_cells


func _grid_to_world(gx: int, gy: int) -> Vector2:
	return _grid_origin + Vector2(float(gx) + 0.5, float(gy) + 0.5)


func _distance_at(point: Vector2) -> float:
	var gx: int = int(floorf(point.x - _grid_origin.x))
	var gy: int = int(floorf(point.y - _grid_origin.y))
	if gx < 0 or gy < 0 or gx >= _grid_size.x or gy >= _grid_size.y:
		return INF

	return _distance[gy * _grid_size.x + gx]


func _is_dirt(point: Vector2) -> bool:
	var world: Vector3 = Vector3(point.x, 0.0, point.y)
	if is_nan(_data.get_height(world)):
		return false

	# Cells flagged "auto" let the terrain shader pick the texture by slope, so
	# they can read as dirt in the data while rendering as grass. They are not
	# paths; treating them as one left bare patches without vegetation.
	if _data.get_control_auto(world):
		return false

	# Solid dirt has the dirt texture as its base. A cell whose dirt is only the
	# overlay is a soft blend into grass, and only counts when it is almost
	# fully dirt. A 60% blend renders as grass, and treating it as path left
	# bare clearings without vegetation.
	# A path cell keeps dirt as its BASE texture even when most of it renders
	# green (a worn strip with moss and grass growing in from the sides).
	# Older versions feathered the outside of the path as base dirt with a
	# leaf overlay above 50%; those are not path.
	var ids: Vector3 = _data.get_texture_id(world)
	if int(ids.x) == dirt_texture_id:
		return not (int(ids.y) == TEX_FOREST_FLOOR and ids.z > 0.5)

	return int(ids.y) == dirt_texture_id and ids.z > 0.85


# ============================================================
# PLACEMENT
# ============================================================

func _scatter_layer(layer: Dictionary) -> void:
	if layer.get("fill", false):
		_scatter_fill(layer)
		return

	var ids: Array = layer["ids"]
	var d_min: float = layer.get("d_min", 0.0)
	var d_max: float = minf(layer.get("d_max", 0.0), max_path_distance)
	var density: float = layer["density"]
	var clump: float = layer.get("clump", 0.5)
	var noise_offset: Vector2 = layer.get("noise_offset", Vector2.ZERO)

	var x_start: int = int(floorf(zone.position.x))
	var x_end: int = int(ceilf(zone.end.x))
	var z_start: int = int(floorf(zone.position.y))
	var z_end: int = int(ceilf(zone.end.y))

	for cz: int in range(z_start, z_end):
		for cx: int in range(x_start, x_end):
			var center: Vector2 = Vector2(float(cx) + 0.5, float(cz) + 0.5)
			var d: float = _distance_at(center)
			if layer.get("tall", false) and not layer.get("inside", false):
				# Medium and tall bands start at the edge of the whole path, so
				# they never grow on ground people can walk on.
				d = _path_distance_at(center)
			var weight: float = 1.0
			if layer.get("inside", false):
				# Grows on the path itself, only in the strip along its edges,
				# so the trail narrows and the forest creeps onto it.
				if not _is_dirt(center):
					continue

				if _edge_distance(center) > int(layer.get("inner_max", 1)):
					continue
			else:
				if d < d_min or d > d_max:
					continue

				# Ease in from the inner edge, so plants do not line up along it.
				weight = _band_weight(d, d_min, d_max, layer["taper"])
				weight *= smoothstep(d_min, d_min + float(layer.get("ramp", 1.6)), d)

				# Vegetation follows the ground: lush on grass, sparse on bare
				# leaf litter or humus. Trees and rocks ignore the texture.
				if float(layer.get("spacing", 0.0)) <= 0.0 and not layer.get("keep_size", false):
					weight *= lerpf(0.5, 1.6, _grassiness(center))
			var patches: float = lerpf(
				1.0 - clump,
				1.0 + clump,
				_noise.get_noise_2d(center.x + noise_offset.x, center.y + noise_offset.y) * 0.5 + 0.5
			)
			var expected: float = density * weight * patches
			var count: int = int(expected)
			if _rng.randf() < expected - float(count):
				count += 1

			for _i: int in range(count):
				var point: Vector2 = Vector2(
					float(cx) + _rng.randf(),
					float(cz) + _rng.randf()
				)
				var mesh_id: int = ids[_rng.randi() % ids.size()]
				_try_place(layer, mesh_id, point)


## 0 to 1: how much of the ground at this cell is green (grass or moss).
func _grassiness(center: Vector2) -> float:
	var ids: Vector3 = _data.get_texture_id(Vector3(center.x, 0.0, center.y))
	var base_green: float = _green_value(int(ids.x))
	var overlay_green: float = _green_value(int(ids.y))
	return lerpf(base_green, overlay_green, clampf(ids.z, 0.0, 1.0))


func _green_value(texture_id: int) -> float:
	match texture_id:
		TEX_GRASS:
			return 1.0
		TEX_MOSS:
			return 0.8
		TEX_FOREST_FLOOR:
			return 0.3

	return 0.0


func _band_weight(d: float, d_min: float, d_max: float, taper: float) -> float:
	var fade_start: float = lerpf(d_min, d_max, clampf(1.0 - taper, 0.0, 1.0))
	if d <= fade_start:
		return 1.0

	return clampf(1.0 - (d - fade_start) / maxf(d_max - fade_start, 0.001), 0.0, 1.0)


func _try_place(layer: Dictionary, mesh_id: int, point: Vector2) -> void:
	if not zone.has_point(point):
		return

	for blocked: Rect2 in exclusions:
		if blocked.has_point(point):
			return

	if layer.get("tall", false) and (_in_view_corridor(point) or _in_rects(low_zones, point)):
		return

	if float(layer.get("spacing", 0.0)) > 0.0 and _in_rects(no_tree_zones, point):
		return

	var spacing: float = layer.get("spacing", 0.0)
	if spacing > 0.0:
		for other: Vector2 in _tree_points:
			if other.distance_squared_to(point) < spacing * spacing:
				return

	var world: Vector3 = Vector3(point.x, 0.0, point.y)
	var height: float = _data.get_height(world)
	if is_nan(height):
		return

	var normal: Vector3 = _data.get_normal(world)
	var max_slope: float = layer.get("max_slope", 55.0)
	if normal.y < cos(deg_to_rad(max_slope)):
		return

	var scale_range: Vector2 = layer["scale"]
	# "scale_bias" above 1 favours the small end, so most plants are small and a
	# few grow larger, like a natural mix of young and old plants.
	var uniform_scale: float = lerpf(
		scale_range.x,
		scale_range.y,
		pow(_rng.randf(), float(layer.get("scale_bias", 1.0)))
	)
	# Plants are small beside the path and grow taller with distance from it,
	# as if the trail were kept low by people walking. Trees, rocks and the
	# plants growing on the path itself keep their own sizes.
	if spacing <= 0.0 and not layer.get("keep_size", false) and not layer.get("inside", false):
		uniform_scale *= lerpf(
			edge_min_scale,
			1.0,
			smoothstep(0.4, edge_growth_distance, _distance_at(point))
		)

	var width_scale: float = uniform_scale * _rng.randf_range(0.9, 1.1)

	# Wide plants need more room, so their leaves reach the trail edge
	# without covering the line the player walks along.
	var clearance: float = float(layer.get("radius", 0.0)) * width_scale * _rng.randf_range(0.55, 0.95)
	# The distance field counts whole cells, so a point in the first cell off
	# the path can be right on its edge (field value 1.0 means 0 to 1 m away).
	# Medium and tall plants therefore need the conservative figure, so none of
	# their foliage can hang over the line people walk along.
	var edge_distance: float = _distance_at(point)
	if layer.get("tall", false) or float(layer.get("radius", 0.0)) >= 0.5:
		edge_distance = _path_distance_at(point)
	if layer.get("tall", false) or float(layer.get("radius", 0.0)) >= 0.5:
		edge_distance -= 1.0
	if edge_distance < clearance:
		return

	var up: Vector3 = Vector3.UP.lerp(normal, layer.get("align", 0.0)).normalized()
	var basis: Basis = Basis(Quaternion(Vector3.UP, up))
	basis = basis * Basis(Vector3.UP, _rng.randf() * TAU)

	var tilt: float = deg_to_rad(layer.get("tilt", 0.0))
	if tilt > 0.0:
		basis = basis * Basis.from_euler(Vector3(
			_rng.randf_range(-tilt, tilt),
			0.0,
			_rng.randf_range(-tilt, tilt)
		))

	basis = basis.scaled_local(Vector3(width_scale, uniform_scale, width_scale))

	var origin: Vector3 = Vector3(
		point.x,
		height + float(layer.get("sink", 0.0)),
		point.y
	)

	if not _pending_transforms.has(mesh_id):
		var transforms: Array[Transform3D] = []
		_pending_transforms[mesh_id] = transforms
		_pending_colors[mesh_id] = PackedColorArray()

	(_pending_transforms[mesh_id] as Array[Transform3D]).append(
		Transform3D(basis, origin)
	)

	var shade: float = _rng.randf_range(0.78, 1.0)
	(_pending_colors[mesh_id] as PackedColorArray).append(
		Color(shade, shade, shade, 1.0)
	)

	if spacing > 0.0:
		_tree_points.append(point)

	_placed_count[mesh_id] = int(_placed_count.get(mesh_id, 0)) + 1


func _in_view_corridor(point: Vector2) -> bool:
	for corridor: Dictionary in view_corridors:
		var origin: Vector2 = corridor["origin"]
		var offset: Vector2 = point - origin
		var distance: float = offset.length()
		if distance < 0.001:
			return true

		if distance > float(corridor["length"]):
			continue

		var direction: Vector2 = corridor["direction"]
		var angle: float = absf(rad_to_deg(offset.angle_to(direction)))
		if angle <= float(corridor["half_angle"]):
			return true

	return false



# ============================================================
# GROUND TEXTURES
# ============================================================

## Terrain3D texture slots (see the Terrain3DAssets in dream_intro.tscn).
## Slots 0 (grass) and 1 (path dirt) are left alone: slot 1 marks the paths.
const TEX_GRASS: int = 0
const TEX_FOREST_FLOOR: int = 2
const TEX_MOSS: int = 3
const TEX_HUMUS: int = 4
const TEX_PINE_MULCH: int = 5
const TEX_ROCK: int = 6

## Paint the forest floor textures around the paths.
var paint_ground_textures: bool = true

## Ground is painted this far past max_path_distance, so the edge of the
## painted area is well inside the fog.
var ground_extra_distance: float = 8.0

## Slopes steeper than this (degrees) turn to mossy rock.
var rock_slope_start: float = 26.0
var rock_slope_full: float = 38.0

## Radius of pine-needle mulch around each tree.
var mulch_radius: float = 2.4

var _ground_noise_big: FastNoiseLite = FastNoiseLite.new()
var _ground_noise_fine: FastNoiseLite = FastNoiseLite.new()
var _ground_noise_mix: FastNoiseLite = FastNoiseLite.new()


## Painted cells use no "auto" flag and never use slot 1, so a rerun still finds
## the same paths. Returns the number of painted cells.
func _paint_ground() -> int:
	_ground_noise_big.seed = seed_value + 11
	_ground_noise_big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ground_noise_big.frequency = 0.05
	_ground_noise_fine.seed = seed_value + 23
	_ground_noise_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ground_noise_fine.frequency = 0.3
	_ground_noise_mix.seed = seed_value + 31
	_ground_noise_mix.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ground_noise_mix.frequency = 0.16
	var path_surface_cells: int = _paint_path_surface()

	var reach: float = max_path_distance + ground_extra_distance
	var painted: int = 0

	var x_start: int = int(floorf(zone.position.x))
	var x_end: int = int(ceilf(zone.end.x))
	var z_start: int = int(floorf(zone.position.y))
	var z_end: int = int(ceilf(zone.end.y))

	for cz: int in range(z_start, z_end):
		for cx: int in range(x_start, x_end):
			var center: Vector2 = Vector2(float(cx) + 0.5, float(cz) + 0.5)
			var d: float = _distance_at(center)
			if d <= 0.0 or d > reach or _in_rects(exclusions, center):
				continue

			var world: Vector3 = Vector3(center.x, 0.0, center.y)
			if is_nan(_data.get_height(world)):
				continue

			if _is_dirt(center):
				continue

			var cell: Dictionary = _choose_ground(center, world, d)
			_data.set_control_base_id(world, int(cell["base"]))
			_data.set_control_overlay_id(world, int(cell["overlay"]))
			_data.set_control_blend(world, float(cell["blend"]))
			_data.set_control_auto(world, false)
			painted += 1

	return painted + path_surface_cells



## Gives the path itself some variety. Cells keep the dirt texture as their
## base, which is how every tool recognises a path, and get an overlay below
## 50% so the dirt stays dominant: damp patches in the worn middle, leaf litter
## creeping in at the edges, and the occasional embedded stone.
func _paint_path_surface() -> int:
	var stone_noise: FastNoiseLite = FastNoiseLite.new()
	stone_noise.seed = seed_value + 5
	stone_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	stone_noise.frequency = 0.24
	var patch_noise: FastNoiseLite = FastNoiseLite.new()
	patch_noise.seed = seed_value + 9
	patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patch_noise.frequency = 0.11

	var painted: int = 0
	var x_start: int = int(floorf(zone.position.x))
	var x_end: int = int(ceilf(zone.end.x))
	var z_start: int = int(floorf(zone.position.y))
	var z_end: int = int(ceilf(zone.end.y))

	for cz: int in range(z_start, z_end):
		for cx: int in range(x_start, x_end):
			var center: Vector2 = Vector2(float(cx) + 0.5, float(cz) + 0.5)
			if not _is_dirt(center):
				continue

			var world: Vector3 = Vector3(center.x, 0.0, center.y)
			var fine: float = _ground_noise_fine.get_noise_2d(center.x, center.y) * 0.5 + 0.5
			var stone: float = stone_noise.get_noise_2d(center.x, center.y)
			var edge: int = _edge_distance(center)

			# Several textures are mixed cell by cell, with a random jitter on
			# every blend, so the path never reads as one flat colour: stony
			# stretches, leaf-littered stretches, dark damp earth, and sprinkles
			# of needles and moss.
			var patch: float = patch_noise.get_noise_2d(center.x, center.y)
			var jitter: float = _rng.randf_range(-0.09, 0.09)
			var overlay: int = TEX_HUMUS
			var blend: float = 0.2 + fine * 0.2
			if stone > 0.12:
				overlay = TEX_ROCK
				blend = 0.3 + minf((stone - 0.12) * 0.8, 0.16)
			elif edge <= 1:
				overlay = TEX_FOREST_FLOOR if patch > -0.2 else TEX_MOSS
				blend = 0.32 + fine * 0.14
			elif patch > 0.22:
				overlay = TEX_FOREST_FLOOR
				blend = 0.2 + fine * 0.26
			elif patch < -0.3:
				overlay = TEX_HUMUS
				blend = 0.28 + fine * 0.18
			elif fine > 0.62:
				overlay = TEX_PINE_MULCH
				blend = 0.18 + (fine - 0.62) * 0.7
			elif edge <= 2:
				overlay = TEX_MOSS
				blend = 0.12 + fine * 0.2
			blend += jitter

			# Thin the dirt to a worn strip: green grows in from both sides.
			# The cell stays path (dirt base) but renders mostly grass or moss,
			# and the green creeps further in on a wandering noise, so the dirt
			# is a narrow, irregular line like a real forest trail.
			var wander: float = patch_noise.get_noise_2d(center.x * 1.7 + 40.0, center.y * 1.7 - 25.0)
			var green: float = 0.0
			if edge <= 2:
				green = 0.82 + fine * 0.15
			elif edge == 3:
				green = 0.4 + wander * 0.4 + fine * 0.2
			else:
				green = 0.04 + wander * 0.25
			green += _rng.randf_range(-0.08, 0.08)
			if stone > 0.12:
				green *= 0.4

			if green > 0.5:
				overlay = TEX_GRASS if fine > 0.35 else TEX_MOSS
				_data.set_control_base_id(world, dirt_texture_id)
				_data.set_control_overlay_id(world, overlay)
				_data.set_control_blend(world, clampf(green, 0.5, 0.97))
				_data.set_control_auto(world, false)
				painted += 1
				continue

			_data.set_control_base_id(world, dirt_texture_id)
			_data.set_control_overlay_id(world, overlay)
			_data.set_control_blend(world, clampf(blend, 0.05, 0.46))
			_data.set_control_auto(world, false)
			painted += 1

	return painted


## Rough distance from a path cell to the nearest non-path cell, 1 to 3 m.
func _edge_distance(center: Vector2) -> int:
	for radius: int in range(1, 5):
		for step: int in range(8):
			var angle: float = float(step) * TAU / 8.0
			var probe: Vector2 = center + Vector2(cos(angle), sin(angle)) * float(radius)
			if not _is_dirt(probe):
				return radius

	return 5

## Decides base, overlay and blend for one cell. Precedence: rock on steep
## ground, then damp humus beside the trail, then moss patches, then leaves.
func _choose_ground(center: Vector2, world: Vector3, d: float) -> Dictionary:
	var big: float = _ground_noise_big.get_noise_2d(center.x, center.y)
	var fine: float = _ground_noise_fine.get_noise_2d(center.x, center.y) * 0.5 + 0.5

	var slope: float = rad_to_deg(acos(clampf(_data.get_normal(world).y, 0.0, 1.0)))
	var rock: float = smoothstep(rock_slope_start, rock_slope_full, slope)
	if rock > 0.05:
		return {
			"base": TEX_HUMUS if rock < 0.6 else TEX_ROCK,
			"overlay": TEX_ROCK,
			"blend": clampf(rock * 0.9 + fine * 0.1, 0.0, 1.0),
		}

	# Mostly green ground, as in a real Atlantic-forest trail: the dirt line
	# is surrounded by a carpet of grass and moss, with leaf litter, humus and
	# needles showing through in patches. Cells right beside the path have a
	# grass base with only a hint of dirt, so the trail fades out softly. (The
	# base must not be dirt here: a dirt base marks a path cell.)
	var mix: float = _ground_noise_mix.get_noise_2d(center.x, center.y)
	var jitter: float = _rng.randf_range(-0.12, 0.12)
	if d < 1.8:
		return {
			"base": TEX_GRASS,
			"overlay": dirt_texture_id,
			"blend": clampf(0.12 + (1.0 - d / 1.8) * 0.3 + jitter * 0.5, 0.05, 0.45),
		}

	var carpet: float = smoothstep(-0.25, 0.25, big) # broad green vs. litter areas
	var base: int = TEX_GRASS if carpet > 0.45 or fine > 0.7 else TEX_FOREST_FLOOR
	var overlay: int = TEX_MOSS
	var blend: float = 0.3 + fine * 0.35 + jitter
	if mix > 0.32:
		overlay = TEX_PINE_MULCH
		blend = 0.25 + fine * 0.3 + jitter
	elif mix < -0.3:
		overlay = TEX_HUMUS
		blend = 0.3 + fine * 0.3 + jitter
	elif base == TEX_FOREST_FLOOR:
		overlay = TEX_GRASS if fine > 0.4 else TEX_MOSS
		blend = 0.5 + fine * 0.35 + jitter
	return {
		"base": base,
		"overlay": overlay,
		"blend": clampf(blend, 0.08, 0.9),
	}


## Pine needles pile up under the trees placed by the spaced (tree) layers.
func _paint_tree_mulch() -> void:
	var reach: int = int(ceilf(mulch_radius))
	for tree: Vector2 in _tree_points:
		for dz: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				var offset: Vector2 = Vector2(dx, dz)
				var distance: float = offset.length()
				if distance > mulch_radius:
					continue

				var cell: Vector2 = Vector2(floorf(tree.x) + dx + 0.5, floorf(tree.y) + dz + 0.5)
				if _distance_at(cell) <= 0.0 or _is_dirt(cell):
					continue

				var world: Vector3 = Vector3(cell.x, 0.0, cell.y)
				if is_nan(_data.get_height(world)):
					continue

				# Leave steep rock alone; mulch only softens the flat ground.
				if _data.get_control_overlay_id(world) == TEX_ROCK:
					continue

				var falloff: float = 1.0 - smoothstep(0.4, mulch_radius, distance)
				_data.set_control_base_id(world, TEX_FOREST_FLOOR)
				_data.set_control_overlay_id(world, TEX_PINE_MULCH)
				_data.set_control_blend(world, clampf(falloff * 0.9, 0.0, 0.9))
				_data.set_control_auto(world, false)

## Adds gentle bumps and hollows to the ground, and sinks the path a few
## centimetres below its surroundings, so the forest is no longer a flat sheet.
## ONE-TIME: it adds to the current heights, so running it twice doubles the
## effect. Run it before generate(), since plants read the terrain height.
## The overlook area (view_corridors[0].origin) is faded out to stay level.
func add_ground_relief(terrain: Terrain3D, amplitude: float = 1.0) -> int:
	_terrain = terrain
	_data = terrain.data
	if _distance.is_empty() and _build_distance_field() == 0:
		return 0

	var large: FastNoiseLite = FastNoiseLite.new()
	large.seed = seed_value + 41
	large.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	large.frequency = 0.07
	var small: FastNoiseLite = FastNoiseLite.new()
	small.seed = seed_value + 43
	small.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	small.frequency = 0.38

	var keep_level: Vector2 = Vector2.INF
	if not view_corridors.is_empty():
		keep_level = view_corridors[0]["origin"]

	var changed: int = 0
	for cz: int in range(int(floorf(zone.position.y)), int(ceilf(zone.end.y))):
		for cx: int in range(int(floorf(zone.position.x)), int(ceilf(zone.end.x))):
			var center: Vector2 = Vector2(float(cx) + 0.5, float(cz) + 0.5)
			if _distance_at(center) > max_path_distance:
				continue

			var world: Vector3 = Vector3(center.x, 0.0, center.y)
			var height: float = _data.get_height(world)
			if is_nan(height):
				continue

			var offset: float = large.get_noise_2d(center.x, center.y) * 0.3
			offset += small.get_noise_2d(center.x, center.y) * 0.1
			if _is_dirt(center):
				offset -= 0.07

			if keep_level.is_finite():
				offset *= smoothstep(14.0, 26.0, center.distance_to(keep_level))

			_data.set_height(world, height + offset * amplitude)
			changed += 1

	for region: Terrain3DRegion in _data.get_regions_active():
		region.set_modified(true)

	_data.calc_height_range(true)
	return changed


func _commit() -> int:
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var added: int = 0

	for mesh_id: int in _pending_transforms:
		var transforms: Array[Transform3D] = _pending_transforms[mesh_id]
		var colors: PackedColorArray = _pending_colors[mesh_id]
		instancer.add_transforms(mesh_id, transforms, colors)
		added += transforms.size()

	return added


# ============================================================
# CLEARING
# ============================================================

## Removes existing plants whose position is inside the zone, keeping every
## other instance of the same mesh. Terrain3D stores instance X/Z relative
## to the region, so positions are converted to world space before testing.
func _clear_existing_plants() -> int:
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var removed: int = 0

	for region: Terrain3DRegion in _data.get_regions_active():
		var location: Vector2i = region.location
		var offset: Vector2 = Vector2(location) * region_size
		if not Rect2(offset, Vector2(region_size, region_size)).intersects(zone):
			continue

		var instances: Dictionary = region.get_instances()
		for mesh_id: int in CLEARED_MESH_IDS:
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
					var world: Vector2 = Vector2(
						transform.origin.x + offset.x,
						transform.origin.z + offset.y
					)
					if zone.has_point(world):
						removed_here += 1
						continue

					kept_transforms.append(transform)
					kept_colors.append(
						cell_colors[i] if i < cell_colors.size() else Color.WHITE
					)

			if removed_here == 0:
				continue

			instancer.clear_by_region(region, mesh_id)
			if not kept_transforms.is_empty():
				instancer.append_region(
					region,
					mesh_id,
					kept_transforms,
					kept_colors,
					true
				)

			removed += removed_here

	return removed


## Dirt that actually renders as dirt. Path cells whose overlay is mostly
## grass or moss still count as path for painting, but plants should measure
## their distance from the visible dirt line, so the bands hug the walkable
## strip instead of the wider painted path.
func _is_visible_dirt(point: Vector2) -> bool:
	if not _is_dirt(point):
		return false

	var ids: Vector3 = _data.get_texture_id(Vector3(point.x, 0.0, point.y))
	if int(ids.x) == dirt_texture_id and ids.z > 0.5:
		return int(ids.y) not in [TEX_GRASS, TEX_MOSS]

	return true


func _build_path_field() -> void:
	var cell_count: int = _grid_size.x * _grid_size.y
	_path_distance.resize(cell_count)
	for gy: int in range(_grid_size.y):
		for gx: int in range(_grid_size.x):
			var index: int = gy * _grid_size.x + gx
			_path_distance[index] = (
				0.0 if (_is_dirt(_grid_to_world(gx, gy)) or _on_virtual_path(_grid_to_world(gx, gy))) else INF
			)

	var diagonal: float = 1.4142
	for gy: int in range(_grid_size.y):
		for gx: int in range(_grid_size.x):
			var index: int = gy * _grid_size.x + gx
			var best: float = _path_distance[index]
			if gx > 0:
				best = minf(best, _path_distance[index - 1] + 1.0)
			if gy > 0:
				best = minf(best, _path_distance[index - _grid_size.x] + 1.0)
				if gx > 0:
					best = minf(best, _path_distance[index - _grid_size.x - 1] + diagonal)
				if gx < _grid_size.x - 1:
					best = minf(best, _path_distance[index - _grid_size.x + 1] + diagonal)
			_path_distance[index] = best

	for gy: int in range(_grid_size.y - 1, -1, -1):
		for gx: int in range(_grid_size.x - 1, -1, -1):
			var index: int = gy * _grid_size.x + gx
			var best: float = _path_distance[index]
			if gx < _grid_size.x - 1:
				best = minf(best, _path_distance[index + 1] + 1.0)
			if gy < _grid_size.y - 1:
				best = minf(best, _path_distance[index + _grid_size.x] + 1.0)
				if gx < _grid_size.x - 1:
					best = minf(best, _path_distance[index + _grid_size.x + 1] + diagonal)
				if gx > 0:
					best = minf(best, _path_distance[index + _grid_size.x - 1] + diagonal)
			_path_distance[index] = best


func _path_distance_at(point: Vector2) -> float:
	var gx: int = int(floorf(point.x - _grid_origin.x))
	var gy: int = int(floorf(point.y - _grid_origin.y))
	if gx < 0 or gy < 0 or gx >= _grid_size.x or gy >= _grid_size.y:
		return INF

	return _path_distance[gy * _grid_size.x + gx]


func _in_rects(rects: Array[Rect2], point: Vector2) -> bool:
	for rect: Rect2 in rects:
		if rect.has_point(point):
			return true

	return false


func _on_virtual_path(point: Vector2) -> bool:
	for line: PackedVector2Array in virtual_paths:
		for i: int in range(line.size() - 1):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				point,
				line[i],
				line[i + 1]
			)
			if closest.distance_to(point) <= virtual_path_half_width:
				return true

	return false


## Scatters a "fill" layer uniformly over fill_zones.
func _scatter_fill(layer: Dictionary) -> void:
	var ids: Array = layer["ids"]
	var density: float = layer["density"]
	for rect: Rect2 in fill_zones:
		var expected_total: float = density * rect.get_area()
		var count: int = int(expected_total)
		if _rng.randf() < expected_total - float(count):
			count += 1

		for _i: int in range(count):
			var point: Vector2 = Vector2(
				_rng.randf_range(rect.position.x, rect.end.x),
				_rng.randf_range(rect.position.y, rect.end.y)
			)
			_try_place(layer, ids[_rng.randi() % ids.size()], point)
