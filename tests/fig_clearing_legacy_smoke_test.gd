extends Node

## Loads the fig tree clearing and the signal tower from a save made before the camp was revised, and plays them HQ first.
##
## The old save (written here, in a test slot): the J & S box shut with a half turned dial, the tower's door saved locked, an old red
## herring photograph placed in the album (placing took it from the hands), and a manual snapshot whose inventory holds the old brass key
## and another old red herring. Loaded, the box stands open with Rain at the Station in it, the door opens with no key (and leaves the key
## alone), a door of another kind still keeps its lock, the photograph in the album goes back to the hands once (loading again does not
## give it twice), and the album takes only the three story photographs. Then the memory is played, the game is saved before the Ficha is
## taken and loaded (one Ficha, on the empty seat, the fire cold, the camp's lights out), the Ficha is taken and the game loaded again (no
## Ficha), and once the Ficha is in the payphone's slot no Ficha comes back either. Run it as a scene; it quits by itself with a non-zero
## exit code on failure.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_fig_clearing_legacy_smoke"
const TEST_SCENE_PATH: String = "res://tests/fig_clearing_test.tscn"
const SELF_SCENE_PATH: String = "res://tests/fig_clearing_legacy_smoke_test.tscn"
const TIME_SCALE: float = 6.0
const STORY_PHOTOS: Array[String] = ["photo_adolescence", "photo_childhood", "photo_recent"]

var test_failed: bool = false
var level: Node = null
var clearing: FigClearingSequence = null
var tower: SignalTowerBuilder = null
var player: CharacterBody3D = null


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "fig_legacy_start", "SAVE_LOCATION_DREAM_INTRO")
	GameSettings.set_captions_enabled(true, false)
	_write_the_old_save()

	await _load_level()
	Engine.time_scale = TIME_SCALE
	await _run()
	Engine.time_scale = 1.0

	SaveManager.delete_slot(1)
	print("FIG_CLEARING_LEGACY_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


## What the game used to save in the middle of the old route: the box shut (its dial half turned), the door locked, the Lucas at the
## Workshop photograph in the album's first space, and in the hands the brass key and The Broken Lever.
func _write_the_old_save() -> void:
	SaveManager.set_state_value(&"puzzles", &"js_lockbox_open", false)
	SaveManager.set_state_value(&"puzzles", &"js_lockbox_digits", [1, 4, 0, 0])
	SaveManager.set_state_value(&"doors", &"signal_tower_front_door", {"is_open": false, "is_locked": true, "key_side": 0, "signed_open_angle_degrees": 85.0})
	SaveManager.set_state_value(&"puzzles", &"album_arrangement", ["photo_workshop", "", ""])
	for item_id: String in ["photo_workshop", "photo_broken_lever", "brass_signal_key"]:
		SaveManager.set_state_value(&"collectibles", StringName(item_id), true)

	var inventory: Array = [
		{"id": "brass_signal_key", "name": "ITEM_BRASS_SIGNAL_KEY_NAME", "description": "ITEM_BRASS_SIGNAL_KEY_DESCRIPTION", "item_scene_path": "res://scenes/objects/signal_tower/brass_signal_key.tscn"},
		{"id": "photo_broken_lever", "name": "ITEM_PHOTO_BROKEN_LEVER_NAME", "description": "ITEM_PHOTO_BROKEN_LEVER_DESCRIPTION", "item_scene_path": "res://scenes/objects/photo_broken_lever.tscn"},
	]
	var saved: Error = SaveManager.save_manual_game(SELF_SCENE_PATH, {
		"position": [-11.0, 1.1, 2.1],
		"rotation": [0.0, 0.0, 0.0],
		"movement": {},
		"inventory": inventory,
		"flashlight": {"is_on": true},
	})
	_expect(saved == OK, "the old save is written (%s)" % error_string(saved))


func _run() -> void:
	# The inventory is the old one, with the photograph the album held given back, once.
	_expect(_count("brass_signal_key") == 1 and _count("photo_broken_lever") == 1, "the old save's hands are restored: the brass key and The Broken Lever")
	_expect(_count("photo_workshop") == 1, "and Lucas at the Workshop, which the album held, is back in the hands, once")
	var album: PhotoAlbum = clearing.album
	_expect(album.arrangement == ["", "", ""], "its space in the album is empty again (%s)" % str(album.arrangement))
	_expect(SaveManager.get_state_value(&"puzzles", &"album_arrangement", []) == ["", "", ""], "and the corrected arrangement is what is saved now")
	_expect(not album.locked, "the album is not solved by it")

	# The same save state read again (as by the next load) gives nothing twice.
	var again: PhotoAlbum = (load("res://scenes/objects/photo_album.tscn") as PackedScene).instantiate() as PhotoAlbum
	level.add_child(again)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_count("photo_workshop") == 1, "reading the save again does not give the photograph back twice")
	again.queue_free()
	await get_tree().process_frame

	# The box is open, whatever the old save said, with Rain at the Station in it and no key.
	var dressing: FigClearingProps = clearing.get_node("CampDressing") as FigClearingProps
	var lockbox: JSLockbox = dressing.lockbox
	_expect(lockbox.is_unlocked and not lockbox.can_interact(player), "the J & S box saved shut stands open, with no dial to work")
	var rain: Collectible = lockbox.find_child("Photo", true, false) as Collectible
	_expect(rain != null and rain.is_inside_tree() and rain.item_id == "photo_adolescence" and rain.can_interact(player), "Rain at the Station lies in it, in reach")
	_expect(lockbox.find_child("Key", true, false) == null, "and no second key is put there")

	# The tower's door saved locked is let go, and it does not take the old key.
	var door: DoorController = tower.lower_door
	_expect(not door.is_locked and not door.is_open, "the tower's door saved locked is not locked, and still shut as it was")
	_expect(not bool((SaveManager.get_state_value(&"doors", &"signal_tower_front_door", {}) as Dictionary).get("is_locked", true)), "and it is saved unlocked from now on")
	# A door of another kind still keeps its lock.
	var other: DoorController = (load("res://scenes/objects/door_interactable.tscn") as PackedScene).instantiate() as DoorController
	other.starts_locked = true
	other.required_key_id = "some_other_key"
	other.persistent_id = &"test_other_locked_door"
	other.animate_player_interaction = false
	other.position = Vector3(20.0, 0.0, 20.0)
	level.add_child(other)
	await get_tree().process_frame
	_expect(other.is_locked and other.get_prompt_text_for_player(player) == "PROMPT_LOCKED", "a door that wants another key is still locked")
	other.interact(player)
	_expect(other.is_locked and not other.is_open, "and stays shut when tried")
	other.queue_free()

	# HQ first: the door, the Scraped Knee; then the camp.
	DoorController.approach_enabled = false
	door.animate_player_interaction = false
	_expect(door.get_prompt_text_for_player(player) == "PROMPT_OPEN", "the tower's door offers [E] Open")
	door.interact(player)
	_expect(door.is_open, "and opens")
	_expect(_count("brass_signal_key") == 1, "the old key stays in the hands")
	await _pick_up(tower.props.photos["photo_childhood"] as Collectible)
	await _pick_up(rain)
	await _pick_up(clearing.get_node("Props/PhotoRecent") as Collectible)
	for item_id: String in STORY_PHOTOS:
		_expect(_count(item_id) == 1, item_id + " is in the hands")

	# The album offers the three story photographs only, and is solved by them.
	album.interact(player)
	var view: AlbumView = album.view
	var tray_ids: Array[String] = []
	for card: Node in view._tray_row.get_children():
		if card is PhotoCardUI and not card.is_queued_for_deletion():
			tray_ids.append((card as PhotoCardUI).item_id)
	tray_ids.sort()
	_expect(tray_ids == STORY_PHOTOS, "the tray offers the three story photographs and none of the old ones (%s)" % str(tray_ids))
	view.drop_on_slot(0, {"item_id": "photo_childhood", "from_slot": -1})
	view.drop_on_slot(1, {"item_id": "photo_adolescence", "from_slot": -1})
	view.drop_on_slot(2, {"item_id": "photo_recent", "from_slot": -1})
	_expect(album.locked, "the right order solves the album")
	await _until(func() -> bool: return clearing.stage == FigClearingSequence.Stage.DONE, 90.0)
	_expect(_count("photo_workshop") == 1 and _count("photo_broken_lever") == 1 and _count("brass_signal_key") == 1, "the old photographs and the key are left in the hands")
	_expect(not bool(SaveManager.get_state_value(&"collectibles", &"photo_foggy_platform", false)), "and nothing the player never took is marked as taken")
	_expect(clearing._ficha != null, "the Ficha lies on Table B")

	# Saved now, before the Ficha is taken, and loaded.
	await _save_and_load()
	_expect(clearing.stage == FigClearingSequence.Stage.DONE and not clearing.recorder.is_turning(), "loaded: the memory stays over")
	_expect(CaptionManager._active_run.is_empty() and CaptionManager._runs.is_empty(), "nothing is said again")
	_expect(not clearing.fire.is_lit, "the fire is cold ash")
	dressing = clearing.get_node("CampDressing") as FigClearingProps
	_expect(dressing.lights_out and not dressing.lantern_light.visible and not dressing.radio_static.playing, "the camp's lights stay out (the lantern and the radio)")
	var fichas: Array[Collectible] = _fichas_in_world()
	_expect(fichas.size() == 1, "one Ficha lies in the clearing (%d)" % fichas.size())
	if fichas.size() == 1:
		_expect(fichas[0].global_position.distance_to(clearing.token_landing()) < 0.01, "on Table B, at the landing anchor")
		fichas[0].interact(player)
		await _wait(0.5)
		player.inspect_controller.close(false)
		player.inventory_ui_controller.close()
		await _wait(0.6)
	_expect(_count("juliana_ficha") == 1, "taken, it is in the hands once")

	# Saved after it is taken, and loaded: no Ficha comes back, and the one in the hands is still there once.
	await _save_and_load()
	_expect(_fichas_in_world().is_empty(), "loaded after the Ficha is taken: none lies in the clearing")
	_expect(_count("juliana_ficha") == 1, "and the one in the hands is still there, once")

	# In the payphone's slot (as the overlook saves it): still no Ficha in the clearing, and it is the one the payphone takes.
	_expect(OverlookPhoneSequence.FICHA_IDS.has("juliana_ficha") and str(OverlookPhoneSequence.FICHA_SCENES["juliana_ficha"]) == clearing.ficha_scene.resource_path, "the payphone takes this Ficha, from this scene")
	player.consume_inventory_item("juliana_ficha")
	SaveManager.set_state_value(&"puzzles", &"orelhao_fichas", ["juliana_ficha"])
	await _save_and_load()
	_expect(_fichas_in_world().is_empty() and _count("juliana_ficha") == 0, "once it is in the payphone, no Ficha is in the clearing or the hands")


## Saves the game as the pause menu does (the player's snapshot and the state together), frees the level and loads it again.
func _save_and_load() -> void:
	var saved: Error = SaveManager.save_manual_game(SELF_SCENE_PATH, player.get_manual_save_state())
	_expect(saved == OK, "the game is saved")
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await _load_level()


func _load_level() -> void:
	level = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	clearing = level.get_node("FigClearing")
	tower = level.get_node("SignalTower")
	player = level.get_node("Player")


func _pick_up(item: Collectible) -> void:
	_expect(item != null and item.can_interact(player), "%s can be picked up" % (item.item_id if item != null else "?"))
	if item == null:
		return

	item.interact(player)
	await _wait(0.5)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.6)


func _fichas_in_world() -> Array[Collectible]:
	var found: Array[Collectible] = []
	for node: Node in level.find_children("*", "Collectible", true, false):
		var item: Collectible = node as Collectible
		if item.item_id == "juliana_ficha" and not item.is_queued_for_deletion():
			found.append(item)
	return found


## How many times an item is in the player's hands.
func _count(item_id: String) -> int:
	var count: int = 0
	for slot_data: Dictionary in player.inventory_controller.get_slots():
		count += 1 if str(slot_data.get("id", "")) == item_id else 0
	return count


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
