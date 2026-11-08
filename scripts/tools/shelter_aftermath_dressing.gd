class_name ShelterAftermathDressing
extends RefCounted

## The blood of the aftermath photograph, dressed on the waiting shed's real geometry for ONE offline capture (`capture_shelter_aftermath.gd`), and
## nowhere else: the shipped game contains the resulting texture, never these meshes. A few textured quads close to the surfaces (alpha masks drawn in
## code from noise), no decals (the game may run on the Compatibility renderer, which has none), no particles, no simulation, nothing dynamic.
##
## What it shows is a place, not a reconstruction: broad, irregular dark-red staining across part of the seat and over its front edge, runs on the
## bench's front leg, a large pool on the slab between the bench and the cracked pillar with a smear toward it, droplets round it, and staining at the
## pillar's foot and up its face, with plenty of bare, textured surface between the stains. No body, no wound, no weapon, no figure, and nothing in
## the shapes that says how many blows or what struck them.
##
## Positions are in the space of the shed's root (the scene `waiting_shed.tscn`): the bench stands at (-4.3, 0.05, -5.8) with its seat top at y 0.49, the
## cracked pillar's foot at (-5.7, ., -4.0), the slab's top at y 0.05.

const WET: Color = Color(0.3, 0.025, 0.027)
const DRIED: Color = Color(0.13, 0.014, 0.018)
const MASK_SIZE: int = 256


## Adds the dressing as a node named `AftermathBlood` under `shed` and returns it.
static func build(shed: Node3D) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "AftermathBlood"
	shed.add_child(root)

	# The seat: a broad stain over the left half of the planks, running over the front plank's edge.
	_floor_quad(root, "SeatStain", _blob(11, 0.92, 0.9), Vector3(-4.68, 0.4935, -5.78), Vector2(1.5, 0.5), 4.0)
	_floor_quad(root, "SeatSmear", _blob(12, 0.6, 0.0), Vector3(-4.1, 0.4935, -5.72), Vector2(0.7, 0.3), -18.0)
	# Its edge and the bench's front leg: runs going down.
	_wall_quad(root, "EdgeRuns", _runs(21, 7), Vector3(-4.78, 0.455, -5.5815), Vector2(0.8, 0.09), 0.0)
	_wall_quad(root, "LegRuns", _runs(22, 5), Vector3(-5.05, 0.26, -5.5775), Vector2(0.14, 0.42), 0.0)
	# The slab: the pool in front of the bench, a smear toward the pillar, and the droplets round them.
	_floor_quad(root, "Pool", _blob(31, 0.86, 0.0), Vector3(-4.95, 0.0535, -5.05), Vector2(2.4, 1.5), -14.0)
	_floor_quad(root, "UnderBench", _blob(34, 0.8, 0.0), Vector3(-4.65, 0.0536, -5.62), Vector2(1.5, 0.6), 3.0)
	_floor_quad(root, "Smear", _blob(32, 0.7, 0.0), Vector3(-5.3, 0.0538, -4.5), Vector2(1.5, 0.7), 38.0)
	_floor_quad(root, "Drops", _droplets(33), Vector3(-4.9, 0.054, -4.95), Vector2(2.9, 1.9), 8.0)
	# The pillar's foot: the floor, and up the faces that look toward the bench and toward the open front.
	_floor_quad(root, "PillarFoot", _blob(41, 0.75, 0.0), Vector3(-5.5, 0.0537, -4.1), Vector2(1.0, 0.8), 20.0)
	_wall_quad(root, "PillarEast", _runs(42, 6), Vector3(-5.5755, 0.38, -4.0), Vector2(0.24, 0.62), 90.0)
	_wall_quad(root, "PillarFront", _runs(43, 5), Vector3(-5.7, 0.33, -3.8775), Vector2(0.24, 0.5), 0.0)
	return root


## The drag trail of the waiting shed's camcorder view (NOT part of the photograph, never captured by the tool): a smeared, uneven streak that runs along `points` (in the space of `parent`,
## on the floor, each point's y is the height the streak lies at) and thins as it goes, with a little spatter at both ends. Plain textured quads like the rest of this dressing. Returns the node
## `DragTrail` it makes under `parent`.
static func build_trail(parent: Node3D, points: PackedVector3Array) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "DragTrail"
	parent.add_child(root)
	var count: int = points.size()
	for i: int in range(count - 1):
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var flat: Vector2 = Vector2(to.x - from.x, to.z - from.z)
		var length: float = flat.length()
		if length < 0.01:
			continue

		var along: float = float(i) / float(maxi(count - 2, 1))
		var width: float = lerpf(0.6, 0.34, along)
		var middle: Vector3 = (from + to) * 0.5 + Vector3(0.0, 0.0006 * float(i), 0.0)
		# A little longer than the step so the pieces overlap and read as one smear.
		_floor_quad(root, "Smear%d" % i, _smear(60 + i, along), middle, Vector2(length + 0.22, width), rad_to_deg(atan2(-flat.y, flat.x)))
	_floor_quad(root, "StartSpatter", _droplets(71), points[0] + Vector3(0.0, 0.0012, 0.0), Vector2(0.9, 0.7), 20.0)
	_floor_quad(root, "EndSpatter", _droplets(72), points[count - 1] + Vector3(0.0, 0.0012, 0.0), Vector2(0.5, 0.5), -35.0)
	return root


## A streak along the quad's x axis: broad and heavy at the start, thin and broken at the end, darker where it is older, with parallel drag marks inside it.
static func _smear(seed_value: int, along_trail: float) -> ImageTexture:
	var width: int = MASK_SIZE
	var height: int = 96
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var shape: FastNoiseLite = _noise(seed_value, 3.0)
	var marks: FastNoiseLite = _noise(seed_value + 40, 5.0)
	var tone: FastNoiseLite = _noise(seed_value + 90, 4.0)
	for y: int in height:
		for x: int in width:
			var u: float = float(x) / float(width - 1)
			var v: float = (float(y) / float(height - 1)) * 2.0 - 1.0
			var body: float = lerpf(0.82, 0.55, clampf(along_trail + u * 0.2, 0.0, 1.0))
			var wobble: float = 0.2 * shape.get_noise_2d(x * 0.6, y * 1.4)
			var edge: float = body - absf(v + wobble) + 0.18 * shape.get_noise_2d(x * 1.5, y * 3.0)
			var alpha: float = smoothstep(0.0, 0.2, edge)
			# The streak thins out toward its ends and breaks up there.
			alpha *= smoothstep(0.0, 0.07, u) * smoothstep(1.0, 0.86, u)
			# Drag marks: lighter and darker stripes along the length.
			alpha *= 0.75 + 0.25 * smoothstep(-0.2, 0.4, marks.get_noise_2d(x * 0.3, y * 4.0))
			var dried: float = clampf(0.25 + 0.5 * tone.get_noise_2d(x, y) + along_trail * 0.4, 0.0, 1.0)
			var colour: Color = WET.lerp(DRIED, dried)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, clampf(alpha * 0.95, 0.0, 0.95)))
	return ImageTexture.create_from_image(image)


## Handwritten words in blood on a wall (the waiting shed's rear message), as a textured quad facing `facing_yaw` (degrees, 0 faces +Z, 180 faces -Z): uneven strokes made of a few letters' skeletons (a small
## stroke alphabet: C A L M E I G), wobbling, thicker where the finger pressed, with a few runs under the heaviest strokes. Dark red-brown, never a clean decal. `text` is upper case.
static func build_words(parent: Node3D, node_name: String, text: String, at: Vector3, size: Vector2, facing_yaw: float, drip: float = 0.0) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = quad
	instance.material_override = _material(words_texture(text, size.x / size.y, drip))
	instance.position = at
	instance.rotation_degrees = Vector3(0.0, facing_yaw, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


const GLYPHS: Dictionary = {
	"M": [[Vector2(0, 1), Vector2(0, 0), Vector2(0.5, 0.55), Vector2(1, 0), Vector2(1, 1)]],
	"E": [[Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)], [Vector2(0, 0.5), Vector2(0.72, 0.5)]],
	"L": [[Vector2(0, 0), Vector2(0, 1), Vector2(0.92, 1)]],
	"I": [[Vector2(0.5, 0), Vector2(0.5, 1)]],
	"G": [[Vector2(1, 0.14), Vector2(0.5, 0), Vector2(0, 0.3), Vector2(0, 0.7), Vector2(0.5, 1), Vector2(1, 0.86), Vector2(1, 0.56), Vector2(0.55, 0.56)]],
	"A": [[Vector2(0, 1), Vector2(0.5, 0), Vector2(1, 1)], [Vector2(0.2, 0.66), Vector2(0.8, 0.66)]],
	"C": [[Vector2(1, 0.16), Vector2(0.5, 0), Vector2(0, 0.3), Vector2(0, 0.7), Vector2(0.5, 1), Vector2(1, 0.84)]],
}


## The words' alpha mask and colour: strokes brushed along the glyphs with a wobbling width, a few runs below the heavy ones.
static func words_texture(text: String, aspect: float, drip: float = 0.0) -> ImageTexture:
	# `drip` is the extra height of the picture, as a share of the lettering's own (0 for none): the room under the words for the blood that runs down from them.
	var text_height: float = 128.0
	var height: int = int(round(text_height * (1.0 + drip)))
	var width: int = int(round(float(height) * aspect))
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(WET.r, WET.g, WET.b, 0.0))
	var wobble: FastNoiseLite = _noise(901, 6.0)
	var weight: FastNoiseLite = _noise(902, 3.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var letters: PackedStringArray = PackedStringArray()
	for i: int in text.length():
		letters.append(text.substr(i, 1))
	var advance: float = float(width) * 0.94 / float(maxi(letters.size(), 1))
	var glyph_w: float = advance * 0.66
	var glyph_h: float = text_height * 0.6
	var left: float = float(width) * 0.03
	var top: float = text_height * 0.1
	var heavy: Array[Vector2] = []
	for i: int in letters.size():
		var strokes: Array = GLYPHS.get(letters[i], [])
		var ox: float = left + advance * float(i) + rng.randf_range(-3.0, 3.0)
		var oy: float = top + rng.randf_range(-4.0, 4.0)
		for stroke: Array in strokes:
			for k: int in range(stroke.size() - 1):
				var a: Vector2 = stroke[k]
				var b: Vector2 = stroke[k + 1]
				var steps: int = int(maxf(a.distance_to(b) * 40.0, 4.0))
				for s: int in steps + 1:
					var t: float = float(s) / float(steps)
					var p: Vector2 = a.lerp(b, t)
					var px: float = ox + p.x * glyph_w + wobble.get_noise_2d(p.x * 40.0 + float(i) * 13.0, p.y * 40.0) * 4.0
					var py: float = oy + p.y * glyph_h + wobble.get_noise_2d(p.y * 40.0, p.x * 40.0 + float(i) * 7.0) * 4.0
					var radius: float = 4.2 + 2.0 * weight.get_noise_2d(px, py) + 0.8 * sin(float(s) * 0.7)
					_dab(image, px, py, radius)
					if (rng.randf() < 0.07) if drip > 0.0 else (radius > 5.4 and rng.randf() < 0.12):
						heavy.append(Vector2(px, py))
	for spot: Vector2 in heavy:
		# With room under the words (`drip`) the blood runs a long way down the wall, thinning as it goes and gathering in a bead at the end; otherwise only a short run.
		var run_length: float = rng.randf_range(6.0, 22.0) if drip <= 0.0 else rng.randf_range(26.0, 40.0 + 110.0 * drip * rng.randf())
		var run_width: float = 1.7 if drip <= 0.0 else rng.randf_range(2.6, 4.2)
		var y: float = spot.y
		while y < spot.y + run_length and y < float(height) - 4.0:
			var share: float = (y - spot.y) / run_length
			_dab(image, spot.x + wobble.get_noise_2d(spot.x, y) * 1.2, y, run_width * (1.0 - 0.35 * share))
			y += 1.0
		if drip > 0.0 and y < float(height) - 3.0:
			_dab(image, spot.x + wobble.get_noise_2d(spot.x, y) * 1.2, y + 1.0, run_width * 1.6)
	return ImageTexture.create_from_image(image)


## One round touch of the brush: the paint is darker at its middle and the edge is a little ragged.
static func _dab(image: Image, cx: float, cy: float, radius: float) -> void:
	var x0: int = maxi(int(cx - radius - 1.0), 0)
	var x1: int = mini(int(cx + radius + 1.0), image.get_width() - 1)
	var y0: int = maxi(int(cy - radius - 1.0), 0)
	var y1: int = mini(int(cy + radius + 1.0), image.get_height() - 1)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var d: float = Vector2(float(x) - cx, float(y) - cy).length() / maxf(radius, 0.5)
			if d < 1.0:
				var alpha: float = clampf((1.0 - d) * 2.4, 0.0, 0.96)
				var old: Color = image.get_pixel(x, y)
				if alpha > old.a:
					var colour: Color = WET.lerp(DRIED, clampf(d * 0.9, 0.0, 1.0) * 0.5)
					image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, alpha))


static func _material(texture: Texture2D) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.85
	material.metallic_specular = 0.12
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## A horizontal quad lying on a surface (`yaw` in degrees about the vertical).
static func _floor_quad(parent: Node3D, node_name: String, texture: Texture2D, at: Vector3, size: Vector2, yaw: float) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = quad
	instance.material_override = _material(texture)
	instance.position = at
	instance.rotation_degrees = Vector3(-90.0, yaw, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


## A vertical quad against a face (`yaw` 0 faces +Z, 90 faces +X).
static func _wall_quad(parent: Node3D, node_name: String, texture: Texture2D, at: Vector3, size: Vector2, yaw: float) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = quad
	instance.material_override = _material(texture)
	instance.position = at
	instance.rotation_degrees = Vector3(0.0, yaw, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 4
	return noise


## An irregular stain: a soft, uneven blob (`reach` how much of the quad it fills), darker and clotted toward its middle, with bare patches left in it;
## `tongue` pulls one side out into a run.
static func _blob(seed_value: int, reach: float, tongue: float) -> ImageTexture:
	var image: Image = Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	var shape: FastNoiseLite = _noise(seed_value, 2.2)
	var tone: FastNoiseLite = _noise(seed_value + 100, 4.0)
	var holes: FastNoiseLite = _noise(seed_value + 200, 7.0)
	for y: int in MASK_SIZE:
		for x: int in MASK_SIZE:
			var u: float = (float(x) / (MASK_SIZE - 1)) * 2.0 - 1.0
			var v: float = (float(y) / (MASK_SIZE - 1)) * 2.0 - 1.0
			var r: float = sqrt(u * u + v * v) / maxf(reach, 0.05)
			# The run: a lobe toward +u that widens the stain along one side.
			var lobe: float = tongue * 0.5 * exp(-pow((v + 0.1) / 0.28, 2.0)) * smoothstep(-0.2, 0.9, u)
			var edge: float = 1.0 - r + 0.55 * shape.get_noise_2d(x, y) + lobe
			var alpha: float = smoothstep(0.0, 0.16, edge)
			alpha *= 1.0 - 0.45 * smoothstep(0.35, 0.62, holes.get_noise_2d(x, y)) * smoothstep(0.1, 0.5, edge)
			var dried: float = smoothstep(-0.2, 0.5, tone.get_noise_2d(x, y)) * smoothstep(0.1, 0.7, edge)
			var colour: Color = WET.lerp(DRIED, dried)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, clampf(alpha * 0.97, 0.0, 0.97)))
	return ImageTexture.create_from_image(image)


## Streaks that run down a face from its top edge: tapering, some long, some short, the heaviest near the top.
static func _runs(seed_value: int, count: int) -> ImageTexture:
	var image: Image = Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(WET.r, WET.g, WET.b, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var wobble: FastNoiseLite = _noise(seed_value + 7, 3.0)
	for k: int in count:
		var centre: float = (float(k) + rng.randf_range(0.25, 0.75)) / float(count) * MASK_SIZE
		var width: float = rng.randf_range(0.035, 0.085) * MASK_SIZE
		var length: float = rng.randf_range(0.35, 0.98) * MASK_SIZE
		for y: int in MASK_SIZE:
			var along: float = float(y) / length
			if along > 1.0:
				break
			var taper: float = width * (1.0 - 0.7 * along)
			var drift: float = wobble.get_noise_2d(centre, y) * width * 0.6
			for x: int in range(maxi(int(centre + drift - taper), 0), mini(int(centre + drift + taper) + 1, MASK_SIZE)):
				var across: float = absf(float(x) - (centre + drift)) / maxf(taper, 1.0)
				var alpha: float = (1.0 - across * across) * (0.93 - 0.25 * along)
				var old: Color = image.get_pixel(x, y)
				if alpha > old.a:
					var colour: Color = WET.lerp(DRIED, clampf(0.2 + 0.6 * along, 0.0, 1.0) * 0.6)
					image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, alpha))
	# The pooled edge at the top, where the runs begin.
	for y: int in range(0, int(MASK_SIZE * 0.1)):
		var fade: float = 1.0 - float(y) / (MASK_SIZE * 0.1)
		for x: int in MASK_SIZE:
			var old: Color = image.get_pixel(x, y)
			var alpha: float = maxf(old.a, 0.85 * fade * (0.7 + 0.3 * wobble.get_noise_2d(x, 40)))
			if alpha > old.a:
				image.set_pixel(x, y, Color(DRIED.r, DRIED.g, DRIED.b, alpha))
	return ImageTexture.create_from_image(image)


## Droplets and small splashes scattered round a stain, thinning out toward the edges.
static func _droplets(seed_value: int) -> ImageTexture:
	var image: Image = Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(WET.r, WET.g, WET.b, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in 210:
		var u: float = rng.randfn(0.0, 0.42)
		var v: float = rng.randfn(0.0, 0.42)
		if absf(u) > 0.97 or absf(v) > 0.97:
			continue
		var cx: float = (u * 0.5 + 0.5) * MASK_SIZE
		var cy: float = (v * 0.5 + 0.5) * MASK_SIZE
		var radius: float = rng.randf_range(0.8, 4.5) * (1.0 - 0.6 * minf(sqrt(u * u + v * v), 1.0))
		var stretch: float = rng.randf_range(1.0, 1.9)
		var angle: float = rng.randf_range(0.0, PI)
		for y: int in range(int(cy - radius * 2.0), int(cy + radius * 2.0) + 1):
			for x: int in range(int(cx - radius * 2.0), int(cx + radius * 2.0) + 1):
				if x < 0 or y < 0 or x >= MASK_SIZE or y >= MASK_SIZE:
					continue
				var dx: float = float(x) - cx
				var dy: float = float(y) - cy
				var along: float = (dx * cos(angle) + dy * sin(angle)) / stretch
				var across: float = -dx * sin(angle) + dy * cos(angle)
				var d: float = sqrt(along * along + across * across) / radius
				if d < 1.0:
					var alpha: float = (1.0 - d * d) * 0.92
					var old: Color = image.get_pixel(x, y)
					if alpha > old.a:
						image.set_pixel(x, y, Color(DRIED.r, DRIED.g, DRIED.b, alpha))
	return ImageTexture.create_from_image(image)
