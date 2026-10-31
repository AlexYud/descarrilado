extends Node

## How the ground changes the walk: uphill is slower and downhill quicker (the pace, the steps, the head and the breath follow), and a stair is a slow, heavy
## climb with its own motion of the head (it rises in the middle of each step going up, drops with the heel going down) and now and then the groan of an old
## board. The real player walks on a flat floor, a slope of about 20 degrees and a stair (a slope in the `stairs` group, as the game's stairs are). Run it as a
## scene; it quits by itself with a non-zero exit code on failure.

const TIME_SCALE: float = 2.0
const SLOPE_DEGREES: float = 20.0
const STAIRS_DEGREES: float = 35.0
const RAMP_LENGTH: float = 18.0

var test_failed: bool = false
var player: CharacterBody3D = null
var movement: PlayerMovementController = null
var level: Node3D = null


func _ready() -> void:
	DoorController.approach_enabled = false
	GameSettings.set_text_locale("en", false)
	GameSettings.set_head_bob_enabled(true, false)
	level = Node3D.new()
	add_child(level)
	_add_floor()
	# The slope rises towards -Z from z = 2; the stair rises towards -Z from z = -40, a long way from it.
	_add_ramp(Vector3(0.0, 0.0, 2.0), SLOPE_DEGREES, false)
	_add_ramp(Vector3(0.0, 0.0, -40.0), STAIRS_DEGREES, true)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	level.add_child(player)
	player.global_position = Vector3(0.0, 1.1, 14.0)
	var setup: PlayTestSetup = PlayTestSetup.new()
	setup.player = player
	level.add_child(setup)
	for i: int in 12:
		await get_tree().physics_frame

	movement = player.movement_controller
	Engine.time_scale = TIME_SCALE
	await _run()
	Engine.time_scale = 1.0
	Input.action_release(&"up")

	print("SLOPE_AND_STAIRS_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	_check_the_curve()
	var flat: Dictionary = await _walk(Vector3(0.0, 1.1, 14.0), 0.0, 3.2, func() -> bool: return absf(movement.slope_grade) < 0.03 and player.is_on_floor())
	var uphill: Dictionary = await _walk(Vector3(0.0, 1.1, 6.0), 0.0, 6.5, func() -> bool: return movement.slope_grade > tan(deg_to_rad(SLOPE_DEGREES)) * 0.85 and movement.stairs_blend < 0.1)
	var downhill: Dictionary = await _walk(_ramp_point(Vector3(0.0, 0.0, 2.0), SLOPE_DEGREES, 13.0) + Vector3(0.0, 1.1, 0.0), 180.0, 6.5, func() -> bool: return movement.slope_grade < -tan(deg_to_rad(SLOPE_DEGREES)) * 0.85 and movement.stairs_blend < 0.1)
	_check_the_pace(flat, uphill, downhill)
	_check_the_body(flat, uphill, downhill)
	var stairs: Dictionary = await _walk(Vector3(0.0, 1.1, -36.0), 0.0, 9.0, func() -> bool: return movement.stairs_blend > 0.9 and movement.slope_grade > 0.4)
	var down_stairs: Dictionary = await _walk(_ramp_point(Vector3(0.0, 0.0, -40.0), STAIRS_DEGREES, 14.0) + Vector3(0.0, 1.1, 0.0), 180.0, 9.0, func() -> bool: return movement.stairs_blend > 0.9 and movement.slope_grade < -0.4)
	_check_the_stairs(uphill, stairs, down_stairs)


# ============================================================
# THE LEVEL
# ============================================================

func _add_floor() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 120.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, -20.0)
	ground.add_child(shape)
	level.add_child(ground)


## A ramp of `RAMP_LENGTH` metres from `start` rising towards -Z at `degrees`; `stairs` puts it in the group of the game's stairs.
func _add_ramp(start: Vector3, degrees: float, stairs: bool) -> void:
	var ramp: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6.0, 0.4, RAMP_LENGTH)
	shape.shape = box
	ramp.add_child(shape)
	level.add_child(ramp)
	var angle: float = deg_to_rad(degrees)
	ramp.basis = Basis(Vector3.RIGHT, angle)
	var along: Vector3 = Vector3(0.0, sin(angle), -cos(angle))
	ramp.position = start + along * RAMP_LENGTH * 0.5 - ramp.basis.y * 0.2
	if stairs:
		ramp.add_to_group(&"stairs")
		ramp.set_meta(&"stair_creaks", true)


## A point on a ramp's surface `distance` along it from its start.
func _ramp_point(start: Vector3, degrees: float, distance: float) -> Vector3:
	var angle: float = deg_to_rad(degrees)
	return start + Vector3(0.0, sin(angle), -cos(angle)) * distance


# ============================================================
# WALKING
# ============================================================

## Walks the real player from `from`, facing `yaw`, for `seconds` of game time, and reports what happened while `counts` was true: how fast (m/s of
## horizontal movement), how many frames that was, how far the camera moved up and down (its local y, peak to peak after the pace had settled), and
## the breath, the lean and the stride.
func _walk(from: Vector3, yaw: float, seconds: float, counts: Callable) -> Dictionary:
	Input.action_release(&"up")
	movement.look_yaw = yaw
	movement.look_pitch = 0.0
	player.global_position = from
	player.velocity = Vector3.ZERO
	movement._reset_view_motion()
	await get_tree().create_timer(0.5).timeout
	Input.action_press(&"up")
	var speeds: Array[float] = []
	var heights: Array[float] = []
	var efforts: Array[float] = []
	var pitches: Array[float] = []
	var steps_at_start: float = movement.step_phase
	var steps_in_window: float = 0.0
	var window_seen: bool = false
	var waited: float = 0.0
	var creaks_before: bool = player.audio_controller._creak_player != null
	var last_phase: float = movement.step_phase
	while waited < seconds:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if bool(counts.call()) and waited > 0.8:
			speeds.append(Vector2(player.velocity.x, player.velocity.z).length())
			heights.append(movement.camera.position.y)
			efforts.append(movement.slope_effort)
			pitches.append(movement._slope_pitch)
			if movement.step_phase >= last_phase:
				steps_in_window += movement.step_phase - last_phase
				window_seen = true

		last_phase = movement.step_phase

	Input.action_release(&"up")
	var mean: float = 0.0
	for speed: float in speeds:
		mean += speed

	mean /= maxf(float(speeds.size()), 1.0)
	var low: float = INF
	var high: float = -INF
	for height: float in heights:
		low = minf(low, height)
		high = maxf(high, height)

	var effort: float = 0.0
	for value: float in efforts:
		effort = maxf(effort, value)

	var pitch: float = 0.0
	for value: float in pitches:
		pitch += value / maxf(float(pitches.size()), 1.0)

	return {
		"speed": mean, "frames": speeds.size(), "height_range": high - low if not heights.is_empty() else 0.0,
		"effort": effort, "pitch": pitch, "steps": steps_in_window, "seconds": float(speeds.size()) * get_physics_process_delta_time(),
		"creak_player": player.audio_controller._creak_player != null and not creaks_before, "window_seen": window_seen,
		"steps_at_start": steps_at_start,
	}


# ============================================================
# THE CHECKS
# ============================================================

func _check_the_curve() -> void:
	var f: Callable = PlayerMovementController.slope_speed_factor
	_expect(is_equal_approx(f.call(0.0), 1.0), "the flat is the usual pace")
	_expect(f.call(0.36) < 0.85 and f.call(0.36) > 0.65, "a slope of 20 degrees takes a good part of the pace (%.2f)" % f.call(0.36))
	_expect(f.call(0.62) < f.call(0.36) and f.call(2.0) >= PlayerMovementController.UPHILL_SLOWEST - 0.001, "a steeper one takes more, up to a point (%.2f, %.2f)" % [f.call(0.62), f.call(2.0)])
	_expect(f.call(-0.24) > 1.15 and f.call(-0.24) <= PlayerMovementController.DOWNHILL_QUICKEST + 0.001, "downhill is quicker (%.2f)" % f.call(-0.24))
	_expect(f.call(-0.7) < f.call(-0.24) and f.call(-0.7) > 1.0, "but a very steep way down is taken with care again (%.2f)" % f.call(-0.7))


func _check_the_pace(flat: Dictionary, uphill: Dictionary, downhill: Dictionary) -> void:
	_expect(int(flat["frames"]) > 20 and int(uphill["frames"]) > 20 and int(downhill["frames"]) > 20, "the player walked on the flat, up the slope and down it (%d, %d, %d frames)" % [flat["frames"], uphill["frames"], downhill["frames"]])
	var walk_speed: float = PlayerMovementController.WALK_SPEED
	_expect(absf(float(flat["speed"]) - walk_speed) < 0.12, "on the flat the pace is the walking pace (%.2f of %.2f)" % [flat["speed"], walk_speed])
	# The pace is the same on a hill (only the stairs have a pace of their own).
	_expect(absf(float(uphill["speed"]) - float(flat["speed"])) < float(flat["speed"]) * 0.06, "uphill is the same pace as the flat (%.2f against %.2f)" % [uphill["speed"], flat["speed"]])
	_expect(absf(float(downhill["speed"]) - float(flat["speed"])) < float(flat["speed"]) * 0.06, "and so is downhill (%.2f against %.2f)" % [downhill["speed"], flat["speed"]])


func _check_the_body(flat: Dictionary, uphill: Dictionary, downhill: Dictionary) -> void:
	_expect(float(uphill["effort"]) > 0.5 and float(flat["effort"]) < 0.1, "the climb is hard work for the breath (%.2f against %.2f)" % [uphill["effort"], flat["effort"]])
	_expect(float(uphill["pitch"]) < -0.6 and float(downhill["pitch"]) > 0.2, "the head leans in going up (%.1f degrees) and back going down (%.1f)" % [uphill["pitch"], downhill["pitch"]])
	# Shorter steps uphill, longer downhill: steps per metre walked.
	var up_rate: float = float(uphill["steps"]) / maxf(float(uphill["speed"]) * float(uphill["seconds"]), 0.01)
	var flat_rate: float = float(flat["steps"]) / maxf(float(flat["speed"]) * float(flat["seconds"]), 0.01)
	var down_rate: float = float(downhill["steps"]) / maxf(float(downhill["speed"]) * float(downhill["seconds"]), 0.01)
	_expect(up_rate > flat_rate * 1.0 and down_rate < flat_rate * 0.95, "the steps are shorter uphill and longer downhill (%.2f, %.2f, %.2f steps a metre)" % [up_rate, flat_rate, down_rate])
	var breath: ColdBreath = player.cold_breath
	movement.slope_effort = 0.9
	_expect(breath != null, "the player breathes the cold air")
	player.velocity = Vector3(0.0, 0.0, -0.6)
	_expect(breath.get_effort() == 2, "a hard climb breathes as running does")
	movement.slope_effort = 0.0
	_expect(breath.get_effort() == 1, "and a walk on the flat does not")
	player.velocity = Vector3.ZERO


func _check_the_stairs(uphill: Dictionary, stairs: Dictionary, down_stairs: Dictionary) -> void:
	_expect(int(stairs["frames"]) > 30 and int(down_stairs["frames"]) > 30, "the player climbed a stair and came down it (%d, %d frames)" % [stairs["frames"], down_stairs["frames"]])
	var walk_speed: float = PlayerMovementController.WALK_SPEED
	_expect(float(stairs["speed"]) < walk_speed * 0.62 and float(stairs["speed"]) > walk_speed * 0.45, "a stair is climbed slowly (%.2f, a pace of %.2f)" % [stairs["speed"], walk_speed])
	_expect(float(down_stairs["speed"]) < walk_speed * 0.72 and float(down_stairs["speed"]) > walk_speed * 0.5, "and gone down with care (%.2f)" % down_stairs["speed"])
	_expect(float(stairs["effort"]) > 0.7, "the climb takes the breath (%.2f)" % stairs["effort"])
	_expect(float(stairs["height_range"]) > float(uphill["height_range"]) * 1.5, "the head rises and sinks with every step, much more than on a plain slope (%.3f against %.3f)" % [stairs["height_range"], uphill["height_range"]])
	_expect(float(down_stairs["height_range"]) > float(uphill["height_range"]) * 1.5, "going down too")
	# One footfall to two treads, about half a metre of stair.
	var per_step: float = float(stairs["speed"]) * float(stairs["seconds"]) / maxf(float(stairs["steps"]), 0.01)
	_expect(per_step > 0.4 and per_step < 0.65, "a step takes about two treads (%.2f m)" % per_step)
	_expect(float(stairs["pitch"]) < -0.8 and float(down_stairs["pitch"]) < float(stairs["pitch"]), "the head bows to the steps, more going down (%.1f, %.1f degrees)" % [stairs["pitch"], down_stairs["pitch"]])
	_expect(bool(stairs["creak_player"]) or bool(down_stairs["creak_player"]) or player.audio_controller._creak_player != null, "the old boards groaned under a step")
	var creak: AudioStreamWAV = PlaceholderAudio.make_stair_creak(0.55, 11)
	_expect(creak.get_length() > 0.5 and creak.data.size() > 10000, "(a creak is half a second of sound)")
	# The head's curve goes to nothing over a step: the view is never left higher or lower.
	var total: float = 0.0
	movement.slope_grade = 0.7
	for index: int in 100:
		total += movement._stairs_lift(float(index) / 100.0)

	movement.slope_grade = -0.7
	var total_down: float = 0.0
	for index: int in 100:
		total_down += movement._stairs_lift(float(index) / 100.0)

	movement.slope_grade = 0.0
	_expect(absf(total) / 100.0 < 0.002 and absf(total_down) / 100.0 < 0.002, "and it averages out to nothing over a step (%.4f, %.4f)" % [total / 100.0, total_down / 100.0])


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
