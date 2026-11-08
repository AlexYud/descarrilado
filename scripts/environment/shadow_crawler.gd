extends Node3D
class_name ShadowCrawler

## The human shadow of the other places (the rigged basic model drawn as `SeatedFigure.GHOST_SHADER`, see `SeatedFigure`) crawling on the ground like the dead that will not stay dead: face to the ground, the
## chest lifted on an arched back, the head up and lolling, one arm reaching and the other dragging the body forward in jerks, the legs trailing and flopping, and at the end the last reach, a shudder, and
## it lies still. A pure function of the time (`pose_at`): a clock, a path, no animation player, no state to lose; it can be seeked, paused and replayed.
##
## It is built facing +Z with its origin on the ground under the middle of its chest, and moved along a path given in its parent's space by `play`. The skeleton's rests have no rotation (T-pose along x,
## y up, z forward), so a bone's rotation about X bends it forward/back, about Y twists it, about Z swings it sideways (to the character's left for +Z on its left arm).

signal finished

const MODEL: String = "res://assets/models/characters/basic_model/basic_model_rigged.tscn"
## The crawl, a Mixamo animation (without a skin) played on this rig: see `_load_clip` and `_pose_clip`. Its first `CLIP_START` seconds are skipped; the hips travel with it (the figure moves along its path as its hips do, so nothing slides).
const CLIP: String = "res://assets/animations/mixamo/shadow_crawl.fbx"
const CLIP_START: float = 1.5
## After the crawl the clip is not stopped dead (a stalled stroke is a body frozen in the air): it runs on for this many seconds of its own, slowing to a halt as the body gives out.
const CLIP_COAST: float = 0.0
const CLIP_COAST_TAU: float = 0.45
## How far under the model's own origin its soles are (the rigged model has its feet at y -0.975).
const MODEL_FLOOR: float = 0.975
## How far (degrees) each bone is turned down when the body gives out: the chest first, the head most.
## The child each bone points to (to measure its rest direction); the others (head, hands, feet) take their parent's fix.
const REST_CHILD: Dictionary = {"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "LeftShoulder": "LeftArm", "RightShoulder": "RightArm", "LeftArm": "LeftForeArm", "RightArm": "RightForeArm", "LeftForeArm": "LeftHand", "RightForeArm": "RightHand", "LeftUpLeg": "LeftLeg", "RightUpLeg": "RightLeg", "LeftLeg": "LeftFoot", "RightLeg": "RightFoot"}
const COLLAPSE_SAG: Dictionary = {"Spine1": 10.0, "Spine2": 26.0, "Neck": 38.0, "Head": 62.0}
const PREFIX: String = "mixamorig_"

## One full stroke (both arms) takes this long (seconds).
const STROKE_SECONDS: float = 1.7
## The time at the end spent dying and lying down.
const DEATH_SECONDS: float = 2.6
## A pause part of the way (a stop with the head up and a twitch), as a share of the crawl, and how long.
const PAUSE_AT: float = 0.45
const PAUSE_SECONDS: float = 1.3

var skeleton: Skeleton3D = null
var body: MeshInstance3D = null
## The path (in the parent's space), its length, and when the crawl and the whole performance start (the clock is the node's own, advanced by `_process`).
var path: PackedVector3Array = PackedVector3Array()
var path_length: float = 0.0
var total_seconds: float = 0.0
var elapsed: float = 0.0
var playing: bool = false
var is_dead: bool = false
## The stop part of the way, as it is for this performance (none in a short one: a crawl of a few seconds is all strokes).
var pause_seconds: float = 0.0
## How long the death lasts in this performance (0 for the animated crawl).
var death_seconds: float = DEATH_SECONDS
## The supernatural part of the animated crawl (seconds of the performance): from `glitch_from` the figure strobes and fades like a ghost and the camera fails (`glitch_at`, `static_at`, `ghost_alpha_at`), and at
## `glitch_until`, under a burst of static, it is gone; the picture settles over the rest of the performance with nothing in it.
var glitch_from: float = 0.0
var glitch_until: float = 3.55
## The camera has been failing this long when the shadow shows (it is not there before): the shadow crawls from `lead_seconds` to `glitch_until`.
var lead_seconds: float = 1.3
## Half the thickness of the lying body (metres, at the figure's scale): the model rests on the ground by this much.
var thickness: float = 0.13

var _bones: Dictionary = {}
var _scale: float = 1.0
var _model: Node3D = null
var _material: ShaderMaterial = null

## The crawl's data (see `_load_clip`): the animation, the source skeleton's bone names, parents, rest rotations, the animation's track of each bone, and our bone to the source bone.
var clip_ready: bool = false
var _clip: Animation = null
var _src_names: PackedStringArray = PackedStringArray()
var _src_parent: PackedInt32Array = PackedInt32Array()
var _src_rest_local: Array[Quaternion] = []
var _src_rest_global: Array[Quaternion] = []
var _src_rot_track: PackedInt32Array = PackedInt32Array()
var _hips_track: int = -1
var _src_hips_rest: Vector3 = Vector3.ZERO
var _our_to_src: PackedInt32Array = PackedInt32Array()
var _clip_scale: float = 1.0
## For each of our bones, the turn that takes its rest direction (toward its child: our model rests in an A-pose, arms sloping down) to the source's (a T-pose): the retargeted pose is the source's turn on top of it.
var _our_rest_fix: Array[Quaternion] = []
## How far the body falls when it gives out (metres, at the model's own scale).
var collapse_drop: float = 0.13


## Builds the figure at `figure_scale` (1.0 is the 1.83 m model). `plain` keeps the model's own look instead of the shadow (for a developer's tool).
func build(figure_scale: float = 0.92, plain: bool = false) -> void:
	if skeleton != null:
		return

	_scale = figure_scale
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	_model.scale = Vector3.ONE * figure_scale
	add_child(_model)
	skeleton = _model.get_node("Skeleton3D") as Skeleton3D
	body = skeleton.get_node("Body") as MeshInstance3D
	for bone: int in skeleton.get_bone_count():
		_bones[skeleton.get_bone_name(bone).trim_prefix(PREFIX)] = bone
	if not plain:
		var shader: Shader = Shader.new()
		# The shadow of the other places, without its flicker and dropouts (a crawling body that flickers is a bad render, not a ghost) and, whatever pose it is in, never culled by its rest size.
		shader.code = SeatedFigure.GHOST_SHADER.replace("0.94 + 0.06 * sin(TIME * 6.3) * sin(TIME * 2.1 + 1.3)", "1.0").replace("step(0.985, fract(sin(floor(TIME * 9.0) * 12.9898) * 43758.5453))", "0.0")
		_material = ShaderMaterial.new()
		_material.shader = shader
		body.extra_cull_margin = 3.0
		# Lying on the ground it must not fade towards it (the shadow of a standing figure does).
		_material.set_shader_parameter(&"fade_height", 0.001)
		_material.set_shader_parameter(&"body_alpha", 0.97)
		body.material_override = _material
	clip_ready = _load_clip()
	if clip_ready:
		# The animation is of a body already crawling (prone, the head toward +Z): the model stands as it is, its soles on the ground at the origin.
		_model.basis = Basis.from_scale(Vector3.ONE * figure_scale)
		_model.position = Vector3(0.0, MODEL_FLOOR * figure_scale, 0.0)
	else:
	# Lying face down, the head toward +Z: the model is turned a quarter circle about X, its chest over the origin, the back of it up.
		_model.basis = Basis(Vector3.RIGHT, deg_to_rad(90.0)) * Basis.from_scale(Vector3.ONE * figure_scale)
		_model.position = Vector3(0.0, thickness, -1.18 * figure_scale)
	visible = false
	pose_at(0.0)


## Starts the performance along `points` (the parent's space, ground points; at least two) taking `seconds` in all, of which the last `DEATH_SECONDS` are the death.
func play(points: PackedVector3Array, seconds: float) -> void:
	if skeleton == null or points.size() < 2:
		return

	path = points
	path_length = 0.0
	for i: int in points.size() - 1:
		path_length += points[i].distance_to(points[i + 1])
	# The animated crawl has no death: the figure is gone at the end (the shed's scene makes the camera fail as it goes). The hand-posed fallback still dies.
	death_seconds = 0.0 if clip_ready else DEATH_SECONDS
	total_seconds = maxf(seconds, glitch_until + 1.0) if clip_ready else maxf(seconds, death_seconds + 3.0)
	pause_seconds = PAUSE_SECONDS if total_seconds > death_seconds + 8.0 else 0.0
	elapsed = 0.0
	is_dead = false
	playing = true
	visible = true
	pose_at(0.0)


## Hides it and stops (the lens's picture is over).
func stop() -> void:
	playing = false
	visible = false


func _process(delta: float) -> void:
	if not playing:
		return

	elapsed = minf(elapsed + delta, total_seconds)
	pose_at(elapsed)
	if elapsed >= total_seconds:
		playing = false
		if clip_ready:
			# Nothing of it is left: not lying there, not a shadow, nothing.
			visible = false
		else:
			is_dead = true
		finished.emit()


## Where it is on its path (0 to 1 of the length) `t` seconds in: the surges of the two pulls, a pause part of the way, and nothing during the death.
func progress_at(t: float) -> float:
	if clip_ready:
		return _clip_progress(t)

	var crawl: float = maxf(total_seconds - death_seconds, 0.1)
	var moving: float = crawl - pause_seconds
	var clock: float = clampf(t, 0.0, crawl)
	var pause_start: float = PAUSE_AT * moving
	# The clock of the strokes stands still during the pause.
	var strokes: float = clock if clock < pause_start else (pause_start if clock < pause_start + pause_seconds else clock - pause_seconds)
	var c: float = strokes / STROKE_SECONDS
	# Two pulls a stroke: the speed breathes about its mean (surges at phase .175 and .675, where the arms pull).
	var wave: float = 0.85 * STROKE_SECONDS / (4.0 * PI) * (sin(4.0 * PI * (c - 0.175)) - sin(4.0 * PI * (-0.175)))
	var travelled: float = strokes + wave
	return clampf(travelled / moving, 0.0, 1.0)


## The place and heading of the node `t` seconds in (its parent's space), and the body pose.
func pose_at(t: float) -> void:
	if skeleton == null:
		return

	var crawl: float = maxf(total_seconds - death_seconds, 0.1)
	var share: float = progress_at(t) if path.size() >= 2 else 0.0
	var at: Dictionary = _point_on_path(share)
	var heading: Vector3 = at["heading"] as Vector3
	if heading.length() > 0.001:
		transform = Transform3D(Basis.looking_at(-heading, Vector3.UP).rotated(Vector3.UP, 0.0), at["point"] as Vector3)
		# (`looking_at` points -Z at the target: the figure faces +Z, so it is turned to look away from the heading.)
	else:
		position = at["point"] as Vector3

	if _material != null:
		# The shadow fades toward `ground_y`; lying on the ground it must not (nothing is below the figure by more than a metre).
		_material.set_shader_parameter(&"ground_y", global_position.y - 1.0)
	var dying: float = clampf((t - crawl) / maxf(death_seconds, 0.001), 0.0, 1.0) if death_seconds > 0.0 else 0.0
	if clip_ready:
		_pose_clip(_crawl_time(t), _crawl_seconds(), 0.0)
		_apply_glitch(t)
		return

	var pause_start: float = PAUSE_AT * (crawl - pause_seconds)
	var paused: bool = t > pause_start and t < pause_start + pause_seconds and dying <= 0.0
	var clock: float = minf(t, crawl)
	var strokes: float = clock if clock < pause_start else (pause_start if clock < pause_start + pause_seconds else clock - pause_seconds)
	var phase: float = fmod(strokes / STROKE_SECONDS, 1.0)
	_pose(phase, clock, dying, paused, t)


func _point_on_path(share: float) -> Dictionary:
	if path.size() < 2:
		return {"point": position, "heading": Vector3.ZERO}

	var target: float = share * path_length
	var run: float = 0.0
	for i: int in path.size() - 1:
		var length: float = path[i].distance_to(path[i + 1])
		if run + length >= target or i == path.size() - 2:
			var u: float = clampf((target - run) / maxf(length, 0.0001), 0.0, 1.0)
			var heading: Vector3 = path[i + 1] - path[i]
			heading.y = 0.0
			return {"point": path[i].lerp(path[i + 1], u), "heading": heading.normalized()}
		run += length
	return {"point": path[path.size() - 1], "heading": Vector3.ZERO}


## One arm's swing about the body's axis: `reach` 0 is the arm drawn back along the body, 1 the arm thrown forward over the head. The stroke: the slow reach, the quick pull, a short rest.
func _stroke(phase: float) -> float:
	if phase < 0.45:
		return smoothstep(0.0, 1.0, phase / 0.45)
	if phase < 0.9:
		return 1.0 - smoothstep(0.0, 1.0, (phase - 0.45) / 0.45) * 0.97
	return 0.03


func _pose(phase: float, clock: float, dying: float, paused: bool, t: float) -> void:
	var left: float = _stroke(phase)
	var right: float = _stroke(fmod(phase + 0.5, 1.0))
	var alive: float = 1.0 - smoothstep(0.0, 0.45, dying)
	var shudder: float = 0.0
	if dying > 0.0:
		var since: float = dying * DEATH_SECONDS
		shudder = exp(-2.4 * since) * sin(since * 38.0) * smoothstep(0.0, 0.15, since)
	# The last reach: just before it dies the left arm is thrown out once more and then falls.
	var final_reach: float = sin(clampf(dying / 0.35, 0.0, 1.0) * PI) if dying > 0.0 else 0.0
	var lean: float = sin(TAU * phase)

	# The arms: about Z, 0 degrees is straight out to the side, +90 (left) along the body over the head, -30 drawn back by the hip.
	var left_angle: float = lerpf(-28.0, 150.0, left) * alive + 28.0 * (1.0 - alive) + final_reach * 25.0
	var right_angle: float = -(lerpf(-28.0, 150.0, right) * alive + 28.0 * (1.0 - alive))
	var left_bend: float = (1.0 - left) * 55.0 * alive
	var right_bend: float = (1.0 - right) * 55.0 * alive
	_bone("LeftArm", [[Vector3.BACK, left_angle], [Vector3.UP, -12.0 * left]])
	_bone("RightArm", [[Vector3.BACK, right_angle], [Vector3.UP, 12.0 * right]])
	_bone("LeftForeArm", [[Vector3.BACK, left_bend + shudder * 9.0]])
	_bone("RightForeArm", [[Vector3.BACK, -right_bend - shudder * 9.0]])
	_bone("LeftHand", [[Vector3.BACK, 12.0 * (1.0 - left)], [Vector3.RIGHT, 20.0]])
	_bone("RightHand", [[Vector3.BACK, -12.0 * (1.0 - right)], [Vector3.RIGHT, 20.0]])
	_bone("LeftShoulder", [[Vector3.BACK, 10.0 * left - 4.0]])
	_bone("RightShoulder", [[Vector3.BACK, -10.0 * right + 4.0]])

	# The back arched so that the chest is up, swaying from side to side with the strokes; the head up and lolling, and dropping at the end.
	var arch: float = lerpf(-6.0, 0.0, dying) * alive
	var sway: float = (7.0 * lean + (4.0 * sin(clock * 3.1) if not paused else 3.0 * sin(clock * 5.0))) * alive + shudder * 3.0
	var twist: float = (9.0 * sin(TAU * phase + 0.7)) * alive + final_reach * 6.0
	_bone("Hips", [[Vector3.BACK, -sway * 0.5], [Vector3.UP, -twist * 0.4]])
	_bone("Spine", [[Vector3.RIGHT, arch], [Vector3.BACK, sway * 0.4], [Vector3.UP, twist * 0.3]])
	_bone("Spine1", [[Vector3.RIGHT, arch], [Vector3.BACK, sway * 0.4], [Vector3.UP, twist * 0.3]])
	_bone("Spine2", [[Vector3.RIGHT, arch], [Vector3.BACK, sway * 0.4], [Vector3.UP, twist * 0.4]])
	var head_up: float = lerpf(-44.0, 12.0, smoothstep(0.1, 0.9, dying))
	if paused:
		head_up = -58.0 + 6.0 * sin(clock * 4.0)
	var loll: float = (14.0 * sin(clock * 2.3 + 1.0) + 8.0 * sin(clock * 5.7)) * alive + shudder * 8.0
	var jerk: float = 0.0
	# A jerk of the head at the end of each pull.
	var pull_end: float = absf(fmod(phase, 0.5) - 0.2)
	if pull_end < 0.06 and alive > 0.5:
		jerk = (0.06 - pull_end) / 0.06 * 11.0
	_bone("Neck", [[Vector3.RIGHT, head_up * 0.4 - jerk * 0.4], [Vector3.BACK, loll * 0.4], [Vector3.UP, loll * 0.5]])
	_bone("Head", [[Vector3.RIGHT, head_up * 0.6 - jerk * 0.6], [Vector3.BACK, loll * 0.6], [Vector3.UP, loll * 0.5]])

	# The legs trail and flop: the knees bend and straighten against each other, the toes drag, the thighs fall open; limp at the end.
	var left_knee: float = (4.0 + 5.0 * sin(TAU * phase)) * alive + 1.0 * (1.0 - alive)
	var right_knee: float = (4.0 - 5.0 * sin(TAU * phase)) * alive + 1.0 * (1.0 - alive)
	_bone("LeftUpLeg", [[Vector3.BACK, 7.0 + 5.0 * (1.0 - alive)], [Vector3.RIGHT, 4.0 * sin(TAU * phase)]])
	_bone("RightUpLeg", [[Vector3.BACK, -7.0 - 5.0 * (1.0 - alive)], [Vector3.RIGHT, -4.0 * sin(TAU * phase)]])
	_bone("LeftLeg", [[Vector3.RIGHT, left_knee]])
	_bone("RightLeg", [[Vector3.RIGHT, right_knee]])
	_bone("LeftFoot", [[Vector3.RIGHT, 22.0 + 8.0 * sin(TAU * phase + 1.0)]])
	_bone("RightFoot", [[Vector3.RIGHT, 22.0 - 8.0 * sin(TAU * phase + 1.0)]])

	# Dying, it settles onto its side a little and flattens.
	if _model != null:
		var roll: float = -26.0 * smoothstep(0.2, 1.0, dying)
		var sink: float = lerpf(thickness, thickness * 0.82, smoothstep(0.2, 1.0, dying))
		_model.basis = Basis(Vector3.RIGHT, deg_to_rad(90.0)) * Basis(Vector3.UP, deg_to_rad(roll)) * Basis.from_scale(Vector3.ONE * _scale)
		_model.position = Vector3(0.0, sink, -1.18 * _scale)


func _bone(bone_name: String, steps: Array) -> void:
	if not _bones.has(bone_name):
		return

	var result: Quaternion = Quaternion.IDENTITY
	for step: Array in steps:
		result = Quaternion(step[0] as Vector3, deg_to_rad(float(step[1]))) * result
	skeleton.set_bone_pose_rotation(int(_bones[bone_name]), result)


## Where the head is now (world space), for the tests and the placing of what it leaves.
func head_world() -> Vector3:
	return bone_world("Head")


## Where a bone is now (world space); the figure's own place if it has no such bone.
func bone_world(bone_name: String) -> Vector3:
	if skeleton == null or not _bones.has(bone_name):
		return global_position
	return skeleton.to_global(skeleton.get_bone_global_pose(int(_bones[bone_name])).origin)


# ============================================================
# THE CRAWL (a Mixamo animation on this rig)
# ============================================================

## Reads the crawl: the animation and the source skeleton's rests (the animation's own, imported without a skin). Our bones have identity rests (a T-pose along x, y up), the source's do not, so the animation is
## retargeted in GLOBAL space: a bone's turn from the source's rest is the same turn from ours. False if the file is missing or its bones are not these.
func _load_clip() -> bool:
	var packed: PackedScene = load(CLIP) as PackedScene
	if packed == null:
		return false

	var source: Node = packed.instantiate()
	var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source_skeleton: Skeleton3D = source.find_child("Skeleton3D", true, false) as Skeleton3D
	if player == null or source_skeleton == null or player.get_animation_list().is_empty():
		source.free()
		return false

	_clip = player.get_animation(player.get_animation_list()[0])
	var count: int = source_skeleton.get_bone_count()
	_src_names.resize(count)
	_src_parent.resize(count)
	_src_rot_track.resize(count)
	_src_rest_local.resize(count)
	_src_rest_global.resize(count)
	var by_name: Dictionary = {}
	for s: int in count:
		var bone_name: String = source_skeleton.get_bone_name(s).trim_prefix(PREFIX)
		_src_names[s] = bone_name
		by_name[bone_name] = s
		_src_parent[s] = source_skeleton.get_bone_parent(s)
		_src_rest_local[s] = source_skeleton.get_bone_rest(s).basis.get_rotation_quaternion()
		var parent_rotation: Quaternion = Quaternion.IDENTITY if _src_parent[s] < 0 else _src_rest_global[_src_parent[s]]
		_src_rest_global[s] = parent_rotation * _src_rest_local[s]
		_src_rot_track[s] = _clip.find_track(NodePath("Skeleton3D:" + source_skeleton.get_bone_name(s)), Animation.TYPE_ROTATION_3D)
	var hips: int = int(by_name.get("Hips", -1))
	if hips < 0:
		source.free()
		return false

	_hips_track = _clip.find_track(NodePath("Skeleton3D:" + source_skeleton.get_bone_name(hips)), Animation.TYPE_POSITION_3D)
	_src_hips_rest = source_skeleton.get_bone_rest(hips).origin
	# Our hips are 0.955 m over the soles, theirs 1.043: the hips' own travel is scaled by that.
	_clip_scale = (skeleton.get_bone_rest(int(_bones["Hips"])).origin.y + MODEL_FLOOR) / maxf(_src_hips_rest.y, 0.1)
	_our_to_src.resize(skeleton.get_bone_count())
	var missing: int = 0
	for b: int in skeleton.get_bone_count():
		var name_here: String = skeleton.get_bone_name(b).trim_prefix(PREFIX)
		_our_to_src[b] = int(by_name.get(name_here, -1))
		if _our_to_src[b] < 0:
			missing += 1
	_our_rest_fix.resize(skeleton.get_bone_count())
	for b: int in skeleton.get_bone_count():
		var own_name: String = skeleton.get_bone_name(b).trim_prefix(PREFIX)
		var fix: Quaternion = Quaternion.IDENTITY
		var child_name: String = String(REST_CHILD.get(own_name, ""))
		if child_name != "" and _bones.has(child_name) and by_name.has(own_name) and by_name.has(child_name):
			var ours_vector: Vector3 = skeleton.get_bone_global_rest(int(_bones[child_name])).origin - skeleton.get_bone_global_rest(b).origin
			var source_vector: Vector3 = source_skeleton.get_bone_global_rest(int(by_name[child_name])).origin - source_skeleton.get_bone_global_rest(int(by_name[own_name])).origin
			if ours_vector.length() > 0.001 and source_vector.length() > 0.001:
				fix = Quaternion(ours_vector.normalized(), source_vector.normalized())
		elif child_name == "":
			var parent_bone: int = skeleton.get_bone_parent(b)
			if parent_bone >= 0 and parent_bone < b:
				fix = _our_rest_fix[parent_bone]
		_our_rest_fix[b] = fix
	source.free()
	return _hips_track >= 0 and missing == 0 and _our_to_src[int(_bones["Hips"])] >= 0


## The animation's time for the performance's `t`: the crawl runs `CLIP_START` into the clip, and the clip is held (stalled) when the figure stops, over the end of the crawl and the death.
func _clip_time(t: float, crawl: float) -> float:
	if t <= crawl:
		return minf(CLIP_START + t, _clip.length)

	return minf(CLIP_START + crawl + CLIP_COAST * (1.0 - exp(-(t - crawl) / CLIP_COAST_TAU)), _clip.length)


## The hips' forward travel in the clip (metres, its own scale) at an animation time: how far the figure has crawled.
func _hips_forward(clip_time: float) -> float:
	return _clip.position_track_interpolate(_hips_track, clip_time).z


## How far along the path the figure is: the share of the hips' own travel over the crawl (so the feet and hands never slide).
func _clip_progress(t: float) -> float:
	var start: float = _hips_forward(CLIP_START)
	var whole: float = _hips_forward(minf(CLIP_START + _crawl_seconds(), _clip.length)) - start
	return clampf((_hips_forward(minf(CLIP_START + _crawl_time(t), _clip.length)) - start) / maxf(whole, 0.001), 0.0, 1.0)


## How long the figure is seen crawling (the shadow shows at `lead_seconds` and is gone at `glitch_until`), and how far into that `t` is.
func _crawl_seconds() -> float:
	return maxf(glitch_until - lead_seconds, 0.5)


func _crawl_time(t: float) -> float:
	return clampf(t - lead_seconds, 0.0, _crawl_seconds())


## How far the whole crawl travels on the ground (metres, at the figure's scale): the length the path should have, so that nothing slides.
func clip_travel_metres() -> float:
	if not clip_ready:
		return 0.0

	return (_hips_forward(minf(CLIP_START + _crawl_seconds(), _clip.length)) - _hips_forward(CLIP_START)) * _clip_scale * _scale


## The pose at `t`: the crawl (retargeted), then at its end the figure gives out: the last reach stalls, the body drops to the ground, rolls a little onto its side and shudders, and lies still.
func _pose_clip(t: float, crawl: float, dying: float) -> void:
	var clip_time: float = _clip_time(t, crawl)
	var count: int = _src_names.size()
	var source_global: Array[Quaternion] = []
	source_global.resize(count)
	for s: int in count:
		var local: Quaternion = _src_rest_local[s]
		if _src_rot_track[s] >= 0:
			local = _clip.rotation_track_interpolate(_src_rot_track[s], clip_time)
		source_global[s] = local if _src_parent[s] < 0 else source_global[_src_parent[s]] * local
	# Giving out: the chest sags and the head drops to the ground (turns in the model's own frame, about its X axis, which takes what points forward down).
	var since_now: float = dying * DEATH_SECONDS
	var sag: float = smoothstep(0.0, 0.55, since_now) + 0.12 * exp(-3.0 * since_now) * sin(since_now * 30.0) * smoothstep(0.0, 0.1, since_now)
	var ours_global: Array[Quaternion] = []
	ours_global.resize(skeleton.get_bone_count())
	for b: int in skeleton.get_bone_count():
		var s: int = _our_to_src[b]
		var turn: Quaternion = (source_global[s] * _src_rest_global[s].inverse() * _our_rest_fix[b]) if s >= 0 else Quaternion.IDENTITY
		if dying > 0.0 and COLLAPSE_SAG.has(_src_names[s] if s >= 0 else ""):
			turn = Quaternion(Vector3.RIGHT, deg_to_rad(float(COLLAPSE_SAG[_src_names[s]]) * sag)) * turn
		ours_global[b] = turn
		var parent: int = skeleton.get_bone_parent(b)
		var parent_turn: Quaternion = Quaternion.IDENTITY if parent < 0 else ours_global[parent]
		skeleton.set_bone_pose_rotation(b, parent_turn.inverse() * turn)
	# The hips: their height and sideways sway from the clip (the forward travel is the path's).
	var hips: int = int(_bones["Hips"])
	var rest: Vector3 = skeleton.get_bone_rest(hips).origin
	var moved: Vector3 = _clip.position_track_interpolate(_hips_track, clip_time) - _src_hips_rest
	skeleton.set_bone_pose_position(hips, rest + Vector3(moved.x, moved.y, 0.0) * _clip_scale)

	# The end: it gives out. The body falls to the ground and rolls a little onto its side, with a shudder that dies away.
	if _model != null:
		var since: float = dying * DEATH_SECONDS
		var fall: float = smoothstep(0.0, 0.45, since)
		var shudder: float = exp(-2.6 * since) * sin(since * 34.0) * smoothstep(0.0, 0.12, since)
		var roll: float = -30.0 * smoothstep(0.1, 1.0, dying) + shudder * 3.0
		var sink: float = 0.0 if dying <= 0.0 else -collapse_drop * _scale * fall
		_model.basis = Basis(Vector3.FORWARD, deg_to_rad(roll)) * Basis.from_scale(Vector3.ONE * _scale)
		_model.position = Vector3(0.0, MODEL_FLOOR * _scale + sink, 0.0)


# ============================================================
# THE CAMERA FAILING (the animated crawl's end)
# ============================================================

## A number between 0 and 1 from a whole number (a hash with no state).
func _hash(cell: float) -> float:
	return fposmod(sin(cell * 12.9898 + 4.1414) * 43758.5453, 1.0)


## The scene, as horror does it (found footage, the VHS horror of games and films): a restraint and a rhythm, not a constant noise. The picture first goes wrong a little, in tiny disturbances and dips of the light, with
## nothing in it (so something is coming); the light fails altogether for an instant, and when it comes back the shadow is there, crawling, whole and readable, in a picture that is darker than before; the camera
## hiccups only in a few quick spikes, each one with the shadow skipping (a frame lost: it is suddenly further on, or back) or stuttering, never hiding it for long; the light flickers harder; the last spike, a blackout and
## a burst of static, and when the light returns the shadow is gone and the picture is calmer than it ever was, as if nothing had happened. All of it is a pure function of the time (`t`, seconds of the performance;
## `lead_seconds` is when the shadow shows, `glitch_until` when it is gone).

## Quick spikes of the camera failing while the shadow crawls: [when (seconds after it shows), how long, how bad (0 to 1), how far the shadow skips (metres along its way), how solid it is meanwhile].
const SPIKES: Array = [[0.45, 0.10, 0.9, 0.22, 0.5], [1.1, 0.12, 1.0, -0.14, 0.0], [1.65, 0.10, 0.95, 0.3, 0.5], [2.05, 0.14, 1.0, 0.0, 0.5]]
## Dips of the light (a flicker): [when (seconds after it shows; negative is before), how long, how dark (0 to 1)].
const DIPS: Array = [[-0.95, 0.05, 0.55], [-0.68, 0.04, 0.7], [-0.48, 0.05, 0.5], [0.85, 0.06, 0.6], [1.3, 0.04, 0.8], [1.9, 0.05, 0.7], [2.0, 0.035, 0.85], [2.12, 0.035, 0.9]]


## How badly the camera is failing `t` seconds in (0 is a clean picture, 1 the worst).
func glitch_at(t: float) -> float:
	if not clip_ready or t < glitch_from or t > total_seconds:
		return 0.0

	var cell: float = floorf(t * 16.0)
	var noise: float = 0.6 + 0.4 * _hash(cell)
	var value: float = 0.0
	if t < lead_seconds:
		# Before the shadow: small disturbances that grow a little.
		value = (0.08 + 0.14 * smoothstep(0.0, lead_seconds, t)) * noise
	elif t < glitch_until:
		value = 0.1 * noise
	elif t < glitch_until + 0.9:
		# After it: the last of it, dying away.
		value = 0.3 * (1.0 - smoothstep(0.4, 0.9, t - glitch_until)) * noise
	for spike: Array in SPIKES:
		var begin: float = lead_seconds + float(spike[0])
		if t >= begin and t < begin + float(spike[1]):
			value = maxf(value, float(spike[2]) * (0.75 + 0.25 * _hash(cell + 40.0)))
	if _blackout_at(t) > 0.0:
		value = maxf(value, 0.7)
	return clampf(value, 0.0, 1.0)


## 1 inside a blackout (the light fails altogether): just before the shadow shows, and as it goes.
func _blackout_at(t: float) -> float:
	if t >= lead_seconds - 0.3 and t < lead_seconds + 0.02:
		return 1.0
	if t >= glitch_until - 0.05 and t < glitch_until + 0.35:
		return 1.0
	return 0.0


## How dark the picture is (0 normal, 1 black): the light flickers before the shadow, fails for an instant, comes back dimmer, flickers harder as the end comes, fails, and comes back as it was.
func dim_at(t: float) -> float:
	if not clip_ready:
		return 0.0

	if _blackout_at(t) > 0.0:
		return 0.96

	var level: float = 0.0
	if t >= lead_seconds + 0.02 and t < glitch_until:
		# Darker than before while it crawls (and a little darker still toward the end).
		level = 0.2 * smoothstep(lead_seconds + 0.02, lead_seconds + 0.35, t) + 0.06 * smoothstep(lead_seconds + 1.0, glitch_until, t)
	for dip: Array in DIPS:
		var begin: float = lead_seconds + float(dip[0])
		if t >= begin and t < begin + float(dip[1]):
			level = maxf(level, float(dip[2]))
	return level


## How much of the picture is nothing but static `t` seconds in: a burst as the light fails before the shadow, a spit at the start of each spike, and the last, total, as it goes.
func static_at(t: float) -> float:
	if not clip_ready:
		return 0.0

	if t >= lead_seconds - 0.25 and t < lead_seconds - 0.1:
		return 0.9
	if t >= glitch_until - 0.05 and t < glitch_until + 0.1:
		return 1.0
	for spike: Array in SPIKES:
		var begin: float = lead_seconds + float(spike[0])
		if t >= begin and t < begin + 0.05:
			return 0.35 + 0.1 * float(spike[2])
	return 0.0


## How solid the figure is `t` seconds in: not there until `lead_seconds`; whole and readable while it crawls, but for the spikes (when it stutters: faded, or gone for an instant); gone from `glitch_until` on.
func ghost_alpha_at(t: float) -> float:
	if t < lead_seconds or t >= glitch_until:
		return 0.0

	for spike: Array in SPIKES:
		var begin: float = lead_seconds + float(spike[0])
		if t >= begin and t < begin + float(spike[1]):
			return float(spike[4])
	return 0.97


## How far along its way the figure is thrown at `t` (metres: a frame lost, it is suddenly further on or back), only in the spikes.
func skip_offset_at(t: float) -> float:
	for spike: Array in SPIKES:
		var begin: float = lead_seconds + float(spike[0])
		if t >= begin and t < begin + float(spike[1]):
			return float(spike[3])
	return 0.0


## The figure's solidity and its shaking, as the camera fails: the shadow's alpha follows `ghost_alpha_at`, and the body is thrown a little sideways and stretched in the frames the camera is worst.
func _apply_glitch(t: float) -> void:
	var alpha: float = ghost_alpha_at(t)
	if _material != null:
		_material.set_shader_parameter(&"body_alpha", alpha)
	elif body != null:
		body.visible = alpha > 0.5
	var g: float = glitch_at(t)
	if _model != null and g > 0.0:
		var cell: float = floorf(t * 18.0)
		_model.position.x += (_hash(cell + 31.0) - 0.5) * 0.1 * g
		_model.position.z += (_hash(cell + 57.0) - 0.5) * 0.05 * g + skip_offset_at(t)
		_model.basis = _model.basis * Basis.from_scale(Vector3(1.0 + (_hash(cell + 83.0) - 0.5) * 0.5 * g, 1.0, 1.0 + (_hash(cell + 91.0) - 0.5) * 0.3 * g))
