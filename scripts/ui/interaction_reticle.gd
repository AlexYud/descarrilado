extends Control
class_name InteractionReticle

## The quiet way the game says "this can be used", with nothing else on the screen (the way the horror games with no HUD do it):
##  - near something usable that the player can see, a tiny white ring sits on the thing itself (the thing is not a random asset);
##  - with that, a tiny dot appears in the middle of the screen, which is where the interaction ray goes: put the dot on the thing;
##  - when the ray is on it, the ring becomes a small icon of the kind of use (an eye to inspect, a hand otherwise);
##    the text prompt (`InteractionPromptView`) is shown as before.
## Nothing is shown otherwise. Every mark fades in and out. The marks go through the horror filter's lens (`lens_position`), so they stay
## on what they mark, and are laid over the picture from a 3D position every frame.

## How far (metres) from the eyes a usable thing is marked: just beyond what the ray reaches, so the player is led the last step.
@export var notice_distance: float = 2.2
## Sizes, for a screen 1080 pixels high (scaled with it).
@export var dot_radius: float = 2.2
@export var ring_radius: float = 5.0
@export var icon_radius: float = 13.0
@export var line_width: float = 1.5
@export var fade_speed: float = 7.0

const KIND_HAND: StringName = &"hand"
const KIND_EYE: StringName = &"eye"

var _player: CharacterBody3D = null
var _camera: Camera3D = null
var _controller: PlayerInteractionController = null
var _active: bool = true
## The usable things in sight (updated a few times a second), what is drawn for each (its screen position and how visible it is) and
## the shape its mark is placed on.
var _seen: Array[Interactable] = []
var _marks: Dictionary = {}
var _shapes: Dictionary = {}
var _dot_alpha: float = 0.0
var _scan_timer: float = 0.0
## The doors near (their leaves hide what is behind them, swinging or not).
var _doors: Array[DoorController] = []


func _init() -> void:
	name = "InteractionReticle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(player: CharacterBody3D, camera: Camera3D, controller: PlayerInteractionController) -> void:
	_player = player
	_camera = camera
	_controller = controller


## The marks are off while something else has the player's attention (a dialogue, the inventory).
func set_active(active: bool) -> void:
	_active = active


## The kind of use shown for `item`: an eye to inspect, a hand otherwise.
static func kind_of(item: Interactable) -> StringName:
	if item is Collectible:
		return KIND_HAND
	if item is Inspectable:
		return KIND_EYE
	return KIND_HAND


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera) or _player == null or not is_instance_valid(_player):
		return

	var suppressed: bool = not _active or bool(_player.get("view_locked")) or _inspecting()
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		if suppressed:
			_seen.clear()
		else:
			_seen = _scan()

	var aimed: Interactable = null
	if not suppressed and _controller != null and is_instance_valid(_controller.current_interactable):
		aimed = _controller.current_interactable

	# Every mark moves to where its thing is on the screen, and fades towards 1 (in sight) or 0 (not).
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var wanted: Array[Interactable] = []
	wanted.append_array(_seen)
	if aimed != null and not wanted.has(aimed):
		wanted.append(aimed)
	for item: Interactable in wanted:
		if not is_instance_valid(item):
			continue
		var mark: Dictionary = _marks.get(item, {"alpha": 0.0, "icon": 0.0, "at": Vector2.ZERO})
		var at: Vector3 = _point_of(item)
		# Checked every frame, not only when the things are looked for: a door swings between the eyes and a thing in a moment.
		if _camera.is_position_behind(at) or not _line_clear(item, _camera.global_position, at):
			mark["alpha"] = maxf(float(mark["alpha"]) - delta * fade_speed * 5.0, 0.0)
			mark["icon"] = maxf(float(mark["icon"]) - delta * fade_speed * 5.0, 0.0)
		else:
			mark["at"] = _lens(_camera.unproject_position(at), screen)
			mark["alpha"] = minf(float(mark["alpha"]) + delta * fade_speed, 1.0)
		mark["icon"] = move_toward(float(mark["icon"]), 1.0 if item == aimed else 0.0, delta * fade_speed)
		_marks[item] = mark
	for item: Variant in _marks.keys():
		if not is_instance_valid(item):
			_marks.erase(item)
		elif not wanted.has(item):
			var mark: Dictionary = _marks[item]
			mark["alpha"] = maxf(float(mark["alpha"]) - delta * fade_speed, 0.0)
			mark["icon"] = maxf(float(mark["icon"]) - delta * fade_speed, 0.0)
			if float(mark["alpha"]) <= 0.0 or not is_instance_valid(item):
				_marks.erase(item)
			else:
				_marks[item] = mark

	_dot_alpha = move_toward(_dot_alpha, 1.0 if not wanted.is_empty() else 0.0, delta * fade_speed)
	queue_redraw()


func _draw() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var unit: float = screen.y / 1080.0
	for item: Variant in _marks.keys():
		if not is_instance_valid(item):
			continue
		var mark: Dictionary = _marks[item]
		var alpha: float = float(mark["alpha"])
		var icon: float = float(mark["icon"])
		if alpha <= 0.01:
			continue
		var at: Vector2 = mark["at"]
		_draw_ring(at, ring_radius * unit, alpha * (1.0 - icon) * 0.9, unit)
		if icon > 0.01:
			_draw_icon(kind_of(item as Interactable), at, icon_radius * unit, alpha * icon, unit)

	if _dot_alpha > 0.01:
		var centre: Vector2 = (screen * 0.5).round()
		draw_circle(centre, dot_radius * unit + 1.0 * unit, Color(0.0, 0.0, 0.0, 0.45 * _dot_alpha))
		draw_circle(centre, dot_radius * unit, Color(1.0, 1.0, 1.0, 0.92 * _dot_alpha))


# ---- What is in sight --------------------------------------------------------------------------------------------

## The usable things close enough, in front of the eyes and not behind a wall.
func _scan() -> Array[Interactable]:
	var found: Array[Interactable] = []
	var eye: Vector3 = _camera.global_position
	_doors.clear()
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var knob: DoorKnobInteractable = node as DoorKnobInteractable
		if knob != null and knob.door_controller != null and not _doors.has(knob.door_controller):
			_doors.append(knob.door_controller)
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var item: Interactable = node as Interactable
		if item == null or not item.is_visible_in_tree():
			continue
		var at: Vector3 = _point_of(item)
		if eye.distance_to(at) > notice_distance or _camera.is_position_behind(at) or not _camera.is_position_in_frustum(at):
			continue
		if not item.can_interact(_player) or not _line_clear(item, eye, at):
			continue
		found.append(item)
	return found


## True when the eyes see `at` (a thing's mark point): nothing solid between, no door's leaf (it may be swinging, and solid or not) and,
## for a door's handle, the player on the same face.
func _line_clear(item: Interactable, eye: Vector3, at: Vector3) -> bool:
	if not _on_this_side(item, eye):
		return false
	for door: DoorController in _doors:
		if is_instance_valid(door) and door.door_root != null and _crosses_leaf(door.door_root, eye, at):
			return false
	return _in_the_open(eye, at)


## True when the straight line from `eye` to `at` passes through the door leaf (about 0.9 by 2 metres, centred on `leaf`).
func _crosses_leaf(leaf: Node3D, eye: Vector3, at: Vector3) -> bool:
	var a: Vector3 = leaf.to_local(eye)
	var b: Vector3 = leaf.to_local(at)
	if a.z * b.z >= 0.0 or absf(a.z - b.z) < 0.0001:
		return false
	var along: float = a.z / (a.z - b.z)
	var crossing: Vector3 = a + (b - a) * along
	return absf(crossing.x) < 0.5 and absf(crossing.y) < 1.05


## True when nothing solid stands between the eyes and `at` (only the thing's own surface, a hand's breadth before it, is allowed).
func _in_the_open(eye: Vector3, at: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, at)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(at) < 0.12


## A door's handle is marked only on the face the player is on (the other one is behind the leaf).
func _on_this_side(item: Interactable, eye: Vector3) -> bool:
	var knob: DoorKnobInteractable = item as DoorKnobInteractable
	if knob == null or knob.door_controller == null:
		return true

	var door: DoorController = knob.door_controller
	return door.to_local(knob.global_position).z * door.to_local(eye).z >= 0.0


## Where a thing's mark sits: the middle of its interaction shape, or its own origin.
func _point_of(item: Interactable) -> Vector3:
	var shape: Node3D = _shapes.get(item) as Node3D
	if shape == null or not is_instance_valid(shape):
		shape = null
		for child: Node in item.find_children("*", "CollisionShape3D", true, false):
			shape = child as Node3D
			break
		_shapes[item] = shape if shape != null else item
	return (shape if shape != null else item).global_position


func _inspecting() -> bool:
	var inspect: Variant = _player.get("inspect_controller")
	return inspect != null and bool(inspect.call("is_open"))


## Where the horror filter's lens shows what the camera drew at `point`.
func _lens(point: Vector2, screen: Vector2) -> Vector2:
	var filter: Node = get_node_or_null("/root/HorrorFilter")
	if filter != null and filter.has_method("lens_position"):
		return filter.call("lens_position", point, screen)
	return point


# ---- The marks ---------------------------------------------------------------------------------------------------

func _draw_ring(at: Vector2, radius: float, alpha: float, unit: float) -> void:
	if alpha <= 0.01:
		return
	draw_arc(at + Vector2(1.0, 1.0) * unit, radius, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.4 * alpha), line_width * unit + 1.0)
	draw_arc(at, radius, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, alpha), line_width * unit, true)


## A small icon of the kind of use, in thin white lines with a faint dark shadow (so it reads over the flashlight's bright circle).
func _draw_icon(kind: StringName, at: Vector2, radius: float, alpha: float, unit: float) -> void:
	for pass_index: int in 2:
		var shadow: bool = pass_index == 0
		var colour: Color = Color(0.0, 0.0, 0.0, 0.45 * alpha) if shadow else Color(1.0, 1.0, 1.0, 0.95 * alpha)
		var width: float = line_width * unit + (1.0 if shadow else 0.0)
		var origin: Vector2 = at + (Vector2(1.0, 1.0) * unit if shadow else Vector2.ZERO)
		match kind:
			KIND_EYE:
				_icon_eye(origin, radius, colour, width)
			_:
				_icon_hand(origin, radius, colour, width)


func _icon_eye(c: Vector2, r: float, colour: Color, width: float) -> void:
	var upper: PackedVector2Array = PackedVector2Array()
	var lower: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var t: float = float(i) / 16.0
		var x: float = lerpf(-1.0, 1.0, t) * r * 1.15
		var bulge: float = sin(PI * t) * r * 0.62
		upper.append(c + Vector2(x, -bulge))
		lower.append(c + Vector2(x, bulge))
	draw_polyline(upper, colour, width, true)
	draw_polyline(lower, colour, width, true)
	draw_arc(c, r * 0.34, 0.0, TAU, 20, colour, width, true)
	draw_circle(c, r * 0.12, colour)


## An open hand, a line drawing: four fingers on a palm, and the thumb.
func _icon_hand(c: Vector2, r: float, colour: Color, width: float) -> void:
	var palm: Rect2 = Rect2(c + Vector2(-0.5, -0.05) * r, Vector2(1.0, 0.72) * r)
	draw_rect(palm, colour, false, width)
	for i: int in 4:
		var x: float = -0.5 + 0.25 * float(i) + 0.02
		var top: float = -0.78 + (0.08 if i == 0 or i == 3 else 0.0) - (0.05 if i == 1 else 0.0)
		draw_rect(Rect2(c + Vector2(x, top) * r, Vector2(0.21, -0.05 - top) * r), colour, false, width)
	draw_line(c + Vector2(-0.5, 0.3) * r, c + Vector2(-0.8, 0.02) * r, colour, width, true)
	draw_line(c + Vector2(-0.8, 0.02) * r, c + Vector2(-0.68, -0.12) * r, colour, width, true)
	draw_line(c + Vector2(-0.68, -0.12) * r, c + Vector2(-0.5, 0.06) * r, colour, width, true)
