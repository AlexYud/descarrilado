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
# MENU DISTANCE FOG
# ============================================================

@export_category("Menu Distance Fog")

## Distance where menu fog begins.
@export_range(0.0, 100.0, 1.0)
var menu_fog_begin: float = 11.0


## At this distance the scenery is almost completely hidden.
@export_range(1.0, 150.0, 1.0)
var menu_fog_end: float = 30.0


## Controls how quickly the distant scenery disappears.
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
# STARTUP
# ============================================================

func _ready() -> void:
	if apply_on_ready:
		call_deferred("apply_environment")


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
# PROFILE VALUES
# ============================================================

func _get_profile_settings() -> Dictionary:
	match profile:
		EnvironmentProfile.MAIN_MENU:
			return _get_main_menu_profile()

		_:
			return _get_dream_intro_profile()


func _get_dream_intro_profile() -> Dictionary:
	## Dream Intro remains unchanged.
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

		## Dark blue fog matching the menu background.
		"fog_color": Color("#111a2b"),
		"fog_energy": 0.55,

		## In depth mode this is the maximum fog opacity.
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

	env.background_color = settings[
		"background_color"
	]

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

	env.ambient_light_color = settings[
		"ambient_color"
	]

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

	## Depth-fog density represents maximum opacity.
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
