extends SceneTree

const SaveManagerScript := preload(
	"res://scripts/save/save_manager.gd"
)
const TEST_SAVE_DIRECTORY := (
	"res://.godot/codex_save_system_smoke"
)
const TEST_SLOT := 2


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var manager: Node = SaveManagerScript.new()
	manager.set("save_directory", TEST_SAVE_DIRECTORY)
	root.add_child(manager)

	_expect_ok(
		int(manager.call("delete_slot", TEST_SLOT)),
		"cleaning the test slot"
	)
	_expect_ok(
		int(manager.call(
			"create_new_game",
			TEST_SLOT,
			"res://scenes/cinematics/dream_intro.tscn",
			"dream_intro_start",
			"SAVE_LOCATION_DREAM_INTRO"
		)),
		"creating a new game"
	)

	var summary: Dictionary = manager.call(
		"get_slot_summary",
		TEST_SLOT
	)
	_expect(
		bool(summary.get("exists", false))
		and bool(summary.get("valid", false)),
		"the new slot should be valid"
	)

	_expect_ok(
		int(manager.call(
			"set_state_value",
			&"puzzles",
			&"test_generator",
			true
		)),
		"setting persistent puzzle state"
	)
	_expect_ok(
		int(manager.call(
			"save_checkpoint",
			"res://scenes/cinematics/dream_intro.tscn",
			"dream_intro_test_checkpoint",
			"SAVE_LOCATION_DREAM_INTRO",
			{"triggers": {"test_door": "opened"}}
		)),
		"saving a checkpoint"
	)
	var manual_player_state := {
		"position": [1.0, 2.0, 3.0],
		"inventory": [],
	}
	_expect_ok(
		int(manager.call(
			"save_manual_game",
			"res://scenes/cinematics/dream_intro.tscn",
			manual_player_state
		)),
		"saving a manual snapshot"
	)
	var restored_manual_state: Dictionary = manager.call(
		"get_manual_player_state",
		"res://scenes/cinematics/dream_intro.tscn"
	)
	_expect(
		restored_manual_state == manual_player_state,
		"the manual player snapshot should round-trip"
	)

	manager.call("suspend_session", false)
	var loaded_data: Dictionary = manager.call("load_slot", TEST_SLOT)
	_expect(not loaded_data.is_empty(), "the test slot should load")
	_expect(
		str(loaded_data.get("checkpoint_id", ""))
		== "dream_intro_test_checkpoint",
		"the checkpoint ID should round-trip"
	)
	_expect(
		bool(manager.call(
			"get_state_value",
			&"puzzles",
			&"test_generator",
			false
		)),
		"the puzzle state should round-trip"
	)
	_expect(
		str(manager.call(
			"get_state_value",
			&"triggers",
			&"test_door",
			""
		)) == "opened",
		"the checkpoint state patch should round-trip"
	)

	_expect_ok(
		int(manager.call("delete_slot", TEST_SLOT)),
		"deleting the test slot"
	)
	summary = manager.call("get_slot_summary", TEST_SLOT)
	_expect(
		not bool(summary.get("exists", true)),
		"the deleted slot should be empty"
	)

	print("SaveManager smoke test passed.")
	manager.queue_free()
	quit(0)


func _expect_ok(result: int, operation: String) -> void:
	_expect(
		result == OK,
		"%s failed with %s" % [operation, error_string(result)]
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	push_error("SaveManager smoke test: " + message)
	quit(1)
