extends Node
class_name InspectReaction

## Plays a caption line when the player examines a named object, or turns it
## over to see its back.
##
## The object's Visual node carries the metadata the inspect controller reads
## (`inspect_id`, and `inspect_back_normal` for objects with a back). Place this
## node in the level, not under a collectible: a collectible frees itself when
## picked up, and its reactions must keep working from the inventory.
##
## Lines are caption keys, shown through CaptionManager.

## Matches the `inspect_id` metadata on the object's Visual node.
@export var inspect_id: StringName = &""

## Said `open_line_delay` seconds after the object settles in view. Closing the
## view first cancels it, so the delay doubles as "after studying it a while".
@export var open_line: String = ""
@export var open_line_delay: float = 0.6

## Said `back_line_delay` seconds after the player turns it over.
@export var back_line: String = ""
@export var back_line_delay: float = 0.4

## Say each line only the first time, and remember it across saves when a
## `persistent_id` is given.
@export var once: bool = true
@export var persistent_id: StringName = &""

var _inspect_controller: PlayerInspectController = null
var _open_done: bool = false
var _back_done: bool = false
var _requests: Dictionary = {"open": 0, "back": 0}


func _ready() -> void:
	if once and not persistent_id.is_empty():
		_open_done = _was_saved("open")
		_back_done = _was_saved("back")

	_connect_to_player.call_deferred()


func _connect_to_player() -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		# The player may not have entered the tree yet; try once more.
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group(&"player")

	if player == null:
		push_warning("InspectReaction '%s': no player found." % name)
		return

	_inspect_controller = player.get("inspect_controller") as PlayerInspectController
	if _inspect_controller == null:
		return

	_inspect_controller.inspect_opened.connect(_on_inspect_opened)
	_inspect_controller.inspect_closed.connect(_on_inspect_closed)
	_inspect_controller.back_revealed.connect(_on_back_revealed)


func _on_inspect_opened(opened_id: String) -> void:
	if StringName(opened_id) != inspect_id or open_line.is_empty():
		return

	if once and _open_done:
		return

	_say_after(open_line, open_line_delay, "open")


func _on_inspect_closed(closed_id: String) -> void:
	if StringName(closed_id) == inspect_id:
		_cancel_pending()


func _on_back_revealed(revealed_id: String) -> void:
	if StringName(revealed_id) != inspect_id or back_line.is_empty():
		return

	if once and _back_done:
		return

	_say_after(back_line, back_line_delay, "back")


func _say_after(line: String, delay: float, which: String) -> void:
	_requests[which] = int(_requests[which]) + 1
	var request: int = int(_requests[which])

	await get_tree().create_timer(delay).timeout
	if request != int(_requests[which]):
		return

	if which == "open":
		_open_done = true
	else:
		_back_done = true

	if not persistent_id.is_empty():
		SaveManager.set_state_value(&"triggers", _save_key(which), true)

	CaptionManager.say(line)


func _save_key(which: String) -> StringName:
	return StringName("%s_%s" % [persistent_id, which])


func _was_saved(which: String) -> bool:
	return bool(SaveManager.get_state_value(
		&"triggers",
		_save_key(which),
		false
	))


## Closing the view cancels any line still waiting for its delay.
func _cancel_pending() -> void:
	for which: String in _requests:
		_requests[which] = int(_requests[which]) + 1
