extends CanvasLayer

const QUALITY_LOW: int = 0
const QUALITY_MEDIUM: int = 1

@onready var horror_rect: ColorRect = $HorrorRect


func _ready() -> void:
	if not GameSettings.quality_preset_changed.is_connected(
		_on_quality_preset_changed
	):
		GameSettings.quality_preset_changed.connect(
			_on_quality_preset_changed
		)

	_apply_quality_preset(GameSettings.get_quality_preset())


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
