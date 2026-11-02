extends Node3D
class_name ShelterFootage

## The performance in the waiting shed's archival recording, and nothing else of it: ONE short excerpt of a hidden, fixed camera. Marina sits on the
## shelter's bench, waiting. Someone walks in from the right, on the near side of the bench, stops by her, appears to speak with her for a while,
## turns and walks out the way they came; she follows them with her head, then settles back into waiting. The visitor's head is never in the picture
## (the camera is set so that the top of the 4:3 frame is under their chin, see `WaitingShedSequence.shot_recording`), nothing is carried or touched,
## and nothing says what was said, whether they knew each other, or what happened next.
##
## Everything is a pure function of one clock, the footage time (`seek`): both actors' poses (see `ArchiveActor`), the visitor's place on the
## path, Marina's gaze. A pause, a cancel or a seek to any time gives the same picture; nothing is a timer, a tween or a callback. The visitor's walk
## is authored, not simulated: their root follows a short path (entry, stop, exit) at `walk_speed` with a short ramp at each end, and `ArchiveGait`
## plans where each foot lands so that a foot on the ground never moves (no skating) and the pelvis is only as high as the legs reach.
##
## The cast is built in code from the shared rigged model at the first `prepare` (off camera) and is never an obstacle, an interaction or a light;
## its placement comes from four markers in the scene: `marina_seat` (the point on the seat under her pelvis, +Z the way she faces), and the visitor's
## `path_entry`, `path_stop` and `path_exit`. Every moment below is an export (seconds into the footage) so it can be re-timed in play.

const DT: float = ArchiveGait.DT
## Frames between the keys written for the long channels (a key every 1/30 s).
const KEY_FRAMES: int = 2

@export_category("Placement")
## The point on the bench's seat under Marina's pelvis (+Z of the marker is the way she faces).
@export var marina_seat: Marker3D
## Where the visitor comes from (out of the picture), where they stop to speak with her, and where they go (empty: back the way they came).
@export var path_entry: Marker3D
@export var path_stop: Marker3D
@export var path_exit: Marker3D
@export var marina_scale: float = 0.9
@export var visitor_scale: float = 0.97

@export_category("Footage")
@export var length_seconds: float = 22.0

@export_category("Marina")
## Her head turns to the visitor (they are in the picture from about 3.9 s), she nods once as they begin, makes one small hand movement and nods once more.
@export var marina_notice_seconds: float = 4.3
@export var marina_notice_blend_seconds: float = 0.9
@export var marina_nod_times: PackedFloat32Array = PackedFloat32Array([6.6, 11.6])
@export var marina_gesture_start: float = 9.0
@export var marina_gesture_seconds: float = 1.5
## She follows them with her head until this time, then lets go of it over `marina_settle_seconds` and waits again.
@export var marina_follow_until: float = 15.6
@export var marina_settle_seconds: float = 1.4

@export_category("Visitor path (metres per second, seconds)")
@export var visitor_start_seconds: float = 1.2
@export var walk_speed: float = 1.2
## The ramps are short: most of the walk is at steady speed.
@export var accel_seconds: float = 0.4
@export var decel_seconds: float = 0.5
## How long they stand and speak, from the moment they have stopped, and how long the turn back takes (the walk out begins part-way through it).
@export var exchange_seconds: float = 8.0
@export var turn_seconds: float = 0.9
## How long before they stop the body has finished turning to Marina.
@export var turn_in_seconds: float = 0.7

@export_category("Visitor exchange (seconds after they stop)")
## One restrained gesture with the right hand, a small one with the left, and the nods of the head (not in the picture).
@export var gesture_a_offset: float = 1.6
@export var gesture_a_seconds: float = 1.6
@export var gesture_b_offset: float = 5.0
@export var gesture_b_seconds: float = 1.2

var marina: ArchiveActor = null
var visitor: ArchiveActor = null
var gait: ArchiveGait = null
## The footage time the cast was last posed at (`seek`).
var current_time: float = 0.0
## When the visitor has stopped, when they begin to turn away, and when they begin to walk out (footage seconds; set by `prepare`).
var arrive_time: float = 0.0
var depart_time: float = 0.0
var walk_out_time: float = 0.0

var _prepared: bool = false
var _floor_y: float = 0.0
var _root: PackedVector2Array = PackedVector2Array()
var _heading: PackedFloat32Array = PackedFloat32Array()
var _seat_height: float = 0.44


func _ready() -> void:
	# Nothing of the cast is ever seen until a sequence shows it.
	visible = false


func is_prepared() -> bool:
	return _prepared


## Builds and poses the cast (once). Call it while nothing of it is on screen. The cast stays hidden until `show_cast`.
func prepare() -> void:
	if _prepared or marina_seat == null or path_entry == null or path_stop == null or not is_inside_tree():
		return

	visible = false
	marina = _make_actor("Marina", marina_scale, 0.0, {
		&"top": Color(0.66, 0.7, 0.76), &"bottom": Color(0.26, 0.29, 0.36), &"skin": Color(0.88, 0.74, 0.64),
		&"hair": Color(0.2, 0.14, 0.1), &"shoes": Color(0.14, 0.13, 0.13),
	})
	visitor = _make_actor("Visitor", visitor_scale, 2.3, {
		&"top": Color(0.3, 0.34, 0.4), &"bottom": Color(0.68, 0.64, 0.56), &"skin": Color(0.8, 0.66, 0.56),
		&"hair": Color(0.1, 0.09, 0.09), &"shoes": Color(0.1, 0.1, 0.1),
	})
	visitor.life = 0.5
	_floor_y = path_stop.global_position.y
	_seat_height = marina_seat.global_position.y - _floor_y
	_plan_visitor()
	_key_visitor()
	_key_marina()
	_place_marina()
	_prepared = true
	seek(0.0)


func _make_actor(actor_name: String, scale_value: float, phase: float, colours: Dictionary) -> ArchiveActor:
	var actor: ArchiveActor = ArchiveActor.new()
	actor.name = actor_name
	actor.actor_scale = scale_value
	actor.life_phase = phase
	actor.palette = colours
	add_child(actor)
	actor.build()
	return actor


## Shown (under a cut) or hidden. Hidden, nothing of the cast is drawn or casts a shadow.
func show_cast(shown: bool) -> void:
	visible = shown and _prepared


## The footage at `time` (seconds): both actors posed. A pure function of the time.
func seek(time: float) -> void:
	if not _prepared:
		return

	current_time = time
	visitor.global_transform = visitor_transform_at(time)
	marina.sample(time)
	visitor.sample(time)


## Where the visitor's root is at `time` (the floor under them, facing where they face).
func visitor_transform_at(time: float) -> Transform3D:
	var position_xz: Vector2 = _root_at(time)
	return Transform3D(Basis(Vector3.UP, _heading_at(time)), Vector3(position_xz.x, _floor_y, position_xz.y))


func _frame_at(time: float) -> float:
	return clampf(time / DT, 0.0, float(maxi(_root.size() - 1, 0)))


func _root_at(time: float) -> Vector2:
	var frame: float = _frame_at(time)
	var low: int = int(floor(frame))
	var high: int = mini(low + 1, _root.size() - 1)
	return _root[low].lerp(_root[high], frame - low)


func _heading_at(time: float) -> float:
	var frame: float = _frame_at(time)
	var low: int = int(floor(frame))
	var high: int = mini(low + 1, _root.size() - 1)
	return _heading[low] + angle_difference(_heading[low], _heading[high]) * (frame - low)


# ============================================================
# THE VISITOR'S PATH AND FEET
# ============================================================

func _xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## The root's place and heading, frame by frame, from the three marks and the timing exports; then the feet and the pelvis from `ArchiveGait`.
func _plan_visitor() -> void:
	var entry: Vector2 = _xz(path_entry.global_position)
	var stop: Vector2 = _xz(path_stop.global_position)
	var leave: Vector2 = _xz(path_exit.global_position) if path_exit != null else entry
	var face: Vector2 = _xz(marina_seat.global_position)
	var heading_in: float = atan2(stop.x - entry.x, stop.y - entry.y)
	var heading_face: float = atan2(face.x - stop.x, face.y - stop.y)
	var heading_out: float = atan2(leave.x - stop.x, leave.y - stop.y)
	var length_in: float = entry.distance_to(stop)
	var length_out: float = stop.distance_to(leave)
	var time_in: float = _travel_time(length_in)
	arrive_time = visitor_start_seconds + time_in
	depart_time = arrive_time + exchange_seconds
	walk_out_time = depart_time + turn_seconds * 0.55

	var count: int = int(round(length_seconds / DT)) + 1
	_root.resize(count)
	_heading.resize(count)
	for i: int in count:
		var time: float = float(i) * DT
		var position_xz: Vector2 = entry
		var heading: float = heading_in
		if time < visitor_start_seconds:
			pass
		elif time < arrive_time:
			var walked: float = time - visitor_start_seconds
			position_xz = entry.lerp(stop, _travel(walked, length_in) / maxf(length_in, 0.001))
			var turning: float = clampf((walked - (time_in - turn_in_seconds)) / maxf(turn_in_seconds, 0.01), 0.0, 1.0)
			heading = heading_in + angle_difference(heading_in, heading_face) * _smooth(turning)
		else:
			position_xz = stop
			heading = heading_face
			if time >= depart_time:
				var turned: float = clampf((time - depart_time) / maxf(turn_seconds, 0.01), 0.0, 1.0)
				heading = heading_face + angle_difference(heading_face, heading_out) * _smooth(turned)
			if time >= walk_out_time:
				position_xz = stop + (leave - stop) * (_travel(time - walk_out_time, length_out) / maxf(length_out, 0.001))
		_root[i] = position_xz
		_heading[i] = heading

	gait = ArchiveGait.new()
	gait.figure_scale = visitor_scale
	gait.standing_hips = (-0.02 - visitor.feet_low)
	gait.root = _root
	gait.heading = _heading
	gait.plan()


func _smooth(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


## How long a walk of `length` metres takes at `walk_speed`, with the short ramps.
func _travel_time(length: float) -> float:
	return length / walk_speed + (accel_seconds + decel_seconds) * 0.5


## How far along a walk of `length` metres the root is `seconds` after it began: a short acceleration, steady speed, a short deceleration.
func _travel(seconds: float, length: float) -> float:
	var total: float = _travel_time(length)
	if seconds <= 0.0:
		return 0.0
	if seconds >= total:
		return length
	var speed: float = walk_speed
	if seconds < accel_seconds:
		return speed * seconds * seconds / (2.0 * accel_seconds)
	var after_ramp: float = speed * accel_seconds * 0.5
	var cruise_end: float = total - decel_seconds
	if seconds < cruise_end:
		return after_ramp + speed * (seconds - accel_seconds)
	var at_cruise_end: float = after_ramp + speed * (cruise_end - accel_seconds)
	var d: float = seconds - cruise_end
	return at_cruise_end + speed * d - speed * d * d / (2.0 * decel_seconds)


## A bell of unit height from `start` over `seconds` (zero outside it).
func _pulse(time: float, start: float, seconds: float) -> float:
	var u: float = (time - start) / maxf(seconds, 0.01)
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return sin(PI * u) * sin(PI * u)


## Writes the visitor's channels: a key every 1/30 s from the planned feet and hips, the arm swing that goes with the feet, the gestures and the
## small lean of the body while they speak.
func _key_visitor() -> void:
	var v: ArchiveActor = visitor
	var s: float = visitor_scale
	var count: int = _root.size()
	var frames: Array[int] = []
	for i: int in range(0, count, KEY_FRAMES):
		frames.append(i)
	if frames[frames.size() - 1] != count - 1:
		frames.append(count - 1)

	var times: PackedFloat32Array = PackedFloat32Array()
	var channels: Dictionary = {}
	for channel: StringName in [&"hips_at", &"foot_l", &"foot_r", &"yaw_l", &"yaw_r", &"hand_l", &"hand_r", &"Hips", &"Spine", &"Spine1", &"Spine2", &"Neck", &"Head"]:
		channels[channel] = []
	var ankle: float = ArchiveActor.ANKLE_HEIGHT * s
	var hang_x: float = 0.235 * s
	var hang_y: float = 0.93 * s
	for i: int in frames:
		var time: float = float(i) * DT
		times.append(time)
		var heading: float = _heading[i]
		var inverse: Transform3D = Transform3D(Basis(Vector3.UP, heading), Vector3(_root[i].x, _floor_y, _root[i].y)).affine_inverse()
		var forward: Vector2 = Vector2(sin(heading), cos(heading))
		var ahead: Array[float] = []
		for f: int in 2:
			var up: float = ankle + gait.foot_up[f][i]
			var world: Vector3 = Vector3(gait.foot_xz[f][i].x, _floor_y + up, gait.foot_xz[f][i].y)
			(channels[&"foot_l" if f == 0 else &"foot_r"] as Array).append(inverse * world)
			(channels[&"yaw_l" if f == 0 else &"yaw_r"] as Array).append(Vector3(rad_to_deg(angle_difference(heading, gait.foot_heading[f][i])), 0.0, 0.0))
			ahead.append((gait.foot_xz[f][i] - _root[i]).dot(forward))
		# The legs' phase: positive while the left foot is the one in front.
		var phase: float = clampf((ahead[0] - ahead[1]) / (0.6 * s), -1.0, 1.0)
		var moving: float = clampf(gait_speed(time) / walk_speed, 0.0, 1.0)
		(channels[&"hips_at"] as Array).append(Vector3(0.0, gait.hips_height[i], 0.07 * s))

		# Arms swing against the legs; they rest at the sides, lift in the two gestures while the visitor speaks.
		var swing: float = phase * 0.15 * s
		var g_a: float = _pulse(time, arrive_time + gesture_a_offset, gesture_a_seconds)
		var g_b: float = _pulse(time, arrive_time + gesture_b_offset, gesture_b_seconds)
		var left: Vector3 = Vector3(hang_x, hang_y + 0.015 * absf(swing) / s, 0.03 * s - swing)
		var right: Vector3 = Vector3(-hang_x, hang_y + 0.015 * absf(swing) / s, 0.03 * s + swing)
		right = right.lerp(Vector3(-0.2 * s, 1.08 * s, 0.3 * s), g_a)
		left = left.lerp(Vector3(0.21 * s, 1.0 * s, 0.22 * s), g_b)
		(channels[&"hand_l"] as Array).append(left)
		(channels[&"hand_r"] as Array).append(right)

		# The trunk: the pelvis and the shoulders turn against each other a little with the stride, and the body leans a touch toward the one
		# they are speaking to (the head dips with it; it is above the picture's top edge).
		var speaking: float = _smooth(clampf((time - arrive_time) / 0.8, 0.0, 1.0)) * (1.0 - _smooth(clampf((time - depart_time) / 0.8, 0.0, 1.0)))
		var nod: float = _pulse(time, arrive_time + 0.6, 0.7) + _pulse(time, arrive_time + 4.1, 0.7)
		(channels[&"Hips"] as Array).append(Vector3(1.0, -8.0 * phase * moving, 0.0))
		(channels[&"Spine"] as Array).append(Vector3(2.0 + 3.0 * moving + 2.0 * speaking, 3.0 * phase * moving, 0.0))
		(channels[&"Spine1"] as Array).append(Vector3(1.0 + 1.0 * speaking, 3.0 * phase * moving, 0.0))
		(channels[&"Spine2"] as Array).append(Vector3(1.0 + 1.5 * speaking, 2.5 * phase * moving, 0.0))
		(channels[&"Neck"] as Array).append(Vector3(2.0 + 5.0 * speaking + 5.0 * nod, 0.0, 0.0))
		(channels[&"Head"] as Array).append(Vector3(3.0 + 6.0 * speaking + 6.0 * nod, 0.0, 0.0))
	for channel: StringName in channels:
		v.set_channel(channel, times, channels[channel] as Array)


## The visitor's speed (metres per second) at a time.
func gait_speed(time: float) -> float:
	return gait.speed_at(int(round(clampf(time / DT, 0.0, float(_root.size() - 1)))))


# ============================================================
# MARINA
# ============================================================

## Marina sits on the bench: pelvis on the seat, thighs on it, feet on the floor, hands on her thighs, shoulders natural, the legs not mirrored.
## Her head waits, looking a little down and toward the side the visitor will come from; when they appear it turns to them and follows them;
## she nods, makes one small hand movement, and settles back into waiting when they have gone.
func _key_marina() -> void:
	var m: ArchiveActor = marina
	var s: float = marina_scale
	var ankle: float = ArchiveActor.ANKLE_HEIGHT * s
	var end: float = length_seconds
	var thigh_top: float = _seat_height + 0.165
	m.hold(&"hips_at", 0.0, end, Vector3(0.0, _seat_height + 0.09 * s, 0.06 * s))
	m.hold(&"foot_r", 0.0, end, Vector3(-0.14, ankle, 0.34))
	m.hold(&"foot_l", 0.0, end, Vector3(0.18, ankle, 0.44))
	m.hold(&"yaw_r", 0.0, end, Vector3(-7.0, 0.0, 0.0))
	m.hold(&"yaw_l", 0.0, end, Vector3(13.0, 0.0, 0.0))
	m.hold(&"Hips", 0.0, end, Vector3(-3.0, 0.0, 0.0))
	m.hold(&"Spine", 0.0, end, Vector3(3.0, 1.0, 0.0))
	m.hold(&"Spine1", 0.0, end, Vector3(2.0, 0.0, 0.0))
	m.hold(&"Spine2", 0.0, end, Vector3(2.0, -1.0, 0.0))
	m.hold(&"LeftShoulder", 0.0, end, Vector3(0.0, 0.0, 2.0))
	m.hold(&"RightShoulder", 0.0, end, Vector3(0.0, 0.0, -2.5))
	# The left hand rests on her thigh; the right one too, and rises once.
	m.hold(&"hand_l", 0.0, end, Vector3(0.16, thigh_top, 0.15))
	var rest: Vector3 = Vector3(-0.16, thigh_top, 0.14)
	var raised: Vector3 = Vector3(-0.12, thigh_top + 0.2, 0.34)
	var hand_times: PackedFloat32Array = PackedFloat32Array()
	var hand_values: Array = []
	for i: int in range(0, int(round(end / DT)) + 1, KEY_FRAMES):
		var time: float = float(i) * DT
		hand_times.append(time)
		hand_values.append(rest.lerp(raised, _pulse(time, marina_gesture_start, marina_gesture_seconds)))
	m.set_channel(&"hand_r", hand_times, hand_values)


## After the pose is keyed: her pelvis is put on the seat (the lowest vertex of the pelvis exactly on its top), the gaze is keyed (it needs her
## head's place) and she is placed on the bench.
func _place_marina() -> void:
	var seat: Vector3 = marina_seat.global_position
	var facing: Vector3 = marina_seat.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	marina.global_transform = Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), Vector3(seat.x, _floor_y, seat.z))
	marina.hips_shift = 0.0
	marina.sample(0.0)
	marina.settle_hips_on_floor(0.0, _seat_height + 0.002, ["Hips"] as Array[String])
	_key_marina_gaze()


## Marina's head: waiting (looking a little down and toward the side the visitor comes from), then on the visitor from when she notices them
## until they have left, as a dense channel from where the visitor is; the nods add to it.
func _key_marina_gaze() -> void:
	var m: ArchiveActor = marina
	var count: int = int(round(length_seconds / DT)) + 1
	var times: PackedFloat32Array = PackedFloat32Array()
	var necks: Array = []
	var heads: Array = []
	var head_point: Vector3 = m.bone_point("Head")
	for i: int in range(0, count, KEY_FRAMES):
		var time: float = float(i) * DT
		times.append(time)
		var weight: float = _smooth(clampf((time - marina_notice_seconds) / maxf(marina_notice_blend_seconds, 0.01), 0.0, 1.0))
		weight *= 1.0 - _smooth(clampf((time - marina_follow_until) / maxf(marina_settle_seconds, 0.01), 0.0, 1.0))
		# Where she would look: at the visitor's face (their chest height if they are far), from where her head is.
		var target_world: Vector3 = Vector3(_root[i].x, _floor_y + 1.45 * visitor_scale, _root[i].y)
		var d: Vector3 = m.to_local(target_world) - head_point
		var track_yaw: float = rad_to_deg(atan2(d.x, d.z))
		var track_pitch: float = -rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
		var yaw: float = lerpf(34.0, clampf(track_yaw, -70.0, 70.0), weight)
		var pitch: float = lerpf(12.0, clampf(track_pitch, -30.0, 30.0), weight)
		var nod: float = 0.0
		for nod_time: float in marina_nod_times:
			nod += _pulse(time, nod_time, 0.7)
		pitch += 9.0 * nod
		necks.append(Vector3(pitch * 0.4, yaw * 0.4, 0.0))
		heads.append(Vector3(pitch * 0.6, yaw * 0.6, 0.0))
	m.set_channel(&"Neck", times, necks)
	m.set_channel(&"Head", times, heads)
