extends Node
class_name OutdoorAmbience

## The forest at night, heard all through the game outside, and through the walls inside.
##
## Done the way big games do ambience, at our scale:
##
## - **A bed and spots.** The wind recording (`stream`, wind with crickets and leaves in it) is split by pitch. Its low part is a 2D bed:
##   the wind all round, which does not move as the player does (`OutdoorAmbienceBed` bus, low pass at `bed_cutoff_hz`). Its high part (the
##   crickets, the rustle of leaves) is played by `detail_emitters` 3D emitters fixed in the world on a grid round the player
##   (`OutdoorAmbienceDetail` bus, high pass at `detail_cutoff_hz`). The night recording (`night_stream`, the chorus of insects and the
##   leaves, mostly high) is played whole by a second grid, `night_emitters` (`OutdoorAmbienceNight` bus), spaced differently. Walking or
##   running, the spots are passed by, and come up ahead: one left far behind is moved to a place ahead, silently (it is far), and fades
##   in there. Each plays from its own point of its recording.
## - **A forest that changes as it is walked.** One value, `wind_weight` (1 windy, 0 deep woods), sets how the two recordings are mixed:
##   near the `open_places` (the wagon, the fig clearing, the overlook: open sky) the wind is strong and the night chorus thin; deep in the
##   woods, away from them, the other way round (from `open_inner_radius` to `open_outer_radius`). A slow noise over the map
##   (`variation`, on a `variation_scale` metres pattern) moves it a little either way as the player goes, so no two stretches of the
##   forest sound quite the same. It changes over `mix_smoothing_seconds`.
## - **Inside, by how open the place is.** Everything goes through the `OutdoorAmbience` bus (sent to Master, so the volume setting governs
##   it), whose low pass filter and level are set by one value, `interior` (0 outside, 1 shut in): the outside heard through walls loses
##   its highs and some level, muffled, not gone. Inside an `AmbienceZone` (the wagon, the unfinished house, the signal tower's rooms)
##   that value is the zone's `interior` times how enclosed the listener is right there, measured with rays (a few each frame, round a
##   ring and up): the share of them that leave the building through a window, a door that stands open, a broken pane or a hole in the
##   roof. By a window or in a doorway (`open_full` of them out) it is all but the outside; in the middle of a closed room, muffled. A
##   shut door blocks its rays, so opening it lets the outside in.
## - **Requests.** Muffle requests by name (`set_muffle`), for scenes that push the world back under them (the overlook call), called with
##   `get_tree().call_group(OutdoorAmbience.GROUP, "set_muffle", name, amount)`; and the pause menu and any cutscene that freezes the
##   player (`cutscene_frozen`).
##
## The largest of them wins, and `interior` moves towards it over `transition_seconds`, never in a jump, except when the listener is moved
## further than `teleport_distance` in one frame (a cut to another place): then it is set at once (the rays all cast again, the mix too),
## so the wind does not "arrive" from outside after the cut. The whole fades in at the start of the scene.

const GROUP: StringName = &"outdoor_ambience"
const BUS_NAME: StringName = &"OutdoorAmbience"
const BED_BUS_NAME: StringName = &"OutdoorAmbienceBed"
const DETAIL_BUS_NAME: StringName = &"OutdoorAmbienceDetail"
const NIGHT_BUS_NAME: StringName = &"OutdoorAmbienceNight"
const NO_CELL: Vector2i = Vector2i(2147483647, 0)

## The wind (`placeholder_windy_forest`) and the night chorus (`placeholder_night_forest`).
@export var stream: AudioStream
@export var night_stream: AudioStream

@export_category("Levels")
## The bed's level outside at full wind (the placeholder recording is quiet: about -43 LUFS).
@export var outdoor_volume_db: float = 2.0
## Each wind emitter's level at `detail_unit_size` metres, and each night emitter's at `night_unit_size`.
@export var detail_volume_db: float = 3.0
@export var night_volume_db: float = 2.0
## How much quieter it all is fully inside, on top of the filter.
@export var inside_volume_db: float = -6.0
@export var fade_in_seconds: float = 3.0

@export_category("Bed and spots")
## The bed keeps the wind below this; the wind emitters keep the crickets and leaves above `detail_cutoff_hz`.
@export var bed_cutoff_hz: float = 2500.0
@export var detail_cutoff_hz: float = 3000.0
## The wind emitters: how many (a square grid round the player), how far apart, how loud close up and how far they carry.
@export var detail_emitters: int = 9
@export var detail_spacing: float = 14.0
@export var detail_unit_size: float = 5.0
@export var detail_max_distance: float = 30.0
## The night emitters, the same way.
@export var night_emitters: int = 9
@export var night_spacing: float = 18.0
@export var night_unit_size: float = 7.0
@export var night_max_distance: float = 40.0
@export var detail_fade_seconds: float = 1.5

@export_category("The forest's mix")
## Places with open sky round them, where the wind is strongest (the wagon, the fig clearing, the overlook).
@export var open_places: Array[Node3D] = []
## Within the inner radius of one the wind is full; past the outer one, the deep woods.
@export var open_inner_radius: float = 15.0
@export var open_outer_radius: float = 70.0
## How much the mix moves either way with the slow noise over the map, and how big its patches are.
@export_range(0.0, 0.5, 0.05) var variation: float = 0.25
@export var variation_scale: float = 60.0
## The gain of each recording at the two ends of the mix: at full wind the night is thin, deep in the woods the wind is.
@export_range(0.0, 1.0, 0.05) var night_at_full_wind: float = 0.3
@export_range(0.0, 1.0, 0.05) var wind_in_deep_woods: float = 0.45
@export var mix_smoothing_seconds: float = 2.0

@export_category("Inside")
@export var open_cutoff_hz: float = 20000.0
## The cutoff fully inside: the wind through walls loses its hiss but is still plainly there.
@export var inside_cutoff_hz: float = 1500.0
## The share of rays leaving the building at which the outside is heard in full (a window close by, a doorway).
@export_range(0.05, 1.0, 0.05) var open_full: float = 0.25
## How fast a little openness lets the outside in: below 1 the first rays out count most (a door a few steps away is already heard well).
@export_range(0.2, 1.0, 0.05) var open_curve: float = 0.6
## Openness below this counts as none: a crack a ray slips through now and then is not a window.
@export_range(0.0, 0.1, 0.005) var open_floor: float = 0.02
## The measured openness is an average over about this long (the rays are jittered, so it changes smoothly as the listener moves).
@export var openness_smoothing_seconds: float = 0.3
## How far a ray looks for a wall, and how many are cast each frame.
@export var ray_length: float = 15.0
@export var rays_per_frame: int = 12

@export_category("Changes")
@export var transition_seconds: float = 0.6
## A cut to another place moves the listener at least this far in one frame.
@export var teleport_distance: float = 4.0
## How muffled the world is while the game is paused, and during a cutscene that freezes the player. The cutscene's is slight: the
## muffle is a low pass, and the night chorus (crickets, leaves) is high, so a heavy one silences it and leaves only the wind (the
## dream intro's head lift sounded like that until the cutscene ended).
## How long the outside takes to go silent or come back when a scene asks (`set_silenced`).
@export var silence_fade_seconds: float = 1.0
@export_range(0.0, 1.0, 0.05) var pause_muffle: float = 0.75
@export_range(0.0, 1.0, 0.05) var cutscene_muffle: float = 0.15

## The current amount (0 outside, 1 shut in), and the one it is moving towards.
var interior: float = 0.0
var target_interior: float = 0.0
## The share of rays that left the building, last measured (1 outside a zone).
var openness: float = 1.0
## The forest's mix right now (1 windy, 0 deep woods), and where the listener's place would put it.
var wind_weight: float = 1.0
var target_wind_weight: float = 1.0

## The bed, its filter, and the two grids of emitters (their players: `emitters` the wind's, `night_players` the night's).
var player: AudioStreamPlayer = null
var filter: AudioEffectLowPassFilter = null
var emitters: Array[AudioStreamPlayer3D] = []
var night_players: Array[AudioStreamPlayer3D] = []
var wind_grid: EmitterGrid = null
var night_grid: EmitterGrid = null

var _muffles: Dictionary = {}
## Scenes that ask for the outside to be silent (`set_silenced`), and how silent it is now (0 to 1, moving over `silence_fade_seconds`).
var _silenced: Dictionary = {}
var _silence: float = 0.0
var _fade: float = 0.0
var _listener_known: bool = false
var _last_listener: Vector3 = Vector3.ZERO
var _made_buses: Array[StringName] = []
var _directions: Array[Vector3] = []
var _slices: PackedFloat32Array = PackedFloat32Array()
var _escaped: PackedByteArray = PackedByteArray()
var _next_ray: int = 0
var _noise: FastNoiseLite = null


## A square of 3D emitters on a world grid round the listener, all playing one recording on one bus, each from its own point of it. The
## grid moves cell by cell: emitters whose cells fall out of the square go to the cells that came in, and fade in there.
class EmitterGrid:
	extends RefCounted

	var players: Array[AudioStreamPlayer3D] = []
	var cells: Array[Vector2i] = []
	var fades: PackedFloat32Array = PackedFloat32Array()
	var spacing: float = 14.0
	var salt: int = 0
	var centre: Vector2i = NO_CELL

	func _init(owner: Node, recording: AudioStream, bus: StringName, count: int, cell_size: float, unit_size: float, max_distance: float, seed_salt: int, label: String) -> void:
		spacing = cell_size
		salt = seed_salt
		for i: int in count:
			var emitter: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			emitter.name = "%s%d" % [label, i]
			emitter.stream = recording
			emitter.bus = bus
			emitter.unit_size = unit_size
			emitter.max_distance = max_distance
			emitter.attenuation_filter_db = -12.0
			emitter.volume_db = -80.0
			emitter.process_mode = Node.PROCESS_MODE_ALWAYS
			owner.add_child(emitter)
			players.append(emitter)
			cells.append(Vector2i(NO_CELL.x, i))
			fades.append(0.0)

	## Keeps the emitters on the cells round the listener. `spot` gives the place in a cell.
	func place(listener: Vector3, cut: bool, spot: Callable, offset: Callable) -> void:
		if players.is_empty():
			return

		var here: Vector2i = Vector2i(floori(listener.x / spacing), floori(listener.z / spacing))
		if here == centre and not cut:
			return

		# The very first placing is heard at once (the whole fades in anyway); later ones fade in where they are put.
		var first: bool = centre.x == NO_CELL.x
		centre = here
		var side: int = maxi(1, int(round(sqrt(float(players.size())))))
		var low: int = -int(floor(float(side - 1) * 0.5))
		var wanted: Array[Vector2i] = []
		for dz: int in side:
			for dx: int in side:
				wanted.append(here + Vector2i(low + dx, low + dz))

		var free: Array[int] = []
		for i: int in players.size():
			var at: int = wanted.find(cells[i])
			if at >= 0:
				wanted.remove_at(at)
			else:
				free.append(i)

		for i: int in free:
			if wanted.is_empty():
				break

			var cell: Vector2i = wanted.pop_front()
			cells[i] = cell
			players[i].global_position = spot.call(cell, spacing, salt, listener.y)
			fades[i] = 1.0 if first else 0.0
			players[i].volume_db = -80.0
			if not players[i].playing:
				players[i].play(float(offset.call()))

	## Brings each emitter towards full and sets its level: `volume_db` for all, plus its own fade.
	func update(delta: float, fade_seconds: float, volume_db: float) -> void:
		for i: int in players.size():
			fades[i] = minf(fades[i] + delta / fade_seconds, 1.0) if fade_seconds > 0.0 else 1.0
			players[i].volume_db = volume_db + linear_to_db(maxf(fades[i], 0.0001))

	func stop() -> void:
		for emitter: AudioStreamPlayer3D in players:
			emitter.stop()


func _ready() -> void:
	add_to_group(GROUP)
	# The forest goes on, muffled, under the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	_make_directions()
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = 1988
	_noise.frequency = 1.0 / maxf(variation_scale, 1.0)

	player = AudioStreamPlayer.new()
	player.name = "Wind"
	player.bus = BED_BUS_NAME
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	if stream != null:
		_set_looping(stream)
		player.stream = stream
		wind_grid = EmitterGrid.new(self, stream, DETAIL_BUS_NAME, detail_emitters, detail_spacing, detail_unit_size, detail_max_distance, 0, "Detail")
		emitters = wind_grid.players
		player.play(_random_offset(stream))

	if night_stream != null:
		_set_looping(night_stream)
		night_grid = EmitterGrid.new(self, night_stream, NIGHT_BUS_NAME, night_emitters, night_spacing, night_unit_size, night_max_distance, 7919, "Night")
		night_players = night_grid.players

	_apply()


func _exit_tree() -> void:
	if player != null:
		player.stop()

	for grid: EmitterGrid in [wind_grid, night_grid]:
		if grid != null:
			grid.stop()

	# The buses go with the scene, the ones sending to another first.
	for i: int in range(_made_buses.size() - 1, -1, -1):
		var index: int = AudioServer.get_bus_index(_made_buses[i])
		if index > 0:
			AudioServer.remove_bus(index)

	_made_buses.clear()


## Asks for the outside to be pushed back (`amount` 0 to 1) until it is asked again with 0. `source` names the asker.
func set_muffle(source: StringName, amount: float) -> void:
	if amount <= 0.0:
		_muffles.erase(source)
	else:
		_muffles[source] = clampf(amount, 0.0, 1.0)


## Asks for the outside to be silent (wind and night chorus gone, not only pushed back) until it is asked again with `on` false. `source`
## names the asker (the wagon scene, where only the girl is heard).
func set_silenced(source: StringName, on: bool) -> void:
	if on:
		_silenced[source] = true
	else:
		_silenced.erase(source)


## The cutoff and the level the outside has right now (for tests and for tuning).
func get_cutoff_hz() -> float:
	return filter.cutoff_hz if filter != null else open_cutoff_hz


func get_volume_db() -> float:
	var index: int = AudioServer.get_bus_index(BUS_NAME)
	return AudioServer.get_bus_volume_db(index) + (player.volume_db if player != null else 0.0)


## The gain of the wind and of the night chorus at the mix right now (0 to 1, for tests and for tuning).
func get_wind_gain() -> float:
	return lerpf(wind_in_deep_woods, 1.0, wind_weight)


func get_night_gain() -> float:
	return lerpf(1.0, night_at_full_wind, wind_weight)


## Where the forest's mix would be at `point`: 1 within `open_inner_radius` of an open place, 0 past `open_outer_radius` of all of them,
## moved a little by the noise over the map.
func mix_at(point: Vector3) -> float:
	var open: float = 0.0
	for place: Node3D in open_places:
		if place != null and is_instance_valid(place) and place.is_inside_tree():
			var flat: float = Vector2(point.x - place.global_position.x, point.z - place.global_position.z).length()
			open = maxf(open, 1.0 - smoothstep(open_inner_radius, open_outer_radius, flat))

	var wobble: float = _noise.get_noise_2d(point.x, point.z) * variation if _noise != null else 0.0
	return clampf(open + wobble, 0.0, 1.0)


func _process(delta: float) -> void:
	var listener: Variant = _listener_position()
	var cut: bool = false
	if listener is Vector3:
		cut = not _listener_known or (listener as Vector3).distance_to(_last_listener) > teleport_distance
		_last_listener = listener as Vector3
		_listener_known = true
		target_wind_weight = mix_at(listener as Vector3)
		if cut or mix_smoothing_seconds <= 0.0:
			wind_weight = target_wind_weight
		else:
			wind_weight = move_toward(wind_weight, target_wind_weight, delta / mix_smoothing_seconds)

	target_interior = _wanted_interior(listener, cut)

	if cut or transition_seconds <= 0.0:
		interior = target_interior
	else:
		interior = move_toward(interior, target_interior, delta / transition_seconds)

	_silence = move_toward(_silence, 1.0 if not _silenced.is_empty() else 0.0, delta / maxf(silence_fade_seconds, 0.01))
	if fade_in_seconds > 0.0:
		_fade = minf(_fade + delta / fade_in_seconds, 1.0)
	else:
		_fade = 1.0

	if listener is Vector3:
		for grid: EmitterGrid in [wind_grid, night_grid]:
			if grid != null:
				grid.place(listener as Vector3, cut, _spot_in_cell, _random_offset.bind(grid.players[0].stream if not grid.players.is_empty() else null))

	if wind_grid != null:
		wind_grid.update(delta, detail_fade_seconds, detail_volume_db + linear_to_db(maxf(get_wind_gain(), 0.0001)) + _silence_db())
	if night_grid != null:
		night_grid.update(delta, detail_fade_seconds, night_volume_db + linear_to_db(maxf(get_night_gain(), 0.0001)) + _silence_db())

	_apply()


func _wanted_interior(listener: Variant, cut: bool) -> float:
	var wanted: float = 0.0
	if listener is Vector3:
		var zone_amount: float = 0.0
		for node: Node in get_tree().get_nodes_in_group(AmbienceZone.GROUP):
			var zone: AmbienceZone = node as AmbienceZone
			if zone != null and zone.is_inside_tree():
				zone_amount = maxf(zone_amount, zone.amount_at(listener as Vector3))

		if zone_amount > 0.0:
			_measure_openness(listener as Vector3, cut)
			var open: float = clampf((openness - open_floor) / maxf(open_full - open_floor, 0.01), 0.0, 1.0)
			var enclosed: float = 1.0 - pow(open, open_curve)
			wanted = zone_amount * enclosed
		else:
			openness = 1.0
			_escaped.fill(1)

	for amount: Variant in _muffles.values():
		wanted = maxf(wanted, float(amount))

	if get_tree().paused:
		wanted = maxf(wanted, pause_muffle)

	var body: Node = get_tree().get_first_node_in_group(&"player")
	if body != null and bool(body.get("cutscene_frozen")):
		wanted = maxf(wanted, cutscene_muffle)

	return wanted


## Casts the next few rays (all of them after a cut) and works out the share that leave the building: no wall within `ray_length`, or the
## first thing met is outside every zone (a tree seen through a window).
func _measure_openness(at: Vector3, all_now: bool) -> void:
	var viewport: Viewport = get_viewport()
	var world: World3D = viewport.find_world_3d() if viewport != null else null
	if world == null or _directions.is_empty():
		return

	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var exclude: Array[RID] = []
	var body: CollisionObject3D = get_tree().get_first_node_in_group(&"player") as CollisionObject3D
	if body != null:
		exclude.append(body.get_rid())

	var count: int = _directions.size() if all_now else mini(rays_per_frame, _directions.size())
	for i: int in count:
		var index: int = _next_ray
		_next_ray = (_next_ray + 1) % _directions.size()
		# Each ray goes somewhere in its own slice of the circle, a little differently each time: fixed directions would make the openness
		# jump as a window comes into one of them.
		var direction: Vector3 = _directions[index].rotated(Vector3.UP, randf_range(-0.5, 0.5) * _slices[index])
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at, at + direction * ray_length)
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		_escaped[index] = 1 if hit.is_empty() or not _in_any_zone(hit["position"] as Vector3) else 0

	var out: int = 0
	for value: int in _escaped:
		out += value
	var measured: float = float(out) / float(_escaped.size())
	if all_now or openness_smoothing_seconds <= 0.0:
		openness = measured
	else:
		openness = lerpf(openness, measured, 1.0 - exp(-get_process_delta_time() / openness_smoothing_seconds))


## Whether a point is in (or on the walls of) one of the interiors.
func _in_any_zone(point: Vector3) -> bool:
	for node: Node in get_tree().get_nodes_in_group(AmbienceZone.GROUP):
		var zone: AmbienceZone = node as AmbienceZone
		if zone != null and zone.contains(point, 0.3):
			return true
	return false


## Where the player hears from: the camera in use.
func _listener_position() -> Variant:
	var viewport: Viewport = get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	if camera == null or not camera.is_inside_tree():
		return null

	return camera.global_position


func _silence_db() -> float:
	return -80.0 * _silence


func _apply() -> void:
	if filter != null:
		# The cutoff moves on a log scale, as the ear hears pitch.
		filter.cutoff_hz = exp(lerpf(log(open_cutoff_hz), log(inside_cutoff_hz), interior))

	var index: int = AudioServer.get_bus_index(BUS_NAME)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, inside_volume_db * interior + linear_to_db(maxf(_fade, 0.0001)) + _silence_db())

	if player != null:
		player.volume_db = outdoor_volume_db + linear_to_db(maxf(get_wind_gain(), 0.0001)) + _silence_db()


## A place in a cell, the same every time for that cell and grid (the forest does not shuffle), near the ground.
func _spot_in_cell(cell: Vector2i, spacing: float, salt: int, listener_y: float) -> Vector3:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(cell) + salt
	var x: float = (float(cell.x) + rng.randf_range(0.15, 0.85)) * spacing
	var z: float = (float(cell.y) + rng.randf_range(0.15, 0.85)) * spacing
	var y: float = listener_y - 1.0
	var viewport: Viewport = get_viewport()
	var world: World3D = viewport.find_world_3d() if viewport != null else null
	if world != null:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, listener_y + 30.0, z), Vector3(x, listener_y - 60.0, z))
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			y = (hit["position"] as Vector3).y

	return Vector3(x, y + rng.randf_range(0.2, 0.8), z)


# ============================================================
# SET UP
# ============================================================

## The buses: the main one with the inside filter (to Master), and the bed's, the wind emitters' and the night emitters' (to it), the
## first two each with its own split. Made once, and taken away again with this node.
func _make_buses() -> void:
	var main: int = _bus(BUS_NAME, &"Master")
	filter = _effect(main, AudioEffectLowPassFilter.new(), open_cutoff_hz) as AudioEffectLowPassFilter
	_effect(_bus(BED_BUS_NAME, BUS_NAME), AudioEffectLowPassFilter.new(), bed_cutoff_hz)
	_effect(_bus(DETAIL_BUS_NAME, BUS_NAME), AudioEffectHighPassFilter.new(), detail_cutoff_hz)
	_bus(NIGHT_BUS_NAME, BUS_NAME)


func _bus(bus_name: StringName, send: StringName) -> int:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, send)
		_made_buses.append(bus_name)

	return index


## The bus's filter of the same kind as `made`, or `made` itself, set up and added.
func _effect(bus: int, made: AudioEffectFilter, cutoff_hz: float) -> AudioEffectFilter:
	for i: int in AudioServer.get_bus_effect_count(bus):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus, i)
		if effect.get_class() == made.get_class():
			return effect as AudioEffectFilter

	made.db = AudioEffectFilter.FILTER_12DB
	made.cutoff_hz = cutoff_hz
	AudioServer.add_bus_effect(bus, made)
	return made


## Rays round a ring at the ear, a ring tilted up, and a few steeply up (a roof breach); each with the width of its slice of the circle.
func _make_directions() -> void:
	_directions.clear()
	_slices.clear()
	for ring: Vector2 in [Vector2(32.0, 0.0), Vector2(12.0, 30.0), Vector2(4.0, 65.0)]:
		var rays: int = int(ring.x)
		var up: float = deg_to_rad(ring.y)
		for i: int in rays:
			var a: float = TAU * (float(i) + 0.5 * float(ring.y > 0.0)) / float(rays)
			_directions.append(Vector3(cos(a) * cos(up), sin(up), sin(a) * cos(up)))
			_slices.append(TAU / float(rays))

	_escaped.resize(_directions.size())
	_escaped.fill(1)


func _random_offset(sound: AudioStream = null) -> float:
	var length: float = sound.get_length() if sound != null else 0.0
	return randf() * length if length > 1.0 else 0.0


func _set_looping(sound: AudioStream) -> void:
	if sound is AudioStreamMP3:
		(sound as AudioStreamMP3).loop = true
	elif sound is AudioStreamOggVorbis:
		(sound as AudioStreamOggVorbis).loop = true
	elif sound is AudioStreamWAV:
		(sound as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
