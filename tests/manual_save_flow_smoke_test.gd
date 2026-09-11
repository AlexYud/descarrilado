extends Node

const TEST_SAVE_DIRECTORY := (
	"res://.godot/codex_manual_save_flow_smoke"
)
const TEST_SCENE_PATH := (
	"res://tests/manual_save_flow_smoke_test.tscn"
)
const TEST_POSITION := Vector3(3.25, 1.5, -7.75)

var test_failed: bool = false


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	_expect_ok(SaveManager.delete_slot(1), "cleaning the manual test slot")
	_expect_ok(
		SaveManager.create_new_game(
			1,
			TEST_SCENE_PATH,
			"manual_test_start",
			"SAVE_LOCATION_DREAM_INTRO"
		),
		"creating the manual test game"
	)

	var player_scene: PackedScene = load(
		"res://scenes/player/player.tscn"
	)
	var player: CharacterBody3D = player_scene.instantiate()
	add_child(player)
	player.global_position = TEST_POSITION

	var movement: PlayerMovementController = player.get_node(
		"MovementController"
	)
	movement.restore_save_state({
		"look_yaw": 24.0,
		"look_pitch": -11.0,
		"is_crouching": true,
	})
	var flashlight: Node = player.get_node("Hand/SpotLight3D")
	flashlight.call("restore_save_state", {"is_on": true})

	var collectible_scene: PackedScene = load(
		"res://scenes/objects/cellphone.tscn"
	)
	var collectible: Collectible = collectible_scene.instantiate()
	add_child(collectible)
	collectible.interact(player)
	_expect(
		player.has_inventory_item("cellphone"),
		"collecting an item should update the inventory"
	)

	var drawer_scene: PackedScene = load(
		"res://scenes/objects/drawer_interactable.tscn"
	)
	var drawer: DrawerInteractable = drawer_scene.instantiate()
	drawer.persistent_id = &"manual_test_drawer"
	add_child(drawer)
	drawer.interact(player)
	_expect(drawer.is_open, "the test drawer should be open")

	var door_scene: PackedScene = load(
		"res://scenes/objects/door_interactable.tscn"
	)
	var door: DoorController = door_scene.instantiate()
	door.persistent_id = &"manual_test_door"
	add_child(door)
	door.interact(player)
	_expect(door.is_open, "the test door should be open")

	var pause_menu: PauseMenuController = player.get_node("PauseMenu")
	pause_menu.open_pause_menu()
	var save_button: Button = pause_menu.get_node(
		"PauseRoot/MenuCenter/PauseWindow/PauseMargin/"
		+ "PauseVBox/SaveButton"
	)
	var status_label: Label = pause_menu.get_node(
		"PauseRoot/MenuCenter/PauseWindow/PauseMargin/"
		+ "PauseVBox/SaveStatusLabel"
	)
	_expect(not save_button.disabled, "manual saving should be available")
	save_button.pressed.emit()
	_expect(status_label.visible, "saving should show confirmation")
	pause_menu.resume_game()

	var saved_player_state: Dictionary = (
		SaveManager.get_manual_player_state(TEST_SCENE_PATH)
	)
	_expect(
		not saved_player_state.is_empty(),
		"the pause menu should persist a player snapshot"
	)

	player.queue_free()
	drawer.queue_free()
	door.queue_free()
	await get_tree().process_frame

	var restored_player: CharacterBody3D = player_scene.instantiate()
	add_child(restored_player)
	await get_tree().process_frame
	_expect(
		restored_player.global_position.distance_to(TEST_POSITION) < 0.05,
		"the player position should be restored"
	)
	_expect(
		restored_player.has_inventory_item("cellphone"),
		"the player inventory should be restored"
	)
	var restored_movement: PlayerMovementController = (
		restored_player.get_node("MovementController")
	)
	_expect(
		is_equal_approx(restored_movement.look_yaw, 24.0)
		and is_equal_approx(restored_movement.look_pitch, -11.0),
		"the saved view should be restored"
	)

	var restored_collectible: Collectible = collectible_scene.instantiate()
	add_child(restored_collectible)
	_expect(
		restored_collectible.is_queued_for_deletion(),
		"a collected world item should not respawn"
	)

	var restored_drawer: DrawerInteractable = drawer_scene.instantiate()
	restored_drawer.persistent_id = &"manual_test_drawer"
	add_child(restored_drawer)
	_expect(restored_drawer.is_open, "the drawer state should be restored")

	var restored_door: DoorController = door_scene.instantiate()
	restored_door.persistent_id = &"manual_test_door"
	add_child(restored_door)
	_expect(restored_door.is_open, "the door state should be restored")

	restored_player.set_cutscene_frozen(true)
	var restored_pause: PauseMenuController = restored_player.get_node(
		"PauseMenu"
	)
	restored_pause.open_pause_menu()
	var restored_save_button: Button = restored_pause.get_node(
		"PauseRoot/MenuCenter/PauseWindow/PauseMargin/"
		+ "PauseVBox/SaveButton"
	)
	_expect(
		restored_save_button.disabled,
		"manual saving should be disabled during a cutscene"
	)
	restored_pause.resume_game()

	_expect_ok(SaveManager.delete_slot(1), "deleting the manual test slot")
	SaveManager.suspend_session(false)
	if test_failed:
		get_tree().quit(1)
	else:
		print("Manual save flow smoke test passed.")
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
	push_error("Manual save flow smoke test: " + message)
