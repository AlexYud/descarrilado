extends Node

## One-off terrain edit, run as a scene in a real window (the plant instancer needs a renderer):
## `Godot --path . res://scripts/tools/rescale_big_foliage.tscn`. Scales every placed instance of the
## big foliage meshes (the bushes that make the tall "vegetation wall" along the paths) about its own
## base by `SCALE_FACTOR`, then saves the terrain data of the dream intro. Pass `--apply` after `--` to
## write the change; without it only the statistics are printed.
##
## Run it ONCE (a second run would shrink them again).

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
## Terrain3D mesh ids of big_foliage_02 and big_foliage_01.
const BIG_FOLIAGE_IDS: Array[int] = [0, 4]
const SCALE_FACTOR: float = 0.7


func _ready() -> void:
	var apply: bool = OS.get_cmdline_user_args().has("--apply")
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	var terrain: Terrain3D = scene.get_node("Terrain3D") as Terrain3D
	var instancer: Terrain3DInstancer = terrain.get_instancer()

	var count: int = 0
	var scale_sum: float = 0.0
	var scale_max: float = 0.0
	for region: Terrain3DRegion in terrain.data.get_regions_active():
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in BIG_FOLIAGE_IDS:
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
					var size: float = transform.basis.get_scale().y
					count += 1
					scale_sum += size
					scale_max = maxf(scale_max, size)
					transform.basis = transform.basis.scaled(Vector3.ONE * SCALE_FACTOR)
					transforms.append(transform)
					colors.append(cell_colors[i] if i < cell_colors.size() else Color.WHITE)

			if apply and not transforms.is_empty():
				instancer.clear_by_region(region, mesh_id)
				instancer.append_region(region, mesh_id, transforms, colors, true)

	print("BIG FOLIAGE: %d instances, mean scale %.2f, max %.2f, factor %.2f, apply %s" % [count, scale_sum / maxf(float(count), 1.0), scale_max, SCALE_FACTOR, str(apply)])
	if apply:
		terrain.data.save_directory(TERRAIN_DIRECTORY)
		print("SAVED terrain data")

	get_tree().quit()
