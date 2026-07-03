extends Control
## Pet Store: species cards + adopt UX.


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): SceneRouter.go("habitat"))
	top.add_child(back)
	var title := Label.new()
	title.text = "Pet Store — choose a companion"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	if PetController.active_pet != null:
		var warn := Label.new()
		warn.text = "You already have a pet. Burial required before re-adopt if they have passed."
		root.add_child(warn)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	root.add_child(cards)
	for sid in SpeciesCatalog.list_ids():
		cards.add_child(_make_card(sid))


func _make_card(species_id: StringName) -> PanelContainer:
	var t: Dictionary = SpeciesCatalog.get_template(species_id)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	panel.add_child(v)
	var name_l := Label.new()
	name_l.text = str(t.get("display_name", species_id))
	v.add_child(name_l)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(200, 0)
	body.text = (
		"Feed: %s\nPlay: %s\nHardiness: %s\n%s\nTemperament: %s"
		% [
			str(t.get("feed_need_label", "")),
			str(t.get("play_need_label", "")),
			str(t.get("hardiness_label", "")),
			str(t.get("risk_blurb", "")),
			str(t.get("temperament", "")),
		]
	)
	v.add_child(body)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Name (2–16)"
	name_edit.text = "Mochi" if str(species_id) == "blob" else str(t.get("display_name", "Pet")).substr(0, 12)
	v.add_child(name_edit)
	var adopt := Button.new()
	adopt.text = "Adopt"
	adopt.pressed.connect(func():
		var r: Dictionary = PetController.adopt_pet(species_id, name_edit.text)
		print("[store] adopt ", species_id, " => ", r)
		if r.get("ok", false):
			SceneRouter.go("habitat")
	)
	v.add_child(adopt)
	return panel
