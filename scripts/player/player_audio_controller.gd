extends Node
class_name PlayerAudioController

const FOOTSTEP_PITCH_MIN: float = 0.85
const FOOTSTEP_PITCH_MAX: float = 1.0
const SPRINT_FOOTSTEP_PITCH_MIN: float = 0.98
const SPRINT_FOOTSTEP_PITCH_MAX: float = 1.12

## The footsteps on the forest floor: the steps of one recording (`placeholder_footstep_forest.mp3`) cut one by one
## (see PROJECT_CONTEXT, "Footsteps"). They sound only while the ground under the player is the Terrain3D landscape;
## everywhere else (the wagon, the unfinished house, the signal tower, the waiting shed, the railway) the player's own
## `sfx_walk` stream is the sound.
const FOREST_STEPS: Array[String] = [
	"res://assets/audios/footsteps/forest_step_01.wav", "res://assets/audios/footsteps/forest_step_02.wav",
	"res://assets/audios/footsteps/forest_step_03.wav", "res://assets/audios/footsteps/forest_step_04.wav",
	"res://assets/audios/footsteps/forest_step_05.wav", "res://assets/audios/footsteps/forest_step_06.wav",
	"res://assets/audios/footsteps/forest_step_07.wav", "res://assets/audios/footsteps/forest_step_08.wav",
	"res://assets/audios/footsteps/forest_step_09.wav", "res://assets/audios/footsteps/forest_step_10.wav",
	"res://assets/audios/footsteps/forest_step_11.wav", "res://assets/audios/footsteps/forest_step_12.wav",
	"res://assets/audios/footsteps/forest_step_13.wav", "res://assets/audios/footsteps/forest_step_14.wav",
	"res://assets/audios/footsteps/forest_step_15.wav", "res://assets/audios/footsteps/forest_step_16.wav",
	"res://assets/audios/footsteps/forest_step_17.wav", "res://assets/audios/footsteps/forest_step_18.wav",
]
## Boxes (`Area3D` with a `BoxShape3D`) in this group are ground where the default sound plays even if it is
## Terrain3D: the railway's track bed.
const DEFAULT_ZONE_GROUP: StringName = &"default_footstep_zone"
const FOREST_PITCH_MIN: float = 0.94
const FOREST_PITCH_MAX: float = 1.06
const FOREST_SPRINT_PITCH_MAX: float = 1.1

var player: CharacterBody3D = null
var sfx_walk: AudioStreamPlayer = null

var audio_trigger_areas: Dictionary = {}

## True while the last step was taken on the forest floor (the tests look at it).
var on_forest_ground: bool = false

var _walk_base_db: float = 0.0
var _left_foot: bool = false
var _default_step: AudioStream = null
var _forest_steps: Array[AudioStream] = []
var _last_forest_step: int = -1
var _terrain: Terrain3D = null
var _next_terrain_search_msec: int = 0
var _creak_player: AudioStreamPlayer = null
static var _stair_creaks: Array[AudioStreamWAV] = []


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	sfx_walk = player.get_node("SoundEffects/sfx_walk") as AudioStreamPlayer
	_walk_base_db = sfx_walk.volume_db
	_default_step = sfx_walk.stream
	for path: String in FOREST_STEPS:
		var step: AudioStream = load(path) as AudioStream
		if step != null:
			_forest_steps.append(step)

	register_audio_triggers()


## Plays one footstep; the movement controller calls it whenever a foot lands.
## `strength` is how hard the foot came down (1 is a normal step). Each step varies
## in pitch and volume, and now and then one lands noticeably softer, so a long walk
## never sounds like one sample on repeat.
func trigger_footstep(wants_sprint: bool, strength: float = 1.0) -> void:
	var loudness_db: float = (
		randf_range(-2.5, 1.0)
		+ 6.0 * log(clampf(strength, 0.35, 1.8)) / log(10.0)
	)
	if randf() < 0.12:
		loudness_db -= randf_range(3.0, 6.0)

	on_forest_ground = not _forest_steps.is_empty() and is_standing_on_forest()
	if on_forest_ground:
		sfx_walk.stream = _pick_forest_step()
		sfx_walk.pitch_scale = randf_range(FOREST_PITCH_MIN, FOREST_SPRINT_PITCH_MAX if wants_sprint else FOREST_PITCH_MAX)
	else:
		sfx_walk.stream = _default_step
		if wants_sprint:
			sfx_walk.pitch_scale = randf_range(SPRINT_FOOTSTEP_PITCH_MIN, SPRINT_FOOTSTEP_PITCH_MAX)
		else:
			sfx_walk.pitch_scale = randf_range(FOOTSTEP_PITCH_MIN, FOOTSTEP_PITCH_MAX)

	# The left and right foot sound a touch different.
	_left_foot = not _left_foot
	sfx_walk.pitch_scale *= 0.97 if _left_foot else 1.03
	sfx_walk.volume_db = _walk_base_db + loudness_db
	sfx_walk.play()


## An old board of a wooden stair groaning under a heavy step: a short creak (one of a few, never the same twice in a row), under the footstep. The movement
## controller asks for it now and then, only on stairs that creak.
func trigger_stair_creak(strength: float = 1.0) -> void:
	if _creak_player == null:
		_creak_player = AudioStreamPlayer.new()
		_creak_player.name = "StairCreak"
		_creak_player.bus = sfx_walk.bus
		player.add_child(_creak_player)

	if _stair_creaks.is_empty():
		for variant: int in 4:
			_stair_creaks.append(PlaceholderAudio.make_stair_creak(0.55, 11 + 13 * variant))

	if _creak_player.playing:
		return

	_creak_player.stream = _stair_creaks[randi() % _stair_creaks.size()]
	_creak_player.pitch_scale = randf_range(0.85, 1.2)
	_creak_player.volume_db = _walk_base_db - 7.0 + 6.0 * log(clampf(strength, 0.4, 1.8)) / log(10.0)
	_creak_player.play()


## One of the forest steps, never the one just played.
func _pick_forest_step() -> AudioStream:
	var index: int = randi() % _forest_steps.size()
	if index == _last_forest_step:
		index = (index + 1 + randi() % (_forest_steps.size() - 1)) % _forest_steps.size()

	_last_forest_step = index
	return _forest_steps[index]


## True when the ground under the player's feet is the Terrain3D landscape (not a floor, a deck, a plank) and not
## inside a default-sound zone (the railway). A ray straight down: Terrain3D's ground is one collision body of its
## own, so the body that the ray meets says what the ground is.
func is_standing_on_forest() -> bool:
	var terrain: Terrain3D = _find_terrain()
	if terrain == null or terrain.get_collision() == null:
		return false

	var from: Vector3 = player.global_position + Vector3(0.0, 0.3, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -2.0, 0.0))
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("rid") != terrain.get_collision().get_rid():
		return false

	return not _in_default_zone(hit["position"] as Vector3)


func _in_default_zone(point: Vector3) -> bool:
	for node: Node in player.get_tree().get_nodes_in_group(DEFAULT_ZONE_GROUP):
		var zone: Area3D = node as Area3D
		if zone == null:
			continue

		for child: Node in zone.get_children():
			var shape_node: CollisionShape3D = child as CollisionShape3D
			var box: BoxShape3D = shape_node.shape as BoxShape3D if shape_node != null else null
			if box == null:
				continue

			var local: Vector3 = shape_node.global_transform.affine_inverse() * point
			var half: Vector3 = box.size * 0.5
			if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
				return true

	return false


## The landscape, found once (and looked for again now and then in a scene that has none).
func _find_terrain() -> Terrain3D:
	if is_instance_valid(_terrain):
		return _terrain

	var now: int = Time.get_ticks_msec()
	if now < _next_terrain_search_msec:
		return null

	_next_terrain_search_msec = now + 2000
	var found: Array[Node] = player.get_tree().root.find_children("*", "Terrain3D", true, false)
	_terrain = found[0] as Terrain3D if not found.is_empty() else null
	return _terrain


func stop_footsteps() -> void:
	if sfx_walk.playing:
		sfx_walk.stop()


func play_3d_sound(sound_path: String, sound_position: Vector3, max_distance: float = 10.0, debug: bool = false) -> AudioStreamPlayer3D:
	var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var sound: Resource = load(sound_path)

	if sound == null:
		push_error("Sound not found: " + sound_path)
		return null

	audio_player.stream = sound
	audio_player.max_distance = max_distance
	audio_player.unit_size = 1.0
	audio_player.global_position = sound_position

	var audio_parent: Node = player.get_node_or_null("../house")
	if audio_parent == null:
		audio_parent = player.get_parent()

	audio_parent.add_child(audio_player)
	audio_player.play()

	if debug:
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.mesh = SphereMesh.new()
		marker.scale = Vector3(0.2, 0.2, 0.2)

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color.RED
		marker.material_override = mat
		marker.global_position = sound_position
		audio_parent.add_child(marker)

		audio_player.finished.connect(func():
			if is_instance_valid(marker):
				marker.queue_free()
			if is_instance_valid(audio_player):
				audio_player.queue_free()
		)
	else:
		audio_player.finished.connect(func():
			if is_instance_valid(audio_player):
				audio_player.queue_free()
		)

	return audio_player


func register_audio_triggers() -> void:
	var triggers: Array = player.get_tree().get_nodes_in_group("audio_triggers")

	for trigger_variant in triggers:
		var trigger: Area3D = trigger_variant as Area3D

		if trigger != null:
			trigger.body_entered.connect(Callable(self, "_on_audio_trigger_entered").bind(trigger))
			trigger.body_exited.connect(Callable(self, "_on_audio_trigger_exited").bind(trigger))
			audio_trigger_areas[trigger.name] = false


func _on_audio_trigger_entered(body: Node3D, trigger: Area3D) -> void:
	if body != player:
		return

	var sound_path: String = str(trigger.get_meta("sound_path", ""))
	var max_distance: float = float(trigger.get_meta("max_distance", 10.0))
	var one_time: bool = bool(trigger.get_meta("one_time", false))

	if sound_path != "" and (not one_time or not audio_trigger_areas.get(trigger.name, false)):
		play_3d_sound(sound_path, trigger.global_position, max_distance, false)
		audio_trigger_areas[trigger.name] = true


func _on_audio_trigger_exited(body: Node3D, trigger: Area3D) -> void:
	if body != player:
		return

	var one_time: bool = bool(trigger.get_meta("one_time", false))

	if not one_time:
		audio_trigger_areas[trigger.name] = false
