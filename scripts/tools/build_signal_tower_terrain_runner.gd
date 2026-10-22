extends Node

## Headless runner for SignalTowerTerrainBuilder:
##   godot --headless --path . res://scripts/tools/build_signal_tower_terrain_runner.tscn
## Loads the dream intro, runs the builder on its Terrain3D, saves the forest walls and only the terrain regions
## that changed, and prints where the tower stands (put the `Scenery/SignalTower` instance there). Run it once.

const SCENE_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const BOUNDARIES_SCENE_PATH: String = "res://scenes/environment/forest_boundaries.tscn"


func _ready() -> void:
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var terrain: Terrain3D = scene.get_node("Terrain3D") as Terrain3D
	var builder: SignalTowerTerrainBuilder = SignalTowerTerrainBuilder.new()
	var started: int = Time.get_ticks_msec()
	var old_walls: PackedScene = load(BOUNDARIES_SCENE_PATH) as PackedScene
	var old_faces: PackedVector3Array = builder.faces_of(old_walls)
	var result: Dictionary = builder.build(terrain)
	# Only the tower's neighbourhood of the walls changes (see SignalTowerTerrainBuilder.splice_walls).
	var splice: Dictionary = {}
	var spliced: PackedScene = builder.splice_walls(old_faces, builder.ring_faces(), splice)
	var wall_error: Error = ResourceSaver.save(spliced, BOUNDARIES_SCENE_PATH)
	print("SIGNAL_TOWER_WALLS: ", splice, " (old ", old_faces.size() / 3, " triangles)")
	terrain.data.save_directory(terrain.data_directory)
	print(
		"SIGNAL_TOWER_TERRAIN: level height %.3f at pad centre %s, %d cells painted, %d forest plants removed, %d re-seated, %d floor plants, walls %s (%d triangles of the ring spliced in), %d ms"
		% [float(result["height"]), str(builder.center), int(result["painted"]), int(result["removed"]), int(result["reseated"]), int(result["floor_plants"]), error_string(wall_error), int(splice["added"]), Time.get_ticks_msec() - started]
	)
	print("SIGNAL_TOWER_AT: ", builder.tower_origin, " height ", result["height"], " yaw ", builder.tower_yaw_degrees)
	get_tree().quit()
