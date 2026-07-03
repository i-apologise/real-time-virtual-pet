extends Control
## Playable habitat: meters, action bar, pet view, status, empty/death banners.

const MoodStateMachineScr = preload("res://src/sim/mood_state_machine.gd")

var _meters: Dictionary = {}  # stat -> ProgressBar
var _status: Label
var _pet_label: Label
var _pet_shape: ColorRect
var _action_row: HBoxContainer
var _empty_panel: PanelContainer
var _death_panel: PanelContainer
var _day_night: ColorRect
var _counter: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	if not EventBus.pet_updated.is_connected(_on_pet_updated):
		EventBus.pet_updated.connect(_on_pet_updated)
	if not EventBus.profile_updated.is_connected(_on_profile):
		EventBus.profile_updated.connect(_on_profile)
	_refresh_from_controller()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Top bar
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "Habitat — Your House"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_counter = Label.new()
	_counter.text = "Deaths: 0 · Graves: 0"
	top.add_child(_counter)

	# Day/night wash
	_day_night = ColorRect.new()
	_day_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_night.color = Color(0.05, 0.08, 0.2, 0.0)
	_day_night.custom_minimum_size = Vector2(0, 8)
	_day_night.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_day_night)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "…"
	root.add_child(_status)

	# Mid: pet + meters
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	var pet_box := VBoxContainer.new()
	pet_box.custom_minimum_size = Vector2(220, 220)
	mid.add_child(pet_box)
	_pet_shape = ColorRect.new()
	_pet_shape.custom_minimum_size = Vector2(180, 180)
	_pet_shape.color = Color(0.45, 0.75, 0.95)
	pet_box.add_child(_pet_shape)
	_pet_label = Label.new()
	_pet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pet_label.text = "No pet"
	pet_box.add_child(_pet_label)

	var meter_box := VBoxContainer.new()
	meter_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(meter_box)
	for stat in ["hunger", "energy", "happiness", "hygiene"]:
		var row := HBoxContainer.new()
		meter_box.add_child(row)
		var lab := Label.new()
		lab.text = stat.capitalize()
		lab.custom_minimum_size = Vector2(100, 0)
		row.add_child(lab)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 22)
		row.add_child(bar)
		_meters[stat] = bar

	# Actions
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 6)
	root.add_child(_action_row)
	for action in ["feed", "walk", "play", "clean", "sleep", "wake"]:
		var btn := Button.new()
		btn.text = action.capitalize()
		btn.pressed.connect(_on_action.bind(StringName(action)))
		_action_row.add_child(btn)

	var nav := HBoxContainer.new()
	root.add_child(nav)
	for item in [["Graveyard", "graveyard"], ["Pet Store", "pet_store"], ["Town", "town"]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(_on_nav.bind(item[1]))
		nav.add_child(b)

	# Empty panel
	_empty_panel = _make_banner_panel("No living pet. Visit the Pet Store to adopt, or the Graveyard to remember.")
	var adopt_btn := Button.new()
	adopt_btn.text = "Adopt Cozy Blob (debug)"
	adopt_btn.pressed.connect(func():
		PetController.debug_adopt_blob("Mochi")
		_refresh_from_controller()
	)
	_empty_panel.get_child(0).add_child(adopt_btn)
	root.add_child(_empty_panel)

	# Death panel
	_death_panel = _make_banner_panel("Your pet has died. Dig a grave to say goodbye.")
	var dig := Button.new()
	dig.text = "Dig Grave"
	dig.pressed.connect(func():
		PetController.complete_burial("")
		_refresh_from_controller()
	)
	_death_panel.get_child(0).add_child(dig)
	root.add_child(_death_panel)


func _make_banner_panel(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return p


func _on_action(action: StringName) -> void:
	var r: Dictionary = PetController.request_care(action)
	print("[habitat] care ", action, " => ", r.get("reason", "ok"))
	_refresh_from_controller()


func _on_nav(scene_id: String) -> void:
	if SceneRouter.has_method("go"):
		SceneRouter.go(scene_id)
	else:
		print("[habitat] nav ", scene_id)


func _on_pet_updated(snap: Dictionary) -> void:
	_apply_snapshot(snap)


func _on_profile(snap: Dictionary) -> void:
	_counter.text = "Deaths: %d · Graves: %d" % [
		int(snap.get("total_pets_died", 0)),
		int(snap.get("total_graves_dug", 0)),
	]


func _refresh_from_controller() -> void:
	if PetController.active_pet != null:
		var mood = MoodStateMachineScr.derive_mood(PetController.active_pet)
		_apply_snapshot(PetController.active_pet.to_view_dict(mood))
	else:
		_apply_snapshot({})
	_on_profile(PetController.profile.to_view_dict(PetController.active_pet != null))


func _apply_snapshot(snap: Dictionary) -> void:
	var has_pet := not snap.is_empty() and str(snap.get("id", "")) != ""
	var life := str(snap.get("life_state", ""))
	_empty_panel.visible = not has_pet
	_death_panel.visible = has_pet and life == "DEAD" and not bool(snap.get("buried", false))
	_action_row.visible = has_pet and life != "DEAD"
	for c in _action_row.get_children():
		if c is Button:
			c.disabled = bool(snap.get("is_sleeping", false)) and str(c.text).to_lower() not in ["wake", "sleep"]
			if str(c.text).to_lower() == "wake":
				c.disabled = not bool(snap.get("is_sleeping", false))
			elif str(c.text).to_lower() == "sleep":
				c.disabled = bool(snap.get("is_sleeping", false)) or life == "DEAD"

	if not has_pet:
		_pet_label.text = "Empty bed"
		_pet_shape.color = Color(0.25, 0.25, 0.3)
		_status.text = "No pet — adopt to begin."
		for k in _meters:
			_meters[k].value = 0
		return

	_pet_label.text = "%s (%s)\n%s · mood %s" % [
		str(snap.get("name", "?")),
		str(snap.get("species_display", snap.get("species_id", ""))),
		life,
		str(snap.get("mood", "")),
	]
	_status.text = str(snap.get("status_message", PetController.get_status_line()))
	for k in _meters:
		_meters[k].value = float(snap.get(k, 0.0))
		_meters[k].modulate = _meter_color(float(snap.get(k, 0.0)))
	_pet_shape.color = _species_color(str(snap.get("species_id", "blob")), life, bool(snap.get("is_sleeping", false)))
	_apply_day_night(str(snap.get("local_day_phase", TimeService.local_day_phase())))


func _meter_color(v: float) -> Color:
	if v <= 0.0:
		return Color(1.0, 0.3, 0.3)
	if v < 15.0:
		return Color(1.0, 0.55, 0.2)
	if v < 40.0:
		return Color(1.0, 0.9, 0.3)
	return Color(0.5, 1.0, 0.55)


func _species_color(species_id: String, life: String, sleeping: bool) -> Color:
	if life == "DEAD":
		return Color(0.35, 0.35, 0.38)
	var base := Color(0.45, 0.75, 0.95)
	match species_id:
		"pup":
			base = Color(0.95, 0.7, 0.4)
		"owl":
			base = Color(0.55, 0.45, 0.85)
		_:
			base = Color(0.45, 0.8, 0.7)
	if sleeping:
		base = base.darkened(0.25)
	if life == "DYING":
		base = base.lerp(Color(1, 0.2, 0.2), 0.45)
	return base


func _apply_day_night(phase: String) -> void:
	match phase:
		"night":
			_day_night.color = Color(0.05, 0.08, 0.25, 0.55)
		"dusk":
			_day_night.color = Color(0.35, 0.15, 0.25, 0.35)
		"dawn":
			_day_night.color = Color(0.9, 0.55, 0.35, 0.25)
		_:
			_day_night.color = Color(0.9, 0.95, 1.0, 0.08)
