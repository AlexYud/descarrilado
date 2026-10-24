extends Node

## The horror transition under the end of the overlook call: it ends as the dialogue ends (so that the sound meets the end of
## the scene just before the cut to the wagon). It only plays for the call the finale takes over. Run it as a scene; it
## quits by itself with a non-zero exit code on failure. Game time runs faster so the call does not take its 38 seconds.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_transition_audio_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/overlook_phone_playtest.tscn"
const TIME_SCALE: float = 4.0
const FICHAS: Array[String] = ["juliana_ficha", "lucas_ficha", "sophia_ficha"]

var test_failed: bool = false


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "transition_audio_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.set_state_value(&"puzzles", &"orelhao_fichas", FICHAS)
	GameSettings.set_captions_enabled(true, false)
	GameSettings.set_text_locale("en", false)

	var level: Node = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var phone: OverlookPhoneSequence = level.get_node("OverlookPhone")
	var player: Node3D = level.get_node("Player")
	phone.release_player_after_call_seconds = 0.0
	Engine.time_scale = TIME_SCALE
	await _run(phone, player)

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("TRANSITION_AUDIO_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run(phone: OverlookPhoneSequence, player: Node3D) -> void:
	var audio: AudioStreamMP3 = phone.transition_audio as AudioStreamMP3
	_expect(audio != null and audio.resource_path.ends_with("placeholder_horror_transition.mp3"), "the call has placeholder_horror_transition")
	var last_end: float = 0.0
	for cue: Dictionary in CaptionTracks.get_cues(phone.call_track):
		last_end = maxf(last_end, float(cue["end"]))

	var length: float = audio.get_length()
	_expect(absf(phone.get_transition_delay() - (last_end - length)) < 0.01 and phone.get_transition_delay() > 20.0, "it is to start %.1f s into the call (the last caption ends at %.1f s, the sound is %.1f s long)" % [phone.get_transition_delay(), last_end, length])

	# The call the finale takes over: the sound plays and ends with the dialogue.
	phone.finale_takes_over = true
	var clock: Array[float] = [0.0]
	var picked_at: Array[float] = [-1.0]
	var started_at: Array[float] = [-1.0]
	var cut_at: Array[float] = [-1.0]
	phone.receiver_picked_up.connect(func() -> void: picked_at[0] = _game_seconds())
	phone.line_cut.connect(func() -> void: cut_at[0] = _game_seconds())
	phone.use_booth(player)
	var waited: float = 0.0
	while cut_at[0] < 0.0 and waited < 40.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / Engine.time_scale
		if started_at[0] < 0.0 and phone.transition_player != null and phone.transition_player.playing:
			started_at[0] = _game_seconds()
			_expect(picked_at[0] >= 0.0, "it starts during the call")

	_expect(started_at[0] > 0.0 and cut_at[0] > 0.0, "the sound started (%.1f) and the call was cut (%.1f)" % [started_at[0], cut_at[0]])
	var started_after: float = started_at[0] - picked_at[0]
	_expect(absf(started_after - phone.get_transition_delay()) < 1.0, "it started %.1f s into the call, as planned (%.1f s)" % [started_after, phone.get_transition_delay()])
	# The line is cut 0.35 s after the last caption ends: the sound's end is the dialogue's end.
	var sound_end: float = started_at[0] + length
	var dialogue_end: float = cut_at[0] - 0.35
	_expect(absf(sound_end - dialogue_end) < 1.0, "the end of the sound (%.1f) meets the end of the dialogue (%.1f)" % [sound_end, dialogue_end])
	_expect(phone.transition_player != null and phone.transition_player.volume_db == phone.transition_volume_db, "it plays at its set volume")

	# A call the finale does not take over (the playtest of the booth alone) has no transition: checked on the delay logic.
	phone.finale_takes_over = false
	phone.transition_player = null
	phone._play_transition_audio()
	_expect(phone.transition_player == null, "without the finale there is no transition sound")


func _game_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0 * Engine.time_scale


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
