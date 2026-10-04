@tool
extends EditorScript

## Run from the Script Editor with File > Run (Ctrl+Shift+X) while the dream
## intro scene is open. It rebuilds scenes/environment/forest_boundaries.tscn:
## invisible walls around the painted paths and the overlook plaza, so the
## player stays on the trail. Rerun after repainting paths; the scene is
## instanced at the origin under Scenery/ForestBoundaries.

const Builder := preload("res://scripts/tools/forest_boundary_builder.gd")

const TERRAIN_NODE_NAME: String = "Terrain3D"
const SCENE_PATH: String = "res://scenes/environment/forest_boundaries.tscn"


func _run() -> void:
	var scene_root: Node = get_scene()
	if scene_root == null:
		push_error("Open the dream intro scene before running this script.")
		return

	var terrain: Terrain3D = scene_root.get_node_or_null(
		TERRAIN_NODE_NAME
	) as Terrain3D
	if terrain == null:
		push_error("No Terrain3D node named '%s' in the open scene." % TERRAIN_NODE_NAME)
		return

	var builder = Builder.new()
	var result: Dictionary = builder.build(terrain)
	var error: Error = ResourceSaver.save(result["scene"], SCENE_PATH)
	print(
		"Forest boundaries: %d wall runs, %d triangles, saved with result %s."
		% [int(result["segments"]), int(result["faces"]), error_string(error)]
	)
