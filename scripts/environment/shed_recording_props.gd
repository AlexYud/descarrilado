class_name ShedRecordingProps
extends RefCounted

## Stand-in models for the waiting shed's recording scene ("The Shelter Stayed Open"), built in code from primitives like the
## rest of the shed (see JunctionProps): the videotape, the camcorder on its tripod, the newspaper clipping with its photograph, the litter
## bin, and the dressing the recording and the aftermath photograph show (the bench's front plank before it was replaced: whole, and broken).
## ProceduralProp calls `build()` for these kinds. No model here has a person in it, or a shape that could be taken for one; the two people of the
## recording are the rigged model, performed by `ShelterFootage`.
##
## Inspectable props (tape, clipping) are built facing +Z with +Y up and centred on the origin, as the inspect view shows them; scenery
## (the camcorder, which is not examined) stands on the ground with the origin at floor level.

const PAPER_NEWS: Color = Color(0.78, 0.74, 0.64)
const INK_DARK: Color = Color(0.1, 0.09, 0.08)

## The aftermath photograph: a colour print of this shelter after the body was removed, captured once from the real shelter's geometry by the
## developer's tool (`scripts/tools/capture_shelter_aftermath.tscn`) and shipped as a texture. It is never drawn or rendered at run time.
const PHOTO_PATH: String = "res://assets/textures/waiting_shed/shelter_aftermath_photo.png"
## The photograph's aspect (width over height).
const PHOTO_ASPECT: float = 4.0 / 3.0


static func has_kind(kind: StringName) -> bool:
	return kind in [&"vhs_tape", &"camcorder", &"newspaper_clipping", &"marina_sister_note", &"helena_clarke_notice", &"shelter_archive", &"shelter_bin"]


static func build(kind: StringName, root: Node3D) -> void:
	match kind:
		&"vhs_tape":
			_build_vhs_tape(root)
		&"camcorder":
			_build_camcorder(root)
		&"newspaper_clipping":
			_build_newspaper_clipping(root)
		&"marina_sister_note":
			_build_marina_sister_note(root)
		&"helena_clarke_notice":
			_build_helena_clarke_notice(root)
		&"shelter_archive":
			_build_shelter_archive(root)
		&"shelter_bin":
			_build_shelter_bin(root)
		_:
			push_warning("ShedRecordingProps: unknown prop kind '%s'." % kind)


# ============================================================
# THE VIDEOTAPE
# ============================================================

## A VHS cassette (not the audio cassette of the fig clearing): black shell, a paper label across the front with the
## handwriting on it, the window with its two reels. 187 x 103 x 25 mm, the label on the +Z face.
static func _build_vhs_tape(root: Node3D) -> void:
	var shell: StandardMaterial3D = HouseProps.material(Color(0.07, 0.07, 0.075), 0.55)
	var plate: StandardMaterial3D = HouseProps.material(Color(0.13, 0.13, 0.14), 0.6)
	var paper: StandardMaterial3D = HouseProps.material(Color(0.84, 0.81, 0.7), 0.95)
	var reel: StandardMaterial3D = HouseProps.material(Color(0.62, 0.62, 0.6), 0.5)
	var window: StandardMaterial3D = HouseProps.glass_material(Color(0.04, 0.04, 0.05, 0.7))

	HouseProps.add_box(root, "Shell", Vector3(0.187, 0.103, 0.025), Vector3.ZERO, shell)
	HouseProps.add_box(root, "FrontPlate", Vector3(0.18, 0.096, 0.002), Vector3(0.0, 0.0, 0.0126), plate)
	# The paper label across the middle of the face.
	HouseProps.add_box(root, "Label", Vector3(0.152, 0.05, 0.0012), Vector3(0.0, -0.012, 0.0141), paper)
	HouseProps.add_box(root, "LabelStripe", Vector3(0.152, 0.004, 0.0013), Vector3(0.0, 0.009, 0.0142), HouseProps.material(Color(0.5, 0.12, 0.1), 0.9))
	# Written in Portuguese on the tape itself, whatever the language of the game.
	HouseProps.add_text(
		root, "LabelText", "ABRIGO / CÓPIA", Vector3(0.0, -0.0105, 0.0149), 28, 0.00042,
		INK_DARK, 0.0, true
	)
	HouseProps.add_text(
		root, "Handwriting", "Devolver na sexta.", Vector3(0.0, -0.0315, 0.0149), 22, 0.0003,
		HouseProps.INK_BLUE, 0.0, true, Vector3(0.0, 0.0, -1.5)
	)

	# The window over the tape, with the two reels.
	HouseProps.add_box(root, "Window", Vector3(0.078, 0.017, 0.0012), Vector3(0.0, 0.0395, 0.0141), window)
	for sx: float in [-0.024, 0.024]:
		HouseProps.add_cylinder(root, "Reel%s" % ("L" if sx < 0.0 else "R"), 0.0072, 0.0014, Vector3(sx, 0.0395, 0.0138), reel, Vector3(90.0, 0.0, 0.0))
	# The seam of the flap, and the write-protect tab on the edge.
	HouseProps.add_box(root, "FlapSeam", Vector3(0.18, 0.0012, 0.0012), Vector3(0.0, 0.0245, 0.0142), shell)
	HouseProps.add_box(root, "Tab", Vector3(0.012, 0.004, 0.008), Vector3(0.07, -0.0515, 0.0), HouseProps.material(Color(0.5, 0.1, 0.08), 0.8))


# ============================================================
# THE CAMCORDER
# ============================================================

## A cylinder between two points, for the legs of the tripod.
static func _strut(parent: Node3D, node_name: String, from: Vector3, to: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 10
	mesh.rings = 1
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = (from + to) * 0.5
	instance.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
	parent.add_child(instance)
	return instance


## An ordinary 1990s camcorder on a tripod, the lens toward -Z, the tripod's foot centre at the origin and the lens 1.33 m up.
## `Head` is the part that turns (the body and the lens on the pan head); `Led` is the recording light (see
## `camcorder_set_recording`) and `LedGlow` the faint red light it throws on the body. Light grey and black, so the
## body, the lens and the legs read when a flashlight finds them: nothing here glows but the light.
static func _build_camcorder(root: Node3D) -> void:
	var shell: StandardMaterial3D = HouseProps.material(Color(0.52, 0.52, 0.54), 0.42, 0.15)
	var dark: StandardMaterial3D = HouseProps.material(Color(0.06, 0.06, 0.07), 0.6)
	var silver: StandardMaterial3D = HouseProps.material(Color(0.72, 0.72, 0.74), 0.3, 0.8)
	var leg_material: StandardMaterial3D = HouseProps.material(Color(0.2, 0.2, 0.22), 0.45, 0.5)
	var glass: StandardMaterial3D = HouseProps.material(Color(0.015, 0.02, 0.035), 0.04, 0.9)
	var head_y: float = 1.2

	# The tripod: three legs from the head to the ground, one of them behind (+Z), and the column.
	var top: Vector3 = Vector3(0.0, head_y - 0.07, 0.0)
	for i: int in 3:
		var angle: float = deg_to_rad(90.0 + 120.0 * i)
		var foot: Vector3 = Vector3(cos(angle) * 0.52, 0.0, sin(angle) * 0.52)
		_strut(root, "Leg%d" % i, top, foot + Vector3(0.0, 0.012, 0.0), 0.011, leg_material)
		HouseProps.add_cylinder(root, "Foot%d" % i, 0.02, 0.024, foot + Vector3(0.0, 0.012, 0.0), dark)
		# A lock on each leg, a third of the way down.
		HouseProps.add_cylinder(root, "Lock%d" % i, 0.016, 0.04, top.lerp(foot, 0.3), silver, Vector3.ZERO)
	HouseProps.add_cylinder(root, "Column", 0.017, 0.2, Vector3(0.0, head_y - 0.12, 0.0), silver)
	HouseProps.add_cylinder(root, "Crown", 0.045, 0.05, Vector3(0.0, head_y - 0.075, 0.0), dark)
	# The pan handle, pointing back and to the right.
	_strut(root, "PanHandle", Vector3(0.02, head_y - 0.04, 0.03), Vector3(0.2, head_y - 0.13, 0.28), 0.007, dark)

	# The part that turns.
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, head_y, 0.0)
	# A full-size shoulder camcorder: a fifth bigger than the plain measures below, so that it is seen across a clearing.
	head.scale = Vector3.ONE * 1.2
	root.add_child(head)

	HouseProps.add_box(head, "Plate", Vector3(0.07, 0.02, 0.12), Vector3(0.0, 0.01, 0.02), dark)
	HouseProps.add_box(head, "Body", Vector3(0.115, 0.13, 0.28), Vector3(0.0, 0.095, 0.02), shell)
	HouseProps.add_box(head, "Underside", Vector3(0.118, 0.028, 0.282), Vector3(0.0, 0.047, 0.02), dark)
	HouseProps.add_box(head, "Seam", Vector3(0.1165, 0.003, 0.282), Vector3(0.0, 0.118, 0.02), dark)
	# The lens: barrel, its bright ring, the glass.
	HouseProps.add_cylinder(head, "LensBarrel", 0.041, 0.1, Vector3(0.0, 0.105, -0.19), dark, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_cylinder(head, "LensRing", 0.046, 0.012, Vector3(0.0, 0.105, -0.242), silver, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_cylinder(head, "LensGlass", 0.033, 0.004, Vector3(0.0, 0.105, -0.249), glass, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_cylinder(head, "LensHood", 0.052, 0.02, Vector3(0.0, 0.105, -0.222), shell, Vector3(90.0, 0.0, 0.0))
	# Viewfinder (back, top left), the handle across the top, the microphone, the strap on the right side, the tape door on the left.
	HouseProps.add_box(head, "Viewfinder", Vector3(0.04, 0.05, 0.12), Vector3(-0.03, 0.185, 0.08), dark)
	HouseProps.add_cylinder(head, "Eyecup", 0.021, 0.025, Vector3(-0.03, 0.185, 0.155), dark, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_box(head, "Handle", Vector3(0.03, 0.016, 0.16), Vector3(0.0, 0.178, -0.02), dark)
	HouseProps.add_box(head, "HandlePostFront", Vector3(0.026, 0.02, 0.02), Vector3(0.0, 0.168, -0.09), dark)
	HouseProps.add_box(head, "HandlePostBack", Vector3(0.026, 0.02, 0.02), Vector3(0.0, 0.168, 0.05), dark)
	HouseProps.add_box(head, "Microphone", Vector3(0.032, 0.03, 0.06), Vector3(0.0, 0.147, -0.12), dark)
	HouseProps.add_box(head, "Strap", Vector3(0.012, 0.1, 0.16), Vector3(0.0635, 0.09, 0.02), dark)
	HouseProps.add_box(head, "TapeDoor", Vector3(0.004, 0.09, 0.16), Vector3(-0.059, 0.09, 0.03), silver)
	# The label plate by the lens, and a worn stripe along the shell.
	HouseProps.add_box(head, "ModelPlate", Vector3(0.05, 0.012, 0.002), Vector3(-0.02, 0.146, -0.1205), silver)

	# The recording light: a small red lens on the front, above the right of the lens barrel. Off: a dull dark red.
	var led_material: StandardMaterial3D = HouseProps.material(Color(0.22, 0.03, 0.03), 0.3)
	led_material.emission_enabled = true
	led_material.emission = Color(1.0, 0.08, 0.05)
	led_material.emission_energy_multiplier = 0.0
	JunctionProps._sphere(head, "Led", 0.0075, 0.015, Vector3(0.04, 0.152, -0.1385), led_material)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.name = "LedGlow"
	glow.position = Vector3(0.04, 0.152, -0.17)
	glow.light_color = Color(1.0, 0.1, 0.06)
	glow.light_energy = 0.0
	glow.omni_range = 0.9
	glow.shadow_enabled = false
	glow.visible = false
	head.add_child(glow)


## The recording light of a camcorder built by `_build_camcorder`, on or off: the red lens lights and throws a little red on the body.
static func camcorder_set_recording(model: Node, recording: bool) -> void:
	var led: MeshInstance3D = model.find_child("Led", true, false) as MeshInstance3D
	if led != null and led.material_override is StandardMaterial3D:
		(led.material_override as StandardMaterial3D).emission_energy_multiplier = 6.0 if recording else 0.0
	var glow: OmniLight3D = model.find_child("LedGlow", true, false) as OmniLight3D
	if glow != null:
		glow.visible = recording
		glow.light_energy = 0.35 if recording else 0.0


# ============================================================
# THE NEWSPAPER CLIPPING
# ============================================================

## A cut-out newspaper column, yellowed and folded once: a headline, the colour print of this shelter after the body was taken away (a white
## border, a pencilled caption under it, held by two scraps of tape), and a few lines of print. The words are read in the inspect view
## (`readable_text`); the print on the model is only strips, so it says the same in every language, except the caption of the photograph. 125 x 165 mm,
## facing +Z.
static func _build_newspaper_clipping(root: Node3D) -> void:
	var ink: StandardMaterial3D = HouseProps.material(Color(0.16, 0.15, 0.13), 1.0)
	var faded: StandardMaterial3D = HouseProps.material(Color(0.3, 0.28, 0.24), 1.0)

	HouseProps._add_paper(root, "Paper", Vector2(0.125, 0.165), Vector3.ZERO, PAPER_NEWS)
	# Yellowed edges and the fold.
	JunctionProps._stain(root, "EdgeStain", Vector3(0.125, 0.014, 0.0003), Vector3(0.0, -0.079, 0.0009), Color(0.62, 0.55, 0.38))
	JunctionProps._stain(root, "FoldLight", Vector3(0.125, 0.0012, 0.0003), Vector3(0.0, 0.004, 0.0009), Color(0.86, 0.82, 0.72))
	JunctionProps._stain(root, "FoldDark", Vector3(0.125, 0.0008, 0.0003), Vector3(0.0, 0.0025, 0.0009), Color(0.46, 0.42, 0.34))

	# The headline: two lines of heavy print.
	HouseProps.add_box(root, "Headline0", Vector3(0.108, 0.011, 0.0004), Vector3(0.0, 0.07, 0.001), ink)
	HouseProps.add_box(root, "Headline1", Vector3(0.082, 0.011, 0.0004), Vector3(-0.013, 0.056, 0.001), ink)

	# The print: a white border all round, the picture inside it (4:3), a little crooked, a scrap of tape at each top corner.
	var mounted: Node3D = Node3D.new()
	mounted.name = "Print"
	mounted.rotation_degrees = Vector3(0.0, 0.0, -1.2)
	root.add_child(mounted)
	var border: StandardMaterial3D = HouseProps.material(Color(0.93, 0.92, 0.88), 0.55)
	HouseProps.add_box(mounted, "PhotoBorder", Vector3(0.108, 0.083, 0.0006), Vector3(0.0, 0.0035, 0.00115), border)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.1, 0.1 / PHOTO_ASPECT)
	var photo_material: StandardMaterial3D = HouseProps.material(Color.WHITE, 0.5)
	photo_material.albedo_texture = load_photo()
	HouseProps._add_mesh(mounted, "Photo", quad, Vector3(0.0, 0.0035, 0.00155), photo_material, Vector3.ZERO)
	var tape: StandardMaterial3D = HouseProps.material(Color(0.78, 0.74, 0.55, 0.85), 0.9)
	tape.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side: float in [-1.0, 1.0]:
		HouseProps.add_box(mounted, "Tape%s" % ("L" if side < 0.0 else "R"), Vector3(0.016, 0.006, 0.0002), Vector3(side * 0.05, 0.0465, 0.0018), tape, Vector3(0.0, 0.0, side * 28.0))
	# The caption, in the language of the text.
	HouseProps.add_paragraphs(root, "PhotoCaption", "PHOTO_CAPTION_SHELTER", Vector3(-0.0505, -0.0425, 0.0011), 12, 0.0002, Color(0.24, 0.22, 0.2), 520.0)

	# A few lines of print under it, in two columns, some shorter.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1990
	for column: int in 2:
		for row: int in 4:
			var length: float = 0.05 if rng.randf() > 0.2 else 0.032
			HouseProps.add_box(
				root, "Line%d_%d" % [column, row], Vector3(length, 0.0034, 0.0004),
				Vector3(-0.0275 + column * 0.055 + (length - 0.05) * 0.5, -0.0545 - row * 0.0085, 0.001), faded
			)


# ============================================================
# THE SISTER'S NOTE
# ============================================================

## The note from Marina's sister: one sheet of lined paper, folded in three and opened out again, its creases still across it, written in dark ink in a
## looser hand than Sophia's. The words are read in the inspect view (`readable_text`); on the model they are only strips. 105 x 145 mm, facing +Z.
static func _build_marina_sister_note(root: Node3D) -> void:
	var ink: StandardMaterial3D = HouseProps.material(Color(0.14, 0.14, 0.17), 1.0)
	var ruling: StandardMaterial3D = HouseProps.material(Color(0.62, 0.68, 0.74), 1.0)

	HouseProps._add_paper(root, "Paper", Vector2(0.105, 0.145), Vector3.ZERO, Color(0.86, 0.84, 0.76))
	# The two folds of a letter folded in three: a light edge and a dark one each.
	for fold_y: float in [0.0242, -0.0242]:
		JunctionProps._stain(root, "FoldLight", Vector3(0.105, 0.0011, 0.0003), Vector3(0.0, fold_y, 0.0009), Color(0.94, 0.92, 0.86))
		JunctionProps._stain(root, "FoldDark", Vector3(0.105, 0.0007, 0.0003), Vector3(0.0, fold_y - 0.0011, 0.0009), Color(0.55, 0.52, 0.45))

	# The ruling, and the handwriting on it: three paragraphs, the last a little longer, the lines a little uneven.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1411
	var rows: Array = [4, 1, 5]
	var line_y: float = 0.061
	for paragraph: int in rows.size():
		for row: int in int(rows[paragraph]):
			HouseProps.add_box(root, "Ruling%d_%d" % [paragraph, row], Vector3(0.093, 0.0005, 0.0003), Vector3(0.0, line_y - 0.0035, 0.0008), ruling)
			var length: float = 0.088 - rng.randf_range(0.0, 0.016) if row < int(rows[paragraph]) - 1 else rng.randf_range(0.03, 0.06)
			var skew: float = rng.randf_range(-0.8, 0.8)
			HouseProps.add_box(root, "Hand%d_%d" % [paragraph, row], Vector3(length, 0.0026, 0.0004), Vector3(-0.0465 + length * 0.5, line_y, 0.001), ink, Vector3(0.0, 0.0, skew))
			line_y -= 0.0092
		line_y -= 0.0075


# ============================================================
# THE RECENT NOTICE (paper pinned to a post)
# ============================================================

## A small recent clipping about the missing woman, pinned by its top edge to a shelter post: newsprint, a heavy headline, a few lines of print and a steel pin.
## 95 x 130 mm, facing +Z (the words are read in the inspect view, `readable_text`).
static func _build_helena_clarke_notice(root: Node3D) -> void:
	var ink: StandardMaterial3D = HouseProps.material(Color(0.16, 0.15, 0.13), 1.0)
	HouseProps._add_paper(root, "Paper", Vector2(0.095, 0.13), Vector3.ZERO, Color(0.84, 0.81, 0.72))
	JunctionProps._stain(root, "EdgeStain", Vector3(0.095, 0.011, 0.0003), Vector3(0.0, -0.062, 0.0009), Color(0.66, 0.6, 0.45))
	HouseProps.add_box(root, "Headline0", Vector3(0.078, 0.01, 0.0004), Vector3(0.0, 0.043, 0.001), ink)
	HouseProps.add_box(root, "Headline1", Vector3(0.056, 0.01, 0.0004), Vector3(-0.011, 0.03, 0.001), ink)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2217
	for row: int in 7:
		var length: float = 0.078 if row < 6 else 0.04
		HouseProps.add_box(root, "Line%d" % row, Vector3(length, 0.0034, 0.0004), Vector3(-0.039 + length * 0.5, 0.008 - 0.0105 * float(row), 0.001), ink)
	_pin(root, Vector3(0.0, 0.056, 0.0016))


## A steel drawing pin through the top of a sheet.
static func _pin(root: Node3D, at: Vector3) -> void:
	var metal: StandardMaterial3D = HouseProps.material(Color(0.62, 0.62, 0.6), 0.4, 0.7)
	var pin: MeshInstance3D = HouseProps.add_cylinder(root, "Pin", 0.0045, 0.003, at, metal, Vector3(90.0, 0.0, 0.0))
	pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The shipped photograph (null, with a warning, if the file is missing: it is art, never generated at run time).
static func load_photo() -> Texture2D:
	if not ResourceLoader.exists(PHOTO_PATH):
		push_warning("ShedRecordingProps: the aftermath photograph %s is missing; run scripts/tools/capture_shelter_aftermath.tscn." % PHOTO_PATH)
		return null
	return load(PHOTO_PATH) as Texture2D


# ============================================================
# THE RECORDING'S DRESSING
# ============================================================

## What the recording and the aftermath photograph show and the present does not, in the bench's own space (place it at the bench): the front plank as
## it was before it was replaced. `Intact` is the recording's (a whole, ordinary old plank like the other two: the bench is in use); `Damaged` is the
## aftermath's (the plank broken at one end with its splinters, a length of it fallen on the floor). Kept hidden; `WaitingShedSequence.set_world_state`
## shows one of them under a cut. No blood is dressed here: the aftermath's blood belongs to the capture tool only.
static func _build_shelter_archive(root: Node3D) -> void:
	var wood: StandardMaterial3D = JunctionProps.weathered(JunctionProps.WOOD_OLD, 3.0, 0.9)
	var raw: StandardMaterial3D = HouseProps.material(Color(0.8, 0.66, 0.44), 0.9)

	var intact: Node3D = Node3D.new()
	intact.name = "Intact"
	intact.visible = false
	root.add_child(intact)
	HouseProps.add_box(intact, "OldPlank", Vector3(1.74, 0.04, 0.13), Vector3(0.0, 0.42, 0.15), wood)

	var damaged: Node3D = Node3D.new()
	damaged.name = "Damaged"
	damaged.visible = false
	root.add_child(damaged)
	# The old front plank: a short length and a drooping, splintered end.
	HouseProps.add_box(damaged, "OldPlank", Vector3(1.1, 0.04, 0.13), Vector3(-0.3, 0.42, 0.15), wood)
	HouseProps.add_box(damaged, "BrokenEnd", Vector3(0.34, 0.04, 0.13), Vector3(0.41, 0.37, 0.15), wood, Vector3(0.0, 0.0, -27.0))
	for i: int in 6:
		HouseProps.add_box(
			damaged, "Splinter%d" % i, Vector3(0.1 + 0.015 * (i % 3), 0.012, 0.012),
			Vector3(0.27 + 0.01 * i, 0.4 + 0.012 * (i % 2), 0.1 + 0.02 * i), raw,
			Vector3(0.0, 8.0 * i - 20.0, 24.0 - 9.0 * i)
		)
	# A length of the plank fallen on the floor.
	HouseProps.add_box(damaged, "FallenPiece", Vector3(0.38, 0.04, 0.12), Vector3(0.62, 0.02, 0.42), wood, Vector3(0.0, 24.0, 2.0))


# ============================================================
# THE BIN
# ============================================================

## A small weathered sheet-metal litter bin, a little out of true, with a few muted wrappers. Public-shelter scenery: no
## controls, nothing in it to find. Origin at the floor.
static func _build_shelter_bin(root: Node3D) -> void:
	var metal: StandardMaterial3D = JunctionProps.weathered(Color(0.27, 0.3, 0.28), 2.5, 0.78, 0.5)
	var rusty: StandardMaterial3D = JunctionProps.weathered(JunctionProps.RUST_DARK, 3.0, 0.9, 0.4)

	var lean: Node3D = Node3D.new()
	lean.name = "Lean"
	lean.rotation_degrees = Vector3(2.5, 0.0, -2.0)
	root.add_child(lean)

	HouseProps.add_cylinder(lean, "Body", 0.17, 0.56, Vector3(0.0, 0.29, 0.0), metal)
	HouseProps.add_cylinder(lean, "Base", 0.175, 0.04, Vector3(0.0, 0.03, 0.0), rusty)
	HouseProps.add_cylinder(lean, "Band", 0.1745, 0.03, Vector3(0.0, 0.34, 0.0), rusty)
	HouseProps.add_cylinder(lean, "Rim", 0.18, 0.026, Vector3(0.0, 0.565, 0.0), metal)
	HouseProps.add_cylinder(lean, "Hollow", 0.155, 0.002, Vector3(0.0, 0.5785, 0.0), HouseProps.black_material())
	JunctionProps._stain(lean, "Dent", Vector3(0.05, 0.12, 0.012), Vector3(0.0, 0.3, 0.168), JunctionProps.CONCRETE_DARK, Vector3(0.0, 0.0, 14.0))

	# A few wrappers: one in the mouth of the bin, two on the floor beside it.
	var wrapper_a: StandardMaterial3D = HouseProps.material(Color(0.42, 0.37, 0.28), 0.9)
	var wrapper_b: StandardMaterial3D = HouseProps.material(Color(0.28, 0.32, 0.34), 0.9)
	HouseProps.add_box(lean, "WrapperTop", Vector3(0.07, 0.05, 0.05), Vector3(0.04, 0.6, 0.02), wrapper_a, Vector3(20.0, 30.0, 15.0))
	HouseProps.add_box(root, "WrapperFloorA", Vector3(0.06, 0.03, 0.045), Vector3(0.24, 0.015, 0.1), wrapper_b, Vector3(0.0, 40.0, 0.0))
	HouseProps.add_box(root, "WrapperFloorB", Vector3(0.05, 0.02, 0.04), Vector3(-0.26, 0.01, 0.2), wrapper_a, Vector3(0.0, -25.0, 0.0))

	HouseProps.add_solid(root, "Solid", Vector3(0.36, 0.58, 0.36), Vector3(0.0, 0.29, 0.0))
