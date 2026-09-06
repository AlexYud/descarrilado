extends Node

signal master_volume_changed(percent: float)
signal quality_preset_changed(preset: int)
signal display_mode_changed(mode: int)
signal window_resolution_changed(resolution: Vector2i)
signal vsync_changed(enabled: bool)
signal fps_limit_changed(limit: int)
signal brightness_changed(percent: float)
signal mouse_sensitivity_changed(percent: float)
signal invert_y_changed(enabled: bool)

enum GraphicsQuality {
	LOW,
	MEDIUM,
	HIGH,
}

enum DisplayMode {
	WINDOWED,
	FULLSCREEN,
	EXCLUSIVE_FULLSCREEN,
}

const SETTINGS_PATH: String = "user://settings.cfg"

const AUDIO_SECTION: String = "audio"
const MASTER_VOLUME_KEY: String = "master_volume_percent"

const GRAPHICS_SECTION: String = "graphics"
const QUALITY_PRESET_KEY: String = "quality_preset"
const DISPLAY_MODE_KEY: String = "display_mode"
const WINDOW_RESOLUTION_KEY: String = "window_resolution"
const VSYNC_KEY: String = "vsync_enabled"
const FPS_LIMIT_KEY: String = "fps_limit"
const BRIGHTNESS_KEY: String = "brightness_percent"

const CONTROLS_SECTION: String = "controls"
const MOUSE_SENSITIVITY_KEY: String = (
	"mouse_sensitivity_percent"
)
const INVERT_Y_KEY: String = "invert_y"

const MASTER_BUS_NAME: String = "Master"

const DEFAULT_MASTER_VOLUME_PERCENT: float = 100.0

const DEFAULT_QUALITY_PRESET: int = GraphicsQuality.HIGH
const DEFAULT_DISPLAY_MODE: int = DisplayMode.FULLSCREEN
const DEFAULT_WINDOW_RESOLUTION: Vector2i = Vector2i(
	1280,
	720
)
const DEFAULT_VSYNC_ENABLED: bool = true
const DEFAULT_FPS_LIMIT: int = 60
const DEFAULT_BRIGHTNESS_PERCENT: float = 100.0

const MIN_BRIGHTNESS_PERCENT: float = 70.0
const MAX_BRIGHTNESS_PERCENT: float = 130.0

const DEFAULT_MOUSE_SENSITIVITY_PERCENT: float = 100.0
const MIN_MOUSE_SENSITIVITY_PERCENT: float = 25.0
const MAX_MOUSE_SENSITIVITY_PERCENT: float = 200.0
const DEFAULT_INVERT_Y: bool = false

const MIN_WINDOW_RESOLUTION: Vector2i = Vector2i(
	640,
	360
)

const LOW_RENDER_SCALE: float = 0.59
const MEDIUM_RENDER_SCALE: float = 0.77
const HIGH_RENDER_SCALE: float = 1.0

const BASE_BRIGHTNESS_META: StringName = (
	&"game_settings_base_brightness"
)
const BASE_ADJUSTMENT_ENABLED_META: StringName = (
	&"game_settings_base_adjustment_enabled"
)

var master_volume_percent: float = (
	DEFAULT_MASTER_VOLUME_PERCENT
)

var quality_preset: int = DEFAULT_QUALITY_PRESET
var display_mode: int = DEFAULT_DISPLAY_MODE
var window_resolution: Vector2i = (
	DEFAULT_WINDOW_RESOLUTION
)
var vsync_enabled: bool = DEFAULT_VSYNC_ENABLED
var fps_limit: int = DEFAULT_FPS_LIMIT
var brightness_percent: float = (
	DEFAULT_BRIGHTNESS_PERCENT
)

var mouse_sensitivity_percent: float = (
	DEFAULT_MOUSE_SENSITIVITY_PERCENT
)
var invert_y: bool = DEFAULT_INVERT_Y

var tracked_world_environments: Array[WorldEnvironment] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not get_tree().node_added.is_connected(
		_on_tree_node_added
	):
		get_tree().node_added.connect(
			_on_tree_node_added
		)

	load_settings()
	call_deferred("_find_existing_world_environments")


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SETTINGS_PATH)

	_set_default_values()

	if load_error == OK:
		_load_values_from_config(config)
	elif load_error != ERR_FILE_NOT_FOUND:
		push_warning(
			"GameSettings: Could not load settings.cfg. "
			+ "Error code: %s"
			% load_error
		)

	_sanitize_values()
	_apply_all_settings()


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

	config.set_value(
		GRAPHICS_SECTION,
		QUALITY_PRESET_KEY,
		quality_preset
	)
	config.set_value(
		GRAPHICS_SECTION,
		DISPLAY_MODE_KEY,
		display_mode
	)
	config.set_value(
		GRAPHICS_SECTION,
		WINDOW_RESOLUTION_KEY,
		window_resolution
	)
	config.set_value(
		GRAPHICS_SECTION,
		VSYNC_KEY,
		vsync_enabled
	)
	config.set_value(
		GRAPHICS_SECTION,
		FPS_LIMIT_KEY,
		fps_limit
	)
	config.set_value(
		GRAPHICS_SECTION,
		BRIGHTNESS_KEY,
		brightness_percent
	)

	config.set_value(
		CONTROLS_SECTION,
		MOUSE_SENSITIVITY_KEY,
		mouse_sensitivity_percent
	)
	config.set_value(
		CONTROLS_SECTION,
		INVERT_Y_KEY,
		invert_y
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
	master_volume_changed.emit(master_volume_percent)

	if save_after_change:
		save_settings()


func get_master_volume_percent() -> float:
	return master_volume_percent


func set_quality_preset(
	value: int,
	save_after_change: bool = true
) -> void:
	var new_value: int = clampi(
		value,
		GraphicsQuality.LOW,
		GraphicsQuality.HIGH
	)

	if quality_preset == new_value:
		_apply_quality_preset()
		return

	quality_preset = new_value
	_apply_quality_preset()
	quality_preset_changed.emit(quality_preset)

	if save_after_change:
		save_settings()


func get_quality_preset() -> int:
	return quality_preset


func set_display_mode(
	value: int,
	save_after_change: bool = true
) -> void:
	var new_value: int = clampi(
		value,
		DisplayMode.WINDOWED,
		DisplayMode.EXCLUSIVE_FULLSCREEN
	)

	if display_mode == new_value:
		_apply_display_mode()
		return

	display_mode = new_value
	_apply_display_mode()
	display_mode_changed.emit(display_mode)

	if save_after_change:
		save_settings()


func get_display_mode() -> int:
	return display_mode


func set_window_resolution(
	value: Vector2i,
	save_after_change: bool = true
) -> void:
	var new_value: Vector2i = _sanitize_resolution(value)

	if window_resolution == new_value:
		if display_mode == DisplayMode.WINDOWED:
			_apply_windowed_resolution()
		return

	window_resolution = new_value

	if display_mode == DisplayMode.WINDOWED:
		_apply_windowed_resolution()

	window_resolution_changed.emit(window_resolution)

	if save_after_change:
		save_settings()


func get_window_resolution() -> Vector2i:
	return window_resolution


func set_vsync_enabled(
	value: bool,
	save_after_change: bool = true
) -> void:
	if vsync_enabled == value:
		_apply_vsync()
		return

	vsync_enabled = value
	_apply_vsync()
	vsync_changed.emit(vsync_enabled)

	if save_after_change:
		save_settings()


func get_vsync_enabled() -> bool:
	return vsync_enabled


func set_fps_limit(
	value: int,
	save_after_change: bool = true
) -> void:
	var new_value: int = maxi(value, 0)

	if fps_limit == new_value:
		_apply_fps_limit()
		return

	fps_limit = new_value
	_apply_fps_limit()
	fps_limit_changed.emit(fps_limit)

	if save_after_change:
		save_settings()


func get_fps_limit() -> int:
	return fps_limit


func set_brightness_percent(
	value: float,
	save_after_change: bool = true
) -> void:
	var new_value: float = clampf(
		value,
		MIN_BRIGHTNESS_PERCENT,
		MAX_BRIGHTNESS_PERCENT
	)

	if is_equal_approx(brightness_percent, new_value):
		_apply_brightness()
		return

	brightness_percent = new_value
	_apply_brightness()
	brightness_changed.emit(brightness_percent)

	if save_after_change:
		save_settings()


func get_brightness_percent() -> float:
	return brightness_percent


func set_mouse_sensitivity_percent(
	value: float,
	save_after_change: bool = true
) -> void:
	var new_value: float = clampf(
		value,
		MIN_MOUSE_SENSITIVITY_PERCENT,
		MAX_MOUSE_SENSITIVITY_PERCENT
	)

	if is_equal_approx(
		mouse_sensitivity_percent,
		new_value
	):
		return

	mouse_sensitivity_percent = new_value
	mouse_sensitivity_changed.emit(
		mouse_sensitivity_percent
	)

	if save_after_change:
		save_settings()


func get_mouse_sensitivity_percent() -> float:
	return mouse_sensitivity_percent


func get_mouse_sensitivity_multiplier() -> float:
	return mouse_sensitivity_percent / 100.0


func set_invert_y(
	value: bool,
	save_after_change: bool = true
) -> void:
	if invert_y == value:
		return

	invert_y = value
	invert_y_changed.emit(invert_y)

	if save_after_change:
		save_settings()


func get_invert_y() -> bool:
	return invert_y


func reset_audio_to_default() -> void:
	set_master_volume_percent(
		DEFAULT_MASTER_VOLUME_PERCENT
	)


func reset_graphics_to_default() -> void:
	quality_preset = DEFAULT_QUALITY_PRESET
	display_mode = DEFAULT_DISPLAY_MODE
	window_resolution = DEFAULT_WINDOW_RESOLUTION
	vsync_enabled = DEFAULT_VSYNC_ENABLED
	fps_limit = DEFAULT_FPS_LIMIT
	brightness_percent = DEFAULT_BRIGHTNESS_PERCENT

	_apply_quality_preset()
	_apply_display_mode()
	_apply_vsync()
	_apply_fps_limit()
	_apply_brightness()

	quality_preset_changed.emit(quality_preset)
	display_mode_changed.emit(display_mode)
	window_resolution_changed.emit(window_resolution)
	vsync_changed.emit(vsync_enabled)
	fps_limit_changed.emit(fps_limit)
	brightness_changed.emit(brightness_percent)

	save_settings()


func reset_controls_to_default() -> void:
	mouse_sensitivity_percent = (
		DEFAULT_MOUSE_SENSITIVITY_PERCENT
	)
	invert_y = DEFAULT_INVERT_Y

	mouse_sensitivity_changed.emit(
		mouse_sensitivity_percent
	)
	invert_y_changed.emit(invert_y)

	save_settings()


func _set_default_values() -> void:
	master_volume_percent = DEFAULT_MASTER_VOLUME_PERCENT

	quality_preset = DEFAULT_QUALITY_PRESET
	display_mode = DEFAULT_DISPLAY_MODE
	window_resolution = DEFAULT_WINDOW_RESOLUTION
	vsync_enabled = DEFAULT_VSYNC_ENABLED
	fps_limit = DEFAULT_FPS_LIMIT
	brightness_percent = DEFAULT_BRIGHTNESS_PERCENT

	mouse_sensitivity_percent = (
		DEFAULT_MOUSE_SENSITIVITY_PERCENT
	)
	invert_y = DEFAULT_INVERT_Y


func _load_values_from_config(config: ConfigFile) -> void:
	master_volume_percent = float(
		config.get_value(
			AUDIO_SECTION,
			MASTER_VOLUME_KEY,
			DEFAULT_MASTER_VOLUME_PERCENT
		)
	)

	quality_preset = int(
		config.get_value(
			GRAPHICS_SECTION,
			QUALITY_PRESET_KEY,
			DEFAULT_QUALITY_PRESET
		)
	)
	display_mode = int(
		config.get_value(
			GRAPHICS_SECTION,
			DISPLAY_MODE_KEY,
			DEFAULT_DISPLAY_MODE
		)
	)

	var saved_resolution: Variant = config.get_value(
		GRAPHICS_SECTION,
		WINDOW_RESOLUTION_KEY,
		DEFAULT_WINDOW_RESOLUTION
	)

	if saved_resolution is Vector2i:
		window_resolution = saved_resolution
	elif saved_resolution is Vector2:
		window_resolution = Vector2i(saved_resolution)

	vsync_enabled = bool(
		config.get_value(
			GRAPHICS_SECTION,
			VSYNC_KEY,
			DEFAULT_VSYNC_ENABLED
		)
	)
	fps_limit = int(
		config.get_value(
			GRAPHICS_SECTION,
			FPS_LIMIT_KEY,
			DEFAULT_FPS_LIMIT
		)
	)
	brightness_percent = float(
		config.get_value(
			GRAPHICS_SECTION,
			BRIGHTNESS_KEY,
			DEFAULT_BRIGHTNESS_PERCENT
		)
	)

	mouse_sensitivity_percent = float(
		config.get_value(
			CONTROLS_SECTION,
			MOUSE_SENSITIVITY_KEY,
			DEFAULT_MOUSE_SENSITIVITY_PERCENT
		)
	)
	invert_y = bool(
		config.get_value(
			CONTROLS_SECTION,
			INVERT_Y_KEY,
			DEFAULT_INVERT_Y
		)
	)


func _sanitize_values() -> void:
	master_volume_percent = clampf(
		master_volume_percent,
		0.0,
		100.0
	)

	quality_preset = clampi(
		quality_preset,
		GraphicsQuality.LOW,
		GraphicsQuality.HIGH
	)
	display_mode = clampi(
		display_mode,
		DisplayMode.WINDOWED,
		DisplayMode.EXCLUSIVE_FULLSCREEN
	)
	window_resolution = _sanitize_resolution(
		window_resolution
	)
	fps_limit = maxi(fps_limit, 0)
	brightness_percent = clampf(
		brightness_percent,
		MIN_BRIGHTNESS_PERCENT,
		MAX_BRIGHTNESS_PERCENT
	)

	mouse_sensitivity_percent = clampf(
		mouse_sensitivity_percent,
		MIN_MOUSE_SENSITIVITY_PERCENT,
		MAX_MOUSE_SENSITIVITY_PERCENT
	)


func _sanitize_resolution(value: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(value.x, MIN_WINDOW_RESOLUTION.x),
		maxi(value.y, MIN_WINDOW_RESOLUTION.y)
	)


func _apply_all_settings() -> void:
	_apply_master_volume()
	_apply_quality_preset()
	_apply_display_mode()
	_apply_vsync()
	_apply_fps_limit()
	_apply_brightness()


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


func _apply_quality_preset() -> void:
	var root_viewport: Viewport = get_tree().root

	root_viewport.scaling_3d_mode = (
		Viewport.SCALING_3D_MODE_FSR
	)

	match quality_preset:
		GraphicsQuality.LOW:
			root_viewport.scaling_3d_scale = (
				LOW_RENDER_SCALE
			)
		GraphicsQuality.MEDIUM:
			root_viewport.scaling_3d_scale = (
				MEDIUM_RENDER_SCALE
			)
		_:
			root_viewport.scaling_3d_scale = (
				HIGH_RENDER_SCALE
			)


func _apply_display_mode() -> void:
	match display_mode:
		DisplayMode.WINDOWED:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED
			)
			DisplayServer.window_set_flag(
				DisplayServer.WINDOW_FLAG_BORDERLESS,
				false
			)
			_apply_windowed_resolution()

		DisplayMode.EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			)

		_:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN
			)


func _apply_windowed_resolution() -> void:
	var current_screen: int = (
		DisplayServer.window_get_current_screen()
	)
	var usable_rect: Rect2i = (
		DisplayServer.screen_get_usable_rect(
			current_screen
		)
	)
	var safe_size: Vector2i = Vector2i(
		mini(window_resolution.x, usable_rect.size.x),
		mini(window_resolution.y, usable_rect.size.y)
	)

	DisplayServer.window_set_size(safe_size)

	var centered_position: Vector2i = (
		usable_rect.position
		+ Vector2i(
			int(
				(usable_rect.size.x - safe_size.x)
				/ 2.0
			),
			int(
				(usable_rect.size.y - safe_size.y)
				/ 2.0
			)
		)
	)

	DisplayServer.window_set_position(centered_position)


func _apply_vsync() -> void:
	var vsync_mode: int = (
		DisplayServer.VSYNC_ENABLED
		if vsync_enabled
		else DisplayServer.VSYNC_DISABLED
	)

	DisplayServer.window_set_vsync_mode(vsync_mode)


func _apply_fps_limit() -> void:
	Engine.max_fps = fps_limit


func _on_tree_node_added(node: Node) -> void:
	var world_environment: WorldEnvironment = (
		node as WorldEnvironment
	)

	if world_environment == null:
		return

	_register_world_environment(world_environment)


func _find_existing_world_environments() -> void:
	_find_world_environments_recursive(get_tree().root)


func _find_world_environments_recursive(node: Node) -> void:
	var world_environment: WorldEnvironment = (
		node as WorldEnvironment
	)

	if world_environment != null:
		_register_world_environment(world_environment)

	for child: Node in node.get_children():
		_find_world_environments_recursive(child)


func _register_world_environment(
	world_environment: WorldEnvironment
) -> void:
	if tracked_world_environments.has(world_environment):
		return

	tracked_world_environments.append(world_environment)

	world_environment.tree_exited.connect(
		_on_world_environment_tree_exited.bind(
			world_environment
		),
		CONNECT_ONE_SHOT
	)

	call_deferred(
		"_apply_brightness_to_world_environment",
		world_environment
	)


func _on_world_environment_tree_exited(
	world_environment: WorldEnvironment
) -> void:
	tracked_world_environments.erase(world_environment)


func _apply_brightness() -> void:
	var index: int = tracked_world_environments.size() - 1

	while index >= 0:
		var world_environment: WorldEnvironment = (
			tracked_world_environments[index]
		)

		if not is_instance_valid(world_environment):
			tracked_world_environments.remove_at(index)
		else:
			_apply_brightness_to_world_environment(
				world_environment
			)

		index -= 1


func _apply_brightness_to_world_environment(
	world_environment: WorldEnvironment
) -> void:
	if not is_instance_valid(world_environment):
		return

	var environment: Environment = (
		world_environment.environment
	)

	if environment == null:
		return

	if not environment.has_meta(BASE_BRIGHTNESS_META):
		environment.set_meta(
			BASE_BRIGHTNESS_META,
			environment.adjustment_brightness
		)

	if not environment.has_meta(
		BASE_ADJUSTMENT_ENABLED_META
	):
		environment.set_meta(
			BASE_ADJUSTMENT_ENABLED_META,
			environment.adjustment_enabled
		)

	var base_brightness: float = float(
		environment.get_meta(BASE_BRIGHTNESS_META)
	)
	var base_adjustment_enabled: bool = bool(
		environment.get_meta(
			BASE_ADJUSTMENT_ENABLED_META
		)
	)
	var brightness_multiplier: float = (
		brightness_percent / 100.0
	)

	environment.adjustment_brightness = (
		base_brightness * brightness_multiplier
	)
	environment.adjustment_enabled = (
		base_adjustment_enabled
		or not is_equal_approx(
			brightness_multiplier,
			1.0
		)
	)
