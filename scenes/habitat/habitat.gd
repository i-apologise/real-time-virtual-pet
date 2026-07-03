extends Node2D
## 2D house simulation: animated human + pet, care choreography, HUD overlay.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const CareDirectorScr = preload("res://src/gameplay/care_director.gd")
const MoodStateMachineScr = preload("res://src/sim/mood_state_machine.gd")

var _human: CharacterBody2D
var _pet: CharacterBody2D
var _director: Node
var _camera: Camera2D

# HUD
var _meters: Dictionary = {}
var _status: Label
var _toast: Label
var _counter: Label
var _action_row: HBoxContainer
var _empty_panel: PanelContainer
var _death_panel: PanelContainer
var _day_overlay: ColorRect
var _debug: Label
var _debug_visible: bool = false
var _dig_progress: ProgressBar
var _digging: bool = false
var _dig_accum: float = 0.0
const DIG_HOLD_SEC := 3.0


func _ready() -> void:
	_build_room()
	_build_actors()
	_build_hud()
	_wire_director()
	if not EventBus.pet_updated.is_connected(_on_pet_updated):
		EventBus.pet_updated.connect(_on_pet_updated)
	if not EventBus.profile_updated.is_connected(_on_profile):
		EventBus.profile_updated.connect(_on_profile)
	_refresh_all()


func _build_room() -> void:
	# Floor
	var floor := ColorRect.new()
	floor.color = Color(0.45, 0.36, 0.28)
	floor.size = Vector2(960, 540)
	floor.position = Vector2(0, 0)
	floor.z_index = -10
	add_child(floor)
	# rug
	var rug := ColorRect.new()
	rug.color = Color(0.55, 0.25, 0.25)
	rug.size = Vector2(220, 140)
	rug.position = Vector2(370, 280)
	rug.z_index = -9
	add_child(rug)
	# wall
	var wall := ColorRect.new()
	wall.color = Color(0.72, 0.68, 0.58)
	wall.size = Vector2(960, 120)
	wall.position = Vector2(0, 0)
	wall.z_index = -8
	add_child(wall)
	# window
	var window := ColorRect.new()
	window.color = Color(0.55, 0.75, 0.95)
	window.size = Vector2(100, 70)
	window.position = Vector2(80, 30)
	window.z_index = -7
	add_child(window)
	# bed / cushion for pet
	var bed := ColorRect.new()
	bed.color = Color(0.85, 0.8, 0.7)
	bed.size = Vector2(80, 50)
	bed.position = Vector2(520, 300)
	bed.z_index = -6
	add_child(bed)
	var bed_l := Label.new()
	bed_l.text = "pet bed"
	bed_l.position = Vector2(528, 350)
	bed_l.z_index = -5
	bed_l.add_theme_font_size_override("font_size", 11)
	add_child(bed_l)
	# bowl
	var bowl := ColorRect.new()
	bowl.color = Color(0.9, 0.85, 0.5)
	bowl.size = Vector2(28, 16)
	bowl.position = Vector2(470, 330)
	bowl.z_index = -6
	add_child(bowl)
	# door to town
	var door := ColorRect.new()
	door.color = Color(0.4, 0.28, 0.18)
	door.size = Vector2(50, 80)
	door.position = Vector2(20, 400)
	door.z_index = -6
	add_child(door)
	var door_l := Label.new()
	door_l.text = "Town (E)"
	door_l.position = Vector2(14, 480)
	door_l.add_theme_font_size_override("font_size", 11)
	add_child(door_l)

	_day_overlay = ColorRect.new()
	_day_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_overlay.color = Color(0, 0, 0, 0)
	_day_overlay.size = Vector2(960, 540)
	_day_overlay.z_index = 50
	add_child(_day_overlay)


func _build_actors() -> void:
	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.move_speed = 160.0
	_human.position = Vector2(200, 380)
	add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.2)

	_pet = AnimatedActorScr.new()
	_pet.is_player_controlled = false
	_pet.move_speed = 90.0
	_pet.position = Vector2(540, 320)
	add_child(_pet)
	_reload_pet_sprites()

	_camera = Camera2D.new()
	_camera.position = Vector2(0, -20)
	_human.add_child(_camera)
	_camera.make_current()
	# Keep house framed
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 960
	_camera.limit_bottom = 540


func _reload_pet_sprites() -> void:
	var sid := "blob"
	if PetController.active_pet != null:
		sid = String(PetController.active_pet.species_id)
	_pet.setup_frames(SpriteFactoryScr.pet_frames(sid), 2.4)


func _wire_director() -> void:
	_director = CareDirectorScr.new()
	add_child(_director)
	var spots := {
		"feed": Vector2(490, 340),
		"play": Vector2(500, 340),
		"walk": Vector2(500, 340),
		"clean": Vector2(510, 340),
		"sleep": Vector2(520, 330),
		"wake": Vector2(520, 330),
	}
	_director.setup(_human, _pet, spots)
	_director.toast.connect(_show_toast)
	_director.choreography_finished.connect(func(_a, _r): _refresh_all())


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = 200
	layer.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "House — WASD move · 1-6 care · E town door"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_counter = Label.new()
	_counter.text = "Deaths: 0 · Graves: 0"
	top.add_child(_counter)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	_toast = Label.new()
	_toast.modulate = Color(1, 1, 0.65)
	root.add_child(_toast)

	var meter_box := HBoxContainer.new()
	meter_box.add_theme_constant_override("separation", 10)
	root.add_child(meter_box)
	for stat in ["hunger", "energy", "happiness", "hygiene"]:
		var col := VBoxContainer.new()
		meter_box.add_child(col)
		var lab := Label.new()
		lab.text = stat.substr(0, 3).to_upper()
		lab.add_theme_font_size_override("font_size", 11)
		col.add_child(lab)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(90, 14)
		bar.max_value = 100
		col.add_child(bar)
		_meters[stat] = bar

	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 6)
	root.add_child(_action_row)
	var keys := ["1 Feed", "2 Walk", "3 Play", "4 Clean", "5 Sleep", "6 Wake"]
	var actions := ["feed", "walk", "play", "clean", "sleep", "wake"]
	for i in actions.size():
		var btn := Button.new()
		btn.text = keys[i]
		btn.pressed.connect(_on_care_pressed.bind(StringName(actions[i])))
		_action_row.add_child(btn)

	var nav := HBoxContainer.new()
	root.add_child(nav)
	for item in [["Town", "town"], ["Store", "pet_store"], ["Graveyard", "graveyard"]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(func(): SceneRouter.go(item[1]))
		nav.add_child(b)

	_empty_panel = _banner("No living pet — adopt to start the simulation.")
	var adopt := Button.new()
	adopt.text = "Adopt Cozy Blob (quick)"
	adopt.pressed.connect(func():
		PetController.debug_adopt_blob("Mochi")
		_reload_pet_sprites()
		_show_toast("Adopted Mochi!")
		_refresh_all()
	)
	_empty_panel.get_child(0).add_child(adopt)
	var store := Button.new()
	store.text = "Pet Store"
	store.pressed.connect(func(): SceneRouter.go("pet_store"))
	_empty_panel.get_child(0).add_child(store)
	layer.add_child(_empty_panel)
	_empty_panel.position = Vector2(280, 180)

	_death_panel = _banner("Your pet died. Hold Dig Grave to bury them.")
	_dig_progress = ProgressBar.new()
	_dig_progress.max_value = 100
	_death_panel.get_child(0).add_child(_dig_progress)
	var dig := Button.new()
	dig.text = "Hold Dig Grave"
	dig.button_down.connect(func():
		_digging = true
		_dig_accum = 0.0
		if _director and _human:
			_human.set_busy(true)
			_human.play_anim(&"dig")
	)
	dig.button_up.connect(func():
		_digging = false
		_dig_accum = 0.0
		_dig_progress.value = 0
		if _human:
			_human.set_busy(false)
			_human.play_idle()
	)
	_death_panel.get_child(0).add_child(dig)
	layer.add_child(_death_panel)
	_death_panel.position = Vector2(280, 180)

	_debug = Label.new()
	_debug.visible = false
	_debug.position = Vector2(8, 420)
	_debug.modulate = Color(0.7, 1, 0.8)
	layer.add_child(_debug)

	var help := Label.new()
	help.position = Vector2(8, 500)
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(0.85, 0.85, 0.9)
	help.text = "Gameplay: walk with WASD · care plays character animations · pets only have needs"
	layer.add_child(help)


func _banner(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	v.add_child(l)
	return p


func _process(delta: float) -> void:
	if _digging:
		_dig_accum += delta
		_dig_progress.value = (_dig_accum / DIG_HOLD_SEC) * 100.0
		if _dig_accum >= DIG_HOLD_SEC:
			_digging = false
			_dig_accum = 0.0
			if _human:
				_human.set_busy(false)
				_human.play_idle()
			var r: Dictionary = PetController.complete_burial("")
			_show_toast("Burial complete" if r.get("ok", false) else str(r.get("reason", "fail")))
			_refresh_all()

	# Door interact
	if _human and _human.global_position.distance_to(Vector2(45, 440)) < 55.0:
		if Input.is_action_just_pressed("interact"):
			SceneRouter.go("town")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	if k.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		_debug.visible = _debug_visible
		_update_debug()
	elif k.keycode == KEY_F7:
		_debug_advance(3600.0)
	elif k.keycode == KEY_F8:
		_debug_advance(3.0 * 86400.0)
	elif k.keycode == KEY_F9:
		_debug_advance(2.0 * 3600.0)
	elif k.keycode == KEY_1:
		_on_care_pressed(&"feed")
	elif k.keycode == KEY_2:
		_on_care_pressed(&"walk")
	elif k.keycode == KEY_3:
		_on_care_pressed(&"play")
	elif k.keycode == KEY_4:
		_on_care_pressed(&"clean")
	elif k.keycode == KEY_5:
		_on_care_pressed(&"sleep")
	elif k.keycode == KEY_6:
		_on_care_pressed(&"wake")


func _on_care_pressed(action: StringName) -> void:
	if _director and _director.is_busy():
		_show_toast("Busy…")
		return
	var r: Dictionary = _director.try_start_care(action)
	if not r.get("ok", false):
		_show_toast("Can't %s: %s" % [str(action), str(r.get("reason", ""))])


func _debug_advance(sec: float) -> void:
	TimeService.add_debug_offset_sec(sec)
	PetController.on_focus_resume()
	_show_toast("Debug clock +%.0fs" % sec)
	_refresh_all()


func _show_toast(msg: String) -> void:
	if _toast:
		_toast.text = msg


func _on_pet_updated(snap: Dictionary) -> void:
	_apply_snap(snap)
	_update_debug()
	_sync_pet_visual()


func _on_profile(snap: Dictionary) -> void:
	_counter.text = "Deaths: %d · Graves: %d" % [
		int(snap.get("total_pets_died", 0)), int(snap.get("total_graves_dug", 0))
	]


func _refresh_all() -> void:
	if PetController.active_pet != null:
		var mood = MoodStateMachineScr.derive_mood(PetController.active_pet)
		var snap: Dictionary = PetController.active_pet.to_view_dict(mood)
		var st: Dictionary = StatusCopy.status_for_pet(PetController.active_pet)
		snap["status_message"] = st.get("message", "")
		snap["local_day_phase"] = TimeService.local_day_phase()
		_apply_snap(snap)
	else:
		_apply_snap({})
	_on_profile(PetController.profile.to_view_dict(PetController.active_pet != null))
	_sync_pet_visual()
	_update_debug()


func _apply_snap(snap: Dictionary) -> void:
	var has_pet := not snap.is_empty() and str(snap.get("id", "")) != ""
	var life := str(snap.get("life_state", ""))
	_empty_panel.visible = not has_pet
	_death_panel.visible = has_pet and life == "DEAD" and not bool(snap.get("buried", false))
	_action_row.visible = has_pet and life != "DEAD"
	_pet.visible = has_pet
	if _status:
		if has_pet:
			_status.text = "%s (%s) · %s · %s" % [
				str(snap.get("name", "?")),
				str(snap.get("species_display", "")),
				life,
				str(snap.get("status_message", "")),
			]
		else:
			_status.text = "No pet — adopt to begin real-time care simulation."
	for k in _meters:
		_meters[k].value = float(snap.get(k, 0.0)) if has_pet else 0.0
	_apply_day_night(str(snap.get("local_day_phase", TimeService.local_day_phase())))


func _sync_pet_visual() -> void:
	if _pet == null:
		return
	if PetController.active_pet == null:
		return
	_reload_pet_sprites()
	if _director:
		_director._sync_pet_mood_anim()


func _apply_day_night(phase: String) -> void:
	match phase:
		"night":
			_day_overlay.color = Color(0.05, 0.08, 0.25, 0.45)
		"dusk":
			_day_overlay.color = Color(0.35, 0.15, 0.25, 0.28)
		"dawn":
			_day_overlay.color = Color(0.9, 0.55, 0.35, 0.18)
		_:
			_day_overlay.color = Color(1, 1, 1, 0.0)


func _update_debug() -> void:
	if _debug == null or not _debug_visible:
		return
	var lines: PackedStringArray = []
	lines.append("DEBUG · offset=%.0f · phase=%s" % [TimeService.debug_offset_sec, TimeService.local_day_phase()])
	if PetController.active_pet:
		var p = PetController.active_pet
		lines.append(
			"%s %s H=%.0f E=%.0f A=%.0f Y=%.0f hold=%.0f"
			% [p.name, str(p.life_state), p.hunger, p.energy, p.happiness, p.hygiene, p.zero_hold_sec]
		)
	_debug.text = "\n".join(lines)
