extends Node
class_name FinaleDoorScene

## The last scene of the game, at the wagon's black corridor door (the end of `DreamFinale`): the player walks the aisle to it
## themselves, slowly; when they are close and looking at it a pale head swings in over the door, and Juliana is frightened out of
## her wits: she falls twisting away from it onto all fours, the flashlight flying out of her hand, and crawls away along the floor;
## something takes her foot, and in the dark she has to press the interact key again and again against what drags her back (and cannot
## win); then two hands close on her face. The host (`DreamFinale`) gets `captured` when they have, and does the black and the title.
##
## The only sounds are the player's own footsteps and the sting of the head. Nothing here is a debug aid.
##
## How the fall and the crawl are built (the body is never seen, so only the view moves, but it moves like the head of a body that
## does these things):
##   - the camera is her head: its height is her eye height (standing, on all fours), its pitch is how she holds her head (thrown
##     back, down at her hands), its roll is where her weight is and its yaw is how her torso twists;
##   - every motion has an anticipation (the opposite way first), a fast main movement and a follow-through (overshoot, then it
##     settles), and impacts (the palms) add a short shake that dies away quickly (a "trauma" value, squared, as in the usual
##     camera-shake model);
##   - a crawl is a train of strokes, hand after hand: the head lifts and leans forward as the hand reaches, dips as it lands (the
##     weight goes onto that arm), and the shoulders sway the other way as the body is pulled past it.

## The head has begun to swing (the player has got to the door).
signal scare_started
## The hands are on her face: the host turns it black.
signal captured

## Where the corridor door is (the front face of the partition, wagon-local z) and how far from it the scare begins (the player is
## looking at the door by then; if they are not, it begins a metre further on all the same).
const DOOR_Z: float = 3.75
const TRIGGER_DISTANCE: float = 3.4
const TRIGGER_Z: float = DOOR_Z - TRIGGER_DISTANCE
## How fast the player walks to the door (a fraction of the usual pace) and how far back they may go.
const WALK_SCALE: float = 0.55
const BACK_LIMIT: float = 0.6
## The sting of the head comes this long after its movement has started: in the middle of its swing.
const STING_AFTER_START_SECONDS: float = 0.5
## Her eyes' height above the floor on all fours.
const EYE_CRAWLING: float = 0.6
## The pulls of the crawl, each quicker than the last (panic), how far each takes her, and the closing time of the hands.
const CRAWL_SECONDS: Array[float] = [0.55, 0.45]
const CRAWL_LENGTH: float = 0.4
const GRAB_SECONDS: float = 0.26
## How far the thing drags her towards the door when the bar is empty.
const DRAG_DISTANCE: float = 1.9
## How fast she crawls while she fights it (strokes a second): slowly when she is only being hauled back, quickly while she is pressing.
const STRUGGLE_SLOW_RATE: float = 0.55
const STRUGGLE_FAST_RATE: float = 2.0
## How far the view lunges with every stroke of the struggle, and how much the head turns and nods with each, against a crawl's 1.
const STRUGGLE_REACH: float = 0.3
const STRUGGLE_VIGOR: float = 0.6
const POSE_FIELDS: Array[String] = ["yaw", "pitch", "roll", "x", "y", "z"]

var wagon: Node3D = null
var creature: FinaleCreature = null
var struggle: FinaleStruggle = null

var _player: Node3D = null
var _movement: Node = null
var _torch: Node = null
var _camera: Camera3D = null
var _prop: Node3D = null
var _run: int = 0
var _clock: float = 0.0
var _eye_height: float = 1.55
var _fov_tween: Tween = null
var _tweens: Array[Tween] = []
var _struggling: bool = false
var _grabbing: bool = false
var _fall_z: float = 0.0
var _step_side: float = 1.0

# The hand-animated view (see `_scare_and_crawl`): the pose that the keys set, the stroke of the last hand, the strain and the shake.
var _rig_on: bool = false
var _rig_base_yaw: float = 0.0
var _pose_yaw: float = 0.0
var _pose_pitch: float = 0.0
var _pose_roll: float = 0.0
var _pose_x: float = 0.0
var _pose_y: float = 0.0
var _pose_z: float = 0.0
var _crawling: bool = false
var _crawl_phase: float = 0.0
var _crawl_rate: float = STRUGGLE_SLOW_RATE
var _crawl_side: float = 1.0
var _effort: float = 0.0
var _strain: float = 0.0
var _stroke_gain: float = 1.0
var _stroke_offset: Vector3 = Vector3.ZERO
var _stroke_pitch: float = 0.0
var _stroke_roll: float = 0.0
var _stroke_yaw: float = 0.0
var _strain_time: float = 0.0
var _trauma: float = 0.0
var _jolt: float = 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	_drag(delta)
	_rig_tick(delta)
	if _grabbing:
		creature.follow_camera(_camera_in_wagon())


## Gives the scene the wagon and the player, and builds what it needs (the head and hands in the wagon, the prompt).
func setup(wagon_node: Node3D, player_node: Node3D) -> void:
	wagon = wagon_node
	_player = player_node
	_movement = _player.get("movement_controller") as Node
	_torch = _player.get("flashlight_controller") as Node
	_camera = _player.get_node("Head/Camera3D") as Camera3D
	creature = FinaleCreature.new()
	wagon.add_child(creature)
	struggle = FinaleStruggle.new()
	add_child(struggle)


## The black of the corridor door (the vestibule behind it is pitch black).
func show_doorway(on: bool) -> void:
	if creature != null:
		creature.show_doorway(on)


## The scene, as a coroutine: the host calls it when the player has the controls back, facing the door.
func begin() -> void:
	_run += 1
	var generation: int = _run
	set_process(true)
	if not await _approach(generation):
		return

	scare_started.emit()
	if not await _scare_and_crawl(generation):
		return

	if not await _run_struggle(generation):
		return

	await _ending(generation)
	if generation != _run:
		return

	captured.emit()


## Ends what is in progress.
func stop() -> void:
	_run += 1
	set_process(false)
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()

	_tweens.clear()
	if _fov_tween != null and _fov_tween.is_valid():
		_fov_tween.kill()

	if creature != null:
		creature.stop()

	if struggle != null:
		struggle.end()


## Gives the player back everything the scene changed in their view (for when the finale ends without leaving the scene).
func cleanup() -> void:
	stop()
	_grabbing = false
	_struggling = false
	_rig_end()
	_set_blur(false)
	if _movement != null:
		_movement.set("scripted_fov", 0.0)

	if _prop != null and is_instance_valid(_prop):
		_prop.queue_free()
		_prop = null


func _new_tween() -> Tween:
	var tween: Tween = create_tween()
	_tweens.append(tween)
	return tween


## The direction along the aisle from the back of the wagon to the corridor door, in the world.
func _aisle_axis() -> Vector3:
	return wagon.global_basis * Vector3.BACK


## The camera's transform in the wagon's own space.
func _camera_in_wagon() -> Transform3D:
	return wagon.global_transform.affine_inverse() * _camera.global_transform


# ============================================================
# The walk to the door
# ============================================================

## The walk is the player's: slowly, along the aisle (the corridor lock keeps them in it; the view is free). When they are
## `TRIGGER_DISTANCE` from the door and looking at it (or when they have gone a metre past that, whatever they look at) the scare begins.
func _approach(generation: int) -> bool:
	_player.set("scripted_flashlight", true)
	var start_z: float = wagon.to_local(_player.global_position).z
	_movement.call("lock_to_corridor", _player.global_position, _aisle_axis(), -BACK_LIMIT, TRIGGER_Z + 1.3 - start_z)
	_movement.set("corridor_speed_scale", WALK_SCALE)
	_movement.set("scripted_fov", 0.0)
	var door_at: Vector3 = wagon.to_global(Vector3(0.0, creature.floor_y + 1.2, DOOR_Z))
	var looking_time: float = 0.0
	while true:
		await get_tree().process_frame
		if generation != _run:
			return false

		var z: float = wagon.to_local(_player.global_position).z
		if z >= TRIGGER_Z:
			var at_door: Vector3 = (door_at - _camera.global_position).normalized()
			if (-_camera.global_basis.z).dot(at_door) > 0.85:
				looking_time += get_process_delta_time()
			else:
				looking_time = 0.0

			if looking_time >= 0.3 or z >= TRIGGER_Z + 1.0:
				break

	return true


# ============================================================
# The head, the fall and the crawl
# ============================================================

## The head swings down out of the dark behind the door, the sting lands half a second into its swing, and she jumps: the head is
## thrown up and back, and at once her legs go and she falls twisting away from it, round onto all fours in one violent movement (the
## flashlight flying out of her hand), and crawls away along the floor towards the light of the flashlight, faster and faster; and on
## the way something takes her foot.
func _scare_and_crawl(generation: int) -> bool:
	# She does not stop dead: the walk slows to nothing as the head comes down, and the view is still the player's until she jumps.
	var slow: Tween = _new_tween()
	slow.tween_property(_movement, "corridor_speed_scale", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	creature.play_jumpscare()
	await creature.jumpscare_cue
	if generation != _run:
		return false

	# The head swings in without a sound; half a second after it has started, in the middle of its swing, comes the sting, and her fright
	# with it.
	await get_tree().create_timer(STING_AFTER_START_SECONDS).timeout
	if generation != _run:
		return false

	_play_sting(PlaceholderAudio.make_grab_impact(), -1.0)
	_play_sting(PlaceholderAudio.make_whisper(), -7.0)
	_movement.set("scripted_fov", 86.0)
	_fov_tween = create_tween()
	_fov_tween.tween_property(_movement, "scripted_fov", 70.0, 0.5).set_trans(Tween.TRANS_SINE)
	# She jumps. The view is taken over from where it is (no snap), and the body goes off in an instant: the head is thrown up and back, the
	# shoulders twist, and the tremor of the fright starts.
	_eye_height = _camera.global_position.y - wagon.to_global(Vector3(0.0, creature.floor_y, 0.0)).y
	_rig_begin()
	_jolt = 1.0
	var snap: Array[Dictionary] = [
		{"t": 0.08, "yaw": 9.0, "pitch": 14.0, "roll": 8.0, "y": 0.04, "z": 0.3, "ease": "out", "shake": 1.0},
	]
	if not await _play_keys(generation, snap):
		return false

	# And at once her legs go and she throws herself round, away from it: one movement, a fall that is also a twist. The view is taken over from
	# where it is (no snap to a rest pose, no cut in the field of view): the player has stopped by now.
	_player.set("view_locked", true)
	_movement.call("release_corridor")
	# The head lets go of the door: it drops to the floor and starts to crawl after her legs, while she twists to get away.
	creature.play_face_drop()
	var hand_at: Vector3 = (_torch as Node3D).global_position
	CaptionManager.say("CAPTION_WAGON_SWEAR", 2.0)
	# The flashlight leaves her hand (and she cannot switch it on again).
	_torch.set("toggle_locked", true)
	_torch.set("scripted_aim_on", false)
	_torch.call("turn_off")
	_spawn_prop(hand_at)
	var on_all_fours: float = -(_eye_height - EYE_CRAWLING)
	var twist: Array[Dictionary] = [
		# The knees buckle and the shoulders go round: the view sinks and turns, rolling over the shoulder she turns on.
		{"t": 0.2, "yaw": -60.0, "pitch": 8.0, "roll": -18.0, "y": -0.28, "z": 0.5, "ease": "fall"},
		# Still turning, down onto the hands: the view sweeps across the wagon and looks down.
		{"t": 0.44, "yaw": -140.0, "pitch": -6.0, "roll": -12.0, "y": lerpf(0.0, on_all_fours, 0.7), "z": 0.4, "ease": "lin"},
		# The palms hit the floor, a little past where the turn has to stop...
		{"t": 0.64, "yaw": -196.0, "pitch": -28.0, "roll": -4.0, "y": on_all_fours - 0.1, "z": 0.3, "ease": "out", "shake": 0.8},
		# ...and it settles, on all fours, looking along the floor away from the door.
		{"t": 0.88, "yaw": -180.0, "pitch": 9.0, "roll": 0.0, "y": on_all_fours, "z": 0.25, "ease": "io"},
	]
	if not await _play_keys(generation, twist):
		return false

	# From here the view looks the other way: its zero is the new way.
	_rig_base_yaw += _pose_yaw
	_pose_yaw = 0.0

	# She crawls away from the door, towards the light of the flashlight lying on the floor: pulls of the arms, faster each time.
	for pull: int in CRAWL_SECONDS.size():
		if not await _crawl_pull(generation, CRAWL_SECONDS[pull], CRAWL_LENGTH, 0.35):
			return false

	# And her foot is taken: the whole body is yanked back.
	_fall_z = wagon.to_local(_player.global_position).z
	var at: Vector3 = wagon.to_local(_player.global_position)
	var jerk: Tween = _new_tween()
	jerk.tween_method(func(back: float) -> void: _player.global_position = wagon.to_global(Vector3(at.x, at.y, _fall_z + back)), 0.0, 0.25, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var yank: Array[Dictionary] = [
		{"t": 0.07, "pitch": 22.0, "roll": 12.0, "y": on_all_fours - 0.05, "z": 0.6, "ease": "out", "shake": 0.9},
		{"t": 0.3, "pitch": 12.0, "roll": 0.0, "y": on_all_fours, "z": 0.3, "ease": "io"},
	]
	if not await _play_keys(generation, yank):
		return false

	_fall_z = wagon.to_local(_player.global_position).z
	return true


## One pull of a crawl, on the floor: the body moves `distance` along the aisle, away from the door, while the view makes the
## stroke of one hand (see `_set_stroke`).
func _crawl_pull(generation: int, duration: float, distance: float, reach: float) -> bool:
	var from: Vector3 = _player.global_position
	var to: Vector3 = from - _aisle_axis() * distance
	var elapsed: float = 0.0
	while elapsed < duration:
		await get_tree().process_frame
		if generation != _run:
			return false

		elapsed += get_process_delta_time()
		var progress: float = clampf(elapsed / duration, 0.0, 1.0)
		_set_stroke(progress, _step_side, reach)
		# The body travels while the arm pulls, in the second half of the stroke.
		_player.global_position = from.lerp(to, smoothstep(0.4, 1.0, progress))

	_set_stroke(1.0, _step_side, reach)
	_step_side = -_step_side
	return true


## The view's part of one stroke of a crawl or of a struggle (`progress` 0 to 1; zero at both ends): the head comes forward and a
## little up as the hand reaches, dips as it lands (the weight goes onto that arm: the head rolls towards it), and the shoulders
## sway the other way as the body is pulled past it. `side` is +1 for the right hand and -1 for the left.
func _set_stroke(progress: float, side: float, reach: float, vigor: float = 1.0) -> void:
	var reaching: float = sin(clampf(progress / 0.4, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.5, 1.0, progress))
	var landing: float = sin(clampf((progress - 0.25) / 0.4, 0.0, 1.0) * PI)
	var pulling: float = sin(clampf((progress - 0.45) / 0.55, 0.0, 1.0) * PI)
	_stroke_offset = Vector3(
		side * 0.05 * pulling,
		0.03 * reaching - 0.07 * landing + 0.035 * pulling,
		-reach * 0.5 * reaching + reach * 0.15 * pulling
	)
	_stroke_pitch = (5.0 * reaching - 7.0 * landing + 3.0 * pulling) * vigor
	_stroke_roll = (-side * 5.0 * reaching + side * 7.0 * landing - side * 5.0 * pulling) * vigor
	_stroke_yaw = (side * 3.0 * reaching - side * 5.0 * pulling) * vigor


# ============================================================
# The view (see `_scare_and_crawl`)
# ============================================================

## Starts the hand-animated view: from here on `_rig_tick` writes the player's view every frame, from the pose that the keys
## (`_play_keys`), the strokes and the shake make up. The yaw and pitch the player had are taken over as the pose's zero.
func _rig_begin() -> void:
	_rig_base_yaw = float(_movement.get("look_yaw"))
	_pose_pitch = -float(_movement.get("look_pitch"))
	_pose_yaw = 0.0
	_pose_roll = 0.0
	_pose_x = 0.0
	_pose_y = 0.0
	_pose_z = 0.0
	_crawling = false
	_crawl_phase = 0.0
	_crawl_rate = STRUGGLE_SLOW_RATE
	_effort = 0.0
	_strain = 0.0
	_stroke_gain = 1.0
	_stroke_offset = Vector3.ZERO
	_stroke_pitch = 0.0
	_stroke_roll = 0.0
	_stroke_yaw = 0.0
	_strain_time = 0.0
	_trauma = 0.0
	_jolt = 0.0
	_movement.set("look_pitch", 0.0)
	_movement.set("gesture_direct", true)
	_rig_on = true


func _rig_end() -> void:
	_rig_on = false
	_crawling = false
	if _movement != null:
		_movement.set("gesture_direct", false)
		_movement.set("gesture_offset", Vector3.ZERO)
		_movement.set("gesture_pitch_degrees", 0.0)
		_movement.set("gesture_roll_degrees", 0.0)


## Called every frame: runs the crawl of the struggle and the strain, and writes the view.
## The crawl never restarts: its strokes follow one another, hand after hand, and only their speed changes (smoothly), with how hard
## she has been pressing lately; the view is never given a kick of its own by a press.
func _rig_tick(delta: float) -> void:
	if not _rig_on:
		return

	_movement.set("look_pitch", 0.0)
	if _struggling:
		_strain_time += delta

	if _crawling:
		_effort = maxf(_effort - delta * 0.8, 0.0)
		var wanted_rate: float = lerpf(STRUGGLE_SLOW_RATE, STRUGGLE_FAST_RATE, clampf(_effort, 0.0, 1.0))
		_crawl_rate = lerpf(_crawl_rate, wanted_rate, 1.0 - exp(-delta * 5.0))
		_crawl_phase += delta * _crawl_rate
		var cycle: float = floorf(_crawl_phase)
		# The hand changes where a stroke is over, when the view is at rest: no jump.
		_crawl_side = 1.0 if int(cycle) % 2 == 0 else -1.0
		_set_stroke(_crawl_phase - cycle, _crawl_side, STRUGGLE_REACH * _stroke_gain, STRUGGLE_VIGOR * _stroke_gain)

	_trauma = maxf(_trauma - delta * 1.7, 0.0)
	var shake: float = _trauma * _trauma
	# The start of a fright: a hard tremor that carries on through the first moments and is gone in about a second.
	_jolt = maxf(_jolt - delta * 1.3, 0.0)
	var jolt: float = _jolt * _jolt
	var noise_a: float = sin(_clock * 37.0) + sin(_clock * 61.0 + 1.3)
	var noise_b: float = sin(_clock * 43.0 + 2.1) + sin(_clock * 71.0 + 0.4)
	var noise_c: float = sin(_clock * 29.0 + 4.2) + sin(_clock * 53.0 + 3.1)
	# Between her presses the thing hauls her back: a slow lean back and up against the pull, eased in and out, never stepped.
	var hauled: float = 0.0
	if _struggling:
		hauled = clampf((_strain_time - 0.3) * 2.0, 0.0, 1.0)

	_strain = lerpf(_strain, hauled, 1.0 - exp(-delta * 2.5))
	_movement.set("look_yaw", _rig_base_yaw + _pose_yaw + _stroke_yaw + (shake * 2.5 + jolt * 3.0) * noise_a)
	_movement.set("gesture_pitch_degrees", _pose_pitch + _stroke_pitch + _strain * 5.0 + (shake * 2.2 + jolt * 2.5) * noise_b)
	_movement.set("gesture_roll_degrees", _pose_roll + _stroke_roll + (shake * 2.5 + jolt * 3.0) * noise_c)
	_movement.set("gesture_offset", Vector3(_pose_x, _pose_y, _pose_z) + _stroke_offset + Vector3((shake * 0.015 + jolt * 0.02) * noise_a, (shake * 0.02 + jolt * 0.02) * noise_b, _strain * 0.1 + (shake * 0.015 + jolt * 0.02) * noise_c))


## Plays a list of keys on the pose, one after the other: `t` is when the key is reached (seconds from the start of the list), then
## any of `yaw`, `pitch`, `roll`, `x`, `y`, `z` (the pose it moves to; what a key leaves out stays), `ease` ("out" arrives fast and
## slows, "in" starts slowly and arrives fast, "lin" is even, "fall" starts already moving and speeds up, anything else is smooth),
## `shake` (trauma added on arriving) and `do` (a Callable run on arriving). False when the scene was stopped.
func _play_keys(generation: int, keys: Array[Dictionary]) -> bool:
	var start_time: float = 0.0
	for key: Dictionary in keys:
		var end_time: float = key["t"]
		var duration: float = maxf(end_time - start_time, 0.001)
		var from: Dictionary = {}
		for field: String in POSE_FIELDS:
			if key.has(field):
				from[field] = float(get("_pose_" + field))

		var elapsed: float = 0.0
		while elapsed < duration:
			await get_tree().process_frame
			if generation != _run:
				return false

			elapsed += get_process_delta_time()
			var eased: float = _ease(clampf(elapsed / duration, 0.0, 1.0), String(key.get("ease", "io")))
			for field: String in from:
				set("_pose_" + field, lerpf(float(from[field]), float(key[field]), eased))

		for field: String in from:
			set("_pose_" + field, float(key[field]))

		_trauma = maxf(_trauma, float(key.get("shake", 0.0)))
		if key.has("do"):
			(key["do"] as Callable).call()

		start_time = end_time

	return true


func _ease(progress: float, mode: String) -> float:
	if mode == "out":
		return 1.0 - pow(1.0 - progress, 3.0)

	if mode == "in":
		return progress * progress * progress

	if mode == "lin":
		return progress

	# A fall that begins already moving (it takes over from a stagger) and speeds up.
	if mode == "fall":
		return progress * (0.4 + 0.6 * progress * progress)

	return smoothstep(0.0, 1.0, progress)


## The flashlight as a prop: a small cylinder with its own beam. It leaves her hand at `from` and rolls away along the aisle, away
## from the door, spinning, and lies there with its beam on the floor (the light she crawls towards).
func _spawn_prop(from: Vector3) -> void:
	_prop = Node3D.new()
	_prop.name = "RolledFlashlight"
	wagon.add_child(_prop)
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.12, 0.13)
	metal.metallic = 0.7
	metal.roughness = 0.4
	var body: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.026
	cylinder.bottom_radius = 0.022
	cylinder.height = 0.19
	body.mesh = cylinder
	body.material_override = metal
	body.rotation_degrees.x = 90.0
	_prop.add_child(body)
	var lens: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.036
	disc.bottom_radius = 0.028
	disc.height = 0.04
	lens.mesh = disc
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.9, 0.95, 1.0)
	glass.emission_enabled = true
	glass.emission = Color(0.9, 0.95, 1.0)
	glass.emission_energy_multiplier = 1.5
	lens.material_override = glass
	lens.rotation_degrees.x = 90.0
	lens.position = Vector3(0.0, 0.0, -0.1)
	_prop.add_child(lens)
	var beam: SpotLight3D = SpotLight3D.new()
	var player_spot: SpotLight3D = _torch as SpotLight3D
	beam.light_energy = player_spot.light_energy * 1.4
	beam.spot_range = player_spot.spot_range
	beam.spot_angle = player_spot.spot_angle
	beam.spot_attenuation = player_spot.spot_attenuation
	beam.light_color = player_spot.light_color
	beam.position = Vector3(0.0, 0.0, -0.11)
	_prop.add_child(beam)

	var floor_level: float = creature.floor_y + 0.03
	# It rolls away ahead of her, along the aisle, away from the door.
	var rest: Vector3 = wagon.to_global(Vector3(0.28, floor_level, TRIGGER_Z - 2.3))
	_prop.global_position = from
	# It spins as it rolls and ends up pointing a little to one side.
	_prop.rotation.y = 0.0
	var path: Tween = _new_tween().set_parallel(true)
	path.tween_property(_prop, "global_position:y", rest.y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	path.tween_property(_prop, "global_position:z", rest.z, 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	path.tween_property(_prop, "global_position:x", rest.x, 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	path.tween_property(_prop, "rotation:y", 0.5 - TAU * 2.0, 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


# ============================================================
# The struggle and the hands
# ============================================================

## The struggle: the thing drags her towards the door as the bar drains. It cannot be won; it ends when the bar is empty.
func _run_struggle(generation: int) -> bool:
	_struggling = true
	_strain_time = 0.0
	_crawling = true
	_crawl_phase = 0.0
	_crawl_rate = STRUGGLE_SLOW_RATE
	if not struggle.pressed.is_connected(_on_struggle_pressed):
		struggle.pressed.connect(_on_struggle_pressed)

	struggle.begin()
	await struggle.failed
	_struggling = false
	return generation == _run


## Every press makes her crawl harder, and that is all: her crawl (see `_rig_tick`) speeds up smoothly, and between presses it slows
## again as the thing hauls her back: slow pull, quick lunge, like a tug of war, without the view ever being kicked.
func _on_struggle_pressed(_progress: float) -> void:
	_effort = minf(_effort + 0.45, 1.5)
	_strain_time = 0.0


## While the struggle lasts she slides towards the black door as the bar drains, and back as it fills.
func _drag(delta: float) -> void:
	if not _struggling:
		return

	var wanted: float = _fall_z + (1.0 - struggle.progress) * DRAG_DISTANCE
	var local: Vector3 = wagon.to_local(_player.global_position)
	var next: float = move_toward(local.z, wanted, 2.4 * delta)
	_player.global_position = wagon.to_global(Vector3(local.x, local.y, next))


## The bar is empty: she is pulled BACK, towards the door, by the legs (the body goes back and the view is thrown back and up), and the
## hands are on her face before she has gone far; all in well under a second, so as not to break the rhythm of the scene.
func _ending(generation: int) -> void:
	_trauma = 0.5
	var local: Vector3 = wagon.to_local(_player.global_position)
	var haul: Tween = _new_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	haul.tween_method(func(z: float) -> void: _player.global_position = wagon.to_global(Vector3(local.x, local.y, z)), local.z, local.z + 1.4, 0.4)
	haul.tween_property(self, "_pose_pitch", _pose_pitch + 24.0, 0.4)
	haul.tween_property(self, "_pose_roll", -12.0, 0.4)
	haul.tween_property(self, "_pose_z", 0.5, 0.4)
	haul.tween_property(self, "_stroke_gain", 0.3, 0.4)
	await get_tree().create_timer(0.16).timeout
	if generation != _run:
		return

	# Two hands slap onto her face from the sides of the view (a quarter of a second).
	_grabbing = true
	_set_blur(true)
	_torch.set("scripted_aim_on", false)
	creature.play_grab(_camera_in_wagon(), GRAB_SECONDS)
	await creature.grab_done
	if generation != _run:
		_grabbing = false
		return

	# Hardly a beat on her face: the host turns it black.
	await get_tree().create_timer(0.05).timeout


## Things this close to the eyes are out of focus: the camera's near blur is switched on while the hands are on her face.
func _set_blur(on: bool) -> void:
	if _camera == null:
		return

	var attributes: CameraAttributesPractical = _camera.attributes as CameraAttributesPractical
	if attributes == null:
		return

	attributes.dof_blur_near_enabled = on
	if on:
		attributes.dof_blur_near_distance = 0.7
		attributes.dof_blur_near_transition = 0.6
		attributes.dof_blur_amount = 0.25


## The sting of the head: the one sound of the scene (besides the player's own footsteps).
func _play_sting(stream: AudioStream, volume_db: float) -> void:
	var sound: AudioStreamPlayer = AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = volume_db
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
