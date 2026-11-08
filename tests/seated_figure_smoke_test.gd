extends Node

## The shadow that sits at the fig clearing's table (`SeatedFigure`) is posed from the Mixamo sitting animation (`assets/animations/mixamo/sitting.fbx`): the lowest point of its pelvis lies exactly on the bench's top
## (it neither floats over it nor sinks into it), its feet are not in the ground, the hands still reach what the sequence wants (the token over the table), and the head still bows. Run it as a scene.

var test_failed: bool = false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS - ", message)
	else:
		test_failed = true
		push_error("FAIL - " + message)
		print("FAIL - ", message)


func _ready() -> void:
	var bench_top: float = 0.45
	var figure: SeatedFigure = SeatedFigure.new()
	add_child(figure)
	figure.build(bench_top, 0.92, {"token_hand": "Left", "hold": Vector3(0.2, 0.85, 0.6), "rest": Vector3(-0.2, bench_top + 0.12, 0.25)})
	_expect(not figure._sit_base.is_empty(), "the body is posed from the sitting animation")
	var extent: Dictionary = figure._extent()
	var pelvis_world: float = float(extent["pelvis"]) * 0.92 + (figure.get_node("Model") as Node3D).position.y
	_expect(absf(pelvis_world - bench_top) < 0.004, "the lowest point of the pelvis is on the bench's top (%.4f m against %.2f m)" % [pelvis_world, bench_top])
	_expect(figure.feet_clearance > -0.02, "the feet are not in the ground (%.3f m over it)" % figure.feet_clearance)
	_expect(absf(figure.hold_error) < 0.12, "the hand still holds the token over the table (%.3f m off)" % figure.hold_error)
	_expect(figure.head_point.y > bench_top + 0.5 and figure.head_point.y < 1.6, "the head is where a sitting person's is (%.2f m)" % figure.head_point.y)
	var neck: int = int(figure._bones["Neck"])
	var before: Quaternion = figure.skeleton.get_bone_pose_rotation(neck)
	figure._set_head_bow(30.0)
	_expect(figure.skeleton.get_bone_pose_rotation(neck).angle_to(before) > 0.05, "the head still bows when asked to")
	print("SEATED_FIGURE_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)
