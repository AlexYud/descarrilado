extends CanvasLayer
class_name ArchiveVideoOverlay

## The presentation of the recording in the waiting shed: a 4:3 picture with black bars around it, and the picture itself
## drained, grainy and softly scanned (assets/shaders/archive_video.gdshader). It sits above the game's own filters and below
## the subtitles, and is only built, shown and freed by the shed's sequence. It does not touch the player's settings: with
## the player's video filter off, only the colour is drained and the bars stay (no grain, scanlines or vignette).

const ASPECT: float = 4.0 / 3.0
const SHADER: Shader = preload("res://assets/shaders/archive_video.gdshader")

var _picture: ColorRect = null
var _black: ColorRect = null
var _bars: Array[ColorRect] = []


func _init() -> void:
	name = "ArchiveVideoOverlay"
	# Over the world and the screen filter (layer 0), under the subtitles (1100) and the menus.
	layer = 10
	visible = false


func _ready() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	var full_look: bool = GameSettings.get_vhs_filter_enabled()
	material.set_shader_parameter(&"grain", 0.05 if full_look else 0.0)
	material.set_shader_parameter(&"scanlines", 0.035 if full_look else 0.0)
	material.set_shader_parameter(&"vignette", 0.35 if full_look else 0.0)

	_picture = ColorRect.new()
	_picture.name = "Picture"
	_picture.material = material
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)

	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color.BLACK
	_black.visible = false
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	for bar_name: String in ["BarLeft", "BarRight", "BarTop", "BarBottom"]:
		var bar: ColorRect = ColorRect.new()
		bar.name = bar_name
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		_bars.append(bar)

	_layout()


func _process(_delta: float) -> void:
	if visible:
		_layout()


## The picture on (the recording plays).
func show_picture() -> void:
	visible = true
	if _black != null:
		_black.visible = false
	_layout()


## The picture goes out, the bars stay (the tape is stopped).
func show_black() -> void:
	visible = true
	if _black != null:
		_black.visible = true
	_layout()


## Everything away: the present again.
func hide_overlay() -> void:
	visible = false
	if _black != null:
		_black.visible = false


func is_picture_shown() -> bool:
	return visible and _black != null and not _black.visible


## The vertical lens that makes the picture's 4:3 frame (not the whole viewport) show what a shot designed with `designed_fov` shows: the same in a
## window as wide as 4:3 or wider (the picture fills its height), and wider in a narrower window (the picture is a band across its middle, so the camera
## must see more above and below it). The recording is framed to this rectangle, never to the window: its top edge sits under a standing person's chin.
static func matched_fov(designed_fov: float, viewport: Vector2) -> float:
	var picture_height: float = minf(viewport.y, viewport.x / ASPECT)
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(designed_fov) * 0.5) * viewport.y / maxf(picture_height, 1.0)))


## The picture rectangle in screen pixels: the largest 4:3 that fits the screen, centred.
func get_picture_rect() -> Rect2:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var width: float = minf(screen.x, screen.y * ASPECT)
	var height: float = width / ASPECT
	return Rect2((screen.x - width) * 0.5, (screen.y - height) * 0.5, width, height)


func _layout() -> void:
	if _picture == null:
		return

	var screen: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = get_picture_rect()
	_picture.position = rect.position
	_picture.size = rect.size
	_black.position = rect.position
	_black.size = rect.size
	# Left, right, top, bottom; each a little over-size so no seam shows.
	_bars[0].position = Vector2(-2.0, -2.0)
	_bars[0].size = Vector2(rect.position.x + 2.0, screen.y + 4.0)
	_bars[1].position = Vector2(rect.end.x, -2.0)
	_bars[1].size = Vector2(screen.x - rect.end.x + 2.0, screen.y + 4.0)
	_bars[2].position = Vector2(rect.position.x, -2.0)
	_bars[2].size = Vector2(rect.size.x, rect.position.y + 2.0)
	_bars[3].position = Vector2(rect.position.x, rect.end.y)
	_bars[3].size = Vector2(rect.size.x, screen.y - rect.end.y + 2.0)
