extends Node3D
class_name WoodCabinet

## The tall wooden cabinet of the models (`wood_cabinet_large.glb`: a lower compartment with two openings and a ladder of open shelves over it) with its
## two doors (`wood_cabinet_door.glb`, a model of its own for each leaf) hung in the openings as real `DoorController`s, so that they open and close the
## way the game's doors do: aimed at and used, the leaf swings out on its hinge. The glb files are not changed. Built in the model's own frame, whose
## +X is the front: the node that holds this one turns it to face the room.
##
## Measured on the model (file frame, metres): the lower compartment is open at the front from y 0.16 to 0.69, in two openings 0.36 wide split by a
## stile at z 0 (left z -0.36..0, right z 0.01..0.37), its back is at x -0.274 and its frame's front at x 0.286-0.297; the door is 0.361 wide, 0.52 tall
## and 0.035 thick, its origin in its middle.

const CABINET_SCENE: PackedScene = preload("res://assets/models/furniture/wood_cabinet_large/wood_cabinet_large.glb")
const DOOR_SCENE: PackedScene = preload("res://assets/models/furniture/wood_cabinet_door/wood_cabinet_door.glb")

## Where a door's own origin sits in the opening (its plane, just inside the frame's front) and at what height.
const DOOR_X: float = 0.285
const DOOR_Y: float = 0.425
const DOOR_WIDTH: float = 0.361
## The hinges: on the outer edge of each opening.
const LEFT_HINGE_Z: float = -0.36
const RIGHT_HINGE_Z: float = 0.37
const OPEN_DEGREES: float = 105.0
## The model's box, for the collision.
const BODY_SIZE: Vector3 = Vector3(0.648, 1.861, 0.867)
const BODY_CENTRE: Vector3 = Vector3(0.002, 0.93, 0.0)

## Prefix of the doors' saved names (`<prefix>_left`, `<prefix>_right`); empty: they are not saved.
@export var persistent_prefix: StringName = &""
## Coils stand in the lower compartment (the tower's relay cabinet).
@export var coils: bool = false

var left_door: DoorController = null
var right_door: DoorController = null
var body: StaticBody3D = null


func _ready() -> void:
	if get_child_count() > 0:
		return

	var model: Node3D = CABINET_SCENE.instantiate() as Node3D
	model.name = "Model"
	add_child(model)

	body = HouseProps.add_solid(self, "Solid", BODY_SIZE, BODY_CENTRE)
	if coils:
		_build_coils()

	left_door = _make_door("DoorLeft", LEFT_HINGE_Z, 1.0)
	right_door = _make_door("DoorRight", RIGHT_HINGE_Z, -1.0)


## `leaf_direction` is +1 when the leaf runs from its hinge towards +z (the left door) and -1 towards -z (the right one).
func _make_door(door_name: String, hinge_z: float, leaf_direction: float) -> DoorController:
	var door: DoorController = DoorController.new()
	door.name = door_name
	door.build_hardware = false
	door.animate_player_interaction = false
	door.handle_sound_enabled = false
	door.one_way = true
	door.open_angle_degrees = OPEN_DEGREES
	door.rotate_speed = 5.0
	# Positive turns swing the leaf towards the door's -Z side, which is the front for the left door (turned to run along +z, facing -X in its own
	# frame); the right door is turned the other way about and swings the other way.
	door.swing_sign = 1 if leaf_direction > 0.0 else -1
	if not persistent_prefix.is_empty():
		door.persistent_id = StringName("%s_%s" % [persistent_prefix, "left" if leaf_direction > 0.0 else "right"])

	door.position = Vector3(DOOR_X, DOOR_Y, hinge_z)
	door.rotation = Vector3(0.0, -PI * 0.5 if leaf_direction > 0.0 else PI * 0.5, 0.0)

	var hinge: Node3D = Node3D.new()
	hinge.name = "Hinge"
	door.add_child(hinge)
	var leaf: Node3D = Node3D.new()
	leaf.name = "DoorRoot"
	leaf.position = Vector3(DOOR_WIDTH * 0.5, 0.0, 0.0)
	hinge.add_child(leaf)

	# The door model: its width runs along its z, its outside is its +x (the pull): turned so that the width runs along the leaf and the outside faces
	# the front.
	var model: Node3D = DOOR_SCENE.instantiate() as Node3D
	model.name = "Model"
	model.rotation = Vector3(0.0, PI * 0.5 if leaf_direction > 0.0 else -PI * 0.5, 0.0)
	leaf.add_child(model)

	# What the player aims at: the leaf's front (the knob finds the controller above it).
	var knob: DoorKnobInteractable = DoorKnobInteractable.new()
	knob.name = "KnobInteractable"
	var front: float = -1.0 if leaf_direction > 0.0 else 1.0
	knob.position = Vector3(0.0, 0.0, front * 0.05)
	leaf.add_child(knob)
	var area: Area3D = Area3D.new()
	area.name = "InteractArea"
	knob.add_child(area)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.34, 0.5, 0.14)
	shape.shape = box
	area.add_child(shape)

	add_child(door)
	return door


## A few coils of copper wire standing on the lower compartment's floor (the cabinet held relays).
func _build_coils() -> void:
	var copper: StandardMaterial3D = HouseProps.material(Color(0.5, 0.26, 0.12), 0.45, 0.8)
	var iron: StandardMaterial3D = HouseProps.material(Color(0.16, 0.16, 0.17), 0.6, 0.7)
	for row: int in 2:
		for column: int in 3:
			var z: float = (-0.27 + 0.09 * float(column)) if row == 0 else (0.1 + 0.09 * float(column))
			var spot: Vector3 = Vector3(0.0 - 0.08 * float(row), 0.16, z)
			HouseProps.add_cylinder(self, "Coil%d_%d" % [row, column], 0.036, 0.16, spot + Vector3(0.0, 0.1, 0.0), copper)
			HouseProps.add_cylinder(self, "Core%d_%d" % [row, column], 0.012, 0.2, spot + Vector3(0.0, 0.1, 0.0), iron)
