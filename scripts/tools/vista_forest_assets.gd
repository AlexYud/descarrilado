@tool
extends RefCounted
class_name VistaForestAssets

## Builds the vegetation meshes of the city overlook's vista, as Terrain3D mesh assets:
##
## - `canopy_<species>.tscn`: the far forest. A "canopy stand" is ONE opaque mesh (one surface,
##   one draw call) of a 64 x 64 m patch of the Atlantic forest seen from far away: dozens of
##   overlapping faceted foliage masses at different heights and tones, with slim emergent
##   araucárias in one of them. Leaf cards (the tree models) are see-through by nature, so far
##   slopes of them read as bald; solid crowns cover the mountains, are cheaper, and have no alpha
##   overdraw. Vertex colours only (no texture), flat shaded.
## - `tree_<species>.tscn`: the project's four tree models with their leaves darkened, for the
##   single trees near the overlook and in the town's yards.
##
## Terrain3D's instancer makes one draw call per mesh per 32 m cell, so the far forest is one
## canopy stand per 64 m block (see `TownVistaBuilder.plant_forest`).
## Run `scripts/tools/build_town_vista.tscn -- assets` (headless is fine).

const OUTPUT_DIRECTORY: String = "res://scenes/environment/vista_forest"
const CLUMP_SIZE: float = 64.0
## How far below its origin a canopy stand reaches (a stand on a slope stays seated on it).
const SKIRT_DEPTH: float = 12.0
## The single trees' leaves are darkened (the texture's pale edges bleed into the far mip levels
## and read as frosty leaves at night) and cut out tighter.
const LEAF_TINT: Color = Color(0.56, 0.62, 0.54)
const LEAF_CUTOUT: float = 0.78

## The tree models, in the order of `TownScenery.TREE_*`.
const SPECIES: Array[Dictionary] = [
	{"name": "medium", "path": "res://assets/models/trees/medium_generic_tree/mediun_generic_tree.glb"},
	{"name": "broad", "path": "res://assets/models/trees/custom_tree/tree_test.glb"},
	{"name": "pitangueira", "path": "res://assets/models/trees/pitangueira/pitangueira.glb"},
	{"name": "araucaria", "path": "res://assets/models/trees/araucaria/araucaria.glb"},
]

## The four kinds of canopy (the same indices): crown radius and height range (m), number of
## foliage masses, base colour, how many slim emergent araucárias rise above it.
const CANOPY: Array[Dictionary] = [
	{"name": "medium", "radius": Vector2(7.5, 10.5), "height": Vector2(4.0, 11.0), "count": 46, "color": Color(0.1, 0.2, 0.09), "emergent": 0},
	{"name": "broad", "radius": Vector2(8.0, 11.5), "height": Vector2(6.0, 13.0), "count": 40, "color": Color(0.09, 0.18, 0.12), "emergent": 0},
	{"name": "pitangueira", "radius": Vector2(6.5, 9.0), "height": Vector2(3.0, 9.0), "count": 54, "color": Color(0.13, 0.23, 0.09), "emergent": 0},
	{"name": "araucaria", "radius": Vector2(7.0, 10.0), "height": Vector2(4.0, 10.0), "count": 46, "color": Color(0.09, 0.19, 0.1), "emergent": 9},
]


static func scene_path(species: int) -> String:
	return "%s/canopy_%s.tscn" % [OUTPUT_DIRECTORY, CANOPY[species]["name"]]


static func tree_scene_path(species: int) -> String:
	return "%s/tree_%s.tscn" % [OUTPUT_DIRECTORY, SPECIES[species]["name"]]


func build() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIRECTORY)
	for species: int in SPECIES.size():
		var canopy: ArrayMesh = _build_canopy(species)
		_save_scene(canopy, "%s/canopy_%s.res" % [OUTPUT_DIRECTORY, CANOPY[species]["name"]], scene_path(species), "Canopy_%s" % CANOPY[species]["name"])
		var single: ArrayMesh = _build_tree(species)
		_save_scene(single, "%s/tree_%s.res" % [OUTPUT_DIRECTORY, SPECIES[species]["name"]], tree_scene_path(species), "Tree_%s" % SPECIES[species]["name"])
		print("  ", CANOPY[species]["name"], ": canopy ", _triangles(canopy), " triangles, tree ", _triangles(single))


func _triangles(mesh: Mesh) -> int:
	var total: int = 0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_INDEX] != null and not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
			total += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3

	return total


# ============================================================
# THE CANOPY
# ============================================================

## The foliage masses: lumpy, flattened spheres as flat-shaded triangles (triplets of unit-space
## points), a few shapes.
func _blob_shapes() -> Array[PackedVector3Array]:
	var shapes: Array[PackedVector3Array] = []
	var base: SphereMesh = SphereMesh.new()
	base.radius = 1.0
	base.height = 2.0
	base.radial_segments = 7
	base.rings = 4
	var arrays: Array = base.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = 1.3
	for shape: int in 5:
		noise.seed = 700 + shape * 31
		var bumpy: PackedVector3Array = PackedVector3Array()
		for vertex: Vector3 in vertices:
			var lump: float = 1.0 + noise.get_noise_3dv(vertex * 2.0) * 0.38
			bumpy.append(Vector3(vertex.x * lump, vertex.y * lump * 0.7, vertex.z * lump))

		var triangles: PackedVector3Array = PackedVector3Array()
		for i: int in range(0, indices.size(), 3):
			triangles.append(bumpy[indices[i]])
			triangles.append(bumpy[indices[i + 1]])
			triangles.append(bumpy[indices[i + 2]])

		shapes.append(triangles)

	return shapes


func _build_canopy(species: int) -> ArrayMesh:
	var spec: Dictionary = CANOPY[species]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6000 + species
	var shapes: Array[PackedVector3Array] = _blob_shapes()
	var base_color: Color = spec["color"]
	var half: float = CLUMP_SIZE * 0.5

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()

	# The foliage masses: spread over the block (a jittered grid, so none of it is bare), each at
	# its own height and tone.
	var count: int = spec["count"]
	var cells: int = int(ceil(sqrt(float(count))))
	var step: float = CLUMP_SIZE / float(cells)
	var placed: int = 0
	for gz: int in cells:
		for gx: int in cells:
			if placed >= count:
				break

			placed += 1
			var radius: float = rng.randf_range((spec["radius"] as Vector2).x, (spec["radius"] as Vector2).y)
			var at: Vector3 = Vector3(
				-half + (float(gx) + rng.randf_range(0.1, 0.9)) * step,
				rng.randf_range((spec["height"] as Vector2).x, (spec["height"] as Vector2).y),
				-half + (float(gz) + rng.randf_range(0.1, 0.9)) * step
			)
			var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(radius, radius * rng.randf_range(0.8, 1.15), radius))
			var tone: float = rng.randf_range(0.75, 1.2)
			_emit(vertices, normals, colors, shapes[rng.randi() % shapes.size()], Transform3D(basis, at), base_color * tone, rng, 0.22)

	# A low skirt of masses at the ground, so a block on a slope has no gaps under the crowns.
	for ring: int in 8:
		var around: Vector3 = Vector3(rng.randf_range(-half, half), rng.randf_range(0.5, 2.5), rng.randf_range(-half, half))
		var skirt: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(5.0, 3.0, 5.0))
		_emit(vertices, normals, colors, shapes[rng.randi() % shapes.size()], Transform3D(skirt, around), base_color * 0.55, rng, 0.2)

	# Emergent araucárias: a slim trunk and a flat umbrella crown over the canopy.
	for emergent: int in int(spec["emergent"]):
		var foot: Vector3 = Vector3(rng.randf_range(-half * 0.85, half * 0.85), 0.0, rng.randf_range(-half * 0.85, half * 0.85))
		var top: float = rng.randf_range(20.0, 27.0)
		var trunk: CylinderMesh = CylinderMesh.new()
		trunk.top_radius = 0.35
		trunk.bottom_radius = 0.7
		trunk.height = top + SKIRT_DEPTH
		trunk.radial_segments = 5
		trunk.rings = 1
		_emit_mesh(vertices, normals, colors, trunk, Transform3D(Basis.IDENTITY, foot + Vector3(0.0, (top - SKIRT_DEPTH) * 0.5, 0.0)), Color(0.1, 0.075, 0.055), rng, 0.1)
		var crown: CylinderMesh = CylinderMesh.new()
		crown.top_radius = rng.randf_range(5.5, 7.5)
		crown.bottom_radius = 1.2
		crown.height = rng.randf_range(2.6, 3.6)
		crown.radial_segments = 8
		crown.rings = 1
		_emit_mesh(vertices, normals, colors, crown, Transform3D(Basis.IDENTITY, foot + Vector3(0.0, top + 1.2, 0.0)), base_color * 0.85, rng, 0.2)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic_specular = 0.0
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	mesh.resource_name = "canopy_%s" % spec["name"]
	return mesh


## Emits a primitive mesh as flat-shaded triangles with a colour.
func _emit_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, mesh: PrimitiveMesh, placed: Transform3D, color: Color, rng: RandomNumberGenerator, jitter: float) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var triangles: PackedVector3Array = PackedVector3Array()
	for i: int in indices.size():
		triangles.append(source[indices[i]])

	_emit(vertices, normals, colors, triangles, placed, color, rng, jitter)


## Emits triangles (triplets of points) transformed by `placed`, flat shaded: one normal per
## triangle, its colour the base colour with a random tone per face (the leafy mottling) and
## darker underneath.
func _emit(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, triangles: PackedVector3Array, placed: Transform3D, color: Color, rng: RandomNumberGenerator, jitter: float) -> void:
	for i: int in range(0, triangles.size(), 3):
		var a: Vector3 = placed * triangles[i]
		var b: Vector3 = placed * triangles[i + 1]
		var c: Vector3 = placed * triangles[i + 2]
		var normal: Vector3 = (b - a).cross(c - a)
		if normal.length_squared() < 0.000001:
			continue

		normal = normal.normalized()
		var local_y: float = (triangles[i].y + triangles[i + 1].y + triangles[i + 2].y) / 3.0
		var shade: float = lerpf(0.5, 1.0, clampf(local_y * 0.5 + 0.5, 0.0, 1.0)) * (1.0 + rng.randf_range(-jitter, jitter))
		var tone: Color = Color(color.r * shade, color.g * shade, color.b * shade, 1.0)
		for point: Vector3 in [a, b, c]:
			vertices.append(point)
			normals.append(normal)
			colors.append(tone)


# ============================================================
# THE SINGLE TREES
# ============================================================

func _source_mesh(path: String) -> Mesh:
	var model: Node = (load(path) as PackedScene).instantiate()
	var found: Mesh = null
	var pending: Array[Node] = [model]
	while not pending.is_empty() and found == null:
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			found = (node as MeshInstance3D).mesh

		pending.append_array(node.get_children())

	model.free()
	return found


## The leaf surface of a tree model: the one whose material is transparent (alpha cut-out).
func _leaf_surface(mesh: Mesh) -> int:
	for surface: int in mesh.get_surface_count():
		var material: BaseMaterial3D = mesh.surface_get_material(surface) as BaseMaterial3D
		if material != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return surface

	return mesh.get_surface_count() - 1


## The single tree of a species: the model's mesh with its leaf material darkened.
func _build_tree(species: int) -> ArrayMesh:
	var source: Mesh = _source_mesh(SPECIES[species]["path"])
	var tree: ArrayMesh = source.duplicate() as ArrayMesh
	var leaf_surface: int = _leaf_surface(tree)
	var leaf_material: BaseMaterial3D = (tree.surface_get_material(leaf_surface) as BaseMaterial3D).duplicate()
	leaf_material.albedo_color = LEAF_TINT
	leaf_material.metallic_specular = 0.0
	leaf_material.alpha_scissor_threshold = LEAF_CUTOUT
	tree.surface_set_material(leaf_surface, leaf_material)
	var bark_surface: int = 1 - leaf_surface if tree.get_surface_count() == 2 else 0
	var bark_material: BaseMaterial3D = (tree.surface_get_material(bark_surface) as BaseMaterial3D).duplicate()
	bark_material.albedo_color = Color(0.62, 0.58, 0.54)
	tree.surface_set_material(bark_surface, bark_material)
	tree.resource_name = "tree_%s" % SPECIES[species]["name"]
	return tree


func _save_scene(mesh: ArrayMesh, mesh_path: String, scene_file: String, node_name: String) -> void:
	ResourceSaver.save(mesh, mesh_path)
	mesh.take_over_path(mesh_path)
	var root: Node3D = Node3D.new()
	root.name = node_name
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	root.add_child(instance)
	instance.owner = root
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, scene_file)
	root.free()
