@tool
extends Node3D
class_name FigClearingProps

## The dressing of the fig tree clearing, built in code from boxes and cylinders (the clearing scene adds this node as `CampDressing`; its frame is
## the clearing's: the trail runs in from the west and out to the east along z about 0.2, the fig tree stands at (3.3, -2) and the fire at (1, 2.8)):
##
##   The clothesline  near the western trail entrance (Trail Entrance A): a rope strung between two of the forest's own trees
##       (the project's medium tree model) with a damp jacket hung over it. A dressing only: nothing on it is searched or read.
##   The memory table  (`Scenery/CampTable` in the scene, with the cassette recorder, the photo album and Bus Stop Departure on it) stands in the open
##       beside the fig tree, clear of its trunk and roots, its front toward the trail; a lit hurricane lantern on it (`CampLantern`) lights it as the
##       fire lights the other side of the trail, so that the two lights show the way into the camp from the entrance.
##   The fire ring  three logs to sit on and a kettle on a stone, round the fire (the side toward the trail is left open). One of them is
##       the empty seat the last line of the memory comes from (`FigClearingSequence`; `seat_top()` says where a log's top is).
##   The campsite log table  next to the campfire, with a log bench on the fire's side. On it stand a weathered thermos with Sophia's note
##       around its middle (`READABLE_THERMOS`: the photo of the two of them as children is still on the desk at HQ) and the J & S lockbox
##       (`JSLockbox`), standing open, with the photograph "Rain at the Station" on its padding: nothing is locked in it any more (its wheels
##       are dressing). The lockbox stands at the table's southern end, near the edge, with its front facing outward (along the table), so that
##       a player at the end of the table is in front of it.
##   The wood yard  a chopping block with an axe in it, split wood and kindling, where the camp's first tent used to stand. The two tents (in
##       the scene) are pitched with their doors toward the middle of the camp, each with an open door and some gear in front of it.
##
## The inspectable pieces are scenes in `scenes/objects/fig_clearing/` (the thermos, the lockbox);
## what they look like is built here too, for the kinds below, so that ProceduralProp can fill their `Visual` node.


## The ready-made models the camp's wood is made of, and each one's box in its own file frame (position, size; metres), which `_place_model` fits to the
## size a prop has here.
const TABLE_SCENE: PackedScene = preload("res://assets/models/wooden_structures/wood_table/wood_table.glb")
const BENCH_SCENE: PackedScene = preload("res://assets/models/wooden_structures/wood_bench/wood_bench.glb")
const LOG_SCENE: PackedScene = preload("res://assets/models/wooden_structures/log/log.glb")
const STUMP_SCENE: PackedScene = preload("res://assets/models/wooden_structures/log_small/log_small.glb")
const AXE_SCENE: PackedScene = preload("res://assets/models/weapons/axe/axe.glb")
const STICK_SCENE: PackedScene = preload("res://assets/models/wooden_structures/wood_piece_medium/wood_piece_medium.glb")
const TABLE_BOX: AABB = AABB(Vector3(-0.622, -0.008, -1.404), Vector3(1.215, 0.997, 2.761))
const BENCH_BOX: AABB = AABB(Vector3(-0.197, -0.034, -1.187), Vector3(0.392, 0.519, 2.407))
const LOG_BOX: AABB = AABB(Vector3(-0.308, -0.296, -1.579), Vector3(0.615, 0.583, 3.112))
const STUMP_BOX: AABB = AABB(Vector3(-0.255, -0.053, -0.243), Vector3(0.510, 0.647, 0.479))
const STICK_BOX: AABB = AABB(Vector3(-0.307, -0.016, -0.015), Vector3(0.614, 0.031, 0.030))
const THERMOS_SCENE_PATH: String = "res://scenes/objects/fig_clearing/camp_thermos.tscn"
const LOCKBOX_SCENE_PATH: String = "res://scenes/objects/fig_clearing/js_lockbox.tscn"
const TREE_SCENE_PATH: String = "res://assets/models/trees/medium_generic_tree/mediun_generic_tree.glb"

const KIND_THERMOS: StringName = &"camp_thermos"
const KIND_LOCKBOX: StringName = &"js_lockbox"

# The clothesline (the clearing's frame: the path enters from the west, the camp lies east of the middle).
const TREE_POSITIONS: Array[Vector3] = [Vector3(-6.3, 0.0, -0.8), Vector3(-5.6, 0.0, -4.2)]
const TREE_YAWS: Array[float] = [35.0, 200.0]
const TREE_SCALES: Array[float] = [1.0, 1.12]
const TRUNK_RADIUS: float = 0.2
const ROPE_WRAP_RADIUS: float = 0.14
const ROPE_HEIGHT_A: float = 2.2
const ROPE_HEIGHT_B: float = 2.05
const ROPE_SAG: float = 0.34
const ROPE_SEGMENTS: int = 18
const JACKET_AT: float = 0.4

# The camp round the fire (the clearing's frame; the tents, the memory table and the firewood are in the scene). The three seats are logs lying along the
# ring (a position and the yaw of the log's length), the kettle stands on a stone on the fire's north east side, and the wood yard is where the first tent
# stood. The lantern stands on the memory table (in the table's frame, the top 0.78 m up).
const SEAT_POSITIONS: Array[Vector3] = [Vector3(-0.59, 0.0, 2.2), Vector3(-0.1, 0.0, 4.03), Vector3(1.45, 0.0, 4.35)]
const SEAT_YAWS: Array[float] = [70.0, -40.0, 25.0]
## How far each log is sunk in the ground.
const SEAT_SINK: float = 0.025
const KETTLE_AT: Vector3 = Vector3(1.78, 0.0, 2.15)
const BLOCK_AT: Vector3 = Vector3(-3.7, 0.0, 1.75)
const LANTERN_ON_MEMORY_TABLE: Vector3 = Vector3(0.63, 0.78, -0.17)
const LANTERN_LIGHT_ENERGY: float = 1.1
const LANTERN_LIGHT_RANGE: float = 5.0
const LANTERN_GLASS_GLOW: float = 2.4

# The log table and its bench.
## Table B stands 3.4 m east of the fire, turned so that its bench is on the memory table's side and the table beyond it: someone sitting there faces
## away from a player at the memory table (the line from the memory table, at (0.45, -2.2), to here runs about 39 degrees east of south).
const TABLE_POSITION: Vector3 = Vector3(4.4, 0.0, 2.6)
const TABLE_YAW: float = -141.0
const TABLE_TOP_Y: float = 0.8
const TABLE_LENGTH: float = 1.5
const TABLE_DEPTH: float = 0.72
const BENCH_OFFSET: Vector3 = Vector3(0.0, 0.0, 0.85)
## The top of the bench seat above the ground (its plank is 0.05 thick, centred at 0.425).
const BENCH_SEAT_Y: float = 0.45
## The thermos stands at the table's northern end, the lockbox at the southern one (the table's own frame: its length runs along x).
const THERMOS_ON_TABLE: Vector3 = Vector3(-0.55, 0.0, 0.04)
const LOCKBOX_ON_TABLE: Vector3 = Vector3(0.62, 0.0, 0.03)
## The lockbox's front faces the table's southern end (+X in the table's frame), a little off true as a hand leaves it.
const LOCKBOX_YAW: float = 88.0

# The thermos, the centre of its body at the origin.
const THERMOS_BOTTOM: float = -0.15

# The J & S lockbox (origin at the middle of the base's underside, front toward +Z): the body's width, height and depth, the lid's height, and
# the four thumb wheels of the dial in the front (their axis height, radius and spacing). The inside is padded up to 2.5 cm under the rim,
# so that what lies on it can be seen from a standing player's eyes over the front wall: the photograph and the key lie on the padding.
const LOCKBOX_SIZE: Vector3 = Vector3(0.30, 0.10, 0.19)
const LOCKBOX_LID_HEIGHT: float = 0.03
const LOCKBOX_WHEEL_Y: float = 0.043
const LOCKBOX_WHEEL_RADIUS: float = 0.0185
const LOCKBOX_WHEEL_SPACING: float = 0.052
const LOCKBOX_PADDING_TOP: float = 0.075
## The lockbox's close-up camera: this far above the rim of the box and this far in front of the dial (the box's frame).
const LOCKBOX_CLOSE_UP_RISE: float = 0.06
const LOCKBOX_CLOSE_UP_DISTANCE: float = 0.28
const LOCKBOX_PHOTO_AT: Vector3 = Vector3(0.0, 0.0773, -0.004)
const LOCKBOX_KEY_AT: Vector3 = Vector3(-0.05, 0.0793, 0.035)

# The jacket's chest pocket (the high one, with a flap): where the pocket's body and flap are, in the jacket's frame.
const CHEST_POCKET_AT: Vector3 = Vector3(-0.12, -0.215, 0.0605)
const CHEST_FLAP_AT: Vector3 = Vector3(-0.12, -0.168, 0.0615)

## The pieces the tests look for.
var trees: Array[Node3D] = []
var rope_points: PackedVector3Array = PackedVector3Array()
## The damp jacket on the rope: a dressing, nothing to search.
var jacket: Node3D = null
var log_table: Node3D = null
var log_bench: Node3D = null
var thermos: Inspectable = null
var lockbox: JSLockbox = null
## The three logs round the fire and the two tents (the scene's), which get their doors and gear here.
var seats: Array[Node3D] = []
var tents: Array[Node3D] = []
## The lit lantern on the memory table, its light, its glass's material and its flame.
var lantern: Node3D = null
var lantern_light: OmniLight3D = null
var lantern_glass_material: StandardMaterial3D = null
var lantern_flame: MeshInstance3D = null
## True once `put_out_lights` has been called: the camp's lights stay out.
var lights_out: bool = false
## How much of its light the lantern gives (0 to 1): the sequence dims it in dips before the camp goes dark.
var lantern_level: float = 1.0
## True once Table B has been cleared (`clear_log_table`).
var log_table_cleared: bool = false

var _rope: StandardMaterial3D
var _wood: StandardMaterial3D
var _wood_pale: StandardMaterial3D
var _bark: StandardMaterial3D
var _jacket_cloth: StandardMaterial3D
var _jacket_wet: StandardMaterial3D


func _ready() -> void:
	if get_child_count() > 0:
		return

	_make_materials()
	_build_clothesline()
	_build_log_table()
	_build_bench()
	_build_fire_ring()
	_build_wood_yard()
	_dress_tents()
	_build_camp_lantern()
	if lights_out:
		put_out_lights()


# ============================================================
# KINDS (for ProceduralProp)
# ============================================================

static func has_kind(kind: StringName) -> bool:
	return kind in [KIND_THERMOS, KIND_LOCKBOX]


static func build(kind: StringName, root: Node3D) -> void:
	match kind:
		KIND_THERMOS:
			_build_thermos(root)
		KIND_LOCKBOX:
			_build_js_lockbox(root)
		_:
			push_warning("FigClearingProps: unknown prop kind '%s'." % kind)


## A weathered steel thermos standing upright, centred on the origin, 31 cm tall with its cup on. A strip of paper
## is wrapped round its middle, tied with twine and held with a brass pin: Sophia's note (`READABLE_THERMOS`) is a
## readable spot on its front, offered from the start.
static func _build_thermos(root: Node3D) -> void:
	var steel: StandardMaterial3D = HouseProps.material(Color(0.27, 0.36, 0.31), 0.62, 0.55)
	var dark_steel: StandardMaterial3D = HouseProps.material(Color(0.14, 0.17, 0.15), 0.7, 0.4)
	var rust: StandardMaterial3D = HouseProps.material(Color(0.42, 0.22, 0.1), 0.95, 0.2)
	var cup_color: StandardMaterial3D = HouseProps.material(Color(0.2, 0.08, 0.06), 0.7, 0.2)
	var brass: StandardMaterial3D = HouseProps.material(Color(0.62, 0.46, 0.16), 0.3, 0.85)

	HouseProps.add_cylinder(root, "Body", 0.04, 0.22, Vector3(0.0, -0.04, 0.0), steel)
	HouseProps.add_cylinder(root, "Foot", 0.0425, 0.016, Vector3(0.0, THERMOS_BOTTOM + 0.008, 0.0), dark_steel)
	var shoulder: MeshInstance3D = HouseProps.add_cylinder(root, "Shoulder", 0.04, 0.03, Vector3(0.0, 0.085, 0.0), steel)
	(shoulder.mesh as CylinderMesh).top_radius = 0.03
	HouseProps.add_cylinder(root, "Neck", 0.03, 0.012, Vector3(0.0, 0.106, 0.0), dark_steel)
	# The cup, screwed on over the neck.
	HouseProps.add_cylinder(root, "Cup", 0.0355, 0.075, Vector3(0.0, 0.1465, 0.0), cup_color)
	HouseProps.add_cylinder(root, "CupRim", 0.0375, 0.008, Vector3(0.0, 0.1125, 0.0), dark_steel)
	# The handle, a loop on the left of the body.
	HouseProps.add_ring(root, "Handle", 0.026, 0.0315, Vector3(-0.0585, -0.01, 0.0), dark_steel)
	# Weathering: rust blooms where the paint has gone.
	HouseProps.add_cylinder(root, "RustLow", 0.0407, 0.03, Vector3(0.0, -0.118, 0.0), rust)
	HouseProps.add_box(root, "RustRim", Vector3(0.02, 0.012, 0.004), Vector3(0.026, 0.07, 0.025), rust, Vector3(0.0, 40.0, 0.0))
	HouseProps.add_box(root, "Dent", Vector3(0.02, 0.026, 0.004), Vector3(-0.018, -0.1, 0.0345), dark_steel, Vector3(0.0, -25.0, 10.0))

	# The note: a strip of paper wrapped round the middle of the body, with twine at both edges and a brass pin.
	var paper: StandardMaterial3D = HouseProps.material(Color(0.82, 0.77, 0.62), 0.96)
	var strip: MeshInstance3D = HouseProps.add_cylinder(root, "Note", 0.0415, 0.085, Vector3(0.0, -0.03, 0.0), paper)
	(strip.mesh as CylinderMesh).cap_top = false
	(strip.mesh as CylinderMesh).cap_bottom = false
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	var twine: StandardMaterial3D = HouseProps.material(Color(0.6, 0.5, 0.32), 1.0)
	for twine_y: float in [0.0075, -0.0675]:
		var cord: MeshInstance3D = MeshInstance3D.new()
		cord.name = "Twine"
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.0418
		ring.outer_radius = 0.0438
		cord.mesh = ring
		cord.material_override = twine
		cord.position = Vector3(0.0, twine_y, 0.0)
		root.add_child(cord)

	var spot: ReadableSpot = ReadableSpot.new()
	spot.name = "NoteSpot"
	spot.spot_id = &"thermos_note"
	spot.text_key = "READABLE_THERMOS"
	spot.title_key = ""
	spot.obvious = true
	spot.facing_angle_degrees = 55.0
	spot.position = Vector3(0.0, -0.03, 0.0422)
	root.add_child(spot)
	var pencil: StandardMaterial3D = HouseProps.material(Color(0.22, 0.22, 0.24), 1.0)
	var line_widths: Array[float] = [0.024, 0.026, 0.02, 0.025, 0.012]
	for i: int in line_widths.size():
		HouseProps.add_box(spot, "Line%d" % i, Vector3(line_widths[i], 0.0017, 0.0004), Vector3(0.0, 0.025 - 0.0125 * float(i), 0.0), pencil)

	HouseProps.add_cylinder(root, "Pin", 0.0055, 0.004, Vector3(0.0, 0.0075, 0.0428), brass, Vector3(90.0, 0.0, 0.0))


## Folds the plain meshes under `root` (the boxes, cylinders and rings a model is built from, a draw call each) into one mesh with a surface for
## each material, so that a detailed model costs a handful of draws instead of a hundred and fifty. A part named in `keep`, and everything under
## one, stays as it is (what is looked up by name, or moves); a group that is left empty goes (unless `prune_empty` is false). Text and lights are not meshes
## and stay.
static func _merge_by_material(root: Node3D, keep: Array[StringName], prune_empty: bool = true) -> void:
	var groups: Dictionary = {}
	var folded: Array[MeshInstance3D] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = node as MeshInstance3D
		if not part.mesh is PrimitiveMesh or part.material_override == null:
			continue

		var to_root: Transform3D = Transform3D.IDENTITY
		var up: Node = part
		var kept: bool = false
		while up != root and up is Node3D:
			kept = kept or keep.has(up.name) or up is ReadableSpot
			to_root = (up as Node3D).transform * to_root
			up = up.get_parent()

		if kept or up != root:
			continue

		if not groups.has(part.material_override):
			groups[part.material_override] = []

		(groups[part.material_override] as Array).append([part.mesh, to_root])
		folded.append(part)

	if folded.size() < 2:
		return

	var combined: ArrayMesh = ArrayMesh.new()
	for material: Material in groups:
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		for entry: Array in groups[material]:
			surface.append_from(entry[0] as Mesh, 0, entry[1] as Transform3D)

		surface.commit(combined)

	var merged: MeshInstance3D = MeshInstance3D.new()
	merged.name = "Merged"
	merged.mesh = combined
	root.add_child(merged)
	for part: MeshInstance3D in folded:
		var group: Node = part.get_parent()
		group.remove_child(part)
		part.free()
		while prune_empty and group != root and group.get_child_count() == 0:
			var above: Node = group.get_parent()
			above.remove_child(group)
			group.free()
			group = above


## The J & S lockbox, a steel strongbox 30 by 19 cm and 13 cm tall with its lid, its paint chipped to bare steel and rusting, "J & S"
## painted on the lid in white by a hand, and four brass and black thumb wheels in the front, a digit each (the code). Facing +Z, its
## origin the middle of the base's underside. The nodes `JSLockbox` looks up: `Wheels/Wheel0..3` (turned about X: a digit is 36 degrees,
## the one facing front is the value), `LidPivot` (hinged at the back), `Latch` (the hasp, hanging over the front, swings out when the
## lock lets go) and `CloseUp` (a marker: where the close-up view's camera goes, looking at the dial).
static func _build_js_lockbox(root: Node3D) -> void:
	var size: Vector3 = LOCKBOX_SIZE
	var width: float = size.x
	var height: float = size.y
	var depth: float = size.z
	var paint: StandardMaterial3D = HouseProps.material(Color(0.17, 0.22, 0.16), 0.62, 0.45)
	var dark_paint: StandardMaterial3D = HouseProps.material(Color(0.1, 0.13, 0.1), 0.7, 0.4)
	var bare: StandardMaterial3D = HouseProps.material(Color(0.42, 0.4, 0.37), 0.5, 0.8)
	var rust: StandardMaterial3D = HouseProps.material(Color(0.4, 0.2, 0.1), 0.95, 0.2)
	var brass: StandardMaterial3D = HouseProps.material(HouseProps.BRASS, 0.3, 0.85)
	var black: StandardMaterial3D = HouseProps.material(Color(0.05, 0.05, 0.055), 0.45, 0.6)
	var cloth: StandardMaterial3D = HouseProps.material(Color(0.2, 0.08, 0.07), 1.0)
	var white_paint: StandardMaterial3D = HouseProps.material(Color(0.88, 0.86, 0.78), 0.85)

	# The shell: a floor and four walls, open at the top.
	var wall: float = 0.008
	HouseProps.add_box(root, "Floor", Vector3(width, wall, depth), Vector3(0.0, wall * 0.5, 0.0), paint)
	for side: float in [-1.0, 1.0]:
		HouseProps.add_box(root, "Side", Vector3(wall, height - wall, depth), Vector3(side * (width * 0.5 - wall * 0.5), wall + (height - wall) * 0.5, 0.0), paint)

	HouseProps.add_box(root, "Back", Vector3(width, height - wall, wall), Vector3(0.0, wall + (height - wall) * 0.5, -(depth * 0.5 - wall * 0.5)), paint)
	HouseProps.add_box(root, "Front", Vector3(width, height - wall, wall), Vector3(0.0, wall + (height - wall) * 0.5, depth * 0.5 - wall * 0.5), paint)
	# What is inside: a padding of dark red cloth that the contents lie on, nearly up to the rim.
	HouseProps.add_box(root, "Padding", Vector3(width - 0.022, LOCKBOX_PADDING_TOP - wall, depth - 0.022), Vector3(0.0, wall + (LOCKBOX_PADDING_TOP - wall) * 0.5, 0.0), cloth)
	# Corner strips, a rim and the wear: bare steel where the paint has gone, rust where it has been wet.
	for corner_x: float in [-1.0, 1.0]:
		for corner_z: float in [-1.0, 1.0]:
			HouseProps.add_box(root, "Corner", Vector3(0.012, height, 0.012), Vector3(corner_x * (width * 0.5 - 0.0015), height * 0.5, corner_z * (depth * 0.5 - 0.0015)), dark_paint)

	HouseProps.add_box(root, "RimFront", Vector3(width + 0.004, 0.006, 0.01), Vector3(0.0, height - 0.003, depth * 0.5 - 0.003), dark_paint)
	HouseProps.add_box(root, "RimBack", Vector3(width + 0.004, 0.006, 0.01), Vector3(0.0, height - 0.003, -depth * 0.5 + 0.003), dark_paint)
	HouseProps.add_box(root, "ChipA", Vector3(0.03, 0.02, 0.0004), Vector3(0.1, 0.05, depth * 0.5 + 0.0002), bare, Vector3(0.0, 0.0, 14.0))
	HouseProps.add_box(root, "ChipB", Vector3(0.018, 0.012, 0.0004), Vector3(-0.115, 0.022, depth * 0.5 + 0.0002), bare)
	HouseProps.add_box(root, "RustA", Vector3(0.05, 0.03, 0.0005), Vector3(-0.12, 0.07, depth * 0.5 + 0.0003), rust, Vector3(0.0, 0.0, -9.0))
	HouseProps.add_box(root, "RustSide", Vector3(0.0005, 0.04, 0.07), Vector3(width * 0.5 + 0.0003, 0.035, 0.02), rust)
	HouseProps.add_box(root, "ChipSide", Vector3(0.0005, 0.02, 0.04), Vector3(-width * 0.5 - 0.0003, 0.06, -0.03), bare)

	# The dial: a black plate in the front with a brass bezel above and below it and four thumb wheels, half out of it.
	var front_z: float = depth * 0.5
	HouseProps.add_box(root, "DialPlate", Vector3(0.246, 0.058, 0.004), Vector3(0.0, LOCKBOX_WHEEL_Y, front_z + 0.002), black)
	HouseProps.add_box(root, "BezelTop", Vector3(0.246, 0.004, 0.012), Vector3(0.0, LOCKBOX_WHEEL_Y + 0.031, front_z + 0.006), brass)
	HouseProps.add_box(root, "BezelBottom", Vector3(0.246, 0.004, 0.012), Vector3(0.0, LOCKBOX_WHEEL_Y - 0.031, front_z + 0.006), brass)
	var wheels: Node3D = Node3D.new()
	wheels.name = "Wheels"
	root.add_child(wheels)
	var digit_color: Color = Color(0.95, 0.9, 0.72)
	for i: int in 4:
		var wheel: Node3D = Node3D.new()
		wheel.name = "Wheel%d" % i
		wheel.position = Vector3((float(i) - 1.5) * LOCKBOX_WHEEL_SPACING, LOCKBOX_WHEEL_Y, front_z + 0.004)
		wheels.add_child(wheel)
		HouseProps.add_cylinder(wheel, "Drum", LOCKBOX_WHEEL_RADIUS, 0.04, Vector3.ZERO, black, Vector3(0.0, 0.0, 90.0))
		for ring_x: float in [-0.0205, 0.0205]:
			HouseProps.add_cylinder(wheel, "Ring", LOCKBOX_WHEEL_RADIUS + 0.0015, 0.004, Vector3(ring_x, 0.0, 0.0), brass, Vector3(0.0, 0.0, 90.0))

		# Ten digits round the rim: digit k faces front when the wheel is turned k * 36 degrees about X.
		for digit: int in 10:
			var around: float = deg_to_rad(36.0 * float(digit))
			var label: Label3D = Label3D.new()
			label.name = "Digit%d" % digit
			label.text = str(digit)
			label.font_size = 40
			label.pixel_size = 0.0003
			label.modulate = digit_color
			label.outline_size = 0
			label.double_sided = false
			label.shaded = true
			label.position = Vector3(0.0, sin(around), cos(around)) * (LOCKBOX_WHEEL_RADIUS + 0.0006)
			label.rotation_degrees = Vector3(-36.0 * float(digit), 0.0, 0.0)
			wheel.add_child(label)

	# "J & S" in white paint, a letter at a time so that it is crooked: across the front under the dial, and big on the lid.
	_add_initials(root, Vector3(0.0, 0.0115, front_z + 0.0006), 0.0105, Vector3(0.0, 0.0, 0.0), white_paint, 0.011)

	# The lid, hinged at the back of the rim.
	var pivot: Node3D = Node3D.new()
	pivot.name = "LidPivot"
	pivot.position = Vector3(0.0, height, -depth * 0.5)
	root.add_child(pivot)
	HouseProps.add_box(pivot, "Lid", Vector3(width + 0.004, LOCKBOX_LID_HEIGHT, depth + 0.004), Vector3(0.0, LOCKBOX_LID_HEIGHT * 0.5, depth * 0.5), paint)
	HouseProps.add_box(pivot, "LidRibA", Vector3(width - 0.03, 0.002, 0.008), Vector3(0.0, LOCKBOX_LID_HEIGHT + 0.001, depth * 0.5 - 0.06), dark_paint)
	HouseProps.add_box(pivot, "LidRibB", Vector3(width - 0.03, 0.002, 0.008), Vector3(0.0, LOCKBOX_LID_HEIGHT + 0.001, depth * 0.5 + 0.06), dark_paint)
	HouseProps.add_box(pivot, "LidFront", Vector3(width + 0.004, 0.012, 0.006), Vector3(0.0, 0.006, depth + 0.002), dark_paint)
	HouseProps.add_box(pivot, "LidChip", Vector3(0.04, 0.0004, 0.025), Vector3(0.09, LOCKBOX_LID_HEIGHT + 0.0002, depth * 0.5 - 0.04), bare, Vector3(0.0, 22.0, 0.0))
	HouseProps.add_box(pivot, "LidRust", Vector3(0.05, 0.0005, 0.03), Vector3(-0.1, LOCKBOX_LID_HEIGHT + 0.0003, depth * 0.5 + 0.055), rust, Vector3(0.0, -15.0, 0.0))
	for hinge_x: float in [-0.09, 0.09]:
		HouseProps.add_cylinder(pivot, "Hinge", 0.006, 0.04, Vector3(hinge_x, 0.0, -0.004), black, Vector3(0.0, 0.0, 90.0))

	_add_initials(pivot, Vector3(0.0, LOCKBOX_LID_HEIGHT + 0.0008, depth * 0.5), 0.05, Vector3(-90.0, 0.0, 4.0), white_paint, 0.05)

	# The latch: a plate on a hinge at the lid's front edge, hanging down over a keeper in the body. It swings out when the lock lets go.
	HouseProps.add_box(root, "Keeper", Vector3(0.05, 0.034, 0.004), Vector3(0.0, height - 0.025, front_z + 0.002), black)
	HouseProps.add_cylinder(root, "KeeperEye", 0.006, 0.02, Vector3(0.0, height - 0.04, front_z + 0.008), brass, Vector3(0.0, 0.0, 90.0))
	var latch: Node3D = Node3D.new()
	latch.name = "Latch"
	latch.position = Vector3(0.0, height + 0.004, front_z + 0.006)
	root.add_child(latch)
	HouseProps.add_box(latch, "Strap", Vector3(0.036, 0.05, 0.004), Vector3(0.0, -0.025, 0.0), brass)
	HouseProps.add_box(latch, "Tab", Vector3(0.022, 0.01, 0.006), Vector3(0.0, -0.052, 0.002), brass)

	var close_up: Marker3D = Marker3D.new()
	close_up.name = "CloseUp"
	var eye: Vector3 = Vector3(0.0, height + LOCKBOX_CLOSE_UP_RISE, front_z + LOCKBOX_CLOSE_UP_DISTANCE)
	var target: Vector3 = Vector3(0.0, LOCKBOX_WHEEL_Y + 0.004, front_z + 0.012)
	close_up.transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	root.add_child(close_up)


## How many degrees above straight ahead the digit that counts is read. The close-up camera looks down on the dial from above, so the digit that faces
## straight out of the box is seen below the middle of its wheel, between two others, and the player could not tell which of them was the one. The wheels are
## turned this much further, so that the digit that counts faces the camera and is seen in the middle of its wheel (see `JSLockbox`).
static func lockbox_reading_degrees() -> float:
	var rise: float = LOCKBOX_SIZE.y + LOCKBOX_CLOSE_UP_RISE - LOCKBOX_WHEEL_Y
	return rad_to_deg(atan2(rise, LOCKBOX_CLOSE_UP_DISTANCE - 0.004))


## "J & S" in paint, three marks (a J, an ampersand and an S) each a little off its line and tilted, as if by hand. `letter_height` is how
## tall a letter is in metres; `spacing` the distance between the middles of the marks. Lying where `euler_degrees` says (the front: none; the
## lid: flat, -90 about X).
static func _add_initials(parent: Node3D, at: Vector3, letter_height: float, euler_degrees: Vector3, mat: StandardMaterial3D, spacing: float) -> void:
	var group: Node3D = Node3D.new()
	group.name = "Initials"
	group.position = at
	group.rotation_degrees = euler_degrees
	parent.add_child(group)
	var marks: Array[String] = ["J", "&", "S"]
	var tilts: Array[float] = [-6.0, 4.0, 7.0]
	var lifts: Array[float] = [0.0006, -0.0008, 0.0004]
	for i: int in marks.size():
		var label: Label3D = Label3D.new()
		label.name = "Mark%d" % i
		label.text = marks[i]
		label.font_size = 64
		label.pixel_size = letter_height / 64.0 / 0.72
		label.modulate = mat.albedo_color
		label.outline_size = 0
		label.shaded = true
		label.double_sided = false
		label.position = Vector3((float(i) - 1.0) * spacing * 1.6, lifts[i] * (letter_height / 0.01), 0.0)
		label.rotation_degrees = Vector3(0.0, 0.0, tilts[i])
		group.add_child(label)


# ============================================================
# MATERIALS
# ============================================================

func _make_materials() -> void:
	_rope = HouseProps.material(Color(0.55, 0.45, 0.3), 1.0)
	_wood = HouseProps.material(Color(0.36, 0.25, 0.14), 0.92)
	_wood_pale = HouseProps.material(Color(0.5, 0.38, 0.22), 0.92)
	_bark = HouseProps.material(Color(0.24, 0.17, 0.11), 1.0)
	_jacket_cloth = HouseProps.material(Color(0.56, 0.45, 0.14), 1.0)
	_jacket_wet = HouseProps.material(Color(0.28, 0.22, 0.08), 0.6)


# ============================================================
# THE CLOTHESLINE
# ============================================================

func _build_clothesline() -> void:
	var line: Node3D = Node3D.new()
	line.name = "Clothesline"
	add_child(line)

	var tree_scene: PackedScene = load(TREE_SCENE_PATH) as PackedScene
	for i: int in TREE_POSITIONS.size():
		var tree: Node3D = tree_scene.instantiate() as Node3D
		tree.name = "Tree%d" % (i + 1)
		tree.position = TREE_POSITIONS[i]
		tree.rotation_degrees = Vector3(0.0, TREE_YAWS[i], 0.0)
		tree.scale = Vector3.ONE * TREE_SCALES[i]
		line.add_child(tree)
		trees.append(tree)
		_add_trunk_solid(line, "Trunk%d" % (i + 1), TREE_POSITIONS[i])

	# The rope, a sagging chain of short cylinders, wrapped twice round each trunk.
	for i: int in ROPE_SEGMENTS + 1:
		rope_points.append(rope_at(float(i) / float(ROPE_SEGMENTS)))

	for i: int in ROPE_SEGMENTS:
		_add_beam(line, "Rope%d" % i, rope_points[i], rope_points[i + 1], 0.0075, _rope)

	for end: int in 2:
		var trunk: Vector3 = TREE_POSITIONS[end]
		var height: float = ROPE_HEIGHT_A if end == 0 else ROPE_HEIGHT_B
		for turn: int in 2:
			var turn_ring: MeshInstance3D = MeshInstance3D.new()
			turn_ring.name = "Wrap%d_%d" % [end, turn]
			var ring: TorusMesh = TorusMesh.new()
			ring.inner_radius = ROPE_WRAP_RADIUS - 0.006
			ring.outer_radius = ROPE_WRAP_RADIUS + 0.009
			turn_ring.mesh = ring
			turn_ring.material_override = _rope
			turn_ring.position = Vector3(trunk.x, height - 0.03 * float(turn), trunk.z)
			turn_ring.rotation_degrees = Vector3(4.0 * (1.0 - 2.0 * float(turn)), 0.0, 0.0)
			line.add_child(turn_ring)

	_build_jacket(line)


## The rope's point at `t` along it (0 at the first tree, 1 at the second): a parabola sagging below the
## straight line between the two knots.
static func rope_at(t: float) -> Vector3:
	var along: Vector3 = _line_direction()
	var start: Vector3 = TREE_POSITIONS[0] + along * ROPE_WRAP_RADIUS
	var end: Vector3 = TREE_POSITIONS[1] - along * ROPE_WRAP_RADIUS
	start.y = ROPE_HEIGHT_A
	end.y = ROPE_HEIGHT_B
	var point: Vector3 = start.lerp(end, t)
	point.y -= ROPE_SAG * 4.0 * t * (1.0 - t)
	return point


## The horizontal direction from the first tree to the second.
static func _line_direction() -> Vector3:
	var flat: Vector3 = TREE_POSITIONS[1] - TREE_POSITIONS[0]
	flat.y = 0.0
	return flat.normalized()


## The frame of something hanging from the rope at `t`: x along the rope, y up, z across it toward the clearing's middle.
static func hanging_basis() -> Basis:
	var along: Vector3 = _line_direction()
	var across: Vector3 = along.cross(Vector3.UP)
	return Basis(along, Vector3.UP, across)


func _add_trunk_solid(parent: Node3D, node_name: String, at: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = at + Vector3(0.0, 1.5, 0.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = TRUNK_RADIUS
	cylinder.height = 3.0
	shape.shape = cylinder
	body.add_child(shape)
	parent.add_child(body)


## A damp jacket hung over the rope by its shoulders: front and back panels, sleeves hanging a little apart, a collar, two pockets (a hand
## pocket low down, and a high one on the chest with a flap and a button), a zip, a darker wet hem and a few drops. It faces across the rope toward
## the middle of the clearing. Only a dressing: nothing on it is searched or read.
func _build_jacket(parent: Node3D) -> void:
	jacket = Node3D.new()
	jacket.name = "Jacket"
	jacket.transform = Transform3D(hanging_basis(), rope_at(JACKET_AT))
	parent.add_child(jacket)

	HouseProps.add_box(jacket, "Front", Vector3(0.44, 0.6, 0.022), Vector3(0.0, -0.31, 0.046), _jacket_cloth)
	HouseProps.add_box(jacket, "Back", Vector3(0.44, 0.6, 0.022), Vector3(0.0, -0.31, -0.046), _jacket_cloth)
	HouseProps.add_box(jacket, "Shoulders", Vector3(0.44, 0.03, 0.118), Vector3(0.0, -0.004, 0.0), _jacket_cloth)
	HouseProps.add_box(jacket, "Collar", Vector3(0.2, 0.05, 0.12), Vector3(0.0, 0.026, 0.0), _jacket_wet)
	HouseProps.add_box(jacket, "HemFront", Vector3(0.44, 0.15, 0.0225), Vector3(0.0, -0.535, 0.0462), _jacket_wet)
	HouseProps.add_box(jacket, "HemBack", Vector3(0.44, 0.15, 0.0225), Vector3(0.0, -0.535, -0.0462), _jacket_wet)
	for side: float in [-1.0, 1.0]:
		var sleeve: MeshInstance3D = HouseProps.add_box(
			jacket, "Sleeve", Vector3(0.12, 0.52, 0.07), Vector3(side * 0.28, -0.29, 0.0), _jacket_cloth,
			Vector3(0.0, 0.0, -side * 7.0)
		)
		HouseProps.add_box(sleeve, "Cuff", Vector3(0.122, 0.07, 0.072), Vector3(0.0, -0.225, 0.0), _jacket_wet)

	# The low hand pocket, and the high chest pocket with its flap and its button.
	HouseProps.add_box(jacket, "Pocket", Vector3(0.12, 0.1, 0.008), Vector3(0.11, -0.36, 0.0605), _jacket_wet)
	HouseProps.add_box(jacket, "ChestPocket", Vector3(0.12, 0.1, 0.008), CHEST_POCKET_AT, _jacket_wet)
	HouseProps.add_box(jacket, "ChestFlap", Vector3(0.126, 0.04, 0.01), CHEST_FLAP_AT, _jacket_cloth)
	HouseProps.add_cylinder(jacket, "ChestButton", 0.006, 0.004, CHEST_FLAP_AT + Vector3(0.0, -0.008, 0.0068), HouseProps.material(Color(0.5, 0.42, 0.2), 0.4, 0.7), Vector3(90.0, 0.0, 0.0))
	HouseProps.add_box(jacket, "Zip", Vector3(0.008, 0.52, 0.004), Vector3(0.0, -0.31, 0.0585), HouseProps.material(Color(0.55, 0.55, 0.52), 0.4, 0.7))
	var drop_material: StandardMaterial3D = HouseProps.material(Color(0.5, 0.6, 0.65), 0.1)
	for i: int in 3:
		HouseProps.add_cylinder(jacket, "Drop%d" % i, 0.004, 0.026, Vector3(-0.14 + 0.13 * float(i), -0.63 - 0.02 * float(i % 2), 0.0), drop_material)


# ============================================================
# FITTING A MODEL
# ============================================================

## A ready-made model stretched to a box: the model's own box (`file_box`, in its file frame) is turned `yaw_degrees` about Y, then stretched to `size`
## (in the frame of `parent`), and the middle of its base is put at `base`. Returns the model's root.
static func _place_model(parent: Node3D, scene: PackedScene, node_name: String, file_box: AABB, size: Vector3, base: Vector3, yaw_degrees: float) -> Node3D:
	var model: Node3D = scene.instantiate() as Node3D
	model.name = node_name
	var turn: Basis = Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var in_file: Vector3 = (turn.inverse() * size).abs()
	var fitted: Basis = turn * Basis.from_scale(Vector3(in_file.x / file_box.size.x, in_file.y / file_box.size.y, in_file.z / file_box.size.z))
	var centre: Vector3 = file_box.get_center()
	model.transform = Transform3D(fitted, base - fitted * Vector3(centre.x, file_box.position.y, centre.z))
	parent.add_child(model)
	return model


# ============================================================
# THE LOG TABLE AND ITS BENCH
# ============================================================

func _build_log_table() -> void:
	log_table = Node3D.new()
	log_table.name = "LogTable"
	log_table.position = TABLE_POSITION
	log_table.rotation_degrees = Vector3(0.0, TABLE_YAW, 0.0)
	add_child(log_table)

	# The table of the models: four hewn planks on log rails, on four log legs.
	_place_model(log_table, TABLE_SCENE, "Table", TABLE_BOX, Vector3(TABLE_LENGTH, TABLE_TOP_Y, TABLE_DEPTH), Vector3.ZERO, 90.0)
	HouseProps.add_solid(log_table, "Solid", Vector3(TABLE_LENGTH, TABLE_TOP_Y, TABLE_DEPTH), Vector3(0.0, TABLE_TOP_Y * 0.5, 0.0))

	_place_on_table()


func _place_on_table() -> void:
	var flask: Node3D = (load(THERMOS_SCENE_PATH) as PackedScene).instantiate() as Node3D
	flask.name = "Thermos"
	flask.position = THERMOS_ON_TABLE + Vector3(0.0, TABLE_TOP_Y - THERMOS_BOTTOM + 0.0005, 0.0)
	flask.rotation_degrees = Vector3(0.0, 24.0, 0.0)
	log_table.add_child(flask)
	thermos = flask as Inspectable

	# The lockbox stands at the table's southern end, near its edge, its front facing outward along the table: a player at the end of the table is in
	# front of it, close, with nothing between (the table's own collision keeps them from reaching across it). It stands open, with only the
	# photograph in it (set before it enters the tree, as it reads them in `_ready`).
	lockbox = (load(LOCKBOX_SCENE_PATH) as PackedScene).instantiate() as JSLockbox
	lockbox.name = "JSLockbox"
	lockbox.set("starts_open", true)
	lockbox.set("key_scene", null)
	lockbox.position = LOCKBOX_ON_TABLE + Vector3(0.0, TABLE_TOP_Y + 0.0005, 0.0)
	lockbox.rotation_degrees = Vector3(0.0, LOCKBOX_YAW, 0.0)
	log_table.add_child(lockbox)


## A bench of a plank on two log stumps, on the fire's side of the table.
func _build_bench() -> void:
	log_bench = Node3D.new()
	log_bench.name = "LogBench"
	log_bench.position = TABLE_POSITION + Basis(Vector3.UP, deg_to_rad(TABLE_YAW)) * BENCH_OFFSET
	log_bench.rotation_degrees = Vector3(0.0, TABLE_YAW + 3.0, 0.0)
	add_child(log_bench)
	_place_model(log_bench, BENCH_SCENE, "Bench", BENCH_BOX, Vector3(1.5, 0.45, 0.3), Vector3.ZERO, 90.0)
	HouseProps.add_solid(log_bench, "Solid", Vector3(1.5, 0.45, 0.3), Vector3(0.0, 0.225, 0.0))


# ============================================================
# THE CAMP: SEATS, WOOD, TENTS AND THE LANTERN
# ============================================================

## Three logs round the fire to sit on, each lying along the ring (the side toward the trail is left open, and the east side has the bench of the log
## table), a little sunk in the ground, with pale cut ends, and a kettle on a flat stone beside the fire.
func _build_fire_ring() -> void:
	var ring: Node3D = Node3D.new()
	ring.name = "FireRing"
	add_child(ring)
	for i: int in SEAT_POSITIONS.size():
		var seat: Node3D = Node3D.new()
		seat.name = "Seat%d" % (i + 1)
		seat.position = SEAT_POSITIONS[i]
		seat.rotation_degrees = Vector3(0.0, SEAT_YAWS[i], 0.0)
		ring.add_child(seat)
		seats.append(seat)
		var length: float = seat_length(i)
		var radius: float = seat_radius(i)
		_place_model(seat, LOG_SCENE, "Log", LOG_BOX, Vector3(length, radius * 2.0, radius * 2.0), Vector3(0.0, -SEAT_SINK, 0.0), 90.0)
		HouseProps.add_cylinder(seat, "Stub", 0.022, 0.1, Vector3(seat_stub_x(i), radius + 0.035, 0.02), _bark, Vector3(8.0, 0.0, 24.0))
		HouseProps.add_solid(seat, "Solid", Vector3(length, radius * 1.9, radius * 2.0), Vector3(0.0, radius * 0.95 - 0.02, 0.0))

	# The kettle: dented dark enamel on a flat stone, its handle up and its spout toward the fire.
	var kettle: Node3D = Node3D.new()
	kettle.name = "Kettle"
	kettle.position = KETTLE_AT
	kettle.rotation_degrees = Vector3(0.0, 205.0, 0.0)
	ring.add_child(kettle)
	var stone: StandardMaterial3D = HouseProps.material(Color(0.3, 0.3, 0.29), 0.95)
	var enamel: StandardMaterial3D = HouseProps.material(Color(0.12, 0.14, 0.17), 0.4, 0.35)
	HouseProps.add_box(kettle, "Stone", Vector3(0.34, 0.06, 0.28), Vector3(0.0, 0.03, 0.0), stone, Vector3(0.0, 12.0, 0.0))
	HouseProps.add_cylinder(kettle, "Body", 0.1, 0.15, Vector3(0.0, 0.135, 0.0), enamel)
	HouseProps.add_cylinder(kettle, "Lid", 0.07, 0.016, Vector3(0.0, 0.218, 0.0), enamel)
	HouseProps.add_cylinder(kettle, "Knob", 0.013, 0.02, Vector3(0.0, 0.235, 0.0), HouseProps.material(Color(0.05, 0.05, 0.05), 0.6))
	HouseProps.add_cylinder(kettle, "Spout", 0.015, 0.13, Vector3(0.1, 0.19, 0.0), enamel, Vector3(0.0, 0.0, -48.0))
	HouseProps.add_ring(kettle, "Handle", 0.082, 0.09, Vector3(0.0, 0.2, 0.0), HouseProps.material(Color(0.08, 0.08, 0.09), 0.5, 0.5))
	HouseProps.add_solid(kettle, "Solid", Vector3(0.34, 0.1, 0.3), Vector3(0.0, 0.05, 0.0))
	_merge_by_material(ring, [])


## The length and radius of log `index` of the fire ring, and where along it (its own x) the branch stub sticks up.
static func seat_length(index: int) -> float:
	return 1.3 - 0.07 * float(index)


static func seat_radius(index: int) -> float:
	return 0.15 + 0.012 * float(index % 2)


static func seat_stub_x(index: int) -> float:
	return 0.18 - 0.1 * float(index)


## The top of log `index`, `along` metres from its middle along its length, in the clearing's frame: the highest line of the bark, where
## something laid on the log rests (along that line a log is straight, so a small flat thing lies on it without rocking).
static func seat_top(index: int, along: float) -> Vector3:
	var top: Vector3 = Vector3(along, 2.0 * seat_radius(index) - SEAT_SINK, 0.0)
	return SEAT_POSITIONS[index] + Basis(Vector3.UP, deg_to_rad(SEAT_YAWS[index])) * top


## A chopping block with an axe sunk in it, split wood and kindling round it and a few chips on the ground, where the first tent used to stand
## (the ground there is bare, with no plants: the camp's tents were moved).
func _build_wood_yard() -> void:
	var yard: Node3D = Node3D.new()
	yard.name = "WoodYard"
	yard.position = BLOCK_AT
	add_child(yard)
	var steel: StandardMaterial3D = HouseProps.material(Color(0.22, 0.23, 0.25), 0.5, 0.7)
	# The chopping block is the models' stump (its cut top, with its rings, is part of it).
	_place_model(yard, STUMP_SCENE, "Block", STUMP_BOX, Vector3(0.46, 0.43, 0.46), Vector3.ZERO, 0.0)

	# The axe is stuck in it, blade down, the model turned over (head up in the file) with its blade sunk a little into the block.
	var axe: Node3D = Node3D.new()
	axe.name = "Axe"
	axe.position = Vector3(0.03, 0.43, -0.02)
	axe.rotation_degrees = Vector3(0.0, 24.0, -13.0)
	yard.add_child(axe)
	var axe_model: Node3D = AXE_SCENE.instantiate() as Node3D
	axe_model.name = "Model"
	var flip: Basis = Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3.ONE * 0.78)
	axe_model.transform = Transform3D(flip, Vector3(0.0, 0.459 * 0.78 - 0.06, 0.0))
	axe.add_child(axe_model)
	HouseProps.add_solid(yard, "Solid", Vector3(0.5, 0.42, 0.5), Vector3(0.0, 0.21, 0.0))

	# Split wood and kindling on the ground, as it fell.
	var split_spots: Array[Vector3] = [Vector3(0.52, 0.07, 0.26), Vector3(-0.46, 0.07, 0.42), Vector3(0.38, 0.065, -0.42)]
	var split_yaws: Array[float] = [20.0, -35.0, 70.0]
	for i: int in split_spots.size():
		var half: MeshInstance3D = HouseProps.add_cylinder(yard, "Split%d" % i, 0.075, 0.4, split_spots[i], _wood_pale, Vector3(90.0, 0.0, 0.0))
		half.rotation_degrees = Vector3(90.0, split_yaws[i], 0.0)
		half.scale = Vector3(1.0, 1.0, 0.7)

	var stick_spots: Array[Vector3] = [Vector3(0.7, 0.015, -0.12), Vector3(0.62, 0.015, 0.02), Vector3(-0.2, 0.015, 0.62), Vector3(-0.62, 0.015, 0.05), Vector3(0.12, 0.015, 0.7)]
	for i: int in stick_spots.size():
		var stick: Node3D = _place_model(yard, STICK_SCENE, "Kindling%d" % i, STICK_BOX, Vector3(0.34 - 0.03 * float(i % 3), 0.03, 0.03), Vector3(0.0, -0.015, 0.0), 0.0)
		stick.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(33.0 * float(i) - 20.0)) * Basis(Vector3.BACK, deg_to_rad(4.0 * float(i % 2))) * stick.transform.basis, stick_spots[i] + Vector3(0.0, 0.015, 0.0))

	var chip: StandardMaterial3D = HouseProps.material(Color(0.72, 0.6, 0.4), 1.0)
	for i: int in 7:
		var around: float = 0.9 * float(i) + 0.4
		HouseProps.add_box(yard, "Chip%d" % i, Vector3(0.05, 0.008, 0.03), Vector3(cos(around) * (0.33 + 0.08 * float(i % 3)), 0.006, sin(around) * (0.3 + 0.08 * float(i % 2))), chip, Vector3(0.0, 40.0 * float(i), 0.0))

	_merge_by_material(yard, [&"Axe"])


## The tents are pitched with their doors toward the middle of the camp (the clearing scene turns them): each gets a little gear in front of its
## door: a rolled mat and a backpack at the first tent, a pair of boots at the second. (The door itself is the model's: a dark doorway drawn on
## it was tried and removed.)
func _dress_tents() -> void:
	var scenery: Node = get_parent().get_node_or_null("Scenery") if get_parent() != null else null
	if scenery == null:
		return

	for tent_name: String in ["Tent", "Tent2"]:
		var tent: Node3D = scenery.get_node_or_null(tent_name) as Node3D
		if tent == null:
			continue

		tents.append(tent)

	if tents.size() > 0:
		_add_tent_gear(tents[0], true)

	if tents.size() > 1:
		_add_tent_gear(tents[1], false)

	# (A tent's own mesh is not a plain one and stays; its gear is folded, the empty groups kept for whoever looks for them.)
	for tent: Node3D in tents:
		_merge_by_material(tent, [], false)


## What lies in front of a tent's door (in the tent's frame, +Z out of the door).
func _add_tent_gear(tent: Node3D, with_pack: bool) -> void:
	var gear: Node3D = Node3D.new()
	gear.name = "Gear"
	tent.add_child(gear)
	if with_pack:
		var canvas: StandardMaterial3D = HouseProps.material(Color(0.2, 0.25, 0.15), 1.0)
		var dark_canvas: StandardMaterial3D = HouseProps.material(Color(0.12, 0.15, 0.1), 1.0)
		var strap: StandardMaterial3D = HouseProps.material(Color(0.07, 0.07, 0.06), 0.9)
		var pack: Node3D = Node3D.new()
		pack.name = "Backpack"
		pack.position = Vector3(-1.05, 0.0, 2.0)
		pack.rotation_degrees = Vector3(-7.0, -22.0, 0.0)
		gear.add_child(pack)
		HouseProps.add_box(pack, "Body", Vector3(0.36, 0.52, 0.22), Vector3(0.0, 0.26, 0.0), canvas)
		HouseProps.add_box(pack, "Lid", Vector3(0.34, 0.1, 0.24), Vector3(0.0, 0.52, 0.0), dark_canvas)
		HouseProps.add_box(pack, "Pocket", Vector3(0.28, 0.22, 0.09), Vector3(0.0, 0.17, 0.15), dark_canvas)
		for side: float in [-1.0, 1.0]:
			HouseProps.add_box(pack, "Strap", Vector3(0.04, 0.46, 0.012), Vector3(side * 0.1, 0.27, -0.115), strap)

		HouseProps.add_solid(pack, "Solid", Vector3(0.38, 0.6, 0.3), Vector3(0.0, 0.3, 0.03))
		var roll: StandardMaterial3D = HouseProps.material(Color(0.5, 0.27, 0.1), 0.95)
		HouseProps.add_cylinder(gear, "Mat", 0.1, 0.8, Vector3(0.5, 0.1, 1.95), roll, Vector3(0.0, 0.0, 90.0)).rotation_degrees = Vector3(0.0, 12.0, 90.0)
	else:
		var leather: StandardMaterial3D = HouseProps.material(Color(0.16, 0.1, 0.07), 0.8)
		var sole: StandardMaterial3D = HouseProps.material(Color(0.04, 0.04, 0.04), 0.9)
		for i: int in 2:
			var boot: Node3D = Node3D.new()
			boot.name = "Boot%d" % i
			boot.position = Vector3(0.4 + 0.3 * float(i), 0.0, 1.95 + 0.08 * float(i))
			boot.rotation_degrees = Vector3(0.0, 10.0 - 24.0 * float(i), 0.0)
			gear.add_child(boot)
			HouseProps.add_box(boot, "Sole", Vector3(0.11, 0.03, 0.3), Vector3(0.0, 0.015, 0.0), sole)
			HouseProps.add_box(boot, "Foot", Vector3(0.1, 0.09, 0.24), Vector3(0.0, 0.075, -0.02), leather)
			HouseProps.add_box(boot, "Shaft", Vector3(0.1, 0.17, 0.11), Vector3(0.0, 0.18, -0.09), leather)


## A hurricane lantern on the memory table (the table with the recorder and the album), lit: a glass with a flame in it and a warm light of its own, so
## that the table can be seen from the trail like the fire can. It stays lit when the fire goes out at the end of the memory.
func _build_camp_lantern() -> void:
	var table: Node3D = get_parent().get_node_or_null("Scenery/CampTable") as Node3D if get_parent() != null else null
	if table == null:
		return

	var iron: StandardMaterial3D = HouseProps.material(Color(0.08, 0.08, 0.09), 0.5, 0.6)
	lantern = Node3D.new()
	lantern.name = "CampLantern"
	lantern.position = LANTERN_ON_MEMORY_TABLE
	table.add_child(lantern)
	HouseProps.add_cylinder(lantern, "Base", 0.058, 0.02, Vector3(0.0, 0.01, 0.0), iron)
	HouseProps.add_cylinder(lantern, "Fuel", 0.04, 0.03, Vector3(0.0, 0.035, 0.0), HouseProps.material(Color(0.55, 0.5, 0.35), 0.5, 0.6))
	var glass: StandardMaterial3D = HouseProps.material(Color(1.0, 0.8, 0.5), 0.3)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.68, 0.32)
	glass.emission_energy_multiplier = LANTERN_GLASS_GLOW
	lantern_glass_material = glass
	HouseProps.add_cylinder(lantern, "Glass", 0.046, 0.13, Vector3(0.0, 0.115, 0.0), glass)
	for rib: int in 4:
		var around: float = deg_to_rad(45.0 + 90.0 * float(rib))
		HouseProps.add_cylinder(lantern, "Rib", 0.004, 0.14, Vector3(sin(around) * 0.049, 0.115, cos(around) * 0.049), iron)

	HouseProps.add_cylinder(lantern, "Top", 0.062, 0.022, Vector3(0.0, 0.192, 0.0), iron)
	HouseProps.add_cylinder(lantern, "Chimney", 0.02, 0.035, Vector3(0.0, 0.22, 0.0), iron)
	HouseProps.add_ring(lantern, "Bail", 0.052, 0.058, Vector3(0.0, 0.225, 0.0), iron)
	var flame: StandardMaterial3D = HouseProps.material(Color(1.0, 0.95, 0.7), 0.3)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.85, 0.5)
	flame.emission_energy_multiplier = 4.0
	lantern_flame = HouseProps.add_cylinder(lantern, "Flame", 0.01, 0.045, Vector3(0.0, 0.09, 0.0), flame)

	lantern_light = OmniLight3D.new()
	lantern_light.name = "Light"
	lantern_light.position = Vector3(0.0, 0.12, 0.0)
	lantern_light.light_color = Color(1.0, 0.7, 0.4)
	lantern_light.light_energy = LANTERN_LIGHT_ENERGY
	lantern_light.light_specular = 0.25
	lantern_light.omni_range = LANTERN_LIGHT_RANGE
	lantern_light.omni_attenuation = 1.3
	lantern_light.shadow_enabled = false
	lantern.add_child(lantern_light)
	_merge_by_material(lantern, [&"Glass", &"Flame"], false)


## Puts every light of the camp that is not the fire out at once (the fire does it itself): the lantern (its light, glass and flame), They stay out. (The camp's own ending no longer calls it: only the fire goes out there.)
func put_out_lights() -> void:
	lights_out = true
	lantern_level = 0.0
	if lantern_light != null:
		lantern_light.visible = false

	if lantern_glass_material != null:
		lantern_glass_material.emission_energy_multiplier = 0.0

	if lantern_flame != null:
		lantern_flame.visible = false



## The lantern gives `level` of its light (its glass and flame with it): 1 as it burns, 0 out (the light itself is not put out: `put_out_lights` does).
func set_lantern_level(level: float) -> void:
	lantern_level = clampf(level, 0.0, 1.0)
	if lights_out:
		return

	if lantern_glass_material != null:
		lantern_glass_material.emission_energy_multiplier = LANTERN_GLASS_GLOW * lantern_level
	if lantern_flame != null and lantern_flame.material_override is StandardMaterial3D:
		(lantern_flame.material_override as StandardMaterial3D).emission_energy_multiplier = 4.0 * lantern_level


## Table B, the log table by the fire, is cleared of what stood on it (the thermos and the J & S lockbox, which only matter until the album is
## solved: the photograph in the box is in the album by then): they are freed with their interaction and collision, their scenes and items stay
## as they are. Called by the sequence while the camera is on Table A, and on a game loaded after it.
func clear_log_table() -> void:
	log_table_cleared = true
	for prop: Node3D in [thermos, lockbox]:
		if prop != null and is_instance_valid(prop):
			prop.visible = false
			prop.process_mode = Node.PROCESS_MODE_DISABLED
			prop.queue_free()
	thermos = null
	lockbox = null


## The lantern's light wavers a little (a flame, not a bulb).
func _process(_delta: float) -> void:
	if lantern_light == null or lights_out or Engine.is_editor_hint():
		return

	var t: float = Time.get_ticks_msec() / 1000.0 * 6.5 + 1.3
	var wobble: float = 0.55 * sin(t) + 0.3 * sin(t * 2.4 + 0.8) + 0.15 * sin(t * 5.7)
	lantern_light.light_energy = LANTERN_LIGHT_ENERGY * (1.0 + 0.07 * wobble) * lantern_level


# ============================================================
# HELPERS
# ============================================================

## A cylinder from `from_point` to `to_point`.
static func _add_beam(parent: Node3D, node_name: String, from_point: Vector3, to_point: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var beam: MeshInstance3D = HouseProps.add_cylinder(parent, node_name, radius, from_point.distance_to(to_point), (from_point + to_point) * 0.5, mat)
	beam.basis = Basis(Quaternion(Vector3.UP, (to_point - from_point).normalized()))
	return beam
