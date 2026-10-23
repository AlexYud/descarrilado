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

## The wind materials made, by the asset's name (the tests look at them).
var materials: Array[ShaderMaterial] = []
var assets_changed: Array[String] = []

## The wind material of each asset whose tint is a material override of the instancer (the grass tufts): their
## instances get it directly, because setting the asset's override at run time makes the terrain redraw the editor's
## thumbnails, which only works in the editor.
var _override_materials: Dictionary = {}


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
		material.set_shader_parameter("wind_strength", strength)
		material.set_shader_parameter("wind_direction", direction)
		material.set_shader_parameter("wind_speed", speed)
