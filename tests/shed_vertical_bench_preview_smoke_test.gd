extends Node

## Instantiates the vertical-bench look-test scene (a developer preview, not the game) and checks its arrangement by its numbers: the bench stands on its end against the pillar, Emily is
## placed against its seat with her feet on the floor, her featureless head is collapsed (on her instance only) under the cloth, her hands are under the lowest broad band, nothing of the
## game is in it (no recording, trigger, interaction, sound or save access), and the tape look can be switched. It cannot judge the picture: see the screenshots taken separately.

var test_failed: bool = false


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	GameSettings.set_text_locale("en", false)
	var done_before: Variant = SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false)

	var preview: ShedVerticalBenchPreview = (load("res://scenes/levels/shed_vertical_bench_preview.tscn") as PackedScene).instantiate()
	preview.hold_seconds = 0.3
	add_child(preview)
	for i: int in 4:
		await get_tree().process_frame

	var pivot: Node3D = preview.bench_pivot
	var emily: ArchiveActor = preview.emily
	_expect(pivot != null and emily != null and preview.camera != null and preview.camera.current, "the scene builds its bench, Emily and its own camera")

	# The bench: the level's own builder, turned upright here.
	_expect(pivot.global_basis.x.dot(Vector3.UP) > 0.995, "the bench's long axis is vertical (%.3f)" % pivot.global_basis.x.dot(Vector3.UP))
	_expect(pivot.global_basis.y.dot(Vector3.BACK) > 0.995 and pivot.global_basis.y.dot(Vector3.BACK) < 1.0, "its seat faces the camera's side and leans back a little against the pillar")
	var foot: Vector3 = pivot.global_transform * Vector3(-ShedVerticalBenchPreview.BENCH_HALF_LENGTH, 0.42, 0.0)
	_expect(absf(foot.y - ShedVerticalBenchPreview.FLOOR_Y) < 0.03, "the end of its planks stands on the floor (%.3f m over it)" % (foot.y - ShedVerticalBenchPreview.FLOOR_Y))
	var legs_back: float = (pivot.global_transform * Vector3(0.75, 0.0, 0.0)).z
	var pillar_face: float = ShedVerticalBenchPreview.PILLAR_CENTRE.z + ShedVerticalBenchPreview.PILLAR_HALF
	_expect(legs_back - pillar_face > -0.03 and legs_back - pillar_face < 0.03, "its upper leg rests against the pillar's face (%.3f m)" % (legs_back - pillar_face))
	var bench: Node3D = pivot.get_node("Bench")
	_expect(bench.get_node_or_null("ReplacedPlank") != null and not (bench.get_node("ReplacedPlank") as Node3D).visible and (pivot.get_node("ShelterArchive/Intact") as Node3D).visible, "with the old plank of the recording in place of the repaired one")
	_expect(pivot.global_basis.get_scale().is_equal_approx(Vector3.ONE), "at its own size, not stretched to fit her")

	# Emily: at her own scale, her back on the seat, her feet on the floor, painted clothes, the head collapsed on this instance and nobody else's.
	var vertices: PackedVector3Array = emily.skinned_vertices()
	var lowest: float = 1.0e9
	var top: float = -1.0e9
	for v: Vector3 in vertices:
		lowest = minf(lowest, emily.to_global(v).y)
		top = maxf(top, emily.to_global(v).y)
	_expect(absf(lowest - ShedVerticalBenchPreview.FLOOR_Y) < 0.03, "her feet are on the floor (%.3f m)" % (lowest - ShedVerticalBenchPreview.FLOOR_Y))
	var seat_point: Vector3 = pivot.global_transform * Vector3(0.0, ShedVerticalBenchPreview.SEAT_TOP, 0.0)
	var nearest: float = 1.0e9
	for index: int in emily.vertices_of(["Hips", "Spine", "Spine1", "Spine2"]):
		nearest = minf(nearest, (emily.to_global(vertices[index]) - seat_point).dot(pivot.global_basis.y))
	_expect(nearest > -0.02 and nearest < 0.02, "her back is against the wood, not through it (%.3f m)" % nearest)
	var seat_top_y: float = (pivot.global_transform * Vector3(ShedVerticalBenchPreview.BENCH_HALF_LENGTH, 0.0, 0.0)).y
	_expect(is_equal_approx(emily.actor_scale, 0.9) and top < seat_top_y + 0.1 and top > 1.4, "at the same scale as in the recording: her head is no higher than the bench's top end (%.2f against %.2f m)" % [top, seat_top_y])
	var top_colour: Color = emily.palette[&"top"]
	var trousers: Color = emily.palette[&"bottom"]
	var shoes: Color = emily.palette[&"shoes"]
	_expect(top_colour.get_luminance() > trousers.get_luminance() * 2.0 and trousers.get_luminance() > shoes.get_luminance(), "painted clothing: a moderately dark top, darker trousers, darker shoes")
	var head_bone: int = emily.skeleton.find_bone("mixamorig_Head")
	_expect(emily.skeleton.get_bone_pose_scale(head_bone).x < 0.01 and emily.hidden_bones == PackedStringArray(["Head"]), "her featureless head is collapsed on this instance")
	var fresh: Node = (load(ArchiveActor.MODEL) as PackedScene).instantiate()
	var fresh_skeleton: Skeleton3D = fresh.get_node("Skeleton3D") as Skeleton3D
	_expect(fresh_skeleton.get_bone_pose_scale(fresh_skeleton.find_bone("mixamorig_Head")).is_equal_approx(Vector3.ONE), "while a fresh instance of the shared model is untouched")
	fresh.free()

	# The head covering and the bands.
	var head_point: Vector3 = emily.to_global(emily.bone_point("Head"))
	_expect(preview.head_cloth != null and preview.head_cloth.get_child_count() >= 2, "a plain cloth covers the head")
	var covered: bool = false
	for piece: Node in preview.head_cloth.get_children():
		var mesh_piece: MeshInstance3D = piece as MeshInstance3D
		if mesh_piece != null and mesh_piece.name == "Dome":
			covered = mesh_piece.global_position.distance_to(head_point) < 0.2 and (mesh_piece.global_transform * mesh_piece.mesh.get_aabb()).size.y > 0.25
	_expect(covered, "over where the head is, large enough to hide it")
	_expect(preview.bands.size() == 3, "three broad bands hold her to the wood")
	var hip_band: Node3D = preview.bands[1]
	var hands_ok: bool = true
	for hand: String in ["LeftHand", "RightHand"]:
		var at: Vector3 = pivot.global_transform.affine_inverse() * emily.to_global(emily.bone_point(hand))
		var front: MeshInstance3D = hip_band.get_node("Front") as MeshInstance3D
		var box: BoxMesh = front.mesh as BoxMesh
		hands_ok = hands_ok and absf(at.x - front.position.x) < box.size.x * 0.5 and absf(at.z) < box.size.z * 0.5 and at.y < front.position.y
	_expect(hands_ok, "her hands hang at her hips, inside the lowest, broadest band's height and width and behind its front face")
	var wide: float = (emily.to_global(emily.bone_point("LeftHand")) - emily.to_global(emily.bone_point("RightHand"))).length()
	_expect(wide < 0.5, "arms down at her sides: no spread arms, no T-pose (%.2f m between the wrists)" % wide)
	_expect(preview.find_children("*", "Light3D", true, false).size() == 1, "one light only: the shelter's own lamp (no spotlight for the victim)")

	# Nothing of the game is in it.
	_expect(preview.find_children("*", "WaitingShedSequence", true, false).is_empty() and preview.find_children("*", "Interactable", true, false).is_empty() and preview.find_children("*", "Inspectable", true, false).is_empty() and preview.find_children("*", "AudioStreamPlayer", true, false).is_empty() and preview.find_children("*", "ShelterFootage", true, false).is_empty(), "no recording, interaction, token or sound in it")
	_expect(SaveManager.get_state_value(&"puzzles", &"shelter_recording_done", false) == done_before, "it touches no completion flag")

	# The tape look can be switched, and the tape's static comes after the hold.
	var overlay: ArchiveVideoOverlay = null
	for child: Node in preview.get_children():
		if child is ArchiveVideoOverlay:
			overlay = child as ArchiveVideoOverlay
	_expect(overlay != null and overlay.visible and overlay.force_full_look, "the tape look is on by default, whatever the player's own filter setting is")
	await get_tree().create_timer(0.5).timeout
	_expect(bool(preview.get("_burst_shown")), "and the tape's static comes once the held still is over")
	preview.vhs_overlay_enabled = false
	await get_tree().process_frame
	_expect(not overlay.visible, "the preview's one switch turns it off: the clean picture")
	preview.vhs_overlay_enabled = true
	await get_tree().process_frame
	_expect(overlay.visible, "and on again")

	print("SHED_VERTICAL_BENCH_PREVIEW_SMOKE_TEST: ", "FAILED" if test_failed else "PASSED")
	get_tree().quit(1 if test_failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("ok   - ", message)
	else:
		test_failed = true
		push_error("FAIL - " + message)
		print("FAIL - ", message)
