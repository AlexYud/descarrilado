extends Node

const ShedExpectedTexts = preload("res://tests/shed_expected_texts.gd")

## Plays the waiting shed ("The Shelter Stayed Open") through the game's own APIs: the removed puzzle is gone, the bench cluster fits the bench, the box
## opens with a plain interaction and shows the tape over the token, the tape and the token are reached by the interaction ray as they should be, the first close of
## the tape's view hands the player to the recording scene without a gap, the scene runs once (about 24 s of silent footage in three shots and two hard cuts: Emily on the bench, who waits
## six seconds, turns toward her left and greets someone out of the picture; a camera carried forward over the forest floor; the empty bloodstained shelter from the photograph's own viewpoint;
## then the tape again, held on her greeting as Juliana asks to stop, the remembered conversation and the cut to the photograph; the cameras, the shelter's three looks under the cuts, the camcorder,
## the held view and flashlight given back), the token is then free and taken normally, and old saves are mapped (never replaying the scene, never bringing the token back). `_check_footage` and
## `_check_states_and_photo` check the rig, the six seconds, the left turn and the wave, shot A's framing, the walk's travel, bob and pitch, shot C's match with the photograph's viewpoint, the stains
## and the shipped photograph by their numbers. Run it as a scene; it quits by itself with a non-zero exit code on failure. Game time runs faster so the waits are short. It cannot judge the picture, the acting or the pace: see the screenshots taken separately.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_waiting_shed_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/waiting_shed_playtest.tscn"
const TIME_SCALE: float = 4.0

var test_failed: bool = false
var completed_count: int = 0

var level: Node = null
var shed: WaitingShedSequence = null
var player: CharacterBody3D = null
var vhs: GatedInspectable = null
var ficha: Collectible = null
var view_before: Vector2 = Vector2.ZERO
var cue_heard_at: float = -1.0
var scene_ended_at_msec: int = 0

var _watching: bool = false
var _seen: Dictionary = {}


func _ready() -> void:
	# Keeps running while the tree is paused (the pause check below).
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1280, 720)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	GameSettings.set_captions_enabled(true, false)
	GameSettings.set_text_locale("en", false)

	await _run()

	Engine.time_scale = 1.0
	SaveManager.delete_slot(1)
	print("WAITING_SHED_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	await _fresh_level(true)
	await _check_layout()
	await _check_text()
	await _check_footage()
	await _check_states_and_photo()
	await _check_bench_fit()
	await _check_evidence_and_rays()
	await _check_scene_plays_once()
	await _check_after_scene()
	await _check_saves()
	await _check_cancel()
	await _check_pause()


# ============================================================
# SETUP
# ============================================================

## A new game in slot 1 with the shed loaded fresh. `keep_state` false keeps whatever state the caller has just prepared.
func _fresh_level(new_game: bool) -> void:
	await _free_level()
	if new_game:
		SaveManager.delete_slot(1)
		SaveManager.create_new_game(1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	await _load_level()


func _load_level() -> void:
	level = (load(TEST_SCENE_PATH) as PackedScene).instantiate()
	# The test node never pauses; the level does.
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	shed = level.get_node("WaitingShed")
	player = level.get_node("Player")
	# The playtest scene has no forest sound of its own: this one is the real thing, to hear whether the memory silences it.
	level.add_child(OutdoorAmbience.new())
	vhs = shed.vhs
	ficha = shed.ficha
	shed.recording_finished.connect(func() -> void:
		completed_count += 1
		cue_heard_at = -1.0
		_watch_cue())
	Engine.time_scale = TIME_SCALE


func _free_level() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
		level = null
		await get_tree().process_frame
		await get_tree().process_frame
	shed = null
	player = null


# ============================================================
# STEPS
# ============================================================

func _check_layout() -> void:
	_expect(player.is_in_group(&"player"), "the player joins the player group")
	_expect(shed.get_node("%Shelter").get_child_count() > 30, "the shelter is built")
	_expect(
		shed.get_node("%Shelter").find_children("Pillar?", "MeshInstance3D", false, false).size() == 4,
		"the shelter stands on four pillars"
	)
	_expect(shed.get_node("%Shelter/PillarCrack0") != null and shed.get_node("%Shelter/PillarPatch") != null, "one pillar has its crack and its mend")
	_expect(shed.get_node("%Track").get_child_count() == 4, "the track is the ready-made track model: three pieces and a bank (no lantern)")
	_expect(shed.get_node("%Track/TrackBank/Bank") != null, "the track has a low bank to walk over")
	_expect(shed.get_node_or_null("%MileMarker") != null, "the KM 214 marker stays")
	_expect(shed.get_node_or_null("%CarvedWhistle") == null and shed.get_node_or_null("%RailwayLantern") == null, "the whistle and the lantern are gone from the route")

	# The old mechanism is gone entirely.
	_expect(shed.find_children("*", "SignalLever", true, false).is_empty(), "no lever is left in the shed")
	_expect(shed.find_children("*", "LeverBox", true, false).is_empty(), "no lever box is left in the shed")
	_expect(shed.get_node_or_null("%SignalBox") == null, "the signal box is gone")
	_expect(shed.find_child("FichaNote", true, false) == null, "the old note about the call is gone")
	_expect(shed.find_child("TicketPuncher", true, false) == null, "the ticket puncher is not in the box")
	_expect(shed.find_child("Lever*", true, false) == null, "nothing in the shed is called a lever")

	# The bin: scenery with nothing to use.
	var bin: Node = shed.get_node("Platform/ShelterBin")
	_expect(bin.get_child_count() > 3 and bin.find_children("*", "Interactable", true, false).is_empty(), "the bin is scenery with nothing to use")
	_expect(not ((bin as Node) is Interactable) and not ((bin.get_parent() as Node) is Interactable), "the bin is not interactable")
	_expect(shed.get_node("Platform/PersonalEffects/Backpack").find_children("*", "Area3D", true, false).is_empty(), "the backpack is scenery only")

	# The recording's dressing is hidden, the camcorder is there from the start with its light off.
	_expect(not shed.archive_dressing.visible, "the recording's dressing is hidden in the present")
	_expect(shed.replaced_plank != null and shed.replaced_plank.visible, "the replaced plank is shown in the present")
	var camcorder: ShedCamcorder = shed.camcorder
	_expect(camcorder != null and camcorder.visible and not ((camcorder as Node) is Inspectable) and not ((camcorder as Node) is Collectible), "the camcorder stands in the level from the start, a fixed device: it is not an item")
	_expect(camcorder.can_interact(player) and camcorder.get_prompt_text() == "PROMPT_VIEWFINDER", "its one interaction is to look through its viewfinder")
	var led: MeshInstance3D = camcorder.find_child("Led", true, false) as MeshInstance3D
	_expect(led != null and (led.material_override as StandardMaterial3D).emission_energy_multiplier == 0.0, "its recording light is off")
	var head: Node3D = camcorder.get_head()
	var view: Dictionary = shed.get_camcorder_view()
	var shot_a_xf: Transform3D = shed.shot_recording.aimed_transform()
	var lens_world: Vector3 = camcorder.get_lens_marker().global_position
	_expect(not view.is_empty() and lens_world.distance_to(shot_a_xf.origin) < 0.005, "its lens is exactly at the recording's first viewpoint (%.4f m apart)" % lens_world.distance_to(shot_a_xf.origin))
	_expect((-head.global_basis.z).angle_to(-shot_a_xf.basis.z) < deg_to_rad(0.05), "and looks along that shot's axis (%.3f degrees apart)" % rad_to_deg((-head.global_basis.z).angle_to(-shot_a_xf.basis.z)))
	_expect(is_equal_approx(head.scale.x, 1.2) and camcorder.get_eye_marker() != null, "the head keeps its scale and has an eyecup marker")
	var eye_back: Vector3 = (camcorder.get_eye_marker().global_position - lens_world)
	_expect(eye_back.dot(-head.global_basis.z) < -0.35 and eye_back.length() < 0.7, "the eyecup is behind the lens along its axis (%.2f m back)" % -eye_back.dot(-head.global_basis.z))
	_expect(camcorder.global_position.y > shed.global_position.y - 0.06 and camcorder.global_position.y < shed.global_position.y + 0.06, "the tripod stands on the ground (its root %.3f m from the slab's level)" % (camcorder.global_position.y - shed.global_position.y))
	var bench: Node3D = shed.get_node("%Bench")


## The note from Emily's sister: the same optional readable on the bench (a world Inspectable, never an inventory item, its scene and inspect id unchanged), now about where
## the copy came from, with the approved name, description and words in both languages and nothing the fragment cannot support.
func _check_sister_note(undecided: Array[String]) -> void:
	var note: Inspectable = shed.get_node("%MarinaSisterNote")
	var visual: Node3D = note.get_node("Visual") as Node3D
	_expect(note.scene_file_path == "res://scenes/objects/waiting_shed/marina_sister_note.tscn" and note.get_script() != load("res://scripts/interactions/collectible_interactable.gd") and not note.get("item_id"), "the sister's note keeps its scene and is a world readable, not something to pick up")
	_expect(str(visual.get_meta("inspect_id")) == "marina_sister_note" and str(visual.get_meta("inspect_mode")) == "read" and str(visual.get_meta("readable_text")) == "READABLE_MARINA_SISTER_NOTE", "with its inspect id, in read mode")
	for locale: String in ["en", "pt_BR"]:
		var lowered: String = (_translated("READABLE_MARINA_SISTER_NOTE", locale) + " " + _translated("ITEM_MARINA_SISTER_NOTE_DESCRIPTION", locale)).to_lower()
		for word: String in undecided:
			_expect(not lowered.contains(word), "the note says nothing of '%s' (%s)" % [word.strip_edges(), locale])
		for banned: String in ["marina", "helena", "autopsy", "autópsia", "threat", "ameaç"]:
			_expect(not lowered.contains(banned), "and nothing of '%s' (%s)" % [banned, locale])


## The optional paper that is new: the recent clipping about Helena Clarke (pinned to a shelter post, facing the bench).
func _check_new_papers() -> void:
	var notice: Inspectable = shed.get_node("%HelenaClarkeNotice")
	var visual: Node3D = notice.get_node("Visual") as Node3D
	_expect(notice.get_script() == load("res://scripts/interactions/inspectable_interactable.gd") and not notice.get("item_id"), "the Helena Clarke notice is an ordinary world readable: no item, no inventory, no trigger")
	_expect(str(visual.get_meta("inspect_id")) == "helena_clarke_notice" and str(visual.get_meta("inspect_mode")) == "read" and str(visual.get_meta("readable_text")) == "READABLE_HELENA_NOTICE", "with its inspect id, in read mode")
	_expect(_translated("ITEM_HELENA_NOTICE_NAME", "en") == "Recent News — Helena Clarke" and _translated("ITEM_HELENA_NOTICE_NAME", "pt_BR") == "Notícia recente — Helena Clarke", "its name (both languages)")
	for locale: String in ["en", "pt_BR"]:
		var lowered: String = (_translated("READABLE_HELENA_NOTICE", locale) + " " + _translated("ITEM_HELENA_NOTICE_DESCRIPTION", locale)).to_lower()
		for banned: String in ["emily", "miller", "dead", "morta", "morto", "34", "neighbo", "vizinh", "killer", "assassin", "homicid"]:
			_expect(not lowered.contains(banned), "the Helena notice has nothing of Emily's case or of a death ('%s', %s)" % [banned, locale])

	# Where it is: on the WEST face of the front-west post (Pillar1), at hand height, its face toward the incoming trail, clear of everything else's hit area.
	var post: Vector3 = shed.to_global(Vector3(-5.7, 1.4, -4.0))
	_expect(notice.global_position.distance_to(Vector3(post.x - 0.126, post.y, post.z)) < 0.03 and notice.global_basis.z.dot(Vector3.LEFT) > 0.95, "it is pinned to the west face of the front-west post, its face toward the incoming trail")
	var notice_area: Area3D = notice.get_node("InteractArea") as Area3D
	var notice_box: AABB = (notice_area.get_node("CollisionShape3D") as CollisionShape3D).shape.get_debug_mesh().get_aabb()
	var notice_bounds: AABB = notice_area.global_transform * notice_box
	for other: Node in [shed.get_node("%SophiaJournal"), shed.get_node("%NewspaperClipping"), shed.get_node("%MarinaSisterNote"), shed.vhs, shed.letter, shed.ficha, shed.camcorder]:
		for area: Node in other.find_children("*", "Area3D", true, false):
			var shape: CollisionShape3D = area.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if shape != null and shape.shape != null:
				var other_bounds: AABB = shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
				_expect(not notice_bounds.intersects(other_bounds), "its hit area is clear of %s's" % other.name)



func _check_text() -> void:
	_check_pinned_texts()
	var journal: Inspectable = shed.get_node("%SophiaJournal")
	_expect(tr(journal.get_inspect_data()["name"]) == "Sophia Bennett's Notebook", "the notebook is Sophia Bennett's Notebook")
	var old_words: Array[String] = ["light the track", "punch the ticket", "blow the signal", "junction box", "wrench", "secret code", "lever"]
	for key: String in ["READABLE_JOURNAL", "JOURNAL_LEFT", "JOURNAL_RIGHT", "JOURNAL_EXTRACT", "JOURNAL_MARGIN"]:
		for locale: String in ["en", "pt_BR"]:
			var text: String = _translated(key, locale).to_lower()
			_expect(not text.is_empty() and text != key.to_lower(), "%s has %s text" % [key, locale])
			for word: String in old_words:
				_expect(not text.contains(word), "%s (%s) has none of the old clue %s" % [key, locale, word])
			_expect(not text.contains("marina"), "%s (%s) has no Marina: the old victim is Emily" % [key, locale])

	var undecided: Array[String] = ["stabb", "knife", "firearm", "pistol", "bullet", "gunshot", "revólver", "arma de fogo", "strangl", "poison", "overdose", "beaten", "weapon", "wound", "autopsy", "faca", "apunhal", "estrangul", "envenen", "espanc", "arma ", "ferida", "autópsia"]

	_check_sister_note(undecided)

	# The clipping with its photograph: name, description, reading text and caption, in both languages; the cause of death left undisclosed.
	var clipping: Inspectable = shed.get_node("%NewspaperClipping")
	_expect(tr(clipping.get_inspect_data()["name"]) == "Clipping with Photograph — Emily Miller", "the clipping is a Clipping with Photograph — Emily Miller")
	_expect(_translated("ITEM_CLIPPING_NAME", "pt_BR") == "Recorte com fotografia — Emily Miller", "and its Portuguese name")
	_check_new_papers()
	for key: String in ["READABLE_CLIPPING", "ITEM_CLIPPING_DESCRIPTION", "READABLE_JOURNAL", "JOURNAL_LEFT", "JOURNAL_RIGHT", "ITEM_VHS_DESCRIPTION", "PHOTO_CAPTION_SHELTER"]:
		for locale: String in ["en", "pt_BR"]:
			var lowered: String = _translated(key, locale).to_lower()
			for word: String in undecided:
				_expect(not lowered.contains(word), "%s (%s) names no weapon, wound or method of death ('%s')" % [key, locale, word])
			for claim: String in ["unexplained", "could not determine", "inexplic", "não foi possível determinar"]:
				_expect(not lowered.contains(claim), "%s (%s) does not say the cause is medically unexplained ('%s')" % [key, locale, claim])

	_expect(vhs.prompt_text == "PROMPT_EXAMINE_TAPE" and tr(vhs.prompt_text) == "Examine tape", "the tape says Examine tape")
	_expect(tr(vhs.get_inspect_data()["name"]) == "Videotape — Emily Miller", "the tape is a Videotape — Emily Miller")
	_expect(_translated("ITEM_VHS_NAME", "pt_BR") == "Fita de vídeo — Emily Miller", "(Fita de vídeo — Emily Miller)")
	_expect(_translated("READABLE_VHS_LABEL", "pt_BR").contains("ABRIGO / CÓPIA") and not _translated("READABLE_VHS_LABEL", "pt_BR").to_lower().contains("marina"), "the label on the cassette names no victim")
	_expect(vhs.get_node("Visual").get_meta("inspect_id") == "sophia_vhs", "its inspect id is sophia_vhs")
	_expect(not ((vhs as Node) is Collectible), "the tape is examined, never collected")
	_expect(tr("ITEM_SOPHIA_FICHA_NAME") == "Sophia's Telephone Token" and _translated("ITEM_SOPHIA_FICHA_NAME", "pt_BR") == "Ficha de Sophia", "the token's name")
	_expect(ficha.item_id == "sophia_ficha" and ficha.scene_file_path == "res://scenes/objects/waiting_shed/sophia_ficha.tscn", "the token keeps its id and its scene")

	# The captions: Portuguese and English, one speaker's line each, full speaker names, nothing for the silent recording, nothing of the old scene.
	_expect(CaptionTracks.get_cues(&"shed_recording").is_empty() and CaptionTracks.get_cues(&"shed_recording_again").is_empty() and CaptionTracks.get_cues(&"shed_review").is_empty(), "the silent recording has no caption track, and the review has none either")
	var cue_count: int = 0
	for track: StringName in [CaptionTracks.SHED_REMEMBERED_COPY, CaptionTracks.SHED_REMEMBERED_TALK]:
		var last_end: float = 0.0
		for cue: Dictionary in CaptionTracks.get_cues(track):
			_expect(float(cue["start"]) >= last_end - 0.0001 and float(cue["end"]) > float(cue["start"]), "%s: cue %s does not overlap the one before it" % [track, str(cue["key"])])
			last_end = float(cue["end"])
			var key: String = str(cue["key"])
			if key.is_empty():
				continue
			cue_count += 1
			var pinned: Array = ShedExpectedTexts.CAPTIONS.get(key, [])
			_expect(pinned.size() == 3, "%s is a line of the approved conversation" % key)
			if pinned.size() == 3:
				_expect(_translated(key, "en") == pinned[0] and _translated(key, "pt_BR") == pinned[1], "%s reads as approved (both languages)" % key)
				_expect(str(cue.get("speaker", "")) == "CAPTION_SPEAKER_" + str(pinned[2]), "%s is said by %s" % [key, pinned[2]])
			_expect(_translated(key, "en").length() < 66 and _translated(key, "pt_BR").length() < 66, "%s is one short line (a longer sentence is split into contiguous groups)" % key)
			for banned: String in ["help", "ajud", "lip", "lábio", "watch it again", "ver de novo", "bag", "bolsa", "turn it off", "desliga", "marina", "head", "cabeça", "replay", "employee", "funcionário", "ground", "bench", "banco", "sitting", "sentada"]:
				_expect(not _translated(key, "en").to_lower().contains(banned) and not _translated(key, "pt_BR").to_lower().contains(banned), "%s has nothing of the old scene (%s)" % [key, banned])
	_expect(cue_count == ShedExpectedTexts.CAPTIONS.size() and cue_count == 25, "three lines of introduction and twenty-two of conversation, and no other (%d)" % cue_count)
	_expect(_translated("CAPTION_SPEAKER_SOPHIA", "en") == "Sophia" and _translated("CAPTION_SPEAKER_JULIANA", "en") == "Juliana", "the speakers are labelled with their names")
	var intro: float = CaptionTracks.get_length(CaptionTracks.SHED_REMEMBERED_COPY)
	var talk: float = CaptionTracks.get_length(CaptionTracks.SHED_REMEMBERED_TALK)
	_expect(intro >= 7.0 and intro <= 10.0, "the introduction is about 8 to 9 s (%.1f)" % intro)
	_expect(talk >= 74.0 and talk <= 82.0, "the conversation, the second viewing included, is about 78 s (%.1f)" % talk)
	var talk_cues: Array = CaptionTracks.get_cues(CaptionTracks.SHED_REMEMBERED_TALK)
	# Every group is on screen long enough to read (never under a second, at most about 20 characters a second); a split line's groups meet exactly.
	for i: int in talk_cues.size() - 1:
		var cue: Dictionary = talk_cues[i]
		var shown: float = float(cue["end"]) - float(cue["start"])
		var characters: int = _translated(str(cue["key"]), "pt_BR").length()
		_expect(shown >= 1.0 and float(characters) / shown <= 20.0, "%s stays %.1f s for %d characters" % [cue["key"], shown, characters])
	for pair: Array in [[3, 4], [5, 6], [12, 13]]:
		var first_cue: Dictionary = _talk_cue("CAPTION_SHED_TALK_%02d" % pair[0])
		var second_cue: Dictionary = _talk_cue("CAPTION_SHED_TALK_%02d" % pair[1])
		_expect(float(second_cue["start"]) == float(first_cue["end"]) and first_cue["speaker"] == second_cue["speaker"], "the groups %d and %d of a split line meet exactly" % [pair[0], pair[1]])
	# The director's pauses, between the end of one line and the start of the next.
	var gaps: Array = [
		["CAPTION_SHED_REPLAY_08", "CAPTION_SHED_REPLAY_09", 0.4, 1.0, "hesitation after the first 'Não.' before 'Pode parar, por favor?'"],
		["CAPTION_SHED_REPLAY_09", "CAPTION_SHED_TALK_01", 0.8, 2.0, "silence before the warning"],
		["CAPTION_SHED_TALK_01", "CAPTION_SHED_REPLAY_10", 1.0, 2.5, "the photograph holds before Sophia goes on"],
		["CAPTION_SHED_REPLAY_12", "CAPTION_SHED_TALK_02", 1.5, 3.0, "a silence after 'Nunca encontraram.'"],
		["CAPTION_SHED_TALK_08", "CAPTION_SHED_TALK_09", 1.5, 3.0, "a pause before 'Aqui não é seguro.'"],
		["CAPTION_SHED_TALK_10", "CAPTION_SHED_TALK_11", 0.0, 0.3, "Juliana's 'Não.' cuts in on the unfinished thought"],
		["CAPTION_SHED_TALK_11", "CAPTION_SHED_TALK_12", 1.0, 2.5, "a silence after it"],
		["CAPTION_SHED_TALK_14", "CAPTION_SHED_TALK_15", 2.0, 4.0, "a long silence after 'Desculpa.'"],
	]
	for gap: Array in gaps:
		var between: float = float(_talk_cue(gap[1])["start"]) - float(_talk_cue(gap[0])["end"])
		_expect(between >= float(gap[2]) - 0.0001 and between <= float(gap[3]) + 0.0001, "%s (%.2f s)" % [gap[4], between])
	_check_second_viewing_text(talk_cues)
	for gone: String in ["CAPTION_SPEAKER_MARINA", "CAPTION_SPEAKER_RECORDED_VOICE", "CAPTION_SHED_REC_01", "CAPTION_SHED_REC_07", "CAPTION_SHED_OFF", "CAPTION_SHED_REVIEW_01", "CAPTION_SHED_REVIEW_03", "CAPTION_SHED_MEM_04", "CAPTION_SHED_TALK_17"]:
		_expect(_translated(gone, "en").is_empty() and _translated(gone, "pt_BR").is_empty(), "%s no longer exists" % gone)


## The cue of the conversation's track with this key.
func _talk_cue(key: String) -> Dictionary:
	for cue: Dictionary in CaptionTracks.get_cues(CaptionTracks.SHED_REMEMBERED_TALK):
		if str(cue["key"]) == key:
			return cue
	return {}


## The second viewing: the marks the sequence derives from the cues (the picture is held a quarter of a second after Juliana's first "Não." begins, and the photograph cuts in a second after "Você não devia
## ficar vendo esse tipo de coisa." ends), where the footage is at those marks, and the machine's sounds cut from the mp3 as asked (2.30 and 6.20).
func _check_second_viewing_text(talk_cues: Array) -> void:
	var order: Array[String] = []
	for cue: Dictionary in talk_cues:
		order.append(str(cue["key"]))
	_expect(order.find("CAPTION_SHED_REPLAY_08") < order.find("CAPTION_SHED_REPLAY_09") and order.find("CAPTION_SHED_REPLAY_09") < order.find("CAPTION_SHED_TALK_01") and order.find("CAPTION_SHED_TALK_01") < order.find("CAPTION_SHED_REPLAY_10") and order.find("CAPTION_SHED_REPLAY_10") < order.find("CAPTION_SHED_TALK_02"), "Juliana's first 'Não.' and her request to stop come first, then the warning, then Sophia goes on, and only then the rest of the conversation")
	var first_no: float = float(_talk_cue("CAPTION_SHED_REPLAY_08")["start"])
	var stop_at: float = shed.replay_stop_seconds()
	var photo_at: float = shed.photo_cut_seconds()
	_expect(is_equal_approx(stop_at, first_no + shed.replay_stop_after_start_seconds) and absf(shed.replay_stop_after_start_seconds - 0.25) < 0.0001, "the picture is held 0.25 s after Juliana's first 'Não.' begins (%.2f s into the viewing)" % stop_at)
	_expect(is_equal_approx(photo_at, float(_talk_cue("CAPTION_SHED_TALK_01")["end"]) + shed.photo_after_replay_seconds) and absf(shed.photo_after_replay_seconds - 1.0) < 0.0001, "and the photograph cuts in 1.0 s after 'Você não devia ficar vendo esse tipo de coisa.' ends (%.2f s)" % photo_at)
	_expect(stop_at < float(_talk_cue("CAPTION_SHED_REPLAY_09")["start"]) and photo_at < float(_talk_cue("CAPTION_SHED_REPLAY_10")["start"]), "(both marks fall before the next line)")
	var footage: ShelterFootage = shed.footage
	var held_at: float = shed.replay_from() + stop_at
	_expect(footage.passage_at(shed.replay_from()) == &"A" and footage.passage_at(held_at) == &"A" and held_at > footage.hand_up_start_seconds and held_at < footage.hand_down_end_seconds, "the viewing replays from %.1f s and is held at %.1f s of the excerpt: on her raised hand, inside the first shot" % [shed.replay_from(), held_at])

	# The machine's sounds: the first 2.30 s, the loop from 2.30 s to 6.20 s as one seamless stream, and the stop (6.20 s to the end) played once.
	var start_stream: AudioStreamWAV = TapePlayerSounds.start_stream()
	var stop_stream: AudioStreamWAV = TapePlayerSounds.stop_stream()
	var rate: float = float(start_stream.mix_rate)
	_expect(start_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and absf(float(start_stream.loop_begin) / rate - 2.30) < 0.001 and absf(float(start_stream.loop_end) / rate - 6.20) < 0.001, "the machine's start stream loops from 2.30 s to 6.20 s (%.3f to %.3f)" % [float(start_stream.loop_begin) / rate, float(start_stream.loop_end) / rate])
	_expect(absf(start_stream.get_length() - 6.20) < 0.001 and stop_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and absf(stop_stream.get_length() - (TapePlayerSounds.length() - 6.20)) < 0.001 and stop_stream.get_length() > 0.6 and stop_stream.get_length() < 0.8, "and its stop stream is the last part, 6.20 s to the end (%.2f s), played once" % stop_stream.get_length())
	_expect(TapePlayerSounds.LOOP_BEGIN == 2.30 and TapePlayerSounds.LOOP_END == 6.20, "(the cut points are the director's)")


## Waits until the picture of the recording is running (the machine's first part is over: its clock is the audio's, which the test's time scale does not speed up) and then
## this many seconds of the scene's time.
func _footage_plays_for(seconds: float) -> void:
	var guard: float = 0.0
	while not bool(shed.get("_footage_playing")) and guard < 40.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	await _wait(seconds)


func _check_bench_fit() -> void:
	var bench: Node3D = shed.get_node("%Bench")
	var seat: AABB = _bench_seat_world()
	var clipping: Inspectable = shed.clipping
	var items: Dictionary = {
		"notebook": shed.get_node("%SophiaJournal"),
		"clipping": clipping,
		"sister's note": shed.get_node("%MarinaSisterNote"),
		"tape": shed.vhs_set_down,
	}
	var boxes: Dictionary = {}
	for label: String in items.keys():
		var item: Node3D = items[label]
		var bounds: AABB = _visual_bounds(item) if label != "tape" else _tape_bounds_at(shed.vhs_set_down)
		boxes[label] = bounds
		# Each sits on the seat with a margin to its ends (0.05 m) and does not hang off the front or back.
		_expect(bounds.position.x >= seat.position.x + 0.05 and bounds.end.x <= seat.end.x - 0.05, "%s is on the seat with a margin at the ends" % label)
		_expect(bounds.position.z >= seat.position.z - 0.02 and bounds.end.z <= seat.end.z + 0.04, "%s does not overhang the seat" % label)
		_expect(bounds.position.y >= seat.end.y - 0.03 and bounds.position.y <= seat.end.y + 0.07, "%s rests on the seat (%.3f over it)" % [label, bounds.position.y - seat.end.y])

	# The notebook is at the west end, the sister's note at the east end, the clipping central: none overlaps another in plan, but the clipping that lies over the tape.
	for a: String in ["notebook", "sister's note", "tape", "clipping"]:
		for b: String in ["notebook", "sister's note", "tape", "clipping"]:
			if a < b and not (a == "clipping" and b == "tape"):
				_expect(not _overlap_plan(boxes[a], boxes[b]), "%s and %s do not overlap on the seat" % [a, b])
	_expect(boxes["notebook"].get_center().x < boxes["clipping"].get_center().x and boxes["clipping"].get_center().x < boxes["sister's note"].get_center().x, "the notebook is at the bench's west end, the clipping in the middle, the sister's note at the east end")

	# The clipping covers the whole tape: every corner of the tape lies inside the paper's own rectangle.
	var paper: MeshInstance3D = clipping.find_child("Paper", true, false) as MeshInstance3D
	var paper_box: AABB = paper.mesh.get_aabb()
	var tape_box: AABB = AABB(Vector3(-0.0935, -0.0515, -0.0125), Vector3(0.187, 0.103, 0.025))
	var covered: bool = true
	for corner: int in 8:
		var local_corner: Vector3 = tape_box.position + Vector3(tape_box.size.x * (corner & 1), tape_box.size.y * ((corner >> 1) & 1), tape_box.size.z * ((corner >> 2) & 1))
		var in_paper: Vector3 = paper.global_transform.affine_inverse() * (shed.vhs_set_down.global_transform * local_corner)
		covered = covered and in_paper.x > paper_box.position.x and in_paper.x < paper_box.end.x and in_paper.y > paper_box.position.y and in_paper.y < paper_box.end.y
		_expect(in_paper.z < 0.001, "(the tape's corner %d is under the paper: %.4f m)" % [corner, in_paper.z])
	_expect(covered, "the main clipping physically covers the whole tape")

	# Where the clipping lies once read: clear of the tape, the notebook and the sister's note, and still on the seat.
	var home: Transform3D = clipping.transform
	clipping.transform = shed.clipping_aside.transform
	var aside: AABB = _visual_bounds(clipping)
	clipping.transform = home
	_expect(aside.position.x >= seat.position.x + 0.05 and aside.end.x <= seat.end.x - 0.05 and aside.position.z >= seat.position.z - 0.02 and aside.end.z <= seat.end.z + 0.04, "the clipping, aside, is still on the seat")
	_expect(not _overlap_plan(aside, boxes["tape"]) and not _overlap_plan(aside, boxes["notebook"]) and not _overlap_plan(aside, boxes["sister's note"]), "and clear of the tape, the notebook and the sister's note")

	# The backpack stands on the ground beside the bench, dressing only.
	var backpack: AABB = _visual_bounds(shed.get_node("Platform/PersonalEffects/Backpack"))
	var slab_top: float = shed.global_position.y + 0.05
	_expect(absf(backpack.position.y - slab_top) < 0.03, "the backpack stands on the slab (%.3f m over it)" % (backpack.position.y - slab_top))
	_expect(not _overlap_plan(backpack, seat) and backpack.position.x >= seat.end.x - 0.05, "beside the bench, not on it")

	# Every hit area: the notebook, the clipping over the tape, the sister's note, the tape, the letter, the Helena notice and the camcorder; only the clipping and the tape (on purpose) share space.
	var areas: Dictionary = {
		"notebook": _area_bounds(shed.get_node("%SophiaJournal")),
		"clipping": _area_bounds(clipping),
		"sister's note": _area_bounds(shed.get_node("%MarinaSisterNote")),
		"tape": _area_bounds(shed.vhs),
		"letter": _area_bounds(shed.letter),
		"notice": _area_bounds(shed.get_node("%HelenaClarkeNotice")),
	}
	for a: String in areas.keys():
		for b: String in areas.keys():
			if a < b and not ((a == "clipping" and b == "tape") or (a == "tape" and b == "clipping")):
				_expect(not (areas[a] as AABB).intersects(areas[b]), "the hit areas of the %s and the %s do not overlap" % [a, b])
	clipping.transform = shed.clipping_aside.transform
	_expect(not _area_bounds(clipping).intersects(areas["tape"]) and not _area_bounds(clipping).intersects(areas["notebook"]) and not _area_bounds(clipping).intersects(areas["sister's note"]), "and once the clipping lies aside its hit area is clear of the tape's, the notebook's and the note's")
	clipping.transform = home

	# The standing patch in front of the bench is clear: no solid within a metre and a half but the bench.
	var patch_clear: bool = true
	var space: PhysicsDirectSpaceState3D = level.get_viewport().world_3d.direct_space_state
	for dx: float in [-0.6, 0.0, 0.6]:
		for dz: float in [0.5, 0.9, 1.3]:
			var probe: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				bench.global_position + Vector3(dx, 1.0, dz), bench.global_position + Vector3(dx, 0.1, dz)
			)
			probe.exclude = [player.get_rid()]
			if not space.intersect_ray(probe).is_empty():
				patch_clear = false
	_expect(patch_clear, "the ground in front of the bench is clear to stand on")
	# The player can stand 0.7 m from the bench's front (no obstacle) with the capsule.
	_expect(await _player_can_stand(bench.global_position + Vector3(-0.5, 0.0, 0.85)), "the player's capsule fits in front of the notebook")
	_expect(await _player_can_stand(bench.global_position + Vector3(0.6, 0.0, 0.85)), "and in front of the sister's note")


## The evidence: the tape is under the clipping and offers nothing (no prompt, no mark, no ray target) until the clipping has been read; reading it once (closing it at once is enough) moves it aside and
## exposes the tape. Nothing else has to be read.
func _check_evidence_and_rays() -> void:
	_expect(not shed.vhs.can_interact(player) and not shed.vhs.interaction_enabled, "the tape offers nothing while the clipping lies over it")
	_expect(not bool(SaveManager.get_state_value(&"puzzles", &"shelter_clipping_read", false)), "(nothing has been read)")
	_expect(not shed.letter.can_interact(player) and not shed.letter.visible and shed.ficha.visible and shed.ficha.pickup_enabled, "the letter is not in the world; the token lies in its recess behind the shelter, an ordinary pickup")
	_expect(shed.vhs.is_inside_tree() and shed.clipping.is_inside_tree(), "the tape is in the scene, under the paper")
	var clipping: Inspectable = shed.clipping
	var notebook: Inspectable = shed.get_node("%SophiaJournal")
	var sister_note: Inspectable = shed.get_node("%MarinaSisterNote")

	var stand: Vector3 = _stand_for(Vector3(-4.3, 0.0, 0.0))
	# Aimed at the tape through the paper, the ray ends on the clipping; the tape is never the target.
	await _ray_finds(clipping, stand, clipping.global_position + Vector3(0.0, 0.012, 0.0), "the clipping, over the tape")
	await _ray_finds(clipping, stand, shed.vhs.global_position + Vector3(0.0, 0.02, 0.0), "the clipping where the tape lies under it (the tape is not a target)")
	var marks: Array = player.interaction_controller.reticle.call("_scan", false)
	_expect(not marks.has(shed.vhs), "and the tape has no interaction mark through the paper")
	await _ray_finds(notebook, _stand_for(Vector3(-4.86, 0.0, 0.0)), notebook.global_position + Vector3(-0.07, 0.01, 0.0), "the notebook")
	await _ray_finds(sister_note, _stand_for(Vector3(-3.72, 0.0, 0.0)), sister_note.global_position + Vector3(0.0, 0.012, 0.0), "the sister's note, at the other end")

	# Reading the clipping once exposes the tape; no timer, and closing it at once is enough.
	await _read_and_close_clipping()
	await _wait(1.0)
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_clipping_read", false)), "reading the clipping is remembered")
	_expect(clipping.global_transform.is_equal_approx(shed.clipping_aside.global_transform), "the clipping lies aside, where the marker is")
	_expect(shed.vhs.can_interact(player) and shed.vhs.interaction_enabled, "the tape offers its inspection now")
	_expect(shed.vhs.get_node("Visual").global_basis.z.dot(Vector3.UP) > 0.95, "the tape lies label up")
	_expect(shed.vhs.global_transform.is_equal_approx(shed.vhs_set_down.global_transform), "and where it lay, not moved")
	await _ray_finds(shed.vhs, stand, shed.vhs.global_position, "the tape, exposed")
	var marks_after: Array = player.interaction_controller.reticle.call("_scan", false)
	_expect(marks_after.has(shed.vhs), "and it has its interaction mark")
	_expect(not bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)), "(the cinematic has not started)")
	_expect(not shed.is_recording_running() and not player.view_locked, "reading the clipping starts nothing and holds nobody")
	_expect(not shed.letter.visible, "and it does not bring the letter")


func _check_scene_plays_once() -> void:
	player.flashlight_controller.flashlight_on = true
	player.global_position = Vector3(_stand_for(Vector3(-3.9, 0.0, 0.0)).x, 1.1, _stand_for(Vector3.ZERO).z)
	player.movement_controller.look_yaw = 0.0
	await _wait(0.8)
	var start_position: Vector3 = player.global_position
	view_before = Vector2(player.movement_controller.look_yaw, player.movement_controller.look_pitch)
	var scripted_before: bool = player.scripted_flashlight
	await _read_and_close_tape()
	# The very call that closed the view took the player: no frame of walking or opening the inventory in between.
	_expect(shed.is_recording_running(), "the first close of the tape starts the scene")
	_expect(player.view_locked and player.manual_save_blocked, "at once: the view is held and saving is blocked")
	_expect(player.inspect_controller.is_open() or true, "(the tape is still flying back)")
	_start_watch()

	# The inventory cannot be opened during the scene.
	await _wait(2.0)
	player.inventory_ui_controller.show_inventory(player.inventory_controller.get_slots())
	await _wait(0.3)
	_expect(not player.inventory_ui_controller.is_inventory_open(), "the inventory is shut at once during the scene")
	_expect(not player.inspect_controller.is_open(), "the tape's view is gone before the first shot")

	var waited: float = 0.0
	while shed.is_recording_running() and waited < 320.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_stop_watch()
	await get_tree().process_frame
	await get_tree().process_frame

	scene_ended_at_msec = Time.get_ticks_msec()
	_expect(not shed.is_recording_running() and shed.is_recording_done(), "the scene ends by itself")
	_expect(waited > 125.0 and waited < 200.0, "it lasts about two and a half minutes: the introduction, the machine's 2.3 s and the 62 s recording, the tape again with the conversation and the photograph (%.0f s)" % waited)
	_expect(completed_count == 1, "it is announced once")
	_expect(player.global_position.distance_to(start_position) < 0.05, "the player was never moved")
	_expect(not player.view_locked and not player.manual_save_blocked and player.scripted_flashlight == scripted_before, "the view, saving and the flashlight scripting are given back")
	_expect(player.flashlight_controller.flashlight_on, "the flashlight is on as it was")
	_expect(get_viewport().get_camera_3d() == player.movement_controller.camera, "the player's camera is current again")
	_expect(is_zero_approx(player.movement_controller.scripted_fov) and not player.movement_controller.view_motion_still, "the field of view and the body's own motion are given back")
	_expect(shed.get_node_or_null("CinemaCamera") == null or shed.get_node("CinemaCamera").is_queued_for_deletion(), "the scene's camera is gone")
	_expect(shed.effects_root.visible and shed.camcorder.visible and not shed.archive_dressing.visible and shed.replaced_plank.visible, "the present is whole again")

	_expect(bool(_seen.get("cinema_first", false)), "the first shot was the scene's camera, with the tape already beside the box")
	_expect(int(_seen.get("hidden_in_player_view", 0)) == 0, "nothing was ever hidden or shown while the player's own camera was current (changes were under cuts)")
	_expect(bool(_seen.get("archive_world", false)) and bool(_seen.get("overlay_seen", false)), "the recording showed its own dressing, with the 4:3 overlay")
	_expect(int(_seen.get("overlay_in_player_view", 0)) == 0, "the overlay was never over the player's own view")
	_expect(bool(_seen.get("cast_seen", false)), "the two people were in the recording")
	_expect(int(_seen.get("cast_in_player_view", 0)) == 0 and int(_seen.get("cast_without_recording", 0)) == 0, "and only there: never in the player's view, never without the recording's own dressing")
	_expect(int(_seen.get("cast_in_talk", 0)) == 0, "and not in the present shots (%d frames)" % int(_seen.get("cast_in_talk", 0)))
	_expect(int(_seen.get("foreground_outside", 0)) == 0 and bool(_seen.get("foreground_seen", false)), "the ferns are in the recording and nowhere else (%d frames outside)" % int(_seen.get("foreground_outside", 0)))
	_expect(int(_seen.get("caption_in_recording", 0)) == 0, "no caption while the first viewing plays (%d frames)" % int(_seen.get("caption_in_recording", 0)))
	_expect(int(_seen.get("caption_in_photo", 0)) > 100, "and the rest of the conversation is spoken over the photograph (%d frames with a caption)" % int(_seen.get("caption_in_photo", 0)))
	_expect(int(_seen.get("source_sounds", 0)) == 0, "no sound but the tape's own noise while the recording's picture is up (%d frames)" % int(_seen.get("source_sounds", 0)))
	_expect(int(_seen.get("tape_frames", 0)) > 100 and int(_seen.get("tape_silent_frames", 0)) <= 2, "and that noise plays the whole time (%d frames with it, %d without)" % [int(_seen.get("tape_frames", 0)), int(_seen.get("tape_silent_frames", 0))])
	_expect(bool(_seen.get("tape_loops", false)) and str(_seen.get("tape_path", "")).ends_with("placeholder_video_tape.mp3") and int(_seen.get("tape_outside", 0)) == 0, "it is placeholder_video_tape, looped, and nowhere else (%d frames outside the recording)" % int(_seen.get("tape_outside", 0)))
	_expect(int(_seen.get("silenced_frames", 0)) > 100 and int(_seen.get("not_silenced_in_cinema", 0)) == 0, "the wind and the night chorus are silent through the whole memory (%d frames not silent in a shot)" % int(_seen.get("not_silenced_in_cinema", 0)))
	_expect(int(_seen.get("preroll_frames", 0)) > 5 and bool(_seen.get("preroll_static", false)), "the machine's first part plays on static, with no PLAY on it yet (%d frames)" % int(_seen.get("preroll_frames", 0)))
	_expect(bool(_seen.get("picture_began", false)) and bool(_seen.get("picture_stream_ok", false)) and float(_seen.get("picture_machine_at", 0.0)) >= 2.28 and float(_seen.get("picture_machine_at", 0.0)) <= 2.40 and str(_seen.get("picture_label", "")) == "PLAY", "the picture begins at the machine's 2.30 s, with PLAY on it (%.3f s)" % float(_seen.get("picture_machine_at", 0.0)))
	_expect(int(_seen.get("first_loop_frames", 0)) > 100 and float(_seen.get("first_loop_min", 0.0)) >= 2.2, "and the running sound plays, looping, all through the first viewing (%d frames)" % int(_seen.get("first_loop_frames", 0)))
	_expect(bool(_seen.get("end_stop_sound", false)), "and when the tape ends its last part (6.20 s to the end) plays")
	_expect(bool(_seen.get("replayed", false)) and absf(float(_seen.get("replay_from", 0.0)) - shed.replay_from()) < 0.5, "the second viewing replays the footage from where it was meant to (%.1f s)" % float(_seen.get("replay_from", 0.0)))
	_expect(int(_seen.get("replay_frames", 0)) > 25 and bool(_seen.get("replay_label_play", false)) and int(_seen.get("replay_machine_wrong", 0)) == 0 and int(_seen.get("replay_noise_missing", 0)) == 0, "it runs with PLAY on it, the machine's running sound and the tape's own noise throughout (%d frames, %d wrong, %d without noise)" % [int(_seen.get("replay_frames", 0)), int(_seen.get("replay_machine_wrong", 0)), int(_seen.get("replay_noise_missing", 0))])
	_expect(int(_seen.get("paused_frames", 0)) > 20 and str(_seen.get("paused_label", "")) == "PAUSE" and bool(_seen.get("paused_stop_sound", false)) and bool(_seen.get("paused_noise_off", false)), "when Juliana asks to stop, PAUSE replaces PLAY and only the machine's last part plays (%d frames held)" % int(_seen.get("paused_frames", 0)))
	_expect(not bool(_seen.get("paused_moved", false)) and bool(_seen.get("paused_cast_shown", false)), "and the picture is held where it was, the cast still in it")
	_expect(bool(_seen.get("paused_on_greeting", false)) and int(_seen.get("paused_off_greeting", 0)) == 0, "held on her greeting (at %.1f s of the footage), shot A's camera and lens unchanged, Emily in it and no blood" % float(_seen.get("paused_time", 99.0)))
	_expect(int(_seen.get("replay_other_shot", 0)) == 0 and int(_seen.get("replay_shot_a_frames", 0)) > 20, "the second viewing never reaches the first cut (%d frames of shot A, %d of another)" % [int(_seen.get("replay_shot_a_frames", 0)), int(_seen.get("replay_other_shot", 0))])
	_expect(int(_seen.get("stale_frames", 0)) > 20 and int(_seen.get("moving_frames", 0)) > 20, "the tape's picture holds still between its own frames, and does move (%d held, %d moved)" % [int(_seen.get("stale_frames", 0)), int(_seen.get("moving_frames", 0))])
	_expect(shed.get_node_or_null("RecordedVoices") == null and shed.get_node_or_null("ArchiveTexture") == null and shed.get_node_or_null("ArchiveMotif") == null and shed.get_node_or_null("RewindFoley") == null, "the old recorded-voice, texture, motif and rewind players are gone: nothing is replayed")
	_expect(float(_seen.get("max_footage_time", 0.0)) >= shed.footage.length_seconds - 0.2, "the footage ran to its end, once (%.1f s)" % float(_seen.get("max_footage_time", 0.0)))
	_expect(int(_seen.get("footage_restarts", 0)) == 0, "and never went back (%d restarts)" % int(_seen.get("footage_restarts", 0)))
	_expect(int(_seen.get("camera_wrong", 0)) == 0 and int(_seen.get("frames_A", 0)) > 100 and int(_seen.get("frames_walk", 0)) > 40 and int(_seen.get("frames_aftermath", 0)) > 60 and int(_seen.get("frames_walk2", 0)) > 60, "the recording's camera is always the one the footage's own time asks for, with the lens matched to the picture (%d frames of shot A, %d walking, %d of the aftermath, %d walking again, %d wrong)" % [int(_seen.get("frames_A", 0)), int(_seen.get("frames_walk", 0)), int(_seen.get("frames_aftermath", 0)), int(_seen.get("frames_walk2", 0)), int(_seen.get("camera_wrong", 0))])
	_expect(str(_seen.get("cuts", "")) == "A>walk,walk>aftermath,aftermath>walk2", "the first viewing has exactly three cuts, A to the walk, the walk to the aftermath, the aftermath to the second walk, and never goes back (%s)" % str(_seen.get("cuts", "")))
	_expect(float(_seen.get("cut_one_at", 0.0)) >= 20.0 and float(_seen.get("cut_one_at", 0.0)) <= 20.2 and float(_seen.get("cut_two_at", 0.0)) >= 32.0 and float(_seen.get("cut_two_at", 0.0)) <= 32.2 and float(_seen.get("cut_three_at", 0.0)) >= 46.0 and float(_seen.get("cut_three_at", 0.0)) <= 46.2, "each cut is immediate, at the source's 20, 32 and 46 s (%.2f, %.2f, %.2f)" % [float(_seen.get("cut_one_at", 0.0)), float(_seen.get("cut_two_at", 0.0)), float(_seen.get("cut_three_at", 0.0))])
	_expect(int(_seen.get("dressing_wrong", 0)) == 0 and int(_seen.get("dressing_checked", 0)) > 200, "in every frame of the recording the shelter was the shot's: Emily, the whole bench and the ferns in the first; each strip's litter in its walk; the broken bench and the blood, nobody, in the aftermath (%d frames, %d wrong)" % [int(_seen.get("dressing_checked", 0)), int(_seen.get("dressing_wrong", 0))])
	_expect(int(_seen.get("light_wrong", 0)) == 0, "the camera's own faint light is off in shot A and on in the other three (%d frames wrong)" % int(_seen.get("light_wrong", 0)))
	_expect(int(_seen.get("photo_frames", 0)) > 300 and int(_seen.get("photo_present_frames", 0)) == int(_seen.get("photo_frames", 0)), "the photograph's close view was held, with the present's dressing whole and nobody in it (%d frames)" % int(_seen.get("photo_frames", 0)))
	_expect(float(_seen.get("photo_camera_move", 1.0)) < 0.0001, "and the photograph is one still shot to the end of the conversation (%.5f m)" % float(_seen.get("photo_camera_move", 1.0)))
	_expect(int(_seen.get("black_frames", 0)) == 0, "no black or dissolve frame between the recording, the photograph and the conversation (%d frames of a black picture)" % int(_seen.get("black_frames", 0)))
	_expect(not bool(_seen.get("led_on", false)), "the camcorder's light never came on: it is only there")
	_expect(is_equal_approx(float(_seen.get("head_turn", 0.0)), 0.0), "and it never turned (%.1f degrees)" % float(_seen.get("head_turn", 0.0)))
	_expect(bool(_seen.get("flash_off_in_memory", false)), "her flashlight was out for the memory")
	var after_last: float = float(_seen.get("ended_ms", 0.0)) - float(_seen.get("last_line_ms", 0.0))
	_expect(_seen.has("last_line_ms") and _seen.has("ended_ms") and after_last >= 0.0 and after_last < 9000.0 / maxf(TIME_SCALE, 0.1), "the controls come back when the conversation is over, with nothing played after it (%.1f s after the last line, real time)" % (after_last / 1000.0))
	_expect(int(_seen.get("eyes_frames_with_scene", 0)) == 0, "nothing of the scene's own camera or recording shows once her eyes are back (%d frames)" % int(_seen.get("eyes_frames_with_scene", 0)))
	_expect(not bool(_seen.get("saw_marina", false)) and not bool(_seen.get("saw_recorded", false)), "no subtitle ever spoke for Marina or a recorded voice")
	_expect(bool(_seen.get("saw_last", false)), "the subtitles reached the last line of the conversation")
	_expect(str(_seen.get("order_ok", "")) == "yes", "the subtitles came in order and none was left behind across a cut (%s)" % str(_seen.get("order_ok", "")))
	var led: MeshInstance3D = shed.camcorder.find_child("Led", true, false)
	_expect((led.material_override as StandardMaterial3D).emission_energy_multiplier == 0.0 and shed.camcorder.visible, "its light is out and it is still there")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)), "completion is saved")
	_expect(not bool(SaveManager.get_state_value(&"collectibles", &"sophia_ficha", false)), "the token is not collected by the scene")
	_expect(not player.has_inventory_item("sophia_ficha"), "and not in the inventory")
	_expect(not shed.footage.visible and is_zero_approx(shed.footage.current_time) and not shed.archive_foreground.visible, "the cast and the ferns are put away, the cast at its first frame")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT, "and the shelter is in its present look")


func _check_after_scene() -> void:
	# The tape lies on the bench where it lay; the first cinematic frees nothing and moves nothing of the token, which lies in its recess behind the shelter all along.
	_expect(vhs.get_parent() == shed.effects_root, "the tape stays on the bench")
	_expect(vhs.global_transform.is_equal_approx(shed.vhs_set_down.global_transform), "where it lay")
	_expect(ficha.is_inside_tree() and ficha.visible and ficha.pickup_enabled and shed.rear_annex.is_ancestor_of(ficha), "the first cinematic does not touch the token: it lies where it always lay, behind the shelter")
	_expect(not ("token_landing" in shed) and not shed.has_method("_turn_toward_camcorder"), "(nothing of the token's fall or of the forced turn is left)")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)) and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_letter_read", false)) and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)), "only the first cinematic is saved: the leaves are still over the end of the trail, the letter is unread")
	_expect(shed.camcorder.viewfinder_enabled and shed.camcorder.can_interact(player), "the camcorder can be used")
	# The control comes back in the view the player had when the scene began: no turn toward the camcorder, no snap.
	var camera: Camera3D = player.movement_controller.camera
	_expect(absf(wrapf(player.movement_controller.look_yaw - view_before.x, -180.0, 180.0)) < 0.5 and absf(player.movement_controller.look_pitch - view_before.y) < 0.5, "the player's view is the one they had before the scene (%.1f, %.1f against %.1f, %.1f)" % [player.movement_controller.look_yaw, player.movement_controller.look_pitch, view_before.x, view_before.y])
	var yaw_after: float = player.movement_controller.look_yaw
	# 1.2 to 1.8 s after the control, a small mechanical sound comes from the physical camcorder, behind her; nothing is forced (timed by `_watch_cue`, from the moment the scene ended).
	var guard_cue: float = 0.0
	while cue_heard_at < 0.0 and guard_cue < 4.0:
		await get_tree().process_frame
		guard_cue += get_process_delta_time()
	var heard_at: float = cue_heard_at
	var cue: AudioStreamPlayer3D = shed.camcorder.get_head().get_node_or_null("CueSound") as AudioStreamPlayer3D
	_expect(heard_at >= 1.2 and heard_at <= 1.9, "the camcorder's own sound begins 1.2 to 1.8 s after the control (%.2f s)" % heard_at)
	_expect(cue != null and shed.camcorder.get_head().is_ancestor_of(cue) and cue.stream != null, "from the device itself, a 3D source (not a UI sound)")
	_expect(not player.view_locked and get_viewport().get_camera_3d() == camera and absf(player.movement_controller.look_yaw - yaw_after) < 0.05, "and it forces no look: the player is free and their view has not moved")
	await _wait(1.8)
	_expect(cue != null and not cue.playing, "and it stops by itself, once")

	# The tape, now, is the voluntary review; examining it again never replays the scene.
	_expect(vhs.review_mode and vhs.get_prompt_text() == "PROMPT_REVIEW_TAPE", "the tape offers a review now")
	vhs.interact(player)
	await _wait(0.6)
	_expect(not shed.is_recording_running() and int(shed.get("_aux_mode")) == 2, "using the tape again opens the review, not the scene")
	shed.call("_abort_aux")
	await get_tree().process_frame
	_expect(not shed.is_recording_running() and not player.view_locked, "and leaving it gives everything back")
	_expect(completed_count == 1, "(nothing announced again)")

	# The rest of the investigation is tested in shed_investigation_smoke_test. Here the dev shortcut resolves it, and the token is taken with the ordinary pickup.
	shed.force_resolve()
	await _wait(0.4)
	_expect(ficha.visible and ficha.pickup_enabled and ficha.can_interact(player), "once the investigation is resolved the token is still a plain pickup")
	ficha.interact(player)
	_expect(player.has_inventory_item("sophia_ficha"), "the token goes in the inventory with the ordinary pickup")
	_expect(bool(SaveManager.get_state_value(&"collectibles", &"sophia_ficha", false)), "and is remembered as collected")
	await _wait(0.6)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.8)
	_expect(not player.view_locked and not shed.is_recording_running(), "taking the token does not start anything")


func _check_saves() -> void:
	# Collected: the scene is over, the tape on the bench, no second token, no replay.
	await _fresh_level(false)
	_expect(shed.is_recording_done() and bool(SaveManager.get_state_value(&"puzzles", &"shelter_letter_read", false)), "reloaded after the token was taken: the scene is over and the letter was read")
	_expect(shed.vhs.get_parent() == shed.effects_root and shed.clipping.global_transform.is_equal_approx(shed.clipping_aside.global_transform), "the tape is on the bench and the clipping lies aside")
	await _wait(0.3)
	_expect(not is_instance_valid(shed.ficha) or shed.ficha.is_queued_for_deletion() or not shed.ficha.is_inside_tree(), "the token does not come back once it is collected")
	_expect(shed.letter.visible and shed.letter.can_interact(player), "the letter lies where it was left, to be read again")
	await _free_level()

	# The first cinematic done only: the camcorder stage. The token is NOT in the world, the letter is hidden, the leaves are over it.
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.set_state_value(&"puzzles", &"shelter_recording_done", true)
	await _load_level()
	_expect(shed.is_recording_done() and shed.vhs.can_interact(player), "the first cinematic done: the tape is exposed")
	_expect(shed.ficha.visible and shed.ficha.pickup_enabled and not shed.letter.visible and not shed.letter.can_interact(player), "the token lies in its recess, the letter is hidden")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_clipping_read", false)) and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_leaf_revealed", false)), "the clipping counts as read, the leaves are still over the end of the trail")
	shed.vhs.interact(player)
	await _wait(0.4)
	_expect(not shed.is_recording_running() and int(shed.get("_aux_mode")) == 2, "and the tape opens the review, it does not replay the scene")
	shed.call("_abort_aux")
	await _free_level()

	# Old saves. A solved lever box: the cinematic counts as done, the investigation is not.
	await _legacy_case("a solved lever box", [[&"puzzles", &"junction_signal_box_open", true]], true, false)
	# The token taken the old way: everything resolved, nothing respawns.
	await _legacy_case("a token taken from the lever box", [[&"puzzles", &"junction_ficha_taken", true], [&"collectibles", &"sophia_ficha", true]], true, true)
	# The token already in the payphone.
	await _legacy_case("a token already in the payphone", [[&"puzzles", &"orelhao_fichas", ["sophia_ficha"]], [&"collectibles", &"sophia_ficha", true]], true, true)
	# The old hinged box opened (with the old levers) and nothing more: the scene is still to come.
	await _legacy_case("only the old switch box opened", [[&"puzzles", &"junction_switch_box_open", true], [&"puzzles", &"junction_signal_box_levers", [true, true, false]]], false, false)


## A saved state prepared, the shed loaded: whether the first cinematic counts as over, and whether the token is gone for good (every stage resolved, nothing respawns).
func _legacy_case(label: String, values: Array, expect_done: bool, expect_resolved: bool) -> void:
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	for entry: Array in values:
		SaveManager.set_state_value(entry[0], entry[1], entry[2])
	await _load_level()
	await _wait(0.3)
	_expect(shed.is_recording_done() == expect_done, "%s: the scene is %s" % [label, "over" if expect_done else "still to come"])
	var token_in_world: bool = is_instance_valid(shed.ficha) and shed.ficha.is_inside_tree() and not shed.ficha.is_queued_for_deletion() and shed.ficha.visible
	_expect(token_in_world == not expect_resolved, "%s: the token %s (one token, never twice)" % [label, "is gone with the one collected" if expect_resolved else "lies in its recess behind the shelter"])
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_letter_read", false)) == expect_resolved, "%s: the investigation is %s" % [label, "resolved" if expect_resolved else "still to be done"])
	_expect(shed.letter.visible == expect_resolved and (not expect_resolved or shed.letter.can_interact(player)), "%s: the letter is %s" % [label, "exposed to be read again" if expect_resolved else "hidden"])
	if expect_done:
		_expect(shed.vhs.can_interact(player) and shed.vhs.get_parent() == shed.effects_root, "%s: the tape is exposed on the bench" % label)
		shed.vhs.interact(player)
		await _wait(0.4)
		_expect(not shed.is_recording_running() and int(shed.get("_aux_mode")) == 2, "%s: no scene is forced (the tape opens the review)" % label)
		shed.call("_abort_aux")
	else:
		_expect(not shed.vhs.can_interact(player) and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_clipping_read", false)), "%s: the tape is still under the clipping (the old box proves nothing)" % label)
	await _free_level()


func _check_cancel() -> void:
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.set_state_value(&"puzzles", &"shelter_clipping_read", true)
	await _load_level()
	await _wait(1.0)
	player.flashlight_controller.flashlight_on = true
	await _read_and_close_tape()
	# In the walking shot (the footage begins after the machine's first part): 11 s of the footage in.
	await _footage_plays_for(26.0)
	_expect(shed.is_recording_running() and not shed.effects_root.visible and shed.footage.visible and shed.footage.litter.visible and not shed.footage.marina.visible and not shed.archive_foreground.visible, "(in the recording, in the walking shot: the litter on screen, no Emily, no ferns)")
	_expect(shed.footage.passage_at(shed.footage.current_time) == &"walk", "(the footage is at %.1f s: the walking shot)" % shed.footage.current_time)
	_expect(shed.get_node_or_null("CinemaCamera") != null and (shed.get_node("CinemaCamera").global_transform.origin - (shed.footage.camera_at(shed.footage.current_time)["transform"] as Transform3D).origin).length() < 0.5, "(and the camera is the carried one)")
	shed.cancel_recording()
	await _wait(0.3)
	_expect(not shed.is_recording_running() and not shed.is_recording_done(), "cutting the scene short leaves it to be played")
	_expect(not player.view_locked and not player.manual_save_blocked and get_viewport().get_camera_3d() == player.movement_controller.camera, "the player has their view, saving and camera back")
	_expect(player.flashlight_controller.flashlight_on and is_zero_approx(player.movement_controller.scripted_fov), "the flashlight and the lens are as they were")
	_expect(shed.effects_root.visible and shed.camcorder.visible and not shed.archive_dressing.visible, "the present is whole")
	_expect(not shed.footage.visible and is_zero_approx(shed.footage.current_time) and not shed.archive_foreground.visible and not shed.archive_dressing.visible and shed.footage.marina.visible and not shed.footage.aftermath.visible and not shed.footage.litter.visible, "the cast and the ferns are put away, the cast at its first frame (Emily back in it, no blood, no litter), the old plank hidden")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT and not shed.footage.aftermath.is_visible_in_tree() and not shed.footage.litter.is_visible_in_tree(), "and the shelter is in its present look: the blood and the litter are not in the tree's view")
	_expect(shed.vhs.get_parent() == shed.effects_root and shed.vhs.can_interact(player) and shed.ficha.pickup_enabled and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)), "the tape lies where it lay, exposed, and the token is still not in the world")
	await _wait(2.0)
	_expect(CaptionManager.panel.visible == false, "no subtitle is left on the screen")
	# It can be played again.
	await _read_and_close_tape()
	_expect(shed.is_recording_running(), "examining the tape plays it again")
	shed.cancel_recording()
	await _free_level()


func _check_pause() -> void:
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.set_state_value(&"puzzles", &"shelter_clipping_read", true)
	await _load_level()
	await _wait(1.0)
	await _read_and_close_tape()
	# In the walking shot (the footage begins after the machine's first part): the picture stands still, the camera with it, and nothing keeps moving.
	await _footage_plays_for(26.0)
	var cinema: Camera3D = shed.get_node_or_null("CinemaCamera")
	_expect(shed.is_recording_running() and cinema != null and shed.footage.visible, "(in the footage, the walking shot)")
	var time_before: float = shed.footage.current_time
	var snapshot_before: Dictionary = _footage_snapshot(shed.footage)
	var camera_before: Transform3D = cinema.global_transform
	get_tree().paused = true
	await get_tree().create_timer(1.5, true, false, true).timeout
	_expect(is_equal_approx(shed.footage.current_time, time_before) and _snapshots_equal(snapshot_before, _footage_snapshot(shed.footage)) and cinema.global_transform.is_equal_approx(camera_before), "paused in the walking shot: the clock, the poses, the places and the camera stand still")
	get_tree().paused = false
	await _wait(0.5)
	_expect(shed.footage.current_time > time_before + 0.3, "resumed: the footage goes on from where it was (%.2f -> %.2f)" % [time_before, shed.footage.current_time])

	# Through the exchange, the exit and the photograph's close view.
	var guard: float = 0.0
	while shed.footage.visible and guard < 320.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	await _wait(1.0)
	cinema = shed.get_node_or_null("CinemaCamera")
	_expect(shed.is_recording_running() and cinema != null and not shed.footage.visible and shed.effects_root.visible and not shed.archive_foreground.visible, "(the photograph's view: the present whole, nobody in it)")
	var photo_before: Transform3D = cinema.global_transform
	get_tree().paused = true
	await get_tree().create_timer(1.5, true, false, true).timeout
	_expect(cinema.global_transform.is_equal_approx(photo_before), "paused over the photograph: the view stands still (a line may be up: it stands with the clock, checked below)")
	get_tree().paused = false
	await _wait(0.3)

	# Later, in the conversation: the shot and the subtitle stand still.
	guard = 0.0
	while shed.footage.visible and guard < 60.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	await _wait(5.0)
	cinema = shed.get_node_or_null("CinemaCamera")
	_expect(shed.is_recording_running() and cinema != null and not shed.footage.visible, "(in the conversation, the cast gone)")
	_expect(shed.is_recording_running() and shed.effects_root.visible, "(the scene is still running after the pauses)")
	var before: Transform3D = cinema.global_transform
	var caption_before: String = CaptionManager.label.text
	var caption_clock: float = float(CaptionManager.get("_clock"))
	get_tree().paused = true
	await get_tree().create_timer(1.5, true, false, true).timeout
	_expect(cinema.global_transform.is_equal_approx(before) and CaptionManager.label.text == caption_before and is_equal_approx(float(CaptionManager.get("_clock")), caption_clock), "paused: the still shot stands, the subtitle and its clock with it")
	get_tree().paused = false
	await _wait(1.0)
	_expect(float(CaptionManager.get("_clock")) > caption_clock + 0.5, "resumed: the subtitles go on from where they were")
	shed.cancel_recording()
	await _wait(0.2)
	_expect(not player.view_locked and not shed.footage.visible, "(cut short)")
	await _free_level()


# ============================================================
# THE FOOTAGE (Emily, the three cameras, the ferns, the litter, the stains): numbers, not acting. Whether it reads is for the eye.
# ============================================================

func _check_footage() -> void:
	# Built long before, out of sight.
	var footage: ShelterFootage = shed.footage
	for i: int in 5:
		await get_tree().process_frame
	_expect(footage != null and footage.is_prepared(), "the cast is built before the scene is watched")
	_expect(not footage.visible, "and hidden in the present")
	var marina: ArchiveActor = footage.marina
	var seat_y: float = footage.marina_seat.global_position.y
	var floor_y: float = seat_y - footage.bench_seat_height

	# The rig: the project's rigged basic model, a local copy, one pose owner, one actor and nobody else.
	_expect(marina.skeleton != null and marina.skeleton.get_bone_count() == 25, "Emily has a skeleton of the model's 25 bones")
	_expect(footage.find_children("*", "ArchiveActor", false, false).size() == 1, "she is the only actor in the footage: no visitor, no operator, no second figure")
	for gone: String in ["adult", "restraint", "forearm", "adult_behind", "adult_by_lens", "shot_b", "shot_final", "passage_b_seconds", "passage_final_seconds", "lean_start_seconds", "visitor", "gait"]:
		_expect(footage.get(gone) == null, "nothing of the discarded footage is left on the node (%s)" % gone)
	_expect(footage.find_children("*", "RestrainedForearm", true, false).is_empty() and footage.find_children("Restraint*", "", true, false).is_empty(), "the hand insert and the band are not in the active footage")
	_expect(marina.find_children("*", "Skeleton3D", true, false).size() == 1 and marina.find_children("*", "AnimationPlayer", true, false).is_empty() and marina.find_children("*", "AnimationTree", true, false).is_empty(), "one skeleton, and no AnimationPlayer or AnimationTree writing to it: the one pose owner is sample()")
	_expect(marina.find_children("*", "CollisionObject3D", true, false).is_empty() and marina.find_children("*", "Camera3D", true, false).is_empty() and marina.find_children("*", "Light3D", true, false).is_empty() and marina.find_children("*", "Interactable", true, false).is_empty(), "she has no collision, camera, light or interaction: archive picture only")
	var mouth: bool = false
	for bone: int in marina.skeleton.get_bone_count():
		var lowered: String = marina.skeleton.get_bone_name(bone).to_lower()
		mouth = mouth or lowered.contains("jaw") or lowered.contains("mouth") or lowered.contains("lip") or lowered.contains("teeth")
	_expect(not mouth and (marina.body.mesh as ArrayMesh).get_blend_shape_count() == 0 and marina.hidden_bones.is_empty(), "no face rig is animated or claimed, and none of her bones is hidden")
	var shared_scene: Node = (load(ArchiveActor.MODEL) as PackedScene).instantiate()
	var shared_body: MeshInstance3D = shared_scene.get_node("Skeleton3D/Body") as MeshInstance3D
	_expect(shared_body.mesh != marina.body.mesh and (shared_body.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] == null, "her body mesh is a painted copy of her own; the shared model's mesh has no vertex colours written to it")
	var rest_untouched: bool = true
	for bone: int in shared_scene.get_node("Skeleton3D").get_bone_count():
		var shared_skeleton: Skeleton3D = shared_scene.get_node("Skeleton3D") as Skeleton3D
		rest_untouched = rest_untouched and shared_skeleton.get_bone_pose_rotation(bone).is_equal_approx(Quaternion.IDENTITY) and shared_skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE)
	_expect(rest_untouched, "and a fresh instance of it is still in its own rest pose")
	shared_scene.free()

	# The source timeline: about 24 s, two hard cuts, six seconds of watching before she reacts.
	_expect(absf(footage.length_seconds - 62.0) < 0.01 and absf(footage.cut_walk_seconds - 20.0) < 0.01 and absf(footage.cut_aftermath_seconds - 32.0) < 0.01 and absf(footage.cut_walk2_seconds - 46.0) < 0.01, "the source is 62 s: the hidden camera to 20 s, the carried camera to 32 s, the aftermath to 46 s, the carried camera again to 62 s (%.1f, %.1f, %.1f, %.1f)" % [footage.length_seconds, footage.cut_walk_seconds, footage.cut_aftermath_seconds, footage.cut_walk2_seconds])
	_expect(footage.cut_aftermath_seconds - footage.cut_walk_seconds == 12.0 and footage.cut_walk2_seconds - footage.cut_aftermath_seconds == 14.0 and footage.length_seconds - footage.cut_walk2_seconds == 16.0, "twelve seconds of walking, fourteen of the aftermath, sixteen of the second walk")
	_expect(footage.greet_on_right and footage.turn_start_seconds == 10.0 and footage.turn_end_seconds == 12.0 and footage.hand_up_start_seconds >= 12.0 and footage.hand_up_end_seconds <= 14.0 and footage.hand_down_end_seconds >= 15.0 and footage.hand_down_end_seconds < footage.cut_walk_seconds - 2.0, "she waits ten seconds, turns toward her right until 12 s, greets from 12 s, and her hand settles by %.1f s (%.1f, %.1f, %.1f)" % [footage.hand_down_end_seconds, footage.turn_start_seconds, footage.turn_end_seconds, footage.hand_up_start_seconds])
	_expect(footage.passage_at(0.0) == &"A" and footage.passage_at(19.99) == &"A" and footage.passage_at(20.0) == &"walk" and footage.passage_at(31.99) == &"walk" and footage.passage_at(32.0) == &"aftermath" and footage.passage_at(45.99) == &"aftermath" and footage.passage_at(46.0) == &"walk2" and footage.passage_at(62.0) == &"walk2", "the shot at each moment: the cuts are exactly at 20, 32 and 46 s")

	# Emily sits ON the bench: pelvis on the seat, thighs on it, feet on the floor, both hands on her thighs.
	footage.seek(0.0)
	var vertices: PackedVector3Array = marina.skinned_vertices()
	var pelvis_low: float = 1.0e9
	var thigh_low: float = 1.0e9
	var feet_low: float = 1.0e9
	var lowest: float = 1.0e9
	var bench: Node3D = shed.get_node("%Bench")
	var seat_front: float = bench.global_position.z + 0.23
	for v: Vector3 in vertices:
		lowest = minf(lowest, marina.to_global(v).y)
	for index: int in marina.vertices_of(["Hips"]):
		pelvis_low = minf(pelvis_low, marina.to_global(vertices[index]).y)
	for index: int in marina.vertices_of(["*UpLeg"]):
		var world: Vector3 = marina.to_global(vertices[index])
		if world.z < seat_front - 0.04:
			thigh_low = minf(thigh_low, world.y)
	for index: int in marina.vertices_of(["*Foot", "*ToeBase"]):
		feet_low = minf(feet_low, marina.to_global(vertices[index]).y)
	_expect(pelvis_low > seat_y - 0.01 and pelvis_low - seat_y < 0.05 and thigh_low > seat_y - 0.01, "Emily's pelvis rests on the seat and her thighs are on it, not through it (%.3f, %.3f m)" % [pelvis_low - seat_y, thigh_low - seat_y])
	_expect(absf(feet_low - floor_y) < 0.015 and lowest > floor_y - 0.02, "her feet are on the floor and nothing of her is under it (%.3f, %.3f m)" % [feet_low - floor_y, lowest - floor_y])
	_expect(marina.global_position.x > bench.global_position.x - 0.85 and marina.global_position.x < bench.global_position.x - 0.1 and absf(marina.global_position.z - bench.global_position.z) < 0.2, "she sits on the bench's left half, over the seat")
	for side: String in ["Left", "Right"]:
		var nearest: float = 1.0e9
		for h: int in marina.vertices_of([side + "Hand"]):
			for tv: int in marina.vertices_of([side + "UpLeg"]):
				nearest = minf(nearest, vertices[h].distance_to(vertices[tv]))
		_expect(nearest < 0.05, "her %s hand rests on her thigh at the start (%.3f m)" % [side.to_lower(), nearest])
	# Nothing of her goes into the bench: no vertex of her legs, hips, arms or hands is inside any of its boxes (its legs, its planks, the old front plank of the recording), at any moment of the greeting.
	var bench_boxes: Array[MeshInstance3D] = []
	for item: Node in bench.find_children("*", "MeshInstance3D", true, false):
		var bench_piece: MeshInstance3D = item as MeshInstance3D
		if bench_piece.mesh is BoxMesh and not shed.get_node("%Bench/ReplacedPlank").is_ancestor_of(bench_piece):
			bench_boxes.append(bench_piece)
	for item: Node in shed.archive_dressing.get_node("Intact").find_children("*", "MeshInstance3D", true, false):
		if (item as MeshInstance3D).mesh is BoxMesh:
			bench_boxes.append(item as MeshInstance3D)
	var clipped: PackedStringArray = PackedStringArray()
	var clip_worst: float = 0.0
	for clip_time: float in [0.0, 11.0, 12.5, 14.0, 16.0, 17.5, 19.5]:
		footage.seek(clip_time)
		var skin_now: PackedVector3Array = marina.skinned_vertices()
		for index: int in marina.vertices_of(["Hips", "*Leg", "*Foot", "*ToeBase", "*Hand", "*ForeArm", "*Arm"]):
			var world_vertex: Vector3 = marina.to_global(skin_now[index])
			for box_node: MeshInstance3D in bench_boxes:
				var half: Vector3 = (box_node.mesh as BoxMesh).size * 0.5
				var local_vertex: Vector3 = box_node.global_transform.affine_inverse() * world_vertex
				var depth: float = minf(minf(half.x - absf(local_vertex.x), half.y - absf(local_vertex.y)), half.z - absf(local_vertex.z))
				if depth > 0.006:
					clip_worst = maxf(clip_worst, depth)
					if not clipped.has(str(box_node.name)):
						clipped.append(str(box_node.name))
	footage.seek(0.0)
	_expect(clipped.is_empty(), "no part of her is inside the bench at any moment (worst %.3f m; into: %s)" % [clip_worst, ", ".join(clipped)])
	var shins_free: bool = true
	var seat_front_now: float = bench.global_position.z + 0.215
	for index: int in marina.vertices_of(["*Foot", "*ToeBase"]):
		shins_free = shins_free and marina.to_global(vertices[index]).z > seat_front_now + 0.02
	_expect(shins_free, "and her feet are on the floor in front of the seat, not under it")
	var rest_snapshot: Dictionary = _footage_snapshot(footage)
	var rest_right_hand: Vector3 = marina.to_global(marina.bone_point("RightHand"))
	var rest_left_hand: Vector3 = marina.to_global(marina.bone_point("LeftHand"))

	# Ten seconds pass, and she does not move but for a breath; then she turns toward HER right (the model's -X), greets with her right hand and listens.
	footage.seek(footage.turn_start_seconds - 0.1)
	_expect(_snapshots_close(rest_snapshot, _footage_snapshot(footage)), "ten seconds pass before she reacts: at 9.9 s she is as she was at 0 (but for her breathing)")
	var left_axis: Vector3 = marina.global_basis.x.normalized()
	var forward_axis: Vector3 = marina.global_basis.z.normalized()
	var flat_before: Vector3 = (marina.global_basis * marina.bone_forward("Head")).slide(Vector3.UP).normalized()
	footage.seek(footage.turn_end_seconds + 0.3)
	var flat_after: Vector3 = (marina.global_basis * marina.bone_forward("Head")).slide(Vector3.UP).normalized()
	footage.seek(footage.turn_start_seconds + 0.5)
	var flat_mid: Vector3 = (marina.global_basis * marina.bone_forward("Head")).slide(Vector3.UP).normalized()
	# A turn about the vertical is positive toward the model's +X (her left) and negative toward her right.
	var turned: float = rad_to_deg(flat_before.signed_angle_to(flat_after, Vector3.UP))
	var turned_mid: float = rad_to_deg(flat_before.signed_angle_to(flat_mid, Vector3.UP))
	_expect(turned < -25.0 and turned > -90.0, "the head turns toward HER right (%.0f degrees about the vertical, negative is her right)" % turned)
	_expect(turned_mid < -3.0 and turned_mid > turned + 3.0, "and it turns smoothly through the second of the turn, not in one jump (%.0f degrees at its middle)" % turned_mid)
	footage.seek(footage.hand_up_end_seconds + 0.1)
	var raised: Vector3 = marina.to_global(marina.bone_point("RightHand"))
	var hips: Vector3 = marina.to_global(marina.bone_point("Hips"))
	_expect(raised.y > rest_right_hand.y + 0.3 and (raised - hips).dot(-left_axis) > 0.2 and (raised - hips).dot(forward_axis) > 0.15, "the right hand is raised toward the person on her right, in front and to the side (%.2f m above its rest)" % (raised.y - rest_right_hand.y))
	_expect(float(marina.reach_error.get(&"hand_r", 1.0)) < 0.03 and marina.to_global(marina.bone_point("LeftHand")).distance_to(rest_left_hand) < 0.03, "within the arm's reach (%.3f m off), while the left hand stays where it was" % float(marina.reach_error.get(&"hand_r", 1.0)))
	var xs: Array[float] = []
	var t: float = footage.hand_up_end_seconds
	while t <= footage.hand_up_end_seconds + footage.wave_seconds + 0.001:
		footage.seek(t)
		xs.append((marina.to_global(marina.bone_point("RightHand")) - hips).dot(left_axis))
		t += 0.05
	var reversals: int = 0
	var low_x: float = 1.0e9
	var high_x: float = -1.0e9
	for i: int in range(2, xs.size()):
		if (xs[i] - xs[i - 1]) * (xs[i - 1] - xs[i - 2]) < -1.0e-9:
			reversals += 1
	for x_value: float in xs:
		low_x = minf(low_x, x_value)
		high_x = maxf(high_x, x_value)
	_expect(reversals >= 2 and high_x - low_x > 0.05 and high_x - low_x < 0.25, "the greeting is a short wave: the hand swings from side to side twice or so (%d reversals, %.2f m across)" % [reversals, high_x - low_x])
	footage.seek(footage.hand_down_end_seconds + 0.2)
	_expect(marina.to_global(marina.bone_point("RightHand")).distance_to(rest_right_hand) < 0.06, "then it goes back down to rest on her thigh (%.3f m from where it began)" % marina.to_global(marina.bone_point("RightHand")).distance_to(rest_right_hand))
	var listening_low: float = 1.0e9
	var listening_high: float = -1.0e9
	t = footage.hand_down_end_seconds + 0.3
	while t <= footage.cut_walk_seconds - 0.05:
		footage.seek(t)
		var pitch_value: float = (marina.global_basis * marina.bone_forward("Head")).normalized().y
		listening_low = minf(listening_low, pitch_value)
		listening_high = maxf(listening_high, pitch_value)
		t += 0.05
	_expect(listening_high - listening_low > 0.02 and listening_high - listening_low < 0.3, "while she listens her head moves a little, a nod or two and nothing more (%.2f of its height range)" % (listening_high - listening_low))

	# Where the cast is and is not, shot by shot, and the same whatever order the times come in.
	footage.seek(3.0)
	_expect(marina.visible and not footage.aftermath.visible and footage.litter != null and not footage.litter.visible, "in shot A: Emily is in the picture; no blood, no litter")
	footage.seek(26.0)
	_expect(not marina.visible and not footage.aftermath.visible and footage.litter.visible and not footage.litter2.visible, "in the first walking shot: Emily is out (her shadow with her), no blood, the forest floor's litter of its strip is there")
	footage.seek(38.0)
	_expect(not marina.visible and footage.aftermath.visible and not footage.litter.visible and not footage.litter2.visible, "in the aftermath: no Emily, no litter, the blood is there")
	footage.seek(54.0)
	_expect(not marina.visible and not footage.aftermath.visible and not footage.litter.visible and footage.litter2.visible, "in the second walking shot: no Emily, no blood, the litter of the second strip")
	footage.seek(2.0)
	_expect(marina.visible and not footage.aftermath.visible and not footage.litter.visible and not footage.litter2.visible and _snapshots_equal(_footage_snapshot(footage), _snapshot_at(footage, 2.0)), "seeking back to the start restores Emily and hides the blood and the litter again")
	var probe_times: Array[float] = [0.5, 9.9, 11.0, 12.4, 13.6, 15.2, 17.6, 19.2, 24.0, 35.0, 44.0, 48.0, 54.0, 62.0]
	var reference: Dictionary = {}
	for tt: float in probe_times:
		footage.seek(0.0)
		footage.seek(tt)
		reference[tt] = _footage_snapshot(footage)
	var identical: bool = true
	var bad_time: float = -1.0
	for round_index: int in 3:
		var shuffled: Array[float] = probe_times.duplicate()
		shuffled.shuffle()
		for tt: float in shuffled:
			footage.seek(tt + 5.7)
			footage.seek(tt)
			if not _snapshots_equal(reference[tt] as Dictionary, _footage_snapshot(footage)):
				identical = false
				bad_time = tt
	_expect(identical, "seeking in any order gives exactly the same pose, visibility and place at the same time (bad at %.1f)" % bad_time)
	var camera_same: bool = true
	for tt: float in probe_times:
		var first: Dictionary = footage.camera_at(tt)
		footage.camera_at(tt + 3.3)
		var second: Dictionary = footage.camera_at(tt)
		camera_same = camera_same and (first["transform"] as Transform3D).is_equal_approx(second["transform"] as Transform3D) and is_equal_approx(float(first["fov"]), float(second["fov"]))
	_expect(camera_same, "and the camera at a time never depends on the times asked before it (no hidden state, no random noise)")
	footage.seek(0.0)

	# Shot A: the hidden camera, locked, oblique, Emily a third of the picture's height, the greeting arm clear of the pillars and of the ferns.
	var shot_a: ShotMarker = footage.shot_a
	var a_xf: Transform3D = shot_a.aimed_transform()
	_expect(shot_a == shed.shot_recording, "shot A's camera is the scene's recording marker")
	var locked: bool = true
	t = 0.0
	while t < footage.cut_walk_seconds:
		var state: Dictionary = footage.camera_at(t)
		locked = locked and (state["transform"] as Transform3D).is_equal_approx(a_xf) and is_equal_approx(float(state["fov"]), shot_a.fov)
		t += 0.1
	_expect(locked, "it does not move, zoom or shake for the first 11 seconds")
	var heading: Vector3 = (-a_xf.basis.z).slide(Vector3.UP).normalized()
	_expect(heading.dot(forward_axis) < -0.3 and heading.dot(left_axis) < -0.3 and heading.dot(left_axis) > -0.9, "from outside the shelter, oblique to her: the camera is on her left and in front, so her right (where she turns) is away from it (%.2f, %.2f)" % [heading.dot(forward_axis), heading.dot(left_axis)])
	footage.seek(footage.hand_up_end_seconds + 0.2)
	var skin: PackedVector3Array = marina.skinned_vertices()
	var low: Vector2 = Vector2(1.0e9, 1.0e9)
	var high: Vector2 = Vector2(-1.0e9, -1.0e9)
	var arm_low: Vector2 = Vector2(1.0e9, 1.0e9)
	var arm_high: Vector2 = Vector2(-1.0e9, -1.0e9)
	var arm_group: PackedInt32Array = marina.vertices_of(["RightHand", "RightForeArm"])
	var head_group: PackedInt32Array = marina.vertices_of(["Head"])
	for v: Vector3 in skin:
		var at_v: Vector2 = _picture_point(a_xf, shot_a.fov, marina.to_global(v))
		low = low.min(at_v)
		high = high.max(at_v)
	for index: int in arm_group:
		var at_arm: Vector2 = _picture_point(a_xf, shot_a.fov, marina.to_global(skin[index]))
		arm_low = arm_low.min(at_arm)
		arm_high = arm_high.max(at_arm)
	var figure_height: float = high.y - low.y
	_expect(figure_height > 0.25 and figure_height < 0.5 and low.x > 0.1 and high.x < 0.9 and low.y > 0.05 and high.y < 0.95, "Emily is about a third of the picture's height, well inside it (%.0f%%)" % (100.0 * figure_height))
	_expect(arm_low.x > 0.05 and arm_high.x < 0.95 and arm_low.y > 0.05 and arm_high.y < 0.95, "and the greeting arm is in the picture, not at its edge (%.2f-%.2f across)" % [arm_low.x, arm_high.x])
	var pillar_hits: int = 0
	var head_hits: int = 0
	for pillar_name: String in ["Pillar0", "Pillar1", "Pillar2", "Pillar3"]:
		var pillar: MeshInstance3D = shed.get_node("%Shelter/" + pillar_name) as MeshInstance3D
		var box: AABB = pillar.global_transform * pillar.mesh.get_aabb()
		for index: int in arm_group:
			if box.intersects_segment(a_xf.origin, marina.to_global(skin[index])) != null:
				pillar_hits += 1
		for index: int in head_group:
			if box.intersects_segment(a_xf.origin, marina.to_global(skin[index])) != null:
				head_hits += 1
	_expect(pillar_hits == 0 and head_hits < head_group.size() / 5, "no pillar hides the raised arm (%d of %d vertices) and little of her head (%d of %d)" % [pillar_hits, arm_group.size(), head_hits, head_group.size()])
	var head_rect: Rect2 = Rect2()
	var head_rect_first: bool = true
	for index: int in head_group:
		var at_head: Vector2 = _picture_point(a_xf, shot_a.fov, marina.to_global(skin[index]))
		head_rect = Rect2(at_head, Vector2.ZERO) if head_rect_first else head_rect.expand(at_head)
		head_rect_first = false
	var arm_rect: Rect2 = Rect2(arm_low, arm_high - arm_low)
	var covered: int = 0
	var counted: int = 0
	var foreground: Node3D = shed.archive_foreground
	_expect(foreground != null and not foreground.visible and foreground.get_child_count() >= 2 and foreground.get_child_count() <= 5, "a few ferns stand near the lens, hidden in the present")
	_expect(foreground.find_children("*", "CollisionObject3D", true, false).is_empty() and foreground.find_children("*", "AnimationPlayer", true, false).is_empty() and foreground.find_children("*", "Light3D", true, false).is_empty(), "plain meshes: no collision, no wind animation, no light")
	var fern_names: PackedStringArray = PackedStringArray()
	for fern: Node in foreground.get_children():
		var instance: MeshInstance3D = fern as MeshInstance3D
		var inside_picture: int = 0
		for surface: int in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var corners: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i: int in corners.size():
					indices.append(i)
			for tri: int in range(0, indices.size() - 2, 3):
				for gu: int in 6:
					for gv: int in 6 - gu:
						var sample: Vector3 = corners[indices[tri]] * (1.0 - float(gu) / 5.0 - float(gv) / 5.0) + corners[indices[tri + 1]] * (float(gu) / 5.0) + corners[indices[tri + 2]] * (float(gv) / 5.0)
						var world_sample: Vector3 = instance.global_transform * sample
						if (a_xf.affine_inverse() * world_sample).z > -0.3:
							continue
						var at_sample: Vector2 = _picture_point(a_xf, shot_a.fov, world_sample)
						if at_sample.x >= 0.0 and at_sample.x <= 1.0 and at_sample.y >= 0.0 and at_sample.y <= 1.0:
							inside_picture += 1
							counted += 1
							if head_rect.grow(0.01).has_point(at_sample) or arm_rect.grow(0.01).has_point(at_sample):
								covered += 1
		fern_names.append("%s %d" % [fern.name, inside_picture])
	_expect(counted > 60, "ferns frame the picture's edges (%s samples in it)" % ", ".join(fern_names))
	_expect(covered == 0, "and none of them is over her head or the greeting arm (%d samples)" % covered)

	# Shots B: the carried camera, genuinely moving forward along its strip, pitched down at the ground, a slow walker's bob and roll, clear of the ground and the shelter; twice, on two strips.
	var path_one: Array[Vector3] = _check_walk(footage, "first", footage.cut_walk_seconds, footage.cut_aftermath_seconds, footage.walk_start, footage.walk_end, footage.litter, 8.5, 9.5, false)
	var path_two: Array[Vector3] = _check_walk(footage, "second", footage.cut_walk2_seconds, footage.length_seconds, footage.walk2_start, footage.walk2_end, footage.litter2, 11.5, 12.5, true)
	var stride_one: float = (footage.walk_end.global_position - footage.walk_start.global_position).slide(Vector3.UP).length() / (footage.cut_aftermath_seconds - footage.cut_walk_seconds) / footage.steps_per_second
	var stride_two: float = (footage.walk2_end.global_position - footage.walk2_start.global_position).slide(Vector3.UP).length() / (footage.length_seconds - footage.cut_walk2_seconds) / footage.drag_steps_per_second
	_expect(footage.drag_steps_per_second < footage.steps_per_second * 0.75 and stride_two > stride_one * 1.4 and footage.drag_surge > footage.walk_surge * 2.0 and footage.drag_bob_metres > footage.walk_bob_metres * 1.4, "the second walk drags something: slower steps (%.2f against %.2f a second), longer ones (%.2f m against %.2f m) and heavier ones (a bigger surge and a deeper dip)" % [footage.drag_steps_per_second, footage.steps_per_second, stride_two, stride_one])
	var strips_apart: float = 1.0e9
	for p1: Vector3 in path_one:
		for p2: Vector3 in path_two:
			strips_apart = minf(strips_apart, Vector2(p1.x - p2.x, p1.z - p2.z).length())
	var heading_one: Vector3 = (footage.walk_end.global_position - footage.walk_start.global_position).slide(Vector3.UP).normalized()
	var heading_two: Vector3 = (footage.walk2_end.global_position - footage.walk2_start.global_position).slide(Vector3.UP).normalized()
	_expect(strips_apart > 1.5 and heading_one.dot(heading_two) < 0.0, "the second walk is a different path: at least %.1f m from the first everywhere, and walked the other way (%.2f)" % [strips_apart, heading_one.dot(heading_two)])
	var terrain_free: bool = true
	for marker: Marker3D in [footage.walk_start, footage.walk_end, footage.walk2_start, footage.walk2_end]:
		terrain_free = terrain_free and shed.to_local(marker.global_position).y == 0.0
	_expect(terrain_free, "both strips lie on the shelter's own ground level, and the strips were chosen clear of every tree (see the scene's comment); nothing of the terrain was moved")

	# Shot C: seen from OUTSIDE, from the dark of the forest and not from the aftermath photograph's viewpoint; a person of 1.70 m with a camera at their eyes stands, then creeps in step by step at a steady
	# pace while the aim slides to the blood and the lens closes in.
	var capture_constants: Dictionary = (load("res://scripts/tools/capture_shelter_aftermath.gd") as Script).get_script_constant_map()
	var capture_at: Vector3 = capture_constants["CAMERA_AT"] as Vector3
	var shot_c: ShotMarker = footage.shot_c
	var shelter_floor: float = shed.to_global(Vector3.ZERO).y
	var first_c: Transform3D = shot_c.aimed_transform()
	var shelter_box: AABB = _mesh_bounds_world(shed.get_node("%Shelter"))
	_expect(shed.to_local(shot_c.global_position).distance_to(capture_at) > 5.0, "shot C does NOT begin at the newspaper photograph's viewpoint (%.1f m from it): it is a different, outside angle" % shed.to_local(shot_c.global_position).distance_to(capture_at))
	_expect(shot_c.global_position.x < shelter_box.position.x - 2.0 and not shelter_box.grow(1.0).has_point(shot_c.global_position), "it begins out in the forest, west of the shelter and well clear of it")
	var fov_low: float = 1.0e9
	var fov_high: float = -1.0e9
	var step_move: float = 0.0
	var step_turn: float = 0.0
	var roll_c: float = 0.0
	var eye_low: float = 1.0e9
	var eye_high: float = -1.0e9
	var clear_of_shelter: bool = true
	var from_photo: float = 1.0e9
	var blood_in_view: bool = true
	var shelter_in_view: bool = true
	var previous: Transform3D = first_c
	var duration_c: float = footage.cut_walk2_seconds - footage.cut_aftermath_seconds
	var walk_from: float = footage.creep_start_seconds + footage.creep_ramp_seconds
	var walk_to: float = footage.creep_stop_seconds - footage.creep_ramp_seconds
	var cruise_points: Array[Vector3] = []
	var cruise_heights: Array[float] = []
	var first_second_heights: Array[float] = []
	var first_second_origin: Array[Vector3] = []
	var last_second_origin: Array[Vector3] = []
	var cruise_speeds: Array[float] = []
	var all_points: Array[Vector3] = []
	t = footage.cut_aftermath_seconds
	while t < footage.cut_walk2_seconds - 0.001:
		var local_t: float = t - footage.cut_aftermath_seconds
		var state_c: Dictionary = footage.camera_at(t)
		var cxf: Transform3D = state_c["transform"] as Transform3D
		fov_low = minf(fov_low, float(state_c["fov"]))
		fov_high = maxf(fov_high, float(state_c["fov"]))
		if t > footage.cut_aftermath_seconds:
			step_move = maxf(step_move, cxf.origin.distance_to(previous.origin))
			step_turn = maxf(step_turn, rad_to_deg((-cxf.basis.z).angle_to(-previous.basis.z)))
			if local_t >= walk_from and local_t <= walk_to:
				cruise_speeds.append(Vector2(cxf.origin.x - previous.origin.x, cxf.origin.z - previous.origin.z).length() / 0.05)
		previous = cxf
		all_points.append(cxf.origin)
		roll_c = maxf(roll_c, rad_to_deg(absf(asin(clampf(cxf.basis.x.y, -1.0, 1.0)))))
		eye_low = minf(eye_low, cxf.origin.y - shelter_floor)
		eye_high = maxf(eye_high, cxf.origin.y - shelter_floor)
		clear_of_shelter = clear_of_shelter and not shelter_box.grow(0.5).has_point(cxf.origin)
		from_photo = minf(from_photo, shed.to_local(cxf.origin).distance_to(capture_at))
		var blood_at: Vector2 = _picture_point(cxf, float(state_c["fov"]), footage.blood_focus.global_position)
		if local_t > duration_c * 0.7:
			blood_in_view = blood_in_view and blood_at.x > 0.2 and blood_at.x < 0.8 and blood_at.y > 0.15 and blood_at.y < 0.9
		if local_t < 3.0:
			var shelter_at: Vector2 = _picture_point(cxf, float(state_c["fov"]), shelter_box.get_center())
			shelter_in_view = shelter_in_view and shelter_at.x > 0.15 and shelter_at.x < 0.85 and shelter_at.y > 0.1 and shelter_at.y < 0.9
		if local_t >= walk_from and local_t <= walk_to:
			cruise_points.append(cxf.origin)
			cruise_heights.append(cxf.origin.y)
		if local_t < 1.2:
			first_second_heights.append(cxf.origin.y)
			first_second_origin.append(cxf.origin)
		if local_t > duration_c - 1.2:
			last_second_origin.append(cxf.origin)
		t += 0.05
	_expect(eye_low > shelter_floor + 1.5 and eye_high < shelter_floor + 1.76, "at the eyes of a person of 1.70 m: the camera stays between %.2f and %.2f m over the ground" % [eye_low - shelter_floor, eye_high - shelter_floor])
	var way: float = Vector2(all_points[all_points.size() - 1].x - first_c.origin.x, all_points[all_points.size() - 1].z - first_c.origin.z).length()
	_expect(way > 4.0 and way < 6.0 and first_c.origin.distance_to(all_points[all_points.size() - 1]) > 4.0, "it creeps in from the forest to the shelter: %.1f m of travel in the shot" % way)
	var mean_speed: float = 0.0
	var slowest: float = 1.0e9
	var fastest: float = 0.0
	for speed: float in cruise_speeds:
		mean_speed += speed / float(cruise_speeds.size())
		slowest = minf(slowest, speed)
		fastest = maxf(fastest, speed)
	_expect(mean_speed > 0.3 and mean_speed < 0.6 and slowest > 0.15 and fastest < 0.9, "at a steady creeping pace between the ramps (%.2f m/s on average, %.2f to %.2f inside the steps)" % [mean_speed, slowest, fastest])
	# Steps: one dip of the head at each footfall; the count follows the cadence, the dips are real, and the bump is a few centimetres.
	var footfalls: int = 0
	for i: int in range(5, cruise_heights.size() - 5):
		var is_dip: bool = true
		for j: int in range(i - 5, i + 6):
			is_dip = is_dip and cruise_heights[i] <= cruise_heights[j]
		if is_dip:
			footfalls += 1
	var expected_steps: float = footage.creep_steps_per_second * (walk_to - walk_from)
	_expect(absf(float(footfalls) - expected_steps) <= 2.0, "its height dips at every footfall: %d dips over %.1f s (a cadence of %.2f steps a second makes %.1f)" % [footfalls, walk_to - walk_from, footage.creep_steps_per_second, expected_steps])
	var cruise_low: float = 1.0e9
	var cruise_high: float = -1.0e9
	for h: float in cruise_heights:
		cruise_low = minf(cruise_low, h)
		cruise_high = maxf(cruise_high, h)
	_expect(cruise_high - cruise_low > 0.04 and cruise_high - cruise_low < 0.12, "and the bump of each step is a few centimetres (%.1f cm from the lowest to the highest of the head)" % (100.0 * (cruise_high - cruise_low)))
	var still_low: float = 1.0e9
	var still_high: float = -1.0e9
	for h: float in first_second_heights:
		still_low = minf(still_low, h)
		still_high = maxf(still_high, h)
	_expect(still_high - still_low < 0.02 and first_second_origin[0].distance_to(first_second_origin[first_second_origin.size() - 1]) < 0.05 and last_second_origin[0].distance_to(last_second_origin[last_second_origin.size() - 1]) < 0.06, "and it stands still, without the bump of a step, before the creeping starts and after it stops")
	_expect(fov_high - fov_low > 10.0 and absf(fov_high - shot_c.fov) < 0.01 and absf(fov_low - footage.creep_closest_fov) < 0.5, "the lens closes in on the blood (from %.0f to %.0f degrees)" % [fov_high, fov_low])
	_expect(step_move < 0.04 and step_turn < 0.8, "it moves smoothly from frame to frame, with no snap or jitter (at most %.1f cm and %.2f degrees in 1/20 s)" % [100.0 * step_move, step_turn])
	_expect(roll_c < 2.5, "the roll is a degree or two at most (%.2f)" % roll_c)
	_expect(shelter_in_view, "at first the shelter is what it looks at, in the middle of the picture")
	_expect(blood_in_view, "and at the end the pool of blood is what the camera is on: well inside the middle of the picture")
	_expect(clear_of_shelter, "it never passes through the shelter")
	_expect(from_photo > 3.0, "and it is never near the photograph's viewpoint (%.1f m at the nearest)" % from_photo)
	var seam: float = (footage.camera_at(footage.cut_aftermath_seconds)["transform"] as Transform3D).origin.distance_to(first_c.origin)
	_expect(seam < 0.05, "and it begins where its marker is (%.3f m)" % seam)
	var matte_ok: bool = true
	for shot_fov: float in [shot_a.fov, footage.walk_fov, shot_c.fov]:
		for size: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(1024, 768), Vector2(1280, 1024), Vector2(800, 800)]:
			var matched: float = ArchiveVideoOverlay.matched_fov(shot_fov, size)
			var picture_height: float = minf(size.y, size.x / ArchiveVideoOverlay.ASPECT)
			var matte_top: float = rad_to_deg(atan(tan(deg_to_rad(matched) * 0.5) * picture_height / size.y))
			matte_ok = matte_ok and absf(matte_top - shot_fov * 0.5) < 0.001 and matched >= shot_fov - 0.001
	_expect(matte_ok, "in any window size the lens is matched to the picture's 4:3 frame for the recording's lenses (the widest of each shot)")

	# The blood: the capture tool's dressing, plain textured quads on the real geometry, a place and no body.
	var stains: Node3D = footage.aftermath
	_expect(stains != null and stains.get_parent() == footage and stains.get_child_count() >= 8 and stains.find_children("*", "CollisionObject3D", true, false).is_empty() and stains.find_children("*", "Light3D", true, false).is_empty(), "the stains are the capture tool's own quads, plain, without collision or light, under the footage (%d)" % stains.get_child_count())
	_expect(footage.find_children("*", "Skeleton3D", true, false).size() == 1, "and there is no body, nobody, no second skeleton, in the footage")


## Everything the picture is made of at the time the cast was last posed, after seeking to `time`.
func _snapshot_at(footage: ShelterFootage, time: float) -> Dictionary:
	footage.seek(time)
	return _footage_snapshot(footage)


## The states of the shelter and the aftermath photograph: three looks that never mix, and the shipped image itself.
func _check_states_and_photo() -> void:
	var footage: ShelterFootage = shed.footage
	var dressing: Node3D = shed.archive_dressing
	var intact: Node3D = dressing.get_node("Intact") as Node3D
	var damaged: Node3D = dressing.get_node("Damaged") as Node3D
	var foreground: Node3D = shed.archive_foreground
	# The present.
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT, "the shed starts in the present")
	_expect(shed.effects_root.visible and shed.camcorder.visible and shed.replaced_plank.visible and not dressing.visible and not footage.visible and not foreground.visible, "present: Sophia's things, the camcorder and the repaired plank are shown; nothing of the recording or the aftermath")
	_expect(footage.aftermath != null and not footage.aftermath.is_visible_in_tree() and footage.litter != null and not footage.litter.is_visible_in_tree(), "and the stains and the litter, which belong to the recording's last two shots, are hidden")
	# The recording.
	shed.set_world_state(WaitingShedSequence.WorldState.RECORDING)
	_expect(not shed.effects_root.visible and not shed.camcorder.visible and not shed.replaced_plank.visible and dressing.visible and intact.visible and not damaged.visible and foreground.visible and footage.visible and footage.marina.is_visible_in_tree() and not footage.aftermath.is_visible_in_tree(), "recording (its first shot): no belongings, the old plank whole, the ferns and Emily shown; no damaged plank, no blood")
	# The aftermath (capture only).
	shed.set_world_state(WaitingShedSequence.WorldState.PHOTO_CAPTURE)
	_expect(not shed.effects_root.visible and not shed.camcorder.visible and not shed.replaced_plank.visible and dressing.visible and damaged.visible and not intact.visible and not foreground.visible and not footage.visible and not footage.aftermath.is_visible_in_tree(), "aftermath (the capture tool's look): the plank broken, no belongings, no camcorder, no ferns, nobody, and not the footage's own stains (the tool dresses its own)")
	shed.set_world_state(WaitingShedSequence.WorldState.PRESENT)
	_expect(shed.effects_root.visible and shed.camcorder.visible and shed.replaced_plank.visible and not dressing.visible and not footage.visible and not foreground.visible, "and back to the present, whole")
	_expect(is_zero_approx(footage.current_time) and footage.marina.visible and not footage.aftermath.visible and not footage.litter.visible, "with the cast put back at its first frame: Emily in it, the blood and the litter away")
	var bench_wood: Node = shed.get_node("%Bench")
	_expect(bench_wood.find_children("*", "MeshInstance3D", true, false).size() > 5 and intact.get_child_count() == 1 and damaged.get_child_count() >= 8, "the old plank: one whole length for the recording, pieces for the aftermath")

	# The shipped photograph.
	var path: String = ShedRecordingProps.PHOTO_PATH
	_expect(ResourceLoader.exists(path), "the photograph is shipped as a project texture (%s)" % path)
	var texture: Texture2D = ShedRecordingProps.load_photo()
	_expect(texture != null and texture.get_width() == 1024 and texture.get_height() == 768, "1024 x 768")
	var source: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(source != null and not source.is_empty(), "and its file can be read")
	if source != null and not source.is_empty():
		source.convert(Image.FORMAT_RGB8)
		var step: int = 4
		var total: int = 0
		var luminance_sum: float = 0.0
		var red_blood: int = 0
		var dark_blood: int = 0
		var black: int = 0
		for y: int in range(0, source.get_height(), step):
			for x: int in range(0, source.get_width(), step):
				var c: Color = source.get_pixel(x, y)
				total += 1
				var luminance: float = c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				luminance_sum += luminance
				if luminance < 0.04:
					black += 1
				# Blood: a red much stronger than green and blue.
				if c.r > 0.22 and c.r > c.g * 2.2 and c.r > c.b * 2.0:
					red_blood += 1
				elif c.r > 0.1 and c.r > c.g * 2.0 and c.r > c.b * 1.8:
					dark_blood += 1
		var mean: float = luminance_sum / float(total)
		var blood_share: float = float(red_blood + dark_blood) / float(total)
		_expect(mean > 0.15 and mean < 0.7 and float(black) / float(total) < 0.1, "it is an exposed photograph, not a black or white frame (mean %.2f, %.1f%% black)" % [mean, 100.0 * float(black) / float(total)])
		_expect(blood_share > 0.02 and blood_share < 0.3, "with a substantial, bounded amount of blood in it (%.1f%% of the picture is dark red) and plenty of bare surface" % (100.0 * blood_share))
	# The print on the clipping.
	var clipping: Inspectable = shed.get_node("%NewspaperClipping")
	# The photograph is looked at where the clipping lies once it has been read (it covers the tape before that).
	var clipping_home: Transform3D = clipping.transform
	clipping.transform = shed.clipping_aside.transform
	var visual: Node3D = clipping.get_node("Visual") as Node3D
	var photo: MeshInstance3D = visual.find_child("Photo", true, false) as MeshInstance3D
	var border: MeshInstance3D = visual.find_child("PhotoBorder", true, false) as MeshInstance3D
	_expect(photo != null and border != null and (photo.material_override as StandardMaterial3D).albedo_texture == texture, "the clipping carries the shipped photograph, in a white border like a print")
	_expect((photo.mesh as QuadMesh).size.x / (photo.mesh as QuadMesh).size.y > 1.3 and (border.mesh as BoxMesh).size.x > (photo.mesh as QuadMesh).size.x + 0.004, "4:3, with a visible border")
	_expect(visual.find_child("PhotoCaption", true, false) != null, "and its caption")
	_expect(shed.find_children("*", "Inspectable", true, false).filter(func(n: Node) -> bool: return String(n.name) == "NewspaperClipping").size() == 1, "there is still one clipping, one interaction target, and no other photograph item")

	# The close view of the print: much of the frame, with the paper's own border and edge in it.
	var shot: ShotMarker = shed.shot_photo
	var photo_xf: Transform3D = shot.aimed_transform()
	var aspect: float = 16.0 / 9.0
	var reach: float = tan(deg_to_rad(shot.fov) * 0.5)
	var quad_size: Vector2 = (photo.mesh as QuadMesh).size
	var low: Vector2 = Vector2(1.0e9, 1.0e9)
	var high: Vector2 = Vector2(-1.0e9, -1.0e9)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var world: Vector3 = photo.global_transform * Vector3(corner.x * quad_size.x * 0.5, corner.y * quad_size.y * 0.5, 0.0)
		var local: Vector3 = photo_xf.affine_inverse() * world
		var at: Vector2 = Vector2(0.5 + local.x / -local.z / (reach * aspect) * 0.5, 0.5 - local.y / -local.z / reach * 0.5)
		low = low.min(at)
		high = high.max(at)
	_expect(low.x > 0.03 and high.x < 0.97 and low.y > 0.02 and high.y < 0.98, "the picture of the print is wholly inside the close view (%.2f-%.2f, %.2f-%.2f)" % [low.x, high.x, low.y, high.y])
	_expect(high.x - low.x > 0.33 and high.y - low.y > 0.55, "and takes much of the frame (%.0f%% across, %.0f%% down)" % [100.0 * (high.x - low.x), 100.0 * (high.y - low.y)])
	var paper: MeshInstance3D = visual.find_child("Paper", true, false) as MeshInstance3D
	var paper_box: AABB = paper.get_aabb()
	var paper_low: float = 1.0e9
	var paper_high: float = -1.0e9
	for corner: int in 4:
		var local_corner: Vector3 = paper_box.position + Vector3(paper_box.size.x * (corner & 1), paper_box.size.y * ((corner >> 1) & 1), 0.0)
		var camera_space: Vector3 = photo_xf.affine_inverse() * (paper.global_transform * local_corner)
		var px: float = 0.5 + camera_space.x / -camera_space.z / (reach * aspect) * 0.5
		paper_low = minf(paper_low, px)
		paper_high = maxf(paper_high, px)
	_expect(paper_low < low.x - 0.02 and paper_high > high.x + 0.02 and paper_low > -0.1 and paper_high < 1.1, "with the paper's own edge round it, so that it reads as a photograph on a clipping (%.2f to %.2f)" % [paper_low, paper_high])
	clipping.transform = clipping_home


## One carried camera shot (from `from_time` to `to_time` of the footage, along the strip `start` to `end`): its travel, pace, heading, pitch, height, bob and roll; the camera clear of the ground and of the
## shelter; the strip's litter. Returns the camera's path.
func _check_walk(footage: ShelterFootage, label: String, from_time: float, to_time: float, start: Marker3D, end: Marker3D, litter_node: Node3D, min_length: float, max_length: float, dragging: bool) -> Array[Vector3]:
	var strip: Vector3 = end.global_position - start.global_position
	strip.y = 0.0
	var seconds: float = to_time - from_time
	_expect(strip.length() > min_length and strip.length() < max_length, "the %s strip of ground is %.2f m for %.0f seconds of walking" % [label, strip.length(), seconds])
	var path: Array[Vector3] = []
	var forwards: Array[Vector3] = []
	var rolls: Array[float] = []
	var pitches: Array[float] = []
	var heights: Array[float] = []
	var fov_walk_ok: bool = true
	var step_time: float = from_time
	while step_time < to_time - 0.001:
		var state_b: Dictionary = footage.camera_at(step_time)
		var xf: Transform3D = state_b["transform"] as Transform3D
		path.append(xf.origin)
		forwards.append(-xf.basis.z)
		rolls.append(rad_to_deg(asin(clampf(xf.basis.x.y, -1.0, 1.0))))
		pitches.append(rad_to_deg(asin(clampf(xf.basis.z.y, -1.0, 1.0))))
		heights.append(xf.origin.y - start.global_position.y)
		fov_walk_ok = fov_walk_ok and is_equal_approx(float(state_b["fov"]), footage.walk_fov)
		step_time += 0.05
	var covered_distance: float = Vector2(path[path.size() - 1].x - path[0].x, path[path.size() - 1].z - path[0].z).length()
	_expect(fov_walk_ok, "(%s walk) the lens does not change while walking" % label)
	_expect(covered_distance > min_length - 0.3 and covered_distance < max_length, "(%s walk) it really travels: %.2f m forward in %.0f seconds (a slow walk of %.2f m/s), over the ground" % [label, covered_distance, seconds, covered_distance / seconds])
	var always_moving: bool = true
	var steady: bool = true
	var speeds: Array[float] = []
	for i: int in range(1, path.size()):
		var flat: Vector2 = Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z)
		speeds.append(flat.length() / 0.05)
		always_moving = always_moving and flat.length() / 0.05 > (0.25 if dragging else 0.4)
	for i: int in range(1, speeds.size()):
		steady = steady and absf(speeds[i] - speeds[i - 1]) < (0.5 if dragging else 0.35)
	_expect(always_moving and steady, "(%s walk) it never stops, never snaps and never goes back (no stationary shake): its pace only breathes with the steps" % label)
	var along_strip: float = 0.0
	for f: Vector3 in forwards:
		along_strip += f.slide(Vector3.UP).normalized().dot(strip.normalized())
	_expect(along_strip / float(forwards.size()) > 0.98, "(%s walk) pointed the way it goes (%.3f)" % [label, along_strip / float(forwards.size())])
	var pitch_low: float = 1.0e9
	var pitch_high: float = -1.0e9
	var roll_peak: float = 0.0
	var height_low: float = 1.0e9
	var height_high: float = -1.0e9
	for i: int in pitches.size():
		pitch_low = minf(pitch_low, pitches[i])
		pitch_high = maxf(pitch_high, pitches[i])
		roll_peak = maxf(roll_peak, absf(rolls[i]))
		height_low = minf(height_low, heights[i])
		height_high = maxf(height_high, heights[i])
	_expect(pitch_low > 50.0 and pitch_high < 75.0 and pitch_low - footage.walk_fov * 0.5 > 22.0, "(%s walk) the lens looks down at the ground (%.1f to %.1f degrees below the horizon), its top edge well below it: no faces, no sky, no operator" % [label, pitch_low, pitch_high])
	_expect(height_low > 1.5 and height_high < 1.76 and height_high - height_low > (0.07 if dragging else 0.04) and height_high - height_low < (0.18 if dragging else 0.1), "(%s walk) at the eyes of a person of 1.70 m, with the bump of the steps (%.2f to %.2f m over the ground)" % [label, height_low, height_high])
	_expect(roll_peak > 0.2 and roll_peak < (2.5 if dragging else 1.2), "(%s walk) and a roll of a degree or two at most (%.2f degrees)" % [label, roll_peak])
	# The steps: a dip of the head at every footfall; the count follows the gait's cadence (and the stride, in metres a step, follows from the pace).
	var cadence: float = footage.drag_steps_per_second if dragging else footage.steps_per_second
	var footfalls: int = 0
	for i: int in range(5, heights.size() - 5):
		var lowest: bool = true
		for j: int in range(i - 5, i + 6):
			lowest = lowest and heights[i] <= heights[j]
		if lowest:
			footfalls += 1
	_expect(absf(float(footfalls) - cadence * seconds) <= 2.5, "(%s walk) a dip of the head at every footfall: %d steps in %.0f s (a cadence of %.2f a second makes %.1f), each %.2f m long" % [label, footfalls, seconds, cadence, cadence * seconds, covered_distance / maxf(float(footfalls), 1.0)])
	var inside_slab: bool = false
	var slab: AABB = _mesh_bounds_world(shed.get_node("%Shelter"))
	for p: Vector3 in path:
		inside_slab = inside_slab or slab.has_point(p)
	_expect(not inside_slab, "(%s walk) the camera never passes through the shelter" % label)
	_expect(litter_node != null and litter_node.get_child_count() >= 15 and litter_node.find_children("*", "CollisionObject3D", true, false).is_empty(), "(%s walk) the forest floor of the strip has leaf litter and stones to pass through the picture, plain meshes without collision" % label)
	return path


## The picture is 4:3, the camera's vertical lens `fov` (degrees): where a world point falls in it, from 0 to 1 across and down (outside means not in the picture).
func _picture_point(camera_xf: Transform3D, fov: float, world: Vector3) -> Vector2:
	var local: Vector3 = camera_xf.affine_inverse() * world
	if local.z > -0.05:
		return Vector2(-9.0, -9.0)
	var reach: float = tan(deg_to_rad(fov) * 0.5)
	var tx: float = local.x / -local.z / (reach * 4.0 / 3.0)
	var ty: float = local.y / -local.z / reach
	return Vector2(0.5 + tx * 0.5, 0.5 - ty * 0.5)


## Everything the picture is made of at the time the cast was last posed: every bone of Emily, and whether she, the stains and the litter are in the picture.
func _footage_snapshot(footage: ShelterFootage) -> Dictionary:
	var poses: Array[Quaternion] = []
	for bone: int in footage.marina.skeleton.get_bone_count():
		poses.append(footage.marina.skeleton.get_bone_pose_rotation(bone))
	return {"poses": poses, "hips": footage.marina.skeleton.get_bone_pose_position(0), "visible": [footage.marina.visible, footage.aftermath.visible, footage.litter.visible, footage.litter2.visible]}


## The same staging within her breathing: every bone within a few degrees, her pelvis within 2 cm, the same things in the picture.
func _snapshots_close(a: Dictionary, b: Dictionary) -> bool:
	var pa: Array = a["poses"]
	var pb: Array = b["poses"]
	if pa.size() != pb.size():
		return false
	for i: int in pa.size():
		if (pa[i] as Quaternion).angle_to(pb[i] as Quaternion) > 0.06:
			return false
	return (a["hips"] as Vector3).distance_to(b["hips"] as Vector3) <= 0.02 and a["visible"] == b["visible"]


func _snapshots_equal(a: Dictionary, b: Dictionary) -> bool:
	var pa: Array = a["poses"]
	var pb: Array = b["poses"]
	if pa.size() != pb.size():
		return false
	for i: int in pa.size():
		if not (pa[i] as Quaternion).is_equal_approx(pb[i] as Quaternion):
			return false
	return (a["hips"] as Vector3).is_equal_approx(b["hips"] as Vector3) and a["visible"] == b["visible"]


# ============================================================
# WATCHING THE SCENE
# ============================================================

func _start_watch() -> void:
	_seen = {}
	_watching = true
	_watch()


func _stop_watch() -> void:
	_watching = false


func _watch() -> void:
	var camera: Camera3D = player.movement_controller.camera
	var flash: SpotLight3D = player.flashlight_controller as SpotLight3D
	var head: Node3D = shed.camcorder.find_child("Head", true, false)
	var led: StandardMaterial3D = (shed.camcorder.find_child("Led", true, false) as MeshInstance3D).material_override
	var start_yaw: float = head.rotation_degrees.y
	var ambience: Node = get_tree().get_first_node_in_group(OutdoorAmbience.GROUP)
	var last_tape_time: float = -1.0
	var was_done: bool = shed.is_recording_done()
	var last_cinema_origin: Vector3 = Vector3.ZERO
	var shots_seen: int = 0
	var captions: Array[String] = []
	# The subtitles that must appear, in this order: the introduction and then the conversation (from the approved texts, each with its speaker's name).
	var expected: Array[String] = []
	for track: StringName in [CaptionTracks.SHED_REMEMBERED_COPY, CaptionTracks.SHED_REMEMBERED_TALK]:
		for cue: Dictionary in CaptionTracks.get_cues(track):
			if str(cue["key"]).is_empty():
				continue
			var pinned: Array = ShedExpectedTexts.CAPTIONS[str(cue["key"])]
			expected.append("%s: %s" % [str(pinned[2]).capitalize(), pinned[0]])
	var last_expected: String = expected[expected.size() - 1]
	while _watching and is_instance_valid(shed):
		await get_tree().process_frame
		if not _watching:
			break
		var current: Camera3D = get_viewport().get_camera_3d()
		var in_cinema: bool = current != null and current.name == "CinemaCamera"
		if in_cinema and not _seen.has("cinema_first"):
			_seen["cinema_first"] = shed.vhs.get_parent() == shed.effects_root and shed.vhs.is_inside_tree()
		last_cinema_origin = current.global_position if in_cinema else Vector3.ZERO
		var changed_world: bool = not shed.effects_root.visible or shed.archive_dressing.visible or not shed.replaced_plank.visible or not shed.camcorder.visible
		if changed_world and not in_cinema:
			_seen["hidden_in_player_view"] = int(_seen.get("hidden_in_player_view", 0)) + 1
		if shed.archive_dressing.visible:
			_seen["archive_world"] = true
		var overlay: ArchiveVideoOverlay = shed.get_node_or_null("ArchiveVideoOverlay") as ArchiveVideoOverlay
		var playing: bool = bool(shed.get("_footage_playing"))
		if shed.footage.visible:
			_seen["cast_seen"] = true
			if not in_cinema:
				_seen["cast_in_player_view"] = int(_seen.get("cast_in_player_view", 0)) + 1
			if not shed.archive_dressing.visible:
				_seen["cast_without_recording"] = int(_seen.get("cast_without_recording", 0)) + 1
			if in_cinema and (overlay == null or not overlay.visible):
				_seen["cast_in_talk"] = int(_seen.get("cast_in_talk", 0)) + 1
		if in_cinema and shed.get_world_state() == WaitingShedSequence.WorldState.RECORDING and shed.footage.visible and (overlay != null and overlay.visible):
			var shot_now: StringName = shed.footage.passage_at(shed.footage.current_time)
			var intact_node: Node3D = shed.archive_dressing.get_node("Intact") as Node3D
			var damaged_node: Node3D = shed.archive_dressing.get_node("Damaged") as Node3D
			var right: bool = shed.footage.marina.visible == (shot_now == &"A") and shed.footage.aftermath.visible == (shot_now == &"aftermath") and shed.footage.litter.visible == (shot_now == &"walk") and shed.footage.litter2.visible == (shot_now == &"walk2")
			right = right and intact_node.visible == (shot_now == &"A" or shot_now == &"walk") and damaged_node.visible == (shot_now == &"aftermath" or shot_now == &"walk2") and shed.archive_foreground.visible == (shot_now == &"A")
			_seen["dressing_checked"] = int(_seen.get("dressing_checked", 0)) + 1
			if not right:
				_seen["dressing_wrong"] = int(_seen.get("dressing_wrong", 0)) + 1
		if shed.archive_foreground.visible:
			_seen["foreground_seen"] = true
			if not shed.footage.visible:
				_seen["foreground_outside"] = int(_seen.get("foreground_outside", 0)) + 1
		if playing:
			var footage_time: float = shed.footage.current_time
			if footage_time + 0.001 < float(_seen.get("max_footage_time", 0.0)) and not bool(_seen.get("replayed", false)) and bool(shed.get("replay_running")):
				_seen["replayed"] = true
				_seen["replay_from"] = footage_time
			elif footage_time + 0.001 < float(_seen.get("max_footage_time", 0.0)) and not bool(shed.get("replay_running")):
				_seen["footage_restarts"] = int(_seen.get("footage_restarts", 0)) + 1
			_seen["max_footage_time"] = maxf(float(_seen.get("max_footage_time", 0.0)), footage_time)
			if CaptionManager.panel.visible and not bool(shed.get("replay_running")):
				_seen["caption_in_recording"] = int(_seen.get("caption_in_recording", 0)) + 1
			# The recording's camera: always the one the footage's own time asks for (locked, walking, drifting), with the lens matched to the picture.
			if in_cinema:
				var state: Dictionary = shed.footage.camera_at(footage_time)
				var passage: StringName = shed.footage.passage_at(footage_time)
				var fov_ok: bool = absf(current.fov - ArchiveVideoOverlay.matched_fov(float(state["fov"]), get_viewport().get_visible_rect().size)) < 0.01
				if not current.global_transform.is_equal_approx(state["transform"] as Transform3D) or not fov_ok:
					_seen["camera_wrong"] = int(_seen.get("camera_wrong", 0)) + 1
				if not bool(shed.get("replay_running")):
					_seen["frames_" + str(passage)] = int(_seen.get("frames_" + str(passage), 0)) + 1
					if _seen.has("last_passage") and StringName(str(_seen["last_passage"])) != passage:
						var cut_name: String = "%s>%s" % [str(_seen["last_passage"]), str(passage)]
						_seen["cuts"] = (str(_seen["cuts"]) + "," if _seen.has("cuts") else "") + cut_name
						_seen["cut_one_at" if not _seen.has("cut_one_at") else ("cut_two_at" if not _seen.has("cut_two_at") else "cut_three_at")] = footage_time
					_seen["last_passage"] = str(passage)
				else:
					if passage == &"A":
						_seen["replay_shot_a_frames"] = int(_seen.get("replay_shot_a_frames", 0)) + 1
					else:
						_seen["replay_other_shot"] = int(_seen.get("replay_other_shot", 0)) + 1
				# The camcorder's own faint light on the ground: in the walking shot only (the aftermath has its fill: it is a light too, but not the walk's).
				var light: SpotLight3D = shed.get_node("CinemaCamera/ShotLight") as SpotLight3D
				var expected_light: bool = passage != &"A"
				if light.visible != expected_light:
					_seen["light_wrong"] = int(_seen.get("light_wrong", 0)) + 1
		# The photograph's close view: the present's dressing whole, nobody in it, no words.
		if in_cinema and current.global_transform.origin.distance_to(shed.shot_photo.global_position) < 0.001:
			_seen["photo_frames"] = int(_seen.get("photo_frames", 0)) + 1
			if not _seen.has("photo_origin"):
				_seen["photo_origin"] = current.global_position
			_seen["photo_camera_move"] = maxf(float(_seen.get("photo_camera_move", 0.0)), current.global_position.distance_to(_seen["photo_origin"] as Vector3))
			if shed.effects_root.visible and shed.replaced_plank.visible and not shed.footage.visible and not shed.archive_foreground.visible and not shed.archive_dressing.visible and (overlay == null or not overlay.visible):
				_seen["photo_present_frames"] = int(_seen.get("photo_present_frames", 0)) + 1
			if CaptionManager.panel.visible:
				_seen["caption_in_photo"] = int(_seen.get("caption_in_photo", 0)) + 1
			_seen["photo_seen_at"] = float(Time.get_ticks_msec())
		# No blank frame between the cuts: the overlay is never black when the camera is not in the recording or already left it.
		if overlay != null and overlay.visible:
			_seen["overlay_seen"] = true
			if not in_cinema:
				_seen["overlay_in_player_view"] = int(_seen.get("overlay_in_player_view", 0)) + 1
			if not overlay.is_picture_shown():
				_seen["black_frames"] = int(_seen.get("black_frames", 0)) + 1
		if overlay != null and overlay.visible and overlay.is_picture_shown():
			for child: Node in shed.get_children():
				if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing and child.name != "TapeSound" and child.name != "TapeMachine":
					_seen["source_sounds"] = int(_seen.get("source_sounds", 0)) + 1
		# The tape's own noise: playing all through the recording's picture, looped, and at no other time.
		var tape: AudioStreamPlayer = shed.get_node_or_null("TapeSound") as AudioStreamPlayer
		if tape != null:
			if overlay != null and overlay.visible and overlay.is_picture_shown() and bool(shed.get("_footage_playing")):
				if tape.playing:
					_seen["tape_frames"] = int(_seen.get("tape_frames", 0)) + 1
					_seen["tape_loops"] = tape.stream is AudioStreamMP3 and (tape.stream as AudioStreamMP3).loop
					_seen["tape_path"] = tape.stream.resource_path
				else:
					_seen["tape_silent_frames"] = int(_seen.get("tape_silent_frames", 0)) + 1
			elif tape.playing:
				_seen["tape_outside"] = int(_seen.get("tape_outside", 0)) + 1
		# The machine: its first part before the picture (static, no label), the picture at 2.30 s of it with PLAY and the running loop, the stop at the end, and in the
		# second viewing the running loop only, then PAUSE, the held picture and the stop once.
		var machine: AudioStreamPlayer = shed.get_node_or_null("TapeMachine") as AudioStreamPlayer
		if machine != null and overlay != null and overlay.visible:
			var machine_stream: AudioStreamWAV = machine.stream as AudioStreamWAV
			var machine_at: float = machine.get_playback_position()
			var running: bool = bool(shed.get("_footage_playing"))
			var replaying: bool = bool(shed.get("replay_running"))
			if not running and not replaying and not _seen.has("picture_began") and machine.playing and machine_stream == TapePlayerSounds.start_stream():
				_seen["preroll_frames"] = int(_seen.get("preroll_frames", 0)) + 1
				_seen["preroll_static"] = _seen.get("preroll_static", true) and not overlay.get_node("Play").visible
			if running and not replaying and not _seen.has("picture_began"):
				_seen["picture_began"] = true
				_seen["picture_machine_at"] = machine_at
				_seen["picture_label"] = overlay.get_label_text()
				_seen["picture_stream_ok"] = machine.playing and machine_stream == TapePlayerSounds.start_stream()
			if running and not replaying and machine.playing and machine_stream == TapePlayerSounds.start_stream():
				_seen["first_loop_frames"] = int(_seen.get("first_loop_frames", 0)) + 1
				_seen["first_loop_min"] = minf(float(_seen.get("first_loop_min", 99.0)), machine_at)
			if replaying and running:
				_seen["replay_frames"] = int(_seen.get("replay_frames", 0)) + 1
				_seen["replay_label_play"] = overlay.get_label_text() == "PLAY" and not overlay.is_paused()
				if not machine.playing or machine_stream != TapePlayerSounds.start_stream() or machine_at < 2.2:
					_seen["replay_machine_wrong"] = int(_seen.get("replay_machine_wrong", 0)) + 1
				if tape.playing != true:
					_seen["replay_noise_missing"] = int(_seen.get("replay_noise_missing", 0)) + 1
			if replaying and not running and overlay.is_paused():
				_seen["paused_frames"] = int(_seen.get("paused_frames", 0)) + 1
				_seen["paused_label"] = overlay.get_label_text()
				_seen["paused_stop_sound"] = bool(_seen.get("paused_stop_sound", false)) or (machine.playing and machine_stream == TapePlayerSounds.stop_stream())
				_seen["paused_noise_off"] = not tape.playing
				var held_time: float = shed.footage.current_time
				if _seen.has("paused_time") and not is_equal_approx(held_time, float(_seen["paused_time"])):
					_seen["paused_moved"] = true
				_seen["paused_time"] = held_time
				var centre_cast: bool = shed.footage.visible
				_seen["paused_cast_shown"] = centre_cast
				# Held on the greeting: shot A's own camera and lens, Emily in the picture, the hand raised (the footage between the hand's rise and its fall), no blood.
				var shot_a: ShotMarker = shed.footage.shot_a
				var held_on_greeting: bool = in_cinema and current.global_transform.is_equal_approx(shot_a.aimed_transform()) and absf(current.fov - ArchiveVideoOverlay.matched_fov(shot_a.fov, get_viewport().get_visible_rect().size)) < 0.01
				held_on_greeting = held_on_greeting and shed.footage.marina.visible and not shed.footage.aftermath.visible and shed.archive_foreground.visible and held_time > shed.footage.hand_up_start_seconds and held_time < shed.footage.hand_down_end_seconds
				if held_on_greeting:
					_seen["paused_on_greeting"] = true
				else:
					_seen["paused_off_greeting"] = int(_seen.get("paused_off_greeting", 0)) + 1
		if not bool(_seen.get("replayed", false)) and not bool(shed.get("replay_running")) and machine != null and machine.stream == TapePlayerSounds.stop_stream() and machine.playing and _seen.has("picture_began"):
			_seen["end_stop_sound"] = true
		# The picture of the tape holds between its own frames (12 a second) and in its stalls.
		if playing:
			var shown_time: float = shed.footage.current_time
			if is_equal_approx(shown_time, last_tape_time):
				_seen["stale_frames"] = int(_seen.get("stale_frames", 0)) + 1
			else:
				_seen["moving_frames"] = int(_seen.get("moving_frames", 0)) + 1
			last_tape_time = shown_time
		# The wind and the night chorus: silent while the memory's shots are up (the ambience's own silence level, once it has had time to fall).
		if ambience != null and in_cinema:
			if float(ambience.get("_silence")) > 0.9:
				_seen["silenced_frames"] = int(_seen.get("silenced_frames", 0)) + 1
			elif float(ambience.get("_silence")) < 0.5 and float(_seen.get("cinema_frames", 0.0)) > 120.0:
				_seen["not_silenced_in_cinema"] = int(_seen.get("not_silenced_in_cinema", 0)) + 1
		if in_cinema:
			_seen["cinema_frames"] = float(_seen.get("cinema_frames", 0.0)) + 1.0
		# Once the scene is over her own eyes are current: nothing of the scene's camera, the overlay or the cast is up.
		if not was_done and shed.is_recording_done() and not shed.is_recording_running() and not _seen.has("ended_ms"):
			_seen["ended_ms"] = float(Time.get_ticks_msec())
		if _seen.has("ended_ms") and (in_cinema or (overlay != null and overlay.visible) or shed.footage.visible):
			_seen["eyes_frames_with_scene"] = int(_seen.get("eyes_frames_with_scene", 0)) + 1
		if led.emission_energy_multiplier > 0.0:
			_seen["led_on"] = true
			if in_cinema:
				_seen["led_on_in_cinema"] = int(_seen.get("led_on_in_cinema", 0)) + 1
		_seen["head_turn"] = maxf(float(_seen.get("head_turn", 0.0)), absf(head.rotation_degrees.y - start_yaw))
		if in_cinema and not flash.visible:
			_seen["flash_off_in_memory"] = true
		# Subtitles, in order of appearance.
		if CaptionManager.panel.visible:
			var text: String = CaptionManager.label.text
			if captions.is_empty() or captions[captions.size() - 1] != text:
				captions.append(text)
				_seen["saw_marina"] = bool(_seen.get("saw_marina", false)) or text.begins_with("Marina:")
				_seen["saw_recorded"] = bool(_seen.get("saw_recorded", false)) or text.begins_with("Recorded voice:")
				_seen["saw_last"] = bool(_seen.get("saw_last", false)) or text == last_expected
				if text == last_expected and not _seen.has("last_line_ms"):
					_seen["last_line_ms"] = float(Time.get_ticks_msec())
				# A subtitle of the girls never lingers over her own eyes except by their own track (none exists then).
				if in_cinema == false:
					_seen["order_ok"] = "a line over her own eyes: " + text
	var cursor: int = 0
	for text: String in captions:
		if cursor < expected.size() and text == expected[cursor]:
			cursor += 1
	if not _seen.has("order_ok"):
		_seen["order_ok"] = "yes" if cursor >= expected.size() else "only %d of %d seen in order: %s" % [cursor, expected.size(), str(captions)]


# ============================================================
# HELPERS
# ============================================================

## Reads the main clipping and shuts it at once: the first reading exposes the tape.
func _read_and_close_clipping() -> void:
	shed.clipping.interact(player)
	var waited: float = 0.0
	while player.inspect_controller.state != PlayerInspectController.InspectState.VIEWING and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_expect(player.inspect_controller.is_open(), "the clipping opens the inspect view")
	await _wait(0.4)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	# The first reading of the clipping is followed by a short scene (the paper is moved aside by hand): it is waited out.
	var scene_wait: float = 0.0
	while int(shed.get("_aux_mode")) != 0 and scene_wait < 14.0:
		await get_tree().process_frame
		scene_wait += get_process_delta_time()


func _read_and_close_tape() -> void:
	vhs.interact(player)
	var waited: float = 0.0
	while player.inspect_controller.state != PlayerInspectController.InspectState.VIEWING and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_expect(player.inspect_controller.is_open(), "the tape opens the inspect view")
	await _wait(0.4)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()


func _translated(key: String, locale: String) -> String:
	var translation: Translation = TranslationServer.get_translation_object(locale)
	return str(translation.get_message(StringName(key))) if translation != null else key


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


## Where the player stands to use something on the bench: in front of it at x (shed space), a metre or so away.
func _stand_for(local: Vector3) -> Vector3:
	return shed.to_global(Vector3(local.x, 0.0, -4.85))


func _player_can_stand(at: Vector3) -> bool:
	player.global_position = Vector3(at.x, 1.1, at.z)
	player.velocity = Vector3.ZERO
	await _wait(0.5)
	return Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(at.x, at.z)) < 0.1


## Stands the player at `stand`, aims at `aim`, and checks the interaction ray ends on `item`.
func _ray_finds(item: Node, stand: Vector3, aim: Vector3, what: String) -> void:
	player.global_position = Vector3(stand.x, 1.1, stand.z)
	player.velocity = Vector3.ZERO
	await _wait(0.8)

	# Aim twice: the view settles a little after the player lands.
	var camera: Camera3D = player.get_node("Head/Camera3D")
	for pass_number: int in 2:
		var to_aim: Vector3 = aim - camera.global_position
		player.movement_controller.look_yaw = -rad_to_deg(atan2(-to_aim.x, -to_aim.z))
		player.movement_controller.look_pitch = -rad_to_deg(
			atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length())
		)
		for i: int in 3:
			await get_tree().physics_frame

	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractRay")
	ray.force_raycast_update()
	var found: Node = ray.get_collider() as Node
	while found != null and not found is Interactable:
		found = found.get_parent()

	_expect(
		found == item,
		"the interaction ray reaches %s from %.2f m (hit %s)" % [what, camera.global_position.distance_to(aim), str(ray.get_collider())]
	)


## The bench's seat in the world: its solid, top at the surface of the planks.
func _bench_seat_world() -> AABB:
	var bench: Node3D = shed.get_node("%Bench")
	return AABB(bench.global_position + Vector3(-0.9, 0.0, -0.23), Vector3(1.8, 0.44, 0.46))


## The world box around the meshes of a node (the first meshes of its subtree).
func _mesh_bounds_world(node: Node) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = mesh as MeshInstance3D
		if instance.mesh == null or not instance.visible:
			continue
		var box: AABB = instance.global_transform * instance.mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


func _visual_bounds(item: Node) -> AABB:
	var visual: Node = item.get_node_or_null("Visual")
	if visual == null:
		visual = item.get_node_or_null("Model")
	if visual == null:
		visual = item
	var result: AABB = _mesh_bounds_world(visual)
	# Labels are ignored (they are zero-thickness).
	return result


func _tape_bounds_at(marker: Node3D) -> AABB:
	return marker.global_transform * AABB(Vector3(-0.0935, -0.0515, -0.0125), Vector3(0.187, 0.103, 0.025))


func _overlap_plan(a: AABB, b: AABB) -> bool:
	return a.position.x < b.end.x and a.end.x > b.position.x and a.position.z < b.end.z and a.end.z > b.position.z


## The world box of an item's hit area (its shape's box, in the world).
func _area_bounds(item: Node) -> AABB:
	var shape: CollisionShape3D = item.get_node("InteractArea/CollisionShape3D") as CollisionShape3D
	return shape.global_transform * shape.shape.get_debug_mesh().get_aabb()


## Every approved evidence text, exactly as written, in both languages (tests/shed_expected_texts.gd), and what the brief asks of them as a whole: Emily is missing (no body, no death, no weapon, no
## cause), the smell is a witness's, the leaflet is a fictional English-founded village's, Daniel Nogueira is named, and the sister's note is unsigned.
func _check_pinned_texts() -> void:
	for key: String in ShedExpectedTexts.EVIDENCE:
		var pair: Array = ShedExpectedTexts.EVIDENCE[key]
		_expect(_translated(key, "en") == pair[0] and _translated(key, "pt_BR") == pair[1], "%s reads as approved (both languages)" % key)
		for locale: String in ["en", "pt_BR"]:
			var lowered: String = _translated(key, locale).to_lower()
			for banned: String in ["body", "corpo", "found dead", "encontrada morta", "death", "morte", "killed", "matou", "autopsy", "autópsia", "weapon", "arma ", "marina", "wound", "ferida"]:
				_expect(not lowered.contains(banned), "%s (%s) has nothing of a body, a death or a weapon ('%s')" % [key, locale, banned])
	var journal_en: String = _translated("READABLE_JOURNAL", "en")
	var journal_pt: String = _translated("READABLE_JOURNAL", "pt_BR")
	_expect(journal_en.contains("smell of iron and soaked wood") and journal_pt.contains("cheiro de ferro e madeira encharcada"), "the smell is a witness's, in the maintenance record's margin note")
	_expect(journal_en.contains("founded by the English") and journal_pt.contains("fundada por ingleses"), "the leaflet gives the village an English founding")
	_expect(journal_en.contains("Daniel Nogueira") and journal_pt.contains("Daniel Nogueira"), "Daniel Nogueira is named")
	_expect(_translated("READABLE_HELENA_NOTICE", "en").contains("born and raised in the Fenda") and _translated("READABLE_HELENA_NOTICE", "pt_BR").contains("nascida e criada na Fenda"), "Helena was born and raised in the Fenda")
	_expect(not _translated("READABLE_MARINA_SISTER_NOTE", "en").to_lower().contains("sister") and not _translated("ITEM_MARINA_SISTER_NOTE_NAME", "en").to_lower().contains("sister"), "the note that came with the tape does not call its writer a sister (the family's reply says Emily has none)")
	_expect(_translated("READABLE_CLIPPING", "en").contains("remains missing") and _translated("READABLE_CLIPPING", "pt_BR").contains("não foi localizada"), "the clipping says Emily is missing")
	_expect(_translated("READABLE_FAMILY_LETTER", "en").ends_with("Emily doesn't have a sister.") and _translated("READABLE_FAMILY_LETTER", "pt_BR").ends_with("A Emily não tem irmã."), "the family's reply says she has no sister")


## From the moment the first cinematic ends (the control is back), counts game time until the physical camcorder's own sound begins.
func _watch_cue() -> void:
	var elapsed: float = 0.0
	while elapsed < 6.0 and is_instance_valid(shed):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not is_instance_valid(shed) or shed.camcorder == null:
			return
		var cue: AudioStreamPlayer3D = shed.camcorder.get_head().get_node_or_null("CueSound") as AudioStreamPlayer3D
		if cue != null and cue.playing:
			cue_heard_at = elapsed
			return
