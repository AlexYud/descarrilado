extends CanvasLayer

## The developer console (autoload `DevConsole`): a drop-down command line over the game, opened with the
## backquote key (the one under Esc), for speeding up play tests (give the three fichas, jump to a place,
## walk faster, set a save value...). The commands are in `DevCommands`; type `help`.
##
## It exists only in debug builds (the editor, debug exports) or when the game is started with the user
## argument `--dev` (`godot ... -- --dev`, or `game.exe --dev`). In a release build it removes itself, so
## the players never get it.

signal opened
signal closed

const TOGGLE_KEY: Key = KEY_QUOTELEFT
const HISTORY_LIMIT: int = 50
const HEIGHT_FRACTION: float = 0.42

var is_open: bool = false
## Tests set this to the level they load themselves (it is not the current scene then).
var scene_override: Node = null

var _commands: DevCommands = null
var _panel: PanelContainer = null
var _log: RichTextLabel = null
var _line: LineEdit = null
var _history: PackedStringArray = PackedStringArray()
var _history_at: int = 0
var _completion: PackedStringArray = PackedStringArray()
var _completion_at: int = 0
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _modal_before: bool = false


## True when the console is allowed in this run.
static func is_enabled() -> bool:
	return OS.is_debug_build() or OS.get_cmdline_user_args().has("--dev")


func _ready() -> void:
	if not is_enabled():
		queue_free()
		return

	layer = 2000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_commands = DevCommands.new(self)
	_build_ui()
	_panel.visible = false
	print("Developer console ready: press the backquote key (type help).")


## Runs a command line and prints it with its answer. Returns the answer (for tests).
func execute(line: String) -> String:
	if _commands == null:
		_commands = DevCommands.new(self)

	var answer: String = _commands.execute(line)
	if _log != null:
		_write("[color=%s]> %s[/color]" % [UIConfig.color_disabled.to_html(false), line.strip_edges().replace("[", "[lb]")])
		if not answer.is_empty():
			_write(answer)

	return answer


## The level the commands work on.
func scene_root() -> Node:
	if scene_override != null and is_instance_valid(scene_override):
		return scene_override

	return get_tree().current_scene


func clear_log() -> void:
	if _log != null:
		_log.clear()


func open() -> void:
	if is_open or _panel == null:
		return

	is_open = true
	_panel.visible = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The player stops moving, looking and acting while the console is up.
	var player: Node = get_tree().get_first_node_in_group(&"player")
	_modal_before = player != null and bool(player.get("modal_ui_open"))
	if player != null and player.has_method("set_modal_ui_open") and not _modal_before:
		player.call("set_modal_ui_open", true)

	_line.clear()
	_line.grab_focus()
	opened.emit()


func close() -> void:
	if not is_open:
		return

	is_open = false
	_panel.visible = false
	_line.release_focus()
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method("set_modal_ui_open") and not _modal_before:
		player.call("set_modal_ui_open", false)

	Input.mouse_mode = _mouse_before
	closed.emit()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	if key.physical_keycode == TOGGLE_KEY or key.keycode == TOGGLE_KEY:
		if is_open:
			close()
		else:
			open()

		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	match key.keycode:
		KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		KEY_UP:
			_step_history(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_step_history(1)
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_complete()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"NotePanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.anchor_bottom = HEIGHT_FRACTION
	_panel.offset_bottom = 0.0
	add_child(_panel)

	var box: VBoxContainer = VBoxContainer.new()
	_panel.add_child(box)

	_log = RichTextLabel.new()
	_log.name = "Log"
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_log)
	_write("Developer console. [color=%s]help[/color] lists the commands." % UIConfig.color_accent.to_html(false))

	_line = LineEdit.new()
	_line.name = "Input"
	_line.placeholder_text = "command"
	_line.context_menu_enabled = false
	_line.text_submitted.connect(_on_submitted)
	_line.text_changed.connect(func(_t: String) -> void: _completion = PackedStringArray())
	box.add_child(_line)


func _write(text: String) -> void:
	_log.append_text(text + "\n")


func _on_submitted(text: String) -> void:
	var line: String = text.strip_edges()
	_line.clear()
	if line.is_empty():
		return

	if _history.is_empty() or _history[_history.size() - 1] != line:
		_history.append(line)
		if _history.size() > HISTORY_LIMIT:
			_history.remove_at(0)

	_history_at = _history.size()
	execute(line)
	if is_open:
		_line.grab_focus()


func _step_history(direction: int) -> void:
	if _history.is_empty():
		return

	_history_at = clampi(_history_at + direction, 0, _history.size())
	_line.text = _history[_history_at] if _history_at < _history.size() else ""
	_line.caret_column = _line.text.length()


## Tab: completes the command being typed (and cycles through the matches on further presses).
func _complete() -> void:
	if _completion.is_empty():
		var typed: String = _line.text.strip_edges()
		if typed.contains(" "):
			return

		_completion = _commands.complete(typed)
		_completion_at = 0
		if _completion.is_empty():
			return
	else:
		_completion_at = (_completion_at + 1) % _completion.size()

	_line.text = _completion[_completion_at] + " "
	_line.caret_column = _line.text.length()
