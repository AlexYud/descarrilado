extends CanvasLayer
class_name PauseMenuController

@export var main_menu_scene: PackedScene

@onready var pause_root: Control = $PauseRoot
@onready var menu_center: CenterContainer = $PauseRoot/MenuCenter

@onready var resume_button: Button = (
	$PauseRoot
	/MenuCenter
	/PauseWindow
	/PauseMargin
	/PauseVBox
	/ResumeButton
)

@onready var options_button: Button = (
	$PauseRoot
	/MenuCenter
	/PauseWindow
	/PauseMargin
	/PauseVBox
	/OptionsButton
)

@onready var main_menu_button: Button = (
	$PauseRoot
	/MenuCenter
	/PauseWindow
	/PauseMargin
	/PauseVBox
	/MainMenuButton
)

@onready var options_panel: OptionsPanelController = (
	$PauseRoot
	/OptionsPanel
)

var pause_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_root.hide()

	if not resume_button.pressed.is_connected(_on_resume_button_pressed):
		resume_button.pressed.connect(_on_resume_button_pressed)

	if not options_button.pressed.is_connected(_on_options_button_pressed):
		options_button.pressed.connect(_on_options_button_pressed)

	if not main_menu_button.pressed.is_connected(_on_main_menu_button_pressed):
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)

	if not options_panel.back_requested.is_connected(_on_options_back_requested):
		options_panel.back_requested.connect(_on_options_back_requested)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if pause_open:
		if options_panel.is_open():
			_show_pause_buttons()
		else:
			resume_game()
	else:
		open_pause_menu()

	get_viewport().set_input_as_handled()


func open_pause_menu() -> void:
	if pause_open:
		return

	pause_open = true
	pause_root.show()
	menu_center.show()
	options_panel.hide()

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	resume_button.grab_focus()


func resume_game() -> void:
	if not pause_open:
		return

	if options_panel.is_open():
		options_panel.close()

	pause_root.hide()
	pause_open = false

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func is_open() -> bool:
	return pause_open


func _show_options() -> void:
	if not pause_open:
		return

	menu_center.hide()
	options_panel.open()


func _show_pause_buttons() -> void:
	options_panel.close()
	menu_center.show()
	options_button.grab_focus()


func _on_resume_button_pressed() -> void:
	resume_game()


func _on_options_button_pressed() -> void:
	_show_options()


func _on_options_back_requested() -> void:
	_show_pause_buttons()


func _on_main_menu_button_pressed() -> void:
	if main_menu_scene == null:
		push_error(
			"PauseMenu: Assign the main Menu scene to Main Menu Scene in the Inspector."
		)
		return

	GameSettings.save_settings()

	pause_root.hide()
	pause_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var change_error: Error = get_tree().change_scene_to_packed(
		main_menu_scene
	)

	if change_error != OK:
		push_error(
			"PauseMenu: Could not return to the main menu. Error code: %s"
			% change_error
		)

		pause_open = true
		pause_root.show()
		menu_center.show()
		get_tree().paused = true
		main_menu_button.grab_focus()


func _exit_tree() -> void:
	if pause_open:
		get_tree().paused = false
