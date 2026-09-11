extends Control
class_name SaveSlotsPanelController

signal new_game_slot_selected(slot_id: int)
signal load_game_slot_selected(slot_id: int)
signal closed

enum Mode {
	NEW_GAME,
	LOAD_GAME,
}

@onready var title_label: Label = (
	$Center/Window/Margin/Content/TitleLabel
)
@onready var subtitle_label: Label = (
	$Center/Window/Margin/Content/SubtitleLabel
)
@onready var slot_buttons: Array[Button] = [
	$Center/Window/Margin/Content/Slots/Slot1/SlotButton,
	$Center/Window/Margin/Content/Slots/Slot2/SlotButton,
	$Center/Window/Margin/Content/Slots/Slot3/SlotButton,
]
@onready var delete_buttons: Array[Button] = [
	$Center/Window/Margin/Content/Slots/Slot1/DeleteButton,
	$Center/Window/Margin/Content/Slots/Slot2/DeleteButton,
	$Center/Window/Margin/Content/Slots/Slot3/DeleteButton,
]
@onready var back_button: Button = (
	$Center/Window/Margin/Content/BackButton
)
@onready var overwrite_dialog: ConfirmationDialog = $OverwriteDialog
@onready var delete_dialog: ConfirmationDialog = $DeleteDialog
@onready var error_dialog: AcceptDialog = $ErrorDialog

var _mode: Mode = Mode.NEW_GAME
var _pending_slot_id: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	for index: int in slot_buttons.size():
		var slot_id: int = index + 1
		slot_buttons[index].pressed.connect(
			_on_slot_button_pressed.bind(slot_id)
		)
		delete_buttons[index].pressed.connect(
			_on_delete_button_pressed.bind(slot_id)
		)

	back_button.pressed.connect(close_panel)
	overwrite_dialog.confirmed.connect(_confirm_overwrite)
	delete_dialog.confirmed.connect(_confirm_delete)

	if not SaveManager.slots_changed.is_connected(_refresh_slots):
		SaveManager.slots_changed.connect(_refresh_slots)

	if not GameSettings.text_language_changed.is_connected(
		_on_text_language_changed
	):
		GameSettings.text_language_changed.connect(
			_on_text_language_changed
		)

	_refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return

	if event.is_echo():
		return

	if overwrite_dialog.visible or delete_dialog.visible or error_dialog.visible:
		return

	close_panel()
	get_viewport().set_input_as_handled()


func open_new_game() -> void:
	_mode = Mode.NEW_GAME
	_open_panel()


func open_load_game() -> void:
	_mode = Mode.LOAD_GAME
	_open_panel()


func close_panel() -> void:
	if not visible:
		return

	_pending_slot_id = -1
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


func show_save_error(message_key: StringName) -> void:
	error_dialog.title = tr("SAVE_ERROR_TITLE")
	error_dialog.dialog_text = tr(message_key)
	error_dialog.get_ok_button().text = tr("COMMON_OK")
	error_dialog.popup_centered()


func _open_panel() -> void:
	_pending_slot_id = -1
	_refresh_text()
	_refresh_slots()
	show()
	_focus_first_available_slot.call_deferred()


func _focus_first_available_slot() -> void:
	for button: Button in slot_buttons:
		if not button.disabled:
			button.grab_focus()
			return

	back_button.grab_focus()


func _refresh_text() -> void:
	if not is_node_ready():
		return

	if _mode == Mode.NEW_GAME:
		title_label.text = tr("SAVE_NEW_GAME_TITLE")
		subtitle_label.text = tr("SAVE_SELECT_NEW_GAME")
	else:
		title_label.text = tr("SAVE_LOAD_GAME_TITLE")
		subtitle_label.text = tr("SAVE_SELECT_LOAD_GAME")

	for button: Button in delete_buttons:
		button.text = tr("SAVE_DELETE")

	back_button.text = tr("COMMON_BACK")
	overwrite_dialog.title = tr("SAVE_OVERWRITE_TITLE")
	delete_dialog.title = tr("SAVE_DELETE_TITLE")
	error_dialog.title = tr("SAVE_ERROR_TITLE")
	overwrite_dialog.get_ok_button().text = tr("COMMON_CONFIRM")
	overwrite_dialog.get_cancel_button().text = tr("COMMON_CANCEL")
	delete_dialog.get_ok_button().text = tr("COMMON_CONFIRM")
	delete_dialog.get_cancel_button().text = tr("COMMON_CANCEL")
	error_dialog.get_ok_button().text = tr("COMMON_OK")

	_refresh_slots()


func _refresh_slots() -> void:
	if not is_node_ready():
		return

	var summaries: Array[Dictionary] = (
		SaveManager.get_all_slot_summaries()
	)

	for index: int in slot_buttons.size():
		var summary: Dictionary = summaries[index]
		var is_valid_save: bool = (
			bool(summary.get("exists", false))
			and bool(summary.get("valid", false))
		)
		var is_corrupt_save: bool = (
			bool(summary.get("exists", false))
			and not bool(summary.get("valid", false))
		)

		slot_buttons[index].text = _format_slot_text(summary)
		slot_buttons[index].disabled = (
			_mode == Mode.LOAD_GAME and not is_valid_save
		)
		delete_buttons[index].visible = (
			is_valid_save or is_corrupt_save
		)
		delete_buttons[index].disabled = false


func _format_slot_text(summary: Dictionary) -> String:
	var slot_id: int = int(summary.get("slot_id", 0))
	if not bool(summary.get("exists", false)):
		return tr("SAVE_SLOT_EMPTY").format({"slot": slot_id})

	if not bool(summary.get("valid", false)):
		return tr("SAVE_SLOT_CORRUPT").format({"slot": slot_id})

	var location_key: String = str(
		summary.get("location_key", "SAVE_LOCATION_UNKNOWN")
	)
	if location_key.is_empty():
		location_key = "SAVE_LOCATION_UNKNOWN"

	var updated_at: int = int(summary.get("updated_at_unix", 0))
	var date_text: String = tr("SAVE_DATE_UNKNOWN")
	if updated_at > 0:
		date_text = _format_local_date(updated_at)

	var play_time: String = _format_play_time(
		float(summary.get("play_time_seconds", 0.0))
	)
	return tr("SAVE_SLOT_OCCUPIED").format({
		"slot": slot_id,
		"location": tr(location_key),
		"date": date_text,
		"playtime": play_time,
	})


func _format_local_date(unix_time: int) -> String:
	var time_zone: Dictionary = Time.get_time_zone_from_system()
	var offset_seconds: int = int(time_zone.get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(
		unix_time + offset_seconds,
		true
	)


func _format_play_time(total_seconds: float) -> String:
	var rounded_seconds: int = maxi(int(total_seconds), 0)
	var hours: int = rounded_seconds / 3600
	var minutes: int = (rounded_seconds % 3600) / 60
	var seconds: int = rounded_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _on_slot_button_pressed(slot_id: int) -> void:
	var summary: Dictionary = SaveManager.get_slot_summary(slot_id)
	var occupied: bool = (
		bool(summary.get("exists", false))
		and bool(summary.get("valid", false))
	)

	if _mode == Mode.LOAD_GAME:
		if occupied:
			load_game_slot_selected.emit(slot_id)
		return

	if occupied or bool(summary.get("exists", false)):
		_pending_slot_id = slot_id
		overwrite_dialog.dialog_text = tr(
			"SAVE_OVERWRITE_MESSAGE"
		).format({"slot": slot_id})
		overwrite_dialog.popup_centered()
		return

	new_game_slot_selected.emit(slot_id)


func _on_delete_button_pressed(slot_id: int) -> void:
	_pending_slot_id = slot_id
	delete_dialog.dialog_text = tr("SAVE_DELETE_MESSAGE").format(
		{"slot": slot_id}
	)
	delete_dialog.popup_centered()


func _confirm_overwrite() -> void:
	if not SaveManager.is_valid_slot(_pending_slot_id):
		return

	var slot_id: int = _pending_slot_id
	_pending_slot_id = -1
	new_game_slot_selected.emit(slot_id)


func _confirm_delete() -> void:
	if not SaveManager.is_valid_slot(_pending_slot_id):
		return

	var slot_id: int = _pending_slot_id
	_pending_slot_id = -1
	var result: Error = SaveManager.delete_slot(slot_id)
	if result != OK:
		show_save_error("SAVE_ERROR_DELETE")
		return

	_refresh_slots()
	_focus_first_available_slot.call_deferred()


func _on_text_language_changed(_locale: String) -> void:
	_refresh_text()
