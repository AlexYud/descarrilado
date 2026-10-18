extends Node

## The end of the dream intro (`DreamFinale`): the town's lights going out one by one (each stuttering and then
## gone for good), the black and silent cut, the slow fade-in with heavy lids and the wake-up in the wagon (rain,
## flickering dim lights, a weak flashlight, the girl sobbing at the far end of the aisle with her back to it,
## both in the middle of the aisle), the cutscene near her (the player loses control, walks on a second, the
## whisper behind the head, the crying stops, Juliana turns round scared, the girl is gone when she turns
## back, she searches with the flashlight and turns to the exit), the walk out, the arms that come out of the black door after two metres and the grab,
## the title card and the save. Run it as a scene; it quits by itself with a non-zero exit code on failure.
## Then it checks the finale is wired into the real dream intro scene.

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

	await _scenario()
	await _check_real_scene()
	await _check_early_jump()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("DREAM_FINALE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


## One play of the finale in a small fixture (the wagon, the player, a few lights standing for the city).
func _scenario() -> void:
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
	finale.dark_hold_seconds = 1.0
	finale.grab_black_after_seconds = 0.4
	finale.black_hold_seconds = 0.5
	finale.title_fade_in_seconds = 0.3
	finale.title_hold_seconds = 0.4
	finale.title_fade_out_seconds = 0.3
	finale.wagon_fade_in_seconds = 0.8
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

	# ---- The lights go out, one by one, while the call ends.
	finale.begin_lights_out(1.6)
	_expect(finale.stage == DreamFinale.Stage.BLACKOUT, "the finale starts when the call is nearing its end")
	_expect(not bool(flashlight.get("flashlight_on")), "the flashlight goes out")
	_expect(player.manual_save_blocked, "saving is blocked from here to the end")
	var partial: bool = false
	var samples: int = 0
	var lit_seen: Dictionary = {}
	for step: int in 16:
		await _wait(0.1)
		if not has_buffer:
			continue

		var buffer: PackedFloat32Array = (glow.multimesh as MultiMesh).buffer
		var lit_count: int = 0
		for i: int in 40:
			var alpha: float = buffer[i * 16 + 15]
			if alpha > 0.001 and not is_equal_approx(alpha, 0.2):
				partial = true

			if alpha > 0.001:
				lit_count += 1

		lit_seen[lit_count] = true
		samples += 1
	_expect(not has_buffer or not partial, "every light is either on or out, never half way (it goes suddenly, not fading)")
	_expect(not has_buffer or lit_seen.size() >= 4, "and they go one by one over the time (%d different counts of lit lights)" % lit_seen.size())
	_expect(night.blackout > 0.99, "the world's light has drained by the end")
	var all_dark: bool = true
	for i: int in (40 if has_buffer else 0):
		if (glow.multimesh as MultiMesh).buffer[i * 16 + 15] > 0.001:
			all_dark = false
	_expect(all_dark, "every halo of the city is out")
	_expect(is_equal_approx(window_material.emission_energy_multiplier, 3.0), "the shared window material was not touched (it is copied before it is dimmed)")
	var own_window: StandardMaterial3D = window_mesh.get_surface_override_material(0) as StandardMaterial3D
	_expect(own_window != null and own_window != window_material and own_window.emission_energy_multiplier < 0.01, "the window's own copy is out")
	_expect(not has_buffer or multimesh.buffer[15] == glow_alpha_before, "nor the shared halo data (it is copied before it is dimmed)")
	_expect(finale._black_rect == null, "the picture is still the town while the call ends")

	# ---- The call ends: black and silent at once.
	finale._on_line_cut()
	_expect(finale._black_rect != null and finale._black_rect.modulate.a > 0.99, "the call ends and the picture is black at once")
	await _wait(0.5)
	_expect(AudioServer.get_bus_volume_db(0) < -40.0, "in complete silence (the master volume is down to %.0f dB)" % AudioServer.get_bus_volume_db(0))
	_expect(finale.stage == DreamFinale.Stage.BLACKOUT or finale.stage == DreamFinale.Stage.APPROACH, "dark and silent, before the move")

	# ---- The wagon.
	await _until(func() -> bool: return finale.stage == DreamFinale.Stage.APPROACH, "the player being moved to the wagon", 5.0)
	var peak_alpha: float = finale._black_rect.modulate.a
	var drooped: bool = false
	var last_alpha: float = peak_alpha
	for i: int in 70:
		await get_tree().physics_frame
		var alpha_now: float = finale._black_rect.modulate.a
		if alpha_now > last_alpha + 0.01:
			drooped = true

		last_alpha = alpha_now
	_expect(peak_alpha > 0.3, "the wagon begins in black (%.2f)" % peak_alpha)
	_expect(drooped, "and opens like heavy lids: it droops back a little before it clears")
	_expect(finale._black_rect.modulate.a < 0.05, "until the picture is clear (%.2f)" % finale._black_rect.modulate.a)

	# Waking up: the head-raise animation plays and the player has no control until it ends.
	var head_animation: AnimationPlayer = player.get_node("Head/HeadRaiseAnimationPlayer")
	_expect(player.cutscene_frozen and head_animation.is_playing() and head_animation.current_animation == "HeadRaise", "the player wakes up (the head-raise animation plays, no control)")
	var low_pitch: float = player.get_node("Head/Camera3D").rotation.x
	_expect(low_pitch < -0.5 or head_animation.current_animation_position > 3.0, "lying down, looking up at the ceiling (pitch %.2f)" % low_pitch)
	Input.action_press("up")
	await _wait(0.5)
	Input.action_release("up")
	_expect(player.global_position.distance_to(wagon.to_global(finale.wagon_start_local)) < 0.4, "and walking does nothing meanwhile")
	var lowest_y: float = 99.0
	var fastest_fall: float = 0.0
	var guard: float = 0.0
	while player.cutscene_frozen and guard < 14.0:
		await get_tree().physics_frame
		guard += get_physics_process_delta_time()
		lowest_y = minf(lowest_y, wagon.to_local(player.global_position).y)
		fastest_fall = minf(fastest_fall, player.velocity.y)
	_expect(not player.cutscene_frozen, "getting up (the animation ending)")
	_expect(lowest_y > 0.0 and fastest_fall > -3.0, "standing on the floor the whole wake-up, never falling (lowest %.2f, fastest fall %.1f m/s)" % [lowest_y, fastest_fall])
	_expect(not head_animation.is_playing() and absf(player.rotation.y) < 0.001, "on their feet, the controls are theirs")
	await _wait(0.3)

	_expect(AudioServer.get_bus_volume_db(0) > -10.0 or is_equal_approx(AudioServer.get_bus_volume_db(0), volume_before), "the sound is back (%.0f dB)" % AudioServer.get_bus_volume_db(0))
	var rain: AudioStreamPlayer = finale.get_node_or_null("RoofRain") as AudioStreamPlayer
	_expect(rain != null and rain.playing, "heavy rain pounds the roof")
	_expect(absf(wagon.to_local(player.global_position).x - finale.aisle_x) < 0.05, "the player is in the middle of the aisle (x %.2f)" % wagon.to_local(player.global_position).x)
	var lights: Node = wagon.get_node("Lights")
	var not_red: bool = true
	for light: Node in lights.get_children():
		var omni: OmniLight3D = light as OmniLight3D
		if omni != null and omni.light_color.r > 0.9 and omni.light_color.g < 0.3:
			not_red = false
	_expect(not_red, "the wagon is not red any more")
	var seen_levels: Dictionary = {}
	var flicker_peak: float = 0.0
	var darkest_stretch: float = 0.0
	var dark_run: float = 0.0
	for i: int in 150:
		await get_tree().physics_frame
		for light: Node in lights.get_children():
			if light is OmniLight3D:
				seen_levels[snappedf((light as OmniLight3D).light_energy, 0.005)] = true
				flicker_peak = maxf(flicker_peak, (light as OmniLight3D).light_energy)

		var total_energy: float = 0.0
		for light: Node in lights.get_children():
			if light is OmniLight3D:
				total_energy += (light as OmniLight3D).light_energy

		dark_run = dark_run + get_physics_process_delta_time() if total_energy < 0.03 else 0.0
		darkest_stretch = maxf(darkest_stretch, dark_run)
	_expect(seen_levels.size() >= 4 and flicker_peak <= 0.4, "the lights only flicker, dim (%d different levels, peak %.2f)" % [seen_levels.size(), flicker_peak])
	_expect(wagon.get_node_or_null("SophiaLight") == null, "nothing lights the girl but the wagon's own dim lights")
	_expect(darkest_stretch < 1.0, "the lights never leave the wagon in the dark for long (longest dark stretch %.2f s)" % darkest_stretch)
	var torch: SpotLight3D = flashlight as SpotLight3D
	_expect(not bool(flashlight.get("flashlight_on")), "the flashlight is not switched on for the player")
	_expect(torch.light_energy < torch_energy_before * 0.25 and torch.light_energy > torch_energy_before * 0.08, "and it is way weaker than usual (%.1f of %.1f)" % [torch.light_energy, torch_energy_before])
	var sophia: Node3D = wagon.get_node_or_null("Sophia") as Node3D
	_expect(sophia != null and sophia.visible, "a girl sits in the aisle")
	var sophia_at: Vector3 = wagon.to_local(sophia.global_position)
	_expect(absf(sophia_at.x - finale.aisle_x) < 0.1, "in the middle of it (x %.2f)" % sophia_at.x)
	_expect(sophia_at.z < -5.0 and sophia_at.z > -6.1, "right against the far (north) wall, so the whole wagon has to be walked (z %.2f)" % sophia_at.z)
	_facing_check(sophia.global_basis.z, player, sophia)
	var sobbing: AudioStreamPlayer3D = sophia.get_node_or_null("Sobbing") as AudioStreamPlayer3D
	_expect(sobbing != null and sobbing.playing, "sobbing quietly")
	var movement: PlayerMovementController = player.movement_controller
	_expect(movement.is_corridor_locked(), "the player can only walk along the aisle")
	_expect(bool(flashlight.get("flashlight_input_enabled")), "the flashlight can be used again")
	var facing_vector: Vector3 = -player.get_node("Head").global_basis.z
	var to_her: Vector3 = sophia.global_position - player.global_position
	facing_vector.y = 0.0
	to_her.y = 0.0
	_expect(rad_to_deg(facing_vector.angle_to(to_her)) < 15.0, "looking down the aisle at her")

	# Sideways keys do nothing; back is limited (the locked door).
	var before_sideways: Vector3 = player.global_position
	Input.action_press("right")
	await _wait(0.6)
	Input.action_release("right")
	_expect(Vector2(player.global_position.x - before_sideways.x, player.global_position.z - before_sideways.z).length() < 0.05, "the sideways keys do nothing")
	Input.action_press("down")
	await _wait(1.6)
	Input.action_release("down")
	var back_distance: float = movement.get_corridor_distance()
	_expect(back_distance < -0.2 and back_distance >= -finale.back_limit - 0.1, "back stops at the locked door behind (%.2f m)" % back_distance)

	# ---- Forward, the whole wagon, until the cutscene takes over.
	Input.action_press("up")
	await _wait(1.2)
	var walk_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	_expect(walk_speed > 0.3 and walk_speed < 0.9, "the walk is slow (%.2f m/s)" % walk_speed)
	await _until(func() -> bool: return finale.stage == DreamFinale.Stage.CUTSCENE, "the cutscene once she is near", 40.0)
	Input.action_release("up")
	var distance_at_start: float = _distance(player, sophia)
	_expect(distance_at_start <= finale.cutscene_distance + 0.3 and distance_at_start > finale.cutscene_distance - 0.8, "about three metres from her (%.2f)" % distance_at_start)
	_expect(player.view_locked, "the player has no control")
	var facing_yaw: float = _yaw_of(movement)
	Engine.time_scale = 2.0

	# Juliana walks on by herself, even against the keys.
	await _until(func() -> bool: return finale._auto_walking, "Juliana starting to walk by herself", 4.0)
	_expect(bool(flashlight.get("flashlight_on")), "the flashlight is on as she walks up to the girl")
	_expect((-torch.global_basis.z).y < -0.2, "and it points down at the girl on the floor, not straight ahead (%.2f)" % (-torch.global_basis.z).y)
	var before_walk: float = _distance(player, sophia)
	Input.action_press("down")
	await _wait(0.5)
	Input.action_release("down")
	_expect(_distance(player, sophia) < before_walk - 0.2, "Juliana walks on towards her by herself, whatever keys are pressed (%.2f m closer)" % (before_walk - _distance(player, sophia)))
	var camera: Camera3D = player.get_node("Head/Camera3D")
	await _until(func() -> bool: return camera.get_node_or_null("Whisper") != null, "the whisper", 4.0)
	var whisper: AudioStreamPlayer3D = camera.get_node_or_null("Whisper") as AudioStreamPlayer3D
	_expect(whisper != null and whisper.playing, "a whisper plays")
	_expect(whisper.get_parent() == camera and whisper.panning_strength > 1.0 and whisper.max_distance <= 5.0, "as a true 3D sound on her head, with strong panning")
	_expect(absf(camera.to_local(whisper.global_position).x) > 0.1, "at one ear, not in the middle of the head (%.2f m to the side)" % camera.to_local(whisper.global_position).x)
	var offset: Vector3 = whisper.global_position - camera.global_position
	_expect(offset.length() < 0.5 and offset.dot(-camera.global_basis.z) < -0.15, "right behind her head (%.2f m, %.2f along the view)" % [offset.length(), offset.dot(-camera.global_basis.z)])
	_expect(not sobbing.playing, "the crying stops with the whisper")
	_expect(bool(flashlight.get("flashlight_on")), "her flashlight is on for the search")
	await _wait(0.3)
	_expect(CaptionManager.label.text.contains("You're not supposed to be here."), "'You're not supposed to be here.' (%s)" % CaptionManager.label.text)
	var cutscene_distance_walked: float = distance_at_start - _distance(player, sophia)
	_expect(cutscene_distance_walked > 0.3 and cutscene_distance_walked < 1.4, "after about a second of walking (%.2f m)" % cutscene_distance_walked)

	# She turns round, scared: far round, and the girl is gone when she turns back.
	var max_turn: float = 0.0
	var gone_while_looking_back: bool = false
	var back_facing_after: bool = false
	var sophia_visible_when_facing_again: bool = true
	var turned_round: bool = false
	var waited: float = 0.0
	var max_beam_lead: float = 0.0
	while finale.stage == DreamFinale.Stage.CUTSCENE and waited < 60.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		max_beam_lead = maxf(max_beam_lead, rad_to_deg((-torch.global_basis.z).angle_to(-camera.global_basis.z)))
		var turn: float = _yaw_of(movement) - facing_yaw
		max_turn = maxf(max_turn, turn)
		if turn > 170.0:
			turned_round = true
			if not sophia.visible:
				gone_while_looking_back = true

		if turned_round and absf(turn) < 8.0 and not back_facing_after:
			back_facing_after = true
			sophia_visible_when_facing_again = sophia.visible

	_expect(max_beam_lead > 30.0, "the flashlight is pointed first and the head follows (the beam got %.0f degrees ahead of the view)" % max_beam_lead)
	_expect(max_turn > 175.0, "Juliana turns all the way round to look behind her (%.0f degrees)" % max_turn)
	_expect(gone_while_looking_back, "the girl is gone while she looks at the empty wagon")
	_expect(back_facing_after and not sophia_visible_when_facing_again, "and when she turns back to the crying girl there is nobody there")
	_expect(wagon.get_node_or_null("Ticket") == null, "nothing is left in her place")
	Engine.time_scale = 1.0
	_expect(finale.stage == DreamFinale.Stage.LEAVING, "then the controls come back")
	_expect(finale._exit_light_dead and not finale._wagon_lights[0].visible, "the lamp over the exit door is dead, the door is black")
	_expect(not player.view_locked, "the player can move and look again")
	var exit_look: Vector3 = -camera.global_basis.z
	exit_look.y = 0.0
	_expect(exit_look.normalized().dot(finale._corridor_axis) < -0.9, "facing the wagon exit")

	# ---- Walking out: after two metres the black door gets its arms.
	_expect(finale.stage != DreamFinale.Stage.GRABBED and finale.stage != DreamFinale.Stage.DOOR, "nothing happens as she stands there")
	var start_z: float = wagon.to_local(player.global_position).z
	Input.action_press("up")
	await _wait(1.5)
	_expect(finale.stage == DreamFinale.Stage.LEAVING and wagon.to_local(player.global_position).z > start_z + 0.3, "the forward key walks her towards the exit")
	await _until(func() -> bool: return finale.stage == DreamFinale.Stage.DOOR, "the scene at the door after two metres", 25.0)
	Input.action_release("up")
	var walked_out: float = wagon.to_local(player.global_position).z - start_z
	_expect(walked_out > finale.leave_distance - 0.4 and walked_out < finale.leave_distance + 1.0, "about two metres from where she turned (%.2f m)" % walked_out)
	_expect(player.view_locked, "the controls go again")
	var arms: FinaleDoorArms = wagon.get_node_or_null("DoorArms") as FinaleDoorArms
	_expect(arms != null, "the wagon has the arms of the door")
	var doorway: Node3D = arms.get_node("Doorway") as Node3D
	_expect(doorway.visible, "the exit door is a black opening")
	_expect(arms.emerge < 0.1, "nothing has come out of it yet")
	Engine.time_scale = 3.0
	var lights_went_out: bool = false
	var peak_emerge: float = 0.0
	var nearest_hand: float = 99.0
	var arms_never_backwards: bool = true
	var last_emerge: float = 0.0
	var beam_on_door: float = 0.0
	var door_world: Vector3 = wagon.to_global(Vector3(finale.aisle_x, 1.3, finale.wagon_end_wall_z - 0.1))
	var guard_door: float = 0.0
	while finale.stage == DreamFinale.Stage.DOOR and guard_door < 60.0:
		await get_tree().process_frame
		guard_door += get_process_delta_time()
		lights_went_out = lights_went_out or finale._lights_forced_out
		peak_emerge = maxf(peak_emerge, arms.emerge)
		if arms.emerge < last_emerge - 0.001:
			arms_never_backwards = false

		last_emerge = arms.emerge
		if arms.emerge > 0.3 and bool(flashlight.get("flashlight_on")):
			beam_on_door = maxf(beam_on_door, 1.0 - rad_to_deg((-torch.global_basis.z).angle_to((door_world - torch.global_position).normalized())) / 30.0)

	Engine.time_scale = 1.0
	_expect(finale.stage == DreamFinale.Stage.GRABBED, "then the arms get her")
	_expect(lights_went_out, "the lights went out while they came")
	_expect(peak_emerge > 0.99, "the arms came all the way out of the door (%.2f)" % peak_emerge)
	_expect(arms_never_backwards, "slowly, never going back")
	_expect(beam_on_door > 0.0, "with her flashlight shaking on the door")
	for rig: Dictionary in arms._rigs:
		var hand: Node3D = (rig["wrist"] as Node3D)
		nearest_hand = minf(nearest_hand, hand.global_position.distance_to(camera.global_position))
	_expect(nearest_hand < 1.2, "the hands are at her face (%.2f m)" % nearest_hand)
	_expect(arms.reach > 0.9 and arms.lunge > 3.0, "after the lunge (reach %.2f, %.1f m travelled)" % [arms.reach, arms.lunge])
	var impact_seen: Array[bool] = [false]
	await _wait(0.2)
	_expect(finale.get_node_or_null("GrabLayer") == null, "(the old black-hands overlay is gone)")
	for child: Node in finale.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing and (child as AudioStreamPlayer).volume_db > 0.0:
			impact_seen[0] = true
	_expect(impact_seen[0], "with a loud impact")
	_expect(movement.gesture_offset.z > 0.1 or movement.gesture_pitch_degrees > 3.0, "and the view thrown back (z %.2f, pitch %.1f)" % [movement.gesture_offset.z, movement.gesture_pitch_degrees])
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


func _distance(player: Node3D, sophia: Node3D) -> float:
	return Vector2(player.global_position.x - sophia.global_position.x, player.global_position.z - sophia.global_position.z).length()


func _yaw_of(movement: PlayerMovementController) -> float:
	return movement.look_yaw


## She sits facing the wall: her back is to the aisle, so the player sees the back of her head.
func _facing_check(her_facing: Vector3, player: Node3D, sophia: Node3D) -> void:
	var to_player: Vector3 = player.global_position - sophia.global_position
	to_player.y = 0.0
	_expect(her_facing.dot(to_player.normalized()) < -0.9, "facing the wall, her back to the player (%.2f)" % her_facing.dot(to_player.normalized()))


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
	_expect(finale.phone.finale_takes_over, "the payphone leaves the view to the finale (it stays on the city, zooming)")
	_expect(finale.phone.call_ending.is_connected(finale.begin_lights_out) and finale.phone.line_cut.is_connected(finale._on_line_cut), "the call tells the finale when it is ending and when it is over")
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
	_expect(finale._has_last_light, "and one window of the town is kept for the last light")
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

	# The developer console's shortcuts work in the real scene.
	DevConsole.scene_override = level
	var spots: Dictionary = {}
	for place: String in ["house", "shed", "clearing", "overlook", "train"]:
		_expect(DevConsole.execute("tp " + place).contains("Teleported"), "tp " + place + " works")
		spots[place] = player.global_position
		_expect(is_finite(player.global_position.y) and player.global_position.y > -60.0, "  on the ground (y %.1f)" % player.global_position.y)

	_expect((spots["house"] as Vector3).distance_to(spots["shed"] as Vector3) > 20.0, "the places are different spots")
	_expect(absf((spots["overlook"] as Vector3).y - (-17.5)) < 3.0, "the overlook spot is on the overlook plateau, not at the height of the last place (y %.1f)" % (spots["overlook"] as Vector3).y)
	DevConsole.scene_override = null
	level.queue_free()
	await get_tree().process_frame


## Jumping into the finale (the developer console) in the first seconds of the scene, while the dream intro's own
## opening (its black cover, head raise and wagon flicker) is still playing: the opening is cut short, so it
## does not black the picture out or take the controls in the middle of the wake-up.
func _check_early_jump() -> void:
	print("-- jumping into the wagon while the opening still plays")
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "finale_early_start", "SAVE_LOCATION_DREAM_INTRO")
	var level: Node = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait(0.3)
	var finale: DreamFinale = level.get_node("Finale") as DreamFinale
	var player: Node3D = level.get_node("Player")
	var intro: Node = null
	for child: Node in level.get_children():
		if child.has_method("skip_opening"):
			intro = child

	_expect(intro != null and not bool(intro.get("head_raise_finished")), "the opening is still playing")
	finale.change_scene_at_end = false
	finale.wagon_fade_in_seconds = 1.5
	finale.start_in_wagon()
	_expect(intro != null and bool(intro.get("opening_cancelled")), "the jump cut the opening short")
	var rect: ColorRect = intro.get("blackout_rect") as ColorRect
	await _until(func() -> bool: return not player.get("cutscene_frozen"), "the wake-up ending", 14.0)
	await _wait(1.0)
	_expect(not rect.visible, "the opening's black cover is gone")
	var wagon_node: Node3D = level.get_node("Train/Wagons/TrainWagon")
	_expect(wagon_node.to_local(player.global_position).y > 0.0 and (player as CharacterBody3D).is_on_floor(), "the player stands on the wagon floor (local y %.2f)" % wagon_node.to_local(player.global_position).y)
	_expect(finale._black_rect.modulate.a < 0.05, "the picture is clear")
	_expect(not player.get("cutscene_frozen") and not player.get("view_locked"), "and the player has the controls")
	var lit: bool = false
	for i: int in 90:
		await get_tree().physics_frame
		for light: OmniLight3D in finale._wagon_lights:
			if light.visible and light.light_energy > 0.02:
				lit = true

	_expect(lit, "the wagon's lights are not put out by the opening")
	_expect(not bool(player.get("flashlight_controller").get("flashlight_on")), "and the flashlight is left for the player to switch on")
	_expect(finale.stage == DreamFinale.Stage.APPROACH, "nothing else has taken the scene over")
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
