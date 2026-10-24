extends Node

## The forest map that lies on the ground just past the fence door: it is where the story says, on the ground, and
## built; its picture agrees with the Terrain3D trails it was baked from; every place of the story has its name on it
## (in both languages); the red dot follows the player and the arrow follows their view; it can be picked up, is kept
## across a save, and the copy in the inspect view follows the player too. Run it as a scene; it quits by itself with a
## non-zero exit code on failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_forest_map_smoke"
const PATH_TEXTURE: int = 1

var test_failed: bool = false
var level: Node = null
var player: CharacterBody3D = null
var terrain: Terrain3D = null
var map: Collectible = null


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "forest_map_start", "SAVE_LOCATION_DREAM_INTRO")
	level = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	for i: int in 6:
		await get_tree().physics_frame

	player = level.get_node("Player")
	terrain = level.get_node("Terrain3D") as Terrain3D
	map = level.get_node_or_null("Scenery/ForestMap") as Collectible
	await _run()

	GameSettings.set_text_locale("en", false)
	SaveManager.delete_slot(1)
	print("FOREST_MAP_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _stand_at(x: float, z: float) -> void:
	var ground: float = terrain.data.get_height(Vector3(x, 0.0, z))
	player.global_position = Vector3(x, ground + 1.1, z)
	player.velocity = Vector3.ZERO
	for i: int in 8:
		await get_tree().physics_frame


func _is_path(x: float, z: float) -> bool:
	var id: Vector3 = terrain.data.get_texture_id(Vector3(x, 0.0, z))
	return int(id.x) == PATH_TEXTURE or (int(id.y) == PATH_TEXTURE and id.z > 0.5)


func _run() -> void:
	_expect(map != null, "the map is in the dream intro (Scenery/ForestMap) and is a collectible")
	if map == null:
		return

	_expect(map.item_id == "forest_map", "its item id is forest_map")
	_check_where_it_lies()
	_check_the_sheet()
	_check_the_picture_matches_the_trails()
	_check_the_words()
	await _check_the_marker()
	await _check_picking_it_up()


func _check_where_it_lies() -> void:
	var door: Node3D = level.get_node("Scenery/DoorController")
	var flat_distance: float = Vector2(map.global_position.x - door.global_position.x, map.global_position.z - door.global_position.z).length()
	_expect(flat_distance > 1.5 and flat_distance < 8.0, "it lies a few steps past the fence door (%.1f m)" % flat_distance)
	_expect(map.global_position.x > door.global_position.x, "it lies on the far side of the door, where the trails start")

	var ground: float = terrain.data.get_height(map.global_position)
	_expect(absf(map.global_position.y - ground) < 0.06, "it lies on the ground (%.3f m above it)" % (map.global_position.y - ground))
	_expect(map.global_transform.basis.z.dot(Vector3.UP) > 0.95, "it lies flat (its face is up)")
	_expect(map.global_transform.basis.y.dot(Vector3(0.0, 0.0, -1.0)) > 0.3, "north is the top of the sheet whichever way it is turned")
	_expect(_is_path(map.global_position.x, map.global_position.z), "it lies on a path, where the plants do not hide it")

	var area: Area3D = map.get_node("InteractArea") as Area3D
	_expect(area != null and area.get_child_count() > 0, "it has a place to be picked up from")


func _check_the_sheet() -> void:
	var visual: Node3D = map.get_node("Visual")
	_expect(visual.get_node_or_null("Sheet") != null, "the sheet is built")
	var print_node: MeshInstance3D = visual.get_node_or_null("Print") as MeshInstance3D
	_expect(print_node != null, "the baked picture is on the sheet (run tools/bake_forest_map.tscn if not)")
	if print_node != null:
		var material: StandardMaterial3D = print_node.material_override as StandardMaterial3D
		_expect(material != null and material.albedo_texture != null, "the picture is imported as a texture")

	var paper: Vector2 = ForestMapProps.paper_size()
	_expect(absf(paper.x / paper.y - ForestMapProps.WORLD_SIZE.x / ForestMapProps.WORLD_SIZE.y) < 0.001, "the sheet has the shape of the world it shows")
	var top_left: Vector2 = ForestMapProps.world_to_paper(ForestMapProps.WORLD_MIN)
	_expect(top_left.is_equal_approx(Vector2(-paper.x * 0.5, paper.y * 0.5)), "the north west corner of the world is the sheet's top left")
	var bottom_right: Vector2 = ForestMapProps.world_to_paper(ForestMapProps.WORLD_MIN + ForestMapProps.WORLD_SIZE)
	_expect(bottom_right.is_equal_approx(Vector2(paper.x * 0.5, -paper.y * 0.5)), "the south east corner is the bottom right")

	for landmark: Dictionary in ForestMapProps.LANDMARKS:
		_expect(ForestMapProps.covers(landmark["at"]), "%s is inside the map" % landmark["id"])

	_expect(ForestMapProps.covers(Vector2(0.0, 0.0)) and ForestMapProps.covers(Vector2(0.0, ForestMapProps.RAILWAY_Z.y)), "the railway is inside the map")


## The picture was baked from the terrain: every path cell has the ink of a trail (or an icon) next to it. When the
## trails are changed, bake again.
func _check_the_picture_matches_the_trails() -> void:
	var texture: Texture2D = load(ForestMapProps.TEXTURE_PATH) as Texture2D
	if texture == null:
		_expect(false, "the baked picture can be loaded")
		return

	var image: Image = texture.get_image()
	var size: Vector2i = ForestMapProps.picture_size()
	_expect(image.get_width() == size.x and image.get_height() == size.y, "the picture is %dx%d" % [size.x, size.y])

	var checked: int = 0
	var inked: int = 0
	var x: float = ForestMapProps.WORLD_MIN.x + 4.0
	while x < ForestMapProps.WORLD_MIN.x + ForestMapProps.WORLD_SIZE.x - 4.0:
		var z: float = ForestMapProps.WORLD_MIN.y + 4.0
		while z < ForestMapProps.WORLD_MIN.y + ForestMapProps.WORLD_SIZE.y - 4.0:
			if _is_path(x, z):
				checked += 1
				if _has_ink_near(image, ForestMapProps.world_to_pixel(Vector2(x, z)), 16):
					inked += 1

			z += 3.0

		x += 3.0

	_expect(checked > 100, "enough trail cells were checked (%d)" % checked)
	_expect(float(inked) / maxf(float(checked), 1.0) > 0.97, "the picture has ink wherever the terrain has a trail (%d of %d)" % [inked, checked])


func _has_ink_near(image: Image, pixel: Vector2, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var px: int = clampi(int(pixel.x) + dx, 0, image.get_width() - 1)
			var py: int = clampi(int(pixel.y) + dy, 0, image.get_height() - 1)
			if image.get_pixel(px, py).get_luminance() < 0.3:
				return true

	return false


func _check_the_words() -> void:
	var visual: Node3D = map.get_node("Visual")
	var keys: Array[String] = ["MAP_TITLE", "MAP_LEGEND_YOU", "MAP_LABEL_RAILWAY", "ITEM_FOREST_MAP_NAME", "ITEM_FOREST_MAP_DESCRIPTION"]
	for landmark: Dictionary in ForestMapProps.LANDMARKS:
		keys.append(str(landmark["label"]))
		var label: Label3D = visual.get_node_or_null("Label_%s" % landmark["id"]) as Label3D
		_expect(label != null and label.text == str(landmark["label"]), "%s has its name written on the map" % landmark["id"])
		if label != null:
			var spot: Vector2 = ForestMapProps.world_to_paper(landmark["at"] + landmark["name_at"])
			_expect(label.position.x == spot.x and label.position.y == spot.y, "the name of %s stands beside its icon" % landmark["id"])
			_expect(ForestMapProps.covers(landmark["at"] + landmark["name_at"]), "the name of %s is inside the map" % landmark["id"])

	for locale: String in ["en", "pt_BR"]:
		GameSettings.set_text_locale(locale, false)
		for key: String in keys:
			_expect(tr(key) != key and not tr(key).is_empty(), "%s is translated in %s" % [key, locale])

	GameSettings.set_text_locale("en", false)
	_expect(tr("MAP_LABEL_CLEARING") == "Fig Tree Clearing", "the English name of the clearing")
	GameSettings.set_text_locale("pt_BR", false)
	_expect(tr("MAP_LABEL_CLEARING") == "Clareira da Figueira", "the Portuguese name of the clearing")
	GameSettings.set_text_locale("en", false)


func _marker_in(root: Node) -> ForestMapMarker:
	var found: Array[Node] = root.find_children("YouAreHere", "ForestMapMarker", true, false)
	return found[0] as ForestMapMarker if not found.is_empty() else null


func _check_the_marker() -> void:
	var marker: ForestMapMarker = _marker_in(map)
	_expect(marker != null, "the red dot is on the map")
	if marker == null:
		return

	var door: Node3D = level.get_node("Scenery/DoorController")
	await _stand_at(door.global_position.x, door.global_position.z)
	await get_tree().process_frame
	var expected: Vector2 = ForestMapProps.world_to_paper(Vector2(player.global_position.x, player.global_position.z))
	_expect(marker.on_sheet and marker.paper_position.distance_to(expected) < 0.002, "the dot is at the fence door when the player is (%s vs %s)" % [marker.paper_position, expected])
	_expect(absf(marker.position.x - expected.x) < 0.002 and absf(marker.position.y - expected.y) < 0.002, "the dot node is moved there")

	await _stand_at(174.0, 25.0)
	await get_tree().process_frame
	expected = ForestMapProps.world_to_paper(Vector2(player.global_position.x, player.global_position.z))
	_expect(marker.paper_position.distance_to(expected) < 0.002, "it followed the player to the overlook")

	# The arrow follows the view: looking north (-Z) it points up the sheet; looking east it points to the right.
	var movement: PlayerMovementController = player.movement_controller
	movement.look_yaw = 0.0
	for i: int in 30:
		await get_tree().physics_frame

	await get_tree().process_frame
	var arrow: MeshInstance3D = marker.get_node("Arrow") as MeshInstance3D
	_expect(absf(wrapf(arrow.rotation.z, -PI, PI)) < deg_to_rad(12.0), "looking north the arrow points up the sheet (%.0f degrees)" % rad_to_deg(arrow.rotation.z))
	movement.look_yaw = 90.0
	for i: int in 30:
		await get_tree().physics_frame

	await get_tree().process_frame
	_expect(absf(wrapf(arrow.rotation.z + PI * 0.5, -PI, PI)) < deg_to_rad(12.0), "looking east the arrow points right (%.0f degrees)" % rad_to_deg(arrow.rotation.z))
	movement.look_yaw = 0.0

	# Off the sheet it waits at the edge.
	await _stand_at(-40.0, 0.0)
	await get_tree().process_frame
	var half_width: float = ForestMapProps.paper_size().x * 0.5
	_expect(not marker.on_sheet and absf(marker.paper_position.x) <= half_width - ForestMapMarker.EDGE_MARGIN + 0.0001, "off the sheet the dot waits at its edge")


func _check_picking_it_up() -> void:
	var door: Node3D = level.get_node("Scenery/DoorController")
	await _stand_at(door.global_position.x + 1.0, door.global_position.z + 1.0)
	# The dream starts with the player held in the wagon; this is a player in the forest.
	player.cutscene_frozen = false
	_expect(map.can_interact(player), "the player can pick it up")
	map.interact(player)
	for i: int in 3:
		await get_tree().process_frame

	_expect(player.inventory_controller.has_item("forest_map"), "it is in the inventory")
	_expect(bool(SaveManager.get_state_value(&"collectibles", &"forest_map", false)), "it counts as collected, so it never lies in the world again")
	_expect(not is_instance_valid(map) or map.is_queued_for_deletion(), "it is gone from the ground")
	_expect(player.inspect_controller.is_open(), "it is shown to the player as it is taken")

	var live: ForestMapMarker = _marker_in(get_tree().root)
	_expect(live != null and live.is_inside_tree(), "the copy in the view has the red dot")
	if live != null:
		await _stand_at(100.0, -36.0)
		await get_tree().process_frame
		var expected: Vector2 = ForestMapProps.world_to_paper(Vector2(player.global_position.x, player.global_position.z))
		_expect(live.paper_position.distance_to(expected) < 0.002, "the dot in the view follows the player too (the signal tower)")

	player.inspect_controller.close()
	for i: int in 30:
		await get_tree().process_frame

	# Kept across a save: the inventory is rebuilt from its scene, and the model with it.
	var saved: Array[Dictionary] = player.inventory_controller.get_serializable_slots()
	player.inventory_controller.restore_serializable_slots(saved)
	var slot: Dictionary = {}
	for candidate: Dictionary in player.inventory_controller.get_slots():
		if str(candidate.get("id", "")) == "forest_map":
			slot = candidate

	_expect(not slot.is_empty(), "the map is still in the inventory after a load")
	var template: Node3D = slot.get("inspect_visual_template") as Node3D
	_expect(template != null and template.get_node_or_null("Sheet") != null and _marker_in(template) != null, "the loaded map has its sheet and its red dot")

	# And can be looked at again at any time.
	var opened: bool = player.inspect_controller.open_inventory(slot)
	_expect(opened, "it can be opened from the inventory")
	await _stand_at(65.0, -16.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var again: ForestMapMarker = _marker_in(get_tree().root)
	_expect(again != null, "the copy opened later has the red dot")
	if again != null:
		var expected_again: Vector2 = ForestMapProps.world_to_paper(Vector2(player.global_position.x, player.global_position.z))
		_expect(again.paper_position.distance_to(expected_again) < 0.002, "opened again later, the dot shows where the player is now (the waiting shed)")

	player.inspect_controller.close()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
