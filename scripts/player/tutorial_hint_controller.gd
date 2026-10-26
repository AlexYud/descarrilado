extends Node
class_name TutorialHintController

## Teaches the player a control, the way modern games teach it: a short, non-blocking
## hint at the bottom of the screen, shown when it is relevant and not before. There
## are three lessons: walking faster (below), the inventory and the map (at the end of
## this comment).
##
## - It waits until the player has walked a while at the normal pace (they know
##   how to move and have not found the faster pace on their own).
## - It names the key the player really uses (`{sprint}` is replaced by the
##   current binding, and the wording follows hold or toggle mode), and follows
##   the binding if it is changed meanwhile.
## - It never shows over a cutscene, a dialogue, a close-up, the inventory or the
##   pause menu, and it counts nothing while one of those is open.
## - It goes away the moment the player does it (a second of walking fast), or
##   after a while if ignored, and comes back once more later, then gives up.
## - Players who find the faster pace before the hint appears never see it: in a level
##   with a trigger that means a player who is already walking fast when they reach it
##   or while they are beyond it (the hint is not for them).
## - It is remembered per saved game, and can be turned off in the Controls
##   settings ("Tutorial hints").
##
## The other two lessons are started by what gives the player the thing (`trigger(&"inventory")`
## from `Collectible` when the first item is picked up, `trigger(&"map")` from `PinnedCollectible`
## when the trail map is taken; a saved game that started one and has not learned it starts it
## again): once the player is back in the game, a second later, "Press {inventory} to open the
## inventory" / "Press {map} to open the map" comes up at the bottom, in the same style. It goes
## away the moment they do it (open the inventory, or the map), or after a while if ignored, and
## comes back once, then gives up. It is the only hint on screen while it shows (the walking one
## waits), it never shows over a cutscene, a dialogue, a close-up, the inventory or the pause
## menu, it is remembered per saved game, and the same "Tutorial hints" setting turns it off.

const STATE_SECTION: StringName = &"tutorials"
## (The earlier key `sprint_done` is not read: it was set by an older trigger design,
## and by testers who had already walked fast.)
const KEY_SPRINT_DONE: StringName = &"sprint_hint_done"

## The lessons of a thing that is given: the id `trigger` is called with, the key of the saved game, the localization key of the text.
const LESSONS: Array[Dictionary] = [
	{"id": &"inventory", "done": &"inventory_hint_done", "wanted": &"inventory_hint_wanted", "text": "TUTORIAL_INVENTORY"},
	{"id": &"map", "done": &"map_hint_done", "wanted": &"map_hint_wanted", "text": "TUTORIAL_MAP"},
]

## How far the player walks at the normal pace before the first hint (world units).
@export var distance_before_hint: float = 14.0
## With a `TutorialTrigger` in the level (the dream intro has one past the fence gate)
## the hint waits for the player to enter it, then for this much walking, so it
## comes once they are in the woods rather than on the clock.
@export var distance_after_trigger: float = 6.0
## How long the hint stays if ignored.
@export var show_seconds: float = 14.0
## Walking time before the second showing, after the first was ignored.
@export var remind_after_seconds: float = 45.0
@export var max_showings: int = 2
## Walking fast for this long counts as having learned it.
@export var seconds_to_learn: float = 1.2
@export var font_size: int = 26
## Distance of the hint from the bottom of the screen.
@export var bottom_margin: float = 170.0
@export var fade_seconds: float = 0.35

## How long after the player is back in the game (the thing's own view closed) the hint of the inventory or the map comes up, and how
## long the player is left alone before it comes back.
@export var lesson_delay: float = 1.0
@export var lesson_remind_seconds: float = 30.0

## Without an active saved game (a test, a playtest scene) the lesson is only
## remembered for this run.
static var _learned_this_run: bool = false
## The same for the inventory and the map lessons, by id.
static var _lessons_learned_this_run: Dictionary = {}

var is_showing: bool = false

var _player: CharacterBody3D = null
var _layer: CanvasLayer = null
var _label: RichTextLabel = null
var _tween: Tween = null
## The state of each lesson of a thing given, by id (see `LESSONS`).
var _lessons: Dictionary = {}

var _learned: bool = false
var _walked_distance: float = 0.0
var _showing_time: float = 0.0
var _showings: int = 0
var _fast_time: float = 0.0
var _paused_while_showing: bool = false
var _triggered: bool = false
var _needs_trigger: bool = false
var _trigger_checked: bool = false


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_build_ui()

	_learned = _was_learned()
	for lesson: Dictionary in LESSONS:
		var id: StringName = lesson["id"]
		var state: Dictionary = _lessons[id]
		state["learned"] = _lesson_was_learned(id)
		# A game that was given the thing but has not learned its key is taught now.
		state["wanted"] = not state["learned"] and _lesson_was_wanted(id)
		state["wait"] = lesson_delay

	InputBindings.bindings_changed.connect(_refresh_text)
	GameSettings.sprint_toggle_changed.connect(_on_sprint_toggle_changed)
	GameSettings.tutorial_hints_changed.connect(_on_tutorial_hints_changed)


func _process(delta: float) -> void:
	if _player == null:
		return

	var lesson_on_screen: bool = _process_lessons(delta)
	if lesson_on_screen:
		# One lesson on screen at a time: the walking one waits.
		_hide()
		return

	if _learned or not GameSettings.get_tutorial_hints():
		_paused_while_showing = false
		_hide()
		return

	if not _is_gameplay_active():
		# A dialogue or a menu covers the hint; it returns afterwards.
		if is_showing:
			_paused_while_showing = true
		_hide()
		return

	if _paused_while_showing:
		_paused_while_showing = false
		_showing_time = 0.0
		is_showing = true
		_refresh_text()
		_fade_to(1.0)

	var movement: Node = _player.get("movement_controller") as Node
	if movement == null:
		return

	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()

	if not _trigger_checked:
		_trigger_checked = true
		_needs_trigger = not get_tree().get_nodes_in_group(
			TutorialTrigger.group_name(&"sprint")
		).is_empty()

	# Walking fast, for long enough, is the lesson learned. In a level with a trigger
	# it only counts once they have reached it (or while the hint is on screen): whoever
	# walked fast about the yard still gets the hint at the gate, but whoever is already
	# walking fast past it needs none, and it goes away as soon as they do it.
	var may_learn: bool = is_showing or not _needs_trigger or _triggered
	if (
		may_learn
		and bool(movement.get("is_sprinting"))
		and speed > PlayerMovementController.WALK_SPEED * 1.1
	):
		_fast_time += delta
		if _fast_time >= seconds_to_learn:
			_mark_learned()
			_hide()
			return

	if is_showing:
		_showing_time += delta
		if _showing_time >= show_seconds:
			_give_up_for_now()
		return

	# A level with a trigger teaches nothing before the player reaches it.
	if _needs_trigger and not _triggered:
		return

	if speed > 0.4 and _player.is_on_floor():
		_walked_distance += speed * delta

	var needed: float = distance_after_trigger if _needs_trigger else distance_before_hint
	if _showings > 0:
		needed = remind_after_seconds * PlayerMovementController.WALK_SPEED

	if _walked_distance >= needed:
		_show()


## True while the hint of the inventory or of the map is on screen (the id says which; none: either).
func is_lesson_showing(id: StringName = &"") -> bool:
	for lesson_id: StringName in _lessons:
		if (id == &"" or id == lesson_id) and bool(_lessons[lesson_id]["showing"]):
			return true

	return false


func is_lesson_learned(id: StringName) -> bool:
	return _lessons.has(id) and bool(_lessons[id]["learned"])


## The lessons of the inventory and the map: each is shown once the player is back in the game, until they do what it says. Returns
## whether one is on screen (a second one waits for the first).
func _process_lessons(delta: float) -> bool:
	var on_screen: bool = false
	for lesson: Dictionary in LESSONS:
		var id: StringName = lesson["id"]
		var state: Dictionary = _lessons[id]
		if on_screen and not bool(state["showing"]):
			continue

		if _process_lesson(id, state, delta):
			on_screen = true

	return on_screen


func _process_lesson(id: StringName, state: Dictionary, delta: float) -> bool:
	if not state["wanted"] or state["learned"] or not GameSettings.get_tutorial_hints():
		_hide_lesson(id)
		return false

	# Doing what it says is the lesson learned (checked before the gameplay test: the inventory is a menu, the map is a close-up).
	if _lesson_done(id):
		_mark_lesson_learned(id)
		return false

	# The hint is about opening the map: while it is open (it was shown as it was taken) there
	# is nothing to tell; the hint comes a moment after it is put away.
	if id == &"map" and _map_is_open():
		state["wait"] = lesson_delay
		_hide_lesson(id)
		return false

	if not _is_gameplay_active():
		# The close-up of the thing, a dialogue or a menu covers the hint; it comes back a moment after.
		if state["showing"]:
			state["wait"] = lesson_delay

		_hide_lesson(id)
		return false

	if state["showing"]:
		state["showing_time"] += delta
		if state["showing_time"] >= show_seconds:
			_hide_lesson(id)
			state["wait"] = lesson_remind_seconds
			if state["showings"] >= max_showings:
				_mark_lesson_learned(id)
				return false

		return bool(state["showing"])

	state["wait"] -= delta
	if state["wait"] <= 0.0:
		_show_lesson(id)
		return true

	return false


func _show_lesson(id: StringName) -> void:
	var state: Dictionary = _lessons[id]
	state["showings"] += 1
	state["showing_time"] = 0.0
	state["showing"] = true
	_refresh_text()
	_fade_label(state, 1.0)


func _hide_lesson(id: StringName) -> void:
	var state: Dictionary = _lessons[id]
	var label: RichTextLabel = state["label"]
	if not state["showing"] and (label == null or label.modulate.a <= 0.0):
		return

	state["showing"] = false
	_fade_label(state, 0.0)


func _fade_label(state: Dictionary, alpha: float) -> void:
	var label: RichTextLabel = state["label"]
	if label == null:
		return

	var old: Tween = state["tween"]
	if old != null and old.is_valid():
		old.kill()

	if alpha > 0.0:
		label.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", alpha, fade_seconds)
	if alpha <= 0.0:
		tween.tween_callback(func() -> void: label.visible = false)

	state["tween"] = tween


## Whether the player has done what the lesson says: opened the inventory, or the map.
func _lesson_done(id: StringName) -> bool:
	if id == &"inventory":
		var inventory: Object = _player.get("inventory_ui_controller") as Object
		return inventory != null and inventory.has_method("is_inventory_open") and bool(inventory.call("is_inventory_open")) and not _map_is_open()

	if id == &"map":
		return _map_is_open() and bool((_player.get("map_controller") as Object).get("opened_by_player"))

	return false


func _map_is_open() -> bool:
	var maps: Object = _player.get("map_controller") as Object
	return maps != null and bool(maps.get("is_open"))


func _mark_lesson_learned(id: StringName) -> void:
	var state: Dictionary = _lessons[id]
	state["learned"] = true
	_lessons_learned_this_run[id] = true
	_hide_lesson(id)

	if SaveManager.has_active_game():
		SaveManager.set_state_value(STATE_SECTION, _lesson_key(id, "done"), true)


func _lesson_key(id: StringName, which: String) -> StringName:
	for lesson: Dictionary in LESSONS:
		if lesson["id"] == id:
			return lesson[which]

	return &""


func _lesson_was_learned(id: StringName) -> bool:
	if SaveManager.has_active_game():
		return bool(SaveManager.get_state_value(STATE_SECTION, _lesson_key(id, "done"), false))

	return bool(_lessons_learned_this_run.get(id, false))


## Started before (the game was saved between the thing being given and the lesson being learned).
func _lesson_was_wanted(id: StringName) -> bool:
	return SaveManager.has_active_game() and bool(SaveManager.get_state_value(STATE_SECTION, _lesson_key(id, "wanted"), false))


## Called by a `TutorialTrigger` when the player enters it, and by what gives the player something with a key of its own: `&"inventory"`
## when the first item is picked up, `&"map"` when the trail map is taken.
func trigger(id: StringName) -> void:
	if _lessons.has(id):
		var state: Dictionary = _lessons[id]
		if not state["learned"]:
			state["wanted"] = true
			state["wait"] = lesson_delay
			state["showings"] = 0
			if SaveManager.has_active_game():
				SaveManager.set_state_value(STATE_SECTION, _lesson_key(id, "wanted"), true)

		return

	if id == &"sprint":
		_triggered = true
		# Already walking fast as they arrive: there is nothing to teach.
		if _is_sprinting():
			_mark_learned()
			_hide()


## True while the player is walking fast right now.
func _is_sprinting() -> bool:
	var movement: Node = _player.get("movement_controller") as Node
	if movement == null:
		return false

	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	return bool(movement.get("is_sprinting")) and speed > PlayerMovementController.WALK_SPEED * 1.1


## The close-ups, dialogue, cutscenes and menus own the player's attention.
func _is_gameplay_active() -> bool:
	if get_tree().paused:
		return false

	if bool(_player.get("cutscene_frozen")) or bool(_player.get("dialogue_frozen")):
		return false

	if bool(_player.get("modal_ui_open")) or bool(_player.get("view_locked")):
		return false

	var movement: Node = _player.get("movement_controller") as Node
	if movement != null and bool(movement.get("cutscene_camera_controlled")):
		return false

	var inspect: Object = _player.get("inspect_controller") as Object
	if inspect != null and inspect.has_method("blocks_gameplay") and bool(inspect.call("blocks_gameplay")):
		return false

	# The map in the hands holds the player too (the map's own lesson is learned by opening it).
	if _player.has_method("is_map_holding_player") and bool(_player.call("is_map_holding_player")):
		return false

	var inventory: Object = _player.get("inventory_ui_controller") as Object
	if inventory != null and inventory.has_method("is_inventory_open") and bool(inventory.call("is_inventory_open")):
		return false

	return true


func _show() -> void:
	# Never over someone who is already doing it.
	if _is_sprinting():
		_mark_learned()
		return

	_showings += 1
	_showing_time = 0.0
	is_showing = true
	_refresh_text()
	_fade_to(1.0)


func _give_up_for_now() -> void:
	_hide()
	_walked_distance = 0.0
	if _showings >= max_showings:
		_mark_learned()


func _hide() -> void:
	if not is_showing and _label.modulate.a <= 0.0:
		return

	is_showing = false
	_fade_to(0.0)


func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if alpha > 0.0:
		_label.visible = true

	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", alpha, fade_seconds)
	if alpha <= 0.0:
		_tween.tween_callback(func() -> void: _label.visible = false)


func _mark_learned() -> void:
	_learned = true
	_learned_this_run = true

	if SaveManager.has_active_game():
		SaveManager.set_state_value(STATE_SECTION, KEY_SPRINT_DONE, true)


func _was_learned() -> bool:
	if SaveManager.has_active_game():
		return bool(SaveManager.get_state_value(STATE_SECTION, KEY_SPRINT_DONE, false))

	return _learned_this_run


func _refresh_text() -> void:
	for lesson: Dictionary in LESSONS:
		var label: RichTextLabel = _lessons[lesson["id"]]["label"]
		if label != null:
			label.text = "[center]%s[/center]" % InputBindings.format_text(tr(lesson["text"]), true)

	if _label == null:
		return

	var key: String = (
		"TUTORIAL_SPRINT_TOGGLE"
		if GameSettings.get_sprint_toggle()
		else "TUTORIAL_SPRINT_HOLD"
	)
	_label.text = "[center]%s[/center]" % InputBindings.format_text(tr(key), true)


## Turning the hints back on in the settings teaches everything again, as modern
## games do (and it lets a tester see a hint a second time).
func _on_tutorial_hints_changed(enabled: bool) -> void:
	if not enabled:
		return

	_learned = false
	_learned_this_run = false
	_walked_distance = 0.0
	_showings = 0
	_fast_time = 0.0
	_triggered = false
	_lessons_learned_this_run.clear()

	if SaveManager.has_active_game():
		SaveManager.set_state_value(STATE_SECTION, KEY_SPRINT_DONE, false)

	for lesson: Dictionary in LESSONS:
		var id: StringName = lesson["id"]
		var state: Dictionary = _lessons[id]
		state["learned"] = false
		state["showings"] = 0
		# Only what the player was given is taught again: the map, once they have it; the inventory, once they have picked something up.
		state["wanted"] = _lesson_was_wanted(id)
		state["wait"] = lesson_delay
		if SaveManager.has_active_game():
			SaveManager.set_state_value(STATE_SECTION, _lesson_key(id, "done"), false)


func _on_sprint_toggle_changed(_enabled: bool) -> void:
	_refresh_text()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "TutorialHintLayer"
	_layer.layer = 4
	add_child(_layer)

	_label = _make_hint_label("TutorialHint")
	for lesson: Dictionary in LESSONS:
		_lessons[lesson["id"]] = {
			"label": _make_hint_label("%sHint" % str(lesson["id"]).capitalize()),
			"tween": null,
			"learned": false,
			"wanted": false,
			"wait": 0.0,
			"showing": false,
			"showing_time": 0.0,
			"showings": 0,
		}


## A hint's line of text across the bottom of the screen, hidden until it is shown.
func _make_hint_label(label_name: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.name = label_name
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	label.modulate.a = 0.0
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = -bottom_margin
	label.offset_bottom = -bottom_margin + 44.0
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.theme_type_variation = &"HintText"
	_layer.add_child(label)
	return label
