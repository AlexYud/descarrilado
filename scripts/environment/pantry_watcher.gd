extends Node3D
class_name PantryWatcher

## The optional watcher of the unfinished house: a completely black head that looks round the pantry door's frame at whoever comes along the corridor,
## and is gone (back into the room, behind the wall) the moment it is noticed. It is the rigged basic model (the same body as the figure at the fig
## clearing), drawn by a shader that throws away everything below the jaw, so nothing of a neck, a body or arms can ever show; what is left is lit by
## nothing and not tinted by the air (pure black against the lit room behind it, no skin, eyes or mouth, nothing that glows).
##
## The node's origin is the line of the jaw, where the head is cut off (about 1.5 m up for a standing person); `peek_yaw_degrees` says where the face looks (0:
## along local +Z).
## The head is put partly behind the door frame by where the node is placed in the scene (the half of it past the jamb is the half that shows). It leans out
## round the wall's edge as someone does who is hiding behind it and looking along the corridor: the head tilted towards the opening (`lean_degrees`, about the
## base of the neck), and a glimpse of the shoulder on that side (the cut under the jaw drops there by `shoulder_drop`); the rest of the body is never shown.

const MODEL: String = "res://assets/models/characters/basic_model/basic_model_rigged.tscn"
const PREFIX: String = "mixamorig_"

const HEAD_SHADER: String = """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform float cut_y = 1.5;
uniform float shoulder_drop = 0.0;
uniform float shoulder_side = -1.0;
varying float local_y;
varying float local_x;
void vertex() {
	local_y = VERTEX.y;
	local_x = VERTEX.x * shoulder_side;
}
void fragment() {
	// Under the jaw nothing, except on the shoulder's side, where the cut drops to show the top of that shoulder (and no arm).
	float lower = shoulder_drop * smoothstep(0.0, 0.08, local_x) * (1.0 - smoothstep(0.17, 0.24, local_x));
	if (local_y < cut_y - lower) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
"""

## Where the face looks: degrees about the vertical from local +Z.
@export var peek_yaw_degrees: float = -90.0
## How far, in the parent's frame, the head goes back into the room when it is noticed, and how long that takes.
@export var retreat_offset: Vector3 = Vector3(0.0, 0.0, 0.5)
@export var retreat_seconds: float = 1.0
## The lean: the head tilts this far (degrees, about the way the face looks) towards the side the wall is not, from a point `neck_drop` under the jaw; the shoulder
## on that side shows `shoulder_drop` below the jaw line (the model's local X sign of that side is `shoulder_side`).
@export var lean_degrees: float = 26.0
@export var neck_drop: float = 0.12
@export var shoulder_drop: float = 0.12
@export var shoulder_side: float = -1.0

## True while the head shows (before it is noticed).
var is_peeking: bool = false

var _lean: Node3D = null
var _model: Node3D = null
var _cap: MeshInstance3D = null
var _home: Vector3 = Vector3.ZERO
var _tween: Tween = null


func _ready() -> void:
	_home = position
	_build()
	_show(false)


## Makes the head (once): the model, with the shader that keeps only what is above the jaw, and a black disc over the cut so that it cannot be seen into.
func _build() -> void:
	if _model != null:
		return

	# The lean pivots at the base of the neck: the way the face looks is the axis of the roll.
	_lean = Node3D.new()
	_lean.name = "Lean"
	_lean.position = Vector3(0.0, -neck_drop, 0.0)
	_lean.basis = Basis(Vector3.BACK.rotated(Vector3.UP, deg_to_rad(peek_yaw_degrees)), deg_to_rad(lean_degrees))
	add_child(_lean)

	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	_model.rotation_degrees.y = peek_yaw_degrees
	_lean.add_child(_model)
	var skeleton: Skeleton3D = _model.get_node("Skeleton3D") as Skeleton3D
	var body: MeshInstance3D = skeleton.get_node("Body") as MeshInstance3D
	var head_bone: int = skeleton.find_bone(PREFIX + "Head")
	var pivot: Vector3 = skeleton.get_bone_global_rest(head_bone).origin
	var cut: float = pivot.y - 0.07

	var shader: Shader = Shader.new()
	shader.code = HEAD_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"cut_y", cut)
	material.set_shader_parameter(&"shoulder_drop", shoulder_drop)
	material.set_shader_parameter(&"shoulder_side", shoulder_side)
	body.material_override = material
	# The head at the node's height: the model stands `cut` below it.
	_model.position.y = -cut + 0.07 + neck_drop

	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.075
	disc.bottom_radius = 0.075
	disc.height = 0.006
	var disc_material: StandardMaterial3D = StandardMaterial3D.new()
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_material.albedo_color = Color.BLACK
	disc_material.disable_fog = true
	_cap = MeshInstance3D.new()
	_cap.name = "NeckCap"
	_cap.mesh = disc
	_cap.material_override = disc_material
	_cap.position = Vector3(pivot.x, 0.07 + 0.003 + neck_drop, pivot.z).rotated(Vector3.UP, deg_to_rad(peek_yaw_degrees))
	_lean.add_child(_cap)


func _show(shown: bool) -> void:
	visible = shown
	is_peeking = shown


## The head is there, looking round the frame.
func peek() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = _home
	_show(true)


## The head is not there (and does not come back until `peek`): at once.
func hide_now() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = _home
	_show(false)


## It has been noticed: the head goes back into the room, behind the wall, and is hidden. Returns the tween's length in seconds (`seconds` below zero: its own).
func retreat(seconds: float = -1.0) -> float:
	if not is_peeking:
		return 0.0

	if seconds < 0.0:
		seconds = retreat_seconds
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", _home + retreat_offset, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void: _show(false))
	return seconds


## The middle of the head in the world (a hand's breadth over the jaw line).
func head_point() -> Vector3:
	if _lean == null:
		return global_position + Vector3.UP * 0.12
	return _lean.global_transform * Vector3(0.0, neck_drop + 0.12, 0.0)
