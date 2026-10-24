extends Node

## The forest footsteps play only on the Terrain3D ground of the dream intro: the wagon, the unfinished house, the signal
## tower, the waiting shed and the railway's track bed keep the default sound. Run it as a scene; it quits by itself with a
## non-zero exit code on failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_footstep_surface_smoke"

var test_failed: bool = false
var level: Node = null
var player: CharacterBody3D = null
var audio: PlayerAudioController = null
var terrain: Terrain3D = null


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "footstep_surface_start", "SAVE_LOCATION_DREAM_INTRO")
	level = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	for i: int in 6:
		await get_tree().physics_frame

	player = level.get_node("Player")
	audio = player.audio_controller
	terrain = level.get_node("Terrain3D") as Terrain3D
	await _run()

	SaveManager.delete_slot(1)
	print("FOOTSTEP_SURFACE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _stand_at(x: float, z: float, y_over_ground: float = 1.1) -> void:
	var ground: float = terrain.data.get_height(Vector3(x, 0.0, z))
	player.global_position = Vector3(x, ground + y_over_ground, z)
	player.velocity = Vector3.ZERO
	for i: int in 8:
		await get_tree().physics_frame


func _stand_in(node: Node3D, local: Vector3) -> void:
	player.global_position = node.to_global(local)
	player.velocity = Vector3.ZERO
	for i: int in 8:
		await get_tree().physics_frame


func _step_stream() -> AudioStream:
	audio.trigger_footstep(false)
	return audio.sfx_walk.stream


func _run() -> void:
	var default_stream: AudioStream = audio.sfx_walk.stream
	_expect(audio._forest_steps.size() == PlayerAudioController.FOREST_STEPS.size() and audio._forest_steps.size() >= 12, "the forest steps are all loaded (%d)" % audio._forest_steps.size())

	# The wagon's floor (where the dream starts).
	var wagon: Node3D = level.get_node("Train/Wagons/TrainWagon")
	await _stand_in(wagon, Vector3(0.0, 1.1, 0.0))
	_expect(not audio.is_standing_on_forest() and _step_stream() == default_stream, "inside the wagon the steps are the default sound")

	# The railway: the track bed is Terrain3D ground, but a zone makes it the default sound.
	await _stand_at(0.0, 20.0)
	_expect(audio.is_standing_on_forest() == false and _step_stream() == default_stream, "on the railway's track bed the steps are the default sound")
	await _stand_at(-1.9, -30.0)
	_expect(not audio.is_standing_on_forest(), "the whole length of the track bed is default")

	# The forest floor beside the railway.
	await _stand_at(6.0, 20.0)
	_expect(audio.is_standing_on_forest(), "just beside the railway, on the forest ground, it is the forest")
	var seen: Dictionary = {}
	var previous: AudioStream = null
	var repeats: int = 0
	for i: int in 40:
		var stream: AudioStream = _step_stream()
		seen[stream] = true
		if stream == previous:
			repeats += 1

		previous = stream
		_expect(stream != default_stream and audio.on_forest_ground, "step %d is a forest step" % i) if stream == default_stream else null

	_expect(seen.size() >= 10 and repeats == 0, "forty forest steps use many different recordings (%d), never the same twice in a row" % seen.size())

	# Back on a floor: the default again.
	var house: Node3D = level.get_node("Scenery/UnfinishedHouse")
	await _stand_in(house, Vector3(5.0, 1.05, 12.0))
	_expect(not audio.is_standing_on_forest() and _step_stream() == default_stream, "inside the unfinished house (its floor) the steps are the default sound")
	var tower: Node3D = level.get_node("Scenery/SignalTower")
	await _stand_in(tower, Vector3(0.0, 1.1, 0.0))
	_expect(not audio.is_standing_on_forest() and _step_stream() == default_stream, "inside the signal tower (its floor) the steps are the default sound")
	var shed: Node3D = level.get_node("Scenery/WaitingShed")
	for spot: Vector3 in [Vector3(-3.0, 1.1, -5.5), Vector3(1.0, 1.1, -2.0), Vector3(6.0, 1.1, 10.0), Vector3(6.0, 1.1, -18.0)]:
		await _stand_in(shed, spot)
		_expect(not audio.is_standing_on_forest() and _step_stream() == default_stream, "at the waiting shed (%s) the steps are the default sound" % str(spot))

	await _stand_in(shed, Vector3(-3.0, 1.1, 12.0))
	_expect(audio.is_standing_on_forest(), "but a little way off the shed, on the forest ground, it is the forest")

	await _stand_at(6.0, 20.0)
	_expect(audio.is_standing_on_forest(), "and back out on the forest ground it is the forest again")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
