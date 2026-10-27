extends Interactable
class_name TimeCapsule

## The time capsule on the crate in the living room: a small chest shut with an iron latch. It rattles ("Locked") until the
## story unlocks it (`story_unlocked`, set by the house once the bedroom scene is over; no key is needed), or until the player
## holds the inventory item `required_key_id` if one is set. Then "[E] Unlock" turns the latch, which swings out, the lid
## opens, and the contents are within reach for good.
##
## The capsule needs a child `Model` holding `LidPivot` and `Latch` (see HouseProps `time_capsule`), and may have a child
## `Contents` node and an `InteractArea`. Contents stay out of the scene tree, and so out of reach, until the capsule is
## open; the area is switched off then, so that it never hides the contents from the player's aim.

## The lid is open for good and the contents are within reach.
signal opened

const STATE_SECTION: StringName = &"puzzles"

@export var persistent_id: StringName = &"time_capsule"
## An inventory item that opens it as well; empty (the house's capsule), only the story unlocks it.
@export var required_key_id: String = ""
@export var locked_prompt_text: String = "PROMPT_LOCKED"
@export var unlock_prompt_text: String = "PROMPT_UNLOCK"
@export var lid_open_degrees: float = 110.0
## How far the lid pops up when the latch is thrown.
@export var lid_ajar_degrees: float = 7.0
@export var latch_open_degrees: float = 75.0

## Unlocked by the story, for good until the next load (the house sets it again).
var story_unlocked: bool = false
var is_unlatched: bool = false
var is_open: bool = false

var _lid: Node3D = null
var _latch: Node3D = null
var _contents: Node3D = null
var _sound: AudioStreamPlayer3D = null
var _opening: bool = false


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
		_disable_area()
	elif _contents != null:
		remove_child(_contents)


func _exit_tree() -> void:
	# Contents that never entered the tree again would leak.
	if is_instance_valid(_contents) and _contents.get_parent() == null:
		_contents.free()
		_contents = null


func can_interact(_player: Node) -> bool:
	return not is_open and not _opening


func get_prompt_text() -> String:
	return unlock_prompt_text if _can_unlock(_get_player()) else locked_prompt_text


func interact(player: Node) -> void:
	if not can_interact(player):
		return

	if not _can_unlock(player):
		# A normal locked response: the lid is tried and holds.
		_play(PlaceholderAudio.make_locked_rattle(), -10.0, 1.25)
		return

	_opening = true
	if not story_unlocked:
		player.call("consume_inventory_item", required_key_id)
	_play(PlaceholderAudio.make_key_turn(0.5), -6.0, 1.4)
	await get_tree().create_timer(0.55, false).timeout
	unlatch(true)
	await get_tree().create_timer(0.45, false).timeout
	open_lid(true)
	_opening = false


## The iron latch is thrown with a clack and the lid pops up a crack. The contents stay out of reach.
func unlatch(animated: bool = true) -> void:
	if is_unlatched or is_open:
		return

	is_unlatched = true
	if animated:
		_play(PlaceholderAudio.make_iron_clack(), -2.0)

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
	_disable_area()

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


## The open capsule's area would sit over the contents and catch the player's aim: it is switched off.
func _disable_area() -> void:
	var area: Node = get_node_or_null(^"InteractArea")
	if area == null:
		return

	for shape: Node in area.get_children():
		if shape is CollisionShape3D:
			(shape as CollisionShape3D).set_deferred("disabled", true)


func _can_unlock(player: Node) -> bool:
	return story_unlocked or _player_has_key(player)


func _player_has_key(player: Node) -> bool:
	return (
		player != null
		and not required_key_id.is_empty()
		and player.has_method("has_inventory_item")
		and bool(player.call("has_inventory_item", required_key_id))
	)


func _get_player() -> Node:
	return get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null


func _play(stream: AudioStream, volume_db: float, pitch: float = 1.0) -> void:
	if _sound == null:
		return

	_sound.stream = stream
	_sound.volume_db = volume_db
	_sound.pitch_scale = pitch
	_sound.play()
