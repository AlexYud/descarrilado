extends Node

## The main menu as a player meets it, driven only by real mouse and keyboard events (no direct calls to the menu's handlers): the menu is the current scene, so the next scene is
## built behind a loading screen first; then HOVER and focus, OPTIONS (open, a drop-down, back), NEW GAME (the slot list, an occupied slot's overwrite dialog with CANCEL and with
## CONFIRM, the delete dialog, BACK), LOAD GAME (its list, back), QUIT (wired), the start of the game (no black, the narration begins), Esc in the cinematic (opens and closes the pause
## menu) and the held skip (the next scene takes over). Run it as a scene; it quits by itself with a non-zero exit code on failure. The window is given a real size, so it also runs
## headless.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_main_menu_buttons_smoke"
const MENU_SCENE: String = "res://scenes/menu/main_menu.tscn"

var test_failed: bool = false
var root: Window = null
var menu: Node = null
var controller: Node = null
var audio: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# Like the game's main scene: a child of the root, the current scene.
	root = get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	get_window().size = Vector2i(1920, 1080)
	GameSettings.set_text_locale("en", false)
	GameSettings.set_captions_enabled(true, false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	for slot_id: int in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot_id)
	# Slot 1 holds a game; the others are empty.
	SaveManager.create_new_game(1, "res://scenes/cinematics/dream_intro.tscn", "dream_intro_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.suspend_session(true)
	audio = root.get_node("PersistentAudio")

	menu = (load(MENU_SCENE) as PackedScene).instantiate()
	controller = menu.get_node("MenuController")
	controller.set("play_menu_idle_audio", false)
	root.add_child(menu)
	get_tree().current_scene = menu

	await _check_boot_loading()
	await _check_hover_and_focus()
	await _check_options()
	await _check_new_game_slots()
	await _check_load_game()
	_check_quit_is_wired()
	await _check_start_and_cinematic()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	Input.action_release(&"skip_cinematic")
	for slot_id: int in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot_id)
	SaveManager.suspend_session(false)
	print("MAIN_MENU_BUTTONS_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


# ============================================================
# THE CHECKS
# ============================================================

func _check_boot_loading() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var black: ColorRect = controller.get("blackout_rect") as ColorRect
	var label: Label = controller.get("cinematic_loading_label") as Label
	_expect(black.modulate.a > 0.99 and label != null and label.visible, "at launch the menu is under black with the loading label while the next scene is built")
	_expect(bool(controller.get("new_game_button").disabled), "and its buttons cannot be pressed meanwhile")
	var waited: float = 0.0
	while (controller.get("_built_scene") == null or black.modulate.a > 0.01) and waited < 120.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_expect(controller.get("_built_scene") != null, "the next scene gets built and the menu is shown (%.1f s)" % waited)
	await _wait_real(0.5)
	_expect(not label.visible and root.disable_3d and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "with no loading label, the next scene asleep (no 3D drawn for it) and the pointer free")
	var new_game: Button = controller.get("new_game_button") as Button
	_expect(not new_game.disabled and not (controller.get("options_button") as Button).disabled and not (controller.get("quit_button") as Button).disabled, "NEW GAME, OPTIONS and QUIT can be pressed")
	_expect(( controller.get("load_game_button") as Button).disabled == false, "and LOAD GAME, since a save exists")
	var built: Node = controller.get("_built_scene")
	var pause_menus: int = 0
	for node: Node in built.find_children("*", "", true, false):
		if node.has_method("open_pause_menu") and node.process_mode != Node.PROCESS_MODE_DISABLED:
			pause_menus += 1
	_expect(pause_menus == 0, "the sleeping scene has no pause menu that could catch a key")
	await _wait_real(1.0)


func _check_hover_and_focus() -> void:
	var options: Button = controller.get("options_button") as Button
	await _move(_center(options))
	_expect(options.is_hovered(), "the pointer is over OPTIONS")
	_expect(root.gui_get_focus_owner() == options, "and moving over a button gives it the focus (the arrow)")


func _check_options() -> void:
	var options: Button = controller.get("options_button") as Button
	var panel: Control = controller.get("options_panel") as Control
	await _click(_center(options))
	_expect(panel.visible and bool(controller.get("options_panel_open")), "a click on OPTIONS opens the options")
	# A drop-down: its list opens (a pop-up window) and closes.
	var quality: OptionButton = panel.find_child("QualityOption", true, false) as OptionButton
	if quality != null:
		var tabs: TabContainer = panel.find_child("OptionsTabs", true, false) as TabContainer
		if tabs != null:
			# The tab that holds the drop-down.
			var holder: Node = quality
			while holder != null and holder.get_parent() != tabs:
				holder = holder.get_parent()
			if holder != null:
				tabs.current_tab = tabs.get_tab_idx_from_control(holder as Control)
			await get_tree().process_frame
		await _click(_center(quality))
		_expect(quality.get_popup().visible, "a drop-down of the options opens its list")
		await _key(KEY_ESCAPE)
		_expect(not quality.get_popup().visible, "and Esc closes the list")
	var back: Button = controller.get("options_back_button") as Button
	await _click(_center(back))
	_expect(not panel.visible and not bool(controller.get("options_panel_open")), "BACK in the options closes them")
	_expect(not (controller.get("new_game_button") as Button).disabled, "and the menu's buttons work again")


func _check_new_game_slots() -> void:
	var new_game: Button = controller.get("new_game_button") as Button
	var panel: Control = controller.get("save_slots_panel") as Control
	await _click(_center(new_game))
	_expect(bool(panel.call("is_open")), "a click on NEW GAME opens the slot list")
	var slot1: Button = panel.get_node("Center/Window/Margin/Content/Slots/Slot1/SlotButton") as Button
	var delete1: Button = panel.get_node("Center/Window/Margin/Content/Slots/Slot1/DeleteButton") as Button
	var back: Button = panel.get_node("Center/Window/Margin/Content/BackButton") as Button
	var overwrite: ConfirmationDialog = panel.get("overwrite_dialog") as ConfirmationDialog
	var deletion: ConfirmationDialog = panel.get("delete_dialog") as ConfirmationDialog

	# An occupied slot: the overwrite dialog, CANCEL closes it and nothing starts.
	await _click(_center(slot1))
	_expect(overwrite.visible, "a click on a slot that holds a game asks before overwriting it")
	await _click(_center_screen(overwrite.get_cancel_button()))
	_expect(not overwrite.visible and not bool(controller.get("transition_running")), "CANCEL closes the question and nothing starts")

	# The delete question: CANCEL leaves the save alone.
	await _click(_center(delete1))
	_expect(deletion.visible, "DELETE asks before deleting")
	await _click(_center_screen(deletion.get_cancel_button()))
	_expect(not deletion.visible and SaveManager.has_slot(1), "CANCEL leaves the save alone")

	# BACK returns to the menu.
	await _click(_center(back))
	_expect(not bool(panel.call("is_open")) and not (controller.get("new_game_button") as Button).disabled, "BACK closes the slot list and gives the menu its buttons back")


func _check_load_game() -> void:
	var load_game: Button = controller.get("load_game_button") as Button
	var panel: Control = controller.get("save_slots_panel") as Control
	await _click(_center(load_game))
	_expect(bool(panel.call("is_open")), "a click on LOAD GAME opens the list of saves")
	var empty_slot: Button = panel.get_node("Center/Window/Margin/Content/Slots/Slot2/SlotButton") as Button
	await _click(_center(empty_slot))
	_expect(not bool(controller.get("transition_running")), "an empty slot loads nothing")
	var back: Button = panel.get_node("Center/Window/Margin/Content/BackButton") as Button
	await _click(_center(back))
	_expect(not bool(panel.call("is_open")), "BACK closes it")


func _check_quit_is_wired() -> void:
	var quit: Button = controller.get("quit_button") as Button
	_expect(quit.pressed.get_connections().size() > 0, "QUIT is wired (it is not pressed here: it would end the test)")


func _check_start_and_cinematic() -> void:
	var new_game: Button = controller.get("new_game_button") as Button
	var panel: Control = controller.get("save_slots_panel") as Control
	var black: ColorRect = controller.get("blackout_rect") as ColorRect
	await _click(_center(new_game))
	var slot1: Button = panel.get_node("Center/Window/Margin/Content/Slots/Slot1/SlotButton") as Button
	var overwrite: ConfirmationDialog = panel.get("overwrite_dialog") as ConfirmationDialog
	await _click(_center(slot1))
	_expect(overwrite.visible, "(the occupied slot asks again)")
	await _click(_center_screen(overwrite.get_ok_button()))
	_expect(bool(controller.get("transition_running")), "CONFIRM starts the game")

	# The first seconds: no black at all, the narration begins, the menu fades out over the train.
	var peak: float = 0.0
	var waited: float = 0.0
	while waited < 2.5:
		await get_tree().process_frame
		waited += get_process_delta_time()
		peak = maxf(peak, black.modulate.a)
	_expect(peak < 0.05, "the start is smooth: no black screen (the black cover reached %.2f)" % peak)
	_expect(bool(audio.call("is_intro_narration_running")), "and the narration is running")
	_expect((controller.get("main_menu_ui") as Control).modulate.a < 0.5, "while the menu has faded out")
	await _wait_real(2.0)

	# Esc opens the cinematic's pause menu, Esc closes it.
	var pause_menu: Node = controller.get_node("../CinematicPauseMenu")
	await _key(KEY_ESCAPE)
	_expect(bool(pause_menu.call("is_open")) and get_tree().paused, "Esc in the cinematic opens the pause menu")
	await _key(KEY_ESCAPE)
	_expect(not bool(pause_menu.call("is_open")) and not get_tree().paused, "and Esc closes it")
	await _wait_real(0.5)

	# The held skip hands over to the next scene at once.
	var dream: Node = controller.get("_built_scene")
	Input.action_press(&"skip_cinematic")
	var skip_waited: float = 0.0
	while is_instance_valid(controller) and not bool(controller.get("_handing_over")) and skip_waited < 5.0:
		await get_tree().process_frame
		skip_waited += get_process_delta_time()
	Input.action_release(&"skip_cinematic")
	await _wait_real(1.0)
	_expect(is_instance_valid(dream) and get_tree().current_scene == dream and not root.disable_3d, "holding the skip key hands the game to the next scene (3D drawn again)")
	_expect(root.get_node_or_null("CinematicHost") == null and not bool(audio.call("is_intro_narration_running")), "the cinematic's layer is gone and the narration has stopped")
	_expect(not audio.call("is_opening_held"), "and the next scene may begin its opening")


# ============================================================
# REAL INPUT
# ============================================================

func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## A button of a pop-up dialog (a window): its place on the screen.
func _center_screen(control: Control) -> Vector2:
	return control.get_screen_position() + control.size * 0.5


func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await _wait_real(0.25)


func _click(at: Vector2) -> void:
	await _move(at)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		await _wait_real(0.12)
	await _wait_real(0.5)


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		Input.parse_input_event(key)
		await _wait_real(0.12)
	await _wait_real(0.4)


func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
	else:
		test_failed = true
		push_error("FAIL - " + message)
		print("FAIL - ", message)
