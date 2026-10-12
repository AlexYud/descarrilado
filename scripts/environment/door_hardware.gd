extends Node3D
class_name DoorHardware

## The handle and the keyhole fitted to one face of a door, built in code like the
## other props: a rose with a lever handle that turns, and an escutcheon with a
## keyhole where a key can be shown, slid in and turned. The DoorController drives
## it. The node sits on the door's surface and its local +z points out of the face,
## so the same pieces serve both sides of a door (the back one is turned half a
## round).

const KEY_SCENE: PackedScene = preload("res://assets/models/interactables/miscellaneous/key.glb")

## How far the handle is pressed down when fully turned.
const LEVER_TURN_DEGREES: float = 38.0
## The key model is a flat 6.6 cm blank; this makes it a believable door key.
const KEY_SCALE: float = 1.25
const KEY_THICKNESS_SCALE: float = 2.5
## The key's origin height above the door face when it is out and when it is in.
const KEY_Z_OUT: float = 0.1
const KEY_Z_IN: float = 0.021
const KEYHOLE_Y: float = -0.103
const PLATE_SURFACE_Z: float = 0.006

## +1 for the front face, -1 for the back one.
var face_side: int = 1

var _lever: Node3D = null
var _key_slot: Node3D = null
var _key_turn: Node3D = null


func setup(side: int, brass: Material) -> void:
	face_side = side
	_build_rose(brass)
	_build_lever(brass)
	_build_keyhole_plate(brass)


## 0 is the handle at rest, 1 is pressed all the way down.
func set_lever_turn(amount: float) -> void:
	if _lever == null:
		return

	# The handle points towards the hinge on both faces; turning it down is a
	# turn one way on the front and the other way on the back.
	_lever.rotation.z = deg_to_rad(LEVER_TURN_DEGREES) * amount * float(face_side)


func has_key() -> bool:
	return _key_turn != null


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


func _build_rose(brass: Material) -> void:
	_add_cylinder(self, 0.042, 0.008, Vector3(0.0, 0.0, 0.004), brass)
	_add_cylinder(self, 0.009, 0.044, Vector3(0.0, 0.0, 0.03), brass)


func _build_lever(brass: Material) -> void:
	_lever = Node3D.new()
	_lever.name = "Lever"
	_lever.position = Vector3(0.0, 0.0, 0.052)
	add_child(_lever)

	# It points towards the hinge: along local -x on the front face, +x on the back.
	var toward_hinge: float = -float(face_side)

	var hub: MeshInstance3D = MeshInstance3D.new()
	var hub_mesh: SphereMesh = SphereMesh.new()
	hub_mesh.radius = 0.019
	hub_mesh.height = 0.038
	hub.mesh = hub_mesh
	hub.material_override = brass
	_lever.add_child(hub)

	var arm: MeshInstance3D = MeshInstance3D.new()
	var arm_mesh: BoxMesh = BoxMesh.new()
	arm_mesh.size = Vector3(0.13, 0.016, 0.016)
	arm.mesh = arm_mesh
	arm.material_override = brass
	arm.position = Vector3(toward_hinge * 0.065, 0.0, 0.0)
	_lever.add_child(arm)

	var tip: MeshInstance3D = MeshInstance3D.new()
	var tip_mesh: SphereMesh = SphereMesh.new()
	tip_mesh.radius = 0.012
	tip_mesh.height = 0.024
	tip.mesh = tip_mesh
	tip.material_override = brass
	tip.position = Vector3(toward_hinge * 0.13, 0.0, 0.0)
	_lever.add_child(tip)


func _build_keyhole_plate(brass: Material) -> void:
	var plate: MeshInstance3D = MeshInstance3D.new()
	var plate_mesh: BoxMesh = BoxMesh.new()
	plate_mesh.size = Vector3(0.032, 0.07, 0.006)
	plate.mesh = plate_mesh
	plate.material_override = brass
	plate.position = Vector3(0.0, KEYHOLE_Y, 0.003)
	add_child(plate)

	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.01, 0.012)
	dark.roughness = 1.0

	var slot: MeshInstance3D = MeshInstance3D.new()
	var slot_mesh: BoxMesh = BoxMesh.new()
	slot_mesh.size = Vector3(0.0055, 0.022, 0.001)
	slot.mesh = slot_mesh
	slot.material_override = dark
	slot.position = Vector3(0.0, KEYHOLE_Y - 0.008, PLATE_SURFACE_Z + 0.0005)
	add_child(slot)

	_add_cylinder(
		self, 0.0075, 0.001,
		Vector3(0.0, KEYHOLE_Y + 0.008, PLATE_SURFACE_Z + 0.0005), dark
	)

	_key_slot = Node3D.new()
	_key_slot.name = "KeySlot"
	_key_slot.position = Vector3(0.0, KEYHOLE_Y + 0.008, PLATE_SURFACE_Z)
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


## A cylinder lying along the z axis.
func _add_cylinder(
	parent: Node3D, radius: float, length: float, at: Vector3, material: Material
) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 20
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = material
	instance.rotation.x = PI * 0.5
	instance.position = at
	parent.add_child(instance)
