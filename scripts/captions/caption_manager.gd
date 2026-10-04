extends CanvasLayer

## Shows captions for voiced audio, in the player's caption language.
##
## Autoload "CaptionManager". Two ways to caption:
##
## - Audio that exists: start it, then `follow_player(track_id, player)`. The
##   manager reads the player's playback position every frame, so captions stay
##   in sync through pauses, seeking and voice-language changes, and clear
##   themselves when the audio stops.
## - Scripted lines (no audio yet, or audio the level plays itself): `say()` for
##   one line or `play_scripted()` for a timed track. Runs are queued and play
##   one after another on an internal clock that stops while the game is paused.
##   `say_and_wait()` / `play_scripted_and_wait()` can be awaited.
##
## Cue data lives in CaptionTracks. A cue may name a `speaker` (localization key)
## that is shown before the line; a cue with an empty key shows nothing, which is
## how a track keeps its length through a silent stretch.

signal run_finished(run_id: int)

## Reading speed used to size a one-off `say()` line.
const SECONDS_PER_WORD: float = 0.4
const MIN_LINE_SECONDS: float = 1.8
const LINE_TAIL_SECONDS: float = 0.8

@onready var panel: PanelContainer = $Root/Anchor/CaptionPanel
@onready var label: Label = $Root/Anchor/CaptionPanel/CaptionLabel

var _player: AudioStreamPlayer = null
var _cues: Array = []
var _shown_key: String = ""

var _runs: Array[Dictionary] = []
var _active_run: Dictionary = {}
var _clock: float = 0.0
var _next_run_id: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

	GameSettings.captions_enabled_changed.connect(_on_settings_changed)
	GameSettings.caption_language_changed.connect(_on_settings_changed)
	GameSettings.caption_size_changed.connect(_on_size_changed)
	_apply_font_size()


## Starts following `player`: captions for `track_id` show while it plays.
## This takes over from any scripted run.
func follow_player(track_id: StringName, player: AudioStreamPlayer) -> void:
	_drop_runs()
	_player = player
	_cues = CaptionTracks.get_cues(track_id)
	_shown_key = ""
	set_process(true)


## Queues one caption line. `duration` <= 0 sizes it from the text length.
## Returns the run id, which `run_finished` reports.
func say(key: String, duration: float = 0.0, speaker_key: String = "") -> int:
	if duration <= 0.0:
		duration = _estimate_duration(key)

	var cue: Dictionary = {
		"start": 0.0,
		"end": duration,
		"key": key,
		"speaker": speaker_key,
	}
	return _queue_run([cue])


## Queues a timed track from CaptionTracks. Returns the run id.
func play_scripted(track_id: StringName) -> int:
	return _queue_run(CaptionTracks.get_cues(track_id))


func say_and_wait(
	key: String,
	duration: float = 0.0,
	speaker_key: String = ""
) -> void:
	await _wait_for_run(say(key, duration, speaker_key))


func play_scripted_and_wait(track_id: StringName) -> void:
	await _wait_for_run(play_scripted(track_id))


## Stops following the current audio, drops queued runs and hides the caption.
func clear() -> void:
	_player = null
	_cues = []
	_drop_runs()
	_hide_caption()


func _process(delta: float) -> void:
	if _player != null:
		_process_player_track()
		return

	_process_scripted_runs(delta)


func _process_player_track() -> void:
	if not is_instance_valid(_player) or not _player.playing:
		clear()
		return

	_show_cue_at(_cues, _get_playback_seconds())


func _process_scripted_runs(delta: float) -> void:
	if _active_run.is_empty():
		if _runs.is_empty():
			return

		_active_run = _runs.pop_front()
		_clock = 0.0
		_shown_key = ""

	if not get_tree().paused:
		_clock += delta

	var cues: Array = _active_run["cues"]
	if _clock >= float(_active_run["end"]):
		var finished_id: int = int(_active_run["id"])
		_active_run = {}
		_hide_caption()
		run_finished.emit(finished_id)
		return

	_show_cue_at(cues, _clock)


func _show_cue_at(cues: Array, position: float) -> void:
	if not GameSettings.get_captions_enabled():
		_hide_caption()
		return

	for cue: Dictionary in cues:
		if position >= float(cue["start"]) and position < float(cue["end"]):
			var key: String = str(cue["key"])
			if key.is_empty():
				break

			_show_caption(key, str(cue.get("speaker", "")))
			return

	_hide_caption()


func _queue_run(cues: Array) -> int:
	var run_id: int = _next_run_id
	_next_run_id += 1

	var end_time: float = 0.0
	for cue: Dictionary in cues:
		end_time = maxf(end_time, float(cue["end"]))

	_runs.append({"id": run_id, "cues": cues, "end": end_time})
	set_process(true)
	return run_id


func _wait_for_run(run_id: int) -> void:
	while true:
		var finished_id: int = await run_finished
		if finished_id == run_id:
			return


func _estimate_duration(key: String) -> float:
	var words: int = _translate(key).split(" ", false).size()
	return maxf(
		MIN_LINE_SECONDS,
		words * SECONDS_PER_WORD + LINE_TAIL_SECONDS
	)


## Playback position, corrected for the audio that has been mixed but not yet
## heard, so the text appears with the voice and not slightly ahead of it.
func _get_playback_seconds() -> float:
	var position: float = _player.get_playback_position()
	if not _player.stream_paused:
		position += AudioServer.get_time_since_last_mix()
		position -= AudioServer.get_output_latency()

	return maxf(position, 0.0)


func _show_caption(key: String, speaker_key: String) -> void:
	var shown_id: String = key + "|" + speaker_key
	if shown_id != _shown_key:
		_shown_key = shown_id
		label.text = _compose_text(key, speaker_key)

	panel.visible = true


func _compose_text(key: String, speaker_key: String) -> String:
	if speaker_key.is_empty():
		return _translate(key)

	return "%s: %s" % [_translate(speaker_key), _translate(key)]


func _hide_caption() -> void:
	_shown_key = ""
	panel.visible = false


## Looks the key up in the caption language, not the interface language.
func _translate(key: String) -> String:
	var translation: Translation = TranslationServer.get_translation_object(
		GameSettings.get_caption_locale()
	)
	if translation != null:
		var message: String = str(translation.get_message(StringName(key)))
		if not message.is_empty():
			return message

	return tr(key)


func _on_settings_changed(_value: Variant) -> void:
	# Re-render the visible caption with the new language, or hide it.
	_shown_key = ""
	if not GameSettings.get_captions_enabled():
		_hide_caption()


func _on_size_changed(_size_index: int) -> void:
	_apply_font_size()


func _apply_font_size() -> void:
	label.add_theme_font_size_override(
		&"font_size",
		GameSettings.get_caption_font_size()
	)


## Forgets every queued and running scripted line, releasing anyone awaiting it.
func _drop_runs() -> void:
	var dropped_ids: Array[int] = []
	if not _active_run.is_empty():
		dropped_ids.append(int(_active_run["id"]))

	for run: Dictionary in _runs:
		dropped_ids.append(int(run["id"]))

	_runs.clear()
	_active_run = {}
	for run_id: int in dropped_ids:
		run_finished.emit(run_id)
