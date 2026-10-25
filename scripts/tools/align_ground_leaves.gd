extends Node

## One-off terrain edit, run as a scene in a real window: `Godot --path . res://scripts/tools/align_ground_leaves.tscn` prints how the leaf litter lies on the
## ground; add `-- --apply` to put right what floats.
##
## The dead leaves of the forest floor (mesh id 5, `ground_leaves_01`) are a flat sheet about three metres across. Planted level on a slope or a rounded
## bit of ground, one side of it hangs in the air (and the other goes under the soil), which looks like a plate laid on the ground. This looks at every
## sheet: where its leaves float more than `FLOAT_LIMIT` over the terrain (measured on the model's real vertices) it is tipped to lie along the ground
## (the plane that fits the ground under it best), put down so that nothing floats more than a hair, and, where the ground is too bumpy for one sheet to
## follow, made smaller (a sheet is scaled down a step at a time, down to `SMALLEST`) or, if even that does not fit, taken away.
## Sheets that already lie on the ground are not touched, and neither is anything else: no other plant, no position (a sheet only turns about its own
## middle and goes up or down; a smaller one keeps its middle). It can be run again.

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
const LEAF_ID: int = 5
## The sheet's flat part: the vertices of its model lower than this are the ones that should lie on the ground.
const BASE_HEIGHT: float = 0.06
## A sheet that floats more than this (metres) over the ground at some leaf is put right.
const FLOAT_LIMIT: float = 0.025
## Where the highest leaf of a sheet that was put right stays over the ground, and the most it may be sunk or raised to get there.
const FLOAT_TARGET: float = 0.015
const MAX_RAISE: float = 0.04
## A sheet is given up (made smaller, or taken away) when this share of its flat leaves are buried deeper than `BURIED` under the ground.
const BURIED: float = 0.07
const BURIED_SHARE: float = 0.3
## The scales a sheet is tried at, as shares of its own, and the least it can be.
const SHRINK_STEPS: Array[float] = [1.0, 0.8, 0.62, 0.48]
const SMALLEST: float = 0.18

var _terrain: Terrain3D = null
var _base: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	var apply: bool = OS.get_cmdline_user_args().has("--apply")
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	_terrain = scene.get_node("Terrain3D") as Terrain3D
	var asset: Terrain3DMeshAsset = _terrain.assets.get_mesh_asset(LEAF_ID)
	var arrays: Array = asset.get_mesh().surface_get_arrays(0)
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		if vertex.y < BASE_HEIGHT:
			_base.append(vertex)

	print("LEAF MODEL flat vertices ", _base.size())
	var instancer: Terrain3DInstancer = _terrain.get_instancer()
	var region_size: float = float(_terrain.region_size) * _terrain.vertex_spacing
	var total: int = 0
	var floating: int = 0
	var tipped: int = 0
	var shrunk: int = 0
	var removed: int = 0
	var worst_before: float = 0.0
	var worst_after: float = 0.0
	var gaps: Array[float] = []
	var changed_regions: Array[Vector2i] = []
	for region: Terrain3DRegion in _terrain.data.get_regions_active():
		var offset: Vector2 = Vector2(region.location) * region_size
		var instances: Dictionary = region.get_instances()
		if not instances.has(LEAF_ID):
			continue

		var transforms: Array[Transform3D] = []
		var colors: PackedColorArray = PackedColorArray()
		var changed: bool = false
		var cells: Dictionary = instances[LEAF_ID]
		for cell: Variant in cells:
			var cell_transforms: Array = cells[cell][0]
			var cell_colors: PackedColorArray = cells[cell][1]
			for i: int in cell_transforms.size():
				var transform: Transform3D = cell_transforms[i]
				var color: Color = cell_colors[i] if i < cell_colors.size() else Color.WHITE
				total += 1
				var world: Transform3D = Transform3D(transform.basis, transform.origin + Vector3(offset.x, 0.0, offset.y))
				var report: Dictionary = _measure(world)
				if bool(report["no_ground"]):
					transforms.append(transform)
					colors.append(color)
					continue

				var gap: float = report["highest"]
				gaps.append(gap)
				worst_before = maxf(worst_before, gap)
				if gap <= FLOAT_LIMIT:
					transforms.append(transform)
					colors.append(color)
					continue

				floating += 1
				var fixed: Dictionary = _put_right(world)
				if fixed.is_empty():
					removed += 1
					changed = true
					continue

				var result: Transform3D = fixed["transform"]
				if bool(fixed["shrunk"]):
					shrunk += 1
				else:
					tipped += 1

				worst_after = maxf(worst_after, float(fixed["highest"]))
				changed = true
				transforms.append(Transform3D(result.basis, result.origin - Vector3(offset.x, 0.0, offset.y)))
				colors.append(color)

		if apply and changed:
			instancer.clear_by_region(region, LEAF_ID)
			instancer.append_region(region, LEAF_ID, transforms, colors, true)
			changed_regions.append(region.location)

	gaps.sort()
	for limit: float in [0.015, 0.02, 0.03, 0.04, 0.08, 0.15]:
		var over: int = 0
		for gap_value: float in gaps:
			if gap_value > limit:
				over += 1

		print("  sheets floating more than ", limit, " m: ", over)

	print("LEAF SHEETS ", total, ": floating more than ", FLOAT_LIMIT, " m: ", floating, " (worst ", snappedf(worst_before, 0.001), " m, median of all ", snappedf(gaps[gaps.size() / 2], 0.001), " m)")
	print("  tipped to the ground ", tipped, ", made smaller ", shrunk, ", taken away ", removed, ", the highest leaf over the ground after: ", snappedf(worst_after, 0.001), " m")
	if apply:
		for location: Vector2i in changed_regions:
			_terrain.data.save_region(location, TERRAIN_DIRECTORY)
			print("SAVED region ", location)

	get_tree().quit()


## How a sheet lies: the height of its highest flat leaf over the ground (positive floats), the share of its flat leaves buried deeper than `BURIED`.
func _measure(world: Transform3D) -> Dictionary:
	var highest: float = -INF
	var buried: int = 0
	for vertex: Vector3 in _base:
		var point: Vector3 = world * vertex
		var ground: float = _terrain.data.get_height(Vector3(point.x, 0.0, point.z))
		if is_nan(ground):
			return {"no_ground": true, "highest": 0.0, "buried": 0.0}

		var gap: float = point.y - ground
		highest = maxf(highest, gap)
		if gap < -BURIED:
			buried += 1

	return {"no_ground": false, "highest": highest, "buried": float(buried) / float(_base.size())}


## A sheet put right: tipped to the ground's plane and set down on it, smaller if it must. Returns {transform, highest, shrunk}, or nothing if it does not fit.
func _put_right(world: Transform3D) -> Dictionary:
	var scale: Vector3 = world.basis.get_scale()
	var yaw: float = world.basis.orthonormalized().get_euler(EULER_ORDER_YXZ).y
	for step: int in SHRINK_STEPS.size():
		var factor: float = SHRINK_STEPS[step]
		if scale.x * factor < SMALLEST:
			break

		var trial_scale: Vector3 = scale * factor
		var flat: Basis = Basis(Vector3.UP, yaw).scaled_local(trial_scale)
		var plane: Vector3 = _ground_plane(Transform3D(flat, world.origin))
		var normal: Vector3 = Vector3(-plane.x, 1.0, -plane.y).normalized()
		var basis: Basis = Basis(Quaternion(Vector3.UP, normal)) * flat
		var at: Transform3D = Transform3D(basis, Vector3(world.origin.x, plane.x * world.origin.x + plane.y * world.origin.z + plane.z, world.origin.z))
		var report: Dictionary = _measure(at)
		if bool(report["no_ground"]):
			return {}

		# Down (or a little up) so that the highest leaf is only a hair over the ground.
		var shift: float = clampf(FLOAT_TARGET - float(report["highest"]), -1.0, MAX_RAISE)
		at.origin.y += shift
		report = _measure(at)
		if float(report["buried"]) <= BURIED_SHARE and float(report["highest"]) <= FLOAT_LIMIT:
			return {"transform": at, "highest": report["highest"], "shrunk": step > 0}

	return {}


## The plane (a, b, c with height = a * x + b * z + c) that fits the ground under the flat leaves of a sheet laid level at `world`, by least squares.
func _ground_plane(world: Transform3D) -> Vector3:
	var count: float = float(_base.size())
	var mean_x: float = 0.0
	var mean_z: float = 0.0
	var mean_h: float = 0.0
	var points: Array[Vector3] = []
	for vertex: Vector3 in _base:
		var point: Vector3 = world * vertex
		var ground: float = _terrain.data.get_height(Vector3(point.x, 0.0, point.z))
		points.append(Vector3(point.x, ground, point.z))
		mean_x += point.x / count
		mean_z += point.z / count
		mean_h += ground / count

	var sxx: float = 0.0
	var szz: float = 0.0
	var sxz: float = 0.0
	var sxh: float = 0.0
	var szh: float = 0.0
	for point: Vector3 in points:
		var dx: float = point.x - mean_x
		var dz: float = point.z - mean_z
		var dh: float = point.y - mean_h
		sxx += dx * dx
		szz += dz * dz
		sxz += dx * dz
		sxh += dx * dh
		szh += dz * dh

	var determinant: float = sxx * szz - sxz * sxz
	var a: float = 0.0
	var b: float = 0.0
	if absf(determinant) > 0.000001:
		a = (sxh * szz - szh * sxz) / determinant
		b = (szh * sxx - sxh * sxz) / determinant

	return Vector3(a, b, mean_h - a * mean_x - b * mean_z)
