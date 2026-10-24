extends Node

## Bakes the picture of the forest map (`ForestMapProps.TEXTURE_PATH`) from the real world: the Terrain3D cells painted
## with the path texture become the trails, drawn in ink on aged paper, with the railway, a hand drawn border, a
## compass, an icon for each place of the story (`ForestMapProps.LANDMARKS`) and a scatter of small trees. The names of
## the places are not in the picture: they are words in the world (Label3D) so they can be translated.
##
## Run it again whenever the trails or the places move (one Godot at a time; no window is needed):
##   Godot --headless --path . res://tools/bake_forest_map.tscn
## then `--import` so the picture is imported.

const LEVEL_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
## The Terrain3D base texture slot that is the dirt path.
const PATH_TEXTURE: int = 1
const BAKE_SAVE_DIRECTORY: String = "res://.godot/map_bake"

const PAPER_LIGHT: Color = Color(0.85, 0.77, 0.58)
const PAPER_DARK: Color = Color(0.68, 0.57, 0.37)
const STAIN: Color = Color(0.46, 0.31, 0.17)
const INK: Color = ForestMapProps.INK_COLOR

var _image: Image = null
var _wobble: FastNoiseLite = FastNoiseLite.new()
var _width: int = 0
var _height: int = 0


func _ready() -> void:
	# The level wants a save slot to be playing; this one is thrown away.
	SaveManager.save_directory = BAKE_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, LEVEL_PATH, "x", "SAVE_LOCATION_DREAM_INTRO")
	var level: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().create_timer(2.0).timeout

	var terrain: Terrain3D = level.get_node("Terrain3D") as Terrain3D
	var cells: PackedFloat32Array = _sample_path_cells(terrain)
	SaveManager.delete_slot(1)

	_wobble.seed = 31
	_wobble.frequency = 0.12
	var picture: Vector2i = ForestMapProps.picture_size()
	_width = picture.x
	_height = picture.y
	_image = Image.create(_width, _height, false, Image.FORMAT_RGBA8)
	var smooth: PackedFloat32Array = _paint_paper_and_trails(cells)
	_draw_railway()
	_draw_border()
	_draw_compass()
	_draw_trees(cells, smooth)
	for landmark: Dictionary in ForestMapProps.LANDMARKS:
		_draw_icon(str(landmark["shape"]), ForestMapProps.world_to_pixel(landmark["at"]))

	var error: int = _image.save_png(ProjectSettings.globalize_path(ForestMapProps.TEXTURE_PATH))
	print("[bake_forest_map] %dx%d, saved: %s" % [_width, _height, error_string(error)])
	get_tree().quit(0 if error == OK else 1)


# ============================================================
# THE WORLD
# ============================================================

## One value for each metre of the world (at the integer coordinates): 1 where the ground is the path.
func _sample_path_cells(terrain: Terrain3D) -> PackedFloat32Array:
	var columns: int = int(ForestMapProps.WORLD_SIZE.x) + 1
	var rows: int = int(ForestMapProps.WORLD_SIZE.y) + 1
	var cells: PackedFloat32Array = PackedFloat32Array()
	cells.resize(columns * rows)
	var path_cells: int = 0
	for row: int in rows:
		for column: int in columns:
			var spot: Vector3 = Vector3(ForestMapProps.WORLD_MIN.x + column, 0.0, ForestMapProps.WORLD_MIN.y + row)
			var id: Vector3 = terrain.data.get_texture_id(spot)
			var is_path: bool = int(id.x) == PATH_TEXTURE or (int(id.y) == PATH_TEXTURE and id.z > 0.5)
			cells[row * columns + column] = 1.0 if is_path else 0.0
			path_cells += 1 if is_path else 0

	print("[bake_forest_map] path cells: %d" % path_cells)
	return cells


## The cells smoothed to the picture's resolution (bilinear, then blurred), so the trails have soft, round edges.
func _upsample(cells: PackedFloat32Array) -> PackedFloat32Array:
	var columns: int = int(ForestMapProps.WORLD_SIZE.x) + 1
	var rows: int = int(ForestMapProps.WORLD_SIZE.y) + 1
	var per_meter: float = float(ForestMapProps.PIXELS_PER_METER)
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(_width * _height)
	for y: int in _height:
		var world_y: float = (float(y) + 0.5) / per_meter
		var row: int = mini(int(floorf(world_y)), rows - 2)
		var ty: float = world_y - float(row)
		for x: int in _width:
			var world_x: float = (float(x) + 0.5) / per_meter
			var column: int = mini(int(floorf(world_x)), columns - 2)
			var tx: float = world_x - float(column)
			var top: float = lerpf(cells[row * columns + column], cells[row * columns + column + 1], tx)
			var bottom: float = lerpf(cells[(row + 1) * columns + column], cells[(row + 1) * columns + column + 1], tx)
			field[y * _width + x] = lerpf(top, bottom, ty)

	return field


func _blur(source: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var span: float = float(radius * 2 + 1)
	var across: PackedFloat32Array = PackedFloat32Array()
	across.resize(source.size())
	for y: int in _height:
		var total: float = 0.0
		for x: int in range(-radius, radius + 1):
			total += source[y * _width + clampi(x, 0, _width - 1)]

		for x: int in _width:
			across[y * _width + x] = total / span
			total += source[y * _width + clampi(x + radius + 1, 0, _width - 1)] - source[y * _width + clampi(x - radius, 0, _width - 1)]

	var down: PackedFloat32Array = PackedFloat32Array()
	down.resize(source.size())
	for x: int in _width:
		var total: float = 0.0
		for y: int in range(-radius, radius + 1):
			total += across[clampi(y, 0, _height - 1) * _width + x]

		for y: int in _height:
			down[y * _width + x] = total / span
			total += across[clampi(y + radius + 1, 0, _height - 1) * _width + x] - across[clampi(y - radius, 0, _height - 1) * _width + x]

	return down


# ============================================================
# THE PAPER AND THE TRAILS
# ============================================================

## Paints the aged paper (blotches, fibres, darkened edges, folds, stains) and the trails in ink; returns the smoothed
## trail field.
func _paint_paper_and_trails(cells: PackedFloat32Array) -> PackedFloat32Array:
	var smooth: PackedFloat32Array = _blur(_blur(_upsample(cells), 4), 4)

	var blotches: FastNoiseLite = FastNoiseLite.new()
	blotches.seed = 5
	blotches.frequency = 0.006
	blotches.fractal_type = FastNoiseLite.FRACTAL_FBM
	var fibres: FastNoiseLite = FastNoiseLite.new()
	fibres.seed = 9
	fibres.frequency = 0.35
	var ink_noise: FastNoiseLite = FastNoiseLite.new()
	ink_noise.seed = 13
	ink_noise.frequency = 0.08

	var stains: Array[Vector3] = [
		Vector3(0.78, 0.2, 46.0), Vector3(0.16, 0.74, 34.0), Vector3(0.55, 0.9, 22.0),
	]
	var pale_interior: Color = PAPER_LIGHT.lightened(0.12)

	for y: int in _height:
		for x: int in _width:
			var blotch: float = 0.5 + 0.5 * blotches.get_noise_2d(float(x), float(y))
			var color: Color = PAPER_LIGHT.lerp(PAPER_DARK, smoothstep(0.35, 0.95, blotch) * 0.6)
			color = color * (1.0 + 0.05 * fibres.get_noise_2d(float(x), float(y) * 0.3))

			# Worn, darker edges.
			var edge: float = float(mini(mini(x, _width - 1 - x), mini(y, _height - 1 - y)))
			var wear: float = 1.0 - smoothstep(0.0, 80.0, edge)
			color = color.lerp(STAIN, wear * wear * 0.7 + wear * 0.12)

			# The folds: a dark crease with a pale ridge beside it, down and across the middle.
			for fold: float in [absf(float(x) - float(_width) * 0.5), absf(float(y) - float(_height) * 0.5)]:
				color = color.darkened(exp(-fold * fold / 3.0) * 0.2)
				color = color.lightened(exp(-pow(fold - 4.0, 2.0) / 5.0) * 0.05)

			# Rings left by a wet cup.
			for stain: Vector3 in stains:
				var from_centre: float = Vector2(float(x), float(y)).distance_to(Vector2(stain.x * float(_width), stain.y * float(_height)))
				color = color.lerp(STAIN, exp(-pow((from_centre - stain.z) / 2.5, 2.0)) * 0.22)

			# The trails: dark ink at the edges, the paper showing through the middle of the wide ones.
			var trail: float = smooth[y * _width + x]
			if trail > 0.3:
				var interior: float = smoothstep(0.64, 0.78, trail)
				color = color.lerp(pale_interior, interior * 0.35)
				var ink_alpha: float = smoothstep(0.4, 0.52, trail) * (1.0 - 0.9 * interior)
				ink_alpha *= 0.78 + 0.22 * (0.5 + 0.5 * ink_noise.get_noise_2d(float(x), float(y)))
				color = color.lerp(INK, ink_alpha * 0.92)

			_image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))

	return smooth


# ============================================================
# DRAWING
# ============================================================

func _blend(x: int, y: int, color: Color, alpha: float) -> void:
	if x < 0 or y < 0 or x >= _width or y >= _height or alpha <= 0.0:
		return

	var base: Color = _image.get_pixel(x, y)
	var mixed: Color = base.lerp(color, clampf(alpha, 0.0, 1.0))
	_image.set_pixel(x, y, Color(mixed.r, mixed.g, mixed.b, 1.0))


## A round stamp of ink, soft at its rim.
func _dot(point: Vector2, radius: float, color: Color, alpha: float) -> void:
	for y: int in range(int(floorf(point.y - radius - 1.0)), int(ceilf(point.y + radius + 1.0)) + 1):
		for x: int in range(int(floorf(point.x - radius - 1.0)), int(ceilf(point.x + radius + 1.0)) + 1):
			var cover: float = clampf(radius + 0.5 - Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(point), 0.0, 1.0)
			_blend(x, y, color, cover * alpha)


## A hand drawn line: the pen wanders a little off the straight.
func _line(from: Vector2, to: Vector2, width: float = 1.5, alpha: float = 0.85, color: Color = INK) -> void:
	var steps: int = maxi(int(ceilf(from.distance_to(to) / 0.7)), 1)
	for step: int in steps + 1:
		var point: Vector2 = from.lerp(to, float(step) / float(steps))
		var drift: Vector2 = Vector2(_wobble.get_noise_2d(point.x, point.y), _wobble.get_noise_2d(point.y + 100.0, point.x)) * 1.2
		_dot(point + drift, width * 0.5, color, alpha)


func _poly(centre: Vector2, points: Array[Vector2], closed: bool, width: float = 1.5) -> void:
	for i: int in points.size() - (0 if closed else 1):
		_line(centre + points[i], centre + points[(i + 1) % points.size()], width)


func _circle(centre: Vector2, radius: float, width: float = 1.4, dashed: bool = false, steps: int = 36) -> void:
	for i: int in steps:
		if dashed and i % 2 == 1:
			continue

		var a: float = TAU * float(i) / float(steps)
		var b: float = TAU * float(i + 1) / float(steps)
		_line(centre + Vector2(cos(a), sin(a)) * radius, centre + Vector2(cos(b), sin(b)) * radius, width)


func _fill_circle(centre: Vector2, radius: float, color: Color, alpha: float) -> void:
	_dot(centre, radius, color, alpha)


func _fill_triangle(a: Vector2, b: Vector2, c: Vector2, color: Color, alpha: float) -> void:
	var low: Vector2 = Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
	var high: Vector2 = Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
	for y: int in range(int(floorf(low.y)), int(ceilf(high.y)) + 1):
		for x: int in range(int(floorf(low.x)), int(ceilf(high.x)) + 1):
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var d1: float = (p - b).cross(a - b)
			var d2: float = (p - c).cross(b - c)
			var d3: float = (p - a).cross(c - a)
			var has_negative: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
			var has_positive: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
			if not (has_negative and has_positive):
				_blend(x, y, color, alpha)


func _draw_railway() -> void:
	var top: Vector2 = ForestMapProps.world_to_pixel(Vector2(0.0, ForestMapProps.RAILWAY_Z.x))
	var bottom: Vector2 = ForestMapProps.world_to_pixel(Vector2(0.0, ForestMapProps.RAILWAY_Z.y))
	var gauge: float = 1.1 * float(ForestMapProps.PIXELS_PER_METER)
	_line(top + Vector2(-gauge, 0.0), bottom + Vector2(-gauge, 0.0), 1.5)
	_line(top + Vector2(gauge, 0.0), bottom + Vector2(gauge, 0.0), 1.5)
	var y: float = top.y
	while y <= bottom.y:
		_line(Vector2(top.x - gauge * 1.7, y), Vector2(top.x + gauge * 1.7, y), 1.1, 0.75)
		y += 3.0 * float(ForestMapProps.PIXELS_PER_METER)


func _draw_border() -> void:
	for inset: Array in [[11.0, 2.3], [18.0, 1.1]]:
		var a: float = float(inset[0])
		var width: float = float(inset[1])
		var corners: Array[Vector2] = [
			Vector2(a, a), Vector2(float(_width) - a, a), Vector2(float(_width) - a, float(_height) - a), Vector2(a, float(_height) - a),
		]
		for i: int in 4:
			_line(corners[i], corners[(i + 1) % 4], width, 0.8)


func _draw_compass() -> void:
	var centre: Vector2 = Vector2(float(_width) - ForestMapProps.COMPASS_FROM_CORNER, float(_height) - ForestMapProps.COMPASS_FROM_CORNER)
	_circle(centre, 30.0, 1.5)
	_circle(centre, 24.0, 0.9, true, 48)
	# North is drawn solid; the other three points are only outlined.
	_fill_triangle(centre + Vector2(0.0, -36.0), centre + Vector2(-6.0, 0.0), centre + Vector2(6.0, 0.0), INK, 0.9)
	_poly(centre, [Vector2(0.0, 36.0), Vector2(-6.0, 0.0), Vector2(6.0, 0.0)] as Array[Vector2], true, 1.3)
	_poly(centre, [Vector2(36.0, 0.0), Vector2(0.0, -6.0), Vector2(0.0, 6.0)] as Array[Vector2], true, 1.3)
	_poly(centre, [Vector2(-36.0, 0.0), Vector2(0.0, -6.0), Vector2(0.0, 6.0)] as Array[Vector2], true, 1.3)


## Small trees, scattered where nothing else is: off the trails, the places, the railway and the corners.
func _draw_trees(cells: PackedFloat32Array, smooth: PackedFloat32Array) -> void:
	var near_trail: PackedFloat32Array = _blur(_blur(_upsample(cells), 14), 14)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var step: int = 7 * ForestMapProps.PIXELS_PER_METER
	var compass: Vector2 = Vector2(float(_width) - ForestMapProps.COMPASS_FROM_CORNER, float(_height) - ForestMapProps.COMPASS_FROM_CORNER)
	var tree_ink: Color = INK.lightened(0.18)
	var drawn: int = 0
	for gy: int in range(40, _height - 40, step):
		for gx: int in range(40, _width - 40, step):
			var point: Vector2 = Vector2(float(gx) + rng.randf_range(-10.0, 10.0), float(gy) + rng.randf_range(-10.0, 10.0))
			var index: int = clampi(int(point.y), 0, _height - 1) * _width + clampi(int(point.x), 0, _width - 1)
			if near_trail[index] > 0.012 or smooth[index] > 0.05:
				continue

			if point.y < 80.0 or point.distance_to(compass) < 80.0 or (point.x < 300.0 and point.y > float(_height) - 90.0):
				continue

			var world: Vector2 = ForestMapProps.WORLD_MIN + point / float(ForestMapProps.PIXELS_PER_METER)
			if absf(world.x) < 6.0 and world.y > ForestMapProps.RAILWAY_Z.x - 4.0 and world.y < ForestMapProps.RAILWAY_Z.y + 14.0:
				continue

			if _near_a_place(world):
				continue

			var radius: float = rng.randf_range(2.8, 4.2)
			_circle(point + Vector2(0.0, -radius), radius, 1.0, false, 14)
			_line(point + Vector2(0.0, 0.0), point + Vector2(0.0, 3.5), 1.0, 0.7, tree_ink)
			drawn += 1

	print("[bake_forest_map] trees: %d" % drawn)


## Within reach of an icon or its written name.
func _near_a_place(world: Vector2) -> bool:
	for landmark: Dictionary in ForestMapProps.LANDMARKS:
		var at: Vector2 = landmark["at"]
		if absf(world.x - at.x) < 12.0 and absf(world.y - at.y) < 14.0:
			return true

		var name_at: Vector2 = at + (landmark["name_at"] as Vector2)
		if absf(world.x - name_at.x) < 26.0 and absf(world.y - name_at.y) < 7.0:
			return true

	return false


# ============================================================
# THE PLACES
# ============================================================

func _draw_icon(shape: String, centre: Vector2) -> void:
	# Paper behind the icon, so a trail does not run through it.
	_fill_circle(centre, 15.0, PAPER_LIGHT, 0.95)
	match shape:
		"door":
			_line(centre + Vector2(-7.0, -7.0), centre + Vector2(-7.0, 8.0))
			_line(centre + Vector2(7.0, -7.0), centre + Vector2(7.0, 8.0))
			_line(centre + Vector2(-7.0, -7.0), centre + Vector2(7.0, -7.0))
			_line(centre + Vector2(-7.0, -5.0), centre + Vector2(7.0, 5.0), 1.2)
			_line(centre + Vector2(7.0, -5.0), centre + Vector2(-7.0, 5.0), 1.2)
		"shed":
			_poly(centre, [Vector2(-9.0, -1.0), Vector2(0.0, -9.0), Vector2(9.0, -1.0), Vector2(9.0, 8.0), Vector2(-9.0, 8.0)] as Array[Vector2], true)
			_poly(centre, [Vector2(-2.5, 8.0), Vector2(-2.5, 2.0), Vector2(2.5, 2.0), Vector2(2.5, 8.0)] as Array[Vector2], false, 1.2)
		"clearing":
			_circle(centre, 16.0, 1.2, true, 24)
			_circle(centre + Vector2(0.0, -3.0), 5.0, 1.4, false, 16)
			_line(centre + Vector2(0.0, 2.0), centre + Vector2(0.0, 9.0))
			_line(centre + Vector2(7.0, 6.0), centre + Vector2(11.0, 10.0), 1.2)
			_line(centre + Vector2(11.0, 6.0), centre + Vector2(7.0, 10.0), 1.2)
		"tower":
			_poly(centre, [Vector2(0.0, -13.0), Vector2(-8.0, 10.0), Vector2(8.0, 10.0)] as Array[Vector2], true)
			_line(centre + Vector2(-4.5, -1.0), centre + Vector2(4.5, -1.0), 1.2)
			_line(centre + Vector2(-6.2, 5.0), centre + Vector2(6.2, 5.0), 1.2)
			_circle(centre + Vector2(0.0, -15.0), 2.2, 1.2, false, 12)
		"house":
			# The house is unfinished: its roof is only half drawn.
			_line(centre + Vector2(-10.0, 0.0), centre + Vector2(0.0, -10.0))
			_line(centre + Vector2(0.0, -10.0), centre + Vector2(3.5, -6.5), 1.3, 0.7)
			_line(centre + Vector2(6.0, -4.0), centre + Vector2(10.0, 0.0), 1.3, 0.7)
			_line(centre + Vector2(-10.0, 0.0), centre + Vector2(-10.0, 9.0))
			_line(centre + Vector2(10.0, 0.0), centre + Vector2(10.0, 9.0))
			_line(centre + Vector2(-10.0, 9.0), centre + Vector2(10.0, 9.0))
			_line(centre + Vector2(-10.0, 4.0), centre + Vector2(10.0, 4.0), 1.0, 0.6)
		"overlook":
			var ring: Array[Vector2] = []
			for i: int in 28:
				var a: float = TAU * float(i) / 28.0
				ring.append(Vector2(cos(a) * 12.0, sin(a) * 6.5))

			_poly(centre, ring, true, 1.4)
			_fill_circle(centre, 3.0, INK, 0.9)
			for angle: float in [-60.0, -90.0, -120.0]:
				var direction: Vector2 = Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle)))
				_line(centre + direction * 10.0, centre + direction * 15.0, 1.2)
		_:
			push_warning("bake_forest_map: no icon for '%s'." % shape)
