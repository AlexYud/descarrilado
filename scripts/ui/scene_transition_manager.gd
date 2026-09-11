extends Node

signal transition_finished

@export_range(0.0, 3.0, 0.05) var fade_from_black_duration: float = 0.65
@export_range(0.0, 1.0, 0.01) var black_hold_duration: float = 0.08
@export_range(0, 10, 1) var scene_ready_frame_delay: int = 2

var _transition_layer: CanvasLayer = null
var _blackout_rect: ColorRect = null
var _fade_tween: Tween = null
var _reveal_after_next_scene: bool = false
var _transition_token: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_transition_overlay()
	get_tree().scene_changed.connect(_on_scene_changed)


func cover_next_scene() -> void:
	_transition_token += 1
	_reveal_after_next_scene = true
	_kill_fade_tween()

	_blackout_rect.visible = true
	_blackout_rect.modulate.a = 1.0
	_blackout_rect.mouse_filter = Control.MOUSE_FILTER_STOP


func cancel_transition() -> void:
	_transition_token += 1
	_reveal_after_next_scene = false
	_kill_fade_tween()
	_hide_overlay()


func is_cover_visible() -> bool:
	return (
		_blackout_rect != null
		and _blackout_rect.visible
		and _blackout_rect.modulate.a > 0.0
	)


func get_cover_alpha() -> float:
	if _blackout_rect == null or not _blackout_rect.visible:
		return 0.0

	return _blackout_rect.modulate.a


func _create_transition_overlay() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "SceneLoadTransitionLayer"
	_transition_layer.layer = 4096
	_transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_transition_layer)

	_blackout_rect = ColorRect.new()
	_blackout_rect.name = "BlackoutRect"
	_blackout_rect.color = Color.BLACK
	_blackout_rect.modulate.a = 0.0
	_blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_layer.add_child(_blackout_rect)
	_blackout_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_blackout_rect.hide()


func _on_scene_changed() -> void:
	if not _reveal_after_next_scene:
		return

	_reveal_after_next_scene = false
	var token: int = _transition_token
	call_deferred("_reveal_scene_when_ready", token)


func _reveal_scene_when_ready(token: int) -> void:
	for _frame_index: int in range(maxi(scene_ready_frame_delay, 0)):
		await get_tree().process_frame
		if token != _transition_token:
			return

	var hold_duration: float = maxf(black_hold_duration, 0.0)
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration, true).timeout
		if token != _transition_token:
			return

	var fade_duration: float = maxf(fade_from_black_duration, 0.0)
	if fade_duration <= 0.0:
		_finish_reveal(token)
		return

	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(
		_blackout_rect,
		"modulate:a",
		0.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await _fade_tween.finished
	_finish_reveal(token)


func _finish_reveal(token: int) -> void:
	if token != _transition_token:
		return

	_fade_tween = null
	_hide_overlay()
	transition_finished.emit()


func _hide_overlay() -> void:
	if _blackout_rect == null:
		return

	_blackout_rect.modulate.a = 0.0
	_blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout_rect.hide()


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = null
