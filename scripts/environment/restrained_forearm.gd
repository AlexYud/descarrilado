extends Node3D
class_name RestrainedForearm

## A static close-up insert for the waiting shed's recording (angle B, see `ShelterFootage`): one clothed forearm ending in a CLOSED, gloved hand that rests on its side on the
## bench's plank, with the band round the sleeve and a strap that goes from it to the wood and round the plank. It REPLACES Emily's forearm and hand for that shot (the footage
## hides those two bones of her own skeleton instance while the insert is shown): the project's rigged mannequin has no fingers, so a closed hand cannot be posed on it.
##
## It is scenery for one camera shot: a handful of plain meshes, built once in code from a few numbers, one fixed pose. No collision, no interaction, no light, no animation, no
## physics and no saved state; hidden with the rest of the cast. The sleeve is a loose tube (ring by ring along the line from the elbow to the wrist, bunched at the cuff, a few
## broad folds) that continues, over the mannequin's own upper arm, out of the picture; the glove is a leather mitt made of overlapping ellipsoids and capsules: the back of the
## hand, a row of knuckles, four curled fingers, a thumb mass folded over them and a gauntlet cuff. Detail goes into the silhouette, the proportions and the contact with the wood,
## not into stitching or textures. All lengths are in metres, at an adult's scale (a closed fist about 9 cm across and 11 cm long).

const SLEEVE_RINGS: int = 22
const SLEEVE_SIDES: int = 16

@export_category("Look")
@export var sleeve_colour: Color = Color(0.62, 0.64, 0.68)
@export var glove_colour: Color = Color(0.52, 0.4, 0.28)
@export var cuff_colour: Color = Color(0.3, 0.22, 0.15)
@export var band_colour: Color = Color(0.46, 0.41, 0.33)

@export_category("Shape")
## The sleeve's radius at the elbow end and at the cuff (a loose sleeve is wider than the arm), and how deep its folds are.
@export var sleeve_radius_elbow: float = 0.047
@export var sleeve_radius_cuff: float = 0.041
@export var fold_depth: float = 0.06
## How far the sleeve runs on over the mannequin's upper arm (so there is no seam to see), and how far short of the wrist it ends.
@export var sleeve_overlap: float = 0.07
@export var sleeve_short_of_wrist: float = 0.015
## Where along the forearm (from the wrist, metres) the band is.
@export var band_from_wrist: float = 0.085
@export var band_width: float = 0.034

## The points the insert was built from (for the tests and the camera): the glove's middle, the band's middle and where the strap is tied round the plank.
var glove_centre: Vector3 = Vector3.ZERO
var band_centre: Vector3 = Vector3.ZERO
var strap_anchor: Vector3 = Vector3.ZERO
var wrist_point: Vector3 = Vector3.ZERO
var elbow_point: Vector3 = Vector3.ZERO

var _leather: StandardMaterial3D = null
var _cuff: StandardMaterial3D = null
var _cloth: StandardMaterial3D = null
var _band: StandardMaterial3D = null


## Builds the insert (again, if it was built). Everything is in this node's own space.
##   elbow, wrist: the ends of the forearm (the mannequin's own posed ones, so the sleeve carries on from its upper arm);
##   outward: the way away from Emily's body (the back of the hand faces it); forward: the way she faces (the hand lies along it, fingers forward);
##   plank_top: the height of the wood the hand rests on; plank_z_low and plank_z_high: the plank's two edges along z (the strap goes round it).
func build(elbow: Vector3, wrist: Vector3, outward: Vector3, forward: Vector3, plank_top: float, plank_z_low: float, plank_z_high: float) -> void:
	clear()
	_make_materials()
	# The hand lies on the plank: the wrist is put where the mannequin's wrist was, but at the height at which a closed hand rests on the wood (the mannequin's own forearm is hidden,
	# so nothing needs to reach there); the sleeve still starts at the mannequin's own elbow.
	var resting: Vector3 = Vector3(wrist.x, plank_top + 0.05, wrist.z)
	elbow_point = elbow
	wrist_point = resting
	var forearm: Vector3 = (resting - elbow).normalized()

	_build_sleeve(elbow, resting, forearm)
	_build_glove(resting, forearm, outward, forward, plank_top)
	_build_band(resting, forearm, outward, plank_top, plank_z_low, plank_z_high)


func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func _make_materials() -> void:
	_leather = StandardMaterial3D.new()
	_leather.albedo_color = glove_colour
	_leather.roughness = 0.5
	_leather.metallic_specular = 0.6
	_cuff = StandardMaterial3D.new()
	_cuff.albedo_color = cuff_colour
	_cuff.roughness = 0.85
	_cloth = StandardMaterial3D.new()
	_cloth.albedo_color = sleeve_colour
	_cloth.roughness = 1.0
	_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_band = StandardMaterial3D.new()
	_band.albedo_color = band_colour
	_band.roughness = 1.0


# ============================================================
# THE SLEEVE
# ============================================================

## The sleeve's radius at `t` (0 at the elbow end, 1 at the cuff) round the angle `angle`: wide at the top, tapering, bunched into broad folds near the cuff.
func sleeve_radius_at(t: float, angle: float) -> float:
	var base: float = lerpf(sleeve_radius_elbow, sleeve_radius_cuff, smoothstep(0.0, 1.0, t))
	var folds: float = 1.0 + fold_depth * sin(angle * 3.0 + t * 8.0) * (0.4 + 0.6 * t) + fold_depth * 0.5 * sin(angle * 2.0 - t * 5.0)
	var bunch: float = 1.0 + 0.1 * smoothstep(0.65, 1.0, t) * sin(t * 46.0)
	var sag: float = 1.0 + 0.05 * cos(angle)
	return base * folds * bunch * sag


func _build_sleeve(elbow: Vector3, wrist: Vector3, forearm: Vector3) -> void:
	var start: Vector3 = elbow - forearm * sleeve_overlap
	var finish: Vector3 = wrist - forearm * sleeve_short_of_wrist
	var side_a: Vector3 = forearm.cross(Vector3.UP)
	if side_a.length() < 0.05:
		side_a = forearm.cross(Vector3.RIGHT)
	side_a = side_a.normalized()
	var side_b: Vector3 = forearm.cross(side_a).normalized()

	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for ring: int in SLEEVE_RINGS - 1:
		var t0: float = float(ring) / float(SLEEVE_RINGS - 1)
		var t1: float = float(ring + 1) / float(SLEEVE_RINGS - 1)
		for side: int in SLEEVE_SIDES:
			var a0: float = TAU * float(side) / float(SLEEVE_SIDES)
			var a1: float = TAU * float(side + 1) / float(SLEEVE_SIDES)
			var p00: Vector3 = _ring_point(start, finish, side_a, side_b, t0, a0)
			var p01: Vector3 = _ring_point(start, finish, side_a, side_b, t0, a1)
			var p10: Vector3 = _ring_point(start, finish, side_a, side_b, t1, a0)
			var p11: Vector3 = _ring_point(start, finish, side_a, side_b, t1, a1)
			for point: Vector3 in [p00, p10, p01, p01, p10, p11]:
				tool.add_vertex(point)
	tool.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Sleeve"
	instance.mesh = tool.commit()
	instance.material_override = _cloth
	add_child(instance)

	# The open end of the sleeve at the cuff: a dark inside, so that no gap shows between the cloth and the glove.
	var inside: MeshInstance3D = _cylinder("SleeveInside", sleeve_radius_cuff * 0.93, 0.02, finish + forearm * 0.0, forearm, _cuff)
	inside.position = finish - forearm * 0.004


func _ring_point(start: Vector3, finish: Vector3, side_a: Vector3, side_b: Vector3, t: float, angle: float) -> Vector3:
	var centre: Vector3 = start.lerp(finish, t)
	var radius: float = sleeve_radius_at(t, angle)
	return centre + (side_a * cos(angle) + side_b * sin(angle)) * radius


# ============================================================
# THE GLOVE
# ============================================================

## The closed hand: lying on its little-finger side with the thumb up, the back of it toward `outward`, the fingers curled and the thumb folded over them. `forearm` is the
## direction the forearm points (towards the hand); the hand bends at the wrist to lie along the wood.
func _build_glove(wrist: Vector3, forearm: Vector3, outward: Vector3, forward: Vector3, plank_top: float) -> void:
	# Along the hand: the way she faces, level (the fist's underside rests on the plank), bent at the wrist from the hanging forearm.
	var along: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
	if along.length() < 0.5:
		along = Vector3(outward.x, 0.0, outward.z).normalized()
	var top: Vector3 = Vector3.UP
	var back: Vector3 = top.cross(along).normalized()
	if back.dot(outward) < 0.0:
		back = -back
	var centre: Vector3 = wrist + along * 0.058
	glove_centre = centre

	# The wrist: a bridge between the sleeve's end and the hand, and the gauntlet cuff over the end of the sleeve.
	_ellipsoid("WristBridge", wrist + along * 0.012, back * 0.033, top * 0.033, along * 0.04, _leather)
	var cuff_direction: Vector3 = forearm
	var cuff: MeshInstance3D = _cylinder("Cuff", 0.0375, 0.075, wrist - forearm * 0.022, cuff_direction, _cuff)
	_ellipsoid("CuffLip", wrist - forearm * 0.056, back * 0.041, top * 0.041, forearm * 0.009, _cuff)

	# The back of the hand and the palm: one broad mass, taller (across the knuckles) than it is thick, fuller towards the knuckles.
	_ellipsoid("HandMass", centre + along * 0.008, back * 0.028, top * 0.041, along * 0.054, _leather)

	# The curled fingers: a column down the front of the fist, four rounded rolls that overlap (index at the top, the little finger smaller and set back); the ridge between
	# two rolls is shallow, so that the whole reads as one closed mitt and not as a row of beads.
	for finger: int in 4:
		var across: float = 0.0278 - 0.0185 * float(finger)
		var size: float = 0.0168 - 0.0012 * float(finger)
		var set_back: float = 0.0035 * float(maxi(finger - 1, 0))
		var tip: Vector3 = centre + along * (0.058 - set_back) + back * 0.004 + top * across
		_ellipsoid("Finger%d" % finger, tip, back * (size * 1.5), top * size * 1.12, along * size * 1.25, _leather)
	# The thumb: a mass at the base of the hand on the top side, and the thumb itself folded forward over the first finger's front.
	_ellipsoid("ThumbBase", centre + top * 0.036 - along * 0.022 + back * 0.002, back * 0.019, top * 0.014, along * 0.028, _leather)
	var thumb_from: Vector3 = centre + top * 0.039 - along * 0.012 + back * 0.006
	var thumb_to: Vector3 = centre + top * 0.034 + along * 0.062 + back * 0.012
	_capsule("Thumb", 0.0135, thumb_from, thumb_to, _leather)
	_ellipsoid("ThumbTip", thumb_to + (thumb_to - thumb_from).normalized() * 0.004 - top * 0.003, back * 0.0128, top * 0.0115, along * 0.0125, _leather)


# ============================================================
# THE BAND AND THE STRAP
# ============================================================

## The band round the sleeve a hand's width above the wrist, a short strap down to the plank, across the plank's top and over its front edge into the gap between the boards
## (where it is tied round the board), so that the limb is held to the wood.
func _build_band(wrist: Vector3, forearm: Vector3, outward: Vector3, plank_top: float, plank_z_low: float, plank_z_high: float) -> void:
	var centre: Vector3 = wrist - forearm * band_from_wrist
	band_centre = centre
	var t: float = 1.0 - (band_from_wrist - sleeve_short_of_wrist) / maxf(wrist.distance_to(elbow_point) + sleeve_overlap - sleeve_short_of_wrist, 0.01)
	var radius: float = lerpf(sleeve_radius_elbow, sleeve_radius_cuff, smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))) * 1.0 + 0.007
	_cylinder("Band", radius, band_width, centre, forearm, _band)
	# The strap: from the band's outer side down the outside of the sleeve and the cuff to the plank, then flat across the board's top and over both its edges into the gaps
	# between the boards (where it is tied round the board): one visible line from the band to the wood.
	var side: Vector3 = Vector3(outward.x, 0.0, outward.z).normalized()
	var from: Vector3 = centre + side * (radius + 0.005)
	var anchor: Vector3 = Vector3(centre.x, plank_top, centre.z) + side * 0.062
	strap_anchor = anchor
	_strap("Lead", from, anchor + Vector3(0.0, 0.004, 0.0), 0.03, 0.008)
	var z_a: float = plank_z_low + 0.004
	var z_b: float = plank_z_high - 0.004
	_strap("AcrossBoard", Vector3(anchor.x, plank_top + 0.005, z_a), Vector3(anchor.x, plank_top + 0.005, z_b), 0.034, 0.009)
	_strap("OverFront", Vector3(anchor.x, plank_top + 0.003, z_b + 0.004), Vector3(anchor.x, plank_top - 0.052, z_b + 0.006), 0.034, 0.008)
	_strap("OverBack", Vector3(anchor.x, plank_top + 0.003, z_a - 0.004), Vector3(anchor.x, plank_top - 0.052, z_a - 0.006), 0.034, 0.008)

# ============================================================
# SMALL BUILDING BLOCKS
# ============================================================

## A flat strap between two points: a thin box, `width` across and `thickness` thick.
func _strap(strap_name: String, from: Vector3, to: Vector3, width: float, thickness: float) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = strap_name
	var box: BoxMesh = BoxMesh.new()
	var length: float = maxf(from.distance_to(to), 0.004)
	box.size = Vector3(width, thickness, length)
	instance.mesh = box
	instance.material_override = _band
	var direction: Vector3 = (to - from).normalized()
	var up_hint: Vector3 = Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT
	instance.transform = Transform3D(Basis.looking_at(direction, up_hint), (from + to) * 0.5)
	add_child(instance)
	return instance


## A cylinder of `radius` and `height` whose axis is `direction`, centred at `centre`.
func _cylinder(cylinder_name: String, radius: float, height: float, centre: Vector3, direction: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = cylinder_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = Transform3D(_basis_along_y(direction), centre)
	add_child(instance)
	return instance


## A capsule of `radius` between two points (its ends are the round caps' tips).
func _capsule(capsule_name: String, radius: float, from: Vector3, to: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = capsule_name
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(from.distance_to(to) + radius * 2.0, radius * 2.0 + 0.001)
	mesh.radial_segments = 14
	mesh.rings = 4
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = Transform3D(_basis_along_y(to - from), (from + to) * 0.5)
	add_child(instance)
	return instance


## An ellipsoid with the given three semi-axes (the axes' own lengths are the radii) at `centre`.
func _ellipsoid(ellipsoid_name: String, centre: Vector3, axis_x: Vector3, axis_y: Vector3, axis_z: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = ellipsoid_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = Transform3D(Basis(axis_x, axis_y, axis_z), centre)
	add_child(instance)
	return instance


func _basis_along_y(direction: Vector3) -> Basis:
	var unit: Vector3 = direction.normalized()
	if unit.length() < 0.5:
		return Basis.IDENTITY
	if unit.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, unit))
