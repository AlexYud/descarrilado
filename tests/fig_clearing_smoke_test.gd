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

	# The two halves of the puzzle: the clothesline, the thermos and the lockbox in the camp, the note on the tower's door.
	await _check_two_part_puzzle()

	# Picking up a photograph shows it in the inspect view first. The camp's two lie on the ground (the third, Rain at the Station, is in the lockbox); the
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
	var camp: FigClearingProps = clearing.get_node("CampDressing") as FigClearingProps
	_expect(camp.lights_out and not camp.lantern_light.visible and is_zero_approx(camp.lantern_glass_material.emission_energy_multiplier) and not camp.lantern_flame.visible, "the lantern on the memory table goes out with the fire: total darkness")
	_expect(not camp.radio_static.playing and is_zero_approx(camp.radio_lamp_material.emission_energy_multiplier), "and so do the railway radio's hiss and lamp")
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


## The tower's key is in the camp, and it takes some doing to get it: Sophia's note on the thermos says she locked it (and the station photo) in the
## J & S lockbox, with the code of their emergency radio channel, and that the radio's panel at the entrance has it. The railway radio on its crate
## by the western trail entrance has its dial locked on 14.08 MHz (a red needle, a bar bolted over the slider, a strip of masking tape marked HQ
## above it), and 1 4 0 8 on the lockbox's dial pops its lid open on the key and the photograph "Rain at the Station". The lockbox stands at
## the southern end of the log table, near its edge, facing out along it. A note pinned to the tower's door says the key is at the camp. The
## tower's door is locked until the key is used.
func _check_two_part_puzzle() -> void:
	var dressing: FigClearingProps = clearing.get_node("CampDressing") as FigClearingProps
	_expect(dressing != null, "the camp has its dressing")
	for gone: String in ["BrassSignalKey", "CampNote", "PhotoAdolescence"]:
		_expect(clearing.get_node_or_null("Props/" + gone) == null, gone + " no longer lies on the ground or the camp table")

	# The clothesline: a rope between two trees near the western trail entrance, out of the player's head's way, with a damp jacket that is only
	# a dressing now (no pocket to search, no ticket) and no note.
	_expect(dressing.trees.size() == 2, "a clothesline hangs between two trees")
	var lowest: float = INF
	for point: Vector3 in dressing.rope_points:
		lowest = minf(lowest, point.y)
	_expect(lowest > 1.75, "the rope hangs above head height (%.2f m at its lowest)" % lowest)
	for tree: Node3D in dressing.trees:
		_expect(tree.global_position.x < -4.0 and Vector2(tree.global_position.x, tree.global_position.z).length() < 7.5, "tree %s stands by the trail entrance, inside the clearing" % tree.name)

	var jacket: Node3D = dressing.jacket
	_expect(jacket != null and jacket.global_position.y < lowest + 0.1 and jacket.global_position.y > 1.7, "a damp jacket hangs from the rope")
	_expect(not jacket is Interactable and jacket.find_children("*", "Area3D", true, false).is_empty() and jacket.find_children("*", "PhysicsBody3D", true, false).is_empty(), "it is only a dressing: nothing to search, nothing solid")
	_expect(dressing.find_child("ClotheslineNote", true, false) == null and dressing.find_child("PegFront", true, false) == null, "no note is pegged to the rope")
	_expect(dressing.find_child("Ticket", true, false) == null and jacket.find_children("*", "Collectible", true, false).is_empty(), "and no ticket is tucked in the jacket")
	for removed: String in ["READABLE_CAMP_NOTE", "ITEM_CAMP_NOTE_NAME", "READABLE_BUS_TICKET", "ITEM_BUS_TICKET_1994_NAME", "PROMPT_SEARCH_POCKET", "BUS_TICKET_1994_PRINT"]:
		_expect(tr(removed) == removed, removed + " is gone from the texts")

	_expect(not FigClearingProps.has_kind(&"clothesline_note") and not FigClearingProps.has_kind(&"bus_ticket_1994") and not FigClearingProps.has_kind(&"signal_lantern"), "and so are the models of the note, the ticket and the old lantern")

	await _check_the_radio(dressing)
	await _check_the_camp_layout(dressing)

	# The log table next to the campfire, with a bench, the thermos at one end and the lockbox at the other.
	var table: Node3D = dressing.log_table
	var fire_spot: Vector3 = clearing.get_node("Scenery/Campfire").global_position
	_expect(table != null and Vector2(table.global_position.x - fire_spot.x, table.global_position.z - fire_spot.z).length() < 3.0, "a log table stands next to the campfire")
	_expect(dressing.log_bench != null and dressing.log_bench.global_position.distance_to(table.global_position) < 1.2, "with a log bench beside it")
	_expect(table.find_child("Solid", false, false) != null and dressing.log_bench.find_child("Solid", false, false) != null, "both are solid")
	var thermos: Inspectable = dressing.thermos
	var lockbox: JSLockbox = dressing.lockbox
	_expect(thermos != null and lockbox != null and thermos.get_parent() == table and lockbox.get_parent() == table, "the thermos and the lockbox stand on the table")
	_expect(absf(lockbox.global_position.y - table.global_position.y - FigClearingProps.TABLE_TOP_Y) < 0.01, "the lockbox rests on the planks")
	_expect(dressing.find_child("SignalLantern", true, false) == null and dressing.find_child("Pane0", true, false) == null and dressing.find_child("Cage", true, false) == null, "the old signal lantern is gone from the table")

	# The lockbox is at the table's southern end, near the edge, with its dial turned out along the table (not toward the bench, and not in the
	# middle), so that a player at the end of the table stands right in front of it.
	var in_table: Vector3 = table.to_local(lockbox.global_position)
	_expect(in_table.x > 0.5 and absf(in_table.z) < 0.2, "the lockbox stands at the southern end of the table, not in the middle (%.2f m along it, %.2f across)" % [in_table.x, in_table.z])
	var along: Vector3 = table.global_basis.x.normalized()
	var faces: float = lockbox.global_basis.z.normalized().dot(along)
	_expect(faces > 0.99, "its dial faces out along the table, toward its end (%.3f)" % faces)
	var front_edge: float = in_table.x + FigClearingProps.LOCKBOX_SIZE.z * 0.5 + 0.016
	var margin: float = FigClearingProps.TABLE_LENGTH * 0.5 - front_edge
	_expect(margin > 0.0 and margin < 0.06, "with its front just short of the table's end (%.1f cm from the edge)" % (margin * 100.0))
	_expect(table.to_local(thermos.global_position).x < -0.4, "the thermos stands at the other end")

	var thermos_spot: ReadableSpot = thermos.get_visual_node().find_child("NoteSpot", true, false) as ReadableSpot
	_expect(thermos_spot != null and thermos_spot.text_key == "READABLE_THERMOS" and thermos_spot.obvious, "the thermos has its note as a readable spot, offered from the start")
	_expect(thermos.get_visual_node().find_child("Pin", true, false) != null, "pinned round its middle")
	var thermos_en: String = "Juli, I put the tower key and the station photo in our lockbox. I used the password of our emergency radio channel. I took the other photos to organize the board up at the HQ. See you at the Tower. Don't drink all the coffee at once. — Sophia"
	_expect(tr("READABLE_THERMOS") == thermos_en, "the thermos note in English (%s)" % tr("READABLE_THERMOS").left(30))
	_expect(not tr("READABLE_THERMOS").contains("-"), "with no hyphen")
	for piece: Node3D in [thermos, lockbox, dressing.radio]:
		_expect(piece.find_children("*", "PhysicsBody3D", true, false).is_empty() and piece.find_children("*", "CSGShape3D", true, false).is_empty(), piece.name + " is nothing solid: it cannot block the player or a ray")
	GameSettings.set_text_locale("pt_BR", false)
	_expect(tr("READABLE_THERMOS") == "Juli, guardei a chave da torre e a foto da estação na nossa caixa de segurança. Usei a senha do nosso canal de rádio de emergência. Peguei as outras fotos pra organizar o mural lá em cima no QG. Te vejo na Torre. Não bebe o café todo de uma vez. — Sophia", "the thermos note is Sophia's Portuguese, word for word")
	_expect(not tr("READABLE_THERMOS").contains("-"), "with no hyphen in Portuguese either")
	_expect(tr("PROMPT_INSPECT_LOCKBOX") == "Examinar a caixa de segurança", "the lockbox prompt in Portuguese")
	_expect(tr("ITEM_THERMOS_NAME") != "ITEM_THERMOS_NAME" and tr("LOCKBOX_VIEW_HINT") != "LOCKBOX_VIEW_HINT", "and the thermos's name and the texts of the lockbox view too")
	GameSettings.set_text_locale("en", false)
	_expect(tr("PROMPT_INSPECT_LOCKBOX") == "Inspect Lockbox", "[E] Inspect Lockbox")

	# The lockbox, before it is touched: shut, the code 1 4 0 8 on four wheels, the contents inside and out of the scene.
	_expect(lockbox.code == [1, 4, 0, 8], "the code is 1 4 0 8")
	var radio_digits: Array[int] = []
	for letter: String in ("%.2f" % FigClearingProps.RADIO_LOCKED_AT).replace(".", ""):
		radio_digits.append(int(letter))

	_expect(radio_digits == lockbox.code, "which is the frequency the radio's dial is locked on, 14.08, without the point")
	_expect(lockbox.digits == [0, 0, 0, 0] and not lockbox.is_unlocked, "the wheels start at 0 0 0 0, the lockbox shut")
	_expect(lockbox.can_interact(player) and lockbox.get_prompt_text() == "PROMPT_INSPECT_LOCKBOX", "it offers 'Inspect Lockbox'")
	var wheels: Node = lockbox.get_node("Model/Wheels")
	_expect(wheels.get_child_count() == 4, "the dial has four wheels")
	var digits_on_rims: bool = true
	for wheel: Node in wheels.get_children():
		digits_on_rims = digits_on_rims and wheel.find_children("Digit*", "Label3D", false, false).size() == 10

	_expect(digits_on_rims, "each with its ten digits round the rim")
	var initials: Array[Node] = lockbox.find_children("Mark*", "Label3D", true, false)
	_expect(initials.size() == 6, "'J & S' is painted on the front and on the lid, a mark at a time (%d marks)" % initials.size())
	_expect(lockbox.find_child("Key", true, false) == null and lockbox.find_child("Photo", true, false) == null, "the key and the photograph are inside, out of reach")
	var lid: Node3D = lockbox.get_node("Model/LidPivot")
	_expect(is_zero_approx(lid.rotation_degrees.x), "the lid is shut")

	# An interaction ray, run from where the player would stand, reaches each one: nothing solid hides them.
	var front: Vector3 = lockbox.global_basis.z.normalized()
	var eye: Vector3 = lockbox.global_position + front * 0.9
	eye.y = 1.5
	var thermos_eye: Vector3 = thermos.global_position + table.global_basis.z.normalized() * 0.9
	thermos_eye.y = 1.5
	await _ray_finds(thermos, thermos_eye, thermos.global_position, "the thermos")
	await _ray_finds(lockbox, eye, lockbox.global_position + Vector3(0.0, 0.05, 0.0), "the lockbox")
	var memory_table: Node3D = clearing.get_node("Scenery/CampTable") as Node3D
	var album_eye: Vector3 = clearing.album.global_position + memory_table.global_basis.z.normalized() * 0.9
	album_eye.y = 1.4
	await _ray_finds(clearing.album, album_eye, clearing.album.to_global(Vector3(-0.2, 0.012, 0.1)), "the album on the memory table")
	await _check_standing_at_the_lockbox(table, lockbox)

	# Looking at the thermos opens the inspect view, which offers its note to read straight away.
	thermos.interact(player)
	await _wait(0.8)
	var inspect_view: PlayerInspectController = player.inspect_controller
	_expect(inspect_view.is_open() and inspect_view.readables.has_obvious_reading(), "the thermos opens in the inspect view with its note offered to read")
	inspect_view.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)

	await _open_the_lockbox(lockbox, eye)

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


## The railway radio on its crate by the western trail entrance: it faces the way the player arrives, its dial is locked on 14.08 MHz (a red needle
## on the scale, a bar bolted over the slider, masking tape marked HQ above it), `[E] Inspect Radio` shows its front panel close up and offers its
## words, and the words are the ones the brief gives, in both languages.
func _check_the_radio(dressing: FigClearingProps) -> void:
	var radio: Inspectable = dressing.radio
	var crate: Node3D = dressing.radio_crate
	_expect(radio != null and crate != null and radio.get_parent() == crate, "a railway radio stands on a wooden crate")
	var spot_in_clearing: Vector3 = clearing.to_local(radio.global_position)
	_expect(spot_in_clearing.x < -4.5 and Vector2(spot_in_clearing.x, spot_in_clearing.z).length() < 7.5, "by the western trail entrance, inside the clearing (%.1f, %.1f)" % [spot_in_clearing.x, spot_in_clearing.z])
	_expect(absf(radio.global_position.y - crate.global_position.y - FigClearingProps.RADIO_CRATE_SIZE.y) < 0.01, "on top of the crate")
	_expect(crate.find_child("Solid", false, false) != null, "the crate is solid")
	_expect(radio.find_children("*", "PhysicsBody3D", true, false).is_empty(), "and the radio on it is not (its area is what the ray finds)")
	var arriving: Vector3 = clearing.to_global(Vector3(-9.0, 0.0, 0.5)) - radio.global_position
	arriving.y = 0.0
	var faces: float = arriving.normalized().dot(radio.global_basis.z)
	_expect(faces > 0.8, "the radio faces the way the player arrives along the trail (%.2f)" % faces)
	_expect(radio.get_prompt_text() == "PROMPT_INSPECT_RADIO" and radio.can_interact(player), "it offers 'Inspect Radio'")
	_expect(dressing.battery != null and dressing.radio_crate.find_child("Cable", true, false) != null, "a heavy cable runs from its back to a car battery on the ground")

	var visual: Node3D = radio.get_visual_node()
	var meshes: int = visual.find_children("*", "MeshInstance3D", true, false).size()
	var crate_meshes: int = crate.find_children("*", "MeshInstance3D", true, false).size() - meshes
	_expect(meshes < 40 and crate_meshes < 20, "the radio and its crate are a few dozen meshes, not two hundred: their plain parts are folded by material (%d and %d)" % [meshes, crate_meshes])
	var spot: ReadableSpot = visual.get_node_or_null("PanelSpot") as ReadableSpot
	_expect(spot != null and spot.text_key == "READABLE_RADIO" and spot.obvious, "its front panel is a readable spot, offered from the start")
	_expect(spot != null and spot.get_facing_normal().dot(visual.global_basis.z) > 0.99, "facing front")

	# The dial: a scale printed from 14.00 to 14.20 MHz, the red needle on the 14.08 mark, the slider locked there under a bar, tape above.
	var labels: Array[String] = []
	var number_x: Array[float] = []
	for i: int in 6:
		var number: Label3D = visual.find_child("Freq%d" % i, true, false) as Label3D
		labels.append(number.text if number != null else "?")
		number_x.append(number.position.x if number != null else 0.0)

	_expect(labels == ["14.00", "14.04", "14.08", "14.12", "14.16", "14.20"], "the dial's scale is printed from 14.00 to 14.20 MHz (%s)" % str(labels))
	var needle: MeshInstance3D = visual.get_node_or_null("Needle") as MeshInstance3D
	_expect(needle != null, "the dial has a needle")
	var needle_color: Color = (needle.material_override as StandardMaterial3D).albedo_color
	_expect(needle_color.r > 0.6 and needle_color.g < 0.15 and needle_color.b < 0.15, "a red one")
	_expect(absf(needle.position.x - number_x[2]) < 0.002 and absf(needle.position.x - FigClearingProps.radio_scale_x(14.08)) < 0.0005, "pointing at 14.08 MHz (the needle is %.1f mm from the 14.08 mark)" % (absf(needle.position.x - number_x[2]) * 1000.0))
	var number_label: Label3D = visual.find_child("Freq2", true, false) as Label3D
	_expect(number_label.modulate.r > 0.8 and number_label.modulate.g < 0.5, "and that number is printed red")
	_expect(needle.position.y + (needle.mesh as BoxMesh).size.y * 0.5 < number_label.position.y, "the needle ends under the number, not over it")
	var slider: Node3D = visual.get_node_or_null("Slider") as Node3D
	var lock: Node3D = visual.get_node_or_null("LockBar") as Node3D
	_expect(slider != null and absf(slider.position.x - needle.position.x) < 0.001, "the needle sits on the slider, under the dial")
	_expect(lock != null and absf(lock.position.x - slider.position.x) < 0.001 and is_equal_approx(lock.position.y, slider.position.y), "which is locked in place by a steel bar over it")
	# (Two parts of one name are renamed by the engine, so the bolts are the hexagonal heads.)
	var bolts: int = 0
	for part: Node in lock.find_children("*", "MeshInstance3D", false, false):
		var head: CylinderMesh = (part as MeshInstance3D).mesh as CylinderMesh
		bolts += 1 if head != null and head.radial_segments == 6 else 0

	_expect(bolts == 2 and lock.get_node_or_null("Seal") != null, "bolted at both ends (%d hex bolts), with a dab of red sealing wax on one" % bolts)
	var tape: Node3D = visual.get_node_or_null("Tape") as Node3D
	var bezel: MeshInstance3D = visual.get_node_or_null("DialBezel") as MeshInstance3D
	_expect(tape != null and bezel != null and tape.position.y > bezel.position.y + (bezel.mesh as BoxMesh).size.y * 0.5 and absf(tape.position.x - needle.position.x) < 0.02, "a strip of masking tape is stuck above the dial, over the needle")
	var tape_mark: Label3D = tape.get_node_or_null("Mark") as Label3D
	_expect(tape_mark != null and tape_mark.text == "HQ", "marked HQ")

	# The words, in both languages, exactly as the brief gives them.
	_expect(tr("READABLE_RADIO") == "Industrial Railway Transmitter — Frequency dial stuck at 14.08 MHz.", "the radio's words in English (%s)" % tr("READABLE_RADIO"))
	_expect(tr("PROMPT_INSPECT_RADIO") == "Inspect Radio" and tr("ITEM_RADIO_NAME") != "ITEM_RADIO_NAME" and tr("ITEM_RADIO_DESCRIPTION") != "ITEM_RADIO_DESCRIPTION", "[E] Inspect Radio, with a name and a description")
	GameSettings.set_text_locale("pt_BR", false)
	_expect(tr("READABLE_RADIO") == "Transmissor Industrial Ferroviário — Seletor de frequência travado em 14,08 MHz.", "and in Portuguese")
	_expect(tr("PROMPT_INSPECT_RADIO") == "Examinar o rádio" and tr("ITEM_RADIO_NAME") != "ITEM_RADIO_NAME" and tr("ITEM_RADIO_DESCRIPTION") != "ITEM_RADIO_DESCRIPTION", "with the prompt, the name and the description translated")
	GameSettings.set_text_locale("en", false)

	# A ray from where the player stands in front of it reaches the radio: the crate's solid is below it, nothing is in front.
	var radio_eye: Vector3 = radio.global_position + radio.global_basis.z.normalized() * 0.9
	radio_eye.y = 1.5
	await _ray_finds(radio, radio_eye, radio.global_position + Vector3(0.0, 0.2, 0.0), "the railway radio")

	# Inspecting it: the view comes up on the front panel, squarely, with the writing offered to read; reading shows its words; closing frees the player.
	radio.interact(player)
	await _wait(0.9)
	var inspect_view: PlayerInspectController = player.inspect_controller
	_expect(inspect_view.is_open() and inspect_view.readables.has_obvious_reading(), "the radio opens in the inspect view with the writing on its panel offered to read")
	var front_dot: float = inspect_view.current_visual_copy.global_basis.z.dot(inspect_view.camera.global_basis.z)
	_expect(front_dot > 0.97, "its front panel faces the player squarely (%.2f)" % front_dot)
	_expect(inspect_view.inspect_mode == PlayerInspectController.MODE_EXAMINE, "and it can be turned in every direction")
	inspect_view.readables.activate()
	await _wait(1.6)
	_expect(inspect_view.readables.is_reading() and inspect_view.readables._body.text == tr("READABLE_RADIO"), "reading it shows what the panel says (%s)" % inspect_view.readables._body.text.left(40))
	inspect_view.readables.close_text()
	await _wait(0.6)
	inspect_view.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.8)
	_expect(not inspect_view.is_open() and not player.modal_ui_open and not player.view_locked, "and the player is free again afterwards")


## The camp is laid out like a camp, and the way through it is clear: the tents are pitched apart with their doors toward the fire, the fire has three
## logs to sit on round it (the side toward the trail left open), the memory table stands clear of the fig tree and of its roots with its front toward
## the trail and a lit lantern on it, the roots run out from the trunk along the ground (they were four poles all leaning the same way), nothing
## overlaps anything, a player can walk the trail from one side of the clearing to the other, and the radio hisses on a dead channel.
func _check_the_camp_layout(dressing: FigClearingProps) -> void:
	var scenery: Node3D = clearing.get_node("Scenery") as Node3D
	var fire: Node3D = scenery.get_node("Campfire") as Node3D
	var tree: Node3D = scenery.get_node("FigTree") as Node3D
	var table: Node3D = scenery.get_node("CampTable") as Node3D
	var fire_at: Vector2 = Vector2(fire.global_position.x, fire.global_position.z)
	var tree_at: Vector2 = Vector2(tree.global_position.x, tree.global_position.z)
	var table_at: Vector2 = Vector2(table.global_position.x, table.global_position.z)

	# The tents: apart, doors (an open doorway) toward the fire, some gear in front of each.
	var tents: Array[Node3D] = dressing.tents
	_expect(tents.size() == 2, "two tents are pitched")
	if tents.size() == 2:
		var apart: float = Vector2(tents[0].global_position.x - tents[1].global_position.x, tents[0].global_position.z - tents[1].global_position.z).length()
		_expect(apart > 6.0, "far enough apart not to stand like two gateposts (%.1f m)" % apart)
		for tent: Node3D in tents:
			var to_fire: Vector2 = (fire_at - Vector2(tent.global_position.x, tent.global_position.z)).normalized()
			var facing: float = Vector2(tent.global_basis.z.x, tent.global_basis.z.z).normalized().dot(to_fire)
			_expect(facing > 0.8, "%s is pitched with its door toward the fire (%.2f)" % [tent.name, facing])
			_expect(tent.find_child("Door", true, false) == null and tent.find_child("Gear", false, false) != null, "%s has some gear in front of it and no dark doorway drawn on it" % tent.name)

		_expect(tents[0].find_child("Backpack", true, false) != null and tents[1].find_child("Boot0", true, false) != null, "a backpack at one tent, boots at the other")

	# The fire: three logs on the ring, none on the side toward the trail.
	_expect(dressing.seats.size() == 3, "three logs to sit on lie round the fire")
	for seat: Node3D in dressing.seats:
		var radial: Vector2 = Vector2(seat.global_position.x, seat.global_position.z) - fire_at
		_expect(radial.length() > 1.2 and radial.length() < 2.1, "%s lies %.1f m from the fire" % [seat.name, radial.length()])
		var along: Vector2 = Vector2(seat.global_basis.x.x, seat.global_basis.x.z).normalized()
		_expect(absf(along.dot(radial.normalized())) < 0.55, "and along the ring, not pointing at it")
		var north: float = absf(rad_to_deg(radial.angle_to(Vector2(0.0, -1.0))))
		_expect(north > 40.0, "and not on the side toward the trail (%.0f degrees from it)" % north)

	_expect(dressing.find_child("Kettle", true, false) != null, "a kettle stands on a stone by the fire")
	var yard: Node3D = dressing.find_child("WoodYard", true, false) as Node3D
	_expect(yard != null and yard.find_child("Axe", true, false) != null, "and a chopping block with an axe in it, where the first tent stood")

	# The memory table: clear of the trunk and the roots, its front to the trail, everything on it, a lantern lit.
	var trunk_gap: float = (table_at - tree_at).length()
	_expect(trunk_gap > 2.3, "the memory table stands clear of the fig tree (%.1f m from its middle)" % trunk_gap)
	_expect(table.global_basis.z.dot(Vector3(0.0, 0.0, 1.0)) > 0.9, "with its front toward the trail")
	var on_table: Array[Node3D] = [clearing.recorder, clearing.album, clearing.get_node("Props/PhotoWorkshop") as Node3D, clearing.ficha_spot, scenery.get_node("EnamelCup") as Node3D]
	var all_on: bool = true
	for item: Node3D in on_table:
		var local: Vector3 = table.to_local(item.global_position)
		all_on = all_on and absf(local.x) < 0.72 and absf(local.z) < 0.38 and local.y > 0.77 and local.y < 0.86
	_expect(all_on, "the recorder, the album, the photograph, the cup and the Ficha's place are all on the table")
	# ... and none of them lies over another (the recorder used to trespass on the album).
	var laid: Dictionary = {
		"recorder": _footprint(clearing.recorder, Vector2(0.12, 0.075), false),
		"album": _footprint(clearing.album, Vector2(0.38, 0.145), false),
		"photograph": _footprint(clearing.get_node("Props/PhotoWorkshop") as Node3D, Vector2(0.075, 0.05), true),
		"cup": _footprint(scenery.get_node("EnamelCup") as Node3D, Vector2(0.045, 0.045), false),
		"Ficha's place": _footprint(clearing.ficha_spot, Vector2(0.05, 0.05), false),
		"lantern": _footprint(dressing.lantern, Vector2(0.062, 0.062), false),
	}
	var tightest: float = INF
	var tightest_pair: String = ""
	var names: Array = laid.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var gap: float = _footprint_gap(laid[names[i]], laid[names[j]])
			if gap < tightest:
				tightest = gap
				tightest_pair = "%s and %s" % [names[i], names[j]]

	_expect(tightest > 0.04, "nothing on the memory table lies over another thing: the tightest are the %s, %.0f cm apart" % [tightest_pair, tightest * 100.0])
	var recorder_gap: float = _footprint_gap(laid["recorder"], laid["album"])
	_expect(recorder_gap > 0.06, "and the recorder is clear of the album (%.0f cm)" % (recorder_gap * 100.0))
	_expect(dressing.lantern != null and dressing.lantern.get_parent() == table, "a lantern stands on it")
	_expect(dressing.lantern_light != null and dressing.lantern_light.visible and dressing.lantern_light.light_energy > 0.5 and dressing.lantern_light.global_position.distance_to(clearing.album.global_position) < 1.2, "lit, with a warm light of its own over the album")
	_expect(dressing.lantern_light.light_color.r > 0.9 and dressing.lantern_light.light_color.b < 0.6 and not dressing.lantern_light.shadow_enabled, "a warm one, with no shadows to pay for")
	var fire_light: OmniLight3D = fire.find_child("Light", true, false) as OmniLight3D
	_expect(fire_light != null and fire_light.global_position.distance_to(dressing.thermos.global_position) < fire_light.omni_range * 0.5, "while the thermos and the lockbox are well inside the fire's light")

	# The roots lie along the ground, out from the trunk in every direction, and none runs under the table.
	var bearings: Array[float] = []
	for i: int in range(1, 7):
		var root: Node3D = scenery.get_node_or_null("Root%d" % i) as Node3D
		_expect(root != null, "root %d is there" % i)
		if root == null:
			continue

		var axis: Vector3 = root.global_basis.y
		var out: Vector2 = Vector2(root.global_position.x, root.global_position.z) - tree_at
		var runs_out: bool = Vector2(axis.x, axis.z).normalized().dot(out.normalized()) > 0.95
		_expect(runs_out and axis.normalized().y < -0.05 and root.global_position.y < 0.12, "root %d runs out from the trunk and down into the ground, not up like a pole" % i)
		bearings.append(rad_to_deg(atan2(out.y, out.x)))
		var half: Vector3 = axis * 1.6
		var near: Vector2 = Geometry2D.get_closest_point_to_segment(table_at, Vector2(root.global_position.x - half.x, root.global_position.z - half.z), Vector2(root.global_position.x + half.x, root.global_position.z + half.z))
		_expect(near.distance_to(table_at) > 1.2, "and root %d keeps clear of the table (%.1f m)" % [i, near.distance_to(table_at)])

	bearings.sort()
	var widest: float = 0.0
	for i: int in bearings.size():
		var next: float = bearings[(i + 1) % bearings.size()] + (360.0 if i == bearings.size() - 1 else 0.0)
		widest = maxf(widest, next - bearings[i])

	_expect(widest < 130.0, "the roots spread all round the trunk (the widest gap is %.0f degrees)" % widest)

	# Nothing overlaps anything.
	var overlaps: Array[String] = _solid_overlaps()
	_expect(overlaps.is_empty(), "none of the camp's solid things overlaps another (%s)" % str(overlaps))

	# The trail runs clear through the clearing, west to east.
	var blocked: Array[String] = []
	var space: PhysicsDirectSpaceState3D = clearing.get_world_3d().direct_space_state
	var walker: CapsuleShape3D = CapsuleShape3D.new()
	walker.radius = 0.3
	walker.height = 1.2
	var probe: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	probe.shape = walker
	var lane_x: float = -6.2
	while lane_x <= 6.4:
		probe.transform = Transform3D(Basis.IDENTITY, clearing.to_global(Vector3(lane_x, 0.75, 0.25)))
		for hit: Dictionary in space.intersect_shape(probe, 8):
			var other: Node = hit.get("collider") as Node
			if other != null and not other.name in [&"Ground", &"InvisibleWalls"]:
				blocked.append("%s/%s at %.1f" % [other.get_parent().name, other.name, lane_x])

		lane_x += 0.4

	_expect(blocked.is_empty(), "a player can walk the trail from the west side to the east side without meeting anything (%s)" % str(blocked))

	# The radio hisses on a dead channel, faintly, so that it is heard before it is seen.
	var hiss: AudioStreamPlayer3D = dressing.radio_static
	var hiss_stream: AudioStreamWAV = hiss.stream as AudioStreamWAV if hiss != null else null
	_expect(hiss != null and hiss.playing and hiss_stream != null and hiss_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the railway radio hisses (a looping dead channel)")
	_expect(hiss != null and hiss.volume_db < -12.0 and hiss.max_distance >= 8.0 and hiss.global_position.distance_to(clearing.to_global(Vector3(-7.0, 1.2, 0.5))) < hiss.max_distance, "faintly, and it carries to the trail")
	_expect(dressing.radio_lamp_material != null and dressing.radio_lamp_material.emission_enabled and dressing.radio_lamp_material.emission_energy_multiplier > 0.3, "and its lamp glows red")


## Which digit counts has to be plain. The camera looks down on the dial, so the digit that faces straight out of the box used to be seen low, between two
## others. Now the digit that counts is the one that faces the close-up camera, on the line of sight through its wheel's axis (the middle of the wheel as it is
## seen); the other digits are dimmed by their distance from it; and the view frames that row.
func _check_the_digit_that_counts(lockbox: JSLockbox, view: JSLockboxView, view_camera: Camera3D) -> void:
	var seen_right: bool = true
	var on_the_line: bool = true
	var dimmed: bool = true
	for i: int in 4:
		var axis: Vector3 = lockbox.get_wheel_position(i)
		var to_camera: Vector3 = (view_camera.global_position - axis).normalized()
		var facing_digit: int = -1
		var facing_dot: float = -2.0
		var brightest: int = -1
		var brightest_value: float = -1.0
		for digit: int in 10:
			var label: Label3D = lockbox._wheels[i].get_node("Digit%d" % digit) as Label3D
			var dot: float = label.global_basis.z.normalized().dot((view_camera.global_position - label.global_position).normalized())
			if dot > facing_dot:
				facing_dot = dot
				facing_digit = digit

			if label.modulate.r > brightest_value:
				brightest_value = label.modulate.r
				brightest = digit

		seen_right = seen_right and facing_digit == lockbox.digits[i] and facing_dot > cos(deg_to_rad(18.0)) and brightest == lockbox.digits[i]
		var label_at: Vector3 = (lockbox._wheels[i].get_node("Digit%d" % lockbox.digits[i]) as Label3D).global_position
		var inverse: Transform3D = view_camera.global_transform.affine_inverse()
		var label_seen: Vector3 = inverse * label_at
		var axis_seen: Vector3 = inverse * axis
		var higher: float = (label_seen.y / label_seen.z - axis_seen.y / axis_seen.z) * absf(axis_seen.z)
		on_the_line = on_the_line and absf(higher) < 0.0015
		var next: Label3D = lockbox._wheels[i].get_node("Digit%d" % posmod(lockbox.digits[i] + 1, 10)) as Label3D
		var chosen: Label3D = lockbox._wheels[i].get_node("Digit%d" % lockbox.digits[i]) as Label3D
		dimmed = dimmed and next.modulate.r < chosen.modulate.r * 0.6

	_expect(seen_right, "on every wheel the digit that faces the camera is the value, and it is the brightest one")
	_expect(on_the_line, "and it is seen in the middle of its wheel, not above or below the axis (within 1.5 mm)")
	_expect(dimmed, "its neighbours are dimmed, so the wheel reads at a glance")
	var band: Control = view._band
	var arrows_left: float = view._up[0].position.x
	var arrows_right: float = view._up[3].position.x + view._up[3].size.x
	_expect(band != null and band.visible and band.position.x < arrows_left + view._up[0].size.x * 0.5 and band.position.x + band.size.x > arrows_right - view._up[3].size.x * 0.5, "the view frames the row the digits are read in, across the four wheels")
	var wheel_screen_y: float = view._through_the_lens(view_camera.unproject_position(lockbox.get_wheel_position(1))).y
	_expect(absf(band.position.y + band.size.y * 0.5 - wheel_screen_y) < 1.0, "with the frame on the middle of the wheels (off by %.1f px)" % absf(band.position.y + band.size.y * 0.5 - wheel_screen_y))


## A rectangle on the ground plane for a thing on a table: where its middle is, the directions of its two sides and half of each. A thing that lies
## on its back (a card) has its sides along the node's x and y; one that stands has them along x and z.
func _footprint(node: Node3D, half: Vector2, lying: bool) -> Dictionary:
	var basis: Basis = node.global_basis
	var first: Vector3 = basis.x
	var second: Vector3 = basis.y if lying else basis.z
	return {
		"centre": Vector2(node.global_position.x, node.global_position.z),
		"axes": [Vector2(first.x, first.z).normalized(), Vector2(second.x, second.z).normalized()],
		"half": half,
	}


## How far apart two such rectangles are, in metres (negative while they overlap): the separating axis test, the biggest gap along the four sides.
func _footprint_gap(a: Dictionary, b: Dictionary) -> float:
	var best: float = -INF
	for owner: Dictionary in [a, b]:
		for axis: Vector2 in owner["axes"]:
			var apart: float = absf(((b["centre"] as Vector2) - (a["centre"] as Vector2)).dot(axis))
			var reach: float = 0.0
			for rect: Dictionary in [a, b]:
				for k: int in 2:
					reach += absf((rect["axes"][k] as Vector2).dot(axis)) * (rect["half"] as Vector2)[k]

			best = maxf(best, apart - reach)

	return best


## The solid things of the clearing that overlap another one (each pair once). The ground and the invisible walls are left out, and every shape is
## shrunk a hair and lifted a hair so that things resting on the ground or on each other do not count.
func _solid_overlaps() -> Array[String]:
	var found: Array[String] = []
	var space: PhysicsDirectSpaceState3D = clearing.get_world_3d().direct_space_state
	for node: Node in clearing.find_children("*", "StaticBody3D", true, false):
		var body: StaticBody3D = node as StaticBody3D
		if body.name in [&"InvisibleWalls", &"Ground"]:
			continue

		for child: Node in body.get_children():
			var shaped: CollisionShape3D = child as CollisionShape3D
			if shaped == null or shaped.disabled:
				continue

			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			var at: Transform3D = shaped.global_transform
			if shaped.shape is BoxShape3D:
				var smaller: BoxShape3D = BoxShape3D.new()
				smaller.size = (shaped.shape as BoxShape3D).size - Vector3(0.06, 0.06, 0.06)
				query.shape = smaller
			elif shaped.shape is CylinderShape3D:
				var narrower: CylinderShape3D = CylinderShape3D.new()
				narrower.radius = (shaped.shape as CylinderShape3D).radius - 0.03
				narrower.height = (shaped.shape as CylinderShape3D).height - 0.06
				query.shape = narrower
			else:
				continue

			at.origin += Vector3(0.0, 0.03, 0.0)
			query.transform = at
			for hit: Dictionary in space.intersect_shape(query, 16):
				var other: Node = hit.get("collider") as Node
				if other == null or other == body or other.name in [&"Ground", &"InvisibleWalls"]:
					continue

				var pair: String = "%s + %s" % [body.get_parent().name if body.name in [&"Solid", &"TentBody", &"TrunkBody"] else body.name, other.get_parent().name if other.name in [&"Solid", &"TentBody", &"TrunkBody"] else other.name]
				var reverse: String = "%s + %s" % [pair.get_slice(" + ", 1), pair.get_slice(" + ", 0)]
				if not found.has(pair) and not found.has(reverse):
					found.append(pair)

	return found


## A player stands as close as they can to the end of the log table (the closest their capsule gets without overlapping the table's collision,
## which is right and solid): the lockbox is right in front of them, close, and the interaction ray from their eyes reaches it.
func _check_standing_at_the_lockbox(table: Node3D, lockbox: JSLockbox) -> void:
	var home: Vector3 = player.global_position
	var body_shape: CollisionShape3D = player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = body_shape.shape as CapsuleShape3D
	var standing: CapsuleShape3D = CapsuleShape3D.new()
	standing.radius = capsule.radius * body_shape.global_basis.get_scale().x
	standing.height = capsule.height * body_shape.global_basis.get_scale().y
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	var space: PhysicsDirectSpaceState3D = clearing.get_world_3d().direct_space_state
	var in_table: Vector3 = table.to_local(lockbox.global_position)
	var spot: Vector3 = Vector3.ZERO
	var gap: float = 0.0
	var found: bool = false
	for step: int in 60:
		gap = 0.005 * float(step)
		spot = table.to_global(Vector3(FigClearingProps.TABLE_LENGTH * 0.5 + standing.radius - 0.05 + gap, 0.0, in_table.z))
		spot.y = body_shape.global_position.y
		query.transform = Transform3D(Basis.IDENTITY, spot)
		var blocked: bool = false
		for info: Dictionary in space.intersect_shape(query, 8):
			var hit: Node = info.get("collider") as Node
			blocked = blocked or (hit != null and hit.get_parent() == table)

		if not blocked:
			found = true
			break

	_expect(found and gap > 0.04, "a player's capsule cannot get nearer the end of the table than %.0f cm from it: it is solid" % ((standing.radius + gap - 0.05) * 100.0))
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(spot.x, home.y, spot.z)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
	var aim: Vector3 = lockbox.global_position + Vector3(0.0, 0.05, 0.0)
	var reach: float = camera.global_position.distance_to(aim)
	_expect(reach < 0.9, "standing there, the player's eyes are close to the lockbox (%.2f m from the dial; the interaction ray reaches %.1f m)" % [reach, player.interaction_controller.interaction_distance])
	await _ray_finds(lockbox, camera.global_position, aim, "the lockbox, from the player's eyes at the end of the table")
	player.velocity = Vector3.ZERO
	player.global_position = home
	await get_tree().physics_frame


## The lockbox's dial: a wrong code does nothing; 1 4 0 8 holds the wheels, lets the latch go (CLACK-CLICK) and pops the lid open on the key and
## the photograph "Rain at the Station", which are then ordinary pickups.
func _open_the_lockbox(lockbox: JSLockbox, eye: Vector3) -> void:
	var view: JSLockboxView = lockbox.view
	lockbox.interact(player)
	_expect(view.is_open() and player.modal_ui_open, "interacting opens the close-up and holds the player")
	await _until(func() -> bool: return not view.is_flying())
	var close_up: Transform3D = lockbox.get_close_up_transform()
	var view_camera: Camera3D = lockbox.get_node("LockboxViewCamera") as Camera3D
	_expect(view_camera != null and view_camera.global_position.distance_to(close_up.origin) < 0.01, "the view camera flew to the front panel")
	_expect(view_camera.global_basis.z.dot(lockbox.global_basis.z) > 0.8, "and looks straight at it")
	_expect(view_camera.is_position_behind(lockbox.get_wheel_position(0)) == false and view_camera.unproject_position(lockbox.get_wheel_position(1)).x < view_camera.unproject_position(lockbox.get_wheel_position(2)).x, "the four wheels are in sight, in order")
	await get_tree().process_frame
	await get_tree().process_frame
	# (A headless window is tiny, so the arrows are only checked to be there, one above and one below each wheel.)
	var arrows_there: bool = true
	for i: int in 4:
		arrows_there = arrows_there and view._up[i].visible and view._down[i].visible and view._up[i].position.y < view._down[i].position.y
	_expect(arrows_there, "an arrow sits above and below each wheel, on the box")
	# They sit over the wheels as the picture filter's lens shows them (it bends the picture under them a little toward its corners).
	var filter: Node = get_node_or_null("/root/HorrorFilter")
	var worst_miss: float = 0.0 if filter != null else INF
	for i: int in 4:
		var shown: Vector2 = filter.call("lens_position", view_camera.unproject_position(lockbox.get_wheel_position(i)), get_viewport().get_visible_rect().size)
		worst_miss = maxf(worst_miss, maxf(absf(view._up[i].position.x + view._up[i].size.x * 0.5 - shown.x), absf(view._down[i].position.x + view._down[i].size.x * 0.5 - shown.x)))
	_expect(worst_miss < 1.0, "each pair is centred on its wheel as the filter's lens shows it (off by at most %.1f px)" % worst_miss)

	# Each wheel turns on its own, with a heavy tick; the wheel itself turns.
	var ticks: Array[int] = [0]
	lockbox.digit_changed.connect(func(_index: int, _value: int) -> void: ticks[0] += 1)
	view.turn(0, 1)
	_expect(lockbox.digits == [1, 0, 0, 0], "wheel one up once is 1 0 0 0")
	_expect(lockbox._sound.playing and lockbox._sound.stream != null and lockbox._sound.stream.get_length() > 0.2, "a heavy double tick sounds (%.2f s)" % lockbox._sound.stream.get_length())
	var turned_to: float = JSLockbox.DEGREES_PER_DIGIT - lockbox.reading_degrees
	await _until(func() -> bool: return absf(wrapf(lockbox._wheels[0].rotation_degrees.x - turned_to, -180.0, 180.0)) < 1.0, 4.0)
	_expect(absf(wrapf(lockbox._wheels[0].rotation_degrees.x - turned_to, -180.0, 180.0)) < 1.0, "and the wheel turned its 36 degrees (to the reading line, %.0f degrees above straight ahead)" % lockbox.reading_degrees)
	view.turn(3, -1)
	_expect(lockbox.digits == [1, 0, 0, 9], "wheel four down once is 9, round the other way")
	for step: int in 10:
		view.turn(2, 1)
	_expect(lockbox.digits[2] == 0 and ticks[0] == 12, "ten steps bring a wheel back where it was (%d ticks)" % ticks[0])
	await _wait(1.2)
	_expect(not lockbox.is_unlocked and is_zero_approx(lockbox.get_node("Model/LidPivot").rotation_degrees.x), "a wrong code does nothing: the lid stays shut")
	_expect(lockbox.find_child("Key", true, false) == null, "and the key is out of reach")

	_expect(view._selected == 2, "the wheel last turned is the chosen one, for the keyboard")
	_check_the_digit_that_counts(lockbox, view, view_camera)

	# Esc steps back: the player has their eyes and their hands again, the wheels keep their digits, and the box can be tried again.
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await _until(func() -> bool: return not view.is_open() and not view.is_flying() and not player.modal_ui_open, 8.0)
	_expect(not view.is_open() and not player.modal_ui_open, "Esc goes back and the player is free")
	_expect(lockbox.get_viewport().get_camera_3d() == player.get_node("Head/Camera3D") and lockbox.get_node_or_null("LockboxViewCamera") == null, "through their own eyes again")
	_expect(lockbox.digits == [1, 0, 0, 9] and not get_tree().paused, "the wheels keep their digits, and the game is not paused")
	lockbox.interact(player)
	_expect(view.is_open() and player.modal_ui_open, "and the box can be looked at again")
	await _until(func() -> bool: return not view.is_flying())

	# The right code: 1 4 0 8.
	view.turn(1, 4)
	_expect(lockbox.digits == [1, 4, 0, 9] and not lockbox.is_unlocked, "1 4 0 9 is not it")
	view.turn(3, -1)
	_expect(lockbox.digits == [1, 4, 0, 8], "1 4 0 8")
	_expect(lockbox.is_unlocked, "the wheels are held from the moment the code is right")
	view.turn(0, 1)
	_expect(lockbox.digits == [1, 4, 0, 8], "so a last nudge cannot undo it")
	var opened: Array[bool] = [false]
	lockbox.unlocked.connect(func() -> void: opened[0] = true)
	await _until(func() -> bool: return opened[0] and lockbox.find_child("Key", true, false) != null, 6.0)
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"js_lockbox_open", false)), "the opening is remembered")
	var latch_stream: AudioStream = lockbox._sound.stream
	_expect(latch_stream != null and latch_stream.get_length() > 0.5, "the latch let go with a CLACK and a CLICK (%.2f s of sound)" % (latch_stream.get_length() if latch_stream != null else 0.0))
	await _until(func() -> bool: return lockbox.get_node("Model/LidPivot").rotation_degrees.x < -100.0, 6.0)
	_expect(lockbox.get_node("Model/LidPivot").rotation_degrees.x < -100.0, "the lid popped open (%.0f degrees)" % lockbox.get_node("Model/LidPivot").rotation_degrees.x)
	_expect(lockbox.get_node("Model/Latch").rotation_degrees.x > 60.0, "the latch is out")
	_expect(not lockbox.can_interact(player), "the open lockbox no longer answers its dial")
	await get_tree().process_frame
	var area_disabled: bool = true
	for shape: Node in lockbox.get_node("InteractArea").get_children():
		area_disabled = area_disabled and (shape as CollisionShape3D).disabled
	_expect(area_disabled, "and its area no longer catches the interaction ray over the contents")

	# The view goes back by itself, a moment after: the player is free and sees the open box.
	await _until(func() -> bool: return not view.is_open() and not view.is_flying() and not player.modal_ui_open, 10.0)
	_expect(not view.is_open() and not player.modal_ui_open, "the view goes back by itself and the player is free")
	_expect(lockbox.get_viewport().get_camera_3d() == player.get_node("Head/Camera3D"), "through their own eyes again")
	_expect(lockbox.get_node_or_null("LockboxViewCamera") == null, "the view's camera is gone")

	var key: Collectible = lockbox.find_child("Key", true, false) as Collectible
	var photo: Collectible = lockbox.find_child("Photo", true, false) as Collectible
	_expect(key != null and key.item_id == "brass_signal_key" and key.can_interact(player), "the brass signal key lies in the open box")
	_expect(photo != null and photo.item_id == "photo_adolescence" and photo.can_interact(player), "and the photograph 'Rain at the Station' with it")
	_check_photo_back(photo, "PHOTO_NOTE_ADOLESCENCE")
	_expect(key.global_position.y > lockbox.global_position.y + 0.07 and photo.global_position.y > lockbox.global_position.y + 0.07, "both lie on the padding, up near the rim, in sight")
	_expect(key.global_basis.z.dot(Vector3.UP) > 0.95 and photo.global_basis.z.dot(Vector3.UP) > 0.95, "lying flat")
	await _ray_finds(key, eye, key.global_position, "the key in the open lockbox")
	await _ray_finds(photo, eye, photo.global_position, "the photograph in the open lockbox")


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


## The key and Rain at the Station out of the lockbox, the key into the lock; the Scraped Knee and the Broken Lever taken from where they lie.
func _take_from_tower() -> void:
	var lockbox: JSLockbox = (clearing.get_node("CampDressing") as FigClearingProps).lockbox
	var rain: Collectible = lockbox.find_child("Photo", true, false) as Collectible
	rain.interact(player)
	_expect(player.inspect_controller.is_open(), "Rain at the Station opens the inspect view")
	await _wait(0.5)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)
	var key: Collectible = lockbox.find_child("Key", true, false) as Collectible
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
