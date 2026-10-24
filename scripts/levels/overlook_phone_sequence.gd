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
## The voice has stopped and the line is cut. With `finale_takes_over` the view stays on the city (still
## pushing in) and `DreamFinale` goes on from here; see `end_view_in_the_dark`.
signal line_cut
## The call is about to end (`seconds_left` before its last caption does): the town's lights start going out.
signal call_ending(seconds_left: float)

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

@export_category("Transition sound")
## The horror sound under the end of the call, when the finale takes the call over (the town goes dark, then the wagon).
## It is played so that its LAST moment is the last moment of the dialogue: it starts this long before the last caption
## ends (its own length), so the end of the sound meets the end of the dialogue, just before the cut to the wagon.
@export var transition_audio: AudioStream = preload("res://assets/audios/placeholder_horror_transition.mp3")
@export var transition_volume_db: float = 0.0

@export_category("Timing")
@export var camera_seconds: float = 1.1
@export var close_up_fov: float = 70.0
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
## The slow push-in on the city that starts with the voice and goes on until the lights go out: the view ends
## this narrow, `call_zoom_extra_seconds` after the last caption of the call (still far from the city).
@export var call_zoom_fov: float = 31.0

@export_category("Cinematic shot")
## While Sophia speaks the picture is a cutscene, not the player's eyes: a camera behind and above where she
## stands, looking out over the fence at the whole town (the way she looked at it), wide at first, with
## letterbox bars, then pushing in slowly.
@export var shot_height: float = 1.6
@export var shot_back: float = 1.6
@export var shot_pitch_degrees: float = -5.0
## The view is turned this many degrees from where she looked at the town (negative: back towards the booth)
## so that the middle of the town is the middle of the picture.
@export var shot_yaw_offset_degrees: float = -26.0
@export var shot_fov: float = 58.0
@export var call_zoom_extra_seconds: float = 0.4
## The call is near its end this many seconds before its last caption ends: `call_ending` tells the finale, which
## then puts the town's lights out one by one.
@export var call_ending_lead_seconds: float = 7.0

var stage: int = Stage.IDLE

var _player: Node = null
var _view_camera: Camera3D = null
var _player_camera: Camera3D = null
var _inserted: Array[String] = []
var _camera_tween: Tween = null
var _grace_left: float = 0.0

## While she listens the view breathes a little round this pose.
var _call_base: Transform3D = Transform3D.IDENTITY
var _in_call_view: bool = false
## Set by the finale: the call does not turn back to the booth and give the view back; the view stays on the
## city, zooming, until the finale ends it in the dark.
var finale_takes_over: bool = false
var _zoom_on: bool = false
var _zoom_elapsed: float = 0.0
var _zoom_total: float = 1.0
var _zoom_start_fov: float = 58.0

## The transition sound's player (made when it starts; the tests look at it).
var transition_player: AudioStreamPlayer = null

var _ui_layer: CanvasLayer = null
var _prompt: KeyHint = null
var _away_hint: KeyHint = null
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

	# The press is taken at once (the stage changes before anything is awaited): a second press, a frame later, must find the booth busy.
	if is_payment_complete():
		stage = Stage.BUSY
		_hide_hints()
		await pick_up_receiver()
		return

	var id: String = get_next_ficha()
	if id.is_empty():
		return

	stage = Stage.BUSY
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

	# (Through `UiFade`: a hide a few frames after a show must replace the show, not run beside it: the longer fade-in used to finish
	# last and put the hints back on screen over the call.)
	UiFade.to(_prompt, 0.0, 0.2)
	UiFade.to(_away_hint, 0.0, 0.2)


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

	UiFade.to(_prompt, 1.0, 0.25)
	UiFade.to(_away_hint, 1.0, 0.25)


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


## Picking up the receiver is not shown: the picture simply cuts to a cinematic shot of the town at night,
## its centre in the middle of the frame, with letterbox bars, and the slow push-in starts with the voice (no
## handset animation, no lamp flicker). When the voice has stopped the line is cut; with `finale_takes_over`
## the shot stays and the finale goes on from here, otherwise the view goes back to the booth and the
## receiver is left hanging on its cord. Await it.
func pick_up_receiver() -> void:
	stage = Stage.CALL
	_hide_hints()
	receiver_picked_up.emit()

	# The cut: the shot, the bars sliding in, and the far view sharp.
	_set_far_blur(false)
	_call_base = _cinematic_shot()
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()

	_view_camera.global_transform = _call_base
	_view_camera.fov = shot_fov
	_in_call_view = true
	_start_zoom()
	_announce_the_end()
	_play_transition_audio()

	await CaptionManager.play_scripted_and_wait(call_track)

	# The line is cut at the other end: a soft, hollow click (not when the finale takes over: the last light
	# going out is silent).
	if not finale_takes_over:
		_play(&"disconnect", -8.0)

	await get_tree().create_timer(0.35).timeout

	if finale_takes_over:
		# The shot stays, still pushing in, while the lights go out: the finale takes it from here.
		SaveManager.set_state_value(STATE_SECTION, KEY_CALL_DONE, true)
		if interactable != null:
			interactable.enabled = false

		call_finished.emit()
		line_cut.emit()
		return

	_zoom_on = false
	_in_call_view = false
	_set_far_blur(true)
	await _fly_camera(model.close_up_camera.global_transform, close_up_fov, 1.0)

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


## How long after the call starts the transition sound starts, so that it ends with the dialogue: the end of the last
## caption less the sound's own length (at once, when the dialogue is shorter than the sound).
func get_transition_delay() -> float:
	if transition_audio == null:
		return 0.0

	var last_end: float = 0.0
	for cue: Dictionary in CaptionTracks.get_cues(call_track):
		last_end = maxf(last_end, float(cue["end"]))

	return maxf(last_end - transition_audio.get_length(), 0.0)


## Starts the transition sound at the moment that makes it end with the dialogue (only for the call the finale takes
## over: the one that ends with the town going dark and the cut to the wagon).
func _play_transition_audio() -> void:
	if not finale_takes_over or transition_audio == null:
		return

	var delay: float = get_transition_delay()
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout

	if stage != Stage.CALL or not _in_call_view:
		return

	transition_player = AudioStreamPlayer.new()
	transition_player.name = "TransitionSound"
	transition_player.stream = transition_audio
	transition_player.volume_db = transition_volume_db
	add_child(transition_player)
	transition_player.play()


## Waits until the call is near its end and says so (`call_ending`).
func _announce_the_end() -> void:
	var last_end: float = 0.0
	for cue: Dictionary in CaptionTracks.get_cues(call_track):
		last_end = maxf(last_end, float(cue["end"]))

	var lead: float = minf(call_ending_lead_seconds, last_end)
	await get_tree().create_timer(maxf(last_end - lead, 0.0), false).timeout
	if stage == Stage.CALL and _in_call_view:
		call_ending.emit(lead)


## Starts the slow push-in on the city (it goes on to the end of the call and past it).
func _start_zoom() -> void:
	var last_end: float = 0.0
	for cue: Dictionary in CaptionTracks.get_cues(call_track):
		last_end = maxf(last_end, float(cue["end"]))

	_zoom_total = maxf(last_end + call_zoom_extra_seconds, 1.0)
	_zoom_start_fov = _view_camera.fov
	_zoom_elapsed = 0.0
	_zoom_on = true


## The finale calls this once everything is dark: the view goes back to the player at once, and the
## receiver is left hanging on its cord.
func end_view_in_the_dark() -> void:
	if _view_camera == null:
		return

	_zoom_on = false
	_in_call_view = false
	model.receiver.visible = true
	model.let_hang()
	_player_camera.make_current()
	_view_camera.queue_free()
	_view_camera = null
	_player.call("set_view_locked", false)
	_player.call("hold_movement", 3600.0)
	stage = Stage.DONE
	sequence_completed.emit()



## The cutscene camera: behind and above where she stands, looking the way she looked at the town.
func _cinematic_shot() -> Transform3D:
	var base: Transform3D = _call_view_transform()
	var forward: Vector3 = -base.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin: Vector3 = base.origin + Vector3.UP * shot_height - forward * shot_back
	var look: Vector3 = Basis(Vector3.UP, deg_to_rad(shot_yaw_offset_degrees)) * forward
	look.y = tan(deg_to_rad(shot_pitch_degrees))
	return Transform3D(Basis.looking_at(look.normalized(), Vector3.UP), origin)


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


func _process(delta: float) -> void:
	_grace_left = maxf(_grace_left - delta, 0.0)

	# A safety net: the hints are only ever on screen while the view is up and waiting for the player; whatever else may have left them
	# showing, they are put out as soon as nothing is fading them.
	if stage != Stage.VIEWING:
		for hint: KeyHint in [_prompt, _away_hint]:
			if hint != null and hint.modulate.a > 0.0 and not UiFade.is_fading(hint):
				hint.modulate.a = 0.0

	# The light on the unit goes out with the street lamp.
	if lamp != null and model != null:
		model.set_fill_scale(lamp.get_lamp_level())

	if _zoom_on and _view_camera != null:
		_zoom_elapsed += delta
		_view_camera.fov = lerpf(_zoom_start_fov, call_zoom_fov, clampf(_zoom_elapsed / _zoom_total, 0.0, 1.0))

	if stage != Stage.CALL or _view_camera == null or not _in_call_view:
		return

	var now: float = Time.get_ticks_msec() / 1000.0

	# She breathes and shifts her gaze a little as she listens.
	var drift: Basis = Basis.from_euler(Vector3(sin(now * 0.45) * 0.006, sin(now * 0.31 + 1.0) * 0.012, 0.0))
	_view_camera.global_transform = Transform3D(
		_call_base.basis * drift, _call_base.origin + Vector3(0.0, sin(now * 0.9) * 0.004, 0.0)
	)


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
		&"disconnect": PlaceholderAudio.make_disconnect_click(),
	}


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
