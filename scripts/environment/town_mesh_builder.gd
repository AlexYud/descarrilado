class_name TownMeshBuilder
extends RefCounted

## Mesh helper for the town blockout: flat-shaded triangles whose winding is fixed from a
## "hint" (the direction the face must look), boxes, solids extruded along a straight
## line, profiles swept along a path (road ribbons, sidewalks, walls, rails), plus the
## procedural stone textures. Godot's front faces are clockwise, so the geometric normal
## of a triangle (a, b, c) is (c - a) x (b - a).

var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()


func is_empty() -> bool:
	return indices.is_empty()


func add_triangle(a: Vector3, b: Vector3, c: Vector3, hint: Vector3, uv_a: Vector2 = Vector2.ZERO, uv_b: Vector2 = Vector2.ZERO, uv_c: Vector2 = Vector2.ZERO, color: Color = Color.WHITE) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 0.0000001:
		return

	normal = normal.normalized()
	if normal.dot(hint) < 0.0:
		var swapped: Vector3 = b
		b = c
		c = swapped
		var swapped_uv: Vector2 = uv_b
		uv_b = uv_c
		uv_c = swapped_uv
		normal = -normal

	var base: int = vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	uvs.append(uv_a)
	uvs.append(uv_b)
	uvs.append(uv_c)
	for i: int in 3:
		normals.append(normal)
		colors.append(color)

	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)


## A quad given in cyclic order.
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, uv_a: Vector2 = Vector2.ZERO, uv_b: Vector2 = Vector2.ZERO, uv_c: Vector2 = Vector2.ZERO, uv_d: Vector2 = Vector2.ZERO, color: Color = Color.WHITE) -> void:
	add_triangle(a, b, c, hint, uv_a, uv_b, uv_c, color)
	add_triangle(a, c, d, hint, uv_a, uv_c, uv_d, color)


## A box, turned `yaw` radians about Y around its centre.
func add_box(center: Vector3, size: Vector3, color: Color = Color.WHITE, yaw: float = 0.0) -> void:
	var basis: Basis = Basis(Vector3.UP, yaw)
	var half: Vector3 = size * 0.5
	var corners: Array[Vector3] = []
	for ix: int in 2:
		for iy: int in 2:
			for iz: int in 2:
				corners.append(center + basis * Vector3(half.x * (2 * ix - 1), half.y * (2 * iy - 1), half.z * (2 * iz - 1)))

	# index = ix * 4 + iy * 2 + iz
	var faces: Array = [
		[0, 1, 3, 2, Vector3.LEFT],
		[4, 5, 7, 6, Vector3.RIGHT],
		[0, 1, 5, 4, Vector3.DOWN],
		[2, 3, 7, 6, Vector3.UP],
		[0, 2, 6, 4, Vector3.FORWARD],
		[1, 3, 7, 5, Vector3.BACK],
	]
	for face: Array in faces:
		var hint: Vector3 = basis * (face[4] as Vector3)
		add_quad(corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], hint, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, color)


## A convex polygon (points in cyclic order, in one plane) pushed along `offset`: a roof,
## a wedge, a prism.
func add_prism(polygon: Array[Vector3], offset: Vector3, color: Color = Color.WHITE) -> void:
	var count: int = polygon.size()
	var centre: Vector3 = Vector3.ZERO
	for point: Vector3 in polygon:
		centre += point

	centre = centre / float(count) + offset * 0.5
	for k: int in count:
		var k2: int = (k + 1) % count
		var a: Vector3 = polygon[k]
		var b: Vector3 = polygon[k2]
		var middle: Vector3 = (a + b) * 0.5 + offset * 0.5
		add_quad(a, b, b + offset, a + offset, middle - centre, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, color)

	for k: int in range(1, count - 1):
		add_triangle(polygon[0], polygon[k], polygon[k + 1], -offset, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, color)
		add_triangle(polygon[0] + offset, polygon[k] + offset, polygon[k + 1] + offset, offset, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, color)


## Sweeps `profile` (x = sideways offset to the right of the path, y = height above the
## path point) along `path`. An open profile is a surface looking up (ribbons, sidewalks);
## a closed one is a solid (a wall, a rail) with its end caps. Texture coordinates: u =
## offset, v = distance along the path. A profile point whose height is -1000 sits on the
## fixed height `floor_y` instead (walls whose foot stays level beside a stair).
func extrude(path: PackedVector3Array, profile: PackedVector2Array, closed: bool, color: Color = Color.WHITE, floor_y: float = NAN) -> void:
	var count: int = path.size()
	if count < 2 or profile.size() < 2:
		return

	var rows: Array[PackedVector3Array] = []
	var centres: Array[Vector3] = []
	var distance: PackedFloat32Array = PackedFloat32Array()
	var travelled: float = 0.0
	for i: int in count:
		var before: Vector3 = path[maxi(i - 1, 0)]
		var after: Vector3 = path[mini(i + 1, count - 1)]
		var tangent: Vector2 = Vector2(after.x - before.x, after.z - before.z)
		tangent = tangent.normalized() if tangent.length() > 0.0001 else Vector2(1.0, 0.0)
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var row: PackedVector3Array = PackedVector3Array()
		var centre: Vector3 = Vector3.ZERO
		for p: Vector2 in profile:
			var position: Vector3 = path[i] + Vector3(normal.x * p.x, p.y, normal.y * p.x)
			if p.y <= -999.0 and not is_nan(floor_y):
				position.y = floor_y

			row.append(position)
			centre += position

		rows.append(row)
		centres.append(centre / float(profile.size()))
		if i > 0:
			travelled += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()

		distance.append(travelled)

	var sections: int = profile.size() if closed else profile.size() - 1
	for i: int in count - 1:
		for k: int in sections:
			var k2: int = (k + 1) % profile.size()
			var a: Vector3 = rows[i][k]
			var b: Vector3 = rows[i][k2]
			var c: Vector3 = rows[i + 1][k2]
			var d: Vector3 = rows[i + 1][k]
			var hint: Vector3 = Vector3.UP
			if closed:
				hint = (a + b + c + d) * 0.25 - (centres[i] + centres[i + 1]) * 0.5

			add_quad(
				a, b, c, d, hint,
				Vector2(profile[k].x, distance[i]), Vector2(profile[k2].x, distance[i]),
				Vector2(profile[k2].x, distance[i + 1]), Vector2(profile[k].x, distance[i + 1]),
				color
			)

	if closed and profile.size() >= 3:
		var start_direction: Vector3 = (path[0] - path[1]).normalized()
		var end_direction: Vector3 = (path[count - 1] - path[count - 2]).normalized()
		for k: int in range(1, profile.size() - 1):
			add_triangle(rows[0][0], rows[0][k], rows[0][k + 1], start_direction, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, color)
			add_triangle(rows[count - 1][0], rows[count - 1][k], rows[count - 1][k + 1], end_direction, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, color)


## Smooths the shading: every vertex takes the average normal of the faces that meet at its
## position and bend away from it by less than `max_angle_degrees` (a ribbon with its
## bevels stays sharp where it should, but its flat quads stop showing seams).
func smooth_normals(max_angle_degrees: float = 50.0) -> void:
	var limit: float = cos(deg_to_rad(max_angle_degrees))
	var groups: Dictionary = {}
	for i: int in vertices.size():
		var key: Vector3i = Vector3i(roundi(vertices[i].x * 50.0), roundi(vertices[i].y * 50.0), roundi(vertices[i].z * 50.0))
		if not groups.has(key):
			groups[key] = []

		(groups[key] as Array).append(i)

	var result: PackedVector3Array = normals.duplicate()
	for key: Vector3i in groups:
		var members: Array = groups[key]
		if members.size() < 2:
			continue

		for i: int in members:
			var sum: Vector3 = Vector3.ZERO
			for j: int in members:
				if normals[i].dot(normals[j]) >= limit:
					sum += normals[j]

			result[i] = sum.normalized() if sum.length_squared() > 0.000001 else normals[i]

	normals = result


func build() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


## Courses of uneven stones with dark mortar and a little moss: a tileable texture. The
## stones of a course always add up to the tile, so it repeats without a seam.
static func stone_texture(seed_value: int, tile: int, course_pixels: int, min_width: int, max_width: int, tint: Color, mortar: Color, moss: float) -> ImageTexture:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var image: Image = Image.create(tile, tile, false, Image.FORMAT_RGB8)
	image.fill(mortar)

	var courses: int = maxi(int(round(float(tile) / float(course_pixels))), 1)
	var moss_color: Color = Color(0.22, 0.34, 0.16)
	for course: int in courses:
		# The courses add up to the whole tile (no empty strip at its edge).
		var y0: int = course * tile / courses
		var y1: int = (course + 1) * tile / courses
		var widths: Array[int] = []
		var total: int = 0
		while total < tile:
			var width: int = rng.randi_range(min_width, max_width)
			if tile - total - width < min_width:
				width = tile - total

			widths.append(width)
			total += width

		var x0: int = rng.randi_range(0, tile - 1)
		var cursor: int = 0
		for width: int in widths:
			var shade: float = rng.randf_range(0.7, 1.15)
			var stone: Color = Color(tint.r * shade, tint.g * shade, tint.b * shade)
			if rng.randf() < moss:
				stone = stone.lerp(moss_color, rng.randf_range(0.3, 0.75))

			for py: int in range(y0 + 1, y1 - 1):
				for px: int in range(cursor + 1, cursor + width - 1):
					var edge_x: int = mini(px - cursor, cursor + width - 1 - px)
					var edge_y: int = mini(py - y0, y1 - 1 - py)
					# Rounded corners: the corner pixels stay mortar.
					if edge_x + edge_y < 3:
						continue

					var rim: float = clampf(float(mini(edge_x, edge_y)) / 3.0, 0.55, 1.0)
					var grain: float = 1.0 + rng.randf_range(-0.07, 0.07)
					image.set_pixel((px + x0) % tile, py, Color(stone.r * rim * grain, stone.g * rim * grain, stone.b * rim * grain))

			cursor += width

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
