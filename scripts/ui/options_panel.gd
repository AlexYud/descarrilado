extends Control
class_name OptionsPanelController

signal back_requested

@onready var master_volume_slider: HSlider = (
	$OptionsMargin
	/OptionsVBox
	/OptionsTabs
	/Audio
	/AudioVBox
	/MasterVolumeRow
	/MasterVolumeSlider
)

@onready var back_button: Button = (
	$OptionsMargin
	/OptionsVBox
	/OptionsBackButton
)

var syncing_controls: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	master_volume_slider.min_value = 0.0
	master_volume_slider.max_value = 100.0
	master_volume_slider.step = 1.0

	if not master_volume_slider.value_changed.is_connected(
		_on_master_volume_slider_changed
	):
		master_volume_slider.value_changed.connect(
			_on_master_volume_slider_changed
		)

	if not master_volume_slider.drag_ended.is_connected(
		_on_master_volume_drag_ended
	):
		master_volume_slider.drag_ended.connect(
			_on_master_volume_drag_ended
		)

	if not back_button.pressed.is_connected(
		_on_back_button_pressed
	):
		back_button.pressed.connect(
			_on_back_button_pressed
		)

	if not GameSettings.master_volume_changed.is_connected(
		_on_saved_master_volume_changed
	):
		GameSettings.master_volume_changed.connect(
			_on_saved_master_volume_changed
		)

	_sync_controls_from_settings()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_request_back()
		get_viewport().set_input_as_handled()


func open() -> void:
	_sync_controls_from_settings()
	show()

	master_volume_slider.grab_focus()


func close() -> void:
	GameSettings.save_settings()
	hide()


func is_open() -> bool:
	return visible


func _sync_controls_from_settings() -> void:
	syncing_controls = true

	master_volume_slider.value = (
		GameSettings.get_master_volume_percent()
	)

	syncing_controls = false


func _on_master_volume_slider_changed(
	value: float
) -> void:
	if syncing_controls:
		return

	GameSettings.set_master_volume_percent(
		value,
		false
	)


func _on_master_volume_drag_ended(
	value_changed: bool
) -> void:
	if not value_changed:
		return

	GameSettings.save_settings()


func _on_saved_master_volume_changed(
	percent: float
) -> void:
	if syncing_controls:
		return

	if is_equal_approx(
		master_volume_slider.value,
		percent
	):
		return

	syncing_controls = true
	master_volume_slider.value = percent
	syncing_controls = false


func _on_back_button_pressed() -> void:
	_request_back()


func _request_back() -> void:
	GameSettings.save_settings()
	back_requested.emit()
