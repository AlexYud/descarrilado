extends Interactable
class_name SignalLantern

## An iron railway signal lantern with a drawer in its base, which holds the brass signal key and the photograph
## "Rain at the Station" (`Contents`). Its filter is a drum of three panes of coloured glass, yellow, neutral and
## red, and interacting with the lens turns it to the next with a heavy metallic CLACK. Turned to red (the
## railway's emergency signal), a spring latch lets go (CLICK-SHRK) and the drawer slides open, bringing the
## contents out. Once open it stays open (it is saved) and the lens answers no more.
##
## The model is `Model` (built by ProceduralProp, kind `signal_lantern`: `Drum`, `Drawer`, `Glow`), the lens is
## the `InteractArea`. Like OpenableContainer, the contents stay out of the scene tree, and so out of reach and out
## of sight, until the drawer is opened.

signal filter_changed(filter: int)
signal opened

enum Filter {
	YELLOW,
	NEUTRAL,
	RED,
}

const STATE_SECTION: StringName = &"puzzles"
const FILTER_COLORS: Array[Color] = [Color(1.0, 0.72, 0.2), Color(0.95, 0.93, 0.85), Color(1.0, 0.1, 0.05)]

## Unique within the game; the open lantern is saved under it.
@export var persistent_id: StringName = &"signal_lantern"
@export var key_scene: PackedScene
@export var photo_scene: PackedScene
@export var turn_seconds: float = 0.42
@export var slide_seconds: float = 1.1
## How long after the red pane lands the latch lets go.
@export var latch_delay_seconds: float = 0.4

var filter: int = Filter.YELLOW
var is_open: bool = false
var is_turning: bool = false

var _drum: Node3D = null
var _drawer: Node3D = null
var _glow: OmniLight3D = null
var _contents: Node3D = null
var _sound: AudioStreamPlayer3D = null
var _steps: int = 0


func _ready() -> void:
	_drum = get_node_or_null(^"Model/Drum") as Node3D
	_drawer = get_node_or_null(^"Model/Drawer") as Node3D
	_glow = get_node_or_null(^"Model/Glow") as OmniLight3D

	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 2.0
	_sound.max_distance = 15.0
	add_child(_sound)

	_make_contents()
	is_open = bool(SaveManager.get_state_value(STATE_SECTION, _key(), false))

	if is_open:
		_disable_lens()
		filter = Filter.RED
		_steps = Filter.RED
		_set_drum_angle(_steps)
		_light_up(filter)
		if _drawer != null:
			_drawer.position.z = FigClearingProps.DRAWER_SLIDE
			_drawer.add_child(_contents)


func _exit_tree() -> void:
	# Contents that never entered the tree would leak.
	if is_instance_valid(_contents) and _contents.get_parent() == null:
		_contents.free()
		_contents = null


func can_interact(_player: Node) -> bool:
	return not is_open and not is_turning


func get_prompt_text() -> String:
	return prompt_text


func interact(_player: Node) -> void:
	if is_open or is_turning:
		return

	is_turning = true
	_steps += 1
	filter = _steps % FigClearingProps.LANTERN_PANEL_COUNT
	_light_up(filter)

	var turn: Tween = create_tween()
	turn.tween_method(_set_drum_angle, float(_steps - 1), float(_steps), turn_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await turn.finished

	_play(PlaceholderAudio.make_iron_clack(), -2.0)
	is_turning = false
	filter_changed.emit(filter)

	if filter == Filter.RED:
		_release_latch()


func _release_latch() -> void:
	is_open = true
	is_turning = true
	SaveManager.set_state_value(STATE_SECTION, _key(), true)
	_disable_lens()

	await get_tree().create_timer(latch_delay_seconds).timeout

	_play(PlaceholderAudio.make_spring_latch(), -3.0)
	if _contents != null and _contents.get_parent() == null and _drawer != null:
		_drawer.add_child(_contents)

	if _drawer != null:
		create_tween().tween_property(
			_drawer, "position:z", FigClearingProps.DRAWER_SLIDE, slide_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.12)

	is_turning = false
	opened.emit()


## The key and the photograph, lying on the drawer's tray (in its frame). They are not in the scene yet.
func _make_contents() -> void:
	_contents = Node3D.new()
	_contents.name = "Contents"

	if photo_scene != null:
		var photo: Node3D = photo_scene.instantiate() as Node3D
		photo.name = "Photo"
		photo.transform = Transform3D(
			Basis(Vector3.UP, deg_to_rad(7.0)) * Basis(Vector3.RIGHT, -PI * 0.5), FigClearingProps.DRAWER_PHOTO_AT
		)
		_contents.add_child(photo)

	if key_scene != null:
		var key: Node3D = key_scene.instantiate() as Node3D
		key.name = "Key"
		key.transform = Transform3D(
			Basis(Vector3.UP, PI * 0.5 + deg_to_rad(-12.0)) * Basis(Vector3.RIGHT, -PI * 0.5), FigClearingProps.DRAWER_KEY_AT
		)
		_contents.add_child(key)


## The drum's angle in turns of a third: step `value` brings the pane `value` mod 3 to the front.
func _set_drum_angle(value: float) -> void:
	if _drum != null:
		_drum.rotation.y = -TAU * value / float(FigClearingProps.LANTERN_PANEL_COUNT)


func _light_up(index: int) -> void:
	if _glow != null:
		create_tween().tween_property(_glow, "light_color", FILTER_COLORS[index], turn_seconds)


func _play(stream: AudioStream, volume_db: float) -> void:
	_sound.stream = stream
	_sound.volume_db = volume_db
	_sound.play()


func _key() -> StringName:
	return StringName("%s_open" % persistent_id)


## The open lantern must not keep catching the interaction ray: its area sits over the drawer's contents and would
## hide them from the player's aim.
func _disable_lens() -> void:
	var area: Node = get_node_or_null(^"InteractArea")
	if area != null:
		for shape: Node in area.get_children():
			if shape is CollisionShape3D:
				(shape as CollisionShape3D).set_deferred("disabled", true)
