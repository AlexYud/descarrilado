extends Node3D
class_name RuntimeMultiMeshBatcher


## Combines repeated direct-child MeshInstance3D nodes at runtime while
## leaving the authored scene intact in the editor. Meshes are divided into
## spatial cells so Godot can still cull distant parts of a large group.

@export_category("Batching")

@export var batch_on_ready: bool = true
@export_range(16.0, 512.0, 1.0) var chunk_size: float = 96.0
@export_range(2, 256, 1) var minimum_batch_size: int = 2
@export var print_results: bool = true


func _ready() -> void:
	if batch_on_ready:
		_batch_repeated_meshes()


func _batch_repeated_meshes() -> void:
	var groups: Dictionary = _collect_groups()
	var source_count: int = 0
	var batch_count: int = 0

	for key: String in groups:
		var sources: Array = groups[key]

		if sources.size() < minimum_batch_size:
			continue

		_create_batch(sources, batch_count + 1)
		source_count += sources.size()
		batch_count += 1

	if print_results and source_count > 0:
		print(
			"RuntimeMultiMeshBatcher: combined ",
			source_count,
			" meshes into ",
			batch_count,
			" spatial batches under ",
			name,
			"."
		)


func _collect_groups() -> Dictionary:
	var groups: Dictionary = {}

	for child: Node in get_children():
		var source: MeshInstance3D = child as MeshInstance3D

		if source == null or source.mesh == null or not source.visible:
			continue

		var cell_x: int = floori(source.position.x / chunk_size)
		var cell_z: int = floori(source.position.z / chunk_size)
		var material_id: int = 0
		var overlay_id: int = 0

		if source.material_override != null:
			material_id = source.material_override.get_instance_id()
		if source.material_overlay != null:
			overlay_id = source.material_overlay.get_instance_id()

		var key: String = "%d:%d:%d:%d:%d:%d:%d" % [
			source.mesh.get_instance_id(),
			material_id,
			overlay_id,
			int(source.cast_shadow),
			source.layers,
			cell_x,
			cell_z,
		]

		if not groups.has(key):
			groups[key] = []

		var group: Array = groups[key]
		group.append(source)

	return groups


func _create_batch(sources: Array, batch_number: int) -> void:
	var first: MeshInstance3D = sources[0] as MeshInstance3D

	if first == null or first.mesh == null:
		return

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = first.mesh
	multimesh.instance_count = sources.size()
	multimesh.visible_instance_count = -1

	for index: int in range(sources.size()):
		var source: MeshInstance3D = sources[index] as MeshInstance3D
		multimesh.set_instance_transform(index, source.transform)

	var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
	batch.name = "RuntimeBatch%02d" % batch_number
	batch.multimesh = multimesh
	batch.material_override = first.material_override
	batch.material_overlay = first.material_overlay
	batch.cast_shadow = first.cast_shadow
	batch.layers = first.layers
	batch.extra_cull_margin = first.extra_cull_margin
	batch.visibility_range_begin = first.visibility_range_begin
	batch.visibility_range_begin_margin = first.visibility_range_begin_margin
	batch.visibility_range_end = first.visibility_range_end
	batch.visibility_range_end_margin = first.visibility_range_end_margin
	batch.visibility_range_fade_mode = first.visibility_range_fade_mode
	add_child(batch)

	# Keep the source nodes so child lights and authored NodePaths remain valid.
	# Removing only their mesh prevents duplicate rendering for this session.
	for item: Variant in sources:
		var source: MeshInstance3D = item as MeshInstance3D
		source.mesh = null
