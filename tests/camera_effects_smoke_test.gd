extends Node

## The two camera effects the player can switch off in the options: the soft focus
## behind what is looked at (only while something is in focus) and the blur of a fast
## turn. Run it as a scene; it quits by itself with a non-zero exit code on failure.

var test_failed: bool = false


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
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
	await _wait(0.6)

	_check_settings()
	await _check_focus(player)
	await _check_motion(player)
	await _check_options_panel()

	GameSettings.set_depth_of_field_enabled(true)
	GameSettings.set_motion_blur_enabled(true)
	print("CAMERA_EFFECTS_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _check_settings() -> void:
	_expect(GameSettings.get_depth_of_field_enabled() and GameSettings.get_motion_blur_enabled(), "both effects are on by default")

	var seen: Array[bool] = []
	GameSettings.depth_of_field_changed.connect(func(on: bool) -> void: seen.append(on))
	GameSettings.set_depth_of_field_enabled(false, false)
	GameSettings.set_depth_of_field_enabled(false, false)
	_expect(seen == [false], "turning one off says so once (%s)" % str(seen))
	GameSettings.set_depth_of_field_enabled(true, false)


func _check_focus(player: CharacterBody3D) -> void:
	var blur: FocusBlurController = player.focus_blur
	var camera: Camera3D = player.get_node("Head/Camera3D")
	_expect(blur != null and camera.attributes is CameraAttributesPractical, "the camera carries the focus effect")
	_expect(not camera.attributes.dof_blur_far_enabled and blur.get_weight() == 0.0, "nothing in focus: no blur, no cost")

	var whistle: Inspectable = (load("res://scenes/objects/waiting_shed/carved_whistle.tscn") as PackedScene).instantiate()
	add_child(whistle)
	whistle.global_position = Vector3(0.0, 1.0, -3.0)
	await get_tree().process_frame
	player.start_world_inspect(whistle)
	await _wait(1.5)

	_expect(blur.get_weight() > 0.99, "an item held up is in focus (%.2f)" % blur.get_weight())
	var far_start: float = camera.attributes.dof_blur_far_distance
	_expect(
		camera.attributes.dof_blur_far_enabled and far_start > player.inspect_controller.get_focus_distance(),
		"what is behind it blurs, from just behind it (%.2f)" % far_start
	)

	GameSettings.set_depth_of_field_enabled(false, false)
	await _wait(1.2)
	_expect(not camera.attributes.dof_blur_far_enabled, "the option turns it off, even with an item held")
	GameSettings.set_depth_of_field_enabled(true, false)
	await _wait(0.8)
	_expect(camera.attributes.dof_blur_far_enabled, "and on again")

	player.inspect_controller.close(false)
	await _wait(1.5)
	_expect(not camera.attributes.dof_blur_far_enabled and blur.get_weight() == 0.0, "put away, the focus goes with it")
	whistle.queue_free()


func _check_motion(player: CharacterBody3D) -> void:
	var blur: MotionBlurController = player.motion_blur
	_expect(blur != null, "the player has the motion blur")

	# Still: nothing to draw.
	await _wait(0.3)
	_expect(not blur.visible, "a still view is not blurred")

	# A quick turn is smeared, a slow one is not.
	for i in 12:
		player.rotation.y += deg_to_rad(4.0)
		await get_tree().process_frame
	_expect(blur.visible, "a quick turn is blurred")
	await _wait(0.4)
	_expect(not blur.visible, "and it clears when the view settles")

	for i in 30:
		player.rotation.y += deg_to_rad(0.1)
		await get_tree().process_frame
	_expect(not blur.visible, "a slow turn stays sharp")

	GameSettings.set_motion_blur_enabled(false, false)
	for i in 12:
		player.rotation.y += deg_to_rad(4.0)
		await get_tree().process_frame
	_expect(not blur.visible, "the option turns it off")
	GameSettings.set_motion_blur_enabled(true, false)


func _check_options_panel() -> void:
	var panel: Node = (load("res://scenes/ui/options_panel.tscn") as PackedScene).instantiate()
	add_child(panel)
	await get_tree().process_frame

	var depth: CheckButton = panel.depth_of_field_check_button
	var motion: CheckButton = panel.motion_blur_check_button
	_expect(depth.button_pressed and motion.button_pressed, "the options show both as on")
	depth.button_pressed = false
	_expect(not GameSettings.get_depth_of_field_enabled(), "the depth of field switch works")
	motion.button_pressed = false
	_expect(not GameSettings.get_motion_blur_enabled(), "so does the motion blur switch")
	panel.queue_free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
