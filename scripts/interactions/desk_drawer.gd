extends Interactable
class_name DeskDrawer

## A drawer that slides out of a desk on its runners, with something in it. Opening and closing are short scenes of their own, and they are
## played from a small simulation instead of a tween, so that the drawer moves the way a wooden drawer does:
##
##   * a hand pulls (or pushes) it through a little give, and the drawer holds on its runners until the pull is strong enough, then breaks free
##     with a small jerk (stiction), and the rough wood makes its speed waver a little as it slides;
##   * it runs along the stop at the end of its travel and knocks against it, rebounds a few millimetres and knocks once more, softer;
##   * while it is out it binds a little to one side and its front sags a fraction of a degree; what lies in it slides back as it starts and
##     forward as it stops;
##   * the sound is made from the same motion (`PlaceholderAudio.make_drawer_slide`): a scrape that follows its speed, the tack of the break away,
##     the knocks, a rattle.
##
## The player leans in a little while they pull (the camera gesture of the doors), and everything is kept in the save when `persistent_id` is set.
## What is in the drawer stays out of reach until it is open: its interaction areas are off while the drawer is shut or on its way.
##
## The nodes: `Slide` (the part that moves, its origin the middle of the drawer box), `Contents` (a child of `Slide`: things in the drawer go
## here) and `InteractArea` (on the front of `Slide`: aim at the front to open or shut it). `build` makes them.

signal opened
signal closed

const STATE_SECTION: StringName = &"drawers"

## The simulation (metres, seconds, and a drawer that weighs 0.6 in the units of the springs).
const SIM_STEP: float = 1.0 / 480.0
const RECORD_STEP: float = 1.0 / 240.0
const DRAWER_MASS: float = 0.6
const HAND_STIFFNESS: float = 650.0
const HAND_DAMPING: float = 14.0
const STICTION: float = 1.1
const SLIDING_FRICTION: float = 0.55
## The wood's roughness: how much the sliding friction wavers, and how close its bumps are (per metre).
const ROUGHNESS: float = 0.45
## A hand pulls at this speed (m/s) until the stop holds the drawer, and carries on this far past it; it is let go a moment after.
const PULL_SPEED: float = 0.5
const PUSH_SPEED: float = 0.6
const HAND_OVERSHOOT: float = 0.003
const HAND_START: float = 0.05
const HAND_RAMP_SECONDS: float = 0.16
## The hand lets go this long after the first knock (it eases off when the drawer stops), and a hit under `HIT_MIN_SPEED` is only the hand pressing
## the drawer against its stop.
const HAND_RELEASE_AFTER: float = 0.1
const HIT_MIN_SPEED: float = 0.03
const STOP_RESTITUTION: float = 0.34
const REST_SPEED: float = 0.0015
const MAX_SECONDS: float = 2.2

## How much the drawer binds to one side while it moves (radians at full speed) and how far its front sags when it is far out.
const BIND_RADIANS: float = 0.012
const SAG_RADIANS: float = 0.013
## How far (metres) what lies in the drawer slides for each m/s² of the drawer's acceleration, and the most it moves.
const CONTENTS_SLIDE: float = 0.0007
const CONTENTS_MAX_SLIDE: float = 0.009

@export var persistent_id: StringName = &""
@export var closed_prompt_text: String = "PROMPT_OPEN"
@export var opened_prompt_text: String = "PROMPT_CLOSE"
## How far the drawer comes out of the desk, in metres.
@export var travel: float = 0.34

var is_open: bool = false
var is_moving: bool = false
var slide: Node3D = null
var contents: Node3D = null

var _profile: Dictionary = {}
var _clock: float = 0.0
var _opening: bool = true
var _closed_origin: Vector3 = Vector3.ZERO
var _bind_side: float = 1.0
var _contents_home: Vector3 = Vector3.ZERO
var _contents_slide: float = 0.0
var _contents_velocity: float = 0.0
var _sound: AudioStreamPlayer3D = null
var _player: Node = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _leaning: bool = false
static var _profiles: Dictionary = {}
static var _sounds: Dictionary = {}


func _ready() -> void:
	# (Built by a tool script in the editor, it only has to look right there: nothing runs, and the save is not read.)
	if Engine.is_editor_hint():
		return

	_rng.randomize()
	if slide == null:
		slide = get_node_or_null("Slide") as Node3D

	if slide == null:
		push_warning("DeskDrawer: there is no `Slide` node.")
		set_process(false)
		return

	contents = slide.get_node_or_null("Contents") as Node3D
	_closed_origin = slide.position
	if contents != null:
		_contents_home = contents.position

	_sound = AudioStreamPlayer3D.new()
	_sound.name = "Sound"
	_sound.unit_size = 2.0
	_sound.max_distance = 14.0
	_sound.volume_db = -5.0
	add_child(_sound)
	set_process(false)

	var saved: Variant = SaveManager.get_state_value(STATE_SECTION, persistent_id, {}) if not persistent_id.is_empty() else {}
	if saved is Dictionary and bool((saved as Dictionary).get("is_open", false)):
		_set_position_at(travel)
		is_open = true

	_enable_contents(is_open)


func can_interact(_player_node: Node) -> bool:
	return slide != null and not is_moving


func get_prompt_text() -> String:
	return opened_prompt_text if is_open else closed_prompt_text


func interact(player: Node) -> void:
	if slide == null or is_moving:
		return

	_player = player
	if is_open:
		close()
	else:
		open()


## Pulls the drawer open (a scene of a second or so).
func open() -> void:
	_begin(true)


## Pushes it shut.
func close() -> void:
	_begin(false)


## At once, with no scene (a loaded game, a test).
func set_open_now(open_it: bool) -> void:
	is_moving = false
	set_process(false)
	_set_position_at(travel if open_it else 0.0)
	is_open = open_it
	_enable_contents(open_it)
	_remember()


## How far out the drawer is, 0 shut and 1 at its stop.
func get_openness() -> float:
	if slide == null or travel <= 0.0:
		return 0.0

	return clampf((slide.position.z - _closed_origin.z) / travel, 0.0, 1.0)


# ============================================================
# THE SCENE
# ============================================================

func _begin(opening: bool) -> void:
	_opening = opening
	_profile = get_profile(opening, travel)
	_clock = 0.0
	is_moving = true
	_bind_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_contents_slide = 0.0
	_contents_velocity = 0.0
	# Nothing in it can be taken (or aimed at) while it is on its way, and nothing in a shut drawer at all.
	_enable_contents(false)
	_play_sound()
	_lean(true)
	set_process(true)


func _process(delta: float) -> void:
	if not is_moving:
		set_process(false)
		return

	_clock += delta
	var seconds: float = float(_profile["seconds"])
	var distance: float = _sample(_profile["x"] as PackedFloat32Array, _clock)
	var speed: float = _sample(_profile["v"] as PackedFloat32Array, _clock)
	var acceleration: float = (_sample(_profile["v"] as PackedFloat32Array, _clock + RECORD_STEP) - _sample(_profile["v"] as PackedFloat32Array, _clock - RECORD_STEP)) / (2.0 * RECORD_STEP)
	var out: float = distance if _opening else travel - distance
	_set_position_at(out)

	# It binds to one side while it runs, and its front sags once it is far out.
	var openness: float = clampf(out / maxf(travel, 0.001), 0.0, 1.0)
	slide.rotation = Vector3(
		SAG_RADIANS * smoothstep(0.5, 1.0, openness),
		_bind_side * BIND_RADIANS * clampf(absf(speed) / 0.4, 0.0, 1.0),
		0.0
	)

	# What lies in the drawer lags behind it: back as it starts, forward as it stops (a damped spring on the drawer's acceleration).
	if contents != null:
		var wanted: float = clampf(-acceleration * CONTENTS_SLIDE, -CONTENTS_MAX_SLIDE, CONTENTS_MAX_SLIDE)
		_contents_velocity += (wanted - _contents_slide) * 900.0 * delta - _contents_velocity * 38.0 * delta
		_contents_slide += _contents_velocity * delta
		contents.position = _contents_home + Vector3(0.0, 0.0, _contents_slide)

	if _leaning and _clock > seconds * 0.55:
		_lean(false)

	if _clock >= seconds:
		_finish()


func _finish() -> void:
	is_moving = false
	set_process(false)
	is_open = _opening
	_set_position_at(travel if is_open else 0.0)
	slide.rotation = Vector3(SAG_RADIANS if is_open else 0.0, 0.0, 0.0)
	if contents != null:
		contents.position = _contents_home

	_lean(false)
	_enable_contents(is_open)
	_remember()
	if is_open:
		opened.emit()
	else:
		closed.emit()


func _set_position_at(out: float) -> void:
	slide.position = _closed_origin + Vector3(0.0, 0.0, out)
	if out <= 0.0 or out >= travel:
		slide.rotation = Vector3(SAG_RADIANS if out >= travel else 0.0, 0.0, 0.0)


## The player leans in over the drawer for the pull and straightens up as it comes to its stop.
func _lean(into: bool) -> void:
	_leaning = into
	var movement: Object = null
	if is_instance_valid(_player):
		movement = _player.get("movement_controller") as Object

	if movement == null:
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(movement, "gesture_offset", Vector3(0.0, -0.014, -0.03) if into else Vector3.ZERO, 0.22 if into else 0.35)
	tween.tween_property(movement, "gesture_pitch_degrees", 1.6 if into else 0.0, 0.22 if into else 0.35)


func _enable_contents(enabled: bool) -> void:
	if contents == null:
		return

	for area: Node in contents.find_children("*", "CollisionShape3D", true, false):
		(area as CollisionShape3D).set_deferred("disabled", not enabled)


func _remember() -> void:
	if persistent_id.is_empty() or not SaveManager.has_active_game():
		return

	SaveManager.set_state_value(STATE_SECTION, persistent_id, {"is_open": is_open})


func _play_sound() -> void:
	if _sound == null:
		return

	var key: String = "%s_%.3f" % ["open" if _opening else "shut", travel]
	if not _sounds.has(key):
		var hits: Array[Vector2] = []
		hits.assign(_profile["hits"])
		_sounds[key] = PlaceholderAudio.make_drawer_slide(_profile["v"] as PackedFloat32Array, RECORD_STEP, hits, float(_profile["seconds"]) + 0.15, _opening)

	_sound.stream = _sounds[key]
	_sound.pitch_scale = _rng.randf_range(0.96, 1.04)
	_sound.play()


## A value of a recorded curve at `seconds` (linear between the records; the first before it, the last after it).
static func _sample(curve: PackedFloat32Array, seconds: float) -> float:
	if curve.is_empty():
		return 0.0

	var at: float = clampf(seconds / RECORD_STEP, 0.0, float(curve.size() - 1))
	var index: int = int(floorf(at))
	var next: int = mini(index + 1, curve.size() - 1)
	return lerpf(curve[index], curve[next], at - float(index))


# ============================================================
# THE MOTION (a small simulation, played back)
# ============================================================

## The motion of the drawer along its runners as arrays recorded every `RECORD_STEP` seconds: `x` the distance covered from where it started, `v` its
## speed, `hits` where it knocks (time, strength 0 to 1), `seconds` how long until it is still. Opening starts at the shut position, closing at the
## stop; both are measured from where they start. The same arrays are played by the drawer and made into its sound.
static func get_profile(opening: bool, distance: float) -> Dictionary:
	var key: String = "%s_%.3f" % ["open" if opening else "shut", distance]
	if _profiles.has(key):
		return _profiles[key] as Dictionary

	var profile: Dictionary = simulate(PULL_SPEED if opening else PUSH_SPEED, distance, 1.0 if opening else 1.7)
	_profiles[key] = profile
	return profile


## One run of the simulation: a hand moves at `hand_speed` (after a short ramp) until the stop at `distance` holds the drawer; `bump` is how much
## harder the stop is hit than a drawer pulled out hits its own.
static func simulate(hand_speed: float, distance: float, bump: float) -> Dictionary:
	var xs: PackedFloat32Array = PackedFloat32Array()
	var vs: PackedFloat32Array = PackedFloat32Array()
	var hits: Array[Vector2] = []
	var x: float = 0.0
	var v: float = 0.0
	var t: float = 0.0
	# (If the stop is never hit hard enough to be felt, the hand lets go a moment after it has carried the drawer all the way.)
	var release: float = HAND_START + (distance + HAND_OVERSHOOT) / hand_speed + HAND_RAMP_SECONDS * 0.5 + HAND_RELEASE_AFTER
	var quiet_for: float = 0.0
	var record_clock: float = 0.0
	var seconds: float = MAX_SECONDS
	xs.append(0.0)
	vs.append(0.0)

	while t < MAX_SECONDS:
		# The hand: a ramp up to its speed, then straight on, stopped when the drawer is held and let go a moment after.
		var hand_x: float = 0.0
		var hand_v: float = 0.0
		var since: float = t - HAND_START
		if since > 0.0:
			var ramp: float = clampf(since / HAND_RAMP_SECONDS, 0.0, 1.0)
			hand_v = hand_speed * ramp * ramp * (3.0 - 2.0 * ramp)
			if since < HAND_RAMP_SECONDS:
				hand_x = hand_speed * HAND_RAMP_SECONDS * _ramp_integral(ramp)
			else:
				hand_x = hand_speed * HAND_RAMP_SECONDS * 0.5 + hand_speed * (since - HAND_RAMP_SECONDS)

			if hand_x > distance + HAND_OVERSHOOT:
				hand_x = distance + HAND_OVERSHOOT
				hand_v = 0.0

		var coupled: bool = t < release
		var pull: float = (HAND_STIFFNESS * (hand_x - x) + HAND_DAMPING * (hand_v - v)) if coupled else 0.0
		var force: float = pull
		if absf(v) < REST_SPEED and absf(pull) <= STICTION:
			v = 0.0
			force = 0.0
		else:
			var grain: float = 0.5 * sin(x * 130.0) + 0.3 * sin(x * 311.0 + 1.3) + 0.2 * sin(x * 47.0 + 0.4)
			var slip: float = SLIDING_FRICTION * (1.0 + ROUGHNESS * grain)
			var direction: float = signf(v) if absf(v) >= REST_SPEED else signf(pull)
			force = pull - slip * direction

		v += force / DRAWER_MASS * SIM_STEP
		x += v * SIM_STEP
		if x >= distance and v > 0.0:
			# The stop: it knocks, rebounds a little and is pulled back against it, softer each time. The hand eases off after the first knock.
			if v > HIT_MIN_SPEED:
				hits.append(Vector2(t, clampf(v * bump / 0.55, 0.0, 1.0)))
				release = minf(release, t + HAND_RELEASE_AFTER)
				v = -v * STOP_RESTITUTION
			else:
				v = 0.0

			x = distance
		elif x <= 0.0 and v < 0.0:
			x = 0.0
			v = 0.0

		t += SIM_STEP
		record_clock += SIM_STEP
		if record_clock >= RECORD_STEP:
			record_clock -= RECORD_STEP
			xs.append(x)
			vs.append(v)

		if t > HAND_START and absf(v) < REST_SPEED and x > distance * 0.5 and not coupled:
			quiet_for += SIM_STEP
			if quiet_for > 0.06:
				seconds = t
				break
		else:
			quiet_for = 0.0

	return {"x": xs, "v": vs, "hits": hits, "seconds": seconds}


## The distance a hand covers while its speed rises along a smooth ramp, in ramp lengths (the integral of `3r^2 - 2r^3` from 0 to `r`).
static func _ramp_integral(ramp: float) -> float:
	return ramp * ramp * ramp - 0.5 * ramp * ramp * ramp * ramp


# ============================================================
# THE LOOK
# ============================================================

## Makes the drawer of a small desk or table, in the desk's frame: `front_center` is the middle of the front panel's outside face, `width` the drawer's
## width, and the drawer is `depth` deep and `height` tall. The materials come from the desk. The front faces +Z. The drawer is not in the tree yet: set what
## it needs (`persistent_id`, `travel`), put what lies in it under its `contents`, and add it to the desk.
static func build(front_center: Vector3, width: float, height: float, depth: float, wood: Material, front_wood: Material, brass: Material, rail_wood: Material) -> DeskDrawer:
	var drawer: DeskDrawer = DeskDrawer.new()
	drawer.name = "Drawer"

	var panel: float = 0.022
	var wall: float = 0.012
	var floor_board: float = 0.008
	# The middle of the box: half the depth behind the front panel's outside face.
	var middle: Vector3 = front_center + Vector3(0.0, 0.0, -depth * 0.5)
	var moving: Node3D = Node3D.new()
	moving.name = "Slide"
	moving.position = middle
	drawer.add_child(moving)
	drawer.slide = moving

	# The drawer: the front panel, the two sides, the back and the bottom (all in the slide's frame).
	HouseProps.add_box(moving, "Front", Vector3(width, height, panel), Vector3(0.0, 0.0, depth * 0.5 - panel * 0.5), front_wood)
	var side_height: float = height - 0.02
	for side: float in [-1.0, 1.0]:
		HouseProps.add_box(moving, "Side", Vector3(wall, side_height, depth - panel), Vector3(side * (width * 0.5 - 0.02 - wall * 0.5), -0.005, -panel * 0.5), wood)

	HouseProps.add_box(moving, "Back", Vector3(width - 0.04 - wall * 2.0, side_height, wall), Vector3(0.0, -0.005, -depth * 0.5 + wall * 0.5), wood)
	HouseProps.add_box(moving, "Bottom", Vector3(width - 0.04, floor_board, depth - panel), Vector3(0.0, -height * 0.5 + 0.012 + floor_board * 0.5, -panel * 0.5), wood)
	# The pull: a brass bar on two posts.
	var pull_z: float = depth * 0.5 + 0.028
	HouseProps.add_cylinder(moving, "Pull", 0.0065, width * 0.3, Vector3(0.0, 0.0, pull_z), brass, Vector3(0.0, 0.0, 90.0))
	for post: float in [-1.0, 1.0]:
		HouseProps.add_cylinder(moving, "PullPost", 0.005, 0.03, Vector3(post * width * 0.13, 0.0, depth * 0.5 + 0.012), brass, Vector3(90.0, 0.0, 0.0))

	# What the drawer's interior holds goes here: on the bottom board, near the front so that it shows when the drawer is out.
	var holder: Node3D = Node3D.new()
	holder.name = "Contents"
	holder.position = Vector3(0.0, -height * 0.5 + 0.012 + floor_board, depth * 0.5 - panel - 0.14)
	moving.add_child(holder)
	drawer.contents = holder

	# Aim at the front to open or shut it: the area sticks out of the panel and over its top, so that a ray from the room meets it first.
	var area: Area3D = Area3D.new()
	area.name = "InteractArea"
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width + 0.04, height + 0.06, 0.09)
	shape_node.shape = box
	area.add_child(shape_node)
	area.position = Vector3(0.0, 0.0, depth * 0.5 + 0.012)
	moving.add_child(area)

	# What the player bumps into when it is out: thin boards, so that a ray from above still reaches what lies inside.
	var solid: StaticBody3D = StaticBody3D.new()
	solid.name = "Solid"
	moving.add_child(solid)
	var boards: Array[Array] = [
		[Vector3(width, height, panel), Vector3(0.0, 0.0, depth * 0.5 - panel * 0.5)],
		[Vector3(wall, side_height, depth - panel), Vector3(-(width * 0.5 - 0.02 - wall * 0.5), -0.005, -panel * 0.5)],
		[Vector3(wall, side_height, depth - panel), Vector3(width * 0.5 - 0.02 - wall * 0.5, -0.005, -panel * 0.5)],
		[Vector3(width - 0.04, floor_board, depth - panel), Vector3(0.0, -height * 0.5 + 0.012 + floor_board * 0.5, -panel * 0.5)],
		[Vector3(width - 0.04 - wall * 2.0, side_height, wall), Vector3(0.0, -0.005, -depth * 0.5 + wall * 0.5)],
	]
	for board: Array in boards:
		var part: CollisionShape3D = CollisionShape3D.new()
		var part_box: BoxShape3D = BoxShape3D.new()
		part_box.size = board[0] as Vector3
		part.shape = part_box
		part.position = board[1] as Vector3
		solid.add_child(part)

	# The runners it rides on and the board that closes the space behind it (fixed to the desk).
	var rail_y: float = middle.y - height * 0.5 + 0.002
	for side: float in [-1.0, 1.0]:
		HouseProps.add_box(drawer, "Runner", Vector3(0.024, 0.014, depth), Vector3(side * (width * 0.5 - 0.005), rail_y, middle.z), rail_wood)

	HouseProps.add_box(drawer, "BackBoard", Vector3(width + 0.04, height + 0.04, 0.012), Vector3(0.0, middle.y, middle.z - depth * 0.5 - 0.012), rail_wood)
	return drawer
