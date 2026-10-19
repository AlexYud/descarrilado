extends CanvasLayer
class_name FinaleStruggle

## The button-mash struggle (the "quick time event" of the finale): the player presses the interact key again and again to hold
## a bar up against what is dragging them away. It is built the way these prompts usually are:
##   - the key and a bar, low and in the middle of the screen, in the game's own look (UIConfig colours, labels);
##   - every press pushes the bar up one step and the key cap kicks, so each press is felt.
## The tuning is the finale's: it is a struggle that cannot be won, but that is fair at the start. First the prompt is given time to be
## seen (`reaction_seconds`: the key throbs and the bar holds until the player presses, or for two seconds after it has
## faded in). Then the bar drains, slowly at first (a player who does nothing still has a couple of seconds of it), and the drain grows
## exponentially with every second (`decay_growth_rate`): each press is one step up, but the bar is always on its way down, and by about
## the fifth second of it the drain is far beyond what any hands can answer, however fast. The bar can never be filled
## (`max_progress`), so the player is always captured: `failed` is the only way it ends.
## The scene reads `progress` (0 to 1) to show the struggle (the thing that drags the player slides back as the bar drains).

signal failed
signal pressed(progress: float)

const KEY_TEXT_SIZE: int = 46

@export var action: StringName = &"interact"
## Presses from empty to full (one press is one step of the bar).
@export var presses_needed: int = 50
## Where the bar starts (so the first press already shows).
@export_range(0.0, 0.9, 0.01) var start_progress: float = 0.55
## How fast the bar drains at the start (per second), and how fast that rate grows: it is multiplied by `exp(decay_growth_rate)` every
## second since the drain began (the drain is exponential: slow enough to react to, then nothing can hold it).
@export var decay_per_second: float = 0.08
@export var decay_growth_rate: float = 0.75
## The bar can never be filled higher than this: there is no winning it with the hands.
@export_range(0.5, 1.0, 0.01) var max_progress: float = 0.95
## Time the player has before the bar starts to drain by itself, counted from when the prompt starts to fade in (a quarter of a second
## of that is the fade): the key throbs and the bar holds, so that there is time to see what is asked and to start. Pressing the key
## starts the drain at once.
@export var reaction_seconds: float = 2.25

var progress: float = 0.0
var active: bool = false

var _elapsed: float = 0.0
## True from the first press (or when the reaction time is over): the bar drains from then on.
var _started: bool = false
var _since_start: float = 0.0
var _root: Control = null
var _key_panel: PanelContainer = null
var _key_label: Label = null
var _prompt: Label = null
var _bar_back: ColorRect = null
var _bar_fill: ColorRect = null
var _kick: Tween = null


func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_process_input(false)


## Starts the struggle: the prompt appears and the bar starts to be read.
func begin() -> void:
	_build_ui()
	progress = start_progress
	_elapsed = 0.0
	_started = false
	_since_start = 0.0
	active = true
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	set_process(true)
	set_process_input(true)
	_refresh()


## Ends it and takes the prompt away.
func end() -> void:
	active = false
	set_process(false)
	set_process_input(false)
	if _root != null:
		var fade: Tween = create_tween()
		fade.tween_property(_root, "modulate:a", 0.0, 0.2)
		fade.tween_callback(func() -> void: _root.visible = false)


func _input(event: InputEvent) -> void:
	if not active:
		return

	if event.is_action_pressed(action) and not event.is_echo():
		progress = minf(progress + 1.0 / float(maxi(presses_needed, 1)), max_progress)
		_started = true
		pressed.emit(progress)
		_kick_key()
		get_viewport().set_input_as_handled()
		_refresh()


func _process(delta: float) -> void:
	if not active:
		return

	_elapsed += delta
	if not _started and _elapsed >= reaction_seconds:
		_started = true

	if _started:
		_since_start += delta
		progress = maxf(progress - current_decay() * delta, 0.0)
	else:
		# Waiting for the first press: the key cap throbs.
		_key_panel.scale = Vector2.ONE * (1.0 + 0.07 * sin(_elapsed * 9.0))

	_refresh()
	if progress <= 0.0 and _started:
		_finish()


## How fast the bar is draining now (per second): it grows with every second since the drain began.
func current_decay() -> float:
	return decay_per_second * exp(decay_growth_rate * _since_start)


func _finish() -> void:
	active = false
	set_process(false)
	set_process_input(false)
	failed.emit()
	end()


func _kick_key() -> void:
	if _kick != null and _kick.is_valid():
		_kick.kill()

	_key_panel.scale = Vector2.ONE * 1.22
	_kick = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_kick.tween_property(_key_panel, "scale", Vector2.ONE, 0.14)


func _refresh() -> void:
	if _bar_fill == null:
		return

	var width: float = _bar_back.size.x
	_bar_fill.size = Vector2(width * progress, _bar_back.size.y)
	# The bar goes from the muted colour to the accent as it fills, and flashes the danger colour when nearly empty.
	var colour: Color = UIConfig.color_disabled.lerp(UIConfig.color_bright, progress)
	if progress < 0.25:
		colour = UIConfig.color_danger.lerp(UIConfig.color_bright, 0.35 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 70.0)))

	_bar_fill.color = colour


func _build_ui() -> void:
	if _root != null:
		_prompt.text = _prompt_text()
		_key_label.text = _key_text()
		return

	_root = Control.new()
	_root.name = "Struggle"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_bottom = -88.0
	column.add_theme_constant_override(&"separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)

	_prompt = Label.new()
	_prompt.theme_type_variation = &"HintLabel"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.text = _prompt_text()
	column.add_child(_prompt)

	var key_row: CenterContainer = CenterContainer.new()
	key_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(key_row)
	_key_panel = PanelContainer.new()
	_key_panel.theme_type_variation = &"NotePanel"
	_key_panel.custom_minimum_size = Vector2(104.0, 104.0)
	_key_panel.pivot_offset = Vector2(52.0, 52.0)
	key_row.add_child(_key_panel)
	_key_label = Label.new()
	_key_label.text = _key_text()
	_key_label.add_theme_font_size_override(&"font_size", KEY_TEXT_SIZE)
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_panel.add_child(_key_label)

	var bar_row: CenterContainer = CenterContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_row)
	# A frame (so the empty bar can be seen against the dark), and the bar inside it.
	var frame: ColorRect = ColorRect.new()
	frame.color = UIConfig.color_disabled
	frame.custom_minimum_size = Vector2(432.0, 22.0)
	bar_row.add_child(frame)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(UIConfig.color_panel, 1.0)
	_bar_back.position = Vector2(3.0, 3.0)
	_bar_back.size = Vector2(426.0, 16.0)
	frame.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = UIConfig.color_disabled
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_child(_bar_fill)
	_bar_fill.size = Vector2(0.0, 16.0)


func _key_text() -> String:
	return InputBindings.get_binding_label(action, -1, true)


func _prompt_text() -> String:
	return tr("STRUGGLE_PROMPT") % _key_text()
