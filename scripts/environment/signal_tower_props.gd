@tool
extends Node3D
class_name SignalTowerProps

## The furniture of the ruined signal tower, built in code from boxes and cylinders (the tower itself is
## `SignalTowerBuilder`, which adds this node as its child `Props`; both share the tower's frame: the
## origin at the middle of the foot, the front door facing +Z).
##
##   Relay room (lower level, floor at y 0.04)  the children's headquarters, in three zones around an open
##       aisle. The one photograph the album needs from this place lies out in the open (no box, nothing to unlock):
##         1. the HQ desk, back left (a makeshift table of two crates and a plank with a drawer under it, two stools, a desk
##            lamp): Scraped Knee lies flat in the middle of the plank, and in the drawer (`DeskDrawer`, which slides out when it
##            is used) lies the note Juliana wrote;
##         2. the wooden bench on the right wall (a daybed with a cushion): Sophia's folded letter on graph paper;
##         3. the low shelf on the back wall: an open tin, with a few of a child's things on the lower board.
##       Also a relay cabinet, pipes, crates and a barrel, all kept out of the aisle.
##   Control cabin (upper level, floor at y 2.8)  the floor frame with five heavy iron interlocking signal
##       levers (the fourth is Lucas's, snapped off), a stove under the stovepipe, a desk with a telegraph,
##       a bench, and four pieces of the town's own eerie history to read (`LORE_ITEMS`): a newspaper
##       clipping on the desk, an internal memo pinned to the lever frame, an operator's journal page on the
##       bench and a health notice taped to the back window.
##
## The inspectable pieces are scenes (the notes, Juliana's note); what they
## look like is built here too, for the kinds below, so that ProceduralProp can fill their `Visual` node.

const HQ_TABLE: Vector3 = Vector3(-1.15, 0.04, -1.3)
const HQ_WALL_Z: float = -1.82
## The middle of the back shelf and of the carved board over it, along the back wall.
const SHELF_X: float = 0.45
const LEVER_FRAME: Vector3 = Vector3(0.0, 2.8, 1.5)
const LEVER_COUNT: int = 5
## Which lever is snapped off (counting from 0 at the left): Lucas's.
const BROKEN_LEVER: int = 3
const STOVE_POSITION: Vector3 = Vector3(-1.4, 2.8, -0.9)

const JULIANA_NOTE_SCENE_PATH: String = "res://scenes/objects/signal_tower/tower_juliana_note.tscn"

const KIND_DOOR_NOTE: StringName = &"tower_door_note"
const KIND_JULIANA_NOTE: StringName = &"juliana_note"
const KIND_SOPHIA_NOTE: StringName = &"sophia_note"
const KIND_NEWS: StringName = &"tower_news"
const KIND_MEMO: StringName = &"tower_memo"
const KIND_JOURNAL: StringName = &"tower_journal"
const KIND_NOTICE: StringName = &"tower_notice"

## The four lore documents of the control cabin: scene, and the node's name in `lore_items`.
const LORE_ITEMS: Dictionary = {
	&"news": "res://scenes/objects/signal_tower/tower_news.tscn",
	&"memo": "res://scenes/objects/signal_tower/tower_memo.tscn",
	&"journal": "res://scenes/objects/signal_tower/tower_journal.tscn",
	&"notice": "res://scenes/objects/signal_tower/tower_notice.tscn",
}

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
## The lore documents by key (`news`, `memo`, `journal`, `notice`), as Inspectables in the game.
var lore_items: Dictionary = {}

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
	return kind in [KIND_DOOR_NOTE, KIND_NEWS, KIND_MEMO, KIND_JOURNAL, KIND_NOTICE, KIND_JULIANA_NOTE, KIND_SOPHIA_NOTE]


static func build(kind: StringName, root: Node3D) -> void:
	match kind:
		KIND_DOOR_NOTE:
			_build_note(root, true)
		KIND_JULIANA_NOTE:
			_build_juliana_note(root)
		KIND_SOPHIA_NOTE:
			_build_graph_paper(root)
		KIND_NEWS, KIND_MEMO, KIND_JOURNAL, KIND_NOTICE:
			_build_document(root, kind)
		_:
			push_warning("SignalTowerProps: unknown prop kind '%s'." % kind)


## A page torn from a school notebook, facing +Z, centred on the origin. The words are not drawn on it (the
## player reads them as an overlay); a few lines of a child's pencil stand for them. Pinned, it hangs from
## a rusty nail by its top edge; unpinned, it is creased down the middle and stained by damp.
static func _build_note(root: Node3D, pinned: bool, tint: Color = HouseProps.PAPER) -> void:
	var paper: MeshInstance3D = HouseProps.add_box(
		root, "Paper", Vector3(0.11, 0.08, 0.0015), Vector3.ZERO, HouseProps.material(tint, 0.96),
		Vector3(0.0, 0.0, 3.0 if pinned else 0.0)
	)
	var pencil: StandardMaterial3D = HouseProps.material(Color(0.22, 0.22, 0.24), 1.0)
	var widths: Array[float] = [0.088, 0.092, 0.07, 0.09, 0.082, 0.04]
	for i: int in widths.size():
		var line_x: float = -0.049 + widths[i] * 0.5 + (0.0 if i < widths.size() - 1 else 0.05)
		HouseProps.add_box(
			paper, "Line%d" % i, Vector3(widths[i], 0.0016, 0.0004),
			Vector3(line_x, 0.026 - 0.0105 * float(i), 0.001), pencil
		)

	if pinned:
		var rust: StandardMaterial3D = HouseProps.material(Color(0.34, 0.17, 0.08), 0.85, 0.5)
		HouseProps.add_cylinder(paper, "Nail", 0.0055, 0.003, Vector3(0.0, 0.034, 0.0022), rust, Vector3(90.0, 0.0, 0.0))
		HouseProps.add_box(
			paper, "TornEdge", Vector3(0.11, 0.004, 0.0004), Vector3(0.0, -0.0398, 0.0009),
			HouseProps.material(Color(0.6, 0.56, 0.46), 1.0)
		)
	else:
		HouseProps.add_box(paper, "Crease", Vector3(0.0012, 0.08, 0.0004), Vector3(0.0, 0.0, 0.0009), HouseProps.material(Color(0.6, 0.57, 0.48), 1.0))
		HouseProps.add_box(paper, "Damp", Vector3(0.05, 0.034, 0.0003), Vector3(0.026, -0.018, 0.0008), HouseProps.material(Color(0.5, 0.42, 0.3), 1.0))


## One of the cabin's lore documents, facing +Z, centred on the origin. As with the notes, the words are not
## drawn on it (the player reads them as an overlay): stand-ins for the print and the handwriting are a few
## dark bars. A newspaper clipping is grey newsprint with a headline bar and two columns; the memo is white
## with a letterhead and typed lines; the journal page is yellowed, ruled and written in ink; the health
## notice has a heavy header band and a tape strip at each top corner.
static func _build_document(root: Node3D, kind: StringName) -> void:
	var paper_color: Color = HouseProps.NEWSPRINT
	var ink_color: Color = Color(0.16, 0.16, 0.15)
	var size: Vector2 = Vector2(0.12, 0.09)
	match kind:
		KIND_MEMO:
			paper_color = Color(0.86, 0.85, 0.8)
			size = Vector2(0.1, 0.13)
		KIND_JOURNAL:
			paper_color = Color(0.78, 0.7, 0.5)
			ink_color = HouseProps.INK_BLUE
			size = Vector2(0.11, 0.15)
		KIND_NOTICE:
			paper_color = Color(0.82, 0.8, 0.7)
			size = Vector2(0.11, 0.15)

	var paper: MeshInstance3D = HouseProps.add_box(
		root, "Paper", Vector3(size.x, size.y, 0.0015), Vector3.ZERO, HouseProps.material(paper_color, 0.96)
	)
	var ink: StandardMaterial3D = HouseProps.material(ink_color, 1.0)
	var top: float = size.y * 0.5 - 0.012
	var left: float = -size.x * 0.5 + 0.008
	var inner_width: float = size.x - 0.016
	match kind:
		KIND_NEWS:
			HouseProps.add_box(paper, "Headline", Vector3(inner_width, 0.014, 0.0004), Vector3(0.0, top, 0.001), ink)
			for column: int in 2:
				for row: int in 5:
					HouseProps.add_box(
						paper, "Print%d_%d" % [column, row], Vector3(inner_width * 0.46, 0.0036, 0.0004),
						Vector3(left + inner_width * (0.23 + 0.54 * float(column)), top - 0.026 - 0.0085 * float(row), 0.001), ink
					)
			# a torn edge
			HouseProps.add_box(paper, "Torn", Vector3(0.03, 0.004, 0.0004), Vector3(0.03, -size.y * 0.5 + 0.002, 0.001), HouseProps.material(Color(0.55, 0.52, 0.42), 1.0))
		KIND_MEMO:
			HouseProps.add_box(paper, "Letterhead", Vector3(inner_width, 0.012, 0.0004), Vector3(0.0, top, 0.001), ink)
			HouseProps.add_box(paper, "Rule", Vector3(inner_width, 0.0012, 0.0004), Vector3(0.0, top - 0.012, 0.001), ink)
			for row: int in 8:
				var width: float = inner_width * (1.0 if row < 7 else 0.5)
				HouseProps.add_box(
					paper, "Typed%d" % row, Vector3(width, 0.0028, 0.0004),
					Vector3(left + width * 0.5, top - 0.03 - 0.0105 * float(row), 0.001), ink
				)
			HouseProps.add_box(paper, "Stamp", Vector3(0.026, 0.012, 0.0004), Vector3(0.026, -size.y * 0.5 + 0.016, 0.001), HouseProps.material(HouseProps.INK_RED, 1.0), Vector3(0.0, 0.0, 10.0))
		KIND_JOURNAL:
			var ruling: StandardMaterial3D = HouseProps.material(Color(0.55, 0.62, 0.7), 1.0)
			for row: int in 11:
				var line_y: float = top - 0.006 - 0.0115 * float(row)
				HouseProps.add_box(paper, "Ruling%d" % row, Vector3(inner_width, 0.0006, 0.0003), Vector3(0.0, line_y - 0.004, 0.0009), ruling)
				var width: float = inner_width * (0.95 - 0.12 * float(row % 3)) if row < 10 else inner_width * 0.4
				HouseProps.add_box(paper, "Hand%d" % row, Vector3(width, 0.0026, 0.0004), Vector3(left + width * 0.5, line_y, 0.001), ink)
			HouseProps.add_box(paper, "Margin", Vector3(0.0008, size.y - 0.01, 0.0003), Vector3(left + 0.012, 0.0, 0.0009), HouseProps.material(Color(0.7, 0.3, 0.3), 1.0))
			# a coffee ring
			HouseProps.add_ring(paper, "Ring", 0.012, 0.015, Vector3(0.03, -0.04, 0.001), HouseProps.material(Color(0.4, 0.28, 0.14), 1.0))
		KIND_NOTICE:
			HouseProps.add_box(paper, "Header", Vector3(inner_width, 0.026, 0.0004), Vector3(0.0, top - 0.004, 0.001), ink)
			HouseProps.add_box(paper, "Subhead", Vector3(inner_width * 0.7, 0.006, 0.0004), Vector3(0.0, top - 0.026, 0.001), ink)
			for row: int in 8:
				var width: float = inner_width * (0.95 if row < 7 else 0.55)
				HouseProps.add_box(
					paper, "Print%d" % row, Vector3(width, 0.003, 0.0004),
					Vector3(left + width * 0.5, top - 0.048 - 0.0105 * float(row), 0.001), ink
				)
			var tape: StandardMaterial3D = HouseProps.material(Color(0.78, 0.74, 0.55), 0.6)
			for side: float in [-1.0, 1.0]:
				HouseProps.add_box(paper, "Tape", Vector3(0.024, 0.011, 0.0007), Vector3(side * (size.x * 0.5 - 0.006), size.y * 0.5 - 0.004, 0.0012), tape, Vector3(0.0, 0.0, -side * 38.0))


## The note Juliana wrote, facing +Z, centred on the origin: a page torn from a school notebook (cream, ruled with a few lines of her pencil, a
## crease down the middle where it was folded once), her little face with a fringe drawn in the top corner. The words are not drawn on it (the
## player reads them as an overlay).
static func _build_juliana_note(root: Node3D) -> void:
	_build_note(root, false, Color(0.86, 0.82, 0.68))
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
	var inner: float = SignalTowerBuilder.BASE_SIZE * 0.5 - SignalTowerBuilder.BASE_WALL

	# The relay cabinet against the right wall, in the back corner, its door hanging open on the coils inside.
	# It faces the room (-X).
	var cabinet: Node3D = Node3D.new()
	cabinet.name = "RelayCabinet"
	cabinet.position = Vector3(inner - 0.24, floor_y, -1.2)
	cabinet.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	room.add_child(cabinet)
	HouseProps.add_box(cabinet, "Back", Vector3(1.1, 1.7, 0.02), Vector3(0.0, 0.85, -0.22), _iron)
	HouseProps.add_box(cabinet, "SideL", Vector3(0.02, 1.7, 0.46), Vector3(-0.55, 0.85, 0.0), _iron)
	HouseProps.add_box(cabinet, "SideR", Vector3(0.02, 1.7, 0.46), Vector3(0.55, 0.85, 0.0), _iron)
	HouseProps.add_box(cabinet, "Top", Vector3(1.12, 0.03, 0.48), Vector3(0.0, 1.7, 0.0), _rust)
	for shelf: int in 4:
		var shelf_y: float = 0.1 + 0.52 * float(shelf)
		HouseProps.add_box(cabinet, "Shelf%d" % shelf, Vector3(1.08, 0.02, 0.44), Vector3(0.0, shelf_y, 0.0), _iron)
		if shelf == 3:
			continue

		for coil: int in 5:
			var coil_x: float = -0.4 + 0.2 * float(coil)
			HouseProps.add_cylinder(cabinet, "Coil%d_%d" % [shelf, coil], 0.06, 0.2, Vector3(coil_x, shelf_y + 0.12, 0.0), HouseProps.material(Color(0.5, 0.26, 0.12), 0.45, 0.8))
			HouseProps.add_cylinder(cabinet, "Core%d_%d" % [shelf, coil], 0.02, 0.26, Vector3(coil_x, shelf_y + 0.14, 0.0), _iron)
	var cabinet_door: Node3D = Node3D.new()
	cabinet_door.name = "CabinetDoor"
	cabinet_door.position = Vector3(-0.55, 0.0, 0.23)
	cabinet_door.rotation_degrees = Vector3(0.0, -105.0, 0.0)
	cabinet.add_child(cabinet_door)
	HouseProps.add_box(cabinet_door, "Leaf", Vector3(0.55, 1.68, 0.02), Vector3(0.275, 0.85, 0.0), _rust)
	HouseProps.add_solid(cabinet, "Solid", Vector3(1.1, 1.7, 0.46), Vector3(0.0, 0.85, 0.0))

	# Conduit along the back wall under the deck, with a drop to the floor between the window and the cabinet.
	var pipe_y: float = 2.35
	HouseProps.add_cylinder(room, "ConduitBack", 0.035, inner * 2.0 - 0.1, Vector3(0.0, pipe_y, -inner + 0.06), _iron, Vector3(0.0, 0.0, 90.0))
	HouseProps.add_cylinder(room, "ConduitDrop", 0.035, pipe_y - floor_y, Vector3(1.27, floor_y + (pipe_y - floor_y) * 0.5, -inner + 0.06), _iron)
	for bracket_x: float in [-1.4, -0.4, 0.6, 1.4]:
		HouseProps.add_box(room, "Bracket", Vector3(0.04, 0.05, 0.05), Vector3(bracket_x, pipe_y, -inner + 0.03), _rust)

	# Crates and a barrel in the front left corner, out of the aisle between the door and the zones.
	_crate(room, "CrateLarge", Vector3(0.55, 0.5, 0.45), Vector3(-inner + 0.4, floor_y, inner - 0.35), 12.0)
	_crate(room, "CrateSmall", Vector3(0.42, 0.38, 0.38), Vector3(-inner + 0.4, floor_y + 0.5, inner - 0.35), -8.0, false)
	HouseProps.add_cylinder(room, "Barrel", 0.26, 0.8, Vector3(-inner + 0.3, floor_y + 0.4, inner - 1.0), _wood)
	for band_y: float in [0.2, 0.6]:
		HouseProps.add_cylinder(room, "BarrelBand", 0.268, 0.03, Vector3(-inner + 0.3, floor_y + band_y, inner - 1.0), _rust)
	HouseProps.add_solid(room, "BarrelSolid", Vector3(0.5, 0.8, 0.5), Vector3(-inner + 0.3, floor_y + 0.4, inner - 1.0))

	# A gap in the floorboards by the door: two planks snapped, and black under them.
	HouseProps.add_box(room, "FloorGap", Vector3(0.5, 0.002, 0.16), Vector3(0.5, floor_y + 0.0012, 0.9), HouseProps.black_material(), Vector3(0.0, 14.0, 0.0))
	HouseProps.add_box(room, "BrokenPlankA", Vector3(0.42, 0.025, 0.1), Vector3(0.18, floor_y + 0.02, 1.02), _wood, Vector3(6.0, 14.0, 8.0))
	HouseProps.add_box(room, "BrokenPlankB", Vector3(0.3, 0.025, 0.1), Vector3(0.78, floor_y + 0.012, 0.8), _wood, Vector3(0.0, 24.0, -6.0))


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


## Zone 1, the HQ desk in the back left corner: a table of two crates and a plank (the plank's top is 0.56 m over the floor) with a drawer under
## the plank, two stools and a desk lamp. The Scraped Knee lies flat in the middle of the plank; in the drawer lies the note Juliana wrote.
func _build_desk_zone(corner: Node3D) -> void:
	var table: Node3D = Node3D.new()
	table.name = "CrateTable"
	table.position = HQ_TABLE
	table.rotation_degrees = Vector3(0.0, 6.0, 0.0)
	corner.add_child(table)
	# (The crates stand a little apart: the drawer is between them, under the plank.)
	_crate(table, "CrateLeft", Vector3(0.4, 0.52, 0.5), Vector3(-0.42, 0.0, 0.0), 0.0)
	_crate(table, "CrateRight", Vector3(0.4, 0.52, 0.5), Vector3(0.42, 0.0, 0.0), 0.0)
	HouseProps.add_box(table, "Plank", Vector3(1.24, 0.04, 0.66), Vector3(0.0, 0.54, 0.0), _wood_pale)
	HouseProps.add_solid(table, "Solid", Vector3(1.24, 0.58, 0.66), Vector3(0.0, 0.29, 0.0))
	HouseProps.add_cylinder(table, "Pencil", 0.005, 0.15, Vector3(0.2, 0.564, 0.2), HouseProps.material(Color(0.7, 0.55, 0.15), 0.6), Vector3(90.0, 40.0, 0.0))

	# The desk lamp, back left on the plank: a round iron foot, a thin stem, an arm and a green enamel shade.
	desk_lamp = Node3D.new()
	desk_lamp.name = "DeskLamp"
	desk_lamp.position = Vector3(-0.4, 0.56, -0.15)
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
	_place_photo("photo_childhood", "res://scenes/objects/photo_childhood.tscn", table, Vector3(0.0, 0.5635, 0.02), Vector3(-90.0, 7.0, 0.0))

	# The drawer under the plank, between the crates: its front flush with the plank's front edge. Juliana's note lies in it, near the front, so that it
	# shows when the drawer is out.
	desk_drawer = DeskDrawer.build(Vector3(0.0, 0.452, 0.332), 0.42, 0.11, 0.46, _wood, _wood_pale, _brass, _wood)
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
	var inner: float = SignalTowerBuilder.BASE_SIZE * 0.5 - SignalTowerBuilder.BASE_WALL
	var daybed: Node3D = Node3D.new()
	daybed.name = "Daybed"
	daybed.position = Vector3(inner - 0.3, SignalTowerBuilder.FLOOR_TOP, 0.45)
	corner.add_child(daybed)
	HouseProps.add_box(daybed, "FrameLeft", Vector3(0.04, 0.12, 1.8), Vector3(-0.23, 0.34, 0.0), _wood)
	HouseProps.add_box(daybed, "FrameRight", Vector3(0.04, 0.12, 1.8), Vector3(0.23, 0.34, 0.0), _wood)
	HouseProps.add_box(daybed, "FrameEndBack", Vector3(0.5, 0.12, 0.04), Vector3(0.0, 0.34, -0.9), _wood)
	HouseProps.add_box(daybed, "FrameEndFront", Vector3(0.5, 0.12, 0.04), Vector3(0.0, 0.34, 0.9), _wood)
	for leg_x: float in [-0.22, 0.22]:
		for leg_z: float in [-0.88, 0.88]:
			HouseProps.add_box(daybed, "Leg", Vector3(0.06, 0.34, 0.06), Vector3(leg_x, 0.17, leg_z), _wood)
	var fabric: StandardMaterial3D = JunctionProps.weathered(Color(0.4, 0.3, 0.26), 4.0, 1.0)
	HouseProps.add_box(daybed, "Cushion", Vector3(0.46, 0.09, 1.76), Vector3(0.0, 0.445, 0.0), fabric)
	var bolster: MeshInstance3D = HouseProps.add_cylinder(daybed, "Bolster", 0.08, 0.44, Vector3(0.0, 0.54, -0.8), fabric, Vector3(0.0, 0.0, 90.0))
	bolster.name = "Bolster"
	HouseProps.add_solid(daybed, "Solid", Vector3(0.5, 0.49, 1.8), Vector3(0.0, 0.245, 0.0))

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
	HouseProps.add_cylinder(stool, "Seat", 0.17, 0.04, Vector3(0.0, 0.4, 0.0), _wood_pale)
	for leg: int in 3:
		var angle: float = TAU * float(leg) / 3.0
		var leg_node: MeshInstance3D = HouseProps.add_cylinder(
			stool, "Leg%d" % leg, 0.02, 0.42, Vector3(cos(angle) * 0.1, 0.2, sin(angle) * 0.1), _wood
		)
		leg_node.rotation = Vector3(-sin(angle) * 0.12, 0.0, cos(angle) * 0.12)
	HouseProps.add_solid(stool, "Solid", Vector3(0.32, 0.42, 0.32), Vector3(0.0, 0.21, 0.0))


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
	_place_lore(cabin)


## The floor frame with its heavy iron interlocking levers, in front of the windows. Lucas's lever (the
## fourth) is snapped off at the knee, and the rest of it lies on the floor.
func _build_lever_frame(cabin: Node3D) -> void:
	lever_frame = Node3D.new()
	lever_frame.name = "LeverFrame"
	lever_frame.position = LEVER_FRAME
	cabin.add_child(lever_frame)

	HouseProps.add_box(lever_frame, "Base", Vector3(2.3, 0.1, 0.36), Vector3(0.0, 0.05, 0.0), _iron)
	for end_x: float in [-1.12, 1.12]:
		HouseProps.add_box(lever_frame, "Upright", Vector3(0.09, 0.62, 0.3), Vector3(end_x, 0.31, 0.0), _iron)
	HouseProps.add_box(lever_frame, "Quadrant", Vector3(2.2, 0.05, 0.05), Vector3(0.0, 0.58, 0.12), _iron)
	# The interlocking bar behind the levers, with a tappet at each of them.
	HouseProps.add_cylinder(lever_frame, "InterlockBar", 0.02, 2.2, Vector3(0.0, 0.3, 0.13), _rust, Vector3(0.0, 0.0, 90.0))
	HouseProps.add_solid(lever_frame, "Solid", Vector3(2.3, 0.5, 0.36), Vector3(0.0, 0.25, 0.0))

	var tips: Array[Color] = [
		Color(0.55, 0.08, 0.06), Color(0.62, 0.5, 0.08), Color(0.08, 0.08, 0.09), Color(0.1, 0.2, 0.5), Color(0.55, 0.08, 0.06),
	]
	var tilt_degrees: Array[float] = [0.0, -17.0, -4.0, -28.0, -21.0]
	for i: int in LEVER_COUNT:
		var x: float = -0.8 + 0.4 * float(i)
		HouseProps.add_box(lever_frame, "Tappet%d" % i, Vector3(0.05, 0.07, 0.04), Vector3(x, 0.3, 0.13), _iron)
		HouseProps.add_cylinder(lever_frame, "Pivot%d" % i, 0.045, 0.1, Vector3(x, 0.22, 0.0), _iron, Vector3(0.0, 0.0, 90.0))

		var arm: Node3D = Node3D.new()
		arm.name = "Lever%d" % i
		arm.position = Vector3(x, 0.22, 0.0)
		arm.rotation_degrees = Vector3(tilt_degrees[i], 0.0, 0.0)
		lever_frame.add_child(arm)

		var broken: bool = i == BROKEN_LEVER
		var arm_length: float = 0.4 if broken else 1.05
		HouseProps.add_box(arm, "Arm", Vector3(0.035, arm_length, 0.022), Vector3(0.0, arm_length * 0.5, 0.0), _iron)
		HouseProps.add_cylinder(arm, "Weight", 0.05, 0.06, Vector3(0.0, -0.06, 0.0), _iron, Vector3(0.0, 0.0, 90.0))
		HouseProps.add_box(arm, "CatchRod", Vector3(0.012, 0.5 if not broken else 0.3, 0.012), Vector3(0.0, 0.32, 0.022), _brass)
		if broken:
			# The snapped end, jagged and bright where the iron gave.
			HouseProps.add_box(arm, "Stump", Vector3(0.04, 0.05, 0.026), Vector3(0.005, arm_length + 0.01, 0.0), _rust, Vector3(0.0, 0.0, 22.0))
		else:
			HouseProps.add_box(arm, "Grip", Vector3(0.05, 0.22, 0.04), Vector3(0.0, arm_length - 0.08, 0.0), HouseProps.material(tips[i], 0.7))

		# The lever's number on a brass plate on the frame.
		var label: Label3D = Label3D.new()
		label.name = "Number%d" % i
		label.text = str(i + 1)
		label.font_size = 40
		label.pixel_size = 0.0012
		label.modulate = Color(0.12, 0.09, 0.04)
		label.shaded = true
		label.double_sided = false
		label.position = Vector3(x, 0.103, 0.12)
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		lever_frame.add_child(label)

	# The top of Lucas's lever, on the floor in front of the frame.
	var fallen: Node3D = Node3D.new()
	fallen.name = "FallenLever"
	fallen.position = Vector3(0.75, 0.025, -0.75)
	fallen.rotation_degrees = Vector3(0.0, 40.0, 0.0)
	lever_frame.add_child(fallen)
	HouseProps.add_box(fallen, "Arm", Vector3(0.035, 0.022, 0.7), Vector3(0.0, 0.0, 0.0), _iron)
	HouseProps.add_box(fallen, "Grip", Vector3(0.05, 0.04, 0.2), Vector3(0.0, 0.01, 0.38), HouseProps.material(tips[BROKEN_LEVER], 0.7))
	HouseProps.add_box(fallen, "Break", Vector3(0.04, 0.026, 0.05), Vector3(0.0, 0.0, -0.36), _rust, Vector3(0.0, 18.0, 0.0))


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
	var pipe_height: float = SignalTowerBuilder.CABIN_HEIGHT - 0.9
	HouseProps.add_cylinder(stove, "Pipe", 0.075, pipe_height, Vector3(0.0, 0.9 + pipe_height * 0.5, 0.0), _iron)
	HouseProps.add_cylinder(stove, "PipeBand", 0.085, 0.05, Vector3(0.0, 1.6, 0.0), _rust)
	HouseProps.add_solid(stove, "Solid", Vector3(0.56, 0.9, 0.56), Vector3(0.0, 0.45, 0.0))


func _build_desk(cabin: Node3D) -> void:
	var desk: Node3D = Node3D.new()
	desk.name = "Desk"
	desk.position = Vector3(0.4, 2.8, -1.72)
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
	bench.position = Vector3(1.85, 2.8, 0.35)
	cabin.add_child(bench)
	HouseProps.add_box(bench, "Seat", Vector3(0.42, 0.04, 1.1), Vector3(0.0, 0.42, 0.0), _wood_pale)
	for leg_x: float in [-0.17, 0.17]:
		for leg_z: float in [-0.46, 0.46]:
			HouseProps.add_box(bench, "Leg", Vector3(0.05, 0.4, 0.05), Vector3(leg_x, 0.2, leg_z), _wood)
	HouseProps.add_box(bench, "Stretcher", Vector3(0.04, 0.04, 0.9), Vector3(0.0, 0.14, 0.0), _wood)
	HouseProps.add_solid(bench, "Solid", Vector3(0.42, 0.44, 1.1), Vector3(0.0, 0.22, 0.0))


## The four lore documents: where each one lies or hangs (see the header).
func _place_lore(cabin: Node3D) -> void:
	var desk: Node3D = cabin.get_node("Desk") as Node3D
	var bench: Node3D = cabin.get_node("Bench") as Node3D

	# The clipping lies flat on the desk, to the right of the log book.
	_add_lore(&"news", desk, Vector3(0.49, 0.7765, 0.08), Vector3(-90.0, 14.0, 0.0))

	# The memo is pinned to a small wooden board screwed to the right upright of the lever frame, on the
	# operator's side (the frame's -Z face), above the frame's solid base so nothing hides it.
	HouseProps.add_box(lever_frame, "SignalBoard", Vector3(0.3, 0.3, 0.02), Vector3(1.12, 0.52, -0.16), _wood_pale)
	HouseProps.add_cylinder(lever_frame, "BoardPin", 0.005, 0.004, Vector3(1.12, 0.6, -0.1735), _rust, Vector3(90.0, 0.0, 0.0))
	_add_lore(&"memo", lever_frame, Vector3(1.12, 0.52, -0.1735), Vector3(0.0, 180.0, 0.0))

	# The journal page rests on the seat of the bench, half over its edge.
	_add_lore(&"journal", bench, Vector3(-0.2, 0.4415, 0.05), Vector3(-90.0, 18.0, 0.0))

	# The health notice is taped to the centre mullion of the back window, facing into the room.
	_add_lore(&"notice", cabin, Vector3(0.0, 4.62, -2.1), Vector3.ZERO)


func _add_lore(key: StringName, parent: Node3D, pos: Vector3, rotation_degrees_value: Vector3) -> void:
	# (A plain node first: in the editor the scripts of instanced scenes are placeholders.)
	var item: Node3D = (load(str(LORE_ITEMS[key])) as PackedScene).instantiate() as Node3D
	item.name = "Lore%s" % str(key).capitalize()
	item.position = pos
	item.rotation_degrees = rotation_degrees_value
	parent.add_child(item)
	lore_items[key] = item as Inspectable


## Splinters of the broken panes on the floor under the windows.
func _scatter_glass(cabin: Node3D) -> void:
	var shards: Node3D = Node3D.new()
	shards.name = "GlassShards"
	cabin.add_child(shards)
	var reach: float = SignalTowerBuilder.CABIN_SIZE * 0.5 - SignalTowerBuilder.CABIN_WALL - 0.15
	for i: int in 26:
		var wall: int = _rng.randi_range(0, 2)
		var along: float = _rng.randf_range(-1.5, 1.5)
		var out: float = reach - _rng.randf_range(0.0, 0.7)
		var pos: Vector3 = Vector3(along, 2.806, out)
		if wall == 1:
			pos = Vector3(along, 2.806, -out)
		elif wall == 2:
			pos = Vector3(-out, 2.806, along)

		var shard: MeshInstance3D = HouseProps.add_box(
			shards, "Shard%d" % i, Vector3(_rng.randf_range(0.02, 0.09), 0.003, _rng.randf_range(0.02, 0.09)), pos, _glass
		)
		shard.rotation_degrees = Vector3(0.0, _rng.randf_range(0.0, 180.0), 0.0)
