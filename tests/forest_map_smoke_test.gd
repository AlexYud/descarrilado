extends Node

## The forest map that hangs on the trail map sign, between the wagon and the fence gate: it is on the board, at reading height and
## facing the middle of the space; its picture agrees with the Terrain3D trails it was baked from; every place of the story has its
## name on it (in both languages) and no name lies across a fold; the back of the map has no title; taking it is a scene of about four seconds
## (the top pins are worked out, the paper sags, is yanked and torn off the bottom pins, and held up; the flashlight stays on and is turned
## on it), then it is folded in the hand, opens out when it is looked at and folds again
## when it is put away; it is the player's own map (not an item of the inventory), opened with the map key. Run it as a scene; it quits by itself with a non-zero exit code on
## failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_forest_map_smoke"
const PATH_TEXTURE: int = 1

var test_failed: bool = false
var level: Node = null
var player: CharacterBody3D = null
var terrain: Terrain3D = null
var trail: TrailheadProps = null
var map: Collectible = null
var start_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "forest_map_start", "SAVE_LOCATION_DREAM_INTRO")
	level = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	for i: int in 8:
		await get_tree().physics_frame

	player = level.get_node("Player")
	start_position = player.global_position
	terrain = level.get_node("Terrain3D") as Terrain3D
	trail = level.get_node_or_null("Scenery/Trailhead") as TrailheadProps
	map = level.get_node_or_null("Scenery/Trailhead/ForestMap") as Collectible
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


## Waits until `condition` is true, for at most `seconds` of real time. Returns whether it became true.
func _wait_for(condition: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if bool(condition.call()):
			return true

		await get_tree().process_frame

	return bool(condition.call())


func _is_path(x: float, z: float) -> bool:
	var id: Vector3 = terrain.data.get_texture_id(Vector3(x, 0.0, z))
	return int(id.x) == PATH_TEXTURE or (int(id.y) == PATH_TEXTURE and id.z > 0.5)


func _run() -> void:
	_expect(trail != null, "the trailhead is in the dream intro (Scenery/Trailhead)")
	_expect(map != null, "the map is in the dream intro (Scenery/Trailhead/ForestMap) and is a collectible")
	if map == null or trail == null:
		return

	_expect(trail.is_built, "the trailhead is built")
	_expect(map.item_id == "forest_map", "its item id is forest_map")
	_check_where_it_hangs()
	_check_the_sheet()
	_check_the_picture_matches_the_trails()
	_check_the_words()
	await _check_taking_it()
	await _check_it_is_kept()


func _check_where_it_hangs() -> void:
	var door: Node3D = level.get_node("Scenery/DoorController")
	var flat_distance: float = Vector2(map.global_position.x - door.global_position.x, map.global_position.z - door.global_position.z).length()
	_expect(flat_distance > 1.5 and flat_distance < 6.0, "it is next to the fence door (%.1f m)" % flat_distance)
	_expect(map.global_position.x > 3.0 and map.global_position.x < door.global_position.x, "it is between the wagon and the fence door")

	var ground: float = terrain.data.get_height(map.global_position)
	var height: float = map.global_position.y - ground
	_expect(height > 1.3 and height < 2.4, "it hangs at reading height (%.2f m over the ground)" % height)
	var normal: Vector3 = map.global_transform.basis.z
	_expect(absf(normal.y) < 0.1, "it hangs upright")
	var gate: Vector2 = Vector2(trail.global_position.x, trail.global_position.z)
	var middle: Vector2 = (trail.wagon_door_world + gate) * 0.5
	var to_middle: Vector2 = middle - Vector2(map.global_position.x, map.global_position.z)
	_expect(Vector2(normal.x, normal.z).normalized().dot(to_middle.normalized()) > 0.98, "its face turns to the middle of the space between the wagon's door and the gate")
	_expect(ForestMapProps.paper_size().x <= 0.5, "it is a small paper (%.2f m wide)" % ForestMapProps.paper_size().x)
	_expect(trail.board != null and map.global_position.distance_to(trail.board.to_global(TrailheadProps.MAP_MOUNT)) < 0.01, "it is mounted on the board")
	_expect(map.get_node("Visual").get_meta("inspect_fold_rig", "") == "Sheet", "its Visual names the sheet as the part that folds")

	var area: Area3D = map.get_node("InteractArea") as Area3D
	_expect(area != null and area.get_child_count() > 0, "it has a place to be taken from")


func _check_the_sheet() -> void:
	var visual: Node3D = map.get_node("Visual")
	var sheet: FoldingSheet = visual.get_node_or_null("Sheet") as FoldingSheet
	_expect(sheet != null, "the sheet is built")
	if sheet == null:
		return

	var offsets: Dictionary = {}
	for panel_name: StringName in [&"BottomLeft", &"TopLeft", &"BottomRight", &"TopRight"]:
		var panel: Node3D = sheet.get_panel(panel_name)
		var print_node: MeshInstance3D = panel.get_node_or_null("Print") as MeshInstance3D if panel != null else null
		var material: StandardMaterial3D = print_node.material_override as StandardMaterial3D if print_node != null else null
		_expect(material != null and material.albedo_texture != null, "%s carries its quarter of the baked picture" % panel_name)
		if material != null:
			offsets[material.uv1_offset] = true

	_expect(offsets.size() == 4, "the four panels carry four different quarters")

	var paper: Vector2 = ForestMapProps.paper_size()
	_expect(absf(paper.x / paper.y - ForestMapProps.WORLD_SIZE.x / ForestMapProps.WORLD_SIZE.y) < 0.001, "the sheet has the shape of the world it shows")
	var top_left: Vector2 = ForestMapProps.world_to_paper(ForestMapProps.WORLD_MIN)
	_expect(top_left.is_equal_approx(Vector2(-paper.x * 0.5, paper.y * 0.5)), "the north west corner of the world is the sheet's top left")
	var bottom_right: Vector2 = ForestMapProps.world_to_paper(ForestMapProps.WORLD_MIN + ForestMapProps.WORLD_SIZE)
	_expect(bottom_right.is_equal_approx(Vector2(paper.x * 0.5, -paper.y * 0.5)), "the south east corner is the bottom right")

	for landmark: Dictionary in ForestMapProps.LANDMARKS:
		_expect(ForestMapProps.covers(landmark["at"]), "%s is inside the map" % landmark["id"])

	_expect(ForestMapProps.covers(Vector2(0.0, 0.0)) and ForestMapProps.covers(Vector2(0.0, ForestMapProps.RAILWAY_Z.y)), "the railway is inside the map")
	_expect(visual.find_child("YouAreHere", true, false) == null, "there is no red dot: the map does not say where the player is")


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
	var sheet: FoldingSheet = visual.get_node("Sheet") as FoldingSheet
	var keys: Array[String] = ["MAP_TITLE", "MAP_LABEL_RAILWAY", "ITEM_FOREST_MAP_NAME", "ITEM_FOREST_MAP_DESCRIPTION"]
	var half: Vector2 = sheet.panel_size() * 0.5
	for landmark: Dictionary in ForestMapProps.LANDMARKS:
		keys.append(str(landmark["label"]))
		var label: Label3D = visual.find_child("Label_%s" % landmark["id"], true, false) as Label3D
		_expect(label != null and label.text == str(landmark["label"]), "%s has its name written on the map" % landmark["id"])
		if label == null:
			continue

		var spot: Vector2 = ForestMapProps.world_to_paper(landmark["at"] + landmark["name_at"])
		var on_sheet: Vector3 = sheet.to_local(label.global_position)
		_expect(absf(on_sheet.x - spot.x) < 0.001 and absf(on_sheet.y - spot.y) < 0.001, "the name of %s stands beside its icon" % landmark["id"])
		_expect(ForestMapProps.covers(landmark["at"] + landmark["name_at"]), "the name of %s is inside the map" % landmark["id"])
		# It hangs on one panel of the folding sheet, and the whole word fits on it (it never lies across a fold).
		var box: AABB = label.get_aabb()
		_expect(absf(label.position.x) + box.size.x * 0.5 < half.x and absf(label.position.y) + box.size.y * 0.5 < half.y, "the name of %s fits on its panel (%.3f of %.3f m wide)" % [landmark["id"], box.size.x, half.x * 2.0])

	# The back of the map has no title; every word is on the front of its panel.
	_expect(visual.find_child("Cover", true, false) == null, "the back of the map has no title")
	var behind: int = 0
	for panel_name: StringName in [&"BottomLeft", &"TopLeft", &"BottomRight", &"TopRight"]:
		for child: Node in sheet.get_panel(panel_name).get_children():
			if child is Label3D and (child as Label3D).position.z < 0.0:
				behind += 1

	_expect(behind == 0, "no word is written on the back of a panel")

	for locale: String in ["en", "pt_BR"]:
		GameSettings.set_text_locale(locale, false)
		for key: String in keys:
			_expect(tr(key) != key and not tr(key).is_empty(), "%s is translated in %s" % [key, locale])

	GameSettings.set_text_locale("en", false)
	_expect(tr("MAP_LABEL_CLEARING") == "Fig Tree Clearing", "the English name of the clearing")
	GameSettings.set_text_locale("pt_BR", false)
	_expect(tr("MAP_LABEL_CLEARING") == "Clareira da Figueira", "the Portuguese name of the clearing")
	_expect(not tr("ITEM_FOREST_MAP_DESCRIPTION").contains("ponto vermelho"), "the description does not promise a red dot")
	GameSettings.set_text_locale("en", false)
	_expect(not tr("ITEM_FOREST_MAP_DESCRIPTION").contains("red dot"), "the English description does not promise one either")


## How far the closedness of a sheet that may have been freed meanwhile is (1 if it is gone: a map that has gone folded).
func _closedness(reference: WeakRef) -> float:
	var sheet: FoldingSheet = reference.get_ref() as FoldingSheet
	return 1.0 if sheet == null else sheet.closedness


func _moving(reference: WeakRef) -> bool:
	var sheet: FoldingSheet = reference.get_ref() as FoldingSheet
	return sheet != null and sheet.is_moving()


## The scene of taking the map, looked at moment by moment (it is a function of time): the two top pins are worked out of the wood one after
## the other, the top of the paper sags, it is yanked down and torn free of the bottom pins (which keep a scrap of it), and the paper is lifted
## flat in front of the player, all in the light of the flashlight, which stays on and turns on the paper.
func _check_the_removal_scene() -> void:
	var stand: Vector3 = trail.board.to_global(Vector3(0.0, 0.0, 1.6))
	await _stand_at(stand.x, stand.z)
	player.cutscene_frozen = false
	var pinned: PinnedCollectible = map as PinnedCollectible
	_expect(pinned != null and pinned.pins.size() == 4, "the map knows its four pins")
	if pinned == null or pinned.pins.size() != 4:
		return

	_expect(pinned.removal_seconds >= 3.5, "the scene is long enough to be seen (%.1f s)" % pinned.removal_seconds)
	_expect(trail.scraps.size() == 2, "a scrap of paper waits behind the paper under each bottom pin")
	var camera: Camera3D = player.movement_controller.camera
	var flashlight: Node = player.flashlight_controller
	_expect(flashlight != null, "the player has a flashlight")
	var home: Transform3D = map.global_transform
	var pin_homes: Array[Vector3] = []
	for pin: Node3D in pinned.pins:
		pin_homes.append(pin.position)

	# The flashlight was off: the scene lights it. (And it is put out again at the end, as it was.) The player has it in the forest.
	flashlight.set("flashlight_input_enabled", true)
	flashlight.call("turn_off")
	_expect(pinned.begin_removal(player), "the removal can begin")
	_expect(player.view_locked and pinned.is_being_removed, "the player's view is held while it plays")
	_expect(not player.modal_ui_open, "but it is not held as a puzzle screen is, which puts the flashlight out")
	_expect(not player.is_flashlight_blocked(), "the flashlight is not blocked")
	_expect((flashlight as Node3D).visible and bool(flashlight.get("scripted_aim_on")), "the flashlight is on, and its beam is aimed by the scene")
	_expect(not pinned.can_interact(player), "and the map cannot be taken again meanwhile")

	pinned.pose_removal(0.0)
	var sheet: FoldingSheet = map.get_node("Visual/Sheet") as FoldingSheet
	_expect(map.global_transform.is_equal_approx(home) and is_equal_approx(sheet.curl, 0.0), "at the start the paper hangs flat on the board")
	for pin: Node3D in pinned.pins:
		_expect(pin.visible, "at the start every pin is in the wood")

	# The beam follows the paper.
	var to_paper: Vector3 = (map.global_position - (flashlight as Node3D).global_position).normalized()
	var aimed: Vector3 = flashlight.get("scripted_aim_direction")
	_expect(aimed.normalized().dot(to_paper) > 0.99, "the beam is turned on the paper")

	# 0.9 s: the first pin is being worked: tugged a little, not out; the second is still in.
	pinned.pose_removal(0.9)
	_expect(pinned.pins[0].visible and pinned.pins[0].position.distance_to(pin_homes[0]) < PinnedCollectible.PIN_TUG * 2.5, "the first pin is being tugged, not out yet")
	_expect(pinned.pins[1].position.is_equal_approx(pin_homes[1]), "the second pin is still in")

	# 1.4 s: the first pin has come out with a jerk and is on its way to the pocket.
	pinned.pose_removal(1.3)
	_expect(pinned.pins[0].visible and pinned.pins[0].position.distance_to(pin_homes[0]) > 0.06, "the first pin is out and carried off (%.2f m)" % pinned.pins[0].position.distance_to(pin_homes[0]))
	_expect(map.global_transform.origin.distance_to(home.origin) < 0.001, "and the paper has not moved")
	pinned.pose_removal(1.6)
	_expect(not pinned.pins[0].visible, "then it is in the pocket")

	# 2.2 s: both top pins are in the pocket; the top of the paper sags forward, held by its bottom pins.
	pinned.pose_removal(2.2)
	_expect(not pinned.pins[1].visible, "the second pin is in the pocket")
	_expect(sheet.curl > 0.05, "the top of the paper sags (%.2f rad)" % sheet.curl)
	_expect(pinned.pins[2].visible and pinned.pins[3].visible, "the bottom pins still hold it")
	var sagged: float = rad_to_deg(home.basis.z.angle_to(map.global_transform.basis.z))
	_expect(sagged > 5.0 and sagged < 32.0, "it hangs %.0f degrees off the board" % sagged)

	# 2.95 s: it has been yanked down hard on the bottom pins, and has torn free.
	pinned.pose_removal(2.95)
	var yanked: float = rad_to_deg(home.basis.z.angle_to(map.global_transform.basis.z))
	_expect(yanked > 50.0 and yanked < 75.0, "yanked down it is %.0f degrees off the board" % yanked)
	_expect(map.global_transform.origin.distance_to(home.origin) < 0.4, "still at the board")
	_expect(is_zero_approx(camera.h_offset) and is_zero_approx(camera.v_offset), "the view does not shake or jolt as the paper tears")
	_expect(pinned.pins[2].visible and pinned.pins[3].visible and trail.scraps[0].is_visible_in_tree(), "the bottom pins stay in the board, and so do the scraps under them")

	# 3.3 s: it is on its way to the hands.
	pinned.pose_removal(3.3)
	_expect(map.global_transform.origin.distance_to(home.origin) > 0.15, "the torn paper is lifted away from the board")

	# The end: flat, facing the player, a forearm in front of them; the view is still again.
	pinned.pose_removal(pinned.removal_seconds)
	var view: Transform3D = camera.global_transform
	var held: Vector3 = view.origin - view.basis.z * PinnedCollectible.HAND_DISTANCE - view.basis.y * PinnedCollectible.HAND_DROP
	_expect(map.global_position.distance_to(held) < 0.01, "at the end the paper is held up in front of the player")
	_expect(map.global_transform.basis.z.dot(view.basis.z) > 0.98, "facing them")
	_expect(is_equal_approx(sheet.curl, 0.0) and is_equal_approx(sheet.closedness, 0.0), "flat and open")
	_expect(is_zero_approx(camera.h_offset) and is_zero_approx(camera.v_offset), "and it is still at the end")

	pinned.cancel_removal()
	_expect(not player.view_locked and not pinned.is_being_removed, "cancelled, the player is free again")
	_expect(not bool(flashlight.get("scripted_aim_on")) and not bool(flashlight.get("flashlight_on")), "the flashlight is as it was (off), its beam the player's again")
	_expect(map.global_transform.is_equal_approx(home) and pinned.pins[0].visible and pinned.pins[0].position.is_equal_approx(pin_homes[0]), "and everything is back on the board")

	# With the flashlight on to begin with, it stays on after.
	flashlight.set("flashlight_on", true)
	_expect(pinned.begin_removal(player), "the removal can begin again with the flashlight on")
	pinned.cancel_removal()
	_expect(bool(flashlight.get("flashlight_on")), "a flashlight that was on is still on after")
	flashlight.call("turn_off")


## A key press as the game gets it.
func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _check_taking_it() -> void:
	var inspect: PlayerInspectController = player.inspect_controller
	var opened_signals: Array[String] = []
	var closed_signals: Array[String] = []
	inspect.inspect_opened.connect(func(id: String) -> void: opened_signals.append(id))
	inspect.inspect_closed.connect(func(id: String) -> void: closed_signals.append(id))

	await _check_the_removal_scene()
	var pinned: PinnedCollectible = map as PinnedCollectible
	var home: Transform3D = map.global_transform
	_expect(map.can_interact(player), "the player can take it")
	_expect(map.get_prompt_text() == "PROMPT_INSPECT" and tr("PROMPT_INSPECT") == "Inspect", "first they look at it: the prompt on the board is [E] Inspect, not Pick Up")

	# First the close up: the player walks to the board, the view frames the map where it hangs, and a row at the bottom asks.
	var stand: Vector3 = trail.board.to_global(Vector3(0.0, 0.0, 1.6))
	await _stand_at(stand.x, stand.z)
	player.cutscene_frozen = false
	player.flashlight_controller.set("flashlight_input_enabled", true)
	player.flashlight_controller.set("flashlight_on", true)
	map.interact(player)
	_expect(pinned.stage != PinnedCollectible.Stage.IDLE, "interacting starts the close up, not the taking")
	_expect(not pinned.can_interact(player), "the map cannot be started twice")
	var framed: bool = await _wait_for(func() -> bool: return pinned.stage == PinnedCollectible.Stage.FRAMING, 6.0)
	_expect(framed, "the player walks up to the board and the view frames the map")
	var prompt_up: bool = await _wait_for(func() -> bool: return pinned.collect_prompt != null and pinned.collect_prompt.is_showing(), 3.0)
	_expect(prompt_up, "the Collect row comes up at the bottom")
	# The map is framed almost full screen, so that it can be read where it hangs.
	var camera: Camera3D = player.movement_controller.camera
	var zoomed: bool = await _wait_for(func() -> bool: return camera.fov < 45.0, 3.0)
	_expect(zoomed, "the lens closes in on the paper (%.0f degrees)" % camera.fov)
	await _wait_for(func() -> bool: return absf(camera.fov - float(player.movement_controller.scripted_fov)) < 0.5, 2.0)
	var sheet_size: Vector2 = (map.get_node("Visual/Sheet") as FoldingSheet).sheet_size
	var top: Vector2 = camera.unproject_position(map.global_position + map.global_transform.basis.y * sheet_size.y * 0.5)
	var bottom: Vector2 = camera.unproject_position(map.global_position - map.global_transform.basis.y * sheet_size.y * 0.5)
	var fill: float = absf(bottom.y - top.y) / camera.get_viewport().get_visible_rect().size.y
	_expect(fill > 0.6 and fill < 0.95, "the paper fills %.0f%% of the screen's height" % (fill * 100.0))
	var flashlight: Node = player.flashlight_controller
	_expect((flashlight as Node3D).visible and bool(flashlight.get("scripted_aim_on")), "the flashlight is lit and aimed at the paper while it is read")
	_expect(player.view_locked, "the player's view is held while they look")
	_expect(map.global_transform.is_equal_approx(home), "the map is still attached, where it hangs")
	for pin: Node3D in trail.pins:
		_expect(pin.visible, "%s is still in the board" % pin.name)

	_expect(not player.inventory_controller.has_item("forest_map") and not player.map_controller.has_map(), "and the player does not have it yet")

	# Stepping back leaves everything as it was.
	await _press(&"ui_cancel")
	_expect(pinned.stage == PinnedCollectible.Stage.IDLE, "Esc steps back")
	var back_to_normal: bool = await _wait_for(func() -> bool: return absf(camera.fov - PlayerMovementController.BASE_FOV) < 1.0, 3.0)
	_expect(back_to_normal, "the lens opens again")
	_expect(not pinned.collect_prompt.is_showing(), "the row goes")
	_expect(not player.view_locked and map.can_interact(player), "the player is free and can try again")
	_expect(map.global_transform.is_equal_approx(home) and not player.inventory_controller.has_item("forest_map"), "the map still hangs on the board")

	# Collecting: the pins are worked out, the paper is torn off and held up, all in about four seconds; then it is in the inventory.
	map.interact(player)
	framed = await _wait_for(func() -> bool: return pinned.stage == PinnedCollectible.Stage.FRAMING and pinned.collect_prompt != null and pinned.collect_prompt.is_showing(), 6.0)
	_expect(framed, "the close up comes again")
	# Pressing the key does not touch the light: it is lit all through the first moments of the rip (no flicker, no pop).
	var light: Node3D = player.flashlight_controller as Node3D
	var light_energy_before: float = (light as Light3D).light_energy
	var went_dark: bool = false
	var energy_jump: float = 0.0
	var last_energy: float = light_energy_before
	await _press(&"interact")
	for i: int in 45:
		if not light.visible:
			went_dark = true

		energy_jump = maxf(energy_jump, absf((light as Light3D).light_energy - last_energy))
		last_energy = (light as Light3D).light_energy
		await get_tree().process_frame

	_expect(pinned.stage == PinnedCollectible.Stage.TAKING and pinned.is_being_removed, "E collects it: the rip scene plays")
	_expect(camera.fov < 45.0 and float(player.movement_controller.scripted_fov) < 45.0, "the frame is kept: the lens stays closed in on the paper while the pins are worked out (%.0f degrees)" % camera.fov)
	_expect(not went_dark, "the flashlight stays lit when it is collected")
	_expect(energy_jump < 0.01, "and its strength does not change (%.3f)" % energy_jump)
	_expect(not player.inventory_controller.has_item("forest_map") and not player.map_controller.has_map(), "the map is not the player's yet: it is still on the board")
	map.interact(player)
	_expect(not inspect.is_open(), "taking it twice does nothing")
	var inspected: bool = await _wait_for(func() -> bool: return inspect.is_open(), 8.0)
	_expect(inspected, "the map is shown to the player when the pins are out and the paper is in their hands")
	_expect(not player.view_locked and not player.scripted_flashlight, "and the view is given back")
	var lens_open: bool = await _wait_for(func() -> bool: return absf(camera.fov - PlayerMovementController.BASE_FOV) < 2.0, 3.0)
	_expect(lens_open, "with the lens open again, as the paper came to the hands (%.0f degrees)" % camera.fov)
	_expect(inspect.is_walkable_view() and not inspect.blocks_gameplay(), "the first view, straight after taking it, is one the player can walk with")
	_expect(player.map_controller.has_map(), "the player has the map")
	_expect(not player.inventory_controller.has_item("forest_map"), "and it is not an item of the inventory")
	_expect(bool(SaveManager.get_state_value(&"collectibles", &"forest_map", false)), "it counts as taken, so it never hangs on the board again")
	for pin: Node3D in [trail.pins[0], trail.pins[1]]:
		_expect(not pin.visible, "%s went with the paper" % pin.name)

	for pin: Node3D in [trail.pins[2], trail.pins[3]]:
		_expect(pin.visible, "%s stays in the board, with a scrap of the paper under it" % pin.name)

	# The first view is of the paper open, as it was on the board: it is not folded and unfolded.
	_expect(inspect.state != PlayerInspectController.InspectState.PREPARING, "the first view does not fold the paper first")
	var rig: FoldingSheet = inspect._fold_rig as FoldingSheet
	_expect(rig != null, "the inspect view found the sheet that folds")
	if rig == null:
		return

	var rig_ref: WeakRef = weakref(rig)
	var viewing: bool = await _wait_for(func() -> bool: return inspect.state == PlayerInspectController.InspectState.VIEWING, 4.0)
	_expect(viewing, "it settles in front of the player")
	_expect(opened_signals.has("forest_map"), "the view reports it opened")
	var kept_open: bool = true
	for i: int in 30:
		if _closedness(rig_ref) > 0.001 or _moving(rig_ref):
			kept_open = false

		await get_tree().process_frame

	_expect(kept_open, "it stays open, as it was on the sign")
	_expect(not is_instance_valid(map) or map.is_queued_for_deletion(), "the map is gone from the board")

	# The first time it is put away it folds, then goes.
	inspect.close()
	_expect(inspect.state == PlayerInspectController.InspectState.FOLDING, "put away for the first time, it folds first")
	_expect(closed_signals.has("forest_map"), "the view reports it closed as it starts to go")
	var folded_again: bool = await _wait_for(func() -> bool: return _closedness(rig_ref) >= 0.999, 3.0)
	_expect(folded_again, "it folds small before it is put away")
	var gone: bool = await _wait_for(func() -> bool: return inspect.state == PlayerInspectController.InspectState.CLOSED, 3.0)
	_expect(gone and not inspect.is_open(), "the view is closed when the map has folded and gone")

	# The lesson of the map key starts: the player is told how to look at it again (and not about the inventory: nothing was put in it).
	var hints: TutorialHintController = player.get_node_or_null("TutorialHints") as TutorialHintController
	_expect(hints != null, "the player has the tutorial hints")
	if hints != null:
		var lesson: bool = await _wait_for(func() -> bool: return hints.is_lesson_showing(&"map"), hints.lesson_delay + 4.0)
		_expect(lesson, "once the map is put away the lesson of the map key comes up")
		_expect(not hints.is_lesson_showing(&"inventory"), "and the inventory is not taught for the map")


## The map in the hands is a view the player walks with: nothing holds them, the mouse stays captured, the flashlight works, and it fills the
## screen ALWAYS, standing or walking (on purpose: it blocks the view, so that the player puts it away after a while). Esc puts it away.
func _check_walking_with_the_map() -> void:
	var inspect: PlayerInspectController = player.inspect_controller
	_expect(inspect.is_walkable_view() and not inspect.blocks_gameplay(), "the map is a view the player walks with")
	_expect(not inspect.keep_mouse_visible_on_finish, "and it leaves the mouse captured (a headless run cannot read the mode itself)")
	_expect(not player.is_flashlight_blocked(), "and the flashlight works")
	# (The opening cinematic still holds the camera in this fixture: let go of it, as the end of the intro does.)
	for node: Node in level.find_children("*", "", true, false) + [level]:
		if node.has_method("skip_opening"):
			node.call("skip_opening")
			break

	player.cutscene_frozen = false
	player.movement_controller.end_cutscene_camera_control()
	await get_tree().create_timer(0.8).timeout
	var camera: Camera3D = player.movement_controller.camera
	var screen: Vector2 = camera.get_viewport().get_visible_rect().size
	var still_fill: float = _fill_of(inspect, camera, screen)
	var still_middle: float = camera.unproject_position(inspect.get_item_center_world()).y / screen.y
	# It fills the height of the screen, or all the width a narrow window has (a headless window is square and tiny).
	var wide_enough: float = 0.85 if screen.x / screen.y > 1.6 else 0.7
	_expect(still_fill > wide_enough, "standing, the map fills the screen (%.0f%% of its height)" % (still_fill * 100.0))
	_expect(still_middle > 0.4 and still_middle < 0.55, "and sits in the middle, a little high so that the bottom row is clear (%.2f)" % still_middle)
	var start: Vector3 = player.global_position
	Input.action_press("up")
	await get_tree().create_timer(1.3).timeout
	var walking_fill: float = _fill_of(inspect, camera, screen)
	var walking_middle: float = camera.unproject_position(inspect.get_item_center_world()).y / screen.y
	var walked: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	Input.action_release("up")
	_expect(walked > 0.5, "the player walks with the map open (%.2f m)" % walked)
	_expect(inspect.is_walkable_view() and player.map_controller.is_open, "and it stays open")
	_expect(absf(walking_fill - still_fill) < 0.03 and absf(walking_middle - still_middle) < 0.03, "and it fills the screen just as much while they walk (%.0f%%, %.2f): it is not lowered to leave the way in sight" % [walking_fill * 100.0, walking_middle])
	await get_tree().create_timer(1.0).timeout
	_expect(absf(_fill_of(inspect, camera, screen) - still_fill) < 0.03, "and when they stop")


## How much of the screen's height the held item takes: its height at its own scale, as seen from the camera.
func _fill_of(inspect: PlayerInspectController, camera: Camera3D, screen: Vector2) -> float:
	var middle: Vector3 = inspect.get_item_center_world()
	var up: Vector3 = camera.global_basis.y
	var half: float = inspect._item_extent.y * 0.5
	return absf(camera.unproject_position(middle - up * half).y - camera.unproject_position(middle + up * half).y) / screen.y


func _check_it_is_kept() -> void:
	var inspect: PlayerInspectController = player.inspect_controller

	# Kept across a save: the game remembers the player has it (so the board stays bare), and the model is built from its scene.
	_expect(bool(SaveManager.get_state_value(&"collectibles", &"forest_map", false)), "the saved game knows the player has the map")
	var again: PlayerMapController = PlayerMapController.new()
	player.add_child(again)
	again.setup(player)
	_expect(again.has_map(), "a player loaded from it has the map")
	again.queue_free()

	# The map key looks at it at any time: out of the pocket it is folded, and it opens out; the key puts it away again.
	await _press(&"map")
	_expect(player.map_controller.is_open and inspect.is_open(), "the map key opens the map")
	var rig: FoldingSheet = inspect._fold_rig as FoldingSheet
	_expect(rig != null and rig.closedness >= 0.999, "out of the pocket it is folded small")
	var rig_ref: WeakRef = weakref(rig)
	var viewing: bool = await _wait_for(func() -> bool: return inspect.state == PlayerInspectController.InspectState.VIEWING, 3.0)
	_expect(viewing, "it comes to the view")
	var unfolded: bool = await _wait_for(func() -> bool: return _closedness(rig_ref) <= 0.001, 4.0)
	_expect(unfolded, "and opens out")
	await _check_walking_with_the_map()
	await _press(&"map")
	_expect(not player.map_controller.is_open, "the map key closes it")
	var put_away: bool = await _wait_for(func() -> bool: return inspect.state == PlayerInspectController.InspectState.CLOSED, 4.0)
	_expect(put_away and not inspect.is_open(), "and it folds and goes")
	_expect(not player.inventory_controller.has_item("forest_map"), "it was never in the inventory")

	# The inventory key does not show it.
	await _press(&"inventory")
	_expect(not player.map_controller.is_open, "the inventory key does not open the map")
	if player.inventory_ui_controller.is_inventory_open():
		player.inventory_ui_controller.close()

	await get_tree().process_frame
	_expect(player.map_controller.open(), "the map can also be opened by script")
	await _wait_for(func() -> bool: return inspect.state == PlayerInspectController.InspectState.VIEWING, 3.0)

	# Put away while it is still open: it folds, and goes.
	inspect.close()
	var folded: bool = await _wait_for(func() -> bool: return inspect.state == PlayerInspectController.InspectState.CLOSED, 4.0)
	_expect(folded, "it goes away again")

	# Pressed too early: a map that has just been taken (here: one that comes from a place in the world) is still being
	# folded up in the hand. The press is kept, not lost: it is put away as soon as it has come to the view, still folded.
	var from_the_world: Transform3D = player.get_node("Head/Camera3D").global_transform
	var taken: bool = player.map_controller.open(from_the_world)
	_expect(taken and inspect.state == PlayerInspectController.InspectState.PREPARING, "a map taken from the world is first folded in the hand")
	var early_ref: WeakRef = weakref(inspect._fold_rig)
	inspect.close()
	_expect(inspect.state == PlayerInspectController.InspectState.PREPARING, "closing too early does not break the folding")
	# It starts flat and folds in the hand; from the moment it is folded small it must stay so.
	var folded_small: Array[bool] = [false]
	var opened_again: Array[bool] = [false]
	var closed_by_itself: bool = await _wait_for(func() -> bool:
		if early_ref.get_ref() != null:
			if _closedness(early_ref) >= 0.999:
				folded_small[0] = true
			elif folded_small[0]:
				opened_again[0] = true

		return inspect.state == PlayerInspectController.InspectState.CLOSED, 4.0)
	_expect(closed_by_itself and not inspect.is_open(), "the press is kept: it is put away as soon as it has come to the view")
	_expect(folded_small[0] and not opened_again[0], "and once it was folded it never opened out on the way")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
