@tool
extends Node3D
class_name SignalTowerBuilder

## Builds the ruined signal tower: a two storey 19th century railway signal cabin, the children's
## headquarters of the story. Everything is a CSG shape or a plain box, so the whole building is
## cheap to change; the numbers live in the constants below. Built at runtime, so nothing here is
## saved in the scene file.
##
## Drawn in metres, the origin at the middle of the foot of the tower, the front (and the door the
## key opens) facing +Z:
##
##   Lower level   a red brick relay room, 4 x 4 m, 2.8 m high with its deck (the upper floor), arched
##                 narrow windows, a reinforced wooden door with a brass keyhole at x = DOOR_X
##   Upper level   the control cabin, 4.4 x 4.4 m, overhanging the brick by 0.2 m all round: weathered
##                 green and yellow lap siding, wide multi pane windows on three sides (front, back and
##                 left, many panes shattered), a shingle roof with a breach and a stovepipe
##   Outside       a wooden staircase with a banister up the +X side to a small balcony and the door of
##                 the cabin, and ivy creeping up the brick
##
## The furniture (the levers, the children's corner, the lockbox and the notes) is `SignalTowerProps`,
## added as the child `Props`.

## The inventory id of the key to the front door. The key itself is `brass_signal_key.tscn`.
const KEY_ID: String = "brass_signal_key"
const DOOR_LOCKED_LINE: String = "CAPTION_TOWER_DOOR_LOCKED"

# -- Lower level --
const BASE_SIZE: float = 4.0
const BASE_WALL: float = 0.18
## The top of the lower level: the cabin's floor.
const BASE_HEIGHT: float = 2.8
const DECK_THICKNESS: float = 0.2
## The top of the floorboards inside the relay room.
const FLOOR_TOP: float = 0.04
const PLINTH_HEIGHT: float = 0.4
const PLINTH_LIP: float = 0.05

# -- Upper level --
const CABIN_SIZE: float = 4.4
const CABIN_WALL: float = 0.12
const CABIN_HEIGHT: float = 2.4
const WINDOW_SILL: float = 1.15
const WINDOW_HEIGHT: float = 1.05
const WINDOW_COLUMNS: int = 4
const WINDOW_ROWS: int = 2

# -- Roof --
const ROOF_PITCH_DEGREES: float = 24.0
const ROOF_OVERHANG: float = 0.55
const ROOF_THICKNESS: float = 0.12

# -- Doors --
const DOOR_WIDTH: float = 0.9
const DOOR_HEIGHT: float = 2.0
## Where the front door is along the front wall.
const DOOR_X: float = -0.5
## Where the cabin's door is along the +X wall, and the balcony in front of it.
const UPPER_DOOR_Z: float = -1.15

# -- Balcony and stairs (+X side) --
const BALCONY_Z_FROM: float = -2.0
const BALCONY_Z_TO: float = -0.35
const BALCONY_DEPTH: float = 1.25
const STAIR_CENTER_X: float = 2.75
## The banister runs in line with the balcony's railing.
const STAIR_RAIL_X: float = 3.29
const STAIR_WIDTH: float = 0.9
const STAIR_START_Z: float = 3.2
const STAIR_STEPS: int = 14

const VINE_COUNT: int = 24

# -- Arched windows of the relay room --
const ARCH_WIDTH: float = 0.5
const ARCH_SILL: float = 1.05
const ARCH_RECT_HEIGHT: float = 0.85

var lower_door: DoorController = null
var upper_door: DoorController = null
var props: SignalTowerProps = null
## Where every ivy leaf is (the multimesh holds them, but a headless run discards its data).
var ivy_leaf_points: PackedVector3Array = PackedVector3Array()

var _brick: StandardMaterial3D
var _stone: StandardMaterial3D
var _siding: StandardMaterial3D
var _shingle: StandardMaterial3D
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _iron: StandardMaterial3D
var _glass: StandardMaterial3D
var _door_wood: StandardMaterial3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if get_child_count() > 0:
		return

	_rng.seed = 1888
	_make_materials()
	_build_lower()
	_build_deck()
	_build_upper()
	_build_roof()
	_build_balcony_and_stairs()
	_build_doors()
	_build_ivy()
	_build_rubble()

	props = SignalTowerProps.new()
	props.name = "Props"
	add_child(props)


# ============================================================
# LOWER LEVEL: the relay room
# ============================================================

func _build_lower() -> void:
	var shell: CSGCombiner3D = _combiner("LowerShell", true)
	var wall_top: float = BASE_HEIGHT - DECK_THICKNESS
	var face: float = BASE_SIZE + PLINTH_LIP * 2.0

	_csg_box(shell, "Walls", Vector3(BASE_SIZE, wall_top, BASE_SIZE), Vector3(0.0, wall_top * 0.5, 0.0), _brick)
	_csg_box(shell, "Plinth", Vector3(face, PLINTH_HEIGHT, face), Vector3(0.0, PLINTH_HEIGHT * 0.5, 0.0), _stone)
	_csg_box(shell, "Cornice", Vector3(face, 0.1, face), Vector3(0.0, wall_top - 0.05, 0.0), _stone)

	var inner: float = BASE_SIZE - BASE_WALL * 2.0
	# (It starts under the ground, so the floorboards are the floor and no brick shows between them and the walls.)
	var hollow_height: float = wall_top + 0.05 + 0.1
	_csg_box(
		shell, "Hollow", Vector3(inner, hollow_height, inner),
		Vector3(0.0, -0.1 + hollow_height * 0.5, 0.0), _brick, CSGShape3D.OPERATION_SUBTRACTION
	)

	# The door opening in the front wall, a little wider than the door.
	_cut(
		shell, "DoorOpening", Vector3(0.0, 0.0, 1.0), DOOR_X, 0.0, DOOR_WIDTH + 0.06, DOOR_HEIGHT + 0.06,
		BASE_SIZE * 0.5 - BASE_WALL * 0.5, BASE_WALL + PLINTH_LIP * 2.0 + 0.2, _brick
	)

	# Narrow arched windows: the front (one beside the door), the left wall (two) and the back wall.
	var windows: Array[Dictionary] = [
		{"n": Vector3(0.0, 0.0, 1.0), "along": 1.15},
		{"n": Vector3(-1.0, 0.0, 0.0), "along": 0.85},
		{"n": Vector3(-1.0, 0.0, 0.0), "along": -0.85},
		# (No window in the back wall: the HQ desk, the carved board, the shelf and the relay cabinet stand along it.)
	]
	for entry: Dictionary in windows:
		_cut_arch(shell, entry["n"] as Vector3, float(entry["along"]))

	var floor_body: StaticBody3D = HouseProps.add_solid(
		self, "RelayFloorBody", Vector3(inner, FLOOR_TOP, inner), Vector3(0.0, FLOOR_TOP * 0.5, 0.0)
	)
	floor_body.add_child(_floor_mesh(Vector3(inner, FLOOR_TOP, inner), _wood_dark))

	# A worn stone sill in front of the door.
	HouseProps.add_box(
		self, "DoorStep", Vector3(DOOR_WIDTH + 0.4, 0.04, 0.5),
		Vector3(DOOR_X, 0.02, BASE_SIZE * 0.5 + PLINTH_LIP + 0.2), _stone
	)

	# The window dressing: a stone sill and a keystone at every arch, and iron bars across it.
	for entry: Dictionary in windows:
		_dress_arch(entry["n"] as Vector3, float(entry["along"]))


## One arched window cut through the wall (a rectangle and a half round on top of it).
func _cut_arch(shell: CSGCombiner3D, n: Vector3, along: float) -> void:
	var offset: float = BASE_SIZE * 0.5 - BASE_WALL * 0.5
	var thickness: float = BASE_WALL + PLINTH_LIP * 2.0 + 0.2
	_cut(shell, "ArchRect", n, along, ARCH_SILL, ARCH_WIDTH, ARCH_RECT_HEIGHT, offset, thickness, _brick)

	var tangent: Vector3 = Vector3.UP.cross(n)
	var round_top: CSGCylinder3D = CSGCylinder3D.new()
	round_top.name = "ArchTop"
	round_top.radius = ARCH_WIDTH * 0.5
	round_top.height = thickness
	round_top.sides = 16
	round_top.operation = CSGShape3D.OPERATION_SUBTRACTION
	round_top.material = _brick
	round_top.position = n * offset + tangent * along + Vector3(0.0, ARCH_SILL + ARCH_RECT_HEIGHT, 0.0)
	round_top.rotation = Vector3(PI * 0.5, 0.0, 0.0) if absf(n.z) > 0.5 else Vector3(0.0, 0.0, PI * 0.5)
	shell.add_child(round_top)


func _dress_arch(n: Vector3, along: float) -> void:
	var tangent: Vector3 = Vector3.UP.cross(n)
	var across_x: bool = absf(n.z) > 0.5
	var holder: Node3D = Node3D.new()
	holder.name = "ArchDressing"
	var wall_face: float = BASE_SIZE * 0.5
	holder.position = n * wall_face + tangent * along
	add_child(holder)

	var sill_size: Vector3 = Vector3(ARCH_WIDTH + 0.22, 0.07, 0.2) if across_x else Vector3(0.2, 0.07, ARCH_WIDTH + 0.22)
	HouseProps.add_box(holder, "Sill", sill_size, n * 0.08 + Vector3(0.0, ARCH_SILL - 0.03, 0.0), _stone)
	var key_size: Vector3 = Vector3(0.14, 0.16, 0.12) if across_x else Vector3(0.12, 0.16, 0.14)
	HouseProps.add_box(
		holder, "Keystone", key_size,
		n * 0.02 + Vector3(0.0, ARCH_SILL + ARCH_RECT_HEIGHT + ARCH_WIDTH * 0.5 + 0.06, 0.0), _stone
	)

	var bar_size: Vector3 = Vector3(0.025, ARCH_RECT_HEIGHT + 0.2, 0.025)
	for i: int in 3:
		var bar_offset: float = (float(i) - 1.0) * ARCH_WIDTH * 0.3
		HouseProps.add_box(
			holder, "Bar%d" % i, bar_size,
			-n * BASE_WALL * 0.45 + tangent * bar_offset + Vector3(0.0, ARCH_SILL + ARCH_RECT_HEIGHT * 0.5 + 0.1, 0.0), _iron
		)


# ============================================================
# THE DECK between the two levels
# ============================================================

func _build_deck() -> void:
	var deck: CSGCombiner3D = _combiner("Deck", true)
	var y: float = BASE_HEIGHT - DECK_THICKNESS * 0.5
	_csg_box(deck, "Slab", Vector3(CABIN_SIZE, DECK_THICKNESS, CABIN_SIZE), Vector3(0.0, y, 0.0), _wood)

	# The ends of the joists show under the overhang, with a brace under each of them.
	var reach: float = (CABIN_SIZE - BASE_SIZE) * 0.5
	for i: int in 5:
		var along: float = -1.6 + 0.8 * float(i)
		for sign_value: float in [-1.0, 1.0]:
			HouseProps.add_box(
				self, "Brace%d" % i, Vector3(0.1, 0.09, reach * 1.1),
				Vector3(along, BASE_HEIGHT - DECK_THICKNESS - 0.1, sign_value * (BASE_SIZE * 0.5 + reach * 0.3)),
				_wood_dark, Vector3(35.0 * sign_value, 0.0, 0.0)
			)


# ============================================================
# UPPER LEVEL: the control cabin
# ============================================================

func _build_upper() -> void:
	var shell: CSGCombiner3D = _combiner("UpperShell", true)
	var cabin_y: float = BASE_HEIGHT + CABIN_HEIGHT * 0.5
	_csg_box(shell, "Walls", Vector3(CABIN_SIZE, CABIN_HEIGHT, CABIN_SIZE), Vector3(0.0, cabin_y, 0.0), _siding)

	var inner: float = CABIN_SIZE - CABIN_WALL * 2.0
	# (The hollow starts below the deck's top, so the deck alone is the floor.)
	_csg_box(
		shell, "Hollow", Vector3(inner, CABIN_HEIGHT + 0.3, inner),
		Vector3(0.0, cabin_y - 0.05, 0.0), _siding, CSGShape3D.OPERATION_SUBTRACTION
	)

	var offset: float = CABIN_SIZE * 0.5 - CABIN_WALL * 0.5
	var thickness: float = CABIN_WALL + 0.2
	var sill: float = BASE_HEIGHT + WINDOW_SILL

	# Ribbon windows on three sides: the front, the back and the left.
	var ribbons: Dictionary = {"Front": Vector3(0.0, 0.0, 1.0), "Back": Vector3(0.0, 0.0, -1.0), "Left": Vector3(-1.0, 0.0, 0.0)}
	for side_name: String in ribbons:
		var n: Vector3 = ribbons[side_name] as Vector3
		_cut(shell, "Ribbon%s" % side_name, n, 0.0, sill, 3.2, WINDOW_HEIGHT, offset, thickness, _siding)
		_glaze(n, 0.0, sill, 3.2, WINDOW_HEIGHT)

	# On the +X side: the door out to the balcony and a small window beside it.
	_cut(
		shell, "BalconyDoorOpening", Vector3(1.0, 0.0, 0.0), -UPPER_DOOR_Z, BASE_HEIGHT,
		DOOR_WIDTH + 0.06, DOOR_HEIGHT + 0.06, offset, thickness, _siding
	)
	_cut(shell, "SideWindow", Vector3(1.0, 0.0, 0.0), -1.35, sill, 1.0, WINDOW_HEIGHT, offset, thickness, _siding)
	_glaze(Vector3(1.0, 0.0, 0.0), -1.35, sill, 1.0, WINDOW_HEIGHT)

	# The corner posts and the sill board under the windows.
	for corner_x: float in [-1.0, 1.0]:
		for corner_z: float in [-1.0, 1.0]:
			HouseProps.add_box(
				self, "CornerPost", Vector3(0.12, CABIN_HEIGHT, 0.12),
				Vector3(corner_x * (CABIN_SIZE * 0.5 - 0.02), cabin_y, corner_z * (CABIN_SIZE * 0.5 - 0.02)), _wood_dark
			)

	# The ceiling, with a hole where the roof is open to the sky.
	var ceiling: CSGCombiner3D = _combiner("Ceiling", false)
	_csg_box(
		ceiling, "Slab", Vector3(CABIN_SIZE, 0.1, CABIN_SIZE),
		Vector3(0.0, BASE_HEIGHT + CABIN_HEIGHT + 0.05, 0.0), _wood_dark
	)
	_csg_box(
		ceiling, "Breach", Vector3(0.95, 0.4, 0.95),
		Vector3(0.9, BASE_HEIGHT + CABIN_HEIGHT + 0.05, -1.47), _wood_dark, CSGShape3D.OPERATION_SUBTRACTION
	)


## A multi pane glazing in the opening of a wall: mullions, and the panes, most of them broken.
func _glaze(n: Vector3, along: float, bottom: float, width: float, height: float) -> void:
	var tangent: Vector3 = Vector3.UP.cross(n)
	var across_x: bool = absf(n.z) > 0.5
	var holder: Node3D = Node3D.new()
	holder.name = "Glazing"
	holder.position = n * (CABIN_SIZE * 0.5 - CABIN_WALL * 0.5) + tangent * along
	if not across_x:
		holder.rotation_degrees = Vector3(0.0, 90.0 * n.x, 0.0)
	add_child(holder)

	# The holder's local X runs along the wall, its local +Z points out of it.
	var columns: int = WINDOW_COLUMNS if width > 1.5 else 2
	var cell_w: float = width / float(columns)
	var cell_h: float = height / float(WINDOW_ROWS)
	for i: int in columns + 1:
		HouseProps.add_box(
			holder, "MullionV%d" % i, Vector3(0.045, height, 0.06),
			Vector3(-width * 0.5 + cell_w * float(i), bottom + height * 0.5, 0.0), _wood_dark
		)
	for j: int in WINDOW_ROWS + 1:
		HouseProps.add_box(
			holder, "MullionH%d" % j, Vector3(width, 0.045, 0.06),
			Vector3(0.0, bottom + cell_h * float(j), 0.0), _wood_dark
		)

	for i: int in columns:
		for j: int in WINDOW_ROWS:
			var pane_center: Vector3 = Vector3(
				-width * 0.5 + cell_w * (float(i) + 0.5), bottom + cell_h * (float(j) + 0.5), 0.0
			)
			var roll: float = _rng.randf()
			if roll < 0.12:
				_pane(holder, pane_center, cell_w - 0.045, cell_h - 0.045, false)
			elif roll < 0.62:
				_pane(holder, pane_center, cell_w - 0.045, cell_h - 0.045, true)
			# otherwise the pane is gone: a hole through to the dark inside


func _pane(holder: Node3D, center: Vector3, width: float, height: float, shattered: bool) -> void:
	var pane: MeshInstance3D = MeshInstance3D.new()
	pane.name = "Shards" if shattered else "Pane"
	if shattered:
		pane.mesh = _shard_mesh(width, height)
	else:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(width, height)
		pane.mesh = quad
	pane.material_override = _glass
	pane.position = center
	holder.add_child(pane)


## What is left of a broken pane: a few jagged triangles standing in the corners of the frame.
func _shard_mesh(width: float, height: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3(0.0, 0.0, 1.0))
	# Spikes standing in from the four edges of the frame, one or two to a side.
	for side: int in 4:
		for spike: int in _rng.randi_range(1, 2):
			var along: float = _rng.randf_range(-0.4, 0.4)
			var base_half: float = _rng.randf_range(0.04, 0.12)
			var depth: float = _rng.randf_range(0.12, 0.42)
			var lean: float = _rng.randf_range(-0.08, 0.08)
			var a: Vector3
			var b: Vector3
			var tip: Vector3
			if side < 2:
				var edge_y: float = height * 0.5 * (1.0 if side == 0 else -1.0)
				a = Vector3((along - base_half) * width, edge_y, 0.0)
				b = Vector3((along + base_half) * width, edge_y, 0.0)
				tip = Vector3((along + lean) * width, edge_y - signf(edge_y) * depth * height, 0.0)
			else:
				var edge_x: float = width * 0.5 * (1.0 if side == 2 else -1.0)
				a = Vector3(edge_x, (along - base_half) * height, 0.0)
				b = Vector3(edge_x, (along + base_half) * height, 0.0)
				tip = Vector3(edge_x - signf(edge_x) * depth * width, (along + lean) * height, 0.0)
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(tip)

	return surface.commit()


# ============================================================
# ROOF
# ============================================================

func _build_roof() -> void:
	var roof: CSGCombiner3D = _combiner("Roof", false)
	var theta: float = deg_to_rad(ROOF_PITCH_DEGREES)
	var half_span: float = CABIN_SIZE * 0.5 + ROOF_OVERHANG
	var slope: float = half_span / cos(theta)
	var eave_y: float = BASE_HEIGHT + CABIN_HEIGHT - 0.05
	var rise: float = half_span * tan(theta)
	var length: float = CABIN_SIZE + ROOF_OVERHANG * 2.0
	var up: Vector3 = Vector3(0.0, cos(theta), 0.0) * ROOF_THICKNESS * 0.5

	var front_basis: Basis = Basis(Vector3.RIGHT, theta)
	var back_basis: Basis = Basis(Vector3.RIGHT, -theta)
	var front_center: Vector3 = Vector3(0.0, eave_y + rise * 0.5, half_span * 0.5) + up
	var back_center: Vector3 = Vector3(0.0, eave_y + rise * 0.5, -half_span * 0.5) + up

	for entry: Array in [[front_basis, front_center, "Front"], [back_basis, back_center, "Back"]]:
		var slab: CSGBox3D = _csg_box(
			roof, "Slab%s" % entry[2], Vector3(length, ROOF_THICKNESS, slope + 0.1), entry[1] as Vector3, _shingle
		)
		slab.basis = entry[0] as Basis

	# The breach in the back slope: rotten boards, no tiles, daylight.
	var breach_center: Vector3 = back_center + back_basis * Vector3(0.9, 0.0, -0.1)
	var breach: CSGBox3D = _csg_box(
		roof, "Breach", Vector3(1.05, ROOF_THICKNESS * 3.0, 0.95), breach_center, _shingle, CSGShape3D.OPERATION_SUBTRACTION
	)
	breach.basis = back_basis
	# A smaller bite out of the front slope, near the eave.
	var bite_center: Vector3 = front_center + front_basis * Vector3(-1.5, 0.0, 0.85)
	var bite: CSGBox3D = _csg_box(
		roof, "Bite", Vector3(0.55, ROOF_THICKNESS * 3.0, 0.4), bite_center, _shingle, CSGShape3D.OPERATION_SUBTRACTION
	)
	bite.basis = front_basis

	# The ridge cap, with a stretch of it gone.
	var ridge_y: float = eave_y + rise + 0.06
	for entry: Array in [[-1.3, 2.6], [1.8, 1.0]]:
		var ridge: CSGBox3D = _csg_box(
			roof, "RidgeCap", Vector3(float(entry[1]), 0.2, 0.2), Vector3(float(entry[0]), ridge_y, 0.0), _shingle
		)
		ridge.rotation_degrees = Vector3(45.0, 0.0, 0.0)

	# The gable ends: lap siding between the cabin walls and the roof.
	var gable_height: float = CABIN_SIZE * 0.5 * tan(theta) + 0.1
	for sign_value: float in [-1.0, 1.0]:
		var gable: CSGPolygon3D = CSGPolygon3D.new()
		gable.name = "Gable"
		gable.polygon = PackedVector2Array([
			Vector2(-CABIN_SIZE * 0.5, 0.0), Vector2(CABIN_SIZE * 0.5, 0.0), Vector2(0.0, gable_height),
		])
		gable.depth = 0.1
		gable.material = _siding
		gable.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		# CSGPolygon3D extrudes towards -Z, which the quarter turn makes -X: from the position, 0.1 m inwards on the
		# +X side; on the -X side it has to start 0.1 m in from the wall to end flush with its outside.
		var gable_x: float = CABIN_SIZE * 0.5 if sign_value > 0.0 else -(CABIN_SIZE * 0.5 - 0.1)
		gable.position = Vector3(gable_x, BASE_HEIGHT + CABIN_HEIGHT, 0.0)
		roof.add_child(gable)

	# Frieze boards close the slit between the wall tops and the roof along the long sides.
	for sign_value: float in [-1.0, 1.0]:
		HouseProps.add_box(
			self, "Frieze", Vector3(CABIN_SIZE + 0.02, 0.24, 0.08),
			Vector3(0.0, BASE_HEIGHT + CABIN_HEIGHT + 0.1, sign_value * (CABIN_SIZE * 0.5 - 0.04)), _siding
		)

	# The stovepipe: through the back slope above the stove, leaning a little, with a rusted band and a hat.
	var pipe_x: float = -1.4
	var pipe_z: float = -0.9
	var pipe: CSGCylinder3D = CSGCylinder3D.new()
	pipe.name = "Stovepipe"
	pipe.radius = 0.075
	pipe.height = 1.9
	pipe.sides = 10
	pipe.material = _iron
	pipe.position = Vector3(pipe_x, BASE_HEIGHT + CABIN_HEIGHT + 0.85, pipe_z)
	pipe.rotation_degrees = Vector3(0.0, 0.0, 3.0)
	add_child(pipe)
	var band: MeshInstance3D = HouseProps.add_cylinder(
		self, "PipeBand", 0.088, 0.07, Vector3(pipe_x + 0.02, BASE_HEIGHT + CABIN_HEIGHT + 1.35, pipe_z),
		JunctionProps.weathered(Color(0.45, 0.2, 0.1), 3.0, 0.9, 0.4)
	)
	band.rotation_degrees = Vector3(0.0, 0.0, 3.0)
	var hat: CSGCylinder3D = CSGCylinder3D.new()
	hat.name = "PipeHat"
	hat.radius = 0.16
	hat.height = 0.1
	hat.cone = true
	hat.sides = 10
	hat.material = _iron
	hat.position = Vector3(pipe_x + 0.1, BASE_HEIGHT + CABIN_HEIGHT + 1.85, pipe_z)
	add_child(hat)
	HouseProps.add_box(
		self, "PipeFlashing", Vector3(0.5, 0.03, 0.5),
		Vector3(pipe_x, ridge_y - 0.1 - absf(pipe_z) * tan(theta) + 0.07, pipe_z), _iron, Vector3(-ROOF_PITCH_DEGREES, 0.0, 0.0)
	)

	# Loose tiles: a few lifted on the roof and a few that have slid off.
	for i: int in 7:
		var on_front: bool = _rng.randf() < 0.5
		var slope_basis: Basis = front_basis if on_front else back_basis
		var slab_center: Vector3 = front_center if on_front else back_center
		var tile_position: Vector3 = slab_center + slope_basis * Vector3(
			_rng.randf_range(-2.3, 2.3), ROOF_THICKNESS * 0.5 + 0.012, _rng.randf_range(-slope * 0.45, slope * 0.45)
		)
		var tile: MeshInstance3D = HouseProps.add_box(
			self, "LooseTile%d" % i, Vector3(0.22, 0.015, 0.3), tile_position, _shingle
		)
		tile.basis = slope_basis * Basis(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * Basis(Vector3.RIGHT, _rng.randf_range(0.0, 0.35))


# ============================================================
# BALCONY AND STAIRS
# ============================================================

func _build_balcony_and_stairs() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Balcony"
	add_child(holder)

	var x_from: float = CABIN_SIZE * 0.5 - 0.1
	var depth: float = BALCONY_DEPTH
	var length: float = BALCONY_Z_TO - BALCONY_Z_FROM
	var center_x: float = x_from + depth * 0.5
	var center_z: float = (BALCONY_Z_FROM + BALCONY_Z_TO) * 0.5
	var deck_y: float = BASE_HEIGHT - 0.06

	var platform: StaticBody3D = HouseProps.add_solid(
		holder, "BalconyBody", Vector3(depth, 0.12, length), Vector3(center_x, deck_y, center_z)
	)
	platform.add_child(_floor_mesh(Vector3(depth, 0.12, length), _wood))
	# Two beams hold it up from the wall.
	for beam_z: float in [BALCONY_Z_FROM + 0.25, BALCONY_Z_TO - 0.25]:
		HouseProps.add_box(
			holder, "Beam", Vector3(depth, 0.14, 0.1), Vector3(center_x, deck_y - 0.13, beam_z), _wood_dark
		)
		# A diagonal strut from the brick wall up to the outer end of the beam.
		HouseProps.add_box(
			holder, "Strut", Vector3(1.25, 0.08, 0.08), Vector3(2.6, BASE_HEIGHT - 0.45, beam_z), _wood_dark,
			Vector3(0.0, 0.0, 23.5)
		)
	for post_z: float in [BALCONY_Z_FROM + 0.25, BALCONY_Z_TO - 0.25]:
		HouseProps.add_cylinder(
			holder, "Leg", 0.05, BASE_HEIGHT - 0.12, Vector3(x_from + depth - 0.08, (BASE_HEIGHT - 0.12) * 0.5, post_z), _wood_dark
		)

	# The railing: the outer side and the back end; the front end is where the stairs arrive.
	var rail_x: float = x_from + depth - 0.06
	var rail_height: float = 0.95
	for post_z: float in [BALCONY_Z_FROM + 0.06, (BALCONY_Z_FROM + BALCONY_Z_TO) * 0.5, BALCONY_Z_TO - 0.06]:
		HouseProps.add_box(
			holder, "RailPost", Vector3(0.08, rail_height, 0.08), Vector3(rail_x, BASE_HEIGHT + rail_height * 0.5, post_z), _wood_dark
		)
	HouseProps.add_box(
		holder, "RailTop", Vector3(0.08, 0.06, length), Vector3(rail_x, BASE_HEIGHT + rail_height, center_z), _wood_dark
	)
	HouseProps.add_box(
		holder, "RailMid", Vector3(0.05, 0.05, length), Vector3(rail_x, BASE_HEIGHT + rail_height * 0.5, center_z), _wood_dark
	)
	# The railing along the back end of the balcony.
	HouseProps.add_box(
		holder, "BackRailTop", Vector3(depth, 0.06, 0.08),
		Vector3(center_x, BASE_HEIGHT + rail_height, BALCONY_Z_FROM + 0.06), _wood_dark
	)
	HouseProps.add_box(
		holder, "BackRailMid", Vector3(depth, 0.05, 0.05),
		Vector3(center_x, BASE_HEIGHT + rail_height * 0.5, BALCONY_Z_FROM + 0.06), _wood_dark
	)
	HouseProps.add_solid(
		holder, "RailBlock", Vector3(0.1, rail_height, length), Vector3(rail_x, BASE_HEIGHT + rail_height * 0.5, center_z)
	)
	HouseProps.add_solid(
		holder, "BackRailBlock", Vector3(depth, rail_height, 0.1), Vector3(center_x, BASE_HEIGHT + rail_height * 0.5, BALCONY_Z_FROM + 0.06)
	)

	_build_stairs(holder)


func _build_stairs(holder: Node3D) -> void:
	var stairs: Node3D = Node3D.new()
	stairs.name = "Stairs"
	holder.add_child(stairs)

	var rise: float = BASE_HEIGHT / float(STAIR_STEPS)
	var run_total: float = STAIR_START_Z - BALCONY_Z_TO
	var tread: float = run_total / float(STAIR_STEPS)
	var angle: float = atan2(BASE_HEIGHT, run_total)
	var slope: float = BASE_HEIGHT / run_total
	var mid_z: float = (STAIR_START_Z + BALCONY_Z_TO) * 0.5

	for i: int in STAIR_STEPS:
		var z_front: float = STAIR_START_Z - tread * float(i)
		var top: float = rise * float(i + 1)
		HouseProps.add_box(
			stairs, "Tread%d" % i, Vector3(STAIR_WIDTH, 0.045, tread + 0.04),
			Vector3(STAIR_CENTER_X, top - 0.0225, z_front - tread * 0.5), _wood
		)
		HouseProps.add_box(
			stairs, "Riser%d" % i, Vector3(STAIR_WIDTH, rise, 0.03),
			Vector3(STAIR_CENTER_X, top - rise * 0.5, z_front - 0.015), _wood_dark
		)

	# The two stringers under the treads. (Turned about X by +angle, the long axis runs down towards +Z.)
	var stringer_length: float = sqrt(run_total * run_total + BASE_HEIGHT * BASE_HEIGHT)
	var tilt: Basis = Basis(Vector3.RIGHT, angle)
	var middle: Vector3 = Vector3(STAIR_CENTER_X, BASE_HEIGHT * 0.5 - 0.02, mid_z)
	for side: float in [-1.0, 1.0]:
		var stringer: MeshInstance3D = HouseProps.add_box(
			stairs, "Stringer", Vector3(0.06, 0.24, stringer_length),
			middle + Vector3(side * (STAIR_WIDTH * 0.5 - 0.02), 0.0, 0.0), _wood_dark
		)
		stringer.basis = tilt

	# What the player walks on: one smooth ramp from the foot of the stairs to the balcony, as the other
	# stairs of the game do. Its top surface runs through the back edge of every tread.
	var ramp: StaticBody3D = StaticBody3D.new()
	ramp.name = "RampBody"
	var ramp_shape: CollisionShape3D = CollisionShape3D.new()
	var ramp_box: BoxShape3D = BoxShape3D.new()
	ramp_box.size = Vector3(STAIR_WIDTH, 0.1, stringer_length)
	ramp_shape.shape = ramp_box
	ramp.add_child(ramp_shape)
	stairs.add_child(ramp)
	ramp.basis = tilt
	ramp.position = Vector3(STAIR_CENTER_X, BASE_HEIGHT * 0.5, mid_z) - tilt.y * 0.05
	# Stairs for the player's walk (`PlayerMovementController`): a slow, heavy step to every two treads, and the old boards groan.
	ramp.add_to_group(&"stairs")
	ramp.set_meta(&"stair_creaks", true)

	# The banister on the outer side: posts and a rail that follow the stairs, and a block so nobody walks off.
	var post_count: int = 5
	for i: int in post_count:
		var q: float = float(i) / float(post_count - 1)
		var post_z: float = lerpf(STAIR_START_Z - 0.1, BALCONY_Z_TO + 0.1, q)
		var surface: float = slope * (STAIR_START_Z - post_z) + 0.1
		HouseProps.add_box(
			stairs, "BanisterPost%d" % i, Vector3(0.07, 1.05, 0.07), Vector3(STAIR_RAIL_X, surface + 0.425, post_z), _wood_dark
		)

	var rail_mid: float = slope * (STAIR_START_Z - mid_z) + 0.1
	var rail: MeshInstance3D = HouseProps.add_box(
		stairs, "Banister", Vector3(0.07, 0.06, stringer_length), Vector3(STAIR_RAIL_X, rail_mid + 0.95, mid_z), _wood_dark
	)
	rail.basis = tilt
	var rail_low: MeshInstance3D = HouseProps.add_box(
		stairs, "BanisterLow", Vector3(0.05, 0.05, stringer_length), Vector3(STAIR_RAIL_X, rail_mid + 0.5, mid_z), _wood_dark
	)
	rail_low.basis = tilt
	var guard: StaticBody3D = StaticBody3D.new()
	guard.name = "BanisterBody"
	var guard_shape: CollisionShape3D = CollisionShape3D.new()
	var guard_box: BoxShape3D = BoxShape3D.new()
	guard_box.size = Vector3(0.1, 1.2, stringer_length)
	guard_shape.shape = guard_box
	guard.add_child(guard_shape)
	stairs.add_child(guard)
	guard.basis = tilt
	guard.position = Vector3(STAIR_RAIL_X, rail_mid + 0.5, mid_z)

	# One tread has half rotted away, and sits crooked.
	var rotten: MeshInstance3D = stairs.get_node_or_null("Tread%d" % (STAIR_STEPS - 5)) as MeshInstance3D
	if rotten != null:
		rotten.scale = Vector3(0.6, 1.0, 1.0)
		rotten.position.x += STAIR_WIDTH * 0.2
		rotten.rotation_degrees = Vector3(0.0, 3.0, 0.0)


# ============================================================
# DOORS
# ============================================================

## (The doors are handled as plain nodes and their properties set by name: in the editor the scripts of an instanced
## scene are placeholders, so a cast to DoorController gives nothing there; in the game the casts below are real.)
func _build_doors() -> void:
	var front_z: float = BASE_SIZE * 0.5 - BASE_WALL * 0.5
	var front: Node3D = _make_door(
		"FrontDoor", Vector3(DOOR_X - DOOR_WIDTH * 0.5, FLOOR_TOP + 0.005, front_z), 0.0, true, KEY_ID, &"signal_tower_front_door"
	)
	front.set("locked_line", DOOR_LOCKED_LINE)
	lower_door = front as DoorController

	# The note pinned to the door moves with it.
	var note: Node3D = (load("res://scenes/objects/signal_tower/tower_door_note.tscn") as PackedScene).instantiate() as Node3D
	note.name = "DoorNote"
	note.position = Vector3(-0.12, 0.42, 0.057)
	note.rotation_degrees = Vector3(0.0, 0.0, 2.0)
	(front.get_node("Hinge/DoorRoot") as Node3D).add_child(note)

	var side_x: float = CABIN_SIZE * 0.5 - CABIN_WALL * 0.5
	upper_door = _make_door(
		"BalconyDoor", Vector3(side_x, BASE_HEIGHT + 0.01, UPPER_DOOR_Z + DOOR_WIDTH * 0.5), 90.0, false, "", &"signal_tower_balcony_door"
	) as DoorController


func _make_door(
	door_name: String,
	hinge_position: Vector3,
	yaw_degrees: float,
	locked: bool,
	key_id: String,
	persistent: StringName
) -> Node3D:
	var door: Node3D = (load("res://scenes/objects/door_interactable.tscn") as PackedScene).instantiate() as Node3D
	door.name = door_name
	door.set("starts_locked", locked)
	door.set("required_key_id", key_id)
	door.set("persistent_id", persistent)
	door.position = hinge_position
	door.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	door.set("door_sounds_enabled", false)

	var door_root: Node3D = door.get_node("Hinge/DoorRoot") as Node3D
	var mesh: MeshInstance3D = door_root.get_node("DoorMesh") as MeshInstance3D
	mesh.material_override = _door_wood
	# The handle and the keyhole the door fits are brass (it takes the material of the knob it replaces).
	var brass: StandardMaterial3D = HouseProps.material(HouseProps.BRASS, 0.4, 0.85)
	for knob_name: String in ["FrontKnobInteractable", "BackKnobInteractable"]:
		var knob_mesh: MeshInstance3D = door_root.get_node("%s/KnobMesh" % knob_name) as MeshInstance3D
		knob_mesh.set_surface_override_material(0, brass)
	add_child(door)

	# Iron straps across both faces, studded, and hinge plates: a door built to keep children out.
	for side: float in [-1.0, 1.0]:
		for strap_y: float in [-0.62, 0.62]:
			HouseProps.add_box(
				door_root, "Strap", Vector3(DOOR_WIDTH - 0.04, 0.12, 0.012),
				Vector3(0.0, strap_y, side * 0.045), _iron
			)
		for stud_x: float in [-0.3, -0.1, 0.1, 0.3]:
			for strap_y: float in [-0.62, 0.62]:
				HouseProps.add_box(
					door_root, "Stud", Vector3(0.025, 0.025, 0.012),
					Vector3(stud_x, strap_y, side * 0.054), _iron
				)
	# A heavy frame in the opening.
	var frame_holder: Node3D = Node3D.new()
	frame_holder.name = "%sFrame" % door_name
	frame_holder.position = hinge_position + Vector3(DOOR_WIDTH * 0.5, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(yaw_degrees))
	frame_holder.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	add_child(frame_holder)
	var frame_depth: float = BASE_WALL * 0.9 if yaw_degrees == 0.0 else CABIN_WALL * 1.6
	HouseProps.add_box(
		frame_holder, "Lintel", Vector3(DOOR_WIDTH + 0.2, 0.12, frame_depth),
		Vector3(0.0, DOOR_HEIGHT + 0.09, 0.0), _wood_dark
	)
	for side: float in [-1.0, 1.0]:
		HouseProps.add_box(
			frame_holder, "Jamb", Vector3(0.08, DOOR_HEIGHT + 0.06, frame_depth),
			Vector3(side * (DOOR_WIDTH * 0.5 + 0.045), (DOOR_HEIGHT + 0.06) * 0.5, 0.0), _wood_dark
		)
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
	var wall_face: float = BASE_SIZE * 0.5

	for i: int in VINE_COUNT:
		var n: Vector3 = faces[i % 3 if i < VINE_COUNT - 3 else 3]
		var tangent: Vector3 = Vector3.UP.cross(n)
		var along: float = _rng.randf_range(-1.85, 1.85)
		# Not across the door, and the stairs hide the +X side.
		if n.z > 0.5 and absf(along - DOOR_X) < 0.75:
			along += 1.6
		if n.x > 0.5:
			along = _rng.randf_range(-1.8, 0.0)

		var height: float = _rng.randf_range(0.9, 2.55)
		var y: float = 0.0
		var drift: float = _rng.randf_range(-0.04, 0.04)
		var point: Vector3 = _wall_point(n, tangent, along, y, wall_face)
		while y < height:
			y += 0.14
			along += drift + _rng.randf_range(-0.045, 0.045)
			along = clampf(along, -1.9, 1.9)
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


## A point on the wall surface (the plinth sticks out a little further than the bricks above it).
func _wall_point(n: Vector3, tangent: Vector3, along: float, y: float, wall_face: float) -> Vector3:
	var out: float = wall_face + (PLINTH_LIP + 0.015 if y < PLINTH_HEIGHT else 0.018)
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
		var spot: Vector3 = Vector3(_rng.randf_range(-3.2, -2.2), 0.04, _rng.randf_range(-1.8, 2.0))
		if i % 3 == 0:
			spot = Vector3(_rng.randf_range(-1.5, 1.2), 0.04, _rng.randf_range(-3.1, -2.2))

		var brick: MeshInstance3D = HouseProps.add_box(
			rubble, "Brick%d" % i, Vector3(0.215, 0.065, 0.1), spot, _brick
		)
		brick.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.2, 0.2))

	for i: int in 9:
		var tile: MeshInstance3D = HouseProps.add_box(
			rubble, "Tile%d" % i, Vector3(0.22, 0.015, 0.3),
			Vector3(_rng.randf_range(-3.6, -1.6), 0.02, _rng.randf_range(-3.4, -1.0)), _shingle
		)
		tile.rotation = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.15, 0.15))



# ============================================================
# BUILDING BLOCKS
# ============================================================

func _combiner(combiner_name: String, collide: bool) -> CSGCombiner3D:
	var combiner: CSGCombiner3D = CSGCombiner3D.new()
	combiner.name = combiner_name
	combiner.use_collision = collide
	add_child(combiner)
	return combiner


func _csg_box(
	parent: Node,
	box_name: String,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	operation: CSGShape3D.Operation = CSGShape3D.OPERATION_UNION
) -> CSGBox3D:
	var box: CSGBox3D = CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos
	box.material = mat
	box.operation = operation
	parent.add_child(box)
	return box


## An opening cut through the wall whose outer face looks along `n`: `along` is the distance of its
## middle along the wall (to the right when looking at it from outside), `bottom` its lowest edge.
func _cut(
	shell: CSGCombiner3D,
	cut_name: String,
	n: Vector3,
	along: float,
	bottom: float,
	width: float,
	height: float,
	offset: float,
	thickness: float,
	mat: Material
) -> void:
	var tangent: Vector3 = Vector3.UP.cross(n)
	var size: Vector3 = Vector3(width, height, thickness) if absf(n.z) > 0.5 else Vector3(thickness, height, width)
	var pos: Vector3 = n * offset + tangent * along + Vector3(0.0, bottom + height * 0.5, 0.0)
	_csg_box(shell, cut_name, size, pos, mat, CSGShape3D.OPERATION_SUBTRACTION)


func _floor_mesh(size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	instance.material_override = mat
	return instance


# ============================================================
# MATERIALS
# ============================================================

func _make_materials() -> void:
	_brick = HouseProps.material(Color.WHITE, 0.95)
	_brick.albedo_texture = _make_brick_texture()
	_triplanar(_brick, 1.0 / 0.9)

	_stone = JunctionProps.weathered(Color(0.46, 0.45, 0.42), 1.6, 0.95)

	_siding = HouseProps.material(Color.WHITE, 0.9)
	_siding.albedo_texture = _make_siding_texture()
	_triplanar(_siding, 1.0)

	_shingle = HouseProps.material(Color.WHITE, 0.92)
	_shingle.albedo_texture = _make_shingle_texture()
	_shingle.uv1_triplanar = true
	_shingle.uv1_scale = Vector3.ONE * 0.9

	_wood = HouseProps.material(Color.WHITE, 0.9)
	_wood.albedo_texture = _make_plank_texture(Color(0.42, 0.36, 0.28))
	_triplanar(_wood, 0.8)

	_wood_dark = HouseProps.material(Color.WHITE, 0.92)
	_wood_dark.albedo_texture = _make_plank_texture(Color(0.25, 0.2, 0.15))
	_triplanar(_wood_dark, 0.8)

	_door_wood = HouseProps.material(Color.WHITE, 0.9)
	_door_wood.albedo_texture = _make_plank_texture(Color(0.3, 0.2, 0.12))
	_door_wood.uv1_scale = Vector3(1.0, 1.0, 1.0)

	_iron = JunctionProps.weathered(Color(0.16, 0.16, 0.17), 3.0, 0.6, 0.7)

	_glass = HouseProps.glass_material(Color(0.55, 0.65, 0.62, 0.18))


func _triplanar(mat: StandardMaterial3D, uv_scale: float) -> void:
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * uv_scale


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


## Lap siding, 8 boards to the tile: the paint is green, gone yellow in places and peeled to grey wood
## in others, a dark shadow line under every board.
func _make_siding_texture() -> ImageTexture:
	var size: int = 256
	var boards: int = 8
	var board_h: int = int(size / float(boards))
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73

	var peel: FastNoiseLite = FastNoiseLite.new()
	peel.seed = 5
	peel.frequency = 0.03
	peel.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	for board: int in boards:
		var paint: Color = Color(0.31, 0.4, 0.28) if rng.randf() < 0.6 else Color(0.6, 0.55, 0.3)
		var joint: int = rng.randi_range(20, size - 20)
		for y: int in board_h:
			var py: int = board * board_h + y
			for x: int in size:
				var color: Color = paint * (1.0 + sin(float(y) * 0.5 + float(x) * 0.02) * 0.04 + rng.randf_range(-0.04, 0.04))
				if peel.get_noise_2d(float(x), float(py) * 2.5) > 0.2:
					color = Color(0.46, 0.42, 0.36) * (1.0 + rng.randf_range(-0.07, 0.07))
				if y >= board_h - 3:
					color *= 0.45
				elif y == 0:
					color *= 1.12
				if x == joint:
					color *= 0.4
				image.set_pixel(x, py, color)

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


## Grey weathered boards in 8 rows to the tile.
func _make_plank_texture(base: Color) -> ImageTexture:
	var size: int = 256
	var boards: int = 8
	var board_h: int = int(size / float(boards))
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12

	for board: int in boards:
		var tint: float = rng.randf_range(0.8, 1.12)
		var joint: int = rng.randi_range(30, size - 30)
		for y: int in board_h:
			var grain: float = sin(float(y) * 0.9 + float(board) * 3.0) * 0.03
			for x: int in size:
				var color: Color = base * (tint + grain + rng.randf_range(-0.03, 0.03) + sin(float(x) * 0.07 + float(board)) * 0.03)
				if y < 2 or x == joint or x == joint - 1:
					color = base * 0.3
				image.set_pixel(x, board * board_h + y, color)

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
