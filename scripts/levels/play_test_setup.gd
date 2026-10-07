extends Node3D
class_name PlayTestSetup

## Put in a standalone test scene next to a Player. The player scene starts in
## the dream intro's lying-down pose, tilted a few degrees; the intro plays the
## head-raise to finish upright. Nothing does that in a test scene, so this
## brings the view upright the same way a finished cutscene does.

@export var player: Node


func _ready() -> void:
	_stand_up.call_deferred()


func _stand_up() -> void:
	if player == null or not player.has_method("set_cutscene_frozen"):
		return

	player.call("set_cutscene_frozen", true)
	player.call("set_cutscene_frozen", false)
