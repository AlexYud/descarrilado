@tool
extends EditorScript

## Run from the Script Editor with File > Run (Ctrl+Shift+X) while the dream
## intro scene is open. It levels, paints and plants the ground for the fig tree
## clearing on the top of the northern path loop, regrows the forest around it
## and rebuilds the invisible path walls (scenes/environment/forest_boundaries.tscn).
## Then save the scene (Ctrl+S) to store the terrain changes.
##
## Run it once. Levelling is not additive (it targets an average height), but
## the vegetation inside the area is replaced every time. Position and size are
## on the builder (scripts/tools/fig_clearing_terrain_builder.gd).

const Builder := preload("res://scripts/tools/fig_clearing_terrain_builder.gd")

const TERRAIN_NODE_NAME: String = "Terrain3D"
const BOUNDARIES_SCENE_PATH: String = "res://scenes/environment/forest_boundaries.tscn"
const CLEARING_NODE_PATH: NodePath = ^"Scenery/FigClearing"


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
	var walls: Dictionary = result["boundaries"]
	var error: Error = ResourceSaver.save(walls["scene"], BOUNDARIES_SCENE_PATH)
	print(
		"Fig clearing: level height %.2f, %d cells painted, forest plants %d removed / %d added, %d floor plants, walls saved with result %s. Save the scene (Ctrl+S)."
		% [
			float(result["height"]),
			int(result["painted"]),
			int(result["removed"]),
			int(result["added"]),
			int(result["floor_plants"]),
			error_string(error),
		]
	)

	# The clearing's origin is its ground level: put the instance on the floor
	# that was just levelled, or every prop sinks into it or hovers above it.
	var clearing: Node3D = scene_root.get_node_or_null(CLEARING_NODE_PATH) as Node3D
	if clearing != null:
		clearing.position.y = float(result["height"])
		print("Fig clearing instance placed at y = %.3f." % clearing.position.y)
