extends Interactable
class_name JSLockbox

## The "J & S" lockbox on the camp's log table: a steel strongbox Juliana and Sophia painted their initials on, shut with a four wheel
## combination dial in its front. The right code, 1 4 0 8 (the date they took over the HQ, 14 August: it is stamped in red ink on the old
## bus ticket in the jacket on the clothesline), lets the latch go with a heavy CLACK-CLICK and the lid pops open, showing what Sophia hid
## in it: the signal tower's brass key and the photograph "Rain at the Station" (`Contents`: two ordinary Collectibles, out of the scene
## tree, and so out of reach and sight, until the lid opens).
##
## Interacting opens a close-up (`JSLockboxView`): the view flies to the front panel and the player turns each wheel on its own with the
## arrows or the mouse wheel, each step a heavy metallic TICK TICK. There is no button to confirm: the code is judged as the last wheel
## settles (like the time capsule's lock), and the wheels are held from then on so that a last nudge cannot undo it. Nothing tells the
## player a wrong code is close.
##
## The model is `Model` (ProceduralProp kind `js_lockbox`, see FigClearingProps): `Wheels/Wheel0..3` (a thumb wheel each, ten digits round
## its rim, turned about X: the digit that faces the close-up camera is the value), `LidPivot`, `Latch` and `CloseUp` (where the close-up view's camera
## goes). The opened lockbox is saved (`puzzles/js_lockbox_open`) and so are the wheels' digits.
##
## Which digit counts has to be plain: the camera looks down on the dial, so the wheels are turned `reading_degrees` further than straight ahead,
## which puts the digit that counts in the middle of its wheel as it is seen (it used to be seen low, between two others, and the player set the
## wrong one), and the digits next to it are dimmed more the further they are from it, so that the wheel reads at a glance. The close-up view
## frames that row as well (`JSLockboxView`).

signal digit_changed(index: int, value: int)
signal unlocked
## The close-up opened or closed.
@warning_ignore("unused_signal")
signal opened
@warning_ignore("unused_signal")
signal closed

const STATE_SECTION: StringName = &"puzzles"
## How far a wheel turns for one digit.
const DEGREES_PER_DIGIT: float = 36.0
## How bright a digit is, by its distance in degrees round the wheel from the one that counts: full at the reading line, `DIGIT_DIM` of it from
## `DIM_FROM_DEGREES` on.
const DIGIT_DIM: float = 0.35
const DIM_FROM_DEGREES: float = 40.0

## One digit per wheel.
@export var code: Array[int] = [1, 4, 0, 8]
## Unique within the game; the wheels and the open box are saved under it.
@export var persistent_id: StringName = &"js_lockbox"
@export var key_scene: PackedScene
@export var photo_scene: PackedScene
@export var wheel_turn_seconds: float = 0.14
## The wheels settle this long before the latch lets go, so the last tick is heard first.
@export var unlock_delay_seconds: float = 0.5
@export var latch_swing_seconds: float = 0.14
@export var lid_open_degrees: float = 112.0
@export var lid_open_seconds: float = 0.95

var digits: Array[int] = []
var is_unlocked: bool = false
var view: JSLockboxView = null
## Degrees above straight ahead at which the digit that counts is read (see the top of the file).
var reading_degrees: float = 0.0

var _wheels: Array[Node3D] = []
## How many digits each wheel has been turned by since the start (not wrapped), so that it always turns the way it was pushed.
var _wheel_steps: Array[int] = []
var _lid: Node3D = null
var _latch: Node3D = null
var _contents: Node3D = null
var _sound: AudioStreamPlayer3D = null
var _close_up: Marker3D = null
## The ten digit labels of each wheel, and the colour they have at full brightness.
var _digit_labels: Array = []
var _digit_base: Color = Color(0.95, 0.9, 0.72)
## How much longer the digits' brightness is kept up to date (a wheel is turning).
var _glow_time: float = 0.0


func _ready() -> void:
	reading_degrees = FigClearingProps.lockbox_reading_degrees()
	for i: int in code.size():
		digits.append(0)
		_wheel_steps.append(0)

	var wheels: Node = get_node_or_null(^"Model/Wheels")
	if wheels != null:
		for i: int in code.size():
			var wheel: Node3D = wheels.get_node_or_null("Wheel%d" % i) as Node3D
			if wheel != null:
				_wheels.append(wheel)
				var labels: Array[Label3D] = []
				for digit: int in 10:
					labels.append(wheel.get_node_or_null("Digit%d" % digit) as Label3D)

				_digit_labels.append(labels)

	if not _digit_labels.is_empty() and (_digit_labels[0] as Array)[0] != null:
		_digit_base = ((_digit_labels[0] as Array)[0] as Label3D).modulate

	_lid = get_node_or_null(^"Model/LidPivot") as Node3D
	_latch = get_node_or_null(^"Model/Latch") as Node3D
	_close_up = get_node_or_null(^"Model/CloseUp") as Marker3D

	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 3.0
	_sound.max_distance = 20.0
	add_child(_sound)

	_make_contents()
	_restore_state()
	_pose_wheels()

	if is_unlocked:
		_pose_open()

	view = JSLockboxView.new()
	add_child(view)
	view.setup(self)
	set_process(false)


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


## Where the close-up view's camera goes (the world transform of the `CloseUp` marker), or the lockbox's own if there is none.
func get_close_up_transform() -> Transform3D:
	return _close_up.global_transform if _close_up != null else global_transform


## Where a wheel is in the world (its axis), for the view to put its arrows at.
func get_wheel_position(index: int) -> Vector3:
	if index < 0 or index >= _wheels.size():
		return global_position

	return _wheels[index].global_position


## The radius of the wheels in metres, to size the arrows by.
func get_wheel_radius() -> float:
	return 0.0185


## Turns one wheel a digit up (+1) or down (-1).
func turn_wheel(index: int, step: int) -> void:
	if is_unlocked or index < 0 or index >= digits.size() or step == 0:
		return

	digits[index] = posmod(digits[index] + step, 10)
	_wheel_steps[index] += step
	_spin_wheel(index)
	_save_digits()
	_play(PlaceholderAudio.make_dial_tick(), -3.0, randf_range(0.94, 1.06))
	digit_changed.emit(index, digits[index])

	if _matches_code():
		_unlock_after_delay()


func _matches_code() -> bool:
	for i: int in code.size():
		if digits[i] != code[i]:
			return false

	return true


func _unlock_after_delay() -> void:
	# Locks the wheels at once so that a last nudge cannot undo the combination.
	is_unlocked = true
	await get_tree().create_timer(unlock_delay_seconds).timeout
	_release()


## The latch lets go (CLACK, CLICK), swings out, and the lid pops up on its hinge with a little spring; the contents are in reach.
func _release() -> void:
	_disable_area()
	SaveManager.set_state_value(STATE_SECTION, _key("open"), true)
	_play(PlaceholderAudio.make_lockbox_latch(), 1.0)

	if _latch != null:
		create_tween().tween_property(_latch, "rotation_degrees:x", 78.0, latch_swing_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.2).timeout
	if _contents != null and _contents.get_parent() == null:
		add_child(_contents)

	if _lid != null:
		create_tween().tween_property(_lid, "rotation_degrees:x", -lid_open_degrees, lid_open_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	unlocked.emit()


## The box as it is when loaded open: latch out, lid up, contents in the box.
func _pose_open() -> void:
	_disable_area()
	if _latch != null:
		_latch.rotation_degrees.x = 78.0

	if _lid != null:
		_lid.rotation_degrees.x = -lid_open_degrees

	if _contents != null and _contents.get_parent() == null:
		add_child(_contents)


## The key and the photograph, lying on the padding inside the box (in the lockbox's frame). They are not in the scene yet.
func _make_contents() -> void:
	_contents = Node3D.new()
	_contents.name = "Contents"

	if photo_scene != null:
		var photo: Node3D = photo_scene.instantiate() as Node3D
		photo.name = "Photo"
		photo.transform = Transform3D(
			Basis(Vector3.UP, deg_to_rad(-9.0)) * Basis(Vector3.RIGHT, -PI * 0.5), FigClearingProps.LOCKBOX_PHOTO_AT
		)
		_contents.add_child(photo)

	if key_scene != null:
		var key: Node3D = key_scene.instantiate() as Node3D
		key.name = "Key"
		key.transform = Transform3D(
			Basis(Vector3.UP, PI * 0.5 + deg_to_rad(18.0)) * Basis(Vector3.RIGHT, -PI * 0.5), FigClearingProps.LOCKBOX_KEY_AT
		)
		_contents.add_child(key)


## Puts each wheel at its digit.
func _pose_wheels() -> void:
	for i: int in _wheels.size():
		_wheels[i].rotation_degrees.x = _wheel_angle(i)

	_update_digit_glow()


## The angle a wheel is turned to for its digit: the digit that counts is read `reading_degrees` above straight ahead.
func _wheel_angle(index: int) -> float:
	return float(_wheel_steps[index]) * DEGREES_PER_DIGIT - reading_degrees


func _spin_wheel(index: int) -> void:
	if index >= _wheels.size():
		return

	create_tween().tween_property(
		_wheels[index], "rotation_degrees:x", _wheel_angle(index), wheel_turn_seconds
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_glow_time = wheel_turn_seconds + 0.15
	set_process(true)


func _process(delta: float) -> void:
	_glow_time -= delta
	_update_digit_glow()
	if _glow_time <= 0.0:
		set_process(false)


## Dims every digit by how far it is, round its wheel, from the reading line (the one that counts is full).
func _update_digit_glow() -> void:
	for i: int in _wheels.size():
		var turned: float = _wheels[i].rotation_degrees.x
		var labels: Array = _digit_labels[i] as Array
		for digit: int in labels.size():
			var label: Label3D = labels[digit] as Label3D
			if label == null:
				continue

			var from_line: float = absf(wrapf(DEGREES_PER_DIGIT * float(digit) - turned - reading_degrees, -180.0, 180.0))
			var brightness: float = lerpf(1.0, DIGIT_DIM, smoothstep(2.0, DIM_FROM_DEGREES, from_line))
			label.modulate = Color(_digit_base.r * brightness, _digit_base.g * brightness, _digit_base.b * brightness, _digit_base.a)


func _play(stream: AudioStream, volume_db: float, pitch: float = 1.0) -> void:
	if _sound == null:
		return

	_sound.stream = stream
	_sound.volume_db = volume_db
	_sound.pitch_scale = pitch
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
	if saved is Array:
		var saved_list: Array = saved as Array
		for i: int in mini(saved_list.size(), digits.size()):
			digits[i] = posmod(int(saved_list[i]), 10)
			_wheel_steps[i] = digits[i]

	# An open box shows its code.
	if is_unlocked:
		for i: int in mini(code.size(), digits.size()):
			digits[i] = code[i]
			_wheel_steps[i] = code[i]


## The open box must not keep catching the interaction ray: its area sits over the contents and would hide them from the player's aim.
func _disable_area() -> void:
	var area: Node = get_node_or_null(^"InteractArea")
	if area != null:
		for shape: Node in area.get_children():
			if shape is CollisionShape3D:
				(shape as CollisionShape3D).set_deferred("disabled", true)
