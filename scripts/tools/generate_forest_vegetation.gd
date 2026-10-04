@tool
extends EditorScript

## Run from the Script Editor with File > Run (Ctrl+Shift+X) while the dream
## intro scene is open. It fills the zone below with path-hugging forest, then
## you save the scene (Ctrl+S) to store the instances in the terrain regions.
##
## Edit the zone and options below, then run again. Reruns replace the plants
## inside the zone instead of stacking new ones on top of them.

const TERRAIN_NODE_NAME: String = "Terrain3D"

## World-space area to fill: x, z, width, depth (metres). This one covers the
## fence door, all three paths and the overlook.
const ZONE: Rect2 = Rect2(12.0, -95.0, 205.0, 190.0)

## Keeps the fence line and train side clear.
const EXCLUSIONS: Array[Rect2] = [
	Rect2(-70.0, -80.0, 82.0, 200.0),
]

## Overlook view: only low plants grow in this cone, so the city stays visible.
const OVERLOOK_ORIGIN: Vector2 = Vector2(168.0, 27.0)
const OVERLOOK_DIRECTION: Vector2 = Vector2(0.686, -0.727)
const OVERLOOK_HALF_ANGLE: float = 38.0
const OVERLOOK_VIEW_LENGTH: float = 70.0

const SEED: int = 20261003
const Generator := preload("res://scripts/tools/forest_path_vegetation_generator.gd")


func _run() -> void:
	var scene_root: Node = get_scene()
	if scene_root == null:
		push_error("Open the dream intro scene before running this script.")
		return

	var terrain: Terrain3D = scene_root.get_node_or_null(
		TERRAIN_NODE_NAME
	) as Terrain3D
	if terrain == null:
		push_error("No Terrain3D node named '%s' in the open scene." % TERRAIN_NODE_NAME)
		return

	var generator = Generator.new()
	generator.zone = ZONE
	generator.exclusions = EXCLUSIONS
	generator.seed_value = SEED
	var corridors: Array[Dictionary] = [{
		"origin": OVERLOOK_ORIGIN,
		"direction": OVERLOOK_DIRECTION.normalized(),
		"half_angle": OVERLOOK_HALF_ANGLE,
		"length": OVERLOOK_VIEW_LENGTH,
	}]
	generator.view_corridors = corridors

	var started: int = Time.get_ticks_msec()
	var result: Dictionary = generator.generate(terrain)
	print(
		"Forest vegetation: removed %d, added %d in %.1f s. Save the scene (Ctrl+S)."
		% [
			int(result.get("removed", 0)),
			int(result.get("added", 0)),
			float(Time.get_ticks_msec() - started) / 1000.0,
		]
	)
