class_name HouseProps
extends RefCounted

## Stand-in models for the unfinished house, built in code from primitives and
## CSG so the scene can be played before real art exists. `build()` fills a node
## with the model for a `kind`; ProceduralProp calls it for every prop.
##
## Inspectable props (notes, jar, key, diary...) are built facing +Z with +Y up
## and centred on the origin, which is how the inspect view shows them. Written
## text is a Label3D (shaded, so it never glows in the dark) holding a
## localization key.

const PAPER: Color = Color(0.8, 0.76, 0.64)
const NEWSPRINT: Color = Color(0.76, 0.72, 0.57)
const INK_DARK: Color = Color(0.12, 0.1, 0.08)
const INK_BLUE: Color = Color(0.1, 0.18, 0.55)
const INK_RED: Color = Color(0.62, 0.1, 0.08)
const BRASS: Color = Color(0.58, 0.44, 0.15)
const PINE: Color = Color(0.5, 0.38, 0.22)
const PINE_DARK: Color = Color(0.3, 0.21, 0.12)


static func build(kind: StringName, root: Node3D) -> void:
	match kind:
		&"note_capsule":
			_build_note_capsule(root)
		&"kitchen_recipe":
			_build_kitchen_recipe(root)
		&"pantry_note":
			_build_pantry_note(root)
		&"pantry_jar":
			_build_pantry_jar(root)
		&"tin_can":
			_build_tin_can(root)
		&"sack":
			_build_sack(root)
		&"lucas_diary":
			_build_lucas_diary(root)
		&"house_advertisement":
			_build_house_advertisement(root)
		&"bus_ticket_sophia":
			_build_bus_ticket(root, "BUS_TICKET_PASSENGER_SOPHIA", "BUS_TICKET_NAME_SOPHIA")
		&"bus_ticket_unclaimed":
			_build_bus_ticket(root, "BUS_TICKET_PASSENGER", "BUS_TICKET_IF_YOU_WANT")
		&"time_capsule":
			_build_time_capsule(root)
		&"crate":
			_build_crate(root)
		&"kitchen_sink":
			_build_kitchen_sink(root)
		&"chalk_outline":
			_build_chalk_outline(root)
		&"nightstand":
			_build_nightstand(root)
		&"postcard":
			_build_postcard(root)
		&"pantry_shelves":
			_build_pantry_shelves(root)
		&"kitchen_counter":
			_build_kitchen_counter(root)
		&"pantry_lamp":
			_build_pantry_lamp(root)
		&"bed":
			_build_bed(root)
		&"memory_bedding":
			_build_memory_bedding(root)
		&"memory_chair":
			_build_memory_chair(root)
		&"memory_cups":
			_build_memory_cups(root)
		&"bedside_lamp":
			_build_bedside_lamp(root)
		&"standing_silhouette":
			_build_standing_silhouette(root)
		_:
			push_warning("HouseProps: unknown prop kind '%s'." % kind)


# ============================================================
# BUILDING BLOCKS
# ============================================================

static func material(
	color: Color,
	roughness: float = 0.9,
	metallic: float = 0.0
) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	return result


static func glass_material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = material(color, 0.06, 0.0)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


static func black_material() -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = Color.BLACK
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


static func add_box(
	parent: Node,
	node_name: String,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, node_name, mesh, pos, mat, rot)


static func add_cylinder(
	parent: Node,
	node_name: String,
	radius: float,
	height: float,
	pos: Vector3,
	mat: Material,
	rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _add_mesh(parent, node_name, mesh, pos, mat, rot)


## A ring lying in the XY plane (facing +Z) unless rotated.
static func add_ring(
	parent: Node,
	node_name: String,
	inner_radius: float,
	outer_radius: float,
	pos: Vector3,
	mat: Material
) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	return _add_mesh(parent, node_name, mesh, pos, mat, Vector3(90.0, 0.0, 0.0))


## A hand-drawn rectangle outline of four thin strips, in the XY plane.
static func add_frame(
	parent: Node,
	node_name: String,
	size: Vector2,
	pos: Vector3,
	thickness: float,
	mat: Material,
	tilt_degrees: float = 0.0
) -> Node3D:
	var frame: Node3D = Node3D.new()
	frame.name = node_name
	frame.position = pos
	frame.rotation_degrees = Vector3(0.0, 0.0, tilt_degrees)
	parent.add_child(frame)

	add_box(frame, "Top", Vector3(size.x, thickness, thickness), Vector3(0.0, size.y * 0.5, 0.0), mat)
	add_box(frame, "Bottom", Vector3(size.x, thickness, thickness), Vector3(0.0, -size.y * 0.5, 0.0), mat)
	add_box(frame, "Left", Vector3(thickness, size.y, thickness), Vector3(-size.x * 0.5, 0.0, 0.0), mat)
	add_box(frame, "Right", Vector3(thickness, size.y, thickness), Vector3(size.x * 0.5, 0.0, 0.0), mat)
	return frame


## Written text. Left aligned from its top-left corner, or centred on `pos`.
static func add_text(
	parent: Node,
	node_name: String,
	key: String,
	pos: Vector3,
	font_size: int,
	pixel_size: float,
	color: Color,
	width_pixels: float = 0.0,
	centered: bool = false,
	rot: Vector3 = Vector3.ZERO
) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = node_name
	label.text = key
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.position = pos
	label.rotation_degrees = rot

	if width_pixels > 0.0:
		label.width = width_pixels
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	parent.add_child(label)
	return label


## A solid box for the player to bump into. Not visible.
static func add_solid(
	parent: Node,
	node_name: String,
	size: Vector3,
	pos: Vector3
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


static func _add_mesh(
	parent: Node,
	node_name: String,
	mesh: Mesh,
	pos: Vector3,
	mat: Material,
	rot: Vector3
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	instance.rotation_degrees = rot
	parent.add_child(instance)
	return instance


## A sheet of paper, `size` wide and tall, a millimetre and a half thick.
static func _add_paper(
	parent: Node,
	node_name: String,
	size: Vector2,
	pos: Vector3,
	color: Color,
	rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	return add_box(
		parent,
		node_name,
		Vector3(size.x, size.y, 0.0015),
		pos,
		material(color, 0.96),
		rot
	)


static func _add_tape(
	parent: Node,
	pos: Vector3,
	size: Vector2,
	tilt_degrees: float
) -> void:
	var tape_color: Color = Color(0.86, 0.8, 0.58, 0.55)
	var tape: StandardMaterial3D = material(tape_color, 0.5)
	tape.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_box(
		parent,
		"Tape",
		Vector3(size.x, size.y, 0.0006),
		pos,
		tape,
		Vector3(0.0, 0.0, tilt_degrees)
	)


# ============================================================
# NOTES AND PAPERS
# ============================================================

static func _build_note_capsule(root: Node3D) -> void:
	_add_paper(root, "Paper", Vector2(0.16, 0.13), Vector3.ZERO, PAPER)
	add_paragraphs(
		root, "Text", "NOTE_CAPSULE_TEXT",
		Vector3(-0.072, 0.057, 0.0009), 22, 0.00025, INK_DARK, 576.0
	)
	_add_tape(root, Vector3(0.045, 0.063, 0.0012), Vector2(0.04, 0.015), -8.0)


static func _build_kitchen_recipe(root: Node3D) -> void:
	var grease: StandardMaterial3D = material(Color(0.45, 0.3, 0.14, 0.2), 0.6)
	grease.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	add_box(
		root, "Wrapper", Vector3(0.27, 0.21, 0.003), Vector3.ZERO,
		material(Color(0.42, 0.3, 0.18), 0.95)
	)
	add_box(
		root, "Fold", Vector3(0.27, 0.06, 0.002), Vector3(0.0, 0.075, 0.0012),
		material(Color(0.38, 0.27, 0.16), 0.95), Vector3(0.0, 0.0, 1.5)
	)

	var sheet: MeshInstance3D = _add_paper(
		root, "Sheet", Vector2(0.21, 0.175), Vector3(-0.025, 0.0, 0.003),
		Color(0.82, 0.78, 0.66), Vector3(0.0, 0.0, 2.0)
	)
	add_paragraphs(
		sheet, "Text", "RECIPE_TEXT",
		Vector3(-0.095, 0.08, 0.0009), 21, 0.00025, INK_DARK, 720.0
	)
	add_cylinder(
		sheet, "Stain", 0.014, 0.0004, Vector3(0.06, -0.06, 0.0009), grease,
		Vector3(90.0, 0.0, 0.0)
	)


## A folded note lying on a shelf.
static func _build_pantry_note(root: Node3D) -> void:
	var note: MeshInstance3D = _add_paper(
		root, "Paper", Vector2(0.14, 0.17), Vector3.ZERO, PAPER
	)
	add_box(
		root, "Fold", Vector3(0.14, 0.0007, 0.0004), Vector3(0.0, -0.004, 0.0009),
		material(Color(0.6, 0.57, 0.48), 1.0)
	)
	add_paragraphs(
		note, "Text", "JAR_NOTE_TEXT",
		Vector3(-0.062, 0.078, 0.0009), 17, 0.00025, INK_BLUE, 496.0, 0.0035
	)


## An empty glass preserve jar standing on a shelf. Origin at its middle.
static func _build_pantry_jar(root: Node3D) -> void:
	add_cylinder(
		root, "Glass", 0.045, 0.13, Vector3.ZERO,
		glass_material(Color(0.65, 0.82, 0.76, 0.2))
	)
	add_cylinder(
		root, "Base", 0.0455, 0.01, Vector3(0.0, -0.06, 0.0),
		glass_material(Color(0.6, 0.78, 0.72, 0.35))
	)
	add_cylinder(
		root, "Lid", 0.047, 0.016, Vector3(0.0, 0.073, 0.0),
		material(Color(0.45, 0.36, 0.14), 0.6, 0.6)
	)


## A tin can with a faded label. Origin at its middle.
static func _build_tin_can(root: Node3D) -> void:
	add_cylinder(
		root, "Tin", 0.04, 0.11, Vector3.ZERO,
		material(Color(0.5, 0.52, 0.55), 0.45, 0.7)
	)
	add_cylinder(
		root, "Label", 0.0407, 0.06, Vector3.ZERO,
		material(Color(0.55, 0.22, 0.16), 0.9)
	)


## A burlap sack slumped on the floor. Origin on the floor.
static func _build_sack(root: Node3D) -> void:
	var burlap: StandardMaterial3D = material(Color(0.5, 0.4, 0.25), 1.0)

	var body: CylinderMesh = CylinderMesh.new()
	body.top_radius = 0.17
	body.bottom_radius = 0.25
	body.height = 0.55
	_add_mesh(root, "Sack", body, Vector3(0.0, 0.275, 0.0), burlap, Vector3.ZERO)
	var neck: CylinderMesh = CylinderMesh.new()
	neck.top_radius = 0.07
	neck.bottom_radius = 0.14
	neck.height = 0.14
	_add_mesh(root, "Neck", neck, Vector3(0.0, 0.62, 0.0), burlap, Vector3(0.0, 0.0, 8.0))
	add_solid(root, "Collision", Vector3(0.48, 0.6, 0.48), Vector3(0.0, 0.3, 0.0))


static func _build_lucas_diary(root: Node3D) -> void:
	var leather: StandardMaterial3D = material(Color(0.22, 0.14, 0.09), 0.8)
	var page: StandardMaterial3D = material(Color(0.8, 0.76, 0.62), 0.95)
	var rule: StandardMaterial3D = material(Color(0.35, 0.33, 0.3), 1.0)

	add_box(root, "Cover", Vector3(0.27, 0.19, 0.012), Vector3(0.0, 0.0, -0.006), leather)
	add_box(root, "LeftPage", Vector3(0.125, 0.18, 0.004), Vector3(-0.0635, 0.0, 0.002), page)
	add_box(root, "RightPage", Vector3(0.125, 0.18, 0.004), Vector3(0.0635, 0.0, 0.002), page)
	add_box(root, "Spine", Vector3(0.003, 0.185, 0.006), Vector3(0.0, 0.0, 0.003), leather)
	add_box(
		root, "Ribbon", Vector3(0.005, 0.05, 0.0008), Vector3(0.0, -0.11, 0.0046),
		material(Color(0.5, 0.08, 0.08), 0.9)
	)

	# Ruled lines of an older entry on the left page.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 91
	for i: int in 11:
		var length: float = rng.randf_range(0.06, 0.11)
		add_box(
			root, "Scribble%d" % i, Vector3(length, 0.0009, 0.0004),
			Vector3(-0.118 + length * 0.5, 0.07 - i * 0.0125, 0.0043), rule
		)

	# The date and time as a heading, then the entry.
	add_text(
		root, "Heading", "DIARY_HEADING",
		Vector3(0.013, 0.077, 0.0042), 22, 0.00025, INK_DARK
	)
	add_paragraphs(
		root, "Text", "DIARY_TEXT",
		Vector3(0.013, 0.066, 0.0042), 12, 0.00025, INK_DARK, 420.0, 0.0022
	)


static func _build_house_advertisement(root: Node3D) -> void:
	_add_paper(root, "Page", Vector2(0.2, 0.28), Vector3.ZERO, NEWSPRINT)
	add_text(
		root, "Headline", "AD_HEADLINE", Vector3(-0.088, 0.128, 0.0009),
		32, 0.00032, INK_DARK, 540.0
	)

	# The photograph: a small house with blue windows.
	add_box(
		root, "Photo", Vector3(0.15, 0.085, 0.0008), Vector3(0.0, 0.045, 0.0012),
		material(Color(0.2, 0.22, 0.21), 0.9)
	)
	add_box(
		root, "HouseWall", Vector3(0.062, 0.032, 0.0008), Vector3(0.0, 0.034, 0.002),
		material(Color(0.56, 0.5, 0.42), 0.9)
	)
	var roof: PrismMesh = PrismMesh.new()
	roof.size = Vector3(0.074, 0.02, 0.0008)
	_add_mesh(
		root, "HouseRoof", roof, Vector3(0.0, 0.06, 0.002),
		material(Color(0.32, 0.18, 0.12), 0.9), Vector3.ZERO
	)
	var blue: StandardMaterial3D = material(Color(0.2, 0.36, 0.72), 0.5)
	add_box(root, "WindowLeft", Vector3(0.011, 0.012, 0.0008), Vector3(-0.017, 0.037, 0.0026), blue)
	add_box(root, "WindowRight", Vector3(0.011, 0.012, 0.0008), Vector3(0.017, 0.037, 0.0026), blue)
	add_box(
		root, "HouseDoor", Vector3(0.01, 0.018, 0.0008), Vector3(0.0, 0.027, 0.0026),
		material(Color(0.3, 0.2, 0.12), 0.9)
	)

	# The printed advertisement under the photograph.
	add_paragraphs(
		root, "Body", "AD_BODY", Vector3(-0.088, -0.006, 0.0009),
		22, 0.00026, INK_DARK, 400.0, 0.004
	)

	# Two hands on it: Lucas's question in red, beside the print, and Sophia's line in blue, under it; each signed.
	add_text(
		root, "Ours", "AD_OURS", Vector3(0.026, -0.008, 0.0009),
		50, 0.00034, INK_RED, 0.0, false, Vector3(0.0, 0.0, 4.0)
	)
	add_text(
		root, "LucasSignature", "AD_LUCAS_SIGNATURE", Vector3(0.034, -0.03, 0.0009),
		30, 0.00028, INK_RED, 0.0, false, Vector3(0.0, 0.0, 4.0)
	)
	add_paragraphs(
		root, "SophiaNote", "AD_SOPHIA_NOTE", Vector3(-0.08, -0.078, 0.0009),
		26, 0.00024, INK_BLUE, 600.0, 0.003
	)


## A one way bus ticket: the print, and the passenger field filled in by hand. `passenger_key` is the field's printed label
## (in Portuguese it agrees with who travels: "Passageira" on Sophia's, "Passageiro" on the other).
static func _build_bus_ticket(root: Node3D, passenger_key: String, handwriting_key: String) -> void:
	_add_paper(root, "Paper", Vector2(0.16, 0.07), Vector3.ZERO, Color(0.82, 0.78, 0.64))
	add_box(
		root, "Stripe", Vector3(0.16, 0.008, 0.0008), Vector3(0.0, 0.031, 0.0009),
		material(Color(0.4, 0.16, 0.14), 0.9)
	)
	add_text(
		root, "Print", "BUS_TICKET_PRINT", Vector3(-0.073, 0.025, 0.0009),
		18, 0.00026, INK_DARK, 520.0
	)
	add_text(
		root, "PassengerLabel", passenger_key, Vector3(-0.073, -0.012, 0.0009),
		20, 0.00026, INK_DARK, 0.0
	)
	add_box(
		root, "PassengerLine", Vector3(0.082, 0.0006, 0.0004), Vector3(0.0235, -0.0215, 0.0009),
		material(INK_DARK, 1.0)
	)
	add_text(
		root, "Handwriting", handwriting_key, Vector3(-0.012, -0.0075, 0.001),
		34, 0.00034, INK_BLUE, 0.0, false, Vector3(0.0, 0.0, 2.5)
	)


# ============================================================
# THE TIME CAPSULE
# ============================================================

## A small, shallow wooden chest closed with an iron clasp, filled to just under the brim so that what is
## in it can be seen from a standing player's eyes without leaning over the front wall: the interior
## is padded up to 2.5 cm below the rim (the contents lie on the padding, at `CONTENTS_HEIGHT`). Its
## origin is the middle of the base. Nodes the script looks up: LidPivot and Latch.
static func _build_time_capsule(root: Node3D) -> void:
	var wood: StandardMaterial3D = material(Color(0.36, 0.24, 0.14), 0.85)
	var brass: StandardMaterial3D = material(BRASS, 0.4, 0.85)

	var body: CSGBox3D = CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(0.44, 0.12, 0.28)
	body.position = Vector3(0.0, 0.06, 0.0)
	body.material = wood
	root.add_child(body)

	var hollow: CSGBox3D = CSGBox3D.new()
	hollow.name = "Hollow"
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.size = Vector3(0.4, 0.12, 0.24)
	hollow.material = wood
	hollow.position = Vector3(0.0, 0.03, 0.0)
	body.add_child(hollow)

	# The padding the keepsakes lie on, nearly up to the rim.
	add_box(
		root, "Padding", Vector3(0.396, 0.065, 0.236), Vector3(0.0, 0.0625, 0.0),
		material(Color(0.3, 0.12, 0.11), 1.0)
	)

	add_box(root, "BandLeft", Vector3(0.02, 0.122, 0.284), Vector3(-0.15, 0.06, 0.0), brass)
	add_box(root, "BandRight", Vector3(0.02, 0.122, 0.284), Vector3(0.15, 0.06, 0.0), brass)

	var pivot: Node3D = Node3D.new()
	pivot.name = "LidPivot"
	pivot.position = Vector3(0.0, 0.12, -0.14)
	root.add_child(pivot)
	add_box(pivot, "Lid", Vector3(0.46, 0.035, 0.3), Vector3(0.0, 0.0175, 0.14), wood)
	add_box(pivot, "LidBandLeft", Vector3(0.02, 0.038, 0.304), Vector3(-0.15, 0.0175, 0.14), brass)
	add_box(pivot, "LidBandRight", Vector3(0.02, 0.038, 0.304), Vector3(0.15, 0.0175, 0.14), brass)
	add_box(pivot, "Hasp", Vector3(0.03, 0.006, 0.05), Vector3(0.0, 0.038, 0.275), brass)

	# An iron clasp over the hasp: it swings up and out when the capsule unlatches (`TimeCapsule.unlatch`).
	var iron: StandardMaterial3D = material(Color(0.16, 0.16, 0.17), 0.45, 0.9)
	var latch: Node3D = Node3D.new()
	latch.name = "Latch"
	latch.position = Vector3(0.0, 0.105, 0.146)
	root.add_child(latch)
	add_box(latch, "Strap", Vector3(0.05, 0.085, 0.01), Vector3(0.0, 0.0425, 0.0), iron)
	add_box(latch, "Eye", Vector3(0.022, 0.02, 0.016), Vector3(0.0, 0.092, -0.005), iron)
	add_box(root, "LatchPlate", Vector3(0.06, 0.03, 0.008), Vector3(0.0, 0.098, 0.1435), iron)


# ============================================================
# FURNITURE
# ============================================================

## An upturned crate used as a table. Origin on the floor, 0.42 m tall.
static func _build_crate(root: Node3D) -> void:
	var board: StandardMaterial3D = material(PINE, 0.9)
	var core: StandardMaterial3D = material(PINE_DARK, 1.0)
	add_box(root, "Core", Vector3(0.68, 0.4, 0.48), Vector3(0.0, 0.21, 0.0), core)

	for i: int in 3:
		var y: float = 0.06 + i * 0.135
		add_box(
			root, "Board%d" % i, Vector3(0.7, 0.115, 0.5), Vector3(0.0, y, 0.0), board
		)

	for i: int in 3:
		add_box(
			root, "Plank%d" % i, Vector3(0.7, 0.02, 0.155),
			Vector3(0.0, 0.42, (i - 1) * 0.165), board
		)

	for x: float in [-0.33, 0.33]:
		for z: float in [-0.23, 0.23]:
			add_box(
				root, "Post", Vector3(0.05, 0.42, 0.05), Vector3(x, 0.21, z), core
			)

	add_solid(root, "Collision", Vector3(0.7, 0.42, 0.5), Vector3(0.0, 0.21, 0.0))


## A stainless sink on loose bricks, unplumbed. The basin floor is at y 0.75.
static func _build_kitchen_sink(root: Node3D) -> void:
	var brick: StandardMaterial3D = material(Color(0.5, 0.25, 0.18), 0.95)
	var steel: StandardMaterial3D = material(Color(0.62, 0.64, 0.66), 0.3, 0.85)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 17

	for column: int in 2:
		var x: float = -0.38 + column * 0.76
		for row: int in 11:
			var shift: Vector2 = Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.01, 0.01))
			var flipped: bool = row % 2 == 1
			add_box(
				root, "Brick%d_%d" % [column, row],
				Vector3(0.1, 0.07, 0.22) if flipped else Vector3(0.22, 0.07, 0.1),
				Vector3(x + shift.x, 0.035 + row * 0.07, shift.y),
				brick, Vector3(0.0, rng.randf_range(-3.0, 3.0), 0.0)
			)
		add_solid(root, "BrickBody%d" % column, Vector3(0.24, 0.77, 0.24), Vector3(x, 0.385, 0.0))

	var sink: CSGBox3D = CSGBox3D.new()
	sink.name = "Sink"
	sink.size = Vector3(1.0, 0.18, 0.52)
	sink.position = Vector3(0.0, 0.82, 0.0)
	sink.material = steel
	root.add_child(sink)

	var basin: CSGBox3D = CSGBox3D.new()
	basin.name = "Basin"
	basin.operation = CSGShape3D.OPERATION_SUBTRACTION
	basin.size = Vector3(0.84, 0.2, 0.38)
	basin.position = Vector3(0.0, 0.03, 0.0)
	sink.add_child(basin)

	add_cylinder(
		root, "Drain", 0.03, 0.002, Vector3(0.0, 0.7515, 0.0), material(Color(0.05, 0.05, 0.05), 0.8)
	)
	add_cylinder(
		root, "PipeStub", 0.014, 0.16, Vector3(0.0, 1.0, -0.2), steel
	)

	# Solid parts that leave the basin open from above for the player's aim.
	add_solid(root, "BasinFloor", Vector3(1.0, 0.02, 0.52), Vector3(0.0, 0.74, 0.0))
	add_solid(root, "BasinFront", Vector3(1.0, 0.14, 0.07), Vector3(0.0, 0.80, 0.225))
	add_solid(root, "BasinBack", Vector3(1.0, 0.14, 0.07), Vector3(0.0, 0.80, -0.225))
	add_solid(root, "BasinLeft", Vector3(0.08, 0.14, 0.4), Vector3(-0.46, 0.80, 0.0))
	add_solid(root, "BasinRight", Vector3(0.08, 0.14, 0.4), Vector3(0.46, 0.80, 0.0))


## A mattress and pillow outlined on the floorboards in carpenter's chalk. The
## bed lies along Z, its head at -Z, about the origin.
static func _build_chalk_outline(root: Node3D) -> void:
	var chalk: StandardMaterial3D = material(Color(0.86, 0.85, 0.8), 1.0)
	var length: float = 1.95
	var width: float = 0.95
	var line: float = 0.035
	var height: float = 0.004

	add_box(root, "Head", Vector3(width, height, line), Vector3(0.0, height * 0.5, -length * 0.5), chalk)
	add_box(root, "Foot", Vector3(width, height, line), Vector3(0.0, height * 0.5, length * 0.5), chalk)
	add_box(root, "Left", Vector3(line, height, length), Vector3(-width * 0.5, height * 0.5, 0.0), chalk)
	add_box(root, "Right", Vector3(line, height, length), Vector3(width * 0.5, height * 0.5, 0.0), chalk)

	var pillow_z: float = -length * 0.5 + 0.3
	add_box(root, "PillowFront", Vector3(0.6, height, line * 0.7), Vector3(0.0, height * 0.5, pillow_z + 0.14), chalk)
	add_box(root, "PillowLeft", Vector3(line * 0.7, height, 0.28), Vector3(-0.3, height * 0.5, pillow_z), chalk)
	add_box(root, "PillowRight", Vector3(line * 0.7, height, 0.28), Vector3(0.3, height * 0.5, pillow_z), chalk)


## An unpainted nightstand whose front faces +Z. The drawer is a separate scene.
## Origin on the floor, top at y 0.575.
static func _build_nightstand(root: Node3D) -> void:
	var raw: StandardMaterial3D = material(Color(0.62, 0.5, 0.32), 0.9)
	add_box(root, "Body", Vector3(0.5, 0.55, 0.294), Vector3(0.0, 0.275, 0.0), raw)
	add_box(root, "Top", Vector3(0.54, 0.025, 0.34), Vector3(0.0, 0.5625, 0.01), raw)
	add_box(
		root, "Recess", Vector3(0.45, 0.12, 0.002), Vector3(0.0, 0.43, 0.1475),
		material(Color(0.02, 0.015, 0.01), 1.0)
	)
	# Shallower than the body so the drawer front (and its interaction area) stands in front of it.
	add_solid(root, "Collision", Vector3(0.54, 0.575, 0.3), Vector3(0.0, 0.2875, 0.0))


## The size of `postcard` (width, height), in metres: an ordinary postcard.
const POSTCARD_SIZE: Vector2 = Vector2(0.148, 0.105)


## An old postcard, never sent: the written side faces +Z (Lucas's message, `POSTCARD_TEXT`, in blue ink; no address, no stamp)
## and the picture side -Z (a faded print of the town: old houses, the station's canopy and the rails, fog). Centred on the
## origin, +Y up the writing, so the inspect view and a scene can both show the writing the same way. The picture names no
## place.
static func _build_postcard(root: Node3D) -> void:
	var card: StandardMaterial3D = material(Color(0.83, 0.79, 0.67), 0.95)
	add_box(root, "Card", Vector3(POSTCARD_SIZE.x, POSTCARD_SIZE.y, 0.0006), Vector3.ZERO, card)

	# The message, smaller and centred on the written side with wide margins (it is what fills the picture when it is read close).
	add_paragraphs(
		root, "Text", "POSTCARD_TEXT", Vector3(-0.0275, 0.0178, 0.0004), 26, 0.000176, INK_BLUE, 500.0, 0.0032
	)

	# The picture side: a white margin round a faded print.
	var back: Node3D = Node3D.new()
	back.name = "Picture"
	back.position = Vector3(0.0, 0.0, -0.0004)
	back.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	root.add_child(back)
	var sky: StandardMaterial3D = material(Color(0.62, 0.62, 0.58), 1.0)
	var fog: StandardMaterial3D = material(Color(0.74, 0.73, 0.68), 1.0)
	var house: StandardMaterial3D = material(Color(0.33, 0.31, 0.29), 1.0)
	var roof: StandardMaterial3D = material(Color(0.26, 0.22, 0.2), 1.0)
	var iron: StandardMaterial3D = material(Color(0.2, 0.19, 0.18), 1.0)
	add_box(back, "Sky", Vector3(0.134, 0.091, 0.0002), Vector3.ZERO, sky)
	add_box(back, "Fog", Vector3(0.134, 0.022, 0.0002), Vector3(0.0, -0.004, 0.0001), fog)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1957
	for i: int in 6:
		var x: float = -0.055 + float(i) * 0.016 + rng.randf_range(-0.002, 0.002)
		var height: float = rng.randf_range(0.014, 0.022)
		add_box(back, "House%d" % i, Vector3(0.013, height, 0.0002), Vector3(x, -0.024 + height * 0.5, 0.0002), house)
		var gable: PrismMesh = PrismMesh.new()
		gable.size = Vector3(0.015, 0.008, 0.0002)
		_add_mesh(back, "Roof%d" % i, gable, Vector3(x, -0.024 + height + 0.004, 0.0002), roof, Vector3.ZERO)
	# The station: a long canopy on posts, and the rails running off.
	add_box(back, "Canopy", Vector3(0.05, 0.003, 0.0002), Vector3(0.03, -0.012, 0.0003), iron)
	for x: float in [0.008, 0.03, 0.052]:
		add_box(back, "Post", Vector3(0.0012, 0.016, 0.0002), Vector3(x, -0.021, 0.0003), iron)
	for y: float in [-0.033, -0.038]:
		add_box(back, "Rail", Vector3(0.134, 0.0008, 0.0002), Vector3(0.0, y, 0.0003), iron)
	add_box(back, "Mist", Vector3(0.134, 0.012, 0.0002), Vector3(0.0, -0.03, 0.0004), fog)


## Bare shelves on the pantry's far wall (the wall is at the origin, shelves
## stick out towards -X). The top shelf is at eye level, y 1.45.
static func _build_pantry_shelves(root: Node3D) -> void:
	var plank: StandardMaterial3D = material(Color(0.55, 0.42, 0.26), 0.9)
	var bracket: StandardMaterial3D = material(Color(0.12, 0.12, 0.13), 0.6, 0.6)

	for y: float in [0.55, 1.0, 1.45]:
		add_box(root, "Shelf%.2f" % y, Vector3(0.28, 0.03, 2.0), Vector3(-0.14, y, 0.0), plank)
		# Thin collision per plank: a solid block over the whole shelf would swallow
		# everything lying on it, and the interaction ray would never reach it.
		add_solid(root, "ShelfBody%.2f" % y, Vector3(0.28, 0.03, 2.0), Vector3(-0.14, y, 0.0))
		for z: float in [-0.85, 0.85]:
			add_box(
				root, "Bracket%.2f_%.1f" % [y, z], Vector3(0.03, 0.14, 0.03),
				Vector3(-0.03, y - 0.085, z), bracket
			)



## A plank laid over two piles of loose bricks beside the sink, unplumbed like it: where the recipe lies. The plank's top
## is at y 0.9, 0.62 long (along X) and 0.48 deep; the front faces +Z. Origin on the floor.
static func _build_kitchen_counter(root: Node3D) -> void:
	var brick: StandardMaterial3D = material(Color(0.5, 0.25, 0.18), 0.95)
	var plank: StandardMaterial3D = material(Color(0.56, 0.43, 0.27), 0.85)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 29

	for column: int in 2:
		var x: float = -0.21 + column * 0.42
		for row: int in 12:
			var shift: Vector2 = Vector2(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.01, 0.01))
			var flipped: bool = row % 2 == 1
			add_box(
				root, "Brick%d_%d" % [column, row],
				Vector3(0.1, 0.07, 0.22) if flipped else Vector3(0.22, 0.07, 0.1),
				Vector3(x + shift.x, 0.035 + row * 0.07, shift.y),
				brick, Vector3(0.0, rng.randf_range(-3.0, 3.0), 0.0)
			)
		add_solid(root, "BrickBody%d" % column, Vector3(0.24, 0.84, 0.24), Vector3(x, 0.42, 0.0))

	add_box(root, "Plank", Vector3(0.62, 0.04, 0.48), Vector3(0.0, 0.88, 0.0), plank)
	add_solid(root, "PlankBody", Vector3(0.62, 0.04, 0.48), Vector3(0.0, 0.88, 0.0))


## A bare bulb hanging from the pantry ceiling on its flex. Origin at the ceiling; the bulb hangs 0.46 below it. The glass
## is `Bulb` (the house switches its glow on when the lamp is lit; the light itself is a sibling node).
static func _build_pantry_lamp(root: Node3D) -> void:
	add_cylinder(root, "Rose", 0.035, 0.02, Vector3(0.0, -0.01, 0.0), material(Color(0.82, 0.8, 0.74), 0.7))
	add_cylinder(root, "Flex", 0.004, 0.38, Vector3(0.0, -0.21, 0.0), material(Color(0.08, 0.08, 0.08), 0.7))
	add_cylinder(root, "Holder", 0.016, 0.04, Vector3(0.0, -0.41, 0.0), material(Color(0.35, 0.3, 0.2), 0.5, 0.4))
	var bulb_mesh: SphereMesh = SphereMesh.new()
	bulb_mesh.radius = 0.03
	bulb_mesh.height = 0.07
	var glass: StandardMaterial3D = material(Color(0.95, 0.9, 0.78), 0.2)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.72, 0.42)
	glass.emission_energy_multiplier = 0.0
	_add_mesh(root, "Bulb", bulb_mesh, Vector3(0.0, -0.46, 0.0), glass, Vector3.ZERO)


## A plain double bed against the wall: a pine frame, a headboard and a bare striped mattress (no bedding: the house is
## unfinished; the bedding is `memory_bedding`). 1.4 wide (X), 1.95 long (Z), its head at -Z. Origin on the floor at the
## middle of the bed; the mattress's top is at y 0.5.
static func _build_bed(root: Node3D) -> void:
	var pine: StandardMaterial3D = material(PINE, 0.85)
	var ticking: StandardMaterial3D = material(Color(0.72, 0.7, 0.64), 0.95)
	var stripe: StandardMaterial3D = material(Color(0.42, 0.46, 0.55), 0.95)
	var stain: StandardMaterial3D = material(Color(0.55, 0.48, 0.36, 0.5), 1.0)
	stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	add_box(root, "RailLeft", Vector3(0.05, 0.16, 1.95), Vector3(-0.675, 0.24, 0.0), pine)
	add_box(root, "RailRight", Vector3(0.05, 0.16, 1.95), Vector3(0.675, 0.24, 0.0), pine)
	add_box(root, "RailFoot", Vector3(1.4, 0.16, 0.05), Vector3(0.0, 0.24, 0.95), pine)
	for x: float in [-0.675, 0.675]:
		add_box(root, "LegFoot", Vector3(0.06, 0.32, 0.06), Vector3(x, 0.16, 0.95), pine)
	# Kept under the sill of the bedroom window beside it (0.9).
	add_box(root, "Headboard", Vector3(1.4, 0.8, 0.05), Vector3(0.0, 0.4, -0.95), pine)
	add_box(root, "HeadboardTop", Vector3(1.44, 0.04, 0.07), Vector3(0.0, 0.82, -0.95), pine)
	add_box(root, "Slats", Vector3(1.3, 0.02, 1.85), Vector3(0.0, 0.29, 0.0), material(PINE_DARK, 0.95))

	add_box(root, "Mattress", Vector3(1.32, 0.2, 1.86), Vector3(0.0, 0.4, 0.02), ticking)
	for i: int in 7:
		add_box(root, "Stripe%d" % i, Vector3(0.025, 0.002, 1.86), Vector3(-0.54 + i * 0.18, 0.501, 0.02), stripe)
	add_cylinder(root, "Stain", 0.12, 0.002, Vector3(0.25, 0.502, 0.35), stain)

	add_solid(root, "Collision", Vector3(1.42, 0.5, 1.98), Vector3(0.0, 0.25, 0.0))
	add_solid(root, "HeadboardBody", Vector3(1.44, 0.84, 0.07), Vector3(0.0, 0.42, -0.95))


## The bed made, as it was in the memory: a sheet, a warm wool blanket turned down, two pillows, a throw folded at the foot.
## Laid on `bed` (same origin). Nothing solid: it is only seen while the player is held.
static func _build_memory_bedding(root: Node3D) -> void:
	var sheet: StandardMaterial3D = material(Color(0.86, 0.82, 0.74), 0.95)
	# Ochre, not red: nothing in the memory may read as the old red room.
	var wool: StandardMaterial3D = material(Color(0.62, 0.48, 0.26), 1.0)
	var pillow: StandardMaterial3D = material(Color(0.9, 0.87, 0.8), 0.95)
	var throw_color: StandardMaterial3D = material(Color(0.32, 0.36, 0.28), 1.0)

	add_box(root, "Sheet", Vector3(1.36, 0.012, 1.88), Vector3(0.0, 0.506, 0.02), sheet)
	# The blanket, turned down at the top, hanging a little over each side.
	add_box(root, "Blanket", Vector3(1.4, 0.03, 1.3), Vector3(0.0, 0.525, 0.3), wool)
	add_box(root, "BlanketFold", Vector3(1.4, 0.035, 0.18), Vector3(0.0, 0.55, -0.32), sheet, Vector3(4.0, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		add_box(root, "BlanketSide", Vector3(0.02, 0.18, 1.3), Vector3(side * 0.71, 0.44, 0.3), wool)
	for x: float in [-0.33, 0.33]:
		add_box(root, "Pillow", Vector3(0.58, 0.11, 0.36), Vector3(x, 0.57, -0.7), pillow, Vector3(-6.0, x * 8.0, 0.0))
	add_box(root, "Throw", Vector3(1.0, 0.05, 0.3), Vector3(0.0, 0.57, 0.78), throw_color, Vector3(0.0, 3.0, 0.0))


## A kitchen chair with clothes thrown over it: a shirt over the back, jeans folded on the seat. Origin on the floor, the seat
## at 0.45, its back at -Z. Nothing solid.
static func _build_memory_chair(root: Node3D) -> void:
	var wood: StandardMaterial3D = material(Color(0.4, 0.26, 0.15), 0.8)
	var shirt: StandardMaterial3D = material(Color(0.62, 0.66, 0.72), 1.0)
	var denim: StandardMaterial3D = material(Color(0.2, 0.26, 0.4), 1.0)

	add_box(root, "Seat", Vector3(0.42, 0.03, 0.4), Vector3(0.0, 0.45, 0.0), wood)
	for x: float in [-0.18, 0.18]:
		for z: float in [-0.17, 0.17]:
			add_box(root, "Leg", Vector3(0.035, 0.45, 0.035), Vector3(x, 0.225, z), wood)
		add_box(root, "BackPost", Vector3(0.035, 0.45, 0.035), Vector3(x, 0.68, -0.18), wood)
	add_box(root, "BackRail", Vector3(0.4, 0.07, 0.025), Vector3(0.0, 0.85, -0.18), wood)

	add_box(root, "ShirtBack", Vector3(0.46, 0.34, 0.012), Vector3(0.0, 0.72, -0.205), shirt, Vector3(-4.0, 0.0, 2.0))
	add_box(root, "ShirtFront", Vector3(0.44, 0.22, 0.012), Vector3(0.0, 0.79, -0.155), shirt, Vector3(8.0, 0.0, -3.0))
	add_box(root, "Sleeve", Vector3(0.09, 0.3, 0.012), Vector3(0.24, 0.6, -0.19), shirt, Vector3(0.0, 0.0, 14.0))
	add_box(root, "Jeans", Vector3(0.3, 0.05, 0.34), Vector3(0.02, 0.49, 0.02), denim, Vector3(0.0, 9.0, 0.0))


## Two enamel cups left on the floor by the bed, one still with a little coffee. Origin on the floor.
static func _build_memory_cups(root: Node3D) -> void:
	var enamel: StandardMaterial3D = material(Color(0.86, 0.84, 0.78), 0.4)
	var rim: StandardMaterial3D = material(Color(0.12, 0.16, 0.3), 0.4)
	var coffee: StandardMaterial3D = material(Color(0.16, 0.09, 0.05), 0.2)
	for i: int in 2:
		var at: Vector3 = Vector3(-0.07 + i * 0.15, 0.0, 0.03 * float(i))
		add_cylinder(root, "Cup%d" % i, 0.04, 0.085, at + Vector3(0.0, 0.0425, 0.0), enamel)
		add_cylinder(root, "Rim%d" % i, 0.0405, 0.006, at + Vector3(0.0, 0.083, 0.0), rim)
		add_ring(root, "Handle%d" % i, 0.018, 0.026, at + Vector3(0.045, 0.045, 0.0), enamel)
	add_cylinder(root, "Coffee", 0.036, 0.002, Vector3(-0.07, 0.07, 0.0), coffee)


## A small bedside lamp with a cloth shade, lit (the light itself is a sibling node, above it, standing in for the bulb: so the
## lamp casts no shadow of its own, or its shade would throw a wedge of dark over everything beside it). Origin on the surface
## it stands on.
static func _build_bedside_lamp(root: Node3D) -> void:
	var base: StandardMaterial3D = material(Color(0.3, 0.2, 0.12), 0.6)
	add_cylinder(root, "Base", 0.06, 0.03, Vector3(0.0, 0.015, 0.0), base).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_cylinder(root, "Stem", 0.01, 0.22, Vector3(0.0, 0.14, 0.0), base).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shade_mesh: CylinderMesh = CylinderMesh.new()
	shade_mesh.top_radius = 0.07
	shade_mesh.bottom_radius = 0.11
	shade_mesh.height = 0.14
	shade_mesh.cap_top = false
	shade_mesh.cap_bottom = false
	var cloth: StandardMaterial3D = material(Color(0.95, 0.82, 0.6), 0.9)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.emission_enabled = true
	cloth.emission = Color(1.0, 0.7, 0.4)
	cloth.emission_energy_multiplier = 0.9
	_add_mesh(root, "Shade", shade_mesh, Vector3(0.0, 0.27, 0.0), cloth, Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ============================================================
# SCARES
# ============================================================

## Something standing still in the dark, in flat black. It is meant NOT to read as a man: too tall,
## too thin, arms that hang past its knees, a small head on a long neck, no face. Only an outline
## shows against whatever the flashlight lights behind it, and the less light the less sure the eye is
## of what it sees. Origin at the feet, about 2.1 m tall, facing -Z. The sequence poses it through the
## pivots `Lean` (the body above the hips), `Lean/HeadPivot`, `Lean/ArmL` and `Lean/ArmR`.
static func _build_standing_silhouette(root: Node3D) -> void:
	var black: StandardMaterial3D = black_material()

	for x: float in [-0.075, 0.075]:
		_add_capsule(root, "Leg%s" % ("L" if x < 0.0 else "R"), 0.05, 1.02, Vector3(x, 0.51, 0.0), black)

	var lean: Node3D = Node3D.new()
	lean.name = "Lean"
	lean.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(lean)

	var torso: MeshInstance3D = _add_capsule(lean, "Torso", 0.11, 0.66, Vector3(0.0, 0.33, 0.0), black)
	torso.scale = Vector3(1.0, 1.0, 0.62)
	_add_capsule(lean, "Neck", 0.03, 0.34, Vector3(0.0, 0.76, -0.01), black)

	# The head: small, a little long, with a chin so a turn of it can be read, and nothing else.
	var head_pivot: Node3D = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 0.92, -0.01)
	lean.add_child(head_pivot)
	var skull: SphereMesh = SphereMesh.new()
	skull.radius = 0.075
	skull.height = 0.19
	_add_mesh(head_pivot, "Head", skull, Vector3(0.0, 0.05, 0.0), black, Vector3.ZERO)
	var chin: SphereMesh = SphereMesh.new()
	chin.radius = 0.028
	chin.height = 0.06
	_add_mesh(head_pivot, "Chin", chin, Vector3(0.0, -0.03, -0.06), black, Vector3.ZERO)

	# Arms from the shoulders, thin and far too long.
	for x: float in [-0.17, 0.17]:
		var arm: Node3D = Node3D.new()
		arm.name = "Arm%s" % ("L" if x < 0.0 else "R")
		arm.position = Vector3(x, 0.62, 0.0)
		lean.add_child(arm)
		_add_capsule(arm, "Limb", 0.026, 1.05, Vector3(0.0, -0.52, 0.0), black)
		# Long fingers hanging open.
		_add_capsule(arm, "Hand", 0.02, 0.22, Vector3(0.0, -1.1, 0.0), black)


static func _add_capsule(
	parent: Node,
	node_name: String,
	radius: float,
	height: float,
	pos: Vector3,
	mat: Material,
	rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _add_mesh(parent, node_name, mesh, pos, mat, rot)




## Several paragraphs of written text (see ParagraphStack). `key` is a
## localization key whose translation separates paragraphs with blank lines.
static func add_paragraphs(
	parent: Node,
	node_name: String,
	key: String,
	pos: Vector3,
	font_size: int,
	pixel_size: float,
	color: Color,
	width_pixels: float,
	gap: float = 0.006
) -> ParagraphStack:
	var stack: ParagraphStack = ParagraphStack.new()
	stack.name = node_name
	stack.text_key = key
	stack.font_size = font_size
	stack.pixel_size = pixel_size
	stack.color = color
	stack.width_pixels = width_pixels
	stack.gap = gap
	stack.position = pos
	parent.add_child(stack)
	return stack
