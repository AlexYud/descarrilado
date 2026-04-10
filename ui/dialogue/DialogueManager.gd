extends Node

signal player_freeze_changed(is_frozen: bool)

const DIALOGUE_BOX_SCENE: PackedScene = preload("res://ui/dialogue/DialogueBox.tscn")

var dialogue_box: DialogueBox
var queue: Array[Dictionary] = []
var showing: bool = false
var ui_ready: bool = false
var current_message_freezes_player: bool = false

func _ready() -> void:
	dialogue_box = DIALOGUE_BOX_SCENE.instantiate()

	# Add it after the current scene setup finishes
	get_tree().root.call_deferred("add_child", dialogue_box)

	# Wait until the DialogueBox actually enters the tree and finishes _ready()
	await dialogue_box.ready

	dialogue_box.finished.connect(_on_dialogue_finished)
	ui_ready = true
	_try_show_next()

func show_timed(text: String, duration: float = 2.0, freeze_player: bool = false) -> void:
	queue.append({
		"type": "timed",
		"text": text,
		"duration": duration,
		"freeze_player": freeze_player
	})
	_try_show_next()

func show_continue(text: String, freeze_player: bool = false) -> void:
	queue.append({
		"type": "continue",
		"text": text,
		"freeze_player": freeze_player
	})
	_try_show_next()

func clear_all() -> void:
	queue.clear()
	showing = false

	if current_message_freezes_player:
		current_message_freezes_player = false
		player_freeze_changed.emit(false)

	if is_instance_valid(dialogue_box) and ui_ready:
		dialogue_box.hide_message()

func _try_show_next() -> void:
	if not ui_ready:
		return

	if showing:
		return

	if queue.is_empty():
		return

	if not is_instance_valid(dialogue_box):
		return

	showing = true
	var item: Dictionary = queue.pop_front()

	var dialog_type: String = item["type"]
	var text: String = item["text"]
	current_message_freezes_player = bool(item.get("freeze_player", false))

	if current_message_freezes_player:
		player_freeze_changed.emit(true)

	if dialog_type == "timed":
		var duration: float = float(item["duration"])
		dialogue_box.show_timed_message(text, duration)
	else:
		dialogue_box.show_continue_message(text)

func _on_dialogue_finished() -> void:
	dialogue_box.hide_message()

	if current_message_freezes_player:
		current_message_freezes_player = false
		player_freeze_changed.emit(false)

	showing = false
	_try_show_next()
