extends Control

## A page that shows every control type and theme variation of the game's UI theme on a
## foggy backdrop, to check the look (and to compare a changed `UIConfig`) without playing.
## Open scenes/ui/ui_theme_gallery.tscn and run it (F6).

func _ready() -> void:
	var back: ColorRect = ColorRect.new()
	back.color = Color(0.06, 0.065, 0.07)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var fog: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0.3, 0.32, 0.35, 0.5), Color(0.02, 0.03, 0.04, 0.0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.0, 1.0)
	fog.texture = texture
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(fog)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)

	add_child(margin)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	margin.add_child(columns)

	# Left: titles, text, panels, hints.
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.add_theme_constant_override("separation", 14)
	columns.add_child(left)
	left.add_child(_label("THE HOLE", "TitleLabel"))
	left.add_child(_label("Inventory", "HeaderLabel"))
	left.add_child(_label("SIGNAL BOX 04 // LINE CLOSED / 1962-11-03", "AccentLabel"))
	var dialogue: PanelContainer = PanelContainer.new()
	var dialogue_box: VBoxContainer = VBoxContainer.new()
	dialogue.add_child(dialogue_box)
	dialogue_box.add_child(_label("Sophia, did you hear that? Something is walking under the floor, slowly, as if it knew we were here.", "DialogueLabel", true))
	dialogue_box.add_child(_label("[E] CONTINUE", "MutedLabel"))
	left.add_child(dialogue)
	var note: PanelContainer = PanelContainer.new()
	note.theme_type_variation = &"NotePanel"
	var note_box: VBoxContainer = VBoxContainer.new()
	note.add_child(note_box)
	note_box.add_child(_label("A note, found in the wagon", "HeaderLabel"))
	var body: RichTextLabel = RichTextLabel.new()
	body.theme_type_variation = &"NoteText"
	body.bbcode_enabled = true
	body.fit_content = true
	body.text = "They told us the line was closed years ago. [b]Do not go down to the platform[/b] after dark. [i]If you hear the bell, do not answer it.[/i] Ação, coração, não, até."
	note_box.add_child(body)
	left.add_child(note)
	var caption: PanelContainer = PanelContainer.new()
	caption.theme_type_variation = &"CaptionPanel"
	caption.add_child(_label("[Caption] A bell rings somewhere below the platform.", "CaptionLabel"))
	left.add_child(caption)
	left.add_child(_label("Sophia's notebook", "ItemTitleLabel"))
	var danger: PanelContainer = PanelContainer.new()
	danger.theme_type_variation = &"DangerPanel"
	danger.add_child(_label("WARNING: the door will not open from this side.", "DangerLabel"))
	left.add_child(danger)
	var hint: PanelContainer = PanelContainer.new()
	hint.theme_type_variation = &"HintPanel"
	hint.add_child(_label("Hold SHIFT to sprint", "HintLabel"))
	left.add_child(hint)

	# Right: controls.
	var right: PanelContainer = PanelContainer.new()
	right.custom_minimum_size = Vector2(560, 0)
	columns.add_child(right)
	var controls: VBoxContainer = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	right.add_child(controls)
	controls.add_child(_label("Options", "HeaderLabel"))
	var tabs: TabContainer = TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 250)
	var audio: VBoxContainer = VBoxContainer.new()
	audio.name = "Audio"
	tabs.add_child(audio)
	var graphics: VBoxContainer = VBoxContainer.new()
	graphics.name = "Graphics"
	tabs.add_child(graphics)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_label("Master volume"))
	var slider: HSlider = HSlider.new()
	slider.value = 65
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	audio.add_child(row)
	var option: OptionButton = OptionButton.new()
	option.add_item("Ultra")
	option.add_item("High")
	audio.add_child(option)
	var check: CheckBox = CheckBox.new()
	check.text = "Subtitles"
	check.button_pressed = true
	audio.add_child(check)
	var toggle: CheckButton = CheckButton.new()
	toggle.text = "Vertical sync"
	toggle.button_pressed = true
	audio.add_child(toggle)
	var off: CheckButton = CheckButton.new()
	off.text = "Motion blur"
	audio.add_child(off)
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = "Name"
	edit.text = "Sophia"
	audio.add_child(edit)
	controls.add_child(tabs)
	controls.add_child(HSeparator.new())
	for entry: Array in [["New game", ""], ["Continue", ""], ["Options (disabled)", "off"], ["Delete save", "danger"]]:
		var button: Button = Button.new()
		button.text = entry[0]
		if entry[1] == "off":
			button.disabled = true
		elif entry[1] == "danger":
			button.theme_type_variation = &"DangerButton"

		controls.add_child(button)
		if entry[0] == "New game":
			button.grab_focus.call_deferred()

	var bar: ProgressBar = ProgressBar.new()
	bar.value = 40
	controls.add_child(bar)


func _label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	if variation != "":
		label.theme_type_variation = StringName(variation)

	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(500, 0)

	return label
