extends Node

## The opening narration: Juliana's voice-over (subtitles only for now, a slot for a recording later) over the menu's train cinematic. The idle menu says nothing; Start
## begins one narration, once; its first caption comes 3 s after the click; every caption is one line, in order, the parts of a sentence never blink out between them; the
## camera glide is slowed to end with the last line before the black plus a short ambient tail and only then do the lights fail; the last sentence is said in the black
## of the transition, which is the next scene's (the narration is held while it is built, and the next scene lets it go, then begins right after the last word); skipping, leaving for the menu, replaying, captions off and a recording in the slot all end cleanly. Run it as a scene; it quits by itself with a non-zero exit code on failure.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_intro_narration_smoke"
const MENU_SCENE: String = "res://scenes/menu/main_menu.tscn"
const TIME_SCALE: float = 8.0

## The approved Portuguese words, in order (punctuation as approved).
const APPROVED_PT: String = "A Fenda tem o tamanho exato do que falta. Quando cheguei, ainda pequena, pensei que as montanhas tivessem se afastado para deixar alguma coisa passar. E se esquecido de voltar ao lugar. As casas foram ficando. A chuva aprendeu a morar nas paredes. O ferro amanhecia vermelho. À noite, havia janelas que continuavam acesas como se a noite ainda devesse alguém. Naquela viagem, contei as luzes pela janela do trem. Se uma se apagava, começava de novo. Eu ainda não sabia onde íamos morar. Mas tive a impressão de que alguém havia deixado uma delas acesa para mim. Hoje, quando fecho os olhos, aquela luz continua acesa. A casa em volta é que eu já não consigo encontrar."

const APPROVED_EN: String = "The Fenda is the exact size of what is missing. When I first arrived, still a little girl, I thought the mountains had moved apart to let something pass. And forgotten to move back. The houses stayed. The rain learned to live in the walls. The iron woke red. At night, some windows would stay lit as though the night still had someone to return. On that journey, I counted the lights through the train window. If one went out, I would start again. I didn't yet know where we were going to live. But I had the feeling that someone had left one of them on for me. Today, when I close my eyes, that light is still on. It's the house around it that I can no longer find."

var test_failed: bool = false

var menu: Node = null
var controller: Node = null
var audio: Node = null
var animation_player: AnimationPlayer = null

# What is recorded every frame of a run.
var recording: bool = false
var sim_time: float = 0.0
var texts: Array[String] = []
var text_times: Array[float] = []
var panel_gaps: Array[float] = []
var max_lines: int = 0
var raw_markup: bool = false
var brake_time: float = -1.0
var black_time: float = -1.0
var finished_time: float = -1.0
var transition_end_time: float = -1.0
var visible_at_brake: bool = false
var panel_was_up_before_black: bool = false
var intro_start_time: float = -1.0
var intro_start_position: Vector3 = Vector3.ZERO
var brake_start_position: Vector3 = Vector3.ZERO
var last_text: String = ""
var captions_on: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.set_text_locale("en", false)
	GameSettings.set_captions_enabled(true, false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	for slot_id: int in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot_id)
	audio = get_node_or_null("/root/PersistentAudio")
	_expect(audio != null, "the persistent audio autoload is there")
	if audio == null:
		_finish()
		return

	_check_texts()
	_check_old_voice_is_gone()
	await _check_idle_menu()
	await _check_full_run()
	await _check_leaving_for_the_menu_and_replay()
	await _check_captions_off()
	await _check_recording_slot()
	await _check_hold_across_a_scene_change()
	await _check_dream_intro_waits_for_the_last_sentence()
	await _check_dream_intro_waits_for_the_hand_over()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	Input.action_release(&"skip_cinematic")
	for slot_id: int in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot_id)
	SaveManager.suspend_session(false)
	print("INTRO_NARRATION_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


# ============================================================
# THE TEXT
# ============================================================

func _check_texts() -> void:
	var cues: Array = CaptionTracks.get_cues(CaptionTracks.INTRO_NARRATION)
	_expect(cues.size() == 20, "twenty one-line cues in the opening track (%d)" % cues.size())
	var ordered: bool = true
	var overlapping: bool = false
	for i: int in cues.size():
		var cue: Dictionary = cues[i]
		ordered = ordered and float(cue["end"]) > float(cue["start"])
		if i > 0:
			overlapping = overlapping or float(cue["start"]) < float((cues[i - 1] as Dictionary)["end"]) - 0.0001
	_expect(ordered and not overlapping, "every cue has a length, and none overlaps the one before")
	_expect(is_equal_approx(float((cues[0] as Dictionary)["start"]), 3.0), "the first caption comes 3 s after the click")
	var black_index: int = CaptionTracks.INTRO_BLACK_CUE_INDEX
	_expect(black_index == 18 and black_index < cues.size(), "the last two cues are the ones said in the black")
	_expect(float((cues[black_index - 1] as Dictionary)["end"]) < float((cues[black_index] as Dictionary)["start"]) - 3.0, "with the ambient tail and the failing lights between them and the line before")
	var span: float = 0.0
	for i: int in range(black_index, cues.size()):
		span += float((cues[i] as Dictionary)["end"]) - float((cues[i] as Dictionary)["start"])
	_expect(span > 4.0 and span < 5.2, "the last sentence has its time to be read (%.1f s)" % span)
	var speakers: bool = false
	for cue: Dictionary in cues:
		speakers = speakers or cue.has("speaker")
	_expect(not speakers, "no speaker tag on the voice-over (as before)")

	for locale: String in ["pt_BR", "en"]:
		GameSettings.set_text_locale(locale, false)
		var whole: PackedStringArray = []
		var clean: bool = true
		var max_line_chars: int = 0
		var max_cue_lines: int = 0
		for cue: Dictionary in cues:
			var text: String = CaptionManager._translate(str(cue["key"]))
			whole.append(text.replace("\n", " "))
			clean = clean and not text.contains("CAPTION_INTRO") and not text.contains("<br>") and not text.contains("\\n") and not text.is_empty()
			max_cue_lines = maxi(max_cue_lines, text.split("\n").size())
			for line: String in text.split("\n"):
				max_line_chars = maxi(max_line_chars, line.length())
				clean = clean and not line.begins_with(" ") and not line.ends_with(" ")
		var joined: String = " ".join(whole)
		var expected: String = APPROVED_PT if locale == "pt_BR" else APPROVED_EN
		_expect(joined.split(" ", false) == expected.split(" ", false), "%s: every approved word, in order, with the approved punctuation" % locale)
		_expect(clean, "%s: no raw key, no literal break markup, no stray spaces at a line's ends" % locale)
		_expect(max_cue_lines == 1 and max_line_chars <= 48, "%s: every caption is one line of at most 48 characters (%d lines, %d characters)" % [locale, max_cue_lines, max_line_chars])
	var pt: PackedStringArray = []
	GameSettings.set_text_locale("pt_BR", false)
	for cue: Dictionary in cues:
		pt.append(CaptionManager._translate(str(cue["key"])))
	_expect(pt[2].ends_with("afastado") and pt[3].begins_with("para deixar"), "pt_BR: a sentence split in parts goes on across the change, with nothing added at the end of a part")
	_expect(not pt[1].ends_with(".") and not pt[1].ends_with("...") and not pt[8].ends_with(".") and not pt[8].ends_with("..."), "and the others too")
	_expect(pt[18] == "A casa em volta" and pt[19] == "é que eu já não consigo encontrar.", "the last sentence is the last two parts")
	var splits: bool = true
	for i: int in range(1, cues.size()):
		var gap: float = float((cues[i] as Dictionary)["start"]) - float((cues[i - 1] as Dictionary)["end"])
		var previous_ends_sentence: bool = pt[i - 1].ends_with(".") or pt[i - 1].ends_with("!")
		if not previous_ends_sentence:
			splits = splits and absf(gap) < 0.001
	_expect(splits, "the parts of a sentence share a timestamp (no gap and no overlap inside a sentence)")
	var forbidden: bool = false
	for text: String in pt:
		forbidden = forbidden or text.to_lower().contains("memórias") or text.to_lower().contains("janelas escuras") or text.to_lower().contains("sempre")
	_expect(not forbidden, "none of the rejected endings is left")
	GameSettings.set_text_locale("en", false)


func _check_old_voice_is_gone() -> void:
	var player: AudioStreamPlayer = audio.get("intro_narration_player") as AudioStreamPlayer
	_expect(player != null and player.stream == null, "the old recording is not on the narration player")
	_expect(audio.get("intro_narration_english") == null and audio.get("intro_narration_brazilian_portuguese") == null, "and no recording is assigned in either voice language (empty slots, ready for the new ones)")
	_expect(not bool(audio.call("is_intro_narration_running")), "nothing is narrating at the start")


# ============================================================
# THE MENU, ONCE STARTED
# ============================================================

func _make_menu() -> void:
	menu = (load(MENU_SCENE) as PackedScene).instantiate()
	controller = menu.get_node("MenuController")
	controller.set("play_menu_idle_audio", false)
	controller.set("change_scene_after_animation", false)
	add_child(menu)
	animation_player = controller.get("camera_animation_player") as AnimationPlayer


func _drop_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null
	controller = null
	animation_player = null
	await get_tree().process_frame
	await get_tree().process_frame


func _check_idle_menu() -> void:
	_make_menu()
	await get_tree().process_frame
	await _wait_real(2.5)
	_expect(not bool(audio.call("is_intro_narration_running")) and not CaptionManager.panel.visible, "waiting in the menu starts no narration and shows no caption")
	_expect(animation_player != null and not animation_player.is_playing() and is_zero_approx(animation_player.current_animation_position), "and the camera is parked at the start of the glide")
	await _drop_menu()


func _start_recording() -> void:
	texts.clear()
	text_times.clear()
	panel_gaps.clear()
	max_lines = 0
	raw_markup = false
	brake_time = -1.0
	black_time = -1.0
	finished_time = -1.0
	transition_end_time = -1.0
	visible_at_brake = false
	panel_was_up_before_black = false
	intro_start_time = -1.0
	last_text = ""
	sim_time = 0.0
	recording = true


func _process(delta: float) -> void:
	if not recording:
		return

	sim_time += delta
	if intro_start_time < 0.0 and animation_player != null and animation_player.is_playing() and animation_player.current_animation == "Intro":
		intro_start_time = sim_time
		var camera: Camera3D = controller.get("menu_camera") as Camera3D
		intro_start_position = camera.position if camera != null else Vector3.ZERO
	if brake_time < 0.0 and animation_player != null and animation_player.current_animation == "BreakDip" and animation_player.is_playing():
		brake_time = sim_time
		var camera: Camera3D = controller.get("menu_camera") as Camera3D
		brake_start_position = camera.position if camera != null else Vector3.ZERO

	var black: ColorRect = controller.get("blackout_rect") as ColorRect
	if black_time < 0.0 and brake_time >= 0.0 and black != null and black.modulate.a >= 0.99:
		black_time = sim_time
	if brake_time >= 0.0 and transition_end_time < 0.0 and not bool(controller.get("transition_running")):
		transition_end_time = sim_time
	if finished_time < 0.0 and sim_time > 30.0 and not bool(audio.call("is_intro_narration_running")):
		finished_time = sim_time
	if brake_time < 0.0:
		panel_was_up_before_black = panel_was_up_before_black or CaptionManager.panel.visible
	if brake_time >= 0.0 and visible_at_brake == false and absf(sim_time - brake_time) < 0.05:
		visible_at_brake = CaptionManager.panel.visible

	if CaptionManager.panel.visible:
		var shown: String = CaptionManager.label.text
		if shown != last_text:
			last_text = shown
			texts.append(shown)
			text_times.append(sim_time)
		max_lines = maxi(max_lines, shown.split("\n").size())
		raw_markup = raw_markup or shown.contains("<br>") or shown.contains("\\n") or shown.contains("CAPTION_INTRO")
	elif captions_on:
		panel_gaps.append(sim_time)


func _start_game() -> void:
	controller.call("_on_new_game_slot_selected", 1)


func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _check_full_run() -> void:
	captions_on = true
	GameSettings.set_captions_enabled(true, false)
	_make_menu()
	await get_tree().process_frame
	var before: int = int(audio.get("narration_request_id"))
	Engine.time_scale = TIME_SCALE
	_start_recording()
	_start_game()
	# Pressing Start again (or its slot) while it plays changes nothing.
	_start_game()
	controller.call("_on_new_game_slot_selected", 1)
	await get_tree().process_frame
	_expect(int(audio.get("narration_request_id")) - before == 1, "Start begins one narration, once, however often it is pressed")
	_expect(bool(audio.call("is_intro_narration_running")), "and it is running")
	var waited: float = 0.0
	while controller != null and (bool(controller.get("transition_running")) or bool(audio.call("is_intro_narration_running"))) and waited < 120.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	recording = false
	Engine.time_scale = 1.0
	if transition_end_time < 0.0:
		transition_end_time = sim_time
	_expect(waited < 120.0, "the whole opening completes (no deadlock) in %.1f real seconds" % waited)
	_analyse_full_run()
	await _drop_menu()


func _analyse_full_run() -> void:
	var expected: Array[String] = []
	for cue: Dictionary in CaptionTracks.get_cues(CaptionTracks.INTRO_NARRATION):
		expected.append(CaptionManager._translate(str(cue["key"])))
	_expect(texts == expected, "the twenty captions appear once each, in order (%d seen)" % texts.size())
	_expect(max_lines == 1 and not raw_markup, "always one line, no raw key, no literal break markup (%d lines)" % max_lines)
	var cues: Array = CaptionTracks.get_cues(CaptionTracks.INTRO_NARRATION)
	var late: float = 0.0
	for i: int in mini(texts.size(), cues.size()):
		late = maxf(late, absf(text_times[i] - float((cues[i] as Dictionary)["start"])))
	_expect(late < 0.6, "each appears at its time (%.2f s off at the worst, one frame being %.2f s at this speed)" % [late, 1.0 / 60.0 * TIME_SCALE])
	var blink: bool = false
	var boundaries: int = 0
	for i: int in range(1, cues.size()):
		var boundary: float = float((cues[i] as Dictionary)["start"])
		if absf(boundary - float((cues[i - 1] as Dictionary)["end"])) < 0.001:
			boundaries += 1
			for t: float in panel_gaps:
				blink = blink or (t > boundary - 0.3 and t < boundary + 0.3)
	_expect(boundaries == 9 and not blink, "no blank frame where a sentence goes on across a change of part (%d such changes)" % boundaries)
	_expect(not CaptionManager.panel.visible and not bool(audio.call("is_intro_narration_running")), "at the end nothing is left on screen or narrating")
	_expect(text_times.size() > 0 and text_times[0] > 2.8 and text_times[0] < 3.5, "the dialogue begins 3 s after Start (%.2f s)" % (text_times[0] if text_times.size() > 0 else -1.0))
	_expect(intro_start_time > 1.5 and intro_start_time < 2.6, "the camera begins its glide as the menu has cleared (%.2f s)" % intro_start_time)
	_expect(brake_time > 0.0, "the braking sequence is reached")
	var lights_after: float = float((cues[CaptionTracks.INTRO_BLACK_CUE_INDEX - 1] as Dictionary)["end"])
	var tail: float = brake_time - lights_after
	_expect(tail > 2.2 and tail < 3.3, "the brake / lights sequence begins 2 to 3 s after the last caption before the black ends (%.2f s after it, at %.2f s)" % [tail, brake_time])
	_expect(not visible_at_brake, "and no caption is up when it begins")
	var glide: float = brake_time - intro_start_time
	_expect(glide > 55.0 and glide < 60.5, "the camera glide, slowed to the narration, lasts %.1f s (it was 28.5 s)" % glide)
	var last_start: float = float((cues[CaptionTracks.INTRO_BLACK_CUE_INDEX] as Dictionary)["start"])
	_expect(black_time > brake_time and black_time < brake_time + 2.0, "the screen goes black after the brake (%.2f s after it)" % (black_time - brake_time))
	_expect(text_times.size() == 20 and text_times[18] > black_time + 0.2 and text_times[18] < black_time + 1.5, "the last sentence begins a moment after the black is complete (%.2f s after it)" % (text_times[18] - black_time if text_times.size() == 20 else -1.0))
	_expect(text_times.size() == 20 and text_times[17] < brake_time - 1.0, "and none of it is said before: the line before it was over %.1f s before the brake" % (brake_time - text_times[17] if text_times.size() == 20 else 0.0))
	_expect(finished_time > last_start + 3.0, "the last sentence is said to its end (the narration ends at %.2f s)" % finished_time)
	_expect(transition_end_time > 0.0 and transition_end_time < black_time + 0.6, "and the menu's part is over at the black (%.2f s after it): the next scene is built next, with the narration held, and begins when the sentence is over" % (transition_end_time - black_time))
	_expect(intro_start_position.distance_to(Vector3(-2.5982728, 1.5710266, 61.894657)) < 0.5, "it starts where it always did")
	_expect(brake_start_position.distance_to(Vector3(1.243, 1.5, 2.789)) < 0.06, "and arrives where it always did, at Juliana's seat, before the brake (%s)" % str(brake_start_position))


# ============================================================
# EXITS, REPLAY, CAPTIONS OFF, A RECORDING
# ============================================================

func _check_leaving_for_the_menu_and_replay() -> void:
	captions_on = true
	_make_menu()
	await get_tree().process_frame
	Engine.time_scale = TIME_SCALE
	_start_game()
	var polled: float = 0.0
	while not CaptionManager.panel.visible and polled < 4.0:
		await get_tree().process_frame
		polled += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	_expect(bool(audio.call("is_intro_narration_running")) and CaptionManager.panel.visible, "mid-narration a caption is up")
	# What the pause menu's way back to the main menu does to the menu scene: it goes.
	await _drop_menu()
	Engine.time_scale = 1.0
	_expect(not bool(audio.call("is_intro_narration_running")) and not CaptionManager.panel.visible, "leaving for the menu stops the narration and clears the caption")

	# A fresh menu, and Start again: it narrates from its beginning.
	_make_menu()
	await get_tree().process_frame
	await _wait_real(0.3)
	_expect(not bool(audio.call("is_intro_narration_running")) and not CaptionManager.panel.visible, "the new menu is quiet")
	Engine.time_scale = TIME_SCALE
	var before: int = int(audio.get("narration_request_id"))
	_start_game()
	await _wait_real(0.8)
	_expect(int(audio.get("narration_request_id")) - before == 1 and bool(audio.call("is_intro_narration_running")), "replaying starts one narration again")
	# Held skip: what the skip does is stop the narration, and the cinematic does not go on to brake.
	audio.call("stop_intro_narration")
	await _wait_real(0.5)
	Engine.time_scale = 1.0
	_expect(not bool(audio.call("is_intro_narration_running")) and not CaptionManager.panel.visible, "stopping it (the skip) leaves no caption or narration behind")
	await _drop_menu()


func _check_captions_off() -> void:
	captions_on = false
	GameSettings.set_captions_enabled(false, false)
	_make_menu()
	await get_tree().process_frame
	Engine.time_scale = TIME_SCALE
	_start_recording()
	_start_game()
	var waited: float = 0.0
	while controller != null and (bool(controller.get("transition_running")) or bool(audio.call("is_intro_narration_running"))) and waited < 120.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	recording = false
	Engine.time_scale = 1.0
	_expect(waited < 120.0 and brake_time > 0.0, "with captions off the opening still completes, and still brakes (%.1f s)" % brake_time)
	_expect(texts.is_empty(), "and no caption was shown")
	GameSettings.set_captions_enabled(true, false)
	captions_on = true
	await _drop_menu()


## A recording in the slot: it is the clock, the captions follow it, and the opening still goes on to the brake when it ends (here a short one).
func _check_recording_slot() -> void:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(22050 * 2 * 3)
	wav.data = bytes
	audio.set("intro_narration_english", wav)
	audio.call("_apply_intro_narration_language")
	var player: AudioStreamPlayer = audio.get("intro_narration_player") as AudioStreamPlayer
	_expect(player.stream == wav, "a recording assigned to the voice language is the one on the player")
	_make_menu()
	await get_tree().process_frame
	_start_recording()
	_start_game()
	await _wait_real(0.5)
	_expect(bool(audio.call("is_intro_narration_running")) and player.playing, "it plays with the Start click")
	_expect(float(audio.call("get_intro_narration_remaining")) < 3.2 and float(audio.call("get_intro_narration_remaining")) > 0.5, "and its own length is the narration's length (%.1f s left)" % float(audio.call("get_intro_narration_remaining")))
	await _wait_real(4.2)
	_expect(not bool(audio.call("is_intro_narration_running")) and not CaptionManager.panel.visible, "when it ends the narration ends and the captions are gone")
	recording = false
	await _drop_menu()
	audio.set("intro_narration_english", null)
	audio.call("_apply_intro_narration_language")
	_expect(player.stream == null, "taking it out again leaves the slot empty")


## Built behind the cinematic, the scene must not begin its opening on its own: it waits for the hand-over (the opening hold), whether or not the narration runs.
func _check_dream_intro_waits_for_the_hand_over() -> void:
	audio.call("hold_opening", true)
	_expect(bool(audio.call("is_opening_held")), "the opening can be held")
	var dream: Node = (load("res://scenes/cinematics/dream_intro.tscn") as PackedScene).instantiate()
	add_child(dream)
	await _wait_real(3.0)
	var black: ColorRect = dream.get_node("TransitionBlackout/BlackoutRect") as ColorRect
	var controller_node: Node = dream.get_node("DreamIntroController")
	var head: AnimationPlayer = controller_node.get("head_raise_animation_player") as AnimationPlayer
	_expect(black.modulate.a > 0.99 and (head == null or not head.is_playing()), "a scene built while it is held stays black and does not begin its opening")
	audio.call("hold_opening", false)
	var waited: float = 0.0
	while black.modulate.a > 0.9 and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_expect(black.modulate.a < 0.9, "and begins it as soon as it is handed over (%.2f s)" % waited)
	dream.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## What the hand-over relies on: a held narration stands still (its caption clock does not run) and goes on from where it was.
func _check_hold_across_a_scene_change() -> void:
	audio.call("play_intro_narration_after_delay", 0.0)
	await _wait_real(1.0)
	var first: float = float(audio.call("get_intro_narration_seconds"))
	audio.call("hold_intro_narration", true)
	_expect(bool(audio.call("is_intro_narration_held")), "the narration can be held")
	await _wait_real(1.2)
	var second: float = float(audio.call("get_intro_narration_seconds"))
	_expect(absf(second - first) < 0.2, "and its clock stands still while it is (%.2f s, then %.2f s)" % [first, second])
	audio.call("hold_intro_narration", false)
	await _wait_real(1.0)
	var third: float = float(audio.call("get_intro_narration_seconds"))
	_expect(third - second > 0.7 and third - second < 1.6, "let go, it goes on from where it was (%.2f s later)" % (third - second))
	audio.call("hold_intro_narration", true)
	audio.call("stop_intro_narration")
	_expect(not bool(audio.call("is_intro_narration_held")) and not bool(CaptionManager.get("_clock_held")), "stopping it lets go of the hold too")


## The next scene is built while the narration is held; when it is ready it lets the narration go and does not begin until the last word has been said, and then begins at once.
func _check_dream_intro_waits_for_the_last_sentence() -> void:
	audio.call("play_intro_narration_after_delay", 0.0)
	await get_tree().process_frame
	audio.call("hold_intro_narration", true)
	var dream: Node = (load("res://scenes/cinematics/dream_intro.tscn") as PackedScene).instantiate()
	add_child(dream)
	var polled: float = 0.0
	while bool(audio.call("is_intro_narration_held")) and polled < 60.0:
		await get_tree().process_frame
		polled += get_process_delta_time()
	_expect(not bool(audio.call("is_intro_narration_held")) and bool(audio.call("is_intro_narration_running")), "the scene, once built, lets the narration go on (%.1f s to build it)" % polled)
	await _wait_real(1.5)
	var black: ColorRect = dream.get_node("TransitionBlackout/BlackoutRect") as ColorRect
	var controller_node: Node = dream.get_node("DreamIntroController")
	var head: AnimationPlayer = controller_node.get("head_raise_animation_player") as AnimationPlayer
	_expect(black.modulate.a > 0.99 and (head == null or not head.is_playing()), "and waits, black, with the opening not begun, while the sentence is said")
	var started: int = Time.get_ticks_msec()
	audio.call("stop_intro_narration")
	var waited: float = 0.0
	while black.modulate.a > 0.9 and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_expect(black.modulate.a < 0.9 and (Time.get_ticks_msec() - started) < 1500, "after the last word the opening begins at once (%d ms)" % (Time.get_ticks_msec() - started))
	dream.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ============================================================
# HELPERS
# ============================================================

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
	else:
		test_failed = true
		push_error("FAIL - " + message)
		print("FAIL - ", message)
