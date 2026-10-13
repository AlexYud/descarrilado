@tool
extends Node3D
class_name OverlookPhoneDressing

## The set round the overlook's payphone, built in code so it can be played before
## real art exists: a curved concrete ledge over the valley, a rusted chain-link
## fence along its edge (one broken stretch) and a single streetlamp that throws a
## dim cone of light over the booth. Local space: the booth stands at the origin
## facing +Z, the valley is behind it (-Z), the ground is y = 0.
##
## Everything here is placeholder; the real fence and lamp replace it when the
## booth is merged into the overlook of the dream intro, which already has its own
## fence and bench.

## The ledge is a disc whose far edge is `edge_distance` behind the booth.
## The test scene has nothing else, so it builds its own ledge and fence. In the dream
## intro the overlook already has its ground, its barbed fence and its bench: turn both
## off there and only the lamp and the mist are built.
@export var build_ledge: bool = true
@export var build_fence: bool = true
@export var edge_distance: float = 3.4
@export var ledge_radius: float = 8.5
## The fence follows the ledge's edge, this far inside it.
@export var fence_inset: float = 0.55
@export var fence_height: float = 1.55
## Half the angle the fence covers, seen from the middle of the ledge.
@export var fence_half_angle_degrees: float = 52.0
@export var lamp_position: Vector3 = Vector3(-2.3, 0.0, 1.5)
@export var lamp_height: float = 3.9
@export var lamp_energy: float = 9.0
## How strong the halo, the haze and the light shaft round the lamp are, as a fraction of
## the test scene's (1). The dream intro, already dark and misty, wants them subtler.
@export_range(0.0, 1.5, 0.05) var glow_strength: float = 1.0

const POST_SPACING_DEGREES: float = 5.5

## The lamp burns steadily. It only flickers when the scene asks it to (`play_flicker`), in
## scripted patterns made to be unsettling: segments of [level, seconds, ramp], where the
## lamp holds `level` (0 dark, 1 full) for `seconds`, or, with `ramp`, slides to it over
## that time. Every pattern ends with the lamp at full power.
const FLICKERS: Dictionary = {
	# When the voice on the line begins: the light sags, catches, sputters and dies for
	# a long moment, twitches in the dark, and comes back as if nothing had happened.
	&"start": [
		[0.7, 1.0, true], [1.0, 0.12, false], [0.25, 0.05, false], [1.0, 0.07, false],
		[0.0, 0.55, false], [0.5, 0.04, false], [0.0, 0.4, false], [0.9, 0.05, false],
		[0.0, 0.18, false], [0.3, 0.04, false], [1.0, 0.06, false], [0.0, 0.75, false],
		[0.35, 0.05, false], [1.0, 0.5, true],
	],
	# When it ends: a nervous run of stutters, then a long darkness with one faint
	# twitch of light in it, and a hard strike back to full.
	&"end": [
		[0.6, 0.06, false], [1.0, 0.05, false], [0.1, 0.05, false], [0.85, 0.04, false],
		[0.0, 0.07, false], [1.0, 0.05, false], [0.0, 0.05, false], [0.55, 0.04, false],
		[0.0, 0.9, false], [0.25, 0.07, false], [0.0, 1.3, false], [0.12, 0.05, false],
		[0.0, 0.45, false], [1.0, 0.08, false],
	],
}

signal flicker_started(kind: StringName)
signal flicker_finished(kind: StringName)

var _spot: SpotLight3D = null
var _lens_material: StandardMaterial3D = null
var _glow_material: ShaderMaterial = null
var _shaft_material: ShaderMaterial = null
var _wide_material: ShaderMaterial = null
var _level: float = 1.0
var _script: Array = []
var _script_kind: StringName = &""
var _script_index: int = 0
var _script_time: float = 0.0
var _script_from: float = 1.0
var _hum: AudioStreamPlayer = null
var _spot_colour: Color = Color.WHITE


func _ready() -> void:
	if get_child_count() > 0:
		return

	if build_ledge:
		_build_ledge()

	if build_fence:
		_build_fence()

	_build_lamp()
	_build_mist()


func _ledge_center() -> Vector3:
	return Vector3(0.0, -0.15, ledge_radius - edge_distance)


func _build_ledge() -> void:
	var concrete: StandardMaterial3D = JunctionProps.weathered(JunctionProps.CONCRETE, 1.4, 0.95)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ledge"
	body.position = _ledge_center()
	add_child(body)

	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = ledge_radius
	mesh.bottom_radius = ledge_radius
	mesh.height = 0.3
	mesh.radial_segments = 72
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = concrete
	body.add_child(instance)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = ledge_radius
	cylinder.height = 0.3
	shape.shape = cylinder
	body.add_child(shape)

	# A kerb along the edge: a lower lip, a darker stain below the edge.
	var kerb: MeshInstance3D = HouseProps.add_cylinder(
		body, "Kerb", ledge_radius + 0.06, 0.12, Vector3(0.0, -0.1, 0.0),
		JunctionProps.weathered(JunctionProps.CONCRETE_DARK, 1.4, 0.95)
	)
	kerb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_fence() -> void:
	var center: Vector3 = _ledge_center()
	var radius: float = ledge_radius - fence_inset
	var rust: StandardMaterial3D = JunctionProps.weathered(JunctionProps.RUST, 3.0, 0.9, 0.5)
	var mesh_material: StandardMaterial3D = _chain_link_material()

	var fence: Node3D = Node3D.new()
	fence.name = "Fence"
	add_child(fence)

	var previous: Vector3 = Vector3.ZERO
	var has_previous: bool = false
	var step: int = 0
	var angle: float = -fence_half_angle_degrees
	while angle <= fence_half_angle_degrees + 0.01:
		var direction: Vector3 = Vector3(sin(deg_to_rad(angle)), 0.0, -cos(deg_to_rad(angle)))
		var post_position: Vector3 = Vector3(center.x, 0.0, center.z) + direction * radius
		HouseProps.add_cylinder(
			fence, "Post%d" % step, 0.028, fence_height + 0.1,
			post_position + Vector3(0.0, (fence_height + 0.1) * 0.5, 0.0), rust
		)

		if has_previous:
			_add_panel(fence, step, previous, post_position, mesh_material, rust, step == 4)

		previous = post_position
		has_previous = true
		step += 1
		angle += POST_SPACING_DEGREES


## One stretch of chain link between two posts, with a top rail and a bottom wire;
## `torn` sags and leaves a hole.
func _add_panel(parent: Node3D, index: int, from: Vector3, to: Vector3, mesh_material: Material, rust: Material, torn: bool) -> void:
	var length: float = from.distance_to(to)
	var middle: Vector3 = (from + to) * 0.5
	var along: Vector3 = (to - from).normalized()
	var panel_basis: Basis = Basis.looking_at(along.cross(Vector3.UP), Vector3.UP)

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(length, fence_height - 0.05)
	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.name = "Mesh%d" % index
	panel.mesh = quad
	panel.material_override = mesh_material
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.transform = Transform3D(panel_basis, middle + Vector3(0.0, (fence_height - 0.05) * 0.5 + 0.03, 0.0))
	parent.add_child(panel)

	var rail: MeshInstance3D = HouseProps.add_cylinder(parent, "Rail%d" % index, 0.014, length, middle + Vector3(0.0, fence_height, 0.0), rust)
	rail.transform = Transform3D(Basis.looking_at(along, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(90.0)), rail.position)

	if torn:
		# Peeled back from the bottom: a ragged flap leaning outwards.
		var flap: MeshInstance3D = HouseProps.add_box(
			parent, "Flap%d" % index, Vector3(length * 0.45, 0.02, 0.5),
			middle + Vector3(0.0, 0.2, 0.0), rust
		)
		flap.transform = Transform3D(panel_basis * Basis(Vector3.RIGHT, deg_to_rad(-25.0)), flap.position)


## A diamond lattice with transparent holes, tiled along the panel.
func _chain_link_material() -> StandardMaterial3D:
	var size: int = 48
	var image: Image = Image.create(size, size, true, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var wire: Color = Color(0.36, 0.22, 0.14, 1.0)
	for i: int in size:
		for thickness: int in 2:
			var a: int = (i + thickness) % size
			image.set_pixel(a, i, wire)
			image.set_pixel((size - 1 - a), i, wire)

	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.8
	material.metallic = 0.5
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(14.0, 20.0, 1.0)
	return material


## A concrete pole with a bent arm and a lamp head; a spot throws a dim cone of
## sodium-yellow light over the booth.
func _build_lamp() -> void:
	var pole: StandardMaterial3D = JunctionProps.weathered(Color(0.22, 0.22, 0.23), 4.0, 0.7, 0.5)
	var lamp: Node3D = Node3D.new()
	lamp.name = "Streetlamp"
	lamp.position = lamp_position
	add_child(lamp)

	var base: MeshInstance3D = HouseProps.add_cylinder(lamp, "Base", 0.14, 0.4, Vector3(0.0, 0.2, 0.0), JunctionProps.weathered(JunctionProps.CONCRETE, 2.0, 0.95))
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	HouseProps.add_cylinder(lamp, "Pole", 0.055, lamp_height, Vector3(0.0, lamp_height * 0.5, 0.0), pole)

	# The arm bends towards the booth.
	var toward: Vector3 = (Vector3(0.0, 0.0, 0.0) - lamp_position)
	toward.y = 0.0
	toward = toward.normalized()
	var arm_length: float = 1.3
	var arm: MeshInstance3D = HouseProps.add_cylinder(lamp, "Arm", 0.035, arm_length, Vector3.ZERO, pole)
	arm.transform = Transform3D(
		Basis.looking_at(toward, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(90.0)),
		Vector3(0.0, lamp_height + 0.05, 0.0) + toward * arm_length * 0.5
	)
	var head_position: Vector3 = Vector3(0.0, lamp_height + 0.05, 0.0) + toward * arm_length

	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = head_position
	head.basis = Basis.looking_at(toward, Vector3.UP)
	lamp.add_child(head)
	HouseProps.add_box(head, "Housing", Vector3(0.3, 0.07, 0.62), Vector3(0.0, 0.0, -0.15), pole)

	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.95, 0.82)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.9, 0.68)
	glow.emission_energy_multiplier = 2.4
	var lens: MeshInstance3D = HouseProps.add_box(head, "Lens", Vector3(0.24, 0.01, 0.5), Vector3(0.0, -0.04, -0.15), glow)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lens_material = glow

	var spot: SpotLight3D = SpotLight3D.new()
	spot.name = "Cone"
	spot.light_color = Color(1.0, 0.9, 0.72)
	spot.light_energy = lamp_energy
	spot.spot_range = 9.0
	spot.spot_angle = 34.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 1.6
	spot.position = head_position + Vector3(0.0, -0.1, 0.0) + toward * -0.1
	lamp.add_child(spot)
	# Aimed at the booth: the cone's axis is the spot's -Z.
	var target: Vector3 = Vector3(0.0, 1.0, 0.1) - (lamp_position + spot.position)
	spot.basis = Basis.looking_at(target.normalized(), Vector3.UP)
	_spot = spot
	_spot_colour = spot.light_color
	_add_glow_and_shaft(lamp, head, spot, target)
	_build_hum()


## A soft halo round the lens and a faint shaft of light down to the booth, so the lamp
## glows through the mist at every quality setting (the real fog adds to it where it is on).
func _add_glow_and_shaft(lamp: Node3D, head: Node3D, spot: SpotLight3D, target: Vector3) -> void:
	var halo_shader: Shader = Shader.new()
	halo_shader.code = "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 tint = vec3(1.0, 0.8, 0.5);
uniform float intensity = 0.8;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 2.4);
	ALBEDO = tint;
	ALPHA = glow * intensity;
}
"
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = halo_shader

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(3.2, 3.2)
	var halo: MeshInstance3D = MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = quad
	halo.material_override = _glow_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = Vector3(0.0, -0.05, -0.15)
	head.add_child(halo)

	# A far wider, fainter, cooler haze round it: the lamp lights the mist, not just itself.
	_wide_material = ShaderMaterial.new()
	_wide_material.shader = halo_shader
	_wide_material.set_shader_parameter("tint", Vector3(0.62, 0.74, 0.92))
	_wide_material.set_shader_parameter("intensity", 0.25)
	var wide_quad: QuadMesh = QuadMesh.new()
	wide_quad.size = Vector2(9.0, 9.0)
	var wide: MeshInstance3D = MeshInstance3D.new()
	wide.name = "Haze"
	wide.mesh = wide_quad
	wide.material_override = _wide_material
	wide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wide.position = Vector3(0.0, -0.1, -0.2)
	head.add_child(wide)

	# The shaft: a cone from the lamp to the booth, brightest at its edges' middle and
	# fading as it widens.
	var direction: Vector3 = target.normalized()
	var length: float = target.length()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = length * tan(deg_to_rad(spot.spot_angle * 0.85))
	cone.height = length
	cone.radial_segments = 32
	cone.rings = 1

	var shader: Shader = Shader.new()
	shader.code = "shader_type spatial;\nrender_mode blend_add, unshaded, cull_disabled, depth_draw_never;\nuniform vec3 tint = vec3(1.0, 0.78, 0.45);\nuniform float intensity = 0.1;\nuniform float height = 4.0;\nvarying float along;\nvoid vertex() {\n\talong = VERTEX.y / height + 0.5;\n}\nvoid fragment() {\n\tfloat edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);\n\tfloat fade = pow(clamp(along, 0.0, 1.0), 1.3);\n\tALBEDO = tint;\n\tALPHA = intensity * edge * fade;\n}\n"
	_shaft_material = ShaderMaterial.new()
	_shaft_material.shader = shader
	_shaft_material.set_shader_parameter("height", length)

	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = cone
	shaft.material_override = _shaft_material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var axis: Quaternion = Quaternion(Vector3.UP, -direction)
	shaft.transform = Transform3D(Basis(axis), spot.position + direction * length * 0.5)
	lamp.add_child(shaft)


## Mist round the booth, for the lamp's light to scatter in (it shows where the
## game's volumetric fog is on).
func _build_mist() -> void:
	var volume: FogVolume = FogVolume.new()
	volume.name = "Mist"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	volume.size = Vector3(12.0, 5.0, 12.0)
	volume.position = Vector3(-0.8, 1.5, 0.6)
	var material: FogMaterial = FogMaterial.new()
	material.density = 0.022
	material.albedo = Color(0.74, 0.82, 0.92)
	material.emission = Color(0.012, 0.018, 0.026)
	material.edge_fade = 0.5
	volume.material = material
	add_child(volume)


## The lamp's light right now, 0 (dark) to 1 (full).
func get_lamp_level() -> float:
	return _level


func is_flickering() -> bool:
	return not _script.is_empty()


## Plays a scripted flicker (see `FLICKERS`: &"start" or &"end"); the lamp is at full power
## afterwards. Await it to know when it is over.
func play_flicker(kind: StringName) -> void:
	if not FLICKERS.has(kind) or _spot == null:
		return

	_script = FLICKERS[kind]
	_script_kind = kind
	_script_index = 0
	_script_time = 0.0
	_script_from = _level
	flicker_started.emit(kind)
	while _script_kind == kind and not _script.is_empty():
		await flicker_finished


func _process(delta: float) -> void:
	if _spot == null or Engine.is_editor_hint():
		return

	var level: float = 1.0
	if not _script.is_empty():
		var segment: Array = _script[_script_index]
		var length: float = maxf(float(segment[1]), 0.001)
		_script_time += delta
		if bool(segment[2]):
			level = lerpf(_script_from, float(segment[0]), clampf(_script_time / length, 0.0, 1.0))
		else:
			level = float(segment[0])

		if _script_time >= length:
			_script_from = float(segment[0])
			_script_time -= length
			_script_index += 1
			if _script_index >= _script.size():
				var kind: StringName = _script_kind
				_script = []
				level = 1.0
				flicker_finished.emit(kind)

	_set_lamp_level(level)


func _set_lamp_level(level: float) -> void:
	# A strike after darkness: a hard electric pop.
	if _level < 0.15 and level > 0.5 and _hum != null:
		_play_pop()

	_level = level
	_spot.light_energy = lamp_energy * level
	_spot.light_volumetric_fog_energy = 1.6 * level * glow_strength
	# A failing lamp goes cold and sickly as it dims.
	_spot.light_color = _spot_colour.lerp(Color(0.7, 0.85, 1.0), clampf(1.0 - level, 0.0, 1.0) * 0.8)
	if _lens_material != null:
		_lens_material.emission_energy_multiplier = 2.4 * level

	if _glow_material != null:
		_glow_material.set_shader_parameter("intensity", 0.8 * level * glow_strength)
	if _wide_material != null:
		_wide_material.set_shader_parameter("intensity", 0.25 * level * glow_strength)

	if _shaft_material != null:
		_shaft_material.set_shader_parameter("intensity", 0.055 * level * glow_strength)

	# The electrical hum is only there while the lamp is misbehaving, and dies with it.
	if _hum != null:
		_hum.volume_db = lerpf(-60.0, -24.0, level) if is_flickering() else -80.0


func _build_hum() -> void:
	if Engine.is_editor_hint():
		return

	_hum = AudioStreamPlayer.new()
	_hum.name = "Hum"
	_hum.stream = PlaceholderAudio.make_lamp_hum()
	_hum.volume_db = -80.0
	add_child(_hum)
	_hum.play()


func _play_pop() -> void:
	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.stream = PlaceholderAudio.make_lamp_pop()
	voice.volume_db = -12.0
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
