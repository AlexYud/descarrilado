extends SceneTree

## Bakes the game's UI theme to `resources/ui/the_hole_theme.tres` (the editor's project theme, so
## scenes preview in the game's look). At runtime `ThemeManager` rebuilds the same theme from
## `UIConfig`, so this file only matters in the editor: run it again after changing UIConfig.
##   godot --headless --script res://scripts/tools/build_ui_theme.gd

const OUTPUT_PATH: String = "res://resources/ui/the_hole_theme.tres"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var result: Error = ResourceSaver.save(UIConfig.build_theme(), OUTPUT_PATH)
	print("UI theme saved: ", error_string(result), " (", OUTPUT_PATH, ")")
	quit(0 if result == OK else 1)
