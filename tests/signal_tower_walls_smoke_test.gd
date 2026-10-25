extends Node

## The invisible walls round the signal tower's pad: the bare ground south west of the pad and along the trail's east side has no wall
## across it (a wall stands only where the plants are), and the ring round the tower still closes the place in. Rays are cast at the
## height of a body, over the ground, between points of the open ground; the walls are one concave body, so a ray that meets nothing
## is a way a player can walk. Run it as a scene; it quits by itself with a non-zero exit code on failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_tower_walls_smoke"

var test_failed: bool = false
var level: Node = null
var terrain: Terrain3D = null
var space: PhysicsDirectSpaceState3D = null


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "tower_walls_start", "SAVE_LOCATION_DREAM_INTRO")
	level = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	for i: int in 8:
		await get_tree().physics_frame

	terrain = level.get_node("Terrain3D") as Terrain3D
	space = (level.get_viewport().world_3d as World3D).direct_space_state
	_run()

	SaveManager.delete_slot(1)
	print("SIGNAL_TOWER_WALLS_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


## The wall (if any) a body-high ray meets between two points of the ground, as (x, z).
func _wall_between(from_xz: Vector2, to_xz: Vector2) -> Dictionary:
	var from: Vector3 = Vector3(from_xz.x, terrain.data.get_height(Vector3(from_xz.x, 0.0, from_xz.y)) + 1.0, from_xz.y)
	var to: Vector3 = Vector3(to_xz.x, terrain.data.get_height(Vector3(to_xz.x, 0.0, to_xz.y)) + 1.0, to_xz.y)
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


func _run() -> void:
	# The bare pocket beside the pad (south west of it), reached from the trail: nothing in the way, east to the plants.
	for z: float in [-31.0, -30.0, -29.0]:
		var hit: Dictionary = _wall_between(Vector2(96.0, z), Vector2(99.6, z))
		_expect(hit.is_empty(), "the ground beside the pad is open from the trail (z %.0f)" % z)

	# The strip along the trail's east side: the wall used to stand a metre or so from the trail; it now stands at the plants' face
	# (the first wall east of the trail is at least this far from it, and still there).
	var strip: Dictionary = {-26.0: 99.0, -24.5: 99.8, -23.0: 100.3, -21.5: 100.7}
	for z: float in strip:
		var hit: Dictionary = _wall_between(Vector2(96.2, z), Vector2(112.0, z))
		var wall_x: float = float(hit["position"].x) if not hit.is_empty() else INF
		_expect(wall_x >= float(strip[z]) and wall_x < 105.0, "the bare strip east of the trail is open up to the plants (z %.1f: the wall is at x %.1f)" % [z, wall_x])

	_expect(not _wall_between(Vector2(101.5, -33.0), Vector2(101.5, -20.0)).is_empty(), "south of the pad the ring is closed")
	_expect(not _wall_between(Vector2(101.5, -36.0), Vector2(120.0, -36.0)).is_empty(), "east of the tower the ring is closed")
	_expect(not _wall_between(Vector2(101.5, -36.0), Vector2(101.5, -52.0)).is_empty(), "north of the tower the ring is closed")
	_expect(not _wall_between(Vector2(97.0, -19.0), Vector2(110.0, -17.0)).is_empty(), "further south the old wall stands as before")

	# The trail itself and the way from the loop to the tower's door are not walled.
	_expect(_wall_between(Vector2(94.0, -36.0), Vector2(98.4, -36.0)).is_empty(), "the way from the loop to the tower is open")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
