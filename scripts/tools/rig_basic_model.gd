extends SceneTree

## Rigs `basic-model.glb` (one welded humanoid mesh in an A-pose, facing +Z, feet on y -0.975) with a Mixamo skeleton: the same bones and
## hierarchy a Mixamo auto-rig gives (no fingers), named `mixamorig_*` (Godot turns the colon of `mixamorig:Hips` into an underscore on
## import, because a colon would break animation track paths). Every bone's rest rotation is identity (the rest pose is the model's
## A-pose), so posing is a plain local rotation about the bone's joint.
##
## The weights are measured, not painted: each vertex follows the bones whose segments are nearest to it (the nearer, the more), the two
## sides of the body never mix, the arms leave the torso only past the shoulder and the thighs the pelvis only below the hip.
##
## Run it (headless is fine) after changing the landmarks below:
##   Godot --headless --path . -s res://scripts/tools/rig_basic_model.gd
## It writes `basic_model_rigged_mesh.res` and `basic_model_rigged.tscn` next to the model, and `basic_model_rigged.glb` (the same rig for
## Godot's retarget import settings or for Blender).

const SOURCE: String = "res://assets/models/characters/basic_model/basic-model.glb"
const OUT_DIRECTORY: String = "res://assets/models/characters/basic_model/"
const PREFIX: String = "mixamorig_"

## The joints, in metres, in the model's own space (the character's left is +X). Name, parent, position.
const JOINTS: Array = [
	["Hips", "", Vector3(0.0, -0.02, 0.07)],
	["Spine", "Hips", Vector3(0.0, 0.10, 0.075)],
	["Spine1", "Spine", Vector3(0.0, 0.27, 0.08)],
	["Spine2", "Spine1", Vector3(0.0, 0.43, 0.085)],
	["Neck", "Spine2", Vector3(0.0, 0.56, 0.09)],
	["Head", "Neck", Vector3(0.0, 0.64, 0.095)],
	["HeadTop_End", "Head", Vector3(0.0, 0.855, 0.09)],
	["LeftShoulder", "Spine2", Vector3(0.035, 0.53, 0.075)],
	["LeftArm", "LeftShoulder", Vector3(0.18, 0.49, 0.04)],
	["LeftForeArm", "LeftArm", Vector3(0.439, 0.359, 0.03)],
	["LeftHand", "LeftForeArm", Vector3(0.68, 0.237, 0.025)],
	["LeftUpLeg", "Hips", Vector3(0.095, -0.05, 0.08)],
	["LeftLeg", "LeftUpLeg", Vector3(0.09, -0.47, 0.06)],
	["LeftFoot", "LeftLeg", Vector3(0.085, -0.89, -0.02)],
	["LeftToeBase", "LeftFoot", Vector3(0.085, -0.95, 0.11)],
	["LeftToe_End", "LeftToeBase", Vector3(0.085, -0.968, 0.196)],
]

## Where the end of a bone's flesh is when it has no child bone: the tip of the hand.
const HAND_TIP: Vector3 = Vector3(0.755, 0.20, 0.02)
const WEIGHT_POWER: float = 3.0

var _names: Array[String] = []
var _positions: Dictionary = {}
var _parents: Dictionary = {}


func _init() -> void:
	_build_joint_tables()
	var source: Node3D = (load(SOURCE) as PackedScene).instantiate()
	var mesh_instance: MeshInstance3D = source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	var material: Material = mesh_instance.mesh.surface_get_material(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	var segments: Array = _segments()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	bones.resize(vertices.size() * 4)
	weights.resize(vertices.size() * 4)
	var main_count: Dictionary = {}
	for index: int in vertices.size():
		var influence: Array = _influence(vertices[index], segments)
		for slot: int in 4:
			bones[index * 4 + slot] = int(influence[slot][0]) if slot < influence.size() else 0
			weights[index * 4 + slot] = float(influence[slot][1]) if slot < influence.size() else 0.0
		var main: String = _names[int(influence[0][0])]
		main_count[main] = int(main_count.get(main, 0)) + 1

	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	mesh.resource_name = "BasicModelRigged"
	var mesh_path: String = OUT_DIRECTORY + "basic_model_rigged_mesh.res"
	ResourceSaver.save(mesh, mesh_path)
	mesh = load(mesh_path) as ArrayMesh

	var root: Node3D = Node3D.new()
	root.name = "BasicModelRigged"
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root.add_child(skeleton)
	skeleton.owner = root
	for joint: Array in JOINTS_FULL:
		skeleton.add_bone(PREFIX + String(joint[0]))
	for joint: Array in JOINTS_FULL:
		var bone: int = skeleton.find_bone(PREFIX + String(joint[0]))
		var parent_name: String = String(joint[1])
		var local: Vector3 = joint[2]
		if parent_name != "":
			skeleton.set_bone_parent(bone, skeleton.find_bone(PREFIX + parent_name))
			local = joint[2] - _positions[parent_name]
		skeleton.set_bone_rest(bone, Transform3D(Basis.IDENTITY, local))
	skeleton.reset_bone_poses()

	var skin: Skin = Skin.new()
	for bone: int in skeleton.get_bone_count():
		skin.add_bind(bone, skeleton.get_bone_global_rest(bone).affine_inverse())
		skin.set_bind_name(bone, skeleton.get_bone_name(bone))

	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	body.skin = skin
	skeleton.add_child(body)
	body.owner = root
	body.skeleton = NodePath("..")

	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, OUT_DIRECTORY + "basic_model_rigged.tscn")

	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: int = document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, OUT_DIRECTORY + "basic_model_rigged.glb")
	print("RIG written; glb export error code ", error)
	print("RIG bones ", skeleton.get_bone_count(), " vertices ", vertices.size())
	for name: String in main_count:
		print("RIG   ", name, ": ", main_count[name], " vertices")
	quit()


var JOINTS_FULL: Array = []


func _build_joint_tables() -> void:
	JOINTS_FULL.clear()
	for joint: Array in JOINTS:
		JOINTS_FULL.append(joint)
		if String(joint[0]).begins_with("Left"):
			var mirrored: String = "Right" + String(joint[0]).substr(4)
			var parent_name: String = String(joint[1])
			if parent_name.begins_with("Left"):
				parent_name = "Right" + parent_name.substr(4)
			var at: Vector3 = joint[2]
			JOINTS_FULL.append([mirrored, parent_name, Vector3(-at.x, at.y, at.z)])
	_names.clear()
	_positions.clear()
	for joint: Array in JOINTS_FULL:
		_names.append(String(joint[0]))
		_positions[String(joint[0])] = joint[2]
		_parents[String(joint[0])] = String(joint[1])


## Where each bone's flesh runs: from its joint to the next one (bone index, from, to).
func _segments() -> Array:
	var ends: Dictionary = {
		"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "Head": "HeadTop_End",
		"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand",
		"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase", "LeftToeBase": "LeftToe_End",
	}
	var result: Array = []
	for name: String in _names:
		var mirror: String = name
		var side: float = 0.0
		if name.begins_with("Left"):
			side = 1.0
		elif name.begins_with("Right"):
			side = -1.0
			mirror = "Left" + name.substr(5)
		var end_name: String = String(ends.get(mirror, ""))
		var from: Vector3 = _positions[name]
		var to: Vector3
		if mirror == "LeftHand":
			to = Vector3(HAND_TIP.x * (side if side != 0.0 else 1.0), HAND_TIP.y, HAND_TIP.z)
		elif end_name != "":
			to = _positions[(("Right" + end_name.substr(4)) if side < 0.0 else end_name)]
		else:
			continue
		result.append([_names.find(name), from, to, side, mirror])
	return result


## The four bones that move the vertex at `point` and how much each (index, weight), the biggest first, the weights adding up to 1.
func _influence(point: Vector3, segments: Array) -> Array:
	var scored: Array = []
	for segment: Array in segments:
		var side: float = segment[3]
		if side * point.x < -0.012:
			continue

		var from: Vector3 = segment[1]
		var to: Vector3 = segment[2]
		var along: Vector3 = to - from
		var t: float = clampf((point - from).dot(along) / maxf(along.length_squared(), 0.000001), 0.0, 1.0)
		var distance: float = point.distance_to(from + along * t)
		var weight: float = 1.0 / pow(distance + 0.01, WEIGHT_POWER)
		var kind: String = String(segment[4])
		if kind == "LeftArm" or kind == "LeftForeArm" or kind == "LeftHand":
			weight *= smoothstep(0.09, 0.19, absf(point.x))
		elif kind == "LeftUpLeg":
			weight *= smoothstep(0.04, -0.12, point.y)
		scored.append([segment[0], weight])

	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var total: float = 0.0
	var top: Array = []
	for entry: Array in scored:
		if top.size() == 4 or float(entry[1]) <= 0.0:
			break
		top.append(entry)
		total += float(entry[1])
	if top.is_empty() or total <= 0.0:
		return [[0, 1.0]]

	for entry: Array in top:
		entry[1] = float(entry[1]) / total
	return top
