extends Node

## The unfinished house's escape, apart from the long directed scene (which `unfinished_house_smoke_test` plays through): the doorway that replaces a wall
## (pictures and collision together, the door swinging into the bedroom, room for a player's body), the states a game can be loaded in (an older game that
## never went through the escape, a game saved after it and before Lucas's token, the token owned, collected or in the payphone, the watcher noticed), the two
## outside exits (released by the token's pickup, never re-locked), and the black head in the pantry (a partial shape that goes, with the bulb, when the
## player's view finds it, only from the corridor, only once). Run it as a scene; it quits by itself with a non-zero exit code on failure.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_unfinished_house_escape_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/unfinished_house_playtest.tscn"
const HOUSE_SCENE_PATH: String = "res://scenes/levels/unfinished_house.tscn"

var test_failed: bool = false
var house: UnfinishedHouseSequence = null
var player: CharacterBody3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DoorController.approach_enabled = false
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "house_escape_test_start", "SAVE_LOCATION_DREAM_INTRO")

	var level: Node = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	house = level.get_node("UnfinishedHouse")
	player = level.get_node("Player")

	await _check_the_doorway()
	await _check_restored_states()
	await _check_the_watcher()
	await _check_the_broken_flashlight()

	get_tree().paused = false
	SaveManager.delete_slot(1)
	print("UNFINISHED_HOUSE_ESCAPE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


# ============================================================
# THE DOORWAY
# ============================================================

func _check_the_doorway() -> void:
	var door: DoorController = house.escape_door
	_expect(house.shell != null and not house.shell.escape_doorway_open, "the wall between the kitchen and the bedroom starts solid")
	_expect(door.position.y < -50.0 and not door.visible, "and the new door is kept under the world, unseen, until there is a doorway")
	_expect(_wall_blocks(), "a ray through the wall where the doorway will be meets it")

	house._apply_doorway(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(house.shell.escape_doorway_open and door.visible and absf(door.position.y) < 0.01, "with the doorway made, the picture of the wall changes and the door is in it")
	door.unlock()
	door.close_instantly()
	await get_tree().physics_frame
	_expect(_wall_blocks() or _door_blocks(), "the shut door fills it")
	door.ajar_degrees = house.escape_door_open_degrees
	await _wait(0.4)
	var leaf_mesh: MeshInstance3D = door.find_child("DoorMesh", true, false) as MeshInstance3D
	var leaf: Vector3 = house.to_local(leaf_mesh.global_transform * leaf_mesh.get_aabb().get_center())
	_expect(leaf.x > 4.75, "the door opens into the bedroom, never into the kitchen she goes into (the leaf's middle is at x %.2f z %.2f, open %.0f degrees, the wall at x 4.65)" % [leaf.x, leaf.z, house._door_offset_degrees(door)])
	_expect(not _wall_blocks(), "and nothing is in the opening: the collision of the wall changed with its picture")
	var blocked: Array[String] = _body_blocked_at([Vector3(5.2, 0.0, 2.2), Vector3(4.65, 0.0, 2.32), Vector3(3.9, 0.0, 2.45), Vector3(3.35, 0.0, 2.9)])
	_expect(blocked.is_empty(), "a player's whole body fits the whole way through, with the door open (blocked by: %s)" % str(blocked))
	var walked: Array[Vector3] = []
	for leg: int in range(house.escape_path.size() - 1):
		var from: Vector3 = house.escape_path[leg]
		var to: Vector3 = house.escape_path[leg + 1]
		for step: int in range(int(from.distance_to(to) / 0.1) + 1):
			walked.append(from.lerp(to, float(step) * 0.1 / maxf(from.distance_to(to), 0.1)))
	var walk_blocked: Array[String] = _body_blocked_at(walked)
	_expect(walk_blocked.is_empty(), "and her whole walk, every 0.1 m of it from the bedroom, is clear of the open leaf (%d points, blocked by: %s)" % [walked.size(), str(walk_blocked)])

	door.ajar_degrees = 0.0
	door.close_instantly()
	door.lock()
	house._apply_doorway(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(not house.shell.escape_doorway_open and _wall_blocks() and door.position.y < -50.0, "and it can be put back: the wall solid again")
	door.unlock()


## True when a ray along the doorway's line (house local, at hip height, from the bedroom side to the kitchen side) is stopped by something solid.
func _wall_blocks() -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(house.to_global(Vector3(5.6, 1.0, 2.32)), house.to_global(Vector3(3.8, 1.0, 2.32)))
	query.exclude = [player.get_rid()]
	var hit: Dictionary = house.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and not str((hit["collider"] as Node).get_path()).contains("EscapeDoor")


func _door_blocks() -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(house.to_global(Vector3(5.6, 1.0, 2.32)), house.to_global(Vector3(3.8, 1.0, 2.32)))
	query.exclude = [player.get_rid()]
	var hit: Dictionary = house.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


## The names of what stops a capsule the size of the player at each of the points (house local, on the floor).
func _body_blocked_at(points: Array[Vector3]) -> Array[String]:
	var blocked: Array[String] = []
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	var body_shape: CollisionShape3D = player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = body_shape.shape as CapsuleShape3D
	shape.radius = capsule.radius * body_shape.global_basis.get_scale().x
	shape.height = capsule.height * body_shape.global_basis.get_scale().y
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.exclude = [player.get_rid()]
	for point: Vector3 in points:
		query.transform = Transform3D(Basis.IDENTITY, house.to_global(point + Vector3(0.0, shape.height * 0.5 + 0.03, 0.0)))
		for info: Dictionary in house.get_world_3d().direct_space_state.intersect_shape(query, 8):
			var hit: Node = info.get("collider") as Node
			if hit != null:
				blocked.append("%s at %s" % [hit.name, str(point)])
	return blocked


# ============================================================
# THE STATES A GAME IS LOADED IN
# ============================================================

func _check_restored_states() -> void:
	# An older game: the bedroom scene done, the escape never played. Nothing of it is applied, and nothing is locked.
	_clear_state()
	_mark(&"house_migrated", true)
	_mark(&"house_recipe_done", true)
	_mark(&"house_bedroom_memory_done", true)
	var old: UnfinishedHouseSequence = await _spawn()
	_expect(not old.shell.escape_doorway_open and old.escape_door.position.y < -50.0, "an older game keeps its wall: no doorway is made round a player who may be in the bedroom")
	_expect(not old.back_door.is_locked and not old.front_door.is_locked and not old.watcher.is_peeking, "nothing is locked and nobody watches")
	_expect(not old.is_pantry_lamp_on() and old.capsule.story_unlocked, "its pantry bulb stays out, as it always did, and its capsule is unlocked")
	old.queue_free()
	await get_tree().process_frame

	# Saved after the escape, before Lucas's token: the doorway is there, the door shut and locked, the exits shut (left open before) and locked.
	_clear_state()
	_mark(&"house_migrated", true)
	_mark(&"house_recipe_done", true)
	_mark(&"house_bedroom_memory_done", true)
	_mark(&"house_escape_done", true)
	_mark(&"house_exits_locked", true)
	SaveManager.set_state_value(&"doors", &"house_front_door", {"is_locked": false, "is_open": true, "signed_open_angle_degrees": 85.0})
	var fresh: UnfinishedHouseSequence = await _spawn()
	_expect(fresh.shell.escape_doorway_open and absf(fresh.escape_door.position.y) < 0.01 and fresh.escape_door.is_locked and not fresh.escape_door.is_open, "after the escape the doorway is there, its door shut and locked")
	_expect(fresh.back_door.is_locked and fresh.front_door.is_locked and not fresh.front_door.is_open, "both outside exits are shut and locked (the front door was left open)")
	_expect(fresh.is_pantry_lamp_on() and fresh.watcher.is_peeking, "the pantry's bulb is on and the head is looking round the frame")
	_expect(fresh.capsule.story_unlocked and not fresh.capsule.is_open, "the capsule is unlocked, shut, with its token still inside")
	_set_collectible(&"lucas_ficha", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(not fresh.back_door.is_locked and not fresh.front_door.is_locked and not _flag(&"house_exits_locked"), "the moment the token is collected both exits are released (nothing else is waited for)")
	_expect(fresh.escape_door.is_locked, "the new door stays locked")
	fresh.queue_free()
	await get_tree().process_frame

	# The token already taken (or in the payphone) with the exits still marked locked: they are freed at once and never locked again.
	for how: String in ["collected", "payphone"]:
		_clear_state()
		_mark(&"house_migrated", true)
		_mark(&"house_recipe_done", true)
		_mark(&"house_bedroom_memory_done", true)
		_mark(&"house_escape_done", true)
		_mark(&"house_exits_locked", true)
		if how == "collected":
			_set_collectible(&"lucas_ficha", true)
		else:
			SaveManager.set_state_value(&"puzzles", &"orelhao_fichas", ["lucas_ficha"])
		var taken: UnfinishedHouseSequence = await _spawn()
		_expect(not taken.back_door.is_locked and not taken.front_door.is_locked and not _flag(&"house_exits_locked"), "token %s: the exits are usable and the mark is cleared" % how)
		taken._lock_exits()
		_expect(not taken.back_door.is_locked and not taken.front_door.is_locked, "token %s: nothing locks them again" % how)
		taken.queue_free()
		await get_tree().process_frame
	SaveManager.set_state_value(&"puzzles", &"orelhao_fichas", [])

	# The head already noticed: no head, the bulb out, and the door stays as the player left it.
	_clear_state()
	_mark(&"house_migrated", true)
	_mark(&"house_recipe_done", true)
	_mark(&"house_bedroom_memory_done", true)
	_mark(&"house_escape_done", true)
	_mark(&"house_watcher_done", true)
	var seen: UnfinishedHouseSequence = await _spawn()
	_expect(not seen.watcher.is_peeking and not seen.is_pantry_lamp_on(), "a head that was noticed does not come back after a reload, and the bulb is out")
	_expect(seen.living_light != null, "(the living room's light is its own)")
	seen.queue_free()
	await get_tree().process_frame
	SaveManager.set_state_value(&"collectibles", &"lucas_ficha", false)


# ============================================================
# THE WATCHER
# ============================================================

func _check_the_watcher() -> void:
	_clear_state()
	_mark(&"house_migrated", true)
	_mark(&"house_recipe_done", true)
	_mark(&"house_bedroom_memory_done", true)
	_mark(&"house_escape_done", true)
	house._escape_done = true
	house._watcher_done = false
	house._recipe_done = true
	# (With Lucas's token in hand: the flashlight works. It is broken only until the token, see `_check_the_broken_flashlight`.)
	SaveManager.set_state_value(&"collectibles", &"lucas_ficha", true)
	house._sync_flashlight_failure(0.0, true)
	house._set_pantry_lamp(true, false)
	house._set_living_light(true, 0.0)
	house.pantry_door.unlock()
	house.pantry_door.force_open(0.0, 55.0)
	house._arm_watcher()
	await get_tree().physics_frame
	var head: Vector3 = house.watcher.head_point()
	_expect(house.watcher.is_peeking and house.watcher.visible, "the head looks round the pantry's frame")
	_expect(house.watcher.get_node("Lean/Model").get_child_count() > 0 and house.watcher.find_children("*", "MeshInstance3D", true, false).size() >= 2, "it is the project's humanoid model (and a disc over the cut at the neck)")
	var body: MeshInstance3D = house.watcher.get_node("Lean/Model/Skeleton3D/Body") as MeshInstance3D
	var shader_material: ShaderMaterial = body.material_override as ShaderMaterial
	_expect(shader_material != null and shader_material.shader.code.contains("ALBEDO = vec3(0.0)") and not shader_material.shader.code.contains("EMISSION"), "drawn completely black, unlit, with no emission, and cut off under the jaw: only the head and a shoulder can show")

	# Not noticed: from the kitchen (a wall between), from the corridor looking away, with the view held, with a panel open.
	(player.get("flashlight_controller") as Node).set("flashlight_on", true)
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var movement: PlayerMovementController = player.movement_controller
	_stand_at(Vector3(3.4, 0.1, 2.9), head)
	await _wait(1.4)
	_expect(not house._watcher_done and house.watcher.is_peeking, "not from the kitchen, wherever the player looks")
	_stand_at(Vector3(6.0, 0.1, 7.35), head)
	movement.look_yaw += 150.0
	await _wait(1.4)
	_expect(not house._watcher_done, "not from the corridor looking the other way")
	_stand_at(Vector3(6.0, 0.1, 7.35), head)
	player.set_view_locked(true)
	await _wait(1.4)
	_expect(not house._watcher_done, "not while the view is held (a scene is playing)")
	player.set_view_locked(false)
	player.modal_ui_open = true
	await _wait(1.4)
	_expect(not house._watcher_done, "nor with a panel open")
	player.modal_ui_open = false

	# Noticed: from the corridor, the view on it.
	var light: Node = player.get("flashlight_controller") as Node
	light.set("flashlight_on", false)
	_stand_at(Vector3(5.2, 0.1, 7.35), head)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lamp_before: float = house.pantry_light.light_energy
	var living_before: float = house.living_light.light_energy
	await _wait(1.0)
	_expect(not house._watcher_done and house.watcher.visible and house.is_pantry_lamp_on(), "looking straight at it with the flashlight off finds nothing: it waits there, the lamp on")
	light.set("flashlight_on", true)
	await _until(func() -> bool: return house._watcher_done, "the flashlight pointed down the corridor at it is what finds it", 6.0)
	await _wait(0.4)
	_expect(house.watcher.visible and house.watcher.is_peeking, "it takes its time to go: a moment later it is still there, going")
	await _until(func() -> bool: return not house.watcher.visible, "and it goes back into the room, in about a second", 3.0)
	_expect(not house.watcher.visible and not house.watcher.is_peeking, "and is hidden")
	await _wait(0.3)
	_expect(not house.is_pantry_lamp_on() and lamp_before > 0.5, "the pantry's bulb goes out with it")
	_expect(house.living_light.visible and absf(house.living_light.light_energy - living_before) < 0.01, "and the living room's light stays on")
	_expect(_flag(&"house_watcher_done"), "the head is remembered as seen")
	house._arm_watcher()
	_expect(not house.watcher.is_peeking, "it does not look again")
	_expect(not bool(player.get("view_locked")) and not bool(player.get("cutscene_frozen")) and camera.fov == camera.fov, "the player was never taken out of control")


## After the escape and until Lucas's token the flashlight is broken (no light, the key does nothing, and the shadow is found by her eyes alone); with the token
## it works again, with its usual start-up flicker.
func _check_the_broken_flashlight() -> void:
	_clear_state()
	_mark(&"house_migrated", true)
	_mark(&"house_recipe_done", true)
	_mark(&"house_bedroom_memory_done", true)
	_mark(&"house_escape_done", true)
	house._escape_done = true
	house._watcher_done = false
	house._recipe_done = true
	house.pantry_door.unlock()
	house.pantry_door.force_open(0.0, 55.0)
	house._set_pantry_lamp(true, false)
	var light: Node = player.get("flashlight_controller") as Node
	light.set("flashlight_on", true)
	light.call("set_failed", false)
	house._sync_flashlight_failure(0.0, true)
	await get_tree().physics_frame
	_expect(bool(light.get("failed")) and not (light as Node3D).visible, "after the escape the flashlight is broken: no light")
	_expect(not bool(light.call("_can_toggle_flashlight")), "and its key does nothing")
	await _wait(0.3)
	_expect(not (light as Node3D).visible and bool(light.get("flashlight_on")), "it stays dark (its switch was left on)")

	# Her eyes alone find the shadow while it is broken.
	house._arm_watcher()
	await get_tree().physics_frame
	var head: Vector3 = house.watcher.head_point()
	_stand_at(Vector3(5.2, 0.1, 7.35), head)
	await _until(func() -> bool: return house._watcher_done, "looking at the shadow, with a dead flashlight, is enough to find it", 6.0)
	await _until(func() -> bool: return not house.watcher.visible, "and it goes", 3.0)

	# The token is taken: it works again.
	SaveManager.set_state_value(&"collectibles", &"lucas_ficha", true)
	await _until(func() -> bool: return not bool(light.get("failed")), "taking Lucas's token mends the flashlight", 3.0)
	await _wait(1.4)
	_expect(bool(light.call("_can_toggle_flashlight")) and (light as Node3D).visible, "and it lights again, as before")
	SaveManager.set_state_value(&"collectibles", &"lucas_ficha", false)


## The player put at `spot` (house local) looking at `point` (world).
func _stand_at(spot: Vector3, point: Vector3) -> void:
	player.global_position = house.to_global(spot)
	player.velocity = Vector3.ZERO
	var movement: PlayerMovementController = player.movement_controller
	var eye: Vector3 = movement.camera.global_position
	movement.look_yaw = rad_to_deg(atan2(point.x - eye.x, -(point.z - eye.z)))
	movement.look_pitch = rad_to_deg(atan2(-(point.y - eye.y), Vector2(point.x - eye.x, point.z - eye.z).length()))


# ============================================================
# HELPERS
# ============================================================

func _spawn() -> UnfinishedHouseSequence:
	var copy: UnfinishedHouseSequence = (load(HOUSE_SCENE_PATH) as PackedScene).instantiate() as UnfinishedHouseSequence
	# Far from the player, so that nothing in it reacts to them.
	copy.position = Vector3(0.0, -200.0, 0.0)
	add_child(copy)
	await get_tree().process_frame
	await get_tree().process_frame
	return copy


func _clear_state() -> void:
	for key: StringName in [&"house_recipe_done", &"house_pantry_closed_on_entry", &"house_argument_active", &"house_bedroom_memory_done", &"house_migrated", &"house_ficha_taken", &"time_capsule_open", &"house_escape_done", &"house_exits_locked", &"house_watcher_done"]:
		SaveManager.set_state_value(&"puzzles", key, false)
	SaveManager.set_state_value(&"collectibles", &"lucas_ficha", false)
	SaveManager.set_state_value(&"puzzles", &"orelhao_fichas", [])
	for door: StringName in [&"house_front_door", &"house_back_door", &"house_pantry_door", &"house_bedroom_door", &"house_escape_door"]:
		SaveManager.set_state_value(&"doors", door, {})


func _mark(key: StringName, value: bool) -> void:
	SaveManager.set_state_value(&"puzzles", key, value)


func _set_collectible(key: StringName, value: bool) -> void:
	SaveManager.set_state_value(&"collectibles", key, value)


func _flag(key: StringName) -> bool:
	return bool(SaveManager.get_state_value(&"puzzles", key, false))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _until(condition: Callable, what: String, timeout_seconds: float = 10.0) -> void:
	var waited: float = 0.0
	while not condition.call() and waited < timeout_seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()

	_expect(condition.call(), what)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
