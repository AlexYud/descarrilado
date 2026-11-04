extends Node

## One-off terrain edit, run as a scene in a real window (the plant instancer needs a renderer):
## `Godot --path . res://scripts/tools/add_tree_base_plants.tscn` prints what it would add; add `-- --apply` to write.
##
## The trees that stand by the paths had bare soil round their feet, so that they read as a model set down on the ground (the generator leaves the path's edge
## sparse and the trees' mulch is only a texture). A few small plants are added round the base of each of them, the way grass and ferns gather at a trunk:
##  - only the trees that are within `PATH_REACH` metres of a path cell (the mesh ids of the trees: 1, 2, 3 and the araucarias 14), none of the far ones;
##  - small foliage (mesh ids 11 and 12, the grass tufts) in a ring close to the trunk, a couple of small ferns (id 9) and, now and then, a white flower (id 8),
##    all small, at the colours of the grass that is already there;
##  - every one of those trees gets a ring of them (the plants the generator left there are mostly tiny, by the path, or hide behind a bush), unless it already has this
##    tool's own (`ENOUGH_NEAR`); nothing is moved or removed, and nothing is put on the path itself;
##  - it can be run again (a tree that has its plants is left as it is).
## The new plants are marked (alpha of their colour `OWN_MARK`), so that this tool does not add twice and `add_ground_grass.gd` does not scale them.

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
const PATH_TEXTURE: int = 1
const X0: int = -14
const Z0: int = -90
const WIDTH: int = 204
const HEIGHT: int = 164

const TREE_IDS: Array[int] = [1, 2, 3, 14]
const GRASS_IDS: Array[int] = [11, 12]
const FERN_ID: int = 9
const FLOWER_ID: int = 8
## Plants that count as "already something at the foot".
const SMALL_IDS: Array[int] = [11, 12, 9, 8]
## A tree this near a path cell (metres) gets plants.
const PATH_REACH: float = 3.0
## How near the foot counts, and how many of THIS tool's plants there make it done (it is run again without doubling).
const FOOT_RADIUS: float = 1.6
const ENOUGH_NEAR: int = 3
## The mark of the plants this tool adds (the alpha of their colour; under `add_ground_grass.gd`'s `GROWN_MARK` so that tool leaves them alone as well).
const OWN_MARK: float = 0.985
## The ring: from a little off the trunk to a metre or so out (grown with the tree's scale).
const RING_INNER: float = 0.4
const RING_OUTER: float = 1.25
const GRASS_COUNT: Vector2i = Vector2i(6, 10)
const FERN_COUNT: Vector2i = Vector2i(1, 2)
const FLOWER_CHANCE: float = 0.3
const GRASS_SCALE: Vector2 = Vector2(0.3, 0.75)
const FERN_SCALE: Vector2 = Vector2(0.3, 0.5)
const FLOWER_SCALE: Vector2 = Vector2(0.5, 0.9)
const MAX_SLOPE_DEGREES: float = 40.0

var _terrain: Terrain3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _distance: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var apply: bool = OS.get_cmdline_user_args().has("--apply")
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	_terrain = scene.get_node("Terrain3D") as Terrain3D
	_rng.seed = 20261104
	_measure_distance()
	var result: Dictionary = _plan()
	print("TREES NEAR PATHS ", result["trees"], ", WITH ENOUGH ", result["enough"], ", PLANTED ", result["planted"], " | NEW PLANTS ", (result["planned"] as Array).size(), " ", result["by_id"])
	if apply:
		var instancer: Terrain3DInstancer = _terrain.get_instancer()
		for id: int in GRASS_IDS + [FERN_ID, FLOWER_ID]:
			var transforms: Array[Transform3D] = []
			var colors: PackedColorArray = PackedColorArray()
			for entry: Dictionary in result["planned"]:
				if int(entry["id"]) == id:
					transforms.append(entry["transform"])
					colors.append(entry["color"])

			if not transforms.is_empty():
				instancer.add_transforms(id, transforms, colors)

		_terrain.data.save_directory(TERRAIN_DIRECTORY)
		print("SAVED terrain data")

	get_tree().quit()


func _index(x: int, z: int) -> int:
	return z * WIDTH + x


## Distance in metres from every cell to the nearest path cell (a sweep out to `PATH_REACH`).
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
	var reach: float = PATH_REACH + 1.0
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


func _distance_at(point: Vector2) -> float:
	var cx: int = floori(point.x - float(X0))
	var cz: int = floori(point.y - float(Z0))
	if cx < 0 or cz < 0 or cx >= WIDTH or cz >= HEIGHT:
		return 1e9
	return _distance[_index(cx, cz)]


## The trees by the paths, the small plants already at their feet, and what to add.
func _plan() -> Dictionary:
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var trees: Array[Dictionary] = []
	var small: Dictionary = {}
	var colors: Array[Color] = []
	for region: Terrain3DRegion in _terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in instances.keys():
			var is_tree: bool = TREE_IDS.has(mesh_id)
			if not is_tree and not SMALL_IDS.has(mesh_id):
				continue

			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in cell_transforms.size():
					var transform: Transform3D = cell_transforms[i]
					var point: Vector2 = Vector2(transform.origin.x + offset.x, transform.origin.z + offset.y)
					if is_tree:
						if _distance_at(point) <= PATH_REACH:
							trees.append({"point": point, "scale": transform.basis.get_scale().y})
					else:
						var key: Vector2i = Vector2i(floori(point.x / 2.0), floori(point.y / 2.0))
						if not small.has(key):
							small[key] = []
						if i < cell_colors.size() and absf(cell_colors[i].a - OWN_MARK) < 0.002:
							(small[key] as Array).append(point)
						if GRASS_IDS.has(mesh_id) and colors.size() < 4000 and i < cell_colors.size() and _rng.randf() < 0.05:
							colors.append(cell_colors[i])

	if colors.is_empty():
		colors.append(Color.WHITE)

	var planned: Array[Dictionary] = []
	var by_id: Dictionary = {}
	var enough: int = 0
	var planted: int = 0
	var min_normal_y: float = cos(deg_to_rad(MAX_SLOPE_DEGREES))
	for tree: Dictionary in trees:
		var base: Vector2 = tree["point"]
		var near: int = 0
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var key: Vector2i = Vector2i(floori(base.x / 2.0) + dx, floori(base.y / 2.0) + dz)
				for other: Vector2 in small.get(key, []):
					if other.distance_to(base) <= FOOT_RADIUS:
						near += 1

		if near >= ENOUGH_NEAR:
			enough += 1
			continue

		planted += 1
		var grown: float = clampf(float(tree["scale"]), 0.7, 1.6)
		var jobs: Array[int] = []
		for n: int in _rng.randi_range(GRASS_COUNT.x, GRASS_COUNT.y):
			jobs.append(GRASS_IDS[_rng.randi() % GRASS_IDS.size()])
		for n: int in _rng.randi_range(FERN_COUNT.x, FERN_COUNT.y):
			jobs.append(FERN_ID)
		if _rng.randf() < FLOWER_CHANCE:
			jobs.append(FLOWER_ID)
		for id: int in jobs:
			var angle: float = _rng.randf() * TAU
			var radius: float = lerpf(RING_INNER * grown, RING_OUTER * grown, pow(_rng.randf(), 0.8))
			var point: Vector2 = base + Vector2(cos(angle), sin(angle)) * radius
			# Nothing on the path itself.
			if _distance_at(point) < 0.6:
				continue

			var world: Vector3 = Vector3(point.x, 0.0, point.y)
			var height: float = _terrain.data.get_height(world)
			if is_nan(height) or _terrain.data.get_normal(world).y < min_normal_y:
				continue

			var range_scale: Vector2 = GRASS_SCALE if GRASS_IDS.has(id) else (FERN_SCALE if id == FERN_ID else FLOWER_SCALE)
			var scale: float = lerpf(range_scale.x, range_scale.y, pow(_rng.randf(), 1.4))
			var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(scale * _rng.randf_range(0.9, 1.1), scale, scale * _rng.randf_range(0.9, 1.1)))
			planned.append({
				"id": id,
				"transform": Transform3D(basis, Vector3(point.x, height, point.y)),
				"color": Color(colors[_rng.randi() % colors.size()], OWN_MARK),
			})
			by_id[id] = int(by_id.get(id, 0)) + 1

	return {"planned": planned, "trees": trees.size(), "enough": enough, "planted": planted, "by_id": by_id}
