extends Node3D
class_name ArchiveActor

## One of the two adults of the waiting shed's archival recording (`ShelterFootage`): a LOCAL copy of the rigged basic model
## (`basic_model_rigged.tscn`, a Mixamo skeleton of 25 bones with no fingers, no jaw and no blend shapes; the shared scene, its rest pose
## and its mesh are never touched, the body's mesh is a painted copy of its own), scaled to the adult it plays.
##
## The skeleton has exactly ONE writer: `sample(time)`. There is no AnimationPlayer or AnimationTree on this model, and none is added:
## every pose is a pure function of the time asked for, built from keyed channels (so a seek, a replay or a pause can never leave
## anything half done):
##   - bone channels, named like the bone without its prefix (`Hips`, `Spine`, `Spine1`, `Spine2`, `Neck`, `Head`, `LeftShoulder`,
##     `RightShoulder`): Euler degrees (x leans forward, y turns to the model's left, z rolls to its right) over the bone's rest;
##   - `hips_at`: where the hips bone is, in the actor's frame (metres; the origin is on the floor, +Z forward, +X to the actor's left);
##   - `hand_l`, `hand_r`: where each wrist is; `foot_l`, `foot_r`: where each ankle is; `yaw_l`, `yaw_r` (x, degrees): how each foot is
##     turned about the vertical. Arms and legs are solved from these by a two-bone solution (the rotations come from the rig's own rest
##     directions and bone lengths, not from angles tried on another rig), the feet are kept flat, and a planted foot is simply a
##     channel that does not move.
## Channels are interpolated with a monotone cubic (it never overshoots a hold and has no stop at a key), so overlapping moves read as
## one continuous gesture. A barely-there breathing and weight drift (`life`) is added on the spine and the head, as a sum of slow
## sines of the time: restrained, never periodic enough to look looped, never a tremor.
##
## It is archive picture only: no collision, nothing to interact with, no controller of its own.

const MODEL: String = "res://assets/models/characters/basic_model/basic_model_rigged.tscn"
const PREFIX: String = "mixamorig_"

const BONE_CHANNELS: Array[String] = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "RightShoulder"]
## How far along the hand its middle is from the wrist (model units): the mitten is 7.5 cm long.
## The A-pose's rest: how far the ankle is over the sole (model units).
const ANKLE_HEIGHT: float = 0.085

## The adult's height as a fraction of the 1.83 m model.
@export var actor_scale: float = 1.0
## Weights of the breathing and drift (0 is perfectly still).
@export var life: float = 1.0
## Colours by region: &"top", &"bottom", &"skin", &"hair", &"shoes".
var palette: Dictionary = {
	&"top": Color(0.4, 0.4, 0.42), &"bottom": Color(0.2, 0.2, 0.22), &"skin": Color(0.62, 0.5, 0.42),
	&"hair": Color(0.1, 0.08, 0.07), &"shoes": Color(0.12, 0.11, 0.1),
}
## A phase that makes this actor's breathing and drift their own.
var life_phase: float = 0.0
## Knee and elbow poles, in the actor's frame (the direction the joint bends toward).
var knee_pole_l: Vector3 = Vector3(0.25, 0.3, 1.0)
var knee_pole_r: Vector3 = Vector3(-0.25, 0.3, 1.0)
var elbow_pole_l: Vector3 = Vector3(0.5, -1.0, -0.35)
var elbow_pole_r: Vector3 = Vector3(-0.5, -1.0, -0.35)

var skeleton: Skeleton3D = null
var body: MeshInstance3D = null
## Where the lowest vertex of the model's feet is in its own units (the model stands this far under its origin).
var feet_low: float = -0.975
## How far the last solved wrists and ankles were from where the channels asked (metres, at the actor's scale).
var reach_error: Dictionary = {}

var _model: Node3D = null
var _bones: Dictionary = {}
var _rotations: Dictionary = {}
var _hips_model: Vector3 = Vector3.ZERO
var _tracks: Dictionary = {}
var _vertices: PackedVector3Array = PackedVector3Array()
var _bone_ids: PackedInt32Array = PackedInt32Array()
var _weights: PackedFloat32Array = PackedFloat32Array()
var _main_bone: PackedStringArray = PackedStringArray()
var _sampled_at: float = -1.0e9
## Added to the hips' height (see `settle_hips_on_floor`).
var hips_shift: float = 0.0


## Makes the local model (once). `palette` and `actor_scale` are set before.
func build() -> void:
	if skeleton != null:
		return

	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	skeleton = _model.get_node("Skeleton3D") as Skeleton3D
	body = skeleton.get_node("Body") as MeshInstance3D
	for bone: int in skeleton.get_bone_count():
		_bones[skeleton.get_bone_name(bone).trim_prefix(PREFIX)] = bone
	_read_mesh()
	_paint()
	_model.scale = Vector3.ONE * actor_scale
	_model.position.y = -feet_low * actor_scale
	body.extra_cull_margin = 1.5
	sample(0.0)


func _read_mesh() -> void:
	var arrays: Array = (body.mesh as ArrayMesh).surface_get_arrays(0)
	_vertices = arrays[Mesh.ARRAY_VERTEX]
	_bone_ids = arrays[Mesh.ARRAY_BONES]
	_weights = arrays[Mesh.ARRAY_WEIGHTS]
	_main_bone.resize(_vertices.size())
	var low: float = 1.0e9
	for index: int in _vertices.size():
		var main: int = _bone_ids[index * 4]
		var best: float = -1.0
		for slot: int in 4:
			if _weights[index * 4 + slot] > best:
				best = _weights[index * 4 + slot]
				main = _bone_ids[index * 4 + slot]
		var bone_name: String = skeleton.get_bone_name(main).trim_prefix(PREFIX)
		_main_bone[index] = bone_name
		if bone_name.ends_with("ToeBase") or bone_name.ends_with("Foot"):
			low = minf(low, _vertices[index].y)
	feet_low = low


## A painted copy of the body for this actor alone: clothes, skin and hair by the bone that moves each vertex most. The shared mesh and its
## look are untouched.
func _paint() -> void:
	var source: ArrayMesh = body.mesh as ArrayMesh
	var arrays: Array = source.surface_get_arrays(0)
	var colours: PackedColorArray = PackedColorArray()
	colours.resize(_vertices.size())
	for index: int in _vertices.size():
		var bone_name: String = _main_bone[index]
		var colour: Color = palette[&"top"]
		if bone_name.ends_with("Hand") or bone_name == "Neck":
			colour = palette[&"skin"]
		elif bone_name == "Head":
			colour = palette[&"skin"] if (_vertices[index].z > 0.115 and _vertices[index].y < 0.8) else palette[&"hair"]
		elif bone_name.ends_with("ToeBase") or bone_name.ends_with("Foot"):
			colour = palette[&"shoes"]
		elif bone_name == "Hips" or bone_name.ends_with("UpLeg") or bone_name.ends_with("Leg"):
			colour = palette[&"bottom"]
		colours[index] = colour
	arrays[Mesh.ARRAY_COLOR] = colours
	var painted: ArrayMesh = ArrayMesh.new()
	painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# The palette is written as the colours one sees (sRGB), not as linear light.
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	painted.surface_set_material(0, material)
	body.mesh = painted


# ============================================================
# THE CHANNELS
# ============================================================

## A key of a channel (times must not go back). Bone channels and the foot yaws are degrees (Vector3), the others metres.
func key(channel: StringName, time: float, value: Vector3) -> void:
	if not _tracks.has(channel):
		_tracks[channel] = {"times": PackedFloat32Array(), "values": [], "slopes": []}
	var track: Dictionary = _tracks[channel]
	var times: PackedFloat32Array = track["times"]
	assert(times.is_empty() or time >= times[times.size() - 1], "keys of '%s' go back in time" % channel)
	times.append(time)
	track["times"] = times
	(track["values"] as Array).append(value)
	track["slopes"] = []


## A whole channel at once: the keys' times (strictly increasing) and their values (the same count).
func set_channel(channel: StringName, times: PackedFloat32Array, values: Array) -> void:
	assert(times.size() == values.size() and not times.is_empty(), "set_channel needs matching, non-empty keys")
	_tracks[channel] = {"times": times.duplicate(), "values": values.duplicate(), "slopes": []}


## The channel is `value` from `from` to `to` (two keys).
func hold(channel: StringName, from: float, to: float, value: Vector3) -> void:
	key(channel, from, value)
	if to > from:
		key(channel, to, value)


## A channel's value at `time`: a monotone cubic through its keys (`fallback` when it has none).
func value_at(channel: StringName, time: float, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if not _tracks.has(channel):
		return fallback

	var track: Dictionary = _tracks[channel]
	var times: PackedFloat32Array = track["times"]
	var values: Array = track["values"]
	var count: int = times.size()
	if time <= times[0]:
		return values[0]
	if time >= times[count - 1]:
		return values[count - 1]

	if (track["slopes"] as Array).size() != count:
		track["slopes"] = _slopes(times, values)
	var slopes: Array = track["slopes"]
	# The first key at or after the time (binary search: the walking channels have hundreds of keys).
	var low: int = 1
	var high: int = count - 1
	while low < high:
		var middle: int = (low + high) / 2
		if times[middle] < time:
			low = middle + 1
		else:
			high = middle
	var right: int = low
	var left: int = right - 1
	var h: float = times[right] - times[left]
	var u: float = (time - times[left]) / h
	var u2: float = u * u
	var u3: float = u2 * u
	var a: Vector3 = values[left]
	var b: Vector3 = values[right]
	return (
		a * (2.0 * u3 - 3.0 * u2 + 1.0) + (slopes[left] as Vector3) * (h * (u3 - 2.0 * u2 + u))
		+ b * (-2.0 * u3 + 3.0 * u2) + (slopes[right] as Vector3) * (h * (u3 - u2))
	)


## Tangents at the keys that keep each component monotone between them (Fritsch-Carlson): zero at the ends and at a hold or a turning
## point, so a value never overshoots; elsewhere a weighted harmonic mean of the neighbouring slopes.
func _slopes(times: PackedFloat32Array, values: Array) -> Array:
	var count: int = times.size()
	var result: Array = []
	for k: int in count:
		var slope: Vector3 = Vector3.ZERO
		if k > 0 and k < count - 1:
			var h0: float = times[k] - times[k - 1]
			var h1: float = times[k + 1] - times[k]
			var d0: Vector3 = ((values[k] as Vector3) - (values[k - 1] as Vector3)) / h0
			var d1: Vector3 = ((values[k + 1] as Vector3) - (values[k] as Vector3)) / h1
			for axis: int in 3:
				if d0[axis] * d1[axis] > 0.0:
					var w0: float = 2.0 * h1 + h0
					var w1: float = h1 + 2.0 * h0
					slope[axis] = (w0 + w1) / (w0 / d0[axis] + w1 / d1[axis])
		result.append(slope)
	return result


# ============================================================
# THE POSE
# ============================================================

## The model's point for a point of the actor's frame, and back.
func to_model(point: Vector3) -> Vector3:
	return point / actor_scale + Vector3(0.0, feet_low, 0.0)


func from_model(point: Vector3) -> Vector3:
	return (point - Vector3(0.0, feet_low, 0.0)) * actor_scale


## Poses the skeleton as it is `time` seconds into the footage. The one place a bone is written.
func sample(time: float) -> void:
	if skeleton == null:
		return

	_sampled_at = time
	_rotations.clear()
	var standing: Vector3 = Vector3(0.0, (-0.02 - feet_low) * actor_scale, 0.07 * actor_scale)
	_hips_model = to_model(value_at(&"hips_at", time, standing) + Vector3(0.0, hips_shift, 0.0))
	for channel: String in BONE_CHANNELS:
		var degrees: Vector3 = value_at(StringName(channel), time) + _drift(channel, time)
		_set_rotation(int(_bones[channel]), Quaternion.from_euler(degrees * (PI / 180.0)))

	reach_error[&"foot_l"] = _two_bone("LeftUpLeg", "LeftLeg", "LeftFoot", to_model(value_at(&"foot_l", time, Vector3(0.085, ANKLE_HEIGHT, 0.05) * actor_scale)), knee_pole_l)
	reach_error[&"foot_r"] = _two_bone("RightUpLeg", "RightLeg", "RightFoot", to_model(value_at(&"foot_r", time, Vector3(-0.085, ANKLE_HEIGHT, 0.05) * actor_scale)), knee_pole_r)
	reach_error[&"hand_l"] = _two_bone("LeftArm", "LeftForeArm", "LeftHand", to_model(value_at(&"hand_l", time, Vector3(0.25, 0.8, 0.03) * actor_scale)), elbow_pole_l)
	reach_error[&"hand_r"] = _two_bone("RightArm", "RightForeArm", "RightHand", to_model(value_at(&"hand_r", time, Vector3(-0.25, 0.8, 0.03) * actor_scale)), elbow_pole_r)
	# The soles flat on the floor, turned by their own yaw.
	for side: String in ["Left", "Right"]:
		var yaw: float = value_at(&"yaw_l" if side == "Left" else &"yaw_r", time).x
		var foot: int = int(_bones[side + "Foot"])
		var parent: Quaternion = _global_pose(skeleton.get_bone_parent(foot)).basis.get_rotation_quaternion()
		_set_rotation(foot, parent.inverse() * Quaternion(Vector3.UP, deg_to_rad(yaw)))

	for bone: int in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(bone, _rotations.get(bone, Quaternion.IDENTITY) as Quaternion)
	skeleton.set_bone_pose_position(int(_bones["Hips"]), _hips_model)


## Breathing, and a slow drift of the head and the weight: a sum of slow sines of the time (degrees).
func _drift(channel: String, time: float) -> Vector3:
	if life <= 0.0:
		return Vector3.ZERO

	var p: float = life_phase
	var slow: float = sin(time * TAU / 9.7 + p * 1.9)
	var medium: float = sin(time * TAU / 4.1 + p)
	var breath: float = sin(time * TAU / 3.6 + p * 0.6) * 0.65 + sin(time * TAU / 5.3 + p * 1.3) * 0.35
	match channel:
		"Spine2":
			return Vector3(0.55 * breath, 0.0, 0.25 * slow) * life
		"Spine1":
			return Vector3(0.25 * breath, 0.35 * slow, 0.0) * life
		"Neck":
			return Vector3(0.3 * medium, 0.5 * slow, 0.0) * life
		"Head":
			return Vector3(0.35 * slow, 0.6 * sin(time * TAU / 13.1 + p * 2.3), 0.3 * medium) * life
		"LeftShoulder":
			return Vector3(0.0, 0.0, 0.35 * breath) * life
		"RightShoulder":
			return Vector3(0.0, 0.0, -0.35 * breath) * life
		"Hips":
			return Vector3(0.0, 0.0, 0.3 * slow) * life
	return Vector3.ZERO


func _set_rotation(bone: int, rotation: Quaternion) -> void:
	_rotations[bone] = rotation


## A bone's pose in the model's own space, from the rotations set and the rests (the rests have no rotation; the hips bone is at
## `_hips_model`). Never read from the skeleton while it is being posed: its own global poses go stale.
func _global_pose(bone: int) -> Transform3D:
	var origin: Vector3 = _hips_model if skeleton.get_bone_parent(bone) < 0 else skeleton.get_bone_rest(bone).origin
	var local: Transform3D = Transform3D(Basis(_rotations.get(bone, Quaternion.IDENTITY) as Quaternion), origin)
	var parent: int = skeleton.get_bone_parent(bone)
	return local if parent < 0 else _global_pose(parent) * local


## Puts the tip of a chain (wrist or ankle) at `target` (the model's units) with the middle joint (elbow or knee) toward `pole`.
## Each bone is turned from its rest direction to the one the solution asks for. Returns how far the tip ended from the target
## (metres, at the actor's scale; the chain is never stretched, so a target out of reach shows here).
func _two_bone(root_name: String, mid_name: String, tip_name: String, target: Vector3, pole: Vector3) -> float:
	var root_bone: int = int(_bones[root_name])
	var mid: int = int(_bones[mid_name])
	var tip: int = int(_bones[tip_name])
	var origin: Vector3 = _global_pose(root_bone).origin
	var first: float = skeleton.get_bone_rest(mid).origin.length()
	var second: float = skeleton.get_bone_rest(tip).origin.length()
	var to_target: Vector3 = target - origin
	var span: float = clampf(to_target.length(), 0.05, (first + second) * 0.998)
	var direction: Vector3 = to_target.normalized()
	var along: float = (first * first - second * second + span * span) / (2.0 * span)
	var bend: float = sqrt(maxf(first * first - along * along, 0.0))
	var away: Vector3 = pole - direction * pole.dot(direction)
	away = away.normalized() if away.length() > 0.0001 else Vector3.UP
	var joint: Vector3 = origin + direction * along + away * bend
	var end: Vector3 = origin + direction * span

	var upper: Quaternion = Quaternion(skeleton.get_bone_rest(mid).origin.normalized(), (joint - origin).normalized())
	var parent_rotation: Quaternion = _global_pose(skeleton.get_bone_parent(root_bone)).basis.get_rotation_quaternion()
	_set_rotation(root_bone, parent_rotation.inverse() * upper)
	var lower: Quaternion = Quaternion(skeleton.get_bone_rest(tip).origin.normalized(), (end - joint).normalized())
	_set_rotation(mid, upper.inverse() * lower)
	return end.distance_to(target) * actor_scale


# ============================================================
# WHAT THE POSE MEANS IN SPACE (for the props, the placement and the tests)
# ============================================================

## The way a bone faces (the model's +Z), in the actor's frame, as the pose last sampled has it: for the head, where the face looks.
func bone_forward(bone_name: String) -> Vector3:
	return (_global_pose(int(_bones[bone_name])).basis * Vector3.BACK).normalized()


## A bone's origin, in the actor's frame.
func bone_point(bone_name: String) -> Vector3:
	return from_model(_global_pose(int(_bones[bone_name])).origin)


## Every vertex of the body as the pose last sampled has it, in the actor's frame (skinned by hand).
func skinned_vertices() -> PackedVector3Array:
	var palette_transforms: Array[Transform3D] = []
	for bone: int in skeleton.get_bone_count():
		palette_transforms.append(_global_pose(bone) * body.skin.get_bind_pose(bone))

	var result: PackedVector3Array = PackedVector3Array()
	result.resize(_vertices.size())
	for index: int in _vertices.size():
		var at: Vector3 = Vector3.ZERO
		for slot: int in 4:
			var weight: float = _weights[index * 4 + slot]
			if weight > 0.0:
				at += (palette_transforms[_bone_ids[index * 4 + slot]] * _vertices[index]) * weight
		result[index] = from_model(at)
	return result


## The vertices that a set of bones move most (by bone name without prefix, or a suffix such as "UpLeg").
func vertices_of(names: Array[String]) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	for index: int in _vertices.size():
		for name_part: String in names:
			if _main_bone[index] == name_part or (name_part.begins_with("*") and _main_bone[index].ends_with(name_part.substr(1))):
				found.append(index)
				break
	return found


## Lowers or raises the hips (`hips_shift`) so that the lowest vertex of the pelvis and the thighs' tops, as `time` poses it, is `clearance`
## over the floor. For the actor that sits: its pelvis genuinely on the floor. Returns the shift it settled on.
func settle_hips_on_floor(time: float, clearance: float = 0.0, groups: Array[String] = ["Hips", "*UpLeg"]) -> float:
	var group: PackedInt32Array = vertices_of(groups)
	var low: float = -0.4
	var high: float = 0.4
	for step: int in 24:
		hips_shift = (low + high) * 0.5
		sample(time)
		var vertices: PackedVector3Array = skinned_vertices()
		var lowest: float = 1.0e9
		for index: int in group:
			lowest = minf(lowest, vertices[index].y)
		if lowest > clearance:
			high = hips_shift
		else:
			low = hips_shift
	hips_shift = (low + high) * 0.5
	sample(time)
	return hips_shift
