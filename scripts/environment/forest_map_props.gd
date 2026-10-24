@tool
extends RefCounted
class_name ForestMapProps

## The map of the forest that lies on the ground just past the fence door: a sheet of aged paper with the trails drawn
## on it as they really are (the picture is baked from the Terrain3D path cells by `tools/bake_forest_map.gd`, into
## `assets/textures/map/forest_map.png`), an ink icon for every place of the story, the names of the places as written
## words (Label3D with localization keys), and a red dot and arrow that follow the player (`ForestMapMarker`).
##
## The sheet is built facing +Z with +Y up, centred on the origin, which is how the inspect view shows it. North (the
## world's -Z) is the top of the sheet. ProceduralProp calls `build()` for the kind below.

const KIND_FOREST_MAP: StringName = &"forest_map"
const TEXTURE_PATH: String = "res://assets/textures/map/forest_map.png"

## The part of the world the sheet shows, as (x, z) in metres, and how many pixels of the picture are a metre.
const WORLD_MIN: Vector2 = Vector2(-14.0, -90.0)
const WORLD_SIZE: Vector2 = Vector2(204.0, 164.0)
const PIXELS_PER_METER: int = 4

const PAPER_WIDTH: float = 0.7
const PAPER_THICKNESS: float = 0.002
const PRINT_LIFT: float = 0.0002
const LABEL_LIFT: float = 0.0016
const LABEL_FONT_SIZE: int = 40
const LABEL_PIXEL_SIZE: float = 0.00042
const PAPER_COLOR: Color = Color(0.74, 0.65, 0.46)
const INK_COLOR: Color = Color(0.2, 0.12, 0.07)

## How far from the middle of the compass in the picture's corner, and from the corner, in pixels.
const COMPASS_FROM_CORNER: float = 80.0
## Where the legend (the red dot and its words) stands, in the world.
const LEGEND_AT: Vector2 = Vector2(-4.0, 68.0)
const TITLE_AT: Vector2 = Vector2(150.0, -82.0)
## The names are written with a halo of paper, so that a trail running under one does not cut it up.
const LABEL_HALO_SIZE: int = 10
const LABEL_HALO_COLOR: Color = Color(0.85, 0.77, 0.58)

## Every place that is drawn: `shape` is the icon (see the baker), `at` the world position as (x, z), `label` the name
## and `name_at` where the name is written, as metres from the icon (x east, z south) on the side that is empty.
const LANDMARKS: Array[Dictionary] = [
	{"id": "door", "shape": "door", "at": Vector2(10.3, 4.9), "label": "MAP_LABEL_DOOR", "name_at": Vector2(10.0, 10.0)},
	{"id": "shed", "shape": "shed", "at": Vector2(65.0, -16.0), "label": "MAP_LABEL_SHED", "name_at": Vector2(0.0, 10.0)},
	{"id": "clearing", "shape": "clearing", "at": Vector2(64.0, -68.0), "label": "MAP_LABEL_CLEARING", "name_at": Vector2(0.0, 11.0)},
	{"id": "tower", "shape": "tower", "at": Vector2(101.5, -36.0), "label": "MAP_LABEL_TOWER", "name_at": Vector2(19.0, 1.0)},
	{"id": "house", "shape": "house", "at": Vector2(68.5, 55.0), "label": "MAP_LABEL_HOUSE", "name_at": Vector2(22.0, -1.0)},
	{"id": "overlook", "shape": "overlook", "at": Vector2(174.5, 25.4), "label": "MAP_LABEL_OVERLOOK", "name_at": Vector2(0.0, -10.0)},
]
## The railway runs north to south through (0, 0); the sheet draws it between these two z values.
const RAILWAY_Z: Vector2 = Vector2(-35.0, 35.0)
const RAILWAY_LABEL_AT: Vector2 = Vector2(4.0, 44.0)


static func has_kind(kind: StringName) -> bool:
	return kind == KIND_FOREST_MAP


static func build(kind: StringName, root: Node3D) -> void:
	if kind != KIND_FOREST_MAP:
		push_warning("ForestMapProps: unknown prop kind '%s'." % kind)
		return

	_build_map(root)


## The size of the sheet in metres.
static func paper_size() -> Vector2:
	return Vector2(PAPER_WIDTH, PAPER_WIDTH * WORLD_SIZE.y / WORLD_SIZE.x)


## The size of the picture in pixels.
static func picture_size() -> Vector2i:
	return Vector2i(int(WORLD_SIZE.x) * PIXELS_PER_METER, int(WORLD_SIZE.y) * PIXELS_PER_METER)


## A world position (x, z) to the picture, in pixels from its top left corner.
static func world_to_pixel(world: Vector2) -> Vector2:
	return (world - WORLD_MIN) * float(PIXELS_PER_METER)


## A world position (x, z) to the sheet's own frame (x right, y up, the middle at the origin), in metres.
static func world_to_paper(world: Vector2) -> Vector2:
	var paper: Vector2 = paper_size()
	var fraction: Vector2 = (world - WORLD_MIN) / WORLD_SIZE
	return Vector2((fraction.x - 0.5) * paper.x, (0.5 - fraction.y) * paper.y)


## Whether a world position (x, z) lies on the sheet.
static func covers(world: Vector2) -> bool:
	var fraction: Vector2 = (world - WORLD_MIN) / WORLD_SIZE
	return fraction.x >= 0.0 and fraction.x <= 1.0 and fraction.y >= 0.0 and fraction.y <= 1.0


## The middle of the compass in the world (x, z): in the picture's bottom right corner.
static func compass_world() -> Vector2:
	var corner: Vector2 = Vector2(picture_size())
	return WORLD_MIN + (corner - Vector2(COMPASS_FROM_CORNER, COMPASS_FROM_CORNER)) / float(PIXELS_PER_METER)


static func _build_map(root: Node3D) -> void:
	var paper: Vector2 = paper_size()
	HouseProps.add_box(root, "Sheet", Vector3(paper.x, paper.y, PAPER_THICKNESS), Vector3.ZERO, HouseProps.material(PAPER_COLOR, 0.97))

	# The picture. Without it (before it is baked) the sheet is plain paper.
	if ResourceLoader.exists(TEXTURE_PATH):
		var print_material: StandardMaterial3D = HouseProps.material(Color.WHITE, 0.96)
		print_material.albedo_texture = load(TEXTURE_PATH) as Texture2D
		print_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var quad: QuadMesh = QuadMesh.new()
		quad.size = paper
		var print: MeshInstance3D = MeshInstance3D.new()
		print.name = "Print"
		print.mesh = quad
		print.material_override = print_material
		print.position = Vector3(0.0, 0.0, PAPER_THICKNESS * 0.5 + PRINT_LIFT)
		root.add_child(print)

	var ink: Color = INK_COLOR
	var title: Vector2 = world_to_paper(TITLE_AT)
	HouseProps.add_text(root, "Title", "MAP_TITLE", Vector3(title.x, title.y, LABEL_LIFT), LABEL_FONT_SIZE * 2, LABEL_PIXEL_SIZE, ink.lightened(0.05), 0.0, true)

	for landmark: Dictionary in LANDMARKS:
		var at: Vector2 = world_to_paper(landmark["at"] + landmark["name_at"])
		var name_label: Label3D = HouseProps.add_text(root, "Label_%s" % landmark["id"], str(landmark["label"]), Vector3(at.x, at.y, LABEL_LIFT), LABEL_FONT_SIZE, LABEL_PIXEL_SIZE, ink, 0.0, true)
		_halo(name_label)

	var railway: Vector2 = world_to_paper(RAILWAY_LABEL_AT)
	_halo(HouseProps.add_text(root, "Label_railway", "MAP_LABEL_RAILWAY", Vector3(railway.x, railway.y, LABEL_LIFT), LABEL_FONT_SIZE, LABEL_PIXEL_SIZE, ink, 0.0, true))

	# North, over the compass.
	var compass: Vector2 = world_to_paper(compass_world() + Vector2(0.0, -13.0))
	HouseProps.add_text(root, "North", "N", Vector3(compass.x, compass.y, LABEL_LIFT), LABEL_FONT_SIZE, LABEL_PIXEL_SIZE, ink, 0.0, true)

	# The legend: the red dot of the player and what it means.
	var legend: Vector2 = world_to_paper(LEGEND_AT)
	var dot_material: StandardMaterial3D = ForestMapMarker.dot_material()
	var dot: MeshInstance3D = HouseProps.add_cylinder(root, "LegendDot", ForestMapMarker.DOT_RADIUS, 0.0006, Vector3(legend.x, legend.y, LABEL_LIFT), dot_material, Vector3(90.0, 0.0, 0.0))
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var words: Label3D = HouseProps.add_text(root, "LegendWords", "MAP_LEGEND_YOU", Vector3(legend.x + 0.012, legend.y, LABEL_LIFT), LABEL_FONT_SIZE, LABEL_PIXEL_SIZE, ink)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var marker: ForestMapMarker = ForestMapMarker.new()
	marker.name = "YouAreHere"
	root.add_child(marker)


static func _halo(label: Label3D) -> void:
	label.outline_size = LABEL_HALO_SIZE
	label.outline_modulate = LABEL_HALO_COLOR
