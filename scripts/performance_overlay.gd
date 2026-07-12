extends Label

@export var visible_in_game: bool = true
@export var update_interval: float = 0.25

var update_timer: float = 0.0


func _ready() -> void:
	visible = visible_in_game

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0

	offset_left = 16.0
	offset_top = 16.0
	offset_right = 420.0
	offset_bottom = 160.0

	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1.0))
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("outline_size", 4)


func _process(delta: float) -> void:
	update_timer -= delta

	if update_timer > 0.0:
		return

	update_timer = update_interval
	_update_text()


func _update_text() -> void:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects: float = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var primitives: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var video_memory_mb: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024.0 / 1024.0

	text = "FPS: %d\nDraw Calls: %d\nObjects: %d\nPrimitives: %d\nVideo Memory: %.1f MB" % [
		int(fps),
		int(draw_calls),
		int(objects),
		int(primitives),
		video_memory_mb
	]
