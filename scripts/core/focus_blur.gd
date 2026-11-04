class_name FocusBlur
extends RefCounted

## A shallow depth of field for the shots whose subject is close to the lens (a cassette recorder, a postcard, an item held up to be looked at): the subject is
## sharp and everything behind it is blurred, as a camera focused on it would have it. Done with the camera's own `CameraAttributesPractical` (far blur only),
## so it costs nothing where it is not used. It follows the player's own setting (`GameSettings.get_depth_of_field_enabled`).

## How far behind the subject the sharp part ends, how long the blur takes to come to its full strength, and its strength (the engine's `dof_blur_amount`).
const DEPTH: float = 0.3
const FALLOFF: float = 1.6
const AMOUNT: float = 0.16


## The engine's depth of field at its default quality leaves stacked dark ghosts along the edges of a bright subject on a dark picture: the high quality with jitter does
## not (a global setting of the renderer, made once).
static func use_clean_quality() -> void:
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, true)


## Focuses `camera` on something `distance` metres from it. `strength` (0 to 1) fades the whole effect (0 is off, with no blur at all), for a subject that is
## sometimes near and sometimes far.
static func focus_on(camera: Camera3D, distance: float, strength: float = 1.0, amount: float = AMOUNT, depth: float = DEPTH, falloff: float = FALLOFF) -> void:
	if camera == null or not is_instance_valid(camera):
		return

	var attributes: CameraAttributesPractical = camera.attributes as CameraAttributesPractical
	if attributes == null:
		attributes = CameraAttributesPractical.new()
		camera.attributes = attributes

	use_clean_quality()
	var on: bool = GameSettings.get_depth_of_field_enabled() and strength > 0.01
	attributes.dof_blur_far_enabled = on
	if on:
		attributes.dof_blur_far_distance = maxf(distance, 0.05) + depth
		attributes.dof_blur_far_transition = falloff
		attributes.dof_blur_amount = amount * clampf(strength, 0.0, 1.0)


## The effect off (the camera is left with whatever else its attributes hold).
static func clear(camera: Camera3D) -> void:
	if camera == null or not is_instance_valid(camera):
		return

	var attributes: CameraAttributesPractical = camera.attributes as CameraAttributesPractical
	if attributes != null:
		attributes.dof_blur_far_enabled = false


## How much of the effect a subject `distance` metres from the lens gets: all of it up close (`near`), none from `far` on.
static func closeness(distance: float, near: float = 0.55, far: float = 1.3) -> float:
	return 1.0 - smoothstep(near, far, distance)
