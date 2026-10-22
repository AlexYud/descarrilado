@tool
extends Node3D
class_name FigClearingProps

## The dressing of the fig tree clearing that the camp's puzzle uses, built in code from boxes and cylinders (the
## clearing scene adds this node as `CampDressing`; its frame is the clearing's):
##
##   The clothesline  near the western trail entrance: a rope strung between two of the forest's own trees
##       (the project's medium tree model), a damp jacket hung over it, and Juliana's note held to it by a
##       wooden peg (`READABLE_CAMP_NOTE`: she hid the signal tower's key near the camp).
##   The campsite log table  next to the campfire, with a log bench on the fire's side. On it stand a weathered
##       thermos with Sophia's note around its middle (`READABLE_THERMOS`, in Portuguese: the key is in the
##       lantern's signal box, and the filter turns to red) and the signal lantern, a puzzle (`SignalLantern`):
##       turning its coloured filter to red springs the latch of the drawer in its base, which holds the
##       brass signal key and the photograph "Rain at the Station".
##
## The inspectable pieces are scenes in `scenes/objects/fig_clearing/` (the note, the thermos, the lantern); what
## they look like is built here too, for the kinds below, so that ProceduralProp can fill their `Visual` node.

const NOTE_SCENE_PATH: String = "res://scenes/objects/fig_clearing/clothesline_note.tscn"
const THERMOS_SCENE_PATH: String = "res://scenes/objects/fig_clearing/camp_thermos.tscn"
const LANTERN_SCENE_PATH: String = "res://scenes/objects/fig_clearing/signal_lantern.tscn"
const TREE_SCENE_PATH: String = "res://assets/models/trees/medium_generic_tree/mediun_generic_tree.glb"

const KIND_CLOTHESLINE_NOTE: StringName = &"clothesline_note"
const KIND_THERMOS: StringName = &"camp_thermos"
const KIND_LANTERN: StringName = &"signal_lantern"

# The clothesline (the clearing's frame: the path enters from the west, the camp lies east of the middle).
const TREE_POSITIONS: Array[Vector3] = [Vector3(-6.2, 0.0, -1.0), Vector3(-4.6, 0.0, -4.3)]
const TREE_YAWS: Array[float] = [35.0, 200.0]
const TREE_SCALES: Array[float] = [1.0, 1.12]
const TRUNK_RADIUS: float = 0.2
const ROPE_WRAP_RADIUS: float = 0.14
const ROPE_HEIGHT_A: float = 2.2
const ROPE_HEIGHT_B: float = 2.05
const ROPE_SAG: float = 0.34
const ROPE_SEGMENTS: int = 18
const JACKET_AT: float = 0.4
const NOTE_AT: float = 0.68
## Where the rope passes behind the note's paper, in the note's frame (the peg holds paper and rope together).
const NOTE_ROPE_OFFSET: Vector3 = Vector3(0.0, 0.054, -0.014)

# The log table and its bench.
const TABLE_POSITION: Vector3 = Vector3(3.3, 0.0, 3.0)
const TABLE_YAW: float = -84.0
const TABLE_TOP_Y: float = 0.8
const TABLE_LENGTH: float = 1.5
const TABLE_DEPTH: float = 0.72
const BENCH_OFFSET: Vector3 = Vector3(0.0, 0.0, 0.85)
const THERMOS_ON_TABLE: Vector3 = Vector3(-0.42, 0.0, 0.04)
const LANTERN_ON_TABLE: Vector3 = Vector3(0.36, 0.0, 0.02)

# The thermos, the centre of its body at the origin.
const THERMOS_HEIGHT: float = 0.31
const THERMOS_BOTTOM: float = -0.15

# The lantern (origin at the middle of its base's underside, front toward +Z).
const LANTERN_BASE_SIZE: Vector3 = Vector3(0.22, 0.075, 0.17)
const LANTERN_DRUM_Y: float = 0.15
const LANTERN_DRUM_RADIUS: float = 0.058
const LANTERN_PANEL_COUNT: int = 3
## The drawer's tray floor, in the drawer's frame, and where the drawer's contents lie on it.
const DRAWER_FLOOR_Y: float = 0.012
const DRAWER_PHOTO_AT: Vector3 = Vector3(0.015, 0.0145, -0.025)
const DRAWER_KEY_AT: Vector3 = Vector3(-0.02, 0.0135, 0.055)
const DRAWER_SLIDE: float = 0.13

## The pieces the tests look for.
var trees: Array[Node3D] = []
var rope_points: PackedVector3Array = PackedVector3Array()
var jacket: Node3D = null
var note: Inspectable = null
var log_table: Node3D = null
var log_bench: Node3D = null
var thermos: Inspectable = null
var lantern: Node3D = null

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


# ============================================================
# KINDS (for ProceduralProp)
# ============================================================

static func has_kind(kind: StringName) -> bool:
	return kind in [KIND_CLOTHESLINE_NOTE, KIND_THERMOS, KIND_LANTERN]


static func build(kind: StringName, root: Node3D) -> void:
	match kind:
		KIND_CLOTHESLINE_NOTE:
			_build_clothesline_note(root)
		KIND_THERMOS:
			_build_thermos(root)
		KIND_LANTERN:
			_build_lantern(root)
		_:
			push_warning("FigClearingProps: unknown prop kind '%s'." % kind)


## Juliana's page, facing +Z, centred on the origin: a sheet torn from a school notebook, soft and wavy with damp,
## held by a wooden clothes peg at its top edge (the rope runs along the peg, behind the paper). The words are
## not drawn on it (the player reads them as an overlay); a few lines of a child's pencil stand for them.
static func _build_clothesline_note(root: Node3D) -> void:
	var paper: MeshInstance3D = HouseProps.add_box(
		root, "Paper", Vector3(0.14, 0.1, 0.0015), Vector3.ZERO, HouseProps.material(HouseProps.PAPER.darkened(0.06), 0.96)
	)
	var pencil: StandardMaterial3D = HouseProps.material(Color(0.22, 0.22, 0.24), 1.0)
	var widths: Array[float] = [0.112, 0.118, 0.09, 0.116, 0.104, 0.05]
	for i: int in widths.size():
		var line_x: float = -0.062 + widths[i] * 0.5 + (0.0 if i < widths.size() - 1 else 0.06)
		HouseProps.add_box(
			paper, "Line%d" % i, Vector3(widths[i], 0.002, 0.0004),
			Vector3(line_x, 0.03 - 0.0125 * float(i), 0.001), pencil
		)

	HouseProps.add_box(paper, "Damp", Vector3(0.07, 0.04, 0.0003), Vector3(0.036, -0.026, 0.0008), HouseProps.material(Color(0.5, 0.42, 0.3), 1.0))
	HouseProps.add_box(paper, "Fold", Vector3(0.0012, 0.1, 0.0004), Vector3(-0.02, 0.0, 0.0009), HouseProps.material(Color(0.6, 0.57, 0.48), 1.0))

	# The peg: two wooden legs either side of the paper's top edge, joined over the rope by a pale spring.
	var peg_wood: StandardMaterial3D = HouseProps.material(Color(0.5, 0.34, 0.18), 0.9)
	var rope_at: Vector3 = NOTE_ROPE_OFFSET
	HouseProps.add_box(root, "PegFront", Vector3(0.016, 0.07, 0.008), Vector3(0.0, 0.026, 0.0065), peg_wood)
	HouseProps.add_box(root, "PegBack", Vector3(0.016, 0.07, 0.008), Vector3(0.0, 0.026, -0.0065), peg_wood)
	HouseProps.add_box(root, "PegHead", Vector3(0.016, 0.012, 0.026), Vector3(0.0, 0.0625, 0.0), peg_wood)
	HouseProps.add_cylinder(root, "PegSpring", 0.0035, 0.018, Vector3(0.0, 0.034, 0.0), HouseProps.material(Color(0.5, 0.5, 0.52), 0.4, 0.8), Vector3(0.0, 0.0, 90.0))
	# The short stub of rope in the peg's grip, so the note stays right even without the clothesline around it.
	HouseProps.add_cylinder(root, "RopeStub", 0.0075, 0.08, rope_at, HouseProps.material(Color(0.55, 0.45, 0.3), 1.0), Vector3(0.0, 0.0, 90.0))


## A weathered steel thermos standing upright, centred on the origin, 31 cm tall with its cup on. A strip of paper
## is wrapped round its middle, tied with twine and held with a brass pin: the note (`READABLE_THERMOS`) is a
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


## The signal lantern, about 33 cm tall with its bail, front toward +Z, its origin at the middle of the base's
## underside. From the bottom: an iron base with a drawer (its tray slides out toward +Z, `Drawer`), a collar, the
## cage with four posts, a roof, a chimney and a bail, and inside the cage the filter drum (`Drum`), a cylinder
## with three panes of coloured glass 120 degrees apart: yellow, neutral and red (`Pane0`..`Pane2`, in that order
## round the drum; turning the drum by 120 degrees brings the next one to the front). A faint light inside it
## (`Glow`) takes the colour of the pane at the front. The glass is opaque and lit by itself: transparent panes
## would sort wrongly against each other.
static func _build_lantern(root: Node3D) -> void:
	var iron: StandardMaterial3D = HouseProps.material(Color(0.1, 0.1, 0.11), 0.55, 0.6)
	var rusty: StandardMaterial3D = HouseProps.material(Color(0.2, 0.12, 0.08), 0.8, 0.4)
	var brass: StandardMaterial3D = HouseProps.material(Color(0.62, 0.46, 0.16), 0.3, 0.85)

	# The base, with an open front for the drawer.
	var size: Vector3 = LANTERN_BASE_SIZE
	var base: Node3D = Node3D.new()
	base.name = "Base"
	root.add_child(base)
	HouseProps.add_box(base, "Floor", Vector3(size.x, 0.008, size.z), Vector3(0.0, 0.004, 0.0), iron)
	HouseProps.add_box(base, "Top", Vector3(size.x, 0.012, size.z), Vector3(0.0, size.y - 0.006, 0.0), iron)
	HouseProps.add_box(base, "SideL", Vector3(0.008, size.y - 0.02, size.z), Vector3(-size.x * 0.5 + 0.004, size.y * 0.5, 0.0), rusty)
	HouseProps.add_box(base, "SideR", Vector3(0.008, size.y - 0.02, size.z), Vector3(size.x * 0.5 - 0.004, size.y * 0.5, 0.0), rusty)
	HouseProps.add_box(base, "Back", Vector3(size.x, size.y - 0.02, 0.004), Vector3(0.0, size.y * 0.5, -size.z * 0.5 + 0.002), rusty)
	HouseProps.add_box(base, "Lip", Vector3(size.x + 0.004, 0.006, 0.006), Vector3(0.0, size.y - 0.0035, size.z * 0.5), brass)
	for rivet_x: float in [-0.095, 0.095]:
		HouseProps.add_cylinder(base, "Rivet", 0.004, 0.003, Vector3(rivet_x, size.y - 0.0125, 0.03), brass)

	# The drawer: a tray and a proud front panel with a brass knob. It slides out toward +Z.
	var drawer: Node3D = Node3D.new()
	drawer.name = "Drawer"
	root.add_child(drawer)
	HouseProps.add_box(drawer, "TrayFloor", Vector3(0.196, 0.004, 0.158), Vector3(0.0, DRAWER_FLOOR_Y - 0.002, 0.0), rusty)
	HouseProps.add_box(drawer, "TrayL", Vector3(0.004, 0.016, 0.158), Vector3(-0.098, DRAWER_FLOOR_Y + 0.006, 0.0), rusty)
	HouseProps.add_box(drawer, "TrayR", Vector3(0.004, 0.016, 0.158), Vector3(0.098, DRAWER_FLOOR_Y + 0.006, 0.0), rusty)
	HouseProps.add_box(drawer, "TrayBack", Vector3(0.196, 0.016, 0.004), Vector3(0.0, DRAWER_FLOOR_Y + 0.006, -0.077), rusty)
	HouseProps.add_box(drawer, "Front", Vector3(0.216, 0.056, 0.012), Vector3(0.0, 0.0375, 0.085), iron)
	HouseProps.add_cylinder(drawer, "Knob", 0.0075, 0.012, Vector3(0.0, 0.0375, 0.0975), brass, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_box(drawer, "Latch", Vector3(0.03, 0.01, 0.004), Vector3(0.0, 0.058, 0.0925), brass)

	# The collar between the base and the drum, and the cage round the drum.
	HouseProps.add_cylinder(root, "Collar", 0.089, 0.012, Vector3(0.0, size.y + 0.006, 0.0), iron)
	var cage: Node3D = Node3D.new()
	cage.name = "Cage"
	root.add_child(cage)
	var top_y: float = LANTERN_DRUM_Y + 0.07
	HouseProps.add_cylinder(cage, "TopPlate", 0.089, 0.01, Vector3(0.0, top_y, 0.0), iron)
	var roof: MeshInstance3D = HouseProps.add_cylinder(cage, "Roof", 0.089, 0.05, Vector3(0.0, top_y + 0.03, 0.0), rusty)
	(roof.mesh as CylinderMesh).top_radius = 0.018
	HouseProps.add_cylinder(cage, "Chimney", 0.014, 0.036, Vector3(0.0, top_y + 0.073, 0.0), iron)
	HouseProps.add_cylinder(cage, "ChimneyCap", 0.024, 0.006, Vector3(0.0, top_y + 0.094, 0.0), iron)
	HouseProps.add_ring(cage, "Bail", 0.052, 0.057, Vector3(0.0, top_y + 0.04, 0.0), iron)
	for post: int in 4:
		var angle: float = deg_to_rad(45.0 + 90.0 * float(post))
		HouseProps.add_cylinder(
			cage, "Post%d" % post, 0.0065, top_y - size.y - 0.012,
			Vector3(sin(angle) * 0.087, (top_y + size.y + 0.012) * 0.5, cos(angle) * 0.087), iron
		)

	# The drum: two rings, the struts between the panes, and the panes themselves.
	var drum: Node3D = Node3D.new()
	drum.name = "Drum"
	drum.position = Vector3(0.0, LANTERN_DRUM_Y, 0.0)
	root.add_child(drum)
	HouseProps.add_cylinder(drum, "RingBottom", 0.082, 0.01, Vector3(0.0, -0.06, 0.0), brass)
	HouseProps.add_cylinder(drum, "RingTop", 0.082, 0.01, Vector3(0.0, 0.06, 0.0), brass)
	var colours: Array[Color] = [Color(0.95, 0.72, 0.1), Color(0.8, 0.86, 0.9), Color(0.82, 0.05, 0.04)]
	var glow_strength: Array[float] = [0.7, 0.4, 0.85]
	for pane: int in LANTERN_PANEL_COUNT:
		var angle: float = TAU * float(pane) / float(LANTERN_PANEL_COUNT)
		var holder: Node3D = Node3D.new()
		holder.name = "Pane%d" % pane
		holder.position = Vector3(sin(angle), 0.0, cos(angle)) * LANTERN_DRUM_RADIUS
		holder.rotation = Vector3(0.0, angle, 0.0)
		drum.add_child(holder)
		var glass: StandardMaterial3D = HouseProps.material(colours[pane], 0.15)
		glass.emission_enabled = true
		glass.emission = colours[pane]
		glass.emission_energy_multiplier = glow_strength[pane]
		HouseProps.add_box(holder, "Glass", Vector3(0.092, 0.104, 0.005), Vector3.ZERO, glass)
		HouseProps.add_frame(holder, "Frame", Vector2(0.098, 0.11), Vector3(0.0, 0.0, 0.0015), 0.007, iron)
		var strut_angle: float = angle + TAU / 6.0
		HouseProps.add_cylinder(drum, "Strut%d" % pane, 0.0065, 0.11, Vector3(sin(strut_angle), 0.0, cos(strut_angle)) * 0.074, iron)

	# The flame behind the glass, and the light it throws.
	var flame_material: StandardMaterial3D = HouseProps.material(Color(1.0, 0.8, 0.4), 0.5)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.7, 0.25)
	flame_material.emission_energy_multiplier = 2.0
	HouseProps.add_cylinder(drum, "Wick", 0.005, 0.05, Vector3(0.0, -0.03, 0.0), brass)
	HouseProps.add_cylinder(drum, "Flame", 0.007, 0.034, Vector3(0.0, 0.0, 0.0), flame_material)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.name = "Glow"
	glow.position = Vector3(0.0, LANTERN_DRUM_Y, 0.0)
	glow.light_color = colours[0]
	glow.light_energy = 0.45
	glow.omni_range = 2.4
	glow.shadow_enabled = false
	root.add_child(glow)


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
			var wrap: MeshInstance3D = MeshInstance3D.new()
			wrap.name = "Wrap%d_%d" % [end, turn]
			var ring: TorusMesh = TorusMesh.new()
			ring.inner_radius = ROPE_WRAP_RADIUS - 0.006
			ring.outer_radius = ROPE_WRAP_RADIUS + 0.009
			wrap.mesh = ring
			wrap.material_override = _rope
			wrap.position = Vector3(trunk.x, height - 0.03 * float(turn), trunk.z)
			wrap.rotation_degrees = Vector3(4.0 * (1.0 - 2.0 * float(turn)), 0.0, 0.0)
			line.add_child(wrap)

	_build_jacket(line)
	_place_note(line)


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


## A damp jacket hung over the rope by its shoulders: front and back panels, sleeves hanging a little apart, a collar, a
## pocket, a zip, a darker wet hem and a few drops. It faces across the rope toward the middle of the clearing.
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

	HouseProps.add_box(jacket, "Pocket", Vector3(0.12, 0.1, 0.008), Vector3(0.11, -0.36, 0.0605), _jacket_wet)
	HouseProps.add_box(jacket, "Zip", Vector3(0.008, 0.52, 0.004), Vector3(0.0, -0.31, 0.0585), HouseProps.material(Color(0.55, 0.55, 0.52), 0.4, 0.7))
	var drop_material: StandardMaterial3D = HouseProps.material(Color(0.5, 0.6, 0.65), 0.1)
	for i: int in 3:
		HouseProps.add_cylinder(jacket, "Drop%d" % i, 0.004, 0.026, Vector3(-0.14 + 0.13 * float(i), -0.63 - 0.02 * float(i % 2), 0.0), drop_material)


## Juliana's note, hung from the rope on its peg beside the jacket, facing the same way.
func _place_note(parent: Node3D) -> void:
	var basis: Basis = hanging_basis()
	var hung: Node3D = (load(NOTE_SCENE_PATH) as PackedScene).instantiate() as Node3D
	hung.name = "ClotheslineNote"
	hung.transform = Transform3D(basis, rope_at(NOTE_AT) - basis * NOTE_ROPE_OFFSET)
	parent.add_child(hung)
	note = hung as Inspectable


# ============================================================
# THE LOG TABLE AND ITS BENCH
# ============================================================

func _build_log_table() -> void:
	log_table = Node3D.new()
	log_table.name = "LogTable"
	log_table.position = TABLE_POSITION
	log_table.rotation_degrees = Vector3(0.0, TABLE_YAW, 0.0)
	add_child(log_table)

	# The top is four hewn planks laid on two log rails, on four log legs.
	var plank_depth: float = (TABLE_DEPTH - 0.03) / 4.0
	for i: int in 4:
		var z: float = -TABLE_DEPTH * 0.5 + plank_depth * (float(i) + 0.5) + 0.01 * float(i)
		var plank: MeshInstance3D = HouseProps.add_box(
			log_table, "Plank%d" % i, Vector3(TABLE_LENGTH - 0.01 * float(i % 2), 0.045, plank_depth),
			Vector3(0.0, TABLE_TOP_Y - 0.0225, z), _wood_pale if i % 2 == 0 else _wood
		)
		plank.rotation_degrees.y = 0.4 * (1.0 - 2.0 * float(i % 2))

	for rail_x: float in [-0.56, 0.56]:
		HouseProps.add_cylinder(log_table, "Rail", 0.045, TABLE_DEPTH - 0.04, Vector3(rail_x, TABLE_TOP_Y - 0.045 - 0.04, 0.0), _bark, Vector3(90.0, 0.0, 0.0))

	for leg_x: float in [-0.56, 0.56]:
		for leg_z: float in [-0.29, 0.29]:
			HouseProps.add_cylinder(log_table, "Leg", 0.05, TABLE_TOP_Y - 0.13, Vector3(leg_x, (TABLE_TOP_Y - 0.13) * 0.5, leg_z), _bark)

	HouseProps.add_solid(log_table, "Solid", Vector3(TABLE_LENGTH, TABLE_TOP_Y, TABLE_DEPTH), Vector3(0.0, TABLE_TOP_Y * 0.5, 0.0))

	# A dark ring on the planks where a mug stood, and one knot.
	HouseProps.add_cylinder(log_table, "MugRing", 0.04, 0.0006, Vector3(-0.1, TABLE_TOP_Y + 0.0005, 0.2), HouseProps.material(Color(0.2, 0.13, 0.08), 1.0))

	_place_on_table()


func _place_on_table() -> void:
	var flask: Node3D = (load(THERMOS_SCENE_PATH) as PackedScene).instantiate() as Node3D
	flask.name = "Thermos"
	flask.position = THERMOS_ON_TABLE + Vector3(0.0, TABLE_TOP_Y - THERMOS_BOTTOM + 0.0005, 0.0)
	flask.rotation_degrees = Vector3(0.0, 24.0, 0.0)
	log_table.add_child(flask)
	thermos = flask as Inspectable

	lantern = (load(LANTERN_SCENE_PATH) as PackedScene).instantiate() as Node3D
	lantern.name = "SignalLantern"
	lantern.position = LANTERN_ON_TABLE + Vector3(0.0, TABLE_TOP_Y + 0.0005, 0.0)
	lantern.rotation_degrees = Vector3(0.0, -6.0, 0.0)
	log_table.add_child(lantern)


## A bench of a plank on two log stumps, on the fire's side of the table.
func _build_bench() -> void:
	log_bench = Node3D.new()
	log_bench.name = "LogBench"
	log_bench.position = TABLE_POSITION + Basis(Vector3.UP, deg_to_rad(TABLE_YAW)) * BENCH_OFFSET
	log_bench.rotation_degrees = Vector3(0.0, TABLE_YAW + 3.0, 0.0)
	add_child(log_bench)
	HouseProps.add_box(log_bench, "Seat", Vector3(1.5, 0.05, 0.3), Vector3(0.0, 0.425, 0.0), _wood_pale)
	for stump_x: float in [-0.56, 0.56]:
		HouseProps.add_cylinder(log_bench, "Stump", 0.11, 0.4, Vector3(stump_x, 0.2, 0.0), _bark)

	HouseProps.add_solid(log_bench, "Solid", Vector3(1.5, 0.45, 0.3), Vector3(0.0, 0.225, 0.0))


# ============================================================
# HELPERS
# ============================================================

## A cylinder from `from_point` to `to_point`.
static func _add_beam(parent: Node3D, node_name: String, from_point: Vector3, to_point: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var beam: MeshInstance3D = HouseProps.add_cylinder(parent, node_name, radius, from_point.distance_to(to_point), (from_point + to_point) * 0.5, mat)
	beam.basis = Basis(Quaternion(Vector3.UP, (to_point - from_point).normalized()))
	return beam
