@tool
extends Node3D
class_name SignalTowerBuilder

## The ruined signal tower: a two storey railway signal cabin, the children's headquarters of the story. The building is the ready-made model
## `signal_box_ruined.glb` (a red brick relay room under a red clapboard control cabin with a tiled roof, broken panes and a plank ramp up to a
## balcony), turned and moved here so that it keeps the frame the blockout had, and given collision from its own triangles. The furniture is
## `SignalTowerProps`, the two doors are the game's `DoorController` (with the `door_001` model), and the ivy and the rubble are built in
## code. Built at runtime, so nothing here is saved in the scene file.
##
## Drawn in metres, the origin at the middle of the foot of the tower, the front (and its door) facing +Z:
##
##   Lower level   the relay room, 4 x 4 m inside, floor at y 0.005, ceiling (the deck's underside) at 2.9; the door in the front wall left
##                 of the middle (x about -0.955) and a barred arched window right of it, two arched windows in the left wall, none in the
##                 back and right walls
##   Upper level   the control cabin, 4 x 4 m inside, floor at y 3.006, under the pitched roof (ridge 7.4 m, along X); broken ribbon windows
##                 on the front, back and left, and the door on the +X wall at z about -0.94
##   Outside       a plank ramp with rails up the +X side (it starts on the ground at z about 3.6 and rises towards the back) to a balcony
##                 at the cabin's door

## The inventory id of the brass key that used to open the front door (`brass_signal_key.tscn`). Nothing asks for it now, but an
## old save may still carry one in the inventory, where it is harmless.
const KEY_ID: String = "brass_signal_key"

const SHELL_SCENE: PackedScene = preload("res://assets/models/buildings/signal_box_ruined/signal_box_ruined.glb")
## The model's file frame to ours: its door wall (+X in the file) faces +Z here, and its relay room's middle (x -0.124 in the file) is the origin.
const SHELL_YAW_DEGREES: float = -90.0
const SHELL_OFFSET: Vector3 = Vector3(0.0, 0.0, 0.124)
## Surfaces of the model that have no collision: the panes and the roof tiles.
const NO_COLLISION_MATERIALS: Array[String] = ["glass", "roof_tiles"]

## Half the size of both rooms inside (4 x 4 m), and the outer face of the brick and of the cabin's walls.
const ROOM_HALF: float = 2.0
const WALL_FACE: float = 2.25
## The top of the floorboards inside the relay room.
const FLOOR_TOP: float = 0.005
## The cabin's floor (the deck's top) and how far under the roof the stove's pipe reaches, above that floor.
const BASE_HEIGHT: float = 3.006
const STOVE_PIPE_TOP: float = 3.9

# -- Doors --
const DOOR_WIDTH: float = 0.8
const DOOR_HEIGHT: float = 2.07
## The middle of the front door along the front wall, and of the cabin's door along the +X wall.
const DOOR_X: float = -0.955
const UPPER_DOOR_Z: float = -0.941
## Where each door stands across its wall (the middle of the wall's thickness, 0.25 m).
const FRONT_DOOR_Z: float = 2.125
const UPPER_DOOR_X: float = 2.125

const VINE_COUNT: int = 24

var lower_door: DoorController = null
var upper_door: DoorController = null
var props: SignalTowerProps = null
## The collision of the building, from the model's own triangles.
var shell_body: StaticBody3D = null

## Where the ivy's leaves are (kept: a headless run discards the multimesh data).
var ivy_leaf_points: PackedVector3Array = PackedVector3Array()

static var _shell_shape: ConcavePolygonShape3D = null

var _brick: StandardMaterial3D
var _shingle: StandardMaterial3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if get_child_count() > 0:
		return

	_rng.seed = 1888
	_make_materials()
	_build_shell()
	_build_stair_ramp()
	_build_doors()
	_build_ivy()
	_build_rubble()

	props = SignalTowerProps.new()
	props.name = "Props"
	add_child(props)
	_add_ambience_zones()


## Inside, the wind outside is heard muffled (`OutdoorAmbience`): less in the cabin, whose windows are broken, than in the brick relay room,
## whose door and arched windows are its only openings.
func _add_ambience_zones() -> void:
	if Engine.is_editor_hint():
		return

	var inner: float = ROOM_HALF * 2.0
	var relay_height: float = 2.9 - FLOOR_TOP
	var relay: AmbienceZone = AmbienceZone.new()
	relay.name = "AmbienceRelayRoom"
	relay.position = Vector3(0.0, FLOOR_TOP + relay_height * 0.5, 0.0)
	relay.size = Vector3(inner, relay_height, inner)
	relay.interior = 0.7
	add_child(relay)

	var cabin_height: float = 3.2
	var cabin: AmbienceZone = AmbienceZone.new()
	cabin.name = "AmbienceCabin"
	cabin.position = Vector3(0.0, BASE_HEIGHT + cabin_height * 0.5, 0.0)
	cabin.size = Vector3(inner, cabin_height, inner)
	cabin.interior = 0.5
	add_child(cabin)


# ============================================================
# THE BUILDING
# ============================================================

func _build_shell() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Shell"
	holder.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(SHELL_YAW_DEGREES)), SHELL_OFFSET)
	add_child(holder)

	var model: Node3D = SHELL_SCENE.instantiate() as Node3D
	model.name = "Model"
	holder.add_child(model)

	shell_body = StaticBody3D.new()
	shell_body.name = "ShellBody"
	holder.add_child(shell_body)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = _collision_shape(model)
	shell_body.add_child(shape)


## The model's stairs up the +X side are 13 treads of 0.2275 m. The player does not step up (see `stairs.gd`), so a smooth ramp is laid over them: a thin
## box whose top touches the treads' nose line (a little above it), from the ground in front (z 4.06) to the balcony's floor (z 0.24), 1.1 m wide
## between the rails (centred on x 3.0). The treads' own triangles stay under it.
const RAMP_X: float = 3.0
const RAMP_WIDTH: float = 1.1
const RAMP_TOP: Vector2 = Vector2(0.238, 2.99)
const RAMP_FOOT: Vector2 = Vector2(4.057, 0.0)


func _build_stair_ramp() -> void:
	var run: Vector2 = RAMP_FOOT - RAMP_TOP
	var length: float = run.length()
	var along: Vector3 = Vector3(0.0, run.y, run.x) / length
	var normal: Vector3 = Vector3(0.0, run.x, -run.y) / length
	var thickness: float = 0.1
	var middle: Vector3 = Vector3(RAMP_X, (RAMP_TOP.y + RAMP_FOOT.y) * 0.5, (RAMP_TOP.x + RAMP_FOOT.x) * 0.5) - normal * thickness * 0.5
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "StairRamp"
	body.transform = Transform3D(Basis(Vector3.RIGHT, normal, along), middle)
	add_child(body)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(RAMP_WIDTH, thickness, length)
	shape.shape = box
	body.add_child(shape)


## One trimesh of every surface of the model but the panes and the roof tiles (a player walks through the broken windows' holes, the bars and
## the sills are solid), made once.
static func _collision_shape(model: Node3D) -> ConcavePolygonShape3D:
	if _shell_shape != null:
		return _shell_shape

	var kept: ArrayMesh = ArrayMesh.new()
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var source: Mesh = (node as MeshInstance3D).mesh
		for surface: int in source.get_surface_count():
			var material: Material = source.surface_get_material(surface)
			if material != null and NO_COLLISION_MATERIALS.has(material.resource_name):
				continue

			kept.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
	_shell_shape = kept.create_trimesh_shape()
	# The deck's underside and the walls' inner faces are single sided in the model: let a ray meet them from the other side too.
	_shell_shape.backface_collision = true
	return _shell_shape


# ============================================================
# DOORS
# ============================================================

func _build_doors() -> void:
	var front: Node3D = _make_door(
		"FrontDoor", Vector3(DOOR_X - DOOR_WIDTH * 0.5, FLOOR_TOP, FRONT_DOOR_Z), 0.0, &"signal_tower_front_door"
	)
	lower_door = front as DoorController
	# A save from when the door wanted the brass key may hold it locked (the door restores itself as it enters the tree, just above): this
	# door is never locked now, so it is let go at once, open or shut as it was saved, and no key is asked for or taken.
	# (Not in the editor: there the door's script is a placeholder, which has the exported properties but no `is_locked`.)
	if lower_door != null and not Engine.is_editor_hint() and lower_door.is_locked:
		lower_door.unlock()

	upper_door = _make_door(
		"BalconyDoor", Vector3(UPPER_DOOR_X, BASE_HEIGHT, UPPER_DOOR_Z + DOOR_WIDTH * 0.5), 90.0, &"signal_tower_balcony_door"
	) as DoorController


## A standard door (the `door_001` model) hung in an opening of the model: the opening's frame is part of the building.
func _make_door(door_name: String, hinge_position: Vector3, yaw_degrees: float, persistent: StringName) -> Node3D:
	var door: Node3D = (load("res://scenes/objects/door_interactable.tscn") as PackedScene).instantiate() as Node3D
	door.name = door_name
	door.set("starts_locked", false)
	door.set("required_key_id", "")
	door.set("persistent_id", persistent)
	door.set("leaf_width", DOOR_WIDTH)
	door.set("leaf_height", DOOR_HEIGHT)
	door.position = hinge_position
	door.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	door.set("door_sounds_enabled", false)
	add_child(door)
	return door


# ============================================================
# IVY
# ============================================================

## Vines creeping up the brick: thin stems in one multimesh, leaves in another.
func _build_ivy() -> void:
	var stems: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var faces: Array[Vector3] = [Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0)]
	var wall_face: float = WALL_FACE

	for i: int in VINE_COUNT:
		var n: Vector3 = faces[i % 3 if i < VINE_COUNT - 3 else 3]
		var tangent: Vector3 = Vector3.UP.cross(n)
		var along: float = _rng.randf_range(-1.6, 1.6)
		# Not across the door, and the stairs hide the +X side.
		if n.z > 0.5 and absf(along - DOOR_X) < 0.75:
			along = 1.2
		if n.x > 0.5:
			along = _rng.randf_range(-1.6, -0.1)

		var height: float = _rng.randf_range(0.9, 2.55)
		var y: float = 0.0
		var drift: float = _rng.randf_range(-0.04, 0.04)
		var point: Vector3 = _wall_point(n, tangent, along, y, wall_face)
		while y < height:
			y += 0.14
			along += drift + _rng.randf_range(-0.045, 0.045)
			along = clampf(along, -1.65, 1.65)
			var next_point: Vector3 = _wall_point(n, tangent, along, y, wall_face)
			stems.append(_segment(point, next_point, 0.02 * (1.0 - y / (height + 0.5)) + 0.008))

			var leaf_count: int = 3 if y < height * 0.7 else 2
			for k: int in leaf_count:
				var spot: Vector3 = next_point + tangent * _rng.randf_range(-0.13, 0.13) + Vector3.UP * _rng.randf_range(-0.07, 0.07) + n * 0.012
				var base_basis: Basis = Basis(tangent, Vector3.UP, n)
				var spin: Basis = Basis(Vector3(0.0, 0.0, 1.0), _rng.randf_range(0.0, TAU))
				var tilt: Basis = Basis(Vector3.RIGHT, _rng.randf_range(-0.35, 0.35))
				var leaf_scale: float = _rng.randf_range(0.075, 0.14)
				leaves.append(Transform3D((base_basis * tilt * spin).scaled_local(Vector3.ONE * leaf_scale), spot))
				ivy_leaf_points.append(spot)
				var shade: float = _rng.randf_range(0.7, 1.15)
				leaf_colors.append(Color(0.22 * shade, 0.38 * shade, 0.14 * shade) if _rng.randf() < 0.8 else Color(0.34 * shade, 0.36 * shade, 0.12 * shade))

			point = next_point
			drift = clampf(drift + _rng.randf_range(-0.02, 0.02), -0.07, 0.07)

	var ivy: Node3D = Node3D.new()
	ivy.name = "Ivy"
	add_child(ivy)

	var stem_mesh: CylinderMesh = CylinderMesh.new()
	stem_mesh.top_radius = 0.5
	stem_mesh.bottom_radius = 0.5
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 5
	stem_mesh.rings = 1
	stem_mesh.cap_top = false
	stem_mesh.cap_bottom = false
	var stem_multi: MultiMesh = MultiMesh.new()
	stem_multi.transform_format = MultiMesh.TRANSFORM_3D
	stem_multi.mesh = stem_mesh
	stem_multi.instance_count = stems.size()
	for i: int in stems.size():
		stem_multi.set_instance_transform(i, stems[i])
	var stem_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	stem_instance.name = "Stems"
	stem_instance.multimesh = stem_multi
	stem_instance.material_override = HouseProps.material(Color(0.2, 0.15, 0.09), 0.95)
	ivy.add_child(stem_instance)

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var leaf_multi: MultiMesh = MultiMesh.new()
	leaf_multi.transform_format = MultiMesh.TRANSFORM_3D
	leaf_multi.use_colors = true
	leaf_multi.mesh = quad
	leaf_multi.instance_count = leaves.size()
	for i: int in leaves.size():
		leaf_multi.set_instance_transform(i, leaves[i])
		leaf_multi.set_instance_color(i, leaf_colors[i])
	var leaf_material: StandardMaterial3D = HouseProps.material(Color.WHITE, 0.85)
	leaf_material.albedo_texture = _make_leaf_texture()
	leaf_material.vertex_color_use_as_albedo = true
	leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaf_material.alpha_scissor_threshold = 0.5
	leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaf_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	leaf_instance.name = "Leaves"
	leaf_instance.multimesh = leaf_multi
	leaf_instance.material_override = leaf_material
	ivy.add_child(leaf_instance)


## A point on the wall surface, a little off the bricks.
func _wall_point(n: Vector3, tangent: Vector3, along: float, y: float, wall_face: float) -> Vector3:
	var out: float = wall_face + 0.03
	return n * out + tangent * along + Vector3(0.0, y, 0.0)


## The unit cylinder stretched from `from_point` to `to_point`.
func _segment(from_point: Vector3, to_point: Vector3, thickness: float) -> Transform3D:
	var direction: Vector3 = to_point - from_point
	var length: float = direction.length()
	var y_axis: Vector3 = direction / maxf(length, 0.0001)
	var helper: Vector3 = Vector3.RIGHT if absf(y_axis.x) < 0.9 else Vector3.FORWARD
	var x_axis: Vector3 = y_axis.cross(helper).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	var segment_basis: Basis = Basis(x_axis * thickness * 2.0, y_axis * length, z_axis * thickness * 2.0)
	return Transform3D(segment_basis, (from_point + to_point) * 0.5)


# ============================================================
# RUBBLE
# ============================================================

## Fallen bricks, a drift of loose tiles and a snapped board lying at the foot of the walls.
func _build_rubble() -> void:
	var rubble: Node3D = Node3D.new()
	rubble.name = "Rubble"
	add_child(rubble)

	for i: int in 12:
		var spot: Vector3 = Vector3(_rng.randf_range(-3.2, -2.5), 0.04, _rng.randf_range(-1.8, 2.0))
		if i % 3 == 0:
			spot = Vector3(_rng.randf_range(-1.5, 1.2), 0.04, _rng.randf_range(-3.1, -2.5))

		var brick: MeshInstance3D = HouseProps.add_box(
			rubble, "Brick%d" % i, Vector3(0.215, 0.065, 0.1), spot, _brick
		)
		brick.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.2, 0.2))

	for i: int in 9:
		var tile: MeshInstance3D = HouseProps.add_box(
			rubble, "Tile%d" % i, Vector3(0.22, 0.015, 0.3),
			Vector3(_rng.randf_range(-3.6, -2.5), 0.02, _rng.randf_range(-3.4, -1.0)), _shingle
		)
		tile.rotation = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.15, 0.15))



# ============================================================
# MATERIALS
# ============================================================

func _make_materials() -> void:
	_brick = HouseProps.material(Color.WHITE, 0.95)
	_brick.albedo_texture = _make_brick_texture()
	_brick.uv1_triplanar = true
	_brick.uv1_world_triplanar = true
	_brick.uv1_scale = Vector3.ONE * (1.0 / 0.9)

	_shingle = HouseProps.material(Color.WHITE, 0.92)
	_shingle.albedo_texture = _make_shingle_texture()
	_shingle.uv1_triplanar = true
	_shingle.uv1_scale = Vector3.ONE * 0.9


## Red brick, 4 bricks across and 12 courses to the tile (0.9 m square): each brick its own shade,
## the mortar crumbling, a few burnt dark ones, and soot running down from above.
func _make_brick_texture() -> ImageTexture:
	var size: int = 256
	var courses: int = 12
	var bricks: int = 4
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41

	var grime: FastNoiseLite = FastNoiseLite.new()
	grime.seed = 9
	grime.frequency = 0.02
	grime.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	var tints: Array[float] = []
	for k: int in courses * (bricks + 1):
		tints.append(rng.randf_range(0.75, 1.15))

	var course_h: float = float(size) / float(courses)
	var brick_w: float = float(size) / float(bricks)
	for y: int in size:
		var course: int = int(float(y) / course_h)
		var local_y: float = float(y) - float(course) * course_h
		var shift: float = brick_w * 0.5 if course % 2 == 1 else 0.0
		for x: int in size:
			var sx: float = fposmod(float(x) - shift, float(size))
			var column: int = int(sx / brick_w)
			var local_x: float = sx - float(column) * brick_w
			var color: Color = Color(0.55, 0.52, 0.46)
			if local_y > 2.0 and local_x > 2.0:
				var tint: float = tints[course * (bricks + 1) + column]
				var burnt: float = 0.78 if tints[course * (bricks + 1) + column] < 0.8 else 1.0
				color = Color(0.58, 0.22, 0.15) * tint * burnt
				color *= 1.0 + rng.randf_range(-0.06, 0.06)
			else:
				color *= 1.0 + rng.randf_range(-0.08, 0.08)
			var stain: float = grime.get_noise_2d(float(x) * 0.6, float(y) * 0.12)
			if stain > 0.15:
				color *= 1.0 - (stain - 0.15) * 0.9
			image.set_pixel(x, y, color)

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Dark slate shingles in staggered rows, a few missing so the boards show through.
func _make_shingle_texture() -> ImageTexture:
	var size: int = 256
	var rows: int = 8
	var per_row: int = 8
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 29

	var row_h: int = int(size / float(rows))
	var tile_w: int = int(size / float(per_row))
	var gone: Dictionary = {}
	for row: int in rows:
		for column: int in per_row:
			if rng.randf() < 0.07:
				gone[row * per_row + column] = true

	for row: int in rows:
		var shift: int = int(tile_w * 0.5) if row % 2 == 1 else 0
		for y: int in row_h:
			var py: int = row * row_h + y
			for x: int in size:
				var sx: int = (x - shift + size) % size
				var column: int = int(sx / float(tile_w))
				var local_x: int = sx - column * tile_w
				var color: Color = Color(0.14, 0.14, 0.15) * rng.randf_range(0.85, 1.15)
				if gone.has(row * per_row + column):
					color = Color(0.07, 0.05, 0.04) * rng.randf_range(0.8, 1.2)
				elif (row * 7 + column * 3) % 11 == 0:
					color = Color(0.24, 0.24, 0.22) * rng.randf_range(0.9, 1.1)
				if y >= row_h - 3 or local_x < 1:
					color *= 0.4
				image.set_pixel(x, py, color)

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## A pointed ivy leaf with a pale midrib; white, tinted per instance.
func _make_leaf_texture() -> ImageTexture:
	var size: int = 48
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		var v: float = float(y) / float(size - 1)
		# 0 at the stem (bottom), 1 at the tip (top).
		var t: float = 1.0 - v
		var half_width: float = sin(clampf(t * 1.15, 0.0, 1.0) * PI) * (0.5 - 0.22 * t) * 1.2
		for x: int in size:
			var u: float = float(x) / float(size - 1) - 0.5
			if absf(u) > half_width or t < 0.03:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue

			var shade: float = 1.0 - absf(u) / maxf(half_width, 0.001) * 0.25
			if absf(u) < 0.025:
				shade = 1.35
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
