extends Node

## Captures the aftermath photograph of the waiting shed (a colour print of this shelter after the body was removed) from the shed's real geometry
## and saves it as a project texture. A DEVELOPER's tool, run by hand in a window (a capture needs a real renderer; a headless run renders nothing):
##   godot --path . res://scripts/tools/capture_shelter_aftermath.tscn
## It writes `res://assets/textures/waiting_shed/shelter_aftermath_photo.png` (1024 x 768), which is then imported and shipped like any other art: the game never
## renders, draws or writes this picture at run time. Pass `-- out=<absolute path>` to write a trial somewhere else instead (nothing in the project changes).
##
## What it does: loads the shed's playtest scene (the shed, the ground and the ring of forest), takes the player out of it, asks the shed for its aftermath
## look (`WaitingShedSequence.WorldState.PHOTO_CAPTURE`: the old front plank broken, no belongings, no camcorder, no cast, no ferns), dresses the blood on
## the real geometry (`ShelterAftermathDressing`), lights it as a documentary flash photograph (a bright flat light at the camera over a neutral ambient: no
## fog, no red light, no glow), renders one frame in a 1024 x 768 SubViewport, waits for it to be drawn (`frame_post_draw`, or the read can return a black or
## stale image), reads it back and gives it a muted print's grade (a little desaturation and warmth, lifted blacks, a soft vignette, fine grain).
## Saves are left alone: the save directory is pointed at a throwaway folder before anything loads.

const OUT_PATH: String = "res://assets/textures/waiting_shed/shelter_aftermath_photo.png"
const SIZE: Vector2i = Vector2i(1024, 768)
const PLAYTEST_SCENE: String = "res://scenes/levels/waiting_shed_playtest.tscn"

## The photographer's place, in the shed's space: in front of the shelter and to the right, looking at the bench, the pool and the cracked pillar's foot.
const CAMERA_AT: Vector3 = Vector3(-2.55, 1.3, -2.6)
const CAMERA_LOOKS_AT: Vector3 = Vector3(-4.75, 0.7, -5.2)
const CAMERA_FOV: float = 64.0


func _ready() -> void:
	SaveManager.save_directory = "res://.godot/aftermath_capture_unused"
	var out: String = ProjectSettings.globalize_path(OUT_PATH)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out = argument.substr(4)
	await _capture(out)
	get_tree().quit()


func _capture(out: String) -> void:
	var level: Node3D = (load(PLAYTEST_SCENE) as PackedScene).instantiate() as Node3D
	add_child(level)
	# No player and no setup in a capture: nothing of the game's own is in the picture.
	for node_name: String in ["Player", "PlayTestSetup"]:
		var node: Node = level.get_node_or_null(node_name)
		if node != null:
			level.remove_child(node)
			node.free()
	var shed: Node3D = level.get_node("WaitingShed") as Node3D
	for i: int in 4:
		await get_tree().process_frame

	shed.call("set_world_state", 2)
	ShelterAftermathDressing.build(shed)
	# The shelter's own lamp is the night's; this is a flash photograph.
	var lamp: Light3D = shed.find_child("ShelterLamp", true, false) as Light3D
	if lamp != null:
		lamp.visible = false
	for existing: Node in level.find_children("*", "WorldEnvironment", true, false):
		existing.queue_free()
	for existing: Node in level.find_children("*", "DirectionalLight3D", true, false):
		existing.queue_free()

	var view: SubViewport = SubViewport.new()
	view.size = SIZE
	view.msaa_3d = Viewport.MSAA_4X
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.11, 0.13, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = false
	var camera: Camera3D = Camera3D.new()
	camera.environment = environment
	camera.fov = CAMERA_FOV
	camera.near = 0.05
	camera.far = 80.0
	view.add_child(camera)
	camera.global_transform = Transform3D(Basis.IDENTITY, shed.to_global(CAMERA_AT)).looking_at(shed.to_global(CAMERA_LOOKS_AT), Vector3.UP)

	# The flash: bright, flat, at the camera; and a weak sky-ish fill from above so that the slab and the planks keep their texture.
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_energy = 3.2
	flash.omni_range = 18.0
	flash.omni_attenuation = 1.0
	flash.shadow_enabled = false
	flash.light_color = Color(1.0, 0.97, 0.92)
	camera.add_child(flash)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_energy = 0.55
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.shadow_enabled = true
	fill.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	level.add_child(fill)

	# The picture is drawn some frames after everything is in place; wait for the last draw before reading it back.
	for i: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("capture_shelter_aftermath: nothing was rendered (run it in a window, not headless).")
		return

	image.convert(Image.FORMAT_RGB8)
	_grade_as_print(image)
	var directory: String = out.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var error: Error = image.save_png(out)
	print("CAPTURE saved %s (%s): %s" % [out, str(image.get_size()), error_string(error)])


## A muted print: a little desaturation and warmth, lifted blacks, a soft vignette and fine grain. Deterministic.
func _grade_as_print(image: Image) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1991
	var size: Vector2 = Vector2(image.get_size())
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var luminance: float = c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			var muted: Color = Color(luminance, luminance, luminance).lerp(c, 0.84)
			muted = Color(muted.r * 1.03, muted.g * 1.0, muted.b * 0.94)
			muted = Color(muted.r * 0.94 + 0.04, muted.g * 0.94 + 0.04, muted.b * 0.94 + 0.045)
			var offset: Vector2 = Vector2(x, y) / size - Vector2(0.5, 0.5)
			var vignette: float = 1.0 - 0.34 * pow(clampf(offset.length() * 1.4, 0.0, 1.0), 2.2)
			var grain: float = rng.randf_range(-0.016, 0.016)
			image.set_pixel(x, y, Color(
				clampf(muted.r * vignette + grain, 0.0, 1.0),
				clampf(muted.g * vignette + grain, 0.0, 1.0),
				clampf(muted.b * vignette + grain, 0.0, 1.0)
			))
