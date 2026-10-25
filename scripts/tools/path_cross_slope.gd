extends Node

## One-off terrain tool, run as a scene (the plants need a renderer): `Godot --path . res://scripts/tools/path_cross_slope.tscn`.
##
## Measures the CROSS slope of the trails: how much the ground tilts sideways, across the walking direction, where the player walks
## (the path texture, Terrain3D slot 1). A path that climbs or descends is fine; one whose ground leans to one side feels like walking on a
## slanted floor (developer feedback: trail A from the fence door to the fig clearing leans up to 30 degrees). Prints how many path cells
## lean more than each angle and where the worst stretches are.
##
## Add `-- --apply` to ease the lean (it never makes the path level):
##  - every path cell that has a direction gets the plane of the path around it (least squares over the path cells within `FIT_RADIUS`),
##    whose sideways slope is `lean`; the lean is compressed with `_eased_lean`: nothing below `KEEP_DEGREES`, a quarter of the rest above it
##    (32 degrees becomes about 13, 22 about 10, 15 about 8, 10 about 7, in theory; in practice the forks come out 12-17);
##  - the height of the ground beside the path, across the walking direction, is changed by the difference of the two slopes times the
##    distance from the middle of the path (a cut on the high side, a fill on the low side), the middle of the path keeping its height, so
##    the way along the trail is the same; the change fades to nothing `MARGIN` metres from the path, and the result is blurred so no
##    seam shows where the nearest stretch changes;
##  - all of that is done `PASSES` times (the second pass catches the forks, where the direction is not clear the first time);
##  - nothing changes inside the curated sites (the wagon yard and the gate, the waiting shed, the fig clearing, the signal tower, the
##    unfinished house, the overlook), fading in over `GUARD_FADE` metres outside them;
##  - the plants of the instancer (mesh ids below `MAX_PLANT_ID`) keep their height above the ground: each is moved by the change under it.
## Heights are changed, nothing else, and only the regions that changed are saved. Run it ONCE on a terrain that was not eased (a second run eases it again).

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
const PATH_TEXTURE: int = 1
const X0: int = -14
const Z0: int = -90
const WIDTH: int = 204
const HEIGHT: int = 164
## A path cell's direction is read from the path cells within this radius; a place where they do not line up (a junction, a clearing)
## has no direction and is left to its neighbours.
const DIRECTION_RADIUS: int = 4
const MIN_ELONGATION: float = 2.5
const GRADIENT_STEP: float = 1.25
## The plane of the path is fitted over the path cells within this radius.
const FIT_RADIUS: int = 5
## How the lean is eased: left alone up to this angle, and above it only this fraction of the excess stays.
const KEEP_DEGREES: float = 6.0
const EXCESS_KEPT: float = 0.25
## Where the change reaches: metres from the path where it has faded to nothing, and the distance from the path cells at which it starts to.
const MARGIN: float = 8.0
const FULL_WITHIN: float = 2.0
## The lean is eased this many times over (a pass takes the worst of it down to about 17 degrees, two to about 12; a stretch that was
## already gentle is left alone by both).
const PASSES: int = 2
## The lean of a stretch is averaged with its neighbours within this many cells.
const SMOOTH_RADIUS: int = 6
## The change is blurred with a box of this radius, this many times.
const BLUR_RADIUS: int = 1
const BLUR_PASSES: int = 2
const MAX_PLANT_ID: int = 25
## Sites that keep their ground: centre (x, z) and radius. The change fades in over `GUARD_FADE` metres beyond the radius.
const GUARDS: Array[Vector3] = [
	Vector3(9.0, 6.0, 9.0),
	Vector3(65.0, -16.0, 15.0),
	Vector3(64.0, -68.0, 20.0),
	Vector3(101.5, -36.0, 17.0),
	Vector3(68.5, 55.0, 25.0),
	Vector3(170.0, 26.0, 26.0),
]
## The hand-made wagon yard and gate (everything west of x = 14) keeps its ground whole.
const GUARD_RECTS: Array[Rect2] = [Rect2(-14.0, -90.0, 28.0, 164.0)]
const GUARD_FADE: float = 6.0

var _terrain: Terrain3D = null
var _is_path: PackedByteArray = PackedByteArray()
var _heights: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var apply: bool = OS.get_cmdline_user_args().has("--apply")
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	_terrain = scene.get_node("Terrain3D") as Terrain3D
	_read()
	_report("BEFORE")
	if apply:
		for pass_index: int in PASSES:
			_ease_the_lean()
			_read()

		_report("AFTER")

	get_tree().quit()


func _index(x: int, z: int) -> int:
	return z * WIDTH + x


func _inside(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < WIDTH and z < HEIGHT


## Reads the path mask and the heights, at the vertices of the terrain (a vertex a metre).
func _read() -> void:
	_is_path.resize(WIDTH * HEIGHT)
	_heights.resize(WIDTH * HEIGHT)
	for x: int in WIDTH:
		for z: int in HEIGHT:
			var world: Vector3 = Vector3(float(X0 + x), 0.0, float(Z0 + z))
			var id: Vector3 = _terrain.data.get_texture_id(world)
			_is_path[_index(x, z)] = 1 if (int(id.x) == PATH_TEXTURE or (int(id.y) == PATH_TEXTURE and id.z > 0.5)) else 0
			_heights[_index(x, z)] = _terrain.data.get_height(world)


## The direction of the path at a cell (x, z unit vector) or a zero vector.
func _direction(x: int, z: int) -> Vector2:
	var count: int = 0
	var mean: Vector2 = Vector2.ZERO
	for dx: int in range(-DIRECTION_RADIUS, DIRECTION_RADIUS + 1):
		for dz: int in range(-DIRECTION_RADIUS, DIRECTION_RADIUS + 1):
			if dx * dx + dz * dz > DIRECTION_RADIUS * DIRECTION_RADIUS or not _inside(x + dx, z + dz):
				continue

			if _is_path[_index(x + dx, z + dz)] == 1:
				mean += Vector2(dx, dz)
				count += 1

	if count < 8:
		return Vector2.ZERO

	mean /= float(count)
	var sxx: float = 0.0
	var sxz: float = 0.0
	var szz: float = 0.0
	for dx: int in range(-DIRECTION_RADIUS, DIRECTION_RADIUS + 1):
		for dz: int in range(-DIRECTION_RADIUS, DIRECTION_RADIUS + 1):
			if dx * dx + dz * dz > DIRECTION_RADIUS * DIRECTION_RADIUS or not _inside(x + dx, z + dz) or _is_path[_index(x + dx, z + dz)] == 0:
				continue

			var offset: Vector2 = Vector2(dx, dz) - mean
			sxx += offset.x * offset.x
			sxz += offset.x * offset.y
			szz += offset.y * offset.y

	var trace: float = sxx + szz
	var determinant: float = sxx * szz - sxz * sxz
	var spread: float = sqrt(maxf(trace * trace * 0.25 - determinant, 0.0))
	var large: float = trace * 0.5 + spread
	var small: float = trace * 0.5 - spread
	if small <= 0.0001 or large / small < MIN_ELONGATION:
		return Vector2.ZERO

	var angle: float = 0.5 * atan2(2.0 * sxz, sxx - szz)
	return Vector2(cos(angle), sin(angle))


## The gradient of the ground at a cell, differenced over `GRADIENT_STEP`.
func _gradient(x: int, z: int) -> Vector2:
	var world: Vector3 = Vector3(float(X0 + x), 0.0, float(Z0 + z))
	var data: Terrain3DData = _terrain.data
	return Vector2(
		(data.get_height(world + Vector3(GRADIENT_STEP, 0.0, 0.0)) - data.get_height(world - Vector3(GRADIENT_STEP, 0.0, 0.0))) / (2.0 * GRADIENT_STEP),
		(data.get_height(world + Vector3(0.0, 0.0, GRADIENT_STEP)) - data.get_height(world - Vector3(0.0, 0.0, GRADIENT_STEP))) / (2.0 * GRADIENT_STEP))


func _report(label: String) -> void:
	var thresholds: Array[float] = [5.0, 8.0, 10.0, 12.0, 15.0, 20.0, 25.0]
	var over: Array[int] = []
	over.resize(thresholds.size())
	var measured: int = 0
	var bins: Dictionary = {}
	var path_cells: int = 0
	for x: int in WIDTH:
		for z: int in HEIGHT:
			if _is_path[_index(x, z)] == 0:
				continue

			path_cells += 1
			var direction: Vector2 = _direction(x, z)
			if direction == Vector2.ZERO:
				continue

			var gradient: Vector2 = _gradient(x, z)
			var normal: Vector2 = Vector2(-direction.y, direction.x)
			var cross: float = rad_to_deg(atan(absf(gradient.dot(normal))))
			var along: float = rad_to_deg(atan(gradient.dot(direction)))
			measured += 1
			for i: int in thresholds.size():
				if cross > thresholds[i]:
					over[i] += 1

			if cross > 10.0:
				var key: Vector2i = Vector2i(floori(float(X0 + x) / 10.0), floori(float(Z0 + z) / 10.0))
				if not bins.has(key):
					bins[key] = []
				(bins[key] as Array).append(Vector2(cross, along))

	print("%s: PATH CELLS %d, MEASURED %d" % [label, path_cells, measured])
	for i: int in thresholds.size():
		print("%s: CROSS > %.0f deg: %d (%.1f%%)" % [label, thresholds[i], over[i], 100.0 * float(over[i]) / maxf(float(measured), 1.0)])

	var keys: Array = bins.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (bins[a] as Array).size() > (bins[b] as Array).size())
	for key: Vector2i in keys.slice(0, 14):
		var list: Array = bins[key]
		var mean_cross: float = 0.0
		var worst: float = 0.0
		for slopes: Vector2 in list:
			mean_cross += slopes.x
			worst = maxf(worst, slopes.x)

		print("%s: BIN x %d..%d z %d..%d: %d cells over 10 deg, mean cross %.1f worst %.1f" % [
			label, key.x * 10, key.x * 10 + 10, key.y * 10, key.y * 10 + 10, list.size(), mean_cross / list.size(), worst])


## The lean (a slope, signed) that remains of `lean` after easing.
func _eased_lean(lean: float) -> float:
	var keep: float = tan(deg_to_rad(KEEP_DEGREES))
	var size: float = absf(lean)
	if size <= keep:
		return lean

	return signf(lean) * (keep + (size - keep) * EXCESS_KEPT)


## How much of the change the sites let through (0 inside them, 1 far from them).
func _guard_weight(world: Vector2) -> float:
	var weight: float = 1.0
	for guard: Vector3 in GUARDS:
		var beyond: float = world.distance_to(Vector2(guard.x, guard.y)) - guard.z
		weight = minf(weight, smoothstep(0.0, GUARD_FADE, beyond))

	for rect: Rect2 in GUARD_RECTS:
		var nearest: Vector2 = Vector2(clampf(world.x, rect.position.x, rect.end.x), clampf(world.y, rect.position.y, rect.end.y))
		weight = minf(weight, smoothstep(0.0, GUARD_FADE, world.distance_to(nearest)))

	return weight


func _ease_the_lean() -> void:
	var count: int = WIDTH * HEIGHT
	# 1. What every path cell with a direction says: the lean to take away (a slope across the path), the middle of the path nearby, the
	# direction across it.
	var correction: PackedFloat32Array = PackedFloat32Array()
	correction.resize(count)
	var centre_x: PackedFloat32Array = PackedFloat32Array()
	centre_x.resize(count)
	var centre_z: PackedFloat32Array = PackedFloat32Array()
	centre_z.resize(count)
	var normal_x: PackedFloat32Array = PackedFloat32Array()
	normal_x.resize(count)
	var normal_z: PackedFloat32Array = PackedFloat32Array()
	normal_z.resize(count)
	var has_direction: PackedByteArray = PackedByteArray()
	has_direction.resize(count)
	var directional: Array[Vector2i] = []
	for x: int in WIDTH:
		for z: int in HEIGHT:
			if _is_path[_index(x, z)] == 0:
				continue

			var direction: Vector2 = _direction(x, z)
			if direction == Vector2.ZERO:
				continue

			var fit: Dictionary = _fit_plane(x, z)
			if fit.is_empty():
				continue

			var normal: Vector2 = Vector2(-direction.y, direction.x)
			var gradient: Vector2 = fit["gradient"]
			var lean: float = gradient.dot(normal)
			var index: int = _index(x, z)
			correction[index] = lean - _eased_lean(lean)
			var centre: Vector2 = fit["centre"]
			centre_x[index] = centre.x
			centre_z[index] = centre.y
			normal_x[index] = normal.x
			normal_z[index] = normal.y
			has_direction[index] = 1
			directional.append(Vector2i(x, z))

	# 2. The correction of a stretch is the average of its neighbours' (the normal is kept from the cell itself: a sign flip of the
	# direction between neighbours must not cancel, so each neighbour's correction is taken along the normal of the cell).
	var smoothed: PackedFloat32Array = correction.duplicate()
	for cell: Vector2i in directional:
		var index: int = _index(cell.x, cell.y)
		var reference: Vector2 = Vector2(normal_x[index], normal_z[index])
		var sum: float = 0.0
		var weight: float = 0.0
		for dx: int in range(-SMOOTH_RADIUS, SMOOTH_RADIUS + 1):
			for dz: int in range(-SMOOTH_RADIUS, SMOOTH_RADIUS + 1):
				if dx * dx + dz * dz > SMOOTH_RADIUS * SMOOTH_RADIUS or not _inside(cell.x + dx, cell.y + dz):
					continue

				var other: int = _index(cell.x + dx, cell.y + dz)
				if has_direction[other] == 0:
					continue

				var other_normal: Vector2 = Vector2(normal_x[other], normal_z[other])
				var sign_of_normal: float = signf(other_normal.dot(reference))
				if sign_of_normal == 0.0 or absf(other_normal.dot(reference)) < 0.6:
					continue

				sum += correction[other] * sign_of_normal
				weight += 1.0

		if weight > 0.0:
			smoothed[index] = sum / weight

	# 3. Distance from the path (every path cell), and the nearest cell with a direction, both by a sweep outwards.
	var distance: PackedFloat32Array = PackedFloat32Array()
	distance.resize(count)
	distance.fill(1e9)
	var source: PackedInt32Array = PackedInt32Array()
	source.resize(count)
	source.fill(-1)
	var queue: Array[int] = []
	for x: int in WIDTH:
		for z: int in HEIGHT:
			if _is_path[_index(x, z)] == 1:
				distance[_index(x, z)] = 0.0
	# The nearest directional cell, for every cell within MARGIN + a bit of one.
	var reach: float = MARGIN + 3.0
	for cell: Vector2i in directional:
		var index: int = _index(cell.x, cell.y)
		source[index] = index
		queue.append(index)

	var nearest_directional: PackedFloat32Array = PackedFloat32Array()
	nearest_directional.resize(count)
	nearest_directional.fill(1e9)
	for index: int in queue:
		nearest_directional[index] = 0.0

	var head: int = 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var x: int = index % WIDTH
		var z: int = index / WIDTH
		var d: float = nearest_directional[index]
		if d > reach:
			continue

		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				if dx == 0 and dz == 0 or not _inside(x + dx, z + dz):
					continue

				var other: int = _index(x + dx, z + dz)
				var step: float = 1.0 if dx == 0 or dz == 0 else 1.4142
				if nearest_directional[other] > d + step + 0.001:
					nearest_directional[other] = d + step
					source[other] = source[index]
					queue.append(other)

	# Distance to the nearest path cell of any kind (for the fade).
	var path_queue: Array[int] = []
	for x: int in WIDTH:
		for z: int in HEIGHT:
			if _is_path[_index(x, z)] == 1:
				path_queue.append(_index(x, z))

	head = 0
	while head < path_queue.size():
		var index: int = path_queue[head]
		head += 1
		var x: int = index % WIDTH
		var z: int = index / WIDTH
		var d: float = distance[index]
		if d > MARGIN:
			continue

		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				if dx == 0 and dz == 0 or not _inside(x + dx, z + dz):
					continue

				var other: int = _index(x + dx, z + dz)
				var step: float = 1.0 if dx == 0 or dz == 0 else 1.4142
				if distance[other] > d + step + 0.001:
					distance[other] = d + step
					path_queue.append(other)

	# 4. The change of height of every cell near the path.
	var change: PackedFloat32Array = PackedFloat32Array()
	change.resize(count)
	for x: int in WIDTH:
		for z: int in HEIGHT:
			var index: int = _index(x, z)
			if distance[index] > MARGIN or source[index] < 0:
				continue

			var s: int = source[index]
			var offset: Vector2 = Vector2(float(x) - centre_x[s], float(z) - centre_z[s])
			var across: float = offset.dot(Vector2(normal_x[s], normal_z[s]))
			var fade: float = 1.0 - smoothstep(FULL_WITHIN, MARGIN, distance[index])
			# Not further across than the path and its margin: a cell nearest to the end of a stretch must not take a long lever.
			across = clampf(across, -(MARGIN + 2.0), MARGIN + 2.0)
			change[index] = -smoothed[s] * across * fade

	# 5. Blurred, so that no seam shows, and let through by the sites only far from them.
	for pass_index: int in BLUR_PASSES:
		var blurred: PackedFloat32Array = change.duplicate()
		for x: int in WIDTH:
			for z: int in HEIGHT:
				var sum: float = 0.0
				var number: int = 0
				for dx: int in range(-BLUR_RADIUS, BLUR_RADIUS + 1):
					for dz: int in range(-BLUR_RADIUS, BLUR_RADIUS + 1):
						if _inside(x + dx, z + dz):
							sum += change[_index(x + dx, z + dz)]
							number += 1

				blurred[_index(x, z)] = sum / float(maxi(number, 1))

		change = blurred

	var applied: int = 0
	var biggest: float = 0.0
	for x: int in WIDTH:
		for z: int in HEIGHT:
			var index: int = _index(x, z)
			change[index] *= _guard_weight(Vector2(float(X0 + x), float(Z0 + z)))
			if absf(change[index]) > 0.004:
				applied += 1
				biggest = maxf(biggest, absf(change[index]))

	print("CHANGED CELLS ", applied, " largest change ", snappedf(biggest, 0.01), " m")

	# 6. Heights.
	for x: int in WIDTH:
		for z: int in HEIGHT:
			var index: int = _index(x, z)
			if absf(change[index]) > 0.004:
				_terrain.data.set_height(Vector3(float(X0 + x), 0.0, float(Z0 + z)), _heights[index] + change[index])

	_terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)

	# 7. The plants keep their height over the ground.
	_follow_plants(change)
	_terrain.data.save_directory(TERRAIN_DIRECTORY)
	print("SAVED terrain data")


## The plane through the path cells within `FIT_RADIUS` of a cell: its gradient and the middle of those cells. Empty when there are too few.
func _fit_plane(x: int, z: int) -> Dictionary:
	var count: int = 0
	var mean: Vector2 = Vector2.ZERO
	var mean_height: float = 0.0
	for dx: int in range(-FIT_RADIUS, FIT_RADIUS + 1):
		for dz: int in range(-FIT_RADIUS, FIT_RADIUS + 1):
			if dx * dx + dz * dz > FIT_RADIUS * FIT_RADIUS or not _inside(x + dx, z + dz):
				continue

			var index: int = _index(x + dx, z + dz)
			if _is_path[index] == 1:
				mean += Vector2(float(x + dx), float(z + dz))
				mean_height += _heights[index]
				count += 1

	if count < 10:
		return {}

	mean /= float(count)
	mean_height /= float(count)
	var sxx: float = 0.0
	var sxz: float = 0.0
	var szz: float = 0.0
	var sxh: float = 0.0
	var szh: float = 0.0
	for dx: int in range(-FIT_RADIUS, FIT_RADIUS + 1):
		for dz: int in range(-FIT_RADIUS, FIT_RADIUS + 1):
			if dx * dx + dz * dz > FIT_RADIUS * FIT_RADIUS or not _inside(x + dx, z + dz):
				continue

			var index: int = _index(x + dx, z + dz)
			if _is_path[index] == 0:
				continue

			var offset: Vector2 = Vector2(float(x + dx), float(z + dz)) - mean
			var rise: float = _heights[index] - mean_height
			sxx += offset.x * offset.x
			sxz += offset.x * offset.y
			szz += offset.y * offset.y
			sxh += offset.x * rise
			szh += offset.y * rise

	var determinant: float = sxx * szz - sxz * sxz
	if absf(determinant) < 0.0001:
		return {}

	var gradient: Vector2 = Vector2((sxh * szz - szh * sxz) / determinant, (szh * sxx - sxh * sxz) / determinant)
	return {"gradient": gradient, "centre": mean}


## Moves every plant by the change of height under it (bilinear over the grid of changes).
func _follow_plants(change: PackedFloat32Array) -> void:
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var moved: int = 0
	for region: Terrain3DRegion in _terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		for mesh_id: int in instances.keys():
			if mesh_id >= MAX_PLANT_ID:
				continue

			var transforms: Array[Transform3D] = []
			var colors: PackedColorArray = PackedColorArray()
			var changed: bool = false
			var cells: Dictionary = instances[mesh_id]
			for cell: Variant in cells:
				var cell_transforms: Array = cells[cell][0]
				var cell_colors: PackedColorArray = cells[cell][1]
				for i: int in cell_transforms.size():
					var transform: Transform3D = cell_transforms[i]
					var shift: float = _change_at(change, transform.origin.x + offset.x, transform.origin.z + offset.y)
					if absf(shift) > 0.004:
						transform.origin.y += shift
						changed = true
						moved += 1

					transforms.append(transform)
					colors.append(cell_colors[i] if i < cell_colors.size() else Color.WHITE)

			if changed:
				instancer.clear_by_region(region, mesh_id)
				instancer.append_region(region, mesh_id, transforms, colors, true)

	print("PLANTS MOVED ", moved)


func _change_at(change: PackedFloat32Array, world_x: float, world_z: float) -> float:
	var fx: float = world_x - float(X0)
	var fz: float = world_z - float(Z0)
	var x: int = floori(fx)
	var z: int = floori(fz)
	if x < 0 or z < 0 or x + 1 >= WIDTH or z + 1 >= HEIGHT:
		return 0.0

	var tx: float = fx - float(x)
	var tz: float = fz - float(z)
	var top: float = lerpf(change[_index(x, z)], change[_index(x + 1, z)], tx)
	var bottom: float = lerpf(change[_index(x, z + 1)], change[_index(x + 1, z + 1)], tx)
	return lerpf(top, bottom, tz)
