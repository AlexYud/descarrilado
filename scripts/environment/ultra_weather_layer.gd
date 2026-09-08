extends Node3D
class_name UltraWeatherLayer


const QUALITY_ULTRA: int = 3
const PUDDLE_RENDER_LAYER: int = 1 << 19

const GROUND_MIST_SHADER: Shader = preload(
	"res://assets/shaders/ultra_ground_mist.gdshader"
)
const PUDDLE_SHADER: Shader = preload(
	"res://assets/shaders/ultra_puddle.gdshader"
)

const PUDDLE_LAYOUT: Array[Vector4] = [
	Vector4(-2.20, -27.0, 1.75, 0.78),
	Vector4(2.05, -22.0, 1.30, 0.68),
	Vector4(-2.35, -16.0, 1.05, 0.55),
	Vector4(2.15, -10.0, 1.65, 0.72),
	Vector4(-2.10, -4.5, 1.35, 0.62),
	Vector4(2.25, 2.0, 1.10, 0.56),
	Vector4(-2.30, 7.5, 1.80, 0.76),
	Vector4(2.05, 13.5, 1.45, 0.64),
	Vector4(-2.15, 19.5, 1.20, 0.58),
	Vector4(2.20, 25.0, 1.70, 0.72),
	Vector4(-2.25, 30.5, 1.30, 0.60),
]

@export_category("Scene References")
@export var terrain_path: NodePath = ^"../Terrain3D"
@export var player_path: NodePath = ^"../Player"

@export_category("Wet Ground")
@export_range(0.0, 1.0, 0.01)
var wet_grass_roughness: float = 0.42
@export_range(0.0, 1.0, 0.01)
var wet_dirt_roughness: float = 0.27

@export_category("Local Mist")
@export_range(0.0, 0.2, 0.001)
var center_mist_density: float = 0.040
@export_range(0.0, 0.2, 0.001)
var side_mist_density: float = 0.050

var _effects_created: bool = false
var _ultra_enabled: bool = false
var _effect_nodes: Array[VisualInstance3D] = []
var _terrain_original_roughness: Dictionary = {}
var _flashlight_original_fog_energy: Dictionary = {}


func _ready() -> void:
	if not GameSettings.quality_preset_changed.is_connected(
		_on_quality_preset_changed
	):
		GameSettings.quality_preset_changed.connect(
			_on_quality_preset_changed
		)

	call_deferred("_apply_current_quality")


func _exit_tree() -> void:
	_restore_terrain_roughness()
	_restore_flashlight_fog_energy()

	if GameSettings.quality_preset_changed.is_connected(
		_on_quality_preset_changed
	):
		GameSettings.quality_preset_changed.disconnect(
			_on_quality_preset_changed
		)


func _apply_current_quality() -> void:
	_set_ultra_enabled(
		GameSettings.get_quality_preset() == QUALITY_ULTRA
	)


func _on_quality_preset_changed(preset: int) -> void:
	_set_ultra_enabled(preset == QUALITY_ULTRA)


func _set_ultra_enabled(enabled: bool) -> void:
	_ultra_enabled = enabled

	if enabled and not _effects_created:
		_create_weather_effects()

	for effect_node: VisualInstance3D in _effect_nodes:
		if is_instance_valid(effect_node):
			effect_node.visible = enabled

	_apply_terrain_wetness(enabled)
	_apply_flashlight_fog_energy(enabled)


func _create_weather_effects() -> void:
	_effects_created = true
	_create_ground_mist()
	_create_puddles()
	_create_reflection_probes()


func _create_ground_mist() -> void:
	_create_mist_volume(
		"CenterGroundMist",
		Vector3(0.0, 0.45, 0.0),
		Vector3(11.5, 3.4, 72.0),
		RenderingServer.FOG_VOLUME_SHAPE_BOX,
		center_mist_density,
		0.0
	)
	_create_mist_volume(
		"LeftMistBank",
		Vector3(-4.1, 0.35, -10.0),
		Vector3(8.0, 3.8, 38.0),
		RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID,
		side_mist_density,
		3.7
	)
	_create_mist_volume(
		"RightMistBank",
		Vector3(4.0, 0.30, 16.0),
		Vector3(7.5, 3.6, 34.0),
		RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID,
		side_mist_density,
		8.9
	)
	_create_train_fog_exclusions()


func _create_train_fog_exclusions() -> void:
	var wagon_positions: Array[float] = [
		0.0,
		14.0,
		-14.0,
		-28.0,
		28.0,
	]

	for wagon_index: int in wagon_positions.size():
		var clear_volume: FogVolume = FogVolume.new()
		clear_volume.name = "TrainFogExclusion%02d" % (
			wagon_index + 1
		)
		clear_volume.position = Vector3(
			0.0,
			1.25,
			wagon_positions[wagon_index]
		)
		clear_volume.size = Vector3(3.25, 2.65, 11.8)
		clear_volume.shape = (
			RenderingServer.FOG_VOLUME_SHAPE_BOX
		)

		var clear_material: FogMaterial = FogMaterial.new()
		clear_material.density = -0.14
		clear_material.edge_fade = 0.85
		clear_volume.material = clear_material

		add_child(clear_volume)
		_effect_nodes.append(clear_volume)


func _create_mist_volume(
	node_name: String,
	volume_position: Vector3,
	volume_size: Vector3,
	volume_shape: RenderingServer.FogVolumeShape,
	density: float,
	phase: float
) -> void:
	var fog_volume: FogVolume = FogVolume.new()
	fog_volume.name = node_name
	fog_volume.position = volume_position
	fog_volume.size = volume_size
	fog_volume.shape = volume_shape

	var fog_material: ShaderMaterial = ShaderMaterial.new()
	fog_material.shader = GROUND_MIST_SHADER
	fog_material.set_shader_parameter("density", density)
	fog_material.set_shader_parameter("phase", phase)
	fog_volume.material = fog_material

	add_child(fog_volume)
	_effect_nodes.append(fog_volume)


func _create_puddles() -> void:
	var puddle_index: int = 0

	for puddle_data: Vector4 in PUDDLE_LAYOUT:
		var puddle_position: Vector3 = Vector3(
			puddle_data.x,
			0.0,
			puddle_data.y
		)
		puddle_position.y = _get_terrain_height(puddle_position) + 0.025

		var puddle: MeshInstance3D = MeshInstance3D.new()
		puddle.name = "Puddle%02d" % (puddle_index + 1)
		puddle.position = puddle_position
		puddle.rotation.y = deg_to_rad(
			fmod(float(puddle_index * 47), 180.0)
		)
		puddle.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		puddle.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		puddle.layers = PUDDLE_RENDER_LAYER
		puddle.visibility_range_end = 46.0
		puddle.visibility_range_end_margin = 4.0

		var puddle_mesh: PlaneMesh = PlaneMesh.new()
		puddle_mesh.orientation = PlaneMesh.FACE_Y
		puddle_mesh.size = Vector2(
			puddle_data.z * 2.0,
			puddle_data.w * 2.0
		)
		puddle.mesh = puddle_mesh

		var puddle_material: ShaderMaterial = ShaderMaterial.new()
		puddle_material.shader = PUDDLE_SHADER
		puddle_material.set_shader_parameter(
			"shape_seed",
			float(puddle_index) * 1.731
		)
		puddle_material.set_shader_parameter(
			"ripple_phase",
			float(puddle_index) * 0.83
		)
		puddle.material_override = puddle_material

		add_child(puddle)
		_effect_nodes.append(puddle)
		puddle_index += 1


func _create_reflection_probes() -> void:
	_create_reflection_probe("WetReflectionNorth", 17.0)
	_create_reflection_probe("WetReflectionSouth", -19.0)


func _create_reflection_probe(
	node_name: String,
	z_position: float
) -> void:
	var reflection_probe: ReflectionProbe = ReflectionProbe.new()
	reflection_probe.name = node_name
	reflection_probe.position = Vector3(0.0, 2.8, z_position)
	reflection_probe.size = Vector3(15.0, 8.0, 38.0)
	reflection_probe.origin_offset = Vector3(0.0, 0.8, 0.0)
	reflection_probe.intensity = 0.72
	reflection_probe.max_distance = 52.0
	reflection_probe.blend_distance = 3.0
	reflection_probe.enable_shadows = false
	reflection_probe.cull_mask = (
		reflection_probe.cull_mask & ~PUDDLE_RENDER_LAYER
	)
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	reflection_probe.mesh_lod_threshold = 2.0

	add_child(reflection_probe)
	_effect_nodes.append(reflection_probe)


func _get_terrain_height(world_position: Vector3) -> float:
	var terrain: Node = get_node_or_null(terrain_path)

	if terrain == null:
		return 0.0

	var terrain_data: Variant = terrain.get("data")

	if (
		terrain_data == null
		or not terrain_data.has_method("get_height")
	):
		return 0.0

	var height: float = float(
		terrain_data.call("get_height", world_position)
	)

	if is_nan(height):
		return 0.0

	return height


func _apply_terrain_wetness(enabled: bool) -> void:
	var terrain: Node = get_node_or_null(terrain_path)

	if terrain == null:
		return

	var terrain_assets: Variant = terrain.get("assets")

	if terrain_assets == null:
		return

	var texture_list: Variant = terrain_assets.get("texture_list")

	if not texture_list is Array:
		return

	var texture_index: int = 0

	for texture_asset: Variant in texture_list:
		if texture_asset == null:
			texture_index += 1
			continue

		if not _terrain_original_roughness.has(texture_asset):
			_terrain_original_roughness[texture_asset] = float(
				texture_asset.get("roughness")
			)

		var original_roughness: float = float(
			_terrain_original_roughness[texture_asset]
		)
		var wet_roughness: float = (
			wet_grass_roughness
			if texture_index == 0
			else wet_dirt_roughness
		)
		texture_asset.set(
			"roughness",
			minf(original_roughness, wet_roughness)
			if enabled
			else original_roughness
		)
		texture_index += 1

	terrain_assets.emit_changed()


func _restore_terrain_roughness() -> void:
	for texture_asset: Variant in _terrain_original_roughness:
		if is_instance_valid(texture_asset):
			texture_asset.set(
				"roughness",
				float(_terrain_original_roughness[texture_asset])
			)

	_terrain_original_roughness.clear()


func _apply_flashlight_fog_energy(enabled: bool) -> void:
	var player: Node = get_node_or_null(player_path)

	if player == null:
		return

	var spot_lights: Array[Node] = player.find_children(
		"*",
		"SpotLight3D",
		true,
		false
	)

	for light_node: Node in spot_lights:
		var spot_light: SpotLight3D = light_node as SpotLight3D

		if spot_light == null:
			continue

		if not _flashlight_original_fog_energy.has(spot_light):
			_flashlight_original_fog_energy[spot_light] = (
				spot_light.light_volumetric_fog_energy
			)

		var ultra_energy: float = (
			0.24
			if spot_light.name == &"FlashlightFill"
			else 0.85
		)
		spot_light.light_volumetric_fog_energy = (
			ultra_energy
			if enabled
			else float(
				_flashlight_original_fog_energy[spot_light]
			)
		)


func _restore_flashlight_fog_energy() -> void:
	for light: Variant in _flashlight_original_fog_energy:
		if is_instance_valid(light):
			light.light_volumetric_fog_energy = float(
				_flashlight_original_fog_energy[light]
			)

	_flashlight_original_fog_energy.clear()
