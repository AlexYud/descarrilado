@tool
extends EditorScript

## Run from the Script Editor with File > Run (Ctrl+Shift+X) while the dream intro scene is open. It levels,
## paints and plants the ground for the ruined signal tower in the bowl east of the northern loop, clears the
## forest plants off its pad and trail, and splices a clean ring of invisible wall round it into
## scenes/environment/forest_boundaries.tscn (see SignalTowerTerrainBuilder). Then save the scene (Ctrl+S) to
## store the terrain changes. (`build_signal_tower_terrain_runner.tscn` does the same headless and saves the
## terrain regions itself.)
##
## Run it once, from a clean start: levelling targets an average height, the plants are added once and the old
## walls are read from the file. Position and size are on the builder (signal_tower_terrain_builder.gd).

const TERRAIN_NODE_NAME: String = "Terrain3D"
const BOUNDARIES_SCENE_PATH: String = "res://scenes/environment/forest_boundaries.tscn"
const TOWER_NODE_PATH: NodePath = ^"Scenery/SignalTower"


func _run() -> void:
	var scene_root: Node = get_scene()
	if scene_root == null:
		push_error("Open the dream intro scene before running this script.")
		return

	var terrain: Terrain3D = scene_root.get_node_or_null(TERRAIN_NODE_NAME) as Terrain3D
	if terrain == null:
		push_error("No Terrain3D node named '%s' in the open scene." % TERRAIN_NODE_NAME)
		return

	var builder: SignalTowerTerrainBuilder = SignalTowerTerrainBuilder.new()
	var old_faces: PackedVector3Array = builder.faces_of(load(BOUNDARIES_SCENE_PATH) as PackedScene)
	var result: Dictionary = builder.build(terrain)
	var splice: Dictionary = {}
	var spliced: PackedScene = builder.splice_walls(old_faces, builder.ring_faces(), splice)
	var error: Error = ResourceSaver.save(spliced, BOUNDARIES_SCENE_PATH)
	print(
		"Signal tower: level height %.2f, %d cells painted, %d forest plants removed, %d re-seated, %d floor plants, walls %s %s. Save the scene (Ctrl+S)."
		% [float(result["height"]), int(result["painted"]), int(result["removed"]), int(result["reseated"]), int(result["floor_plants"]), str(splice), error_string(error)]
	)

	# The tower's origin is its ground level: put the instance on the pad that was just levelled.
	var tower: Node3D = scene_root.get_node_or_null(TOWER_NODE_PATH) as Node3D
	if tower != null:
		tower.position = Vector3(builder.tower_origin.x, float(result["height"]), builder.tower_origin.y)
		print("Signal tower instance placed at %s." % str(tower.position))
