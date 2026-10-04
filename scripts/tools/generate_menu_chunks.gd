@tool
extends EditorScript

## Run from the Script Editor with File > Run (Ctrl+Shift+X). Rebuilds the four
## main-menu scenery chunks (scenes/menu/scenery/menu_scenery_chunk_a..d.tscn)
## as one seamless 128 m loop. See menu_chunk_generator.gd for the layout and
## the knobs. It overwrites the chunk scenes and writes generated meshes to
## scenes/menu/scenery/generated/. Do not edit the chunks by hand; rerun this.

const Generator := preload("res://scripts/tools/menu_chunk_generator.gd")


func _run() -> void:
	var generator = Generator.new()
	var started: int = Time.get_ticks_msec()
	var summary: Dictionary = generator.generate()
	print(
		"Menu chunks rebuilt in %.1f s: %s"
		% [float(Time.get_ticks_msec() - started) / 1000.0, summary]
	)
