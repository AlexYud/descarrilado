extends CanvasLayer
class_name MotionBlurController

## Motion blur for the player's view: a screen shader (the engine has none) that
## smears the picture along the way the camera turned in the last frame, like a
## camera's shutter, so a quick turn feels fast instead of stuttering. It sits above
## the 3D world and below the UI, so only the world is blurred. Off (and not even
## drawn) when the player turns it off in the options, while an item is inspected, and
## when the view jumps (a cut).

const SHADER: Shader = preload("res://assets/shaders/motion_blur.gdshader")

## How long the shutter is open, in seconds (1/120 is the classic half-frame at 60).
@export var shutter_seconds: float = 1.0 / 120.0
## The most the picture is smeared, as a fraction of the screen.
@export var max_blur: float = 0.05
## Turning slower than this (screen fractions per second) is not blurred at all.
@export var dead_zone: float = 0.12
## Outward blur per metre per second of forward speed.
@export var radial_per_speed: float = 0.0018
@export var max_radial: float = 0.02
## A turn bigger than this much of the screen in one frame is a cut, not a turn.
@export var cut_threshold: float = 0.6

var player: CharacterBody3D = null
var inspect_controller: PlayerInspectController = null

var _rect: ColorRect = null
var _material: ShaderMaterial = null
var _previous_forward: Vector3 = Vector3.ZERO
var _previous_camera: Camera3D = null
var _smoothed: Vector2 = Vector2.ZERO


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	inspect_controller = player.get_node_or_null("InspectController") as PlayerInspectController

	# Above the 3D world, below the filter and every piece of UI.
	layer = -1

	_material = ShaderMaterial.new()
	_material.shader = SHADER

	_rect = ColorRect.new()
	_rect.name = "MotionBlurRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)

	visible = false
	set_process(true)


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var enabled: bool = (
		GameSettings.get_motion_blur_enabled()
		and camera != null
		and delta > 0.0
		and not (inspect_controller != null and inspect_controller.is_open())
	)

	if not enabled:
		visible = false
		_previous_camera = null
		_smoothed = Vector2.ZERO
		return

	var forward: Vector3 = -camera.global_basis.z
	var shift: Vector2 = Vector2.ZERO

	if _previous_camera == camera:
		shift = _screen_shift(camera, _previous_forward)
		if shift.length() > cut_threshold:
			shift = Vector2.ZERO

	_previous_camera = camera
	_previous_forward = forward

	# Screen fractions per second, minus the slow turns that should stay sharp.
	var speed: Vector2 = shift / delta
	var magnitude: float = maxf(speed.length() - dead_zone, 0.0)
	var wanted: Vector2 = Vector2.ZERO
	if speed.length() > 0.0001:
		wanted = speed.normalized() * magnitude * shutter_seconds

	_smoothed = _smoothed.lerp(wanted, 1.0 - exp(-24.0 * delta))
	var blur: Vector2 = _smoothed.limit_length(max_blur)

	var radial: float = 0.0
	if player != null:
		var forward_speed: float = maxf(player.velocity.dot(forward), 0.0)
		radial = minf(forward_speed * radial_per_speed, max_radial)

	var needed: bool = blur.length() > 0.0004 or radial > 0.0004
	visible = needed
	if needed:
		_material.set_shader_parameter("blur_vector", blur)
		_material.set_shader_parameter("radial_strength", radial)


## Where the camera's previous direction now appears, relative to the middle of the
## screen, in screen fractions (so a turn to the right moves it to the left).
func _screen_shift(camera: Camera3D, previous_forward: Vector3) -> Vector2:
	var local: Vector3 = camera.global_basis.inverse() * previous_forward
	if local.z >= -0.001:
		return Vector2.ZERO

	var half_height: float = tan(deg_to_rad(camera.fov * 0.5))
	var size: Vector2 = get_viewport().get_visible_rect().size
	var half_width: float = half_height * size.x / maxf(size.y, 1.0)

	var ndc: Vector2 = Vector2(
		local.x / -local.z / half_width,
		local.y / -local.z / half_height
	)
	# Normalised device coordinates to screen fractions (y points down on screen).
	return Vector2(ndc.x * 0.5, -ndc.y * 0.5)
