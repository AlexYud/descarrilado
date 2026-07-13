extends Path3D

@export_category("Train Movement")
@export var movement_speed: float = 6.0
@export var wagon_spacing: float = 14.0
@export var start_progress: float = 0.0
@export var move_train: bool = true

@onready var wagon_follow_1: PathFollow3D = $WagonFollow
@onready var wagon_follow_2: PathFollow3D = $WagonFollow2
@onready var wagon_follow_3: PathFollow3D = $WagonFollow3
@onready var wagon_follow_4: PathFollow3D = $WagonFollow4

var current_progress: float = 0.0


func _ready() -> void:
	current_progress = start_progress

	wagon_follow_1.loop = true
	wagon_follow_2.loop = true
	wagon_follow_3.loop = true
	wagon_follow_4.loop = true

	_update_wagon_positions()


func _process(delta: float) -> void:
	if not move_train:
		return

	current_progress += movement_speed * delta
	_update_wagon_positions()


func _update_wagon_positions() -> void:
	wagon_follow_1.progress = current_progress
	wagon_follow_2.progress = current_progress - wagon_spacing
	wagon_follow_3.progress = current_progress - wagon_spacing * 2.0
	wagon_follow_4.progress = current_progress - wagon_spacing * 3.0
