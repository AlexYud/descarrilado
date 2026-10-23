extends Node

## The wind in the dream intro's vegetation: every plant and tree asset of the terrain gets wind materials (leaf cards and
## bark), the assets that are not plants (rocks, tent, campfire, bench, the far vista trees) are left alone, the grass tufts
## (tinted through the instancer's override) have it on their instances, the shaders compile, and the wind's strength
## and direction reach every material. Run it as a scene; it quits by itself with a non-zero exit code on failure.

const DREAM_INTRO: String = "res://scenes/cinematics/dream_intro.tscn"
const TEST_SAVE_DIRECTORY: String = "res://.godot/codex_wind_smoke"

var test_failed: bool = false


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	SaveManager.delete_slot(1)
	SaveManager.create_new_game(1, DREAM_INTRO, "wind_start", "SAVE_LOCATION_DREAM_INTRO")

	var level: Node = (load(DREAM_INTRO) as PackedScene).instantiate()
	add_child(level)
	for i: int in 6:
		await get_tree().physics_frame
	await get_tree().create_timer(1.0).timeout

	_run(level)

	SaveManager.delete_slot(1)
	print("VEGETATION_WIND_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run(level: Node) -> void:
	var wind: VegetationWind = level.get_node_or_null("VegetationWind") as VegetationWind
	_expect(wind != null, "the dream intro has its VegetationWind")
	if wind == null:
		return

	var terrain: Terrain3D = level.get_node("Terrain3D") as Terrain3D
	_expect(wind.terrain == terrain, "it blows on the dream intro's terrain")
	_expect(wind.assets_changed.size() == VegetationWind.PROFILES.size(), "every plant and tree asset got wind (%d of %d)" % [wind.assets_changed.size(), VegetationWind.PROFILES.size()])

	var leaves: int = 0
	var bark: int = 0
	for material: ShaderMaterial in wind.materials:
		if material.shader == VegetationWind.LEAVES_SHADER:
			leaves += 1
		elif material.shader == VegetationWind.BARK_SHADER:
			bark += 1
	_expect(leaves >= 15 and bark == 4, "leaf cards (%d) and the four trees' bark (%d) each have their shader" % [leaves, bark])

	var kept: Array[String] = []
	for index: int in terrain.assets.get_mesh_count():
		var asset: Terrain3DMeshAsset = terrain.assets.get_mesh_asset(index)
		var mesh: Mesh = asset.get_mesh(0)
		var has_wind: bool = false
		for surface: int in mesh.get_surface_count():
			has_wind = has_wind or mesh.surface_get_material(surface) is ShaderMaterial
		if VegetationWind.PROFILES.has(asset.name):
			if asset.material_override == null:
				_expect(has_wind, asset.name + " sways")
		else:
			if has_wind:
				kept.append(asset.name)
	_expect(kept.is_empty(), "rocks, the tent, the campfire, the bench and the vista trees keep their own materials (%s)" % str(kept))

	# The tinted grass tufts are tinted by the instancer's override; their instances carry the wind material.
	var tufts: int = 0
	var plain: int = 0
	for node: Node in terrain.find_children("*_M11_L0", "MultiMeshInstance3D", true, false) + terrain.find_children("*_M12_L0", "MultiMeshInstance3D", true, false):
		if (node as MultiMeshInstance3D).material_override is ShaderMaterial:
			tufts += 1
		else:
			plain += 1
	_expect(tufts > 0 and plain == 0, "all %d groups of grass tufts blow (%d without)" % [tufts + plain, plain])

	# The settings reach every material, and the sway is in metres of the plant's own size.
	wind.strength = 1.5
	wind.direction_degrees = 90.0
	wind.speed = 2.0
	var reached: bool = true
	for material: ShaderMaterial in wind.materials:
		reached = reached and is_equal_approx(float(material.get_shader_parameter("wind_strength")), 1.5)
		reached = reached and is_equal_approx(float(material.get_shader_parameter("wind_speed")), 2.0)
		reached = reached and (material.get_shader_parameter("wind_direction") as Vector2).is_equal_approx(Vector2(0.0, 1.0))
	_expect(reached, "strength, direction and speed reach every material")
	var sways: Array[float] = []
	for material: ShaderMaterial in wind.materials:
		sways.append(float(material.get_shader_parameter("sway_amount")))
	_expect(sways.min() > 0.01 and sways.max() < 0.8, "no plant sways less than a centimetre or more than 80 cm (%.2f to %.2f m)" % [sways.min(), sways.max()])
	wind.strength = 0.0
	_expect(is_zero_approx(float(wind.materials[0].get_shader_parameter("wind_strength"))), "and with strength 0 the air is still")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
