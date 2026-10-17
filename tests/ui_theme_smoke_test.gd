extends Node

## The game's UI theme: the exact palette (Retro Analog Stamp) and the Oswald font of the design brief, built in one
## place (UIConfig) and applied to every Control by the ThemeManager autoload; every theme type
## variation used by a scene or script exists; the whole look can be swapped from UIConfig; and
## the font covers every character of both languages.

var test_failed: bool = false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.003 and absf(a.g - b.g) < 0.003 and absf(a.b - b.b) < 0.003


func _ready() -> void:
	await get_tree().process_frame
	GameSettings.set_text_locale("en", false)

	# The palette of the brief.
	_expect(UIConfig.color_panel.to_html(false).to_lower() == "050505", "panel background #050505")
	_expect(UIConfig.color_border.to_html(false).to_lower() == "1c1c1c", "panel border #1C1C1C")
	_expect(UIConfig.color_text.to_html(false).to_lower() == "e0e0e0", "text #E0E0E0")
	_expect(UIConfig.color_accent.to_html(false).to_lower() == "e60026", "accent #E60026 (crimson beacon)")
	_expect(UIConfig.color_disabled.to_html(false).to_lower() == "666666", "disabled #666666")
	_expect(UIConfig.color_danger.to_html(false).to_lower() == "e60026", "danger #E60026 (crimson beacon)")
	_expect(UIConfig.panel_opacity >= 0.9 and UIConfig.panel_opacity <= 0.96, "panels are 90-95%% opaque (%.2f)" % UIConfig.panel_opacity)
	_expect(UIConfig.corner_radius <= 1, "sharp corners (radius 0)")

	# It is applied to the whole game.
	var manager: Node = get_node_or_null("/root/ThemeManager")
	_expect(manager != null, "the ThemeManager autoload exists")
	var theme: Theme = ThemeManager.theme
	_expect(theme != null and theme == ThemeDB.get_project_theme(), "the game's theme is the project theme (the one controls actually read)")
	if theme == null:
		get_tree().quit(1)
		return

	var panel: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	_expect(_same(panel.bg_color, UIConfig.color_panel) and absf(panel.bg_color.a - UIConfig.panel_opacity) < 0.01, "PanelContainer: the panel colour at its opacity")
	_expect(_same(panel.border_color, UIConfig.color_border), "PanelContainer: the border colour")
	_expect(panel.corner_radius_top_left <= 1 and panel.content_margin_left >= 16.0, "PanelContainer: sharp corners and clean inner margins")
	_expect(_same(theme.get_color("font_color", "Label"), UIConfig.color_text), "Label text colour")
	_expect(_same(theme.get_color("default_color", "RichTextLabel"), UIConfig.color_text), "RichTextLabel text colour")
	_expect(_same(theme.get_color("font_disabled_color", "Button"), UIConfig.color_disabled), "disabled button text colour")
	_expect(_same(theme.get_color("icon_hover_color", "Button"), UIConfig.color_accent), "the selection arrow uses the accent")
	var danger: StyleBoxFlat = theme.get_stylebox("panel", "DangerPanel") as StyleBoxFlat
	_expect(_same(danger.border_color, UIConfig.color_danger) and _same(danger.bg_color, UIConfig.color_panel), "DangerPanel: red border on the panel colour")
	_expect(_same(theme.get_color("font_color", "DangerLabel"), UIConfig.color_danger), "DangerLabel text colour")

	# Titles are the primary colour; interactable indications and the words of a note are white; captions have no background.
	_expect(_same(theme.get_color("font_color", "TitleLabel"), UIConfig.color_accent) and _same(theme.get_color("font_color", "HeaderLabel"), UIConfig.color_accent), "titles use the primary colour")
	_expect(_same(theme.get_color("font_color", "ItemTitleLabel"), UIConfig.color_accent.lightened(0.12)), "an inspected item's title uses the primary colour")
	_expect(UIConfig.color_bright.get_luminance() > 0.9 and _same(theme.get_color("font_color", "HintLabel"), UIConfig.color_bright) and _same(theme.get_color("default_color", "HintText"), UIConfig.color_bright), "prompts and hints are white")
	_expect(_same(theme.get_color("default_color", "NoteText"), UIConfig.color_bright), "the words of a note are white")
	_expect(_same(theme.get_color("font_color", "CaptionLabel"), UIConfig.color_bright) and (theme.get_stylebox("panel", "CaptionPanel") as StyleBoxFlat).bg_color.a == 0.0, "captions: white text, no background")

	# The UI size: three named sizes (small, medium, large), each a set of font sizes (no screen stretch,
	# which would blur the text); the theme is rebuilt on a change.
	var old_index: int = GameSettings.get_ui_size_index()
	_expect(GameSettings.UI_SIZE_COUNT == 3 and UIConfig.UI_SIZES.size() == 3 and UIConfig.UI_SIZES[1]["name"] == "medium" and GameSettings.DEFAULT_UI_SIZE_INDEX == 1, "three UI sizes, medium by default")
	var sizes_ok: bool = true
	for i: int in range(1, UIConfig.UI_SIZES.size()):
		for key: String in ["small", "body", "button", "header", "title"]:
			sizes_ok = sizes_ok and int(UIConfig.UI_SIZES[i][key]) > int(UIConfig.UI_SIZES[i - 1][key])

	_expect(sizes_ok, "every font size grows from small to medium to large")
	_expect(is_equal_approx(get_tree().root.content_scale_factor, 1.0), "the screen is never stretched (content scale 1.0)")
	var probe_label: Label = Label.new()
	add_child(probe_label)
	for i: int in 3:
		GameSettings.set_ui_size_index(i, false)
		await get_tree().process_frame
		_expect(probe_label.get_theme_font_size("font_size") == int(UIConfig.UI_SIZES[i]["body"]), "an existing Label follows UI size %s live (%d)" % [UIConfig.UI_SIZES[i]["name"], probe_label.get_theme_font_size("font_size")])
		var sized: Theme = ThemeManager.theme
		_expect(sized.get_font_size("font_size", "Label") == int(UIConfig.UI_SIZES[i]["body"]) and sized.get_font_size("font_size", "TitleLabel") == int(UIConfig.UI_SIZES[i]["title"]) and sized.get_font_size("font_size", "Button") == int(UIConfig.UI_SIZES[i]["button"]), "UI size %s: the theme uses its font sizes (body %d)" % [UIConfig.UI_SIZES[i]["name"], sized.get_font_size("font_size", "Label")])

	GameSettings.set_ui_size_index(old_index, false)
	_expect(UIConfig.font_size_body <= 18 and UIConfig.font_size_button <= 20, "the default (medium) text is modest (body %d, buttons %d)" % [UIConfig.font_size_body, UIConfig.font_size_button])

	# The options window keeps ONE size on every tab (it used to resize to each tab's content).
	var pause: Node = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pause)
	await get_tree().process_frame
	pause.open_pause_menu()
	await get_tree().process_frame
	var options: Control = pause.get_node("PauseRoot/OptionsPanel") as Control
	options.open()
	var tabs: TabContainer = options.get_node("OptionsMargin/OptionsVBox/OptionsTabs") as TabContainer
	for size_index: int in 3:
		GameSettings.set_ui_size_index(size_index, false)
		await get_tree().process_frame
		var seen: Array[Vector2] = []
		for tab: int in tabs.get_tab_count():
			tabs.current_tab = tab
			await get_tree().process_frame
			await get_tree().process_frame
			seen.append(options.size)

		var steady: bool = true
		for window_size: Vector2 in seen:
			steady = steady and window_size.is_equal_approx(seen[0])

		_expect(steady, "UI size %s: the options window is the same on all %d tabs %s" % [UIConfig.UI_SIZES[size_index]["name"], seen.size(), seen])
		_expect(options.size.y <= 720.0 and options.size.x <= 1280.0, "and it fits a 1280x720 screen (%s)" % options.size)

	GameSettings.set_ui_size_index(old_index, false)
	pause.queue_free()

	# The CRT look: a soft glow round text, the selection arrow on buttons (invisible until hovered or focused).
	_expect(theme.get_constant("shadow_outline_size", "Label") == UIConfig.glow_size and is_equal_approx(theme.get_color("font_shadow_color", "Label").a, UIConfig.glow_alpha), "the glow follows the config (alpha %.2f)" % UIConfig.glow_alpha)
	_expect(theme.get_constant("outline_size", "HintLabel") >= 5 and theme.get_color("font_outline_color", "HintLabel").get_luminance() < 0.05, "text over the 3D world has a strong dark outline")
	var arrow_button: Button = Button.new()
	add_child(arrow_button)
	var check_box: CheckBox = CheckBox.new()
	add_child(check_box)
	_expect(arrow_button.icon != null and check_box.icon == null, "plain buttons get the selection arrow, check boxes do not")
	_expect(theme.get_color("icon_normal_color", "Button").a == 0.0 and _same(theme.get_color("icon_hover_color", "Button"), UIConfig.color_accent) and _same(theme.get_color("icon_focus_color", "Button"), UIConfig.color_accent), "the arrow shows only on hover and focus")
	_expect(theme.get_color("icon_disabled_color", "Button").a == 0.0, "and never on a disabled button")

	# No boxes: text-only buttons (no outline, no fill), but drop-downs keep a field outline; menu items and titles are capitals.
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = theme.get_stylebox(state, "Button") as StyleBoxFlat
		_expect(box.border_width_left == 0 and box.bg_color.a == 0.0, "Button '%s' has no box (no border, no fill)" % state)

	_expect((theme.get_stylebox("focus", "OptionButton") as StyleBoxFlat).border_width_left > 0, "drop-downs keep a field outline")
	var menu_item: Button = Button.new()
	menu_item.text = "Hello there"
	add_child(menu_item)
	var key_item: Button = Button.new()
	key_item.text = "OPTIONS_BACK"
	add_child(key_item)
	await get_tree().process_frame
	_expect(menu_item.text == "HELLO THERE", "plain button text is capitals (%s)" % menu_item.text)
	_expect(key_item.text == tr("OPTIONS_BACK").to_upper() and key_item.text != "OPTIONS_BACK", "a translated button is shown translated, in capitals (%s)" % key_item.text)
	menu_item.text = "second text"
	await get_tree().process_frame
	_expect(menu_item.text == "SECOND TEXT", "text set later is capitalised too")

	# A change of language re-translates the capitalised buttons.
	var old_locale: String = GameSettings.get_text_locale()
	GameSettings.set_text_locale("pt_BR", false)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(key_item.text == "VOLTAR", "after switching to Portuguese the button reads VOLTAR (%s)" % key_item.text)
	GameSettings.set_text_locale(old_locale, false)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(key_item.text == "BACK", "and back to English: BACK (%s)" % key_item.text)

	# The font: Share Tech Mono (monospace), a little letter spacing for buttons and titles.
	var label_font: Font = theme.get_font("font", "Label")
	_expect(UIConfig.font_path.ends_with("Oswald-Variable.ttf"), "the font is Oswald")
	_expect(label_font is FontVariation and ((label_font as FontVariation).base_font.resource_path == UIConfig.font_path), "Labels use Oswald")
	var button_font: FontVariation = theme.get_font("font", "Button") as FontVariation
	var title_font: FontVariation = theme.get_font("font", "TitleLabel") as FontVariation
	_expect(title_font.variation_opentype.get("wght", 0) >= 600 and button_font.variation_opentype.get("wght", 0) >= 600, "titles and buttons use the bold weight (%s)" % [title_font.variation_opentype])
	_expect(button_font.spacing_glyph >= (label_font as FontVariation).spacing_glyph, "buttons have at least the body's letter spacing")
	_expect(title_font.spacing_glyph >= button_font.spacing_glyph, "titles have the most letter spacing")
	_expect(theme.get_font("normal_font", "RichTextLabel").get_class() == "FontVariation", "RichTextLabel uses Oswald")

	# Titles are drawn in capitals.
	var title: Label = Label.new()
	title.theme_type_variation = &"TitleLabel"
	add_child(title)
	var plain: Label = Label.new()
	add_child(plain)
	_expect(title.uppercase and not plain.uppercase, "TitleLabel is uppercase, a plain Label is not")

	# Every variation named in a scene or script exists in the theme.
	var used: Dictionary = {}
	var pattern: RegEx = RegEx.new()
	pattern.compile("theme_type_variation = &\"([A-Za-z]+)\"")
	for path: String in _files("res://scenes", ["tscn"]) + _files("res://scripts", ["gd"]):
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			used[found.get_string(1)] = path

	var missing: PackedStringArray = []
	for variation: String in used:
		if theme.get_type_variation_base(variation) == &"":
			missing.append("%s (%s)" % [variation, used[variation]])

	_expect(used.size() >= 8 and missing.is_empty(), "every theme type variation in use exists (%d used, missing: %s)" % [used.size(), missing])

	# The whole look can be swapped from the one place.
	var old_text: Color = UIConfig.color_text
	var old_accent: Color = UIConfig.color_accent
	UIConfig.apply_palette({"text": "#ff0000", "accent": "#00ff00"})
	manager.refresh()
	var swapped: Theme = ThemeManager.theme
	_expect(_same(swapped.get_color("font_color", "Label"), Color("#ff0000")) and _same(swapped.get_color("icon_hover_color", "Button"), Color("#00ff00")), "changing UIConfig and refreshing restyles every control")
	UIConfig.apply_palette({"text": old_text.to_html(false), "accent": old_accent.to_html(false)})
	manager.refresh()
	_expect(_same(ThemeManager.theme.get_color("font_color", "Label"), old_text), "and it can be switched back")

	# Cinzel has every character of both languages.
	var cinzel: FontFile = load(UIConfig.font_path) as FontFile
	var missing_chars: String = ""
	for po: String in ["res://localization/en.po", "res://localization/pt_BR.po"]:
		for character: String in FileAccess.get_file_as_string(po):
			if character.unicode_at(0) > 32 and not cinzel.has_char(character.unicode_at(0)) and not missing_chars.contains(character):
				missing_chars += character

	_expect(missing_chars.is_empty(), "the font covers every character of the translations (missing: '%s')" % missing_chars)

	print("UI_THEME_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _files(root: String, extensions: Array[String]) -> Array[String]:
	var found: Array[String] = []
	var directory: DirAccess = DirAccess.open(root)
	if directory == null:
		return found

	for sub: String in directory.get_directories():
		found.append_array(_files(root.path_join(sub), extensions))

	for file: String in directory.get_files():
		if extensions.has(file.get_extension()):
			found.append(root.path_join(file))

	return found
