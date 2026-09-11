extends Path3D


# ============================================================
# TRAIN MOVEMENT
# ============================================================

@export_category("Train Movement")

@export var movement_speed: float = 0
@export var wagon_spacing: float = 14.0
@export var start_progress: float = 0.0

## Keep this disabled for the stationary menu train.
@export var move_train: bool = false


# ============================================================
# STARTUP POSITION
# ============================================================

@export_category("Startup Position")

## When the train is stopped, preserve every PathFollow3D
## exactly where it was placed in the editor.
##
## This prevents the train and camera from snapping to the
## start of the Path3D when the menu begins.
@export var preserve_editor_positions_when_stopped: bool = true

## When movement is enabled, begin from WagonFollow's current
## editor progress instead of Start Progress.
@export var use_editor_progress_when_moving: bool = true


# ============================================================
# WAGON REFERENCES
# ============================================================

@onready var wagon_follow_1: PathFollow3D = $WagonFollow
@onready var wagon_follow_2: PathFollow3D = $WagonFollow2
@onready var wagon_follow_3: PathFollow3D = $WagonFollow3
@onready var wagon_follow_4: PathFollow3D = $WagonFollow4


# ============================================================
# RUNTIME
# ============================================================

var current_progress: float = 0.0
var slowdown_tween: Tween = null


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	wagon_follow_1.loop = true
	wagon_follow_2.loop = true
	wagon_follow_3.loop = true
	wagon_follow_4.loop = true

	# The new menu uses a stationary train.
	# Do not overwrite any editor-authored wagon positions.
	if (
		not move_train
		and preserve_editor_positions_when_stopped
	):
		current_progress = wagon_follow_1.progress
		return

	if use_editor_progress_when_moving:
		current_progress = wagon_follow_1.progress
	else:
		current_progress = start_progress

	_update_wagon_positions()


# ============================================================
# MOVEMENT
# ============================================================

func _process(delta: float) -> void:
	if not move_train:
		return

	if is_zero_approx(movement_speed):
		return

	current_progress += movement_speed * delta

	_update_wagon_positions()


func _update_wagon_positions() -> void:
	wagon_follow_1.progress = current_progress

	wagon_follow_2.progress = (
		current_progress
		- wagon_spacing
	)

	wagon_follow_3.progress = (
		current_progress
		- wagon_spacing * 2.0
	)

	wagon_follow_4.progress = (
		current_progress
		- wagon_spacing * 3.0
	)


# ============================================================
# OPTIONAL MOVEMENT CONTROL
# ============================================================

func smooth_stop(duration: float = 0.8) -> void:
	if not move_train:
		return

	_cancel_slowdown_tween()

	var stop_duration: float = maxf(
		duration,
		0.0
	)

	if stop_duration <= 0.0:
		movement_speed = 0.0
		move_train = false
		return

	var starting_speed: float = movement_speed

	slowdown_tween = create_tween()

	slowdown_tween.tween_method(
		_set_movement_speed,
		starting_speed,
		0.0,
		stop_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	await slowdown_tween.finished

	movement_speed = 0.0
	move_train = false
	slowdown_tween = null


func resume_train() -> void:
	_cancel_slowdown_tween()

	if is_zero_approx(movement_speed):
		movement_speed = 6.0

	move_train = true


func stop_immediate() -> void:
	_cancel_slowdown_tween()

	movement_speed = 0.0
	move_train = false


func _set_movement_speed(new_speed: float) -> void:
	movement_speed = maxf(
		new_speed,
		0.0
	)


func _cancel_slowdown_tween() -> void:
	if slowdown_tween == null:
		return

	if slowdown_tween.is_valid():
		slowdown_tween.kill()

	slowdown_tween = null
