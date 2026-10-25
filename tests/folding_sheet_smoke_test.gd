extends Node

## The sheet that folds like a road map (`FoldingSheet`): flat it is the whole sheet; folded once it is half of it; folded twice
## it is a block of a quarter, kept in the middle, with its four layers lying one above the other and none through another;
## writing hung on a panel goes with it; it folds and opens over time and a copy of it still works. Run it as a scene; it
## quits by itself with a non-zero exit code on failure.

const SIZE: Vector2 = Vector2(0.7, 0.56)
const THICKNESS: float = 0.002

var test_failed: bool = false


func _ready() -> void:
	var sheet: FoldingSheet = _make_sheet()
	add_child(sheet)
	await get_tree().process_frame

	_check_flat(sheet)
	_check_folded_once(sheet)
	_check_folded_small(sheet)
	_check_order_and_labels(sheet)
	_check_animation(sheet)
	await _check_a_copy(sheet)

	print("FOLDING_SHEET_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _make_sheet() -> FoldingSheet:
	var sheet: FoldingSheet = FoldingSheet.new()
	sheet.name = "Sheet"
	sheet.sheet_size = SIZE
	sheet.thickness = THICKNESS
	sheet.build()

	# One word on each panel.
	for i: int in 4:
		var label: Label3D = Label3D.new()
		label.name = "Word%d" % i
		label.text = "word"
		var at: Vector2 = Vector2(-0.2 if i % 2 == 0 else 0.2, 0.15 if i < 2 else -0.15)
		sheet.attach(label, at, 0.001)

	return sheet


## The box round the four slabs, in the sheet's own frame.
func _bounds(sheet: FoldingSheet) -> AABB:
	var result: AABB = AABB()
	var found: bool = false
	for slab: Node in sheet.find_children("Slab", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = slab as MeshInstance3D
		var box: AABB = (sheet.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		result = box if not found else result.merge(box)
		found = true

	return result


## The height of each slab's middle over the sheet's plane, lowest first.
func _layers(sheet: FoldingSheet) -> Array[float]:
	var heights: Array[float] = []
	for slab: Node in sheet.find_children("Slab", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = slab as MeshInstance3D
		heights.append(sheet.to_local(mesh.global_position).z)

	heights.sort()
	return heights


func _check_flat(sheet: FoldingSheet) -> void:
	sheet.closedness = 0.0
	var box: AABB = _bounds(sheet)
	_expect(is_equal_approx(box.size.x, SIZE.x) and is_equal_approx(box.size.y, SIZE.y), "flat, it is the whole sheet (%s)" % box.size)
	_expect(box.size.z < THICKNESS * 1.5, "flat, it is one sheet thick")
	_expect(box.get_center().length() < 0.001, "flat, it is centred")
	for layer: float in _layers(sheet):
		_expect(absf(layer) < 0.0001, "flat, every panel is in the plane (%.4f)" % layer)

	_expect(sheet.get_panel(&"TopLeft") != null and sheet.get_panel(&"BottomRight") != null, "the four panels are found by name")
	_expect(sheet.panel_at(Vector2(-0.1, 0.1)) == &"TopLeft" and sheet.panel_at(Vector2(0.1, -0.1)) == &"BottomRight", "a point of the sheet is on the panel it lies on")


func _check_folded_once(sheet: FoldingSheet) -> void:
	sheet.closedness = 0.5
	var box: AABB = _bounds(sheet)
	_expect(absf(box.size.x - SIZE.x) < 0.001 and absf(box.size.y - SIZE.y * 0.5) < 0.001, "folded once across, it is half as tall (%s)" % box.size)
	_expect(absf(box.get_center().y) < 0.001, "folded once, it is kept in the middle")


func _check_folded_small(sheet: FoldingSheet) -> void:
	sheet.closedness = 1.0
	var box: AABB = _bounds(sheet)
	_expect(absf(box.size.x - SIZE.x * 0.5) < 0.001 and absf(box.size.y - SIZE.y * 0.5) < 0.001, "folded twice, it is a quarter of the sheet (%s)" % box.size)
	_expect(absf(box.get_center().x) < 0.001 and absf(box.get_center().y) < 0.001, "folded small, it is still in the middle")
	_expect(box.size.z > THICKNESS * 4.0 and box.size.z < 0.03, "folded small, it is a few sheets thick (%.4f m)" % box.size.z)


func _check_order_and_labels(sheet: FoldingSheet) -> void:
	sheet.closedness = 1.0
	var layers: Array[float] = _layers(sheet)
	_expect(layers.size() == 4, "four layers")
	for i: int in layers.size() - 1:
		_expect(layers[i + 1] - layers[i] > THICKNESS * 0.99, "layers %d and %d do not touch (%.4f m apart)" % [i, i + 1, layers[i + 1] - layers[i]])

	# The cover is the back of the bottom right panel: it lies on top of the stack, and its back faces up.
	var bottom_right: Node3D = sheet.get_panel(&"BottomRight")
	var top_layer: float = layers[layers.size() - 1]
	_expect(is_equal_approx(sheet.to_local(bottom_right.global_position).z, top_layer), "the bottom right panel is on top of the folded sheet")
	_expect(bottom_right.global_transform.basis.z.dot(sheet.global_transform.basis.z) < -0.99, "and it is face down, so its back shows")

	# Words go with their panel: folded, each one is inside the block.
	var block: AABB = _bounds(sheet).grow(0.002)
	for i: int in 4:
		var word: Label3D = sheet.find_child("Word%d" % i, true, false) as Label3D
		_expect(block.has_point(sheet.to_local(word.global_position)), "word %d went with its panel into the fold" % i)

	sheet.closedness = 0.0
	for i: int in 4:
		var word: Label3D = sheet.find_child("Word%d" % i, true, false) as Label3D
		var local: Vector3 = sheet.to_local(word.global_position)
		var expected: Vector2 = Vector2(-0.2 if i % 2 == 0 else 0.2, 0.15 if i < 2 else -0.15)
		_expect(Vector2(local.x, local.y).distance_to(expected) < 0.001, "flat again, word %d is back where it was written" % i)


func _check_animation(sheet: FoldingSheet) -> void:
	sheet.closedness = 0.0
	var duration: float = sheet.close_over(0.8)
	_expect(is_equal_approx(duration, 0.8) and sheet.is_moving(), "folding a flat sheet takes the whole time")
	var steps: int = 0
	while sheet.is_moving() and steps < 200:
		sheet._process(0.05)
		steps += 1

	_expect(is_equal_approx(sheet.closedness, 1.0) and not sheet.is_moving(), "it ends folded (%d steps)" % steps)

	duration = sheet.open_out(1.0)
	_expect(is_equal_approx(duration, 1.0), "opening a folded sheet takes the whole time")
	sheet._process(0.5)
	_expect(sheet.closedness > 0.4 and sheet.closedness < 0.6, "half way through it is half open (%.2f)" % sheet.closedness)
	# Folded again from where it is: the time is only what is left to fold.
	duration = sheet.close_over(1.0)
	_expect(duration > 0.4 and duration < 0.6, "folding again from half open takes half the time (%.2f s)" % duration)
	while sheet.is_moving():
		sheet._process(0.1)

	_expect(is_equal_approx(sheet.closedness, 1.0), "and it ends folded")

	sheet.set_closed(false)
	_expect(is_equal_approx(sheet.closedness, 0.0) and not sheet.is_moving(), "it can also be opened at once")
	_expect(sheet.close_over(0.0) == 0.0 and is_equal_approx(sheet.closedness, 1.0), "a fold of no time is at once")
	sheet.set_closed(false)


## The inspect view duplicates the item: the copy has the panels already and finds them again.
func _check_a_copy(sheet: FoldingSheet) -> void:
	var copy: FoldingSheet = sheet.duplicate() as FoldingSheet
	add_child(copy)
	await get_tree().process_frame
	_expect(copy.get_panel(&"TopRight") != null and copy.get_child_count() == 1, "a copy has its panels and builds nothing more")
	copy.closedness = 1.0
	var box: AABB = _bounds(copy)
	_expect(absf(box.size.x - SIZE.x * 0.5) < 0.001 and absf(box.size.y - SIZE.y * 0.5) < 0.001, "a copy folds the same way")
	copy.set_closed(false)
	_expect(is_equal_approx(_bounds(copy).size.x, SIZE.x), "and opens")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
