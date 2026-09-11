extends Node

## Versioned, slot-based persistence service.
##
## Gameplay systems should save semantic state under stable IDs (for example,
## `puzzles/generator_room`) instead of serializing scene nodes directly.

signal slots_changed
signal active_slot_changed(slot_id: int)
signal save_completed(slot_id: int, success: bool)
signal save_loaded(slot_id: int, save_data: Dictionary)

const FORMAT_VERSION := 1
const SLOT_COUNT := 3
const NO_ACTIVE_SLOT := -1

const DEFAULT_SCENE_PATH := (
	"res://scenes/cinematics/dream_intro.tscn"
)
const DEFAULT_CHECKPOINT_ID := "dream_intro_start"
const DEFAULT_LOCATION_KEY := "SAVE_LOCATION_DREAM_INTRO"

## Kept configurable so automated tests can use an isolated directory.
var save_directory: String = "user://saves"

var _active_slot_id: int = NO_ACTIVE_SLOT
var _current_save_data: Dictionary = {}
var _session_active: bool = false


func _process(delta: float) -> void:
	if not _session_active or get_tree().paused:
		return

	_current_save_data["play_time_seconds"] = (
		float(_current_save_data.get("play_time_seconds", 0.0))
		+ delta
	)


func is_valid_slot(slot_id: int) -> bool:
	return slot_id >= 1 and slot_id <= SLOT_COUNT


func has_slot(slot_id: int) -> bool:
	if not is_valid_slot(slot_id):
		return false

	return not _read_slot_data(slot_id).is_empty()


func has_any_save() -> bool:
	for slot_id: int in range(1, SLOT_COUNT + 1):
		if has_slot(slot_id):
			return true

	return false


func get_slot_summary(slot_id: int) -> Dictionary:
	var summary := {
		"slot_id": slot_id,
		"exists": false,
		"valid": is_valid_slot(slot_id),
		"created_at_unix": 0,
		"updated_at_unix": 0,
		"play_time_seconds": 0.0,
		"scene_path": "",
		"checkpoint_id": "",
		"location_key": "",
	}

	if not is_valid_slot(slot_id):
		return summary

	var primary_exists: bool = FileAccess.file_exists(
		_get_slot_path(slot_id)
	)
	var backup_exists: bool = FileAccess.file_exists(
		_get_backup_path(slot_id)
	)

	if not primary_exists and not backup_exists:
		return summary

	var save_data: Dictionary = _read_slot_data(slot_id)
	if save_data.is_empty():
		summary["exists"] = true
		summary["valid"] = false
		return summary

	summary["exists"] = true
	summary["created_at_unix"] = int(
		save_data.get("created_at_unix", 0)
	)
	summary["updated_at_unix"] = int(
		save_data.get("updated_at_unix", 0)
	)
	summary["play_time_seconds"] = float(
		save_data.get("play_time_seconds", 0.0)
	)
	summary["scene_path"] = str(save_data.get("scene_path", ""))
	summary["checkpoint_id"] = str(
		save_data.get("checkpoint_id", "")
	)
	summary["location_key"] = str(
		save_data.get("location_key", "")
	)
	return summary


func get_all_slot_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []

	for slot_id: int in range(1, SLOT_COUNT + 1):
		summaries.append(get_slot_summary(slot_id))

	return summaries


func create_new_game(
	slot_id: int,
	initial_scene_path: String = DEFAULT_SCENE_PATH,
	checkpoint_id: String = DEFAULT_CHECKPOINT_ID,
	location_key: String = DEFAULT_LOCATION_KEY
) -> Error:
	if not is_valid_slot(slot_id):
		return ERR_INVALID_PARAMETER

	var clean_scene_path: String = initial_scene_path.strip_edges()
	if (
		clean_scene_path.is_empty()
		or not ResourceLoader.exists(clean_scene_path, "PackedScene")
	):
		return ERR_INVALID_PARAMETER

	var now_unix: int = int(Time.get_unix_time_from_system())
	var new_save := {
		"format_version": FORMAT_VERSION,
		"slot_id": slot_id,
		"created_at_unix": now_unix,
		"updated_at_unix": now_unix,
		"play_time_seconds": 0.0,
		"scene_path": clean_scene_path,
		"checkpoint_id": checkpoint_id,
		"location_key": location_key,
		"state": {
			"puzzles": {},
			"triggers": {},
			"collectibles": {},
			"player": {},
		},
	}

	var result: Error = _write_slot_data(slot_id, new_save)
	if result != OK:
		save_completed.emit(slot_id, false)
		return result

	_active_slot_id = slot_id
	_current_save_data = new_save.duplicate(true)
	_session_active = true
	active_slot_changed.emit(slot_id)
	save_completed.emit(slot_id, true)
	slots_changed.emit()
	return OK


func load_slot(slot_id: int) -> Dictionary:
	if not is_valid_slot(slot_id):
		return {}

	var save_data: Dictionary = _read_slot_data(slot_id)
	if save_data.is_empty():
		return {}

	_active_slot_id = slot_id
	_current_save_data = save_data.duplicate(true)
	_session_active = true
	active_slot_changed.emit(slot_id)
	save_loaded.emit(slot_id, _current_save_data.duplicate(true))
	return _current_save_data.duplicate(true)


func delete_slot(slot_id: int) -> Error:
	if not is_valid_slot(slot_id):
		return ERR_INVALID_PARAMETER

	var first_error: Error = OK
	for path: String in [
		_get_slot_path(slot_id),
		_get_temporary_path(slot_id),
		_get_backup_path(slot_id),
	]:
		if not FileAccess.file_exists(path):
			continue

		var remove_error: Error = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(path)
		)
		if remove_error != OK and first_error == OK:
			first_error = remove_error

	if first_error != OK:
		return first_error

	if _active_slot_id == slot_id:
		_clear_active_session()

	slots_changed.emit()
	return OK


func save_checkpoint(
	scene_path: String,
	checkpoint_id: String,
	location_key: String,
	state_patch: Dictionary = {}
) -> Error:
	if not has_active_game():
		return ERR_DOES_NOT_EXIST

	var clean_scene_path: String = scene_path.strip_edges()
	var clean_checkpoint_id: String = checkpoint_id.strip_edges()
	if (
		clean_scene_path.is_empty()
		or clean_checkpoint_id.is_empty()
		or not ResourceLoader.exists(clean_scene_path, "PackedScene")
	):
		return ERR_INVALID_PARAMETER

	if not state_patch.is_empty():
		if not _is_json_safe(state_patch):
			return ERR_INVALID_DATA

		var current_state: Dictionary = _get_or_create_state()
		_merge_dictionary_recursive(current_state, state_patch)

	_current_save_data["scene_path"] = clean_scene_path
	_current_save_data["checkpoint_id"] = clean_checkpoint_id
	_current_save_data["location_key"] = location_key
	return save_active_game()


func save_manual_game(
	scene_path: String,
	player_state: Dictionary
) -> Error:
	if not has_active_game():
		return ERR_DOES_NOT_EXIST

	var clean_scene_path: String = scene_path.strip_edges()
	if (
		clean_scene_path.is_empty()
		or not ResourceLoader.exists(clean_scene_path, "PackedScene")
		or not _is_json_safe(player_state)
	):
		return ERR_INVALID_DATA

	var state: Dictionary = _get_or_create_state()
	var player_section_value: Variant = state.get("player", {})
	var player_section: Dictionary = {}
	if player_section_value is Dictionary:
		player_section = player_section_value as Dictionary

	player_section["manual_snapshot"] = {
		"scene_path": clean_scene_path,
		"captured_at_unix": int(Time.get_unix_time_from_system()),
		"data": player_state.duplicate(true),
	}
	state["player"] = player_section
	_current_save_data["scene_path"] = clean_scene_path
	return save_active_game()


func has_manual_snapshot_for_scene(scene_path: String) -> bool:
	return not get_manual_player_state(scene_path).is_empty()


func get_manual_player_state(scene_path: String) -> Dictionary:
	if not has_active_game():
		return {}

	var state: Dictionary = _get_state_for_reading()
	var player_section_value: Variant = state.get("player", {})
	if not player_section_value is Dictionary:
		return {}

	var player_section: Dictionary = (
		player_section_value as Dictionary
	)
	var snapshot_value: Variant = player_section.get(
		"manual_snapshot",
		{}
	)
	if not snapshot_value is Dictionary:
		return {}

	var snapshot: Dictionary = snapshot_value as Dictionary
	if str(snapshot.get("scene_path", "")) != scene_path.strip_edges():
		return {}

	var data_value: Variant = snapshot.get("data", {})
	if not data_value is Dictionary:
		return {}

	return (data_value as Dictionary).duplicate(true)


func save_active_game() -> Error:
	if not has_active_game():
		return ERR_DOES_NOT_EXIST

	_current_save_data["updated_at_unix"] = int(
		Time.get_unix_time_from_system()
	)

	var result: Error = _write_slot_data(
		_active_slot_id,
		_current_save_data
	)
	save_completed.emit(_active_slot_id, result == OK)

	if result == OK:
		slots_changed.emit()

	return result


func suspend_session(save_progress: bool = true) -> Error:
	var result: Error = OK
	if save_progress and has_active_game():
		result = save_active_game()

	_clear_active_session()
	return result


func has_active_game() -> bool:
	return (
		_session_active
		and is_valid_slot(_active_slot_id)
		and not _current_save_data.is_empty()
	)


func get_active_slot_id() -> int:
	return _active_slot_id


func get_active_save_data() -> Dictionary:
	return _current_save_data.duplicate(true)


func get_active_checkpoint_id() -> String:
	return str(_current_save_data.get("checkpoint_id", ""))


func set_state_value(
	section: StringName,
	persistent_id: StringName,
	value: Variant
) -> Error:
	if not has_active_game():
		return ERR_DOES_NOT_EXIST

	if String(section).is_empty() or String(persistent_id).is_empty():
		return ERR_INVALID_PARAMETER

	if not _is_json_safe(value):
		return ERR_INVALID_DATA

	var state: Dictionary = _get_or_create_state()
	var section_key: String = String(section)
	var section_value: Variant = state.get(section_key, {})
	var section_data: Dictionary = {}
	if section_value is Dictionary:
		section_data = section_value as Dictionary
	section_data[String(persistent_id)] = value
	state[section_key] = section_data
	return OK


func get_state_value(
	section: StringName,
	persistent_id: StringName,
	default_value: Variant = null
) -> Variant:
	var state: Dictionary = _get_state_for_reading()
	var section_value: Variant = state.get(String(section), {})
	if not section_value is Dictionary:
		return default_value

	var section_data: Dictionary = section_value as Dictionary
	return section_data.get(String(persistent_id), default_value)


func has_state_value(
	section: StringName,
	persistent_id: StringName
) -> bool:
	var state: Dictionary = _get_state_for_reading()
	var section_value: Variant = state.get(String(section), {})
	if not section_value is Dictionary:
		return false

	var section_data: Dictionary = section_value as Dictionary
	return section_data.has(String(persistent_id))


func get_state_section(section: StringName) -> Dictionary:
	var state: Dictionary = _get_state_for_reading()
	var section_value: Variant = state.get(String(section), {})
	if not section_value is Dictionary:
		return {}

	var section_data: Dictionary = section_value as Dictionary
	return section_data.duplicate(true)


func _clear_active_session() -> void:
	var previous_slot_id: int = _active_slot_id
	_active_slot_id = NO_ACTIVE_SLOT
	_current_save_data.clear()
	_session_active = false

	if previous_slot_id != NO_ACTIVE_SLOT:
		active_slot_changed.emit(NO_ACTIVE_SLOT)


func _get_or_create_state() -> Dictionary:
	var state_value: Variant = _current_save_data.get("state", {})
	if state_value is Dictionary:
		return state_value as Dictionary

	var state: Dictionary = {}
	_current_save_data["state"] = state
	return state


func _get_state_for_reading() -> Dictionary:
	var state_value: Variant = _current_save_data.get("state", {})
	if state_value is Dictionary:
		return state_value as Dictionary

	return {}


func _read_slot_data(slot_id: int) -> Dictionary:
	if not is_valid_slot(slot_id):
		return {}

	var primary_data: Dictionary = _read_and_validate_file(
		_get_slot_path(slot_id),
		slot_id
	)
	if not primary_data.is_empty():
		return primary_data

	return _read_and_validate_file(
		_get_backup_path(slot_id),
		slot_id
	)


func _read_and_validate_file(
	path: String,
	expected_slot_id: int
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		return {}

	var save_data: Dictionary = parsed as Dictionary
	return _migrate_and_validate(save_data, expected_slot_id)


func _migrate_and_validate(
	save_data: Dictionary,
	expected_slot_id: int
) -> Dictionary:
	var version: int = int(save_data.get("format_version", 0))
	if version != FORMAT_VERSION:
		return {}

	if int(save_data.get("slot_id", NO_ACTIVE_SLOT)) != expected_slot_id:
		return {}

	var required_keys: Array[String] = [
		"created_at_unix",
		"updated_at_unix",
		"play_time_seconds",
		"scene_path",
		"checkpoint_id",
		"location_key",
		"state",
	]
	for key: String in required_keys:
		if not save_data.has(key):
			return {}

	if str(save_data["scene_path"]).strip_edges().is_empty():
		return {}

	if not save_data["state"] is Dictionary:
		return {}

	return save_data


func _write_slot_data(slot_id: int, save_data: Dictionary) -> Error:
	if not is_valid_slot(slot_id) or not _is_json_safe(save_data):
		return ERR_INVALID_DATA

	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(save_directory)
	)
	if directory_error != OK:
		return directory_error

	var temporary_path: String = _get_temporary_path(slot_id)
	var slot_path: String = _get_slot_path(slot_id)
	var backup_path: String = _get_backup_path(slot_id)
	var temporary_file: FileAccess = FileAccess.open(
		temporary_path,
		FileAccess.WRITE
	)
	if temporary_file == null:
		return FileAccess.get_open_error()

	temporary_file.store_string(JSON.stringify(save_data, "\t"))
	temporary_file.flush()
	temporary_file.close()

	if _read_and_validate_file(temporary_path, slot_id).is_empty():
		_remove_file_if_present(temporary_path)
		return ERR_FILE_CORRUPT

	_remove_file_if_present(backup_path)
	var had_previous_save: bool = FileAccess.file_exists(slot_path)
	if had_previous_save:
		var backup_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(slot_path),
			ProjectSettings.globalize_path(backup_path)
		)
		if backup_error != OK:
			_remove_file_if_present(temporary_path)
			return backup_error

	var promote_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(slot_path)
	)
	if promote_error != OK:
		if had_previous_save:
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(backup_path),
				ProjectSettings.globalize_path(slot_path)
			)
		_remove_file_if_present(temporary_path)
		return promote_error

	_remove_file_if_present(backup_path)
	return OK


func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _merge_dictionary_recursive(
	target: Dictionary,
	patch: Dictionary
) -> void:
	for key: Variant in patch:
		var patch_value: Variant = patch[key]
		if (
			patch_value is Dictionary
			and target.get(key) is Dictionary
		):
			_merge_dictionary_recursive(
				target[key] as Dictionary,
				patch_value as Dictionary
			)
		else:
			target[key] = patch_value


func _is_json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item: Variant in value as Array:
				if not _is_json_safe(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value as Dictionary:
				if not key is String:
					return false
				if not _is_json_safe((value as Dictionary)[key]):
					return false
			return true
		_:
			return false


func _get_slot_path(slot_id: int) -> String:
	return save_directory.path_join("slot_%02d.json" % slot_id)


func _get_temporary_path(slot_id: int) -> String:
	return _get_slot_path(slot_id) + ".tmp"


func _get_backup_path(slot_id: int) -> String:
	return _get_slot_path(slot_id) + ".bak"
