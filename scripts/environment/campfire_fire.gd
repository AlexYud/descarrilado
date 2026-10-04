extends Node3D
class_name CampfireFire

## Flames, embers, a flickering warm light and a crackle for a campfire. Place
## it on top of the campfire model. `extinguish()` kills all of it at once, with
## no fade and no smoke, as if the scene had cut; `ignite()` brings it back.
##
## The light is a single OmniLight3D without shadows, to stay cheap. Crackle is
## a generated placeholder until a recording is assigned to `crackle_stream`.

signal extinguished

@export var starts_lit: bool = true
@export var light_energy_lit: float = 2.4

## How strongly the light wavers (0 = steady) and how fast.
@export_range(0.0, 0.6, 0.01) var flicker_amount: float = 0.22
@export var flicker_speed: float = 9.0

## Optional recorded crackle; null uses the generated placeholder.
@export var crackle_stream: AudioStream

@onready var light: OmniLight3D = $Light
@onready var flames: GPUParticles3D = $Flames
@onready var embers: GPUParticles3D = $Embers
@onready var crackle: AudioStreamPlayer3D = $Crackle

var is_lit: bool = false

var _phase: float = 0.0


func _ready() -> void:
	_phase = randf() * 100.0
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

	if lit:
		light.light_energy = light_energy_lit
		crackle.play()
	else:
		crackle.stop()
