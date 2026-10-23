extends Node3D
class_name ColdBreath

## The player's breath smoking in the cold air: now and then a few soft puffs of vapour leave the mouth (a little
## below and in front of the eyes), drift on the way the player looks, slow down, swell and thin out. They are left
## hanging in the air (not tied to the player), so walking on leaves a faint trail behind.
##
## The rhythm follows what the player does: slow when standing still, quicker walking, short and heavy running. It is
## silent and shows nothing while the player cannot move or is looking at something else (a cutscene, a dialogue, the
## inspect view, the inventory, the album, a held view). `cold` switches it off for warm places.
##
## Built in code (a billboard particle emitter and `cold_breath.gdshader`, which draws each particle as drifting noise that
## is eaten away until nothing is left, so the vapour thins out and vanishes in the air): there are no art assets. The player scene
## adds it under its camera; the player's `cold_breath_enabled` says whether the scene is cold.

## Below and in front of the camera's eye, where the mouth is.
const MOUTH_OFFSET: Vector3 = Vector3(0.0, -0.1, -0.17)
const NOISE_TEXTURE_SIZE: int = 128
const PUFF_LIFETIME: float = 1.3
const MAX_PARTICLES: int = 120
const VAPOUR_SHADER: Shader = preload("res://assets/shaders/cold_breath.gdshader")

## Seconds between two breaths while standing, walking and running, and how long each breath is blown for.
const STANDING_INTERVAL: float = 3.8
const WALKING_INTERVAL: float = 2.7
const RUNNING_INTERVAL: float = 1.35
const EXHALE_SECONDS: float = 0.4
const RUNNING_EXHALE_SECONDS: float = 0.34
## How many puffs there are, as a share of the most: a held breath is thin, a run is thick.
const STANDING_DENSITY: float = 0.4
const WALKING_DENSITY: float = 0.55
const RUNNING_DENSITY: float = 0.8

## False in warm places (the player's `cold_breath_enabled`).
var cold: bool = true
## The breath's colour: a pale, cold white; the alpha is how strong it shows.
var tint: Color = Color(0.78, 0.86, 0.95, 0.08)
## How many breaths were blown (the tests count them).
var exhale_count: int = 0
var is_exhaling: bool = false

var _player: CharacterBody3D = null
var _emitter: GPUParticles3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _until_next: float = 1.5
var _exhale_left: float = 0.0


func setup(player: CharacterBody3D) -> void:
	_player = player
	_rng.randomize()
	position = MOUTH_OFFSET
	_emitter = _make_emitter()
	add_child(_emitter)


func _process(delta: float) -> void:
	if _player == null or _emitter == null:
		return

	if not cold or not can_breathe_visibly():
		_stop_exhaling()
		# Hold the next breath back: it comes a moment after the player can be seen breathing again.
		_until_next = maxf(_until_next, 0.8)
		return

	if is_exhaling:
		_exhale_left -= delta
		if _exhale_left <= 0.0:
			_stop_exhaling()
		return

	_until_next -= delta
	if _until_next <= 0.0:
		_start_exhaling()


## False while the player is held, talking, inspecting something or in a menu: nothing is shown then.
func can_breathe_visibly() -> bool:
	var body: Variant = _player
	if bool(body.get("cutscene_frozen")) or bool(body.get("dialogue_frozen")) or bool(body.get("modal_ui_open")) or bool(body.get("view_locked")):
		return false

	var inspect: PlayerInspectController = body.get("inspect_controller") as PlayerInspectController
	if inspect != null and inspect.is_open():
		return false

	var inventory: InventoryUIController = body.get("inventory_ui_controller") as InventoryUIController
	return inventory == null or not inventory.is_inventory_open()


## What the player is doing, for the rhythm: 0 standing, 1 walking, 2 running.
func get_effort() -> int:
	var movement: PlayerMovementController = _player.get("movement_controller") as PlayerMovementController
	if movement != null and movement.is_sprinting and Vector2(_player.velocity.x, _player.velocity.z).length() > 0.5:
		return 2

	if Vector2(_player.velocity.x, _player.velocity.z).length() > 0.3:
		return 1

	return 0


## Seconds to the next breath for an effort level, a little different each time.
func interval_for(effort: int) -> float:
	var base: float = [STANDING_INTERVAL, WALKING_INTERVAL, RUNNING_INTERVAL][effort]
	return base * _rng.randf_range(0.85, 1.2)


func _start_exhaling() -> void:
	var effort: int = get_effort()
	is_exhaling = true
	exhale_count += 1
	_exhale_left = RUNNING_EXHALE_SECONDS if effort == 2 else EXHALE_SECONDS
	_emitter.amount_ratio = [STANDING_DENSITY, WALKING_DENSITY, RUNNING_DENSITY][effort]
	_emitter.emitting = true
	_until_next = interval_for(effort)


## The puffs already out live on to the end of their life; only new ones stop.
func _stop_exhaling() -> void:
	if is_exhaling:
		is_exhaling = false
		_emitter.emitting = false


func _make_emitter() -> GPUParticles3D:
	var emitter: GPUParticles3D = GPUParticles3D.new()
	emitter.name = "Vapour"
	emitter.amount = MAX_PARTICLES
	emitter.lifetime = PUFF_LIFETIME
	emitter.local_coords = false
	emitter.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	emitter.visibility_aabb = AABB(Vector3(-4.0, -4.0, -4.0), Vector3(8.0, 8.0, 8.0))
	emitter.emitting = false
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	# Out of the mouth: along the view (-Z of the camera), a little up, in a narrow fan.
	process.direction = Vector3(0.0, 0.2, -1.0)
	process.spread = 24.0
	# Breath leaves fast and is braked hard by the air: it billows out, slows, and hangs.
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.8
	process.damping_min = 1.6
	process.damping_max = 3.0
	process.gravity = Vector3(0.0, 0.06, 0.0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.02
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.9
	process.turbulence_noise_scale = 1.8
	process.turbulence_noise_speed = Vector3(0.0, 0.25, 0.0)
	process.turbulence_influence_min = 0.1
	process.turbulence_influence_max = 0.3
	process.scale_min = 0.5
	process.scale_max = 1.3

	# Small at the lips, billowing out as it cools.
	var growth: Curve = Curve.new()
	growth.add_point(Vector2(0.0, 0.3))
	growth.add_point(Vector2(0.35, 1.0))
	growth.add_point(Vector2(1.0, 1.4))
	var growth_texture: CurveTexture = CurveTexture.new()
	growth_texture.curve = growth
	process.scale_curve = growth_texture

	# It comes quickly and goes slowly; the shader eats it away besides.
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.08, 0.5, 1.0])
	fade.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.7), Color(1.0, 1.0, 1.0, 0.0)])
	var fade_texture: GradientTexture1D = GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	emitter.process_material = process

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	var vapour: ShaderMaterial = ShaderMaterial.new()
	vapour.shader = VAPOUR_SHADER
	vapour.set_shader_parameter("noise_texture", make_noise_texture())
	vapour.set_shader_parameter("tint", tint)
	quad.material = vapour
	emitter.draw_pass_1 = quad
	return emitter


## Seamless cloud noise for the vapour shader, in the red channel.
static func make_noise_texture() -> ImageTexture:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 4711
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var image: Image = noise.get_seamless_image(NOISE_TEXTURE_SIZE, NOISE_TEXTURE_SIZE)
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
