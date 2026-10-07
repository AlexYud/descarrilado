extends CanvasLayer
class_name CombinationLockView

## Close-up of a CombinationLock: one brass wheel per digit with an arrow above
## and below. Click the arrows or scroll over a wheel to turn it; the lock
## itself decides when the code is right. Esc, right click or the back button
## step away.
##
## The UI is built in code, like the album close-up. Everything the mouse does
## goes through `turn()`, so tests can drive it.

const VIEW_LAYER: int = 20
const CLOSE_DELAY_AFTER_UNLOCK: float = 0.9

var lock: CombinationLock = null

var _player: Node = null
var _open: bool = false

var _title_label: Label = null
var _hint_label: Label = null
var _back_button: Button = null
var _digit_labels: Array[Label] = []


func setup(owner_lock: CombinationLock) -> void:
	lock = owner_lock
	layer = VIEW_LAYER
	visible = false
	_build_ui()

	lock.unlocked.connect(_on_unlocked)
	GameSettings.text_language_changed.connect(_on_text_language_changed)


func is_open() -> bool:
	return _open


func open(player: Node) -> void:
	if _open:
		return

	_open = true
	_player = player
	visible = true
	_player.call("set_modal_ui_open", true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()
	lock.opened.emit()


func close() -> void:
	if not _open:
		return

	_open = false
	visible = false
	_player.call("set_modal_ui_open", false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	lock.closed.emit()


## Turns wheel `index` one step up (+1) or down (-1).
func turn(index: int, step: int) -> void:
	lock.turn_wheel(index, step)
	_refresh()


func _input(event: InputEvent) -> void:
	if not _open:
		return

	var closes: bool = event.is_action_pressed("ui_cancel")
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	):
		closes = true

	if closes:
		close()
		get_viewport().set_input_as_handled()


func _on_unlocked() -> void:
	_refresh()
	if not _open:
		return

	await get_tree().create_timer(CLOSE_DELAY_AFTER_UNLOCK).timeout
	close()


func _on_text_language_changed(_locale: String) -> void:
	_apply_texts()


# ============================================================
# UI
# ============================================================

func _refresh() -> void:
	for i: int in _digit_labels.size():
		_digit_labels[i].text = str(lock.digits[i])


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 20)
	center.add_child(column)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override(&"font_size", 28)
	column.add_child(_title_label)

	column.add_child(_build_wheels())

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	column.add_child(_hint_label)

	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(160.0, 40.0)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(close)
	column.add_child(_back_button)

	_apply_texts()


func _build_wheels() -> Control:
	var plate: PanelContainer = PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.add_theme_stylebox_override(
		&"panel",
		_make_style(Color(0.36, 0.27, 0.1), Color(0.18, 0.13, 0.05), 4)
	)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	plate.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	for i: int in lock.code.size():
		row.add_child(_build_wheel(i))

	return plate


func _build_wheel(index: int) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)

	var up: ArrowButton = ArrowButton.new()
	up.pointing_up = true
	up.pressed.connect(turn.bind(index, 1))
	column.add_child(up)

	var window: PanelContainer = PanelContainer.new()
	window.custom_minimum_size = Vector2(90.0, 120.0)
	window.add_theme_stylebox_override(
		&"panel",
		_make_style(Color(0.07, 0.06, 0.04), Color(0.55, 0.45, 0.2), 3)
	)
	# Scrolling over the wheel turns it.
	window.gui_input.connect(_on_wheel_gui_input.bind(index))
	column.add_child(window)

	var digit: Label = Label.new()
	digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	digit.add_theme_font_size_override(&"font_size", 72)
	digit.add_theme_color_override(&"font_color", Color(0.92, 0.82, 0.5))
	window.add_child(digit)
	_digit_labels.append(digit)

	var down: ArrowButton = ArrowButton.new()
	down.pointing_up = false
	down.pressed.connect(turn.bind(index, -1))
	column.add_child(down)

	return column


func _on_wheel_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		turn(index, 1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		turn(index, -1)


func _apply_texts() -> void:
	_title_label.text = tr("LOCK_VIEW_TITLE")
	_hint_label.text = tr("LOCK_VIEW_HINT")
	_back_button.text = tr("OPTIONS_BACK")


func _make_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style


## A flat button with a triangle, so no font needs an arrow glyph.
class ArrowButton extends Button:
	var pointing_up: bool = true

	func _init() -> void:
		custom_minimum_size = Vector2(90.0, 34.0)
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var middle: float = size.x * 0.5
		var top: float = size.y * 0.3
		var bottom: float = size.y * 0.7
		var points: PackedVector2Array
		if pointing_up:
			points = PackedVector2Array([
				Vector2(middle, top), Vector2(middle + 14.0, bottom), Vector2(middle - 14.0, bottom)
			])
		else:
			points = PackedVector2Array([
				Vector2(middle, bottom), Vector2(middle + 14.0, top), Vector2(middle - 14.0, top)
			])

		draw_colored_polygon(points, Color(0.92, 0.82, 0.5))
