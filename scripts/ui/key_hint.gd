extends HBoxContainer
class_name KeyHint

## A key cap and a word, "[E] Read" in the quiet style of the game's few on-screen
## prompts: the key in a thin outlined box, the word beside it. Clickable, for
## players using the mouse. Used by the inspect view (the prompt to read, the way
## back) so every prompt looks the same.

signal pressed

var _key_panel: PanelContainer = null
var _key_label: Label = null
var _text_label: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 10)

	_key_panel = PanelContainer.new()
	_key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The key cap: a thin white box, over a light panel tint (UIConfig, so a new palette restyles it).
	var cap: StyleBoxFlat = UIConfig.panel_style(UIConfig.color_bright, 0.5, Vector2i(9, 3))
	cap.set_border_width_all(2)
	cap.shadow_size = 0
	_key_panel.add_theme_stylebox_override("panel", cap)
	add_child(_key_panel)

	_key_label = Label.new()
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_panel.add_child(_key_label)

	_text_label = Label.new()
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_text_label)

	# HintLabel: the text colour with an outline, readable over the 3D world.
	for label: Label in [_key_label, _text_label]:
		label.theme_type_variation = &"HintLabel"


## `key_text` goes in the cap (empty hides the cap); `text` is the word beside it.
func set_hint(key_text: String, text: String, font_size: int, font: Font = null) -> void:
	_key_label.text = key_text
	_key_panel.visible = not key_text.is_empty()
	_text_label.text = text

	for label: Label in [_key_label, _text_label]:
		label.add_theme_font_size_override("font_size", font_size)
		if font != null:
			label.add_theme_font_override("font", font)

	size = get_combined_minimum_size()


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		pressed.emit()
		accept_event()
