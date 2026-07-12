@tool
extends Node3D
class_name RenderDistanceGroup

@export var apply_on_ready: bool = true

@export var apply_now: bool = false:
	set(value):
		if value:
			call_deferred("apply_render_distance")
		apply_now = false

@export_category("Render Distance")
@export var visibility_end_distance: float = 40.0
@export var visibility_end_margin: float = 0.0

# Disabled is cheaper than fade.
# Fade looks smoother, but Godot says it uses transparent rendering and has a performance cost.
@export var use_fade: bool = false

@export_category("Advanced")
@export var include_root_if_geometry: bool = true
@export var print_applied_count: bool = true


func _ready() -> void:
	if apply_on_ready:
		apply_render_distance()


func apply_render_distance() -> void:
	var applied_count: int = 0

	if include_root_if_geometry:
		applied_count += _apply_to_node(self)

	for child in get_children():
		applied_count += _apply_to_children_recursive(child)

	if print_applied_count:
		print("RenderDistanceGroup applied to ", applied_count, " geometry nodes under: ", name)


func _apply_to_children_recursive(node: Node) -> int:
	var applied_count: int = 0

	applied_count += _apply_to_node(node)

	for child in node.get_children():
		applied_count += _apply_to_children_recursive(child)

	return applied_count


func _apply_to_node(node: Node) -> int:
	if not node is GeometryInstance3D:
		return 0

	var geometry_node: GeometryInstance3D = node as GeometryInstance3D

	geometry_node.visibility_range_end = visibility_end_distance
	geometry_node.visibility_range_end_margin = visibility_end_margin

	if use_fade:
		geometry_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	else:
		geometry_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	return 1
