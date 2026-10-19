extends Node3D
class_name FinaleCreature

## What is in the wagon's black corridor door at the end of the game: a pale head that hangs upside-down from the dark above the
## door and swings in, and the two hands that close on Juliana's face. Both are built in code (lofted meshes, a hand with knuckles
## and three-jointed fingers posed with two-bone IK, a face with staring eyes and long black hair); there is no art for them.
##
## Everything is in the wagon's own space (a child of the wagon). The host (`FinaleDoorScene`) calls `play_jumpscare()`, then
## `play_face_drop()` when Juliana falls, and `play_grab()` at the end, and answers the signals.

## `play_jumpscare()`: the head has started to swing, and (a moment after the swing is over) it has stopped.
signal jumpscare_cue
signal jumpscare_done
## `play_grab()`: the hands have closed on her face.
signal grab_done

# The wagon's corridor door: the doorway in the partition at the end of the aisle (measured on the model from its vertices: jambs at x +-0.48,
# the opening 1.72 m high from the floor, the partition 7 cm thick, its front face at wagon-local z 3.75). Beyond it is the vestibule
# (about 3.8 m wide and 2.1 m deep, up to the back wall at z 6.07), which this scene fills with pitch black.
const DOOR_WIDTH: float = 0.96
const DOOR_HEIGHT: float = 1.72

# A grown woman's arm (metres).
const UPPER_ARM: float = 0.30
const FOREARM: float = 0.27
const FINGER_BONES: Array[float] = [0.045, 0.028, 0.022]
const FINGER_SCALE: Array[float] = [0.93, 1.0, 0.94, 0.78]
const THUMB_BONES: Array[float] = [0.04, 0.03]
const PALM_LENGTH: float = 0.095
## How restless the fingers of the hands are (0 still, 1 restless).
const FINGER_TWITCH: float = 0.4

## The head hangs this far (metres) below the pivot above the door.
const FACE_HANG: float = 0.5
## The rod the head hangs from: its top is this high above the floor and this far behind the partition's front face (in the dark
## of the vestibule, hidden by the wall above the door).
const FACE_PIVOT_HEIGHT: float = 1.95
const FACE_PIVOT_BEHIND: float = 0.25
## How far in front of the pivot the head hangs when it is over the middle of the doorway: it ends in the plane of the door, half in
## the dark behind it (the black of the doorway hides the back of the head).
const FACE_OUT: float = 0.25
## The head's movement is in two parts: a short one in the dark, behind the wall, from the side to where it comes into the opening
## (`FACE_ENTRY_ANGLE`), and then the swing that is seen, from there to hanging still in the doorway. The seen swing takes this long.
const JUMPSCARE_SWING_SECONDS: float = 1.0
## The part in the dark: nothing is seen of it, so it is quick, and it sets how soon the head shows after the scare begins.
const JUMPSCARE_LEAD_SECONDS: float = 0.2
## Where the head comes into the doorway (see `face_angle`).
const FACE_ENTRY_ANGLE: float = -0.75
## The drop to the floor (`play_face_drop`): how long the fall takes, how high the head hangs when it has landed (its centre above the
## floor: upside-down, it rests on its hair), and how far it then crawls out of the doorway towards the player, and how slowly.
const FACE_DROP_SECONDS: float = 0.5
const FACE_FLOOR_CLEARANCE: float = 0.16
const FACE_CRAWL_DISTANCE: float = 0.8
const FACE_CRAWL_SECONDS: float = 1.4
## Which way the head swings in from: +1 comes from the right of a player who faces the door (wagon -x), -1 from the left.
const FACE_SIDE: float = 1.0
const FACE_HIDDEN: float = -1.5708
## The head is a little bigger than life, so that it reads from the far end of the walk.
const FACE_SCALE: float = 1.35

## Where the end wall is (wagon-local Z), the floor's height and the aisle's middle.
@export var wall_z: float = 3.75
@export var floor_y: float = 0.073
@export var aisle_x: float = 0.0

## How far the hanging head has swung across the doorway (see `_pose_face`); `FACE_HIDDEN` is level with the pivot, behind the wall.
var face_angle: float = -1.5708
## 0 hangs from the rod, 1 has dropped to the floor (the neck stretches to stay joined to the body above the door).
var face_fall: float = 0.0
## How far, in metres, the fallen head has crawled out of the doorway.
var face_crawl: float = 0.0
## The hands closing on the player's face (`play_grab`): 0 far apart at the sides of the view, 1 both on the face.
var grab_amount: float = 0.0
var grab_mode: bool = false

var _doorway: Node3D = null
var _arms_root: Node3D = null
var _glow: OmniLight3D = null
var _skin: StandardMaterial3D = null
var _cloth: StandardMaterial3D = null
var _hair_material: StandardMaterial3D = null
var _meshes: Dictionary = {}
var _time: float = 0.0
var _generation: int = 0
var _tweens: Array[Tween] = []
var _grab_camera: Transform3D = Transform3D.IDENTITY
var _skin_albedo: Color = Color.WHITE
var _skin_emission: float = 0.03
var _face: Node3D = null
var _face_hair: Node3D = null
var _face_neck: MeshInstance3D = null
var _neck_stretch: MeshInstance3D = null
var _face_skin: StandardMaterial3D = null
var _arms: Array[Dictionary] = []


func _ready() -> void:
	name = "Creature"
	_make_materials()
	_build_doorway()
	_arms_root = Node3D.new()
	_arms_root.name = "Arms"
	add_child(_arms_root)
	for index: int in 2:
		_arms.append(_build_arm(1.0 if index == 0 else -1.0))

	_build_face()
	_glow = OmniLight3D.new()
	_glow.name = "CreatureGlow"
	_glow.light_color = Color(0.72, 0.82, 1.0)
	_glow.light_energy = 0.0
	_glow.omni_range = 3.0
	_glow.shadow_enabled = false
	add_child(_glow)
	_arms_root.visible = false
	_glow.visible = false
	show_doorway(false)


func _process(delta: float) -> void:
	_time += delta
	if grab_mode:
		_pose_grab()

	if _face != null and _face.visible:
		_pose_face(delta)


# ============================================================
# API
# ============================================================

## The black of the corridor door (the vestibule behind it is pitch black).
func show_doorway(on: bool) -> void:
	if _doorway != null:
		_doorway.visible = on


## Back to the start: nothing out of the door.
func reset() -> void:
	face_angle = FACE_HIDDEN
	face_fall = 0.0
	face_crawl = 0.0
	grab_amount = 0.0
	grab_mode = false
	_arms_root.visible = false
	_glow.visible = false
	if _skin != null:
		_skin.albedo_color = _skin_albedo
		_skin.emission_energy_multiplier = _skin_emission
		_skin.rim_enabled = true

	if _face != null:
		_face.visible = false


## Ends what is in progress (it stops between two steps) and everything it was tweening.
func stop() -> void:
	_generation += 1
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()

	_tweens.clear()


# ============================================================
# Helpers
# ============================================================

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


## A tween that `stop()` can kill.
func _new_tween() -> Tween:
	var tween: Tween = create_tween()
	_tweens.append(tween)
	return tween


# ============================================================
# Build
# ============================================================

func _make_materials() -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.seed = 4177
	var mottling: NoiseTexture2D = NoiseTexture2D.new()
	mottling.noise = noise
	mottling.width = 256
	mottling.height = 256
	mottling.seamless = true
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.55, 0.5, 0.5))
	ramp.set_color(1, Color(0.86, 0.8, 0.76))
	mottling.color_ramp = ramp
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = Color(0.7, 0.64, 0.61)
	_skin.albedo_texture = mottling
	_skin.uv1_triplanar = true
	_skin.uv1_scale = Vector3.ONE * 3.0
	_skin.roughness = 0.62
	_skin.rim_enabled = true
	_skin.rim = 0.35
	_skin.rim_tint = 0.5
	_skin.emission_enabled = true
	_skin.emission = Color(0.5, 0.54, 0.6)
	_skin.emission_energy_multiplier = 0.03
	_skin_albedo = _skin.albedo_color
	_skin_emission = _skin.emission_energy_multiplier
	_cloth = StandardMaterial3D.new()
	_cloth.albedo_color = Color(0.36, 0.36, 0.34)
	_cloth.roughness = 1.0
	_hair_material = StandardMaterial3D.new()
	_hair_material.albedo_color = Color(0.025, 0.02, 0.02)
	_hair_material.roughness = 0.85
	_hair_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _build_doorway() -> void:
	_doorway = Node3D.new()
	_doorway.name = "Doorway"
	add_child(_doorway)
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(DOOR_WIDTH, DOOR_HEIGHT)
	var hole: MeshInstance3D = MeshInstance3D.new()
	hole.name = "Black"
	hole.mesh = quad
	hole.material_override = black
	# The quad faces +Z by default; this one faces the aisle (-Z).
	hole.rotation_degrees.y = 180.0
	hole.position = Vector3(aisle_x, floor_y + DOOR_HEIGHT * 0.5, wall_z + 0.05)
	_doorway.add_child(hole)


func _build_arm(side: float) -> Dictionary:
	var upper: MeshInstance3D = _node_with_mesh("UpperArm%s" % ("R" if side > 0.0 else "L"), _tube(UPPER_ARM, [
		Vector3(0.0, 0.043, 0.043), Vector3(0.3, 0.046, 0.047), Vector3(0.75, 0.038, 0.037), Vector3(1.0, 0.032, 0.032),
	], 14), _skin)
	var fore: MeshInstance3D = _node_with_mesh("Forearm%s" % ("R" if side > 0.0 else "L"), _tube(FOREARM, [
		Vector3(0.0, 0.033, 0.033), Vector3(0.22, 0.037, 0.036), Vector3(0.7, 0.028, 0.026), Vector3(1.0, 0.024, 0.018),
	], 14), _skin)
	var hand: Node3D = Node3D.new()
	hand.name = "Hand%s" % ("R" if side > 0.0 else "L")
	_arms_root.add_child(hand)
	# The wrist, then the palm (a tapered slab), knuckles, four fingers and a thumb.
	var palm: MeshInstance3D = _node_with_mesh("Palm", _tube(PALM_LENGTH, [
		Vector3(0.0, 0.026, 0.0135), Vector3(0.5, 0.039, 0.0125), Vector3(1.0, 0.044, 0.0105),
	], 12), _skin, hand)
	palm.position = Vector3.ZERO
	var fingers: Array[Dictionary] = []
	for index: int in 4:
		var x: float = (float(index) - 1.5) * 0.0215 * side
		var base: Node3D = Node3D.new()
		base.name = "Finger%d" % index
		base.position = Vector3(x, 0.0, -PALM_LENGTH)
		hand.add_child(base)
		var finger_scale: float = FINGER_SCALE[index]
		fingers.append({"base": base, "joints": _add_finger(base, FINGER_BONES, finger_scale, 0.0088 - 0.0007 * float(index == 3)), "spread": (float(index) - 1.5) * 7.0 * -side, "phase": float(index) * 1.9 + side, "thumb": false})

	var thumb: Node3D = Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(-side * 0.034, -0.008, -0.03)
	hand.add_child(thumb)
	fingers.append({"base": thumb, "joints": _add_finger(thumb, THUMB_BONES, 1.0, 0.0105), "spread": side * 38.0, "phase": 6.1 + side, "thumb": true})
	return {"side": side, "upper": upper, "fore": fore, "hand": hand, "fingers": fingers}


## A finger: bones in a chain along -Z, each a joint that can curl; returns the joints (a node per bone).
func _add_finger(base: Node3D, bones: Array[float], bone_scale: float, radius: float) -> Array[Node3D]:
	var joints: Array[Node3D] = []
	var parent: Node3D = base
	var at: float = 0.0
	var thickness: float = radius
	for length: float in bones:
		var joint: Node3D = Node3D.new()
		joint.position = Vector3(0.0, 0.0, -at)
		parent.add_child(joint)
		var bone: float = length * bone_scale
		_node_with_mesh("Bone", _tube(bone, [
			Vector3(0.0, thickness, thickness * 0.95), Vector3(0.12, thickness * 1.08, thickness), Vector3(1.0, thickness * 0.82, thickness * 0.78),
		], 8), _skin, joint)
		joints.append(joint)
		parent = joint
		at = bone
		thickness *= 0.82

	return joints


func _node_with_mesh(node_name: String, mesh: Mesh, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	(parent if parent != null else _arms_root).add_child(node)
	return node


# ============================================================
# Meshes
# ============================================================

## A tube along -Z from the origin to `length`, rounded at both ends. `profile` is (t along it from 0 to 1, half width
## in X, half thickness in Y) at each station.
func _tube(length: float, profile: Array[Vector3], sides: int = 12) -> ArrayMesh:
	var key: String = "%f:%s:%d" % [length, str(profile), sides]
	if _meshes.has(key):
		return _meshes[key]

	var points: Array[Vector3] = []
	var radii: Array[Vector2] = []
	var first: Vector3 = profile[0]
	var last: Vector3 = profile[profile.size() - 1]
	# Rounded caps: a few rings that shrink along a quarter circle.
	var cap_us: Array[float] = [1.0, 0.82, 0.58, 0.3]
	for u: float in cap_us:
		var shrink: float = sqrt(maxf(1.0 - u * u, 0.0))
		points.append(Vector3(0.0, 0.0, first.y * u))
		radii.append(Vector2(first.y, first.z) * shrink)

	for station: Vector3 in profile:
		points.append(Vector3(0.0, 0.0, -station.x * length))
		radii.append(Vector2(station.y, station.z))

	for index: int in cap_us.size():
		var u: float = cap_us[cap_us.size() - 1 - index]
		var shrink: float = sqrt(maxf(1.0 - u * u, 0.0))
		points.append(Vector3(0.0, 0.0, -length - last.y * u))
		radii.append(Vector2(last.y, last.z) * shrink)

	var mesh: ArrayMesh = _sweep(points, radii, sides)
	_meshes[key] = mesh
	return mesh


## A smooth surface swept along `points`, with an ellipse of half widths `radii` (x: width, y: thickness) at each.
func _sweep(points: Array[Vector3], radii: Array[Vector2], sides: int) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var rings: Array[PackedVector3Array] = []
	for index: int in points.size():
		var before: Vector3 = points[maxi(index - 1, 0)]
		var after: Vector3 = points[mini(index + 1, points.size() - 1)]
		var tangent: Vector3 = (after - before).normalized()
		var reference: Vector3 = Vector3.RIGHT if absf(tangent.dot(Vector3.RIGHT)) < 0.95 else Vector3.UP

		# `thickness` direction is -Y for a tube along -Z, `width` is X.
		var thickness_axis: Vector3 = tangent.cross(reference).normalized()
		var width_axis: Vector3 = tangent.cross(thickness_axis).normalized()
		if tangent.is_equal_approx(Vector3(0.0, 0.0, -1.0)):
			thickness_axis = Vector3.UP
			width_axis = Vector3.RIGHT

		var ring: PackedVector3Array = PackedVector3Array()
		for side: int in sides:
			var angle: float = TAU * float(side) / float(sides)
			ring.append(points[index] + width_axis * cos(angle) * radii[index].x + thickness_axis * sin(angle) * radii[index].y)
		rings.append(ring)

	for index: int in rings.size() - 1:
		for side: int in sides:
			var next_side: int = (side + 1) % sides
			var a: Vector3 = rings[index][side]
			var b: Vector3 = rings[index][next_side]
			var c: Vector3 = rings[index + 1][next_side]
			var d: Vector3 = rings[index + 1][side]
			surface.add_vertex(a)
			surface.add_vertex(c)
			surface.add_vertex(b)
			surface.add_vertex(a)
			surface.add_vertex(d)
			surface.add_vertex(c)

	surface.generate_normals()
	return surface.commit()


# ============================================================
# The face (the jump scare)
# ============================================================

## The head that swings into the doorway upside down: a pale face, staring eyes, an open mouth, long black hair hanging
## towards the floor. It hangs from the dark above the door (its neck goes up behind the lintel), so only the head is
## ever seen. Nothing but the player's weak flashlight and a tiny glow of the skin shows it: the picture stays dark.
func _build_face() -> void:
	_face = Node3D.new()
	_face.name = "Face"
	add_child(_face)
	_face_skin = StandardMaterial3D.new()
	_face_skin.albedo_color = Color(0.56, 0.54, 0.54)
	_face_skin.roughness = 0.55
	_face_skin.rim_enabled = true
	_face_skin.rim = 0.3
	_face_skin.rim_tint = 0.6
	_face_skin.emission_enabled = true
	_face_skin.emission = Color(0.55, 0.58, 0.64)
	_face_skin.emission_energy_multiplier = 0.04
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.015, 0.01, 0.01)
	dark.roughness = 0.9
	var eye_white: StandardMaterial3D = StandardMaterial3D.new()
	eye_white.albedo_color = Color(0.82, 0.84, 0.84)
	eye_white.roughness = 0.2
	eye_white.emission_enabled = true
	eye_white.emission = Color(0.7, 0.75, 0.75)
	eye_white.emission_energy_multiplier = 0.035
	var lip: StandardMaterial3D = StandardMaterial3D.new()
	lip.albedo_color = Color(0.3, 0.24, 0.25)
	lip.roughness = 0.5

	# The head, in its own space: +Y up through the forehead, -Z the way the face looks.
	var head: Node3D = Node3D.new()
	head.name = "Head"
	_face.add_child(head)
	_face_part(head, _sphere(), Vector3(0.0, 0.0, 0.0), Vector3(0.076, 0.1, 0.088), _face_skin)
	# The jaw and chin.
	_face_part(head, _sphere(), Vector3(0.0, -0.062, -0.014), Vector3(0.056, 0.058, 0.07), _face_skin)
	# The brow, the nose, the cheekbones.
	var brow: CapsuleMesh = CapsuleMesh.new()
	brow.radius = 0.013
	brow.height = 0.125
	var brow_node: MeshInstance3D = _face_part(head, brow, Vector3(0.0, 0.034, -0.073), Vector3.ONE, _face_skin)
	brow_node.rotation_degrees.z = 90.0
	_face_part(head, _sphere(), Vector3(0.0, -0.012, -0.086), Vector3(0.0095, 0.022, 0.015), _face_skin)
	_face_part(head, _sphere(), Vector3(-0.007, -0.031, -0.089), Vector3(0.005, 0.004, 0.004), dark)
	_face_part(head, _sphere(), Vector3(0.007, -0.031, -0.089), Vector3(0.005, 0.004, 0.004), dark)
	for side: float in [-1.0, 1.0]:
		# The eye: a dark socket, the white of the eye, a small black pupil that looks at the player.
		_face_part(head, _sphere(), Vector3(side * 0.031, 0.02, -0.07), Vector3(0.024, 0.0175, 0.016), dark)
		_face_part(head, _sphere(), Vector3(side * 0.031, 0.02, -0.077), Vector3(0.0125, 0.0125, 0.0125), eye_white)
		_face_part(head, _sphere(), Vector3(side * 0.031, 0.02, -0.0895), Vector3(0.0048, 0.0048, 0.0048), dark)
		# The ear.
		_face_part(head, _sphere(), Vector3(side * 0.075, -0.004, 0.0), Vector3(0.006, 0.018, 0.012), _face_skin)

	# The mouth: a dark opening, a little open, between two pale lips.
	_face_part(head, _sphere(), Vector3(0.0, -0.059, -0.076), Vector3(0.022, 0.009, 0.012), dark)
	var upper: CapsuleMesh = CapsuleMesh.new()
	upper.radius = 0.0055
	upper.height = 0.05
	var upper_lip: MeshInstance3D = _face_part(head, upper, Vector3(0.0, -0.05, -0.081), Vector3.ONE, lip)
	upper_lip.rotation_degrees.z = 90.0
	var lower_lip: MeshInstance3D = _face_part(head, upper, Vector3(0.0, -0.069, -0.079), Vector3.ONE, lip)
	lower_lip.rotation_degrees.z = 90.0

	# The neck goes up (world up, which is down in head space) into the dark above the door.
	_face_neck = _node_with_mesh("Neck", _tube(0.4, [Vector3(0.0, 0.03, 0.032), Vector3(1.0, 0.033, 0.035)], 10), _cloth, head)
	_face_neck.position = Vector3(0.0, -0.1, 0.015)
	_face_neck.rotation_degrees.x = -90.0
	# The neck that stretches when the head drops to the floor: a thin tube from the body above the door to the head, laid out by
	# `_pose_face` in the creature's space (top level, so that it is not carried about by the head).
	_neck_stretch = MeshInstance3D.new()
	_neck_stretch.name = "NeckStretch"
	var tube: CylinderMesh = CylinderMesh.new()
	tube.top_radius = 0.034
	tube.bottom_radius = 0.04
	tube.height = 1.0
	tube.radial_segments = 10
	_neck_stretch.mesh = tube
	_neck_stretch.material_override = _cloth
	_neck_stretch.top_level = true
	_neck_stretch.visible = false
	_face.add_child(_neck_stretch)

	# The hair, in the world's frame (it falls towards the floor from the scalp, which is at the bottom of the upside-down head).
	_face_hair = Node3D.new()
	_face_hair.name = "Hair"
	head.add_child(_face_hair)
	_face_hair.rotation_degrees.z = 180.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5531
	for strand: int in 170:
		var angle: float = rng.randf() * TAU
		# On the crown and the back of the head: the front (the face, -Z) is left bare.
		var polar: float = acos(lerpf(0.99, 0.5, rng.randf()))
		var head_root: Vector3 = Vector3(sin(polar) * cos(angle) * 0.078, cos(polar) * 0.101, sin(polar) * sin(angle) * 0.09)
		if head_root.z < -0.012:
			head_root.z = -head_root.z * 0.4
		# In the hair's frame (turned half a turn about Z): x and y change sign.
		var root: Vector3 = Vector3(-head_root.x, -head_root.y, head_root.z)
		var length: float = rng.randf_range(0.3, 0.6)
		var points: Array[Vector3] = []
		var radii: Array[Vector2] = []
		var p: Vector3 = root
		for step: int in 7:
			var t: float = float(step) / 6.0
			points.append(p)
			radii.append(Vector2.ONE * lerpf(0.003, 0.0013, t))
			p += Vector3(root.x * 0.15 * maxf(0.0, 1.0 - t * 2.0), -length / 6.0, root.z * 0.15 * maxf(0.0, 1.0 - t * 2.0)) + Vector3(sin(float(step) * 1.7 + angle) * 0.004, 0.0, cos(float(step) * 1.3 + angle) * 0.004)

		var strand_node: MeshInstance3D = MeshInstance3D.new()
		strand_node.mesh = _sweep(points, radii, 4)
		strand_node.material_override = _hair_material
		_face_hair.add_child(strand_node)

	_face.visible = false


func _sphere() -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return mesh


func _face_part(parent: Node3D, mesh: Mesh, at: Vector3, scale_to: Vector3, material: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.scale = scale_to
	parent.add_child(node)
	return node


## The head hangs from the dark ceiling of the vestibule behind the door (the rest of the body is up there) on a short neck, like
## the hand of a clock: it swings sideways, across the doorway. `face_angle` is the angle of the rod from straight down (radians):
## 0 hangs straight down in the middle of the doorway, negative is out to the side the head comes from (about -pi/2 is level with the
## pivot, behind the wall next to the door, out of sight), positive is the other side. The pivot is behind the partition, up in the
## dark above the lintel: the neck goes up and back behind the top of the door and out of sight, and is never in front of the wall.
## Out at the sides the head is behind the wall; as it comes in over the doorway it comes forward a little (`FACE_OUT`), through
## the opening and in front of the black of the doorway, so that it is seen (the swing plane leans towards the player).
## No light is on it: only the player's own flashlight shows it.
func _pose_face(_delta: float) -> void:
	var pivot: Vector3 = Vector3(aisle_x, floor_y + FACE_PIVOT_HEIGHT, wall_z + FACE_PIVOT_BEHIND)
	var side_angle: float = face_angle * FACE_SIDE
	var forward: float = FACE_OUT * (1.0 - smoothstep(0.3, 0.75, absf(face_angle)))
	var rod: Vector3 = Vector3(sin(side_angle) * FACE_HANG, -cos(side_angle) * FACE_HANG, -forward)
	var hanging: Vector3 = pivot + rod
	# When it has dropped, the head lies a little above the floor, upside-down, and has crawled out of the doorway.
	var landed: Vector3 = Vector3(hanging.x, floor_y + FACE_FLOOR_CLEARANCE, hanging.z - face_crawl)
	_face.position = hanging.lerp(landed, face_fall)
	# The head's own up axis points along the rod, away from the pivot (upside down), and the face looks at the player (-Z).
	var up: Vector3 = rod.normalized()
	var right: Vector3 = up.cross(Vector3.BACK).normalized()
	var back: Vector3 = right.cross(up)
	_face.basis = Basis(right, up, back).scaled(Vector3.ONE * FACE_SCALE)
	# The hair falls straight down whatever the head does.
	_face_hair.global_basis = global_basis
	_pose_stretched_neck(pivot)


## While the head hangs, its own short neck goes up behind the lintel; once it has dropped, a longer one joins it to the body above the door:
## a tube from the pivot to the throat of the head (the head's -Y side), which gets longer as the head falls.
func _pose_stretched_neck(pivot: Vector3) -> void:
	var stretched: bool = face_fall > 0.001
	_face_neck.visible = not stretched
	_neck_stretch.visible = stretched
	if not stretched:
		return

	var throat: Vector3 = _face.position - _face.basis.y.normalized() * 0.1 * FACE_SCALE
	var axis: Vector3 = pivot - throat
	var length: float = maxf(axis.length(), 0.01)
	var up: Vector3 = axis / length
	var right: Vector3 = up.cross(Vector3.BACK).normalized()
	var back: Vector3 = right.cross(up)
	_neck_stretch.global_transform = global_transform * Transform3D(Basis(right, up * length, back), throat + axis * 0.5)


## The head drops to the floor and starts to crawl out of the doorway, after her legs (the host calls it when Juliana falls): it falls in
## `FACE_DROP_SECONDS` (faster and faster) with its neck stretching after it, and then crawls `FACE_CRAWL_DISTANCE` towards the player
## in `FACE_CRAWL_SECONDS`, and stops: from then on it is still.
func play_face_drop() -> void:
	var drop: Tween = _new_tween()
	drop.tween_property(self, "face_fall", 1.0, FACE_DROP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(self, "face_crawl", FACE_CRAWL_DISTANCE, FACE_CRAWL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The scene of the face: after `delay` the head comes out of the dark behind the wall next to the door, like the hand of a clock going
## from three to six. Behind the wall it is quick (`JUMPSCARE_LEAD_SECONDS`, nothing can be seen), so the head shows almost at once; then
## the swing that is seen takes `JUMPSCARE_SWING_SECONDS`: it comes in fast and slows to rest hanging in the middle of the doorway, and
## then it is perfectly still (`jumpscare_cue` the moment it starts). `jumpscare_done` when it has stopped.
func play_jumpscare(delay: float = 0.0) -> void:
	stop()
	var generation: int = _generation
	reset()
	show_doorway(true)
	_face.visible = true
	if delay > 0.0:
		await _wait(delay)
		if generation != _generation:
			return

	# One frame, so the host (who calls this and then waits for the cue) is already waiting.
	await get_tree().process_frame
	if generation != _generation:
		return

	jumpscare_cue.emit()
	var swing: Tween = _new_tween()
	swing.tween_property(self, "face_angle", FACE_ENTRY_ANGLE, JUMPSCARE_LEAD_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	swing.tween_property(self, "face_angle", 0.0, JUMPSCARE_SWING_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _wait(JUMPSCARE_LEAD_SECONDS + JUMPSCARE_SWING_SECONDS)
	if generation != _generation:
		return

	jumpscare_done.emit()


# ============================================================
# The hands on the face (the end)
# ============================================================

## Two hands come in from the edges of the picture and close on the player's face (the end of the scene, won or lost):
## `grab_amount` 0 is hands far apart at the sides of the view, 1 is both on the face, the fingers clawed over it.
## `camera_xf` is the player's camera in the wagon's space. The hands slap shut in `seconds`; done then (`grab_done`).
func play_grab(camera_xf: Transform3D, seconds: float = 0.38) -> void:
	stop()
	var generation: int = _generation
	reset()
	_arms_root.visible = true
	_grab_camera = camera_xf
	grab_amount = 0.0
	grab_mode = true
	# In the dark, out of focus and against the lens a hand is almost black.
	_skin.albedo_color = Color(0.16, 0.14, 0.14)
	_skin.emission_energy_multiplier = 0.0
	_skin.rim_enabled = false
	var close: Tween = _new_tween()
	close.tween_property(self, "grab_amount", 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await close.finished
	if generation != _generation:
		return

	grab_done.emit()


## The host keeps the hands on the face as the view moves (the camera in the wagon's space).
func follow_camera(camera_xf: Transform3D) -> void:
	_grab_camera = camera_xf


## Called every frame while the hands are on their way to the face. From her point of view you do not see two hands, you
## see a dark mass shut over part of your face: one hand comes from the side across her eyes, the other from below over her mouth,
## both a hand's breadth from the lens (so they are huge, out of focus and nearly black), the fingers wrapping round.
func _pose_grab() -> void:
	var cam: Transform3D = _grab_camera
	var forward: Vector3 = -cam.basis.z
	var right: Vector3 = cam.basis.x
	var up: Vector3 = cam.basis.y
	var amount: float = clampf(grab_amount, 0.0, 1.0)
	for rig: Dictionary in _arms:
		var side: float = rig["side"]
		var wrist: Vector3
		var hand_dir: Vector3
		var shoulder: Vector3
		if side > 0.0:
			# Across the eyes, from the right of the view.
			wrist = cam.origin + forward * lerpf(0.4, 0.11, amount) + right * lerpf(0.9, 0.03, amount) + up * lerpf(0.12, 0.045, amount)
			hand_dir = (forward * 0.3 - right * 0.8 + up * 0.35).normalized()
			shoulder = cam.origin - forward * 0.1 + right * 0.26 + up * 0.14
		else:
			# Over the mouth, from below.
			wrist = cam.origin + forward * lerpf(0.4, 0.1, amount) + right * lerpf(-0.55, -0.02, amount) + up * lerpf(-0.75, -0.075, amount)
			hand_dir = (forward * 0.3 + right * 0.55 + up * 0.55).normalized()
			shoulder = cam.origin - forward * 0.1 - right * 0.26 + up * -0.2

		_pose_arm(rig, shoulder, wrist, right * side * 0.8 - up * 0.3, hand_dir, forward)
		_pose_fingers(rig)

	# Next to no light on them: black shapes against a dark picture, with only the flashlight's glow on an edge.
	_glow.visible = true
	_glow.position = cam.origin - forward * 0.15 + up * 0.15
	_glow.light_energy = 0.05


# ============================================================
# Pose
# ============================================================

func _pose_arm(rig: Dictionary, shoulder: Vector3, wrist: Vector3, pole: Vector3, hand_dir: Vector3, back: Vector3) -> void:
	var elbow: Vector3 = _solve(shoulder, wrist, UPPER_ARM, FOREARM, pole)
	var end: Vector3 = shoulder + (wrist - shoulder).normalized() * minf(shoulder.distance_to(wrist), UPPER_ARM + FOREARM - 0.002)
	_place(rig["upper"], shoulder, elbow, Vector3.UP)
	_place(rig["fore"], elbow, end, Vector3.UP)
	var hand: Node3D = rig["hand"]
	hand.transform = Transform3D(_basis_looking(hand_dir, back), end)


## The joint of a two-bone chain from `root` to `target` that bends towards `pole`.
func _solve(root: Vector3, target: Vector3, first: float, second: float, pole: Vector3) -> Vector3:
	var to_target: Vector3 = target - root
	var distance: float = clampf(to_target.length(), 0.05, first + second - 0.002)
	var direction: Vector3 = to_target.normalized() if to_target.length() > 0.0001 else Vector3.DOWN
	var along: float = (first * first - second * second + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(first * first - along * along, 0.0))
	var bend: Vector3 = pole - direction * pole.dot(direction)
	if bend.length() < 0.0001:
		bend = direction.cross(Vector3.UP)

	return root + direction * along + bend.normalized() * height


## The fingers claw over the face: spread wide and curled, closing harder as the hands close.
func _pose_fingers(rig: Dictionary) -> void:
	for finger: Dictionary in rig["fingers"]:
		var base: Node3D = finger["base"]
		var is_thumb: bool = finger["thumb"]
		base.rotation_degrees = Vector3(0.0, float(finger["spread"]) * 2.2, 0.0)
		var joints: Array[Node3D] = finger["joints"]
		var restless: float = (sin(_time * (2.2 + float(finger["phase"]) * 0.5) + float(finger["phase"])) * 0.5 + 0.5) * FINGER_TWITCH
		var curl: Array[float] = [22.0, 34.0, 22.0]
		for joint_index: int in joints.size():
			var bend: float = curl[mini(joint_index, 2)] + restless * 14.0 + grab_amount * 34.0
			if is_thumb:
				bend *= 0.6

			joints[joint_index].rotation_degrees = Vector3(-bend, 0.0, 0.0)


# ============================================================
# Transforms
# ============================================================

## Puts a mesh built along -Z from `from` to `to`.
func _place(node: Node3D, from: Vector3, to: Vector3, up: Vector3) -> void:
	var direction: Vector3 = to - from
	if direction.length() < 0.0001:
		return

	node.transform = Transform3D(_basis_looking(direction.normalized(), up), from)


## A basis whose -Z is `forward` and whose +Y is as near `up` as it can be.
func _basis_looking(forward: Vector3, up: Vector3) -> Basis:
	var hint: Vector3 = up
	if absf(forward.dot(hint.normalized())) > 0.97:
		hint = Vector3.RIGHT if absf(forward.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK

	return Basis.looking_at(forward, hint)
