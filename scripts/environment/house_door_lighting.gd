extends Node3D
class_name HouseDoorLighting

## The master bedroom as the door shot lights it: nearly dark, cold, and readable, the way a horror film lights a distant door.
## Built from the usual few pieces, all in the house's local space and all dim: a cold fill so the room is only just there (the
## bed, the walls, the floor are shapes, not detail); the moon through the open window, one hard pale patch across the floor and
## the bed, the only thing that looks like a source; a narrow, dim pool on the door and the floor in front of it, so the eye goes
## there and the door is the brightest quiet thing in the frame; a thin haze in the room for the beams to show in (the flashlight
## sweep too); and a soft vignette that closes the corners of the picture. Nothing is lit from behind the door.
##
## `fade_to(level, seconds)` brings the whole rig in or out together; the moon drifts a little, as thin cloud passes it.

@export_group("Light")
@export var fill_position: Vector3 = Vector3(8.0, 2.3, 3.1)
@export var fill_color: Color = Color(0.4, 0.5, 0.78)
@export var fill_energy: float = 0.0
@export var fill_range: float = 8.5
@export var moon_position: Vector3 = Vector3(8.14, 2.5, -0.9)
@export var moon_target: Vector3 = Vector3(6.7, 0.0, 3.4)
@export var moon_color: Color = Color(0.62, 0.72, 1.0)
@export var moon_energy: float = 0.0
@export var moon_angle: float = 30.0
@export var door_position: Vector3 = Vector3(7.43, 2.4, 1.2)
@export var door_target: Vector3 = Vector3(7.43, 0.9, 6.2)
@export var door_color: Color = Color(0.78, 0.84, 0.95)
@export var door_energy: float = 1.5
@export var door_angle: float = 34.0

@export_group("Air and frame")
@export var haze_center: Vector3 = Vector3(8.1, 1.3, 3.1)
@export var haze_size: Vector3 = Vector3(6.9, 2.6, 6.0)
@export var haze_density: float = 0.04
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.7

var level: float = 0.0

var _fill: OmniLight3D = null
var _moon: SpotLight3D = null
var _pool: SpotLight3D = null
var _haze: FogVolume = null
var _haze_material: FogMaterial = null
var _vignette: ColorRect = null
var _layer: CanvasLayer = null
var _tween: Tween = null
var _clock: float = 0.0


func _ready() -> void:
	_fill = OmniLight3D.new()
	_fill.name = "Fill"
	_fill.light_color = fill_color
	_fill.omni_range = fill_range
	_fill.omni_attenuation = 1.3
	_fill.light_specular = 0.0
	_fill.shadow_enabled = true
	_fill.position = fill_position
	add_child(_fill)

	_moon = SpotLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = moon_color
	_moon.spot_range = 12.0
	_moon.spot_angle = moon_angle
	_moon.spot_attenuation = 0.6
	_moon.shadow_enabled = true
	_moon.light_volumetric_fog_energy = 2.0
	_moon.position = moon_position
	add_child(_moon)
	_moon.look_at(to_global(moon_target), Vector3.UP)

	_pool = SpotLight3D.new()
	_pool.name = "DoorPool"
	_pool.light_color = door_color
	_pool.spot_range = 9.0
	_pool.spot_angle = door_angle
	_pool.spot_attenuation = 1.0
	_pool.light_specular = 0.0
	_pool.shadow_enabled = false
	_pool.light_volumetric_fog_energy = 1.0
	_pool.position = door_position
	add_child(_pool)
	_pool.look_at(to_global(door_target), Vector3.UP)

	_haze = FogVolume.new()
	_haze.name = "Haze"
	_haze.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_haze.size = haze_size
	_haze.position = haze_center
	_haze_material = FogMaterial.new()
	_haze_material.albedo = Color(0.7, 0.78, 0.92)
	_haze_material.emission = Color(0.004, 0.006, 0.01)
	_haze_material.edge_fade = 0.4
	_haze.material = _haze_material
	add_child(_haze)

	_layer = CanvasLayer.new()
	_layer.name = "Vignette"
	_layer.layer = 8
	add_child(_layer)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float strength : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tvec2 p = UV - vec2(0.5);\n\tp.x *= 1.15;\n\tfloat edge = smoothstep(0.28, 0.78, length(p));\n\tCOLOR = vec4(0.0, 0.0, 0.0, edge * strength);\n}\n"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	_vignette.material = material
	_layer.add_child(_vignette)

	_apply()


func _process(delta: float) -> void:
	if level <= 0.0:
		return

	_clock += delta
	_apply()


## The whole rig to `target` (0 off, 1 full) over `seconds` (0: at once).
func fade_to(target: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if seconds <= 0.0:
		level = target
		_apply()
		return

	_tween = create_tween()
	_tween.tween_method(_set_level, level, target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_level(value: float) -> void:
	level = value
	_apply()


func _apply() -> void:
	if _fill == null:
		return

	var on: bool = level > 0.001
	_fill.visible = on and fill_energy > 0.0
	_moon.visible = on and moon_energy > 0.0
	_pool.visible = on
	_haze.visible = on
	_layer.visible = on
	# Thin cloud passing the moon: a slow, small drift, never a flicker.
	var drift: float = 1.0 + 0.07 * sin(_clock * 0.37) + 0.04 * sin(_clock * 0.91 + 1.3)
	_fill.light_energy = fill_energy * level
	_moon.light_energy = moon_energy * level * drift
	_pool.light_energy = door_energy * level
	_haze_material.density = haze_density * level
	(_vignette.material as ShaderMaterial).set_shader_parameter(&"strength", vignette_strength * level)
