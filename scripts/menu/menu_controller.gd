extends Node


# ============================================================
# FIXED MENU SCENE PATHS
# ============================================================

const MENU_CAMERA_PATH := NodePath(
	"StationaryTrain/MenuCameraRig/"
	+ "CameraImpactPivot/MenuCamera"
)

const CAMERA_ANIMATION_PLAYER_PATH := NodePath(
	"StationaryTrain/MenuCameraRig/"
	+ "CameraAnimationPlayer"
)

## Contains the five stationary wagon instances.
const STATIONARY_TRAIN_PATH := NodePath(
	"StationaryTrain"
)

## Moves to create the illusion that the train is travelling.
const SCENERY_LOOP_PATH := NodePath(
	"SceneryLoop"
)

const BLACKOUT_RECT_PATH := NodePath(
	"TransitionBlackout/BlackoutRect"
)

const MAIN_MENU_UI_PATH := NodePath(
	"UI/MainMenuUI"
)

const LEFT_PANEL_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel"
)

const TITLE_LABEL_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/TitleLabel"
)

const NEW_GAME_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/NewGameButton"
)

const LOAD_GAME_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/LoadGameButton"
)

const OPTIONS_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/OptionsButton"
)

const QUIT_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/LeftPanel/MenuColumn/MenuMargin/"
	+ "VBoxContainer/QuitButton"
)

const OPTIONS_PANEL_PATH := NodePath(
	"UI/MainMenuUI/OptionsPanel"
)

const SAVE_SLOTS_PANEL_PATH := NodePath(
	"UI/MainMenuUI/SaveSlotsPanel"
)

const OPTIONS_BACK_BUTTON_PATH := NodePath(
	"UI/MainMenuUI/OptionsPanel/OptionsMargin/"
	+ "OptionsVBox/OptionsBackButton"
)

const MASTER_VOLUME_SLIDER_PATH := NodePath(
	"UI/MainMenuUI/OptionsPanel/OptionsMargin/"
	+ "OptionsVBox/OptionsTabs/Audio/AudioVBox/"
	+ "MasterVolumeRow/MasterVolumeSlider"
)

const CINEMATIC_SKIP_PROMPT_PATH := NodePath(
	"CinematicHUD/SkipPrompt"
)

const CINEMATIC_SKIP_PROGRESS_PATH := NodePath(
	"CinematicHUD/SkipPrompt/SkipMargin/SkipVBox/"
	+ "SkipProgress"
)

const CINEMATIC_LOADING_LABEL_PATH := NodePath(
	"LoadingHUD/LoadingLabel"
)

const PERSISTENT_AUDIO_NAME := "PersistentAudio"
const HORROR_FILTER_SCENE := "res://scenes/ui/filters/horror_filter.tscn"


# ============================================================
# AUDIO
# ============================================================

@export_category("Audio")

@export var play_menu_idle_audio: bool = true
@export var menu_idle_fade_out_duration: float = 2.0

@export var play_intro_narration: bool = true
## The narration clock starts this long after Start (keep it 0: the cue schedule counts from the click; a later start only makes the narration end later than the camera).
@export var intro_narration_start_delay: float = 0.0
@export var intro_narration_volume_db: float = -10.0
## The narration (the recording, or the caption schedule while there is none) is the clock of the opening: the camera glide is slowed so that it ends this long after the
## last line said before the blackout (the cue before `CaptionTracks.INTRO_BLACK_CUE_INDEX`), with only the train's own sound in that time, and the lights fail then. The
## last sentence is said in the black, which is the next scene's (the narration is held while it loads, and the next scene lets it go when it is ready and waits for
## its last word before it begins). The glide is never made faster than its own speed.
@export var intro_ambient_tail_seconds: float = 2.5
@export_range(0.1, 1.0, 0.05) var intro_min_speed_scale: float = 0.2


# ============================================================
# RESPONSIVE UI
# ============================================================

@export_category("Responsive UI")

@export var reference_resolution: Vector2 = Vector2(
	1920.0,
	1080.0
)

@export var title_base_font_size: int = 120
@export var button_base_font_size: int = 32

@export var min_ui_scale: float = 0.85
@export var max_ui_scale: float = 1.35


# ============================================================
# CAMERA CUTSCENES
# ============================================================

@export_category("Camera Cutscenes")

@export var intro_animation_name: StringName = &"Intro"

## Keep this spelling identical to your animation.
@export var brake_animation_name: StringName = &"BreakDip"

@export var play_brake_animation: bool = true

@export var menu_fade_duration: float = 2.0
@export var intro_animation_start_delay: float = 0.0


# ============================================================
# TRAIN MALFUNCTION
# ============================================================

@export_category("Train Stop Sequence")

## Controls how quickly the moving scenery stops.
@export var train_slowdown_duration: float = 0.8

## Panic flickering begins together with BreakDip.
@export var blackout_during_slowdown_delay: float = 0.20

## Duration of the final wagon-light flicker.
@export var blackout_final_flicker_duration: float = 0.35

## Fast blackout that resembles a light pulse.
@export var screen_blackout_fade_duration: float = 0.06

## Brief fully black pause before DreamIntro loads.
@export var screen_blackout_hold_duration: float = 0.05


# ============================================================
# PLAYABLE SCENE
# ============================================================

@export_category("Playable Scene")

@export var change_scene_after_animation: bool = true

## The next scene is built when the main menu is first shown, behind a loading screen (a few seconds: nothing can be drawn while it is built), and this menu then runs in a
## viewport over it. Start is then smooth (the menu fades out over the train, the cinematic begins) and at the end of the cinematic the viewport is taken away and the
## scene is already there, so nothing is built after Start or after the crash. False: the old way (nothing built beforehand, a few seconds of black after the crash).
@export var build_scene_before_cinematic: bool = true
@export var menu_reveal_seconds: float = 0.8

@export_file("*.tscn")
var playable_scene_path: String = (
	"res://scenes/cinematics/dream_intro.tscn"
)


# ============================================================
# CINEMATIC SKIP
# ============================================================

@export_category("Cinematic Skip")

@export var skip_action_name: StringName = &"skip_cinematic"
@export var skip_hold_duration: float = 1.25
## The skip hint stays hidden until the player presses a key (they want to skip);
## it then shows for this long after their last key press (and while they hold).
@export var skip_prompt_visible_seconds: float = 3.5


# ============================================================
# NODE REFERENCES
# ============================================================

var menu_root: Node = null

var menu_camera: Camera3D = null
var camera_animation_player: AnimationPlayer = null

var stationary_train: Node = null
var scenery_loop: Node = null

var blackout_rect: ColorRect = null

var main_menu_ui: Control = null
var left_panel: CanvasItem = null

var title_label: Label = null
var new_game_button: Button = null
var load_game_button: Button = null
var options_button: Button = null
var quit_button: Button = null

var options_panel: Control = null
var save_slots_panel: SaveSlotsPanelController = null
var options_back_button: Button = null
var master_volume_slider: HSlider = null

var cinematic_skip_prompt: Control = null
var cinematic_skip_progress: ProgressBar = null
var cinematic_loading_label: Label = null

var persistent_audio: Node = null

var train_light_flickers: Array[TrainLightFlicker] = []

var scenery_slowdown_tween: Tween = null

var transition_running: bool = false
var options_panel_open: bool = false
var updating_master_volume_slider: bool = false

var skip_hold_elapsed: float = 0.0
var skip_waiting_for_release: bool = false
var skip_requested: bool = false
var skip_prompt_visible_until_msec: int = 0
## True only during the opening cinematic of a new game: loading a saved game has
## nothing to skip, and shows no skip hint at all.
var cinematic_skip_enabled: bool = false

var playable_scene_load_path: String = ""
var playable_scene_load_started: bool = false
var playable_scene_load_failed: bool = false
var loaded_playable_scene: PackedScene = null
var scene_change_requested: bool = false
var scene_change_fade_finished: bool = false
var new_game_scene_path: String = ""
var reveal_loaded_scene_after_change: bool = false

## While the cinematic is played over the already built next scene: the host of the cinematic (a layer with a viewport that holds this whole menu), and the scene.
var _cinematic_host: CanvasLayer = null
## The menu's interface and logic (everything that is not the 3D scene) stay in the main window's viewport, as they always were; only the 3D scene is in the cinematic viewport.
var _menu_logic: Node = null
var _built_scene: Node = null
var _handing_over: bool = false
var _prebuilding: bool = false
## What the built scene had set to "always process" (its pause menu, for one), which sleeps with it: no key may reach it while the cinematic is on.
var _slept_nodes: Array[Node] = []
var _hidden_layers: Array[CanvasLayer] = []


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	menu_root = get_parent()
	new_game_scene_path = playable_scene_path

	_find_scene_nodes()
	_collect_train_light_flickers()
	_connect_buttons()
	_connect_viewport()
	_prepare_menu_state()


func _exit_tree() -> void:
	# Leaving the menu (the pause menu's way back to it, a scene change) never leaves the narration running under whatever comes next (but handing the cinematic over
	# to the built scene does not stop it: its last sentence is still to be said).
	if _handing_over:
		return

	_stop_intro_narration_if_running()


func _process(delta: float) -> void:
	_update_playable_scene_preload()
	_advance_playable_scene_change()
	_update_cinematic_skip(delta)


func _find_scene_nodes() -> void:
	if menu_root == null:
		push_error(
			"MenuController: Menu scene root was not found."
		)
		return

	menu_camera = (
		menu_root.get_node_or_null(MENU_CAMERA_PATH)
		as Camera3D
	)

	camera_animation_player = (
		menu_root.get_node_or_null(
			CAMERA_ANIMATION_PLAYER_PATH
		)
		as AnimationPlayer
	)

	stationary_train = menu_root.get_node_or_null(
		STATIONARY_TRAIN_PATH
	)

	scenery_loop = menu_root.get_node_or_null(
		SCENERY_LOOP_PATH
	)

	blackout_rect = (
		menu_root.get_node_or_null(BLACKOUT_RECT_PATH)
		as ColorRect
	)

	main_menu_ui = (
		menu_root.get_node_or_null(MAIN_MENU_UI_PATH)
		as Control
	)

	left_panel = (
		menu_root.get_node_or_null(LEFT_PANEL_PATH)
		as CanvasItem
	)

	title_label = (
		menu_root.get_node_or_null(TITLE_LABEL_PATH)
		as Label
	)

	new_game_button = (
		menu_root.get_node_or_null(NEW_GAME_BUTTON_PATH)
		as Button
	)

	load_game_button = (
		menu_root.get_node_or_null(LOAD_GAME_BUTTON_PATH)
		as Button
	)

	options_button = (
		menu_root.get_node_or_null(OPTIONS_BUTTON_PATH)
		as Button
	)

	quit_button = (
		menu_root.get_node_or_null(QUIT_BUTTON_PATH)
		as Button
	)

	options_panel = (
		menu_root.get_node_or_null(OPTIONS_PANEL_PATH)
		as Control
	)

	save_slots_panel = (
		menu_root.get_node_or_null(SAVE_SLOTS_PANEL_PATH)
		as SaveSlotsPanelController
	)

	options_back_button = (
		menu_root.get_node_or_null(
			OPTIONS_BACK_BUTTON_PATH
		)
		as Button
	)

	master_volume_slider = (
		menu_root.get_node_or_null(
			MASTER_VOLUME_SLIDER_PATH
		)
		as HSlider
	)

	cinematic_skip_prompt = (
		menu_root.get_node_or_null(
			CINEMATIC_SKIP_PROMPT_PATH
		)
		as Control
	)

	cinematic_skip_progress = (
		menu_root.get_node_or_null(
			CINEMATIC_SKIP_PROGRESS_PATH
		)
		as ProgressBar
	)

	cinematic_loading_label = (
		menu_root.get_node_or_null(
			CINEMATIC_LOADING_LABEL_PATH
		)
		as Label
	)

	_find_persistent_audio()
	_find_ui_fallbacks()
	_validate_scene_nodes()


func _find_persistent_audio() -> void:
	var tree_root: Window = get_tree().root

	if tree_root == null:
		return

	persistent_audio = tree_root.get_node_or_null(
		PERSISTENT_AUDIO_NAME
	)

	if persistent_audio != null:
		return

	for child: Node in tree_root.get_children():
		if (
			child.has_method("play_menu_idle")
			and child.has_method(
				"play_intro_narration_after_delay"
			)
		):
			persistent_audio = child
			return


func _find_ui_fallbacks() -> void:
	if main_menu_ui == null:
		return

	if title_label == null:
		title_label = (
			main_menu_ui.find_child(
				"TitleLabel",
				true,
				false
			)
			as Label
		)

	if new_game_button == null:
		new_game_button = (
			main_menu_ui.find_child(
				"NewGameButton",
				true,
				false
			)
			as Button
		)

	if load_game_button == null:
		load_game_button = (
			main_menu_ui.find_child(
				"LoadGameButton",
				true,
				false
			)
			as Button
		)

	if options_button == null:
		options_button = (
			main_menu_ui.find_child(
				"OptionsButton",
				true,
				false
			)
			as Button
		)

	if quit_button == null:
		quit_button = (
			main_menu_ui.find_child(
				"QuitButton",
				true,
				false
			)
			as Button
		)

	if options_panel == null:
		options_panel = (
			main_menu_ui.find_child(
				"OptionsPanel",
				true,
				false
			)
			as Control
		)

	if save_slots_panel == null:
		save_slots_panel = (
			main_menu_ui.find_child(
				"SaveSlotsPanel",
				true,
				false
			)
			as SaveSlotsPanelController
		)

	if options_back_button == null:
		options_back_button = (
			main_menu_ui.find_child(
				"OptionsBackButton",
				true,
				false
			)
			as Button
		)

	if master_volume_slider == null:
		master_volume_slider = (
			main_menu_ui.find_child(
				"MasterVolumeSlider",
				true,
				false
			)
			as HSlider
		)

	if master_volume_slider == null:
		master_volume_slider = (
			main_menu_ui.find_child(
				"MasterVolumeSlide",
				true,
				false
			)
			as HSlider
		)


func _validate_scene_nodes() -> void:
	if menu_camera == null:
		push_error(
			"MenuController: New MenuCamera was not found at: "
			+ str(MENU_CAMERA_PATH)
		)

	if camera_animation_player == null:
		push_error(
			"MenuController: New CameraAnimationPlayer was not "
			+ "found at: "
			+ str(CAMERA_ANIMATION_PLAYER_PATH)
		)

	if stationary_train == null:
		push_error(
			"MenuController: StationaryTrain was not found at: "
			+ str(STATIONARY_TRAIN_PATH)
		)

	if scenery_loop == null:
		push_error(
			"MenuController: SceneryLoop was not found at: "
			+ str(SCENERY_LOOP_PATH)
		)
	elif not scenery_loop.has_method("smooth_stop"):
		push_warning(
			"MenuController: SceneryLoop does not have a "
			+ "smooth_stop() method."
		)

	if blackout_rect == null:
		push_error(
			"MenuController: BlackoutRect was not found at: "
			+ str(BLACKOUT_RECT_PATH)
		)
	else:
		blackout_rect.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		var blackout_parent: Node = (
			blackout_rect.get_parent()
		)

		if blackout_parent is CanvasLayer:
			(blackout_parent as CanvasLayer).layer = 1000

	if main_menu_ui == null:
		push_error(
			"MenuController: MainMenuUI was not found."
		)

	if new_game_button == null:
		push_error(
			"MenuController: NewGameButton was not found."
		)

	if load_game_button == null:
		push_error(
			"MenuController: LoadGameButton was not found."
		)

	if save_slots_panel == null:
		push_error(
			"MenuController: SaveSlotsPanel was not found."
		)

	if options_button == null:
		push_warning(
			"MenuController: OptionsButton was not found."
		)

	if quit_button == null:
		push_warning(
			"MenuController: QuitButton was not found."
		)

	if options_panel == null:
		push_warning(
			"MenuController: OptionsPanel was not found."
		)

	if options_back_button == null:
		push_warning(
			"MenuController: OptionsBackButton was not found."
		)

	if master_volume_slider == null:
		push_warning(
			"MenuController: MasterVolumeSlider was not found."
		)
	else:
		master_volume_slider.min_value = 0.0
		master_volume_slider.max_value = 100.0
		master_volume_slider.step = 1.0

	if cinematic_skip_prompt == null:
		push_warning(
			"MenuController: Cinematic SkipPrompt was not found."
		)

	if cinematic_skip_progress == null:
		push_warning(
			"MenuController: Cinematic SkipProgress was not found."
		)
	else:
		cinematic_skip_progress.min_value = 0.0
		cinematic_skip_progress.max_value = 1.0
		cinematic_skip_progress.value = 0.0
		cinematic_skip_progress.show_percentage = false

	if not InputMap.has_action(skip_action_name):
		push_error(
			"MenuController: Input action '%s' was not found."
			% skip_action_name
		)

	if cinematic_loading_label == null:
		push_warning(
			"MenuController: Cinematic LoadingLabel was not found."
		)

	if persistent_audio == null:
		push_error(
			"MenuController: PersistentAudio Autoload was not "
			+ "found."
		)

	if (
		camera_animation_player != null
		and not camera_animation_player.has_animation(
			intro_animation_name
		)
	):
		push_error(
			"MenuController: Intro animation '%s' was not found."
			% intro_animation_name
		)

	if (
		camera_animation_player != null
		and play_brake_animation
		and not camera_animation_player.has_animation(
			brake_animation_name
		)
	):
		push_warning(
			"MenuController: Brake animation '%s' was not found."
			% brake_animation_name
		)


# ============================================================
# TRAIN LIGHTS
# ============================================================

func _collect_train_light_flickers() -> void:
	train_light_flickers.clear()

	if stationary_train == null:
		return

	_find_train_light_flickers_recursive(
		stationary_train
	)

	if train_light_flickers.is_empty():
		push_warning(
			"MenuController: No TrainLightFlicker nodes "
			+ "were found under StationaryTrain."
		)


func _find_train_light_flickers_recursive(
	node: Node
) -> void:
	var light_flicker: TrainLightFlicker = (
		node as TrainLightFlicker
	)

	if light_flicker != null:
		if not train_light_flickers.has(light_flicker):
			train_light_flickers.append(light_flicker)

	for child: Node in node.get_children():
		_find_train_light_flickers_recursive(child)


# ============================================================
# MENU BUTTONS
# ============================================================

func _connect_buttons() -> void:
	if (
		new_game_button != null
		and not new_game_button.pressed.is_connected(
			_on_new_game_button_pressed
		)
	):
		new_game_button.pressed.connect(
			_on_new_game_button_pressed
		)

	if (
		load_game_button != null
		and not load_game_button.pressed.is_connected(
			_on_load_game_button_pressed
		)
	):
		load_game_button.pressed.connect(
			_on_load_game_button_pressed
		)

	if (
		options_button != null
		and not options_button.pressed.is_connected(
			_on_options_button_pressed
		)
	):
		options_button.pressed.connect(
			_on_options_button_pressed
		)

	if (
		options_back_button != null
		and not options_back_button.pressed.is_connected(
			_on_options_back_button_pressed
		)
	):
		options_back_button.pressed.connect(
			_on_options_back_button_pressed
		)

	if (
		master_volume_slider != null
		and not master_volume_slider.value_changed.is_connected(
			_on_master_volume_slider_value_changed
		)
	):
		master_volume_slider.value_changed.connect(
			_on_master_volume_slider_value_changed
		)

	if (
		quit_button != null
		and not quit_button.pressed.is_connected(
			_on_quit_button_pressed
		)
	):
		quit_button.pressed.connect(
			_on_quit_button_pressed
		)

	if save_slots_panel != null:
		if not save_slots_panel.new_game_slot_selected.is_connected(
			_on_new_game_slot_selected
		):
			save_slots_panel.new_game_slot_selected.connect(
				_on_new_game_slot_selected
			)

		if not save_slots_panel.load_game_slot_selected.is_connected(
			_on_load_game_slot_selected
		):
			save_slots_panel.load_game_slot_selected.connect(
				_on_load_game_slot_selected
			)

		if not save_slots_panel.closed.is_connected(
			_on_save_slots_panel_closed
		):
			save_slots_panel.closed.connect(
				_on_save_slots_panel_closed
			)

	if not SaveManager.slots_changed.is_connected(
		_refresh_main_menu_save_state
	):
		SaveManager.slots_changed.connect(
			_refresh_main_menu_save_state
		)


func _on_new_game_button_pressed() -> void:
	if transition_running or _prebuilding:
		return

	_set_options_panel_open(false)
	_set_main_menu_buttons_visible(false)
	_set_main_menu_buttons_enabled(false)

	if save_slots_panel != null:
		save_slots_panel.open_new_game()


func _on_load_game_button_pressed() -> void:
	if transition_running or not SaveManager.has_any_save():
		return

	_set_options_panel_open(false)
	_set_main_menu_buttons_visible(false)
	_set_main_menu_buttons_enabled(false)

	if save_slots_panel != null:
		save_slots_panel.open_load_game()


func _on_new_game_slot_selected(slot_id: int) -> void:
	if transition_running:
		return

	playable_scene_path = new_game_scene_path
	# The scene that has been loading since the menu appeared is kept.
	if playable_scene_load_path != playable_scene_path or not (playable_scene_load_started or loaded_playable_scene != null):
		_reset_playable_scene_load()
	reveal_loaded_scene_after_change = false
	var save_result: Error = SaveManager.create_new_game(
		slot_id,
		playable_scene_path,
		"dream_intro_start",
		"SAVE_LOCATION_DREAM_INTRO"
	)
	if save_result != OK:
		if save_slots_panel != null:
			save_slots_panel.show_save_error("SAVE_ERROR_CREATE")
		return

	_start_new_game_transition()


func _on_load_game_slot_selected(slot_id: int) -> void:
	if transition_running:
		return

	var save_data: Dictionary = SaveManager.load_slot(slot_id)
	var target_path: String = str(save_data.get("scene_path", ""))
	if (
		save_data.is_empty()
		or target_path.is_empty()
		or not ResourceLoader.exists(target_path, "PackedScene")
	):
		SaveManager.suspend_session(false)
		if save_slots_panel != null:
			save_slots_panel.show_save_error("SAVE_ERROR_LOAD")
		return

	playable_scene_path = target_path
	_reset_playable_scene_load()
	reveal_loaded_scene_after_change = true
	_start_loaded_game_transition()


func _on_save_slots_panel_closed() -> void:
	if transition_running:
		return

	_set_main_menu_buttons_visible(true)
	_set_main_menu_buttons_enabled(true)
	if new_game_button != null:
		new_game_button.grab_focus()


func _refresh_main_menu_save_state() -> void:
	if transition_running:
		return

	_set_main_menu_buttons_enabled(
		not options_panel_open
		and (
			save_slots_panel == null
			or not save_slots_panel.is_open()
		)
	)


func _start_new_game_transition() -> void:
	transition_running = true
	var built: bool = _built_scene != null and is_instance_valid(_built_scene)
	_begin_cinematic_skip()
	if not built:
		_start_playable_scene_preload()

	if save_slots_panel != null:
		save_slots_panel.close_panel()

	_set_options_panel_open(false)
	_set_main_menu_buttons_visible(true)
	_set_main_menu_buttons_enabled(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_fade_out_menu_idle_audio()

	# The menu fades out over the train and the narration begins (the next scene, if it was built beforehand, sleeps behind this).
	_start_intro_narration()
	await _fade_out_menu()

	if skip_requested:
		return

	if intro_animation_start_delay > 0.0:
		await get_tree().create_timer(
			intro_animation_start_delay,
			false
		).timeout

	await _play_intro_animation()
	if skip_requested:
		return

	# The one synchronisation point: the narration has reached the end of its last line before the black plus the ambient tail (the glide normally ends exactly
	# there), then the lights fail; the last sentence is said in the black (see `_run_train_stop_sequence`).
	await _wait_for_intro_lights_out()
	if skip_requested:
		return

	await _run_train_stop_sequence()

	if built:
		_hand_over_to_built_scene()
	elif change_scene_after_animation:
		_open_playable_scene()
	else:
		transition_running = false
		_reset_cinematic_skip()


func _start_loaded_game_transition() -> void:
	transition_running = true
	_reset_cinematic_skip()
	_start_playable_scene_preload()

	if save_slots_panel != null:
		save_slots_panel.close_panel()

	_set_options_panel_open(false)
	_set_main_menu_buttons_visible(true)
	_set_main_menu_buttons_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_fade_out_menu_idle_audio()

	await _fade_out_menu()
	_open_playable_scene()


func _on_options_button_pressed() -> void:
	if transition_running:
		return

	_set_options_panel_open(true)


func _on_options_back_button_pressed() -> void:
	if transition_running:
		return

	_set_options_panel_open(false)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func is_cinematic_transition_running() -> bool:
	return transition_running and not skip_requested


# ============================================================
# CINEMATIC SKIP
# ============================================================

func _begin_cinematic_skip() -> void:
	cinematic_skip_enabled = true
	skip_requested = false
	skip_hold_elapsed = 0.0
	skip_waiting_for_release = (
		InputMap.has_action(skip_action_name)
		and Input.is_action_pressed(skip_action_name)
	)

	if cinematic_skip_prompt != null:
		# The hint names the key the player has chosen for skipping.
		var skip_label: Label = cinematic_skip_prompt.get_node_or_null("SkipMargin/SkipVBox/SkipLabel") as Label
		if skip_label != null:
			skip_label.text = InputBindings.format_text(tr("CINEMATIC_HOLD_SKIP"))

		# Hidden until the player presses a key.
		cinematic_skip_prompt.hide()

	skip_prompt_visible_until_msec = 0
	_set_cinematic_skip_progress(0.0)


## Any key or button press during the cinematic means the player may want to skip
## it: only then is the hint shown (and it fades out again if they do nothing).
func _input(event: InputEvent) -> void:
	if not cinematic_skip_enabled or not transition_running or skip_requested or cinematic_skip_prompt == null:
		return

	var is_button: bool = (
		event is InputEventKey
		or event is InputEventMouseButton
		or event is InputEventJoypadButton
	)
	var pressed: bool = is_button and event.is_pressed() and not event.is_echo()

	if pressed and not skip_waiting_for_release:
		_reveal_skip_prompt()


func _reveal_skip_prompt() -> void:
	if cinematic_skip_prompt == null:
		return

	skip_prompt_visible_until_msec = Time.get_ticks_msec() + int(skip_prompt_visible_seconds * 1000.0)
	cinematic_skip_prompt.show()


func _update_cinematic_skip(delta: float) -> void:
	if not cinematic_skip_enabled or not transition_running or skip_requested:
		return

	if not InputMap.has_action(skip_action_name):
		return

	var skip_held: bool = Input.is_action_pressed(
		skip_action_name
	)

	if skip_waiting_for_release:
		if not skip_held:
			skip_waiting_for_release = false
		return

	# The hint is on screen while the key is held and for a moment after the last
	# press, then it goes away again.
	if skip_held:
		_reveal_skip_prompt()
	elif (
		cinematic_skip_prompt != null
		and cinematic_skip_prompt.visible
		and Time.get_ticks_msec() > skip_prompt_visible_until_msec
	):
		cinematic_skip_prompt.hide()

	if not skip_held:
		skip_hold_elapsed = 0.0
		_set_cinematic_skip_progress(0.0)
		return

	var required_hold_time: float = maxf(
		skip_hold_duration,
		0.05
	)

	skip_hold_elapsed += delta
	_set_cinematic_skip_progress(
		clampf(
			skip_hold_elapsed / required_hold_time,
			0.0,
			1.0
		)
	)

	if skip_hold_elapsed >= required_hold_time:
		_skip_to_playable_scene()


func _skip_to_playable_scene() -> void:
	if skip_requested or not transition_running:
		return

	skip_requested = true
	_set_cinematic_skip_progress(1.0)

	if persistent_audio != null:
		if persistent_audio.has_method(
			"stop_intro_narration"
		):
			persistent_audio.call("stop_intro_narration")

		if persistent_audio.has_method("stop_menu_idle"):
			persistent_audio.call("stop_menu_idle")

	if _built_scene != null and is_instance_valid(_built_scene):
		_hand_over_to_built_scene()
		return

	_open_playable_scene()


func _set_cinematic_skip_progress(value: float) -> void:
	if cinematic_skip_progress != null:
		cinematic_skip_progress.value = clampf(
			value,
			0.0,
			1.0
		)


func _reset_cinematic_skip() -> void:
	cinematic_skip_enabled = false
	skip_hold_elapsed = 0.0
	skip_waiting_for_release = false
	skip_requested = false

	if cinematic_skip_prompt != null:
		cinematic_skip_prompt.hide()

	_set_cinematic_skip_progress(0.0)


# ============================================================
# INITIAL MENU STATE
# ============================================================

func _prepare_menu_state() -> void:
	_stop_intro_narration_if_running()
	transition_running = false
	options_panel_open = false
	playable_scene_path = new_game_scene_path
	_reset_playable_scene_load()
	_reset_cinematic_skip()
	SaveManager.suspend_session()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if menu_camera != null:
		menu_camera.current = true

	if main_menu_ui != null:
		main_menu_ui.visible = true
		main_menu_ui.modulate = Color.WHITE

	if left_panel != null:
		left_panel.visible = true
		left_panel.modulate = Color.WHITE

	if blackout_rect != null:
		blackout_rect.visible = true
		blackout_rect.color = Color.BLACK
		blackout_rect.modulate.a = 0.0

	if cinematic_loading_label != null:
		cinematic_loading_label.hide()

	_set_options_panel_open(false)
	if save_slots_panel != null:
		save_slots_panel.hide()
	_set_main_menu_buttons_enabled(true)

	_prepare_camera_animation()
	_sync_master_volume_slider_to_audio()
	_apply_responsive_ui()
	_start_menu_idle_audio()

	# The next scene is built (behind a loading screen) before the menu is shown.
	_prebuild_if_main_menu.call_deferred()

	if new_game_button != null:
		new_game_button.call_deferred("grab_focus")


func _prepare_camera_animation() -> void:
	if camera_animation_player == null:
		return

	if not camera_animation_player.has_animation(
		intro_animation_name
	):
		return

	camera_animation_player.play(
		intro_animation_name
	)

	camera_animation_player.seek(0.0, true)
	camera_animation_player.pause()


# ============================================================
# OPTIONS PANEL
# ============================================================

func _set_options_panel_open(opened: bool) -> void:
	options_panel_open = opened

	if options_panel != null:
		options_panel.visible = opened

	_set_main_menu_buttons_visible(not opened)

	_set_main_menu_buttons_enabled(
		not opened and not transition_running
	)

	if opened:
		if options_back_button != null:
			options_back_button.grab_focus()
	else:
		if new_game_button != null and not transition_running:
			new_game_button.grab_focus()


func _set_main_menu_buttons_visible(
	buttons_visible: bool
) -> void:
	if new_game_button != null:
		new_game_button.visible = buttons_visible

	if load_game_button != null:
		load_game_button.visible = buttons_visible

	if options_button != null:
		options_button.visible = buttons_visible

	if quit_button != null:
		quit_button.visible = buttons_visible


func _set_main_menu_buttons_enabled(enabled: bool) -> void:
	if new_game_button != null:
		new_game_button.disabled = not enabled

	if load_game_button != null:
		load_game_button.disabled = (
			not enabled or not SaveManager.has_any_save()
		)

	if options_button != null:
		options_button.disabled = not enabled

	if quit_button != null:
		quit_button.disabled = not enabled


# ============================================================
# MASTER VOLUME
# ============================================================

func _on_master_volume_slider_value_changed(
	value: float
) -> void:
	if updating_master_volume_slider:
		return

	if persistent_audio == null:
		return

	if persistent_audio.has_method(
		"set_master_volume_percent"
	):
		persistent_audio.call(
			"set_master_volume_percent",
			value,
			true
		)


func _sync_master_volume_slider_to_audio() -> void:
	if master_volume_slider == null:
		return

	updating_master_volume_slider = true

	if (
		persistent_audio != null
		and persistent_audio.has_method(
			"get_master_volume_percent"
		)
	):
		var saved_volume: Variant = persistent_audio.call(
			"get_master_volume_percent"
		)

		master_volume_slider.value = float(
			saved_volume
		)
	else:
		master_volume_slider.value = 100.0

	updating_master_volume_slider = false


# ============================================================
# AUDIO
# ============================================================

func _start_menu_idle_audio() -> void:
	if not play_menu_idle_audio:
		return

	if persistent_audio == null:
		return

	if persistent_audio.has_method("play_menu_idle"):
		persistent_audio.call("play_menu_idle")


func _fade_out_menu_idle_audio() -> void:
	if persistent_audio == null:
		return

	if persistent_audio.has_method("fade_out_menu_idle"):
		persistent_audio.call(
			"fade_out_menu_idle",
			menu_idle_fade_out_duration
		)


func _stop_intro_narration_if_running() -> void:
	# A narration that is held is being handed over to the next scene, which lets it go on and waits for its last word: leaving the menu does not stop it.
	if persistent_audio != null and is_instance_valid(persistent_audio) and persistent_audio.has_method("is_intro_narration_held") and bool(persistent_audio.call("is_intro_narration_held")):
		return

	if persistent_audio != null and is_instance_valid(persistent_audio) and persistent_audio.has_method("is_intro_narration_running"):
		if bool(persistent_audio.call("is_intro_narration_running")):
			persistent_audio.call("stop_intro_narration")


## Waits, if the glide was over before the narration was, until the last line before the black has ended and the ambient tail has passed (normally no wait at all).
func _wait_for_intro_lights_out() -> void:
	if persistent_audio == null or not persistent_audio.has_method("is_intro_narration_running"):
		return
	if not bool(persistent_audio.call("is_intro_narration_running")):
		return

	var wait: float = float(persistent_audio.call("get_intro_narration_seconds_to_black")) + maxf(intro_ambient_tail_seconds, 0.0)
	if wait > 0.02:
		await get_tree().create_timer(wait, false).timeout


## The menu is first shown: it stays under black with the loading label while the next scene is built (this takes a few seconds, in which no frame is drawn), and then
## appears. Only for the real main menu (the current scene, with the building switched on).
func _should_prebuild() -> bool:
	return build_scene_before_cinematic and change_scene_after_animation and menu_root != null and get_tree().current_scene == menu_root and _built_scene == null


func _prebuild_if_main_menu() -> void:
	if _should_prebuild():
		_prebuild_next_scene()


func _prebuild_next_scene() -> void:
	_prebuilding = true
	if persistent_audio != null and persistent_audio.has_method("hold_opening"):
		persistent_audio.call("hold_opening", true)

	_set_main_menu_buttons_enabled(false)
	if blackout_rect != null:
		blackout_rect.visible = true
		blackout_rect.color = Color.BLACK
		blackout_rect.modulate.a = 1.0

	if cinematic_loading_label != null:
		cinematic_loading_label.show()

	_start_playable_scene_preload()
	await get_tree().process_frame

	var built: bool = await _build_next_scene_asleep()
	if cinematic_loading_label != null:
		cinematic_loading_label.hide()

	if not built:
		_release_opening_hold()

	if blackout_rect != null:
		var reveal: Tween = create_tween()
		reveal.tween_property(blackout_rect, "modulate:a", 0.0, maxf(menu_reveal_seconds, 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await reveal.finished

	_prebuilding = false
	_refresh_main_menu_save_state()
	if new_game_button != null:
		new_game_button.grab_focus()


## Builds the next scene and leaves it asleep behind this menu: this whole menu is moved into a viewport on a layer over it (a world of its own, so the two scenes never see
## each other), and the next scene has its processing and its 3D drawing switched off until the hand-over. False if it could not be done (the old way is then used).
func _build_next_scene_asleep() -> bool:
	var waited: float = 0.0
	while loaded_playable_scene == null and not playable_scene_load_failed and waited < 120.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	if loaded_playable_scene == null or menu_root == null:
		return false

	var tree: SceneTree = get_tree()
	var packed: PackedScene = loaded_playable_scene
	_make_cinematic_host()
	await tree.process_frame

	var next_scene: Node = packed.instantiate()
	tree.root.add_child(next_scene)
	tree.current_scene = next_scene
	_built_scene = next_scene
	_built_scene.tree_exited.connect(_on_built_scene_left)
	_reset_playable_scene_load()
	# Its own set-up runs and its first frames are drawn here, under the black; then it sleeps.
	for _frame: int in 4:
		await tree.process_frame

	_sleep_built_scene()
	tree.root.disable_3d = true
	# (It captured the mouse for its own opening: the menu needs the pointer.)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	return true


func _sleep_built_scene() -> void:
	_slept_nodes.clear()
	for node: Node in _built_scene.find_children("*", "", true, false):
		if node.process_mode == Node.PROCESS_MODE_ALWAYS:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			_slept_nodes.append(node)

	_built_scene.process_mode = Node.PROCESS_MODE_DISABLED

	# Its interface layers (its black cover for one) would be drawn over the cinematic.
	_hidden_layers.clear()
	for layer: Node in _built_scene.find_children("*", "CanvasLayer", true, false):
		var canvas_layer: CanvasLayer = layer as CanvasLayer
		if canvas_layer.visible:
			canvas_layer.visible = false
			_hidden_layers.append(canvas_layer)


func _wake_built_scene() -> void:
	for canvas_layer: CanvasLayer in _hidden_layers:
		if is_instance_valid(canvas_layer):
			canvas_layer.visible = true

	_hidden_layers.clear()

	if _built_scene != null and is_instance_valid(_built_scene):
		_built_scene.process_mode = Node.PROCESS_MODE_INHERIT

	for node: Node in _slept_nodes:
		if is_instance_valid(node):
			node.process_mode = Node.PROCESS_MODE_ALWAYS

	_slept_nodes.clear()


## The menu's 3D scene (the train, the forest loop, the camera, the sky) goes into a viewport of its own, drawn on a layer under the menu's interface. The interface (the buttons, the
## options, the save slots and their dialogs, the skip prompt, the pause menu, the black) and this controller stay in the main window, so that they work exactly as they always
## did (pop-up windows and keyboard/gamepad focus do not work properly inside a viewport that is shown through a container).
const MENU_LOGIC_NODES: Array[String] = ["UI", "CinematicHUD", "LoadingHUD", "CinematicPauseMenu", "CinematicPauseController", "MenuController", "TransitionBlackout"]


func _make_cinematic_host() -> void:
	var tree: SceneTree = get_tree()
	var window: Window = tree.root
	_cinematic_host = CanvasLayer.new()
	_cinematic_host.name = "CinematicHost"
	# Over the dream scene's pictures and the main window's own filter, under every layer of the menu's interface (10 and up).
	_cinematic_host.layer = 5

	var container: SubViewportContainer = SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cinematic_host.add_child(container)

	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	# Its 3D sounds (the train) are heard through this viewport.
	viewport.audio_listener_enable_3d = true
	viewport.audio_listener_enable_2d = true
	viewport.size = window.size
	viewport.msaa_3d = window.msaa_3d
	viewport.screen_space_aa = window.screen_space_aa
	viewport.use_taa = window.use_taa
	viewport.use_debanding = window.use_debanding
	viewport.scaling_3d_mode = window.scaling_3d_mode
	viewport.scaling_3d_scale = window.scaling_3d_scale
	# The horror filter (grain, glare, lens) is a layer-0 overlay of the main window: it never sees what is drawn in another viewport, so the 3D scene gets one of its own (without
	# it the menu's night loses its haze and colour).
	viewport.add_child((load(HORROR_FILTER_SCENE) as PackedScene).instantiate())
	container.add_child(viewport)
	window.add_child(_cinematic_host)

	# This scene is no longer the current one (it is not freed when the next one is built); the interface goes to the main window, the 3D scene to its viewport.
	tree.current_scene = null
	_menu_logic = Node.new()
	_menu_logic.name = "MenuLogic"
	window.add_child(_menu_logic)
	for node_name: String in MENU_LOGIC_NODES:
		var node: Node = menu_root.get_node_or_null(node_name)
		if node != null:
			menu_root.remove_child(node)
			_menu_logic.add_child(node)

	menu_root.get_parent().remove_child(menu_root)
	viewport.add_child(menu_root)
	if menu_camera != null:
		menu_camera.make_current()


## The cinematic is over (or skipped): its viewport goes, and the built scene wakes up where it waited, black, to begin when the last word has been said.
func _hand_over_to_built_scene() -> void:
	if _handing_over:
		return

	_handing_over = true
	var tree: SceneTree = get_tree()
	_wake_built_scene()

	tree.root.disable_3d = false
	_free_cinematic_host()
	_release_opening_hold()


func _free_cinematic_host() -> void:
	if _cinematic_host != null and is_instance_valid(_cinematic_host):
		_cinematic_host.queue_free()

	if _menu_logic != null and is_instance_valid(_menu_logic):
		_menu_logic.queue_free()


func _release_opening_hold() -> void:
	if persistent_audio != null and is_instance_valid(persistent_audio) and persistent_audio.has_method("hold_opening"):
		persistent_audio.call("hold_opening", false)


## The built scene went while the cinematic was still being played (the pause menu's way back to the main menu): nothing of this is left over it.
func _on_built_scene_left() -> void:
	if _handing_over:
		return

	_handing_over = true
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	tree.root.disable_3d = false
	_stop_intro_narration_if_running()
	_release_opening_hold()
	_free_cinematic_host()


## The screen is black and the next scene is about to be built (which takes a few seconds in which no frame is drawn): the narration waits where it is, and the next scene
## (`DreamIntroController`) lets it go when it is ready, so that the last sentence is said in the black, whole, and the opening begins right after it.
func _hold_narration_for_scene_change() -> void:
	if skip_requested or not change_scene_after_animation or _built_scene != null or persistent_audio == null or not persistent_audio.has_method("hold_intro_narration"):
		return

	persistent_audio.call("hold_intro_narration", true)


## How fast the camera glide runs: slowed (never sped up) so that it ends `intro_ambient_tail_seconds` after the last line said before the black.
func _intro_animation_speed(animation_length: float) -> float:
	if persistent_audio == null or not persistent_audio.has_method("get_intro_narration_seconds_to_black"):
		return 1.0

	var remaining: float = float(persistent_audio.call("get_intro_narration_seconds_to_black"))
	if remaining <= 0.0 or animation_length <= 0.0:
		return 1.0

	return clampf(animation_length / (remaining + maxf(intro_ambient_tail_seconds, 0.0)), intro_min_speed_scale, 1.0)


func _start_intro_narration() -> void:
	if not play_intro_narration:
		return

	if persistent_audio == null:
		return

	if _node_has_property(
		persistent_audio,
		&"intro_narration_volume_db"
	):
		persistent_audio.set(
			"intro_narration_volume_db",
			intro_narration_volume_db
		)

	if persistent_audio.has_method(
		"play_intro_narration_after_delay"
	):
		persistent_audio.call(
			"play_intro_narration_after_delay",
			intro_narration_start_delay
		)


# ============================================================
# MENU FADE AND INTRO ANIMATION
# ============================================================

func _fade_out_menu() -> void:
	if main_menu_ui == null:
		return

	var tween: Tween = create_tween()

	tween.tween_property(
		main_menu_ui,
		"modulate:a",
		0.0,
		maxf(menu_fade_duration, 0.0)
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished

	main_menu_ui.visible = false


func _play_intro_animation() -> void:
	if camera_animation_player == null:
		push_error(
			"MenuController: CameraAnimationPlayer is missing."
		)
		return

	if not camera_animation_player.has_animation(
		intro_animation_name
	):
		push_error(
			"MenuController: Animation '%s' was not found."
			% intro_animation_name
		)
		return

	var intro_animation: Animation = (
		camera_animation_player.get_animation(
			intro_animation_name
		)
	)

	if (
		intro_animation != null
		and intro_animation.loop_mode
		!= Animation.LOOP_NONE
	):
		push_warning(
			"MenuController: Intro animation is looping. "
			+ "Disable looping."
		)
		return

	# Same path, same order of events, at the speed that lets it end with the narration (and its tail).
	camera_animation_player.play(
		intro_animation_name,
		-1.0,
		_intro_animation_speed(intro_animation.length)
	)

	camera_animation_player.seek(0.0, true)

	await camera_animation_player.animation_finished


# ============================================================
# BRAKE ANIMATION
# ============================================================

func _start_brake_animation() -> void:
	if not play_brake_animation:
		return

	if camera_animation_player == null:
		return

	if not camera_animation_player.has_animation(
		brake_animation_name
	):
		push_warning(
			"MenuController: Brake animation '%s' was not found."
			% brake_animation_name
		)
		return

	camera_animation_player.play(
		brake_animation_name
	)

	camera_animation_player.seek(0.0, true)


func _wait_for_brake_animation() -> void:
	if not play_brake_animation:
		return

	if camera_animation_player == null:
		return

	if not camera_animation_player.is_playing():
		return

	if (
		camera_animation_player.current_animation
		!= String(brake_animation_name)
	):
		return

	await camera_animation_player.animation_finished


# ============================================================
# STOP SEQUENCE
# ============================================================

func _run_train_stop_sequence() -> void:
	var slowdown_time: float = maxf(
		train_slowdown_duration,
		0.0
	)

	var blackout_delay: float = clampf(
		blackout_during_slowdown_delay,
		0.0,
		slowdown_time
	)

	var final_flicker_time: float = maxf(
		blackout_final_flicker_duration,
		0.0
	)

	_start_brake_animation()
	_begin_scenery_slowdown(slowdown_time)

	for light_flicker: TrainLightFlicker in (
		train_light_flickers
	):
		if (
			light_flicker != null
			and is_instance_valid(light_flicker)
		):
			light_flicker.start_panic_flicker()

	if blackout_delay > 0.0:
		await get_tree().create_timer(
			blackout_delay,
			false
		).timeout

	for light_flicker: TrainLightFlicker in (
		train_light_flickers
	):
		if (
			light_flicker != null
			and is_instance_valid(light_flicker)
		):
			light_flicker.blackout_with_final_flicker(
				final_flicker_time
			)

	if final_flicker_time > 0.0:
		await get_tree().create_timer(
			final_flicker_time,
			false
		).timeout

	var remaining_slowdown_time: float = maxf(
		slowdown_time
		- blackout_delay
		- final_flicker_time,
		0.0
	)

	if remaining_slowdown_time > 0.0:
		await get_tree().create_timer(
			remaining_slowdown_time,
			false
		).timeout

	_finish_scenery_stop()

	await _wait_for_brake_animation()
	await _fade_screen_to_black()

	if screen_blackout_hold_duration > 0.0:
		await get_tree().create_timer(
			screen_blackout_hold_duration,
			false
		).timeout

	_hold_narration_for_scene_change()


# ============================================================
# SCENERY BRAKING
# ============================================================

func _begin_scenery_slowdown(duration: float) -> void:
	if scenery_loop == null:
		return

	if scenery_loop.has_method("smooth_stop"):
		scenery_loop.call(
			"smooth_stop",
			duration
		)
		return

	if not _node_has_property(
		scenery_loop,
		&"movement_speed"
	):
		push_warning(
			"MenuController: SceneryLoop has no smooth_stop() "
			+ "method or movement_speed property."
		)
		return

	if scenery_slowdown_tween != null:
		if scenery_slowdown_tween.is_valid():
			scenery_slowdown_tween.kill()

	var current_speed: float = float(
		scenery_loop.get("movement_speed")
	)

	if duration <= 0.0:
		_set_scenery_loop_speed(0.0)
		return

	scenery_slowdown_tween = create_tween()

	scenery_slowdown_tween.tween_method(
		_set_scenery_loop_speed,
		current_speed,
		0.0,
		duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)


func _set_scenery_loop_speed(speed: float) -> void:
	if scenery_loop == null:
		return

	if scenery_loop.has_method("set_loop_speed"):
		scenery_loop.call(
			"set_loop_speed",
			speed
		)
		return

	if _node_has_property(
		scenery_loop,
		&"movement_speed"
	):
		scenery_loop.set(
			"movement_speed",
			speed
		)


func _finish_scenery_stop() -> void:
	if scenery_loop == null:
		return

	if scenery_loop.has_method("stop_immediate"):
		scenery_loop.call("stop_immediate")
		return

	if scenery_loop.has_method("set_loop_speed"):
		scenery_loop.call(
			"set_loop_speed",
			0.0
		)
		return

	if _node_has_property(
		scenery_loop,
		&"movement_speed"
	):
		scenery_loop.set(
			"movement_speed",
			0.0
		)

	if _node_has_property(
		scenery_loop,
		&"active"
	):
		scenery_loop.set(
			"active",
			false
		)


func _node_has_property(
	object: Object,
	property_name: StringName
) -> bool:
	if object == null:
		return false

	for property_data: Dictionary in object.get_property_list():
		var found_name := StringName(
			property_data.get("name", "")
		)

		if found_name == property_name:
			return true

	return false


# ============================================================
# SCREEN BLACKOUT
# ============================================================

func _fade_screen_to_black() -> void:
	if blackout_rect == null:
		return

	blackout_rect.visible = true
	blackout_rect.color = Color.BLACK

	var fade_duration: float = maxf(
		screen_blackout_fade_duration,
		0.0
	)

	if fade_duration <= 0.0:
		blackout_rect.modulate.a = 1.0
		return

	var tween: Tween = create_tween()

	tween.tween_property(
		blackout_rect,
		"modulate:a",
		1.0,
		fade_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished


# ============================================================
# RESPONSIVE UI
# ============================================================

func _connect_viewport() -> void:
	var viewport: Viewport = get_viewport()

	if viewport == null:
		return

	if not viewport.size_changed.is_connected(
		_apply_responsive_ui
	):
		viewport.size_changed.connect(
			_apply_responsive_ui
		)

	if not GameSettings.ui_size_changed.is_connected(_on_ui_size_changed):
		GameSettings.ui_size_changed.connect(_on_ui_size_changed)


func _on_ui_size_changed(_size_index: int) -> void:
	_apply_responsive_ui()


func _apply_responsive_ui() -> void:
	var viewport: Viewport = get_viewport()

	if viewport == null:
		return

	var viewport_size: Vector2 = (
		viewport.get_visible_rect().size
	)

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var width_scale: float = (
		viewport_size.x / reference_resolution.x
	)

	var height_scale: float = (
		viewport_size.y / reference_resolution.y
	)

	var ui_scale: float = clampf(
		minf(width_scale, height_scale),
		min_ui_scale,
		max_ui_scale
	)

	# The base sizes are the Large UI size's; the player's UI size (UIConfig) scales them down.
	var large: Dictionary = UIConfig.UI_SIZES[UIConfig.UI_SIZES.size() - 1]
	var title_size: int = int(
		round(
			float(title_base_font_size)
			* ui_scale
			* float(UIConfig.font_size_title) / float(large["title"])
		)
	)

	var button_size: int = int(
		round(
			float(button_base_font_size)
			* ui_scale
			* float(UIConfig.font_size_button) / float(large["button"])
		)
	)

	if title_label != null:
		title_label.add_theme_font_size_override(
			"font_size",
			title_size
		)

	if new_game_button != null:
		new_game_button.add_theme_font_size_override(
			"font_size",
			button_size
		)

	if load_game_button != null:
		load_game_button.add_theme_font_size_override(
			"font_size",
			button_size
		)

	if options_button != null:
		options_button.add_theme_font_size_override(
			"font_size",
			button_size
		)

	if quit_button != null:
		quit_button.add_theme_font_size_override(
			"font_size",
			button_size
		)


# ============================================================
# SCENE CHANGE
# ============================================================

func _open_playable_scene() -> void:
	if scene_change_requested:
		return

	if playable_scene_path.strip_edges().is_empty():
		push_error(
			"MenuController: Playable scene path is empty."
		)
		transition_running = false
		_reset_cinematic_skip()
		return

	if cinematic_skip_prompt != null:
		cinematic_skip_prompt.hide()

	scene_change_requested = true
	scene_change_fade_finished = false
	_start_playable_scene_preload()

	if blackout_rect == null:
		_on_scene_change_fade_finished()
		return

	blackout_rect.visible = true
	blackout_rect.color = Color.BLACK

	if blackout_rect.modulate.a >= 0.99:
		blackout_rect.modulate.a = 1.0
		_on_scene_change_fade_finished()
		return

	var blackout_tween: Tween = create_tween()
	blackout_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	blackout_tween.tween_property(
		blackout_rect,
		"modulate:a",
		1.0,
		0.12
	)
	blackout_tween.finished.connect(
		_on_scene_change_fade_finished
	)


func _start_playable_scene_preload() -> void:
	if playable_scene_load_started:
		return

	if loaded_playable_scene != null:
		return

	var target_path: String = playable_scene_path.strip_edges()

	if target_path.is_empty():
		return

	playable_scene_load_path = target_path

	var existing_status: ResourceLoader.ThreadLoadStatus = (
		ResourceLoader.load_threaded_get_status(target_path)
	)

	if existing_status == ResourceLoader.THREAD_LOAD_LOADED:
		_store_loaded_playable_scene()
		return

	if existing_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		playable_scene_load_started = true
		return

	var request_result: Error = ResourceLoader.load_threaded_request(
		target_path,
		"PackedScene",
		false
	)

	if request_result == OK:
		playable_scene_load_started = true
		return

	playable_scene_load_failed = true
	push_error(
		"MenuController: Failed to begin loading '%s'. Error: %s"
		% [target_path, error_string(request_result)]
	)


func _update_playable_scene_preload() -> void:
	if not playable_scene_load_started:
		return

	if playable_scene_load_failed:
		return

	if loaded_playable_scene != null:
		return

	var load_status: ResourceLoader.ThreadLoadStatus = (
		ResourceLoader.load_threaded_get_status(
			playable_scene_load_path
		)
	)

	match load_status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_store_loaded_playable_scene()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			playable_scene_load_failed = true
			push_error(
				"MenuController: Background loading failed for '%s'."
				% playable_scene_load_path
			)


func _store_loaded_playable_scene() -> void:
	var loaded_resource: Resource = ResourceLoader.load_threaded_get(
		playable_scene_load_path
	)

	loaded_playable_scene = loaded_resource as PackedScene
	playable_scene_load_started = true

	if loaded_playable_scene == null:
		playable_scene_load_failed = true
		push_error(
			"MenuController: Loaded resource '%s' is not a PackedScene."
			% playable_scene_load_path
		)


func _on_scene_change_fade_finished() -> void:
	scene_change_fade_finished = true
	_advance_playable_scene_change()


func _advance_playable_scene_change() -> void:
	if not scene_change_requested:
		return

	if not scene_change_fade_finished:
		return

	if playable_scene_load_failed:
		_recover_from_playable_scene_load_failure()
		return

	if loaded_playable_scene == null:
		if cinematic_loading_label != null:
			cinematic_loading_label.show()
		return

	if cinematic_loading_label != null:
		cinematic_loading_label.hide()

	scene_change_requested = false
	if reveal_loaded_scene_after_change:
		SceneTransition.cover_next_scene()

	var result: Error = get_tree().change_scene_to_packed(
		loaded_playable_scene
	)

	if result != OK:
		push_error(
			"MenuController: Failed to open '%s'. Error: %s"
			% [
				playable_scene_path,
				error_string(result)
			]
		)

		_recover_from_playable_scene_load_failure()


func _recover_from_playable_scene_load_failure() -> void:
	_stop_intro_narration_if_running()
	transition_running = false
	reveal_loaded_scene_after_change = false
	SceneTransition.cancel_transition()
	_reset_playable_scene_load()
	_reset_cinematic_skip()
	SaveManager.suspend_session(false)
	playable_scene_path = new_game_scene_path

	if cinematic_loading_label != null:
		cinematic_loading_label.hide()

	if blackout_rect != null:
		blackout_rect.modulate.a = 0.0

	if main_menu_ui != null:
		main_menu_ui.show()
		main_menu_ui.modulate = Color.WHITE

	if left_panel != null:
		left_panel.show()
		left_panel.modulate = Color.WHITE

	_set_main_menu_buttons_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _reset_playable_scene_load() -> void:
	playable_scene_load_path = ""
	playable_scene_load_started = false
	playable_scene_load_failed = false
	loaded_playable_scene = null
	scene_change_requested = false
	scene_change_fade_finished = false
