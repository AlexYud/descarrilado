@tool
extends EditorScript

## Run from the Script Editor with File > Run (Ctrl+Shift+X) while the dream
## intro scene is open. It paints the dirt that links the path ends to the
## overlook plaza, levels the ground for the bench and fence (blending out
## gradually), then rebuilds scenes/environment/overlook.tscn (fence and
## bench). Run generate_forest_vegetation.gd afterwards so plants avoid the new
## dirt, then save the scene (Ctrl+S).
##
## Change the position, view direction or path ends on the builder below.

const Builder := preload("res://scripts/tools/overlook_builder.gd")

const TERRAIN_NODE_NAME: String = "Terrain3D"
const SCENE_PATH: String = "res://scenes/environment/overlook.tscn"


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
	var painted: int = builder.paint_paths(terrain)
	builder.flatten_ground(terrain)
	var result: Error = builder.build_scene(terrain, SCENE_PATH)
	print(
		"Overlook: painted %d cells, scene saved with result %s. Save the scene (Ctrl+S)."
		% [painted, error_string(result)]
	)
