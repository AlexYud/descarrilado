extends Node

## The waiting shed's investigation after the first cinematic (see WaitingShedSequence, "THE INVESTIGATION"): the camcorder's viewfinder (assisted approach, eye lean masked by black, hint with the keys really bound,
## fresh-input exit, reverse lean), the leaves that slide aside, the family's reply (only read: it starts and releases nothing), the token that lies in a real recess behind the shelter, the voluntary tape
## review (Play/Pause/Stop/Rewind/Fast-forward/Close through real input events, the rear segment before the excerpt, exact seeking), the camcorder's own sound, cancelling from any phase, and loading at every
## stage and from older saves. The first cinematic itself is in waiting_shed_smoke_test. Run it as a scene; it quits by itself with a non-zero exit code on failure.
## Durations that are asserted (the lean, the withdrawal, the cue's delay) are measured in GAME time, so the result is the same at any time scale: run it with `-- --scale=1` for a normal-speed check
## (the default is 4, to keep the waits short). It cannot judge the picture, the pace or the readability.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_shed_investigation_smoke"
const PLAYTEST_SCENE_PATH: String = "res://scenes/levels/waiting_shed_playtest.tscn"
const DREAM_SCENE_PATH: String = "res://scenes/cinematics/dream_intro.tscn"

const AUX_NONE: int = 0
const AUX_VIEWFINDER: int = 1
const AUX_REVIEW: int = 2
const AUX_TRANSITION: int = 3

var time_scale: float = 4.0
## The level the checks run in: the small playtest scene, or (`-- --scene=dream`) the real dream intro with the shed where it stands in the game.
var scene_path: String = PLAYTEST_SCENE_PATH
var shed_node_path: String = "WaitingShed"
var test_failed: bool = false
var level: Node = null
var shed: WaitingShedSequence = null
var player: CharacterBody3D = null
var saved_events: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scale="):
			time_scale = clampf(argument.get_slice("=", 1).to_float(), 0.5, 8.0)
		if argument == "--scene=dream":
			scene_path = DREAM_SCENE_PATH
			shed_node_path = "Scenery/WaitingShed"
	print("time scale ", time_scale)
	get_tree().root.size = Vector2i(1280, 720)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	GameSettings.set_captions_enabled(true, false)
	GameSettings.set_text_locale("en", false)

	await _run()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("SHED_INVESTIGATION_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	var only: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.get_slice("=", 1)
	var checks: Array[Array] = [
		["strings", _check_strings_and_assets], ["viewfinder", _check_viewfinder_before_the_cinematic], ["input", _check_viewfinder_input_rules],
		["after", _check_viewfinder_after_the_cinematic], ["creature", _check_leaving_during_the_creature], ["hidden", _check_hidden_means_hidden], ["dressing", _check_ground_dressing],
		["letter", _check_letter_starts_nothing], ["token", _check_token_in_the_recess], ["review", _check_review], ["reviewkey", _check_review_by_key], ["clipping", _check_clipping_reveal], ["rear", _check_rear_handheld], ["seek", _check_seeking],
		["cue", _check_camcorder_cue], ["cancel", _check_cancel_from_every_phase], ["loads", _check_loads_at_every_stage], ["pause", _check_pause_in_the_viewfinder], ["skip", _check_skip_recording],
	]
	for entry: Array in checks:
		if only.is_empty() or only.split(",").has(entry[0]):
			await (entry[1] as Callable).call()


# ============================================================
# SETUP
# ============================================================

func _new_game(flags: Array[StringName]) -> void:
	await _free_level()
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, scene_path, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	for key: StringName in flags:
		SaveManager.set_state_value(&"puzzles", key, true)
	await _load_level()


func _load_level() -> void:
	level = (load(scene_path) as PackedScene).instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	shed = level.get_node(shed_node_path)
	player = level.get_node("Player")
	if scene_path == DREAM_SCENE_PATH:
		# The real dream intro opens with its own cinematic, which holds the camera and the body: it is skipped, as a player would have it over.
		for i: int in 20:
			await get_tree().process_frame
		for node: Node in level.find_children("*", "", true, false):
			if node.has_method("skip_opening"):
				node.call("skip_opening")
				break
		await get_tree().create_timer(1.0, true, false, true).timeout
		player.movement_controller.end_cutscene_camera_control()
		player.cutscene_frozen = false
	Engine.time_scale = time_scale
	# The cast and the blood are built a frame after the level.
	var guard: float = 0.0
	while not shed.footage.is_prepared() and guard < 10.0:
		await get_tree().process_frame
		guard += get_process_delta_time()


func _free_level() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
		level = null
		await get_tree().process_frame
		await get_tree().process_frame
	shed = null
	player = null
	_release_all_keys()


# ============================================================
# STEPS
# ============================================================

## The texts and the one token's identity.
func _check_strings_and_assets() -> void:
	var expected: Dictionary = {
		"ITEM_FAMILY_LETTER_NAME": ["Reply from Emily's Family", "Resposta da família de Emily"],
		"ITEM_FAMILY_LETTER_DESCRIPTION": ["A short reply to Sophia's questions. The edges of the paper are damp.", "Uma resposta curta às perguntas de Sophia. O papel está úmido nas bordas."],
		"READABLE_FAMILY_LETTER": ["Sophia,\n\nEmily doesn't have a sister. I don't know who gave you that tape, but if I were you I wouldn't watch it again, especially the ending. She said it was meant for you.", "Sophia,\n\nA Emily não tem irmã, não sei quem te deu essa fita, mas se eu fosse você não assistiria ela de novo, especialmente o final. Ela disse que era pra você."],
		"ITEM_SOPHIA_FICHA_DESCRIPTION": ["A brass telephone token found in a recess behind the shelter.", "Uma ficha de telefone de latão, encontrada numa reentrância atrás do abrigo."],
		"PROMPT_VIEWFINDER_EXIT": ["Step back", "Afastar-se"],
		"PROMPT_REVIEW_TAPE": ["Review tape", "Revisar fita"],
	}
	for key: String in expected:
		_expect(_translated(key, "en") == (expected[key] as Array)[0] and _translated(key, "pt_BR") == (expected[key] as Array)[1], "%s reads as written, in both languages" % key)
	_expect(_translated("VHS_REVIEW_HINT", "en").contains("{left}") and _translated("VHS_REVIEW_HINT", "pt_BR").contains("{interact}"), "the review's hint names its keys by action, not by letter")
	for key: String in ["VHS_REWIND", "VHS_PLAY", "VHS_PAUSE", "VHS_STOP", "VHS_FORWARD", "VHS_CLOSE"]:
		_expect(_translated(key, "en") != key and _translated(key, "pt_BR") != key, "%s is translated" % key)
	await _new_game([])
	var tokens: Array = shed.find_children("*", "Collectible", true, false).filter(func(n: Node) -> bool: return str(n.get("item_id")) == "sophia_ficha")
	_expect(tokens.size() == 1, "there is exactly one telephone token in the shed")
	_expect(shed.ficha.item_id == "sophia_ficha" and shed.ficha.scene_file_path == "res://scenes/objects/waiting_shed/sophia_ficha.tscn" and OverlookPhoneSequence.FICHA_SCENES["sophia_ficha"] == shed.ficha.scene_file_path, "it is Sophia's own collectible, the one the payphone recognizes")
	_expect(shed.find_children("*", "OpenableContainer", true, false).is_empty(), "no hinged box in the shed")
	_expect(shed.rear_annex != null and shed.rear_annex.is_ancestor_of(shed.ficha), "the token is a child of the rear annex, behind the shelter")
	_expect(shed.ficha.visible and shed.ficha.pickup_enabled and shed.ficha.can_interact(player), "it is a real, visible, ordinary pickup from the start: nothing gates it but where it lies")
	_expect(not ("token_landing" in shed) and not ("shot_token" in shed) and not ("letter_aside" in shed), "(the token's fall, its camera and the letter's aside pose no longer exist)")
	var letter_visual: Node3D = shed.letter.get_node("Visual") as Node3D
	_expect(str(letter_visual.get_meta("inspect_id")) == "shed_family_letter" and str(letter_visual.get_meta("inspect_mode")) == "read" and str(letter_visual.get_meta("readable_text")) == "READABLE_FAMILY_LETTER", "the letter is a world readable with its own inspect id")
	_expect(not shed.letter.visible and not shed.letter.can_interact(player), "and it is not in the world at the start")
	_expect(shed.camcorder_cue_delay_seconds >= 1.2 and shed.camcorder_cue_delay_seconds <= 1.8, "the camcorder's own sound comes 1.2 to 1.8 s after the control (%.2f s)" % shed.camcorder_cue_delay_seconds)
	_expect(shed.viewfinder_enter_seconds >= 1.2 and shed.viewfinder_enter_seconds <= 1.8 and shed.viewfinder_exit_seconds >= 0.4 and shed.viewfinder_exit_seconds <= 0.7, "the lean lasts 1.2 to 1.8 s and the withdrawal 0.4 to 0.7 s")
	_expect(shed.footage.rear_seconds == 8.0 and absf(shed.footage.tape_length() - 70.0) < 0.001 and shed.footage.tape_time_of(0.0) == 0.0 and shed.footage.excerpt_time_of(8.0) == 8.0, "the tape is 70 s: the excerpt is its first 62 s and the rear segment (CALL ME) its last 8 s")
	await _free_level()


## Before the first cinematic: the walk, the lean and the black that hides the cut, the picture from the recording's first viewpoint, the hint, the guard, and the way out (reverse lean).
func _check_viewfinder_before_the_cinematic() -> void:
	await _new_game([&"shelter_clipping_read"])
	var device: ShedCamcorder = shed.camcorder
	var view: Dictionary = shed.get_camcorder_view()
	var stand_local: Vector3 = (view["eye"] as Vector3) - (view["axis"] as Vector3) * 0.6
	var stand: Vector3 = shed.to_global(Vector3(stand_local.x, 1.1, stand_local.z))
	await _ray_finds(device, stand, device.get_head().global_position, "the camcorder (its head), from behind the eyepiece")
	var start_position: Vector3 = player.global_position
	var scripted_before: bool = player.scripted_flashlight
	var run: Dictionary = await _enter_measured(device)
	_expect(bool(run["settled"]), "the viewfinder is reached")
	_expect(bool(run["held"]) and bool(run["never_walked_on_input"]), "using the camcorder holds the player the whole time")
	_expect(float(run["lean"]) >= 1.2 and float(run["lean"]) <= 1.85, "the eye leans to the eyecup for 1.2 to 1.8 s (%.2f s)" % float(run["lean"]))
	_expect(int(run["circle_on_her_view"]) == 0, "her own view is never circled: nothing but black ever covers it before the cut (%d frames with a circle on it)" % int(run["circle_on_her_view"]))
	_expect(float(run["black_before_cut"]) > 0.99 and float(run["black_at_cut"]) > 0.99, "the cut from her eye to the lens happens in full black (%.2f at the cut)" % float(run["black_at_cut"]))
	_expect(int(run["wrong_world_frames"]) == 0, "and from the first frame the picture is seen it is the right one: no frame of the ordinary shelter that then turns into the bloodstained one (%d wrong frames)" % int(run["wrong_world_frames"]))
	_expect(float(run["peer"]) >= shed.viewfinder_peer_seconds * 0.7 and float(run["wander"]) > 0.005, "the lens's picture is peered through in the small round window before it opens (%.2f s, the window moved by %.3f)" % [float(run["peer"]), float(run["wander"])])
	_expect(float(run["max_step"]) < 0.4, "nothing teleports: the largest step between frames is %.2f m" % float(run["max_step"]))
	_expect(float(run["eye_error"]) < 0.02, "her eye ends on the eyecup's marker (%.3f m)" % float(run["eye_error"]))
	var cinema: Camera3D = shed.get_node_or_null("CinemaCamera") as Camera3D
	var shot_a: Transform3D = shed.shot_recording.aimed_transform()
	_expect(cinema != null and get_viewport().get_camera_3d() == cinema, "the view is the scene's camera")
	_expect(cinema.global_position.distance_to(shot_a.origin) < 0.001 and (-cinema.global_basis.z).angle_to(-shot_a.basis.z) < deg_to_rad(0.01), "at the recording's first viewpoint (%.4f m)" % cinema.global_position.distance_to(shot_a.origin))
	_expect(is_equal_approx(cinema.fov, ArchiveVideoOverlay.matched_fov(shed.shot_recording.fov, get_viewport().get_visible_rect().size)), "with the lens matched to the picture's 4:3 frame, as the recording has it (%.2f degrees)" % cinema.fov)
	var overlay: ArchiveVideoOverlay = shed.get("_overlay") as ArchiveVideoOverlay
	_expect(overlay != null and overlay.is_picture_shown() and overlay.get_label_text() == shed.viewfinder_label, "through the 4:3 picture, with the camera's own word on it")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT and not shed.camcorder.visible and shed.effects_root.visible, "it shows the ordinary shelter (the device itself is not in the picture)")
	_expect(not shed.footage.visible and not shed.footage.is_blood_view() and (shed.footage.trail == null or not shed.footage.trail.visible) and not shed.footage.aftermath.is_visible_in_tree(), "no blood and no trail")
	_expect(not shed.archive_foreground.visible and not shed.archive_dressing.visible and shed.replaced_plank.visible, "no actor, no ferns, the present's plank")
	var fill: Node = device.find_child("FillLight", true, false)
	_expect(fill == null, "the camcorder has no fill light of its own (it is hidden by planting, not by a beacon)")
	var prompt: KeyHint = shed.get_node("ViewfinderPrompt/Root/Exit") as KeyHint
	_expect(prompt != null and shed.get_node("ViewfinderPrompt").visible and str(prompt.get("_key_label").text) == "WASD" and str(prompt.get("_text_label").text) == "Step away", "the exit hint is the payphone's: a cap with the four movement keys and the words 'Step away' (%s, %s)" % [str(prompt.get("_key_label").text), str(prompt.get("_text_label").text)])
	_expect(prompt.global_position.x > get_viewport().get_visible_rect().size.x * 0.5 and prompt.global_position.y > get_viewport().get_visible_rect().size.y * 0.85, "at the bottom right, where the payphone has it")
	_expect(not shed.get_node("VhsReviewUi" if shed.has_node("VhsReviewUi") else "ViewfinderPrompt") is VhsReviewUi, "the tape's transport row is not part of the viewfinder")
	await _wait(4.0)
	_expect(not bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)) and not shed.letter.visible, "looking for long enough shows nothing and unlocks nothing before the first cinematic")
	_expect(not device.viewfinder_enabled and not device.can_interact(player), "(the device offers nothing while it is in use)")

	var leave: Dictionary = await _leave_measured(&"down")
	_expect(bool(leave["done"]), "a fresh movement key steps back")
	_expect(float(leave["lean"]) >= 0.4 and float(leave["lean"]) <= 0.72, "the eye comes back from the eyecup in 0.4 to 0.7 s (%.2f s)" % float(leave["lean"]))
	_expect(bool(leave["black_before_world"]), "the picture has closed to the small round hole before the ordinary world is shown again")
	_expect(int(shed.get("_aux_mode")) == AUX_NONE and not player.view_locked and not player.manual_save_blocked, "the control is back")
	_expect(get_viewport().get_camera_3d() == player.movement_controller.camera and (shed.get_node_or_null("CinemaCamera") == null or shed.get_node("CinemaCamera").is_queued_for_deletion()), "the player's own camera is current again")
	_expect(overlay == null or not is_instance_valid(overlay) or not overlay.visible, "the picture is gone")
	_expect(shed.camcorder.visible and shed.effects_root.visible and shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT, "the ordinary world is whole")
	_expect(Vector2(player.global_position.x - stand.x, player.global_position.z - stand.z).length() < 0.8 and player.scripted_flashlight == scripted_before and is_zero_approx(player.movement_controller.scripted_fov), "the flashlight scripting and the lens are as they were")
	_expect(player.movement_controller.gesture_offset.length() < 0.001, "her head is back where it was (no leftover lean)")
	var forward: Vector3 = -player.movement_controller.camera.global_basis.z
	var lens_axis: Vector3 = shed.global_transform.basis * (shed.get_camcorder_view()["axis"] as Vector3)
	_expect(Vector2(forward.x, forward.z).normalized().dot(Vector2(lens_axis.x, lens_axis.z).normalized()) > 0.97, "she keeps looking the way the lens looked: no turning about to face where she stood before (%.1f degrees off the lens axis)" % rad_to_deg(Vector2(forward.x, forward.z).angle_to(Vector2(lens_axis.x, lens_axis.z))))
	_expect(device.viewfinder_enabled and not shed.get_node("ViewfinderPrompt").visible, "it can be used again, and the exit hint is gone")
	_expect(Vector2(start_position.x - stand.x, start_position.z - stand.z).length() < 0.01, "(she began behind the eyepiece)")

	# From the lens side the approach goes round the tripod: no teleport, no walking through the device.
	player.global_position = shed.to_global(Vector3(-2.05, 1.1, 0.59))
	player.velocity = Vector3.ZERO
	await _settle_player()
	await _wait(1.2)
	var round_trip: Dictionary = await _enter_measured(device)
	_expect(bool(round_trip["settled"]) and float(round_trip["max_step"]) < 0.4, "from the lens side she walks round to the back (largest step %.2f m)" % float(round_trip["max_step"]))
	_expect(float(round_trip["closest_to_body"]) > 0.25, "and does not walk through the device (closest %.2f m)" % float(round_trip["closest_to_body"]))
	await _leave_measured(&"up")
	var forward_2: Vector3 = -player.movement_controller.camera.global_basis.z
	_expect(Vector2(forward_2.x, forward_2.z).normalized().dot(Vector2(lens_axis.x, lens_axis.z).normalized()) > 0.97, "having come from the lens side too she leaves looking the way the lens looked, not back toward where she came from (%.1f degrees)" % rad_to_deg(Vector2(forward_2.x, forward_2.z).angle_to(Vector2(lens_axis.x, lens_axis.z))))
	await _free_level()


## The viewfinder's input rules: the press that began it, held keys and key repeats do nothing; a fresh press exits; Esc is the pause menu's; an unbound key is not a way out; the hint follows a rebinding.
func _check_viewfinder_input_rules() -> void:
	await _new_game([&"shelter_clipping_read"])
	await _near_camcorder()
	var device: ShedCamcorder = shed.camcorder
	# A movement key held while it is used (and the interaction key that began it) do not step back.
	await _key(&"up", true)
	device.interact(player)
	var settled_at: float = await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	_expect(settled_at >= 0.0, "(the viewfinder was reached with a movement key held)")
	await _wait_real(shed.viewfinder_input_guard_seconds + 0.25)
	await _key(&"up", true, true)
	await _key(&"up", true, true)
	_expect(int(shed.get("_aux_mode")) == AUX_VIEWFINDER, "a key that was already held, and its repeats, do not step back")
	await _key(&"up", false)
	_expect(int(shed.get("_aux_mode")) == AUX_VIEWFINDER, "and neither does releasing it")
	await _key(&"interact", true)
	await _key(&"interact", false)
	_expect(int(shed.get("_aux_mode")) == AUX_VIEWFINDER, "the interaction key is not a way out of the viewfinder")
	# Esc is the pause menu's: the viewfinder does not take it.
	await _esc()
	_expect(int(shed.get("_aux_mode")) == AUX_VIEWFINDER, "Esc does not step back (it is the pause menu's: the menu opens, the viewfinder is untouched)")
	await _unpause_menu()
	_expect(not get_tree().paused and int(shed.get("_aux_mode")) == AUX_VIEWFINDER, "and closing the menu returns to the viewfinder")
	await _key(&"left", true)
	await _key(&"left", false)
	await _wait(shed.viewfinder_exit_seconds + 0.5)
	_expect(int(shed.get("_aux_mode")) == AUX_NONE and not player.view_locked, "a fresh press of another movement key steps back")
	# Nothing steps back through the first instant, either.
	device.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	await _key(&"right", true)
	await _key(&"right", false)
	_expect(int(shed.get("_aux_mode")) == AUX_VIEWFINDER, "a press within the guard's first moments is ignored")
	await _wait_real(shed.viewfinder_input_guard_seconds + 0.25)
	await _key(&"right", true)
	await _key(&"right", false)
	await _wait(shed.viewfinder_exit_seconds + 0.5)
	_expect(int(shed.get("_aux_mode")) == AUX_NONE, "and one after it works")
	_release_all_keys()

	# The hint follows the real bindings (rebound in memory only: the player's settings file is never written).
	var slots: Dictionary = InputBindings.get("_slots") as Dictionary
	var original_slots: Array = (slots[&"up"] as Array).duplicate(true)
	(slots[&"up"] as Array)[0] = {"type": InputBindings.TYPE_KEY, "code": KEY_T}
	InputBindings.call("_apply_action", &"up")
	device.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	var prompt: KeyHint = shed.get_node("ViewfinderPrompt/Root/Exit") as KeyHint
	_expect(str(prompt.get("_key_label").text).begins_with("T"), "rebinding the movement keys changes the hint (%s)" % str(prompt.get("_key_label").text))
	await _wait_real(shed.viewfinder_input_guard_seconds + 0.25)
	await _key(&"up", true)
	await _key(&"up", false)
	await _wait(shed.viewfinder_exit_seconds + 0.5)
	_expect(int(shed.get("_aux_mode")) == AUX_NONE, "and the rebound key is the one that steps back")
	slots[&"up"] = original_slots
	InputBindings.call("_apply_action", &"up")
	_release_all_keys()
	await _free_level()


## After the first cinematic: the empty bloodstained shelter, the broken plank, no actor, the drag trail, no leaves and no letter; a static dressing; three seconds in, the shadow crawls into the picture along the
## trail to the pillar, dies and lies there; it is not seen again (a second look through the lens shows the bloodstained shelter alone), and the reply lies in the real world where it died.
func _check_viewfinder_after_the_cinematic() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	await _near_camcorder()
	var device: ShedCamcorder = shed.camcorder
	_expect(shed.leaf_cover == null or shed.leaf_cover.find_children("Leaves*", "MeshInstance3D", true, false).is_empty(), "there are no leaves over anything: the three leaf sheets are gone")
	_expect(shed.leaf_cover == null or shed.leaf_cover.find_children("*", "MeshInstance3D", true, false).is_empty(), "and no ferns either: nothing grows on the slab by the pillar and the reply")
	var clock_before: float = shed.footage.current_time
	var run: Dictionary = await _enter_measured(device)
	_expect(bool(run["settled"]), "the viewfinder is reached after the first cinematic too")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.VIEWFINDER, "the viewfinder's own look of the shelter")
	var cinema: Camera3D = shed.get_node_or_null("CinemaCamera") as Camera3D
	var shot_a: Transform3D = shed.shot_recording.aimed_transform()
	_expect(cinema != null and cinema.global_position.distance_to(shot_a.origin) < 0.001 and (-cinema.global_basis.z).angle_to(-shot_a.basis.z) < deg_to_rad(0.01), "from the recording's first viewpoint, not the later shot's camera")
	_expect(shed.footage.is_blood_view() and shed.footage.visible and shed.footage.aftermath.visible and not shed.footage.marina.visible and not shed.footage.litter.visible and not shed.footage.litter2.visible, "the blood is shown, nobody is (Emily is hidden, no litter)")
	_expect(shed.footage.trail != null and shed.footage.trail.visible and shed.footage.trail.get_child_count() >= 5, "and so is the drag trail (%d pieces)" % (shed.footage.trail.get_child_count() if shed.footage.trail != null else 0))
	var stains_shown: int = 0
	var cracked_pillar_stains: int = 0
	for stain: Node in shed.footage.aftermath.get_children():
		if (stain as Node3D).visible:
			stains_shown += 1
		if String(stain.name) in ["Smear", "PillarEast"] and (stain as Node3D).visible:
			cracked_pillar_stains += 1
	_expect(stains_shown >= 8 and cracked_pillar_stains == 0, "the pool, the seat, the bench's stains and the pillar's foot are in (%d); the recording's own smear gives way to the drag trail" % stains_shown)
	_expect(not shed.effects_root.visible and not shed.camcorder.visible and not shed.archive_foreground.visible and not shed.replaced_plank.visible, "no belongings, no camcorder, no ferns")
	var damaged: Node3D = shed.archive_dressing.get_node("Damaged") as Node3D
	var intact: Node3D = shed.archive_dressing.get_node("Intact") as Node3D
	_expect(shed.archive_dressing.visible and damaged.visible and not intact.visible, "and the bench's plank is the broken one")
	_expect(shed.footage.current_time == clock_before and not bool(shed.get("_footage_playing")), "there is no clock: the source is not playing, the footage's time did not move")
	_expect(not shed.letter.visible and not shed.letter.can_interact(player), "no letter is in the picture, and none is in the world yet")
	_expect(shed.rear_annex.visible, "the rear annex (with the token) is part of the shelter in the viewfinder too, but out of the lens's cone")
	var creature: ShadowCrawler = shed.get("_creature") as ShadowCrawler
	_expect(creature == null or not creature.visible, "nothing is in the picture at first")
	# Three seconds of the empty picture, then it crawls in.
	var waited: float = 0.0
	while (shed.get("_creature") == null or not (shed.get("_creature") as ShadowCrawler).visible) and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	creature = shed.get("_creature") as ShadowCrawler
	_expect(creature != null and creature.visible and waited >= shed.viewfinder_read_seconds - 0.45 and waited <= shed.viewfinder_read_seconds + 0.9, "three seconds into the picture the creature comes (%.2f s)" % waited)
	_expect(not bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)) and not shed.letter.visible, "merely coming into the picture does not count as having been seen, and there is no letter in the picture")
	# Its crawl: it is there from the first frame, beside the pillar where the reply lies, and crawls at the pace of the animation toward the right of the picture and a little toward the lens; in the middle of it the camera fails and
	# the shadow strobes like a ghost; and under a burst of static it is gone, with nothing left behind.
	var end_point: Vector3 = shed.to_global(shed.creature_path[shed.creature_path.size() - 1])
	var start_point: Vector3 = shed.to_global(shed.creature_path[0])
	var start_head: Vector3 = creature.head_world()
	_expect(creature.global_position.distance_to(start_point) < 0.5, "it starts at the beginning of the path (%.2f m from it)" % creature.global_position.distance_to(start_point))
	_expect(_in_picture(cinema, start_head) and start_head.distance_to(shed.letter.global_position) < 1.0, "it shows beside the pillar where the reply lies (%.2f m from it)" % start_head.distance_to(shed.letter.global_position))
	var way: Vector3 = (end_point - start_point)
	way.y = 0.0
	way = way.normalized()
	var cam_right: Vector3 = cinema.global_basis.x
	var cam_toward: Vector3 = cinema.global_basis.z
	cam_right.y = 0.0
	cam_toward.y = 0.0
	_expect(way.dot(cam_right.normalized()) > 0.8 and way.dot(cam_toward.normalized()) > 0.1 and way.dot(cam_toward.normalized()) < 0.6, "it crawls toward the right of the picture and a little toward the camera, not along the shed (%.2f to the right, %.2f toward the lens)" % [way.dot(cam_right.normalized()), way.dot(cam_toward.normalized())])
	var overlay: ArchiveVideoOverlay = shed.get("_overlay") as ArchiveVideoOverlay
	var material: ShaderMaterial = overlay.get("_material") as ShaderMaterial
	var frames: int = 0
	var spent: float = 0.0
	var worst_glitch: float = 0.0
	var worst_static: float = 0.0
	var seen_solid: int = 0
	var seen_gone: int = 0
	var seen_faded: int = 0
	var glitch_before: float = 0.0
	var darkest: float = 0.0
	var travelled: float = 0.0
	var last_position: Vector3 = creature.global_position
	while creature.playing and spent < 25.0:
		await get_tree().process_frame
		spent += get_process_delta_time()
		frames += 1
		travelled += creature.global_position.distance_to(last_position)
		last_position = creature.global_position
		worst_glitch = maxf(worst_glitch, _number(material, &"glitch"))
		worst_static = maxf(worst_static, _number(material, &"burst"))
		var alpha: float = creature.ghost_alpha_at(creature.elapsed)
		if creature.elapsed < creature.lead_seconds - 0.35:
			glitch_before = maxf(glitch_before, _number(material, &"glitch"))
		darkest = maxf(darkest, _number(material, &"dim"))
		if alpha > 0.9:
			seen_solid += 1
		elif alpha > 0.1:
			seen_faded += 1
		else:
			seen_gone += 1
	_expect(glitch_before > 0.1, "the picture goes wrong before the shadow shows (%.2f of failing with nothing in it)" % glitch_before)
	_expect(darkest > 0.9, "and the light fails altogether in the scene (%.2f dark at the worst)" % darkest)
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)), "watched through, it counts as seen (written down)")
	_expect(spent > shed.creature_crawl_seconds - 1.0 and spent < shed.creature_crawl_seconds + 1.0, "the whole of it takes about %.1f s (%.1f s)" % [shed.creature_crawl_seconds, spent])
	_expect(worst_glitch > 0.3 and worst_static >= 0.99, "in the middle of the crawl the camera fails (tearing %.2f at worst, static %.2f at its worst)" % [worst_glitch, worst_static])
	_expect(seen_solid > 15 and seen_faded >= 1 and seen_gone > 2, "the shadow is whole and readable for most of its crawl and only stutters in the spikes: whole %d frames, faded %d, not yet or no longer there %d" % [seen_solid, seen_faded, seen_gone])
	_expect(travelled > 0.5 and travelled < 1.1, "it crawled about as far as the animation takes it, and stops short (%.2f m)" % travelled)
	_expect(not creature.visible and not creature.playing and not creature.is_dead, "and it is gone: nothing lies there, nothing is left of it")
	await _wait(0.6)
	_expect(_number(material, &"glitch") == 0.0 and _number(material, &"burst") == 0.0 and _number(material, &"dim") == 0.0, "the picture is clean and the light normal again, with nothing in it")
	_expect(shed.get_node_or_null("GlitchNoise") == null and shed.get_node_or_null("GlitchDrone") == null, "and nothing is added to the sound: the camera's failing is silent")
	_expect(creature.global_position.distance_to(end_point) < 0.35, "(it had crawled to the end of its path: %.2f m from it)" % creature.global_position.distance_to(end_point))
	# A look away and back: the creature is not replayed.
	var leave: Dictionary = await _leave_measured(&"up")
	_expect(bool(leave["done"]) and creature != null and not creature.visible, "stepping back takes it out of the world at once")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT and shed.effects_root.visible and shed.camcorder.visible and shed.replaced_plank.visible and not shed.archive_dressing.visible, "the ordinary shelter is whole again: no creature in the real world")
	_expect(not shed.footage.visible and not shed.footage.is_blood_view() and not shed.footage.aftermath.is_visible_in_tree() and not shed.footage.trail.is_visible_in_tree(), "no blood and no trail in the ordinary view")
	for stain: Node in shed.footage.aftermath.get_children():
		_expect((stain as Node3D).visible, "(the recording's own stain %s is back as the recording has it)" % stain.name)
	_expect(shed.clipping.global_transform.is_equal_approx(shed.clipping_aside.global_transform) and shed.vhs.global_transform.is_equal_approx(shed.vhs_set_down.global_transform), "the props are where the new layout has them, not at an old default")
	_expect(shed.letter.visible and shed.letter.can_interact(player) and shed.letter.global_position.distance_to(start_head) < 1.0, "the reply lies in the real world where the shadow began, by the pillar (%.2f m from it)" % shed.letter.global_position.distance_to(start_head))
	_expect(shed.letter.mark_notice_distance >= 10.0, "its mark is seen from far: %.0f m" % shed.letter.mark_notice_distance)
	# From where the camcorder stands, ten metres away, the player sees its mark.
	var view: Dictionary = shed.get_camcorder_view()
	var at: Vector3 = (view["eye"] as Vector3) - (view["axis"] as Vector3) * 0.6
	var seen_from_far: Array = []
	player.global_position = shed.to_global(Vector3(at.x, 1.1, at.z))
	player.velocity = Vector3.ZERO
	await _settle_player()
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var to_letter: Vector3 = shed.letter.global_position - camera.global_position
	player.movement_controller.look_yaw = -rad_to_deg(atan2(-to_letter.x, -to_letter.z))
	player.movement_controller.look_pitch = -rad_to_deg(atan2(to_letter.y, Vector2(to_letter.x, to_letter.z).length()))
	for i: int in 6:
		await get_tree().physics_frame
	seen_from_far = player.interaction_controller.reticle.call("_scan", false)
	_expect(seen_from_far.has(shed.letter), "from the camcorder's stand, %.1f m away, the reply's interaction mark shows" % camera.global_position.distance_to(shed.letter.global_position))
	# A second look through the lens: the bloodstained shelter alone.
	device.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	await _wait(shed.viewfinder_read_seconds + 2.0)
	_expect(not creature.visible and not creature.playing, "looking through the lens again shows no creature (it is not replayed)")
	_expect(shed.footage.is_blood_view() and shed.get_world_state() == WaitingShedSequence.WorldState.VIEWFINDER and not shed.letter.visible, "only the bloodstained shelter, and no letter in the picture")
	await _leave_measured(&"down")
	_expect(int(shed.get("_aux_mode")) == AUX_NONE, "(and it is left again)")
	await _free_level()


## Leaving the lens before the creature has been watched: it is gone at once, it does not count as seen, the reply is not in the world, and the next look shows it again; watched long enough, leaving then puts the reply in the world.
func _check_leaving_during_the_creature() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	await _near_camcorder()
	shed.camcorder.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	var guard: float = 0.0
	while (shed.get("_creature") == null or not (shed.get("_creature") as ShadowCrawler).playing) and guard < shed.viewfinder_read_seconds + 3.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	var creature: ShadowCrawler = shed.get("_creature") as ShadowCrawler
	await _wait(1.5)
	_expect(creature != null and creature.playing and not creature.is_dead, "the creature is crawling")
	shed.call("_exit_viewfinder")
	await _wait(2.0)
	_expect(not creature.visible and not creature.playing, "stepping back takes it out of the picture and the world at once")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT and not shed.footage.visible, "the ordinary view is back, with no blood")
	_expect(not bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)) and not shed.letter.visible and not shed.letter.can_interact(player), "it was not watched through, so it does not count as seen and the reply is not in the world")
	_expect(not player.view_locked and int(shed.get("_aux_mode")) == AUX_NONE, "and nobody is held")
	# The next look shows it again, from the beginning.
	shed.camcorder.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	guard = 0.0
	while not creature.playing and guard < shed.viewfinder_read_seconds + 3.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	_expect(creature.playing and creature.elapsed < 1.0, "the next look shows it again from the beginning (%.2f s in)" % creature.elapsed)
	await _wait(shed.creature_seen_after_seconds + 1.0)
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)), "watched for %.0f s it counts as seen" % shed.creature_seen_after_seconds)
	shed.call("_exit_viewfinder")
	await _wait(2.0)
	_expect(not creature.visible and shed.letter.visible and shed.letter.can_interact(player), "and then the reply is in the world")
	# Leaving before it has come: nothing was seen, nothing is in the world.
	await _free_level()
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	await _near_camcorder()
	shed.camcorder.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	await _wait(0.8)
	shed.call("_exit_viewfinder")
	await _wait(2.0)
	_expect(not bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)) and not shed.letter.visible, "stepping back before it comes leaves the reply out of the world: it was not seen")
	await _free_level()


## Until the creature has been seen, nothing of the reply can be found: no prompt, no ray target, no mark, nothing in sight.
func _check_hidden_means_hidden() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	_expect(not shed.letter.visible and not shed.letter.can_interact(player) and not shed.letter.interaction_enabled, "the reply is not in the world and offers nothing")
	var letter_shape: CollisionShape3D = shed.letter.get_node("InteractArea/CollisionShape3D") as CollisionShape3D
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(letter_shape.disabled, "and its interaction shape is off")
	var found_early: bool = false
	for spot: Vector3 in [Vector3(-5.0, 0.0, -2.45), Vector3(-4.2, 0.0, -2.6), Vector3(-6.5, 0.0, -3.0), Vector3(-5.3, 0.0, -4.9)]:
		for aim: Vector3 in [shed.letter.global_position, shed.letter.global_position + Vector3(0.0, 0.1, 0.0)]:
			if await _ray_target(shed.to_global(spot), aim) == shed.letter:
				found_early = true
	_expect(not found_early, "no ray from the places around the pillar's foot finds it")
	var marks: Array = player.interaction_controller.reticle.call("_scan", false)
	_expect(not marks.has(shed.letter), "and no interaction mark shows it, close to the pillar")
	await _free_level()


## The ground and the plants of the clearing, and the thicket round the camcorder with its path.
func _check_ground_dressing() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	await _wait(1.5)
	var dressing: ShedGroundDressing = shed.ground_dressing as ShedGroundDressing
	_expect(dressing != null and dressing.visible, "the clearing has its dressing in the present")
	var total: int = 0
	for kind: String in dressing.plants_placed:
		total += int(dressing.plants_placed[kind])
	_expect(total >= 380 and dressing.plants_placed.size() >= 8, "plants of %d kinds, %d of them" % [dressing.plants_placed.size(), total])
	_expect(dressing.thicket_count >= 120, "%d of them in the thicket round the camcorder" % dressing.thicket_count)
	_expect(dressing.patches_made >= 25 and dressing.rocks_made >= 5, "%d patches of ground (moss, humus, pine needles, the path's earth) and %d rocks" % [dressing.patches_made, dressing.rocks_made])
	# The patches of ground follow the terrain (it rises half a metre toward the west and north edges of the clearing: a flat plane there is cut by it and shows as a straight line), and are drawn in a fixed order
	# (patches that overlap are never re-sorted by the camera's distance, which made them change as the player moved).
	var priorities: Dictionary = {}
	var patch_count: int = 0
	var buried: int = 0
	var floating: int = 0
	var vertex_count: int = 0
	for child: Node in dressing.get_children():
		var patch: MeshInstance3D = child as MeshInstance3D
		if patch == null or not (patch.mesh is ArrayMesh):
			continue
		patch_count += 1
		var patch_material: Material = patch.material_override
		priorities[patch_material.render_priority] = int(priorities.get(patch_material.render_priority, 0)) + 1
		var vertices: PackedVector3Array = (patch.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex: Vector3 in vertices:
			vertex_count += 1
			var ground: float = dressing._ground_y(Vector2(vertex.x, vertex.z))
			if vertex.y < ground + 0.005:
				buried += 1
			if vertex.y > ground + 0.2:
				floating += 1
	_expect(patch_count >= 25 and priorities.size() == patch_count, "every patch has its own place in the drawing order (%d patches, %d orders)" % [patch_count, priorities.size()])
	_expect(buried == 0 and floating == 0 and vertex_count > 1000, "every point of every patch lies just over the ground under it (%d points, %d under it, %d floating)" % [vertex_count, buried, floating])
	if scene_path == DREAM_SCENE_PATH:
		_expect(dressing._terrain_data != null, "(the real terrain is what they follow)")
		var rise: float = dressing._ground_y(Vector2(-11.0, -11.0)) - dressing._ground_y(Vector2(-4.0, -3.0))
		_expect(rise > 0.15, "where the clearing's ground rises (%.2f m at the north-west corner) the patches rise with it" % rise)
		# The plants of the clearing sway with the wind as the forest's do (the terrain's own wind meshes and materials), and the terrain's low plants under the slab are hidden.
		_expect(dressing._wind != null, "(the level's wind is there)")
		var unmoved: Array[String] = []
		var wind_checked: int = 0
		for holder: Node in dressing.find_children("Plants_*", "MultiMeshInstance3D", true, false):
			var plants: MultiMeshInstance3D = holder as MultiMeshInstance3D
			if String(plants.name) == "Plants_leaves":
				continue
			wind_checked += 1
			var blowing: bool = plants.material_override is ShaderMaterial
			if not blowing and plants.multimesh != null and plants.multimesh.mesh != null:
				for surface: int in plants.multimesh.mesh.get_surface_count():
					blowing = blowing or plants.multimesh.mesh.surface_get_material(surface) is ShaderMaterial
			if not blowing:
				unmoved.append(String(plants.name))
		_expect(wind_checked >= 6 and unmoved.is_empty(), "every kind of plant of the clearing is drawn with a wind material (%d kinds; still: %s)" % [wind_checked, str(unmoved)])
		_expect(dressing.slab_rect.has_area() and dressing.slab_rect.size.x > 7.0 and dressing.slab_rect.size.y > 5.0, "the ground under the slab is hidden from the terrain's plants (%s)" % str(dressing.slab_rect))
		var hide: Variant = dressing._wind.materials[0].get_shader_parameter("hide_rect") if not dressing._wind.materials.is_empty() else null
		_expect(hide is Vector4 and (hide as Vector4).z > (hide as Vector4).x, "and the wind's shader has that rectangle")
	# What is where: nothing stands on the slab, the track, the recess, the stand or the path (from the dressing's own records: a headless run discards a MultiMesh's data).
	var offenders: Array[String] = []
	var thicket_plants: Array[Dictionary] = []
	for record: Dictionary in dressing.plant_records:
		var origin: Vector3 = (record["t"] as Transform3D).origin
		var p: Vector2 = Vector2(origin.x, origin.z)
		if bool(record["thicket"]):
			thicket_plants.append({"t": record["t"], "h": float(record["height"])})
		if String(record["kind"]) == "leaves":
			continue
		if dressing._path_distance(p) < dressing.path_half_width + 0.1 or p.distance_to(dressing.stand_position) < 0.7 or (p.x > -7.4 and p.x < -1.9 and p.y > -8.8 and p.y < -1.5) or p.x > 3.0 or (p.x > -6.6 and p.x < -4.2 and p.y > -10.4 and p.y < -7.0):
			offenders.append("%s %s" % [record["kind"], str(p)])
	_expect(offenders.is_empty(), "nothing grows on the slab, the track, the token's recess, the cameraman's place or the path (%s)" % str(offenders.slice(0, 3)))
	# Nothing of the dressing stands on the shelter's own floor slab, which is wider than the box the old checks used (it reaches 0.3 m east of the shed's origin).
	var on_slab: int = 0
	for record: Dictionary in dressing.plant_records:
		var at: Vector3 = (record["t"] as Transform3D).origin
		if dressing.slab_local.has_point(Vector2(at.x, at.z)):
			on_slab += 1
	_expect(dressing.slab_local.has_area() and dressing.slab_local.size.x > 6.0 and dressing.slab_local.size.y > 4.0 and on_slab == 0, "no plant of the clearing stands on the shelter's floor slab (%s; %d on it)" % [str(dressing.slab_local), on_slab])
	_expect(shed.get_node_or_null("%Shelter/Weed0") == null, "and no weeds grow through the slab")
	_expect(thicket_plants.size() >= 120, "(%d plants counted in the thicket)" % thicket_plants.size())
	# The path: from the slab's corner to the stand, a continuous strip free of plants.
	var points: PackedVector2Array = dressing.path_points
	_expect(points.size() >= 5 and points[0].distance_to(Vector2(-2.2, -1.5)) < 1.0 and points[points.size() - 1].distance_to(dressing.stand_position) < 0.1, "a path leads from the slab's corner to the cameraman's place behind the eyepiece")
	var worst_gap: float = 0.0
	for i: int in points.size() - 1:
		worst_gap = maxf(worst_gap, points[i].distance_to(points[i + 1]))
	_expect(worst_gap < 1.6, "with no gap in it (longest piece %.1f m)" % worst_gap)
	# The camcorder is not seen from the shelter: a plant of the thicket stands in the way from most of the places it could be seen from.
	var head: Vector3 = shed.camcorder.get_head().global_position
	var covered: int = 0
	var viewpoints: Array[Vector3] = [Vector3(-5.0, 1.55, -2.45), Vector3(-4.0, 1.55, -4.8), Vector3(-2.2, 1.55, -2.0), Vector3(0.5, 1.55, -1.0), Vector3(-6.5, 1.55, -1.5)]
	for spot: Vector3 in viewpoints:
		var eye: Vector3 = shed.to_global(spot)
		var blocked: bool = false
		for entry: Dictionary in thicket_plants:
			var t: Transform3D = entry["t"] as Transform3D
			var base: Vector3 = shed.to_global(t.origin)
			var top: float = base.y + float(entry["h"])
			# The plant as an upright cylinder 0.35 m wide, as high as it is: does the sight line cross it?
			var flat: Vector2 = Vector2(eye.x, eye.z)
			var target_flat: Vector2 = Vector2(head.x, head.z)
			var along: float = clampf((Vector2(base.x, base.z) - flat).dot(target_flat - flat) / maxf((target_flat - flat).length_squared(), 0.0001), 0.0, 1.0)
			var closest: Vector2 = flat.lerp(target_flat, along)
			var height_there: float = lerpf(eye.y, head.y, along)
			if closest.distance_to(Vector2(base.x, base.z)) < 0.3 and height_there < top and height_there > base.y and along > 0.05 and along < 0.97:
				blocked = true
				break
		if blocked:
			covered += 1
	_expect(covered >= 1, "the camcorder is hidden from %d of the 5 places it could be seen from (the ones off the lens axis; the lens looks out through a gap)" % covered)
	var tall_in_cone: Array[String] = []
	for record: Dictionary in dressing.plant_records:
		var origin2: Vector3 = (record["t"] as Transform3D).origin
		if String(record["kind"]) != "leaves" and float(record["height"]) > ShedGroundDressing.LOW_PLANT + 0.05 and dressing._in_lens_cone(Vector2(origin2.x, origin2.z), 27.0):
			tall_in_cone.append("%s %.2f at %s" % [record["kind"], float(record["height"]), str(Vector2(origin2.x, origin2.z))])
	_expect(tall_in_cone.is_empty(), "nothing taller than %.1f m stands in the way of the lens (the cone is open, like a gap between the plants) (%s)" % [ShedGroundDressing.LOW_PLANT, str(tall_in_cone.slice(0, 3))])
	await _free_level()


## The family's reply is only read: closing it saves that and starts nothing, releases nothing, moves nothing, holds nobody, and reading it again is the same.
func _check_letter_starts_nothing() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done", &"shelter_leaf_revealed"])
	_expect(shed.letter.visible and shed.letter.can_interact(player), "the exposed letter offers its reading")
	await _ray_finds(shed.letter, shed.to_global(Vector3(-5.0, 0.0, -2.45)), shed.letter.global_position, "the exposed letter")
	var marks: Array = player.interaction_controller.reticle.call("_scan", false)
	_expect(marks.has(shed.letter), "it has its mark")
	var token_before: Transform3D = shed.ficha.global_transform
	var token_visible_before: bool = shed.ficha.visible
	var token_pickup_before: bool = shed.ficha.pickup_enabled
	var token_count_before: int = shed.find_children("*", "Collectible", true, false).filter(func(n: Node) -> bool: return str(n.get("item_id")) == "sophia_ficha").size()
	var start_position: Vector3 = player.global_position
	await _read_and_close(shed.letter)
	var held: bool = false
	var elapsed: float = 0.0
	while elapsed < 3.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		held = held or player.view_locked or int(shed.get("_aux_mode")) != AUX_NONE or get_viewport().get_camera_3d() != player.movement_controller.camera
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_letter_read", false)), "closing the letter remembers that it was read")
	_expect(not held, "and starts nothing: nobody is held, the camera is the player's, for the following 3 s")
	_expect(shed.letter.mark_notice_distance == 0.0, "and once read its mark behaves like every other: the reticle's ordinary distance, not 14 m (%.1f)" % shed.letter.mark_notice_distance)
	_expect(shed.ficha.global_transform.is_equal_approx(token_before) and shed.ficha.visible == token_visible_before and shed.ficha.pickup_enabled == token_pickup_before, "the token is exactly as it was: not moved, not shown, not released")
	_expect(shed.find_children("*", "Collectible", true, false).filter(func(n: Node) -> bool: return str(n.get("item_id")) == "sophia_ficha").size() == token_count_before, "and not duplicated")
	_expect(player.global_position.distance_to(start_position) < 0.05 and not player.manual_save_blocked, "the player did not move, saving is not blocked")
	_expect(shed.letter.visible and shed.letter.can_interact(player), "the letter stays where it was, readable again")
	await _read_and_close(shed.letter)
	await _wait(1.0)
	_expect(not player.view_locked and int(shed.get("_aux_mode")) == AUX_NONE, "reading it again starts nothing either")
	await _free_level()


## The token lies in a real recess behind the shelter: hidden from the usual places by real geometry (no flag), reachable and taken by an ordinary deliberate approach.
func _check_token_in_the_recess() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done", &"shelter_leaf_revealed", &"shelter_letter_read"])
	var token: Vector3 = shed.ficha.global_position
	_expect(shed.ficha.visible and shed.ficha.pickup_enabled and shed.ficha.can_interact(player), "the token is a plain, enabled pickup")
	var local: Vector3 = shed.to_local(token)
	_expect(absf(local.x + 5.6) < 0.05 and absf(local.z + 7.415) < 0.05 and local.y < 0.12, "it lies at the foot of the wall behind the shelter (%.2f, %.2f, %.2f)" % [local.x, local.y, local.z])
	# Real occlusion from the places a player passes: the interior, the front, the track, the camcorder, the ordinary way round the west and east ends at a distance.
	var far_spots: Array[Vector3] = [
		Vector3(-5.0, 0.0, -2.45), Vector3(-3.5, 0.0, -4.5), Vector3(-7.0, 0.0, -3.0), Vector3(-1.5, 0.0, 1.9), Vector3(-5.3, 0.0, -4.9),
		Vector3(-4.0, 0.0, -6.4), Vector3(-5.6, 0.0, -6.2), Vector3(-7.5, 0.0, -6.5), Vector3(-6.5, 0.0, -9.5), Vector3(-5.6, 0.0, -10.4),
	]
	var seen_from: Array[String] = []
	for spot: Vector3 in far_spots:
		var eye: Vector3 = shed.to_global(spot) + Vector3(0.0, 1.6, 0.0)
		if _sight_clear(eye, token + Vector3(0.0, 0.03, 0.0)):
			seen_from.append(str(spot))
	_expect(seen_from.is_empty(), "no line of sight to it from the ordinary places (%s)" % str(seen_from))
	for spot: Vector3 in far_spots:
		var target: Node = await _ray_target(shed.to_global(spot), token)
		_expect(target != shed.ficha, "the interaction ray finds nothing from %s" % str(spot))
	var marks_far: Array = player.interaction_controller.reticle.call("_scan", false)
	_expect(not marks_far.has(shed.ficha), "and no interaction mark shows it")
	# A deliberate, near approach: some free standing place within reach sees it, and the ordinary pickup works from there. Over the whole ground round the annex (a 0.1 m grid, a standing
	# capsule that fits, an eye 1.6 m up) it is seen from nowhere farther than the interaction ray reaches: the lip hides it from a distance.
	var best: Vector3 = Vector3.INF
	var best_distance: float = 1.0e9
	var farthest_seen: float = 0.0
	var clear_places: int = 0
	var spacing: float = 0.1
	var x: float = -7.6
	while x <= -3.6:
		var z: float = -12.0
		while z <= -7.1:
			var stand: Vector3 = shed.to_global(Vector3(x, 0.0, z))
			var eye2: Vector3 = stand + Vector3(0.0, 1.6, 0.0)
			if _fits_standing(stand) and _sight_clear(eye2, token + Vector3(0.0, 0.03, 0.0)):
				clear_places += 1
				var d: float = Vector2(stand.x - token.x, stand.z - token.z).length()
				farthest_seen = maxf(farthest_seen, eye2.distance_to(token + Vector3(0.0, 0.03, 0.0)))
				if d < best_distance:
					best_distance = d
					best = stand
			z += spacing
		x += spacing
	_expect(clear_places > 0, "there are free places to stand that see it (%d)" % clear_places)
	_expect(farthest_seen <= 3.0, "and none of them is farther than %.2f m (eye to token)" % farthest_seen)
	print("  token sight: %d clear places, nearest stand %.2f m, farthest eye distance %.2f m" % [clear_places, best_distance, farthest_seen])
	# Walking there: from the shelter's front, over standing cells (a 0.2 m grid, the real capsule, no step over 0.3 m), the near approach is reachable; the way round is the player's own, no teleport.
	var route: Dictionary = _walk_route(shed.to_global(Vector3(-4.2, 0.0, -2.6)), best)
	_expect(bool(route["reachable"]), "the ground behind the shelter can be walked to from its front (%d cells, about %.1f m of walking)" % [int(route["cells"]), float(route["length"])])
	print("  rear access: route %.1f m, world x from %.2f to %.2f" % [float(route["length"]), float(route["west_x"]), float(route["east_x"])])
	# Walking that route from the shelter's front, the token comes into sight only at the blind corner: the first standing cell with a clear line to it is within a few metres of it.
	var first_seen: float = -1.0
	for cell: Vector3 in route["path"]:
		if _sight_clear(cell + Vector3(0.0, 1.6, 0.0), token + Vector3(0.0, 0.03, 0.0)):
			first_seen = (cell + Vector3(0.0, 1.6, 0.0)).distance_to(token)
			break
	_expect(first_seen > 0.0 and first_seen <= 2.8, "walking round to it from the front, the token first comes into sight %.2f m away (eye to token), never before the corner" % first_seen)
	if clear_places > 0:
		var found: Node = await _ray_target(best, token + Vector3(0.0, 0.03, 0.0))
		_expect(found == shed.ficha, "the interaction ray finds it from %s (%.2f m away)" % [str(shed.to_local(best)), best_distance])
		var marks_near: Array = player.interaction_controller.reticle.call("_scan", false)
		_expect(marks_near.has(shed.ficha), "and its mark shows there")
		shed.ficha.interact(player)
		_expect(player.has_inventory_item("sophia_ficha") and bool(SaveManager.get_state_value(&"collectibles", &"sophia_ficha", false)), "the token goes in the inventory and is remembered as collected")
		await _wait(0.6)
		player.inspect_controller.close(false)
		player.inventory_ui_controller.close()
		await _wait(0.8)
		_expect(bool(SaveManager.get_state_value(&"puzzles", &"junction_ficha_taken", false)) and not player.view_locked, "closing its view marks the old key the payphone's story reads, and holds nobody")
	await _free_level()


## The voluntary tape review: the physical tape starts it; Space, Left, Right, Down, Interact and the clickable row; the playhead; the rear segment; nothing physical happens because of a frame.
func _check_review() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	_expect(shed.vhs.review_mode and shed.vhs.get_prompt_text() == "PROMPT_REVIEW_TAPE", "after the first cinematic the tape offers a review")
	_expect(shed.get("_review_ui") == null or not (shed.get("_review_ui") as CanvasLayer).visible, "the transport row exists only in the review")
	var flags_before: Dictionary = _flags()
	var letter_before: bool = shed.letter.visible
	shed.vhs.interact(player)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(int(shed.get("_aux_mode")) == AUX_REVIEW and player.view_locked, "the review holds the player")
	var ui: VhsReviewUi = shed.get("_review_ui") as VhsReviewUi
	var overlay: ArchiveVideoOverlay = shed.get("_overlay") as ArchiveVideoOverlay
	_expect(ui != null and ui.visible and overlay != null and overlay.visible, "the transport row and the picture are shown")
	_expect(is_zero_approx(float(shed.get("_review_time"))) and shed.review_counter_text(0.0) == "00:00 / 01:10", "the first visit starts at the start of the tape: 00:00 of 01:10")
	_expect(shed.footage.passage_at(float(shed.get("_review_time"))) == &"A" and shed.footage.marina.visible, "(on Emily's excerpt)")
	_expect(str(shed.get("_review_state")) == "pause" and overlay.get_label_text() == "PAUSE", "paused on it, with the word PAUSE")
	for kind: StringName in [&"rewind", &"play", &"pause", &"stop", &"forward", &"close"]:
		_expect(ui.buttons.has(kind) and (ui.buttons[kind] as Control).tooltip_text != "" and (ui.buttons[kind] as Control).tooltip_text.begins_with("VHS_") == false, "the %s button has a localized tooltip" % kind)
	_expect(ui.hint.text.contains("[Space]") and ui.hint.text.contains("[A]") and ui.hint.text.contains("[D]") and ui.hint.text.contains("[S]") and ui.hint.text.contains("[E]"), "the hint names Space and the keys really bound (%s)" % ui.hint.text)
	await _wait(1.0)
	_expect(is_zero_approx(float(shed.get("_review_time"))), "a paused tape does not move")

	# Space plays at 1x; Space pauses.
	await _key_space()
	_expect(str(shed.get("_review_state")) == "play" and overlay.get_label_text() == "PLAY", "Space plays")
	var t0: float = float(shed.get("_review_time"))
	var spent: float = await _spend(1.0)
	var advanced: float = float(shed.get("_review_time")) - t0
	_expect(absf(advanced - spent) < 0.25, "it plays at normal speed (%.2f s of tape in %.2f s)" % [advanced, spent])
	await _key_space()
	_expect(str(shed.get("_review_state")) == "pause", "Space pauses")
	var paused_at: float = float(shed.get("_review_time"))
	await _wait(0.5)
	_expect(is_equal_approx(float(shed.get("_review_time")), paused_at), "and holds")

	# Held Right fast-forwards at about 10x; releasing holds a frame.
	await _key(&"right", true)
	_expect(str(shed.get("_review_state")) == "ff" and overlay.get_label_text() == "FF", "holding Right fast-forwards")
	t0 = float(shed.get("_review_time"))
	spent = await _spend(1.0)
	var ff: float = float(shed.get("_review_time")) - t0
	_expect(absf(ff - spent * shed.review_search_speed) < 1.5 and shed.review_search_speed >= 8.0 and shed.review_search_speed <= 14.0, "at about 10 times the speed (%.2f s of tape in %.2f s)" % [ff, spent])
	await _key(&"right", false)
	_expect(str(shed.get("_review_state")) == "pause", "releasing it pauses")
	# Held Right winds the tape on across the excerpt's end into the rear segment, which is the last 8 s of the tape (jumped to near the end first: the wind itself is measured above).
	var seen_rear: bool = false
	shed.set("_review_time", shed.footage.length_seconds - 3.0)
	await _key(&"right", true)
	_expect(str(shed.get("_review_state")) == "ff" and overlay.get_label_text() == "FF", "holding Right winds the tape on")
	var guard: float = 0.0
	while float(shed.get("_review_time")) < shed.footage.length_seconds + 2.0 and guard < 12.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	seen_rear = float(shed.get("_review_time")) > shed.footage.length_seconds
	await _key(&"right", false)
	var rear_time: float = float(shed.get("_review_time"))
	_expect(seen_rear and shed.footage.passage_at(rear_time) == &"rear", "winding past the excerpt's end reaches the rear segment (%.2f)" % rear_time)
	_expect(shed.footage.rear_message != null and shed.footage.rear_message.visible and not shed.footage.marina.visible, "the rear wall with its words is in the picture, and nobody")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.RECORDING and shed.rear_annex.visible and shed.rear_annex.get_node("Structure").visible, "with the repaired wall and the recess in the rear annex")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_rear_seen", false)), "seeing the rear segment is remembered")
	var cinema: Camera3D = shed.get_node("CinemaCamera") as Camera3D
	var rear_shot: Transform3D = shed.footage.camera_at(rear_time)["transform"] as Transform3D
	_expect(cinema.global_position.distance_to(rear_shot.origin) < 0.06 and shed.review_counter_text(rear_time).begins_with("01:0"), "from the rear camera, a handheld walk behind the wall; the counter reads tape time (%s, %.3f m from where it should be)" % [shed.review_counter_text(rear_time), cinema.global_position.distance_to(rear_shot.origin)])
	# Winding stops at the tape's end.
	await _key(&"right", true)
	guard = 0.0
	while float(shed.get("_review_time")) < shed.footage.tape_length() - 0.001 and guard < 12.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	await _key(&"right", false)
	_expect(is_equal_approx(float(shed.get("_review_time")), shed.footage.tape_length()) and shed.review_counter_text(shed.footage.tape_length()) == "01:10 / 01:10" and str(shed.get("_review_state")) == "pause", "it stops at the end of the tape (01:10)")
	# Rewinding stops at the tape's start.
	shed.set("_review_time", 3.0)
	await _key(&"left", true)
	guard = 0.0
	while float(shed.get("_review_time")) > 0.001 and guard < 12.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	await _key(&"left", false)
	_expect(is_equal_approx(float(shed.get("_review_time")), 0.0) and shed.review_counter_text(0.0) == "00:00 / 01:10" and str(shed.get("_review_state")) == "pause", "and at the start of the tape (00:00)")

	# Stop keeps the playhead and shows no picture; Space plays on from there.
	await _key_space()
	await _spend(1.5)
	var before_stop: float = 0.0
	await _key(&"down", true)
	await _key(&"down", false)
	before_stop = float(shed.get("_review_time"))
	_expect(str(shed.get("_review_state")) == "stop", "Stop stops")
	_expect(not overlay.is_picture_shown() and overlay.get_label_text() == "STOP", "and shows no picture, with the word STOP")
	await _wait(0.5)
	_expect(is_equal_approx(float(shed.get("_review_time")), before_stop), "nothing moves while stopped")
	await _key_space()
	_expect(str(shed.get("_review_state")) == "play" and overlay.is_picture_shown() and float(shed.get("_review_time")) >= before_stop, "Space plays again from where it stopped")

	# The clickable row, with real mouse events at the buttons' positions.
	await _click(ui.buttons[&"pause"])
	_expect(str(shed.get("_review_state")) == "pause", "the Pause button pauses")
	await _click(ui.buttons[&"play"])
	_expect(str(shed.get("_review_state")) == "play", "the Play button plays")
	await _click(ui.buttons[&"stop"])
	_expect(str(shed.get("_review_state")) == "stop", "the Stop button stops")
	await _press_button(ui.buttons[&"forward"], true)
	_expect(str(shed.get("_review_state")) == "ff", "the Fast-forward button, held, searches")
	await _press_button(ui.buttons[&"forward"], false)
	_expect(str(shed.get("_review_state")) == "pause", "and holds when it is released")
	await _press_button(ui.buttons[&"rewind"], true)
	_expect(str(shed.get("_review_state")) == "rew", "the Rewind button, held, searches back")
	await _press_button(ui.buttons[&"rewind"], false)

	# Nothing physical happened because of any frame of the tape.
	_expect(_flags_equal_except(flags_before, _flags(), [&"shelter_rear_seen", &"shelter_review_playhead"]) and shed.letter.visible == letter_before, "no frame of the tape changed the shed's progress")

	# Close: the playhead is saved, the ordinary world is whole, the control is back.
	var at_close: float = float(shed.get("_review_time"))
	await _wait_real(shed.viewfinder_input_guard_seconds + 0.25)
	await _key(&"interact", true)
	await _key(&"interact", false)
	_expect(int(shed.get("_aux_mode")) == AUX_NONE and not player.view_locked and shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT, "Close leaves the review: the control is back and the ordinary shelter is whole")
	_expect(not ui.visible and not shed.footage.visible and not shed.footage.marina.is_visible_in_tree() and not shed.rear_annex.get_node_or_null("Structure") == null, "the transport row is gone and nobody of the tape remains")
	_expect(get_viewport().get_camera_3d() == player.movement_controller.camera, "the player's own camera is current")
	_expect(is_equal_approx(float(SaveManager.get_state_value(&"puzzles", &"shelter_review_playhead", 999.0)), at_close), "the playhead is saved")
	# It resumes there, with no remembered dialogue and no captions.
	await _wait_real(0.6)
	shed.vhs.interact(player)
	await get_tree().process_frame
	_expect(is_equal_approx(float(shed.get("_review_time")), at_close) and str(shed.get("_review_state")) == "pause", "the next visit resumes at the saved playhead, paused")
	_expect(CaptionManager.get_active_count() == 0 if CaptionManager.has_method("get_active_count") else true, "(no captions)")
	# Esc stays the pause menu's: it does not close the review.
	await _esc()
	_expect(int(shed.get("_aux_mode")) == AUX_REVIEW, "Esc does not close the review (it is the pause menu's)")
	await _unpause_menu()
	await _wait_real(shed.viewfinder_input_guard_seconds + 0.25)
	await _click(ui.buttons[&"close"])
	_expect(int(shed.get("_aux_mode")) == AUX_NONE and not player.view_locked, "the Close button leaves it too")
	await _free_level()




## The review as a player opens and closes it: the interact key pressed at the tape (the interaction controller opens it), and the same key pressed again closes it.
func _check_review_by_key() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	await _ray_finds(shed.vhs, shed.to_global(Vector3(-4.3, 0.0, -4.8)), shed.vhs.global_position, "the tape, from the bench front")
	await _key(&"interact", true)
	await _key(&"interact", false)
	await _wait(0.5)
	_expect(int(shed.get("_aux_mode")) == AUX_REVIEW, "the interact key at the tape opens the review")
	await _wait_real(shed.viewfinder_input_guard_seconds + 0.6)
	await _key(&"interact", true)
	await _key(&"interact", false)
	await _wait(0.5)
	_expect(int(shed.get("_aux_mode")) == AUX_NONE and not player.view_locked, "and the interact key closes it (aux mode %d)" % int(shed.get("_aux_mode")))


## The first reading of the clipping: the paper is set down over the tape, a still shot shows it moved aside by hand, the tape is held in view, and only then is the view hers; cancelled midway nothing is lost.
func _check_clipping_reveal() -> void:
	await _new_game([])
	await _near_bench()
	_expect(not shed.vhs.can_interact(player), "the tape offers nothing while the clipping lies over it")
	var home: Transform3D = shed.clipping.global_transform
	await _read_and_close_without_waiting(shed.clipping)
	_expect(int(shed.get("_aux_mode")) == AUX_TRANSITION and player.view_locked, "closing the clipping takes the player in that very call")
	_expect(not bool(SaveManager.get_state_value(&"puzzles", &"shelter_clipping_read", false)), "nothing is written yet")
	var seen_cinema: bool = false
	var own_eyes: bool = true
	var moved: bool = false
	var lifted: float = 0.0
	var tape_early: bool = false
	var elapsed: float = 0.0
	var camera_look: float = 99.0
	var slide_done_at: float = -1.0
	while int(shed.get("_aux_mode")) != AUX_NONE and elapsed < 20.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		# The whole scene is from her own eyes: no other camera is ever current, and the paper and the tape are in front of her.
		var eyes: Camera3D = player.movement_controller.camera
		if _cinema_is_current() or get_viewport().get_camera_3d() != eyes:
			own_eyes = false
		if slide_done_at < 0.0 and moved:
			seen_cinema = true
			var to_tape: Vector3 = shed.vhs.global_position - eyes.global_position
			camera_look = minf(camera_look, rad_to_deg((-eyes.global_basis.z).angle_to(to_tape)))
		tape_early = tape_early or (shed.vhs.can_interact(player) and not moved)
		if shed.clipping.global_position.distance_to(home.origin) > 0.02:
			moved = true
		lifted = maxf(lifted, shed.clipping.global_position.y - home.origin.y)
		if slide_done_at < 0.0 and shed.clipping.global_transform.is_equal_approx(shed.clipping_aside.global_transform):
			slide_done_at = elapsed
	var held_after_slide: float = elapsed - slide_done_at if slide_done_at >= 0.0 else 0.0
	_expect(own_eyes, "the scene is seen from the player's own eyes: no other camera takes the view")
	_expect(seen_cinema and camera_look < 30.0, "and the tape is in front of her as the paper slides (%.1f degrees off her line of sight at best)" % camera_look)
	_expect(not tape_early, "the tape was not offered before the paper was moved")
	_expect(moved and lifted > 0.005 and lifted < 0.06, "the paper was lifted a little (%.3f m) and slid" % lifted)
	_expect(held_after_slide >= shed.clipping_hold_seconds * 0.7, "and the tape is held in view for a moment after (%.1f s)" % held_after_slide)
	_expect(shed.clipping.global_transform.is_equal_approx(shed.clipping_aside.global_transform) and bool(SaveManager.get_state_value(&"puzzles", &"shelter_clipping_read", false)), "the paper lies aside and the stage is saved")
	_expect(shed.vhs.can_interact(player) and not player.view_locked and get_viewport().get_camera_3d() == player.movement_controller.camera, "the tape is offered, the control and the player's camera are back")
	await _free_level()
	# Cut short in the middle of the slide: the paper is aside, the stage saved, nobody held.
	await _new_game([])
	await _near_bench()
	var home_cut: Vector3 = shed.clipping.global_position
	await _read_and_close_without_waiting(shed.clipping)
	var waited: float = 0.0
	while shed.clipping.global_position.distance_to(home_cut) < 0.02 and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(0.5)
	shed.call("_abort_aux")
	await get_tree().process_frame
	_expect(_given_back("cut short in the scene") and shed.clipping.global_transform.is_equal_approx(shed.clipping_aside.global_transform) and bool(SaveManager.get_state_value(&"puzzles", &"shelter_clipping_read", false)), "cancelled midway: the paper is aside, the stage is saved, the player is free")
	_expect(shed.vhs.can_interact(player), "and the tape can be used")
	await _free_level()


func _cinema_is_current() -> bool:
	var cinema: Camera3D = shed.get_node_or_null("CinemaCamera") as Camera3D
	return cinema != null and cinema.is_current()


## Opens an item's reading and closes it, and returns at once (what the closing starts is left running).
func _read_and_close_without_waiting(item: Inspectable) -> void:
	item.interact(player)
	var waited: float = 0.0
	while player.inspect_controller.state != PlayerInspectController.InspectState.VIEWING and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(0.4)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()


## Stands the player in front of the bench, where the notes are read.
func _near_bench() -> void:
	player.global_position = shed.to_global(Vector3(-4.3, 1.1, -4.8))
	player.velocity = Vector3.ZERO
	await _settle_player()


## The rear segment is a handheld walk: it shows the words in blood on the wall, then goes down to the token in its recess and has it in view and lit at the end; in the dream intro the plants near the lens
## shrink away and the wind stands still while the tape is held.
func _check_rear_handheld() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	var footage: ShelterFootage = shed.footage
	var wind: Node = shed.call("_wind_node") as Node
	var strength_before: float = float(wind.get("strength")) if wind != null else 0.0
	shed.vhs.interact(player)
	await get_tree().process_frame
	var cinema: Camera3D = shed.get_node("CinemaCamera") as Camera3D
	var words: Vector3 = footage.rear_message.global_position
	var token: Vector3 = shed.ficha.global_position
	var words_in_view: float = 0.0
	var token_in_view: float = 0.0
	var token_seen_from: float = -1.0
	var previous: Vector3 = Vector3.INF
	var max_step: float = 0.0
	var step: float = 1.0 / 12.0
	var t: float = footage.length_seconds + 0.1
	while t <= footage.tape_length():
		shed.call("_apply_footage", t)
		if cinema.is_position_in_frustum(words) and _sight_clear(cinema.global_position, words + Vector3(0.0, 0.0, -0.02)):
			words_in_view += step
		if cinema.is_position_in_frustum(token) and _sight_clear(cinema.global_position, token + Vector3(0.0, 0.03, 0.0)):
			token_in_view += step
			if token_seen_from < 0.0:
				token_seen_from = t - footage.length_seconds
		if previous != Vector3.INF:
			max_step = maxf(max_step, previous.distance_to(cinema.global_position))
		previous = cinema.global_position
		t += step
	_expect(words_in_view >= 3.0, "the words in blood are in view and unobstructed for %.1f s of the 8" % words_in_view)
	_expect(token_in_view >= 1.0 and token_seen_from >= 4.0, "the token is in view over the lip for %.1f s, from %.1f s into the segment" % [token_in_view, token_seen_from])
	_expect(max_step < 0.12, "the camera moves like a hand, never jumps (largest step between frames %.3f m)" % max_step)
	shed.call("_apply_footage", footage.length_seconds + 0.1)
	var start_at: Vector3 = cinema.global_position
	shed.call("_apply_footage", footage.tape_length() - 0.05)
	_expect(start_at.distance_to(cinema.global_position) > 2.0 and cinema.global_position.y < start_at.y, "it walks in from the dark behind the shelter and goes down toward the recess (%.1f m)" % start_at.distance_to(cinema.global_position))
	var lamp: SpotLight3D = shed.get("_shot_light") as SpotLight3D
	_expect(lamp != null and lamp.light_energy > 1.0 and lamp.spot_angle < 30.0, "at the end the camera's lamp is a narrow beam on the token")
	shed.call("_apply_footage", footage.length_seconds + 2.0)
	_expect(lamp.light_energy < 0.05, "and not a wide lamp on the wall earlier (no white hotspot)")
	# The tape's look is the recording's own: on whatever the player's filter option says; and the picture reaches far, fading into the dark, so that nothing pops in out of black.
	var overlay: ArchiveVideoOverlay = shed.get("_overlay") as ArchiveVideoOverlay
	_expect(overlay != null and overlay.force_full_look and is_equal_approx(float((overlay.get("_material") as ShaderMaterial).get_shader_parameter(&"degrade")), 0.85) and float((overlay.get("_material") as ShaderMaterial).get_shader_parameter(&"grain")) > 0.05, "the worn tape look (grain, tracking, bleeding) is on: it does not depend on the player's video filter option (%s)" % str(GameSettings.get_vhs_filter_enabled()))
	_expect(cinema.far >= 100.0, "the tape's camera sees %.0f m (the player's own is 15 and a black cut-off)" % cinema.far)
	var environment: Environment = cinema.environment
	_expect(environment != null and environment.fog_enabled and environment.fog_depth_begin >= 25.0 and environment.fog_depth_end <= cinema.far, "and the distance fades into the dark from %.0f m, ending inside the view (%.0f m)" % [environment.fog_depth_begin if environment != null else 0.0, environment.fog_depth_end if environment != null else 0.0])
	var wind0: Node = shed.call("_wind_node") as Node
	if wind0 != null:
		var material0: ShaderMaterial = (wind0.get("materials") as Array)[0] as ShaderMaterial
		var clearing: Vector4 = material0.get_shader_parameter("clearing_a") as Vector4
		var clearing_end: Vector3 = material0.get_shader_parameter("clearing_b") as Vector3
		_expect(clearing.w > 0.5 and Vector3(clearing.x, clearing.y, clearing.z).distance_to(shed.to_global(footage.rear_key_positions[0])) < 0.05 and clearing_end.distance_to(shed.to_global(footage.rear_key_positions[footage.rear_key_positions.size() - 1])) < 0.05, "the plants within %.1f m of the whole walk are gone from the shot, set once (no plant shrinks as the camera passes)" % clearing.w)
	if wind != null:
		await _key_space()
		await _key_space()
		await _wait(0.8)
		_expect(float(wind.get("strength")) < 0.01, "the wind in the plants stands still while the tape is paused")
		await _key_space()
		await _wait(0.8)
		_expect(is_equal_approx(float(wind.get("strength")), strength_before), "and blows again when it plays")
		await _key(&"down", true)
		await _key(&"down", false)
		await _wait(0.8)
		_expect(float(wind.get("strength")) < 0.01, "and stands still when it is stopped")
		var material: ShaderMaterial = (wind.get("materials") as Array)[0] as ShaderMaterial
		await _wait_real(shed.viewfinder_input_guard_seconds + 0.25)
		await _key(&"interact", true)
		await _key(&"interact", false)
		await _wait(0.6)
		_expect(is_equal_approx(float(wind.get("strength")), strength_before) and (material.get_shader_parameter("clearing_a") as Vector4).w <= 0.0, "leaving the review gives the wind and the plants back")
	await _free_level()


## The picture is an exact function of the playhead: the same time always shows the same thing, whichever way it was reached, across every cut and the prefix boundary.
func _check_seeking() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	shed.vhs.interact(player)
	await get_tree().process_frame
	var cinema: Camera3D = shed.get_node("CinemaCamera") as Camera3D
	var times: Array[float] = [0.0, 5.0, 12.5, 19.96, 20.0, 31.96, 32.0, 45.96, 46.0, 61.9, 62.0, 62.1, 66.0, 70.0]
	var first_pass: Dictionary = {}
	for t: float in times:
		shed.call("_apply_footage", t)
		first_pass[t] = _picture()
	var order: Array[float] = times.duplicate()
	order.reverse()
	var identical: bool = true
	for t: float in order:
		shed.call("_apply_footage", t)
		if not _same_picture(first_pass[t], _picture()):
			identical = false
			print("  differs at ", t)
	_expect(identical, "going back over every time gives the same picture as going forward (14 times, across the end of the excerpt and all three cuts)")
	var shuffled: Array[float] = [31.96, 70.0, 20.0, 62.0, 62.1, 12.5, 46.0, 0.0, 19.96, 61.9, 5.0, 45.96, 32.0, 66.0]
	identical = true
	for t: float in shuffled:
		shed.call("_apply_footage", t)
		if not _same_picture(first_pass[t], _picture()):
			identical = false
	_expect(identical, "and so does jumping about")
	shed.call("_apply_footage", 62.1)
	_expect(shed.footage.passage_at(62.1) == &"rear" and shed.footage.rear_message.visible and not shed.footage.marina.visible, "the frame after the excerpt is the rear segment")
	shed.call("_apply_footage", 62.0)
	_expect(shed.footage.passage_at(62.0) == &"walk2" and not shed.footage.rear_message.visible and not shed.rear_annex.visible, "and the excerpt's last frame is still the dragging walk, with the rear annex gone")
	var last_state: Dictionary = {}
	for t: float in [19.96, 20.0, 31.96, 32.0, 45.96, 46.0]:
		last_state[t] = shed.footage.passage_at(t)
	_expect(last_state[19.96] == &"A" and last_state[20.0] == &"walk" and last_state[31.96] == &"walk" and last_state[32.0] == &"aftermath" and last_state[45.96] == &"aftermath" and last_state[46.0] == &"walk2", "the cuts are where the tape has them (excerpt 20, 32 and 46 s = tape 28, 40 and 54 s)")
	_expect(shed.footage.tape_time_of(20.0) == 20.0 and shed.footage.tape_time_of(32.0) == 32.0 and shed.footage.tape_time_of(46.0) == 46.0, "(the same on the tape's clock)")
	await _free_level()


## The camcorder's own sound: a moment after the control, from the physical device, once; it can be missed, never forces a look, and a use of the device (or a pause) ends it.
func _check_camcorder_cue() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	shed.call("_start_camcorder_cue")
	await _wait(shed.camcorder_cue_delay_seconds * 0.5)
	var early: AudioStreamPlayer3D = shed.camcorder.get_head().get_node_or_null("CueSound") as AudioStreamPlayer3D
	_expect(early == null or not early.playing, "nothing sounds before the delay (%.2f s)" % shed.camcorder_cue_delay_seconds)
	await _wait(shed.camcorder_cue_delay_seconds * 0.5 + 0.3)
	var cue: AudioStreamPlayer3D = shed.camcorder.get_head().get_node_or_null("CueSound") as AudioStreamPlayer3D
	_expect(cue != null and cue.playing, "then the physical camcorder makes its sound")
	_expect(shed.camcorder.get_head().is_ancestor_of(cue), "from the device itself (a 3D source on its head, behind the player)")
	_expect(not player.view_locked and int(shed.get("_aux_mode")) == AUX_NONE and get_viewport().get_camera_3d() == player.movement_controller.camera, "while the player has their view and their control (nothing is forced)")
	await _wait(1.6)
	_expect(cue != null and not cue.playing, "and it stops by itself")
	# Using the device before it sounds cancels it.
	shed.call("_start_camcorder_cue")
	await _wait(0.2)
	shed.camcorder.interact(player)
	await _wait(shed.camcorder_cue_delay_seconds + 1.0)
	cue = shed.camcorder.get_head().get_node_or_null("CueSound") as AudioStreamPlayer3D
	_expect(cue == null or not cue.playing, "a cue that has not sounded is cancelled by using the device")
	await _free_level()


## Cancelling from any phase gives the world and the control back at once: the walk, the lean, the picture, the withdrawal, the review.
func _check_cancel_from_every_phase() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done", &"shelter_leaf_revealed"])
	var device: ShedCamcorder = shed.camcorder
	var view: Dictionary = shed.get_camcorder_view()
	player.global_position = shed.to_global(Vector3(-3.0, 1.1, 0.4))
	player.velocity = Vector3.ZERO
	await _settle_player()
	await _wait(1.2)
	# Phase 1: the walk.
	device.interact(player)
	await _wait(0.35)
	_expect(int(shed.get("_aux_mode")) == AUX_TRANSITION and player.movement_controller.is_guided_walking(), "(in the assisted walk)")
	shed.call("_abort_aux")
	await get_tree().process_frame
	_expect(_given_back("during the walk"), "cancelled during the walk")
	# Phase 2: the lean.
	var stand_local: Vector3 = (view["eye"] as Vector3) - (view["axis"] as Vector3) * 0.6
	player.global_position = shed.to_global(Vector3(stand_local.x, 1.1, stand_local.z))
	await _wait(0.3)
	device.interact(player)
	var guard: float = 0.0
	while player.movement_controller.gesture_offset.length() < 0.01 and guard < 6.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	_expect(player.movement_controller.gesture_offset.length() >= 0.01, "(in the lean)")
	shed.call("_abort_aux")
	await get_tree().process_frame
	_expect(_given_back("during the lean") and player.movement_controller.gesture_offset.length() < 0.001, "cancelled during the lean (the head is back)")
	# Phase 3: the picture.
	device.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	shed.call("_abort_aux")
	await get_tree().process_frame
	_expect(_given_back("in the picture") and not shed.get_node("ViewfinderPrompt").visible and shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT, "cancelled in the picture (the hint is gone, the world is the present's)")
	# Phase 4: the withdrawal.
	device.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	await _wait_real(shed.viewfinder_input_guard_seconds + 0.25)
	await _key(&"up", true)
	await _key(&"up", false)
	await _wait(0.12)
	shed.call("_abort_aux")
	await get_tree().process_frame
	_expect(_given_back("during the withdrawal") and player.movement_controller.gesture_offset.length() < 0.001, "cancelled during the withdrawal")
	# Phase 5: the creature crawling, with the viewfinder left through the tree.
	await _free_level()
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	await _near_camcorder()
	shed.camcorder.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	guard = 0.0
	while (shed.get("_creature") == null or not (shed.get("_creature") as ShadowCrawler).playing) and guard < shed.viewfinder_read_seconds + 3.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	shed.call("_abort_aux")
	await get_tree().process_frame
	_expect(_given_back("during the creature") and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)) and not (shed.get("_creature") as ShadowCrawler).visible, "cancelled while the creature crawls (it was not watched to the end: it is not counted as seen, and it is gone)")
	_expect(not shed.letter.visible and not shed.letter.can_interact(player), "and the reply is not in the world yet")
	# Phase 6: the review.
	shed.vhs.interact(player)
	await get_tree().process_frame
	await _key_space()
	await _spend(0.6)
	var at: float = float(shed.get("_review_time"))
	shed.call("_abort_aux")
	await get_tree().process_frame
	_expect(_given_back("during the review") and not (shed.get("_review_ui") as CanvasLayer).visible and not shed.footage.marina.is_visible_in_tree(), "cancelled during the review (the row is gone, nobody of the tape remains)")
	_expect(is_equal_approx(float(SaveManager.get_state_value(&"puzzles", &"shelter_review_playhead", 999.0)), at), "and the playhead is kept")
	# The scene freed from the viewfinder loads clean.
	shed.camcorder.interact(player)
	await get_tree().process_frame
	await _free_level()
	await _load_level()
	_expect(not player.view_locked and int(shed.get("_aux_mode")) == AUX_NONE and shed.camcorder.can_interact(player), "a scene left from the viewfinder loads clean")
	await _free_level()


## Every stage, saved and loaded; and the older saves.
func _check_loads_at_every_stage() -> void:
	# The creature seen, the reply not read: the reply lies in the world.
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done", &"shelter_leaf_revealed"])
	_expect(shed.letter.visible and shed.letter.can_interact(player) and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_letter_read", false)), "after the creature: the reply lies in the world, not read")
	_expect(shed.ficha.visible and shed.ficha.pickup_enabled, "and the token lies where it always did")
	_expect(shed.clipping.global_transform.is_equal_approx(shed.clipping_aside.global_transform) and shed.vhs.review_mode, "the clipping lies aside and the tape is for review")
	await _free_level()
	# Letter read: nothing changed but the flag.
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done", &"shelter_leaf_revealed", &"shelter_letter_read"])
	_expect(shed.ficha.visible and shed.ficha.pickup_enabled and shed.letter.visible, "after the letter: the token is in its place, the letter is where it was")
	await _free_level()
	# Only the old first-cinematic flag: the camcorder stage; the old box flag proves nothing.
	await _new_game([&"shelter_recording_done", &"junction_switch_box_open"])
	_expect(shed.is_recording_done() and not shed.letter.visible and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_letter_read", false)), "the first-cinematic flag only enables the camcorder stage; nothing is complete")
	_expect(shed.footage.passage_at(float(SaveManager.get_state_value(&"puzzles", &"shelter_review_playhead", 0.0))) == &"A", "(no saved playhead: the review is cued on the excerpt)")
	await _free_level()
	# The old box flag alone: nothing of the new investigation is done.
	await _new_game([&"junction_switch_box_open"])
	_expect(shed.is_recording_done() == (bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false))) and not shed.letter.visible, "the old hinged box's flag alone completes no later stage")
	await _free_level()
	# A save of the previous design: the letter read, the token fallen and not taken. One token, in its recess, free to take; none of the old timers.
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done", &"shelter_leaf_revealed", &"shelter_letter_read"])
	var count: int = shed.find_children("*", "Collectible", true, false).filter(func(n: Node) -> bool: return str(n.get("item_id")) == "sophia_ficha").size()
	_expect(count == 1 and shed.ficha.visible and shed.ficha.pickup_enabled and shed.rear_annex.is_ancestor_of(shed.ficha), "a save from the earlier design loads one token, in the recess behind the shelter")
	await _free_level()
	# The token already collected (in any of the older ways): nothing comes back.
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, scene_path, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.set_state_value(&"collectibles", &"sophia_ficha", true)
	await _load_level()
	_expect(not is_instance_valid(shed.ficha) or shed.ficha.is_queued_for_deletion() or not shed.ficha.is_inside_tree(), "a collected token does not respawn")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_letter_read", false)) and shed.letter.visible, "and every stage counts as resolved (the leaves aside, the letter exposed)")
	await _free_level()
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, scene_path, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.set_state_value(&"puzzles", &"junction_ficha_taken", true)
	await _load_level()
	_expect(shed.is_recording_done() and shed.letter.visible, "a token taken in the older flow also resolves the investigation")
	await _free_level()


## Paused in the viewfinder: the picture stands still; resumed and left.
func _check_pause_in_the_viewfinder() -> void:
	await _new_game([&"shelter_clipping_read", &"shelter_recording_done"])
	await _near_camcorder()
	shed.camcorder.interact(player)
	await _wait_for_mode(AUX_VIEWFINDER, 8.0)
	var cinema: Camera3D = shed.get_node_or_null("CinemaCamera") as Camera3D
	var before: Transform3D = cinema.global_transform
	await _wait(0.5)
	get_tree().paused = true
	await get_tree().create_timer(1.5, true, false, true).timeout
	_expect(cinema.global_transform.is_equal_approx(before) and int(shed.get("_aux_mode")) == AUX_VIEWFINDER and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)), "paused: the view stands still and the hold does not run out")
	get_tree().paused = false
	await _wait(shed.viewfinder_read_seconds)
	_expect(shed.get("_creature") != null and (shed.get("_creature") as ShadowCrawler).visible, "resumed: the hold goes on and the creature comes")
	shed.call("_exit_viewfinder")
	await _wait(0.9)
	_expect(int(shed.get("_aux_mode")) == AUX_NONE and not player.view_locked and not shed.letter.visible, "left before the creature was watched through: nobody is held, and the reply is not in the world yet")
	await _free_level()


# ============================================================
# HELPERS
# ============================================================

func _translated(key: String, locale: String) -> String:
	var translation: Translation = TranslationServer.get_translation_object(locale)
	return str(translation.get_message(StringName(key))) if translation != null else key


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Waits this many seconds of GAME time frame by frame and returns the game time that really passed.
func _spend(seconds: float) -> float:
	var spent: float = 0.0
	while spent < seconds:
		await get_tree().process_frame
		spent += get_process_delta_time()
	return spent


func _wait_for_mode(mode: int, limit: float) -> float:
	var waited: float = 0.0
	while int(shed.get("_aux_mode")) != mode and waited < limit:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return waited if int(shed.get("_aux_mode")) == mode else -1.0


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


func _given_back(what: String) -> bool:
	var camera_ok: bool = get_viewport().get_camera_3d() == player.movement_controller.camera
	var ok: bool = int(shed.get("_aux_mode")) == AUX_NONE and not player.view_locked and not player.manual_save_blocked and camera_ok and not player.movement_controller.is_guided_walking()
	ok = ok and shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT and (shed.get_node_or_null("CinemaCamera") == null or shed.get_node("CinemaCamera").is_queued_for_deletion())
	if not ok:
		print("  (", what, ": mode ", shed.get("_aux_mode"), " locked ", player.view_locked, " camera ok ", camera_ok, ")")
	return ok


## The bound key event of an action (the first keyboard one), as a fresh copy.
func _key_event(action: StringName, pressed: bool, echo: bool = false) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var copy: InputEventKey = (event as InputEventKey).duplicate() as InputEventKey
			copy.pressed = pressed
			copy.echo = echo
			return copy
	return null


## A key press or release as the game gets it from the keyboard (the viewport's `_input` path), and the input state that goes with it.
func _key(action: StringName, pressed: bool, echo: bool = false) -> void:
	var event: InputEventKey = _key_event(action, pressed, echo)
	if event == null:
		_expect(false, "(the %s action has a bound key)" % action)
		return
	if pressed:
		saved_events[action] = true
	else:
		saved_events.erase(action)
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _release_all_keys() -> void:
	for action: StringName in saved_events.keys():
		var event: InputEventKey = _key_event(action, false)
		if event != null:
			Input.parse_input_event(event)
	saved_events.clear()
	Input.flush_buffered_events()


func _key_space() -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_SPACE
	down.keycode = KEY_SPACE
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up: InputEventKey = down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


## A full mouse click on a control, at its centre, through the window's own input path.
func _click(button: Control) -> void:
	await _press_button(button, true)
	await _press_button(button, false)


func _press_button(button: Control, pressed: bool) -> void:
	var centre: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = centre
	motion.global_position = centre
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = centre
	click.global_position = centre
	click.pressed = pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(click)
	await get_tree().process_frame
	await get_tree().process_frame


## Uses the camcorder and watches every frame of the way in (game time): the largest step the body takes, how long the eye leans, the black at the cut, the closest she comes to the device.
func _enter_measured(device: ShedCamcorder) -> Dictionary:
	var movement: PlayerMovementController = player.movement_controller
	var result: Dictionary = {"settled": false, "held": true, "never_walked_on_input": true, "lean": 0.0, "black_at_cut": 0.0, "circle_on_her_view": 0, "peer": 0.0, "wrong_world_frames": 0, "black_before_cut": 0.0, "wander": 0.0, "max_step": 0.0, "eye_error": 1.0, "closest_to_body": 99.0, "yaw_before": movement.look_yaw, "pitch_before": movement.look_pitch}
	var previous: Vector3 = player.global_position
	var lean_started: float = -1.0
	var elapsed: float = 0.0
	var seen_cut: bool = false
	var expected_world: int = WaitingShedSequence.WorldState.VIEWFINDER if bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)) else WaitingShedSequence.WorldState.PRESENT
	var last_black: float = 0.0
	device.interact(player)
	while elapsed < 14.0:
		await get_tree().process_frame
		var step_time: float = get_process_delta_time()
		elapsed += step_time
		result["held"] = bool(result["held"]) and (player.view_locked or movement.is_guided_walking())
		result["max_step"] = maxf(float(result["max_step"]), previous.distance_to(player.global_position))
		previous = player.global_position
		var head: Node3D = device.get_head()
		if head != null:
			result["closest_to_body"] = minf(float(result["closest_to_body"]), Vector2(player.global_position.x - device.global_position.x, player.global_position.z - device.global_position.z).length())
		if lean_started < 0.0 and movement.gesture_direct:
			lean_started = elapsed
		var cinema: Camera3D = shed.get_node_or_null("CinemaCamera") as Camera3D
		var black: float = float(shed.get("_iris_black_alpha"))
		var radius: float = float(shed.get("_iris_radius"))
		if not seen_cut:
			# Her own view is never circled: only black may cover it, and it covers it before the cut.
			if radius < 1.5 and black < 0.99:
				result["circle_on_her_view"] = int(result["circle_on_her_view"]) + 1
			result["black_before_cut"] = maxf(float(result["black_before_cut"]), black)
			last_black = black
		if not seen_cut and cinema != null and cinema.is_current():
			seen_cut = true
			result["black_at_cut"] = black
			result["lean"] = elapsed - lean_started if lean_started >= 0.0 else 0.0
		if seen_cut:
			# After the cut: the picture is what it should be from the first frame it is seen, and the small round window is peered through.
			if black < 0.95 and shed.get_world_state() != expected_world:
				result["wrong_world_frames"] = int(result["wrong_world_frames"]) + 1
			if black < 0.05 and radius < 0.4:
				result["peer"] = float(result["peer"]) + step_time
				result["wander"] = maxf(float(result["wander"]), ((shed.get("_iris_center") as Vector2) - Vector2(0.5, 0.5)).length())
		if int(shed.get("_aux_mode")) == AUX_VIEWFINDER:
			result["settled"] = true
			break
	var eye: Marker3D = device.get_eye_marker()
	if eye != null:
		result["eye_error"] = movement.camera.global_position.distance_to(eye.global_position)
	return result


## Presses a movement key (a fresh press) in the viewfinder and watches the way out: the black before the ordinary world, the time from the camera being hers to the control (the reverse lean).
func _leave_measured(action: StringName) -> Dictionary:
	var result: Dictionary = {"done": false, "lean": 0.0, "black_before_world": true}
	await _wait_real(shed.viewfinder_input_guard_seconds + 0.25)
	var movement: PlayerMovementController = player.movement_controller
	var event_down: InputEventKey = _key_event(action, true)
	var event_up: InputEventKey = _key_event(action, false)
	Input.parse_input_event(event_down)
	await get_tree().process_frame
	Input.parse_input_event(event_up)
	var elapsed: float = 0.0
	var lean_from: float = -1.0
	while elapsed < 6.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if lean_from < 0.0 and get_viewport().get_camera_3d() == movement.camera:
			lean_from = elapsed
			result["black_before_world"] = float(shed.get("_iris_radius")) <= 0.35
		if int(shed.get("_aux_mode")) == AUX_NONE:
			result["done"] = true
			result["lean"] = elapsed - lean_from if lean_from >= 0.0 else 0.0
			break
	await get_tree().process_frame
	return result


## Stands the player at `stand`, aims at `aim`, and returns the interactable the interaction ray ends on (null if none).
func _ray_target(stand: Vector3, aim: Vector3) -> Node:
	player.global_position = Vector3(stand.x, shed.global_position.y + 1.1, stand.z)
	player.velocity = Vector3.ZERO
	await _wait(0.6)
	var camera: Camera3D = player.get_node("Head/Camera3D")
	for pass_number: int in 2:
		var to_aim: Vector3 = aim - camera.global_position
		player.movement_controller.look_yaw = -rad_to_deg(atan2(-to_aim.x, -to_aim.z))
		player.movement_controller.look_pitch = -rad_to_deg(atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length()))
		for i: int in 3:
			await get_tree().physics_frame
	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractRay")
	ray.force_raycast_update()
	var found: Node = ray.get_collider() as Node
	while found != null and not found is Interactable:
		found = found.get_parent()
	return found


func _ray_finds(item: Node, stand: Vector3, aim: Vector3, what: String) -> void:
	var found: Node = await _ray_target(stand, aim)
	var camera: Camera3D = player.get_node("Head/Camera3D")
	_expect(found == item, "the interaction ray reaches %s from %.2f m (hit %s)" % [what, camera.global_position.distance_to(aim), str(found)])


func _read_and_close(item: Inspectable) -> void:
	item.interact(player)
	var waited: float = 0.0
	while player.inspect_controller.state != PlayerInspectController.InspectState.VIEWING and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(0.4)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()


## True when no solid lies between two points (the player's own body ignored; papers and plants have no collision).
func _sight_clear(from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = shed.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	return space.intersect_ray(query).is_empty()


## True when a standing body (a 0.3 m radius capsule) fits at this floor point.
func _fits_standing(floor_point: Vector3) -> bool:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, floor_point + Vector3(0.0, 0.95, 0.0))
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	if not shed.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	# And there is ground under it (not the void past the slab).
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(floor_point + Vector3(0.0, 0.5, 0.0), floor_point + Vector3(0.0, -0.6, 0.0))
	down.exclude = [player.get_rid()]
	return not shed.get_world_3d().direct_space_state.intersect_ray(down).is_empty()


func _flags() -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in [&"shelter_clipping_read", &"shelter_recording_done", &"shelter_leaf_revealed", &"shelter_letter_read", &"shelter_rear_seen", &"shelter_review_playhead", &"junction_ficha_taken"]:
		result[key] = SaveManager.get_state_value(&"puzzles", key, null)
	result["collected"] = SaveManager.get_state_value(&"collectibles", &"sophia_ficha", false)
	return result


func _flags_equal_except(a: Dictionary, b: Dictionary, ignored: Array[StringName]) -> bool:
	for key: Variant in a.keys():
		if key in ignored:
			continue
		if a[key] != b.get(key):
			return false
	return true


## What the picture shows at this moment: the camera, the lens, who is in it, and the dressing.
func _picture() -> Dictionary:
	var cinema: Camera3D = shed.get_node("CinemaCamera") as Camera3D
	return {
		"transform": cinema.global_transform, "fov": cinema.fov,
		"marina": shed.footage.marina.visible, "marina_at": shed.footage.marina.global_position, "aftermath": shed.footage.aftermath.visible,
		"rear": shed.footage.rear_message.visible, "litter": shed.footage.litter.visible, "litter2": shed.footage.litter2.visible,
		"annex": shed.rear_annex.visible, "foreground": shed.archive_foreground.visible, "damaged": (shed.archive_dressing.get_node("Damaged") as Node3D).visible,
	}


func _same_picture(a: Dictionary, b: Dictionary) -> bool:
	for key: Variant in a.keys():
		var x: Variant = a[key]
		var y: Variant = b[key]
		if x is Transform3D:
			if not (x as Transform3D).is_equal_approx(y as Transform3D):
				return false
		elif x is Vector3:
			if not (x as Vector3).is_equal_approx(y as Vector3):
				return false
		elif x is float:
			if not is_equal_approx(float(x), float(y)):
				return false
		elif x != y:
			return false
	return true


func _mesh_bounds_world(node: Node) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var instance: MeshInstance3D = mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		var box: AABB = instance.global_transform * instance.mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


## Stands the player behind the camcorder's eyepiece (where a person who walked up to use it stands), looking at the device.
func _near_camcorder() -> void:
	var view: Dictionary = shed.get_camcorder_view()
	var at: Vector3 = (view["eye"] as Vector3) - (view["axis"] as Vector3) * 0.6
	player.global_position = shed.to_global(Vector3(at.x, 1.1, at.z))
	player.velocity = Vector3.ZERO
	await _settle_player()
	await _wait(1.2)


## Waits real seconds, whatever the time scale (the input guards count in real time, as the player's hands do).
func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## One press and release of Escape (the pause menu's key). If the pause menu opened and paused the game, it is closed again with a second one.
func _esc() -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame


func _unpause_menu() -> void:
	if get_tree().paused:
		await _esc()
		await _wait_real(0.3)
	get_tree().paused = false


## Puts the player on the floor where they were placed (gravity takes a moment).
func _settle_player() -> void:
	var waited: float = 0.0
	while not player.is_on_floor() and waited < 4.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	await _wait(0.2)


## Walkable-ground search between two world points over a grid: a cell is standing ground if a ray down finds ground, the real capsule fits above it and the ground is within 0.3 m of its neighbour's.
func _walk_route(from_world: Vector3, to_world: Vector3) -> Dictionary:
	var step: float = 0.2
	var space: PhysicsDirectSpaceState3D = shed.get_world_3d().direct_space_state
	var start: Vector2i = Vector2i(roundi(from_world.x / step), roundi(from_world.z / step))
	var goal: Vector2i = Vector2i(roundi(to_world.x / step), roundi(to_world.z / step))
	var limit_min: Vector2i = Vector2i(mini(start.x, goal.x) - 30, mini(start.y, goal.y) - 30)
	var limit_max: Vector2i = Vector2i(maxi(start.x, goal.x) + 30, maxi(start.y, goal.y) + 30)
	var ground: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	ground[start] = from_world.y
	var came_from: Dictionary = {start: start}
	var head: int = 0
	var found: bool = false
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if Vector2(cell - goal).length() <= 2.5:
			goal = cell
			found = true
			break
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + offset
			if came_from.has(next) or next.x < limit_min.x or next.y < limit_min.y or next.x > limit_max.x or next.y > limit_max.y:
				continue
			var gy: float = _standing_ground(space, Vector3(next.x * step, ground[cell], next.y * step))
			if gy == INF or absf(gy - float(ground[cell])) > 0.3:
				continue
			ground[next] = gy
			came_from[next] = cell
			queue.append(next)
	var length: float = 0.0
	var path: Array[Vector3] = []
	var west_x: float = 1.0e9
	var east_x: float = -1.0e9
	if found:
		var walk: Vector2i = goal
		while walk != start:
			length += step
			path.push_front(Vector3(float(walk.x) * step, float(ground[walk]), float(walk.y) * step))
			west_x = minf(west_x, float(walk.x) * step)
			east_x = maxf(east_x, float(walk.x) * step)
			walk = came_from[walk]
	return {"reachable": found, "cells": queue.size(), "length": length, "west_x": west_x, "east_x": east_x, "path": path}


## The ground height under a point if a standing body fits there (its capsule clear of every solid), else INF.
func _standing_ground(space: PhysicsDirectSpaceState3D, around: Vector3) -> float:
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(around + Vector3(0.0, 1.0, 0.0), around - Vector3(0.0, 1.0, 0.0))
	down.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(down)
	if hit.is_empty():
		return INF
	var ground_y: float = (hit["position"] as Vector3).y
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.6
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, Vector3(around.x, ground_y + 0.07 + 0.8, around.z))
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	return INF if not space.intersect_shape(query, 1).is_empty() else ground_y


## True where a world point is inside the 4:3 picture the tape's overlay leaves visible (the camera renders wider, the black bars cover the rest), in front of the camera.
func _in_picture(camera: Camera3D, point: Vector3) -> bool:
	if camera.is_position_behind(point):
		return false

	var size: Vector2 = get_viewport().get_visible_rect().size
	var picture_w: float = size.y * 4.0 / 3.0
	var left: float = (size.x - picture_w) * 0.5
	var at: Vector2 = camera.unproject_position(point)
	return at.x >= left and at.x <= left + picture_w and at.y >= 0.0 and at.y <= size.y


## Holding Space ("Hold [Space] to Skip", the project's own prompt) skips the recording's cutscene: it is cut to its end at once, the view and the control are the player's own, the stage is saved, and the camcorder
## behind her makes its sound as ever. A tap does nothing.
func _check_skip_recording() -> void:
	await _new_game([&"shelter_clipping_read"])
	await _near_bench()
	shed.call("_begin_recording")
	await _wait(2.0)
	var skip: HoldToSkip = shed.get("_skip_ui") as HoldToSkip
	_expect(shed.is_recording_running() and skip != null and skip.is_armed(), "the recording has the skip prompt armed")
	# A tap does nothing.
	Input.action_press(&"skip_cinematic")
	await _wait(0.3)
	Input.action_release(&"skip_cinematic")
	await _wait(0.4)
	_expect(shed.is_recording_running(), "a tap of Space does not skip it")
	# Held, it does.
	Input.action_press(&"skip_cinematic")
	var held: float = 0.0
	while shed.is_recording_running() and held < 4.0:
		await get_tree().process_frame
		held += get_process_delta_time()
	Input.action_release(&"skip_cinematic")
	_expect(not shed.is_recording_running() and held >= skip.hold_seconds - 0.2 and held < skip.hold_seconds + 1.0, "held, Space skips it (%.2f s of the %.2f s hold)" % [held, skip.hold_seconds])
	await get_tree().process_frame
	_expect(shed.is_recording_done() and not player.view_locked and get_viewport().get_camera_3d() == player.movement_controller.camera and shed.get_node_or_null("CinemaCamera") == null, "the stage is saved and the view and the control are the player's")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT and shed.effects_root.visible and not shed.footage.visible, "the shelter is the present, whole")
	_expect(not skip.is_armed() and not skip.panel.visible, "the prompt is gone")
	var waited: float = 0.0
	var cue: AudioStreamPlayer3D = null
	while cue == null and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		cue = shed.camcorder.get_head().get_node_or_null("CueSound") as AudioStreamPlayer3D
	_expect(cue != null and cue.playing, "and the camcorder makes its sound")
	var led: StandardMaterial3D = (shed.camcorder.find_child("Led", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	_expect(led.emission_energy_multiplier > 1.0, "with its red light on")
	await _free_level()


## A shader parameter as a number (0 when it has never been set).
func _number(material: ShaderMaterial, name: StringName) -> float:
	var value: Variant = material.get_shader_parameter(name)
	return float(value) if value != null else 0.0
