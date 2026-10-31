extends Node

## The rigged basic model (`rig_basic_model.gd` makes it): a skeleton with Mixamo's bones and hierarchy (no fingers; `mixamorig_` names, as
## Godot imports a Mixamo file), every vertex bound to up to four of them with weights adding up to one, the two sides of the body never
## sharing a limb, and its rest pose the same A-pose as the unrigged model. Run it as a scene; it quits by itself with a non-zero exit
## code on failure.

const RIGGED: String = "res://assets/models/characters/basic_model/basic_model_rigged.tscn"
const PREFIX: String = "mixamorig_"
const BONES: Dictionary = {
	"Hips": "", "Spine": "Hips", "Spine1": "Spine", "Spine2": "Spine1", "Neck": "Spine2", "Head": "Neck", "HeadTop_End": "Head",
	"LeftShoulder": "Spine2", "LeftArm": "LeftShoulder", "LeftForeArm": "LeftArm", "LeftHand": "LeftForeArm",
	"RightShoulder": "Spine2", "RightArm": "RightShoulder", "RightForeArm": "RightArm", "RightHand": "RightForeArm",
	"LeftUpLeg": "Hips", "LeftLeg": "LeftUpLeg", "LeftFoot": "LeftLeg", "LeftToeBase": "LeftFoot", "LeftToe_End": "LeftToeBase",
	"RightUpLeg": "Hips", "RightLeg": "RightUpLeg", "RightFoot": "RightLeg", "RightToeBase": "RightFoot", "RightToe_End": "RightToeBase",
}

var test_failed: bool = false


func _ready() -> void:
	var root: Node3D = (load(RIGGED) as PackedScene).instantiate()
	add_child(root)
	var skeleton: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
	_expect(skeleton != null and skeleton.get_bone_count() == BONES.size(), "the skeleton has Mixamo's %d bones without fingers (%d)" % [BONES.size(), skeleton.get_bone_count() if skeleton != null else -1])

	var wrong: PackedStringArray = PackedStringArray()
	for bone_name: String in BONES:
		var index: int = skeleton.find_bone(PREFIX + bone_name)
		if index < 0:
			wrong.append(bone_name + " missing")
			continue
		var parent_name: String = String(BONES[bone_name])
		var parent: int = skeleton.get_bone_parent(index)
		if (parent_name == "" and parent != -1) or (parent_name != "" and (parent < 0 or skeleton.get_bone_name(parent) != PREFIX + parent_name)):
			wrong.append(bone_name + " has the wrong parent")
	_expect(wrong.is_empty(), "every bone has its Mixamo name and parent (%s)" % ", ".join(wrong))

	var body: MeshInstance3D = skeleton.get_node("Body") as MeshInstance3D
	_expect(body != null and body.skin != null and body.skin.get_bind_count() == BONES.size(), "the body is skinned to all of them")
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	_expect(vertices.size() == 2502 and bones.size() == vertices.size() * 4 and weights.size() == vertices.size() * 4, "every one of the %d vertices has four bones and weights" % vertices.size())

	var worst_sum: float = 0.0
	var crossed: int = 0
	for index: int in vertices.size():
		var sum: float = 0.0
		for slot: int in 4:
			var weight: float = weights[index * 4 + slot]
			sum += weight
			if weight > 0.001:
				var bone_name: String = skeleton.get_bone_name(bones[index * 4 + slot])
				if (bone_name.begins_with(PREFIX + "Left") and vertices[index].x < -0.02) or (bone_name.begins_with(PREFIX + "Right") and vertices[index].x > 0.02):
					crossed += 1
		worst_sum = maxf(worst_sum, absf(sum - 1.0))
	_expect(worst_sum < 0.001, "the weights of every vertex add up to one (worst %.5f off)" % worst_sum)
	_expect(crossed == 0, "no left limb moves a vertex on the right of the body, nor the reverse (%d)" % crossed)

	# Raising the left arm moves the left hand up and the right hand not at all.
	var left_hand: int = skeleton.find_bone(PREFIX + "LeftHand")
	var right_hand: int = skeleton.find_bone(PREFIX + "RightHand")
	var rest_left: Vector3 = skeleton.get_bone_global_pose(left_hand).origin
	var rest_right: Vector3 = skeleton.get_bone_global_pose(right_hand).origin
	skeleton.set_bone_pose_rotation(skeleton.find_bone(PREFIX + "LeftArm"), Quaternion(Vector3.BACK, deg_to_rad(70.0)))
	_expect(skeleton.get_bone_global_pose(left_hand).origin.y > rest_left.y + 0.3 and skeleton.get_bone_global_pose(right_hand).origin.is_equal_approx(rest_right), "turning the left arm raises the left hand (%.2f m) and leaves the right one" % (skeleton.get_bone_global_pose(left_hand).origin.y - rest_left.y))

	print("BASIC_MODEL_RIG_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
