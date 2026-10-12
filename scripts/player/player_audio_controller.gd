extends Node
class_name PlayerAudioController

const FOOTSTEP_PITCH_MIN: float = 0.85
const FOOTSTEP_PITCH_MAX: float = 1.0
const SPRINT_FOOTSTEP_PITCH_MIN: float = 0.98
const SPRINT_FOOTSTEP_PITCH_MAX: float = 1.12

var player: CharacterBody3D = null
var sfx_walk: AudioStreamPlayer = null

var audio_trigger_areas: Dictionary = {}

var _walk_base_db: float = 0.0
var _left_foot: bool = false


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	sfx_walk = player.get_node("SoundEffects/sfx_walk") as AudioStreamPlayer
	_walk_base_db = sfx_walk.volume_db

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

	if wants_sprint:
		sfx_walk.pitch_scale = randf_range(SPRINT_FOOTSTEP_PITCH_MIN, SPRINT_FOOTSTEP_PITCH_MAX)
	else:
		sfx_walk.pitch_scale = randf_range(FOOTSTEP_PITCH_MIN, FOOTSTEP_PITCH_MAX)

	# The left and right foot sound a touch different.
	_left_foot = not _left_foot
	sfx_walk.pitch_scale *= 0.97 if _left_foot else 1.03
	sfx_walk.volume_db = _walk_base_db + loudness_db
	sfx_walk.play()


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
