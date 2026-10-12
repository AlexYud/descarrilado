extends Node
class_name TutorialHintController

## Teaches the player that they can walk faster, the way modern games teach a
## control: a short, non-blocking hint at the bottom of the screen, shown when it
## is relevant and not before.
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
## - Players who find the faster pace before the hint appears never see it.
## - It is remembered per saved game, and can be turned off in the Controls
##   settings ("Tutorial hints").

const STATE_SECTION: StringName = &"tutorials"
## (The earlier key `sprint_done` is not read: it was set by an older trigger design,
## and by testers who had already walked fast.)
const KEY_SPRINT_DONE: StringName = &"sprint_hint_done"

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

## Without an active saved game (a test, a playtest scene) the lesson is only
## remembered for this run.
static var _learned_this_run: bool = false

var is_showing: bool = false

var _player: CharacterBody3D = null
var _layer: CanvasLayer = null
var _label: RichTextLabel = null
var _tween: Tween = null

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

	InputBindings.bindings_changed.connect(_refresh_text)
	GameSettings.sprint_toggle_changed.connect(_on_sprint_toggle_changed)
	GameSettings.tutorial_hints_changed.connect(_on_tutorial_hints_changed)


func _process(delta: float) -> void:
	if _player == null:
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
	# it only counts while the hint is on screen: whoever walked fast about the yard
	# still gets the hint at the gate, and it goes away as soon as they do it again.
	var may_learn: bool = is_showing or not _needs_trigger
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


## Called by a `TutorialTrigger` when the player enters it.
func trigger(id: StringName) -> void:
	if id == &"sprint":
		_triggered = true


## The close-ups, dialogue, cutscenes and menus own the player's attention.
func _is_gameplay_active() -> bool:
	if get_tree().paused:
		return false

	if bool(_player.get("cutscene_frozen")) or bool(_player.get("dialogue_frozen")):
		return false

	if bool(_player.get("modal_ui_open")):
		return false

	var movement: Node = _player.get("movement_controller") as Node
	if movement != null and bool(movement.get("cutscene_camera_controlled")):
		return false

	var inspect: Object = _player.get("inspect_controller") as Object
	if inspect != null and inspect.has_method("is_open") and bool(inspect.call("is_open")):
		return false

	var inventory: Object = _player.get("inventory_ui_controller") as Object
	if inventory != null and inventory.has_method("is_inventory_open") and bool(inventory.call("is_inventory_open")):
		return false

	return true


func _show() -> void:
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

	if SaveManager.has_active_game():
		SaveManager.set_state_value(STATE_SECTION, KEY_SPRINT_DONE, false)


func _on_sprint_toggle_changed(_enabled: bool) -> void:
	_refresh_text()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "TutorialHintLayer"
	_layer.layer = 4
	add_child(_layer)

	_label = RichTextLabel.new()
	_label.name = "TutorialHint"
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	_label.modulate.a = 0.0
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 0.0
	_label.offset_right = 0.0
	_label.offset_top = -bottom_margin
	_label.offset_bottom = -bottom_margin + 44.0
	_label.add_theme_font_size_override("normal_font_size", font_size)
	_label.add_theme_color_override("default_color", Color(0.92, 0.92, 0.88, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_layer.add_child(_label)
