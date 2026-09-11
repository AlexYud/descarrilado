extends Node

const TEST_SAVE_DIRECTORY := (
	"res://.godot/codex_dream_manual_resume_smoke"
)
const DREAM_SCENE_PATH := (
	"res://scenes/cinematics/dream_intro.tscn"
)
const TEST_POSITION := Vector3(1.243, 1.14, 2.789)

var test_failed: bool = false


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	_expect_ok(SaveManager.delete_slot(1), "cleaning the dream test slot")
	_expect_ok(
		SaveManager.create_new_game(
			1,
			DREAM_SCENE_PATH,
			"dream_intro_start",
			"SAVE_LOCATION_DREAM_INTRO"
		),
		"creating the dream test game"
	)
	_expect_ok(
		SaveManager.save_manual_game(
			DREAM_SCENE_PATH,
			{
				"position": [
					TEST_POSITION.x,
					TEST_POSITION.y,
					TEST_POSITION.z,
				],
				"rotation": [0.0, 0.0, 0.0],
				"movement": {
					"look_yaw": 8.0,
					"look_pitch": 3.0,
					"is_crouching": false,
				},
				"inventory": [],
				"flashlight": {"is_on": false},
			}
		),
		"saving the dream player snapshot"
	)

	# Keep this runner alive while replacing the test's current scene.
	SceneTransition.fade_from_black_duration = 0.05
	SceneTransition.black_hold_duration = 0.0
	SceneTransition.scene_ready_frame_delay = 1
	SceneTransition.cover_next_scene()
	_expect(
		SceneTransition.is_cover_visible(),
		"the persistent transition should cover the outgoing scene"
	)
	get_tree().current_scene = null
	var change_result: Error = get_tree().change_scene_to_file(
		DREAM_SCENE_PATH
	)
	_expect_ok(change_result, "loading the saved Dream Intro scene")
	await get_tree().scene_changed
	_expect(
		SceneTransition.is_cover_visible(),
		"the transition should remain black while the saved scene initializes"
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var dream_scene: Node = get_tree().current_scene
	var player: CharacterBody3D = dream_scene.get_node("Player")
	var blackout: ColorRect = dream_scene.get_node(
		"TransitionBlackout/BlackoutRect"
	)
	var horizontal_position := Vector2(
		player.global_position.x,
		player.global_position.z
	)
	var expected_horizontal_position := Vector2(
		TEST_POSITION.x,
		TEST_POSITION.z
	)
	_expect(
		horizontal_position.distance_to(expected_horizontal_position) < 0.05
		and absf(player.global_position.y - TEST_POSITION.y) < 0.15,
		"Dream Intro should preserve the manual-save position, allowing "
		+ "minor CharacterBody3D floor settling (expected %s, received %s)"
		% [TEST_POSITION, player.global_position]
	)
	_expect(
		not bool(player.get("cutscene_frozen")),
		"Dream Intro should restore player control"
	)
	_expect(
		not blackout.visible,
		"Dream Intro should not replay its opening blackout"
	)

	for _frame_index: int in range(60):
		if not SceneTransition.is_cover_visible():
			break
		await get_tree().process_frame
	_expect(
		not SceneTransition.is_cover_visible(),
		"the transition should fade away after the restored scene is ready"
	)

	_expect_ok(SaveManager.delete_slot(1), "deleting the dream test slot")
	SaveManager.suspend_session(false)
	if test_failed:
		get_tree().quit(1)
	else:
		print("Dream manual resume smoke test passed.")
		get_tree().quit(0)


func _expect_ok(result: int, operation: String) -> void:
	_expect(
		result == OK,
		"%s failed with %s" % [operation, error_string(result)]
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	test_failed = true
	push_error("Dream manual resume smoke test: " + message)
