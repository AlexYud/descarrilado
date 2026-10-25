extends Node

## One-off terrain edit, run as a scene in a real window (the plant instancer needs a renderer):
## `Godot --path . res://scripts/tools/add_ground_grass.tscn` prints what it would add; add `-- --apply` to write.
##
## More small grass on the forest floor, the way the developer painted it by hand along trail A (from the fence door's fork to the fig tree
## clearing), for every other trail: the ground between the plants reads as a floor of grass, not as bare soil under tall plants.
## Nothing is moved or removed:
##  - the grass tufts (mesh ids 11 and 12) are added up to a TARGET number per square metre that depends on the distance from the path:
##    none where people walk (the path and its first metre and a half), rising to full density 4 m from it, and staying full through the
##    woods before fading far out ("less in the middle of the path, more further in the woods");
##  - the target is raised close to the medium and tall plants (bushes, ferns, tall plants, trees: a clump at their feet) and lowered where
##    there is none, as grass grows in the shade of its neighbours;
##  - cells that already have that many tufts get none, so a trail with plenty of grass is left as it was;
##  - the tufts already beside the path are GROWN (`_grow_existing`): the generator keeps them small near the path (mean scale 0.32 within
##    1.5 m of it) while the developer's trail A has full size ones there (0.52), which is what makes it read as grass; they are scaled up
##    to match along `GROW_CURVE`, once (a grown tuft is marked by an alpha of `GROWN_MARK` in its instance colour);
##  - never inside what the developer made by hand or the curated sites: trail A's first leg (`REFERENCE_TRAIL`), the wagon yard and gate,
##    the waiting shed, the fig clearing, the signal tower, the unfinished house, the overlook plaza and its gates.
## It can be run again (it only ever fills the difference up to the target, so a metre that has enough gets nothing).

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
const PATH_TEXTURE: int = 1
const X0: int = -14
const Z0: int = -90
const WIDTH: int = 204
const HEIGHT: int = 164

const GRASS_IDS: Array[int] = [11, 12]
## Plants whose feet the grass gathers at: bushes, ferns, tall plants and the trees.
const COMPANION_IDS: Array[int] = [0, 4, 6, 7, 9, 10, 13, 15, 19, 1, 2, 3, 14, 21, 22, 23, 24]
## How near a companion plant has to be to count, and how many of them make the target as high as it gets.
const COMPANION_RADIUS: float = 1.6
const COMPANIONS_FOR_FULL: float = 3.0
## Target tufts per square metre by distance from the nearest path cell, then multiplied by the companion factor. (Second version, after
## the developer's feedback that a spot of the forest was still bald: the first, 6.5 a square metre at 4 m, was well under what the
## hand painted trail A has, 11 to 14 within 3 m of the path.)
const PROFILE: Array[Vector2] = [
	Vector2(0.0, 5.0),
	Vector2(0.5, 5.0),
	Vector2(1.0, 8.0),
	Vector2(1.5, 11.0),
	Vector2(3.0, 12.0),
	Vector2(5.0, 11.0),
	Vector2(8.0, 8.5),
	Vector2(11.0, 4.5),
	Vector2(13.5, 1.5),
	Vector2(15.0, 0.0),
]
## On the path itself only tiny tufts grow (the developer's rule: the dirt strip is where people walk).
const PATH_SCALE_RANGE: Vector2 = Vector2(0.1, 0.24)
const PATH_DISTANCE: float = 0.5
## The factor from "no companion near" to "full".
const ALONE_FACTOR: float = 0.55
const COMPANION_FACTOR: float = 1.35
## Size of a tuft: the range the developer's grass uses, biased to the small end, smaller beside the path.
const SCALE_RANGE: Vector2 = Vector2(0.28, 0.85)
const SCALE_BIAS: float = 1.8
const EDGE_MIN_SCALE: float = 0.8
const EDGE_GROWTH_DISTANCE: float = 1.5
## How much an existing tuft is scaled up by its distance from the path (distance, factor), and the mark that says it was.
const GROW_CURVE: Array[Vector2] = [
	Vector2(0.5, 1.0),
	Vector2(1.0, 1.55),
	Vector2(2.0, 1.3),
	Vector2(3.0, 1.12),
	Vector2(4.5, 1.04),
	Vector2(6.0, 1.0),
]
const GROWN_MARK: float = 0.99
const MAX_GROWN_SCALE: float = 1.0
const MAX_SLOPE_DEGREES: float = 42.0
## The developer's hand-painted trail: the first leg of trail A, fence door fork to the fig clearing (x, z).
const REFERENCE_TRAIL: Array[Vector2] = [Vector2(21, 6), Vector2(32, -5), Vector2(40, -20), Vector2(43, -50), Vector2(53, -69)]
const REFERENCE_RADIUS: float = 11.0
## Places that keep what they have: rectangles, and circles (x, z, radius).
const EXCLUDED_RECTS: Array[Rect2] = [
	Rect2(-70.0, -95.0, 84.0, 200.0),
	Rect2(154.0, 13.0, 24.0, 24.0),
	Rect2(135.0, 10.0, 14.0, 14.0),
	Rect2(146.0, 36.0, 14.0, 14.0),
]
## The levelled floors of the curated sites and what their builders scattered on them: the waiting shed, the fig clearing (7.5 m disc), the
## signal tower's pad, the unfinished house. (The first version kept the plants of whole 40 m squares round them, which left their paths
## bald.)
const EXCLUDED_CIRCLES: Array[Vector3] = [
	Vector3(65.0, -16.0, 9.0),
	Vector3(64.0, -68.0, 10.0),
	Vector3(101.5, -36.0, 10.0),
	Vector3(68.4, 55.0, 12.0),
]

var _terrain: Terrain3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _distance: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var apply: bool = OS.get_cmdline_user_args().has("--apply")
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	_terrain = scene.get_node("Terrain3D") as Terrain3D
	_rng.seed = 20261024
	_measure_distance()
	var result: Dictionary = _plan()
	print("EXISTING TUFTS ", result["existing"], ", TO ADD ", (result["transforms"] as Array).size(), " (", result["by_band"], ")")
	print("TUFTS GROWN ", _grow_existing(apply))
	if apply:
		var instancer: Terrain3DInstancer = _terrain.get_instancer()
		for id: int in GRASS_IDS:
			var transforms: Array[Transform3D] = []
			var colors: PackedColorArray = PackedColorArray()
			for entry: Dictionary in result["transforms"]:
				if int(entry["id"]) == id:
					transforms.append(entry["transform"])
					colors.append(entry["color"])

			instancer.add_transforms(id, transforms, colors)

		_terrain.data.save_directory(TERRAIN_DIRECTORY)
		print("SAVED terrain data")

	get_tree().quit()


## The factor an existing tuft at distance `d` from the path is scaled by (1 on the path and far from it).
func _grow_factor(d: float) -> float:
	if d <= GROW_CURVE[0].x or d >= GROW_CURVE[GROW_CURVE.size() - 1].x:
		return 1.0

	for i: int in GROW_CURVE.size() - 1:
		var a: Vector2 = GROW_CURVE[i]
		var b: Vector2 = GROW_CURVE[i + 1]
		if d <= b.x:
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, d))

	return 1.0


## Scales up the tufts that are already beside the paths (see the top of the file). Returns how many were (or would be) grown and their mean
## scale before and after.
func _grow_existing(apply: bool) -> Dictionary:
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var grown: int = 0
	var before: float = 0.0
	var after: float = 0.0
	for region: Terrain3DRegion in _terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in GRASS_IDS:
			if not instances.has(mesh_id):
				continue

			var transforms: Array[Transform3D] = []
			var colors: PackedColorArray = PackedColorArray()
			var changed: bool = false
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in cell_transforms.size():
					var transform: Transform3D = cell_transforms[i]
					var color: Color = cell_colors[i] if i < cell_colors.size() else Color.WHITE
					var wx: float = transform.origin.x + offset.x
					var wz: float = transform.origin.z + offset.y
					var cx: int = floori(wx - float(X0))
					var cz: int = floori(wz - float(Z0))
					if cx >= 0 and cz >= 0 and cx < WIDTH and cz < HEIGHT and color.a > GROWN_MARK + 0.004 and not _excluded(Vector2(wx, wz)):
						var factor: float = _grow_factor(_distance[_index(cx, cz)])
						var current: float = transform.basis.get_scale().y
						factor = minf(factor, maxf(MAX_GROWN_SCALE / maxf(current, 0.01), 1.0))
						if factor > 1.01:
							before += current
							transform.basis = transform.basis.scaled_local(Vector3(factor, factor, factor))
							after += current * factor
							color = Color(color.r, color.g, color.b, GROWN_MARK)
							grown += 1
							changed = true

					transforms.append(transform)
					colors.append(color)

			if apply and changed:
				instancer.clear_by_region(region, mesh_id)
				instancer.append_region(region, mesh_id, transforms, colors, true)

	return {"grown": grown, "mean_before": snappedf(before / maxf(float(grown), 1.0), 0.01), "mean_after": snappedf(after / maxf(float(grown), 1.0), 0.01)}


func _index(x: int, z: int) -> int:
	return z * WIDTH + x


## Distance in metres from every cell to the nearest path cell (a sweep out to the reach of the profile).
func _measure_distance() -> void:
	var count: int = WIDTH * HEIGHT
	_distance.resize(count)
	_distance.fill(1e9)
	var queue: Array[int] = []
	for x: int in WIDTH:
		for z: int in HEIGHT:
			var id: Vector3 = _terrain.data.get_texture_id(Vector3(float(X0 + x), 0.0, float(Z0 + z)))
			if int(id.x) == PATH_TEXTURE or (int(id.y) == PATH_TEXTURE and id.z > 0.5):
				_distance[_index(x, z)] = 0.0
				queue.append(_index(x, z))

	var head: int = 0
	var reach: float = PROFILE[PROFILE.size() - 1].x + 1.0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var x: int = index % WIDTH
		var z: int = index / WIDTH
		var d: float = _distance[index]
		if d > reach:
			continue

		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				if dx == 0 and dz == 0:
					continue

				var nx: int = x + dx
				var nz: int = z + dz
				if nx < 0 or nz < 0 or nx >= WIDTH or nz >= HEIGHT:
					continue

				var other: int = _index(nx, nz)
				var step: float = 1.0 if dx == 0 or dz == 0 else 1.4142
				if _distance[other] > d + step + 0.001:
					_distance[other] = d + step
					queue.append(other)


func _target_at(d: float) -> float:
	if d >= PROFILE[PROFILE.size() - 1].x:
		return 0.0

	for i: int in PROFILE.size() - 1:
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		if d <= b.x:
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, d))

	return 0.0


func _reference_distance(point: Vector2) -> float:
	var best: float = 1e9
	for i: int in REFERENCE_TRAIL.size() - 1:
		var a: Vector2 = REFERENCE_TRAIL[i]
		var b: Vector2 = REFERENCE_TRAIL[i + 1]
		var t: float = clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, point.distance_to(a + (b - a) * t))

	return best


func _excluded(point: Vector2) -> bool:
	if _reference_distance(point) < REFERENCE_RADIUS:
		return true

	for rect: Rect2 in EXCLUDED_RECTS:
		if rect.has_point(point):
			return true

	for circle: Vector3 in EXCLUDED_CIRCLES:
		if point.distance_to(Vector2(circle.x, circle.y)) < circle.z:
			return true

	return false


## What to add: every cell's deficit against its target, as transforms in world space.
func _plan() -> Dictionary:
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var count: int = WIDTH * HEIGHT
	var tufts: PackedInt32Array = PackedInt32Array()
	tufts.resize(count)
	var companions: PackedFloat32Array = PackedFloat32Array()
	companions.resize(count)
	var colors: Array[Color] = []
	var existing: int = 0
	var companion_cells: int = int(ceil(COMPANION_RADIUS))
	for region: Terrain3DRegion in _terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in instances.keys():
			var is_grass: bool = GRASS_IDS.has(mesh_id)
			if not is_grass and not COMPANION_IDS.has(mesh_id):
				continue

			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in cell_transforms.size():
					var transform: Transform3D = cell_transforms[i]
					var wx: float = transform.origin.x + offset.x
					var wz: float = transform.origin.z + offset.y
					var cx: int = floori(wx - float(X0))
					var cz: int = floori(wz - float(Z0))
					if is_grass:
						existing += 1
						if cx >= 0 and cz >= 0 and cx < WIDTH and cz < HEIGHT:
							tufts[_index(cx, cz)] += 1

						if colors.size() < 4000 and i < cell_colors.size() and _rng.randf() < 0.05:
							colors.append(cell_colors[i])
					else:
						for dx: int in range(-companion_cells, companion_cells + 1):
							for dz: int in range(-companion_cells, companion_cells + 1):
								var nx: int = cx + dx
								var nz: int = cz + dz
								if nx < 0 or nz < 0 or nx >= WIDTH or nz >= HEIGHT:
									continue

								var centre: Vector2 = Vector2(float(X0 + nx) + 0.5, float(Z0 + nz) + 0.5)
								if centre.distance_to(Vector2(wx, wz)) <= COMPANION_RADIUS:
									companions[_index(nx, nz)] += 1.0

	if colors.is_empty():
		colors.append(Color.WHITE)

	var planned: Array[Dictionary] = []
	var by_band: Dictionary = {}
	var min_normal_y: float = cos(deg_to_rad(MAX_SLOPE_DEGREES))
	for x: int in WIDTH:
		for z: int in HEIGHT:
			var index: int = _index(x, z)
			var d: float = _distance[index]
			var target: float = _target_at(d)
			if target <= 0.0:
				continue

			var centre: Vector2 = Vector2(float(X0 + x) + 0.5, float(Z0 + z) + 0.5)
			if _excluded(centre):
				continue

			var near: float = clampf(companions[index] / COMPANIONS_FOR_FULL, 0.0, 1.0)
			target *= lerpf(ALONE_FACTOR, COMPANION_FACTOR, near)
			var deficit: float = target - float(tufts[index])
			if deficit <= 0.0:
				continue

			var number: int = int(floor(deficit)) + (1 if _rng.randf() < deficit - floor(deficit) else 0)
			for n: int in number:
				var point: Vector2 = centre + Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
				var world: Vector3 = Vector3(point.x, 0.0, point.y)
				var height: float = _terrain.data.get_height(world)
				if is_nan(height) or _terrain.data.get_normal(world).y < min_normal_y:
					continue

				var scale: float = lerpf(SCALE_RANGE.x, SCALE_RANGE.y, pow(_rng.randf(), SCALE_BIAS))
				scale *= lerpf(EDGE_MIN_SCALE, 1.0, smoothstep(0.4, EDGE_GROWTH_DISTANCE, d))
				if d < PATH_DISTANCE:
					scale = lerpf(PATH_SCALE_RANGE.x, PATH_SCALE_RANGE.y, _rng.randf())
				var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(scale * _rng.randf_range(0.9, 1.1), scale, scale * _rng.randf_range(0.9, 1.1)))
				planned.append({
					"id": GRASS_IDS[_rng.randi() % GRASS_IDS.size()],
					"transform": Transform3D(basis, Vector3(point.x, height, point.y)),
					"color": Color(colors[_rng.randi() % colors.size()], GROWN_MARK),
				})
				var band: int = int(d / 2.0) * 2
				by_band[band] = int(by_band.get(band, 0)) + 1

	return {"transforms": planned, "existing": existing, "by_band": by_band}
