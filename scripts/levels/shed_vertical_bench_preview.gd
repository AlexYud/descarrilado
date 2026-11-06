extends Node3D
class_name ShedVerticalBenchPreview

## A developer LOOK TEST (not part of the game): the waiting shed's bench stood upright on its end against a pillar, with Emily held against its wooden seat like an improvised
## upright stretcher: fully clothed (painted on the basic character), a plain loose cloth over her head, a few broad fabric bands round her and the bench, her hands under the
## lowest band. Nobody else is in the picture. It is a still master shot of the whole arrangement, shown through the recording's own tape look for `hold_seconds` and then
## left standing (the tape's static is shown once, as at the end of a tape).
##
## Run this scene directly (res://scenes/levels/shed_vertical_bench_preview.tscn). Compare the tape look with the clean picture with `vhs_overlay_enabled` (an export on the root
## node; it is the only switch, and it touches no setting). Nothing here is the game's: it uses the real builders for the shelter, the bench and its old plank and the real
## `ArchiveActor` (a local copy of the basic model), builds its own small ground and lamp, and never touches the waiting shed scene, a save, a token or a recording flag.
## Everything is local to this scene: the bench is turned here (the level's bench is never rotated), the head of the character is collapsed on this instance's skeleton only.

const SHELTER_ORIGIN: Vector3 = Vector3(-3.0, 0.0, -5.5)
const FLOOR_Y: float = 0.05
## The shelter's back-west pillar (the cracked one is the front-west one): its centre, in the world of this scene, and its half width.
const PILLAR_CENTRE: Vector3 = Vector3(-5.7, 0.0, -7.0)
const PILLAR_HALF: float = 0.12
## The bench, at its own size: its length (along its long axis) and where its seat's top is over its origin.
const BENCH_HALF_LENGTH: float = 0.87
const SEAT_TOP: float = 0.44
const FERN_MESH: String = "res://assets/models/foliage/medium_foliage_01/medium_foliage_01_mesh.tres"

@export_category("Preview")
## The recording's tape look over the picture (4:3, PLAY, grain, bleeding colour), or the clean picture of the 3D view.
@export var vhs_overlay_enabled: bool = true:
	set(value):
		vhs_overlay_enabled = value
		if is_inside_tree():
			_apply_overlay()
## How long the still is held before the tape's static (seconds); 0 holds it for ever.
@export var hold_seconds: float = 10.0

@export_category("Light")
## The recording's own ambient light is 1.0; the preview lifts it a little so that the wood, the clothing and the bands can be told apart through the tape look (a local adjustment: no new light).
@export var ambient_energy: float = 1.5

@export_category("Camera")
@export var camera_position: Vector3 = Vector3(-3.5, 1.3, -3.0)
@export var camera_target: Vector3 = Vector3(-5.7, 0.95, -6.6)
@export var camera_fov: float = 34.0

@export_category("The bench")
## How far the bench leans back against the pillar (degrees about its foot): its legs rest against the pillar's shaft above the pillar's own foot.
@export var lean_back_degrees: float = 2.4
## Where the foot of the bench stands in front of the pillar's face (metres): clear of the pillar's low foot.
@export var foot_gap: float = 0.06

@export_category("Emily")
@export var emily_scale: float = 0.9
@export var top_colour: Color = Color(0.36, 0.37, 0.42)
@export var trousers_colour: Color = Color(0.07, 0.07, 0.085)
@export var shoes_colour: Color = Color(0.05, 0.05, 0.05)
@export var cloth_colour: Color = Color(0.4, 0.37, 0.31)
@export var band_colour: Color = Color(0.36, 0.32, 0.25)
## The heights (over the floor) of the three bands round her and the bench: chest, hips (over her hands) and knees.
@export var band_heights: Array[float] = [1.2, 0.88, 0.46]
## How tall each band is (the hip band is the broadest: her wrists, at hip height, are under it).
@export var band_sizes: Array[float] = [0.09, 0.19, 0.09]

var bench_pivot: Node3D = null
var emily: ArchiveActor = null
var head_cloth: Node3D = null
var bands: Array[Node3D] = []
var camera: Camera3D = null

var _overlay: ArchiveVideoOverlay = null
var _bench_transform: Transform3D = Transform3D.IDENTITY
var _clock: float = 0.0
var _burst_shown: bool = false


func _ready() -> void:
	_make_environment()
	_make_ground_and_forest()
	_make_shelter()
	_make_bench()
	_make_emily()
	_make_cloth_and_bands()
	_make_camera()
	_apply_overlay()


func _process(delta: float) -> void:
	_clock += delta
	if hold_seconds > 0.0 and _clock >= hold_seconds and not _burst_shown and _overlay != null:
		_burst_shown = true
		_overlay.set_burst(1.0)


# ============================================================
# THE PLACE
# ============================================================

## The recording's own look for the 3D view (no fog, a pale ambient, a little brighter and harder), on a black sky.
func _make_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.56, 0.66)
	environment.ambient_light_energy = ambient_energy
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.25
	environment.adjustment_contrast = 1.08
	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.name = "Environment"
	holder.environment = environment
	add_child(holder)


func _make_ground_and_forest() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	var plane: BoxMesh = BoxMesh.new()
	plane.size = Vector3(80.0, 0.1, 80.0)
	ground.mesh = plane
	var soil: StandardMaterial3D = StandardMaterial3D.new()
	soil.albedo_color = Color(0.07, 0.1, 0.06)
	soil.roughness = 1.0
	ground.material_override = soil
	ground.position = Vector3(0.0, -0.05, 0.0)
	add_child(ground)

	# A ring of the forest's own ferns round the shelter, so that the picture has the clearing's dark edge and not a void.
	var fern: Mesh = load(FERN_MESH) as Mesh
	if fern == null:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1911
	for i: int in 46:
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(7.5, 15.0)
		var plant: MeshInstance3D = MeshInstance3D.new()
		plant.name = "Fern%d" % i
		plant.mesh = fern
		var scale_value: float = rng.randf_range(1.2, 2.6)
		plant.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale_value), SHELTER_ORIGIN + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		add_child(plant)


func _make_shelter() -> void:
	var shelter: ProceduralProp = ProceduralProp.new()
	shelter.name = "Shelter"
	shelter.kind = &"waiting_shelter"
	shelter.position = SHELTER_ORIGIN
	add_child(shelter)

	# The bin of the level, where it stands there.
	var bin: ProceduralProp = ProceduralProp.new()
	bin.name = "ShelterBin"
	bin.kind = &"shelter_bin"
	bin.position = Vector3(-2.1, FLOOR_Y, -6.85)
	add_child(bin)

	# The shelter's lamp, as the level has it (the recording's only light).
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "ShelterLamp"
	lamp.position = Vector3(-3.0, 2.55, -5.2)
	lamp.light_color = Color(0.62, 0.78, 0.9)
	lamp.light_energy = 1.0
	lamp.omni_range = 8.0
	lamp.shadow_enabled = true
	add_child(lamp)


## The bench, the level's own builder at its own size, turned here: its long axis is vertical, its seat faces the camera (+Z), its legs are behind the seat and rest against
## the pillar, and the end of its planks stands on the floor. The recording's version of its front plank (the old one, whole) replaces the repaired one.
func _make_bench() -> void:
	bench_pivot = Node3D.new()
	bench_pivot.name = "UprightBench"
	add_child(bench_pivot)

	var bench: ProceduralProp = ProceduralProp.new()
	bench.name = "Bench"
	bench.kind = &"shelter_bench"
	bench_pivot.add_child(bench)
	var replaced: Node3D = bench.get_node_or_null("ReplacedPlank") as Node3D
	if replaced != null:
		replaced.visible = false
	var archive: ProceduralProp = ProceduralProp.new()
	archive.name = "ShelterArchive"
	archive.kind = &"shelter_archive"
	bench_pivot.add_child(archive)
	var intact: Node3D = archive.get_node_or_null("Intact") as Node3D
	var damaged: Node3D = archive.get_node_or_null("Damaged") as Node3D
	if intact != null:
		intact.visible = true
	if damaged != null:
		damaged.visible = false

	# Bench x (its length) -> up, bench y (the seat's normal) -> toward the camera, bench z -> east. Turned about the foot of its planks so that it leans back a little.
	var upright: Basis = Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT)
	var lean: Basis = Basis(Vector3.RIGHT, deg_to_rad(-lean_back_degrees))
	var foot: Vector3 = Vector3(PILLAR_CENTRE.x, FLOOR_Y, PILLAR_CENTRE.z + PILLAR_HALF + foot_gap)
	_bench_transform = Transform3D(lean * upright, foot + lean * (Vector3.UP * BENCH_HALF_LENGTH))
	bench_pivot.transform = _bench_transform


# ============================================================
# EMILY
# ============================================================

func _make_emily() -> void:
	emily = ArchiveActor.new()
	emily.name = "Emily"
	emily.actor_scale = emily_scale
	emily.life = 0.0
	emily.palette = {
		&"top": top_colour, &"bottom": trousers_colour, &"skin": Color(0.82, 0.68, 0.58), &"hair": Color(0.18, 0.13, 0.1), &"shoes": shoes_colour,
	}
	add_child(emily)
	emily.build()
	var s: float = emily_scale
	var ankle: float = ArchiveActor.ANKLE_HEIGHT * s
	var end: float = 3600.0
	# One ordinary, held pose: standing close to the wood, the shoulders a little rounded, the head lowered, the arms straight down with the hands in against the hips (under the
	# lowest band), the feet together on the floor. Nobody reaches or struggles.
	emily.hold(&"foot_l", 0.0, end, Vector3(0.085 * s, ankle, 0.05 * s))
	emily.hold(&"foot_r", 0.0, end, Vector3(-0.085 * s, ankle, 0.05 * s))
	emily.hold(&"Spine", 0.0, end, Vector3(2.0, 0.0, 0.0))
	emily.hold(&"Spine1", 0.0, end, Vector3(3.0, 0.0, 0.0))
	emily.hold(&"Spine2", 0.0, end, Vector3(4.0, 0.0, 0.0))
	emily.hold(&"Neck", 0.0, end, Vector3(8.0, 0.0, 0.0))
	emily.hold(&"Head", 0.0, end, Vector3(12.0, 0.0, 0.0))
	emily.hold(&"LeftShoulder", 0.0, end, Vector3(0.0, 0.0, 4.0))
	emily.hold(&"RightShoulder", 0.0, end, Vector3(0.0, 0.0, -4.0))
	emily.hold(&"hand_l", 0.0, end, Vector3(0.17 * s, 0.76 * s, 0.02 * s))
	emily.hold(&"hand_r", 0.0, end, Vector3(-0.17 * s, 0.76 * s, 0.02 * s))
	# The character's featureless head is collapsed on this instance (the cloth stands in its place); the shared model is never touched.
	emily.hidden_bones = PackedStringArray(["Head"])
	emily.sample(0.0)

	# Placed: her feet on the floor in front of the seat, her back against its wood (leaning back with the bench).
	var upright_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(-lean_back_degrees))
	emily.global_transform = Transform3D(upright_basis, Vector3(PILLAR_CENTRE.x, FLOOR_Y, PILLAR_CENTRE.z + PILLAR_HALF + foot_gap + 0.5))
	var seat_normal: Vector3 = bench_pivot.global_basis.y
	var seat_point: Vector3 = bench_pivot.global_transform * Vector3(0.0, SEAT_TOP, 0.0)
	var back_vertices: PackedInt32Array = emily.vertices_of(["Hips", "Spine", "Spine1", "Spine2"])
	var skinned: PackedVector3Array = emily.skinned_vertices()
	var nearest: float = 1.0e9
	for index: int in back_vertices:
		nearest = minf(nearest, (emily.to_global(skinned[index]) - seat_point).dot(seat_normal))
	emily.global_position += seat_normal * (0.004 - nearest)


# ============================================================
# THE CLOTH AND THE BANDS
# ============================================================

func _make_cloth_and_bands() -> void:
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = cloth_colour
	cloth.roughness = 1.0
	var strap: StandardMaterial3D = StandardMaterial3D.new()
	strap.albedo_color = band_colour
	strap.roughness = 1.0

	# The head covering: a plain, loose, rounded bag of cloth over where the head is, and down over the neck onto the shoulders (a loose skirt, not a tight cord), a little out of
	# true. The head bone's own point and the neck's give the way the head is turned.
	head_cloth = Node3D.new()
	head_cloth.name = "HeadCloth"
	add_child(head_cloth)
	var neck_at: Vector3 = emily.to_global(emily.bone_point("Neck"))
	var head_at: Vector3 = emily.to_global(emily.bone_point("Head"))
	var up: Vector3 = (head_at - neck_at).normalized()
	var centre: Vector3 = head_at + up * 0.1 * emily_scale
	var dome: MeshInstance3D = _ellipsoid("Dome", centre, Vector3(0.118, 0.0, 0.0), Vector3(0.0, 0.15, 0.0), Vector3(0.0, 0.0, 0.132), cloth)
	head_cloth.add_child(dome)
	dome.global_transform = Transform3D(_aligned(up, emily.global_basis.z) * Basis.from_scale(Vector3(0.106, 0.134, 0.116)), centre)
	var skirt: MeshInstance3D = MeshInstance3D.new()
	skirt.name = "Skirt"
	var tube: CylinderMesh = CylinderMesh.new()
	tube.top_radius = 0.1
	tube.bottom_radius = 0.135
	tube.height = 0.15
	tube.radial_segments = 20
	skirt.mesh = tube
	skirt.material_override = cloth
	head_cloth.add_child(skirt)
	skirt.global_transform = Transform3D(_aligned(up, emily.global_basis.z), centre - up * 0.075)

	# The bands: each a broad strip across her front at its height, wrapping round the edges of the bench to its back. Everything is in the bench's own frame (x up the bench,
	# y out of the seat, z across it), at the front of her body at that height.
	var skin: PackedVector3Array = emily.skinned_vertices()
	for band_index: int in band_heights.size():
		var height: float = band_heights[band_index]
		var band_width: float = band_sizes[band_index]
		var local_x: float = height - FLOOR_Y - BENCH_HALF_LENGTH
		var front: float = SEAT_TOP + 0.02
		for index: int in skin.size():
			var local: Vector3 = bench_pivot.global_transform.affine_inverse() * emily.to_global(skin[index])
			if absf(local.x - local_x) < band_width * 0.5 + 0.05:
				front = maxf(front, local.y)
		var band: Node3D = Node3D.new()
		band.name = "Band%d" % bands.size()
		bench_pivot.add_child(band)
		bands.append(band)
		var half_width: float = 0.3
		_strap_box(band, "Front", strap, Vector3(local_x, front + 0.012, 0.0), Vector3(band_width, 0.024, half_width * 2.0))
		for side: float in [-1.0, 1.0]:
			# Down the side of her and the bench's edge to the planks' underside.
			var depth: float = front + 0.012 - 0.37
			_strap_box(band, "Side%d" % int(side), strap, Vector3(local_x, 0.37 + depth * 0.5, side * (half_width - 0.012)), Vector3(band_width, depth, 0.024))
			_strap_box(band, "Under%d" % int(side), strap, Vector3(local_x, 0.37, side * 0.1), Vector3(band_width, 0.024, 0.2))


func _strap_box(parent: Node3D, box_name: String, material: Material, at: Vector3, size: Vector3) -> void:
	var piece: MeshInstance3D = MeshInstance3D.new()
	piece.name = box_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	piece.mesh = box
	piece.material_override = material
	piece.position = at
	parent.add_child(piece)


func _ellipsoid(piece_name: String, centre: Vector3, axis_x: Vector3, axis_y: Vector3, axis_z: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = piece_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = Transform3D(Basis(axis_x, axis_y, axis_z), centre)
	return instance


## A basis whose up is `up` and whose forward leans toward `hint` (orthogonalised).
func _aligned(up: Vector3, hint: Vector3) -> Basis:
	var forward: Vector3 = (hint - up * hint.dot(up)).normalized()
	var right: Vector3 = up.cross(forward).normalized()
	return Basis(right, up, forward)


# ============================================================
# THE PICTURE
# ============================================================

func _make_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = camera_position
	camera.near = 0.05
	camera.far = 80.0
	add_child(camera)
	camera.look_at(camera_target, Vector3.UP)
	camera.fov = ArchiveVideoOverlay.matched_fov(camera_fov, get_viewport().get_visible_rect().size)
	camera.make_current()


func _apply_overlay() -> void:
	if vhs_overlay_enabled:
		if _overlay == null:
			_overlay = ArchiveVideoOverlay.new()
			# The preview's switch is the one that decides: the tape look is shown whatever the player's own video filter setting is.
			_overlay.force_full_look = true
			add_child(_overlay)
		_overlay.show_picture()
		_overlay.set_burst(1.0 if _burst_shown else 0.0)
	elif _overlay != null:
		_overlay.hide_overlay()
