extends Collectible
class_name PinnedCollectible

## A collectible that hangs on a board by pins (the trail map): taking it is a scene, not a click.
##
##   1. Pressing the key walks the player up to the board, slowly, looking at the paper, as they are walked up to a door (`begin_guided_walk`).
##   2. The view is held there and zoomed until the paper nearly fills the screen (the lens narrows, as if the player had put their face to it), so
##      it can be read where it hangs; a row at the bottom says "[E] Collect" and "[Esc] Back" (`CollectPrompt`). Back lets go of the view
##      and leaves the map where it is. The flashlight is taken over as the view is (see `_take_over_light`): lit and steady on the paper,
##      brought up gently if it was off, so pressing the key later changes nothing about the light: no flicker.
##   3. Collect: the player RIPS the map off the board, with the view held exactly as it was framed (the lens stays closed in on the paper, and
##      nothing shakes the camera): the two top pins are worked out of the wood (each tugged, twisted, tugged again, then out with a jerk) and go
##      to the player's pocket, the top of the paper sags, it is yanked down and torn free of the bottom two pins (they stay in the board, each
##      with a scrap of the paper), and the torn paper whips up to the player's hands, flat and facing them, the lens opening again as it comes.
##   4. The map is not an item of the inventory: it is the player map, opened with its own key (`PlayerMapController`, "M" by
##      default), like the flashlight is a tool and not a thing in a pocket. The view shows it open, flying from where the hands hold it, as it
##      was on the board: it folds only when the player closes it, and comes out folded and opens out the next time. The lesson of the map key
##      is started (`TutorialHintController`).
##
## The game shows no hands anywhere, so none are shown here: the pins and the paper move as if held. The rip is one function of time
## (`pose_removal(t)`), played by a tween, so a test can look at any moment of it.

signal examine_started
## The close up is ready: the row is up and the player can collect.
signal framed
signal declined
signal removal_started
signal removal_finished

enum Stage { IDLE, WALKING, FRAMING, TAKING }

## How far in front of the paper the player stands to look at it (horizontally, from the paper's middle), and how long the view rests there
## before the row comes up.
const EXAMINE_DISTANCE: float = 0.75
const FRAME_SETTLE_SECONDS: float = 0.5
const WALK_TIMEOUT_SECONDS: float = 3.0
## The paper fills this much of the screen while it is looked at (the lens zooms to it), and how long the lens takes to close in and open.
const FRAME_FILL: float = 0.8
const ZOOM_IN_SECONDS: float = 0.8
const ZOOM_OUT_SECONDS: float = 0.5
## A flashlight that was off comes up (and goes down) over this long, rather than popping.
const LIGHT_FADE_SECONDS: float = 0.45

## When each of the two top pins starts to be worked out (in the order of `pins`: top left, top right). A pin is tugged for
## `PIN_STRUGGLE_SECONDS`, then carried to the pocket for `PIN_CARRY_SECONDS`.
const PIN_START: Array[float] = [0.6, 1.1]
const PIN_STRUGGLE_SECONDS: float = 0.55
const PIN_CARRY_SECONDS: float = 0.3
## How far a pin is drawn straight out of the wood when it comes, and how far it is tugged before that.
const PIN_PULL: float = 0.045
const PIN_TUG: float = 0.01
## The top of the paper sags once both top pins are out; then it is yanked; the paper tears free of the bottom pins in the yank.
const PEEL_AT: float = 1.95
const PEEL_SECONDS: float = 0.6
const YANK_AT: float = 2.65
const YANK_SECONDS: float = 0.32
const TEAR_AT: float = 2.85
## It is lifted to the hands from `GRAB_AT`.
const GRAB_AT: float = 2.9
const GRAB_SECONDS: float = 0.85
## How far the paper is peeled off the board, bent at the middle, and tilted from the bottom edge, at the end of the sag and at the
## end of the yank.
const PEEL_TILT_DEGREES: float = 26.0
const PEEL_CURL_DEGREES: float = 38.0
const YANK_TILT_DEGREES: float = 64.0
const YANK_CURL_DEGREES: float = 46.0
const SAG: float = 0.04
## Where the paper is held in front of the camera, and how it is tilted there.
const HAND_DISTANCE: float = 0.46
const HAND_DROP: float = 0.03
const HAND_TILT_DEGREES: float = -8.0
const HAND_ROLL_DEGREES: float = 3.0
## Where the pins go: below the view, a little to the right, where the hands would put them in a pocket.
const POCKET: Vector3 = Vector3(0.14, -0.3, -0.38)
## The beam follows the paper this much faster than it usually follows the view.
const BEAM_SPEED: float = 3.0

## How long the rip takes, in seconds, before the item is handed to the inspect view.
@export var removal_seconds: float = 3.9

## The pins that hold it, which the board hands over when the item is mounted: the first two are the top ones, which are pulled out;
## the last two are the bottom ones, which keep a scrap of the paper when it tears.
var pins: Array[Node3D] = []
var stage: Stage = Stage.IDLE
## True from the moment the key is pressed until the map is in the inventory (or the player has stepped back).
var is_being_removed: bool = false
var collect_prompt: CollectPrompt = null

var _player: Node = null
var _camera: Camera3D = null
var _movement: Node = null
var _flashlight: Node = null
var _flashlight_was_on: bool = false
var _light_taken: bool = false
var _view_locked: bool = false
var _sheet: FoldingSheet = null
var _home: Transform3D = Transform3D.IDENTITY
var _pivot: Vector3 = Vector3.ZERO
var _pin_homes: Array[Transform3D] = []
var _pin_frame: Node3D = null
var _pin_pull: Vector3 = Vector3.BACK
var _frame_wait: float = 0.0
## How wide the lens was closed to for the close up (0 before there was one): the rip holds it, and opens it as the paper goes to the hands.
var _framed_fov: float = 0.0
var _zoom_tween: Tween = null
var _light_tween: Tween = null


func can_interact(player: Node) -> bool:
	return stage == Stage.IDLE and not is_being_removed and player != null


## The key: walk up to the map and look at it close, with the choice to collect it or step back.
func interact(player: Node) -> void:
	if stage != Stage.IDLE or player == null:
		return

	# Without a view to show it to (a test fixture without a camera) it is simply given.
	if not begin_examine(player):
		_give_map(player)
		return


## Starts the close up. Returns false when there is no view to do it in.
func begin_examine(player: Node) -> bool:
	_camera = _find_camera(player)
	_sheet = get_node_or_null("Visual/Sheet") as FoldingSheet
	if _camera == null or _sheet == null or not is_inside_tree():
		return false

	_player = player
	_movement = player.get("movement_controller") as Node
	stage = Stage.WALKING
	is_being_removed = true
	_home = global_transform
	if not tree_exiting.is_connected(_release_player):
		tree_exiting.connect(_release_player)

	examine_started.emit()
	var stand: Vector3 = _stand_point()
	var walking: bool = false
	if _movement != null and _movement.has_method("begin_guided_walk") and Vector2(stand.x - _player_body().global_position.x, stand.z - _player_body().global_position.z).length() > 0.12:
		walking = bool(_movement.call("begin_guided_walk", stand, global_position, PlayerMovementController.WALK_SPEED * 0.8, WALK_TIMEOUT_SECONDS))

	if not walking:
		_arrive()

	return true


func _process(delta: float) -> void:
	match stage:
		Stage.WALKING:
			if _movement == null or not bool(_movement.call("is_guided_walking")):
				_arrive()

		Stage.FRAMING:
			if _frame_wait > 0.0:
				_frame_wait -= delta
				if _frame_wait <= 0.0:
					_show_prompt()


func _input(event: InputEvent) -> void:
	if stage != Stage.FRAMING or _frame_wait > 0.0:
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		collect()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		decline()


## Steps back: the view is given back and the map stays where it hangs.
func decline() -> void:
	if stage != Stage.FRAMING:
		return

	_hide_prompt()
	_zoom_to(PlayerMovementController.BASE_FOV, ZOOM_OUT_SECONDS)
	_release_player(true)
	stage = Stage.IDLE
	is_being_removed = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	declined.emit()


## Collects it: the rip, then the player has the map and the view shows it open.
func collect() -> void:
	if stage != Stage.FRAMING:
		return

	_hide_prompt()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	stage = Stage.TAKING
	# The frame is kept for the rip: the lens stays closed in on the paper and the view stays where it is (it opens as the paper is lifted away,
	# see `_pose_view`). The light is already on the paper: nothing is switched here.
	begin_removal(_player)
	var tween: Tween = create_tween()
	tween.tween_method(pose_removal, 0.0, removal_seconds, removal_seconds)
	await tween.finished
	var player: Node = _player
	end_removal(true)
	# (The level may have been left while it played: then there is no one to give it to.)
	if is_instance_valid(player):
		_give_map(player)

	stage = Stage.IDLE


## The player has the map: it is theirs from now on (kept in the saved game, so the board stays bare), shown to them open from where the
## hands hold it, and the lesson of its key is started. It does not go into the inventory.
func _give_map(player: Node) -> void:
	if SaveManager.has_active_game():
		SaveManager.set_state_value(&"collectibles", StringName(item_id), true)

	var maps: Object = player.get("map_controller") as Object
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if maps != null:
		maps.call("give_map")
		maps.call("open", visual.global_transform if visual != null else global_transform, true)

	_start_map_tutorial(player)
	queue_free()


## Where the player stands to look at the paper: in front of it, on the side it faces, at its own height.
func _stand_point() -> Vector3:
	var normal: Vector3 = global_transform.basis.z
	normal.y = 0.0
	normal = normal.normalized()
	var body: Node3D = _player_body()
	var point: Vector3 = global_position + normal * EXAMINE_DISTANCE
	point.y = body.global_position.y
	return point


func _player_body() -> Node3D:
	return _player as Node3D


## They are there (walked, or already close): the view is held, turned on the paper, and the row comes up once it has settled.
func _arrive() -> void:
	if stage != Stage.WALKING:
		return

	if _movement != null and bool(_movement.call("is_guided_walking")):
		_movement.call("cancel_guided_walk")

	_lock_view()
	_look_at_paper()
	_take_over_light(LIGHT_FADE_SECONDS)
	_framed_fov = _frame_fov()
	_zoom_to(_framed_fov, ZOOM_IN_SECONDS)
	stage = Stage.FRAMING
	_frame_wait = FRAME_SETTLE_SECONDS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## How wide the lens is when the paper (at its distance from the eye) fills `FRAME_FILL` of the screen, in the direction that is tighter.
func _frame_fov() -> float:
	if _sheet == null or not is_instance_valid(_camera):
		return PlayerMovementController.BASE_FOV

	var screen: Vector2 = _camera.get_viewport().get_visible_rect().size
	var aspect: float = maxf(screen.x / maxf(screen.y, 1.0), 0.1)
	var distance: float = maxf(_camera.global_position.distance_to(global_position), 0.1)
	var visible_height: float = maxf(_sheet.sheet_size.y, _sheet.sheet_size.x / aspect) / FRAME_FILL
	return clampf(rad_to_deg(2.0 * atan(visible_height * 0.5 / distance)), 20.0, PlayerMovementController.BASE_FOV)


## Moves the lens (the player movement controller follows `scripted_fov` smoothly). Zooming back to the usual view hands it over to the
## movement controller again at the end.
func _zoom_to(fov: float, seconds: float) -> void:
	if _movement == null:
		return

	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()

	var start: float = float(_movement.get("scripted_fov"))
	if start <= 0.0:
		start = float(_camera.fov) if is_instance_valid(_camera) else PlayerMovementController.BASE_FOV

	_zoom_tween = create_tween()
	_zoom_tween.tween_method(_set_scripted_fov, start, fov, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_equal_approx(fov, PlayerMovementController.BASE_FOV):
		_zoom_tween.tween_callback(_set_scripted_fov.bind(0.0))


func _set_scripted_fov(fov: float) -> void:
	if is_instance_valid(_movement):
		_movement.set("scripted_fov", fov)


func _look_at_paper() -> void:
	if _movement == null:
		return

	var to_paper: Vector3 = global_position - _camera.global_position
	_movement.set("look_yaw", -rad_to_deg(atan2(-to_paper.x, -to_paper.z)))
	_movement.set("look_pitch", -rad_to_deg(atan2(to_paper.y, Vector2(to_paper.x, to_paper.z).length())))


func _show_prompt() -> void:
	if collect_prompt == null:
		collect_prompt = CollectPrompt.new()
		collect_prompt.collect_pressed.connect(collect)
		collect_prompt.back_pressed.connect(decline)
		add_child(collect_prompt)

	collect_prompt.show_prompt(item_name)
	framed.emit()


func _hide_prompt() -> void:
	if collect_prompt != null:
		collect_prompt.hide_prompt()


## Takes the rip's hold of the view and the light, and notes where everything starts. Returns false when there is nothing to play it on.
func begin_removal(player: Node) -> bool:
	_camera = _find_camera(player)
	_sheet = get_node_or_null("Visual/Sheet") as FoldingSheet
	if _camera == null or _sheet == null or not is_inside_tree():
		return false

	_player = player
	_movement = player.get("movement_controller") as Node
	is_being_removed = true
	_home = global_transform
	_pivot = Vector3(0.0, -_sheet.sheet_size.y * 0.5, 0.0)

	_pin_homes.clear()
	for pin: Node3D in pins:
		_pin_homes.append(pin.transform)

	_pin_frame = pins[0].get_parent() as Node3D if not pins.is_empty() else null
	_pin_pull = Vector3.BACK
	_lock_view()
	_take_over_light()
	# The beam follows the paper faster while it is torn off.
	if is_instance_valid(_flashlight) and _light_taken:
		_flashlight.set("scripted_aim_speed", BEAM_SPEED)

	if not tree_exiting.is_connected(_release_player):
		tree_exiting.connect(_release_player)

	removal_started.emit()
	return true


## Gives the view back, with everything where the rip ends: the top pins gone, the paper flat in the hands.
func end_removal(gentle: bool = false) -> void:
	pose_removal(removal_seconds)
	_release_player(gentle)
	is_being_removed = false
	removal_finished.emit()


## Puts everything back as it hangs on the board and gives the view back (for a rip that is not played to its end).
func cancel_removal() -> void:
	pose_removal(0.0)
	_release_player()
	is_being_removed = false
	stage = Stage.IDLE


## Puts everything where it is `seconds` into the rip (0 is as it hangs on the board).
func pose_removal(seconds: float) -> void:
	if _sheet == null or not is_instance_valid(_camera):
		return

	# The hands and the pocket are wherever the view is now (the camera may still be settling), so the paper always ends
	# in front of the player.
	var hand: Transform3D = _hand_transform()
	var pocket: Vector3 = _pin_frame.to_local(_camera.global_transform * POCKET) if _pin_frame != null else Vector3.ZERO
	for i: int in pins.size():
		_pose_pin(i, seconds, pocket)

	# The sag: the top is let go once the top pins are out. The yank: pulled down and out on the bottom pins. Then it tears free.
	var peel: float = _ease(clampf((seconds - PEEL_AT) / PEEL_SECONDS, 0.0, 1.0))
	var yank_raw: float = clampf((seconds - YANK_AT) / YANK_SECONDS, 0.0, 1.0)
	var yank: float = yank_raw * yank_raw * yank_raw
	var grab_raw: float = clampf((seconds - GRAB_AT) / GRAB_SECONDS, 0.0, 1.0)
	var grab: float = _ease(grab_raw)
	var held_by_bottom: float = 1.0 - grab
	# It trembles while it hangs by its bottom edge, harder as it is pulled, and the tremble dies away in the hands.
	var flutter: float = (sin(seconds * 41.0) * deg_to_rad(0.9) * peel + sin(seconds * 67.0) * deg_to_rad(2.2) * yank) * held_by_bottom

	# The pose it tears free in is held still while it is lifted to the hands (the lift starts from the end of the yank).
	var tilt: float = deg_to_rad(PEEL_TILT_DEGREES) * peel + deg_to_rad(YANK_TILT_DEGREES - PEEL_TILT_DEGREES) * yank + flutter
	var peeled: Transform3D = _home * _about_pivot(Basis(Vector3.RIGHT, tilt))
	# Let go at the bottom, it sags before it is lifted.
	peeled.origin += Vector3(0.0, -SAG * sin(grab_raw * PI) * (1.0 - grab), 0.0)

	global_transform = _blend(peeled, hand, grab)
	_sheet.curl = (deg_to_rad(PEEL_CURL_DEGREES) * peel + deg_to_rad(YANK_CURL_DEGREES - PEEL_CURL_DEGREES) * yank) * held_by_bottom
	_pose_view(seconds)


## Holds the player's view. The flashlight is not put out for it: the view is held as a scene holds it (`scripted_flashlight`), not as a
## puzzle screen does (`modal_ui_open`), which is what puts the flashlight out.
func _lock_view() -> void:
	if _view_locked or _player == null or not _player.has_method("set_view_locked"):
		return

	_view_locked = true
	_player.set("scripted_flashlight", true)
	_player.call("set_view_locked", true)
	_flashlight = _player.get("flashlight_controller") as Node
	if _flashlight != null:
		_flashlight_was_on = bool(_flashlight.get("flashlight_on"))


## The flashlight is taken over like the unfinished house does, from the moment the player is at the paper: lit, and its beam aimed at
## it, so the light does not change when the key is pressed (a light that comes on, or is aimed afresh, at that moment is seen as a flicker).
## One that is already shining just goes on shining, steady (the random flicker of the light is let go of while the paper is looked at); one
## that is off, or is in the dark half of a flicker, comes up over `fade_seconds` instead of popping. Only if the player can use the
## flashlight at all (`flashlight_input_enabled`).
func _take_over_light(fade_seconds: float = 0.0) -> void:
	if _flashlight == null or not _flashlight.has_method("begin_scripted_light"):
		return

	if not bool(_flashlight.get("flashlight_input_enabled")):
		return

	if _light_taken:
		# Already on the paper (the close up): the rip changes nothing about the light.
		return

	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()

	_light_taken = true
	var shining: bool = (_flashlight as Node3D).visible
	_flashlight.call("begin_scripted_light")
	var start: float = 1.0 if shining or fade_seconds <= 0.0 else 0.0
	_set_light(start)
	_aim_light()
	_flashlight.set("scripted_aim_on", true)
	_flashlight.set("scripted_aim_speed", 1.0)
	if start < 1.0:
		_fade_light(start, 1.0, fade_seconds)


## The beam on the paper, at once (it would otherwise be a frame at the default direction).
func _aim_light() -> void:
	if not is_instance_valid(_flashlight):
		return

	var to_paper: Vector3 = global_position - (_flashlight as Node3D).global_position
	if to_paper.length() > 0.05:
		_flashlight.set("scripted_aim_direction", to_paper.normalized())


func _set_light(level: float) -> void:
	if is_instance_valid(_flashlight) and _light_taken:
		_flashlight.call("set_scripted_light", level > 0.001, level)


## The light strength from `from` to `to` over `seconds` (at once when `seconds` is 0).
func _fade_light(from: float, to: float, seconds: float) -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()

	if seconds <= 0.0:
		_set_light(to)
		return

	_light_tween = create_tween()
	_light_tween.tween_method(_set_light, from, to, seconds)


## The beam follows the paper, and the lens that was closed in on it opens as it is lifted away to the hands. The view itself is not touched: it
## does not shake or jolt when the paper tears.
func _pose_view(seconds: float) -> void:
	if _flashlight != null and is_instance_valid(_flashlight) and _light_taken:
		var to_paper: Vector3 = global_position - (_flashlight as Node3D).global_position
		if to_paper.length() > 0.05:
			_flashlight.set("scripted_aim_direction", to_paper.normalized())

	if _framed_fov > 0.0 and _framed_fov < PlayerMovementController.BASE_FOV - 0.5 and is_instance_valid(_movement):
		var opening: float = _ease(clampf((seconds - GRAB_AT) / GRAB_SECONDS, 0.0, 1.0))
		_movement.set("scripted_fov", lerpf(_framed_fov, PlayerMovementController.BASE_FOV, opening))


## The paper tilted about its bottom edge.
func _about_pivot(rotation_basis: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, _pivot) * Transform3D(rotation_basis, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -_pivot)


## Where the paper is held: in front of the camera, facing the player, a little tilted and not quite level.
func _hand_transform() -> Transform3D:
	var view: Transform3D = _camera.global_transform
	var held_basis: Basis = view.basis.orthonormalized()
	held_basis = held_basis * Basis(Vector3.RIGHT, deg_to_rad(HAND_TILT_DEGREES)) * Basis(Vector3.BACK, deg_to_rad(HAND_ROLL_DEGREES))
	var held_at: Vector3 = view.origin - view.basis.z * HAND_DISTANCE - view.basis.y * HAND_DROP
	return Transform3D(held_basis, held_at)


## The two top pins are worked out and carried off; the two bottom pins stay where they are and shake when the paper tears from them.
func _pose_pin(index: int, seconds: float, pocket: Vector3) -> void:
	var pin: Node3D = pins[index]
	if not is_instance_valid(pin) or index >= _pin_homes.size():
		return

	var home: Transform3D = _pin_homes[index]
	if index >= PIN_START.size():
		var shake: float = clampf(1.0 - (seconds - TEAR_AT) / 0.3, 0.0, 1.0) if seconds >= TEAR_AT else 0.0
		pin.visible = true
		pin.transform = Transform3D(home.basis * Basis(Vector3.RIGHT, deg_to_rad(6.0) * sin(seconds * 70.0) * shake), home.origin)
		return

	var struggle: float = clampf((seconds - PIN_START[index]) / PIN_STRUGGLE_SECONDS, 0.0, 1.0)
	var carry: float = clampf((seconds - PIN_START[index] - PIN_STRUGGLE_SECONDS) / PIN_CARRY_SECONDS, 0.0, 1.0)
	if struggle <= 0.0:
		pin.visible = true
		pin.transform = home
		return

	if carry >= 1.0:
		pin.visible = false
		pin.transform = Transform3D(home.basis, pocket)
		return

	# Tugged twice (it comes a little way and goes back), twisted, and then, with a jerk, out of the wood.
	var tugs: float = PIN_TUG * (1.0 - cos(minf(struggle / 0.75, 1.0) * TAU * 2.0)) * 0.5
	var jerk: float = 1.0 - pow(1.0 - clampf((struggle - 0.75) / 0.25, 0.0, 1.0), 2.0)
	var out: float = tugs * (1.0 - jerk) + PIN_PULL * jerk
	var twist: float = deg_to_rad(14.0) * sin(struggle * TAU * 3.0) * (1.0 - struggle) + deg_to_rad(28.0) * jerk
	var carried: float = _ease(carry)
	var at: Vector3 = (home.origin + _pin_pull * out).lerp(pocket, carried)
	pin.visible = true
	pin.transform = Transform3D(Basis(Vector3.RIGHT, twist) * home.basis, at)
	pin.scale = Vector3.ONE * (1.0 - 0.7 * carried)


func _blend(from: Transform3D, to: Transform3D, amount: float) -> Transform3D:
	if amount <= 0.0:
		return from

	if amount >= 1.0:
		return to

	var turned: Quaternion = from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), amount)
	return Transform3D(Basis(turned), from.origin.lerp(to.origin, amount))


func _ease(amount: float) -> float:
	return smoothstep(0.0, 1.0, amount)


func _find_camera(player: Node) -> Camera3D:
	var movement: Object = player.get("movement_controller") as Object
	if movement != null:
		var camera: Camera3D = movement.get("camera") as Camera3D
		if camera != null:
			return camera

	return player.get_viewport().get_camera_3d() if player.get_viewport() != null else null


## Starts the lesson about the map key: the player has the map now, and this is how to look at it again.
func _start_map_tutorial(player: Node) -> void:
	var hints: Node = player.get_node_or_null("TutorialHints")
	if hints != null and hints.has_method("trigger"):
		hints.call("trigger", &"map")


## The light is given back: the beam follows the view again, and a flashlight that was off is put out again, at once or (`gentle`) after
## going down over a moment.
func _release_light(gentle: bool) -> void:
	if not _light_taken or not is_instance_valid(_flashlight):
		_light_taken = false
		_flashlight = null
		return

	var flashlight: Node = _flashlight
	var was_on: bool = _flashlight_was_on
	_light_taken = false
	_flashlight = null
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()

	flashlight.set("scripted_aim_on", false)
	flashlight.set("scripted_aim_speed", 1.0)
	if gentle and not was_on:
		var fade: Tween = create_tween()
		fade.tween_method(_set_light_of.bind(flashlight), 1.0, 0.0, LIGHT_FADE_SECONDS)
		fade.tween_callback(_finish_light.bind(flashlight, was_on))
		_light_tween = fade
		return

	_finish_light(flashlight, was_on)


func _set_light_of(level: float, flashlight: Node) -> void:
	if is_instance_valid(flashlight):
		flashlight.call("set_scripted_light", level > 0.001, level)


func _finish_light(flashlight: Node, was_on: bool) -> void:
	if not is_instance_valid(flashlight):
		return

	flashlight.call("end_scripted_light")
	if not was_on and flashlight.has_method("turn_off"):
		flashlight.call("turn_off")


## Gives the view and the flashlight back as they were: the view is free, the beam follows it again, and a flashlight that was off
## is put out again (`gentle`: it goes down over a moment, not at once).
func _release_player(gentle: bool = false) -> void:
	_release_light(gentle)
	if is_instance_valid(_movement) and not (_zoom_tween != null and _zoom_tween.is_valid()):
		_movement.set("scripted_fov", 0.0)

	if _view_locked and is_instance_valid(_player) and _player.has_method("set_view_locked"):
		_player.call("set_view_locked", false)
		_player.set("scripted_flashlight", false)

	_view_locked = false
