extends Node

## Plays the whole fig tree clearing, and the ruined signal tower that is its other half, through the
## game's own APIs (triggers, pickups, the locked door and its key, the tower's photographs, the album close-up's drag
## and drop, inspect, captions) and checks each stage. Run it as a scene; it quits by itself with a non-zero exit code
## on failure. Game time runs faster so the 30 s recording does not take 30 s.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_fig_clearing_smoke"
const TEST_SCENE_PATH: String = "res://tests/fig_clearing_test.tscn"
const TIME_SCALE: float = 6.0

var test_failed: bool = false
var back_revealed_ids: Array[String] = []
var wrong_count: int = 0

var clearing: FigClearingSequence = null
var tower: SignalTowerBuilder = null
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
	tower = level.get_node("SignalTower")
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
	var crackle: AudioStreamPlayer3D = clearing.fire.crackle
	var recording: AudioStreamWAV = crackle.stream as AudioStreamWAV
	_expect(recording != null and recording.resource_path.ends_with("campfire_placeholder.wav"), "the fire crackles with the recording campfire_placeholder.wav")
	_expect(recording != null and recording.loop_mode == AudioStreamWAV.LOOP_FORWARD and recording.get_length() > 5.0, "which loops (%.0f s long)" % (recording.get_length() if recording != null else 0.0))
	_expect(crackle.playing, "and plays while the fire burns")

	var album: PhotoAlbum = clearing.album
	var flashlight: Node = player.get_node("Hand/SpotLight3D")

	# Half of the six photographs lie about the camp, none on top of another, and each has its note on the
	# back as a readable spot (no words are drawn on the model). The other half are in the tower.
	var photo_names: Array[String] = ["PhotoRecent", "PhotoWorkshop"]
	var note_keys: Array[String] = ["PHOTO_NOTE_RECENT", "PHOTO_NOTE_WORKSHOP"]
	var closest: float = INF
	for i: int in photo_names.size():
		var photo: Collectible = clearing.get_node("Props/" + photo_names[i])
		_expect(photo.global_position.distance_to(clearing.global_position) < 8.0, photo_names[i] + " lies in the clearing")
		for j: int in range(i + 1, photo_names.size()):
			closest = minf(closest, photo.global_position.distance_to(clearing.get_node("Props/" + photo_names[j]).global_position))

		_check_photo_back(photo, note_keys[i])

	_expect(closest > 0.4, "no two photographs lie on top of each other (closest %.2f m)" % closest)
	for gone: String in ["PhotoChildhood", "PhotoBrokenLever", "PhotoFoggyPlatform", "PhotoAdolescence"]:
		_expect(clearing.get_node_or_null("Props/" + gone) == null, gone + " is no longer in the camp: it is in the tower")

	# The notes are translated, in both languages, and are the written ones: no hyphens in any of them.
	var all_note_keys: Array[String] = ["PHOTO_NOTE_CHILDHOOD", "PHOTO_NOTE_ADOLESCENCE", "PHOTO_NOTE_RECENT", "PHOTO_NOTE_WORKSHOP", "PHOTO_NOTE_BROKEN_LEVER", "PHOTO_NOTE_FOGGY_PLATFORM"]
	_expect(tr("PHOTO_NOTE_CHILDHOOD") == "July 1988. She fell on the gravel behind the signal tower. She swore something under the floorboards grabbed her ankle. I told her it was just a loose wire. I lied. I saw it too.", "the English note of the scraped knee")
	_expect(tr("PHOTO_NOTE_BROKEN_LEVER") == "1994. Lucas tried to fix the tracks himself after the station closed. He always thought he owned this place.", "the English note of the broken lever")
	_expect(tr("PHOTO_NOTE_FOGGY_PLATFORM") == "I don't remember taking this. The date stamp says 1988, but I was never at the tracks alone at night back then.", "the English note of the foggy platform")
	_expect(tr("ITEM_PHOTO_BROKEN_LEVER_NAME").ends_with("The Broken Lever") and tr("ITEM_PHOTO_FOGGY_PLATFORM_NAME").ends_with("The Foggy Platform"), "the two renamed photographs carry their new names")
	var no_hyphens: bool = true
	for key: String in all_note_keys:
		no_hyphens = no_hyphens and not tr(key).contains("-")
	GameSettings.set_text_locale("pt_BR", false)
	var all_translated: bool = true
	for key: String in all_note_keys + ["PHOTO_FRONT_CHILDHOOD", "PHOTO_FRONT_FOGGY_PLATFORM", "PHOTO_FRONT_BROKEN_LEVER", "ITEM_PHOTO_WORKSHOP_NAME", "ITEM_PHOTO_BROKEN_LEVER_NAME", "ITEM_PHOTO_FOGGY_PLATFORM_NAME", "FICHA_SCRATCH_JULIANA", "INSPECT_VERB_TURN"]:
		all_translated = all_translated and tr(key) != key
		if key.begins_with("PHOTO_NOTE"):
			no_hyphens = no_hyphens and not tr(key).contains("-")
	_expect(all_translated, "every photograph text is also translated into Portuguese")
	_expect(no_hyphens, "and none of the six photograph notes has a hyphen, in either language")
	GameSettings.set_text_locale("en", false)

	# The two halves of the puzzle: the clothesline, the thermos and the lantern in the camp, the note on the tower's door.
	await _check_two_part_puzzle()

	# Picking up a photograph shows it in the inspect view first. The camp's two lie on the ground (the third, Rain at the Station, is in the lantern's drawer); the
	# tower's lie about its relay room, and are taken after the key (see below). One red herring (the foggy
	# platform, in the tin on the back shelf) is left there: the solved album will take it away.
	for photo_name: String in ["PhotoRecent", "PhotoWorkshop"]:
		var photo: Collectible = clearing.get_node("Props/" + photo_name)
		_expect(photo.can_interact(player), photo_name + " can be picked up")
		photo.interact(player)
		_expect(player.inspect_controller.is_open(), photo_name + " opens the inspect view")
		await _wait(0.5)
		player.inspect_controller.close(false)
		player.inventory_ui_controller.close()
		await _wait(0.6)

	await _take_from_tower()
	for item_id: String in ["photo_childhood", "photo_adolescence", "photo_recent", "photo_workshop", "photo_broken_lever"]:
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
	_expect(view.drop_on_slot(1, _from_hand("photo_broken_lever")), "and another")
	_expect(wrong_count == 0, "no reaction while a space is still empty")
	_expect(view.drop_on_slot(2, _from_hand("photo_recent")), "the last space is filled")
	_expect(
		album.arrangement == ["photo_workshop", "photo_broken_lever", "photo_recent"],
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
	_expect(not player.has_inventory_item("photo_workshop") and not player.has_inventory_item("photo_broken_lever"), "the strays are no longer in the inventory")
	var foggy: Variant = tower.props.photos["photo_foggy_platform"]
	_expect(not is_instance_valid(foggy) or (foggy as Node).is_queued_for_deletion(), "the stray still standing in the tower's tin is gone too")
	_expect(bool(SaveManager.get_state_value(&"collectibles", &"photo_foggy_platform", false)), "and is remembered as taken, for when the tower is loaded again")

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


## A photograph's note is on its back as a readable spot facing away from the picture, and no text is drawn there.
func _check_photo_back(photo: Collectible, note_key: String) -> void:
	var visual: Node3D = photo.get_node("Visual")
	var spot: ReadableSpot = visual.find_child("BackNote", true, false) as ReadableSpot
	_expect(spot != null and spot.text_key == note_key and spot.obvious, photo.name + " has its note on the back as a readable spot")
	_expect(spot != null and spot.get_facing_normal().dot(visual.global_basis.z) < -0.99, "which faces away from the picture")
	_expect(visual.find_child("BackLabel", true, false) == null, "and no text is drawn on the model's back")


## The tower's key is in the camp, and it takes some doing to get it: Juliana's note on the clothesline says it was
## tucked away near the campsite, Sophia's note on the thermos says it is in the lantern's signal box and that the
## filter turns to red, and turning the lantern's filter twice (yellow, neutral, red) springs the drawer in its base,
## which holds the key and the photograph "Rain at the Station". A note pinned to the tower's door says the key is at
## the camp. The tower's door is locked until the key is used.
func _check_two_part_puzzle() -> void:
	var dressing: FigClearingProps = clearing.get_node("CampDressing") as FigClearingProps
	_expect(dressing != null, "the camp has its dressing")
	for gone: String in ["BrassSignalKey", "CampNote", "PhotoAdolescence"]:
		_expect(clearing.get_node_or_null("Props/" + gone) == null, gone + " no longer lies on the ground or the camp table")

	# The clothesline: a rope between two trees near the western trail entrance, out of the player's head's way.
	_expect(dressing.trees.size() == 2, "a clothesline hangs between two trees")
	var lowest: float = INF
	for point: Vector3 in dressing.rope_points:
		lowest = minf(lowest, point.y)
	_expect(lowest > 1.75, "the rope hangs above head height (%.2f m at its lowest)" % lowest)
	for tree: Node3D in dressing.trees:
		_expect(tree.global_position.x < -4.0 and Vector2(tree.global_position.x, tree.global_position.z).length() < 7.5, "tree %s stands by the trail entrance, inside the clearing" % tree.name)

	_expect(dressing.jacket != null and dressing.jacket.global_position.y < lowest + 0.1 and dressing.jacket.global_position.y > 1.7, "a damp jacket hangs from the rope")
	var note: Inspectable = dressing.note
	_expect(note != null, "Juliana's note hangs on the clothesline")
	_expect(note.global_position.y > 1.6 and note.global_position.y < dressing.rope_points[0].y, "pinned to the rope with a wooden peg (%.2f m up)" % note.global_position.y)
	_expect(note.find_child("PegFront", true, false) != null and note.find_child("PegBack", true, false) != null, "the peg is wood")
	_expect(str(note.get_visual_node().get_meta("readable_text")) == "READABLE_CAMP_NOTE" and str(note.get_visual_node().get_meta("inspect_mode")) == "read", "reading it shows READABLE_CAMP_NOTE")
	_expect(tr("READABLE_CAMP_NOTE") == "Sophia left her jacket out in the rain again. I told her the damp air off the ridge never dries out. I took the key to our signal tower HQ and tucked it away near the campsite so Lucas wouldn't find it if he comes poking around the clearing tonight. — Juliana", "Juliana's note says the key is near the campsite (%s)" % tr("READABLE_CAMP_NOTE").left(30))
	_expect(not tr("READABLE_CAMP_NOTE").contains("-"), "and has no hyphen")

	# The log table next to the campfire, with a bench and the thermos and the lantern on it.
	var table: Node3D = dressing.log_table
	var fire_spot: Vector3 = clearing.get_node("Scenery/Campfire").global_position
	_expect(table != null and Vector2(table.global_position.x - fire_spot.x, table.global_position.z - fire_spot.z).length() < 3.0, "a log table stands next to the campfire")
	_expect(dressing.log_bench != null and dressing.log_bench.global_position.distance_to(table.global_position) < 1.2, "with a log bench beside it")
	_expect(table.find_child("Solid", false, false) != null and dressing.log_bench.find_child("Solid", false, false) != null, "both are solid")
	var thermos: Inspectable = dressing.thermos
	var lantern: SignalLantern = dressing.lantern as SignalLantern
	_expect(thermos != null and lantern != null and thermos.get_parent() == table and lantern.get_parent() == table, "the thermos and the lantern stand on the table")
	_expect(absf(lantern.global_position.y - table.global_position.y - FigClearingProps.TABLE_TOP_Y) < 0.01, "the lantern rests on the planks")
	_expect(thermos.global_position.distance_to(lantern.global_position) < 1.0, "side by side")
	var thermos_spot: ReadableSpot = thermos.get_visual_node().find_child("NoteSpot", true, false) as ReadableSpot
	_expect(thermos_spot != null and thermos_spot.text_key == "READABLE_THERMOS" and thermos_spot.obvious, "the thermos has its note as a readable spot, offered from the start")
	_expect(thermos.get_visual_node().find_child("Pin", true, false) != null, "pinned round its middle")
	_expect(tr("READABLE_THERMOS") == "Hot coffee for the best night watch on the tracks. The key to the tower is kept in the lantern's signal box. If the latch won't open in the dark, turn the filter to the red light, which is the railway's emergency signal. Don't drink it all at once. — Sophia", "the thermos note in English (%s)" % tr("READABLE_THERMOS").left(30))
	for piece: Node3D in [note, thermos, lantern]:
		_expect(piece.find_children("*", "PhysicsBody3D", true, false).is_empty() and piece.find_children("*", "CSGShape3D", true, false).is_empty(), piece.name + " is nothing solid: it cannot block the player or a ray")
	GameSettings.set_text_locale("pt_BR", false)
	_expect(tr("READABLE_THERMOS") == "Café quente para a melhor vigia noturna dos trilhos. A chave da torre tá guardada na caixa de sinal do lampião. Se o trinco não abrir no escuro, gira o filtro pra luz vermelha, que é o sinal de emergência da ferrovia. Não bebe tudo de uma vez. — Sophia", "the thermos note is Sophia's Portuguese, word for word")
	_expect(tr("READABLE_CAMP_NOTE").begins_with("A Sophia deixou a jaqueta") and tr("READABLE_CAMP_NOTE").ends_with("— Juliana") and not tr("READABLE_CAMP_NOTE").contains("-"), "the clothesline note is translated, with no hyphen")
	_expect(tr("PROMPT_ROTATE_FILTER") == "Girar Filtro" and tr("ITEM_THERMOS_NAME") != "ITEM_THERMOS_NAME" and tr("ITEM_CAMP_NOTE_NAME") != "ITEM_CAMP_NOTE_NAME", "and the prompts and names too")
	GameSettings.set_text_locale("en", false)
	_expect(tr("PROMPT_ROTATE_FILTER") == "Rotate Filter", "[E] Rotate Filter")

	# An interaction ray, run from where the player would stand, reaches each one: nothing solid hides them.
	var front: Vector3 = lantern.global_basis.z.normalized()
	var eye: Vector3 = lantern.global_position + front * 0.9
	eye.y = 1.5
	await _ray_finds(note, note.global_position + note.global_basis.z * 1.2 + Vector3(0.0, 1.7 - note.global_position.y, 0.0), note.global_position, "Juliana's note on the clothesline")
	var thermos_eye: Vector3 = thermos.global_position + table.global_basis.z.normalized() * 0.9
	thermos_eye.y = 1.5
	await _ray_finds(thermos, thermos_eye, thermos.global_position, "the thermos")
	await _ray_finds(lantern, eye, lantern.global_position + Vector3(0.0, 0.17, 0.0), "the lantern's lens")
	await _ray_finds(clearing.album, Vector3(1.25, 1.4, -0.2), clearing.album.to_global(Vector3(-0.2, 0.012, 0.1)), "the album on the old camp table")

	# Looking at the thermos opens the inspect view, which offers its note to read straight away; the clothesline note
	# opens as an overlay.
	thermos.interact(player)
	await _wait(0.8)
	var inspect_view: PlayerInspectController = player.inspect_controller
	_expect(inspect_view.is_open() and inspect_view.readables.has_obvious_reading(), "the thermos opens in the inspect view with its note offered to read")
	inspect_view.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)

	# The lantern: yellow to start, the drawer shut, the contents out of the scene.
	var drawer: Node3D = lantern.get_node("Model/Drawer")
	_expect(lantern.filter == SignalLantern.Filter.YELLOW and not lantern.is_open, "the lantern shows its yellow filter")
	_expect(lantern.can_interact(player) and lantern.get_prompt_text() == "PROMPT_ROTATE_FILTER", "its lens offers 'Rotate Filter'")
	_expect(lantern.find_child("Key", true, false) == null and lantern.find_child("Photo", true, false) == null, "the key and the photograph are inside, out of reach")
	_expect(drawer.position.z == 0.0, "the drawer is shut")
	var drum: Node3D = lantern.get_node("Model/Drum")
	_expect(drum.find_children("Pane*", "Node3D", false, false).size() == 3, "the filter drum has three panes of glass (yellow, neutral, red)")

	lantern.interact(player)
	_expect(not lantern.can_interact(player), "while the drum turns it is not used again")
	await _until(func() -> bool: return lantern.can_interact(player))
	_expect(lantern.filter == SignalLantern.Filter.NEUTRAL and not lantern.is_open, "one turn gives the neutral filter, and the drawer stays shut")
	_expect(absf(wrapf(drum.rotation.y + TAU / 3.0, -PI, PI)) < 0.05, "the drum turned a third (%.1f degrees)" % rad_to_deg(drum.rotation.y))
	_expect(lantern.find_child("Key", true, false) == null, "still nothing to take")

	lantern.interact(player)
	await _until(func() -> bool: return lantern.is_open and lantern.find_child("Key", true, false) != null and drawer.position.z > FigClearingProps.DRAWER_SLIDE - 0.005)
	_expect(lantern.filter == SignalLantern.Filter.RED, "the second turn gives the red filter (the emergency signal)")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"signal_lantern_open", false)), "the lantern's opening is remembered")
	_expect(not lantern.can_interact(player), "the open lantern no longer answers its lens")
	await get_tree().process_frame
	var lens_disabled: bool = true
	for shape: Node in lantern.get_node("InteractArea").get_children():
		lens_disabled = lens_disabled and (shape as CollisionShape3D).disabled
	_expect(lens_disabled, "and its lens no longer catches the interaction ray over the open drawer")

	var key: Collectible = lantern.find_child("Key", true, false) as Collectible
	var photo: Collectible = lantern.find_child("Photo", true, false) as Collectible
	_expect(key != null and key.item_id == "brass_signal_key" and key.can_interact(player), "the brass signal key lies on the drawer's tray")
	_expect(photo != null and photo.item_id == "photo_adolescence" and photo.can_interact(player), "and the photograph 'Rain at the Station' beside it")
	_check_photo_back(photo, "PHOTO_NOTE_ADOLESCENCE")
	_expect(key.global_position.distance_to(drawer.global_position) < 0.2 and key.global_position.y > drawer.global_position.y + 0.012, "both lie on the tray, out in the open")
	_expect(key.global_basis.z.dot(Vector3.UP) > 0.95 and photo.global_basis.z.dot(Vector3.UP) > 0.95, "lying flat")
	await _ray_finds(key, eye, key.global_position, "the key in the open drawer")
	await _ray_finds(photo, eye, photo.global_position, "the photograph in the open drawer")

	_expect(tower.lower_door.is_locked and tower.lower_door.required_key_id == "brass_signal_key", "the tower's door starts locked, and the brass signal key is what opens it")
	var door_note: Inspectable = tower.lower_door.get_node("Hinge/DoorRoot/DoorNote") as Inspectable
	_expect(door_note != null, "a note is pinned to the tower's door")
	_expect(str(door_note.get_visual_node().get_meta("readable_text")) == "READABLE_TOWER_DOOR_NOTE", "its words are READABLE_TOWER_DOOR_NOTE")
	_expect(tr("READABLE_TOWER_DOOR_NOTE") == "We can't let anyone find this place, Sophia, or we lose our HQ forever. I'm keeping the key with me at the fig tree camp until the rain stops. — Juliana", "the door note says the key is kept at the fig tree camp (%s)" % tr("READABLE_TOWER_DOOR_NOTE").left(30))
	GameSettings.set_text_locale("pt_BR", false)
	_expect(tr("READABLE_TOWER_DOOR_NOTE") != "READABLE_TOWER_DOOR_NOTE" and tr("CAPTION_TOWER_DOOR_LOCKED") != "CAPTION_TOWER_DOOR_LOCKED", "the door note and the locked line are translated into Portuguese")
	GameSettings.set_text_locale("en", false)

	# The door will not open without the key.
	DoorController.approach_enabled = false
	tower.lower_door.animate_player_interaction = false
	_expect(tower.lower_door.get_prompt_text_for_player(player) == "PROMPT_LOCKED", "without the key the door offers only 'locked'")
	tower.lower_door.interact(player)
	_expect(tower.lower_door.is_locked and not tower.lower_door.is_open, "and stays shut when tried")
	await get_tree().process_frame


## A ray from an eye at `eye` to `aim`, as the interaction ray would run (it sees areas as well as solids): the
## first thing it meets must be `item`, so nothing solid lies over it.
func _ray_finds(item: Node, eye: Vector3, aim: Vector3, what: String) -> void:
	var space: PhysicsDirectSpaceState3D = clearing.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, aim + (aim - eye).normalized() * 0.1)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(query)
	var collider: Node = hit.get("collider") as Node
	var found: Node = collider
	while found != null and not found is Interactable:
		found = found.get_parent()

	_expect(
		found == item,
		"an interaction ray reaches %s (hit %s)" % [what, str(collider.get_path()) if collider != null else "nothing"]
	)


## The key and Rain at the Station out of the lantern's drawer, the key into the lock; the Scraped Knee and the Broken Lever taken from where they lie.
func _take_from_tower() -> void:
	var lantern: SignalLantern = (clearing.get_node("CampDressing") as FigClearingProps).lantern as SignalLantern
	var rain: Collectible = lantern.find_child("Photo", true, false) as Collectible
	rain.interact(player)
	_expect(player.inspect_controller.is_open(), "Rain at the Station opens the inspect view")
	await _wait(0.5)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)
	var key: Collectible = lantern.find_child("Key", true, false) as Collectible
	key.interact(player)
	_expect(player.has_inventory_item("brass_signal_key"), "the key is in the inventory")
	_expect(bool(SaveManager.get_state_value(&"collectibles", &"brass_signal_key", false)), "taking it is remembered")
	await _wait(0.5)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)

	var door: DoorController = tower.lower_door
	_expect(door.get_prompt_text_for_player(player) == "PROMPT_UNLOCK", "with the key the door offers to unlock")
	door.interact(player)
	_expect(not door.is_locked and door.is_open, "the key opens the tower's door")
	_expect(not player.has_inventory_item("brass_signal_key"), "and stays in the lock")

	# The tower's three photographs lie about the relay room (none in a box): the Scraped Knee against the desk
	# lamp, the Broken Lever on the daybed, the Foggy Platform in the tin on the back shelf.
	var photos: Dictionary = tower.props.photos
	var ids: Array = photos.keys()
	ids.sort()
	_expect(ids == ["photo_broken_lever", "photo_childhood", "photo_foggy_platform"], "the Scraped Knee, the Broken Lever and the Foggy Platform lie in the tower (%s)" % str(ids))
	_check_photo_back(photos["photo_childhood"], "PHOTO_NOTE_CHILDHOOD")
	_check_photo_back(photos["photo_broken_lever"], "PHOTO_NOTE_BROKEN_LEVER")
	_check_photo_back(photos["photo_foggy_platform"], "PHOTO_NOTE_FOGGY_PLATFORM")

	for item_id: String in ["photo_childhood", "photo_broken_lever"]:
		var photo: Collectible = photos[item_id] as Collectible
		_expect(photo.can_interact(player), item_id + " can be picked up where it lies")
		photo.interact(player)
		await _wait(0.5)
		player.inspect_controller.close(false)
		player.inventory_ui_controller.close()
		await _wait(0.6)


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
