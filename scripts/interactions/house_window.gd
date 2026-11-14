extends Interactable
class_name HouseWindow

## A window of the unfinished house with its pair of plank shutters (`unfinished_house_window_door.glb`, one leaf of the pair each), which the player opens and
## closes by looking at the window and pressing the interact key, like a door. The shutters hang on the two sides of the opening, outside, and swing outward:
## open they lie back against the wall; shut they close over the window and meet in the middle.
##
## The motion is not mechanical: the two leaves never move together (the second follows a moment later, a little slower), each one hangs on a hinge that holds
## for an instant before it gives and then swings on an eased curve; open, the leaf runs up to its stop and rebounds a few degrees; shut, it knocks against the
## frame, bounces a little and settles. It makes no sound. The opening is solid (see `_build_area`), and so is each leaf while it is at rest (open or shut: nobody
## walks through an open shutter outside); a leaf on its way has no collision, so it never shoves the player. The interaction mark sits on the face of the window
## the player is looking from.
##
## The state is saved when `persistent_id` is set (section `windows`). It starts open: the windows of the house are unfinished, with no glass, and the moonlight
## comes in as it always did until someone closes them.
##
## Frame: the window's origin is the middle of the opening on the wall's centre line, +X along the wall, +Y up and +Z towards the OUTSIDE.

signal opened
signal closed

const LEAF_MODEL: PackedScene = preload("res://assets/models/buildings/unfinished_house/parts/window_door/unfinished_house_window_door.glb")
## The leaf's size in its own file (x its thickness, y its height, z its width).
const LEAF_FILE_SIZE: Vector3 = Vector3(0.0349, 1.1046, 0.5495)
const STATE_SECTION: StringName = &"windows"

@export var persistent_id: StringName = &""
@export var starts_open: bool = true
## The opening's width and height (metres): the two leaves cover it together.
@export var opening_width: float = 1.33
@export var opening_height: float = 1.1
## How far outside the wall's centre line the leaves hang (the middle of the leaf), and the gap left between them in the middle when shut (so that their stiles
## never cut into each other).
@export var plane_offset: float = 0.17
@export var middle_gap: float = 0.008
## Where the room's face of the wall is (negative: inside), a little into the room so that the window, not the wall, is what a ray from inside meets.
@export var inner_face: float = -0.15
@export var open_angle_degrees: float = 100.0
## Seconds of a swing; each leaf varies a little around it, every time.
@export var open_seconds: float = 1.05
@export var close_seconds: float = 0.85

var is_open: bool = false

var _hinges: Array[Node3D] = []
var _busy: bool = false
var _tweens: Array[Tween] = []
var _leaf_shapes: Array[CollisionShape3D] = []
var _window_shape: CollisionShape3D = null
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	# The window's own body first: the interaction mark sits on the first collision shape of a thing.
	_build_area()
	_build_leaves()

	is_open = starts_open
	if not persistent_id.is_empty() and SaveManager.has_active_game():
		var saved: Variant = SaveManager.get_state_value(STATE_SECTION, persistent_id, {})
		if saved is Dictionary and not (saved as Dictionary).is_empty():
			is_open = bool((saved as Dictionary).get("is_open", is_open))
	_set_angles(1.0 if is_open else 0.0, 0.0)


## The mark on the face the player looks from: on the room's face from inside, on the shutters' face from outside (the window's body is in the way otherwise).
func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if camera == null or _window_shape == null:
		return

	var inside: bool = to_local(camera.global_position).z < 0.0
	var centre: float = _window_shape.position.z
	var outer: float = plane_offset + 0.04
	mark_offset = Vector3(0.0, 0.0, (inner_face - centre - 0.01) if inside else (outer - centre + 0.01))


func can_interact(_player: Node) -> bool:
	return not _busy


func get_prompt_text() -> String:
	return "PROMPT_CLOSE" if is_open else "PROMPT_OPEN"


func interact(_player: Node) -> void:
	if _busy:
		return

	if is_open:
		close()
	else:
		open()


## Opens the window, with its motion. Await it.
func open() -> void:
	if is_open or _busy:
		return

	is_open = true
	_remember()
	await _swing(true)
	opened.emit()


## Shuts the window, with its motion. Await it.
func close() -> void:
	if not is_open or _busy:
		return

	is_open = false
	_remember()
	await _swing(false)
	closed.emit()


## Both leaves at once, with no motion (a script, a test).
func set_open_now(open_now: bool) -> void:
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_busy = false
	is_open = open_now
	_set_leaves_solid(true)
	_set_angles(1.0 if open_now else 0.0, 0.0)
	_remember()


## How far each leaf is open, 0 shut to 1 wide open (for the tests).
func leaf_openness() -> Array[float]:
	var found: Array[float] = []
	for hinge: Node3D in _hinges:
		found.append(absf(hinge.rotation_degrees.y) / open_angle_degrees)
	return found


# ============================================================
# BUILDING
# ============================================================

func _build_leaves() -> void:
	var leaf_width: float = opening_width * 0.5 - middle_gap * 0.5
	var width_scale: float = leaf_width / LEAF_FILE_SIZE.z
	for side: int in [-1, 1]:
		# Hinge on the opening's side `side` (-1 west, +1 east); the leaf runs from it towards the middle.
		var hinge: Node3D = Node3D.new()
		hinge.name = "HingeWest" if side < 0 else "HingeEast"
		hinge.position = Vector3(float(side) * opening_width * 0.5, 0.0, plane_offset)
		add_child(hinge)
		_hinges.append(hinge)

		var leaf: Node3D = Node3D.new()
		leaf.name = "Leaf"
		leaf.position = Vector3(-float(side) * leaf_width * 0.5, 0.0, 0.0)
		# The leaf's width is its file z, its thickness its file x: a quarter turn about Y puts the width along the wall.
		leaf.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		hinge.add_child(leaf)

		var model: Node3D = LEAF_MODEL.instantiate() as Node3D
		model.scale = Vector3(1.0, opening_height / LEAF_FILE_SIZE.y, width_scale)
		leaf.add_child(model)

		# Solid at rest (see `_set_leaves_solid`), in the leaf's own axes: its thickness along x, its width along z.
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "LeafBody"
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(LEAF_FILE_SIZE.x + 0.01, opening_height, leaf_width)
		shape.shape = box
		body.add_child(shape)
		leaf.add_child(body)
		_leaf_shapes.append(shape)


## The window is solid: a body fills the opening through the wall's thickness, from just inside the room's face of the wall (`inner_face`) to just outside the
## shutters. Nothing walks or falls through it, and it is also what the interaction ray and the flashlight's aim meet, at the wall's own face, as they meet a wall
## (an interaction volume reaching into the room made the flashlight aim at a point in the air and swing aside when close).
func _build_area() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "WindowBody"
	# It keeps the player out of the opening, not the night's sound (the shutters, when shut, do that).
	body.add_to_group(OutdoorAmbience.SOUND_TRANSPARENT_GROUP)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box: BoxShape3D = BoxShape3D.new()
	var outer: float = plane_offset + 0.04
	box.size = Vector3(opening_width, opening_height, outer - inner_face)
	shape.shape = box
	shape.position = Vector3(0.0, 0.0, (outer + inner_face) * 0.5)
	body.add_child(shape)
	add_child(body)
	_window_shape = shape


## The leaves block the way at rest and let it be while they move.
func _set_leaves_solid(solid: bool) -> void:
	for shape: CollisionShape3D in _leaf_shapes:
		shape.set_deferred("disabled", not solid)


# ============================================================
# MOTION
# ============================================================

## Sets the leaves at `amount` (0 shut to 1 open), `extra` degrees past it (a rebound).
func _set_angles(amount: float, extra: float) -> void:
	for i: int in _hinges.size():
		_apply(i, amount, extra)


## The west hinge turns the other way from the east one: both leaves swing out to +Z.
func _apply(index: int, amount: float, extra: float) -> void:
	var sign_of_turn: float = -1.0 if index == 0 else 1.0
	_hinges[index].rotation_degrees.y = sign_of_turn * (open_angle_degrees * amount + extra)


func _swing(opening: bool) -> void:
	_busy = true
	_set_leaves_solid(false)
	_tweens.clear()
	var finished: Array[bool] = [false, false]
	var first: int = 0 if _random.randf() < 0.5 else 1
	for turn: int in 2:
		var index: int = first if turn == 0 else 1 - first
		var delay: float = 0.0 if turn == 0 else _random.randf_range(0.06, 0.16)
		var seconds: float = (open_seconds if opening else close_seconds) * _random.randf_range(0.9, 1.12) * (1.0 if turn == 0 else 1.1)
		_play_leaf(index, opening, delay, seconds, finished)

	while not (finished[0] and finished[1]):
		await get_tree().process_frame
	_set_leaves_solid(true)
	_busy = false


func _play_leaf(index: int, opening: bool, delay: float, seconds: float, finished: Array[bool]) -> void:
	var from: float = 0.0 if opening else 1.0
	var to: float = 1.0 if opening else 0.0
	var tween: Tween = create_tween()
	_tweens.append(tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	# The hinge holds for an instant, then gives (the first few degrees come slowly), and the leaf is carried on an eased curve.
	tween.tween_method(
		func(p: float) -> void:
			var eased: float = _swing_curve(p, opening)
			_apply(index, lerpf(from, to, eased), 0.0),
		0.0, 1.0, seconds
	)
	# What happens at the stop: open, it runs up to the stop and rebounds a few degrees; shut, it knocks against the frame, bounces open a little and shuts again.
	var rebound: float = _random.randf_range(3.0, 5.0)
	if opening:
		tween.tween_method(func(p: float) -> void: _apply(index, 1.0, -rebound * sin(p * PI) * (1.0 - p * 0.4)), 0.0, 1.0, 0.32)
	else:
		tween.tween_method(func(p: float) -> void: _apply(index, 0.0, rebound * 0.7 * sin(p * PI) * (1.0 - p * 0.5)), 0.0, 1.0, 0.26)
	tween.tween_callback(func() -> void: finished[index] = true)


## 0 to 1 over a swing: a slow start (the hinge holds), a fast middle and a soft arrival when opening; shutting accelerates into the frame and arrives quickly.
func _swing_curve(p: float, opening: bool) -> float:
	var held: float = smoothstep(0.0, 0.16, p) * 0.06
	if opening:
		return clampf(held + (1.0 - 0.06) * smoothstep(0.0, 1.0, pow(p, 0.9)), 0.0, 1.0)
	return clampf(held + (1.0 - 0.06) * pow(p, 1.7), 0.0, 1.0)


func _remember() -> void:
	if persistent_id.is_empty() or not SaveManager.has_active_game():
		return

	SaveManager.set_state_value(STATE_SECTION, persistent_id, {"is_open": is_open})
