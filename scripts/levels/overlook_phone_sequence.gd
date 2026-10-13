extends Node3D
class_name OverlookPhoneSequence

## The overlook's payphone (the Orelhao): the puzzle that uses the three fichas.
##
## Flow, started by one interaction at the booth in the world (like the doors):
## - The prompt says what the interaction will do: "Insert ficha 1" (then 2, 3) when
##   the player carries a ficha that is not in the slot yet, "Pick up Receiver" once
##   all three are in, "Examine Orelhão" otherwise. With no ficha to insert, pressing
##   it only makes Juliana say "I need some fichas...".
## - Otherwise she first walks up to the booth, slowly (the guided walk the doors use),
##   looking at it, and then keeps looking at the unit from a camera of its own. Two
##   things are offered: [E] puts the next ficha in the slot ("Insert ficha 2" once the
##   first is in; after the third, "Pick up Receiver"), and moving away (any movement
##   key, Esc or right click) steps back and returns her view. Each insertion is saved,
##   so she can go and look for the others while the inserted ones stay.
## - Picking up the receiver (off its hook) lifts it to her right ear (she is
##   right-handed). Then, without moving from where she stands, she turns her head
##   to the left and listens to Sophia's call (captions) until it ends, the booth still
##   at the right edge of the picture; the phone stays at the right ear, so the cord is
##   never stretched. Her head turns back, the receiver is lowered and left hanging on
##   its cord, and the view returns to the player, who may look but not walk until
##   `release_player()` (the next event) or `release_player_after_call_seconds` pass.
##
## The model (`OrelhaoModel`) and the cord (`CoiledCord`) only animate; every decision
## is here.

signal ficha_inserted(item_id: String, count: int)
signal receiver_picked_up
signal call_finished
## The call is over and the view is back with the player.
signal sequence_completed

enum Stage {
	IDLE,
	WALKING,
	BUSY,
	VIEWING,
	CALL,
	DONE,
}

const STATE_SECTION: StringName = &"puzzles"
const KEY_FICHAS: StringName = &"orelhao_fichas"
const KEY_CALL_DONE: StringName = &"orelhao_call_done"

const LINE_NEED_FICHAS: String = "CAPTION_JULIANA_NEED_FICHAS"

const FICHA_IDS: Array[String] = ["juliana_ficha", "lucas_ficha", "sophia_ficha"]
const FICHA_SCENES: Dictionary = {
	"juliana_ficha": "res://scenes/objects/overlook/juliana_ficha.tscn",
	"lucas_ficha": "res://scenes/objects/overlook/lucas_ficha.tscn",
	"sophia_ficha": "res://scenes/objects/waiting_shed/sophia_ficha.tscn",
}

## Where the receiver floats at her right ear, in the camera's space (x right, y up,
## -z ahead): the right edge of the picture.
const EAR_POSITION: Vector3 = Vector3(0.35, 0.0, -0.34)
## Which way the handset's own axes point in that space: +Y runs from the earpiece to
## the cord end (down and towards the middle, the earpiece up at the right ear), +Z is
## its inner face (away from the viewer: the viewer sees its back).
const EAR_Y_AXIS: Vector3 = Vector3(-0.42, -0.9, 0.0)
const EAR_Z_AXIS: Vector3 = Vector3(0.55, 0.0, -0.85)

## How far behind the close-up camera she stands (so she does not walk into the booth).
const STAND_BACK: float = 0.12
## Moving away is ignored for this long after the view comes up.
const STEP_AWAY_GRACE_SECONDS: float = 0.7

@export var model: OrelhaoModel
@export var interactable: OrelhaoInteractable
## The set round the booth; its streetlamp flickers when the voice on the line begins and
## when it ends (it burns steadily the rest of the time).
@export var lamp: OverlookPhoneDressing
## Set when the player is not the node found by group "player".
@export var player: Node3D

@export_category("Test scene")
## Puts the three fichas in the player's inventory when the scene starts (the playtest).
@export var start_with_fichas: bool = false

@export_category("Timing")
@export var camera_seconds: float = 1.1
@export var close_up_fov: float = 70.0
## How far the view leans towards the phone (to the right: the right ear).
@export var call_roll_degrees: float = 5.0
## The caption track of the call (an unknown id plays nothing, for tests).
@export var call_track: StringName = CaptionTracks.OVERLOOK_CALL
## After the call the player may look but not walk. This many seconds later they are
## let go; 0 keeps them held until `release_player()` is called (by the next event).
@export var release_player_after_call_seconds: float = 6.0

@export_category("Listening")
## During the call she turns her head this many degrees to the left of the booth and
## looks at the horizon (pitch), without moving from where she stands.
@export var call_look_yaw_degrees: float = 60.0
@export var call_look_pitch_degrees: float = 1.0
@export var call_fov: float = 68.0
@export var call_head_turn_seconds: float = 1.8

var stage: int = Stage.IDLE

var _player: Node = null
var _view_camera: Camera3D = null
var _player_camera: Camera3D = null
var _inserted: Array[String] = []
var _camera_tween: Tween = null
var _grace_left: float = 0.0

var _receiver_held: bool = false
var _held_pose: Transform3D = Transform3D.IDENTITY
## While she listens the view breathes a little round this pose.
var _call_base: Transform3D = Transform3D.IDENTITY
var _in_call_view: bool = false

var _ui_layer: CanvasLayer = null
var _prompt: KeyHint = null
var _away_hint: KeyHint = null
var _hiss: AudioStreamPlayer = null
var _sounds: Dictionary = {}


func _ready() -> void:
	_load_state()
	_build_audio()

	if model != null:
		if stage == Stage.DONE:
			model.let_hang()
		else:
			model.put_on_hook()

		if _inserted.size() >= FICHA_IDS.size():
			model.set_indicator(true, false)

	if interactable != null:
		interactable.examined.connect(_on_examined)
		interactable.prompt_provider = _get_prompt
		interactable.enabled = stage != Stage.DONE

	_prepare_player.call_deferred()


func _exit_tree() -> void:
	if _ui_layer != null and is_instance_valid(_ui_layer):
		_ui_layer.queue_free()


# ============================================================
# STATE
# ============================================================

func _load_state() -> void:
	var saved: Variant = SaveManager.get_state_value(STATE_SECTION, KEY_FICHAS, [])
	if saved is Array:
		for entry: Variant in saved as Array:
			var id: String = str(entry)
			if id in FICHA_IDS and id not in _inserted:
				_inserted.append(id)

	if bool(SaveManager.get_state_value(STATE_SECTION, KEY_CALL_DONE, false)):
		stage = Stage.DONE


func _save_fichas() -> void:
	SaveManager.set_state_value(STATE_SECTION, KEY_FICHAS, _inserted.duplicate())


func get_inserted_count() -> int:
	return _inserted.size()


func is_payment_complete() -> bool:
	return _inserted.size() >= FICHA_IDS.size()


func _prepare_player() -> void:
	_player = _get_player()
	if _player == null:
		await get_tree().process_frame
		_player = _get_player()

	if _player == null:
		push_warning("OverlookPhoneSequence: no player found.")
		return

	if start_with_fichas:
		_give_fichas_to_player()


func _get_player() -> Node:
	if player != null:
		return player

	return get_tree().get_first_node_in_group(&"player")


## Puts the three fichas in the inventory, as the playtest wants (in the game they come
## from the other puzzles).
func _give_fichas_to_player() -> void:
	for id: String in FICHA_IDS:
		if id in _inserted or bool(_player.call("has_inventory_item", id)):
			continue

		var scene: PackedScene = load(str(FICHA_SCENES[id])) as PackedScene
		var root: Node = scene.instantiate()
		var visual: Node3D = (root.get_node("Visual") as Node3D).duplicate() as Node3D
		var item_name: String = str(root.get("item_name"))
		var item_description: String = str(root.get("item_description"))
		root.free()
		_player.call("add_item_to_inventory", id, item_name, item_description, visual, scene.resource_path)


## The first ficha the player carries that is not in the slot yet ("" if none).
func get_next_ficha() -> String:
	var holder: Node = _get_player()
	if holder == null:
		return ""

	for id: String in FICHA_IDS:
		if id not in _inserted and bool(holder.call("has_inventory_item", id)):
			return id

	return ""


## What the booth's prompt says right now (see `OrelhaoInteractable`).
func _get_prompt() -> String:
	if is_payment_complete():
		return "PROMPT_PICK_UP_RECEIVER"

	if not get_next_ficha().is_empty():
		return tr("PROMPT_INSERT_FICHA") % (_inserted.size() + 1)

	return "PROMPT_EXAMINE_ORELHAO"


# ============================================================
# USING THE BOOTH
# ============================================================

func _on_examined(by: Node) -> void:
	use_booth(by)


## What pressing the interact key at the booth does (see the header). Await it.
func use_booth(by: Node = null) -> void:
	if stage != Stage.IDLE:
		return

	if by != null:
		_player = by

	if _player == null or model == null:
		return

	if not is_payment_complete() and get_next_ficha().is_empty():
		CaptionManager.say(LINE_NEED_FICHAS)
		return

	await _walk_to_booth()
	await _enter_view()

	if is_payment_complete():
		await pick_up_receiver()
		return

	_offer_choices()


## While the view is up: [E] does what the prompt says, moving away leaves.
func _input(event: InputEvent) -> void:
	if stage != Stage.VIEWING:
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_use_interaction()
		return

	if _grace_left > 0.0:
		return

	var moving: bool = false
	for action: String in ["left", "right", "up", "down"]:
		if event.is_action_pressed(action):
			moving = true

	if (
		moving
		or event.is_action_pressed("ui_cancel")
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	):
		get_viewport().set_input_as_handled()
		step_away()


## [E] in the view: the next ficha, or the receiver once all are in. Await it.
func _use_interaction() -> void:
	if stage != Stage.VIEWING:
		return

	if is_payment_complete():
		_hide_hints()
		await pick_up_receiver()
		return

	var id: String = get_next_ficha()
	if id.is_empty():
		return

	_hide_hints()
	await insert_ficha(id)

	if not is_payment_complete() and get_next_ficha().is_empty():
		CaptionManager.say(LINE_NEED_FICHAS)

	_offer_choices()


## Leaves the booth: the view returns to the player. Await it.
func step_away() -> void:
	if stage != Stage.VIEWING:
		return

	_hide_hints()
	await _exit_view()


## Shows what can be done now (see `_refresh_hints`) and waits for the player's input.
func _offer_choices() -> void:
	stage = Stage.VIEWING
	_grace_left = STEP_AWAY_GRACE_SECONDS
	_refresh_hints()


# ============================================================
# WALKING UP, THE CLOSE-UP CAMERA
# ============================================================

## Where she stands to use the unit: just behind the close-up camera, on the ground.
func get_standing_spot() -> Vector3:
	var marker: Transform3D = model.close_up_camera.global_transform
	var back: Vector3 = marker.basis.z
	back.y = 0.0
	var spot: Vector3 = marker.origin + back.normalized() * STAND_BACK
	spot.y = (_player as Node3D).global_position.y
	return spot


## She walks up to the booth, slowly and looking at it, unless she is already there.
## Await it.
func _walk_to_booth() -> void:
	var movement: Node = _player.get("movement_controller") as Node
	var spot: Vector3 = get_standing_spot()
	var here: Vector3 = (_player as Node3D).global_position
	var distance: float = Vector2(spot.x - here.x, spot.z - here.z).length()

	if movement == null or distance < 0.12:
		return

	stage = Stage.WALKING
	var speed: float = PlayerMovementController.WALK_SPEED * 0.8
	if bool(movement.call("begin_guided_walk", spot, model.plate.global_position, speed, distance / speed * 1.6 + 1.5)):
		await movement.guided_walk_finished


## Takes the player's view to the faceplate. Await it.
func _enter_view() -> void:
	stage = Stage.BUSY
	_player.call("set_view_locked", true)

	_player_camera = _player.get_node("Head/Camera3D") as Camera3D
	_view_camera = Camera3D.new()
	_view_camera.name = "PhoneViewCamera"
	add_child(_view_camera)
	_view_camera.global_transform = _player_camera.global_transform
	_view_camera.fov = _player_camera.fov
	_view_camera.near = _player_camera.near
	_view_camera.far = _player_camera.far
	_view_camera.attributes = _make_view_attributes()
	_view_camera.make_current()

	_build_hints()
	await _fly_camera(model.close_up_camera.global_transform, close_up_fov, camera_seconds)


## Gives the view back to the player. Await it.
func _exit_view() -> void:
	var finished_call: bool = _call_done()
	stage = Stage.BUSY

	await _fly_camera(_player_camera.global_transform, _player_camera.fov, camera_seconds)

	_player_camera.make_current()
	_view_camera.queue_free()
	_view_camera = null

	_player.call("set_view_locked", false)
	stage = Stage.DONE if finished_call else Stage.IDLE


func _call_done() -> bool:
	return bool(SaveManager.get_state_value(STATE_SECTION, KEY_CALL_DONE, false))


## Flies the view camera to `target` (leaning `roll_degrees` to the left). Await it.
func _fly_camera(target: Transform3D, fov: float, seconds: float, roll_degrees: float = 0.0) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()

	var start: Transform3D = _view_camera.global_transform
	var start_fov: float = _view_camera.fov
	var leaning: Transform3D = Transform3D(
		target.basis * Basis(Vector3.BACK, deg_to_rad(roll_degrees)), target.origin
	)
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(
		func(t: float) -> void:
			if is_instance_valid(_view_camera):
				_view_camera.global_transform = start.interpolate_with(leaning, t)
				_view_camera.fov = lerpf(start_fov, fov, t),
		0.0, 1.0, seconds
	)
	await _camera_tween.finished


## The booth is in focus, the valley behind it soft (the player's own option applies).
func _make_view_attributes() -> CameraAttributesPractical:
	var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = GameSettings.get_depth_of_field_enabled()
	attributes.dof_blur_far_distance = 1.5
	attributes.dof_blur_far_transition = 4.0
	attributes.dof_blur_amount = 0.12
	return attributes


## Looking far away, the horizon is in focus; looking at the booth, the valley is soft.
func _set_far_blur(on: bool) -> void:
	var attributes: CameraAttributesPractical = _view_camera.attributes as CameraAttributesPractical
	if attributes != null:
		attributes.dof_blur_far_enabled = on and GameSettings.get_depth_of_field_enabled()


# ============================================================
# THE CHOICES ON SCREEN
# ============================================================

func _build_hints() -> void:
	if _ui_layer != null:
		_ui_layer.queue_free()

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "PhoneBoothHints"
	_ui_layer.layer = 9
	add_child(_ui_layer)

	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root)

	_prompt = KeyHint.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.modulate.a = 0.0
	root.add_child(_prompt)

	_away_hint = KeyHint.new()
	_away_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_away_hint.modulate.a = 0.0
	root.add_child(_away_hint)

	if not get_viewport().size_changed.is_connected(_refresh_hints):
		get_viewport().size_changed.connect(_refresh_hints)


func _hide_hints() -> void:
	if _prompt == null:
		return

	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(_prompt, "modulate:a", 0.0, 0.2)
	fade.tween_property(_away_hint, "modulate:a", 0.0, 0.2)


## "[E] Insert ficha 2" (or "Pick up Receiver") when there is something to do, and
## always the way to step away.
func _refresh_hints() -> void:
	if _prompt == null or _player == null or stage != Stage.VIEWING:
		return

	var screen: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = maxi(int(screen.y * 0.026), 15)
	var font: Font = null
	var inspect: PlayerInspectController = _player.get("inspect_controller") as PlayerInspectController
	if inspect != null:
		font = inspect.get_ui_font(false)

	var text: String = ""
	if is_payment_complete():
		text = tr("PROMPT_PICK_UP_RECEIVER")
	elif not get_next_ficha().is_empty():
		text = tr("PROMPT_INSERT_FICHA") % (_inserted.size() + 1)

	if text.is_empty():
		_prompt.visible = false
	else:
		_prompt.visible = true
		_prompt.set_hint(InputBindings.get_binding_label(&"interact", -1, true), text, font_size, font)
		_prompt.position = Vector2((screen.x - _prompt.size.x) * 0.5, screen.y * 0.86)

	var keys: String = ""
	for action: StringName in [&"up", &"left", &"down", &"right"]:
		keys += InputBindings.get_binding_label(action, -1, true)

	_away_hint.set_hint(keys, tr("OVERLOOK_PHONE_STEP_AWAY"), font_size, font)
	_away_hint.position = Vector2(screen.x - _away_hint.size.x - screen.x * 0.04, screen.y * 0.93)

	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(_prompt, "modulate:a", 1.0, 0.25)
	fade.tween_property(_away_hint, "modulate:a", 1.0, 0.25)


# ============================================================
# THE FICHAS
# ============================================================

## Drops the ficha `item_id` from the inventory into the coin slot (the close-up camera
## is up). Await it.
func insert_ficha(item_id: String) -> void:
	if item_id not in FICHA_IDS or item_id in _inserted:
		return

	var visual: Node3D = _take_ficha_visual(item_id)
	if visual == null:
		return

	stage = Stage.BUSY
	_play(&"knock", -10.0)
	await model.drop_ficha(visual)
	_play(&"click", -8.0)
	_play(&"coin", -9.0)

	_inserted.append(item_id)
	_save_fichas()
	ficha_inserted.emit(item_id, _inserted.size())

	if is_payment_complete():
		await get_tree().create_timer(0.35).timeout
		model.set_indicator(true, true)
		_play(&"clunk", -6.0)
		await get_tree().create_timer(0.9).timeout
	else:
		await get_tree().create_timer(0.6).timeout


## Takes the ficha out of the inventory and returns a copy of its model for the slot.
func _take_ficha_visual(item_id: String) -> Node3D:
	var inventory: PlayerInventoryController = _player.get("inventory_controller") as PlayerInventoryController
	if inventory == null or not inventory.has_item(item_id):
		return null

	var visual: Node3D = null
	for slot_data: Dictionary in inventory.get_slots():
		if str(slot_data.get("id", "")) == item_id:
			var template: Node3D = slot_data.get("inspect_visual_template") as Node3D
			if template != null and is_instance_valid(template):
				visual = template.duplicate() as Node3D

	_player.call("consume_inventory_item", item_id)

	if visual == null:
		# No model came with the item: build the stand-in.
		var scene: PackedScene = load(str(FICHA_SCENES[item_id])) as PackedScene
		var root: Node = scene.instantiate()
		visual = (root.get_node("Visual") as Node3D).duplicate() as Node3D
		root.free()

	return visual


# ============================================================
# THE CALL
# ============================================================

## The receiver comes off its hook and floats to her right ear (the arm is for the real
## model to supply); she turns her head to the left, in place, and listens to the call;
## her head turns back, the receiver goes back down, hanging on its cord. The close-up
## camera is up. Await it.
func pick_up_receiver() -> void:
	stage = Stage.CALL
	_hide_hints()
	receiver_picked_up.emit()

	var receiver: Node3D = model.receiver
	model.take_off_hook()
	_play(&"knock", -8.0)

	# Off the hook and up, with her eyes on it.
	var start: Transform3D = _view_camera.global_transform.affine_inverse() * receiver.global_transform
	var ear: Transform3D = _ear_pose()
	_receiver_held = true
	var lift: Tween = create_tween()
	lift.tween_method(_move_receiver.bind(start, ear), 0.0, 1.0, 1.5)
	await lift.finished
	_held_pose = ear
	await get_tree().create_timer(0.3).timeout

	# She turns her head to the left and looks at the horizon, still where she stands,
	# the phone at her right ear and the booth at the right edge of the picture.
	_set_far_blur(false)
	_call_base = _call_view_transform()
	await _fly_camera(_call_base, call_fov, call_head_turn_seconds, -call_roll_degrees)
	_call_base = Transform3D(_call_base.basis * Basis(Vector3.BACK, deg_to_rad(-call_roll_degrees)), _call_base.origin)
	_in_call_view = true

	# The voice begins: the lamp sputters and dies for a long moment, then burns on.
	_start_hiss()
	if lamp != null:
		lamp.play_flicker(&"start")

	await CaptionManager.play_scripted_and_wait(call_track)
	_stop_hiss()

	# The voice ends: the lamp stutters again, and goes dark once more, before it settles.
	if lamp != null:
		lamp.play_flicker(&"end")

	await get_tree().create_timer(0.7).timeout

	# Her head turns back to the booth as the receiver is lowered and let go.
	_in_call_view = false
	_set_far_blur(true)
	var back: Tween = create_tween().set_parallel(true)
	var close_up: Transform3D = model.close_up_camera.global_transform
	var from_camera: Transform3D = _view_camera.global_transform
	var from_fov: float = _view_camera.fov
	back.tween_method(
		func(t: float) -> void:
			var eased: float = ease(t, -2.0)
			_view_camera.global_transform = from_camera.interpolate_with(close_up, eased)
			_view_camera.fov = lerpf(from_fov, close_up_fov, eased),
		0.0, 1.0, 2.0
	)
	back.tween_method(_return_receiver.bind(ear), 0.0, 1.0, 2.0)
	await back.finished

	_receiver_held = false
	model.let_hang()
	_play(&"knock", -10.0)
	model.swing_receiver()
	await get_tree().create_timer(1.1).timeout

	SaveManager.set_state_value(STATE_SECTION, KEY_CALL_DONE, true)
	if interactable != null:
		interactable.enabled = false

	call_finished.emit()
	await _exit_view()
	_player.call("hold_movement", 3600.0)
	sequence_completed.emit()

	if release_player_after_call_seconds > 0.0:
		await get_tree().create_timer(release_player_after_call_seconds).timeout
		release_player()


## Where the camera is while she listens: the very same place as when she looked at the
## unit, the head turned to the left (and level, looking far away).
func _call_view_transform() -> Transform3D:
	var marker: Transform3D = model.close_up_camera.global_transform
	var facing: Vector3 = -marker.basis.z
	facing.y = 0.0
	facing = facing.normalized()

	var look: Vector3 = Basis(Vector3.UP, deg_to_rad(call_look_yaw_degrees)) * facing
	look.y = tan(deg_to_rad(call_look_pitch_degrees))
	return Transform3D(Basis.looking_at(look.normalized(), Vector3.UP), marker.origin)


## Where the receiver floats at her right ear, in the camera's space, at the size it
## has in the booth.
func _ear_pose() -> Transform3D:
	var y_axis: Vector3 = EAR_Y_AXIS.normalized()
	var z_axis: Vector3 = (EAR_Z_AXIS - y_axis * EAR_Z_AXIS.dot(y_axis)).normalized()
	var x_axis: Vector3 = y_axis.cross(z_axis)
	var size: float = model.global_basis.get_scale().x
	return Transform3D(Basis(x_axis, y_axis, z_axis).scaled(Vector3.ONE * size), EAR_POSITION)


## Moves the floating receiver along a gentle arc from `from` to `to` (both in the view
## camera's space); it comes off the hook with a small lift.
func _move_receiver(t: float, from: Transform3D, to: Transform3D) -> void:
	if _view_camera == null:
		return

	var eased: float = ease(t, -2.0)
	var local: Transform3D = from.interpolate_with(to, eased)
	local.origin += Vector3(0.0, sin(eased * PI) * 0.05, 0.0)
	model.receiver.global_transform = _view_camera.global_transform * local


## The way back: towards the hanging pose (followed as the camera moves).
func _return_receiver(t: float, from: Transform3D) -> void:
	if _view_camera == null:
		return

	var hang_world: Transform3D = model.global_transform * model.get_receiver_home()
	var hang_local: Transform3D = _view_camera.global_transform.affine_inverse() * hang_world
	var eased: float = ease(t, -2.0)
	var local: Transform3D = from.interpolate_with(hang_local, eased)
	local.origin += Vector3(0.0, sin(eased * PI) * 0.03, 0.0)
	model.receiver.global_transform = _view_camera.global_transform * local


func _process(delta: float) -> void:
	_grace_left = maxf(_grace_left - delta, 0.0)

	# The light on the unit goes out with the street lamp.
	if lamp != null and model != null:
		model.set_fill_scale(lamp.get_lamp_level())

	if stage != Stage.CALL or _view_camera == null or not _in_call_view:
		return

	var now: float = Time.get_ticks_msec() / 1000.0

	# She breathes and shifts her gaze a little as she listens.
	var drift: Basis = Basis.from_euler(Vector3(sin(now * 0.45) * 0.006, sin(now * 0.31 + 1.0) * 0.012, 0.0))
	_view_camera.global_transform = Transform3D(
		_call_base.basis * drift, _call_base.origin + Vector3(0.0, sin(now * 0.9) * 0.004, 0.0)
	)

	# The receiver trembles a little, as a hand holds it.
	if _receiver_held and _held_pose != Transform3D.IDENTITY:
		var tremble: Vector3 = Vector3(sin(now * 1.7), sin(now * 2.3 + 1.0), sin(now * 1.1 + 2.0)) * 0.0025
		var tilt: Basis = Basis.from_euler(Vector3(sin(now * 1.3), sin(now * 0.9), sin(now * 1.9)) * 0.012)
		var pose: Transform3D = Transform3D(tilt * _held_pose.basis, _held_pose.origin + tremble)
		model.receiver.global_transform = _view_camera.global_transform * pose


## Lets the player walk again (the event that follows the call has finished).
func release_player() -> void:
	if _player != null:
		_player.call("release_movement_hold")


# ============================================================
# SOUND (placeholders)
# ============================================================

func _build_audio() -> void:
	_sounds = {
		&"click": PlaceholderAudio.make_click(),
		&"clunk": PlaceholderAudio.make_clunk(),
		&"coin": PlaceholderAudio.make_coin_clatter(),
		&"knock": PlaceholderAudio.make_receiver_knock(),
	}

	_hiss = AudioStreamPlayer.new()
	_hiss.name = "LineHiss"
	_hiss.stream = PlaceholderAudio.make_line_hiss()
	_hiss.volume_db = -22.0
	add_child(_hiss)


func _play(sound: StringName, volume_db: float = -6.0) -> void:
	var stream: AudioStream = _sounds.get(sound) as AudioStream
	if stream == null:
		return

	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.stream = stream
	voice.volume_db = volume_db
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()


func _start_hiss() -> void:
	if _hiss != null:
		_hiss.play()


func _stop_hiss() -> void:
	if _hiss != null:
		_hiss.stop()
