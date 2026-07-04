extends Control
## Pet Store: species cards + adopt. First-time: primary onboarding step.


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1E2A32")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var has_pet := PetController.active_pet != null
	if has_pet:
		var back := Button.new()
		back.text = "Back"
		back.pressed.connect(func(): SceneRouter.go("town", "from_store"))
		top.add_child(back)
	var title := Label.new()
	title.text = "Adopt your first pet" if not has_pet else "Pet Store — choose a companion"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("F0F8E8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	if not has_pet:
		var intro := Label.new()
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro.add_theme_color_override("font_color", Color("B0D0B8"))
		intro.text = "Pick a species and give them a name (2–16 letters). Needs run in real time — even when you're away."
		root.add_child(intro)
	elif has_pet:
		var warn := Label.new()
		warn.add_theme_color_override("font_color", Color("F0C0A0"))
		warn.text = "You already have a living pet. You can only adopt again after burial if they pass away."
		root.add_child(warn)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cards)
	for sid in SpeciesCatalog.list_ids():
		cards.add_child(_make_card(sid, has_pet))


func _make_card(species_id: StringName, has_pet: bool) -> PanelContainer:
	var t: Dictionary = SpeciesCatalog.get_template(species_id)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	# Preview sprite
	var tex_path := "res://assets/sprites/%s_idle_0.png" % (
		"puppy" if str(species_id) == "pup" else ("owl" if str(species_id) == "owl" else "slime")
	)
	if ResourceLoader.exists(tex_path) or FileAccess.file_exists(tex_path):
		var tex: Texture2D = load(tex_path) as Texture2D
		if tex == null:
			var img := Image.load_from_file(ProjectSettings.globalize_path(tex_path))
			if img:
				tex = ImageTexture.create_from_image(img)
		if tex:
			var spr := TextureRect.new()
			spr.texture = tex
			spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			spr.custom_minimum_size = Vector2(96, 96)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			v.add_child(spr)

	var name_l := Label.new()
	name_l.text = str(t.get("display_name", species_id))
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", Color("F8F0E0"))
	v.add_child(name_l)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(200, 0)
	body.add_theme_color_override("font_color", Color("D0D8D0"))
	body.text = (
		"Feed need: %s\nPlay need: %s\nHardiness: %s\n%s"
		% [
			str(t.get("feed_need_label", "")),
			str(t.get("play_need_label", "")),
			str(t.get("hardiness_label", "")),
			str(t.get("risk_blurb", "")),
		]
	)
	v.add_child(body)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Name (2–16)"
	name_edit.text = "Mochi" if str(species_id) == "blob" else "Buddy"
	v.add_child(name_edit)
	var adopt := Button.new()
	adopt.text = "Adopt" if not has_pet else "Adopt (blocked if living pet)"
	adopt.disabled = has_pet and PetController.active_pet != null and str(PetController.active_pet.life_state) != "DEAD"
	# Allow adopt only if no living pet
	if PetController.active_pet != null and str(PetController.active_pet.life_state) != "DEAD":
		adopt.disabled = true
	adopt.pressed.connect(func():
		var r: Dictionary = PetController.adopt_pet(species_id, name_edit.text)
		if r.get("ok", false):
			SceneRouter.go("habitat")
		else:
			print("[store] adopt failed ", r)
	)
	v.add_child(adopt)
	return panel
