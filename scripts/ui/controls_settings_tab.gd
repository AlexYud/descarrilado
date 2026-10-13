extends VBoxContainer
class_name ControlsSettingsTab

## The Controls tab of the options: mouse, key bindings and gameplay options.
## Built from `InputBindings.ACTIONS`, so a new rebindable action shows up here
## by itself.
##
## Rebinding follows the usual pattern of modern games: click a key to listen
## ("Press a key..."), press the new key or a mouse button; Esc or a left click
## cancels, Delete clears the alternate key; a key already in use asks whether to
## swap the two actions or take it from the other; each changed action has its own
## reset, and there is a reset-all with a confirmation.

const KEY_BUTTON_WIDTH: float = 150.0
const NAME_WIDTH: float = 210.0
const RESET_WIDTH: float = 76.0
const EMPTY_SLOT_TEXT: String = "-"

var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _hint_label: Label = null

var _sensitivity_slider: HSlider = null
var _sensitivity_value: Label = null
var _invert_check: CheckButton = null
var _sprint_option: OptionButton = null
var _hints_check: CheckButton = null
var _head_bob_check: CheckButton = null
var _readable_option: OptionButton = null
var _reset_all_button: Button = null

var _confirm_dialog: ConfirmationDialog = null
var _conflict_dialog: ConfirmationDialog = null
var _conflict_replace_button: Button = null

## action -> {"name": Label, "slots": [Button, Button], "reset": Button}
var _rows: Dictionary = {}
## Labels and buttons that carry a localization key, refreshed with the language.
var _texts: Array[Dictionary] = []

var _listening_action: StringName = &""
var _listening_slot: int = -1
var _pending: Dictionary = {}
var _syncing: bool = false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_build()
	InputBindings.bindings_changed.connect(_refresh)
	visibility_changed.connect(_on_visibility_changed)
	refresh()


func is_listening() -> bool:
	return _listening_action != &""


func refresh() -> void:
	_refresh()


func focus_first() -> void:
	if _sensitivity_slider != null:
		_sensitivity_slider.grab_focus()


func cancel_listening() -> void:
	if not is_listening():
		return

	_listening_action = &""
	_listening_slot = -1
	_refresh()
	_set_hint("")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_listening()


# ----------------------------------------------------------------------
# Building the tab
# ----------------------------------------------------------------------

func _build() -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)

	_build_mouse_section()
	_build_keys_section()
	_build_gameplay_section()

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	add_child(footer)

	# What to do now, or why a change was refused; the reset sits beside it.
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.modulate = Color(1.0, 1.0, 1.0, 0.75)
	_hint_label.custom_minimum_size = Vector2(0.0, 44.0)
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_hint_label)

	_reset_all_button = Button.new()
	_reset_all_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_reset_all_button.pressed.connect(_on_reset_all_pressed)
	_style_button(_reset_all_button)
	_track_text(_reset_all_button, "BINDINGS_RESET_ALL")
	footer.add_child(_reset_all_button)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.exclusive = true
	_confirm_dialog.confirmed.connect(_on_reset_all_confirmed)
	add_child(_confirm_dialog)

	_conflict_dialog = ConfirmationDialog.new()
	_conflict_dialog.exclusive = true
	_conflict_dialog.confirmed.connect(func() -> void: _resolve_conflict(&"swap"))
	_conflict_dialog.canceled.connect(_on_conflict_cancelled)
	_conflict_replace_button = _conflict_dialog.add_button("", false, "replace")
	_conflict_dialog.custom_action.connect(_on_conflict_custom_action)
	add_child(_conflict_dialog)


func _build_mouse_section() -> void:
	_add_section("CONTROLS_SECTION_MOUSE")

	var row: HBoxContainer = _add_row("CONTROLS_MOUSE_SENSITIVITY")
	_sensitivity_slider = HSlider.new()
	_sensitivity_slider.min_value = GameSettings.MIN_MOUSE_SENSITIVITY_PERCENT
	_sensitivity_slider.max_value = GameSettings.MAX_MOUSE_SENSITIVITY_PERCENT
	_sensitivity_slider.step = 5.0
	_sensitivity_slider.scrollable = false
	_sensitivity_slider.custom_minimum_size = Vector2(220.0, 0.0)
	_sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	row.add_child(_sensitivity_slider)

	_sensitivity_value = Label.new()
	_sensitivity_value.custom_minimum_size = Vector2(56.0, 0.0)
	_sensitivity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_sensitivity_value)

	row = _add_row("CONTROLS_INVERT_Y")
	_invert_check = CheckButton.new()
	_invert_check.toggled.connect(_on_invert_toggled)
	row.add_child(_invert_check)

	row = _add_row("CONTROLS_HEAD_BOB")
	_head_bob_check = CheckButton.new()
	_head_bob_check.toggled.connect(_on_head_bob_toggled)
	row.add_child(_head_bob_check)


func _build_keys_section() -> void:
	_add_section("CONTROLS_SECTION_KEYS")

	var titles: HBoxContainer = HBoxContainer.new()
	titles.add_theme_constant_override("separation", 8)
	_content.add_child(titles)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	titles.add_child(spacer)
	for key: String in ["BINDINGS_PRIMARY", "BINDINGS_ALTERNATE"]:
		var title: Label = Label.new()
		title.custom_minimum_size = Vector2(KEY_BUTTON_WIDTH, 0.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.modulate = Color(1.0, 1.0, 1.0, 0.6)
		_track_text(title, key)
		titles.add_child(title)

	for category: Dictionary in InputBindings.get_categories():
		var heading: Label = Label.new()
		heading.modulate = Color(0.85, 0.8, 0.65, 0.9)
		_track_text(heading, category["label"])
		_content.add_child(heading)

		for action: StringName in InputBindings.get_actions_in(category["id"]):
			_add_binding_row(action)

		# The way of walking fast belongs next to its key.
		if category["id"] == &"movement":
			_add_sprint_mode_row()


func _build_gameplay_section() -> void:
	_add_section("CONTROLS_SECTION_GAMEPLAY")

	var row: HBoxContainer = _add_row("CONTROLS_TUTORIAL_HINTS")
	_hints_check = CheckButton.new()
	_hints_check.toggled.connect(_on_hints_toggled)
	row.add_child(_hints_check)

	row = _add_row("READABLE_OVERLAY_SETTING")
	_readable_option = OptionButton.new()
	_readable_option.custom_minimum_size = Vector2(300.0, 0.0)
	_readable_option.item_selected.connect(_on_readable_selected)
	row.add_child(_readable_option)


func _add_section(title_key: String) -> void:
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	_track_text(title, title_key)
	_content.add_child(title)
	_content.add_child(HSeparator.new())


## A row with the name on the left; the control goes in the returned container.
func _add_row(name_key: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)

	var name_label: Label = Label.new()
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	_track_text(name_label, name_key)
	row.add_child(name_label)
	return row


func _add_binding_row(action: StringName) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)

	var name_label: Label = Label.new()
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_track_text(name_label, InputBindings.get_action_label_key(action))
	row.add_child(name_label)

	var slots: Array[Button] = []
	for slot: int in InputBindings.SLOT_COUNT:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(KEY_BUTTON_WIDTH, 0.0)
		button.clip_text = true
		_style_button(button)
		button.pressed.connect(_start_listening.bind(action, slot))
		row.add_child(button)
		slots.append(button)

	var reset: Button = Button.new()
	reset.custom_minimum_size = Vector2(RESET_WIDTH, 0.0)
	reset.flat = true
	reset.pressed.connect(_on_reset_action_pressed.bind(action))
	_track_text(reset, "BINDING_RESET")
	row.add_child(reset)

	_rows[action] = {"name": name_label, "slots": slots, "reset": reset}


## Key buttons look like buttons: a dark plate with a thin edge, lighter on hover.
func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _plate(Color(0.16, 0.17, 0.19, 1.0), Color(0.34, 0.35, 0.38, 1.0)))
	button.add_theme_stylebox_override("hover", _plate(Color(0.22, 0.23, 0.26, 1.0), Color(0.55, 0.52, 0.42, 1.0)))
	button.add_theme_stylebox_override("pressed", _plate(Color(0.12, 0.13, 0.15, 1.0), Color(0.7, 0.62, 0.4, 1.0)))
	button.add_theme_stylebox_override("focus", _plate(Color(0.0, 0.0, 0.0, 0.0), Color(0.8, 0.72, 0.5, 1.0)))


func _plate(fill: Color, edge: Color) -> StyleBoxFlat:
	var plate: StyleBoxFlat = StyleBoxFlat.new()
	plate.bg_color = fill
	plate.border_color = edge
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(3)
	plate.content_margin_left = 10.0
	plate.content_margin_right = 10.0
	plate.content_margin_top = 5.0
	plate.content_margin_bottom = 5.0
	return plate


func _add_sprint_mode_row() -> void:
	var row: HBoxContainer = _add_row("CONTROLS_SPRINT_MODE")
	_sprint_option = OptionButton.new()
	_sprint_option.custom_minimum_size = Vector2(KEY_BUTTON_WIDTH, 0.0)
	_sprint_option.item_selected.connect(_on_sprint_mode_selected)
	row.add_child(_sprint_option)


func _track_text(control: Control, key: String) -> void:
	_texts.append({"control": control, "key": key})


# ----------------------------------------------------------------------
# Showing the current state
# ----------------------------------------------------------------------

func _refresh() -> void:
	if _content == null:
		return

	_syncing = true

	for entry: Dictionary in _texts:
		var control: Control = entry["control"]
		control.set("text", tr(entry["key"]))

	for action: Variant in _rows:
		var row: Dictionary = _rows[action]
		var slots: Array = row["slots"]
		for slot: int in slots.size():
			var button: Button = slots[slot]
			var binding: Dictionary = InputBindings.get_binding(action, slot)
			var is_listening_here: bool = action == _listening_action and slot == _listening_slot

			if is_listening_here:
				button.text = tr("BINDING_LISTENING")
			elif binding.is_empty():
				button.text = EMPTY_SLOT_TEXT
			else:
				button.text = InputBindings.label_for_binding(binding)

			button.modulate = (
				Color(1.0, 0.92, 0.6, 1.0) if is_listening_here
				else Color(1.0, 1.0, 1.0, 0.45 if binding.is_empty() else 1.0)
			)

		# Only changed actions offer a reset; the space stays so the rows line up.
		var changed: bool = not InputBindings.is_default(action)
		var reset: Button = row["reset"]
		reset.modulate.a = 1.0 if changed else 0.0
		reset.disabled = not changed
		reset.focus_mode = Control.FOCUS_ALL if changed else Control.FOCUS_NONE

	_sensitivity_slider.value = GameSettings.get_mouse_sensitivity_percent()
	_sensitivity_value.text = "%d%%" % roundi(GameSettings.get_mouse_sensitivity_percent())
	_invert_check.set_pressed_no_signal(GameSettings.get_invert_y())
	_head_bob_check.set_pressed_no_signal(GameSettings.get_head_bob_enabled())
	_hints_check.set_pressed_no_signal(GameSettings.get_tutorial_hints())

	_sprint_option.clear()
	_sprint_option.add_item(tr("CONTROLS_SPRINT_HOLD"), 0)
	_sprint_option.add_item(tr("CONTROLS_SPRINT_TOGGLE"), 1)
	_sprint_option.select(1 if GameSettings.get_sprint_toggle() else 0)

	_readable_option.clear()
	_readable_option.add_item(tr("READABLE_OVERLAY_AUTO"), GameSettings.ReadableText.AUTO)
	_readable_option.add_item(tr("READABLE_OVERLAY_ALWAYS"), GameSettings.ReadableText.ALWAYS)
	_readable_option.add_item(tr("READABLE_OVERLAY_NEVER"), GameSettings.ReadableText.NEVER)
	_readable_option.select(GameSettings.get_readable_text_mode())

	_syncing = false


func _set_hint(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


# ----------------------------------------------------------------------
# Rebinding
# ----------------------------------------------------------------------

func _start_listening(action: StringName, slot: int) -> void:
	_listening_action = action
	_listening_slot = slot
	_refresh()
	_set_hint(tr("BINDING_LISTEN_HINT"))


func _input(event: InputEvent) -> void:
	if not is_listening() or not is_visible_in_tree():
		return

	if _conflict_dialog.visible or _confirm_dialog.visible:
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			# The release of the key that started the listening, and repeats.
			get_viewport().set_input_as_handled()
			return

		get_viewport().set_input_as_handled()
		var code: int = key_event.physical_keycode
		if code == 0:
			code = key_event.keycode

		if code == KEY_ESCAPE:
			cancel_listening()
			return

		if code == KEY_DELETE or code == KEY_BACKSPACE:
			_clear_listening_slot()
			return

		_bind(InputBindings.binding_from_event(event))
		return

	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			cancel_listening()
			return

		_bind(InputBindings.binding_from_event(event))


func _clear_listening_slot() -> void:
	var action: StringName = _listening_action
	var slot: int = _listening_slot
	var cleared: bool = InputBindings.clear_binding(action, slot)
	_listening_action = &""
	_listening_slot = -1
	_refresh()
	_set_hint("" if cleared else tr("BINDING_LAST_KEY"))


func _bind(binding: Dictionary) -> void:
	if binding.is_empty() or not InputBindings.is_binding_allowed(binding):
		return

	var action: StringName = _listening_action
	var slot: int = _listening_slot
	var result: Dictionary = InputBindings.set_binding(action, slot, binding)

	if bool(result.get("ok", false)):
		_finish_listening()
		return

	if result.get("reason", "") == "conflict":
		_ask_about_conflict(action, slot, binding, result)
		return

	_finish_listening()
	_set_hint(tr("BINDING_LAST_KEY"))


func _finish_listening() -> void:
	_listening_action = &""
	_listening_slot = -1
	_refresh()
	_set_hint("")


func _ask_about_conflict(action: StringName, slot: int, binding: Dictionary, result: Dictionary) -> void:
	var conflict: Dictionary = result["conflict"]
	var other: StringName = conflict["action"]
	var key_label: String = InputBindings.label_for_binding(binding)
	var other_name: String = tr(InputBindings.get_action_label_key(other))

	var can_swap: bool = bool(result["can_swap"])
	var can_replace: bool = bool(result["can_replace"])

	if not can_swap and not can_replace:
		# The other action would be left with no key: say so instead of asking.
		_finish_listening()
		_set_hint(
			tr("BINDING_CONFLICT_BLOCKED").format({"key": key_label, "action": other_name})
		)
		return

	_pending = {"action": action, "slot": slot, "binding": binding}
	_conflict_dialog.title = tr("BINDING_CONFLICT_TITLE")
	_conflict_dialog.dialog_text = tr("BINDING_CONFLICT_TEXT").format(
		{"key": key_label, "action": other_name}
	)
	_conflict_dialog.ok_button_text = tr("BINDING_CONFLICT_SWAP")
	_conflict_dialog.cancel_button_text = tr("BINDING_CONFLICT_CANCEL")
	_conflict_replace_button.text = tr("BINDING_CONFLICT_REPLACE")
	_conflict_dialog.get_ok_button().disabled = not can_swap
	_conflict_replace_button.disabled = not can_replace
	_conflict_dialog.popup_centered()


func _on_conflict_custom_action(action_name: StringName) -> void:
	if action_name == &"replace":
		_conflict_dialog.hide()
		_resolve_conflict(&"replace")


func _resolve_conflict(resolution: StringName) -> void:
	if _pending.is_empty():
		return

	var result: Dictionary = InputBindings.set_binding(
		_pending["action"], _pending["slot"], _pending["binding"], resolution
	)
	_pending = {}
	_finish_listening()

	if not bool(result.get("ok", false)):
		_set_hint(tr("BINDING_LAST_KEY"))


func _on_conflict_cancelled() -> void:
	_pending = {}
	_finish_listening()


func _on_reset_action_pressed(action: StringName) -> void:
	cancel_listening()
	InputBindings.reset_action(action)


func _on_reset_all_pressed() -> void:
	cancel_listening()
	_confirm_dialog.title = tr("BINDINGS_RESET_TITLE")
	_confirm_dialog.dialog_text = tr("BINDINGS_RESET_TEXT")
	_confirm_dialog.ok_button_text = tr("BINDINGS_RESET_TITLE")
	_confirm_dialog.cancel_button_text = tr("BINDING_CONFLICT_CANCEL")
	_confirm_dialog.popup_centered()


func _on_reset_all_confirmed() -> void:
	GameSettings.reset_controls_to_default()
	InputBindings.reset_all()
	_refresh()


# ----------------------------------------------------------------------
# Other controls
# ----------------------------------------------------------------------

func _on_sensitivity_changed(value: float) -> void:
	if _syncing:
		return

	GameSettings.set_mouse_sensitivity_percent(value)
	_sensitivity_value.text = "%d%%" % roundi(value)


func _on_invert_toggled(enabled: bool) -> void:
	if not _syncing:
		GameSettings.set_invert_y(enabled)


func _on_head_bob_toggled(enabled: bool) -> void:
	if not _syncing:
		GameSettings.set_head_bob_enabled(enabled)


func _on_sprint_mode_selected(index: int) -> void:
	if not _syncing:
		GameSettings.set_sprint_toggle(index == 1)


func _on_hints_toggled(enabled: bool) -> void:
	if not _syncing:
		GameSettings.set_tutorial_hints(enabled)


func _on_readable_selected(index: int) -> void:
	if not _syncing:
		GameSettings.set_readable_text_mode(index)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_listening()
		if _conflict_dialog != null and _conflict_dialog.visible:
			_conflict_dialog.hide()
