@tool
extends MultiMeshInstance3D


# ============================================================
# SOURCE TREES
# ============================================================

@export_category("Source Trees")

## Every sibling beginning with this name will be copied.
## Examples: tree_test, tree_test2, tree_test16.
@export var source_name_prefix: String = "tree_test"

## Hides the original tree nodes after baking.
@export var hide_source_trees_after_bake: bool = true


# ============================================================
# EDITOR ACTIONS
# ============================================================

@export_category("Editor Actions")

## Enable this checkbox once to create the MultiMesh instances.
@export var bake_now: bool = false:
	set(value):
		bake_now = false

		if value and Engine.is_editor_hint():
			call_deferred("_bake_multimesh")


## Enable this checkbox to show the original trees again.
@export var restore_source_trees_now: bool = false:
	set(value):
		restore_source_trees_now = false

		if value and Engine.is_editor_hint():
			call_deferred("_restore_source_trees")


# ============================================================
# BAKE
# ============================================================

func _bake_multimesh() -> void:
	if not Engine.is_editor_hint():
		return

	if multimesh == null:
		push_error(
			"ForestMultiMeshBaker: MultiMesh resource is missing."
		)
		return

	if multimesh.mesh == null:
		push_error(
			"ForestMultiMeshBaker: Assign the tree mesh "
			+ "to the MultiMesh before baking."
		)
		return

	var forest_parent: Node = get_parent()

	if forest_parent == null:
		push_error(
			"ForestMultiMeshBaker: Parent forest node "
			+ "was not found."
		)
		return

	var source_trees: Array[Node3D] = []

	for child: Node in forest_parent.get_children():
		if child == self:
			continue

		var source_tree: Node3D = child as Node3D

		if source_tree == null:
			continue

		if not str(source_tree.name).begins_with(
			source_name_prefix
		):
			continue

		source_trees.append(source_tree)

	if source_trees.is_empty():
		push_error(
			"ForestMultiMeshBaker: No sibling trees beginning "
			+ "with '%s' were found."
			% source_name_prefix
		)
		return

	# Transform Format can only safely be changed while the
	# MultiMesh has no instances.
	multimesh.instance_count = 0
	multimesh.transform_format = MultiMesh.TRANSFORM_3D

	multimesh.instance_count = source_trees.size()
	multimesh.visible_instance_count = -1

	var multimesh_inverse: Transform3D = (
		global_transform.affine_inverse()
	)

	var baked_count: int = 0

	for source_tree: Node3D in source_trees:
		var source_mesh: MeshInstance3D = (
			_find_first_mesh_instance(source_tree)
		)

		if source_mesh == null:
			push_warning(
				"ForestMultiMeshBaker: No MeshInstance3D "
				+ "was found inside '%s'."
				% source_tree.name
			)
			continue

		# Use the mesh child's global transform. This preserves
		# offsets inside the imported GLB scene as well as the
		# tree root's position, rotation, and scale.
		var instance_transform: Transform3D = (
			multimesh_inverse
			* source_mesh.global_transform
		)

		multimesh.set_instance_transform(
			baked_count,
			instance_transform
		)

		baked_count += 1

	if baked_count != source_trees.size():
		multimesh.instance_count = baked_count
		multimesh.visible_instance_count = -1

	if hide_source_trees_after_bake:
		for source_tree: Node3D in source_trees:
			source_tree.visible = false

	visible = true

	print(
		"ForestMultiMeshBaker: Baked ",
		baked_count,
		" trees into ",
		name,
		"."
	)


# ============================================================
# RESTORE ORIGINAL TREES
# ============================================================

func _restore_source_trees() -> void:
	if not Engine.is_editor_hint():
		return

	var forest_parent: Node = get_parent()

	if forest_parent == null:
		return

	var restored_count: int = 0

	for child: Node in forest_parent.get_children():
		if child == self:
			continue

		var source_tree: Node3D = child as Node3D

		if source_tree == null:
			continue

		if not str(source_tree.name).begins_with(
			source_name_prefix
		):
			continue

		source_tree.visible = true
		restored_count += 1

	visible = false

	print(
		"ForestMultiMeshBaker: Restored ",
		restored_count,
		" original trees."
	)


# ============================================================
# MESH SEARCH
# ============================================================

func _find_first_mesh_instance(
	node: Node
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = (
		node as MeshInstance3D
	)

	if mesh_instance != null:
		return mesh_instance

	for child: Node in node.get_children():
		var result: MeshInstance3D = (
			_find_first_mesh_instance(child)
		)

		if result != null:
			return result

	return null
