extends Node

## The end of the dream intro (`DreamFinale`): the blackout (silence, the city going out in a wave, the
## world losing its light), the move to the wagon in the dark (rain, flickering dim lights, a weak flashlight,
## the girl sobbing at the far end of the aisle, movement locked to the aisle and stopped two metres from her), the whisper behind the player's head, the girl vanishing when
## they look away and back (and when they never look away), the ticket that takes her place, the grab
## and the title card, and the save. Run it as a scene; it quits by itself with a non-zero exit code on
## failure. Then it checks the finale is wired into the real dream intro scene.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_dream_finale_smoke"
const TEST_SCENE_PATH: String = "res://tests/dream_finale_smoke_test.tscn"
const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"

## Stands in for the night environment: all the finale needs of it is a `blackout` it can set.
class FakeNight extends Node:
	var blackout: float = 0.0

var test_failed: bool = false


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	GameSettings.set_captions_enabled(true, false)
	GameSettings.set_text_locale("en", false)

	await _scenario(true)
	await _scenario(false)
	await _check_real_scene()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("DREAM_FINALE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


## One play of the finale in a small fixture (the wagon, the player, a few lights standing for the city).
## `turn_back`: the player looks behind them and back (else they never look away).
func _scenario(turn_back: bool) -> void:
	print("-- scenario: ", "the player turns round and back" if turn_back else "the player never looks away")
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "finale_test_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.set_state_value(&"puzzles", &"orelhao_call_done", true)
	SaveManager.set_state_value(&"puzzles", &"orelhao_fichas", ["juliana_ficha", "lucas_ficha", "sophia_ficha"])

	var root: Node3D = Node3D.new()
	add_child(root)
	var wagon: Node3D = (load("res://scenes/objects/train_wagon.tscn") as PackedScene).instantiate()
	wagon.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(13.86)), Vector3(0.0, 0.3, 0.0))
	root.add_child(wagon)

	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	# The overlook, far from the wagon.
	player.global_position = Vector3(170.0, 1.05, 30.0)

	# A few lights standing for the town: halo billboards in a multimesh, and an emissive window.
	var town: Node3D = Node3D.new()
	root.add_child(town)
	var glow: MultiMeshInstance3D = MultiMeshInstance3D.new()
	glow.name = "NightGlow"
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = 40
	for i: int in 40:
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(300.0 + float(i) * 10.0, -40.0, -300.0)))
		multimesh.set_instance_color(i, Color(1.0, 0.7, 0.4, 0.2))
	glow.multimesh = multimesh
	town.add_child(glow)
	var window_mesh: MeshInstance3D = MeshInstance3D.new()
	var window_material: StandardMaterial3D = StandardMaterial3D.new()
	window_material.emission_enabled = true
	window_material.emission = Color(1.0, 0.8, 0.5)
	window_material.emission_energy_multiplier = 3.0
	window_mesh.mesh = BoxMesh.new()
	window_mesh.material_override = null
	(window_mesh.mesh as BoxMesh).material = window_material
	window_mesh.position = Vector3(320.0, -40.0, -300.0)
	town.add_child(window_mesh)

	var night: FakeNight = FakeNight.new()
	root.add_child(night)

	var finale: DreamFinale = DreamFinale.new()
	finale.night = night
	finale.town = town
	finale.wagon = wagon
	finale.blackout_seconds = 1.0
	finale.dark_hold_seconds = 0.3
	finale.grab_black_after_seconds = 0.4
	finale.black_hold_seconds = 0.5
	finale.title_fade_in_seconds = 0.3
	finale.title_hold_seconds = 0.4
	finale.title_fade_out_seconds = 0.3
	finale.fakeout_timeout_seconds = 6.0 if turn_back else 1.5
	finale.change_scene_at_end = false
	finale.save_scene_path = TEST_SCENE_PATH
	root.add_child(finale)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait(0.5)

	var flashlight: Node = player.get("flashlight_controller") as Node
	flashlight.call("restore_save_state", {"is_on": true})
	var torch_energy_before: float = (flashlight as SpotLight3D).light_energy
	var volume_before: float = AudioServer.get_bus_volume_db(0)
	# The multimesh buffer only exists with a renderer (the headless one keeps none): the halo checks
	# run when it does, and are skipped (said so) when it does not.
	var has_buffer: bool = not multimesh.buffer.is_empty()
	if not has_buffer:
		print("note - no multimesh buffer without a renderer: the halo checks are skipped")
	var glow_alpha_before: float = multimesh.buffer[15] if has_buffer else 0.0
	var finished_count: Array[int] = [0]
	finale.finished.connect(func() -> void: finished_count[0] += 1)
	var titled: Array[bool] = [false]
	finale.title_shown.connect(func() -> void: titled[0] = true)

	# ---- The blackout.
	finale.start()
	_expect(finale.stage == DreamFinale.Stage.BLACKOUT, "the finale starts with the blackout")
	_expect(not bool(flashlight.get("flashlight_on")), "the flashlight goes out")
	_expect(player.manual_save_blocked, "saving is blocked from here to the end")
	await _wait(0.45)
	_expect(AudioServer.get_bus_volume_db(0) < -40.0, "in complete silence (the master volume is down to %.0f dB)" % AudioServer.get_bus_volume_db(0))
	var halfway: PackedFloat32Array = (glow.multimesh as MultiMesh).buffer
	var lit_now: int = 0
	var dark_now: int = 0
	for i: int in (40 if has_buffer else 0):
		if halfway[i * 16 + 15] > 0.001:
			lit_now += 1
		else:
			dark_now += 1
	_expect(not has_buffer or (lit_now > 0 and dark_now > 0), "half way, the city is going out in a wave: some lights dark, some still lit (%d lit, %d dark)" % [lit_now, dark_now])
	_expect(night.blackout > 0.2 and night.blackout < 1.0, "and the world's light is on its way out (%.2f)" % night.blackout)
	await _wait(0.8)
	_expect(is_equal_approx(night.blackout, 1.0), "the world has no light at all")
	var all_dark: bool = true
	for i: int in (40 if has_buffer else 0):
		if (glow.multimesh as MultiMesh).buffer[i * 16 + 15] > 0.001:
			all_dark = false
	_expect(all_dark, "every halo of the city is out")
	_expect(is_equal_approx(window_material.emission_energy_multiplier, 3.0), "the shared window material was not touched (it is copied before it is dimmed)")
	var own_window: StandardMaterial3D = window_mesh.get_surface_override_material(0) as StandardMaterial3D
	_expect(own_window != null and own_window != window_material and own_window.emission_energy_multiplier < 0.01, "the window's own copy is out")
	_expect(not has_buffer or multimesh.buffer[15] == glow_alpha_before, "nor the shared halo data (it is copied before it is dimmed)")
	_expect(finale.stage == DreamFinale.Stage.BLACKOUT, "still dark and silent, before the move")

	# ---- The wagon.
	await _until(func() -> bool: return finale.stage == DreamFinale.Stage.APPROACH, "the player being moved to the wagon", 5.0)
	await _wait(0.3)
	_expect(AudioServer.get_bus_volume_db(0) > -10.0 or is_equal_approx(AudioServer.get_bus_volume_db(0), volume_before), "the sound is back (%.0f dB)" % AudioServer.get_bus_volume_db(0))
	var rain: AudioStreamPlayer = finale.get_node_or_null("RoofRain") as AudioStreamPlayer
	_expect(rain != null and rain.playing, "heavy rain pounds the roof")
	var start_world: Vector3 = wagon.to_global(finale.wagon_start_local)
	_expect(player.global_position.distance_to(start_world) < 0.4, "the player is where the dream began, in the wagon (%.2f m off)" % player.global_position.distance_to(start_world))
	var lights: Node = wagon.get_node("Lights")
	var not_red: bool = true
	var brightest: float = 0.0
	for light: Node in lights.get_children():
		var omni: OmniLight3D = light as OmniLight3D
		if omni == null:
			continue

		if omni.light_color.r > 0.9 and omni.light_color.g < 0.3:
			not_red = false

		brightest = maxf(brightest, omni.light_energy)
	_expect(not_red, "the wagon is not red any more")
	var seen_levels: Dictionary = {}
	var flicker_peak: float = 0.0
	for i: int in 150:
		await get_tree().physics_frame
		for light: Node in lights.get_children():
			if light is OmniLight3D:
				seen_levels[snappedf((light as OmniLight3D).light_energy, 0.005)] = true
				flicker_peak = maxf(flicker_peak, (light as OmniLight3D).light_energy)
	_expect(seen_levels.size() >= 4 and flicker_peak <= 0.2, "the lights only flicker, dim (%d different levels, peak %.2f)" % [seen_levels.size(), flicker_peak])
	var torch: SpotLight3D = flashlight as SpotLight3D
	_expect(bool(flashlight.get("flashlight_on")) and torch.light_energy < torch_energy_before * 0.5, "and the flashlight is on but weak (%.1f of %.1f)" % [torch.light_energy, torch_energy_before])
	var sophia: Node3D = wagon.get_node_or_null("Sophia") as Node3D
	_expect(sophia != null and sophia.visible, "a girl sits in the aisle")
	var sophia_at: Vector3 = wagon.to_local(sophia.global_position)
	_expect(absf(sophia_at.x) < 0.1, "in the middle of it")
	_expect(sophia_at.z < -5.0 and sophia_at.z > -6.1, "right against the far (north) wall, so the whole wagon has to be walked (z %.2f)" % sophia_at.z)
	var sobbing: AudioStreamPlayer3D = sophia.get_node_or_null("Sobbing") as AudioStreamPlayer3D
	_expect(sobbing != null and sobbing.playing, "sobbing quietly")
	var movement: PlayerMovementController = player.movement_controller
	_expect(movement.is_corridor_locked(), "the player can only walk along the aisle")
	_expect(bool(flashlight.get("flashlight_input_enabled")), "the flashlight can be used again")
	var facing: Vector3 = -player.get_node("Head").global_basis.z
	var to_her: Vector3 = sophia.global_position - player.global_position
	facing.y = 0.0
	to_her.y = 0.0
	_expect(rad_to_deg(facing.angle_to(to_her)) < 15.0, "looking down the aisle at her")

	# Sideways keys do nothing; back is limited (the locked door).
	var before_sideways: Vector3 = player.global_position
	Input.action_press("right")
	await _wait(0.6)
	Input.action_release("right")
	_expect(Vector2(player.global_position.x - before_sideways.x, player.global_position.z - before_sideways.z).length() < 0.05, "the sideways keys do nothing (moved %.2f m)" % Vector2(player.global_position.x - before_sideways.x, player.global_position.z - before_sideways.z).length())
	Input.action_press("down")
	await _wait(1.6)
	Input.action_release("down")
	var back_distance: float = movement.get_corridor_distance()
	_expect(back_distance < -0.2 and back_distance >= -finale.back_limit - 0.1, "back stops at the locked door behind (%.2f m)" % back_distance)

	# ---- Forward, the whole wagon: the whisper from behind the head, and the walk ends two metres from her.
	Input.action_press("up")
	await _until(func() -> bool: return finale.stage == DreamFinale.Stage.WHISPERED, "the whisper once she is near", 20.0)
	var distance_at_whisper: float = Vector2(player.global_position.x - sophia.global_position.x, player.global_position.z - sophia.global_position.z).length()
	_expect(distance_at_whisper <= finale.whisper_distance + 0.3 and distance_at_whisper > finale.whisper_distance - 0.8, "about two metres from her (%.2f)" % distance_at_whisper)
	var whisper: AudioStreamPlayer3D = finale.get_node_or_null("Whisper") as AudioStreamPlayer3D
	_expect(whisper != null and whisper.playing, "a whisper plays")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var offset: Vector3 = whisper.global_position - camera.global_position
	_expect(offset.length() < 0.5 and offset.dot(-camera.global_basis.z) < -0.15, "right behind the player's head (%.2f m, %.2f along the view)" % [offset.length(), offset.dot(-camera.global_basis.z)])
	await _wait(0.3)
	_expect(CaptionManager.label.text.contains("You're not supposed to be here."), "'You're not supposed to be here.' (%s)" % CaptionManager.label.text)
	_expect(sophia.visible, "and she is still there")

	# Forward is still held: the walk ends where it is.
	await _wait(0.5)
	var stuck_at: float = Vector2(player.global_position.x - sophia.global_position.x, player.global_position.z - sophia.global_position.z).length()
	Input.action_release("up")
	_expect(stuck_at >= finale.stop_before_sophia - 0.2 and stuck_at <= finale.stop_before_sophia + 0.35, "the walk ends there, however long forward is held (%.2f m)" % stuck_at)

	if turn_back:
		# They turn to look behind them: the wagon is empty. Then back to the aisle.
		var yaw: float = movement.look_yaw
		movement.look_yaw = yaw + 180.0
		await _wait(0.6)
		_expect(not sobbing.playing, "the crying stops when they look back")
		_expect(sophia.visible and finale.stage == DreamFinale.Stage.WHISPERED, "while they look behind them she is still there, and the wagon behind is empty")
		movement.look_yaw = yaw
		await _until(func() -> bool: return finale.stage == DreamFinale.Stage.SWAPPED, "she goes when they turn back", 3.0)
	else:
		await _until(func() -> bool: return finale.stage == DreamFinale.Stage.SWAPPED, "she goes anyway if they never look away", 6.0)

	await _wait(0.5)
	_expect(not sophia.visible, "the crying girl is GONE")
	_expect(not sobbing.playing, "the sobbing has stopped")
	var ticket: FinaleTicket = wagon.get_node_or_null("Ticket") as FinaleTicket
	_expect(ticket != null and ticket.enabled, "where she sat lies a ticket")
	_expect(wagon.to_local(ticket.global_position).distance_to(finale.sophia_local) < 0.05, "on the very spot")
	_expect(ticket.get_prompt_text() == "PROMPT_TAKE_TICKET" and tr(ticket.get_prompt_text()) == "[{interact}] Take Ticket", "with a 'Take Ticket' prompt (%s)" % tr(ticket.get_prompt_text()))
	_expect(ticket.find_child("Glow", true, false) != null, "and a faint glow of its own")
	# The walk now reaches the ticket (and not past it).
	Input.action_press("up")
	await _wait(2.5)
	Input.action_release("up")
	var ticket_gap: float = Vector2(player.global_position.x - ticket.global_position.x, player.global_position.z - ticket.global_position.z).length()
	_expect(ticket_gap < finale.stop_before_ticket + 0.4 and ticket_gap > 0.3, "the walk now reaches the ticket (%.2f m from it)" % ticket_gap)
	await _check_ticket_ray(player, ticket)

	# ---- The grab, the black, the title card, the save.
	var impact_seen: Array[bool] = [false]
	player.global_position = wagon.to_global(finale.sophia_local + Vector3(0.0, 0.7657 - 0.073, 1.3))
	ticket.interact(player)
	_expect(finale.stage == DreamFinale.Stage.GRABBED, "taking the ticket springs the trap")
	_expect(not ticket.can_interact(player), "and it can be taken only once")
	await _wait(0.12)
	var grab_layer: Node = finale.get_node_or_null("GrabLayer")
	_expect(grab_layer != null and grab_layer.get_child(0) is FinaleGrabOverlay, "black hands claw in over the picture")
	for child: Node in finale.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing and (child as AudioStreamPlayer).volume_db > 0.0:
			impact_seen[0] = true
	_expect(impact_seen[0], "with a loud impact")
	_expect(movement.gesture_offset.z > 0.2 or movement.gesture_pitch_degrees > 5.0, "and the view thrown back")
	_expect(not movement.is_corridor_locked(), "(the corridor lock is let go)")
	await _wait(0.5)
	var black: ColorRect = finale._black_rect
	_expect(black != null and black.modulate.a > 0.99, "the picture snaps to black")
	_expect(rain == null or not rain.playing, "in silence")
	_expect(not titled[0], "and stays black for a moment before the title")
	await _until(func() -> bool: return titled[0], "the title card", 6.0)
	var title: Label = finale.get_node("TitleCard").find_child("Title", true, false) as Label
	_expect(title != null and title.text == "UNRAILED", "UNRAILED")
	_expect(title.theme_type_variation == &"TitleLabel" and title.label_settings == null, "set in the menu's title style (its variation)")
	_expect(title.get_theme_color(&"font_color").is_equal_approx(UIConfig.color_accent), "in the palette's accent colour")
	_expect(title.get_theme_constant(&"outline_size") == 0 and title.get_theme_color(&"font_shadow_color").a < 0.01, "with no outline, glow or shadow")
	_expect(finale.get_node("TitleCard").find_children("*", "ColorRect", true, false).is_empty(), "and no lines")
	await _until(func() -> bool: return finished_count[0] == 1, "the finale ending", 6.0)
	_expect(finale.stage == DreamFinale.Stage.DONE, "it is over")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"demo_complete", false)), "the game is marked finished")
	_expect(not bool(SaveManager.get_state_value(&"puzzles", &"orelhao_call_done", true)), "and the call is still to be made when they continue")
	var snapshot: Dictionary = SaveManager.get_manual_player_state(TEST_SCENE_PATH)
	_expect(not snapshot.is_empty(), "the save keeps where they were")
	var saved_position: Variant = snapshot.get("position", null)
	_expect(saved_position != null, "(a position is in it)")
	if saved_position is Array and (saved_position as Array).size() == 3:
		var at: Vector3 = Vector3(float((saved_position as Array)[0]), float((saved_position as Array)[1]), float((saved_position as Array)[2]))
		_expect(at.distance_to(Vector3(170.0, 1.05, 30.0)) < 3.0, "at the overlook, not in the wagon (%s)" % str(at))
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(0), volume_before), "the master volume is back")

	Input.action_release("up")
	root.queue_free()
	await get_tree().process_frame


func _check_ticket_ray(player: CharacterBody3D, ticket: FinaleTicket) -> void:
	# The player can find the ticket with the interaction ray, from where the aisle lets them stand.
	var movement: PlayerMovementController = player.movement_controller
	var stand: Vector3 = ticket.global_position + Vector3(0.0, 0.7657 - 0.073 + 0.0, 0.0)
	var along: Vector3 = (ticket.global_basis.z).normalized()
	stand += along * 1.2
	stand.y = player.global_position.y
	player.global_position = stand
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var to_ticket: Vector3 = ticket.global_position - camera.global_position
	movement.look_yaw = -rad_to_deg(atan2(-to_ticket.x, -to_ticket.z))
	movement.look_pitch = -rad_to_deg(atan2(to_ticket.y, Vector2(to_ticket.x, to_ticket.z).length()))
	for i: int in 4:
		await get_tree().physics_frame

	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractRay")
	ray.force_raycast_update()
	var found: Node = ray.get_collider() as Node
	while found != null and not found is Interactable:
		found = found.get_parent()

	_expect(found == ticket, "the interaction ray reaches the ticket from the aisle")


## The finale is wired into the real dream intro: its nodes are set, the call does not hold the player,
## and run on the real town it dims the real halos.
func _check_real_scene() -> void:
	print("-- the real dream intro")
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "finale_real_start", "SAVE_LOCATION_DREAM_INTRO")
	var level: Node = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait(0.5)

	var finale: DreamFinale = level.get_node_or_null("Finale") as DreamFinale
	_expect(finale != null, "the dream intro has its Finale")
	if finale == null:
		level.queue_free()
		return

	_expect(finale.phone != null and finale.night != null and finale.town != null and finale.wagon != null, "wired to the payphone, the night, the town and the wagon")
	_expect(finale.phone.release_player_after_call_seconds == 0.0, "the call does not release the player: the finale takes over")
	_expect(finale.wagon.get_node_or_null("Lights") != null, "the wagon has its lights")
	_expect(finale.night.get("blackout") != null, "and the night environment can lose its light")

	var glow: MultiMeshInstance3D = finale.town.find_child("NightGlow", true, false) as MultiMeshInstance3D
	_expect(glow != null and glow.multimesh != null and glow.multimesh.instance_count > 100, "the town has its halos (%d)" % (glow.multimesh.instance_count if glow != null and glow.multimesh != null else 0))
	var cached: MultiMesh = glow.multimesh
	var before: PackedFloat32Array = cached.buffer
	var has_buffer: bool = not before.is_empty()
	finale.blackout_seconds = 0.8
	finale.dark_hold_seconds = 0.1
	finale.change_scene_at_end = false
	var player: Node3D = level.get_node("Player")
	player.global_position = Vector3(168.0, -18.0, 27.0)
	finale.start()
	await _wait(1.2)
	_expect(is_equal_approx(float(finale.night.get("blackout")), 1.0), "the real night loses all its light")
	var after: PackedFloat32Array = glow.multimesh.buffer
	var lit: int = 0
	for i: int in (glow.multimesh.instance_count if has_buffer else 0):
		if after[i * 16 + 15] > 0.001:
			lit += 1
	_expect(lit == 0, "every real halo is out (%d still lit)" % lit)
	_expect(glow.multimesh != cached and cached.buffer == before, "the town's own data is untouched")
	await _until(func() -> bool: return finale.stage == DreamFinale.Stage.APPROACH, "the player moved into the real wagon", 6.0)
	var wagon_spot: Vector3 = finale.wagon.to_global(finale.wagon_start_local)
	_expect(player.global_position.distance_to(wagon_spot) < 0.6, "at the wagon start (%.2f m off)" % player.global_position.distance_to(wagon_spot))
	level.queue_free()
	await get_tree().process_frame


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
