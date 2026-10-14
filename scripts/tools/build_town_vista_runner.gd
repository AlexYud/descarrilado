extends Node

## Bakes the town vista (see TownVistaBuilder). Run the scene next to it:
##   godot --headless --path . res://scripts/tools/build_town_vista.tscn -- terrain
## shapes the Terrain3D of the dream intro (cliff, valley, mountains), paints the forest as
## Terrain3D instances and saves only the regions that changed. The scene step needs a renderer
## (a MultiMesh saved headless loses its transforms), so run it in a window:
##   godot --path . res://scripts/tools/build_town_vista.tscn -- scene
## `-- assets` builds the far forest's stand meshes first (VistaForestAssets). Pass `-- check` to only measure the saved terrain, forest and visibility.

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("assets"):
		VistaForestAssets.new().build()
		get_tree().quit()
		return

	var do_terrain: bool = args.has("terrain")
	var do_scene: bool = args.has("scene")
	var builder: TownVistaBuilder = TownVistaBuilder.new()

	var terrain: Terrain3D = Terrain3D.new()
	terrain.data_directory = TownVistaBuilder.TERRAIN_DIRECTORY
	builder.load_assets(terrain)
	add_child(terrain)
	await get_tree().process_frame

	var started: int = Time.get_ticks_msec()
	var town: TownBlockout = builder.make_town()
	add_child(town)
	await get_tree().process_frame
	print("town built in ", Time.get_ticks_msec() - started, " ms: scenery houses ", town._scenery.house_count)

	if do_terrain:
		started = Time.get_ticks_msec()
		builder.bake_terrain(terrain, town)
		print("terrain baked in ", Time.get_ticks_msec() - started, " ms: ", builder.stats)

	builder.check_visibility(terrain, town)
	builder.check_match(terrain, town)
	builder.check_trees(terrain)

	if do_scene:
		var result: Error = builder.bake_scene(town, TownVistaBuilder.SCENE_PATH)
		print("scene saved: ", error_string(result), " (", TownVistaBuilder.SCENE_PATH, ")")

	get_tree().quit()
