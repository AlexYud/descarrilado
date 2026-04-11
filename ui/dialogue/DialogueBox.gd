extends CanvasLayer
class_name DialogueBox

signal finished

@onready var root: Control = $Root
@onready var message_label: Label = $Root/BottomMargin/Panel/VBox/MessageLabel
@onready var hint_label: Label = $Root/BottomMargin/Panel/VBox/HintLabel
@onready var hide_timer: Timer = $HideTimer

var waiting_for_input: bool = false

func _ready() -> void:
	root.visible = false
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)

func show_timed_message(text: String, duration: float) -> void:
	waiting_for_input = false
	message_label.text = text
	hint_label.text = ""
	root.visible = true
	hide_timer.start(duration)

func show_continue_message(text: String) -> void:
	waiting_for_input = true
	hide_timer.stop()
	message_label.text = text
	hint_label.text = "Press Enter or click to continue"
	root.visible = true

func hide_message() -> void:
	waiting_for_input = false
	hide_timer.stop()
	root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not root.visible:
		return

	if not waiting_for_input:
		return

	if event.is_action_pressed("dialog_continue"):
		get_viewport().set_input_as_handled()
		finished.emit()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			finished.emit()

func _on_hide_timer_timeout() -> void:
	finished.emit()
