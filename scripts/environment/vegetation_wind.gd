extends Node
class_name VegetationWind

## Makes the wind blow in the vegetation of a Terrain3D landscape (the dream intro).
##
## When the scene starts, every plant and tree mesh asset of the terrain gets wind materials that look like the
## ones it had (same textures, colours, cut-out and normal maps) and sway the vertices in a vertex shader (see
## `vegetation_wind.gdshaderinc`). Nothing is saved: the authored meshes, materials and terrain stay as they are, and
## only the running game has the wind. Rocks, the tent, the campfire, the bench and the far vista trees are left alone.
##
## Wind is the same everywhere: `strength` (0 is dead calm), `direction_degrees` (the way it blows in the ground
## plane, 0 toward +X, 90 toward +Z) and `speed`. Change them at any time, e.g. for a storm.

## The sway of each kind of plant: `sway` is how far its tip moves, as a share of its height, `flutter` how far
## single leaves quiver, in metres. Assets that are not listed are left still.
const PROFILES: Dictionary = {
	"tree_test": {"sway": 0.04, "flutter": 0.07},
	"mediun_generic_tree": {"sway": 0.04, "flutter": 0.07},
	"pitangueira": {"sway": 0.04, "flutter": 0.07},
	"araucaria": {"sway": 0.022, "flutter": 0.05},
	"big_foliage_01": {"sway": 0.14, "flutter": 0.03},
	"big_foliage_02": {"sway": 0.14, "flutter": 0.03},
	"medium_foliage_01": {"sway": 0.17, "flutter": 0.025},
	"medium_foliage_02": {"sway": 0.17, "flutter": 0.02},
	"tall_thin_foliage_01": {"sway": 0.24, "flutter": 0.02},
	"tall_thin_foliage_02": {"sway": 0.24, "flutter": 0.02},
	"kelp_like_foliage": {"sway": 0.2, "flutter": 0.02},
	"small_foliage_01": {"sway": 0.2, "flutter": 0.012},
	"small_foliage_02": {"sway": 0.2, "flutter": 0.012},
	"white_flower_01": {"sway": 0.26, "flutter": 0.012},
	"white_flower_02": {"sway": 0.26, "flutter": 0.012},
	# Leaf litter does not sway; it is listed so that it gets the wind's shader (and with it the hidden ground under the shelter's slab).
	"ground_leaves_01": {"sway": 0.0, "flutter": 0.0},
}

const LEAVES_SHADER: Shader = preload("res://assets/shaders/vegetation_wind_leaves.gdshader")
const BARK_SHADER: Shader = preload("res://assets/shaders/vegetation_wind_bark.gdshader")

@export var terrain: Terrain3D
@export var enabled: bool = true
@export_range(0.0, 2.0, 0.01) var strength: float = 1.0:
	set(value):
		strength = value
		_push_parameters()
@export_range(0.0, 360.0, 1.0) var direction_degrees: float = 25.0:
	set(value):
		direction_degrees = value
		_push_parameters()
@export_range(0.0, 4.0, 0.01) var speed: float = 1.0:
	set(value):
		speed = value
		_push_parameters()
## How far a body going through the plants reaches (metres; 0 is off): the plants near the player bend away from them (see `actor_local_offset` in the shader), and shiver if they brush them.
@export_range(0.0, 3.0, 0.05) var push_radius: float = 1.1:
	set(value):
		push_radius = value
		_push_parameters()
## False leaves the body to `set_actor` (the tests).
@export var follow_player: bool = true

## The wind materials made, by the asset's name (the tests look at them).
var materials: Array[ShaderMaterial] = []
var assets_changed: Array[String] = []

## The wind material of each asset whose tint is a material override of the instancer (the grass tufts): their
## instances get it directly, because setting the asset's override at run time makes the terrain redraw the editor's
## thumbnails, which only works in the editor.
var _override_materials: Dictionary = {}
var _hidden_rect: Rect2 = Rect2()
var _hidden_below: float = 1000.0


func _ready() -> void:
	if Engine.is_editor_hint() or not enabled:
		return

	if terrain == null:
		var found: Array[Node] = get_tree().root.find_children("*", "Terrain3D", true, false)
		terrain = found.front() as Terrain3D if not found.is_empty() else null

	if terrain == null or terrain.assets == null:
		push_warning("VegetationWind: no Terrain3D with assets to blow on.")
		return

	for index: int in terrain.assets.get_mesh_count():
		var asset: Terrain3DMeshAsset = terrain.assets.get_mesh_asset(index)
		if asset != null and PROFILES.has(asset.name):
			_apply_to_asset(asset)

	_wind_existing_instances()
	get_tree().node_added.connect(_on_node_added)
	_push_parameters()


## Swaps the materials of one asset: its mesh's surfaces, or the asset's own override (the tinted ones).
func _apply_to_asset(asset: Terrain3DMeshAsset) -> void:
	var mesh: Mesh = asset.get_mesh(0)
	if mesh == null:
		return

	var profile: Dictionary = PROFILES[asset.name]
	var height: float = maxf(mesh.get_aabb().size.y, 0.2)
	var sway: float = float(profile["sway"]) * height
	var flutter: float = float(profile["flutter"])

	var override: BaseMaterial3D = asset.material_override as BaseMaterial3D
	if override != null:
		_override_materials[asset.id] = _make_material(override, height, sway, flutter)
	else:
		for surface: int in mesh.get_surface_count():
			var source: BaseMaterial3D = mesh.surface_get_material(surface) as BaseMaterial3D
			if source != null:
				mesh.surface_set_material(surface, _make_material(source, height, sway, flutter))

	assets_changed.append(asset.name)


## A wind material that looks like `source`: a cut-out card (leaves, grass) or an opaque textured one (bark).
func _make_material(source: BaseMaterial3D, height: float, sway: float, flutter: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var is_leaf: bool = source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shader = LEAVES_SHADER if is_leaf else BARK_SHADER
	material.resource_name = source.resource_name
	material.set_shader_parameter("albedo_texture", source.albedo_texture)
	material.set_shader_parameter("albedo_color", source.albedo_color)
	material.set_shader_parameter("roughness", source.roughness)
	if is_leaf:
		material.set_shader_parameter("alpha_scissor", source.alpha_scissor_threshold)
	else:
		material.set_shader_parameter("normal_texture", source.normal_texture)
		material.set_shader_parameter("normal_scale", source.normal_scale)
		material.set_shader_parameter("roughness_texture", source.roughness_texture)

	material.set_shader_parameter("bend_height", height)
	material.set_shader_parameter("sway_amount", sway)
	# Only the leaves quiver; the bark bends with them.
	material.set_shader_parameter("flutter_amount", flutter if is_leaf else 0.0)
	materials.append(material)
	return material


func _wind_existing_instances() -> void:
	if _override_materials.is_empty():
		return

	for node: Node in terrain.find_children("*", "MultiMeshInstance3D", true, false):
		_wind_instance(node as MultiMeshInstance3D)


## Instances the terrain makes later (a region streamed in) get their material as soon as they enter the tree.
func _on_node_added(node: Node) -> void:
	if node is MultiMeshInstance3D and not _override_materials.is_empty() and terrain.is_ancestor_of(node):
		_wind_instance.call_deferred(node as MultiMeshInstance3D)


## The terrain names its instances `MMI3D_<chunk>_M<mesh id>_L<lod>`.
func _wind_instance(instance: MultiMeshInstance3D) -> void:
	if not is_instance_valid(instance):
		return

	var parts: PackedStringArray = String(instance.name).split("_")
	if parts.size() < 3 or not parts[parts.size() - 2].begins_with("M"):
		return

	var mesh_id: int = parts[parts.size() - 2].substr(1).to_int()
	if _override_materials.has(mesh_id):
		instance.material_override = _override_materials[mesh_id]


func _push_parameters() -> void:
	var direction: Vector2 = Vector2.from_angle(deg_to_rad(direction_degrees))
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("actor_radius", push_radius)
		material.set_shader_parameter("wind_strength", strength)
		material.set_shader_parameter("wind_direction", direction)
		material.set_shader_parameter("wind_speed", speed)


## A clearing of the plants along the walk of a camera that goes through the forest (the waiting shed's tape): roots nearer than `radius` metres (on the ground plane) to the segment `from`..`to` shrink to nothing,
## roots up to `band` metres further part of the way. `radius` 0 puts everything back. Meant to be set once for a whole shot, under a cut. Only in the running game; nothing of the terrain is touched.
func set_clearing_segment(from: Vector3, to: Vector3, radius: float, band: float = 0.4) -> void:
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("clearing_a", Vector4(from.x, from.y, from.z, radius))
		material.set_shader_parameter("clearing_b", to)
		material.set_shader_parameter("clearing_band", band)


## No plant shows in a rectangle of ground (`rect`: x and z in world metres) whose root is lower than `below` (world height): the ground under a slab. An empty rect puts everything back. Only in the running game;
## nothing of the terrain is touched.
func set_hidden_ground(rect: Rect2, below: float = 1000.0) -> void:
	_hidden_rect = rect
	_hidden_below = below
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("hide_rect", Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y) if rect.has_area() else Vector4(0.0, 0.0, 0.0, 0.0))
		material.set_shader_parameter("hide_below", below)


## The mesh the terrain draws an asset with (its wind materials on it), by the asset's name (the folder name of its model: `small_foliage_01`); null if there is none. Plants of the clearing's dressing use it so that they sway as the forest does.
func asset_mesh(asset_name: String) -> Mesh:
	if terrain == null or terrain.assets == null:
		return null

	for index: int in terrain.assets.get_mesh_count():
		var asset: Terrain3DMeshAsset = terrain.assets.get_mesh_asset(index)
		if asset != null and asset.name == asset_name and PROFILES.has(asset_name):
			return asset.get_mesh(0)
	return null


## The material the terrain gives every instance of an asset whose tint is a material override (the grass tufts), or null.
func asset_override_material(asset_name: String) -> Material:
	if terrain == null or terrain.assets == null:
		return null

	for index: int in terrain.assets.get_mesh_count():
		var asset: Terrain3DMeshAsset = terrain.assets.get_mesh_asset(index)
		if asset != null and asset.name == asset_name and _override_materials.has(asset.id):
			return _override_materials[asset.id] as Material
	return null


# ============================================================
# THE PLAYER GOING THROUGH THE PLANTS
# ============================================================

var _actor_previous: Vector3 = Vector3.INF
var _actor_speed: float = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or materials.is_empty() or not follow_player or push_radius <= 0.0:
		return

	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return

	# Where the feet are: the player's eyes are about 1.54 m over the ground.
	var camera: Node3D = player.get_node_or_null(^"Head/Camera3D") as Node3D
	var feet: Vector3 = player.global_position
	if camera != null:
		feet = Vector3(camera.global_position.x, camera.global_position.y - 1.54, camera.global_position.z)
	var speed: float = 0.0
	if _actor_previous != Vector3.INF and delta > 0.0:
		speed = Vector2(feet.x - _actor_previous.x, feet.z - _actor_previous.z).length() / delta
	_actor_previous = feet
	# (Smoothed: a frame's step is a poor measure of a walking speed.)
	_actor_speed = lerpf(_actor_speed, minf(speed, 8.0), clampf(delta * 8.0, 0.0, 1.0))
	set_actor(feet, _actor_speed)


## Puts the body that the plants make way for at `feet` (world), going `speed` metres a second.
func set_actor(feet: Vector3, speed: float) -> void:
	var value: Vector4 = Vector4(feet.x, feet.y, feet.z, speed)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("actor", value)
