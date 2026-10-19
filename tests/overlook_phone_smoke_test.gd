extends Node

## Plays the overlook payphone through the game's own APIs: the prompt that says what
## the booth will do ("Insert ficha 1/2/3", "Pick up Receiver"), Juliana's "I need some
## fichas..." when she has none, walking up to the booth calmly, the two choices once
## she is looking at the unit ([E] for the next ficha, or moving away), the inserted
## fichas staying (and saved) while she looks for the others, the indicator turning
## green, the receiver off its hook, the call as captions while she turns her head to
## the left in place, the receiver left hanging, and the view returning to the player,
## who may look but not walk. Run it as a scene; it quits by itself with a non-zero exit
## code on failure. Game time runs faster so the waits are short.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_overlook_phone_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/overlook_phone_playtest.tscn"
const TIME_SCALE: float = 4.0
const FICHAS: Array[String] = ["juliana_ficha", "lucas_ficha", "sophia_ficha"]

var test_failed: bool = false
var level: Node = null
var phone: OverlookPhoneSequence = null
var player: CharacterBody3D = null


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(
		1, TEST_SCENE_PATH, "overlook_phone_test_start", "SAVE_LOCATION_DREAM_INTRO"
	)
	GameSettings.set_captions_enabled(true, false)
	GameSettings.set_text_locale("en", false)

	level = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	phone = level.get_node("OverlookPhone")
	phone.release_player_after_call_seconds = 0.0
	player = level.get_node("Player")
	Engine.time_scale = TIME_SCALE

	await _check_layout()
	await _check_note_rays()
	await _check_lamp_steady()
	await _check_without_fichas()
	await _check_first_ficha()
	await _check_the_rest()
	await _check_call()
	_check_note()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("OVERLOOK_PHONE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(condition: Callable, timeout_seconds: float) -> void:
	var waited: float = 0.0
	while not condition.call() and waited < timeout_seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


func _action(action_name: String) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event


func _prompt() -> String:
	return tr(phone.interactable.get_prompt_text())


func _stage(stage: int) -> bool:
	return phone.stage == stage


## Looks at the booth from two metres and asks the interaction ray what it finds.
func _face_booth() -> void:
	player.global_position = Vector3(0.0, 1.05, 2.2)
	player.movement_controller.look_yaw = 0.0
	await _wait(0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.interaction_controller.update_state(false, false)


## Presses E at the booth in the world and waits until she is looking at the unit.
func _walk_up_and_look() -> void:
	phone.interactable.interact(player)
	await _until(func() -> bool: return _stage(OverlookPhoneSequence.Stage.VIEWING), 12.0)
	await _wait(0.9)


func _hint_text() -> String:
	return phone._prompt._text_label.text if phone._prompt.visible else ""


func _take_fichas_out() -> void:
	for id: String in FICHAS:
		player.consume_inventory_item(id)


# ============================================================
# STEPS
# ============================================================

func _check_layout() -> void:
	var model: OrelhaoModel = phone.model
	_expect(model.plate != null and model.receiver != null and model.cord != null, "the booth has its plate, receiver and cord")
	_expect(model.find_child("Key11", true, false) != null, "the keypad has twelve keys (1-9, *, 0, #)")
	_expect(model.find_child("SlotHousing", true, false) != null and model.find_child("ReturnCup", true, false) != null, "the coin slot and the return cup are there")
	_expect(model.find_child("CradleLeft", true, false) != null, "and the cradle's fork")
	_expect(not model._indicator_on, "the indicator starts red")
	_expect(_stage(OverlookPhoneSequence.Stage.IDLE), "the puzzle starts idle")

	_expect(model.on_hook, "the receiver starts on its hook")
	var hook_world: Vector3 = model.to_global(OrelhaoModel.HOOK_POSITION)
	_expect(model.receiver.global_position.distance_to(hook_world) < 0.01, "at the hook, not hanging")
	_expect(model.receiver.global_basis.y.normalized().y < -0.99, "upside down, as it sits in the cradle")
	_expect(not model.sway_enabled, "so it does not sway")

	var mesh: ArrayMesh = model.cord.mesh as ArrayMesh
	_expect(mesh != null and mesh.get_surface_count() == 1, "joined by a coiled cord")
	var box: AABB = mesh.get_aabb().grow(0.02)
	_expect(box.has_point(model.cord_anchor.global_position) and box.has_point(model.receiver.global_position), "that reaches both ends")

	for id: String in FICHAS:
		_expect(player.has_inventory_item(id), "the playtest starts with %s in the inventory" % id)

	_expect(phone.get_inserted_count() == 0, "no ficha is in the slot yet")
	_expect(phone.get_node("Dressing").find_child("Streetlamp", true, false) != null, "there is a streetlamp")


## No fichas: the booth can only be examined, and Juliana says what she needs. She does
## not even walk up to it.
func _check_without_fichas() -> void:
	_take_fichas_out()
	await _face_booth()
	var controller: PlayerInteractionController = player.interaction_controller
	_expect(controller.current_interactable == phone.interactable, "the player's ray finds the booth")
	_expect(_prompt() == "Examine Orelhão", "with no fichas it only offers 'Examine Orelhão' (%s)" % _prompt())

	var before: Vector3 = player.global_position
	phone.interactable.interact(player)
	await _wait(0.4)
	_expect(CaptionManager.panel.visible and CaptionManager.label.text == "I need some fichas...", "Juliana says 'I need some fichas...' (%s)" % CaptionManager.label.text)
	_expect(not player.view_locked and _stage(OverlookPhoneSequence.Stage.IDLE), "and nothing else happens")
	_expect(player.global_position.distance_to(before) < 0.05, "she stays where she is")
	await _wait(3.0)

	phone._give_fichas_to_player()
	for id: String in FICHAS:
		_expect(player.has_inventory_item(id), "%s is back in the inventory" % id)


## She walks up calmly, looks at the unit and is offered two things; the first ficha goes
## in; with no more fichas on her she is told so and can only step away.
func _check_first_ficha() -> void:
	var player_camera: Camera3D = player.get_node("Head/Camera3D")
	var model: OrelhaoModel = phone.model
	await _face_booth()
	_expect(_prompt() == "Insert ficha 1", "the prompt says 'Insert ficha 1' (%s)" % _prompt())

	var start: Vector3 = player.global_position
	phone.interactable.interact(player)
	await _wait(0.3)
	_expect(_stage(OverlookPhoneSequence.Stage.WALKING), "she first walks up to the booth")
	_expect(not player.view_locked, "on her own feet")
	var speed_seen: Array[float] = [0.0]
	var watcher: Callable = func() -> void:
		while _stage(OverlookPhoneSequence.Stage.WALKING):
			await get_tree().physics_frame
			speed_seen[0] = maxf(speed_seen[0], Vector2(player.velocity.x, player.velocity.z).length())

	watcher.call()
	await _until(func() -> bool: return _stage(OverlookPhoneSequence.Stage.VIEWING), 12.0)
	await _wait(0.9)
	_expect(speed_seen[0] > 0.2 and speed_seen[0] < PlayerMovementController.WALK_SPEED + 0.05, "calmly, at a walk (%.2f m/s)" % speed_seen[0])
	var spot: Vector3 = phone.get_standing_spot()
	_expect(Vector2(player.global_position.x - spot.x, player.global_position.z - spot.z).length() < 0.15, "and she stops at the booth")
	_expect(player.global_position.distance_to(start) > 1.0, "having come closer")
	_expect(_stage(OverlookPhoneSequence.Stage.VIEWING) and player.view_locked, "then she keeps looking at the unit")
	_expect(_hint_text() == "Insert ficha 1", "with 'Insert ficha 1' on offer (%s)" % _hint_text())
	_expect(phone._away_hint._text_label.text == "Step away", "and a way to step away")

	# The others are not on her: after the first goes in she is told, and can only leave.
	for other: String in ["lucas_ficha", "sophia_ficha"]:
		player.consume_inventory_item(other)

	phone._input(_action("interact"))
	await _until(func() -> bool: return phone.get_inserted_count() == 1, 6.0)
	_expect(phone.get_inserted_count() == 1, "[E] puts juliana_ficha in the slot")
	_expect(not player.has_inventory_item("juliana_ficha"), "and it leaves the inventory")
	await _until(func() -> bool: return _stage(OverlookPhoneSequence.Stage.VIEWING), 6.0)
	await _wait(0.5)
	_expect(player.view_locked, "she is still looking at the unit")
	_expect(CaptionManager.label.text == "I need some fichas...", "and she needs more fichas")
	_expect(_hint_text() == "", "so only stepping away is offered")
	var saved: Variant = SaveManager.get_state_value(&"puzzles", &"orelhao_fichas", [])
	_expect(saved is Array and (saved as Array).size() == 1, "the first ficha is remembered (%s)" % str(saved))
	_expect(not model._indicator_on, "the light is still red")

	# Pressing E with nothing to insert does nothing; moving away leaves.
	phone._input(_action("interact"))
	await _wait(0.3)
	_expect(phone.get_inserted_count() == 1 and _stage(OverlookPhoneSequence.Stage.VIEWING), "[E] does nothing without a ficha")
	await _wait(2.5)
	phone._input(_action("down"))
	await _until(func() -> bool: return _stage(OverlookPhoneSequence.Stage.IDLE), 6.0)
	_expect(_stage(OverlookPhoneSequence.Stage.IDLE) and not player.view_locked, "moving away steps back and frees her")
	_expect(get_viewport().get_camera_3d() == player_camera, "her own view is back")
	_expect(phone.get_inserted_count() == 1, "the inserted ficha stays")


## She comes back with the others: [E] again for each one, then the receiver.
func _check_the_rest() -> void:
	var model: OrelhaoModel = phone.model
	phone._give_fichas_to_player()
	await _face_booth()
	_expect(_prompt() == "Insert ficha 2", "back with more, the prompt says 'Insert ficha 2' (%s)" % _prompt())

	await _walk_up_and_look()
	_expect(_hint_text() == "Insert ficha 2", "she looks at the unit and 'Insert ficha 2' is on offer")
	await _check_hint_fades()
	# Hammering [E]: the ficha goes in once, and the second press while it is going in does nothing.
	phone._input(_action("interact"))
	phone._input(_action("interact"))
	phone._input(_action("interact"))
	await _until(func() -> bool: return phone.get_inserted_count() == 2, 6.0)
	await _until(func() -> bool: return _stage(OverlookPhoneSequence.Stage.VIEWING), 6.0)
	await _wait(0.5)
	_expect(phone.get_inserted_count() == 2 and _hint_text() == "Insert ficha 3", "then 'Insert ficha 3' (%s)" % _hint_text())
	_expect(not model._indicator_on, "the light is still red")

	phone._input(_action("interact"))
	await _until(func() -> bool: return phone.get_inserted_count() == 3, 6.0)
	await _until(func() -> bool: return _stage(OverlookPhoneSequence.Stage.VIEWING), 8.0)
	await _wait(0.5)
	_expect(phone.is_payment_complete() and model._indicator_on, "the third turns the indicator green")
	_expect(model.on_hook, "the receiver is still on its hook")
	_expect(_hint_text() == "Pick up Receiver", "and 'Pick up Receiver' is on offer (%s)" % _hint_text())

	# She steps away for a moment: the world prompt now says the same.
	await _wait(1.0)
	phone._input(_action("left"))
	await _until(func() -> bool: return _stage(OverlookPhoneSequence.Stage.IDLE), 6.0)
	await _face_booth()
	_expect(_prompt() == "Pick up Receiver", "from outside the prompt is 'Pick up Receiver' too (%s)" % _prompt())


## The hints' fades must never fight: when the player presses [E] while the hints are still fading in (the call, or the next ficha, begins
## and hides them), they must end hidden. They used to end on screen for ever (the fade-in, 0.25 s, was still going after the fade-out, 0.2 s,
## had finished, and set the alpha back to 1), over the call, and stayed until the scene was left.
func _check_hint_fades() -> void:
	# (At the game's own speed: the old bug depended on frames, and at the test's faster time it did not always show.)
	var scale_before: float = Engine.time_scale
	Engine.time_scale = 1.0
	# (The old bug showed for some gaps and not for others, depending on how many frames the show had run: all of them are tried.)
	var worst_hidden: float = 0.0
	for gap: int in 10:
		phone._prompt.modulate.a = 0.0
		phone._away_hint.modulate.a = 0.0
		phone._refresh_hints()
		for frame: int in gap:
			await get_tree().process_frame

		phone._hide_hints()
		await _wait(0.8)
		worst_hidden = maxf(worst_hidden, maxf(phone._prompt.modulate.a, phone._away_hint.modulate.a))

	_expect(worst_hidden < 0.01, "hiding the hints at any moment while they fade in leaves them hidden (the worst left %.2f)" % worst_hidden)
	# And showing them again while they fade out leaves them shown.
	var worst_shown: float = 1.0
	for gap: int in 10:
		phone._refresh_hints()
		await _wait(0.8)
		phone._hide_hints()
		for frame: int in gap:
			await get_tree().process_frame

		phone._refresh_hints()
		await _wait(0.8)
		worst_shown = minf(worst_shown, phone._away_hint.modulate.a)

	_expect(worst_shown > 0.99, "and showing them while they fade out leaves them shown (the worst left %.2f)" % worst_shown)

	# Outside the view nothing may be left on screen, whatever happened to the fades: the safety net puts it out.
	var stage_before: int = phone.stage
	phone.stage = OverlookPhoneSequence.Stage.CALL
	phone._prompt.modulate.a = 1.0
	phone._away_hint.modulate.a = 1.0
	await _wait(0.3)
	_expect(phone._prompt.modulate.a < 0.01 and phone._away_hint.modulate.a < 0.01, "and a hint left showing outside the view is put out (%.2f)" % phone._prompt.modulate.a)
	phone.stage = stage_before
	phone._refresh_hints()
	await _wait(0.5)
	Engine.time_scale = scale_before


## The call: nothing is shown of the receiver being picked up, the picture cuts to the cinematic shot of the
## town, Sophia speaks, the lamp does not move, the receiver ends up hanging, the view returns to the player.
func _check_call() -> void:
	var model: OrelhaoModel = phone.model
	var lines: Array[String] = []
	var saw_roll: Array[bool] = [false]
	var narrowest_fov: Array[float] = [999.0]
	var cut_at: Array[float] = [-1.0]
	var ending_left: Array[float] = [-1.0]
	var ending_at: Array[float] = [-1.0]
	var call_ended_at: Array[float] = [-1.0]
	var picked_at: Array[float] = [-1.0]
	var saw_listening: Array[bool] = [false]
	var worst_move: Array[float] = [0.0]
	var picked: Array[bool] = [false]
	phone.call_ending.connect(func(left: float) -> void:
		ending_left[0] = left
		ending_at[0] = Time.get_ticks_msec() / 1000.0
	)
	phone.call_finished.connect(func() -> void: call_ended_at[0] = Time.get_ticks_msec() / 1000.0)
	var pick_count: Array[int] = [0]
	var hint_alpha_in_call: Array[float] = [0.0]
	var in_call_time: Array[float] = [0.0]
	phone.receiver_picked_up.connect(func() -> void:
		pick_count[0] += 1
		picked[0] = true
		picked_at[0] = Time.get_ticks_msec() / 1000.0
	)
	var finished: Array[bool] = [false]
	phone.sequence_completed.connect(func() -> void: finished[0] = true)
	var on_hook_pose: Transform3D = model.receiver.global_transform
	var receiver_moved: Array[bool] = [false]
	var eye: Vector3 = model.close_up_camera.global_position

	# The lamp: steady until the voice starts, a scripted flicker then, steady through
	# the call, and a scripted flicker again when it is over.
	var lamp: OverlookPhoneDressing = phone.lamp
	var flickers: Array[String] = []
	var lines_when: Dictionary = {}
	var lowest_in: Dictionary = {}
	var steady_lowest: Array[float] = [1.0]
	var active_kind: Array[String] = [""]
	lamp.flicker_started.connect(func(kind: StringName) -> void:
		flickers.append(String(kind))
		active_kind[0] = String(kind)
		lowest_in[String(kind)] = 1.0
		lines_when[String(kind)] = lines.size()
	)
	lamp.flicker_finished.connect(func(_kind: StringName) -> void: active_kind[0] = "")

	# [E] hammered at the booth: the call starts once.
	for press: int in 6:
		phone.interactable.interact(player)
		await _wait(0.03)

	await _wait(0.3)
	_expect(_stage(OverlookPhoneSequence.Stage.WALKING) or _stage(OverlookPhoneSequence.Stage.BUSY) or _stage(OverlookPhoneSequence.Stage.CALL), "interacting starts the call (stage %d)" % phone.stage)

	var watcher: Callable = func() -> void:
		while not finished[0]:
			await get_tree().process_frame
			var camera: Camera3D = get_viewport().get_camera_3d()
			if phone._in_call_view:
				in_call_time[0] += get_process_delta_time()
				if in_call_time[0] > 0.6:
					hint_alpha_in_call[0] = maxf(hint_alpha_in_call[0], maxf(phone._prompt.modulate.a, phone._away_hint.modulate.a))

			if phone._in_call_view and camera != null:
				if absf(camera.rotation_degrees.z + 5.0) < 1.0:
					saw_roll[0] = true

				narrowest_fov[0] = minf(narrowest_fov[0], camera.fov)

				# A head turn: the eyes stay where they were, only the view swings left.
				worst_move[0] = maxf(worst_move[0], camera.global_position.distance_to(eye))
				var facing: Vector3 = -model.close_up_camera.global_basis.z
				facing.y = 0.0
				facing = facing.normalized()
				var view: Vector3 = -camera.global_basis.z
				view.y = 0.0
				view = view.normalized()
				var turned: float = rad_to_deg(facing.angle_to(view))
				var to_the_left: bool = facing.cross(view).y > 0.0
				var hood: Vector3 = model.to_global(Vector3(-0.3, 1.3, 0.1))
				if (
					to_the_left and turned > 33.0 and turned < 50.0
				):
					saw_listening[0] = true

			if phone._in_call_view and cut_at[0] < 0.0:
				cut_at[0] = Time.get_ticks_msec() / 1000.0

			if phone._in_call_view and not model.receiver.global_transform.is_equal_approx(on_hook_pose):
				receiver_moved[0] = true

			var level: float = lamp.get_lamp_level()
			if active_kind[0] != "":
				lowest_in[active_kind[0]] = minf(float(lowest_in[active_kind[0]]), level)
			else:
				steady_lowest[0] = minf(steady_lowest[0], level)

			if CaptionManager.panel.visible:
				var text: String = CaptionManager.label.text
				if lines.is_empty() or lines[lines.size() - 1] != text:
					lines.append(text)

	watcher.call()
	await _until(func() -> bool: return finished[0], 120.0)

	_expect(picked[0], "the receiver was picked up")
	_expect(finished[0], "the call ends")
	_expect(pick_count[0] == 1, "the receiver was picked up once, however often [E] was pressed (%d)" % pick_count[0])
	_expect(hint_alpha_in_call[0] < 0.01, "and no hint stayed on screen over the call (%.2f)" % hint_alpha_in_call[0])
	_expect(cut_at[0] >= 0.0 and cut_at[0] - picked_at[0] < 0.3, "the picture cuts to the shot at once, no handset animation (%.2f s)" % (cut_at[0] - picked_at[0]))
	_expect(ending_left[0] > 5.0 and (call_ended_at[0] - ending_at[0]) * Engine.time_scale > 5.0 and (call_ended_at[0] - ending_at[0]) * Engine.time_scale < 12.0, "the end of the call is announced ahead of time, for the town's lights (%.1f s left, %.1f game seconds before it finished)" % [ending_left[0], (call_ended_at[0] - ending_at[0]) * Engine.time_scale])
	_expect(not receiver_moved[0], "the receiver is not shown being picked up")
	_expect(saw_listening[0], "the picture became a cutscene of the town (about 40 degrees to the left of the booth, centred on the town), without letterbox bars")
	_expect(worst_move[0] > 0.5 and worst_move[0] < 4.0, "from a camera a little behind and above where she stands (%.2f m away)" % worst_move[0])
	_expect(narrowest_fov[0] < phone.shot_fov - 4.0 and narrowest_fov[0] >= phone.call_zoom_fov - 0.5, "the view slowly pushes in on the city while she listens (field of view down to %.1f from %.1f)" % [narrowest_fov[0], phone.shot_fov])
	_expect(lines.size() == 12, "the call is split into twelve short blocks that appear as it goes (%d)" % lines.size())
	var longest: int = 0
	for line: String in lines:
		longest = maxi(longest, line.length())
	_expect(longest <= 90, "none longer than a line or two of film subtitles (longest %d characters)" % longest)
	var expected: Array[String] = []
	for number: int in 12:
		expected.append("CAPTION_PHONE_%02d" % (number + 1))
	var turn_starts: Array[int] = [0, 4, 7, 9]
	for index: int in mini(lines.size(), expected.size()):
		var prefix: String = "%s: " % tr("CAPTION_SPEAKER_SOPHIA_PHONE") if index in turn_starts else ""
		_expect(lines[index] == prefix + tr(expected[index]), "block %d is %s" % [index + 1, "Sophia's, naming her" if index in turn_starts else "the same turn, no name again"])

	_expect(lines.size() > 0 and lines[0].begins_with("Sophia: Juli... Oh, thank God you called."), "the first line is the warm voice's greeting")
	_expect(lines.size() == 12 and lines[11].contains("Don't go near the wagon!"), "and the last (the desperate voice) warns her off the wagon")
	_expect(lines.size() == 12 and lines[6].contains("Hang up right now!"), "the second turn is the desperate voice too")
	_expect(lines.size() == 12 and lines[8].contains("I miss you"), "and the third the warm one again")
	var voices: Array = []
	var last_voice: String = ""
	for cue: Dictionary in CaptionTracks.get_cues(phone.call_track):
		if cue.has("voice") and String(cue["voice"]) != last_voice:
			last_voice = String(cue["voice"])
			voices.append(last_voice)
	_expect(voices == ["warm", "desperate", "warm", "desperate"], "the voices alternate warm, desperate, warm, desperate (%s)" % str(voices))
	var speakers: Dictionary = {}
	for cue: Dictionary in CaptionTracks.get_cues(phone.call_track):
		if cue.has("speaker"):
			speakers[cue["speaker"]] = true
	_expect(speakers.size() == 1, "both voices are captioned as the same speaker, Sophia")
	_expect(phone._sounds.has(&"disconnect"), "the line has a soft disconnect click ready")

	_expect(flickers.is_empty(), "the street lamp does not move during the call (%s)" % str(flickers))
	_expect(steady_lowest[0] == 1.0, "it burns steadily at full power through it (%.2f)" % steady_lowest[0])
	_expect(not lamp.is_flickering() and lamp.get_lamp_level() == 1.0, "it ends at full power")

	var player_camera: Camera3D = player.get_node("Head/Camera3D")
	_expect(get_viewport().get_camera_3d() == player_camera, "the view is back with the player")
	_expect(not player.view_locked, "who can look again")
	_expect(not CaptionManager.panel.visible, "the subtitles are gone")
	_expect(Time.get_ticks_msec() < player._movement_hold_until_msec, "but cannot walk yet")
	_expect(not phone.interactable.enabled, "the booth has nothing more to offer")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"orelhao_call_done", false)), "the call is remembered")

	await _wait(3.5)
	_expect(not model.on_hook and model.sway_enabled, "the receiver is left off the hook, swaying a little")
	_expect(model.receiver.global_position.y < model.plate.global_position.y - 0.25, "hanging below the unit")
	_expect(model.receiver.global_basis.y.normalized().y > 0.9, "port up, on its cord")
	var box: AABB = (model.cord.mesh as ArrayMesh).get_aabb().grow(0.02)
	_expect(box.has_point(model.cord_anchor.global_position) and box.has_point(model.receiver.global_position), "the cord still joins the outlet to the port")

	phone.release_player()
	_expect(Time.get_ticks_msec() >= player._movement_hold_until_msec, "the player is let go when the next event releases them")


func _check_note() -> void:
	var note: Node = phone.get_node("Orelhao/PayphoneNote")
	_expect(note is Inspectable, "a note is stuck to the booth's side")
	var visual: Node3D = (note as Inspectable).get_visual_node()
	_expect(str(visual.get_meta("readable_text", "")) == "READABLE_OVERLOOK_NOTE", "it is a readable document")
	_expect(tr("READABLE_OVERLOOK_NOTE") == "One ficha for each of us.", "that says 'One ficha for each of us.'")
	GameSettings.set_text_locale("pt_BR", false)
	_expect(tr("READABLE_OVERLOOK_NOTE") == "Uma ficha para cada um de nós.", "and in Portuguese")
	GameSettings.set_text_locale("en", false)


## The lamp burns steadily when nothing asks it to flicker.
func _check_lamp_steady() -> void:
	var lamp: OverlookPhoneDressing = phone.lamp
	_expect(lamp != null, "the sequence knows its streetlamp")
	var lowest: float = 1.0
	var waited: float = 0.0
	while waited < 9.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		lowest = minf(lowest, lamp.get_lamp_level())

	_expect(lowest == 1.0 and not lamp.is_flickering(), "the lamp burns steadily, at full power, with no random flicker (%.2f)" % lowest)


## What a ray from `from` to `to` finds, as the interactable the player would be offered.
func _interactable_hit(from: Vector3, to: Vector3) -> Interactable:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	var current: Node = hit.get("collider") as Node
	while current != null:
		if current is Interactable:
			return current as Interactable

		current = current.get_parent()

	return null


## Looking at the note stuck to the booth offers the note, not the booth's own prompt.
func _check_note_rays() -> void:
	await get_tree().physics_frame
	var note: Inspectable = phone.get_node("Orelhao/PayphoneNote") as Inspectable
	var out: Vector3 = note.global_basis.z.normalized()
	var from_side: Vector3 = note.global_position + out * 0.8
	_expect(_interactable_hit(from_side, note.global_position) == note, "looking at the note offers the note (it can be examined)")
	_expect(note.get_prompt_text() == "PROMPT_INSPECT", "'Examine', not 'Insert ficha'")
	var from_diagonal: Vector3 = note.global_position + out * 0.6 + Vector3(0.0, 0.0, 0.5)
	_expect(_interactable_hit(from_diagonal, note.global_position) == note, "also from a little in front of it")

	var model: OrelhaoModel = phone.model
	_expect(_interactable_hit(model.close_up_camera.global_position, model.plate.global_position) == phone.interactable, "looking at the unit still offers the booth")
