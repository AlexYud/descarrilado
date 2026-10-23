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
	_expect(bloom > 0.2 and gain > 0.1, "the glare is on in the usual picture (bloom %.2f, push %.2f)" % [bloom, gain])
	_expect(float(material.get_shader_parameter("vhs_line_jitter")) > 0.0 and not material.shader.code.contains("vhs_dropouts"), "the tape wobble is there, the white dropout dashes are not")
	_expect(not material.shader.code.contains("vhs_head_switch"), "and the torn band along the bottom is gone")

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


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
