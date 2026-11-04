extends Node

## Builds the ruined signal tower (`SignalTowerBuilder`, its furniture `SignalTowerProps`) and checks it:
## the shape of the two levels, the front door (not locked: it opens like any door, and a key an old save
## still carries is left alone), the stairs up to the balcony walked with the real player, the children's
## headquarters (its three zones: the desk with the Scraped Knee, its lamp and its drawer with Juliana's note,
## the bench with Sophia's folded letter, the shelf with the empty tin), the levers, the decay (broken panes,
## the roof breach, the ivy) and that every clue can be reached by an interaction ray. Run it as a scene; it
## quits by itself with a non-zero exit code on failure.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_signal_tower_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/signal_tower_playtest.tscn"
const TIME_SCALE: float = 3.0

var test_failed: bool = false
var tower: SignalTowerBuilder = null
var player: CharacterBody3D = null
var space: PhysicsDirectSpaceState3D = null


func _ready() -> void:
	DoorController.approach_enabled = false
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "tower_test_start", "SAVE_LOCATION_DREAM_INTRO")
	GameSettings.set_captions_enabled(true, false)

	var level: Node3D = Node3D.new()
	add_child(level)
	var ground: StaticBody3D = StaticBody3D.new()
	var ground_shape: CollisionShape3D = CollisionShape3D.new()
	var ground_box: BoxShape3D = BoxShape3D.new()
	ground_box.size = Vector3(60.0, 1.0, 60.0)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(ground_shape)
	level.add_child(ground)

	tower = (load("res://scenes/levels/signal_tower.tscn") as PackedScene).instantiate() as SignalTowerBuilder
	level.add_child(tower)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	level.add_child(player)
	player.global_position = Vector3(3.0, 1.1, 5.6)
	var setup: PlayTestSetup = PlayTestSetup.new()
	setup.player = player
	level.add_child(setup)

	for i: int in 12:
		await get_tree().physics_frame

	space = level.get_world_3d().direct_space_state
	Engine.time_scale = TIME_SCALE
	await _run()
	Engine.time_scale = 1.0

	SaveManager.delete_slot(1)
	print("SIGNAL_TOWER_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	_check_shape()
	_check_the_doors()
	_check_props()
	_check_zones()
	_check_decay()
	await _check_the_stairs()
	await _check_the_cabinet()
	await _check_opening_the_front_door()
	await _check_the_drawer()
	await _read_the_notes()
	_check_translations()


# ============================================================
# THE SHAPE
# ============================================================

func _check_shape() -> void:
	var model: Node = tower.get_node_or_null("Shell/Model")
	_expect(model != null and model.scene_file_path == "res://assets/models/buildings/signal_box_ruined/signal_box_ruined.glb", "the building is the ready-made signal box model")
	_expect(tower.get_node_or_null("LowerShell") == null and tower.get_node_or_null("UpperShell") == null and tower.get_node_or_null("Roof") == null, "and no blockout of CSG shapes is left")
	var shell_shape: CollisionShape3D = tower.get_node_or_null("Shell/ShellBody/CollisionShape3D") as CollisionShape3D
	_expect(shell_shape != null and shell_shape.shape is ConcavePolygonShape3D and (shell_shape.shape as ConcavePolygonShape3D).get_faces().size() > 3000, "it has collision made of its own triangles")
	var materials: Array[String] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			materials.append(mesh.surface_get_material(surface).resource_name)
	_expect(materials.has("roof_tiles") and materials.has("glass") and materials.has("bars"), "a tiled roof, panes and window bars are part of it")

	# The rooms, measured with rays from inside (at heights and places where no window or door is): 4 m by 4 m, 2 m either way from the middle.
	var inside: Vector3 = Vector3(0.0, 1.3, -1.4)
	var back: Vector3 = _first_hit(inside, inside + Vector3(0.0, 0.0, -6.0))
	var right: Vector3 = _first_hit(Vector3(0.0, 1.3, 1.65), Vector3(6.0, 1.3, 1.65))
	var left: Vector3 = _first_hit(inside, inside + Vector3(-6.0, 0.0, 0.0))
	var front: Vector3 = _first_hit(Vector3(1.5, 1.3, 0.0), Vector3(1.5, 1.3, 6.0))
	_expect(absf(front.z - 2.0) < 0.03 and absf(back.z + 2.0) < 0.03, "the relay room is 4 m deep (front %.2f, back %.2f)" % [front.z, back.z])
	_expect(absf(left.x + 2.0) < 0.03 and absf(right.x - 2.0) < 0.03, "and 4 m wide (left %.2f, right %.2f)" % [left.x, right.x])
	var outer: Vector3 = _first_hit(Vector3(1.6, 1.3, 6.0), Vector3(1.6, 1.3, -6.0))
	_expect(absf(outer.z - SignalTowerBuilder.WALL_FACE) < 0.06, "its brick walls are 0.25 m thick (outer face of the front wall %.2f)" % outer.z)

	# Inside: boards at the foot, the deck's underside at 2.9 m, and the cabin floor on top at 3.006 m.
	var floor_hit: Vector3 = _first_hit(Vector3(0.3, 2.0, 0.6), Vector3(0.3, -1.0, 0.6))
	var ceiling_hit: Vector3 = _first_hit(Vector3(0.3, 1.0, 0.6), Vector3(0.3, 4.0, 0.6))
	var cabin_floor: Vector3 = _first_hit(Vector3(0.3, 4.0, 0.6), Vector3(0.3, 1.0, 0.6))
	_expect(absf(floor_hit.y - SignalTowerBuilder.FLOOR_TOP) < 0.01, "the relay room has a floor of boards at %.3f m" % floor_hit.y)
	_expect(absf(ceiling_hit.y - 2.9) < 0.03, "its ceiling is the underside of the deck, 2.9 m up (%.2f)" % ceiling_hit.y)
	_expect(absf(cabin_floor.y - SignalTowerBuilder.BASE_HEIGHT) < 0.02, "the cabin's floor is the deck's top at %.3f m (%.3f)" % [SignalTowerBuilder.BASE_HEIGHT, cabin_floor.y])

	# The cabin is 4 m by 4 m as well, under a pitched roof (the ridge is along X, 7.4 m up).
	var cabin_inside: Vector3 = Vector3(0.0, 3.6, 0.2)
	var cabin_right: Vector3 = _first_hit(cabin_inside, cabin_inside + Vector3(6.0, 0.0, 0.0))
	_expect(absf(cabin_right.x - 2.0) < 0.1 or cabin_right.x > 5.0, "the control cabin is 4 m wide (right wall at %.2f, or its door or window)" % cabin_right.x)
	var ridge: Vector3 = _first_hit(Vector3(1.7, 9.0, 0.0), Vector3(1.7, 3.5, 0.0))
	_expect(ridge.y > 6.0 or ridge.y < 3.6, "and has a roof over it (the ray from above meets %.2f)" % ridge.y)

	# Narrow arched windows in the brick (a ray through one meets the bars, not the wall) in the left wall, and wide windows in the cabin.
	var through_arch: Vector3 = _first_hit(Vector3(-6.0, 1.5, -0.8), Vector3(6.0, 1.5, -0.8))
	_expect(through_arch.x > -2.2, "the left wall has an arched window (the ray gets to %.2f, past the wall's face at -2.25)" % through_arch.x)
	var ribbon: Vector3 = _first_hit(Vector3(-1.0, 4.4, 8.0), Vector3(-1.0, 4.4, -8.0))
	_expect(ribbon.z < 1.9, "the cabin's front window is open to the inside (the ray goes in to %.2f)" % ribbon.z)

	# The ramp up the +X side, to the balcony (it starts on the ground in front and rises towards the back).
	var foot: Vector3 = _first_hit(Vector3(3.0, 3.0, 3.4), Vector3(3.0, -1.0, 3.4))
	var top: Vector3 = _first_hit(Vector3(3.0, 5.0, -0.6), Vector3(3.0, -1.0, -0.6))
	_expect(foot.y < 0.8 and top.y > 2.6, "a plank ramp rises up the +X side (%.2f m up at the front, %.2f m near the cabin's door)" % [foot.y, top.y])


# ============================================================
# THE DOORS
# ============================================================

func _check_the_doors() -> void:
	var door: DoorController = tower.lower_door
	_expect(not door.is_locked and not door.starts_locked, "the tower's front door is not locked")
	_expect(door.required_key_id.is_empty() and door.locked_line.is_empty(), "it asks for no key, and has no line about one")
	_expect(door.get_prompt_text_for_player(player) == "PROMPT_OPEN", "it offers [E] Open")
	_expect(door.persistent_id == &"signal_tower_front_door", "and is saved as it always was (signal_tower_front_door)")
	_expect(absf(door.global_position.z - SignalTowerBuilder.FRONT_DOOR_Z) < 0.02 and absf(door.global_position.x - (SignalTowerBuilder.DOOR_X - DOOR_WIDTH_FOR_TEST * 0.5)) < 0.02, "it hangs in the front wall's doorway, left of the middle")

	# The door_001 model: its slab, the handle plate and the lever on both faces, with a keyhole each.
	var root: Node3D = door.get_node("Hinge/DoorRoot")
	var slab: MeshInstance3D = root.get_node("DoorMesh") as MeshInstance3D
	_expect(slab.mesh == DoorModel.slab_mesh(), "it is the door model (the slab of door_001)")
	var leaf_width: float = slab.mesh.get_aabb().size.z * slab.transform.basis.get_scale().x
	_expect(absf(leaf_width - SignalTowerBuilder.DOOR_WIDTH) < 0.02, "as wide as the doorway (%.2f m)" % leaf_width)
	_expect(door._hardware.size() == 2, "it has hardware on both faces")
	for face: int in [1, -1]:
		var hardware: DoorHardware = door._hardware[face] as DoorHardware
		_expect(hardware.get_node_or_null("Plate") != null and hardware.get_node_or_null("Lever/Handle") != null, "(face %d: a plate with its keyhole and the lever, a model of its own that turns)" % face)
		_expect(hardware.get_key_slot_global().distance_to(door.global_position) < 1.5, "(and a place for the key)")
	_expect(root.get_node_or_null("DoorNote") == null and tower.find_child("DoorNote", true, false) == null, "no note about a key is pinned to it")

	var upper: DoorController = tower.upper_door
	_expect(not upper.is_locked, "the cabin's balcony door is not locked")
	_expect(upper.global_position.y > 2.9 and upper.global_position.x > 2.0, "it is on the +X side, at the cabin's floor")
	_expect(upper.persistent_id == &"signal_tower_balcony_door", "and keeps its saved name (signal_tower_balcony_door)")


# ============================================================
# THE FURNITURE
# ============================================================

func _check_props() -> void:
	var props: SignalTowerProps = tower.props
	_expect(props != null and tower.get_node("Props") == props, "the furniture is the tower's child Props")

	# The levers: the signal box's own model (twelve levers on a curved plate, none broken), standing in the control cabin with its plate towards the room.
	var frame: Node3D = props.lever_frame
	var lever_model: Node = frame.get_node_or_null("Model")
	_expect(lever_model != null and lever_model.scene_file_path == "res://assets/models/train_related/signal_box_levers/signal_box_levers.glb", "the levers are the signal box model")
	_expect(is_equal_approx(frame.global_position.y, SignalTowerBuilder.BASE_HEIGHT), "standing in the control cabin")
	var mesh_box: AABB = (lever_model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb()
	var in_room: AABB = (lever_model as Node3D).global_transform * mesh_box
	_expect(in_room.position.x > -1.2 and in_room.end.x < 1.2 and in_room.position.z > 0.5 and in_room.end.z < SignalTowerBuilder.ROOM_HALF + 0.01, "wholly inside the cabin, against the front wall (z %.2f to %.2f)" % [in_room.position.z, in_room.end.z])
	_expect(frame.get_node_or_null("FallenLever") == null and frame.find_children("InterlockBar", "MeshInstance3D", true, false).is_empty(), "with none of the old frame's pieces (no snapped lever, no bar)")

	# The relay cabinet: the wooden cabinet of the models, with two doors that are doors.
	var cabinet: WoodCabinet = props.get_node("RelayRoom/RelayCabinet") as WoodCabinet
	_expect(cabinet.get_node("Model").scene_file_path == "res://assets/models/furniture/wood_cabinet_large/wood_cabinet_large.glb", "the relay cabinet is the wooden cabinet model")
	_expect(cabinet.left_door != null and cabinet.right_door != null and cabinet.left_door.persistent_id == &"tower_relay_cabinet_left", "with a left and a right door, saved by name")
	_expect(cabinet.global_basis.x.dot(Vector3.LEFT) > 0.99, "its front faces the room (-X)")

	# The children's headquarters, in the back left corner of the relay room.
	var hq: Node3D = props.get_node("HeadQuarters") as Node3D
	var table: Node3D = hq.get_node("CrateTable") as Node3D
	_expect(table.global_position.x < -0.5 and table.global_position.z < -0.9 and table.global_position.y < 0.1, "a crate table stands in the back left corner of the relay room")
	_expect(table.get_node_or_null("CrateLeft") != null and table.get_node_or_null("CrateRight") != null and table.get_node_or_null("Plank") != null, "made of two crates and a plank")
	var stools: Array[Node] = hq.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Stool"))
	_expect(stools.size() == 2, "with two old stools")
	for stool: Node in stools:
		var spot: Vector3 = (stool as Node3D).global_position
		_expect(absf(spot.x) < 1.65 and absf(spot.z) < 1.65, "%s is inside the room (%.2f, %.2f)" % [stool.name, spot.x, spot.z])

	# What is not there any more: the carved board with the children's names, the chalkboard, the pocket watch and the notebook.
	_expect(props.find_child("CarvedBoard", true, false) == null and props.find_child("Chalkboard", true, false) == null, "no carved board and no chalkboard hang on the walls")
	var written: bool = false
	for label: Node in props.find_children("*", "Label3D", true, false):
		written = written or (label as Label3D).text.contains("HQ")

	_expect(not written, "and nothing is carved or written on them")
	_expect(not props.ground_items.has(&"watch") and not props.ground_items.has(&"sketchbook") and props.find_child("TowerPocketWatch", true, false) == null and props.find_child("TowerSketchbook", true, false) == null, "there is no pocket watch and no notebook")
	_expect(not tower.props.ground_items.is_empty(), "(the headquarters' items are kept by key)")
	_expect(tower.find_children("*", "Inspectable", true, false).size() == 2, "and the two notes of the headquarters are the only things to read in the tower")

	# The relay room: a cabinet and the like.
	_expect(props.get_node("RelayRoom/RelayCabinet") != null and props.get_node("RelayRoom/Barrel") != null, "the relay room has its cabinet and its barrel")
	_expect(props.get_node("Cabin/Stove") != null and props.get_node("Cabin/Desk") != null, "the cabin has a stove and a desk")


# ============================================================
# THE HEADQUARTERS: THREE ZONES
# ============================================================

const GROUND_TEXTS: Dictionary = {
	"juliana_note": ["READABLE_JULIANA_NOTE", "October 1989. The butcher's wife told Sophia at the market that I have dead eyes like the birds that drown in the reservoir during heavy rain. Sophia didn't get angry or shout. She just smiled, took a long bite of her apple, and said, 'Juliana sees the things you're too afraid to look at.' Then she handed me the core and told me to plant it right behind the signal tower so we could watch it grow out of the gravel. She is the only person who doesn't lower her voice when I walk into a room. — Juliana"],
	"sophia_note": ["READABLE_SOPHIA_NOTE", "To the Chief Operator of HQ No. 1: I overheard my father talking to the station master last night. They think the town is going to close the northern line before winter because the ground keeps shifting under the ties. My father said this place is built on a hollow crust that is slowly caving in. I told him he was being paranoid. But if the tracks do collapse and the trains stop coming, we are keeping this tower, Juli. We will lock the bottom door, pull up the stairs, and let the fog swallow the rest of the valley. — Sophia"],
}


## The relay room's three zones, each easy to reach from the open aisle, with nothing solid over what lies in them: the Scraped Knee on
## the desk (the one photograph the album needs from here), Sophia's letter on the bench, the empty tin on the shelf.
func _check_zones() -> void:
	var props: SignalTowerProps = tower.props
	var photos: Dictionary = props.photos
	var knee: Node3D = photos["photo_childhood"]
	_expect(photos.size() == 1 and knee is Collectible, "one photograph lies in the relay room, as a collectible: the Scraped Knee")
	var others: int = 0
	for node: Node in tower.find_children("*", "Collectible", true, false):
		others += 1 if node != knee and str((node as Collectible).item_id).begins_with("photo_") else 0
	_expect(others == 0, "The Broken Lever and The Foggy Platform are no longer in the tower")
	_expect(props.get_node_or_null("HeadQuarters/Lockbox") == null and props.find_child("Lockbox", true, false) == null, "it is not in a box")
	_expect(absf(knee.global_position.x) < 1.8 and absf(knee.global_position.z) < 1.8 and knee.global_position.y < 1.0, "it is inside the room, low enough to reach")

	# Zone 1: the desk. The Scraped Knee lies flat in the middle of the plank; Juliana's note is in the drawer under it.
	var table: Node3D = props.get_node("HeadQuarters/CrateTable")
	var lamp: Node3D = props.desk_lamp
	_expect(lamp != null and table.is_ancestor_of(lamp), "a desk lamp stands on the HQ desk")
	var on_table: Vector3 = table.to_local(knee.global_position)
	_expect(Vector2(on_table.x, on_table.z).length() < 0.12, "the Scraped Knee lies in the middle of the plank (%.2f, %.2f)" % [on_table.x, on_table.z])
	_expect(knee.global_basis.z.dot(Vector3.UP) > 0.99 and absf(on_table.y - 0.7435) < 0.006, "flat, face up, on the plank's top (%.3f)" % on_table.y)
	var from_lamp: Vector2 = Vector2(knee.global_position.x - lamp.global_position.x, knee.global_position.z - lamp.global_position.z)
	_expect(from_lamp.length() > 0.25, "and not propped against the lamp (%.2f m from its stem)" % from_lamp.length())
	var drawer: DeskDrawer = props.desk_drawer
	_expect(drawer != null and drawer.get_parent() == table, "a drawer is built into the desk, under the plank")
	var juliana_note: Node3D = props.ground_items[&"juliana_note"]
	_expect(juliana_note != null and drawer.is_ancestor_of(juliana_note) and juliana_note.global_basis.z.dot(Vector3.UP) > 0.99, "Juliana's note lies in the drawer, face up")
	_expect(not drawer.is_open and is_zero_approx(drawer.get_openness()), "and the drawer is shut")
	var note_in_table: Vector3 = table.to_local(juliana_note.global_position)
	_expect(note_in_table.y < 0.7 and absf(note_in_table.x) < 0.2, "under the plank, between the crates (%s)" % str(note_in_table))

	# Zone 2: the wooden bench (the daybed), with Sophia's folded letter on the cushion.
	var daybed: Node3D = props.get_node("HeadQuarters/Daybed")
	var note: Node3D = props.ground_items[&"sophia_note"]
	_expect(daybed.is_ancestor_of(note) and absf(daybed.to_local(note.global_position).y - 0.4922) < 0.01, "Sophia's folded letter lies on the cushion")
	_expect(note.global_basis.z.dot(Vector3.UP) > 0.99, "lying face up")
	_expect(note.get_visual_node().find_child("Squares", true, false) != null, "it is a sheet of graph paper")
	_expect(props.find_child("WalkieTalkie", true, false) == null and props.find_child("SophiaJacket", true, false) == null, "there is no walkie-talkie and no jacket")
	_expect(knee.global_position.distance_to(note.global_position) > 1.5, "the desk and the bench are separate zones (%.1f m apart)" % knee.global_position.distance_to(note.global_position))

	# Zone 3: the low shelf on the back wall, with an open tin on it, empty now.
	var shelf: Node3D = props.get_node("HeadQuarters/BackShelf")
	var tin: Node3D = props.photo_tin
	_expect(shelf.global_position.y < 0.2 and tin != null and shelf.is_ancestor_of(tin), "a low wooden shelf on the back wall carries an open tin")
	_expect(tin.find_children("*", "Collectible", true, false).is_empty(), "with nothing to pick up in it")

	# Nothing is cluttered: the crates and barrel are in the front left corner, out of the aisle that runs from
	# the door to the three zones, and nothing of the three zones is on the door's side of the room.
	var aisle_clear: bool = true
	for solid: Node in props.find_children("*", "StaticBody3D", true, false):
		var spot: Vector3 = (solid as Node3D).global_position
		if spot.y < 1.0 and absf(spot.x - SignalTowerBuilder.DOOR_X) < 0.3 and spot.z > -0.2:
			aisle_clear = false
	_expect(aisle_clear, "no furniture stands in the way from the door")

	# Every item can be reached by a ray from the aisle: no collider of the floor or of the furniture hides it.
	_ray_finds(knee, knee.global_position + Vector3(0.5, 0.9, 0.9), knee.global_position, "the Scraped Knee on the plank")
	_ray_finds(note, note.global_position + Vector3(-0.8, 0.9, 0.4), note.global_position, "Sophia's note on the cushion")

	# The texts: the written ones, in both languages, with no hyphen.
	for key: String in GROUND_TEXTS:
		var item: Inspectable = props.ground_items[StringName(key)] as Inspectable
		var expected: Array = GROUND_TEXTS[key]
		_expect(str(item.get_visual_node().get_meta("readable_text")) == expected[0] and str(item.get_visual_node().get_meta("inspect_mode")) == "read", "the %s is a document with the words %s" % [key, expected[0]])
		_expect(tr(expected[0]) == expected[1], "the %s says what was written (%s)" % [key, tr(expected[0]).left(24)])
		_expect(not tr(expected[0]).contains("-"), "with no hyphen in it")
	GameSettings.set_text_locale("pt_BR", false)
	var translated: bool = true
	var clean: bool = true
	for key: String in GROUND_TEXTS:
		var key_text: String = (GROUND_TEXTS[key] as Array)[0]
		translated = translated and tr(key_text) != key_text and tr(key_text) != str((GROUND_TEXTS[key] as Array)[1])
		clean = clean and not tr(key_text).contains("-")
	for key_text: String in ["ITEM_JULIANA_NOTE_NAME", "ITEM_JULIANA_NOTE_DESCRIPTION", "ITEM_SOPHIA_NOTE_NAME", "ITEM_SOPHIA_NOTE_DESCRIPTION"]:
		translated = translated and tr(key_text) != key_text
	_expect(translated, "all of it is translated into Portuguese")
	_expect(clean, "with no hyphen there either")
	GameSettings.set_text_locale("en", false)


## Pressing the interact key on an open document shows its words in the clean text overlay.
func _read_the_notes() -> void:
	player.global_position = Vector3(1.0, 3.4, 0.5)
	var inspect: PlayerInspectController = player.inspect_controller
	var documents: Dictionary = {}
	for key: String in GROUND_TEXTS:
		documents[key] = [tower.props.ground_items[StringName(key)], (GROUND_TEXTS[key] as Array)[0]]
	for key: String in documents:
		var item: Inspectable = (documents[key] as Array)[0] as Inspectable
		var text_key: String = (documents[key] as Array)[1]
		item.interact(player)
		await _wait(0.9)
		_expect(inspect.is_open(), "the %s opens the inspect view" % key)
		_expect(inspect.has_document_text() and inspect.get_document_text_key() == text_key, "which offers to read it")
		inspect.readables.activate()
		await _wait(1.6)
		_expect(inspect.readables.is_reading(), "pressing the key opens the text overlay")
		_expect(inspect.readables._body.text == tr(text_key), "showing the %s's words" % key)
		inspect.readables.close_text()
		await _wait(0.6)
		inspect.close(false)
		player.inventory_ui_controller.close()
		await _wait(0.6)


# ============================================================
# DECAY
# ============================================================

func _check_decay() -> void:
	# (The broken panes, the missing tiles and the cracks are the model's own.)
	_expect(tower.get_node("Rubble").get_child_count() >= 20, "tiles and bricks lie fallen on the ground (%d pieces)" % tower.get_node("Rubble").get_child_count())
	var inside_walls: int = 0
	for piece: Node in tower.get_node("Rubble").get_children():
		var spot: Vector3 = (piece as Node3D).position
		if maxf(absf(spot.x), absf(spot.z)) < SignalTowerBuilder.WALL_FACE:
			inside_walls += 1
	_expect(inside_walls == 0, "none of them lies inside a wall (%d)" % inside_walls)

	var leaves: MultiMeshInstance3D = tower.get_node("Ivy/Leaves") as MultiMeshInstance3D
	var stems: MultiMeshInstance3D = tower.get_node("Ivy/Stems") as MultiMeshInstance3D
	var count: int = leaves.multimesh.instance_count
	_expect(count > 300 and stems.multimesh.instance_count > 100, "ivy creeps on the brick (%d leaves on %d stem pieces)" % [count, stems.multimesh.instance_count])
	var highest: float = 0.0
	var farthest: float = 0.0
	var on_brick: int = 0
	_expect(tower.ivy_leaf_points.size() == count, "(the leaves' places are kept)")
	for spot: Vector3 in tower.ivy_leaf_points:
		highest = maxf(highest, spot.y)
		farthest = maxf(farthest, maxf(absf(spot.x), absf(spot.z)))
		if absf(maxf(absf(spot.x), absf(spot.z)) - (SignalTowerBuilder.WALL_FACE + 0.03)) < 0.2:
			on_brick += 1
	_expect(highest < SignalTowerBuilder.BASE_HEIGHT, "the ivy stays on the brick base (highest leaf %.2f m)" % highest)
	_expect(farthest < SignalTowerBuilder.WALL_FACE + 0.3 and on_brick > int(count * 0.9), "every leaf clings to a wall (%d of %d)" % [on_brick, count])


# ============================================================
# WALKING AND OPENING
# ============================================================

## The real player walks up the stairs to the balcony.
func _check_the_stairs() -> void:
	player.global_position = Vector3(2.75, 1.1, 4.4)
	player.velocity = Vector3.ZERO
	await _wait(0.6)
	Input.action_press(&"up")
	var waited: float = 0.0
	while waited < 14.0 and player.global_position.y < SignalTowerBuilder.BASE_HEIGHT + 0.4:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	await _wait(0.5)
	Input.action_release(&"up")
	_expect(player.global_position.y > SignalTowerBuilder.BASE_HEIGHT + 0.3, "the player walks up the ramp to the balcony (%.2f m up)" % player.global_position.y)
	_expect(player.global_position.z < 0.6 and player.global_position.z > -2.2 and player.global_position.x > 2.3, "and stands on it (%.2f, %.2f)" % [player.global_position.x, player.global_position.z])

	# The balcony door opens: it is not locked.
	var upper: DoorController = tower.upper_door
	upper.animate_player_interaction = false
	upper.interact(player)
	_expect(upper.is_open, "the cabin's door opens for the player")
	await _wait(5.0)
	var through: Vector3 = _first_hit(Vector3(6.0, 4.4, UPPER_DOOR_Z), Vector3(-6.0, 4.4, UPPER_DOOR_Z))
	_expect(through.x < -1.9, "and the way into the cabin is clear (the ray goes in to %.2f)" % through.x)


## The relay cabinet's two doors open out to the room and shut again, like any door.
func _check_the_cabinet() -> void:
	var cabinet: WoodCabinet = tower.props.get_node("RelayRoom/RelayCabinet") as WoodCabinet
	player.global_position = Vector3(0.6, 1.1, -1.2)
	await _wait(0.3)
	for door: DoorController in [cabinet.left_door, cabinet.right_door]:
		var leaf: Node3D = door.get_node("Hinge/DoorRoot/Model") as Node3D
		var shut: Vector3 = leaf.global_position
		_expect(door.get_prompt_text_for_player(player) == "PROMPT_OPEN", "(%s offers [E] Open)" % door.name)
		door.interact(player)
		_expect(door.is_open, "%s opens when used" % door.name)
		await _wait(1.6)
		var moved: Vector3 = leaf.global_position - shut
		var front: Vector3 = cabinet.global_basis.x
		_expect(moved.dot(front) > 0.12 and leaf.global_position.x < 1.7, "and swings OUT of the cabinet, to the room's side (moved %.2f m towards the front)" % moved.dot(front))
		_expect(absf(door.hinge.rotation_degrees.y) > 90.0, "about %d degrees open" % int(absf(door.hinge.rotation_degrees.y)))
		_expect(door.get_prompt_text_for_player(player) == "PROMPT_CLOSE", "and offers [E] Close")
		door.interact(player)
		await _wait(1.6)
		_expect(not door.is_open and absf(door.hinge.rotation_degrees.y) < 1.0, "%s closes again" % door.name)


## The shut front door blocks the way in, and opens like any door. A brass key an old save still carries is left alone: the door neither
## asks for it nor takes it.
func _check_opening_the_front_door() -> void:
	var door: DoorController = tower.lower_door
	door.animate_player_interaction = false
	var shut: Vector3 = _first_hit(Vector3(SignalTowerBuilder.DOOR_X, 1.0, 6.0), Vector3(SignalTowerBuilder.DOOR_X, 1.0, -1.5))
	_expect(shut.z > 1.7, "the shut door blocks the way in (%.2f)" % shut.z)

	var key: Collectible = (load("res://scenes/objects/signal_tower/brass_signal_key.tscn") as PackedScene).instantiate() as Collectible
	add_child(key)
	_expect(key.item_id == "brass_signal_key" and key.item_name == "ITEM_BRASS_SIGNAL_KEY_NAME", "an old save's brass signal key is still an item")
	key.interact(player)
	await _wait(0.5)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)
	_expect(player.has_inventory_item("brass_signal_key"), "which goes in the inventory")
	_expect(door.get_prompt_text_for_player(player) == "PROMPT_OPEN", "the door still offers only [E] Open")
	door.interact(player)
	_expect(not door.is_locked and door.is_open, "it opens")
	_expect(player.has_inventory_item("brass_signal_key"), "and the key is still in the hands: it was not used")
	await _wait(6.0)
	var open: Vector3 = _first_hit(Vector3(SignalTowerBuilder.DOOR_X, 1.0, 6.0), Vector3(SignalTowerBuilder.DOOR_X, 1.0, -1.9))
	_expect(open.z < -1.7, "the way into the relay room is clear (the ray goes in to %.2f)" % open.z)
	var top: Vector3 = _first_hit(Vector3(SignalTowerBuilder.DOOR_X, 1.95, 6.0), Vector3(SignalTowerBuilder.DOOR_X, 1.95, -1.9))
	_expect(top.z < -1.7, "up to the door's full height (%.2f)" % top.z)


## The desk's drawer. Its motion is a small simulation (a hand pulling through a spring, wood that holds and then lets go, a stop it knocks against twice),
## played by the drawer and made into its sound. Aimed at, it opens with a scrape and a knock and shows Juliana's note (which cannot be aimed at while
## the drawer is shut), and it shuts again.
func _check_the_drawer() -> void:
	var drawer: DeskDrawer = tower.props.desk_drawer
	var table: Node3D = drawer.get_parent() as Node3D
	var note: Inspectable = tower.props.ground_items[&"juliana_note"] as Inspectable

	# The motion that is played: from rest, a hold, a break away, a run, a knock against the stop, a second softer one, and still.
	var pull: Dictionary = DeskDrawer.get_profile(true, drawer.travel)
	var covered: PackedFloat32Array = pull["x"]
	var speeds: PackedFloat32Array = pull["v"]
	var hits: Array = pull["hits"]
	_expect(absf(covered[covered.size() - 1] - drawer.travel) < 0.004, "pulled open, it ends at its stop (%.3f of %.3f m)" % [covered[covered.size() - 1], drawer.travel])
	_expect(float(pull["seconds"]) > 0.6 and float(pull["seconds"]) < 1.6, "in about a second (%.2f s)" % float(pull["seconds"]))
	_expect(hits.size() >= 2 and (hits[0] as Vector2).y > 0.3 and (hits[1] as Vector2).y < (hits[0] as Vector2).y, "it knocks against the stop and again, softer (%d knocks)" % hits.size())
	var top_speed: float = 0.0
	for speed: float in speeds:
		top_speed = maxf(top_speed, speed)

	_expect(top_speed > 0.3 and top_speed < 0.9, "it runs at a hand's pace, %.2f m/s at most" % top_speed)
	_expect(speeds[int(0.03 / DeskDrawer.RECORD_STEP)] < 0.02, "it holds on its runners for a moment before it breaks away")
	var shut_hits: Array = DeskDrawer.get_profile(false, drawer.travel)["hits"]
	_expect(not shut_hits.is_empty() and (shut_hits[0] as Vector2).y >= (hits[0] as Vector2).y, "pushed shut it is hit at least as hard")

	# Shut: what is in it cannot be aimed at, and the front is what a ray from the room meets.
	await get_tree().process_frame
	await get_tree().process_frame
	var note_areas: Array[Node] = note.find_children("*", "CollisionShape3D", true, false)
	var reachable: bool = false
	for shape: Node in note_areas:
		reachable = reachable or not (shape as CollisionShape3D).disabled

	_expect(not note_areas.is_empty() and not reachable, "while the drawer is shut the note has no area to be aimed at")
	var front: Vector3 = table.to_global(Vector3(0.0, 0.632, 0.36))
	_ray_finds(drawer, front + table.global_basis.z * 0.7 + Vector3(0.0, 0.5, 0.0), front, "the drawer's front")
	_expect(drawer.can_interact(player) and drawer.get_prompt_text() == "PROMPT_OPEN" and tr("PROMPT_OPEN").ends_with("] Open"), "aimed at, it offers [E] Open")

	# Pulled open.
	var shut_at: Vector3 = drawer.slide.global_position
	drawer.interact(player)
	_expect(drawer.is_moving and not drawer.can_interact(player), "[E] sets it moving, and it is not used again meanwhile")
	# (The lean comes and goes within the pull, and at three times the speed a slow frame can miss it: it is the deepest lean seen that counts.)
	var deepest_lean: float = 0.0
	var pulled_for: float = 0.0
	var pull_movement: Object = player.get("movement_controller") as Object
	while pulled_for < 0.45:
		await get_tree().process_frame
		pulled_for += get_process_delta_time()
		deepest_lean = minf(deepest_lean, (pull_movement.get("gesture_offset") as Vector3).z)
	var mid: float = drawer.get_openness()
	_expect(mid > 0.1 and mid < 0.95 and drawer.is_moving, "it is on its way (%.0f%% out)" % (mid * 100.0))
	var sound: AudioStreamPlayer3D = drawer.get_node("Sound") as AudioStreamPlayer3D
	_expect(sound.playing and sound.stream != null and sound.stream.get_length() > 0.8, "its scrape and its knocks sound (%.2f s)" % (sound.stream.get_length() if sound.stream != null else 0.0))
	var movement: Object = player.get("movement_controller") as Object
	_expect(movement != null and deepest_lean < -0.005, "the player leans in while they pull (%.3f m)" % deepest_lean)
	var waited: float = 0.0
	while drawer.is_moving and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	await _wait(0.3)
	_expect(drawer.is_open and is_equal_approx(drawer.get_openness(), 1.0), "it comes to rest at its stop")
	_expect(absf(drawer.slide.global_position.distance_to(shut_at) - drawer.travel) < 0.01, "%.0f cm out of the desk" % (drawer.travel * 100.0))
	_expect(drawer.get_prompt_text() == "PROMPT_CLOSE" and tr("PROMPT_CLOSE").ends_with("] Close"), "and now it offers [E] Close")
	_expect(bool((SaveManager.get_state_value(&"drawers", &"tower_desk_drawer", {}) as Dictionary).get("is_open", false)), "that it is open is kept in the save")
	_expect(movement != null and (movement.get("gesture_offset") as Vector3).length() < 0.01, "the player has straightened up")

	# The note is out where it can be seen and aimed at.
	var out: Vector3 = table.to_local(note.global_position)
	_expect(out.z > 0.4 and out.y < 0.7, "Juliana's note lies in the open part of the drawer, past the plank's edge (%s)" % str(out))
	reachable = false
	for shape: Node in note_areas:
		reachable = reachable or not (shape as CollisionShape3D).disabled

	_expect(reachable, "and it can be aimed at again")
	_ray_finds(note, note.global_position + table.global_basis.z * 0.7 + Vector3(0.0, 0.8, 0.0), note.global_position, "Juliana's note in the open drawer")
	_ray_finds(drawer, drawer.slide.global_position + table.global_basis.z * 0.9 + Vector3(0.0, 0.1, 0.0), drawer.slide.global_position + table.global_basis.z * 0.26, "the open drawer's front")
	note.interact(player)
	await _wait(0.8)
	_expect(player.inspect_controller.is_open(), "the note opens in the inspect view")
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)

	# And shut again.
	drawer.interact(player)
	waited = 0.0
	while drawer.is_moving and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	await _wait(0.3)
	_expect(not drawer.is_open and is_zero_approx(drawer.get_openness()) and drawer.slide.global_position.distance_to(shut_at) < 0.003, "pushed shut, it is flush with the desk again")
	reachable = false
	for shape: Node in note_areas:
		reachable = reachable or not (shape as CollisionShape3D).disabled

	_expect(not reachable, "and the note is out of reach again")
	_expect(not bool((SaveManager.get_state_value(&"drawers", &"tower_desk_drawer", {}) as Dictionary).get("is_open", true)), "(that it is shut is kept too)")


## The brass key's texts stay, in both languages: an old save may still carry one in the inventory.
func _check_translations() -> void:
	_expect(tr("ITEM_BRASS_SIGNAL_KEY_NAME") == "Brass Signal Key", "the old key's name, in English")
	GameSettings.set_text_locale("pt_BR", false)
	var all_translated: bool = true
	for key: String in ["ITEM_BRASS_SIGNAL_KEY_NAME", "ITEM_BRASS_SIGNAL_KEY_DESCRIPTION"]:
		all_translated = all_translated and tr(key) != key
	_expect(all_translated, "and its name and description in Portuguese")
	GameSettings.set_text_locale("en", false)


# ============================================================
# HELPERS
# ============================================================

const UPPER_DOOR_Z: float = SignalTowerBuilder.UPPER_DOOR_Z
const DOOR_WIDTH_FOR_TEST: float = SignalTowerBuilder.DOOR_WIDTH


## Where a ray from `from` towards `to` first meets something solid (areas ignored); `to` if nothing.
func _first_hit(from: Vector3, to: Vector3) -> Vector3:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return hit["position"] as Vector3 if not hit.is_empty() else to


## A ray from an eye at `eye` to `aim`, as the interaction ray would run (areas as well as solids): the first
## thing it meets must be `item`.
func _ray_finds(item: Node, eye: Vector3, aim: Vector3, what: String) -> void:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, aim + (aim - eye).normalized() * 0.1)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	var collider: Node = hit.get("collider") as Node
	var found: Node = collider
	while found != null and not found is Interactable:
		found = found.get_parent()

	_expect(
		found == item,
		"an interaction ray reaches %s (hit %s)" % [what, str(collider.get_path()) if collider != null else "nothing"]
	)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
