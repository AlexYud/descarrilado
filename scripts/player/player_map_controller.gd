extends Node
class_name PlayerMapController

## The player's map of the forest: not an item of the inventory but a thing they carry and look at with a key of its own ("M" by default,
## the `map` action, rebindable in the Controls settings), as the flashlight is a tool with its own key. The player gets it from the trail
## map sign (`PinnedCollectible`); it is remembered in the saved game (`collectibles/forest_map`, the same flag that keeps the board bare).
## Looking at it is the inspect view of the map's model (`forest_map.tscn`): it comes folded and opens out, and folds again when it is put
## away; the first time, straight after it is taken, it is shown open (as it hung on the board) and folds only when it is closed.

signal map_given
signal map_opened
signal map_closed

const ITEM_ID: String = "forest_map"
const SCENE_PATH: String = "res://scenes/objects/forest_map.tscn"
const STATE_SECTION: StringName = &"collectibles"

## True while the map is the thing being looked at.
var is_open: bool = false
## True when the player asked for it (the key, or by script from nowhere), not when it was shown to them as they took it: only the first
## is the lesson of the key learned.
var opened_by_player: bool = false

var _player: CharacterBody3D = null
var _has_map: bool = false
var _template: Node3D = null


func setup(player: CharacterBody3D) -> void:
	_player = player
	_has_map = SaveManager.has_active_game() and bool(SaveManager.get_state_value(STATE_SECTION, StringName(ITEM_ID), false))

	var inspect: PlayerInspectController = player.get("inspect_controller") as PlayerInspectController
	if inspect != null:
		inspect.inspect_closed.connect(_on_inspect_closed)


func has_map() -> bool:
	return _has_map


## The player has the map from now on.
func give_map() -> void:
	if _has_map:
		return

	_has_map = true
	if SaveManager.has_active_game():
		SaveManager.set_state_value(STATE_SECTION, StringName(ITEM_ID), true)

	map_given.emit()


## True when pressing the key would open the map: they have it, and nothing else holds their attention.
func can_open() -> bool:
	if not _has_map or is_open or _player == null:
		return false

	if bool(_player.get("cutscene_frozen")) or bool(_player.get("dialogue_frozen")) or bool(_player.get("modal_ui_open")) or bool(_player.get("view_locked")):
		return false

	var inspect: PlayerInspectController = _player.get("inspect_controller") as PlayerInspectController
	if inspect != null and inspect.is_open():
		return false

	var inventory: Object = _player.get("inventory_ui_controller") as Object
	return inventory == null or not bool(inventory.call("is_inventory_open"))


## Looks at the map. `start_transform` is where it flies in from (the hands, just after it is taken; otherwise it comes from the pocket);
## `held_open` shows it open straight away instead of folded and then opening out.
func open(start_transform: Variant = null, held_open: bool = false) -> bool:
	if not _has_map or _player == null:
		return false

	var inspect: PlayerInspectController = _player.get("inspect_controller") as PlayerInspectController
	if inspect == null or _template_or_build() == null:
		return false

	var slot_data: Dictionary = {
		"id": ITEM_ID,
		"name": "ITEM_FOREST_MAP_NAME",
		"description": "ITEM_FOREST_MAP_DESCRIPTION",
		"inspect_visual_template": _template,
	}

	var interaction: PlayerInteractionController = _player.get("interaction_controller") as PlayerInteractionController
	if interaction != null:
		interaction.clear_prompt()

	# The map is held in the hands: the view is one the player walks with (nothing holds them, the mouse stays captured), and the
	# inventory panel is not involved.
	var opened: bool = inspect.open_inventory(slot_data, start_transform, held_open, true)
	if not opened:
		return false

	is_open = true
	opened_by_player = start_transform == null
	map_opened.emit()
	return true


## The map key while the map is open puts it away (the view's own back key does too).
func close() -> void:
	if not is_open:
		return

	var inspect: PlayerInspectController = _player.get("inspect_controller") as PlayerInspectController
	if inspect != null:
		inspect.close(false)


## The map's model, built from its scene the way the inventory builds the model of an item, once.
func _template_or_build() -> Node3D:
	if _template != null and is_instance_valid(_template):
		return _template

	if not ResourceLoader.exists(SCENE_PATH, "PackedScene"):
		return null

	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		return null

	var root: Node = scene.instantiate()
	var source: Node3D = root.get_node_or_null("Visual") as Node3D
	if source != null:
		# A model built in code is built here, as this scene is never put in the tree.
		var prop: ProceduralProp = source as ProceduralProp
		if prop != null:
			prop.build_now()

		_template = source.duplicate() as Node3D

	root.free()
	return _template


func _on_inspect_closed(inspect_id: String) -> void:
	if is_open and inspect_id == ITEM_ID:
		is_open = false
		map_closed.emit()


func _exit_tree() -> void:
	if _template != null and is_instance_valid(_template):
		_template.free()
		_template = null
