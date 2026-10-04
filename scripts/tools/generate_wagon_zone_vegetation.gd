@tool
extends EditorScript

## Run from the Script Editor with File > Run (Ctrl+Shift+X) while the dream
## intro scene is open, then save the scene (Ctrl+S).
##
## Fills the area around the train and up to the gate fence with the forest
## pattern, while keeping every structure visible: nothing grows on the rails
## or wagons or in the gate, only low plants grow beside the fences and wagons,
## and no trees stand close enough for their crowns to hang over the train.
##
## It does NOT run the one-time ground relief; the train area stays flat.

const Generator := preload("res://scripts/tools/forest_path_vegetation_generator.gd")

const TERRAIN_NODE_NAME: String = "Terrain3D"

const ZONE: Rect2 = Rect2(-45.0, -62.0, 57.0, 132.0)

## Rails and wagon bodies: no plants at all. The door fence is also covered.
const EXCLUSIONS: Array[Rect2] = [
	Rect2(-2.7, -37.0, 5.4, 80.0),
	Rect2(9.0, 4.2, 2.4, 3.6),
]

## Fence lines flank the train at x -3.7 and 3.5; the gate fence arcs out to
## the door. Only low plants within these areas.
const LOW_ZONES: Array[Rect2] = [
	Rect2(-4.6, -37.0, 9.2, 80.0),
]

const NO_TREE_ZONES: Array[Rect2] = [
	Rect2(-10.0, -40.0, 20.0, 86.0),
	Rect2(7.5, 2.5, 5.0, 6.0),
]

## Strips between each wagon side (x +-2.4) and its fence (x +-3.5-4): filled
## directly with dense small and low-medium plants.
const FILL_ZONES: Array[Rect2] = [
	Rect2(-3.45, -37.0, 0.75, 80.0),
	Rect2(2.7, -37.0, 0.75, 80.0),
]

## Lines the forest is grown around (just inside the fences).
const SIDE_LINES: Array[float] = [-3.0, 3.0]


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
	generator.low_zones = LOW_ZONES
	generator.no_tree_zones = NO_TREE_ZONES
	generator.fill_zones = FILL_ZONES

	# The ground here is hand-painted (dirt = walkable, grass = vegetation), so
	# do not repaint it. Plants follow the painting.
	generator.paint_ground_textures = false
	generator.virtual_path_half_width = 0.5

	var lines: Array[PackedVector2Array] = []
	for x: float in SIDE_LINES:
		lines.append(PackedVector2Array([Vector2(x, -42.0), Vector2(x, 48.0)]))
	generator.virtual_paths = lines

	var result: Dictionary = generator.generate(terrain)
	print(
		"Wagon zone: removed %d, added %d. Save the scene (Ctrl+S)."
		% [int(result.get("removed", 0)), int(result.get("added", 0))]
	)
