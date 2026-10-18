extends SceneTree

## One-off: makes the tinted materials the forest-floor plants use (the Terrain3D mesh assets' `material_override`),
## because instance colours do not reach these models' materials. Each is the model's own material (same
## texture, alpha cut-out and double sides) with a darker, less pale `albedo_color`, so the pale tufts, leaf
## cards and rocks stop glowing in the flashlight and sit in the leaf floor.
## Run: `Godot --headless --path . -s res://scripts/tools/make_tinted_materials.gd`

const OUT_DIRECTORY: String = "res://assets/materials/forest"
const SOURCES: Dictionary = {
	"tufts_small_01": ["res://assets/models/foliage/small_foliage_01/small_foliage_01.glb", Color(0.5, 0.52, 0.4)],
	"tufts_small_02": ["res://assets/models/foliage/small_foliage_02/small_foliage_02.glb", Color(0.5, 0.52, 0.4)],
	"fallen_leaves": ["res://assets/models/foliage/ground_leaves_01/ground_leaves_01.glb", Color(0.38, 0.3, 0.22)],
	"rock_001": ["res://assets/models/rocks/floor_path/rock_001/rock_001.glb", Color(0.36, 0.36, 0.33)],
	"rock_002": ["res://assets/models/rocks/floor_path/rock_002/rock_002.glb", Color(0.36, 0.36, 0.33)],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIRECTORY))
	for key: String in SOURCES:
		var entry: Array = SOURCES[key]
		var root: Node = (load(str(entry[0])) as PackedScene).instantiate()
		var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
		if found.is_empty():
			push_error("No mesh in " + str(entry[0]))
			root.free()
			continue

		var mesh: Mesh = (found[0] as MeshInstance3D).mesh
		var source: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
		if source == null:
			push_error("No standard material in " + str(entry[0]))
			root.free()
			continue

		var tinted: StandardMaterial3D = source.duplicate() as StandardMaterial3D
		tinted.albedo_color = entry[1] as Color
		var path: String = "%s/%s_tinted.tres" % [OUT_DIRECTORY, key]
		var result: Error = ResourceSaver.save(tinted, path)
		print("saved ", path, " ", error_string(result))
		root.free()

	quit()
