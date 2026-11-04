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
## Damp wood and moss in the shelter's bench and box: dark, so that it never reads as a sheet of paper under a light.
const MOLD_DAMP: Color = Color(0.085, 0.115, 0.07)
const WOOD_OLD: Color = Color(0.27, 0.2, 0.13)
const WOOD_PALE: Color = Color(0.46, 0.34, 0.2)
const ETCH: Color = Color(0.06, 0.045, 0.03)
const BRASS: Color = Color(0.58, 0.44, 0.15)

## Half the length of the track in metres (it runs along Z through the origin).
const TRACK_HALF_LENGTH: float = 21.0
## Height of the walkable bank under the track model.
const TRACK_BANK_TOP: float = 0.14

const LEVER_REST_Y: float = 0.9


static func has_kind(kind: StringName) -> bool:
	return kind in [
		&"sophia_journal", &"railway_lantern", &"switch_box", &"carved_whistle",
		&"sophia_ficha", &"juliana_ficha", &"lucas_ficha", &"ficha_note", &"waiting_shelter",
		&"shelter_bench", &"backpack", &"track_bank", &"mile_marker",
	]


static func build(kind: StringName, root: Node3D) -> void:
	match kind:
		&"sophia_journal":
			_build_journal(root)
		&"railway_lantern":
			_build_lantern(root)
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
		Vector3(-0.118, 0.077, 0.0042), 19, 0.00025, HouseProps.INK_BLUE, 440.0
	)
	HouseProps.add_paragraphs(
		root, "RightText", "JOURNAL_RIGHT",
		Vector3(0.013, 0.077, 0.0042), 19, 0.00025, HouseProps.INK_BLUE, 440.0
	)

	# The maintenance record Sophia copied out, on a scrap pasted low on the right page, and a note in the margin.
	var extract: MeshInstance3D = HouseProps._add_paper(
		root, "ExtractPaper", Vector2(0.108, 0.078), Vector3(0.0645, -0.046, 0.0043),
		Color(0.9, 0.88, 0.8), Vector3(0.0, 0.0, -1.5)
	)
	HouseProps.add_paragraphs(
		extract, "ExtractText", "JOURNAL_EXTRACT",
		Vector3(-0.049, 0.034, 0.0009), 14, 0.00025, HouseProps.INK_BLUE, 392.0, 0.002
	)
	HouseProps.add_paragraphs(
		root, "MarginText", "JOURNAL_MARGIN",
		Vector3(-0.118, -0.073, 0.0042), 14, 0.00025, HouseProps.INK_BLUE, 400.0
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
## Origin at the middle of the box, its floor at y = -0.07 and its rim at y = 0.025 (shallow, so what lies in it is seen from above).
static func _build_switch_box(root: Node3D) -> void:
	var wood: StandardMaterial3D = weathered(WOOD_OLD, 3.0, 0.9)
	var brass: StandardMaterial3D = HouseProps.material(BRASS, 0.4, 0.85)

	HouseProps.add_box(root, "Floor", Vector3(0.3, 0.01, 0.2), Vector3(0.0, -0.065, 0.0), wood)
	HouseProps.add_box(root, "Front", Vector3(0.3, 0.085, 0.01), Vector3(0.0, -0.0175, 0.095), wood)
	HouseProps.add_box(root, "Back", Vector3(0.3, 0.085, 0.01), Vector3(0.0, -0.0175, -0.095), wood)
	HouseProps.add_box(root, "Left", Vector3(0.01, 0.085, 0.2), Vector3(-0.145, -0.0175, 0.0), wood)
	HouseProps.add_box(root, "Right", Vector3(0.01, 0.085, 0.2), Vector3(0.145, -0.0175, 0.0), wood)
	# Tilt the floor of the box into shade: a dark inside for when it opens.
	HouseProps.add_box(root, "Inside", Vector3(0.28, 0.002, 0.18), Vector3(0.0, -0.059, 0.0), HouseProps.material(Color(0.2, 0.15, 0.11), 1.0))

	var hinge: Node3D = Node3D.new()
	hinge.name = "LidPivot"
	hinge.position = Vector3(0.0, 0.025, -0.1)
	root.add_child(hinge)
	HouseProps.add_box(hinge, "Lid", Vector3(0.32, 0.016, 0.22), Vector3(0.0, 0.008, 0.11), wood)
	HouseProps.add_box(hinge, "LidBandLeft", Vector3(0.016, 0.018, 0.224), Vector3(-0.1, 0.008, 0.11), brass)
	HouseProps.add_box(hinge, "LidBandRight", Vector3(0.016, 0.018, 0.224), Vector3(0.1, 0.008, 0.11), brass)
	HouseProps.add_box(hinge, "Clasp", Vector3(0.03, 0.02, 0.012), Vector3(0.0, 0.0, 0.222), brass)
	_stain(hinge, "LidMould", Vector3(0.11, 0.0016, 0.07), Vector3(0.05, 0.0168, 0.09), MOLD_DAMP)

	_stain(root, "MouldFront", Vector3(0.12, 0.05, 0.0016), Vector3(-0.05, -0.02, 0.1005), MOLD_DAMP)
	_stain(root, "MouldSide", Vector3(0.0016, 0.06, 0.08), Vector3(0.1505, -0.01, 0.03), MOLD_DAMP)


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


# ============================================================
# SIGNAL CONTROL BOX
# ============================================================

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

	# The cracked pillar, seen from the open side (+Z): a narrow zigzag crack and the lighter cement patch that mended its
	# lower half. Pillar 1 is the one beside the bench; the same marks are in the news photograph and in the recording.
	_build_pillar_crack(root, Vector3(-half_x, 0.05 + pillar_height * 0.5, half_z))

	# Ordinary damp on the slab in front of the bench: dark, soft and uneven.
	var damp: StandardMaterial3D = HouseProps.material(Color(0.1, 0.1, 0.1, 0.3), 1.0)
	damp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i: int in 3:
		HouseProps.add_box(
			root, "Damp%d" % i, Vector3(0.9 - i * 0.2, 0.002, 0.5 - i * 0.1),
			Vector3(-1.9 + i * 0.35, 0.0512, 0.25 + i * 0.12), damp, Vector3(0.0, 18.0 * i - 10.0, 0.0)
		)

	# Spalled concrete on one pillar with the iron showing through.
	var spall: Vector3 = Vector3(-half_x, 1.1, -half_z)
	HouseProps.add_box(root, "Spall", Vector3(0.18, 0.5, 0.012), Vector3(spall.x, spall.y, spall.z - 0.122), HouseProps.material(Color(0.22, 0.22, 0.21), 1.0))
	for i: int in 3:
		HouseProps.add_cylinder(
			root, "ExposedBar%d" % i, 0.008, 0.52,
			Vector3(spall.x - 0.05 + i * 0.05, spall.y, spall.z - 0.13), rebar
		)

	# The lamp's fixture: a cord and a bare bulb under the roof (the light itself is the scene's `ShelterLamp`, at the same place), so that the shelter
	# reads as lit from far off in the fog. Steady and cold: it does nothing.
	var bulb: StandardMaterial3D = HouseProps.material(Color(0.78, 0.9, 1.0), 0.3)
	bulb.emission_enabled = true
	bulb.emission = Color(0.7, 0.86, 1.0)
	bulb.emission_energy_multiplier = 1.8
	HouseProps.add_cylinder(root, "LampCord", 0.004, 0.2, Vector3(0.0, 2.7, 0.3), HouseProps.black_material())
	JunctionProps._sphere(root, "LampBulb", 0.05, 0.1, Vector3(0.0, 2.56, 0.3), bulb)

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


## The crack in the shelter's mended pillar: a zigzag of thin dark strips down the face toward +Z, the lighter patch of
## cement over its lower half. `pillar_centre` is the middle of the pillar in the shelter's space.
static func _build_pillar_crack(root: Node3D, pillar_centre: Vector3) -> void:
	var face_z: float = pillar_centre.z + 0.1215
	var crack: StandardMaterial3D = HouseProps.material(Color(0.045, 0.045, 0.045), 1.0)
	var patch: StandardMaterial3D = weathered(Color(0.6, 0.6, 0.56), 2.0, 0.95)
	var top_y: float = pillar_centre.y + 0.75
	var x: float = pillar_centre.x + 0.02
	for i: int in 7:
		var lean: float = 22.0 if i % 2 == 0 else -22.0
		HouseProps.add_box(
			root, "PillarCrack%d" % i, Vector3(0.011, 0.2, 0.003),
			Vector3(x + (0.025 if i % 2 == 0 else -0.025) * 0.5, top_y - 0.17 * i, face_z), crack,
			Vector3(0.0, 0.0, lean)
		)

	# The mend: an uneven patch of lighter cement over the lower cracks.
	HouseProps.add_box(
		root, "PillarPatch", Vector3(0.115, 0.42, 0.004),
		Vector3(x, top_y - 0.17 * 5.0, face_z - 0.0005), patch
	)
	HouseProps.add_box(
		root, "PillarPatchEdge", Vector3(0.07, 0.16, 0.004),
		Vector3(x - 0.02, top_y - 0.17 * 6.4, face_z - 0.0005), patch, Vector3(0.0, 0.0, 6.0)
	)


## A concrete bench with a few rotten planks. Origin on the floor under its
## middle; 1.8 m long along X, the seat 0.45 m high. The front plank is a replacement: the same length as the seat, a
## little greyer and cleaner than the others, with fresh nail heads. (The recording shows the plank it replaced: see
## `shelter_archive`.)
static func _build_bench(root: Node3D) -> void:
	var concrete: StandardMaterial3D = weathered(CONCRETE, 1.4)
	var wood: StandardMaterial3D = weathered(WOOD_OLD, 3.0, 0.9)
	var replaced: StandardMaterial3D = weathered(Color(0.31, 0.25, 0.18), 2.2, 0.82)

	for sx: float in [-0.75, 0.75]:
		HouseProps.add_box(root, "Leg%s" % ("L" if sx < 0.0 else "R"), Vector3(0.14, 0.4, 0.44), Vector3(sx, 0.2, 0.0), concrete)

	for i: int in 2:
		# The middle plank has split and sags.
		HouseProps.add_box(
			root, "Plank%d" % i, Vector3(1.74, 0.04, 0.13),
			Vector3(0.0, 0.42 - (0.012 if i == 1 else 0.0), -0.15 + i * 0.15),
			wood, Vector3(0.0, 0.0, 0.0 if i != 1 else 1.0)
		)

	# The replaced plank with its nails, in a node of its own: the recording shows the old plank in its place.
	var fresh: Node3D = Node3D.new()
	fresh.name = "ReplacedPlank"
	root.add_child(fresh)
	HouseProps.add_box(fresh, "Plank2", Vector3(1.74, 0.04, 0.13), Vector3(0.0, 0.42, 0.15), replaced)
	var nail: StandardMaterial3D = HouseProps.material(Color(0.2, 0.2, 0.21), 0.5, 0.7)
	for sx: float in [-0.75, 0.75]:
		for dz: float in [-0.035, 0.035]:
			HouseProps.add_cylinder(fresh, "Nail%s%s" % ["L" if sx < 0.0 else "R", "a" if dz < 0.0 else "b"], 0.006, 0.003, Vector3(sx, 0.4415, 0.15 + dz), nail)

	_stain(root, "Mould", Vector3(0.3, 0.002, 0.1), Vector3(0.3, 0.443, -0.1), MOLD_DAMP, Vector3(0.0, 15.0, 0.0))
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
