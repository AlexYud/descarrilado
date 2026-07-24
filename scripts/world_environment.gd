@tool
extends WorldEnvironment
class_name HorrorNightEnvironment


enum EnvironmentProfile {
	DREAM_INTRO,
	MAIN_MENU
}


# ============================================================
# SCENE PROFILE
# ============================================================

@export_category("Scene Profile")

@export var profile: EnvironmentProfile = (
	EnvironmentProfile.DREAM_INTRO
)


# ============================================================
# EDITOR CONTROL
# ============================================================

@export_category("Editor Control")

@export var apply_on_ready: bool = true

@export var apply_now: bool = false:
	set(value):
		if value:
			call_deferred("apply_environment")

		apply_now = false


# ============================================================
# OPTIONAL TUNING
# ============================================================

@export_category("Optional Tuning")

@export_range(0.5, 1.5, 0.05)
var exterior_visibility: float = 1.0


@export_range(0.5, 1.5, 0.05)
var interior_fill: float = 1.0


@export_range(0.0, 1.8, 0.05)
var fog_amount: float = 1.0


# ============================================================
# DREAM FOG ALTITUDE CONTROL
# ============================================================

@export_category("Dream Fog Altitude Control")

## Keeps the current fog above the start altitude, then makes
## it progressively weaker as the player descends.
@export var reduce_fog_below_altitude: bool = true

## Optional. Leave empty to automatically find Player.
## If Player cannot be found, the active Camera3D is used.
@export var fog_altitude_target_path: NodePath

## The fog remains exactly as configured at and above this Y.
@export var fog_reduction_start_altitude: float = 0.0

## Fog is completely removed here and below.
@export var fog_reduction_end_altitude: float = -8.0

@export_range(0.0, 1.0, 0.01)
var low_altitude_fog_density_multiplier: float = 0.0

@export_range(0.0, 1.0, 0.01)
var low_altitude_height_density_multiplier: float = 0.0

## Makes the fog layer follow the player while descending.
@export var fog_height_follows_descent: bool = true


# ============================================================
# LOW ALTITUDE LIGHTING
# ============================================================

@export_category("Low Altitude Lighting")

## Brightens the exterior vista around the lighthouse.
@export var boost_low_altitude_lighting: bool = true

## The lighting transition starts here.
@export var lighting_boost_start_altitude: float = -7.0

## The lighting boost is fully active here and below.
@export var lighting_boost_end_altitude: float = -8.0

## Strengthens direct moonlight on exterior surfaces.
@export_range(1.0, 5.0, 0.05)
var low_altitude_moon_multiplier: float = 2.25

## Gently lifts surfaces facing away from the moon.
@export_range(1.0, 3.0, 0.05)
var low_altitude_ambient_multiplier: float = 1.40

## Slightly lifts the night sky without changing exposure.
@export_range(1.0, 2.0, 0.05)
var low_altitude_background_multiplier: float = 1.15


# ============================================================
# MENU DISTANCE FOG
# ============================================================

@export_category("Menu Distance Fog")

@export_range(0.0, 100.0, 1.0)
var menu_fog_begin: float = 11.0

@export_range(1.0, 150.0, 1.0)
var menu_fog_end: float = 30.0

@export_range(0.1, 4.0, 0.05)
var menu_fog_curve: float = 1.35


# ============================================================
# MOON
# ============================================================

@export_category("Moon")

## Leave empty if the node is named MoonLight.
@export var moon_light_path: NodePath

@export var moon_angle_degrees: Vector3 = Vector3(
	-38.0,
	-32.0,
	0.0
)


# ============================================================
# RUNTIME STATE
# ============================================================

var _fog_altitude_target: Node3D = null
var _runtime_moon: DirectionalLight3D = null

var _base_fog_density: float = 0.0
var _base_fog_height: float = 0.0
var _base_fog_height_density: float = 0.0

var _base_moon_energy: float = 0.0
var _base_ambient_energy: float = 0.0
var _base_background_energy: float = 0.0

var _runtime_values_ready: bool = false


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	if not Engine.is_editor_hint():
		_fog_altitude_target = _find_altitude_target()

	if apply_on_ready:
		call_deferred("apply_environment")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if profile != EnvironmentProfile.DREAM_INTRO:
		return

	if not _runtime_values_ready:
		return

	if environment == null:
		return

	if (
		_fog_altitude_target == null
		or not is_instance_valid(_fog_altitude_target)
	):
		_fog_altitude_target = _find_altitude_target()

	if _fog_altitude_target == null:
		_restore_base_dream_fog()
		_restore_base_dream_lighting()
		return

	var altitude: float = (
		_fog_altitude_target.global_position.y
	)

	if reduce_fog_below_altitude:
		_update_dream_fog_for_altitude(altitude)
	else:
		_restore_base_dream_fog()

	if boost_low_altitude_lighting:
		_update_dream_lighting_for_altitude(altitude)
	else:
		_restore_base_dream_lighting()


# ============================================================
# ENVIRONMENT APPLICATION
# ============================================================

func apply_environment() -> void:
	_make_environment_local()

	if environment == null:
		return

	var settings: Dictionary = _get_profile_settings()

	var exterior: float = clampf(
		exterior_visibility,
		0.5,
		1.5
	)

	var interior: float = clampf(
		interior_fill,
		0.5,
		1.5
	)

	var fog_strength: float = clampf(
		fog_amount,
		0.0,
		1.8
	)

	_cache_runtime_values(
		settings,
		fog_strength,
		exterior,
		interior
	)

	_apply_background(
		environment,
		settings,
		exterior
	)

	_apply_ambient_light(
		environment,
		settings,
		interior
	)

	_apply_fog(
		environment,
		settings,
		exterior,
		fog_strength
	)

	_apply_tonemapping(
		environment,
		settings
	)

	_apply_image_adjustments(
		environment,
		settings
	)

	_apply_ssao(
		environment,
		settings
	)

	_disable_expensive_effects(environment)

	_apply_moon_light(
		settings,
		exterior
	)


func _cache_runtime_values(
	settings: Dictionary,
	fog_strength: float,
	exterior: float,
	interior: float
) -> void:
	_base_fog_density = (
		float(settings["fog_density"])
		* fog_strength
	)

	_base_fog_height = float(
		settings["fog_height"]
	)

	_base_fog_height_density = (
		float(settings["fog_height_density"])
		* fog_strength
	)

	_base_moon_energy = (
		float(settings["moon_energy"])
		* exterior
	)

	_base_ambient_energy = (
		float(settings["ambient_energy"])
		* interior
	)

	_base_background_energy = (
		float(settings["background_energy"])
		* exterior
	)

	_runtime_values_ready = true


func _make_environment_local() -> void:
	if environment == null:
		environment = Environment.new()
		environment.resource_local_to_scene = true
		return

	if environment.resource_local_to_scene:
		return

	var local_environment: Environment = (
		environment.duplicate(true)
		as Environment
	)

	if local_environment == null:
		return

	local_environment.resource_local_to_scene = true
	environment = local_environment


# ============================================================
# RUNTIME ALTITUDE FOG
# ============================================================

func _update_dream_fog_for_altitude(
	altitude: float
) -> void:
	var blend: float = _get_descending_altitude_blend(
		altitude,
		fog_reduction_start_altitude,
		fog_reduction_end_altitude
	)

	var density_multiplier: float = lerpf(
		1.0,
		low_altitude_fog_density_multiplier,
		blend
	)

	var height_density_multiplier: float = lerpf(
		1.0,
		low_altitude_height_density_multiplier,
		blend
	)

	environment.fog_density = (
		_base_fog_density
		* density_multiplier
	)

	environment.fog_height_density = (
		_base_fog_height_density
		* height_density_multiplier
	)

	if fog_height_follows_descent:
		var descent: float = minf(
			altitude - fog_reduction_start_altitude,
			0.0
		)

		environment.fog_height = (
			_base_fog_height + descent
		)
	else:
		environment.fog_height = _base_fog_height


func _restore_base_dream_fog() -> void:
	environment.fog_density = _base_fog_density
	environment.fog_height = _base_fog_height
	environment.fog_height_density = (
		_base_fog_height_density
	)


# ============================================================
# RUNTIME ALTITUDE LIGHTING
# ============================================================

func _update_dream_lighting_for_altitude(
	altitude: float
) -> void:
	var blend: float = _get_descending_altitude_blend(
		altitude,
		lighting_boost_start_altitude,
		lighting_boost_end_altitude
	)

	environment.ambient_light_energy = (
		_base_ambient_energy
		* lerpf(
			1.0,
			low_altitude_ambient_multiplier,
			blend
		)
	)

	environment.background_energy_multiplier = (
		_base_background_energy
		* lerpf(
			1.0,
			low_altitude_background_multiplier,
			blend
		)
	)

	if (
		_runtime_moon == null
		or not is_instance_valid(_runtime_moon)
	):
		_runtime_moon = _find_moon_light()

	if _runtime_moon != null:
		_runtime_moon.light_energy = (
			_base_moon_energy
			* lerpf(
				1.0,
				low_altitude_moon_multiplier,
				blend
			)
		)


func _restore_base_dream_lighting() -> void:
	environment.ambient_light_energy = (
		_base_ambient_energy
	)

	environment.background_energy_multiplier = (
		_base_background_energy
	)

	if (
		_runtime_moon == null
		or not is_instance_valid(_runtime_moon)
	):
		_runtime_moon = _find_moon_light()

	if _runtime_moon != null:
		_runtime_moon.light_energy = _base_moon_energy


func _get_descending_altitude_blend(
	altitude: float,
	start_altitude: float,
	end_altitude: float
) -> float:
	var safe_end_altitude: float = minf(
		end_altitude,
		start_altitude - 0.1
	)

	var altitude_range: float = (
		start_altitude - safe_end_altitude
	)

	var blend: float = clampf(
		(start_altitude - altitude)
		/ altitude_range,
		0.0,
		1.0
	)

	return blend * blend * (3.0 - 2.0 * blend)


func _find_altitude_target() -> Node3D:
	if not fog_altitude_target_path.is_empty():
		var assigned_target: Node3D = (
			get_node_or_null(
				fog_altitude_target_path
			)
			as Node3D
		)

		if assigned_target != null:
			return assigned_target

	var current_scene: Node = get_tree().current_scene

	if current_scene != null:
		var player_node: Node3D = (
			current_scene.find_child(
				"Player",
				true,
				false
			)
			as Node3D
		)

		if player_node != null:
			return player_node

	return get_viewport().get_camera_3d()


# ============================================================
# PROFILE VALUES
# ============================================================

func _get_profile_settings() -> Dictionary:
	match profile:
		EnvironmentProfile.MAIN_MENU:
			return _get_main_menu_profile()

		_:
			return _get_dream_intro_profile()


func _get_dream_intro_profile() -> Dictionary:
	return {
		"background_color": Color("#050916"),
		"background_energy": 0.22,

		"ambient_color": Color("#3f5068"),
		"ambient_energy": 0.12,

		"fog_color": Color("#2c3c4f"),
		"fog_energy": 0.27,
		"fog_density": 0.035,
		"fog_height": 1.30,
		"fog_height_density": 0.12,
		"fog_sky_affect": 0.88,
		"fog_sun_scatter": 0.06,

		"exposure": 0.92,
		"agx_contrast": 1.15,
		"brightness": 0.98,
		"contrast": 1.03,
		"saturation": 0.82,

		"ssao_intensity": 0.95,

		"moon_color": Color("#8fa8c4"),
		"moon_energy": 0.1,
		"moon_specular": 0.08,
		"moon_shadow_opacity": 0.72,
		"moon_volumetric_energy": 0.20
	}


func _get_main_menu_profile() -> Dictionary:
	return {
		"background_color": Color("#091225"),
		"background_energy": 0.32,

		"ambient_color": Color("#566c87"),
		"ambient_energy": 0.18,

		"fog_color": Color("#111a2b"),
		"fog_energy": 0.55,
		"fog_density": 0.98,

		"fog_height": 1.30,
		"fog_height_density": 0.0,
		"fog_sky_affect": 1.0,
		"fog_sun_scatter": 0.04,

		"exposure": 0.98,
		"agx_contrast": 1.10,
		"brightness": 1.0,
		"contrast": 1.02,
		"saturation": 0.84,

		"ssao_intensity": 0.80,

		"moon_color": Color("#9db7d2"),
		"moon_energy": 0.53,
		"moon_specular": 0.10,
		"moon_shadow_opacity": 0.66,
		"moon_volumetric_energy": 0.24
	}


# ============================================================
# BACKGROUND
# ============================================================

func _apply_background(
	env: Environment,
	settings: Dictionary,
	exterior: float
) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = settings["background_color"]

	env.background_energy_multiplier = (
		float(settings["background_energy"])
		* exterior
	)


# ============================================================
# AMBIENT LIGHT
# ============================================================

func _apply_ambient_light(
	env: Environment,
	settings: Dictionary,
	interior: float
) -> void:
	env.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)

	env.ambient_light_color = settings["ambient_color"]

	env.ambient_light_energy = (
		float(settings["ambient_energy"])
		* interior
	)

	env.ambient_light_sky_contribution = 0.0

	env.reflected_light_source = (
		Environment.REFLECTION_SOURCE_DISABLED
	)


# ============================================================
# FOG
# ============================================================

func _apply_fog(
	env: Environment,
	settings: Dictionary,
	exterior: float,
	fog_strength: float
) -> void:
	env.fog_enabled = fog_strength > 0.0
	env.fog_light_color = settings["fog_color"]

	env.fog_light_energy = (
		float(settings["fog_energy"])
		* exterior
	)

	env.fog_height = float(
		settings["fog_height"]
	)

	env.fog_height_density = (
		float(settings["fog_height_density"])
		* fog_strength
	)

	env.fog_sky_affect = float(
		settings["fog_sky_affect"]
	)

	env.fog_sun_scatter = float(
		settings["fog_sun_scatter"]
	)

	env.fog_aerial_perspective = 0.0

	if profile == EnvironmentProfile.MAIN_MENU:
		_apply_menu_distance_fog(
			env,
			settings,
			fog_strength
		)
	else:
		_apply_dream_exponential_fog(
			env,
			settings,
			fog_strength
		)

	env.volumetric_fog_enabled = false


func _apply_dream_exponential_fog(
	env: Environment,
	settings: Dictionary,
	fog_strength: float
) -> void:
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL

	env.fog_density = (
		float(settings["fog_density"])
		* fog_strength
	)


func _apply_menu_distance_fog(
	env: Environment,
	settings: Dictionary,
	fog_strength: float
) -> void:
	env.fog_mode = Environment.FOG_MODE_DEPTH

	env.fog_density = clampf(
		float(settings["fog_density"])
		* fog_strength,
		0.0,
		1.0
	)

	env.fog_depth_begin = menu_fog_begin

	env.fog_depth_end = maxf(
		menu_fog_end,
		menu_fog_begin + 1.0
	)

	env.fog_depth_curve = menu_fog_curve


# ============================================================
# TONEMAPPING
# ============================================================

func _apply_tonemapping(
	env: Environment,
	settings: Dictionary
) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_AGX

	env.tonemap_exposure = float(
		settings["exposure"]
	)

	env.tonemap_agx_contrast = float(
		settings["agx_contrast"]
	)

	env.tonemap_agx_white = 16.29


func _apply_image_adjustments(
	env: Environment,
	settings: Dictionary
) -> void:
	env.adjustment_enabled = true

	env.adjustment_brightness = float(
		settings["brightness"]
	)

	env.adjustment_contrast = float(
		settings["contrast"]
	)

	env.adjustment_saturation = float(
		settings["saturation"]
	)


# ============================================================
# SSAO
# ============================================================

func _apply_ssao(
	env: Environment,
	settings: Dictionary
) -> void:
	env.ssao_enabled = true

	env.ssao_intensity = float(
		settings["ssao_intensity"]
	)

	env.ssao_radius = 0.55
	env.ssao_power = 1.20
	env.ssao_detail = 0.30
	env.ssao_horizon = 0.04
	env.ssao_sharpness = 0.86
	env.ssao_light_affect = 0.0
	env.ssao_ao_channel_affect = 0.0


func _disable_expensive_effects(
	env: Environment
) -> void:
	env.glow_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false


# ============================================================
# MOON
# ============================================================

func _apply_moon_light(
	settings: Dictionary,
	exterior: float
) -> void:
	var moon: DirectionalLight3D = _find_moon_light()

	if moon == null:
		push_warning(
			"HorrorNightEnvironment: MoonLight was not found. "
			+ "Assign Moon Light Path or name the node MoonLight."
		)
		return

	_runtime_moon = moon
	moon.light_color = settings["moon_color"]

	moon.light_energy = (
		float(settings["moon_energy"])
		* exterior
	)

	moon.light_indirect_energy = 0.0

	moon.light_specular = float(
		settings["moon_specular"]
	)

	moon.rotation_degrees = moon_angle_degrees
	moon.shadow_enabled = true

	moon.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	)

	moon.directional_shadow_split_1 = 0.25
	moon.directional_shadow_max_distance = 42.0
	moon.directional_shadow_fade_start = 0.82
	moon.directional_shadow_blend_splits = false
	moon.directional_shadow_pancake_size = 12.0

	moon.shadow_opacity = float(
		settings["moon_shadow_opacity"]
	)

	moon.shadow_bias = 0.035
	moon.shadow_normal_bias = 0.65
	moon.shadow_blur = 1.55

	moon.light_volumetric_fog_energy = float(
		settings["moon_volumetric_energy"]
	)


func _find_moon_light() -> DirectionalLight3D:
	if not moon_light_path.is_empty():
		var assigned_moon: DirectionalLight3D = (
			get_node_or_null(moon_light_path)
			as DirectionalLight3D
		)

		if assigned_moon != null:
			return assigned_moon

	var scene_parent: Node = get_parent()

	if scene_parent == null:
		return null

	return (
		scene_parent.find_child(
			"MoonLight",
			true,
			false
		)
		as DirectionalLight3D
	)
