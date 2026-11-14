@tool
extends Node3D
class_name UnfinishedHouseShell

## The unfinished house's shell as a model (`unfinished_house.glb`: one mesh with the floor, the outer walls with their door and window frames, the ceiling
## and the tiled roof), standing where the code-built shell (`UnfinishedHouseBuilder`) stands. The builder keeps the collision, the partition walls and the
## doors' positions; this node only supplies the picture of the floor, the outer walls and the roof.
##
## The model was made for the same plan, turned half way round (its two-opening wall is the builder's front wall) and a little narrower, so it is fitted to the
## builder's rooms: turned 180 degrees about Y and stretched in X and Z until the INSIDE faces of its outer walls lie on the inside faces of the builder's outer
## walls (the rooms keep their size; the walls are a little thicker than the builder's, and outside the builder's collision, which nobody can see). The exterior
## doors of the model fall within a few centimetres of the builder's door openings.
##
## The model has two partitions of its own (kitchen and bedroom against the hallway, hallway against the living room, with their arches and the bedroom's door
## frame): they are kept, and `build_collision` makes them solid. What it carries that the game supplies itself is left out: the closed door leaves (the game's doors
## replace them), and the pantry's door frame and shelving (the model has no pantry walls; those are the game's). The mesh is split into its connected pieces and
## those are dropped (see `_keeps`).
## The model's own file is never touched.

const MODEL: PackedScene = preload("res://assets/models/buildings/unfinished_house/unfinished_house.glb")

## The model's frame: where the INSIDE faces of its outer walls are (x min, x max, z min, z max), and the outer faces of the plaster (the footprint polygon below).
const INNER_X: Vector2 = Vector2(-4.84, 4.68)
const INNER_Z: Vector2 = Vector2(-7.40, 7.44)
## The footprint's outline in the model's frame (outer faces), an L: used to tell the pieces of the shell from loose ones standing inside.
const OUTLINE: Array[Vector2] = [
	Vector2(-3.06, -7.647), Vector2(4.93, -7.647), Vector2(4.93, 7.686), Vector2(-5.099, 7.686), Vector2(-5.099, -1.36), Vector2(-3.06, -1.36),
]
## A loose piece is kept if the middle of its box is this close to the outline.
const KEEP_DISTANCE: float = 0.7
## Walls on the north / south sides of the model (z beyond these): where its door and window frames are.
const WALL_BAND_Z: float = 7.37

## Surface numbers in the model: 0 floor and door leaves, 1 plaster, 2 roof tiles, 3 painted wood, 4 glass.
const SURFACE_FLOOR: int = 0
const SURFACE_WOOD: int = 3

## The windows of the model (middle of the opening on the wall's centre line, in the model's frame) and their size.
const WINDOWS: Array[Vector2] = [Vector2(-2.05, 7.56), Vector2(-1.20, -7.52), Vector2(3.10, -7.52)]
const WINDOW_WIDTH: float = 1.11
const WINDOW_BOTTOM: float = 1.07
const WINDOW_HEIGHT: float = 1.10
## The exterior doors of the model: the middle of the clear opening between the jambs (x, z in the model's frame), its clear width and the underside of its head.
const DOORS: Array[Vector3] = [Vector3(2.823, 7.56, 0.7776), Vector3(0.936, -7.52, 0.7776)]
const DOOR_HEIGHT: float = 2.10
## Surface numbers of the plaster and of the painted wood (the partitions and their casings are dressed in these).
const SURFACE_PLASTER: int = 1
## The model's two partitions in the house's frame (z from, z to): the one between the kitchen and bedroom and the hallway, and the one between the hallway and
## the living room. Their walls, frames and thresholds are kept.
const PARTITION_BANDS: Array[Vector2] = [Vector2(5.95, 6.5), Vector2(8.8, 9.3)]

var model_to_house: Transform3D = Transform3D.IDENTITY
var mesh_instance: MeshInstance3D = null


## Builds the picture, fitted to the builder's inside faces: `inner_min` / `inner_max` are the inside faces of its outer walls (x, z).
func setup(inner_min: Vector2, inner_max: Vector2) -> void:
	var span_x: float = INNER_X.y - INNER_X.x
	var span_z: float = INNER_Z.y - INNER_Z.x
	var scale_x: float = (inner_max.x - inner_min.x) / span_x
	var scale_z: float = (inner_max.y - inner_min.y) / span_z
	# x' = -x (half a turn), then stretched: the inside face at the model's x max goes to the builder's x min.
	var origin: Vector3 = Vector3(inner_min.x + INNER_X.y * scale_x, 0.0, inner_min.y + INNER_Z.y * scale_z)
	model_to_house = Transform3D(Basis.from_scale(Vector3(-scale_x, 1.0, -scale_z)), origin)

	var root: Node3D = MODEL.instantiate() as Node3D
	var source: MeshInstance3D = _find_mesh(root)
	if source == null:
		root.free()
		return

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Model"
	mesh_instance.mesh = _filtered(source.mesh as ArrayMesh) if source.mesh is ArrayMesh else source.mesh
	mesh_instance.transform = model_to_house
	add_child(mesh_instance)
	root.free()


## The model's point (x, y, z) in the house's frame.
func to_house(point: Vector3) -> Vector3:
	return model_to_house * point


## Where the windows of the model are in the house's frame: {"center": Vector3 on the wall's centre line at the opening's middle height, "width": float, "north": bool}.
func window_openings() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for window: Vector2 in WINDOWS:
		var middle: Vector3 = to_house(Vector3(window.x, WINDOW_BOTTOM + WINDOW_HEIGHT * 0.5, window.y))
		# The model's +Z wall is the house's north wall (z = 0).
		found.append({
			"center": middle,
			"width": WINDOW_WIDTH * absf(model_to_house.basis.x.x),
			"height": WINDOW_HEIGHT,
			"north": window.y > 0.0,
		})
	return found


## A body with the model's own shape (its plaster, wood and glass; not the floor or the roof, which the game's boxes give): the walls collide where they are
## drawn, arches and frames included. Made once.
func build_collision() -> StaticBody3D:
	if mesh_instance == null or get_node_or_null("ModelBody") != null:
		return get_node_or_null("ModelBody") as StaticBody3D

	var faces: PackedVector3Array = PackedVector3Array()
	for surface: int in mesh_instance.mesh.get_surface_count():
		if surface == SURFACE_FLOOR or surface == 2:
			continue
		for point: Vector3 in mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			faces.append(model_to_house * point)

	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ModelBody"
	var holder: CollisionShape3D = CollisionShape3D.new()
	holder.name = "CollisionShape3D"
	holder.shape = shape
	body.add_child(holder)
	add_child(body)
	return body


## The exterior doors of the model in the house's frame: {"center": Vector3 (on the floor, the wall's centre line), "width": float, "height": float, "north": bool}.
func door_openings() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for door: Vector3 in DOORS:
		found.append({
			"center": to_house(Vector3(door.x, 0.0, door.y)),
			"width": door.z * absf(model_to_house.basis.x.x),
			"height": DOOR_HEIGHT,
			"north": door.y > 0.0,
		})
	return found


## A copy of one of the model's materials mapped by world position (`uv_scale` repeats per metre), for the boxes that are not part of the model
## (the partitions, their casings, the ceiling), so that they wear the same plaster and wood as the shell. Null if there is no model.
func world_material(surface: int, uv_scale: float) -> StandardMaterial3D:
	if mesh_instance == null or mesh_instance.mesh == null or surface >= mesh_instance.mesh.get_surface_count():
		return null

	var source: StandardMaterial3D = mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
	if source == null:
		return null

	var copy: StandardMaterial3D = source.duplicate() as StandardMaterial3D
	copy.uv1_triplanar = true
	copy.uv1_world_triplanar = true
	copy.uv1_scale = Vector3.ONE * uv_scale
	copy.uv1_offset = Vector3.ZERO
	return copy


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child: Node in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found

	return null


# ============================================================
# DROPPING THE LOOSE PIECES
# ============================================================

func _filtered(source: ArrayMesh) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var kept: Array = _kept_arrays(surface, arrays)
		if kept.is_empty():
			continue

		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, kept)
		result.surface_set_material(result.get_surface_count() - 1, source.surface_get_material(surface))
		result.surface_set_name(result.get_surface_count() - 1, source.surface_get_name(surface))
	return result


## The surface's triangles whose connected piece is part of the shell, as plain (unindexed) arrays; empty if none.
func _kept_arrays(surface: int, arrays: Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var corners: PackedInt32Array = indices
	if corners.is_empty():
		corners = PackedInt32Array()
		corners.resize(vertices.size())
		for i: int in vertices.size():
			corners[i] = i

	# Connected pieces: vertices at the same place are one vertex.
	var parent: Dictionary = {}
	for corner: int in corners:
		var key: Vector3i = _key(vertices[corner])
		if not parent.has(key):
			parent[key] = key
	for t: int in corners.size() / 3:
		var a: Vector3i = _root(parent, _key(vertices[corners[t * 3]]))
		for k: int in [1, 2]:
			var b: Vector3i = _root(parent, _key(vertices[corners[t * 3 + k]]))
			if a != b:
				parent[b] = a

	var boxes: Dictionary = {}
	for corner: int in corners:
		var point: Vector3 = vertices[corner]
		var piece: Vector3i = _root(parent, _key(point))
		if boxes.has(piece):
			boxes[piece] = (boxes[piece] as AABB).expand(point)
		else:
			boxes[piece] = AABB(point, Vector3.ZERO)

	var biggest: AABB = AABB()
	for box: AABB in boxes.values():
		if box.get_volume() + box.size.length() > biggest.get_volume() + biggest.size.length():
			biggest = box

	var kept_triangles: Array[int] = []
	for t: int in corners.size() / 3:
		var piece: Vector3i = _root(parent, _key(vertices[corners[t * 3]]))
		if _keeps(surface, boxes[piece] as AABB, biggest):
			kept_triangles.append(t)
	if kept_triangles.is_empty():
		return []

	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	for slot: int in Mesh.ARRAY_MAX:
		if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
			continue
		var source: Variant = arrays[slot]
		if source is PackedVector3Array:
			var out: PackedVector3Array = PackedVector3Array()
			for t: int in kept_triangles:
				for k: int in 3:
					out.append((source as PackedVector3Array)[corners[t * 3 + k]])
			result[slot] = out
		elif source is PackedVector2Array:
			var out2: PackedVector2Array = PackedVector2Array()
			for t: int in kept_triangles:
				for k: int in 3:
					out2.append((source as PackedVector2Array)[corners[t * 3 + k]])
			result[slot] = out2
		elif source is PackedColorArray:
			var out3: PackedColorArray = PackedColorArray()
			for t: int in kept_triangles:
				for k: int in 3:
					out3.append((source as PackedColorArray)[corners[t * 3 + k]])
			result[slot] = out3
		elif source is PackedFloat32Array and slot == Mesh.ARRAY_TANGENT:
			var out4: PackedFloat32Array = PackedFloat32Array()
			for t: int in kept_triangles:
				for k: int in 3:
					for c: int in 4:
						out4.append((source as PackedFloat32Array)[corners[t * 3 + k] * 4 + c])
			result[slot] = out4
	return result


## Whether a connected piece (its box, in the model's frame) belongs to the shell.
func _keeps(surface: int, box: AABB, biggest: AABB) -> bool:
	if box.size.length() > 0.5 * biggest.size.length() and box.size.length() > 6.0:
		return true

	# The roof is all one piece (or two); anything high up is the roof's or the ceiling's.
	if box.position.y > 2.5:
		return true

	var in_house: AABB = model_to_house * box
	var in_a_partition: bool = false
	for band: Vector2 in PARTITION_BANDS:
		if in_house.position.z >= band.x and in_house.end.z <= band.y:
			in_a_partition = true

	if surface == SURFACE_FLOOR:
		# The floor is the big piece; the rest of this surface is the model's door leaves (the game's doors replace them) and the thresholds of the
		# partitions' openings (kept: flat on the floor).
		return in_a_partition and in_house.size.y < 0.05

	if surface == SURFACE_WOOD or surface == 4:
		# Door and window frames of the north and south walls (the model's z beyond the band) and of the partitions; not the pantry's door frame (the model has no
		# pantry wall to hold it: the pantry's walls and door are the game's) nor its shelving (the game has its own).
		return box.position.z >= WALL_BAND_Z or box.end.z <= -WALL_BAND_Z or (in_a_partition and in_house.size.x < 2.0)

	# Plaster: the partitions, and what lies along the outer walls; anything else standing inside is left out.
	var middle: Vector3 = box.get_center()
	return in_a_partition or _distance_to_outline(Vector2(middle.x, middle.z)) <= KEEP_DISTANCE


func _distance_to_outline(point: Vector2) -> float:
	var best: float = INF
	for i: int in OUTLINE.size():
		var a: Vector2 = OUTLINE[i]
		var b: Vector2 = OUTLINE[(i + 1) % OUTLINE.size()]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
		best = minf(best, point.distance_to(closest))
	return best


func _key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0))


func _root(parent: Dictionary, key: Vector3i) -> Vector3i:
	var current: Vector3i = key
	while parent[current] != current:
		parent[current] = parent[parent[current]]
		current = parent[current]
	return current
