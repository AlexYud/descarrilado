extends Node3D
class_name ShelterFootage

## The waiting shed's archival recording: the EXCERPT, about 62 seconds, silent, in four shots joined by three hard cuts, preceded on the full TAPE by a short REAR segment (see `rear_prefix_seconds`: the excerpt's
## clock is 0 to `length_seconds`; the rear segment lives at excerpt times from `-rear_prefix_seconds` to 0, so the TAPE's own time is the excerpt's plus the prefix). Everything is a pure function of one clock, `seek(t)` (the cast) and
## `camera_at(t)` (the picture's camera): a pause, a replay from any time, a seek backwards or a cancel gives the same picture. Nothing here is a timer, a tween, a callback or a random number.
##
##   A (0 to `cut_walk_seconds`, 20 s): a hidden, locked camera outside the shelter, behind a few ferns, watches Emily sit on the bench. She waits (`turn_start_seconds`, 10 s of it), turns her head and
##      shoulders toward HER RIGHT, raises her right hand in a short greeting to someone outside the picture, lowers it, and listens, nodding a little. Nobody else exists in the picture.
##   B (to `cut_aftermath_seconds`, 12 s): a hard cut to a camera being carried forward, pointed at the forest floor: genuine travel along a strip of ground between two markers (9 m, a slow walking
##      pace), at the eyes of a person 1.70 m tall, with the motion of steps (`_gait`: a dip and rise at every step, a pace that breathes inside it, a lean at every second step; smooth functions of
##      the time, no jitter). No operator is shown. How long passed between the shots is not said.
##   C (to `cut_walk2_seconds`, 14 s): a hard cut to the empty shelter, bloodstained, its bench broken, seen from OUTSIDE, from the dark of the forest (not from the aftermath photograph's viewpoint): someone
##      stands there at a pillar's edge with a camera at their eyes, then creeps in step by step at a steady pace, the aim trailing the body and sliding to the pool of blood, the lens closing in on it. No
##      body, no Emily, no shadow of anyone.
##   B again (to `length_seconds`, 16 s): a hard cut to the carried camera over the forest floor along a DIFFERENT strip (`walk2_start` to `walk2_end`, 12 m), walked as by someone dragging something heavy
##      (slower, longer, heaving steps), and the tape ends.
##
## The cast is the shared rigged mannequin as a LOCAL copy (`ArchiveActor`) built from a few numbers at the first `prepare` (off camera); the blood is the capture tool's own dressing
## (`ShelterAftermathDressing`) built once and shown only in shot C. Every moment below is an export, so it can be re-timed in play.

@export_category("Placement")
## The point on the seat under Emily's pelvis (+Z of the marker is the way she faces; her left is then the marker's +X).
@export var marina_seat: Marker3D
## How high the seat's top is over the floor she stands on, in metres.
@export var bench_seat_height: float = 0.44
@export var marina_scale: float = 0.9

@export_category("Source (seconds)")
@export var length_seconds: float = 62.0
## The hard cuts: to the carried camera, to the aftermath, and to the carried camera again.
@export var cut_walk_seconds: float = 20.0
@export var cut_aftermath_seconds: float = 32.0
@export var cut_walk2_seconds: float = 46.0

@export_category("Emily's greeting (seconds)")
## She sits still until `turn_start_seconds` (ten seconds of watching), turns her head toward her right until `turn_end_seconds`, raises her right hand until `hand_up_end_seconds`, waves
## for `wave_seconds`, lowers it until `hand_down_end_seconds`, then listens (a nod at each of `nod_seconds`). `greet_on_right` false mirrors all of it to her left.
@export var greet_on_right: bool = true
@export var turn_start_seconds: float = 10.0
@export var turn_end_seconds: float = 12.0
@export var hand_up_start_seconds: float = 12.0
@export var hand_up_end_seconds: float = 13.0
@export var wave_seconds: float = 1.6
@export var hand_down_end_seconds: float = 16.4
@export var nod_seconds: PackedFloat32Array = PackedFloat32Array([17.4, 19.0])
## How far her head turns (degrees: the neck and the head together), and the shoulders' share of it.
@export var head_turn_degrees: float = 62.0
@export var torso_turn_degrees: float = 12.0

@export_category("Shot A: the hidden camera")
@export var shot_a: ShotMarker

@export_category("Shots B: the carried camera")
## The strips of ground the camera travels along, one for each walking shot (their first and last point; their height is taken from the ground under them when there is one).
@export var walk_start: Marker3D
@export var walk_end: Marker3D
@export var walk2_start: Marker3D
@export var walk2_end: Marker3D
## The camera's height over the ground: the lens of a camera held up in front of the face by a person 1.70 m tall (the eyes are at about 1.6 m), its downward pitch (degrees) and its lens.
@export var carry_height: float = 1.62
@export var walk_pitch_degrees: float = 55.0
@export var walk_fov: float = 54.0
## The first walk, an ordinary one. The gait is built from steps (see `_gait`): `steps_per_second` is the cadence, `walk_bob_metres` how far the head rises and falls over a step (it is lowest as a foot
## lands and rises over the step), `walk_sway_metres` the lean from side to side (once per two steps), `walk_surge` how much the forward speed breathes inside a step (a fraction of the pace: the body
## is quickest as it comes down onto a foot and slowest at the top of its arc), roll, yaw and nod (degrees) the body's twist and tip with the stride, and `walk_wander_degrees` a slow heading wander.
@export var walk_bob_metres: float = 0.024
@export var walk_sway_metres: float = 0.02
@export var walk_surge: float = 0.12
@export var walk_roll_degrees: float = 0.9
@export var walk_yaw_degrees: float = 0.8
@export var walk_nod_degrees: float = 0.7
@export var walk_wander_degrees: float = 1.5
@export var steps_per_second: float = 1.8
## The second walk, a person dragging something heavy behind them: slower steps (a lower cadence) and longer ones (the strip is walked at about the same pace, so each step covers much more ground),
## each one a heave: the head drops further, the body lunges (a big surge of speed as it pulls, then a drag), leans, and twists with the load.
@export var drag_bob_metres: float = 0.045
@export var drag_sway_metres: float = 0.05
@export var drag_surge: float = 0.45
@export var drag_roll_degrees: float = 2.0
@export var drag_yaw_degrees: float = 2.6
@export var drag_nod_degrees: float = 1.6
@export var drag_steps_per_second: float = 1.1

@export_category("Shot C: the aftermath")
## Where the camera begins: out in the dark of the forest, west of the shelter, at the eyes of a person standing (`ShotRecordingC`: its lens is the opening one, its target the first thing it looks at, the
## shelter with a pillar in front of it). NOT the aftermath photograph's viewpoint: someone is looking in from outside.
@export var shot_c: ShotMarker
## Where it ends up after creeping in, step by step (the first marker's height is kept), and what it ends up looking at: the pool of blood. The aim moves from the first target toward it.
@export var creep_end: Marker3D
@export var blood_focus: Marker3D
## The lens at the end (the vertical field of view, degrees: a zoom on the blood).
@export var creep_closest_fov: float = 44.0
## When the creeping starts and stops (seconds into the shot: the person stands still before and after) and how long it takes to get up to its pace and to slow to a stop (seconds).
@export var creep_start_seconds: float = 1.6
@export var creep_stop_seconds: float = 12.4
@export var creep_ramp_seconds: float = 0.9
## The creeping gait: the cadence (steps per second: slow and careful), how far the head dips and rises over a step (metres), the lean from side to side (metres), the surge inside a step (a fraction of the
## pace), the roll, yaw and nod (degrees) the stride puts into the hands.
@export var creep_steps_per_second: float = 1.15
@export var creep_bob_metres: float = 0.03
@export var creep_sway_metres: float = 0.024
@export var creep_surge: float = 0.2
@export var creep_roll_degrees: float = 1.1
@export var creep_yaw_degrees: float = 1.0
@export var creep_nod_degrees: float = 0.9
## How far behind the body the aim trails (seconds), and the hands: drift of the position (metres), of the aim (degrees yaw and pitch) and of the roll (degrees).
@export var aim_lag_seconds: float = 0.5
@export var hand_drift_metres: float = 0.012
@export var hand_drift_degrees: float = 0.4
@export var hand_roll_degrees: float = 0.35
## How much darker the stains are drawn than the capture tool's dressing (a multiplier on their colour), so that they read through the tape look.
@export var stain_darkening: float = 0.3

@export_category("The rear segment (earlier on the tape, voluntary review only)")
## How long the rear segment is (seconds). The excerpt starts this long after the start of the tape. It is never part of the directed first viewing.
@export var rear_prefix_seconds: float = 8.0
## The low camera behind the shelter (a marker with a target and a lens) and the blood words on the rear face of the low wall (in the space of this node: the middle of the words, their size).
@export var shot_rear: ShotMarker
@export var rear_message_at: Vector3 = Vector3(-4.90, 0.40, -7.353)
@export var rear_message_size: Vector2 = Vector2(0.52, 0.17)
## A very small hand drift of the rear camera (metres), the only movement of the segment.
@export var rear_drift_metres: float = 0.004
## From this time into the rear segment (s) the camera's lamp comes up, narrow, on the token.
@export var rear_lamp_from_seconds: float = 6.4
## The rear segment's handheld walk (see `_rear_camera`), in the shed's space: when (s into the segment), where the lens is, what it looks at, and its lens (fov).
@export var rear_key_times: PackedFloat32Array = PackedFloat32Array([0.0, 0.8, 2.6, 4.6, 6.2, 7.2, 8.0])
@export var rear_key_positions: PackedVector3Array = PackedVector3Array([Vector3(-4.30, 1.32, -9.70), Vector3(-4.35, 1.32, -9.55), Vector3(-4.80, 1.22, -8.90), Vector3(-4.92, 1.18, -8.60), Vector3(-5.46, 1.00, -8.10), Vector3(-5.57, 0.90, -7.80), Vector3(-5.58, 0.74, -7.73)])
@export var rear_key_aims: PackedVector3Array = PackedVector3Array([Vector3(-4.90, 0.50, -7.35), Vector3(-4.90, 0.50, -7.35), Vector3(-4.90, 0.40, -7.35), Vector3(-4.95, 0.38, -7.35), Vector3(-5.58, 0.12, -7.40), Vector3(-5.60, 0.06, -7.415), Vector3(-5.60, 0.06, -7.415)])
@export var rear_key_fovs: PackedFloat32Array = PackedFloat32Array([52.0, 52.0, 48.0, 46.0, 40.0, 32.0, 30.0])
## The drag trail seen through the camcorder's viewfinder (NOT in the recording): the path of the smear, in the space of this node (the shelter's), each point's y the height it lies at. It is only ever drawn by `set_blood_view`.
@export var trail_points: PackedVector3Array = PackedVector3Array()
## The stains of the aftermath that the viewfinder's view leaves out (they lead to the cracked pillar, a second destination); the recording's own shot shows all of them.
@export var blood_view_hidden_stains: PackedStringArray = PackedStringArray(["Smear", "PillarEast"])

var marina: ArchiveActor = null
## The forest floor of each carried camera's strip: leaf litter and stones laid along it (the existing leaf-litter and stone models), shown in that shot only.
var litter: Node3D = null
var litter2: Node3D = null
## The blood of the aftermath (the capture tool's dressing), shown only in shot C.
var aftermath: Node3D = null
## The drag trail of the camcorder's viewfinder: shown only by `set_blood_view`.
var trail: Node3D = null
## The words in blood of the rear segment: shown only in it.
var rear_message: MeshInstance3D = null
var _blood_view: bool = false
## The footage time the cast was last posed at (`seek`).
var current_time: float = 0.0

var _prepared: bool = false
var _floor_y: float = 0.0
var _seat_height: float = 0.44
var _walk_ground: PackedFloat32Array = PackedFloat32Array()
var _walk2_ground: PackedFloat32Array = PackedFloat32Array()

const WALK_SAMPLES: int = 25
const LEAF_MESH: String = "res://assets/models/foliage/ground_leaves_01/ground_leaves_01_mesh.tres"
const STONE_MODELS: Array[String] = ["res://assets/models/rocks/floor_path/rock_001/rock_001.glb", "res://assets/models/rocks/floor_path/rock_002/rock_002.glb"]


func _ready() -> void:
	# Nothing of the cast is ever seen until a sequence shows it.
	visible = false


func is_prepared() -> bool:
	return _prepared


## Builds and poses the cast and the blood (once). Call it while nothing of it is on screen. They stay hidden until `show_cast`.
func prepare() -> void:
	if _prepared or marina_seat == null or not is_inside_tree():
		return

	visible = false
	marina = ArchiveActor.new()
	marina.name = "Emily"
	marina.actor_scale = marina_scale
	marina.life_phase = 0.0
	marina.life = 0.3
	marina.palette = {
		&"top": Color(0.7, 0.72, 0.78), &"bottom": Color(0.4, 0.41, 0.46),
		&"skin": Color(0.88, 0.74, 0.64), &"hair": Color(0.2, 0.14, 0.1), &"shoes": Color(0.14, 0.13, 0.13),
	}
	add_child(marina)
	marina.build()
	_floor_y = marina_seat.global_position.y - bench_seat_height
	_seat_height = bench_seat_height
	_key_marina()
	_place_marina()
	aftermath = ShelterAftermathDressing.build(self)
	aftermath.name = "AftermathStains"
	aftermath.visible = false
	_darken_stains(aftermath)
	if trail_points.size() >= 2:
		trail = ShelterAftermathDressing.build_trail(self, trail_points)
		trail.visible = false
		_darken_stains(trail, stain_darkening * 0.3)
	_build_rear_message()
	_walk_ground = _sample_ground(walk_start, walk_end)
	_walk2_ground = _sample_ground(walk2_start, walk2_end)
	litter = _build_litter("WalkLitter", walk_start, walk_end, _walk_ground, 4417)
	litter2 = _build_litter("WalkLitter2", walk2_start, walk2_end, _walk2_ground, 5231)
	_prepared = true
	seek(0.0)


## Shown (under a cut) or hidden. Hidden, nothing of the cast, the stains or their shadows is drawn.
func show_cast(shown: bool) -> void:
	# Whatever the blood view had put on is put back: the recording's own shots (and nothing at all) show the stains as the recording has them.
	_clear_blood_view()
	visible = shown and _prepared


## The empty, bloodstained shelter for the camcorder's viewfinder, as a STATIC dressing (no clock, no camera, no actor): the stains of the aftermath (but for those that lead to the
## cracked pillar) and the drag trail, and nothing else of the cast. `show_cast` (or `set_blood_view(false)`) puts everything back. Not for the recording, which never calls it.
func set_blood_view(on: bool) -> void:
	if not _prepared:
		return

	if not on:
		_clear_blood_view()
		visible = false
		return

	_blood_view = true
	visible = true
	marina.visible = false
	if litter != null:
		litter.visible = false
	if litter2 != null:
		litter2.visible = false
	aftermath.visible = true
	for stain: Node in aftermath.get_children():
		var item: Node3D = stain as Node3D
		if item != null:
			item.visible = not (String(item.name) in blood_view_hidden_stains)
	if trail != null:
		trail.visible = true


func is_blood_view() -> bool:
	return _blood_view


func _clear_blood_view() -> void:
	if not _blood_view:
		return

	_blood_view = false
	if aftermath != null:
		aftermath.visible = false
		for stain: Node in aftermath.get_children():
			var item: Node3D = stain as Node3D
			if item != null:
				item.visible = true
	if trail != null:
		trail.visible = false


## "A", "walk", "aftermath" or "walk2": the shot the source is in at `time`.
func passage_at(time: float) -> StringName:
	if time < 0.0:
		return &"rear"
	if time >= cut_walk2_seconds:
		return &"walk2"
	if time >= cut_aftermath_seconds:
		return &"aftermath"
	if time >= cut_walk_seconds:
		return &"walk"
	return &"A"


## The cast at `time` (seconds): Emily's pose and whether she, the blood and the litter are in the picture. A pure function of the time.
func seek(time: float) -> void:
	if not _prepared:
		return

	current_time = time
	var passage: StringName = passage_at(time)
	# Emily is in the picture in shot A only (hidden, her shadow goes with her); the blood in shot C only; each strip's litter in its own shot.
	marina.visible = passage == &"A"
	if rear_message != null:
		rear_message.visible = passage == &"rear"
	aftermath.visible = passage == &"aftermath"
	if litter != null:
		litter.visible = passage == &"walk"
	if litter2 != null:
		litter2.visible = passage == &"walk2"
	marina.sample(maxf(time, 0.0))


# ============================================================
# THE PICTURE'S CAMERA
# ============================================================

## The camera's transform and lens at `time`: {"transform": Transform3D, "fov": float}. Shot A is locked, the walks walk (the second one drags), shot C creeps in; each has its own motion and none shares another's.
func camera_at(time: float) -> Dictionary:
	match passage_at(time):
		&"walk":
			return _walk_camera(time - cut_walk_seconds, cut_aftermath_seconds - cut_walk_seconds, walk_start, walk_end, _walk_ground, false)
		&"walk2":
			return _walk_camera(time - cut_walk2_seconds, length_seconds - cut_walk2_seconds, walk2_start, walk2_end, _walk2_ground, true)
		&"rear":
			return _rear_camera(time + rear_prefix_seconds)
		&"aftermath":
			return _aftermath_camera(time - cut_aftermath_seconds)
	return {"transform": shot_a.aimed_transform() if shot_a != null else Transform3D.IDENTITY, "fov": shot_a.fov if shot_a != null else 26.0}


## What a walking body does to a camera held in front of it, `seconds` into a walk of `cadence` steps a second. A pure function of the time; every part of it is tied to the same step phase `steps`
## (the count of steps taken so far), so that the picture moves the way a body does:
##   "up":    the head's height over its mean (metres): the body is an inverted pendulum, an arc over each step and a low point as a foot lands, so the height is the shape of an arc between low points
##            (a sharp dip, a rounded top); alternate steps differ a little, as a left and a right do;
##   "side":  the lean from side to side (metres), once per two steps;
##   "surge": the share of the forward pace now (1 is the mean): the body is quickest as it comes down and slowest at the top of its arc;
##   "ahead": how far that breathing has put the body ahead of or behind a steady advance (metres, for a pace in metres a second);
##   "roll", "yaw", "nod": the body's tip, twist and nod (radians) over the stride.
## A real gait has two steps to a stride, so the side, roll and yaw go once per two steps; the nod once per step.
func _gait(seconds: float, cadence: float, bob: float, sway: float, surge: float, roll_degrees: float, yaw_degrees: float, nod_degrees: float, pace: float) -> Dictionary:
	var steps: float = cadence * seconds
	var cycle: float = steps - floorf(steps)
	var arc: float = sin(PI * cycle)
	# The arc between footfalls, rounded off a little at the foot so that the dip is quick, not a cusp.
	var rounded: float = (sqrt(arc * arc + 0.02) - sqrt(0.02)) / (sqrt(1.02) - sqrt(0.02))
	var parity: float = 1.0 if int(floorf(steps)) % 2 == 0 else -1.0
	var up: float = bob * (2.0 * rounded * (1.0 + 0.1 * parity) - 1.0)
	var stride: float = TAU * steps * 0.5
	return {
		"up": up,
		"side": sway * sin(stride + 0.6),
		"surge": 1.0 + surge * cos(TAU * steps),
		"ahead": pace * surge / (TAU * cadence) * sin(TAU * steps),
		"roll": deg_to_rad(roll_degrees) * sin(stride + 0.2),
		"yaw": deg_to_rad(yaw_degrees) * sin(stride + 1.4),
		"nod": deg_to_rad(nod_degrees) * sin(TAU * steps + 1.0),
	}


## Where a carried camera is `seconds` after the cut to it, over `duration` seconds along the strip from `start` to `end`: forward at an even pace that breathes with each step, at the eyes of a person
## 1.70 m tall, its height rising and falling with the steps, a lean at every second step, a little roll, twist and nod, the lens always pitched down at the ground. `dragging` is the other gait (slow,
## long, heaving steps, as of someone pulling a weight behind them).
func _walk_camera(seconds: float, duration: float, start: Marker3D, end: Marker3D, ground_table: PackedFloat32Array, dragging: bool) -> Dictionary:
	var u: float = clampf(seconds / maxf(duration, 0.001), 0.0, 1.0)
	var from: Vector3 = start.global_position if start != null else Vector3.ZERO
	var to: Vector3 = end.global_position if end != null else Vector3(0.0, 0.0, -4.0)
	var along: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	var heading: Vector3 = along.normalized() if along.length() > 0.01 else Vector3(0.0, 0.0, -1.0)
	var side: Vector3 = Vector3(-heading.z, 0.0, heading.x).normalized()
	var ground: float = _ground_at(ground_table, u, from.y, to.y)
	var pace: float = along.length() / maxf(duration, 0.001)
	var gait: Dictionary
	if dragging:
		gait = _gait(seconds, drag_steps_per_second, drag_bob_metres, drag_sway_metres, drag_surge, drag_roll_degrees, drag_yaw_degrees, drag_nod_degrees, pace)
	else:
		gait = _gait(seconds, steps_per_second, walk_bob_metres, walk_sway_metres, walk_surge, walk_roll_degrees, walk_yaw_degrees, walk_nod_degrees, pace)
	# The breathing of the pace puts the body ahead of or behind a steady advance; it dies away at both ends of the strip, so the strip is walked from its first point to its last.
	var advance: float = clampf(u * along.length() + float(gait["ahead"]) * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.92, 1.0, u)), 0.0, along.length())
	var on_strip: Vector3 = from + heading * advance
	var at: Vector3 = Vector3(on_strip.x, ground + carry_height + float(gait["up"]), on_strip.z) + side * float(gait["side"])
	var wander: float = deg_to_rad(walk_wander_degrees) * (sin(seconds * 1.7 + 0.8) * 0.6 + sin(seconds * 0.63 + 2.1) * 0.4)
	var facing: Vector3 = heading.rotated(Vector3.UP, wander + float(gait["yaw"]))
	var basis: Basis = Basis.looking_at(facing, Vector3.UP)
	var pitch: float = deg_to_rad(walk_pitch_degrees) + float(gait["nod"])
	basis = basis * Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.BACK, float(gait["roll"]))
	return {"transform": Transform3D(basis, at), "fov": walk_fov}


## The camera `seconds` after the cut to the aftermath: someone creeping in on the shelter from the dark of the forest, a person of 1.70 m with a camera held up to the face, looking in at the blood. It stands
## a moment at `shot_c` (a pillar in front, the broken bench beyond it), then walks, step by step and at a steady pace, toward `creep_end`, the aim trailing the body (`aim_lag_seconds`) and sliding
## from the shelter to the pool of blood, the lens closing in on it as they go; at the end it stands again. The walking is `_gait` (a cadence, a dip and rise at every step, a breathing pace, a
## lean), present only while the body moves (the pace ramps up and down over `creep_ramp_seconds`), and on top of it the hands: slow drifts of the position and the aim (sums of three sines that never line up).
func _aftermath_camera(seconds: float) -> Dictionary:
	var base: Transform3D = shot_c.aimed_transform() if shot_c != null else Transform3D.IDENTITY
	var first_target: Vector3 = shot_c.target.global_position if shot_c != null and shot_c.target != null else base.origin + (-base.basis.z) * 4.0
	var last_target: Vector3 = blood_focus.global_position if blood_focus != null else first_target
	var stop_at: Vector3 = Vector3(creep_end.global_position.x, base.origin.y, creep_end.global_position.z) if creep_end != null else base.origin
	var duration: float = maxf(cut_walk2_seconds - cut_aftermath_seconds, 0.001)
	var walking: float = maxf(creep_stop_seconds - creep_start_seconds, 0.001)
	var ramp: float = clampf(creep_ramp_seconds, 0.01, walking * 0.5)
	# The distance walked, as a share of the whole way: still, up to a steady pace over `ramp`, steady, down to still over `ramp`, still. (The pace is constant between the ramps.)
	var t: float = clampf(seconds - creep_start_seconds, 0.0, walking)
	var cruise: float = 1.0 / (walking - ramp)
	var share: float
	if t < ramp:
		share = cruise * t * t / (2.0 * ramp)
	elif t > walking - ramp:
		var left: float = walking - t
		share = 1.0 - cruise * left * left / (2.0 * ramp)
	else:
		share = cruise * (t - ramp * 0.5)
	var path: Vector3 = stop_at - base.origin
	var length: float = Vector2(path.x, path.z).length()
	var heading: Vector3 = Vector3(path.x, 0.0, path.z).normalized() if length > 0.01 else Vector3(0.0, 0.0, -1.0)
	var side: Vector3 = Vector3(-heading.z, 0.0, heading.x).normalized()
	# How much the body is moving now (0 standing, 1 at its pace): the gait exists only in proportion to it.
	var moving: float = 0.0
	if seconds > creep_start_seconds and seconds < creep_stop_seconds:
		moving = clampf(minf(t, walking - t) / ramp, 0.0, 1.0)
	var pace: float = length / walking
	var gait: Dictionary = _gait(t, creep_steps_per_second, creep_bob_metres, creep_sway_metres, creep_surge, creep_roll_degrees, creep_yaw_degrees, creep_nod_degrees, pace)
	var ahead: float = float(gait["ahead"]) * moving
	var distance: float = clampf(share * length + ahead, 0.0, length)
	var drift: Vector3 = Vector3(_drift(seconds, 1.0), _drift(seconds, 2.3) * 0.7, _drift(seconds, 3.1)) * hand_drift_metres
	var origin: Vector3 = base.origin + heading * distance + side * (float(gait["side"]) * moving) + Vector3.UP * (float(gait["up"]) * moving) + drift
	# The aim trails the body, then eases onto the blood.
	var aim_share: float = _smooth(clampf((seconds - creep_start_seconds - aim_lag_seconds) / (walking + 1.0), 0.0, 1.0))
	var aim_at: Vector3 = first_target.lerp(last_target, aim_share)
	var aim: Basis = Basis.looking_at((aim_at - origin).normalized(), Vector3.UP)
	var yaw: float = deg_to_rad(hand_drift_degrees) * (_drift(seconds, 4.7) + 0.25 * _drift(seconds * 2.3, 6.1)) + float(gait["yaw"]) * moving
	var pitch: float = deg_to_rad(hand_drift_degrees) * 0.8 * (_drift(seconds, 5.9) + 0.2 * _drift(seconds * 2.1, 7.3)) + float(gait["nod"]) * moving
	var roll: float = deg_to_rad(hand_roll_degrees) * _drift(seconds, 8.3) + float(gait["roll"]) * moving
	var basis: Basis = aim * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	var start_fov: float = shot_c.fov if shot_c != null else 60.0
	var fov: float = lerpf(start_fov, creep_closest_fov, aim_share)
	return {"transform": Transform3D(basis, origin), "fov": fov}


## A smooth rise from 0 to 1 (zero slope at both ends).
func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## The rear segment's camera `seconds` into it: someone holding a camcorder walks up to the outside of the wall from the dark behind the shelter, shows the words in blood on it, then goes down on their haunches
## and brings the lens over the lip to the recess where the telephone token lies, and holds there. Keys in the shed's space (`rear_key_times`, `rear_key_positions`, `rear_key_aims`, `rear_key_fovs`) joined by
## smooth curves with slopes taken from the neighbours (no overshoot, a still hand at both ends); the walking is `_gait` in proportion to how fast the body moves, with the hand's slow drifts on top.
func _rear_camera(seconds: float) -> Dictionary:
	var space: Node3D = shot_rear.get_parent() as Node3D if shot_rear != null else null
	var count: int = mini(mini(rear_key_times.size(), rear_key_positions.size()), mini(rear_key_aims.size(), rear_key_fovs.size()))
	if space == null or count < 2:
		var base: Transform3D = shot_rear.aimed_transform() if shot_rear != null else Transform3D.IDENTITY
		return {"transform": base, "fov": shot_rear.fov if shot_rear != null else 45.0}

	var t: float = clampf(seconds, rear_key_times[0], rear_key_times[count - 1])
	var local_at: Vector3 = _keyed_vector(rear_key_times, rear_key_positions, count, t)
	var local_aim: Vector3 = _keyed_vector(rear_key_times, rear_key_aims, count, t)
	var fov_vector: Vector3 = _keyed_vector(rear_key_times, PackedVector3Array(Array(rear_key_fovs).map(func(f: float) -> Vector3: return Vector3(f, 0.0, 0.0))), count, t)
	var before: Vector3 = _keyed_vector(rear_key_times, rear_key_positions, count, maxf(t - 0.1, rear_key_times[0]))
	var after: Vector3 = _keyed_vector(rear_key_times, rear_key_positions, count, minf(t + 0.1, rear_key_times[count - 1]))
	var speed: float = before.distance_to(after) / 0.2
	var moving: float = clampf(speed / 0.22, 0.0, 1.0)
	var gait: Dictionary = _gait(seconds, creep_steps_per_second, creep_bob_metres * 0.8, creep_sway_metres, creep_surge * 0.5, creep_roll_degrees, creep_yaw_degrees, creep_nod_degrees, speed)
	var drift: Vector3 = Vector3(_drift(seconds, 11.0), _drift(seconds, 12.3) * 0.7, _drift(seconds, 13.1)) * hand_drift_metres
	var origin: Vector3 = space.to_global(local_at) + Vector3.UP * (float(gait["up"]) * moving) + drift
	var aim_point: Vector3 = space.to_global(local_aim)
	var heading: Vector3 = (aim_point - origin).normalized()
	var side: Vector3 = Vector3(-heading.z, 0.0, heading.x).normalized()
	origin += side * (float(gait["side"]) * moving)
	var aim: Basis = Basis.looking_at((aim_point - origin).normalized(), Vector3.UP)
	var yaw: float = deg_to_rad(hand_drift_degrees) * (_drift(seconds, 14.7) + 0.25 * _drift(seconds * 2.3, 16.1)) + float(gait["yaw"]) * moving
	var pitch: float = deg_to_rad(hand_drift_degrees) * 0.8 * (_drift(seconds, 15.9) + 0.2 * _drift(seconds * 2.1, 17.3)) + float(gait["nod"]) * moving
	var roll: float = deg_to_rad(hand_roll_degrees) * _drift(seconds, 18.3) + float(gait["roll"]) * moving
	var basis: Basis = aim * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	return {"transform": Transform3D(basis, origin), "fov": fov_vector.x}


## A smooth curve through keyed vectors (cubic Hermite, each slope the difference of the neighbours over their time apart, zero at the two ends), at time `t`.
func _keyed_vector(times: PackedFloat32Array, values: PackedVector3Array, count: int, t: float) -> Vector3:
	var i: int = 0
	while i < count - 2 and t > times[i + 1]:
		i += 1
	var t0: float = times[i]
	var t1: float = times[i + 1]
	var span: float = maxf(t1 - t0, 0.0001)
	var u: float = clampf((t - t0) / span, 0.0, 1.0)
	var m0: Vector3 = Vector3.ZERO if i == 0 else (values[i + 1] - values[i - 1]) / maxf(times[i + 1] - times[i - 1], 0.0001)
	var m1: Vector3 = Vector3.ZERO if i + 2 >= count else (values[i + 2] - values[i]) / maxf(times[i + 2] - times[i], 0.0001)
	var u2: float = u * u
	var u3: float = u2 * u
	return values[i] * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * span * (u3 - 2.0 * u2 + u) + values[i + 1] * (-2.0 * u3 + 3.0 * u2) + m1 * span * (u3 - u2)


## The whole tape's length in seconds: the rear segment and the excerpt.
func tape_length() -> float:
	return rear_prefix_seconds + length_seconds


## The tape's own time (0 is the start of the tape) of an excerpt time, and the other way round. The directed first viewing and the replay of her greeting run on the excerpt's clock; the review's counter runs on the tape's.
func tape_time_of(excerpt_time: float) -> float:
	return excerpt_time + rear_prefix_seconds


func excerpt_time_of(tape_time: float) -> float:
	return tape_time - rear_prefix_seconds


## The words in blood on the rear wall, as a quad on the wall's outside face (facing -Z), in the language of the text: `RECORDING_BLOOD_WORDS` ("ME LIGA" / "CALL ME"). Rebuilt when the language changes.
func _build_rear_message() -> void:
	if rear_message != null and is_instance_valid(rear_message):
		rear_message.queue_free()
	rear_message = ShelterAftermathDressing.build_words(self, "RearMessage", tr("RECORDING_BLOOD_WORDS").to_upper(), rear_message_at, rear_message_size, 180.0)
	rear_message.visible = false
	var copy: StandardMaterial3D = (rear_message.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	copy.albedo_color = Color(minf(stain_darkening * 1.5, 1.0), minf(stain_darkening * 1.5, 1.0), minf(stain_darkening * 1.5, 1.0), 1.0)
	rear_message.material_override = copy
	if not GameSettings.text_language_changed.is_connected(_on_text_language_changed):
		GameSettings.text_language_changed.connect(_on_text_language_changed)


func _on_text_language_changed(_value: Variant) -> void:
	if _prepared:
		var was_visible: bool = rear_message != null and rear_message.visible
		_build_rear_message()
		rear_message.visible = was_visible


## A slow, irregular wave of the time between -1 and 1: three sines whose periods (10, 4.6 and 2.3 seconds) never line up, shifted by `seed_value`. Deterministic: no state, no random numbers.
func _drift(seconds: float, seed_value: float) -> float:
	return 0.55 * sin(seconds * 0.63 + seed_value) + 0.3 * sin(seconds * 1.37 + seed_value * 2.1 + 1.0) + 0.15 * sin(seconds * 2.71 + seed_value * 3.7 + 2.0)


## The ground's height under a carried camera at `u` (0 to 1 along its strip): the table taken at `prepare`, or the markers' own height.
func _ground_at(table: PackedFloat32Array, u: float, from_y: float, to_y: float) -> float:
	if table.size() < 2:
		return lerpf(from_y, to_y, u)

	var scaled: float = u * float(table.size() - 1)
	var index: int = mini(int(floor(scaled)), table.size() - 2)
	return lerpf(table[index], table[index + 1], scaled - float(index))


## The height of the ground along a strip, once (a ray down at each sample, if the world has a floor there; the markers' height otherwise), so that the camera's height over it is steady.
func _sample_ground(start: Marker3D, end: Marker3D) -> PackedFloat32Array:
	var table: PackedFloat32Array = PackedFloat32Array()
	if start == null or end == null:
		return table

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if get_world_3d() != null else null
	var from: Vector3 = start.global_position
	var to: Vector3 = end.global_position
	for i: int in WALK_SAMPLES:
		var u: float = float(i) / float(WALK_SAMPLES - 1)
		var point: Vector3 = from.lerp(to, u)
		var height: float = point.y
		if space != null:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.0, point + Vector3.DOWN * 1.0)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				height = (hit["position"] as Vector3).y
		table.append(height)
	return table


## The tape drains the colour, so a dark red stain on a pale slab survives only as a faint, low-contrast shade: the footage's own copies of the stains' materials are darkened so that their LUMINANCE
## contrast with the slab, the planks and the pillar survives it (the photograph's own dressing and the capture tool are never touched: only these copies, in this scene).
func _darken_stains(holder: Node3D, factor: float = -1.0) -> void:
	var level: float = stain_darkening if factor < 0.0 else factor
	for item: Node in holder.get_children():
		var instance: MeshInstance3D = item as MeshInstance3D
		if instance == null or not (instance.material_override is StandardMaterial3D):
			continue

		var copy: StandardMaterial3D = (instance.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		copy.albedo_color = Color(level, level, level, 1.0)
		instance.material_override = copy


## Leaf litter and stones along a strip, so that the forest floor has something to pass through the picture: the project's own leaf-litter sheets (`ground_leaves_01`) and stones (`rock_001`,
## `rock_002`), placed from a fixed seed on the ground under the strip, plain meshes with no collision. They exist only for their own carried shot.
func _build_litter(node_name: String, start: Marker3D, end: Marker3D, table: PackedFloat32Array, seed_value: int) -> Node3D:
	if start == null or end == null:
		return null

	var holder: Node3D = Node3D.new()
	holder.name = node_name
	holder.visible = false
	add_child(holder)
	var leaves: Mesh = load(LEAF_MESH) as Mesh
	var stones: Array[PackedScene] = []
	for path: String in STONE_MODELS:
		var scene: PackedScene = load(path) as PackedScene
		if scene != null:
			stones.append(scene)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var from: Vector3 = start.global_position
	var to: Vector3 = end.global_position
	var along: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var side: Vector3 = Vector3(-along.z, 0.0, along.x)
	var length: float = Vector2(to.x - from.x, to.z - from.z).length()
	var sheets: int = int(round(length * 3.6))
	if leaves != null:
		for i: int in sheets:
			var u: float = (float(i) + rng.randf_range(0.0, 0.9)) / float(sheets)
			var at: Vector3 = from.lerp(to, u) + side * rng.randf_range(-1.3, 1.3)
			var sheet: MeshInstance3D = MeshInstance3D.new()
			sheet.name = "Leaves%d" % i
			sheet.mesh = leaves
			sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var size: float = rng.randf_range(0.4, 0.7)
			sheet.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(at.x, _ground_at(table, u, from.y, to.y) + 0.012, at.z))
			holder.add_child(sheet)
	if not stones.is_empty():
		for i: int in int(round(length * 4.9)):
			var u2: float = rng.randf()
			var at2: Vector3 = from.lerp(to, u2) + side * rng.randf_range(-1.2, 1.2)
			var stone: Node3D = stones[i % stones.size()].instantiate() as Node3D
			stone.name = "Stone%d" % i
			holder.add_child(stone)
			_tint(stone, Color(0.4, 0.38, 0.34))
			var bounds: AABB = _bounds_of(stone)
			var want: float = rng.randf_range(0.09, 0.28)
			var scale_value: float = want / maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
			stone.transform = Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled(Vector3.ONE * scale_value), Vector3(at2.x, _ground_at(table, u2, from.y, to.y) - bounds.position.y * scale_value * 0.6, at2.z))
	return holder


## Every mesh of a node drawn with its own material at a darker, duller colour (a copy: the model's material is never touched).
func _tint(node: Node3D, colour: Color) -> void:
	for item: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = item as MeshInstance3D
		var source: Material = instance.get_active_material(0)
		var copy: StandardMaterial3D = (source.duplicate() as StandardMaterial3D) if source is StandardMaterial3D else StandardMaterial3D.new()
		copy.albedo_color = colour
		instance.material_override = copy


## The box of a node's meshes in its own frame.
func _bounds_of(node: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for item: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = item as MeshInstance3D
		if instance.mesh == null:
			continue

		var box: AABB = node.transform * (node.global_transform.affine_inverse() * instance.global_transform * instance.mesh.get_aabb()) if node.is_inside_tree() else instance.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


# ============================================================
# EMILY
# ============================================================

## One channel through a list of [time, value] keys (times strictly increasing).
func _keys(channel: StringName, keys: Array) -> void:
	for pair: Array in keys:
		marina.key(channel, float(pair[0]), pair[1] as Vector3)


## Emily sits on the bench: her pelvis on the seat, feet on the floor, knees bent, the back straight and relaxed, the head a little down, both hands resting on her thighs. She waits, then turns
## her head toward her right (the head first, the neck, the shoulders a little behind), lifts her right hand in a short greeting that ends in a small wave, lowers it, and keeps her head turned,
## nodding once or twice as someone speaks. Her other hand and her legs never move. Her left is the model's +X, her right its -X (`side` is +1 for the left and -1 for the right).
func _key_marina() -> void:
	var m: ArchiveActor = marina
	var s: float = marina_scale
	var ankle: float = ArchiveActor.ANKLE_HEIGHT * s
	var end: float = 3600.0
	var thigh_top: float = _seat_height + 0.165
	var side: float = -1.0 if greet_on_right else 1.0
	var hand_channel: StringName = &"hand_l" if side > 0.0 else &"hand_r"
	var rest_channel: StringName = &"hand_r" if side > 0.0 else &"hand_l"
	var shoulder_channel: StringName = &"LeftShoulder" if side > 0.0 else &"RightShoulder"
	var rest_shoulder: StringName = &"RightShoulder" if side > 0.0 else &"LeftShoulder"
	m.hold(&"hips_at", 0.0, end, Vector3(0.0, _seat_height + 0.09 * s, 0.06 * s))
	m.hold(&"foot_r", 0.0, end, Vector3(-0.14, ankle, 0.34))
	m.hold(&"foot_l", 0.0, end, Vector3(0.18, ankle, 0.44))
	m.hold(&"yaw_r", 0.0, end, Vector3(-7.0, 0.0, 0.0))
	m.hold(&"yaw_l", 0.0, end, Vector3(13.0, 0.0, 0.0))
	m.hold(&"Hips", 0.0, end, Vector3(-2.0, 0.0, 0.0))
	m.hold(&"Spine", 0.0, end, Vector3(3.0, 0.0, 0.0))
	m.hold(&"Spine1", 0.0, end, Vector3(3.0, 0.0, 0.0))
	# The hand that does not greet stays on its thigh, its shoulder as it was.
	m.hold(rest_shoulder, 0.0, end, Vector3(0.0, 0.0, -side * 2.5))
	m.hold(rest_channel, 0.0, end, Vector3(-side * 0.16, thigh_top, 0.14))

	var t0: float = turn_start_seconds
	var t1: float = turn_end_seconds
	var turn: float = head_turn_degrees * side
	var torso: float = torso_turn_degrees * side
	var tail: float = maxf(length_seconds, 40.0)
	# The head leads, the neck follows a moment behind, the shoulders a little behind that and only a little.
	var head_turned: Vector3 = Vector3(5.0, turn * 0.6, 0.0)
	var head_keys: Array = [[0.0, Vector3(5.0, 0.0, 0.0)], [t0, Vector3(5.0, 0.0, 0.0)], [t1, head_turned]]
	# The listening: after the greeting a couple of small nods (the head dips a few degrees and comes back) with the turn easing a degree, as it does when somebody is listening.
	var last: float = t1
	for nod: float in nod_seconds:
		if nod - 0.6 <= last + 0.1:
			continue
		head_keys.append([nod - 0.6, head_turned])
		head_keys.append([nod, Vector3(11.0, turn * 0.6 - side * 2.0, 0.0)])
		head_keys.append([nod + 0.6, head_turned])
		last = nod + 0.6
	head_keys.append([maxf(tail, last + 1.0), head_turned])
	_keys(&"Head", head_keys)
	_keys(&"Neck", [[0.0, Vector3(7.0, 0.0, 0.0)], [t0 + 0.24, Vector3(7.0, 0.0, 0.0)], [t1, Vector3(7.0, turn * 0.4, 0.0)], [tail, Vector3(7.0, turn * 0.4, 0.0)]])
	_keys(&"Spine2", [[0.0, Vector3(2.0, 0.0, 0.0)], [t0 + 0.6, Vector3(2.0, 0.0, 0.0)], [t1 + 0.8, Vector3(2.0, torso, 0.0)], [tail, Vector3(2.0, torso, 0.0)]])
	_keys(shoulder_channel, [[0.0, Vector3(0.0, 0.0, side * 2.0)], [hand_up_start_seconds, Vector3(0.0, 0.0, side * 2.0)], [hand_up_end_seconds, Vector3(0.0, 0.0, side * 6.0)], [hand_down_end_seconds, Vector3(0.0, 0.0, side * 2.0)], [tail, Vector3(0.0, 0.0, side * 2.0)]])

	# The greeting hand: on her thigh, up toward the person (in front of her and to her side, the forearm raised to about the height of her head), a small wave from side to side, and back down to her thigh.
	var rest: Vector3 = Vector3(side * 0.16, thigh_top, 0.14)
	var up: Vector3 = Vector3(side * 0.31, 1.13, 0.25)
	var hand: Array = [[0.0, rest], [hand_up_start_seconds, rest], [hand_up_end_seconds, up]]
	var swing: float = 0.06
	var steps: int = 4
	for i: int in steps:
		var phase: float = float(i + 1) / float(steps)
		var sign_value: float = 1.0 if i % 2 == 0 else -1.0
		hand.append([hand_up_end_seconds + wave_seconds * phase, up + Vector3(sign_value * swing, 0.02 if sign_value > 0.0 else 0.0, 0.0)])
	hand.append([hand_down_end_seconds, rest])
	hand.append([tail, rest])
	_keys(hand_channel, hand)


## Her pelvis is put on the seat (the lowest vertex of the pelvis exactly on its top) and she is placed on the bench.
func _place_marina() -> void:
	var seat: Vector3 = marina_seat.global_position
	var facing: Vector3 = marina_seat.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	marina.global_transform = Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), Vector3(seat.x, _floor_y, seat.z))
	marina.hips_shift = 0.0
	marina.sample(0.0)
	# Her pelvis and her thighs, over the seat's footprint, rest ON the planks (the thighs are rounder than the pelvis and went a centimetre or two into them when only the pelvis was settled); past the
	# front edge the thighs go down to the knees, which is why only the vertices over the seat count.
	var bench: Node3D = get_node_or_null(^"../Bench") as Node3D
	var seat_centre: Vector3 = bench.global_position if bench != null else seat
	var footprint: Rect2 = Rect2(Vector2(seat_centre.x - 0.84, seat_centre.z - 0.2), Vector2(1.68, 0.43))
	marina.settle_hips_on_floor(0.0, _seat_height + 0.003, ["Hips", "*Leg"] as Array[String], footprint)
