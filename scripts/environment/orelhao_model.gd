@tool
extends Node3D
class_name OrelhaoModel

## A stand-in model of an Orelhao, the yellow fibreglass shell payphone of Brazil,
## built in code from primitives and CSG so the overlook scene can be played before
## real art exists (put the real model in its place; keep the part names, the
## `CloseUpCamera` marker and `Receiver`). Built facing +Z with the origin at the ground.
##
## The shape follows the real ones: a deep egg-shaped shell, yellow outside and dark
## inside, open to the front, tilted a little forward, on a slim post that joins it
## underneath. The phone unit (faceplate, keypad, coin slot, coin return, cradle hook)
## sits in the middle of the cavity; the handset hangs from the unit by its coiled cord.
## The world is smaller than a real street (the player's eyes are at 1.3 m), so the
## booth is built a little under real size: the unit's middle is at eye height.

const PLATE_CENTER: Vector3 = Vector3(0.0, 1.48, -0.3)
## The plate is built at the size of a 30 x 56 cm plate and scaled down to the unit's
## real size (22 x 41 cm).
const PLATE_SCALE: float = 0.74
## Where the receiver's cord port hangs when it is off its hook, in the model's space,
## directly below where the cord leaves the unit.
const RECEIVER_HOME: Vector3 = Vector3(-0.081, 1.05, -0.24)
## Where it sits on its hook: upside down, the earpiece in the fork at the top of the
## unit's left side and the cord port (now at the bottom) just above the cord outlet.
const HOOK_POSITION: Vector3 = Vector3(-0.0814, 1.391, -0.2556)
## Slot housing (in plate space) and the top of its slit.
const SLOT_POSITION: Vector3 = Vector3(0.075, 0.205, 0.025)
const SLOT_TOP_Y: float = 0.25
## The handle's middle, below the cord port (receiver space).
const HANDLE_CENTER: Vector3 = Vector3(0.0, -0.105, 0.0)

const SHELL_YELLOW: Color = Color(0.97, 0.74, 0.07)
const SHELL_INSIDE: Color = Color(0.11, 0.115, 0.105)
const UNIT_BLUE: Color = Color(0.2, 0.3, 0.45)
const BLUE_PLASTIC: Color = Color(0.1, 0.24, 0.66)

var plate: Node3D = null
## Pivots at the receiver's cord port; the handset hangs below it.
var receiver: Node3D = null
var cord: CoiledCord = null
var cord_anchor: Node3D = null
var close_up_camera: Marker3D = null
var indicator_light: OmniLight3D = null
## A soft light on the unit so it can be read in the shadow of the shell.
var face_fill: OmniLight3D = null

## While true the hanging receiver sways a little, as if in a draught.
var sway_enabled: bool = false
## True while the receiver sits on its hook.
var on_hook: bool = true

var _indicator_material: StandardMaterial3D = null
var _flap: Node3D = null
var _indicator_on: bool = false
var _time: float = 0.0


func _ready() -> void:
	if get_child_count() > 0:
		return

	_build()


func _process(delta: float) -> void:
	if receiver == null or not sway_enabled or Engine.is_editor_hint():
		return

	_time += delta
	receiver.rotation_degrees = Vector3(
		sin(_time * 0.9 + 1.0) * 1.1,
		sin(_time * 0.55) * 2.0,
		sin(_time * 1.3) * 1.6
	)


# ============================================================
# BUILDING
# ============================================================

func _build() -> void:
	var shell_paint: StandardMaterial3D = JunctionProps.weathered(SHELL_YELLOW, 3.0, 0.5, 0.0)
	var shell_inside: StandardMaterial3D = JunctionProps.weathered(SHELL_INSIDE, 3.0, 0.9, 0.0)
	var steel: StandardMaterial3D = JunctionProps.weathered(Color(0.58, 0.6, 0.62), 6.0, 0.4, 0.85)
	var unit_paint: StandardMaterial3D = JunctionProps.weathered(UNIT_BLUE, 5.0, 0.5, 0.6)
	var dark_steel: StandardMaterial3D = JunctionProps.weathered(Color(0.16, 0.17, 0.18), 6.0, 0.5, 0.8)
	var post_paint: StandardMaterial3D = JunctionProps.weathered(Color(0.12, 0.12, 0.13), 3.0, 0.6, 0.5)
	var concrete: StandardMaterial3D = JunctionProps.weathered(JunctionProps.CONCRETE, 2.0, 0.95)

	# Footing and the slim post that joins the shell from underneath.
	HouseProps.add_box(self, "Footing", Vector3(0.34, 0.08, 0.34), Vector3(0.0, 0.04, -0.12), concrete)
	HouseProps.add_cylinder(self, "Post", 0.045, 0.76, Vector3(0.0, 0.38, -0.12), post_paint)
	HouseProps.add_cylinder(self, "PostCollar", 0.065, 0.04, Vector3(0.0, 0.1, -0.12), dark_steel)
	_build_shell(shell_paint, shell_inside)

	_build_plate(steel, unit_paint, dark_steel)
	_build_receiver()
	_build_camera_marker()

	face_fill = OmniLight3D.new()
	var fill: OmniLight3D = face_fill
	fill.name = "FaceFill"
	fill.position = Vector3(0.0, 1.4, 0.1)
	fill.light_color = Color(1.0, 0.82, 0.55)
	fill.light_energy = 0.55
	fill.omni_range = 1.5
	fill.shadow_enabled = false
	add_child(fill)


## The shell: a hollow egg, yellow outside and dark inside, with the front cut away
## and tilted forward.
func _build_shell(shell_paint: Material, shell_inside: Material) -> void:
	var combiner: CSGCombiner3D = CSGCombiner3D.new()
	combiner.name = "Shell"
	combiner.position = Vector3(0.0, 1.32, -0.02)
	combiner.rotation_degrees = Vector3(14.0, 0.0, 0.0)
	combiner.use_collision = false
	add_child(combiner)

	_shell_sphere(combiner, "Outer", false, Vector3.ZERO, Vector3(0.46, 0.58, 0.54), shell_paint)
	_shell_sphere(combiner, "Inner", true, Vector3.ZERO, Vector3(0.43, 0.55, 0.51), shell_inside)

	# The opening: the front is cut away, the cut edge is the yellow rim.
	var cutter: CSGBox3D = CSGBox3D.new()
	cutter.name = "Opening"
	cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
	cutter.size = Vector3(3.0, 4.0, 2.0)
	cutter.position = Vector3(0.0, -0.12, 1.22)
	cutter.material = shell_paint
	combiner.add_child(cutter)


func _shell_sphere(parent: Node, node_name: String, subtract: bool, pos: Vector3, radii: Vector3, mat: Material) -> void:
	var sphere: CSGSphere3D = CSGSphere3D.new()
	sphere.name = node_name
	if subtract:
		sphere.operation = CSGShape3D.OPERATION_SUBTRACTION

	sphere.radius = 1.0
	sphere.radial_segments = 40
	sphere.rings = 20
	sphere.position = pos
	sphere.scale = radii
	sphere.material = mat
	parent.add_child(sphere)


func _build_plate(steel: Material, unit_paint: Material, dark_steel: Material) -> void:
	plate = Node3D.new()
	plate.name = "Plate"
	plate.position = PLATE_CENTER
	plate.scale = Vector3.ONE * PLATE_SCALE
	add_child(plate)

	var black: StandardMaterial3D = HouseProps.material(Color(0.02, 0.02, 0.025), 0.8)
	var grey_plastic: StandardMaterial3D = HouseProps.material(Color(0.42, 0.42, 0.4), 0.7)
	var brass: StandardMaterial3D = HouseProps.material(JunctionProps.BRASS, 0.5, 0.8)
	var card: StandardMaterial3D = HouseProps.material(Color(0.8, 0.78, 0.7), 0.9)
	var screen: StandardMaterial3D = HouseProps.material(Color(0.22, 0.32, 0.22), 0.4)

	# The unit's body behind the face, painted blue like the real ones.
	HouseProps.add_box(plate, "Body", Vector3(0.34, 0.6, 0.12), Vector3(0.0, 0.0, -0.07), unit_paint)
	HouseProps.add_box(plate, "Face", Vector3(0.3, 0.56, 0.02), Vector3.ZERO, steel)
	for sx: float in [-0.135, 0.135]:
		for sy: float in [-0.255, 0.255]:
			HouseProps.add_cylinder(plate, "Screw", 0.006, 0.004, Vector3(sx, sy, 0.011), dark_steel, Vector3(90.0, 0.0, 0.0))

	# The instruction card and the little display at the top.
	HouseProps.add_box(plate, "Card", Vector3(0.2, 0.07, 0.002), Vector3(-0.02, 0.235, 0.0105), card)
	HouseProps.add_box(plate, "Display", Vector3(0.1, 0.03, 0.003), Vector3(-0.03, 0.17, 0.011), screen)

	# Coin slot: a housing with a slit across its top and a flap on its front.
	HouseProps.add_box(plate, "SlotHousing", Vector3(0.1, 0.09, 0.03), SLOT_POSITION, dark_steel)
	HouseProps.add_box(plate, "Slit", Vector3(0.066, 0.002, 0.0095), SLOT_POSITION + Vector3(0.0, 0.0451, 0.0), black)
	HouseProps.add_box(plate, "SlotWindow", Vector3(0.05, 0.026, 0.002), SLOT_POSITION + Vector3(0.0, -0.01, 0.0158), black)
	_flap = Node3D.new()
	_flap.name = "FlapHinge"
	_flap.position = SLOT_POSITION + Vector3(0.0, -0.001, 0.0172)
	plate.add_child(_flap)
	HouseProps.add_box(_flap, "Flap", Vector3(0.046, 0.022, 0.002), Vector3(0.0, -0.011, 0.0), brass)

	# Indicator light: red until the line is paid.
	HouseProps.add_cylinder(plate, "IndicatorRing", 0.0125, 0.006, Vector3(-0.1, 0.17, 0.011), dark_steel, Vector3(90.0, 0.0, 0.0))
	_indicator_material = StandardMaterial3D.new()
	_indicator_material.albedo_color = Color(0.5, 0.02, 0.02)
	_indicator_material.emission_enabled = true
	_indicator_material.emission = Color(0.95, 0.05, 0.04)
	_indicator_material.emission_energy_multiplier = 1.6
	_indicator_material.roughness = 0.2
	HouseProps.add_cylinder(plate, "Indicator", 0.0085, 0.008, Vector3(-0.1, 0.17, 0.0135), _indicator_material, Vector3(90.0, 0.0, 0.0))
	indicator_light = OmniLight3D.new()
	indicator_light.name = "IndicatorLight"
	indicator_light.position = Vector3(-0.1, 0.17, 0.05)
	indicator_light.light_color = Color(1.0, 0.1, 0.06)
	indicator_light.light_energy = 0.4
	indicator_light.omni_range = 0.35
	plate.add_child(indicator_light)

	# The keypad: three columns, four rows (1-9, *, 0, #) of worn grey keys.
	HouseProps.add_box(plate, "KeypadBase", Vector3(0.14, 0.2, 0.006), Vector3(0.0, 0.02, 0.012), black)
	var legends: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
	for index: int in 12:
		var column: int = index % 3
		var row: int = index / 3
		var key_pos: Vector3 = Vector3(-0.042 + column * 0.042, 0.083 - row * 0.043, 0.0185)
		HouseProps.add_box(plate, "Key%d" % index, Vector3(0.034, 0.032, 0.01), key_pos, grey_plastic)
		HouseProps.add_text(
			plate, "Legend%d" % index, legends[index], key_pos + Vector3(0.0, 0.0, 0.0054),
			32, 0.00042, Color(0.06, 0.06, 0.06), 0.0, true
		)

	# The coin return cup under the keypad.
	HouseProps.add_box(plate, "ReturnCup", Vector3(0.1, 0.045, 0.05), Vector3(0.0, -0.21, 0.03), dark_steel)
	HouseProps.add_box(plate, "ReturnOpening", Vector3(0.074, 0.022, 0.002), Vector3(0.0, -0.205, 0.0555), black)

	# The cradle: a fork on the unit's left side that the earpiece of the receiver rests in.
	HouseProps.add_box(plate, "CradleBase", Vector3(0.12, 0.03, 0.04), Vector3(-0.11, 0.146, 0.03), dark_steel)
	HouseProps.add_box(plate, "CradleLeft", Vector3(0.014, 0.075, 0.045), Vector3(-0.162, 0.185, 0.04), dark_steel, Vector3(0.0, 0.0, -6.0))
	HouseProps.add_box(plate, "CradleRight", Vector3(0.014, 0.075, 0.045), Vector3(-0.058, 0.185, 0.04), dark_steel, Vector3(0.0, 0.0, 6.0))

	# The armoured cord leaves the unit's lower left edge.
	HouseProps.add_cylinder(plate, "CordSleeve", 0.012, 0.04, Vector3(-0.11, -0.29, 0.012), dark_steel)
	cord_anchor = Node3D.new()
	cord_anchor.name = "CordAnchor"
	cord_anchor.position = Vector3(-0.11, -0.312, 0.012)
	plate.add_child(cord_anchor)


## The handset, hanging by its cord from the port at its top: mouthpiece cup, handle,
## earpiece cup, in blue plastic. The coiled cord joins the unit to the port.
func _build_receiver() -> void:
	receiver = Node3D.new()
	receiver.name = "Receiver"
	receiver.transform = get_hook_pose()
	add_child(receiver)

	var blue: StandardMaterial3D = HouseProps.material(BLUE_PLASTIC, 0.32)
	var scuff: StandardMaterial3D = HouseProps.material(BLUE_PLASTIC.lightened(0.18), 0.6)
	var black: StandardMaterial3D = HouseProps.material(Color(0.02, 0.02, 0.025), 0.8)

	HouseProps.add_cylinder(receiver, "Mouthpiece", 0.027, 0.032, Vector3(0.0, -0.016, 0.0), blue, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_cylinder(receiver, "Handle", 0.0135, 0.14, HANDLE_CENTER, blue)
	HouseProps.add_box(receiver, "HandleWear", Vector3(0.005, 0.07, 0.006), Vector3(0.0, -0.105, 0.0128), scuff)
	HouseProps.add_cylinder(receiver, "Earpiece", 0.031, 0.034, Vector3(0.0, -0.2, 0.0), blue, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_cylinder(receiver, "MouthGrille", 0.018, 0.002, Vector3(0.0, -0.016, 0.0165), black, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_cylinder(receiver, "EarGrille", 0.02, 0.002, Vector3(0.0, -0.2, 0.0175), black, Vector3(90.0, 0.0, 0.0))
	HouseProps.add_cylinder(receiver, "PortBoot", 0.0125, 0.03, Vector3(0.0, 0.015, 0.0), black)

	cord = CoiledCord.new()
	cord.name = "Cord"
	cord.rest_length = 0.34
	cord.turns = 24.0
	cord.coil_radius = 0.0125
	cord.wire_radius = 0.0048
	cord.color = Color(0.62, 0.63, 0.66)
	add_child(cord)
	# The cord's far end is the receiver's port (the pivot itself).
	cord.attach(cord_anchor, receiver)


func _build_camera_marker() -> void:
	close_up_camera = Marker3D.new()
	close_up_camera.name = "CloseUpCamera"
	close_up_camera.position = Vector3(0.0, 1.6, 0.72)
	# At the player's own eye height, looking down at the unit.
	close_up_camera.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	add_child(close_up_camera)


# ============================================================
# ANIMATION
# ============================================================

## Dims the fill light on the unit with the street lamp (1 is the lamp at full power): when
## the lamp dies only the red or green indicator is left.
func set_fill_scale(lamp_level: float) -> void:
	if face_fill != null:
		face_fill.light_energy = 0.55 * lerpf(0.0, 1.0, clampf(lamp_level, 0.0, 1.0))


## The receiver's pose on its hook, in this model's space: upside down (a half turn about X,
## so its back faces out).
func get_hook_pose() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, PI), HOOK_POSITION)


## Puts the receiver on its hook at once.
func put_on_hook() -> void:
	on_hook = true
	sway_enabled = false
	receiver.transform = get_hook_pose()


## The receiver is lifted off its hook (the sequence moves it from here on).
func take_off_hook() -> void:
	on_hook = false
	sway_enabled = false


## Leaves the receiver hanging by its cord at once, swaying a little.
func let_hang() -> void:
	on_hook = false
	receiver.transform = get_receiver_home()
	sway_enabled = true


## The receiver's hanging pose, in this model's space (off the hook, by its cord).
func get_receiver_home() -> Transform3D:
	return Transform3D(Basis.IDENTITY, RECEIVER_HOME)


## Sets the indicator red (false) or green (true). With `animate` it blinks once
## first, as a relay settling.
func set_indicator(on: bool, animate: bool = false) -> void:
	if _indicator_on == on:
		return

	_indicator_on = on
	if animate:
		var blink: Tween = create_tween()
		blink.tween_method(_set_indicator_level, 1.0, 0.0, 0.12)
		blink.tween_callback(_apply_indicator_colour)
		blink.tween_method(_set_indicator_level, 0.0, 1.0, 0.25)
	else:
		_apply_indicator_colour()
		_set_indicator_level(1.0)


func _apply_indicator_colour() -> void:
	var colour: Color = Color(0.1, 1.0, 0.25) if _indicator_on else Color(0.95, 0.05, 0.04)
	_indicator_material.emission = colour
	_indicator_material.albedo_color = colour.darkened(0.6)
	indicator_light.light_color = colour


func _set_indicator_level(level: float) -> void:
	_indicator_material.emission_energy_multiplier = lerpf(0.0, 1.8, level)
	indicator_light.light_energy = lerpf(0.0, 0.6, level)


## A ficha (its inventory model, facing +Z) appears over the coin slot, slides down
## into it and disappears, and the flap inside tilts forward and snaps back. The
## model is freed at the end. Await it.
func drop_ficha(visual: Node3D) -> void:
	var start_y: float = SLOT_TOP_Y + 0.026 + 0.014
	var end_y: float = SLOT_TOP_Y - 0.026 - 0.006
	var slot_xz: Vector3 = Vector3(SLOT_POSITION.x, start_y, SLOT_POSITION.z)

	plate.add_child(visual)
	visual.position = slot_xz
	visual.scale = Vector3.ONE * 0.9
	# Only what is above the housing shows; the housing hides the rest.
	var settle: Tween = create_tween().set_parallel(true)
	settle.tween_property(visual, "scale", Vector3.ONE, 0.2)
	await get_tree().create_timer(0.38).timeout

	var slide: Tween = create_tween()
	slide.tween_property(visual, "position:y", end_y, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await slide.finished
	visual.queue_free()

	# The flap inside tilts forward and snaps back.
	var flap: Tween = create_tween()
	flap.tween_property(_flap, "rotation_degrees:x", -38.0, 0.12).set_trans(Tween.TRANS_SINE)
	flap.tween_property(_flap, "rotation_degrees:x", 0.0, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await flap.finished


## The receiver swings on its cord after being let go, and settles back into its
## gentle sway. Await it.
func swing_receiver(strength: float = 1.0) -> void:
	sway_enabled = false
	var swing: Tween = create_tween()
	var angles: Array[float] = [9.0, -6.5, 4.5, -3.0, 1.8, -1.0, 0.4, 0.0]
	for angle: float in angles:
		swing.tween_property(receiver, "rotation_degrees:z", angle * strength, 0.34).set_trans(Tween.TRANS_SINE)

	var sway: Tween = create_tween()
	var depth_angles: Array[float] = [-5.0, 3.5, -2.2, 1.2, -0.5, 0.0]
	for angle: float in depth_angles:
		sway.tween_property(receiver, "rotation_degrees:x", angle * strength, 0.42).set_trans(Tween.TRANS_SINE)

	await swing.finished
	sway_enabled = true
