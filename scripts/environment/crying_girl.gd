extends Node3D
class_name CryingGirl

## The girl crying in the wagon: the rigged basic model (`basic_model_rigged.tscn`, a Mixamo skeleton) scaled down to a girl, squatting
## with her head down and her hands over her face, and shaking as she sobs. Built facing +Z with her feet on y 0 (the finale turns her to
## the wall). The body is one colour per part (hair, skin, clothes) from vertex colours made here, so the shared model stays plain.

const MODEL: String = "res://assets/models/characters/basic_model/basic_model_rigged.tscn"
const PREFIX: String = "mixamorig_"

## The model is a 1.83 m adult; she is a girl.
const SCALE: float = 0.72
## The model's ankle is this high above the sole of its foot.
const ANKLE_HEIGHT: float = 0.085

const CLOTH: Color = Color(0.17, 0.2, 0.32)
const SKIN: Color = Color(0.55, 0.42, 0.38)
const HAIR: Color = Color(0.05, 0.04, 0.04)

## The pose (the hips tilted back so that her seat and her flat feet are both on the floor, the back rounded into a hump from the lower back to
## the shoulders, found by trying leg angles until the lowest point of the pelvis and of the feet were level), in degrees: bone name, then rotations applied one after the other in the parent bone's frame (axis, degrees). She sits on the
## floor with her knees drawn up to her chest, her feet flat in front of her, her arms wrapped round her knees and her head down on her
## forearms.
const POSE: Dictionary = {
	"Hips": [[Vector3.RIGHT, -40.0]],
	"LeftUpLeg": [[Vector3.BACK, 6.0], [Vector3.RIGHT, -115.0]],
	"RightUpLeg": [[Vector3.BACK, -6.0], [Vector3.RIGHT, -115.0]],
	"LeftLeg": [[Vector3.RIGHT, 110.0]],
	"RightLeg": [[Vector3.RIGHT, 110.0]],
	"LeftFoot": [[Vector3.RIGHT, 45.0]],
	"RightFoot": [[Vector3.RIGHT, 45.0]],
	"Spine": [[Vector3.RIGHT, 24.0]],
	"Spine1": [[Vector3.RIGHT, 34.0]],
	"Spine2": [[Vector3.RIGHT, 38.0]],
	"Neck": [[Vector3.RIGHT, 20.0]],
	"Head": [[Vector3.BACK, 9.0], [Vector3.RIGHT, 48.0]],
	"LeftShoulder": [[Vector3.BACK, 7.0]],
	"RightShoulder": [[Vector3.BACK, 2.0]],
	"LeftArm": [[Vector3.BACK, -62.0], [Vector3.RIGHT, -98.0]],
	"RightArm": [[Vector3.BACK, 62.0], [Vector3.RIGHT, -98.0]],
	"LeftForeArm": [[Vector3.BACK, -118.0]],
	"RightForeArm": [[Vector3.BACK, 118.0]],
}

## Where she takes up room on the floor, in her own space (x right of her, y being her z, facing +Z): from her back to her feet, side to side.
var footprint: Rect2 = Rect2()
var skeleton: Skeleton3D = null
var body: MeshInstance3D = null
var _rest: Dictionary = {}
var _bones: Dictionary = {}


func _ready() -> void:
	build()


## Makes her (once; `_ready` does it, or the caller before she is in the tree, to know her `footprint`).
func build() -> void:
	if skeleton != null:
		return

	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	skeleton = model.get_node("Skeleton3D") as Skeleton3D
	body = skeleton.get_node("Body") as MeshInstance3D
	for bone: int in skeleton.get_bone_count():
		var short: String = skeleton.get_bone_name(bone).trim_prefix(PREFIX)
		_bones[short] = bone
		_rest[short] = skeleton.get_bone_rest(bone)
	_colour_the_body()
	_squat()
	# She sits on the floor: the model is lowered by how far its lowest point is above y 0.
	var extent: Dictionary = _extent()
	model.position.y = -float(extent["low"]) * SCALE
	footprint = Rect2(Vector2(extent["min_x"], extent["min_z"]) * SCALE, Vector2(float(extent["max_x"]) - float(extent["min_x"]), float(extent["max_z"]) - float(extent["min_z"])) * SCALE)


## The pose (the sob, see `sob`, moves it a little).
func _squat() -> void:
	skeleton.reset_bone_poses()
	for bone_name: String in POSE:
		skeleton.set_bone_pose_rotation(_bones[bone_name], _rotation_of(POSE[bone_name]))


func _rotation_of(steps: Array) -> Quaternion:
	var result: Quaternion = Quaternion.IDENTITY
	for step: Array in steps:
		result = Quaternion(step[0] as Vector3, deg_to_rad(float(step[1]))) * result
	return result


## She sobs: the back heaves slowly, the shoulders jerk quickly and the head nods with them, at game time `t` (seconds).
func sob(t: float) -> void:
	if skeleton == null:
		return

	var heave: float = sin(t * 1.1)
	var jerk: float = maxf(sin(t * 7.5), 0.0) * (0.55 + 0.45 * sin(t * 1.7))
	_add_rotation("Spine", Vector3.RIGHT, heave * 2.0 + jerk * 1.2)
	_add_rotation("Spine2", Vector3.RIGHT, jerk * 1.8)
	_add_rotation("Head", Vector3.RIGHT, jerk * 2.2 + heave * 1.0)
	_add_rotation("LeftShoulder", Vector3.BACK, -jerk * 3.0)
	_add_rotation("RightShoulder", Vector3.BACK, jerk * 3.0)


func _add_rotation(bone_name: String, axis: Vector3, degrees: float) -> void:
	var base: Quaternion = _rotation_of(POSE[bone_name]) if POSE.has(bone_name) else Quaternion.IDENTITY
	skeleton.set_bone_pose_rotation(_bones[bone_name], Quaternion(axis, deg_to_rad(degrees)) * base)


## Hair, skin and clothes: vertex colours from where each vertex is and which bone moves it most.
func _colour_the_body() -> void:
	var source: ArrayMesh = body.mesh as ArrayMesh
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var colours: PackedColorArray = PackedColorArray()
	colours.resize(vertices.size())
	for index: int in vertices.size():
		var main: int = bones[index * 4]
		var best: float = -1.0
		for slot: int in 4:
			if weights[index * 4 + slot] > best:
				best = weights[index * 4 + slot]
				main = bones[index * 4 + slot]
		var bone_name: String = skeleton.get_bone_name(main).trim_prefix(PREFIX)
		var point: Vector3 = vertices[index]
		var colour: Color = CLOTH
		if bone_name.ends_with("Hand") or bone_name == "Neck":
			colour = SKIN
		elif bone_name == "Head":
			# The face is the front of the head below the hairline; the rest of the head is hair.
			colour = SKIN if (point.z > 0.115 and point.y < 0.8) else HAIR
		colours[index] = colour
	arrays[Mesh.ARRAY_COLOR] = colours
	var painted: ArrayMesh = ArrayMesh.new()
	painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	painted.surface_set_material(0, material)
	body.mesh = painted


## The lowest point and the sides of the posed body (in the model's own units): every vertex skinned by hand.
func _extent() -> Dictionary:
	var arrays: Array = (body.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var palette: Array[Transform3D] = []
	for bone: int in skeleton.get_bone_count():
		palette.append(skeleton.get_bone_global_pose(bone) * body.skin.get_bind_pose(bone))
	var result: Dictionary = {"low": 1.0e9, "min_x": 1.0e9, "max_x": -1.0e9, "min_z": 1.0e9, "max_z": -1.0e9}
	for index: int in vertices.size():
		var at: Vector3 = Vector3.ZERO
		for slot: int in 4:
			var weight: float = weights[index * 4 + slot]
			if weight > 0.0:
				at += (palette[bones[index * 4 + slot]] * vertices[index]) * weight
		result["low"] = minf(float(result["low"]), at.y)
		result["min_x"] = minf(float(result["min_x"]), at.x)
		result["max_x"] = maxf(float(result["max_x"]), at.x)
		result["min_z"] = minf(float(result["min_z"]), at.z)
		result["max_z"] = maxf(float(result["max_z"]), at.z)
	return result
