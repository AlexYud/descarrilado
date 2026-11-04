extends RefCounted
class_name DoorModel

## The `door_001` door model, cut into the pieces the door needs. The glb is one mesh of three surfaces: the wooden slab, a handle plate and a
## keyhole escutcheon (the last two sit on ONE face of the slab), and a separate `door_001_handle.glb` lever that turns. The glb files are never
## changed: here the slab and the plate are split into two meshes (once, cached), so the DoorController can stretch the slab to its opening and fit
## the plate on both faces (see `DoorHardware`).
##
## Numbers are the model's own, in its file frame (metres): the slab is 0.79 wide along z (the plate near z = +0.30, the thin edge at z = -0.40
## being the hinge side), 2.073 tall along y and 0.073 thick along x, the plate and the lever on the +x face. A door's `Hinge/DoorRoot` has its
## width along x, so the leaf is turned a quarter round about y (file z becomes door x, file +x face becomes the door's -z face).

const DOOR_SCENE: PackedScene = preload("res://assets/models/interactables/doors/door_001/door_001.glb")
const HANDLE_SCENE: PackedScene = preload("res://assets/models/interactables/doors/door_001/door_001_handle.glb")

const WIDTH: float = 0.790
const HEIGHT: float = 2.073
## Half the slab's thickness (file x from -0.037 to 0.036).
const HALF_THICKNESS: float = 0.0365
## The slab's middle along the file z axis (-0.398 to 0.392).
const SLAB_CENTER_Z: float = -0.003
## The plate and the lever's pivot, in the file frame: the pivot sits on the plate's surface, above the slot, at the plate's middle.
const HUB_Y: float = 0.03
const HUB_Z: float = 0.304
const PLATE_SURFACE_X: float = 0.059
## How far the plate stands off the slab's face, and the keyhole escutcheon (a little higher).
const PLATE_HEIGHT: float = PLATE_SURFACE_X - HALF_THICKNESS
const KEYHOLE_TOP: float = 0.063 - HALF_THICKNESS
## Where the key goes in, from the pivot: the middle of the escutcheon's round rim (measured on the mesh: file y -0.0745, file z 0.299).
const KEYHOLE_Y: float = -0.0745 - HUB_Y
## The rim's middle lies this far from the pivot, towards the hinge (the lever's side), across the door.
const KEYHOLE_TOWARDS_HINGE: float = HUB_Z - 0.299

static var _slab: ArrayMesh = null
static var _plate: ArrayMesh = null
static var _plate_mirrored: ArrayMesh = null


## The slab: the model's wooden surface only, in the file frame.
static func slab_mesh() -> ArrayMesh:
	_split()
	return _slab


## The handle plate and the keyhole escutcheon, in the file frame. `mirrored` is the same pieces reflected in the plane through the lever's pivot
## (file z = HUB_Z): the plate of the door's other face, where the hinge is on the other side. It is a mesh of its own, with its vertices, normals and
## tangents reflected and its triangles turned over (a negative scale on the instance rendered it black: its normal mapping broke).
static func plate_mesh(mirrored: bool = false) -> ArrayMesh:
	_split()
	if mirrored:
		if _plate_mirrored == null:
			_plate_mirrored = _mirror(_plate)
		return _plate_mirrored

	return _plate


## Dresses a standard door's leaf: the slab in place of the box (stretched to `width` x `height`), the root moved so that the hinge edge is at the
## hinge, the collision box refitted. Returns where the handle's pivot is in the door root's frame (the hardware goes there, on each face).
static func dress_leaf(door_root: Node3D, leaf: MeshInstance3D, width: float, height: float) -> Vector2:
	var stretch: Vector2 = Vector2(width / WIDTH, height / HEIGHT)
	leaf.mesh = slab_mesh()
	leaf.material_override = null
	# File frame to door frame: file z -> door x, file x -> door -z; then the stretch on x and y; the slab's middle on the door root's origin.
	var turn: Basis = Basis(Vector3.UP, PI * 0.5)
	leaf.transform = Transform3D(
		Basis.from_scale(Vector3(stretch.x, stretch.y, 1.0)) * turn,
		Vector3(-SLAB_CENTER_Z * stretch.x, 0.0, 0.0)
	)
	door_root.position = Vector3(width * 0.5, height * 0.5, 0.0)

	for shape_node: Node in door_root.find_children("*", "CollisionShape3D", true, false):
		var holder: Node = shape_node.get_parent()
		if holder is StaticBody3D and holder.get_parent() == door_root:
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(width, height, HALF_THICKNESS * 2.0)
			(shape_node as CollisionShape3D).shape = box
	return Vector2((HUB_Z - SLAB_CENTER_Z) * stretch.x, HUB_Y * stretch.y)


## The handle lever for a face: `face_side` +1 is the door's front (+z), -1 its back. In the hardware's own frame (z out of the face, the lever
## pointing at the hinge: along -x on the front, +x on the back) with its pivot at the origin.
static func face_basis(face_side: int, flip_y: bool) -> Basis:
	# Back face (hardware turned half a round): file x -> out (z), file y -> y, file z -> -x. A proper rotation.
	# Front face: the mirror of that, file z -> +x. The plate is a mirrored mesh (`plate_mesh(true)`) under the back face's rotation; the lever,
	# which is the same above and below, is turned over instead (file y -> -y), which is a proper rotation.
	if face_side < 0:
		return Basis(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.0, 0.0))

	var y_sign: float = -1.0 if flip_y else 1.0
	return Basis(Vector3(0.0, 0.0, 1.0), Vector3(0.0, y_sign, 0.0), Vector3(1.0, 0.0, 0.0))


static func _mirror(source: ArrayMesh) -> ArrayMesh:
	var mirrored: ArrayMesh = ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i: int in vertices.size():
			vertices[i].z = 2.0 * HUB_Z - vertices[i].z

		arrays[Mesh.ARRAY_VERTEX] = vertices
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i: int in normals.size():
				normals[i].z = -normals[i].z

			arrays[Mesh.ARRAY_NORMAL] = normals

		if arrays[Mesh.ARRAY_TANGENT] != null:
			# (x, y, z, w) per vertex: the reflected tangent, and the handedness turned over.
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for i: int in tangents.size() / 4:
				tangents[i * 4 + 2] = -tangents[i * 4 + 2]
				tangents[i * 4 + 3] = -tangents[i * 4 + 3]

			arrays[Mesh.ARRAY_TANGENT] = tangents

		if arrays[Mesh.ARRAY_INDEX] != null:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i: int in indices.size() / 3:
				var second: int = indices[i * 3 + 1]
				indices[i * 3 + 1] = indices[i * 3 + 2]
				indices[i * 3 + 2] = second

			arrays[Mesh.ARRAY_INDEX] = indices

		mirrored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mirrored.surface_set_material(surface, source.surface_get_material(surface))

	return mirrored


static func _split() -> void:
	if _slab != null:
		return

	_slab = ArrayMesh.new()
	_plate = ArrayMesh.new()
	var inst: Node = DOOR_SCENE.instantiate()
	var source: Mesh = null
	for node: Node in inst.find_children("*", "MeshInstance3D", true, false):
		source = (node as MeshInstance3D).mesh
		break
	if source != null:
		for surface: int in source.get_surface_count():
			var material: Material = source.surface_get_material(surface)
			var target: ArrayMesh = _slab if material != null and material.resource_name == "door" else _plate
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
			target.surface_set_material(target.get_surface_count() - 1, material)
	inst.free()
