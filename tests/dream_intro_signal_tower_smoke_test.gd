extends Node

## The ruined signal tower in the real dream intro: where it stands (on levelled ground, its door towards the
## loop's east leg, the arrow the developer drew on the map), that the player can get from the path to its door
## without meeting the invisible forest walls, that the ground round it is closed by walls, and that the loop's
## east wall is still whole outside the opening. Run it as a scene; it quits by itself with a non-zero exit
## code on failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_dream_tower_smoke"
## Where the trail leaves the loop's east leg.
const PATH_POINT: Vector2 = Vector2(94.5, -36.0)

var test_failed: bool = false
var level: Node = null
var tower: SignalTowerBuilder = null
var terrain: Terrain3D = null
var space: PhysicsDirectSpaceState3D = null


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "dream_tower_start", "SAVE_LOCATION_DREAM_INTRO")

	level = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	for i: int in 6:
		await get_tree().physics_frame
	await get_tree().create_timer(1.0).timeout

	tower = level.get_node_or_null("Scenery/SignalTower") as SignalTowerBuilder
	terrain = level.get_node("Terrain3D") as Terrain3D
	space = (level as Node3D).get_world_3d().direct_space_state
	await _run()

	SaveManager.delete_slot(1)
	print("DREAM_INTRO_SIGNAL_TOWER_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	_expect(tower != null, "the dream intro has the signal tower, under Scenery")
	if tower == null:
		return

	_check_site()
	_check_the_way_in()
	_check_the_walls()
	_check_the_tower_inside()
	await _check_walking()


func _ground(x: float, z: float) -> float:
	return terrain.data.get_height(Vector3(x, 0.0, z))


## Where it stands: east of the loop's east leg (x about 94), in the bowl the arrow on the map points at, on level ground.
func _check_site() -> void:
	var at: Vector3 = tower.global_position
	_expect(at.x > 98.0 and at.x < 105.0 and at.z > -40.0 and at.z < -32.0, "the tower stands in the bowl east of the loop (%s)" % str(at))
	_expect(absf(at.y - _ground(at.x, at.z)) < 0.05, "its foot is on the ground (%.3f against %.3f)" % [at.y, _ground(at.x, at.z)])

	# Its door faces the loop (west), its stairs and balcony are on the south side.
	var door: Node3D = tower.lower_door.get_node("Hinge/DoorRoot")
	_expect(door.global_basis.z.dot(Vector3.LEFT) > 0.99, "its front door faces west, to the loop")
	_expect(tower.upper_door.global_position.z > at.z + 1.5, "and the stairs and the balcony are on the south side")

	# The ground is level under the building, its stairs and its balcony.
	var worst: float = 0.0
	for local: Vector2 in [Vector2(-2.2, -2.2), Vector2(2.2, -2.2), Vector2(2.2, 2.2), Vector2(-2.2, 2.2), Vector2(-0.5, 2.4), Vector2(0.0, 0.0)]:
		var world: Vector3 = tower.to_global(Vector3(local.x, 0.0, local.y))
		worst = maxf(worst, absf(_ground(world.x, world.z) - at.y))
	_expect(worst < 0.2, "the ground is level under it (worst %.2f m off)" % worst)
	var stair_foot: Vector3 = tower.to_global(Vector3(2.75, 0.0, 3.4))
	var balcony_side: Vector3 = tower.to_global(Vector3(3.3, 0.0, -1.2))
	_expect(absf(_ground(stair_foot.x, stair_foot.z) - at.y) < 0.35 and absf(_ground(balcony_side.x, balcony_side.z) - at.y) < 0.6, "and under the foot of the stairs and the balcony (%.2f, %.2f)" % [_ground(stair_foot.x, stair_foot.z) - at.y, _ground(balcony_side.x, balcony_side.z) - at.y])
	var path_height: float = _ground(PATH_POINT.x, PATH_POINT.y)
	_expect(absf(path_height - at.y) < 1.2, "level with the path it leaves (%.2f m apart)" % (path_height - at.y))


## A capsule the size of the player's, walked from the loop to the door, meets no invisible wall.
func _check_the_way_in() -> void:
	var door_front: Vector3 = tower.lower_door.get_node("Hinge/DoorRoot").global_position + Vector3.LEFT * 1.0
	var from_point: Vector3 = Vector3(PATH_POINT.x, 0.0, PATH_POINT.y)
	var to_point: Vector3 = Vector3(door_front.x, 0.0, door_front.z)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	var blocked: Array[String] = []
	var steps: int = 40
	for i: int in steps + 1:
		var spot: Vector3 = from_point.lerp(to_point, float(i) / float(steps))
		spot.y = _ground(spot.x, spot.z) + 0.95
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, spot)
		for hit: Dictionary in space.intersect_shape(query, 8):
			var collider: Node = hit["collider"] as Node
			if collider != null and _is_wall(collider):
				blocked.append("%s at %s" % [collider.get_path(), str(spot)])

	_expect(blocked.is_empty(), "a player sized capsule walks from the loop to the tower's door without meeting a wall (%s)" % str(blocked.slice(0, 2)))
	_expect(from_point.distance_to(to_point) < 9.0, "a short way: %.1f m" % from_point.distance_to(to_point))


func _is_wall(node: Node) -> bool:
	return str(node.get_path()).contains("ForestBoundar")


## Walls close the ground round the tower, and the loop's east wall is whole except where the trail goes through.
func _check_the_walls() -> void:
	var middle: Vector3 = tower.global_position + Vector3(-0.6, 1.0, 0.7)
	var open_rays: int = 0
	var shortest: float = INF
	for i: int in 72:
		var angle: float = TAU * float(i) / 72.0
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(middle, middle + direction * 16.0)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			open_rays += 1
		else:
			shortest = minf(shortest, middle.distance_to(hit["position"] as Vector3))
	_expect(open_rays == 0, "every direction from the tower meets a wall or the tower within 16 m (%d open)" % open_rays)

	# The loop's east wall, ray after ray from the path's middle eastwards: something stops each one.
	var open_z: Array[float] = []
	for z: int in range(-50, -21):
		var from_point: Vector3 = Vector3(94.0, _ground(94.0, float(z)) + 1.5, float(z))
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_point, from_point + Vector3(24.0, 0.0, 0.0))
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			open_z.append(float(z))
	_expect(open_z.is_empty(), "the loop's east side is walled from z -50 to -22 (open at %s)" % str(open_z))

	# And the loop's own corridor is still there: its west wall, the path itself stays open.
	var corridor_open: int = 0
	for z: int in range(-50, -21, 4):
		var centre: Vector3 = Vector3(93.5, _ground(93.5, float(z)) + 1.5, float(z))
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(centre, centre + Vector3(-0.3, 0.0, 0.0))
		if space.intersect_ray(query).is_empty():
			corridor_open += 1
	_expect(corridor_open >= 6, "the path itself is not walled in (%d of 8 points open)" % corridor_open)


## The tower inside the dream intro is the same one: its door, its props, all built.
func _check_the_tower_inside() -> void:
	_expect(tower.lower_door != null and not tower.lower_door.is_locked and tower.lower_door.required_key_id.is_empty(), "its front door is not locked and wants no key")
	_expect(tower.props != null and tower.props.photos.size() == 1 and tower.props.photos.has("photo_childhood"), "the Scraped Knee is in the relay room")
	var wall_hits: int = 0
	for child: Node in level.get_node("Scenery").get_children():
		if child.name == "SignalTower":
			wall_hits += 1
	_expect(wall_hits == 1, "there is one tower")
	# The tower's walls are solid in the real scene.
	var from_point: Vector3 = tower.to_global(Vector3(1.6, 1.3, 6.0))
	var to_point: Vector3 = tower.to_global(Vector3(1.6, 1.3, -6.0))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_point, to_point)
	var hit: Dictionary = space.intersect_ray(query)
	_expect(not hit.is_empty() and absf(tower.to_local(hit["position"] as Vector3).z - 2.0) < 0.08, "its brick wall stops a ray at 2 m from its middle")


## The real player, walking: from the loop to the door, in through it, and up the stairs to the balcony. (A
## capsule test says nothing is in the way; this says the player's own body, its slopes and its steps agree.)
func _check_walking() -> void:
	var player: CharacterBody3D = level.get_node("Player") as CharacterBody3D
	player.call("set_cutscene_frozen", true)
	player.call("set_cutscene_frozen", false)
	DoorController.approach_enabled = false
	var movement: Object = player.get("movement_controller") as Object
	var door: DoorController = tower.lower_door
	var base_y: float = tower.global_position.y

	# 1. From the middle of the path, east, to the door.
	await _place(player, Vector2(94.5, -36.5), 90.0)
	await _walk(player, 3.6)
	_expect(player.global_position.x > 98.3 and player.global_position.x < 99.6, "the player walks from the path to the door (x %.2f)" % player.global_position.x)

	# 2. The door opens (it is unlocked here), and the player goes in.
	door.unlock()
	door.animate_player_interaction = false
	door.interact(player)
	await get_tree().create_timer(5.0).timeout
	await _walk(player, 2.6)
	_expect(player.global_position.x > 100.6 and absf(player.global_position.y - base_y) < 1.8, "and in through it (x %.2f)" % player.global_position.x)

	# 3. From the pad, the stairs: east along their length from the foot, up to the balcony.
	await _place(player, Vector2(97.4, -33.25), 90.0)
	# (The stairs are climbed slowly now, one step to two treads: walk until the top, for as long as it takes.)
	await _walk_until(player, func() -> bool: return player.global_position.y > base_y + 2.7, 16.0)
	_expect(player.global_position.y > base_y + 2.7, "the player climbs the stairs to the balcony (%.2f m up)" % (player.global_position.y - base_y))
	_expect(movement != null, "(the player has its movement controller)")


func _place(player: CharacterBody3D, spot: Vector2, yaw: float) -> void:
	var ground: float = _ground(spot.x, spot.y)
	player.global_position = Vector3(spot.x, ground + 1.2, spot.y)
	player.velocity = Vector3.ZERO
	(player.get("movement_controller") as Object).set("look_yaw", yaw)
	await get_tree().create_timer(0.7).timeout


func _walk(player: CharacterBody3D, seconds: float) -> void:
	Input.action_press(&"up")
	await get_tree().create_timer(seconds).timeout
	Input.action_release(&"up")
	await get_tree().create_timer(0.2).timeout


## Walks forward until `done` is true (or `seconds` have passed).
func _walk_until(_player: CharacterBody3D, done: Callable, seconds: float) -> void:
	Input.action_press(&"up")
	var waited: float = 0.0
	while waited < seconds and not bool(done.call()):
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()

	Input.action_release(&"up")
	await get_tree().create_timer(0.2).timeout


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
