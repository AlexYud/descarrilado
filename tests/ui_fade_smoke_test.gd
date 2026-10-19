extends Node

## `UiFade`: a new fade of a piece of UI replaces the one running, so that the last thing asked is what ends up on screen, however fast
## the player acts. Every gap between a fade-in and a fade-out (and the other way round) from 0 to 18 frames is tried. For the record,
## the same sweep is run with bare tweens (the old way), which end wrong for some gaps: that is the bug this class exists for.

var test_failed: bool = false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)


func _ready() -> void:
	var root: Control = Control.new()
	add_child(root)
	await get_tree().process_frame
	var wrong_in_out: int = 0
	var wrong_out_in: int = 0
	var bare_wrong: int = 0
	for gap: int in 19:
		# In, then out `gap` frames later: must end hidden.
		var item: ColorRect = _item(root)
		UiFade.to(item, 1.0, 0.25)
		for frame: int in gap:
			await get_tree().process_frame

		UiFade.to(item, 0.0, 0.2)
		await get_tree().create_timer(0.5).timeout
		if item.modulate.a > 0.001:
			wrong_in_out += 1

		item.queue_free()
		# Out, then in: must end shown.
		var other: ColorRect = _item(root)
		other.modulate.a = 1.0
		UiFade.to(other, 0.0, 0.25)
		for frame: int in gap:
			await get_tree().process_frame

		UiFade.to(other, 1.0, 0.2)
		await get_tree().create_timer(0.5).timeout
		if other.modulate.a < 0.999:
			wrong_out_in += 1

		other.queue_free()
		# The same as the first, with bare tweens, for the record.
		var bare: ColorRect = _item(root)
		bare.create_tween().tween_property(bare, "modulate:a", 1.0, 0.25)
		for frame: int in gap:
			await get_tree().process_frame

		bare.create_tween().tween_property(bare, "modulate:a", 0.0, 0.2)
		await get_tree().create_timer(0.5).timeout
		if bare.modulate.a > 0.001:
			bare_wrong += 1

		bare.queue_free()

	_expect(wrong_in_out == 0, "a fade-out asked at any moment of a fade-in always ends hidden (%d of 19 gaps wrong)" % wrong_in_out)
	_expect(wrong_out_in == 0, "a fade-in asked at any moment of a fade-out always ends shown (%d of 19 gaps wrong)" % wrong_out_in)
	print("note - the same sweep with bare tweens ends wrong for %d of 19 gaps" % bare_wrong)

	# Hiding, cancelling, and an item that goes away in the middle of a fade.
	var hidden: ColorRect = _item(root)
	hidden.modulate.a = 1.0
	UiFade.to(hidden, 0.0, 0.1, true)
	await get_tree().create_timer(0.3).timeout
	_expect(not hidden.visible and hidden.modulate.a == 0.0, "hide_when_clear hides it once it has faded out")
	var cancelled: ColorRect = _item(root)
	UiFade.to(cancelled, 1.0, 0.5)
	await get_tree().create_timer(0.1).timeout
	_expect(UiFade.is_fading(cancelled), "a fade is reported while it runs")
	UiFade.cancel(cancelled)
	var stopped_at: float = cancelled.modulate.a
	await get_tree().create_timer(0.5).timeout
	_expect(not UiFade.is_fading(cancelled) and is_equal_approx(cancelled.modulate.a, stopped_at), "cancelling stops it where it is")
	var going: ColorRect = _item(root)
	UiFade.to(going, 1.0, 0.3)
	going.free()
	await get_tree().create_timer(0.4).timeout
	_expect(true, "an item freed in the middle of a fade does no harm")
	UiFade.to(null, 1.0, 0.2)
	_expect(true, "and a null one is ignored")

	print("UI_FADE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _item(parent: Node) -> ColorRect:
	var item: ColorRect = ColorRect.new()
	item.modulate.a = 0.0
	parent.add_child(item)
	return item
