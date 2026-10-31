extends Node

## Plays the whole unfinished house through the game's own APIs (inspect, pickups, doors, the postcard) and checks each
## step of the revised sequence: the recipe beside the sink (the fall behind the player, the pantry's latch, the door part
## way open, the bulb on), the pantry (the door closing behind the player once, the arguing only while the note has been
## read, the door is shut and the player is in), the bedroom key, the notebook on the bed and the empty drawer (nothing
## happens), the postcard's directed scene (read in her hands, the paper over the whole picture at both changes of time with
## the writing on the same pixels, the one still memory shot, the seventeen lines, the paper lowered back, the far, square,
## slowly approaching door shot, the slow footsteps, one slow press, the slow opening to 45 degrees with no one there, the camera going slowly to her eyes, the
## door put back unseen, the hand back with no snap; one played without subtitles and one cancelled half way), the capsule
## opened with its key, the Ficha, a reload, games saved by the old sequences, and the pause. Run it as a scene; it quits by
## itself with a non-zero exit code on failure. Game time runs faster so the beats do not take their full length.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_unfinished_house_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/unfinished_house_playtest.tscn"
const HOUSE_SCENE_PATH: String = "res://scenes/levels/unfinished_house.tscn"
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
var drawer: DrawerInteractable = null
var card: Postcard = null
var card_home: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DoorController.approach_enabled = false
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(
		1, TEST_SCENE_PATH, "house_test_start", "SAVE_LOCATION_DREAM_INTRO"
	)
	GameSettings.set_captions_enabled(true, false)

	var level: Node = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	drawer = house.get_node("Furniture/NightstandDrawer")
	card = house.get_node("Furniture/Postcard")
	card_home = card.global_transform
	house.sequence_completed.connect(func() -> void: completed_count += 1)
	Engine.time_scale = TIME_SCALE

	await _run()

	Engine.time_scale = 1.0
	get_tree().paused = false
	GameSettings.set_captions_enabled(true, false)
	SaveManager.delete_slot(1)
	print("UNFINISHED_HOUSE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	GameSettings.set_text_locale("en", false)
	await _check_layout()
	await _check_kitchen()
	await _check_pantry()
	await _check_bedroom_and_notebook()
	await _check_memory_scene()
	await _check_postcard_again()
	await _check_capsule_and_ficha()
	await _check_memory_without_captions()
	await _check_memory_cancelled()
	await _check_reload()
	await _check_legacy_saves()
	_check_copy()


# ============================================================
# STEPS
# ============================================================

func _check_layout() -> void:
	_expect(player.is_in_group(&"player"), "the player joins the player group")
	_expect(house.get_node("Shell").get_child_count() > 30, "the house shell is built")

	# The old finale is gone: no red light, no runner, no figure, no trap, no reaction to the recipe.
	for gone: String in ["Scares", "RecipeReaction", "Scares/BedroomRed", "Scares/Silhouette", "Scares/HallwayTrap", "Scares/RunSteps"]:
		_expect(house.get_node_or_null(gone) == null, "the old %s is gone" % gone)
	_expect(_red_lights().is_empty(), "no red light anywhere in the house")
	_expect(house.find_children("*", "Area3D", true, false).filter(func(a: Node) -> bool: return a.name == "HallwayTrap").is_empty(), "no hallway trap")

	_expect(capsule.required_key_id.is_empty() and not capsule.story_unlocked, "the capsule wants no key, and is not unlocked yet")
	_expect(not capsule.is_open and not capsule.is_unlatched, "the time capsule starts closed")
	_expect(capsule.get_node_or_null("Contents") == null, "its contents are out of reach")
	_expect(capsule.get_prompt_text() == "PROMPT_LOCKED", "it says it is locked")

	_expect(pantry_door.is_locked and not pantry_door.is_open, "the pantry door starts LOCKED")
	_expect(bedroom_door.is_locked and bedroom_door.required_key_id == "master_key", "the bedroom is locked; the existing key opens it")
	_expect(not back_door.is_locked and not front_door.is_locked, "the back and front doors are not locked")
	_expect(not house.argument_voices.playing, "no arguing yet")
	_expect(not house.is_pantry_lamp_on(), "the pantry bulb is off")
	_expect(not house.memory_root.visible, "the memory's dressing is hidden")
	capsule.interact(player)
	_expect(not capsule.is_open and not capsule._opening, "and trying it opens nothing")

	# The drawer is empty, and no notebook lies on the bed.
	_expect(drawer.get_node("DrawerRoot/ItemAnchor").get_child_count() == 0, "the nightstand drawer is empty")
	_expect(drawer.find_children("*", "Interactable", true, false).is_empty(), "nothing to read or take in it")
	_expect(not house.get_node("Memory/Bed").is_visible_in_tree() and house.get_node("Memory").find_children("*", "CollisionShape3D", true, false).all(func(c: Node) -> bool: return (c as CollisionShape3D).disabled), "the bed is only in the memory (not shown, not solid, in the night)")
	_expect(not house.living_light.visible, "the living room light is off before the scene")
	_expect(house.get_node_or_null("Furniture/LucasDiary") == null and house.get_node_or_null("Furniture/CapsuleKey") == null, "the notebook is gone from the bed, and there is no key in the scene")

	# Lucas's postcard on the nightstand: an ordinary readable world prop (not an item), its writing up; no clock.
	var nightstand: Node3D = house.get_node("Furniture/Nightstand")
	_expect(not _is_collectable(card) and card is Inspectable, "the postcard is read in place, not taken")
	_expect(card.get_prompt_text() == "PROMPT_INSPECT" and card.inspect_name == "ITEM_POSTCARD_NAME" and card.get_visual_node().get_meta("readable_text", "") == "READABLE_POSTCARD", "it offers \"Inspect\" under its own name, and its writing can be read")
	_expect(tr("ITEM_POSTCARD_NAME") == "Postcard" and tr("ITEM_POSTCARD_DESCRIPTION") == "A postcard of the town, written by Lucas. No address or stamp.", "its name and description")
	_expect(absf(card.global_position.y - 0.576) < 0.01 and Vector2(card.global_position.x - nightstand.global_position.x, card.global_position.z - nightstand.global_position.z).length() < 0.2, "it lies on the nightstand")
	_expect(card.get_visual_node().global_basis.z.y > 0.99, "written side up")
	_expect(card.plays_scene, "and its reading is the scene's")
	_expect(house.get_node_or_null("Furniture/AlarmClock") == null and house.find_children("*", "AlarmClock", true, false).is_empty(), "the clock is gone from the nightstand")
	_expect(house.find_children("*", "Camera3D", true, false).is_empty(), "the house keeps no camera of its own in the level")

	# The recipe lies on the counter beside the sink, not in it.
	var recipe: Inspectable = house.get_node("Furniture/KitchenRecipe")
	var sink: Node3D = house.get_node("Furniture/KitchenSink")
	var in_sink: Vector3 = sink.to_local(recipe.global_position)
	_expect(absf(in_sink.x) > 0.5, "the recipe is beside the sink (%.2f m along it from its middle)" % in_sink.x)
	_expect(absf(recipe.global_position.y - 0.9) < 0.02, "on the counter's plank")

	await _check_interaction_rays()


func _check_kitchen() -> void:
	# In by the back door.
	player.global_position = Vector3(1.865, 1.05, -1.6)
	player.velocity = Vector3.ZERO
	await _wait(0.4)
	back_door.interact(player)
	await _until(func() -> bool: return back_door._choreo == &"", "the back door opening", 10.0)
	_expect(back_door.is_open, "the back door opens into the kitchen")

	# A note is read in place and opens nothing.
	var note: Inspectable = house.get_node("Furniture/NoteCapsule")
	await _read(note, 0.4)
	_expect(pantry_door.is_locked, "reading the capsule's note opens nothing")

	var recipe: Inspectable = house.get_node("Furniture/KitchenRecipe")
	_expect(not _is_collectable(recipe), "the recipe is read in place")
	flashlight.call("restore_save_state", {"is_on": true})
	# Standing in the kitchen facing the counter (west): "behind" is the east side of the room.
	player.global_position = Vector3(1.4, 1.05, 2.6)
	player.velocity = Vector3.ZERO
	await _aim_player_at(recipe.global_position)

	recipe.interact(player)
	await _wait(1.6)
	_expect(pantry_door.is_locked, "the pantry stays locked while the recipe is read")
	_expect(not CaptionManager.panel.visible, "no line is spoken over the recipe")
	var sounds_before: Array[int] = _sound_ids()
	var eye: Vector3 = (player.get_node("Head/Camera3D") as Camera3D).global_position
	var forward: Vector3 = -(player.get_node("Head/Camera3D") as Camera3D).global_basis.z
	_close_view()

	await _until(func() -> bool: return _new_sounds(sounds_before).size() > 0, "something falls after the recipe is put away", 6.0)
	var fall: Array = _new_sounds(sounds_before)
	var fall_at: Vector3 = (instance_from_id(fall[0]) as Node3D).global_position
	var flat: Vector3 = Vector3(fall_at.x - eye.x, 0.0, fall_at.z - eye.z)
	_expect(flat.normalized().dot(Vector3(forward.x, 0.0, forward.z).normalized()) < -0.5, "behind the player")
	_expect(house.to_local(fall_at).y < 0.5 and house.to_local(fall_at).x < 4.65, "on the kitchen floor")
	_expect(pantry_door.is_locked, "the pantry is still locked when it falls")
	_expect(not CaptionManager.panel.visible, "with no voice (no \"Juliana?\")")

	await _until(func() -> bool: return not pantry_door.is_locked, "then the pantry latch gives", 8.0)
	await _until(func() -> bool: return pantry_door.is_open, "the pantry door opens by itself", 6.0)
	await _until(func() -> bool: return house.is_pantry_lamp_on(), "its warm bulb comes on", 4.0)
	await _until(func() -> bool: return _pantry_angle() > 45.0, "the door swinging", 20.0)
	await _wait(4.0)
	_expect(_pantry_angle() > 45.0 and _pantry_angle() < 65.0, "only part way open (%.0f degrees)" % _pantry_angle())
	_expect(house.pantry_light.light_color.r > 0.9 and house.pantry_light.light_color.g > 0.6 and house.pantry_light.light_color.b < 0.6, "a warm light")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"house_recipe_done", false)), "the recipe is remembered as read")
	_expect(not bool(SaveManager.get_state_value(&"triggers", &"house_recipe_open", false)), "the old recipe reaction is not used")
	_expect(bool(flashlight.get("flashlight_on")), "the flashlight was not touched")
	# Turning for the corridor, a little before the arch, the flashlight goes out by itself (so the pantry's bulb and the open door are seen).
	player.global_position = house.to_global(Vector3(2.33, 1.05, 2.5))
	await _wait(0.3)
	_expect(bool(flashlight.get("flashlight_on")), "far from the corridor the flashlight stays on")
	player.global_position = house.to_global(Vector3(2.33, 1.05, 4.6))
	await _wait(0.5)
	_expect(not bool(flashlight.get("flashlight_on")), "near the corridor's arch the flashlight goes out by itself")
	flashlight.set("flashlight_on", true)

	# Reading it again plays nothing.
	var angle: float = _pantry_angle()
	sounds_before = _sound_ids()
	await _read(recipe, 0.4)
	await _wait(4.0)
	_expect(_new_sounds(sounds_before).is_empty(), "reading the recipe again plays nothing")
	_expect(absf(_pantry_angle() - angle) < 1.0 and house.is_pantry_lamp_on(), "and changes nothing")


func _check_pantry() -> void:
	var flashlight_was_on: bool = bool(flashlight.get("flashlight_on"))
	_expect(not house.is_argument_playing(), "no arguing before the pantry")

	# Just inside, still in the door's swing: it does not move.
	player.global_position = Vector3(9.75, 1.05, 7.7)
	player.velocity = Vector3.ZERO
	await _wait(1.5)
	_expect(house.is_player_in_pantry(), "(the player is in the pantry)")
	_expect(pantry_door.is_open, "the door waits while the player is in its swing")

	# All the way in: it swings gently shut behind them.
	var sounds_before: Array[int] = _sound_ids()
	player.global_position = Vector3(10.8, 1.05, 8.4)
	player.velocity = Vector3.ZERO
	await _until(func() -> bool: return not pantry_door.is_open, "the pantry door closing behind the player", 4.0)
	await _wait(0.25)
	_expect(_pantry_angle() > 15.0, "gently, not slammed (%.0f degrees left after a quarter second)" % _pantry_angle())
	await _until(func() -> bool: return house.is_pantry_door_shut(), "it shuts", 10.0)
	await _until(func() -> bool: return _new_sounds(sounds_before).size() > 0, "a soft latch as it meets the frame", 6.0)
	_expect(not pantry_door.is_locked, "it is not locked")
	_expect(house.is_pantry_lamp_on(), "the bulb stays on")
	_expect(bool(flashlight.get("flashlight_on")) == flashlight_was_on, "the flashlight is not forced either way")
	await _wait(1.5)
	_expect(not house.is_argument_playing() and not house.argument_voices.playing, "no arguing before the note is read")

	# Leaving without the key: the door opens from inside and stays open after.
	pantry_door.interact(player)
	await _until(func() -> bool: return pantry_door._choreo == &"", "the player opening the pantry door", 10.0)
	_expect(pantry_door.is_open, "the player can leave the pantry")
	player.global_position = Vector3(8.0, 1.05, 7.4)
	player.velocity = Vector3.ZERO
	await _wait(1.0)
	player.global_position = Vector3(10.8, 1.05, 8.4)
	player.velocity = Vector3.ZERO
	await _wait(3.0)
	_expect(pantry_door.is_open, "coming back in, the door does not close by itself again")

	# The note, with the door open: nothing to hear yet.
	var note: Inspectable = house.get_node("Furniture/PantryNote")
	await _read(note, 0.6)
	_expect(not house.is_argument_playing(), "with the door open, reading the note brings no arguing")

	# The door shut, the player in: the arguing comes from the hallway.
	pantry_door.interact(player)
	await _until(func() -> bool: return house.is_pantry_door_shut(), "the player shutting the pantry door", 10.0)
	await _until(func() -> bool: return house.argument_voices.playing, "muffled arguing starts behind the shut door", 3.0)
	_expect(house.argument_voices.volume_db < house.voices_db - 1.0, "fading in (%.0f dB)" % house.argument_voices.volume_db)
	_expect(house.argument_voices.stream is AudioStreamWAV and (house.argument_voices.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED, "as a loop")
	var source: Vector3 = house.to_local(house.argument_voices.global_position)
	_expect(source.z > 6.2 and source.z < 8.525 and source.x < 9.3, "from the hallway")
	await _wait(2.5)
	_expect(is_equal_approx(house.argument_voices.volume_db, house.voices_db), "at full level by now")

	# Opening the door cuts it at once; shutting it again brings it back.
	pantry_door.interact(player)
	await _wait(0.2)
	_expect(not house.argument_voices.playing, "opening the door cuts the arguing at once")
	await _until(func() -> bool: return pantry_door._choreo == &"", "the opening playing out", 10.0)
	await _wait(1.0)
	_expect(not house.argument_voices.playing, "it stays quiet while the door is open")
	pantry_door.interact(player)
	await _until(func() -> bool: return house.is_pantry_door_shut(), "the door shut again", 10.0)
	await _until(func() -> bool: return house.argument_voices.playing, "the arguing resumes", 3.0)

	# Out of the pantry (the door shut): quiet.
	player.global_position = Vector3(8.0, 1.05, 7.4)
	player.velocity = Vector3.ZERO
	await _wait(0.5)
	_expect(not house.argument_voices.playing, "outside the pantry there is no arguing")
	player.global_position = Vector3(10.8, 1.05, 8.4)
	player.velocity = Vector3.ZERO
	await _until(func() -> bool: return house.argument_voices.playing, "back inside with the door shut, it plays again", 3.0)

	# The key can be taken whenever: it starts nothing.
	var key: Collectible = house.get_node("Furniture/MasterKey")
	key.interact(player)
	_expect(player.has_inventory_item("master_key"), "the bedroom key goes in the inventory")
	await _wait(0.6)
	_close_view()
	await _wait(1.0)
	_expect(not pantry_door.is_locked and not front_door.is_locked, "taking it locks nothing")
	pantry_door.interact(player)
	await _until(func() -> bool: return pantry_door._choreo == &"", "the player opening the pantry door to leave", 10.0)
	_expect(pantry_door.is_open and not house.argument_voices.playing, "the way out is open, and the arguing stops")


func _check_bedroom_and_notebook() -> void:
	player.global_position = Vector3(7.4, 1.05, 7.4)
	player.velocity = Vector3.ZERO
	await _wait(0.4)
	_expect(bedroom_door.get_prompt_text_for_player(player) == "PROMPT_UNLOCK", "the bedroom door offers to unlock")
	bedroom_door.interact(player)
	_expect(not bedroom_door.is_locked and bedroom_door.is_open, "the key opens the bedroom door")
	_expect(not player.has_inventory_item("master_key"), "the key is used up")
	await _until(func() -> bool: return bedroom_door._choreo == &"", "the key and the opening playing out", 15.0)


	# Walking up to the bed and opening the empty drawer: nothing either.
	player.global_position = Vector3(7.58, 1.05, 1.45)
	player.velocity = Vector3.ZERO
	await _wait(1.0)
	_expect(not house.memory_running, "being in the room starts nothing")
	drawer.interact(player)
	await _wait(1.5)
	_expect(drawer.is_open and not house.memory_running and not house.in_memory, "opening the drawer starts nothing (no memory, no door scene)")
	_expect(not CaptionManager.panel.visible and not bool(player.get("view_locked")), "no line, and the player keeps the controls")
	drawer.interact(player)
	await _wait(0.6)


func _check_memory_scene() -> void:
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var movement: PlayerMovementController = player.movement_controller
	var spot: SpotLight3D = flashlight as SpotLight3D
	player.global_position = Vector3(7.58, 1.05, 1.45)
	player.velocity = Vector3.ZERO
	await _ray_finds(card, Vector3(7.58, 1.05, 1.45), card.global_position, "the postcard from beside the bed")
	await _wait(0.8)
	var stand: Vector3 = player.global_position
	var eye_height: float = camera.global_position.y
	var gameplay_fov: float = camera.fov
	var yaw_held_ref: float = INF
	var bow_lift: float = 0.0
	var bow_lower: float = 0.0
	var bow_samples_lift: Array[float] = []
	var other_sounds: int = 0
	var beam_far: float = -1.0
	var beam_near: float = 99.0
	var door_x_error: float = 0.0
	var screen_centre_error: float = 99.0
	var whole_door_at_end: bool = false
	var beam_early: float = -1.0
	var eyes_on_door_at_cut: float = 99.0
	var beam_off_after: bool = false
	var beam_first_off: float = 0.0
	var cinema_last: Transform3D = Transform3D.IDENTITY
	var cinema_last_fov: float = 0.0
	var blend_error: float = 99.0
	var blend_fov_error: float = 99.0
	var max_crack_open: float = 0.0

	card.interact(player)
	await get_tree().process_frame
	_expect(house.memory_running, "reading the postcard starts the scene")
	_expect(not player.inspect_controller.is_open(), "and not the generic inspect view")
	_expect(player.manual_save_blocked and not player.can_manual_save(), "saving is blocked from the first step")
	var walked_from: Vector3 = player.global_position
	await _until(func() -> bool: return house._held != null, "she is walked to the nightstand and held", 14.0)
	_expect(player.global_position.distance_to(walked_from) > 0.3 and Vector2(player.global_position.x - house.postcard_stand.global_position.x, player.global_position.z - house.postcard_stand.global_position.z).length() < 0.3, "she walks closer to the nightstand first (%.2f m)" % player.global_position.distance_to(walked_from))
	stand = player.global_position
	eye_height = camera.global_position.y
	_expect(bool(player.get("view_locked")) and player.manual_save_blocked and not player.can_manual_save(), "the player is held and saving is blocked")
	_expect(movement.view_motion_still, "the player's own camera motion is stilled for the scene")

	# Things the player might try: the postcard again, the inventory.
	card.interact(player)
	player.inventory_ui_controller.toggle(player.inventory_controller.get_slots())
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(house.memory_log.filter(func(e: Dictionary) -> bool: return e["beat"] == &"start").size() == 1, "reading it again starts nothing more")
	_expect(not player.is_inventory_open() and not player.inspect_controller.is_open(), "the inventory and the inspect view stay shut")

	var captions: Array[String] = []
	var caption_times: Array[float] = []
	var inspect_seen: bool = false
	var control_slipped: bool = false
	var max_drift: float = 0.0
	var max_eye_change: float = 0.0
	var max_roll: float = 0.0
	var pov_turn_while_held: float = 0.0
	var held_seen: bool = false
	var duplicate_seen: bool = false
	var written_side_to_her: bool = false
	var held_pixels: Array = []
	var registration_in: float = -1.0
	var registration_out: float = -1.0
	var covered_in: bool = false
	var covered_out: bool = false
	var cinema_pixels: Array = []
	var memory_motion: float = 0.0
	var memory_settled: Transform3D = Transform3D.IDENTITY
	var memory_settled_seen: bool = false
	var swap_times: Array[float] = []
	var memory_was: bool = house.memory_root.visible
	var unlocked_during: bool = false
	var steps_seen: Dictionary = {}
	var door_cut_ok: bool = false
	var whole_door_at_cut: bool = false
	var distance_at_cut: float = 0.0
	var distance_at_end: float = 99.0
	var square_on: float = 0.0
	var door_direction_change: float = 0.0
	var door_forward: Vector3 = Vector3.ZERO
	var door_fov_change: float = 0.0
	var door_fov: float = -1.0
	var lever_before_handle: float = 0.0
	var presses: int = 0
	var pressed: bool = false
	var press_start: float = -1.0
	var press_end: float = -1.0
	var max_crack: float = 0.0
	var ajar_at_cut: float = -1.0
	var door_seen_at_reset: bool = true
	var paused_checked: bool = false
	var last_forward: Vector3 = Vector3.ZERO
	var previous_camera: Camera3D = null
	var waited: float = 0.0
	while house.memory_running and waited < 260.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		var view: Camera3D = get_viewport().get_camera_3d()
		var forward: Vector3 = -view.global_basis.z
		var now: float = _scene_time()
		var flat: Vector3 = player.global_position - stand
		flat.y = 0.0
		max_drift = maxf(max_drift, flat.length())
		max_eye_change = maxf(max_eye_change, absf(camera.global_position.y - eye_height))
		inspect_seen = inspect_seen or player.inspect_controller.is_open()
		if house.memory_running:
			control_slipped = control_slipped or not bool(player.get("view_locked")) or not player.manual_save_blocked
		# The head bows to the nightstand taking the postcard up and putting it down, and is up for the reading.
		var bow: float = -movement.gesture_pitch_degrees
		if _logged(&"lift") and not _logged(&"dissolve_in"):
			bow_lift = maxf(bow_lift, bow)
			bow_samples_lift.append(bow)
		if _logged(&"lower") and not _logged(&"settled"):
			bow_lower = maxf(bow_lower, bow)
		# Nothing but the steps is heard: no other sound of the house's is playing during the scene.
		if _logged(&"lift") and not _logged(&"released"):
			for sound: Node in house.find_children("*", "AudioStreamPlayer3D", true, false):
				var other: AudioStreamPlayer3D = sound as AudioStreamPlayer3D
				if other.playing and other.stream != house._step_sound and not other.has_meta(&"footfall") and not bedroom_door.is_ancestor_of(other) and other != house.argument_voices:
					other_sounds += 1
		max_roll = maxf(max_roll, absf(rad_to_deg(asin(clampf(view.global_basis.x.y, -1.0, 1.0)))))
		last_forward = -camera.global_basis.z
		var held: Node3D = house.held_card if house.held_card != null and is_instance_valid(house.held_card) else null

		# In her hands: through her own eyes, which do not move; never two postcards seen at once; the writing to her.
		if held != null and held.visible:
			held_seen = true
			if view == camera and now > 0.5:
				# (Her heading, not her pitch: the head bows to the nightstand, which is meant.)
				var heading: float = rad_to_deg(atan2(forward.x, forward.z))
				if yaw_held_ref == INF:
					yaw_held_ref = heading
				pov_turn_while_held = maxf(pov_turn_while_held, absf(wrapf(heading - yaw_held_ref, -180.0, 180.0)))
				if house._held_near > 0.95:
					written_side_to_her = held.global_basis.z.dot(camera.global_position - held.global_position) > 0.0
			if card.visible:
				duplicate_seen = true
			if not _logged(&"dissolve_in"):
				held_pixels = _card_on_screen(view, held.global_transform)
		if _logged(&"return") and not _logged(&"dissolve_out") and view != camera:
			cinema_pixels = _card_on_screen(view, card.get_visual_node().global_transform)

		# The paper seams: the same writing on the same pixels, and the paper over the whole picture.
		if _logged(&"dissolve_in") and registration_in < 0.0:
			var now_pixels: Array = _card_on_screen(view, card.get_visual_node().global_transform)
			registration_in = _worst_pixel(held_pixels, now_pixels)
			covered_in = _covers_screen(now_pixels)
		if _logged(&"dissolve_out") and registration_out < 0.0 and held != null:
			var back_pixels: Array = _card_on_screen(view, held.global_transform)
			registration_out = _worst_pixel(cinema_pixels, back_pixels)
			covered_out = _covers_screen(back_pixels)

		# The memory's one shot: still once it is composed.
		if _logged(&"conversation") and now > _logged_time(&"pullback") + house.pullback_seconds + 0.1 and not _logged(&"return") and view != camera:
			if not memory_settled_seen:
				memory_settled_seen = true
				memory_settled = view.global_transform
			memory_motion = maxf(memory_motion, view.global_position.distance_to(memory_settled.origin) * 1000.0 + rad_to_deg(forward.angle_to(-memory_settled.basis.z)))
		if house.memory_root.visible != memory_was:
			memory_was = house.memory_root.visible
			swap_times.append(now)


		if capsule.story_unlocked and house.memory_running:
			unlocked_during = true

		# The footsteps.
		if _logged(&"steps") and not _logged(&"handle"):
			for sound: Node in house.find_children("*", "AudioStreamPlayer3D", true, false):
				var step_player: AudioStreamPlayer3D = sound as AudioStreamPlayer3D
				if step_player.stream == house._step_sound and step_player.playing and not steps_seen.has(step_player.get_instance_id()):
					steps_seen[step_player.get_instance_id()] = [house.to_local(step_player.global_position), step_player.volume_db, now]

		# The door: a hard cut square on from far back, the whole door in the picture, one lens, a straight approach that never
		# turns; one slow press; a slow opening, wide; nothing on the other side.
		if _logged(&"door") and _logged_time(&"door") == now and view != camera:
			eyes_on_door_at_cut = rad_to_deg((-camera.global_basis.z).angle_to((house._door_middle() - camera.global_position).normalized()))
			door_cut_ok = previous_camera == camera and view.global_position.distance_to(house.door_front_wide.global_position) < 0.001
			whole_door_at_cut = _door_wholly_in(view, 0.03)
			square_on = absf(forward.dot(bedroom_door.global_basis.z))
			door_forward = forward
			door_fov = view.fov
			distance_at_cut = absf((view.global_position - bedroom_door.global_position).dot(bedroom_door.global_basis.z))
		# The door's opening is followed to its end, which comes after the camera has started back to her eyes.
		if _logged(&"crack") and not bedroom_door.is_open:
			max_crack = maxf(max_crack, _bedroom_angle())
		if _logged(&"open"):
			max_crack_open = maxf(max_crack_open, _bedroom_angle())
		if _logged(&"door") and not _logged(&"to_eyes") and view != camera:
			door_direction_change = maxf(door_direction_change, rad_to_deg(forward.angle_to(door_forward)))
			door_fov_change = maxf(door_fov_change, absf(view.fov - door_fov))
			distance_at_end = absf((view.global_position - bedroom_door.global_position).dot(bedroom_door.global_basis.z))
		# The flashlight: pointing back at the nightstand at the cut (not at the door, not in the picture), coming round to the door
		# after a few steps, swaying; her own aim again at the end.
		if _logged(&"door") and not _logged(&"to_eyes") and view != camera:
			var hand: Vector3 = (flashlight as Node3D).global_position
			var aim: Vector3 = flashlight.get("scripted_aim_direction")
			var to_door: Vector3 = (house._door_middle() - hand).normalized()
			var off: float = rad_to_deg(aim.angle_to(to_door))
			var since: float = now - _logged_time(&"door")
			if since > 0.3 and since < 0.9:
				beam_early = maxf(beam_early, off)
				beam_first_off = maxf(beam_first_off, rad_to_deg(aim.angle_to((card.global_position - hand).normalized())))
			if since > 8.0:
				beam_near = minf(beam_near, off)
			# The door camera is centred on the door the whole way, and the picture's middle is the door's.
			door_x_error = maxf(door_x_error, absf(view.global_position.x - bedroom_door.global_position.x - 0.45))
			if _logged(&"crack"):
				var door_centre: Vector2 = view.unproject_position(bedroom_door.to_global(Vector3(0.45, 1.0, 0.0)))
				screen_centre_error = minf(screen_centre_error, (door_centre - get_viewport().get_visible_rect().size * 0.5).length() / get_viewport().get_visible_rect().size.y)
				whole_door_at_end = _door_wholly_in(view, 0.01)
		# The scene's camera goes to her eyes: it is where her camera is, with her lens, when the view becomes hers.
		if view != camera:
			cinema_last = view.global_transform
			cinema_last_fov = view.fov
		if _logged(&"cut_to_eyes") and blend_error > 90.0 and view == camera:
			blend_error = cinema_last.origin.distance_to(camera.global_position) + rad_to_deg((-cinema_last.basis.z).angle_to(-camera.global_basis.z))
			blend_fov_error = absf(cinema_last_fov - camera.fov)
		if _logged(&"cut_to_eyes") and not beam_off_after:
			beam_off_after = not bool(flashlight.get("scripted_aim_on"))
		var lever: float = _lever_turn()
		if not _logged(&"handle"):
			lever_before_handle = maxf(lever_before_handle, lever)
		elif not _logged(&"to_eyes"):
			if press_start < 0.0 and lever > 0.02:
				press_start = now
			if lever > 0.9 and not pressed:
				pressed = true
				presses += 1
				press_end = now
			if lever < 0.05:
				pressed = false

		# The subtitles.
		if CaptionManager.panel.visible:
			var text: String = CaptionManager.label.text
			if captions.is_empty() or captions[captions.size() - 1] != text:
				captions.append(text)
				caption_times.append(now)
		if _logged(&"cut_to_eyes") and ajar_at_cut < 0.0 and view == camera:
			ajar_at_cut = _bedroom_angle()
		if _logged(&"door_reset") and _logged_time(&"door_reset") == now:
			door_seen_at_reset = _door_visible_to(camera)

		previous_camera = view

		# The pause stops it: in the middle of the conversation the scene and its subtitles stand still.
		if not paused_checked and _logged(&"conversation") and float(CaptionManager.get("_clock")) > 6.0:
			paused_checked = true
			var log_size: int = house.memory_log.size()
			var caption_clock: float = float(CaptionManager.get("_clock"))
			var scene_time: float = house.scene_clock
			get_tree().paused = true
			await get_tree().create_timer(1.6, true, false, true).timeout
			_expect(is_equal_approx(float(CaptionManager.get("_clock")), caption_clock), "pausing stops the subtitles' clock")
			_expect(house.memory_log.size() == log_size and is_equal_approx(house.scene_clock, scene_time), "and the scene")
			get_tree().paused = false
			previous_camera = null

	_expect(not house.memory_running, "the scene finishes (%.0f s of game time)" % waited)
	_expect(paused_checked, "(the pause was tried)")

	# The beats, in order.
	var beats: Array[StringName] = []
	for entry: Dictionary in house.memory_log:
		beats.append(entry["beat"] as StringName)
	var wanted: Array[StringName] = [&"approach", &"start", &"lift", &"dissolve_in", &"door_closed", &"pullback", &"conversation", &"return", &"dissolve_out", &"night", &"lower", &"steps", &"settled", &"steps_end", &"door", &"handle", &"latch", &"crack", &"handle_release", &"to_eyes", &"open", &"cut_to_eyes", &"flick", &"flick", &"glance_end", &"released"]
	_expect(beats == wanted, "the beats run in order: %s" % ", ".join(PackedStringArray(beats.map(func(b: StringName) -> String: return String(b)))))
	_expect(not inspect_seen, "the generic inspect view never opens during it")
	_expect(not control_slipped, "the controls never come back to the player before the end")

	# The postcard in her hands and the paper seams.
	_expect(held_seen and pov_turn_while_held < 0.2, "the postcard is lifted into her hands while her eyes stay where they were (turned %.2f degrees)" % pov_turn_while_held)
	_expect(written_side_to_her, "with the written side to her as it comes close")
	var lift_seconds_log: float = _logged_time(&"dissolve_in") - _logged_time(&"lift")
	_expect(absf(lift_seconds_log - (house.lift_seconds * 0.85 + house.look_seconds + house.show_seconds * 1.8 + house.flip_seconds + house.flip_hold_seconds + house.unflip_seconds * 0.9 + house.zoom_seconds + house.fill_hold_seconds)) < 0.2 and house.memory_log.filter(func(e: Dictionary) -> bool: return e["beat"] == &"reading" or e["beat"] == &"fill").is_empty(), "picked up slowly, looked over, turned to its picture side and back, then drawn in to the full-screen paper (%.1f s)" % lift_seconds_log)
	var lower_seconds_log: float = _logged_time(&"settled") - _logged_time(&"lower")
	_expect(bow_lift > 7.0 and bow_lower > 7.0, "she bows her head to the nightstand taking it up (%.0f degrees) and putting it down (%.0f degrees)" % [bow_lift, bow_lower])
	_expect(absf(lower_seconds_log - 3.0 * house.lower_land_share) < 0.2, "putting it down takes until the card touches the nightstand (%.1f s)" % lower_seconds_log)
	var smooth_start: bool = bow_samples_lift.size() > 8 and bow_samples_lift.max() > 8.5
	_expect(smooth_start, "the head goes down and comes back up (not one constant movement)")
	var push_seconds_log: float = _logged_time(&"dissolve_out") - _logged_time(&"return")
	_expect(push_seconds_log > 4.2 and push_seconds_log < 4.6, "the camera takes four seconds to frame the paper again (%.1f s with a moment still)" % push_seconds_log)
	_expect(other_sounds == 0, "no sound but the footsteps plays in the scene (%d other)" % other_sounds)
	_expect(not duplicate_seen, "never two postcards at once (the one on the nightstand is hidden while one is held)")
	_expect(covered_in and covered_out, "the paper is most of the picture, centred, with the room at its edges, at both changes of time")
	_expect(registration_in >= 0.0 and registration_in < 0.5 and registration_out >= 0.0 and registration_out < 0.5, "the writing stays on the same pixels through both (%.2f and %.2f px)" % [registration_in, registration_out])
	_expect(swap_times.size() == 2 and swap_times[0] - _logged_time(&"dissolve_in") < 0.12 and swap_times[0] >= _logged_time(&"dissolve_in") and swap_times[1] - _logged_time(&"dissolve_out") < 0.12 and swap_times[1] >= _logged_time(&"dissolve_out"), "the room changes only under the paper")
	_expect(memory_settled_seen and memory_motion < 0.01, "the memory holds one still shot (%.4f)" % memory_motion)
	_expect(max_roll < 0.05, "no shot ever rolls (%.3f degrees)" % max_roll)
	_expect(card.visible and (house.held_card == null or not is_instance_valid(house.held_card)), "the postcard is back on the nightstand, and nothing is left in her hands")
	_expect(card.global_transform.is_equal_approx(card_home), "exactly where it was")

	# The subtitles: the seventeen lines in order, with the right speakers (no voice playing, and no "Shh.").
	var speakers: String = "SLSLSLSLSLSLSLSSL"
	var expected: Array[String] = []
	for i: int in range(1, 18):
		expected.append(tr("CAPTION_HOUSE_BED_%02d" % i))
	var order_ok: bool = captions.size() == expected.size()
	for i: int in mini(captions.size(), expected.size()):
		order_ok = order_ok and captions[i].ends_with(expected[i])
		if i < 17:
			var who: String = tr("CAPTION_SPEAKER_SOPHIA") if speakers[i] == "S" else tr("CAPTION_SPEAKER_LUCAS")
			order_ok = order_ok and captions[i].begins_with(who + ":")
	_expect(order_ok, "the seventeen lines (and nothing after them) are subtitled in order, each by its speaker (%d shown)" % captions.size())
	_expect(house.memory_voice == null and house.memory_voice_player.stream == null, "no voice: subtitles only")
	# The silences between lines (from the end of one to the start of the next), from the track itself.
	var silence: Dictionary = {}
	var cues: Array = CaptionTracks.get_cues(CaptionTracks.HOUSE_BEDROOM_MEMORY)
	for i: int in range(1, cues.size()):
		silence[str(cues[i - 1]["key"])] = float(cues[i]["start"]) - float(cues[i - 1]["end"])
	var pauses: Array[float] = [float(silence["CAPTION_HOUSE_BED_04"]), float(silence["CAPTION_HOUSE_BED_08"]), float(silence["CAPTION_HOUSE_BED_15"])]
	_expect(pauses.all(func(p: float) -> bool: return p >= 1.0 and p <= 2.0) and float(silence["CAPTION_HOUSE_BED_01"]) < 1.0, "short pauses after cues 04, 08 and 15 (%s), not between every line" % str(pauses))
	_expect(float(silence["CAPTION_HOUSE_BED_11"]) > pauses.max() and float(silence["CAPTION_HOUSE_BED_11"]) <= 2.5, "a slightly longer silence after \"All right.\" (%.1f s)" % float(silence["CAPTION_HOUSE_BED_11"]))

	# From the last line to the first step: the hold, the push into the paper, the paper lowered, three seconds of the room.
	var last_line_end: float = _logged_time(&"conversation") + 49.8
	var to_steps: float = _logged_time(&"door") - last_line_end
	_expect(to_steps > 10.0 and to_steps < 14.5, "the first footstep comes %.1f s after the last line ends" % to_steps)
	_expect(absf((_logged_time(&"return") - last_line_end) - 2.0) < 0.3, "the shot is held two seconds after the last line")
	_expect(absf((_logged_time(&"door") - _logged_time(&"settled")) - (house._scare_seconds() + house.night_seconds)) < 0.3, "and her eyes rest on the dark room for %.0f s before it" % house.night_seconds)
	_expect(_logged_time(&"steps") >= _logged_time(&"lower") and _logged_time(&"steps") < _logged_time(&"settled") and _logged_time(&"door") - _logged_time(&"steps") > 2.0, "the running begins while the postcard is being put away, heard before the cut (%.1f s before it)" % (_logged_time(&"door") - _logged_time(&"steps")))

	# The footsteps: slow, heavy, along the hallway, clearly heard, up to the door, done before the handle moves.
	var step_list: Array = steps_seen.values()
	_expect(step_list.size() >= 5, "footsteps come along the hallway (%d steps)" % step_list.size())
	if step_list.size() >= 2:
		var first_step: Array = step_list[0]
		var last_step: Array = step_list[step_list.size() - 1]
		var last_at: Vector3 = last_step[0]
		_expect(last_at.z > 6.2 and last_at.z < 8.525 and absf(last_at.x - 7.43) < 0.5, "they stop just outside the bedroom door")
		_expect(float(first_step[1]) >= -16.0 and float(last_step[1]) >= -4.0, "clearly heard, from %.0f dB to %.0f dB" % [float(first_step[1]), float(last_step[1])])
		var cadence: float = (float(last_step[2]) - float(first_step[2])) / float(step_list.size() - 1)
		_expect(cadence > 0.3 and cadence < 0.85, "walking, hurried to arrive in time: a step every %.2f s" % cadence)
		_expect(float(last_step[2]) - _logged_time(&"door") > -1.0 and float(last_step[2]) - _logged_time(&"door") < 3.6, "they arrive at the door a few seconds after the cut (%.1f s)" % (float(last_step[2]) - _logged_time(&"door")))
	_expect(_logged_time(&"handle") - _logged_time(&"steps_end") > 0.2 and _logged_time(&"handle") - _logged_time(&"steps_end") < 1.0, "the handle goes right after the steps stop (%.1f s)" % (_logged_time(&"handle") - _logged_time(&"steps_end")))

	# The door.
	_expect(door_cut_ok, "a hard cut from her eyes to the door camera")
	_expect(square_on > 0.999, "square on to the shut door (%.4f)" % square_on)
	_expect(whole_door_at_cut and distance_at_cut > 4.0, "far back, the whole door in the first frame (%.1f m away)" % distance_at_cut)
	_expect(door_direction_change < 0.01 and door_fov_change < 0.01, "one lens, and a camera that only ever looks along the door's normal")
	_expect(distance_at_end < distance_at_cut - 1.0 and distance_at_end > 3.2, "it creeps closer all the way, and stops far enough to keep the whole door (%.1f m to %.1f m)" % [distance_at_cut, distance_at_end])
	_expect(door_x_error < 0.02 and screen_centre_error < 0.05, "the whole shot is centred on the door (%.3f m off, %.3f of the picture's height)" % [door_x_error, screen_centre_error])
	_expect(whole_door_at_end, "the last frame still has the whole door, none of it cut off")
	_expect(beam_early >= 0.0 and beam_early < 14.0, "the flashlight is already on the door when the cut comes (%.0f degrees off it)" % beam_early)
	_expect(eyes_on_door_at_cut < 6.0, "and her eyes had turned to the door before it (%.1f degrees off it)" % eyes_on_door_at_cut)
	_expect(beam_near < 8.0, "and after a few steps it has come slowly round to the door (%.1f degrees off it by the end)" % beam_near)
	_expect(beam_off_after, "and her own beam is back at the end")
	var handle_at: float = _logged_time(&"handle") - _logged_time(&"door")
	_expect(handle_at > -0.5 and handle_at < 1.0, "the handle moves %.1f s after the cut" % handle_at)
	var crack_at: float = _logged_time(&"crack") - _logged_time(&"door")
	_expect(absf(crack_at - house.door_opens_after_cut_seconds) < 0.3, "the door starts to open %.1f s after the cut" % crack_at)
	_expect(house.find_child("DoorScene", true, false) == null and house.find_child("HallFloorLight", true, false) == null and house.find_child("StepShadow", true, false) == null and house.find_child("DoorGlimpse", true, false) == null, "no light behind the door, no shadow, no one on the other side")
	_expect(lever_before_handle < 0.01 and presses == 1 and press_end - press_start > house.handle_press_seconds * 0.6, "the handle goes down once, slowly (%.1f s from a fiftieth to nine tenths)" % (press_end - press_start))
	var held_down: float = _logged_time(&"latch") - (_logged_time(&"handle") + house.handle_press_seconds)
	_expect(held_down > 0.2, "and stays down (%.1f s) before the latch gives" % held_down)
	_expect(max_crack > 58.0 and max_crack < 62.0 and max_crack_open > 58.0 and _logged_time(&"open") - _logged_time(&"crack") > 6.0, "the door opens slowly, wide, to 60 degrees (%.1f degrees)" % max_crack)
	var to_eyes_at: float = _logged_time(&"to_eyes") - _logged_time(&"door")
	_expect(to_eyes_at > 10.0 and to_eyes_at < 20.0, "the camera starts for her eyes about twenty seconds after the cut (%.1f s)" % to_eyes_at)
	_expect(_logged_time(&"open") - _logged_time(&"crack") > 12.0, "the door takes its time to open (%.1f s)" % (_logged_time(&"open") - _logged_time(&"crack")))
	_expect(absf((_logged_time(&"open") - _logged_time(&"to_eyes")) - house.eyes_lead_seconds) < 0.3, "the camera starts back to her eyes %.1f s before the door has finished opening" % (_logged_time(&"open") - _logged_time(&"to_eyes")))

	# Her eyes: the scene's camera goes slowly to where hers is, and the view is hers there, with nothing in between.
	_expect(_logged_time(&"cut_to_eyes") - _logged_time(&"to_eyes") > 4.5, "the camera takes its time to reach her eyes (%.1f s)" % (_logged_time(&"cut_to_eyes") - _logged_time(&"to_eyes")))
	_expect(blend_error < 0.1 and blend_fov_error < 0.5, "it is her camera's place, direction and lens when the view becomes hers (%.3f, lens %.2f degrees off)" % [blend_error, blend_fov_error])
	_expect(_logged_time(&"released") - _logged_time(&"glance_end") < 0.1, "and the controls are hers once her flashlight has flickered back (no turn to the side, no \"Shh.\")")
	_expect(_logged_time(&"glance_end") - _logged_time(&"cut_to_eyes") < 3.0 and house.memory_log.filter(func(e: Dictionary) -> bool: return e["beat"] == &"flick").size() == house.return_flick_levels.size(), "her flashlight flickers twice in her own view, each time stronger")
	_expect(ajar_at_cut > 58.0, "the door is still open as she looks at it (%.1f degrees)" % ajar_at_cut)
	_expect(bedroom_door.is_open and absf(_bedroom_angle() - 60.0) < 1.0 and _lever_turn() < 0.05, "and it stays open at 60 degrees in the game, its handle up (%.1f degrees)" % _bedroom_angle())
	_expect(house._tension != null and house._tension.stream != null and _logged_time(&"handle_release") - _logged_time(&"crack") > 1.0, "the tension recording began with the door moving, the handle going back up a few centimetres into the opening")
	_expect(rad_to_deg((-camera.global_basis.z).angle_to((house._door_middle() - camera.global_position).normalized())) < 12.0, "she is looking at the door, the spot the camera was looking at")

	# Given back.
	_expect(get_viewport().get_camera_3d() == camera and (house._cinema == null or not is_instance_valid(house._cinema)), "her own camera is the view again (the scene's camera is gone)")
	_expect(not bool(player.get("view_locked")) and not player.manual_save_blocked, "the player is let go and can save again")
	_expect(not movement.view_motion_still and movement.scripted_fov == 0.0, "her camera's own motion and lens are hers")
	_expect(max_drift < 0.02 and absf(camera.global_position.y - eye_height) < 0.02, "the player is not moved (%.3f m), nor is her head (%.3f m)" % [max_drift, max_eye_change])
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(rad_to_deg((-camera.global_basis.z).angle_to(last_forward)) < 0.3, "the hand back does not move the view")
	var nudge: InputEventMouseMotion = InputEventMouseMotion.new()
	nudge.relative = Vector2(4.0, 0.0)
	var before_nudge: Vector3 = -camera.global_basis.z
	movement.handle_input(nudge, false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nudged: float = rad_to_deg((-camera.global_basis.z).angle_to(before_nudge))
	_expect(nudged > 0.05 and nudged < 2.0, "the first mouse movement turns from there, with no snap (%.2f degrees)" % nudged)
	await _wait(1.0)
	_expect(absf(camera.fov - gameplay_fov) < 1.0, "the field of view is the player's own (%.1f, was %.1f)" % [camera.fov, gameplay_fov])
	_expect(bool(flashlight.get("flashlight_on")) and spot.visible, "her flashlight stays on")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"house_bedroom_memory_done", false)), "it is remembered as played")
	_expect(capsule.story_unlocked and not unlocked_during and not capsule.is_open, "the capsule is unlocked now, with no key (and was not before)")
	_expect(not pantry_door.is_open and not house.is_pantry_lamp_on(), "the pantry is shut and its bulb out after the door scene")
	_expect(house.living_light.visible and house.living_light.light_energy > 1.0, "the living room's light is on, lit by the opened door, for the capsule")


## Game seconds since the scene began (its own clock, the one its log is written by).
func _scene_time() -> float:
	return house.scene_clock


## When a line was first shown (scene seconds), or a large number.
func _caption_time(captions: Array[String], times: Array[float], key: String) -> float:
	for i: int in captions.size():
		if captions[i].ends_with(tr(key)):
			return times[i]

	return 9999.0


## True while any corner of the bedroom door or its doorway is in `view`'s picture.
func _door_visible_to(view: Camera3D) -> bool:
	for along: float in [0.0, 0.45, 0.9]:
		for height: float in [0.0, 1.0, 2.0]:
			if view.is_position_in_frustum(bedroom_door.to_global(Vector3(along, height, 0.0))):
				return true
			if view.is_position_in_frustum(bedroom_door.door_root.to_global(Vector3(along - 0.45, height - 1.0, 0.0))):
				return true

	return false


## True when every corner of the bedroom doorway (with its frame) is in `view`'s picture, `margin` (a share of the picture) clear of its edges.
func _door_wholly_in(view: Camera3D, margin: float = 0.0) -> bool:
	var size: Vector2 = get_viewport().get_visible_rect().size
	for along: float in [-0.05, 0.95]:
		for height: float in [0.0, 2.1]:
			var at: Vector2 = view.unproject_position(bedroom_door.to_global(Vector3(along, height, 0.0)))
			if at.x < size.x * margin or at.x > size.x * (1.0 - margin) or at.y < size.y * margin or at.y > size.y * (1.0 - margin):
				return false

	return true


## Where the postcard's corners land on the screen, seen by `view` with the postcard's model at `frame` (as pixels of a 1920 by
## 1080 picture, whatever the real one).
func _card_on_screen(view: Camera3D, frame: Transform3D) -> Array:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var half: Vector2 = HouseProps.POSTCARD_SIZE * 0.5
	var out: Array = []
	for point: Vector3 in [Vector3(-half.x, -half.y, 0.0), Vector3(half.x, -half.y, 0.0), Vector3(half.x, half.y, 0.0), Vector3(-half.x, half.y, 0.0)]:
		out.append(view.unproject_position(frame * point) / size * Vector2(1920.0, 1080.0))
	return out


## True when the postcard (its corners on the screen) covers the whole picture.
func _covers_screen(corners: Array) -> bool:
	if corners.size() != 4:
		return false

	# The paper is most of the picture, not all of it: about four fifths of its width and nearly all of its height, centred, with a little
	# of the room showing at its edges.
	var low: Vector2 = Vector2(99999.0, 99999.0)
	var high: Vector2 = Vector2(-99999.0, -99999.0)
	for corner: Vector2 in corners:
		low = low.min(corner)
		high = high.max(corner)
	var width: float = (high.x - low.x) / 1920.0
	var height: float = (high.y - low.y) / 1080.0
	var middle: Vector2 = (low + high) * 0.5
	# (The test window need not be 16 by 9, so only its width, which the lens is set by, and the centring are held to.)
	return width > 0.68 and width < 0.9 and height < 1.05 and absf(middle.x - 960.0) < 90.0 and absf(middle.y - 540.0) < 150.0


## The worst distance between two sets of screen points (in pixels of a 1920 by 1080 picture).
func _worst_pixel(a: Array, b: Array) -> float:
	if a.is_empty() or a.size() != b.size():
		return 999.0

	var worst: float = 0.0
	for i: int in a.size():
		worst = maxf(worst, (a[i] as Vector2).distance_to(b[i] as Vector2))
	return worst


## After the scene the postcard is a postcard: reading it opens the ordinary inspect view, and plays nothing.
func _check_postcard_again() -> void:
	card.interact(player)
	await _wait(0.6)
	_expect(player.inspect_controller.is_open() and not house.memory_running, "reading the postcard again opens the inspect view and plays nothing")
	_close_view()
	await _wait(0.5)
	drawer.interact(player)
	await _wait(0.6)
	_expect(drawer.is_open and not house.memory_running, "nor does the drawer")
	drawer.interact(player)
	await _wait(0.6)


func _check_capsule_and_ficha() -> void:
	player.global_position = _front_of(capsule, 1.1)
	player.velocity = Vector3.ZERO
	await _wait(0.4)
	var area: Area3D = capsule.get_node("InteractArea")
	await _ray_finds(capsule, _front_of(capsule, 1.1), area.global_position, "the capsule's lock")
	_expect(capsule.get_prompt_text() == "PROMPT_UNLOCK", "the capsule offers to unlock, with no key")
	capsule.interact(player)
	await _until(func() -> bool: return capsule.is_open, "the key opens the capsule", 6.0)
	await _wait(2.0)
	_expect(capsule.get_node("Model/LidPivot").rotation_degrees.x < -90.0, "the lid stands open")
	_expect(capsule.get_node_or_null("Contents") != null, "the contents are within reach")
	_expect(not capsule.can_interact(player), "the open capsule offers nothing more")
	_expect(completed_count == 0, "the scene is not over yet")

	var ad: Inspectable = capsule.get_node("Contents/HouseAdvertisement")
	var ticket_sophia: Inspectable = capsule.get_node("Contents/BusTicketSophia")
	var ticket_unclaimed: Inspectable = capsule.get_node("Contents/BusTicketUnclaimed")
	var ficha: Collectible = capsule.get_node("Contents/LucasFicha")
	_expect(not _is_collectable(ad) and not _is_collectable(ticket_sophia) and not _is_collectable(ticket_unclaimed), "the advertisement and the tickets are read in place")
	_expect(_is_collectable(ficha) and ficha.item_id == "lucas_ficha", "Lucas's Ficha is the one thing to take")
	_expect(OverlookPhoneSequence.FICHA_IDS.has(ficha.item_id), "it is the payphone's Lucas token")
	await _ray_finds(ticket_unclaimed, _front_of(capsule, 1.05), ticket_unclaimed.global_position, "the unclaimed ticket in the chest")
	await _ray_finds(ficha, _front_of(capsule, 1.05), ficha.global_position, "the Ficha in the chest")
	await _ray_finds(ticket_sophia, _front_of(capsule, 1.05), ticket_sophia.global_position, "Sophia's ticket in the chest")
	await _ray_finds(ad, _front_of(capsule, 1.05), ad.global_position + capsule.global_basis.z * 0.09, "the advertisement in the chest (its edge)")
	await _read(ad, 0.4)
	await _read(ticket_sophia, 0.4)
	await _read(ticket_unclaimed, 0.4)
	_expect(completed_count == 0, "nothing ends the scene before the Ficha is taken")

	var visual: Node = ficha.get_node("Visual")
	var stamp: ReadableSpot = visual.find_child("StampSpot", true, false) as ReadableSpot
	var scratch: ReadableSpot = visual.find_child("ScratchSpot", true, false) as ReadableSpot
	_expect(stamp != null and tr(stamp.text_key) == "LUCAS", "its front is stamped LUCAS")
	_expect(scratch != null and tr(scratch.text_key) == "NEVER LEFT", "its back is scratched NEVER LEFT")
	_expect(tr(ficha.item_description) == "A brass telephone token, dented, scratched and a little bent.", "its description is unchanged")

	ficha.interact(player)
	_expect(player.has_inventory_item("lucas_ficha"), "the Ficha goes in the inventory")
	await _wait(0.6)
	_close_view()
	await _wait(0.6)
	_expect(completed_count == 1, "closing the Ficha raises sequence_completed once")
	for door: DoorController in house._doors():
		_expect(not door.is_locked, "%s is not locked" % door.name)
	front_door.interact(player)
	await _until(func() -> bool: return front_door._choreo == &"", "the front door opening", 10.0)
	_expect(front_door.is_open, "the front door opens: no exit is held back")
	await _wait(1.0)
	_expect(completed_count == 1, "nothing else happens after it")


## The scene keeps its timing with subtitles switched off (nothing shows, everything else plays).
func _check_memory_without_captions() -> void:
	GameSettings.set_captions_enabled(false, false)
	SaveManager.set_state_value(&"puzzles", &"house_bedroom_memory_done", false)
	house._memory_done = false
	card.plays_scene = true
	player.global_position = Vector3(7.58, 1.05, 1.45)
	player.velocity = Vector3.ZERO
	await _aim_player_at(card.global_position)
	var eyes_before: float = _logged_time(&"to_eyes")
	var door_before: float = _logged_time(&"door")
	card.interact(player)
	var any_caption: bool = false
	var waited: float = 0.0
	while house.memory_running and waited < 200.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		any_caption = any_caption or CaptionManager.panel.visible
	_expect(not house.memory_running and _logged(&"released"), "with subtitles off the scene still plays to the end")
	_expect(not any_caption, "and shows no text")
	_expect(absf(_logged_time(&"to_eyes") - eyes_before) < 1.0 and absf(_logged_time(&"door") - door_before) < 0.5, "with the same timing, the door's too (back to her eyes at %.1f s, %.1f s with subtitles)" % [_logged_time(&"to_eyes"), eyes_before])
	_expect(not bool(player.get("view_locked")) and get_viewport().get_camera_3d() == player.get_node("Head/Camera3D"), "and gives the player back")
	_expect(capsule.story_unlocked or capsule.is_open, "the capsule stays unlocked")
	GameSettings.set_captions_enabled(true, false)


## A scene cancelled in the middle (the developer console, or the house leaving the tree) gives everything back, and can be
## played again from the start.
func _check_memory_cancelled() -> void:
	SaveManager.set_state_value(&"puzzles", &"house_bedroom_memory_done", false)
	house._memory_done = false
	card.plays_scene = true
	var spot: SpotLight3D = flashlight as SpotLight3D
	var camera: Camera3D = player.get_node("Head/Camera3D")
	player.global_position = Vector3(7.58, 1.05, 1.45)
	player.velocity = Vector3.ZERO
	await _aim_player_at(card.global_position)
	card.interact(player)
	await _until(func() -> bool: return _logged(&"conversation"), "a scene begun again", 40.0)
	await _wait(5.0)
	_expect(house.in_memory and house.memory_root.visible and not spot.visible, "(the room is warm, the flashlight out)")
	_expect(get_viewport().get_camera_3d() != camera, "(the scene's camera showing)")
	house.force_finish_memory()
	await get_tree().process_frame
	_expect(not house.memory_running and not bool(player.get("view_locked")) and not player.manual_save_blocked, "the developer console's way out lets the player go at once")
	_expect(get_viewport().get_camera_3d() == camera and (house._cinema == null or not is_instance_valid(house._cinema)), "her own camera is the view again")
	_expect(not house.memory_root.visible and not house.in_memory and not CaptionManager.panel.visible, "the room is the night again and the subtitles are gone")
	_expect(card.visible and card.global_transform.is_equal_approx(card_home) and (house.held_card == null or not is_instance_valid(house.held_card)), "the postcard lies where it was on the nightstand, and nothing is left in her hands")
	var movement: PlayerMovementController = player.movement_controller
	_expect(not movement.view_motion_still and movement.scripted_fov == 0.0, "the player's camera motion and lens are their own")
	_expect(not bedroom_door.is_open and _bedroom_angle() < 0.5 and _lever_turn() < 0.05, "the door is shut, its handle up")
	_expect(house.find_children("DissolveStill", "CanvasLayer", true, false).is_empty(), "no still is left over the picture")
	await _wait(0.6)
	_expect(spot.visible and bool(flashlight.get("flashlight_on")), "and the flashlight is back")

	# Cancelled while she is still being walked to the nightstand: nothing is left held or blocked.
	SaveManager.set_state_value(&"puzzles", &"house_bedroom_memory_done", false)
	house._memory_done = false
	card.plays_scene = true
	player.global_position = Vector3(9.4, 1.05, 2.2)
	player.velocity = Vector3.ZERO
	await _aim_player_at(card.global_position)
	card.interact(player)
	await _wait(0.4)
	_expect(house.memory_running and house._approaching and movement.is_guided_walking(), "(she is being walked to the nightstand)")
	house.force_finish_memory()
	await get_tree().process_frame
	_expect(not house.memory_running and not movement.is_guided_walking() and not bool(player.get("view_locked")) and not player.manual_save_blocked, "cut off on the way there, she is her own again, saving allowed")
	SaveManager.set_state_value(&"puzzles", &"house_bedroom_memory_done", false)
	house._memory_done = false
	card.plays_scene = true

	# Cancelled before it was done (the house leaving, say): the postcard plays it from the start next time.
	SaveManager.set_state_value(&"puzzles", &"house_bedroom_memory_done", false)
	house._memory_done = false
	card.plays_scene = true
	card.interact(player)
	await _until(func() -> bool: return _logged(&"dissolve_in"), "a scene begun once more", 20.0)
	house._cancel_memory()
	await get_tree().process_frame
	_expect(not house.memory_running and card.plays_scene and not _flag(&"house_bedroom_memory_done"), "cut off, it is not counted as played: the postcard offers it again")
	_expect(not capsule.story_unlocked, "and the capsule stays locked")
	house.force_finish_memory()
	await get_tree().process_frame


## A second copy of the house built from the saved state: everything is where the story left it.
func _check_reload() -> void:
	var copy: UnfinishedHouseSequence = await _spawn_house()
	_expect((copy.get_node("Doors/PantryDoor") as DoorController).is_locked == false, "after a reload the pantry is open to the player")
	_expect(not copy.is_pantry_lamp_on(), "its bulb stays out (the bedroom scene put the pantry out)")
	_expect(not (copy.get_node("Doors/BedroomDoor") as DoorController).is_locked, "the bedroom is unlocked")
	_expect((copy.get_node("Furniture/TimeCapsule") as TimeCapsule).is_open, "the capsule is open")
	_expect(not copy.memory_root.visible, "the room is the night room")
	var copy_card: Postcard = copy.get_node("Furniture/Postcard")
	_expect(not copy_card.plays_scene, "the postcard is only a postcard after a reload")
	(copy.get_node("Furniture/NightstandDrawer") as DrawerInteractable).interact(player)
	await get_tree().process_frame
	_expect(not copy.memory_running, "the drawer plays nothing after a reload")
	copy.queue_free()
	await get_tree().process_frame

	# A save made after the key was set down but before it was taken: the key lies there.
	SaveManager.set_state_value(&"collectibles", &"capsule_key", false)
	SaveManager.set_state_value(&"puzzles", &"time_capsule_open", false)
	copy = await _spawn_house()
	_expect((copy.get_node("Furniture/TimeCapsule") as TimeCapsule).story_unlocked, "a save from after the scene, before the capsule was opened, finds it unlocked")
	copy.queue_free()
	await get_tree().process_frame
	SaveManager.set_state_value(&"collectibles", &"capsule_key", true)
	SaveManager.set_state_value(&"puzzles", &"time_capsule_open", true)


## Games saved by the old sequence are converted once, and converting again changes nothing.
func _check_legacy_saves() -> void:
	# The old trap under way: the doors locked, the drawer open, the capsule shut.
	_clear_house_state()
	SaveManager.set_state_value(&"puzzles", &"house_stage", 4)
	SaveManager.set_state_value(&"puzzles", &"house_pantry_beat", 2)
	SaveManager.set_state_value(&"doors", &"house_front_door", {"is_locked": true, "is_open": false})
	SaveManager.set_state_value(&"doors", &"house_back_door", {"is_locked": true, "is_open": false})
	SaveManager.set_state_value(&"doors", &"house_pantry_door", {"is_locked": false, "is_open": false})
	SaveManager.set_state_value(&"doors", &"house_bedroom_door", {"is_locked": false, "is_open": true})
	SaveManager.set_state_value(&"drawers", &"house_nightstand_drawer", {"is_open": true})
	var copy: UnfinishedHouseSequence = await _spawn_house()
	_expect(_flag(&"house_migrated"), "an old game is converted")
	_expect(_flag(&"house_recipe_done") and copy.is_pantry_lamp_on(), "the recipe counts as read (the pantry bulb is on)")
	_expect(_flag(&"house_argument_active") and _flag(&"house_pantry_closed_on_entry"), "the pantry's beats count as done")
	_expect(not (copy.get_node("Doors/FrontDoor") as DoorController).is_locked and not (copy.get_node("Doors/BackDoor") as DoorController).is_locked, "the doors the old trap locked are unlocked")
	_expect((copy.get_node("Furniture/Postcard") as Postcard).plays_scene, "the postcard offers the bedroom scene (an open drawer does not matter)")
	_expect(not _flag(&"house_bedroom_memory_done") and not (copy.get_node("Furniture/TimeCapsule") as TimeCapsule).story_unlocked, "the memory is still to come")
	copy.queue_free()
	await get_tree().process_frame
	var snapshot: Dictionary = _house_state()
	copy = await _spawn_house()
	_expect(_house_state() == snapshot, "converting again changes nothing")
	copy.queue_free()
	await get_tree().process_frame

	# The previous version's drawer scene played (its key lying on the nightstand, not taken yet): kept as done, the key
	# within reach, and the postcard does not play it again.
	_clear_house_state()
	SaveManager.set_state_value(&"puzzles", &"house_migrated", true)
	SaveManager.set_state_value(&"puzzles", &"house_recipe_done", true)
	SaveManager.set_state_value(&"puzzles", &"house_bedroom_memory_done", true)
	SaveManager.set_state_value(&"doors", &"house_bedroom_door", {"is_locked": false, "is_open": false})
	SaveManager.set_state_value(&"drawers", &"house_nightstand_drawer", {"is_open": true})
	copy = await _spawn_house()
	_expect((copy.get_node("Furniture/TimeCapsule") as TimeCapsule).story_unlocked, "a game that played the drawer version finds the capsule unlocked")
	_expect(not (copy.get_node("Furniture/Postcard") as Postcard).plays_scene, "and is not made to play the new scene")
	_expect(not (copy.get_node("Doors/BedroomDoor") as DoorController).is_locked, "the bedroom stays open to it")
	copy.queue_free()
	await get_tree().process_frame

	# The old ending reached (the capsule open, the Ficha not taken yet): nothing is left to present.
	_clear_house_state()
	SaveManager.set_state_value(&"puzzles", &"house_stage", 7)
	SaveManager.set_state_value(&"puzzles", &"time_capsule_open", true)
	SaveManager.set_state_value(&"doors", &"house_front_door", {"is_locked": true, "is_open": false})
	copy = await _spawn_house()
	_expect(_flag(&"house_bedroom_memory_done"), "an old game past the ending skips the scene")
	_expect((copy.get_node("Furniture/TimeCapsule") as TimeCapsule).is_open, "the capsule stays open")
	_expect(not (copy.get_node("Doors/FrontDoor") as DoorController).is_locked, "and the exit is open")
	copy.queue_free()
	await get_tree().process_frame

	# A brand-new game: nothing changes but the mark.
	_clear_house_state()
	copy = await _spawn_house()
	_expect(_flag(&"house_migrated") and not _flag(&"house_recipe_done") and (copy.get_node("Doors/PantryDoor") as DoorController).is_locked, "a new game starts at the beginning")
	copy.queue_free()
	await get_tree().process_frame


## The texts the director wrote (English; PT-BR is authoritative and checked by its own catalogue).
func _check_copy() -> void:
	_expect(tr("CAPTION_HOUSE_BED_01") == "Did you write this when you got here?" and tr("CAPTION_HOUSE_BED_05") == "“You don't need to worry about me.”", "the bedroom lines read as written")
	_expect(tr("CAPTION_HOUSE_BED_17") == "No. Leave it where it was." and tr("READABLE_POSTCARD").begins_with("Mom,") and tr("READABLE_POSTCARD").ends_with("Lucas"), "to the last one, and the postcard's message")
	_expect(tr("CAPTION_HOUSE_SHH") == "Shh.", "\"Shh.\"")
	_expect(tr("ITEM_CAPSULE_KEY_NAME") == "Capsule Key", "the capsule key is named")
	_expect(tr("AD_HEADLINE") == "HOUSE FOR SALE" and tr("AD_OURS") == "OURS?", "the advertisement")
	_expect(tr("BUS_TICKET_IF_YOU_WANT") == "If you want.", "the unclaimed ticket")
	_expect(tr("READABLE_DIARY").begins_with("[b]6 a.m.[/b]"), "the notebook's page")
	_expect(tr("READABLE_RECIPE").ends_with("Sophia") and tr("JAR_NOTE_TEXT").ends_with("Sophia") and tr("DIARY_TEXT").ends_with("Lucas"), "signed with full names")
	for key: String in ["READABLE_RECIPE", "READABLE_PANTRY_NOTE", "JAR_NOTE_TEXT", "READABLE_DIARY", "READABLE_NOTE_CAPSULE", "READABLE_HOUSE_AD"]:
		_expect(not tr(key).contains("-"), "%s has no hyphens" % key)
	var catalogue: Translation = load("res://localization/pt_BR.po") as Translation
	_expect(catalogue != null and catalogue.get_message("CAPTION_HOUSE_BED_03") == "Sua mãe já tinha morrido?" and catalogue.get_message("CAPTION_HOUSE_BED_17") == "Não. Deixa onde estava." and catalogue.get_message("CAPTION_HOUSE_SHH") == "Shhh.", "the Portuguese lines are there")
	_expect(catalogue != null and catalogue.get_message("READABLE_POSTCARD") == "Mãe,\n\nCheguei bem. Aqui é tranquilo.\nNão precisa se preocupar comigo.\n\nLucas" and catalogue.get_message("ITEM_POSTCARD_NAME") == "Cartão-postal", "and the postcard, word for word")
	_expect(catalogue != null and catalogue.get_message("BUS_TICKET_PASSENGER_SOPHIA") == "Passageira:", "with Sophia's ticket in the feminine")


# ============================================================
# HELPERS
# ============================================================

func _spawn_house() -> UnfinishedHouseSequence:
	var copy: UnfinishedHouseSequence = (load(HOUSE_SCENE_PATH) as PackedScene).instantiate() as UnfinishedHouseSequence
	# Far from the player, so that nothing in it reacts to them.
	copy.position = Vector3(0.0, -200.0, 0.0)
	add_child(copy)
	await get_tree().process_frame
	await get_tree().process_frame
	return copy


func _clear_house_state() -> void:
	for key: StringName in [&"house_recipe_done", &"house_pantry_closed_on_entry", &"house_argument_active", &"house_bedroom_memory_done", &"house_migrated", &"house_ficha_taken", &"time_capsule_open"]:
		SaveManager.set_state_value(&"puzzles", key, false)
	SaveManager.set_state_value(&"puzzles", &"house_stage", 0)
	SaveManager.set_state_value(&"puzzles", &"house_pantry_beat", 0)
	SaveManager.set_state_value(&"triggers", &"house_recipe_open", false)
	SaveManager.set_state_value(&"collectibles", &"capsule_key", false)
	SaveManager.set_state_value(&"drawers", &"house_nightstand_drawer", {})
	for door: StringName in [&"house_front_door", &"house_back_door", &"house_pantry_door", &"house_bedroom_door"]:
		SaveManager.set_state_value(&"doors", door, {})


func _house_state() -> Dictionary:
	var state: Dictionary = {}
	for key: StringName in [&"house_recipe_done", &"house_pantry_closed_on_entry", &"house_argument_active", &"house_bedroom_memory_done", &"house_migrated"]:
		state[key] = _flag(key)
	for door: StringName in [&"house_front_door", &"house_back_door", &"house_pantry_door", &"house_bedroom_door"]:
		state[door] = SaveManager.get_state_value(&"doors", door, {})
	state["drawer"] = SaveManager.get_state_value(&"drawers", &"house_nightstand_drawer", {})
	return state


func _flag(key: StringName) -> bool:
	return bool(SaveManager.get_state_value(&"puzzles", key, false))


func _logged(beat: StringName) -> bool:
	return _logged_time(beat) >= 0.0


func _logged_time(beat: StringName) -> float:
	for entry: Dictionary in house.memory_log:
		if entry["beat"] == beat:
			return float(entry["time"])

	return -1.0


func _pantry_angle() -> float:
	return absf(pantry_door.hinge.rotation_degrees.y - pantry_door.closed_rotation_degrees.y)


func _bedroom_angle() -> float:
	return absf(bedroom_door.hinge.rotation_degrees.y - bedroom_door.closed_rotation_degrees.y)


## How far the bedroom door's handle is pressed down (0 to 1), on either face.
func _lever_turn() -> float:
	var turn: float = 0.0
	for face: Variant in bedroom_door._hardware:
		var lever: Node3D = (bedroom_door._hardware[face] as DoorHardware)._lever
		if lever != null:
			turn = maxf(turn, absf(lever.rotation.z) / deg_to_rad(DoorHardware.LEVER_TURN_DEGREES))
	return turn


## Lights in the house that are on and red.
func _red_lights() -> Array[Light3D]:
	var red: Array[Light3D] = []
	for node: Node in house.find_children("*", "Light3D", true, false):
		var light: Light3D = node as Light3D
		if light.is_visible_in_tree() and light.light_energy > 0.01 and light.light_color.r > 0.8 and light.light_color.g < 0.4:
			red.append(light)
	return red


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


## Every 3D sound player in the house (the doors' own included).
func _sound_ids() -> Array[int]:
	var ids: Array[int] = []
	for sound: Node in house.find_children("*", "AudioStreamPlayer3D", true, false):
		ids.append(sound.get_instance_id())

	return ids


## Sound players made since `before`, that are still there.
func _new_sounds(before: Array[int]) -> Array:
	return _sound_ids().filter(func(id: int) -> bool: return not before.has(id))


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
		furniture.get_node("KitchenRecipe"), _beside(furniture.get_node("KitchenRecipe"), 0.7),
		furniture.get_node("KitchenRecipe").global_position, "the recipe on the counter"
	)
	await _ray_finds(
		furniture.get_node("NoteCapsule"), _front_of(capsule, 1.05),
		furniture.get_node("NoteCapsule").global_position, "the note on the capsule"
	)
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
