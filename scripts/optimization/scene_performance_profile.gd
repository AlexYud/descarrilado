extends Node
class_name ScenePerformanceProfile


@export_category("General")

@export var apply_on_ready: bool = true
@export var print_results: bool = true


@export_category("Universal Render Distance")

# Absolute camera cutoff.
# Anything farther than this will not be rendered.
@export var camera_far_distance: float = 45.0

# Applies to MeshInstance3D, CSGShape3D, particles,
# MultiMeshInstance3D and other GeometryInstance3D nodes.
@export var geometry_render_distance: float = 40.0

# Small margin prevents objects rapidly appearing/disappearing
# when standing exactly at the distance limit.
@export var geometry_distance_margin: float = 2.0


@export_category("Omni and Spot Lights")

@export var configure_local_lights: bool = true

# The light begins fading at this camera distance.
@export var light_fade_begin: float = 10.0

# The light disappears after:
# light_fade_begin + light_fade_length.
@export var light_fade_length: float = 5.0

# Shadows disappear sooner than the light.
@export var light_shadow_distance: float = 7.0


@export_category("Directional Light")

@export var configure_directional_light: bool = true

# Maximum distance for moon/sun shadows.
@export var directional_shadow_distance: float = 25.0

@export_range(0.0, 1.0, 0.05)
var directional_shadow_fade_start: float = 0.75


@export_category("Automatic Mesh LOD")

@export var configure_mesh_lod: bool = true

# Higher values make imported mesh LODs activate sooner.
# Godot's default is 1.0.
@export_range(0.25, 8.0, 0.25)
var mesh_lod_threshold: float = 2.0


var camera_count: int = 0
var geometry_count: int = 0
var local_light_count: int = 0
var directional_light_count: int = 0


func _ready() -> void:
	if not apply_on_ready:
		return

	_apply_global_settings()

	# Wait until the full scene has finished entering the tree.
	call_deferred("_apply_to_current_scene")

	# Also configure objects created later, such as OutsideLoop copies.
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree() == null:
		return

	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func apply_profile_again() -> void:
	_apply_global_settings()
	_apply_to_current_scene()


func _apply_global_settings() -> void:
	if configure_mesh_lod:
		get_tree().root.mesh_lod_threshold = mesh_lod_threshold


func _apply_to_current_scene() -> void:
	camera_count = 0
	geometry_count = 0
	local_light_count = 0
	directional_light_count = 0

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		scene_root = get_parent()

	_apply_recursive(scene_root)

	if print_results:
		print(
			"ScenePerformanceProfile applied: ",
			camera_count,
			" cameras, ",
			geometry_count,
			" geometry nodes, ",
			local_light_count,
			" local lights, ",
			directional_light_count,
			" directional lights."
		)


func _apply_recursive(node: Node) -> void:
	_apply_to_node(node)

	for child: Node in node.get_children():
		_apply_recursive(child)


func _on_node_added(node: Node) -> void:
	call_deferred("_apply_new_node", node)


func _apply_new_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	_apply_to_node(node)


func _apply_to_node(node: Node) -> void:
	if node is Camera3D:
		_configure_camera(node as Camera3D)
		return

	if node is DirectionalLight3D:
		_configure_directional_light(node as DirectionalLight3D)
		return

	if node is OmniLight3D or node is SpotLight3D:
		_configure_local_light(node as Light3D)
		return

	if node is GeometryInstance3D:
		_configure_geometry(node as GeometryInstance3D)


func _configure_camera(camera: Camera3D) -> void:
	camera.far = maxf(
		camera_far_distance,
		camera.near + 1.0
	)

	camera_count += 1


func _configure_geometry(geometry: GeometryInstance3D) -> void:
	if geometry_render_distance <= 0.0:
		return

	geometry.visibility_range_end = geometry_render_distance
	geometry.visibility_range_end_margin = maxf(
		0.0,
		geometry_distance_margin
	)

	# Hard cutoff is cheaper than transparency-based fading.
	# Your fog should hide most of the transition.
	geometry.visibility_range_fade_mode = (
		GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	)

	geometry_count += 1


func _configure_local_light(light: Light3D) -> void:
	if not configure_local_lights:
		return

	light.distance_fade_enabled = true
	light.distance_fade_begin = maxf(
		0.0,
		light_fade_begin
	)
	light.distance_fade_length = maxf(
		0.1,
		light_fade_length
	)
	light.distance_fade_shadow = clampf(
		light_shadow_distance,
		0.0,
		light.distance_fade_begin + light.distance_fade_length
	)

	local_light_count += 1


func _configure_directional_light(
	light: DirectionalLight3D
) -> void:
	if not configure_directional_light:
		return

	if not light.shadow_enabled:
		return

	light.directional_shadow_max_distance = maxf(
		1.0,
		directional_shadow_distance
	)

	light.directional_shadow_fade_start = clampf(
		directional_shadow_fade_start,
		0.0,
		1.0
	)

	directional_light_count += 1
