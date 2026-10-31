@tool
extends RefCounted
class_name TownVistaBuilder

## Puts the whole blockout town in the dream intro's valley, where the player sees it from the
## city overlook (it replaces the old `CityBlockout` lights):
##
## 1. `bake_terrain` sculpts the dream intro's Terrain3D: a CLIFF right beyond the overlook's
##    fence, the valley floor below it with soft swells, the town's own ground (the playable
##    core's carved streets, the shaped valley with the river) at the town's place, mountains
##    round it, painted with the terrain's textures (grass, forest floor, moss, dirt for roads
##    and pitches, rock on the steep parts) and tinted with its colour map. Beyond the cliff it
##    only RAISES the old ground; the plateau, the plaza and the forest the player walks in stay
##    as authored.
## 2. `plant_forest` paints the forest of the valley and the mountains as Terrain3D mesh
##    instances (the instancer, the project's tree models as vista mesh assets), standing on
##    the baked heights. They are stored in the regions: the editor's instance tools see them.
## 3. `bake_scene` builds the town in vista mode (`TownBlockout.vista_mode`: visual only, lit
##    windows and lamps as emissive meshes) and saves it as `scenes/environment/town_vista.scn`,
##    to be instanced in the dream intro at `town_transform()`.
##
## Run `scripts/tools/build_town_vista.tscn`: `-- terrain` (headless is fine, bakes 1 and 2),
## then `-- scene` (needs a renderer). Both steps are deterministic for the same seed.

const SCENE_PATH: String = "res://scenes/environment/town_vista.scn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"

## Where the town's origin (the playable core's centre) stands in the dream intro. It is turned
## so that the overlook lies straight along its +Z (south): the river is in front and the old
## upper town behind the centre, as seen from the overlook.
const CENTER: Vector2 = Vector2(379.31, -348.0)
## The town's local height 0 is this high in the world. The valley floor is raised to -64 (the
## old terrain had it at -200): from the plaza the town then lies about 5 degrees below the
## eye, clear of the plateau lip.
const BASE_Y: float = -56.0
const FLOOR_WORLD: float = -64.0
const OVERLOOK: Vector2 = Vector2(168.0, 27.0)
## The world area that Terrain3D can hold here (regions -1..15 in X, -16..2 in Z).
const LIMITS: Rect2 = Rect2(-62.0, -1020.0, 1082.0, 1200.0)
## Beyond the cliff's reach, nothing within this radius of the overlook is touched.
const KEEP_RADIUS: float = 80.0

## The cliff: the fence is an arc of FENCE_RADIUS round a point behind the viewpoint (see
## OverlookBuilder); beyond it the ground falls to the valley floor over CLIFF_FACE metres, all
## along the arc (CLIFF_ARC_FULL degrees either side of the view direction) and fading out by
## CLIFF_ARC_NONE degrees, where the authored hill goes on.
const VIEW_DIRECTION: Vector2 = Vector2(0.686, -0.727)
const FENCE_DISTANCE: float = 8.2
const FENCE_RADIUS: float = 22.0
const CLIFF_LIP: float = 1.2
const CLIFF_FACE: float = 24.0
const CLIFF_ARC_FULL: float = 38.0
const CLIFF_ARC_NONE: float = 64.0

const TEX_GRASS: int = 0
const TEX_DIRT: int = 1
const TEX_LEAVES: int = 2
const TEX_MOSS: int = 3
const TEX_HUMUS: int = 4
const TEX_NEEDLES: int = 5
const TEX_ROCK: int = 6

## The vista tree mesh assets in the dream intro's Terrain3D (`mesh_list`), by species
## (TownScenery.TREE_*): medium generic, broadleaf (tree_test), pitangueira, araucária.
const MESH_IDS: Array[int] = [21, 22, 23, 24]
## The vista stand mesh assets (VistaForestAssets), by species: one 64 m patch of trees each.
const STAND_IDS: Array[int] = [25, 26, 27, 28]
## Within this distance of the overlook the forest is single trees (the rest are stands).
const NEAR_RADIUS: float = 205.0

## The call's camera in the dream intro (the overlook's shot, looking along `FRINGE_LOOK`), for `plant_fringe`: the front rows are the buildings
## within `FRINGE_REACH` m and `FRINGE_ARC` degrees of the view with no building nearer along the same line of sight; their trees stand `FRINGE_NEAR` to `FRINGE_FAR` m in front,
## `FRINGE_SIDE` m either way, `FRINGE_FROM_HOUSE` m from any house and `FRINGE_APART` m from each other. A tree is about
## `FRINGE_TREE_HEIGHT` m tall with a crown of `FRINGE_CROWN` m (at scale 1).
const FRINGE_CAMERA: Vector3 = Vector3(173.5, -15.9, 27.1)
const FRINGE_LOOK: Vector2 = Vector2(0.63, -0.77)
const FRINGE_REACH: float = 520.0
const FRINGE_ARC: float = 42.0
const FRINGE_PER_HOUSE: int = 22
const FRINGE_NEAR: float = 4.5
const FRINGE_FAR: float = 44.0
const FRINGE_SIDE: float = 16.0
const FRINGE_FROM_HOUSE: float = 8.0
const FRINGE_APART: float = 3.0
const FRINGE_TREE_HEIGHT: float = 9.0
## `plant_cover`: the strip starts `COVER_FROM` m from the call's camera (past the near ring of single trees), ends `COVER_GAP` m before the nearest
## house and is `COVER_SIDE` m wide either way.
const COVER_FROM: float = 215.0
const COVER_GAP: float = 30.0
const COVER_SIDE: float = 190.0
const COVER_MAX_BARE: int = 9
const FRINGE_CROWN: float = 3.0


## What the vertex pass did to a vertex.
const EDIT_NONE: int = 0
const EDIT_RAISED: int = 1
const EDIT_NEW: int = 2
const EDIT_LOWERED: int = 3

var stats: Dictionary = {}
## `plant_cover` places stands with `_stand_transform` on its own terms (see there): the town's houses, flat, and whether it is on.
var _cover_mode: bool = false
var _cover_houses: Array[Vector2] = []

var _noise: FastNoiseLite = FastNoiseLite.new()
var _cliff_noise: FastNoiseLite = FastNoiseLite.new()
var _stand_noise: FastNoiseLite = FastNoiseLite.new()
var _grove_noise: FastNoiseLite = FastNoiseLite.new()
var _view_direction: Vector2 = VIEW_DIRECTION.normalized()


## The town's place: its +Z (south) points at the overlook.
func town_transform() -> Transform3D:
	var yaw: float = atan2(OVERLOOK.x - CENTER.x, OVERLOOK.y - CENTER.y)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(CENTER.x, BASE_Y, CENTER.y))


## A town in vista mode, placed at `town_transform()` (it builds when it enters the tree).
func make_town() -> TownBlockout:
	var town: TownBlockout = TownBlockout.new()
	town.vista_mode = true
	town.build_environment = false
	town.build_street_lamps = false
	town.vista_overlook_world = OVERLOOK
	town.vista_limits_world = LIMITS
	town.transform = town_transform()
	return town


## Gives the baking Terrain3D the dream intro's mesh assets (textures and the vista trees),
## which live in the scene, so the instancer knows the ids it paints.
func load_assets(terrain: Terrain3D) -> void:
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	var source: Terrain3D = scene.get_node("Terrain3D") as Terrain3D
	terrain.assets = source.assets
	scene.free()


# ============================================================
# THE TERRAIN
# ============================================================

## The weight (0..1) of the cliff at a world point: 0 on the plateau and up to the fence, 1 on
## the valley side beyond its face. A little noise makes the face and the lip irregular.
func cliff_weight(x: float, z: float) -> float:
	var centre: Vector2 = OVERLOOK + _view_direction * (FENCE_DISTANCE - FENCE_RADIUS)
	var offset: Vector2 = Vector2(x, z) - centre
	var radius: float = offset.length()
	if radius < 1.0:
		return 0.0

	var angle: float = rad_to_deg(acos(clampf(offset.dot(_view_direction) / radius, -1.0, 1.0)))
	var across: float = 1.0 - smoothstep(CLIFF_ARC_FULL, CLIFF_ARC_NONE, angle)
	var beyond: float = radius - FENCE_RADIUS + _cliff_noise.get_noise_2d(x, z) * 3.0
	return smoothstep(CLIFF_LIP, CLIFF_FACE, beyond) * across


func bake_terrain(terrain: Terrain3D, town: TownBlockout) -> void:
	var data: Terrain3DData = terrain.data
	var scenery: TownScenery = town._scenery
	var to_local: Transform3D = town.global_transform.affine_inverse()
	_noise.seed = 31
	_noise.frequency = 0.012
	_noise.fractal_octaves = 3
	_cliff_noise.seed = 91
	_cliff_noise.frequency = 0.11
	_cliff_noise.fractal_octaves = 3

	# The final heights of the whole area the vista covers, one vertex at a time. Beyond the
	# cliff the old ground is only RAISED, and never within KEEP_RADIUS of the overlook.
	var region_size: int = int(float(terrain.region_size) * terrain.vertex_spacing)
	var origin: Vector2i = Vector2i(floori(LIMITS.position.x / float(region_size)) * region_size, floori(LIMITS.position.y / float(region_size)) * region_size)
	var width: int = (floori((LIMITS.end.x - 0.01) / float(region_size)) + 1) * region_size - origin.x
	var depth: int = (floori((LIMITS.end.y - 0.01) / float(region_size)) + 1) * region_size - origin.y
	var heights: PackedFloat32Array = PackedFloat32Array()
	var edits: PackedByteArray = PackedByteArray()
	var cliffs: PackedFloat32Array = PackedFloat32Array()
	heights.resize(width * depth)
	edits.resize(width * depth)
	cliffs.resize(width * depth)

	var started: int = Time.get_ticks_msec()
	var raised: int = 0
	var lowered: int = 0
	var created: int = 0
	for j: int in depth:
		var z: int = origin.y + j
		for i: int in width:
			var x: int = origin.x + i
			var point: Vector3 = Vector3(float(x), 0.0, float(z))
			var old: float = data.get_height(point)
			var k: int = j * width + i
			var wanted: float = FLOOR_WORLD
			if LIMITS.has_point(Vector2(float(x), float(z))):
				var local: Vector3 = to_local * point
				wanted = BASE_Y + scenery.vista_height(local.x, local.z, FLOOR_WORLD - BASE_Y)

			if is_nan(old):
				# No region here yet: it is born with the vista's ground.
				heights[k] = wanted
				edits[k] = EDIT_NEW
				created += 1
				continue

			var cliff: float = 0.0
			if Vector2(float(x) - OVERLOOK.x, float(z) - OVERLOOK.y).length() < 160.0:
				cliff = cliff_weight(float(x), float(z))

			if cliff > 0.001 and wanted < old - 0.05:
				heights[k] = lerpf(old, wanted, cliff)
				cliffs[k] = cliff
				edits[k] = EDIT_LOWERED
				lowered += 1
			elif wanted > old + 0.05 and Vector2(float(x) - OVERLOOK.x, float(z) - OVERLOOK.y).length() > KEEP_RADIUS:
				heights[k] = wanted
				edits[k] = EDIT_RAISED
				raised += 1
			else:
				heights[k] = old

	print("  heights computed in ", Time.get_ticks_msec() - started, " ms: ", raised, " raised, ", lowered, " lowered by the cliff, ", created, " in new regions")
	started = Time.get_ticks_msec()

	var modified: Array[Vector2i] = []
	var born: Array[Vector2i] = []
	for rz: int in range(origin.y / region_size, (origin.y + depth) / region_size):
		for rx: int in range(origin.x / region_size, (origin.x + width) / region_size):
			var location: Vector2i = Vector2i(rx, rz)
			var cell: Vector2i = Vector2i(rx * region_size - origin.x, rz * region_size - origin.y)
			var existing: Terrain3DRegion = data.get_region(location)
			var touched: bool = false
			for j: int in region_size:
				for i: int in region_size:
					if edits[(cell.y + j) * width + cell.x + i] != EDIT_NONE:
						touched = true
						break
				if touched:
					break
			if not touched:
				continue

			var height_image: Image
			var control_image: Image
			var color_image: Image
			if existing != null:
				height_image = existing.get_height_map()
				control_image = existing.get_control_map()
				color_image = existing.get_color_map()
			else:
				height_image = Image.create(region_size, region_size, false, Image.FORMAT_RF)
				control_image = Image.create(region_size, region_size, false, Image.FORMAT_RF)
				color_image = null

			if color_image == null or color_image.get_width() != region_size or color_image.get_format() != Image.FORMAT_RGBA8:
				color_image = Image.create(region_size, region_size, false, Image.FORMAT_RGBA8)
				color_image.fill(Color(1.0, 1.0, 1.0, 0.5))

			for j: int in region_size:
				for i: int in region_size:
					var gi: int = cell.x + i
					var gj: int = cell.y + j
					var k: int = gj * width + gi
					var edit: int = edits[k]
					if edit == EDIT_NONE:
						continue

					height_image.set_pixel(i, j, Color(heights[k], 0.0, 0.0, 1.0))
					var slope: float = 0.0
					if gi > 0 and gj > 0 and gi < width - 1 and gj < depth - 1:
						var dx: float = heights[k + 1] - heights[k - 1]
						var dz: float = heights[k + width] - heights[k - width]
						slope = rad_to_deg(atan(sqrt(dx * dx + dz * dz) * 0.5))

					var local: Vector3 = to_local * Vector3(float(origin.x + gi), 0.0, float(origin.y + gj))
					var choice: Vector3 = _texture_for(scenery, local, heights[k] - FLOOR_WORLD, slope)
					var uint: int = Terrain3DUtil.enc_base(int(choice.x)) | Terrain3DUtil.enc_overlay(int(choice.y)) | Terrain3DUtil.enc_blend(int(clampf(choice.z, 0.0, 1.0) * 255.0))
					var tint: Color = _tint(local, heights[k] - FLOOR_WORLD, slope, color_image.get_pixel(i, j).a, choice)
					if edit == EDIT_LOWERED:
						# The cliff fades in over what was authored there (its dirt and grass at the lip),
						# texture and tint both: no hard edge.
						var fresh: float = smoothstep(0.02, 0.5, cliffs[k])
						var old_base: int = Terrain3DUtil.get_base(Terrain3DUtil.as_uint(control_image.get_pixel(i, j).r))
						uint = Terrain3DUtil.enc_base(int(choice.x)) | Terrain3DUtil.enc_overlay(old_base) | Terrain3DUtil.enc_blend(int((1.0 - fresh) * 255.0))
						tint = color_image.get_pixel(i, j).lerp(tint, fresh)

					control_image.set_pixel(i, j, Color(Terrain3DUtil.as_float(uint), 0.0, 0.0, 1.0))
					color_image.set_pixel(i, j, tint)

			if existing != null:
				existing.set_color_map(color_image)
				existing.set_modified(true)
				modified.append(location)
			else:
				var region: Terrain3DRegion = Terrain3DRegion.new()
				region.set_region_size(terrain.region_size)
				region.set_vertex_spacing(terrain.vertex_spacing)
				region.set_location(location)
				region.set_height_map(height_image)
				region.set_control_map(control_image)
				region.set_color_map(color_image)
				region.sanitize_maps()
				data.add_region(region, false)
				born.append(location)

	print("  regions edited: ", modified.size(), ", born: ", born.size(), " in ", Time.get_ticks_msec() - started, " ms")
	started = Time.get_ticks_msec()
	data.update_maps()
	data.calc_height_range(true)

	# The vegetation the old ground carried is where the ground no longer is (a cliff took the
	# slope from under it, raised ground buried it): it goes.
	var pruned: int = 0
	for location: Vector2i in modified:
		pruned += _prune_unseated(data, data.get_region(location), region_size, edits, origin, width)

	print("  vegetation that lost its ground removed: ", pruned, " (", Time.get_ticks_msec() - started, " ms)")
	stats["raised"] = raised
	stats["lowered"] = lowered
	stats["edited"] = modified.size()
	stats["born"] = born.size()
	stats["pruned"] = pruned

	started = Time.get_ticks_msec()
	var owned: Callable = func(world: Vector2) -> bool:
		var column: int = roundi(world.x) - origin.x
		var row: int = roundi(world.y) - origin.y
		if column < 0 or row < 0 or column >= width or row >= depth:
			return false

		return edits[row * width + column] != EDIT_NONE

	plant_forest(terrain, town, owned)
	print("  forest planted in ", Time.get_ticks_msec() - started, " ms: ", stats.get("trees", 0), " trees")

	# Only the regions this bake changed are written (the instancer flags every region it touches,
	# even to read it; the untouched files stay byte-identical to git).
	started = Time.get_ticks_msec()
	var to_save: Dictionary = {}
	for location: Vector2i in modified:
		to_save[location] = true
	for location: Vector2i in born:
		to_save[location] = true
	for region: Terrain3DRegion in data.get_regions_active():
		if _has_vista_instances(region):
			to_save[region.get_location()] = true

	for location: Vector2i in to_save:
		data.save_region(location, TERRAIN_DIRECTORY, false)

	stats["saved"] = to_save.size()
	print("  saved ", to_save.size(), " regions in ", Time.get_ticks_msec() - started, " ms (only the ones that changed)")


## Removes the instances of the old forest (X and Z of an instance are local to its region, Y is
## the world height) whose height no longer matches the ground, where the vertex pass changed it.
func _prune_unseated(data: Terrain3DData, region: Terrain3DRegion, region_size: int, edits: PackedByteArray, origin: Vector2i, width: int) -> int:
	var removed: int = 0
	var offset: Vector3 = Vector3(float(region.get_location().x * region_size), 0.0, float(region.get_location().y * region_size))
	var instances: Dictionary = region.get_instances()
	for mesh_id: Variant in instances.keys():
		var cells: Dictionary = instances[mesh_id]
		for cell: Variant in cells.keys():
			var entry: Array = cells[cell]
			var transforms: Array = entry[0]
			var colors: Variant = entry[1]
			var kept_transforms: Array = transforms.duplicate()
			kept_transforms.clear()
			var kept_colors: Variant = colors.duplicate()
			kept_colors.clear()
			for n: int in transforms.size():
				var spot: Vector3 = (transforms[n] as Transform3D).origin + offset
				var k: int = (roundi(spot.z) - origin.y) * width + (roundi(spot.x) - origin.x)
				var changed: bool = k >= 0 and k < edits.size() and edits[k] != EDIT_NONE
				if changed and absf(spot.y - data.get_height(spot)) > 0.6:
					removed += 1
					continue

				kept_transforms.append(transforms[n])
				kept_colors.append(colors[n])

			if kept_transforms.is_empty():
				cells.erase(cell)
			else:
				cells[cell] = [kept_transforms, kept_colors, entry[2]]

	if removed > 0:
		region.set_instances(instances)
		region.set_modified(true)

	return removed


## (base texture, overlay texture, blend) for a vertex: what the town painted there, else the
## natural ground: grass round the town, forest floor and moss under the forest, rock on the
## steep parts and the high ground.
func _texture_for(scenery: TownScenery, local: Vector3, above_floor: float, slope: float) -> Vector3:
	var noise: float = _noise.get_noise_2d(local.x, local.z) * 0.5 + 0.5
	if slope > 44.0:
		return Vector3(TEX_ROCK, TEX_LEAVES, 0.1 + noise * 0.2)

	match scenery.kind_at(local.x, local.z):
		TownScenery.KIND_DIRT:
			return Vector3(TEX_DIRT, TEX_GRASS, 0.05 + noise * 0.25)
		TownScenery.KIND_STONE:
			return Vector3(TEX_DIRT, TEX_ROCK, 0.3 + noise * 0.3)
		TownScenery.KIND_MUD:
			return Vector3(TEX_DIRT, TEX_MOSS, 0.2 + noise * 0.4)
		TownScenery.KIND_PASTURE:
			return Vector3(TEX_GRASS, TEX_MOSS, 0.1 + noise * 0.3)
		TownScenery.KIND_BANANA:
			return Vector3(TEX_GRASS, TEX_HUMUS, 0.2 + noise * 0.3)
		TownScenery.KIND_COFFEE:
			return Vector3(TEX_HUMUS, TEX_GRASS, 0.2 + noise * 0.3)
		TownScenery.KIND_EUCALYPTUS:
			return Vector3(TEX_NEEDLES, TEX_LEAVES, 0.3 + noise * 0.4)
		TownScenery.KIND_CEMETERY:
			return Vector3(TEX_GRASS, TEX_MOSS, 0.15 + noise * 0.2)

	if slope > 33.0:
		# Steep but not a cliff: bare earth and rock showing through the moss.
		return Vector3(TEX_MOSS, TEX_ROCK, clampf(0.25 + (slope - 33.0) * 0.05, 0.0, 0.7))

	if above_floor > 230.0:
		return Vector3(TEX_LEAVES, TEX_ROCK, clampf(0.12 + (above_floor - 230.0) * 0.003, 0.0, 0.6))

	# The valley floor and the lower slopes are grass in patches: damp moss hollows, bare earth
	# where the cattle go, the forest floor creeping in; the forest floor takes over higher up.
	var forest: float = maxf(smoothstep(6.0, 40.0, above_floor + noise * 30.0 - 4.0), smoothstep(9.0, 22.0, slope))
	if forest < 0.45:
		var patch: float = _noise.get_noise_2d(local.x * 2.7 + 200.0, local.z * 2.7) * 0.5 + 0.5
		if patch > 0.76:
			return Vector3(TEX_GRASS, TEX_DIRT, clampf(0.25 + (patch - 0.76) * 3.0, 0.0, 0.8))
		if patch < 0.38:
			return Vector3(TEX_GRASS, TEX_MOSS, clampf(0.2 + (0.38 - patch) * 1.6, 0.0, 0.8))
		return Vector3(TEX_GRASS, TEX_LEAVES, 0.15 + forest * 1.2)

	# Under the forest: moss (green from afar) with the forest floor and humus showing through.
	return Vector3(TEX_MOSS, TEX_LEAVES if noise > 0.5 else TEX_HUMUS, 0.12 + noise * 0.35)


## The colour map tint of a vertex (the terrain's albedo is multiplied by it): patches of
## lighter and darker green over the valley, a dark canopy colour on the forested slopes, paler
## rock. `roughness` (the map's alpha) is kept.
func _tint(local: Vector3, above_floor: float, slope: float, roughness: float, choice: Vector3) -> Color:
	var patch: float = _noise.get_noise_2d(local.x * 2.3 + 71.0, local.z * 2.3 - 13.0) * 0.5 + 0.5
	var forest: float = maxf(smoothstep(6.0, 40.0, above_floor + (_noise.get_noise_2d(local.x, local.z) * 0.5 + 0.5) * 30.0 - 4.0), smoothstep(9.0, 22.0, slope))
	var dry: float = smoothstep(0.62, 0.9, _noise.get_noise_2d(local.x * 1.3 - 90.0, local.z * 1.3 + 40.0) * 0.5 + 0.5)
	var meadow: Color = Color(0.52, 0.7, 0.44).lerp(Color(0.8, 0.84, 0.62), patch).lerp(Color(0.78, 0.72, 0.54), dry * 0.45)
	var canopy: Color = Color(0.17, 0.27, 0.15).lerp(Color(0.23, 0.33, 0.18), patch)
	var tint: Color = meadow.lerp(canopy, forest)
	if slope > 40.0:
		tint = tint.lerp(Color(0.34, 0.36, 0.33), clampf((slope - 36.0) * 0.08, 0.0, 0.75))
	# The moss texture is a bright lime on its own: calmed down where it is the base.
	if int(choice.x) == TEX_MOSS:
		tint *= Color(0.66, 0.72, 0.58)

	return Color(tint.r, tint.g, tint.b, roughness)


# ============================================================
# THE FOREST (Terrain3D instances)
# ============================================================

## Paints the forest as Terrain3D mesh instances into the regions (they are saved with them), on
## the baked heights: single real trees near the overlook and inside the town's square, and
## STANDS (see VistaForestAssets) everywhere else, one per 64 m block. Run after the terrain is
## shaped (`bake_terrain` does).
func plant_forest(terrain: Terrain3D, town: TownBlockout, owned: Callable) -> void:
	var data: Terrain3DData = terrain.data
	var instancer: Terrain3DInstancer = terrain.get_instancer()
	var scenery: TownScenery = town._scenery
	var ground: Callable = func(world: Vector2) -> float: return data.get_height(Vector3(world.x, 0.0, world.y))
	var stand: Callable = _stand_species
	var grove: Callable = _grove.bind(data)
	var to_world: Transform3D = town.global_transform
	_stand_noise.seed = 57
	_stand_noise.frequency = 0.0042
	_stand_noise.fractal_octaves = 2
	_grove_noise.seed = 63
	_grove_noise.frequency = 0.007
	_grove_noise.fractal_octaves = 2

	var ids: Array[int] = []
	ids.append_array(MESH_IDS)
	ids.append_array(STAND_IDS)
	var transforms: Dictionary = {}
	var colors: Dictionary = {}
	for id: int in ids:
		transforms[id] = [] as Array[Transform3D]
		colors[id] = PackedColorArray()

	var stands: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 909

	# The canopy stands first (the single trees keep off the blocks they cover).
	var covered: Dictionary = {}
	var block: float = VistaForestAssets.CLUMP_SIZE
	for bz: int in range(floori(LIMITS.position.y / block), floori(LIMITS.end.y / block)):
		for bx: int in range(floori(LIMITS.position.x / block), floori(LIMITS.end.x / block)):
			var centre: Vector2 = Vector2((float(bx) + 0.5) * block, (float(bz) + 0.5) * block)
			if _grove(centre, data) < 0.3:
				_reject("clearing")
				continue

			var placed_stand: Variant = _stand_transform(data, town, centre, rng, owned)
			if placed_stand == null:
				continue

			var id: int = STAND_IDS[_stand_species(centre)]
			(transforms[id] as Array[Transform3D]).append(placed_stand)
			(colors[id] as PackedColorArray).append(Color.WHITE)
			covered[Vector2i(bx, bz)] = true
			stands += 1


	var block_size: float = VistaForestAssets.CLUMP_SIZE
	var is_covered: Callable = func(world: Vector2) -> bool: return covered.has(Vector2i(floori(world.x / block_size), floori(world.y / block_size)))
	var singles: int = 0
	for spot: Dictionary in scenery.vista_forest_spots(ground, stand, grove, owned, is_covered, NEAR_RADIUS):
		var id: int = MESH_IDS[spot["species"]]
		(transforms[id] as Array[Transform3D]).append(to_world * (spot["transform"] as Transform3D))
		(colors[id] as PackedColorArray).append(Color.WHITE)
		singles += 1

	# The eucalyptus plantations: the medium tree, stretched slim and tall.
	for spot: Transform3D in scenery.vista_eucalyptus_spots():
		var placed: Transform3D = to_world * Transform3D(spot.basis.scaled(Vector3(0.55, 1.7, 0.55)), spot.origin)
		if not bool(owned.call(Vector2(placed.origin.x, placed.origin.z))):
			continue

		var height: float = ground.call(Vector2(placed.origin.x, placed.origin.z))
		if is_nan(height):
			continue

		placed.origin.y = height - 0.1
		(transforms[MESH_IDS[TownScenery.TREE_MEDIUM]] as Array[Transform3D]).append(placed)
		(colors[MESH_IDS[TownScenery.TREE_MEDIUM]] as PackedColorArray).append(Color.WHITE)
		singles += 1

	# The trees the town would have built as shapes (yards, pastures, cemetery, the trail): real
	# trees of the block's species, seated on the baked ground. Cypresses are the medium tree
	# stretched slim.
	for yard: Dictionary in town.vista_tree_spots:
		var base: Vector3 = to_world * (yard["position"] as Vector3)
		if not bool(owned.call(Vector2(base.x, base.z))):
			continue

		var seat: float = ground.call(Vector2(base.x, base.z))
		if is_nan(seat):
			continue

		var species: int = _stand_species(Vector2(base.x, base.z))
		if species == TownScenery.TREE_ARAUCARIA:
			species = TownScenery.TREE_MEDIUM

		var tree_scale: float = float(yard["height"]) / 9.0
		var yard_basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(tree_scale, tree_scale, tree_scale))
		if bool(yard["slim"]):
			species = TownScenery.TREE_MEDIUM
			yard_basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(tree_scale * 0.4, tree_scale * 1.15, tree_scale * 0.4))

		(transforms[MESH_IDS[species]] as Array[Transform3D]).append(Transform3D(yard_basis, Vector3(base.x, seat - 0.1, base.z)))
		(colors[MESH_IDS[species]] as PackedColorArray).append(Color.WHITE)
		singles += 1

	for id: int in ids:
		var list: Array[Transform3D] = transforms[id]
		if not list.is_empty():
			instancer.add_transforms(id, list, colors[id], false)

	stats["trees"] = singles
	stats["stands"] = stands
	# Only the regions that got vista trees change (the authored vegetation uses the ids below 21).
	for region: Terrain3DRegion in data.get_regions_active():
		if _has_vista_instances(region):
			region.set_modified(true)


## A belt of trees in front of the town's nearest houses, so that in the call's shot of the city their bottoms (which stood on bare
## ground) are hidden: for each house of the front rows (the ones nearest the call's camera, within `FRINGE_DEPTH`, in front of the
## town's middle) a few single trees stand between it and the camera, `FRINGE_NEAR` to `FRINGE_FAR` metres in front, never on a house or
## on another tree. Adds Terrain3D instances only (heights are not touched) and saves only the regions it planted in. Run it ONCE on the
## baked terrain (`-- fringe`); to run it again, restore the terrain first (`git checkout -- terrain_data`). Prints how many of the front
## houses have their foot, and the top of their wall, hidden from the call's camera by the new trees alone.
func plant_fringe(terrain: Terrain3D, town: TownBlockout) -> Dictionary:
	var data: Terrain3DData = terrain.data
	var instancer: Terrain3DInstancer = terrain.get_instancer()
	_stand_noise.seed = 57
	_stand_noise.frequency = 0.0042
	_stand_noise.fractal_octaves = 2
	var camera: Vector3 = FRINGE_CAMERA
	var camera_flat: Vector2 = Vector2(camera.x, camera.z)
	var forward: Vector2 = Vector2(FRINGE_LOOK.x, FRINGE_LOOK.y).normalized()

	# Every building the call's camera can see (the core's houses and the outer town's, which are merged into a few meshes: told apart by
	# the tall cells of a 12 m grid over their vertices), and of those the ones in front: nothing nearer stands in front of them.
	var houses: Array[Vector3] = _building_spots(town)
	var visible: Array[Vector3] = []
	for house: Vector3 in houses:
		var offset: Vector2 = Vector2(house.x, house.z) - camera_flat
		if offset.length() < FRINGE_REACH and rad_to_deg(acos(clampf(offset.normalized().dot(forward), -1.0, 1.0))) < FRINGE_ARC:
			visible.append(house)
	var front: Array[Vector3] = []
	for house: Vector3 in visible:
		var offset: Vector2 = Vector2(house.x, house.z) - camera_flat
		var hidden_behind: bool = false
		for other: Vector3 in visible:
			var other_offset: Vector2 = Vector2(other.x, other.z) - camera_flat
			if other_offset.length() < offset.length() - 18.0 and rad_to_deg(acos(clampf(offset.normalized().dot(other_offset.normalized()), -1.0, 1.0))) < 2.5:
				hidden_behind = true
				break
		if not hidden_behind:
			front.append(house)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var transforms: Dictionary = {}
	var colors: Dictionary = {}
	for id: int in MESH_IDS:
		transforms[id] = [] as Array[Transform3D]
		colors[id] = PackedColorArray()

	var trees: Array[Dictionary] = []
	for house: Vector3 in front:
		var house_flat: Vector2 = Vector2(house.x, house.z)
		var toward: Vector2 = (camera_flat - house_flat).normalized()
		var side: Vector2 = Vector2(-toward.y, toward.x)
		for attempt: int in FRINGE_PER_HOUSE * 4:
			if _fringe_count_near(trees, house_flat, FRINGE_FAR) >= FRINGE_PER_HOUSE:
				break

			var spot: Vector2 = house_flat + toward * rng.randf_range(FRINGE_NEAR, FRINGE_FAR) + side * rng.randf_range(-FRINGE_SIDE, FRINGE_SIDE)
			var clear: bool = true
			for other: Vector3 in houses:
				if Vector2(other.x, other.z).distance_to(spot) < FRINGE_FROM_HOUSE:
					clear = false
					break
			if not clear:
				continue

			for tree: Dictionary in trees:
				if (tree["flat"] as Vector2).distance_to(spot) < FRINGE_APART:
					clear = false
					break
			if not clear:
				continue

			var ground: float = data.get_height(Vector3(spot.x, 0.0, spot.y))
			if is_nan(ground) or absf(ground - house.y) > 8.0:
				continue

			var species: int = _stand_species(spot)
			if species == TownScenery.TREE_ARAUCARIA:
				species = TownScenery.TREE_MEDIUM
			var tree_scale: float = rng.randf_range(1.2, 1.95)
			var placed: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tree_scale), Vector3(spot.x, ground - 0.1, spot.y))
			(transforms[MESH_IDS[species]] as Array[Transform3D]).append(placed)
			(colors[MESH_IDS[species]] as PackedColorArray).append(Color.WHITE)
			trees.append({"flat": spot, "foot": ground, "height": FRINGE_TREE_HEIGHT * tree_scale, "radius": FRINGE_CROWN * tree_scale})

	for id: int in MESH_IDS:
		var list: Array[Transform3D] = transforms[id]
		if not list.is_empty():
			instancer.add_transforms(id, list, colors[id], false)

	var locations: Dictionary = {}
	for tree: Dictionary in trees:
		var flat: Vector2 = tree["flat"]
		locations[data.get_region_location(Vector3(flat.x, 0.0, flat.y))] = true
	for location: Vector2i in locations:
		data.save_region(location, TERRAIN_DIRECTORY, false)

	var foot_hidden: int = 0
	var wall_hidden: int = 0
	for house: Vector3 in front:
		if _fringe_hides(trees, camera, house):
			foot_hidden += 1
		if _fringe_hides(trees, camera, house + Vector3(0.0, 6.0, 0.0)):
			wall_hidden += 1

	var result: Dictionary = {"front_houses": front.size(), "trees": trees.size(), "regions_saved": locations.size(), "feet_hidden": foot_hidden, "walls_top_hidden": wall_hidden}
	print("  fringe: ", result)
	return result


## The buildings of the town as points (x, ground, z): the core's houses by their nodes, the outer town's merged house meshes ("Houses_*") by
## the cells of a 12 m grid in which their vertices span more than 3.5 m of height.
func _building_spots(town: TownBlockout) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for node: Node in town.find_children("House*", "Node3D", true, false):
		spots.append((node as Node3D).global_position)

	for node: Node in town.find_children("Houses_*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		var cells: Dictionary = {}
		for surface: int in mesh_instance.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var world: Vector3 = mesh_instance.global_transform * vertex
				var key: Vector2i = Vector2i(floori(world.x / 12.0), floori(world.z / 12.0))
				var cell: Dictionary = cells.get(key, {"lo": 1.0e9, "hi": -1.0e9, "x": 0.0, "z": 0.0, "n": 0})
				cell["lo"] = minf(float(cell["lo"]), world.y)
				cell["hi"] = maxf(float(cell["hi"]), world.y)
				cell["x"] = float(cell["x"]) + world.x
				cell["z"] = float(cell["z"]) + world.z
				cell["n"] = int(cell["n"]) + 1
				cells[key] = cell
		for key: Vector2i in cells:
			var cell: Dictionary = cells[key]
			if float(cell["hi"]) - float(cell["lo"]) > 3.5:
				spots.append(Vector3(float(cell["x"]) / float(cell["n"]), float(cell["lo"]), float(cell["z"]) / float(cell["n"])))
	return spots


func _fringe_count_near(trees: Array[Dictionary], flat: Vector2, radius: float) -> int:
	var count: int = 0
	for tree: Dictionary in trees:
		if (tree["flat"] as Vector2).distance_to(flat) < radius:
			count += 1
	return count


## Whether one of the new trees stands in the straight line from `from` to `to` (a crown of the tree's radius, from its foot to its top).
func _fringe_hides(trees: Array[Dictionary], from: Vector3, to: Vector3) -> bool:
	var from_flat: Vector2 = Vector2(from.x, from.z)
	var to_flat: Vector2 = Vector2(to.x, to.z)
	var along: Vector2 = to_flat - from_flat
	var length_squared: float = along.length_squared()
	for tree: Dictionary in trees:
		var flat: Vector2 = tree["flat"]
		var t: float = clampf((flat - from_flat).dot(along) / length_squared, 0.0, 1.0)
		if t > 0.995:
			continue

		if from_flat.lerp(to_flat, t).distance_to(flat) < float(tree["radius"]):
			var line_height: float = lerpf(from.y, to.y, t)
			if line_height < float(tree["foot"]) + float(tree["height"]) and line_height > float(tree["foot"]):
				return true
	return false


## Forest on the bare meadow between the overlook and the town: where the valley floor in front of the town was left a clearing (the groves
## and clearings of `plant_forest` are by noise), the call's shot of the city sees the first rows of houses standing on bare grass. Every
## 64 m block of the strip from `COVER_FROM` m from the call's camera to `COVER_GAP` m before the nearest house, `COVER_SIDE` m either side of
## the line to the town's middle, that has no canopy stand yet gets one (the same stands, on the same terms: nowhere the town built, none on
## ground too steep or lumpy). Adds Terrain3D instances only and saves only the regions it planted in. Run it ONCE (`-- cover`), after the
## baked terrain and `-- fringe`; to run it again restore the terrain first (`git checkout -- terrain_data`).
func plant_cover(terrain: Terrain3D, town: TownBlockout) -> Dictionary:
	var data: Terrain3DData = terrain.data
	var instancer: Terrain3DInstancer = terrain.get_instancer()
	_stand_noise.seed = 57
	_stand_noise.frequency = 0.0042
	_stand_noise.fractal_octaves = 2
	var camera_flat: Vector2 = Vector2(FRINGE_CAMERA.x, FRINGE_CAMERA.z)
	var axis: Vector2 = (Vector2(CENTER.x, CENTER.y) - camera_flat).normalized()
	var across: Vector2 = Vector2(-axis.y, axis.x)
	var nearest: float = INF
	for node: Node in town.find_children("House*", "Node3D", true, false):
		var at: Vector3 = (node as Node3D).global_position
		nearest = minf(nearest, (Vector2(at.x, at.z) - camera_flat).dot(axis))

	var existing: Dictionary = _stand_blocks(terrain)
	_cover_mode = true
	_cover_houses.clear()
	for spot_at: Vector3 in _building_spots(town):
		_cover_houses.append(Vector2(spot_at.x, spot_at.z))
	var block: float = VistaForestAssets.CLUMP_SIZE
	var owned: Callable = func(_world: Vector2) -> bool: return true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 515
	var transforms: Dictionary = {}
	var colors: Dictionary = {}
	for id: int in STAND_IDS:
		transforms[id] = [] as Array[Transform3D]
		colors[id] = PackedColorArray()

	var wanted: int = 0
	var already: int = 0
	var placed: Array[Vector2] = []
	for bz: int in range(floori((camera_flat.y - 600.0) / block), floori((camera_flat.y + 200.0) / block)):
		for bx: int in range(floori((camera_flat.x - 300.0) / block), floori((camera_flat.x + 700.0) / block)):
			var centre: Vector2 = Vector2((float(bx) + 0.5) * block, (float(bz) + 0.5) * block)
			var along: float = (centre - camera_flat).dot(axis)
			if along < COVER_FROM or along > nearest - COVER_GAP or absf((centre - camera_flat).dot(across)) > COVER_SIDE:
				continue

			wanted += 1
			if existing.has(Vector2i(bx, bz)):
				already += 1
				continue

			var spot: Variant = _stand_transform(data, town, centre, rng, owned)
			if spot == null:
				continue

			var id: int = STAND_IDS[_stand_species(centre)]
			(transforms[id] as Array[Transform3D]).append(spot)
			(colors[id] as PackedColorArray).append(Color.WHITE)
			placed.append(centre)

	for id: int in STAND_IDS:
		var list: Array[Transform3D] = transforms[id]
		if not list.is_empty():
			instancer.add_transforms(id, list, colors[id], false)

	var locations: Dictionary = {}
	for centre: Vector2 in placed:
		locations[data.get_region_location(Vector3(centre.x, 0.0, centre.y))] = true
	for location: Vector2i in locations:
		data.save_region(location, TERRAIN_DIRECTORY, false)

	_cover_mode = false
	var result: Dictionary = {"blocks_in_strip": wanted, "had_a_stand": already, "stands_added": placed.size(), "regions_saved": locations.size(), "rejected": stats}
	print("  cover: ", result)
	return result


## The 64 m blocks (by index) that already hold a canopy stand.
func _stand_blocks(terrain: Terrain3D) -> Dictionary:
	var data: Terrain3DData = terrain.data
	var region_size: int = int(float(terrain.region_size) * terrain.vertex_spacing)
	var block: float = VistaForestAssets.CLUMP_SIZE
	var found: Dictionary = {}
	for region: Terrain3DRegion in data.get_regions_active():
		var offset: Vector3 = Vector3(float(region.get_location().x * region_size), 0.0, float(region.get_location().y * region_size))
		var instances: Dictionary = region.get_instances()
		for mesh_id: Variant in instances.keys():
			if not STAND_IDS.has(int(mesh_id)):
				continue

			for cell: Variant in (instances[mesh_id] as Dictionary).keys():
				for spot: Transform3D in (instances[mesh_id][cell] as Array)[0]:
					var world: Vector3 = spot.origin + offset
					found[Vector2i(floori(world.x / block), floori(world.z / block))] = true
	return found


## The species of the 64 m block a world point is in (a patch of the forest, one species).
func _stand_species(world: Vector2) -> int:
	var block: float = VistaForestAssets.CLUMP_SIZE
	var centre: Vector2 = Vector2((floorf(world.x / block) + 0.5) * block, (floorf(world.y / block) + 0.5) * block)
	var value: float = _stand_noise.get_noise_2d(centre.x, centre.y)
	if value < -0.2:
		return TownScenery.TREE_BROAD
	if value < 0.22:
		return TownScenery.TREE_MEDIUM
	if value < 0.42:
		return TownScenery.TREE_PITANGUEIRA
	return TownScenery.TREE_ARAUCARIA


## Where a stand goes on a block, or null. The stand is one rigid mesh, so it is SHEARED to the
## slope under it (trees stay vertical, their feet follow the ground plane fitted over the block).
func _stand_transform(data: Terrain3DData, town: TownBlockout, centre: Vector2, rng: RandomNumberGenerator, owned: Callable) -> Variant:
	var block: float = VistaForestAssets.CLUMP_SIZE
	if not LIMITS.grow(-block * 0.5).has_point(centre):
		_reject("limits")
		return null

	# The near ring has single trees; the town's square has its own (a stand would bury houses).
	if centre.distance_to(OVERLOOK) < NEAR_RADIUS + 15.0:
		_reject("near")
		return null

	# Inside the town's square a canopy stand goes only where the town built nothing (the hills
	# behind it): 25 samples over the block, none on a house, road, farm or near the centre.
	var to_local: Transform3D = town.global_transform.affine_inverse()
	var scenery: TownScenery = town._scenery
	if _cover_mode:
		# The meadow in front of the town belongs to the town's own ground (pastures, yards), so `vista_spot_free` refuses all of it: here the block is
		# free when no house stands on it or within 8 m of it, and none of 25 samples is bare dirt (a road, a pitch).
		var area: Rect2 = Rect2(centre - Vector2(block, block) * 0.5, Vector2(block, block)).grow(8.0)
		for house: Vector2 in _cover_houses:
			if area.has_point(house):
				_reject("house")
				return null

		var bare: int = 0
		for sz: int in range(-2, 3):
			for sx: int in range(-2, 3):
				var sample: Vector3 = Vector3(centre.x + float(sx) * block * 0.22, 0.0, centre.y + float(sz) * block * 0.22)
				var texture: Vector3 = data.get_texture_id(sample)
				if (int(texture.x) == TEX_DIRT and texture.z < 0.5) or (int(texture.y) == TEX_DIRT and texture.z >= 0.5):
					bare += 1
		# A few streets cross every block; a pitch or a square (a third of the samples or more is dirt) keeps its sky.
		if bare >= COVER_MAX_BARE:
			_reject("dirt")
			return null
	else:
		for sz: int in range(-2, 3):
			for sx: int in range(-2, 3):
				var local: Vector3 = to_local * Vector3(centre.x + float(sx) * block * 0.22, 0.0, centre.y + float(sz) * block * 0.22)
				if not scenery.vista_spot_free(local.x, local.z):
					_reject("town")
					return null

	# The ground over the block: nine samples, a plane through them.
	var reach: float = block * 0.375
	var samples: Array[Vector3] = []
	for dz: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var point: Vector3 = Vector3(centre.x + float(dx) * reach, 0.0, centre.y + float(dz) * reach)
			if not bool(owned.call(Vector2(point.x, point.z))):
				_reject("authored ground")
				return null

			var height: float = data.get_height(point)
			if is_nan(height):
				_reject("nan")
				return null

			samples.append(Vector3(float(dx) * reach, height, float(dz) * reach))

	var mean: float = 0.0
	for sample: Vector3 in samples:
		mean += sample.y / 9.0

	# Least squares for the two gradients (the nine points are on a regular grid).
	var gradient_x: float = 0.0
	var gradient_z: float = 0.0
	for sample: Vector3 in samples:
		gradient_x += sample.x * (sample.y - mean)
		gradient_z += sample.z * (sample.y - mean)

	var sum_sq: float = 6.0 * reach * reach
	gradient_x /= sum_sq
	gradient_z /= sum_sq
	var worst: float = 0.0
	for sample: Vector3 in samples:
		worst = maxf(worst, absf(sample.y - (mean + gradient_x * sample.x + gradient_z * sample.z)))

	# Too steep (a cliff) or too lumpy for one rigid mesh: no stand.
	if worst > 12.0 or Vector2(gradient_x, gradient_z).length() > 1.05:
		_reject("steep" if Vector2(gradient_x, gradient_z).length() > 0.75 else "lumpy")
		return null

	var shear: Basis = Basis(Vector3(1.0, gradient_x, 0.0), Vector3.UP, Vector3(0.0, gradient_z, 1.0))
	var basis: Basis = shear * Basis(Vector3.UP, rng.randf() * TAU)
	return Transform3D(basis, Vector3(centre.x, mean - 0.3, centre.y))


# ============================================================
# THE SCENE
# ============================================================

## Saves `town` (already built in vista mode) as the scene `path`, with its transform reset.
func bake_scene(town: TownBlockout, path: String) -> Error:
	var placed: Transform3D = town.transform
	town.transform = Transform3D.IDENTITY
	_own(town, town)
	var packed: PackedScene = PackedScene.new()
	var result: Error = packed.pack(town)
	town.transform = placed
	if result != OK:
		return result

	return ResourceSaver.save(packed, path)


func _own(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own(child, root)


# ============================================================
# CHECKS
# ============================================================

## Prints, for the overlook's eye position(s), how many points of the town can be seen over the
## terrain (a ray every 2 m against the Terrain3D heights): the vista has to be visible.
func check_visibility(terrain: Terrain3D, town: TownBlockout) -> void:
	var data: Terrain3DData = terrain.data
	var to_world: Transform3D = town.global_transform
	var scenery: TownScenery = town._scenery
	var eyes: Array[Vector3] = [Vector3(166.0, -17.4, 24.5), Vector3(172.0, -17.4, 19.5), Vector3(160.0, -17.4, 29.0)]
	var places: Dictionary = {"church": scenery.landmarks.get("IgrejaMatriz", Vector3.ZERO), "praca": scenery.landmarks.get("Coreto", Vector3.ZERO), "station": scenery.landmarks.get("Estacao", Vector3.ZERO), "football": scenery.landmarks.get("CampoDeFutebol", Vector3.ZERO), "cemetery": scenery.landmarks.get("Cemiterio", Vector3.ZERO), "core": Vector3.ZERO, "cruzeiro": scenery.landmarks.get("Cruzeiro", Vector3.ZERO)}
	for eye: Vector3 in eyes:
		var line: String = "  eye (%.0f, %.0f): " % [eye.x, eye.z]
		for place: String in places:
			var local: Vector3 = places[place]
			var target: Vector3 = to_world * (local + Vector3(0.0, 6.0, 0.0))
			var visible: bool = true
			var steps: int = int(Vector2(target.x - eye.x, target.z - eye.z).length() / 2.0)
			for i: int in range(1, steps):
				var t: float = float(i) / float(steps)
				var p: Vector3 = eye.lerp(target, t)
				var ground: float = data.get_height(Vector3(p.x, 0.0, p.z))
				if not is_nan(ground) and ground > p.y:
					visible = false
					break

			line += "%s %s, " % [place, "yes" if visible else "HIDDEN"]

		print(line)


## Compares the baked Terrain3D with the town's own ground, over the 660 m square of the town:
## `terrain - town` in metres (positive: the terrain would hide things the town built there).
func check_match(terrain: Terrain3D, town: TownBlockout) -> Dictionary:
	var data: Terrain3DData = terrain.data
	var scenery: TownScenery = town._scenery
	var to_world: Transform3D = town.global_transform
	var core_worst: float = 0.0
	var core_sum: float = 0.0
	var core_n: int = 0
	var worst_up: float = -INF
	var worst_down: float = INF
	var buried: int = 0
	var total: int = 0
	var x: float = TownScenery.X0
	while x < TownScenery.X0 + TownScenery.SIZE:
		var z: float = TownScenery.Z0
		while z < TownScenery.Z0 + TownScenery.SIZE:
			var world: Vector3 = to_world * Vector3(x, 0.0, z)
			var ground: float = data.get_height(world)
			var wanted: float = world.y + scenery.height_at(x, z)
			var diff: float = ground - wanted
			if not is_nan(ground) and LIMITS.has_point(Vector2(world.x, world.z)):
				total += 1
				worst_up = maxf(worst_up, diff)
				worst_down = minf(worst_down, diff)
				if diff > 0.15:
					buried += 1
				if TownScenery.CORE.has_point(Vector2(x, z)):
					core_n += 1
					core_sum += absf(diff)
					core_worst = maxf(core_worst, absf(diff))

			z += 2.0

		x += 2.0

	var result: Dictionary = {"samples": total, "terrain_above_town_max": worst_up, "terrain_below_town_max": worst_down, "terrain_over_0.15m": buried, "core_mean_abs": core_sum / maxf(float(core_n), 1.0), "core_worst_abs": core_worst}
	print("  terrain vs town ground: ", result)
	return result


## Prints how the planted trees stand on the baked terrain: the world height of each tree's foot
## minus the terrain's height under it (they are seated 0.15 m deep on purpose).
func check_trees(terrain: Terrain3D) -> Dictionary:
	var data: Terrain3DData = terrain.data
	var region_size: int = int(float(terrain.region_size) * terrain.vertex_spacing)
	var count: int = 0
	var low: float = INF
	var high: float = -INF
	var off: int = 0
	for region: Terrain3DRegion in data.get_regions_active():
		var offset: Vector3 = Vector3(float(region.get_location().x * region_size), 0.0, float(region.get_location().y * region_size))
		var instances: Dictionary = region.get_instances()
		for mesh_id: Variant in instances.keys():
			if not MESH_IDS.has(int(mesh_id)) and not STAND_IDS.has(int(mesh_id)):
				continue

			for cell: Variant in (instances[mesh_id] as Dictionary).keys():
				for spot: Transform3D in (instances[mesh_id][cell] as Array)[0]:
					var foot: Vector3 = spot.origin + offset
					var ground: float = data.get_height(foot)
					if is_nan(ground):
						continue

					count += 1
					low = minf(low, foot.y - ground)
					high = maxf(high, foot.y - ground)
					if absf(foot.y - ground) > 0.4:
						off += 1

	var result: Dictionary = {"trees": count, "foot_vs_ground_min": low, "foot_vs_ground_max": high, "more_than_0.4m_off": off}
	print("  trees on terrain: ", result)
	return result


func _reject(reason: String) -> void:
	stats["no stand: " + reason] = int(stats.get("no stand: " + reason, 0)) + 1


## How much forest there is at a world point, 0 (a meadow) to 1 (forest): groves and clearings in
## the valley, always forest on the high ground.
func _grove(world: Vector2, data: Terrain3DData) -> float:
	var noise: float = _grove_noise.get_noise_2d(world.x, world.y) * 0.5 + 0.5
	var density: float = smoothstep(0.34, 0.6, noise)
	var above: float = data.get_height(Vector3(world.x, 0.0, world.y)) - FLOOR_WORLD
	return lerpf(density, 1.0, smoothstep(25.0, 70.0, above))


## Does the region hold trees of the vista (the instancer also keeps empty entries)?
func _has_vista_instances(region: Terrain3DRegion) -> bool:
	var instances: Dictionary = region.get_instances()
	for id: Variant in instances.keys():
		if (MESH_IDS.has(int(id)) or STAND_IDS.has(int(id))) and not (instances[id] as Dictionary).is_empty():
			return true

	return false
