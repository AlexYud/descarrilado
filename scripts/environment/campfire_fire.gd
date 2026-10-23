extends Node3D
class_name CampfireFire

## Flames, embers, a flickering warm light and a crackle for a campfire. Place
## it on top of the campfire model. `extinguish()` kills all of it at once, with
## no fade and no smoke, as if the scene had cut, and leaves the pit with cold grey ash (a flat
## mound and a paler heap under it, built in code); `ignite()` brings the fire back.
##
## The light is a single OmniLight3D without shadows, to stay cheap. Crackle is
## a generated placeholder until a recording is assigned to `crackle_stream`.

signal extinguished

@export var starts_lit: bool = true
@export var light_energy_lit: float = 2.4

## How strongly the light wavers (0 = steady) and how fast.
@export_range(0.0, 0.6, 0.01) var flicker_amount: float = 0.22
@export var flicker_speed: float = 9.0

## The recorded crackle, a looping sound (the fire scene sets `campfire_placeholder.wav`); null uses the generated
## placeholder.
@export var crackle_stream: AudioStream

@onready var light: OmniLight3D = $Light
@onready var flames: GPUParticles3D = $Flames
@onready var embers: GPUParticles3D = $Embers
@onready var crackle: AudioStreamPlayer3D = $Crackle

var is_lit: bool = false

var _phase: float = 0.0
var _ash: Node3D = null


func _ready() -> void:
	_phase = randf() * 100.0
	_build_ash()
	crackle.stream = crackle_stream if crackle_stream != null else (
		PlaceholderAudio.make_fire_crackle()
	)
	_set_lit(starts_lit)


func _process(_delta: float) -> void:
	if not is_lit:
		return

	var t: float = Time.get_ticks_msec() / 1000.0 * flicker_speed + _phase
	var wobble: float = (
		0.6 * sin(t) + 0.3 * sin(t * 2.3 + 1.7) + 0.1 * sin(t * 5.1)
	)
	light.light_energy = light_energy_lit * (1.0 + flicker_amount * wobble)


func ignite() -> void:
	if is_lit:
		return

	_set_lit(true)


## Puts the fire out instantly: flames, embers, light and sound all stop in the
## same frame. The particles are hidden too, so none linger.
func extinguish() -> void:
	if not is_lit:
		return

	_set_lit(false)
	extinguished.emit()


func _set_lit(lit: bool) -> void:
	is_lit = lit
	flames.visible = lit
	embers.visible = lit
	flames.emitting = lit
	embers.emitting = lit
	light.visible = lit
	if _ash != null:
		_ash.visible = not lit

	if lit:
		light.light_energy = light_energy_lit
		crackle.play()
	else:
		crackle.stop()


## Cold ash for the burnt-out pit: a dark flat mound with a paler, lumpier heap on it. Hidden while the
## fire burns.
func _build_ash() -> void:
	_ash = Node3D.new()
	_ash.name = "ColdAsh"
	add_child(_ash)

	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.13)
	dark.roughness = 1.0
	var pale: StandardMaterial3D = StandardMaterial3D.new()
	pale.albedo_color = Color(0.42, 0.42, 0.4)
	pale.roughness = 1.0

	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 0.3
	base_mesh.bottom_radius = 0.36
	base_mesh.height = 0.05
	base_mesh.radial_segments = 12
	base.mesh = base_mesh
	base.material_override = dark
	base.position = Vector3(0.0, 0.0, 0.0)
	_ash.add_child(base)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	for i: int in 6:
		var lump: MeshInstance3D = MeshInstance3D.new()
		var lump_mesh: SphereMesh = SphereMesh.new()
		var radius: float = rng.randf_range(0.06, 0.11)
		lump_mesh.radius = radius
		lump_mesh.height = radius * 1.3
		lump_mesh.radial_segments = 8
		lump_mesh.rings = 4
		lump.mesh = lump_mesh
		lump.material_override = pale if i % 3 != 0 else dark
		var angle: float = TAU * float(i) / 6.0 + rng.randf() * 0.5
		lump.position = Vector3(cos(angle) * rng.randf_range(0.02, 0.2), 0.04, sin(angle) * rng.randf_range(0.02, 0.2))
		_ash.add_child(lump)

	_ash.visible = false
