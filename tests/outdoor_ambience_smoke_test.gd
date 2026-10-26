extends Node

## The wind outside (`OutdoorAmbience`) and the interiors that muffle it (`AmbienceZone`):
## - the recording split into a 2D bed (the wind, low) and 3D emitters fixed in the world (the crickets and leaves, high), each on its
##   bus, through a main bus with the inside filter; the emitters stay put as the listener walks (so they are passed by) and the far ones
##   are moved ahead when the listener has gone on;
## - inside, by how enclosed the spot is: in the middle of a closed room muffled, by a window all but outside, more and more on the way
##   there (never a jump), a door opened lets the outside in, the tower's broken cabin is open; a cut snaps;
## - a cutscene's request and the pause menu; the bus taken away with the scene; the dream intro has it with the windy forest recording.
## Run it as a scene; it quits by itself with a non-zero exit code on failure.

const WIND_PATH: String = "res://assets/audios/placeholder_windy_forest.mp3"
const NIGHT_PATH: String = "res://assets/audios/placeholder_night_forest.mp3"
const S: float = UnfinishedHouseBuilder.PLAN_SCALE

var test_failed: bool = false
var wind: OutdoorAmbience = null
var camera: Camera3D = null
var wagon: Node3D = null
var house: Node3D = null
var tower: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.set_text_locale("en", false)
	DoorController.approach_enabled = false
	_check_the_dream_intro_has_it()

	var level: Node3D = Node3D.new()
	add_child(level)
	camera = Camera3D.new()
	level.add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(0.0, 1.5, 30.0)

	wagon = (load("res://scenes/objects/train_wagon.tscn") as PackedScene).instantiate() as Node3D
	level.add_child(wagon)
	wagon.rotation_degrees = Vector3(0.0, 14.0, 0.0)
	house = (load("res://scenes/levels/unfinished_house.tscn") as PackedScene).instantiate() as Node3D
	house.position = Vector3(100.0, 0.0, 0.0)
	house.rotation_degrees = Vector3(0.0, -135.0, 0.0)
	level.add_child(house)
	tower = (load("res://scenes/levels/signal_tower.tscn") as PackedScene).instantiate() as Node3D
	tower.position = Vector3(-100.0, 0.0, 0.0)
	tower.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	level.add_child(tower)

	wind = OutdoorAmbience.new()
	wind.stream = load(WIND_PATH) as AudioStream
	wind.night_stream = load(NIGHT_PATH) as AudioStream
	wind.open_places = [wagon]
	level.add_child(wind)
	for i: int in 3:
		await get_tree().physics_frame

	await _run()

	print("OUTDOOR_AMBIENCE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run() -> void:
	_check_the_buses()
	_expect(wind.player.stream != null and wind.player.stream.resource_path == WIND_PATH and (wind.player.stream as AudioStreamMP3).loop, "the bed plays the windy forest recording, looping")
	_expect(wind.player.playing and wind.player.bus == OutdoorAmbience.BED_BUS_NAME, "on the bed's bus")
	_expect(wind.get_volume_db() < wind.outdoor_volume_db - 10.0, "it fades in at the start (%.1f dB)" % wind.get_volume_db())

	await _check_the_emitters()
	await _check_the_mix()

	# Outside, once it has faded in: open.
	var waited: float = 0.0
	while wind._fade < 1.0 and waited < 15.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	camera.global_position = Vector3(0.0, 1.5, 30.0)
	await _settle()
	_expect(is_zero_approx(wind.interior) and wind.get_cutoff_hz() > 19000.0, "outside the wind is open (%.0f Hz)" % wind.get_cutoff_hz())
	var full: float = wind.outdoor_volume_db + linear_to_db(wind.get_wind_gain())
	_expect(absf(wind.get_volume_db() - full) < 0.1, "at its full level for the forest's mix there (%.1f dB)" % wind.get_volume_db())

	# Into the shut wagon, walked: it comes on gradually, and in the middle it is muffled (the wagon has no window open).
	var outside: Vector3 = wagon.to_global(Vector3(0.0, 1.5, 9.0))
	var inside: Vector3 = wagon.to_global(Vector3(0.0, 1.5, 0.0))
	camera.global_position = outside
	await _settle()
	var biggest_step: float = 0.0
	var last: float = wind.interior
	for i: int in 60:
		camera.global_position = outside.lerp(inside, float(i + 1) / 60.0)
		await get_tree().process_frame
		biggest_step = maxf(biggest_step, absf(wind.interior - last))
		last = wind.interior
	await _wait(1.2)
	_expect(wind.interior > 0.85, "in the middle of the shut wagon the outside is muffled (%.2f, %.0f%% of the rays out)" % [wind.interior, wind.openness * 100.0])
	_expect(biggest_step < 0.2, "and it came on gradually, never in a jump (largest step %.3f)" % biggest_step)
	_expect(wind.get_cutoff_hz() < 2500.0 and wind.get_cutoff_hz() > 1200.0, "the highs are taken off, not everything (%.0f Hz)" % wind.get_cutoff_hz())
	var drop: float = wind.outdoor_volume_db - wind.get_volume_db()
	_expect(drop > 4.0 and drop < 7.0, "and it is quieter (%.1f dB down), but plainly still there" % drop)

	# A cut to another place: set at once.
	camera.global_position = Vector3(0.0, 1.5, 60.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(is_zero_approx(wind.interior), "a cut to a place outside opens it at once (%.2f)" % wind.interior)

	# The unfinished house's bedroom, from its middle to its glassless window: muffled in the middle, all but outside at the window, and
	# more and more open on the way, without a jump.
	var amounts: Array[float] = []
	for step: int in 9:
		var z: float = lerpf(2.0, 0.3, float(step) / 8.0) * S
		camera.global_position = house.to_global(Vector3(5.25 * S, 1.4, z))
		await _settle(step == 0)
		amounts.append(wind.interior)
	_expect(amounts[0] > 0.4, "in the middle of the bedroom the outside is muffled (%.2f; the room has a glassless window)" % amounts[0])
	_expect(amounts[amounts.size() - 1] < 0.25, "at its window it is all but the outside (%.2f)" % amounts[amounts.size() - 1])
	var steadily: bool = true
	for i: int in range(1, amounts.size()):
		steadily = steadily and amounts[i] <= amounts[i - 1] + 0.08 and amounts[i - 1] - amounts[i] < 0.25
	_expect(steadily, "and on the way it opens more and more, step by step (%s)" % str(amounts.map(func(a: float) -> String: return "%.2f" % a)))

	# The front door: shut, the hall behind it is muffled; opened, the outside comes in.
	var by_door: Vector3 = house.to_global(Vector3(3.0 * S, 1.4, 9.2 * S))
	camera.global_position = by_door
	await _settle(true)
	var shut: float = wind.interior
	var front: DoorController = _front_door()
	_expect(front != null, "the house has its front door")
	if front != null:
		front.force_open()
		await _wait(3.0)
		await _settle()
		_expect(shut > 0.5 and wind.interior < shut - 0.2, "a step inside the front door: muffled while it is shut (%.2f), the outside comes in when it is opened (%.2f)" % [shut, wind.interior])
		front.slam_shut()
		await _wait(1.5)

	# The signal tower: the brick relay room muffles it, the cabin with its shattered windows hardly at all.
	camera.global_position = tower.to_global(Vector3(0.0, 1.3, 0.0))
	await _settle(true)
	var relay: float = wind.interior
	camera.global_position = tower.to_global(Vector3(0.0, 4.1, 0.0))
	await _wait(1.2)
	await _settle()
	var cabin: float = wind.interior
	_expect(relay > 0.3 and cabin < 0.15 and relay > cabin + 0.2, "in the tower the relay room muffles it (%.2f), the broken cabin hardly (%.2f)" % [relay, cabin])

	# A cutscene asks for it to be pushed back, and lets it come back.
	camera.global_position = Vector3(0.0, 1.5, 30.0)
	await _settle(true)
	get_tree().call_group(OutdoorAmbience.GROUP, "set_muffle", &"test_scene", 0.75)
	await _wait(0.2)
	_expect(wind.target_interior == 0.75 and wind.interior > 0.1 and wind.interior < 0.75, "a cutscene's request pushes it back, gradually (%.2f)" % wind.interior)
	await _wait(1.0)
	_expect(absf(wind.interior - 0.75) < 0.01, "to what it asked (%.2f)" % wind.interior)
	get_tree().call_group(OutdoorAmbience.GROUP, "set_muffle", &"test_scene", 0.0)
	await _wait(1.0)
	_expect(is_zero_approx(wind.interior), "and it comes back when the request is let go")

	# The pause menu: muffled, still playing.
	get_tree().paused = true
	await _wait(1.0)
	_expect(absf(wind.interior - wind.pause_muffle) < 0.01 and wind.player.playing and wind.emitters[0].playing, "paused, the wind goes on, muffled (%.2f)" % wind.interior)
	get_tree().paused = false
	await _wait(1.0)
	_expect(is_zero_approx(wind.interior), "and opens again after")

	# Taken away with its scene, it takes its buses with it.
	wind.queue_free()
	await get_tree().process_frame
	_expect(AudioServer.get_bus_index(OutdoorAmbience.BUS_NAME) < 0 and AudioServer.get_bus_index(OutdoorAmbience.BED_BUS_NAME) < 0 and AudioServer.get_bus_index(OutdoorAmbience.DETAIL_BUS_NAME) < 0, "gone with the scene, it takes its buses with it")


## The main bus (the inside filter) to Master; the bed's (keeps the wind, low) and the emitters' (keeps the crickets and leaves, high) to it.
func _check_the_buses() -> void:
	var main: int = AudioServer.get_bus_index(OutdoorAmbience.BUS_NAME)
	var bed: int = AudioServer.get_bus_index(OutdoorAmbience.BED_BUS_NAME)
	var detail: int = AudioServer.get_bus_index(OutdoorAmbience.DETAIL_BUS_NAME)
	_expect(main > 0 and AudioServer.get_bus_send(main) == &"Master", "the wind has a bus of its own, sent to Master")
	_expect(wind.filter != null and AudioServer.get_bus_effect(main, 0) == wind.filter and wind.filter.db == AudioEffectFilter.FILTER_12DB, "with a gentle low pass filter on it, for inside")
	_expect(bed > main and AudioServer.get_bus_send(bed) == OutdoorAmbience.BUS_NAME and AudioServer.get_bus_effect(bed, 0) is AudioEffectLowPassFilter, "the bed's bus keeps the low part (the wind) and goes through it")
	_expect(detail > main and AudioServer.get_bus_send(detail) == OutdoorAmbience.BUS_NAME and AudioServer.get_bus_effect(detail, 0) is AudioEffectHighPassFilter, "the emitters' bus keeps the high part (crickets, leaves) and goes through it")
	var night: int = AudioServer.get_bus_index(OutdoorAmbience.NIGHT_BUS_NAME)
	_expect(night > main and AudioServer.get_bus_send(night) == OutdoorAmbience.BUS_NAME, "the night chorus has its bus, through it too")


## The emitters: world-locked on a grid round the listener. Walking a little they do not move (they are passed by: one beside the path
## goes from ahead to behind); gone far, the ones behind are moved ahead, and fade in there.
func _check_the_emitters() -> void:
	_expect(wind.emitters.size() == wind.detail_emitters and wind.detail_emitters >= 4, "%d emitters carry the crickets and the leaves" % wind.emitters.size())
	# (They are placed, and start, on the first frame the listener is known.)
	await _settle()
	var all_ok: bool = true
	var report: Array[String] = []
	for emitter: AudioStreamPlayer3D in wind.emitters:
		var ok: bool = emitter.playing and emitter.bus == OutdoorAmbience.DETAIL_BUS_NAME and emitter.stream == wind.player.stream and emitter.max_distance > 10.0
		all_ok = all_ok and ok
		if not ok:
			report.append("%s playing=%s bus=%s" % [emitter.name, emitter.playing, emitter.bus])
	_expect(all_ok, "each plays the recording in 3D on the emitters' bus %s" % str(report))

	var start: Vector3 = Vector3(5.0, 1.5, 205.0)
	camera.global_position = start
	await _settle()
	var reach: float = wind.detail_spacing * 1.6
	var round_us: bool = true
	for emitter: AudioStreamPlayer3D in wind.emitters:
		round_us = round_us and Vector2(emitter.global_position.x - start.x, emitter.global_position.z - start.z).length() < reach * 1.5
	_expect(round_us, "they stand round the listener")

	# A few steps: nothing moves. The nearest one ahead and to the side goes from in front to behind as the listener walks past it.
	var before: Array[Vector3] = []
	for emitter: AudioStreamPlayer3D in wind.emitters:
		before.append(emitter.global_position)
	var target: AudioStreamPlayer3D = null
	for emitter: AudioStreamPlayer3D in wind.emitters:
		var ahead: float = start.z - emitter.global_position.z
		if ahead > 1.0 and (target == null or ahead < start.z - target.global_position.z):
			target = emitter
	var passed: bool = false
	if target != null:
		var cell_z: float = floor(start.z / wind.detail_spacing) * wind.detail_spacing
		var walk_to: Vector3 = Vector3(start.x, start.y, maxf(target.global_position.z - 2.0, cell_z + 0.5))
		var was_ahead: bool = target.global_position.z < start.z
		camera.global_position = walk_to
		await _settle()
		passed = was_ahead and target.global_position.z > walk_to.z
	var still: bool = true
	for i: int in wind.emitters.size():
		still = still and wind.emitters[i].global_position.is_equal_approx(before[i])
	_expect(still, "walking a little, they stay where they are in the world (they do not follow the listener)")
	_expect(passed, "so one ahead of the listener is passed and left behind")

	# Far on: the emitters are round the new place, the moved ones fading in.
	var far: Vector3 = start + Vector3(0.0, 0.0, -wind.detail_spacing * 2.0)
	camera.global_position = far + Vector3(0.0, 0.0, wind.detail_spacing * 0.9)
	await get_tree().process_frame
	camera.global_position = far
	await get_tree().process_frame
	await get_tree().process_frame
	var moved: int = 0
	var fading: bool = false
	for i: int in wind.emitters.size():
		if not wind.emitters[i].global_position.is_equal_approx(before[i]):
			moved += 1
			fading = fading or wind.wind_grid.fades[i] < 0.5
	_expect(moved > 0 and moved < wind.emitters.size(), "gone on two cells, the ones left behind are moved ahead (%d of %d)" % [moved, wind.emitters.size()])
	_expect(fading, "and fade in there")
	var around: bool = true
	for emitter: AudioStreamPlayer3D in wind.emitters:
		around = around and Vector2(emitter.global_position.x - far.x, emitter.global_position.z - far.z).length() < reach * 1.5
	_expect(around, "all of them round the new place")


## The night chorus: its own grid of emitters playing the night recording. The mix: by an open place (the wagon here) the wind is strong and
## the night chorus thin, deep in the woods the other way round, the woods are not all alike (the noise over the map), and walking from
## one to the other it changes gradually.
func _check_the_mix() -> void:
	var night_ok: bool = wind.night_players.size() == wind.night_emitters and wind.night_emitters >= 4
	for emitter: AudioStreamPlayer3D in wind.night_players:
		night_ok = night_ok and emitter.playing and emitter.bus == OutdoorAmbience.NIGHT_BUS_NAME and emitter.stream.resource_path == NIGHT_PATH
	_expect(night_ok, "%d emitters play the night chorus, in 3D on its bus" % wind.night_players.size())
	_expect(not wind.night_players.is_empty() and not wind.night_players[0].global_position.is_equal_approx(wind.emitters[0].global_position) and wind.night_spacing != wind.detail_spacing, "on a grid of their own")

	var by_wagon: Vector3 = wagon.to_global(Vector3(0.0, 1.5, 12.0))
	camera.global_position = by_wagon
	await _settle(true)
	_expect(wind.wind_weight > 0.95 and wind.get_wind_gain() > wind.get_night_gain() + 0.5, "by the wagon the wind is strong (%.2f) and the night chorus thin (%.2f)" % [wind.get_wind_gain(), wind.get_night_gain()])
	var bed_by_wagon: float = wind.player.volume_db

	var deep: Vector3 = Vector3(0.0, 1.5, 400.0)
	var mixes: Array[float] = []
	for step: int in 6:
		mixes.append(wind.mix_at(deep + Vector3(float(step) * 30.0, 0.0, 0.0)))
	var lowest: float = mixes.min()
	var highest: float = mixes.max()
	_expect(highest <= wind.variation + 0.001, "deep in the woods the mix is low everywhere (at most %.2f)" % highest)
	_expect(highest - lowest > 0.05, "but the woods are not all alike: it varies from place to place (%.2f to %.2f)" % [lowest, highest])

	# Walked, not cut: from the wagon into the woods it changes gradually.
	var biggest_step: float = 0.0
	var last: float = wind.wind_weight
	for i: int in 40:
		camera.global_position = by_wagon.lerp(by_wagon + Vector3(0.0, 0.0, 120.0), float(i + 1) / 40.0)
		await get_tree().process_frame
		biggest_step = maxf(biggest_step, absf(wind.wind_weight - last))
		last = wind.wind_weight
	_expect(biggest_step < 0.1, "walking into the woods the mix changes gradually (largest step %.3f)" % biggest_step)
	await _wait(wind.mix_smoothing_seconds + 0.5)
	_expect(wind.get_night_gain() > wind.get_wind_gain(), "deep in the woods the night chorus is the stronger (%.2f against %.2f)" % [wind.get_night_gain(), wind.get_wind_gain()])
	_expect(wind.player.volume_db < bed_by_wagon - 3.0, "and the wind bed is quieter there (%.1f dB against %.1f)" % [wind.player.volume_db, bed_by_wagon])


func _front_door() -> DoorController:
	var front: Vector3 = house.to_global(Vector3(3.0 * S, 1.0, 10.0 * S))
	var best: DoorController = null
	for node: Node in house.find_children("*", "DoorController", true, false):
		var door: DoorController = node as DoorController
		if best == null or door.global_position.distance_to(front) < best.global_position.distance_to(front):
			best = door
	if best != null and best.global_position.distance_to(front) > 1.5:
		return null
	return best


## Lets the rays go round and the amount settle where it is (a cut first, when asked, so that it starts from here).
func _settle(cut: bool = false) -> void:
	if cut:
		var at: Vector3 = camera.global_position
		camera.global_position = at + Vector3(0.0, 50.0, 0.0)
		await get_tree().process_frame
		camera.global_position = at
	for i: int in 8:
		await get_tree().process_frame
	await _wait(0.8)


## The dream intro (the whole game) has the wind, with the windy forest recording, and the menu does not.
func _check_the_dream_intro_has_it() -> void:
	var found: bool = false
	var state: SceneState = (load("res://scenes/cinematics/dream_intro.tscn") as PackedScene).get_state()
	for i: int in state.get_node_count():
		for p: int in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"stream":
				var value: Variant = state.get_node_property_value(i, p)
				if value is AudioStream and (value as AudioStream).resource_path == WIND_PATH and state.get_node_name(i) == &"OutdoorAmbience":
					found = true
	_expect(found, "the dream intro has the wind (OutdoorAmbience, with the windy forest recording)")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
