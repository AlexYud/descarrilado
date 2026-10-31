extends Node3D
class_name SeatedFigure

## Someone sitting on the camp's bench at the log table (Table B), for the apparition at the end of the fig clearing (`FigClearingSequence`): the
## rigged basic model (`basic_model_rigged.tscn`, the same body as the girl in the wagon, a Mixamo skeleton) scaled by `figure_scale`, seated
## on the bench with its back to whoever looks at it, leaning a little towards the table, shoulders rounded and a little uneven, head lowered.
## One forearm rests at the table's edge with the hand just above the tabletop holding the token (`hold_point`), the other hand rests on its
## thigh. It is perfectly still (no animation), has no collision and nothing to interact with.
##
## Built facing +Z (towards the table), its origin on the ground under the middle of its seat. `build` solves the legs (of a few thigh and knee
## angles, the foot flat, it takes the ones that put the lowest point of the pelvis `seat_height` above the lowest point of the feet) and then
## puts each hand where the sequence wants it with a two-bone solution (`_reach`): the arms' rotations come from the shoulder's place and the
## target, not from angles tried on another rig.

const MODEL: String = "res://assets/models/characters/basic_model/basic_model_rigged.tscn"
const PREFIX: String = "mixamorig_"

## (Vertex colours of the old, plain look: dark clothes, a dim skin, black hair. The figure is a shadow now, see `GHOST_SHADER`; they remain in the mesh.)
const CLOTH: Color = Color(0.07, 0.08, 0.11)
const SKIN: Color = Color(0.3, 0.24, 0.21)
const HAIR: Color = Color(0.03, 0.025, 0.025)

## The trunk's lean over the spine (the hips are tilted `HIPS_TILT`), in degrees: leaning to the table, not stooped.
const HIPS_TILT: float = -2.0
const SPINE: float = 5.0
const SPINE1: float = 6.0
const SPINE2: float = 5.0

var skeleton: Skeleton3D = null
var body: MeshInstance3D = null
## The leg angles that were solved, and how far the pelvis ended up from `seat_height` (metres).
var thigh_degrees: float = 0.0
var knee_degrees: float = 0.0
var seat_error: float = 0.0
## Where the hand that holds the token is, in the figure's own frame (the token's place before it falls), and how near the hand got to it (metres).
var hold_point: Vector3 = Vector3.ZERO
var hold_error: float = 0.0
## Where the head is, in the figure's own frame.
var head_point: Vector3 = Vector3.ZERO

## A shadow, not a body: pure black, lit by nothing and not tinted by the mist (so it stays darker than the air round it), a little less than solid,
## with a slow uneven flicker and rare, very short dropouts, fading towards the ground so that it does not quite stand on it. It gives off no light.
const GHOST_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, fog_disabled;
uniform float body_alpha = 0.94;
uniform float ground_y = 0.0;
uniform float fade_height = 0.6;
varying float height;
void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - ground_y;
}
void fragment() {
	float flicker = 0.94 + 0.06 * sin(TIME * 6.3) * sin(TIME * 2.1 + 1.3);
	float drop = step(0.985, fract(sin(floor(TIME * 9.0) * 12.9898) * 43758.5453));
	float fade = smoothstep(0.0, fade_height, height);
	ALBEDO = vec3(0.0);
	ALPHA = clamp(body_alpha * flicker * mix(0.3, 1.0, fade) * (1.0 - 0.55 * drop), 0.0, 1.0);
}
"""

## How far the head has been lowered from its resting pose (degrees), see `lower_head`.
var head_bow_degrees: float = 0.0

var _scale: float = 1.0
var _ghost: ShaderMaterial = null
var _bones: Dictionary = {}
## The rotation given to each bone (by bone index), mirrored here: the skeleton's own global poses are never read while they are being changed
## (they go stale), the figure's forward kinematics is done from these and the bones' rests.
var _rotations: Dictionary = {}
var _pelvis_ids: PackedInt32Array = PackedInt32Array()
var _foot_ids: PackedInt32Array = PackedInt32Array()


## Makes the figure. `seat_height` is the top of the bench (metres above the ground), `figure_scale` the model's scale (1.0 is the 1.83 m model),
## and `reach` says where the hands go, in the figure's own frame (x to its left, y up from the ground, z forward): `token_hand` ("Left" or
## "Right") holds the token at `hold`, the other hand rests at `rest`.
func build(seat_height: float, figure_scale: float, reach: Dictionary) -> void:
	if skeleton != null:
		return

	_scale = figure_scale
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * figure_scale
	add_child(model)
	skeleton = model.get_node("Skeleton3D") as Skeleton3D
	body = skeleton.get_node("Body") as MeshInstance3D
	for bone: int in skeleton.get_bone_count():
		_bones[skeleton.get_bone_name(bone).trim_prefix(PREFIX)] = bone
	_colour_the_body()
	_sort_vertices()

	_solve_legs(seat_height / figure_scale)
	_pose_trunk()

	var extent: Dictionary = _extent()
	var feet_low: float = float(extent["feet"])
	var hips_z: float = _global_pose(int(_bones["Hips"])).origin.z
	model.position.y = -feet_low * figure_scale
	# The seat is on the bench's centre line: the pelvis (the hips bone) is over the origin.
	model.position.z = -hips_z * figure_scale

	var holding: String = String(reach.get("token_hand", "Left"))
	var resting: String = "Right" if holding == "Left" else "Left"
	var hold: Vector3 = reach.get("hold", Vector3(0.2, 0.85, 0.6)) as Vector3
	var rest: Vector3 = reach.get("rest", Vector3(-0.2, seat_height + 0.12, 0.25)) as Vector3
	var outward: float = 1.0 if holding == "Left" else -1.0
	hold_error = _reach(holding, _to_model(hold, feet_low, hips_z), Vector3(outward * 0.5, -1.0, -0.2))
	_reach(resting, _to_model(rest, feet_low, hips_z), Vector3(-outward * 0.5, -1.0, -0.2))
	hold_point = hold
	var head: Vector3 = _global_pose(int(_bones["Head"])).origin
	head_point = Vector3(head.x * figure_scale, (head.y - feet_low) * figure_scale + 0.1, (head.z - hips_z) * figure_scale)


## A point of the figure's own frame in the model's units.
func _to_model(point: Vector3, feet_low: float, hips_z: float) -> Vector3:
	return Vector3(point.x / _scale, point.y / _scale + feet_low, point.z / _scale + hips_z)


## The lowest point of the pelvis and of the feet (in the model's own units), skinned by hand.
func _extent() -> Dictionary:
	var arrays: Array = (body.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var palette: Array[Transform3D] = []
	for bone: int in skeleton.get_bone_count():
		palette.append(_global_pose(bone) * body.skin.get_bind_pose(bone))

	var pelvis: float = 1.0e9
	var feet: float = 1.0e9
	for group: Array in [[_pelvis_ids, true], [_foot_ids, false]]:
		for index: int in (group[0] as PackedInt32Array):
			var at: Vector3 = Vector3.ZERO
			for slot: int in 4:
				var weight: float = weights[index * 4 + slot]
				if weight > 0.0:
					at += (palette[bones[index * 4 + slot]] * vertices[index]) * weight
			if bool(group[1]):
				pelvis = minf(pelvis, at.y)
			else:
				feet = minf(feet, at.y)
	return {"pelvis": pelvis, "feet": feet}


## Which vertices are the pelvis (the hips and the thighs' tops) and the feet, by the bone that moves each most.
func _sort_vertices() -> void:
	var arrays: Array = (body.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for index: int in vertices.size():
		var main: int = bones[index * 4]
		var best: float = -1.0
		for slot: int in 4:
			if weights[index * 4 + slot] > best:
				best = weights[index * 4 + slot]
				main = bones[index * 4 + slot]
		var bone_name: String = skeleton.get_bone_name(main).trim_prefix(PREFIX)
		if bone_name == "Hips" or bone_name.ends_with("UpLeg"):
			_pelvis_ids.append(index)
		elif bone_name.ends_with("ToeBase") or bone_name.ends_with("Foot"):
			_foot_ids.append(index)


## Tries thigh and knee angles (the foot flat) for the ones that leave the pelvis `target` (model units) above the feet.
func _solve_legs(target: float) -> void:
	var best_error: float = 1.0e9
	for thigh: float in [-100.0, -95.0, -90.0, -85.0, -80.0, -75.0, -70.0, -65.0, -60.0, -55.0, -50.0, -45.0, -40.0]:
		for knee: float in [40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 110.0, 120.0, 130.0]:
			_set_legs(thigh, knee)
			var extent: Dictionary = _extent()
			var height: float = float(extent["pelvis"]) - float(extent["feet"])
			# The thigh near level, the shin straight or leaning a little forward (never back under the seat): a body sitting naturally, its feet
			# in front of it.
			var shin: float = -(HIPS_TILT + thigh) - knee
			var error: float = absf(height - target) + 0.0012 * absf(thigh + 86.0) + 0.0012 * absf(shin - 2.0)
			if error < best_error:
				best_error = error
				thigh_degrees = thigh
				knee_degrees = knee
				seat_error = height - target
	_set_legs(thigh_degrees, knee_degrees)


func _set_legs(thigh: float, knee: float) -> void:
	_rotations.clear()
	skeleton.reset_bone_poses()
	_rotate("Hips", [[Vector3.RIGHT, HIPS_TILT]])
	for side: String in ["Left", "Right"]:
		var splay: float = 5.0 if side == "Left" else -5.0
		_rotate(side + "UpLeg", [[Vector3.BACK, splay], [Vector3.RIGHT, thigh]])
		_rotate(side + "Leg", [[Vector3.RIGHT, knee]])
		_rotate(side + "Foot", [[Vector3.RIGHT, -(HIPS_TILT + thigh + knee)]])


## The trunk, shoulders and head (after the legs, before the arms): the back to the viewer, so the head stays in line with the trunk, only
## lowered a little and tilted, never turned.
func _pose_trunk() -> void:
	_rotate("Spine", [[Vector3.RIGHT, SPINE]])
	_rotate("Spine1", [[Vector3.RIGHT, SPINE1]])
	_rotate("Spine2", [[Vector3.BACK, 3.0], [Vector3.RIGHT, SPINE2]])
	_rotate("Neck", [[Vector3.RIGHT, 8.0]])
	_rotate("Head", [[Vector3.BACK, -3.0], [Vector3.RIGHT, 10.0]])
	# Shoulders rounded forward, the left a little higher.
	_rotate("LeftShoulder", [[Vector3.BACK, 6.0], [Vector3.UP, -8.0]])
	_rotate("RightShoulder", [[Vector3.BACK, 1.0], [Vector3.UP, 8.0]])


## Puts the `side` hand at `target` (model units) with the elbow towards `pole`: the upper arm and the forearm are each turned from their
## rest direction to the one the two-bone solution asks for. Returns how far the hand ended from the target (metres, at the figure's scale).
func _reach(side: String, target: Vector3, pole: Vector3) -> float:
	var arm: int = int(_bones[side + "Arm"])
	var fore: int = int(_bones[side + "ForeArm"])
	var hand: int = int(_bones[side + "Hand"])
	var shoulder: Vector3 = _global_pose(arm).origin
	var first: float = skeleton.get_bone_rest(fore).origin.length()
	var second: float = skeleton.get_bone_rest(hand).origin.length()
	var to_target: Vector3 = target - shoulder
	var span: float = clampf(to_target.length(), 0.05, (first + second) * 0.995)
	var direction: Vector3 = to_target.normalized()
	var along: float = (first * first - second * second + span * span) / (2.0 * span)
	var bend: float = sqrt(maxf(first * first - along * along, 0.0))
	var away: Vector3 = (pole - direction * pole.dot(direction)).normalized()
	var elbow: Vector3 = shoulder + direction * along + away * bend
	var wrist: Vector3 = shoulder + direction * span

	var upper: Quaternion = Quaternion(skeleton.get_bone_rest(fore).origin.normalized(), (elbow - shoulder).normalized())
	var parent_rotation: Quaternion = _global_pose(skeleton.get_bone_parent(arm)).basis.get_rotation_quaternion()
	_set_rotation(arm, parent_rotation.inverse() * upper)
	var lower: Quaternion = Quaternion(skeleton.get_bone_rest(hand).origin.normalized(), (wrist - elbow).normalized())
	_set_rotation(fore, upper.inverse() * lower)
	return wrist.distance_to(target) * _scale


func _rotate(bone_name: String, steps: Array) -> void:
	var result: Quaternion = Quaternion.IDENTITY
	for step: Array in steps:
		result = Quaternion(step[0] as Vector3, deg_to_rad(float(step[1]))) * result
	_set_rotation(int(_bones[bone_name]), result)


func _set_rotation(bone: int, rotation: Quaternion) -> void:
	_rotations[bone] = rotation
	skeleton.set_bone_pose_rotation(bone, rotation)


## A bone's global pose from the mirrored rotations and the rests (the rests have no rotation).
func _global_pose(bone: int) -> Transform3D:
	var local: Transform3D = Transform3D(Basis(_rotations.get(bone, Quaternion.IDENTITY) as Quaternion), skeleton.get_bone_rest(bone).origin)
	var parent: int = skeleton.get_bone_parent(bone)
	return local if parent < 0 else _global_pose(parent) * local


## Dark clothes, a dim skin on the head and the hands, black hair, from vertex colours (the shared model stays plain).
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
		var colour: Color = CLOTH
		if bone_name.ends_with("Hand") or bone_name == "Neck":
			colour = SKIN
		elif bone_name == "Head":
			colour = SKIN if (vertices[index].z > 0.115 and vertices[index].y < 0.8) else HAIR
		colours[index] = colour
	arrays[Mesh.ARRAY_COLOR] = colours
	var painted: ArrayMesh = ArrayMesh.new()
	painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader: Shader = Shader.new()
	shader.code = GHOST_SHADER
	_ghost = ShaderMaterial.new()
	_ghost.shader = shader
	painted.surface_set_material(0, _ghost)
	body.mesh = painted


## The head goes slowly down (`degrees` more than its resting pose, over `seconds`): the neck takes a third of it, the head the rest. It stays down.
func lower_head(degrees: float, seconds: float) -> void:
	var bow: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow.tween_method(_set_head_bow, head_bow_degrees, degrees, maxf(seconds, 0.05))


func _set_head_bow(degrees: float) -> void:
	head_bow_degrees = degrees
	_rotate("Neck", [[Vector3.RIGHT, 8.0 + degrees * 0.35]])
	_rotate("Head", [[Vector3.BACK, -3.0], [Vector3.RIGHT, 10.0 + degrees * 0.65]])


## The world height of the ground under the figure, from which it fades (call it once the figure is where it will stand).
func set_ground(world_y: float) -> void:
	if _ghost != null:
		_ghost.set_shader_parameter(&"ground_y", world_y)
