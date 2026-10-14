extends Node
class_name InspectReadables

## The "read this" workflow of the item inspection, kept apart from the 3D handling
## in `PlayerInspectController`. Kept as quiet as the games that inspired it: the item
## and nothing else, until there is something to read.
##
## 1. While the player turns an item freely (`update` every frame), its `ReadableSpot`s
##    are tested: a spot whose outward direction points at the player (within its cone,
##    for its dwell time, with a margin before it is dropped again) becomes the offered
##    one, the best-facing of them when several qualify. A document whose art is in
##    another language than the player's offers its whole text the same way.
## 2. What is offered shows a small prompt ("[E] Read" / "[E] Examine", with the key the
##    player has chosen; it can also be clicked) on the spot, or on the document.
## 3. Opening it fades a veil over the 3D view and the text in, centred, left aligned,
##    with a red title. For a spot the item first eases round to show it squarely.
## 4. Back (the same key, Esc, right click, the inventory key, or a click on "Back")
##    fades the text out and gives the turning back.
##
## Only a dot product per spot runs each frame. Nothing is cast.

## A spot was opened. `spot_id` is the spot's id ("" for a document's text or a spot
## without one).
signal spot_read(spot_id: StringName)
## The text opened or closed (the inspect view changes its corner prompt).
signal reading_changed(is_reading: bool)

## A spot stays offered until it is this many degrees beyond its own cone.
const RELEASE_MARGIN_DEGREES: float = 10.0
const FADE_SECONDS: float = 0.28
## Text this short is shown large and centred (an engraving), longer text as reading.
const SHORT_TEXT_LENGTH: int = 120

var controller: PlayerInspectController = null

var _item: Node3D = null
var _spots: Array[ReadableSpot] = []
var _offered: ReadableSpot = null
var _candidate: ReadableSpot = null
var _dwell: float = 0.0
var _document_offered: bool = false
var _prompt_shown: bool = false

var _reading: bool = false
var _reading_spot: ReadableSpot = null
var _focus_orientation: Basis = Basis.IDENTITY
var _fading_out: bool = false
var _tween: Tween = null
var _prompt_tween: Tween = null

var _prompt: KeyHint = null
var _veil: ColorRect = null
var _text_box: VBoxContainer = null
var _title: Label = null
var _body: RichTextLabel = null


# ----------------------------------------------------------------------
# Lifecycle
# ----------------------------------------------------------------------

## Builds the prompt and the text view under `root` (the inspect view's overlay).
func build_ui(root: Control) -> void:
	_prompt = KeyHint.new()
	_prompt.name = "ReadablePrompt"
	_prompt.visible = false
	_prompt.modulate.a = 0.0
	_prompt.pressed.connect(activate)
	root.add_child(_prompt)

	# The 3D view steps back behind a dark veil: the item stays faintly visible. (Black, as the inspect view always was.)
	_veil = ColorRect.new()
	_veil.name = "ReadableVeil"
	_veil.color = Color(0.0, 0.0, 0.0, 0.93)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.visible = false
	_veil.modulate.a = 0.0
	root.add_child(_veil)

	_text_box = VBoxContainer.new()
	_text_box.name = "ReadableText"
	_text_box.visible = false
	_text_box.modulate.a = 0.0
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.add_theme_constant_override("separation", 18)
	root.add_child(_text_box)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.theme_type_variation = &"HeaderLabel"
	_text_box.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.theme_type_variation = &"NoteText"
	_text_box.add_child(_body)

	if not GameSettings.text_language_changed.is_connected(_on_language_changed):
		GameSettings.text_language_changed.connect(_on_language_changed)


## A new inspection starts: finds the item's spots.
func begin(item: Node3D) -> void:
	end()
	_item = item
	_spots.clear()
	for node: Node in item.find_children("*", "ReadableSpot", true, false):
		_spots.append(node as ReadableSpot)


## The inspection ends (or is replaced): everything goes away at once.
func end() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()

	var was_reading: bool = _reading
	_item = null
	_spots.clear()
	_offered = null
	_candidate = null
	_dwell = 0.0
	_document_offered = false
	_prompt_shown = false
	_reading = false
	_reading_spot = null
	_fading_out = false

	if _prompt != null:
		_prompt.visible = false
		_prompt.modulate.a = 0.0
		_veil.visible = false
		_text_box.visible = false

	if was_reading:
		reading_changed.emit(false)


func has_spots() -> bool:
	return not _spots.is_empty()


## True from the moment a text is opened until it has faded away.
func is_reading() -> bool:
	return _reading


## True while a text is open and not on its way out (what "Back" would close).
func is_text_open() -> bool:
	return _reading and not _fading_out


## True while the item should ease round to face the spot being read.
func is_focusing() -> bool:
	return _reading and _reading_spot != null and not _fading_out


## The orientation (relative to the camera) that shows the spot squarely and upright.
func get_focus_orientation() -> Basis:
	return _focus_orientation


## The spot offered right now (or null).
func get_offered_spot() -> ReadableSpot:
	return _offered


## True when the document's own text is what is offered.
func is_document_offered() -> bool:
	return _document_offered


# ----------------------------------------------------------------------
# Each frame
# ----------------------------------------------------------------------

## Tests the spots against the way the item faces. Call it every frame while the
## item is being viewed.
func update(delta: float) -> void:
	if _item == null or _reading:
		return

	_update_spots(delta)

	# A document whose art is in another language offers its text when no spot is.
	var document_wanted: bool = (
		_offered == null and _candidate == null and controller.has_document_text()
	)
	if document_wanted != _document_offered:
		_document_offered = document_wanted
		_apply_prompt()

	if _prompt_shown:
		_place_prompt()


func _update_spots(delta: float) -> void:
	if _spots.is_empty():
		return

	var toward_viewer: Vector3 = controller.camera.global_basis.z

	# The best-facing spot that is inside its cone (the offered one gets a wider cone,
	# so the prompt does not flicker at its edge).
	var best: ReadableSpot = null
	var best_dot: float = -2.0
	for spot: ReadableSpot in _spots:
		var margin: float = RELEASE_MARGIN_DEGREES if spot == _offered else 0.0
		if not spot.is_facing(toward_viewer, margin):
			continue

		var dot: float = spot.get_facing_dot(toward_viewer)
		if dot > best_dot:
			best_dot = dot
			best = spot

	if best == _offered:
		_candidate = null
		_dwell = 0.0
		return

	if best == null:
		_candidate = null
		_dwell = 0.0
		_set_offered(null)
		return

	if best != _candidate:
		_candidate = best
		_dwell = 0.0

	_dwell += delta
	if _dwell >= best.dwell_seconds:
		_set_offered(best)


func _set_offered(spot: ReadableSpot) -> void:
	_offered = spot
	_candidate = null
	_dwell = 0.0
	_apply_prompt()


## Shows or hides the prompt to match what is offered.
func _apply_prompt() -> void:
	if _prompt == null:
		return

	var wanted: bool = _offered != null or _document_offered
	if wanted:
		_refresh_prompt()

	if wanted == _prompt_shown:
		return

	_prompt_shown = wanted
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()

	_prompt_tween = create_tween()
	if wanted:
		_prompt.visible = true
		_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.22)
	else:
		_prompt_tween.tween_property(_prompt, "modulate:a", 0.0, 0.15)
		_prompt_tween.tween_callback(func() -> void: _prompt.visible = _prompt_shown)


# ----------------------------------------------------------------------
# Opening and closing the text
# ----------------------------------------------------------------------

## Opens what is offered. False if nothing is.
func activate() -> bool:
	if _reading or _item == null or (_offered == null and not _document_offered):
		return false

	_reading = true
	_fading_out = false
	_reading_spot = _offered
	var spot_id: StringName = &""
	if _reading_spot != null:
		_focus_orientation = _frame_orientation_for(_reading_spot)
		spot_id = _reading_spot.spot_id

	_offered = null
	_document_offered = false
	_prompt_shown = false
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.visible = false
	_prompt.modulate.a = 0.0

	_fill_text()
	_layout()

	_veil.visible = true
	_text_box.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_veil, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_property(_text_box, "modulate:a", 1.0, FADE_SECONDS)

	spot_read.emit(spot_id)
	reading_changed.emit(true)
	return true


## Closes the text and gives the turning back. False if none was open.
func close_text() -> bool:
	if not _reading or _fading_out:
		return false

	_fading_out = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_veil, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_property(_text_box, "modulate:a", 0.0, FADE_SECONDS)
	_tween.chain().tween_callback(_finish_close)
	reading_changed.emit(false)
	return true


func _finish_close() -> void:
	_reading = false
	_reading_spot = null
	_fading_out = false
	_veil.visible = false
	_text_box.visible = false


## Gives the first chance at an input event while an item is being viewed. True if it
## was used (the controller then does not turn the item).
func handle_input(event: InputEvent) -> bool:
	if _reading:
		# The same key closes it; nothing else turns the item meanwhile (the wheel
		# over a long text still scrolls it).
		if event.is_action_pressed("interact"):
			close_text()

		return true

	if event.is_action_pressed("interact") and (_offered != null or _document_offered):
		activate()
		return true

	return false


# ----------------------------------------------------------------------
# What is shown
# ----------------------------------------------------------------------

func _fill_text() -> void:
	var title_text: String = controller.get_item_title()
	var text_key: String = controller.get_document_text_key()

	if _reading_spot != null:
		text_key = _reading_spot.text_key
		if not _reading_spot.title_key.is_empty():
			title_text = tr(_reading_spot.title_key)

	_title.text = title_text
	_title.visible = not title_text.is_empty()
	_body.text = tr(text_key)


func _refresh_prompt() -> void:
	if _prompt == null or controller == null:
		return

	var verb_key: String = "INSPECT_VERB_READ"
	if _offered != null and _offered.prompt_kind == ReadableSpot.PromptKind.EXAMINE:
		verb_key = "INSPECT_VERB_EXAMINE"

	_prompt.set_hint(
		InputBindings.get_binding_label(&"interact", -1, true),
		tr(verb_key),
		controller.get_body_font_size(),
		controller.get_ui_font(false)
	)
	_place_prompt()


## The prompt sits on the spot (or on the document) so the eye is already there.
func _place_prompt() -> void:
	if _prompt == null or controller == null or _item == null:
		return

	var screen: Vector2 = controller.get_screen_size()
	var column: float = controller.get_column_width()
	var left: float = (screen.x - column) * 0.5

	var world_point: Vector3 = controller.get_item_center_world()
	if _offered != null:
		world_point = _offered.global_position

	var point: Vector2 = controller.camera.unproject_position(world_point)
	_prompt.size = _prompt.get_combined_minimum_size()
	var x: float = clampf(point.x - _prompt.size.x * 0.5, left, left + column - _prompt.size.x)
	var y: float = clampf(point.y + screen.y * 0.04, screen.y * 0.1, screen.y * 0.8)
	_prompt.position = Vector2(x, y)


func _layout() -> void:
	var screen: Vector2 = controller.get_screen_size()
	var column: float = controller.get_column_width()
	var body: int = controller.get_body_font_size()
	var body_text: String = _body.text
	var short: bool = body_text.length() <= SHORT_TEXT_LENGTH
	var text_size: int = int(body * (1.7 if short else 1.12))
	var serif: Font = controller.get_ui_font(false)
	var bold: Font = controller.get_ui_font(true)

	_title.add_theme_font_size_override("font_size", int(body * 1.5))
	_body.add_theme_font_override("normal_font", serif)
	_body.add_theme_font_override("bold_font", bold)
	_body.add_theme_font_override("italics_font", UIConfig.font(UIConfig.weight_body, UIConfig.spacing_body, true))
	for size_name: String in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		_body.add_theme_font_size_override(size_name, text_size)

	_title.custom_minimum_size.x = column
	_body.custom_minimum_size = Vector2(column, 0.0)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if short else HORIZONTAL_ALIGNMENT_LEFT
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if short else HORIZONTAL_ALIGNMENT_LEFT

	_body.fit_content = true
	_body.scroll_active = false
	_text_box.custom_minimum_size = Vector2(column, 0.0)
	_text_box.size = Vector2(column, 0.0)

	await get_tree().process_frame
	if _text_box == null or not _text_box.visible:
		return

	# A text taller than the screen allows scrolls inside a fixed height.
	var most: float = screen.y * 0.72
	_text_box.size = Vector2(column, 0.0)
	if _text_box.size.y > most:
		_body.fit_content = false
		_body.scroll_active = true
		_body.custom_minimum_size.y = most - _title.size.y - 24.0
		_text_box.size = Vector2(column, 0.0)
		await get_tree().process_frame

	var top: float = screen.y * 0.16
	if short:
		top = maxf((screen.y - _text_box.size.y) * 0.5 - screen.y * 0.04, screen.y * 0.1)

	_text_box.position = Vector2((screen.x - column) * 0.5, top)


## The screen changed size.
func relayout() -> void:
	if _reading:
		_layout()
	elif _prompt_shown:
		_refresh_prompt()


func _on_language_changed(_locale: String) -> void:
	if _prompt_shown:
		_refresh_prompt()

	if _reading:
		_fill_text()
		_layout()


## The orientation, relative to the camera, that puts the spot's own axes on the
## camera's: facing the viewer, upright. (The spot's frame is read in the item's own
## space, so it does not depend on how the item is turned now.)
func _frame_orientation_for(spot: ReadableSpot) -> Basis:
	var item_basis: Basis = _item.global_basis.orthonormalized()
	var spot_basis: Basis = spot.global_basis.orthonormalized()
	var frame_in_item: Basis = item_basis.inverse() * spot_basis
	return frame_in_item.inverse().orthonormalized()
