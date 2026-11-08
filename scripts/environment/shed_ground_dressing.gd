extends Node3D
class_name ShedGroundDressing

## The ground of the waiting shed's clearing and the thicket that hides the camcorder, made in code from the project's own plants, rocks and ground textures (nothing is saved into the terrain: the
## terrain's authored data is untouched, this only adds objects in the shed's space). Deterministic (`seed_value`), no collision, and the same plants as the forest (their meshes are the terrain's mesh assets, so
## the wind moves them too).
##
## The clearing: patches of moss, dark humus and pine needles laid over the flat painted ground (soft-edged, so no square shows), drifts of fallen leaves, a few rocks, and low plants (grass, flowers, ferns), more
## and taller toward the edges, none on the slab, the track bed, the walkway across the clearing (only grass there), the token's recess behind the shelter, or in the lens's cone (the viewfinder must see the shelter).
##
## The thicket: a dense ring of plants round the camcorder, so that it stands in the woods and is not seen from the shelter, with a narrow trodden path (bare earth, fallen leaves, no plant on it) that comes from
## the slab's corner and goes round to the cameraman's place behind the eyepiece. The thicket is a child of `cover` (the scene's `CamcorderCover`), which the shed's sequence shows in the present only.

const PLANT_MESHES: Dictionary = {
	"grass_a": {"path": "res://assets/models/foliage/small_foliage_01/small_foliage_01_mesh.tres", "height": Vector2(0.22, 0.42)},
	"grass_b": {"path": "res://assets/models/foliage/small_foliage_02/small_foliage_02_mesh.tres", "height": Vector2(0.22, 0.42)},
	"fern_a": {"path": "res://assets/models/foliage/medium_foliage_01/medium_foliage_01_mesh.tres", "height": Vector2(0.45, 0.85)},
	"fern_b": {"path": "res://assets/models/foliage/medium_foliage_02/medium_foliage_02_mesh.tres", "height": Vector2(0.45, 0.85)},
	"tall_a": {"path": "res://assets/models/foliage/tall_thin_foliage_01/tall_thin_foliage_01_mesh.tres", "height": Vector2(0.9, 1.4)},
	"tall_b": {"path": "res://assets/models/foliage/tall_thin_foliage_02/tall_thin_foliage_02_mesh.tres", "height": Vector2(0.9, 1.4)},
	"big_a": {"path": "res://assets/models/foliage/big_foliage_01/big_foliage_01_mesh.tres", "height": Vector2(1.0, 1.6)},
	"big_b": {"path": "res://assets/models/foliage/big_foliage_02/big_foliage_02_mesh.tres", "height": Vector2(1.0, 1.6)},
	"flower": {"path": "res://assets/models/foliage/white_flower_01/white_flower_01_mesh.tres", "height": Vector2(0.3, 0.55)},
	"kelp": {"path": "res://assets/models/foliage/kelp_like_foliage/kelp_like_foliage_mesh.tres", "height": Vector2(0.55, 0.95)},
	"leaves": {"path": "res://assets/models/foliage/ground_leaves_01/ground_leaves_01_mesh.tres", "height": Vector2(0.1, 0.16)},
}
## Nothing taller than this (metres) stands in the lens's cone, and the cone is this wide (half angle, degrees) round the thicket.
const LOW_PLANT: float = 0.6
const THICKET_CONE_DEGREES: float = 34.0
const ROCK_SCENES: Array[String] = ["res://assets/models/rocks/floor_path/rock_001/rock_001.glb", "res://assets/models/rocks/floor_path/rock_002/rock_002.glb"]
const GROUND_TEXTURES: Dictionary = {
	"moss": "res://assets/textures/moss_ground/moss_ground_Color.jpg",
	"humus": "res://assets/textures/dark_humus/dark_humus_Color.jpg",
	"needles": "res://assets/textures/pine_needle_mulch/pine_needle_mulch_Color.jpg",
	"dirt": "res://assets/textures/dirt/GroundDirtWeedsPatchy004_COL_2K.jpg",
}

@export var seed_value: int = 4411
## The CamcorderCover node that the thicket goes under (shown in the present only).
@export var cover: Node3D
## The camcorder's lens and axis (the shed's space) and where the cameraman stands behind the eyepiece.
@export var lens_position: Vector3 = Vector3(-1.6, 1.3, 1.7)
@export var lens_axis: Vector2 = Vector2(-0.348, -0.937)
@export var camcorder_root: Vector2 = Vector2(-1.495, 1.982)
@export var stand_position: Vector2 = Vector2(-1.27, 2.69)
## The trodden path from the slab's corner to the stand (the shed's space, x and z).
@export var path_points: PackedVector2Array = PackedVector2Array([Vector2(-2.1, -1.6), Vector2(-1.35, -0.55), Vector2(-0.55, 0.55), Vector2(-0.2, 1.55), Vector2(-0.45, 2.45), Vector2(-0.9, 2.78), Vector2(-1.27, 2.69)])
@export var path_half_width: float = 0.3
## How many metres of ground one repeat of a patch's photograph covers.
@export var ground_tile_metres: float = 1.8
## The part of the clearing that is dressed: x and z limits (the shed's space).
@export var area_min: Vector2 = Vector2(-12.5, -12.5)
@export var area_max: Vector2 = Vector2(3.0, 7.5)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _meshes: Dictionary = {}
var _soft_textures: Dictionary = {}
var _patch_shader: Shader = null
## What was made, for the tests and the tools: the plants placed (by kind) and the patches of ground.
var plants_placed: Dictionary = {}
var thicket_count: int = 0
var patches_made: int = 0
var rocks_made: int = 0
## Every plant placed, kept here because a headless run discards a MultiMesh's data: {kind, t (the shed's space), height, thicket}.
var plant_records: Array[Dictionary] = []
var _making_thicket: bool = false
## The terrain's data (`Terrain3DData`), if the level has one: the ground is not flat toward the clearing's west and north edges (it rises there by over half a metre), so everything laid on it follows its height.
var _terrain_data: Object = null
## The level's wind (`VegetationWind`), if it has one: the plants here are drawn with the terrain's own wind meshes and materials so that they sway as the forest does, and it hides the terrain's low plants under the shed's slab.
var _wind: Node = null
## The ground under the slab, in the world (x, z), where the terrain's plants are hidden (empty if nothing was hidden).
var slab_rect: Rect2 = Rect2()
## The shelter's floor slab in this node's space (x, z): nothing of the dressing stands on it (it is wider than the old fixed box: it reaches x -6.3 to 0.3 here).
var slab_local: Rect2 = Rect2()


func _ready() -> void:
	build.call_deferred()


func build() -> void:
	if not _meshes.is_empty():
		return

	_rng.seed = seed_value
	_find_terrain()
	_find_wind()
	_find_slab()
	for key: String in PLANT_MESHES:
		var asset_name: String = String((PLANT_MESHES[key] as Dictionary)["path"]).get_base_dir().get_file()
		var wind_mesh: Mesh = _wind.call("asset_mesh", asset_name) as Mesh if _wind != null else null
		_meshes[key] = wind_mesh if wind_mesh != null else (load(String((PLANT_MESHES[key] as Dictionary)["path"])) as Mesh)
	_ground_patches()
	_clearing_plants()
	_leaf_drifts()
	_rocks()
	_thicket()
	_path_ground()
	_hide_ground_plants_under_slab()


# ============================================================
# THE GROUND'S HEIGHT
# ============================================================

func _find_wind() -> void:
	_wind = null
	if not is_inside_tree():
		return

	var found: Array[Node] = get_tree().root.find_children("*", "VegetationWind", true, false)
	if not found.is_empty():
		_wind = found[0]


## The terrain's low plants under the shelter's floor slab (grass and ferns that would show through the concrete) are hidden: the wind's shader shrinks the plants rooted under the slab (nothing of the terrain is
## changed). The slab's own box, in the world, with half a metre round it (a plant that leans in from the edge is as unwelcome as one in the middle).
func _hide_ground_plants_under_slab() -> void:
	if _wind == null:
		return

	var floor_node: MeshInstance3D = get_node_or_null(^"../Platform/Shelter/Floor") as MeshInstance3D
	if floor_node == null or floor_node.mesh == null:
		return

	var box: AABB = floor_node.global_transform * floor_node.mesh.get_aabb()
	slab_rect = Rect2(box.position.x - 0.5, box.position.z - 0.5, box.size.x + 1.0, box.size.z + 1.0)
	_wind.call("set_hidden_ground", slab_rect, box.end.y + 0.5)


func _find_slab() -> void:
	slab_local = Rect2()
	var floor_node: MeshInstance3D = get_node_or_null(^"../Platform/Shelter/Floor") as MeshInstance3D
	if floor_node == null or floor_node.mesh == null:
		return

	var box: AABB = floor_node.global_transform * floor_node.mesh.get_aabb()
	var low: Vector3 = to_local(box.position)
	var high: Vector3 = to_local(box.end)
	slab_local = Rect2(minf(low.x, high.x), minf(low.z, high.z), absf(high.x - low.x), absf(high.z - low.z))


## True on the shelter's floor slab, or within `margin` metres of it.
func _on_slab(p: Vector2, margin: float = 0.2) -> bool:
	return slab_local.has_area() and slab_local.grow(margin).has_point(p)


func _find_terrain() -> void:
	_terrain_data = null
	if not is_inside_tree():
		return

	for node: Node in get_tree().root.find_children("*", "Terrain3D", true, false):
		var data: Variant = node.get("data")
		if data is Object and (data as Object).has_method("get_height"):
			_terrain_data = data as Object


## The terrain's height at a point (x and z in this node's space), in this node's space: 0 where there is no terrain (the test scenes, a hole in the data).
func _ground_y(p: Vector2) -> float:
	if _terrain_data == null or not is_inside_tree():
		return 0.0

	var world: Vector3 = to_global(Vector3(p.x, 0.0, p.y))
	var height: Variant = _terrain_data.call("get_height", world)
	if typeof(height) != TYPE_FLOAT or is_nan(float(height)) or absf(float(height)) > 1.0e5:
		return 0.0
	return to_local(Vector3(world.x, float(height), world.z)).y


# ============================================================
# WHERE THINGS MAY BE
# ============================================================

## True where nothing may stand up: the slab and its apron, the track bed, the recess behind the shelter, the stand and the path.
func _blocked(p: Vector2) -> bool:
	if _on_slab(p):
		return true
	if p.x > -7.5 and p.x < -1.8 and p.y > -8.9 and p.y < -1.4:
		return true
	if p.x > 2.9:
		return true
	if p.x > -6.8 and p.x < -4.0 and p.y > -10.6 and p.y < -6.8:
		return true
	if p.distance_to(stand_position) < 0.85:
		return true
	return _path_distance(p) < path_half_width + 0.3


func _path_distance(p: Vector2) -> float:
	var best: float = 1.0e9
	for i: int in path_points.size() - 1:
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var ab: Vector2 = b - a
		var u: float = clampf((p - a).dot(ab) / maxf(ab.dot(ab), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * u))
	return best


## True in the cone the lens looks through toward the shelter (where a tall plant would be in the viewfinder's picture).
func _in_lens_cone(p: Vector2, half_angle: float = 27.0) -> bool:
	var to_p: Vector2 = p - Vector2(lens_position.x, lens_position.z)
	var distance: float = to_p.length()
	if distance < 0.4 or distance > 11.0:
		return false
	return rad_to_deg(acos(clampf(to_p.normalized().dot(lens_axis.normalized()), -1.0, 1.0))) < half_angle


## True on the walkway across the clearing toward the track, where only grass grows.
func _on_walkway(p: Vector2) -> bool:
	return p.x > -2.2 and p.x < 3.0 and p.y > -3.4 and p.y < 3.4


func _random_point() -> Vector2:
	return Vector2(_rng.randf_range(area_min.x, area_max.x), _rng.randf_range(area_min.y, area_max.y))


# ============================================================
# PLANTS
# ============================================================

class Batch extends RefCounted:
	var transforms: Array[Transform3D] = []


func _scale_for(kind: String, height: float) -> float:
	var mesh: Mesh = _meshes[kind] as Mesh
	return height / maxf(mesh.get_aabb().size.y, 0.05)


## One plant of a kind at a point: a height in its range (times `bigger`), a random turn and a slight lean.
func _plant(batches: Dictionary, kind: String, at: Vector2, bigger: float = 1.0) -> void:
	var range_h: Vector2 = (PLANT_MESHES[kind] as Dictionary)["height"] as Vector2
	var height: float = _rng.randf_range(range_h.x, range_h.y) * bigger
	var s: float = _scale_for(kind, height)
	if kind == "leaves":
		# A flat mesh has no height to size it by: the scale the shelter's own leaf sheets had.
		s = _rng.randf_range(0.12, 0.19)
	var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(_rng.randf_range(-6.0, 6.0))) * Basis.from_scale(Vector3(s, s * _rng.randf_range(0.9, 1.1), s))
	if not batches.has(kind):
		batches[kind] = Batch.new()
	var rooted: Transform3D = Transform3D(basis, Vector3(at.x, _ground_y(at), at.y))
	(batches[kind] as Batch).transforms.append(rooted)
	plants_placed[kind] = int(plants_placed.get(kind, 0)) + 1
	plant_records.append({"kind": kind, "t": rooted, "height": height, "thicket": _making_thicket})


func _flush(batches: Dictionary, parent: Node3D) -> void:
	for kind: String in batches:
		var batch: Batch = batches[kind] as Batch
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _meshes[kind] as Mesh
		multi.instance_count = batch.transforms.size()
		for i: int in batch.transforms.size():
			multi.set_instance_transform(i, batch.transforms[i])
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "Plants_" + kind
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The grass tufts are tinted by an override the terrain gives its instances: the same here, with the wind in it.
		if _wind != null:
			var tint: Material = _wind.call("asset_override_material", String((PLANT_MESHES[kind] as Dictionary)["path"]).get_base_dir().get_file()) as Material
			if tint != null:
				instance.material_override = tint
		parent.add_child(instance)


func _clearing_plants() -> void:
	var batches: Dictionary = {}
	var parent: Node3D = Node3D.new()
	parent.name = "Plants"
	add_child(parent)
	var tries: int = 0
	var made: int = 0
	# Low cover everywhere that is not blocked: grass, with ferns and flowers in clumps, more of it toward the edges.
	while made < 330 and tries < 6000:
		tries += 1
		var p: Vector2 = _random_point()
		if _blocked(p):
			continue

		var edge: float = clampf((p.distance_to(Vector2(-5.0, -3.5)) - 5.0) / 6.0, 0.0, 1.0)
		var roll: float = _rng.randf()
		if _on_walkway(p):
			if roll < 0.35:
				_plant(batches, "grass_a" if _rng.randf() < 0.5 else "grass_b", p, 0.8)
				made += 1
			continue
		if roll < 0.52:
			_plant(batches, "grass_a" if _rng.randf() < 0.5 else "grass_b", p)
		elif roll < 0.74:
			# A fern clump: a few round one point.
			for k: int in _rng.randi_range(1, 3):
				var q: Vector2 = p + Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35))
				if not _blocked(q) and (not _in_lens_cone(q)):
					_plant(batches, "fern_a" if _rng.randf() < 0.5 else "fern_b", q)
		elif roll < 0.82:
			if not _in_lens_cone(p):
				_plant(batches, "flower", p)
		elif roll < 0.9:
			if not _in_lens_cone(p):
				_plant(batches, "kelp", p)
		elif edge > 0.25 and not _in_lens_cone(p):
			_plant(batches, ["tall_a", "tall_b", "tall_a", "tall_b", "big_a"][_rng.randi() % 5], p, 0.9 + edge * 0.25)
		made += 1
	_flush(batches, parent)


## Fallen leaves in drifts: several leaf sheets together, in corners, against the slab, along the walkway's sides.
func _leaf_drifts() -> void:
	var batches: Dictionary = {}
	var parent: Node3D = Node3D.new()
	parent.name = "Leaves"
	add_child(parent)
	for drift: int in 14:
		var center: Vector2 = _random_point()
		if center.x > 2.0 or _path_distance(center) < 0.5:
			continue
		for k: int in _rng.randi_range(3, 8):
			var p: Vector2 = center + Vector2(_rng.randf_range(-0.9, 0.9), _rng.randf_range(-0.9, 0.9))
			if _on_slab(p, 0.1) or (p.x > -7.4 and p.x < -1.9 and p.y > -8.8 and p.y < -1.5):
				continue
			_plant(batches, "leaves", p, 1.0)
	_flush(batches, parent)
	for child: Node in parent.get_children():
		(child as Node3D).position.y = 0.012


## Stones: a few rocks at the clearing's edges and by the slab, sunk a little into the ground.
func _rocks() -> void:
	var parent: Node3D = Node3D.new()
	parent.name = "Rocks"
	add_child(parent)
	for i: int in 11:
		var p: Vector2 = _random_point()
		if _blocked(p) or _on_walkway(p) or _in_lens_cone(p):
			continue

		var scene: PackedScene = load(ROCK_SCENES[_rng.randi() % ROCK_SCENES.size()]) as PackedScene
		if scene == null:
			continue
		var rock: Node3D = scene.instantiate() as Node3D
		var s: float = _rng.randf_range(0.18, 0.5)
		rock.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * _rng.randf_range(0.6, 1.0), s)), Vector3(p.x, _ground_y(p) - 0.04, p.y))
		parent.add_child(rock)
		rocks_made += 1


# ============================================================
# THE GROUND
# ============================================================

## The patches are drawn with the ground photograph at its own scale, repeated (`ground_tile_metres` to a repeat: it is as sharp as the terrain's own ground, which a picture stretched over the whole patch was not),
## darkened toward the night and seen through a soft, uneven mask, so that no square outline shows.
const PATCH_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_back;
uniform sampler2D detail : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform float tiles = 3.0;
uniform vec2 offset = vec2(0.0);
uniform float darken = 0.5;
uniform float strength = 0.9;
void fragment() {
	ALBEDO = texture(detail, UV * tiles + offset).rgb * darken;
	ALPHA = texture(mask, UV).a * strength;
	ROUGHNESS = 1.0;
}
"""

## The soft, uneven edge as an alpha mask (white, 256 px): clear at its square border, whatever the noise did.
func _soft_texture(kind: String) -> ImageTexture:
	if _soft_textures.has(kind):
		return _soft_textures[kind] as ImageTexture

	var size: int = 256
	var half: float = float(size) * 0.5
	var image: Image = Image.create(size, size, true, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value + kind.hash() % 1000
	noise.frequency = 0.027
	for y: int in size:
		for x: int in size:
			var d: float = Vector2(x - half, y - half).length() / half
			var edge: float = d + noise.get_noise_2d(float(x), float(y)) * 0.3
			var alpha: float = 1.0 - smoothstep(0.45, 0.92, edge)
			alpha *= 1.0 - smoothstep(0.74, 0.96, maxf(absf(x - half), absf(y - half)) / half)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	image.clear_mipmaps()
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_soft_textures[kind] = texture
	return texture


## A patch of ground texture: a grid of triangles whose every point lies `lift` over the terrain under it (a flat plane would be cut by the ground wherever it rises, and show as a straight line), drawn after
## the patches before it (`render_priority` is its number: patches that overlap are blended in the same order from every side, never re-sorted by the camera's distance, which made them change as the player moved).
func _ground_patch(kind: String, center: Vector2, size: float, lift: float, turn: float) -> void:
	var cells: int = clampi(int(ceil(size / 0.4)), 4, 16)
	var rotation: Basis = Basis(Vector3.UP, turn)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for iz: int in cells + 1:
		for ix: int in cells + 1:
			var local: Vector3 = Vector3((float(ix) / float(cells) - 0.5) * size, 0.0, (float(iz) / float(cells) - 0.5) * size)
			var flat: Vector3 = rotation * local
			var at: Vector2 = center + Vector2(flat.x, flat.z)
			points.append(Vector3(at.x, _ground_y(at) + lift, at.y))
	for iz: int in cells:
		for ix: int in cells:
			var corners: Array[int] = [iz * (cells + 1) + ix, iz * (cells + 1) + ix + 1, (iz + 1) * (cells + 1) + ix, (iz + 1) * (cells + 1) + ix + 1]
			# (Clockwise seen from above: the front face in Godot.)
			for index: int in [0, 1, 2, 1, 3, 2]:
				var corner: int = corners[index]
				var column: int = corner % (cells + 1)
				var row: int = corner / (cells + 1)
				tool.set_uv(Vector2(float(column) / float(cells), float(row) / float(cells)))
				tool.add_vertex(points[corner])
	tool.generate_normals()
	var quad: MeshInstance3D = MeshInstance3D.new()
	quad.mesh = tool.commit()
	if _patch_shader == null:
		_patch_shader = Shader.new()
		_patch_shader.code = PATCH_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _patch_shader
	material.set_shader_parameter(&"detail", load(String(GROUND_TEXTURES[kind])) as Texture2D)
	material.set_shader_parameter(&"mask", _soft_texture(kind))
	material.set_shader_parameter(&"tiles", size / ground_tile_metres)
	material.set_shader_parameter(&"offset", Vector2(_rng.randf(), _rng.randf()))
	material.render_priority = clampi(patches_made - 100, -100, 100)
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	patches_made += 1


func _ground_patches() -> void:
	var kinds: Array[String] = ["moss", "humus", "needles", "moss", "humus", "needles"]
	var lift: float = 0.014
	for i: int in 22:
		var p: Vector2 = _random_point()
		if p.x > 2.4 or (p.x > -8.2 and p.x < -1.0 and p.y > -9.6 and p.y < -0.8):
			continue
		var kind: String = kinds[i % kinds.size()]
		_ground_patch(kind, p, _rng.randf_range(3.2, 6.0), lift, _rng.randf() * TAU)
		lift += 0.0007


## The trodden path: bare earth along it in overlapping patches of dirt, a bright worn strip in the middle.
func _path_ground() -> void:
	var lift: float = 0.02
	for i: int in path_points.size() - 1:
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var length: float = a.distance_to(b)
		var steps: int = maxi(int(length / 0.45), 1)
		for k: int in steps + 1:
			var p: Vector2 = a.lerp(b, float(k) / float(steps)) + Vector2(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.05, 0.05))
			_ground_patch("dirt", p, _rng.randf_range(1.2, 1.5), lift, _rng.randf() * TAU)
			lift += 0.0004
	# The stand: a little worn ground where the cameraman's feet are.
	_ground_patch("dirt", stand_position, 1.9, lift + 0.001, 0.5)


# ============================================================
# THE THICKET ROUND THE CAMCORDER
# ============================================================

## The thicket: plants of the same sort as the forest behind it (ferns, grass, thin tall plants, kelp-like leaves, a few flowers), thick round the camcorder and thinning out into the clearing (so it
## does not stand as a wall of its own). Its sides and back are close and the lens's cone is open: nothing taller than `LOW_PLANT` is in the way of the lens, so that it looks out between the plants.
func _thicket() -> void:
	_making_thicket = true
	var parent: Node3D = cover if cover != null else self
	var holder: Node3D = Node3D.new()
	holder.name = "Thicket"
	parent.add_child(holder)
	var batches: Dictionary = {}
	var centre: Vector2 = camcorder_root
	var tries: int = 0
	var made: int = 0
	while made < 190 and tries < 9000:
		tries += 1
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(0.5, 3.4)
		# Thick close to the camcorder, thinning out with the distance.
		if _rng.randf() > pow(1.0 - (radius - 0.5) / 3.1, 0.8):
			continue
		var p: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius
		if p.distance_to(stand_position) < 0.8 or _path_distance(p) < path_half_width + 0.12:
			continue
		if _on_slab(p, 0.1) or (p.x > -7.4 and p.x < -1.8 and p.y > -8.9 and p.y < -1.4):
			continue
		var kind: String
		var roll: float = _rng.randf()
		if _in_lens_cone(p, THICKET_CONE_DEGREES):
			# In the way of the lens only what a lens looks over.
			kind = ["grass_a", "grass_b", "flower", "grass_a"][_rng.randi() % 4]
		elif roll < 0.30:
			kind = "fern_a" if _rng.randf() < 0.5 else "fern_b"
		elif roll < 0.50:
			kind = "grass_a" if _rng.randf() < 0.5 else "grass_b"
		elif roll < 0.78:
			kind = "tall_a" if _rng.randf() < 0.5 else "tall_b"
		elif roll < 0.88:
			kind = "kelp"
		elif roll < 0.95:
			kind = "flower"
		else:
			kind = "big_a" if _rng.randf() < 0.5 else "big_b"
		# The plants round it are no taller than the forest's own plants about it.
		_plant(batches, kind, p, 1.15 if kind.begins_with("tall") else 0.85)
		made += 1
	thicket_count = made
	_making_thicket = false
	_flush(batches, holder)
