@tool
extends Node3D
class_name TrailheadProps

## The start of the trail between the wagon and the fence gate: two signs, like the ones a small park put up in the nineties (a board of
## dull painted wood in a plain timber frame on two square posts, the timber the same pale, weathered wood as the fence gate beside them,
## no bright colour, no ornament), old and abused.
##
##   The welcome sign stands beside the way to the gate, facing the wagon's exit door. It says "Bem-vindo à"; the name of the
##   place that follows has been scratched at and painted over in red until it cannot be read, and over that someone has
##   painted "Fenda", as if children had done it.
##   The trail map sign stands on the other side, turned to face the middle of the space between the wagon's door and the
##   gate, with the map (the `ForestMap` collectible, a child of this node) pinned in its window. The paint under the map
##   is darker: the paper kept the sun off it. Taking the map is a scene (`PinnedCollectible`): the top pins are worked out, and the
##   paper is ripped off the bottom two, which keep a scrap of it.
## Both signs stand beside the gate, against the fence on either side of it, a little way from the opening, like a guide at the entrance.
##
## The boards' faces (the painted illustration, the logos, the grime, the red paint and the scratches) are baked pictures
## (`tools/bake_trailhead_signs.gd`, in `assets/textures/trailhead/`); the timber, the posts and the written words are built
## here in code, and put on the ground by asking the Terrain3D for its height, so nothing touches the terrain.
##
## The frame of this node: the origin is on the ground in the middle of the gate's opening; -Z is the way into the woods
## (through the gate), +Z the way back to the wagon, +X to the right when going in. The scene turns the node to the gate.

signal built

const SIGN_WELCOME_KEY: String = "SIGN_TRAILHEAD_WELCOME"
const SIGN_OLD_NAME_KEY: String = "SIGN_TRAILHEAD_OLD_NAME"
const SIGN_NEW_NAME_KEY: String = "SIGN_TRAILHEAD_NEW_NAME"

const LABEL_FONT_SIZE: int = 100
const RANDOM_SEED: int = 1989

const TEXTURE_DIRECTORY: String = "res://assets/textures/trailhead/"
const WELCOME_FACE_PATH: String = TEXTURE_DIRECTORY + "welcome_sign.png"
const DEFACED_NAME_PATH: String = TEXTURE_DIRECTORY + "name_defaced.png"
const BOARD_FACE_PATH: String = TEXTURE_DIRECTORY + "map_board.png"
## The fence gate's own wood (its albedo), so that the signs' timber is the same plain, pale, weathered wood.
const GATE_WOOD_PATH: String = "res://assets/models/wooden_structures/fence_gate/fence-gate_TreeEnd002_1K-JPG_Color.jpg"
const PANEL_COLOR: Color = Color(0.14, 0.19, 0.15)

## How deep the posts are set in the ground, and how thick the panels and their frames are.
const POST_BURIED: float = 0.4
const PANEL_DEPTH: float = 0.03
const FRAME_DEPTH: float = 0.045
const FACE_LIFT: float = 0.0005

# The welcome sign: a painted panel in a frame on two posts (the face is 1.3 by 0.72 m).
## Both signs stand beside the gate, against the fence on either side of it (about four metres from the middle of the opening, a little
## further than first, which was too close to the door), like a guide waiting at the entrance, not out in the clearing.
const WELCOME_AT: Vector2 = Vector2(3.0, 2.3)
const WELCOME_PANEL: Vector2 = Vector2(1.3, 0.72)
const WELCOME_FRAME: float = 0.055
const WELCOME_CENTER_Y: float = 1.4
const WELCOME_POST: float = 0.08
const WELCOME_POST_X: float = 0.46
## Where the writing is, on the face (x right, y up, from the face's middle), in metres. The old name is a line of
## capitals; the red paint and the scratches lie over a box a little bigger than it, and "Fenda" is painted over both.
const WELCOME_LINE_AT: Vector2 = Vector2(-0.58, 0.2)
const WELCOME_LINE_EM: float = 0.105
const OLD_NAME_AT: Vector2 = Vector2(-0.58, 0.04)
const OLD_NAME_EM: float = 0.15
const DEFACED_SIZE: Vector2 = Vector2(1.2, 0.27)
const DEFACED_AT: Vector2 = Vector2(-0.02, 0.0)
const NEW_NAME_AT: Vector2 = Vector2(0.06, -0.01)
const NEW_NAME_EM: float = 0.3
const DRIP_COUNT: int = 6

# The trail map sign: a tall panel in a frame between two posts, a cap over them, and the map in its window.
const BOARD_AT: Vector2 = Vector2(-1.85, 3.6)
const BOARD_PANEL: Vector2 = Vector2(0.92, 1.28)
const BOARD_PANEL_BOTTOM: float = 0.72
const BOARD_FRAME: float = 0.05
const BOARD_POST: float = 0.09
const BOARD_TOP_Y: float = 2.05
## The window the map is pinned in, on the panel: its middle from the panel's middle, and its size.
const MAP_WINDOW_CENTER: Vector2 = Vector2(0.0, 0.1)
const MAP_WINDOW_SIZE: Vector2 = Vector2(0.5, 0.41)
## Where the front of the board's panel is (in the board's frame), and where the middle of the pinned map is.
const BOARD_FACE_Z: float = 0.035
const MAP_MOUNT: Vector3 = Vector3(0.0, 1.46, 0.0372)
const PIN_INSET: float = 0.025
const PIN_RADIUS: float = 0.008

## The wagon's exit door, in the world (x, z): what the welcome sign faces, and (with the gate) what the trail map sign turns
## to the middle of.
@export var wagon_door_world: Vector2 = Vector2(1.35, 3.6)
## The Terrain3D that the ground is read from; without one everything stands on the origin's level.
@export var terrain_path: NodePath = ^"../../Terrain3D"
## The map item on the board: a child of this node with this name.
@export var map_name: StringName = &"ForestMap"

## The pieces the tests look for.
var is_built: bool = false
var welcome_sign: Node3D = null
var old_name_label: Label3D = null
var new_name_label: Label3D = null
var defacement: MeshInstance3D = null
var board: Node3D = null
var pins: Array[Node3D] = []
## The two scraps of paper that stay under the bottom pins when the map is ripped off.
var scraps: Array[Node3D] = []
var map: Node3D = null

var _terrain: Terrain3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _frame_wood: StandardMaterial3D
var _post_wood: StandardMaterial3D
var _plywood: StandardMaterial3D
var _red: StandardMaterial3D
var _pin_metal: StandardMaterial3D
var _scrap_paper: StandardMaterial3D

static var _grain_textures: Dictionary = {}


func _ready() -> void:
	# After every node of the scene is ready, so that the terrain has its data.
	call_deferred(&"_build_all")


func _build_all() -> void:
	if is_built or not is_inside_tree():
		return

	is_built = true
	_terrain = get_node_or_null(terrain_path) as Terrain3D
	_rng.seed = RANDOM_SEED
	_make_materials()
	_build_welcome_sign()
	_build_board()
	_mount_map()
	built.emit()


## The ground's height at (x, z) of this node's frame, as a height over this node's origin.
func ground_at(x: float, z: float) -> float:
	if _terrain == null or _terrain.data == null:
		return 0.0

	var height: float = _terrain.data.get_height(to_global(Vector3(x, 0.0, z)))
	if is_nan(height):
		return 0.0

	return height - global_position.y


## The wagon's exit door in this node's frame (x, z).
func wagon_door_local() -> Vector2:
	var local: Vector3 = to_local(Vector3(wagon_door_world.x, global_position.y, wagon_door_world.y))
	return Vector2(local.x, local.z)


## The middle of the space between the wagon's door and the gate (the gate is the origin), in this node's frame (x, z).
func space_center_local() -> Vector2:
	return wagon_door_local() * 0.5


## Where the four pins are, from the middle of the map, in the board's frame (x right, y up).
static func pin_offsets(paper_size: Vector2) -> Array[Vector2]:
	var half: Vector2 = paper_size * 0.5 - Vector2(PIN_INSET, PIN_INSET)
	return [Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]


# ============================================================
# MATERIALS
# ============================================================

## Weathered wood: a warm brown with grain, made from noise (streaks along a post, or across a plank's face).
static func _grain_texture(horizontal: bool) -> ImageTexture:
	if _grain_textures.has(horizontal):
		return _grain_textures[horizontal] as ImageTexture

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var size: int = 128
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var across: float = float(y) if horizontal else float(x)
			var along: float = float(x) if horizontal else float(y)
			var grain: float = 0.5 + 0.5 * noise.get_noise_2d(across * 0.8, along * 0.035)
			var crack: float = 0.5 + 0.5 * noise.get_noise_2d(across * 2.6 + 90.0, along * 0.12)
			var shade: float = 0.66 + 0.3 * grain - 0.16 * smoothstep(0.78, 0.95, crack)
			image.set_pixel(x, y, Color(shade, shade * 0.98, shade * 0.94, 1.0))

	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_grain_textures[horizontal] = texture
	return texture


func _wood(color: Color, horizontal: bool = false, roughness: float = 0.9) -> StandardMaterial3D:
	var material: StandardMaterial3D = HouseProps.material(color, roughness)
	material.albedo_texture = _grain_texture(horizontal)
	return material


## The fence gate's wood.
func _gate_wood(tint: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = HouseProps.material(tint, 0.85)
	if ResourceLoader.exists(GATE_WOOD_PATH):
		material.albedo_texture = load(GATE_WOOD_PATH) as Texture2D

	return material


func _make_materials() -> void:
	# The frames and posts are the fence gate's pale, weathered wood, a little greyer where the rain runs.
	_frame_wood = _gate_wood(Color(0.86, 0.8, 0.7))
	_post_wood = _gate_wood(Color(0.8, 0.75, 0.66))
	_plywood = _wood(Color(0.45, 0.4, 0.32), true)
	_red = HouseProps.material(Color(0.5, 0.06, 0.05), 0.5)
	# Map pins with a round head, dull brick red, the kind a park uses.
	_pin_metal = HouseProps.material(Color(0.5, 0.14, 0.1), 0.45, 0.2)
	_scrap_paper = HouseProps.material(ForestMapProps.PAPER_COLOR.lightened(0.05), 0.97)


## A picture lying on a panel: a quad `size` metres big, showing `path` (a plain colour if it has not been baked yet).
func _face(parent: Node, part_name: String, size: Vector2, path: String, fallback: Color, at: Vector3, transparent: bool = false, priority: int = 0) -> MeshInstance3D:
	var material: StandardMaterial3D = HouseProps.material(fallback, 0.55)
	if ResourceLoader.exists(path):
		material.albedo_color = Color.WHITE
		material.albedo_texture = load(path) as Texture2D
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	material.render_priority = priority
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	var face: MeshInstance3D = MeshInstance3D.new()
	face.name = part_name
	face.mesh = quad
	face.material_override = material
	face.position = at
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(face)
	return face


# ============================================================
# SMALL PARTS
# ============================================================

func _box(parent: Node, part_name: String, size: Vector3, at: Vector3, material: Material, rotation_degrees_xyz: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return HouseProps.add_box(parent, part_name, size, at, material, rotation_degrees_xyz)


## Written words (a localization key) `em` metres tall.
func _words(parent: Node, part_name: String, key: String, at: Vector3, em: float, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, priority: int = 0) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = part_name
	label.text = key
	label.font_size = LABEL_FONT_SIZE
	label.pixel_size = em / float(LABEL_FONT_SIZE)
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.render_priority = priority
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = at
	parent.add_child(label)
	return label


func _jitter(amount: float) -> float:
	return _rng.randf_range(-amount, amount)


## Turns `node` (standing at `from`, both in this node's frame, x and z) so that its front (+Z) faces `target`.
func _turn_to(node: Node3D, from: Vector2, target: Vector2) -> void:
	var direction: Vector2 = target - from
	node.rotation.y = atan2(direction.x, direction.y)


## A panel in a frame, as the signs are made: a box (its back is bare plywood) with a baked face on it, and four timber strips
## round it. `parent` is the sign's node (its origin on the ground, the front toward +Z); `back_z` is where the panel's back is.
func _panelled(parent: Node3D, size: Vector2, center_y: float, back_z: float, frame: float, face_path: String, fallback: Color) -> void:
	var panel_z: float = back_z + PANEL_DEPTH * 0.5
	_box(parent, "Panel", Vector3(size.x, size.y, PANEL_DEPTH), Vector3(0.0, center_y, panel_z), _plywood)
	_face(parent, "Face", size, face_path, fallback, Vector3(0.0, center_y, back_z + PANEL_DEPTH + FACE_LIFT))
	# The frame reaches from the panel's back to a little proud of its front.
	var frame_z: float = back_z + FRAME_DEPTH * 0.5
	_box(parent, "FrameTop", Vector3(size.x + frame * 2.0, frame, FRAME_DEPTH), Vector3(0.0, center_y + size.y * 0.5 + frame * 0.5, frame_z), _frame_wood)
	_box(parent, "FrameBottom", Vector3(size.x + frame * 2.0, frame, FRAME_DEPTH), Vector3(0.0, center_y - size.y * 0.5 - frame * 0.5, frame_z), _frame_wood)
	for side: int in 2:
		var x: float = (size.x * 0.5 + frame * 0.5) * (-1.0 if side == 0 else 1.0)
		_box(parent, "FrameSide%d" % side, Vector3(frame, size.y, FRAME_DEPTH), Vector3(x, center_y, frame_z), _frame_wood)


# ============================================================
# THE WELCOME SIGN
# ============================================================

func _build_welcome_sign() -> void:
	welcome_sign = Node3D.new()
	welcome_sign.name = "WelcomeSign"
	var ground: float = ground_at(WELCOME_AT.x, WELCOME_AT.y)
	welcome_sign.position = Vector3(WELCOME_AT.x, ground, WELCOME_AT.y)
	add_child(welcome_sign)
	_turn_to(welcome_sign, WELCOME_AT, wagon_door_local())

	# Two square posts; the panel is fixed to their front, and they end behind it.
	var post_top: float = WELCOME_CENTER_Y - WELCOME_PANEL.y * 0.5 + 0.5
	for side: int in 2:
		var x: float = -WELCOME_POST_X if side == 0 else WELCOME_POST_X
		var height: float = post_top + POST_BURIED
		_box(welcome_sign, "Post%d" % side, Vector3(WELCOME_POST, height, WELCOME_POST), Vector3(x, post_top - height * 0.5, 0.0), _post_wood)
		HouseProps.add_solid(welcome_sign, "Solid%d" % side, Vector3(0.14, post_top, 0.14), Vector3(x, post_top * 0.5, 0.0))

	var back_z: float = WELCOME_POST * 0.5
	_panelled(welcome_sign, WELCOME_PANEL, WELCOME_CENTER_Y, back_z, WELCOME_FRAME, WELCOME_FACE_PATH, PANEL_COLOR)

	var face_z: float = back_z + PANEL_DEPTH + FACE_LIFT
	var center: Vector3 = Vector3(0.0, WELCOME_CENTER_Y, face_z)
	_words(welcome_sign, "Welcome", SIGN_WELCOME_KEY, center + Vector3(WELCOME_LINE_AT.x, WELCOME_LINE_AT.y, 0.0015), WELCOME_LINE_EM, Color(0.8, 0.76, 0.63), HORIZONTAL_ALIGNMENT_LEFT, 1)
	# The old name, dulled by the years and made bolder, as on the park's own signs: what is under the paint and the scratches.
	old_name_label = _words(welcome_sign, "OldName", SIGN_OLD_NAME_KEY, center + Vector3(OLD_NAME_AT.x, OLD_NAME_AT.y, 0.0015), OLD_NAME_EM, Color(0.5, 0.48, 0.4), HORIZONTAL_ALIGNMENT_LEFT, 1)
	old_name_label.outline_size = 4
	old_name_label.outline_modulate = old_name_label.modulate
	defacement = _face(welcome_sign, "Defacement", DEFACED_SIZE, DEFACED_NAME_PATH, Color(0.5, 0.06, 0.05, 0.7), center + Vector3(DEFACED_AT.x, DEFACED_AT.y, 0.0028), true, 2)
	new_name_label = _words(welcome_sign, "NewName", SIGN_NEW_NAME_KEY, center + Vector3(NEW_NAME_AT.x, NEW_NAME_AT.y, 0.0045), NEW_NAME_EM, Color(0.56, 0.05, 0.04), HORIZONTAL_ALIGNMENT_CENTER, 3)
	new_name_label.rotation_degrees.z = -4.0
	new_name_label.outline_size = 6
	new_name_label.outline_modulate = Color(0.28, 0.03, 0.03)
	_drips(center + Vector3(NEW_NAME_AT.x, NEW_NAME_AT.y - 0.1, 0.0042), 0.7)


## Paint running down from the letters: thin streaks of different lengths, each with a round bead at its foot.
func _drips(top: Vector3, word_width: float) -> void:
	for i: int in DRIP_COUNT:
		var x: float = top.x + word_width * (float(i) / float(DRIP_COUNT - 1) - 0.5) * 0.9 + _jitter(0.03)
		var length: float = _rng.randf_range(0.04, 0.16)
		_box(welcome_sign, "Drip%d" % i, Vector3(_rng.randf_range(0.006, 0.012), length, 0.0012), Vector3(x, top.y - length * 0.5, top.z), _red)
		HouseProps.add_cylinder(welcome_sign, "DripBead%d" % i, 0.009, 0.0012, Vector3(x, top.y - length, top.z), _red, Vector3(90.0, 0.0, 0.0))


# ============================================================
# THE TRAIL MAP SIGN
# ============================================================

func _build_board() -> void:
	board = Node3D.new()
	board.name = "MapBoard"
	var ground: float = ground_at(BOARD_AT.x, BOARD_AT.y)
	board.position = Vector3(BOARD_AT.x, ground, BOARD_AT.y)
	add_child(board)
	_turn_to(board, BOARD_AT, space_center_local())

	# Two square posts either side of the frame, and a cap across their tops.
	var post_x: float = BOARD_PANEL.x * 0.5 + BOARD_FRAME + BOARD_POST * 0.5
	var post_height: float = BOARD_TOP_Y + POST_BURIED
	for side: int in 2:
		var x: float = -post_x if side == 0 else post_x
		_box(board, "Post%d" % side, Vector3(BOARD_POST, post_height, BOARD_POST), Vector3(x, BOARD_TOP_Y - post_height * 0.5, 0.0), _post_wood)
		HouseProps.add_solid(board, "Solid%d" % side, Vector3(0.15, BOARD_TOP_Y, 0.15), Vector3(x, BOARD_TOP_Y * 0.5, 0.0))

	_box(board, "Cap", Vector3(post_x * 2.0 + BOARD_POST, 0.07, BOARD_POST), Vector3(0.0, BOARD_TOP_Y + 0.035, 0.0), _post_wood)
	var panel_center_y: float = BOARD_PANEL_BOTTOM + BOARD_PANEL.y * 0.5
	_panelled(board, BOARD_PANEL, panel_center_y, BOARD_FACE_Z - PANEL_DEPTH, BOARD_FRAME, BOARD_FACE_PATH, PANEL_COLOR)

	# Four pins through the map's corners. They are pulled out when the map is taken.
	for offset: Vector2 in pin_offsets(ForestMapProps.paper_size()):
		var pin: MeshInstance3D = HouseProps.add_cylinder(
			board, "Pin%d" % pins.size(), PIN_RADIUS, 0.006,
			Vector3(MAP_MOUNT.x + offset.x, MAP_MOUNT.y + offset.y, MAP_MOUNT.z + 0.0045),
			_pin_metal, Vector3(90.0, 0.0, 0.0)
		)
		pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pins.append(pin)

		# The map is ripped off the bottom pins: a ragged scrap of it stays under each, hidden behind the paper until it is gone.
		if pins.size() > 2:
			var scrap: MeshInstance3D = _box(
				board, "Scrap%d" % scraps.size(), Vector3(0.034, 0.026, 0.0008),
				Vector3(MAP_MOUNT.x + offset.x, MAP_MOUNT.y + offset.y, MAP_MOUNT.z - 0.0004),
				_scrap_paper, Vector3(0.0, 0.0, _rng.randf_range(-25.0, 25.0))
			)
			scrap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			scraps.append(scrap)


## Puts the map on the board, in the window, and gives it its pins (a `PinnedCollectible` pulls them when it is taken).
func _mount_map() -> void:
	map = get_node_or_null(NodePath(String(map_name))) as Node3D
	if map == null or board == null:
		return

	map.transform = board.transform * Transform3D(Basis.IDENTITY, MAP_MOUNT)
	# (In the editor the map's script is only a placeholder, which holds no variables: it only has the pins when it plays.)
	var pinned: PinnedCollectible = map as PinnedCollectible
	if pinned != null and not Engine.is_editor_hint():
		pinned.pins = pins
