extends CanvasLayer

const QUALITY_LOW: int = 0
const QUALITY_MEDIUM: int = 1

## The values `pulse_unease` pushes the picture towards at full strength.
const UNEASE_PEAK: Dictionary = {
	&"chroma_separation_pixels": 5.0,
	&"chroma_noise_strength": 0.07,
	&"grain_strength": 0.1,
	&"lens_distortion": 0.05,
	&"vhs_wobble_amount": 0.007,
	&"vhs_vertical_twitch": 0.006,
}

## While the player looks at an item up close (the inspect view) the glare is faded out: the item is lit by the
## inspect light a few centimetres away, and the bloom and the push toward white would burn its details out (a
## label, an engraving). It fades back in when the view closes.
const GLARE_PARAMETERS: Array[StringName] = [&"bloom_strength", &"highlight_gain"]
const GLARE_FADE_SECONDS: float = 0.25

@onready var horror_rect: ColorRect = $HorrorRect

## 0 for the usual picture, 1 while an item is inspected (the glare is gone).
var inspect_amount: float = 0.0

var _glare_base: Dictionary = {}
var _player: Node = null
var _applied_amount: float = -1.0


func _ready() -> void:
	if not GameSettings.quality_preset_changed.is_connected(
		_on_quality_preset_changed
	):
		GameSettings.quality_preset_changed.connect(
			_on_quality_preset_changed
		)

	_apply_quality_preset(GameSettings.get_quality_preset())

	var filter_material: ShaderMaterial = horror_rect.material as ShaderMaterial
	if filter_material != null:
		for parameter: StringName in GLARE_PARAMETERS:
			_glare_base[parameter] = _read_parameter(filter_material, parameter)


func _process(delta: float) -> void:
	var target: float = 1.0 if _is_inspecting() else 0.0
	inspect_amount = move_toward(inspect_amount, target, delta / GLARE_FADE_SECONDS)
	if is_equal_approx(inspect_amount, _applied_amount):
		return

	_applied_amount = inspect_amount
	var filter_material: ShaderMaterial = horror_rect.material as ShaderMaterial
	if filter_material == null:
		return

	for parameter: StringName in GLARE_PARAMETERS:
		filter_material.set_shader_parameter(parameter, float(_glare_base.get(parameter, 0.0)) * (1.0 - inspect_amount))


## True while the player has an item held up.
func _is_inspecting() -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player")

	if _player == null:
		return false

	var inspect: Variant = _player.get("inspect_controller")
	return inspect != null and bool(inspect.call("is_open"))


func _exit_tree() -> void:
	if GameSettings.quality_preset_changed.is_connected(
		_on_quality_preset_changed
	):
		GameSettings.quality_preset_changed.disconnect(
			_on_quality_preset_changed
		)


func _on_quality_preset_changed(preset: int) -> void:
	_apply_quality_preset(preset)


func _apply_quality_preset(preset: int) -> void:
	var filter_material: ShaderMaterial = (
		horror_rect.material as ShaderMaterial
	)
	if filter_material == null:
		push_warning(
			"HorrorFilter: HorrorRect requires a ShaderMaterial."
		)
		return

	match preset:
		QUALITY_LOW:
			# Procedural grain and scanlines remain, but only one screen
			# sample is used so the style stays affordable on Low.
			filter_material.set_shader_parameter(
				"screen_sample_quality",
				0.0
			)
		QUALITY_MEDIUM:
			# Keep the chroma separation, omit the four soft-focus samples.
			filter_material.set_shader_parameter(
				"screen_sample_quality",
				0.5
			)
		_:
			filter_material.set_shader_parameter(
				"screen_sample_quality",
				1.0
			)


## 0 is the usual look; 1 takes the grain, noise and lifted blacks out, so black is truly black (see the shader's `darkness`).
func set_darkness(amount: float) -> void:
	var filter_material: ShaderMaterial = horror_rect.material as ShaderMaterial
	if filter_material != null:
		filter_material.set_shader_parameter("darkness", clampf(amount, 0.0, 1.0))


## A brief spike of unease: the picture smears (colour fringes, a little lens warp, heavier grain, a
## tighter vignette) as the beam finds something it should not, then settles. `amount` is 0..1,
## `seconds` how long it lasts. The fringes shake while it lasts instead of rising smoothly.
func pulse_unease(amount: float, seconds: float) -> void:
	var filter_material: ShaderMaterial = horror_rect.material as ShaderMaterial
	if filter_material == null:
		return

	var base: Dictionary = {}
	for parameter: StringName in UNEASE_PEAK:
		base[parameter] = _read_parameter(filter_material, parameter)

	var tween: Tween = create_tween()
	tween.tween_method(
		func(progress: float) -> void:
			# Up fast, down slowly, with a shake riding on it.
			var envelope: float = clampf(progress / 0.15, 0.0, 1.0) * (1.0 - smoothstep(0.55, 1.0, progress))
			var shake: float = 0.75 + 0.25 * sin(progress * 90.0)
			for parameter: StringName in UNEASE_PEAK:
				var peak: float = UNEASE_PEAK[parameter]
				filter_material.set_shader_parameter(
					parameter,
					lerpf(base[parameter], peak, envelope * amount * shake)
				),
		0.0, 1.0, seconds
	)
	await tween.finished
	for parameter: StringName in UNEASE_PEAK:
		filter_material.set_shader_parameter(parameter, base[parameter])


## What a shader parameter is now (its own default when the material never set it).
func _read_parameter(filter_material: ShaderMaterial, parameter: StringName) -> float:
	var value: Variant = filter_material.get_shader_parameter(parameter)
	if value == null and filter_material.shader != null:
		value = RenderingServer.shader_get_parameter_default(filter_material.shader.get_rid(), parameter)

	return float(value) if value != null else 0.0
