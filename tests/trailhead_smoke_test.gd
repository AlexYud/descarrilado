extends Node

## The start of the trail between the wagon and the fence gate: two signs and nothing else. The welcome sign ("Bem-vindo à", the old name
## of the place scratched and painted over until it cannot be read, "Fenda" in red over it) stands by the way to the gate and faces the
## wagon's exit door; the trail map sign stands on the other side and faces the middle of the space between the wagon's door and the
## gate, with the map pinned in its window. Both stand a little way from the gate's opening, against the fence. Both are small (a city park's signs), stand on the ground, are in Portuguese whatever the
## language of the game, and do not stand in the way of the player's walk to the gate. Run it as a scene; it quits by itself with a
## non-zero exit code on failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_trailhead_smoke"

var test_failed: bool = false
var level: Node = null
var player: CharacterBody3D = null
var terrain: Terrain3D = null
var trail: TrailheadProps = null
var start_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "trailhead_start", "SAVE_LOCATION_DREAM_INTRO")
	level = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	for i: int in 8:
		await get_tree().physics_frame

	player = level.get_node("Player")
	start_position = player.global_position
	terrain = level.get_node("Terrain3D") as Terrain3D
	trail = level.get_node_or_null("Scenery/Trailhead") as TrailheadProps
	_run()
	await _check_the_way_is_clear()

	GameSettings.set_text_locale("en", false)
	SaveManager.delete_slot(1)
	print("TRAILHEAD_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _ground(position: Vector3) -> float:
	return terrain.data.get_height(position)


## The direction a node's front (+Z) points in, flat on the ground.
func _front_of(node: Node3D) -> Vector2:
	var front: Vector3 = node.global_transform.basis.z
	return Vector2(front.x, front.z).normalized()


func _run() -> void:
	_expect(trail != null and trail.is_built, "the trailhead is in the dream intro and built")
	if trail == null or not trail.is_built:
		return

	var door: Node3D = level.get_node("Scenery/DoorController")
	_check_only_two_signs()
	_check_the_welcome_sign(door)
	_check_the_name_cannot_be_read()
	_check_the_words()
	_check_the_board(door)
	_check_the_pictures()


func _check_only_two_signs() -> void:
	# No portal, no log steps, no bench, no bin, no roof, no header: only the two signs (and the map on one of them).
	for gone: String in ["Portal", "Steps", "Bench", "Bin", "BeamHigh", "RoofBoards", "HeaderPlate", "Header", "Step0"]:
		_expect(trail.find_child(gone, true, false) == null, "there is no %s" % gone)

	_expect(trail.welcome_sign != null and trail.board != null, "the welcome sign and the trail map sign are built")
	var parts: int = 0
	for child: Node in trail.get_children():
		if child is Node3D and child != trail.map:
			parts += 1

	_expect(parts == 2, "the trailhead holds the two signs and the map, nothing else (%d parts)" % parts)


func _check_the_welcome_sign(door: Node3D) -> void:
	var sign_board: Node3D = trail.welcome_sign
	var gate_distance: float = Vector2(sign_board.global_position.x - door.global_position.x, sign_board.global_position.z - door.global_position.z).length()
	_expect(sign_board.global_position.x > 4.0 and sign_board.global_position.x < door.global_position.x, "the welcome sign is between the wagon and the fence gate (x %.1f)" % sign_board.global_position.x)
	_expect(gate_distance < 5.5, "and next to the gate (%.1f m)" % gate_distance)
	_check_beside_the_gate("the welcome sign", sign_board, door)

	# It faces the wagon's exit door.
	var to_wagon_door: Vector2 = trail.wagon_door_world - Vector2(sign_board.global_position.x, sign_board.global_position.z)
	_expect(_front_of(sign_board).dot(to_wagon_door.normalized()) > 0.98, "the welcome sign faces the wagon's exit door")
	_expect(absf(sign_board.global_position.y - _ground(sign_board.global_position)) < 0.05, "it stands on the ground")

	# Small, like a park's sign: the whole of it under two metres and a half a metre wide at most 1.5 m.
	var size: Vector2 = TrailheadProps.WELCOME_PANEL
	_expect(size.x <= 1.5 and size.y <= 0.9, "its face is %.2f by %.2f m" % [size.x, size.y])
	var top: float = TrailheadProps.WELCOME_CENTER_Y + size.y * 0.5 + TrailheadProps.WELCOME_FRAME
	var bottom: float = TrailheadProps.WELCOME_CENTER_Y - size.y * 0.5 - TrailheadProps.WELCOME_FRAME
	_expect(top < 2.0 and bottom > 0.8, "it hangs between %.2f and %.2f m over the ground" % [bottom, top])

	var posts: int = 0
	for node: Node in sign_board.get_children():
		if node is StaticBody3D:
			posts += 1

	_expect(posts == 2, "it stands on two solid posts (%d)" % posts)
	_expect(sign_board.get_node_or_null("FrameTop") != null and sign_board.get_node_or_null("Face") != null, "it has its frame and its painted face")


## A sign stands beside the gate, up against the fence like a guide at the entrance: to one side of the gate's opening (not in front
## of it, in the middle of the clearing), within reach of the fence, and outside the sweep of the gate when it opens.
func _check_beside_the_gate(label: String, node: Node3D, door: Node3D) -> void:
	var local: Vector3 = trail.to_local(node.global_position)
	_expect(absf(local.x) >= 1.4 and absf(local.x) <= 3.8, "%s is to the side of the gate's opening, %.1f m from its middle" % [label, absf(local.x)])
	_expect(local.z > 0.5 and local.z < 4.5, "and %.1f m in front of the gate" % local.z)

	var nearest_fence: float = INF
	for piece: Node in level.get_node("Scenery/Fences/BarbedFenceBigNoAngle").get_children():
		var fence: Node3D = piece as Node3D
		if fence != null and not fence is MultiMeshInstance3D:
			nearest_fence = minf(nearest_fence, Vector2(fence.global_position.x - node.global_position.x, fence.global_position.z - node.global_position.z).length())

	_expect(nearest_fence < 1.8, "%s stands against the fence (%.1f m from it)" % [label, nearest_fence])

	# The gate swings about its hinge (the door node's origin) over a radius of its width.
	var hinge: Vector2 = Vector2(door.global_position.x, door.global_position.z)
	var swing: float = Vector2(node.global_position.x, node.global_position.z).distance_to(hinge)
	_expect(swing > 2.6, "and out of the gate's sweep (%.1f m from its hinge)" % swing)


func _check_the_name_cannot_be_read() -> void:
	var sign_board: Node3D = trail.welcome_sign
	var welcome: Label3D = sign_board.get_node_or_null("Welcome") as Label3D
	var old_name: Label3D = trail.old_name_label
	var new_name: Label3D = trail.new_name_label
	_expect(welcome != null and welcome.text == "SIGN_TRAILHEAD_WELCOME", "it says Bem-vindo à")
	_expect(old_name != null and old_name.text == "SIGN_TRAILHEAD_OLD_NAME", "it has the old name of the place")
	_expect(new_name != null and new_name.text == "SIGN_TRAILHEAD_NEW_NAME", "and the new one")
	if welcome == null or old_name == null or new_name == null or trail.defacement == null:
		return

	# The new name is painted in red, bigger, crooked, over the old one.
	var colour: Color = new_name.modulate
	_expect(colour.r > 0.55 and colour.g < 0.15 and colour.b < 0.15, "Fenda is red (%s)" % colour)
	_expect(new_name.position.z > old_name.position.z and new_name.position.z > trail.defacement.position.z, "and on top of the old name and of the paint")
	_expect(new_name.pixel_size > old_name.pixel_size * 1.5, "and much bigger")
	_expect(absf(new_name.rotation_degrees.z) > 1.0, "and crooked, like a hand did it")
	_expect(sign_board.get_node_or_null("Drip0") != null, "the red paint has run")

	# The paint and the scratches lie over the old name and cover it: the picture is on top of the writing, bigger than it,
	# and does not reach up to "Bem-vindo à".
	var paint_centre: Vector2 = Vector2(trail.defacement.position.x, trail.defacement.position.y)
	var paint_size: Vector2 = TrailheadProps.DEFACED_SIZE
	var name_box: AABB = old_name.get_aabb()
	var name_left: float = old_name.position.x + name_box.position.x
	var name_right: float = name_left + name_box.size.x
	_expect(trail.defacement.position.z > old_name.position.z, "the paint is over the old name")
	_expect(paint_centre.x - paint_size.x * 0.5 <= name_left + 0.001 and paint_centre.x + paint_size.x * 0.5 >= name_right - 0.001, "it spans the whole of the old name (%.2f to %.2f of %.2f to %.2f)" % [name_left, name_right, paint_centre.x - paint_size.x * 0.5, paint_centre.x + paint_size.x * 0.5])
	_expect(paint_centre.y + paint_size.y * 0.5 < welcome.position.y - TrailheadProps.WELCOME_LINE_EM * 0.5 + 0.02, "and stays below the line that says Bem-vindo à")
	_expect(paint_centre.y - paint_size.y * 0.5 < old_name.position.y - TrailheadProps.OLD_NAME_EM * 0.35 and paint_centre.y + paint_size.y * 0.5 > old_name.position.y + TrailheadProps.OLD_NAME_EM * 0.35, "and the old name is inside its height")

	# The picture itself: red over most of the name's rectangle, and scratches through all of it.
	var texture: Texture2D = load(TrailheadProps.DEFACED_NAME_PATH) as Texture2D
	_expect(texture != null, "the picture of the paint and the scratches is baked and imported")
	if texture == null:
		return

	var image: Image = texture.get_image()
	var pixels_per_meter: float = float(image.get_width()) / paint_size.x
	var covered: int = 0
	var scratched: int = 0
	var total: int = 0
	var name_rows: Vector2 = Vector2(old_name.position.y - TrailheadProps.OLD_NAME_EM * 0.4, old_name.position.y + TrailheadProps.OLD_NAME_EM * 0.4)
	for py: int in image.get_height():
		var y_meters: float = paint_centre.y + paint_size.y * 0.5 - float(py) / pixels_per_meter
		if y_meters < name_rows.x or y_meters > name_rows.y:
			continue

		for px: int in image.get_width():
			var x_meters: float = paint_centre.x - paint_size.x * 0.5 + float(px) / pixels_per_meter
			if x_meters < name_left or x_meters > name_right:
				continue

			total += 1
			var pixel: Color = image.get_pixel(px, py)
			if pixel.a > 0.45:
				covered += 1
				if pixel.g > 0.5 and pixel.b > 0.5:
					scratched += 1

	var coverage: float = float(covered) / maxf(float(total), 1.0)
	_expect(coverage > 0.7, "paint and scratches cover most of the old name (%.0f%% of it)" % (coverage * 100.0))
	_expect(float(scratched) / maxf(float(total), 1.0) > 0.03, "and the scratches are many (%.1f%%)" % (100.0 * float(scratched) / maxf(float(total), 1.0)))


func _check_the_words() -> void:
	# The signs are in Portuguese whatever the language of the game: they belong to the park, and to the children.
	for locale: String in ["en", "pt_BR"]:
		GameSettings.set_text_locale(locale, false)
		_expect(tr("SIGN_TRAILHEAD_WELCOME") == "Bem-vindo à", "the sign says Bem-vindo à in %s" % locale)
		_expect(tr("SIGN_TRAILHEAD_NEW_NAME") == "Fenda", "and Fenda in %s" % locale)
		_expect(tr("SIGN_TRAILHEAD_OLD_NAME") == "TRILHA DA SERRA", "and the old name is the same in %s" % locale)
		_expect(tr("SIGN_TRAIL_MAP_TITLE") == "SIGN_TRAIL_MAP_TITLE", "the trail map sign has no name written on it (%s)" % locale)

	GameSettings.set_text_locale("en", false)


func _check_the_board(door: Node3D) -> void:
	var board: Node3D = trail.board
	var board_xz: Vector2 = Vector2(board.global_position.x, board.global_position.z)
	_expect(board.global_position.x > 3.0 and board.global_position.x < door.global_position.x, "the trail map sign is between the wagon and the fence gate")
	_expect(Vector2(board.global_position.x - door.global_position.x, board.global_position.z - door.global_position.z).length() < 5.5, "and next to the gate")
	_check_beside_the_gate("the trail map sign", board, door)
	_expect(absf(board.global_position.y - _ground(board.global_position)) < 0.05, "it stands on the ground")

	# It faces the middle of the space between the wagon's exit door and the gate.
	var gate_xz: Vector2 = Vector2(trail.global_position.x, trail.global_position.z)
	var centre: Vector2 = (trail.wagon_door_world + gate_xz) * 0.5
	_expect(_front_of(board).dot((centre - board_xz).normalized()) > 0.98, "the trail map sign faces the middle of the space between the wagon's door and the gate")
	var local_centre: Vector2 = trail.space_center_local()
	var centre_world: Vector3 = trail.to_global(Vector3(local_centre.x, 0.0, local_centre.y))
	_expect(Vector2(centre_world.x, centre_world.z).distance_to(centre) < 0.05, "the space's middle is the point halfway from the wagon's door to the gate")
	_expect(_front_of(board).dot((trail.wagon_door_world - board_xz).normalized()) < 0.9, "and it no longer points at the wagon")

	# Small, too.
	_expect(TrailheadProps.BOARD_PANEL.x <= 1.0 and TrailheadProps.BOARD_PANEL.y <= 1.4, "its panel is %.2f by %.2f m" % [TrailheadProps.BOARD_PANEL.x, TrailheadProps.BOARD_PANEL.y])
	_expect(TrailheadProps.BOARD_TOP_Y < 2.3, "and it is %.2f m tall" % (TrailheadProps.BOARD_TOP_Y + 0.07))
	_expect(ForestMapProps.paper_size().x <= 0.5, "the map on it is %.2f m wide" % ForestMapProps.paper_size().x)

	# Two solid posts, a cap, a frame, a face, and nothing written on it: no name (the names are in the picture's emblems only).
	var posts: int = 0
	for node: Node in board.get_children():
		if node is StaticBody3D:
			posts += 1

	_expect(posts == 2, "it stands on two solid posts (%d)" % posts)
	_expect(board.get_node_or_null("Cap") != null and board.get_node_or_null("FrameTop") != null and board.get_node_or_null("Face") != null, "it has its cap, its frame and its painted face")
	_expect(board.find_children("*", "Label3D", true, false).is_empty(), "no name is written on it")
	_expect(trail.pins.size() == 4, "four pins hold the map")
	_expect(trail.map != null and trail.map.get_parent() == trail, "the map is a child of the trailhead")
	_expect(trail.map != null and trail.map.global_position.distance_to(board.to_global(TrailheadProps.MAP_MOUNT)) < 0.01, "and hangs in the window")


## The painted faces: the window where the map hangs is darker than the paint round it (the paper kept the sun off it) and the four
## pin holes are in its corners.
func _check_the_pictures() -> void:
	var texture: Texture2D = load(TrailheadProps.BOARD_FACE_PATH) as Texture2D
	_expect(texture != null, "the picture of the trail map sign is baked and imported")
	if texture == null:
		return

	var image: Image = texture.get_image()
	var pixels_per_meter: float = float(image.get_width()) / TrailheadProps.BOARD_PANEL.x
	var window_centre: Vector2 = Vector2(float(image.get_width()) * 0.5, float(image.get_height()) * 0.5) + Vector2(TrailheadProps.MAP_WINDOW_CENTER.x, -TrailheadProps.MAP_WINDOW_CENTER.y) * pixels_per_meter
	var inside: float = _mean_luminance(image, Rect2(window_centre - Vector2(30.0, 30.0), Vector2(60.0, 60.0)))
	var beside: float = _mean_luminance(image, Rect2(Vector2(20.0, window_centre.y - 30.0), Vector2(60.0, 60.0)))
	_expect(inside < beside * 0.85, "the paint under the map is darker than the paint round it (%.3f against %.3f)" % [inside, beside])

	for offset: Vector2 in TrailheadProps.pin_offsets(ForestMapProps.paper_size()):
		var hole: Vector2 = window_centre + Vector2(offset.x, -offset.y) * pixels_per_meter
		var dark: float = _mean_luminance(image, Rect2(hole - Vector2(2.0, 2.0), Vector2(4.0, 4.0)))
		var around: float = _mean_luminance(image, Rect2(hole + Vector2(9.0, 9.0), Vector2(8.0, 8.0)))
		_expect(dark < around, "a pin hole shows where a pin was (%.3f against %.3f)" % [dark, around])


func _mean_luminance(image: Image, rect: Rect2) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(maxi(int(rect.position.y), 0), mini(int(rect.end.y), image.get_height())):
		for x: int in range(maxi(int(rect.position.x), 0), mini(int(rect.end.x), image.get_width())):
			total += image.get_pixel(x, y).get_luminance()
			count += 1

	return total / maxf(float(count), 1.0)


## From the wagon to the gate along the path, nothing solid stands in the way at the height of a body.
func _check_the_way_is_clear() -> void:
	if trail == null or not trail.is_built:
		return

	var space: PhysicsDirectSpaceState3D = (player.get_world_3d() as World3D).direct_space_state
	for lane: float in [-0.6, 0.0, 0.6]:
		var from: Vector3 = trail.to_global(Vector3(lane, 0.0, 8.0))
		var to: Vector3 = trail.to_global(Vector3(lane, 0.0, 1.2))
		var level_height: float = maxf(_ground(from), _ground(to)) + 1.2
		from.y = level_height
		to.y = level_height
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [player.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		var what: String = str(hit.get("collider", "")) if not hit.is_empty() else "nothing"
		_expect(hit.is_empty(), "the way to the gate is clear at %.1f m to the side (%s in the way)" % [lane, what])

	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
