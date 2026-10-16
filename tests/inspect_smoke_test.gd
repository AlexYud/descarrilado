extends Node

## The item inspection: documents are read (shown flat, tilting a little, turned over
## with a key), other items are turned freely about the camera's axes around their
## own middle, with inertia, a flip and a reset; each item comes to a comfortable
## size; its name and description are on screen in the player's language, and the
## hint names the player's keys. Run it as a scene; it quits by itself with a
## non-zero exit code on failure.

const RECIPE: String = "res://scenes/objects/unfinished_house/kitchen_recipe.tscn"
const KEY: String = "res://scenes/objects/waiting_shed/carved_whistle.tscn"

var test_failed: bool = false
var player: CharacterBody3D = null
var inspect: PlayerInspectController = null


func _ready() -> void:
	# A screen like the game's own (an automated run has none).
	get_tree().root.size = Vector2i(1280, 720)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, 1.05, 0.0)
	await _wait(0.6)
	inspect = player.inspect_controller

	# The art of the documents is in Portuguese: in that language they are shown as made.
	GameSettings.set_text_locale("pt_BR", false)
	await _check_reading()
	await _check_examining()
	await _check_readable_overlay()
	await _check_readable_spots()
	await _check_action_row()
	await _check_zoom_limits()
	await _check_inventory_list()
	GameSettings.set_text_locale("en", false)

	print("INSPECT_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _spawn(path: String, at: Vector3) -> Inspectable:
	var item: Node3D = (load(path) as PackedScene).instantiate()
	add_child(item)
	item.global_position = at
	await get_tree().process_frame
	return item as Inspectable


func _open(item: Inspectable) -> void:
	player.start_world_inspect(item)
	await _until(func() -> bool: return inspect.state == PlayerInspectController.InspectState.VIEWING, 4.0)
	await _wait(0.1)


func _close() -> void:
	inspect.close(false)
	await _until(func() -> bool: return not inspect.is_open(), 4.0)


func _drag(dx: float, dy: float) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	inspect.handle_input(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(dx, dy)
	inspect.handle_input(motion)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	inspect.handle_input(release)


## Where the item's own front (+Z) points, in the camera's space.
func _front() -> Vector3:
	return inspect._orientation_local * Vector3.BACK


func _middle_error() -> float:
	var middle: Vector3 = inspect.current_visual_copy.global_transform * inspect._center_local
	var expected: Vector3 = (
		inspect.inspect_anchor.global_position
		+ inspect._steady_basis() * Vector3(inspect._shift_current.x, inspect._shift_current.y, 0.0)
	)
	return middle.distance_to(expected)


func _check_reading() -> void:
	var recipe: Inspectable = await _spawn(RECIPE, Vector3(0.0, 1.0, -3.0))
	await _open(recipe)

	_expect(inspect.inspect_mode == &"read", "a document is read")
	_expect(inspect.title_label.text == tr("ITEM_KITCHEN_RECIPE_NAME"), "the title is on screen, translated (%s)" % inspect.title_label.text)
	_expect(
		inspect.controls_label.text.contains("R") and not inspect.controls_label.text.contains("{"),
		"the hint names the keys (%s)" % inspect.controls_label.text
	)
	_expect(inspect.get_hint_text() == inspect.controls_label.text, "and can be asked for")
	_expect(inspect.close_hint.visible and inspect.close_hint._text_label.text == tr("INSPECT_VERB_CLOSE"), "the way back is on screen")

	# A paper fills a good part of the view: the first distance fits it.
	var largest: float = inspect._local_bounds(inspect.current_visual_copy).size.length()
	_expect(inspect.current_inspect_distance > 0.1 and inspect.current_inspect_distance < 0.6, "it comes to a sensible distance (%.2f)" % inspect.current_inspect_distance)
	_expect(largest > 0.0, "it has a size")
	_expect(_middle_error() < 0.001, "its middle is at the anchor")
	_check_vertical_crop("a document as made")

	# Dragging only tilts, within a limit, and it springs back.
	_drag(2000.0, 0.0)
	await _wait(0.1)
	_expect(absf(inspect._tilt.x) <= deg_to_rad(inspect.read_tilt_limit_degrees) + 0.001, "a paper only tilts so far")
	_expect(_front().z > 0.85, "and still faces the viewer")
	await _wait(1.2)
	_expect(inspect._tilt.length() < 0.01, "and it springs back when let go")

	# Turning it over shows the back; again shows the front.
	inspect._flip()
	await _wait(1.0)
	_expect(_front().z < -0.95, "a key turns the paper over")
	_expect(_middle_error() < 0.001, "about its middle")
	inspect._flip()
	await _wait(1.0)
	_expect(_front().z > 0.95, "and back again")

	# Zoom stays within limits.
	for i in 40:
		var wheel: InputEventMouseButton = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		inspect.handle_input(wheel)
	_expect(is_equal_approx(inspect.current_inspect_distance, inspect._zoom_min), "zooming in stops at the limit")
	for i in 80:
		var wheel_out: InputEventMouseButton = InputEventMouseButton.new()
		wheel_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel_out.pressed = true
		inspect.handle_input(wheel_out)
	_expect(is_equal_approx(inspect.current_inspect_distance, inspect._zoom_max), "and so does zooming out")

	inspect._reset_view()
	await _wait(1.5)
	_expect(absf(inspect.current_inspect_distance - inspect._fit_distance) < 0.005, "reset brings back the first distance")

	await _close()
	_expect(inspect.title_label.text == "", "the name goes with the item")
	recipe.queue_free()


func _check_examining() -> void:
	var key: Inspectable = await _spawn(KEY, Vector3(0.0, 1.0, -3.0))
	await _open(key)

	_expect(inspect.inspect_mode == &"examine", "an object is examined")
	_expect(inspect.title_label.text == tr("ITEM_WOODEN_WHISTLE_NAME"), "an object shows its name and nothing else")
	_check_vertical_crop("an object")

	# The same drag turns it the same way whatever it has been through.
	_drag(60.0, 0.0)
	var after_first: Vector3 = _front()
	_expect(after_first.x > 0.2, "dragging right turns the front to the right (%.2f)" % after_first.x)
	_drag(0.0, 60.0)
	var after_second: Vector3 = _front()
	_expect(after_second.y < after_first.y - 0.1, "dragging down turns the front down")
	_expect(_middle_error() < 0.001, "it turns about its own middle")

	# A flick keeps turning, then slows down.
	inspect._reset_view()
	await _wait(1.5)
	inspect._angular_velocity = Vector2(6.0, 0.0)
	await _wait(0.15)
	var early: float = absf(_front().x)
	_expect(early > 0.1, "a flick keeps the item turning")
	await _wait(2.5)
	_expect(inspect._angular_velocity.length() < 0.05, "and it slows to a stop")

	# Turning it all the way round, in two directions, never loses the middle.
	for i in 12:
		_drag(80.0, 40.0)
		if i % 4 == 0:
			_expect(_middle_error() < 0.001, "the middle stays put (%d)" % i)

	# Flip, then reset.
	inspect._reset_view()
	await _wait(1.5)
	_expect(_front().z > 0.99, "reset puts it back")
	inspect._flip()
	await _wait(1.0)
	_expect(_front().z < -0.95, "flip shows the back")

	# A tall object and a small one come to a similar size on screen.
	var near: float = inspect.current_inspect_distance
	await _close()
	var lantern: Inspectable = await _spawn("res://scenes/objects/waiting_shed/railway_lantern.tscn", Vector3(0.0, 1.0, -3.0))
	await _open(lantern)
	var far: float = inspect.current_inspect_distance
	_expect(far > near * 1.3, "a lantern is shown further away than a whistle (%.2f vs %.2f)" % [far, near])
	await _close()

	key.queue_free()
	lantern.queue_free()


func _until(condition: Callable, timeout_seconds: float) -> void:
	var waited: float = 0.0
	while not condition.call() and waited < timeout_seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


## The art of a document is made once, in Portuguese. A player of another language
## sees the same document with its writing as an overlay in their own language; a
## player of Portuguese sees the art as it is.
func _check_readable_overlay() -> void:
	GameSettings.set_text_locale("en", false)
	GameSettings.set_readable_text_mode(GameSettings.ReadableText.AUTO, false)

	var recipe: Inspectable = await _spawn(RECIPE, Vector3(0.0, 1.0, -3.0))
	await _wait(0.6)
	await _open(recipe)
	await _wait(0.8)

	_expect(inspect._readable_on, "in English the Portuguese art has its text offered")
	_expect(inspect.readables.is_document_offered(), "as a document text")
	_expect(inspect.read_hint.visible and inspect.read_hint._text_label.text == tr("INSPECT_VERB_READ"), "with a [E] Read button under it")
	_expect(inspect.rotate_hint.visible, "and a [R] Rotate button")
	var stacks: Array[Node] = inspect.current_visual_copy.find_children("*", "ParagraphStack", true, false)
	_expect(stacks.size() > 0 and not (stacks[0] as Node3D).visible, "the stand-in writing on the paper steps aside")
	var middle: Vector3 = inspect.current_visual_copy.global_transform * inspect._center_local
	var screen: Vector2 = inspect.camera.unproject_position(middle)
	var view: Vector2 = get_viewport().get_visible_rect().size
	_expect(absf(screen.x - view.x * 0.5) < view.x * 0.03, "the paper stays in the middle (x %.0f of %.0f)" % [screen.x, view.x])
	_expect(absf(screen.y - view.y * 0.47) < view.y * 0.04, "with the screen to itself (y %.0f of %.0f)" % [screen.y, view.y])
	_check_vertical_crop("with a text to read")

	# Reading it: a veil, the text centred in the column, back with the same key.
	inspect.handle_input(_press(KEY_E))
	await _wait(0.6)
	_expect(inspect.is_reading_text(), "the key opens the text")
	_expect(inspect.readables._body.text.contains("potato soup"), "in English")
	_expect(not inspect.readables._body.get_parsed_text().contains("[u]"), "(the markup is drawn, not shown)")
	_expect(inspect.readables._veil.visible and inspect.readables._veil.modulate.a > 0.9, "over a dark veil")
	var column: float = inspect.get_column_width()
	var text_rect: Rect2 = inspect.readables._text_box.get_global_rect()
	_expect(absf(text_rect.get_center().x - view.x * 0.5) < 2.0 and text_rect.size.x <= column + 2.0, "inside the column (%s)" % text_rect)
	_expect(text_rect.end.y < view.y * 0.9 and text_rect.position.y > 0.0, "and the screen (%s)" % text_rect)
	_expect(inspect.close_hint._text_label.text == tr("INSPECT_BACK"), "the way back says Back")
	inspect.handle_input(_press(KEY_E))
	await _wait(0.6)
	_expect(not inspect.is_reading_text() and inspect.is_open(), "the same key goes back to the item")
	_expect(inspect.close_hint._text_label.text == tr("INSPECT_VERB_CLOSE"), "which can be closed again")

	# Changing the language while looking changes what is offered, not the art.
	GameSettings.set_text_locale("pt_BR", false)
	await _wait(1.0)
	_expect(not inspect._readable_on, "in Portuguese the art is shown as it is")
	_expect(not inspect.readables._prompt.visible and not inspect.readables.is_document_offered(), "with nothing to read")
	_expect(not (stacks[0] as Node3D).visible == false, "and its writing back on the paper")

	# The player can ask for the text always, or never.
	GameSettings.set_readable_text_mode(GameSettings.ReadableText.ALWAYS, false)
	await _wait(0.8)
	_expect(inspect._readable_on and inspect.get_document_text_key() == "READABLE_RECIPE", "always: the text is offered, easy to read")
	GameSettings.set_text_locale("en", false)
	GameSettings.set_readable_text_mode(GameSettings.ReadableText.NEVER, false)
	await _wait(0.8)
	_expect(not inspect._readable_on, "never: no overlay in any language")
	GameSettings.set_readable_text_mode(GameSettings.ReadableText.AUTO, false)
	await _close()
	recipe.queue_free()

	# An object without writing needs no overlay in any language.
	var whistle: Inspectable = await _spawn(KEY, Vector3(0.0, 1.0, -3.0))
	await _open(whistle)
	_expect(not inspect._readable_on and not inspect.readables._prompt.visible, "an object with no writing has nothing to read")
	_expect(inspect.title_label.text == tr("ITEM_WOODEN_WHISTLE_NAME"), "but its name still follows the language")
	await _close()
	whistle.queue_free()


## Everything the player needs (the item, the writing, the hints, the buttons) must
## stay inside a vertical 9:16 crop of the middle of the screen: the game is shown
## in vertical videos too.
func _check_vertical_crop(what: String) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var crop_width: float = view.y * 9.0 / 16.0
	var crop: Rect2 = Rect2((view.x - crop_width) * 0.5, 0.0, crop_width, view.y).grow(2.0)

	_expect(crop.encloses(inspect.title_label.get_global_rect()), "%s: the name fits the vertical crop" % what)
	_expect(crop.encloses(inspect.close_hint.get_global_rect()), "%s: the way back fits the vertical crop" % what)
	_expect(crop.encloses(inspect.controls_label.get_global_rect()), "%s: the controls fit the vertical crop" % what)
	if inspect.readables._prompt.visible:
		_expect(crop.encloses(inspect.readables._prompt.get_global_rect()), "%s: the prompt fits the vertical crop" % what)

	var middle: Vector3 = inspect.current_visual_copy.global_transform * inspect._center_local
	var screen: Vector2 = inspect.camera.unproject_position(middle)
	_expect(crop.has_point(screen), "%s: the item is inside the vertical crop (%s)" % [what, screen])
	var half_height: float = absf(
		inspect.camera.unproject_position(middle + inspect.camera.global_basis.y * inspect._largest * 0.5).y - screen.y
	)
	_expect(screen.y + half_height < view.y * 0.86, "%s: and clear of the bottom row" % what)


func _press(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _action(name: String) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


## A clue engraved on the back of an item: nothing is written in the model. Turn the
## item so the spot faces the player and "[E] Read" is offered; reading shows the text
## as an overlay, pauses the turning, and Back returns to the item.
func _check_readable_spots() -> void:
	GameSettings.set_text_locale("en", false)
	var read_ids: Array[String] = []
	inspect.spot_read.connect(func(inspect_id: String, spot_id: StringName) -> void: read_ids.append("%s/%s" % [inspect_id, spot_id]))

	var whistle: Inspectable = await _spawn(KEY, Vector3(0.0, 1.0, -3.0))
	await _open(whistle)
	await _wait(0.4)

	var spots: Array[Node] = inspect.current_visual_copy.find_children("*", "ReadableSpot", true, false)
	_expect(spots.size() == 1, "the whistle has one readable spot")
	_expect(inspect.current_visual_copy.find_children("*", "Label3D", true, false).is_empty(), "and no words are in the model")
	_expect(inspect.readables.get_offered_spot() == null, "nothing is offered while its front shows")
	_expect(not inspect.readables._prompt.visible, "and there is no prompt")

	# Turning it over brings the spot round: after a moment the prompt appears.
	inspect._flip()
	await _wait(1.3)
	_expect(inspect.readables.get_offered_spot() == spots[0], "turned over, the spot is offered")
	_expect(inspect.readables._prompt.visible, "with a prompt")
	_expect(inspect.readables._prompt._key_label.text == "E" and inspect.readables._prompt._text_label.text == "Read", "naming the key (%s %s)" % [inspect.readables._prompt._key_label.text, inspect.readables._prompt._text_label.text])

	# Swung away again, it is taken back (with a margin, so it does not flicker).
	inspect._rotate_item(Vector2(1.3, 0.0))
	await _wait(0.6)
	_expect(inspect.readables.get_offered_spot() == null, "turned too far, the offer goes")
	inspect._rotate_item(Vector2(-1.3, 0.0))
	await _wait(0.8)
	_expect(inspect.readables.get_offered_spot() == spots[0], "and comes back")

	# Reading it.
	var before: Basis = inspect._orientation_local
	inspect.handle_input(_press(KEY_E))
	await _wait(1.2)
	_expect(inspect.is_reading_text(), "the key opens the text")
	_expect(inspect.readables._body.text == tr("WHISTLE_CLUE"), "with the translated clue (%s)" % inspect.readables._body.text)
	_expect(inspect.readables._veil.visible and inspect.readables._veil.modulate.a > 0.9, "the 3D view steps back")
	_expect(read_ids == ["whistle/whistle_clue"] or read_ids.size() == 1, "a reaction is told which spot was read (%s)" % str(read_ids))
	var spot: ReadableSpot = spots[0] as ReadableSpot
	_expect(spot.get_facing_dot(inspect.camera.global_basis.z) > 0.99, "the item has been brought to face the player")
	_expect(spot.global_basis.y.dot(inspect._steady_basis().y) > 0.97, "with the text upright")

	# Nothing turns it meanwhile.
	var held: Basis = inspect._orientation_local
	_drag(300.0, 120.0)
	inspect._angular_velocity = Vector2(5.0, 0.0)
	await _wait(0.4)
	_expect(inspect._orientation_local.is_equal_approx(held), "the item stays still while its text is open")

	# Back goes to the item, not out of it.
	var cancel: InputEventAction = _action("ui_cancel")
	player._input(cancel)
	await _wait(0.5)
	_expect(not inspect.is_reading_text(), "Back closes the text")
	_expect(inspect.is_open(), "and the item is still in the player's hands")
	_drag(60.0, 0.0)
	_expect(not inspect._orientation_local.is_equal_approx(held), "which they can turn again")

	# Back again leaves the item.
	player._input(_action("ui_cancel"))
	await _until(func() -> bool: return not inspect.is_open(), 4.0)
	_expect(not inspect.is_open(), "a second Back puts the item away")
	whistle.queue_free()


## The two choices under the item, in the same style as Close: "[E] Read" (only where there is plain
## writing, like a ticket's front and back) and "[R] Rotate", centred a row above the name and Close.
## A hidden detail (a whistle's engraving) gets neither: it is found by turning the item.
func _check_action_row() -> void:
	GameSettings.set_text_locale("en", false)
	var ticket: Inspectable = await _spawn("res://scenes/objects/train_ticket.tscn", Vector3(0.0, 1.0, -3.0))
	await _wait(0.6)
	await _open(ticket)
	await _wait(0.6)

	_expect(inspect.read_hint.visible and inspect.rotate_hint.visible, "a ticket shows Read and Rotate")
	_expect(inspect.read_hint._text_label.text == tr("INSPECT_VERB_READ") and inspect.rotate_hint._text_label.text == tr("INSPECT_VERB_ROTATE"), "worded Read and Rotate")
	_expect(inspect.read_hint._key_label.text == InputBindings.get_binding_label(&"interact", -1, true), "with the player's own keys")
	_expect(inspect.rotate_hint.position.y < inspect.title_label.position.y and inspect.rotate_hint.position.y < inspect.close_hint.position.y, "a row above the name and Close")
	var row_left: float = inspect.read_hint.position.x
	var row_right: float = inspect.rotate_hint.position.x + inspect.rotate_hint.size.x
	var view: Vector2 = get_viewport().get_visible_rect().size
	_expect(absf((row_left + row_right) * 0.5 - view.x * 0.5) < 3.0, "centred on the screen")
	_expect(not inspect.readables._prompt.visible, "and no prompt over the item itself")

	# The front, then (after turning it over) the back.
	inspect.handle_input(_press(KEY_E))
	await _wait(0.8)
	_expect(inspect.is_reading_text() and inspect.readables._body.text == tr("TICKET_FRONT_TEXT"), "Read shows the front of the ticket")
	_expect(not inspect.read_hint.visible and not inspect.rotate_hint.visible, "with no row while the text is open")
	inspect.handle_input(_press(KEY_E))
	await _wait(0.8)
	_expect(not inspect.is_reading_text() and inspect.read_hint.visible, "the row comes back with the item")
	inspect.handle_input(_action("inspect_flip"))
	await _wait(1.6)
	inspect.handle_input(_press(KEY_E))
	await _wait(0.8)
	_expect(inspect.readables._body.text == tr("TICKET_BACK_TEXT"), "after turning it over, Read shows the back")
	inspect.handle_input(_press(KEY_E))
	await _wait(0.8)
	await _close()
	ticket.queue_free()

	var whistle: Inspectable = await _spawn(KEY, Vector3(0.0, 1.0, -3.0))
	await _open(whistle)
	await _wait(0.4)
	_expect(not inspect.read_hint.visible and inspect.rotate_hint.visible, "a whistle, whose writing is a hidden detail, offers only Rotate")
	await _close()
	whistle.queue_free()


## The inventory is a list without a limit, and its single cursor follows the mouse.
func _check_inventory_list() -> void:
	var before: int = player.inventory_controller.get_slots().size()
	for i: int in 9:
		player.add_item_to_inventory("test_item_%d" % i, "ITEM_WOODEN_WHISTLE_NAME", "ITEM_WOODEN_WHISTLE_DESCRIPTION", null, "")
	_expect(player.has_inventory_space(), "the inventory never fills")
	_expect(player.inventory_controller.get_slots().size() == before + 9, "nine more items fit")
	player.inventory_ui_controller.show_inventory(player.inventory_controller.get_slots())
	await _wait(0.3)
	_expect(player.inventory_ui_controller.inventory_slot_buttons.size() == before + 9, "the list has a row for each")
	var rows: Array[Button] = player.inventory_ui_controller.inventory_slot_buttons
	_expect(rows[0].has_focus(), "the cursor starts on the first")
	rows[3].mouse_entered.emit()
	await _wait(0.1)
	_expect(rows[3].has_focus() and not rows[0].has_focus(), "the mouse moves the one cursor: never two arrows at once")
	_expect(player.inventory_ui_controller.description_label.text != "", "the item under the cursor is described")
	player.inventory_ui_controller.close()
	for i: int in 9:
		player.consume_inventory_item("test_item_%d" % i)


## How much of the screen's height the item's largest side fills at the current distance.
func _height_fraction() -> float:
	var half: float = tan(deg_to_rad(inspect.camera.fov * 0.5))
	return inspect._largest / (2.0 * inspect.current_inspect_distance * half)


## No item can be zoomed in until it covers the screen, and the key and the train ticket come up smaller
## than other items of their kind.
func _check_zoom_limits() -> void:
	var whistle: Inspectable = await _spawn(KEY, Vector3(0.0, 1.0, -3.0))
	await _open(whistle)
	await _wait(0.4)
	var first: float = _height_fraction()
	inspect._set_inspect_distance(0.0)
	var closest: float = _height_fraction()
	_expect(closest < 0.75, "an object zoomed all the way in still fits the screen (%.2f of its height)" % closest)
	_expect(closest > first * 1.2, "but it does come closer (%.2f from %.2f)" % [closest, first])
	await _close()
	whistle.queue_free()

	var ticket: Inspectable = await _spawn("res://scenes/objects/train_ticket.tscn", Vector3(0.0, 1.0, -3.0))
	await _open(ticket)
	await _wait(0.4)
	var ticket_first: float = _height_fraction()
	_expect(ticket_first < 0.5, "the train ticket comes up at a modest size (%.2f)" % ticket_first)
	inspect._set_inspect_distance(0.0)
	_expect(_height_fraction() < 0.8, "and zoomed in it does not cover the screen (%.2f)" % _height_fraction())
	await _close()
	ticket.queue_free()
