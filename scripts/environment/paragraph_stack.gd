@tool
extends Node3D
class_name ParagraphStack

## Written text with paragraph gaps. A Label3D drops blank lines, so each
## paragraph (text between blank lines in the translation) is its own label,
## stacked downwards once their heights are known. Left aligned from this node's
## origin (the top-left corner of the text block).
##
## Built when the scene loads, in the caption language of that moment; a copy of a
## built node (the inspect view duplicates `Visual`) keeps its labels and layout.

@export var text_key: String = ""
@export var font_size: int = 22
@export var pixel_size: float = 0.0002
@export var color: Color = Color(0.12, 0.1, 0.08)
@export var width_pixels: float = 600.0
## Space between paragraphs, in metres.
@export var gap: float = 0.006


func _ready() -> void:
	if get_child_count() > 0 or text_key.is_empty():
		return

	var paragraphs: PackedStringArray = tr(text_key).split("\n\n")
	var labels: Array[Label3D] = []
	for i: int in paragraphs.size():
		var label: Label3D = HouseProps.add_text(
			self, "Paragraph%d" % i, paragraphs[i].strip_edges(), Vector3.ZERO,
			font_size, pixel_size, color, width_pixels
		)
		labels.append(label)

	# The labels measure themselves a couple of frames after entering the tree.
	await get_tree().process_frame
	await get_tree().process_frame

	var y: float = 0.0
	for label: Label3D in labels:
		label.position.y = y
		y -= label.get_aabb().size.y + gap
