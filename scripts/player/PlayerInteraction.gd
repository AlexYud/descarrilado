extends Node
class_name PlayerInteractionController

@export var interaction_distance: float = 1.0

var player: CharacterBody3D = null
var interact_ray: RayCast3D = null
var interaction_prompt: Label = null

var current_interactable: Interactable = null


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	interact_ray = player.get_node("Head/Camera3D/InteractRay") as RayCast3D
	interaction_prompt = player.get_node("InteractionUI/InteractionCenter/InteractionPrompt") as Label

	interaction_prompt.visible = false
	interaction_prompt.text = ""

	_setup_interact_ray()


func update_state(dialogue_frozen: bool, inventory_open: bool) -> void:
	if dialogue_frozen or inventory_open:
		clear_prompt()
		return

	interact_ray.force_raycast_update()

	if not interact_ray.is_colliding():
		clear_prompt()
		return

	var collider_obj: Object = interact_ray.get_collider()
	var collider_node: Node = collider_obj as Node

	if collider_node == null:
		clear_prompt()
		return

	var interactable: Interactable = _find_interactable_from_node(collider_node)

	if interactable != null and interactable.can_interact(player):
		current_interactable = interactable
		interaction_prompt.text = interactable.get_prompt_text()
		interaction_prompt.visible = true
	else:
		clear_prompt()


func try_interact(player_node: Node) -> void:
	if is_instance_valid(current_interactable):
		current_interactable.interact(player_node)


func clear_prompt() -> void:
	current_interactable = null

	if interaction_prompt != null:
		interaction_prompt.visible = false
		interaction_prompt.text = ""


func _setup_interact_ray() -> void:
	interact_ray.enabled = true
	interact_ray.collide_with_areas = true
	interact_ray.collide_with_bodies = true
	interact_ray.target_position = Vector3(0.0, 0.0, -interaction_distance)

	_add_interact_ray_exceptions(player)


func _add_interact_ray_exceptions(node: Node) -> void:
	var collision_object: CollisionObject3D = node as CollisionObject3D
	if collision_object != null:
		interact_ray.add_exception(collision_object)

	for child in node.get_children():
		_add_interact_ray_exceptions(child)


func _find_interactable_from_node(node: Node) -> Interactable:
	var current: Node = node

	while current != null:
		if current is Interactable:
			return current as Interactable
		current = current.get_parent()

	return null
