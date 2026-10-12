extends Node

## One-off migration, run as a scene (it needs a real window for the plant
## instancer): `Godot --path . res://scenes/tools/...` or a scene with this script.
## Replaces the long loop of the south path between the unfinished house and the
## overlook with a short curve (see path_shortcut_builder.gd), regrows the forest,
## rebuilds the invisible walls and saves the terrain data and the walls.
##
## Run it once from a clean start (the terrain as it was before).

const Builder := preload("res://scripts/tools/path_shortcut_builder.gd")

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
const BOUNDARIES_SCENE_PATH: String = "res://scenes/environment/forest_boundaries.tscn"


func _ready() -> void:
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	var terrain: Terrain3D = scene.get_node("Terrain3D") as Terrain3D

	var builder = Builder.new()
	var result: Dictionary = builder.build(terrain)
	print(
		"SHORTCUT old loop cells %d, new path %.1f m from %s, painted %d, plants removed %d added %d"
		% [
			int(result.get("old_cells", 0)), float(result.get("length", 0.0)),
			str(result.get("start", Vector2.ZERO)), int(result.get("painted", 0)),
			int(result.get("removed", 0)), int(result.get("added", 0)),
		]
	)

	if int(result.get("old_cells", 0)) > 0:
		var walls: Dictionary = result["boundaries"]
		var saved: Error = ResourceSaver.save(walls["scene"], BOUNDARIES_SCENE_PATH)
		terrain.data.save_directory(TERRAIN_DIRECTORY)
		print("SAVED walls ", error_string(saved), " runs ", walls["segments"], " faces ", walls["faces"])

	get_tree().quit()
