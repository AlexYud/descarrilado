extends Node
class_name PlayerInteractionController

@export var interaction_distance: float = 2.0

var player: CharacterBody3D = null
var interact_ray: RayCast3D = null
## The scene's own label of the prompt: no longer shown, it only keeps the text (the prompt is drawn by `prompt_view`).
var interaction_prompt: Label = null
## The prompt as the player sees it: a key cap and a word on a panel, like every other prompt of the game.
var prompt_view: InteractionPromptView = null

## The marks on the usable things and the dot in the middle (see `InteractionReticle`).
var reticle: InteractionReticle = null

## The key legend ("[E] Inspect") is shown over a usable thing only until the player has used one thing; after that the marks alone say
## what can be used (the inspect view keeps its own prompts).
var current_interactable: Interactable = null


func setup(player_node: CharacterBody3D) -> void:
	player = player_node
	interact_ray = player.get_node("Head/Camera3D/InteractRay") as RayCast3D
	interaction_prompt = player.get_node("InteractionUI/InteractionCenter/InteractionPrompt") as Label

	interaction_prompt.visible = false
	interaction_prompt.text = ""
	# White text over the flashlight's white circle cannot be read: the prompt sits on a panel (see `InteractionPromptView`).
	prompt_view = InteractionPromptView.new()
	player.get_node("InteractionUI").add_child(prompt_view)
	reticle = InteractionReticle.new()
	player.get_node("InteractionUI").add_child(reticle)
	reticle.setup(player, player.get_node("Head/Camera3D") as Camera3D, self)

	_setup_interact_ray()


func update_state(dialogue_frozen: bool, inventory_open: bool) -> void:
	if reticle != null:
		reticle.set_active(not dialogue_frozen and not inventory_open)

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
		var text: String = InputBindings.format_text(_with_key(tr(interactable.get_prompt_text())))
		interaction_prompt.text = text
		if prompt_view != null:
			if prompt_seen():
				prompt_view.hide_prompt()
			else:
				prompt_view.show_prompt(text)
	else:
		clear_prompt()


## Every prompt names the key ("[E] Inspect"): one that is written without it ("Pull lever 2 down", "Inspect") is given it here, so no
## prompt can lack the key, whatever wrote it.
func _with_key(text: String) -> String:
	if text.is_empty() or text.contains("{") or text.begins_with("["):
		return text

	return "[{interact}] " + text


## True once the player has used a thing for the first time (kept with the settings, for good).
func prompt_seen() -> bool:
	return GameSettings.interaction_prompt_seen


func try_interact(player_node: Node) -> void:
	if is_instance_valid(current_interactable):
		if not prompt_seen():
			GameSettings.set_interaction_prompt_seen(true)
			if prompt_view != null:
				prompt_view.hide_prompt()
		current_interactable.interact(player_node)


func clear_prompt() -> void:
	current_interactable = null

	if interaction_prompt != null:
		interaction_prompt.visible = false
		interaction_prompt.text = ""

	if prompt_view != null:
		prompt_view.hide_prompt()


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
