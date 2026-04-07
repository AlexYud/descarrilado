extends SpotLight3D

var flashlight_on: bool = true
var flicker_timer: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	visible = flashlight_on

func _process(delta: float) -> void:
	# Toggle flashlight on/off
	if Input.is_action_just_pressed("flashlight"):
		flashlight_on = !flashlight_on
		visible = flashlight_on
	
	# If flashlight is on, apply flicker randomly
	if flashlight_on:
		flicker_timer -= delta
		if flicker_timer <= 0.0:
			# Small chance of flickering
			if rng.randi_range(0, 100) < 10: # 10% chance each interval
				visible = false
				flicker_timer = rng.randf_range(0.05, 0.2) # short off
			else:
				visible = true
				flicker_timer = rng.randf_range(0.05, 0.2) # short on
