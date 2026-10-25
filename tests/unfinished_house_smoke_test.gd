extends Node

## Plays the whole unfinished house through the game's own APIs (inspect, pickups, doors, the drawer,
## the flashlight key) and checks each step: the rooms opening one after another (recipe, pantry,
## key, bedroom, notebook), the pantry's muffled arguing, the climax (red light, running footsteps,
## the capsule's clack), the hallway trap (the light dies, the silhouette, the doors slam and lock,
## the second light) and the exit with Lucas's Ficha. Run it as a scene; it quits by itself with a
## non-zero exit code on failure. Game time runs faster so the beats do not take their full length.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_unfinished_house_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/unfinished_house_playtest.tscn"
const TIME_SCALE: float = 4.0

var test_failed: bool = false
var completed_count: int = 0

var house: UnfinishedHouseSequence = null
var player: CharacterBody3D = null
var capsule: TimeCapsule = null
var flashlight: Node = null
var front_door: DoorController = null
var back_door: DoorController = null
var pantry_door: DoorController = null
var bedroom_door: DoorController = null


func _ready() -> void:
	DoorController.approach_enabled = false
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
	front_door = house.get_node("Doors/FrontDoor")
	back_door = house.get_node("Doors/BackDoor")
	pantry_door = house.get_node("Doors/PantryDoor")
	bedroom_door = house.get_node("Doors/BedroomDoor")
	house.sequence_completed.connect(func() -> void: completed_count += 1)
	Engine.time_scale = TIME_SCALE

	await _run()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("UNFINISHED_HOUSE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	GameSettings.set_text_locale("en", false)
	await _check_layout()
	await _check_kitchen_opens_the_pantry()
	await _check_pantry_voices_and_key()
	await _check_bedroom_and_climax()
	await _check_hallway_trap()
	await _check_the_trap_cannot_stick()
	await _check_capsule_and_exit()


# ============================================================
# STEPS
# ============================================================

func _check_layout() -> void:
	_expect(player.is_in_group(&"player"), "the player joins the player group")
	_expect(house.get_node("Shell").get_child_count() > 30, "the house shell is built")
	_expect(house.get_node("Shell").find_children("Glass*", "", true, false).is_empty(), "the windows are unfinished: no glass panes")

	# No padlock any more: the capsule is closed and cannot be used until the climax.
	_expect(capsule.get_node("Model").get_node_or_null("Padlock") == null, "the capsule has no padlock")
	_expect(capsule.get_node_or_null("Model/Latch") != null, "it is closed with an iron latch")
	_expect(not capsule.is_open and not capsule.is_unlatched, "the time capsule starts closed and latched")
	_expect(capsule.get_node_or_null("Contents") == null, "the capsule's contents are out of reach")
	_expect(not (capsule as Node).has_method("interact"), "the capsule cannot be used")

	_expect(pantry_door.is_locked and not pantry_door.is_open, "the pantry door starts LOCKED")
	_expect(bedroom_door.is_locked, "the master bedroom door starts locked")
	_expect(not house.silhouette.visible and not house.bedroom_light.visible, "no silhouette, no red light yet")
	_expect(not house.argument_voices.playing, "no arguing yet")

	pantry_door.interact(player)
	await _wait(1.0)
	_expect(pantry_door.is_locked and not pantry_door.is_open, "it stays shut: the player cannot open it yet")
	bedroom_door.interact(player)
	_expect(bedroom_door.is_locked and not bedroom_door.is_open, "the bedroom door stays shut without the key")
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


func _check_kitchen_opens_the_pantry() -> void:
	# A note is read in place: it opens the inspect view and stays where it lies.
	var note: Inspectable = house.get_node("Furniture/NoteCapsule")
	_expect(not _is_collectable(note), "the note on the capsule is not collectable")
	await _read(note, 0.5)
	_expect(is_instance_valid(note), "the note stays where it lies")
	_expect(pantry_door.is_locked, "reading that note opens nothing")

	# The recipe: Juliana comments, and when it is put away the pantry unlocks and swings open.
	var recipe: Inspectable = house.get_node("Furniture/KitchenRecipe")
	_expect(not _is_collectable(recipe), "the recipe is not collectable")
	flashlight.call("restore_save_state", {"is_on": true})
	recipe.interact(player)
	await _wait(2.4)
	_expect(
		bool(SaveManager.get_state_value(&"triggers", &"house_recipe_open", false)),
		"Juliana comments on the recipe"
	)
	_expect(pantry_door.is_locked, "the pantry door is still locked while the recipe is read")
	var sounds_before: Array[int] = _sound_ids()
	_close_view()
	await _until(func() -> bool: return not pantry_door.is_locked, "the pantry door unlocking", 10.0)
	var click: Array = _sound_ids().filter(func(id: int) -> bool: return not sounds_before.has(id))
	_expect(not click.is_empty(), "with a click that can be heard (a new sound at the door)")
	_expect(not pantry_door.is_open, "the door has not started to open yet")
	await _until(func() -> bool: return pantry_door.is_open, "then the pantry door swinging open by itself", 10.0)
	await _until(
		func() -> bool: return absf(pantry_door.hinge.rotation_degrees.y - pantry_door.closed_rotation_degrees.y) > 60.0,
		"it swinging open", 15.0
	)
	_expect(bool(flashlight.get("flashlight_on")), "nothing dims the flashlight")


func _check_pantry_voices_and_key() -> void:
	front_door.interact(player)
	back_door.interact(player)
	await _wait(3.0)
	_expect(front_door.is_open and back_door.is_open, "the front and back doors are open")

	_expect(pantry_door.is_open, "the pantry door is open when the player comes in")
	_expect(not house.argument_voices.playing, "no arguing yet")

	# The note, the first time: the arguing FADES IN from the hallway and the pantry door quietly closes.
	var note: Inspectable = house.get_node("Furniture/PantryNote")
	note.interact(player)
	await _wait(0.3)
	_expect(player.inspect_controller.is_open(), "the pantry note opens the inspect view")
	_expect(house.argument_voices.playing, "muffled arguing starts")
	_expect(house.argument_voices.volume_db < house.voices_db - 3.0, "quietly at first (%.0f dB)" % house.argument_voices.volume_db)
	_expect(house.argument_voices.stream is AudioStreamWAV and (house.argument_voices.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED, "as a loop")
	_expect(house.argument_voices.position.z > 6.2 and house.argument_voices.position.z < 8.5, "it comes from the hallway")
	var sounds_before: Array[int] = _sound_ids()
	await _until(func() -> bool: return not pantry_door.is_open, "the pantry door closing by itself", 10.0)
	await _wait(3.0)
	_expect(absf(pantry_door.hinge.rotation_degrees.y - pantry_door.closed_rotation_degrees.y) < 1.0, "all the way shut")
	_expect(not pantry_door.is_locked, "but not locked")
	_expect(is_equal_approx(house.argument_voices.volume_db, house.voices_db), "the arguing is at full level by now")
	var new_sounds: Array = _sound_ids().filter(func(id: int) -> bool: return not sounds_before.has(id))
	_expect(new_sounds.is_empty(), "the door closed silently")

	# Putting the note away does not stop it.
	_close_view()
	await _wait(2.0)
	_expect(house.argument_voices.playing, "the arguing goes on after the note is put away")

	# The key: taking it starts nothing.
	var key: Collectible = house.get_node("Furniture/MasterKey")
	key.interact(player)
	_expect(player.has_inventory_item("master_key"), "the key goes in the inventory")
	await _wait(0.6)
	_close_view()
	await _wait(3.0)
	_expect(front_door.is_open and back_door.is_open, "taking the key slams no door")
	_expect(house.argument_voices.playing, "and the arguing still goes on")
	_expect(bool(flashlight.get("flashlight_on")), "the flashlight stays on")
	_expect(not house.silhouette.visible, "and nobody shows at a window")

	# Opening the closed pantry door ends it: the arguing fades out.
	pantry_door.interact(player)
	await _wait(0.9)
	_expect(house.argument_voices.playing and house.argument_voices.volume_db < house.voices_db - 3.0, "when the pantry door is opened the arguing fades out")
	await _until(func() -> bool: return not house.argument_voices.playing, "and stops", 10.0)
	await _wait(2.0)
	_expect(not house.argument_voices.playing, "it does not come back")

	# Reading the note again does not repeat it.
	await _read(note, 0.8)
	_expect(not house.argument_voices.playing, "reading the note again repeats nothing")


func _check_bedroom_and_climax() -> void:
	# The key opens the master bedroom for good.
	_expect(
		bedroom_door.get_prompt_text_for_player(player) == "PROMPT_UNLOCK",
		"the bedroom door offers to unlock"
	)
	bedroom_door.interact(player)
	_expect(not bedroom_door.is_locked and bedroom_door.is_open, "the key opens the bedroom door")
	_expect(not player.has_inventory_item("master_key"), "the key is used up")
	await _until(func() -> bool: return bedroom_door._choreo == &"", "the key and the opening playing out", 15.0)

	var drawer: DrawerInteractable = house.get_node("Furniture/NightstandDrawer")
	var diary: Inspectable = house.get_node(
		"Furniture/NightstandDrawer/DrawerRoot/ItemAnchor/LucasDiary"
	)
	_expect(not _is_collectable(diary), "the diary is read in place")
	var closed_z: float = drawer.drawer_root.position.z
	drawer.interact(player)
	await _wait(1.5)
	_expect(drawer.is_open and drawer.drawer_root.position.z > closed_z + 0.2, "the drawer slides out")
	await _ray_finds(diary, _front_of(drawer, 1.04), diary.global_position, "the diary in the open drawer")

	# Reading the notebook starts nothing; putting it away starts the climax.
	diary.interact(player)
	await _wait(2.0)
	_expect(player.inspect_controller.is_open(), "the player is reading the notebook")
	_expect(not house.bedroom_light.visible and not house.run_steps.playing, "nothing happens while it is read")
	_expect(house.tension_player == null or not house.tension_player.playing, "and the string tension has not started")
	_expect(not capsule.is_unlatched, "the capsule is still latched")

	_close_view()
	await _wait(0.3)
	_expect(house.bedroom_light.visible, "the bedroom light turns on")
	_expect(house.tension_player != null and house.tension_player.playing, "and the string tension starts with it, as the notebook is put away")
	var tension: AudioStreamMP3 = house.tension_player.stream as AudioStreamMP3 if house.tension_player != null else null
	_expect(tension != null and tension.resource_path.ends_with("placeholder_string_tension.mp3") and tension.get_length() > 12.0, "it is placeholder_string_tension (%.1f s)" % (tension.get_length() if tension != null else 0.0))
	_expect(house.bedroom_light.light_color.r > 0.9 and house.bedroom_light.light_color.g < 0.15 and house.bedroom_light.light_color.b < 0.15, "a vivid RED")
	await _wait(1.0)
	_expect(house.bedroom_light.light_energy > 1.0, "and it is bright")
	_expect(player.manual_save_blocked, "saving is blocked during the climax")

	# Running footsteps from inside the bedroom, down the hallway, into the living room.
	var marks: Array[Vector3] = []
	var volumes: Array[float] = []
	var end_mark: Vector3 = house.run_path[house.run_path.size() - 1]
	var waited: float = 0.0
	while waited < 25.0 and (marks.is_empty() or marks[marks.size() - 1] != end_mark):
		await get_tree().process_frame
		waited += get_process_delta_time()
		var here: Vector3 = house.run_steps.position
		if house.run_steps.playing and (marks.is_empty() or marks[marks.size() - 1] != here):
			marks.append(here)
			volumes.append(house.run_steps.volume_db)

	_expect(marks.size() >= 10, "many quick running steps (%d)" % marks.size())
	_expect(marks[0].x > 4.65 and marks[0].z < 6.2, "they start inside the master bedroom")
	var in_hallway: bool = false
	for mark: Vector3 in marks:
		if mark.z > 6.3 and mark.z < 8.4:
			in_hallway = true
	_expect(in_hallway, "they race down the hallway")
	_expect(marks[marks.size() - 1].z > 8.6, "and end in the living room")
	_expect(volumes[0] > volumes[volumes.size() - 1], "fading as the runner gets away")

	# Then the iron latch of the capsule is thrown: a loud clack.
	await _until(func() -> bool: return capsule.is_unlatched, "the capsule's latch being thrown", 5.0)
	_expect(capsule._sound.stream != null and capsule._sound.volume_db > 0.0, "with a loud clack")
	await _wait(0.8)
	_expect(capsule.get_node("Model/LidPivot").rotation_degrees.x < -3.0, "the lid pops ajar")
	_expect(capsule.get_node_or_null("Contents") == null, "but nothing inside is within reach")
	_expect(not capsule.is_open, "the capsule is not open yet")


func _check_hallway_trap() -> void:
	flashlight.call("restore_save_state", {"is_on": true})
	# Walking around the hallway away from the living room: nothing.
	player.global_position = Vector3(7.0, 1.05, 7.4)
	player.velocity = Vector3.ZERO
	await _wait(0.6)
	_expect(bool(flashlight.get("flashlight_on")) and not house.silhouette.visible, "the east hallway is safe")

	# Walking down towards the living room: the flashlight dies and the figure is there.
	player.global_position = Vector3(2.0, 1.05, 7.35)
	player.velocity = Vector3.ZERO
	await _wait(0.6)
	_expect(not bool(flashlight.get("flashlight_on")), "the flashlight goes out by itself")
	_expect(house.silhouette.visible, "a silhouette stands in the living room")
	_expect(house.silhouette.global_position.distance_to(capsule.global_position) < 1.0, "over the time capsule")
	_expect(house.bedroom_light.visible, "the red light is still on")
	_expect(not front_door.is_locked and not capsule.is_open, "nothing else has changed")

	# Switching the light back on is allowed, in the hallway and anywhere: the instinct is to do it, and
	# nothing happens until the beam finds the figure.
	flashlight.call("player_toggle")
	_expect(bool(flashlight.get("flashlight_on")), "the player switches the flashlight back on")
	await _wait(2.0)
	_expect(bool(flashlight.get("flashlight_on")), "and it stays on in the hallway")
	_expect(not front_door.is_locked and not back_door.is_locked, "no door slams")
	_expect(house._stage == UnfinishedHouseSequence.Stage.TRAP_CUT, "the trap is still waiting")

	# In the living room, with the beam pointing away from the figure: still nothing.
	player.global_position = Vector3(3.5, 1.05, 12.2)
	player.velocity = Vector3.ZERO
	await _aim_player_at(Vector3(3.5, 1.2, 15.0))
	await _wait(1.0)
	_expect(bool(flashlight.get("flashlight_on")) and house._stage == UnfinishedHouseSequence.Stage.TRAP_CUT, "pointing the light elsewhere does nothing")
	_expect(not house._figure_in_beam(), "the beam is not on the figure")

	# The detection is generous (it must never leave the player stuck): any part of the figure counts,
	# the lamp's flicker does not matter, and lingering nearby with the light on springs it anyway.
	# (Probing with the stage frozen, or finding it would spring the real trap.)
	var base_dwell: float = house.figure_dwell_seconds
	var base_idle: float = house.figure_idle_seconds
	house._stage = UnfinishedHouseSequence.Stage.RESOLVED
	house.figure_dwell_seconds = 999.0
	house.figure_idle_seconds = 999.0
	var figure_feet: Vector3 = house.silhouette.global_position
	await _aim_player_at(figure_feet + Vector3(0.0, 0.2, 0.0))
	_expect(house._figure_in_beam(), "looking at its feet finds it")
	await _aim_player_at(figure_feet + Vector3(0.0, 1.6, 0.0))
	_expect(house._figure_in_beam(), "looking at its head finds it")
	(flashlight as SpotLight3D).visible = false
	_expect(house._figure_in_beam(), "a blink of the lamp does not hide it")
	(flashlight as SpotLight3D).visible = true
	var camera_pos: Vector3 = player.get_node("Head/Camera3D").global_position
	var off_axis: Vector3 = figure_feet + Vector3(0.0, 1.0, 0.0) + Vector3(0.0, 0.0, 0.0)
	var lateral: Vector3 = (off_axis - camera_pos).cross(Vector3.UP).normalized() * (off_axis - camera_pos).length() * 0.45
	await _aim_player_at(off_axis + lateral)
	_expect(not house._figure_in_beam() and house._figure_near_and_visible(), "loosely looking its way is caught by the fallback")

	# The figure lit at the edge of the beam (the bug: the light plainly lit it, a good way off the middle of the
	# beam, and nothing happened): found, near or far.
	var spot: SpotLight3D = flashlight as SpotLight3D
	for stand: Vector3 in [Vector3(3.5, 1.05, 12.2), Vector3(2.6, 1.05, 12.2)]:
		player.global_position = stand
		player.velocity = Vector3.ZERO
		var to_figure: Vector3 = off_axis - stand
		for share: float in [0.18, 0.24]:
			var sideways: Vector3 = to_figure.cross(Vector3.UP).normalized() * to_figure.length() * share
			await _aim_player_at(off_axis + sideways)
			var axis: Vector3 = -spot.global_basis.z
			var off_degrees: float = rad_to_deg(axis.angle_to(off_axis - spot.global_position))
			_expect(off_degrees < spot.spot_angle and house._figure_in_beam(), "the figure lit %.0f degrees off the middle of the beam, %.1f m away, is found" % [off_degrees, stand.distance_to(off_axis)])

	# Even looking away, standing near it with the light on for long enough springs it (nobody can be stuck).
	house.figure_idle_seconds = base_idle
	house._figure_idle = base_idle - 0.2
	await _aim_player_at(Vector3(3.5, 1.2, 15.0))
	player.global_position = Vector3(5.5, 1.05, 12.2)
	house._stage = UnfinishedHouseSequence.Stage.TRAP_CUT
	await _until(func() -> bool: return house._stage != UnfinishedHouseSequence.Stage.TRAP_CUT, "standing near the figure with the light on long enough springs the trap, however the player looks", 4.0)
	_expect(house._stage == UnfinishedHouseSequence.Stage.SLAMMING or house._stage == UnfinishedHouseSequence.Stage.SLAMMED, "(the reveal runs)")
	await _until(func() -> bool: return house._stage == UnfinishedHouseSequence.Stage.SLAMMED, "and it ends with the doors shut", 6.0)
	# Put back as it was for the real run of the trap below (the player away from the figure, looking elsewhere).
	house.figure_dwell_seconds = 999.0
	house.figure_idle_seconds = 999.0
	player.global_position = Vector3(3.5, 1.05, 12.2)
	player.velocity = Vector3.ZERO
	await _aim_player_at(Vector3(3.5, 1.2, 15.0))
	house._stage = UnfinishedHouseSequence.Stage.TRAP_CUT
	for door: DoorController in house._doors():
		door.unlock()
	flashlight.call("restore_save_state", {"is_on": true})
	house.silhouette.visible = true
	house._pose_figure(&"bowed")
	house._figure_dwell = 0.0
	house._figure_idle = 0.0
	await _wait(0.3)
	house.figure_dwell_seconds = base_dwell
	house.figure_idle_seconds = base_idle

	# The beam finds the figure: for half a second the light is weak and stutters, and each time it
	# comes back the figure is different. Then it dies and every door slams and locks.
	var full_energy: float = (flashlight as SpotLight3D).light_energy
	await _check_unease_pulse()
	await _aim_player_at(house.silhouette.global_position + Vector3(0.0, 1.0, 0.0))
	await _until(func() -> bool: return house._stage == UnfinishedHouseSequence.Stage.SLAMMED, "pointing the light at the figure springs the trap", 8.0)
	var log: Array[Dictionary] = house.reveal_log
	var total: float = 0.0
	var poses: Dictionary = {}
	var offs: int = 0
	var lit_strongest: float = 0.0
	for beat: Dictionary in log:
		total += float(beat["seconds"])
		if bool(beat["on"]):
			poses[beat["pose"]] = true
			lit_strongest = maxf(lit_strongest, float(beat["energy"]))
		else:
			offs += 1
	_expect(absf(total - 0.5) < 0.1, "the reveal lasts half a second (%.2f s)" % total)
	_expect(lit_strongest < full_energy * 0.3 and lit_strongest > 0.0, "the light is weak the whole time, never full (%.1f of %.1f)" % [lit_strongest, full_energy])
	_expect(offs >= 3, "and it stutters (%d dark beats)" % offs)
	_expect(poses.size() >= 4, "the figure is in a different pose every time the light comes back (%s)" % str(poses.keys()))
	await _until(
		func() -> bool: return front_door.is_locked and back_door.is_locked and pantry_door.is_locked and bedroom_door.is_locked,
		"every door slamming shut and locking", 10.0
	)
	await _wait(0.5)
	_expect(not front_door.is_open and not back_door.is_open and not pantry_door.is_open and not bedroom_door.is_open, "every door is shut")
	_expect(not bool(flashlight.get("flashlight_on")), "and the flashlight goes out")
	_expect(is_equal_approx((flashlight as SpotLight3D).light_energy, full_energy), "(its strength is given back for next time)")
	_expect(house.silhouette.visible and house._figure_pose == &"near", "the figure is still there, nearer")
	_expect(not capsule.is_open, "the capsule is still closed")

	# The next light switched on: everything is back to normal.
	flashlight.call("player_toggle")
	_expect(bool(flashlight.get("flashlight_on")), "the player switches it on again")
	await _wait(0.3)
	_expect(not house.silhouette.visible, "the silhouette is gone")
	await _until(func() -> bool: return not house.bedroom_light.visible, "the red light settling back", 8.0)
	_expect(capsule.is_open, "the time capsule sits open on the crate")
	_expect(capsule.get_node("Model/LidPivot").rotation_degrees.x < -90.0, "its lid wide open")
	_expect(capsule.get_node_or_null("Contents") != null, "and its contents are within reach")
	_expect(not player.manual_save_blocked, "saving works again")
	_expect(
		front_door.is_locked and back_door.is_locked,
		"the doors stay locked until the Ficha is taken"
	)
	_expect(bool(flashlight.get("flashlight_on")), "the flashlight stays on")
	_expect(completed_count == 0, "the scene is not over yet")

	# It happens once: more presses change nothing.
	flashlight.call("player_toggle")
	flashlight.call("player_toggle")
	await _wait(0.8)
	_expect(not house.silhouette.visible and front_door.is_locked, "pressing the flashlight again does nothing")


func _check_capsule_and_exit() -> void:
	var ad: Inspectable = capsule.get_node("Contents/HouseAdvertisement")
	var ticket_sophia: Inspectable = capsule.get_node("Contents/BusTicketSophia")
	var ticket_unclaimed: Inspectable = capsule.get_node("Contents/BusTicketUnclaimed")
	var ficha: Collectible = capsule.get_node("Contents/LucasFicha")
	_expect(not _is_collectable(ad), "the house advertisement is read in place")
	_expect(not _is_collectable(ticket_sophia), "Sophia's ticket is read in place")
	_expect(not _is_collectable(ticket_unclaimed), "the unclaimed ticket is read in place too")
	_expect(_is_collectable(ficha) and ficha.item_id == "lucas_ficha", "Lucas's Ficha is the one thing to take")
	await _check_contents_in_view(ficha, [ad, ticket_sophia, ticket_unclaimed])

	await _ray_finds(ticket_unclaimed, _front_of(capsule, 1.05), ticket_unclaimed.global_position, "the unclaimed ticket in the chest")
	await _ray_finds(ficha, _front_of(capsule, 1.05), ficha.global_position, "the Ficha in the chest")
	await _ray_finds(ticket_sophia, _front_of(capsule, 1.05), ticket_sophia.global_position, "Sophia's ticket in the chest")
	await _ray_finds(
		ad, _front_of(capsule, 1.05), ad.global_position + capsule.global_basis.z * 0.09,
		"the advertisement in the chest (its edge, the tickets lie on top)"
	)
	await _read(ad, 0.5)
	await _read(ticket_sophia, 0.5)
	await _read(ticket_unclaimed, 0.5)
	_expect(not player.has_inventory_item("bus_ticket_unclaimed"), "reading the unclaimed ticket takes nothing")
	_expect(completed_count == 0, "nothing ends the scene before the Ficha is taken")

	# Lucas's Ficha: his name stamped on the front, "never left" scratched on the back (hidden details).
	var visual: Node = ficha.get_node("Visual")
	var stamp: ReadableSpot = visual.find_child("StampSpot", true, false) as ReadableSpot
	var scratch: ReadableSpot = visual.find_child("ScratchSpot", true, false) as ReadableSpot
	_expect(stamp != null and not stamp.obvious and tr(stamp.text_key) == "LUCAS", "its front is stamped LUCAS (a hidden detail)")
	_expect(scratch != null and not scratch.obvious and tr(scratch.text_key) == "NEVER LEFT", "its back is scratched NEVER LEFT (a hidden detail)")
	_expect(stamp.get_facing_normal().dot(scratch.get_facing_normal()) < -0.9, "on opposite faces")
	_expect(tr(ficha.item_description) == "A brass telephone token, dented, scratched and a little bent.", "the description is unchanged")

	# Taking it: the doors unlock without a sound and the scene ends.
	var sounds_before: Array[int] = _sound_ids()
	_expect(ficha.can_interact(player), "the Ficha can be taken")
	ficha.interact(player)
	_expect(player.has_inventory_item("lucas_ficha"), "the Ficha goes in the inventory")
	_expect(player.inspect_controller.is_open(), "taking it shows it in the inspect view")
	_expect(front_door.is_locked, "the doors are still locked while it is being looked at")
	await _wait(0.6)
	_close_view()
	await _wait(0.6)
	_expect(completed_count == 1, "closing the Ficha raises sequence_completed once")
	_expect(
		not front_door.is_locked and not back_door.is_locked and not pantry_door.is_locked and not bedroom_door.is_locked,
		"every door is unlocked, the front exit included"
	)
	var new_sounds: Array = _sound_ids().filter(func(id: int) -> bool: return not sounds_before.has(id))
	_expect(new_sounds.is_empty(), "silently")
	front_door.interact(player)
	await _wait(1.0)
	_expect(front_door.is_open, "and the front door can be opened")
	await _wait(1.0)
	_expect(completed_count == 1, "nothing else happens after it")


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


## Every 3D sound player in the house outside the doors (they make their own sounds).
func _sound_ids() -> Array[int]:
	var ids: Array[int] = []
	for sound: Node in house.find_children("*", "AudioStreamPlayer3D", true, false):
		ids.append(sound.get_instance_id())

	return ids


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
	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractRay")
	var found: Node = null
	# The camera is still settling after the move (the player drops to the floor) and the view eases towards where it is told
	# to look, so the aim is taken again from where the camera is now, until the ray arrives. An item that cannot be reached
	# never does, and the check fails after the last try.
	for attempt: int in 3:
		var to_aim: Vector3 = aim - camera.global_position
		player.movement_controller.look_yaw = -rad_to_deg(atan2(-to_aim.x, -to_aim.z))
		player.movement_controller.look_pitch = -rad_to_deg(
			atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length())
		)
		await _wait(0.6)
		for i: int in 3:
			await get_tree().physics_frame

		ray.force_raycast_update()
		found = ray.get_collider() as Node
		while found != null and not found is Interactable:
			found = found.get_parent()

		if found == item:
			break

	_expect(
		found == item,
		"the interaction ray reaches %s (hit %s)" % [what, str(ray.get_collider().get_path()) if ray.get_collider() != null else "nothing"]
	)


## A standing point `distance` metres in front of a node (its local +Z), at eye level.
func _front_of(node: Node3D, distance: float) -> Vector3:
	var point: Vector3 = node.global_position + node.global_basis.z * distance
	return Vector3(point.x, 1.0, point.z)


## A standing point `offset` metres along X from a node's position, at eye level.
func _beside(node: Node3D, offset: float) -> Vector3:
	return Vector3(node.global_position.x + offset, 1.0, node.global_position.z)


## Turns the player to look at a world point.
func _aim_player_at(aim: Vector3) -> void:
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var to_aim: Vector3 = aim - camera.global_position
	player.movement_controller.look_yaw = -rad_to_deg(atan2(-to_aim.x, -to_aim.z))
	player.movement_controller.look_pitch = -rad_to_deg(atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length()))
	await _wait(0.8)


## The screen smears while the unease pulse lasts, then goes back to what it was.
func _check_unease_pulse() -> void:
	var horror: Node = get_node("/root/HorrorFilter")
	var filter_material: ShaderMaterial = (horror.get("horror_rect") as ColorRect).material as ShaderMaterial
	var base: float = float(filter_material.get_shader_parameter("chroma_separation_pixels"))
	Engine.time_scale = 1.0
	horror.call("pulse_unease", 1.0, 0.6)
	await _wait(0.2)
	var peak: float = float(filter_material.get_shader_parameter("chroma_separation_pixels"))
	_expect(peak > base + 0.8, "the picture smears during the scare (colour fringes %.1f from %.1f)" % [peak, base])
	await _wait(0.8)
	_expect(is_equal_approx(float(filter_material.get_shader_parameter("chroma_separation_pixels")), base), "and settles back afterwards")
	Engine.time_scale = TIME_SCALE


## Everything in the open capsule can be seen from a standing player's eyes, without leaning over its
## front wall: from every distance the player can stand at, the line from their eye to each item
## passes above the front rim.
func _check_contents_in_view(ficha: Node3D, others: Array) -> void:
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var rim_height: float = 0.12
	var worst: float = 99.0
	for distance: float in [0.7, 0.9, 1.2, 1.6, 2.0]:
		var stand: Vector3 = capsule.global_position + capsule.global_basis.z * distance
		player.global_position = Vector3(stand.x, 0.1, stand.z)
		player.velocity = Vector3.ZERO
		await _wait(0.4)
		var eye: Vector3 = capsule.to_local(camera.global_position)
		var targets: Array = [ficha]
		targets.append_array(others)
		for item: Node3D in targets:
			var target: Vector3 = capsule.to_local(item.global_position)
			var along: float = (0.14 - eye.z) / (target.z - eye.z)
			var height_at_rim: float = eye.y + along * (target.y - eye.y)
			worst = minf(worst, height_at_rim - rim_height)
	_expect(worst > 0.0, "every item in the capsule is in view over the front rim, from any standing distance (clearance %.3f m)" % worst)
	_expect(ficha.global_position.y > capsule.global_position.y + 0.1, "the Ficha lies near the rim, on top, not at the bottom of a deep box")


## The trap cannot get stuck: every stage has a watchdog (see the sequence's header). Each is tried here by making the
## stage it guards go wrong in the way that would have stuck it.
func _check_the_trap_cannot_stick() -> void:
	var spot: SpotLight3D = flashlight as SpotLight3D

	# 1. A reveal that stalled (stage SLAMMING for good): finished by the watchdog, the doors shut, the light out.
	_reset_trap_for_test()
	house._stage = UnfinishedHouseSequence.Stage.SLAMMING
	house._reveal_elapsed = 0.0
	house.reveal_failsafe_seconds = 0.4
	await _until(func() -> bool: return house._stage == UnfinishedHouseSequence.Stage.SLAMMED, "a reveal that stalls is finished by its watchdog", 6.0)
	_expect(front_door.is_locked and back_door.is_locked and not bool(flashlight.get("flashlight_on")), "with every door shut and locked and the light out")
	house.reveal_failsafe_seconds = 3.0

	# 2. The light comes on again but the signal never reaches the house: the house is put right all the same.
	flashlight.call("restore_save_state", {"is_on": true})
	flashlight.set("flashlight_on", true)
	await _until(func() -> bool: return house._stage == UnfinishedHouseSequence.Stage.RESOLVED, "the house is put right as soon as the light is on again, signal or not", 6.0)
	_expect(not house.silhouette.visible and capsule.is_open, "the figure is gone and the capsule is open")

	# 3. The very last resort: the figure stands there, the player does nothing at all (the light is out, they are far away).
	_reset_trap_for_test()
	house._stage = UnfinishedHouseSequence.Stage.TRAP_CUT
	house.silhouette.visible = true
	house._trap_elapsed = 0.0
	house.trap_failsafe_seconds = 0.6
	player.global_position = Vector3(2.0, 1.05, 7.35)
	flashlight.call("turn_off")
	await _until(func() -> bool: return house._stage == UnfinishedHouseSequence.Stage.SLAMMED, "with the figure out and nobody looking, the trap springs by itself in the end", 8.0)
	house.trap_failsafe_seconds = 30.0

	# 4. The link to the flashlight is lost (the player was not there in time): retried until it holds.
	house._flashlight = null
	house._connected = false
	await _wait(1.5)
	_expect(house._connected and house._flashlight == flashlight, "the link to the player's flashlight is made again when it was lost")

	# 5. The player is already standing in the hallway when the trap arms (ran ahead of the climax): the figure is shown.
	_reset_trap_for_test()
	player.global_position = Vector3(2.0, 1.05, 7.35)
	player.velocity = Vector3.ZERO
	await _wait(0.4)
	house._stage = UnfinishedHouseSequence.Stage.TRAP_ARMED
	await _until(func() -> bool: return house._stage == UnfinishedHouseSequence.Stage.TRAP_CUT and house.silhouette.visible, "a player already in the hallway when the trap arms is caught too", 6.0)

	# 6. The developer console's way out, from any state.
	house.force_resolve()
	_expect(house._stage == UnfinishedHouseSequence.Stage.RESOLVED and not house.silhouette.visible, "house_unstick puts the house right from any state")

	# Back to the state the rest of the test expects: put right, the doors locked until the Ficha is taken.
	house.force_resolve()
	for door: DoorController in house._doors():
		door.lock()
	player.global_position = Vector3(3.5, 1.05, 12.2)
	player.velocity = Vector3.ZERO
	flashlight.call("restore_save_state", {"is_on": true})


## The house as it is just after the climax: the figure hidden, the doors open and unlocked, the capsule shut, the light on.
func _reset_trap_for_test() -> void:
	house.silhouette.visible = false
	house._trap_elapsed = 0.0
	house._figure_dwell = 0.0
	house._figure_idle = 0.0
	player.global_position = Vector3(7.0, 1.05, 7.4)
	player.velocity = Vector3.ZERO
	for door: DoorController in house._doors():
		door.unlock()

	house._stage = UnfinishedHouseSequence.Stage.CLIMAX
