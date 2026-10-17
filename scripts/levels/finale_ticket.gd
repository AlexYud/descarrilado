extends Interactable
class_name FinaleTicket

## The train ticket that lies on the wagon floor where the crying girl sat (the finale's bait). A paper
## ticket with a faint glow of its own, so it can be found in the dark, and a single use: `E` raises
## `taken` and the finale springs its trap. Nothing goes in the inventory.

signal taken

## Off, it offers nothing (once taken).
var enabled: bool = true

var _paper_material: StandardMaterial3D = null
var _light: OmniLight3D = null
var _time: float = 0.0


func _init() -> void:
	prompt_text = "PROMPT_TAKE_TICKET"


func _ready() -> void:
	_paper_material = StandardMaterial3D.new()
	_paper_material.albedo_color = Color(0.82, 0.76, 0.6)
	_paper_material.roughness = 0.95
	_paper_material.emission_enabled = true
	_paper_material.emission = Color(0.95, 0.88, 0.7)
	_paper_material.emission_energy_multiplier = 0.55

	var paper: MeshInstance3D = MeshInstance3D.new()
	paper.name = "Paper"
	var paper_mesh: BoxMesh = BoxMesh.new()
	paper_mesh.size = Vector3(0.16, 0.004, 0.1)
	paper.mesh = paper_mesh
	paper.material_override = _paper_material
	paper.position = Vector3(0.0, 0.002, 0.0)
	paper.rotation_degrees.y = 12.0
	add_child(paper)

	var stripe: MeshInstance3D = MeshInstance3D.new()
	stripe.name = "Stripe"
	var stripe_mesh: BoxMesh = BoxMesh.new()
	stripe_mesh.size = Vector3(0.16, 0.0012, 0.012)
	stripe.mesh = stripe_mesh
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.45, 0.12, 0.1)
	red.roughness = 0.9
	stripe.material_override = red
	paper.add_child(stripe)
	stripe.position = Vector3(0.0, 0.0026, -0.036)

	# A pale glow over it, enough to find it in the red gloom (a ticket that shines is wrong).
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = Color(0.95, 0.9, 0.75)
	_light.light_energy = 0.5
	_light.omni_range = 1.5
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.18, 0.0)
	add_child(_light)

	var area: Area3D = Area3D.new()
	area.name = "InteractArea"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.28, 0.16, 0.22)
	shape.shape = box
	shape.position = Vector3(0.0, 0.06, 0.0)
	area.add_child(shape)
	add_child(area)


func _process(delta: float) -> void:
	# The glow breathes a little.
	_time += delta
	var pulse: float = 0.85 + 0.15 * sin(_time * 2.4)
	if _paper_material != null:
		_paper_material.emission_energy_multiplier = 0.55 * pulse

	if _light != null:
		_light.light_energy = 0.5 * pulse


func can_interact(_player: Node) -> bool:
	return enabled


func interact(_player: Node) -> void:
	if not enabled:
		return

	enabled = false
	taken.emit()
