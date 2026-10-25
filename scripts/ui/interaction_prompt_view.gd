extends PanelContainer
class_name InteractionPromptView

## The prompt over what the player looks at ("[E] Pick Up", "[E] Inspect"): drawn as every other prompt of the game is, a squared key cap and
## a word (`KeyHint`), here on a panel of the theme (squared, dark, with its border and soft shadow). The panel is what keeps it readable where
## the flashlight is brightest: white text over a white circle cannot be read, whatever its outline; contrast comes from the backing.
## It is small and placed a little under the middle of the screen so that it does not cover what the player is looking at (developer
## feedback: the first size, 2% of the screen's height with the theme's roomy padding, hid the item behind it), and its panel is a little
## see through.

## Where the prompt sits: its middle, as a fraction of the screen's height.
const HEIGHT_RATIO: float = 0.62
const BODY_FONT_RATIO: float = 0.0148
const MIN_FONT_SIZE: int = 12
## The panel: how much of the panel colour shows through it, and the padding round the cap and the word.
const PANEL_ALPHA: float = 0.8
const PANEL_PADDING: Vector2i = Vector2i(9, 3)

var _hint: KeyHint = null
var _text: String = ""


func _init() -> void:
	name = "InteractionPromptView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# The theme's panel (squared, bordered, with its soft shadow), made snug and a little see through.
	var style: StyleBoxFlat = UIConfig.panel_style(Color(0.0, 0.0, 0.0, 0.0), PANEL_ALPHA, PANEL_PADDING)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)
	_hint = KeyHint.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	InputBindings.bindings_changed.connect(_layout)


## Shows `text` as written for the prompt: the key in brackets first ("[E] Pick Up", the key already replaced by the player's own).
func show_prompt(text: String) -> void:
	_text = text
	_layout()
	visible = true


func hide_prompt() -> void:
	_text = ""
	visible = false


## What the prompt says now, as the player reads it ("[E] Pick Up"); empty when it is not shown.
func get_text() -> String:
	return _text if visible else ""


## The key (without its brackets) and the word of a prompt text: "[E] Pick Up" is ("E", "Pick Up"); a text with no key is ("", text).
static func split_text(text: String) -> PackedStringArray:
	if text.begins_with("["):
		var close: int = text.find("]")
		if close > 1:
			return PackedStringArray([text.substr(1, close - 1), text.substr(close + 1).strip_edges()])

	return PackedStringArray(["", text])


func _layout() -> void:
	if _hint == null or _text.is_empty() or not is_inside_tree():
		return

	var screen: Vector2 = get_viewport().get_visible_rect().size
	screen = Vector2(maxf(screen.x, 320.0), maxf(screen.y, 240.0))
	var scale_setting: float = float(GameSettings.get_caption_font_size()) / float(GameSettings.CAPTION_FONT_SIZES[GameSettings.DEFAULT_CAPTION_SIZE])
	var body: int = maxi(int(round(screen.y * BODY_FONT_RATIO * scale_setting)), MIN_FONT_SIZE)
	var parts: PackedStringArray = split_text(_text)
	_hint.set_hint(parts[0], parts[1], body, UIConfig.font(UIConfig.weight_body, UIConfig.spacing_body))
	# The panel is as big as its contents; it is centred on the screen's middle line at `HEIGHT_RATIO`.
	reset_size()
	var panel_size: Vector2 = get_combined_minimum_size()
	size = panel_size
	position = Vector2((screen.x - panel_size.x) * 0.5, screen.y * HEIGHT_RATIO - panel_size.y * 0.5).round()
