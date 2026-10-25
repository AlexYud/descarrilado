extends CanvasLayer
class_name CollectPrompt

## The bottom row shown while the player is close up to something that is still where it hangs, and can be taken or left: the
## item's name at the left, and "[E] Collect" and "[Esc] Back" at the right, in the same quiet style (and the same column, font and
## size) as the inspect view's name and "Esc Close" (`KeyHint`, `UIConfig`). It does not read keys: whoever shows it listens for them
## (`PinnedCollectible`); the two hints are also clickable, for players using the mouse.

signal collect_pressed
signal back_pressed

const FADE_SECONDS: float = 0.3
## The same proportions as the inspect view's bottom row.
const COLUMN_HEIGHT_RATIO: float = 0.56
const BODY_FONT_RATIO: float = 0.0172
const ROW_TOP_RATIO: float = 0.915

var _root: Control = null
var _title: Label = null
var _collect: KeyHint = null
var _back: KeyHint = null
var _name_key: String = ""
var _tween: Tween = null
var _wanted: bool = false


func _init() -> void:
	name = "CollectPrompt"
	layer = 14
	visible = false


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)

	_title = Label.new()
	_title.name = "Title"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.theme_type_variation = &"ItemTitleLabel"
	_root.add_child(_title)

	_collect = KeyHint.new()
	_collect.name = "Collect"
	_collect.pressed.connect(func() -> void: collect_pressed.emit())
	_root.add_child(_collect)

	_back = KeyHint.new()
	_back.name = "Back"
	_back.pressed.connect(func() -> void: back_pressed.emit())
	_root.add_child(_back)

	get_viewport().size_changed.connect(_layout)
	InputBindings.bindings_changed.connect(_layout)


## Shows the row for the item called `name_key` (a localization key).
func show_prompt(name_key: String) -> void:
	_wanted = true
	_name_key = name_key
	_layout()
	visible = true
	_fade_to(1.0)


func hide_prompt() -> void:
	_wanted = false
	_fade_to(0.0)


## True from `show_prompt` until `hide_prompt`.
func is_showing() -> bool:
	return _wanted


func _fade_to(alpha: float) -> void:
	if _root == null:
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", alpha, FADE_SECONDS)
	if alpha <= 0.0:
		_tween.tween_callback(func() -> void: visible = false)


func _layout() -> void:
	if _root == null or not is_inside_tree():
		return

	var screen: Vector2 = get_viewport().get_visible_rect().size
	screen = Vector2(maxf(screen.x, 320.0), maxf(screen.y, 240.0))
	var column: float = minf(screen.x * 0.94, screen.y * COLUMN_HEIGHT_RATIO)
	var left: float = (screen.x - column) * 0.5
	var scale_setting: float = float(GameSettings.get_caption_font_size()) / float(GameSettings.CAPTION_FONT_SIZES[GameSettings.DEFAULT_CAPTION_SIZE])
	var body: int = maxi(int(round(screen.y * BODY_FONT_RATIO * scale_setting)), 13)
	var row_top: float = screen.y * ROW_TOP_RATIO
	var font: Font = UIConfig.font(UIConfig.weight_body, UIConfig.spacing_body)

	_collect.set_hint(InputBindings.get_binding_label(&"interact", -1, true), tr("PROMPT_COLLECT"), body, font)
	_back.set_hint(tr("KEY_NAME_ESCAPE"), tr("INSPECT_BACK"), body, font)
	var gap: float = float(body) * 2.0
	var hints_width: float = _collect.size.x + gap + _back.size.x
	_collect.position = Vector2(left + column - hints_width, row_top)
	_back.position = Vector2(left + column - _back.size.x, row_top)

	_title.text = tr(_name_key) if not _name_key.is_empty() else ""
	_title.add_theme_font_size_override("font_size", int(float(body) * 1.2))
	_title.position = Vector2(left, row_top)
	_title.size = Vector2(maxf(column - hints_width - 28.0, 40.0), _collect.size.y)
