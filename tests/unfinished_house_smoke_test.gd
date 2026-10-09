extends Node

## Plays the whole unfinished house through the game's own APIs (inspect, pickups,
## the padlock close-up, doors, the drawer) and checks each step and scare. Run it
## as a scene; it quits by itself with a non-zero exit code on failure. Game time
## runs faster so the scares do not take their full length.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_unfinished_house_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/unfinished_house_playtest.tscn"
const TIME_SCALE: float = 4.0

var test_failed: bool = false
var completed_count: int = 0

var house: UnfinishedHouseSequence = null
var player: CharacterBody3D = null
var capsule: CombinationLock = null
var flashlight: Node = null


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(
		1, TEST_SCENE_PATH, "house_test_start", "SAVE_LOCATION_DREAM_INTRO"
	)
	GameSettings.set_captions_enabled(true, false)

	var level: Node = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame

	house = level.get_node("UnfinishedHouse")
	player = level.get_node("Player")
	capsule = house.get_node("Furniture/TimeCapsule")
	flashlight = player.get_node("Hand/SpotLight3D")
	house.sequence_completed.connect(func() -> void: completed_count += 1)
	Engine.time_scale = TIME_SCALE

	await _run()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("UNFINISHED_HOUSE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	await _check_layout()
	await _check_notes_and_recipe_scare()
	await _check_padlock()
	await _check_capsule_contents()
	await _check_key_and_pantry_scare()
	await _check_diary_and_footsteps()


# ============================================================
# STEPS
# ============================================================

func _check_layout() -> void:
	_expect(player.is_in_group(&"player"), "the player joins the player group")
	_expect(house.get_node("Shell").get_child_count() > 30, "the house shell is built")
	_expect(not capsule.is_unlocked, "the time capsule starts locked")
	_expect(
		capsule.get_node_or_null("Contents") == null,
		"the capsule's contents are out of reach while locked"
	)

	var bedroom_door: DoorController = house.get_node("Doors/BedroomDoor")
	var pantry_door: DoorController = house.get_node("Doors/PantryDoor")
	_expect(bedroom_door.is_locked, "the master bedroom door starts locked")
	_expect(not pantry_door.is_locked and pantry_door.is_open, "the pantry door starts open so the player can walk in")

	bedroom_door.interact(player)
	_expect(bedroom_door.is_locked and not bedroom_door.is_open, "it stays shut without the key")
	_expect(
		bedroom_door.get_prompt_text_for_player(player) == "PROMPT_LOCKED",
		"it says it is locked"
	)

	var note: Inspectable = house.get_node("Furniture/PantryNote")
	var key: Collectible = house.get_node("Furniture/MasterKey")
	_expect(
		note.global_position.x > 9.3 and key.global_position.x > 9.3,
		"both lie on the pantry shelves"
	)
	_expect(
		absf(note.global_position.z - key.global_position.z) > 0.15
		and absf(note.global_position.y - key.global_position.y) < 0.1,
		"the note and the key lie apart on the same (middle) shelf"
	)
	await _check_interaction_rays()


func _check_notes_and_recipe_scare() -> void:
	# A note is read in place: it opens the inspect view and stays where it lies.
	var note: Inspectable = house.get_node("Furniture/NoteCapsule")
	_expect(not _is_collectable(note), "the note on the capsule is not collectable")
	await _read(note, 0.5)
	_expect(is_instance_valid(note), "the note stays where it lies")

	# Reading the recipe gives Juliana's comment and nothing else: no scare.
	var recipe: Inspectable = house.get_node("Furniture/KitchenRecipe")
	_expect(not _is_collectable(recipe), "the recipe is not collectable")
	var front_door: DoorController = house.get_node("Doors/FrontDoor")
	var back_door: DoorController = house.get_node("Doors/BackDoor")
	var pantry_door: DoorController = house.get_node("Doors/PantryDoor")
	front_door.interact(player)
	back_door.interact(player)
	flashlight.call("restore_save_state", {"is_on": true})
	await _wait(3.0)
	_expect(front_door.is_open and back_door.is_open and pantry_door.is_open, "three doors are open")

	recipe.interact(player)
	await _wait(2.4)
	_expect(
		bool(SaveManager.get_state_value(&"triggers", &"house_recipe_open", false)),
		"Juliana comments on the recipe"
	)
	_close_view()
	await _wait(5.0)
	_expect(
		front_door.is_open and back_door.is_open and pantry_door.is_open,
		"closing the recipe slams nothing"
	)
	_expect(bool(flashlight.get("flashlight_on")), "closing the recipe leaves the flashlight on")


func _check_padlock() -> void:
	_expect(capsule.can_interact(player), "the padlock can be used")
	capsule.interact(player)
	_expect(capsule.view.is_open(), "the padlock close-up opens")
	_expect(player.modal_ui_open, "the player is held while the padlock is open")

	var view: CombinationLockView = capsule.view
	view.turn(0, 1)
	view.turn(1, 1)
	view.turn(2, 1)
	_expect(capsule.digits == [1, 1, 1], "each wheel turns one digit")
	view.turn(0, -2)
	_expect(capsule.digits[0] == 9, "a wheel wraps from 0 round to 9")
	_expect(not capsule.is_unlocked, "a wrong code does not open it")

	# 3 - 6 - 6
	view.turn(0, 4)
	view.turn(1, 5)
	_expect(not capsule.is_unlocked, "two right digits are not enough")
	view.turn(2, 5)
	_expect(capsule.is_unlocked, "3-6-6 opens the capsule")
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"time_capsule_open", false)) == false,
		"the lock only opens after a beat"
	)

	await _until(func() -> bool: return not view.is_open(), "the close-up closing itself", 10.0)
	_expect(not player.modal_ui_open, "the player is released when the close-up closes")
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"time_capsule_open", false)),
		"the open capsule is remembered"
	)
	_expect(capsule.get_node_or_null("Contents") != null, "the contents are within reach")
	await _wait(2.0)
	_expect(
		capsule.get_node("Model/LidPivot").rotation_degrees.x < -90.0,
		"the lid is open"
	)
	_expect(not capsule.can_interact(player), "the open lock offers nothing more")


func _check_capsule_contents() -> void:
	var ad: Inspectable = capsule.get_node("Contents/HouseAdvertisement")
	var ticket_sophia: Inspectable = capsule.get_node("Contents/BusTicketSophia")
	var ticket_unclaimed: Collectible = capsule.get_node("Contents/BusTicketUnclaimed")
	_expect(not _is_collectable(ad), "the house advertisement is read in place")
	_expect(not _is_collectable(ticket_sophia), "Sophia's ticket is read in place")

	await _ray_finds(ticket_unclaimed, _front_of(capsule, 1.05), ticket_unclaimed.global_position, "the unclaimed ticket in the chest")
	await _ray_finds(ticket_sophia, _front_of(capsule, 1.05), ticket_sophia.global_position, "Sophia's ticket in the chest")
	await _ray_finds(
		ad, _front_of(capsule, 1.05), ad.global_position + capsule.global_basis.z * 0.09,
		"the advertisement in the chest (its edge, the tickets lie on top)"
	)
	await _read(ad, 0.5)
	await _read(ticket_sophia, 0.5)
	_expect(completed_count == 0, "nothing ends the scene before the last ticket is taken")

	_expect(ticket_unclaimed.can_interact(player), "the unclaimed ticket can be taken")
	ticket_unclaimed.interact(player)
	_expect(player.has_inventory_item("bus_ticket_unclaimed"), "the ticket goes in the inventory")
	_expect(player.inspect_controller.is_open(), "taking it shows it in the inspect view")
	await _wait(0.6)
	_close_view()
	await _wait(0.6)
	_expect(completed_count == 1, "closing the ticket raises sequence_completed once")
	await _wait(1.0)
	_expect(completed_count == 1, "and nothing else happens after it")


func _check_key_and_pantry_scare() -> void:
	var front_door: DoorController = house.get_node("Doors/FrontDoor")
	var back_door: DoorController = house.get_node("Doors/BackDoor")
	var pantry_door: DoorController = house.get_node("Doors/PantryDoor")
	var bedroom_door: DoorController = house.get_node("Doors/BedroomDoor")

	# The note is only a clue; the key is what starts the scare.
	var note: Inspectable = house.get_node("Furniture/PantryNote")
	await _read(note, 0.5)
	await _wait(2.0)
	_expect(front_door.is_open and pantry_door.is_open, "reading the note slams nothing")

	var key: Collectible = house.get_node("Furniture/MasterKey")
	key.interact(player)
	_expect(player.has_inventory_item("master_key"), "the key goes in the inventory")
	_expect(player.inspect_controller.is_open(), "taking the key shows it")
	await _wait(0.6)
	_expect(front_door.is_open and pantry_door.is_open, "the doors wait for the key's view to close")
	_close_view()

	# Every open door slams shut at once and the flashlight dies.
	await _until(
		func() -> bool:
			return not front_door.is_open and not back_door.is_open and not pantry_door.is_open,
		"every open door slamming shut",
		10.0
	)
	await _until(
		func() -> bool: return not bool(flashlight.get("flashlight_on")),
		"the flashlight dying",
		5.0
	)
	_expect(not front_door.is_locked and not pantry_door.is_locked, "the doors are shut, not locked")
	_expect(bedroom_door.is_locked, "the bedroom door is still locked")
	_expect(not house.figure.visible, "nobody is in the corridor yet")
	await _wait(3.0)
	_expect(not house.figure.visible, "the silhouette waits for the pantry door to be opened")

	# Opening the pantry door: a head is at the corridor window, OUTSIDE, for 1.5 s
	# second, then it ducks away. Silently.
	var sounds_before: int = house.find_children("*", "AudioStreamPlayer3D", true, false).size()
	pantry_door.interact(player)
	_expect(pantry_door.is_open, "the player opens the pantry door")
	_expect(house.figure.visible, "a silhouette is at the corridor window")
	_expect(house.hall_glow.visible, "the window glows behind it so it can be seen")
	_expect(house.hall_light.visible, "a weak light comes in through the window")
	_expect(house.figure_position.x < -0.3, "it is outside the west wall, not in the corridor")
	_expect(house.hall_glow.position.x < house.figure_position.x, "the glow is behind it")
	_expect(
		house.figure.position.is_equal_approx(house.figure_position),
		"the head is already in view the moment the door opens"
	)
	var sounds_after: int = house.find_children("*", "AudioStreamPlayer3D", true, false).size()
	_expect(sounds_after == sounds_before, "the silhouette beat adds no sound")

	# A second and a half after the door opens it flees.
	_expect(is_equal_approx(house.figure_wait_seconds, 1.5), "it flees 1.5 s after the door opens")
	await _wait(0.2)
	_expect(house.figure.visible, "it is still there 0.2 s after the door opens")
	await _until(func() -> bool: return not house.figure.visible, "it ducking out of sight", 3.0)
	_expect(not house.hall_glow.visible and not house.hall_light.visible, "the glow and light go with it")
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"house_silhouette_done", false)),
		"the silhouette is remembered"
	)

	# It happens once: after closing and opening the door again nothing returns.
	pantry_door.interact(player)
	pantry_door.interact(player)
	await _wait(1.0)
	_expect(not house.figure.visible, "the silhouette does not come back")

	# The key opens the master bedroom for good.
	_expect(
		bedroom_door.get_prompt_text_for_player(player) == "PROMPT_UNLOCK",
		"the bedroom door offers to unlock"
	)
	bedroom_door.interact(player)
	_expect(not bedroom_door.is_locked and bedroom_door.is_open, "the key opens the bedroom door")
	_expect(not player.has_inventory_item("master_key"), "the key is used up")


func _check_diary_and_footsteps() -> void:
	var drawer: DrawerInteractable = house.get_node("Furniture/NightstandDrawer")
	var diary: Inspectable = house.get_node(
		"Furniture/NightstandDrawer/DrawerRoot/ItemAnchor/LucasDiary"
	)
	_expect(not _is_collectable(diary), "the diary is read in place")
	_expect(not house.run_steps.playing, "nobody runs yet")

	var closed_z: float = drawer.drawer_root.position.z
	drawer.interact(player)
	await _wait(1.5)
	_expect(drawer.is_open, "the drawer opens")
	_expect(drawer.drawer_root.position.z > closed_z + 0.2, "the drawer slides out of the front")
	await _ray_finds(diary, _front_of(drawer, 1.04), diary.global_position, "the diary in the open drawer")
	_expect(not house.run_steps.playing, "opening the drawer starts nothing")

	# Opening the diary starts someone running towards the master bedroom, the
	# footsteps coming closer and louder while the player reads.
	diary.interact(player)
	var door_mark: Vector3 = house.run_path[house.run_path.size() - 1]
	var marks: Array[Vector3] = []
	var volumes: Array[float] = []
	var waited: float = 0.0
	while waited < 20.0 and (marks.is_empty() or marks[marks.size() - 1] != door_mark):
		await get_tree().process_frame
		waited += get_process_delta_time()
		var here: Vector3 = house.run_steps.position
		if house.run_steps.playing and (marks.is_empty() or marks[marks.size() - 1] != here):
			marks.append(here)
			volumes.append(house.run_steps.volume_db)

	_expect(player.inspect_controller.is_open(), "the player is still reading the diary")
	_expect(marks.size() >= 8, "many quick running steps, not three spaced ones (%d)" % marks.size())
	_expect(
		marks[0].distance_to(door_mark) > marks[marks.size() / 2].distance_to(door_mark)
		and marks[marks.size() / 2].distance_to(door_mark) > marks[marks.size() - 1].distance_to(door_mark) - 0.01,
		"the steps get closer to the master bedroom door"
	)
	_expect(volumes[volumes.size() - 1] > volumes[0] + 10.0, "and much louder")
	_expect(
		marks[marks.size() - 1].is_equal_approx(door_mark),
		"the runner ends at the master bedroom door"
	)
	await _wait(2.0)
	_expect(
		house.run_steps.position.is_equal_approx(door_mark),
		"nothing runs any further"
	)
	_close_view()
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"house_diary_scare_done", false)),
		"the footsteps are remembered"
	)


# ============================================================
# HELPERS
# ============================================================

## Opens an inspectable in the inspect view, waits, and closes it again.
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


func _is_collectable(node: Node) -> bool:
	return node is Collectible


## The player must be able to reach every clue with the interaction ray: a collision
## body covering an item hides it from the ray even though `interact()` still works.
func _check_interaction_rays() -> void:
	var furniture: Node = house.get_node("Furniture")
	var capsule_node: Node3D = capsule
	await _ray_finds(
		furniture.get_node("PantryNote"), _beside(furniture.get_node("PantryNote"), -0.8),
		furniture.get_node("PantryNote").global_position, "the pantry note"
	)
	await _ray_finds(
		furniture.get_node("MasterKey"), _beside(furniture.get_node("MasterKey"), -0.8),
		furniture.get_node("MasterKey").global_position, "the key"
	)
	await _ray_finds(
		furniture.get_node("KitchenRecipe"), _beside(furniture.get_node("KitchenRecipe"), 0.6),
		furniture.get_node("KitchenRecipe").global_position, "the recipe in the sink"
	)
	await _ray_finds(
		furniture.get_node("NoteCapsule"), _front_of(capsule, 1.05),
		furniture.get_node("NoteCapsule").global_position, "the note on the capsule"
	)
	await _ray_finds(
		capsule_node, _front_of(capsule, 1.05),
		capsule_node.get_node("Model/Padlock").global_position, "the padlock"
	)
	var drawer: Node3D = furniture.get_node("NightstandDrawer")
	await _ray_finds(
		drawer, _front_of(drawer, 1.04), drawer.global_position + Vector3(0.0, 0.0, 0.15),
		"the nightstand drawer"
	)


## Stands the player at `stand`, aims at `aim`, and checks the interaction ray
## ends on `item`.
func _ray_finds(item: Node, stand: Vector3, aim: Vector3, what: String) -> void:
	player.global_position = stand
	player.velocity = Vector3.ZERO
	await _wait(0.4)

	var camera: Camera3D = player.get_node("Head/Camera3D")
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


## A standing point `distance` metres in front of a node (its local +Z), at eye level.
func _front_of(node: Node3D, distance: float) -> Vector3:
	var point: Vector3 = node.global_position + node.global_basis.z * distance
	return Vector3(point.x, 1.0, point.z)


## A standing point `offset` metres along X from a node's position, at eye level.
func _beside(node: Node3D, offset: float) -> Vector3:
	return Vector3(node.global_position.x + offset, 1.0, node.global_position.z)
