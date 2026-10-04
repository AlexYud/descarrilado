extends Node3D
class_name ClearingForestRing

## Walls in a circular clearing with forest, so the player never meets an
## invisible wall on open ground: a ring of trees and undergrowth (MultiMesh,
## one draw call per mesh) with an invisible collision wall just inside it.
##
## One gap stays open, a short corridor that ends in a dead end, standing for
## the narrow passage the player came through. Everything is built at runtime
## from a seed, so the ring is cheap to tweak and identical on every run.

@export_category("Shape")
## Distance from this node's origin to the inner edge of the forest.
@export var clearing_radius: float = 10.5
@export var forest_depth: float = 7.0

## Direction of the passage, as atan2(z, x) of its centre.
@export var gap_angle: float = 2.936
@export var gap_half_width: float = 1.4
@export var corridor_length: float = 6.0

@export_category("Vegetation")
@export var seed_value: int = 7731
@export var tree_meshes: Array[Mesh] = []
@export var bush_meshes: Array[Mesh] = []
@export var small_meshes: Array[Mesh] = []
@export var tree_count: int = 30
@export var bush_count: int = 110
@export var small_count: int = 70

## Keeps the middle of the clearing free of small plants.
@export var small_plants_keep_out_radius: float = 4.5

@export_category("Collision")
@export var wall_height: float = 4.0
@export var wall_thickness: float = 0.6
@export var wall_segments: int = 40

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value
	_add_vegetation(tree_meshes, tree_count, clearing_radius + 1.0, 0.95, 1.5, true)
	_add_vegetation(bush_meshes, bush_count, clearing_radius + 0.2, 0.8, 1.3, true)
	_add_vegetation(small_meshes, small_count, small_plants_keep_out_radius, 0.7, 1.2, false)
	_build_walls()


## True when a point at `radius` and `angle` falls inside the passage corridor.
func _in_gap(radius: float, angle: float, margin: float) -> bool:
	var offset: float = absf(angle_difference(angle, gap_angle)) * radius
	return offset < gap_half_width + margin


func _add_vegetation(
	meshes: Array[Mesh],
	count: int,
	inner_radius: float,
	min_scale: float,
	max_scale: float,
	in_forest_band: bool
) -> void:
	if meshes.is_empty():
		return

	var outer_radius: float = clearing_radius + forest_depth
	var per_mesh: Array[Array] = []
	for mesh_index: int in meshes.size():
		var empty_list: Array[Transform3D] = []
		per_mesh.append(empty_list)

	for i: int in count:
		var radius: float
		if in_forest_band:
			radius = _rng.randf_range(inner_radius, outer_radius)
		else:
			radius = _rng.randf_range(inner_radius, clearing_radius - 0.5)

		var angle: float = _rng.randf_range(-PI, PI)
		if _in_gap(radius, angle, 1.2):
			continue

		var scale_factor: float = _rng.randf_range(min_scale, max_scale)
		var plant_basis: Basis = Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		plant_basis = plant_basis.scaled(Vector3.ONE * scale_factor)
		var origin: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var mesh_index: int = _rng.randi_range(0, meshes.size() - 1)
		var list: Array[Transform3D] = per_mesh[mesh_index]
		list.append(Transform3D(plant_basis, origin))

	for mesh_index: int in meshes.size():
		var transforms: Array[Transform3D] = per_mesh[mesh_index]
		_add_multimesh(meshes[mesh_index], transforms, in_forest_band)


func _add_multimesh(
	mesh: Mesh,
	transforms: Array[Transform3D],
	casts_shadow: bool
) -> void:
	if transforms.is_empty():
		return

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])

	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if casts_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	add_child(instance)


## An invisible wall just inside the forest, with the passage corridor cut out.
func _build_walls() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "InvisibleWalls"
	add_child(body)

	var wall_radius: float = clearing_radius + 0.6
	var segment_angle: float = TAU / wall_segments
	var segment_length: float = wall_radius * segment_angle * 1.08

	for i: int in wall_segments:
		var angle: float = -PI + (i + 0.5) * segment_angle
		if _in_gap(wall_radius, angle, 0.3):
			continue

		_add_wall_box(
			body,
			Vector3(wall_thickness, wall_height, segment_length),
			Vector3(cos(angle) * wall_radius, wall_height * 0.5, sin(angle) * wall_radius),
			-angle
		)

	# Corridor: two side walls and a dead end.
	var direction: Vector3 = Vector3(cos(gap_angle), 0.0, sin(gap_angle))
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var corridor_start: float = wall_radius - 0.5
	var corridor_centre: float = corridor_start + corridor_length * 0.5
	for sign_value: float in [-1.0, 1.0]:
		_add_wall_box(
			body,
			Vector3(corridor_length, wall_height, wall_thickness),
			direction * corridor_centre + side * (gap_half_width * sign_value)
			+ Vector3.UP * wall_height * 0.5,
			-gap_angle
		)

	_add_wall_box(
		body,
		Vector3(wall_thickness, wall_height, gap_half_width * 2.0 + wall_thickness),
		direction * (corridor_start + corridor_length) + Vector3.UP * wall_height * 0.5,
		-gap_angle
	)


func _add_wall_box(
	body: StaticBody3D,
	size: Vector3,
	position_value: Vector3,
	yaw: float
) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(Basis(Vector3.UP, yaw), position_value)
	body.add_child(collision)
