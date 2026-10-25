extends Node

## The prompt over what the player looks at: every prompt names its key ("[E] Inspect", "[E] Locked", "[E] Pull lever 2 down"), whoever
## wrote it; it is drawn as a key cap and a word on the theme's squared panel (like the inspect view's prompts), so it reads over the
## flashlight's bright circle; and what it says is in the game's language (the payphone's prompt is English in English). Run it as a scene;
## it quits by itself with a non-zero exit code on failure.

const PROMPT_KEYS: Array[String] = [
	"PROMPT_INTERACT", "PROMPT_PICK_UP", "PROMPT_OPEN", "PROMPT_CLOSE", "PROMPT_LOCKED", "PROMPT_UNLOCK", "PROMPT_INSPECT",
	"PROMPT_OPEN_ALBUM", "PROMPT_ENTER_CODE", "PROMPT_EXAMINE_ORELHAO", "PROMPT_PICK_UP_RECEIVER", "PROMPT_ROTATE_FILTER",
]

var test_failed: bool = false


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	var controller: PlayerInteractionController = PlayerInteractionController.new()
	add_child(controller)
	for locale: String in ["en", "pt_BR"]:
		GameSettings.set_text_locale(locale, false)
		for key: String in PROMPT_KEYS:
			var shown: String = InputBindings.format_text(controller._with_key(tr(key)))
			_expect(shown.begins_with("[") and shown.contains("]") and not shown.contains("{"), "%s (%s) names its key: '%s'" % [key, locale, shown])

		var lever: String = InputBindings.format_text(controller._with_key(tr("PROMPT_LEVER_PULL_DOWN") % 2))
		_expect(lever.begins_with("[E] "), "the lever prompt names its key (%s): '%s'" % [locale, lever])

	GameSettings.set_text_locale("en", false)
	_expect(tr("PROMPT_EXAMINE_ORELHAO") == "Examine Payphone", "the payphone's prompt is in English in English: '%s'" % tr("PROMPT_EXAMINE_ORELHAO"))
	_expect(tr("CAPTION_TOWER_DOOR_LOCKED") == "Where is the HQ key?", "the tower door's line asks for the key")
	GameSettings.set_text_locale("pt_BR", false)
	_expect(tr("PROMPT_EXAMINE_ORELHAO") == "Examinar o orelhão", "and in Portuguese in Portuguese")
	_expect(tr("CAPTION_TOWER_DOOR_LOCKED") == "Onde está a chave do QG?", "the tower door's line in Portuguese")
	GameSettings.set_text_locale("en", false)

	# The way a text is split into the cap and the word.
	var parts: PackedStringArray = InteractionPromptView.split_text("[E] Pick Up")
	_expect(parts[0] == "E" and parts[1] == "Pick Up", "'[E] Pick Up' is the key E and the word Pick Up")
	parts = InteractionPromptView.split_text("Pick Up")
	_expect(parts[0] == "" and parts[1] == "Pick Up", "a text with no key has no cap")

	# The view: shown on a squared panel of the theme, with the key cap and the word.
	var view: InteractionPromptView = InteractionPromptView.new()
	add_child(view)
	await get_tree().process_frame
	_expect(not view.visible and view.get_text().is_empty(), "the view starts hidden")
	view.show_prompt("[E] Inspect")
	await get_tree().process_frame
	_expect(view.visible and view.get_text() == "[E] Inspect", "it shows the prompt")
	var panel: StyleBoxFlat = view.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(panel != null and panel.corner_radius_top_left == UIConfig.corner_radius and panel.corner_radius_bottom_right == UIConfig.corner_radius, "on the theme's panel (corners as the other panels' and key caps')")
	_expect(panel != null and panel.bg_color.a < 0.9 and panel.bg_color.a > 0.5, "a little see through, so the item behind it can be seen")
	_expect(UIConfig.corner_radius == 0, "which is squared")
	_expect(view.size.x > 40.0 and view.size.y > 10.0 and view.position.y > get_viewport().get_visible_rect().size.y * 0.4, "sized to its contents, a little under the middle of the screen")
	_expect(view.size.y < 40.0, "and snug: %.0f px tall at the smallest font" % view.size.y)
	view.hide_prompt()
	_expect(not view.visible, "and hides")

	GameSettings.set_text_locale("en", false)
	print("INTERACTION_PROMPT_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
