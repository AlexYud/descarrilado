extends Node
class_name DreamFinale

## The end of the dream intro: what happens as the call at the overlook ends.
##
## 1. **The lights go out.** While the call nears its end (`phone.call_ending`) the town's lights go out ONE BY ONE,
##    suddenly (each stutters for a moment and is gone for good, in no tidy order), the street lamp dies and the
##    world's light drains, so that the last light dies as the call ends (`phone.line_cut`) while the shot is still
##    pushing in, and the screen is black. In complete silence, `dark_hold_seconds` of nothing.
## 2. **The wagon.** The picture fades in slowly with heavy lids, as if Juliana were waking up: she wakes on the bench
##    where the dream began (the dream intro's own head-raise animation, nothing can be done) and gets to her
##    feet in the aisle. The ceiling lights only stutter, the flashlight is weak, the way
##    out behind is locked, and at the far end of the aisle, against the north wall, a girl (Sophia) sits on the
##    floor hugging her knees, crying, her back to the aisle, a little lit so she can be seen from where
##    Juliana wakes. The player can only walk, slowly, forward and back along the aisle, and look around.
## 3. **The cutscene.** About `cutscene_distance` from her the player loses control: Juliana walks on by herself
##    for a second, a whisper comes from right behind her head (a caption: "You're not supposed to be
##    here."), she flinches and turns round, scared, to see who it was: the wagon behind is
##    empty. She turns back: the girl is gone (nothing is left in her place). She searches the spot with the
##    flashlight, and turns towards the exit, where the player gets the controls back.
## 4. **The door** (`FinaleDoorScene`). The player walks the aisle themselves, slowly, to the wagon's black
##    corridor door. When they are near and looking at it a pale head swings in over it (the only sound of the scene is its sting,
##    besides their footsteps), Juliana jumps and falls twisting away onto all fours, crawls, something takes her foot, and she
##    fights it by pressing the interact key (she cannot win); then two hands close on her face.
## 5. **The end.** The picture goes black, in silence, for `black_hold_seconds`, then the UNRAILED title card in the palette,
##    plain like the menu's, and back to the main menu. The save is marked `demo_complete` and keeps the player at the overlook
##    with the three fichas in the slot, so Continue lets them make the call again.
##
## Everything is placeholder art (the girl, the head and the hands are made in code). The girl's crying (`placeholder_crying_woman`)
## loops from her own place, in 3D, so it grows as the player nears her and stops when she is gone; besides it the rain and the whisper
## are text only, and the other sounds are the player's footsteps and the sting of the head.

## The title card has been shown and the game is about to return to the menu.
signal finished
signal title_shown
## The player is on their feet and has the controls (after the wake-up animation).
signal player_released
## The cutscene at the girl's place is over and the player has the controls back, facing the exit.
signal cutscene_ended

enum Stage {
	IDLE,
	BLACKOUT,
	APPROACH,
	CUTSCENE,
	LEAVING,
	DOOR,
	GRABBED,
	TITLE,
	DONE,
}

const STATE_SECTION: StringName = &"puzzles"
const KEY_DEMO_COMPLETE: StringName = &"demo_complete"
const KEY_CALL_DONE: StringName = &"orelhao_call_done"
const LINE_WHISPER: String = "CAPTION_WAGON_WHISPER"
## The girl's crying, looped, from where she sits (3D: louder the nearer the player is).
## How long the last light takes to stutter out (five steps of 0.09 s).
const LAST_LIGHT_OUT_SECONDS: float = 0.45
## The highest moment (of the blackout, 0 to 1) at which any light but the last goes out (`_light_rank`).
const LAST_ORDINARY_RANK: float = 0.92
const TENSION_PATH: String = "res://assets/audios/placeholder_string_tension.mp3"
const CRYING_PATH: String = "res://assets/audios/placeholder_crying_woman.mp3"
const CRYING_DB: float = -3.0
const CRYING_UNIT_SIZE: float = 3.0
const CRYING_MAX_DISTANCE: float = 45.0
## A lit box of the town's lit-windows mesh is 12 triangles of 3 vertices.
const VERTICES_PER_BOX: int = 36
## Before a light goes out for good it stutters for this much of the whole blackout.
const STUTTER_SPAN: float = 0.05

const WINDOW_SHADER: String = "shader_type spatial;
uniform float out_progress = 0.0;
uniform float energy = 4.5;
uniform float stutter = 0.05;
uniform float last_on = 1.0;
uniform float last_boost = 1.0;
varying float v_rank;
void vertex() {
	v_rank = COLOR.a;
}
void fragment() {
	float on = step(out_progress, v_rank);
	float shaking = step(v_rank - stutter, out_progress) * step(out_progress, v_rank);
	float flick = step(0.5, fract(TIME * 11.0 + v_rank * 37.0));
	on *= mix(1.0, flick, shaking);
	// The one window left to the end (its moment is 1.0) is on as long as `last_on` says.
	on = mix(on, last_on, step(0.99, v_rank));
	ALBEDO = COLOR.rgb * on;
	EMISSION = COLOR.rgb * energy * on * mix(1.0, last_boost, step(0.99, v_rank));
	ROUGHNESS = 1.0;
}
"

@export_category("Scene")
## The overlook payphone: `call_ending` starts the town's lights going out and `line_cut` (the voice has stopped;
## the view is still on the city) ends it in the dark.
@export var phone: OverlookPhoneSequence
## The node that has the night environment script (its `blackout` takes the light out of the world).
@export var night: Node
## The town in the valley (its `NightGlow` halos and its lit windows go out).
@export var town: Node3D
## The wagon the finale happens in.
@export var wagon: Node3D
## Set when the player is not the node found by group "player".
@export var player: Node3D
@export_file("*.tscn") var main_menu_path: String = "res://scenes/menu/main_menu.tscn"
## Off, the finale ends with `finished` and stays where it is (for tests).
@export var change_scene_at_end: bool = true
## The scene the saved snapshot belongs to; empty is the running scene.
@export var save_scene_path: String = ""

@export_category("Blackout")
## How long the lights take to go out when the finale is started by hand (`start`); with the call it is the time
## left of the call when it announces its end.
@export var blackout_seconds: float = 7.0
## The streetlamp dies this far through the blackout (0 to 1).
@export_range(0.0, 1.0, 0.05) var lamp_dies_at: float = 0.7
## One window light of the town is left lit (the one nearest the middle of the shot) this long after the call ends,
## then it goes out like the others and everything is black.
@export var last_light_seconds: float = 1.5
## The one window left lit is drawn this many times bigger and glows this many times stronger than the others (and its halo this many times
## bigger), from the cut to the call's view on, so it can still be seen on the lowest quality.
@export var last_light_scale: float = 4.0
@export var last_light_glow: float = 2.2
@export var last_halo_scale: float = 1.8
## Seconds into the horror transition's sound when only the last window is left lit.
@export var transition_others_out_seconds: float = 6.0
## With the horror transition playing (it starts with the blackout), the last light is left on until its sound has run
## `OverlookPhoneSequence.transition_sound_seconds` and goes out then, whatever `last_light_seconds` says.
## Pitch black, before the player is moved.
@export var dark_hold_seconds: float = 2.0
## The wagon fades in from black this slowly (with heavy lids: it opens, droops, opens again).
@export var wagon_fade_in_seconds: float = 8.0
## The player wakes up with the dream intro's head-raise animation, without control, before walking.
@export var wake_up_animation: bool = true
## The wake-up animation is played at this fraction of its speed: she gets up slowly and heavily.
@export_range(0.2, 1.0, 0.05) var wake_up_speed: float = 0.55

@export_category("Wagon")
## In the wagon's own space (X across, Z along the aisle): where the player appears (the very spot the
## dream began at), and the floor point where the girl sits.
@export var wagon_start_local: Vector3 = Vector3(-0.18, 0.7657, 3.1)
@export var sophia_local: Vector3 = Vector3(0.0, 0.073, -5.5)
## The middle of the aisle (wagon-local X): the wagon is symmetrical and the aisle between the benches is about
## 1 m wide, so it is 0. The player walks along it.
@export var aisle_x: float = 0.0
## How far back the player can walk (the locked door) and how close to her (the walk ends there; the cutscene
## starts before).
@export var back_limit: float = 0.5
@export var stop_before_sophia: float = 0.9
## Where she sits at the end of the aisle (wagon-local): the X of her middle (the aisle is 1.08 m wide, the benches' ends at -0.54 and 0.54, so
## this is a little past its left edge, in the corner behind the first bench, almost hidden: the player hears her to the left before seeing her), the end wall's Z, and how far from the wall she sits.
@export var girl_x: float = -0.85
@export var girl_end_wall_z: float = -6.068
@export var girl_wall_gap: float = 0.03
## The cutscene begins the moment the player can see her (the bench backs hide her from the aisle until the last row of benches, about
## 1.5 m from the end of the aisle), if they are within `cutscene_sight_distance` of the end of the aisle; at the latest when they are within
## `cutscene_distance` of it (where the walk ends, `stop_before_sophia`). Juliana stands and looks at her back, then walks on for
## `cutscene_walk_seconds` and hears the whisper.
@export var cutscene_distance: float = 1.1
@export var cutscene_sight_distance: float = 3.5
@export var cutscene_walk_seconds: float = 0.8
## `placeholder_string_tension` comes in this long after the whisper, fading in over `tension_in_seconds` to `tension_db`, and goes out as the
## controls come back (`tension_out_seconds`).
@export var tension_after_whisper_seconds: float = 0.5
@export var tension_in_seconds: float = 1.5
@export var tension_db: float = -3.0
@export var tension_out_seconds: float = 3.0
## The shot of her back: the view settles on her (`reveal_turn_seconds`) and holds quite still `reveal_hold_seconds`, her back heaving in a
## weak light that keeps failing (`reveal_torch_level` of its strength, dipping and cutting out), before she walks on and hears the whisper.
@export var reveal_turn_seconds: float = 1.3
@export var reveal_hold_seconds: float = 2.8
@export_range(0.05, 1.0, 0.05) var reveal_torch_level: float = 0.5
## The ceiling lights are dim, cold and always stuttering (the wagon is dark and the girl is not lit by anything
## of her own). The flashlight is a fraction of its usual strength.
@export var wagon_light_color: Color = Color(0.72, 0.82, 1.0)
@export var wagon_light_energy: float = 0.1
@export_range(0.05, 1.0, 0.05) var flashlight_strength: float = 0.3
@export var flashlight_range: float = 9.0
## How fast the player walks in the aisle, as a fraction of the usual pace (and no sprinting): slowly, to build the tension.
@export_range(0.2, 1.0, 0.05) var wagon_walk_scale: float = 0.45
## The player is wider than the aisle between the benches (the capsule is 1 m across, the aisle about 1 m with
## seats that stick out), so it pushed them off the middle. In the wagon the capsule is this thin, and put back after.
@export var wagon_player_radius: float = 0.12

@export_category("The end")
## The picture is black, and silent, this long before the title card.
@export var black_hold_seconds: float = 1.5
@export var title_fade_in_seconds: float = 1.4
@export var title_hold_seconds: float = 3.2
@export var title_fade_out_seconds: float = 1.0

var stage: Stage = Stage.IDLE
var _cry: AudioStreamPlayer3D = null
var _tension: AudioStreamPlayer = null

var _player: Node3D = null
var _snapshot: Dictionary = {}
var _master_db: float = 0.0
var _master_saved: bool = false
var _sophia: Node3D = null
var _girl: CryingGirl = null
var _wagon_lights: Array[OmniLight3D] = []
var _light_time: float = 0.0
var _light_timers: Array[float] = []
var _light_levels: Array[float] = []
var _flashlight_before: Dictionary = {}
var _player_radius_before: float = -1.0
var _corridor_length: float = 0.0
var _corridor_start: Vector3 = Vector3.ZERO
var _corridor_axis: Vector3 = Vector3.FORWARD
var _aisle_end: Vector3 = Vector3.ZERO
var _auto_walking: bool = false
var _beam_shaking: bool = false
var _beam_fear: float = 0.4
## Where the beam is sent while `_beam_goal_on` (x: a view yaw, y: a view pitch, both in the movement controller's
## degrees, positive pitch is down): the beam goes there whatever the view does, so she can point it first and
## turn her head after. While `_beam_track_on` it follows `_beam_track_point` instead.
var _beam_goal_on: bool = false
var _beam_goal: Vector2 = Vector2.ZERO
var _beam_track_on: bool = false
var _beam_track_point: Vector3 = Vector3.ZERO
var _beam_tween: Tween = null
## How fast the beam follows its goal, as a multiple of the usual.
var _beam_speed: float = 2.0
var _door_scene: FinaleDoorScene = null
var _exit_light_dead: bool = false
var _step_clock: float = 0.0
var _black_layer: CanvasLayer = null
var _black_rect: ColorRect = null
var _lights_tween: Tween = null
var _lights_out_started: bool = false

# The city going out.
var _glow: MultiMeshInstance3D = null
var _glow_base: PackedFloat32Array = PackedFloat32Array()
var _glow_stride: int = 16
var _glow_rank: PackedFloat32Array = PackedFloat32Array()
var _window_materials: Array[ShaderMaterial] = []
var _last_light_world: Vector3 = Vector3.ZERO
var _has_last_light: bool = false
var _lights_out_msec: int = 0
var _torch_failing: bool = false
var _dip_wait: float = 0.5
var _dip_left: float = 0.0
var _dip_level: float = 1.0
var _dip_drift: float = 1.0
var _town_prepared: bool = false
var _last_on: float = 1.0
var _windows: Array[Dictionary] = []


func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	if phone != null:
		# The phone keeps its view on the city, zooming, until this finale ends it in the dark.
		phone.finale_takes_over = true
		phone.call_ending.connect(begin_lights_out)
		phone.call_view_started.connect(_on_call_view_started)
		phone.line_cut.connect(_on_line_cut)


func _exit_tree() -> void:
	_stop_failing_the_torch()
	_stop_tension(0.0)
	_silence_outside(false)
	_set_filter_darkness(0.0)
	_stop_beam_script()
	_restore_master()
	_restore_flashlight()
	_restore_player_shape()


# ============================================================
# 1. THE LIGHTS GO OUT
# ============================================================

## Begins the finale by hand (a test or the developer console): the lights go out over `blackout_seconds`, then
## everything goes black as if the call had just ended.
func start() -> void:
	if stage != Stage.IDLE:
		return

	begin_lights_out(blackout_seconds, false)
	await _lights_tween.finished
	_on_line_cut()


## The town's lights start going out, one by one, so that the last one dies `seconds` from now. With the call's horror transition (which
## starts with this) all the others are out `transition_others_out_seconds` into its sound, whatever `seconds` says, and one window is
## left lit from then on.
func begin_lights_out(seconds: float, fit_to_transition: bool = true) -> void:
	if _lights_out_started or stage != Stage.IDLE:
		return

	if fit_to_transition and phone != null and phone.finale_takes_over and phone.transition_audio != null:
		seconds = transition_others_out_seconds / LAST_ORDINARY_RANK

	_lights_out_started = true
	_lights_out_msec = Time.get_ticks_msec()
	stage = Stage.BLACKOUT
	_player = _get_player()
	if _player != null and _player.has_method("get_manual_save_state"):
		_snapshot = _player.call("get_manual_save_state")

	_cancel_the_opening()
	_set_saving_blocked(true)
	_cut_flashlight(false)
	_hide_flashlight_hint()
	_prepare_town_dimmer()

	_master_db = AudioServer.get_bus_volume_db(0)
	_master_saved = true
	_lights_tween = create_tween()
	_lights_tween.tween_method(_set_blackout_progress, 0.0, 1.0, maxf(seconds, 0.05))
	_lamp_dies_later(maxf(seconds, 0.05))


## The call is over: the last light is out, the picture is black and silent, then the wagon.
func _on_line_cut() -> void:
	if stage != Stage.IDLE and stage != Stage.BLACKOUT:
		return

	if stage == Stage.IDLE:
		begin_lights_out(0.05, false)

	if _lights_tween != null and _lights_tween.is_valid():
		_lights_tween.kill()

	_set_blackout_progress(1.0)
	# The horror transition (started with the blackout) is not cut off: the world outside goes quiet at once, and everything once it ends.
	var transition: AudioStreamPlayer = phone.transition_player if phone != null else null
	var transition_on: bool = transition != null and is_instance_valid(transition) and transition.playing
	if transition_on:
		_silence_outside(true)
		transition.finished.connect(_quiet_master)
	else:
		_quiet_master()
	# One window stays lit for a moment, alone in the dark, and then it goes out like the others: with the transition sound's end
	# (`transition_sound_seconds` after it began with the blackout), or `last_light_seconds` after the call when there is none.
	if _has_last_light:
		var hold: float = last_light_seconds
		if transition_on:
			var sound_elapsed: float = float(Time.get_ticks_msec() - _lights_out_msec) / 1000.0
			hold = maxf(phone.transition_sound_seconds - sound_elapsed - LAST_LIGHT_OUT_SECONDS, 0.3)
		await _wait(hold * Engine.time_scale)
		await _put_out_the_last_light()
		await _wait(0.7)

	# The picture is covered at once, so nothing can show through when the view changes.
	_make_black(1.0)
	await _wait(dark_hold_seconds)
	_enter_wagon()


func _quiet_master() -> void:
	if stage == Stage.IDLE:
		return
	var quiet: Tween = create_tween()
	quiet.tween_method(_set_master_db, AudioServer.get_bus_volume_db(0), -80.0, 0.25)


## The last window light stutters and goes out for good (`LAST_LIGHT_OUT_SECONDS`).
func _put_out_the_last_light() -> void:
	for level: float in [0.0, 1.0, 0.0, 1.0, 0.0]:
		_last_on = level
		_dim_town(1.0)
		await _wait(0.09)

	_last_on = 0.0
	_dim_town(1.0)


## For testing and the developer console: goes straight into the dark wagon (the blackout is already over).
func start_in_wagon() -> void:
	if stage != Stage.IDLE:
		return

	_cancel_the_opening()
	_player = _get_player()
	if _player != null and _player.has_method("get_manual_save_state"):
		_snapshot = _player.call("get_manual_save_state")

	_set_saving_blocked(true)
	_set_blackout_progress(1.0)
	_make_black(1.0)
	_enter_wagon()


func _lamp_dies_later(total: float) -> void:
	await _wait(total * lamp_dies_at)
	if phone != null and phone.lamp != null:
		phone.lamp.play_flicker(&"die")


func _set_blackout_progress(progress: float) -> void:
	if night != null:
		night.set("blackout", progress)

	# The camcorder look (grain, lifted blacks) goes with the light, so the end of it is as black as the black screen.
	_set_filter_darkness(progress)

	_dim_town(progress)


func _set_master_db(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)


## The picture filter's camcorder look, taken out by `amount` (0 gives it back).
func _set_filter_darkness(amount: float) -> void:
	var filter: Node = get_node_or_null("/root/HorrorFilter")
	if filter != null and filter.has_method("set_darkness"):
		filter.call("set_darkness", amount)


func _silence_outside(on: bool) -> void:
	if is_inside_tree():
		get_tree().call_group(OutdoorAmbience.GROUP, "set_silenced", &"finale_wagon", on)


func _restore_master() -> void:
	if _master_saved:
		AudioServer.set_bus_volume_db(0, _master_db)
		_master_saved = false


## When (0 to 1 through the blackout) the light at `point` goes out: far ones tend to go first, with a lot of
## chance in it, so it never looks like a wave, only like the town dying light by light. The same function
## serves a window's glowing box and its halo, so they go out together.
func _light_rank(point: Vector3, viewer: Vector3) -> float:
	var distance: float = point.distance_to(viewer)
	var far: float = clampf((distance - 250.0) / 450.0, 0.0, 1.0)
	var chance: float = fposmod(sin(point.x * 12.9898 + point.z * 78.233 + point.y * 37.719) * 43758.5453, 1.0)
	return 0.06 + 0.86 * clampf(0.35 * (1.0 - far) + 0.65 * chance, 0.0, 1.0)


## 1 while the light is on; it stutters just before its moment and is 0 from then on.
func _halo_on(progress: float, rank: float) -> float:
	if rank > 0.99:
		return _last_on

	if progress >= rank:
		return 0.0

	if progress > rank - STUTTER_SPAN:
		return 1.0 if int(Time.get_ticks_msec() / 70.0 + rank * 1000.0) % 2 == 0 else 0.0

	return 1.0


## Gets the town's lights ready to go out: the halo billboards (one multimesh, each with its own colour, switched
## off at its own moment) and the lit windows and lamps (one mesh whose boxes get the same moments in their
## vertex alpha, drawn by a shader that cuts each one at its moment). Nothing shared is ever changed: both are copied.
## The picture has cut to the call's view of the town: its lights are made ready now, so the last window is in the shot from the first
## moment, a little bigger and brighter than the others, as it will be to the end (the cut hides the change).
func _on_call_view_started() -> void:
	await get_tree().process_frame
	_prepare_town_dimmer()


func _prepare_town_dimmer() -> void:
	if town == null or _town_prepared:
		return

	_town_prepared = true
	if _player == null:
		_player = _get_player()
	var viewer: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	_prepare_glow(viewer)
	_prepare_windows(viewer)
	_dim_town(0.0)


func _prepare_windows(viewer: Vector3) -> void:
	_window_materials.clear()
	_windows.clear()
	var meshes: Array[Node] = town.find_children("*", "MeshInstance3D", true, false)
	for node: Node in meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.get_active_material(surface)
			if not (source is StandardMaterial3D and (source as StandardMaterial3D).emission_enabled):
				continue

			var standard: StandardMaterial3D = source as StandardMaterial3D
			var shader_material: ShaderMaterial = _ranked_lit_material(mesh_instance, surface, standard, viewer)
			if shader_material != null:
				_window_materials.append(shader_material)
				continue

			# No per-box data to be had (no renderer): the whole mesh just dims.
			var copy_material: StandardMaterial3D = standard.duplicate() as StandardMaterial3D
			if mesh_instance.material_override != null:
				mesh_instance.material_override = copy_material
			else:
				mesh_instance.set_surface_override_material(surface, copy_material)
			_windows.append({"material": copy_material, "energy": copy_material.emission_energy_multiplier})


## A copy of a lit-boxes mesh whose every box carries its moment in the vertex alpha, with the shader that
## switches each off; null when the mesh data cannot be read (the headless renderer keeps none).
func _ranked_lit_material(mesh_instance: MeshInstance3D, surface: int, standard: StandardMaterial3D, viewer: Vector3) -> ShaderMaterial:
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
	if arrays.size() <= Mesh.ARRAY_COLOR or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_COLOR] == null:
		return null

	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if vertices.is_empty() or colors.size() != vertices.size() or vertices.size() % VERTICES_PER_BOX != 0:
		return null

	# Sanity: each group of vertices must be one small box.
	var boxes: int = floori(float(vertices.size()) / float(VERTICES_PER_BOX))
	var transform: Transform3D = mesh_instance.global_transform
	for check: int in mini(boxes, 40):
		var low: Vector3 = vertices[check * VERTICES_PER_BOX]
		var high: Vector3 = low
		for k: int in VERTICES_PER_BOX:
			var v: Vector3 = vertices[check * VERTICES_PER_BOX + k]
			low = low.min(v)
			high = high.max(v)

		if (high - low).length() > 12.0:
			return null

	# The window nearest the middle of the shot is the one left lit to the end.
	var camera: Camera3D = get_viewport().get_camera_3d()
	var best_box: int = -1
	var best_angle: float = 999.0
	for box: int in boxes:
		var centre: Vector3 = Vector3.ZERO
		for k: int in VERTICES_PER_BOX:
			centre += vertices[box * VERTICES_PER_BOX + k]

		centre = transform * (centre / float(VERTICES_PER_BOX))
		var rank: float = _light_rank(centre, viewer)
		for k: int in VERTICES_PER_BOX:
			var colour: Color = colors[box * VERTICES_PER_BOX + k]
			colour.a = rank
			colors[box * VERTICES_PER_BOX + k] = colour

		if camera != null and camera.global_position.distance_to(centre) > 30.0:
			var angle: float = (-camera.global_basis.z).angle_to(centre - camera.global_position)
			if angle < best_angle:
				best_angle = angle
				best_box = box
				_last_light_world = centre

	if boxes > 10 and best_box >= 0 and best_angle < deg_to_rad(25.0):
		_has_last_light = true
		for k: int in VERTICES_PER_BOX:
			var colour: Color = colors[best_box * VERTICES_PER_BOX + k]
			colour.a = 1.0
			colors[best_box * VERTICES_PER_BOX + k] = colour

	if _has_last_light and boxes > 10:
		# The lonely window is made bigger, so it can be seen from this far, and square: its two long sides (a window's face; the third is its
		# thickness) both become the geometric mean of the two, times `last_light_scale`; the thickness is scaled the same.
		var local_centre: Vector3 = Vector3.ZERO
		var low: Vector3 = vertices[best_box * VERTICES_PER_BOX]
		var high: Vector3 = low
		for k: int in VERTICES_PER_BOX:
			var corner: Vector3 = vertices[best_box * VERTICES_PER_BOX + k]
			local_centre += corner
			low = low.min(corner)
			high = high.max(corner)

		local_centre /= float(VERTICES_PER_BOX)
		var half: Array[float] = [(high.x - low.x) * 0.5, (high.y - low.y) * 0.5, (high.z - low.z) * 0.5]
		var thin: int = 0
		for axis: int in 3:
			if half[axis] < half[thin]:
				thin = axis
		var face: Array[float] = []
		for axis: int in 3:
			if axis != thin:
				face.append(half[axis])
		var side: float = sqrt(face[0] * face[1]) * last_light_scale
		for k: int in VERTICES_PER_BOX:
			var at: int = best_box * VERTICES_PER_BOX + k
			var offset: Vector3 = vertices[at] - local_centre
			for axis: int in 3:
				offset[axis] = offset[axis] * last_light_scale if axis == thin else signf(offset[axis]) * side
			vertices[at] = local_centre + offset

		arrays[Mesh.ARRAY_VERTEX] = vertices

	arrays[Mesh.ARRAY_COLOR] = colors
	var copy_mesh: ArrayMesh = ArrayMesh.new()
	copy_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader: Shader = Shader.new()
	shader.code = WINDOW_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("energy", standard.emission_energy_multiplier)
	material.set_shader_parameter("stutter", STUTTER_SPAN)
	material.set_shader_parameter("last_boost", last_light_glow)
	material.set_shader_parameter("out_progress", 0.0)
	copy_mesh.surface_set_material(0, material)
	mesh_instance.mesh = copy_mesh
	# The town's own material is set on the instance and would win over the mesh's.
	mesh_instance.material_override = material
	return material


## The halo billboards: their multimesh is copied (the town's own data is never changed) and each halo gets
## its moment. Needs the multimesh's buffer, which only exists with a renderer; without one the halos are
## simply left alone.
func _prepare_glow(viewer: Vector3) -> void:
	_glow = town.find_child("NightGlow", true, false) as MultiMeshInstance3D
	_glow_base = PackedFloat32Array()
	if _glow == null or _glow.multimesh == null or not _glow.multimesh.use_colors:
		return

	# Without a renderer the multimesh keeps no buffer to dim (and copying it would only complain).
	if _glow.multimesh.buffer.is_empty():
		return

	var copy: MultiMesh = _glow.multimesh.duplicate() as MultiMesh
	_glow.multimesh = copy
	var count: int = copy.instance_count
	var base: PackedFloat32Array = copy.buffer.duplicate()
	_glow_stride = floori(float(base.size()) / float(maxi(count, 1)))
	if _glow_stride < 16:
		return

	_glow_base = base
	_glow_rank.resize(count)
	for i: int in count:
		var at: Vector3 = Vector3(_glow_base[i * _glow_stride + 3], _glow_base[i * _glow_stride + 7], _glow_base[i * _glow_stride + 11])
		_glow_rank[i] = _light_rank(_glow.to_global(at), viewer)

	if _has_last_light:
		var nearest: int = -1
		var nearest_distance: float = 4.0
		for i: int in count:
			var at: Vector3 = Vector3(_glow_base[i * _glow_stride + 3], _glow_base[i * _glow_stride + 7], _glow_base[i * _glow_stride + 11])
			var distance: float = _glow.to_global(at).distance_to(_last_light_world)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = i

		if nearest >= 0:
			_glow_rank[nearest] = 1.0
			# Its halo is made bigger (the basis of its transform in the buffer; the position stays).
			for row: int in 3:
				for column: int in 3:
					_glow_base[nearest * _glow_stride + row * 4 + column] *= last_halo_scale


## 0 (all lit) to 1 (all dark): each light goes out at its own moment.
func _dim_town(progress: float) -> void:
	if _glow != null and not _glow_base.is_empty():
		var buffer: PackedFloat32Array = _glow_base.duplicate()
		for i: int in _glow_rank.size():
			var alpha_at: int = i * _glow_stride + _glow_stride - 1
			buffer[alpha_at] = _glow_base[alpha_at] * _halo_on(progress, _glow_rank[i])
		_glow.multimesh.buffer = buffer

	for material: ShaderMaterial in _window_materials:
		material.set_shader_parameter("out_progress", progress)
		material.set_shader_parameter("last_on", _last_on)

	for window: Dictionary in _windows:
		(window["material"] as StandardMaterial3D).emission_energy_multiplier = float(window["energy"]) * (1.0 - clampf(progress * 1.5 - 0.2, 0.0, 1.0))


# ============================================================
# 2. THE WAGON
# ============================================================

func _enter_wagon() -> void:
	if wagon == null or _player == null:
		return

	if phone != null:
		phone.end_view_in_the_dark()

	stage = Stage.APPROACH
	_restore_master()
	# Only the girl crying is heard in the wagon: the wind and the night chorus are gone, not just muffled.
	_silence_outside(true)
	# The picture is black now: the camcorder look comes back under it.
	_set_filter_darkness(0.0)
	_prepare_wagon()

	var start_world: Vector3 = wagon.to_global(wagon_start_local)
	var sophia_world: Vector3 = wagon.to_global(sophia_local)
	# The walk runs along the middle of the aisle, from level with where they wake up.
	var aisle_start: Vector3 = wagon.to_global(Vector3(aisle_x, wagon_start_local.y, wagon_start_local.z))
	var along: Vector3 = Vector3(sophia_world.x - aisle_start.x, 0.0, sophia_world.z - aisle_start.z)
	var total: float = along.length()
	_corridor_length = total
	along = along.normalized()
	_corridor_start = aisle_start
	_corridor_axis = along
	_aisle_end = sophia_world

	_player.global_position = start_world
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO

	var movement: Node = _player.get("movement_controller") as Node
	var yaw_degrees: float = _yaw_towards(along)
	if movement != null:
		movement.call("lock_to_corridor", aisle_start, along, -back_limit, maxf(total - stop_before_sophia, 0.5))
		movement.set("corridor_speed_scale", wagon_walk_scale)

	if _player.has_method("release_movement_hold"):
		_player.call("release_movement_hold")

	# The flashlight stays off until the player is on their feet.
	_cut_flashlight(false)
	_hide_flashlight_hint()
	_weaken_flashlight()
	_narrow_player()

	set_physics_process(true)
	set_process(true)
	_fade_in_from_black()
	_wake_up(yaw_degrees)


## The view yaw (the movement controller's `look_yaw`, degrees) that looks along `direction`.
func _yaw_towards(direction: Vector3) -> float:
	return -rad_to_deg(atan2(-direction.x, -direction.z))


## The player wakes up where the dream began, lying on the bench: the dream intro's own head-raise animation
## (the view lifts from the seat and turns up to the aisle) plays and nothing can be done until it ends, then
## the controls are theirs (forward and back along the aisle, looking round).
func _wake_up(yaw_degrees: float) -> void:
	var movement: Node = _player.get("movement_controller") as Node
	var animation_player: AnimationPlayer = _player.get_node_or_null("Head/HeadRaiseAnimationPlayer") as AnimationPlayer
	var animated: bool = wake_up_animation and animation_player != null and animation_player.has_animation(&"HeadRaise")
	if animated:
		_player.call("set_cutscene_frozen", true)
		# Turned along the aisle (the body is turned; the animation owns the head until it ends).
		_player.rotation.y = deg_to_rad(-yaw_degrees)
		# Slowly and heavily: the animation is slowed right down.
		animation_player.speed_scale = wake_up_speed
		animation_player.play(&"HeadRaise")
		animation_player.seek(0.0, true)
		# As they get up they end in the middle of the aisle (they wake on the bench beside it).
		var from: Vector3 = wagon_start_local
		var to: Vector3 = Vector3(aisle_x, wagon_start_local.y, wagon_start_local.z)
		var slide: Tween = create_tween()
		slide.tween_interval(3.0 / wake_up_speed)
		# Only sideways: the height is the floor's business (forcing it every frame piled gravity up unseen, and the
		# moment the forcing stopped the player went straight through the floor).
		slide.tween_method(func(t: float) -> void: _move_sideways_to(from.lerp(to, t)), 0.0, 1.0, 3.2 / wake_up_speed)
		# Until it ends; never for ever (if the animation never reports, the player is freed anyway).
		var ended: Array[bool] = [false]
		animation_player.animation_finished.connect(func(_name: StringName) -> void: ended[0] = true, CONNECT_ONE_SHOT)
		var waited: float = 0.0
		while not ended[0] and waited < animation_player.current_animation_length / wake_up_speed + 3.0:
			await get_tree().process_frame
			waited += get_process_delta_time()

		if stage == Stage.IDLE or not is_inside_tree():
			return

		animation_player.stop()
		animation_player.speed_scale = 1.0
		slide.kill()

		_player.call("set_cutscene_frozen", false)
		_player.rotation.y = 0.0
		_move_sideways_to(Vector3(aisle_x, wagon_start_local.y, wagon_start_local.z))
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).velocity = Vector3.ZERO

	if movement != null:
		# The view must not move at the hand-over: the animation ends looking level along the aisle (the body turned to it), and the
		# player's own view (the head's yaw and the camera's pitch) takes it over exactly there. The head's yaw is set here and now,
		# not left to the movement controller's next physics step: in between, the picture is drawn with the body turned back to 0 and
		# the head not yet turned, a jump of the wagon's own angle.
		movement.set("look_yaw", yaw_degrees)
		movement.set("look_pitch", 0.0 if animated else -4.0)
		var head: Node3D = _player.get_node_or_null("Head") as Node3D
		if head != null:
			head.rotation.y = -deg_to_rad(yaw_degrees)

	# The flashlight is for the player to switch on (the hint says how).
	_allow_torch()
	player_released.emit()


## Puts the player at the wagon-local spot's X and Z, whatever height they are at.
func _move_sideways_to(local_spot: Vector3) -> void:
	var world: Vector3 = wagon.to_global(local_spot)
	_player.global_position.x = world.x
	_player.global_position.z = world.z


## The player may use the flashlight again, but it is not switched on for them: the hint says to.
func _allow_torch() -> void:
	var flashlight: Node = _player.get("flashlight_controller") as Node
	if flashlight == null or not flashlight.has_method("set_flashlight_input_enabled"):
		return

	flashlight.call("set_flashlight_input_enabled", true)
	if bool(flashlight.get("flashlight_on")):
		return

	for child: Node in get_parent().get_children():
		if child.has_method("show_flashlight_hint"):
			child.call("show_flashlight_hint")


## The flashlight on, weak; does nothing if it is already on.
func _switch_torch_on() -> void:
	var flashlight: Node = _player.get("flashlight_controller") as Node
	if flashlight == null or not flashlight.has_method("set_flashlight_input_enabled"):
		return

	flashlight.call("set_flashlight_input_enabled", true)
	if not bool(flashlight.get("flashlight_on")) and flashlight.has_method("turn_on"):
		flashlight.call("turn_on")

	# It is on now: the hint that says to switch it on goes.
	_hide_flashlight_hint()


## The picture opens like heavy lids: it opens, droops a little, opens again, droops, and then clears.
func _fade_in_from_black() -> void:
	if _black_rect == null:
		return

	var scale: float = wagon_fade_in_seconds / 5.0
	var lids: Tween = create_tween()
	lids.tween_property(_black_rect, "modulate:a", 0.5, 1.4 * scale).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	lids.tween_property(_black_rect, "modulate:a", 0.68, 0.6 * scale)
	lids.tween_property(_black_rect, "modulate:a", 0.25, 1.1 * scale).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	lids.tween_property(_black_rect, "modulate:a", 0.38, 0.4 * scale)
	lids.tween_property(_black_rect, "modulate:a", 0.0, 1.5 * scale).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## The wagon is nearly black (the ceiling lights only stutter), and a girl sits crying at the far end, lit by the
## nearest ceiling light and a pale glow of her own so that she can be seen from the far end of the aisle.
func _prepare_wagon() -> void:
	_wagon_lights.clear()
	var lights: Node = wagon.get_node_or_null("Lights")
	if lights != null:
		# The wagon's own flicker script (the dream intro's) must never put the old light back over this.
		if "blackout_active" in lights:
			lights.set("blackout_active", true)
			lights.set("flicker_enabled", false)

		for child: Node in lights.get_children():
			if child is OmniLight3D:
				var light: OmniLight3D = child as OmniLight3D
				light.visible = true
				light.light_color = wagon_light_color
				light.light_energy = 0.0
				_wagon_lights.append(light)
				_light_timers.append(0.0)
				_light_levels.append(0.0)

	# The scene at the corridor door (the head and the hands are in the wagon, the rest is its own node).
	if _door_scene != null and is_instance_valid(_door_scene):
		_door_scene.cleanup()
		if _door_scene.creature != null:
			_door_scene.creature.queue_free()

		_door_scene.queue_free()

	_door_scene = FinaleDoorScene.new()
	_door_scene.name = "DoorScene"
	add_child(_door_scene)
	_door_scene.setup(wagon, _player)
	_door_scene.scare_started.connect(func() -> void: stage = Stage.DOOR)
	_door_scene.captured.connect(_on_captured)

	_sophia = _build_sophia()
	# She sits at the far end of the aisle, on the left as the player walks up it (so the benches do not hide her), her knees almost touching
	# the end wall and her face to it, her back to the player (turned 180 degrees: her front is towards -Z).
	_sophia.rotation_degrees.y = 180.0
	var room: Rect2 = _girl.footprint
	_sophia.position = Vector3(girl_x + room.get_center().x, sophia_local.y, girl_end_wall_z + girl_wall_gap + room.end.y)
	wagon.add_child(_sophia)
	_start_crying()


## The girl: the rigged basic model squatting with her hands over her face (`CryingGirl`). Built facing +Z (`_prepare_wagon` turns her to
## face the wall); `_girl.sob` shakes her as she cries.
func _build_sophia() -> Node3D:
	_girl = CryingGirl.new()
	_girl.name = "Sophia"
	_girl.build()
	return _girl


## While `_beam_shaking` the flashlight shakes in a scared hand (more or less by `_beam_fear`), and goes where the
## goal sends it (`_beam_goal`, or the point being tracked) instead of where the view points.
func _drive_beam() -> void:
	if not _beam_shaking or not _beam_goal_on or _player == null or not is_instance_valid(_player):
		return

	var torch: Node = _player.get("flashlight_controller") as Node
	if torch == null:
		return

	var t: float = _light_time
	var tremble: Vector2 = Vector2(
		sin(t * 17.0) * 0.55 + sin(t * 9.3 + 1.3) * 0.7 + sin(t * 3.1) * 0.5,
		sin(t * 13.0 + 0.6) * 0.5 + cos(t * 7.1) * 0.6 + sin(t * 2.3 + 2.0) * 0.4
	)
	if _beam_track_on:
		_beam_goal = _angles_to(_beam_track_point)

	var yaw: float = _beam_goal.x + tremble.x * _beam_fear
	var pitch: float = _beam_goal.y + tremble.y * _beam_fear
	# The same convention as the view's: yaw is positive to the right, pitch is positive downwards.
	var level: Vector3 = Basis(Vector3.UP, -deg_to_rad(yaw)) * Vector3.FORWARD
	torch.set("scripted_aim_direction", level * cos(deg_to_rad(pitch)) + Vector3.DOWN * sin(deg_to_rad(pitch)))
	torch.set("scripted_aim_speed", _beam_speed)
	torch.set("scripted_aim_on", true)


## The view yaw and pitch (the movement controller's degrees, positive pitch is down) that point the flashlight at
## `point`, the yaw taken to the turn nearest to where the beam is now.
func _angles_to(point: Vector3) -> Vector2:
	var torch: Node3D = _player.get("flashlight_controller") as Node3D
	var from: Vector3 = torch.global_position if torch != null else _camera().global_position
	var direction: Vector3 = point - from
	var yaw: float = _yaw_towards(Vector3(direction.x, 0.0, direction.z))
	var movement: Node = _player.get("movement_controller") as Node
	var near: float = _beam_goal.x if _beam_goal_on else float(movement.get("look_yaw"))
	yaw += 360.0 * roundf((near - yaw) / 360.0)
	return Vector2(yaw, rad_to_deg(atan2(-direction.y, Vector2(direction.x, direction.z).length())))


## Sends the beam to `yaw` / `pitch` over `seconds` (it stops tracking anything).
func _aim_beam(yaw: float, pitch: float, seconds: float, trans: Tween.TransitionType = Tween.TRANS_SINE, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if _beam_tween != null and _beam_tween.is_valid():
		_beam_tween.kill()

	_beam_track_on = false
	_beam_tween = create_tween().set_trans(trans).set_ease(ease_type)
	_beam_tween.tween_property(self, "_beam_goal", Vector2(yaw, pitch), seconds)


## Sends the beam to a point of the world over `seconds`.
func _aim_beam_at(point: Vector3, seconds: float, trans: Tween.TransitionType = Tween.TRANS_SINE, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	var angles: Vector2 = _angles_to(point)
	_aim_beam(angles.x, angles.y, seconds, trans, ease_type)


## The beam stays on `point` from now on, whatever she does (she is walking, it keeps the girl in the light).
func _track_beam(point: Vector3) -> void:
	if _beam_tween != null and _beam_tween.is_valid():
		_beam_tween.kill()

	_beam_track_point = point
	_beam_track_on = true


## She points the light first and only then dares to turn her head to it: the beam goes to `yaw` / `pitch` over
## `beam_seconds`, the head follows `lag` seconds later and takes `head_seconds` (it looks less far down or up than
## the beam points).
func _point_then_look(movement: Node, yaw: float, pitch: float, beam_seconds: float, lag: float, head_seconds: float) -> void:
	_aim_beam(yaw, pitch, beam_seconds)
	await _wait(lag)
	await _look_to(movement, yaw, pitch * 0.5, head_seconds)


## The flashlight sputters for `seconds` (a bad contact), then is as it was.
func _flicker_torch(seconds: float) -> void:
	var torch: Node = _player.get("flashlight_controller") as Node
	if torch == null or not torch.has_method("begin_scripted_light") or not bool(torch.get("flashlight_on")):
		return

	torch.call("begin_scripted_light")
	var pattern: Array[float] = [0.0, 1.0, 0.15, 1.0, 0.0, 0.7, 0.0, 1.0]
	for level: float in pattern:
		if not is_inside_tree() or _player == null:
			break

		torch.call("set_scripted_light", level > 0.05, level)
		await _wait(seconds / float(pattern.size()))

	if is_instance_valid(torch):
		torch.call("end_scripted_light")


## The picture smears for a moment (the filter's unease pulse), as when the beam finds something it should not.
func _pulse_unease(amount: float, seconds: float) -> void:
	var filter: Node = get_node_or_null("/root/HorrorFilter")
	if filter != null and filter.has_method("pulse_unease"):
		filter.call("pulse_unease", amount, seconds)


## Each ceiling light is a failing bulb: it holds a dim level for a while, then stutters (dark, a
## weak flash, dark again) before settling. They are never in step with each other. The one nearest the girl
## (the last) is the strongest, and her own glow follows it.
func _flicker_lights(delta: float) -> void:
	for i: int in _wagon_lights.size():
		_light_timers[i] -= delta
		if _light_timers[i] <= 0.0:
			if randf() < 0.45:
				# A stutter: a very short beat, mostly dark.
				_light_timers[i] = randf_range(0.03, 0.16)
				_light_levels[i] = 0.0 if randf() < 0.7 else randf_range(0.5, 1.0)
			else:
				_light_timers[i] = randf_range(0.5, 2.6)
				# Between stutters it never stays dark for long: always some light.
				_light_levels[i] = randf_range(0.25, 0.5) if randf() < 0.2 else randf_range(0.5, 0.9)

		_wagon_lights[i].light_energy = wagon_light_energy * _light_levels[i]
		# The lamp over the exit door (the first) is dead for good once the girl has gone: the door is black.
		if i == 0 and _exit_light_dead:
			_wagon_lights[i].light_energy = 0.0


## While `_torch_failing` the flashlight on the girl is weak and never steady: a level that wanders, dips for a moment now and then (some
## of them near dark, some in pairs) and cuts out altogether, never twice alike.
func _fail_the_torch(delta: float) -> void:
	var torch: Node = _player.get("flashlight_controller") as Node if _player != null else null
	if torch == null or not torch.has_method("begin_scripted_light") or not bool(torch.get("flashlight_on")):
		return

	torch.call("begin_scripted_light")
	_dip_wait -= delta
	if _dip_left <= 0.0 and _dip_wait <= 0.0:
		_dip_left = randf_range(0.04, 0.35)
		_dip_level = 0.0 if randf() < 0.4 else randf_range(0.05, 0.3)
		_dip_wait = randf_range(0.06, 0.2) if randf() < 0.3 else randf_range(0.25, 1.6)
	_dip_drift = clampf(_dip_drift + randf_range(-0.07, 0.07), 0.6, 1.15)
	var level: float = reveal_torch_level * _dip_drift
	if _dip_left > 0.0:
		_dip_left -= delta
		level = reveal_torch_level * _dip_level
	torch.call("set_scripted_light", level > 0.02, level)


func _stop_failing_the_torch() -> void:
	if not _torch_failing:
		return

	_torch_failing = false
	var torch: Node = _player.get("flashlight_controller") as Node if _player != null and is_instance_valid(_player) else null
	if torch != null and torch.has_method("end_scripted_light"):
		torch.call("end_scripted_light")


## The flashlight is weak here (its strength and its reach are cut), and given back at the end.
func _weaken_flashlight() -> void:
	var flashlight: SpotLight3D = _player.get("flashlight_controller") as SpotLight3D
	if flashlight == null or not _flashlight_before.is_empty():
		return

	var fill: SpotLight3D = flashlight.get_node_or_null("FlashlightFill") as SpotLight3D
	_flashlight_before = {
		"energy": flashlight.light_energy,
		"range": flashlight.spot_range,
		"fill_energy": fill.light_energy if fill != null else 0.0,
	}
	flashlight.light_energy *= flashlight_strength
	flashlight.spot_range = minf(flashlight.spot_range, flashlight_range)
	if fill != null:
		fill.light_energy *= flashlight_strength


## The player's capsule is thinned for the aisle (see `wagon_player_radius`).
func _narrow_player() -> void:
	if _player_radius_before >= 0.0:
		return

	var shapes: Array[Node] = _player.find_children("*", "CollisionShape3D", true, false)
	if shapes.is_empty() or not (shapes[0] as CollisionShape3D).shape is CapsuleShape3D:
		return

	var capsule: CapsuleShape3D = (shapes[0] as CollisionShape3D).shape as CapsuleShape3D
	_player_radius_before = capsule.radius
	capsule.radius = wagon_player_radius


func _restore_player_shape() -> void:
	if _player_radius_before < 0.0 or _player == null or not is_instance_valid(_player):
		return

	var shapes: Array[Node] = _player.find_children("*", "CollisionShape3D", true, false)
	if not shapes.is_empty() and (shapes[0] as CollisionShape3D).shape is CapsuleShape3D:
		((shapes[0] as CollisionShape3D).shape as CapsuleShape3D).radius = _player_radius_before

	_player_radius_before = -1.0


func _restore_flashlight() -> void:
	if _flashlight_before.is_empty() or _player == null or not is_instance_valid(_player):
		return

	var flashlight: SpotLight3D = _player.get("flashlight_controller") as SpotLight3D
	if flashlight != null:
		flashlight.light_energy = float(_flashlight_before["energy"])
		flashlight.spot_range = float(_flashlight_before["range"])
		var fill: SpotLight3D = flashlight.get_node_or_null("FlashlightFill") as SpotLight3D
		if fill != null:
			fill.light_energy = float(_flashlight_before["fill_energy"])

	_flashlight_before = {}


func _process(delta: float) -> void:
	_light_time += delta
	if _torch_failing:
		_fail_the_torch(delta)
	_flicker_lights(delta)
	_drive_beam()

	# She rocks as she sobs.
	if _girl != null and is_instance_valid(_girl) and _sophia != null and _sophia.visible:
		_girl.sob(_light_time)


func _physics_process(delta: float) -> void:
	match stage:
		Stage.APPROACH:
			var near: float = _distance_to_sophia()
			if near <= cutscene_distance or (near <= cutscene_sight_distance and _girl_in_sight()):
				_run_cutscene()
		Stage.CUTSCENE:
			_auto_walk(delta)


## Whether the player's eyes see the girl (nothing of the wagon, the bench backs, is in the line to her back).
func _girl_in_sight() -> bool:
	if _sophia == null or not is_instance_valid(_sophia) or not _sophia.visible:
		return false

	var eye: Vector3 = _camera().global_position
	var back: Vector3 = _girl_point(0.45)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, back)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = _camera().get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(back) < 0.3


## How far the player is from the aisle's end (where she would sit in the middle), along the aisle: the cutscene and the whisper are
## measured by the benches, wherever in the end of the wagon she is.
func _distance_to_sophia() -> float:
	return absf((_player.global_position - _aisle_end).dot(_corridor_axis))


# ============================================================
# 3. THE CUTSCENE: THE WHISPER, THE EMPTY WAGON, THE EMPTY PLACE
# ============================================================

## Juliana walks on by herself, step by step, while `_auto_walking`.
func _auto_walk(delta: float) -> void:
	if not _auto_walking:
		return

	var speed: float = PlayerMovementController.WALK_SPEED * wagon_walk_scale
	_player.global_position += _corridor_axis * speed * delta
	_step_clock += delta
	var audio: Node = _player.get("audio_controller") as Node
	if _step_clock >= 0.78:
		_step_clock = 0.0
		if audio != null and audio.has_method("trigger_footstep"):
			audio.call("trigger_footstep", false, 0.55)

	# A little sway as she walks.
	var movement: Node = _player.get("movement_controller") as Node
	if movement != null:
		movement.set("gesture_offset", Vector3(0.0, sin(_light_time * 7.0) * 0.012, 0.0))
		movement.set("gesture_roll_degrees", sin(_light_time * 3.5) * 0.5)


## The scene at her place. The player has no control from here until Juliana has searched and turned to the
## exit. Her flashlight is on the girl; she walks on a second, hears the whisper, the light sputters and jumps over
## her shoulder, her head following it; she sweeps it behind her over the empty wagon, the girl is gone, the light
## creeps back to the empty place and she cannot look away; then it darts about under the benches and up at the
## dead lamps, always ahead of her head, before it runs down the aisle to the exit and she turns to it.
func _run_cutscene() -> void:
	stage = Stage.CUTSCENE
	var movement: Node = _player.get("movement_controller") as Node
	_player.call("set_view_locked", true)
	_player.call("release_movement_hold")
	if movement == null:
		_end_cutscene(0.0)
		return

	# The flashlight is hers to hold here: the key does nothing, it is aimed by the scene (not by the view) and it
	# trembles.
	_player.set("scripted_flashlight", true)
	var torch: Node = _player.get("flashlight_controller") as Node
	if torch != null:
		torch.set("toggle_locked", true)

	_beam_speed = 2.2
	_beam_fear = 0.35
	_beam_shaking = true

	# Facing her: the nearest equivalent of the aisle's yaw, whatever way they were looking.
	var yaw_north: float = _yaw_towards(_corridor_axis)
	var yaw_now: float = float(movement.get("look_yaw"))
	var facing: float = yaw_north + 360.0 * roundf((yaw_now - yaw_north) / 360.0)

	# The beam is on the girl (she sits low on the floor, so it points down at her) and keeps her in the light while
	# Juliana walks up; the view dips down to her.
	_beam_goal = Vector2(yaw_now, float(movement.get("look_pitch")))
	_beam_goal_on = true
	_switch_torch_on()
	_track_beam(_girl_point(0.3))
	# The shot of her back: the view settles on her slowly and then holds still (nothing moves but her), in a weak light that fails and
	# comes back.
	var to_girl: Vector3 = _girl_point(0.4) - _camera().global_position
	var girl_yaw: float = _yaw_towards(Vector3(to_girl.x, 0.0, to_girl.z))
	girl_yaw += 360.0 * roundf((facing - girl_yaw) / 360.0)
	var girl_pitch: float = rad_to_deg(atan2(-to_girl.y, Vector2(to_girl.x, to_girl.z).length()))
	_torch_failing = true
	await _look_to(movement, girl_yaw, girl_pitch, reveal_turn_seconds)
	await _wait(reveal_hold_seconds)

	# She walks on by herself.
	_auto_walking = true
	_step_clock = 0.0
	await _wait(cutscene_walk_seconds)
	_auto_walking = false
	movement.set("gesture_offset", Vector3.ZERO)

	# The whisper at her ear (a caption); she flinches: the light sputters and jumps back over her shoulder.
	_stop_failing_the_torch()
	_whisper()
	_tension_after_the_whisper()
	_flicker_torch(0.55)
	_beam_fear = 1.4
	_aim_beam(facing + 132.0, 4.0, 0.22, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	var flinch: Tween = create_tween().set_parallel(true)
	flinch.tween_property(movement, "gesture_roll_degrees", 7.0, 0.12)
	flinch.tween_property(movement, "gesture_pitch_degrees", -5.0, 0.12)
	flinch.tween_property(movement, "gesture_offset", Vector3(0.0, -0.05, 0.06), 0.12)
	await _wait(0.5)
	var settle: Tween = create_tween().set_parallel(true)
	settle.tween_property(movement, "gesture_roll_degrees", 0.0, 0.5)
	settle.tween_property(movement, "gesture_pitch_degrees", 0.0, 0.5)
	settle.tween_property(movement, "gesture_offset", Vector3.ZERO, 0.5)

	# Her head catches up with the beam: a glance over her shoulder.
	await _look_to(movement, facing + 105.0, -2.0, 0.45, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	await _wait(0.4)

	# The beam sweeps back along the wagon behind her, over the benches, and her head drags after it.
	_beam_fear = 1.0
	await _point_then_look(movement, facing + 180.0, 3.0, 0.9, 0.35, 0.8)

	# Nobody behind her. While she looks, the girl is gone (the lights stutter as it happens).
	_vanish_sophia()
	_flicker_torch(0.45)
	_beam_fear = 1.7
	_aim_beam(facing + 168.0, 0.0, 1.4)
	await _breathe(movement, 1.6)

	# She turns back, slowly, not wanting to look: the beam goes first, her head dares after it.
	_beam_fear = 0.9
	await _point_then_look(movement, facing + 80.0, 0.0, 1.0, 0.5, 1.0)
	await _wait(0.3)

	# The light creeps to the place where the girl sat, and finds nothing: the picture smears. Her head comes down
	# to look at the empty floor.
	_aim_beam_at(_girl_point(0.05), 1.4)
	await _wait(0.7)
	_pulse_unease(0.9, 2.4)
	await _look_to(movement, facing, 17.0, 1.1)
	await _wait(0.9)

	# She looks for her: the light darts under the benches on one side, then the other, then up at the dead
	# lamps; her head is always a beat behind it.
	_beam_fear = 1.0
	await _point_then_look(movement, facing - 38.0, 26.0, 0.26, 0.14, 0.5)
	await _wait(0.45)
	await _point_then_look(movement, facing + 40.0, 22.0, 0.3, 0.12, 0.85)
	await _wait(0.3)
	await _point_then_look(movement, facing + 6.0, -34.0, 0.4, 0.2, 0.7)
	_flicker_torch(0.35)
	await _wait(0.6)

	# Then the light runs down the aisle to the exit, and she turns to follow it.
	_beam_fear = 0.7
	await _point_then_look(movement, facing + 180.0, 1.0, 0.75, 0.4, 1.5)
	_end_cutscene(facing + 180.0)


## The girl's place, `height` metres above the floor.
func _girl_point(height: float) -> Vector3:
	return _sophia.global_position + Vector3.UP * height


## Turns the view to `yaw` / `pitch` (the movement controller's degrees) over `seconds`.
func _look_to(movement: Node, yaw: float, pitch: float, seconds: float, trans: Tween.TransitionType = Tween.TRANS_SINE, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	var yaw_from: float = float(movement.get("look_yaw"))
	var pitch_from: float = float(movement.get("look_pitch"))
	var turn: Tween = create_tween().set_trans(trans).set_ease(ease_type)
	turn.tween_method(
		func(t: float) -> void:
			movement.set("look_yaw", lerpf(yaw_from, yaw, t))
			movement.set("look_pitch", lerpf(pitch_from, pitch, t)),
		0.0, 1.0, seconds
	)
	await turn.finished


## Standing scared and breathing hard, the view heaving a little, for `seconds`.
func _breathe(movement: Node, seconds: float) -> void:
	var elapsed: float = 0.0
	var pitch: float = float(movement.get("look_pitch"))
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		movement.set("gesture_offset", Vector3(0.0, sin(elapsed * 6.0) * 0.012, 0.0))
		movement.set("look_pitch", pitch + sin(elapsed * 5.0) * 0.8)

	movement.set("gesture_offset", Vector3.ZERO)


## The girl's crying, a loop in 3D at her head (so it gets louder as the player comes closer to her).
func _start_crying() -> void:
	var stream: AudioStream = load(CRYING_PATH) as AudioStream
	if stream == null or _sophia == null:
		return

	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_cry = AudioStreamPlayer3D.new()
	_cry.name = "Crying"
	_cry.stream = stream
	_cry.volume_db = CRYING_DB
	_cry.unit_size = CRYING_UNIT_SIZE
	_cry.max_distance = CRYING_MAX_DISTANCE
	# Heard strongly from the side she is on (the default pans gently), so the player can tell, with her out of sight, that she is on the left.
	_cry.panning_strength = 2.0
	_cry.position = Vector3(0.0, 0.45, 0.0)
	_sophia.add_child(_cry)
	_cry.play()


## The crying stops at once (the whisper, or the girl's going).
func _stop_crying() -> void:
	if _cry != null and is_instance_valid(_cry):
		_cry.stop()


## The girl is gone, and the lights stutter out and in as it happens.
func _vanish_sophia() -> void:
	_stop_crying()
	for light: OmniLight3D in _wagon_lights:
		light.visible = false

	await _wait(0.3)
	_sophia.visible = false
	_exit_light_dead = true
	# The lamp over the exit is dead: the door is a black hole, and there is something in it.
	if _door_scene != null:
		_door_scene.show_doorway(true)
	for index: int in _wagon_lights.size():
		_wagon_lights[index].visible = index != 0


## A whisper from right behind the player's head: its words only (a caption), there is no sound.
## `placeholder_string_tension` comes in a moment after the whisper and stays until the controls are back (see `_end_cutscene`).
func _tension_after_the_whisper() -> void:
	await _wait(tension_after_whisper_seconds)
	if stage != Stage.CUTSCENE:
		return

	_tension = AudioStreamPlayer.new()
	_tension.name = "Tension"
	_tension.stream = load(TENSION_PATH) as AudioStream
	_tension.volume_db = -60.0
	add_child(_tension)
	_tension.play()
	create_tween().tween_property(_tension, "volume_db", tension_db, tension_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _stop_tension(seconds: float) -> void:
	if _tension == null or not is_instance_valid(_tension) or not _tension.playing:
		return

	if seconds <= 0.0:
		_tension.stop()
		return

	var fall: Tween = create_tween()
	fall.tween_property(_tension, "volume_db", -60.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.tween_callback(_tension.stop)


func _whisper() -> void:
	# The crying stops the moment the whisper comes.
	_stop_crying()
	CaptionManager.say(LINE_WHISPER)


## The beam is the view's own again (and stops trembling).
func _stop_beam_script() -> void:
	_beam_shaking = false
	if _player != null and is_instance_valid(_player):
		var torch: Node = _player.get("flashlight_controller") as Node
		if torch != null:
			torch.set("scripted_aim_on", false)

	_beam_goal_on = false
	_beam_track_on = false
	if _beam_tween != null and _beam_tween.is_valid():
		_beam_tween.kill()


## The controls come back, facing the exit, and the scene at the corridor door begins (`FinaleDoorScene`): the player walks the aisle to
## it themselves, and the rest happens when they are near it and looking at it. The only sounds are their footsteps and the sting of
## the head.
func _end_cutscene(yaw: float) -> void:
	stage = Stage.LEAVING
	_stop_tension(tension_out_seconds)
	var movement: Node = _player.get("movement_controller") as Node
	_player.call("set_view_locked", false)
	_stop_beam_script()
	_player.set("scripted_flashlight", false)
	var torch: Node = _player.get("flashlight_controller") as Node
	if torch != null:
		torch.set("toggle_locked", false)

	if movement != null:
		# The view is left exactly where the cutscene's last turn put it (its yaw is `yaw`, its pitch a degree down): the controls take over
		# there, with no jump. (It used to be set to a 4 degree upward look here, a jump of about five degrees at the hand-over.)
		movement.set("look_yaw", yaw)
		movement.set("gesture_offset", Vector3.ZERO)
		movement.set("gesture_roll_degrees", 0.0)
		movement.set("gesture_pitch_degrees", 0.0)

	cutscene_ended.emit()
	if _door_scene != null:
		_door_scene.begin()


## The hands are on her face: the picture snaps to black, in silence, and after a moment the title and the end.
func _on_captured() -> void:
	stage = Stage.GRABBED
	var movement: Node = _player.get("movement_controller") as Node
	if movement != null:
		movement.call("release_corridor")

	if _player.has_method("hold_movement"):
		_player.call("hold_movement", 600.0)

	_stop_beam_script()
	_make_black(1.0)
	await _wait(black_hold_seconds)
	await _show_title()
	_finish()


## Covers the screen with black at once (`alpha` 1) or not at all.
func _make_black(alpha: float) -> void:
	if _black_layer == null:
		_black_layer = CanvasLayer.new()
		_black_layer.name = "BlackLayer"
		_black_layer.layer = 115
		add_child(_black_layer)
		_black_rect = ColorRect.new()
		_black_rect.color = Color.BLACK
		_black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_black_layer.add_child(_black_rect)

	_black_rect.modulate.a = alpha


## The UNRAILED title card over the black: the word alone, as on the main menu (its theme variation, so
## the same font and palette colour; no glow, no rules).
func _show_title() -> void:
	stage = Stage.TITLE
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TitleCard"
	layer.layer = 120
	add_child(layer)

	var card: Control = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	layer.add_child(card)

	var screen: Vector2 = get_viewport().get_visible_rect().size
	var title: Label = Label.new()
	title.name = "Title"
	title.theme_type_variation = &"TitleLabel"
	title.text = tr("TITLE_CARD_TEXT")
	title.add_theme_font_size_override(&"font_size", int(screen.y * 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)

	var fade_in: Tween = create_tween()
	fade_in.tween_property(card, "modulate:a", 1.0, title_fade_in_seconds)
	await fade_in.finished
	title_shown.emit()
	await _wait(title_hold_seconds)
	var fade_out: Tween = create_tween()
	fade_out.tween_property(card, "modulate:a", 0.0, title_fade_out_seconds)
	await fade_out.finished


## The end: the save is marked finished, and keeps the player at the overlook with the fichas in the
## slot and the call still to make; then the main menu.
func _finish() -> void:
	stage = Stage.DONE
	if _door_scene != null and is_instance_valid(_door_scene):
		_door_scene.cleanup()

	SaveManager.set_state_value(STATE_SECTION, KEY_DEMO_COMPLETE, true)
	# So that Continue lets the player make the call again.
	SaveManager.set_state_value(STATE_SECTION, KEY_CALL_DONE, false)
	if SaveManager.has_active_game() and not _snapshot.is_empty():
		var scene_path: String = save_scene_path
		if scene_path.is_empty() and get_tree().current_scene != null:
			scene_path = get_tree().current_scene.scene_file_path

		if not scene_path.is_empty():
			SaveManager.save_manual_game(scene_path, _snapshot)

	_set_filter_darkness(0.0)
	_restore_master()
	_silence_outside(false)
	_restore_flashlight()
	_restore_player_shape()
	finished.emit()
	if not change_scene_at_end:
		return

	GameSettings.save_settings()
	SaveManager.suspend_session()
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(main_menu_path)


# ============================================================
# HELPERS
# ============================================================

func _get_player() -> Node3D:
	if player != null:
		return player

	return get_tree().get_first_node_in_group(&"player") as Node3D


func _camera() -> Camera3D:
	return _player.get_node("Head/Camera3D") as Camera3D


## Puts the flashlight out; `allow` says whether the player may switch it on again.
func _cut_flashlight(allow: bool) -> void:
	if _player == null:
		return

	var flashlight: Node = _player.get("flashlight_controller") as Node
	if flashlight == null:
		return

	if flashlight.has_method("turn_off"):
		flashlight.call("turn_off")

	if not allow and flashlight.has_method("set_flashlight_input_enabled"):
		flashlight.call("set_flashlight_input_enabled", false)


## If the scene's opening cinematic is still running (a jump from the developer console in the first seconds), it is
## cut short first: left alone it would black the picture out and take the controls in the middle of the finale.
func _cancel_the_opening() -> void:
	var scene: Node = get_parent()
	if scene == null:
		return

	for child: Node in scene.get_children():
		if child.has_method("skip_opening"):
			child.call("skip_opening")


## The dream intro's "Press F to turn on the flashlight" hint has no place in the finale.
func _hide_flashlight_hint() -> void:
	var hint: Node = get_tree().root.find_child("FlashlightTutorialPrompt", true, false)
	if hint is CanvasItem:
		(hint as CanvasItem).visible = false


func _set_saving_blocked(blocked: bool) -> void:
	if _player != null and _player.has_method("set_manual_save_blocked"):
		_player.call("set_manual_save_blocked", blocked)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
