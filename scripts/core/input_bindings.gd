extends Node

## The player's key bindings: which keys and mouse buttons trigger which actions,
## saved with the other settings and applied to the InputMap at start-up.
##
## The usual pattern of modern games:
## - every rebindable action has two slots (primary and alternate);
## - the defaults are the ones in the project's input map, captured at start-up,
##   so there is a single source of truth and "reset" always knows where to go;
## - a key already used by another action is a conflict the player resolves (swap
##   the two, or take the key from the other action), never silently both;
## - an action can never be left without a key, Escape is reserved, and only the
##   changes from the defaults are saved (so a changed default reaches players who
##   never touched that action);
## - everything the game tells the player about a control (prompts, hints, the
##   tutorial) is written with `{action}` tokens that `format_text` replaces with
##   the key the player really uses.
##
## Bindings are stored by physical key position (WASD stays WASD on an AZERTY
## keyboard and shows as ZQSD), and only keyboard keys and mouse buttons are
## handled here; other devices' events on an action are left untouched.

signal bindings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "bindings"
const SLOT_COUNT: int = 2

const TYPE_KEY: String = "key"
const TYPE_MOUSE: String = "mouse"

## Shown in this order in the settings. `label` is a localization key.
const CATEGORIES: Array[Dictionary] = [
	{"id": &"movement", "label": "BINDINGS_MOVEMENT"},
	{"id": &"actions", "label": "BINDINGS_ACTIONS"},
	{"id": &"inspect", "label": "BINDINGS_INSPECT"},
	{"id": &"interface", "label": "BINDINGS_INTERFACE"},
]

const ACTIONS: Array[Dictionary] = [
	{"action": &"up", "category": &"movement", "label": "BINDING_UP"},
	{"action": &"down", "category": &"movement", "label": "BINDING_DOWN"},
	{"action": &"left", "category": &"movement", "label": "BINDING_LEFT"},
	{"action": &"right", "category": &"movement", "label": "BINDING_RIGHT"},
	{"action": &"sprint", "category": &"movement", "label": "BINDING_SPRINT"},
	{"action": &"interact", "category": &"actions", "label": "BINDING_INTERACT"},
	{"action": &"flashlight", "category": &"actions", "label": "BINDING_FLASHLIGHT"},
	{"action": &"inventory", "category": &"actions", "label": "BINDING_INVENTORY"},
	{"action": &"inspect_flip", "category": &"inspect", "label": "BINDING_INSPECT_FLIP"},
	{"action": &"inspect_reset", "category": &"inspect", "label": "BINDING_INSPECT_RESET"},
	{"action": &"skip_cinematic", "category": &"interface", "label": "BINDING_SKIP_CINEMATIC"},
	{"action": &"dialog_continue", "category": &"interface", "label": "BINDING_DIALOG_CONTINUE"},
]

## Keys that are never bindable: Escape closes and pauses, the Windows key leaves
## the game.
const RESERVED_KEYS: Array = [KEY_ESCAPE, KEY_META, KEY_UNKNOWN, KEY_NONE]

## The left button is how the menus are clicked, so it is not bindable.
const BINDABLE_MOUSE_BUTTONS: Array = [
	MOUSE_BUTTON_RIGHT,
	MOUSE_BUTTON_MIDDLE,
	MOUSE_BUTTON_XBUTTON1,
	MOUSE_BUTTON_XBUTTON2,
]

## Names of keys the engine only knows in English (localization keys).
const KEY_NAME_KEYS: Dictionary = {
	KEY_SPACE: "KEY_NAME_SPACE",
	KEY_ENTER: "KEY_NAME_ENTER",
	KEY_KP_ENTER: "KEY_NAME_ENTER",
	KEY_SHIFT: "KEY_NAME_SHIFT",
	KEY_CTRL: "KEY_NAME_CTRL",
	KEY_ALT: "KEY_NAME_ALT",
	KEY_TAB: "KEY_NAME_TAB",
	KEY_BACKSPACE: "KEY_NAME_BACKSPACE",
	KEY_DELETE: "KEY_NAME_DELETE",
	KEY_UP: "KEY_NAME_UP",
	KEY_DOWN: "KEY_NAME_DOWN",
	KEY_LEFT: "KEY_NAME_LEFT",
	KEY_RIGHT: "KEY_NAME_RIGHT",
}

const MOUSE_NAME_KEYS: Dictionary = {
	MOUSE_BUTTON_LEFT: ["BINDING_MOUSE_LEFT", "BINDING_MOUSE_LEFT_SHORT"],
	MOUSE_BUTTON_RIGHT: ["BINDING_MOUSE_RIGHT", "BINDING_MOUSE_RIGHT_SHORT"],
	MOUSE_BUTTON_MIDDLE: ["BINDING_MOUSE_MIDDLE", "BINDING_MOUSE_MIDDLE_SHORT"],
	MOUSE_BUTTON_XBUTTON1: ["BINDING_MOUSE_4", "BINDING_MOUSE_4_SHORT"],
	MOUSE_BUTTON_XBUTTON2: ["BINDING_MOUSE_5", "BINDING_MOUSE_5_SHORT"],
}

## Where the bindings are kept (a test points it elsewhere).
var settings_path: String = SETTINGS_PATH

## action -> [slot 0, slot 1], each a binding Dictionary or {} when empty.
var _slots: Dictionary = {}
var _defaults: Dictionary = {}
## Events on an action that are not keyboard or mouse (kept as they are).
var _other_events: Dictionary = {}

var _key_label_pattern: RegEx = RegEx.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_key_label_pattern.compile("\\{(\\w+)\\}")

	_capture_defaults()
	load_bindings()


# ----------------------------------------------------------------------
# What the settings screen needs
# ----------------------------------------------------------------------

func get_categories() -> Array[Dictionary]:
	return CATEGORIES


func get_actions_in(category: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for entry: Dictionary in ACTIONS:
		if entry["category"] == category:
			found.append(entry["action"])

	return found


func get_action_label_key(action: StringName) -> String:
	for entry: Dictionary in ACTIONS:
		if entry["action"] == action:
			return entry["label"]

	return String(action)


func is_rebindable(action: StringName) -> bool:
	return _slots.has(action)


func get_binding(action: StringName, slot: int) -> Dictionary:
	if not _slots.has(action) or slot < 0 or slot >= SLOT_COUNT:
		return {}

	return (_slots[action] as Array)[slot]


func is_default(action: StringName) -> bool:
	if not _slots.has(action):
		return true

	return _slots_equal(_slots[action], _defaults[action])


func is_everything_default() -> bool:
	for action: Variant in _slots:
		if not is_default(action):
			return false

	return true


## True for a binding the player may use: no reserved key, no left mouse button.
func is_binding_allowed(binding: Dictionary) -> bool:
	match str(binding.get("type", "")):
		TYPE_KEY:
			return not RESERVED_KEYS.has(int(binding.get("code", 0)))
		TYPE_MOUSE:
			return BINDABLE_MOUSE_BUTTONS.has(int(binding.get("button", 0)))

	return false


## The binding a pressed key or mouse button stands for, or {} for anything else
## (releases, key repeats, motion, buttons that cannot be bound).
func binding_from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return {}

		var code: int = key_event.physical_keycode
		if code == 0:
			code = key_event.keycode

		return {"type": TYPE_KEY, "code": code}

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed:
			return {}

		return {"type": TYPE_MOUSE, "button": mouse_event.button_index}

	return {}


# ----------------------------------------------------------------------
# Changing bindings
# ----------------------------------------------------------------------

## Looks for another use of `binding`. Returns {"action", "slot"} or {}. The
## slot being edited is skipped.
func find_conflict(action: StringName, slot: int, binding: Dictionary) -> Dictionary:
	for other: Variant in _slots:
		for other_slot: int in SLOT_COUNT:
			if other == action and other_slot == slot:
				continue

			if _same_binding(get_binding(other, other_slot), binding):
				return {"action": other, "slot": other_slot}

	return {}


## Binds `binding` to a slot. If another action already uses it the call changes
## nothing and returns {"ok": false, "reason": "conflict", "conflict": {...},
## "can_swap": bool, "can_replace": bool}; call again with `resolution` set to
## &"swap" (the other action gets what this slot had) or &"replace" (the other
## action loses the key) to settle it. Returns {"ok": true} when done, or
## {"ok": false, "reason": ...} if the binding is not allowed or would leave an
## action with no key.
func set_binding(
	action: StringName,
	slot: int,
	binding: Dictionary,
	resolution: StringName = &""
) -> Dictionary:
	if not _slots.has(action) or slot < 0 or slot >= SLOT_COUNT:
		return {"ok": false, "reason": "unknown_action"}

	if not is_binding_allowed(binding):
		return {"ok": false, "reason": "not_allowed"}

	var current: Dictionary = get_binding(action, slot)
	if _same_binding(current, binding):
		return {"ok": true}

	var conflict: Dictionary = find_conflict(action, slot, binding)
	if conflict.is_empty():
		_write_slot(action, slot, binding)
		_commit()
		return {"ok": true}

	var other: StringName = conflict["action"]
	var other_slot: int = conflict["slot"]
	var same_action: bool = other == action
	# Swapping always works when this slot had a key to give. Taking the key away
	# only works if the other action keeps another one.
	var can_swap: bool = not current.is_empty() or same_action
	var can_replace: bool = same_action or _count_bindings(other) > 1

	if resolution == &"":
		return {
			"ok": false,
			"reason": "conflict",
			"conflict": conflict,
			"can_swap": can_swap,
			"can_replace": can_replace,
		}

	if resolution == &"swap" and not can_swap:
		return {"ok": false, "reason": "last_binding"}

	if resolution == &"replace" and not can_replace:
		return {"ok": false, "reason": "last_binding"}

	if resolution == &"swap":
		_write_slot(other, other_slot, current)
	else:
		_write_slot(other, other_slot, {})

	_write_slot(action, slot, binding)
	_commit()
	return {"ok": true}


## Empties a slot. The last key of an action cannot be removed.
func clear_binding(action: StringName, slot: int) -> bool:
	if not _slots.has(action) or slot < 0 or slot >= SLOT_COUNT:
		return false

	if get_binding(action, slot).is_empty():
		return true

	if _count_bindings(action) <= 1:
		return false

	_write_slot(action, slot, {})
	_commit()
	return true


func reset_action(action: StringName) -> void:
	if not _slots.has(action):
		return

	_slots[action] = _copy_slots(_defaults[action])
	# A default may be held by another action's changed binding; the defaults
	# win, and the other action falls back to a free key of its own.
	_resolve_clashes_after_reset(action)
	_commit()


func reset_all() -> void:
	for action: Variant in _slots:
		_slots[action] = _copy_slots(_defaults[action])

	_commit()


# ----------------------------------------------------------------------
# Telling the player
# ----------------------------------------------------------------------

## The name of the key or button an action uses, e.g. "E", "Shift", "Right Mouse
## Button". `slot` -1 means the first one that is set. `short` shortens mouse
## buttons ("RMB") for prompts.
func get_binding_label(action: StringName, slot: int = -1, short: bool = false) -> String:
	if not _slots.has(action):
		return String(action)

	if slot >= 0:
		return label_for_binding(get_binding(action, slot), short)

	for index: int in SLOT_COUNT:
		var binding: Dictionary = get_binding(action, index)
		if not binding.is_empty():
			return label_for_binding(binding, short)

	return tr("BINDING_UNBOUND")


func label_for_binding(binding: Dictionary, short: bool = false) -> String:
	match str(binding.get("type", "")):
		TYPE_KEY:
			return _key_label(int(binding.get("code", 0)))
		TYPE_MOUSE:
			var names: Array = MOUSE_NAME_KEYS.get(int(binding.get("button", 0)), [])
			if names.size() == 2:
				return tr(names[1] if short else names[0])

			return "Mouse %d" % int(binding.get("button", 0))

	return tr("BINDING_UNBOUND")


## Replaces every `{action}` in `text` with the key that action uses now, so
## "Hold {sprint} to walk faster" tells each player their own key. For a
## RichTextLabel pass `rich` to draw the key as a small key cap.
func format_text(text: String, rich: bool = false) -> String:
	var result: String = text
	for found: RegExMatch in _key_label_pattern.search_all(text):
		var action: StringName = StringName(found.get_string(1))
		if not _slots.has(action):
			continue

		var label: String = get_binding_label(action, -1, true)
		if rich:
			label = "[bgcolor=#2a2f33][color=#f3f0e4] %s [/color][/bgcolor]" % label

		result = result.replace(found.get_string(0), label)

	return result


# ----------------------------------------------------------------------
# Saving and loading
# ----------------------------------------------------------------------

## Only the actions that differ from their defaults are written.
func save_bindings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(settings_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		config = ConfigFile.new()

	if config.has_section(SECTION):
		config.erase_section(SECTION)

	for action: Variant in _slots:
		if is_default(action):
			continue

		var saved: Array = []
		for slot: int in SLOT_COUNT:
			saved.append(_binding_to_string(get_binding(action, slot)))

		config.set_value(SECTION, String(action), saved)

	var save_error: Error = config.save(settings_path)
	if save_error != OK:
		push_error("InputBindings: Could not save settings.cfg. Error code: %s" % save_error)


func load_bindings() -> void:
	for action: Variant in _slots:
		_slots[action] = _copy_slots(_defaults[action])

	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) == OK and config.has_section(SECTION):
		for action: Variant in _slots:
			if not config.has_section_key(SECTION, String(action)):
				continue

			var saved: Variant = config.get_value(SECTION, String(action), [])
			if not saved is Array:
				continue

			var loaded: Array = [{}, {}]
			for slot: int in mini((saved as Array).size(), SLOT_COUNT):
				var binding: Dictionary = _binding_from_string(str((saved as Array)[slot]))
				if is_binding_allowed(binding):
					loaded[slot] = binding

			_slots[action] = loaded

	_sanitize()
	_apply_all()
	bindings_changed.emit()


# ----------------------------------------------------------------------
# Internals
# ----------------------------------------------------------------------

func _capture_defaults() -> void:
	_slots.clear()
	_defaults.clear()
	_other_events.clear()

	for entry: Dictionary in ACTIONS:
		var action: StringName = entry["action"]
		if not InputMap.has_action(action):
			push_warning("InputBindings: the input map has no action '%s'." % action)
			continue

		var found: Array = [{}, {}]
		var others: Array[InputEvent] = []
		var next_slot: int = 0

		for event: InputEvent in InputMap.action_get_events(action):
			var binding: Dictionary = binding_from_event_ignoring_state(event)
			if binding.is_empty() or next_slot >= SLOT_COUNT:
				others.append(event)
				continue

			found[next_slot] = binding
			next_slot += 1

		_defaults[action] = found
		_slots[action] = _copy_slots(found)
		_other_events[action] = others


## Like `binding_from_event` but for events stored in the input map, whose
## `pressed` flag is not set.
func binding_from_event_ignoring_state(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var code: int = key_event.physical_keycode
		if code == 0:
			code = key_event.keycode

		if code == 0:
			return {}

		return {"type": TYPE_KEY, "code": code}

	if event is InputEventMouseButton:
		return {"type": TYPE_MOUSE, "button": (event as InputEventMouseButton).button_index}

	return {}


func _make_event(binding: Dictionary) -> InputEvent:
	match str(binding.get("type", "")):
		TYPE_KEY:
			var key_event: InputEventKey = InputEventKey.new()
			key_event.physical_keycode = int(binding.get("code", 0)) as Key
			return key_event
		TYPE_MOUSE:
			var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
			mouse_event.button_index = int(binding.get("button", 0)) as MouseButton
			return mouse_event

	return null


func _apply_all() -> void:
	for action: Variant in _slots:
		_apply_action(action)


func _apply_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		return

	InputMap.action_erase_events(action)

	for slot: int in SLOT_COUNT:
		var binding: Dictionary = get_binding(action, slot)
		if binding.is_empty():
			continue

		var event: InputEvent = _make_event(binding)
		if event != null:
			InputMap.action_add_event(action, event)

	for event: InputEvent in _other_events.get(action, []):
		InputMap.action_add_event(action, event)


func _write_slot(action: StringName, slot: int, binding: Dictionary) -> void:
	(_slots[action] as Array)[slot] = binding
	_normalise(action)


## An action whose first slot is empty gives it the alternate key.
func _normalise(action: StringName) -> void:
	var slots: Array = _slots[action]
	if (slots[0] as Dictionary).is_empty() and not (slots[1] as Dictionary).is_empty():
		slots[0] = slots[1]
		slots[1] = {}


func _commit() -> void:
	_apply_all()
	save_bindings()
	bindings_changed.emit()


func _count_bindings(action: StringName) -> int:
	var count: int = 0
	for slot: int in SLOT_COUNT:
		if not get_binding(action, slot).is_empty():
			count += 1

	return count


## Keeps a loaded or reset set of bindings valid: no key used twice (the earlier
## action in the list keeps it) and no action without a key.
func _sanitize() -> void:
	var used: Array[Dictionary] = []
	for entry: Dictionary in ACTIONS:
		var action: StringName = entry["action"]
		if not _slots.has(action):
			continue

		for slot: int in SLOT_COUNT:
			var binding: Dictionary = get_binding(action, slot)
			if binding.is_empty():
				continue

			var taken: bool = false
			for other: Dictionary in used:
				if _same_binding(other, binding):
					taken = true
					break

			if taken:
				(_slots[action] as Array)[slot] = {}
			else:
				used.append(binding)

		_normalise(action)
		if _count_bindings(action) == 0:
			_slots[action] = _copy_slots(_defaults[action])
			_resolve_clashes_after_reset(action)
			for slot: int in SLOT_COUNT:
				if not get_binding(action, slot).is_empty():
					used.append(get_binding(action, slot))


## After an action goes back to its defaults, any other action that held one of
## those keys loses it (and falls back to its own defaults if that leaves it empty).
func _resolve_clashes_after_reset(action: StringName) -> void:
	for slot: int in SLOT_COUNT:
		var binding: Dictionary = get_binding(action, slot)
		if binding.is_empty():
			continue

		for other: Variant in _slots:
			if other == action:
				continue

			for other_slot: int in SLOT_COUNT:
				if _same_binding(get_binding(other, other_slot), binding):
					(_slots[other] as Array)[other_slot] = {}

			_normalise(other)
			if _count_bindings(other) == 0:
				_slots[other] = _copy_slots(_defaults[other])


func _copy_slots(slots: Array) -> Array:
	return [(slots[0] as Dictionary).duplicate(), (slots[1] as Dictionary).duplicate()]


func _slots_equal(a: Array, b: Array) -> bool:
	for slot: int in SLOT_COUNT:
		if not _same_binding(a[slot], b[slot]):
			return false

	return true


func _same_binding(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return a.is_empty() and b.is_empty()

	if a.get("type", "") != b.get("type", ""):
		return false

	if a.get("type", "") == TYPE_KEY:
		return int(a.get("code", 0)) == int(b.get("code", 0))

	return int(a.get("button", 0)) == int(b.get("button", 0))


func _binding_to_string(binding: Dictionary) -> String:
	match str(binding.get("type", "")):
		TYPE_KEY:
			return "%s:%d" % [TYPE_KEY, int(binding.get("code", 0))]
		TYPE_MOUSE:
			return "%s:%d" % [TYPE_MOUSE, int(binding.get("button", 0))]

	return ""


func _binding_from_string(text: String) -> Dictionary:
	var parts: PackedStringArray = text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return {}

	match parts[0]:
		TYPE_KEY:
			return {"type": TYPE_KEY, "code": int(parts[1])}
		TYPE_MOUSE:
			return {"type": TYPE_MOUSE, "button": int(parts[1])}

	return {}


func _key_label(physical_code: int) -> String:
	# The key at that position on this keyboard (a layout may print another
	# letter there).
	var code: int = physical_code
	# (A server without a window, as in the automated tests, cannot be asked.)
	if DisplayServer.get_name() != "headless":
		code = DisplayServer.keyboard_get_keycode_from_physical(physical_code as Key)
		if code == KEY_NONE:
			code = physical_code

	if KEY_NAME_KEYS.has(code):
		return tr(KEY_NAME_KEYS[code])

	var key_name: String = OS.get_keycode_string(code as Key)
	if key_name.is_empty():
		return "?"

	return key_name
