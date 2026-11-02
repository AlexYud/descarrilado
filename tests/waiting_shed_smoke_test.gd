extends Node

## Plays the waiting shed ("The Shelter Stayed Open") through the game's own APIs: the removed puzzle is gone, the bench cluster fits the bench, the box
## opens with a plain interaction and shows the tape over the token, the tape and the token are reached by the interaction ray as they should be, the first close of
## the tape's view hands the player to the recording scene without a gap, the scene runs once (about 22 s of SILENT, fixed-camera footage: Marina on the bench, a
## visitor whose head is never in the picture; then a still close view of the print on the clipping, then the remembered conversation; the cameras, the shelter's
## three looks under the cuts, the camcorder, the held view and flashlight given back), the token is then free and taken normally, and old saves are mapped (never
## replaying the scene, never bringing the token back). `_check_footage` and `_check_states_and_photo` check the rig, the walk, the crop of the visitor's head over
## the whole timeline, the fixed picture, the ferns and the shipped photograph by their numbers. Run it as a scene; it quits by itself with a non-zero exit code on
## failure. Game time runs faster so the waits are short. It cannot judge the picture, the acting or the pace: see the screenshots taken separately.

const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_waiting_shed_smoke"
const TEST_SCENE_PATH: String = "res://scenes/levels/waiting_shed_playtest.tscn"
const TIME_SCALE: float = 4.0

var test_failed: bool = false
var completed_count: int = 0

var level: Node = null
var shed: WaitingShedSequence = null
var player: CharacterBody3D = null
var container: OpenableContainer = null
var vhs: Inspectable = null
var ficha: Collectible = null

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
	await _check_box_and_rays()
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
	container = shed.get_node("%SwitchBox")
	vhs = shed.vhs
	ficha = shed.ficha
	shed.recording_finished.connect(func() -> void: completed_count += 1)
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
	_expect(shed.find_child("TicketPuncher", true, false) == null and container.get_node_or_null("Contents/TicketPuncher") == null, "the ticket puncher is not in the box")
	_expect(shed.find_child("Lever*", true, false) == null, "nothing in the shed is called a lever")

	# The bin: scenery with nothing to use.
	var bin: Node = shed.get_node("Platform/ShelterBin")
	_expect(bin.get_child_count() > 3 and bin.find_children("*", "Interactable", true, false).is_empty(), "the bin is scenery with nothing to use")
	_expect(not ((bin as Node) is Interactable) and not ((bin.get_parent() as Node) is Interactable), "the bin is not interactable")
	_expect(shed.get_node("Platform/PersonalEffects/Backpack").find_children("*", "Area3D", true, false).is_empty(), "the backpack is scenery only")

	# The recording's dressing is hidden, the camcorder is there from the start with its light off.
	_expect(not shed.archive_dressing.visible, "the recording's dressing is hidden in the present")
	_expect(shed.replaced_plank != null and shed.replaced_plank.visible, "the replaced plank is shown in the present")
	var camcorder: Node3D = shed.camcorder
	_expect(camcorder != null and camcorder.visible and camcorder is Inspectable, "the camcorder stands in the level from the start, examinable")
	var led: MeshInstance3D = camcorder.find_child("Led", true, false) as MeshInstance3D
	_expect(led != null and (led.material_override as StandardMaterial3D).emission_energy_multiplier == 0.0, "its recording light is off")
	_expect(tr((camcorder as Inspectable).get_inspect_data()["name"]) == "Camcorder", "the camcorder is a Camcorder")
	_expect(tr((camcorder as Inspectable).get_inspect_data()["description"]) == "A camcorder mounted on a tripod. Its lens faces the shelter bench.", "with its description")
	var head: Node3D = camcorder.find_child("Head", true, false) as Node3D
	_expect(head != null and absf(head.rotation_degrees.y - shed.camcorder_start_yaw_degrees) < 0.01, "its head is turned a little off the bench's middle")
	var lens: Vector3 = head.to_global(Vector3(0.0, 0.1, -0.2))
	var bench: Node3D = shed.get_node("%Bench")
	_expect(absf(lens.y - 1.33) < 0.06, "its lens is about 1.3 m up (%.2f)" % lens.y)
	_expect(lens.z - bench.global_position.z > 6.0 and lens.z - bench.global_position.z < 8.5, "about 7 m from the bench (%.1f m)" % (lens.z - bench.global_position.z))
	_expect(absf(lens.x - bench.global_position.x) < 0.2, "straight across the clearing from the bench")
	# It faces the bench.
	var facing: Vector3 = -head.global_basis.z
	var to_bench: Vector3 = (bench.global_position - lens).normalized()
	_expect(facing.dot(to_bench) > 0.99, "its lens faces the bench")


func _check_text() -> void:
	var journal: Inspectable = shed.get_node("%SophiaJournal")
	_expect(tr(journal.get_inspect_data()["name"]) == "Sophia's Notebook", "the notebook is Sophia's Notebook")
	_expect(tr(journal.get_inspect_data()["description"]) == "Clippings folded between pages of notes about the shelter.", "with its description")
	var old_words: Array[String] = ["light the track", "punch the ticket", "blow the signal", "junction box", "wrench", "secret code", "lever"]
	for key: String in ["READABLE_JOURNAL", "JOURNAL_LEFT", "JOURNAL_RIGHT", "JOURNAL_EXTRACT", "JOURNAL_MARGIN"]:
		for locale: String in ["en", "pt_BR"]:
			var text: String = _translated(key, locale).to_lower()
			_expect(not text.is_empty() and text != key.to_lower(), "%s has %s text" % [key, locale])
			for word: String in old_words:
				_expect(not text.contains(word), "%s (%s) has none of the old clue %s" % [key, locale, word])

	# The notebook: the copy has no sound (once), the sister thinks Marina knew the person, who was filming; no help, no timestamp, no cause.
	var undecided: Array[String] = ["stabb", "knife", "firearm", "pistol", "bullet", "gunshot", "revólver", "arma de fogo", "strangl", "poison", "overdose", "beaten", "weapon", "wound", "autopsy", "faca", "tiro", "arma ", "estrangul", "veneno", "espancad", "ferimento", "autópsia", "facada"]
	for locale: String in ["en", "pt_BR"]:
		var full: String = _translated("READABLE_JOURNAL", locale)
		var needle: String = "Marina, 34" if locale == "en" else "Marina, 34 anos"
		_expect(full.contains(needle), "the notebook's reading text starts with Marina (%s)" % locale)
		var extract: String = "Cleared for use." if locale == "en" else "Liberado para uso."
		_expect(full.contains(extract), "the maintenance extract is in the same reading text (%s)" % locale)
		var margin: String = "school transcript" if locale == "en" else "histórico escolar"
		_expect(full.contains(margin), "and the margin note (%s)" % locale)
		_expect(_translated("JOURNAL_EXTRACT", locale).contains(extract), "the world page carries the extract too (%s)" % locale)
		var no_sound: String = "The copy I was lent has no sound." if locale == "en" else "A cópia que me emprestaram está sem som."
		_expect(full.count(no_sound) == 1 and _translated("JOURNAL_RIGHT", locale).count(no_sound) == 1, "the notebook says the copy has no sound, once, in the reading text and on the page (%s)" % locale)
		var knew: String = "Her sister thinks Marina knew the person in the recording. She asked me to look again." if locale == "en" else "A irmã acha que Marina conhecia a pessoa da fita. Pediu para eu olhar de novo."
		_expect(full.contains(knew) and _translated("JOURNAL_LEFT", locale).contains(knew), "the sister thinks Marina knew the person, in the reading text and on the page (%s)" % locale)
		for old: String in (["tried to help", "someone was with her at the end"] if locale == "en" else ["tentou ajudá-la", "havia alguém com ela no fim"]):
			_expect(not full.contains(old) and not _translated("JOURNAL_LEFT", locale).contains(old), "the old sentence '%s' is gone (%s)" % [old, locale])
		var filming: String = "Who was filming?" if locale == "en" else "Quem estava filmando?"
		_expect(full.count(filming) == 1 and _translated("JOURNAL_RIGHT", locale).count(filming) == 1, "'Who was filming?' is on the list, once (%s)" % locale)
		_expect(full.contains("excerpt" if locale == "en" else "trecho") and full.contains("Ask who passed on the copy" if locale == "en" else "quem passou a cópia") and full.contains("Ask who kept the original" if locale == "en" else "quem ficou com o original"), "the questions about the copy and the original stay (%s)" % locale)
		_expect(full.contains("— Sophia") and full.contains("“No witnesses”" if locale == "en" else "“Sem testemunhas”"), "the signature and the 'no witnesses' caution stay (%s)" % locale)
		for last_word: String in (["last person", "that night", "same night"] if locale == "en" else ["última pessoa", "naquela noite", "mesma noite"]):
			_expect(not full.to_lower().contains(last_word), "the notebook does not say '%s' (%s)" % [last_word, locale])

	# The clipping with its photograph: name, description, reading text and caption, in both languages; the cause of death left undisclosed.
	var clipping: Inspectable = shed.get_node("%NewspaperClipping")
	_expect(tr(clipping.get_inspect_data()["name"]) == "Clipping with Photograph", "the clipping is a Clipping with Photograph")
	_expect(_translated("ITEM_CLIPPING_NAME", "pt_BR") == "Recorte com fotografia", "and its Portuguese name")
	_expect(_translated("ITEM_CLIPPING_DESCRIPTION", "en") == "A photograph of the shelter is attached to the clipping. Blood covers part of the seat, runs between the planks, and darkens the floor around it. The body had already been removed when the picture was taken.", "its description (en)")
	_expect(_translated("ITEM_CLIPPING_DESCRIPTION", "pt_BR") == "Uma fotografia do abrigo foi presa ao recorte. O sangue cobre parte do assento, escorre entre as tábuas e escurece o piso ao redor. O corpo já havia sido retirado quando a imagem foi feita.", "its description (pt_BR)")
	_expect(_translated("READABLE_CLIPPING", "en").contains("WOMAN FOUND DEAD AT BRANCH-LINE SHELTER") and _translated("READABLE_CLIPPING", "en").contains("on the ground between the bench and one of the pillars") and _translated("READABLE_CLIPPING", "en").contains("The cause of death had not been released when this edition went to press."), "the reading text: headline, where the body lay, the cause not released (en)")
	_expect(_translated("READABLE_CLIPPING", "pt_BR").contains("MULHER ENCONTRADA MORTA NO ABRIGO DO RAMAL") and _translated("READABLE_CLIPPING", "pt_BR").contains("no chão, entre o banco e um dos pilares") and _translated("READABLE_CLIPPING", "pt_BR").contains("A causa da morte não havia sido divulgada até o fechamento desta edição."), "and in Portuguese")
	_expect(_translated("READABLE_CLIPPING", "en").contains("her clothes were bloodstained, and there was blood on the bench and floor") and _translated("READABLE_CLIPPING", "pt_BR").contains("as roupas estavam ensanguentadas e havia sangue no banco e no piso"), "the paper reports the blood as reported information")
	_expect(_translated("PHOTO_CAPTION_SHELTER", "en") == "Branch-line shelter, after the body was removed." and _translated("PHOTO_CAPTION_SHELTER", "pt_BR") == "Abrigo do ramal, após a retirada do corpo.", "the photograph's caption, in both languages")
	for key: String in ["READABLE_CLIPPING", "ITEM_CLIPPING_DESCRIPTION", "READABLE_JOURNAL", "JOURNAL_LEFT", "JOURNAL_RIGHT", "ITEM_VHS_DESCRIPTION", "PHOTO_CAPTION_SHELTER"]:
		for locale: String in ["en", "pt_BR"]:
			var lowered: String = _translated(key, locale).to_lower()
			for word: String in undecided:
				_expect(not lowered.contains(word), "%s (%s) names no weapon, wound or method of death ('%s')" % [key, locale, word])
			for claim: String in ["unexplained", "could not determine", "inexplic", "não foi possível determinar"]:
				_expect(not lowered.contains(claim), "%s (%s) does not say the cause is medically unexplained ('%s')" % [key, locale, claim])

	_expect(vhs.prompt_text == "PROMPT_EXAMINE_TAPE" and tr(vhs.prompt_text) == "Examine tape", "the tape says Examine tape")
	_expect(tr(vhs.get_inspect_data()["name"]) == "Videotape", "the tape is a Videotape")
	_expect(_translated("ITEM_VHS_NAME", "pt_BR") == "Fita de vídeo", "(Fita de vídeo)")
	_expect(_translated("ITEM_VHS_DESCRIPTION", "en") == "A silent copy associated with the investigation into Marina's death. The label does not identify who made the recording.", "the tape's description (en)")
	_expect(_translated("ITEM_VHS_DESCRIPTION", "pt_BR") == "Uma cópia sem som, associada à investigação da morte de Marina. A etiqueta não identifica quem fez a gravação.", "and (pt_BR)")
	_expect(vhs.get_node("Visual").get_meta("inspect_id") == "sophia_vhs", "its inspect id is sophia_vhs")
	_expect(not ((vhs as Node) is Collectible), "the tape is examined, never collected")
	_expect(tr("ITEM_SOPHIA_FICHA_NAME") == "Sophia's Telephone Token" and _translated("ITEM_SOPHIA_FICHA_NAME", "pt_BR") == "Ficha de Sophia", "the token's name")
	_expect(_translated("ITEM_SOPHIA_FICHA_DESCRIPTION", "pt_BR") == "Uma ficha de telefone de latão, guardada entre os papéis de Sophia.", "and description (pt_BR)")
	_expect(ficha.item_id == "sophia_ficha" and ficha.scene_file_path == "res://scenes/objects/waiting_shed/sophia_ficha.tscn", "the token keeps its id and its scene")

	# The captions: Portuguese and English, one speaker's line each, full speaker names, nothing for the recording, nothing of the old scene.
	_expect(CaptionTracks.get_cues(&"shed_recording").is_empty() and CaptionTracks.get_cues(&"shed_recording_again").is_empty() and CaptionTracks.get_cues(&"shed_review").is_empty(), "the silent recording has no caption track, and there is no review")
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
			var en_text: String = _translated(key, "en")
			var pt_text: String = _translated(key, "pt_BR")
			_expect(not en_text.is_empty() and en_text != key and not pt_text.is_empty() and pt_text != key, "%s is written in both languages" % key)
			var speaker: String = str(cue.get("speaker", ""))
			_expect(speaker == CaptionTracks.SPEAKER_SOPHIA or speaker == CaptionTracks.SPEAKER_JULIANA, "%s is spoken by Sophia or Juliana, never by anyone in the recording" % key)
			_expect(en_text.length() < 60 and pt_text.length() < 60, "%s is one short line" % key)
			for banned: String in ["help", "ajud", "lip", "lábio", "watch it again", "ver de novo", "bag", "bolsa", "turn it off", "desliga"]:
				_expect(not en_text.to_lower().contains(banned) and not pt_text.to_lower().contains(banned), "%s has nothing of the old scene (%s)" % [key, banned])
	_expect(cue_count == 11, "three lines of introduction and eight of conversation (%d)" % cue_count)
	_expect(_translated("CAPTION_SPEAKER_SOPHIA", "en") == "Sophia" and _translated("CAPTION_SPEAKER_JULIANA", "en") == "Juliana", "the speakers are labelled with their names")
	var intro: float = CaptionTracks.get_length(CaptionTracks.SHED_REMEMBERED_COPY)
	var talk: float = CaptionTracks.get_length(CaptionTracks.SHED_REMEMBERED_TALK)
	_expect(intro >= 8.0 and intro <= 10.0, "the introduction is about 8 to 10 s (%.1f)" % intro)
	_expect(talk >= 18.0 and talk <= 23.0, "the conversation is about 18 to 23 s (%.1f)" % talk)
	var talk_cues: Array = CaptionTracks.get_cues(CaptionTracks.SHED_REMEMBERED_TALK)
	var widest_gap: float = 0.0
	var gap_before: String = ""
	for i: int in range(1, talk_cues.size()):
		var gap: float = float(talk_cues[i]["start"]) - float(talk_cues[i - 1]["end"])
		if gap > widest_gap:
			widest_gap = gap
			gap_before = str(talk_cues[i]["key"])
	_expect(widest_gap >= 1.0 and widest_gap <= 2.5 and gap_before == "CAPTION_SHED_TALK_08", "a small unfilled pause (%.1f s) comes before Sophia's last answer (%s)" % [widest_gap, gap_before])
	var expected_lines: Dictionary = {
		"CAPTION_SHED_MEM_01": ["This is the copy Marina's sister lent me.", "Essa é a cópia que a irmã da Marina me emprestou."],
		"CAPTION_SHED_MEM_02": ["There's no sound?", "Tá sem som?"],
		"CAPTION_SHED_MEM_03": ["The copy came like this.", "A cópia veio assim."],
		"CAPTION_SHED_TALK_01": ["Does she know that person?", "Ela conhece essa pessoa?"],
		"CAPTION_SHED_TALK_02": ["Her sister thinks so.", "A irmã acha que sim."],
		"CAPTION_SHED_TALK_03": ["Did you recognize them?", "Você reconheceu?"],
		"CAPTION_SHED_TALK_04": ["No.", "Não."],
		"CAPTION_SHED_TALK_05": ["And who's filming?", "E quem está filmando?"],
		"CAPTION_SHED_TALK_06": ["That's what I asked.", "Foi o que eu perguntei."],
		"CAPTION_SHED_TALK_07": ["And?", "E?"],
		"CAPTION_SHED_TALK_08": ["They offered me a better copy.", "Me ofereceram uma cópia melhor."],
	}
	for key: String in expected_lines:
		_expect(_translated(key, "en") == (expected_lines[key] as Array)[0] and _translated(key, "pt_BR") == (expected_lines[key] as Array)[1], "%s reads as written (both languages)" % key)
	for gone: String in ["CAPTION_SPEAKER_MARINA", "CAPTION_SPEAKER_RECORDED_VOICE", "CAPTION_SHED_REC_01", "CAPTION_SHED_REC_07", "CAPTION_SHED_OFF", "CAPTION_SHED_REVIEW_01", "CAPTION_SHED_REVIEW_03", "CAPTION_SHED_TALK_09", "CAPTION_SHED_TALK_11", "CAPTION_SHED_TALK_12", "CAPTION_SHED_TALK_13"]:
		_expect(_translated(gone, "en").is_empty() and _translated(gone, "pt_BR").is_empty(), "%s no longer exists" % gone)


func _check_bench_fit() -> void:
	var bench: Node3D = shed.get_node("%Bench")
	var seat: AABB = _bench_seat_world()
	var items: Dictionary = {
		"backpack": shed.get_node("Platform/PersonalEffects/Backpack"),
		"notebook": shed.get_node("%SophiaJournal"),
		"clipping": shed.get_node("%NewspaperClipping"),
		"box": shed.get_node("%SwitchBox"),
		"tape set down": shed.vhs_set_down,
	}
	var boxes: Dictionary = {}
	for label: String in items.keys():
		var item: Node3D = items[label]
		var bounds: AABB = _visual_bounds(item) if label != "tape set down" else _tape_bounds_at(shed.vhs_set_down)
		boxes[label] = bounds
		# Each sits on the seat with a margin to its ends (0.1 m) and does not hang off the front or back.
		_expect(bounds.position.x >= seat.position.x + 0.05 and bounds.end.x <= seat.end.x - 0.05, "%s is on the seat with a margin at the ends" % label)
		_expect(bounds.position.z >= seat.position.z - 0.02 and bounds.end.z <= seat.end.z + 0.04, "%s does not overhang the seat" % label)
		_expect(bounds.position.y >= seat.end.y - 0.03 and bounds.position.y <= seat.end.y + 0.07, "%s rests on the seat (%.3f over it)" % [label, bounds.position.y - seat.end.y])

	# The three groups do not overlap in plan (only the clipping lies over the notebook, on purpose).
	for a: String in ["backpack", "notebook", "box", "tape set down"]:
		for b: String in ["backpack", "notebook", "box", "tape set down"]:
			if a < b:
				_expect(not _overlap_plan(boxes[a], boxes[b]), "%s and %s do not overlap on the seat" % [a, b])
	_expect(not _overlap_plan(boxes["clipping"], boxes["box"]) and not _overlap_plan(boxes["clipping"], boxes["tape set down"]), "the clipping touches neither the box nor the tape's place")
	_expect(_overlap_plan(boxes["clipping"], boxes["notebook"]), "the clipping lies over the notebook's page")

	# The open lid stays clear of the notebook, the backpack and anything behind the bench.
	var lid: Node3D = container.get_node("Model/LidPivot")
	lid.rotation_degrees.x = -container.lid_open_degrees
	var lid_bounds: AABB = _mesh_bounds_world(lid)
	lid.rotation_degrees.x = 0.0
	_expect(lid_bounds.position.z > seat.position.z - 0.12, "the open lid does not reach back into the wall (%.2f behind the seat)" % (seat.position.z - lid_bounds.position.z))
	_expect(not _overlap_plan(lid_bounds, boxes["notebook"]) and not _overlap_plan(lid_bounds, boxes["backpack"]), "the open lid cuts through neither the notebook nor the backpack")

	# The tape inside the box fits its floor.
	var inner: AABB = _box_inner_world()
	_expect(inner.size.x > 0.25 and inner.size.z > 0.15, "the box has room inside")
	var tape_in_box: AABB = _tape_bounds_world_from(vhs.get_parent(), vhs.transform)
	_expect(tape_in_box.position.x > inner.position.x and tape_in_box.end.x < inner.end.x and tape_in_box.position.z > inner.position.z and tape_in_box.end.z < inner.end.z, "the tape fits inside the box")
	var token_flat: Vector3 = container.to_global((vhs.get_parent() as Node3D).transform * ficha.transform * Vector3.ZERO)
	_expect(token_flat.x - 0.026 > inner.position.x and token_flat.x + 0.026 < inner.end.x and token_flat.z - 0.026 > inner.position.z and token_flat.z + 0.026 < inner.end.z, "and the token lies on its floor, under the tape")
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
	_expect(await _player_can_stand(bench.global_position + Vector3(-0.3, 0.0, 0.85)), "the player's capsule fits in front of the notebook")
	_expect(await _player_can_stand(bench.global_position + Vector3(0.6, 0.0, 0.85)), "and in front of the box")


func _check_box_and_rays() -> void:
	_expect(container.can_interact(player), "the closed box can be opened")
	_expect(container.get_prompt_text() == "PROMPT_OPEN", "it says open")
	_expect(vhs.get_parent() != null and not vhs.is_inside_tree() and not ficha.is_inside_tree(), "the tape and the token are out of reach and out of sight while the box is shut")
	_expect(not ficha.pickup_enabled, "the token cannot be taken yet")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)) == false, "the scene is not done")

	await _ray_finds(container, _stand_for(Vector3(-3.8, 0.0, 0.0)), container.global_position + Vector3(0.0, 0.03, 0.0), "the closed box")
	container.interact(player)
	_expect(container.is_open, "the box opens with a plain interaction (no levers, no key, no reading)")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"junction_switch_box_open", false)), "the open box is remembered")
	await _wait(1.2)
	_expect(vhs.is_inside_tree() and ficha.is_inside_tree(), "the tape and the token are in the open box")
	_expect(vhs.global_position.y > ficha.global_position.y + 0.01, "the tape lies over the token")
	_expect(container.get_node("Model/LidPivot").rotation_degrees.x < -90.0, "the lid is open")

	# The tape's label faces up; the token lies flat under it.
	_expect(vhs.get_node("Visual").global_basis.z.dot(Vector3.UP) > 0.95, "the tape lies label up")
	_expect(not ficha.can_interact(player), "the token offers nothing while the tape lies on it")

	var stand: Vector3 = _stand_for(Vector3(-3.78, 0.0, 0.0))
	await _ray_finds(vhs, stand, vhs.global_position, "the tape in the open box")
	await _ray_finds(vhs, stand, ficha.global_position + Vector3(0.0, 0.015, 0.0), "the tape (not the token) where the token lies under it")
	var notebook: Inspectable = shed.get_node("%SophiaJournal")
	await _ray_finds(notebook, _stand_for(Vector3(-4.7, 0.0, 0.0)), notebook.global_position + Vector3(-0.07, 0.01, 0.0), "the notebook")
	var clipping: Inspectable = shed.get_node("%NewspaperClipping")
	await _ray_finds(clipping, _stand_for(Vector3(-4.43, 0.0, 0.0)), clipping.global_position + Vector3(0.0, 0.012, 0.0), "the clipping, over the notebook")
	await _ray_finds(shed.camcorder, shed.to_global(Vector3(-4.3, 0.0, -0.8)), shed.camcorder.global_position + Vector3(0.0, 1.33, 0.0), "the camcorder, from 2 m away")


func _check_scene_plays_once() -> void:
	player.flashlight_controller.flashlight_on = true
	player.global_position = Vector3(_stand_for(Vector3(-3.9, 0.0, 0.0)).x, 1.1, _stand_for(Vector3.ZERO).z)
	player.movement_controller.look_yaw = 0.0
	await _wait(0.8)
	var start_position: Vector3 = player.global_position
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
	while shed.is_recording_running() and waited < 160.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_stop_watch()
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(not shed.is_recording_running() and shed.is_recording_done(), "the scene ends by itself")
	_expect(waited > 60.0 and waited < 90.0, "it lasts about seventy seconds (%.0f s)" % waited)
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
	_expect(int(_seen.get("caption_in_recording", 0)) == 0 and int(_seen.get("caption_in_photo", 0)) == 0, "no caption while the silent footage plays, nor over the photograph (%d, %d frames)" % [int(_seen.get("caption_in_recording", 0)), int(_seen.get("caption_in_photo", 0))])
	_expect(int(_seen.get("source_sounds", 0)) == 0, "no sound at all while the recording's picture is up (%d frames)" % int(_seen.get("source_sounds", 0)))
	_expect(shed.get_node_or_null("RecordedVoices") == null and shed.get_node_or_null("ArchiveTexture") == null and shed.get_node_or_null("ArchiveMotif") == null and shed.get_node_or_null("RewindFoley") == null, "the old recorded-voice, texture, motif and rewind players are gone: nothing is replayed")
	_expect(float(_seen.get("max_footage_time", 0.0)) >= shed.footage.length_seconds - 0.2, "the footage ran to its end, once (%.1f s)" % float(_seen.get("max_footage_time", 0.0)))
	_expect(int(_seen.get("footage_restarts", 0)) == 0, "and never went back (%d restarts)" % int(_seen.get("footage_restarts", 0)))
	_expect(float(_seen.get("recording_camera_move", 1.0)) < 0.0001 and float(_seen.get("recording_fov_change", 1.0)) < 0.01, "the recording's camera is fixed: it did not move or zoom (%.5f m, %.3f degrees)" % [float(_seen.get("recording_camera_move", 1.0)), float(_seen.get("recording_fov_change", 1.0))])
	_expect(bool(_seen.get("recording_at_marker", false)), "and it stood where the marker puts it, with the lens matched to the picture")
	_expect(int(_seen.get("photo_frames", 0)) > 25 and int(_seen.get("photo_present_frames", 0)) == int(_seen.get("photo_frames", 0)), "the photograph's close view was held, with the present's dressing whole and nobody in it (%d frames)" % int(_seen.get("photo_frames", 0)))
	_expect(float(_seen.get("talk_camera_move", 1.0)) < 0.0001 and int(_seen.get("talk_frames", 0)) > 80, "the conversation is one still shot (%.5f m over %d frames)" % [float(_seen.get("talk_camera_move", 1.0)), int(_seen.get("talk_frames", 0))])
	_expect(int(_seen.get("black_frames", 0)) == 0, "no black or dissolve frame between the recording, the photograph and the conversation (%d frames of a black picture)" % int(_seen.get("black_frames", 0)))
	_expect(bool(_seen.get("led_on", false)) and int(_seen.get("led_on_in_cinema", 0)) == 0, "the red light came on, in her own view")
	_expect(float(_seen.get("head_turn", 0.0)) >= 2.95 and float(_seen.get("head_turn", 0.0)) <= 8.5, "the camcorder's head turned a small amount (%.1f degrees)" % float(_seen.get("head_turn", 0.0)))
	_expect(float(_seen.get("min_fov", 75.0)) < 70.0, "the lens narrowed a little (%.0f)" % float(_seen.get("min_fov", 75.0)))
	_expect(bool(_seen.get("flash_on_in_shot5", false)), "her flashlight was on for the camcorder")
	_expect(bool(_seen.get("flash_off_in_memory", false)), "and out for the memory")
	_expect(float(_seen.get("flash_energy_min", 15.0)) >= 14.9, "the flashlight was never weakened")
	_expect(bool(_seen.get("mark_shown", false)), "the token's mark was shown at the end")
	_expect(not bool(_seen.get("saw_marina", false)) and not bool(_seen.get("saw_recorded", false)), "no subtitle ever spoke for Marina or a recorded voice")
	_expect(bool(_seen.get("saw_last", false)), "the subtitles reached the last line, 'They offered me a better copy.'")
	_expect(str(_seen.get("order_ok", "")) == "yes", "the subtitles came in order and none was left behind across a cut (%s)" % str(_seen.get("order_ok", "")))
	var final_head: Node3D = shed.camcorder.find_child("Head", true, false)
	_expect(absf(final_head.rotation_degrees.y - shed.camcorder_start_yaw_degrees) >= 2.95, "the camcorder stays turned toward her")
	var led: MeshInstance3D = shed.camcorder.find_child("Led", true, false)
	_expect((led.material_override as StandardMaterial3D).emission_energy_multiplier == 0.0 and shed.camcorder.visible, "its light is out and it is still there")
	_expect(bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)), "completion is saved")
	_expect(not bool(SaveManager.get_state_value(&"collectibles", &"sophia_ficha", false)), "the token is not collected by the scene")
	_expect(not player.has_inventory_item("sophia_ficha"), "and not in the inventory")
	_expect(not shed.footage.visible and is_zero_approx(shed.footage.current_time) and not shed.archive_foreground.visible, "the cast and the ferns are put away, the cast at its first frame")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT, "and the shelter is in its present look")


func _check_after_scene() -> void:
	# The tape lies beside the open box; the token is there to take.
	_expect(vhs.get_parent() == shed.effects_root, "the tape stays on the bench")
	var tape: AABB = _tape_bounds_world_from(vhs.get_parent(), vhs.transform)
	var inner: AABB = _box_inner_world()
	_expect(not _overlap_plan(tape, _visual_bounds(container)), "the tape lies beside the box, not over it")
	_expect(ficha.is_inside_tree() and ficha.pickup_enabled and ficha.can_interact(player), "the token is free to take")
	_expect(ficha.global_position.x > inner.position.x and ficha.global_position.x < inner.end.x and ficha.global_position.z > inner.position.z and ficha.global_position.z < inner.end.z, "the token lies inside the open box")
	_expect(ficha.global_position.y > inner.position.y - 0.02, "on its floor")
	await _ray_finds(ficha, _stand_for(Vector3(-3.78, 0.0, 0.0)), ficha.global_position, "the token inside the open box")
	await _ray_finds(vhs, _stand_for(Vector3(-4.1, 0.0, 0.0)), vhs.global_position, "the tape beside it")

	# A later examination is only an examination.
	await _read_and_close_tape()
	await _wait(0.5)
	_expect(not shed.is_recording_running() and not player.view_locked, "examining the tape again does not replay the scene")
	_expect(completed_count == 1, "(nothing announced again)")

	# The token is taken with the ordinary pickup.
	ficha.interact(player)
	_expect(player.has_inventory_item("sophia_ficha"), "the token goes in the inventory with the ordinary pickup")
	_expect(bool(SaveManager.get_state_value(&"collectibles", &"sophia_ficha", false)), "and is remembered as collected")
	await _wait(0.6)
	player.inspect_controller.close(false)
	player.inventory_ui_controller.close()
	await _wait(0.8)
	_expect(not player.view_locked and not shed.is_recording_running(), "taking the token does not start anything")


func _check_saves() -> void:
	# Collected: the box is open, the tape beside it, no second token, no replay.
	await _fresh_level(false)
	_expect(shed.is_recording_done() and container.is_open, "reloaded after the token was taken: the scene is over and the box open")
	_expect(shed.vhs.get_parent() == shed.effects_root, "the tape is beside the box")
	await _wait(0.3)
	_expect(not is_instance_valid(shed.ficha) or not shed.ficha.is_inside_tree() or shed.ficha.is_queued_for_deletion(), "the token does not come back once it is collected")
	await _free_level()

	# Done, token left: it is there, free, and nothing replays.
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	SaveManager.set_state_value(&"puzzles", &"shelter_recording_done", true)
	SaveManager.set_state_value(&"puzzles", &"junction_switch_box_open", true)
	await _load_level()
	_expect(shed.is_recording_done() and container.is_open and shed.ficha.is_inside_tree() and shed.ficha.pickup_enabled, "scene done, token left: the open box shows the token, free")
	_expect(shed.vhs.get_parent() == shed.effects_root, "the tape is beside the box after a load")
	await _read_and_close_tape()
	await _wait(0.4)
	_expect(not shed.is_recording_running(), "and the tape does not replay the scene")
	await _free_level()

	# Old saves. A solved lever box with its token left behind.
	await _legacy_case("a solved lever box", [[&"puzzles", &"junction_signal_box_open", true]], true, true)
	# The token taken the old way.
	await _legacy_case("a token taken from the lever box", [[&"puzzles", &"junction_ficha_taken", true], [&"collectibles", &"sophia_ficha", true]], true, false)
	# The token already in the payphone.
	await _legacy_case("a token already in the payphone", [[&"puzzles", &"orelhao_fichas", ["sophia_ficha"]], [&"collectibles", &"sophia_ficha", true]], true, false)
	# The old switch box opened (with the puncher) and nothing more: the scene is still to come.
	await _legacy_case("only the old switch box opened", [[&"puzzles", &"junction_switch_box_open", true], [&"puzzles", &"junction_signal_box_levers", [true, true, false]]], false, true)


## A saved state prepared, the shed loaded: whether the recording counts as over, and whether the token is there.
func _legacy_case(label: String, values: Array, expect_done: bool, expect_token: bool) -> void:
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	for entry: Array in values:
		SaveManager.set_state_value(entry[0], entry[1], entry[2])
	await _load_level()
	await _wait(0.3)
	_expect(shed.is_recording_done() == expect_done, "%s: the scene is %s" % [label, "over" if expect_done else "still to come"])
	var token_in_tree: bool = is_instance_valid(shed.ficha) and shed.ficha.is_inside_tree() and not shed.ficha.is_queued_for_deletion()
	_expect(token_in_tree == expect_token, "%s: the token is %s" % [label, "there" if expect_token else "not there (never twice)"])
	if expect_done:
		_expect(container.is_open and shed.vhs.get_parent() == shed.effects_root, "%s: the box is open with the tape beside it" % label)
		if expect_token:
			_expect(shed.ficha.pickup_enabled, "%s: the token is free to take" % label)
		await _read_and_close_tape()
		await _wait(0.4)
		_expect(not shed.is_recording_running(), "%s: no scene is forced" % label)
	else:
		_expect(container.is_open and shed.vhs.is_inside_tree() and not shed.ficha.pickup_enabled, "%s: the open box shows the tape on a token that cannot be taken yet" % label)
	await _free_level()


func _check_cancel() -> void:
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, TEST_SCENE_PATH, "shed_test_start", "SAVE_LOCATION_DREAM_INTRO")
	await _load_level()
	container.interact(player)
	await _wait(1.0)
	player.flashlight_controller.flashlight_on = true
	await _read_and_close_tape()
	# In the footage while the visitor walks (the footage begins about 10 s in).
	await _wait(10.0 + 4.8)
	_expect(shed.is_recording_running() and not shed.effects_root.visible and shed.footage.visible and shed.archive_foreground.visible, "(in the recording: the cast and the ferns on screen)")
	_expect(shed.footage.current_time > 3.0 and shed.footage.current_time < shed.footage.arrive_time, "(the visitor is walking in: %.1f s)" % shed.footage.current_time)
	shed.cancel_recording()
	await _wait(0.3)
	_expect(not shed.is_recording_running() and not shed.is_recording_done(), "cutting the scene short leaves it to be played")
	_expect(not player.view_locked and not player.manual_save_blocked and get_viewport().get_camera_3d() == player.movement_controller.camera, "the player has their view, saving and camera back")
	_expect(player.flashlight_controller.flashlight_on and is_zero_approx(player.movement_controller.scripted_fov), "the flashlight and the lens are as they were")
	_expect(shed.effects_root.visible and shed.camcorder.visible and not shed.archive_dressing.visible, "the present is whole")
	_expect(not shed.footage.visible and is_zero_approx(shed.footage.current_time) and not shed.archive_foreground.visible and not shed.archive_dressing.visible, "the cast and the ferns are put away, the cast at its first frame, the old plank hidden")
	_expect(shed.get_world_state() == WaitingShedSequence.WorldState.PRESENT and shed.footage.visitor.global_position.is_equal_approx(shed.footage.visitor_transform_at(0.0).origin), "and the shelter is in its present look, the visitor back at the entry")
	_expect(shed.vhs.get_parent() == container.get_node("Contents") and not shed.ficha.pickup_enabled and not bool(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)), "the tape lies on the token again and the token is still held")
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
	await _load_level()
	container.interact(player)
	await _wait(1.0)
	await _read_and_close_tape()
	# While the visitor walks (the footage begins about 10 s in): the picture stands still, the cast with it, and the visitor does not keep walking.
	await _wait(10.0 + 4.6)
	var cinema: Camera3D = shed.get_node_or_null("CinemaCamera")
	_expect(shed.is_recording_running() and cinema != null and shed.footage.visible, "(in the footage, the visitor walking)")
	var time_before: float = shed.footage.current_time
	var root_before: Vector3 = shed.footage.visitor.global_position
	var foot_before: Vector3 = shed.footage.visitor.to_global(shed.footage.visitor.bone_point("LeftFoot"))
	get_tree().paused = true
	await get_tree().create_timer(1.5, true, false, true).timeout
	_expect(is_equal_approx(shed.footage.current_time, time_before) and shed.footage.visitor.global_position.is_equal_approx(root_before) and shed.footage.visitor.to_global(shed.footage.visitor.bone_point("LeftFoot")).is_equal_approx(foot_before), "paused while walking: the clock, the root and the feet stand still (nobody walks in place)")
	get_tree().paused = false
	await _wait(0.5)
	_expect(shed.footage.current_time > time_before + 0.3 and shed.footage.visitor.global_position.distance_to(root_before) > 0.1 or shed.footage.current_time > shed.footage.arrive_time, "resumed: the footage goes on from where it was (%.2f -> %.2f)" % [time_before, shed.footage.current_time])

	# Through the exchange, the exit and the photograph's close view.
	var guard: float = 0.0
	while shed.footage.visible and guard < 60.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	await _wait(1.0)
	cinema = shed.get_node_or_null("CinemaCamera")
	_expect(shed.is_recording_running() and cinema != null and not shed.footage.visible and shed.effects_root.visible and not shed.archive_foreground.visible, "(the photograph's view: the present whole, nobody in it)")
	var photo_before: Transform3D = cinema.global_transform
	get_tree().paused = true
	await get_tree().create_timer(1.5, true, false, true).timeout
	_expect(cinema.global_transform.is_equal_approx(photo_before) and not CaptionManager.panel.visible, "paused over the photograph: the view stands still, no words")
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
# THE FOOTAGE (the two archival actors, their walk, the fixed camera, the ferns): numbers, not acting. Whether it reads is for the eye.
# ============================================================

func _check_footage() -> void:
	# Built long before, out of sight.
	var footage: ShelterFootage = shed.footage
	for i: int in 5:
		await get_tree().process_frame
	_expect(footage != null and footage.is_prepared(), "the cast is built before the scene is watched")
	_expect(not footage.visible, "and hidden in the present")
	var marina: ArchiveActor = footage.marina
	var visitor: ArchiveActor = footage.visitor
	var floor_y: float = footage.path_stop.global_position.y
	var seat_y: float = footage.marina_seat.global_position.y

	# The rig: the project's rigged basic model, a local copy, one pose owner, no bag, nobody else.
	_expect(marina.skeleton != null and visitor.skeleton != null and marina.skeleton != visitor.skeleton, "each actor has a skeleton of their own")
	_expect(marina.skeleton.get_bone_count() == 25 and visitor.skeleton.get_bone_count() == 25, "of the model's 25 bones")
	_expect(footage.find_children("*", "ArchiveActor", false, false).size() == 2, "there are two actors in the footage and no third")
	_expect(footage.get_node_or_null("ArchiveBag") == null and footage.get("bag") == null, "and no bag: nothing is carried or handed over")
	for actor: ArchiveActor in [marina, visitor]:
		_expect(actor.find_children("*", "Skeleton3D", true, false).size() == 1, "%s has exactly one skeleton" % actor.name)
		_expect(actor.find_children("*", "AnimationPlayer", true, false).is_empty() and actor.find_children("*", "AnimationTree", true, false).is_empty(), "%s has no AnimationPlayer or AnimationTree writing to it: the one pose owner is sample()" % actor.name)
		_expect(actor.find_children("*", "CollisionObject3D", true, false).is_empty() and actor.find_children("*", "Camera3D", true, false).is_empty(), "%s has no collision, no interaction and no camera: archive picture only" % actor.name)
		_expect(actor.find_children("*", "Light3D", true, false).is_empty() and actor.find_children("*", "Interactable", true, false).is_empty(), "%s casts no light and is not interactable" % actor.name)
		var mouth: bool = false
		for bone: int in actor.skeleton.get_bone_count():
			var lowered: String = actor.skeleton.get_bone_name(bone).to_lower()
			mouth = mouth or lowered.contains("jaw") or lowered.contains("mouth") or lowered.contains("lip") or lowered.contains("teeth")
		_expect(not mouth and (actor.body.mesh as ArrayMesh).get_blend_shape_count() == 0, "%s has no jaw bone or face blend shape: no speech is animated or claimed" % actor.name)
	var shared_scene: Node = (load(ArchiveActor.MODEL) as PackedScene).instantiate()
	var shared_body: MeshInstance3D = shared_scene.get_node("Skeleton3D/Body") as MeshInstance3D
	_expect(shared_body.mesh != marina.body.mesh and shared_body.mesh != visitor.body.mesh and marina.body.mesh != visitor.body.mesh, "each actor's body mesh is a painted copy of its own")
	_expect((shared_body.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] == null, "the shared model's mesh is untouched (no vertex colours were written to it)")
	var rest_untouched: bool = true
	for bone: int in shared_scene.get_node("Skeleton3D").get_bone_count():
		rest_untouched = rest_untouched and (shared_scene.get_node("Skeleton3D") as Skeleton3D).get_bone_pose_rotation(bone).is_equal_approx(Quaternion.IDENTITY)
	_expect(rest_untouched, "and a fresh instance of it is still in its own rest pose")
	shared_scene.free()
	_expect(not marina.palette[&"top"].is_equal_approx(visitor.palette[&"top"]) and not is_equal_approx(marina.actor_scale, visitor.actor_scale), "the two are dressed differently and are two different heights")

	# The timing: about 22 s, the visitor at an ordinary pace with short ramps, in the right order.
	_expect(footage.length_seconds >= 20.0 and footage.length_seconds <= 24.0, "the excerpt is about 22 s (%.1f)" % footage.length_seconds)
	_expect(footage.walk_speed >= 1.0 and footage.walk_speed <= 1.3, "the visitor walks at an ordinary pace (%.2f m/s)" % footage.walk_speed)
	_expect(footage.accel_seconds <= 0.6 and footage.decel_seconds <= 0.7, "with short ramps, not a multi-second float (%.1f s, %.1f s)" % [footage.accel_seconds, footage.decel_seconds])
	_expect(footage.visitor_start_seconds < footage.arrive_time and footage.arrive_time < footage.depart_time and footage.depart_time < footage.walk_out_time and footage.walk_out_time < footage.length_seconds, "they walk in, stop, speak, turn and walk out, in that order")
	_expect(footage.arrive_time >= 4.5 and footage.arrive_time <= 7.5 and footage.depart_time >= 12.0 and footage.depart_time <= 15.0, "they stop about 5.5 s in and turn away about 13.5 s in (%.1f, %.1f)" % [footage.arrive_time, footage.depart_time])

	# Marina sits ON the bench: pelvis on the seat, thighs on it, feet on the floor, hands on her thighs, the legs not mirrored.
	footage.seek(0.0)
	var marina_vertices: PackedVector3Array = marina.skinned_vertices()
	var pelvis: PackedInt32Array = marina.vertices_of(["Hips"])
	var thighs: PackedInt32Array = marina.vertices_of(["*UpLeg"])
	var feet: PackedInt32Array = marina.vertices_of(["*Foot", "*ToeBase"])
	var pelvis_low: float = 1.0e9
	var thigh_low: float = 1.0e9
	var feet_low: float = 1.0e9
	var lowest: float = 1.0e9
	var bench: Node3D = shed.get_node("%Bench")
	var seat_front: float = bench.global_position.z + 0.23
	for v: Vector3 in marina_vertices:
		lowest = minf(lowest, marina.to_global(v).y)
	for index: int in pelvis:
		pelvis_low = minf(pelvis_low, marina.to_global(marina_vertices[index]).y)
	for index: int in thighs:
		var world: Vector3 = marina.to_global(marina_vertices[index])
		if world.z < seat_front - 0.04:
			thigh_low = minf(thigh_low, world.y)
	for index: int in feet:
		feet_low = minf(feet_low, marina.to_global(marina_vertices[index]).y)
	_expect(absf(pelvis_low - seat_y) < 0.015, "Marina's pelvis rests on the seat (%.3f m off)" % (pelvis_low - seat_y))
	_expect(thigh_low > seat_y - 0.025, "and her thighs are on it, not through it (%.3f m)" % (thigh_low - seat_y))
	_expect(absf(feet_low - floor_y) < 0.015 and lowest > floor_y - 0.02, "her feet are on the floor and nothing of her is under it (%.3f, %.3f m)" % [feet_low - floor_y, lowest - floor_y])
	var seat_origin: Vector3 = footage.marina_seat.global_position
	_expect(marina.global_position.x > bench.global_position.x - 0.85 and marina.global_position.x < bench.global_position.x - 0.1 and absf(marina.global_position.z - bench.global_position.z) < 0.2, "she sits on the bench's left half, over the seat")
	_expect(seat_origin.distance_to(Vector3(seat_origin.x, seat_y, seat_origin.z)) < 0.001 and marina.global_basis.z.dot(Vector3.BACK) > 0.95, "facing the open front")
	var foot_gap: float = absf(marina.bone_point("LeftFoot").z - marina.bone_point("RightFoot").z)
	var angles: Array[float] = []
	for side: String in ["Left", "Right"]:
		var hip: Vector3 = marina.bone_point(side + "UpLeg")
		var knee: Vector3 = marina.bone_point(side + "Leg")
		angles.append(rad_to_deg((hip - knee).angle_to(marina.bone_point(side + "Foot") - knee)))
	_expect(foot_gap > 0.05 and absf(angles[0] - angles[1]) > 8.0 and minf(angles[0], angles[1]) > 60.0, "her legs are not mirrored (feet %.2f m apart, knees %.0f and %.0f degrees)" % [foot_gap, angles[0], angles[1]])
	for side: String in ["Left", "Right"]:
		var hand_vertices: PackedInt32Array = marina.vertices_of([side + "Hand"])
		var thigh_vertices: PackedInt32Array = marina.vertices_of([side + "UpLeg"])
		var nearest: float = 1.0e9
		for h: int in hand_vertices:
			for t: int in thigh_vertices:
				nearest = minf(nearest, marina_vertices[h].distance_to(marina_vertices[t]))
		_expect(nearest < 0.035, "her %s hand rests on her thigh (%.3f m)" % [side.to_lower(), nearest])

	# The picture: one fixed camera. The matte is 4:3; the lens is matched to it at any window size.
	var marker: ShotMarker = shed.shot_recording
	var camera_xf: Transform3D = marker.aimed_transform()
	var fov: float = marker.fov
	var top_ray: float = rad_to_deg(asin(-camera_xf.basis.z.y)) + fov * 0.5
	_expect(shed.shot_recording != null and shed.get("shot_recording_reframe") == null and shed.get("shot_talk_to") == null, "the recording has one camera marker, no reframe")
	_expect(top_ray > 0.5 and top_ray < 4.5, "its top edge looks very slightly above the horizon (%.1f degrees): under the chins of the standing, above a seated head" % top_ray)
	_expect(absf(camera_xf.origin.x - shed.camcorder.global_position.x) < 0.3 and absf(camera_xf.origin.z - shed.camcorder.global_position.z) < 0.3 and absf(camera_xf.origin.y - (shed.camcorder.global_position.y + 1.33)) < 0.25, "from the camcorder's place: the reveal keeps its association")
	for size: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(2560, 1440), Vector2(1024, 768), Vector2(1280, 1024), Vector2(800, 800), Vector2(1600, 900), Vector2(1280, 800)]:
		var matched: float = ArchiveVideoOverlay.matched_fov(fov, size)
		var picture_height: float = minf(size.y, size.x / ArchiveVideoOverlay.ASPECT)
		# The matte's top edge as a ray: the camera's own vertical half-angle scaled by the matte's share of the height.
		var matte_top: float = rad_to_deg(atan(tan(deg_to_rad(matched) * 0.5) * picture_height / size.y))
		_expect(absf(matte_top - fov * 0.5) < 0.001 and matched >= fov - 0.001, "in a %dx%d window the matte shows the designed frame (lens %.1f, designed %.1f)" % [int(size.x), int(size.y), matched, fov])

	# The whole timeline, every 1/30 s: the visitor's head, their legs, the feet, the pelvis, Marina's face.
	var step: float = 1.0 / 30.0
	var head_group: PackedInt32Array = visitor.vertices_of(["Head"])
	var marina_head_group: PackedInt32Array = marina.vertices_of(["Head"])
	var worst_chin: float = -1.0e9
	var head_inside: int = 0
	var first_seen: float = -1.0
	var last_seen: float = -1.0
	var worst_reach: float = 0.0
	var worst_floor: float = 0.0
	var marina_face_worst: float = 1.0e9
	var marina_face_inside: bool = true
	var overlap_frames: int = 0
	var max_speed: float = 0.0
	var steady_low: float = 1.0e9
	var steady_high: float = 0.0
	var hips_lateral: float = 0.0
	var lowest_hips: float = 1.0e9
	var heading_error: float = 0.0
	var turning_error: float = 0.0
	var planted_slip: float = 0.0
	var previous_feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var planted_frames: Array[int] = [0, 0]
	var previous_root: Vector3 = Vector3.ZERO
	var time: float = 0.0
	var first: bool = true
	while time <= footage.length_seconds + 0.001:
		footage.seek(time)
		for actor: ArchiveActor in [marina, visitor]:
			for channel: StringName in [&"hand_l", &"hand_r", &"foot_l", &"foot_r"]:
				worst_reach = maxf(worst_reach, float(actor.reach_error[channel]))
		var visitor_vertices: PackedVector3Array = visitor.skinned_vertices()
		var any_inside: bool = false
		var visitor_min_x: float = 1.0e9
		for index: int in visitor_vertices.size():
			var world: Vector3 = visitor.to_global(visitor_vertices[index])
			worst_floor = minf(worst_floor, world.y - floor_y)
			var at: Vector2 = _picture_point(camera_xf, fov, world)
			if at.x > 0.0 and at.x < 1.0 and at.y > 0.0 and at.y < 1.0:
				any_inside = true
				visitor_min_x = minf(visitor_min_x, at.x)
		for index: int in head_group:
			var at_head: Vector2 = _picture_point(camera_xf, fov, visitor.to_global(visitor_vertices[index]))
			if at_head.x > -0.05 and at_head.x < 1.05:
				worst_chin = maxf(worst_chin, at_head.y)
			if at_head.x > 0.0 and at_head.x < 1.0 and at_head.y > 0.0 and at_head.y < 1.0:
				head_inside += 1
		if any_inside:
			if first_seen < 0.0:
				first_seen = time
			last_seen = time
		# Marina's face stays inside the picture, clear of its edges, all the way through.
		var mv: PackedVector3Array = marina.skinned_vertices()
		var face_left: float = 1.0e9
		var face_right: float = -1.0e9
		for index: int in marina_head_group:
			var at_face: Vector2 = _picture_point(camera_xf, fov, marina.to_global(mv[index]))
			marina_face_worst = minf(marina_face_worst, minf(minf(at_face.x, 1.0 - at_face.x), minf(at_face.y, 1.0 - at_face.y)))
			face_left = minf(face_left, at_face.x)
			face_right = maxf(face_right, at_face.x)
		# The visitor's body does not cover her face: while they are in the picture, the nearest part of them is to the right of her head.
		if any_inside and visitor_min_x < face_right + 0.012:
			overlap_frames += 1
		var root_now: Vector3 = visitor.global_position
		if not first:
			var speed: float = root_now.distance_to(previous_root) / step
			max_speed = maxf(max_speed, speed)
			if time > footage.visitor_start_seconds + footage.accel_seconds + 0.2 and time < footage.arrive_time - footage.decel_seconds - 0.2:
				steady_low = minf(steady_low, speed)
				steady_high = maxf(steady_high, speed)
			if speed > 0.6:
				var travelled: Vector3 = (root_now - previous_root).normalized()
				var facing: Vector3 = visitor.global_basis.z
				var off: float = rad_to_deg(absf(Vector2(facing.x, facing.z).angle_to(Vector2(travelled.x, travelled.z))))
				turning_error = maxf(turning_error, off)
				if speed > 1.1:
					heading_error = maxf(heading_error, off)
		previous_root = root_now
		var hips_channel: Vector3 = visitor.value_at(&"hips_at", time)
		hips_lateral = maxf(hips_lateral, absf(hips_channel.x))
		if time > footage.arrive_time + 1.0 and time < footage.depart_time:
			lowest_hips = minf(lowest_hips, visitor.bone_point("Hips").y)
		# A foot on the ground does not move: the ankle's world place over three frames on the ground.
		var feet_now: Array[Vector3] = [visitor.to_global(visitor.bone_point("LeftFoot")), visitor.to_global(visitor.bone_point("RightFoot"))]
		for f: int in 2:
			var on_ground: bool = footage.gait.foot_up[f][int(round(time / ArchiveGait.DT))] < 0.0005
			planted_frames[f] = planted_frames[f] + 1 if on_ground else 0
			if planted_frames[f] >= 3 and not first:
				planted_slip = maxf(planted_slip, feet_now[f].distance_to(previous_feet[f]))
		previous_feet = feet_now
		first = false
		time += step
	_expect(head_inside == 0 and worst_chin < -0.02, "the visitor's head never enters the picture: through the whole excerpt the lowest head vertex is %.3f of the picture's height above its top edge" % -worst_chin)
	_expect(first_seen >= 3.0 and first_seen <= 4.2, "nobody is in the picture for the first three seconds; the visitor appears at %.1f s" % first_seen)
	_expect(last_seen >= 14.5 and last_seen <= 17.5, "and has left it by %.1f s, with Marina alone for the rest" % last_seen)
	_expect(marina_face_worst > 0.03 and overlap_frames == 0, "Marina's face stays in the picture (%.2f of it from the nearest edge) and is never covered by the visitor (%d frames overlap)" % [marina_face_worst, overlap_frames])
	_expect(worst_reach < 0.01, "every hand and foot reaches where it is asked, all through the footage (worst %.4f m)" % worst_reach)
	_expect(worst_floor > -0.02, "the visitor is never under the floor (%.3f m)" % worst_floor)
	_expect(max_speed > footage.walk_speed - 0.05 and max_speed < footage.walk_speed + 0.1, "the root never goes faster than the walk speed (%.2f m/s)" % max_speed)
	_expect(steady_high - steady_low < 0.06, "most of the way in is at one steady speed (%.2f to %.2f m/s)" % [steady_low, steady_high])
	_expect(hips_lateral < 0.05, "the walk is in place on the skeleton (no root translation inside the rig: the pelvis channel stays within %.3f m of centre)" % hips_lateral)
	_expect(heading_error < 35.0 and turning_error < 65.0, "they face the way they travel, in and out (%.0f degrees off at speed, %.0f while turning to or from her)" % [heading_error, turning_error])
	_expect(planted_slip < 0.004, "a foot on the ground does not move: the worst ankle drift over a frame on the ground is %.4f m" % planted_slip)
	_expect(lowest_hips > 0.8 * visitor.actor_scale, "standing and speaking, the pelvis is back at an ordinary height (%.2f m)" % lowest_hips)

	# The planned feet: both feet step, at a cadence that matches the travel, and each foot is stationary while it is down.
	var gait: ArchiveGait = footage.gait
	_expect(gait.steps_taken[0] >= 6 and gait.steps_taken[1] >= 6, "both feet take real steps (%d and %d)" % [gait.steps_taken[0], gait.steps_taken[1]])
	var lifts: int = 0
	var window_start: int = int(round(2.0 / ArchiveGait.DT))
	var window_end: int = int(round(4.0 / ArchiveGait.DT))
	for f: int in 2:
		for i: int in range(window_start + 1, window_end):
			if gait.foot_up[f][i] > 0.0005 and gait.foot_up[f][i - 1] <= 0.0005:
				lifts += 1
	var cadence: float = float(lifts) / 2.0
	_expect(cadence >= 1.5 and cadence <= 3.0, "at steady walking they take %.1f steps a second, with a stride of %.2f m" % [cadence, footage.walk_speed / maxf(cadence, 0.1)])
	var drift: float = 0.0
	for f: int in 2:
		for i: int in range(1, gait.frame_count()):
			if gait.foot_up[f][i] == 0.0 and gait.foot_up[f][i - 1] == 0.0:
				drift = maxf(drift, gait.foot_xz[f][i].distance_to(gait.foot_xz[f][i - 1]))
	_expect(drift < 0.0001, "in the plan a foot on the ground stays exactly where it was put (%.5f m)" % drift)
	var settle_index: int = int(round((footage.arrive_time + 1.2) / ArchiveGait.DT))
	var apart: float = gait.foot_xz[0][settle_index].distance_to(gait.foot_xz[1][settle_index])
	_expect(gait.foot_up[0][settle_index] == 0.0 and gait.foot_up[1][settle_index] == 0.0 and apart < 0.4 * visitor.actor_scale, "when the root has stopped the feet settle beside each other, both down (%.2f m apart)" % apart)
	var after_stop: int = int(round((footage.arrive_time + 2.0) / ArchiveGait.DT))
	var after_stop_end: int = int(round((footage.depart_time - 0.3) / ArchiveGait.DT))
	var restless: float = 0.0
	for i: int in range(after_stop, after_stop_end):
		restless = maxf(restless, gait.foot_xz[0][i].distance_to(gait.foot_xz[0][after_stop]) + gait.foot_xz[1][i].distance_to(gait.foot_xz[1][after_stop]))
	_expect(restless < 0.001, "while they stand and speak neither foot keeps walking in place (%.4f m)" % restless)

	# Where each of them looks: attention leads the action. Marina waits (not at the stop mark), then looks at the visitor while they speak.
	footage.seek(1.0)
	var stop_head: Vector3 = footage.path_stop.global_position + Vector3(0.0, 1.5 * visitor.actor_scale, 0.0)
	var waiting_gaze: float = _gaze_angle(marina, "Head", stop_head)
	footage.seek(footage.arrive_time + 1.5)
	var speaking_gaze: float = _gaze_angle(marina, "Head", visitor.to_global(visitor.bone_point("Head")))
	_expect(speaking_gaze < 45.0 and waiting_gaze > speaking_gaze + 15.0, "Marina waits looking aside (%.0f degrees from where they will stand) and then looks at the visitor (%.0f degrees off)" % [waiting_gaze, speaking_gaze])
	footage.seek(footage.length_seconds - 0.5)
	var settled_gaze: float = _gaze_angle(marina, "Head", stop_head)
	_expect(settled_gaze > speaking_gaze + 15.0, "after they have gone she is waiting again (%.0f degrees from where they stood)" % settled_gaze)

	# The footage is a pure function of the time: any order, any number of times, the same picture. No other animation can run on it.
	var probe_times: Array[float] = [0.5, 4.2, 5.6, 9.0, 13.5, 14.4, 15.3, 18.0, 21.9]
	var reference: Dictionary = {}
	for t: float in probe_times:
		footage.seek(0.0)
		footage.seek(t)
		reference[t] = _footage_snapshot(footage)
	var identical: bool = true
	var bad_time: float = -1.0
	for round_index: int in 3:
		var shuffled: Array[float] = probe_times.duplicate()
		shuffled.shuffle()
		for t: float in shuffled:
			footage.seek(t + 5.7)
			footage.seek(t)
			if not _snapshots_equal(reference[t] as Dictionary, _footage_snapshot(footage)):
				identical = false
				bad_time = t
	_expect(identical, "seeking in any order gives exactly the same poses and places at the same time (bad at %.1f)" % bad_time)
	footage.seek(0.0)

	# The foreground: a few ferns of the forest's own, still, framing the left and lower edges and leaving a clear window onto the bench.
	var foreground: Node3D = shed.archive_foreground
	_expect(foreground != null and not foreground.visible and foreground.get_child_count() >= 2 and foreground.get_child_count() <= 5, "a few ferns stand near the lens, hidden in the present")
	_expect(foreground.find_children("*", "CollisionObject3D", true, false).is_empty() and foreground.find_children("*", "AnimationPlayer", true, false).is_empty() and foreground.find_children("*", "Light3D", true, false).is_empty(), "plain meshes: no collision, no wind animation, no light")
	var in_picture: int = 0
	var window_hits: PackedStringArray = PackedStringArray()
	for fern: Node in foreground.get_children():
		var instance: MeshInstance3D = fern as MeshInstance3D
		var box: AABB = instance.get_aabb()
		var low: Vector2 = Vector2(1.0e9, 1.0e9)
		var high: Vector2 = Vector2(-1.0e9, -1.0e9)
		var visible_corners: int = 0
		for corner: int in 8:
			var local: Vector3 = box.position + Vector3(box.size.x * (corner & 1), box.size.y * ((corner >> 1) & 1), box.size.z * ((corner >> 2) & 1))
			var at_corner: Vector2 = _picture_point(camera_xf, fov, instance.global_transform * local)
			low = low.min(at_corner)
			high = high.max(at_corner)
		# The part of the fern that is in the picture, against the clear window (the right of the left strip, above the bottom strip).
		var shown_low: Vector2 = low.max(Vector2.ZERO)
		var shown_high: Vector2 = high.min(Vector2.ONE)
		if shown_low.x < shown_high.x and shown_low.y < shown_high.y:
			in_picture += 1
			var window: Rect2 = Rect2(Vector2(0.38, 0.0), Vector2(0.58, 0.52))
			if Rect2(shown_low, shown_high - shown_low).intersects(window):
				window_hits.append("%s (%.2f-%.2f, %.2f-%.2f)" % [fern.name, shown_low.x, shown_high.x, shown_low.y, shown_high.y])
	_expect(in_picture >= 2, "at least two ferns are in the picture (%d)" % in_picture)
	_expect(window_hits.is_empty(), "and none of them is over the window onto the bench and the way the visitor walks (%s)" % ", ".join(window_hits))


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
	_expect(shed.find_child("AftermathBlood", true, false) == null, "and there is no blood node in the shed at all (the capture tool alone dresses it)")
	var blood_named: Array[Node] = shed.find_children("*lood*", "", true, false)
	_expect(blood_named.is_empty(), "nothing in the shed is called blood")
	# The recording.
	shed.set_world_state(WaitingShedSequence.WorldState.RECORDING)
	_expect(not shed.effects_root.visible and not shed.camcorder.visible and not shed.replaced_plank.visible and dressing.visible and intact.visible and not damaged.visible and foreground.visible and footage.visible, "recording: no belongings, the old plank whole, the ferns and the two people shown; no damaged plank")
	# The aftermath (capture only).
	shed.set_world_state(WaitingShedSequence.WorldState.PHOTO_CAPTURE)
	_expect(not shed.effects_root.visible and not shed.camcorder.visible and not shed.replaced_plank.visible and dressing.visible and damaged.visible and not intact.visible and not foreground.visible and not footage.visible, "aftermath: the plank broken, no belongings, no camcorder, no ferns, nobody")
	shed.set_world_state(WaitingShedSequence.WorldState.PRESENT)
	_expect(shed.effects_root.visible and shed.camcorder.visible and shed.replaced_plank.visible and not dressing.visible and not footage.visible and not foreground.visible, "and back to the present, whole")
	_expect(is_zero_approx(footage.current_time) and footage.visitor.global_position.is_equal_approx(footage.visitor_transform_at(0.0).origin), "with the cast put back at its first frame")
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


## The angle (degrees) between where a bone of the actor faces and the direction to a world point.
func _gaze_angle(actor: ArchiveActor, bone_name: String, world_point: Vector3) -> float:
	var origin: Vector3 = actor.to_global(actor.bone_point(bone_name))
	var facing: Vector3 = (actor.global_basis * actor.bone_forward(bone_name)).normalized()
	return rad_to_deg(facing.angle_to((world_point - origin).normalized()))


## The picture is 4:3, the camera's vertical lens `fov` (degrees): where a world point falls in it, from 0 to 1 across and down (outside means not in the picture).
func _picture_point(camera_xf: Transform3D, fov: float, world: Vector3) -> Vector2:
	var local: Vector3 = camera_xf.affine_inverse() * world
	if local.z > -0.05:
		return Vector2(-9.0, -9.0)
	var reach: float = tan(deg_to_rad(fov) * 0.5)
	var tx: float = local.x / -local.z / (reach * 4.0 / 3.0)
	var ty: float = local.y / -local.z / reach
	return Vector2(0.5 + tx * 0.5, 0.5 - ty * 0.5)


## Everything the picture is made of at the time the cast was last posed: every bone of both actors, and where the visitor stands.
func _footage_snapshot(footage: ShelterFootage) -> Dictionary:
	var poses: Array[Quaternion] = []
	for actor: ArchiveActor in [footage.marina, footage.visitor]:
		for bone: int in actor.skeleton.get_bone_count():
			poses.append(actor.skeleton.get_bone_pose_rotation(bone))
	return {"poses": poses, "visitor": footage.visitor.global_transform, "hips": [footage.marina.skeleton.get_bone_pose_position(0), footage.visitor.skeleton.get_bone_pose_position(0)]}


func _snapshots_equal(a: Dictionary, b: Dictionary) -> bool:
	var pa: Array = a["poses"]
	var pb: Array = b["poses"]
	if pa.size() != pb.size():
		return false
	for i: int in pa.size():
		if not (pa[i] as Quaternion).is_equal_approx(pb[i] as Quaternion):
			return false
	var ha: Array = a["hips"]
	var hb: Array = b["hips"]
	for i: int in ha.size():
		if not (ha[i] as Vector3).is_equal_approx(hb[i] as Vector3):
			return false
	return (a["visitor"] as Transform3D).is_equal_approx(b["visitor"] as Transform3D)


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
	var last_cinema_origin: Vector3 = Vector3.ZERO
	var shots_seen: int = 0
	var captions: Array[String] = []
	var expected: Array[String] = [
		"Sophia: This is the copy Marina's sister lent me.", "Juliana: There's no sound?", "Sophia: The copy came like this.",
		"Juliana: Does she know that person?", "Sophia: Her sister thinks so.", "Juliana: Did you recognize them?", "Sophia: No.",
		"Juliana: And who's filming?", "Sophia: That's what I asked.", "Juliana: And?", "Sophia: They offered me a better copy.",
	]
	_seen["flash_energy_min"] = 99.0
	_seen["min_fov"] = 75.0
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
		if shed.archive_foreground.visible:
			_seen["foreground_seen"] = true
			if not shed.footage.visible:
				_seen["foreground_outside"] = int(_seen.get("foreground_outside", 0)) + 1
		if playing:
			var footage_time: float = shed.footage.current_time
			if footage_time + 0.001 < float(_seen.get("max_footage_time", 0.0)):
				_seen["footage_restarts"] = int(_seen.get("footage_restarts", 0)) + 1
			_seen["max_footage_time"] = maxf(float(_seen.get("max_footage_time", 0.0)), footage_time)
			if CaptionManager.panel.visible:
				_seen["caption_in_recording"] = int(_seen.get("caption_in_recording", 0)) + 1
			# The recording's camera: fixed, at its marker, with the lens matched to the picture.
			var expected_fov: float = ArchiveVideoOverlay.matched_fov(shed.shot_recording.fov, get_viewport().get_visible_rect().size)
			if in_cinema:
				if not _seen.has("recording_origin"):
					_seen["recording_origin"] = current.global_position
					_seen["recording_basis"] = current.global_basis
					_seen["recording_fov"] = current.fov
					_seen["recording_at_marker"] = current.global_transform.is_equal_approx(shed.shot_recording.aimed_transform()) and absf(current.fov - expected_fov) < 0.01
				_seen["recording_camera_move"] = maxf(float(_seen.get("recording_camera_move", 0.0)), maxf(current.global_position.distance_to(_seen["recording_origin"] as Vector3), (current.global_basis.z - (_seen["recording_basis"] as Basis).z).length()))
				_seen["recording_fov_change"] = maxf(float(_seen.get("recording_fov_change", 0.0)), absf(current.fov - float(_seen["recording_fov"])))
		# The photograph's close view: the present's dressing whole, nobody in it, no words.
		if in_cinema and current.global_transform.origin.distance_to(shed.shot_photo.global_position) < 0.001:
			_seen["photo_frames"] = int(_seen.get("photo_frames", 0)) + 1
			if shed.effects_root.visible and shed.replaced_plank.visible and not shed.footage.visible and not shed.archive_foreground.visible and not shed.archive_dressing.visible and (overlay == null or not overlay.visible):
				_seen["photo_present_frames"] = int(_seen.get("photo_present_frames", 0)) + 1
			if CaptionManager.panel.visible:
				_seen["caption_in_photo"] = int(_seen.get("caption_in_photo", 0)) + 1
			_seen["photo_seen_at"] = float(Time.get_ticks_msec())
		# The still conversation shot.
		if in_cinema and current.global_transform.origin.distance_to(shed.shot_talk.global_position) < 0.001:
			_seen["talk_frames"] = int(_seen.get("talk_frames", 0)) + 1
			if not _seen.has("talk_origin"):
				_seen["talk_origin"] = current.global_position
			_seen["talk_camera_move"] = maxf(float(_seen.get("talk_camera_move", 0.0)), current.global_position.distance_to(_seen["talk_origin"] as Vector3))
		# No blank frame between the cuts: the overlay is never black when the camera is not in the recording or already left it.
		if overlay != null and overlay.visible:
			_seen["overlay_seen"] = true
			if not in_cinema:
				_seen["overlay_in_player_view"] = int(_seen.get("overlay_in_player_view", 0)) + 1
			if not overlay.is_picture_shown():
				_seen["black_frames"] = int(_seen.get("black_frames", 0)) + 1
		if overlay != null and overlay.visible and overlay.is_picture_shown():
			for child: Node in shed.get_children():
				if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
					_seen["source_sounds"] = int(_seen.get("source_sounds", 0)) + 1
		if led.emission_energy_multiplier > 0.0:
			_seen["led_on"] = true
			if in_cinema:
				_seen["led_on_in_cinema"] = int(_seen.get("led_on_in_cinema", 0)) + 1
		_seen["head_turn"] = maxf(float(_seen.get("head_turn", 0.0)), absf(head.rotation_degrees.y - start_yaw))
		_seen["min_fov"] = minf(float(_seen["min_fov"]), camera.fov)
		if not in_cinema and flash.visible:
			_seen["flash_on_in_shot5"] = true
			_seen["flash_energy_min"] = minf(float(_seen["flash_energy_min"]), flash.light_energy)
		if in_cinema and not flash.visible:
			_seen["flash_off_in_memory"] = true
		if not in_cinema and player.movement_controller.look_pitch != 0.0 and shed.ficha.mark_while_held:
			_seen["mark_shown"] = true
		# Subtitles, in order of appearance.
		if CaptionManager.panel.visible:
			var text: String = CaptionManager.label.text
			if captions.is_empty() or captions[captions.size() - 1] != text:
				captions.append(text)
				_seen["saw_marina"] = bool(_seen.get("saw_marina", false)) or text.begins_with("Marina:")
				_seen["saw_recorded"] = bool(_seen.get("saw_recorded", false)) or text.begins_with("Recorded voice:")
				_seen["saw_last"] = bool(_seen.get("saw_last", false)) or text == "Sophia: They offered me a better copy."
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


## The world box of the tape if its node had `local` transform inside `parent`.
func _tape_bounds_world_from(parent: Node, local: Transform3D) -> AABB:
	var parent_transform: Transform3D = (parent as Node3D).global_transform if parent.is_inside_tree() else container.global_transform * (parent as Node3D).transform
	return (parent_transform * local) * AABB(Vector3(-0.0935, -0.0515, -0.0125), Vector3(0.187, 0.103, 0.025))


func _tape_bounds_at(marker: Node3D) -> AABB:
	return marker.global_transform * AABB(Vector3(-0.0935, -0.0515, -0.0125), Vector3(0.187, 0.103, 0.025))


## The inside of the box's floor in the world.
func _box_inner_world() -> AABB:
	var inside: MeshInstance3D = container.get_node("Model/Inside") as MeshInstance3D
	return inside.global_transform * inside.mesh.get_aabb()


func _overlap_plan(a: AABB, b: AABB) -> bool:
	return a.position.x < b.end.x and a.end.x > b.position.x and a.position.z < b.end.z and a.end.z > b.position.z
