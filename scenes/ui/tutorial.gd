extends Control
## How to play — first screen. Skip or Continue → adopt flow.

signal finished


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1A2830")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)

	var title := Label.new()
	title.text = "How to Play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("F0F8E8"))
	v.add_child(title)

	var sub := Label.new()
	sub.text = "Real-Time Virtual Pet — a small town life sim"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color("A0C0A8"))
	v.add_child(sub)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color("E8F0E0"))
	body.text = (
		"1. Adopt a pet at the Pet Store (you'll go there next).\n\n"
		+ "2. Walk with WASD. Press E near doors and buildings.\n\n"
		+ "3. In your House, walk near your pet to see how they feel.\n\n"
		+ "4. Press 1–6 (or the care buttons) to feed, walk, play, clean, sleep.\n"
		+ "   Your character walks over and performs the action.\n\n"
		+ "5. Time is real — needs drop even when the game is closed.\n"
		+ "   Neglect long enough and your pet can die. Dig a grave. Adopt again.\n\n"
		+ "Humans never die. Only pets have needs."
	)
	v.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)

	var skip := Button.new()
	skip.text = "Skip Tutorial"
	skip.custom_minimum_size = Vector2(160, 40)
	skip.pressed.connect(_finish)
	row.add_child(skip)

	var go := Button.new()
	go.text = "Got it — Adopt a Pet"
	go.custom_minimum_size = Vector2(200, 40)
	go.pressed.connect(_finish)
	row.add_child(go)


func _finish() -> void:
	# Persist tutorial seen
	var cfg := ConfigFile.new()
	cfg.set_value("onboarding", "tutorial_done", true)
	cfg.save("user://onboarding.cfg")
	finished.emit()
	# Default: go adopt
	SceneRouter.go("pet_store")
