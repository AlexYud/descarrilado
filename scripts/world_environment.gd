@tool
extends WorldEnvironment
class_name HorrorNightEnvironment


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
# NIGHT PALETTE
# ============================================================

@export_category("Night Palette")

## Nearly black violet background.
@export var background_color: Color = Color("#06040b")

@export_range(0.0, 2.0, 0.01)
var background_energy: float = 0.32


## Muted violet ambient light.
## This colors shadows without making the whole scene purple.
@export var ambient_color: Color = Color("#21182e")

@export_range(0.0, 2.0, 0.01)
var ambient_energy: float = 0.24


## Kept at zero because this setup uses a flat background color.
@export_range(0.0, 1.0, 0.01)
var ambient_sky_contribution: float = 0.0


## Disables environment reflections to reduce overly shiny
## surfaces and save a small amount of rendering work.
@export var disable_environment_reflections: bool = true


# ============================================================
# REGULAR FOG
# ============================================================

@export_category("Fog - Main Atmosphere")

## Main fog effect.
## This is regular exponential fog, not volumetric fog.
@export var fog_enabled: bool = true


## Muted purple-gray mist.
## Avoid making this too saturated or too bright.
@export var fog_color: Color = Color("#443650")


## Controls how much the fog color contributes to the scene.
@export_range(0.0, 2.0, 0.01)
var fog_energy: float = 0.31


## Overall fog amount.
## 0.032 provides visible mist while preserving nearby detail.
@export_range(0.0, 0.2, 0.001)
var fog_density: float = 0.032


## Height where the ground-fog layer begins.
## Raise this slightly if your terrain is higher than Y = 0.
@export_range(-20.0, 20.0, 0.05)
var fog_height: float = 1.70


## Positive values make the fog denser below Fog Height.
## This creates mist around the terrain and lower parts of trees.
@export_range(-1.0, 1.0, 0.005)
var fog_height_density: float = 0.055


## Allows the fog to blend the sky/background into the forest.
@export_range(0.0, 1.0, 0.01)
var fog_sky_affect: float = 0.95


## Very subtle moon scattering through the mist.
@export_range(0.0, 1.0, 0.01)
var fog_moon_scatter: float = 0.05


# ============================================================
# VOLUMETRIC FOG
# ============================================================

@export_category("Volumetric Fog - Optional")

## Keep disabled for the normal performance profile.
@export var volumetric_fog_enabled: bool = false


@export_range(0.0, 0.1, 0.001)
var volumetric_fog_density: float = 0.006


## Keep volumetric albedo fairly neutral.
## Moon and environment colors provide the purple tint.
@export var volumetric_fog_albedo: Color = Color("#b9b1c5")


@export var volumetric_fog_emission: Color = Color("#160f1d")


@export_range(0.0, 2.0, 0.01)
var volumetric_fog_emission_energy: float = 0.06


## Shorter rendering distance improves performance.
@export_range(8.0, 128.0, 1.0)
var volumetric_fog_length: float = 30.0


@export_range(0.5, 8.0, 0.1)
var volumetric_fog_detail_spread: float = 2.0


## Slight forward scattering resembles natural mist.
@export_range(-1.0, 1.0, 0.01)
var volumetric_fog_anisotropy: float = 0.20


@export_range(0.0, 1.0, 0.01)
var volumetric_fog_sky_affect: float = 0.60


## Keep these at zero for a cheaper setup.
@export_range(0.0, 1.0, 0.01)
var volumetric_fog_ambient_inject: float = 0.0


@export_range(0.0, 1.0, 0.01)
var volumetric_fog_gi_inject: float = 0.0


@export var volumetric_fog_temporal_reprojection: bool = true


@export_range(0.0, 1.0, 0.01)
var volumetric_fog_temporal_reprojection_amount: float = 0.82


# ============================================================
# TONEMAPPING
# ============================================================

@export_category("Tonemapping")

@export_enum(
	"Linear",
	"Reinhardt",
	"Filmic",
	"ACES",
	"AgX"
)
var tonemap_mode: int = Environment.TONE_MAPPER_ACES


@export_range(0.1, 4.0, 0.01)
var exposure: float = 0.90


## Preserves bright wagon lights and flashlight highlights.
@export_range(1.0, 16.0, 0.1)
var tonemap_white: float = 6.0


# ============================================================
# IMAGE MOOD
# ============================================================

@export_category("Image Mood")

@export_range(0.1, 2.0, 0.01)
var brightness: float = 0.96


@export_range(0.1, 2.0, 0.01)
var contrast: float = 1.08


@export_range(0.0, 2.0, 0.01)
var saturation: float = 0.84


# ============================================================
# SCREEN-SPACE AMBIENT OCCLUSION
# ============================================================

@export_category("SSAO - Optional Depth")

## Adds grounding around corners, seats, furniture,
## tree trunks, walls, and props.
@export var ssao_enabled: bool = true


@export_range(0.0, 5.0, 0.05)
var ssao_intensity: float = 1.25


## Small radius avoids large dirty halos.
@export_range(0.05, 5.0, 0.05)
var ssao_radius: float = 0.70


@export_range(0.1, 8.0, 0.05)
var ssao_power: float = 1.30


@export_range(0.0, 1.0, 0.01)
var ssao_detail: float = 0.32


@export_range(0.0, 1.0, 0.01)
var ssao_horizon: float = 0.06


@export_range(0.0, 1.0, 0.01)
var ssao_sharpness: float = 0.92


## Ambient occlusion should mainly affect indirect light.
@export_range(0.0, 1.0, 0.01)
var ssao_light_affect: float = 0.0


@export_range(0.0, 1.0, 0.01)
var ssao_material_ao_affect: float = 0.0


# ============================================================
# EXPENSIVE EFFECTS
# ============================================================

@export_category("Expensive Effects")

## The custom horror screen filter already handles softness,
## grain, vignette, and highlight treatment.
@export var glow_enabled: bool = false

@export var ssil_enabled: bool = false

@export var ssr_enabled: bool = false

@export var sdfgi_enabled: bool = false


# ============================================================
# MOON LIGHT
# ============================================================

@export_category("Moon Light")

## Can be "../MoonLight" when MoonLight is a sibling.
## When empty, the script searches for a node named MoonLight.
@export var moon_light_path: NodePath


@export var configure_moon_light: bool = true


## Pale lavender-blue moonlight.
@export var moon_color: Color = Color("#b7afd1")


@export_range(0.0, 8.0, 0.01)
var moon_energy: float = 0.90


@export var moon_angle_degrees: Vector3 = Vector3(
	-42.0,
	-28.0,
	0.0
)


## Reduces shiny, plastic-looking reflections.
@export_range(0.0, 1.0, 0.01)
var moon_specular: float = 0.28


## Optional because forests can contain many shadow casters.
@export var moon_shadow_enabled: bool = false


## Used only when moon shadows are enabled.
@export_range(5.0, 100.0, 1.0)
var moon_shadow_max_distance: float = 28.0


@export_range(0.0, 1.0, 0.01)
var moon_shadow_fade_start: float = 0.72


@export_range(0.0, 1.0, 0.01)
var moon_shadow_opacity: float = 0.55


@export_range(0.0, 2.0, 0.001)
var moon_shadow_bias: float = 0.08


@export_range(0.0, 10.0, 0.01)
var moon_shadow_normal_bias: float = 1.25


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	if apply_on_ready:
		apply_environment()


# ============================================================
# ENVIRONMENT SETUP
# ============================================================

func apply_environment() -> void:
	if environment == null:
		environment = Environment.new()

	var env: Environment = environment

	_apply_background(env)
	_apply_ambient_light(env)
	_apply_regular_fog(env)
	_apply_volumetric_fog(env)
	_apply_tonemapping(env)
	_apply_image_adjustments(env)
	_apply_ssao(env)
	_disable_unused_effects(env)

	if configure_moon_light:
		_apply_moon_light()


func _apply_background(env: Environment) -> void:
	_safe_set(
		env,
		"background_mode",
		Environment.BG_COLOR
	)

	_safe_set(
		env,
		"background_color",
		background_color
	)

	_safe_set(
		env,
		"background_energy_multiplier",
		background_energy
	)


func _apply_ambient_light(env: Environment) -> void:
	_safe_set(
		env,
		"ambient_light_source",
		Environment.AMBIENT_SOURCE_COLOR
	)

	_safe_set(
		env,
		"ambient_light_color",
		ambient_color
	)

	_safe_set(
		env,
		"ambient_light_energy",
		ambient_energy
	)

	_safe_set(
		env,
		"ambient_light_sky_contribution",
		ambient_sky_contribution
	)

	if disable_environment_reflections:
		_safe_set(
			env,
			"reflected_light_source",
			Environment.REFLECTION_SOURCE_DISABLED
		)
	else:
		_safe_set(
			env,
			"reflected_light_source",
			Environment.REFLECTION_SOURCE_BG
		)


func _apply_regular_fog(env: Environment) -> void:
	_safe_set(
		env,
		"fog_enabled",
		fog_enabled
	)

	_safe_set(
		env,
		"fog_mode",
		Environment.FOG_MODE_EXPONENTIAL
	)

	_safe_set(
		env,
		"fog_light_color",
		fog_color
	)

	_safe_set(
		env,
		"fog_light_energy",
		fog_energy
	)

	_safe_set(
		env,
		"fog_density",
		fog_density
	)

	_safe_set(
		env,
		"fog_height",
		fog_height
	)

	_safe_set(
		env,
		"fog_height_density",
		fog_height_density
	)

	_safe_set(
		env,
		"fog_sky_affect",
		fog_sky_affect
	)

	_safe_set(
		env,
		"fog_sun_scatter",
		fog_moon_scatter
	)

	_safe_set(
		env,
		"fog_aerial_perspective",
		0.0
	)


func _apply_volumetric_fog(env: Environment) -> void:
	_safe_set(
		env,
		"volumetric_fog_enabled",
		volumetric_fog_enabled
	)

	_safe_set(
		env,
		"volumetric_fog_density",
		volumetric_fog_density
	)

	_safe_set(
		env,
		"volumetric_fog_albedo",
		volumetric_fog_albedo
	)

	_safe_set(
		env,
		"volumetric_fog_emission",
		volumetric_fog_emission
	)

	_safe_set(
		env,
		"volumetric_fog_emission_energy",
		volumetric_fog_emission_energy
	)

	_safe_set(
		env,
		"volumetric_fog_length",
		volumetric_fog_length
	)

	_safe_set(
		env,
		"volumetric_fog_detail_spread",
		volumetric_fog_detail_spread
	)

	_safe_set(
		env,
		"volumetric_fog_anisotropy",
		volumetric_fog_anisotropy
	)

	_safe_set(
		env,
		"volumetric_fog_sky_affect",
		volumetric_fog_sky_affect
	)

	_safe_set(
		env,
		"volumetric_fog_ambient_inject",
		volumetric_fog_ambient_inject
	)

	_safe_set(
		env,
		"volumetric_fog_gi_inject",
		volumetric_fog_gi_inject
	)

	_safe_set(
		env,
		"volumetric_fog_temporal_reprojection_enabled",
		volumetric_fog_temporal_reprojection
	)

	_safe_set(
		env,
		"volumetric_fog_temporal_reprojection_amount",
		volumetric_fog_temporal_reprojection_amount
	)


func _apply_tonemapping(env: Environment) -> void:
	_safe_set(
		env,
		"tonemap_mode",
		tonemap_mode
	)

	_safe_set(
		env,
		"tonemap_exposure",
		exposure
	)

	_safe_set(
		env,
		"tonemap_white",
		tonemap_white
	)


func _apply_image_adjustments(env: Environment) -> void:
	_safe_set(
		env,
		"adjustment_enabled",
		true
	)

	_safe_set(
		env,
		"adjustment_brightness",
		brightness
	)

	_safe_set(
		env,
		"adjustment_contrast",
		contrast
	)

	_safe_set(
		env,
		"adjustment_saturation",
		saturation
	)


func _apply_ssao(env: Environment) -> void:
	_safe_set(
		env,
		"ssao_enabled",
		ssao_enabled
	)

	_safe_set(
		env,
		"ssao_intensity",
		ssao_intensity
	)

	_safe_set(
		env,
		"ssao_radius",
		ssao_radius
	)

	_safe_set(
		env,
		"ssao_power",
		ssao_power
	)

	_safe_set(
		env,
		"ssao_detail",
		ssao_detail
	)

	_safe_set(
		env,
		"ssao_horizon",
		ssao_horizon
	)

	_safe_set(
		env,
		"ssao_sharpness",
		ssao_sharpness
	)

	_safe_set(
		env,
		"ssao_light_affect",
		ssao_light_affect
	)

	_safe_set(
		env,
		"ssao_ao_channel_affect",
		ssao_material_ao_affect
	)


func _disable_unused_effects(env: Environment) -> void:
	_safe_set(
		env,
		"glow_enabled",
		glow_enabled
	)

	_safe_set(
		env,
		"ssil_enabled",
		ssil_enabled
	)

	_safe_set(
		env,
		"ssr_enabled",
		ssr_enabled
	)

	_safe_set(
		env,
		"sdfgi_enabled",
		sdfgi_enabled
	)


# ============================================================
# MOON LIGHT SETUP
# ============================================================

func _apply_moon_light() -> void:
	var moon_light: DirectionalLight3D = _find_moon_light()

	if moon_light == null:
		push_warning(
			"HorrorNightEnvironment: MoonLight was not found. "
			+ "Assign Moon Light Path or name the node MoonLight."
		)
		return

	moon_light.light_color = moon_color
	moon_light.light_energy = moon_energy
	moon_light.rotation_degrees = moon_angle_degrees
	moon_light.shadow_enabled = moon_shadow_enabled

	_safe_set(
		moon_light,
		"light_specular",
		moon_specular
	)

	_safe_set(
		moon_light,
		"directional_shadow_mode",
		DirectionalLight3D.SHADOW_ORTHOGONAL
	)

	_safe_set(
		moon_light,
		"directional_shadow_max_distance",
		moon_shadow_max_distance
	)

	_safe_set(
		moon_light,
		"directional_shadow_fade_start",
		moon_shadow_fade_start
	)

	_safe_set(
		moon_light,
		"directional_shadow_blend_splits",
		false
	)

	_safe_set(
		moon_light,
		"shadow_opacity",
		moon_shadow_opacity
	)

	_safe_set(
		moon_light,
		"shadow_bias",
		moon_shadow_bias
	)

	_safe_set(
		moon_light,
		"shadow_normal_bias",
		moon_shadow_normal_bias
	)


func _find_moon_light() -> DirectionalLight3D:
	if not moon_light_path.is_empty():
		var assigned_light: DirectionalLight3D = (
			get_node_or_null(moon_light_path)
			as DirectionalLight3D
		)

		if assigned_light != null:
			return assigned_light

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


# ============================================================
# SAFE PROPERTY HELPERS
# ============================================================

func _safe_set(
	target: Object,
	property_name: String,
	value: Variant
) -> void:
	if target == null:
		return

	if _has_property(target, property_name):
		target.set(property_name, value)


func _has_property(
	target: Object,
	property_name: String
) -> bool:
	if target == null:
		return false

	for property_info: Dictionary in target.get_property_list():
		if str(
			property_info.get("name", "")
		) == property_name:
			return true

	return false
