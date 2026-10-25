extends CanvasLayer
class_name JSLockboxView

## The close-up of the J & S lockbox's combination dial. The view flies to the front panel (a camera of its own, flown from the player's
## eyes, as the overlook payphone does) and an arrow sits above and below each of the four wheels, on the box itself: click one, or scroll
## the mouse wheel over a wheel, to turn it a digit. The keyboard works too: left and right pick a wheel, up and down turn it. Esc, right
## click or the back hint go back. The lockbox decides when the code is right (`JSLockbox`); a moment after it opens the view goes back by
## itself, so that the open box is seen from where the player stands.
##
## Everything the mouse does goes through `turn()`, so tests can drive it. The player is held (`set_modal_ui_open`) while it is up.

const VIEW_LAYER: int = 20
const FLY_SECONDS: float = 0.7
const BACK_SECONDS: float = 0.6
const CLOSE_UP_FOV: float = 40.0
const CLOSE_AFTER_UNLOCK_SECONDS: float = 1.7
## The bottom row, in the same proportions as the inspect view's and the collect prompt's.
const COLUMN_HEIGHT_RATIO: float = 0.56
const BODY_FONT_RATIO: float = 0.0172
const ROW_TOP_RATIO: float = 0.915
## The gap between a wheel and its arrows, in wheel radii.
const ARROW_GAP: float = 0.25

var lockbox: JSLockbox = null

var _player: Node = null
var _player_camera: Camera3D = null
var _camera: Camera3D = null
var _tween: Tween = null
var _open: bool = false
var _flying: bool = false
var _selected: int = 0

var _root: Control = null
var _hint: Label = null
var _back: KeyHint = null
var _up: Array[Arrow] = []
var _down: Array[Arrow] = []


func setup(owner_lockbox: JSLockbox) -> void:
	lockbox = owner_lockbox
	layer = VIEW_LAYER
	visible = false
	_build_ui()

	lockbox.unlocked.connect(_on_unlocked)
	GameSettings.text_language_changed.connect(_on_text_language_changed)


func is_open() -> bool:
	return _open


## True while the camera is on its way (in or out).
func is_flying() -> bool:
	return _flying


func open(player: Node) -> void:
	if _open or _flying:
		return

	_open = true
	_selected = 0
	_player = player
	_player.call("set_modal_ui_open", true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_player_camera = _player.get_node("Head/Camera3D") as Camera3D
	_camera = Camera3D.new()
	_camera.name = "LockboxViewCamera"
	_camera.top_level = true
	lockbox.add_child(_camera)
	_camera.global_transform = _player_camera.global_transform
	_camera.fov = _player_camera.fov
	_camera.near = _player_camera.near
	_camera.far = _player_camera.far
	_camera.cull_mask = _player_camera.cull_mask
	# A little warm light of its own: the dial must be readable whatever the night and the flashlight are doing (the view holds the flashlight).
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = Color(1.0, 0.9, 0.72)
	lamp.light_energy = 0.9
	lamp.omni_range = 1.1
	lamp.shadow_enabled = false
	_camera.add_child(lamp)
	_camera.make_current()

	lockbox.opened.emit()
	_fly_in()


## Goes back to the player's eyes (it waits for the camera to arrive first if it is still on its way in).
func close() -> void:
	if not _open:
		return

	_open = false
	_fade_overlay(false)
	if _flying:
		# Still flying in: it turns round as soon as it gets there.
		await _wait_for_flight()

	await _fly(_player_camera.global_transform, _player_camera.fov, BACK_SECONDS)
	_finish_close()


## Turns wheel `index` one digit up (+1) or down (-1).
func turn(index: int, step: int) -> void:
	lockbox.turn_wheel(index, step)
	_selected = clampi(index, 0, lockbox.code.size() - 1)
	_refresh_arrows()


func _fly_in() -> void:
	await _fly(lockbox.get_close_up_transform(), CLOSE_UP_FOV, FLY_SECONDS)
	if _open:
		_fade_overlay(true)


func _finish_close() -> void:
	if is_instance_valid(_player_camera):
		_player_camera.make_current()

	if is_instance_valid(_camera):
		_camera.queue_free()

	_camera = null
	if is_instance_valid(_player):
		_player.call("set_modal_ui_open", false)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	visible = false
	lockbox.closed.emit()


## Flies the view camera to `target`. Await it.
func _fly(target: Transform3D, fov: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_flying = true
	var start: Transform3D = _camera.global_transform
	var start_fov: float = _camera.fov
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(
		func(t: float) -> void:
			if is_instance_valid(_camera):
				_camera.global_transform = start.interpolate_with(target, t)
				_camera.fov = lerpf(start_fov, fov, t),
		0.0, 1.0, seconds
	)
	await _tween.finished
	_flying = false


func _wait_for_flight() -> void:
	while _flying:
		await get_tree().process_frame


func _exit_tree() -> void:
	# The lockbox went (the scene was left) with the view up: give the player their eyes and their hands back.
	if _open or _flying:
		_open = false
		if is_instance_valid(_player_camera):
			_player_camera.make_current()

		if is_instance_valid(_player):
			_player.call("set_modal_ui_open", false)


func _on_unlocked() -> void:
	_refresh_arrows()
	if not _open:
		return

	await get_tree().create_timer(CLOSE_AFTER_UNLOCK_SECONDS).timeout
	if _open:
		close()


func _on_text_language_changed(_locale: String) -> void:
	_apply_texts()


# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:
	if not _open:
		return

	var closes: bool = event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		closes = true

	if closes:
		close()
		get_viewport().set_input_as_handled()
		return

	if _flying or lockbox.is_unlocked:
		return

	# Scrolling over a wheel turns it.
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var wheel: int = wheel_at(event.position)
		if wheel >= 0:
			turn(wheel, 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()

		return

	if event.is_action_pressed("ui_left"):
		_selected = posmod(_selected - 1, lockbox.code.size())
		_refresh_arrows()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_selected = posmod(_selected + 1, lockbox.code.size())
		_refresh_arrows()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		turn(_selected, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		turn(_selected, -1)
		get_viewport().set_input_as_handled()


## The wheel whose column (its arrows and what is between them) holds the screen point, or -1.
func wheel_at(point: Vector2) -> int:
	for i: int in _up.size():
		var top: Rect2 = Rect2(_up[i].position, _up[i].size)
		var bottom: Rect2 = Rect2(_down[i].position, _down[i].size)
		var column: Rect2 = top.merge(bottom)
		if column.has_point(point):
			return i

	return -1


# ============================================================
# THE OVERLAY
# ============================================================

func _process(_delta: float) -> void:
	if _open and visible:
		_layout_arrows()


## Puts the arrows above and below each wheel as the camera sees it (it moves while it flies in and out), and as the picture filter's lens shows it
## (the filter bends the picture a little toward its corners, under this layer).
func _layout_arrows() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return

	for i: int in _up.size():
		var middle: Vector3 = lockbox.get_wheel_position(i)
		if _camera.is_position_behind(middle):
			_up[i].visible = false
			_down[i].visible = false
			continue

		var centre: Vector2 = _through_the_lens(_camera.unproject_position(middle))
		var above: Vector2 = _through_the_lens(_camera.unproject_position(middle + _camera.global_basis.y * 0.02))
		var pixels_per_metre: float = absf(above.y - centre.y) / 0.02
		var radius: float = lockbox.get_wheel_radius() * pixels_per_metre
		var arrow_size: Vector2 = Vector2(maxf(radius * 1.8, 34.0), maxf(radius * 0.85, 20.0)).max(_up[i].get_combined_minimum_size())
		var gap: float = radius * ARROW_GAP
		_up[i].size = arrow_size
		_up[i].position = Vector2(centre.x - arrow_size.x * 0.5, centre.y - radius - gap - arrow_size.y)
		_down[i].size = arrow_size
		_down[i].position = Vector2(centre.x - arrow_size.x * 0.5, centre.y + radius + gap)
		_up[i].visible = true
		_down[i].visible = true

	_layout_row()


## Where the picture filter's lens shows what the camera drew at a screen point (the point itself when there is no filter).
func _through_the_lens(point: Vector2) -> Vector2:
	var filter: Node = get_node_or_null("/root/HorrorFilter")
	if filter == null or not filter.has_method("lens_position"):
		return point

	return filter.call("lens_position", point, get_viewport().get_visible_rect().size)


func _fade_overlay(show_it: bool) -> void:
	if show_it:
		visible = true
		_root.modulate.a = 0.0
		create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
		_refresh_arrows()
	else:
		var tween: Tween = create_tween()
		tween.tween_property(_root, "modulate:a", 0.0, 0.2)


func _refresh_arrows() -> void:
	for i: int in _up.size():
		var chosen: bool = i == _selected
		_up[i].selected = chosen
		_down[i].selected = chosen
		var locked: bool = lockbox.is_unlocked
		_up[i].disabled = locked
		_down[i].disabled = locked
		_up[i].queue_redraw()
		_down[i].queue_redraw()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	for i: int in lockbox.code.size():
		var up: Arrow = Arrow.new()
		up.pointing_up = true
		up.pressed.connect(turn.bind(i, 1))
		_root.add_child(up)
		_up.append(up)

		var down: Arrow = Arrow.new()
		down.pointing_up = false
		down.pressed.connect(turn.bind(i, -1))
		_root.add_child(down)
		_down.append(down)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.theme_type_variation = &"HintLabel"
	_root.add_child(_hint)

	_back = KeyHint.new()
	_back.name = "Back"
	_back.pressed.connect(close)
	_root.add_child(_back)

	_apply_texts()


func _apply_texts() -> void:
	if _hint == null:
		return

	_hint.text = tr("LOCKBOX_VIEW_HINT")
	_layout_row()


## The bottom row: what to do at the left, the way back at the right, in the style of the inspect view's.
func _layout_row() -> void:
	if _hint == null or not is_inside_tree():
		return

	var screen: Vector2 = get_viewport().get_visible_rect().size
	screen = Vector2(maxf(screen.x, 320.0), maxf(screen.y, 240.0))
	var column: float = minf(screen.x * 0.94, screen.y * COLUMN_HEIGHT_RATIO)
	var left: float = (screen.x - column) * 0.5
	var scale_setting: float = float(GameSettings.get_caption_font_size()) / float(GameSettings.CAPTION_FONT_SIZES[GameSettings.DEFAULT_CAPTION_SIZE])
	var body: int = maxi(int(round(screen.y * BODY_FONT_RATIO * scale_setting)), 13)
	var row_top: float = screen.y * ROW_TOP_RATIO
	var font: Font = UIConfig.font(UIConfig.weight_body, UIConfig.spacing_body)

	_back.set_hint(tr("KEY_NAME_ESCAPE"), tr("INSPECT_BACK"), body, font)
	_back.position = Vector2(left + column - _back.size.x, row_top)
	_hint.add_theme_font_size_override("font_size", body)
	_hint.position = Vector2(left, row_top)
	_hint.size = Vector2(maxf(column - _back.size.x - 28.0, 40.0), _back.size.y)


## A squared button with a triangle (no font needs an arrow glyph): bright when it is the chosen wheel's or under the mouse.
class Arrow extends Button:
	var pointing_up: bool = true
	var selected: bool = false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(34.0, 20.0)
		flat = true
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var bright: bool = (is_hovered() or selected) and not disabled
		var edge: Color = Color(UIConfig.color_bright, 1.0 if bright else 0.55)
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(rect, UIConfig.panel_color(0.88 if bright else 0.7))
		draw_rect(rect.grow(-1.0), edge, false, 2.0)
		var middle: float = size.x * 0.5
		var top: float = size.y * 0.3
		var bottom: float = size.y * 0.7
		var reach: float = minf(size.x * 0.22, 14.0)
		var points: PackedVector2Array
		if pointing_up:
			points = PackedVector2Array([Vector2(middle, top), Vector2(middle + reach, bottom), Vector2(middle - reach, bottom)])
		else:
			points = PackedVector2Array([Vector2(middle, bottom), Vector2(middle + reach, top), Vector2(middle - reach, top)])

		draw_colored_polygon(points, Color(UIConfig.color_bright, 1.0 if bright else 0.7))
