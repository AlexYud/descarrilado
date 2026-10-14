extends Node

## Applies the game's UI theme (built from `UIConfig`) and the player's UI size to every Control
## of the game, at runtime.
##
## The theme is set on the root Window, so every Control (and embedded dialog) in every scene
## inherits it; nothing else needs to reference it. `refresh()` rebuilds it after `UIConfig`
## changed (a new palette, font or size), so the whole UI can be restyled in one call.
## The UI size (Options > Graphics > UI Size: small, medium, large) is a set of hand-picked font sizes in
## `UIConfig.UI_SIZES`, not a stretch of the screen (that blurs text): on a change the manager applies the
## set and rebuilds the whole theme.
##
## Two things a theme cannot do are done here, per Control:
## - Every plain Button gets the selection arrow icon, which the theme shows only while the button
##   is hovered, focused or pressed (see UIConfig.arrow_icon).
## - Capitals. Labels of the variations in `UIConfig.uppercase_labels` use `Label.uppercase`.
##   A Button has no such property and its text is usually a translation key, so with
##   `UIConfig.uppercase_buttons` the manager shows `tr(text).to_upper()` itself: it turns the
##   button's auto-translation off, remembers the key, re-translates when the language changes
##   and upper-cases any text a script sets later (when the button is drawn or resized).

const META_KEY: StringName = &"ui_text_key"
const SHOWN_META: StringName = &"ui_text_shown"

var theme: Theme = null
var _buttons: Array[Button] = []


func _ready() -> void:
	UIConfig.apply_ui_size(GameSettings.get_ui_size_index())
	refresh()
	get_tree().node_added.connect(_on_node_added)
	GameSettings.ui_size_changed.connect(_on_ui_size_changed)
	GameSettings.text_language_changed.connect(_on_language_changed)


## Rebuilds the theme from `UIConfig` and applies it to the whole game.
func refresh() -> void:
	# The controls use the PROJECT theme (gui/theme/custom, the baked preview file; a theme set on the
	# root window is ignored), and they only follow a change of the object they already have: so the
	# project theme is cleared and refilled in place.
	var fresh: Theme = UIConfig.build_theme()
	theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = Theme.new()
		get_tree().root.theme = theme

	theme.clear()
	theme.default_font = fresh.default_font
	theme.default_font_size = fresh.default_font_size
	theme.merge_with(fresh)
	for node: Node in get_tree().root.find_children("*", "Label", true, false):
		_on_node_added(node)

	for node: Node in get_tree().root.find_children("*", "Button", true, false):
		_on_node_added(node)


func _on_ui_size_changed(size_index: int) -> void:
	UIConfig.apply_ui_size(size_index)
	refresh()


func _on_node_added(node: Node) -> void:
	if node is Label:
		var label: Label = node as Label
		# Only labels of the listed variations are touched (a label that asks for capitals itself is left alone).
		if UIConfig.uppercase_labels.has(label.theme_type_variation):
			label.uppercase = true
			label.set_meta(&"ui_upper_set", true)
		elif label.has_meta(&"ui_upper_set"):
			label.uppercase = false
			label.remove_meta(&"ui_upper_set")
	elif node is Button and _is_plain_button(node as Button):
		var button: Button = node as Button
		if UIConfig.selection_arrow and button.icon == null:
			button.icon = UIConfig.arrow_icon()
			# The arrow sits right before the text: Godot cannot put an icon next to CENTRED text, so menu
			# items are left-aligned (UIConfig.menu_items_left), as in a classic game menu.
			if UIConfig.menu_items_left and button.alignment == HORIZONTAL_ALIGNMENT_CENTER:
				button.alignment = HORIZONTAL_ALIGNMENT_LEFT

			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

		if UIConfig.uppercase_buttons:
			_track_for_capitals(button)


## Plain buttons get the arrow and the capitals; check boxes, switches, drop-downs and the like do not.
func _is_plain_button(button: Button) -> bool:
	return not (button is CheckBox or button is CheckButton or button is OptionButton or button is MenuButton or button is ColorPickerButton)


func _track_for_capitals(button: Button) -> void:
	if _buttons.has(button):
		return

	_buttons.append(button)
	button.tree_exited.connect(_forget.bind(button), CONNECT_ONE_SHOT)
	# Safety nets for text set later by a script: a change of text changes the size or redraws.
	button.minimum_size_changed.connect(_capitalise.bind(button))
	button.draw.connect(_capitalise.bind(button))
	_capitalise(button)


func _forget(button: Button) -> void:
	_buttons.erase(button)


## Keeps the button's text in capitals. The manager remembers the key it translated and the text it
## last showed (`SHOWN_META`): a text equal to that is its own (it only follows the language); any
## other text was set by a script and is either a translation key (translated here, with the
## button's own auto-translation turned off so it is not translated back to lower case) or plain
## text (simply upper-cased).
func _capitalise(button: Button) -> void:
	var text: String = button.text
	if text.is_empty():
		return

	var key: String = String(button.get_meta(META_KEY, ""))
	if not key.is_empty() and text == String(button.get_meta(SHOWN_META, "")):
		_show_key(button, key)
		return

	button.remove_meta(META_KEY)
	button.remove_meta(SHOWN_META)
	if tr(text) != text:
		_show_key(button, text)
	elif text != text.to_upper():
		button.text = text.to_upper()


## Shows `tr(key)` in capitals on the button.
func _show_key(button: Button, key: String) -> void:
	var shown: String = tr(key).to_upper()
	button.set_meta(META_KEY, key)
	button.set_meta(SHOWN_META, shown)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if button.text != shown:
		button.text = shown


func _on_language_changed(_locale: String) -> void:
	_retranslate.call_deferred()


func _retranslate() -> void:
	for button: Button in _buttons:
		if is_instance_valid(button) and button.has_meta(META_KEY):
			_show_key(button, String(button.get_meta(META_KEY)))
