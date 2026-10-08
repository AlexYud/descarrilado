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
			_build_bus_ticket(root, "BUS_TICKET_NAME_SOPHIA")
		&"bus_ticket_unclaimed":
			_build_bus_ticket(root, "BUS_TICKET_IF_YOU_WANT")
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
		&"alarm_clock":
			_build_alarm_clock(root)
		&"pantry_shelves":
			_build_pantry_shelves(root)
		&"lurking_head":
			_build_lurking_head(root)
		&"window_mist":
			_build_window_mist(root)
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

	# The quantity from the story, circled twice in blue ink on the wrapper.
	var ink: StandardMaterial3D = material(INK_BLUE, 0.6)
	var ring_center: Vector3 = Vector3(0.1135, -0.02, 0.0022)
	add_text(
		root, "Three", "3", ring_center + Vector3(0.0, 0.0, 0.0006), 44, 0.0004,
		INK_BLUE, 0.0, true
	)
	add_ring(root, "CircleA", 0.0098, 0.0108, ring_center, ink)
	add_ring(root, "CircleB", 0.0113, 0.0123, ring_center + Vector3(0.0007, 0.0004, 0.0), ink)


## A folded note lying on a shelf, with the first number underlined.
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
		Vector3(-0.062, 0.078, 0.0009), 22, 0.00025, INK_BLUE, 496.0
	)
	# The first number, underlined.
	add_box(
		note, "Underline", Vector3(0.0036, 0.0006, 0.0004),
		Vector3(-0.0603, 0.0722, 0.0011), material(INK_BLUE, 0.6)
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

	# The date and time as a heading, underlined heavily in black ink, then the entry.
	add_text(
		root, "Heading", "DIARY_HEADING",
		Vector3(0.013, 0.077, 0.0042), 22, 0.00025, INK_DARK
	)
	add_box(
		root, "HeadingUnderline", Vector3(0.07, 0.0014, 0.0004),
		Vector3(0.013 + 0.035, 0.0705, 0.0043), material(INK_DARK, 0.7)
	)
	add_paragraphs(
		root, "Text", "DIARY_TEXT",
		Vector3(0.013, 0.064, 0.0042), 22, 0.00025, INK_DARK, 400.0
	)


static func _build_house_advertisement(root: Node3D) -> void:
	var red: StandardMaterial3D = material(INK_RED, 0.6)

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

	add_text(
		root, "SophiaNote", "AD_SOPHIA_NOTE", Vector3(-0.072, -0.0, 0.0009),
		26, 0.00024, INK_BLUE, 600.0
	)

	# Every room circled by Lucas, and his question.
	var room_keys: Array[String] = [
		"AD_ROOM_LIVING", "AD_ROOM_KITCHEN", "AD_ROOM_BEDROOM",
		"AD_ROOM_BEDROOM", "AD_ROOM_PANTRY",
	]
	for i: int in room_keys.size():
		var top: float = -0.026 - i * 0.0185
		add_text(
			root, "Room%d" % i, room_keys[i], Vector3(-0.078, top, 0.0009),
			24, 0.00026, INK_DARK, 300.0
		)
		add_frame(
			root, "Circle%d" % i, Vector2(0.066, 0.0125),
			Vector3(-0.047, top - 0.0045, 0.0012), 0.0007, red,
			-1.6 if i % 2 == 0 else 1.4
		)

	add_text(
		root, "Ours", "AD_OURS", Vector3(0.018, -0.07, 0.0009),
		50, 0.00034, INK_RED, 0.0
	)


static func _build_bus_ticket(root: Node3D, handwriting_key: String) -> void:
	_add_paper(root, "Paper", Vector2(0.16, 0.07), Vector3.ZERO, Color(0.82, 0.78, 0.64))
	add_box(
		root, "Stripe", Vector3(0.16, 0.008, 0.0008), Vector3(0.0, 0.031, 0.0009),
		material(Color(0.4, 0.16, 0.14), 0.9)
	)
	add_text(
		root, "Print", "BUS_TICKET_PRINT", Vector3(-0.073, 0.024, 0.0009),
		22, 0.00028, INK_DARK, 520.0
	)
	add_text(
		root, "PassengerLabel", "BUS_TICKET_PASSENGER", Vector3(-0.073, -0.012, 0.0009),
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

## A small wooden chest with a brass combination padlock. Its origin is the
## middle of the base. Nodes the puzzle script looks up: LidPivot, Padlock
## (with Digit0..2) and Shackle.
static func _build_time_capsule(root: Node3D) -> void:
	var wood: StandardMaterial3D = material(Color(0.36, 0.24, 0.14), 0.85)
	var brass: StandardMaterial3D = material(BRASS, 0.4, 0.85)

	var body: CSGBox3D = CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(0.44, 0.2, 0.28)
	body.position = Vector3(0.0, 0.1, 0.0)
	body.material = wood
	root.add_child(body)

	var hollow: CSGBox3D = CSGBox3D.new()
	hollow.name = "Hollow"
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.size = Vector3(0.4, 0.2, 0.24)
	hollow.material = wood
	hollow.position = Vector3(0.0, 0.03, 0.0)
	body.add_child(hollow)

	add_box(root, "BandLeft", Vector3(0.02, 0.202, 0.284), Vector3(-0.15, 0.1, 0.0), brass)
	add_box(root, "BandRight", Vector3(0.02, 0.202, 0.284), Vector3(0.15, 0.1, 0.0), brass)

	var pivot: Node3D = Node3D.new()
	pivot.name = "LidPivot"
	pivot.position = Vector3(0.0, 0.2, -0.14)
	root.add_child(pivot)
	add_box(pivot, "Lid", Vector3(0.46, 0.035, 0.3), Vector3(0.0, 0.0175, 0.14), wood)
	add_box(pivot, "LidBandLeft", Vector3(0.02, 0.038, 0.304), Vector3(-0.15, 0.0175, 0.14), brass)
	add_box(pivot, "LidBandRight", Vector3(0.02, 0.038, 0.304), Vector3(0.15, 0.0175, 0.14), brass)
	add_box(pivot, "Hasp", Vector3(0.03, 0.006, 0.05), Vector3(0.0, 0.038, 0.275), brass)

	var padlock: Node3D = Node3D.new()
	padlock.name = "Padlock"
	padlock.position = Vector3(0.0, 0.172, 0.152)
	root.add_child(padlock)
	add_box(padlock, "Case", Vector3(0.07, 0.055, 0.022), Vector3.ZERO, brass)
	var shackle: MeshInstance3D = add_ring(
		padlock, "Shackle", 0.013, 0.018, Vector3(0.0, 0.0275, 0.0), brass
	)
	shackle.scale = Vector3(1.0, 1.0, 1.0)

	for i: int in 3:
		var x: float = (i - 1) * 0.021
		add_box(
			padlock, "Wheel%d" % i, Vector3(0.018, 0.026, 0.002), Vector3(x, 0.0, 0.0115),
			material(Color(0.1, 0.09, 0.07), 0.6, 0.3)
		)
		add_text(
			padlock, "Digit%d" % i, "0", Vector3(x, 0.0, 0.0127), 40, 0.00036,
			Color(0.9, 0.8, 0.5), 0.0, true
		)


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


## A 1990s battery alarm clock frozen at 06:00. The red digits are the one text
## in the house that is meant to glow.
static func _build_alarm_clock(root: Node3D) -> void:
	add_box(
		root, "Body", Vector3(0.16, 0.07, 0.06), Vector3(0.0, 0.035, 0.0),
		material(Color(0.04, 0.04, 0.045), 0.5)
	)
	add_box(
		root, "Face", Vector3(0.13, 0.04, 0.002), Vector3(0.0, 0.038, 0.0305),
		material(Color(0.015, 0.012, 0.012), 0.4)
	)
	var digits: Label3D = add_text(
		root, "Digits", "06:00", Vector3(0.0, 0.038, 0.0318), 48, 0.00055,
		Color(0.95, 0.12, 0.06), 0.0, true
	)
	digits.shaded = false
	for i: int in 2:
		add_box(
			root, "Button%d" % i, Vector3(0.018, 0.006, 0.014),
			Vector3(-0.03 + i * 0.06, 0.073, 0.0), material(Color(0.1, 0.1, 0.11), 0.5)
		)


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



# ============================================================
# SCARES
# ============================================================

## Just a head and one shoulder, in flat black, leaning to the side and peering
## forward like someone lurking just below a window. Only its outline shows
## against the glow behind it. Origin at the base of the neck, facing -Z.
static func _build_lurking_head(root: Node3D) -> void:
	var black: StandardMaterial3D = black_material()

	var lean: Node3D = Node3D.new()
	lean.name = "Lean"
	lean.rotation_degrees = Vector3(14.0, 0.0, 24.0)
	lean.scale = Vector3.ONE * 1.15
	root.add_child(lean)

	add_cylinder(lean, "Neck", 0.055, 0.15, Vector3(0.0, 0.075, 0.0), black)
	var skull: SphereMesh = SphereMesh.new()
	skull.radius = 0.115
	skull.height = 0.29
	_add_mesh(lean, "Head", skull, Vector3(0.0, 0.26, -0.03), black, Vector3(8.0, 0.0, 0.0))
	# Sloping shoulders (a flattened ellipsoid), one side dropping away.
	var shoulders: SphereMesh = SphereMesh.new()
	shoulders.radius = 0.2
	shoulders.height = 0.4
	var body: MeshInstance3D = _add_mesh(
		lean, "Shoulders", shoulders, Vector3(0.1, -0.02, 0.02), black, Vector3(0.0, 0.0, 12.0)
	)
	body.scale = Vector3(1.7, 0.6, 0.8)


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




## A glow standing in for moonlit fog outside a window, so a figure in front of
## it reads as a silhouette. Faces +Z.
static func _build_window_mist(root: Node3D) -> void:
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(0.5, 0.64, 0.7)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.9, 1.8)
	_add_mesh(root, "Mist", quad, Vector3.ZERO, glow, Vector3.ZERO)




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
