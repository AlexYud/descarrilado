extends Node

## Builds the ruined signal tower (`SignalTowerBuilder`, its furniture `SignalTowerProps`) and checks it:
## the shape of the two levels, the locked door and the key that opens it, the stairs up to the balcony
## walked with the real player, the children's headquarters (its three zones, each with a photograph, the desk
## lamp, the bench with its folded letter, the desk's drawer with Juliana's note, the shelf with the tin,
## with the three photographs), the levers, the decay (broken panes, the roof breach, the ivy) and that
## every clue can be reached by an interaction ray. The notes' words are checked here for the door and in
## the fig clearing test for the camp. Run it as a scene; it quits by itself with a non-zero exit code on failure.

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
	player.global_position = Vector3(2.75, 1.1, 4.4)
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
	_check_doors_and_key_logic()
	_check_props()
	_check_zones()
	_check_lore_items()
	_check_decay()
	_check_clues_are_reachable()
	await _check_the_stairs()
	await _check_the_key_and_the_doors()
	await _check_the_drawer()
	await _check_the_door_note()
	await _read_the_lore()
	_check_translations()


# ============================================================
# THE SHAPE
# ============================================================

func _check_shape() -> void:
	_expect(SignalTowerBuilder.BASE_SIZE == 4.0 and SignalTowerBuilder.BASE_HEIGHT == 2.8, "the lower level is 4 m by 4 m and 2.8 m high with its deck")
	_expect(tower.get_node_or_null("LowerShell") is CSGCombiner3D and tower.get_node_or_null("UpperShell") is CSGCombiner3D, "both levels are CSG blockouts")

	# The walls, measured with rays (at heights and places where no window or door is).
	var front: Vector3 = _first_hit(Vector3(1.6, 1.3, 6.0), Vector3(1.6, 1.3, -6.0))
	var back: Vector3 = _first_hit(Vector3(1.6, 1.3, -6.0), Vector3(1.6, 1.3, 6.0))
	var left: Vector3 = _first_hit(Vector3(-6.0, 1.3, 1.6), Vector3(6.0, 1.3, 1.6))
	var right: Vector3 = _first_hit(Vector3(6.0, 1.3, -1.5), Vector3(-6.0, 1.3, -1.5))
	_expect(absf(front.z - 2.0) < 0.03 and absf(back.z + 2.0) < 0.03, "the brick base is 4 m deep (front %.2f, back %.2f)" % [front.z, back.z])
	_expect(absf(left.x + 2.0) < 0.03 and absf(right.x - 2.0) < 0.03, "and 4 m wide (left %.2f, right %.2f)" % [left.x, right.x])

	# Inside: boards at the foot, a ceiling 2.6 m up (the deck's underside), and the cabin floor on top at 2.8 m.
	var floor_hit: Vector3 = _first_hit(Vector3(0.3, 2.0, 0.6), Vector3(0.3, -1.0, 0.6))
	var ceiling_hit: Vector3 = _first_hit(Vector3(0.3, 1.0, 0.6), Vector3(0.3, 4.0, 0.6))
	var cabin_floor: Vector3 = _first_hit(Vector3(0.3, 8.0, 0.6), Vector3(0.3, 1.0, 0.6))
	_expect(absf(floor_hit.y - SignalTowerBuilder.FLOOR_TOP) < 0.01, "the relay room has a floor of boards at %.2f m" % floor_hit.y)
	_expect(absf(ceiling_hit.y - 2.6) < 0.02, "its ceiling is the underside of the deck, 2.6 m up (%.2f)" % ceiling_hit.y)
	_expect(absf(cabin_floor.y - 2.8) < 0.02, "the cabin's floor is the deck's top at 2.8 m (%.2f)" % cabin_floor.y)

	# The cabin overhangs the brick by 0.2 m all round and has walls up to 5.2 m.
	var cabin_left: Vector3 = _first_hit(Vector3(-6.0, 4.0, -1.8), Vector3(6.0, 4.0, -1.8))
	var cabin_back: Vector3 = _first_hit(Vector3(-1.9, 4.0, -6.0), Vector3(-1.9, 4.0, 6.0))
	_expect(absf(cabin_left.x + 2.2) < 0.03 and absf(cabin_back.z + 2.2) < 0.03, "the control cabin is 4.4 m wide, 0.2 m over the brick (left %.2f, back %.2f)" % [cabin_left.x, cabin_back.z])

	# Narrow arched windows in the brick (a ray through one passes the wall) and ribbon windows in the cabin.
	var through_arch: Vector3 = _first_hit(Vector3(-6.0, 1.5, 0.85), Vector3(6.0, 1.5, 0.85))
	_expect(through_arch.x > -0.5 or through_arch.x < -1.7 and through_arch.x > -2.0, "the left wall has arched windows through it (bars aside, the ray goes in: %.2f)" % through_arch.x)
	var ribbon: Vector3 = _first_hit(Vector3(0.3, 4.4, 8.0), Vector3(0.3, 4.4, -8.0))
	_expect(ribbon.z < 1.9, "the cabin's front window is open to the inside (the ray goes in to %.2f)" % ribbon.z)
	for side_name: String in ["Front", "Back", "Left"]:
		_expect(tower.get_node_or_null("UpperShell/Ribbon%s" % side_name) != null, "the cabin has a wide window on its %s side" % side_name.to_lower())

	# The roof, with its stovepipe.
	var roof: Node = tower.get_node_or_null("Roof")
	_expect(roof != null and roof.get_node_or_null("SlabFront") != null and roof.get_node_or_null("SlabBack") != null, "the roof has two shingled slopes")
	_expect(tower.get_node_or_null("Roof/Breach") != null and tower.get_node_or_null("Ceiling/Breach") != null, "with a breach through the roof and the ceiling under it")
	_expect(tower.get_node_or_null("Stovepipe") != null or tower.get_node_or_null("Roof/Stovepipe") != null, "and a stovepipe chimney")


# ============================================================
# DOORS AND THE KEY
# ============================================================

func _check_doors_and_key_logic() -> void:
	var door: DoorController = tower.lower_door
	_expect(door.is_locked and door.starts_locked, "the tower's front door starts locked")
	_expect(door.required_key_id == "brass_signal_key" and SignalTowerBuilder.KEY_ID == "brass_signal_key", "and wants the brass signal key")
	_expect(door.locked_line == "CAPTION_TOWER_DOOR_LOCKED", "a locked door says so")
	_expect(door.get_prompt_text_for_player(player) == "PROMPT_LOCKED", "without the key it only offers 'locked'")
	_expect(absf(door.global_position.z - 1.91) < 0.02 and absf(door.global_position.x - (SignalTowerBuilder.DOOR_X - 0.45)) < 0.02, "it is in the front wall, left of the middle")

	# A door of heavy planks with straps, and brass hardware with a keyhole.
	var root: Node3D = door.get_node("Hinge/DoorRoot")
	var straps: int = 0
	for child: Node in root.get_children():
		var strap: MeshInstance3D = child as MeshInstance3D
		if strap != null and strap.mesh is BoxMesh and (strap.mesh as BoxMesh).size.is_equal_approx(Vector3(DOOR_WIDTH_FOR_TEST - 0.04, 0.12, 0.012)):
			straps += 1
	_expect(straps >= 4, "it is reinforced with iron straps (%d)" % straps)
	_expect(door._hardware.size() == 2 and (door._hardware[1] as DoorHardware).get_key_slot_global().distance_to(door.global_position) < 1.5, "and has brass hardware with a keyhole on both faces")
	var door_note: Inspectable = root.get_node("DoorNote") as Inspectable
	_expect(door_note != null and absf(door_note.global_position.z - 1.96) < 0.05, "a note is pinned to its front")
	_expect(str(door_note.get_visual_node().get_meta("readable_text")) == "READABLE_TOWER_DOOR_NOTE", "it reads READABLE_TOWER_DOOR_NOTE")

	var upper: DoorController = tower.upper_door
	_expect(not upper.is_locked, "the cabin's balcony door is not locked")
	_expect(upper.global_position.y > 2.7 and upper.global_position.x > 2.0, "it is on the +X side, at the cabin's floor")


# ============================================================
# THE FURNITURE
# ============================================================

func _check_props() -> void:
	var props: SignalTowerProps = tower.props
	_expect(props != null and tower.get_node("Props") == props, "the furniture is the tower's child Props")

	# The levers: five heavy iron ones on a floor frame, the fourth snapped.
	var frame: Node3D = props.lever_frame
	var levers: Array[Node] = frame.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Lever") and not n.name.begins_with("LeverFrame"))
	_expect(levers.size() == 5, "five levers stand on the frame (%d)" % levers.size())
	_expect(is_equal_approx(frame.global_position.y, 2.8), "in the control cabin")
	var broken_arm: MeshInstance3D = frame.get_node("Lever%d/Arm" % SignalTowerProps.BROKEN_LEVER) as MeshInstance3D
	var whole_arm: MeshInstance3D = frame.get_node("Lever0/Arm") as MeshInstance3D
	_expect((broken_arm.mesh as BoxMesh).size.y < 0.5 and (whole_arm.mesh as BoxMesh).size.y > 1.0, "Lucas's lever is snapped off short, the others are whole")
	var fallen: Node3D = frame.get_node("FallenLever") as Node3D
	_expect(absf(fallen.global_position.x) < 2.0 and absf(fallen.global_position.z) < 2.0 and fallen.global_position.y < 2.9, "and the rest of it lies on the cabin floor")
	_expect(frame.find_children("InterlockBar", "MeshInstance3D", true, false).size() == 1, "an interlocking bar runs behind the levers")

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
	_expect(tower.props.lore_items.size() == 4 and not tower.props.ground_items.is_empty(), "(the cabin's documents and the headquarters' items are kept by key)")

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


## The three photographs lie in three separate zones of the relay room, each easy to reach from the open aisle,
## with nothing solid over them; the zones' own items are where they were meant to be.
func _check_zones() -> void:
	var props: SignalTowerProps = tower.props
	var photos: Dictionary = props.photos
	var knee: Node3D = photos["photo_childhood"]
	var lever: Node3D = photos["photo_broken_lever"]
	var platform: Node3D = photos["photo_foggy_platform"]
	_expect(photos.size() == 3 and knee is Collectible and lever is Collectible and platform is Collectible, "three photographs lie in the relay room, as collectibles")
	_expect(props.get_node_or_null("HeadQuarters/Lockbox") == null and props.find_child("Lockbox", true, false) == null, "none of them in a box")
	var apart: float = minf(knee.global_position.distance_to(lever.global_position), minf(knee.global_position.distance_to(platform.global_position), lever.global_position.distance_to(platform.global_position)))
	_expect(apart > 1.5, "in three separate zones (at least %.1f m apart)" % apart)
	for photo: Node3D in [knee, lever, platform]:
		_expect(absf(photo.global_position.x) < 1.8 and absf(photo.global_position.z) < 1.8 and photo.global_position.y < 1.0, "%s is inside the room, low enough to reach" % photo.name)

	# Zone 1: the desk. The Scraped Knee lies flat in the middle of the plank; Juliana's note is in the drawer under it.
	var table: Node3D = props.get_node("HeadQuarters/CrateTable")
	var lamp: Node3D = props.desk_lamp
	_expect(lamp != null and table.is_ancestor_of(lamp), "a desk lamp stands on the HQ desk")
	var on_table: Vector3 = table.to_local(knee.global_position)
	_expect(Vector2(on_table.x, on_table.z).length() < 0.12, "the Scraped Knee lies in the middle of the plank (%.2f, %.2f)" % [on_table.x, on_table.z])
	_expect(knee.global_basis.z.dot(Vector3.UP) > 0.99 and absf(on_table.y - 0.5635) < 0.006, "flat, face up, on the plank's top (%.3f)" % on_table.y)
	var from_lamp: Vector2 = Vector2(knee.global_position.x - lamp.global_position.x, knee.global_position.z - lamp.global_position.z)
	_expect(from_lamp.length() > 0.25, "and not propped against the lamp (%.2f m from its stem)" % from_lamp.length())
	var drawer: DeskDrawer = props.desk_drawer
	_expect(drawer != null and drawer.get_parent() == table, "a drawer is built into the desk, under the plank")
	var juliana_note: Node3D = props.ground_items[&"juliana_note"]
	_expect(juliana_note != null and drawer.is_ancestor_of(juliana_note) and juliana_note.global_basis.z.dot(Vector3.UP) > 0.99, "Juliana's note lies in the drawer, face up")
	_expect(not drawer.is_open and is_zero_approx(drawer.get_openness()), "and the drawer is shut")
	var note_in_table: Vector3 = table.to_local(juliana_note.global_position)
	_expect(note_in_table.y < 0.5 and absf(note_in_table.x) < 0.2, "under the plank, between the crates (%s)" % str(note_in_table))

	# Zone 2: the wooden bench (the daybed). The Broken Lever on the cushion, with Sophia's folded letter beside it.
	var daybed: Node3D = props.get_node("HeadQuarters/Daybed")
	var local_lever: Vector3 = daybed.to_local(lever.global_position)
	_expect(absf(local_lever.y - 0.4925) < 0.01 and absf(local_lever.x) < 0.2 and absf(local_lever.z) < 0.85, "the Broken Lever lies on the bench's cushion (%s)" % str(local_lever))
	var note: Node3D = props.ground_items[&"sophia_note"]
	_expect(daybed.is_ancestor_of(note) and absf(daybed.to_local(note.global_position).y - 0.4922) < 0.01, "Sophia's folded letter lies on the cushion")
	_expect(note.global_position.distance_to(lever.global_position) < 0.35, "next to the Broken Lever (%.2f m)" % note.global_position.distance_to(lever.global_position))
	_expect(note.global_basis.z.dot(Vector3.UP) > 0.99, "lying face up")
	_expect(note.get_visual_node().find_child("Squares", true, false) != null, "it is a sheet of graph paper")
	_expect(props.find_child("WalkieTalkie", true, false) == null and props.find_child("SophiaJacket", true, false) == null, "there is no walkie-talkie and no jacket")
	var gap: float = lever.global_position.distance_to(note.global_position)
	_expect(gap > 0.12, "the two do not lie on each other (%.2f m apart)" % gap)

	# Zone 3: the shelf under the carved board; the Foggy Platform in the open tin.
	var shelf: Node3D = props.get_node("HeadQuarters/BackShelf")
	var tin: Node3D = props.photo_tin
	_expect(shelf.global_position.y < 0.2 and tin != null and shelf.is_ancestor_of(tin), "a low wooden shelf on the back wall carries an open tin")
	var in_tin: Vector3 = tin.to_local(platform.global_position)
	_expect(Vector2(in_tin.x, in_tin.z).length() < 0.095 and in_tin.y > 0.02 and in_tin.y < 0.09, "the Foggy Platform stands in the tin, above its rim (%s)" % str(in_tin))

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
	_ray_finds(lever, lever.global_position + Vector3(-0.8, 0.9, 0.3), lever.global_position, "the Broken Lever on the cushion")
	_ray_finds(note, note.global_position + Vector3(-0.8, 0.9, 0.4), note.global_position, "Sophia's note on the cushion")
	_ray_finds(platform, platform.global_position + Vector3(0.2, 0.9, 0.9), platform.global_position, "the Foggy Platform in the tin")

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


# ============================================================
# THE TOWN'S HISTORY
# ============================================================

const LORE_TEXTS: Dictionary = {
	"news": ["READABLE_TOWER_NEWS", "LOCAL POLICE BRIEF (MAY 1984): Search efforts along the northern rail cutting have been suspended. Maintenance worker E. Silva reported hearing his missing seven year old daughter calling his name from inside the drainage culvert near Mile Marker 4. Search teams examined the pipe and confirmed it has been completely filled with solid granite since 1962. Mr. Silva remains under psychiatric observation following his refusal to stop digging into the stone with his bare hands."],
	"memo": ["READABLE_TOWER_MEMO", "INTERNAL MEMORANDUM (1989): To all signal tower operators: Effective immediately, do not record fog shadows in the official station logbook. Operator M. Santos was relieved of duty last night after stopping three freight trains for non existent obstructions. He insists a woman in a black dress was standing in the center of the tracks holding her head in her hands. Medical officers attribute his vision to severe sleep deprivation and carbon monoxide fumes from the coal heater."],
	"journal": ["READABLE_TOWER_JOURNAL", "November 12. My wife says I am losing my mind because I keep measuring the floorboards with a ruler every morning. She does not understand. The distance between the door and the window was four meters on Monday. Today it is four meters and twelve centimeters. The house is stretching. Or maybe my eyes are failing me just like my father told me they would. I cannot sleep when the wood creaks because it sounds like the walls are catching their breath."],
	"notice": ["READABLE_TOWER_NOTICE", "MUNICIPAL HEALTH ANNOUNCEMENT (1991): Residents living near the forest line are advised that severe valley acoustic resonance during heavy fog can cause auditory illusions including knocking sounds, whispered names, and perceived footsteps. Doctors confirm these sensations are harmless neurological responses to prolonged atmospheric isolation. Please keep your doors locked and remain inside after dusk."],
}


## Four documents of the town's own history lie about the control cabin: the words are the written ones
## (in both languages, no hyphens, none of the story's characters named), each is where it was meant to
## be, and each can be reached by an interaction ray.
func _check_lore_items() -> void:
	var items: Dictionary = tower.props.lore_items
	_expect(items.size() == 4, "four lore documents are in the cabin (%d)" % items.size())
	for key: String in LORE_TEXTS:
		var item: Inspectable = items.get(StringName(key)) as Inspectable
		_expect(item != null, "the %s is an inspectable" % key)
		if item == null:
			continue

		var expected: Array = LORE_TEXTS[key]
		_expect(item.global_position.y > 2.8 and item.global_position.y < 5.2, "the %s is on the upper floor (%.2f m up)" % [key, item.global_position.y])
		_expect(str(item.get_visual_node().get_meta("readable_text")) == expected[0], "its words are %s" % expected[0])
		_expect(str(item.get_visual_node().get_meta("inspect_mode")) == "read", "and it is read as a document")
		_expect(tr(expected[0]) == expected[1], "the %s says what was written (%s)" % [key, tr(expected[0]).left(24)])
		_expect(not tr(expected[0]).contains("-"), "with no hyphen in it")
		for name_key: String in ["ITEM_TOWER_%s_NAME" % key.to_upper(), "ITEM_TOWER_%s_DESCRIPTION" % key.to_upper()]:
			_expect(tr(name_key) != name_key, "%s has its name and description" % key)

	GameSettings.set_text_locale("pt_BR", false)
	var translated: bool = true
	var clean: bool = true
	for key: String in LORE_TEXTS:
		var key_text: String = (LORE_TEXTS[key] as Array)[0]
		translated = translated and tr(key_text) != key_text and tr(key_text) != str((LORE_TEXTS[key] as Array)[1]) and tr("ITEM_TOWER_%s_NAME" % key.to_upper()) != "ITEM_TOWER_%s_NAME" % key.to_upper()
		clean = clean and not tr(key_text).contains("-")
	_expect(translated, "all four are translated into Portuguese")
	_expect(clean, "with no hyphen there either")
	GameSettings.set_text_locale("en", false)

	# No one of the story is named in them.
	var named: bool = false
	for key: String in LORE_TEXTS:
		for person: String in ["Sophia", "Juliana", "Juli", "Lucas"]:
			named = named or str((LORE_TEXTS[key] as Array)[1]).contains(person)
	_expect(not named, "none of the main characters is named")

	# Where each one is.
	var news: Node3D = items[&"news"]
	var desk: Node3D = tower.props.get_node("Cabin/Desk")
	var on_desk: Vector3 = desk.to_local(news.global_position)
	_expect(absf(on_desk.x) < 0.65 and absf(on_desk.z) < 0.3 and absf(on_desk.y - 0.775) < 0.01, "the clipping lies on the control desk's top (%s)" % str(on_desk))
	_expect(news.global_basis.z.dot(Vector3.UP) > 0.99, "face up")

	var memo: Node3D = items[&"memo"]
	_expect(tower.props.lever_frame.is_ancestor_of(memo), "the memo is pinned to the lever frame")
	_expect(memo.global_basis.z.dot(Vector3.BACK) < -0.99, "on the operator's side of it, facing into the room")

	var journal: Node3D = items[&"journal"]
	var bench: Node3D = tower.props.get_node("Cabin/Bench")
	var on_bench: Vector3 = bench.to_local(journal.global_position)
	_expect(absf(on_bench.y - 0.44) < 0.01 and absf(on_bench.x) <= 0.21 and absf(on_bench.x) > 0.15, "the journal page rests on the seat of the bench, by its edge (%s)" % str(on_bench))

	var notice: Node3D = items[&"notice"]
	_expect(absf(notice.global_position.z + 2.1) < 0.05 and notice.global_position.y > 4.0, "the notice is taped to the back window frame")
	_expect(tower.props.get_node("Cabin") != null and tower.get_node("UpperShell/RibbonBack") != null, "which is a window of the cabin")

	# Every one can be reached by a ray from where a player would stand.
	_ray_finds(news, Vector3(0.9, 4.2, -0.8), news.global_position, "the clipping on the desk")
	_ray_finds(memo, Vector3(1.0, 4.2, 0.6), memo.global_position, "the memo on the lever frame")
	_ray_finds(journal, Vector3(1.0, 4.2, 0.35), journal.global_position, "the journal page on the bench")
	_ray_finds(notice, Vector3(0.0, 4.2, -0.5), notice.global_position, "the notice on the window frame")


## Pressing the interact key on an open document shows its words in the clean text overlay.
func _read_the_lore() -> void:
	player.global_position = Vector3(1.0, 3.4, 0.5)
	var inspect: PlayerInspectController = player.inspect_controller
	var documents: Dictionary = {}
	for key: String in LORE_TEXTS:
		documents[key] = [tower.props.lore_items[StringName(key)], (LORE_TEXTS[key] as Array)[0]]
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
	# (A broken pane is an ArrayMesh of jagged shards, a whole one a plain quad; one that is gone is nothing.)
	var shards: int = 0
	var panes: int = 0
	for node: Node in tower.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			shards += 1
		elif mesh is QuadMesh:
			panes += 1

	_expect(shards >= 8, "many panes are shattered (%d with jagged shards)" % shards)
	_expect(shards > panes, "more broken than whole (%d against %d)" % [shards, panes])
	_expect(tower.find_children("MullionV*", "MeshInstance3D", true, false).size() >= 15, "the windows are multi pane, with their mullions")

	var tiles: int = 0
	for node: Node in tower.get_children():
		if node.name.begins_with("LooseTile"):
			tiles += 1
	_expect(tiles >= 5, "loose roof tiles lie on the slopes (%d)" % tiles)
	_expect(tower.get_node("Rubble").get_child_count() >= 20, "and tiles and bricks lie fallen on the ground (%d pieces)" % tower.get_node("Rubble").get_child_count())

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
		if absf(maxf(absf(spot.x), absf(spot.z)) - 2.0) < 0.2:
			on_brick += 1
	_expect(highest < SignalTowerBuilder.BASE_HEIGHT, "the ivy stays on the brick base (highest leaf %.2f m)" % highest)
	_expect(farthest < 2.2 and on_brick > int(count * 0.9), "every leaf clings to a wall (%d of %d)" % [on_brick, count])


# ============================================================
# CLUES
# ============================================================

## Every interactable piece can be reached by a ray: no solid lies over it.
func _check_clues_are_reachable() -> void:
	var props: SignalTowerProps = tower.props
	var door: DoorController = tower.lower_door
	var note: Node3D = door.get_node("Hinge/DoorRoot/DoorNote")
	_ray_finds(note, note.global_position + Vector3(0.1, 0.1, 1.0), note.global_position, "the note on the door")


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
	while waited < 14.0 and player.global_position.y < 3.25:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	await _wait(0.5)
	Input.action_release(&"up")
	_expect(player.global_position.y > 3.2, "the player walks up the stairs to the balcony (%.2f m up)" % player.global_position.y)
	_expect(player.global_position.z < -0.2 and player.global_position.z > -2.1 and player.global_position.x > 2.3, "and stands on it (%.2f, %.2f)" % [player.global_position.x, player.global_position.z])

	# The balcony door opens: it is not locked.
	var upper: DoorController = tower.upper_door
	upper.animate_player_interaction = false
	upper.interact(player)
	_expect(upper.is_open, "the cabin's door opens for the player")
	await _wait(5.0)
	var through: Vector3 = _first_hit(Vector3(6.0, 4.2, UPPER_DOOR_Z), Vector3(-6.0, 4.2, UPPER_DOOR_Z))
	_expect(through.x < -1.9, "and the way into the cabin is clear (the ray goes in to %.2f)" % through.x)


## A locked door stays shut; the key takes it open and is left in the lock.
func _check_the_key_and_the_doors() -> void:
	var door: DoorController = tower.lower_door
	door.animate_player_interaction = false
	var shut: Vector3 = _first_hit(Vector3(-0.2, 1.0, 6.0), Vector3(-0.2, 1.0, -1.5))
	_expect(shut.z > 1.7, "the shut door blocks the way in (%.2f)" % shut.z)
	door.interact(player)
	_expect(door.is_locked and not door.is_open, "it does not open without the key")

	var key: Collectible = (load("res://scenes/objects/signal_tower/brass_signal_key.tscn") as PackedScene).instantiate() as Collectible
	add_child(key)
	_expect(key.item_id == "brass_signal_key" and key.item_name == "ITEM_BRASS_SIGNAL_KEY_NAME", "the key is the brass signal key")
	key.interact(player)
	await _wait(0.5)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)
	_expect(player.has_inventory_item("brass_signal_key"), "which goes in the inventory")
	_expect(door.get_prompt_text_for_player(player) == "PROMPT_UNLOCK", "and now the door offers to unlock")
	door.interact(player)
	_expect(not door.is_locked and door.is_open, "the key opens the door")
	_expect(not player.has_inventory_item("brass_signal_key"), "and stays in the lock")
	await _wait(6.0)
	var open: Vector3 = _first_hit(Vector3(-0.2, 1.0, 6.0), Vector3(-0.2, 1.0, -1.9))
	_expect(open.z < -1.7, "the way into the relay room is clear (the ray goes in to %.2f)" % open.z)
	var top: Vector3 = _first_hit(Vector3(-0.2, 1.95, 6.0), Vector3(-0.2, 1.95, -1.9))
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
	var front: Vector3 = table.to_global(Vector3(0.0, 0.452, 0.36))
	_ray_finds(drawer, front + table.global_basis.z * 0.7 + Vector3(0.0, 0.5, 0.0), front, "the drawer's front")
	_expect(drawer.can_interact(player) and drawer.get_prompt_text() == "PROMPT_OPEN" and tr("PROMPT_OPEN").ends_with("] Open"), "aimed at, it offers [E] Open")

	# Pulled open.
	var shut_at: Vector3 = drawer.slide.global_position
	drawer.interact(player)
	_expect(drawer.is_moving and not drawer.can_interact(player), "[E] sets it moving, and it is not used again meanwhile")
	await _wait(0.45)
	var mid: float = drawer.get_openness()
	_expect(mid > 0.1 and mid < 0.95 and drawer.is_moving, "it is on its way (%.0f%% out)" % (mid * 100.0))
	var sound: AudioStreamPlayer3D = drawer.get_node("Sound") as AudioStreamPlayer3D
	_expect(sound.playing and sound.stream != null and sound.stream.get_length() > 0.8, "its scrape and its knocks sound (%.2f s)" % (sound.stream.get_length() if sound.stream != null else 0.0))
	var movement: Object = player.get("movement_controller") as Object
	_expect(movement != null and (movement.get("gesture_offset") as Vector3).z < -0.005, "the player leans in while they pull (%s)" % str(movement.get("gesture_offset")))
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
	_expect(out.z > 0.4 and out.y < 0.5, "Juliana's note lies in the open part of the drawer, past the plank's edge (%s)" % str(out))
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


## The pinned note on the door opens the inspect view like any note.
func _check_the_door_note() -> void:
	var note: Inspectable = tower.lower_door.get_node("Hinge/DoorRoot/DoorNote") as Inspectable
	note.interact(player)
	await _wait(0.8)
	_expect(player.inspect_controller.is_open(), "the door note opens the inspect view")
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)


func _check_translations() -> void:
	_expect(tr("READABLE_TOWER_DOOR_NOTE") == "We can't let anyone find this place, Sophia, or we lose our HQ forever. I'm keeping the key with me at the fig tree camp until the rain stops. — Juliana", "the door note, in English")
	_expect(tr("CAPTION_TOWER_DOOR_LOCKED") == "Where is the HQ key?", "the locked door's line, in English")
	GameSettings.set_text_locale("pt_BR", false)
	var all_translated: bool = true
	for key: String in ["READABLE_TOWER_DOOR_NOTE", "CAPTION_TOWER_DOOR_LOCKED", "ITEM_BRASS_SIGNAL_KEY_NAME", "ITEM_BRASS_SIGNAL_KEY_DESCRIPTION", "ITEM_TOWER_DOOR_NOTE_NAME", "ITEM_TOWER_DOOR_NOTE_DESCRIPTION"]:
		all_translated = all_translated and tr(key) != key
	_expect(all_translated, "every text of the tower is also in Portuguese")
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
