@tool
extends EditorScript

## Run from the Script Editor with File > Run (Ctrl+Shift+X) while the dream
## intro scene is open. It levels, paints and plants the ground for the
## unfinished house on the southern path, regrows the forest around it and
## rebuilds the invisible path walls (scenes/environment/forest_boundaries.tscn).
## Then save the scene (Ctrl+S) to store the terrain changes.
##
## Run it once. Levelling is not additive (it targets an average height), but the
## vegetation inside the zone is replaced every time. Position and size are on the
## builder (scripts/tools/house_terrain_builder.gd).

const Builder := preload("res://scripts/tools/house_terrain_builder.gd")

const TERRAIN_NODE_NAME: String = "Terrain3D"
const BOUNDARIES_SCENE_PATH: String = "res://scenes/environment/forest_boundaries.tscn"
const COLLIDERS_SCENE_PATH: String = "res://scenes/environment/house_forest_colliders.tscn"
const HOUSE_NODE_PATH: NodePath = ^"Scenery/UnfinishedHouse"
## The floor slab sits a hair above the level ground so it never z-fights.
const FLOOR_LIFT: float = 0.015


func _run() -> void:
	var scene_root: Node = get_scene()
	if scene_root == null:
		push_error("Open the dream intro scene before running this script.")
		return

	var terrain: Terrain3D = scene_root.get_node_or_null(TERRAIN_NODE_NAME) as Terrain3D
	if terrain == null:
		push_error("No Terrain3D node named '%s' in the open scene." % TERRAIN_NODE_NAME)
		return

	var builder = Builder.new()
	var result: Dictionary = builder.build(terrain)
	var walls: Dictionary = result["boundaries"]
	var error: Error = ResourceSaver.save(walls["scene"], BOUNDARIES_SCENE_PATH)
	var collider_error: Error = ResourceSaver.save(result["colliders_scene"], COLLIDERS_SCENE_PATH)
	print(
		"Unfinished house: level height %.2f, %d cells painted, forest plants %d removed / %d added, %d too close to the house removed, %d overgrowth plants, %d colliders (saved: %s), walls saved with result %s. Save the scene (Ctrl+S)."
		% [
			float(result["height"]),
			int(result["painted"]),
			int(result["removed"]),
			int(result["added"]),
			int(result["cleared_unsafe"]),
			int(result["overgrowth"]),
			int(result["colliders"]),
			error_string(collider_error),
			error_string(error),
		]
	)

	# Place the house instance on the ground that was just levelled.
	var house: Node3D = scene_root.get_node_or_null(HOUSE_NODE_PATH) as Node3D
	if house != null:
		house.position = Vector3(
			builder.origin.x, float(result["height"]) + FLOOR_LIFT, builder.origin.y
		)
		house.rotation_degrees = Vector3(0.0, -90.0, 0.0)
		print("House placed at %s." % str(house.position))
