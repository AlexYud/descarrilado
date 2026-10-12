extends Node

## One-off migration, run as a scene (it needs a real window for the plant
## instancer): moves the unfinished house to the south path closer to the train,
## turned to follow the path, puts the waiting shed on the middle path, and
## rebuilds the forest walls.
##
## Start from the terrain as it was before the move (git HEAD of terrain_data/,
## forest_boundaries.tscn and house_forest_colliders.tscn).
##
## 1. Restores the old house site from the terrain as it was before the house
##    (files taken from git into res://.godot/old_terrain).
## 2. Builds the waiting shed's clearing (JunctionTerrainBuilder).
## 3. Builds the house's new site (HouseTerrainBuilder, turned along the path).
## 4. Saves the terrain data, the walls and the baked forest colliders.
##
## It prints the transforms to put the two scene instances at. Run it once from a
## clean start; see PROJECT_CONTEXT.md.

const Restore := preload("res://scripts/tools/terrain_area_restore.gd")
const ShedBuilder := preload("res://scripts/tools/junction_terrain_builder.gd")
const HouseBuilder := preload("res://scripts/tools/house_terrain_builder.gd")

const DREAM_INTRO_PATH: String = "res://scenes/cinematics/dream_intro.tscn"
const TERRAIN_DIRECTORY: String = "res://terrain_data/dream_intro"
const OLD_TERRAIN_DIRECTORY: String = "res://.godot/old_terrain"
const BOUNDARIES_SCENE_PATH: String = "res://scenes/environment/forest_boundaries.tscn"
const COLLIDERS_SCENE_PATH: String = "res://scenes/environment/house_forest_colliders.tscn"

## The old house zone: everything inside is put back as it was.
const OLD_HOUSE_ZONE: Rect2 = Rect2(100.0, 60.0, 82.0, 54.0)

## The point of the south path (about the middle of its straight stretch) the house
## is centred on, and the direction the path runs there (towards the south-east).
const HOUSE_PATH_POINT: Vector2 = Vector2(60.5, 52.0)
const HOUSE_PATH_DIRECTION: Vector2 = Vector2(1.0, 1.0)
const HOUSE_ZONE: Rect2 = Rect2(30.0, 24.0, 76.0, 66.0)
## The floor slab sits a hair above the level ground so it never z-fights.
const FLOOR_LIFT: float = 0.015


func _ready() -> void:
	var scene: Node = (load(DREAM_INTRO_PATH) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	var terrain: Terrain3D = scene.get_node("Terrain3D") as Terrain3D

	var restore = Restore.new()
	var restored: Dictionary = await restore.restore(terrain, OLD_TERRAIN_DIRECTORY, OLD_HOUSE_ZONE)
	print("RESTORE ", restored)

	var shed = ShedBuilder.new()
	var shed_result: Dictionary = shed.build(terrain)
	print(
		"SHED plane height %.3f slope (%.4f, %.4f) painted %d plants removed %d added %d floor %d rim %d cover %d"
		% [
			float(shed_result["height"]), (shed_result["slope"] as Vector2).x,
			(shed_result["slope"] as Vector2).y, int(shed_result["painted"]),
			int(shed_result["removed"]), int(shed_result["added"]),
			int(shed_result["floor_plants"]), int(shed_result["rim_plants"]),
			int(shed_result["cover_plants"]),
		]
	)
	print("SHED grading ", shed_result["grading"], " steepest slopes (deg, 3 m) ", shed_result["slopes"])

	var house = HouseBuilder.new()
	house.place_on_path(HOUSE_PATH_POINT, HOUSE_PATH_DIRECTION)
	house.vegetation_zone = HOUSE_ZONE
	house.seed_value = 20261012
	var house_result: Dictionary = house.build(terrain)
	print(
		"HOUSE origin %s yaw %.2f height %.3f painted %d plants removed %d added %d unsafe %d overgrowth %d colliders %d"
		% [
			str(house.origin), house.yaw_degrees,
			float(house_result["height"]), int(house_result["painted"]),
			int(house_result["removed"]), int(house_result["added"]),
			int(house_result["cleared_unsafe"]), int(house_result["overgrowth"]),
			int(house_result["colliders"]),
		]
	)

	# The transforms for the scene.
	var yaw: float = deg_to_rad(house.yaw_degrees)
	var basis: Basis = Basis(Vector3.UP, yaw)
	var house_transform: Transform3D = Transform3D(
		basis, Vector3(house.origin.x, float(house_result["height"]) + FLOOR_LIFT, house.origin.y)
	)
	print("HOUSE transform ", house_transform)
	print("SHED instance at ", Vector3(shed.center.x, shed.plane_height, shed.center.y), " slope ", shed.plane_slope)

	var walls: Dictionary = house_result["boundaries"]
	var saved_walls: Error = ResourceSaver.save(walls["scene"], BOUNDARIES_SCENE_PATH)
	var saved_colliders: Error = ResourceSaver.save(house_result["colliders_scene"], COLLIDERS_SCENE_PATH)
	terrain.data.save_directory(TERRAIN_DIRECTORY)
	print("SAVED walls ", error_string(saved_walls), " colliders ", error_string(saved_colliders))
	get_tree().quit()
