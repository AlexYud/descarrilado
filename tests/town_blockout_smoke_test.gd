extends Node

## The town blockout: its structure and points of interest, the ground heights, a guided
## walk of the whole route along the lanes (stairs, footbridge, switchback, yards) without
## getting stuck, that the walk is short, and that the player cannot leave the playable
## area: a flood fill with real physics queries from the start must stay inside the lanes,
## plazas and yards. Run it as a scene; it quits by itself with a non-zero exit code on
## failure.

const SCENE_PATH: String = "res://scenes/levels/town_blockout_playtest.tscn"
const TIME_SCALE: float = 3.0
const FILL_CELL: float = 0.5
const FILL_LIMIT: int = 70000

var test_failed: bool = false
var level: Node = null
var town: TownBlockout = null
var player: CharacterBody3D = null
var route_length: float = 0.0


func _ready() -> void:
	level = (load(SCENE_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	town = level.get_node("TownBlockout")
	player = level.get_node("Player")

	_check_structure()
	_check_points_of_interest()
	_check_environment()
	_check_scenery()
	await _check_ground_heights()
	await _check_boundary()

	Engine.time_scale = TIME_SCALE
	await _check_route()
	Engine.time_scale = 1.0

	print("largest physics delta ", _max_delta)
	print("TOWN_BLOCKOUT_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


func _root() -> Node3D:
	return town.get_node("MapRoot")


func _find(path: String) -> Node:
	return _root().get_node_or_null(path)


func _check_structure() -> void:
	var map_root: Node3D = _root()
	for zone: String in ["UpperTown", "CentralRailway", "LowerTown", "Terrain", "Environment", "Markers", "MapBoundary", "HillForest"]:
		_expect(map_root.get_node_or_null(zone) != null, "MapRoot/%s exists" % zone)

	var houses: int = map_root.find_children("*", "CSGBox3D", true, false).filter(
		func(node: Node) -> bool: return node.name == "Body" and node.get_parent().has_node("Roof")
	).size()
	_expect(houses >= 80, "the town is packed with houses (%d)" % houses)
	_expect(town._tree_count >= 100, "with a forest of trees (%d)" % town._tree_count)

	var csg: Array[Node] = map_root.find_children("*", "CSGShape3D", true, false)
	var colliding: int = 0
	for node: Node in csg:
		if (node as CSGShape3D).use_collision:
			colliding += 1

	_expect(csg.size() > 100 and colliding > 100, "built from CSG with collision (%d shapes, %d of them solid)" % [csg.size(), colliding])

	# The lanes are narrow and wind: none is a straight line (its heading swings by at least
	# 12 degrees, and the street lanes of the cutting follow the curving track).
	var winding: int = 0
	var swings: Array[String] = []
	for lane_id: String in ["RuaAlta", "RuaPrincipal", "RuaDaEstacao", "RuaDaLinha", "RuaOeste"]:
		var lane: TownLane = town._lane_by_id[lane_id]
		var low: float = INF
		var high: float = -INF
		var reference: float = atan2(lane.tangents[0].y, lane.tangents[0].x)
		for tangent: Vector2 in lane.tangents:
			var heading: float = angle_difference(reference, atan2(tangent.y, tangent.x))
			low = minf(low, heading)
			high = maxf(high, heading)

		var swing: float = rad_to_deg(high - low)
		swings.append("%s %.0f" % [lane_id, swing])
		if swing >= 12.0:
			winding += 1

	_expect(winding >= 5, "the lanes wind: heading swings in degrees %s" % [swings])

	for lane_id: String in town.get_lane_ids():
		var lane: TownLane = town._lane_by_id[lane_id]
		if lane.kind == TownLane.Kind.COBBLE:
			_expect(lane.half_width * 2.0 <= 3.5, "%s is a narrow lane (%.1f m of cobbles)" % [lane_id, lane.half_width * 2.0])


func _check_points_of_interest() -> void:
	var expected: Dictionary = {
		"UpperTown/Houses/JulianasHouseLot/JulianasHouse": "Juliana's house",
		"UpperTown/ChurchAndCemetery/ChapelLot/ParishChapel": "the chapel",
		"UpperTown/ChurchAndCemetery/ChapelLot/BellTower": "its bell tower",
		"UpperTown/ChurchAndCemetery/CemeteryWallNorth0": "the cemetery wall",
		"UpperTown/Streets/StoneStaircase/Steps": "the stone staircase",
		"UpperTown/Streets/RuaAlta/Road": "Rua Alta and the switchback road",
		"CentralRailway/Footbridge/BridgeDeck": "the footbridge",
		"CentralRailway/Footbridge/BridgeRoof": "covered",
		"CentralRailway/SignalTower/SignalTowerLot/SignalTower": "the signal tower",
		"CentralRailway/Track/MainLineBallast": "the railway line",
		"CentralRailway/Track/AbandonedCar1": "the abandoned train cars",
		"CentralRailway/MaintenanceYard/ShedLot/MaintenanceShed": "the maintenance shed",
		"CentralRailway/MaintenanceYard/TimberYardFence0": "the timber yard",
		"LowerTown/CornerBotequim/BotequimLot/CornerBotequim": "the botequim",
		"LowerTown/CornerBotequim/BotequimLot/Orelhao": "its Orelhao",
		"LowerTown/SophiasHouse/SophiasHouseLot/SophiasHouse": "Sophia's house",
		"LowerTown/SophiasHouse/YardFenceBack0": "with its wide yard",
		"LowerTown/ForestTrailhead/TrailGatePostWest": "the forest trailhead",
	}
	for path: String in expected:
		_expect(_find(path) != null, "%s is there" % expected[path])

	for landmark: String in ["PlayerStart", "JulianasDoor", "OrelhaoSpot", "SophiasDoor", "TrailheadGate", "SignalTowerDoor", "ChurchDoor", "FootbridgeMiddle", "StoneStaircaseTop", "BotequimDoor", "MaintenanceShed", "CemeteryGate"]:
		_expect(town.markers.has(landmark), "marker %s" % landmark)

	# Key buildings are red, ordinary houses beige (or green timber).
	var juliana: Node = _find("UpperTown/Houses/JulianasHouseLot/JulianasHouse/Body")
	_expect(((juliana as CSGBox3D).material as StandardMaterial3D).albedo_color == TownBlockout.KEY_RED, "key buildings are red")
	var generic: Node3D = null
	for node: Node in _root().find_children("House*", "Node3D", true, false):
		if node.has_meta("generic"):
			generic = node as Node3D
			break

	_expect(generic != null, "there are ordinary houses")
	if generic != null:
		var colour: Color = ((generic.get_node("Body") as CSGBox3D).material as StandardMaterial3D).albedo_color
		_expect(TownBlockout.BEIGES.has(colour) or TownBlockout.TIMBERS.has(colour), "and they are beige or green timber")

	# The playable area is compact.
	var bounds: Rect2 = town.playable_bounds
	_expect(bounds.size.x <= 112.0 and bounds.size.y <= 146.0, "the playable area is compact (%.0f m x %.0f m)" % [bounds.size.x, bounds.size.y])


func _check_environment() -> void:
	var world: WorldEnvironment = _root().get_node("Environment/WorldEnvironment")
	var environment: Environment = world.environment
	_expect(not environment.fog_enabled and not environment.volumetric_fog_enabled, "there is no fog (it is off by default)")
	_expect(not town.fog_enabled, "the `fog_enabled` export is off")


## The town round the playable core (scenery): its places, its size, that it never blocks
## anything, and that its ground meets the core's without a seam.
func _check_scenery() -> void:
	var outer: Node = _root().get_node_or_null("OuterTown")
	_expect(outer != null, "MapRoot/OuterTown (the scenery) exists")
	if outer == null:
		return

	for part: String in ["Ground", "Serra", "River", "Landmarks", "ForestCrowns"]:
		_expect(outer.get_node_or_null(part) != null, "the scenery has its %s" % part)

	var scenery: TownScenery = town._scenery
	for place: String in ["IgrejaMatriz", "Coreto", "Estacao", "Armazem", "CaixaDaguaFerroviaria", "CampoDeFutebol", "Escola", "Cemiterio", "Cruzeiro", "Antena", "CaixaDaguaMunicipal", "PostoDeGasolina", "RailBridge", "RoadBridgeAvenidaDaPonte"]:
		_expect(scenery.landmarks.has(place), "the town has its %s" % place)

	_expect(scenery.house_count >= 200, "the rest of the town has many houses (%d)" % scenery.house_count)
	_expect(scenery.tree_count >= 5000, "and forest all round (%d trees)" % scenery.tree_count)
	_expect(outer.find_children("*", "CollisionShape3D", true, false).is_empty(), "the scenery has no collision (it is only to be seen)")

	var worst: float = 0.0
	for i: int in 41:
		var t: float = float(i) / 40.0
		var x: float = lerpf(TownBlockout.TERRAIN_X0, TownBlockout.TERRAIN_X1, t)
		var z: float = lerpf(TownBlockout.TERRAIN_Z0, TownBlockout.TERRAIN_Z1, t)
		for edge: Vector2 in [Vector2(x, TownBlockout.TERRAIN_Z0), Vector2(x, TownBlockout.TERRAIN_Z1), Vector2(TownBlockout.TERRAIN_X0, z), Vector2(TownBlockout.TERRAIN_X1, z)]:
			worst = maxf(worst, absf(town.ground_height(edge.x, edge.y) - scenery.natural_height(edge.x, edge.y)))

	_expect(worst < 0.05, "the core's ground meets the scenery's without a seam (worst %.3f m)" % worst)


## The ground under each level and landmark, found with a ray from above.
func _ground_at(x: float, z: float, from_y: float = 60.0) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -20.0, z))
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit["position"].y) if not hit.is_empty() else -999.0


func _check_ground_heights() -> void:
	await get_tree().physics_frame
	var checks: Array = [
		["the start, in front of Juliana's house", town.get_marker_position("JulianasDoor"), 7.2],
		["the top of the stone staircase", town.get_marker_position("StoneStaircaseTop"), 7.3],
		["the foot of the stone staircase", town.get_marker_position("StoneStaircaseBottom"), 0.4],
		["the church plaza", town.get_marker_position("ChurchDoor"), 11.2],
		["the cemetery gate", town.get_marker_position("CemeteryGate"), 11.2],
		["the station street", town.get_marker_position("SignalTowerDoor"), 0.4],
		["the maintenance yard", town.get_marker_position("MaintenanceShed"), -0.2],
		["the corner botequim's sidewalk", town.get_marker_position("OrelhaoSpot"), -1.6],
		["Sophia's yard", town.get_marker_position("SophiasDoor"), -2.75],
		["the forest trailhead", town.get_marker_position("TrailheadGate"), -3.3],
	]
	for check: Array in checks:
		var point: Vector3 = check[1]
		var height: float = _ground_at(point.x, point.z, point.y + 3.0)
		_expect(absf(height - float(check[2])) < 0.6, "%s is at y %.1f (%.2f)" % [check[0], check[2], height])

	# The footbridge deck is a real bridge: the deck above, the track below.
	var bridge: Vector3 = town.get_marker_position("FootbridgeMiddle")
	_expect(absf(_ground_at(bridge.x, bridge.z, 20.0) - 4.2) < 0.4, "the footbridge deck is 4 m up")
	_expect(_ground_at(bridge.x + 4.0, bridge.z, 20.0) < 1.0, "and the line runs under it")


## From the start, a flood fill over 0.5 m cells with real ground and capsule queries: all
## it can reach is lanes, plazas and yards, and it reaches every point of interest.
func _check_boundary() -> void:
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 0.9
	var start: Vector3 = town.get_marker_position("PlayerStart")
	var ground_start: float = _ground_at(start.x, start.z, start.y + 1.0)
	var visited: Dictionary = {}
	var queue: Array[Vector3] = [Vector3(start.x, ground_start, start.z)]
	visited[Vector3i(roundi(start.x / FILL_CELL), roundi(start.z / FILL_CELL), roundi(ground_start))] = Vector3(start.x, ground_start, start.z)
	var cursor: int = 0
	var leaked: bool = false
	while cursor < queue.size():
		var here: Vector3 = queue[cursor]
		cursor += 1
		for step: Vector2 in [Vector2(FILL_CELL, 0.0), Vector2(-FILL_CELL, 0.0), Vector2(0.0, FILL_CELL), Vector2(0.0, -FILL_CELL)]:
			var nx: float = here.x + step.x
			var nz: float = here.z + step.y
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(nx, here.y + 0.6, nz), Vector3(nx, here.y - 0.8, nz))
			ray.exclude = [player.get_rid()]
			var hit: Dictionary = space.intersect_ray(ray)
			if hit.is_empty():
				continue

			var ny: float = float(hit["position"].y)
			if absf(ny - here.y) > 0.45 or float(hit["normal"].y) < 0.55:
				continue

			var key: Vector3i = Vector3i(roundi(nx / FILL_CELL), roundi(nz / FILL_CELL), roundi(ny))
			if visited.has(key):
				continue

			# Nothing stands between the two cells (a wall thinner than a cell).
			var blocked: bool = false
			for height: float in [0.3, 0.9]:
				var base: float = maxf(here.y, ny) + height
				var across: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
					Vector3(here.x, base, here.z),
					Vector3(nx + signf(step.x) * 0.2, base, nz + signf(step.y) * 0.2)
				)
				across.exclude = [player.get_rid()]
				if not space.intersect_ray(across).is_empty():
					blocked = true
					break

			if blocked:
				continue

			var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			shape_query.shape = capsule
			shape_query.transform = Transform3D(Basis.IDENTITY, Vector3(nx, ny + 0.16 + 0.45, nz))
			shape_query.exclude = [player.get_rid()]
			if not space.intersect_shape(shape_query, 1).is_empty():
				continue

			var spot: Vector3 = Vector3(nx, ny, nz)
			visited[key] = spot
			queue.append(spot)
			if queue.size() > FILL_LIMIT:
				leaked = true
				break

		if leaked:
			break

	_expect(not leaked, "the player cannot get out: %d cells are reachable (limit %d)" % [queue.size(), FILL_LIMIT])
	_dump_reach(queue)

	var outside: int = 0
	var first_outside: Vector3 = Vector3.ZERO
	for spot: Vector3 in queue:
		var inside: bool = false
		for dx: float in [-0.6, 0.0, 0.6]:
			for dz: float in [-0.6, 0.0, 0.6]:
				if town.is_playable(Vector3(spot.x + dx, spot.y, spot.z + dz)):
					inside = true

		if not inside:
			outside += 1
			if first_outside == Vector3.ZERO:
				first_outside = spot

	_expect(outside == 0, "every reachable cell is inside the playable area (%d outside, first %s)" % [outside, first_outside])

	var unreachable: Array[String] = []
	for landmark: String in ["JulianasDoor", "ChurchDoor", "CemeteryGate", "StoneStaircaseTop", "StoneStaircaseBottom", "FootbridgeMiddle", "SignalTowerDoor", "MaintenanceShed", "BotequimDoor", "OrelhaoSpot", "SophiasDoor", "TrailheadGate", "ForestEdge"]:
		var point: Vector3 = town.get_marker_position(landmark)
		var found: bool = false
		for spot: Vector3 in queue:
			if Vector2(spot.x - point.x, spot.z - point.z).length() < 1.0 and absf(spot.y - point.y) < 1.2:
				found = true
				break

		if not found:
			unreachable.append(landmark)

	_expect(unreachable.is_empty(), "the flood fill reaches every point of interest (missing: %s)" % [unreachable])


## With `-- dump=<path.png>` on the command line: a picture of the flood fill (white = the
## player can stand there, red = a landmark), 2 pixels per cell, for finding leaks.
func _dump_reach(cells: Array[Vector3]) -> void:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("dump="):
			path = argument.substr(5)

	if path.is_empty():
		return

	var x0: float = TownBlockout.RASTER_X0
	var z0: float = TownBlockout.RASTER_Z0
	var width: int = int((TownBlockout.RASTER_X1 - x0) / FILL_CELL) * 2
	var height: int = int((TownBlockout.RASTER_Z1 - z0) / FILL_CELL) * 2
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color(0.05, 0.05, 0.08))
	for spot: Vector3 in cells:
		var px: int = int((spot.x - x0) / FILL_CELL) * 2
		var py: int = int((spot.z - z0) / FILL_CELL) * 2
		for dx: int in 2:
			for dy: int in 2:
				image.set_pixel(clampi(px + dx, 0, width - 1), clampi(py + dy, 0, height - 1), Color(0.9, 0.9, 0.9))

	for marker: String in town.markers:
		var point: Vector3 = town.get_marker_position(marker)
		var mx: int = int((point.x - x0) / FILL_CELL) * 2
		var my: int = int((point.z - z0) / FILL_CELL) * 2
		for dx: int in range(-2, 3):
			for dy: int in range(-2, 3):
				image.set_pixel(clampi(mx + dx, 0, width - 1), clampi(my + dy, 0, height - 1), Color(1.0, 0.1, 0.1))

	image.save_png(path)


func _lane_route(lane_id: String, from_s: float, to_s: float, step: float = 4.0) -> Array[Vector3]:
	var lane: TownLane = town._lane_by_id[lane_id]
	var points: Array[Vector3] = []
	var direction: float = 1.0 if to_s >= from_s else -1.0
	var s: float = from_s
	while (to_s - s) * direction > 0.01:
		s += step * direction
		if (to_s - s) * direction < 0.0:
			s = to_s

		points.append(lane.point_at(s))

	return points


func _lane_s(lane_id: String, x: float, z: float) -> float:
	return (town._lane_by_id[lane_id] as TownLane).closest_s(Vector2(x, z))


## Walks the player along the lanes through every point of interest, in the order the story
## visits them (with a few side trips), and adds up the distance.
func _check_route() -> void:
	var movement: Node = player.get("movement_controller") as Node
	var route: Array = []

	var door: Vector3 = town.get_marker_position("JulianasDoor")
	var upper: TownLane = town._lane_by_id["RuaAlta"]
	var start_s: float = upper.closest_s(Vector2(door.x, door.z))
	var stair_top: Vector3 = town.get_marker_position("StoneStaircaseTop")
	var stair_s: float = upper.closest_s(Vector2(stair_top.x, stair_top.z))

	# 1. Juliana's house -> Rua Alta -> the lane up to the church -> the church door -> the
	#    cemetery gate.
	var church_s: float = _lane_s("RuaAlta", -1.0, -32.4)
	route.append(["along Rua Alta to the church lane", _lane_route("RuaAlta", start_s, church_s)])
	route.append(["up the lane to the church plaza", _lane_route("TravessaDaIgreja", 0.0, (town._lane_by_id["TravessaDaIgreja"] as TownLane).length())])
	route.append(["to the chapel door", [town.get_marker_position("ChurchDoor")]])
	route.append(["to the cemetery gate", [town.get_marker_position("CemeteryGate")]])
	route.append(["and back to the plaza", [town.get_marker_position("ChurchDoor")]])
	var travessa: TownLane = town._lane_by_id["TravessaDaIgreja"]
	route.append(["down the church lane", _lane_route("TravessaDaIgreja", travessa.length(), 0.0)])
	route.append(["back along Rua Alta to the staircase", _lane_route("RuaAlta", church_s, stair_s)])

	# 2. Down the staircase to Rua da Estacao, to the signal tower, back to the footbridge.
	var stairs: TownLane = town._lane_by_id["StoneStaircase"]
	route.append(["down the stone staircase", [stairs.points[0] + Vector3(0.0, 0.0, 1.0), stairs.points[stairs.points.size() / 2], stairs.points[stairs.points.size() - 1]]])
	var bottom: Vector3 = stairs.points[stairs.points.size() - 1]
	var station_s: float = _lane_s("RuaDaEstacao", bottom.x, bottom.z)
	var tower_door: Vector3 = town.get_marker_position("SignalTowerDoor")
	var tower_s: float = _lane_s("RuaDaEstacao", tower_door.x, tower_door.z)
	route.append(["along Rua da Estacao to the signal tower", _lane_route("RuaDaEstacao", station_s, tower_s)])
	route.append(["to the tower door", [tower_door]])
	var bridge_foot: Vector3 = town.get_marker_position("FootbridgeNorthFoot")
	route.append(["back to the footbridge", _lane_route("RuaDaEstacao", tower_s, _lane_s("RuaDaEstacao", bridge_foot.x, bridge_foot.z))])

	# 3. Over the footbridge to Rua da Linha, to the maintenance yard and back.
	var bridge_mid: Vector3 = town.get_marker_position("FootbridgeMiddle")
	var south_foot: Vector3 = town.get_marker_position("FootbridgeSouthFoot")
	route.append(["up the footbridge steps", [bridge_foot, bridge_mid]])
	route.append(["over the covered footbridge and down", [south_foot]])
	var line_s: float = _lane_s("RuaDaLinha", south_foot.x, south_foot.z)
	var shed_drive: TownLane = town._lane_by_id["ShedDrive"]
	var shed_junction: float = _lane_s("RuaDaLinha", shed_drive.points[0].x, shed_drive.points[0].z)
	route.append(["along Rua da Linha to the maintenance yard", _lane_route("RuaDaLinha", line_s, shed_junction)])
	route.append(["into the yard", _lane_route("ShedDrive", 0.0, shed_drive.length())])
	route.append(["to the shed door", [town.get_marker_position("MaintenanceShed")]])
	route.append(["back out to the street", _lane_route("ShedDrive", shed_drive.length(), 0.0)])

	# 4. The main street: the botequim and its Orelhao, Sophia's yard, the forest.
	var main_street: TownLane = town._lane_by_id["RuaPrincipal"]
	var main_junction: float = _lane_s("RuaDaLinha", main_street.points[0].x, main_street.points[0].z)
	route.append(["back along Rua da Linha to the main street", _lane_route("RuaDaLinha", shed_junction, main_junction)])
	var botequim: Vector3 = town.get_marker_position("BotequimDoor")
	var botequim_s: float = main_street.closest_s(Vector2(botequim.x, botequim.z))
	route.append(["down the main street to the botequim", _lane_route("RuaPrincipal", 0.0, botequim_s)])
	route.append(["to the Orelhao", [town.get_marker_position("OrelhaoSpot")]])
	var drive: TownLane = town._lane_by_id["SophiasDrive"]
	var drive_s: float = main_street.closest_s(Vector2(drive.points[0].x, drive.points[0].z))
	route.append(["on to Sophia's drive", _lane_route("RuaPrincipal", botequim_s, drive_s)])
	route.append(["into Sophia's yard", _lane_route("SophiasDrive", 0.0, drive.length())])
	route.append(["to Sophia's door", [town.get_marker_position("SophiasDoor")]])
	route.append(["back to the drive", [drive.points[drive.points.size() - 1]]])
	route.append(["and out to the main street", _lane_route("SophiasDrive", drive.length(), 0.0)])
	route.append(["down to the forest trailhead", _lane_route("RuaPrincipal", drive_s, main_street.length())])
	var trail: TownLane = town._lane_by_id["ForestTrail"]
	route.append(["into the forest", _lane_route("ForestTrail", 0.0, trail.length() - 1.0)])

	player.global_position = town.get_marker_position("PlayerStart") + Vector3(0.0, 0.3, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(absf(player.global_position.y - 7.5) < 1.2, "the player starts on the upper street")

	var previous: Vector3 = player.global_position
	var leg_length: float = 0.0
	var all_reached: bool = true
	for leg: Array in route:
		var legs_start: Vector3 = previous
		print("walking ", leg[0], " (", (leg[1] as Array).size(), " stops)")
		for target: Vector3 in leg[1]:
			if not (is_finite(target.x) and is_finite(target.y) and is_finite(target.z)):
				_expect(false, "the route point is not finite (%s) in %s" % [target, leg[0]])
				all_reached = false
				break

			var started: bool = bool(movement.call("begin_guided_walk", target, target + Vector3(0.0, 1.5, 0.0), 3.0, 90.0))
			var reached: bool = false
			if started:
				reached = bool(await movement.guided_walk_finished)

			var flat: float = Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length()
			if not (started and reached and flat < 0.7):
				_expect(false, "walks %s (stopped %.1f m from %s, at %s)" % [leg[0], flat, target, player.global_position])
				all_reached = false
				break

			await get_tree().physics_frame
			leg_length += Vector2(previous.x - target.x, previous.z - target.z).length()
			previous = target

		if not all_reached:
			break

		print("ok   - walked ", leg[0], " (", snappedf(leg_length, 0.1), " m so far)")

	route_length = leg_length
	_expect(all_reached, "walks the whole route")
	# At 1.3 m/s: the whole story route is a few minutes.
	var minutes: float = route_length / 1.3 / 60.0
	_expect(route_length < 700.0, "the whole route is %.0f m: %.1f minutes at the player's walking speed" % [route_length, minutes])


var _last_good: Vector3 = Vector3.ZERO
var _last_good_velocity: Vector3 = Vector3.ZERO
var _last_good_look: Vector2 = Vector2.ZERO
var _max_delta: float = 0.0


## A watchdog: the player's position, velocity and look must never become NaN (a degenerate
## collision face would do that, and the walk would then hang).
func _physics_process(delta: float) -> void:
	_max_delta = maxf(_max_delta, delta)
	if player == null:
		return

	var movement: Node = player.get("movement_controller") as Node
	var look: Vector2 = Vector2(float(movement.get("look_yaw")), float(movement.get("look_pitch")))
	var position: Vector3 = player.global_position
	var bad: bool = is_nan(position.x) or is_nan(position.y) or is_nan(position.z)
	bad = bad or is_nan(player.velocity.x) or is_nan(player.velocity.y) or is_nan(player.velocity.z)
	bad = bad or is_nan(look.x) or is_nan(look.y)
	if bad:
		print("FAIL - the player's state became NaN: position %s velocity %s look %s floor %s (last good: %s %s %s)" % [
			position, player.velocity, look, player.is_on_floor(), _last_good, _last_good_velocity, _last_good_look
		])
		test_failed = true
		get_tree().quit(1)
		return

	_last_good = position
	_last_good_velocity = player.velocity
	_last_good_look = look
