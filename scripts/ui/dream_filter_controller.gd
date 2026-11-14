extends CanvasLayer

## The game's picture: the dream look (assets/shaders/dream_filter.gdshader: diffusion glow, the Orton softness, halation, a milky lift in the
## blacks, grain), a layer-0 overlay of the screen. The player can take it off (Options, Graphics: `GameSettings.dream_filter_enabled`, on by
## default). It steps aside while a scene shows the camcorder / VHS look (`HorrorFilter.hold_scene_look`): the two are never stacked.
##
## While an item is held up in the inspect view its softness and glow are mostly faded out, so writing and small details stay crisp.

const QUALITY_LOW: int = 0
const QUALITY_MEDIUM: int = 1

## The parameters faded while inspecting, and how much of each is left then.
const INSPECT_FADED: Array[StringName] = [&"soft_focus", &"orton_opacity", &"glow_strength", &"halation_strength", &"fringe_pixels"]
const INSPECT_KEEP: float = 0.25
const INSPECT_FADE_SECONDS: float = 0.25

@onready var dream_rect: ColorRect = $DreamRect

## 0 for the usual picture, 1 while an item is inspected.
var inspect_amount: float = 0.0

var _base: Dictionary = {}
var _applied: float = -1.0
var _player: Node = null


func _ready() -> void:
	var filter_material: ShaderMaterial = dream_rect.material as ShaderMaterial
	if filter_material != null:
		for parameter: StringName in INSPECT_FADED:
			_base[parameter] = _read_parameter(filter_material, parameter)

	if not GameSettings.quality_preset_changed.is_connected(_apply_quality_preset):
		GameSettings.quality_preset_changed.connect(_apply_quality_preset)
	if not GameSettings.dream_filter_changed.is_connected(_on_dream_filter_changed):
		GameSettings.dream_filter_changed.connect(_on_dream_filter_changed)
	_apply_quality_preset(GameSettings.get_quality_preset())
	_refresh_visible()


func _exit_tree() -> void:
	if GameSettings.quality_preset_changed.is_connected(_apply_quality_preset):
		GameSettings.quality_preset_changed.disconnect(_apply_quality_preset)
	if GameSettings.dream_filter_changed.is_connected(_on_dream_filter_changed):
		GameSettings.dream_filter_changed.disconnect(_on_dream_filter_changed)


func _process(delta: float) -> void:
	_refresh_visible()
	var target: float = 1.0 if _is_inspecting() else 0.0
	inspect_amount = move_toward(inspect_amount, target, delta / INSPECT_FADE_SECONDS)
	if is_equal_approx(inspect_amount, _applied):
		return

	_applied = inspect_amount
	var filter_material: ShaderMaterial = dream_rect.material as ShaderMaterial
	if filter_material == null:
		return

	for parameter: StringName in INSPECT_FADED:
		filter_material.set_shader_parameter(parameter, float(_base.get(parameter, 0.0)) * lerpf(1.0, INSPECT_KEEP, inspect_amount))


## On when the player has it on and no scene is showing the VHS look (the HorrorFilter beside this one in the same viewport, or the autoload).
func _refresh_visible() -> void:
	var wanted: bool = GameSettings.get_dream_filter_enabled() and not _scene_look_shown()
	if visible != wanted:
		visible = wanted


func _scene_look_shown() -> bool:
	var horror: Node = get_parent().get_node_or_null(^"HorrorFilter") if get_parent() != null else null
	if horror == null or horror == self:
		horror = get_node_or_null(^"/root/HorrorFilter")
	return horror != null and horror.has_method(&"is_scene_look_held") and bool(horror.call(&"is_scene_look_held"))


func _on_dream_filter_changed(_enabled: bool) -> void:
	_refresh_visible()


func _apply_quality_preset(preset: int) -> void:
	var filter_material: ShaderMaterial = dream_rect.material as ShaderMaterial
	if filter_material == null:
		return

	match preset:
		QUALITY_LOW:
			filter_material.set_shader_parameter(&"sample_quality", 0.0)
		QUALITY_MEDIUM:
			filter_material.set_shader_parameter(&"sample_quality", 0.5)
		_:
			filter_material.set_shader_parameter(&"sample_quality", 1.0)


## True while the player has an item held up.
func _is_inspecting() -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player")
	if _player == null:
		return false

	var inspect: Variant = _player.get("inspect_controller")
	return inspect != null and bool(inspect.call("is_open"))


## Where the lens shows what the camera drew at `point` (a position in the viewport, in pixels). The shader reads the drawing at
## `p * (1 + k * |p|^2) / (1 + 2k)` for a shown position `p` (0 is the middle, 1 the edges; `k` its `fisheye_strength`), so a drawn point is shown where
## that gives it back (a few rounds of the inverse settle it). Hidden, it gives the point back. See `ScreenLens`.
func lens_position(point: Vector2, viewport_size: Vector2) -> Vector2:
	var filter_material: ShaderMaterial = dream_rect.material as ShaderMaterial
	if filter_material == null or not visible or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return point

	var fisheye: float = _read_parameter(filter_material, &"fisheye_strength")
	var drawn: Vector2 = point / viewport_size * 2.0 - Vector2.ONE
	var shown: Vector2 = drawn
	for i: int in 6:
		shown = drawn * (1.0 + 2.0 * fisheye) / (1.0 + fisheye * shown.length_squared())
	return (shown * 0.5 + Vector2(0.5, 0.5)) * viewport_size


func _read_parameter(filter_material: ShaderMaterial, parameter: StringName) -> float:
	var value: Variant = filter_material.get_shader_parameter(parameter)
	if value == null and filter_material.shader != null:
		value = RenderingServer.shader_get_parameter_default(filter_material.shader.get_rid(), parameter)
	return float(value) if value != null else 0.0
