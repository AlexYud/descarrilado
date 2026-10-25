extends RefCounted
class_name PixelCanvas

## A small drawing surface for the bake scripts in this folder: an Image painted with soft round dots, lines, filled shapes
## and masks, each colour laid over what is already there (so a canvas can start transparent, and a bake can paint an
## overlay). Everything is slow and made for a bake that runs once, not for the game.

var image: Image = null
var width: int = 0
var height: int = 0
## When it has an area, paint only lands inside it (a hill is drawn whole and only its part in the picture shows).
var clip: Rect2i = Rect2i()

var _wobble: FastNoiseLite = FastNoiseLite.new()


func _init(canvas_width: int, canvas_height: int, fill: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	width = canvas_width
	height = canvas_height
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	_wobble.seed = 17
	_wobble.frequency = 0.12


## Lays `color` over the pixel with the given strength (the colour's own alpha counts too).
func blend(x: int, y: int, color: Color, strength: float = 1.0) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return

	if clip.has_area() and not clip.has_point(Vector2i(x, y)):
		return

	var a: float = clampf(strength * color.a, 0.0, 1.0)
	if a <= 0.0:
		return

	var under: Color = image.get_pixel(x, y)
	var out_a: float = a + under.a * (1.0 - a)
	if out_a <= 0.0:
		return

	var keep: float = under.a * (1.0 - a)
	image.set_pixel(x, y, Color(
		(color.r * a + under.r * keep) / out_a,
		(color.g * a + under.g * keep) / out_a,
		(color.b * a + under.b * keep) / out_a,
		out_a
	))


## A round stamp, soft at its rim.
func dot(center: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	for y: int in range(int(floorf(center.y - radius - 1.0)), int(ceilf(center.y + radius + 1.0)) + 1):
		for x: int in range(int(floorf(center.x - radius - 1.0)), int(ceilf(center.x + radius + 1.0)) + 1):
			var cover: float = clampf(radius + 0.5 - Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center), 0.0, 1.0)
			blend(x, y, color, cover * strength)


## A line of dots; `wander` lets the pen drift a little off the straight, the way a hand does.
func line(from: Vector2, to: Vector2, line_width: float, color: Color, strength: float = 1.0, wander: float = 0.0) -> void:
	var steps: int = maxi(int(ceilf(from.distance_to(to) / 0.7)), 1)
	for step: int in steps + 1:
		var point: Vector2 = from.lerp(to, float(step) / float(steps))
		if wander > 0.0:
			point += Vector2(_wobble.get_noise_2d(point.x, point.y), _wobble.get_noise_2d(point.y + 100.0, point.x)) * wander

		dot(point, line_width * 0.5, color, strength)


func fill_rect(rect: Rect2, color: Color, strength: float = 1.0) -> void:
	for y: int in range(maxi(int(floorf(rect.position.y)), 0), mini(int(ceilf(rect.end.y)), height)):
		for x: int in range(maxi(int(floorf(rect.position.x)), 0), mini(int(ceilf(rect.end.x)), width)):
			blend(x, y, color, strength)


## An ellipse with a soft edge `softness` pixels wide.
func fill_ellipse(center: Vector2, radii: Vector2, color: Color, strength: float = 1.0, softness: float = 1.2) -> void:
	for y: int in range(int(floorf(center.y - radii.y - 2.0)), int(ceilf(center.y + radii.y + 2.0)) + 1):
		for x: int in range(int(floorf(center.x - radii.x - 2.0)), int(ceilf(center.x + radii.x + 2.0)) + 1):
			var offset: Vector2 = (Vector2(float(x) + 0.5, float(y) + 0.5) - center) / radii
			var distance: float = offset.length() * minf(radii.x, radii.y)
			var cover: float = clampf((minf(radii.x, radii.y) - distance) / softness + 0.5, 0.0, 1.0)
			blend(x, y, color, cover * strength)


func ring(center: Vector2, radius: float, ring_width: float, color: Color, strength: float = 1.0) -> void:
	var steps: int = maxi(int(TAU * radius / 0.8), 12)
	for i: int in steps:
		var angle: float = TAU * float(i) / float(steps)
		dot(center + Vector2(cos(angle), sin(angle)) * radius, ring_width * 0.5, color, strength)


## A filled polygon (even-odd rule), edges a pixel soft.
func fill_polygon(points: PackedVector2Array, color: Color, strength: float = 1.0) -> void:
	if points.size() < 3:
		return

	var low: float = points[0].y
	var high: float = points[0].y
	for point: Vector2 in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)

	for y: int in range(maxi(int(floorf(low)), 0), mini(int(ceilf(high)) + 1, height)):
		var scan: float = float(y) + 0.5
		var crossings: Array[float] = []
		for i: int in points.size():
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			if (a.y <= scan and b.y > scan) or (b.y <= scan and a.y > scan):
				crossings.append(a.x + (scan - a.y) / (b.y - a.y) * (b.x - a.x))

		crossings.sort()
		for pair: int in range(0, crossings.size() - 1, 2):
			var from_x: float = crossings[pair]
			var to_x: float = crossings[pair + 1]
			for x: int in range(maxi(int(floorf(from_x)), 0), mini(int(ceilf(to_x)) + 1, width)):
				var cover: float = clampf(minf(float(x) + 1.0, to_x) - maxf(float(x), from_x), 0.0, 1.0)
				blend(x, y, color, cover * strength)


## The outline of a rectangle with rounded corners.
func round_rect_outline(rect: Rect2, corner: float, line_width: float, color: Color, strength: float = 1.0) -> void:
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	line(Vector2(left + corner, top), Vector2(right - corner, top), line_width, color, strength)
	line(Vector2(left + corner, bottom), Vector2(right - corner, bottom), line_width, color, strength)
	line(Vector2(left, top + corner), Vector2(left, bottom - corner), line_width, color, strength)
	line(Vector2(right, top + corner), Vector2(right, bottom - corner), line_width, color, strength)
	for corner_point: Array in [
		[Vector2(left + corner, top + corner), PI, 1.5 * PI],
		[Vector2(right - corner, top + corner), 1.5 * PI, TAU],
		[Vector2(right - corner, bottom - corner), 0.0, 0.5 * PI],
		[Vector2(left + corner, bottom - corner), 0.5 * PI, PI],
	]:
		var center: Vector2 = corner_point[0]
		var steps: int = maxi(int(corner * 2.0), 6)
		for i: int in steps + 1:
			var angle: float = lerpf(float(corner_point[1]), float(corner_point[2]), float(i) / float(steps))
			dot(center + Vector2(cos(angle), sin(angle)) * corner, line_width * 0.5, color, strength)


func save_png(path: String) -> int:
	return image.save_png(ProjectSettings.globalize_path(path))
