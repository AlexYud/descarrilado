extends Node3D
class_name LeverBox

## A signal control box with three levers in the 3D scene. Each lever is a
## SignalLever (an interactable child): looking at one shows "Pull lever 1
## down" or "Push lever 1 up" and using it swings the lever on the box. The
## right combination releases what the box holds and locks the levers for good.
##
## The box needs a child `Model` holding `Lever1..3` (see JunctionProps
## `signal_box`) and may have a child `Contents` node. Contents stay out of the
## scene tree, and so out of reach, until the box opens, then slide out of the
## chute into the tray. Nothing tells the player a wrong combination is close.

signal unlocked

const STATE_SECTION: StringName = &"puzzles"
## A lever points up at rotation 0 and down at this many degrees about Z.
const LEVER_DOWN_DEGREES: float = 180.0
const LEVER_SWING_SECONDS: float = 0.3

## true is UP, false is DOWN; one entry per lever.
@export var solution: Array[bool] = [true, false, true]
## Where the levers start (must differ from the solution).
@export var start_states: Array[bool] = [false, true, false]
## Unique within the game; the levers and the open box are saved under it.
@export var persistent_id: StringName = &"signal_box"
## The last lever settles this long before the box opens, so it is seen.
@export var unlock_delay_seconds: float = 0.7
## Where the contents start (inside the box) and where they land (in the tray),
## in this node's space.
@export var chute_start: Vector3 = Vector3(0.0, 1.2, 0.08)
@export var tray_position: Vector3 = Vector3(0.0, 1.162, 0.2)

var states: Array[bool] = []
var is_unlocked: bool = false

var _pivots: Array[Node3D] = []
var _contents: Node3D = null
var _sound: AudioStreamPlayer3D = null


func _ready() -> void:
	states = start_states.duplicate()

	for i: int in solution.size():
		var pivot: Node3D = get_node_or_null("Model/Lever%d" % (i + 1)) as Node3D
		if pivot != null:
			_pivots.append(pivot)

	_contents = get_node_or_null(^"Contents") as Node3D

	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 4.0
	_sound.max_distance = 30.0
	add_child(_sound)

	_restore_state()
	_pose_levers(false)

	if is_unlocked:
		_disable_levers()
		if _contents != null:
			_contents.position = tray_position
	elif _contents != null:
		remove_child(_contents)


func _exit_tree() -> void:
	# Contents that never entered the tree again would leak.
	if is_instance_valid(_contents) and _contents.get_parent() == null:
		_contents.free()
		_contents = null


## Throws lever `index` (0 based) up (true) or down (false).
func set_lever(index: int, up: bool) -> void:
	if is_unlocked or index < 0 or index >= states.size() or states[index] == up:
		return

	states[index] = up
	_pose_levers(true)
	_save_levers()
	_play(PlaceholderAudio.make_lever(), -3.0)

	if _matches_solution():
		_unlock_after_delay()


## Throws lever `index` the other way.
func toggle_lever(index: int) -> void:
	if index >= 0 and index < states.size():
		set_lever(index, not states[index])


func _matches_solution() -> bool:
	for i: int in solution.size():
		if states[i] != solution[i]:
			return false

	return true


func _unlock_after_delay() -> void:
	# Locks the levers at once so a last nudge cannot undo the combination.
	is_unlocked = true
	await get_tree().create_timer(unlock_delay_seconds).timeout
	_open_box()


func _open_box() -> void:
	_disable_levers()
	SaveManager.set_state_value(STATE_SECTION, _key("open"), true)
	_play(PlaceholderAudio.make_iron_clank(), 2.0)
	unlocked.emit()

	if _contents == null or _contents.get_parent() != null:
		return

	# The chute lets go a moment after the clank, then the contents tumble out.
	await get_tree().create_timer(0.35).timeout
	_contents.position = chute_start
	add_child(_contents)

	var drop: Tween = create_tween()
	drop.tween_property(_contents, "position", tray_position, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_callback(_play.bind(PlaceholderAudio.make_coin_clatter(), -2.0))
	drop.tween_property(_contents, "position:y", tray_position.y + 0.012, 0.07) \
		.set_ease(Tween.EASE_OUT)
	drop.tween_property(_contents, "position:y", tray_position.y, 0.07) \
		.set_ease(Tween.EASE_IN)


## Swings every lever to where `states` says it is (at once when not animated).
func _pose_levers(animated: bool) -> void:
	for i: int in _pivots.size():
		var target: float = 0.0 if states[i] else LEVER_DOWN_DEGREES
		if animated:
			var swing: Tween = create_tween()
			swing.tween_property(_pivots[i], "rotation_degrees:z", target, LEVER_SWING_SECONDS) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_pivots[i].rotation_degrees.z = target


func _play(stream: AudioStream, volume_db: float) -> void:
	if _sound == null:
		return

	_sound.stream = stream
	_sound.volume_db = volume_db
	_sound.play()


## Once solved the levers must not keep catching the interaction ray: their areas
## sit in front of the box and would hide the tray from the player's aim.
func _disable_levers() -> void:
	for child: Node in get_children():
		if child is SignalLever:
			(child as SignalLever).disable()


# ============================================================
# SAVING
# ============================================================

func _key(suffix: String) -> StringName:
	return StringName("%s_%s" % [persistent_id, suffix])


func _save_levers() -> void:
	SaveManager.set_state_value(STATE_SECTION, _key("levers"), states.duplicate())


func _restore_state() -> void:
	is_unlocked = bool(SaveManager.get_state_value(STATE_SECTION, _key("open"), false))

	if is_unlocked:
		states = solution.duplicate()
		return

	var saved: Variant = SaveManager.get_state_value(STATE_SECTION, _key("levers"), [])
	if not saved is Array:
		return

	var saved_list: Array = saved as Array
	for i: int in mini(saved_list.size(), states.size()):
		states[i] = bool(saved_list[i])
