extends Node
class_name MenuCinematicPause

const MENU_CONTROLLER_PATH := NodePath("../MenuController")
const PAUSE_MENU_PATH := NodePath("../CinematicPauseMenu")
const SKIP_PROMPT_PATH := NodePath("../CinematicHUD/SkipPrompt")

var menu_controller: Node = null
var pause_menu: PauseMenuController = null
var skip_prompt: Control = null

var cinematic_paused: bool = false
var skip_prompt_was_visible: bool = false
var paused_audio_players: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	menu_controller = get_node_or_null(MENU_CONTROLLER_PATH)
	pause_menu = get_node_or_null(
		PAUSE_MENU_PATH
	) as PauseMenuController
	skip_prompt = get_node_or_null(SKIP_PROMPT_PATH) as Control

	if pause_menu == null:
		push_error(
			"MenuCinematicPause: CinematicPauseMenu was not found."
		)
		return

	pause_menu.set_pause_input_enabled(false)

	if not pause_menu.pause_opened.is_connected(
		_on_pause_opened
	):
		pause_menu.pause_opened.connect(
			_on_pause_opened
		)

	if not pause_menu.pause_closed.is_connected(
		_on_pause_closed
	):
		pause_menu.pause_closed.connect(
			_on_pause_closed
		)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if event.is_echo():
		return

	if pause_menu != null and pause_menu.is_open():
		pause_menu.handle_pause_action()
	elif _can_pause_cinematic():
		pause_menu.open_pause_menu()
	else:
		return

	get_viewport().set_input_as_handled()


func _can_pause_cinematic() -> bool:
	if pause_menu == null:
		return false

	if (
		menu_controller == null
		or not is_instance_valid(menu_controller)
	):
		menu_controller = get_node_or_null(
			MENU_CONTROLLER_PATH
		)

	if menu_controller == null:
		return false

	if menu_controller.has_method(
		"is_cinematic_transition_running"
	):
		return bool(
			menu_controller.call(
				"is_cinematic_transition_running"
			)
		)

	return false


func _on_pause_opened() -> void:
	if cinematic_paused:
		return

	cinematic_paused = true
	skip_prompt_was_visible = (
		skip_prompt != null and skip_prompt.visible
	)

	if skip_prompt != null:
		skip_prompt.hide()

	_pause_playing_audio()


func _on_pause_closed() -> void:
	if not cinematic_paused:
		return

	cinematic_paused = false
	_resume_paused_audio()

	if skip_prompt != null and skip_prompt_was_visible:
		skip_prompt.show()

	skip_prompt_was_visible = false


func _pause_playing_audio() -> void:
	paused_audio_players.clear()
	_pause_audio_recursive(get_tree().root)


func _pause_audio_recursive(node: Node) -> void:
	if _is_audio_player(node):
		var is_playing: bool = bool(node.get("playing"))
		var already_paused: bool = bool(
			node.get("stream_paused")
		)

		if is_playing and not already_paused:
			node.set("stream_paused", true)
			paused_audio_players.append(node)

	for child: Node in node.get_children():
		_pause_audio_recursive(child)


func _resume_paused_audio() -> void:
	for audio_player: Node in paused_audio_players:
		if is_instance_valid(audio_player):
			audio_player.set("stream_paused", false)

	paused_audio_players.clear()


func _is_audio_player(node: Node) -> bool:
	return (
		node is AudioStreamPlayer
		or node is AudioStreamPlayer2D
		or node is AudioStreamPlayer3D
	)


func _exit_tree() -> void:
	if cinematic_paused:
		get_tree().paused = false
		_resume_paused_audio()
