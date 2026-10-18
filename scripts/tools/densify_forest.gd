extends Node

## One-off terrain edit, run as a scene in a real window (the plant instancer needs a renderer):
## `Godot --path . res://scripts/tools/densify_forest.tscn` prints what is there; add `-- --apply` to write.
##
## Makes the forest floor read as a floor and the forest as a dense forest, WITHOUT clearing anything the
## level designers placed (it only merges):
##  1. the grass tufts (mesh ids 11, 12) are thinned in a clumped pattern (patches and bare spots instead of
##     an even sprinkle); their colour is handled by tinted mesh materials (see `make_tinted_materials.gd`,
##     instance colours do not reach these models' materials);
##  2. more trees (canopy, shrub, a few araucarias) fill the gaps further from the trails, keeping the spacing
##     from every tree already there, outside the curated sites (the house, the shed, the fig clearing, the
##     overlook plaza and its gates, the wagon yard) and outside the overlook view cone;
##  3. clumped fallen leaves and half-buried rocks are added everywhere it is walked.
##
## Steps are chosen with `--tufts` and/or `--forest` after `--` (with `--apply`). Run each ONCE on a clean
## terrain (a second `--tufts` thins again; a second `--forest` adds again).

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
const Generator := preload("res://scripts/tools/forest_path_vegetation_generator.gd")

const GRASS_IDS: Array[int] = [11, 12]
const TREE_IDS: Array[int] = [1, 2, 3, 14]

const ZONE: Rect2 = Rect2(12.0, -95.0, 205.0, 190.0)
const EXCLUSIONS: Array[Rect2] = [
	Rect2(-70.0, -80.0, 82.0, 200.0),
	# The curated sites keep the plants their own builders placed.
	Rect2(48.0, 35.0, 40.0, 40.0),
	Rect2(45.0, -36.0, 40.0, 40.0),
	Rect2(29.0, -92.0, 70.0, 48.0),
	# The overlook plaza and the two foliage gates.
	Rect2(154.0, 13.0, 24.0, 24.0),
	Rect2(135.0, 10.0, 14.0, 14.0),
	Rect2(146.0, 36.0, 14.0, 14.0),
]
const OVERLOOK_ORIGIN: Vector2 = Vector2(168.0, 27.0)
const OVERLOOK_DIRECTION: Vector2 = Vector2(0.686, -0.727)


func _ready() -> void:
	var apply: bool = OS.get_cmdline_user_args().has("--apply")
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	var terrain: Terrain3D = scene.get_node("Terrain3D") as Terrain3D

	_report(terrain, "before")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if apply:
		if args.has("--forest"):
			print("ADDED: ", _add_forest(terrain))

		if args.has("--tufts"):
			print("TUFTS: ", _thin_tufts(terrain))

		_report(terrain, "after")
		terrain.data.save_directory(TERRAIN_DIRECTORY)
		print("SAVED terrain data")

	get_tree().quit()


func _report(terrain: Terrain3D, label: String) -> void:
	var counts: Dictionary = {}
	for region: Terrain3DRegion in terrain.data.get_regions_active():
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in instances.keys():
			var total: int = 0
			for cell: Variant in instances[mesh_id]:
				total += (instances[mesh_id][cell][0] as Array).size()

			counts[mesh_id] = int(counts.get(mesh_id, 0)) + total

	var keys: Array = counts.keys()
	keys.sort()
	var line: String = ""
	for key: Variant in keys:
		if int(key) in [0, 1, 2, 3, 4, 5, 9, 11, 12, 14, 17, 18]:
			line += "%d:%d " % [int(key), int(counts[key])]

	print("COUNTS (%s): %s" % [label, line])


## Thins the tufts in clumps.
func _thin_tufts(terrain: Terrain3D) -> Dictionary:
	var instancer: Terrain3DInstancer = terrain.get_instancer()
	var region_size: float = float(terrain.region_size) * terrain.vertex_spacing
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 9917
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.11
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9918
	var kept_total: int = 0
	var removed_total: int = 0

	for region: Terrain3DRegion in terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in GRASS_IDS:
			if not instances.has(mesh_id):
				continue

			var transforms: Array[Transform3D] = []
			var colors: PackedColorArray = PackedColorArray()
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in cell_transforms.size():
					var transform: Transform3D = cell_transforms[i]
					var world: Vector2 = Vector2(transform.origin.x + offset.x, transform.origin.z + offset.y)
					var patch: float = noise.get_noise_2d(world.x, world.y) * 0.5 + 0.5
					var keep: float = clampf(0.12 + 1.05 * smoothstep(0.38, 0.62, patch), 0.0, 1.0)
					if rng.randf() > keep:
						removed_total += 1
						continue

					transforms.append(transform)
					colors.append(cell_colors[i] if i < cell_colors.size() else Color.WHITE)
					kept_total += 1

			instancer.clear_by_region(region, mesh_id)
			if not transforms.is_empty():
				instancer.append_region(region, mesh_id, transforms, colors, true)

	return {"kept": kept_total, "removed": removed_total}


## More trees, clumped fallen leaves and half-buried rocks, merged with what is there.
func _add_forest(terrain: Terrain3D) -> Dictionary:
	var generator: ForestPathVegetationGenerator = Generator.new()
	generator.zone = ZONE
	generator.exclusions = EXCLUSIONS.duplicate()
	generator.seed_value = 20261017
	generator.clear_existing = false
	generator.paint_ground_textures = false
	generator.max_path_distance = 30.0
	generator.existing_tree_ids = TREE_IDS.duplicate()
	generator.view_corridors = [{
		"origin": OVERLOOK_ORIGIN,
		"direction": OVERLOOK_DIRECTION.normalized(),
		"half_angle": 38.0,
		"length": 70.0,
	}]
	generator.layer_override = [
		{
			"name": "extra canopy trees", "tall": true,
			"ids": [ForestPathVegetationGenerator.TREE_A, ForestPathVegetationGenerator.TREE_B],
			"d_min": 2.4, "d_max": 28.0, "density": 1.5, "taper": 0.85,
			"scale": Vector2(0.8, 1.3), "align": 0.0, "clump": 0.5, "radius": 0.5,
			"spacing": 3.0, "tilt": 3.0, "max_slope": 40.0, "sink": -0.15,
		},
		{
			"name": "extra shrub trees", "tall": true,
			"ids": [ForestPathVegetationGenerator.PITANGUEIRA],
			"d_min": 3.0, "d_max": 26.0, "density": 0.3, "taper": 0.85,
			"scale": Vector2(0.6, 0.95), "align": 0.0, "clump": 0.5, "radius": 3.2,
			"spacing": 3.8, "max_slope": 40.0,
		},
		{
			"name": "extra araucarias", "tall": true,
			"ids": [ForestPathVegetationGenerator.ARAUCARIA],
			"d_min": 8.0, "d_max": 30.0, "density": 0.004, "taper": 0.5,
			"scale": Vector2(0.9, 1.3), "align": 0.0, "clump": 0.3, "radius": 0.6,
			"spacing": 9.0, "max_slope": 35.0, "sink": -0.2,
		},
		{
			"name": "clumped fallen leaves",
			"ids": [ForestPathVegetationGenerator.LITTER],
			"d_min": 1.0, "d_max": 14.0, "density": 0.7, "taper": 0.5,
			"scale": Vector2(0.22, 0.5), "align": 1.0, "clump": 1.0, "radius": 0.1,
			"keep_size": true, "sink": -0.02,
		},
		{
			"name": "half-buried rocks",
			"ids": [ForestPathVegetationGenerator.ROCK_A, ForestPathVegetationGenerator.ROCK_B],
			"d_min": 2.0, "d_max": 18.0, "density": 0.045, "taper": 0.4,
			"scale": Vector2(0.5, 1.4), "scale_bias": 1.8, "align": 1.0, "clump": 0.9, "radius": 0.2,
			"keep_size": true, "sink": -0.12,
		},
	]
	var result: Dictionary = generator.generate(terrain)
	print("REJECTED: ", generator.rejected)
	return result
