extends Node
class_name PlayerAudioController

const FOOTSTEP_PITCH_MIN: float = 0.9
const FOOTSTEP_PITCH_MAX: float = 1.1
const SPRINT_FOOTSTEP_PITCH_MIN: float = 1.15
const SPRINT_FOOTSTEP_PITCH_MAX: float = 1.35
const CROUCH_FOOTSTEP_PITCH_MIN: float = 0.8
const CROUCH_FOOTSTEP_PITCH_MAX: float = 1.0

var player: CharacterBody3D = null
var sfx_walk: AudioStreamPlayer = null
var sfx_crouch_walk: AudioStreamPlayer = null

var audio_trigger_areas: Dictionary = {}
var last_step_phase: bool = false


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	sfx_walk = player.get_node("SoundEffects/sfx_walk") as AudioStreamPlayer
	sfx_crouch_walk = player.get_node("SoundEffects/sfx_crouch_walk") as AudioStreamPlayer

	register_audio_triggers()


func update_footsteps(bob_time: float, wants_crouch: bool, wants_sprint: bool) -> void:
	var step_phase: bool = sin(bob_time * 4.0) > 0.9

	if step_phase and not last_step_phase:
		if wants_crouch:
			sfx_walk.stop()
			sfx_crouch_walk.pitch_scale = randf_range(CROUCH_FOOTSTEP_PITCH_MIN, CROUCH_FOOTSTEP_PITCH_MAX)
			sfx_crouch_walk.play()
		else:
			sfx_crouch_walk.stop()

			if wants_sprint:
				sfx_walk.pitch_scale = randf_range(SPRINT_FOOTSTEP_PITCH_MIN, SPRINT_FOOTSTEP_PITCH_MAX)
			else:
				sfx_walk.pitch_scale = randf_range(FOOTSTEP_PITCH_MIN, FOOTSTEP_PITCH_MAX)

			sfx_walk.play()

	last_step_phase = step_phase


func stop_footsteps() -> void:
	last_step_phase = false

	if sfx_walk.playing:
		sfx_walk.stop()

	if sfx_crouch_walk.playing:
		sfx_crouch_walk.stop()


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

	var sound_path: String = str(trigger.get_meta("sound_path", "res://assets/audios/whisper.mp3"))
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
