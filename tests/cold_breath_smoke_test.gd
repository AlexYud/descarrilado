extends Node

## The player's breath smoking in the cold: it exists under the camera only as a particle emitter that is off until
## a breath is blown, the breaths come on a rhythm that follows what the player does (slow standing, quicker walking,
## quickest running), nothing shows in warm places or while the player cannot move or is looking at something else,
## and a scene decides whether it is cold. Run it as a scene; it quits by itself with a non-zero exit code on failure.

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

	var warm: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(warm)
	warm.global_position = Vector3(-5.0, 1.05, 0.0)
	var cold: CharacterBody3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	cold.set("cold_breath_enabled", true)
	add_child(cold)
	cold.global_position = Vector3(5.0, 1.05, 0.0)
	await get_tree().create_timer(0.6).timeout

	await _run(warm, cold)

	print("COLD_BREATH_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _run(warm: CharacterBody3D, cold: CharacterBody3D) -> void:
	var breath: ColdBreath = cold.cold_breath
	var warm_breath: ColdBreath = warm.cold_breath
	_expect(breath != null and breath.get_parent() == cold.get_node("Head/Camera3D"), "the breath is part of the camera, at the mouth")
	_expect(breath.position.y < 0.0 and breath.position.z < 0.0, "a little below and in front of the eyes (%s)" % str(breath.position))
	_expect(breath.cold and not warm_breath.cold, "the scene decides: the dream intro is cold, the default is not")
	var emitter: GPUParticles3D = breath.get_node("Vapour") as GPUParticles3D
	_expect(emitter != null and not emitter.emitting and not emitter.local_coords, "the vapour is off until a breath, and hangs in the air once out (not tied to the player)")
	var vapour: ShaderMaterial = (emitter.draw_pass_1 as QuadMesh).material as ShaderMaterial if emitter.draw_pass_1 != null else null
	_expect(vapour != null and vapour.shader == ColdBreath.VAPOUR_SHADER, "each puff is a billboard drawn by the vapour shader (drifting noise that dissolves)")
	var noise: Texture2D = vapour.get_shader_parameter("noise_texture") as Texture2D
	var noise_image: Image = noise.get_image()
	var low: float = 1.0
	var high: float = 0.0
	for i: int in 32:
		var value: float = noise_image.get_pixel(i * 4, (i * 7) % 128).r
		low = minf(low, value)
		high = maxf(high, value)
	_expect(noise != null and high - low > 0.3, "whose noise is patchy, thick and thin (spread %.2f)" % (high - low))
	_expect(emitter.amount >= 100 and emitter.lifetime < 2.0, "made of many small wisps (%d) that do not stay long (%.1f s)" % [emitter.amount, emitter.lifetime])
	_expect(breath.position.y <= -0.09 and breath.tint.a < 0.12, "low in the view and faint, so it only adds to the air (alpha %.2f)" % breath.tint.a)

	# Standing still: slow breaths; none at all in the warm place.
	for i: int in 700:
		breath._process(0.01)
		warm_breath._process(0.01)
	_expect(warm_breath.exhale_count == 0 and not warm_breath.get_node("Vapour").emitting, "a warm place never shows a breath")
	_expect(breath.exhale_count >= 1 and breath.exhale_count <= 3, "standing still, a breath every few seconds (%d in 7 s)" % breath.exhale_count)

	# The rhythm follows the effort.
	_expect(breath.get_effort() == 0, "standing still is effort 0")
	cold.velocity = Vector3(0.0, 0.0, -1.6)
	_expect(breath.get_effort() == 1, "walking is effort 1")
	cold.movement_controller.is_sprinting = true
	cold.velocity = Vector3(0.0, 0.0, -2.9)
	_expect(breath.get_effort() == 2, "running is effort 2")
	var standing: float = 0.0
	var walking: float = 0.0
	var running: float = 0.0
	for i: int in 50:
		standing += breath.interval_for(0)
		walking += breath.interval_for(1)
		running += breath.interval_for(2)
	_expect(standing > walking * 1.2 and walking > running * 1.2, "the faster the player moves, the quicker the breaths (%.1f, %.1f, %.1f s)" % [standing / 50.0, walking / 50.0, running / 50.0])
	var before: int = breath.exhale_count
	for i: int in 700:
		breath._process(0.01)
	_expect(breath.exhale_count - before >= 3, "running, many breaths in 7 s (%d)" % (breath.exhale_count - before))
	cold.movement_controller.is_sprinting = false
	cold.velocity = Vector3.ZERO

	# A breath starts the vapour and ends it, leaving what is out to fade.
	breath._start_exhaling()
	_expect(emitter.emitting and breath.is_exhaling, "a breath turns the vapour on")
	for i: int in 100:
		breath._process(0.01)
	_expect(not emitter.emitting and not breath.is_exhaling, "and off again after half a second")

	# Nothing shows while the player cannot move or is looking at something else.
	for flag: String in ["cutscene_frozen", "dialogue_frozen", "modal_ui_open", "view_locked"]:
		cold.set(flag, true)
		var count: int = breath.exhale_count
		for i: int in 1500:
			breath._process(0.01)
		_expect(breath.exhale_count == count and not emitter.emitting, "no breath while %s" % flag)
		cold.set(flag, false)

	# Taking it up again, a breath is not blown at once.
	var resumed: int = breath.exhale_count
	for i: int in 30:
		breath._process(0.01)
	_expect(breath.exhale_count == resumed, "a moment after the player can be seen breathing again")

	# The scene's switch works at any time.
	cold.set("cold_breath_enabled", false)
	_expect(not breath.cold, "a script can make a room warm")
	cold.set("cold_breath_enabled", true)
	_expect(breath.cold, "and cold again")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
		return

	test_failed = true
	push_error("FAIL - " + message)
	print("FAIL - ", message)
