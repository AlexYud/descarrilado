extends Node

## Plays doors the way the player meets them: opening (handle, crack, hesitation,
## slow swing), closing, a locked door tried, and a key turned in a lock. The
## state changes at once; the choreography follows. Run it as a scene; it quits by
## itself with a non-zero exit code on failure.

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
	box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0.8, 0.1, 1.2)
	await get_tree().physics_frame
	await get_tree().physics_frame

	await _check_open_and_close()
	await _check_locked_door()
	await _check_unlocking_with_the_key()
	await _check_variety()

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

	# The player leans in and the handle goes down before the door gives.
	await _wait(0.3)
	_expect(_lever_angle(door) > 0.4, "the handle is pressed down")
	var movement: PlayerMovementController = player.movement_controller
	_expect(movement.gesture_offset.length() > 0.02, "the view leans in towards the door")
	_expect(
		player.get("_movement_hold_until_msec") > Time.get_ticks_msec(),
		"the player's feet are held while their hands are busy"
	)

	# It cracks, then hangs there (the plan says when).
	var plan: Dictionary = door._plan
	var stretches: Array = plan["stretches"]
	var hang_at: float = (
		float(plan["reach"]) + float(stretches[1]["d"]) + float(stretches[2]["d"]) * 0.4
	)
	await _wait(hang_at - 0.3)
	var crack: float = _swing_degrees(door)
	_expect(crack > 1.0 and crack < 10.0, "the door gives only a crack first (%.1f)" % crack)
	_expect(opened_count == 0, "nothing counts as opened while it is only ajar")
	await _wait(0.1)
	_expect(absf(_swing_degrees(door) - crack) < 1.0, "it hangs there a moment")

	await _wait(float(plan["open_start"]) + 0.8 - hang_at - 0.1)
	_expect(opened_count == 1, "the door counts as opened once it swings")
	_expect(_swing_degrees(door) > crack + 3.0, "and it swings")

	await _wait(float(plan["main_end"]) + 0.6 - float(plan["open_start"]) - 0.8)
	_expect(is_equal_approx(_swing_degrees(door), 85.0), "the door ends wide open")
	_expect(_lever_angle(door) < 0.01, "the handle is back at rest")
	_expect(movement.gesture_offset.length() < 0.001, "the view is let go")
	_expect(not door.is_busy(), "the door is free again")

	# Closing it again: a quicker pull and the latch.
	door.interact(player)
	_expect(not door.is_open, "the door is closed the moment the player closes it")
	await _wait(0.55)
	var halfway: float = _swing_degrees(door)
	_expect(halfway > 5.0 and halfway < 84.0, "it swings shut (%.1f)" % halfway)
	await _wait(2.5)
	_expect(_swing_degrees(door) < 0.01, "the door ends shut")
	_expect(_lever_angle(door) < 0.01, "and the handle is at rest")

	door.queue_free()
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

	await _wait(1.2)
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


## No two interactions are alike: the plans differ, every variant plays through, and
## the same variant is not served twice in a row if it can be helped.
func _check_variety() -> void:
	var door: DoorController = _make_door(Vector3(15.0, 0.0, 0.0))
	await get_tree().physics_frame

	var names: Dictionary = {}
	var ends: Array[float] = []
	var repeats: int = 0
	var last: StringName = &""
	for i: int in 120:
		var plan: Dictionary = door._plan_open()
		names[plan["variant"]] = true
		ends.append(float(plan["main_end"]))
		if plan["variant"] == last:
			repeats += 1
		last = plan["variant"]

	_expect(names.size() == 4, "all four ways of opening come up (%s)" % str(names.keys()))
	_expect(ends.max() - ends.min() > 2.0, "their lengths differ a lot (%.1f..%.1f)" % [ends.min(), ends.max()])
	_expect(repeats < 30, "the same way is rarely seen twice in a row (%d of 120)" % repeats)

	var close_names: Dictionary = {}
	var try_counts: Dictionary = {}
	for i: int in 60:
		close_names[door._plan_close()["variant"]] = true
		try_counts[(door._plan_locked()["tries"] as Array).size()] = true
	_expect(close_names.size() == 3, "all three ways of closing come up")
	_expect(try_counts.size() == 2, "a locked door is tried two or three times")

	# Every variant plays through to the same end.
	Engine.time_scale = 4.0
	for variant: StringName in [&"standard", &"peek", &"stuck", &"quick"]:
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


func _until_still(door: DoorController) -> void:
	var waited: float = 0.0
	await get_tree().process_frame
	while door._choreo != &"" and waited < 15.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
