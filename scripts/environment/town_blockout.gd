@tool
class_name TownBlockout
extends Node3D

## A compact blockout of the 1990s railway mountain town (Paranapiacaba-like, rural Sao
## Paulo), to judge scale and routes before real art. The player walks slowly (1.3 m/s), so
## every point of interest is a short walk from the next and the whole map is one winding
## route, not a grid:
##
## - The ground is a real heightfield (a hillside in the north, the railway cutting, the
##   lower town and the forest to the south) with the lanes carved into it.
## - The lanes are narrow cobbled lanes that bend and climb, with weeds along the edges,
##   uneven stone sidewalks, stone stairs and one switchback road, lined with tightly
##   packed, irregular houses (different heights, sloping eaves, shutters, balconies,
##   chimneys, dishes), garden walls, wooden poles with lamps, wire clusters and signs.
## - Nothing outside the lanes, plazas and yards is walkable: houses and walls close the
##   sides, and an invisible wall follows the border of the playable area wherever nothing
##   else does (see `is_playable` and `show_boundary_debug`).
##
## Colour code: RED key buildings, BEIGE (or green timber) ordinary houses, GREEN forest,
## yellow Orelhao. North is -Z, east +X.

# Ground levels.
const LEVEL_UPPER: float = 7.0
const LEVEL_TERRACE: float = 11.2
const LEVEL_RAIL: float = 0.2
const LEVEL_LOW: float = -3.0

const SIDEWALK_RISE: float = 0.17
const STORY_HEIGHT: float = 3.0
const RAIL_OFFSET: float = 10.5

const ROAD: Color = Color(0.36, 0.38, 0.35)
const SIDEWALK: Color = Color(0.5, 0.48, 0.44)
const BALLAST: Color = Color(0.3, 0.28, 0.26)
const IRON: Color = Color(0.17, 0.18, 0.2)
const BRIDGE_IRON: Color = Color(0.24, 0.27, 0.32)
const RAIL: Color = Color(0.36, 0.33, 0.3)
const KEY_RED: Color = Color(0.62, 0.14, 0.12)
const BRICK_RED: Color = Color(0.5, 0.16, 0.12)
const ROOF: Color = Color(0.4, 0.2, 0.14)
const ROOF_DARK: Color = Color(0.25, 0.17, 0.14)
const WOOD: Color = Color(0.36, 0.25, 0.16)
const TIMBER: Color = Color(0.58, 0.42, 0.24)
const STONE_WALL: Color = Color(0.4, 0.39, 0.36)
const GRAVE: Color = Color(0.46, 0.46, 0.44)
const FOREST: Color = Color(0.11, 0.3, 0.12)
const TRUNK: Color = Color(0.2, 0.14, 0.09)
const GRAVEL: Color = Color(0.44, 0.4, 0.32)
const YELLOW: Color = Color(0.96, 0.76, 0.1)
const RUST_CAR: Color = Color(0.42, 0.21, 0.15)
const GRASS: Color = Color(0.2, 0.3, 0.14)
const BEIGES: Array[Color] = [
	Color(0.78, 0.7, 0.55),
	Color(0.73, 0.66, 0.52),
	Color(0.8, 0.74, 0.6),
	Color(0.69, 0.63, 0.49),
]
## Wooden houses (the green boards of the hill towns): the other ordinary house colour.
const TIMBERS: Array[Color] = [
	Color(0.24, 0.38, 0.27),
	Color(0.2, 0.32, 0.26),
	Color(0.3, 0.42, 0.4),
	Color(0.5, 0.4, 0.26),
]
const ROOFS: Array[Color] = [
	Color(0.38, 0.22, 0.17),
	Color(0.27, 0.24, 0.23),
	Color(0.3, 0.31, 0.34),
	Color(0.46, 0.45, 0.42),
]
const SHUTTERS: Array[Color] = [
	Color(0.12, 0.3, 0.18),
	Color(0.35, 0.2, 0.12),
	Color(0.15, 0.25, 0.4),
	Color(0.55, 0.15, 0.1),
	Color(0.85, 0.82, 0.74),
]

const FOG_COLOR: Color = Color(0.16, 0.2, 0.24)

# The terrain heightfield (a vertex every metre) and the border raster (a cell every 40 cm).
const TERRAIN_X0: float = -70.0
const TERRAIN_X1: float = 70.0
const TERRAIN_Z0: float = -84.0
const TERRAIN_Z1: float = 92.0
const RASTER_CELL: float = 0.4
const RASTER_X0: float = -64.0
const RASTER_Z0: float = -80.0
const RASTER_X1: float = 64.0
const RASTER_Z1: float = 86.0
const HASH_CELL: float = 4.0

const TRACK_CONTROLS: Array[Vector2] = [
	Vector2(-54.0, -2.0), Vector2(-38.0, -5.0), Vector2(-22.0, -7.0), Vector2(-6.0, -5.5),
	Vector2(10.0, -2.5), Vector2(26.0, -1.0), Vector2(40.0, 0.0), Vector2(54.0, 2.0),
]

@export var seed_value: int = 1990
@export_category("Environment")
## Builds the WorldEnvironment and the moonlight (turn off to use the level's own).
@export var build_environment: bool = true
## Fog is OFF by default (`fog_enabled`). When on, it is clear up to `fog_start_meters` and
## thickens to a wall at `fog_end_meters`, so the player sees about 15 m.
@export var fog_enabled: bool = false
@export var fog_start_meters: float = 12.0
@export var fog_end_meters: float = 36.0
@export var build_street_lamps: bool = true
@export_category("Debug")
## Draws the invisible wall that closes the playable area, as a translucent red surface.
@export var show_boundary_debug: bool = false
@export_category("Vista")
## Builds only what can be SEEN from far away (the dream intro's city overlook): no collision,
## no border wall, no ground mesh (a Terrain3D under it provides the ground), no lights (lit
## windows and emissive lamps instead), CSG shapes as plain meshes. See TownVistaBuilder.
@export var vista_mode: bool = false
## The overlook the town is seen from (world x, z), and the world area the Terrain3D under it
## covers (trees are only planted inside it, mountains fall away towards the overlook).
@export var vista_overlook_world: Vector2 = Vector2(168.0, 27.0)
@export var vista_limits_world: Rect2 = Rect2(-60.0, -1020.0, 1080.0, 1200.0)
## The trees the town would build as shapes (yards, pastures, cemetery, trail), kept as spots
## (position, height, slim) in vista mode for the builder to plant as real tree instances.
var vista_tree_spots: Array[Dictionary] = []
@export_category("Scenery")
## Builds the rest of the town round the playable core (the centre, the station, the river,
## the periphery, the farms and forest): scenery only, no collision. Turn it off to build
## faster while working on the playable streets.
@export var build_scenery: bool = true

var markers: Dictionary = {}
## Where the key buildings stand: name -> {base, theta, size, door} (door = the sidewalk
## point in front of the door).
var landmarks: Dictionary = {}
## The playable area (x, z), found from the lanes, plazas and yards.
var playable_bounds: Rect2 = Rect2()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _lamp_points: Array[Vector3] = []
var _house_count: int = 0
var _tree_count: int = 0
var _lanes: Array[TownLane] = []
var _lane_by_id: Dictionary = {}
var _hash: Dictionary = {}
var _areas: Array[Dictionary] = []
var _solids: Array[Dictionary] = []
var _zones: Dictionary = {}
var _subs: Dictionary = {}
var _side_groups: Dictionary = {}
var _marker_points: Dictionary = {}

var _heights: PackedFloat32Array = PackedFloat32Array()
var _terrain_w: int = 0
var _terrain_h: int = 0

var _raster_w: int = 0
var _raster_h: int = 0
var _allowed: PackedByteArray = PackedByteArray()
var _solid: PackedByteArray = PackedByteArray()

var _wires: TownMeshBuilder = TownMeshBuilder.new()
var _walk_noise: FastNoiseLite = FastNoiseLite.new()
var _pole_count: int = 0
var _scenery: TownScenery = null


func _ready() -> void:
	if get_child_count() > 0:
		return

	build()


## Where the marker `marker_name` stands (world position), or the origin.
func get_marker_position(marker_name: String) -> Vector3:
	var marker: Marker3D = markers.get(marker_name) as Marker3D
	return marker.global_position if marker != null else Vector3.ZERO


## The centre line of a lane (a point every metre), for routes and tests.
func get_lane_points(lane_id: String) -> PackedVector3Array:
	var lane: TownLane = _lane_by_id.get(lane_id) as TownLane
	return lane.points if lane != null else PackedVector3Array()


func get_lane_ids() -> Array:
	return _lane_by_id.keys()


## True where the player may stand: inside a lane, plaza or yard, and not inside a house
## or a wall. Everything else is closed by buildings, walls or the invisible boundary.
func is_playable(point: Vector3) -> bool:
	var cell: int = _raster_cell(point.x, point.z)
	return cell >= 0 and _allowed[cell] == 1 and _solid[cell] == 0


## The ground height of the terrain heightfield at (x, z).
func ground_height(x: float, z: float) -> float:
	return _ground_height(x, z)


func build() -> void:
	_rng.seed = seed_value
	_walk_noise.seed = seed_value
	_walk_noise.frequency = 0.22
	var map_root: Node3D = Node3D.new()
	map_root.name = "MapRoot"
	add_child(map_root)

	for zone: String in ["UpperTown", "CentralRailway", "LowerTown"]:
		_zones[zone] = _group(map_root, zone)

	var marker_root: Node3D = _group(map_root, "Markers")

	_define_lanes()
	_define_areas()
	_scenery = TownScenery.new(self)
	_scenery.shape()
	_index_lanes()
	_build_terrain(map_root)
	_build_lane_surfaces()
	_build_railway()
	_place_points_of_interest()
	_fill_houses()
	_build_frontage()
	_build_points_of_interest_props()
	_build_poles()
	_build_markers(marker_root)
	_build_boundary(map_root)
	if vista_mode:
		_light_the_vista()

	if build_scenery:
		_scenery.build(map_root)

	if not vista_mode:
		_build_hill_trees(map_root)

	_finish_wires(map_root)

	if build_environment and not vista_mode:
		_build_environment(_group(map_root, "Environment"))

	if build_street_lamps and not vista_mode:
		_build_street_lamps(_group(map_root, "StreetLamps"))


# ============================================================
# LANES AND AREAS
# ============================================================

func _track_z(x: float) -> float:
	for i: int in TRACK_CONTROLS.size() - 1:
		var a: Vector2 = TRACK_CONTROLS[i]
		var b: Vector2 = TRACK_CONTROLS[i + 1]
		if x <= b.x:
			return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))

	return TRACK_CONTROLS[TRACK_CONTROLS.size() - 1].y


func _add_lane(lane_id: String, zone: String, kind: TownLane.Kind, controls: Array[Vector3], half_width: float, walk_left: float, walk_right: float) -> TownLane:
	var lane: TownLane = TownLane.create(lane_id, zone, kind, controls, half_width, walk_left, walk_right)
	lane.index = _lanes.size()
	lane.bias = 0.0025 * float(lane.index)
	_lanes.append(lane)
	_lane_by_id[lane_id] = lane
	return lane


## The centre-line point of `lane` closest to the plan point (x, z).
func _lane_point_near(lane: TownLane, x: float, z: float) -> Vector3:
	return lane.point_at(lane.closest_s(Vector2(x, z)))


func _define_lanes() -> void:
	# The railway first: the two streets of the cutting run beside it on either side.
	var track_controls: Array[Vector3] = []
	for x: float in [-49.0, -38.0, -22.0, -6.0, 10.0, 26.0, 40.0, 49.0]:
		track_controls.append(Vector3(x, LEVEL_RAIL, _track_z(x)))

	var track: TownLane = _add_lane("Track", "CentralRailway", TownLane.Kind.TRACK, track_controls, 1.95, 0.0, 0.0)
	track.houses = false

	# The yard: the flat ground between the two streets, the track in its middle.
	var yard_controls: Array[Vector3] = []
	for x: float in [-50.0, -36.0, -22.0, -6.0, 10.0, 26.0, 40.0, 50.0]:
		yard_controls.append(Vector3(x, LEVEL_RAIL, _track_z(x)))

	var yard: TownLane = _add_lane("RailYard", "CentralRailway", TownLane.Kind.GROUND, yard_controls, 9.0, 0.0, 0.0)
	yard.houses = false
	yard.wall_style = 1
	yard.carve_blend = 4.0
	yard.capped_start = true
	yard.capped_end = true

	# Rua da Estacao, on the north bank, and Rua da Linha, on the south bank.
	var station_controls: Array[Vector3] = []
	for x: float in [-46.0, -36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 33.0, 41.0]:
		station_controls.append(Vector3(x, LEVEL_RAIL, _track_z(x) - RAIL_OFFSET + 0.8 * sin(x * 0.13)))

	var station: TownLane = _add_lane("RuaDaEstacao", "CentralRailway", TownLane.Kind.COBBLE, station_controls, 1.6, 0.9, 0.9)
	station.capped_start = true
	station.capped_end = true

	var line_controls: Array[Vector3] = []
	for x: float in [-46.0, -34.0, -22.0, -10.0, 2.0, 14.0, 26.0, 38.0, 47.0]:
		line_controls.append(Vector3(x, LEVEL_RAIL, _track_z(x) + RAIL_OFFSET + 0.8 * sin(x * 0.11 + 1.0)))

	var line: TownLane = _add_lane("RuaDaLinha", "CentralRailway", TownLane.Kind.COBBLE, line_controls, 1.6, 0.9, 0.9)
	line.capped_start = true
	line.capped_end = true

	# Rua Alta, the upper street: it runs along the hill and ends in the switchback road
	# (the Ladeira) that comes down to Rua da Estacao.
	var ladeira_end: Vector3 = _lane_point_near(station, 33.0, -9.0)
	var upper_controls: Array[Vector3] = [
		Vector3(-40.0, 7.0, -30.5), Vector3(-31.0, 7.15, -34.0), Vector3(-21.0, 7.1, -33.2),
		Vector3(-11.0, 6.95, -30.6), Vector3(-1.0, 7.05, -32.4), Vector3(9.0, 7.3, -31.0),
		Vector3(21.0, 7.35, -33.0), Vector3(31.0, 7.2, -31.2),
		Vector3(36.0, 7.0, -30.4), Vector3(43.5, 6.6, -30.4), Vector3(47.2, 6.2, -28.9),
		Vector3(48.7, 5.7, -25.2), Vector3(47.2, 5.2, -21.5), Vector3(43.5, 4.8, -20.0),
		Vector3(38.0, 3.6, -19.0), Vector3(34.0, 2.0, -16.0), Vector3(32.5, 0.9, -13.0), ladeira_end,
	]
	var upper: TownLane = _add_lane("RuaAlta", "UpperTown", TownLane.Kind.COBBLE, upper_controls, 1.7, 0.9, 0.9)
	upper.capped_start = true

	# The lane up to the dead end behind Juliana's house.
	var upper_west: Vector3 = _lane_point_near(upper, -31.0, -34.0)
	var west_lane: TownLane = _add_lane("BecoOeste", "UpperTown", TownLane.Kind.COBBLE, [
		upper_west, Vector3(-33.0, 7.4, -40.0), Vector3(-29.0, 7.9, -46.0), Vector3(-33.0, 8.4, -51.5),
	], 1.2, 0.6, 0.6)
	west_lane.capped_end = true

	# The lane up to the church.
	var church_start: Vector3 = _lane_point_near(upper, -1.0, -32.4)
	_add_lane("TravessaDaIgreja", "UpperTown", TownLane.Kind.COBBLE, [
		church_start, Vector3(3.5, 8.0, -38.0), Vector3(2.8, 9.4, -43.5), Vector3(5.5, 11.15, -49.0),
	], 1.5, 0.8, 0.8)

	# The stone staircase straight down the hill, from Rua Alta to Rua da Estacao.
	var stair_top: Vector3 = _lane_edge_point(upper, -25.0, 1, 0.15)
	var stair_bottom: Vector3 = _lane_edge_point(station, -22.5, -1, 0.15)
	stair_top.y = _lane_point_near(upper, stair_top.x, stair_top.z).y + SIDEWALK_RISE
	stair_bottom.y = LEVEL_RAIL + SIDEWALK_RISE
	var stairs: TownLane = _add_lane("StoneStaircase", "UpperTown", TownLane.Kind.STAIRS, [stair_top, stair_bottom], 1.5, 0.0, 0.0)
	stairs.houses = false
	stairs.wall_style = 6
	stairs.carve_blend = 2.5

	# The lower town: the main street winds south from Rua da Linha to the forest.
	var main_start: Vector3 = _lane_point_near(line, 8.0, 7.5)
	var main_street: TownLane = _add_lane("RuaPrincipal", "LowerTown", TownLane.Kind.COBBLE, [
		main_start, Vector3(7.5, 0.0, 15.0), Vector3(2.5, -0.6, 22.0), Vector3(-1.5, -1.2, 29.0),
		Vector3(1.0, -1.8, 35.0), Vector3(6.0, -2.3, 41.0), Vector3(4.0, -2.7, 47.0),
		Vector3(-1.0, -3.1, 53.0), Vector3(-3.0, -3.3, 59.0),
	], 1.7, 0.9, 0.9)
	main_street.carve_blend = 3.5

	var main_point: Vector3 = _lane_point_near(main_street, -1.5, 28.5)
	_add_lane("RuaOeste", "LowerTown", TownLane.Kind.COBBLE, [
		_lane_point_near(line, -30.0, 6.0), Vector3(-34.0, -0.3, 15.0), Vector3(-30.0, -0.9, 22.0),
		Vector3(-22.0, -1.3, 27.5), Vector3(-12.0, -1.3, 29.5), main_point,
	], 1.4, 0.7, 0.7)

	var east_start: Vector3 = _lane_point_near(main_street, 5.5, 44.0)
	var east_lane: TownLane = _add_lane("BecoLeste", "LowerTown", TownLane.Kind.COBBLE, [
		east_start, Vector3(14.0, -2.9, 46.5), Vector3(22.0, -3.3, 50.5), Vector3(29.0, -3.6, 55.5),
	], 1.3, 0.7, 0.7)
	east_lane.capped_end = true

	# The drive into Sophia's yard and the way into the maintenance yard: short spurs.
	var drive_start: Vector3 = _lane_point_near(main_street, -1.0, 51.0)
	var drive: TownLane = _add_lane("SophiasDrive", "LowerTown", TownLane.Kind.COBBLE, [
		drive_start, Vector3(-8.0, LEVEL_LOW, 50.5), Vector3(-17.0, LEVEL_LOW, 49.5),
	], 1.4, 0.0, 0.0)
	drive.houses = false
	drive.wall_style = 3

	var shed_start: Vector3 = _lane_point_near(line, 33.0, 9.0)
	var shed_drive: TownLane = _add_lane("ShedDrive", "CentralRailway", TownLane.Kind.COBBLE, [
		shed_start, Vector3(33.2, 0.1, 14.0), Vector3(33.5, -0.2, 20.0),
	], 1.5, 0.0, 0.0)
	shed_drive.houses = false
	shed_drive.wall_style = 3

	# The path into the forest.
	var trail: TownLane = _add_lane("ForestTrail", "LowerTown", TownLane.Kind.GROUND, [
		_lane_point_near(main_street, -3.0, 59.0), Vector3(-4.0, -3.4, 65.0), Vector3(-2.0, -3.1, 72.0),
	], 1.3, 0.0, 0.0)
	trail.houses = false
	trail.wall_style = 2
	trail.carve_blend = 2.0
	trail.capped_end = true


## The point of `lane` beside it, at plan position x (about) and on the side `side`
## (+1 right, -1 left): `inset` metres inside the sidewalk's outer edge.
func _lane_edge_point(lane: TownLane, x: float, side: int, inset: float) -> Vector3:
	var best: int = 0
	var best_distance: float = INF
	for i: int in lane.points.size():
		var d: float = absf(lane.points[i].x - x)
		if d < best_distance:
			best_distance = d
			best = i

	var offset: float = lane.edge_offset(side) - inset
	var point: Vector2 = lane.xz(best) + lane.right_normal(best) * float(side) * offset
	return Vector3(point.x, lane.points[best].y, point.y)


func _define_areas() -> void:
	_add_area("ChurchPlaza", Rect2(-1.0, -58.5, 30.0, 11.0), LEVEL_TERRACE, Color(0.46, 0.44, 0.4))
	_add_area("Cemetery", Rect2(29.0, -68.0, 18.0, 20.0), LEVEL_TERRACE, Color(0.24, 0.32, 0.17))
	_add_area("SophiasYard", Rect2(-42.0, 41.0, 28.0, 16.0), LEVEL_LOW, Color(0.24, 0.33, 0.16))
	_add_area("MaintenanceYard", Rect2(25.0, 17.0, 24.0, 14.0), -0.2, Color(0.38, 0.34, 0.28))


func _add_area(area_id: String, rect: Rect2, level: float, color: Color) -> void:
	_areas.append({"id": area_id, "rect": rect, "y": level, "color": color})


func _area(area_id: String) -> Dictionary:
	for area: Dictionary in _areas:
		if area["id"] == area_id:
			return area

	return {}


## Every lane segment is listed in all the 4 m cells within 5 m of its corridor, so one
## cell lookup finds every lane that could be closer than ~1.5 m to a point of the cell.
func _index_lanes() -> void:
	for lane: TownLane in _lanes:
		if lane.kind == TownLane.Kind.TRACK:
			continue

		var reach: float = lane.corridor_half() + 5.0
		var cells: int = int(ceil(reach / HASH_CELL))
		for j: int in lane.points.size() - 1:
			var centre: Vector2 = lane.xz(j)
			var home: Vector2i = Vector2i(int(floor(centre.x / HASH_CELL)), int(floor(centre.y / HASH_CELL)))
			for dx: int in range(-cells, cells + 1):
				for dz: int in range(-cells, cells + 1):
					var cell: Vector2i = home + Vector2i(dx, dz)
					var middle: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * HASH_CELL
					if middle.distance_to(centre) > reach + HASH_CELL * 0.71:
						continue

					if not _hash.has(cell):
						_hash[cell] = []

					(_hash[cell] as Array).append((lane.index << 12) | j)


## The smallest (distance to a lane's centre line - that lane's corridor half width) over
## the lanes near the plan point `p`, ignoring `ignore`. Negative inside a lane's corridor;
## INF when no lane is near.
func _clearance_at(p: Vector2, ignore: TownLane = null) -> float:
	var cell: Vector2i = Vector2i(int(floor(p.x / HASH_CELL)), int(floor(p.y / HASH_CELL)))
	if not _hash.has(cell):
		return INF

	var best: float = INF
	for entry: int in _hash[cell] as Array:
		var lane: TownLane = _lanes[entry >> 12]
		if lane == ignore:
			continue

		var hit: Vector4 = lane.segment_hit(entry & 4095, p)
		best = minf(best, hit.x - lane.corridor_half())

	return best


## Distance from the plan point `p` to the centre line of `lane`, looking only at the
## samples around index `near`.
func _distance_to_lane(lane: TownLane, p: Vector2, near: int) -> float:
	var best: float = INF
	for j: int in range(maxi(near - 12, 0), mini(near + 12, lane.points.size() - 2) + 1):
		best = minf(best, lane.segment_hit(j, p).x)

	return best


# ============================================================
# TERRAIN
# ============================================================

## The natural hillside, before the lanes are cut into it: the ground the scenery shaped for
## the whole valley, plus some small bumps that fade out at the core's edges (so the core's
## terrain meets the outer one without a seam).
func _base_height(x: float, z: float, noise: FastNoiseLite) -> float:
	var inside: float = minf(minf(x - TERRAIN_X0, TERRAIN_X1 - x), minf(z - TERRAIN_Z0, TERRAIN_Z1 - z))
	var bumps: float = noise.get_noise_2d(x, z) * 1.3 + noise.get_noise_2d(x * 3.1, z * 3.1) * 0.25
	return _scenery.natural_height(x, z) + bumps * smoothstep(0.0, 10.0, inside)


func _terrain_material() -> StandardMaterial3D:
	if not _materials.has("terrain"):
		var material: StandardMaterial3D = JunctionProps.weathered(Color.WHITE, 0.8, 1.0)
		material.vertex_color_use_as_albedo = true
		_materials["terrain"] = material

	return _materials["terrain"]


func _terrain_index(gx: int, gz: int) -> int:
	return gz * _terrain_w + gx


func _ground_height(x: float, z: float) -> float:
	var fx: float = clampf((x - TERRAIN_X0), 0.0, TERRAIN_X1 - TERRAIN_X0 - 0.001)
	var fz: float = clampf((z - TERRAIN_Z0), 0.0, TERRAIN_Z1 - TERRAIN_Z0 - 0.001)
	var gx: int = int(fx)
	var gz: int = int(fz)
	var tx: float = fx - float(gx)
	var tz: float = fz - float(gz)
	var h00: float = _heights[_terrain_index(gx, gz)]
	var h10: float = _heights[_terrain_index(gx + 1, gz)]
	var h01: float = _heights[_terrain_index(gx, gz + 1)]
	var h11: float = _heights[_terrain_index(gx + 1, gz + 1)]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _build_terrain(parent: Node3D) -> void:
	_terrain_w = int((TERRAIN_X1 - TERRAIN_X0)) + 1
	_terrain_h = int((TERRAIN_Z1 - TERRAIN_Z0)) + 1
	var count: int = _terrain_w * _terrain_h
	_heights.resize(count)
	var carve_weight: PackedFloat32Array = PackedFloat32Array()
	var carve_height: PackedFloat32Array = PackedFloat32Array()
	var carve_distance: PackedFloat32Array = PackedFloat32Array()
	var plain_weight: PackedFloat32Array = PackedFloat32Array()
	var plain_lane: PackedInt32Array = PackedInt32Array()
	var area_weight: PackedFloat32Array = PackedFloat32Array()
	var area_index: PackedInt32Array = PackedInt32Array()
	carve_weight.resize(count)
	carve_height.resize(count)
	carve_distance.resize(count)
	carve_distance.fill(INF)
	plain_weight.resize(count)
	plain_lane.resize(count)
	area_weight.resize(count)
	area_index.resize(count)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.035
	for gz: int in _terrain_h:
		for gx: int in _terrain_w:
			_heights[_terrain_index(gx, gz)] = _base_height(TERRAIN_X0 + gx, TERRAIN_Z0 + gz, noise)

	# Cut the lanes into the hill: flat under the lane and its sidewalks, then blending
	# back into the hillside.
	for lane: TownLane in _lanes:
		if lane.kind == TownLane.Kind.TRACK:
			continue

		var flat: float = lane.corridor_half() + 0.9
		var reach: float = flat + lane.carve_blend
		var is_plain: bool = lane.kind == TownLane.Kind.GROUND
		for j: int in lane.points.size() - 1:
			var a: Vector3 = lane.points[j]
			var b: Vector3 = lane.points[j + 1]
			var along_x: float = b.x - a.x
			var along_z: float = b.z - a.z
			var length_squared: float = maxf(along_x * along_x + along_z * along_z, 0.000001)
			var gx0: int = maxi(int(floor(minf(a.x, b.x) - reach - TERRAIN_X0)), 0)
			var gx1: int = mini(int(ceil(maxf(a.x, b.x) + reach - TERRAIN_X0)), _terrain_w - 1)
			var gz0: int = maxi(int(floor(minf(a.z, b.z) - reach - TERRAIN_Z0)), 0)
			var gz1: int = mini(int(ceil(maxf(a.z, b.z) + reach - TERRAIN_Z0)), _terrain_h - 1)
			for gz: int in range(gz0, gz1 + 1):
				var pz: float = TERRAIN_Z0 + float(gz)
				for gx: int in range(gx0, gx1 + 1):
					var px: float = TERRAIN_X0 + float(gx)
					var raw: float = ((px - a.x) * along_x + (pz - a.z) * along_z) / length_squared
					var t: float = clampf(raw, 0.0, 1.0)
					var dx: float = px - (a.x + along_x * t)
					var dz: float = pz - (a.z + along_z * t)
					var distance_squared: float = dx * dx + dz * dz
					if distance_squared >= reach * reach:
						continue

					var distance: float = sqrt(distance_squared)
					var weight: float = 1.0 - smoothstep(flat, reach, distance)
					# A dead end stops at its wall: the cut does not round off past it.
					var beyond: float = 0.0
					if j == 0 and lane.capped_start and raw < 0.0:
						beyond = -raw * sqrt(length_squared)
					elif j == lane.points.size() - 2 and lane.capped_end and raw > 1.0:
						beyond = (raw - 1.0) * sqrt(length_squared)

					weight *= 1.0 - smoothstep(0.5, 3.0, beyond)
					var k: int = _terrain_index(gx, gz)
					# The stronger lane wins; inside the flat zone of two, the nearer one.
					var stronger: bool = weight > carve_weight[k] + 0.0001
					var nearer: bool = weight > 0.999 and carve_weight[k] > 0.999 and distance < carve_distance[k]
					if stronger or nearer:
						carve_weight[k] = weight
						carve_height[k] = lerpf(a.y, b.y, t)
						carve_distance[k] = distance

					if is_plain and weight > plain_weight[k]:
						plain_weight[k] = weight
						plain_lane[k] = lane.index

	for k: int in count:
		if carve_weight[k] > 0.0:
			_heights[k] = lerpf(_heights[k], carve_height[k], carve_weight[k])

	# Level plazas and yards.
	for a: int in _areas.size():
		var rect: Rect2 = _areas[a]["rect"]
		var level: float = _areas[a]["y"]
		for gz: int in _terrain_h:
			for gx: int in _terrain_w:
				var x: float = TERRAIN_X0 + gx
				var z: float = TERRAIN_Z0 + gz
				var dx: float = maxf(maxf(rect.position.x - x, x - rect.end.x), 0.0)
				var dz: float = maxf(maxf(rect.position.y - z, z - rect.end.y), 0.0)
				var distance: float = sqrt(dx * dx + dz * dz)
				if distance >= 3.0:
					continue

				var weight: float = 1.0 - smoothstep(0.4, 3.0, distance)
				var k: int = _terrain_index(gx, gz)
				_heights[k] = lerpf(_heights[k], level, weight)
				if weight > area_weight[k]:
					area_weight[k] = weight
					area_index[k] = a

	# The mesh: smooth normals, vertex colours (grass, bare rock on the steep parts,
	# gravel in the yards, the area colours).
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	vertices.resize(count)
	normals.resize(count)
	colors.resize(count)
	uvs.resize(count)
	var color_noise: FastNoiseLite = FastNoiseLite.new()
	color_noise.seed = seed_value + 7
	color_noise.frequency = 0.09
	for gz: int in _terrain_h:
		for gx: int in _terrain_w:
			var k: int = _terrain_index(gx, gz)
			var x: float = TERRAIN_X0 + gx
			var z: float = TERRAIN_Z0 + gz
			vertices[k] = Vector3(x, _heights[k], z)
			uvs[k] = Vector2(x, z) * 0.25
			var left: float = _heights[_terrain_index(maxi(gx - 1, 0), gz)]
			var right: float = _heights[_terrain_index(mini(gx + 1, _terrain_w - 1), gz)]
			var back: float = _heights[_terrain_index(gx, maxi(gz - 1, 0))]
			var front: float = _heights[_terrain_index(gx, mini(gz + 1, _terrain_h - 1))]
			var normal: Vector3 = Vector3(left - right, 2.0, back - front).normalized()
			normals[k] = normal

			var shade: float = color_noise.get_noise_2d(x, z) * 0.5 + 0.5
			var color: Color = _scenery.ground_color(x, z, normal.y, shade)
			if plain_weight[k] > 0.0:
				var ground: Color = Color(0.3, 0.28, 0.25) if _lanes[plain_lane[k]].id == "RailYard" else Color(0.3, 0.22, 0.14)
				color = color.lerp(ground * (0.85 + shade * 0.3), smoothstep(0.0, 1.0, plain_weight[k]))

			if area_weight[k] > 0.0:
				var area_color: Color = _areas[area_index[k]]["color"]
				color = color.lerp(area_color * (0.85 + shade * 0.3), smoothstep(0.0, 0.7, area_weight[k]))

			colors[k] = color

	var indices: PackedInt32Array = PackedInt32Array()
	for gz: int in _terrain_h - 1:
		for gx: int in _terrain_w - 1:
			var a: int = _terrain_index(gx, gz)
			var b: int = a + 1
			var c: int = a + _terrain_w
			var d: int = c + 1
			indices.append_array(PackedInt32Array([a, b, d, a, d, c]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if vista_mode:
		return

	var terrain: Node3D = _group(parent, "Terrain")
	_solid_mesh(terrain, "Ground", mesh, _terrain_material())


# ============================================================
# LANE SURFACES
# ============================================================

func _cobble_material() -> StandardMaterial3D:
	if not _materials.has("cobble"):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_texture = TownMeshBuilder.stone_texture(seed_value, 256, 26, 18, 40, Color(0.42, 0.43, 0.4), Color(0.13, 0.14, 0.12), 0.3)
		material.uv1_scale = Vector3(0.5, 0.5, 1.0)
		material.roughness = 0.92
		_materials["cobble"] = material

	return _materials["cobble"]


func _slab_material() -> StandardMaterial3D:
	if not _materials.has("slab"):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_texture = TownMeshBuilder.stone_texture(seed_value + 3, 256, 90, 70, 150, Color(0.62, 0.6, 0.55), Color(0.2, 0.2, 0.18), 0.12)
		material.uv1_scale = Vector3(0.33, 0.33, 1.0)
		material.roughness = 0.9
		_materials["slab"] = material

	return _materials["slab"]


func _weed_material() -> StandardMaterial3D:
	if not _materials.has("weed"):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color.WHITE
		material.roughness = 1.0
		_materials["weed"] = material

	return _materials["weed"]


func _build_lane_surfaces() -> void:
	for lane: TownLane in _lanes:
		var streets: Node3D = _sub(lane.zone, "Streets")
		match lane.kind:
			TownLane.Kind.COBBLE:
				_build_cobble_lane(lane, streets)
			TownLane.Kind.STAIRS:
				_build_stair_lane(lane, streets)


func _build_cobble_lane(lane: TownLane, parent: Node3D) -> void:
	var group: Node3D = _group(parent, lane.id)
	var road_path: PackedVector3Array = _lane_path(lane, 0.04 + lane.bias)
	var crown: PackedVector2Array = PackedVector2Array([
		Vector2(-lane.half_width, 0.0), Vector2(0.0, 0.015), Vector2(lane.half_width, 0.0),
	])
	var road: TownMeshBuilder = TownMeshBuilder.new()
	road.extrude(road_path, crown, false)
	road.smooth_normals()
	_solid_mesh(group, "Road", road.build(), _cobble_material())

	# Uneven stone sidewalks: raised, bevelled at the kerb, their height drifting.
	for side: int in [-1, 1]:
		var width: float = lane.walk_right if side > 0 else lane.walk_left
		if width <= 0.0:
			continue

		var walk: TownMeshBuilder = TownMeshBuilder.new()
		var rows: Array[PackedVector3Array] = []
		for i: int in lane.points.size():
			var normal: Vector2 = lane.right_normal(i) * float(side)
			var top: float = SIDEWALK_RISE + 0.035 * clampf(_walk_noise.get_noise_1d(lane.distances[i] + float(lane.index) * 37.0 + float(side) * 11.0) * 2.5, -1.0, 1.0)
			var y: float = lane.points[i].y + lane.bias
			var bevel: float = minf(0.28, width * 0.35)
			var offsets: Array[float] = [lane.half_width, lane.half_width + bevel, lane.half_width + width - bevel, lane.half_width + width]
			var lifts: Array[float] = [0.04, top, top, 0.04]
			var row: PackedVector3Array = PackedVector3Array()
			for r: int in offsets.size():
				row.append(Vector3(lane.points[i].x + normal.x * offsets[r], y + lifts[r], lane.points[i].z + normal.y * offsets[r]))

			rows.append(row)

		var bevel_u: float = minf(0.28, width * 0.35)
		var distance_u: Array[float] = [0.0, bevel_u, width - bevel_u, width]
		for i: int in rows.size() - 1:
			for r: int in 3:
				walk.add_quad(
					rows[i][r], rows[i][r + 1], rows[i + 1][r + 1], rows[i + 1][r], Vector3.UP,
					Vector2(distance_u[r], lane.distances[i]), Vector2(distance_u[r + 1], lane.distances[i]),
					Vector2(distance_u[r + 1], lane.distances[i + 1]), Vector2(distance_u[r], lane.distances[i + 1])
				)

		walk.smooth_normals()
		_solid_mesh(group, "Walk%s" % ("Right" if side > 0 else "Left"), walk.build(), _slab_material())

	_build_weeds(lane, group)


## Tufts of weeds along the edges of the cobbles: patches that swell and fade out.
func _build_weeds(lane: TownLane, parent: Node3D) -> void:
	var weeds: TownMeshBuilder = TownMeshBuilder.new()
	for side: int in [-1, 1]:
		var i: int = _rng.randi_range(0, 4)
		while i < lane.points.size() - 2:
			var run: int = _rng.randi_range(2, 6)
			var reach: float = _rng.randf_range(0.15, 0.4)
			var green: Color = Color(0.07, 0.15, 0.05).lerp(Color(0.22, 0.28, 0.1), _rng.randf())
			for k: int in run:
				var j: int = i + k
				if j >= lane.points.size() - 1:
					break

				var w0: float = reach * sin(PI * float(k) / float(run))
				var w1: float = reach * sin(PI * float(k + 1) / float(run))
				var edge: float = lane.half_width
				var n0: Vector2 = lane.right_normal(j) * float(side)
				var n1: Vector2 = lane.right_normal(j + 1) * float(side)
				var y0: float = lane.points[j].y + 0.058 + lane.bias
				var y1: float = lane.points[j + 1].y + 0.058 + lane.bias
				var a: Vector3 = Vector3(lane.points[j].x + n0.x * (edge + 0.05), y0, lane.points[j].z + n0.y * (edge + 0.05))
				var b: Vector3 = Vector3(lane.points[j].x + n0.x * (edge - w0), y0, lane.points[j].z + n0.y * (edge - w0))
				var c: Vector3 = Vector3(lane.points[j + 1].x + n1.x * (edge - w1), y1, lane.points[j + 1].z + n1.y * (edge - w1))
				var d: Vector3 = Vector3(lane.points[j + 1].x + n1.x * (edge + 0.05), y1, lane.points[j + 1].z + n1.y * (edge + 0.05))
				weeds.add_quad(a, b, c, d, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, green)

			i += run + _rng.randi_range(1, 7)

	if not weeds.is_empty():
		var instance: MeshInstance3D = _solid_mesh(parent, "Weeds", weeds.build(), _weed_material(), false)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _lane_path(lane: TownLane, lift: float) -> PackedVector3Array:
	var path: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in lane.points:
		path.append(point + Vector3(0.0, lift, 0.0))

	return path


## Stone steps down (or up) a straight stair lane. The steps are only to look at: the
## player's controller cannot step up, so the collision is one smooth slope through them
## (the way games do it), and the sides are closed by the walls of the frontage.
func _build_stair_lane(lane: TownLane, parent: Node3D) -> void:
	var group: Node3D = _group(parent, lane.id)
	var start: Vector3 = lane.points[0]
	var end: Vector3 = lane.points[lane.points.size() - 1]
	_build_steps(group, start, end, lane.half_width, 0.18)


## Steps from `start` to `end` (both at the stair's centre line): treads, risers and the
## smooth slope collider, offset up by half a rise so the feet ride between tread heights.
func _build_steps(parent: Node3D, start: Vector3, end: Vector3, half_width: float, rise_target: float) -> void:
	var run_vector: Vector2 = Vector2(end.x - start.x, end.z - start.z)
	var run_length: float = run_vector.length()
	var direction: Vector2 = run_vector / run_length
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var steps: int = maxi(int(ceil(absf(end.y - start.y) / rise_target)), 1)
	var rise: float = (end.y - start.y) / float(steps)
	var run: float = run_length / float(steps)
	var descending: bool = end.y < start.y

	var builder: TownMeshBuilder = TownMeshBuilder.new()
	for i: int in steps:
		var d0: float = run * float(i)
		var d1: float = d0 + run
		# Going up the first tread is one rise above the start; going down it is level
		# with it.
		var tread_y: float = start.y + rise * float(i) if descending else start.y + rise * float(i + 1)
		var p0: Vector2 = Vector2(start.x, start.z) + direction * d0
		var p1: Vector2 = Vector2(start.x, start.z) + direction * d1
		var a: Vector3 = Vector3(p0.x - side.x * half_width, tread_y, p0.y - side.y * half_width)
		var b: Vector3 = Vector3(p0.x + side.x * half_width, tread_y, p0.y + side.y * half_width)
		var c: Vector3 = Vector3(p1.x + side.x * half_width, tread_y, p1.y + side.y * half_width)
		var d: Vector3 = Vector3(p1.x - side.x * half_width, tread_y, p1.y - side.y * half_width)
		builder.add_quad(a, b, c, d, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color(0.62, 0.6, 0.56))

		# The riser: at the start of the tread going up (it faces back), at its end going
		# down (it faces forward).
		var low_y: float = start.y + rise * float(i + 1) if descending else start.y + rise * float(i)
		var at: Vector2 = p1 if descending else p0
		var left: Vector3 = Vector3(at.x - side.x * half_width, 0.0, at.y - side.y * half_width)
		var right: Vector3 = Vector3(at.x + side.x * half_width, 0.0, at.y + side.y * half_width)
		var facing: Vector3 = Vector3(direction.x, 0.0, direction.y) * (1.0 if descending else -1.0)
		builder.add_quad(
			Vector3(left.x, low_y, left.z), Vector3(right.x, low_y, right.z),
			Vector3(right.x, tread_y, right.z), Vector3(left.x, tread_y, left.z), facing,
			Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color(0.3, 0.29, 0.27)
		)

	_solid_mesh(parent, "Steps", builder.build(), _vertex_material(), false)
	if vista_mode:
		return

	var slope: Vector3 = Vector3(run_vector.x, end.y - start.y, run_vector.y)
	var slope_basis: Basis = Basis.looking_at(slope.normalized(), Vector3.UP)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "SlopeCollision"
	body.transform = Transform3D(slope_basis, start + slope * 0.5 - slope_basis.y * 0.15 + Vector3(0.0, absf(rise) * 0.5, 0.0))
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(half_width * 2.0, 0.3, slope.length() + 0.2)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


# ============================================================
# RAILWAY
# ============================================================

func _build_railway() -> void:
	var track: TownLane = _lane_by_id["Track"]
	var zone: Node3D = _sub("CentralRailway", "Track")

	# Ballast with bevelled edges (walkable), two rails, and the sleepers.
	var ballast: TownMeshBuilder = TownMeshBuilder.new()
	ballast.extrude(_lane_path(track, 0.0), PackedVector2Array([
		Vector2(-1.95, 0.0), Vector2(-1.3, 0.1), Vector2(1.3, 0.1), Vector2(1.95, 0.0),
	]), false)
	ballast.smooth_normals()
	_solid_mesh(zone, "MainLineBallast", ballast.build(), _mat(BALLAST))

	var rails: TownMeshBuilder = TownMeshBuilder.new()
	for rail_side: float in [-0.7175, 0.7175]:
		rails.extrude(_lane_path(track, 0.1), PackedVector2Array([
			Vector2(rail_side - 0.04, 0.0), Vector2(rail_side + 0.04, 0.0),
			Vector2(rail_side + 0.04, 0.13), Vector2(rail_side - 0.04, 0.13),
		]), true)

	_solid_mesh(zone, "MainLineRails", rails.build(), _mat(RAIL), false)

	var sleeper_mesh: BoxMesh = BoxMesh.new()
	sleeper_mesh.size = Vector3(0.25, 0.1, 2.6)
	var sleepers: MultiMesh = MultiMesh.new()
	sleepers.transform_format = MultiMesh.TRANSFORM_3D
	sleepers.mesh = sleeper_mesh
	var count: int = int(track.length() / 0.8)
	sleepers.instance_count = count
	for i: int in count:
		var s: float = 0.4 + 0.8 * float(i)
		var index: int = track.sample_index(s)
		var tangent: Vector2 = track.tangents[index]
		var sleeper_basis: Basis = Basis(Vector3.UP, atan2(-tangent.y, tangent.x))
		sleepers.set_instance_transform(i, Transform3D(sleeper_basis, track.point_at(s) + Vector3(0.0, 0.1, 0.0)))

	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "MainLineSleepers"
	instance.multimesh = sleepers
	instance.material_override = _mat(Color(0.2, 0.15, 0.1))
	zone.add_child(instance)

	# Where the line comes out of the hill (west) and where it ends (east).
	var stone: Material = _stone(STONE_WALL)
	var west: Vector3 = track.points[0]
	var west_tangent: Vector2 = track.tangents[0]
	var west_yaw: float = atan2(-west_tangent.y, west_tangent.x)
	var portal: Node3D = Node3D.new()
	portal.name = "TunnelPortal"
	portal.position = west
	portal.rotation.y = west_yaw
	zone.add_child(portal)
	# Local +X points east into the line; the portal faces east.
	_box(portal, "PortalPierSouth", Vector3(-0.4, 2.2, 3.1), Vector3(1.6, 4.4, 1.6), stone)
	_box(portal, "PortalPierNorth", Vector3(-0.4, 2.2, -3.1), Vector3(1.6, 4.4, 1.6), stone)
	_box(portal, "PortalLintel", Vector3(-0.4, 5.0, 0.0), Vector3(1.6, 1.4, 8.0), stone)
	_box(portal, "PortalDark", Vector3(-1.4, 2.6, 0.0), Vector3(2.0, 5.2, 6.0), _mat(Color(0.02, 0.02, 0.02)))

	var east: Vector3 = track.points[track.points.size() - 1]
	var east_tangent: Vector2 = track.tangents[track.points.size() - 1]
	var east_yaw: float = atan2(-east_tangent.y, east_tangent.x)
	var buffer: Node3D = Node3D.new()
	buffer.name = "BufferStop"
	buffer.position = east
	buffer.rotation.y = east_yaw
	zone.add_child(buffer)
	_box(buffer, "BufferBeam", Vector3(0.4, 0.9, 0.0), Vector3(0.5, 0.5, 2.6), _mat(IRON))
	_box(buffer, "BufferPostA", Vector3(0.4, 0.5, 1.0), Vector3(0.4, 1.0, 0.4), _mat(IRON))
	_box(buffer, "BufferPostB", Vector3(0.4, 0.5, -1.0), Vector3(0.4, 1.0, 0.4), _mat(IRON))

	# An abandoned train: three cars on the last stretch of the line.
	var car_names: Array[String] = ["AbandonedCar1", "AbandonedCar2", "AbandonedCar3"]
	var car_centres: Array[float] = [track.length() - 8.0, track.length() - 20.0, track.length() - 32.0]
	var car_body: Array[Material] = [_mat(RUST_CAR), _mat(Color(0.2, 0.28, 0.24)), _mat(RUST_CAR)]
	for i: int in car_names.size():
		var index: int = track.sample_index(car_centres[i])
		var tangent: Vector2 = track.tangents[index]
		var car: Node3D = Node3D.new()
		car.name = car_names[i]
		car.position = track.point_at(car_centres[i])
		car.rotation.y = atan2(-tangent.y, tangent.x)
		zone.add_child(car)
		_box(car, "Chassis", Vector3(0.0, 0.75, 0.0), Vector3(11.0, 0.3, 2.7), _mat(IRON))
		_box(car, "Body", Vector3(0.0, 2.2, 0.0), Vector3(11.0, 2.6, 2.7), car_body[i])
		_box(car, "Roof", Vector3(0.0, 3.6, 0.0), Vector3(11.4, 0.2, 3.0), _mat(ROOF_DARK), false)
		_box(car, "DoorGap", Vector3(0.0, 1.9, 1.38), Vector3(1.6, 2.0, 0.06), _mat(Color(0.05, 0.04, 0.04)), false)

	_build_footbridge()


## The covered iron footbridge over the line: steps up on each side, a deck 4 m up, a roof
## on iron posts and side panels. The deck is straight (north-south).
func _build_footbridge() -> void:
	var x: float = -11.0
	var track: TownLane = _lane_by_id["Track"]
	var station: TownLane = _lane_by_id["RuaDaEstacao"]
	var line: TownLane = _lane_by_id["RuaDaLinha"]
	var centre_z: float = _lane_point_near(track, x, _track_z(x)).z
	var deck_y: float = LEVEL_RAIL + 4.0
	var iron: Material = _mat(BRIDGE_IRON)
	var group: Node3D = _sub("CentralRailway", "Footbridge")

	var north_edge: Vector3 = _lane_edge_point(station, x, 1, 0.15)
	var south_edge: Vector3 = _lane_edge_point(line, x, -1, 0.15)
	var north_start: Vector3 = Vector3(x, LEVEL_RAIL + SIDEWALK_RISE, north_edge.z)
	var north_end: Vector3 = Vector3(x, deck_y, centre_z - 3.2)
	var south_start: Vector3 = Vector3(x, LEVEL_RAIL + SIDEWALK_RISE, south_edge.z)
	var south_end: Vector3 = Vector3(x, deck_y, centre_z + 3.2)
	_build_steps(_group(group, "StepsNorth"), north_start, north_end, 1.2, 0.19)
	_build_steps(_group(group, "StepsSouth"), south_start, south_end, 1.2, 0.19)

	_box(group, "BridgeDeck", Vector3(x, deck_y - 0.15, centre_z), Vector3(2.4, 0.3, 6.4), iron)
	for z: float in [centre_z - 3.0, centre_z + 3.0]:
		for side: float in [-1.0, 1.0]:
			_box(group, "BridgePier", Vector3(x + side * 1.0, deck_y * 0.5 - 0.15, z), Vector3(0.45, deck_y - 0.3, 0.45), iron)

	# Solid side panels along the steps (nobody walks under the steps) and the deck.
	for side: float in [-1.0, 1.0]:
		var north_path: PackedVector3Array = PackedVector3Array([north_start + Vector3(side * 1.3, 0.0, 0.0), north_end + Vector3(side * 1.3, 0.0, 0.0)])
		var south_path: PackedVector3Array = PackedVector3Array([south_start + Vector3(side * 1.3, 0.0, 0.0), south_end + Vector3(side * 1.3, 0.0, 0.0)])
		_wall_prism(group, "StepsPanelNorth", north_path, 1.0, 0.18, iron, LEVEL_RAIL - 0.3)
		_wall_prism(group, "StepsPanelSouth", south_path, 1.0, 0.18, iron, LEVEL_RAIL - 0.3)
		_box(group, "BridgeRail", Vector3(x + side * 1.2, deck_y + 0.55, centre_z), Vector3(0.1, 1.1, 6.4), iron)
		_box(group, "BridgeEaves", Vector3(x + side * 1.2, deck_y + 2.25, centre_z), Vector3(0.1, 0.9, 6.4), iron, false)
		for k: int in 3:
			_box(group, "BridgePost", Vector3(x + side * 1.2, deck_y + 1.3, centre_z - 3.0 + float(k) * 3.0), Vector3(0.14, 2.6, 0.14), iron, false)

	_box(group, "BridgeRoof", Vector3(x, deck_y + 2.7, centre_z), Vector3(2.9, 0.15, 6.8), _mat(ROOF_DARK), false)
	_marker_points["FootbridgeMiddle"] = Vector3(x, deck_y, centre_z)
	_marker_points["FootbridgeNorthFoot"] = north_start
	_marker_points["FootbridgeSouthFoot"] = south_start


# ============================================================
# HOUSES
# ============================================================

func _sub(zone_name: String, sub_name: String) -> Node3D:
	var key: String = "%s/%s" % [zone_name, sub_name]
	if not _subs.has(key):
		_subs[key] = _group(_zones[zone_name], sub_name)

	return _subs[key]


func _axes(theta: float) -> Array[Vector2]:
	return [Vector2(cos(theta), -sin(theta)), Vector2(sin(theta), cos(theta))]


## True if the plan point `p` is inside the footprint `fp` grown by `margin`.
func _footprint_has(fp: Dictionary, p: Vector2, margin: float) -> bool:
	var axes: Array[Vector2] = _axes(fp["a"])
	var delta: Vector2 = p - (fp["c"] as Vector2)
	var half: Vector2 = fp["h"]
	return absf(delta.dot(axes[0])) <= half.x + margin and absf(delta.dot(axes[1])) <= half.y + margin


## Do two footprints overlap, both shrunk by `shrink` (separating axis test)?
func _footprints_overlap(a: Dictionary, b: Dictionary, shrink: float) -> bool:
	var axes_a: Array[Vector2] = _axes(a["a"])
	var axes_b: Array[Vector2] = _axes(b["a"])
	var half_a: Vector2 = (a["h"] as Vector2) - Vector2(shrink, shrink)
	var half_b: Vector2 = (b["h"] as Vector2) - Vector2(shrink, shrink)
	var delta: Vector2 = (b["c"] as Vector2) - (a["c"] as Vector2)
	for axis: Vector2 in [axes_a[0], axes_a[1], axes_b[0], axes_b[1]]:
		var radius_a: float = absf(axes_a[0].dot(axis)) * half_a.x + absf(axes_a[1].dot(axis)) * half_a.y
		var radius_b: float = absf(axes_b[0].dot(axis)) * half_b.x + absf(axes_b[1].dot(axis)) * half_b.y
		if absf(delta.dot(axis)) > radius_a + radius_b:
			return false

	return true


func _footprint_points(fp: Dictionary) -> Array[Vector2]:
	var axes: Array[Vector2] = _axes(fp["a"])
	var half: Vector2 = fp["h"]
	var centre: Vector2 = fp["c"]
	var points: Array[Vector2] = []
	for ix: int in [-1, 0, 1]:
		for iz: int in [-1, 0, 1]:
			points.append(centre + axes[0] * half.x * float(ix) + axes[1] * half.y * float(iz))

	return points


func _register_solid(centre: Vector2, half: Vector2, theta: float, is_house: bool) -> Dictionary:
	var fp: Dictionary = {"c": centre, "h": half, "a": theta, "house": is_house}
	_solids.append(fp)
	return fp


func _front_clear(lane: TownLane, side: int, fp: Dictionary, near: int) -> bool:
	var axes: Array[Vector2] = _axes(fp["a"])
	var half: Vector2 = fp["h"]
	for sign_x: float in [-1.0, 1.0]:
		var corner: Vector2 = (fp["c"] as Vector2) + axes[0] * half.x * sign_x + axes[1] * half.y
		if _distance_to_lane(lane, corner, near) < lane.edge_offset(side) - 0.03:
			return false

	return true


func _footprint_free(fp: Dictionary, lane: TownLane) -> bool:
	for point: Vector2 in _footprint_points(fp):
		if point.x < -56.0 or point.x > 56.0 or point.y < -74.0 or point.y > 66.0:
			return false

		if _clearance_at(point, lane) < -0.02:
			return false

		for area: Dictionary in _areas:
			if (area["rect"] as Rect2).grow(0.8).has_point(point):
				return false

	for other: Dictionary in _solids:
		if (other["c"] as Vector2).distance_to(fp["c"]) > 14.0:
			continue

		if _footprints_overlap(fp, other, 0.12):
			return false

	return true


## A house footprint of `width` x `depth` on `side` of `lane`, centred at `s_centre`
## along it, fronting the sidewalk. Pushed out where the lane bends towards it. Empty when
## it does not fit.
func _try_place(lane: TownLane, side: int, s_centre: float, width: float, depth: float, setback: float) -> Dictionary:
	var index: int = lane.sample_index(s_centre)
	var normal: Vector2 = lane.right_normal(index) * float(side)
	var front: Vector2 = -normal
	var theta: float = atan2(front.x, front.y)
	var edge: float = lane.edge_offset(side) + 0.05 + setback
	var fp: Dictionary = {
		"c": lane.xz(index) + normal * (edge + depth * 0.5),
		"h": Vector2(width * 0.5, depth * 0.5),
		"a": theta,
	}
	for attempt: int in 10:
		if _front_clear(lane, side, fp, index):
			break

		fp["c"] = (fp["c"] as Vector2) + normal * 0.12

	if not _front_clear(lane, side, fp, index) or not _footprint_free(fp, lane):
		return {}

	return {"fp": fp, "index": index, "theta": theta, "side": side}


## The base height for a house fronting `lane` at sample `index`: the sidewalk, plus how
## far the ground drops under its corners (the foundation).
func _house_levels(lane: TownLane, index: int, fp: Dictionary, side: int) -> Vector2:
	var walk: float = lane.walk_right if side > 0 else lane.walk_left
	var base_y: float = lane.points[index].y + (SIDEWALK_RISE if walk > 0.0 else 0.05)
	var lowest: float = base_y
	for point: Vector2 in _footprint_points(fp):
		lowest = minf(lowest, _ground_height(point.x, point.y))

	return Vector2(base_y, base_y - lowest + 0.4)


func _fill_houses() -> void:
	for lane: TownLane in _lanes:
		if not lane.houses or lane.kind != TownLane.Kind.COBBLE:
			continue

		for side: int in [-1, 1]:
			var s: float = 1.0
			while s < lane.length() - 1.0:
				var width: float = _rng.randf_range(4.3, 7.6)
				var depth: float = _rng.randf_range(5.5, 8.5)
				var setback: float = _rng.randf_range(0.0, 0.25) if _rng.randf() < 0.35 else 0.0
				# If the house does not fit, try a narrower, shallower one before moving on.
				var placed: Dictionary = {}
				for shrink: float in [1.0, 0.8, 0.62]:
					var try_width: float = maxf(width * shrink, 3.4)
					var try_depth: float = maxf(depth * shrink, 4.6)
					placed = _try_place(lane, side, s + try_width * 0.5, try_width, try_depth, setback)
					if not placed.is_empty():
						width = try_width
						depth = try_depth
						break

				if placed.is_empty():
					s += 0.8
					continue

				_spawn_ordinary_house(lane, placed, width, depth)
				s += width - 0.1


func _side_group(lane: TownLane, side: int) -> Node3D:
	var key: String = "%s%d" % [lane.id, side]
	if not _side_groups.has(key):
		_side_groups[key] = _group(_sub(lane.zone, "Houses"), "%s%s" % [lane.id, "Right" if side > 0 else "Left"])

	return _side_groups[key]


func _spawn_ordinary_house(lane: TownLane, placed: Dictionary, width: float, depth: float) -> void:
	var fp: Dictionary = _register_solid(placed["fp"]["c"], placed["fp"]["h"], placed["theta"], true)
	var levels: Vector2 = _house_levels(lane, placed["index"], fp, placed["side"])
	var roll: float = _rng.randf()
	var floors: int = 1 if roll < 0.4 else (2 if roll < 0.85 else 3)
	var timber: bool = _rng.randf() < 0.28
	var wall: Color = TIMBERS[_rng.randi() % TIMBERS.size()] if timber else BEIGES[_rng.randi() % BEIGES.size()]
	var options: Dictionary = {
		"wall": wall,
		"roof": ROOFS[_rng.randi() % ROOFS.size()],
		"roof_kind": _rng.randi() % 3 if _rng.randf() < 0.5 else 0,
		"floors": floors,
		"drop": levels.y,
		"timber": timber,
		"story_extra": _rng.randf_range(0.0, 0.45),
		"extras": true,
	}
	var centre: Vector2 = fp["c"]
	var house: Node3D = _spawn_house(_side_group(lane, placed["side"]), "House%02d" % _house_count, Vector3(centre.x, levels.x, centre.y), Vector2(width, depth), placed["theta"], options)
	house.set_meta("generic", true)


## A house at a plan position given directly (the key buildings in plazas and yards).
func _spawn_free_house(parent: Node3D, node_name: String, centre: Vector2, base_y: float, size: Vector2, theta: float, options: Dictionary) -> Node3D:
	_register_solid(centre, size * 0.5, theta, true)
	return _spawn_house(parent, node_name, Vector3(centre.x, base_y, centre.y), size, theta, options)


## A house: a solid body from below the ground to the eaves, a sloping roof with eaves
## that overhang the street, and the details (door, windows, shutters, balcony, chimney,
## dish). Its origin is the middle of the base; local +Z is the front.
func _spawn_house(parent: Node3D, node_name: String, base: Vector3, size: Vector2, theta: float, options: Dictionary) -> Node3D:
	var house: Node3D = Node3D.new()
	house.name = node_name
	house.position = base
	house.rotation.y = theta
	parent.add_child(house)

	var floors: int = options.get("floors", 1)
	var story: float = STORY_HEIGHT + float(options.get("story_extra", 0.0))
	var height: float = float(floors) * story
	var drop: float = float(options.get("drop", 0.5))
	var wall: Color = options.get("wall", BEIGES[0])
	var width: float = size.x
	var depth: float = size.y

	if vista_mode:
		var body_mesh: BoxMesh = BoxMesh.new()
		body_mesh.size = Vector3(width, height + drop, depth)
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = "Body"
		visual.mesh = body_mesh
		visual.material_override = _mat(wall)
		visual.position = Vector3(0.0, (height - drop) * 0.5, 0.0)
		house.add_child(visual)
	else:
		var body: CSGBox3D = CSGBox3D.new()
		body.name = "Body"
		body.size = Vector3(width, height + drop, depth)
		body.position = Vector3(0.0, (height - drop) * 0.5, 0.0)
		body.material = _mat(wall)
		body.use_collision = true
		house.add_child(body)

	var roof_kind: int = options.get("roof_kind", 0)
	var roof_color: Color = options.get("roof", ROOF)
	var rise: float = (width if roof_kind == 1 else depth) * _rng.randf_range(0.2, 0.3)
	var roof_builder: TownMeshBuilder = TownMeshBuilder.new()
	_add_roof(roof_builder, roof_kind, width, depth, height, rise)
	var roof: MeshInstance3D = MeshInstance3D.new()
	roof.name = "Roof"
	roof.mesh = roof_builder.build()
	roof.material_override = _mat(roof_color)
	house.add_child(roof)

	var details: TownMeshBuilder = TownMeshBuilder.new()
	var door_x: float = width * 0.22 * (1.0 if _rng.randf() < 0.5 else -1.0)
	var door_color: Color = Color(0.3, 0.2, 0.12) if _rng.randf() < 0.5 else SHUTTERS[_rng.randi() % SHUTTERS.size()].darkened(0.3)
	details.add_box(Vector3(door_x, 1.05, depth * 0.5 + 0.03), Vector3(1.0, 2.1, 0.08), door_color)
	details.add_box(Vector3(door_x, 2.2, depth * 0.5 + 0.02), Vector3(1.3, 0.12, 0.1), wall.lightened(0.35))
	var shutter: Color = SHUTTERS[_rng.randi() % SHUTTERS.size()]
	var frame: Color = wall.lightened(0.4)
	var windows: int = maxi(int((width - 1.0) / 1.9), 1)
	for f: int in floors:
		for k: int in windows:
			var x: float = -width * 0.5 + (float(k) + 0.5) * width / float(windows)
			if f == 0 and absf(x - door_x) < 1.2:
				continue

			var y: float = float(f) * story + 1.7
			details.add_box(Vector3(x, y, depth * 0.5 + 0.015), Vector3(1.05, 1.35, 0.04), frame)
			details.add_box(Vector3(x, y, depth * 0.5 + 0.04), Vector3(0.85, 1.15, 0.04), Color(0.05, 0.06, 0.07))
			# From far away a few windows glow (a hash, so the layout does not change).
			if vista_mode and absi(hash(Vector3(base.x + x, y, base.z))) % 100 < 28:
				_scenery.lit_window(base + Basis(Vector3.UP, theta) * Vector3(x, y, depth * 0.5 + 0.07), Vector3(0.8, 1.0, 0.03), theta)
			if _rng.randf() < 0.8:
				details.add_box(Vector3(x - 0.7, y, depth * 0.5 + 0.06), Vector3(0.42, 1.2, 0.05), shutter)
				details.add_box(Vector3(x + 0.7, y, depth * 0.5 + 0.06), Vector3(0.42, 1.2, 0.05), shutter)

	if options.get("extras", false):
		if floors >= 2 and _rng.randf() < 0.32:
			var balcony_y: float = story
			details.add_box(Vector3(0.0, balcony_y, depth * 0.5 + 0.55), Vector3(width * 0.7, 0.14, 1.1), Color(0.3, 0.3, 0.3))
			details.add_box(Vector3(0.0, balcony_y + 0.55, depth * 0.5 + 1.08), Vector3(width * 0.7, 0.9, 0.05), IRON)
			details.add_box(Vector3(-width * 0.35, balcony_y + 0.55, depth * 0.5 + 0.55), Vector3(0.05, 0.9, 1.1), IRON)
			details.add_box(Vector3(width * 0.35, balcony_y + 0.55, depth * 0.5 + 0.55), Vector3(0.05, 0.9, 1.1), IRON)
		elif floors == 1 and _rng.randf() < 0.2:
			details.add_box(Vector3(door_x, 2.55, depth * 0.5 + 0.5), Vector3(1.9, 0.08, 1.0), SHUTTERS[_rng.randi() % 4])

		if _rng.randf() < 0.3:
			var chimney_x: float = width * 0.28 * (1.0 if _rng.randf() < 0.5 else -1.0)
			details.add_box(Vector3(chimney_x, height + rise * 0.55 + 0.7, -depth * 0.2), Vector3(0.55, 1.6, 0.55), BRICK_RED)

		if _rng.randf() < 0.22:
			var dish: MeshInstance3D = MeshInstance3D.new()
			dish.name = "Dish"
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.35
			sphere.height = 0.2
			dish.mesh = sphere
			dish.material_override = _mat(Color(0.8, 0.8, 0.78))
			dish.position = Vector3(width * 0.3 * (1.0 if _rng.randf() < 0.5 else -1.0), story * 0.6 + float(floors - 1) * story, depth * 0.5 + 0.35)
			dish.rotation_degrees = Vector3(70.0, 0.0, 0.0)
			house.add_child(dish)

	var detail_node: MeshInstance3D = MeshInstance3D.new()
	detail_node.name = "Details"
	detail_node.mesh = details.build()
	detail_node.material_override = _vertex_material()
	house.add_child(detail_node)

	house.set_meta("door_x", door_x)
	house.set_meta("size", size)
	if options.get("key", false):
		house.set_meta("key_building", true)

	_house_count += 1
	return house


## A sloping roof in house-local space (height `h` is the eaves of the walls). Kind 0:
## the ridge runs along the front and the eaves overhang the street; 1: the gable faces
## the street; 2: a single slope falling to the street.
func _add_roof(builder: TownMeshBuilder, kind: int, width: float, depth: float, h: float, rise: float) -> void:
	match kind:
		1:
			var z0: float = -depth * 0.5 - 0.25
			var gable: Array[Vector3] = [
				Vector3(-width * 0.5 - 0.25, h - 0.2, z0),
				Vector3(0.0, h + rise, z0),
				Vector3(width * 0.5 + 0.25, h - 0.2, z0),
			]
			builder.add_prism(gable, Vector3(0.0, 0.0, depth + 0.95))
		2:
			var x0: float = -width * 0.5 - 0.2
			var shed: Array[Vector3] = [
				Vector3(x0, h - 0.15, depth * 0.5 + 0.7),
				Vector3(x0, h + rise * 0.8, -depth * 0.5 - 0.25),
				Vector3(x0, h - 0.05, -depth * 0.5 - 0.25),
				Vector3(x0, h - 0.3, depth * 0.5 + 0.7),
			]
			builder.add_prism(shed, Vector3(width + 0.4, 0.0, 0.0))
		_:
			var x1: float = -width * 0.5 - 0.2
			var ridge: Array[Vector3] = [
				Vector3(x1, h - 0.3, depth * 0.5 + 0.7),
				Vector3(x1, h + rise, 0.0),
				Vector3(x1, h - 0.15, -depth * 0.5 - 0.25),
			]
			builder.add_prism(ridge, Vector3(width + 0.4, 0.0, 0.0))


# ============================================================
# POINTS OF INTEREST
# ============================================================

## The key buildings go in first, so the ordinary houses fill what is left.
func _place_points_of_interest() -> void:
	var upper: TownLane = _lane_by_id["RuaAlta"]
	var station: TownLane = _lane_by_id["RuaDaEstacao"]
	var main_street: TownLane = _lane_by_id["RuaPrincipal"]

	# Juliana's house: on the north side of Rua Alta, across from the stone staircase.
	var juliana_group: Node3D = _group(_sub("UpperTown", "Houses"), "JulianasHouseLot")
	var juliana: Node3D = _place_key_house(upper, -1, upper.closest_s(Vector2(-19.5, -33.0)), Vector2(8.0, 7.0), 1, KEY_RED, ROOF_DARK, 0, juliana_group, "JulianasHouse", "JulianasHouse")
	if juliana == null:
		push_warning("TownBlockout: no room for Juliana's house")

	# The signal tower on the north bank of the railway.
	var tower_group: Node3D = _group(_sub("CentralRailway", "SignalTower"), "SignalTowerLot")
	var tower: Node3D = _place_key_house(station, -1, station.closest_s(Vector2(6.0, -13.0)), Vector2(5.8, 5.8), 2, BRICK_RED, ROOF_DARK, 1, tower_group, "SignalTower", "SignalTower")
	if tower != null:
		var size: Vector2 = tower.get_meta("size")
		var height: float = 2.0 * STORY_HEIGHT
		_box(tower, "SignalLantern", Vector3(0.0, height + 1.9, 0.0), Vector3(2.8, 1.5, 2.8), _mat(Color(0.2, 0.22, 0.25)), false)
		_box(tower, "SignalBalcony", Vector3(0.0, STORY_HEIGHT, size.y * 0.5 + 0.6), Vector3(size.x, 0.2, 1.2), _mat(IRON))
		_box(tower, "SignalMast", Vector3(size.x * 0.5 + 1.2, height * 0.5 + 1.0, size.y * 0.5 + 0.6), Vector3(0.2, height + 2.0, 0.2), _mat(IRON))
		_box(tower, "SignalArm", Vector3(size.x * 0.5 + 0.7, height + 1.0, size.y * 0.5 + 0.6), Vector3(1.2, 0.2, 0.1), _mat(KEY_RED), false)

	# The corner botequim, on the south corner of the junction with Rua Oeste.
	var botequim_group: Node3D = _group(_sub("LowerTown", "CornerBotequim"), "BotequimLot")
	var botequim_s: float = main_street.closest_s(Vector2(-1.5, 36.5))
	var botequim: Node3D = _place_key_house(main_street, 1, botequim_s, Vector2(9.0, 8.0), 1, KEY_RED, ROOF_DARK, 0, botequim_group, "CornerBotequim", "CornerBotequim")
	if botequim != null:
		var size: Vector2 = botequim.get_meta("size")
		_box(botequim, "BotequimAwning", Vector3(0.0, 2.7, size.y * 0.5 + 0.8), Vector3(size.x * 0.7, 0.12, 1.6), _mat(YELLOW), false)
		_box(botequim, "BotequimSign", Vector3(0.0, 3.35, size.y * 0.5 + 0.06), Vector3(size.x * 0.5, 0.6, 0.12), _mat(Color(0.9, 0.88, 0.8)), false)
		# The yellow Orelhao stands on the sidewalk in front of the building's corner on the junction.
		var info: Dictionary = landmarks["CornerBotequim"]
		var base_info: Vector3 = info["base"]
		var theta: float = info["theta"]
		var local_axes: Array[Vector2] = _axes(theta)
		var facing: Vector2 = local_axes[1]
		var toward_junction: Vector2 = -main_street.tangents[main_street.sample_index(botequim_s)]
		var booth_xz: Vector2 = Vector2(base_info.x, base_info.z) + toward_junction * (size.x * 0.5 - 0.9) + facing * (size.y * 0.5 + 0.5)
		var lane_y: float = main_street.point_at(botequim_s).y
		_orelhao(botequim_group, "Orelhao", Vector3(booth_xz.x, lane_y + SIDEWALK_RISE, booth_xz.y), theta)
		_marker_points["OrelhaoSpot"] = Vector3(booth_xz.x + facing.x * 1.1, lane_y + 0.06, booth_xz.y + facing.y * 1.1)

	# Sophia's house in the middle of her wide yard, facing the drive.
	var sophia_group: Node3D = _group(_sub("LowerTown", "SophiasHouse"), "SophiasHouseLot")
	var yard_rect: Rect2 = _area("SophiasYard")["rect"]
	var sophia_centre: Vector2 = Vector2(yard_rect.position.x + 7.5, yard_rect.position.y + 8.0)
	var sophia_options: Dictionary = {"wall": KEY_RED, "roof": ROOF, "floors": 1, "roof_kind": 0, "drop": 0.6, "key": true}
	var sophia: Node3D = _spawn_free_house(sophia_group, "SophiasHouse", sophia_centre, LEVEL_LOW + 0.25, Vector2(11.0, 8.0), PI * 0.5, sophia_options)
	_remember_landmark("SophiasHouse", sophia, Vector3(sophia_centre.x, LEVEL_LOW + 0.25, sophia_centre.y), PI * 0.5, Vector2(11.0, 8.0))
	_box(sophia, "SophiasPorch", Vector3(0.0, 0.15, 4.9), Vector3(5.0, 0.3, 1.8), _mat(WOOD), false)

	# The maintenance shed on the south side of its yard, facing the gate.
	var shed_group: Node3D = _group(_sub("CentralRailway", "MaintenanceYard"), "ShedLot")
	var shed_rect: Rect2 = _area("MaintenanceYard")["rect"]
	var shed_centre: Vector2 = Vector2(shed_rect.position.x + 8.0, shed_rect.end.y - 4.4)
	var shed_options: Dictionary = {"wall": Color(0.45, 0.47, 0.46), "roof": ROOF_DARK, "floors": 2, "roof_kind": 1, "drop": 0.5, "story_extra": 0.4, "key": false}
	var shed: Node3D = _spawn_free_house(shed_group, "MaintenanceShed", shed_centre, -0.2, Vector2(14.0, 8.0), PI, shed_options)
	shed.set_meta("industrial", true)
	_remember_landmark("MaintenanceShed", shed, Vector3(shed_centre.x, -0.2, shed_centre.y), PI, Vector2(14.0, 8.0))

	# The parish chapel on the north side of the church plaza, with its bell tower.
	var church_group: Node3D = _group(_sub("UpperTown", "ChurchAndCemetery"), "ChapelLot")
	var plaza_rect: Rect2 = _area("ChurchPlaza")["rect"]
	var chapel_centre: Vector2 = Vector2(plaza_rect.position.x + 11.0, plaza_rect.position.y - 6.5)
	var chapel_options: Dictionary = {"wall": KEY_RED, "roof": ROOF_DARK, "floors": 2, "roof_kind": 1, "drop": 0.6, "story_extra": 0.5, "key": true}
	var chapel: Node3D = _spawn_free_house(church_group, "ParishChapel", chapel_centre, LEVEL_TERRACE, Vector2(12.0, 13.0), 0.0, chapel_options)
	_remember_landmark("ParishChapel", chapel, Vector3(chapel_centre.x, LEVEL_TERRACE, chapel_centre.y), 0.0, Vector2(12.0, 13.0))

	var tower_centre: Vector2 = Vector2(chapel_centre.x + 8.5, plaza_rect.position.y - 2.0)
	_register_solid(tower_centre, Vector2(2.0, 2.0), 0.0, true)
	var bell_tower: Node3D = Node3D.new()
	bell_tower.name = "BellTower"
	bell_tower.position = Vector3(tower_centre.x, LEVEL_TERRACE, tower_centre.y)
	church_group.add_child(bell_tower)
	_box(bell_tower, "TowerBody", Vector3(0.0, 6.0, 0.0), Vector3(4.0, 12.0, 4.0), _mat(KEY_RED))
	_box(bell_tower, "TowerBelfry", Vector3(0.0, 12.9, 0.0), Vector3(3.0, 1.8, 3.0), _mat(BRICK_RED), false)
	_cyl(bell_tower, "TowerSpire", Vector3(0.0, 15.6, 0.0), 2.0, 3.6, _mat(ROOF_DARK), false, 4, true)


## Places a key building on a lane (looking for room near `s`), registers where its door is.
func _place_key_house(lane: TownLane, side: int, s: float, size: Vector2, floors: int, wall: Color, roof: Color, roof_kind: int, parent: Node3D, node_name: String, landmark: String) -> Node3D:
	for shift: float in [0.0, 1.0, -1.0, 2.0, -2.0, 3.0, -3.0, 4.5, -4.5]:
		var placed: Dictionary = _try_place(lane, side, s + shift, size.x, size.y, 0.0)
		if placed.is_empty():
			continue

		var fp: Dictionary = _register_solid(placed["fp"]["c"], placed["fp"]["h"], placed["theta"], true)
		var levels: Vector2 = _house_levels(lane, placed["index"], fp, side)
		var options: Dictionary = {
			"wall": wall, "roof": roof, "roof_kind": roof_kind, "floors": floors,
			"drop": levels.y, "key": true, "story_extra": 0.2,
		}
		var centre: Vector2 = fp["c"]
		var house: Node3D = _spawn_house(parent, node_name, Vector3(centre.x, levels.x, centre.y), size, placed["theta"], options)
		_remember_landmark(landmark, house, Vector3(centre.x, levels.x, centre.y), placed["theta"], size)
		return house

	return null


func _remember_landmark(landmark: String, house: Node3D, base: Vector3, theta: float, size: Vector2) -> void:
	var door_x: float = house.get_meta("door_x", 0.0)
	var house_basis: Basis = Basis(Vector3.UP, theta)
	var door: Vector3 = base + house_basis * Vector3(door_x, 0.0, size.y * 0.5 + 0.6)
	landmarks[landmark] = {"base": base, "theta": theta, "size": size, "door": door, "node": house}


## Props of the key places that are not houses: the plaza, the cemetery, the yards.
func _build_points_of_interest_props() -> void:
	_build_church_grounds()
	_build_sophias_yard()
	_build_maintenance_yard()
	_build_trailhead()


func _build_church_grounds() -> void:
	var zone: Node3D = _sub("UpperTown", "ChurchAndCemetery")
	var wall_mat: Material = _stone(STONE_WALL)
	var plaza: Rect2 = _area("ChurchPlaza")["rect"]
	var cemetery: Rect2 = _area("Cemetery")["rect"]
	var y: float = LEVEL_TERRACE

	# The plaza wall (open where the lane comes in, behind the chapel and for the gate)
	# and the cemetery wall.
	_wall_line_with_gaps(zone, "PlazaWallSouth", Vector2(plaza.position.x, plaza.end.y), Vector2(plaza.end.x, plaza.end.y), y, 1.2, 0.45, wall_mat, [])
	_wall_line_with_gaps(zone, "PlazaWallWest", Vector2(plaza.position.x, plaza.end.y), Vector2(plaza.position.x, plaza.position.y), y, 1.2, 0.45, wall_mat, [])
	_wall_line_with_gaps(zone, "PlazaWallNorth", Vector2(plaza.position.x, plaza.position.y), Vector2(cemetery.position.x, plaza.position.y), y, 1.8, 0.45, wall_mat, [])
	var gate: Vector2 = Vector2(cemetery.position.x, plaza.position.y + 4.5)
	_wall_line_with_gaps(zone, "CemeteryWallWest", Vector2(cemetery.position.x, plaza.end.y), Vector2(cemetery.position.x, cemetery.position.y), y, 1.8, 0.4, wall_mat, [Vector3(gate.x, gate.y, 2.0)])
	_wall_line_with_gaps(zone, "CemeteryWallNorth", Vector2(cemetery.position.x, cemetery.position.y), Vector2(cemetery.end.x, cemetery.position.y), y, 1.8, 0.4, wall_mat, [])
	_wall_line_with_gaps(zone, "CemeteryWallEast", Vector2(cemetery.end.x, cemetery.position.y), Vector2(cemetery.end.x, cemetery.end.y), y, 1.8, 0.4, wall_mat, [])
	_wall_line_with_gaps(zone, "CemeteryWallSouth", Vector2(cemetery.end.x, cemetery.end.y), Vector2(cemetery.position.x, cemetery.end.y), y, 1.8, 0.4, wall_mat, [])
	_box(zone, "CemeteryGatePostNorth", Vector3(gate.x, y + 1.2, gate.y - 2.0), Vector3(0.6, 2.4, 0.6), _mat(IRON))
	_box(zone, "CemeteryGatePostSouth", Vector3(gate.x, y + 1.2, gate.y + 2.0), Vector3(0.6, 2.4, 0.6), _mat(IRON))
	_marker_points["CemeteryGate"] = Vector3(gate.x, y, gate.y)

	var grave_mat: Material = _mat(GRAVE)
	var index: int = 0
	for column: int in 5:
		for row: int in 5:
			if _rng.randf() < 0.12:
				continue

			var spot: Vector3 = Vector3(
				cemetery.position.x + 4.0 + float(column) * 3.2 + _rng.randf_range(-0.3, 0.3),
				y,
				cemetery.position.y + 4.0 + float(row) * 3.2 + _rng.randf_range(-0.3, 0.3)
			)
			_box(zone, "Headstone%02d" % index, spot + Vector3(0.0, 0.45, 0.0), Vector3(0.7, 0.9, 0.2), grave_mat, true, _rng.randf_range(-6.0, 6.0))
			index += 1

	for i: int in 4:
		_tree(zone, "Cypress%d" % i, Vector3(cemetery.position.x + 1.5, y, cemetery.position.y + 2.5 + float(i) * 5.0), 7.5)


func _build_sophias_yard() -> void:
	var zone: Node3D = _sub("LowerTown", "SophiasHouse")
	var rect: Rect2 = _area("SophiasYard")["rect"]
	var fence: Material = _mat(WOOD)
	var y: float = LEVEL_LOW
	for side: Array in [
		["YardFenceNorth", Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y)],
		["YardFenceEast", Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y)],
		["YardFenceBack", Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y)],
		["YardFenceWest", Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.position.y)],
	]:
		_wall_line_with_gaps(zone, side[0], side[1], side[2], y, 1.3, 0.16, fence, [])

	_box(zone, "YardShed", Vector3(rect.position.x + 2.0, y + 1.1, rect.end.y - 2.2), Vector3(3.2, 2.2, 2.6), _mat(WOOD))
	_register_solid(Vector2(rect.position.x + 2.0, rect.end.y - 2.2), Vector2(1.6, 1.3), 0.0, false)
	_box(zone, "ClotheslinePost", Vector3(rect.end.x - 5.0, y + 1.3, rect.position.y + 3.0), Vector3(0.12, 2.6, 0.12), _mat(IRON))
	_tree(zone, "YardTree1", Vector3(rect.position.x + 5.0, y, rect.position.y + 2.5), 5.5)
	_tree(zone, "YardTree2", Vector3(rect.end.x - 4.0, y, rect.end.y - 2.5), 6.0)


func _build_maintenance_yard() -> void:
	var zone: Node3D = _sub("CentralRailway", "MaintenanceYard")
	var rect: Rect2 = _area("MaintenanceYard")["rect"]
	var fence: Material = _mat(WOOD)
	var y: float = -0.2
	for side: Array in [
		["TimberYardFence", Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y)],
		["TimberYardFenceEast", Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y)],
		["TimberYardFenceSouth", Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y)],
		["TimberYardFenceWest", Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.position.y)],
	]:
		_wall_line_with_gaps(zone, side[0], side[1], side[2], y, 1.6, 0.2, fence, [])

	# Stacked lumber east of the shed.
	var timber: Material = _mat(TIMBER)
	var stack_index: int = 0
	for row: int in 3:
		for column: int in 2:
			var base: Vector3 = Vector3(rect.end.x - 6.0 + float(column) * 3.2, y, rect.position.y + 3.0 + float(row) * 3.6)
			var layers: int = _rng.randi_range(2, 4)
			for layer: int in layers:
				_box(zone, "Lumber%02d_%d" % [stack_index, layer], base + Vector3(0.0, 0.3 + float(layer) * 0.55, 0.0), Vector3(2.8, 0.5, 1.5), timber, true, _rng.randf_range(-3.0, 3.0))

			stack_index += 1


func _build_trailhead() -> void:
	var zone: Node3D = _sub("LowerTown", "ForestTrailhead")
	var trail: TownLane = _lane_by_id["ForestTrail"]
	var start: Vector3 = trail.points[0]
	var wood: Material = _mat(WOOD)
	var tangent: Vector2 = trail.tangents[0]
	var side: Vector2 = Vector2(-tangent.y, tangent.x)
	_box(zone, "TrailGatePostWest", start + Vector3(side.x * -2.0, 1.2, side.y * -2.0), Vector3(0.3, 2.4, 0.3), wood)
	_box(zone, "TrailGatePostEast", start + Vector3(side.x * 2.0, 1.2, side.y * 2.0), Vector3(0.3, 2.4, 0.3), wood)
	var beam: Node3D = _box(zone, "TrailGateBeam", start + Vector3(0.0, 2.45, 0.0), Vector3(0.25, 0.25, 4.7), wood, false)
	beam.rotation.y = atan2(-side.y, side.x) + PI * 0.5
	_box(zone, "TrailMarker", start + Vector3(side.x * 2.8, 0.7, side.y * 2.8 + 0.5), Vector3(0.5, 1.4, 0.15), _mat(Color(0.9, 0.88, 0.8)), false)
	_marker_points["TrailheadGate"] = start
	_marker_points["ForestEdge"] = trail.points[trail.points.size() - 1]

	# Trunks standing along the path.
	for i: int in range(4, trail.points.size() - 1, 3):
		for s: float in [-1.0, 1.0]:
			var n: Vector2 = trail.right_normal(i) * s
			var spot: Vector2 = trail.xz(i) + n * (2.1 + _rng.randf_range(0.0, 1.2))
			_tree(zone, "PathTree%02d_%d" % [i, int(s)], Vector3(spot.x, trail.points[i].y, spot.y), _rng.randf_range(7.0, 10.5))


# ============================================================
# FRONTAGE: THE WALLS THAT CLOSE THE LANES
# ============================================================

func _covered(p: Vector2, margin: float) -> bool:
	for solid: Dictionary in _solids:
		if (solid["c"] as Vector2).distance_to(p) > 14.0:
			continue

		if _footprint_has(solid, p, margin):
			return true

	return false


func _wall_style_materials(style: int) -> Array:
	# [material, height, thickness]
	match style:
		1:
			return [_stone(STONE_WALL), _rng.randf_range(1.3, 1.8), 0.45]
		2:
			return [_mat(Color(0.07, 0.17, 0.08)), 2.6, 1.2]
		3:
			return [_mat(WOOD), 1.4, 0.18]
		4:
			return [_mat(Color(0.2, 0.34, 0.24)), 2.0, 0.25]
		5:
			return [_mat(Color(0.82, 0.78, 0.68)), 1.7, 0.3]
		6:
			return [_stone(STONE_WALL), 0.95, 0.4]
		_:
			return []


## Every lane side that is not closed by a house, another lane or a plaza gets a garden
## wall; dead ends get a wall across.
func _build_frontage() -> void:
	for lane: TownLane in _lanes:
		if lane.kind == TownLane.Kind.TRACK:
			continue

		var group: Node3D = _group(_sub(lane.zone, "Walls"), lane.id)
		for side: int in [-1, 1]:
			var offset: float = lane.edge_offset(side) + 0.1
			var need: Array[bool] = []
			for i: int in lane.points.size():
				var q: Vector2 = lane.xz(i) + lane.right_normal(i) * float(side) * offset
				var open: bool = _clearance_at(q, lane) < 0.25 or _covered(q, 0.5)
				need.append(not open)

			var i: int = 0
			var run_index: int = 0
			while i < need.size():
				if not need[i]:
					i += 1
					continue

				var j: int = i
				while j + 1 < need.size() and need[j + 1]:
					j += 1

				var style: int = lane.wall_style
				if style == 0:
					style = [1, 4, 5, 3][_rng.randi() % 4]

				var spec: Array = _wall_style_materials(style)
				var path: PackedVector3Array = PackedVector3Array()
				for k: int in range(maxi(i - 1, 0), mini(j + 1, need.size() - 1) + 1):
					var wall_offset: float = offset + float(spec[2]) * 0.5
					var p: Vector2 = lane.xz(k) + lane.right_normal(k) * float(side) * wall_offset
					path.append(Vector3(p.x, lane.points[k].y, p.y))

				_wall_prism(group, "Wall%s%d" % ["R" if side > 0 else "L", run_index], path, spec[1], spec[2], spec[0])
				_register_wall_path(path, spec[2])
				run_index += 1
				i = j + 1

		_cap_lane_ends(lane, group)


func _cap_lane_ends(lane: TownLane, group: Node3D) -> void:
	for end: int in [0, 1]:
		if (end == 0 and not lane.capped_start) or (end == 1 and not lane.capped_end):
			continue

		var index: int = 0 if end == 0 else lane.points.size() - 1
		var outward: Vector2 = -lane.tangents[index] if end == 0 else lane.tangents[index]
		var normal: Vector2 = lane.right_normal(index)
		var style: int = lane.wall_style if lane.wall_style > 0 else 4
		var spec: Array = _wall_style_materials(style)
		var centre: Vector2 = lane.xz(index) + outward * (0.2 + float(spec[2]) * 0.5)
		var path: PackedVector3Array = PackedVector3Array()
		for fraction: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var offset: float = (lane.edge_offset(1) + 0.3) * fraction if fraction >= 0.0 else (lane.edge_offset(-1) + 0.3) * fraction
			var p: Vector2 = centre + normal * offset
			path.append(Vector3(p.x, lane.points[index].y, p.y))

		_wall_prism(group, "Cap%s" % ("Start" if end == 0 else "End"), path, spec[1], spec[2], spec[0])
		_register_wall_path(path, spec[2])


## Remembers the footprint of a wall, so the border raster treats it as solid.
func _register_wall_path(path: PackedVector3Array, thickness: float) -> void:
	for i: int in path.size() - 1:
		var a: Vector2 = Vector2(path[i].x, path[i].z)
		var b: Vector2 = Vector2(path[i + 1].x, path[i + 1].z)
		var length: float = a.distance_to(b)
		if length < 0.05:
			continue

		var direction: Vector2 = (b - a) / length
		# Local Z runs along the wall.
		var theta: float = atan2(direction.x, direction.y)
		_register_solid((a + b) * 0.5, Vector2(thickness * 0.5, length * 0.5 + 0.05), theta, false)


## A wall (a prism along `path`, its points on the ground): `height` above the ground,
## `thickness` thick, sunk below it (to `floor_y` when given, for walls beside stairs).
func _wall_prism(parent: Node3D, node_name: String, path: PackedVector3Array, height: float, thickness: float, material: Material, floor_y: float = NAN) -> void:
	if path.size() < 2:
		return

	var builder: TownMeshBuilder = TownMeshBuilder.new()
	var bottom: float = -1000.0 if not is_nan(floor_y) else -0.8
	builder.extrude(path, PackedVector2Array([
		Vector2(-thickness * 0.5, bottom), Vector2(thickness * 0.5, bottom),
		Vector2(thickness * 0.5, height), Vector2(-thickness * 0.5, height),
	]), true, Color.WHITE, floor_y)
	_solid_mesh(parent, node_name, builder.build(), material)


## A wall along the line a -> b at the fixed height `y`, with gaps: wherever a lane's
## corridor or a house is, and at each extra gap (x, z, radius).
func _wall_line_with_gaps(parent: Node3D, node_name: String, a: Vector2, b: Vector2, y: float, height: float, thickness: float, material: Material, gaps: Array) -> void:
	var length: float = a.distance_to(b)
	var count: int = maxi(int(length / 0.5), 1)
	var need: Array[bool] = []
	var points: Array[Vector2] = []
	for i: int in count + 1:
		var p: Vector2 = a.lerp(b, float(i) / float(count))
		points.append(p)
		var open: bool = _clearance_at(p, null) < 0.2 or _covered(p, 0.3)
		for gap: Variant in gaps:
			var g: Vector3 = gap
			if Vector2(g.x, g.y).distance_to(p) < g.z:
				open = true

		need.append(not open)

	var i: int = 0
	var run_index: int = 0
	while i <= count:
		if not need[i]:
			i += 1
			continue

		var j: int = i
		while j + 1 <= count and need[j + 1]:
			j += 1

		var path: PackedVector3Array = PackedVector3Array()
		for k: int in range(i, j + 1):
			path.append(Vector3(points[k].x, y, points[k].y))

		if path.size() >= 2:
			_wall_prism(parent, "%s%d" % [node_name, run_index], path, height, thickness, material)
			_register_wall_path(path, thickness)
			run_index += 1

		i = j + 1


# ============================================================
# POLES, WIRES, SIGNS
# ============================================================

func _build_poles() -> void:
	for lane: TownLane in _lanes:
		if lane.kind != TownLane.Kind.COBBLE or lane.id == "SophiasDrive" or lane.id == "ShedDrive":
			continue

		var group: Node3D = _group(_sub(lane.zone, "Props"), "%sPoles" % lane.id)
		var side: int = 1 if _rng.randf() < 0.5 else -1
		var previous_top: Vector3 = Vector3.INF
		var previous_normal: Vector2 = Vector2.ZERO
		var s: float = _rng.randf_range(3.0, 7.0)
		var n: int = 0
		while s < lane.length() - 2.0:
			var index: int = lane.sample_index(s)
			var normal: Vector2 = lane.right_normal(index)
			var spot: Vector2 = lane.xz(index) + normal * float(side) * (lane.edge_offset(side) - 0.3)
			if _clearance_at(spot, lane) < 0.6 or _covered(spot, 0.2):
				s += 2.0
				continue

			var base: Vector3 = Vector3(spot.x, lane.points[index].y + SIDEWALK_RISE, spot.y)
			_cyl(group, "Pole%02d" % n, base + Vector3(0.0, 3.1, 0.0), 0.12, 6.2, _mat(TRUNK), true, 8)
			var top: Vector3 = base + Vector3(0.0, 6.0, 0.0)
			var cross: Vector3 = Vector3(normal.x, 0.0, normal.y)
			_box(group, "Crossarm%02d" % n, top, Vector3(0.1, 0.1, 1.4), _mat(IRON), false, rad_to_deg(atan2(-cross.z, cross.x)) + 90.0)

			# Three wires to the previous pole, and a few across the lane.
			if previous_top != Vector3.INF and previous_top.distance_to(top) < 22.0:
				for lateral: float in [-0.5, 0.0, 0.5]:
					_add_wire(previous_top + Vector3(previous_normal.x, 0.0, previous_normal.y) * lateral, top + cross * lateral, 0.45)

			var across: Vector3 = top - cross * float(side) * (lane.corridor_half() * 2.0 + 0.5) + Vector3(0.0, -1.2, 0.0)
			for lateral: float in [-0.4, 0.4]:
				if _rng.randf() < 0.7:
					_add_wire(top + cross * lateral * 0.5, across + Vector3(lane.tangents[index].x, 0.0, lane.tangents[index].y) * lateral, 0.3)

			if n % 2 == 0:
				_lamp_points.append(top + Vector3(0.0, -0.5, 0.0) - cross * float(side) * 0.6)
				_box(group, "LampArm%02d" % n, top + Vector3(0.0, -0.45, 0.0) - cross * float(side) * 0.35, Vector3(0.08, 0.08, 0.8), _mat(IRON), false, rad_to_deg(atan2(-cross.z, cross.x)) + 90.0)
				var lamp: MeshInstance3D = MeshInstance3D.new()
				lamp.name = "Lamp%02d" % n
				var lamp_mesh: SphereMesh = SphereMesh.new()
				lamp_mesh.radius = 0.16
				lamp_mesh.height = 0.3
				lamp.mesh = lamp_mesh
				var lamp_material: StandardMaterial3D = _mat(Color(1.0, 0.85, 0.6))
				lamp.material_override = lamp_material
				lamp.position = top + Vector3(0.0, -0.55, 0.0) - cross * float(side) * 0.7
				group.add_child(lamp)

			# A round traffic sign on some of the poles.
			if _rng.randf() < 0.18:
				var sign_mesh: CylinderMesh = CylinderMesh.new()
				sign_mesh.top_radius = 0.28
				sign_mesh.bottom_radius = 0.28
				sign_mesh.height = 0.03
				var sign_node: MeshInstance3D = MeshInstance3D.new()
				sign_node.name = "Sign%02d" % n
				sign_node.mesh = sign_mesh
				sign_node.material_override = _mat(Color(0.7, 0.12, 0.1) if _rng.randf() < 0.6 else Color(0.12, 0.25, 0.55))
				sign_node.position = base + Vector3(0.0, 2.3, 0.0) - cross * float(side) * 0.16
				var tangent: Vector2 = lane.tangents[index]
				sign_node.rotation = Vector3(PI * 0.5, atan2(tangent.x, tangent.y), 0.0)
				group.add_child(sign_node)

			previous_top = top
			previous_normal = normal
			side = -side
			n += 1
			_pole_count += 1
			s += _rng.randf_range(9.0, 13.0)


## A sagging wire from a to b as a thin crossed ribbon.
func _add_wire(a: Vector3, b: Vector3, sag: float) -> void:
	var segments: int = 6
	var previous: Vector3 = a
	for k: int in range(1, segments + 1):
		var t: float = float(k) / float(segments)
		var point: Vector3 = a.lerp(b, t) - Vector3(0.0, sag * 4.0 * t * (1.0 - t), 0.0)
		var direction: Vector3 = (point - previous).normalized()
		var side: Vector3 = direction.cross(Vector3.UP).normalized() * 0.018
		var up: Vector3 = Vector3.UP * 0.018
		_wires.add_quad(previous - side, previous + side, point + side, point - side, Vector3.UP)
		_wires.add_quad(previous - up, previous + up, point + up, point - up, side)
		previous = point


func _finish_wires(parent: Node3D) -> void:
	if _wires.is_empty():
		return

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.04, 0.04)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance: MeshInstance3D = _solid_mesh(_group(parent, "Wires"), "OverheadWires", _wires.build(), material, false)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ============================================================
# BUILDING BLOCKS
# ============================================================

func _group(parent: Node, group_name: String) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = group_name
	parent.add_child(node)
	return node


func _mat(color: Color, roughness: float = 0.95) -> StandardMaterial3D:
	var key: String = "%s_%.2f" % [color.to_html(), roughness]
	if not _materials.has(key):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_materials[key] = material

	return _materials[key]


## The lamps of the playable lanes glow as small emissive boxes (no lights, they would not
## be seen from far away and would cost a lot).
func _light_the_vista() -> void:
	for point: Vector3 in _lamp_points:
		_scenery.lit_lamp(point)


## A grainy stone (world-mapped noise) for walls and steps.
func _stone(color: Color) -> StandardMaterial3D:
	var key: String = "stone_%s" % color.to_html()
	if not _materials.has(key):
		_materials[key] = JunctionProps.weathered(color, 1.6, 0.95)

	return _materials[key]


## One material for everything coloured per vertex (the details of a house, the steps).
func _vertex_material() -> StandardMaterial3D:
	if not _materials.has("details"):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		_materials["details"] = material

	return _materials["details"]


## A mesh with a trimesh collider (both sides), for everything built as a surface.
func _solid_mesh(parent: Node3D, node_name: String, mesh: ArrayMesh, material: Material, collide: bool = true) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	if collide and not vista_mode and mesh.get_surface_count() > 0:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Body"
		var shape: CollisionShape3D = CollisionShape3D.new()
		var concave: ConcavePolygonShape3D = mesh.create_trimesh_shape()
		concave.backface_collision = true
		shape.shape = concave
		body.add_child(shape)
		instance.add_child(body)

	return instance


## A box. Solid ones are CSG with collision (what the blockout is made of); a box with no
## collision (a door, a window, a wire) is only a mesh, which is far cheaper than a CSG
## shape that nothing touches.
func _box(parent: Node, node_name: String, pos: Vector3, size: Vector3, material: Material, collide: bool = true, yaw_degrees: float = 0.0) -> Node3D:
	if not collide or vista_mode:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = node_name
		visual.mesh = mesh
		visual.material_override = material
		visual.position = pos
		visual.rotation_degrees.y = yaw_degrees
		parent.add_child(visual)
		return visual

	var node: CSGBox3D = CSGBox3D.new()
	node.name = node_name
	node.size = size
	node.position = pos
	node.rotation_degrees.y = yaw_degrees
	node.material = material
	node.use_collision = true
	parent.add_child(node)
	return node


func _cyl(parent: Node, node_name: String, pos: Vector3, radius: float, height: float, material: Material, collide: bool = true, sides: int = 12, cone: bool = false) -> Node3D:
	if not collide or vista_mode:
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.0 if cone else radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = sides
		mesh.rings = 1
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = node_name
		visual.mesh = mesh
		visual.material_override = material
		visual.position = pos
		parent.add_child(visual)
		return visual

	var node: CSGCylinder3D = CSGCylinder3D.new()
	node.name = node_name
	node.radius = radius
	node.height = height
	node.sides = sides
	node.cone = cone
	node.position = pos
	node.material = material
	node.use_collision = true
	parent.add_child(node)
	return node


func _tree(parent: Node, node_name: String, base: Vector3, height: float) -> void:
	if vista_mode:
		# Seen from the overlook: a real tree instance (the vista builder plants it), slim for cypresses.
		vista_tree_spots.append({"position": base, "height": height, "slim": node_name.begins_with("Cypress")})
		_tree_count += 1
		return

	var tree: Node3D = Node3D.new()
	tree.name = node_name
	tree.position = base
	parent.add_child(tree)
	var trunk_height: float = height * 0.4
	_cyl(tree, "Trunk", Vector3(0.0, trunk_height * 0.5, 0.0), 0.28, trunk_height, _mat(TRUNK), true, 8)
	_cyl(tree, "Canopy", Vector3(0.0, trunk_height + height * 0.35, 0.0), height * 0.24, height * 0.75, _mat(FOREST), false, 8, true)
	_tree_count += 1


## A yellow fibreglass shell payphone: a post and an egg-shaped hood (a stand-in; the
## detailed one is `OrelhaoModel`). Local +Z is the front.
func _orelhao(parent: Node, node_name: String, base: Vector3, theta: float) -> void:
	var booth: Node3D = Node3D.new()
	booth.name = node_name
	booth.position = base
	booth.rotation.y = theta
	parent.add_child(booth)
	_cyl(booth, "Post", Vector3(0.0, 0.55, 0.0), 0.05, 1.1, _mat(IRON), true, 8)
	if vista_mode:
		var shell_mesh: SphereMesh = SphereMesh.new()
		shell_mesh.radius = 0.45
		shell_mesh.height = 0.9
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = "Shell"
		visual.mesh = shell_mesh
		visual.material_override = _mat(YELLOW, 0.5)
		visual.scale = Vector3(0.85, 1.15, 0.95)
		visual.position = Vector3(0.0, 1.5, 0.0)
		booth.add_child(visual)
		return

	var shell: CSGSphere3D = CSGSphere3D.new()
	shell.name = "Shell"
	shell.radius = 0.45
	shell.scale = Vector3(0.85, 1.15, 0.95)
	shell.position = Vector3(0.0, 1.5, 0.0)
	shell.material = _mat(YELLOW, 0.5)
	shell.use_collision = true
	booth.add_child(shell)


# ============================================================
# MARKERS, BOUNDARY, TREES, ENVIRONMENT
# ============================================================

func _build_markers(parent: Node3D) -> void:
	var points: Dictionary = _marker_points.duplicate()
	var door_names: Dictionary = {
		"JulianasDoor": "JulianasHouse", "SignalTowerDoor": "SignalTower",
		"MaintenanceShedDoor": "MaintenanceShed", "ChurchDoor": "ParishChapel",
		"BotequimDoor": "CornerBotequim", "SophiasDoor": "SophiasHouse",
	}
	for marker_name: String in door_names:
		var info: Dictionary = landmarks.get(door_names[marker_name], {})
		if not info.is_empty():
			points[marker_name] = info["door"]

	if landmarks.has("JulianasHouse"):
		points["PlayerStart"] = (landmarks["JulianasHouse"]["door"] as Vector3) + Vector3(0.0, 0.25, 0.0)

	var stairs: TownLane = _lane_by_id["StoneStaircase"]
	points["StoneStaircaseTop"] = stairs.points[0]
	points["StoneStaircaseBottom"] = stairs.points[stairs.points.size() - 1]
	points["MaintenanceShed"] = points.get("MaintenanceShedDoor", Vector3.ZERO)

	for marker_name: String in points:
		var marker: Marker3D = Marker3D.new()
		marker.name = marker_name
		marker.position = points[marker_name]
		parent.add_child(marker)
		markers[marker_name] = marker


func _raster_cell(x: float, z: float) -> int:
	var gx: int = int(floor((x - RASTER_X0) / RASTER_CELL))
	var gz: int = int(floor((z - RASTER_Z0) / RASTER_CELL))
	if gx < 0 or gz < 0 or gx >= _raster_w or gz >= _raster_h:
		return -1

	return gz * _raster_w + gx


## Marks the cells within `radius` of (cx, cz). `clip` is an optional line (x, z, normal x,
## normal z): cells on the normal's side of it are left out (the end of a dead-end lane).
func _stamp_disc(grid: PackedByteArray, cx: float, cz: float, radius: float, clip: Vector4 = Vector4.ZERO) -> void:
	var gx0: int = maxi(int(floor((cx - radius - RASTER_X0) / RASTER_CELL)), 0)
	var gx1: int = mini(int(ceil((cx + radius - RASTER_X0) / RASTER_CELL)), _raster_w - 1)
	var gz0: int = maxi(int(floor((cz - radius - RASTER_Z0) / RASTER_CELL)), 0)
	var gz1: int = mini(int(ceil((cz + radius - RASTER_Z0) / RASTER_CELL)), _raster_h - 1)
	var limit: float = radius * radius
	var clipped: bool = clip != Vector4.ZERO
	for gz: int in range(gz0, gz1 + 1):
		var dz: float = RASTER_Z0 + (float(gz) + 0.5) * RASTER_CELL - cz
		for gx: int in range(gx0, gx1 + 1):
			var dx: float = RASTER_X0 + (float(gx) + 0.5) * RASTER_CELL - cx
			if dx * dx + dz * dz > limit:
				continue

			if clipped:
				var px: float = RASTER_X0 + (float(gx) + 0.5) * RASTER_CELL
				var pz: float = RASTER_Z0 + (float(gz) + 0.5) * RASTER_CELL
				if (px - clip.x) * clip.z + (pz - clip.y) * clip.w > 0.0:
					continue

			grid[gz * _raster_w + gx] = 1


## Closes everything that is not meant to be walked. The playable area is the union of the
## lanes (with their sidewalks), plazas and yards; houses and walls are solid; wherever a
## playable cell touches a cell that is neither playable nor solid, an invisible wall
## stands on the border (so a gap between houses, an open corner, the end of a lane cannot
## be walked out of).
func _build_boundary(parent: Node3D) -> void:
	_raster_w = int(ceil((RASTER_X1 - RASTER_X0) / RASTER_CELL))
	_raster_h = int(ceil((RASTER_Z1 - RASTER_Z0) / RASTER_CELL))
	_allowed.resize(_raster_w * _raster_h)
	_solid.resize(_raster_w * _raster_h)

	for lane: TownLane in _lanes:
		if lane.kind == TownLane.Kind.TRACK:
			continue

		var radius: float = lane.corridor_half() + 0.35
		# A dead end stops at its cap wall (the wall's own thickness stays solid).
		var last: int = lane.points.size() - 1
		var start_clip: Vector4 = Vector4.ZERO
		var end_clip: Vector4 = Vector4.ZERO
		if lane.capped_start:
			start_clip = Vector4(lane.points[0].x, lane.points[0].z, -lane.tangents[0].x, -lane.tangents[0].y)

		if lane.capped_end:
			end_clip = Vector4(lane.points[last].x, lane.points[last].z, lane.tangents[last].x, lane.tangents[last].y)

		for i: int in lane.points.size():
			var point: Vector3 = lane.points[i]
			var clip: Vector4 = Vector4.ZERO
			if lane.capped_start and lane.distances[i] < radius:
				clip = start_clip
			elif lane.capped_end and lane.length() - lane.distances[i] < radius:
				clip = end_clip

			_stamp_disc(_allowed, point.x, point.z, radius, clip)

	for area: Dictionary in _areas:
		var rect: Rect2 = (area["rect"] as Rect2).grow(0.35)
		var gx0: int = maxi(int(floor((rect.position.x - RASTER_X0) / RASTER_CELL)), 0)
		var gx1: int = mini(int(ceil((rect.end.x - RASTER_X0) / RASTER_CELL)), _raster_w - 1)
		var gz0: int = maxi(int(floor((rect.position.y - RASTER_Z0) / RASTER_CELL)), 0)
		var gz1: int = mini(int(ceil((rect.end.y - RASTER_Z0) / RASTER_CELL)), _raster_h - 1)
		for gz: int in range(gz0, gz1 + 1):
			for gx: int in range(gx0, gx1 + 1):
				_allowed[gz * _raster_w + gx] = 1

	for solid: Dictionary in _solids:
		var centre: Vector2 = solid["c"]
		var half: Vector2 = solid["h"]
		var reach: float = half.length() + 0.1
		var gx0: int = maxi(int(floor((centre.x - reach - RASTER_X0) / RASTER_CELL)), 0)
		var gx1: int = mini(int(ceil((centre.x + reach - RASTER_X0) / RASTER_CELL)), _raster_w - 1)
		var gz0: int = maxi(int(floor((centre.y - reach - RASTER_Z0) / RASTER_CELL)), 0)
		var gz1: int = mini(int(ceil((centre.y + reach - RASTER_Z0) / RASTER_CELL)), _raster_h - 1)
		for gz: int in range(gz0, gz1 + 1):
			for gx: int in range(gx0, gx1 + 1):
				var p: Vector2 = Vector2(RASTER_X0 + (float(gx) + 0.5) * RASTER_CELL, RASTER_Z0 + (float(gz) + 0.5) * RASTER_CELL)
				if _footprint_has(solid, p, 0.0):
					_solid[gz * _raster_w + gx] = 1

	# The faces of the invisible wall: two triangles per border edge.
	var faces: PackedVector3Array = PackedVector3Array()
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	var neighbours: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for gz: int in _raster_h:
		for gx: int in _raster_w:
			var k: int = gz * _raster_w + gx
			if _allowed[k] == 0 or _solid[k] == 1:
				continue

			var x0: float = RASTER_X0 + float(gx) * RASTER_CELL
			var z0: float = RASTER_Z0 + float(gz) * RASTER_CELL
			low = Vector2(minf(low.x, x0), minf(low.y, z0))
			high = Vector2(maxf(high.x, x0 + RASTER_CELL), maxf(high.y, z0 + RASTER_CELL))
			for neighbour: Vector2i in neighbours:
				var nx: int = gx + neighbour.x
				var nz: int = gz + neighbour.y
				var open: bool = nx < 0 or nz < 0 or nx >= _raster_w or nz >= _raster_h
				if not open:
					var nk: int = nz * _raster_w + nx
					open = _allowed[nk] == 0 and _solid[nk] == 0

				if not open:
					continue

				var ground: float = _ground_height(x0 + RASTER_CELL * 0.5, z0 + RASTER_CELL * 0.5)
				var y0: float = ground - 2.0
				var y1: float = ground + 4.5
				var a: Vector3
				var b: Vector3
				if neighbour.x != 0:
					var edge_x: float = x0 if neighbour.x < 0 else x0 + RASTER_CELL
					a = Vector3(edge_x, y0, z0)
					b = Vector3(edge_x, y0, z0 + RASTER_CELL)
				else:
					var edge_z: float = z0 if neighbour.y < 0 else z0 + RASTER_CELL
					a = Vector3(x0, y0, edge_z)
					b = Vector3(x0 + RASTER_CELL, y0, edge_z)

				var up: Vector3 = Vector3(0.0, y1 - y0, 0.0)
				faces.append_array(PackedVector3Array([a, b, b + up, a, b + up, a + up]))

	playable_bounds = Rect2(low, high - low)
	if vista_mode:
		return

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "MapBoundary"
	parent.add_child(body)
	if not faces.is_empty():
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "BorderWall"
		var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		concave.set_faces(faces)
		concave.backface_collision = true
		shape.shape = concave
		body.add_child(shape)

	# A last ring of walls round the terrain, in case anything gets out.
	var ring: Array[Array] = [
		[Vector3(0.0, 15.0, TERRAIN_Z0 - 1.0), Vector3(TERRAIN_X1 - TERRAIN_X0 + 4.0, 60.0, 2.0)],
		[Vector3(0.0, 15.0, TERRAIN_Z1 + 1.0), Vector3(TERRAIN_X1 - TERRAIN_X0 + 4.0, 60.0, 2.0)],
		[Vector3(TERRAIN_X0 - 1.0, 15.0, 0.0), Vector3(2.0, 60.0, TERRAIN_Z1 - TERRAIN_Z0 + 4.0)],
		[Vector3(TERRAIN_X1 + 1.0, 15.0, 0.0), Vector3(2.0, 60.0, TERRAIN_Z1 - TERRAIN_Z0 + 4.0)],
	]
	var ring_index: int = 0
	for wall: Array in ring:
		var ring_shape: CollisionShape3D = CollisionShape3D.new()
		ring_shape.name = "OuterWall%d" % ring_index
		var box: BoxShape3D = BoxShape3D.new()
		box.size = wall[1]
		ring_shape.shape = box
		ring_shape.position = wall[0]
		body.add_child(ring_shape)
		ring_index += 1

	if show_boundary_debug and not faces.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = faces
		var debug_mesh: ArrayMesh = ArrayMesh.new()
		debug_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var debug_material: StandardMaterial3D = StandardMaterial3D.new()
		debug_material.albedo_color = Color(1.0, 0.1, 0.1, 0.3)
		debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var debug: MeshInstance3D = MeshInstance3D.new()
		debug.name = "BorderWallDebug"
		debug.mesh = debug_mesh
		debug.material_override = debug_material
		body.add_child(debug)


## Conifers on the hills round the town (decoration only), as two MultiMeshes.
func _build_hill_trees(parent: Node3D) -> void:
	var group: Node3D = _group(parent, "HillForest")
	var spots: Array[Vector3] = []
	for attempt: int in 1100:
		var x: float = _rng.randf_range(TERRAIN_X0 + 2.0, TERRAIN_X1 - 2.0)
		var z: float = _rng.randf_range(TERRAIN_Z0 + 2.0, TERRAIN_Z1 - 2.0)
		var cell: int = _raster_cell(x, z)
		if cell >= 0:
			var near_playable: bool = false
			for dz: int in range(-14, 15, 7):
				for dx: int in range(-14, 15, 7):
					var other: int = _raster_cell(x + float(dx) * RASTER_CELL, z + float(dz) * RASTER_CELL)
					if other >= 0 and (_allowed[other] == 1 or _solid[other] == 1):
						near_playable = true

			if near_playable:
				continue

		if _clearance_at(Vector2(x, z), null) < 7.0:
			continue

		var blocked: bool = false
		for solid: Dictionary in _solids:
			if (solid["c"] as Vector2).distance_to(Vector2(x, z)) < 16.0 and _footprint_has(solid, Vector2(x, z), 2.0):
				blocked = true
				break

		if build_scenery and _scenery.occupied_by_scenery(x, z):
			blocked = true

		if blocked:
			continue

		spots.append(Vector3(x, _ground_height(x, z), z))

	if spots.is_empty():
		return

	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 3.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var canopy_mesh: SphereMesh = SphereMesh.new()
	canopy_mesh.radius = 2.4
	canopy_mesh.height = 4.0
	canopy_mesh.radial_segments = 7
	canopy_mesh.rings = 3
	var trunks: MultiMesh = MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = spots.size()
	var canopies: MultiMesh = MultiMesh.new()
	canopies.transform_format = MultiMesh.TRANSFORM_3D
	canopies.mesh = canopy_mesh
	canopies.instance_count = spots.size()
	for i: int in spots.size():
		var tree_scale: float = _rng.randf_range(0.8, 1.5)
		var tree_basis: Basis = Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(tree_scale, tree_scale, tree_scale))
		trunks.set_instance_transform(i, Transform3D(tree_basis, spots[i] + Vector3(0.0, 1.5 * tree_scale, 0.0)))
		canopies.set_instance_transform(i, Transform3D(tree_basis, spots[i] + Vector3(0.0, 4.6 * tree_scale, 0.0)))

	_tree_count += spots.size()

	var trunk_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	trunk_instance.name = "HillTrunks"
	trunk_instance.multimesh = trunks
	trunk_instance.material_override = _mat(TRUNK)
	group.add_child(trunk_instance)
	var canopy_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	canopy_instance.name = "HillCanopies"
	canopy_instance.multimesh = canopies
	canopy_instance.material_override = _mat(FOREST)
	group.add_child(canopy_instance)


## Night, fog and moonlight: depth fog clear to `fog_start_meters` and a wall at
## `fog_end_meters`, plus volumetric fog for the lamps to glow in.
func _build_environment(parent: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = FOG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.4, 0.5)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	environment.fog_enabled = fog_enabled
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = FOG_COLOR
	environment.fog_density = 1.0
	environment.fog_depth_begin = fog_start_meters
	environment.fog_depth_end = fog_end_meters
	environment.fog_depth_curve = 1.0
	environment.fog_sky_affect = 1.0

	environment.volumetric_fog_enabled = fog_enabled
	environment.volumetric_fog_density = 0.012
	environment.volumetric_fog_albedo = Color(0.7, 0.78, 0.9)
	environment.volumetric_fog_length = 48.0
	environment.volumetric_fog_emission = FOG_COLOR
	environment.volumetric_fog_emission_energy = 0.1

	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	parent.add_child(world)

	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-52.0, 32.0, 0.0)
	parent.add_child(moon)


## A dim warm light at the lamp poles, so the lanes read in the dark.
func _build_street_lamps(parent: Node3D) -> void:
	var index: int = 0
	for point: Vector3 in _lamp_points:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Lamp%02d" % index
		light.position = point
		light.light_color = Color(1.0, 0.82, 0.55)
		light.light_energy = 1.6
		light.omni_range = 11.0
		light.shadow_enabled = false
		parent.add_child(light)
		index += 1
