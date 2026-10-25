extends Node

## Bakes the pictures on the two signs of the trailhead (`TrailheadProps`) into `assets/textures/trailhead/`. The signs are meant to
## look like the ones of a small park in the nineties: paint gone dull on weathered wood, few colours, little ornament, the same plain
## look as the wooden fence gate beside them.
##
##   welcome_sign.png   the face of the welcome sign: a board of faded dark green paint with a thin cream border, a small plain drawing
##                      (hills, a pine, a pale sun) at the bottom right and the park's two small marks at the bottom left, weathered
##                      (grime, rain streaks, flaked paint). It carries no words: "Bem-vindo à" and the names are written by the game
##                      over it, as localized text.
##   name_defaced.png   what was done to the old name: red paint brushed over it and scratches cut through it, on a transparent
##                      ground, so that it lies over the name and makes it impossible to read.
##   map_board.png      the face of the trail map sign: the same faded green, a header band with two marks and nothing written, a
##                      window where the map is pinned (the paint is darker there, the paper having kept the sun off it, and the four
##                      pin holes are in its corners), two columns of small writing, a column of plain pictograms and the marks
##                      along the bottom, weathered.
##
## Run it again when the signs' size or layout (the constants of `TrailheadProps`) change:
##   Godot --headless --path . res://tools/bake_trailhead_signs.tscn
## then `--import`. The imports must stay lossless (`compress/mode=0`, `detect_3d/compress_to=0` in the `.import` files):
## Godot would otherwise turn them into VRAM compressed textures, which smears fine lines.

const OUT_DIRECTORY: String = TrailheadProps.TEXTURE_DIRECTORY

## Faded paint: dark forest green gone grey where the sun and the rain have been at it, cream lettering that has yellowed.
const PANEL: Color = Color(0.14, 0.19, 0.15)
const PANEL_DARK: Color = Color(0.085, 0.12, 0.095)
const FADED: Color = Color(0.27, 0.3, 0.24)
const CREAM: Color = Color(0.8, 0.76, 0.62)
const RED: Color = Color(0.5, 0.06, 0.05)
const OCHRE: Color = Color(0.58, 0.48, 0.27)
const SLASH: Color = Color(0.48, 0.17, 0.13)
const HILL: Color = Color(0.2, 0.26, 0.19)
const HILL_FAR: Color = Color(0.17, 0.23, 0.17)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIRECTORY))
	var failed: int = 0
	failed += _bake_welcome_face()
	failed += _bake_defaced_name()
	failed += _bake_board_face()
	print("[bake_trailhead_signs] done, %d failed" % failed)
	get_tree().quit(1 if failed > 0 else 0)


# ============================================================
# COMMON
# ============================================================

## The painted surface: the base colour with blotches of sun fade, a fine grain, and darker edges.
func _base(canvas: PixelCanvas, base: Color, noise_seed: int, fade: Color, fade_amount: float) -> void:
	var blotches: FastNoiseLite = FastNoiseLite.new()
	blotches.seed = noise_seed
	blotches.frequency = 0.0045
	blotches.fractal_type = FastNoiseLite.FRACTAL_FBM
	var grain: FastNoiseLite = FastNoiseLite.new()
	grain.seed = noise_seed + 1
	grain.frequency = 0.4
	# The wood shows through old paint as long streaks.
	var streaks: FastNoiseLite = FastNoiseLite.new()
	streaks.seed = noise_seed + 2
	streaks.frequency = 0.9
	for y: int in canvas.height:
		var sun: float = 1.0 - float(y) / float(canvas.height)
		for x: int in canvas.width:
			var blotch: float = 0.5 + 0.5 * blotches.get_noise_2d(float(x), float(y))
			var color: Color = base.lerp(fade, clampf(smoothstep(0.4, 0.95, blotch) * fade_amount + sun * 0.05, 0.0, 1.0))
			color = color * (1.0 + 0.04 * grain.get_noise_2d(float(x), float(y)))
			color = color * (1.0 + 0.05 * streaks.get_noise_2d(float(x) * 0.12, float(y) * 1.6))
			var edge: float = float(mini(mini(x, canvas.width - 1 - x), mini(y, canvas.height - 1 - y)))
			color = color.darkened((1.0 - smoothstep(0.0, 36.0, edge)) * 0.22)
			canvas.image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))


## Rain streaks, grime, mildew, flaked paint: the age of the board. `amount` scales how much of each there is.
func _weather(canvas: PixelCanvas, rng: RandomNumberGenerator, area: Rect2 = Rect2(), amount: float = 0.5) -> void:
	var where: Rect2 = area if area.has_area() else Rect2(0.0, 0.0, float(canvas.width), float(canvas.height))
	for i: int in int(55.0 * amount):
		var x: float = rng.randf_range(where.position.x, where.end.x)
		var top: float = rng.randf_range(where.position.y, where.position.y + where.size.y * 0.7)
		canvas.line(Vector2(x, top), Vector2(x + rng.randf_range(-4.0, 4.0), top + rng.randf_range(50.0, 260.0)), rng.randf_range(1.0, 2.6), Color(0.74, 0.76, 0.7), rng.randf_range(0.02, 0.05))

	for i: int in int(30.0 * amount):
		var x: float = rng.randf_range(where.position.x, where.end.x)
		var top: float = rng.randf_range(where.position.y + where.size.y * 0.45, where.end.y - 20.0)
		canvas.line(Vector2(x, top), Vector2(x, top + rng.randf_range(30.0, 150.0)), rng.randf_range(2.0, 6.0), Color(0.02, 0.025, 0.02), rng.randf_range(0.04, 0.1))

	for i: int in int(16.0 * amount) + 2:
		var at: Vector2 = Vector2(rng.randf_range(where.position.x, where.end.x), rng.randf_range(where.position.y + where.size.y * 0.6, where.end.y))
		canvas.fill_ellipse(at, Vector2(rng.randf_range(24.0, 90.0), rng.randf_range(8.0, 28.0)), Color(0.22, 0.3, 0.2), rng.randf_range(0.08, 0.15), 14.0)

	# Flaked paint along the edges: specks of bare, grey wood, and one or two bigger patches of it.
	for i: int in int(70.0 * amount):
		var edge_point: Vector2 = _edge_point(where, rng, 50.0)
		canvas.fill_ellipse(edge_point, Vector2(rng.randf_range(1.6, 4.5), rng.randf_range(1.2, 3.2)), Color(0.5, 0.47, 0.4), rng.randf_range(0.35, 0.65), 1.0)

	for i: int in int(5.0 * amount) + 1:
		var edge_point: Vector2 = _edge_point(where, rng, 30.0)
		canvas.fill_ellipse(edge_point, Vector2(rng.randf_range(10.0, 26.0), rng.randf_range(6.0, 15.0)), Color(0.4, 0.34, 0.27), rng.randf_range(0.5, 0.8), 2.5)


func _edge_point(where: Rect2, rng: RandomNumberGenerator, depth: float) -> Vector2:
	var along: float = rng.randf()
	var inside: float = rng.randf_range(0.0, depth)
	match rng.randi_range(0, 3):
		0:
			return Vector2(where.position.x + along * where.size.x, where.position.y + inside)
		1:
			return Vector2(where.position.x + along * where.size.x, where.end.y - inside)
		2:
			return Vector2(where.position.x + inside, where.position.y + along * where.size.y)
		_:
			return Vector2(where.end.x - inside, where.position.y + along * where.size.y)


## A footprint: the sole, and four toes.
func _footprint(canvas: PixelCanvas, at: Vector2, scale_by: float, color: Color, strength: float) -> void:
	canvas.fill_ellipse(at + Vector2(0.0, 4.0) * scale_by, Vector2(10.0, 15.0) * scale_by, color, strength, 1.2)
	for toe: Vector2 in [Vector2(-8.0, -14.0), Vector2(-2.5, -17.0), Vector2(3.5, -17.0), Vector2(9.0, -13.0)]:
		canvas.fill_ellipse(at + toe * scale_by, Vector2(3.4, 4.4) * scale_by, color, strength, 1.0)


func _save(canvas: PixelCanvas, file_name: String) -> int:
	var error: int = canvas.save_png(OUT_DIRECTORY + file_name)
	print("[bake_trailhead_signs] %s %dx%d: %s" % [file_name, canvas.width, canvas.height, error_string(error)])
	return 0 if error == OK else 1


# ============================================================
# THE WELCOME SIGN
# ============================================================

func _bake_welcome_face() -> int:
	var canvas: PixelCanvas = PixelCanvas.new(1024, 567, PANEL)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	_base(canvas, PANEL, 11, FADED, 0.3)

	# A thin border, painted a hand's width in from the edge, as on a sign made by a sign painter.
	canvas.round_rect_outline(Rect2(22.0, 22.0, float(canvas.width) - 44.0, float(canvas.height) - 44.0), 8.0, 3.0, CREAM, 0.5)

	# A small plain drawing at the bottom right: far hills, a nearer one, a pine and a pale sun. Dull and low in contrast.
	canvas.fill_ellipse(Vector2(900, 470), Vector2(190, 110), HILL_FAR, 1.0, 2.0)
	canvas.fill_ellipse(Vector2(800, 560), Vector2(250, 120), HILL, 1.0, 2.0)
	canvas.fill_ellipse(Vector2(850, 400), Vector2(30, 30), OCHRE, 0.55, 2.0)
	for tier: int in 3:
		var top: float = 405.0 + float(tier) * 36.0
		var half: float = 26.0 + float(tier) * 14.0
		canvas.fill_polygon(PackedVector2Array([Vector2(930.0, top), Vector2(930.0 - half, top + 52.0), Vector2(930.0 + half, top + 52.0)]), CREAM, 0.42)

	canvas.fill_rect(Rect2(926.0, 512.0, 8.0, 22.0), CREAM, 0.42)

	# The park's two marks at the bottom left, and the lines of their names.
	canvas.fill_ellipse(Vector2(70, 505), Vector2(26, 26), OCHRE, 0.9, 1.5)
	_footprint(canvas, Vector2(70, 507), 0.7, PANEL_DARK, 1.0)
	canvas.fill_rect(Rect2(110, 493, 120, 6), CREAM, 0.55)
	canvas.fill_rect(Rect2(110, 506, 66, 6), CREAM, 0.55)
	canvas.fill_polygon(PackedVector2Array([Vector2(284, 482), Vector2(316, 482), Vector2(316, 506), Vector2(300, 530), Vector2(284, 506)]), CREAM, 0.6)
	canvas.fill_polygon(PackedVector2Array([Vector2(291, 489), Vector2(309, 489), Vector2(309, 504), Vector2(300, 518), Vector2(291, 504)]), PANEL, 0.9)
	for line_index: int in 3:
		canvas.fill_rect(Rect2(330, 490 + line_index * 13, [118, 80, 100][line_index], 5), CREAM, 0.5)

	_weather(canvas, rng)
	return _save(canvas, "welcome_sign.png")


# ============================================================
# WHAT WAS DONE TO THE OLD NAME
# ============================================================

func _bake_defaced_name() -> int:
	# 800 pixels to the metre, like the sign: the size of `TrailheadProps.DEFACED_SIZE`.
	var canvas: PixelCanvas = PixelCanvas.new(int(TrailheadProps.DEFACED_SIZE.x * 800.0), int(TrailheadProps.DEFACED_SIZE.y * 800.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23
	var paint: PackedFloat32Array = PackedFloat32Array()
	paint.resize(canvas.width * canvas.height)

	# Red paint, brushed across in wavy bands that overlap, thick enough to cover the letters between the scratches.
	for band: int in 9:
		var y_line: float = 26.0 + float(band) * 21.0 + rng.randf_range(-6.0, 6.0)
		var thickness: float = rng.randf_range(30.0, 50.0)
		var phase: float = rng.randf() * TAU
		var x: float = rng.randf_range(0.0, 50.0)
		var x_end: float = 960.0 - rng.randf_range(0.0, 70.0)
		while x < x_end:
			var y: float = y_line + sin(x * 0.011 + phase) * 9.0 + sin(x * 0.037 + phase * 2.0) * 3.0
			_stamp(paint, canvas.width, canvas.height, Vector2(x, y), thickness * 0.5 * rng.randf_range(0.85, 1.1), rng.randf_range(0.8, 1.0))
			x += 2.5

	# Splashes round it, and runs down from its lower edge.
	for i: int in 260:
		var at: Vector2 = Vector2(rng.randf_range(0.0, float(canvas.width)), rng.randf_range(0.0, float(canvas.height)))
		_stamp(paint, canvas.width, canvas.height, at, rng.randf_range(1.0, 3.2), rng.randf_range(0.5, 0.95))

	for i: int in 22:
		var x_run: float = rng.randf_range(20.0, 940.0)
		var y_run: float = rng.randf_range(110.0, float(canvas.height) - 28.0)
		var length: float = rng.randf_range(10.0, 36.0)
		var step: float = 0.0
		while step < length:
			_stamp(paint, canvas.width, canvas.height, Vector2(x_run, y_run + step), rng.randf_range(1.6, 2.6), 0.9)
			step += 1.5

	var streaks: FastNoiseLite = FastNoiseLite.new()
	streaks.seed = 3
	streaks.frequency = 0.05
	for y: int in canvas.height:
		for x: int in canvas.width:
			var coverage: float = paint[y * canvas.width + x]
			if coverage <= 0.01:
				continue

			# A brush leaves lines in the paint, and the red is thinner where the bristles skipped.
			var thinness: float = 0.78 + 0.22 * (0.5 + 0.5 * streaks.get_noise_2d(float(x) * 0.15, float(y) * 1.4))
			canvas.blend(x, y, RED, clampf(coverage * 0.97 * thinness, 0.0, 0.96))

	# Scratches through everything: a key or a nail dragged over the paint, over and over, mostly slanting one way.
	for i: int in 300:
		var angle: float = deg_to_rad(rng.randf_range(-62.0, -18.0) if rng.randf() < 0.66 else (rng.randf_range(18.0, 58.0) if rng.randf() < 0.7 else rng.randf_range(-8.0, 8.0)))
		var length: float = rng.randf_range(30.0, 260.0)
		var from: Vector2 = Vector2(rng.randf_range(-20.0, float(canvas.width) + 20.0), rng.randf_range(-10.0, float(canvas.height) + 10.0))
		var to: Vector2 = from + Vector2(cos(angle), sin(angle)) * length
		var bare: bool = rng.randf() < 0.72
		canvas.line(from, to, rng.randf_range(1.1, 2.6), Color(0.78, 0.76, 0.68) if bare else Color(0.03, 0.04, 0.03), rng.randf_range(0.75, 0.95), 1.4)

	return _save(canvas, "name_defaced.png")


## Raises the paint's coverage to at least `strength` at the centre of a round brush mark, fading to nothing at its rim.
func _stamp(paint: PackedFloat32Array, width: int, height: int, center: Vector2, radius: float, strength: float) -> void:
	for y: int in range(maxi(int(floorf(center.y - radius)), 0), mini(int(ceilf(center.y + radius)) + 1, height)):
		for x: int in range(maxi(int(floorf(center.x - radius)), 0), mini(int(ceilf(center.x + radius)) + 1, width)):
			var distance: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			var value: float = strength * clampf((radius - distance) / maxf(radius * 0.3, 1.0), 0.0, 1.0)
			var index: int = y * width + x
			paint[index] = maxf(paint[index], value)


# ============================================================
# THE TRAIL MAP SIGN
# ============================================================

func _bake_board_face() -> int:
	var canvas: PixelCanvas = PixelCanvas.new(640, 890, PANEL)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var pixels_per_meter: float = float(canvas.width) / TrailheadProps.BOARD_PANEL.x
	var window_center: Vector2 = Vector2(float(canvas.width) * 0.5, float(canvas.height) * 0.5) + Vector2(TrailheadProps.MAP_WINDOW_CENTER.x, -TrailheadProps.MAP_WINDOW_CENTER.y) * pixels_per_meter
	var window_size: Vector2 = TrailheadProps.MAP_WINDOW_SIZE * pixels_per_meter
	var window: Rect2 = Rect2(window_center - window_size * 0.5, window_size)

	_base_with_window(canvas, window)

	# The header band, with the park's two marks and nothing written on it.
	canvas.fill_rect(Rect2(0, 0, canvas.width, 118), PANEL_DARK, 0.9)
	canvas.fill_rect(Rect2(0, 116, canvas.width, 3), CREAM, 0.4)
	canvas.fill_rect(Rect2(0, 124, canvas.width, 2), CREAM, 0.2)
	canvas.ring(Vector2(70, 59), 34.0, 4.0, CREAM, 0.65)
	_footprint(canvas, Vector2(70, 62), 1.0, CREAM, 0.65)
	canvas.fill_ellipse(Vector2(canvas.width - 62, 59), Vector2(30, 30), OCHRE, 0.85, 1.5)
	_footprint(canvas, Vector2(canvas.width - 62, 61), 0.8, PANEL_DARK, 1.0)

	# A line round the window marks where the map is.
	canvas.round_rect_outline(Rect2(window.position - Vector2(9, 9), window.size + Vector2(18, 18)), 6.0, 2.0, CREAM, 0.35)

	# The holes of the four pins that held the map, in its corners.
	var paper_size: Vector2 = ForestMapProps.paper_size()
	for offset: Vector2 in TrailheadProps.pin_offsets(paper_size):
		var hole: Vector2 = window_center + Vector2(offset.x, -offset.y) * pixels_per_meter
		canvas.dot(hole, 6.5, Color(0.45, 0.45, 0.4), 0.3)
		canvas.dot(hole, 4.2, Color(0.01, 0.015, 0.01), 0.95)

	# Writing in two columns under the window (lines only: the real words would be too small to read), a column of plain pictograms
	# to the right of it, and the marks along the bottom.
	_text_block(canvas, rng, Vector2(40, 572), 238.0, 8)
	_text_block(canvas, rng, Vector2(318, 572), 282.0, 8)
	var icon_x: float = window.end.x + 36.0
	for i: int in 4:
		_pictogram(canvas, Rect2(icon_x, window.position.y + float(i) * 62.0, 46.0, 46.0), i)

	canvas.fill_ellipse(Vector2(48, 858), Vector2(17, 17), OCHRE, 0.85, 1.2)
	_footprint(canvas, Vector2(48, 859), 0.5, PANEL_DARK, 1.0)
	canvas.fill_rect(Rect2(80, 848, 90, 6), CREAM, 0.5)
	canvas.fill_rect(Rect2(80, 861, 56, 6), CREAM, 0.5)
	canvas.fill_polygon(PackedVector2Array([Vector2(560, 840), Vector2(592, 840), Vector2(592, 862), Vector2(576, 882), Vector2(560, 862)]), CREAM, 0.55)

	_weather(canvas, rng, Rect2(0, 130, canvas.width, canvas.height - 130))
	return _save(canvas, "map_board.png")


## The panel: deep green where the map keeps the sun off it, faded and streaked everywhere else.
func _base_with_window(canvas: PixelCanvas, window: Rect2) -> void:
	_base(canvas, PANEL, 31, FADED, 0.3)
	for y: int in canvas.height:
		for x: int in canvas.width:
			var inside: bool = window.grow(-1.0).has_point(Vector2(float(x), float(y)))
			var edge_distance: float = minf(
				minf(absf(float(x) - window.position.x), absf(float(x) - window.end.x)),
				minf(absf(float(y) - window.position.y), absf(float(y) - window.end.y))
			)
			var protected: float = (1.0 if inside else 0.0) * smoothstep(0.0, 3.0, edge_distance)
			var current: Color = canvas.image.get_pixel(x, y)
			# The exposed paint has lost some of its colour; under the paper it is as it was.
			var colour: Color = current.lerp(PANEL_DARK, protected * 0.7).lerp(FADED, (1.0 - protected) * 0.18)
			canvas.image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, 1.0))


## Lines standing for a column of writing: a heading and then rows of different lengths.
func _text_block(canvas: PixelCanvas, rng: RandomNumberGenerator, at: Vector2, block_width: float, rows: int) -> void:
	canvas.fill_rect(Rect2(at.x, at.y, block_width * 0.7, 10), CREAM, 0.6)
	for row: int in rows:
		var width: float = block_width * (1.0 if row % 4 != 3 else rng.randf_range(0.4, 0.7)) * rng.randf_range(0.9, 1.0)
		canvas.fill_rect(Rect2(at.x, at.y + 30.0 + float(row) * 20.0, width, 5), CREAM, 0.38)


## A small square pictogram, like the park's rules: an outline, a simple mark, and a dull red bar across half of them.
func _pictogram(canvas: PixelCanvas, box: Rect2, index: int) -> void:
	canvas.round_rect_outline(box, 7.0, 2.2, CREAM, 0.6)
	var center: Vector2 = box.get_center()
	match index % 3:
		0:
			canvas.ring(center, 11.0, 3.0, CREAM, 0.65)
			canvas.fill_ellipse(center, Vector2(4, 4), CREAM, 0.65, 1.0)
		1:
			canvas.fill_polygon(PackedVector2Array([center + Vector2(0, -13), center + Vector2(12, 11), center + Vector2(-12, 11)]), CREAM, 0.65)
		_:
			canvas.fill_rect(Rect2(center - Vector2(11, 8), Vector2(22, 16)), CREAM, 0.65)

	if index % 2 == 0:
		canvas.line(box.position + Vector2(6, box.size.y - 6.0), box.position + Vector2(box.size.x - 6.0, 6), 3.2, SLASH, 0.85)
