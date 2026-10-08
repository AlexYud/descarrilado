@tool
extends Node3D
class_name UnfinishedHouseBuilder

## Builds the shell of the unfinished house: floors, walls with door and window
## openings, ceiling, roof and window glass. Everything is a plain box so the
## house is cheap to change; the plan lives in `_walls()`.
##
## Plan (drawn in metres at 1:1 and stretched by PLAN_SCALE; X east, Z south, the origin the north-west corner, the
## front door faces +Z):
##
##   z 0..4    Kitchen x 0..3        Master bedroom x 3..7.5
##   z 4..5.5  Hallway   x 0..6      Pantry x 6..7.5 (z 4..6)
##   z 5.5..10 Living room x 0..6
##
## Built at runtime, so nothing here is saved in the scene file.

const WALL_HEIGHT: float = 2.6
const WALL_THICKNESS: float = 0.18
const DOOR_HEIGHT: float = 2.05
const DOOR_WIDTH: float = 0.94
const CEILING_THICKNESS: float = 0.12
const ROOF_PITCH_DEGREES: float = 21.0

## The casing sticks this far into the opening, so its faces never coincide with the
## wall's own edge faces (coplanar faces flicker between the two colours).
const CASING_LIP: float = 0.012
const ROOF_OVERHANG: float = 0.45

## The plan below is drawn at 1:1 and every room is stretched by this much, so the
## house can be made roomier without redrawing it.
const PLAN_SCALE: float = 1.55

## The two rectangles the house is made of: Rect2(x, z, width, depth).
const BLOCKS: Array[Rect2] = [
	Rect2(0.0, 0.0, 7.5, 6.0),
	Rect2(0.0, 6.0, 6.0, 4.0),
]

var _wall_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _frame_material: StandardMaterial3D
var _wall_body: StaticBody3D


func _ready() -> void:
	if get_child_count() > 0:
		return

	_make_materials()
	_build_floor_and_ceiling()
	_build_walls()
	_build_roof()


# ============================================================
# PLAN
# ============================================================

## Every wall as a line between two points, with its openings measured along it
## from the first point: {center, width, height, sill, frame}.
func _walls() -> Array[Dictionary]:
	return [
		# North (back) wall: the back door into the kitchen and the bedroom window.
		{
			"from": Vector2(0.0, 0.0), "to": Vector2(7.5, 0.0),
			"openings": [
				_door(1.5),
				{"center": 5.25, "width": 1.0, "height": 2.0, "sill": 0.9, "frame": true},
			],
		},
		{"from": Vector2(7.5, 0.0), "to": Vector2(7.5, 6.0), "openings": []},
		{"from": Vector2(6.0, 6.0), "to": Vector2(7.5, 6.0), "openings": []},
		# Wall between the pantry/hallway and the rest: the pantry door.
		{
			"from": Vector2(6.0, 4.0), "to": Vector2(6.0, 10.0),
			"openings": [_door(0.75)],
		},
		# South (front) wall: the front door into the living room.
		{
			"from": Vector2(0.0, 10.0), "to": Vector2(6.0, 10.0),
			"openings": [
				# Two empty, glassless windows flank the front door.
				{"center": 1.0, "width": 0.9, "height": 1.2, "sill": 0.9, "frame": true, "glass": false},
				_door(3.0),
				{"center": 5.0, "width": 0.9, "height": 1.2, "sill": 0.9, "frame": true, "glass": false},
			],
		},
		# West wall: a window at the end of the hallway, facing the pantry door.
		{
			"from": Vector2(0.0, 0.0), "to": Vector2(0.0, 10.0),
			"openings": [
				{"center": 4.75, "width": 1.1, "height": 1.3, "sill": 0.75, "frame": true},
			],
		},
		# Kitchen and bedroom against the hallway: an arch and the bedroom door.
		{
			"from": Vector2(0.0, 4.0), "to": Vector2(7.5, 4.0),
			"openings": [
				{"center": 1.5, "width": 1.2, "height": 2.15, "sill": 0.0, "frame": false},
				_door(4.8),
			],
		},
		{"from": Vector2(3.0, 0.0), "to": Vector2(3.0, 4.0), "openings": []},
		# Hallway to the living room: a wide arch.
		{
			"from": Vector2(0.0, 5.5), "to": Vector2(6.0, 5.5),
			"openings": [
				{"center": 1.5, "width": 1.5, "height": 2.2, "sill": 0.0, "frame": false},
			],
		},
	]


func _door(center: float) -> Dictionary:
	return {
		"center": center, "width": DOOR_WIDTH, "height": DOOR_HEIGHT,
		"sill": 0.0, "frame": true,
	}


# ============================================================
# BUILDING
# ============================================================

func _build_floor_and_ceiling() -> void:
	var collision: StaticBody3D = StaticBody3D.new()
	collision.name = "FloorAndCeilingBody"
	add_child(collision)

	for i: int in BLOCKS.size():
		var rect: Rect2 = _scaled(BLOCKS[i])
		var center: Vector2 = rect.get_center()
		_add_slab(
			"Floor%d" % i, collision,
			Vector3(rect.size.x, 0.2, rect.size.y),
			Vector3(center.x, -0.1, center.y), _floor_material
		)
		_add_slab(
			"Ceiling%d" % i, collision,
			Vector3(rect.size.x, CEILING_THICKNESS, rect.size.y),
			Vector3(center.x, WALL_HEIGHT + CEILING_THICKNESS * 0.5, center.y),
			_floor_material
		)


func _add_slab(
	slab_name: String,
	body: StaticBody3D,
	size: Vector3,
	pos: Vector3,
	mat: Material
) -> void:
	HouseProps.add_box(self, slab_name, size, pos, mat)
	_add_shape(body, size, pos)


func _build_walls() -> void:
	_wall_body = StaticBody3D.new()
	_wall_body.name = "WallBody"
	add_child(_wall_body)

	var index: int = 0
	for wall: Dictionary in _walls():
		_build_wall(index, wall)
		index += 1


func _build_wall(index: int, wall: Dictionary) -> void:
	var from: Vector2 = (wall["from"] as Vector2) * PLAN_SCALE
	var to: Vector2 = (wall["to"] as Vector2) * PLAN_SCALE
	var along_x: bool = is_equal_approx(from.y, to.y)
	var length: float = absf(to.x - from.x) if along_x else absf(to.y - from.y)
	var origin: Vector2 = Vector2(minf(from.x, to.x), minf(from.y, to.y))
	var margin: float = WALL_THICKNESS * 0.5

	var openings: Array = []
	for source: Dictionary in wall["openings"] as Array:
		# Rooms grow with the plan; doors and windows keep their real size.
		var scaled_opening: Dictionary = source.duplicate()
		scaled_opening["center"] = float(source["center"]) * PLAN_SCALE
		openings.append(scaled_opening)
	openings.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["center"]) < float(b["center"])
	)

	var cursor: float = -margin
	var piece: int = 0
	for opening: Dictionary in openings:
		var left: float = float(opening["center"]) - float(opening["width"]) * 0.5
		var right: float = float(opening["center"]) + float(opening["width"]) * 0.5
		var top: float = float(opening["sill"]) + float(opening["height"])
		var sill: float = float(opening["sill"])

		_add_wall_piece(index, piece, along_x, origin, cursor, left, 0.0, WALL_HEIGHT)
		piece += 1
		_add_wall_piece(index, piece, along_x, origin, left, right, top, WALL_HEIGHT)
		piece += 1
		if sill > 0.0:
			_add_wall_piece(index, piece, along_x, origin, left, right, 0.0, sill)
			piece += 1

		if bool(opening["frame"]):
			_add_frame(index, piece, along_x, origin, opening)
			piece += 1

		cursor = right

	_add_wall_piece(index, piece, along_x, origin, cursor, length + margin, 0.0, WALL_HEIGHT)


## One box of wall between two distances along it and two heights.
func _add_wall_piece(
	index: int,
	piece: int,
	along_x: bool,
	origin: Vector2,
	start: float,
	end: float,
	bottom: float,
	top: float
) -> void:
	var span: float = end - start
	var height: float = top - bottom
	if span <= 0.001 or height <= 0.001:
		return

	var middle: float = start + span * 0.5
	var size: Vector3
	var pos: Vector3
	if along_x:
		size = Vector3(span, height, WALL_THICKNESS)
		pos = Vector3(origin.x + middle, bottom + height * 0.5, origin.y)
	else:
		size = Vector3(WALL_THICKNESS, height, span)
		pos = Vector3(origin.x, bottom + height * 0.5, origin.y + middle)

	HouseProps.add_box(self, "Wall%d_%d" % [index, piece], size, pos, _wall_material)
	_add_shape(_wall_body, size, pos)



## Casing around a door, or around the window together with its glass and sill.
func _add_frame(
	index: int,
	piece: int,
	along_x: bool,
	origin: Vector2,
	opening: Dictionary
) -> void:
	var width: float = float(opening["width"])
	var height: float = float(opening["height"])
	var sill: float = float(opening["sill"])
	var center: float = float(opening["center"])
	var depth: float = WALL_THICKNESS + 0.03
	var strip: float = 0.05

	var holder: Node3D = Node3D.new()
	holder.name = "Frame%d_%d" % [index, piece]
	holder.position = (
		Vector3(origin.x + center, 0.0, origin.y)
		if along_x
		else Vector3(origin.x, 0.0, origin.y + center)
	)
	if not along_x:
		holder.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	add_child(holder)

	var middle: float = sill + height * 0.5
	HouseProps.add_box(
		holder, "Left", Vector3(strip, height, depth),
		Vector3(-width * 0.5 - strip * 0.5 + CASING_LIP, middle, 0.0), _frame_material
	)
	HouseProps.add_box(
		holder, "Right", Vector3(strip, height, depth),
		Vector3(width * 0.5 + strip * 0.5 - CASING_LIP, middle, 0.0), _frame_material
	)
	HouseProps.add_box(
		holder, "Header", Vector3(width + strip * 2.0, strip, depth),
		Vector3(0.0, sill + height + strip * 0.5 - CASING_LIP, 0.0), _frame_material
	)

	if sill > 0.0:
		_add_window_parts(holder, width, height, sill, depth, strip, bool(opening.get("glass", true)))


func _add_window_parts(
	holder: Node3D,
	width: float,
	height: float,
	sill: float,
	depth: float,
	strip: float,
	glass: bool = true
) -> void:
	HouseProps.add_box(
		holder, "Sill", Vector3(width + strip * 2.0, 0.04, depth + 0.08),
		Vector3(0.0, sill + 0.019, 0.04), _frame_material
	)
	HouseProps.add_box(
		holder, "BarVertical", Vector3(0.03, height + 0.04, 0.03),
		Vector3(0.0, sill + height * 0.5, 0.0), _frame_material
	)

	if not glass:
		return

	# The glass lets light through (the pane casts no shadow) and cannot be touched.
	var pane: MeshInstance3D = HouseProps.add_box(
		holder, "Glass", Vector3(width, height, 0.006),
		Vector3(0.0, sill + height * 0.5, 0.0),
		HouseProps.glass_material(Color(0.6, 0.72, 0.8, 0.16))
	)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_roof() -> void:
	var tile: StandardMaterial3D = HouseProps.material(Color(0.2, 0.12, 0.09), 0.95)
	var pitch: float = tan(deg_to_rad(ROOF_PITCH_DEGREES))

	for i: int in BLOCKS.size():
		var rect: Rect2 = _scaled(BLOCKS[i])
		var center: Vector2 = rect.get_center()
		var span: float = rect.size.y + ROOF_OVERHANG * 2.0
		var rise: float = span * 0.5 * pitch

		var prism: PrismMesh = PrismMesh.new()
		prism.size = Vector3(span, rise, rect.size.x + ROOF_OVERHANG * 2.0)

		var roof: MeshInstance3D = MeshInstance3D.new()
		roof.name = "Roof%d" % i
		roof.mesh = prism
		roof.material_override = tile
		# The prism's triangle spans X and its length runs along Z; turn it so the
		# ridge runs east to west.
		roof.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		roof.position = Vector3(
			center.x,
			WALL_HEIGHT + CEILING_THICKNESS + rise * 0.5,
			center.y
		)
		add_child(roof)


func _add_shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)


# ============================================================
# MATERIALS
# ============================================================

func _make_materials() -> void:
	_wall_material = HouseProps.material(Color.WHITE, 1.0)
	_wall_material.albedo_texture = _make_plaster_texture()
	_triplanar(_wall_material, 0.32)

	_floor_material = HouseProps.material(Color.WHITE, 0.85)
	_floor_material.albedo_texture = _make_plank_texture()
	_triplanar(_floor_material, 0.5)

	_frame_material = HouseProps.material(Color(0.34, 0.24, 0.14), 0.9)


func _triplanar(mat: StandardMaterial3D, scale: float) -> void:
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale


## Pale lime wash gone grey: damp stains running down from the roof, dark mould
## and patches where the wash has flaked off. Light enough to be seen from far
## away on a dark night, which is the point of the exterior.
func _make_plaster_texture() -> ImageTexture:
	var size: int = 256
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5

	var blotch: FastNoiseLite = FastNoiseLite.new()
	blotch.seed = 31
	blotch.frequency = 0.018
	blotch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var streak: FastNoiseLite = FastNoiseLite.new()
	streak.seed = 77
	streak.frequency = 0.05
	streak.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	var wash: Color = Color(0.72, 0.72, 0.67)
	for y: int in size:
		for x: int in size:
			var tone: float = 1.0 + rng.randf_range(-0.05, 0.05)
			var spots: float = blotch.get_noise_2d(x, y)
			if spots > 0.38:
				tone *= 0.8 - (spots - 0.38) * 0.5
			elif spots < -0.42:
				tone *= 1.12
			# Long vertical stains, dark and faint, like rain running off the roof.
			var run: float = streak.get_noise_2d(x * 3.5, y * 0.35)
			if run > 0.3:
				tone *= 1.0 - (run - 0.3) * 0.9
			image.set_pixel(x, y, wash * tone)

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Dark pine boards running along X with end joints and a dark seam between rows.
func _make_plank_texture() -> ImageTexture:
	var size: int = 256
	var board_height: int = 32
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12

	for row: int in size / board_height:
		var joint: int = rng.randi_range(40, size - 40)
		for segment: int in 2:
			var tint: float = rng.randf_range(0.82, 1.1)
			var x_from: int = 0 if segment == 0 else joint
			var x_to: int = joint if segment == 0 else size
			for y: int in board_height:
				var grain: float = sin(y * 0.9 + row * 3.0) * 0.025
				for x: int in range(x_from, x_to):
					var noise: float = rng.randf_range(-0.02, 0.02)
					var color: Color = Color(0.36, 0.25, 0.15) * (tint + grain + noise)
					if y < 2 or x == joint or x == joint - 1:
						color = Color(0.1, 0.07, 0.04)
					image.set_pixel(x, row * board_height + y, color)

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _scaled(rect: Rect2) -> Rect2:
	return Rect2(rect.position * PLAN_SCALE, rect.size * PLAN_SCALE)
