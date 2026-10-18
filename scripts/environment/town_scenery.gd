class_name TownScenery
extends RefCounted

## The rest of the town around the playable core of `TownBlockout`: a small Brazilian railway
## town in the serra, to be seen from its streets and from the dream intro's city overlook,
## not walked (no collision, a few merged meshes). See docs/town_study.md.
##
## The valley runs west to east: the playable old upper town and its rail yard in the middle,
## the line going on east to the station, the warehouse and the railway water tank; the old
## centre (the Matriz, the praça with its bandstand, two-storey shops) between the line and
## the river; the workers' village in straight rows north of the line; the river curving round
## the centre from the north-east to the west, with a road bridge to the south bank (football
## pitch, school) and an iron rail bridge; the periphery climbing the north hill on dirt roads
## (municipal water tower, the cruzeiro on the peak, a radio mast); the road coming in from the
## south-west past a petrol station and the cemetery; farms (pastures, coffee rows, eucalyptus,
## bananas) and Atlantic forest everywhere else.
##
## It also shapes the ground for the whole map: `natural_height` is what the core's terrain
## starts from before its lanes are cut, so the two meshes meet without a seam.

const X0: float = -330.0
const Z0: float = -330.0
const SIZE: float = 660.0
const STEP: float = 2.0
const OCC_CELL: float = 1.0
## The core's own terrain (TownBlockout.TERRAIN_*): the outer mesh leaves a hole there.
const CORE: Rect2 = Rect2(-70.0, -84.0, 140.0, 176.0)
const PRACA_CENTRE: Vector2 = Vector2(125.0, 65.0)

## North (high) to south: the hill above the upper town, the core, the river, the south hills.
const PROFILE_Z: Array[float] = [-330.0, -260.0, -200.0, -150.0, -110.0, -84.0, -72.0, -56.0, -44.0, -34.0, -26.0, -18.0, -11.0, -2.0, 12.0, 26.0, 40.0, 54.0, 64.0, 80.0, 100.0, 125.0, 160.0, 200.0, 260.0, 330.0]
const PROFILE_Y: Array[float] = [78.0, 68.0, 54.0, 38.0, 25.0, 17.0, 14.0, 11.5, 9.5, 7.3, 6.5, 3.2, 0.6, 0.2, -0.2, -1.4, -2.4, -3.2, -3.6, -4.6, -6.0, -7.0, -3.0, 6.0, 24.0, 40.0]

const PAINTS: Array[Color] = [
	Color(0.86, 0.62, 0.62), Color(0.58, 0.7, 0.82), Color(0.9, 0.8, 0.45), Color(0.6, 0.78, 0.6),
	Color(0.92, 0.88, 0.8), Color(0.82, 0.55, 0.35), Color(0.75, 0.68, 0.85), Color(0.95, 0.93, 0.88),
]
const PERIPHERY: Array[Color] = [
	Color(0.58, 0.57, 0.54), Color(0.55, 0.33, 0.24), Color(0.66, 0.64, 0.6), Color(0.7, 0.6, 0.48),
	Color(0.62, 0.7, 0.72),
]
const ROOF_TILE: Color = Color(0.5, 0.25, 0.17)
const ROOF_TILE_OLD: Color = Color(0.36, 0.21, 0.16)
const ROOF_FIBRE: Color = Color(0.52, 0.53, 0.52)
const WHITE: Color = Color(0.93, 0.92, 0.88)
const DARK: Color = Color(0.06, 0.06, 0.07)
const LAMP: Color = Color(1.0, 0.78, 0.48)
## Lit windows are drawn this much bigger than they are: from the overlook (500 m away) a real
## window is under a pixel, so a town of dark boxes would show no lights.
const GLOW_SCALE: float = 2.2
## The valley floor (town-local height) in front of the town, in vista mode.
const VISTA_PLAIN: float = -8.0
## Vista mode lights: this fraction of the windows are lit, and one lane lamp in this many.
const VISTA_LIT_SCALE: float = 0.4
const VISTA_LAMP_EVERY: int = 2

## What the painted ground is (for the Terrain3D textures and the forest).
const KIND_NONE: int = 0
const KIND_DIRT: int = 1
const KIND_STONE: int = 2
const KIND_PASTURE: int = 3
const KIND_COFFEE: int = 4
const KIND_EUCALYPTUS: int = 5
const KIND_BANANA: int = 6
const KIND_CEMETERY: int = 7
const KIND_MUD: int = 8

var town: TownBlockout
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var heights: PackedFloat32Array = PackedFloat32Array()
## Ground colour painted by roads, pads and farms (alpha = how much of it).
var paint: PackedColorArray = PackedColorArray()
var kinds: PackedByteArray = PackedByteArray()
var grid_n: int = 0
var occupancy: PackedByteArray = PackedByteArray()
var occ_n: int = 0
var roads: Array[Dictionary] = []
var river: TownLane
var rail: TownLane
var siding: TownLane
var pads: Array[Dictionary] = []
var farms: Array[Dictionary] = []
var landmarks: Dictionary = {}
var house_count: int = 0
var tree_count: int = 0

var _noise_a: FastNoiseLite = FastNoiseLite.new()
var _noise_b: FastNoiseLite = FastNoiseLite.new()
var _river_y: PackedFloat32Array = PackedFloat32Array()
var _lamps: Array[Vector3] = []
var _builders: Dictionary = {}
var _lit: TownMeshBuilder = TownMeshBuilder.new()
## The glow of every lit window and lamp, seen from far away (vista mode): {"p": Vector3, "s": size (m), "a": strength}.
var _halos: Array[Dictionary] = []
var _lane_lamp_count: int = 0
var _horizon_noise: FastNoiseLite = FastNoiseLite.new()
var _eucalyptus_spots: Array[Transform3D] = []


func _init(owner: TownBlockout) -> void:
	town = owner
	rng.seed = owner.seed_value + 101
	_noise_a.seed = owner.seed_value + 11
	_noise_a.frequency = 0.006
	_noise_a.fractal_octaves = 4
	_noise_b.seed = owner.seed_value + 13
	_noise_b.frequency = 0.03
	_horizon_noise.seed = owner.seed_value + 17
	_horizon_noise.frequency = 0.0022
	_horizon_noise.fractal_octaves = 4


# ============================================================
# THE GROUND
# ============================================================

## Lays out the river, the line, the roads, the pads and the farms, and shapes the ground
## for the whole map. Call it before the core builds its terrain.
func shape() -> void:
	_define()
	grid_n = int(SIZE / STEP) + 1
	heights.resize(grid_n * grid_n)
	paint.resize(grid_n * grid_n)
	kinds.resize(grid_n * grid_n)
	paint.fill(Color(0.0, 0.0, 0.0, 0.0))
	for gz: int in grid_n:
		var z: float = Z0 + float(gz) * STEP
		var row_height: float = _profile(z)
		for gx: int in grid_n:
			var x: float = X0 + float(gx) * STEP
			heights[gz * grid_n + gx] = row_height + _relief(x, z)

	# Seen from the overlook, the ground in front of the town (within ~150 m of it) is the plain
	# of the valley floor: the south hills would stand in front of the town and hide it.
	if town.vista_mode:
		var view: Vector2 = _view_local()
		for gz: int in grid_n:
			for gx: int in grid_n:
				var d: float = view.distance_to(Vector2(X0 + float(gx) * STEP, Z0 + float(gz) * STEP))
				var k: int = gz * grid_n + gx
				heights[k] = lerpf(VISTA_PLAIN, heights[k], smoothstep(120.0, 260.0, d))

	# The line and the roads keep their own smooth grade (taken from the ground before they
	# were cut in); the ground follows them, then the pads are levelled and the river cut.
	_grade(rail, 0.6)
	_stamp_line(rail, 4.0, 6.0, Color(0.32, 0.29, 0.25), 0.9, KIND_DIRT)
	_grade(siding, 0.6)
	for road: Dictionary in roads:
		var lane: TownLane = road["lane"]
		_grade(lane, 8.0)
		_stamp_line(lane, float(road["half"]) + 0.8, 4.0, road["ground"], 1.0, KIND_DIRT if (road["ground"] as Color).r > (road["ground"] as Color).b + 0.1 else KIND_STONE)

	for pad: Dictionary in pads:
		_stamp_pad(pad)

	for farm: Dictionary in farms:
		_paint_farm(farm)

	_cut_river()


func _define() -> void:
	rail = _polyline("SceneryRail", [
		Vector2(51.5, 1.6), Vector2(75.0, 3.0), Vector2(105.0, 5.0), Vector2(135.0, 5.6), Vector2(165.0, 5.2),
		Vector2(195.0, 0.0), Vector2(220.0, -9.0), Vector2(240.0, -20.0), Vector2(265.0, -33.0),
		Vector2(300.0, -48.0), Vector2(334.0, -60.0),
	], 2.0)
	siding = _polyline("ScenerySiding", [Vector2(168.0, 1.0), Vector2(190.0, -3.0), Vector2(208.0, -9.0)], 2.0)
	river = _polyline("River", [
		Vector2(334.0, -118.0), Vector2(300.0, -85.0), Vector2(268.0, -48.0), Vector2(245.0, -22.0),
		Vector2(228.0, 8.0), Vector2(205.0, 45.0), Vector2(172.0, 82.0), Vector2(130.0, 106.0),
		Vector2(80.0, 118.0), Vector2(25.0, 123.0), Vector2(-30.0, 122.0), Vector2(-85.0, 129.0),
		Vector2(-140.0, 143.0), Vector2(-195.0, 160.0), Vector2(-255.0, 172.0), Vector2(-334.0, 180.0),
	], 5.0)

	var cobble: Color = Color(0.4, 0.4, 0.38)
	var asphalt: Color = Color(0.2, 0.2, 0.21)
	var dirt: Color = Color(0.42, 0.3, 0.2)
	# The centre: the street along the line, the grid round the praça, the bridge.
	_road("RuaDaEstacaoBaixa", [Vector2(52.0, 12.0), Vector2(80.0, 14.0), Vector2(110.0, 15.0), Vector2(138.0, 18.0), Vector2(160.0, 22.0), Vector2(185.0, 18.0), Vector2(205.0, 10.0), Vector2(218.0, 4.0)], 3.0, cobble, true)
	_road("RuaDoComercio", [Vector2(72.0, 43.0), Vector2(100.0, 44.0), Vector2(150.0, 44.0), Vector2(170.0, 40.0)], 3.0, cobble, true)
	_road("RuaDaPonte", [Vector2(70.0, 88.0), Vector2(100.0, 86.0), Vector2(150.0, 86.0), Vector2(158.0, 84.0)], 3.0, cobble, true)
	_road("RuaDaMatriz", [Vector2(99.0, 16.0), Vector2(100.0, 44.0), Vector2(99.0, 86.0), Vector2(97.0, 100.0)], 3.0, cobble, true)
	_road("RuaDireita", [Vector2(151.0, 21.0), Vector2(151.0, 44.0), Vector2(150.0, 86.0)], 3.0, cobble, true)
	_road("RuaDaCaixa", [Vector2(176.0, 20.0), Vector2(170.0, 40.0)], 2.6, cobble, true)
	_road("RuaDoMercado", [Vector2(72.0, -6.0), Vector2(72.0, 14.0), Vector2(72.0, 43.0), Vector2(70.0, 88.0), Vector2(68.0, 104.0)], 3.0, cobble, true)
	_road("AvenidaDaPonte", [Vector2(125.0, 86.0), Vector2(127.0, 100.0), Vector2(130.0, 113.0), Vector2(134.0, 128.0), Vector2(136.0, 142.0)], 3.5, asphalt, true)
	# The south bank.
	_road("RuaVilaNova", [Vector2(30.0, 146.0), Vector2(80.0, 145.0), Vector2(136.0, 142.0), Vector2(185.0, 136.0), Vector2(225.0, 120.0)], 3.0, asphalt, true)
	# The road into town from the south-west, past the petrol station and the cemetery.
	_road("Estrada", [Vector2(-334.0, 152.0), Vector2(-270.0, 140.0), Vector2(-200.0, 120.0), Vector2(-140.0, 106.0), Vector2(-80.0, 104.0), Vector2(-20.0, 106.0), Vector2(30.0, 104.0), Vector2(68.0, 104.0)], 3.5, asphalt, true)
	_road("SubidaDoCemiterio", [Vector2(-110.0, 104.0), Vector2(-112.0, 79.0)], 2.0, dirt, false)
	# The workers' village: straight rows north of the line.
	_road("VilaRua1", [Vector2(78.0, -12.0), Vector2(110.0, -12.0), Vector2(140.0, -12.0)], 2.5, cobble, true)
	_road("VilaRua2", [Vector2(78.0, -30.0), Vector2(110.0, -30.0), Vector2(150.0, -30.0)], 2.5, cobble, true)
	_road("VilaTravessa", [Vector2(110.0, -12.0), Vector2(110.0, -30.0)], 2.2, cobble, false)
	# The periphery up the north hill, the cruzeiro and the radio mast.
	_road("EstradaDoMorro", [Vector2(72.0, -6.0), Vector2(78.0, -30.0), Vector2(80.0, -45.0), Vector2(75.0, -75.0), Vector2(55.0, -100.0), Vector2(25.0, -115.0), Vector2(-10.0, -122.0), Vector2(-45.0, -115.0), Vector2(-75.0, -100.0), Vector2(-95.0, -80.0)], 2.4, dirt, true)
	_road("SubidaDoCruzeiro", [Vector2(-10.0, -122.0), Vector2(-15.0, -150.0), Vector2(-26.0, -172.0), Vector2(-30.0, -182.0)], 1.8, dirt, false)
	_road("SubidaDaAntena", [Vector2(55.0, -100.0), Vector2(85.0, -130.0), Vector2(104.0, -168.0), Vector2(110.0, -182.0)], 1.8, dirt, false)
	_road("RuaDoAlto", [Vector2(-45.0, -115.0), Vector2(-30.0, -100.0), Vector2(-5.0, -96.0), Vector2(30.0, -100.0)], 2.0, dirt, true)
	# Farm roads.
	_road("EstradaSul", [Vector2(185.0, 136.0), Vector2(205.0, 180.0), Vector2(225.0, 230.0), Vector2(250.0, 290.0), Vector2(262.0, 334.0)], 2.2, dirt, false)
	_road("EstradaDoSitio", [Vector2(30.0, 146.0), Vector2(12.0, 190.0), Vector2(-10.0, 240.0), Vector2(-22.0, 300.0)], 2.0, dirt, false)
	_road("EstradaOeste", [Vector2(-200.0, 120.0), Vector2(-215.0, 70.0), Vector2(-240.0, 20.0), Vector2(-270.0, -30.0), Vector2(-300.0, -70.0)], 2.0, dirt, false)
	# More of the town: the south bank's streets, the hill north of the village, the far
	# bank in the east, the lane along the top of the old upper town.
	_road("RuaNova1", [Vector2(136.0, 142.0), Vector2(142.0, 186.0), Vector2(146.0, 222.0)], 2.6, asphalt, true)
	_road("RuaNova2", [Vector2(142.0, 192.0), Vector2(200.0, 192.0), Vector2(238.0, 172.0)], 2.6, cobble, true)
	_road("RuaNova3", [Vector2(146.0, 222.0), Vector2(100.0, 228.0), Vector2(50.0, 226.0), Vector2(12.0, 212.0)], 2.4, dirt, true)
	_road("RuaNova4", [Vector2(185.0, 136.0), Vector2(230.0, 150.0), Vector2(275.0, 150.0)], 2.4, asphalt, true)
	_road("VilaRua3", [Vector2(80.0, -48.0), Vector2(120.0, -50.0), Vector2(160.0, -46.0), Vector2(205.0, -32.0)], 2.4, dirt, true)
	_road("RuaDoMorro2", [Vector2(120.0, -50.0), Vector2(128.0, -80.0), Vector2(118.0, -110.0), Vector2(90.0, -128.0)], 2.2, dirt, true)
	_road("BairroLeste", [Vector2(205.0, -32.0), Vector2(250.0, -2.0), Vector2(268.0, 35.0), Vector2(262.0, 80.0), Vector2(238.0, 118.0)], 2.4, dirt, true)
	_road("RuaDoTopo", [Vector2(-95.0, -80.0), Vector2(-60.0, -92.0), Vector2(-20.0, -90.0), Vector2(20.0, -92.0), Vector2(55.0, -100.0)], 2.2, dirt, true)
	_road("RuaDaBeira", [Vector2(-80.0, 104.0), Vector2(-75.0, 70.0), Vector2(-88.0, 30.0), Vector2(-95.0, -10.0)], 2.2, dirt, true)

	_pad("Praca", Rect2(103.0, 48.0, 44.0, 34.0), Color(0.52, 0.5, 0.45))
	_pad("ChurchPlot", Rect2(112.0, 20.0, 26.0, 21.0), Color(0.48, 0.46, 0.42))
	_pad("Station", Rect2(140.0, 6.0, 45.0, 12.0), Color(0.42, 0.4, 0.36))
	_pad("Warehouse", Rect2(150.0, -8.0, 34.0, 9.0), Color(0.4, 0.37, 0.32))
	_pad("Football", Rect2(37.0, 152.0, 96.0, 62.0), Color(0.5, 0.42, 0.28))
	_pad("School", Rect2(153.0, 149.0, 44.0, 32.0), Color(0.45, 0.44, 0.42))
	_pad("PetrolStation", Rect2(-165.0, 86.0, 30.0, 14.0), Color(0.22, 0.22, 0.23))
	_pad("Cemetery", Rect2(-135.0, 46.0, 40.0, 32.0), Color(0.3, 0.38, 0.22))
	_pad("Cruzeiro", Rect2(-38.0, -196.0, 16.0, 16.0), Color(0.4, 0.38, 0.3))
	_pad("Antenna", Rect2(104.0, -196.0, 14.0, 14.0), Color(0.4, 0.38, 0.3))
	_pad("WaterTower", Rect2(34.0, -137.0, 12.0, 12.0), Color(0.4, 0.38, 0.3))

	farms.append({"kind": "pasture", "rect": Rect2(-320.0, -60.0, 150.0, 115.0)})
	farms.append({"kind": "pasture", "rect": Rect2(-60.0, 225.0, 180.0, 95.0)})
	farms.append({"kind": "coffee", "rect": Rect2(-305.0, 195.0, 140.0, 100.0)})
	farms.append({"kind": "eucalyptus", "rect": Rect2(180.0, 200.0, 125.0, 110.0)})
	farms.append({"kind": "banana", "rect": Rect2(278.0, 40.0, 46.0, 55.0)})
	farms.append({"kind": "pasture", "rect": Rect2(255.0, 120.0, 70.0, 80.0)})


func _polyline(polyline_id: String, controls: Array[Vector2], half_width: float) -> TownLane:
	var points: Array[Vector3] = []
	for c: Vector2 in controls:
		points.append(Vector3(c.x, 0.0, c.y))

	return TownLane.create(polyline_id, "Scenery", TownLane.Kind.GROUND, points, half_width, 0.0, 0.0)


func _road(road_id: String, controls: Array[Vector2], half_width: float, ground: Color, lit: bool) -> void:
	roads.append({"id": road_id, "lane": _polyline(road_id, controls, half_width), "half": half_width, "ground": ground, "lit": lit})


func _pad(pad_id: String, rect: Rect2, color: Color) -> void:
	var kind: int = KIND_STONE
	if pad_id == "Football":
		kind = KIND_DIRT
	elif pad_id == "Cemetery":
		kind = KIND_CEMETERY
	pads.append({"id": pad_id, "rect": rect, "color": color, "y": 0.0, "kind": kind})


func _profile(z: float) -> float:
	for i: int in PROFILE_Z.size() - 1:
		if z <= PROFILE_Z[i + 1]:
			var t: float = clampf((z - PROFILE_Z[i]) / (PROFILE_Z[i + 1] - PROFILE_Z[i]), 0.0, 1.0)
			return lerpf(PROFILE_Y[i], PROFILE_Y[i + 1], smoothstep(0.0, 1.0, t))

	return PROFILE_Y[PROFILE_Y.size() - 1]


## How far (m) the point is outside the core's terrain.
func _outside_core(x: float, z: float) -> float:
	var dx: float = maxf(maxf(CORE.position.x - x, x - CORE.end.x), 0.0)
	var dz: float = maxf(maxf(CORE.position.y - z, z - CORE.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)


## Everything but the north-south profile: the west ridge over the tunnel, the east-west
## lie of the valley, and broad hills away from the core.
func _relief(x: float, z: float) -> float:
	var height: float = 0.0
	# The ridge the line tunnels through, closing the valley in the west.
	var west: float = smoothstep(-50.0, -60.0, x)
	height += west * (14.0 + maxf(-60.0 - x, 0.0) * 0.12)
	# Big, soft hills and hollows, faded out near the core so its ground is untouched.
	var away: float = smoothstep(0.0, 45.0, _outside_core(x, z))
	height += away * (_noise_a.get_noise_2d(x, z) * 14.0 + _noise_b.get_noise_2d(x, z) * 1.6)
	# The hills on the far east and the far south-west rise higher.
	height += away * maxf(absf(x) - 220.0, 0.0) * 0.12
	return height


func _index(gx: int, gz: int) -> int:
	return gz * grid_n + gx


## The shaped ground (bilinear over the 2 m grid). The core starts its terrain from this.
func natural_height(x: float, z: float) -> float:
	var fx: float = clampf((x - X0) / STEP, 0.0, float(grid_n) - 1.001)
	var fz: float = clampf((z - Z0) / STEP, 0.0, float(grid_n) - 1.001)
	var gx: int = int(fx)
	var gz: int = int(fz)
	var tx: float = fx - float(gx)
	var tz: float = fz - float(gz)
	return lerpf(
		lerpf(heights[_index(gx, gz)], heights[_index(gx + 1, gz)], tx),
		lerpf(heights[_index(gx, gz + 1)], heights[_index(gx + 1, gz + 1)], tx),
		tz
	)


## The ground under a point: the core's carved terrain inside it, the shaped ground outside.
func height_at(x: float, z: float) -> float:
	if CORE.grow(-0.5).has_point(Vector2(x, z)):
		return town.ground_height(x, z)

	return natural_height(x, z)


func paint_at(x: float, z: float) -> Color:
	var gx: int = clampi(roundi((x - X0) / STEP), 0, grid_n - 1)
	var gz: int = clampi(roundi((z - Z0) / STEP), 0, grid_n - 1)
	return paint[_index(gx, gz)]


## The ground's colour (grass, bare rock where it is steep, the painted roads and farms).
func ground_color(x: float, z: float, normal_y: float, shade: float) -> Color:
	var color: Color = Color(0.15, 0.24, 0.1).lerp(Color(0.3, 0.38, 0.19), shade)
	color = color.lerp(Color(0.3, 0.3, 0.26), smoothstep(0.72, 0.52, normal_y))
	color = color.lerp(Color(0.2, 0.15, 0.1), smoothstep(0.5, 0.95, shade) * 0.3)
	var painted: Color = paint_at(x, z)
	if painted.a > 0.0:
		var tint: Color = Color(painted.r, painted.g, painted.b) * (0.88 + shade * 0.24)
		color = color.lerp(tint, painted.a)

	return color


## Gives `lane` a smooth grade: the ground's height along it, averaged over `window` metres.
func _grade(lane: TownLane, window: float) -> void:
	var raw: PackedFloat32Array = PackedFloat32Array()
	for point: Vector3 in lane.points:
		raw.append(natural_height(point.x, point.z))

	var reach: int = maxi(int(window / TownLane.STEP), 1)
	for i: int in lane.points.size():
		var total: float = 0.0
		var count: int = 0
		for j: int in range(maxi(i - reach, 0), mini(i + reach, raw.size() - 1) + 1):
			total += raw[j]
			count += 1

		var point: Vector3 = lane.points[i]
		point.y = total / float(count)
		lane.points[i] = point


## Levels the ground along `lane` (flat to `flat` m from it, blending out over `blend`) and
## paints it.
func _stamp_line(lane: TownLane, flat: float, blend: float, color: Color, strength: float, kind: int) -> void:
	var reach: float = flat + blend
	var touched: Dictionary = {}
	for i: int in lane.points.size():
		var point: Vector3 = lane.points[i]
		var gx0: int = maxi(int(floor((point.x - reach - X0) / STEP)), 0)
		var gx1: int = mini(int(ceil((point.x + reach - X0) / STEP)), grid_n - 1)
		var gz0: int = maxi(int(floor((point.z - reach - Z0) / STEP)), 0)
		var gz1: int = mini(int(ceil((point.z + reach - Z0) / STEP)), grid_n - 1)
		for gz: int in range(gz0, gz1 + 1):
			for gx: int in range(gx0, gx1 + 1):
				var dx: float = X0 + float(gx) * STEP - point.x
				var dz: float = Z0 + float(gz) * STEP - point.z
				var distance: float = sqrt(dx * dx + dz * dz)
				if distance >= reach:
					continue

				var k: int = _index(gx, gz)
				var previous: Variant = touched.get(k)
				if previous == null or distance < float((previous as Vector2).x):
					touched[k] = Vector2(distance, point.y)

	for k: int in touched:
		var hit: Vector2 = touched[k]
		var w: float = 1.0 - smoothstep(flat, reach, hit.x)
		heights[k] = lerpf(heights[k], hit.y, w)
		var paint_weight: float = (1.0 - smoothstep(flat - 1.0, flat + 0.5, hit.x)) * strength
		if paint_weight > paint[k].a:
			paint[k] = Color(color.r, color.g, color.b, paint_weight)
			kinds[k] = kind



func _stamp_pad(pad: Dictionary) -> void:
	var rect: Rect2 = pad["rect"]
	var kind: int = pad["kind"]
	# Level it at the average of the ground under it.
	var total: float = 0.0
	var count: int = 0
	var x: float = rect.position.x
	while x <= rect.end.x:
		var z: float = rect.position.y
		while z <= rect.end.y:
			total += natural_height(x, z)
			count += 1
			z += 4.0

		x += 4.0

	var level: float = total / float(maxi(count, 1))
	pad["y"] = level
	var blend: float = 6.0
	var gx0: int = maxi(int(floor((rect.position.x - blend - X0) / STEP)), 0)
	var gx1: int = mini(int(ceil((rect.end.x + blend - X0) / STEP)), grid_n - 1)
	var gz0: int = maxi(int(floor((rect.position.y - blend - Z0) / STEP)), 0)
	var gz1: int = mini(int(ceil((rect.end.y + blend - Z0) / STEP)), grid_n - 1)
	var color: Color = pad["color"]
	for gz: int in range(gz0, gz1 + 1):
		for gx: int in range(gx0, gx1 + 1):
			var px: float = X0 + float(gx) * STEP
			var pz: float = Z0 + float(gz) * STEP
			var dx: float = maxf(maxf(rect.position.x - px, px - rect.end.x), 0.0)
			var dz: float = maxf(maxf(rect.position.y - pz, pz - rect.end.y), 0.0)
			var distance: float = sqrt(dx * dx + dz * dz)
			var w: float = 1.0 - smoothstep(0.5, blend, distance)
			var k: int = _index(gx, gz)
			heights[k] = lerpf(heights[k], level, w)
			var paint_weight: float = 1.0 - smoothstep(0.0, 1.5, distance)
			if paint_weight > paint[k].a:
				paint[k] = Color(color.r, color.g, color.b, paint_weight)
			kinds[k] = kind


func _paint_farm(farm: Dictionary) -> void:
	var rect: Rect2 = farm["rect"]
	var color: Color = Color(0.42, 0.46, 0.22)
	var farm_kind: int = KIND_PASTURE
	match String(farm["kind"]):
		"coffee":
			color = Color(0.2, 0.3, 0.13)
			farm_kind = KIND_COFFEE
		"eucalyptus":
			color = Color(0.3, 0.27, 0.18)
			farm_kind = KIND_EUCALYPTUS
		"banana":
			color = Color(0.22, 0.34, 0.14)
			farm_kind = KIND_BANANA

	for gz: int in grid_n:
		var pz: float = Z0 + float(gz) * STEP
		if pz < rect.position.y - 12.0 or pz > rect.end.y + 12.0:
			continue

		for gx: int in grid_n:
			var px: float = X0 + float(gx) * STEP
			if px < rect.position.x - 12.0 or px > rect.end.x + 12.0:
				continue

			# Ragged edges: the field's border wanders by up to ~10 m.
			var wobble: float = _noise_b.get_noise_2d(px * 0.7, pz * 0.7) * 10.0
			var dx: float = maxf(maxf(rect.position.x - px, px - rect.end.x), 0.0)
			var dz: float = maxf(maxf(rect.position.y - pz, pz - rect.end.y), 0.0)
			var inside: float = 1.0 - smoothstep(-2.0, 2.0, maxf(dx, dz) + wobble)
			var k: int = _index(gx, gz)
			var w: float = inside * 0.85
			if w > paint[k].a:
				paint[k] = Color(color.r, color.g, color.b, w)
				kinds[k] = farm_kind


## The river: its surface falls from east to west; it cuts a bed and a flat flood plain.
func _cut_river() -> void:
	_river_y.resize(river.points.size())
	var level: float = INF
	for i: int in river.points.size():
		var point: Vector3 = river.points[i]
		level = minf(level, natural_height(point.x, point.z) - 2.5)
		level = minf(level, -5.0 - float(i) * 0.008)
		_river_y[i] = level
		point.y = level
		river.points[i] = point

	var reach: float = 46.0
	var nearest: Dictionary = {}
	for i: int in range(0, river.points.size(), 3):
		var point: Vector3 = river.points[i]
		var gx0: int = maxi(int(floor((point.x - reach - X0) / STEP)), 0)
		var gx1: int = mini(int(ceil((point.x + reach - X0) / STEP)), grid_n - 1)
		var gz0: int = maxi(int(floor((point.z - reach - Z0) / STEP)), 0)
		var gz1: int = mini(int(ceil((point.z + reach - Z0) / STEP)), grid_n - 1)
		for gz: int in range(gz0, gz1 + 1):
			for gx: int in range(gx0, gx1 + 1):
				var dx: float = X0 + float(gx) * STEP - point.x
				var dz: float = Z0 + float(gz) * STEP - point.z
				var distance: float = sqrt(dx * dx + dz * dz)
				if distance >= reach:
					continue

				var k: int = _index(gx, gz)
				var previous: Variant = nearest.get(k)
				if previous == null or distance < float((previous as Vector2).x):
					nearest[k] = Vector2(distance, point.y)

	var mud: Color = Color(0.3, 0.26, 0.18)
	for k: int in nearest:
		var hit: Vector2 = nearest[k]
		var distance: float = hit.x
		var surface: float = hit.y
		var bank: float = surface - 1.8
		if distance > 5.0:
			bank = lerpf(surface - 1.8, surface + 0.5, smoothstep(5.0, 9.0, distance)) + maxf(distance - 9.0, 0.0) * 0.06

		var w: float = 1.0 - smoothstep(18.0, reach, distance)
		# Only ever cut down, so the river never builds a dyke.
		heights[k] = minf(heights[k], lerpf(heights[k], bank, w))
		var mud_weight: float = 1.0 - smoothstep(6.0, 11.0, distance)
		if mud_weight > paint[k].a:
			paint[k] = Color(mud.r, mud.g, mud.b, mud_weight)
			kinds[k] = KIND_MUD


# ============================================================
# BUILDING IT
# ============================================================

func build(parent: Node3D) -> void:
	var root: Node3D = town._group(parent, "OuterTown")
	_mark_occupancy()
	if not town.vista_mode:
		_build_ground(root)
		_build_horizon(root)

	_build_water(root)
	_build_line(root)
	_build_roads(root)
	_build_landmarks(root)
	_build_houses()
	_build_farms(root)
	_build_forest(root)
	_finish_meshes(root)


func _builder(builder_name: String) -> TownMeshBuilder:
	if not _builders.has(builder_name):
		_builders[builder_name] = TownMeshBuilder.new()

	return _builders[builder_name]


func _finish_meshes(root: Node3D) -> void:
	for builder_name: String in _builders:
		var builder: TownMeshBuilder = _builders[builder_name]
		if builder.is_empty():
			continue

		var material: Material = town._vertex_material()
		if builder_name == "RedLight":
			var red: StandardMaterial3D = StandardMaterial3D.new()
			red.albedo_color = Color(1.0, 0.1, 0.05)
			red.emission_enabled = true
			red.emission = Color(1.0, 0.1, 0.05)
			red.emission_energy_multiplier = 4.0
			material = red

		var instance: MeshInstance3D = town._solid_mesh(root, builder_name, builder.build(), material, false)
		if builder_name == "Trees":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if not _lit.is_empty():
		var lit_material: StandardMaterial3D = StandardMaterial3D.new()
		lit_material.vertex_color_use_as_albedo = true
		lit_material.emission_enabled = true
		lit_material.emission = LAMP
		lit_material.emission_energy_multiplier = 4.5
		var lights: MeshInstance3D = town._solid_mesh(root, "LitWindowsAndLamps", _lit.build(), lit_material, false)
		lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_build_halos(root)


func _occ_index(x: float, z: float) -> int:
	var ox: int = int(floor((x - X0) / OCC_CELL))
	var oz: int = int(floor((z - Z0) / OCC_CELL))
	if ox < 0 or oz < 0 or ox >= occ_n or oz >= occ_n:
		return -1

	return oz * occ_n + ox


func _occupied(x: float, z: float) -> bool:
	var k: int = _occ_index(x, z)
	return k < 0 or occupancy[k] != 0


func _mark_disc(x: float, z: float, radius: float) -> void:
	var r: int = int(ceil(radius / OCC_CELL))
	for dz: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			if float(dx * dx + dz * dz) * OCC_CELL * OCC_CELL > radius * radius:
				continue

			var k: int = _occ_index(x + float(dx) * OCC_CELL, z + float(dz) * OCC_CELL)
			if k >= 0:
				occupancy[k] = 1


func _mark_rect(rect: Rect2) -> void:
	var x: float = rect.position.x
	while x <= rect.end.x:
		var z: float = rect.position.y
		while z <= rect.end.y:
			var k: int = _occ_index(x, z)
			if k >= 0:
				occupancy[k] = 1

			z += OCC_CELL

		x += OCC_CELL


## What scenery must keep off: the playable core (its lanes, houses and walls, with a margin),
## the roads, the line, the river and the pads.
func _mark_occupancy() -> void:
	occ_n = int(SIZE / OCC_CELL)
	occupancy.resize(occ_n * occ_n)
	occupancy.fill(0)
	var cell: float = TownBlockout.RASTER_CELL
	var z: float = TownBlockout.RASTER_Z0
	while z < TownBlockout.RASTER_Z1:
		var x: float = TownBlockout.RASTER_X0
		while x < TownBlockout.RASTER_X1:
			var k: int = town._raster_cell(x, z)
			if k >= 0 and (town._allowed[k] == 1 or town._solid[k] == 1):
				var o: int = _occ_index(x, z)
				if o >= 0:
					occupancy[o] = 1

			x += cell

		z += cell

	# Grow the core's mark by 2 m.
	var grown: PackedByteArray = occupancy.duplicate()
	for oz: int in range(1, occ_n - 1):
		for ox: int in range(1, occ_n - 1):
			if occupancy[oz * occ_n + ox] == 0:
				continue

			for d: int in range(-2, 3):
				for e: int in range(-2, 3):
					var nx: int = clampi(ox + e, 0, occ_n - 1)
					var nz: int = clampi(oz + d, 0, occ_n - 1)
					grown[nz * occ_n + nx] = 1

	occupancy = grown

	for road: Dictionary in roads:
		var lane: TownLane = road["lane"]
		for point: Vector3 in lane.points:
			_mark_disc(point.x, point.z, float(road["half"]) + 0.4)

	for point: Vector3 in rail.points:
		_mark_disc(point.x, point.z, 4.5)

	for point: Vector3 in siding.points:
		_mark_disc(point.x, point.z, 3.0)

	for i: int in range(0, river.points.size(), 2):
		_mark_disc(river.points[i].x, river.points[i].z, 9.0)

	for pad: Dictionary in pads:
		_mark_rect((pad["rect"] as Rect2).grow(1.0))


## The ground outside the core: a 2 m grid with a hole where the core's own terrain is.
func _build_ground(root: Node3D) -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var count: int = grid_n * grid_n
	vertices.resize(count)
	normals.resize(count)
	colors.resize(count)
	uvs.resize(count)
	var shade_noise: FastNoiseLite = FastNoiseLite.new()
	shade_noise.seed = town.seed_value + 7
	shade_noise.frequency = 0.09
	for gz: int in grid_n:
		for gx: int in grid_n:
			var k: int = _index(gx, gz)
			var x: float = X0 + float(gx) * STEP
			var z: float = Z0 + float(gz) * STEP
			vertices[k] = Vector3(x, heights[k], z)
			uvs[k] = Vector2(x, z) * 0.25
			var left: float = heights[_index(maxi(gx - 1, 0), gz)]
			var right: float = heights[_index(mini(gx + 1, grid_n - 1), gz)]
			var back: float = heights[_index(gx, maxi(gz - 1, 0))]
			var front: float = heights[_index(gx, mini(gz + 1, grid_n - 1))]
			var normal: Vector3 = Vector3(left - right, 2.0 * STEP, back - front).normalized()
			normals[k] = normal
			colors[k] = ground_color(x, z, normal.y, shade_noise.get_noise_2d(x, z) * 0.5 + 0.5)

	var indices: PackedInt32Array = PackedInt32Array()
	for gz: int in grid_n - 1:
		for gx: int in grid_n - 1:
			var x: float = X0 + float(gx) * STEP
			var z: float = Z0 + float(gz) * STEP
			# Leave the core's terrain alone (its edges share these vertices' heights).
			if x >= CORE.position.x and x + STEP <= CORE.end.x and z >= CORE.position.y and z + STEP <= CORE.end.y:
				continue

			var a: int = _index(gx, gz)
			var b: int = a + 1
			var c: int = a + grid_n
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
	town._solid_mesh(root, "Ground", mesh, town._terrain_material(), false)


func _build_water(root: Node3D) -> void:
	var water: TownMeshBuilder = TownMeshBuilder.new()
	var path: PackedVector3Array = PackedVector3Array()
	for i: int in river.points.size():
		path.append(river.points[i] + Vector3(0.0, -0.35, 0.0))

	water.extrude(path, PackedVector2Array([Vector2(-6.5, 0.0), Vector2(6.5, 0.0)]), false, Color(0.08, 0.13, 0.13))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.08
	material.metallic = 0.3
	town._solid_mesh(root, "River", water.build(), material, false)
	landmarks["River"] = river.point_at(river.length() * 0.5)


## The line going on east from the yard: ballast, rails, the station siding, the iron bridge.
func _build_line(root: Node3D) -> void:
	var b: TownMeshBuilder = _builder("Railway")
	for line: TownLane in [rail, siding]:
		var path: PackedVector3Array = PackedVector3Array()
		for point: Vector3 in line.points:
			path.append(point)

		b.extrude(path, PackedVector2Array([Vector2(-1.95, 0.02), Vector2(-1.3, 0.12), Vector2(1.3, 0.12), Vector2(1.95, 0.02)]), false, Color(0.3, 0.28, 0.25))
		for rail_side: float in [-0.72, 0.72]:
			b.extrude(path, PackedVector2Array([
				Vector2(rail_side - 0.04, 0.12), Vector2(rail_side + 0.04, 0.12),
				Vector2(rail_side + 0.04, 0.26), Vector2(rail_side - 0.04, 0.26),
			]), true, Color(0.36, 0.33, 0.3))

	# The iron truss bridge where the line crosses the river.
	var crossing: Array[int] = []
	for i: int in rail.points.size():
		if _distance_to_river(Vector2(rail.points[i].x, rail.points[i].z)) < 16.0:
			crossing.append(i)

	if not crossing.is_empty():
		var a: Vector3 = rail.points[crossing[0]]
		var c: Vector3 = rail.points[crossing[crossing.size() - 1]]
		var direction: Vector3 = (c - a)
		var length: float = Vector2(direction.x, direction.z).length()
		var yaw: float = atan2(-direction.z, direction.x)
		var middle: Vector3 = (a + c) * 0.5
		var iron: Color = Color(0.22, 0.24, 0.26)
		b.add_box(middle + Vector3(0.0, -0.3, 0.0), Vector3(length, 0.6, 4.6), iron, yaw)
		var across: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 2.3)
		var along: Vector3 = Basis(Vector3.UP, yaw) * Vector3(1.0, 0.0, 0.0)
		for side: float in [-1.0, 1.0]:
			b.add_box(middle + across * side + Vector3(0.0, 4.6, 0.0), Vector3(length, 0.3, 0.3), iron, yaw)
			var panels: int = maxi(int(length / 4.0), 2)
			for p: int in panels + 1:
				var at: Vector3 = a + along * (length * float(p) / float(panels)) + across * side
				b.add_box(Vector3(at.x, middle.y + 2.3, at.z), Vector3(0.3, 4.6, 0.3), iron, yaw)

		# The piers down to the river bed.
		for at: Vector3 in [a, c]:
			var bed: float = natural_height(at.x, at.z)
			b.add_box(Vector3(at.x, (middle.y + bed) * 0.5 - 0.5, at.z), Vector3(2.0, middle.y - bed + 1.0, 5.0), Color(0.42, 0.4, 0.37), yaw)

		landmarks["RailBridge"] = middle

	# Wagons on the siding.
	var wagon_colors: Array[Color] = [Color(0.42, 0.21, 0.15), Color(0.2, 0.28, 0.24), Color(0.45, 0.4, 0.3)]
	for w: int in 3:
		var s: float = 6.0 + float(w) * 11.5
		if s > siding.length() - 5.0:
			break

		var index: int = siding.sample_index(s)
		var tangent: Vector2 = siding.tangents[index]
		var point: Vector3 = siding.point_at(s)
		b.add_box(point + Vector3(0.0, 2.0, 0.0), Vector3(10.5, 2.6, 2.7), wagon_colors[w], atan2(-tangent.y, tangent.x))


func _distance_to_river(p: Vector2) -> float:
	var best: float = INF
	for i: int in range(0, river.points.size() - 1, 2):
		best = minf(best, river.segment_hit(i, p).x)

	return best


## Roads as ribbons on the ground (bridges where they cross the river), with street lamps
## (lit points, warm) and wooden poles along the lit ones.
func _build_roads(root: Node3D) -> void:
	var b: TownMeshBuilder = _builder("Roads")
	var poles: TownMeshBuilder = _builder("Poles")
	for road: Dictionary in roads:
		var lane: TownLane = road["lane"]
		var half: float = road["half"]
		var color: Color = road["ground"]
		var path: PackedVector3Array = PackedVector3Array()
		for point: Vector3 in lane.points:
			path.append(point + Vector3(0.0, 0.07, 0.0))

		b.extrude(path, PackedVector2Array([Vector2(-half, 0.0), Vector2(0.0, 0.03), Vector2(half, 0.0)]), false, color.darkened(0.05))

		# A bridge deck and railings where the road is above the river.
		var over: Array[int] = []
		var closest: float = INF
		for i: int in lane.points.size():
			var to_river: float = _distance_to_river(lane.xz(i))
			closest = minf(closest, to_river)
			if to_river < 9.0:
				over.append(i)

		if not over.is_empty() and closest < 3.0:
			var a: Vector3 = lane.points[maxi(over[0] - 2, 0)]
			var c: Vector3 = lane.points[mini(over[over.size() - 1] + 2, lane.points.size() - 1)]
			var direction: Vector3 = c - a
			var yaw: float = atan2(-direction.z, direction.x)
			var length: float = Vector2(direction.x, direction.z).length()
			var middle: Vector3 = (a + c) * 0.5
			var concrete: Color = Color(0.6, 0.59, 0.56)
			b.add_box(middle + Vector3(0.0, -0.35, 0.0), Vector3(length, 0.7, half * 2.0 + 1.0), concrete, yaw)
			var across: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, half + 0.4)
			for side: float in [-1.0, 1.0]:
				b.add_box(middle + across * side + Vector3(0.0, 0.5, 0.0), Vector3(length, 1.0, 0.2), concrete, yaw)

			var bed: float = natural_height(middle.x, middle.z)
			b.add_box(Vector3(middle.x, (middle.y + bed) * 0.5, middle.z), Vector3(1.4, middle.y - bed, half * 2.0), concrete, yaw)
			landmarks["RoadBridge%s" % road["id"]] = middle

		if not bool(road["lit"]):
			continue

		var side_sign: float = 1.0
		var s: float = 6.0
		while s < lane.length() - 3.0:
			var index: int = lane.sample_index(s)
			var normal: Vector2 = lane.right_normal(index) * side_sign
			var base: Vector3 = lane.point_at(s) + Vector3(normal.x, 0.0, normal.y) * (half + 0.5)
			poles.add_box(base + Vector3(0.0, 3.4, 0.0), Vector3(0.22, 6.8, 0.22), Color(0.22, 0.16, 0.1))
			var lamp: Vector3 = base + Vector3(0.0, 6.2, 0.0) - Vector3(normal.x, 0.0, normal.y) * 0.7
			# In vista mode only every other lane lamp is lit.
			_lane_lamp_count += 1
			if not town.vista_mode or _lane_lamp_count % VISTA_LAMP_EVERY == 0:
				_lit.add_box(lamp, Vector3(0.6, 0.35, 0.6), LAMP)
				_halo(lamp, 26.0, 1.0)
			_lamps.append(lamp)
			side_sign = -side_sign
			s += rng.randf_range(16.0, 22.0)


# ============================================================
# LANDMARKS
# ============================================================

func _pad_info(pad_id: String) -> Dictionary:
	for pad: Dictionary in pads:
		if pad["id"] == pad_id:
			return pad

	return {}


## A box turned `yaw` about Y round its centre, into `b`.
func _box(b: TownMeshBuilder, center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	b.add_box(center, size, color, yaw)


## A gabled roof over a w x d body whose eaves are at `base` (its centre), ridge along local X.
func _gable(b: TownMeshBuilder, base: Vector3, w: float, d: float, rise: float, yaw: float, color: Color) -> void:
	var basis: Basis = Basis(Vector3.UP, yaw)
	var x0: float = -w * 0.5 - 0.3
	var points: Array[Vector3] = [
		base + basis * Vector3(x0, -0.15, d * 0.5 + 0.5),
		base + basis * Vector3(x0, rise, 0.0),
		base + basis * Vector3(x0, -0.15, -d * 0.5 - 0.5),
	]
	b.add_prism(points, basis * Vector3(w + 0.6, 0.0, 0.0), color)


## A pyramid roof (a church tower's) over a square of half side `half` at `base`.
func _pyramid(b: TownMeshBuilder, base: Vector3, half: float, height: float, color: Color) -> void:
	var top: Vector3 = base + Vector3(0.0, height, 0.0)
	var corners: Array[Vector3] = [
		base + Vector3(-half, 0.0, -half), base + Vector3(half, 0.0, -half),
		base + Vector3(half, 0.0, half), base + Vector3(-half, 0.0, half),
	]
	for i: int in 4:
		var a: Vector3 = corners[i]
		var c: Vector3 = corners[(i + 1) % 4]
		b.add_triangle(a, c, top, ((a + c) * 0.5 - base) + Vector3(0.0, half, 0.0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, color)


## A many-sided prism standing on `base` (a bandstand, a water tank).
func _round(b: TownMeshBuilder, base: Vector3, radius: float, height: float, sides: int, color: Color) -> void:
	var ring: Array[Vector3] = []
	for i: int in sides:
		var angle: float = TAU * float(i) / float(sides)
		ring.append(base + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))

	b.add_prism(ring, Vector3(0.0, height, 0.0), color)


func _cone(b: TownMeshBuilder, base: Vector3, radius: float, height: float, sides: int, color: Color) -> void:
	var top: Vector3 = base + Vector3(0.0, height, 0.0)
	for i: int in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var p0: Vector3 = base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1: Vector3 = base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		b.add_triangle(p0, p1, top, ((p0 + p1) * 0.5 - base).normalized() + Vector3(0.0, 0.4, 0.0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, color)


func _build_landmarks(root: Node3D) -> void:
	var b: TownMeshBuilder = _builder("Landmarks")
	var marks: Node3D = town._group(root, "Landmarks")

	# The Igreja Matriz: a white nave and two towers facing the praça (south).
	var plot: Dictionary = _pad_info("ChurchPlot")
	var church_y: float = plot["y"]
	var nave: Vector3 = Vector3(125.0, church_y, 29.0)
	_box(b, nave + Vector3(0.0, 5.5, 0.0), Vector3(13.0, 11.0, 17.0), WHITE)
	_gable(b, nave + Vector3(0.0, 11.0, 0.0), 17.0, 13.0, 4.5, PI * 0.5, ROOF_TILE_OLD)
	for side: float in [-1.0, 1.0]:
		var tower: Vector3 = Vector3(125.0 + side * 4.6, church_y, 38.6)
		_box(b, tower + Vector3(0.0, 9.5, 0.0), Vector3(4.0, 19.0, 4.0), WHITE)
		_box(b, tower + Vector3(0.0, 15.5, 2.02), Vector3(1.4, 2.4, 0.06), DARK)
		_pyramid(b, tower + Vector3(0.0, 19.0, 0.0), 2.2, 5.0, Color(0.2, 0.3, 0.32))
	_box(b, nave + Vector3(0.0, 2.0, 8.55), Vector3(2.4, 4.0, 0.1), Color(0.3, 0.18, 0.1))
	_box(b, nave + Vector3(0.0, 8.0, 8.52), Vector3(2.0, 2.0, 0.06), Color(0.85, 0.75, 0.4))
	_mark(marks, "IgrejaMatriz", nave)

	# The praça: paths, the bandstand, palms and ipês, benches, lamps.
	var praca: Dictionary = _pad_info("Praca")
	var rect: Rect2 = praca["rect"]
	var py: float = praca["y"]
	var centre: Vector3 = Vector3(rect.get_center().x, py, rect.get_center().y)
	_box(b, centre + Vector3(0.0, 0.05, 0.0), Vector3(rect.size.x, 0.1, 2.4), Color(0.7, 0.66, 0.58))
	_box(b, centre + Vector3(0.0, 0.05, 0.0), Vector3(2.4, 0.1, rect.size.y), Color(0.7, 0.66, 0.58))
	_round(b, centre, 4.5, 0.9, 8, WHITE)
	for i: int in 8:
		var angle: float = TAU * float(i) / 8.0
		_box(b, centre + Vector3(cos(angle) * 4.1, 2.2, sin(angle) * 4.1), Vector3(0.2, 2.6, 0.2), WHITE)
	_cone(b, centre + Vector3(0.0, 3.5, 0.0), 5.0, 2.4, 8, Color(0.25, 0.42, 0.38))
	_mark(marks, "Coreto", centre)
	for quadrant: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var q: Vector3 = centre + Vector3(quadrant.x * rect.size.x * 0.28, 0.0, quadrant.y * rect.size.y * 0.3)
		_palm(b, q + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-2.0, 2.0)), rng.randf_range(9.0, 12.0))
		_broadleaf(_builder("Trees"), q + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-4.0, 4.0)), rng.randf_range(6.0, 8.0), Color(0.62, 0.3, 0.55) if rng.randf() < 0.4 else Color(0.18, 0.34, 0.14))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var lamp: Vector3 = centre + Vector3(corner.x * (rect.size.x * 0.5 - 1.5), 4.0, corner.y * (rect.size.y * 0.5 - 1.5))
		_box(b, lamp + Vector3(0.0, -2.0, 0.0), Vector3(0.15, 4.0, 0.15), Color(0.15, 0.15, 0.15))
		_lit.add_box(lamp + Vector3(0.0, 0.2, 0.0), Vector3(0.45, 0.45, 0.45), LAMP)
		_halo(lamp, 26.0, 1.0)
		_lamps.append(lamp)

	# The station on the line: the building, a canopy over the platform, the warehouse
	# opposite, the railway water tank.
	var station: Dictionary = _pad_info("Station")
	var sy: float = station["y"]
	var station_at: Vector3 = Vector3(160.0, sy, 13.0)
	_box(b, station_at + Vector3(0.0, 2.6, 0.0), Vector3(24.0, 5.2, 6.0), Color(0.86, 0.72, 0.46))
	_gable(b, station_at + Vector3(0.0, 5.2, 0.0), 24.0, 6.0, 1.8, 0.0, ROOF_TILE)
	_box(b, station_at + Vector3(0.0, 3.6, -4.2), Vector3(40.0, 0.2, 3.4), Color(0.3, 0.2, 0.14))
	_box(b, station_at + Vector3(0.0, 0.35, -4.2), Vector3(40.0, 0.7, 3.0), Color(0.55, 0.54, 0.5))
	for i: int in 6:
		_box(b, station_at + Vector3(-18.0 + float(i) * 7.2, 1.8, -5.6), Vector3(0.2, 3.6, 0.2), Color(0.25, 0.2, 0.15))
	for i: int in 5:
		var window: Vector3 = station_at + Vector3(-9.6 + float(i) * 4.8, 2.4, 3.02)
		_window(b, window, Vector3(1.2, 1.6, 0.08), 0.0, rng.randf() < 0.5)
	_mark(marks, "Estacao", station_at)

	var warehouse: Dictionary = _pad_info("Warehouse")
	var wy: float = warehouse["y"]
	var warehouse_at: Vector3 = Vector3(167.0, wy, -3.5)
	_box(b, warehouse_at + Vector3(0.0, 3.0, 0.0), Vector3(30.0, 6.0, 8.0), Color(0.6, 0.35, 0.25))
	_gable(b, warehouse_at + Vector3(0.0, 6.0, 0.0), 30.0, 8.0, 1.6, 0.0, ROOF_FIBRE)
	_mark(marks, "Armazem", warehouse_at)
	var tank: Vector3 = Vector3(190.0, natural_height(190.0, 12.0), 12.0)
	for corner: Vector2 in [Vector2(-1.4, -1.4), Vector2(1.4, -1.4), Vector2(-1.4, 1.4), Vector2(1.4, 1.4)]:
		_box(b, tank + Vector3(corner.x, 4.0, corner.y), Vector3(0.35, 8.0, 0.35), Color(0.25, 0.25, 0.27))
	_round(b, tank + Vector3(0.0, 8.0, 0.0), 2.4, 3.2, 12, Color(0.3, 0.32, 0.34))
	_mark(marks, "CaixaDaguaFerroviaria", tank)

	# The football pitch on the flood plain: dirt, white lines, goals, a few lamp masts.
	var field: Dictionary = _pad_info("Football")
	var fr: Rect2 = field["rect"]
	var fy: float = field["y"]
	var fc: Vector3 = Vector3(fr.get_center().x, fy, fr.get_center().y)
	var line_w: Color = Color(0.9, 0.9, 0.86)
	var half_x: float = 45.0
	var half_z: float = 27.0
	for side: float in [-1.0, 1.0]:
		_box(b, fc + Vector3(0.0, 0.04, side * half_z), Vector3(half_x * 2.0, 0.08, 0.15), line_w)
		_box(b, fc + Vector3(side * half_x, 0.04, 0.0), Vector3(0.15, 0.08, half_z * 2.0), line_w)
		_box(b, fc + Vector3(side * half_x, 1.2, 0.0), Vector3(0.2, 2.4, 7.3), WHITE)
		_box(b, fc + Vector3(side * (half_x - 8.0), 0.04, 0.0), Vector3(0.15, 0.08, 20.0), line_w)
	_box(b, fc + Vector3(0.0, 0.04, 0.0), Vector3(0.15, 0.08, half_z * 2.0), line_w)
	_round(b, fc + Vector3(0.0, 0.0, 0.0), 9.0, 0.06, 20, Color(0.45, 0.38, 0.26))
	_box(b, fc + Vector3(0.0, 1.0, -half_z - 4.0), Vector3(30.0, 2.0, 3.0), Color(0.5, 0.5, 0.48))
	_mark(marks, "CampoDeFutebol", fc)

	# The school: a U of classrooms and a covered court.
	var school: Dictionary = _pad_info("School")
	var sr: Rect2 = school["rect"]
	var scy: float = school["y"]
	var sc: Vector3 = Vector3(sr.get_center().x, scy, sr.get_center().y)
	var school_wall: Color = Color(0.92, 0.85, 0.6)
	_box(b, sc + Vector3(0.0, 1.8, -12.0), Vector3(40.0, 3.6, 7.0), school_wall)
	_box(b, sc + Vector3(-17.0, 1.8, 0.0), Vector3(6.0, 3.6, 18.0), school_wall)
	_box(b, sc + Vector3(17.0, 1.8, 0.0), Vector3(6.0, 3.6, 18.0), school_wall)
	_gable(b, sc + Vector3(0.0, 3.6, -12.0), 40.0, 7.0, 1.3, 0.0, ROOF_TILE)
	_box(b, sc + Vector3(0.0, 0.05, 6.0), Vector3(22.0, 0.1, 13.0), Color(0.35, 0.5, 0.6))
	_box(b, sc + Vector3(0.0, 7.5, 6.0), Vector3(24.0, 0.3, 15.0), ROOF_FIBRE)
	for corner: Vector2 in [Vector2(-11.5, 0.0), Vector2(11.5, 0.0), Vector2(-11.5, 12.0), Vector2(11.5, 12.0)]:
		_box(b, sc + Vector3(corner.x, 3.7, corner.y), Vector3(0.4, 7.4, 0.4), Color(0.5, 0.5, 0.5))
	for i: int in 6:
		_window(b, sc + Vector3(-15.0 + float(i) * 6.0, 2.0, -8.45), Vector3(2.0, 1.2, 0.08), 0.0, rng.randf() < 0.3)
	_mark(marks, "Escola", sc)

	# The petrol station by the road in.
	var petrol: Dictionary = _pad_info("PetrolStation")
	var pr: Rect2 = petrol["rect"]
	var ppy: float = petrol["y"]
	var pc: Vector3 = Vector3(pr.get_center().x, ppy, pr.get_center().y)
	_box(b, pc + Vector3(0.0, 5.0, 2.0), Vector3(16.0, 0.6, 8.0), Color(0.85, 0.85, 0.82))
	for corner: Vector2 in [Vector2(-5.0, 2.0), Vector2(5.0, 2.0)]:
		_box(b, pc + Vector3(corner.x, 2.4, corner.y), Vector3(0.6, 4.8, 0.6), Color(0.8, 0.15, 0.1))
	_box(b, pc + Vector3(0.0, 1.6, -4.5), Vector3(10.0, 3.2, 4.0), WHITE)
	_lit.add_box(pc + Vector3(0.0, 4.65, 2.0), Vector3(15.0, 0.1, 7.0), LAMP)
	_mark(marks, "PostoDeGasolina", pc)

	# The cemetery on the slope: a whitewashed wall and rows of white tombs.
	var cemetery: Dictionary = _pad_info("Cemetery")
	var cr: Rect2 = cemetery["rect"]
	var cy: float = cemetery["y"]
	var cc: Vector3 = Vector3(cr.get_center().x, cy, cr.get_center().y)
	for side: float in [-1.0, 1.0]:
		_box(b, cc + Vector3(0.0, 1.0, side * cr.size.y * 0.5), Vector3(cr.size.x, 2.0, 0.4), WHITE)
		_box(b, cc + Vector3(side * cr.size.x * 0.5, 1.0, 0.0), Vector3(0.4, 2.0, cr.size.y), WHITE)
	for row: int in 6:
		for column: int in 10:
			if rng.randf() < 0.15:
				continue

			var at: Vector3 = cc + Vector3(-16.0 + float(column) * 3.6, 0.0, -11.0 + float(row) * 4.2)
			var tall: float = rng.randf_range(0.6, 1.8)
			_box(b, at + Vector3(0.0, tall * 0.5, 0.0), Vector3(1.0, tall, 2.0), WHITE.darkened(rng.randf_range(0.0, 0.2)))
	_box(b, cc + Vector3(0.0, 2.5, -cr.size.y * 0.5 + 4.0), Vector3(4.0, 5.0, 4.0), WHITE)
	_mark(marks, "Cemiterio", cc)

	# The cruzeiro on the peak, the radio mast with its red light, the water tower.
	var cruzeiro: Dictionary = _pad_info("Cruzeiro")
	var crr: Rect2 = cruzeiro["rect"]
	var cross: Vector3 = Vector3(crr.get_center().x, cruzeiro["y"], crr.get_center().y)
	_box(b, cross + Vector3(0.0, 0.5, 0.0), Vector3(3.0, 1.0, 3.0), Color(0.6, 0.58, 0.55))
	_box(b, cross + Vector3(0.0, 5.5, 0.0), Vector3(0.7, 10.0, 0.7), WHITE)
	_box(b, cross + Vector3(0.0, 8.0, 0.0), Vector3(4.8, 0.7, 0.7), WHITE)
	_lit.add_box(cross + Vector3(0.0, 0.3, 1.8), Vector3(0.4, 0.4, 0.4), LAMP)
	_halo(cross + Vector3(0.0, 0.3, 1.8), 14.0, 0.8)
	_mark(marks, "Cruzeiro", cross)

	var antenna: Dictionary = _pad_info("Antenna")
	var ar: Rect2 = antenna["rect"]
	var mast: Vector3 = Vector3(ar.get_center().x, antenna["y"], ar.get_center().y)
	for level: int in 10:
		var width: float = lerpf(2.4, 0.5, float(level) / 10.0)
		_box(b, mast + Vector3(0.0, 1.5 + float(level) * 3.0, 0.0), Vector3(width, 3.0, width), Color(0.6, 0.6, 0.62) if level % 2 == 0 else Color(0.75, 0.2, 0.15))
	var red: TownMeshBuilder = _builder("RedLight")
	red.add_box(mast + Vector3(0.0, 30.6, 0.0), Vector3(0.6, 0.6, 0.6), Color(1.0, 0.1, 0.05))
	_mark(marks, "Antena", mast)

	var water_tower: Dictionary = _pad_info("WaterTower")
	var wr: Rect2 = water_tower["rect"]
	var wt: Vector3 = Vector3(wr.get_center().x, water_tower["y"], wr.get_center().y)
	_round(b, wt, 1.4, 14.0, 12, Color(0.65, 0.64, 0.6))
	_round(b, wt + Vector3(0.0, 14.0, 0.0), 4.0, 4.0, 16, Color(0.7, 0.69, 0.66))
	_mark(marks, "CaixaDaguaMunicipal", wt)

	# Shops round the praça: the prefeitura, a bank, a pharmacy (the rest are houses).
	_civic(b, Vector3(103.0 - 7.0, py, 65.0), Vector2(12.0, 10.0), PI * 0.5, Color(0.93, 0.86, 0.6), 2, "Prefeitura", marks)


func _mark(parent: Node3D, mark_name: String, at: Vector3) -> void:
	var marker: Marker3D = Marker3D.new()
	marker.name = mark_name
	marker.position = at
	parent.add_child(marker)
	landmarks[mark_name] = at


func _civic(b: TownMeshBuilder, base: Vector3, size: Vector2, yaw: float, wall: Color, floors: int, mark_name: String, marks: Node3D) -> void:
	var height: float = 3.6 * float(floors)
	_box(b, base + Vector3(0.0, height * 0.5, 0.0), Vector3(size.x, height, size.y), wall, yaw)
	_gable(b, base + Vector3(0.0, height, 0.0), size.x, size.y, 1.8, yaw, ROOF_TILE_OLD)
	_mark(marks, mark_name, base)


func _window(b: TownMeshBuilder, center: Vector3, size: Vector3, yaw: float, lit: bool) -> void:
	if lit:
		_lit.add_box(center, size * GLOW_SCALE, LAMP, yaw)
		_halo(center, 8.0, 0.7)
	else:
		b.add_box(center, size, DARK, yaw)


func _palm(b: TownMeshBuilder, base: Vector3, height: float) -> void:
	_box(b, base + Vector3(0.0, height * 0.5, 0.0), Vector3(0.45, height, 0.45), Color(0.45, 0.4, 0.33))
	var top: Vector3 = base + Vector3(0.0, height, 0.0)
	for i: int in 7:
		var angle: float = TAU * float(i) / 7.0
		var tip: Vector3 = top + Vector3(cos(angle) * 3.0, -1.2, sin(angle) * 3.0)
		var side: Vector3 = Vector3(-sin(angle), 0.0, cos(angle)) * 0.5
		b.add_quad(top - side, top + side, tip + side * 0.2, tip - side * 0.2, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color(0.2, 0.38, 0.16))


## A round broadleaf tree as a few boxes (cheap, reads from afar), into `b`.
func _broadleaf(b: TownMeshBuilder, base: Vector3, height: float, color: Color) -> void:
	# Seen from the overlook the yard and pasture trees are real tree instances (the builder plants them).
	if town.vista_mode:
		town.vista_tree_spots.append({"position": base, "height": height, "slim": false})
		tree_count += 1
		return

	b.add_box(base + Vector3(0.0, height * 0.25, 0.0), Vector3(0.35, height * 0.5, 0.35), Color(0.24, 0.18, 0.12))
	var crown: Vector3 = base + Vector3(0.0, height * 0.68, 0.0)
	var r: float = height * 0.3
	b.add_box(crown, Vector3(r * 2.0, r * 1.3, r * 1.6), color, rng.randf() * TAU)
	b.add_box(crown + Vector3(0.0, r * 0.3, 0.0), Vector3(r * 1.5, r * 1.4, r * 2.0), color.lightened(0.05), rng.randf() * TAU)
	tree_count += 1


# ============================================================
# HOUSES
# ============================================================

## Which part of town a point is in, and so what its houses look like.
func _district(p: Vector2, road: Dictionary) -> String:
	if Rect2(72.0, -40.0, 85.0, 32.0).has_point(p):
		return "vila"

	var to_centre: float = p.distance_to(PRACA_CENTRE)
	var ground: Color = road["ground"]
	var is_dirt: bool = ground.r > ground.b + 0.1
	if to_centre < 75.0 and not is_dirt:
		return "centro"

	if to_centre > 230.0 or String(road["id"]).begins_with("EstradaSul") or String(road["id"]).begins_with("EstradaDoSitio") or String(road["id"]).begins_with("EstradaOeste"):
		return "chacara"

	if is_dirt or p.y < -40.0:
		return "periferia"

	return "suburbio"


func _build_houses() -> void:
	# The front row along every road, then a row behind it where lots run deep (the back
	# houses and annexes that fill Brazilian town blocks).
	for row: int in 2:
		for road: Dictionary in roads:
			var lane: TownLane = road["lane"]
			var half: float = road["half"]
			for side: int in [-1, 1]:
				var s: float = rng.randf_range(2.0, 6.0)
				while s < lane.length() - 3.0:
					var index: int = lane.sample_index(s)
					var p: Vector2 = lane.xz(index)
					var district: String = _district(p, road)
					var spec: Dictionary = _house_spec(district)
					var density: float = float(spec["density"]) * (1.0 if row == 0 else float(spec["back"]))
					if rng.randf() > density:
						s += float(spec["gap"]) + rng.randf_range(4.0, 10.0)
						continue

					var width: float = rng.randf_range(spec["w"].x, spec["w"].y)
					var depth: float = rng.randf_range(spec["d"].x, spec["d"].y)
					var setback: float = rng.randf_range(spec["setback"].x, spec["setback"].y)
					if row == 1:
						setback += float(spec["d"].y) + rng.randf_range(2.0, 5.0)

					var placed: bool = _place_house(lane, side, s + width * 0.5, width, depth, half + setback + 1.1, district, spec)
					s += (width + float(spec["gap"]) * rng.randf()) if placed else 1.5


func _house_spec(district: String) -> Dictionary:
	match district:
		"vila":
			return {"density": 1.0, "back": 0.0, "w": Vector2(9.0, 9.0), "d": Vector2(7.0, 7.0), "setback": Vector2(2.0, 2.0), "gap": 1.2, "floors": Vector2i(1, 1)}
		"centro":
			return {"density": 0.97, "back": 0.8, "w": Vector2(5.0, 9.0), "d": Vector2(9.0, 13.0), "setback": Vector2(0.4, 0.6), "gap": 0.1, "floors": Vector2i(1, 2)}
		"periferia":
			return {"density": 0.8, "back": 0.55, "w": Vector2(4.0, 7.0), "d": Vector2(5.0, 8.0), "setback": Vector2(0.5, 5.0), "gap": 3.0, "floors": Vector2i(1, 2)}
		"chacara":
			return {"density": 0.12, "back": 0.0, "w": Vector2(7.0, 11.0), "d": Vector2(7.0, 10.0), "setback": Vector2(8.0, 18.0), "gap": 30.0, "floors": Vector2i(1, 1)}
		_:
			return {"density": 0.95, "back": 0.65, "w": Vector2(5.0, 9.0), "d": Vector2(6.0, 10.0), "setback": Vector2(1.0, 4.0), "gap": 1.5, "floors": Vector2i(1, 2)}


func _place_house(lane: TownLane, side: int, s: float, width: float, depth: float, offset: float, district: String, spec: Dictionary) -> bool:
	var index: int = lane.sample_index(s)
	var normal: Vector2 = lane.right_normal(index) * float(side)
	var centre: Vector2 = lane.xz(index) + normal * (offset + depth * 0.5)
	if town.vista_mode and not in_limits(centre.x, centre.y):
		return false

	var front: Vector2 = -normal
	var yaw: float = atan2(front.x, front.y)
	var ax: Vector2 = Vector2(cos(yaw), -sin(yaw))
	var az: Vector2 = Vector2(sin(yaw), cos(yaw))
	# The whole footprint (and a little room round it) must be free.
	var steps_x: int = int(ceil(width / OCC_CELL)) + 1
	var steps_z: int = int(ceil(depth / OCC_CELL)) + 1
	for i: int in steps_x + 1:
		for j: int in steps_z + 1:
			var local: Vector2 = Vector2(-width * 0.5 - 0.3 + float(i) * (width + 0.6) / float(steps_x), -depth * 0.5 - 0.3 + float(j) * (depth + 0.6) / float(steps_z))
			var p: Vector2 = centre + ax * local.x + az * local.y
			if _occupied(p.x, p.y):
				return false

	var base_y: float = lane.points[index].y + 0.1
	var lowest: float = base_y
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = centre + ax * corner.x * width * 0.5 + az * corner.y * depth * 0.5
		lowest = minf(lowest, height_at(p.x, p.y))

	# On a slope the house stands on the higher ground behind (a terrace) rather than on
	# stilts; where even that would leave it hanging over a drop, nobody builds.
	var back_point: Vector2 = centre - az * (depth * 0.5)
	base_y = maxf(base_y, minf(height_at(back_point.x, back_point.y), base_y + 2.5))
	if base_y - lowest > 3.2:
		return false

	for i: int in steps_x + 1:
		for j: int in steps_z + 1:
			var local: Vector2 = Vector2(-width * 0.5 + float(i) * width / float(steps_x), -depth * 0.5 + float(j) * depth / float(steps_z))
			var p: Vector2 = centre + ax * local.x + az * local.y
			var k: int = _occ_index(p.x, p.y)
			if k >= 0:
				occupancy[k] = 1

	var drop: float = base_y - lowest + 0.3
	var floors: int = rng.randi_range(spec["floors"].x, spec["floors"].y)
	_house_mesh(district, Vector3(centre.x, base_y, centre.y), yaw, width, depth, floors, drop)
	house_count += 1
	if district == "chacara":
		for t: int in rng.randi_range(2, 5):
			var spot: Vector2 = centre + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))
			if not _occupied(spot.x, spot.y):
				_broadleaf(_builder("Trees"), Vector3(spot.x, height_at(spot.x, spot.y), spot.y), rng.randf_range(4.0, 7.0), Color(0.2, 0.36, 0.14))
				_mark_disc(spot.x, spot.y, 1.5)

	return true


func _house_mesh(district: String, base: Vector3, yaw: float, width: float, depth: float, floors: int, drop: float) -> void:
	var b: TownMeshBuilder = _builder("Houses_%s" % district)
	var story: float = 3.0 + rng.randf_range(0.0, 0.4)
	var height: float = story * float(floors)
	var wall: Color
	var roof: Color
	match district:
		"vila":
			wall = Color(0.92, 0.88, 0.78) if rng.randf() < 0.7 else Color(0.82, 0.72, 0.55)
			roof = ROOF_TILE
		"centro":
			wall = PAINTS[rng.randi() % PAINTS.size()]
			roof = ROOF_TILE if rng.randf() < 0.7 else ROOF_TILE_OLD
		"periferia":
			wall = PERIPHERY[rng.randi() % PERIPHERY.size()]
			roof = ROOF_FIBRE if rng.randf() < 0.6 else ROOF_TILE
		"chacara":
			wall = PAINTS[rng.randi() % PAINTS.size()].lerp(WHITE, 0.4)
			roof = ROOF_TILE
		_:
			wall = PAINTS[rng.randi() % PAINTS.size()] if rng.randf() < 0.75 else PERIPHERY[rng.randi() % PERIPHERY.size()]
			roof = ROOF_TILE if rng.randf() < 0.65 else ROOF_FIBRE

	var basis: Basis = Basis(Vector3.UP, yaw)
	b.add_box(base + Vector3(0.0, (height - drop) * 0.5, 0.0), Vector3(width, height + drop, depth), wall, yaw)
	var flat_roof: bool = district == "periferia" and rng.randf() < 0.3
	if flat_roof:
		b.add_box(base + Vector3(0.0, height + 0.1, 0.0), Vector3(width + 0.3, 0.2, depth + 0.3), ROOF_FIBRE, yaw)
		if rng.randf() < 0.5:
			# A blue water tank on the slab, as on half the roofs of the periphery.
			b.add_box(base + basis * Vector3(width * 0.25, height + 0.75, 0.0), Vector3(1.1, 1.1, 1.1), Color(0.2, 0.35, 0.6), yaw)
	else:
		var rise: float = depth * rng.randf_range(0.18, 0.26)
		_gable(b, base + Vector3(0.0, height, 0.0), width, depth, rise, yaw, roof)

	# A door and windows on the front, some of them lit.
	var face: float = depth * 0.5 + 0.03
	var door_x: float = width * 0.25 * (1.0 if rng.randf() < 0.5 else -1.0)
	b.add_box(base + basis * Vector3(door_x, 1.05, face), Vector3(0.95, 2.1, 0.06), Color(0.3, 0.2, 0.12), yaw)
	var lit_chance: float = 0.4 if district != "chacara" else 0.55
	# Seen from the overlook the town should have fewer lights (the dark is the point), so in vista
	# mode far fewer windows are lit. The random draws are the same, so nothing else moves.
	if town.vista_mode:
		lit_chance *= VISTA_LIT_SCALE
	var count: int = maxi(int((width - 1.0) / 2.2), 1)
	for f: int in floors:
		for k: int in count:
			var x: float = -width * 0.5 + (float(k) + 0.5) * width / float(count)
			if f == 0 and absf(x - door_x) < 1.1:
				continue

			_window(b, base + basis * Vector3(x, float(f) * story + 1.6, face), Vector3(1.0, 1.1, 0.06), yaw, rng.randf() < lit_chance)

	# A shop's awning on the ground floor in the centre.
	if district == "centro" and rng.randf() < 0.45:
		b.add_box(base + basis * Vector3(0.0, 2.7, face + 0.6), Vector3(width * 0.8, 0.1, 1.2), PAINTS[rng.randi() % PAINTS.size()].darkened(0.2), yaw)


# ============================================================
# FARMS AND FOREST
# ============================================================

func _build_farms(root: Node3D) -> void:
	var eucalyptus_spots: Array[Transform3D] = []
	var fences: TownMeshBuilder = _builder("Fences")
	var trees: TownMeshBuilder = _builder("Trees")
	for farm: Dictionary in farms:
		var rect: Rect2 = farm["rect"]
		match String(farm["kind"]):
			"pasture":
				# A fence round it: posts and two wires (as thin boxes).
				var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
				for i: int in 4:
					var a: Vector2 = corners[i]
					var c: Vector2 = corners[(i + 1) % 4]
					var length: float = a.distance_to(c)
					var posts: int = int(length / 4.0)
					for p: int in posts + 1:
						var at: Vector2 = a.lerp(c, float(p) / float(posts))
						if _occupied(at.x, at.y):
							continue

						fences.add_box(Vector3(at.x, height_at(at.x, at.y) + 0.6, at.y), Vector3(0.12, 1.2, 0.12), Color(0.35, 0.27, 0.18))

				# A few lone trees for shade, as in every pasture.
				for t: int in 6:
					var spot: Vector2 = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
					if not _occupied(spot.x, spot.y):
						_broadleaf(trees, Vector3(spot.x, height_at(spot.x, spot.y), spot.y), rng.randf_range(7.0, 11.0), Color(0.2, 0.33, 0.13))

				_mark_rect(rect)
			"coffee":
				var z: float = rect.position.y
				while z < rect.end.y:
					var x: float = rect.position.x
					while x < rect.end.x:
						if not _occupied(x, z):
							trees.add_box(Vector3(x, height_at(x, z) + 0.8, z), Vector3(1.6, 1.6, 1.4), Color(0.06, 0.14, 0.05))

						x += 2.2
					z += 3.2

				_mark_rect(rect)
			"eucalyptus":
				var z2: float = rect.position.y
				while z2 < rect.end.y:
					var x2: float = rect.position.x
					while x2 < rect.end.x:
						if not _occupied(x2, z2):
							var tall: float = rng.randf_range(0.85, 1.25)
							var euc_basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, tall, 1.0))
							eucalyptus_spots.append(Transform3D(euc_basis, Vector3(x2, height_at(x2, z2), z2)))
							tree_count += 1

						x2 += 4.0
					z2 += 4.0

				_mark_rect(rect)
			"banana":
				for t: int in 160:
					var spot: Vector2 = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
					if _occupied(spot.x, spot.y):
						continue

					var base2: Vector3 = Vector3(spot.x, height_at(spot.x, spot.y), spot.y)
					trees.add_box(base2 + Vector3(0.0, 1.4, 0.0), Vector3(0.3, 2.8, 0.3), Color(0.35, 0.4, 0.2))
					for leaf: int in 4:
						var angle: float = TAU * float(leaf) / 4.0 + rng.randf()
						trees.add_box(base2 + Vector3(cos(angle) * 1.0, 3.0, sin(angle) * 1.0), Vector3(2.2, 0.1, 0.7), Color(0.25, 0.45, 0.15), -angle)

				_mark_rect(rect)

	_eucalyptus(root, eucalyptus_spots)


## Atlantic forest on every free piece of ground outside the core: dense on the hills, thin
## near town. Broadleaf crowns and some araucárias, as two MultiMeshes.
func _build_forest(root: Node3D) -> void:
	var round_spots: Array[Transform3D] = []
	var pine_spots: Array[Transform3D] = []
	# The vista's forest is not part of this scene: it is planted as Terrain3D instances.
	if town.vista_mode:
		return

	var x: float = X0 + 3.0
	while x < X0 + SIZE - 3.0:
		var z: float = Z0 + 3.0
		while z < Z0 + SIZE - 3.0:
			var px: float = x + rng.randf_range(-2.5, 2.5)
			var pz: float = z + rng.randf_range(-2.5, 2.5)
			z += 6.0
			if CORE.has_point(Vector2(px, pz)) or _occupied(px, pz):
				continue

			# Thin near the town (yards, a few big trees), dense on the far hills.
			var to_town: float = minf(Vector2(px, pz).distance_to(PRACA_CENTRE), _outside_core(px, pz) + 40.0)
			var density: float = clampf((to_town - 70.0) / 110.0, 0.08, 1.0)
			if paint_at(px, pz).a > 0.5:
				density *= 0.1
			if rng.randf() > density:
				continue

			var y: float = natural_height(px, pz)
			var tree_scale: float = rng.randf_range(0.8, 1.5)
			var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(tree_scale, tree_scale * rng.randf_range(0.9, 1.3), tree_scale))
			if rng.randf() < 0.18:
				pine_spots.append(Transform3D(basis, Vector3(px, y, pz)))
			else:
				round_spots.append(Transform3D(basis, Vector3(px, y, pz)))

		x += 6.0

	# The forest goes on over the first slopes of the serra (beyond that the ring's own dark
	# green reads as forest).
	var band: float = 380.0
	var bx: float = X0 - band
	while bx < X0 + SIZE + band:
		var bz: float = Z0 - band
		while bz < Z0 + SIZE + band:
			var px: float = bx + rng.randf_range(-4.0, 4.0)
			var pz: float = bz + rng.randf_range(-4.0, 4.0)
			bz += 9.0
			var beyond: float = _beyond_edge(px, pz)
			if beyond < 2.0 or rng.randf() > lerpf(0.9, 0.25, beyond / band):
				continue

			var ring_scale: float = rng.randf_range(1.0, 1.8)
			var ring_basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ring_scale, ring_scale, ring_scale))
			round_spots.append(Transform3D(ring_basis, Vector3(px, horizon_height(px, pz), pz)))

		bx += 9.0

	_forest_meshes(root, round_spots, pine_spots)


func _forest_meshes(root: Node3D, round_spots: Array[Transform3D], pine_spots: Array[Transform3D]) -> void:
	var crown: SphereMesh = SphereMesh.new()
	crown.radius = 2.6
	crown.height = 4.2
	crown.radial_segments = 7
	crown.rings = 3
	_multimesh(root, "ForestCrowns", crown, round_spots, Vector3(0.0, 6.5, 0.0), Color(0.12, 0.27, 0.11))
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = 0.2
	trunk.bottom_radius = 0.3
	trunk.height = 5.0
	trunk.radial_segments = 5
	trunk.rings = 1
	_multimesh(root, "ForestTrunks", trunk, round_spots, Vector3(0.0, 2.5, 0.0), Color(0.22, 0.17, 0.12))
	# Araucárias: a tall bare trunk and a flat crown.
	var pine_trunk: CylinderMesh = CylinderMesh.new()
	pine_trunk.top_radius = 0.18
	pine_trunk.bottom_radius = 0.3
	pine_trunk.height = 13.0
	pine_trunk.radial_segments = 5
	pine_trunk.rings = 1
	_multimesh(root, "AraucariaTrunks", pine_trunk, pine_spots, Vector3(0.0, 6.5, 0.0), Color(0.25, 0.18, 0.13))
	var pine_crown: CylinderMesh = CylinderMesh.new()
	pine_crown.top_radius = 3.0
	pine_crown.bottom_radius = 1.0
	pine_crown.height = 2.0
	pine_crown.radial_segments = 8
	pine_crown.rings = 1
	_multimesh(root, "AraucariaCrowns", pine_crown, pine_spots, Vector3(0.0, 13.5, 0.0), Color(0.1, 0.22, 0.12))
	tree_count += round_spots.size() + pine_spots.size()


## The eucalyptus plantation: slim pale trunks and narrow dark crowns, in rows.
func _eucalyptus(root: Node3D, spots: Array[Transform3D]) -> void:
	if town.vista_mode:
		# Seen from far away: planted as Terrain3D instances (the medium tree, stretched slim and tall).
		_eucalyptus_spots = spots
		return

	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.2
	trunk.height = 16.0
	trunk.radial_segments = 5
	trunk.rings = 1
	_multimesh(root, "EucalyptusTrunks", trunk, spots, Vector3(0.0, 8.0, 0.0), Color(0.34, 0.31, 0.26))
	var crown: SphereMesh = SphereMesh.new()
	crown.radius = 1.7
	crown.height = 9.0
	crown.radial_segments = 6
	crown.rings = 3
	_multimesh(root, "EucalyptusCrowns", crown, spots, Vector3(0.0, 15.0, 0.0), Color(0.07, 0.14, 0.09))

func _multimesh(root: Node3D, mesh_name: String, mesh: Mesh, spots: Array[Transform3D], offset: Vector3, color: Color) -> void:
	if spots.is_empty():
		return

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for i: int in spots.size():
		var spot: Transform3D = spots[i]
		multimesh.set_instance_transform(i, Transform3D(spot.basis, spot.origin + spot.basis * offset))

	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = mesh_name
	instance.multimesh = multimesh
	instance.material_override = town._mat(color)
	root.add_child(instance)


## Where the lit points are (street lamps of the scenery), for the core's lamp lights.
func lamp_points() -> Array[Vector3]:
	return _lamps


## True where the scenery built something (a house, a road, a pad) or near the playable area.
func occupied_by_scenery(x: float, z: float) -> bool:
	return occ_n > 0 and _occupied(x, z)


## The serra round the valley out to the horizon: a coarse ring of forested mountains from
## the edge of the map (where it meets the ground's own heights) to 1.6 km out, rising to a
## couple of hundred metres, so the view from the overlook has no edge.
func _build_horizon(root: Node3D) -> void:
	const CELL: float = 30.0
	const REACH: float = 1650.0
	var n: int = int(REACH * 2.0 / CELL) + 1
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	vertices.resize(n * n)
	colors.resize(n * n)
	var inner: Rect2 = Rect2(X0, Z0, SIZE, SIZE)
	for gz: int in n:
		for gx: int in n:
			var x: float = -REACH + float(gx) * CELL
			var z: float = -REACH + float(gz) * CELL
			var beyond: float = _beyond_edge(x, z)
			var y: float = horizon_height(x, z)
			if inner.has_point(Vector2(x, z)):
				y = natural_height(x, z) - 0.8

			vertices[gz * n + gx] = Vector3(x, y, z)
			var shade: float = _horizon_noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5
			var forest: Color = Color(0.05, 0.13, 0.06).lerp(Color(0.1, 0.19, 0.08), shade)
			colors[gz * n + gx] = forest.lerp(Color(0.2, 0.26, 0.24), smoothstep(400.0, 1500.0, beyond) * 0.6)

	var indices: PackedInt32Array = PackedInt32Array()
	for gz: int in n - 1:
		for gx: int in n - 1:
			var x0: float = -REACH + float(gx) * CELL
			var z0: float = -REACH + float(gz) * CELL
			if x0 >= X0 and x0 + CELL <= X0 + SIZE and z0 >= Z0 and z0 + CELL <= Z0 + SIZE:
				continue

			var a: int = gz * n + gx
			indices.append_array(PackedInt32Array([a, a + 1, a + n + 1, a, a + n + 1, a + n]))

	# A skirt under the edge of the detailed ground, so no gap shows where they meet.
	var skirt: TownMeshBuilder = TownMeshBuilder.new()
	var corners: Array[Vector2] = [Vector2(X0, Z0), Vector2(X0 + SIZE, Z0), Vector2(X0 + SIZE, Z0 + SIZE), Vector2(X0, Z0 + SIZE)]
	for side: int in 4:
		var a: Vector2 = corners[side]
		var c: Vector2 = corners[(side + 1) % 4]
		var steps: int = int(SIZE / STEP)
		for i: int in steps:
			var p0: Vector2 = a.lerp(c, float(i) / float(steps))
			var p1: Vector2 = a.lerp(c, float(i + 1) / float(steps))
			var y0: float = natural_height(p0.x, p0.y)
			var y1: float = natural_height(p1.x, p1.y)
			var outward: Vector3 = Vector3(p0.x + p1.x, 0.0, p0.y + p1.y) * 0.5
			skirt.add_quad(Vector3(p0.x, y0, p0.y), Vector3(p1.x, y1, p1.y), Vector3(p1.x, y1 - 25.0, p1.y), Vector3(p0.x, y0 - 25.0, p0.y), outward, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color(0.15, 0.2, 0.1))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Normals from the faces (the ring is coarse; flat-ish shading reads as ridges).
	var tool: SurfaceTool = SurfaceTool.new()
	tool.create_from(mesh, 0)
	tool.generate_normals()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var horizon: MeshInstance3D = town._solid_mesh(root, "Serra", tool.commit(), material, false)
	horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	town._solid_mesh(root, "GroundSkirt", skirt.build(), town._vertex_material(), false)


func _beyond_edge(x: float, z: float) -> float:
	var edge: Vector2 = Vector2(clampf(x, X0, X0 + SIZE), clampf(z, Z0, Z0 + SIZE))
	return Vector2(x, z).distance_to(edge)


## The height of the serra outside the detailed ground: it starts at the map edge's height
## and rises over the first ~700 m to mountains of 100-250 m.
func horizon_height(x: float, z: float) -> float:
	var edge: Vector2 = Vector2(clampf(x, X0, X0 + SIZE), clampf(z, Z0, Z0 + SIZE))
	var beyond: float = Vector2(x, z).distance_to(edge)
	var y: float = natural_height(edge.x, edge.y) - 0.8
	var rise: float = smoothstep(0.0, 700.0, beyond)
	return y + rise * (90.0 + _horizon_noise.get_noise_2d(x, z) * 140.0) + beyond * 0.02


## A glowing window or lamp of the core (town-local, from `TownBlockout` in vista mode).
func lit_window(center: Vector3, size: Vector3, yaw: float) -> void:
	_lit.add_box(center, size * GLOW_SCALE, LAMP, yaw)
	_halo(center, 8.0, 0.7)


func lit_lamp(point: Vector3) -> void:
	_lit.add_box(point, Vector3(0.9, 0.6, 0.9), LAMP)
	_halo(point, 26.0, 1.0)


# ============================================================
# THE VISTA (seen from the dream intro's overlook)
# ============================================================

## Is the town-local point inside the Terrain3D that holds the ground (the world limits)?
func in_limits(x: float, z: float) -> bool:
	var world: Vector3 = town.global_transform * Vector3(x, 0.0, z)
	return town.vista_limits_world.has_point(Vector2(world.x, world.z))


func _view_local() -> Vector2:
	var local: Vector3 = town.global_transform.affine_inverse() * Vector3(town.vista_overlook_world.x, 0.0, town.vista_overlook_world.y)
	return Vector2(local.x, local.z)


## The ground height (town-local) of the whole vista: the core's carved ground and the shaped
## valley inside the 660 m square, mountains beyond it. On the side of the overlook the
## mountains fall away to the valley floor (`floor_height`), so nothing hides the town.
func vista_height(x: float, z: float, floor_height: float) -> float:
	if x >= X0 and x <= X0 + SIZE and z >= Z0 and z <= Z0 + SIZE:
		return height_at(x, z)

	var edge: Vector2 = Vector2(clampf(x, X0, X0 + SIZE), clampf(z, Z0, Z0 + SIZE))
	var beyond: float = Vector2(x, z).distance_to(edge)
	var edge_height: float = natural_height(edge.x, edge.y)
	var rise: float = smoothstep(0.0, 300.0, beyond) * (85.0 + _horizon_noise.get_noise_2d(x, z) * 50.0) + beyond * 0.05
	var open: float = smoothstep(260.0, 470.0, Vector2(x, z).distance_to(_view_local()))
	# The valley floor is not a plane: soft swells and hollows (a few metres) and small bumps.
	var swell: float = _noise_a.get_noise_2d(x, z) * 8.0 + _noise_b.get_noise_2d(x, z) * 2.0
	var masked: float = lerpf(floor_height + swell, edge_height + rise, open)
	return lerpf(edge_height, masked, smoothstep(0.0, 90.0, beyond))


## The kind of ground painted at a town-local point (inside the 660 m square), KIND_NONE if
## it is natural.
func kind_at(x: float, z: float) -> int:
	if x < X0 or x > X0 + SIZE or z < Z0 or z > Z0 + SIZE:
		return KIND_NONE

	var gx: int = clampi(roundi((x - X0) / STEP), 0, grid_n - 1)
	var gz: int = clampi(roundi((z - Z0) / STEP), 0, grid_n - 1)
	var k: int = _index(gx, gz)
	return kinds[k] if paint[k].a > 0.35 else KIND_NONE


## The trees of the vista are Terrain3D mesh instances (the dream intro's instancer, painted
## into the terrain's regions by `TownVistaBuilder`), not meshes of this scene: this only
## decides WHERE they stand. The species are the builder's four vista mesh assets.
const TREE_MEDIUM: int = 0
const TREE_BROAD: int = 1
const TREE_PITANGUEIRA: int = 2
const TREE_ARAUCARIA: int = 3
## The vista forest is planted on this grid and thinned out with distance.
const FOREST_GRID: float = 6.0


## Town-local height of the real baked ground at a town-local point (`ground` is a callable:
## world (x, z) -> world height, NAN where there is none).
func _vista_ground(ground: Callable, x: float, z: float) -> float:
	var world: Vector3 = town.global_transform * Vector3(x, 0.0, z)
	var height: float = ground.call(Vector2(world.x, world.z))
	return height - town.global_transform.origin.y


## Where the vista's INDIVIDUAL trees stand, on the real Terrain3D ground: a list of
## `{"species": TREE_*, "transform": Transform3D (town-local)}`. Only the near ring (within
## `near_radius` of the overlook) and the town's own square get single trees (yards, a few big
## ones; dense on the far hills of the square): everything farther is planted as stands by the
## builder. `stand` (world x, z -> TREE_*) gives one species per 64 m block, so the instancer
## draws one mesh per cell. Keeps off cliffs and off the town (yards, roads, farms). Deterministic.
func vista_forest_spots(ground: Callable, stand: Callable, grove: Callable, owned: Callable, covered: Callable, near_radius: float) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var view: Vector2 = _view_local()
	var reach: float = 330.0 + 330.0
	var forest_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	forest_rng.seed = town.seed_value + 303
	var x: float = -reach
	while x < reach:
		var z: float = -reach
		while z < reach:
			var px: float = x + forest_rng.randf_range(-3.0, 3.0)
			var pz: float = z + forest_rng.randf_range(-3.0, 3.0)
			z += FOREST_GRID
			var away: float = Vector2(px, pz).distance_to(view)
			if not in_limits(px, pz) or away < 40.0:
				continue

			var inside: bool = px >= X0 and px <= X0 + SIZE and pz >= Z0 and pz <= Z0 + SIZE
			if not inside and away > near_radius:
				continue

			if inside and (_occupied(px, pz) or kind_at(px, pz) != KIND_NONE):
				continue

			var world: Vector3 = town.global_transform * Vector3(px, 0.0, pz)
			# Only on ground the vista made (never on the authored forest and paths).
			if not bool(owned.call(Vector2(world.x, world.z))):
				continue

			# Not where a canopy stand (the far forest) already covers the ground.
			if bool(covered.call(Vector2(world.x, world.z))):
				continue

			# Groves and clearings (always forest on the high ground).
			var density: float = float(grove.call(Vector2(world.x, world.z)))
			if inside:
				# Thin near the town (yards, a few big trees), dense on the far hills.
				var to_town: float = minf(Vector2(px, pz).distance_to(PRACA_CENTRE), _outside_core(px, pz) + 40.0)
				density *= clampf((to_town - 70.0) / 110.0, 0.08, 1.0)

			# The spacing grows with distance (the far trees are small on the screen).
			var far: float = smoothstep(150.0, 700.0, away)
			var spacing: float = lerpf(8.0, 13.0, far)
			if forest_rng.randf() > density * pow(FOREST_GRID / spacing, 2.0):
				continue

			var height: float = _vista_ground(ground, px, pz)
			if is_nan(height):
				continue

			# Not on cliffs (the instance would hang over the drop).
			var rise: float = maxf(absf(_vista_ground(ground, px + 3.0, pz) - height), absf(_vista_ground(ground, px, pz + 3.0) - height))
			if rise > 3.2:
				continue

			var species: int = stand.call(Vector2(world.x, world.z))
			var tree_scale: float = forest_rng.randf_range(1.0, 1.5) + far * 0.7
			if species == TREE_ARAUCARIA:
				tree_scale = forest_rng.randf_range(0.9, 1.3)

			var basis: Basis = Basis(Vector3.UP, forest_rng.randf() * TAU).scaled(Vector3(tree_scale, tree_scale * forest_rng.randf_range(0.9, 1.2), tree_scale))
			spots.append({"species": species, "transform": Transform3D(basis, Vector3(px, height - 0.15, pz))})

		x += FOREST_GRID

	return spots


## The eucalyptus plantations' trees (town-local), for the builder to plant as instances.
func vista_eucalyptus_spots() -> Array[Transform3D]:
	return _eucalyptus_spots


## Is this town-local point free of the town (nothing built, painted or fenced, and away from the
## centre), so a canopy stand of the far forest can cover it? Outside the 660 m square: always.
func vista_spot_free(x: float, z: float) -> bool:
	if x < X0 or x > X0 + SIZE or z < Z0 or z > Z0 + SIZE:
		return true

	if _occupied(x, z) or kind_at(x, z) != KIND_NONE:
		return false

	return minf(Vector2(x, z).distance_to(PRACA_CENTRE), _outside_core(x, z) + 40.0) > 100.0


# ============================================================
# THE GLOW (light scattering in the night mist, seen from the overlook)
# ============================================================

func _halo(point: Vector3, size: float, strength: float) -> void:
	if town.vista_mode:
		_halos.append({"p": point, "s": size, "a": strength})


## A soft round glow (white in the middle, nothing at the rim).
func _halo_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.35, 0.65, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


## Billboard halos (one additive MultiMesh, one draw call) round the lit windows and lamps:
## a warm core on each, and a wide teal haze over every cluster of lights, like street lights in
## a fog (the light scatters in the mist and the city glows). Not lights: nothing is lit by them.
func _build_halos(root: Node3D) -> void:
	if not town.vista_mode or _halos.is_empty():
		return

	var spots: Array[Transform3D] = []
	var colors: PackedColorArray = PackedColorArray()
	var clusters: Dictionary = {}
	for halo: Dictionary in _halos:
		var p: Vector3 = halo["p"]
		var size: float = halo["s"]
		var strength: float = halo["a"]
		spots.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), p))
		colors.append(Color(1.0, 0.74, 0.46, 0.2 * strength * strength))
		var key: Vector2i = Vector2i(floori(p.x / 18.0), floori(p.z / 18.0))
		if not clusters.has(key):
			clusters[key] = {"sum": Vector3.ZERO, "n": 0.0}

		clusters[key]["sum"] += p
		clusters[key]["n"] += strength

	for key: Vector2i in clusters:
		var n: float = clusters[key]["n"]
		var centre: Vector3 = (clusters[key]["sum"] as Vector3) / maxf(n, 1.0)
		var wide: float = clampf(34.0 + n * 3.0, 34.0, 80.0)
		spots.append(Transform3D(Basis.IDENTITY.scaled(Vector3(wide, wide, wide)), centre))
		colors.append(Color(0.3, 0.75, 0.7, clampf(0.014 * n, 0.02, 0.09)))

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _halo_texture()
	material.disable_receive_shadows = true
	quad.material = material
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = spots.size()
	for i: int in spots.size():
		multimesh.set_instance_transform(i, spots[i])
		multimesh.set_instance_color(i, colors[i])

	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "NightGlow"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(X0 - 100.0, -150.0, Z0 - 100.0), Vector3(SIZE + 200.0, 500.0, SIZE + 200.0))
	root.add_child(instance)
