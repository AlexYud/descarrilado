extends Node

const TEST_SAVE_DIRECTORY := (
	"res://.godot/codex_save_slots_panel_smoke"
)
const TEST_SLOT := 1


func _ready() -> void:
	SaveManager.save_directory = TEST_SAVE_DIRECTORY
	_expect_ok(
		SaveManager.delete_slot(TEST_SLOT),
		"cleaning the UI test slot"
	)
	_expect_ok(
		SaveManager.create_new_game(
			TEST_SLOT,
			"res://scenes/cinematics/dream_intro.tscn",
			"dream_intro_start",
			"SAVE_LOCATION_DREAM_INTRO"
		),
		"creating the UI test slot"
	)

	var panel_scene: PackedScene = load(
		"res://scenes/ui/save_slots_panel.tscn"
	)
	var panel: SaveSlotsPanelController = panel_scene.instantiate()
	add_child(panel)
	panel.open_load_game()

	var slot_button: Button = panel.get_node(
		"Center/Window/Margin/Content/Slots/Slot1/SlotButton"
	)
	_expect(panel.visible, "the slot panel should open")
	_expect(not slot_button.disabled, "an occupied slot should be loadable")
	_expect(not slot_button.text.is_empty(), "slot metadata should be visible")

	panel.close_panel()
	_expect(not panel.visible, "the slot panel should close")
	_expect_ok(
		SaveManager.delete_slot(TEST_SLOT),
		"deleting the UI test slot"
	)
	SaveManager.suspend_session(false)
	print("Save slot panel smoke test passed.")
	get_tree().quit(0)


func _expect_ok(result: int, operation: String) -> void:
	_expect(
		result == OK,
		"%s failed with %s" % [operation, error_string(result)]
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	push_error("Save slot panel smoke test: " + message)
	get_tree().quit(1)
