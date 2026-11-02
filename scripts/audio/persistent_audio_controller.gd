extends Node
class_name PersistentAudioController

## Raised when the opening narration is over, or was stopped (so that nobody waits for it for ever).
signal intro_narration_finished
## Raised when the next scene may begin its opening (see `hold_opening`).
signal opening_released

@export var menu_idle_player_path: String = "MenuIdlePlayer"
@export var intro_narration_player_path: String = "IntroNarrationPlayer"

@export_category("Localized Voice")
@export var intro_narration_english: AudioStream
@export var intro_narration_brazilian_portuguese: AudioStream

@export var menu_idle_volume_db: float = -8.0
@export var intro_narration_volume_db: float = -10.0

@export var menu_idle_fade_out_db: float = -40.0

@export var settings_file_path: String = "user://settings.cfg"
@export var settings_section_name: String = "audio"
@export var master_volume_key: String = "master_volume_percent"

@export var default_master_volume_percent: float = 100.0

var menu_idle_player: AudioStreamPlayer = null
var intro_narration_player: AudioStreamPlayer = null

var menu_idle_should_loop: bool = false
var menu_idle_tween: Tween = null

var narration_request_id: int = 0
## True from the request until the narration ends or is stopped; `_narration_with_voice` says whether a recording is the clock (else the caption schedule is).
var _narration_running: bool = false
var _narration_with_voice: bool = false
var _narration_run_id: int = -1
var _narration_held: bool = false
var _opening_held: bool = false
var master_volume_percent: float = 100.0
var fallback_intro_narration: AudioStream = null


func _ready() -> void:
	_find_audio_players()
	_connect_language_settings()
	_apply_intro_narration_language()
	_load_master_volume()


func _exit_tree() -> void:
	menu_idle_should_loop = false
	narration_request_id += 1

	if menu_idle_tween != null and menu_idle_tween.is_valid():
		menu_idle_tween.kill()

	menu_idle_tween = null

	if is_instance_valid(menu_idle_player):
		menu_idle_player.stop()

		if menu_idle_player.finished.is_connected(
			_on_menu_idle_finished
		):
			menu_idle_player.finished.disconnect(
				_on_menu_idle_finished
			)

		menu_idle_player.stream = null

	if is_instance_valid(intro_narration_player):
		intro_narration_player.stop()
		intro_narration_player.stream = null

	if GameSettings.voice_language_changed.is_connected(
		_on_voice_language_changed
	):
		GameSettings.voice_language_changed.disconnect(
			_on_voice_language_changed
		)

	fallback_intro_narration = null


func _find_audio_players() -> void:
	menu_idle_player = get_node_or_null(NodePath(menu_idle_player_path)) as AudioStreamPlayer

	if menu_idle_player == null:
		menu_idle_player = find_child("MenuIdlePlayer", true, false) as AudioStreamPlayer

	if menu_idle_player == null:
		push_warning("PersistentAudioController: MenuIdlePlayer not found.")

	intro_narration_player = get_node_or_null(NodePath(intro_narration_player_path)) as AudioStreamPlayer

	if intro_narration_player == null:
		intro_narration_player = find_child("IntroNarrationPlayer", true, false) as AudioStreamPlayer

	if intro_narration_player == null:
		push_warning("PersistentAudioController: IntroNarrationPlayer not found.")
	else:
		fallback_intro_narration = intro_narration_player.stream

	if menu_idle_player != null and not menu_idle_player.finished.is_connected(_on_menu_idle_finished):
		menu_idle_player.finished.connect(_on_menu_idle_finished)


func _connect_language_settings() -> void:
	if not GameSettings.voice_language_changed.is_connected(
		_on_voice_language_changed
	):
		GameSettings.voice_language_changed.connect(
			_on_voice_language_changed
		)


func _on_voice_language_changed(_locale: String) -> void:
	_apply_intro_narration_language()


func _apply_intro_narration_language() -> void:
	if intro_narration_player == null:
		return

	var selected_stream: AudioStream = fallback_intro_narration
	var voice_locale: String = GameSettings.get_voice_locale()

	match voice_locale:
		GameSettings.LOCALE_BRAZILIAN_PORTUGUESE:
			if intro_narration_brazilian_portuguese != null:
				selected_stream = intro_narration_brazilian_portuguese
		_:
			if intro_narration_english != null:
				selected_stream = intro_narration_english

	if selected_stream == null:
		# No recording for this voice language: nothing is left from another one.
		if not intro_narration_player.playing:
			intro_narration_player.stream = null
		return

	if intro_narration_player.stream == selected_stream:
		return

	var was_playing: bool = intro_narration_player.playing
	var was_paused: bool = intro_narration_player.stream_paused
	var playback_position: float = (
		intro_narration_player.get_playback_position()
	)

	intro_narration_player.stream = selected_stream

	if was_playing:
		intro_narration_player.play(playback_position)
		intro_narration_player.stream_paused = was_paused


func play_menu_idle() -> void:
	if menu_idle_player == null:
		return

	menu_idle_should_loop = true

	if menu_idle_tween != null and menu_idle_tween.is_valid():
		menu_idle_tween.kill()

	menu_idle_player.volume_db = menu_idle_volume_db

	if not menu_idle_player.playing:
		menu_idle_player.play()


func fade_out_menu_idle(fade_duration: float) -> void:
	if menu_idle_player == null:
		return

	menu_idle_should_loop = false

	if menu_idle_tween != null and menu_idle_tween.is_valid():
		menu_idle_tween.kill()

	if not menu_idle_player.playing:
		return

	if fade_duration <= 0.0:
		menu_idle_player.stop()
		menu_idle_player.volume_db = menu_idle_volume_db
		return

	menu_idle_tween = create_tween()

	menu_idle_tween.tween_property(
		menu_idle_player,
		"volume_db",
		menu_idle_fade_out_db,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	menu_idle_tween.tween_callback(func() -> void:
		if menu_idle_player != null:
			menu_idle_player.stop()
			menu_idle_player.volume_db = menu_idle_volume_db
	)


func stop_menu_idle() -> void:
	if menu_idle_player == null:
		return

	menu_idle_should_loop = false

	if menu_idle_tween != null and menu_idle_tween.is_valid():
		menu_idle_tween.kill()

	menu_idle_player.stop()
	menu_idle_player.volume_db = menu_idle_volume_db


func _on_menu_idle_finished() -> void:
	if not menu_idle_should_loop:
		return

	if menu_idle_player == null:
		return

	menu_idle_player.play()


## The opening narration (Juliana's voice-over, not spatial). With a recording assigned for the voice language (`intro_narration_english` / `..._brazilian_portuguese`
## here, or a stream on the IntroNarrationPlayer), the recording's own position is the clock of the captions (cue times are seconds into the recording) and the
## narration ends with it. Without one, the caption schedule of `CaptionTracks.INTRO_NARRATION` is the clock, and it ends at its last cue. Either way the
## caption manager does the showing, and `intro_narration_finished` is raised once.
func play_intro_narration_after_delay(start_delay: float) -> void:
	narration_request_id += 1
	var current_request_id: int = narration_request_id
	_narration_running = true
	_narration_with_voice = false
	_narration_run_id = -1

	if start_delay > 0.0:
		await get_tree().create_timer(
			start_delay,
			false
		).timeout

	if current_request_id != narration_request_id:
		return

	if intro_narration_player != null and intro_narration_player.stream != null:
		_narration_with_voice = true
		intro_narration_player.volume_db = intro_narration_volume_db
		intro_narration_player.stop()
		intro_narration_player.play()
		CaptionManager.follow_player(
			CaptionTracks.INTRO_NARRATION,
			intro_narration_player
		)
		await intro_narration_player.finished
	else:
		_narration_run_id = CaptionManager.play_scripted(CaptionTracks.INTRO_NARRATION)
		while true:
			var finished_id: int = await CaptionManager.run_finished
			if finished_id == _narration_run_id or current_request_id != narration_request_id:
				break

	if current_request_id != narration_request_id:
		return

	_narration_running = false
	_narration_run_id = -1
	_release_narration_hold()
	intro_narration_finished.emit()


func stop_intro_narration() -> void:
	narration_request_id += 1
	var was_running: bool = _narration_running
	_narration_running = false
	_narration_run_id = -1
	_release_narration_hold()

	if intro_narration_player != null:
		intro_narration_player.stop()

	if was_running:
		CaptionManager.clear()
		intro_narration_finished.emit()


func is_intro_narration_running() -> bool:
	return _narration_running


## Holds the narration where it is (true), or lets it go on (false): its clock stops, and a recording is paused, so that whatever takes the frame time (the next scene
## being built) can neither eat a line nor leave the voice ahead of its captions. Whoever holds it lets it go; ending or stopping the narration lets it go too.
func hold_intro_narration(held: bool) -> void:
	if not _narration_running:
		return

	_narration_held = held
	if _narration_with_voice:
		if is_instance_valid(intro_narration_player):
			intro_narration_player.stream_paused = held
	else:
		CaptionManager.hold_clock(held)


## The menu's cinematic holds the opening of the next scene (which is already built, asleep behind it) until it hands over: the scene's own set-up may be done long
## before the cinematic is, and must not begin its opening then.
func hold_opening(held: bool) -> void:
	var was_held: bool = _opening_held
	_opening_held = held
	if was_held and not held:
		opening_released.emit()


func is_opening_held() -> bool:
	return _opening_held


func is_intro_narration_held() -> bool:
	return _narration_held and _narration_running


func _release_narration_hold() -> void:
	if not _narration_held:
		return

	_narration_held = false
	CaptionManager.hold_clock(false)
	if is_instance_valid(intro_narration_player):
		intro_narration_player.stream_paused = false


## Where the narration is, in seconds (the recording's position, or the caption schedule's clock); very large once it is over.
func get_intro_narration_seconds() -> float:
	if _narration_with_voice:
		if is_instance_valid(intro_narration_player) and intro_narration_player.playing:
			return intro_narration_player.get_playback_position()
		return 0.0

	if _narration_run_id < 0:
		return 0.0

	var seconds: float = CaptionManager.get_run_seconds(_narration_run_id)
	return seconds if seconds >= 0.0 else 100000.0


## Seconds until the last cue before the ones said in the black ends (negative once it has): the camera glide is fitted to this, and the lights fail after it.
func get_intro_narration_seconds_to_black() -> float:
	if not _narration_running:
		return 0.0

	var cues: Array = CaptionTracks.get_cues(CaptionTracks.INTRO_NARRATION)
	var index: int = CaptionTracks.INTRO_BLACK_CUE_INDEX
	var lights_at: float = float((cues[index - 1] as Dictionary)["end"]) if index > 0 and index <= cues.size() else CaptionTracks.get_length(CaptionTracks.INTRO_NARRATION)
	return lights_at - get_intro_narration_seconds()


## Seconds of the narration still to come (its caption schedule, or its recording), or 0 when it is not running.
func get_intro_narration_remaining() -> float:
	if not _narration_running:
		return 0.0

	var schedule: float = CaptionTracks.get_length(CaptionTracks.INTRO_NARRATION)
	if _narration_with_voice:
		if not is_instance_valid(intro_narration_player) or not intro_narration_player.playing:
			return 0.0

		var recording: float = intro_narration_player.stream.get_length() if intro_narration_player.stream != null else 0.0
		return maxf((recording if recording > 0.0 else schedule) - intro_narration_player.get_playback_position(), 0.0)

	if _narration_run_id < 0:
		return schedule

	return maxf(schedule - maxf(CaptionManager.get_run_seconds(_narration_run_id), 0.0), 0.0)


func set_master_volume_percent(value: float, save_after_change: bool = true) -> void:
	master_volume_percent = clampf(value, 0.0, 100.0)
	_apply_master_volume()

	if save_after_change:
		_save_master_volume()


func get_master_volume_percent() -> float:
	return master_volume_percent


func _apply_master_volume() -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")

	if master_bus_index < 0:
		push_warning("PersistentAudioController: Master audio bus not found.")
		return

	if master_volume_percent <= 0.0:
		AudioServer.set_bus_mute(master_bus_index, true)
		AudioServer.set_bus_volume_db(master_bus_index, -80.0)
		return

	AudioServer.set_bus_mute(master_bus_index, false)

	var linear_volume: float = master_volume_percent / 100.0
	var volume_db: float = linear_to_db(linear_volume)

	AudioServer.set_bus_volume_db(master_bus_index, volume_db)


func _load_master_volume() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: int = config.load(settings_file_path)

	if error == OK:
		master_volume_percent = float(config.get_value(
			settings_section_name,
			master_volume_key,
			default_master_volume_percent
		))
	else:
		master_volume_percent = default_master_volume_percent

	master_volume_percent = clampf(master_volume_percent, 0.0, 100.0)
	_apply_master_volume()


func _save_master_volume() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(settings_file_path)

	config.set_value(
		settings_section_name,
		master_volume_key,
		master_volume_percent
	)

	var error: int = config.save(settings_file_path)

	if error != OK:
		push_warning("PersistentAudioController: Could not save audio settings.")
