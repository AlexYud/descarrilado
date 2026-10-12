extends Node

## Checks the key binding system: defaults, rebinding, conflicts (swap, replace,
## blocked), the one-key-minimum and reserved keys, saving only changes, reset, and
## the {action} tokens in texts. It uses a temporary settings file and puts the
## bindings back afterwards. Run it as a scene; it quits by itself with a non-zero
## exit code on failure.

const TEST_SETTINGS_PATH: String = "user://codex_input_bindings_test.cfg"

var test_failed: bool = false


func _ready() -> void:
	DirAccess.remove_absolute(TEST_SETTINGS_PATH)
	InputBindings.settings_path = TEST_SETTINGS_PATH
	InputBindings.reset_all()

	_check_defaults()
	_check_rebinding()
	_check_conflicts()
	_check_minimum_and_reserved()
	_check_saving()
	_check_reset()
	_check_texts()
	_check_removed_actions()

	InputBindings.reset_all()
	InputBindings.settings_path = InputBindings.SETTINGS_PATH
	DirAccess.remove_absolute(TEST_SETTINGS_PATH)
	print("INPUT_BINDINGS_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _key(code: Key) -> Dictionary:
	return {"type": "key", "code": int(code)}


func _press(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _check_defaults() -> void:
	_expect(InputBindings.get_binding_label(&"up") == "W", "forward is W by default")
	_expect(InputBindings.get_binding_label(&"interact") == "E", "interact is E by default")
	_expect(InputBindings.get_binding_label(&"flashlight") == "F", "the flashlight is F by default")
	_expect(
		InputBindings.get_binding_label(&"sprint") == tr("KEY_NAME_SHIFT"),
		"walking faster is Shift by default"
	)
	_expect(InputBindings.is_everything_default(), "nothing starts changed")
	_expect(InputMap.event_is_action(_press(KEY_W), &"up"), "the input map has W for forward")

	for action: StringName in [&"up", &"down", &"left", &"right", &"sprint", &"interact", &"flashlight", &"inventory"]:
		_expect(InputBindings.is_rebindable(action), "%s can be rebound" % action)

	_expect(not InputMap.has_action(&"jump") and not InputMap.has_action(&"crouch"), "there is no jump or crouch")


func _check_rebinding() -> void:
	var result: Dictionary = InputBindings.set_binding(&"interact", 1, _key(KEY_Y))
	_expect(bool(result["ok"]), "an alternate key can be added")
	_expect(InputMap.event_is_action(_press(KEY_Y), &"interact"), "the new key triggers the action")
	_expect(InputMap.event_is_action(_press(KEY_E), &"interact"), "the old key still does")
	_expect(not InputBindings.is_default(&"interact"), "the action counts as changed")

	result = InputBindings.set_binding(&"interact", 0, _key(KEY_U))
	_expect(bool(result["ok"]), "the primary key can be replaced")
	_expect(not InputMap.event_is_action(_press(KEY_E), &"interact"), "the replaced key no longer triggers it")
	_expect(InputBindings.get_binding_label(&"interact") == "U", "prompts name the primary key")

	var mouse: Dictionary = {"type": "mouse", "button": MOUSE_BUTTON_MIDDLE}
	result = InputBindings.set_binding(&"flashlight", 1, mouse)
	_expect(bool(result["ok"]), "a mouse button can be bound")
	_expect(
		InputBindings.get_binding_label(&"flashlight", 1) == tr("BINDING_MOUSE_MIDDLE"),
		"and is named"
	)

	InputBindings.reset_all()


func _check_conflicts() -> void:
	var result: Dictionary = InputBindings.set_binding(&"flashlight", 0, _key(KEY_E))
	_expect(not bool(result["ok"]) and result["reason"] == "conflict", "a key in use is a conflict")
	_expect(result["conflict"]["action"] == &"interact", "the conflict names the other action")
	_expect(bool(result["can_swap"]) and not bool(result["can_replace"]), "swap works, taking the only key does not")
	_expect(InputBindings.get_binding_label(&"flashlight") == "F", "nothing changes until it is settled")

	result = InputBindings.set_binding(&"flashlight", 0, _key(KEY_E), &"swap")
	_expect(bool(result["ok"]), "swapping works")
	_expect(InputBindings.get_binding_label(&"flashlight") == "E", "the flashlight took E")
	_expect(InputBindings.get_binding_label(&"interact") == "F", "interact took F")
	_expect(InputMap.event_is_action(_press(KEY_F), &"interact"), "the input map follows")

	# Taking a key from an action that has another one is allowed.
	InputBindings.reset_all()
	InputBindings.set_binding(&"interact", 1, _key(KEY_Y))
	result = InputBindings.set_binding(&"inventory", 1, _key(KEY_E))
	_expect(bool(result["can_replace"]), "the key of an action with two keys can be taken")
	result = InputBindings.set_binding(&"inventory", 1, _key(KEY_E), &"replace")
	_expect(bool(result["ok"]), "replacing works")
	_expect(InputBindings.get_binding_label(&"interact") == "Y", "the other action kept its remaining key")
	_expect(InputBindings.get_binding(&"interact", 1).is_empty(), "and lost the taken one")

	# An action can never be left without a key by a conflict.
	InputBindings.reset_all()
	result = InputBindings.set_binding(&"flashlight", 1, _key(KEY_E))
	_expect(not bool(result["can_swap"]) and not bool(result["can_replace"]), "no way to settle it")
	result = InputBindings.set_binding(&"flashlight", 1, _key(KEY_E), &"replace")
	_expect(not bool(result["ok"]), "forcing it is refused")
	_expect(InputBindings.get_binding_label(&"interact") == "E", "interact keeps its key")

	InputBindings.reset_all()


func _check_minimum_and_reserved() -> void:
	_expect(not InputBindings.clear_binding(&"up", 0), "the only key of an action cannot be removed")
	InputBindings.set_binding(&"up", 1, _key(KEY_UP))
	_expect(InputBindings.clear_binding(&"up", 0), "with two keys one can be removed")
	_expect(InputBindings.get_binding_label(&"up") == tr("KEY_NAME_UP"), "the other becomes the primary")
	_expect(InputBindings.get_binding(&"up", 1).is_empty(), "and the second slot is free")

	var result: Dictionary = InputBindings.set_binding(&"sprint", 1, _key(KEY_ESCAPE))
	_expect(not bool(result["ok"]) and result["reason"] == "not_allowed", "Escape is reserved")
	result = InputBindings.set_binding(&"sprint", 1, {"type": "mouse", "button": MOUSE_BUTTON_LEFT})
	_expect(not bool(result["ok"]), "the left mouse button is reserved")
	result = InputBindings.set_binding(&"sprint", 1, _key(KEY_META))
	_expect(not bool(result["ok"]), "the Windows key is reserved")

	_expect(
		InputBindings.binding_from_event(_press(KEY_Q)) == _key(KEY_Q),
		"a pressed key becomes a binding"
	)
	var released: InputEventKey = _press(KEY_Q)
	released.pressed = false
	_expect(InputBindings.binding_from_event(released).is_empty(), "a release is not a binding")
	var repeat: InputEventKey = _press(KEY_Q)
	repeat.echo = true
	_expect(InputBindings.binding_from_event(repeat).is_empty(), "a key repeat is not a binding")

	InputBindings.reset_all()


func _check_saving() -> void:
	InputBindings.set_binding(&"inventory", 0, _key(KEY_B))
	var config: ConfigFile = ConfigFile.new()
	_expect(config.load(TEST_SETTINGS_PATH) == OK, "changes are saved")
	_expect(config.has_section_key("bindings", "inventory"), "the changed action is saved")
	_expect(not config.has_section_key("bindings", "up"), "unchanged actions are not")

	InputBindings.load_bindings()
	_expect(InputBindings.get_binding_label(&"inventory") == "B", "the change survives a reload")
	_expect(InputMap.event_is_action(_press(KEY_B), &"inventory"), "and is applied to the input map")

	# A hand-edited file cannot break the controls.
	config.set_value("bindings", "up", ["key:4194305", "garbage"])
	config.set_value("bindings", "down", ["key:87", ""])
	config.set_value("bindings", "nonsense", ["key:65", ""])
	config.save(TEST_SETTINGS_PATH)
	InputBindings.load_bindings()
	_expect(InputBindings.get_binding_label(&"up") == "W", "an unusable binding falls back to the default")
	_expect(
		InputBindings.get_binding_label(&"down") != "W" or InputBindings.get_binding_label(&"up") != "W",
		"a key is never used twice"
	)
	_expect(InputBindings.get_binding(&"down", 0) != InputBindings.get_binding(&"up", 0), "the two actions differ")

	InputBindings.reset_all()


func _check_reset() -> void:
	InputBindings.set_binding(&"flashlight", 0, _key(KEY_G))
	InputBindings.set_binding(&"inventory", 0, _key(KEY_B))
	InputBindings.reset_action(&"flashlight")
	_expect(InputBindings.get_binding_label(&"flashlight") == "F", "one action goes back to its default")
	_expect(InputBindings.get_binding_label(&"inventory") == "B", "the others stay as they are")

	InputBindings.reset_all()
	_expect(InputBindings.is_everything_default(), "everything goes back to the defaults")
	var config: ConfigFile = ConfigFile.new()
	config.load(TEST_SETTINGS_PATH)
	_expect(not config.has_section("bindings") or config.get_section_keys("bindings").is_empty(), "and nothing stays saved")


func _check_texts() -> void:
	_expect(InputBindings.format_text("[{interact}] Open") == "[E] Open", "prompts name the interact key")
	InputBindings.set_binding(&"interact", 0, _key(KEY_Z))
	_expect(InputBindings.format_text("[{interact}] Open") == "[Z] Open", "and follow a new binding")
	_expect(InputBindings.format_text("Slot {slot}") == "Slot {slot}", "other tokens are left alone")
	_expect(
		InputBindings.format_text("Hold {sprint}", true).contains("bgcolor"),
		"rich text draws the key as a key cap"
	)
	var prompt: String = InputBindings.format_text(tr("PROMPT_OPEN"))
	_expect(prompt.begins_with("[Z]"), "the real interaction prompt follows the binding (%s)" % prompt)
	InputBindings.reset_all()


func _check_removed_actions() -> void:
	for locale: String in ["en", "pt_BR"]:
		var previous: String = TranslationServer.get_locale()
		TranslationServer.set_locale(locale)
		for key: String in ["TUTORIAL_SPRINT_HOLD", "TUTORIAL_SPRINT_TOGGLE", "BINDING_UP", "BINDING_CONFLICT_TEXT", "BINDINGS_RESET_ALL"]:
			_expect(tr(key) != key, "%s is translated in %s" % [key, locale])
		TranslationServer.set_locale(previous)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
