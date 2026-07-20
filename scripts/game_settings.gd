extends Node

signal master_volume_changed(percent: float)

const SETTINGS_PATH: String = "user://settings.cfg"

const AUDIO_SECTION: String = "audio"
const MASTER_VOLUME_KEY: String = "master_volume_percent"

const MASTER_BUS_NAME: String = "Master"
const DEFAULT_MASTER_VOLUME_PERCENT: float = 100.0

var master_volume_percent: float = (
	DEFAULT_MASTER_VOLUME_PERCENT
)


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SETTINGS_PATH)

	if load_error == OK:
		master_volume_percent = float(
			config.get_value(
				AUDIO_SECTION,
				MASTER_VOLUME_KEY,
				DEFAULT_MASTER_VOLUME_PERCENT
			)
		)
	elif load_error == ERR_FILE_NOT_FOUND:
		master_volume_percent = (
			DEFAULT_MASTER_VOLUME_PERCENT
		)
	else:
		push_warning(
			"GameSettings: Could not load settings.cfg. "
			+ "Error code: %s"
			% load_error
		)

		master_volume_percent = (
			DEFAULT_MASTER_VOLUME_PERCENT
		)

	master_volume_percent = clampf(
		master_volume_percent,
		0.0,
		100.0
	)

	_apply_master_volume()


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SETTINGS_PATH)

	if (
		load_error != OK
		and load_error != ERR_FILE_NOT_FOUND
	):
		push_warning(
			"GameSettings: Existing settings could not "
			+ "be loaded before saving. Error code: %s"
			% load_error
		)

		config = ConfigFile.new()

	config.set_value(
		AUDIO_SECTION,
		MASTER_VOLUME_KEY,
		master_volume_percent
	)

	var save_error: Error = config.save(SETTINGS_PATH)

	if save_error != OK:
		push_error(
			"GameSettings: Could not save settings.cfg. "
			+ "Error code: %s"
			% save_error
		)


func set_master_volume_percent(
	value: float,
	save_after_change: bool = true
) -> void:
	var new_value: float = clampf(
		value,
		0.0,
		100.0
	)

	if is_equal_approx(
		master_volume_percent,
		new_value
	):
		_apply_master_volume()
		return

	master_volume_percent = new_value

	_apply_master_volume()

	master_volume_changed.emit(
		master_volume_percent
	)

	if save_after_change:
		save_settings()


func get_master_volume_percent() -> float:
	return master_volume_percent


func reset_audio_to_default() -> void:
	set_master_volume_percent(
		DEFAULT_MASTER_VOLUME_PERCENT
	)


func _apply_master_volume() -> void:
	var master_bus_index: int = AudioServer.get_bus_index(
		MASTER_BUS_NAME
	)

	if master_bus_index < 0:
		push_warning(
			"GameSettings: Master audio bus was not found."
		)
		return

	var volume_linear: float = (
		master_volume_percent / 100.0
	)

	var should_mute: bool = (
		master_volume_percent <= 0.0
	)

	AudioServer.set_bus_mute(
		master_bus_index,
		should_mute
	)

	if not should_mute:
		AudioServer.set_bus_volume_db(
			master_bus_index,
			linear_to_db(volume_linear)
		)
