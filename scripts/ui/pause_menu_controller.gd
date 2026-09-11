extends CanvasLayer
class_name PauseMenuController

signal pause_opened
signal pause_closed

@export var main_menu_scene: PackedScene
@export var pause_input_enabled: bool = true
@export var reload_current_scene_on_main_menu: bool = false
@export var manual_save_visible: bool = true

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

@onready var save_button: Button = (
	$PauseRoot
	/MenuCenter
	/PauseWindow
	/PauseMargin
	/PauseVBox
	/SaveButton
)

@onready var save_status_label: Label = (
	$PauseRoot
	/MenuCenter
	/PauseWindow
	/PauseMargin
	/PauseVBox
	/SaveStatusLabel
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
var save_provider: Node = null
var save_status_key: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_root.hide()

	if not resume_button.pressed.is_connected(_on_resume_button_pressed):
		resume_button.pressed.connect(_on_resume_button_pressed)

	if not options_button.pressed.is_connected(_on_options_button_pressed):
		options_button.pressed.connect(_on_options_button_pressed)

	if not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)

	if not main_menu_button.pressed.is_connected(_on_main_menu_button_pressed):
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)

	if not options_panel.back_requested.is_connected(_on_options_back_requested):
		options_panel.back_requested.connect(_on_options_back_requested)

	if not GameSettings.text_language_changed.is_connected(
		_on_text_language_changed
	):
		GameSettings.text_language_changed.connect(
			_on_text_language_changed
		)

	save_button.visible = manual_save_visible
	save_status_label.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not pause_input_enabled:
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	if event.is_echo():
		return

	handle_pause_action()
	get_viewport().set_input_as_handled()


func handle_pause_action() -> void:
	if pause_open:
		if options_panel.is_open():
			_show_pause_buttons()
		else:
			resume_game()
	else:
		open_pause_menu()


func set_pause_input_enabled(enabled: bool) -> void:
	pause_input_enabled = enabled


func open_pause_menu() -> void:
	if pause_open:
		return

	pause_open = true
	pause_root.show()
	menu_center.show()
	options_panel.hide()
	_clear_save_status()
	_refresh_manual_save_availability()

	pause_opened.emit()
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
	pause_closed.emit()


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


func _on_save_button_pressed() -> void:
	_refresh_manual_save_availability()
	if save_button.disabled or save_provider == null:
		_set_save_status(&"PAUSE_SAVE_UNAVAILABLE")
		return

	var scene_path: String = str(
		save_provider.call("get_current_save_scene_path")
	)
	var player_state_value: Variant = save_provider.call(
		"get_manual_save_state"
	)
	if not player_state_value is Dictionary:
		_set_save_status(&"PAUSE_SAVE_ERROR")
		return

	var save_result: Error = SaveManager.save_manual_game(
		scene_path,
		player_state_value as Dictionary
	)
	if save_result == OK:
		_set_save_status(&"PAUSE_SAVE_SUCCESS")
	else:
		_set_save_status(&"PAUSE_SAVE_ERROR")


func _on_options_back_requested() -> void:
	_show_pause_buttons()
	_refresh_manual_save_availability()


func _refresh_manual_save_availability() -> void:
	save_button.visible = manual_save_visible
	if not manual_save_visible:
		return

	save_provider = _find_save_provider()
	var available: bool = (
		save_provider != null
		and save_provider.has_method("can_manual_save")
		and save_provider.has_method("get_current_save_scene_path")
		and save_provider.has_method("get_manual_save_state")
		and bool(save_provider.call("can_manual_save"))
	)
	save_button.disabled = not available
	save_button.tooltip_text = (
		""
		if available
		else tr("PAUSE_SAVE_UNAVAILABLE")
	)


func _find_save_provider() -> Node:
	var candidate: Node = get_parent()
	while candidate != null:
		if (
			candidate.has_method("can_manual_save")
			and candidate.has_method("get_manual_save_state")
		):
			return candidate

		candidate = candidate.get_parent()

	return null


func _set_save_status(message_key: StringName) -> void:
	save_status_key = message_key
	save_status_label.text = tr(message_key)
	save_status_label.show()


func _clear_save_status() -> void:
	save_status_key = &""
	save_status_label.text = ""
	save_status_label.hide()


func _on_text_language_changed(_locale: String) -> void:
	_refresh_manual_save_availability()
	if not save_status_key.is_empty():
		save_status_label.text = tr(save_status_key)


func _on_main_menu_button_pressed() -> void:
	if (
		not reload_current_scene_on_main_menu
		and main_menu_scene == null
	):
		push_error(
			"PauseMenu: Assign the main Menu scene to Main Menu Scene in the Inspector."
		)
		return

	GameSettings.save_settings()
	var save_result: Error = SaveManager.suspend_session()
	if save_result != OK:
		push_warning(
			"PauseMenu: Could not save the active game before returning "
			+ "to the main menu. Error: %s"
			% error_string(save_result)
		)

	pause_root.hide()
	pause_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	pause_closed.emit()

	var change_error: Error

	if reload_current_scene_on_main_menu:
		change_error = get_tree().reload_current_scene()
	else:
		change_error = get_tree().change_scene_to_packed(
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
		pause_opened.emit()
		get_tree().paused = true
		main_menu_button.grab_focus()


func _exit_tree() -> void:
	if pause_open:
		pause_open = false
		get_tree().paused = false
		pause_closed.emit()
