extends Interactable
class_name CombinationLock

## A padlock with number wheels that guards a box. Interacting opens a close-up
## (CombinationLockView) where the player turns the wheels; the right code opens
## the lock for good.
##
## The lock needs a child `Model` holding `LidPivot` and `Padlock` (with
## `Digit0..2` labels), see HouseProps `time_capsule`, and may have a child
## `Contents` node. Contents stay out of the scene tree, and so out of reach,
## until the lock opens. Nothing tells the player a wrong code is close.

signal unlocked
## The close-up opened or closed.
signal opened
signal closed

const STATE_SECTION: StringName = &"puzzles"

## One digit per wheel.
@export var code: Array[int] = [3, 6, 6]
## Unique within the game; the wheels and the open lock are saved under it.
@export var persistent_id: StringName = &"time_capsule"
@export var lid_open_degrees: float = 110.0
@export var lid_open_seconds: float = 1.4
## The wheels settle this long before the lock opens, so the last digit is seen.
@export var unlock_delay_seconds: float = 0.45

var digits: Array[int] = []
var is_unlocked: bool = false
var view: CombinationLockView = null

var _lid: Node3D = null
var _padlock: Node3D = null
var _contents: Node3D = null
var _digit_labels: Array[Label3D] = []
var _sound: AudioStreamPlayer3D = null


func _ready() -> void:
	for i: int in code.size():
		digits.append(0)

	_lid = get_node_or_null(^"Model/LidPivot") as Node3D
	_padlock = get_node_or_null(^"Model/Padlock") as Node3D
	_contents = get_node_or_null(^"Contents") as Node3D

	if _padlock != null:
		for i: int in code.size():
			var label: Label3D = _padlock.get_node_or_null("Digit%d" % i) as Label3D
			if label != null:
				_digit_labels.append(label)

	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 3.0
	_sound.max_distance = 20.0
	add_child(_sound)

	_restore_state()
	_refresh_labels()

	if is_unlocked:
		_pose_unlocked()
	elif _contents != null:
		remove_child(_contents)

	view = CombinationLockView.new()
	add_child(view)
	view.setup(self)


func _exit_tree() -> void:
	# Contents that never entered the tree again would leak.
	if is_instance_valid(_contents) and _contents.get_parent() == null:
		_contents.free()
		_contents = null


func can_interact(_player: Node) -> bool:
	return not is_unlocked


func interact(player: Node) -> void:
	if is_unlocked:
		return

	view.open(player)


## Turns one wheel a step up (+1) or down (-1).
func turn_wheel(index: int, step: int) -> void:
	if is_unlocked or index < 0 or index >= digits.size():
		return

	digits[index] = posmod(digits[index] + step, 10)
	_refresh_labels()
	_save_digits()
	_play(PlaceholderAudio.make_click(), -6.0)

	if _matches_code():
		_unlock_after_delay()


func _matches_code() -> bool:
	for i: int in code.size():
		if digits[i] != code[i]:
			return false

	return true


func _unlock_after_delay() -> void:
	# Locks the wheels at once so a last nudge cannot undo the combination.
	is_unlocked = true
	await get_tree().create_timer(unlock_delay_seconds).timeout
	_open_lock()


func _open_lock() -> void:
	_disable_interaction_area()
	SaveManager.set_state_value(STATE_SECTION, _key("open"), true)
	_play(PlaceholderAudio.make_clunk(), 0.0)

	if _contents != null and _contents.get_parent() == null:
		add_child(_contents)

	var tween: Tween = create_tween().set_parallel(true)
	if _padlock != null:
		tween.tween_property(_padlock, "position:y", _padlock.position.y - 0.05, 0.35)
		tween.tween_property(_padlock, "rotation_degrees:z", 25.0, 0.35)
	if _lid != null:
		tween.tween_property(
			_lid, "rotation_degrees:x", -lid_open_degrees, lid_open_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.3)

	unlocked.emit()


func _pose_unlocked() -> void:
	_disable_interaction_area()
	if _padlock != null:
		_padlock.position.y -= 0.05
		_padlock.rotation_degrees.z = 25.0

	if _lid != null:
		_lid.rotation_degrees.x = -lid_open_degrees

	if _contents != null and _contents.get_parent() == null:
		add_child(_contents)


func _refresh_labels() -> void:
	for i: int in _digit_labels.size():
		_digit_labels[i].text = str(digits[i])


func _play(stream: AudioStream, volume_db: float) -> void:
	if _sound == null:
		return

	_sound.stream = stream
	_sound.volume_db = volume_db
	_sound.play()


# ============================================================
# SAVING
# ============================================================

func _key(suffix: String) -> StringName:
	return StringName("%s_%s" % [persistent_id, suffix])


func _save_digits() -> void:
	SaveManager.set_state_value(STATE_SECTION, _key("digits"), digits.duplicate())


func _restore_state() -> void:
	is_unlocked = bool(SaveManager.get_state_value(STATE_SECTION, _key("open"), false))

	var saved: Variant = SaveManager.get_state_value(STATE_SECTION, _key("digits"), [])
	if not saved is Array:
		return

	var saved_list: Array = saved as Array
	for i: int in mini(saved_list.size(), digits.size()):
		digits[i] = posmod(int(saved_list[i]), 10)


## The open lock must not keep catching the interaction ray: its area sits in front
## of the contents and would hide them from the player's aim.
func _disable_interaction_area() -> void:
	for shape: Node in find_children("*", "CollisionShape3D", false, false):
		(shape as CollisionShape3D).set_deferred("disabled", true)

	var area: Node = get_node_or_null(^"InteractArea")
	if area != null:
		for shape: Node in area.get_children():
			if shape is CollisionShape3D:
				(shape as CollisionShape3D).set_deferred("disabled", true)
