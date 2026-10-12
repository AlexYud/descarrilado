extends RefCounted

## Copies an earlier version of the dream intro terrain back into one area: the
## heights, the painted ground and the vegetation inside the rectangle. Used to
## undo the unfinished house's pad, trails and regrown forest when the house moved.
##
## The earlier version is a folder of Terrain3D region files, for example taken
## from git (`git show <commit>:terrain_data/dream_intro/<file>`) into
## res://.godot/old_terrain. Everything outside the rectangle is left alone.

## Returns {"cells": int, "removed": int, "restored": int}.
func restore(terrain: Terrain3D, old_directory: String, area: Rect2) -> Dictionary:
	var old_terrain: Terrain3D = Terrain3D.new()
	old_terrain.data_directory = old_directory
	terrain.get_parent().add_child(old_terrain)
	# The data loads when the node enters the tree.
	await terrain.get_tree().process_frame
	await terrain.get_tree().process_frame

	var data: Terrain3DData = terrain.data
	var old_data: Terrain3DData = old_terrain.data
	var cells: int = 0

	for z: int in range(int(floorf(area.position.y)), int(ceilf(area.end.y)) + 1):
		for x: int in range(int(floorf(area.position.x)), int(ceilf(area.end.x)) + 1):
			var point: Vector3 = Vector3(x, 0.0, z)
			var old_height: float = old_data.get_height(point)
			if is_nan(old_height) or is_nan(data.get_height(point)):
				continue

			data.set_height(point, old_height)
			data.set_control(point, old_data.get_control(point))
			data.set_color(point, old_data.get_color(point))
			cells += 1

	_mark_modified(terrain, area)
	data.calc_height_range(true)
	data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)

	var counts: Dictionary = _restore_plants(terrain, old_data, area)
	old_terrain.get_parent().remove_child(old_terrain)
	old_terrain.free()
	return {"cells": cells, "removed": counts["removed"], "restored": counts["restored"]}


## Replaces the plants inside `area` with the old ones, region by region.
func _restore_plants(terrain: Terrain3D, old_data: Terrain3DData, area: Rect2) -> Dictionary:
	var instancer: Terrain3DInstancer = terrain.get_instancer()
	var region_size: float = float(terrain.region_size) * terrain.vertex_spacing
	var removed: int = 0
	var restored: int = 0

	for region: Terrain3DRegion in terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		if not Rect2(offset, Vector2(region_size, region_size)).intersects(area):
			continue

		var old_region: Terrain3DRegion = old_data.get_regionp(
			Vector3(offset.x + 1.0, 0.0, offset.y + 1.0)
		)
		var old_instances: Dictionary = old_region.get_instances() if old_region != null else {}
		var current: Dictionary = region.get_instances()

		var mesh_ids: Dictionary = {}
		for mesh_id: int in current.keys():
			mesh_ids[mesh_id] = true
		for mesh_id: int in old_instances.keys():
			mesh_ids[mesh_id] = true

		for mesh_id: int in mesh_ids.keys():
			var kept_transforms: Array[Transform3D] = []
			var kept_colors: PackedColorArray = PackedColorArray()
			var gone: int = 0

			# What is there now stays, except inside the area.
			for entry: Array in _entries(current, mesh_id):
				var transform: Transform3D = entry[0]
				var world: Vector2 = Vector2(transform.origin.x + offset.x, transform.origin.z + offset.y)
				if area.has_point(world):
					gone += 1
					continue

				kept_transforms.append(transform)
				kept_colors.append(entry[1])

			# What was there then comes back, inside the area only.
			var back: int = 0
			for entry: Array in _entries(old_instances, mesh_id):
				var transform: Transform3D = entry[0]
				var world: Vector2 = Vector2(transform.origin.x + offset.x, transform.origin.z + offset.y)
				if not area.has_point(world):
					continue

				kept_transforms.append(transform)
				kept_colors.append(entry[1])
				back += 1

			if gone == 0 and back == 0:
				continue

			instancer.clear_by_region(region, mesh_id)
			if not kept_transforms.is_empty():
				instancer.append_region(region, mesh_id, kept_transforms, kept_colors, true)

			removed += gone
			restored += back

	return {"removed": removed, "restored": restored}


## Every plant of one mesh in a region's instance data as [transform, colour].
func _entries(instances: Dictionary, mesh_id: int) -> Array[Array]:
	var result: Array[Array] = []
	if not instances.has(mesh_id):
		return result

	var cells: Dictionary = instances[mesh_id]
	for cell: Variant in cells:
		var cell_transforms: Array = cells[cell][0]
		var cell_colors: PackedColorArray = cells[cell][1]
		for i: int in range(cell_transforms.size()):
			result.append([
				cell_transforms[i] as Transform3D,
				cell_colors[i] if i < cell_colors.size() else Color.WHITE,
			])

	return result


func _mark_modified(terrain: Terrain3D, area: Rect2) -> void:
	var region_size: float = float(terrain.region_size) * terrain.vertex_spacing
	var x: float = area.position.x
	while x <= area.end.x + region_size:
		var z: float = area.position.y
		while z <= area.end.y + region_size:
			var region: Terrain3DRegion = terrain.data.get_regionp(Vector3(x, 0.0, z))
			if region != null:
				region.set_modified(true)

			z += region_size

		x += region_size
