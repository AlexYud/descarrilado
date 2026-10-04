extends Node

## Plays the whole fig tree clearing through the game's own APIs (triggers,
## pickups, the album close-up's drag and drop, inspect, captions) and checks
## each stage. Run it as a scene; it quits by itself with a non-zero exit code
## on failure. Game time runs faster so the 30 s recording does not take 30 s.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_fig_clearing_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/fig_clearing_test.tscn"
const TIME_SCALE: float = 6.0

var test_failed: bool = false
var back_revealed_ids: Array[String] = []

var clearing: FigClearingSequence = null
var player: CharacterBody3D = null


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(
		1, TEST_SCENE_PATH, "fig_test_start", "SAVE_LOCATION_DREAM_INTRO"
	)
	GameSettings.set_captions_enabled(true, false)

	var level: Node = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame

	clearing = level.get_node("FigClearing")
	player = level.get_node("Player")
	Engine.time_scale = TIME_SCALE

	await _run()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("FIG_CLEARING_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	_expect(player.is_in_group(&"player"), "the player joins the player group")
	_expect(clearing.stage == FigClearingSequence.Stage.DORMANT, "starts dormant")
	_expect(clearing.album.slots.size() == 3, "the album has three slots")
	_expect(clearing.fire.is_lit, "the campfire starts lit")

	var recorder: CassetteRecorder = clearing.recorder
	var album: PhotoAlbum = clearing.album
	var flashlight: Node = player.get_node("Hand/SpotLight3D")

	# Walking into the clearing starts the melody; reaching the table stops it.
	player.global_position = Vector3(-6.0, 1.1, 2.0)
	await _until(func() -> bool: return clearing.stage == FigClearingSequence.Stage.CALLING)
	_expect(recorder.voice_player.playing, "the melody plays while calling")

	player.global_position = Vector3(0.0, 1.1, 2.4)
	await _until(func() -> bool: return clearing.stage == FigClearingSequence.Stage.EXPLORING)
	await _wait(1.5)
	_expect(not recorder.voice_player.playing, "the melody stops near the table")
	_expect(recorder.is_turning(), "the cassette keeps turning in silence")

	# Picking up a photograph shows it in the inspect view first.
	for photo_name: String in ["PhotoRecent", "PhotoChildhood", "PhotoAdolescence"]:
		var photo: Collectible = clearing.get_node("Props/" + photo_name)
		_expect(photo.can_interact(player), photo_name + " can be picked up")
		photo.interact(player)
		_expect(player.inspect_controller.is_open(), photo_name + " opens the inspect view")
		await _wait(0.5)
		player.inspect_controller.close(false)
		player.inventory_ui_controller.close()
		await _wait(0.6)

	for item_id: String in ["photo_childhood", "photo_adolescence", "photo_recent"]:
		_expect(player.has_inventory_item(item_id), item_id + " is in the inventory")

	# Turning a photograph over in the inventory reveals its back once.
	player.inspect_controller.back_revealed.connect(
		func(id: String) -> void: back_revealed_ids.append(id)
	)
	player._on_inventory_inspect_requested(_find_slot_data("photo_recent"))
	await _wait(0.6)
	player.inspect_controller.current_visual_copy.rotate_y(PI)
	await _wait(1.0)
	_expect(back_revealed_ids.has("photo_recent"), "turning the photo over reveals its back")
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)

	# The flashlight is on while the memory plays, so it must go out with the fire.
	flashlight.call("restore_save_state", {"is_on": true})

	# Opening the album freezes the player and gives Juliana's first line.
	_expect(album.can_interact(player), "the album can be opened")
	album.interact(player)
	_expect(album.view.is_open(), "the album close-up opens")
	_expect(player.modal_ui_open, "the player is held while the album is open")
	_expect(not player.can_manual_save(), "saving is blocked while the album is open")

	# Any photo can go in any space, and nothing says whether it is right.
	var view: AlbumView = album.view
	_expect(view.drop_on_slot(0, _from_hand("photo_recent")), "a photo can go in any slot")
	_expect(view.drop_on_slot(1, _from_hand("photo_childhood")), "a second photo goes in")
	_expect(view.drop_on_slot(2, _from_hand("photo_adolescence")), "a third photo goes in")
	_expect(not player.has_inventory_item("photo_recent"), "a placed photo leaves the hands")
	_expect(
		album.arrangement == ["photo_recent", "photo_childhood", "photo_adolescence"],
		"the wrong order is kept as placed"
	)
	_expect(not album.locked, "a wrong order does not lock the album")
	_expect(clearing.stage == FigClearingSequence.Stage.EXPLORING, "a wrong order triggers nothing")

	# A photo can be taken back and put down again.
	_expect(
		view.drop_on_tray({"item_id": "photo_recent", "from_slot": 0}),
		"a photo can be taken back"
	)
	_expect(player.has_inventory_item("photo_recent"), "the photo is back in the hands")
	_expect(album.arrangement[0] == "", "its slot is empty again")

	# Dropping on an occupied slot returns the old photo to the hands.
	_expect(view.drop_on_slot(1, _from_hand("photo_recent")), "a photo can replace another")
	_expect(player.has_inventory_item("photo_childhood"), "the replaced photo is back in the hands")
	_expect(view.drop_on_slot(0, _from_hand("photo_childhood")), "it goes into the first slot")

	# Rearranging inside the album: [childhood, recent, adolescence] -> correct.
	_expect(
		album.arrangement == ["photo_childhood", "photo_recent", "photo_adolescence"],
		"the order is one swap away"
	)
	_expect(not album.locked, "still not locked")
	_expect(
		view.drop_on_slot(2, {"item_id": "photo_recent", "from_slot": 1}),
		"photos can swap places"
	)

	_expect(album.locked, "the right order locks the album")
	_expect(clearing.stage >= FigClearingSequence.Stage.FINALE, "the finale starts")
	_expect(
		not view.can_drop_on_slot(0, _from_hand("photo_childhood")),
		"a locked album refuses changes"
	)

	await _until(func() -> bool: return not view.is_open())
	_expect(not player.modal_ui_open, "the player is released when the album closes")

	await _until(func() -> bool: return clearing.stage == FigClearingSequence.Stage.RECORDING)
	_expect(
		clearing.passage_blocker.collision_layer == 1,
		"the passage is blocked during the memory"
	)
	_expect(not player.can_manual_save(), "saving is blocked during the sequence")

	await _until(
		func() -> bool: return clearing.stage == FigClearingSequence.Stage.DONE,
		40.0
	)
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"fig_clearing_recording_done", false)),
		"the recording is remembered as heard"
	)

	# The scene is over the moment the tape ends: everything cuts at once and
	# nothing else happens.
	_expect(not clearing.fire.is_lit, "the campfire goes out when the recording ends")
	_expect(not clearing.fire.flames.visible, "no flame lingers")
	_expect(not clearing.fire.light.visible, "the fire's light is off at once")
	_expect(not bool(flashlight.get("flashlight_on")), "the flashlight goes out with it")
	await _wait(2.0)
	_expect(clearing.stage == FigClearingSequence.Stage.DONE, "the scene stays over")
	_expect(not bool(flashlight.get("flashlight_on")), "the flashlight stays off")
	_expect(player.can_manual_save(), "saving is allowed again")
	await _until(func() -> bool: return clearing.passage_blocker.collision_layer == 0)

	# The album now offers the last photograph, which asks "will you come?".
	_expect(album.can_interact(player), "the album can be used after the memory")
	_expect(album.get_prompt_text() == "PROMPT_TAKE_PHOTO", "it offers to take the photograph")
	album.interact(player)
	_expect(player.has_inventory_item("photo_recent"), "the keepsake photograph is taken")
	_expect(album.arrangement[2] == "", "it leaves the album")
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"fig_clearing_photo_taken", false)),
		"taking it is remembered"
	)
	_expect(album.get_prompt_text() == "PROMPT_OPEN_ALBUM", "the album then only opens to look")
	album.interact(player)
	_expect(view.is_open(), "the finished album can still be looked at")
	view.close()


func _from_hand(item_id: String) -> Dictionary:
	return {"item_id": item_id, "from_slot": -1}


func _find_slot_data(item_id: String) -> Dictionary:
	for slot_data: Dictionary in player.inventory_controller.get_slots():
		if str(slot_data.get("id", "")) == item_id:
			return slot_data

	return {}


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(condition: Callable, timeout_seconds: float = 10.0) -> void:
	var waited: float = 0.0
	while not condition.call() and waited < timeout_seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()

	_expect(condition.call(), "waiting for a stage to be reached")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
