extends Node3D
class_name TrainLightFlicker

@export var flicker_enabled: bool = true

@export var base_energy: float = 2
@export var min_energy: float = 0.15
@export var max_energy: float = 0.9

#@export var flicker_chance: float = 0.09
@export var flicker_chance: float = 0
@export var min_wait_time: float = 0.08
@export var max_wait_time: float = 0.35

#@export var hard_flicker_chance: float = 0.04
@export var hard_flicker_chance: float = 0
@export var hard_flicker_duration: float = 0.06

@export var panic_flicker_chance: float = 0.75
@export var panic_min_energy: float = 0.0
@export var panic_max_energy: float = 1.1
@export var panic_min_wait_time: float = 0.025
@export var panic_max_wait_time: float = 0.12
@export var panic_hard_flicker_chance: float = 0.22
@export var panic_hard_flicker_duration: float = 0.08

var lights: Array[OmniLight3D] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var flicker_timer: float = 0.0

var panic_flicker_active: bool = false
var blackout_active: bool = false
var hard_flicker_running: bool = false


func _ready() -> void:
	rng.randomize()
	_collect_lights()
	_reset_timer()

	for light: OmniLight3D in lights:
		light.light_energy = base_energy
		light.visible = true


func _process(delta: float) -> void:
	if not flicker_enabled:
		return

	if blackout_active:
		return

	if hard_flicker_running:
		return

	flicker_timer -= delta

	if flicker_timer > 0.0:
		return

	_do_flicker()
	_reset_timer()


func start_panic_flicker() -> void:
	blackout_active = false
	panic_flicker_active = true
	flicker_enabled = true
	flicker_timer = 0.0

	for light: OmniLight3D in lights:
		light.visible = true


func stop_panic_flicker() -> void:
	panic_flicker_active = false
	hard_flicker_running = false
	flicker_timer = 0.0

	for light: OmniLight3D in lights:
		light.visible = true
		light.light_energy = base_energy


func blackout_lights() -> void:
	panic_flicker_active = false
	hard_flicker_running = false
	blackout_active = true

	for light: OmniLight3D in lights:
		light.light_energy = 0.0
		light.visible = false


func blackout_with_final_flicker(duration: float = 0.8) -> void:
	blackout_active = false
	panic_flicker_active = true
	flicker_enabled = true
	flicker_timer = 0.0

	if duration > 0.0:
		await get_tree().create_timer(duration).timeout

	blackout_lights()


func restore_lights() -> void:
	blackout_active = false
	panic_flicker_active = false
	hard_flicker_running = false
	flicker_enabled = true
	flicker_timer = 0.0

	for light: OmniLight3D in lights:
		light.visible = true
		light.light_energy = base_energy


func _collect_lights() -> void:
	lights.clear()

	for child in get_children():
		var light: OmniLight3D = child as OmniLight3D

		if light != null:
			lights.append(light)


func _do_flicker() -> void:
	if lights.is_empty():
		return

	var current_flicker_chance: float = flicker_chance
	var current_min_energy: float = min_energy
	var current_max_energy: float = max_energy
	var current_hard_chance: float = hard_flicker_chance
	var current_hard_duration: float = hard_flicker_duration

	if panic_flicker_active:
		current_flicker_chance = panic_flicker_chance
		current_min_energy = panic_min_energy
		current_max_energy = panic_max_energy
		current_hard_chance = panic_hard_flicker_chance
		current_hard_duration = panic_hard_flicker_duration

	if rng.randf() > current_flicker_chance:
		for light: OmniLight3D in lights:
			light.visible = true
			light.light_energy = base_energy
		return

	var hard_flicker: bool = rng.randf() <= current_hard_chance

	if hard_flicker:
		hard_flicker_running = true

		if panic_flicker_active:
			for light: OmniLight3D in lights:
				light.visible = true
				light.light_energy = panic_min_energy
		else:
			for light: OmniLight3D in lights:
				light.visible = false
				light.light_energy = 0.0

		await get_tree().create_timer(current_hard_duration).timeout

		if blackout_active:
			hard_flicker_running = false
			return

		for light: OmniLight3D in lights:
			light.visible = true
			light.light_energy = base_energy

		hard_flicker_running = false
		return

	for light: OmniLight3D in lights:
		light.visible = true
		light.light_energy = rng.randf_range(current_min_energy, current_max_energy)


func _reset_timer() -> void:
	if panic_flicker_active:
		flicker_timer = rng.randf_range(panic_min_wait_time, panic_max_wait_time)
	else:
		flicker_timer = rng.randf_range(min_wait_time, max_wait_time)
