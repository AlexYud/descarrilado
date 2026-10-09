@tool
extends RefCounted
class_name MenuChunkGenerator

## Rebuilds the four main-menu scenery chunks (A to D) as one continuous
## 128 m ring cut into four 32 m pieces, so every seam, including D back to A,
## lines up and the loop stays seamless. Terrain3D cannot be used here because
## the chunks loop, so each chunk has:
##   - a ground mesh whose vertex colours blend the forest-floor textures
##     (see assets/shaders/menu_ground.gdshader),
##   - the original train tracks, untouched,
##   - wandering barbed fences on both sides of the railway,
##   - dense vegetation as MultiMeshes (low plants between the train and the
##     fences, a belt of medium plants, then a tall wall with trees).
##
## Coordinates: x across the railway (tracks at 0), s along the 128 m ring.
## Chunk i covers s in [32 i, 32 i + 32) and local z = s - 32 i - 16.

const RING_LENGTH: float = 128.0
const CHUNK_LENGTH: float = 32.0
const CHUNK_COUNT: int = 4
const HALF_WIDTH: float = 35.0

## Ground surface height, matching the old 0.2 m box (top at y -0.1).
const BASE_HEIGHT: float = -0.1
const FENCE_LIFT: float = 0.65
const FENCE_PIECE: float = 1.78
## The fence line: average distance from the track, and its limits (the wagons are
## about 2.4 m from the centre).
const FENCE_BASE_X: float = 3.75
const FENCE_MIN_X: float = 3.1
const FENCE_MAX_X: float = 5.3

const OUT_DIR: String = "res://scenes/menu/scenery/generated/"
const CHUNK_PATHS: Array[String] = [
	"res://scenes/menu/scenery/menu_scenery_chunk_a.tscn",
	"res://scenes/menu/scenery/menu_scenery_chunk_b.tscn",
	"res://scenes/menu/scenery/menu_scenery_chunk_c.tscn",
	"res://scenes/menu/scenery/menu_scenery_chunk_d.tscn",
]
const CHUNK_NAMES: Array[String] = ["ChunkA", "ChunkB", "ChunkC", "ChunkD"]

const FENCE_MESH: String = (
	"res://assets/models/wooden_structures/barbed_fence_big_no_angle/"
	+ "barbed_fence_big_no_angle_mesh.tres"
)

## Mesh sources. A *_mesh.tres is created next to the .glb when missing.
const MESH_GLBS: Dictionary = {
	"bush_a": "res://assets/models/foliage/big_foliage_02/big_foliage_02.glb",
	"bush_b": "res://assets/models/foliage/big_foliage_01/big_foliage_01.glb",
	"leafy": "res://assets/models/foliage/medium_foliage_01/medium_foliage_01.glb",
	"fern": "res://assets/models/foliage/medium_foliage_02/medium_foliage_02.glb",
	"grass_a": "res://assets/models/foliage/small_foliage_01/small_foliage_01.glb",
	"grass_b": "res://assets/models/foliage/small_foliage_02/small_foliage_02.glb",
	"litter": "res://assets/models/foliage/ground_leaves_01/ground_leaves_01.glb",
	"tall_a": "res://assets/models/foliage/tall_thin_foliage_01/tall_thin_foliage_01.glb",
	"tall_b": "res://assets/models/foliage/tall_thin_foliage_02/tall_thin_foliage_02.glb",
	"red": "res://assets/models/foliage/kelp_like_foliage/kelp_like_foliage.glb",
	"flower_a": "res://assets/models/foliage/white_flower_01/white_flower_01.glb",
	"flower_b": "res://assets/models/foliage/white_flower_02/white_flower_02.glb",
	"tree_big": "res://assets/models/trees/custom_tree/tree_test.glb",
	"tree_mid": "res://assets/models/trees/medium_generic_tree/mediun_generic_tree.glb",
	"tree_small": "res://assets/models/trees/pitangueira/pitangueira.glb",
	"araucaria": "res://assets/models/trees/araucaria/araucaria.glb",
	"pebble": "res://assets/models/rocks/floor_path/rock_001/rock_001.glb",
}

## Trees cast shadows; everything else is too small or too dense to matter.
const SHADOW_MESHES: Array[String] = ["tree_big", "tree_mid", "tree_small", "araucaria"]

const TEXTURE_FOLDERS: Dictionary = {
	"leaves": "res://assets/textures/forest_floor_leaves/forest_floor_leaves",
	"moss": "res://assets/textures/moss_ground/moss_ground",
	"humus": "res://assets/textures/dark_humus/dark_humus",
	"mulch": "res://assets/textures/pine_needle_mulch/pine_needle_mulch",
}
const DIRT_COLOR: String = "res://assets/textures/dirt/GroundDirtWeedsPatchy004_COL_2K.jpg"
const DIRT_NORMAL: String = "res://assets/textures/dirt/GroundDirtWeedsPatchy004_NRM_2K.jpg"

var seed_value: int = 424242

## Vegetation density multiplier, for tuning the cost of the menu.
var density_scale: float = 1.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _noises: Dictionary = {}
var _meshes: Dictionary = {}
var _tree_points: Array[Vector2] = []
var _transforms: Dictionary = {}
var _tree_centres: Array[Vector2] = []
var _reaches: Dictionary = {}


## Generates and saves everything. Returns a summary dictionary.
func generate() -> Dictionary:
	_rng.seed = seed_value
	_tree_points.clear()
	_tree_centres.clear()
	_transforms.clear()

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_prepare_meshes()

	var tracks: Array[Transform3D] = _read_track_transforms()
	var material: ShaderMaterial = _build_material()

	_scatter_all()
	var fences: Array[Transform3D] = _build_fences()

	var summary: Dictionary = {}
	for index: int in range(CHUNK_COUNT):
		summary[CHUNK_NAMES[index]] = _build_chunk(index, tracks, material, fences)

	return summary


# ============================================================
# PERIODIC NOISE
# ============================================================

func _noise(name: String, frequency: float) -> FastNoiseLite:
	if not _noises.has(name):
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = seed_value + hash(name) % 1000
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = frequency
		_noises[name] = noise

	return _noises[name]


## Noise that repeats exactly every RING_LENGTH metres along s, in [-1, 1].
func _ring(name: String, frequency: float, x: float, s: float) -> float:
	var radius: float = RING_LENGTH / TAU
	var angle: float = s / RING_LENGTH * TAU
	return _noise(name, frequency).get_noise_3d(
		x,
		cos(angle) * radius,
		sin(angle) * radius
	)


func _wrap(s: float) -> float:
	return fposmod(s, RING_LENGTH)


func _ring_distance(a: float, b: float) -> float:
	var d: float = absf(a - b)
	return minf(d, RING_LENGTH - d)


# ============================================================
# TERRAIN SHAPE
# ============================================================

## Distance from the track to the fence on one side (side is -1 or +1). The line
## wanders at three scales (long swings, mid bends, fine wobble) and never comes
## nearer than FENCE_MIN_X to the wagons.
func _fence_x(side: int, s: float) -> float:
	var wobble: float = (
		_ring("fence%d" % side, 0.045, 0.0, s) * 1.4
		+ _ring("fence_mid%d" % side, 0.13, 0.0, s) * 0.7
		+ _ring("fence_fine%d" % side, 0.35, 0.0, s) * 0.2
	)
	return float(side) * clampf(FENCE_BASE_X + wobble, FENCE_MIN_X, FENCE_MAX_X)

func _height(x: float, s: float) -> float:
	var distance: float = absf(x)
	var relief: float = (
		_ring("relief", 0.07, x, s) * 0.3
		+ _ring("relief_fine", 0.35, x, s) * 0.08
	)
	return BASE_HEIGHT + relief * smoothstep(3.6, 8.0, distance)


func _normal(x: float, s: float) -> Vector3:
	var e: float = 0.4
	var dx: float = _height(x + e, s) - _height(x - e, s)
	var ds: float = _height(x, s + e) - _height(x, s - e)
	return Vector3(-dx, 2.0 * e, -ds).normalized()


# ============================================================
# MESHES AND MATERIAL
# ============================================================

func _prepare_meshes() -> void:
	_meshes.clear()
	for key: String in MESH_GLBS:
		var glb: String = MESH_GLBS[key]
		var base: String = glb.get_basename()
		var tres: String = base + "_mesh.tres"
		if not ResourceLoader.exists(tres):
			var scene: PackedScene = load(glb) as PackedScene
			var root: Node = scene.instantiate()
			var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
			var mesh: Mesh = (found[0] as MeshInstance3D).mesh
			ResourceSaver.save(mesh, tres)
			root.free()

		_meshes[key] = load(tres)

	_meshes["fence"] = load(FENCE_MESH)


func _read_track_transforms() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var old: Node = (load(CHUNK_PATHS[0]) as PackedScene).instantiate()
	var tracks: Node = old.get_node_or_null("TrainTracks")
	if tracks != null:
		for child: Node in tracks.get_children():
			result.append((child as Node3D).transform)

	old.free()
	if result.is_empty():
		result.append(Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 0.95), Vector3(0, 0, -7.976)))
		result.append(Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 0.95), Vector3(0, 0, 7.962)))

	return result


func _build_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/menu_ground.gdshader") as Shader
	for key: String in TEXTURE_FOLDERS:
		var prefix: String = TEXTURE_FOLDERS[key]
		material.set_shader_parameter("tex_" + key, load(prefix + "_Color.jpg"))
		material.set_shader_parameter("nrm_" + key, load(prefix + "_NormalGL.jpg"))

	material.set_shader_parameter("tex_dirt", load(DIRT_COLOR))
	material.set_shader_parameter("nrm_dirt", load(DIRT_NORMAL))
	ResourceSaver.save(material, OUT_DIR + "menu_ground_material.tres")
	return load(OUT_DIR + "menu_ground_material.tres") as ShaderMaterial


# ============================================================
# VEGETATION
# ============================================================

## Layers. zone "inside" is between the train and the fence, "outside" is
## beyond it. d_min/d_max are metres from the fence (outside) or from the
## train side (inside). "grow" ramps plant size from the fence outward.
func _layers() -> Array[Dictionary]:
	return [
		# --- between the train and the fences: low plants only ---
		{"mesh": "grass_a", "zone": "inside", "density": 5.0, "scale": Vector2(0.3, 0.8), "bias": 1.5, "align": 0.7, "tilt": 12.0},
		{"mesh": "grass_b", "zone": "inside", "density": 5.0, "scale": Vector2(0.3, 0.8), "bias": 1.5, "align": 0.7, "tilt": 12.0},
		{"mesh": "fern", "zone": "inside", "density": 0.9, "scale": Vector2(0.08, 0.26), "bias": 1.4, "align": 0.5, "tilt": 10.0},
		{"mesh": "leafy", "zone": "inside", "density": 0.9, "scale": Vector2(0.2, 0.5), "bias": 1.3, "align": 0.3},
		{"mesh": "litter", "zone": "inside", "density": 0.7, "scale": Vector2(0.2, 0.34), "bias": 1.0, "align": 1.0, "sink": -0.02},
		{"mesh": "pebble", "zone": "inside", "density": 0.3, "scale": Vector2(0.4, 1.1), "bias": 1.6, "align": 1.0, "sink": -0.02},
		{"mesh": "flower_a", "zone": "inside", "density": 0.06, "scale": Vector2(0.8, 1.2), "bias": 1.0, "align": 0.3},
		# --- outside the fences: low understory near the fence ---
		{"mesh": "grass_a", "zone": "outside", "d_min": 0.3, "d_max": 11.0, "density": 5.0, "scale": Vector2(0.3, 0.85), "bias": 1.6, "align": 0.7, "tilt": 12.0, "grow": true},
		{"mesh": "grass_b", "zone": "outside", "d_min": 0.3, "d_max": 11.0, "density": 5.0, "scale": Vector2(0.3, 0.85), "bias": 1.6, "align": 0.7, "tilt": 12.0, "grow": true},
		{"mesh": "litter", "zone": "outside", "d_min": 0.3, "d_max": 9.0, "density": 0.6, "scale": Vector2(0.2, 0.34), "bias": 1.0, "align": 1.0, "sink": -0.02},
		{"mesh": "flower_a", "zone": "outside", "d_min": 0.4, "d_max": 4.0, "density": 0.08, "scale": Vector2(0.8, 1.2), "bias": 1.0, "align": 0.3},
		{"mesh": "flower_b", "zone": "outside", "d_min": 0.4, "d_max": 4.0, "density": 0.08, "scale": Vector2(0.8, 1.2), "bias": 1.0, "align": 0.3},
		# --- belt of medium and tall plants hugging the fences ---
		{"mesh": "leafy", "zone": "outside", "d_min": 0.5, "d_max": 5.0, "density": 1.7, "scale": Vector2(0.55, 1.3), "bias": 1.0, "align": 0.3, "grow": true},
		{"mesh": "fern", "zone": "outside", "d_min": 0.6, "d_max": 6.0, "density": 0.9, "scale": Vector2(0.3, 0.9), "bias": 1.2, "align": 0.5, "tilt": 10.0, "grow": true},
		{"mesh": "bush_a", "zone": "outside", "d_min": 0.8, "d_max": 7.0, "density": 0.55, "scale": Vector2(0.45, 1.0), "bias": 1.0, "align": 0.0, "grow": true},
		{"mesh": "bush_b", "zone": "outside", "d_min": 0.8, "d_max": 7.0, "density": 0.55, "scale": Vector2(0.45, 1.0), "bias": 1.0, "align": 0.0, "grow": true},
		{"mesh": "tall_a", "zone": "outside", "d_min": 0.9, "d_max": 7.0, "density": 0.3, "scale": Vector2(0.55, 1.1), "bias": 1.0, "align": 0.2, "grow": true},
		{"mesh": "tall_b", "zone": "outside", "d_min": 0.9, "d_max": 7.0, "density": 0.3, "scale": Vector2(0.55, 1.1), "bias": 1.0, "align": 0.2, "grow": true},
		{"mesh": "red", "zone": "outside", "d_min": 1.0, "d_max": 7.0, "density": 0.12, "scale": Vector2(0.5, 1.0), "bias": 1.0, "align": 0.3, "grow": true},
		# --- tall wall behind the belt ---
		{"mesh": "bush_a", "zone": "outside", "d_min": 2.5, "d_max": 27.0, "density": 0.7, "scale": Vector2(1.1, 1.8), "bias": 1.0, "align": 0.0, "taper": true},
		{"mesh": "bush_b", "zone": "outside", "d_min": 2.5, "d_max": 27.0, "density": 0.7, "scale": Vector2(1.1, 1.8), "bias": 1.0, "align": 0.0, "taper": true},
		{"mesh": "fern", "zone": "outside", "d_min": 2.5, "d_max": 22.0, "density": 0.55, "scale": Vector2(0.9, 1.5), "bias": 1.0, "align": 0.4, "taper": true},
		{"mesh": "tall_a", "zone": "outside", "d_min": 3.0, "d_max": 24.0, "density": 0.35, "scale": Vector2(0.9, 1.5), "bias": 1.0, "align": 0.2, "taper": true},
		{"mesh": "tall_b", "zone": "outside", "d_min": 3.0, "d_max": 24.0, "density": 0.35, "scale": Vector2(0.9, 1.5), "bias": 1.0, "align": 0.2, "taper": true},
		{"mesh": "leafy", "zone": "outside", "d_min": 4.0, "d_max": 20.0, "density": 0.5, "scale": Vector2(1.0, 1.7), "bias": 1.0, "align": 0.3, "taper": true},
		# --- trees ---
		{"mesh": "tree_small", "zone": "outside", "d_min": 3.0, "d_max": 30.0, "density": 0.035, "scale": Vector2(0.6, 0.95), "bias": 1.0, "align": 0.0, "spacing": 4.2, "sink": -0.15},
		{"mesh": "tree_mid", "zone": "outside", "d_min": 3.5, "d_max": 30.0, "density": 0.05, "scale": Vector2(0.8, 1.25), "bias": 1.0, "align": 0.0, "spacing": 4.2, "tilt": 3.0, "sink": -0.15},
		{"mesh": "tree_big", "zone": "outside", "d_min": 4.0, "d_max": 30.0, "density": 0.04, "scale": Vector2(0.8, 1.25), "bias": 1.0, "align": 0.0, "spacing": 4.2, "tilt": 3.0, "sink": -0.15},
		{"mesh": "araucaria", "zone": "outside", "d_min": 8.0, "d_max": 30.0, "density": 0.004, "scale": Vector2(0.8, 1.1), "bias": 1.0, "align": 0.0, "spacing": 12.0, "sink": -0.15},
	]


func _scatter_all() -> void:
	for layer: Dictionary in _layers():
		_scatter_layer(layer)


func _scatter_layer(layer: Dictionary) -> void:
	var zone: String = layer["zone"]
	var density: float = float(layer["density"]) * density_scale
	var key: String = layer["mesh"]
	var x_limit: int = int(HALF_WIDTH)

	for side: int in [-1, 1]:
		for cell_s: int in range(int(RING_LENGTH)):
			for cell_x: int in range(2, x_limit):
				var x: float = float(side) * (float(cell_x) + 0.5)
				var s: float = float(cell_s) + 0.5
				var fence: float = absf(_fence_x(side, s))
				var weight: float = 1.0
				if zone == "inside":
					if absf(x) < 2.75 or absf(x) > fence - 0.35:
						continue
				else:
					var d: float = absf(x) - fence
					var d_min: float = float(layer.get("d_min", 0.0))
					var d_max: float = float(layer.get("d_max", 30.0))
					if d < d_min or d > d_max:
						continue

					if layer.get("taper", false):
						weight = 1.0 - smoothstep(d_max * 0.45, d_max, d)

				var patches: float = 0.55 + 0.9 * (
					_ring("patch_" + key, 0.12, x, s) * 0.5 + 0.5
				)
				var expected: float = density * weight * patches
				var count: int = int(expected)
				if _rng.randf() < expected - float(count):
					count += 1

				for _i: int in range(count):
					var px: float = x + _rng.randf_range(-0.5, 0.5)
					var ps: float = s + _rng.randf_range(-0.5, 0.5)
					_place(layer, px, _wrap(ps), side, fence)


func _place(layer: Dictionary, x: float, s: float, side: int, fence: float) -> void:
	var key: String = layer["mesh"]
	var distance: float = absf(x)

	var spacing: float = float(layer.get("spacing", 0.0))
	if spacing > 0.0:
		for other: Vector2 in _tree_points:
			if Vector2(other.x - x, _ring_distance(other.y, s)).length() < spacing:
				return

	var scale_range: Vector2 = layer["scale"]
	var size: float = lerpf(
		scale_range.x,
		scale_range.y,
		pow(_rng.randf(), float(layer.get("bias", 1.0)))
	)
	if layer.get("grow", false):
		size *= lerpf(0.5, 1.0, smoothstep(0.4, 3.2, distance - fence))

	var width: float = size * _rng.randf_range(0.9, 1.1)

	# Outside the fence a plant must not reach back over it: the foliage meshes are
	# metres wide, so a bush planted right behind the fence would poke through into
	# the view from the train. Keep each plant as far out as its own reach.
	if spacing <= 0.0 and distance > fence and distance - fence < _plant_reach(key, width):
		return
	var height: float = _height(x, s) + float(layer.get("sink", 0.0))

	var up: Vector3 = Vector3.UP.lerp(
		_normal(x, s),
		float(layer.get("align", 0.0))
	).normalized()
	var basis: Basis = Basis(Quaternion(Vector3.UP, up))
	basis = basis * Basis(Vector3.UP, _rng.randf() * TAU)
	var tilt: float = deg_to_rad(float(layer.get("tilt", 0.0)))
	if tilt > 0.0:
		basis = basis * Basis.from_euler(Vector3(
			_rng.randf_range(-tilt, tilt),
			0.0,
			_rng.randf_range(-tilt, tilt)
		))

	basis = basis.scaled_local(Vector3(width, size, width))

	if not _transforms.has(key):
		_transforms[key] = []

	# Stored in ring coordinates; split into chunks later.
	(_transforms[key] as Array).append({"x": x, "s": s, "y": height, "basis": basis})

	if spacing > 0.0:
		_tree_points.append(Vector2(x, s))
		_tree_centres.append(Vector2(x, s))


# ============================================================
# FENCES
# ============================================================

func _build_fences() -> Array[Transform3D]:
	var pieces: Array[Transform3D] = []
	var fence_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	fence_rng.seed = 9917
	var count: int = int(round(RING_LENGTH / FENCE_PIECE))
	var step: float = RING_LENGTH / float(count)
	for side: int in [-1, 1]:
		for k: int in range(count):
			# Every piece is a little off its slot, like a fence put up by hand and
			# left alone for decades: shifted along and across the line, turned,
			# and now and then leaning badly.
			var s: float = (float(k) + 0.5) * step + fence_rng.randf_range(-0.14, 0.14)
			var across: float = fence_rng.randf_range(-0.22, 0.22)
			var x: float = _fence_x(side, s) + across * float(side)
			x = float(side) * clampf(absf(x), FENCE_MIN_X, FENCE_MAX_X + 0.3)
			var ahead: float = _fence_x(side, s + step * 0.5)
			var behind: float = _fence_x(side, s - step * 0.5)
			var yaw: float = atan2(ahead - behind, step) + deg_to_rad(fence_rng.randf_range(-9.0, 9.0))
			var basis: Basis = Basis(Vector3.UP, yaw)

			var lean: float = 3.0
			if fence_rng.randf() < 0.14:
				lean = fence_rng.randf_range(7.0, 13.0)
			basis = basis * Basis.from_euler(Vector3(
				deg_to_rad(fence_rng.randf_range(-lean * 0.6, lean * 0.6)),
				0.0,
				deg_to_rad(fence_rng.randf_range(-lean, lean))
			))
			var y: float = _height(x, s) + FENCE_LIFT - fence_rng.randf_range(0.0, 0.1)
			pieces.append(Transform3D(basis, Vector3(x, y, s)))

	return pieces



# ============================================================
# GROUND
# ============================================================

func _ground_color(x: float, s: float) -> Color:
	var distance: float = absf(x)
	var side: int = 1 if x >= 0.0 else -1
	var fence: float = absf(_fence_x(side, s))

	var dirt: float = 0.9 * (1.0 - smoothstep(2.9, 4.4, distance))
	dirt *= 0.75 + 0.25 * (_ring("dirt_noise", 0.3, x, s) * 0.5 + 0.5)
	# A worn strip of dirt along the inside of each fence.
	dirt = maxf(dirt, 0.35 * (1.0 - smoothstep(0.0, 1.6, absf(distance - (fence - 1.0)))) * float(distance < fence))

	var moss: float = smoothstep(0.1, 0.5, _ring("moss", 0.05, x, s))
	moss *= smoothstep(fence - 1.0, fence + 1.5, distance) * 0.85
	var humus: float = smoothstep(-0.2, 0.5, _ring("humus", 0.08, x, s)) * 0.55
	humus = maxf(humus, 0.5 * (1.0 - smoothstep(fence, fence + 4.0, distance)) * float(distance > fence - 0.5))
	var mulch: float = 0.0
	for tree: Vector2 in _tree_centres:
		if absf(tree.x - x) > 2.6:
			continue

		var d: float = Vector2(tree.x - x, _ring_distance(tree.y, s)).length()
		if d < 2.6:
			mulch = maxf(mulch, (1.0 - smoothstep(0.4, 2.6, d)) * 0.9)

	var weights: Color = Color(moss, humus, mulch, dirt)
	var total: float = weights.r + weights.g + weights.b + weights.a
	if total > 1.0:
		weights = Color(weights.r / total, weights.g / total, weights.b / total, weights.a / total)

	return weights


func _build_ground_mesh(index: int) -> ArrayMesh:
	var step: float = 0.5
	var columns: int = int(round(HALF_WIDTH * 2.0 / step)) + 1
	var rows: int = int(round(CHUNK_LENGTH / step)) + 1
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for row: int in range(rows):
		for column: int in range(columns):
			var x: float = -HALF_WIDTH + float(column) * step
			var local_z: float = -CHUNK_LENGTH * 0.5 + float(row) * step
			var s: float = float(index) * CHUNK_LENGTH + local_z + CHUNK_LENGTH * 0.5
			vertices.append(Vector3(x, _height(x, s), local_z))
			normals.append(_normal(x, s))
			colors.append(_ground_color(x, _wrap(s)))
			uvs.append(Vector2(x, s))

	for row: int in range(rows - 1):
		for column: int in range(columns - 1):
			var i: int = row * columns + column
			indices.append_array(PackedInt32Array([
				i, i + 1, i + columns,
				i + 1, i + columns + 1, i + columns,
			]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ============================================================
# CHUNK SCENES
# ============================================================

func _build_chunk(
	index: int,
	tracks: Array[Transform3D],
	material: ShaderMaterial,
	fences: Array[Transform3D]
) -> Dictionary:
	var chunk_name: String = CHUNK_NAMES[index]
	var s_min: float = float(index) * CHUNK_LENGTH
	var s_max: float = s_min + CHUNK_LENGTH

	var root: Node3D = Node3D.new()
	root.name = chunk_name

	# Ground
	var ground_mesh: ArrayMesh = _build_ground_mesh(index)
	var ground_path: String = OUT_DIR + "ground_%s.res" % chunk_name.to_lower()
	ground_mesh.surface_set_material(0, material)
	ResourceSaver.save(ground_mesh, ground_path)
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = load(ground_path) as Mesh
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)
	ground.owner = root

	# Tracks
	var tracks_node: Node3D = Node3D.new()
	tracks_node.name = "TrainTracks"
	root.add_child(tracks_node)
	tracks_node.owner = root
	var track_scene: PackedScene = load(
		"res://assets/models/trains/train_tracks/train_tracks.tscn"
	) as PackedScene
	for track_index: int in range(tracks.size()):
		var track: Node3D = track_scene.instantiate() as Node3D
		track.name = "train_tracks" if track_index == 0 else "train_tracks%d" % (track_index + 1)
		tracks_node.add_child(track)
		track.owner = root
		track.transform = tracks[track_index]

	# Fences
	var fence_list: Array[Transform3D] = []
	for piece: Transform3D in fences:
		var s: float = piece.origin.z
		if s >= s_min and s < s_max:
			fence_list.append(Transform3D(
				piece.basis,
				Vector3(piece.origin.x, piece.origin.y, s - s_min - CHUNK_LENGTH * 0.5)
			))

	var fences_node: Node3D = Node3D.new()
	fences_node.name = "Fences"
	root.add_child(fences_node)
	fences_node.owner = root
	_add_multimesh(root, fences_node, "FenceMultiMesh", "fence", fence_list, chunk_name, false)

	# Vegetation
	var vegetation: Node3D = Node3D.new()
	vegetation.name = "Vegetation"
	root.add_child(vegetation)
	vegetation.owner = root

	var total: int = fence_list.size()
	for key: String in _transforms:
		var list: Array[Transform3D] = []
		for entry: Dictionary in _transforms[key]:
			var s: float = float(entry["s"])
			if s >= s_min and s < s_max:
				list.append(Transform3D(
					entry["basis"],
					Vector3(float(entry["x"]), float(entry["y"]), s - s_min - CHUNK_LENGTH * 0.5)
				))

		if list.is_empty():
			continue

		total += list.size()
		_add_multimesh(root, vegetation, key.to_pascal_case(), key, list, chunk_name, SHADOW_MESHES.has(key))

	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	var error: Error = ResourceSaver.save(packed, CHUNK_PATHS[index])
	return {"instances": total, "fences": fence_list.size(), "saved": error_string(error)}


func _add_multimesh(
	root: Node3D,
	parent: Node3D,
	node_name: String,
	mesh_key: String,
	list: Array[Transform3D],
	chunk_name: String,
	casts_shadow: bool
) -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _meshes[mesh_key] as Mesh
	multimesh.instance_count = list.size()
	for i: int in range(list.size()):
		multimesh.set_instance_transform(i, list[i])

	var path: String = OUT_DIR + "%s_%s.res" % [chunk_name.to_lower(), mesh_key]
	ResourceSaver.save(multimesh, path)

	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = load(path) as MultiMesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if casts_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(instance)
	instance.owner = root


## How far a plant's foliage spreads sideways from its stem, in metres: about 40 %
## of the mesh's widest extent times its width scale.
func _plant_reach(key: String, width_scale: float) -> float:
	if not _reaches.has(key):
		var mesh: Mesh = _meshes.get(key) as Mesh
		var extent: float = 0.5
		if mesh != null:
			var box: Vector3 = mesh.get_aabb().size
			extent = maxf(box.x, box.z)

		_reaches[key] = extent * 0.4

	return float(_reaches[key]) * width_scale
