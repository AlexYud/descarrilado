extends Node

## The developer console (`DevConsole`, commands in `DevCommands`): it opens and closes with the backquote
## key and holds the player meanwhile, runs commands (the three fichas, the walking speed, the save state,
## teleports), completes names with Tab and keeps a history. Run it as a scene; it quits by itself with a
## non-zero exit code on failure.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_dev_console_smoke"
const TEST_SCENE_PATH: String = "res://tests/dev_console_smoke_test.tscn"

var test_failed: bool = false


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "dev_console_start", "SAVE_LOCATION_DREAM_INTRO")

	_expect(DevConsole.is_enabled(), "the console is enabled in a debug run")
	var console: Node = DevConsole
	_expect(console != null and not console.is_open, "there is a console and it starts closed")

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)
	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, 1.05, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Open and close with the backquote key; the player is held meanwhile.
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_QUOTELEFT
	key.keycode = KEY_QUOTELEFT
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(console.is_open, "the backquote key opens it")
	_expect(player.modal_ui_open, "and the player is held while it is up")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "with a visible mouse")
	console.close()
	_expect(not console.is_open and not player.modal_ui_open, "closing gives the player back")

	# Commands.
	_expect(console.execute("help").contains("give_fichas"), "help lists the commands")
	_expect(console.execute("help speed").contains("speed <factor>"), "help <command> explains one")
	_expect(console.execute("nonsense").contains("Unknown command"), "an unknown command says so")
	_expect(console.execute("pos").contains("Player at"), "pos prints the position")

	_expect(not player.has_inventory_item("juliana_ficha"), "no fichas to begin with")
	_expect(console.execute("give_fichas").contains("Gave"), "give_fichas gives them")
	var all_three: bool = true
	for id: String in OverlookPhoneSequence.FICHA_IDS:
		all_three = all_three and player.has_inventory_item(id)
	_expect(all_three, "all three fichas are in the inventory")
	_expect(console.execute("give_fichas").contains("already"), "and asking again gives no duplicates")
	_expect(bool(SaveManager.get_state_value(&"collectibles", &"lucas_ficha", false)), "they count as collected, so none lies in the world again")

	console.execute("speed 3")
	_expect(is_equal_approx(player.movement_controller.speed_multiplier, 3.0), "speed sets the walking speed factor")
	console.execute("speed 1")
	console.execute("time_scale 2")
	_expect(is_equal_approx(Engine.time_scale, 2.0), "time_scale sets the time scale")
	console.execute("time_scale 1")

	console.execute("state_set puzzles dev_test_flag true")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"dev_test_flag", false)), "state_set writes the save state")
	_expect(console.execute("state_get puzzles dev_test_flag").contains("true"), "and state_get reads it")

	_expect(console.execute("tp shed").contains("No place"), "tp says so when the scene has no such place")
	_expect(console.execute("places").contains("overlook"), "places lists them")

	# Teleport in a scene that has the places: a stand-in with the nodes `tp` looks for.
	var scenery: Node3D = Node3D.new()
	scenery.name = "Scenery"
	var shed: Node3D = Node3D.new()
	shed.name = "WaitingShed"
	scenery.add_child(shed)
	shed.position = Vector3(20.0, 0.0, 0.0)
	var holder: Node = get_tree().current_scene
	_expect(holder == self, "(the test scene is the current scene)")
	add_child(scenery)
	var result: String = console.execute("tp shed 8")
	_expect(result.contains("Teleported"), "tp moves the player (%s)" % result)
	_expect(absf(player.global_position.x - 12.0) < 0.5 or absf(player.global_position.x - 28.0) < 0.5, "to the given distance from the place (x %.1f)" % player.global_position.x)

	# Tab completes a name and cycles; Up recalls the history.
	console.open()
	console._line.text = "gi"
	console._complete()
	_expect(console._line.text == "give_fichas ", "Tab completes the command (%s)" % console._line.text)
	console._on_submitted("pos")
	console._on_submitted("places")
	console._step_history(-1)
	_expect(console._line.text == "places", "Up recalls the last command")
	console._step_history(-1)
	_expect(console._line.text == "pos", "and the one before")
	console.close()

	SaveManager.delete_slot(1)
	Engine.time_scale = 1.0
	print("DEV_CONSOLE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
