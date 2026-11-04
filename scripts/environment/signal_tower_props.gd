@tool
extends Node3D
class_name SignalTowerProps

## The furniture of the ruined signal tower, built in code from boxes and cylinders (the tower itself is
## `SignalTowerBuilder`, which adds this node as its child `Props`; both share the tower's frame: the
## origin at the middle of the foot, the front door facing +Z).
##
##   Relay room (lower level, floor at y 0.005)  the children's headquarters, in three zones around an open
##       aisle. The one photograph the album needs from this place lies out in the open (no box, nothing to unlock):
##         1. the HQ desk, back left (a makeshift table of two crates and a plank with a drawer under it, two stools, a desk
##            lamp): Scraped Knee lies flat in the middle of the plank, and in the drawer (`DeskDrawer`, which slides out when it
##            is used) lies the note Juliana wrote;
##         2. the wooden bench on the right wall (a daybed with a cushion): Sophia's folded letter on graph paper;
##         3. the low shelf on the back wall: an open tin, with a few of a child's things on the lower board.
##       Also a relay cabinet, pipes, crates and a barrel, all kept out of the aisle.
##   Control cabin (upper level, floor at y 3.006)  the signal box's levers (a model), a stove under the stovepipe, a desk with a telegraph and a bench.
##       Nothing in it is read or picked up.
##
## The inspectable pieces are scenes (Juliana's and Sophia's notes); what they
## look like is built here too, for the kinds below, so that ProceduralProp can fill their `Visual` node.

const HQ_TABLE: Vector3 = Vector3(-1.15, SignalTowerBuilder.FLOOR_TOP, -1.3)
const HQ_WALL_Z: float = -2.0
## The middle of the back shelf and of the carved board over it, along the back wall.
const SHELF_X: float = 0.45
const LEVER_FRAME: Vector3 = Vector3(0.0, SignalTowerBuilder.BASE_HEIGHT, 1.35)
## The levers of the signal box (a model: a curved plate with twelve levers, two green and ten red, none broken and none that moves) and its box in its
## own file frame; the operator stands on the plate's side (+X in the file).
const LEVERS_SCENE: PackedScene = preload("res://assets/models/train_related/signal_box_levers/signal_box_levers.glb")
const LEVERS_BOX: AABB = AABB(Vector3(-0.640, 0.003, -0.934), Vector3(1.173, 1.186, 1.885))
const STOVE_POSITION: Vector3 = Vector3(-1.4, SignalTowerBuilder.BASE_HEIGHT, -0.9)

const JULIANA_NOTE_SCENE_PATH: String = "res://scenes/objects/signal_tower/tower_juliana_note.tscn"

const KIND_JULIANA_NOTE: StringName = &"juliana_note"
const KIND_SOPHIA_NOTE: StringName = &"sophia_note"
## The pieces other scripts and the tests look for.
## The photograph of the relay room, by item id (a Collectible in the game): only `photo_childhood`.
var photos: Dictionary = {}
## The ground floor's other items by key: `juliana_note` (in the desk drawer), `sophia_note` (Inspectables in the game).
var ground_items: Dictionary = {}
## The desk lamp, the desk's drawer and the tin, for the tests.
var desk_lamp: Node3D = null
var desk_drawer: DeskDrawer = null
var photo_tin: Node3D = null
var lever_frame: Node3D = null

var _iron: StandardMaterial3D
var _rust: StandardMaterial3D
var _wood: StandardMaterial3D
var _wood_pale: StandardMaterial3D
var _brass: StandardMaterial3D
var _glass: StandardMaterial3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if get_child_count() > 0:
		return

	_rng.seed = 1994
	_make_materials()
	_build_relay_room()
	_build_zones()
	_build_cabin()


# ============================================================
# KINDS (for ProceduralProp)
# ============================================================

static func has_kind(kind: StringName) -> bool:
	return kind in [KIND_JULIANA_NOTE, KIND_SOPHIA_NOTE]


static func build(kind: StringName, root: Node3D) -> void:
	match kind:
		KIND_JULIANA_NOTE:
			_build_juliana_note(root)
		KIND_SOPHIA_NOTE:
			_build_graph_paper(root)
		_:
			push_warning("SignalTowerProps: unknown prop kind '%s'." % kind)


## A page torn from a school notebook, facing +Z, centred on the origin. The words are not drawn on it (the player reads them as an overlay); a few
## lines of a child's pencil stand for them. It is creased down the middle and stained by damp.
static func _build_note(root: Node3D, tint: Color = HouseProps.PAPER) -> void:
	var paper: MeshInstance3D = HouseProps.add_box(root, "Paper", Vector3(0.11, 0.08, 0.0015), Vector3.ZERO, HouseProps.material(tint, 0.96))
	var pencil: StandardMaterial3D = HouseProps.material(Color(0.22, 0.22, 0.24), 1.0)
	var widths: Array[float] = [0.088, 0.092, 0.07, 0.09, 0.082, 0.04]
	for i: int in widths.size():
		var line_x: float = -0.049 + widths[i] * 0.5 + (0.0 if i < widths.size() - 1 else 0.05)
		HouseProps.add_box(
			paper, "Line%d" % i, Vector3(widths[i], 0.0016, 0.0004),
			Vector3(line_x, 0.026 - 0.0105 * float(i), 0.001), pencil
		)

	HouseProps.add_box(paper, "Crease", Vector3(0.0012, 0.08, 0.0004), Vector3(0.0, 0.0, 0.0009), HouseProps.material(Color(0.6, 0.57, 0.48), 1.0))
	HouseProps.add_box(paper, "Damp", Vector3(0.05, 0.034, 0.0003), Vector3(0.026, -0.018, 0.0008), HouseProps.material(Color(0.5, 0.42, 0.3), 1.0))


## The note Juliana wrote, facing +Z, centred on the origin: a page torn from a school notebook (cream, ruled with a few lines of her pencil, a
## crease down the middle where it was folded once), her little face with a fringe drawn in the top corner. The words are not drawn on it (the
## player reads them as an overlay).
static func _build_juliana_note(root: Node3D) -> void:
	_build_note(root, Color(0.86, 0.82, 0.68))
	var paper: Node3D = root.get_node("Paper") as Node3D
	var pencil: StandardMaterial3D = HouseProps.material(Color(0.2, 0.2, 0.22), 1.0)
	HouseProps.add_ring(paper, "Face", 0.0062, 0.0078, Vector3(0.039, 0.0275, 0.001), pencil)
	HouseProps.add_box(paper, "Fringe", Vector3(0.015, 0.0028, 0.0004), Vector3(0.039, 0.0328, 0.0011), pencil)


## A sheet of graph paper folded in four, facing +Z, centred on the origin: pale blue squares printed on cream
## paper, a crease down the middle and across it, one corner turned back. The words are not on it (the player
## reads them as an overlay).
static func _build_graph_paper(root: Node3D) -> void:
	var paper: MeshInstance3D = HouseProps.add_box(
		root, "Paper", Vector3(0.09, 0.07, 0.003), Vector3.ZERO, HouseProps.material(Color(0.5, 0.48, 0.42), 0.96)
	)
	var grid: MeshInstance3D = MeshInstance3D.new()
	grid.name = "Squares"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.09, 0.07)
	grid.mesh = quad
	var grid_material: StandardMaterial3D = HouseProps.material(Color(0.62, 0.6, 0.55), 0.96)
	grid_material.albedo_texture = _make_graph_texture()
	grid.material_override = grid_material
	grid.position = Vector3(0.0, 0.0, 0.0016)
	paper.add_child(grid)
	var crease: StandardMaterial3D = HouseProps.material(Color(0.2, 0.2, 0.18), 1.0)
	HouseProps.add_box(paper, "CreaseUp", Vector3(0.0012, 0.07, 0.0004), Vector3(0.0, 0.0, 0.0019), crease)
	HouseProps.add_box(paper, "CreaseAcross", Vector3(0.09, 0.0012, 0.0004), Vector3(0.0, 0.0, 0.0019), crease)
	# A turned back corner showing the paper's other side.
	HouseProps.add_box(paper, "Corner", Vector3(0.026, 0.026, 0.001), Vector3(0.032, -0.022, 0.0025), HouseProps.material(Color(0.36, 0.34, 0.3), 0.96), Vector3(0.0, 0.0, 45.0))


static func _make_graph_texture() -> ImageTexture:
	var width: int = 180
	var height: int = 140
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
	for y: int in height:
		for x: int in width:
			var on_line: bool = x % 10 == 0 or y % 10 == 0
			var heavy: bool = x % 50 == 0 or y % 50 == 0
			var color: Color = Color(0.72, 0.68, 0.58)
			if heavy:
				color = Color(0.3, 0.42, 0.58)
			elif on_line:
				color = Color(0.48, 0.58, 0.68)
			image.set_pixel(x, y, color)

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# ============================================================
# MATERIALS
# ============================================================

func _make_materials() -> void:
	_iron = JunctionProps.weathered(JunctionProps.IRON, 3.0, 0.6, 0.7)
	_rust = JunctionProps.weathered(JunctionProps.RUST, 3.0, 0.9, 0.5)
	_wood = JunctionProps.weathered(JunctionProps.WOOD_OLD, 3.0, 0.9)
	_wood_pale = JunctionProps.weathered(JunctionProps.WOOD_PALE, 3.0, 0.9)
	_brass = HouseProps.material(HouseProps.BRASS, 0.4, 0.85)
	_glass = HouseProps.glass_material(Color(0.6, 0.7, 0.66, 0.22))


# ============================================================
# RELAY ROOM
# ============================================================

func _build_relay_room() -> void:
	var room: Node3D = Node3D.new()
	room.name = "RelayRoom"
	add_child(room)
	var floor_y: float = SignalTowerBuilder.FLOOR_TOP
	var inner: float = SignalTowerBuilder.ROOM_HALF

	# The relay cabinet against the right wall, in the back corner: the wooden cabinet of the models (its doors open and close like any door), turned to
	# face the room (-X), with coils in its lower compartment.
	var cabinet: WoodCabinet = WoodCabinet.new()
	cabinet.name = "RelayCabinet"
	cabinet.persistent_prefix = &"tower_relay_cabinet"
	cabinet.coils = true
	cabinet.position = Vector3(inner - 0.33, floor_y, -1.2)
	cabinet.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	room.add_child(cabinet)

	# Conduit along the back wall under the deck, with a drop to the floor between the window and the cabinet.
	var pipe_y: float = 2.35
	HouseProps.add_cylinder(room, "ConduitBack", 0.035, inner * 2.0 - 0.1, Vector3(0.0, pipe_y, -inner + 0.06), _iron, Vector3(0.0, 0.0, 90.0))
	HouseProps.add_cylinder(room, "ConduitDrop", 0.035, pipe_y - floor_y, Vector3(1.27, floor_y + (pipe_y - floor_y) * 0.5, -inner + 0.06), _iron)
	for bracket_x: float in [-1.4, -0.4, 0.6, 1.4]:
		HouseProps.add_box(room, "Bracket", Vector3(0.04, 0.05, 0.05), Vector3(bracket_x, pipe_y, -inner + 0.03), _rust)

	# Crates and a barrel along the left wall, out of the aisle between the door and the zones.
	_crate(room, "CrateLarge", Vector3(0.55, 0.5, 0.45), Vector3(-inner + 0.4, floor_y, 0.75), 12.0)
	_crate(room, "CrateSmall", Vector3(0.42, 0.38, 0.38), Vector3(-inner + 0.4, floor_y + 0.5, 0.75), -8.0, false)
	HouseProps.add_cylinder(room, "Barrel", 0.26, 0.8, Vector3(-inner + 0.3, floor_y + 0.4, 0.0), _wood)
	for band_y: float in [0.2, 0.6]:
		HouseProps.add_cylinder(room, "BarrelBand", 0.268, 0.03, Vector3(-inner + 0.3, floor_y + band_y, 0.0), _rust)
	HouseProps.add_solid(room, "BarrelSolid", Vector3(0.5, 0.8, 0.5), Vector3(-inner + 0.3, floor_y + 0.4, 0.0))

	# A gap in the floorboards by the door: two planks snapped, and black under them.
	HouseProps.add_box(room, "FloorGap", Vector3(0.5, 0.002, 0.16), Vector3(-0.95, floor_y + 0.0012, 1.2), HouseProps.black_material(), Vector3(0.0, 14.0, 0.0))
	HouseProps.add_box(room, "BrokenPlankA", Vector3(0.42, 0.025, 0.1), Vector3(-1.27, floor_y + 0.02, 1.32), _wood, Vector3(6.0, 14.0, 8.0))
	HouseProps.add_box(room, "BrokenPlankB", Vector3(0.3, 0.025, 0.1), Vector3(-0.67, floor_y + 0.012, 1.1), _wood, Vector3(0.0, 24.0, -6.0))


# ============================================================
# THE CHILDREN'S HEADQUARTERS: three zones round an open aisle
# ============================================================

func _build_zones() -> void:
	var corner: Node3D = Node3D.new()
	corner.name = "HeadQuarters"
	add_child(corner)
	_build_desk_zone(corner)
	_build_daybed_zone(corner)
	_build_shelf_zone(corner)

	# Days counted in scratches on the wall beside the desk, in fives.
	for group: int in 4:
		for stroke: int in 4:
			HouseProps.add_box(
				corner, "Tally%d_%d" % [group, stroke], Vector3(0.006, 0.09, 0.004),
				Vector3(-1.72 + 0.014 * float(stroke) + 0.1 * float(group), 0.95, HQ_WALL_Z + 0.002), HouseProps.material(Color(0.12, 0.09, 0.07), 1.0)
			)
		HouseProps.add_box(
			corner, "TallyCross%d" % group, Vector3(0.06, 0.006, 0.004),
			Vector3(-1.72 + 0.021 + 0.1 * float(group), 0.95, HQ_WALL_Z + 0.002), HouseProps.material(Color(0.12, 0.09, 0.07), 1.0), Vector3(0.0, 0.0, 25.0)
		)


## Zone 1, the HQ desk in the back left corner: a table of two crates and a plank (the plank's top is 0.74 m over the floor, a real table's) with a drawer under
## the plank, two stools and a desk lamp. The Scraped Knee lies flat in the middle of the plank; in the drawer lies the note Juliana wrote.
func _build_desk_zone(corner: Node3D) -> void:
	var table: Node3D = Node3D.new()
	table.name = "CrateTable"
	table.position = HQ_TABLE
	table.rotation_degrees = Vector3(0.0, 6.0, 0.0)
	corner.add_child(table)
	# (The crates stand a little apart: the drawer is between them, under the plank.)
	_crate(table, "CrateLeft", Vector3(0.4, 0.70, 0.5), Vector3(-0.42, 0.0, 0.0), 0.0)
	_crate(table, "CrateRight", Vector3(0.4, 0.70, 0.5), Vector3(0.42, 0.0, 0.0), 0.0)
	HouseProps.add_box(table, "Plank", Vector3(1.24, 0.04, 0.66), Vector3(0.0, 0.72, 0.0), _wood_pale)
	HouseProps.add_solid(table, "Solid", Vector3(1.24, 0.76, 0.66), Vector3(0.0, 0.38, 0.0))
	HouseProps.add_cylinder(table, "Pencil", 0.005, 0.15, Vector3(0.2, 0.744, 0.2), HouseProps.material(Color(0.7, 0.55, 0.15), 0.6), Vector3(90.0, 40.0, 0.0))

	# The desk lamp, back left on the plank: a round iron foot, a thin stem, an arm and a green enamel shade.
	desk_lamp = Node3D.new()
	desk_lamp.name = "DeskLamp"
	desk_lamp.position = Vector3(-0.4, 0.74, -0.15)
	table.add_child(desk_lamp)
	var enamel: StandardMaterial3D = HouseProps.material(Color(0.12, 0.3, 0.22), 0.5, 0.3)
	HouseProps.add_cylinder(desk_lamp, "Base", 0.07, 0.03, Vector3(0.0, 0.015, 0.0), _iron)
	HouseProps.add_cylinder(desk_lamp, "Stem", 0.009, 0.3, Vector3(0.0, 0.18, 0.0), _brass)
	HouseProps.add_box(desk_lamp, "Arm", Vector3(0.012, 0.012, 0.11), Vector3(0.0, 0.33, 0.05), _brass)
	var shade: CylinderMesh = CylinderMesh.new()
	shade.top_radius = 0.02
	shade.bottom_radius = 0.075
	shade.height = 0.09
	var shade_node: MeshInstance3D = MeshInstance3D.new()
	shade_node.name = "Shade"
	shade_node.mesh = shade
	shade_node.material_override = enamel
	shade_node.position = Vector3(0.0, 0.3, 0.1)
	desk_lamp.add_child(shade_node)
	HouseProps.add_box(desk_lamp, "Cord", Vector3(0.004, 0.004, 0.22), Vector3(0.0, 0.004, 0.1), HouseProps.black_material())

	# Photo 1, Scraped Knee, lies flat in the middle of the plank, a little turned (it was leaning against the lamp's base, which looked as if it
	# were propped on a cup).
	_place_photo("photo_childhood", "res://scenes/objects/photo_childhood.tscn", table, Vector3(0.0, 0.7435, 0.02), Vector3(-90.0, 7.0, 0.0))

	# The drawer under the plank, between the crates: its front flush with the plank's front edge. Juliana's note lies in it, near the front, so that it
	# shows when the drawer is out.
	desk_drawer = DeskDrawer.build(Vector3(0.0, 0.632, 0.332), 0.42, 0.11, 0.46, _wood, _wood_pale, _brass, _wood)
	desk_drawer.persistent_id = &"tower_desk_drawer"
	desk_drawer.travel = 0.34
	var note: Node3D = (load(JULIANA_NOTE_SCENE_PATH) as PackedScene).instantiate() as Node3D
	note.name = "JulianaNote"
	note.position = Vector3(0.01, 0.0012, 0.0)
	note.rotation_degrees = Vector3(-90.0, 6.0, 0.0)
	desk_drawer.contents.add_child(note)
	ground_items[&"juliana_note"] = note as Inspectable
	table.add_child(desk_drawer)

	_stool(corner, "StoolA", HQ_TABLE + Vector3(0.5, 0.0, 0.85), 20.0)
	_stool(corner, "StoolB", HQ_TABLE + Vector3(-0.45, 0.0, 0.78), -35.0)


## Zone 2, the daybed along the right wall: a plank frame with a faded cushion, a bolster at the far end; on the
## cushion Sophia's folded letter.
func _build_daybed_zone(corner: Node3D) -> void:
	var inner: float = SignalTowerBuilder.ROOM_HALF
	var daybed: Node3D = Node3D.new()
	daybed.name = "Daybed"
	daybed.position = Vector3(inner - 0.43, SignalTowerBuilder.FLOOR_TOP, 0.45)
	corner.add_child(daybed)
	HouseProps.add_box(daybed, "FrameLeft", Vector3(0.04, 0.12, 1.8), Vector3(-0.34, 0.34, 0.0), _wood)
	HouseProps.add_box(daybed, "FrameRight", Vector3(0.04, 0.12, 1.8), Vector3(0.34, 0.34, 0.0), _wood)
	HouseProps.add_box(daybed, "FrameEndBack", Vector3(0.72, 0.12, 0.04), Vector3(0.0, 0.34, -0.9), _wood)
	HouseProps.add_box(daybed, "FrameEndFront", Vector3(0.72, 0.12, 0.04), Vector3(0.0, 0.34, 0.9), _wood)
	for leg_x: float in [-0.33, 0.33]:
		for leg_z: float in [-0.88, 0.88]:
			HouseProps.add_box(daybed, "Leg", Vector3(0.06, 0.34, 0.06), Vector3(leg_x, 0.17, leg_z), _wood)
	var fabric: StandardMaterial3D = JunctionProps.weathered(Color(0.4, 0.3, 0.26), 4.0, 1.0)
	HouseProps.add_box(daybed, "Cushion", Vector3(0.68, 0.09, 1.76), Vector3(0.0, 0.445, 0.0), fabric)
	var bolster: MeshInstance3D = HouseProps.add_cylinder(daybed, "Bolster", 0.08, 0.64, Vector3(0.0, 0.54, -0.8), fabric, Vector3(0.0, 0.0, 90.0))
	bolster.name = "Bolster"
	HouseProps.add_solid(daybed, "Solid", Vector3(0.72, 0.49, 1.8), Vector3(0.0, 0.245, 0.0))

	# The cushion's top is at 0.49 above the daybed's origin.
	var top: float = 0.49
	# Sophia's folded letter lies on the cushion, a little turned.
	_place_ground_item(&"sophia_note", "res://scenes/objects/signal_tower/tower_sophia_note.tscn", daybed, Vector3(-0.02, top + 0.0022, -0.37), Vector3(-90.0, 12.0, 0.0))


## Zone 3, the low shelf on the back wall: an open tin, and a few of a child's things on the lower board.
func _build_shelf_zone(corner: Node3D) -> void:
	var shelf: Node3D = Node3D.new()
	shelf.name = "BackShelf"
	shelf.position = Vector3(SHELF_X, SignalTowerBuilder.FLOOR_TOP, HQ_WALL_Z + 0.2)
	corner.add_child(shelf)
	HouseProps.add_box(shelf, "Top", Vector3(1.1, 0.04, 0.36), Vector3(0.0, 0.44, 0.0), _wood_pale)
	HouseProps.add_box(shelf, "Lower", Vector3(1.1, 0.03, 0.36), Vector3(0.0, 0.18, 0.0), _wood)
	for side_x: float in [-0.53, 0.53]:
		HouseProps.add_box(shelf, "End", Vector3(0.04, 0.46, 0.36), Vector3(side_x, 0.23, 0.0), _wood)
	HouseProps.add_solid(shelf, "Solid", Vector3(1.1, 0.46, 0.36), Vector3(0.0, 0.23, 0.0))
	# On the lower board: a stack of three picture books and a jam jar of pencils.
	for book: int in 3:
		HouseProps.add_box(
			shelf, "Book%d" % book, Vector3(0.2, 0.025, 0.15), Vector3(-0.3, 0.2 + 0.0125 + 0.025 * float(book), 0.02),
			HouseProps.material([Color(0.5, 0.2, 0.15), Color(0.2, 0.35, 0.45), Color(0.55, 0.45, 0.2)][book], 0.9), Vector3(0.0, 6.0 * float(book - 1), 0.0)
		)
	# (An opaque clay pot: a see through glass jar sorted wrongly against the boards and seemed to glitch inside the shelf.)
	HouseProps.add_cylinder(shelf, "Pot", 0.045, 0.1, Vector3(0.3, 0.245, 0.02), HouseProps.material(Color(0.55, 0.36, 0.26), 0.85))

	# The open tin on the top board, its lid lying beside it.
	photo_tin = Node3D.new()
	photo_tin.name = "Tin"
	photo_tin.position = Vector3(-0.05, 0.464, 0.0)
	shelf.add_child(photo_tin)
	var tin_material: StandardMaterial3D = HouseProps.material(Color(0.62, 0.64, 0.6), 0.4, 0.6)
	tin_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tin_mesh: CylinderMesh = CylinderMesh.new()
	tin_mesh.top_radius = 0.095
	tin_mesh.bottom_radius = 0.09
	tin_mesh.height = 0.07
	tin_mesh.cap_top = false
	var tin_node: MeshInstance3D = MeshInstance3D.new()
	tin_node.name = "Body"
	tin_node.mesh = tin_mesh
	tin_node.material_override = tin_material
	# (Its inside is drawn from behind the wall: it must not cast a shadow onto itself, which showed as a spiky fan.)
	tin_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tin_node.position = Vector3(0.0, 0.035, 0.0)
	photo_tin.add_child(tin_node)
	HouseProps.add_cylinder(photo_tin, "Lid", 0.1, 0.008, Vector3(0.24, 0.004, 0.02), tin_material, Vector3(0.0, 0.0, 6.0))


## Puts a photograph (a Collectible scene) where it lies. Plain nodes first: in the editor the scripts of
## instanced scenes are placeholders and a cast gives nothing.
func _place_photo(item_id: String, scene_path: String, parent: Node3D, pos: Vector3, rotation_degrees_value: Vector3) -> void:
	var photo: Node3D = (load(scene_path) as PackedScene).instantiate() as Node3D
	photo.name = item_id.capitalize().replace(" ", "")
	photo.position = pos
	photo.rotation_degrees = rotation_degrees_value
	parent.add_child(photo)
	photos[item_id] = photo


func _place_ground_item(key: StringName, scene_path: String, parent: Node3D, pos: Vector3, rotation_degrees_value: Vector3) -> void:
	var item: Node3D = (load(scene_path) as PackedScene).instantiate() as Node3D
	item.name = str(key).capitalize().replace(" ", "")
	item.position = pos
	item.rotation_degrees = rotation_degrees_value
	parent.add_child(item)
	ground_items[key] = item as Inspectable


func _stool(parent: Node3D, stool_name: String, pos: Vector3, yaw: float) -> void:
	var stool: Node3D = Node3D.new()
	stool.name = stool_name
	stool.position = pos
	stool.rotation_degrees = Vector3(0.0, yaw, 0.0)
	parent.add_child(stool)
	HouseProps.add_cylinder(stool, "Seat", 0.18, 0.04, Vector3(0.0, 0.46, 0.0), _wood_pale)
	for leg: int in 3:
		var angle: float = TAU * float(leg) / 3.0
		var leg_node: MeshInstance3D = HouseProps.add_cylinder(
			stool, "Leg%d" % leg, 0.02, 0.48, Vector3(cos(angle) * 0.11, 0.23, sin(angle) * 0.11), _wood
		)
		leg_node.rotation = Vector3(-sin(angle) * 0.12, 0.0, cos(angle) * 0.12)
	HouseProps.add_solid(stool, "Solid", Vector3(0.34, 0.48, 0.34), Vector3(0.0, 0.24, 0.0))


## A wooden crate: corner posts and a band of slats at the top and bottom. `solid` adds the collision.
func _crate(parent: Node3D, crate_name: String, size: Vector3, pos: Vector3, yaw: float, solid: bool = true) -> void:
	var crate: Node3D = Node3D.new()
	crate.name = crate_name
	crate.position = pos
	crate.rotation_degrees = Vector3(0.0, yaw, 0.0)
	parent.add_child(crate)
	HouseProps.add_box(crate, "Body", size, Vector3(0.0, size.y * 0.5, 0.0), _wood)
	for post_x: float in [-1.0, 1.0]:
		for post_z: float in [-1.0, 1.0]:
			HouseProps.add_box(
				crate, "Post", Vector3(0.045, size.y + 0.004, 0.045),
				Vector3(post_x * (size.x * 0.5 - 0.02), size.y * 0.5, post_z * (size.z * 0.5 - 0.02)), _wood_pale
			)
	for slat_y: float in [0.05, size.y - 0.05]:
		HouseProps.add_box(crate, "Slat", Vector3(size.x + 0.008, 0.06, size.z + 0.008), Vector3(0.0, slat_y, 0.0), _wood_pale)
	if solid:
		HouseProps.add_solid(crate, "Solid", size, Vector3(0.0, size.y * 0.5, 0.0))


# ============================================================
# THE CONTROL CABIN
# ============================================================

func _build_cabin() -> void:
	var cabin: Node3D = Node3D.new()
	cabin.name = "Cabin"
	add_child(cabin)
	_build_lever_frame(cabin)
	_build_stove(cabin)
	_build_desk(cabin)
	_build_bench(cabin)
	_scatter_glass(cabin)


## The signal box's levers (the model), standing on the floor in front of the windows with the plate towards the room: the file's +X (the operator's
## side) is turned to face -Z and its length runs along X.
func _build_lever_frame(cabin: Node3D) -> void:
	lever_frame = Node3D.new()
	lever_frame.name = "LeverFrame"
	lever_frame.position = LEVER_FRAME
	cabin.add_child(lever_frame)

	var model: Node3D = LEVERS_SCENE.instantiate() as Node3D
	model.name = "Model"
	var turn: Basis = Basis(Vector3.UP, PI * 0.5)
	var centre: Vector3 = LEVERS_BOX.get_center()
	model.transform = Transform3D(turn, -(turn * Vector3(centre.x, LEVERS_BOX.position.y, centre.z)))
	lever_frame.add_child(model)
	# The plate is solid up to knee height; the levers themselves are thin and are not.
	HouseProps.add_solid(lever_frame, "Solid", Vector3(1.9, 0.5, 1.17), Vector3(0.0, 0.25, 0.0))


func _build_stove(cabin: Node3D) -> void:
	var stove: Node3D = Node3D.new()
	stove.name = "Stove"
	stove.position = STOVE_POSITION
	cabin.add_child(stove)
	HouseProps.add_cylinder(stove, "Body", 0.27, 0.72, Vector3(0.0, 0.5, 0.0), _iron)
	HouseProps.add_cylinder(stove, "Top", 0.29, 0.03, Vector3(0.0, 0.875, 0.0), _rust)
	for leg: int in 4:
		var angle: float = TAU * (float(leg) + 0.5) / 4.0
		HouseProps.add_box(stove, "Leg%d" % leg, Vector3(0.05, 0.14, 0.05), Vector3(cos(angle) * 0.2, 0.07, sin(angle) * 0.2), _iron)
	HouseProps.add_box(stove, "Door", Vector3(0.2, 0.22, 0.02), Vector3(0.0, 0.5, 0.265), _rust)
	HouseProps.add_box(stove, "DoorHandle", Vector3(0.02, 0.1, 0.02), Vector3(0.07, 0.5, 0.285), _brass)
	# The pipe up to the ceiling (where the roof's stovepipe takes it on).
	var pipe_height: float = SignalTowerBuilder.STOVE_PIPE_TOP - 0.9
	HouseProps.add_cylinder(stove, "Pipe", 0.075, pipe_height, Vector3(0.0, 0.9 + pipe_height * 0.5, 0.0), _iron)
	HouseProps.add_cylinder(stove, "PipeBand", 0.085, 0.05, Vector3(0.0, 1.6, 0.0), _rust)
	HouseProps.add_solid(stove, "Solid", Vector3(0.56, 0.9, 0.56), Vector3(0.0, 0.45, 0.0))


func _build_desk(cabin: Node3D) -> void:
	var desk: Node3D = Node3D.new()
	desk.name = "Desk"
	desk.position = Vector3(0.4, SignalTowerBuilder.BASE_HEIGHT, -1.68)
	cabin.add_child(desk)
	HouseProps.add_box(desk, "Top", Vector3(1.3, 0.05, 0.6), Vector3(0.0, 0.75, 0.0), _wood)
	for leg_x: float in [-0.6, 0.6]:
		for leg_z: float in [-0.25, 0.25]:
			HouseProps.add_box(desk, "Leg", Vector3(0.06, 0.74, 0.06), Vector3(leg_x, 0.37, leg_z), _wood)
	HouseProps.add_box(desk, "Drawer", Vector3(0.5, 0.14, 0.5), Vector3(0.35, 0.64, 0.0), _wood_pale)
	HouseProps.add_box(desk, "DrawerKnob", Vector3(0.04, 0.02, 0.02), Vector3(0.35, 0.64, 0.26), _brass)
	HouseProps.add_solid(desk, "Solid", Vector3(1.3, 0.8, 0.6), Vector3(0.0, 0.4, 0.0))

	# The telegraph: a brass key on a wooden base with a sounder beside it, and the open log book.
	HouseProps.add_box(desk, "TelegraphBase", Vector3(0.24, 0.03, 0.14), Vector3(-0.4, 0.79, 0.05), _wood_pale)
	HouseProps.add_box(desk, "TelegraphKey", Vector3(0.1, 0.012, 0.02), Vector3(-0.4, 0.82, 0.06), _brass, Vector3(0.0, 0.0, 4.0))
	HouseProps.add_cylinder(desk, "TelegraphKnob", 0.012, 0.02, Vector3(-0.35, 0.84, 0.06), HouseProps.material(Color(0.05, 0.05, 0.05), 0.5))
	HouseProps.add_box(desk, "Sounder", Vector3(0.07, 0.07, 0.05), Vector3(-0.47, 0.84, 0.0), _iron)
	HouseProps.add_box(desk, "LogCover", Vector3(0.34, 0.012, 0.24), Vector3(0.1, 0.781, 0.05), HouseProps.material(Color(0.2, 0.1, 0.07), 0.9), Vector3(0.0, 8.0, 0.0))
	HouseProps.add_box(desk, "LogPages", Vector3(0.3, 0.014, 0.21), Vector3(0.1, 0.789, 0.05), HouseProps.material(HouseProps.PAPER, 0.96), Vector3(0.0, 8.0, 0.0))

	_stool(cabin, "DeskStool", desk.position + Vector3(0.1, 0.0, 0.75), 140.0)


## A plain wooden bench along the +X wall, between the balcony door and the small window.
func _build_bench(cabin: Node3D) -> void:
	var bench: Node3D = Node3D.new()
	bench.name = "Bench"
	bench.position = Vector3(SignalTowerBuilder.ROOM_HALF - 0.15, SignalTowerBuilder.BASE_HEIGHT, 0.45)
	cabin.add_child(bench)
	HouseProps.add_box(bench, "Seat", Vector3(0.42, 0.04, 1.1), Vector3(0.0, 0.42, 0.0), _wood_pale)
	for leg_x: float in [-0.17, 0.17]:
		for leg_z: float in [-0.46, 0.46]:
			HouseProps.add_box(bench, "Leg", Vector3(0.05, 0.4, 0.05), Vector3(leg_x, 0.2, leg_z), _wood)
	HouseProps.add_box(bench, "Stretcher", Vector3(0.04, 0.04, 0.9), Vector3(0.0, 0.14, 0.0), _wood)
	HouseProps.add_solid(bench, "Solid", Vector3(0.42, 0.44, 1.1), Vector3(0.0, 0.22, 0.0))


## Splinters of the broken panes on the floor under the windows.
func _scatter_glass(cabin: Node3D) -> void:
	var shards: Node3D = Node3D.new()
	shards.name = "GlassShards"
	cabin.add_child(shards)
	var reach: float = SignalTowerBuilder.ROOM_HALF - 0.15
	for i: int in 26:
		var wall: int = _rng.randi_range(0, 2)
		var along: float = _rng.randf_range(-1.5, 1.5)
		var out: float = reach - _rng.randf_range(0.0, 0.7)
		var pos: Vector3 = Vector3(along, SignalTowerBuilder.BASE_HEIGHT + 0.006, out)
		if wall == 1:
			pos = Vector3(along, SignalTowerBuilder.BASE_HEIGHT + 0.006, -out)
		elif wall == 2:
			pos = Vector3(-out, SignalTowerBuilder.BASE_HEIGHT + 0.006, along)

		var shard: MeshInstance3D = HouseProps.add_box(
			shards, "Shard%d" % i, Vector3(_rng.randf_range(0.02, 0.09), 0.003, _rng.randf_range(0.02, 0.09)), pos, _glass
		)
		shard.rotation_degrees = Vector3(0.0, _rng.randf_range(0.0, 180.0), 0.0)
