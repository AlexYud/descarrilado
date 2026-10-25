extends Node

## The Controls tab of the options (listening for a key, cancelling, clearing,
## conflicts, reset) and the walk-faster tutorial hint (shown after some walking,
## names the player's key, hides for dialogue, goes away when the player does it,
## is remembered, and can be switched off). Bindings use a temporary file; nothing
## here writes the player's real settings. Run it as a scene; it quits by itself
## with a non-zero exit code on failure.

const TEST_SETTINGS_PATH: String = "user://codex_controls_test.cfg"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_controls_tutorial_smoke"
const TEST_SCENE_PATH: String = "res://tests/controls_and_tutorial_smoke_test.tscn"

var test_failed: bool = false


func _ready() -> void:
	DirAccess.remove_absolute(TEST_SETTINGS_PATH)
	InputBindings.settings_path = TEST_SETTINGS_PATH
	InputBindings.reset_all()
	GameSettings.set_text_locale("en", false)

	await _check_controls_tab()
	await _check_tutorial()
	await _check_tutorial_trigger()
	await _check_inventory_tutorial()
	await _check_head_bob()

	InputBindings.reset_all()
	InputBindings.settings_path = InputBindings.SETTINGS_PATH
	DirAccess.remove_absolute(TEST_SETTINGS_PATH)
	print("CONTROLS_AND_TUTORIAL_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _press(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _click(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _slot_text(tab: ControlsSettingsTab, action: StringName, slot: int) -> String:
	return ((tab._rows[action] as Dictionary)["slots"] as Array)[slot].text


func _check_controls_tab() -> void:
	var panel: OptionsPanelController = (load("res://scenes/ui/options_panel.tscn") as PackedScene).instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.open()
	panel.options_tabs.current_tab = 2
	await get_tree().process_frame
	var tab: ControlsSettingsTab = panel.controls_tab

	_expect(tab._rows.size() == InputBindings.ACTIONS.size(), "every rebindable action has a row")
	_expect(_slot_text(tab, &"interact", 0) == "E", "the row shows the key")
	_expect(_slot_text(tab, &"interact", 1) == ControlsSettingsTab.EMPTY_SLOT_TEXT, "an empty alternate shows a dash")
	_expect(tab._sprint_option.item_count == 2, "walking faster can be held or toggled")
	_expect(tab._rows[&"interact"]["reset"].modulate.a == 0.0, "an unchanged action offers no reset")

	# Listening, then a key.
	tab._start_listening(&"interact", 1)
	_expect(tab.is_listening(), "clicking a key starts listening")
	_expect(_slot_text(tab, &"interact", 1) == tr("BINDING_LISTENING"), "the button asks for a key")
	_expect(tab._hint_label.text == tr("BINDING_LISTEN_HINT"), "and the hint says how to cancel and clear")
	tab._input(_press(KEY_Y))
	_expect(not tab.is_listening(), "a key ends it")
	_expect(_slot_text(tab, &"interact", 1) == "Y", "the row shows the new key")
	_expect(InputMap.event_is_action(_press(KEY_Y), &"interact"), "and it works")
	_expect(tab._rows[&"interact"]["reset"].modulate.a == 1.0, "a changed action offers its reset")

	# Escape and the left button cancel.
	tab._start_listening(&"interact", 1)
	tab._input(_press(KEY_ESCAPE))
	_expect(not tab.is_listening() and _slot_text(tab, &"interact", 1) == "Y", "Escape cancels")
	tab._start_listening(&"interact", 1)
	tab._input(_click(MOUSE_BUTTON_LEFT))
	_expect(not tab.is_listening() and _slot_text(tab, &"interact", 1) == "Y", "a left click cancels")

	# A mouse button binds.
	tab._start_listening(&"flashlight", 1)
	tab._input(_click(MOUSE_BUTTON_MIDDLE))
	_expect(_slot_text(tab, &"flashlight", 1) == tr("BINDING_MOUSE_MIDDLE"), "a mouse button binds")

	# Delete clears an alternate key, but never the last key.
	tab._start_listening(&"interact", 1)
	tab._input(_press(KEY_DELETE))
	_expect(_slot_text(tab, &"interact", 1) == ControlsSettingsTab.EMPTY_SLOT_TEXT, "Delete clears the alternate key")
	tab._start_listening(&"up", 0)
	tab._input(_press(KEY_DELETE))
	_expect(_slot_text(tab, &"up", 0) == "W", "but not the last key")
	_expect(tab._hint_label.text == tr("BINDING_LAST_KEY"), "and says why")

	# A key in use asks what to do.
	tab._start_listening(&"flashlight", 0)
	tab._input(_press(KEY_E))
	_expect(tab._conflict_dialog.visible, "a key in use opens the question")
	_expect(not tab._conflict_dialog.get_ok_button().disabled, "swapping is offered")
	_expect(tab._conflict_replace_button.disabled, "taking the only key of the other action is not")
	tab._conflict_dialog.hide()
	tab._on_conflict_cancelled()
	_expect(_slot_text(tab, &"flashlight", 0) == "F", "cancelling changes nothing")

	tab._start_listening(&"flashlight", 0)
	tab._input(_press(KEY_E))
	tab._resolve_conflict(&"swap")
	_expect(
		_slot_text(tab, &"flashlight", 0) == "E" and _slot_text(tab, &"interact", 0) == "F",
		"swapping gives each the other's key"
	)

	# A key nobody can give up is explained, not asked about.
	tab._on_reset_action_pressed(&"flashlight")
	_expect(
		_slot_text(tab, &"flashlight", 0) == "F" and _slot_text(tab, &"interact", 0) == "E",
		"reset puts an action (and the key it took) back"
	)
	tab._start_listening(&"inventory", 1)
	tab._input(_press(KEY_E))
	tab._conflict_dialog.hide()
	tab._on_conflict_cancelled()

	# Closing the options stops listening.
	tab._start_listening(&"sprint", 1)
	panel.close()
	await get_tree().process_frame
	_expect(not tab.is_listening(), "closing the options stops listening")

	InputBindings.reset_all()
	panel.queue_free()
	await get_tree().process_frame


func _check_tutorial() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "tutorial_test_start", "SAVE_LOCATION_DREAM_INTRO")
	TutorialHintController._learned_this_run = false
	GameSettings.set_tutorial_hints(true, false)
	GameSettings.set_sprint_toggle(false, false)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, 0.1, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var hints: TutorialHintController = player.get_node("TutorialHints")
	hints.distance_before_hint = 2.0
	hints.seconds_to_learn = 0.8
	hints.fade_seconds = 0.05

	_expect(not hints.is_showing, "no hint before the player has walked")
	Input.action_press("up")
	await _until(func() -> bool: return hints.is_showing, 8.0)
	_expect(hints.is_showing, "the hint appears after some walking")
	var text: String = hints._label.text
	_expect(text.contains(tr("KEY_NAME_SHIFT")), "it names the key (%s)" % text)
	_expect(text.contains("walk faster"), "and says what it does")

	# It names the key the player really uses, and the way (hold or toggle).
	InputBindings.set_binding(&"sprint", 0, {"type": "key", "code": int(KEY_Z)})
	_expect(hints._label.text.contains("Z") and not hints._label.text.contains(tr("KEY_NAME_SHIFT")), "it follows a rebound key")
	GameSettings.set_sprint_toggle(true, false)
	_expect(hints._label.text.contains("Press"), "and the toggle wording")
	GameSettings.set_sprint_toggle(false, false)
	InputBindings.reset_all()
	_expect(hints._label.text.contains(tr("KEY_NAME_SHIFT")), "and goes back with the key")
	# Changing bindings rebuilds the input map, which releases held actions.
	Input.action_press("up")

	# A dialogue covers it; it comes back afterwards.
	player.dialogue_frozen = true
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not hints.is_showing, "it hides for a dialogue")
	player.dialogue_frozen = false
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(hints.is_showing, "and returns when the dialogue ends")

	# Doing it ends it, for good.
	Input.action_press("sprint")
	await _until(func() -> bool: return bool(SaveManager.get_state_value(&"tutorials", &"sprint_hint_done", false)), 8.0)
	_expect(not hints.is_showing, "walking fast makes it go away")
	_expect(bool(SaveManager.get_state_value(&"tutorials", &"sprint_hint_done", false)), "and it is remembered in the save")
	Input.action_release("sprint")
	Input.action_release("up")

	player.queue_free()
	await get_tree().process_frame
	var again: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(again)
	again.global_position = Vector3(0.0, 0.1, 0.0)
	await get_tree().physics_frame
	_expect(again.get_node("TutorialHints")._learned, "a loaded game does not teach it again")
	again.queue_free()
	await get_tree().process_frame

	# Switched off in the settings, it never shows.
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "tutorial_test_start", "SAVE_LOCATION_DREAM_INTRO")
	TutorialHintController._learned_this_run = false
	GameSettings.set_tutorial_hints(false, false)
	var quiet: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(quiet)
	quiet.global_position = Vector3(0.0, 0.1, 0.0)
	await get_tree().physics_frame
	var quiet_hints: TutorialHintController = quiet.get_node("TutorialHints")
	quiet_hints.distance_before_hint = 1.0
	Input.action_press("up")
	await get_tree().create_timer(3.0).timeout
	Input.action_release("up")
	_expect(not quiet_hints.is_showing, "with tutorial hints off it stays quiet")

	GameSettings.set_tutorial_hints(true, false)
	quiet.queue_free()
	floor_body.queue_free()
	SaveManager.delete_slot(1)
	await get_tree().process_frame


func _until(condition: Callable, timeout_seconds: float) -> void:
	var waited: float = 0.0
	while not condition.call() and waited < timeout_seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


## With a trigger in the level (past the fence gate) the hint waits for the player to
## enter it, then for a little walking.
func _check_tutorial_trigger() -> void:
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "tutorial_test_start", "SAVE_LOCATION_DREAM_INTRO")
	TutorialHintController._learned_this_run = false
	GameSettings.set_tutorial_hints(true, false)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	var trigger: TutorialTrigger = TutorialTrigger.new()
	trigger.size = Vector3(8.0, 6.0, 2.0)
	trigger.position = Vector3(0.0, 1.0, -8.0)
	add_child(trigger)

	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, 0.1, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var hints: TutorialHintController = player.get_node("TutorialHints")
	hints.distance_after_trigger = 2.0
	hints.distance_before_hint = 2.0
	hints.fade_seconds = 0.05

	# Walking forward for a while, still short of the trigger: nothing yet, though the
	# distance alone would have been enough without a trigger.
	Input.action_press("up")
	await get_tree().create_timer(3.5).timeout
	_expect(player.global_position.z > -7.0, "the player has not reached the trigger yet")
	_expect(not hints.is_showing, "the hint waits for the trigger, not the clock")

	await _until(func() -> bool: return hints.is_showing, 12.0)
	_expect(player.global_position.z < -6.0, "it shows once the player is past the trigger")
	_expect(hints.is_showing, "and a little walking later")
	Input.action_release("up")

	# Someone who is already walking fast when they reach the trigger needs no hint.
	player.queue_free()
	await get_tree().process_frame
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "tutorial_test_start", "SAVE_LOCATION_DREAM_INTRO")
	TutorialHintController._learned_this_run = false

	var fast_player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(fast_player)
	fast_player.global_position = Vector3(0.0, 0.1, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fast_hints: TutorialHintController = fast_player.get_node("TutorialHints")
	fast_hints.distance_after_trigger = 2.0
	fast_hints.fade_seconds = 0.05
	GameSettings.set_sprint_toggle(false, false)
	Input.action_press("sprint")
	Input.action_press("up")
	var showed: bool = false
	var waited: float = 0.0
	while fast_player.global_position.z > -13.0 and waited < 14.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		showed = showed or fast_hints.is_showing

	await get_tree().create_timer(1.5).timeout
	showed = showed or fast_hints.is_showing
	Input.action_release("up")
	Input.action_release("sprint")
	_expect(fast_player.global_position.z < -9.0, "the fast walker went through the trigger")
	_expect(not showed, "already walking fast at the trigger: the hint never shows")
	_expect(fast_hints._learned, "and it counts as learned")

	fast_player.queue_free()
	trigger.queue_free()
	floor_body.queue_free()
	SaveManager.delete_slot(1)
	await get_tree().process_frame


## The inventory lesson, taught after the trail map is taken (`trigger(&"inventory")`): it waits to be started, comes up at the bottom
## naming the player's key, goes away the moment the inventory is opened, is remembered, and is silent when the hints are off.
func _check_inventory_tutorial() -> void:
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "tutorial_test_start", "SAVE_LOCATION_DREAM_INTRO")
	TutorialHintController._learned_this_run = false
	TutorialHintController._lessons_learned_this_run.clear()
	GameSettings.set_tutorial_hints(true, false)

	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hints: TutorialHintController = player.get_node("TutorialHints")
	hints.lesson_delay = 0.2
	hints.fade_seconds = 0.05
	await get_tree().create_timer(0.6).timeout
	_expect(not hints.is_lesson_showing(&"inventory"), "the inventory lesson waits to be started")

	hints.trigger(&"inventory")
	await _until(func() -> bool: return hints.is_lesson_showing(&"inventory"), 3.0)
	_expect(hints.is_lesson_showing(&"inventory"), "it comes up once it is started")
	var label: RichTextLabel = hints._lessons[&"inventory"]["label"]
	_expect(label != null and label.get_parsed_text().contains(InputBindings.get_binding_label(&"inventory", -1, true)), "it names the player's key (%s)" % (label.get_parsed_text() if label != null else ""))
	_expect(not hints.is_showing, "and the walking lesson waits")

	# Shown over a cutscene or a close up? No: it goes away and comes back.
	player.cutscene_frozen = true
	await _until(func() -> bool: return not hints.is_lesson_showing(&"inventory"), 2.0)
	_expect(not hints.is_lesson_showing(&"inventory"), "it does not show over a cutscene")
	player.cutscene_frozen = false
	await _until(func() -> bool: return hints.is_lesson_showing(&"inventory"), 3.0)
	_expect(hints.is_lesson_showing(&"inventory"), "and comes back after")

	# Opening the inventory is the lesson learned.
	var slots: Array[Dictionary] = player.inventory_controller.get_slots()
	player.inventory_ui_controller.show_inventory(slots)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not hints.is_lesson_showing(&"inventory"), "opening the inventory puts the hint away")
	_expect(hints.is_lesson_learned(&"inventory"), "and counts as learned")
	_expect(bool(SaveManager.get_state_value(&"tutorials", &"inventory_hint_done", false)), "it is remembered in the saved game")
	player.inventory_ui_controller.close()
	await get_tree().create_timer(0.5).timeout
	_expect(not hints.is_lesson_showing(&"inventory"), "it does not come back")

	# The map lesson: started when the player is given the map. The map shown to them as they take it is not the lesson learned; looking
	# at it with the key is.
	var maps: PlayerMapController = player.map_controller
	var inspect: PlayerInspectController = player.inspect_controller
	maps.give_map()
	hints.trigger(&"map")
	maps.open(player.get_node("Head/Camera3D").global_transform, true)
	await get_tree().create_timer(0.6).timeout
	_expect(maps.is_open and not hints.is_lesson_learned(&"map"), "the map shown as it is taken does not count as the lesson learned")
	_expect(not hints.is_lesson_showing(&"map"), "and no hint is over its view")
	maps.close()
	await _until(func() -> bool: return not inspect.is_open(), 5.0)
	await _until(func() -> bool: return hints.is_lesson_showing(&"map"), 4.0)
	_expect(hints.is_lesson_showing(&"map"), "once it is put away the hint of the map key comes up")
	var map_label: RichTextLabel = hints._lessons[&"map"]["label"]
	_expect(map_label.get_parsed_text().contains(InputBindings.get_binding_label(&"map", -1, true)), "it names the map key (%s)" % map_label.get_parsed_text())
	_expect(not hints.is_lesson_showing(&"inventory"), "and it is not about the inventory")
	_expect(maps.open(), "the player opens the map with its key")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(hints.is_lesson_learned(&"map") and not hints.is_lesson_showing(&"map"), "that is the lesson learned")
	_expect(bool(SaveManager.get_state_value(&"tutorials", &"map_hint_done", false)), "and it is remembered")
	maps.close()
	await _until(func() -> bool: return not inspect.is_open(), 5.0)

	# A loaded game that learned it is not taught again, even if the map is triggered again.
	player.queue_free()
	await get_tree().process_frame
	var again: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(again)
	await get_tree().physics_frame
	var again_hints: TutorialHintController = again.get_node("TutorialHints")
	again_hints.lesson_delay = 0.1
	again_hints.trigger(&"inventory")
	await get_tree().create_timer(0.6).timeout
	_expect(not again_hints.is_lesson_showing(&"inventory"), "a game that learned it is not taught again")
	again.queue_free()
	await get_tree().process_frame

	# Hints turned off in the options: silent.
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "tutorial_test_start", "SAVE_LOCATION_DREAM_INTRO")
	TutorialHintController._lessons_learned_this_run.clear()
	GameSettings.set_tutorial_hints(false, false)
	var quiet: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(quiet)
	await get_tree().physics_frame
	var quiet_hints: TutorialHintController = quiet.get_node("TutorialHints")
	quiet_hints.lesson_delay = 0.1
	quiet_hints.trigger(&"inventory")
	await get_tree().create_timer(0.6).timeout
	_expect(not quiet_hints.is_lesson_showing(&"inventory"), "with the hints turned off the lesson is silent")
	quiet.queue_free()
	GameSettings.set_tutorial_hints(true, false)
	SaveManager.delete_slot(1)
	await get_tree().process_frame


## Head bobbing can be turned off in the options: walking then leaves the view steady.
func _check_head_bob() -> void:
	_expect(GameSettings.get_head_bob_enabled(), "head bobbing is on by default")

	var tab: ControlsSettingsTab = ControlsSettingsTab.new()
	add_child(tab)
	await get_tree().process_frame
	_expect(tab._head_bob_check != null and tab._head_bob_check.button_pressed, "the Controls tab shows it as on")
	tab._head_bob_check.button_pressed = false
	_expect(not GameSettings.get_head_bob_enabled(), "its switch turns it off")
	tab._head_bob_check.button_pressed = true
	_expect(GameSettings.get_head_bob_enabled(), "and on again")
	tab.queue_free()

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, 0.1, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var camera: Camera3D = player.get_node("Head/Camera3D")

	var spread: Array[float] = []
	for bob_on: bool in [true, false]:
		GameSettings.set_head_bob_enabled(bob_on, false)
		player.global_position = Vector3(0.0, 0.1, 0.0)
		Input.action_press("up")
		await get_tree().create_timer(1.2).timeout
		var lowest: float = INF
		var highest: float = -INF
		var roll_low: float = INF
		var roll_high: float = -INF
		var elapsed: float = 0.0
		while elapsed < 2.5:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
			lowest = minf(lowest, camera.position.y)
			highest = maxf(highest, camera.position.y)
			roll_low = minf(roll_low, camera.rotation.z)
			roll_high = maxf(roll_high, camera.rotation.z)

		Input.action_release("up")
		spread.append(highest - lowest)
		spread.append(roll_high - roll_low)
		await get_tree().create_timer(0.8).timeout

	_expect(spread[0] > 0.004 and spread[1] > 0.004, "walking with head bobbing on moves the view (%.4f m, %.4f rad)" % [spread[0], spread[1]])
	_expect(spread[2] < 0.0005 and spread[3] < 0.0005, "with it off the view is steady (%.5f m, %.5f rad)" % [spread[2], spread[3]])
	GameSettings.set_head_bob_enabled(true, false)

	player.queue_free()
	floor_body.queue_free()
	await get_tree().process_frame
