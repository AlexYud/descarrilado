extends MeshInstance3D
class_name CoiledCord

## A telephone's coiled cable between two anchors. It hangs in a curve (the slack
## sags downward, a stretched cord is straight) and the mesh is wound as a helix
## along that curve, with a short plain stretch at each end. It is rebuilt only when
## an anchor has moved, so a cord at rest costs nothing.

## The cord's length when it is not stretched, in metres.
@export var rest_length: float = 0.62
## How many times it winds round over its length.
@export var turns: float = 34.0
@export var coil_radius: float = 0.0085
@export var wire_radius: float = 0.0032
## Points per turn along the helix.
@export var points_per_turn: int = 9
## Fraction of the length at each end that is not coiled.
@export_range(0.0, 0.3, 0.01) var plain_fraction: float = 0.07
## A silver armoured cord, as on the real ones.
@export var color: Color = Color(0.03, 0.03, 0.035)

var start_anchor: Node3D = null
var end_anchor: Node3D = null

var _built_start: Vector3 = Vector3(INF, INF, INF)
var _built_end: Vector3 = Vector3(INF, INF, INF)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY

	var rubber: StandardMaterial3D = StandardMaterial3D.new()
	rubber.albedo_color = color
	rubber.roughness = 0.4
	rubber.metallic = 0.6
	material_override = rubber
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	set_process(true)


## Joins the cord to two nodes (it follows them). Call after both are in the tree.
func attach(start: Node3D, end: Node3D) -> void:
	start_anchor = start
	end_anchor = end
	_rebuild(true)


func _process(_delta: float) -> void:
	_rebuild(false)


func _rebuild(force: bool) -> void:
	if start_anchor == null or end_anchor == null:
		return

	var from: Vector3 = start_anchor.global_position
	var to: Vector3 = end_anchor.global_position
	if (
		not force
		and from.distance_squared_to(_built_start) < 0.0000001
		and to.distance_squared_to(_built_end) < 0.0000001
	):
		return

	_built_start = from
	_built_end = to
	mesh = _make_mesh(from, to)


## The centre line: a cubic curve that leaves the outlet along its axis (down) and
## enters the port along its axis, bulging down as the slack grows.
func _centre_point(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var a: Vector3 = p0.lerp(p1, t)
	var b: Vector3 = p1.lerp(p2, t)
	var c: Vector3 = p2.lerp(p3, t)
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _make_mesh(from: Vector3, to: Vector3) -> ArrayMesh:
	var distance: float = from.distance_to(to)
	var slack_ratio: float = clampf((rest_length - distance) / rest_length, 0.0, 1.0)
	var reach: float = distance * 0.05 + slack_ratio * rest_length * 0.5
	var droop: Vector3 = Vector3.DOWN * slack_ratio * rest_length * 0.18
	var leaves: Vector3 = -start_anchor.global_basis.y.normalized()
	var enters: Vector3 = end_anchor.global_basis.y.normalized()
	var control_a: Vector3 = from + leaves * reach + droop
	var control_b: Vector3 = to + enters * reach + droop

	var samples: int = maxi(int(turns * points_per_turn), 24)
	var sides: int = 5
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	var previous_dir: Vector3 = Vector3.ZERO
	var side_a: Vector3 = Vector3.RIGHT
	for i: int in samples + 1:
		var t: float = float(i) / samples
		var centre: Vector3 = _centre_point(from, control_a, control_b, to, t)
		var ahead: Vector3 = _centre_point(from, control_a, control_b, to, minf(t + 0.004, 1.0))
		var behind: Vector3 = _centre_point(from, control_a, control_b, to, maxf(t - 0.004, 0.0))
		var direction: Vector3 = (ahead - behind).normalized()
		if direction.length_squared() < 0.5:
			direction = previous_dir if previous_dir != Vector3.ZERO else Vector3.DOWN

		# A frame that turns smoothly along the curve.
		if previous_dir == Vector3.ZERO:
			side_a = direction.cross(Vector3.RIGHT)
			if side_a.length_squared() < 0.01:
				side_a = direction.cross(Vector3.FORWARD)
		else:
			side_a = side_a - direction * side_a.dot(direction)

		side_a = side_a.normalized()
		var side_b: Vector3 = direction.cross(side_a).normalized()
		previous_dir = direction

		# The coil's radius eases to nothing at both ends.
		var ramp: float = smoothstep(0.0, plain_fraction, t) * smoothstep(0.0, plain_fraction, 1.0 - t)
		var angle: float = TAU * turns * t
		var radial: Vector3 = (side_a * cos(angle) + side_b * sin(angle))
		var helix_centre: Vector3 = centre + radial * coil_radius * ramp

		for s: int in sides:
			var ring_angle: float = TAU * float(s) / sides
			var ring: Vector3 = (side_a * cos(ring_angle) + side_b * sin(ring_angle))
			vertices.append(helix_centre + ring * wire_radius)
			normals.append(ring)

		if i > 0:
			var base: int = (i - 1) * sides
			for s: int in sides:
				var s2: int = (s + 1) % sides
				var a: int = base + s
				var b: int = base + s2
				var c: int = base + sides + s
				var d: int = base + sides + s2
				indices.append_array([a, c, b, b, c, d])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
