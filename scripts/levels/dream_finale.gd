extends Node
class_name DreamFinale

## The end of the dream intro: what happens when the call at the overlook is over.
##
## 1. **The blackout.** In complete silence the city goes out over `blackout_seconds` (its halos and its
##    lit windows die in a wave that crawls across the valley from the far side towards the overlook),
##    the streetlamp flickers once and dies, and the world loses all its light (`blackout` on the night
##    environment). The player can look around but not walk.
## 2. **The wagon.** In the dark the player is moved to where the dream began, in the wagon, and heavy
##    rain pounds the roof. It is almost black: the ceiling lights only stutter, the flashlight is weak,
##    the way out behind is locked, and at the far end of the aisle, against the north wall, a girl
##    (Sophia) sits on the floor hugging her knees, sobbing. The player can only walk forward and back
##    along the aisle (the move keys) and look around, and the walk ends about `stop_before_sophia`
##    metres from her: they cannot get closer.
## 3. **The whisper and the fakeout.** Stopped there, a whisper comes from right behind the player's head
##    ("You're not supposed to be here."). When they look back the sobbing stops and the wagon behind them
##    is empty. When they turn back to her the girl is gone, and on the floorboards where she sat lies a
##    ticket with a faint glow of its own and `[E] Take Ticket` (the walk now reaches it).
## 4. **The grab.** The moment they take it, black hands claw in from behind: a loud impact, the view
##    thrown back and cut to black. Pitch black for `black_hold` seconds, then the UNRAILED title card in
##    in the palette, plain like the menu's, and back to the main menu. The save is marked `demo_complete` and keeps the player at the
##    overlook with the three fichas in the slot, so Continue lets them make the call again.
##
## Everything is placeholder art and sound (the girl, the hands and every sound are made in code).

## The title card has been shown and the game is about to return to the menu.
signal finished
signal title_shown

enum Stage {
	IDLE,
	BLACKOUT,
	APPROACH,
	WHISPERED,
	SWAPPED,
	GRABBED,
	TITLE,
	DONE,
}

const STATE_SECTION: StringName = &"puzzles"
const KEY_DEMO_COMPLETE: StringName = &"demo_complete"
const KEY_CALL_DONE: StringName = &"orelhao_call_done"
const LINE_WHISPER: String = "CAPTION_WAGON_WHISPER"

@export_category("Scene")
## The overlook payphone: its `sequence_completed` (the call is over, the view is back) starts the finale.
@export var phone: OverlookPhoneSequence
## The node that has the night environment script (its `blackout` takes the light out of the world).
@export var night: Node
## The town in the valley (its `NightGlow` halos and its lit windows go out).
@export var town: Node3D
## The wagon the finale happens in.
@export var wagon: Node3D
## Set when the player is not the node found by group "player".
@export var player: Node3D
@export_file("*.tscn") var main_menu_path: String = "res://scenes/menu/main_menu.tscn"
## Off, the finale ends with `finished` and stays where it is (for tests).
@export var change_scene_at_end: bool = true
## The scene the saved snapshot belongs to; empty is the running scene.
@export var save_scene_path: String = ""

@export_category("Blackout")
@export var blackout_seconds: float = 3.0
## The streetlamp dies this far through the blackout (0 to 1).
@export_range(0.0, 1.0, 0.05) var lamp_dies_at: float = 0.6
## Pitch black, before the player is moved.
@export var dark_hold_seconds: float = 1.2

@export_category("Wagon")
## In the wagon's own space (X across, Z along the aisle): where the player appears (the very spot the
## dream began at), and the floor point where the girl sits.
@export var wagon_start_local: Vector3 = Vector3(-0.18, 0.7657, 3.1)
@export var sophia_local: Vector3 = Vector3(0.0, 0.073, -5.55)
## How far back the player can walk (the locked door), how close to her they can get (the walk ends
## there until the fakeout has played), and how close to the ticket they can get afterwards.
@export var back_limit: float = 0.5
@export var stop_before_sophia: float = 2.0
@export var stop_before_ticket: float = 0.8
## The whisper comes when they are this near (just before the walk ends).
@export var whisper_distance: float = 2.3
## If they never look away, the girl goes anyway after this long (never a stuck player).
@export var fakeout_timeout_seconds: float = 12.0
## The ceiling lights are dim, cold and always stuttering; the flashlight is a fraction of its usual strength.
@export var wagon_light_color: Color = Color(0.72, 0.82, 1.0)
@export var wagon_light_energy: float = 0.1
@export_range(0.05, 1.0, 0.05) var flashlight_strength: float = 0.3
@export var rain_db: float = -7.0

@export_category("The grab")
## The picture goes black this long after the impact.
@export var grab_black_after_seconds: float = 0.5
@export var black_hold_seconds: float = 1.5
@export var title_fade_in_seconds: float = 1.4
@export var title_hold_seconds: float = 3.2
@export var title_fade_out_seconds: float = 1.0

var stage: Stage = Stage.IDLE

var _player: Node3D = null
var _snapshot: Dictionary = {}
var _master_db: float = 0.0
var _master_saved: bool = false
var _rain: AudioStreamPlayer = null
var _sobbing: AudioStreamPlayer3D = null
var _sophia: Node3D = null
var _rock: Node3D = null
var _ticket: FinaleTicket = null
var _wagon_lights: Array[OmniLight3D] = []
var _light_time: float = 0.0
var _light_timers: Array[float] = []
var _light_levels: Array[float] = []
var _flashlight_before: Dictionary = {}
var _corridor_length: float = 0.0
var _whisper_time: float = 0.0
var _looked_away: bool = false
var _black_layer: CanvasLayer = null
var _black_rect: ColorRect = null

# The city going out.
var _glow: MultiMeshInstance3D = null
var _glow_base: PackedFloat32Array = PackedFloat32Array()
var _glow_stride: int = 16
var _glow_start: PackedFloat32Array = PackedFloat32Array()
var _windows: Array[Dictionary] = []


func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	if phone != null:
		phone.sequence_completed.connect(start)


func _exit_tree() -> void:
	_restore_master()
	_restore_flashlight()


# ============================================================
# 1. THE BLACKOUT
# ============================================================

## Begins the finale (the call is over).
func start() -> void:
	if stage != Stage.IDLE:
		return

	stage = Stage.BLACKOUT
	_player = _get_player()
	if _player != null and _player.has_method("get_manual_save_state"):
		_snapshot = _player.call("get_manual_save_state")

	_set_saving_blocked(true)
	_cut_flashlight(false)
	_prepare_town_dimmer()

	# Complete silence, and the world's light going out, both over the blackout.
	_master_db = AudioServer.get_bus_volume_db(0)
	_master_saved = true
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_method(_set_master_db, _master_db, -80.0, 0.6)
	fade.tween_method(_set_blackout_progress, 0.0, 1.0, blackout_seconds)

	_lamp_dies_later()
	await fade.finished
	_set_blackout_progress(1.0)
	await _wait(dark_hold_seconds)
	_enter_wagon()


func _lamp_dies_later() -> void:
	await _wait(blackout_seconds * lamp_dies_at)
	if phone != null and phone.lamp != null:
		phone.lamp.play_flicker(&"die")


func _set_blackout_progress(progress: float) -> void:
	if night != null:
		night.set("blackout", progress)

	_dim_town(progress)


func _set_master_db(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)


func _restore_master() -> void:
	if _master_saved:
		AudioServer.set_bus_volume_db(0, _master_db)
		_master_saved = false


## Gets the town's two kinds of light ready to go out: the halo billboards (one multimesh, each with its
## own colour, faded in a wave from the far side of the valley to the near one) and the emissive windows
## (their materials copied per mesh so nothing shared is ever changed).
func _prepare_town_dimmer() -> void:
	if town == null:
		return

	var viewer: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	_prepare_glow(viewer)

	_windows.clear()
	var meshes: Array[Node] = town.find_children("*", "MeshInstance3D", true, false)
	var ranked: Array[Vector2] = []
	for i: int in meshes.size():
		ranked.append(Vector2(-(meshes[i] as MeshInstance3D).global_position.distance_to(viewer), float(i)))
	ranked.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for rank: int in ranked.size():
		var mesh_instance: MeshInstance3D = meshes[int(ranked[rank].y)] as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.get_active_material(surface)
			if source is StandardMaterial3D and (source as StandardMaterial3D).emission_enabled:
				var copy_material: StandardMaterial3D = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
				mesh_instance.set_surface_override_material(surface, copy_material)
				_windows.append({
					"material": copy_material,
					"energy": copy_material.emission_energy_multiplier,
					"start": float(rank) / float(maxi(ranked.size(), 1)) * 0.7,
				})


## The halo billboards: their multimesh is copied (the town's own data is never changed) and each halo gets
## the moment the wave reaches it, the far ones first. Needs the multimesh's buffer, which only exists
## with a renderer; without one the halos are simply left alone.
func _prepare_glow(viewer: Vector3) -> void:
	_glow = town.find_child("NightGlow", true, false) as MultiMeshInstance3D
	_glow_base = PackedFloat32Array()
	if _glow == null or _glow.multimesh == null or not _glow.multimesh.use_colors:
		return

	# Without a renderer the multimesh keeps no buffer to dim (and copying it would only complain).
	if _glow.multimesh.buffer.is_empty():
		return

	var copy: MultiMesh = _glow.multimesh.duplicate() as MultiMesh
	_glow.multimesh = copy
	var count: int = copy.instance_count
	var base: PackedFloat32Array = copy.buffer.duplicate()
	_glow_stride = base.size() / maxi(count, 1)
	if _glow_stride < 16:
		return

	_glow_base = base
	var order: Array[Vector2] = []
	for i: int in count:
		var at: Vector3 = Vector3(_glow_base[i * _glow_stride + 3], _glow_base[i * _glow_stride + 7], _glow_base[i * _glow_stride + 11])
		order.append(Vector2(-(_glow.to_global(at)).distance_to(viewer), float(i)))
	order.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	_glow_start.resize(count)
	for rank: int in order.size():
		# The wave covers the first 70% of the blackout; each light then fades over the last 30%.
		_glow_start[int(order[rank].y)] = float(rank) / float(maxi(count, 1)) * 0.7


## 0 (all lit) to 1 (all dark): each light goes out when the wave reaches it.
func _dim_town(progress: float) -> void:
	if _glow != null and not _glow_base.is_empty():
		var buffer: PackedFloat32Array = _glow_base.duplicate()
		var count: int = _glow_start.size()
		for i: int in count:
			var out: float = clampf((progress - _glow_start[i]) / 0.3, 0.0, 1.0)
			var alpha_at: int = i * _glow_stride + _glow_stride - 1
			buffer[alpha_at] = _glow_base[alpha_at] * (1.0 - out)
		_glow.multimesh.buffer = buffer

	for window: Dictionary in _windows:
		var out_amount: float = clampf((progress - float(window["start"])) / 0.3, 0.0, 1.0)
		(window["material"] as StandardMaterial3D).emission_energy_multiplier = float(window["energy"]) * (1.0 - out_amount)


# ============================================================
# 2. THE WAGON
# ============================================================

func _enter_wagon() -> void:
	if wagon == null or _player == null:
		return

	stage = Stage.APPROACH
	_restore_master()
	_start_rain()
	_prepare_wagon()

	var start_world: Vector3 = wagon.to_global(wagon_start_local)
	var sophia_world: Vector3 = wagon.to_global(sophia_local)
	var along: Vector3 = Vector3(sophia_world.x - start_world.x, 0.0, sophia_world.z - start_world.z)
	var total: float = along.length()
	_corridor_length = total
	along = along.normalized()

	_player.global_position = start_world
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO

	var movement: Node = _player.get("movement_controller") as Node
	if movement != null:
		# Turned along the aisle, towards her.
		movement.set("look_yaw", -rad_to_deg(atan2(-along.x, -along.z)))
		movement.set("look_pitch", -4.0)
		movement.call("lock_to_corridor", start_world, along, -back_limit, maxf(total - stop_before_sophia, 0.5))

	if _player.has_method("release_movement_hold"):
		_player.call("release_movement_hold")

	_cut_flashlight(false)
	_weaken_flashlight()
	var flashlight: Node = _player.get("flashlight_controller") as Node
	if flashlight != null and flashlight.has_method("set_flashlight_input_enabled"):
		flashlight.call("set_flashlight_input_enabled", true)
		# On from the start: it is nearly all there is to see by.
		if flashlight.has_method("turn_on"):
			flashlight.call("turn_on")

	set_physics_process(true)
	set_process(true)


func _start_rain() -> void:
	_rain = AudioStreamPlayer.new()
	_rain.name = "RoofRain"
	_rain.stream = PlaceholderAudio.make_roof_rain()
	_rain.volume_db = -50.0
	add_child(_rain)
	_rain.play()
	create_tween().tween_property(_rain, "volume_db", rain_db, 2.0)


## The wagon is nearly black (the ceiling lights only stutter), and a girl sits sobbing at the far end.
func _prepare_wagon() -> void:
	_wagon_lights.clear()
	var lights: Node = wagon.get_node_or_null("Lights")
	if lights != null:
		for child: Node in lights.get_children():
			if child is OmniLight3D:
				var light: OmniLight3D = child as OmniLight3D
				light.visible = true
				light.light_color = wagon_light_color
				light.light_energy = 0.0
				_wagon_lights.append(light)
				_light_timers.append(0.0)
				_light_levels.append(0.0)

	_sophia = _build_sophia()
	_sophia.position = sophia_local
	wagon.add_child(_sophia)

	_sobbing = AudioStreamPlayer3D.new()
	_sobbing.name = "Sobbing"
	_sobbing.stream = PlaceholderAudio.make_sobbing()
	_sobbing.volume_db = -3.0
	_sobbing.unit_size = 3.0
	_sobbing.position = Vector3(0.0, 0.5, 0.0)
	_sophia.add_child(_sobbing)
	_sobbing.play()


## A girl sitting on the floor with her arms round her knees and her head down, built from primitives.
## She faces +Z (towards where the player comes from). `_rock` is what rocks as she cries.
func _build_sophia() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Sophia"
	_rock = Node3D.new()
	_rock.name = "Rock"
	_rock.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(_rock)

	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = Color(0.17, 0.2, 0.32)
	cloth.roughness = 0.95
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = Color(0.55, 0.42, 0.38)
	skin.roughness = 0.9
	var hair: StandardMaterial3D = StandardMaterial3D.new()
	hair.albedo_color = Color(0.05, 0.04, 0.04)
	hair.roughness = 1.0

	_add_part(_rock, "Torso", _capsule(0.14, 0.52), Vector3(0.0, 0.28, -0.1), Vector3(-28.0, 0.0, 0.0), cloth)
	_add_part(_rock, "Knees", _capsule(0.085, 0.4), Vector3(0.0, 0.34, 0.2), Vector3(0.0, 0.0, 90.0), cloth)
	_add_part(_rock, "Shins", _capsule(0.07, 0.42), Vector3(0.0, 0.13, 0.32), Vector3(-80.0, 0.0, 0.0), cloth)
	for x: float in [-0.13, 0.13]:
		_add_part(_rock, "Arm%s" % ("L" if x < 0.0 else "R"), _capsule(0.048, 0.42), Vector3(x, 0.4, 0.1), Vector3(62.0, 0.0, 0.0), cloth)

	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.1
	head.height = 0.2
	_add_part(_rock, "Head", head, Vector3(0.0, 0.5, 0.13), Vector3.ZERO, skin)
	var scalp: SphereMesh = SphereMesh.new()
	scalp.radius = 0.108
	scalp.height = 0.216
	var hair_part: MeshInstance3D = _add_part(_rock, "Hair", scalp, Vector3(0.0, 0.52, 0.11), Vector3.ZERO, hair)
	hair_part.scale = Vector3(1.05, 1.0, 1.12)
	return root


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _add_part(parent: Node3D, part_name: String, mesh: Mesh, at: Vector3, degrees: Vector3, material: Material) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = at
	part.rotation_degrees = degrees
	part.material_override = material
	parent.add_child(part)
	return part


## Each ceiling light is a failing bulb: it holds a dim level for a while, then stutters (dark, a
## weak flash, dark again) before settling. They are never in step with each other.
func _flicker_lights(delta: float) -> void:
	for i: int in _wagon_lights.size():
		_light_timers[i] -= delta
		if _light_timers[i] <= 0.0:
			if randf() < 0.45:
				# A stutter: a very short beat, mostly dark.
				_light_timers[i] = randf_range(0.03, 0.16)
				_light_levels[i] = 0.0 if randf() < 0.7 else randf_range(0.5, 1.0)
			else:
				_light_timers[i] = randf_range(0.5, 2.6)
				_light_levels[i] = randf_range(0.0, 1.0) if randf() < 0.25 else randf_range(0.45, 0.85)

		_wagon_lights[i].light_energy = wagon_light_energy * _light_levels[i]


## The flashlight is weak here (its strength and its reach are cut), and given back at the end.
func _weaken_flashlight() -> void:
	var flashlight: SpotLight3D = _player.get("flashlight_controller") as SpotLight3D
	if flashlight == null or not _flashlight_before.is_empty():
		return

	var fill: SpotLight3D = flashlight.get_node_or_null("FlashlightFill") as SpotLight3D
	_flashlight_before = {
		"energy": flashlight.light_energy,
		"range": flashlight.spot_range,
		"fill_energy": fill.light_energy if fill != null else 0.0,
	}
	flashlight.light_energy *= flashlight_strength
	flashlight.spot_range = minf(flashlight.spot_range, 9.0)
	if fill != null:
		fill.light_energy *= flashlight_strength


func _restore_flashlight() -> void:
	if _flashlight_before.is_empty() or _player == null or not is_instance_valid(_player):
		return

	var flashlight: SpotLight3D = _player.get("flashlight_controller") as SpotLight3D
	if flashlight != null:
		flashlight.light_energy = float(_flashlight_before["energy"])
		flashlight.spot_range = float(_flashlight_before["range"])
		var fill: SpotLight3D = flashlight.get_node_or_null("FlashlightFill") as SpotLight3D
		if fill != null:
			fill.light_energy = float(_flashlight_before["fill_energy"])

	_flashlight_before = {}


func _process(delta: float) -> void:
	_light_time += delta
	_flicker_lights(delta)

	# She rocks as she sobs.
	if _rock != null and is_instance_valid(_rock) and _sophia != null and _sophia.visible:
		_rock.rotation_degrees.x = sin(_light_time * 1.1) * 2.2
		_rock.scale = Vector3.ONE * (1.0 + 0.012 * sin(_light_time * 7.5))


func _physics_process(delta: float) -> void:
	match stage:
		Stage.APPROACH:
			if _distance_to_sophia() <= whisper_distance:
				_whisper()
		Stage.WHISPERED:
			_watch_for_the_turn(delta)


# ============================================================
# 3. THE WHISPER AND THE FAKEOUT
# ============================================================

func _distance_to_sophia() -> float:
	var here: Vector3 = _player.global_position
	var there: Vector3 = _sophia.global_position
	return Vector2(here.x - there.x, here.z - there.z).length()


## A whisper from right behind the player's head.
func _whisper() -> void:
	stage = Stage.WHISPERED
	_whisper_time = 0.0
	_looked_away = false

	var camera: Camera3D = _camera()
	var behind: Vector3 = camera.global_basis.z
	behind.y = 0.0
	var whisper: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	whisper.name = "Whisper"
	whisper.stream = PlaceholderAudio.make_whisper()
	whisper.volume_db = 4.0
	whisper.unit_size = 1.2
	add_child(whisper)
	whisper.global_position = camera.global_position + behind.normalized() * 0.3
	whisper.finished.connect(whisper.queue_free)
	whisper.play()
	CaptionManager.say(LINE_WHISPER)


## How far the view is from pointing at her, in degrees (flat).
func _look_angle_to_sophia() -> float:
	var camera: Camera3D = _camera()
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	var to_her: Vector3 = _sophia.global_position - camera.global_position
	to_her.y = 0.0
	return rad_to_deg(forward.angle_to(to_her))


## Stopped short of her, the player is held until they look behind them (the crying stops, the wagon
## there is empty) and turn back: she is gone, and the walk reaches the ticket.
func _watch_for_the_turn(delta: float) -> void:
	_whisper_time += delta
	var angle: float = _look_angle_to_sophia()
	if angle > 110.0:
		if not _looked_away:
			_looked_away = true
			_sobbing.stop()
	elif _looked_away and angle < 40.0:
		_swap(false)
		return

	# Someone who never looks away still loses her after a while (never a player stuck for good).
	if _whisper_time > fakeout_timeout_seconds:
		_swap(true)


## The girl is gone and a ticket lies where she sat. `flicker`: the lights stutter out and in as it happens
## (when the player has not looked away, so it is never seen).
func _swap(flicker: bool) -> void:
	stage = Stage.SWAPPED
	if flicker:
		for light: OmniLight3D in _wagon_lights:
			light.visible = false
		await _wait(0.3)

	_sophia.visible = false
	_sobbing.stop()
	_ticket = FinaleTicket.new()
	_ticket.name = "Ticket"
	wagon.add_child(_ticket)
	_ticket.position = Vector3(sophia_local.x, sophia_local.y, sophia_local.z)
	_ticket.taken.connect(_on_ticket_taken)

	# The walk now reaches the ticket.
	var movement: Node = _player.get("movement_controller") as Node
	if movement != null:
		movement.call("set_corridor_limits", -back_limit, _corridor_length - stop_before_ticket)

	if flicker:
		for light: OmniLight3D in _wagon_lights:
			light.visible = true


# ============================================================
# 4. THE GRAB AND THE TITLE
# ============================================================

func _on_ticket_taken() -> void:
	stage = Stage.GRABBED
	var movement: Node = _player.get("movement_controller") as Node
	if movement != null:
		movement.call("release_corridor")

	if _player.has_method("hold_movement"):
		_player.call("hold_movement", 600.0)

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "GrabLayer"
	layer.layer = 110
	add_child(layer)
	var overlay: FinaleGrabOverlay = FinaleGrabOverlay.new()
	layer.add_child(overlay)

	# The impact: as loud as it gets, the view thrown back as if dragged by the shoulders.
	var impact: AudioStreamPlayer = AudioStreamPlayer.new()
	impact.stream = PlaceholderAudio.make_grab_impact()
	impact.volume_db = 6.0
	add_child(impact)
	impact.play()

	var camera: Camera3D = _camera()
	var fov_before: float = camera.fov
	var snap: Tween = create_tween().set_parallel(true)
	if movement != null:
		snap.tween_property(movement, "gesture_offset", Vector3(0.0, 0.08, 0.75), 0.12)
		snap.tween_property(movement, "gesture_pitch_degrees", 32.0, 0.12)
		snap.tween_property(movement, "gesture_roll_degrees", 14.0, 0.12)
	snap.tween_property(camera, "fov", fov_before + 22.0, 0.12)
	snap.tween_property(overlay, "grab", 1.0, grab_black_after_seconds * 0.9)

	await _wait(grab_black_after_seconds)

	# Black, and not a sound.
	_make_black(1.0)
	if _rain != null:
		_rain.stop()
	if _sobbing != null:
		_sobbing.stop()
	layer.queue_free()
	await _wait(black_hold_seconds)
	await _show_title()
	_finish()


## Covers the screen with black at once (`alpha` 1) or not at all.
func _make_black(alpha: float) -> void:
	if _black_layer == null:
		_black_layer = CanvasLayer.new()
		_black_layer.name = "BlackLayer"
		_black_layer.layer = 115
		add_child(_black_layer)
		_black_rect = ColorRect.new()
		_black_rect.color = Color.BLACK
		_black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_black_layer.add_child(_black_rect)

	_black_rect.modulate.a = alpha


## The UNRAILED title card over the black: the word alone, as on the main menu (its theme variation, so
## the same font and palette colour; no glow, no rules).
func _show_title() -> void:
	stage = Stage.TITLE
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TitleCard"
	layer.layer = 120
	add_child(layer)

	var card: Control = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	layer.add_child(card)

	var screen: Vector2 = get_viewport().get_visible_rect().size
	var title: Label = Label.new()
	title.name = "Title"
	title.theme_type_variation = &"TitleLabel"
	title.text = tr("TITLE_CARD_TEXT")
	title.add_theme_font_size_override(&"font_size", int(screen.y * 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)

	var fade_in: Tween = create_tween()
	fade_in.tween_property(card, "modulate:a", 1.0, title_fade_in_seconds)
	await fade_in.finished
	title_shown.emit()
	await _wait(title_hold_seconds)
	var fade_out: Tween = create_tween()
	fade_out.tween_property(card, "modulate:a", 0.0, title_fade_out_seconds)
	await fade_out.finished


## The end: the save is marked finished, and keeps the player at the overlook with the fichas in the
## slot and the call still to make; then the main menu.
func _finish() -> void:
	stage = Stage.DONE
	SaveManager.set_state_value(STATE_SECTION, KEY_DEMO_COMPLETE, true)
	# So that Continue lets the player make the call again.
	SaveManager.set_state_value(STATE_SECTION, KEY_CALL_DONE, false)
	if SaveManager.has_active_game() and not _snapshot.is_empty():
		var scene_path: String = save_scene_path
		if scene_path.is_empty() and get_tree().current_scene != null:
			scene_path = get_tree().current_scene.scene_file_path

		if not scene_path.is_empty():
			SaveManager.save_manual_game(scene_path, _snapshot)

	_restore_master()
	_restore_flashlight()
	finished.emit()
	if not change_scene_at_end:
		return

	GameSettings.save_settings()
	SaveManager.suspend_session()
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(main_menu_path)


# ============================================================
# HELPERS
# ============================================================

func _get_player() -> Node3D:
	if player != null:
		return player

	return get_tree().get_first_node_in_group(&"player") as Node3D


func _camera() -> Camera3D:
	return _player.get_node("Head/Camera3D") as Camera3D


## Puts the flashlight out; `allow` says whether the player may switch it on again.
func _cut_flashlight(allow: bool) -> void:
	if _player == null:
		return

	var flashlight: Node = _player.get("flashlight_controller") as Node
	if flashlight == null:
		return

	if flashlight.has_method("turn_off"):
		flashlight.call("turn_off")

	if not allow and flashlight.has_method("set_flashlight_input_enabled"):
		flashlight.call("set_flashlight_input_enabled", false)


func _set_saving_blocked(blocked: bool) -> void:
	if _player != null and _player.has_method("set_manual_save_blocked"):
		_player.call("set_manual_save_blocked", blocked)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
