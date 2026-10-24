@tool
extends Node3D
class_name ForestMapMarker

## The red dot on the forest map that shows where the player stands, with an arrow for the way they look and a ring
## that swells and fades now and then so the eye finds it. It lives on the map's `Visual`, so the inspect view's copy
## of the map has it too: it reads the player's position every frame, wherever the map is (on the ground, in the
## hand, in the inventory). Standing off the sheet, it stays on the nearest edge, dimmer.
##
## Built in code, in the sheet's frame (x right, y up, facing +Z). See `ForestMapProps`.

const DOT_RADIUS: float = 0.0052
const ARROW_LENGTH: float = 0.02
const ARROW_HALF_WIDTH: float = 0.008
const RING_RADIUS: float = 0.011
const RING_SECONDS: float = 1.8
const LIFT: float = 0.0019
## How far from the sheet's edge the dot stays, in metres.
const EDGE_MARGIN: float = 0.012
const RED: Color = Color(0.78, 0.07, 0.05)

## Where the player is on the sheet, in its frame (the tests read it).
var paper_position: Vector2 = Vector2.ZERO
## True while the player is on the sheet.
var on_sheet: bool = false

var _arrow: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _ring_material: StandardMaterial3D = null
var _time: float = 0.0


static func dot_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = HouseProps.material(RED, 0.6)
	material.emission_enabled = true
	material.emission = RED
	material.emission_energy_multiplier = 0.5
	return material


func _ready() -> void:
	# A copy of a built marker (the inspect view duplicates the map) already has its parts.
	if get_child_count() == 0:
		_build()
	else:
		_arrow = get_node_or_null("Arrow") as MeshInstance3D
		_ring = get_node_or_null("Ring") as MeshInstance3D
		_ring_material = _ring.material_override as StandardMaterial3D if _ring != null else null

	position.z = LIFT
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_time += delta
	_pulse()

	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		visible = false
		return

	visible = true
	var world: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	on_sheet = ForestMapProps.covers(world)
	paper_position = ForestMapProps.world_to_paper(world)

	var half: Vector2 = ForestMapProps.paper_size() * 0.5 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	paper_position = paper_position.clamp(-half, half)
	position = Vector3(paper_position.x, paper_position.y, LIFT)
	if _arrow != null:
		var facing: Vector2 = _facing_on_sheet(player)
		_arrow.rotation.z = atan2(-facing.x, facing.y)
		_arrow.visible = facing.length() > 0.01

	scale = Vector3.ONE if on_sheet else Vector3(0.6, 0.6, 0.6)


## The way the player looks, on the sheet (x right, y up): the world's x and -z.
func _facing_on_sheet(player: Node3D) -> Vector2:
	var forward: Vector3 = -player.global_transform.basis.z
	var movement: Object = player.get("movement_controller") as Object
	if movement != null:
		var camera: Camera3D = movement.get("camera") as Camera3D
		if camera != null:
			forward = -camera.global_transform.basis.z

	return Vector2(forward.x, -forward.z).normalized()


func _pulse() -> void:
	if _ring == null or _ring_material == null:
		return

	var phase: float = fposmod(_time, RING_SECONDS) / RING_SECONDS
	_ring.scale = Vector3.ONE * lerpf(0.7, 1.7, phase)
	var color: Color = RED
	color.a = (1.0 - phase) * 0.55
	_ring_material.albedo_color = color


func _build() -> void:
	var dot: MeshInstance3D = HouseProps.add_cylinder(self, "Dot", DOT_RADIUS, 0.0006, Vector3.ZERO, dot_material(), Vector3(90.0, 0.0, 0.0))
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_ring_material = HouseProps.material(RED, 1.0)
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring = HouseProps.add_ring(self, "Ring", RING_RADIUS - 0.0007, RING_RADIUS, Vector3(0.0, 0.0, -0.0003), _ring_material)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# The arrow points up the sheet; it is turned to the way the player looks.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.BACK)
	for corner: Vector3 in [
		Vector3(0.0, DOT_RADIUS + ARROW_LENGTH, 0.0),
		Vector3(-ARROW_HALF_WIDTH, DOT_RADIUS + 0.002, 0.0),
		Vector3(ARROW_HALF_WIDTH, DOT_RADIUS + 0.002, 0.0),
	]:
		surface.add_vertex(corner)

	var arrow_material: StandardMaterial3D = dot_material()
	arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arrow = MeshInstance3D.new()
	_arrow.name = "Arrow"
	_arrow.mesh = surface.commit()
	_arrow.material_override = arrow_material
	_arrow.position = Vector3(0.0, 0.0, 0.0003)
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrow)
