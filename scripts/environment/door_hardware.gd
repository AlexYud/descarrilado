extends Node3D
class_name DoorHardware

## The handle and the keyhole fitted to one face of a door, from the `door_001` models (see `DoorModel`): the handle plate with its keyhole
## escutcheon, and the lever, a separate model that turns on its pivot. The DoorController drives it. The node sits on the door's surface, under
## the lever's pivot, and its local +z points out of the face, so the same pieces serve both sides of a door (the back one is turned half a
## round). The glb has the plate on one face only; the other face gets the same pieces mirrored.

const KEY_SCENE: PackedScene = preload("res://assets/models/interactables/miscellaneous/key/key.glb")

## How far the handle is pressed down when fully turned.
const LEVER_TURN_DEGREES: float = 38.0
## The key model is a flat 6.6 cm blank; this makes it a believable door key.
const KEY_SCALE: float = 0.95
const KEY_THICKNESS_SCALE: float = 2.5
## The key's origin height above the keyhole when it is out and when it is in.
const KEY_Z_OUT: float = 0.087
const KEY_Z_IN: float = 0.008
## The keyhole below the lever's pivot, and the escutcheon's surface above the door face.
const KEYHOLE_Y: float = DoorModel.KEYHOLE_Y
const PLATE_SURFACE_Z: float = DoorModel.KEYHOLE_TOP

## +1 for the front face, -1 for the back one.
var face_side: int = 1

var _lever: Node3D = null
var _key_slot: Node3D = null
var _key_turn: Node3D = null


func setup(side: int, _brass: Material = null) -> void:
	face_side = side
	_build_plate()
	_build_lever()
	_build_keyslot()


## 0 is the handle at rest, 1 is pressed all the way down.
func set_lever_turn(amount: float) -> void:
	if _lever == null:
		return

	# The handle points towards the hinge on both faces; turning it down is a
	# turn one way on the front and the other way on the back.
	_lever.rotation.z = deg_to_rad(LEVER_TURN_DEGREES) * amount * float(face_side)


func is_key_shown() -> bool:
	return _key_turn != null and _key_turn.visible


func show_key(shown: bool) -> void:
	if shown:
		_ensure_key()

	if _key_turn != null:
		_key_turn.visible = shown


## `insert` is 0 with the key held just outside the keyhole and 1 with the blade all
## the way in; `twist_degrees` turns it in the lock (negative is clockwise).
func set_key_state(insert: float, twist_degrees: float) -> void:
	_ensure_key()
	_key_turn.position = Vector3(0.0, 0.0, lerpf(KEY_Z_OUT, KEY_Z_IN, insert))
	_key_turn.rotation = Vector3(0.0, 0.0, deg_to_rad(twist_degrees))


## Puts the key at `amount` of the way from `from_global` (where the hand holds it)
## to just outside the keyhole.
func set_key_flight(amount: float, from_global: Vector3) -> void:
	_ensure_key()
	var target: Vector3 = _key_slot.to_global(Vector3(0.0, 0.0, KEY_Z_OUT))
	var eased: float = 1.0 - pow(1.0 - clampf(amount, 0.0, 1.0), 2.0)
	var arc: float = sin(eased * PI) * 0.05
	_key_turn.global_position = from_global.lerp(target, eased) + Vector3(0.0, arc, 0.0)
	_key_turn.rotation = Vector3(
		deg_to_rad(28.0) * (1.0 - eased),
		deg_to_rad(-35.0) * (1.0 - eased),
		deg_to_rad(-20.0) * (1.0 - eased)
	)


func get_key_slot_global() -> Vector3:
	if _key_slot == null:
		return global_position

	return _key_slot.global_position


func get_handle_global() -> Vector3:
	if _lever == null:
		return global_position

	return _lever.global_position


## The plate and the escutcheon, from the model's second and third surfaces, in this face's frame (the front's is a mirrored mesh).
func _build_plate() -> void:
	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = DoorModel.plate_mesh(face_side > 0)
	var basis: Basis = DoorModel.face_basis(-1, false)
	var origin_in_file: Vector3 = Vector3(DoorModel.HALF_THICKNESS, DoorModel.HUB_Y, DoorModel.HUB_Z)
	plate.transform = Transform3D(basis, -(basis * origin_in_file))
	add_child(plate)


## The lever: the handle model on a pivot at the plate's surface, the arm towards the hinge.
func _build_lever() -> void:
	_lever = Node3D.new()
	_lever.name = "Lever"
	_lever.position = Vector3(0.0, 0.0, DoorModel.PLATE_HEIGHT)
	add_child(_lever)

	var model: Node3D = DoorModel.HANDLE_SCENE.instantiate() as Node3D
	model.name = "Handle"
	model.basis = DoorModel.face_basis(face_side, true)
	_lever.add_child(model)


func _build_keyslot() -> void:
	_key_slot = Node3D.new()
	_key_slot.name = "KeySlot"
	# The keyhole is a little towards the hinge from the pivot: along -x on the front face (the lever points that way), +x on the back one.
	_key_slot.position = Vector3(-float(face_side) * DoorModel.KEYHOLE_TOWARDS_HINGE, KEYHOLE_Y, PLATE_SURFACE_Z)
	add_child(_key_slot)


func _ensure_key() -> void:
	if _key_turn != null:
		return

	_key_turn = Node3D.new()
	_key_turn.name = "KeyTurn"
	_key_turn.visible = false
	_key_slot.add_child(_key_turn)

	var model: Node3D = KEY_SCENE.instantiate() as Node3D
	model.name = "Key"
	# The blank lies flat with its length along y. Stand it on its end, bow outwards,
	# blade upright, so it goes into the keyhole point first.
	var stand: Basis = Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
	model.basis = stand * Basis.from_scale(
		Vector3(KEY_SCALE, KEY_SCALE, KEY_SCALE * KEY_THICKNESS_SCALE)
	)
	_key_turn.add_child(model)

	var rust: StandardMaterial3D = StandardMaterial3D.new()
	rust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rust.albedo_color = Color(0.42, 0.2, 0.07, 0.62)
	rust.roughness = 1.0
	for mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = rust

	_key_turn.position = Vector3(0.0, 0.0, KEY_Z_OUT)
