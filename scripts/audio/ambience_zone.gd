extends Node3D
class_name AmbienceZone

## An interior for the outdoor ambience (`OutdoorAmbience`): a box (centred on this node, in its frame) inside which the world outside
## is heard through walls, muffled. `interior` is how much: 1 is a closed room (the wagon), less is a place open to the outside
## (glassless windows, a missing door, a roof breach). Over the last `edge` metres inside the box the amount fades in, so walking
## through a doorway crossfades the way a portal does instead of switching at the threshold. The floor and ceiling have no edge.
##
## Put one as a child of the building, so that it moves and turns with it.

const GROUP: StringName = &"ambience_zones"

@export var size: Vector3 = Vector3(4.0, 3.0, 4.0)
@export_range(0.0, 1.0, 0.05) var interior: float = 1.0
@export var edge: float = 0.5


func _enter_tree() -> void:
	add_to_group(GROUP)


## Whether `point` (world space) is in the box, grown by `margin` on every side (to take in the walls round it).
func contains(point: Vector3, margin: float = 0.0) -> bool:
	var local: Vector3 = global_transform.affine_inverse() * point
	var half: Vector3 = size * 0.5 + Vector3(margin, margin, margin)
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## How strongly a listener at `point` (world space) is inside: 0 outside the box, up to `interior` inside it. (`OutdoorAmbience` then
## weighs it by how enclosed that spot is: close to a window or an open door, the outside is all but heard in full.)
func amount_at(point: Vector3) -> float:
	var local: Vector3 = global_transform.affine_inverse() * point
	var half: Vector3 = size * 0.5
	if absf(local.y) > half.y:
		return 0.0

	var inside: float = minf(half.x - absf(local.x), half.z - absf(local.z))
	if inside <= 0.0:
		return 0.0

	if edge <= 0.0:
		return interior

	return interior * smoothstep(0.0, edge, inside)
