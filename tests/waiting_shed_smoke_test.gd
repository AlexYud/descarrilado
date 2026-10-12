extends Node

## Plays the whole waiting shed and signal box through the game's own APIs
## (inspect, the lever close-up, the Ficha pickup) and checks each step. Run it
## as a scene; it quits by itself with a non-zero exit code on failure. Game
## time runs faster so the waits do not take their full length.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_waiting_shed_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/waiting_shed_playtest.tscn"
const TIME_SCALE: float = 4.0

var test_failed: bool = false
var completed_count: int = 0

var shed: WaitingShedSequence = null
var player: CharacterBody3D = null
var box: LeverBox = null
var container: OpenableContainer = null


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(
		1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO"
	)
	GameSettings.set_captions_enabled(true, false)
	GameSettings.set_text_locale("en")

	var level: Node = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame

	shed = level.get_node("WaitingShed")
	player = level.get_node("Player")
	box = shed.get_node("%SignalBox")
	container = shed.get_node("%SwitchBox")
	shed.sequence_completed.connect(func() -> void: completed_count += 1)
	Engine.time_scale = TIME_SCALE

	await _run()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("WAITING_SHED_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	await _check_layout()
	await _check_clues()
	await _check_interaction_rays()
	await _check_box_and_puncher()
	await _check_levers()
	await _check_ficha()


# ============================================================
# STEPS
# ============================================================

func _check_layout() -> void:
	_expect(player.is_in_group(&"player"), "the player joins the player group")
	_expect(shed.get_node("%Shelter").get_child_count() > 30, "the shelter is built")
	_expect(
		shed.get_node("%Shelter").find_children("Pillar?", "MeshInstance3D", false, false).size() == 4,
		"the shelter stands on four pillars"
	)
	_expect(shed.get_node("%Track").get_child_count() == 5, "the track is the ready-made track model: three pieces, a bank and the lantern")
	_expect(shed.get_node("%Track/TrackBank/Bank") != null, "the track has a low bank to walk over")
	_expect(shed.get_node_or_null("Rain") == null, "there is no rain")
	_expect(shed.get_node_or_null("RainLoop") == null and shed.get_node_or_null("RailCreak") == null, "there are no ambient sounds")

	_expect(not box.is_unlocked, "the signal box starts locked")
	_expect(box.states == [false, true, false], "the levers start DOWN, UP, DOWN")
	_expect(box.get_node_or_null("Contents") == null, "the Ficha is out of reach while locked")
	for number: int in [1, 2, 3]:
		_expect(box.get_node_or_null("Model/Lever%d" % number) != null, "lever %d is on the box" % number)
		_expect(box.get_node("Lever%d" % number) is SignalLever, "lever %d can be used in the 3D scene" % number)

	for item_name: String in ["SophiaJournal", "RailwayLantern", "CarvedWhistle"]:
		var item: Node = shed.get_node("%" + item_name)
		_expect(item is Inspectable and not _is_collectable(item), item_name + " is read in place")

	# The ticket puncher is hidden in a closed box under the bench; the box is not inspected.
	_expect(not _is_inspectable(container), "the switch box is only opened, never inspected")
	_expect(container.get_node_or_null("Contents") == null, "the ticket puncher is out of sight while the box is closed")
	var bench: Node3D = shed.get_node("%Bench")
	_expect(
		container.global_position.y < bench.global_position.y + 0.3
		and absf(container.global_position.x - bench.global_position.x) < 0.7,
		"the box sits on the floor under the bench"
	)

	# The whistle hangs on the back of the mile marker, the lantern rests on a sleeper.
	var marker: Node3D = shed.get_node("%MileMarker")
	_expect(shed.get_node("%CarvedWhistle").global_position.z < marker.global_position.z, "the whistle is on the far side of the marker")
	_expect(absf(shed.get_node("%RailwayLantern").global_position.x - 6.0) < 1.3 and shed.get_node("%RailwayLantern").global_position.y < 0.4, "the lantern rests on a sleeper between the rails")


func _check_clues() -> void:
	# Each clue is only a phrase (no rule number, no lever), etched where the player
	# has to turn the item to find it. The words say up or down; the journal gives
	# the order lantern, puncher, whistle, which is the order of the levers.
	var lantern: Inspectable = shed.get_node("%RailwayLantern")
	var whistle: Inspectable = shed.get_node("%CarvedWhistle")
	_expect(_etching(lantern, "ClueSpot") == "Keep your light above the fog.", "the lantern's base says to keep the light above")
	_expect(_etching(whistle, "ClueSpot") == "Stand tall and make some noise!", "the whistle's back says to stand tall")
	for item: Node in [lantern, whistle]:
		_expect(item.get_node("Visual").find_child("LeverLine", true, false) == null, item.name + " does not name a lever")
		var clue: String = _etching(item, "ClueSpot")
		_expect(not clue.contains("Rule") and not clue.contains("lever") and not clue.contains("LEVER"), item.name + " has no rule number")

	_expect(_label_faces_away(lantern, "ClueSpot", Vector3.DOWN), "the lantern's clue faces down")
	_expect(_label_faces_away(whistle, "ClueSpot", Vector3.FORWARD), "the whistle's clue faces back")

	for item_name: String in ["SophiaJournal", "RailwayLantern", "CarvedWhistle"]:
		var item: Inspectable = shed.get_node("%" + item_name)
		await _read(item, 0.5)
		_expect(is_instance_valid(item), item_name + " stays where it lies")

	var journal: Inspectable = shed.get_node("%SophiaJournal")
	_expect(
		tr(journal.get_inspect_data()["name"]) == "Sophia's Notebook",
		"the journal is Sophia's Notebook"
	)
	var order: String = tr("JOURNAL_RIGHT")
	var light_at: int = order.find("light the track")
	var punch_at: int = order.find("punch the ticket")
	var blow_at: int = order.find("blow the signal")
	_expect(
		light_at >= 0 and punch_at > light_at and blow_at > punch_at,
		"the journal gives the order: light the track, punch the ticket, blow the signal"
	)
	_expect(
		not order.contains("Rule") and not order.contains("lever") and not order.contains("UP") and not order.contains("DOWN"),
		"the journal gives no rules, levers or directions"
	)

	# Lantern (lever 1) says light ABOVE the fog = UP; the puncher (lever 2) says
	# press DEEP = DOWN; the whistle (lever 3) says stand TALL = UP.
	_expect(box.solution == [true, false, true], "the solution is UP, DOWN, UP")


func _check_interaction_rays() -> void:
	await _ray_finds(shed.get_node("%SophiaJournal"), Vector3(-4.4, 1.0, -4.9), shed.get_node("%SophiaJournal").global_position, "the journal on the bench")
	await _ray_finds(container, Vector3(-4.1, 1.0, -4.5), container.global_position + Vector3(0.0, 0.05, 0.0), "the closed box under the bench")
	await _ray_finds(shed.get_node("%RailwayLantern"), Vector3(5.5, 1.0, -3.6), shed.get_node("%RailwayLantern").global_position, "the lantern on its sleeper")
	await _ray_finds(shed.get_node("%CarvedWhistle"), Vector3(-8.45, 1.0, -3.7), shed.get_node("%CarvedWhistle").global_position, "the whistle behind the marker")
	for number: int in [1, 2, 3]:
		var lever: Node3D = box.get_node("Lever%d" % number)
		await _ray_finds(lever, lever.global_position + Vector3(0.0, 0.1, 0.9), lever.global_position, "lever %d" % number)


func _check_box_and_puncher() -> void:
	_expect(container.can_interact(player), "the closed box can be opened")
	_expect(container.get_prompt_text() == "PROMPT_OPEN", "it says open")
	container.interact(player)
	_expect(container.is_open, "the player opens the box")
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"junction_switch_box_open", false)),
		"the open box is remembered"
	)
	_expect(not container.can_interact(player), "an open box offers nothing more")
	await _wait(1.5)
	_expect(container.get_node_or_null("Contents/TicketPuncher") != null, "the ticket puncher is inside")
	_expect(container.get_node("Model/LidPivot").rotation_degrees.x < -90.0, "the lid is open")

	var puncher: Inspectable = container.get_node("Contents/TicketPuncher")
	_expect(not _is_collectable(puncher), "the ticket puncher is read in place")
	await _ray_finds(puncher, Vector3(-4.1, 1.0, -4.5), puncher.global_position, "the ticket puncher in the open box")
	await _read(puncher, 0.5)
	_expect(tr(puncher.get_inspect_data()["name"]) == "Brass Ticket Hole-Puncher", "only the puncher is inspected, as the Brass Ticket Hole-Puncher")
	_expect(tr(puncher.get_inspect_data()["description"]) == "A heavy, cast-iron conductor's ticket puncher.", "with its description")
	_expect(_etching(puncher, "ClueSpot") == "Press deep into the paper.", "the puncher's arm says to press deep")
	_expect(_label_faces_away(puncher, "ClueSpot", Vector3.FORWARD), "the puncher's clue faces back")
	_expect(puncher.get_node("Visual").find_child("LeverLine", true, false) == null, "the puncher does not name a lever")


func _check_levers() -> void:
	var lever1: SignalLever = box.get_node("Lever1")
	var lever2: SignalLever = box.get_node("Lever2")
	var lever3: SignalLever = box.get_node("Lever3")
	_expect(lever1.can_interact(player), "a lever can be used")

	# The prompt names the lever and where using it sends it.
	_expect(lever1.get_prompt_text() == "Push lever 1 up", "lever 1 (down) says Push lever 1 up")
	_expect(lever2.get_prompt_text() == "Pull lever 2 down", "lever 2 (up) says Pull lever 2 down")
	_expect(lever3.get_prompt_text() == "Push lever 3 up", "lever 3 (down) says Push lever 3 up")
	_expect(
		is_equal_approx(box.get_node("Model/Lever1").rotation_degrees.z, LeverBox.LEVER_DOWN_DEGREES),
		"lever 1 starts down on the box"
	)

	lever1.interact(player)
	_expect(box.states == [true, true, false], "using lever 1 throws it up")
	_expect(lever1.get_prompt_text() == "Pull lever 1 down", "and its prompt turns round")
	await _wait(0.6)
	_expect(
		is_equal_approx(box.get_node("Model/Lever1").rotation_degrees.z, 0.0),
		"the lever on the box has swung up"
	)

	# Wrong combinations: nothing happens, however close they are.
	lever3.interact(player)
	await _wait(1.5)
	_expect(not box.is_unlocked and box.states == [true, true, true], "UP, UP, UP does not open it")
	lever1.interact(player)
	await _wait(1.5)
	_expect(not box.is_unlocked and box.states == [false, true, true], "DOWN, UP, UP does not open it")
	lever1.interact(player)
	await _wait(0.6)
	_expect(
		SaveManager.get_state_value(&"puzzles", &"junction_signal_box_levers", []) == [true, true, true],
		"the lever positions are remembered"
	)

	# UP - DOWN - UP.
	lever2.interact(player)
	_expect(box.is_unlocked, "UP, DOWN, UP opens the box")
	_expect(
		not bool(SaveManager.get_state_value(&"puzzles", &"junction_signal_box_open", false)),
		"the box only opens after a beat"
	)
	lever1.interact(player)
	_expect(box.states == [true, false, true], "the levers are locked once the box is solved")
	_expect(not lever1.can_interact(player), "a solved lever offers nothing more")

	await _wait(2.0)
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"junction_signal_box_open", false)),
		"the open box is remembered"
	)


func _check_ficha() -> void:
	await _wait(1.0)
	var contents: Node3D = box.get_node_or_null("Contents")
	_expect(contents != null, "the Ficha has come out of the chute")
	if contents == null:
		return

	var ficha: Collectible = contents.get_node("SophiaFicha")
	var note: Inspectable = contents.get_node("FichaNote")
	_expect(_is_collectable(ficha) and not _is_collectable(note), "the Ficha is taken, the note is read in place")
	_expect(
		contents.global_position.is_equal_approx(box.to_global(box.tray_position)),
		"it lands in the coin tray"
	)

	await _ray_finds(ficha, box.global_position + Vector3(0.0, 0.0, 0.9), ficha.global_position, "the Ficha in the tray")
	await _ray_finds(note, box.global_position + Vector3(0.0, 0.0, 0.9), note.global_position, "the note in the tray")

	await _read(note, 0.5)
	_expect(tr("FICHA_NOTE_TEXT").begins_with("I knew you'd find it, Juli."), "the note is Sophia's")
	_expect(completed_count == 0, "nothing ends the scene before the Ficha is taken")

	_expect(ficha.can_interact(player), "the Ficha can be taken")
	ficha.interact(player)
	_expect(player.has_inventory_item("sophia_ficha"), "the Ficha goes in the inventory")
	_expect(player.inspect_controller.is_open(), "taking it shows it in the inspect view")
	await _wait(0.6)
	_close_view()
	await _wait(0.6)
	_expect(completed_count == 1, "closing the Ficha's view raises sequence_completed once")
	await _wait(1.0)
	_expect(completed_count == 1, "and nothing else happens after it")


# ============================================================
# HELPERS
# ============================================================

func _read(item: Inspectable, seconds: float) -> void:
	item.interact(player)
	_expect(player.inspect_controller.is_open(), item.name + " opens the inspect view")
	await _wait(seconds)
	_close_view()
	await _wait(0.5)


func _close_view() -> void:
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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


func _is_inspectable(node: Node) -> bool:
	return node is Inspectable


func _is_collectable(node: Node) -> bool:
	return node is Collectible


## The translated text of an etched line on an item's Visual.
func _etching(item: Node, line: String) -> String:
	# The clue is a readable spot (the words are shown as an overlay), not a label.
	var spot: ReadableSpot = item.get_node("Visual").find_child(line, true, false) as ReadableSpot
	return tr(spot.text_key) if spot != null else "<missing %s>" % line


## True when the line's text faces `direction` (in the item's own space), so the
## player has to turn the item to read it.
func _label_faces_away(item: Node, line: String, direction: Vector3) -> bool:
	var spot: ReadableSpot = item.get_node("Visual").find_child(line, true, false) as ReadableSpot
	if spot == null:
		return false

	var normal: Vector3 = spot.get_facing_normal()
	var visual: Node3D = item.get_node("Visual")
	var wanted: Vector3 = (visual.global_basis * direction).normalized()
	return normal.dot(wanted) > 0.9


## Stands the player at `stand`, aims at `aim`, and checks the interaction ray
## ends on `item`.
func _ray_finds(item: Node, stand: Vector3, aim: Vector3, what: String) -> void:
	player.global_position = Vector3(stand.x, 1.1, stand.z)
	player.velocity = Vector3.ZERO
	await _wait(0.8)

	# Aim twice: the view settles a little after the player lands.
	var camera: Camera3D = player.get_node("Head/Camera3D")
	for pass_number: int in 2:
		var to_aim: Vector3 = aim - camera.global_position
		player.movement_controller.look_yaw = -rad_to_deg(atan2(-to_aim.x, -to_aim.z))
		player.movement_controller.look_pitch = -rad_to_deg(
			atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length())
		)
		for i: int in 3:
			await get_tree().physics_frame

	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractRay")
	ray.force_raycast_update()
	var found: Node = ray.get_collider() as Node
	while found != null and not found is Interactable:
		found = found.get_parent()

	_expect(
		found == item,
		"the interaction ray reaches %s (hit %s)" % [what, str(ray.get_collider())]
	)
