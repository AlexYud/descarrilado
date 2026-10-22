extends Node
class_name FocusBlurController

## The soft focus of a camera that has something to look at: what the player looks at
## (an item held up to inspect, or something they can interact with) stays sharp and
## what lies far behind it goes soft. With nothing in focus there is no blur at all
## and no cost. Uses the engine's depth of field on the player's camera; the player
## can turn it off in the options (`GameSettings.depth_of_field_enabled`).

## How strongly the world behind an inspected item is blurred, and from how far
## behind the item it starts to blur. **Off (0) by default:** the inspect view sits on a dark veil, so the blur
## showed nothing of the world, but the engine's depth of field smeared the far black into the item's edge and
## drew a jagged dark halo round every item held up. Raise it only with a background worth blurring (and
## check the edges).
@export_range(0.0, 1.0, 0.01) var inspect_amount: float = 0.0
@export var inspect_gap: float = 0.25
@export var inspect_transition: float = 1.2
## The same for something the player looks at in the world (far gentler: it is a
## hint of focus, not a lens).
@export_range(0.0, 1.0, 0.01) var interact_amount: float = 0.06
@export var interact_gap: float = 1.2
@export var interact_transition: float = 7.0
## Seconds for the focus to come in and to go out.
@export var focus_in_seconds: float = 0.25
@export var focus_out_seconds: float = 0.45

var player: CharacterBody3D = null
var camera: Camera3D = null
var interaction_controller: PlayerInteractionController = null
var inspect_controller: PlayerInspectController = null

var attributes: CameraAttributesPractical = null

## 0 (nothing in focus) to 1 (the full effect of the current profile).
var _weight: float = 0.0
var _amount: float = 0.0
var _far_distance: float = 10.0
var _transition: float = 5.0


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	camera = player.get_node("Head/Camera3D") as Camera3D
	interaction_controller = player.get_node_or_null("InteractionController") as PlayerInteractionController
	inspect_controller = player.get_node_or_null("InspectController") as PlayerInspectController

	attributes = CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = false
	attributes.dof_blur_near_enabled = false
	camera.attributes = attributes

	set_process(true)


func _process(delta: float) -> void:
	if camera == null or attributes == null:
		return

	var wanted: float = 0.0
	if GameSettings.get_depth_of_field_enabled():
		wanted = _read_focus()

	var seconds: float = focus_in_seconds if wanted > _weight else focus_out_seconds
	_weight = move_toward(_weight, wanted, delta / maxf(seconds, 0.01))

	var active: bool = _weight > 0.002
	if attributes.dof_blur_far_enabled != active:
		attributes.dof_blur_far_enabled = active

	if active:
		attributes.dof_blur_far_distance = _far_distance
		attributes.dof_blur_far_transition = _transition
		attributes.dof_blur_amount = _amount * _weight


## What is in focus right now: sets the profile and returns how much (0 if nothing).
func _read_focus() -> float:
	if inspect_controller != null and inspect_controller.is_open():
		# An item held up: nothing behind it is blurred unless `inspect_amount` says so (see above), and the
		# world focus below does not apply while the view is up.
		if inspect_amount <= 0.0:
			return 0.0

		var depth: float = inspect_controller.get_focus_distance()
		_far_distance = depth + inspect_controller.get_item_radius() + inspect_gap
		_transition = inspect_transition
		_amount = inspect_amount
		return 1.0

	if (
		interaction_controller != null
		and is_instance_valid(interaction_controller.current_interactable)
		and interaction_controller.interact_ray != null
		and interaction_controller.interact_ray.is_colliding()
	):
		var hit: Vector3 = interaction_controller.interact_ray.get_collision_point()
		_far_distance = camera.global_position.distance_to(hit) + interact_gap
		_transition = interact_transition
		_amount = interact_amount
		return 1.0

	return 0.0


## The amount of focus right now (for tests).
func get_weight() -> float:
	return _weight
