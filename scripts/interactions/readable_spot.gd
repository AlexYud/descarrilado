@tool
extends Node3D
class_name ReadableSpot

## A place on an inspectable item where something is written or marked: an engraving
## under a lantern, a note on the back of a photograph, a stain. The words are never
## part of the model or its textures, so one asset serves every language: when the
## player turns the item so this spot faces them, the inspect view offers to read it
## and shows the text as a translated 2D overlay (see `InspectReadables`).
##
## Put one as a child of the item's `Visual`, at the place and turned so that its
## **+Z axis (the blue arrow, drawn in the editor) points out of the surface** and its
## +Y axis is "up" for the reader. An item can have as many as it likes (a note on the
## front, a bloodstain on the back): the one facing the player best is offered.
##
## It is only data and a few helpers: the detection, the prompt and the overlay are in
## `InspectReadables`, and reach the spot through the helpers below.

enum PromptKind {
	READ,
	EXAMINE,
}

## Names this spot in reactions (`PlayerInspectController.spot_read`).
@export var spot_id: StringName = &""
## What the overlay shows: a localization key for the title (optional) and one for the
## text, which may use BBCode ([b], [i], [u], [color=...]).
@export var title_key: String = "INSPECT_SPOT_ENGRAVING"
@export var text_key: String = ""
## "Read" for writing, "Examine" for a mark or a detail the text describes.
@export var prompt_kind: PromptKind = PromptKind.READ
## The spot is offered when its outward direction is within this many degrees of
## pointing at the player, and stays offered until it is this much plus a margin away.
@export_range(5.0, 80.0, 1.0) var facing_angle_degrees: float = 32.0
## It has to face the player this long before the prompt appears, so that a spot
## swept past while turning the item does not flash a prompt.
@export_range(0.0, 1.5, 0.05) var dwell_seconds: float = 0.2
## Draws the arrow in the editor (never in the game).
@export var show_editor_arrow: bool = true


func _ready() -> void:
	if Engine.is_editor_hint() and show_editor_arrow:
		_add_editor_arrow()


## The direction the spot faces, in world space.
func get_facing_normal() -> Vector3:
	return global_basis.z.normalized()


## 1 when the spot faces `viewer_direction` exactly (a unit vector pointing at the
## viewer), 0 when edge on, negative when turned away.
func get_facing_dot(viewer_direction: Vector3) -> float:
	return get_facing_normal().dot(viewer_direction)


func is_facing(viewer_direction: Vector3, extra_degrees: float = 0.0) -> bool:
	return get_facing_dot(viewer_direction) >= cos(deg_to_rad(facing_angle_degrees + extra_degrees))


## The localization key of the prompt ("[E] Read" / "[E] Examine").
func get_prompt_key() -> String:
	return "INSPECT_PROMPT_EXAMINE" if prompt_kind == PromptKind.EXAMINE else "INSPECT_PROMPT_READ"


## An arrow along +Z so the spot can be placed and turned by eye. Not saved with the
## scene and never present in the game.
func _add_editor_arrow() -> void:
	if get_node_or_null("EditorArrow") != null:
		return

	var arrow: MeshInstance3D = MeshInstance3D.new()
	arrow.name = "EditorArrow"
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.006
	cone.height = 0.022
	arrow.mesh = cone
	arrow.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	arrow.position = Vector3(0.0, 0.0, 0.011)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.8, 0.9)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow.material_override = material
	add_child(arrow)
