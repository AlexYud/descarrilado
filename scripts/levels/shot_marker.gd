@tool
extends Marker3D
class_name ShotMarker

## Where one shot of a scene stands, and what it looks at: a position, a point to aim at (`target`) and a lens (`fov`, the vertical
## field of view in degrees). A scene's script reads them to place its own camera; the marker itself draws nothing and costs nothing.
## Move a marker and its target in the editor to reframe a shot.

@export var fov: float = 45.0
@export var target: Node3D


## The transform the shot's camera has: at the marker, turned to look at the target (the marker's own turn if it has none).
func aimed_transform() -> Transform3D:
	var at: Transform3D = global_transform
	if target != null and target.is_inside_tree() and is_inside_tree():
		at = at.looking_at(target.global_position, Vector3.UP)
	return at
