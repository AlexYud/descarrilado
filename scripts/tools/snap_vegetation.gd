extends Node

## One-off terrain edit, run as a scene in a real window: `Godot --path . res://scripts/tools/snap_vegetation.tscn`
## prints, per mesh id, how far the instances float above (or sink into) the terrain; add `-- --apply` to put
## every instance that floats back on the ground (nothing is moved sideways, nothing is added or removed).

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
## An instance higher than this over the terrain floats and is put back on it (a little sinking is the look of
## half-buried rocks and trunks, and is left alone).
## Mesh ids from this one up are the merged far-tree stands, whose origin is not on the ground: left alone.
const MAX_PLANT_ID: int = 25
const FLOAT_TOLERANCE: float = 0.05


func _ready() -> void:
	var apply: bool = OS.get_cmdline_user_args().has("--apply")
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	var terrain: Terrain3D = scene.get_node("Terrain3D") as Terrain3D
	var instancer: Terrain3DInstancer = terrain.get_instancer()
	var region_size: float = float(terrain.region_size) * terrain.vertex_spacing
	var stats: Dictionary = {}
	var fixed_total: int = 0
	for id: int in terrain.assets.get_mesh_count():
		var asset: Terrain3DMeshAsset = terrain.assets.get_mesh_asset(id)
		var mesh: Mesh = asset.get_mesh() if asset != null else null
		if mesh != null:
			print("ASSET %d bottom %.2f top %.2f width %.2f" % [id, mesh.get_aabb().position.y, mesh.get_aabb().end.y, mesh.get_aabb().size.x])

	for region: Terrain3DRegion in terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in instances.keys():
			var transforms: Array[Transform3D] = []
			var colors: PackedColorArray = PackedColorArray()
			var changed: bool = false
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in cell_transforms.size():
					var transform: Transform3D = cell_transforms[i]
					var ground: float = terrain.data.get_height(Vector3(transform.origin.x + offset.x, 0.0, transform.origin.z + offset.y))
					var gap: float = transform.origin.y - ground
					if not is_nan(gap):
						if not stats.has(mesh_id):
							stats[mesh_id] = []
						(stats[mesh_id] as Array).append(gap)
						if apply and gap > FLOAT_TOLERANCE and int(mesh_id) < MAX_PLANT_ID:
							transform.origin.y = ground
							changed = true
							fixed_total += 1

					transforms.append(transform)
					colors.append(cell_colors[i] if i < cell_colors.size() else Color.WHITE)

			if apply and changed:
				instancer.clear_by_region(region, mesh_id)
				instancer.append_region(region, mesh_id, transforms, colors, true)

	var keys: Array = stats.keys()
	keys.sort()
	for key: Variant in keys:
		var gaps: Array = stats[key]
		gaps.sort()
		var above_tolerance: int = 0
		for gap: float in gaps:
			if gap > FLOAT_TOLERANCE:
				above_tolerance += 1

		print("MESH %d: n=%d min=%.2f median=%.2f p90=%.2f max=%.2f floating(>%.2f)=%d" % [
			int(key), gaps.size(), gaps[0], gaps[gaps.size() / 2], gaps[int(gaps.size() * 0.9)], gaps[gaps.size() - 1], FLOAT_TOLERANCE, above_tolerance])

	if apply:
		print("FIXED ", fixed_total)
		terrain.data.save_directory(TERRAIN_DIRECTORY)
		print("SAVED terrain data")

	get_tree().quit()
