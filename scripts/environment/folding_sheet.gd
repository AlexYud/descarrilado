@tool
extends Node3D
class_name FoldingSheet

## A sheet of paper that folds the way a road map does: in half across its middle, then in half again down its
## middle, until it is a small block a quarter of its size. It is four panels, each hinged on the one before it:
##
##   the bottom left panel is the base and never moves;
##   the top left panel is hinged to it, along the horizontal crease, and folds over it first;
##   the bottom right panel is hinged along the vertical crease and folds over the left side after that;
##   the top right panel is hinged to the bottom right one and goes with it (it has folded over it already).
##
## `closedness` says how far it is folded: 0 is the sheet laid flat, 0.5 is folded once, 1 is folded small. Closing goes
## across first and then down; opening is the same in reverse (the last fold is the first to open). The creases are the
## middle lines of the sheet, so a picture printed on it (`front_texture`, cut into the four quarters) folds along its own
## creases. Anything written on it (a Label3D) is hung on the panel it sits on with `attach()`, and folds with it.
##
## Built in code. A copy of a built sheet (the inspect view duplicates the item) already has its panels and is only
## looked over again. Nothing is lost when the sheet is folded: `fold_to()` moves it a little and does not touch what is
## printed. The inspect view (`PlayerInspectController`) folds and opens it through `set_closed`, `close_over`, `open_out`.

const COVER_NAME: StringName = &"Cover"

@export var sheet_size: Vector2 = Vector2(0.7, 0.56)
@export var thickness: float = 0.002
@export var paper_color: Color = Color(0.74, 0.65, 0.46)
@export var front_texture: Texture2D = null

## 0 is flat, 1 is folded small. Assigning it poses the sheet at once; `close_over` and `open_out` take time.
var closedness: float = 0.0:
	set(value):
		closedness = clampf(value, 0.0, 1.0)
		_pose()

## How far the top half is bent forward over the horizontal crease, in radians, while the sheet lies open: a paper whose top
## has been peeled off a board droops like this. It is only for a sheet that is not folded (a folded one ignores it).
var curl: float = 0.0:
	set(value):
		curl = value
		_pose()

var _pivot: Node3D = null
var _panels: Dictionary = {}
var _hinge_left: Node3D = null
var _hinge_right: Node3D = null
var _hinge_side: Node3D = null

var _moving: bool = false
var _from: float = 0.0
var _to: float = 0.0
var _elapsed: float = 0.0
var _duration: float = 0.0


func _ready() -> void:
	set_process(false)
	if get_child_count() == 0:
		build()
	else:
		_collect()

	_pose()


func _process(delta: float) -> void:
	if not _moving:
		set_process(false)
		return

	_elapsed += delta
	var progress: float = 1.0 if _duration <= 0.0 else clampf(_elapsed / _duration, 0.0, 1.0)
	closedness = lerpf(_from, _to, progress)
	if progress >= 1.0:
		_moving = false
		set_process(false)


# ============================================================
# FOLDING (the inspect view calls these three)
# ============================================================

## Folds (or opens) the sheet at once.
func set_closed(closed: bool) -> void:
	_moving = false
	closedness = 1.0 if closed else 0.0


## Folds it small over `seconds` (the time a full fold takes; less if it is part folded). Returns how long it will take.
func close_over(seconds: float) -> float:
	return _move_to(1.0, seconds)


## Opens it out flat over `seconds`. Returns how long it will take.
func open_out(seconds: float) -> float:
	return _move_to(0.0, seconds)


func is_moving() -> bool:
	return _moving


func _move_to(target: float, seconds: float) -> float:
	var duration: float = seconds * absf(target - closedness)
	if duration <= 0.0:
		_moving = false
		closedness = target
		return 0.0

	_from = closedness
	_to = target
	_elapsed = 0.0
	_duration = duration
	_moving = true
	set_process(true)
	return duration


# ============================================================
# BUILDING
# ============================================================

## The size of one panel, a half of the sheet each way.
func panel_size() -> Vector2:
	return sheet_size * 0.5


## The panel a point of the sheet is on, as a name: points are in the sheet's frame (x right, y up, the middle at the
## origin).
func panel_at(point: Vector2) -> StringName:
	var right: bool = point.x >= 0.0
	var top: bool = point.y >= 0.0
	if top:
		return &"TopRight" if right else &"TopLeft"

	return &"BottomRight" if right else &"BottomLeft"


## Where a panel's middle is, in the sheet's frame.
func panel_center(panel_name: StringName) -> Vector2:
	var quarter: Vector2 = sheet_size * 0.25
	var x: float = quarter.x if String(panel_name).ends_with("Right") else -quarter.x
	var y: float = quarter.y if String(panel_name).begins_with("Top") else -quarter.y
	return Vector2(x, y)


func get_panel(panel_name: StringName) -> Node3D:
	return _panels.get(panel_name) as Node3D


## Hangs `node` on the panel that the point `at` (the sheet's frame) lies on, so that it stays there when the sheet is
## folded; `lift` is how far above the paper's face it floats. Only the position is set; the node's own rotation stays.
## `on_back` hangs it on the back of the panel instead (facing -Z, so that it faces up once the panel is folded over).
func attach(node: Node3D, at: Vector2, lift: float = 0.0004, on_back: bool = false) -> void:
	var panel_name: StringName = panel_at(at)
	var panel: Node3D = get_panel(panel_name)
	if panel == null:
		push_warning("FoldingSheet: no panel for '%s' (build the sheet first)." % panel_name)
		return

	var local: Vector2 = at - panel_center(panel_name)
	var side: float = -1.0 if on_back else 1.0
	node.position = Vector3(local.x, local.y, side * (thickness * 0.5 + lift))
	if on_back:
		node.rotation_degrees.y = 180.0

	panel.add_child(node)


func build() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	var quarter: Vector2 = sheet_size * 0.25
	var hinge_lift: float = thickness
	var side_lift: float = thickness * 3.0

	# The base, and the top left panel on its hinge along the horizontal crease.
	var bottom_left: Node3D = _make_panel(&"BottomLeft", 0, 1)
	bottom_left.position = Vector3(-quarter.x, -quarter.y, 0.0)
	_pivot.add_child(bottom_left)
	_hinge_left = _make_hinge("HingeTopLeft", Vector3(0.0, quarter.y, hinge_lift))
	bottom_left.add_child(_hinge_left)
	var top_left: Node3D = _make_panel(&"TopLeft", 0, 0)
	top_left.position = Vector3(0.0, quarter.y, -hinge_lift)
	_hinge_left.add_child(top_left)

	# The right side, on its hinge along the vertical crease; its top panel hangs from the bottom one the same way.
	_hinge_side = _make_hinge("HingeSide", Vector3(0.0, 0.0, side_lift))
	_pivot.add_child(_hinge_side)
	var bottom_right: Node3D = _make_panel(&"BottomRight", 1, 1)
	bottom_right.position = Vector3(quarter.x, -quarter.y, -side_lift)
	_hinge_side.add_child(bottom_right)
	_hinge_right = _make_hinge("HingeTopRight", Vector3(0.0, quarter.y, hinge_lift))
	bottom_right.add_child(_hinge_right)
	var top_right: Node3D = _make_panel(&"TopRight", 1, 0)
	top_right.position = Vector3(0.0, quarter.y, -hinge_lift)
	_hinge_right.add_child(top_right)


## `column` 0 is left and 1 right; `row` 0 is top and 1 bottom: which quarter of the picture the panel carries.
func _make_panel(panel_name: StringName, column: int, row: int) -> Node3D:
	var panel: Node3D = Node3D.new()
	panel.name = String(panel_name)
	_panels[panel_name] = panel

	var size: Vector2 = panel_size()
	var slab_mesh: BoxMesh = BoxMesh.new()
	slab_mesh.size = Vector3(size.x, size.y, thickness)
	var slab_material: StandardMaterial3D = StandardMaterial3D.new()
	slab_material.albedo_color = paper_color
	slab_material.roughness = 0.97
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.name = "Slab"
	slab.mesh = slab_mesh
	slab.material_override = slab_material
	panel.add_child(slab)

	if front_texture != null:
		var print_material: StandardMaterial3D = StandardMaterial3D.new()
		print_material.albedo_texture = front_texture
		print_material.roughness = 0.96
		print_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		print_material.uv1_scale = Vector3(0.5, 0.5, 1.0)
		print_material.uv1_offset = Vector3(0.5 * float(column), 0.5 * float(row), 0.0)
		var quad: QuadMesh = QuadMesh.new()
		quad.size = size
		var front_print: MeshInstance3D = MeshInstance3D.new()
		front_print.name = "Print"
		front_print.mesh = quad
		front_print.material_override = print_material
		front_print.position = Vector3(0.0, 0.0, thickness * 0.5 + 0.0002)
		panel.add_child(front_print)

	return panel


func _make_hinge(hinge_name: String, at: Vector3) -> Node3D:
	var hinge: Node3D = Node3D.new()
	hinge.name = hinge_name
	hinge.position = at
	return hinge


## A duplicate of a built sheet: the parts are found again by name.
func _collect() -> void:
	_pivot = get_node_or_null("Pivot") as Node3D
	for panel_name: StringName in [&"BottomLeft", &"TopLeft", &"BottomRight", &"TopRight"]:
		var found: Array[Node] = find_children(String(panel_name), "Node3D", true, false)
		if not found.is_empty():
			_panels[panel_name] = found[0]

	_hinge_left = find_child("HingeTopLeft", true, false) as Node3D
	_hinge_right = find_child("HingeTopRight", true, false) as Node3D
	_hinge_side = find_child("HingeSide", true, false) as Node3D


# ============================================================
# POSE
# ============================================================

## The hinges are turned to the fold: across first (the top over the bottom, on both sides), then down (the right side
## over the left). The block that is left lies in the bottom left corner, so the pivot is moved to keep it in the middle.
func _pose() -> void:
	if _pivot == null or _hinge_left == null or _hinge_right == null or _hinge_side == null:
		return

	var across: float = smoothstep(0.0, 1.0, clampf(closedness * 2.0, 0.0, 1.0))
	var down: float = smoothstep(0.0, 1.0, clampf(closedness * 2.0 - 1.0, 0.0, 1.0))
	_hinge_left.rotation.x = PI * across + curl * (1.0 - across)
	_hinge_right.rotation.x = PI * across + curl * (1.0 - across)
	_hinge_side.rotation.y = -PI * down
	var quarter: Vector2 = sheet_size * 0.25
	_pivot.position = Vector3(quarter.x * down, quarter.y * across, 0.0)
