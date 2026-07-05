# DreamIntroAudio.gd
extends Node
class_name DreamIntroAudio

@export var menu_idle_player_path: String = "MenuIdlePlayer"
@export var intro_narration_player_path: String = "IntroNarrationPlayer"

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
var master_volume_percent: float = 100.0


func _ready() -> void:
	_find_audio_players()
	_load_master_volume()


func _find_audio_players() -> void:
	menu_idle_player = get_node_or_null(NodePath(menu_idle_player_path)) as AudioStreamPlayer

	if menu_idle_player == null:
		menu_idle_player = find_child("MenuIdlePlayer", true, false) as AudioStreamPlayer

	if menu_idle_player == null:
		push_warning("DreamIntroAudio: MenuIdlePlayer not found.")

	intro_narration_player = get_node_or_null(NodePath(intro_narration_player_path)) as AudioStreamPlayer

	if intro_narration_player == null:
		intro_narration_player = find_child("IntroNarrationPlayer", true, false) as AudioStreamPlayer

	if intro_narration_player == null:
		push_warning("DreamIntroAudio: IntroNarrationPlayer not found.")

	if menu_idle_player != null and not menu_idle_player.finished.is_connected(_on_menu_idle_finished):
		menu_idle_player.finished.connect(_on_menu_idle_finished)


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


func play_intro_narration_after_delay(start_delay: float) -> void:
	if intro_narration_player == null:
		return

	narration_request_id += 1
	var current_request_id: int = narration_request_id

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout

	if current_request_id != narration_request_id:
		return

	intro_narration_player.volume_db = intro_narration_volume_db
	intro_narration_player.stop()
	intro_narration_player.play()


func stop_intro_narration() -> void:
	narration_request_id += 1

	if intro_narration_player == null:
		return

	intro_narration_player.stop()


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
		push_warning("DreamIntroAudio: Master audio bus not found.")
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
		push_warning("DreamIntroAudio: Could not save audio settings.")
