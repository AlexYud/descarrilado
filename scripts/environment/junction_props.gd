class_name JunctionProps
extends RefCounted

## Stand-in models for the waiting shed and signal box (the third dream puzzle),
## built in code from primitives and CSG so the scene can be played before real
## art exists. `build()` fills a node with the model for a `kind`; ProceduralProp
## calls it for every prop that is not a house prop.
##
## Inspectable props (journal, lantern, switch box, whistle, Ficha, note) are
## built facing +Z with +Y up and centred on the origin, which is how the inspect
## view shows them. Written text is a Label3D (shaded, so it never glows in the
## dark) holding a localization key. Furniture and scenery stand on the ground
## with the origin at floor level.

const CONCRETE: Color = Color(0.5, 0.5, 0.47)
const CONCRETE_DARK: Color = Color(0.3, 0.3, 0.29)
const RUST: Color = Color(0.34, 0.17, 0.08)
const RUST_DARK: Color = Color(0.2, 0.1, 0.05)
const IRON: Color = Color(0.13, 0.13, 0.14)
const MOLD: Color = Color(0.16, 0.26, 0.12)
const WOOD_OLD: Color = Color(0.27, 0.2, 0.13)
const WOOD_PALE: Color = Color(0.46, 0.34, 0.2)
const ETCH: Color = Color(0.06, 0.045, 0.03)
const BRASS: Color = Color(0.58, 0.44, 0.15)

## Half the length of the track in metres (it runs along Z through the origin).
const TRACK_HALF_LENGTH: float = 21.0
## Height of the walkable bank under the track model.
const TRACK_BANK_TOP: float = 0.14

const SIGNAL_BOX_CENTER_Y: float = 1.1
const LEVER_REST_Y: float = 0.9


static func has_kind(kind: StringName) -> bool:
	return kind in [
		&"sophia_journal", &"railway_lantern", &"switch_box", &"carved_whistle",
		&"sophia_ficha", &"juliana_ficha", &"lucas_ficha", &"ficha_note", &"payphone_note", &"signal_box", &"waiting_shelter", &"ticket_puncher",
		&"shelter_bench", &"backpack", &"track_bank", &"mile_marker",
	]


static func build(kind: StringName, root: Node3D) -> void:
	match kind:
		&"sophia_journal":
			_build_journal(root)
		&"railway_lantern":
			_build_lantern(root)
		&"ticket_puncher":
			_build_ticket_puncher(root)
		&"switch_box":
			_build_switch_box(root)
		&"carved_whistle":
			_build_whistle(root)
		&"sophia_ficha":
			_build_ficha(root)
		&"juliana_ficha":
			_build_ficha(root, "FICHA_NUMBER_1", &"juliana")
		&"lucas_ficha":
			_build_ficha(root, "FICHA_NUMBER_2", &"lucas")
		&"ficha_note":
			_build_ficha_note(root)
		&"payphone_note":
			_build_payphone_note(root)
		&"signal_box":
			_build_signal_box(root)
		&"waiting_shelter":
			_build_shelter(root)
		&"shelter_bench":
			_build_bench(root)
		&"backpack":
			_build_backpack(root)
		&"track_bank":
			_build_track_bank(root)
		&"mile_marker":
			_build_mile_marker(root)
		_:
			push_warning("JunctionProps: unknown prop kind '%s'." % kind)


# ============================================================
# BUILDING BLOCKS
# ============================================================

## Weathered stone or iron: the base colour mottled by noise, mapped by world
## position so every box shows the same grain whatever its size.
static func weathered(color: Color, scale: float = 1.2, roughness: float = 0.95, metallic: float = 0.0) -> StandardMaterial3D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = 0.045
	noise.fractal_octaves = 4

	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.5, 0.5, 0.5))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))

	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.width = 256
	texture.height = 256
	texture.seamless = true

	var result: StandardMaterial3D = HouseProps.material(color, roughness, metallic)
	result.albedo_texture = texture
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_scale = Vector3.ONE * scale
	return result


static func _sphere(
	parent: Node,
	node_name: String,
	radius: float,
	height: float,
	pos: Vector3,
	mat: Material
) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	return HouseProps._add_mesh(parent, node_name, mesh, pos, mat, Vector3.ZERO)


static func _frustum(
	parent: Node,
	node_name: String,
	top_radius: float,
	bottom_radius: float,
	height: float,
	pos: Vector3,
	mat: Material,
	rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	return HouseProps._add_mesh(parent, node_name, mesh, pos, mat, rot)


## A thin dark patch lying on a surface: mould, rust streaks, cracks.
static func _stain(
	parent: Node,
	node_name: String,
	size: Vector3,
	pos: Vector3,
	color: Color,
	rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	return HouseProps.add_box(parent, node_name, size, pos, HouseProps.material(color, 1.0), rot)


## Etched lettering: dark, shallow and centred on `pos`.
static func _etch(
	parent: Node,
	node_name: String,
	key: String,
	pos: Vector3,
	font_size: int,
	pixel_size: float,
	rot: Vector3 = Vector3.ZERO,
	width_pixels: float = 0.0,
	color: Color = ETCH
) -> Label3D:
	return HouseProps.add_text(
		parent, node_name, key, pos, font_size, pixel_size, color, width_pixels, true, rot
	)


## An engraving too small to read in the model: a few scratched lines and a
## `ReadableSpot` at the place, turned to face out of the surface. The words are never
## baked into the item: the inspect view offers to read the spot when the player turns
## that side to them and shows the translated text as an overlay, so one asset serves
## every language.
static func _engraving(
	parent: Node3D,
	node_name: String,
	text_key: String,
	spot_id: StringName,
	pos: Vector3,
	rot: Vector3,
	width: float,
	color: Color = ETCH
) -> ReadableSpot:
	var spot: ReadableSpot = ReadableSpot.new()
	spot.name = node_name
	spot.spot_id = spot_id
	spot.text_key = text_key
	spot.title_key = "INSPECT_SPOT_ENGRAVING"
	spot.position = pos
	spot.rotation_degrees = rot
	parent.add_child(spot)

	var scratch: StandardMaterial3D = HouseProps.material(color.darkened(0.45), 1.0)
	for i: int in 3:
		HouseProps.add_box(
			spot, "Scratch%d" % i,
			Vector3(width * (1.0 - 0.2 * i), width * 0.03, 0.0005),
			Vector3(width * 0.03 * i, (i - 1) * width * 0.11, 0.0001), scratch
		)

	return spot


# ============================================================
# THE JOURNAL AND THE CLUE ITEMS
# ============================================================

## Sophia's notebook, open: two pages of blue ink and the three rules.
static func _build_journal(root: Node3D) -> void:
	var cover: StandardMaterial3D = HouseProps.material(Color(0.12, 0.2, 0.22), 0.85)
	var page: StandardMaterial3D = HouseProps.material(Color(0.82, 0.8, 0.7), 0.95)

	HouseProps.add_box(root, "Cover", Vector3(0.27, 0.19, 0.012), Vector3(0.0, 0.0, -0.006), cover)
	HouseProps.add_box(root, "LeftPage", Vector3(0.125, 0.18, 0.004), Vector3(-0.0635, 0.0, 0.002), page)
	HouseProps.add_box(root, "RightPage", Vector3(0.125, 0.18, 0.004), Vector3(0.0635, 0.0, 0.002), page)
	HouseProps.add_box(root, "Spine", Vector3(0.003, 0.185, 0.006), Vector3(0.0, 0.0, 0.003), cover)
	HouseProps.add_box(
		root, "Elastic", Vector3(0.004, 0.19, 0.0008), Vector3(0.1355, 0.0, 0.0044),
		HouseProps.material(Color(0.05, 0.05, 0.06), 0.8)
	)
	# Damp water stain in the corner of the left page.
	_stain(
		root, "Stain", Vector3(0.04, 0.026, 0.0003), Vector3(-0.09, -0.07, 0.0043),
		Color(0.7, 0.65, 0.5), Vector3(0.0, 0.0, 12.0)
	)

	HouseProps.add_paragraphs(
		root, "LeftText", "JOURNAL_LEFT",
		Vector3(-0.118, 0.075, 0.0042), 22, 0.00025, HouseProps.INK_BLUE, 400.0
	)
	HouseProps.add_paragraphs(
		root, "RightText", "JOURNAL_RIGHT",
		Vector3(0.013, 0.075, 0.0042), 22, 0.00025, HouseProps.INK_BLUE, 400.0
	)


## A heavy railway lantern, rusted and waterlogged, the glass cracked. The clue is
## etched on the underside of its base plate: turn it over.
static func _build_lantern(root: Node3D) -> void:
	var rust: StandardMaterial3D = weathered(RUST, 4.0, 0.9, 0.5)
	var dark: StandardMaterial3D = weathered(RUST_DARK, 4.0, 0.9, 0.5)
	var brass: StandardMaterial3D = HouseProps.material(Color(0.4, 0.31, 0.12), 0.55, 0.7)
	var glass: StandardMaterial3D = HouseProps.glass_material(Color(0.62, 0.7, 0.66, 0.34))

	# Base: a thick plate (its underside is written on), a collar, the oil pot.
	HouseProps.add_cylinder(root, "BasePlate", 0.062, 0.012, Vector3(0.0, -0.105, 0.0), brass)
	HouseProps.add_cylinder(root, "Collar", 0.05, 0.02, Vector3(0.0, -0.089, 0.0), dark)
	# The glass globe and a flat cap above it.
	_sphere(root, "Globe", 0.045, 0.13, Vector3(0.0, -0.03, 0.0), glass)
	HouseProps.add_cylinder(root, "Wick", 0.01, 0.07, Vector3(0.0, -0.05, 0.0), HouseProps.material(Color(0.2, 0.17, 0.12), 1.0))
	# Four cage bars from base to cap.
	for i: int in 4:
		var angle: float = i * PI * 0.5 + PI * 0.25
		HouseProps.add_cylinder(
			root, "Bar%d" % i, 0.0035, 0.17,
			Vector3(cos(angle) * 0.052, -0.005, sin(angle) * 0.052), rust
		)

	HouseProps.add_cylinder(root, "Ring", 0.058, 0.01, Vector3(0.0, 0.082, 0.0), rust)
	_frustum(root, "Cap", 0.012, 0.055, 0.04, Vector3(0.0, 0.107, 0.0), dark)
	HouseProps.add_ring(root, "Handle", 0.036, 0.042, Vector3(0.0, 0.158, 0.0), rust)

	# Cracks across the glass.
	var crack: StandardMaterial3D = HouseProps.material(Color(0.1, 0.12, 0.1), 1.0)
	HouseProps.add_box(root, "Crack0", Vector3(0.0015, 0.09, 0.0012), Vector3(0.012, -0.02, 0.0455), crack, Vector3(0.0, 0.0, 18.0))
	HouseProps.add_box(root, "Crack1", Vector3(0.0015, 0.05, 0.0012), Vector3(-0.02, -0.045, 0.04), crack, Vector3(0.0, 20.0, -34.0))

	# Rust streaks and the etching on the underside.
	_stain(root, "Streak0", Vector3(0.008, 0.07, 0.002), Vector3(0.0, -0.09, 0.049), RUST_DARK)
	_engraving(root, "ClueSpot", "LANTERN_CLUE", &"lantern_clue", Vector3(0.0, -0.1115, 0.0), Vector3(90.0, 0.0, 0.0), 0.07)


## A closed, rotting wooden box with a brass clasp. Nothing in it is shown until
## it is opened (see OpenableContainer): `LidPivot` is the hinge at the back edge.
## Origin at the middle of the box, its floor at y = -0.07.
static func _build_switch_box(root: Node3D) -> void:
	var wood: StandardMaterial3D = weathered(WOOD_OLD, 3.0, 0.9)
	var brass: StandardMaterial3D = HouseProps.material(BRASS, 0.4, 0.85)

	HouseProps.add_box(root, "Floor", Vector3(0.3, 0.01, 0.2), Vector3(0.0, -0.065, 0.0), wood)
	HouseProps.add_box(root, "Front", Vector3(0.3, 0.13, 0.01), Vector3(0.0, 0.0, 0.095), wood)
	HouseProps.add_box(root, "Back", Vector3(0.3, 0.13, 0.01), Vector3(0.0, 0.0, -0.095), wood)
	HouseProps.add_box(root, "Left", Vector3(0.01, 0.13, 0.2), Vector3(-0.145, 0.0, 0.0), wood)
	HouseProps.add_box(root, "Right", Vector3(0.01, 0.13, 0.2), Vector3(0.145, 0.0, 0.0), wood)
	# Tilt the floor of the box into shade: a dark inside for when it opens.
	HouseProps.add_box(root, "Inside", Vector3(0.28, 0.002, 0.18), Vector3(0.0, -0.059, 0.0), HouseProps.material(Color(0.07, 0.05, 0.04), 1.0))

	var hinge: Node3D = Node3D.new()
	hinge.name = "LidPivot"
	hinge.position = Vector3(0.0, 0.065, -0.1)
	root.add_child(hinge)
	HouseProps.add_box(hinge, "Lid", Vector3(0.32, 0.016, 0.22), Vector3(0.0, 0.008, 0.11), wood)
	HouseProps.add_box(hinge, "LidBandLeft", Vector3(0.016, 0.018, 0.224), Vector3(-0.1, 0.008, 0.11), brass)
	HouseProps.add_box(hinge, "LidBandRight", Vector3(0.016, 0.018, 0.224), Vector3(0.1, 0.008, 0.11), brass)
	HouseProps.add_box(hinge, "Clasp", Vector3(0.03, 0.02, 0.012), Vector3(0.0, 0.0, 0.222), brass)
	_stain(hinge, "LidMould", Vector3(0.11, 0.0016, 0.07), Vector3(0.05, 0.0168, 0.09), MOLD)

	_stain(root, "MouldFront", Vector3(0.12, 0.05, 0.0016), Vector3(-0.05, -0.02, 0.1005), MOLD)
	_stain(root, "MouldSide", Vector3(0.0016, 0.06, 0.08), Vector3(0.1505, -0.01, 0.03), MOLD)


## A heavy cast-iron conductor's ticket puncher, held open: two crossed arms on a
## brass pivot, a punch on one jaw. The clue is etched along the back of one arm:
## turn it over. Origin at the pivot, jaws to the left (-X), handles to the right.
static func _build_ticket_puncher(root: Node3D) -> void:
	var iron: StandardMaterial3D = weathered(Color(0.2, 0.2, 0.21), 4.0, 0.55, 0.7)
	var brass: StandardMaterial3D = HouseProps.material(BRASS, 0.4, 0.85)
	var grip: StandardMaterial3D = HouseProps.material(Color(0.2, 0.09, 0.06), 0.8)
	var open_degrees: float = 13.0

	for side: float in [-1.0, 1.0]:
		var arm: Node3D = Node3D.new()
		arm.name = "ArmUpper" if side > 0.0 else "ArmLower"
		arm.rotation_degrees = Vector3(0.0, 0.0, side * open_degrees)
		root.add_child(arm)
		# The jaw (left of the pivot) and the handle (right), one piece of iron.
		HouseProps.add_box(arm, "Jaw", Vector3(0.09, 0.022, 0.014), Vector3(-0.045, 0.0, 0.0), iron)
		HouseProps.add_box(arm, "Handle", Vector3(0.115, 0.016, 0.014), Vector3(0.0575, 0.0, 0.0), iron)
		HouseProps.add_box(arm, "Grip", Vector3(0.07, 0.022, 0.018), Vector3(0.075, 0.0, 0.0), grip)

	# The punch on the lower jaw and the hole it fits in, on the upper jaw.
	var lower: Node3D = root.get_node("ArmLower")
	var upper: Node3D = root.get_node("ArmUpper")
	HouseProps.add_cylinder(lower, "Punch", 0.005, 0.016, Vector3(-0.075, 0.016, 0.0), brass)
	HouseProps.add_cylinder(upper, "Anvil", 0.007, 0.006, Vector3(-0.075, -0.014, 0.0), brass)
	HouseProps.add_cylinder(root, "Pivot", 0.008, 0.017, Vector3.ZERO, brass, Vector3(90.0, 0.0, 0.0))
	_stain(root, "Rust", Vector3(0.03, 0.01, 0.0004), Vector3(0.03, 0.0, 0.0072), RUST_DARK, Vector3(0.0, 0.0, 13.0))

	# The clue, etched along the back of the upper arm.
	_engraving(
		upper, "ClueSpot", "PUNCHER_CLUE", &"puncher_clue", Vector3(-0.054, 0.0, -0.0073),
		Vector3(0.0, 180.0, 0.0), 0.05, Color(0.82, 0.74, 0.55)
	)


## A hand-carved wooden train whistle on a faded cord. Its carved face is the
## front; the clue is on the other flat side.
static func _build_whistle(root: Node3D) -> void:
	var wood: StandardMaterial3D = weathered(WOOD_PALE, 5.0, 0.8)
	var dark: StandardMaterial3D = HouseProps.material(Color(0.14, 0.09, 0.05), 0.9)
	var cord: StandardMaterial3D = HouseProps.material(Color(0.5, 0.18, 0.16), 1.0)

	HouseProps.add_box(root, "Body", Vector3(0.12, 0.05, 0.03), Vector3.ZERO, wood)
	# Mouthpiece: a wedge tapering to the left.
	HouseProps.add_box(root, "Mouthpiece", Vector3(0.04, 0.03, 0.022), Vector3(-0.078, 0.004, 0.0), wood, Vector3(0.0, 0.0, -8.0))
	HouseProps.add_box(root, "SoundHole", Vector3(0.02, 0.006, 0.032), Vector3(-0.018, 0.0255, 0.0), dark)
	# The carved face: a little train chimney and wheel grooves.
	HouseProps.add_box(root, "CarvedChimney", Vector3(0.012, 0.016, 0.002), Vector3(0.03, 0.006, 0.0155), dark)
	HouseProps.add_box(root, "CarvedBody", Vector3(0.05, 0.012, 0.002), Vector3(0.012, -0.008, 0.0155), dark)
	HouseProps.add_box(root, "Wheel0", Vector3(0.008, 0.008, 0.002), Vector3(-0.004, -0.02, 0.0155), dark)
	HouseProps.add_box(root, "Wheel1", Vector3(0.008, 0.008, 0.002), Vector3(0.026, -0.02, 0.0155), dark)

	# Cord through a hole at the right end, faded and fraying.
	HouseProps.add_ring(root, "CordLoop", 0.012, 0.0155, Vector3(0.071, 0.018, 0.0), cord)
	HouseProps.add_cylinder(root, "CordTail", 0.0025, 0.07, Vector3(0.088, -0.02, 0.0), cord, Vector3(0.0, 0.0, 12.0))

	# The clue, on the back.
	_engraving(root, "ClueSpot", "WHISTLE_CLUE", &"whistle_clue", Vector3(0.0, 0.0, -0.0151), Vector3(0.0, 180.0, 0.0), 0.08)


## Sophia's Ficha: a brass telephone token, thick enough to read in the hand.
static func _build_ficha(root: Node3D, number_key: String = "FICHA_NUMBER", variant: StringName = &"") -> void:
	var brass: StandardMaterial3D = HouseProps.material(Color(0.66, 0.5, 0.18), 0.35, 0.9)
	var dark: StandardMaterial3D = HouseProps.material(Color(0.3, 0.22, 0.08), 0.5, 0.8)

	# A disc standing on its edge, facing +Z. Lucas's was bent: the whole disc sits a
	# little askew.
	var coin_root: Node3D = root
	if variant == &"lucas":
		coin_root = Node3D.new()
		coin_root.name = "Bent"
		coin_root.rotation_degrees = Vector3(0.0, 9.0, 6.0)
		root.add_child(coin_root)

	HouseProps.add_cylinder(coin_root, "Coin", 0.026, 0.006, Vector3.ZERO, brass, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_ring(coin_root, "Rim", 0.0225, 0.026, Vector3(0.0, 0.0, 0.0), dark)
	# The groove across the middle that telephone tokens have.
	HouseProps.add_box(coin_root, "Groove", Vector3(0.036, 0.004, 0.0012), Vector3(0.0, 0.0, 0.0031), dark)
	_etch(coin_root, "Number", number_key, Vector3(0.0, 0.011, 0.0031), 30, 0.0004)
	_etch(coin_root, "Mark", "FICHA_MARK", Vector3(0.0, -0.011, 0.0031), 12, 0.0004)

	match variant:
		&"juliana":
			# Her message scratched into the back of the token: a hidden detail, found only by turning the token
			# until the scratch faces you (nothing hints at it before); it is then read as an overlay.
			_engraving(coin_root, "ScratchSpot", "FICHA_SCRATCH_JULIANA", &"ficha_scratch", Vector3(0.0, 0.0, -0.0031), Vector3(0.0, 180.0, 0.0), 0.034)
			# Chipped blue nail polish smudged on the rim.
			var polish: StandardMaterial3D = HouseProps.material(Color(0.16, 0.34, 0.74), 0.25, 0.0)
			HouseProps.add_box(root, "PolishChip", Vector3(0.011, 0.0042, 0.0072), Vector3(0.0206, 0.0132, 0.0), polish, Vector3(0.0, 0.0, 38.0))
			HouseProps.add_box(root, "PolishFleck", Vector3(0.004, 0.0035, 0.004), Vector3(0.0132, 0.0212, 0.0), polish, Vector3(0.0, 0.0, 62.0))
			HouseProps.add_box(root, "PolishSmear", Vector3(0.009, 0.0012, 0.0008), Vector3(0.0168, 0.0094, 0.0033), polish, Vector3(0.0, 0.0, 38.0))
		&"lucas":
			# Dents, scratches and a flattened edge.
			var scratch: StandardMaterial3D = HouseProps.material(Color(0.36, 0.26, 0.09), 0.7, 0.6)
			for i: int in 5:
				HouseProps.add_box(
					coin_root, "Scratch%d" % i, Vector3(0.026 - i * 0.003, 0.0006, 0.0004),
					Vector3(-0.002 + i * 0.002, -0.017 + i * 0.0085, 0.0034),
					scratch, Vector3(0.0, 0.0, 22.0 + i * 17.0)
				)
			HouseProps.add_box(coin_root, "Dent", Vector3(0.012, 0.007, 0.0075), Vector3(-0.0215, 0.012, 0.0), dark, Vector3(0.0, 0.0, -28.0))
			HouseProps.add_box(coin_root, "Flat", Vector3(0.016, 0.003, 0.007), Vector3(0.0, -0.0262, 0.0), dark)
			# His name stamped on the front and "never left" scratched roughly on the back: both hidden details,
			# found only by turning the token until the face is toward you; each is read as an overlay.
			_engraving(coin_root, "StampSpot", "FICHA_STAMP_LUCAS", &"ficha_stamp", Vector3(0.0, 0.0, 0.0031), Vector3.ZERO, 0.034)
			_engraving(coin_root, "ScratchSpot", "FICHA_SCRATCH_LUCAS", &"ficha_scratch", Vector3(0.0, 0.0, -0.0031), Vector3(0.0, 180.0, 0.0), 0.034)


## The note that came with the Ficha: a small card, folded once.
static func _build_ficha_note(root: Node3D) -> void:
	var note: MeshInstance3D = HouseProps._add_paper(
		root, "Paper", Vector2(0.14, 0.105), Vector3.ZERO, HouseProps.PAPER
	)
	HouseProps.add_box(
		root, "Fold", Vector3(0.14, 0.0007, 0.0004), Vector3(0.0, 0.0, 0.0009),
		HouseProps.material(Color(0.6, 0.57, 0.48), 1.0)
	)
	HouseProps.add_paragraphs(
		note, "Text", "FICHA_NOTE_TEXT",
		Vector3(-0.062, 0.045, 0.0009), 22, 0.00025, HouseProps.INK_BLUE, 496.0
	)


## The little note taped to the side of the overlook payphone: a scrap of paper, two
## lines in felt pen, held by two strips of tape. Faces +Z, centred on the origin.
static func _build_payphone_note(root: Node3D) -> void:
	var note: MeshInstance3D = HouseProps._add_paper(
		root, "Paper", Vector2(0.1, 0.07), Vector3.ZERO, HouseProps.PAPER
	)
	var tape: StandardMaterial3D = HouseProps.material(Color(0.78, 0.74, 0.55), 0.6)
	HouseProps.add_box(root, "TapeLeft", Vector3(0.026, 0.012, 0.0007), Vector3(-0.042, 0.034, 0.0012), tape, Vector3(0.0, 0.0, 28.0))
	HouseProps.add_box(root, "TapeRight", Vector3(0.026, 0.012, 0.0007), Vector3(0.042, 0.034, 0.0012), tape, Vector3(0.0, 0.0, -24.0))
	HouseProps.add_paragraphs(
		note, "Text", "OVERLOOK_NOTE_TEXT",
		Vector3(-0.043, 0.014, 0.0009), 22, 0.00022, HouseProps.INK_BLUE, 400.0
	)


# ============================================================
# SIGNAL CONTROL BOX
# ============================================================

## An iron post with a grey-green control box on top: a glass window above a
## chute and coin tray, and three levers in slots. Origin at the foot of the post;
## the front (with the controls) faces +Z. The levers are `Lever1..3` (nodes that
## slide up and down in their slot) so the script can pose them.
static func _build_signal_box(root: Node3D) -> void:
	var iron: StandardMaterial3D = weathered(IRON, 3.0, 0.7, 0.6)
	var paint: StandardMaterial3D = weathered(Color(0.26, 0.31, 0.27), 2.0, 0.85, 0.3)
	var rust: StandardMaterial3D = weathered(RUST, 3.0, 0.9, 0.5)
	var brass: StandardMaterial3D = HouseProps.material(BRASS, 0.45, 0.85)
	var dark: StandardMaterial3D = HouseProps.black_material()
	var cy: float = SIGNAL_BOX_CENTER_Y

	# Post and foot.
	HouseProps.add_cylinder(root, "Post", 0.045, 0.75, Vector3(0.0, 0.375, 0.0), iron)
	HouseProps.add_cylinder(root, "Foot", 0.11, 0.06, Vector3(0.0, 0.03, 0.0), rust)
	HouseProps.add_cylinder(root, "Collar", 0.065, 0.05, Vector3(0.0, 0.7, 0.0), rust)

	# The box and a little rain hood.
	HouseProps.add_box(root, "Body", Vector3(0.64, 0.8, 0.28), Vector3(0.0, cy, 0.0), paint)
	HouseProps.add_box(root, "Hood", Vector3(0.7, 0.025, 0.36), Vector3(0.0, cy + 0.41, 0.03), iron, Vector3(6.0, 0.0, 0.0))
	HouseProps.add_box(root, "Plate", Vector3(0.58, 0.74, 0.006), Vector3(0.0, cy, 0.142), iron)
	_stain(root, "RustRun0", Vector3(0.03, 0.4, 0.002), Vector3(0.24, cy - 0.1, 0.1465), RUST)
	_stain(root, "RustRun1", Vector3(0.02, 0.26, 0.002), Vector3(-0.22, cy + 0.05, 0.1465), RUST_DARK)

	# The window: glass over a dark mechanism of brass rings.
	HouseProps.add_box(root, "WindowBack", Vector3(0.36, 0.2, 0.01), Vector3(0.0, 1.38, 0.138), dark)
	HouseProps.add_ring(root, "Gear0", 0.03, 0.045, Vector3(-0.07, 1.38, 0.15), brass)
	HouseProps.add_ring(root, "Gear1", 0.022, 0.034, Vector3(0.05, 1.4, 0.151), brass)
	HouseProps.add_box(root, "WindowGlass", Vector3(0.36, 0.2, 0.004), Vector3(0.0, 1.38, 0.1515), HouseProps.glass_material(Color(0.6, 0.72, 0.7, 0.2)))
	HouseProps.add_frame(root, "WindowFrame", Vector2(0.37, 0.21), Vector3(0.0, 1.38, 0.154), 0.014, iron)

	# The chute slot, the coin tray under it.
	HouseProps.add_box(root, "Slot", Vector3(0.14, 0.03, 0.004), Vector3(0.0, 1.2, 0.1465), dark)
	HouseProps.add_box(root, "TrayFloor", Vector3(0.34, 0.008, 0.16), Vector3(0.0, 1.152, 0.2), brass)
	HouseProps.add_box(root, "TrayLeft", Vector3(0.008, 0.014, 0.16), Vector3(-0.166, 1.159, 0.2), brass)
	HouseProps.add_box(root, "TrayRight", Vector3(0.008, 0.014, 0.16), Vector3(0.166, 1.159, 0.2), brass)
	HouseProps.add_box(root, "TrayFront", Vector3(0.34, 0.006, 0.008), Vector3(0.0, 1.155, 0.28), brass)

	# Three levers, each swinging on its own hub in a slot, with a number above it
	# and UP/DOWN marks. A lever points up (rotation 0) or down (rotation z 180).
	for i: int in 3:
		var x: float = (i - 1) * 0.18
		HouseProps.add_box(root, "LeverSlot%d" % (i + 1), Vector3(0.05, 0.28, 0.004), Vector3(x, LEVER_REST_Y, 0.1465), dark)
		HouseProps.add_cylinder(root, "LeverHub%d" % (i + 1), 0.026, 0.012, Vector3(x, LEVER_REST_Y, 0.152), brass, Vector3(90.0, 0.0, 0.0))
		var lever: Node3D = Node3D.new()
		lever.name = "Lever%d" % (i + 1)
		lever.position = Vector3(x, LEVER_REST_Y, 0.162)
		root.add_child(lever)
		HouseProps.add_cylinder(lever, "Stem", 0.009, 0.1, Vector3(0.0, 0.05, 0.0), iron)
		_sphere(lever, "Knob", 0.022, 0.044, Vector3(0.0, 0.108, 0.0), HouseProps.material(Color(0.5, 0.1, 0.08), 0.5))
		_etch(root, "Number%d" % (i + 1), "%d" % (i + 1), Vector3(x, 1.065, 0.1465), 26, 0.0008)

	# Lettering for the two ends of a lever's travel.
	_etch(root, "UpMark", "LEVER_UP", Vector3(-0.255, 1.01, 0.1465), 14, 0.0008, Vector3.ZERO, 0.0)
	_etch(root, "DownMark", "LEVER_DOWN", Vector3(-0.255, 0.79, 0.1465), 14, 0.0008, Vector3.ZERO, 0.0)

	# Solid: the post and the box, so the player cannot walk through them.
	HouseProps.add_solid(root, "PostSolid", Vector3(0.18, 0.7, 0.18), Vector3(0.0, 0.35, 0.0))
	HouseProps.add_solid(root, "BodySolid", Vector3(0.64, 0.8, 0.28), Vector3(0.0, cy, 0.0))


# ============================================================
# THE SHELTER AND ITS CONTENTS
# ============================================================

## An open 1950s concrete railway shelter: a roof on four slim pillars, a worn
## floor slab and a few broken low walls. Origin at the middle of the floor; the
## long side (6.6 m) runs along X. Nothing is taller than a pillar or a roof, so
## from every direction it reads as a silhouette, never a blank wall.
static func _build_shelter(root: Node3D) -> void:
	var concrete: StandardMaterial3D = weathered(CONCRETE, 1.4)
	var worn: StandardMaterial3D = weathered(CONCRETE_DARK, 1.0)
	var rebar: StandardMaterial3D = weathered(RUST, 3.0, 0.8, 0.6)
	var half_x: float = 2.7
	var half_z: float = 1.5

	# The floor slab, with a little apron.
	HouseProps.add_box(root, "Floor", Vector3(6.6, 0.05, 4.2), Vector3(0.0, 0.025, 0.0), worn)
	HouseProps.add_solid(root, "FloorSolid", Vector3(6.6, 0.05, 4.2), Vector3(0.0, 0.025, 0.0))

	# Four slim pillars, cracked, one with its rebar showing.
	var pillar_height: float = 2.75
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pos: Vector3 = Vector3(sx * half_x, 0.05 + pillar_height * 0.5, sz * half_z)
			var index: int = (0 if sx < 0.0 else 2) + (0 if sz < 0.0 else 1)
			HouseProps.add_box(root, "Pillar%d" % index, Vector3(0.24, pillar_height, 0.24), pos, concrete)
			HouseProps.add_box(
				root, "PillarFoot%d" % index, Vector3(0.32, 0.18, 0.32),
				Vector3(pos.x, 0.14, pos.z), worn
			)
			HouseProps.add_solid(root, "PillarSolid%d" % index, Vector3(0.26, pillar_height, 0.26), pos)
			_stain(
				root, "PillarStain%d" % index, Vector3(0.012, 1.1, 0.2455),
				Vector3(pos.x + 0.06, pos.y + 0.3, pos.z), CONCRETE_DARK
			)

	# Spalled concrete on one pillar with the iron showing through.
	var spall: Vector3 = Vector3(-half_x, 1.1, -half_z)
	HouseProps.add_box(root, "Spall", Vector3(0.18, 0.5, 0.012), Vector3(spall.x, spall.y, spall.z - 0.122), HouseProps.material(Color(0.22, 0.22, 0.21), 1.0))
	for i: int in 3:
		HouseProps.add_cylinder(
			root, "ExposedBar%d" % i, 0.008, 0.52,
			Vector3(spall.x - 0.05 + i * 0.05, spall.y, spall.z - 0.13), rebar
		)

	# The roof: a heavy slab that has lost a corner, nothing hangs from the break.
	var roof: CSGBox3D = CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(7.2, 0.22, 4.8)
	roof.position = Vector3(0.0, 0.05 + pillar_height + 0.11, 0.0)
	roof.rotation_degrees = Vector3(0.0, 0.0, 0.8)
	roof.material = concrete
	root.add_child(roof)

	var bite: CSGBox3D = CSGBox3D.new()
	bite.name = "BrokenCorner"
	bite.operation = CSGShape3D.OPERATION_SUBTRACTION
	bite.size = Vector3(1.4, 0.5, 1.2)
	bite.position = Vector3(3.2, 0.0, 2.2)
	bite.rotation_degrees = Vector3(0.0, 24.0, 0.0)
	bite.material = concrete
	roof.add_child(bite)

	# The underside edge beam, and a stain where the roof leaks.
	HouseProps.add_box(root, "BeamFront", Vector3(6.4, 0.2, 0.2), Vector3(0.0, 0.05 + pillar_height - 0.08, -half_z), concrete)
	HouseProps.add_box(root, "BeamBack", Vector3(6.4, 0.2, 0.2), Vector3(0.0, 0.05 + pillar_height - 0.08, half_z), concrete)
	# Broken low walls along the back and one end. None is waist high.
	var wall_pieces: Array[Vector4] = [
		Vector4(-2.2, -1.75, 1.3, 0.8),
		Vector4(-0.1, -1.75, 1.0, 0.45),
		Vector4(1.9, -1.75, 0.9, 0.7),
		Vector4(-3.05, -0.8, 1.0, 0.55),
	]
	for i: int in wall_pieces.size():
		var piece: Vector4 = wall_pieces[i]
		var along_z: bool = i == wall_pieces.size() - 1
		var size: Vector3 = Vector3(0.2, piece.w, piece.z) if along_z else Vector3(piece.z, piece.w, 0.2)
		var pos: Vector3 = Vector3(piece.x, 0.05 + piece.w * 0.5, piece.y)
		HouseProps.add_box(root, "LowWall%d" % i, size, pos, concrete)
		HouseProps.add_solid(root, "LowWallSolid%d" % i, size, pos)
		# A jagged, broken top.
		HouseProps.add_box(
			root, "LowWallTop%d" % i,
			Vector3(0.12, 0.14, 0.2) if not along_z else Vector3(0.2, 0.14, 0.12),
			pos + Vector3(0.0, piece.w * 0.5 + 0.05, 0.0), concrete,
			Vector3(0.0, 0.0, 14.0)
		)

	# Weeds through the cracks in the slab.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5150
	var weed: StandardMaterial3D = HouseProps.material(Color(0.12, 0.2, 0.09), 1.0)
	for i: int in 14:
		var tuft: Vector3 = Vector3(rng.randf_range(-3.2, 3.2), 0.075, rng.randf_range(-2.0, 2.0))
		HouseProps.add_box(
			root, "Weed%d" % i, Vector3(0.012, rng.randf_range(0.06, 0.16), 0.012),
			tuft, weed, Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-25.0, 25.0))
		)


## A concrete bench with a few rotten planks. Origin on the floor under its
## middle; 1.8 m long along X, the seat 0.45 m high.
static func _build_bench(root: Node3D) -> void:
	var concrete: StandardMaterial3D = weathered(CONCRETE, 1.4)
	var wood: StandardMaterial3D = weathered(WOOD_OLD, 3.0, 0.9)

	for sx: float in [-0.75, 0.75]:
		HouseProps.add_box(root, "Leg%s" % ("L" if sx < 0.0 else "R"), Vector3(0.14, 0.4, 0.44), Vector3(sx, 0.2, 0.0), concrete)

	for i: int in 3:
		# The middle plank has split and sags; the last one is gone at one end.
		var length: float = 1.74 if i != 2 else 1.1
		var offset: float = 0.0 if i != 2 else -0.3
		HouseProps.add_box(
			root, "Plank%d" % i, Vector3(length, 0.04, 0.13),
			Vector3(offset, 0.42 - (0.012 if i == 1 else 0.0), -0.15 + i * 0.15),
			wood, Vector3(0.0, 0.0, 0.0 if i != 1 else 1.0)
		)

	_stain(root, "Mould", Vector3(0.3, 0.002, 0.1), Vector3(0.3, 0.443, -0.1), MOLD, Vector3(0.0, 15.0, 0.0))
	# Solid seat and legs, but open underneath: things can be hidden below.
	HouseProps.add_solid(root, "SeatSolid", Vector3(1.8, 0.05, 0.46), Vector3(0.0, 0.425, 0.0))
	HouseProps.add_solid(root, "LegSolidL", Vector3(0.14, 0.4, 0.44), Vector3(-0.75, 0.2, 0.0))
	HouseProps.add_solid(root, "LegSolidR", Vector3(0.14, 0.4, 0.44), Vector3(0.75, 0.2, 0.0))


## Sophia's backpack: dark teal canvas, a front pocket and two straps. Lying on
## its back on the seat. Origin at the middle of its base.
static func _build_backpack(root: Node3D) -> void:
	var canvas: StandardMaterial3D = HouseProps.material(Color(0.1, 0.22, 0.22), 0.95)
	var strap: StandardMaterial3D = HouseProps.material(Color(0.07, 0.08, 0.08), 0.9)

	HouseProps.add_box(root, "Body", Vector3(0.3, 0.4, 0.17), Vector3(0.0, 0.2, 0.0), canvas)
	HouseProps.add_box(root, "Flap", Vector3(0.31, 0.12, 0.18), Vector3(0.0, 0.37, 0.0), canvas)
	HouseProps.add_box(root, "Pocket", Vector3(0.24, 0.18, 0.07), Vector3(0.0, 0.14, 0.11), canvas)
	HouseProps.add_box(root, "PocketFlap", Vector3(0.25, 0.04, 0.075), Vector3(0.0, 0.225, 0.112), HouseProps.material(Color(0.08, 0.17, 0.17), 0.95))
	for sx: float in [-0.09, 0.09]:
		HouseProps.add_box(root, "Strap%s" % ("L" if sx < 0.0 else "R"), Vector3(0.035, 0.34, 0.012), Vector3(sx, 0.2, -0.09), strap)
	HouseProps.add_box(root, "Buckle", Vector3(0.03, 0.02, 0.012), Vector3(0.0, 0.33, 0.096), HouseProps.material(Color(0.55, 0.55, 0.5), 0.4, 0.8))
	_stain(root, "Damp", Vector3(0.12, 0.1, 0.0016), Vector3(-0.05, 0.1, 0.0858), Color(0.05, 0.12, 0.12))
	# A small keychain: a red ring and a tag.
	HouseProps.add_ring(root, "Keychain", 0.012, 0.016, Vector3(0.12, 0.3, 0.096), HouseProps.material(Color(0.6, 0.12, 0.1), 0.6))


# ============================================================
# THE TRACK AND THE MILE MARKER
# ============================================================

## The collision under the track pieces (the visible track is the ready-made
## model in assets/models/trains/train_tracks, which has no collision): a low
## bank along Z through the origin that the player walks up and over.
static func _build_track_bank(root: Node3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Bank"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	var half_z: float = TRACK_HALF_LENGTH
	var points: PackedVector3Array = PackedVector3Array()
	for z: float in [-half_z, half_z]:
		points.append(Vector3(-1.95, 0.0, z))
		points.append(Vector3(1.95, 0.0, z))
		points.append(Vector3(-1.4, TRACK_BANK_TOP, z))
		points.append(Vector3(1.4, TRACK_BANK_TOP, z))
	hull.points = points
	shape.shape = hull
	body.add_child(shape)
	root.add_child(body)


## A leaning cast-iron kilometre post, rusted dark, its number worn. A
## hook on its back (-Z, away from the trail) holds the whistle. Origin at the foot.
static func _build_mile_marker(root: Node3D) -> void:
	var concrete: StandardMaterial3D = weathered(Color(0.24, 0.19, 0.16), 3.0, 0.75, 0.55)
	var rust: StandardMaterial3D = weathered(RUST, 3.0, 0.9, 0.5)

	var post: Node3D = Node3D.new()
	post.name = "Lean"
	post.rotation_degrees = Vector3(3.0, 0.0, -4.0)
	root.add_child(post)

	HouseProps.add_box(post, "Shaft", Vector3(0.22, 1.25, 0.18), Vector3(0.0, 0.625, 0.0), concrete)
	HouseProps.add_box(post, "Cap", Vector3(0.26, 0.1, 0.22), Vector3(0.0, 1.3, 0.0), concrete, Vector3(0.0, 0.0, 6.0))
	HouseProps.add_box(post, "Plate", Vector3(0.18, 0.16, 0.006), Vector3(0.0, 1.0, 0.093), rust)
	_etch(post, "Number", "MILE_MARKER_TEXT", Vector3(0.0, 1.0, 0.097), 18, 0.0008)
	_stain(post, "Stain", Vector3(0.05, 0.6, 0.002), Vector3(-0.06, 0.55, 0.0915), CONCRETE_DARK)
	# The hook the whistle hangs from is on the BACK of the post, away from the trail.
	HouseProps.add_cylinder(post, "Hook", 0.006, 0.07, Vector3(0.0, 0.62, -0.12), rust, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_box(post, "HookTip", Vector3(0.012, 0.03, 0.012), Vector3(0.0, 0.64, -0.152), rust)

	HouseProps.add_solid(root, "Solid", Vector3(0.3, 1.3, 0.26), Vector3(0.0, 0.65, 0.0))
