extends Control
class_name FinaleGrabOverlay

## The jump scare of the finale: black hands with far too many long fingers clawing in over the picture
## from the left, the right and below (something grabs the player from behind), and the picture closing
## in dark. `grab` runs from 0 (nothing) to 1 (the fingers meet over the whole screen). Drawn in code.

## How far the grab has gone, 0..1.
var grab: float = 0.0:
	set(value):
		grab = clampf(value, 0.0, 1.0)
		queue_redraw()

const FINGERS_PER_HAND: int = 7


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if grab <= 0.0:
		return

	# The overlay sits on a CanvasLayer, so it has no parent to size it: it covers the viewport.
	var size_px: Vector2 = get_viewport_rect().size
	# The dark closing in from the edges first.
	var vignette: Color = Color(0.0, 0.0, 0.0, clampf(grab * 1.3, 0.0, 1.0) * 0.85)
	draw_rect(Rect2(Vector2.ZERO, size_px), vignette)

	var reach: float = ease(grab, 0.55)
	# Each hand: where its wrist is, which way it reaches, and how long its fingers are.
	var hands: Array[Dictionary] = [
		{"from": Vector2(-0.05, 0.55) * size_px, "dir": Vector2(1.0, -0.12), "spread": 1.0},
		{"from": Vector2(1.05, 0.5) * size_px, "dir": Vector2(-1.0, -0.1), "spread": 1.0},
		{"from": Vector2(0.35, 1.05) * size_px, "dir": Vector2(0.35, -1.0), "spread": 0.9},
		{"from": Vector2(0.7, 1.05) * size_px, "dir": Vector2(-0.3, -1.0), "spread": 0.9},
	]
	for hand: Dictionary in hands:
		_draw_hand(hand["from"] as Vector2, (hand["dir"] as Vector2).normalized(), float(hand["spread"]), reach, size_px)


func _draw_hand(wrist: Vector2, direction: Vector2, spread: float, reach: float, size_px: Vector2) -> void:
	var ink: Color = Color(0.0, 0.0, 0.0, 1.0)
	var across: Vector2 = Vector2(-direction.y, direction.x)
	var palm_length: float = size_px.length() * 0.22 * reach
	var palm_width: float = size_px.y * 0.2 * spread

	# The palm and arm: a dark wedge.
	var palm: PackedVector2Array = PackedVector2Array([
		wrist - across * palm_width * 0.5,
		wrist + across * palm_width * 0.5,
		wrist + direction * palm_length + across * palm_width * 0.42,
		wrist + direction * palm_length - across * palm_width * 0.42,
	])
	draw_colored_polygon(palm, ink)

	# The fingers: long, thin, bent at a knuckle, spread like a claw.
	var base: Vector2 = wrist + direction * palm_length
	for i: int in FINGERS_PER_HAND:
		var t: float = float(i) / float(FINGERS_PER_HAND - 1) - 0.5
		var root: Vector2 = base + across * palm_width * 0.85 * t
		var length_one: float = size_px.length() * (0.2 + 0.07 * (1.0 - absf(t) * 1.4)) * reach
		var first: Vector2 = (direction + across * t * 0.5).normalized()
		var knuckle: Vector2 = root + first * length_one * 0.55
		var second: Vector2 = (direction + across * t * 1.1 + Vector2(0.0, 0.1 * sign(t))).normalized()
		var tip: Vector2 = knuckle + second * length_one * 0.6
		var thick: float = size_px.y * 0.018 * spread
		draw_colored_polygon(PackedVector2Array([
			root - across * thick, root + across * thick,
			knuckle + across * thick * 0.7, knuckle - across * thick * 0.7,
		]), ink)
		draw_colored_polygon(PackedVector2Array([
			knuckle - across * thick * 0.7, knuckle + across * thick * 0.7, tip,
		]), ink)
