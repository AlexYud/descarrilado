extends Node

## The horror filter's glare (bloom and the push toward white) fades out while an item is held up in the inspect view,
## so that the item's details can be seen, and comes back when it is put away. Run it as a scene; it quits by itself
## with a non-zero exit code on failure.

var test_failed: bool = false


func _ready() -> void:
	GameSettings.set_text_locale("en", false)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	var player: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, 1.05, 0.0)
	await get_tree().create_timer(0.6).timeout

	await _run(player)

	print("HORROR_FILTER_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run(player: CharacterBody3D) -> void:
	var filter: Node = get_node("/root/HorrorFilter")
	var material: ShaderMaterial = (filter.get("horror_rect") as ColorRect).material as ShaderMaterial
	var bloom: float = float(material.get_shader_parameter("bloom_strength"))
	var gain: float = float(material.get_shader_parameter("highlight_gain"))
	_expect(bloom < 0.01 and gain > 0.1, "the wide bloom is off (as on Low) and the push toward white stays (bloom %.2f, push %.2f)" % [bloom, gain])
	_expect(float(material.get_shader_parameter("vhs_line_jitter")) > 0.0 and not material.shader.code.contains("vhs_dropouts"), "the tape wobble is there, the white dropout dashes are not")
	_expect(not material.shader.code.contains("vhs_head_switch"), "and the torn band along the bottom is gone")
	var fisheye: float = float(material.get_shader_parameter("fisheye_strength"))
	_expect(material.shader.code.contains("fisheye_strength") and fisheye > 0.03 and fisheye < 0.1, "the picture has a little fisheye, not a lot (%.2f)" % fisheye)
	_check_the_lens(filter, material, fisheye)

	var whistle: Inspectable = (load("res://scenes/objects/waiting_shed/carved_whistle.tscn") as PackedScene).instantiate()
	add_child(whistle)
	whistle.global_position = Vector3(0.0, 1.0, -3.0)
	await get_tree().process_frame
	player.start_world_inspect(whistle)
	await get_tree().create_timer(0.8).timeout
	_expect(player.inspect_controller.is_open(), "an item is held up")
	_expect(float(material.get_shader_parameter("bloom_strength")) < 0.01 and float(material.get_shader_parameter("highlight_gain")) < 0.01, "and the glare is gone, so its details can be seen")
	_expect(float(filter.get("inspect_amount")) > 0.99, "(the filter knows it is inspecting)")

	player.inspect_controller.close(false)
	await get_tree().create_timer(0.8).timeout
	_expect(absf(float(material.get_shader_parameter("bloom_strength")) - bloom) < 0.01 and absf(float(material.get_shader_parameter("highlight_gain")) - gain) < 0.01, "put away, the glare comes back as it was")
	whistle.queue_free()


## What is laid over the picture from a 3D position follows the lens: the middle stays, the inner part of the picture is pushed outward and the corners are drawn in
## (the fisheye's bulge), and it is the shader's curve turned round.
func _check_the_lens(filter: Node, material: ShaderMaterial, fisheye: float) -> void:
	var size: Vector2 = Vector2(1000.0, 600.0)
	var middle: Vector2 = size * 0.5
	var at_middle: Vector2 = filter.call("lens_position", middle, size)
	_expect(at_middle.distance_to(middle) < 0.01, "the middle of the picture stays where it was")
	var curve: float = float(material.get_shader_parameter("lens_distortion")) + fisheye
	var turned_round: bool = true
	var pushed_out: bool = true
	var drawn_in: bool = true
	for point: Vector2 in [Vector2(700.0, 300.0), Vector2(250.0, 450.0), Vector2(900.0, 100.0), Vector2(500.0, 560.0), Vector2(40.0, 30.0)]:
		var shown: Vector2 = filter.call("lens_position", point, size)
		var shown_in_lens: Vector2 = shown / size * 2.0 - Vector2.ONE
		var read_at: Vector2 = shown_in_lens * (1.0 + curve * shown_in_lens.length_squared()) / (1.0 + fisheye)
		turned_round = turned_round and read_at.distance_to(point / size * 2.0 - Vector2.ONE) < 0.0005
		var is_corner: bool = (point / size * 2.0 - Vector2.ONE).length_squared() > 1.0
		if is_corner:
			drawn_in = drawn_in and shown.distance_to(middle) < point.distance_to(middle)
		else:
			pushed_out = pushed_out and shown.distance_to(middle) > point.distance_to(middle)

	_expect(turned_round, "a point of the drawing is shown where the shader reads it from (the curve turned round)")
	_expect(pushed_out and drawn_in, "the inner part of the picture is pushed out from the middle and the corners are drawn in, as the picture bulges")

	# No lens, no shift.
	var lens_distortion: Variant = material.get_shader_parameter("lens_distortion")
	material.set_shader_parameter("lens_distortion", 0.0)
	material.set_shader_parameter("fisheye_strength", 0.0)
	var unmoved: Vector2 = filter.call("lens_position", Vector2(900.0, 100.0), size)
	material.set_shader_parameter("lens_distortion", lens_distortion)
	material.set_shader_parameter("fisheye_strength", fisheye)
	_expect(unmoved.distance_to(Vector2(900.0, 100.0)) < 0.01, "with no lens a point is where the camera drew it")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
