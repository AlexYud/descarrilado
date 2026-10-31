extends Node3D
class_name FigClearingSequence

## Orchestrates the fig tree clearing (script sequences 8 to 10): the album puzzle and the recorded memory, ONE directed sequence from the last
## photograph to the token.
##
## The reusable pieces (recorder, album, fire) only raise signals or do what they are told; every decision about what the clearing does lives
## here. Voice lines are captions until recorded audio exists (optional positional voice slots are ready), and the sounds are placeholders.
##
## Three photographs belong to the album, and nothing else stands in the way of it. Two are in the camp: Bus Stop Departure on the memory table
## beside the album (Table A, `Scenery/CampTable`: the album, the recorder and the lantern stay on it) and Rain at the Station in the J & S
## lockbox on the log table by the fire (Table B), which stands open (`JSLockbox.starts_open`, `CampDressing`). The third, Scraped Knee, lies on
## the desk at the HQ in the ruined signal tower. So the camp and the HQ can be visited in either order.
##
## The album is judged when every space is full: wrong, a short burst of static says it does not line up and the photographs stay to be
## moved; right, the sequence begins by itself (no second interaction) and the player holds still for all of it (`_hold_view`):
##   0. the last photograph registers (`last_photo_pause_seconds`), the album view is closed through its own path;
##   1. a cinematic camera low on the near side of Table A, framing the solved album, then one slow glide along the table to the recorder, whose
##      reels rewind, ending close on the recorder with the album and the lantern behind it (`album_shot`, `recorder_shot`);
##   2. the recorder plays the conversation (`CaptionTracks.FIG_RECORDING`, six cues, captions; an assigned clip on `recording_voice_player`
##      plays from the recorder), the camera pushing in very slowly, rain round it;
##   3. in its last seconds the lantern on Table A fails in a few dips; after "Good." the reels and rain stop and the lamp goes down gently until it
##      is out, all at once, `lights_out_after_good_seconds` (1.0) after her "Good.", the fire (this campfire only) and the camp's other lights with it.
##      No black screen and nothing added to the dark: the forest is as dark as it is;
##   4. the picture STAYS on the dark shot of the recorder and Sophia's last line is said once over it,
##      `line_after_dark_seconds` (1.0) after the lights are out (`CaptionTracks.FIG_EMPTY_SEAT`; an assigned clip on `seat_voice_player` plays from
##      where the figure sits), from behind her; `cut_before_torch_seconds` (0.2) before the flashlight comes on the picture cuts to Juliana's own camera
##      (hard cut, her place unchanged, her look on Table A);
##   5. the moment the line is over her flashlight comes on, very weak and flickering (`torch_level`, `_flicker_level`; its key stays locked), and she
##      turns frightened to the voice (`_turn_to_table_b`) to Table B: she searches, looks past it, then snaps back to it with a zoom;
##   6. a human shadow sits on its bench with its back to her (`SeatedFigure`, the basic model as a shadow), a token in its hand over the table, for
##      two seconds;
##   7. it flickers out and the token falls onto the table, with a clink (no light is added anywhere: the flashlight is the only one);
##   8. the token lies there two seconds, its mark visible from where she stands (`Interactable.mark_notice_distance`), then the player has the view,
##      the controls and the flashlight (on or off, as it was) back.
## Table B is cleared of its thermos and lockbox when it is first off camera (`FigClearingProps.clear_log_table`).
##
## Stages: EXPLORING (the cassette turns in silence, photos to find) > FINALE (the last photograph, the camera over Table A) > RECORDING (the tape)
## > EMPTY_SEAT (the black, the last line and what follows) > DONE. Saving is blocked from the last photograph to the token lying on the table.

signal sequence_completed

enum Stage {
	EXPLORING,
	FINALE,
	RECORDING,
	EMPTY_SEAT,
	DONE,
}

const STATE_SECTION: StringName = &"puzzles"
const KEY_WHY_SAID: StringName = &"fig_clearing_why_said"
const KEY_RECORDING_DONE: StringName = &"fig_clearing_recording_done"

const LINE_WHY_THIS_PLACE: String = "CAPTION_JULIANA_WHY_THIS_PLACE"

@export_category("Puzzle")
@export var album: PhotoAlbum
@export var recorder: CassetteRecorder
## The campfire; it goes cold at the blackout.
@export var fire: CampfireFire
## The camp's props: Table B and its bench, the lantern.
@export var dressing: FigClearingProps

@export_category("The token and the figure")
## Juliana's Ficha (a Collectible scene). It lies on Table B at `token_landing()` once the sequence is over.
@export var ficha_scene: PackedScene
## The figure is the rigged basic model (`SeatedFigure.MODEL`); this is its scale (1.0 is the 1.83 m model).
@export var figure_scale: float = 0.95
## How far the figure sits towards the table from the middle of the bench's plank (metres), so that its knees go under the tabletop and the reaching arm bends.
@export var figure_forward: float = 0.04
## Where the figure sits and where the token falls, on Table B (metres): how far along the table from its middle the figure sits, which side of
## it holds the token (true: its left, the north side, which Table A sees), how far to that side the token is, how far in from the table's near
## edge (towards the middle) and how high over the tabletop the hand holds it.
@export var figure_along: float = -0.3
@export var token_on_left: bool = true
@export var token_side_offset: float = 0.24
@export var token_in_from_edge: float = 0.06
@export var token_hand_height: float = 0.07
## The quiet voice slot of the last line: it plays from the figure's head (this marker is placed there when the line is said).
@export var empty_seat: Node3D

@export_category("Voices (an empty stream = captions only)")
## Plays the recorded conversation (cues 1 to 6 of `FIG_RECORDING`) from the recorder, in step with its captions.
@export var recording_voice_player: AudioStreamPlayer3D
## Plays Sophia's last line (`FIG_EMPTY_SEAT`) from the figure's place, with no recording treatment.
@export var seat_voice_player: AudioStreamPlayer3D

@export_category("Recording")
@export var rain_player: AudioStreamPlayer

@export_category("Camera over Table A")
## The cinematic camera's lens (one lens for the whole take) and how it stands: over the album and, at the recorder, `height` above the focus
## and `back` towards the player (the same side of the table all through). The recorder pose is where the glide ends; the push-in ends at the
## closer pose.
@export var camera_fov: float = 56.0
## The shots are placed on the line from the recorder to the album (`along`, towards the album) and across it on the side the album reads to the right
## of the recorder from (`across`), as (along, across, up) from the focus, so that the camera sits low and to the side of the table looking across it. The
## album shot frames the album with the recorder at its left edge; the glide ends at the recorder shot (the recorder in the foreground, the album and the
## lantern behind it); the push-in ends at the closer one. The focus of each is the thing, shifted along the line.
@export var album_shot: Vector3 = Vector3(-0.38, 0.36, 0.38)
@export var album_focus_shift: float = -0.1
@export var recorder_shot: Vector3 = Vector3(-0.22, 0.24, 0.29)
@export var recorder_focus_shift: float = 0.1
@export var push_shot: Vector3 = Vector3(-0.18, 0.2, 0.25)
## A faint warm fill over Table A while the cinematic camera is on it, so that the recorder reads (the lantern alone leaves it dark). It dims with
## the lantern and goes with the camera; 0 turns it off.
@export var camera_fill_energy: float = 0.45

@export_category("Timing (seconds)")
## The last photograph registers before the album closes.
@export var last_photo_pause_seconds: float = 0.7
## Looking down at the album, then the glide to the recorder, the rewind (it starts this long before the glide ends) and how long it lasts.
@export var album_hold_seconds: float = 1.0
@export var glide_seconds: float = 4.0
@export var rewind_before_glide_end_seconds: float = 1.0
@export var rewind_seconds: float = 2.2
## The lantern's failure lasts this long at the end of the recorded part; after the last cue the tape stops and there are this many quiet seconds
## before the blackout; the push-in goes on this long past the last cue.
@export var lamp_failure_seconds: float = 3.5
## After Juliana's "Good." (the end of the tape) everything goes out at once, this long after; the whisper comes `line_after_dark_seconds` later.
@export var lights_out_after_good_seconds: float = 1.0
@export var push_extra_seconds: float = 1.0
## From the moment the lights are out to Sophia's last line (a whisper in the dark).
@export var line_after_dark_seconds: float = 0.3
## After the whisper, in the dark and the quiet, this long before the flashlight comes on.
@export var torch_on_after_line_seconds: float = 1.5
## The picture stays on the dark recorder shot until this long before the flashlight comes on, and then cuts to Juliana's own view.
@export var cut_before_torch_seconds: float = 0.2
## The desperate search, in legs of the BEAM (she points the light first and her head follows `search_head_lag_seconds` later, as in the wagon; the
## beam shakes a little, `search_shake`): a dart away from the voice (`search_away_degrees` in `search_away_seconds`), a cross towards it that stops half
## way (`search_cross_seconds`), a glance up (`search_glance_pitch_degrees`, `search_glance_seconds`), then the beam goes through the figure's place and
## `search_overshoot_degrees` past it (`search_pass_seconds`) without finding it, and drifts (`search_pause_seconds`). Then the mind catches up: a snap
## back to the figure in `snap_back_seconds`, with a punch of the lens to `stare_fov` (its usual is 75), the picture smearing, and a slow creep on to
## `stare_fov_end` while she stares, trembling. The figure is on view from when the beam passes over it until it goes; the stare lasts
## `figure_hold_seconds`, counted from the snap back.
@export var search_away_degrees: float = 26.0
@export var search_away_seconds: float = 0.32
@export var search_cross_seconds: float = 0.55
@export var search_glance_pitch_degrees: float = -12.0
@export var search_glance_seconds: float = 0.4
@export var search_overshoot_degrees: float = 24.0
@export var search_pass_seconds: float = 0.55
@export var search_pause_seconds: float = 0.35
@export var search_head_lag_seconds: float = 0.12
@export_range(0.0, 3.0, 0.05) var search_shake: float = 1.0
@export var snap_back_seconds: float = 0.22
@export var stare_fov: float = 50.0
@export var stare_fov_end: float = 42.0
@export var zoom_in_seconds: float = 0.25
## The shadow lowers its head, slowly, when her view first passes over it (within `beam_notice_degrees` of its head): this many degrees, over `head_bow_seconds`.
@export var beam_notice_degrees: float = 14.0
@export var head_bow_degrees: float = 22.0
@export var head_bow_seconds: float = 1.4
@export var figure_hold_seconds: float = 2.0
## How long after the flashlight's flicker (which takes the shadow) the token starts to fall, how long it falls, and how long it lies before the light returns to normal.
@export var token_delay_seconds: float = 0.07
@export var token_fall_seconds: float = 0.38
@export var landing_rest_seconds: float = 2.2
## The flashlight from the end of the last line to the end of the scene: very weak (this share of its usual strength) and never steady: a slow
## uneven wavering with sudden near-dark dropouts. It is the only light there.
@export_range(0.02, 1.0, 0.01) var torch_level: float = 0.12
## How far from the token its mark can be seen once it has landed.
@export var token_mark_extra_distance: float = 3.0
## How near the player must be to the album to be put into the sequence when the game is loaded with the album solved and the scene unfinished.
@export var resume_max_distance: float = 5.0

## Set when the player is not the node found by group "player".
@export var player: Node3D

var stage: Stage = Stage.EXPLORING

var _why_said: bool = false
var _recording_done: bool = false
var _ficha: Collectible = null
## True while this sequence holds the player's manual save block.
var _holding_save_block: bool = false
## What the sequence holds of the player's (and gives back): the player, their view lock, their flashlight's own key lock and scripted flag.
var _held: Node3D = null
var _held_view_locked: bool = false
var _held_scripted_flashlight: bool = false
var _held_toggle_lock: bool = false
var _torch: Node = null
var _cinema: Camera3D = null
var _cinema_fill: OmniLight3D = null
var _figure: SeatedFigure = null
var _held_flashlight_on: bool = false
## The lantern's irregular dips (stopped when its last fade begins).
var _lamp_dips: Tween = null
## The shadow has lowered its head (once).
var _head_bowed: bool = false
## She is staring at the shadow: the view and the beam tremble about `_stare_goal` (yaw, pitch).
var _staring: bool = false
var _stare_goal: Vector2 = Vector2.ZERO
## `_flash_time` when the search began.
var _search_started_at: float = 0.0
## True while the flashlight flickers back to its normal strength at the end, and what the flashlight is left as when the view is given back.
var _returning_to_normal: bool = false
var _end_with_light_on: bool = false
## The flashlight's energy at the moment the shadow was taken (a test reads it: it must be dark then).
var _light_when_shadow_left: float = -1.0
## While true the flashlight is on, weak and flickering (see `_flicker_level`).
var _flickering: bool = false
var _flash_time: float = 0.0
## `_flash_time` when the figure came into view.
var _figure_shown_at: float = 0.0
## `_flash_time` when the view snapped back to the figure and she began to stare.
var _focus_started_at: float = 0.0
var _zoom: Tween = null
## The sequence is running (so nothing else starts it again).
var _running: bool = false


func _ready() -> void:
	_why_said = _read_flag(KEY_WHY_SAID)
	_recording_done = _read_flag(KEY_RECORDING_DONE)

	_connect_signals()
	_restore_stage()


## A sequence cut short (the clearing unloaded mid way) gives back what it holds, and only that.
func _exit_tree() -> void:
	_release_view()
	if _holding_save_block:
		_set_saving_blocked(false)


func _process(delta: float) -> void:
	_flash_time += delta
	if _flickering and _torch != null and is_instance_valid(_torch):
		_torch.call("set_scripted_light", true, _flicker_level())
	if _staring and _held != null and is_instance_valid(_held):
		var shake: Vector2 = _tremble(_flash_time) * search_shake
		var eyes: Object = _held.get("movement_controller") as Object
		eyes.set("look_yaw", _stare_goal.x + shake.x * 0.12)
		eyes.set("look_pitch", _stare_goal.y + shake.y * 0.12)
		_aim_beam(_held, _stare_goal + shake * 0.5)
	if _figure != null and is_instance_valid(_figure) and _figure.visible and not _head_bowed and _held != null and is_instance_valid(_held):
		var look: Camera3D = (_held.get("movement_controller") as Object).get("camera") as Camera3D
		var to_head: Vector3 = (_figure.to_global(_figure.head_point) - look.global_position).normalized()
		if (-look.global_basis.z).dot(to_head) > cos(deg_to_rad(beam_notice_degrees)):
			_head_bowed = true
			_figure.lower_head(head_bow_degrees, head_bow_seconds)
	if _cinema_fill != null and is_instance_valid(_cinema_fill) and dressing != null:
		_cinema_fill.light_energy = camera_fill_energy * dressing.lantern_level


## The weak flashlight's strength now: `torch_level` wavering slowly and unevenly, and, a dozen times a second, a chance of a dropout to almost nothing.
func _flicker_level() -> float:
	var wave: float = 0.65 + 0.35 * sin(_flash_time * 11.3) * sin(_flash_time * 4.1 + 0.7)
	var raw: float = sin(floorf(_flash_time * 13.0) * 12.9898) * 43758.5453
	var gate: float = raw - floorf(raw)
	return torch_level * wave * (0.04 if gate > 0.8 else 1.0)


func _connect_signals() -> void:
	album.opened.connect(_on_album_opened)
	album.completed.connect(_on_album_completed)
	album.wrong_arrangement.connect(_on_album_wrong)


## Resumes from saved progress. A memory already seen is never replayed: the fire is cold ash, the camp is dark, Table B is clear and the Ficha
## lies on it unless it has been taken (the Collectible removes itself then). An album solved with the scene unfinished (a game left in the middle)
## begins the sequence when the player is next at the album, with nothing open.
func _restore_stage() -> void:
	if _recording_done:
		_apply_finished_state()
		_place_ficha()
		stage = Stage.DONE
		return

	recorder.start_turning()

	if album.locked:
		_resume_when_ready.call_deferred()


func _apply_finished_state() -> void:
	fire.extinguish()
	if dressing != null:
		dressing.put_out_lights()
		dressing.clear_log_table()


func _resume_when_ready() -> void:
	while is_inside_tree() and stage == Stage.EXPLORING:
		if _can_start_here():
			_run_sequence(true)
			return
		await _wait(0.3)


## Whether the player may be taken into the sequence from where they are: free (no panel, dialogue or cutscene of another system) and near the album.
func _can_start_here() -> bool:
	var target: Node3D = _get_player()
	if target == null or not is_instance_valid(target):
		return false

	var movement: Object = target.get("movement_controller") as Object
	if movement == null or movement.get("camera") == null:
		return false

	for flag: String in ["view_locked", "cutscene_frozen", "dialogue_frozen", "modal_ui_open"]:
		if bool(target.get(flag)):
			return false

	var inspect: Object = target.get("inspect_controller") as Object
	if inspect != null and bool(inspect.call("is_open")):
		return false

	var inventory: Object = target.get("inventory_ui_controller") as Object
	if inventory != null and bool(inventory.call("is_inventory_open")):
		return false

	return (movement.get("camera") as Camera3D).global_position.distance_to(album.global_position) <= resume_max_distance


# ============================================================
# TRIGGERS AND ALBUM
# ============================================================

## Opening the album for the first time gives Juliana's first line.
func _on_album_opened() -> void:
	if stage != Stage.EXPLORING or _why_said:
		return

	_why_said = true
	_write_flag(KEY_WHY_SAID)
	CaptionManager.say(LINE_WHY_THIS_PLACE)


func _on_album_completed() -> void:
	_run_sequence(false)


## Every space is full and it is not right: a subtle burst of static, nothing else.
func _on_album_wrong() -> void:
	var glitch: AudioStreamPlayer = AudioStreamPlayer.new()
	glitch.stream = PlaceholderAudio.make_static_glitch()
	glitch.volume_db = -13.0
	add_child(glitch)
	glitch.finished.connect(glitch.queue_free)
	glitch.play()


# ============================================================
# THE SEQUENCE
# ============================================================

## The whole of it, from the last photograph to the token on the table. `resumed`: begun from a loaded game (no last photograph to register).
func _run_sequence(resumed: bool) -> void:
	if _running or stage >= Stage.FINALE:
		return

	_running = true
	stage = Stage.FINALE
	var target: Node3D = _get_player()
	_set_saving_blocked(true)
	_hold_view(target)
	album.interaction_enabled = false

	# 0. The last photograph registers; the album view closes through its own path (the player is already held, so nothing can be walked away from).
	if not resumed:
		await _wait(last_photo_pause_seconds)
	if album.view != null and album.view.is_open():
		album.view.close()
	await get_tree().physics_frame

	# 1. Over the album, then to the recorder, in one take.
	_begin_cinema(target)
	var focus_album: Vector3 = _album_focus()
	var focus_recorder: Vector3 = _recorder_focus()
	var start: Transform3D = _cinema_pose(focus_album, album_shot)
	var arrival: Transform3D = _cinema_pose(focus_recorder, recorder_shot)
	var closer: Transform3D = _cinema_pose(focus_recorder, push_shot)
	_cinema.global_transform = start
	_cinema.make_current()
	# The Table B props are not needed any more and the camera cannot see them: they go now.
	if dressing != null:
		dressing.clear_log_table()
	await _wait(album_hold_seconds)

	recorder.stop_turning()
	var glide: Tween = create_tween()
	glide.tween_method(_set_cinema_between.bind(start, arrival), 0.0, 1.0, glide_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(maxf(glide_seconds - rewind_before_glide_end_seconds, 0.0))
	recorder.rewind(rewind_seconds)
	await glide.finished
	await _wait(maxf(rewind_seconds - rewind_before_glide_end_seconds, 0.0))

	# 2. The conversation, the camera pushing in all the while and a little after.
	await _play_recording(arrival, closer)

	# 3. After "Good.": the reels and the rain stop and the figure is made (hidden, off camera); `lights_out_after_good_seconds` after the tape's end the lamp
	# on Table A and the fire go out AT ONCE. Nothing is added to the dark: the forest is as dark as it is.
	recorder.stop_turning()
	_play_rain(false)
	var good_at: float = _flash_time
	_make_figure(target)
	# Building the figure takes a long frame, and a timer made in the frame after it is still charged that frame's time.
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(maxf(lights_out_after_good_seconds - (_flash_time - good_at), 0.0))
	if _lamp_dips != null and _lamp_dips.is_valid():
		_lamp_dips.kill()
	fire.extinguish()
	if dressing != null:
		dressing.put_out_lights()

	# 4. The picture stays on the dark shot of the recorder; `line_after_dark_seconds` after the lights went out the last line is whispered over it.
	stage = Stage.EMPTY_SEAT
	await _wait(line_after_dark_seconds)
	_place_voice_at_figure()
	_start_voice(seat_voice_player)
	await CaptionManager.play_scripted_and_wait(CaptionTracks.FIG_EMPTY_SEAT)
	await _finish_voice(seat_voice_player)

	# 5. A beat of dark and quiet after the whisper; `cut_before_torch_seconds` before the flashlight comes on, hard cut to Juliana's own camera (her look on
	# Table A); then the flashlight comes on, very weak and flickering, and she searches desperately: the beam darts about with her head a beat behind
	# it, everything trembling; the shadow goes through the beam without stopping it; then she realises and snaps back.
	await _wait(maxf(torch_on_after_line_seconds - cut_before_torch_seconds, 0.0))
	_cut_to_juliana(target)
	await _wait(minf(cut_before_torch_seconds, torch_on_after_line_seconds))
	_flickering = true
	await _search_and_find(target)

	# 6. She stares at the shadow for `figure_hold_seconds`, counted from the snap back (the lens creeps in a little more, her hands trembling).
	_creep_zoom(target)
	await _wait(maxf(figure_hold_seconds - (_flash_time - _focus_started_at), 0.0))

	# 7. The flashlight flickers out and the shadow is gone when it comes back; the token falls.
	await _flicker_the_shadow_away()
	await _wait(token_delay_seconds)
	await _drop_the_token(target)

	# 8. The token lies there; then the light flickers back to its normal strength and the player has the view, the controls and the flashlight again.
	await _wait(landing_rest_seconds)
	await _flicker_to_normal()
	_end_with_light_on = true
	_release_view()

	_end_scene()


## The conversation, from the tape: rain round it, the camera pushing in. It ends on Juliana's "Good.", and the lantern fails at its end.
func _play_recording(from: Transform3D, to: Transform3D) -> void:
	stage = Stage.RECORDING
	_play_rain(true)
	_start_voice(recording_voice_player)

	var length: float = _track_length(CaptionTracks.FIG_RECORDING)
	var push: Tween = create_tween()
	push.tween_method(_set_cinema_between.bind(from, to), 0.0, 1.0, length + push_extra_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fail_the_lantern(maxf(length - lamp_failure_seconds, 0.0))
	await CaptionManager.play_scripted_and_wait(CaptionTracks.FIG_RECORDING)
	await _finish_voice(recording_voice_player)


## The flashlight flickers out and in and out again, and the shadow is gone the first time it is dark: when the light comes back there is nobody there.
func _flicker_the_shadow_away() -> void:
	_flickering = false
	var steps: Array = [[0.0, 0.07], [0.5, 0.04], [0.0, 0.1], [0.8, 0.03], [0.0, 0.1]]
	var removed: bool = false
	for step: Array in steps:
		_torch.call("set_scripted_light", float(step[0]) > 0.05, torch_level * float(step[0]))
		if not removed:
			removed = true
			_remove_figure()
			_light_when_shadow_left = float(_torch.get("light_energy"))
		await _wait(float(step[1]))
	_flickering = true


## The weak light flickers its way back to its normal strength (a few stutters, dark between, then steady and full), so that it returns to the
## player at full strength as if it had just caught.
func _flicker_to_normal() -> void:
	_returning_to_normal = true
	_flickering = false
	var steps: Array = [[0.0, 0.08], [0.3, 0.05], [0.0, 0.1], [0.6, 0.05], [0.0, 0.14], [1.0, 0.2]]
	for step: Array in steps:
		_torch.call("set_scripted_light", float(step[0]) > 0.01, float(step[0]))
		await _wait(float(step[1]))


## The lantern's failure: a few irregular dips (a flame in a draught, not a loop), `delay` seconds from now, lasting `lamp_failure_seconds`.
func _fail_the_lantern(delay: float) -> void:
	await _wait(delay)
	if dressing == null or stage != Stage.RECORDING:
		return

	var keys: Array = [[0.0, 1.0], [0.5, 0.62], [0.78, 0.95], [1.45, 0.4], [1.68, 0.85], [2.35, 0.26], [2.58, 0.62], [3.15, 0.12], [3.5, 0.36]]
	var dips: Tween = create_tween()
	_lamp_dips = dips
	var previous: float = 1.0
	var before: float = 0.0
	for key: Array in keys:
		var at: float = float(key[0]) * lamp_failure_seconds / 3.5
		if at > before:
			dips.tween_method(dressing.set_lantern_level, previous, float(key[1]), at - before)
		before = maxf(at, before)
		previous = float(key[1])


# ---- The cinematic camera ----------------------------------------------------------------------------------------

## A separate camera (its own lens), made once; the shots are placed on the table's line (`_shot_axis`), the same side of it all through.
func _begin_cinema(_target: Node3D) -> void:
	_free_cinema()
	_cinema = Camera3D.new()
	_cinema.name = "SequenceCamera"
	_cinema.fov = camera_fov
	add_child(_cinema)
	if camera_fill_energy > 0.0:
		_cinema_fill = OmniLight3D.new()
		_cinema_fill.name = "CinemaFill"
		_cinema_fill.light_color = Color(1.0, 0.8, 0.55)
		_cinema_fill.light_energy = camera_fill_energy
		_cinema_fill.omni_range = 2.2
		_cinema_fill.shadow_enabled = false
		add_child(_cinema_fill)
		_cinema_fill.global_position = _recorder_focus() + _shot_across() * 0.3 + Vector3.UP * 0.5


func _free_cinema() -> void:
	if _cinema_fill != null and is_instance_valid(_cinema_fill):
		_cinema_fill.queue_free()
	_cinema_fill = null
	if _cinema != null and is_instance_valid(_cinema):
		_cinema.queue_free()
	_cinema = null


## The line the shots are placed on: from the recorder to the album, flat, and the way across it that puts the camera on the near side of the table.
func _shot_axis() -> Vector3:
	var along: Vector3 = album.global_position - recorder.global_position
	along.y = 0.0
	return along.normalized() if along.length() > 0.05 else Vector3.RIGHT


func _shot_across() -> Vector3:
	return _shot_axis().cross(Vector3.UP).normalized()


func _album_focus() -> Vector3:
	return album.global_position + Vector3(0.0, 0.04, 0.0) + _shot_axis() * album_focus_shift


## The recorder's cassette and reels, on the top of its case.
func _recorder_focus() -> Vector3:
	return recorder.global_position + Vector3(0.0, 0.07, 0.0) + _shot_axis() * recorder_focus_shift


## The camera at `offset` (along, across, up) from `focus`, looking at it.
func _cinema_pose(focus: Vector3, offset: Vector3) -> Transform3D:
	var origin: Vector3 = focus + _shot_axis() * offset.x + _shot_across() * offset.y + Vector3.UP * offset.z
	return Transform3D(Basis.looking_at(focus - origin, Vector3.UP), origin)


func _set_cinema_between(t: float, from: Transform3D, to: Transform3D) -> void:
	if _cinema != null and is_instance_valid(_cinema):
		_cinema.global_transform = Transform3D(from.basis.slerp(to.basis, t), from.origin.lerp(to.origin, t))


# ---- Holding the player ------------------------------------------------------------------------------------------

## Takes the player's view, controls and flashlight (and remembers what was theirs): looking, walking, using things and the flashlight key
## are the sequence's from here, the flashlight held off (the external camera must not be lit by a beam from where she stands).
func _hold_view(target: Node3D) -> void:
	_held = target
	_held_view_locked = bool(target.get("view_locked"))
	_held_scripted_flashlight = bool(target.get("scripted_flashlight"))
	target.call("set_view_locked", true)
	target.set("scripted_flashlight", true)
	_torch = target.get("flashlight_controller") as Node
	if _torch != null:
		_held_toggle_lock = bool(_torch.get("toggle_locked"))
		_torch.set("toggle_locked", true)
		_held_flashlight_on = bool(_torch.get("flashlight_on"))
		_torch.call("begin_scripted_light")
		_torch.call("set_scripted_light", false, 0.0)


## Gives back only what `_hold_view` took: the view, the cameras, the flashlight (its own strength) and the key. The view is left where the
## sequence turned it; nothing is restored to what it was before.
func _release_view() -> void:
	_flickering = false
	_staring = false
	if _zoom != null and _zoom.is_valid():
		_zoom.kill()
	if _held != null and is_instance_valid(_held):
		var lens: Object = _held.get("movement_controller") as Object
		if lens != null:
			lens.set("scripted_fov", 0.0)
	_free_cinema()
	_remove_figure()
	if _torch != null and is_instance_valid(_torch):
		# The flashlight is back as the player had it (on or off) at its usual strength.
		_torch.set("scripted_aim_on", false)
		if _end_with_light_on:
			_torch.set("flashlight_on", true)
		_torch.call("set_scripted_light", _held_flashlight_on or _end_with_light_on, 1.0)
		_torch.call("end_scripted_light")
		_torch.set("toggle_locked", _held_toggle_lock)

	_torch = null
	if _held != null and is_instance_valid(_held):
		var movement: Object = _held.get("movement_controller") as Object
		if movement != null and movement.get("camera") != null and (movement.get("camera") as Camera3D).is_inside_tree():
			(movement.get("camera") as Camera3D).make_current()
		_held.set("scripted_flashlight", _held_scripted_flashlight)
		_held.call("set_view_locked", _held_view_locked)

	if _ficha != null and is_instance_valid(_ficha):
		_ficha.mark_while_held = false
	_held = null


## The hard cut, once the lamp is out, to Juliana's own camera at her own eye, her look on Table A (the look state is set, not only the camera, so that
## the first mouse movement cannot snap the view). The audio listener is the current camera's.
func _cut_to_juliana(target: Node3D) -> void:
	_free_cinema()
	var movement: Object = target.get("movement_controller") as Object
	_aim_at(target, movement, _table_a_point())
	(movement.get("camera") as Camera3D).make_current()


func _table_a_point() -> Vector3:
	return (album.global_position + recorder.global_position) * 0.5 + Vector3(0.0, 0.05, 0.0)


## Sets the player's look (yaw and pitch of the movement controller) to look from their eye at `point`.
func _aim_at(target: Node3D, movement: Object, point: Vector3) -> void:
	var angles: Vector2 = _look_angles(target, movement, point)
	var from_yaw: float = float(movement.get("look_yaw"))
	movement.set("look_yaw", from_yaw + wrapf(angles.x - from_yaw, -180.0, 180.0))
	movement.set("look_pitch", clampf(angles.y, -35.0, 75.0))


## Yaw and pitch (the movement controller's degrees) that look from the player's eye at `point`.
func _look_angles(target: Node3D, movement: Object, point: Vector3) -> Vector2:
	var eye: Vector3 = (movement.get("camera") as Camera3D).global_position
	var d: Vector3 = target.global_basis.inverse() * (point - eye)
	return Vector2(rad_to_deg(atan2(d.x, -d.z)), rad_to_deg(atan2(-d.y, Vector2(d.x, d.z).length())))


## The desperate search for whoever whispered, and the finding of the shadow: the beam darts about on its legs (see `search_away_degrees`) with her head a beat
## behind it and everything shaking a little, goes through the place of the shadow (which comes into view as it passes) and past it without stopping, drifts;
## then the mind catches up and the beam and the head snap back to it and stop exactly on it, the lens punching in at once.
func _search_and_find(target: Node3D) -> void:
	var movement: Object = target.get("movement_controller") as Object
	var angles: Vector2 = _look_angles(target, movement, _reveal_point())
	var start: Vector2 = Vector2(float(movement.get("look_yaw")), float(movement.get("look_pitch")))
	var goal: Vector2 = Vector2(start.x + wrapf(angles.x - start.x, -180.0, 180.0), clampf(angles.y, -35.0, 75.0))
	var swing: float = goal.x - start.x
	var way: float = 1.0 if swing >= 0.0 else -1.0
	var legs: Array = [
		[Vector2(start.x - way * search_away_degrees, start.y + 3.0), search_away_seconds],
		[Vector2(start.x + swing * 0.5, start.y), search_cross_seconds],
		[Vector2(start.x + swing * 0.62, goal.y + search_glance_pitch_degrees), search_glance_seconds],
		[Vector2(goal.x + way * search_overshoot_degrees, goal.y - 4.0), search_pass_seconds],
		[Vector2(goal.x + way * (search_overshoot_degrees + 4.0), goal.y - 5.0), search_pause_seconds],
	]
	var path_seconds: float = 0.0
	for leg: Array in legs:
		path_seconds += float(leg[1])
	var beam_end: Vector2 = (legs[legs.size() - 1] as Array)[0] as Vector2
	var head_end: Vector2 = Vector2(beam_end.x, lerpf(start.y, beam_end.y, 0.6))
	var snap_start: float = path_seconds + search_head_lag_seconds
	var total: float = snap_start + 0.06 + snap_back_seconds
	var snapping: Array[bool] = [false]
	_search_started_at = _flash_time
	_staring = false
	if _torch != null:
		_torch.set("scripted_aim_speed", 2.5)
		_torch.set("scripted_aim_on", true)
	var search: Tween = create_tween()
	search.tween_method(
		func(seconds: float) -> void:
			var beam: Vector2
			var head: Vector2
			if seconds < snap_start:
				beam = _along_legs(start, legs, seconds)
				head = _along_legs(start, legs, seconds - search_head_lag_seconds)
				head.y = lerpf(start.y, head.y, 0.6)
				# The shadow is on view as the beam goes over it (she is not looking at it yet: the head is behind the beam).
				if not _figure.visible and (beam.x - start.x) * way >= absf(swing) * 0.9:
					_show_the_figure()
			else:
				if not snapping[0]:
					snapping[0] = true
					_begin_staring(movement)
				var q_beam: float = smoothstep(0.0, 1.0, clampf((seconds - snap_start) / snap_back_seconds, 0.0, 1.0))
				var q_head: float = smoothstep(0.0, 1.0, clampf((seconds - snap_start - 0.06) / snap_back_seconds, 0.0, 1.0))
				beam = beam_end.lerp(goal, q_beam)
				head = head_end.lerp(goal, q_head)
			var shake: Vector2 = _tremble(_flash_time) * search_shake
			_aim_beam(target, beam + shake * 0.5)
			movement.set("look_yaw", head.x + shake.x * 0.12)
			movement.set("look_pitch", head.y + shake.y * 0.12),
		0.0, total, total
	)
	await search.finished
	if not _figure.visible:
		_show_the_figure()
	if not snapping[0]:
		_begin_staring(movement)
	movement.set("look_yaw", goal.x)
	movement.set("look_pitch", goal.y)
	_stare_goal = goal
	_staring = true


## Where the beam is `seconds` into its path of legs (each a dart: a cubic ease out to its mark).
func _along_legs(start: Vector2, legs: Array, seconds: float) -> Vector2:
	var from: Vector2 = start
	var at: float = 0.0
	for leg: Array in legs:
		var length: float = float(leg[1])
		if seconds < at + length:
			var u: float = clampf((seconds - at) / length, 0.0, 1.0)
			return from.lerp(leg[0] as Vector2, 1.0 - pow(1.0 - u, 3.0))
		at += length
		from = leg[0] as Vector2
	return from


## A scared hand: the sum of a few sines, in degrees (as in the wagon's search).
func _tremble(t: float) -> Vector2:
	return Vector2(
		sin(t * 17.0) * 0.55 + sin(t * 9.3 + 1.3) * 0.7 + sin(t * 3.1) * 0.5,
		sin(t * 13.0 + 0.6) * 0.5 + cos(t * 7.1) * 0.6 + sin(t * 2.3 + 2.0) * 0.4
	)


## Points the flashlight along a view yaw and pitch (the movement controller's degrees, pitch positive down) in the world.
func _aim_beam(target: Node3D, angles: Vector2) -> void:
	if _torch == null or not is_instance_valid(_torch):
		return
	var level: Vector3 = Basis(Vector3.UP, -deg_to_rad(angles.x)) * Vector3.FORWARD
	var direction: Vector3 = level * cos(deg_to_rad(angles.y)) + Vector3.DOWN * sin(deg_to_rad(angles.y))
	_torch.set("scripted_aim_direction", target.global_basis * direction)


## The mind catches up: the stare begins (its time is counted from now) and the lens snaps in a little.
func _begin_staring(movement: Object) -> void:
	_focus_started_at = _flash_time
	_zoom_to(movement, stare_fov, zoom_in_seconds, Tween.TRANS_EXPO, Tween.EASE_OUT)
	var filter: Node = get_node_or_null("/root/HorrorFilter")
	if filter != null and filter.has_method("pulse_unease"):
		filter.call("pulse_unease", 0.9, 2.4)


## While she stares the lens creeps in a little more.
func _creep_zoom(target: Node3D) -> void:
	var movement: Object = target.get("movement_controller") as Object
	_zoom_to(movement, stare_fov_end, maxf(figure_hold_seconds, 0.1), Tween.TRANS_SINE, Tween.EASE_IN_OUT)


## Moves the lens (the player movement controller follows `scripted_fov` smoothly); 0 gives it back.
func _zoom_to(movement: Object, fov: float, seconds: float, transition: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if _zoom != null and _zoom.is_valid():
		_zoom.kill()
	var start: float = float(movement.get("scripted_fov"))
	if start <= 0.0:
		start = 75.0
	_zoom = create_tween().set_trans(transition).set_ease(ease_type)
	_zoom.tween_method(func(value: float) -> void: movement.set("scripted_fov", value), start, fov, seconds)


## The shadow comes into view with the token in its hand.
func _show_the_figure() -> void:
	_figure.visible = true
	_figure_shown_at = _flash_time
	if _ficha != null and is_instance_valid(_ficha):
		_ficha.visible = true





## What the view is on at the reveal: the figure's shoulders and the tabletop beside it, where the token will land.
func _reveal_point() -> Vector3:
	var shoulders: Vector3 = _figure.to_global(Vector3(0.0, _figure.head_point.y - 0.25, 0.0))
	return shoulders.lerp(token_landing(), 0.45)


# ---- Table B: the figure, the token ------------------------------------------------------------------------------

## The table's frame, and where the token lies on it in the end: on the tabletop, `token_side_offset` to the side the token is held on from where
## the figure sits, `token_in_from_edge` in from the near edge.
func token_landing() -> Vector3:
	var table: Transform3D = dressing.log_table.global_transform
	var side: float = 1.0 if token_on_left else -1.0
	return table * Vector3(figure_along, FigClearingProps.TABLE_TOP_Y + 0.003, FigClearingProps.TABLE_DEPTH * 0.5 - token_in_from_edge)\
		+ _figure_frame_left() * side * token_side_offset


## Where the figure sits (on the bench, `figure_along` along it) and which way it faces (to the table's middle), as a transform.
func _figure_frame() -> Transform3D:
	var bench: Transform3D = dressing.log_bench.global_transform
	# The table is on the bench's -Z side.
	var seat: Vector3 = bench * Vector3(figure_along, FigClearingProps.BENCH_SEAT_Y, -figure_forward)
	var toward: Vector3 = dressing.log_table.global_position - seat
	toward.y = 0.0
	return Transform3D(Basis(Vector3.UP, atan2(toward.x, toward.z)), Vector3(seat.x, bench.origin.y, seat.z))


## The figure's left, in the world (flat).
func _figure_frame_left() -> Vector3:
	return _figure_frame().basis * Vector3.RIGHT


## Builds the figure on the bench, hidden, in the black (before the beam is anywhere near): sitting there, back to Juliana, the token in a hand
## over the tabletop. The Ficha is made in the same moment (not part of the figure, so that hiding the figure cannot hide it), held in the hand
## and not yet to be taken.
func _make_figure(_target: Node3D) -> void:
	_remove_figure()
	_head_bowed = false
	if dressing == null or dressing.log_bench == null:
		return

	var frame: Transform3D = _figure_frame()
	var landing: Vector3 = token_landing()
	var hold_world: Vector3 = landing + Vector3.UP * token_hand_height
	_figure = SeatedFigure.new()
	_figure.name = "SeatedFigure"
	_figure.visible = false
	_figure.build(FigClearingProps.BENCH_SEAT_Y, figure_scale, {
		"token_hand": "Left" if token_on_left else "Right",
		"hold": frame.affine_inverse() * hold_world,
		"rest": Vector3((-0.2 if token_on_left else 0.2), FigClearingProps.BENCH_SEAT_Y + 0.12, 0.25),
	})
	add_child(_figure)
	_figure.global_transform = frame
	_figure.set_ground(frame.origin.y)
	# The token, in the hand.
	var ficha: Collectible = _make_ficha()
	if ficha != null:
		ficha.pickup_enabled = false
		ficha.global_transform = _held_token_pose()
		ficha.visible = false


## The token as the hand holds it: over the tabletop at the hold point, tilted a little, as a thumb and finger have it.
func _held_token_pose() -> Transform3D:
	var landing: Transform3D = _token_resting_pose()
	return Transform3D(landing.basis * Basis(Vector3.RIGHT, deg_to_rad(28.0)) * Basis(Vector3.FORWARD, deg_to_rad(12.0)), landing.origin + Vector3.UP * token_hand_height)


## The token flat and face up at its landing place.
func _token_resting_pose() -> Transform3D:
	var yaw: float = deg_to_rad(FigClearingProps.TABLE_YAW + 90.0)
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-90.0)), token_landing())


func _remove_figure() -> void:
	if _figure != null and is_instance_valid(_figure):
		_figure.visible = false
		_figure.queue_free()
	_figure = null


## A Ficha of the real kind, on Table B at its resting pose; null if it was made already.
func _make_ficha() -> Collectible:
	if ficha_scene == null or dressing == null or dressing.log_table == null or _ficha != null:
		return null

	_ficha = ficha_scene.instantiate() as Collectible
	add_child(_ficha)
	_ficha.global_transform = _token_resting_pose()
	return _ficha


## Puts Juliana's Ficha on Table B at once, unless she has taken it (the Collectible removes itself then).
func _place_ficha() -> void:
	_make_ficha()


## The token falls from the hand to the tabletop (a fixed tween: no physics), turning flat as it goes, with one clink and one small settle. Then
## it can be taken, and its mark reaches as far as Juliana's eyes.
func _drop_the_token(target: Node3D) -> void:
	var ficha: Collectible = _ficha
	if ficha == null or not is_instance_valid(ficha):
		return

	var start: Transform3D = ficha.global_transform
	var final: Transform3D = _token_resting_pose()
	var fall: Tween = create_tween()
	fall.tween_method(
		func(t: float) -> void:
			var down: float = t * t
			var flat: float = 1.0 - pow(1.0 - t, 2.0)
			ficha.global_transform = Transform3D(start.basis.slerp(final.basis, flat), start.origin.lerp(final.origin, down)),
		0.0, 1.0, token_fall_seconds
	)
	await fall.finished
	if not is_instance_valid(ficha):
		return

	_play_clink(final.origin)
	var settle: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	settle.tween_property(ficha, "global_position:y", final.origin.y + 0.012, 0.05).set_ease(Tween.EASE_OUT)
	settle.tween_property(ficha, "global_position:y", final.origin.y, 0.06).set_ease(Tween.EASE_IN)
	await settle.finished
	if not is_instance_valid(ficha):
		return

	ficha.global_transform = final
	# Now it is a thing to take: its mark (not its reach) shows from where she stands.
	var movement: Object = target.get("movement_controller") as Object
	var eye: Vector3 = (movement.get("camera") as Camera3D).global_position
	ficha.pickup_enabled = true
	ficha.mark_notice_distance = eye.distance_to(final.origin) + token_mark_extra_distance
	ficha.mark_while_held = true


## One localized metallic clink at `at`.
func _play_clink(at: Vector3) -> void:
	var sound: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	sound.stream = PlaceholderAudio.make_metal_clink()
	sound.volume_db = -8.0
	sound.unit_size = 3.0
	sound.max_distance = 18.0
	add_child(sound)
	sound.global_position = at
	sound.finished.connect(sound.queue_free)
	sound.play()


## The last voice slot is placed at the figure's head, where the line comes from.
func _place_voice_at_figure() -> void:
	if empty_seat != null and _figure != null:
		empty_seat.global_position = _figure.to_global(_figure.head_point)


## The scene is over and the token is down: the state is saved as done, and only then may the player save again.
func _end_scene() -> void:
	_recording_done = true
	_write_flag(KEY_RECORDING_DONE)
	album.interaction_enabled = true
	stage = Stage.DONE
	_running = false
	_set_saving_blocked(false)
	sequence_completed.emit()


# ============================================================
# HELPERS
# ============================================================

## The length of a caption track: the end of its last cue.
func _track_length(track: StringName) -> float:
	var last: float = 0.0
	for cue: Dictionary in CaptionTracks.get_cues(track):
		last = maxf(last, float(cue["end"]))
	return last


func _play_rain(enabled: bool) -> void:
	if rain_player == null:
		return

	if enabled:
		rain_player.stream = PlaceholderAudio.make_rain_loop()
		rain_player.volume_db = -16.0
		rain_player.play()
	else:
		rain_player.stop()


## Plays a voice clip if one is assigned. With none, the captions alone carry the line.
func _start_voice(voice: AudioStreamPlayer3D) -> void:
	if voice != null and voice.stream != null:
		voice.play()


## Waits for a voice clip that is still playing after its captions, but never longer than the clip itself: a player with
## no stream, or one that has stopped, is not waited for.
func _finish_voice(voice: AudioStreamPlayer3D) -> void:
	if voice == null or voice.stream == null:
		return

	var left: float = voice.stream.get_length() + 0.25
	while is_instance_valid(voice) and voice.playing and left > 0.0:
		await _wait(0.1)
		left -= 0.1


func _set_saving_blocked(blocked: bool) -> void:
	_holding_save_block = blocked
	var target: Node = _get_player()
	if target != null and is_instance_valid(target) and target.has_method("set_manual_save_blocked"):
		target.call("set_manual_save_blocked", blocked)


func _get_player() -> Node3D:
	if player != null:
		return player

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group(&"player") as Node3D


func _wait(seconds: float) -> void:
	# Not "process always": the pause menu also pauses the sequence.
	await get_tree().create_timer(seconds, false).timeout


func _read_flag(key: StringName) -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, key, false))


func _write_flag(key: StringName) -> void:
	SaveManager.set_state_value(STATE_SECTION, key, true)
