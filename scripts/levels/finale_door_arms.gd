extends Node3D
class_name FinaleDoorArms

## The thing that comes out of the wagon's black doorway at the very end: a pitch-black opening in the end wall
## and two long, pale arms that slide out of it, hands first, bent at the elbow and twitching, then reach for
## the player. Built from primitives, in the wagon's own space (it is a child of the wagon).
##
## `DreamFinale` drives it with three numbers (all tweened): `emerge` (0 hidden in the dark, 1 out in the aisle),
## `reach` (0 the creeping pose, 1 arms straight at `target_local`, palms in, claws open) and `lunge` (metres the
## whole pair has travelled from the door towards the player). `twitch` is how much the fingers and wrists move.

const DOOR_WIDTH: float = 1.0
const DOOR_HEIGHT: float = 1.9
const UPPER_ARM: float = 0.64
const FOREARM: float = 0.6
const PALM_LENGTH: float = 0.1
## The arms are longer and bigger than a person's, which is what makes them wrong (and they can be seen from the
## far end of the wagon).
const SIZE: float = 1.7
## How far from the shoulder the fingertips are when the arms are straight (the lunge is worked out from it), and
## how far in front of the wall the shoulders stand when the arms are fully out.
const REACH_LENGTH: float = 1.5 * SIZE
const OUT_OFFSET: float = 0.25 * SIZE
const FINGER_BONES: Array[float] = [0.085, 0.065, 0.045]
const THUMB_BONES: Array[float] = [0.06, 0.05]

## Where the end wall is (wagon-local Z) and the floor's height; the black opening is just in front of the wall.
@export var wall_z: float = 6.07
@export var floor_y: float = 0.073

## 0 the arms are hidden behind the door, 1 they are out in the aisle.
var emerge: float = 0.0
## 0 the creeping pose, 1 both arms straight ahead at `target_local`, palms facing in, fingers spread.
var reach: float = 0.0
## How far (metres) the pair has been carried from the door towards the player.
var lunge: float = 0.0
## 0 still, 1 fingers and wrists restless.
var twitch: float = 0.4
## What the arms reach for, in the wagon's space (the player's face).
var target_local: Vector3 = Vector3(0.0, 1.6, 0.0)

var _arms: Node3D = null
var _doorway: Node3D = null
var _glow: OmniLight3D = null
var _rigs: Array[Dictionary] = []
var _skin: StandardMaterial3D = null
var _time: float = 0.0


func _ready() -> void:
	name = "DoorArms"
	_build_doorway()
	_arms = Node3D.new()
	_arms.name = "Arms"
	add_child(_arms)
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = Color(0.5, 0.46, 0.45)
	_skin.roughness = 0.85
	# They glow a very little by themselves, so the pale shapes can be made out against the black.
	_skin.emission_enabled = true
	_skin.emission = Color(0.55, 0.58, 0.64)
	_skin.emission_energy_multiplier = 0.14
	# Left and right, one lower than the other, as in the picture the scene came from.
	_rigs.append(_build_arm(1.0, 1.02))
	_rigs.append(_build_arm(-1.0, 1.36))
	# A cold light just ahead of the fingertips travels with the arms (the doorway's own glow, and later the light of
	# the wagon on the hands that fill the screen).
	_glow = OmniLight3D.new()
	_glow.name = "ArmsGlow"
	_glow.light_color = Color(0.72, 0.82, 1.0)
	_glow.light_energy = 0.0
	_glow.omni_range = 3.4
	_glow.shadow_enabled = false
	_arms.add_child(_glow)
	_glow.position = Vector3(0.0, floor_y + 1.45, wall_z + OUT_OFFSET - REACH_LENGTH - 0.9)
	set_arms_visible(false)
	show_doorway(false)


func _process(delta: float) -> void:
	_time += delta
	# The fingers and wrists never stop while the arms are out, so it is a pose that is alive every frame.
	if _arms != null and _arms.visible:
		_apply_pose()


## The black opening (and its frame) is there only from the moment the lamp over it has died.
func show_doorway(on: bool) -> void:
	if _doorway != null:
		_doorway.visible = on


func set_arms_visible(on: bool) -> void:
	if _arms != null:
		_arms.visible = on

	if _glow != null:
		_glow.visible = on


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
	hole.position = Vector3(0.0, floor_y + DOOR_HEIGHT * 0.5, wall_z - 0.012)
	_doorway.add_child(hole)

	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.1, 0.06, 0.05)
	wood.roughness = 0.9
	var frame: float = 0.07
	var parts: Array[Array] = [
		[Vector3(frame, DOOR_HEIGHT + frame, 0.05), Vector3(-(DOOR_WIDTH + frame) * 0.5, floor_y + (DOOR_HEIGHT + frame) * 0.5, wall_z - 0.03)],
		[Vector3(frame, DOOR_HEIGHT + frame, 0.05), Vector3((DOOR_WIDTH + frame) * 0.5, floor_y + (DOOR_HEIGHT + frame) * 0.5, wall_z - 0.03)],
		[Vector3(DOOR_WIDTH + frame * 2.0, frame, 0.05), Vector3(0.0, floor_y + DOOR_HEIGHT + frame * 0.5, wall_z - 0.03)],
	]
	for part: Array in parts:
		var box: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = part[0]
		box.mesh = mesh
		box.material_override = wood
		box.position = part[1]
		_doorway.add_child(box)


## One arm, built along -Z (towards the aisle) from the shoulder. `side` is +1 for the +X arm, -1 for the other.
## Returns its joints, to be posed every frame.
func _build_arm(side: float, height: float) -> Dictionary:
	var shoulder: Node3D = Node3D.new()
	shoulder.name = "Shoulder%s" % ("R" if side > 0.0 else "L")
	shoulder.scale = Vector3.ONE * SIZE
	_arms.add_child(shoulder)
	_add_bone(shoulder, UPPER_ARM, 0.042)

	var elbow: Node3D = Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0.0, 0.0, -UPPER_ARM)
	shoulder.add_child(elbow)
	_add_bone(elbow, FOREARM, 0.032)

	var wrist: Node3D = Node3D.new()
	wrist.name = "Wrist"
	wrist.position = Vector3(0.0, 0.0, -FOREARM)
	elbow.add_child(wrist)

	var palm: MeshInstance3D = MeshInstance3D.new()
	palm.name = "Palm"
	var palm_mesh: BoxMesh = BoxMesh.new()
	palm_mesh.size = Vector3(0.09, 0.02, PALM_LENGTH)
	palm.mesh = palm_mesh
	palm.material_override = _skin
	palm.position = Vector3(0.0, 0.0, -PALM_LENGTH * 0.5)
	wrist.add_child(palm)

	# Four long fingers fanned out, and a thumb on the inner side.
	var fingers: Array[Dictionary] = []
	for index: int in 4:
		var x: float = (float(index) - 1.5) * 0.024
		var base: Node3D = Node3D.new()
		base.name = "Finger%d" % index
		base.position = Vector3(x, 0.0, -PALM_LENGTH)
		wrist.add_child(base)
		fingers.append({"base": base, "joints": _add_finger(base, FINGER_BONES, 0.0075 - 0.0006 * float(index == 3)), "spread": (float(index) - 1.5) * 9.0 * -side, "phase": float(index) * 1.7 + side})

	var thumb: Node3D = Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(-side * 0.044, 0.0, -0.03)
	wrist.add_child(thumb)
	fingers.append({"base": thumb, "joints": _add_finger(thumb, THUMB_BONES, 0.009), "spread": -side * 48.0, "phase": 5.3 + side, "is_thumb": true})

	return {"side": side, "height": height, "shoulder": shoulder, "elbow": elbow, "wrist": wrist, "fingers": fingers}


## A long capsule from the node's origin to `length` along -Z.
func _add_bone(parent: Node3D, length: float, radius: float) -> void:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	var bone: MeshInstance3D = MeshInstance3D.new()
	bone.mesh = mesh
	bone.material_override = _skin
	bone.rotation_degrees.x = 90.0
	bone.position = Vector3(0.0, 0.0, -length * 0.5)
	parent.add_child(bone)


## A finger: bones in a chain, each one a joint that can curl. Returns the joints.
func _add_finger(base: Node3D, bones: Array[float], radius: float) -> Array[Node3D]:
	var joints: Array[Node3D] = []
	var parent: Node3D = base
	var at: float = 0.0
	for length: float in bones:
		var joint: Node3D = Node3D.new()
		joint.position = Vector3(0.0, 0.0, -at)
		parent.add_child(joint)
		_add_bone(joint, length, radius)
		joints.append(joint)
		parent = joint
		at = length

	return joints


func _apply_pose() -> void:
	var slide: float = clampf(emerge, 0.0, 1.0)
	var grab: float = clampf(reach, 0.0, 1.0)
	_arms.position = Vector3(0.0, 0.0, -lunge)
	_glow.light_energy = 0.35 * smoothstep(0.1, 0.5, slide)
	for rig: Dictionary in _rigs:
		var side: float = rig["side"]
		var shoulder: Node3D = rig["shoulder"]
		var elbow: Node3D = rig["elbow"]
		var wrist: Node3D = rig["wrist"]
		var hand_tremble: float = sin(_time * 13.0 + side) * 0.8 + sin(_time * 5.1 + side * 2.0) * 1.4
		# The creeping pose: upper arm out to the side, elbow bent back in, the hand hanging limp from the wrist.
		var hidden_z: float = wall_z + 1.45 * SIZE
		var out_z: float = wall_z + OUT_OFFSET
		var creep: Vector3 = Vector3(side * 0.22, floor_y + float(rig["height"]), lerpf(hidden_z, out_z, slide))
		# The reach: the shoulders rise to the face and come together, and everything points at it.
		var reach_at: Vector3 = target_local + Vector3(side * 0.32, -0.1, 0.0)
		reach_at.z = out_z
		shoulder.position = creep.lerp(reach_at, grab)
		shoulder.rotation_degrees = Vector3(
			lerpf(-6.0, 0.0, grab) + hand_tremble * 0.3,
			lerpf(-side * 10.0, side * 4.0, grab),
			0.0
		)
		elbow.rotation_degrees = Vector3(lerpf(8.0, 0.0, grab), lerpf(side * 34.0, 0.0, grab), 0.0)
		wrist.rotation_degrees = Vector3(lerpf(-22.0, 6.0, grab) + hand_tremble, 0.0, lerpf(side * 4.0, -side * 38.0, grab) + hand_tremble * 0.6)
		var curl: float = lerpf(0.35, 0.22, grab)
		for finger: Dictionary in rig["fingers"]:
			var base: Node3D = finger["base"]
			var spread: float = float(finger["spread"]) * lerpf(0.7, 2.1, grab)
			base.rotation_degrees = Vector3(0.0, spread, 0.0)
			var joints: Array[Node3D] = finger["joints"]
			var restless: float = sin(_time * (3.0 + float(finger["phase"])) + float(finger["phase"])) * 0.5 + 0.5
			var bend: float = curl + restless * 0.55 * twitch * (1.0 - grab * 0.8)
			for joint_index: int in joints.size():
				var weight: float = 1.0 + float(joint_index) * 0.45
				joints[joint_index].rotation_degrees = Vector3(-bend * 34.0 * weight, 0.0, 0.0)
