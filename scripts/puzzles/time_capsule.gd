extends Node3D
class_name TimeCapsule

## The time capsule on the crate in the living room. It has no lock and cannot be used: it is closed
## until the house's climax (`UnfinishedHouseSequence`), which first throws its iron latch open
## (`unlatch`, a loud clack, the lid just ajar) and later opens it for good (`open_lid`).
##
## The capsule needs a child `Model` holding `LidPivot` and `Latch` (see HouseProps `time_capsule`), and
## may have a child `Contents` node. Contents stay out of the scene tree, and so out of reach, until the
## capsule is open.

## The lid is open for good and the contents are within reach.
signal opened

const STATE_SECTION: StringName = &"puzzles"

@export var persistent_id: StringName = &"time_capsule"
@export var lid_open_degrees: float = 110.0
## How far the lid pops up when the latch is thrown.
@export var lid_ajar_degrees: float = 7.0
@export var latch_open_degrees: float = 75.0

var is_unlatched: bool = false
var is_open: bool = false

var _lid: Node3D = null
var _latch: Node3D = null
var _contents: Node3D = null
var _sound: AudioStreamPlayer3D = null


func _ready() -> void:
	_lid = get_node_or_null(^"Model/LidPivot") as Node3D
	_latch = get_node_or_null(^"Model/Latch") as Node3D
	_contents = get_node_or_null(^"Contents") as Node3D

	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 5.0
	_sound.max_distance = 40.0
	add_child(_sound)

	is_open = bool(SaveManager.get_state_value(STATE_SECTION, StringName("%s_open" % persistent_id), false))
	if is_open:
		_pose(true)
		_add_contents()
	elif _contents != null:
		remove_child(_contents)


func _exit_tree() -> void:
	# Contents that never entered the tree again would leak.
	if is_instance_valid(_contents) and _contents.get_parent() == null:
		_contents.free()
		_contents = null


## The iron latch is thrown with a loud clack and the lid pops up a crack. The contents stay out of reach.
func unlatch(animated: bool = true) -> void:
	if is_unlatched or is_open:
		return

	is_unlatched = true
	if animated:
		_sound.stream = PlaceholderAudio.make_iron_clack()
		_sound.volume_db = 8.0
		_sound.play()

	var time: float = 0.12 if animated else 0.0
	var tween: Tween = create_tween().set_parallel(true)
	if _latch != null:
		tween.tween_property(_latch, "rotation_degrees:x", latch_open_degrees, time)
	if _lid != null:
		tween.tween_property(_lid, "rotation_degrees:x", -lid_ajar_degrees, time * 1.5).set_delay(time * 0.4)


## The lid is open for good and the contents can be reached. `animated` false shows it already open.
func open_lid(animated: bool = false) -> void:
	if is_open:
		return

	is_open = true
	SaveManager.set_state_value(STATE_SECTION, StringName("%s_open" % persistent_id), true)
	_add_contents()

	if not animated:
		_pose(true)
	else:
		var tween: Tween = create_tween().set_parallel(true)
		if _latch != null:
			tween.tween_property(_latch, "rotation_degrees:x", latch_open_degrees, 0.2)
		if _lid != null:
			tween.tween_property(_lid, "rotation_degrees:x", -lid_open_degrees, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	opened.emit()


func _pose(open: bool) -> void:
	if _latch != null and open:
		_latch.rotation_degrees.x = latch_open_degrees

	if _lid != null and open:
		_lid.rotation_degrees.x = -lid_open_degrees


func _add_contents() -> void:
	if _contents != null and _contents.get_parent() == null:
		add_child(_contents)
