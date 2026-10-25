extends Node

## Opens the ground south west of the signal tower's pad. The invisible walls there were spliced by hand when the tower was placed
## (`SignalTowerTerrainBuilder`: a ring round the pad, tied to the loop's old wall): the ring ended in a short diagonal wall across
## open ground, and the old wall went on down the east side of the trail about a metre from it, so a pocket of bare ground (no
## plants at all) beside the tower and a strip of it along the trail were walled off for nothing: the player met a wall where
## there was nothing to stop them.
##
## This replaces that stretch (and the ring, which it is part of) with a wall that follows the plants: from the ring's south arc it
## runs down the west face of the plants, 0.3 m in front of them, and joins the old wall where the plants come up to it again.
## The rest of the walls stay as they are.
##
## Run it as a scene (no window is needed, one Godot at a time):
##   Godot --headless --path . res://scripts/tools/open_signal_tower_walls.tscn
## It writes scenes/environment/forest_boundaries.tscn. It can be run again: it takes out its own wall and puts it in anew.

const LEVEL_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const BOUNDARIES_PATH: String = "res://scenes/environment/forest_boundaries.tscn"
const SAVE_DIRECTORY: String = "res://.godot/open_walls"
const Builder := preload("res://scripts/tools/forest_boundary_builder.gd")

## Every triangle lying wholly in here is the ring that was put round the tower (its footprint is x 95 to 110.5, z -44.5 to -26.8).
const RING_RECT: Rect2 = Rect2(94.9, -44.8, 15.9, 18.1)
## Every triangle touching this goes: the ring's last stretch is in it, and the old wall down the trail's east side.
const STRIP_RECT: Rect2 = Rect2(96.0, -31.9, 7.4, 14.3)

## The ring from the old wall's north end round the east of the tower to the plants south of the pad.
const RING_POINTS: Array[Vector2] = [
	Vector2(95.0, -41.0), Vector2(97.5, -43.5), Vector2(102.0, -44.5), Vector2(106.5, -43.5), Vector2(109.5, -40.0),
	Vector2(110.5, -35.5), Vector2(109.5, -31.0), Vector2(106.5, -28.0), Vector2(102.0, -26.8), Vector2(98.0, -28.0),
]
## Where the wall down the plants' face starts and stops (z), the step between its points, and how far in front of the plants it stands.
const STRIP_FROM_Z: float = -27.5
const STRIP_TO_Z: float = -18.0
const STRIP_STEP: float = 0.5
const STRIP_FRONT: float = 0.3
## The wall is never nearer the trail than this (x); where there are no plants it stands at `STRIP_FAR_X`.
const STRIP_NEAREST_X: float = 97.0
const STRIP_FAR_X: float = 103.5

const WALL_BELOW: float = 2.0
const WALL_ABOVE: float = 4.0


func _ready() -> void:
	SaveManager.save_directory = SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, LEVEL_PATH, "x", "SAVE_LOCATION_DREAM_INTRO")
	var level: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	add_child(level)
	await get_tree().create_timer(2.5).timeout

	var terrain: Terrain3D = level.get_node("Terrain3D") as Terrain3D
	var old_faces: PackedVector3Array = _faces_of(load(BOUNDARIES_PATH) as PackedScene)
	var kept: PackedVector3Array = PackedVector3Array()
	var removed: int = 0
	for i: int in range(0, old_faces.size() - 2, 3):
		if _inside(old_faces, i, RING_RECT) or _touches(old_faces, i, STRIP_RECT):
			removed += 1
			continue

		kept.append(old_faces[i])
		kept.append(old_faces[i + 1])
		kept.append(old_faces[i + 2])

	var builder: ForestBoundaryBuilder = Builder.new()
	builder.zone = Rect2(88.0, -48.0, 30.0, 34.0)
	builder.prepare_plants(terrain)

	var points: Array[Vector2] = RING_POINTS.duplicate()
	var strip: Array[Vector2] = _strip(builder)
	points.append_array(strip)
	# It joins the old wall where that comes up to the plants again: at the nearest corner of what is left of it.
	var join: Vector2 = _nearest_corner(kept, strip[strip.size() - 1])
	points.append(join)

	var added: PackedVector3Array = _wall_faces(terrain, points)
	kept.append_array(added)
	var scene: PackedScene = _pack(kept)
	var error: Error = ResourceSaver.save(scene, BOUNDARIES_PATH)
	print("[open_signal_tower_walls] took out %d triangles, put in %d (the new wall has %d points, joins the old wall at %s): saved %s" % [removed, added.size() / 3, points.size(), str(join), error_string(error)])
	SaveManager.delete_slot(1)
	get_tree().quit(0 if error == OK else 1)


## The wall's line down the plants' west face: for each z, the first plant met going east from the trail, less a little.
func _strip(builder: ForestBoundaryBuilder) -> Array[Vector2]:
	var raw: Array[float] = []
	var z: float = STRIP_FROM_Z
	while z <= STRIP_TO_Z + 0.001:
		var wall_x: float = STRIP_FAR_X
		var x: float = STRIP_NEAREST_X
		while x <= STRIP_FAR_X:
			if builder.is_wall_plant_at(Vector2(x, z)):
				wall_x = maxf(x - STRIP_FRONT, STRIP_NEAREST_X)
				break

			x += 0.25

		raw.append(wall_x)
		z += STRIP_STEP

	# Smoothed over three, so that one loose bush does not make the wall zig-zag.
	var line: Array[Vector2] = []
	for i: int in raw.size():
		var total: float = 0.0
		var count: int = 0
		for k: int in range(maxi(i - 1, 0), mini(i + 1, raw.size() - 1) + 1):
			total += raw[k]
			count += 1

		line.append(Vector2(total / float(count), STRIP_FROM_Z + float(i) * STRIP_STEP))

	return line


func _nearest_corner(faces: PackedVector3Array, target: Vector2) -> Vector2:
	var best: Vector2 = target
	var best_distance: float = INF
	for vertex: Vector3 in faces:
		var corner: Vector2 = Vector2(vertex.x, vertex.z)
		var distance: float = corner.distance_to(target)
		if distance < best_distance and corner.y >= target.y - 0.2:
			best_distance = distance
			best = corner

	return best


## A quad for every half metre of the line, from under the ground to well over it (the shape collides from both sides).
func _wall_faces(terrain: Terrain3D, points: Array[Vector2]) -> PackedVector3Array:
	var faces: PackedVector3Array = PackedVector3Array()
	for i: int in points.size() - 1:
		var from_point: Vector2 = points[i]
		var to_point: Vector2 = points[i + 1]
		var steps: int = maxi(int(ceilf(from_point.distance_to(to_point) / 0.5)), 1)
		for k: int in steps:
			var a: Vector2 = from_point.lerp(to_point, float(k) / float(steps))
			var c: Vector2 = from_point.lerp(to_point, float(k + 1) / float(steps))
			var ground_a: float = terrain.data.get_height(Vector3(a.x, 0.0, a.y))
			var ground_c: float = terrain.data.get_height(Vector3(c.x, 0.0, c.y))
			var a_low: Vector3 = Vector3(a.x, ground_a - WALL_BELOW, a.y)
			var a_high: Vector3 = Vector3(a.x, ground_a + WALL_ABOVE, a.y)
			var c_low: Vector3 = Vector3(c.x, ground_c - WALL_BELOW, c.y)
			var c_high: Vector3 = Vector3(c.x, ground_c + WALL_ABOVE, c.y)
			faces.append_array(PackedVector3Array([a_low, c_low, c_high, a_low, c_high, a_high]))

	return faces


func _faces_of(scene: PackedScene) -> PackedVector3Array:
	var body: Node = scene.instantiate()
	var faces: PackedVector3Array = PackedVector3Array()
	for child: Node in body.get_children():
		var shape: CollisionShape3D = child as CollisionShape3D
		if shape != null and shape.shape is ConcavePolygonShape3D:
			faces = (shape.shape as ConcavePolygonShape3D).get_faces()

	body.free()
	return faces


func _pack(faces: PackedVector3Array) -> PackedScene:
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ForestBoundary"
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body
	var packed: PackedScene = PackedScene.new()
	packed.pack(body)
	body.free()
	return packed


func _footprint(faces: PackedVector3Array, i: int) -> Rect2:
	var box: Rect2 = Rect2(Vector2(faces[i].x, faces[i].z), Vector2.ZERO)
	box = box.expand(Vector2(faces[i + 1].x, faces[i + 1].z))
	box = box.expand(Vector2(faces[i + 2].x, faces[i + 2].z))
	return box.grow(0.01)


func _touches(faces: PackedVector3Array, i: int, rect: Rect2) -> bool:
	return _footprint(faces, i).intersects(rect)


func _inside(faces: PackedVector3Array, i: int, rect: Rect2) -> bool:
	return rect.encloses(_footprint(faces, i))
