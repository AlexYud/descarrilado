extends Node

## Plays the whole fig tree clearing through the game's own APIs (triggers,
## pickups, the album close-up's drag and drop, inspect, captions) and checks
## each stage. Run it as a scene; it quits by itself with a non-zero exit code
## on failure. Game time runs faster so the 30 s recording does not take 30 s.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_fig_clearing_smoke"
const TEST_SCENE_PATH: String = "res://tests/fig_clearing_test.tscn"
const TIME_SCALE: float = 6.0

var test_failed: bool = false
var back_revealed_ids: Array[String] = []
var wrong_count: int = 0

var clearing: FigClearingSequence = null
var player: CharacterBody3D = null


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
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
	_expect(clearing.stage == FigClearingSequence.Stage.EXPLORING, "starts exploring")
	_expect(clearing.recorder.is_turning(), "the cassette turns in silence from the start")
	_expect(clearing.album.slots.size() == 3, "the album has three slots")
	_expect(clearing.album.get_photo_ids().size() == 6, "but six photographs belong to it (three are red herrings)")
	_expect(clearing.fire.is_lit, "the campfire starts lit")
	var ash: Node3D = clearing.fire.get_node_or_null("ColdAsh") as Node3D
	_expect(ash != null and not ash.visible, "the cold ash is not shown while the fire burns")

	var album: PhotoAlbum = clearing.album
	var flashlight: Node = player.get_node("Hand/SpotLight3D")

	# Six photographs are scattered about the clearing, none on top of another, and each has its
	# note on the back as a readable spot (no words are drawn on the model).
	var photo_names: Array[String] = ["PhotoChildhood", "PhotoAdolescence", "PhotoRecent", "PhotoWorkshop", "PhotoClock", "PhotoTrack"]
	var note_keys: Array[String] = ["PHOTO_NOTE_CHILDHOOD", "PHOTO_NOTE_ADOLESCENCE", "PHOTO_NOTE_RECENT", "PHOTO_NOTE_WORKSHOP", "PHOTO_NOTE_CLOCK", "PHOTO_NOTE_TRACK"]
	var closest: float = INF
	for i: int in photo_names.size():
		var photo: Collectible = clearing.get_node("Props/" + photo_names[i])
		_expect(photo.global_position.distance_to(clearing.global_position) < 8.0, photo_names[i] + " lies in the clearing")
		for j: int in range(i + 1, photo_names.size()):
			closest = minf(closest, photo.global_position.distance_to(clearing.get_node("Props/" + photo_names[j]).global_position))

		var visual: Node3D = photo.get_node("Visual")
		var spot: ReadableSpot = visual.find_child("BackNote", true, false) as ReadableSpot
		_expect(spot != null and spot.text_key == note_keys[i] and spot.obvious, photo_names[i] + " has its note on the back as a readable spot")
		_expect(spot != null and spot.get_facing_normal().dot(visual.global_basis.z) < -0.99, "which faces away from the picture")
		_expect(visual.find_child("BackLabel", true, false) == null, "and no text is drawn on the model's back")

	_expect(closest > 0.4, "no two photographs lie on top of each other (closest %.2f m)" % closest)

	# The notes are translated, in both languages, and are the written ones.
	_expect(tr("PHOTO_NOTE_CHILDHOOD").begins_with("July 1988. She fell on the gravel behind the signal tower."), "the English note of the scraped knee")
	_expect(tr("PHOTO_NOTE_CLOCK") == "First night on duty alone. October 1999.", "the English note of the station clock")
	GameSettings.set_text_locale("pt_BR", false)
	var all_translated: bool = true
	for key: String in note_keys + ["PHOTO_FRONT_CHILDHOOD", "PHOTO_FRONT_TRACK", "ITEM_PHOTO_WORKSHOP_NAME", "FICHA_SCRATCH_JULIANA", "INSPECT_VERB_TURN"]:
		all_translated = all_translated and tr(key) != key
	_expect(all_translated, "every new text is also translated into Portuguese")
	GameSettings.set_text_locale("en", false)

	# Picking up a photograph shows it in the inspect view first. One distractor (the empty track) is
	# left lying: the solved album will take it away.
	for photo_name: String in ["PhotoRecent", "PhotoChildhood", "PhotoAdolescence", "PhotoWorkshop", "PhotoClock"]:
		var photo: Collectible = clearing.get_node("Props/" + photo_name)
		_expect(photo.can_interact(player), photo_name + " can be picked up")
		photo.interact(player)
		_expect(player.inspect_controller.is_open(), photo_name + " opens the inspect view")
		await _wait(0.5)
		player.inspect_controller.close(false)
		player.inventory_ui_controller.close()
		await _wait(0.6)

	for item_id: String in ["photo_childhood", "photo_adolescence", "photo_recent", "photo_workshop", "photo_clock"]:
		_expect(player.has_inventory_item(item_id), item_id + " is in the inventory")

	# Reading the back works as in the waiting shed: [E] turns the photo over and shows its note as an overlay.
	var inspect: PlayerInspectController = player.inspect_controller
	player._on_inventory_inspect_requested(_find_slot_data("photo_childhood"))
	await _wait(0.8)
	_expect(inspect.rotate_hint.visible and inspect.rotate_hint._text_label.text == tr("INSPECT_VERB_ROTATE"), "inspecting the front, there is a [R] Rotate button")
	_expect(not inspect.read_hint.visible and not inspect.readables.has_obvious_reading(), "and nothing to read yet")
	inspect.readables.activate()
	_expect(not inspect.readables.is_reading(), "so the read key does nothing on the front")
	var rotate_before: Vector2 = inspect.rotate_hint.position
	inspect._flip()
	await _until(func() -> bool: return inspect.read_hint.visible, 6.0)
	_expect(inspect.rotate_hint.position.is_equal_approx(rotate_before), "and Rotate has not moved when Read appeared")
	_expect(inspect.read_hint.visible and inspect.read_hint._text_label.text == tr("INSPECT_VERB_READ"), "turned to its back, a [E] Read button appears")
	_expect(not inspect.readables._prompt.visible, "and no prompt over the photograph itself")
	_expect(not inspect.readables.is_reading(), "nothing is shown before the key is pressed")
	inspect.readables.activate()
	await _wait(1.6)
	_expect(inspect.readables.is_reading(), "pressing the key opens the text")
	_expect(inspect.readables._body.text == tr("PHOTO_NOTE_CHILDHOOD"), "it is the note of the scraped knee, translated (%s)" % inspect.readables._body.text.left(40))
	_expect(inspect.readables._title.text == tr("ITEM_PHOTO_CHILDHOOD_NAME"), "under the photograph's name")
	_expect(inspect.readables._veil.visible and inspect.readables._veil.modulate.a > 0.9, "over the dark veil")
	var back_dot: float = inspect.current_visual_copy.get_node("BackNote").global_basis.z.dot(inspect.camera.global_basis.z)
	_expect(back_dot > 0.97, "the photograph has turned over to show its back squarely (%.2f)" % back_dot)
	inspect.readables.close_text()
	await _wait(0.6)
	inspect.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)

	# Turning a photograph over in the inventory reveals its back once.
	player.inspect_controller.back_revealed.connect(
		func(id: String) -> void: back_revealed_ids.append(id)
	)
	player._on_inventory_inspect_requested(_find_slot_data("photo_recent"))
	await _wait(0.6)
	player.inspect_controller._flip()
	await _wait(1.6)
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

	# Any photo can go in any space; the album is judged only when every space is full.
	var view: AlbumView = album.view
	album.wrong_arrangement.connect(func() -> void: wrong_count += 1)
	_expect(view.drop_on_slot(0, _from_hand("photo_workshop")), "a distractor can be placed")
	_expect(view.drop_on_slot(1, _from_hand("photo_clock")), "and another")
	_expect(wrong_count == 0, "no reaction while a space is still empty")
	_expect(view.drop_on_slot(2, _from_hand("photo_recent")), "the last space is filled")
	_expect(
		album.arrangement == ["photo_workshop", "photo_clock", "photo_recent"],
		"the wrong photographs are kept as placed"
	)
	_expect(wrong_count == 1, "a full but wrong album plays the static glitch (%d)" % wrong_count)
	_expect(not album.locked, "a wrong arrangement does not lock the album")
	_expect(clearing.stage == FigClearingSequence.Stage.EXPLORING, "a wrong arrangement triggers nothing else")

	# A photo can be taken back and put down again.
	_expect(
		view.drop_on_tray({"item_id": "photo_recent", "from_slot": 2}),
		"a photo can be taken back"
	)
	_expect(player.has_inventory_item("photo_recent"), "the photo is back in the hands")
	_expect(album.arrangement[2] == "", "its slot is empty again")
	_expect(wrong_count == 1, "taking one out is not judged")
	_expect(view.drop_on_slot(2, _from_hand("photo_recent")), "and it goes back")
	_expect(wrong_count == 2, "the same full arrangement made again is judged again (%d)" % wrong_count)

	# Right photographs, wrong order, is still wrong.
	_expect(view.drop_on_slot(0, _from_hand("photo_childhood")), "a story photograph replaces a distractor")
	_expect(player.has_inventory_item("photo_workshop"), "the replaced one is back in the hands")
	_expect(wrong_count == 3, "[childhood, clock, recent] is judged wrong (%d)" % wrong_count)
	_expect(not album.locked, "still not locked")
	var before_last: int = wrong_count

	# The last distractor out, the right photograph in: the chronological order.
	_expect(view.drop_on_slot(1, _from_hand("photo_adolescence")), "the last space gets its photograph")
	_expect(album.arrangement == ["photo_childhood", "photo_adolescence", "photo_recent"], "in chronological order")
	_expect(wrong_count == before_last, "the right order is not a wrong arrangement")
	_expect(album.locked, "the right order locks the album")
	_expect(clearing.stage >= FigClearingSequence.Stage.FINALE, "the finale starts")
	_expect(
		not view.can_drop_on_slot(0, _from_hand("photo_childhood")),
		"a locked album refuses changes"
	)

	# The album took the stray photographs: out of the hands and out of the clearing.
	await get_tree().process_frame
	_expect(not player.has_inventory_item("photo_workshop") and not player.has_inventory_item("photo_clock"), "the strays are no longer in the inventory")
	_expect(clearing.get_node_or_null("Props/PhotoTrack") == null, "the stray still lying about is gone too")

	await _until(func() -> bool: return not view.is_open())
	_expect(not player.modal_ui_open, "the player is released when the album closes")

	await _until(func() -> bool: return clearing.stage == FigClearingSequence.Stage.RECORDING)
	_expect(not player.can_manual_save(), "saving is blocked during the sequence")

	await _until(
		func() -> bool: return clearing.stage == FigClearingSequence.Stage.DONE,
		40.0
	)
	_expect(
		bool(SaveManager.get_state_value(&"puzzles", &"fig_clearing_recording_done", false)),
		"the recording is remembered as heard"
	)

	# The moment the tape ends everything cuts at once, into total darkness.
	_expect(not clearing.fire.is_lit, "the campfire goes out when the recording ends")
	_expect(not clearing.fire.flames.visible, "no flame lingers")
	_expect(not clearing.fire.light.visible, "the fire's light is off at once")
	_expect(ash != null and ash.visible, "the fire pit is left with cold ash")
	_expect(not bool(flashlight.get("flashlight_on")), "the flashlight goes out with it")
	_expect(clearing.rain_player != null and not clearing.rain_player.playing, "the rain stops")
	_expect(clearing.ficha_delay_seconds == 2.0, "the dark lasts two seconds before anything happens")
	_expect(player.can_manual_save(), "saving is allowed again")

	# Two seconds of dark: no Ficha, no light. Then the clink, the Ficha, and the flashlight returns.
	await _wait(1.0)
	_expect(clearing._ficha == null, "in the dark nothing has appeared yet")
	_expect(not bool(flashlight.get("flashlight_on")), "and the flashlight is still out")
	await _until(func() -> bool: return clearing._ficha != null, 6.0)
	var clink_heard: bool = false
	for child: Node in clearing.ficha_spot.get_children():
		if child is AudioStreamPlayer3D:
			clink_heard = true
	_expect(clink_heard, "a clink sounds on the table as the Ficha is set down")
	_expect(not bool(flashlight.get("flashlight_on")), "the flashlight is still out at that instant")
	await _wait(0.9)
	_expect(bool(flashlight.get("flashlight_on")), "then the flashlight comes back on by itself")
	_expect(clearing.stage == FigClearingSequence.Stage.DONE, "and the scene stays over")

	# The album can no longer give up a photograph; Juliana's Ficha lies on the table beside it.
	_expect(album.can_interact(player), "the album can be used after the memory")
	_expect(album.get_prompt_text() == "PROMPT_OPEN_ALBUM", "it only opens to look: no photograph can be taken from it")
	var ficha: Collectible = clearing._ficha as Collectible
	_expect(ficha != null and ficha.item_id == "juliana_ficha", "Juliana's Ficha lies beside the album")
	_expect(
		ficha != null and ficha.global_position.distance_to(clearing.ficha_spot.global_position) < 0.05,
		"on the table, where the spot is"
	)
	var scratch: ReadableSpot = ficha.get_node("Visual").find_child("ScratchSpot", true, false) as ReadableSpot
	_expect(scratch != null and not scratch.obvious and tr(scratch.text_key) == "CALL HER", "its back is scratched with CALL HER, read as an overlay")
	_expect(ficha != null and ficha.get_prompt_text() == "PROMPT_PICK_UP", "and it can be picked up")
	ficha.interact(player)
	_expect(player.has_inventory_item("juliana_ficha"), "the Ficha goes in the inventory")
	_expect(album.arrangement[2] == "photo_recent", "the photograph stays in the album")
	_expect(not player.has_inventory_item("photo_recent"), "so the Ficha is the only thing taken")
	_expect(
		bool(SaveManager.get_state_value(&"collectibles", &"juliana_ficha", false)),
		"taking it is remembered"
	)
	await _wait(1.0)

	# Reading the scratch on the Ficha works the same way as the notes on the photographs.
	_expect(inspect.is_open(), "the Ficha opens in the inspect view when taken")
	await _wait(0.8)
	_expect(not inspect.read_hint.visible and inspect.rotate_hint.visible, "the Ficha offers only Rotate: the scratch is a hidden detail")
	_expect(inspect.readables.get_offered_spot() == null, "and nothing is offered while its front faces you")
	inspect._flip()
	await _until(func() -> bool: return inspect.readables.get_offered_spot() != null, 6.0)
	_expect(inspect.readables.get_offered_spot() != null and inspect.readables.get_offered_spot().spot_id == &"ficha_scratch", "turning it over finds the scratch")
	_expect(inspect.readables._prompt.visible, "and only then a prompt appears")
	inspect.readables.activate()
	await _wait(1.2)
	_expect(inspect.readables._body.text == "CALL HER", "and reads CALL HER (%s)" % inspect.readables._body.text)
	inspect.readables.close_text()
	await _wait(0.6)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(1.0)
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
