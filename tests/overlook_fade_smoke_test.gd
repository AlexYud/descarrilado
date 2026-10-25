extends Node

## The approach to the overlook must not show the forest being built in front of the player. Two things make sure of it: the plants and trees of the terrain
## fade out over a margin instead of being cut off at their range (and the trees and rocks reach further), and the fog's reach (its depth and the camera's far
## plane) stays the forest's own, so that nothing can be seen past the point where the plants end, until the player is close to the overlook (see
## `HorrorNightEnvironment.vista_reach_distance`); then it opens, as the light and the mist's colour have been doing all along. Run it as a scene; it quits by
## itself with a non-zero exit code on failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_overlook_fade_smoke"
## The terrain's mesh ids that are the forest's (the tent, the campfire and the bench, 15, 16 and 19, are scenery; from 21 up are the far stands).
const TREES: Array[int] = [1, 2, 3, 14]
const BIG: Array[int] = [0, 4]
const ROCKS: Array[int] = [17, 18]
const SMALL: Array[int] = [5, 7, 11, 12, 13]
const FOREST: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 17, 18, 20]

var test_failed: bool = false


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	GameSettings.set_quality_preset(3, false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "forest_map_start", "SAVE_LOCATION_DREAM_INTRO")
	var level: Node = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	for i: int in 20:
		await get_tree().physics_frame

	for node: Node in level.find_children("*", "", true, false) + [level]:
		if node.has_method("skip_opening"):
			node.call("skip_opening")
			break

	await _check_the_assets(level.get_node("Terrain3D") as Terrain3D)
	await _check_the_reach(level)
	SaveManager.delete_slot(1)
	print("OVERLOOK_FADE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _check_the_assets(terrain: Terrain3D) -> void:
	var all_fade: bool = true
	var which: String = ""
	for id: int in FOREST:
		var asset: Terrain3DMeshAsset = terrain.assets.get_mesh_asset(id)
		var fine: bool = asset != null and asset.fade_margin >= 8.0 and asset.fade_margin <= asset.get_lod0_range() * 0.25 + 0.001
		all_fade = all_fade and fine
		if not fine:
			which += " %d(%s: margin %.1f, range %.1f)" % [id, asset.name if asset != null else "none", asset.fade_margin if asset != null else -1.0, asset.get_lod0_range() if asset != null else -1.0]
	_expect(all_fade, "every plant, tree and rock of the forest fades out over a margin (8 m or more, and not more than a quarter of its range) and is not cut off (not so:%s)" % which)
	var trees_reach: bool = true
	for id: int in TREES:
		trees_reach = trees_reach and terrain.assets.get_mesh_asset(id).get_lod0_range() >= 190.0
	_expect(trees_reach, "the trees can be seen to 190 m")
	var big_reach: bool = true
	for id: int in BIG:
		big_reach = big_reach and terrain.assets.get_mesh_asset(id).get_lod0_range() >= 128.0
	_expect(big_reach, "the big foliage to 128 m")
	var rocks_reach: bool = true
	for id: int in ROCKS:
		rocks_reach = rocks_reach and terrain.assets.get_mesh_asset(id).get_lod0_range() >= 160.0
	_expect(rocks_reach, "the rocks to 160 m")
	var small_short: bool = true
	for id: int in SMALL:
		small_short = small_short and terrain.assets.get_mesh_asset(id).get_lod0_range() <= 48.0
	_expect(small_short, "while the small cover stays short (48 m): it is dark and low out there, and it is what costs the draws")
	await get_tree().process_frame


func _check_the_reach(level: Node) -> void:
	var player: CharacterBody3D = level.get_node("Player")
	player.cutscene_frozen = false
	player.movement_controller.end_cutscene_camera_control()
	var env_node: Node = level.get_node("WorldEnvironment")
	var focus: Node3D = level.get_node("OverlookVistaFocus") as Node3D
	var forest_end: float = float((env_node.get("_forest_fog") as Dictionary)["depth_end"])
	var forest_far: float = float((env_node.get("_forest_fog") as Dictionary)["camera_far"])
	var rows: Dictionary = {}
	for distance: float in [160.0, 110.0, 75.0, 50.0, 40.0, 14.0]:
		player.global_position = focus.global_position + Vector3(distance, 3.0, 0.0)
		player.velocity = Vector3.ZERO
		env_node.set("_vista_creep_ready", false)
		env_node.set("_reach_ready", false)
		await get_tree().create_timer(0.4).timeout
		var environment: Environment = env_node.get("environment")
		rows[distance] = {
			"end": environment.fog_depth_end, "begin": environment.fog_depth_begin, "far": get_viewport().get_camera_3d().far,
			"vista": float(env_node.get("_vista_smoothed")), "energy": environment.fog_light_energy,
		}

	for distance: float in [160.0, 110.0, 75.0, 50.0, 40.0]:
		var row: Dictionary = rows[distance]
		_expect(absf(float(row["end"]) - forest_end) < 1.0 and absf(float(row["far"]) - forest_far) < 1.0, "%.0f m from the overlook the fog and the camera are the forest's (fog ends at %.1f, sees %.1f)" % [distance, row["end"], row["far"]])

	_expect(float((rows[75.0] as Dictionary)["vista"]) > 0.2, "while the light has already started to change (%.2f of the way at 75 m)" % float((rows[75.0] as Dictionary)["vista"]))
	var open: Dictionary = rows[14.0]
	_expect(float(open["end"]) > 1000.0 and float(open["far"]) > 1400.0, "at the overlook the view is open (fog ends at %.0f m, the camera sees %.0f m)" % [open["end"], open["far"]])
	var env_reach: float = float(env_node.get("vista_reach_distance"))
	_expect(env_reach >= 30.0 and env_reach <= 60.0, "the reach opens in the last stretch (from %.0f m)" % env_reach)
	# A walk is gentle: from 40 m in to 14 m, in steps of two metres a few times a second, the reach does not jump (a teleport does, by design).
	env_node.set("_vista_creep_ready", false)
	env_node.set("_reach_ready", false)
	var at: float = 40.0
	while at > 14.0:
		player.global_position = focus.global_position + Vector3(at, 3.0, 0.0)
		await get_tree().create_timer(0.15).timeout
		at -= 2.0

	var environment_now: Environment = env_node.get("environment")
	_expect(environment_now.fog_depth_end < 200.0, "walking in, the reach opens gradually (on arrival at 14 m the fog ends at %.0f m, not at the full 1150)" % environment_now.fog_depth_end)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
