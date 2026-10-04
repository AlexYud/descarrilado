extends Interactable
class_name PhotoAlbum

## A photo album with empty spaces (AlbumSlot children). Interacting opens a
## close-up (AlbumView) where the player drags photographs from their hands
## onto the spaces, in any order, and takes them back out again.
##
## Nothing tells the player whether a single placement is right. Only when
## every space holds its own photograph, which is the chronological order,
## does the album lock and `completed` fire.

signal arrangement_changed
## Every slot holds its own photograph. Fires once; the album is then locked.
signal completed
## The close-up opened or closed.
signal opened
signal closed
## The player took the keepsake photograph out of the finished album.
signal keepsake_taken

## Every photograph that can go in this album (Collectible scenes).
@export var photo_scenes: Array[PackedScene] = []

## The one photograph the player may take from the finished album, once the
## level enables it (`keepsake_enabled`).
@export var keepsake_item_id: String = "photo_recent"
@export var take_prompt_text: String = "PROMPT_TAKE_PHOTO"

const STATE_SECTION: StringName = &"puzzles"
const KEY_ARRANGEMENT: StringName = &"album_arrangement"
const KEY_COMPLETE: StringName = &"album_complete"

var slots: Array[AlbumSlot] = []

## Item id held by each slot, "" when empty. Same order as `slots`.
var arrangement: Array[String] = []

## Once complete the album can still be opened to look, but not changed.
var locked: bool = false

## The level can switch the album off while something else is happening.
var interaction_enabled: bool = true

## While true and the keepsake is still in the album, interacting takes it
## instead of opening the close-up. Set by the level.
var keepsake_enabled: bool = false

var view: AlbumView = null

## item_id -> {scene, name, description, card_color, card_label, card_size}
var _photo_info: Dictionary = {}


func _ready() -> void:
	for node: Node in find_children("*", "AlbumSlot", true, false):
		slots.append(node as AlbumSlot)
		arrangement.append("")

	_read_photo_info()
	_restore_state()
	_refresh_slots()

	view = AlbumView.new()
	add_child(view)
	view.setup(self)


func can_interact(_player: Node) -> bool:
	return interaction_enabled


func get_prompt_text() -> String:
	return take_prompt_text if _keepsake_available() else prompt_text


func interact(player: Node) -> void:
	if _keepsake_available():
		_take_keepsake(player)
		return

	view.open(player)


func _keepsake_available() -> bool:
	return keepsake_enabled and arrangement.has(keepsake_item_id)


## Takes the keepsake out of the album, bypassing the lock, into the player's hands.
func _take_keepsake(player: Node) -> void:
	if not bool(player.call("has_inventory_space")):
		DialogueManager.show_timed("ALBUM_NO_ROOM", 2.0)
		return

	var slot_index: int = arrangement.find(keepsake_item_id)
	arrangement[slot_index] = ""
	_refresh_slots()
	SaveManager.set_state_value(
		STATE_SECTION,
		KEY_ARRANGEMENT,
		arrangement.duplicate()
	)

	give_back(player, keepsake_item_id)
	keepsake_enabled = false
	arrangement_changed.emit()
	keepsake_taken.emit()


# ============================================================
# ARRANGEMENT
# ============================================================

func get_photo_ids() -> Array[String]:
	var ids: Array[String] = []
	for item_id: Variant in _photo_info:
		ids.append(str(item_id))

	return ids


func get_photo_info(item_id: String) -> Dictionary:
	return _photo_info.get(item_id, {})


func find_slot_of(item_id: String) -> int:
	return arrangement.find(item_id)


## Puts a photograph from the player's hands into a slot. Returns the id of the
## photograph that was in that slot, which goes back to the player ("" if none).
func place_from_hand(slot_index: int, item_id: String) -> String:
	if locked or slot_index < 0 or slot_index >= slots.size():
		return item_id

	var displaced: String = arrangement[slot_index]
	arrangement[slot_index] = item_id
	_changed()
	return displaced


## Moves a photograph already in the album to another slot; if that slot is
## occupied the two swap places.
func move_between(from_index: int, to_index: int) -> void:
	if locked or from_index == to_index:
		return

	if (
		from_index < 0 or from_index >= slots.size()
		or to_index < 0 or to_index >= slots.size()
	):
		return

	var moved: String = arrangement[from_index]
	arrangement[from_index] = arrangement[to_index]
	arrangement[to_index] = moved
	_changed()


## Takes a photograph out of the album. Returns its id ("" if the slot was empty).
func take_out(slot_index: int) -> String:
	if locked or slot_index < 0 or slot_index >= slots.size():
		return ""

	var item_id: String = arrangement[slot_index]
	arrangement[slot_index] = ""
	_changed()
	return item_id


func is_correct() -> bool:
	if slots.is_empty():
		return false

	for i: int in slots.size():
		if arrangement[i] != slots[i].correct_item_id:
			return false

	return true


## Gives a photograph back to the player's inventory. False if there is no room.
func give_back(player: Node, item_id: String) -> bool:
	var info: Dictionary = get_photo_info(item_id)
	if info.is_empty() or not player.has_method("add_item_to_inventory"):
		return false

	var scene: PackedScene = info["scene"] as PackedScene
	var photo: Node = scene.instantiate()
	var visual: Node3D = photo.get_node_or_null("Visual") as Node3D
	var template: Node3D = null
	if visual != null:
		template = visual.duplicate() as Node3D

	var added: bool = bool(player.call(
		"add_item_to_inventory",
		item_id,
		str(info["name"]),
		str(info["description"]),
		template,
		scene.resource_path
	))

	if not added and template != null:
		template.free()

	photo.free()
	return added


# ============================================================
# INTERNALS
# ============================================================

func _changed() -> void:
	_refresh_slots()
	SaveManager.set_state_value(
		STATE_SECTION,
		KEY_ARRANGEMENT,
		arrangement.duplicate()
	)
	arrangement_changed.emit()

	if not locked and is_correct():
		locked = true
		SaveManager.set_state_value(STATE_SECTION, KEY_COMPLETE, true)
		completed.emit()


func _refresh_slots() -> void:
	for i: int in slots.size():
		var item_id: String = arrangement[i]
		if item_id.is_empty():
			slots[i].show_photo(null, Vector2.ONE)
			continue

		var info: Dictionary = get_photo_info(item_id)
		var photo: Node = (info["scene"] as PackedScene).instantiate()
		var visual: Node3D = photo.get_node("Visual") as Node3D
		photo.remove_child(visual)
		photo.free()
		slots[i].show_photo(visual, info["card_size"] as Vector2)


func _restore_state() -> void:
	locked = bool(SaveManager.get_state_value(STATE_SECTION, KEY_COMPLETE, false))

	var saved: Variant = SaveManager.get_state_value(
		STATE_SECTION,
		KEY_ARRANGEMENT,
		[]
	)
	if not saved is Array:
		return

	var saved_list: Array = saved as Array
	for i: int in mini(saved_list.size(), slots.size()):
		var item_id: String = str(saved_list[i])
		if item_id.is_empty() or not _photo_info.has(item_id):
			continue

		arrangement[i] = item_id


## Reads each photograph scene once for what the album and its close-up need.
func _read_photo_info() -> void:
	for scene: PackedScene in photo_scenes:
		var photo: Node = scene.instantiate()
		var visual: Node3D = photo.get_node("Visual") as Node3D
		var item_id: String = str(photo.get("item_id"))

		_photo_info[item_id] = {
			"scene": scene,
			"name": str(photo.get("item_name")),
			"description": str(photo.get("item_description")),
			"card_color": visual.get_meta("card_color", Color(0.4, 0.4, 0.4)),
			"card_label": str(visual.get_meta("card_label", "")),
			"card_size": visual.get_meta("card_size", Vector2(0.12, 0.12)),
		}
		photo.free()
