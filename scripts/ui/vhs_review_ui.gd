extends CanvasLayer
class_name VhsReviewUi

## The transport row of the waiting shed's voluntary tape review: a small bottom row of standard symbols (rewind, play, pause, stop, fast-forward, close) that can be clicked, with a hint line that names the
## keys really bound. It only exists in the review (never over the directed first viewing nor the physical viewfinder) and only reports what was asked: the shed's sequence owns the tape's clock.
## The symbols are drawn as shapes (no font glyphs needed); every button has a localized tooltip.

signal play_pause_requested
signal stop_requested
## A rewind (-1) or a fast-forward (+1) search began or ended (a button held down, or released).
signal search_started(direction: int)
signal search_ended
signal close_requested

const BUTTON_SIZE: Vector2 = Vector2(64.0, 44.0)

var buttons: Dictionary = {}
var hint: Label = null

var _row: HBoxContainer = null


## One symbol: a flat panel with a drawn shape, highlighted while hovered, pressed or `active`.
class TransportButton extends Control:
	signal pressed_down
	signal released

	var kind: StringName = &"play"
	var active: bool = false
	var _hover: bool = false
	var _down: bool = false

	func _init(button_kind: StringName, tooltip_key: String) -> void:
		kind = button_kind
		name = String(button_kind).capitalize()
		custom_minimum_size = BUTTON_SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = tooltip_key
		focus_mode = Control.FOCUS_NONE
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			if _down:
				_down = false
				released.emit()
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click == null or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed and not _down:
			_down = true
			pressed_down.emit()
		elif not click.pressed and _down:
			_down = false
			released.emit()
		accept_event()
		queue_redraw()

	func _draw() -> void:
		var shade: Color = Color(0.1, 0.1, 0.11, 0.86)
		if active:
			shade = Color(0.32, 0.34, 0.3, 0.92)
		elif _down:
			shade = Color(0.26, 0.26, 0.24, 0.92)
		elif _hover:
			shade = Color(0.2, 0.2, 0.19, 0.9)
		draw_rect(Rect2(Vector2.ZERO, size), shade)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.7, 0.55), false, 1.5)
		var ink: Color = Color(0.9, 0.93, 0.85, 0.95)
		var c: Vector2 = size * 0.5
		var h: float = 11.0
		match kind:
			&"play":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.7, -h), c + Vector2(h, 0), c + Vector2(-h * 0.7, h)]), ink)
			&"pause":
				draw_rect(Rect2(c + Vector2(-h * 0.8, -h), Vector2(h * 0.55, h * 2.0)), ink)
				draw_rect(Rect2(c + Vector2(h * 0.25, -h), Vector2(h * 0.55, h * 2.0)), ink)
			&"stop":
				draw_rect(Rect2(c - Vector2(h * 0.9, h * 0.9), Vector2(h * 1.8, h * 1.8)), ink)
			&"rewind":
				for k: int in 2:
					var x: float = c.x + (k - 1) * h * 1.05 + h * 0.5
					draw_colored_polygon(PackedVector2Array([Vector2(x + h * 0.9, c.y - h * 0.85), Vector2(x - h * 0.2, c.y), Vector2(x + h * 0.9, c.y + h * 0.85)]), ink)
			&"forward":
				for k: int in 2:
					var x2: float = c.x + (k - 1) * h * 1.05 - h * 0.5
					draw_colored_polygon(PackedVector2Array([Vector2(x2 - h * 0.9, c.y - h * 0.85), Vector2(x2 + h * 0.2, c.y), Vector2(x2 - h * 0.9, c.y + h * 0.85)]), ink)
			&"close":
				draw_line(c + Vector2(-h * 0.8, -h * 0.8), c + Vector2(h * 0.8, h * 0.8), ink, 3.0)
				draw_line(c + Vector2(-h * 0.8, h * 0.8), c + Vector2(h * 0.8, -h * 0.8), ink, 3.0)


func _init() -> void:
	name = "VhsReviewUi"
	layer = 12
	visible = false


func _ready() -> void:
	var root: Control = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hint = Label.new()
	hint.name = "Hint"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -62.0
	hint.offset_bottom = -22.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override(&"font_size", 20)
	hint.add_theme_color_override(&"font_color", Color(0.9, 0.92, 0.86, 0.92))
	hint.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	hint.add_theme_constant_override(&"outline_size", 5)
	root.add_child(hint)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", 8)
	_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_row.offset_top = -118.0
	_row.offset_bottom = -68.0
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_row)

	for spec: Array in [[&"rewind", "VHS_REWIND"], [&"play", "VHS_PLAY"], [&"pause", "VHS_PAUSE"], [&"stop", "VHS_STOP"], [&"forward", "VHS_FORWARD"], [&"close", "VHS_CLOSE"]]:
		var button: TransportButton = TransportButton.new(spec[0], tr(spec[1]))
		buttons[spec[0]] = button
		_row.add_child(button)

	(buttons[&"play"] as TransportButton).pressed_down.connect(func() -> void: play_pause_requested.emit())
	(buttons[&"pause"] as TransportButton).pressed_down.connect(func() -> void: play_pause_requested.emit())
	(buttons[&"stop"] as TransportButton).pressed_down.connect(func() -> void: stop_requested.emit())
	(buttons[&"close"] as TransportButton).pressed_down.connect(func() -> void: close_requested.emit())
	(buttons[&"rewind"] as TransportButton).pressed_down.connect(func() -> void: search_started.emit(-1))
	(buttons[&"rewind"] as TransportButton).released.connect(func() -> void: search_ended.emit())
	(buttons[&"forward"] as TransportButton).pressed_down.connect(func() -> void: search_started.emit(1))
	(buttons[&"forward"] as TransportButton).released.connect(func() -> void: search_ended.emit())
	refresh_text()


## The hint line, with the keys the player really has bound (`{left}` and so on become their names); and the tooltips in the interface language.
func refresh_text() -> void:
	if hint != null:
		hint.text = InputBindings.format_text(tr("VHS_REVIEW_HINT"))
	var keys: Dictionary = {&"rewind": "VHS_REWIND", &"play": "VHS_PLAY", &"pause": "VHS_PAUSE", &"stop": "VHS_STOP", &"forward": "VHS_FORWARD", &"close": "VHS_CLOSE"}
	for kind: StringName in keys.keys():
		if buttons.has(kind):
			(buttons[kind] as TransportButton).tooltip_text = tr(keys[kind])


## Shows which state the tape is in (`play`, `pause`, `stop`, `rew`, `ff`) on the buttons.
func set_state(state: StringName) -> void:
	for kind: StringName in buttons.keys():
		var button: TransportButton = buttons[kind] as TransportButton
		button.active = (
			(kind == &"play" and state == &"play")
			or (kind == &"pause" and state == &"pause")
			or (kind == &"stop" and state == &"stop")
			or (kind == &"rewind" and state == &"rew")
			or (kind == &"forward" and state == &"ff")
		)
		button.queue_redraw()
