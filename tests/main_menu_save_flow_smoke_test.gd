extends Node

const TEST_SAVE_DIRECTORY := (
	"res://.godot/codex_main_menu_save_flow_smoke"
)


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	for slot_id: int in range(1, SaveManager.SLOT_COUNT + 1):
		_expect_ok(
			SaveManager.delete_slot(slot_id),
			"cleaning menu test slot %d" % slot_id
		)

	var menu_scene: PackedScene = load(
		"res://scenes/menu/main_menu.tscn"
	)
	var menu: Node = menu_scene.instantiate()
	var menu_controller: Node = menu.get_node("MenuController")
	menu_controller.set("play_menu_idle_audio", false)
	add_child(menu)

	var new_game_button: Button = menu.get_node(
		"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
		+ "VBoxContainer/NewGameButton"
	)
	var load_game_button: Button = menu.get_node(
		"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
		+ "VBoxContainer/LoadGameButton"
	)
	var panel: SaveSlotsPanelController = menu.get_node(
		"UI/MainMenuUI/SaveSlotsPanel"
	)
	var cinematic_save_button: Button = menu.get_node(
		"CinematicPauseMenu/PauseRoot/MenuCenter/PauseWindow/"
		+ "PauseMargin/PauseVBox/SaveButton"
	)

	_expect(load_game_button.disabled, "Load Game should begin disabled")
	_expect(
		not cinematic_save_button.visible,
		"manual saving should be hidden in the menu cinematic"
	)
	new_game_button.pressed.emit()
	_expect(panel.visible, "New Game should open the slot picker")
	panel.close_panel()

	_expect_ok(
		SaveManager.create_new_game(
			1,
			"res://scenes/cinematics/dream_intro.tscn",
			"dream_intro_start",
			"SAVE_LOCATION_DREAM_INTRO"
		),
		"creating the menu test save"
	)
	_expect(not load_game_button.disabled, "Load Game should become enabled")
	load_game_button.pressed.emit()
	_expect(panel.visible, "Load Game should open the slot picker")
	panel.close_panel()

	_expect_ok(
		SaveManager.delete_slot(1),
		"deleting the menu test save"
	)
	SaveManager.suspend_session(false)
	menu.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Main menu save flow smoke test passed.")
	_finish_test.call_deferred()


func _finish_test() -> void:
	get_tree().quit(0)


func _expect_ok(result: int, operation: String) -> void:
	_expect(
		result == OK,
		"%s failed with %s" % [operation, error_string(result)]
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	push_error("Main menu save flow smoke test: " + message)
	get_tree().quit(1)
