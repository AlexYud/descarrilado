extends Node3D
class_name DoorController

## A door the player can open, close and unlock.
##
## The state (`is_open`, `is_locked`) changes the moment the player interacts; what
## the player sees is a short choreography that follows it, played by `_process`:
## the player leans in, the handle turns and the latch clicks, the door gives a
## crack and hangs there a moment, then swings open slowly and
## settles. A locked door rattles; with the key the key is brought to the keyhole,
## slid in, hitches, turns with a grinding, and stays in the lock. Scripted changes
## (`force_open`, `slam_shut`, restoring a save) skip the choreography.
##
## No two interactions are alike: each picks one of several variants (a cautious
## peek, a stuck door that pops free, a quick shove...) and rolls its timings, so
## the same door never plays the same way twice in a row.

## Raised when the player opens this door (not when a script does). With the
## choreography it comes when the door starts to swing open for real, after the
## crack, not when the button is pressed.
signal opened_by_player

## How far the key turns in the lock (negative is clockwise, seen from the face).
const KEY_TURN_DEGREES: float = -90.0

@export var hinge: Node3D
@export var door_root: Node3D

@export var open_angle_degrees: float = 85.0
@export var rotate_speed: float = 0.6
@export var starts_open: bool = false
@export var starts_locked: bool = false
@export var required_key_id: String = ""
@export var persistent_id: StringName = &""

@export var closed_prompt_text: String = "PROMPT_OPEN"
@export var opened_prompt_text: String = "PROMPT_CLOSE"
@export var locked_prompt_text: String = "PROMPT_LOCKED"
@export var unlock_prompt_text: String = "PROMPT_UNLOCK"

## Caption said when the player tries a locked door they cannot open yet.
@export var locked_line: String = ""

@export_category("Choreography")
## Plays the interaction as described above. Off, the door just swings by itself.
@export var animate_player_interaction: bool = true
## Fits a lever handle and a keyhole in place of the round knobs of the standard door.
@export var build_hardware: bool = true
## Half the thickness of the door, where the handle and the keyhole sit.
@export var door_half_thickness: float = 0.04
## How far from the door the player stands to push it, and how far away a player
## can be and still be walked up to it (farther than that, a script or a test is
## calling, so nobody is walked anywhere).
@export var approach_distance: float = 0.5
@export var max_approach_distance: float = 3.0
## Which of the door root's own axes sticks out of the door's faces (the thin one).
@export var door_normal_local: Vector3 = Vector3(0.0, 0.0, 1.0)
## Where along the door the player stands to push it, as a fraction of its width from
## the hinge: 0.5 is the middle, 1 the free end. Negative (the default) means in front
## of the handle. A long fence gate is pushed near its free end, not at the middle.
@export_range(-1.0, 1.0, 0.05) var approach_handle_fraction: float = -1.0
## A long, heavy gate: pushed with both hands (a bigger lean) and slower to swing.
@export var heavy_gate: bool = false
## Door sounds (latch, key, rattle, thud) are off for now; turn them on when real
## recordings replace the stand-ins.
@export var door_sounds_enabled: bool = false
## Plays this variant of opening every time instead of rolling one (for scripted
## scenes and tests): `standard`, `peek`, `stuck` or `quick`. Empty rolls one.
@export var open_variant_override: StringName = &""

var is_open: bool = false
var is_locked: bool = false

## Set by `slam_shut()`: the speed of the next swing, 0 for the normal one.
var _swing_speed_override: float = 0.0

var closed_rotation_degrees: Vector3 = Vector3.ZERO
var current_open_rotation_degrees: Vector3 = Vector3.ZERO

## Which face of the door the key was turned from and stays in: 1 front, -1 back, 0 none.
var _key_side: int = 0

var _hardware: Dictionary = {}

## The door's solid parts. While the door swings they let the player through: a
## door that sweeps through a standing player would otherwise drag them along.
var _door_bodies: Array[CollisionObject3D] = []
var _body_layers: Dictionary = {}
var _collision_suspended: bool = false

var _choreo: StringName = &""
var _choreo_t: float = 0.0
var _choreo_total: float = 0.0
var _busy_seconds: float = 0.0
var _lead: float = 0.0
var _side: int = 1
var _start_rotation: Vector3 = Vector3.ZERO
var _target_rotation: Vector3 = Vector3.ZERO
var _key_flight_from: Vector3 = Vector3.ZERO
## The rolled timings of the interaction being played (see `_plan_open` and the others).
var _knobs: Array[DoorKnobInteractable] = []
## What `_begin_choreo` was asked while the player is still walking up to the door.
var _pending_start: Dictionary = {}
var _plan: Dictionary = {}
var _key_plan: Dictionary = {}
var _cues: Dictionary = {}
var _player_ref: Node = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## The player walks up to a door before pushing it. Tests that time the door's
## own movements switch this off.
static var approach_enabled: bool = true
static var _sound_cache: Dictionary = {}
## The variant seen last for each kind of interaction, shared by every door.
static var _last_variant: Dictionary = {}


func _ready() -> void:
	if hinge == null:
		hinge = get_node_or_null("Hinge") as Node3D

	if door_root == null:
		door_root = get_node_or_null("Hinge/DoorRoot") as Node3D

	if hinge == null or door_root == null:
		push_warning("DoorController: hinge or door_root is not assigned.")
		set_process(false)
		return

	_rng.randomize()

	closed_rotation_degrees = hinge.rotation_degrees
	current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, absf(open_angle_degrees), 0.0)

	is_locked = starts_locked
	is_open = starts_open and not is_locked

	if is_open:
		hinge.rotation_degrees = current_open_rotation_degrees
	else:
		hinge.rotation_degrees = closed_rotation_degrees

	_cache_door_bodies()

	if build_hardware:
		_build_hardware()

	_restore_persistent_state()
	_show_resting_key()


func _exit_tree() -> void:
	_set_collision_suspended(false)
	_cancel_choreo(true)


func _process(delta: float) -> void:
	if hinge == null:
		return

	if _choreo != &"":
		# The door is solid while the player walks up to it and while it is tried,
		# and lets them through while it swings.
		_set_collision_suspended(_choreo == &"open" or _choreo == &"close")
		_step_choreo(delta)
		return

	var target_rotation: Vector3 = closed_rotation_degrees
	if is_open:
		target_rotation = current_open_rotation_degrees

	var swing_speed: float = (
		_swing_speed_override if _swing_speed_override > 0.0 else rotate_speed
	)
	_set_collision_suspended(
		hinge.rotation_degrees.distance_squared_to(target_rotation) > 0.0004
	)
	var weight: float = clamp(delta * swing_speed, 0.0, 1.0)
	hinge.rotation_degrees = hinge.rotation_degrees.lerp(target_rotation, weight)

	if hinge.rotation_degrees.distance_squared_to(target_rotation) < 0.000001:
		hinge.rotation_degrees = target_rotation
		_swing_speed_override = 0.0


func is_usable() -> bool:
	return hinge != null and door_root != null


## True while the player's hands are on the door; it offers no prompt then.
func is_busy() -> bool:
	return _choreo != &"" and _choreo_t < _busy_seconds


func get_prompt_text() -> String:
	if is_locked:
		return locked_prompt_text

	if is_open:
		return opened_prompt_text

	return closed_prompt_text


func get_prompt_text_for_player(player: Node) -> String:
	if is_locked:
		if _player_can_unlock(player):
			return unlock_prompt_text
		return locked_prompt_text

	if is_open:
		return opened_prompt_text

	return closed_prompt_text


func interact(player: Node) -> void:
	var side: int = _get_side_of(player)
	var used_key: bool = false

	if is_locked:
		var unlocked: bool = _try_unlock_with_player(player)
		if not unlocked:
			if animate_player_interaction and _can_animate():
				_begin_choreo(&"locked", player, side, false)
			elif not locked_line.is_empty():
				CaptionManager.say(locked_line)
			return

		used_key = true
		_key_side = side

	if not is_open:
		_choose_open_side(player)

	is_open = not is_open
	_remember_persistent_state()

	if animate_player_interaction and _can_animate():
		_begin_choreo(&"open" if is_open else &"close", player, side, used_key)
		return

	_cancel_choreo(true)
	_show_resting_key()

	if is_open:
		opened_by_player.emit()


## Opens the door by itself, with no player involved. `swing_sign` picks the
## side it swings towards (+1 or -1 around the hinge). A locked door stays shut.
func force_open(swing_sign: float = 1.0) -> void:
	if hinge == null or is_locked or is_open:
		return

	_cancel_choreo(true)
	current_open_rotation_degrees = closed_rotation_degrees + Vector3(
		0.0,
		absf(open_angle_degrees) * signf(swing_sign),
		0.0
	)
	is_open = true
	_remember_persistent_state()


## Swings the door shut hard and fast, with no player involved. Does nothing to
## a door that is already closed. `speed` replaces `rotate_speed` for this swing.
func slam_shut(speed: float = 16.0) -> void:
	if hinge == null or not is_open:
		return

	_cancel_choreo(true)
	_swing_speed_override = speed
	is_open = false
	_remember_persistent_state()


func unlock() -> void:
	is_locked = false
	_remember_persistent_state()


func lock() -> void:
	_cancel_choreo(true)
	is_locked = true
	is_open = false
	_key_side = 0
	for face: Variant in _hardware:
		(_hardware[face] as DoorHardware).show_key(false)
	_remember_persistent_state()


func _restore_persistent_state() -> void:
	if persistent_id.is_empty():
		return

	var saved_value: Variant = SaveManager.get_state_value(
		&"doors",
		persistent_id,
		{}
	)
	if not saved_value is Dictionary:
		return

	var saved_state: Dictionary = saved_value as Dictionary
	if saved_state.is_empty():
		return

	is_locked = bool(saved_state.get("is_locked", is_locked))
	is_open = (
		bool(saved_state.get("is_open", is_open))
		and not is_locked
	)
	_key_side = int(saved_state.get("key_side", 0))
	var signed_open_angle: float = float(saved_state.get(
		"signed_open_angle_degrees",
		absf(open_angle_degrees)
	))
	current_open_rotation_degrees = (
		closed_rotation_degrees
		+ Vector3(0.0, signed_open_angle, 0.0)
	)
	hinge.rotation_degrees = (
		current_open_rotation_degrees
		if is_open
		else closed_rotation_degrees
	)


func _remember_persistent_state() -> void:
	if persistent_id.is_empty() or not SaveManager.has_active_game():
		return

	SaveManager.set_state_value(
		&"doors",
		persistent_id,
		{
			"is_open": is_open,
			"is_locked": is_locked,
			"key_side": _key_side,
			"signed_open_angle_degrees": (
				current_open_rotation_degrees.y
				- closed_rotation_degrees.y
			),
		}
	)


func _try_unlock_with_player(player: Node) -> bool:
	if not is_locked:
		return true

	if required_key_id == "":
		return false

	if not _player_has_required_key(player):
		return false

	if not _consume_required_key(player):
		return false

	unlock()
	return true


func _player_can_unlock(player: Node) -> bool:
	if not is_locked:
		return false

	if required_key_id == "":
		return false

	return _player_has_required_key(player)


func _player_has_required_key(player: Node) -> bool:
	if player == null:
		return false

	if not player.has_method("has_inventory_item"):
		return false

	return bool(player.call("has_inventory_item", required_key_id))


func _consume_required_key(player: Node) -> bool:
	if player == null:
		return false

	if not player.has_method("consume_inventory_item"):
		return false

	return bool(player.call("consume_inventory_item", required_key_id))


func _choose_open_side(player: Node) -> void:
	var angle_magnitude: float = absf(open_angle_degrees)

	if hinge == null or door_root == null:
		current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, angle_magnitude, 0.0)
		return

	if not (player is Node3D):
		current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, angle_magnitude, 0.0)
		return

	var player_node: Node3D = player as Node3D
	var player_position: Vector3 = player_node.global_position

	var positive_local_center: Vector3 = door_root.position.rotated(Vector3.UP, deg_to_rad(angle_magnitude))
	var negative_local_center: Vector3 = door_root.position.rotated(Vector3.UP, deg_to_rad(-angle_magnitude))

	var positive_global_center: Vector3 = hinge.to_global(positive_local_center)
	var negative_global_center: Vector3 = hinge.to_global(negative_local_center)

	var positive_distance_sq: float = player_position.distance_squared_to(positive_global_center)
	var negative_distance_sq: float = player_position.distance_squared_to(negative_global_center)

	if positive_distance_sq >= negative_distance_sq:
		current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, angle_magnitude, 0.0)
	else:
		current_open_rotation_degrees = closed_rotation_degrees + Vector3(0.0, -angle_magnitude, 0.0)


# ----------------------------------------------------------------------
# Hardware: the handle and the keyhole
# ----------------------------------------------------------------------

## Replaces the round knobs of the standard door with a lever handle and a
## keyhole on each face. A door without knob meshes (the fence gate) is left alone.
func _build_hardware() -> void:
	var knobs: Array[DoorKnobInteractable] = []
	_collect_knobs(door_root, knobs)
	_knobs = knobs.duplicate()

	for knob: DoorKnobInteractable in knobs:
		var knob_mesh: MeshInstance3D = knob.get_node_or_null("KnobMesh") as MeshInstance3D
		if knob_mesh == null:
			continue

		var side: int = 1 if knob.position.z >= 0.0 else -1
		if _hardware.has(side):
			continue

		var brass: Material = knob_mesh.get_surface_override_material(0)
		if brass == null and knob_mesh.mesh != null:
			brass = knob_mesh.mesh.surface_get_material(0)
		if brass == null:
			var fallback: StandardMaterial3D = StandardMaterial3D.new()
			fallback.albedo_color = Color(0.58, 0.44, 0.15)
			fallback.metallic = 0.85
			fallback.roughness = 0.4
			brass = fallback

		knob_mesh.visible = false

		var hardware: DoorHardware = DoorHardware.new()
		hardware.name = "Hardware%s" % ("Front" if side > 0 else "Back")
		hardware.position = Vector3(knob.position.x, knob.position.y, float(side) * door_half_thickness)
		hardware.rotation.y = 0.0 if side > 0 else PI
		door_root.add_child(hardware)
		hardware.setup(side, brass)
		_hardware[side] = hardware


func _collect_knobs(node: Node, out: Array[DoorKnobInteractable]) -> void:
	for child: Node in node.get_children():
		if child is DoorKnobInteractable:
			out.append(child as DoorKnobInteractable)
		_collect_knobs(child, out)


## Leaves the key in the keyhole it was turned in, turned a quarter round.
func _show_resting_key() -> void:
	if _key_side == 0 or not _hardware.has(_key_side):
		return

	var hardware: DoorHardware = _hardware[_key_side] as DoorHardware
	hardware.show_key(true)
	hardware.set_key_state(1.0, KEY_TURN_DEGREES)


func _set_levers(amount: float) -> void:
	for face: Variant in _hardware:
		(_hardware[face] as DoorHardware).set_lever_turn(amount)


# ----------------------------------------------------------------------
# The choreography
# ----------------------------------------------------------------------
#
# Every interaction is planned when it starts: one of a few variants is picked
# (never the one just seen if it can be helped), and its timings, strengths and
# leans are rolled within ranges, so no two openings look the same.

func _can_animate() -> bool:
	return is_inside_tree() and hinge != null and door_root != null


func _get_side_of(player: Node) -> int:
	if player is Node3D and is_inside_tree():
		return 1 if to_local((player as Node3D).global_position).z >= 0.0 else -1

	return 1


func _begin_choreo(kind: StringName, player: Node, side: int, with_key: bool) -> void:
	_cancel_choreo(false)

	# Far from the handle the player first walks up to the door, slowly, looking at
	# it; then the door's own choreography starts.
	var movement: Node = _get_movement_controller(player)
	if approach_enabled and movement != null and movement.has_method("begin_guided_walk"):
		var target: Dictionary = _approach_target(player)
		if (
			not target.is_empty()
			and bool(movement.call(
				"begin_guided_walk",
				target["stand"],
				target["look"],
				PlayerMovementController.WALK_SPEED * 0.8,
				3.0
			))
		):
			_choreo = &"approach"
			_choreo_t = 0.0
			_choreo_total = INF
			_busy_seconds = INF
			_player_ref = player
			_pending_start = {"kind": kind, "side": side, "with_key": with_key}
			return

	_start_choreo(kind, player, side, with_key)


func _start_choreo(kind: StringName, player: Node, side: int, with_key: bool) -> void:
	_choreo = kind
	_choreo_t = 0.0
	_cues.clear()
	_player_ref = player
	_side = side
	_start_rotation = hinge.rotation_degrees
	_lead = 0.0
	_plan = {}

	if with_key:
		_plan_key()
		_lead = float(_key_plan["total"])

	var hold_seconds: float = 0.0

	match kind:
		&"open":
			_target_rotation = current_open_rotation_degrees
			_plan = _plan_open()
			var open_start: float = _plan["open_start"]
			var main_end: float = _plan["main_end"]
			_choreo_total = _lead + main_end + float(_plan["bounce"])
			_busy_seconds = _lead + open_start + (main_end - open_start) * 0.8
			hold_seconds = _lead + open_start + 0.1
		&"close":
			_target_rotation = closed_rotation_degrees
			_plan = _plan_close()
			_choreo_total = float(_plan["total"])
			_busy_seconds = _choreo_total
			hold_seconds = float(_plan["reach"]) + float(_plan["pull"]) * 0.7
		_:
			_target_rotation = _start_rotation
			_plan = _plan_locked()
			_choreo_total = float(_plan["total"])
			_busy_seconds = _choreo_total
			hold_seconds = float(_plan["last_try"]) + 0.4

	if with_key and _hardware.has(side):
		var camera: Camera3D = _get_camera(player)
		if camera != null:
			_key_flight_from = camera.to_global(Vector3(0.3, -0.3, -0.45))
		else:
			_key_flight_from = (_hardware[side] as DoorHardware).global_position + Vector3(0.0, -0.1, 0.3)

	if player != null and player.has_method("hold_movement"):
		player.call("hold_movement", hold_seconds)


func _step_choreo(delta: float) -> void:
	_choreo_t += delta

	if _choreo == &"approach":
		_step_approach()
		return

	match _choreo:
		&"open":
			_eval_open()
		&"close":
			_eval_close()
		_:
			_eval_locked()

	if _choreo_t >= _choreo_total:
		_finish_choreo()


## Settles every moving part at its final place.
func _finish_choreo() -> void:
	match _choreo:
		&"open", &"close":
			hinge.rotation_degrees = _target_rotation
		_:
			hinge.rotation_degrees = _start_rotation

	_cancel_choreo(true)


## Stops the choreography where it is. `release_view` also lets go of the player's
## view; a new choreography that follows at once keeps hold of it instead.
func _cancel_choreo(release_view: bool) -> void:
	if _choreo == &"approach":
		var walker: Node = _get_movement_controller(_player_ref)
		if walker != null and walker.has_method("cancel_guided_walk"):
			walker.call("cancel_guided_walk")
		_pending_start = {}

	var was_playing: bool = _choreo != &""
	_choreo = &""
	_choreo_t = 0.0
	_cues.clear()

	if was_playing:
		_set_levers(0.0)

	if release_view:
		_set_view(Vector3.ZERO, 0.0, 0.0)

	if release_view:
		# A hold that outlasts what it was for would leave the player stuck.
		if (
			was_playing
			and _player_ref != null
			and is_instance_valid(_player_ref)
			and _player_ref.has_method("release_movement_hold")
		):
			_player_ref.call("release_movement_hold")

		_player_ref = null


# -- Planning -----------------------------------------------------------

## Picks a variant by weight, making the one seen last far less likely so the
## player does not see the same thing twice in a row.
func _pick_variant(kind: StringName, weights: Dictionary) -> StringName:
	if kind == &"open" and weights.has(open_variant_override):
		_last_variant[kind] = open_variant_override
		return open_variant_override

	var pool: Dictionary = weights.duplicate()
	var last: StringName = _last_variant.get(kind, &"")
	if pool.has(last):
		pool[last] = float(pool[last]) * 0.2

	var total: float = 0.0
	for choice: Variant in pool:
		total += float(pool[choice])

	var roll: float = _rng.randf() * total
	var chosen: StringName = &""
	for choice: Variant in pool:
		chosen = choice
		roll -= float(pool[choice])
		if roll <= 0.0:
			break

	_last_variant[kind] = chosen
	return chosen


func _rand(from_value: float, to_value: float) -> float:
	return _rng.randf_range(from_value, to_value)


## One stretch of a movement: lasts `d` seconds, ends at `to`, eased by `ease_kind`.
func _stretch(d: float, to: float, ease_kind: StringName = &"smooth", extra: Dictionary = {}) -> Dictionary:
	var stretch: Dictionary = {"d": d, "to": to, "ease": ease_kind}
	stretch.merge(extra, true)
	return stretch


func _plan_open() -> Dictionary:
	var variant: StringName = _pick_variant(
		&"open", {&"standard": 0.4, &"peek": 0.25, &"stuck": 0.2, &"quick": 0.15}
	)
	var stretches: Array = []
	var reach: float = 0.3
	var lean: float = _rand(0.8, 1.2)
	var pop_at: float = -1.0

	match variant:
		&"peek":
			# Cautious: the door barely opens, a long wait, a wider look, then slowly.
			reach = _rand(0.3, 0.4)
			var crack: float = _rand(0.10, 0.13)
			var look: float = _rand(0.22, 0.3)
			stretches = [
				_stretch(reach, 0.0),
				_stretch(_rand(0.7, 0.95), crack, &"in"),
				_stretch(_rand(0.8, 1.2), crack + 0.01),
				_stretch(_rand(0.6, 0.8), look, &"smooth", {"opens": true}),
				_stretch(_rand(0.3, 0.5), look + 0.006),
				_stretch(_rand(1.7, 2.2), 1.0, &"smooth", _wobble(0.02)),
			]
			lean *= 1.1
		&"stuck":
			# The wood is swollen: a shudder, a hard push, then it pops free.
			reach = _rand(0.28, 0.36)
			var shudder: float = _rand(0.008, 0.014)
			var freed: float = _rand(0.08, 0.11)
			stretches = [
				_stretch(reach, 0.0),
				_stretch(_rand(0.2, 0.28), shudder, &"out"),
				_stretch(_rand(0.3, 0.5), shudder + 0.001),
				_stretch(_rand(0.12, 0.18), freed, &"snap", {"opens": true}),
				_stretch(_rand(0.15, 0.3), freed + 0.006),
				_stretch(_rand(1.2, 1.7), 1.0, &"smooth", _wobble(0.015)),
			]
			lean *= 1.25
			pop_at = reach + float(stretches[1]["d"]) + float(stretches[2]["d"])
		&"quick":
			reach = _rand(0.18, 0.24)
			stretches = [
				_stretch(reach, 0.0),
				_stretch(_rand(0.25, 0.35), 0.09, &"in"),
				_stretch(_rand(0.05, 0.12), 0.1),
				_stretch(_rand(0.9, 1.25), 1.0, &"smooth", _wobble(0.008, true)),
			]
			lean *= 0.6
		_:
			reach = _rand(0.26, 0.36)
			var crack: float = _rand(0.045, 0.08)
			stretches = [
				_stretch(reach, 0.0),
				_stretch(_rand(0.45, 0.7), crack, &"in"),
				_stretch(_rand(0.3, 0.6), crack + 0.008),
				_stretch(_rand(1.4, 2.0), 1.0, &"smooth", _wobble(_rand(0.008, 0.025), true)),
			]

	if heavy_gate:
		# A long gate swings more slowly and is pushed with more of the body.
		for index: int in range(1, stretches.size()):
			(stretches[index] as Dictionary)["d"] = float((stretches[index] as Dictionary)["d"]) * 1.3
		lean *= 1.4

	# The stretch that opens for real: the first marked one, else the last.
	var open_index: int = stretches.size() - 1
	for i: int in stretches.size():
		if (stretches[i] as Dictionary).get("opens", false):
			open_index = i
			break

	var open_start: float = 0.0
	var main_end: float = 0.0
	for i: int in stretches.size():
		if i == open_index:
			open_start = main_end
		main_end += float((stretches[i] as Dictionary)["d"])

	# The handle lets go a little after the door starts to move.
	var lever_hold: float = open_start - 0.05
	if variant == &"stuck":
		lever_hold = open_start + 0.2

	return {
		"variant": variant,
		"reach": reach,
		"stretches": stretches,
		"open_start": open_start,
		"main_end": main_end,
		"bounce": 0.35,
		"lever_hold": lever_hold,
		"lean": lean,
		"nudge": _rand(0.7, 1.3) * (1.4 if heavy_gate else 1.0),
		"lean_side": _rand(-1.0, 1.0),
		"pop_at": pop_at,
	}


func _wobble(amount: float, random_count: bool = false) -> Dictionary:
	return {
		"wobble": amount,
		"wobble_count": float(_rng.randi_range(3, 5)) if random_count else 3.0,
	}


func _plan_close() -> Dictionary:
	var variant: StringName = _pick_variant(&"close", {&"standard": 0.5, &"soft": 0.3, &"brisk": 0.2})
	var reach: float = _rand(0.18, 0.26)
	var pull: float = _rand(0.75, 1.05)
	var settle: float = _rand(0.34, 0.44)
	var latch_db: float = -2.0
	var fraction: float = _rand(0.92, 0.95)

	match variant:
		&"soft":
			pull = _rand(1.1, 1.5)
			settle = _rand(0.5, 0.7)
			latch_db = -8.0
		&"brisk":
			pull = _rand(0.5, 0.7)
			settle = _rand(0.22, 0.3)
			latch_db = 2.0

	var latch: float = 0.3
	return {
		"variant": variant,
		"reach": reach,
		"pull": pull,
		"settle": settle,
		"latch": latch,
		"latch_db": latch_db,
		"fraction": fraction,
		"total": reach + pull + settle + latch,
		"lean_side": _rand(-1.0, 1.0),
	}


func _plan_locked() -> Dictionary:
	# Two or three tries, each weaker than the last, at uneven intervals.
	var tries: Array = []
	var at: float = _rand(0.08, 0.14)
	var strengths: Array[float] = [1.0, _rand(0.5, 0.7), _rand(0.35, 0.5)]
	var count: int = _rng.randi_range(2, 3)
	for i: int in count:
		tries.append({"at": at, "strength": strengths[i], "shake_hz": _rand(48.0, 62.0)})
		at += _rand(0.28, 0.42)

	var last_try: float = float(tries[-1]["at"])
	return {
		"tries": tries,
		"last_try": last_try,
		"total": last_try + 0.95,
		"lean_side": _rand(-1.0, 1.0),
	}


## The key's timings: how it comes in, whether it fumbles, how hard it turns.
func _plan_key() -> void:
	var flight: float = _rand(0.42, 0.6)
	var fumble: bool = _rng.randf() < 0.25
	var insert: Array = []
	if fumble:
		# The blade misses the slot, backs off, and finds it the second time.
		insert = [
			_stretch(_rand(0.16, 0.22), 0.3, &"out"),
			_stretch(_rand(0.1, 0.16), 0.3),
			_stretch(_rand(0.16, 0.22), 0.08, &"smooth"),
			_stretch(_rand(0.26, 0.34), 0.75, &"smooth"),
		]
	else:
		insert = [_stretch(_rand(0.26, 0.34), 0.75, &"smooth")]

	var insert_time: float = 0.0
	for stretch: Dictionary in insert:
		insert_time += float(stretch["d"])

	var hitch: float = _rand(0.14, 0.3) if _rng.randf() < 0.75 else 0.0
	var seat: float = _rand(0.1, 0.16)
	var insert_end: float = flight + insert_time
	insert.append(_stretch(hitch, 0.75))
	insert.append(_stretch(seat, 1.0, &"smooth"))

	var turn_start: float = insert_end + hitch + seat + _rand(0.3, 0.5)
	var turn: float = _rand(0.6, 0.85)
	_key_plan = {
		"flight": flight,
		"insert": insert,
		"insert_end": insert_end,
		"hitch": hitch,
		"jiggle_amp": _rand(3.0, 7.0),
		"turn_start": turn_start,
		"turn": turn,
		"stiff": _rand(0.12, 0.28),
		"bolt_at": turn_start + turn,
		"total": turn_start + turn + _rand(0.3, 0.45),
		"fumble": fumble,
	}


# -- Evaluation ---------------------------------------------------------

## How far along its path a movement is at `t`, given its stretches in order.
func _progress(stretches: Array, t: float) -> float:
	var from_value: float = 0.0
	var start: float = 0.0

	for stretch: Dictionary in stretches:
		var d: float = stretch["d"]
		if t < start + d:
			var q: float = _seg(t, start, start + d)
			var shaped: float = _shape(stretch["ease"], q)
			var wobble: float = float(stretch.get("wobble", 0.0))
			if wobble > 0.0:
				shaped += wobble * sin(float(stretch["wobble_count"]) * PI * q) * sin(PI * q)
			return lerpf(from_value, float(stretch["to"]), shaped)

		from_value = stretch["to"]
		start += d

	return from_value


func _shape(kind: StringName, q: float) -> float:
	match kind:
		&"in":
			return q * q
		&"out":
			return _ease_out(q)
		&"snap":
			return 1.0 - pow(1.0 - q, 3.0)
		_:
			return _smooth(q)


func _eval_open() -> void:
	var t: float = _choreo_t
	var open_time: float = t - _lead
	var p: Dictionary = _plan

	if _lead > 0.0:
		_eval_key(t)

	var reach: float = p["reach"]
	var open_start: float = p["open_start"]
	var main_end: float = p["main_end"]
	var lever_hold: float = p["lever_hold"]

	# The handle: pressed down, held while the door gives, let go.
	var lever: float = 0.0
	if open_time > 0.0:
		lever = _ease_out(_seg(open_time, 0.0, reach))
	if open_time > lever_hold:
		lever *= 1.0 - _smooth(_seg(open_time, lever_hold, lever_hold + 0.4))
	_set_levers(lever)

	# How far the door has gone from where it was to wide open.
	var toward: float = 0.0
	if open_time > 0.0:
		toward = _progress(p["stretches"], open_time)
	if open_time > main_end:
		var bounce: float = float(p["bounce"])
		toward = 1.0 - 0.012 * sin(PI * _seg(open_time, main_end, main_end + bounce))

	hinge.rotation_degrees = _start_rotation.lerp(_target_rotation, clampf(toward, 0.0, 1.0))

	# The player leans in to the door, nudges forward as it gives, then lets go.
	var strength: float = p["lean"]
	var lean: float = _ease_out(_seg(open_time, 0.0, reach))
	lean *= 1.0 - _smooth(_seg(open_time, open_start + 0.05, open_start + 1.0))
	lean *= strength
	var nudge: float = sin(PI * _seg(open_time, open_start, open_start + 0.9)) * float(p["nudge"])
	var side: float = p["lean_side"]
	var offset: Vector3 = (
		Vector3(0.012 * side, -0.02, -0.05) * lean
		+ Vector3(0.0, 0.0, -0.025) * nudge
	)
	var pitch: float = -0.8 * lean + 0.5 * nudge
	var roll: float = 0.4 * lean * side

	if _lead > 0.0:
		var key_view: Array = _key_view(t)
		offset += key_view[0] as Vector3
		pitch += float(key_view[1])
		roll += float(key_view[2])

	_set_view(offset, pitch, roll)

	var at: Vector3 = _sound_position()
	if open_time >= reach * 0.7 and _cue(&"latch"):
		_play(&"latch", at, -6.0)
	if open_time >= lever_hold + 0.05 and _cue(&"spring"):
		_play(&"latch", at, -17.0, 0.9)
	var pop_at: float = p["pop_at"]
	if pop_at >= 0.0 and open_time >= pop_at and _cue(&"pop"):
		_play(&"thud", door_root.global_position, -8.0, 1.4)
	if open_time >= open_start and _cue(&"opened"):
		opened_by_player.emit()
	if (
		open_time >= main_end
		and absf(_target_rotation.y - _start_rotation.y) >= 60.0
		and _cue(&"thud")
	):
		_play(&"thud", door_root.global_position, -9.0)


func _eval_close() -> void:
	var t: float = _choreo_t
	var p: Dictionary = _plan
	var reach: float = p["reach"]
	var pull_end: float = reach + float(p["pull"])
	var settle_end: float = pull_end + float(p["settle"])
	var fraction: float = p["fraction"]

	var lever: float = 0.8 * _ease_out(_seg(t, 0.0, reach))
	if t > settle_end:
		lever = lerpf(0.8, 0.0, _seg(t, settle_end, settle_end + 0.25))
	_set_levers(lever)

	var toward: float = 0.0
	if t < reach:
		toward = 0.0
	elif t < pull_end:
		toward = fraction * _smooth(_seg(t, reach, pull_end))
	elif t < settle_end:
		toward = lerpf(fraction, 1.0, _ease_out(_seg(t, pull_end, settle_end)))
	else:
		toward = 1.0

	hinge.rotation_degrees = _start_rotation.lerp(_target_rotation, toward)

	var side: float = p["lean_side"]
	var lean: float = _ease_out(_seg(t, 0.0, reach))
	lean *= 1.0 - _smooth(_seg(t, pull_end - 0.2, settle_end + 0.3))
	var pull_back: float = sin(PI * _seg(t, reach, pull_end))
	_set_view(
		Vector3(0.008 * side, -0.012, -0.03) * lean + Vector3(0.0, 0.0, 0.025) * pull_back,
		-0.4 * lean,
		0.3 * side * lean
	)

	if t >= 0.1 and _cue(&"latch"):
		_play(&"latch", _sound_position(), -8.0, 0.95)
	if t >= settle_end and _cue(&"latch_close"):
		_play(&"latch_close", _sound_position(), float(p["latch_db"]))


func _eval_locked() -> void:
	var t: float = _choreo_t
	var p: Dictionary = _plan
	var tries: Array = p["tries"]

	var lever: float = 0.0
	var shake: float = 0.0
	var kick: float = 0.0

	# Each try: the handle goes down fast, is held a moment and let go; the door
	# knocks against its bolt and the frame shakes, less every time.
	for entry: Dictionary in tries:
		var local: float = t - float(entry["at"])
		if local < 0.0:
			continue

		var strength: float = entry["strength"]
		var pulse: float = _ease_out(_seg(local, 0.0, 0.08))
		pulse *= 1.0 - _smooth(_seg(local, 0.2, 0.4))
		lever = maxf(lever, pulse * lerpf(0.6, 1.0, strength))
		shake += 0.7 * strength * exp(-local * 16.0) * sin(local * float(entry["shake_hz"]))
		kick = maxf(kick, strength * exp(-local * 10.0))

	_set_levers(lever)
	hinge.rotation_degrees = _start_rotation + Vector3(0.0, shake, 0.0)

	var side: float = p["lean_side"]
	var last_try: float = p["last_try"]
	var first_try: float = float(tries[0]["at"])
	var lean: float = _ease_out(_seg(t, 0.0, first_try)) * (1.0 - _smooth(_seg(t, last_try + 0.3, last_try + 0.6)))
	_set_view(
		Vector3(0.008 * side, -0.015, -0.03) * lean + Vector3(0.0, 0.0, 0.045) * kick,
		-0.3 * lean + 0.8 * kick,
		0.5 * kick * side
	)

	for i: int in tries.size():
		var entry: Dictionary = tries[i]
		if t >= float(entry["at"]) and _cue(StringName("rattle%d" % i)):
			var strength: float = entry["strength"]
			_play(&"rattle", _sound_position(), lerpf(-9.0, 0.0, strength), _rand(0.9, 1.05))
	if t >= last_try + 0.4 and _cue(&"line"):
		if not locked_line.is_empty():
			CaptionManager.say(locked_line)


## The key brought to the lock, slid in, turned against the wards.
func _eval_key(t: float) -> void:
	if not _hardware.has(_side):
		return

	var k: Dictionary = _key_plan
	var hardware: DoorHardware = _hardware[_side] as DoorHardware
	hardware.show_key(true)

	var flight: float = k["flight"]
	var turn_start: float = k["turn_start"]
	var turn: float = k["turn"]

	var twist: float = 0.0
	if t >= turn_start:
		var q: float = _seg(t, turn_start, turn_start + turn)
		# Stiff at first, then it gives all at once.
		var stiff: float = k["stiff"]
		var profile: float = 0.0
		if q < 0.45:
			profile = stiff * pow(q / 0.45, 1.5)
		else:
			profile = stiff + (1.0 - stiff) * _smooth((q - 0.45) / 0.55)
		twist = KEY_TURN_DEGREES * profile

	if t < flight:
		hardware.set_key_flight(_seg(t, 0.0, flight), _key_flight_from)
	else:
		var insert: float = _progress(k["insert"], t - flight)
		var jiggle: float = 0.0
		var hitch: float = k["hitch"]
		var insert_end: float = k["insert_end"]
		if hitch > 0.0 and t >= insert_end and t < insert_end + hitch:
			# The blade catches on the wards; a quick wiggle frees it.
			jiggle = (
				float(k["jiggle_amp"]) * sin((t - insert_end) * 70.0)
				* (1.0 - _seg(t, insert_end, insert_end + hitch))
			)
		hardware.set_key_state(insert, twist + jiggle)

	var at: Vector3 = hardware.get_key_slot_global()
	if t >= flight and _cue(&"key_insert"):
		_play(&"key_insert", at, -3.0)
	if bool(k["fumble"]) and t >= flight + 0.4 and _cue(&"key_retry"):
		_play(&"key_insert", at, -8.0, 1.1)
	if t >= turn_start and _cue(&"key_turn"):
		_play(&"key_turn", at, -2.0, 0.7 / turn)
	if t >= float(k["bolt_at"]) and _cue(&"bolt"):
		_play(&"bolt", at, 0.0)


## The player's view while the key goes in: bent towards the lock, straining on the turn.
func _key_view(t: float) -> Array:
	var k: Dictionary = _key_plan
	var turn_start: float = k["turn_start"]
	var bolt_at: float = k["bolt_at"]
	var bend: float = _ease_out(_seg(t, 0.0, float(k["flight"])))
	bend *= 1.0 - _smooth(_seg(t, bolt_at, float(k["total"])))
	var strain: float = sin(PI * _seg(t, turn_start, bolt_at))
	var side: float = _plan.get("lean_side", 0.0)
	return [
		Vector3(0.01, -0.04, -0.04) * bend + Vector3(0.0, 0.0, -0.01) * strain,
		-3.5 * bend - 0.5 * strain,
		-1.2 * strain * signf(side if side != 0.0 else 1.0),
	]


func _set_view(offset: Vector3, pitch_degrees: float, roll_degrees: float) -> void:
	var movement: Node = _get_movement_controller(_player_ref)
	if movement == null:
		return

	movement.set("gesture_offset", offset)
	movement.set("gesture_pitch_degrees", pitch_degrees)
	movement.set("gesture_roll_degrees", roll_degrees)


func _get_movement_controller(player: Variant) -> Node:
	if player == null or not is_instance_valid(player):
		return null

	return player.get("movement_controller") as Node


func _get_camera(player: Variant) -> Camera3D:
	var movement: Node = _get_movement_controller(player)
	if movement == null:
		return null

	return movement.get("camera") as Camera3D


func _sound_position() -> Vector3:
	if _hardware.has(_side):
		return (_hardware[_side] as DoorHardware).get_handle_global()

	return door_root.global_position


## True the first time it is asked once the moment has come, then false.
func _cue(id: StringName) -> bool:
	if _cues.has(id):
		return false

	_cues[id] = true
	return true


## Plays a sound at `at`. Every play is a little different (volume and pitch), so
## repeating a door never repeats its sounds exactly.
func _play(id: StringName, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not door_sounds_enabled:
		return

	var stream: AudioStream = _get_stream(id)
	if stream == null or not is_inside_tree():
		return

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db + _rand(-1.5, 0.5)
	player.pitch_scale = pitch * _rand(0.94, 1.06)
	player.unit_size = 5.0
	player.max_distance = 30.0
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


static func _get_stream(id: StringName) -> AudioStream:
	if _sound_cache.has(id):
		return _sound_cache[id] as AudioStream

	var stream: AudioStream = null
	match id:
		&"latch":
			stream = PlaceholderAudio.make_door_latch()
		&"latch_close":
			stream = PlaceholderAudio.make_door_latch_close()
		&"thud":
			stream = PlaceholderAudio.make_door_thud()
		&"key_insert":
			stream = PlaceholderAudio.make_key_insert()
		&"key_turn":
			stream = PlaceholderAudio.make_key_turn()
		&"bolt":
			stream = PlaceholderAudio.make_bolt_throw()
		&"rattle":
			stream = PlaceholderAudio.make_locked_rattle()

	_sound_cache[id] = stream
	return stream


func _seg(value: float, from_value: float, to_value: float) -> float:
	return clampf((value - from_value) / (to_value - from_value), 0.0, 1.0)


func _smooth(value: float) -> float:
	var x: float = clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - clampf(value, 0.0, 1.0), 2.0)


# -- Walking up to the door -----------------------------------------------

## Where the player stands to push the door (in front of the handle, on their own
## side, at arm's length) and what they look at on the way. {} when no walk is
## needed (they are there already), none is possible (something is in the way) or
## the caller is not a player at the door (a script, a test far away).
func _approach_target(player: Node) -> Dictionary:
	if not player is Node3D or door_root == null:
		return {}

	var body: Node3D = player as Node3D
	var normal: Vector3 = door_root.global_basis * door_normal_local
	normal.y = 0.0
	if normal.length() < 0.01:
		return {}

	normal = normal.normalized()
	var side: float = (
		1.0 if (body.global_position - door_root.global_position).dot(normal) >= 0.0 else -1.0
	)
	var handle: Vector3 = _handle_position(int(side), body)
	var stand: Vector3 = handle + normal * side * approach_distance
	stand.y = body.global_position.y

	var gap: Vector3 = stand - body.global_position
	gap.y = 0.0
	if gap.length() < 0.12 or gap.length() > max_approach_distance:
		return {}

	if not _way_is_clear(body, stand):
		return {}

	return {"stand": stand, "look": handle}


## The handle on `side` of the door, or the knob nearest the player on a door that
## has no fitted handle (the fence gate).
func _handle_position(side: int, body: Node3D) -> Vector3:
	if approach_handle_fraction >= 0.0 and hinge != null:
		return hinge.global_position + (
			(door_root.global_position - hinge.global_position) * 2.0 * approach_handle_fraction
		)

	if _hardware.has(side):
		return (_hardware[side] as DoorHardware).get_handle_global()

	var best: Vector3 = door_root.global_position
	var best_distance: float = INF
	for knob: DoorKnobInteractable in _knobs:
		var distance: float = knob.global_position.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = knob.global_position

	return best


func _step_approach() -> void:
	var movement: Node = _get_movement_controller(_player_ref)
	var walking: bool = movement != null and bool(movement.call("is_guided_walking"))
	if walking and _choreo_t < 4.0:
		return

	if walking:
		movement.call("cancel_guided_walk")

	var pending: Dictionary = _pending_start
	_pending_start = {}
	_choreo = &""
	_start_choreo(pending["kind"], _player_ref, pending["side"], pending["with_key"])


## Whether nothing stands between the player and the spot (furniture, a wall):
## rays at knee and chest height, down the middle and along both sides of the
## player's width. The door itself does not count.
func _way_is_clear(body: Node3D, stand: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var direction: Vector3 = stand - body.global_position
	direction.y = 0.0
	direction = direction.normalized()
	var sideways: Vector3 = Vector3(-direction.z, 0.0, direction.x)

	for offset: float in [-0.22, 0.0, 0.22]:
		for height: float in [-0.3, 0.2]:
			var lift: Vector3 = sideways * offset + Vector3.UP * height
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				body.global_position + lift, stand + lift
			)
			if body is CollisionObject3D:
				query.exclude = [(body as CollisionObject3D).get_rid()]

			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				continue

			# Rising ground is not an obstacle.
			if (hit["normal"] as Vector3).y > 0.6:
				continue

			var collider: Node = hit["collider"] as Node
			if collider != null and door_root.is_ancestor_of(collider):
				continue

			return false

	return true


# -- Letting the player through a swinging door ------------------------------

func _cache_door_bodies() -> void:
	_door_bodies.clear()
	for node: Node in door_root.find_children("*", "CollisionObject3D", true, false):
		if node is Area3D:
			continue

		_door_bodies.append(node as CollisionObject3D)


## While suspended the door's solid parts are on no collision layer, so a swinging
## door never pushes or drags a player standing in its way.
func _set_collision_suspended(suspended: bool) -> void:
	if suspended == _collision_suspended:
		return

	_collision_suspended = suspended

	for body: CollisionObject3D in _door_bodies:
		if not is_instance_valid(body):
			continue

		if suspended:
			_body_layers[body] = body.collision_layer
			body.collision_layer = 0
		else:
			body.collision_layer = int(_body_layers.get(body, 1))
