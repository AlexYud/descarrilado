extends Interactable
class_name OpenableContainer

## A closed box (or anything with a lid) that hides something until it is
## opened. Using it swings the lid open and brings out the child `Contents`
## node, which stays out of the scene tree, and so out of reach and out of sight,
## until then. Only what is inside is inspected afterwards, never the box.
##
## The box needs a child `Model` holding `LidPivot` (see JunctionProps
## `switch_box`). Opening is remembered in the save.

signal opened

const STATE_SECTION: StringName = &"puzzles"

## Unique within the game; the open box is saved under it.
@export var persistent_id: StringName = &"container"
@export var lid_open_degrees: float = 105.0
@export var lid_open_seconds: float = 0.9

var is_open: bool = false

var _lid: Node3D = null
var _contents: Node3D = null
var _sound: AudioStreamPlayer3D = null


func _ready() -> void:
	_lid = get_node_or_null(^"Model/LidPivot") as Node3D
	_contents = get_node_or_null(^"Contents") as Node3D

	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 2.0
	_sound.max_distance = 15.0
	add_child(_sound)

	is_open = bool(SaveManager.get_state_value(STATE_SECTION, _key(), false))

	if is_open:
		_disable_interaction_area()
		if _lid != null:
			_lid.rotation_degrees.x = -lid_open_degrees
	elif _contents != null:
		remove_child(_contents)


func _exit_tree() -> void:
	# Contents that never entered the tree again would leak.
	if is_instance_valid(_contents) and _contents.get_parent() == null:
		_contents.free()
		_contents = null


func can_interact(_player: Node) -> bool:
	return not is_open


func interact(_player: Node) -> void:
	if is_open:
		return

	is_open = true
	SaveManager.set_state_value(STATE_SECTION, _key(), true)
	_disable_interaction_area()

	_sound.stream = PlaceholderAudio.make_clunk()
	_sound.volume_db = -6.0
	_sound.play()

	if _contents != null and _contents.get_parent() == null:
		add_child(_contents)

	if _lid != null:
		create_tween().tween_property(
			_lid, "rotation_degrees:x", -lid_open_degrees, lid_open_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	opened.emit()


func _key() -> StringName:
	return StringName("%s_open" % persistent_id)


## The open box must not keep catching the interaction ray: its area sits over the
## contents and would hide them from the player's aim.
func _disable_interaction_area() -> void:
	var area: Node = get_node_or_null(^"InteractArea")
	if area != null:
		for shape: Node in area.get_children():
			if shape is CollisionShape3D:
				(shape as CollisionShape3D).set_deferred("disabled", true)
