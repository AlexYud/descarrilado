extends CanvasLayer
class_name HoldToSkip

## The "Hold [key] to Skip" prompt of the intro cinematic, for a scene played in the game (the unfinished house's flashback): the same words, the same
## panel in the same corner, the same behaviour. It is hidden until the player presses something (a key, a mouse button, a pad button); it then shows for
## `visible_seconds` after the last press (and for as long as the skip key is held), with a bar that fills while it is held; holding the key for `hold_seconds`
## raises `skipped`. A key that was already down when it was armed must be let go first. It follows the game's pause (nothing counts while paused).

signal skipped

## The action held (the intro's own, `skip_cinematic`), how long it is held, and how long the prompt stays after the last press.
@export var action: StringName = &"skip_cinematic"
@export var hold_seconds: float = 1.25
@export var visible_seconds: float = 3.5

## The panel and its bar (for tests).
var panel: PanelContainer = null
var label: Label = null
var bar: ProgressBar = null

var _armed: bool = false
var _waiting_for_release: bool = false
var _held: float = 0.0
var _shown_until_msec: int = 0


func _ready() -> void:
	layer = 900
	_build()
	panel.hide()
	set_process(false)
	set_process_input(false)


## The prompt, as the menu's scene has it (default theme, bottom right, a label over a thin bar).
func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "SkipPrompt"
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -310.0
	panel.offset_top = -96.0
	panel.offset_right = -32.0
	panel.offset_bottom = -30.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(label)

	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 7.0)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	box.add_child(bar)
	_refresh_text()


func _refresh_text() -> void:
	if label != null:
		label.text = InputBindings.format_text(tr("CINEMATIC_HOLD_SKIP"))


## Starts listening (the prompt stays hidden until something is pressed).
func arm() -> void:
	_armed = true
	_held = 0.0
	bar.value = 0.0
	_waiting_for_release = InputMap.has_action(action) and Input.is_action_pressed(action)
	_shown_until_msec = 0
	panel.hide()
	_refresh_text()
	set_process(true)
	set_process_input(true)


## Stops listening and hides the prompt.
func disarm() -> void:
	_armed = false
	_held = 0.0
	panel.hide()
	set_process(false)
	set_process_input(false)


func is_armed() -> bool:
	return _armed


func _input(event: InputEvent) -> void:
	if not _armed or _waiting_for_release:
		return

	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if pressed:
		_reveal()


func _reveal() -> void:
	_shown_until_msec = Time.get_ticks_msec() + int(visible_seconds * 1000.0)
	panel.show()


func _process(delta: float) -> void:
	if not _armed or not InputMap.has_action(action):
		return

	var down: bool = Input.is_action_pressed(action)
	if _waiting_for_release:
		if not down:
			_waiting_for_release = false
		return

	# On screen while the key is held and for a moment after the last press, then gone again.
	if down:
		_reveal()
	elif panel.visible and Time.get_ticks_msec() > _shown_until_msec:
		panel.hide()

	if not down:
		_held = 0.0
		bar.value = 0.0
		return

	_held += delta
	bar.value = clampf(_held / maxf(hold_seconds, 0.05), 0.0, 1.0)
	if _held >= hold_seconds:
		disarm()
		skipped.emit()
