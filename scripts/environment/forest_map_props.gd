@tool
extends RefCounted
class_name ForestMapProps

## The map of the forest that hangs on the information board at the start of the trail (`TrailheadProps`): a sheet of aged
## paper with the trails drawn on it as they really are (the picture is baked from the Terrain3D path cells by
## `tools/bake_forest_map.gd`, into `assets/textures/map/forest_map.png`), an ink icon for every place of the story and the
## names of the places as written words (Label3D with localization keys). It shows nothing of where the player stands: it
## is a map, not a guide.
##
## The sheet is a `FoldingSheet`: it folds the way a road map does, and the inspect view folds it small when the map is
## taken or put away and opens it out when it is looked at (the `inspect_fold_rig` metadata of the item's Visual names it).
## Its front is built facing +Z with +Y up, centred on the origin, which is how the inspect view shows it. North (the world's
## -Z) is the top of the sheet. The back of the sheet is bare paper (no title). ProceduralProp calls `build()` for the kind below.

const KIND_FOREST_MAP: StringName = &"forest_map"
const TEXTURE_PATH: String = "res://assets/textures/map/forest_map.png"

## The part of the world the sheet shows, as (x, z) in metres, and how many pixels of the picture are a metre.
const WORLD_MIN: Vector2 = Vector2(-14.0, -90.0)
const WORLD_SIZE: Vector2 = Vector2(204.0, 164.0)
const PIXELS_PER_METER: int = 4

## The sheet is a little paper map, the size a park pins on a board (a pocket map opened out would be about this).
const PAPER_WIDTH: float = 0.46
const PAPER_THICKNESS: float = 0.0015
const LABEL_LIFT: float = 0.0012
const LABEL_FONT_SIZE: int = 40
## The size one pixel of a name has on a sheet `REFERENCE_PAPER_WIDTH` wide; the names are made smaller with the sheet.
const LABEL_PIXEL_SIZE: float = 0.00042
const REFERENCE_PAPER_WIDTH: float = 0.7
const PAPER_COLOR: Color = Color(0.74, 0.65, 0.46)
const INK_COLOR: Color = Color(0.2, 0.12, 0.07)

## How far from the middle of the compass in the picture's corner, and from the corner, in pixels.
const COMPASS_FROM_CORNER: float = 80.0
const TITLE_AT: Vector2 = Vector2(150.0, -82.0)
## The names are written with a halo of paper, so that a trail running under one does not cut it up.
const LABEL_HALO_SIZE: int = 10
const LABEL_HALO_COLOR: Color = Color(0.85, 0.77, 0.58)

## Every place that is drawn: `shape` is the icon (see the baker), `at` the world position as (x, z), `label` the name
## and `name_at` where the name is written, as metres from the icon (x east, z south) on the side that is empty. The sheet
## folds along the middle lines of the map, so a name never lies across one (a test checks it): the creases are at the
## world's x 88 and z -8.
const LANDMARKS: Array[Dictionary] = [
	{"id": "door", "shape": "door", "at": Vector2(10.3, 4.9), "label": "MAP_LABEL_DOOR", "name_at": Vector2(10.0, 10.0)},
	{"id": "shed", "shape": "shed", "at": Vector2(65.0, -16.0), "label": "MAP_LABEL_SHED", "name_at": Vector2(0.0, -9.0)},
	{"id": "clearing", "shape": "clearing", "at": Vector2(64.0, -68.0), "label": "MAP_LABEL_CLEARING", "name_at": Vector2(0.0, 11.0)},
	{"id": "tower", "shape": "tower", "at": Vector2(101.5, -36.0), "label": "MAP_LABEL_TOWER", "name_at": Vector2(19.0, 1.0)},
	{"id": "house", "shape": "house", "at": Vector2(68.5, 55.0), "label": "MAP_LABEL_HOUSE", "name_at": Vector2(-4.0, 10.0)},
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
	var sheet: FoldingSheet = FoldingSheet.new()
	sheet.name = "Sheet"
	sheet.sheet_size = paper_size()
	sheet.thickness = PAPER_THICKNESS
	sheet.paper_color = PAPER_COLOR
	if ResourceLoader.exists(TEXTURE_PATH):
		sheet.front_texture = load(TEXTURE_PATH) as Texture2D

	sheet.build()
	root.add_child(sheet)

	var ink: Color = INK_COLOR
	var title: Vector2 = world_to_paper(TITLE_AT)
	sheet.attach(_label("Title", "MAP_TITLE", LABEL_FONT_SIZE * 2, ink.lightened(0.05), false), title, LABEL_LIFT)

	for landmark: Dictionary in LANDMARKS:
		var at: Vector2 = world_to_paper(landmark["at"] + landmark["name_at"])
		sheet.attach(_label("Label_%s" % landmark["id"], str(landmark["label"]), LABEL_FONT_SIZE, ink, true), at, LABEL_LIFT)

	sheet.attach(_label("Label_railway", "MAP_LABEL_RAILWAY", LABEL_FONT_SIZE, ink, true), world_to_paper(RAILWAY_LABEL_AT), LABEL_LIFT)

	# North, over the compass.
	sheet.attach(_label("North", "N", LABEL_FONT_SIZE, ink, false), world_to_paper(compass_world() + Vector2(0.0, -14.5)), LABEL_LIFT)


## A written name (a localization key) as a Label3D that has not been placed yet.
static func _label(label_name: String, key: String, font_size: int, color: Color, halo: bool) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = label_name
	label.text = key
	label.font_size = font_size
	label.pixel_size = LABEL_PIXEL_SIZE * PAPER_WIDTH / REFERENCE_PAPER_WIDTH
	label.modulate = color
	label.outline_size = LABEL_HALO_SIZE if halo else 0
	label.outline_modulate = LABEL_HALO_COLOR
	label.shaded = true
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
