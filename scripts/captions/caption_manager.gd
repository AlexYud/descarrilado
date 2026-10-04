extends CanvasLayer

## Shows captions for voiced audio, in the player's caption language.
##
## Autoload "CaptionManager". To caption a track, start the audio and call
## `follow_player(track_id, player)`. The manager reads the player's playback
## position every frame, so captions stay in sync through pauses, seeking and
## voice-language changes, and clear themselves when the audio stops.
## Cue data lives in CaptionTracks.

@onready var panel: PanelContainer = $Root/Anchor/CaptionPanel
@onready var label: Label = $Root/Anchor/CaptionPanel/CaptionLabel

var _player: AudioStreamPlayer = null
var _cues: Array = []
var _shown_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

	GameSettings.captions_enabled_changed.connect(_on_settings_changed)
	GameSettings.caption_language_changed.connect(_on_settings_changed)
	GameSettings.caption_size_changed.connect(_on_size_changed)
	_apply_font_size()


## Starts following `player`: captions for `track_id` show while it plays.
func follow_player(track_id: StringName, player: AudioStreamPlayer) -> void:
	_player = player
	_cues = CaptionTracks.get_cues(track_id)
	_shown_key = ""
	set_process(true)


## Stops following the current audio and hides the caption.
func clear() -> void:
	_player = null
	_cues = []
	_hide_caption()


func _process(_delta: float) -> void:
	if _player == null:
		return

	if not is_instance_valid(_player) or not _player.playing:
		clear()
		return

	if not GameSettings.get_captions_enabled():
		_hide_caption()
		return

	var position: float = _get_playback_seconds()
	for cue: Dictionary in _cues:
		if position >= float(cue["start"]) and position < float(cue["end"]):
			_show_caption(str(cue["key"]))
			return

	_hide_caption()


## Playback position, corrected for the audio that has been mixed but not yet
## heard, so the text appears with the voice and not slightly ahead of it.
func _get_playback_seconds() -> float:
	var position: float = _player.get_playback_position()
	if not _player.stream_paused:
		position += AudioServer.get_time_since_last_mix()
		position -= AudioServer.get_output_latency()

	return maxf(position, 0.0)


func _show_caption(key: String) -> void:
	if key != _shown_key:
		_shown_key = key
		label.text = _translate(key)

	panel.visible = true


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
