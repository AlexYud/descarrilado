@tool
extends WorldEnvironment
class_name HorrorNightEnvironment

@export var apply_on_ready: bool = true

@export var apply_now: bool = false:
	set(value):
		if value:
			call_deferred("apply_environment")
		apply_now = false

@export_category("Night Mood")
@export var background_color: Color = Color("#05080c")
@export var background_energy: float = 0.48

@export var ambient_color: Color = Color("#1a2330")
@export var ambient_energy: float = 0.28
@export var ambient_sky_contribution: float = 0.25

@export_category("Fog - Cheap")
@export var fog_enabled: bool = true
@export var fog_color: Color = Color("#6f7f92")
@export var fog_energy: float = 0.34
@export var fog_density: float = 0.032
@export var fog_height: float = 0.0
@export var fog_height_density: float = 0.075

@export_category("Volumetric Fog - Expensive")
@export var volumetric_fog_enabled: bool = false
@export var volumetric_fog_density: float = 0.018
@export var volumetric_fog_color: Color = Color("#5f6f82")
@export var volumetric_fog_length: float = 45.0
@export var volumetric_fog_detail_spread: float = 2.0

@export_category("Image Mood")
@export var exposure: float = 0.95
@export var brightness: float = 0.95
@export var contrast: float = 1.12
@export var saturation: float = 0.78

@export_category("Moon Light")
@export var moon_light_path: NodePath
@export var configure_moon_light: bool = true
@export var moon_color: Color = Color("#a9c4e4")
@export var moon_energy: float = 1.15
@export var moon_angle_degrees: Vector3 = Vector3(-42.0, -28.0, 0.0)

# Shadows are nice but can be expensive.
# Keep this off while building the forest.
@export var moon_shadow_enabled: bool = false


func _ready() -> void:
	if apply_on_ready:
		apply_environment()


func apply_environment() -> void:
	if environment == null:
		environment = Environment.new()

	var env: Environment = environment

	# Background / sky darkness.
	_safe_set(env, "background_mode", Environment.BG_COLOR)
	_safe_set(env, "background_color", background_color)
	_safe_set(env, "background_energy_multiplier", background_energy)

	# Ambient light.
	_safe_set(env, "ambient_light_color", ambient_color)
	_safe_set(env, "ambient_light_energy", ambient_energy)
	_safe_set(env, "ambient_light_sky_contribution", ambient_sky_contribution)

	# Tonemap / exposure.
	_safe_set(env, "tonemap_exposure", exposure)

	# Regular fog. Cheaper than volumetric fog.
	_safe_set(env, "fog_enabled", fog_enabled)
	_safe_set(env, "fog_light_color", fog_color)
	_safe_set(env, "fog_light_energy", fog_energy)
	_safe_set(env, "fog_density", fog_density)
	_safe_set(env, "fog_height", fog_height)
	_safe_set(env, "fog_height_density", fog_height_density)

	# Volumetric fog. Beautiful, but expensive.
	_safe_set(env, "volumetric_fog_enabled", volumetric_fog_enabled)
	_safe_set(env, "volumetric_fog_density", volumetric_fog_density)
	_safe_set(env, "volumetric_fog_albedo", volumetric_fog_color)
	_safe_set(env, "volumetric_fog_length", volumetric_fog_length)
	_safe_set(env, "volumetric_fog_detail_spread", volumetric_fog_detail_spread)

	# Color correction.
	_safe_set(env, "adjustment_enabled", true)
	_safe_set(env, "adjustment_brightness", brightness)
	_safe_set(env, "adjustment_contrast", contrast)
	_safe_set(env, "adjustment_saturation", saturation)

	# Keep glow off. Glow can make fog brighter and cost more.
	_safe_set(env, "glow_enabled", false)

	if configure_moon_light:
		_apply_moon_light()


func _apply_moon_light() -> void:
	if moon_light_path.is_empty():
		return

	var moon_light: DirectionalLight3D = get_node_or_null(moon_light_path) as DirectionalLight3D

	if moon_light == null:
		push_warning("HorrorNightEnvironment: Moon light path is empty or invalid.")
		return

	moon_light.light_color = moon_color
	moon_light.light_energy = moon_energy
	moon_light.rotation_degrees = moon_angle_degrees
	moon_light.shadow_enabled = moon_shadow_enabled


func _safe_set(target: Object, property_name: String, value: Variant) -> void:
	if _has_property(target, property_name):
		target.set(property_name, value)


func _has_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if str(property_info.name) == property_name:
			return true

	return false
