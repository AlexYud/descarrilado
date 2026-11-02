class_name ArchiveGait
extends RefCounted

## Where a walking figure's two feet go, planned from the path its ROOT takes, for the archival recording in the waiting shed (`ShelterFootage`).
## Not an NPC system: no navigation, no avoidance, no state machine at run time. The whole plan is made once, in `plan()`, from a table of the
## root's position and heading at 60 frames a second, and every output is a table read back by time: the footage stays a pure function of its clock.
##
## The rule is the one a real walk has: a foot that is on the ground STAYS where it was put (so it can never skate), and steps only when it has been
## left behind (by more than `stride_trigger`), or the body has turned away from it, or the figure has stopped and the foot is not under it. A step
## is a short swing to where that foot will be wanted when it lands (the root's own future position, a little ahead while the root is moving), with
## a small lift and a smooth foot speed. Only one foot swings at a time, so a figure that stops puts the trailing foot beside the other, and a
## figure that turns on the spot turns by two small steps. The pelvis is then lowered, frame by frame, exactly as far as the two legs' lengths
## need to reach the planted feet: that is the walk's bob, and no foot is ever asked for more than the leg has.
##
## Everything is in the model's metres at the figure's own scale (`figure_scale`): inputs and outputs are in the world's xz plane (x, z), a heading
## in radians where 0 faces +Z and a positive turn goes toward +X (a figure's left is then (cos, -sin)).

const DT: float = 1.0 / 60.0

## How far behind where it is wanted a foot may be left before it steps (metres at scale 1), and how far ahead of the wanted place it lands while
## the root is moving at `reference_speed`.
var stride_trigger: float = 0.30
var landing_lead: float = 0.27
var reference_speed: float = 1.2
## How long a step takes in a walk and in a turn on the spot, and how high the foot rises.
var swing_seconds: float = 0.42
var turn_swing_seconds: float = 0.34
## The first step out of a standing start is quicker, and is taken as soon as the root moves (by the left foot).
var first_swing_seconds: float = 0.3
var lift: float = 0.075
## The distance between the two feet's lines, half of it (metres at scale 1), and the heading error that makes a planted foot step (degrees).
var half_stance: float = 0.095
var turn_trigger_degrees: float = 38.0
## Where the legs start and how long they are (metres at scale 1, from the rig): the hip joint's lateral offset, the ankle's height over the sole,
## the standing hips bone height, and the reach of a leg from the hip joint to the ankle.
var hip_lateral: float = 0.0855
var ankle_height: float = 0.085
var standing_hips: float = 0.955
var leg_reach: float = 0.848
var figure_scale: float = 1.0

## Inputs: one entry per frame.
var root: PackedVector2Array = PackedVector2Array()
var heading: PackedFloat32Array = PackedFloat32Array()

## Outputs, [left, right]: the foot's place in the world's xz plane, the height of the ankle over its resting height, and the foot's heading.
var foot_xz: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
var foot_up: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
var foot_heading: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
## The hips bone's height over the sole for each frame.
var hips_height: PackedFloat32Array = PackedFloat32Array()
## How many steps each foot took (a report, for tests and tuning).
var steps_taken: PackedInt32Array = PackedInt32Array([0, 0])


func frame_count() -> int:
	return root.size()


## The root's speed at a frame (metres per second), from the frames around it.
func speed_at(frame: int) -> float:
	var last: int = root.size() - 1
	var a: int = maxi(frame - 3, 0)
	var b: int = mini(frame + 3, last)
	if b <= a:
		return 0.0
	return root[a].distance_to(root[b]) / (float(b - a) * DT)


func _forward(frame: int) -> Vector2:
	return Vector2(sin(heading[frame]), cos(heading[frame]))


func _left(frame: int) -> Vector2:
	return Vector2(cos(heading[frame]), -sin(heading[frame]))


## Where a foot is wanted at a frame: on its own line beside the root, `ahead` metres in front of it.
func _wanted(frame: int, side: float, ahead: float) -> Vector2:
	return root[frame] + _left(frame) * (side * half_stance * figure_scale) + _forward(frame) * ahead


func plan() -> void:
	var count: int = root.size()
	for f: int in 2:
		foot_xz[f].resize(count)
		foot_up[f].resize(count)
		foot_heading[f].resize(count)
	hips_height.resize(count)
	steps_taken = PackedInt32Array([0, 0])
	if count == 0:
		return

	var sides: Array[float] = [1.0, -1.0]
	var planted_at: Array[Vector2] = [_wanted(0, 1.0, 0.0), _wanted(0, -1.0, 0.0)]
	var planted_heading: Array[float] = [heading[0], heading[0]]
	var swinging: Array[bool] = [false, false]
	var swing_start: Array[int] = [0, 0]
	var swing_length: Array[int] = [1, 1]
	var swing_from: Array[Vector2] = [planted_at[0], planted_at[1]]
	var swing_to: Array[Vector2] = [planted_at[0], planted_at[1]]
	var swing_from_heading: Array[float] = [heading[0], heading[0]]
	var swing_to_heading: Array[float] = [heading[0], heading[0]]
	var swing_height: Array[float] = [0.0, 0.0]
	var planted_since: Array[int] = [-100, -100]
	var still_since: int = 0
	var min_plant_frames: int = int(0.1 / DT)

	for i: int in count:
		var speed: float = speed_at(i)
		if speed > 0.08:
			still_since = i
		# A swing that ends puts its foot down where it was going.
		for f: int in 2:
			if swinging[f] and i >= swing_start[f] + swing_length[f]:
				swinging[f] = false
				planted_at[f] = swing_to[f]
				planted_heading[f] = swing_to_heading[f]
				planted_since[f] = i

		# One foot at a time: the one that needs it most, if the other is down.
		if not swinging[0] and not swinging[1]:
			var best: int = -1
			var best_need: float = 1.0
			for f: int in 2:
				if i - planted_since[f] < min_plant_frames:
					continue
				var behind: float = (_wanted(i, sides[f], 0.0) - planted_at[f]).dot(_forward(i))
				var aside: float = absf((_wanted(i, sides[f], 0.0) - planted_at[f]).dot(_left(i)))
				var turned: float = absf(rad_to_deg(angle_difference(planted_heading[f], heading[i])))
				# A foot is left behind by less before it steps while the root is still getting up to speed (or slowing): the first step must come at
				# once, or the other foot would be a whole stride behind by the time it can move.
				var trigger: float = stride_trigger * figure_scale * clampf(speed / (0.7 * reference_speed), 0.1, 1.0)
				var need: float = maxf(behind / trigger, maxf(aside / (0.2 * figure_scale), turned / turn_trigger_degrees))
				if steps_taken[0] + steps_taken[1] == 0 and speed > 0.15 and f == 0:
					need = maxf(need, 1.2)
				if speed < 0.08 and (i - still_since) > int(0.25 / DT):
					# Stopped: bring a foot that is not under the root in beside the other.
					if (_wanted(i, sides[f], 0.0) - planted_at[f]).length() > 0.07 * figure_scale:
						need = maxf(need, 1.05)
				if need >= best_need and (best < 0 or need > best_need):
					best = f
					best_need = need
			if best >= 0:
				var walking: bool = speed > 0.3
				var first_step: bool = steps_taken[0] + steps_taken[1] == 0
				var seconds: float = first_swing_seconds if (first_step and walking) else (swing_seconds if walking else turn_swing_seconds)
				var length_frames: int = maxi(int(round(seconds / DT)), 2)
				var landing: int = mini(i + length_frames, count - 1)
				var ahead: float = landing_lead * figure_scale * clampf(speed_at(landing) / reference_speed, 0.0, 1.0)
				swinging[best] = true
				swing_start[best] = i
				swing_length[best] = length_frames
				swing_from[best] = planted_at[best]
				swing_to[best] = _wanted(landing, sides[best], ahead)
				swing_from_heading[best] = planted_heading[best]
				swing_to_heading[best] = heading[landing]
				swing_height[best] = lift * figure_scale * (1.0 if walking else 0.55)
				steps_taken[best] += 1

		for f: int in 2:
			if swinging[f]:
				var u: float = clampf(float(i - swing_start[f]) / float(swing_length[f]), 0.0, 1.0)
				var eased: float = u * u * (3.0 - 2.0 * u)
				foot_xz[f][i] = swing_from[f].lerp(swing_to[f], eased)
				foot_up[f][i] = swing_height[f] * sin(PI * u)
				foot_heading[f][i] = swing_from_heading[f] + angle_difference(swing_from_heading[f], swing_to_heading[f]) * eased
			else:
				foot_xz[f][i] = planted_at[f]
				foot_up[f][i] = 0.0
				foot_heading[f][i] = planted_heading[f]

	_plan_hips()


## The pelvis is as high as the shorter of the two legs allows (a leg stays a little bent: 97% of its reach), and never higher than a person
## standing easily. Smoothed over a few frames.
func _plan_hips() -> void:
	var count: int = root.size()
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(count)
	var reach: float = leg_reach * figure_scale * 0.95
	var ceiling: float = (standing_hips - 0.012) * figure_scale
	for i: int in count:
		var best: float = ceiling
		for f: int in 2:
			var side: float = 1.0 if f == 0 else -1.0
			var hip_joint: Vector2 = root[i] + _left(i) * (side * hip_lateral * figure_scale) + _forward(i) * 0.01 * figure_scale
			var horizontal: float = hip_joint.distance_to(foot_xz[f][i])
			var vertical: float = sqrt(maxf(reach * reach - horizontal * horizontal, 0.0))
			var hips: float = ankle_height * figure_scale + foot_up[f][i] + vertical + 0.03 * figure_scale
			best = minf(best, hips)
		raw[i] = best
	var radius: int = 4
	for i: int in count:
		var total: float = 0.0
		var weight: int = 0
		for k: int in range(maxi(i - radius, 0), mini(i + radius, count - 1) + 1):
			total += raw[k]
			weight += 1
		hips_height[i] = total / float(weight)
