extends Node

## The unfinished house as a model, and its windows: the shell's picture is the model's (the boxes of the same parts are hidden, their collision is not), the
## model's stray pieces (door leaves, frames and a slatted piece standing inside) are left out, and the three windows have their pair of plank shutters, which
## open and close with a motion of their own, are found from inside and outside, say "Open" or "Close", start open, and remember what they were left as.
## Run it as a scene; it quits by itself with a non-zero exit code on failure.

const HOUSE: String = "res://scenes/levels/unfinished_house.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_house_window_smoke"

var test_failed: bool = false
var house: Node3D = null
var builder: UnfinishedHouseBuilder = null


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, HOUSE, "house_window_test", "SAVE_LOCATION_DREAM_INTRO")
	house = (load(HOUSE) as PackedScene).instantiate()
	add_child(house)
	for i: int in 6:
		await get_tree().physics_frame

	builder = house.get_node("Shell") as UnfinishedHouseBuilder
	_check_shell()
	await _check_windows()

	GameSettings.set_text_locale("en", false)
	SaveManager.delete_slot(1)
	print("HOUSE_WINDOW_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _check_shell() -> void:
	_expect(builder != null and builder.model_shell != null and builder.model_shell.mesh_instance != null, "the house shows the model's shell")
	var mesh: ArrayMesh = builder.model_shell.mesh_instance.mesh as ArrayMesh
	_expect(mesh != null and mesh.get_surface_count() == 5, "with its five surfaces (floor, plaster, roof, wood, glass): %d" % (mesh.get_surface_count() if mesh != null else 0))

	# What the model carries that is not a shell is gone: no wood of it stands inside the rooms.
	var inside: AABB = AABB(Vector3(0.5, 0.3, 0.5), Vector3(8.0, 1.8, 14.0))
	var loose: int = 0
	var box: AABB = builder.model_shell.mesh_instance.global_transform * mesh.get_aabb()
	var wood_vertices: PackedVector3Array = mesh.surface_get_arrays(3)[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in wood_vertices:
		var point: Vector3 = builder.model_shell.mesh_instance.global_transform * vertex
		if inside.has_point(point):
			loose += 1
	_expect(loose == 0, "no loose door frame or fitting of the model stands in the rooms (%d wood vertices there)" % loose)
	_expect(box.size.x > 11.0 and box.size.z > 15.0, "and it covers the house (%.1f by %.1f m with the roof)" % [box.size.x, box.size.z])

	var hidden_boxes: bool = true
	var shown_walls: int = 0
	var dressed: bool = true
	var ceilings: int = 0
	for child: Node in builder.get_children():
		var child_name: String = String(child.name)
		if child is MeshInstance3D and (child_name.begins_with("Floor") or child_name.begins_with("Roof") or child_name.begins_with("Wall0_") or child_name.begins_with("Wall4_")):
			hidden_boxes = hidden_boxes and not (child as MeshInstance3D).visible
		if child is MeshInstance3D and child_name.begins_with("Wall7_") and (child as MeshInstance3D).visible:
			shown_walls += 1
			dressed = dressed and (child as MeshInstance3D).material_override is StandardMaterial3D and ((child as MeshInstance3D).material_override as StandardMaterial3D).albedo_texture != null and ((child as MeshInstance3D).material_override as StandardMaterial3D).uv1_world_triplanar
		if child is MeshInstance3D and child_name.begins_with("Ceiling") and (child as MeshInstance3D).visible:
			ceilings += 1
			dressed = dressed and (child as MeshInstance3D).material_override != null
	_expect(hidden_boxes, "the boxes of the floor, roof and outer walls are hidden")
	_expect(shown_walls > 0, "the escape wall (which the model has not) is still a box")
	_expect(ceilings == 2, "the flat ceiling is kept (the model has none: the lamps hang from it)")
	_expect(dressed, "and those boxes wear the model's plaster")

	# The outer walls are solid where the boxes had their windows, and their doorways are the model's.
	var space: PhysicsDirectSpaceState3D = builder.get_world_3d().direct_space_state
	for old_window: Vector3 in [Vector3(1.55, 1.4, 15.5), Vector3(0.0, 1.4, 7.36)]:
		var across: Vector3 = Vector3(0.0, 0.0, 0.5) if old_window.z > 1.0 and old_window.x > 0.5 else Vector3(0.5, 0.0, 0.0)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(old_window - across, old_window + across))
		_expect(not hit.is_empty(), "the wall is solid where the boxes had a window (%s)" % old_window)
	for door: Dictionary in builder.model_shell.door_openings():
		var at: Vector3 = door["center"] as Vector3
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 1.0, at.z - 0.5), Vector3(at.x, 1.0, at.z + 0.5)))
		var blocked_by_wall: bool = not hit.is_empty() and (hit["collider"] as Node).name == "WallBody"
		_expect(not blocked_by_wall, "the model's doorway at x %.2f is open in the wall's collision" % at.x)
		_expect(absf(float(door["width"]) - 0.935) < 0.01 and is_equal_approx(float(door["height"]), 2.10), "and it is the model's size (%.3f by %.2f m)" % [float(door["width"]), float(door["height"])])
	# The model's partitions are the walls: solid where drawn (the model's own collision), open in their arch, and the boxes of the same walls are gone.
	var model_body: StaticBody3D = builder.model_shell.get_node_or_null("ModelBody") as StaticBody3D
	_expect(model_body != null, "the model's walls have collision")
	for wall_z: float in [6.215, 9.05]:
		var solid: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5.0, 1.2, wall_z - 0.5), Vector3(5.0, 1.2, wall_z + 0.5)))
		_expect(not solid.is_empty() and solid["collider"] == model_body, "the model's partition at z %.2f is solid where it is drawn" % wall_z)
		var arch: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.33, 1.2, wall_z - 0.5), Vector3(2.33, 1.2, wall_z + 0.5)))
		_expect(arch.is_empty(), "and open in its arch (%s)" % (str(arch.get("collider", "")) if not arch.is_empty() else "nothing in the way"))
	var boxes_of_partitions: int = 0
	for child: Node in builder.get_children():
		if String(child.name).begins_with("Wall6_") or String(child.name).begins_with("Wall8_"):
			boxes_of_partitions += 1
	_expect(boxes_of_partitions == 0, "no box stands for those walls any more")
	var bedroom: DoorController = house.get_node("Doors/BedroomDoor") as DoorController
	var bedroom_middle: float = bedroom.global_position.x + bedroom.leaf_width * 0.5
	_expect(absf(bedroom_middle - 6.965) < 0.02 and bedroom.leaf_height > 2.05, "the bedroom door fills the model's doorway (its middle at x %.3f)" % bedroom_middle)
	var shut: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(bedroom_middle, 1.0, 5.6), Vector3(bedroom_middle, 1.0, 6.8)))
	_expect(not shut.is_empty() and (shut["collider"] as Node).name == "DoorBody", "and, locked, it is what closes the doorway")

	var front: DoorController = house.get_node("Doors/FrontDoor") as DoorController
	var front_opening: Vector3 = builder.model_shell.door_openings()[1]["center"] as Vector3
	_expect(absf(front.global_position.x + front.leaf_width * 0.5 - front_opening.x) < 0.01 and front.leaf_height > 2.05, "the front door's leaf fills the model's doorway (its middle %.3f, the doorway's %.3f)" % [front.global_position.x + front.leaf_width * 0.5, front_opening.x])
	var wall_body: StaticBody3D = builder.get_node("WallBody") as StaticBody3D
	var enabled: int = 0
	for shape: Node in wall_body.get_children():
		if shape is CollisionShape3D and not (shape as CollisionShape3D).disabled:
			enabled += 1
	_expect(enabled > 10, "the boxes keep their collision (%d shapes)" % enabled)


func _check_windows() -> void:
	var windows: Array[HouseWindow] = []
	for node: Node in builder.find_children("Window*", "HouseWindow", false, false):
		windows.append(node as HouseWindow)
	_expect(windows.size() == 3, "the model has three windows, each with its shutters (%d)" % windows.size())
	if windows.is_empty():
		return

	var window: HouseWindow = windows[0]
	_expect(window.is_open and window.leaf_openness()[0] > 0.99 and window.leaf_openness()[1] > 0.99, "they start open")
	_expect(window.get_prompt_text() == "PROMPT_CLOSE" and window.can_interact(null), "an open window says Close")

	# Found from outside and from inside, before the wall.
	for from_outside: bool in [true, false]:
		var outward: Vector3 = window.global_transform.basis.z
		var start: Vector3 = window.global_position + outward * (1.5 if from_outside else -1.5)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, window.global_position)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit: Dictionary = window.get_world_3d().direct_space_state.intersect_ray(query)
		var found: bool = false
		var current: Node = hit.get("collider") as Node if not hit.is_empty() else null
		while current != null:
			if current == window:
				found = true
				break
			current = current.get_parent()
		_expect(found, "the window is what a ray finds %s, before the wall" % ("from outside" if from_outside else "from inside"))

	var started: float = Time.get_ticks_msec() / 1000.0
	window.interact(null)
	await get_tree().process_frame
	_expect(not window.can_interact(null), "while it moves nothing else can be done to it")
	await _until(func() -> bool: return not window.is_open and window.can_interact(null), 5.0)
	var taken: float = Time.get_ticks_msec() / 1000.0 - started
	_expect(window.leaf_openness()[0] < 0.02 and window.leaf_openness()[1] < 0.02, "it closes, both leaves shut (%.2f s)" % taken)
	_expect(taken > 0.7 and taken < 3.5, "in a motion that takes its time")
	_expect(window.get_prompt_text() == "PROMPT_OPEN", "a shut window says Open")
	var saved: Variant = SaveManager.get_state_value(&"windows", &"house_window_0", {})
	_expect(saved is Dictionary and (saved as Dictionary).get("is_open", true) == false, "and it is remembered shut")

	window.interact(null)
	await _until(func() -> bool: return window.is_open and window.can_interact(null), 5.0)
	_expect(window.leaf_openness()[0] > 0.97 and window.leaf_openness()[1] > 0.97, "it opens again, both leaves out")
	_expect(window.open_angle_degrees >= 80.0 and window.open_angle_degrees <= 110.0, "the leaves swing %.0f degrees" % window.open_angle_degrees)

	# An open shutter is solid: a ray across it, outside the house, is stopped by it.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var leaf_body: StaticBody3D = window.get_node("HingeWest/Leaf/LeafBody") as StaticBody3D
	var leaf_middle: Vector3 = leaf_body.global_position
	var along_wall: Vector3 = window.global_transform.basis.x
	var across_leaf: Dictionary = window.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(leaf_middle - along_wall * 0.6, leaf_middle + along_wall * 0.6))
	_expect(not across_leaf.is_empty() and across_leaf["collider"] == leaf_body, "an open shutter, outside, cannot be walked through")
	var shapes: Array[Node] = window.find_children("*", "CollisionShape3D", true, false)
	_expect(not shapes.is_empty() and shapes[0].get_parent().name == "WindowBody", "the window's own body is its first shape (where its interaction mark sits)")
	# Its interaction mark is seen, from inside and from outside: nothing solid stands between the eyes and it (the reticle's own test).
	var eye_camera: Camera3D = Camera3D.new()
	add_child(eye_camera)
	eye_camera.make_current()
	for from_outside: bool in [false, true]:
		eye_camera.global_position = window.global_position + window.global_transform.basis.z * (1.3 if from_outside else -1.3) + Vector3(0.0, 0.1, 0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var mark: Vector3 = (shapes[0] as Node3D).global_transform * window.mark_offset
		var sight: Dictionary = window.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye_camera.global_position, mark))
		_expect(sight.is_empty() or (sight["position"] as Vector3).distance_to(mark) < 0.12, "its mark is on the face seen %s" % ("from outside" if from_outside else "from inside"))
	eye_camera.queue_free()
	# No sound of its own.
	_expect(window.find_children("*", "AudioStreamPlayer3D", true, false).is_empty(), "the window makes no sound")
	# Shut, the two leaves leave a gap between them (they do not cut into each other).
	window.set_open_now(false)
	var west_leaf: Node3D = window.get_node("HingeWest/Leaf") as Node3D
	var east_leaf: Node3D = window.get_node("HingeEast/Leaf") as Node3D
	var leaf_half: float = ((west_leaf.get_node("LeafBody/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size.z * 0.5
	var gap: float = window.to_local(east_leaf.global_position).x - window.to_local(west_leaf.global_position).x - leaf_half * 2.0
	_expect(gap > 0.002, "shut, the leaves meet with a small gap (%.1f mm)" % (gap * 1000.0))
	window.set_open_now(true)

	# Both leaves swing outward: an open leaf's far end lies on the outside of the wall.
	var hinge: Node3D = window.get_node("HingeWest") as Node3D
	var leaf: Node3D = hinge.get_child(0) as Node3D
	var tip: Vector3 = window.to_local(leaf.global_position)
	_expect(tip.z > window.plane_offset + 0.15, "open, a leaf lies out from the wall, not into the room (%.2f m out)" % (tip.z - window.plane_offset))

	# What was left is what comes back.
	window.set_open_now(false)
	var again: Node = (load(HOUSE) as PackedScene).instantiate()
	add_child(again)
	await get_tree().process_frame
	var reloaded: HouseWindow = again.get_node("Shell/Window0") as HouseWindow
	_expect(reloaded != null and not reloaded.is_open, "a window left shut is shut when the house is loaded again")
	again.queue_free()


func _until(condition: Callable, timeout: float) -> void:
	var waited: float = 0.0
	while not condition.call() and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
