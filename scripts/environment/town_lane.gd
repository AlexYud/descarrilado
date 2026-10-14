class_name TownLane
extends RefCounted

## One lane of the town blockout: a smooth centre line (a point every metre, with the
## ground height of the lane at each point), its widths, and the small queries the
## builder needs (tangent, side offsets, distance from a point). Coordinates: x east,
## z south (north is -z). Seen from above with north up, the RIGHT of a lane that runs
## east is south: `right_normal` is (-tangent.z, tangent.x).

enum Kind { COBBLE, STAIRS, GROUND, TRACK }

## Distance between two samples of the centre line (m).
const STEP: float = 1.0
## How many times the bends of a smooth lane are averaged.
const SMOOTH_PASSES: int = 10

var id: String = ""
var zone: String = "UpperTown"
var kind: Kind = Kind.COBBLE
var index: int = 0
## Half of the cobbled road (or of the stair, the yard, the path).
var half_width: float = 1.6
## Sidewalk widths on the left and on the right of the direction of travel.
var walk_left: float = 0.9
var walk_right: float = 0.9
## A wall across the start / the end of the lane (a dead end).
var capped_start: bool = false
var capped_end: bool = false
## 0 mixed garden walls, 1 stone, 2 thicket, 3 plank fence.
var wall_style: int = 0
## Houses are placed along the lane's sides (not for stairs, yards, tracks, paths).
var houses: bool = true
var carve_blend: float = 3.0
## Tiny height bias so crossing lanes do not fight for the same pixels.
var bias: float = 0.0

var points: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector2Array = PackedVector2Array()
var distances: PackedFloat32Array = PackedFloat32Array()


## Builds a lane from control points (x, ground height y, z): a smooth Catmull-Rom curve
## through them, resampled every `STEP` metres (a stair is a straight line).
static func create(lane_id: String, lane_zone: String, lane_kind: Kind, controls: Array[Vector3], lane_half_width: float, lane_walk_left: float, lane_walk_right: float) -> TownLane:
	var lane: TownLane = TownLane.new()
	lane.id = lane_id
	lane.zone = lane_zone
	lane.kind = lane_kind
	lane.half_width = lane_half_width
	lane.walk_left = lane_walk_left
	lane.walk_right = lane_walk_right
	lane._sample(controls, lane_kind != Kind.STAIRS)
	return lane


func _sample(controls: Array[Vector3], smooth: bool) -> void:
	var dense: Array[Vector3] = []
	if smooth and controls.size() > 2:
		for i: int in controls.size() - 1:
			var before: Vector3 = controls[maxi(i - 1, 0)]
			var after: Vector3 = controls[mini(i + 2, controls.size() - 1)]
			for k: int in 12:
				dense.append(controls[i].cubic_interpolate(controls[i + 1], before, after, float(k) / 12.0))

		dense.append(controls[controls.size() - 1])
	else:
		dense.assign(controls)

	_resample(dense)
	if smooth and controls.size() > 2:
		# Round off the bends so none is tighter than the lane is wide (the sidewalk on the
		# inside of a sharp bend would fold over itself): a few passes of averaging, the
		# ends staying put, then an even resample again.
		for pass_index: int in SMOOTH_PASSES:
			var average: Array[Vector3] = []
			for n: int in points.size():
				if n == 0 or n == points.size() - 1:
					average.append(points[n])
				else:
					average.append(points[n - 1] * 0.25 + points[n] * 0.5 + points[n + 1] * 0.25)

			for n: int in points.size():
				points[n] = average[n]

		var smoothed: Array[Vector3] = []
		smoothed.assign(points)
		_resample(smoothed)

	tangents.resize(points.size())
	for n: int in points.size():
		var before_point: Vector3 = points[maxi(n - 1, 0)]
		var after_point: Vector3 = points[mini(n + 1, points.size() - 1)]
		var direction: Vector2 = Vector2(after_point.x - before_point.x, after_point.z - before_point.z)
		tangents[n] = direction.normalized() if direction.length() > 0.0001 else Vector2(1.0, 0.0)


## Even samples (every `STEP` metres along the plan) of the polyline `dense`.
func _resample(dense: Array[Vector3]) -> void:
	var total: float = 0.0
	var cumulative: Array[float] = [0.0]
	for i: int in range(1, dense.size()):
		total += Vector2(dense[i].x - dense[i - 1].x, dense[i].z - dense[i - 1].z).length()
		cumulative.append(total)

	var count: int = maxi(int(round(total / STEP)), 1)
	var cursor: int = 0
	points.resize(count + 1)
	distances.resize(count + 1)
	for n: int in count + 1:
		var wanted: float = total * float(n) / float(count)
		while cursor < dense.size() - 2 and cumulative[cursor + 1] < wanted:
			cursor += 1

		var span: float = cumulative[cursor + 1] - cumulative[cursor]
		var t: float = 0.0 if span <= 0.0001 else clampf((wanted - cumulative[cursor]) / span, 0.0, 1.0)
		points[n] = dense[cursor].lerp(dense[cursor + 1], t)
		distances[n] = wanted


func length() -> float:
	return distances[distances.size() - 1]


## The right-hand normal at sample `i` (see the class comment).
func right_normal(i: int) -> Vector2:
	return Vector2(-tangents[i].y, tangents[i].x)


func xz(i: int) -> Vector2:
	return Vector2(points[i].x, points[i].z)


## Half of the lane's whole width (road + the wider sidewalk).
func corridor_half() -> float:
	return half_width + maxf(walk_left, walk_right)


## Distance from the centre line to the outer edge of the sidewalk on `side` (+1 right,
## -1 left).
func edge_offset(side: int) -> float:
	return half_width + (walk_right if side > 0 else walk_left)


func sample_index(s: float) -> int:
	return clampi(int(round(s / STEP)), 0, points.size() - 1)


func point_at(s: float) -> Vector3:
	var clamped: float = clampf(s, 0.0, length())
	var i: int = mini(int(floor(clamped / STEP)), points.size() - 2)
	var span: float = distances[i + 1] - distances[i]
	var t: float = 0.0 if span <= 0.0001 else (clamped - distances[i]) / span
	return points[i].lerp(points[i + 1], t)


## The distance along the lane of the sample closest to the plan point `p`.
func closest_s(p: Vector2) -> float:
	var best: float = INF
	var best_s: float = 0.0
	for i: int in points.size():
		var d: float = xz(i).distance_squared_to(p)
		if d < best:
			best = d
			best_s = distances[i]

	return best_s


## Distance from the plan point `p` to the segment j..j+1, with the height and the
## distance along the lane at the closest point, and which side `p` is on:
## (distance, height, s, side).
func segment_hit(j: int, p: Vector2) -> Vector4:
	var a: Vector2 = xz(j)
	var b: Vector2 = xz(j + 1)
	var ab: Vector2 = b - a
	var span: float = ab.length_squared()
	var t: float = 0.0 if span <= 0.000001 else clampf((p - a).dot(ab) / span, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	var side: float = signf((p - closest).dot(right_normal(j)))
	return Vector4(
		p.distance_to(closest),
		lerpf(points[j].y, points[j + 1].y, t),
		lerpf(distances[j], distances[j + 1], t),
		side
	)
