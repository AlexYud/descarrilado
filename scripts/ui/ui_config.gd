class_name UIConfig
extends RefCounted

## THE single place that defines how the game's UI looks: the Retro Analog Stamp (a high-contrast 90s
## survival-horror look: Oswald bold, pitch black panels, off-white text, one crimson beacon red, sharp corners,
## no button boxes: the selected item is bold text with a red arrow).
##
## Every colour, the font, the sizes, the margins and the corner radius live here. The `Theme` of
## the whole game is BUILT from them (`build_theme`), `ThemeManager` applies it to every Control,
## and UI code that needs a colour or font outside the theme (a hint drawn over the 3D world, a
## note overlay) asks this class instead of hard-coding one. To change the look of the game:
## edit the values below (or call `apply_palette` at runtime and `ThemeManager.refresh()`), and
## run `godot --headless --script res://scripts/tools/build_ui_theme.gd` to rebake the editor
## preview theme (`resources/ui/the_hole_theme.tres`).
##
## Theme type variations (set `theme_type_variation` on a node to use one):
##   Label:          TitleLabel, HeaderLabel (bold, the accent, UPPERCASE), ItemTitleLabel, DialogueLabel, HintLabel and CaptionLabel (the bright colour, outlined), AccentLabel, MutedLabel, DangerLabel
##   PanelContainer: NotePanel (opaque overlay), HintPanel (light), CaptionPanel (no background), DangerPanel
##   Button:         DangerButton
##   RichTextLabel:  NoteText (a note), HintText (over the 3D world, outlined)
## Capitals: `uppercase_labels` (the label variations drawn in capitals, via `Label.uppercase`) and
## `uppercase_buttons` (ThemeManager upper-cases plain buttons' text, translations included).
## Buttons: `button_boxes` false = text only (no box, no fill); the selection is shown by ThemeManager
## giving every plain Button a small arrow icon (`arrow_icon`) that the theme tints transparent
## normally and `color_accent` when hovered, focused or pressed. (An icon, not a glyph: button text
## is a translation key, and the arrow stays solid at any size.)

# ============================================================
# COLOURS (Retro Analog Stamp)
# ============================================================

## Panel backgrounds and text boxes (pitch black), with the opacity they are drawn at.
static var color_panel: Color = Color("#050505")
static var panel_opacity: float = 0.95
## Panel borders and separators.
static var color_border: Color = Color("#1C1C1C")
## Standard text: notes, descriptions, body text (a clean off-white, pale fog).
static var color_text: Color = Color("#E0E0E0")
## The active element / selection highlight (the arrow, titles, slider fills): the crimson beacon red.
static var color_accent: Color = Color("#E60026")
## Inactive / disabled text.
static var color_disabled: Color = Color("#666666")
## Alerts, warnings, danger (the same red); its panel is `color_panel` with this border.
static var color_danger: Color = Color("#E60026")
## Interactable indications, captions and the words of a note: white, for contrast.
static var color_bright: Color = Color("#FFFFFF")

# ============================================================
# TYPOGRAPHY
# ============================================================

static var font_path: String = "res://assets/fonts/Oswald-Variable.ttf"
## Oswald is a variable font: its weight axis runs 200-700 (the weights below are clamped to the
## range of whatever font is set; a one-weight font is emboldened instead).
static var weight_body: int = 400
static var weight_button: int = 700
static var weight_title: int = 700

## The UI sizes (Options > Graphics > UI Size): each one is a hand-picked set of font sizes and paddings
## (never a stretch of the whole screen, which blurs the text). `apply_ui_size` copies a set into the
## `font_size_*` and padding values below; `ThemeManager` rebuilds the theme after it.
const UI_SIZES: Array[Dictionary] = [
	{"name": "small", "small": 12, "body": 15, "button": 16, "header": 21, "title": 34, "panel_padding": Vector2i(18, 12), "button_padding": Vector2i(12, 5)},
	{"name": "medium", "small": 14, "body": 17, "button": 19, "header": 24, "title": 40, "panel_padding": Vector2i(22, 15), "button_padding": Vector2i(14, 6)},
	{"name": "large", "small": 16, "body": 19, "button": 21, "header": 27, "title": 44, "panel_padding": Vector2i(26, 18), "button_padding": Vector2i(16, 7)},
]
const DEFAULT_UI_SIZE: int = 1
static var ui_size_index: int = DEFAULT_UI_SIZE

static var font_size_small: int = 14
static var font_size_body: int = 17
static var font_size_button: int = 19
static var font_size_header: int = 24
static var font_size_title: int = 40

## Extra space between letters, in pixels: a little for body text, more for buttons and titles.
static var spacing_body: int = 0
static var spacing_button: int = 2
static var spacing_title: int = 4

## Outline of text drawn straight over the 3D world (hints, captions): legible in the fog.
static var outline_size_hint: int = 6

## A soft halo of the text's own colour round labels and buttons (alpha, pixels); 0 = none.
static var glow_alpha: float = 0.0
static var glow_size: int = 4

## Buttons show an arrow while hovered or focused.
static var selection_arrow: bool = true
## false: buttons are bold text only (no box, no fill); true: outlined boxes with a highlight fill.
static var button_boxes: bool = false
## Left-align plain buttons so the selection arrow sits right before the text.
static var menu_items_left: bool = true
## Label theme variations drawn in capitals, and whether plain buttons are drawn in capitals.
static var uppercase_labels: Array[StringName] = [&"TitleLabel", &"HeaderLabel"]
static var uppercase_buttons: bool = true
# ============================================================
# LAYOUT
# ============================================================

static var corner_radius: int = 0
static var border_width: int = 1
static var panel_padding: Vector2i = Vector2i(22, 15)
static var button_padding: Vector2i = Vector2i(14, 6)
static var line_spacing: int = 5

# ============================================================
# QUERIES (for UI code outside the theme)
# ============================================================

static var _font_cache: Dictionary = {}

## The OpenType tag of the weight axis ("wght").
const WEIGHT_AXIS: int = 2003265652


## The panel colour at its panel opacity (or at a given alpha).
static func panel_color(alpha: float = -1.0) -> Color:
	return Color(color_panel, panel_opacity if alpha < 0.0 else alpha)


## A palette colour with another alpha.
static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color, alpha)


## The UI font at a weight (clamped to the font's weight axis; a one-weight font is emboldened
## instead) with extra letter spacing; `italic` slants it. Cached. Falls back on the engine's default font if the file is missing.
static func font(weight: int = -1, spacing: int = -1, italic: bool = false) -> Font:
	var wanted_weight: int = weight_body if weight < 0 else weight
	var wanted_spacing: int = spacing_body if spacing < 0 else spacing
	var key: String = "%s|%d|%d|%s" % [font_path, wanted_weight, wanted_spacing, italic]
	if _font_cache.has(key):
		return _font_cache[key]

	var base: Font = null
	if ResourceLoader.exists(font_path):
		base = load(font_path) as Font

	if base == null:
		push_warning("UIConfig: font '%s' not found, using the default font." % font_path)
		return ThemeDB.fallback_font

	var variation: FontVariation = FontVariation.new()
	variation.base_font = base
	var variable: bool = base is FontFile and not (base as FontFile).get_supported_variation_list().is_empty()
	if variable:
		var axes: Dictionary = (base as FontFile).get_supported_variation_list()
		var low: float = 100.0
		var high: float = 900.0
		if axes.has(WEIGHT_AXIS):
			low = (axes[WEIGHT_AXIS] as Vector3).x
			high = (axes[WEIGHT_AXIS] as Vector3).y

		variation.variation_opentype = {"wght": clampf(float(wanted_weight), low, high)}
	else:
		# 500 -> 0, 600 -> 0.18, 700 -> 0.36 px of emboldening.
		variation.variation_embolden = clampf(float(wanted_weight - weight_body) / 200.0 * 0.36, 0.0, 1.0)
	variation.spacing_glyph = wanted_spacing
	if italic:
		variation.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.2, 1.0), Vector2.ZERO)

	_font_cache[key] = variation
	return variation


## The selection arrow (a right-pointing triangle) as a white icon, to be tinted by the theme.
static var _arrow: ImageTexture = null


static func arrow_icon() -> ImageTexture:
	if _arrow == null:
		_arrow = _icon(14, 16, func(image: Image) -> void:
			for x: int in 12:
				var half: float = (12.0 - float(x)) * 0.62
				for y: int in 16:
					if absf(float(y) - 7.5) <= half:
						image.set_pixel(x + 1, y, Color.WHITE))

	return _arrow

## The font for a role: "body", "button", "title".
static func role_font(role: String) -> Font:
	match role:
		"button":
			return font(weight_button, spacing_button)
		"title", "header":
			return font(weight_title, spacing_title if role == "title" else spacing_button)

	return font()


## Switches to a UI size (0 small, 1 medium, 2 large). Follow with `ThemeManager.refresh()`.
static func apply_ui_size(index: int) -> void:
	ui_size_index = clampi(index, 0, UI_SIZES.size() - 1)
	var size: Dictionary = UI_SIZES[ui_size_index]
	font_size_small = size["small"]
	font_size_body = size["body"]
	font_size_button = size["button"]
	font_size_header = size["header"]
	font_size_title = size["title"]
	panel_padding = size["panel_padding"]
	button_padding = size["button_padding"]


## Replaces palette colours at runtime (keys: panel, border, text, accent, disabled, danger, with
## "#rrggbb" strings or Colors) and drops the font cache. Follow with `ThemeManager.refresh()`.
static func apply_palette(colors: Dictionary) -> void:
	for key: String in colors:
		var value: Color = Color(colors[key])
		match key:
			"panel":
				color_panel = value
			"border":
				color_border = value
			"text":
				color_text = value
			"accent":
				color_accent = value
			"disabled":
				color_disabled = value
			"danger":
				color_danger = value

	_font_cache.clear()


# ============================================================
# STYLEBOXES
# ============================================================

static func _flat(fill: Color, border: Color, border_px: int = -1, padding: Vector2i = Vector2i(-1, -1)) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	var width: int = border_width if border_px < 0 else border_px
	style.set_border_width_all(width)
	style.set_corner_radius_all(corner_radius)
	style.anti_aliasing = true
	var pad: Vector2i = panel_padding if padding.x < 0 else padding
	style.content_margin_left = pad.x
	style.content_margin_right = pad.x
	style.content_margin_top = pad.y
	style.content_margin_bottom = pad.y
	return style


## A panel: the panel colour at its opacity, a border, a soft dark shadow that lifts it off the fog.
static func panel_style(border: Color = Color(0, 0, 0, 0), fill_alpha: float = -1.0, padding: Vector2i = Vector2i(-1, -1)) -> StyleBoxFlat:
	var style: StyleBoxFlat = _flat(panel_color(fill_alpha), color_border if border.a == 0.0 else border, -1, padding)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 6
	return style


## A button state: `fill` over the panel, a border.
static func button_style(fill: Color, border: Color, border_px: int = -1) -> StyleBoxFlat:
	return _flat(fill, border, border_px, button_padding)


static func _line(color: Color, thickness: int = 1) -> StyleBoxLine:
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = color
	line.thickness = thickness
	return line


static func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


# ============================================================
# ICONS (small shapes drawn in code, in palette colours)
# ============================================================

static func _icon(width: int, height: int, painter: Callable) -> ImageTexture:
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	painter.call(image)
	return ImageTexture.create_from_image(image)


static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for j: int in h:
		for i: int in w:
			var px: int = x + i
			var py: int = y + j
			if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)


## A check box: a bordered square, with an inner square when checked.
static func _box_icon(checked: bool, disabled: bool = false) -> ImageTexture:
	var edge: Color = color_disabled if disabled else color_text.darkened(0.25)
	var mark: Color = color_disabled if disabled else color_accent.lightened(0.15)
	return _icon(24, 24, func(image: Image) -> void:
		_rect(image, 2, 2, 20, 20, edge)
		_rect(image, 4, 4, 16, 16, panel_color(1.0))
		if checked:
			_rect(image, 7, 7, 10, 10, mark))


## A toggle switch: a bordered pill with a knob on the left (off) or right, accent coloured (on).
static func _switch_icon(on: bool, disabled: bool = false) -> ImageTexture:
	var edge: Color = color_disabled if disabled else (color_accent if on else color_text.darkened(0.45))
	var fill: Color = color_accent.darkened(0.55) if on and not disabled else panel_color(1.0)
	var knob: Color = color_disabled if disabled else (color_text if on else color_text.darkened(0.3))
	return _icon(48, 24, func(image: Image) -> void:
		_rect(image, 1, 3, 46, 18, edge)
		_rect(image, 3, 5, 42, 14, fill)
		_rect(image, 28 if on else 5, 6, 15, 12, knob))


## A round slider knob.
static func _knob_icon(color: Color, size: int = 18) -> ImageTexture:
	return _icon(size, size, func(image: Image) -> void:
		var centre: float = (float(size) - 1.0) * 0.5
		for j: int in size:
			for i: int in size:
				var d: float = Vector2(float(i) - centre, float(j) - centre).length()
				var edge: float = clampf(centre + 0.5 - d, 0.0, 1.0)
				if edge > 0.0:
					image.set_pixel(i, j, Color(color, edge)))


# ============================================================
# THE THEME
# ============================================================

## The whole game's theme, built from the values above.
static func build_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = font()
	theme.default_font_size = font_size_body

	var text_dim: Color = color_text.darkened(0.4)
	var hover_fill: Color = Color(color_accent, 0.2)
	var press_fill: Color = Color(color_accent, 0.38)
	var clear: Color = Color(0, 0, 0, 0)

	# ---- Labels ----
	theme.set_font("font", "Label", font())
	theme.set_font_size("font_size", "Label", font_size_body)
	theme.set_color("font_color", "Label", color_text)
	theme.set_color("font_shadow_color", "Label", Color(color_text, glow_alpha))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 0)
	theme.set_constant("shadow_outline_size", "Label", glow_size)
	theme.set_color("font_outline_color", "Label", panel_color(1.0))
	theme.set_constant("outline_size", "Label", 0)
	theme.set_constant("line_spacing", "Label", line_spacing)

	# Titles are the primary colour (the accent).
	_label_variation(theme, "TitleLabel", role_font("title"), font_size_title, color_accent, 0)
	_label_variation(theme, "HeaderLabel", role_font("header"), font_size_header, color_accent, 0)
	# The name of an item being inspected: primary colour, outlined over the 3D world.
	_label_variation(theme, "ItemTitleLabel", role_font("header"), font_size_header, color_accent.lightened(0.12), outline_size_hint)
	_label_variation(theme, "DialogueLabel", font(weight_body, spacing_body), font_size_body + 2, color_text, 0)
	theme.set_constant("line_spacing", "DialogueLabel", line_spacing + 3)
	_label_variation(theme, "HintLabel", font(weight_button, spacing_body + 1), font_size_body, color_bright, outline_size_hint)
	# Subtitles / captions: white text only, no background (an outline keeps it readable in the fog).
	_label_variation(theme, "CaptionLabel", font(weight_button, spacing_body + 1), font_size_body, color_bright, outline_size_hint)
	_label_variation(theme, "AccentLabel", font(weight_button, spacing_body), font_size_body, color_accent.lightened(0.15), 0)
	_label_variation(theme, "MutedLabel", font(), font_size_body, color_disabled, 0)
	_label_variation(theme, "DangerLabel", font(weight_button, spacing_body), font_size_body, color_danger, 0)

	# ---- Panels ----
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())
	theme.set_type_variation("NotePanel", "PanelContainer")
	theme.set_stylebox("panel", "NotePanel", panel_style(color_border, 0.97, Vector2i(panel_padding.x + 8, panel_padding.y + 6)))
	theme.set_type_variation("CaptionPanel", "PanelContainer")
	theme.set_stylebox("panel", "CaptionPanel", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, Vector2i(22, 8)))
	theme.set_type_variation("HintPanel", "PanelContainer")
	theme.set_stylebox("panel", "HintPanel", _flat(panel_color(0.62), clear, 0, Vector2i(22, 10)))
	theme.set_type_variation("DangerPanel", "PanelContainer")
	theme.set_stylebox("panel", "DangerPanel", panel_style(color_danger))

	# ---- Buttons ----
	_button_type(theme, "Button", color_text, color_accent)
	theme.set_type_variation("DangerButton", "Button")
	_button_type(theme, "DangerButton", color_text, color_danger, true)
	_button_type(theme, "OptionButton", color_text, color_accent)
	theme.set_constant("arrow_margin", "OptionButton", 8)
	theme.set_constant("h_separation", "OptionButton", 10)
	theme.set_constant("h_separation", "Button", 10)

	# ---- Check box and toggle switch ----
	for type_name: String in ["CheckBox", "CheckButton"]:
		_button_type(theme, type_name, color_text, color_accent)
		theme.set_stylebox("normal", type_name, _empty())
		theme.set_stylebox("hover", type_name, _empty())
		theme.set_stylebox("pressed", type_name, _empty())
		theme.set_stylebox("hover_pressed", type_name, _empty())
		theme.set_stylebox("disabled", type_name, _empty())
		theme.set_stylebox("focus", type_name, _flat(clear, color_accent, 1, Vector2i(4, 2)))
		theme.set_constant("h_separation", type_name, 12)
		theme.set_font("font", type_name, font(weight_body, spacing_body))
		theme.set_font_size("font_size", type_name, font_size_body)

	theme.set_icon("unchecked", "CheckBox", _box_icon(false))
	theme.set_icon("checked", "CheckBox", _box_icon(true))
	theme.set_icon("unchecked_disabled", "CheckBox", _box_icon(false, true))
	theme.set_icon("checked_disabled", "CheckBox", _box_icon(true, true))
	theme.set_icon("unchecked", "CheckButton", _switch_icon(false))
	theme.set_icon("checked", "CheckButton", _switch_icon(true))
	theme.set_icon("unchecked_disabled", "CheckButton", _switch_icon(false, true))
	theme.set_icon("checked_disabled", "CheckButton", _switch_icon(true, true))

	# ---- Sliders ----
	theme.set_stylebox("slider", "HSlider", _line(color_border, 3))
	theme.set_stylebox("grabber_area", "HSlider", _line(color_accent, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _line(color_accent.lightened(0.2), 3))
	theme.set_icon("grabber", "HSlider", _knob_icon(color_text.darkened(0.15)))
	theme.set_icon("grabber_highlight", "HSlider", _knob_icon(color_accent.lightened(0.35)))
	theme.set_icon("grabber_disabled", "HSlider", _knob_icon(color_disabled))
	theme.set_stylebox("slider", "VSlider", _line(color_border, 3))
	theme.set_stylebox("grabber_area", "VSlider", _line(color_accent, 3))
	theme.set_icon("grabber", "VSlider", _knob_icon(color_text.darkened(0.15)))
	theme.set_icon("grabber_highlight", "VSlider", _knob_icon(color_accent.lightened(0.35)))

	# ---- Progress bar ----
	theme.set_stylebox("background", "ProgressBar", _flat(panel_color(1.0), color_border, 1, Vector2i(2, 2)))
	theme.set_stylebox("fill", "ProgressBar", _flat(color_accent, clear, 0, Vector2i(2, 2)))
	theme.set_color("font_color", "ProgressBar", color_text)
	theme.set_font("font", "ProgressBar", font())

	# ---- Text fields ----
	theme.set_stylebox("normal", "LineEdit", _flat(panel_color(1.0), color_border, 1, Vector2i(14, 8)))
	theme.set_stylebox("focus", "LineEdit", _flat(panel_color(1.0), color_accent, 1, Vector2i(14, 8)))
	theme.set_stylebox("read_only", "LineEdit", _flat(panel_color(0.6), color_border, 1, Vector2i(14, 8)))
	theme.set_font("font", "LineEdit", font())
	theme.set_font_size("font_size", "LineEdit", font_size_body)
	theme.set_color("font_color", "LineEdit", color_text)
	theme.set_color("font_selected_color", "LineEdit", color_text)
	theme.set_color("font_uneditable_color", "LineEdit", color_disabled)
	theme.set_color("font_placeholder_color", "LineEdit", color_disabled)
	theme.set_color("caret_color", "LineEdit", color_text)
	theme.set_color("selection_color", "LineEdit", Color(color_accent, 0.45))
	theme.set_stylebox("normal", "TextEdit", _flat(panel_color(1.0), color_border, 1, Vector2i(14, 8)))
	theme.set_stylebox("focus", "TextEdit", _flat(panel_color(1.0), color_accent, 1, Vector2i(14, 8)))
	theme.set_font("font", "TextEdit", font())
	theme.set_color("font_color", "TextEdit", color_text)
	theme.set_color("caret_color", "TextEdit", color_text)
	theme.set_color("selection_color", "TextEdit", Color(color_accent, 0.45))

	# ---- Rich text ----
	theme.set_font("normal_font", "RichTextLabel", font())
	theme.set_font("bold_font", "RichTextLabel", font(weight_title, spacing_body))
	theme.set_font("italics_font", "RichTextLabel", font(weight_body, spacing_body, true))
	theme.set_font("bold_italics_font", "RichTextLabel", font(weight_title, spacing_body, true))
	theme.set_font("mono_font", "RichTextLabel", font())
	for size_name: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		theme.set_font_size(size_name, "RichTextLabel", font_size_body)

	theme.set_color("default_color", "RichTextLabel", color_text)
	theme.set_color("font_selected_color", "RichTextLabel", color_text)
	theme.set_color("selection_color", "RichTextLabel", Color(color_accent, 0.45))
	theme.set_color("font_outline_color", "RichTextLabel", panel_color(1.0))
	theme.set_constant("outline_size", "RichTextLabel", 0)
	theme.set_constant("line_separation", "RichTextLabel", line_spacing)
	theme.set_color("font_shadow_color", "RichTextLabel", Color(color_text, glow_alpha))
	theme.set_constant("shadow_offset_x", "RichTextLabel", 0)
	theme.set_constant("shadow_offset_y", "RichTextLabel", 0)
	theme.set_constant("shadow_outline_size", "RichTextLabel", glow_size)
	theme.set_stylebox("normal", "RichTextLabel", _empty())
	theme.set_stylebox("focus", "RichTextLabel", _empty())
	theme.set_type_variation("NoteText", "RichTextLabel")
	theme.set_color("default_color", "NoteText", color_bright)
	theme.set_constant("line_separation", "NoteText", line_spacing + 4)
	theme.set_font_size("normal_font_size", "NoteText", font_size_body + 2)
	theme.set_font_size("bold_font_size", "NoteText", font_size_body + 2)
	theme.set_font_size("italics_font_size", "NoteText", font_size_body + 2)
	theme.set_font_size("bold_italics_font_size", "NoteText", font_size_body + 2)

	theme.set_type_variation("HintText", "RichTextLabel")
	theme.set_color("default_color", "HintText", color_bright)
	theme.set_constant("outline_size", "HintText", outline_size_hint + 1)
	theme.set_color("font_outline_color", "HintText", panel_color(1.0))
	theme.set_font("normal_font", "HintText", font(weight_button, spacing_body + 1))
	theme.set_font("bold_font", "HintText", font(weight_title, spacing_body + 1))

	# ---- Separators ----
	theme.set_stylebox("separator", "HSeparator", _line(color_border, 1))
	theme.set_constant("separation", "HSeparator", 14)
	theme.set_stylebox("separator", "VSeparator", _line(color_border, 1))
	theme.set_constant("separation", "VSeparator", 14)

	# ---- Tabs ----
	for type_name: String in ["TabContainer", "TabBar"]:
		theme.set_font("font", type_name, font(weight_button, spacing_button))
		theme.set_font_size("font_size", type_name, font_size_body)
		theme.set_color("font_selected_color", type_name, color_text)
		theme.set_color("font_hovered_color", type_name, color_text)
		theme.set_color("font_unselected_color", type_name, text_dim)
		theme.set_color("font_disabled_color", type_name, color_disabled)
		theme.set_color("font_outline_color", type_name, clear)
		theme.set_stylebox("tab_selected", type_name, _tab_style(panel_color(0.97), color_accent))
		theme.set_stylebox("tab_unselected", type_name, _tab_style(panel_color(0.7), color_border))
		theme.set_stylebox("tab_hovered", type_name, _tab_style(Color(color_accent, 0.18), color_accent))
		theme.set_stylebox("tab_disabled", type_name, _tab_style(panel_color(0.5), color_border))
		theme.set_stylebox("tab_focus", type_name, _tab_style(clear, color_accent))
		theme.set_constant("h_separation", type_name, 8)

	theme.set_stylebox("panel", "TabContainer", panel_style())
	theme.set_stylebox("tabbar_background", "TabContainer", _empty())

	# ---- Scroll bars ----
	for type_name: String in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type_name, _flat(panel_color(0.8), clear, 0, Vector2i(2, 2)))
		theme.set_stylebox("grabber", type_name, _flat(color_border.lightened(0.25), clear, 0, Vector2i(2, 2)))
		theme.set_stylebox("grabber_highlight", type_name, _flat(color_accent, clear, 0, Vector2i(2, 2)))
		theme.set_stylebox("grabber_pressed", type_name, _flat(color_accent.lightened(0.2), clear, 0, Vector2i(2, 2)))

	# ---- Menus, tooltips, dialogs ----
	var popup: StyleBoxFlat = panel_style(color_border, 0.98, Vector2i(10, 8))
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("panel", "PopupPanel", popup)
	theme.set_stylebox("hover", "PopupMenu", _flat(Color(color_accent, 0.28), clear, 0, Vector2i(10, 6)))
	theme.set_stylebox("separator", "PopupMenu", _line(color_border, 1))
	theme.set_font("font", "PopupMenu", font(weight_button, spacing_body))
	theme.set_font_size("font_size", "PopupMenu", font_size_body)
	theme.set_color("font_color", "PopupMenu", color_text)
	theme.set_color("font_hover_color", "PopupMenu", color_text)
	theme.set_color("font_disabled_color", "PopupMenu", color_disabled)
	theme.set_color("font_separator_color", "PopupMenu", color_disabled)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_constant("item_start_padding", "PopupMenu", 8)
	theme.set_constant("item_end_padding", "PopupMenu", 8)

	theme.set_stylebox("panel", "TooltipPanel", panel_style(color_border, 0.97, Vector2i(14, 8)))
	theme.set_font("font", "TooltipLabel", font())
	theme.set_font_size("font_size", "TooltipLabel", font_size_small)
	theme.set_color("font_color", "TooltipLabel", color_text)

	theme.set_stylebox("panel", "AcceptDialog", panel_style(color_border, 0.98))
	# An embedded dialog's border reserves the title bar above its content (expand margin = title height).
	for border_name: String in ["embedded_border", "embedded_unfocused_border"]:
		var border: StyleBoxFlat = panel_style(color_border, 0.98, Vector2i(14, 12))
		border.expand_margin_top = 44.0
		theme.set_stylebox(border_name, "Window", border)
	theme.set_font("title_font", "Window", font(weight_title, spacing_button))
	theme.set_font_size("title_font_size", "Window", font_size_body + 2)
	theme.set_color("title_color", "Window", color_text)
	theme.set_color("title_outline_modulate", "Window", clear)
	theme.set_constant("title_height", "Window", 44)
	theme.set_constant("close_h_offset", "Window", 14)

	# ---- Lists ----
	theme.set_stylebox("panel", "ItemList", _flat(panel_color(0.9), color_border, 1, Vector2i(8, 6)))
	theme.set_stylebox("focus", "ItemList", _flat(clear, color_accent, 1, Vector2i(8, 6)))
	theme.set_stylebox("selected", "ItemList", _flat(Color(color_accent, 0.3), color_accent, 1, Vector2i(8, 4)))
	theme.set_stylebox("selected_focus", "ItemList", _flat(Color(color_accent, 0.4), color_accent, 1, Vector2i(8, 4)))
	theme.set_stylebox("hovered", "ItemList", _flat(Color(color_accent, 0.14), clear, 0, Vector2i(8, 4)))
	theme.set_font("font", "ItemList", font())
	theme.set_font_size("font_size", "ItemList", font_size_body)
	theme.set_color("font_color", "ItemList", color_text)
	theme.set_color("font_selected_color", "ItemList", color_text)
	theme.set_color("font_hovered_color", "ItemList", color_text)

	return theme


static func _label_variation(theme: Theme, variation: String, label_font: Font, size: int, color: Color, outline: int) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font("font", variation, label_font)
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)
	theme.set_color("font_outline_color", variation, panel_color(1.0))
	theme.set_constant("outline_size", variation, outline)
	if outline > 0:
		# Over the 3D world: a dark outline and a soft dark shadow keep it readable.
		theme.set_color("font_shadow_color", variation, Color(0.0, 0.0, 0.0, 0.6))
		theme.set_constant("shadow_offset_x", variation, 1)
		theme.set_constant("shadow_offset_y", variation, 2)
	else:
		# In a panel: the CRT glow, a halo of the text's own colour.
		theme.set_color("font_shadow_color", variation, Color(color, glow_alpha))
		theme.set_constant("shadow_offset_x", variation, 0)
		theme.set_constant("shadow_offset_y", variation, 0)
		theme.set_constant("shadow_outline_size", variation, glow_size)


## All the states of a button type: transparent with a border, the accent on hover / press / focus,
## the disabled colour when it cannot be pressed. `danger` swaps the accent for the danger colour
## and gives it the danger panel background.
static func _button_type(theme: Theme, type_name: String, text_color: Color, accent: Color, danger: bool = false) -> void:
	var clear: Color = Color(0, 0, 0, 0)
	# Boxed buttons (and always drop-downs, which are form fields) have an outline and a highlight fill;
	# text-only buttons have neither: bold text, the arrow and a brighter colour mark the selection.
	var boxed: bool = button_boxes or type_name == "OptionButton"
	if boxed:
		var base_fill: Color = panel_color(0.55) if not danger else panel_color(0.9)
		var edge: Color = color_border if not danger else color_danger.darkened(0.15)
		theme.set_stylebox("normal", type_name, button_style(base_fill, edge))
		theme.set_stylebox("hover", type_name, button_style(Color(accent, 0.2), accent))
		theme.set_stylebox("pressed", type_name, button_style(Color(accent, 0.38), accent))
		theme.set_stylebox("hover_pressed", type_name, button_style(Color(accent, 0.46), accent))
		theme.set_stylebox("disabled", type_name, button_style(panel_color(0.35), Color(color_border, 0.6)))
		theme.set_stylebox("focus", type_name, button_style(clear, accent, 2))
	else:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			theme.set_stylebox(state, type_name, button_style(clear, clear, 0))
	theme.set_font("font", type_name, font(weight_button, spacing_button))
	theme.set_font_size("font_size", type_name, font_size_button)
	var lit: Color = (color_bright if not boxed else text_color.lightened(0.2)) if not danger else Color(color_danger).lightened(0.35)
	theme.set_color("font_color", type_name, text_color if not danger else Color(color_danger).lightened(0.15))
	theme.set_color("font_hover_color", type_name, lit)
	theme.set_color("font_hover_pressed_color", type_name, lit)
	theme.set_color("font_pressed_color", type_name, lit)
	theme.set_color("font_focus_color", type_name, lit)
	theme.set_color("font_disabled_color", type_name, color_disabled)
	theme.set_color("font_outline_color", type_name, clear)
	# The selection arrow (ThemeManager gives plain buttons the icon): invisible until hovered or focused.
	theme.set_color("icon_normal_color", type_name, clear)
	theme.set_color("icon_hover_color", type_name, accent)
	theme.set_color("icon_hover_pressed_color", type_name, accent)
	theme.set_color("icon_focus_color", type_name, accent)
	theme.set_color("icon_pressed_color", type_name, accent)
	theme.set_color("font_shadow_color", type_name, Color(text_color if not danger else Color(color_danger), glow_alpha * 0.8))
	theme.set_constant("shadow_offset_x", type_name, 0)
	theme.set_constant("shadow_offset_y", type_name, 0)
	theme.set_constant("shadow_outline_size", type_name, glow_size)
	theme.set_color("icon_disabled_color", type_name, clear)
	theme.set_constant("outline_size", type_name, 0)


static func _tab_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _flat(fill, edge, 0, Vector2i(18, 8))
	style.border_width_bottom = 2
	style.set_corner_radius_all(corner_radius)
	return style
