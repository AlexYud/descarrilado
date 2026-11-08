extends Inspectable
class_name GatedInspectable

## An inspectable that can be switched off: while it is, it offers nothing (no prompt, no interaction mark, no ray target), whatever lies over it or
## however visible it is. Foliage and papers have no collision of their own, so "covered" has to be a state of the item itself: the scene that owns it
## (the waiting shed's investigation) turns it on when the cover is gone.

@export var interaction_enabled: bool = true


func can_interact(player: Node) -> bool:
	return interaction_enabled and super(player)


## Turns the interaction on or off: the prompt and the marks (`can_interact`) and the shape the interaction ray can hit.
func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	var shape: CollisionShape3D = get_node_or_null(^"InteractArea/CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.set_deferred("disabled", not enabled)
