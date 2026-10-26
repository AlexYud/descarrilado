extends Node

## Doors played the way AAA exploration and horror games play them: the player is walked to the
## handle, leans in, the handle turns and the door swings once, calmly, AWAY from the player; the
## player's feet are held until the door has all but finished; closing first walks the player where the
## leaf will not sweep. A locked door is tried, and a key is turned in a lock. Run it as a scene; it
## quits by itself with a non-zero exit code on failure.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_door_animation_smoke"
const TEST_SCENE_PATH: String = "res://tests/door_animation_smoke_test.tscn"
const DOOR_SCENE: String = "res://scenes/objects/unfinished_house/house_door.tscn"

var test_failed: bool = false
var player: CharacterBody3D = null
var opened_count: int = 0


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "door_test_start", "SAVE_LOCATION_DREAM_INTRO")

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0.8, 0.1, 1.2)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# The player walks up to a door before pushing it; the timed checks below start from the player
	# already standing at it, and the walking has its own checks.
	DoorController.approach_enabled = false
	await _check_open_and_close()
	await _check_handle_sound()
	await _check_locked_door()
	await _check_unlocking_with_the_key()
	await _check_variety()
	await _check_opens_away()
	await _check_approach()
	await _check_closing_clear_of_the_leaf()
	await _check_gate()

	print("DOOR_ANIMATION_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _make_door(at: Vector3, locked: bool = false, key_id: String = "") -> DoorController:
	var door: DoorController = (load(DOOR_SCENE) as PackedScene).instantiate()
	door.starts_locked = locked
	door.required_key_id = key_id
	door.position = at
	add_child(door)
	return door


func _swing_degrees(door: DoorController) -> float:
	return absf(door.hinge.rotation_degrees.y - door.closed_rotation_degrees.y)


func _lever_angle(door: DoorController) -> float:
	var angle: float = 0.0
	for hardware: Node in door.find_children("Hardware*", "", true, false):
		var lever: Node3D = hardware.get_node_or_null("Lever") as Node3D
		if lever != null:
			angle = maxf(angle, absf(lever.rotation.z))

	return angle


func _held() -> bool:
	return player.get("_movement_hold_until_msec") > Time.get_ticks_msec()


func _check_open_and_close() -> void:
	var door: DoorController = _make_door(Vector3.ZERO)
	door.open_variant_override = &"standard"
	opened_count = 0
	door.opened_by_player.connect(func() -> void: opened_count += 1)
	await get_tree().physics_frame

	var hardware_count: int = door.find_children("Hardware*", "", true, false).size()
	_expect(hardware_count == 2, "the door has a handle and keyhole on each face")

	player.global_position = Vector3(0.8, 0.1, 1.2)
	door.interact(player)
	_expect(door.is_open, "the door is open the moment the player opens it")
	_expect(_swing_degrees(door) < 0.5, "but it has not moved yet")
	_expect(door.is_busy(), "the player's hands are on it")

	await _wait(0.3)
	_expect(_lever_angle(door) > 0.4, "the handle is pressed down")
	var movement: PlayerMovementController = player.movement_controller
	_expect(movement.gesture_offset.length() > 0.02, "the view leans in towards the door")
	_expect(_held(), "the player's feet are held while their hands are busy")

	# One smooth swing: the door moves without stopping half way or going back.
	var plan: Dictionary = door._plan
	var open_start: float = float(plan["open_start"])
	var main_end: float = float(plan["main_end"])
	var previous: float = _swing_degrees(door)
	var went_back: bool = false
	var stalled: int = 0
	var held_mid: bool = false
	var elapsed: float = 0.3
	while elapsed < main_end - 0.02:
		await _wait(0.1)
		elapsed += 0.1
		var now: float = _swing_degrees(door)
		if now < previous - 1.5:
			went_back = true
		if elapsed > open_start + 0.5 and elapsed < main_end - 0.5 and now - previous < 0.3:
			stalled += 1
		if absf(elapsed - (open_start + main_end) * 0.5) < 0.06:
			held_mid = _held()
		previous = now

	_expect(not went_back and stalled == 0, "the door never stops or goes back half way (%d stalls)" % stalled)
	_expect(main_end - open_start >= 1.7, "and it swings calmly (%.1f s)" % (main_end - open_start))
	_expect(opened_count == 1, "the door counts as opened once it swings")
	_expect(held_mid, "the player's feet stay held while it swings, so nobody walks into the leaf")
	_expect(door._door_bodies.size() > 0 and door._door_bodies[0].collision_layer == 0 or door._choreo == &"", "the swinging door lets the player through instead of dragging them")

	await _wait(0.9)
	_expect(is_equal_approx(_swing_degrees(door), 85.0), "the door ends wide open")
	_expect(_lever_angle(door) < 0.01, "the handle is back at rest")
	_expect(door._door_bodies[0].collision_layer != 0, "and the door is solid again")
	_expect(movement.gesture_offset.length() < 0.001, "the view is let go")
	_expect(not door.is_busy(), "the door is free again")

	# Closing it again: a pull and the latch.
	door.interact(player)
	_expect(not door.is_open, "the door is closed the moment the player closes it")
	await _wait(1.0)
	var halfway: float = _swing_degrees(door)
	_expect(halfway > 5.0 and halfway < 84.0, "it swings shut (%.1f)" % halfway)
	await _until_still(door)
	_expect(_swing_degrees(door) < 0.01, "the door ends shut")
	_expect(_lever_angle(door) < 0.01, "and the handle is at rest")

	door.queue_free()
	await get_tree().physics_frame


## The handle turning: a real recording plays, positioned at the handle, the moment it starts to move (not
## before, not when the door is only being approached); one of the two clips is picked, and over many tries
## both are heard; closing the door plays none of it; the fence gate has it switched off.
func _check_handle_sound() -> void:
	var door: DoorController = _make_door(Vector3(2.0, 0.0, 0.0))
	door.open_variant_override = &"standard"
	await get_tree().physics_frame

	_expect(door.handle_sound_enabled, "an ordinary door has the handle sound on")
	_expect(door.handle_sound_a != null and door.handle_sound_b != null and door.handle_sound_a != door.handle_sound_b, "with two different recordings to pick from")

	player.global_position = Vector3(2.8, 0.1, 1.2)
	door.interact(player)
	_expect(door.find_children("*", "AudioStreamPlayer3D", false, false).is_empty(), "nothing sounds the instant the door is opened")

	await _wait(0.3)
	var sounds: Array = door.find_children("*", "AudioStreamPlayer3D", false, false)
	_expect(sounds.size() == 1, "the handle sounds once it starts to move (%d sounds)" % sounds.size())
	if not sounds.is_empty():
		var sound: AudioStreamPlayer3D = sounds[0] as AudioStreamPlayer3D
		_expect(sound.stream == door.handle_sound_a or sound.stream == door.handle_sound_b, "one of the two recordings")
		_expect(sound.playing, "and it plays")
		var at_handle: float = sound.global_position.distance_to(door._sound_position())
		_expect(at_handle < 0.3, "from the handle, where the hand is (%.2f m off)" % at_handle)

	await _wait(0.9)
	_expect(door.find_children("*", "AudioStreamPlayer3D", false, false).size() == 1, "opening wide makes no second sound")

	# Closing: no handle sound (the pull and the latch are a different sound, not this one).
	door.interact(player)
	await _until_still(door)
	_expect(door.find_children("*", "AudioStreamPlayer3D", false, false).filter(func(s: Node) -> bool: return (s as AudioStreamPlayer3D).playing).is_empty(), "closing the door plays no handle sound")

	# Opened many times, both recordings turn up (the pick is random, not fixed).
	var heard: Dictionary = {}
	for i: int in 24:
		for sound: Node in door.find_children("*", "AudioStreamPlayer3D", false, false):
			sound.queue_free()
		await get_tree().process_frame
		door._play_handle_sound(door._sound_position())
		for sound: Node in door.find_children("*", "AudioStreamPlayer3D", false, false):
			heard[(sound as AudioStreamPlayer3D).stream] = true

	_expect(heard.size() == 2, "over 24 tries both recordings are heard (%d)" % heard.size())

	door.queue_free()
	await get_tree().physics_frame

	# The wooden fence gate: a drop-bar, not a handle, so it stays quiet.
	var gate: DoorController = (
		load("res://scenes/objects/fence_door_interactable.tscn") as PackedScene
	).instantiate()
	gate.position = Vector3(2.0, 0.0, 10.0)
	gate.open_variant_override = &"standard"
	add_child(gate)
	await get_tree().physics_frame
	_expect(not gate.handle_sound_enabled, "the fence gate has the handle sound switched off")

	player.global_position = Vector3(2.8, 0.1, 10.0 + gate.approach_handle_fraction)
	gate.interact(player)
	await _wait(0.5)
	_expect(gate.find_children("*", "AudioStreamPlayer3D", false, false).is_empty(), "and opening it makes none of this sound")

	gate.queue_free()
	await get_tree().physics_frame


func _check_locked_door() -> void:
	var door: DoorController = _make_door(Vector3(5.0, 0.0, 0.0), true, "no_such_key")
	await get_tree().physics_frame
	player.global_position = Vector3(5.8, 0.1, 1.2)

	door.interact(player)
	_expect(door.is_locked and not door.is_open, "a locked door stays locked and shut")

	var shaken: float = 0.0
	var pressed: float = 0.0
	for i: int in 30:
		await get_tree().process_frame
		shaken = maxf(shaken, _swing_degrees(door))
		pressed = maxf(pressed, _lever_angle(door))
	_expect(shaken > 0.1 and shaken < 2.0, "the door rattles in its frame (%.2f)" % shaken)
	_expect(pressed > 0.4, "the handle is tried")

	await _wait(1.5)
	_expect(_swing_degrees(door) < 0.01 and _lever_angle(door) < 0.01, "then everything is still")
	_expect(not _any_key_shown(door), "no key appears without one")

	door.queue_free()
	await get_tree().physics_frame


func _check_unlocking_with_the_key() -> void:
	var door: DoorController = _make_door(Vector3(10.0, 0.0, 0.0), true, "test_key")
	await get_tree().physics_frame
	player.global_position = Vector3(10.8, 0.1, 1.2)
	player.add_item_to_inventory("test_key", "Test key", "A key")
	_expect(player.has_inventory_item("test_key"), "the player holds the key")

	door.interact(player)
	_expect(not door.is_locked and door.is_open, "the key unlocks and opens the door at once")
	_expect(not player.has_inventory_item("test_key"), "the key is used up")

	await _wait(0.9)
	_expect(_any_key_shown(door), "the key shows at the keyhole")
	_expect(_swing_degrees(door) < 0.5, "the door stays shut while the key goes in")

	var key_plan: Dictionary = door._key_plan
	await _wait(float(key_plan["turn_start"]) + float(key_plan["turn"]) * 0.7 - 0.9)
	var turned: float = _key_twist(door)
	_expect(absf(turned) > 10.0 and absf(turned) < 90.0, "the key is turning in the lock (%.0f)" % turned)
	_expect(_swing_degrees(door) < 0.5, "and the door still waits")

	await _until_still(door)
	_expect(is_equal_approx(_swing_degrees(door), 85.0), "the door ends wide open")
	_expect(is_equal_approx(_key_twist(door), -90.0), "the key stays in the lock, turned a quarter")

	door.queue_free()
	await get_tree().physics_frame


func _any_key_shown(door: DoorController) -> bool:
	for hardware: Node in door.find_children("Hardware*", "", true, false):
		if hardware is DoorHardware and (hardware as DoorHardware).is_key_shown():
			return true

	return false


func _key_twist(door: DoorController) -> float:
	for hardware: Node in door.find_children("Hardware*", "", true, false):
		var turn: Node3D = hardware.find_child("KeyTurn", true, false) as Node3D
		if turn != null and turn.visible:
			return rad_to_deg(turn.rotation.z)

	return 0.0


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


func _until_still(door: DoorController) -> void:
	var waited: float = 0.0
	await get_tree().process_frame
	while door._choreo != &"" and waited < 20.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


## No two interactions are alike: the plans differ, both variants play through, and the same
## variant is not served twice in a row if it can be helped. Every opening is a single swing.
func _check_variety() -> void:
	var door: DoorController = _make_door(Vector3(15.0, 0.0, 0.0))
	await get_tree().physics_frame

	var names: Dictionary = {}
	var ends: Array[float] = []
	var repeats: int = 0
	var last: StringName = &""
	var all_single_swings: bool = true
	for i: int in 120:
		var plan: Dictionary = door._plan_open()
		names[plan["variant"]] = true
		ends.append(float(plan["main_end"]))
		all_single_swings = all_single_swings and (plan["stretches"] as Array).size() == 2
		if plan["variant"] == last:
			repeats += 1
		last = plan["variant"]

	_expect(names.size() == 2, "both ways of opening come up (%s)" % str(names.keys()))
	_expect(all_single_swings, "and each is one swing, with no crack and no pause")
	_expect(ends.max() - ends.min() > 0.4, "their lengths differ (%.1f..%.1f)" % [ends.min(), ends.max()])
	_expect(repeats < 60, "the same way is rarely seen twice in a row (%d of 120)" % repeats)

	var close_names: Dictionary = {}
	var try_counts: Dictionary = {}
	for i: int in 60:
		close_names[door._plan_close()["variant"]] = true
		try_counts[(door._plan_locked()["tries"] as Array).size()] = true
	_expect(close_names.size() == 3, "all three ways of closing come up")
	_expect(try_counts.size() == 2, "a locked door is tried two or three times")

	# Both variants play through to the same end.
	Engine.time_scale = 4.0
	for variant: StringName in [&"standard", &"quick"]:
		door.open_variant_override = variant
		opened_count = 0
		var counter: Callable = func() -> void: opened_count += 1
		door.opened_by_player.connect(counter)
		player.global_position = Vector3(15.8, 0.1, 1.2)

		door.interact(player)
		await _until_still(door)
		_expect(is_equal_approx(_swing_degrees(door), 85.0), "%s ends wide open" % variant)
		_expect(opened_count == 1, "%s counts as opened once" % variant)
		_expect(_lever_angle(door) < 0.01, "%s lets go of the handle" % variant)

		door.interact(player)
		await _until_still(door)
		_expect(_swing_degrees(door) < 0.01, "%s: the door closes again" % variant)
		door.opened_by_player.disconnect(counter)

	Engine.time_scale = 1.0
	door.queue_free()
	await get_tree().physics_frame


## The door opens AWAY from whoever opens it, from either side, and closes by the same swing.
func _check_opens_away() -> void:
	var door: DoorController = _make_door(Vector3(80.0, 0.0, 0.0))
	await get_tree().physics_frame
	Engine.time_scale = 4.0

	for z: float in [1.2, -1.2, 1.2]:
		player.global_position = Vector3(80.8, 0.1, z)
		door.interact(player)
		await _until_still(door)
		var swung: float = door.hinge.rotation_degrees.y - door.closed_rotation_degrees.y
		# Positive turns the leaf towards -Z: away from a player in front (z > 0).
		var away: float = 85.0 if z > 0.0 else -85.0
		_expect(is_equal_approx(swung, away), "opened from z %.1f the door swings away from the player (%.0f)" % [z, swung])
		door.interact(player)
		await _until_still(door)
		_expect(_swing_degrees(door) < 0.01, "and closes again")

	Engine.time_scale = 1.0
	door.queue_free()
	await get_tree().physics_frame


## Far from the handle, the player first walks up to the door at a slow pace, looking at it, and only
## then does the door start to move.
func _check_approach() -> void:
	DoorController.approach_enabled = true
	Engine.time_scale = 1.0
	var movement: PlayerMovementController = player.movement_controller

	var door: DoorController = _make_door(Vector3(30.0, 0.0, 0.0))
	await get_tree().physics_frame
	player.global_position = Vector3(30.81, 1.05, 2.4)
	player.velocity = Vector3.ZERO
	await _wait(0.5)

	door.interact(player)
	_expect(door.is_open, "the door is open the moment the player opens it")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(movement.is_guided_walking(), "the player starts walking to the door")
	_expect(door.is_busy(), "the door waits for them")
	_expect(_swing_degrees(door) < 0.01 and _lever_angle(door) < 0.01, "nothing moves yet")

	await _wait(0.6)
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	_expect(speed > 0.3 and speed < PlayerMovementController.WALK_SPEED, "at a slow walking pace (%.2f)" % speed)

	await _until_walk_ends(movement)
	var reached: Vector2 = Vector2(player.global_position.x - 30.81, player.global_position.z - 0.59)
	_expect(reached.length() < 0.12, "they stop at arm's length in front of the handle (off by %.2f)" % reached.length())

	await _until_still(door)
	_expect(is_equal_approx(_swing_degrees(door), 85.0), "and the door opens as usual")
	_expect(not movement.is_guided_walking(), "the walk is over")

	# Already at the door: no walk.
	var near_door: DoorController = _make_door(Vector3(60.0, 0.0, 0.0))
	await get_tree().physics_frame
	player.global_position = Vector3(60.81, 1.05, 0.62)
	player.velocity = Vector3.ZERO
	await _wait(0.5)
	near_door.interact(player)
	await get_tree().physics_frame
	_expect(not movement.is_guided_walking(), "someone already at the door is not walked")
	await _until_still(near_door)

	DoorController.approach_enabled = false
	door.queue_free()
	near_door.queue_free()
	await get_tree().physics_frame


func _until_walk_ends(movement: PlayerMovementController) -> void:
	var waited: float = 0.0
	while movement.is_guided_walking() and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


## Closing: the player is first walked to a place the leaf will not sweep, on their own side; from the
## doorway, to the side the leaf is not on.
func _check_closing_clear_of_the_leaf() -> void:
	DoorController.approach_enabled = true
	var movement: PlayerMovementController = player.movement_controller
	var door: DoorController = _make_door(Vector3(90.0, 0.0, 0.0))
	await get_tree().physics_frame

	# Opened from the +Z side: the leaf swings away, to the -Z side.
	player.global_position = Vector3(90.81, 0.1, 0.5)
	player.velocity = Vector3.ZERO
	await _wait(0.5)
	door.interact(player)
	await _until_still(door)
	var sweep: float = float(door._frame()["sweep"])
	_expect(sweep < 0.0, "the leaf is on the -Z side")

	# Closing it from the side the leaf is not on: they stay there, in front of the handle.
	player.global_position = Vector3(90.81, 0.1, 1.5)
	player.velocity = Vector3.ZERO
	await _wait(0.5)
	door.interact(player)
	await _until_still(door)
	var coords: Vector2 = door._door_coords(player.global_position)
	_expect(coords.y * sweep < 0.0 and absf(coords.y) < 0.8, "closed from the side the leaf is not on, they end in front of the handle (%.2f)" % coords.y)
	_expect(_swing_degrees(door) < 0.01, "and the door is shut")

	# Open it again, then close it from inside its arc: walked out of the leaf's reach, same side.
	door.interact(player)
	await _until_still(door)
	player.global_position = Vector3(90.5, 0.1, sweep * 0.3)
	player.velocity = Vector3.ZERO
	await _wait(0.5)
	door.interact(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(movement.is_guided_walking(), "a player inside the leaf's arc is walked out of it before the door closes")
	await _until_still(door)
	coords = door._door_coords(player.global_position)
	_expect(coords.y * sweep >= door._clear_depth(coords.x) - 0.15, "they stay on their side, beyond the leaf's reach (%.2f of %.2f)" % [coords.y * sweep, door._clear_depth(coords.x)])
	_expect(_swing_degrees(door) < 0.01, "and the door is shut")

	# From the doorway: put on the side the leaf is not on.
	door.interact(player)
	await _until_still(door)
	# (It was opened from the -Z side this time, so the leaf is on the +Z side now.)
	sweep = float(door._frame()["sweep"])
	player.global_position = Vector3(90.4, 0.1, 0.04)
	player.velocity = Vector3.ZERO
	await _wait(0.5)
	door.interact(player)
	await _until_still(door)
	coords = door._door_coords(player.global_position)
	_expect(coords.y * sweep < -0.3, "a player standing in the doorway ends on the side the leaf is not on (%.2f)" % coords.y)
	_expect(_swing_degrees(door) < 0.01, "and the door is shut")

	DoorController.approach_enabled = false
	door.queue_free()
	await get_tree().physics_frame


## The long fence gate is pushed near its free end, not at its middle, and swings more slowly.
func _check_gate() -> void:
	DoorController.approach_enabled = true
	var gate: DoorController = (
		load("res://scenes/objects/fence_door_interactable.tscn") as PackedScene
	).instantiate()
	gate.position = Vector3(70.0, 0.0, 0.0)
	add_child(gate)
	await get_tree().physics_frame

	_expect(gate.heavy_gate, "the gate is a heavy one")
	player.global_position = Vector3(70.8, 1.05, 3.0)
	player.velocity = Vector3.ZERO
	await _wait(0.5)

	var target: Dictionary = gate._approach_target(player)
	_expect(not target.is_empty(), "a player in front of the gate is walked to it")
	var from_hinge: float = Vector2(
		target["look"].x - gate.hinge.global_position.x,
		target["look"].z - gate.hinge.global_position.z
	).length()
	var half_width: float = Vector2(
		gate.door_root.global_position.x - gate.hinge.global_position.x,
		gate.door_root.global_position.z - gate.hinge.global_position.z
	).length()
	_expect(
		from_hinge > half_width * 1.5,
		"they stand towards its free end (%.2f of a width %.2f)" % [from_hinge, half_width * 2.0]
	)

	gate.open_variant_override = &"standard"
	var open_plan: Dictionary = gate._plan_open()
	_expect(float(open_plan["main_end"]) > 2.4, "and it swings slowly (%.1f s)" % float(open_plan["main_end"]))

	DoorController.approach_enabled = false
	gate.queue_free()
	await get_tree().physics_frame
