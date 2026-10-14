extends Node

## The town in the dream intro's valley (seen from the city overlook): it replaced the old
## `CityBlockout`, it is only to be seen (no collision), its forest was baked with real data
## (a headless bake saves empty MultiMeshes), the Terrain3D under it holds the valley and the
## mountains, the town can be seen over the overlook's lip, and the atmosphere reveals it
## when the player reaches the overlook. Run it as a scene (it needs a renderer).

const SCENE_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const EYE: Vector3 = Vector3(166.0, -17.4, 24.5)

var test_failed: bool = false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


func _ready() -> void:
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(scene.get_node_or_null("CityBlockout") == null, "the old CityBlockout is gone")
	var vista: TownBlockout = scene.get_node_or_null("TownVista") as TownBlockout
	_expect(vista != null, "the town vista is in the dream intro")
	if vista == null:
		get_tree().quit(1)
		return

	_expect(vista.vista_mode, "built in vista mode")
	_expect(vista.find_children("*", "CollisionShape3D", true, false).is_empty(), "no collision (only to be seen)")
	_expect(vista.find_children("*", "CSGShape3D", true, false).is_empty(), "no CSG (plain meshes, nothing to rebuild when it loads)")

	# The forest is Terrain3D mesh instances (the instancer, so the editor's tools see them) of the
	# project's real tree models, not meshes inside the town scene.
	var terrain: Terrain3D = scene.get_node("Terrain3D") as Terrain3D
	var data: Terrain3DData = terrain.data
	var mesh_list: Array = terrain.assets.mesh_list
	var asset_ids: Array[int] = []
	for asset: Terrain3DMeshAsset in mesh_list:
		asset_ids.append(asset.id)

	for id: int in TownVistaBuilder.MESH_IDS + TownVistaBuilder.STAND_IDS:
		_expect(asset_ids.has(id), "the Terrain3D mesh asset %d (vista tree or stand) exists" % id)

	_expect(vista.find_children("*", "MultiMeshInstance3D", true, false).filter(func(n: Node) -> bool: return (n as MultiMeshInstance3D).multimesh.instance_count > 3000).is_empty(), "no big tree MultiMesh inside the town scene")
	var region_size: int = int(float(terrain.region_size) * terrain.vertex_spacing)
	var singles: int = 0
	var stands: int = 0
	var singles_off: int = 0
	var stands_off: int = 0
	for region: Terrain3DRegion in data.get_regions_active():
		var offset: Vector3 = Vector3(float(region.get_location().x * region_size), 0.0, float(region.get_location().y * region_size))
		var instances: Dictionary = region.get_instances()
		for id: int in TownVistaBuilder.MESH_IDS + TownVistaBuilder.STAND_IDS:
			if not instances.has(id):
				continue

			var is_stand: bool = TownVistaBuilder.STAND_IDS.has(id)
			for cell: Variant in (instances[id] as Dictionary).keys():
				for spot: Transform3D in (instances[id][cell] as Array)[0]:
					var foot: Vector3 = spot.origin + offset
					var ground: float = data.get_height(foot)
					if is_nan(ground):
						continue

					if is_stand:
						stands += 1
						stands_off += 1 if absf(foot.y - ground) > 12.5 else 0
					else:
						singles += 1
						singles_off += 1 if absf(foot.y - ground) > 0.4 else 0

	_expect(singles > 1200, "single real trees planted near the overlook and the town (%d)" % singles)
	_expect(stands > 80, "far forest canopy stands planted on the mountains (%d)" % stands)
	_expect(singles_off == 0, "every single tree stands on the terrain (%d off)" % singles_off)
	_expect(stands_off == 0, "every stand is seated on its slope (%d off)" % stands_off)

	# The cliff right beyond the fence: the ground falls away at least 30 m within 15 m of it.
	var direction: Vector2 = Vector2(0.686, -0.727).normalized()
	var fence: Vector2 = Vector2(168.0, 27.0) + direction * 8.2
	var beyond: Vector2 = fence + direction * 15.0
	var fence_height: float = data.get_height(Vector3(fence.x, 0.0, fence.y))
	var cliff_height: float = data.get_height(Vector3(beyond.x, 0.0, beyond.y))
	_expect(fence_height - cliff_height > 30.0, "a cliff beyond the fence (the ground drops %.0f m within 15 m)" % (fence_height - cliff_height))
	_expect(absf(fence_height - (-18.74)) < 1.5, "the plateau up to the fence is as authored (%.2f)" % fence_height)

	# The town is where it was asked to be.
	_expect(vista.global_position.distance_to(Vector3(379.31, -56.0, -348.0)) < 0.1, "the town stands at (379.31, -56, -348)")

	# The ground: the valley and the mountains in Terrain3D.
	var origin: Vector3 = vista.global_position
	var centre_height: float = data.get_height(Vector3(origin.x, 0.0, origin.z))
	_expect(not is_nan(centre_height) and absf(centre_height - origin.y) < 25.0, "the valley ground is under the town (%.1f)" % centre_height)
	var north: Vector3 = vista.global_transform * Vector3(0.0, 0.0, -420.0)
	var mountain: float = data.get_height(Vector3(north.x, 0.0, north.z))
	_expect(not is_nan(mountain) and mountain > origin.y + 80.0, "the mountains rise behind it (%.0f m above the town)" % (mountain - origin.y))

	# The hill and the overlook stay as they were.
	_expect(absf(data.get_height(Vector3(168.0, 0.0, 27.0)) - (-18.74)) < 0.05, "the overlook's ground is untouched")

	# The town can be seen over the lip of the plateau, from where the player stands.
	var hidden: Array[String] = []
	for place: String in ["IgrejaMatriz", "Coreto", "Estacao", "CaixaDaguaMunicipal", "Escola", "Armazem"]:
		var marker: Node3D = vista.get_node_or_null("MapRoot/OuterTown/Landmarks/%s" % place) as Node3D
		_expect(marker != null, "the town has its %s" % place)
		if marker == null:
			continue

		var target: Vector3 = marker.global_position + Vector3(0.0, 6.0, 0.0)
		var steps: int = int(Vector2(target.x - EYE.x, target.z - EYE.z).length() / 2.0)
		for i: int in range(1, steps):
			var point: Vector3 = EYE.lerp(target, float(i) / float(steps))
			if data.get_height(Vector3(point.x, 0.0, point.z)) > point.y:
				hidden.append(place)
				break

	_expect(hidden.is_empty(), "the town can be seen from the overlook (hidden: %s)" % [hidden])

	# The atmosphere: the forest stays locked away from the overlook, the vista appears there.
	var world: WorldEnvironment = scene.get_node("WorldEnvironment") as WorldEnvironment
	var player: Node3D = scene.get_node("Player") as Node3D
	player.global_position = Vector3(10.0, 0.0, 5.0)
	await get_tree().create_timer(0.5).timeout
	var forest_far: float = world.environment.fog_depth_end
	player.global_position = Vector3(166.0, -17.8, 24.5)
	await get_tree().create_timer(0.5).timeout
	var vista_far: float = world.environment.fog_depth_end
	_expect(forest_far < 100.0, "in the forest the fog is close (ends at %.0f m)" % forest_far)
	_expect(vista_far > 1000.0, "on the overlook the fog clears (ends at %.0f m)" % vista_far)
	_expect(world.environment.glow_enabled, "the city lights bloom on the overlook")
	_expect(world.environment.ambient_light_energy < 0.12, "but it stays night: dim ambient light (%.3f)" % world.environment.ambient_light_energy)
	_expect((scene.get_node("MoonLight") as DirectionalLight3D).light_energy < 0.3, "and a dim moon (%.2f)" % (scene.get_node("MoonLight") as DirectionalLight3D).light_energy)
	_expect(world.environment.fog_density > 0.5, "with mist over the valley (density %.2f)" % world.environment.fog_density)

	print("TOWN_VISTA_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)
