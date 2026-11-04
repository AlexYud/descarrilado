@tool
extends Node3D
class_name OrelhaoModel

## An Orelhao, the shell payphone of Brazil: the ready-made models `big_ear.glb` (the post, the egg shaped shell, the unit with its display,
## keypad, cradle and coin return) and `big_ear_phone.glb` (the handset, a separate model so that it can move), turned to face +Z and moved so
## that the unit keeps the place the blockout's had. The coiled cord, the coin slot's housing with its flap, the indicator and the fill light are
## built here (the models have none): the indicator is the unit's own display strip, lit red until the line is paid and green after. Built facing
## +Z with the origin at the ground; the part names, the `CloseUpCamera` marker and `Receiver` are what the sequence and the tests look for.
##
## The model's file frame to ours (see `file_to_model`): the booth faces +X in the file, so it is turned a quarter round about Y; the unit's front
## (file x 0.355) is put at z -0.294 and the unit's middle (file y 1.378) is at the height it has in the file.

const BOOTH_SCENE: PackedScene = preload("res://assets/models/interactables/miscellaneous/big_ear/big_ear.glb")
const HANDSET_SCENE: PackedScene = preload("res://assets/models/interactables/miscellaneous/big_ear/big_ear_phone.glb")

## File frame to model frame: a quarter turn about Y (file +x faces +z; file z becomes -x) and a shift in z.
const FILE_SHIFT: Vector3 = Vector3(0.0, 0.0, -0.649)
## The handset's cord port in the file frame: the bottom end of the handset, as it hangs on its hook (the file has the handset in place).
const HANDSET_PORT_IN_FILE: Vector3 = Vector3(0.372, 1.267, 0.074)

## The unit's front, in this model's space: its middle (file x 0.355, y 1.378, z 0.009).
const PLATE_CENTER: Vector3 = Vector3(-0.009, 1.378, -0.294)
## The plate is the frame the coin slot is drawn in, scaled so that the token (its inventory model) is the size it was.
const PLATE_SCALE: float = 0.74
## Where the receiver's cord port hangs when it is off its hook, in the model's space, directly below where the cord leaves the unit.
const RECEIVER_HOME: Vector3 = Vector3(-0.074, 1.03, -0.33)
## Where it sits on its hook: the earpiece in the fork at the top of the unit's left side and the cord port (at the bottom) just above the
## cord outlet. The handset is turned upside down against its hanging pose.
const HOOK_POSITION: Vector3 = Vector3(-0.074, 1.267, -0.277)
## Where the cord leaves the unit: its underside, under the handset.
const CORD_OUTLET: Vector3 = Vector3(-0.074, 1.229, -0.33)
## The coin slot's housing (in plate space), standing on the unit's top over the keypad column, and the top of its slit.
const SLOT_POSITION: Vector3 = Vector3(0.066, 0.24, 0.0)
const SLOT_TOP_Y: float = 0.275
## The unit's display strip in the model's space, and the material name it has in the model.
const DISPLAY_POSITION: Vector3 = Vector3(0.047, 1.478, -0.27)
const DISPLAY_MATERIAL: String = "big_ear_phone_case_display"

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


## The model's file frame to this model's: a quarter turn about Y, then the shift.
static func file_to_model(point_in_file: Vector3) -> Vector3:
	return Basis(Vector3.UP, -PI * 0.5) * point_in_file + FILE_SHIFT


# ============================================================
# BUILDING
# ============================================================

func _build() -> void:
	var booth: Node3D = BOOTH_SCENE.instantiate() as Node3D
	booth.name = "Booth"
	booth.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), FILE_SHIFT)
	add_child(booth)
	_make_display_indicator(booth)

	_build_plate()
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


## The unit's display strip is the indicator: its material is replaced by one that glows red (and green after).
func _make_display_indicator(booth: Node3D) -> void:
	_indicator_material = StandardMaterial3D.new()
	_indicator_material.albedo_color = Color(0.5, 0.02, 0.02)
	_indicator_material.emission_enabled = true
	_indicator_material.emission = Color(0.95, 0.05, 0.04)
	_indicator_material.emission_energy_multiplier = 1.6
	_indicator_material.roughness = 0.2
	for node: Node in booth.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in instance.mesh.get_surface_count():
			var material: Material = instance.mesh.surface_get_material(surface)
			if material != null and material.resource_name == DISPLAY_MATERIAL:
				instance.set_surface_override_material(surface, _indicator_material)

	indicator_light = OmniLight3D.new()
	indicator_light.name = "IndicatorLight"
	indicator_light.position = DISPLAY_POSITION + Vector3(0.0, 0.0, 0.05)
	indicator_light.light_color = Color(1.0, 0.1, 0.06)
	indicator_light.light_energy = 0.4
	indicator_light.omni_range = 0.35
	add_child(indicator_light)


## The frame of the coin slot (on the unit's front, in plate units), the slot's housing with its slit and the flap behind it, and the cord's outlet.
func _build_plate() -> void:
	plate = Node3D.new()
	plate.name = "Plate"
	plate.position = PLATE_CENTER
	plate.scale = Vector3.ONE * PLATE_SCALE
	add_child(plate)

	var black: StandardMaterial3D = HouseProps.material(Color(0.02, 0.02, 0.025), 0.8)
	var housing: StandardMaterial3D = HouseProps.material(Color(0.1, 0.1, 0.11), 0.5, 0.6)
	var brass: StandardMaterial3D = HouseProps.material(JunctionProps.BRASS, 0.5, 0.8)

	# The housing: a box on the unit's top with a slit across its top and a window on its front, a flap behind the window.
	HouseProps.add_box(plate, "SlotHousing", Vector3(0.1, 0.07, 0.04), SLOT_POSITION, housing)
	HouseProps.add_box(plate, "Slit", Vector3(0.066, 0.002, 0.0095), SLOT_POSITION + Vector3(0.0, 0.0351, 0.0), black)
	HouseProps.add_box(plate, "SlotWindow", Vector3(0.05, 0.026, 0.002), SLOT_POSITION + Vector3(0.0, -0.005, 0.0208), black)
	_flap = Node3D.new()
	_flap.name = "FlapHinge"
	_flap.position = SLOT_POSITION + Vector3(0.0, -0.001, 0.0222)
	plate.add_child(_flap)
	HouseProps.add_box(_flap, "Flap", Vector3(0.046, 0.022, 0.002), Vector3(0.0, -0.011, 0.0), brass)

	# The armoured cord leaves the unit's underside, under the handset.
	cord_anchor = Node3D.new()
	cord_anchor.name = "CordAnchor"
	cord_anchor.position = CORD_OUTLET
	add_child(cord_anchor)


## The handset, hanging by its cord from the port at its bottom end (as it sits on its hook, turned upside down): the model with its port at the
## pivot. The coiled cord joins the unit to the port.
func _build_receiver() -> void:
	receiver = Node3D.new()
	receiver.name = "Receiver"
	receiver.transform = get_hook_pose()
	add_child(receiver)

	# In the receiver's own frame the port is the origin and the handset hangs below it (the hanging pose is the identity); the model has it on
	# its hook, so it is turned over (half a round about X) after the quarter turn of the whole booth.
	var handset: Node3D = HANDSET_SCENE.instantiate() as Node3D
	handset.name = "Handset"
	var turn: Basis = Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, -PI * 0.5)
	handset.transform = Transform3D(turn, -(turn * HANDSET_PORT_IN_FILE))
	receiver.add_child(handset)

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
	close_up_camera.position = Vector3(0.0, 1.5, 0.72)
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
