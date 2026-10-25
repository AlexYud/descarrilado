extends Node

## Nothing planted with the Terrain3D instancer floats: every plant, rock and leaf of the dream intro's terrain stands on
## the ground (within a hand's breadth) where it is. The far-tree stands (mesh ids from `FIRST_STAND_ID`, huge merged
## meshes whose origin is not on the ground) are not plants and are left out. After sculpting the ground (the overlook
## plaza was levelled after its foliage was planted), run `scripts/tools/snap_vegetation.tscn -- --apply`.
##
## The dead leaves (mesh id 5) are flat sheets about three metres across: planted level on a slope, one side of a sheet hung in the air like a plate laid
## on the ground. They are checked by their real leaves: the highest flat leaf of a sheet is no more than `MAX_LEAF_FLOAT` over the ground under it (they were
## tipped to the ground by `scripts/tools/align_ground_leaves.tscn -- --apply`).

const SCENE_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const FIRST_STAND_ID: int = 25
const MAX_FLOAT: float = 0.1
const LEAF_ID: int = 5
const LEAF_BASE_HEIGHT: float = 0.06
const MAX_LEAF_FLOAT: float = 0.04

var test_failed: bool = false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


func _ready() -> void:
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var terrain: Terrain3D = scene.get_node_or_null("Terrain3D") as Terrain3D
	_expect(terrain != null, "the dream intro has its terrain")
	if terrain == null:
		get_tree().quit(1)
		return

	var region_size: float = float(terrain.region_size) * terrain.vertex_spacing
	var leaf_base: PackedVector3Array = PackedVector3Array()
	for vertex: Vector3 in terrain.assets.get_mesh_asset(LEAF_ID).get_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		if vertex.y < LEAF_BASE_HEIGHT:
			leaf_base.append(vertex)

	var sheets: int = 0
	var hanging: int = 0
	var worst_sheet: float = 0.0
	var checked: int = 0
	var floating: int = 0
	var worst: float = 0.0
	var worst_at: Vector3 = Vector3.ZERO
	for region: Terrain3DRegion in terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in instances.keys():
			if mesh_id >= FIRST_STAND_ID:
				continue

			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				for transform: Transform3D in cells[cell][0]:
					var world: Vector3 = Vector3(transform.origin.x + offset.x, 0.0, transform.origin.z + offset.y)
					var gap: float = transform.origin.y - terrain.data.get_height(world)
					if is_nan(gap):
						continue

					if mesh_id == LEAF_ID:
						var highest: float = -INF
						for vertex: Vector3 in leaf_base:
							var point: Vector3 = transform * vertex
							var under: float = terrain.data.get_height(Vector3(point.x + offset.x, 0.0, point.z + offset.y))
							if not is_nan(under):
								highest = maxf(highest, point.y - under)

						sheets += 1
						worst_sheet = maxf(worst_sheet, highest)
						if highest > MAX_LEAF_FLOAT:
							hanging += 1

					checked += 1
					if gap > MAX_FLOAT:
						floating += 1
						if gap > worst:
							worst = gap
							worst_at = world

	_expect(checked > 50000, "plants were checked (%d)" % checked)
	_expect(floating == 0, "none of them floats above the ground (%d do, the worst %.2f m at %s)" % [floating, worst, str(worst_at)])
	_expect(sheets > 5000 and leaf_base.size() > 20, "the dead leaves were checked (%d sheets, %d flat leaves each)" % [sheets, leaf_base.size()])
	_expect(hanging == 0, "no sheet of leaves hangs over the ground (%d do; the highest leaf of any is %.3f m over it)" % [hanging, worst_sheet])
	print("VEGETATION_GROUNDED_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)
