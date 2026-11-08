extends RefCounted
class_name MixamoPose

## A Mixamo animation (an FBX imported without a skin: a skeleton and one clip) read for the project's rigged basic model (`basic_model_rigged.tscn`, a Mixamo-named skeleton with identity rests, sloping arms and no fingers):
## `sample` gives the rotation of each of OUR bones at a time of the clip. The retargeting is done in global space: a bone's turn from the source's rest pose is the same turn on ours, on top of the turn that takes
## our bone's rest direction (toward its child) to the source's, so that our A-pose arms and the source's T-pose arms end up where the animation puts them. Positions are not retargeted but for the hips (`hips_offset`).
## (The crawling shadow, `ShadowCrawler`, has its own copy of this for its own clip.)

const PREFIX: String = "mixamorig_"
## How far under the model's own origin the soles of the rigged model are.
const MODEL_FLOOR: float = 0.975
## The child each bone points to, to measure its rest direction; the others (head, hands, feet) take their parent's.
const REST_CHILD: Dictionary = {"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "LeftShoulder": "LeftArm", "RightShoulder": "RightArm", "LeftArm": "LeftForeArm", "RightArm": "RightForeArm", "LeftForeArm": "LeftHand", "RightForeArm": "RightHand", "LeftUpLeg": "LeftLeg", "RightUpLeg": "RightLeg", "LeftLeg": "LeftFoot", "RightLeg": "RightFoot"}

var clip: Animation = null
var length: float = 0.0
var hips_scale: float = 1.0

var _names: PackedStringArray = PackedStringArray()
var _parent: PackedInt32Array = PackedInt32Array()
var _rest_local: Array[Quaternion] = []
var _rest_global: Array[Quaternion] = []
var _rot_track: PackedInt32Array = PackedInt32Array()
var _hips_track: int = -1
var _hips_rest: Vector3 = Vector3.ZERO
var _our_to_src: PackedInt32Array = PackedInt32Array()
var _our_fix: Array[Quaternion] = []
var _our_hips: int = -1


## Reads `path` for `skeleton` (ours; `bones` maps our bone names without the prefix to their indices). Null if the file is missing or its bones are not these.
static func load_clip(path: String, skeleton: Skeleton3D, bones: Dictionary) -> MixamoPose:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null or skeleton == null or not bones.has("Hips"):
		return null

	var source: Node = packed.instantiate()
	var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source_skeleton: Skeleton3D = source.find_child("Skeleton3D", true, false) as Skeleton3D
	if player == null or source_skeleton == null or player.get_animation_list().is_empty():
		source.free()
		return null

	var pose: MixamoPose = MixamoPose.new()
	pose.clip = player.get_animation(player.get_animation_list()[0])
	pose.length = pose.clip.length
	var count: int = source_skeleton.get_bone_count()
	pose._names.resize(count)
	pose._parent.resize(count)
	pose._rot_track.resize(count)
	pose._rest_local.resize(count)
	pose._rest_global.resize(count)
	var by_name: Dictionary = {}
	for s: int in count:
		var bone_name: String = source_skeleton.get_bone_name(s).trim_prefix(PREFIX)
		pose._names[s] = bone_name
		by_name[bone_name] = s
		pose._parent[s] = source_skeleton.get_bone_parent(s)
		pose._rest_local[s] = source_skeleton.get_bone_rest(s).basis.get_rotation_quaternion()
		var parent_rotation: Quaternion = Quaternion.IDENTITY if pose._parent[s] < 0 else pose._rest_global[pose._parent[s]]
		pose._rest_global[s] = parent_rotation * pose._rest_local[s]
		pose._rot_track[s] = pose.clip.find_track(NodePath("Skeleton3D:" + source_skeleton.get_bone_name(s)), Animation.TYPE_ROTATION_3D)
	var hips: int = int(by_name.get("Hips", -1))
	if hips < 0:
		source.free()
		return null

	pose._hips_track = pose.clip.find_track(NodePath("Skeleton3D:" + source_skeleton.get_bone_name(hips)), Animation.TYPE_POSITION_3D)
	pose._hips_rest = source_skeleton.get_bone_rest(hips).origin
	pose._our_hips = int(bones["Hips"])
	pose.hips_scale = (skeleton.get_bone_rest(pose._our_hips).origin.y + MODEL_FLOOR) / maxf(pose._hips_rest.y, 0.1)
	var total: int = skeleton.get_bone_count()
	pose._our_to_src.resize(total)
	pose._our_fix.resize(total)
	var missing: int = 0
	for b: int in total:
		var own_name: String = skeleton.get_bone_name(b).trim_prefix(PREFIX)
		pose._our_to_src[b] = int(by_name.get(own_name, -1))
		if pose._our_to_src[b] < 0:
			missing += 1
		var fix: Quaternion = Quaternion.IDENTITY
		var child_name: String = String(REST_CHILD.get(own_name, ""))
		if child_name != "" and bones.has(child_name) and by_name.has(own_name) and by_name.has(child_name):
			var ours_vector: Vector3 = skeleton.get_bone_global_rest(int(bones[child_name])).origin - skeleton.get_bone_global_rest(b).origin
			var source_vector: Vector3 = source_skeleton.get_bone_global_rest(int(by_name[child_name])).origin - source_skeleton.get_bone_global_rest(int(by_name[own_name])).origin
			if ours_vector.length() > 0.001 and source_vector.length() > 0.001:
				fix = Quaternion(ours_vector.normalized(), source_vector.normalized())
		elif child_name == "":
			var parent_bone: int = skeleton.get_bone_parent(b)
			if parent_bone >= 0 and parent_bone < b:
				fix = pose._our_fix[parent_bone]
		pose._our_fix[b] = fix
	source.free()
	if pose._hips_track < 0 or missing > 0:
		return null
	return pose


## The local rotation of each of our bones (by index) at `time` seconds of the clip.
func sample(skeleton: Skeleton3D, time: float) -> Array[Quaternion]:
	var clock: float = clampf(time, 0.0, length)
	var count: int = _names.size()
	var source_global: Array[Quaternion] = []
	source_global.resize(count)
	for s: int in count:
		var local: Quaternion = _rest_local[s]
		if _rot_track[s] >= 0:
			local = clip.rotation_track_interpolate(_rot_track[s], clock)
		source_global[s] = local if _parent[s] < 0 else source_global[_parent[s]] * local
	var total: int = skeleton.get_bone_count()
	var turned: Array[Quaternion] = []
	turned.resize(total)
	var result: Array[Quaternion] = []
	result.resize(total)
	for b: int in total:
		var s: int = _our_to_src[b]
		var turn: Quaternion = (source_global[s] * _rest_global[s].inverse() * _our_fix[b]) if s >= 0 else Quaternion.IDENTITY
		turned[b] = turn
		var parent: int = skeleton.get_bone_parent(b)
		var parent_turn: Quaternion = Quaternion.IDENTITY if parent < 0 else turned[parent]
		result[b] = parent_turn.inverse() * turn
	return result


## How far the clip's hips are from their rest at `time` (our units), for the hips' own position.
func hips_offset(time: float) -> Vector3:
	return (clip.position_track_interpolate(_hips_track, clampf(time, 0.0, length)) - _hips_rest) * hips_scale
