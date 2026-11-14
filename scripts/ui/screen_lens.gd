class_name ScreenLens
extends RefCounted

## Where the picture's lens shows what the camera drew at a screen point. The screen filters bend the picture a little (the dream look's fisheye, the
## VHS look's lens); what is laid over the picture from a 3D position (the interaction mark, the lockbox's arrows) goes through here to stay on what it
## marks. Each filter gives the point back unchanged while it is hidden, and only one of them shows at a time.

const FILTERS: Array[NodePath] = [^"/root/HorrorFilter", ^"/root/DreamFilter"]


static func position(from: Node, point: Vector2, screen: Vector2) -> Vector2:
	if from == null or not from.is_inside_tree():
		return point

	var shown: Vector2 = point
	for path: NodePath in FILTERS:
		var filter: Node = from.get_node_or_null(path)
		if filter != null and filter.has_method(&"lens_position"):
			shown = filter.call(&"lens_position", shown, screen)
	return shown
