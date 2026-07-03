extends Node2D
## Pokemon-style house: pixel tiles, collisions, near-pet stats only, care choreography.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const CareDirectorScr = preload("res://src/gameplay/care_director.gd")
const MoodStateMachineScr = preload("res://src/sim/mood_state_machine.gd")

const NEAR_PET_DIST := 56.0
const LAYER_WORLD := 1

var _human: CharacterBody2D
var _pet: CharacterBody2D
var _director: Node
var _camera: Camera2D
var _world: Node2D

# HUD
var _hint: Label
var _toast: Label
var _counter: Label
var _empty_panel: PanelContainer
var _death_panel: PanelContainer
var _day_overlay: ColorRect
var _debug: Label
var _debug_visible: bool = false
var _dig_progress: ProgressBar
var _digging: bool = false
var _dig_accum: float = 0.0
const DIG_HOLD_SEC := 3.0

# Top-right needs panel (progress bars — never over the pet)
var _stats_panel: PanelContainer
var _stat_bars: Dictionary = {}  # name -> ProgressBar
var _stat_title: Label

# Pokemon-style vertical care menu (bottom-left)
var _care_panel: PanelContainer
var _care_list: VBoxContainer
var _care_labels: Array = []  # Label nodes
var _care_actions: Array = ["feed", "walk", "play", "clean", "sleep", "wake", "cancel"]
var _care_cursor: int = 0
var _near_pet: bool = false
var _care_menu_open: bool = false


func _ready() -> void:
	y_sort_enabled = true
	_build_room()
	_build_actors()
	_build_hud()
	_wire_director()
	if not EventBus.pet_updated.is_connected(_on_pet_updated):
		EventBus.pet_updated.connect(_on_pet_updated)
	if not EventBus.profile_updated.is_connected(_on_profile):
		EventBus.profile_updated.connect(_on_profile)
	_refresh_all()


func _add_static_rect(rect: Rect2, color: Color, z: int = 0) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.z_index = int(body.position.y)
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	vis.color = color
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(vis)
	_world.add_child(body)


func _tile_floor(area: Rect2, kind: String) -> void:
	var tex: Texture2D = SpriteFactoryScr.make_tile(kind)
	var x := int(area.position.x)
	var y := int(area.position.y)
	while y < int(area.end.y):
		x = int(area.position.x)
		while x < int(area.end.x):
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = Vector2(x + 8, y + 8)
			spr.scale = Vector2(1, 1)
			spr.z_index = -100
			_world.add_child(spr)
			x += 16
		y += 16


func _build_room() -> void:
	_world = Node2D.new()
	_world.y_sort_enabled = true
	_world.name = "World"
	add_child(_world)

	_tile_floor(Rect2(0, 0, 480, 320), "floor")
	# walls as colliders (top of room)
	_add_static_rect(Rect2(0, 0, 480, 32), Color("E8DCC8"), -50)
	_add_static_rect(Rect2(0, 0, 16, 320), Color("D8CCB8"))
	_add_static_rect(Rect2(464, 0, 16, 320), Color("D8CCB8"))
	_add_static_rect(Rect2(0, 304, 480, 16), Color("C8BCA8"))
	# furniture
	_add_static_rect(Rect2(48, 40, 64, 40), Color("85C1E9"))  # window sill block
	_add_static_rect(Rect2(280, 150, 56, 40), Color("F5EEDE"))  # bed
	_add_static_rect(Rect2(240, 175, 24, 14), Color("F5D76E"))  # bowl
	_add_static_rect(Rect2(20, 200, 28, 48), Color("6E4B2E"))  # door block slightly open path
	# leave gap at door for walking out — move door collider to sides only
	# rug (no collision)
	var rug := ColorRect.new()
	rug.color = Color("A93226")
	rug.size = Vector2(96, 64)
	rug.position = Vector2(190, 160)
	rug.z_index = -90
	rug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(rug)

	_day_overlay = ColorRect.new()
	_day_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_overlay.color = Color(0, 0, 0, 0)
	_day_overlay.size = Vector2(480, 320)
	_day_overlay.z_index = 400
	add_child(_day_overlay)


func _build_actors() -> void:
	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.is_pet = false
	_human.move_speed = 100.0
	_human.position = Vector2(120, 220)
	_world.add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)  # same scale as town AI
	_human.setup_collision(false)

	_pet = AnimatedActorScr.new()
	_pet.is_player_controlled = false
	_pet.is_pet = true
	_pet.move_speed = 0.0
	_pet.position = Vector2(300, 175)
	_world.add_child(_pet)
	_reload_pet_sprites()
	_pet.setup_collision(true)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(2.5, 2.5)  # chunky pokemon zoom
	_camera.position = Vector2(0, -8)
	_human.add_child(_camera)
	_camera.make_current()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 480
	_camera.limit_bottom = 320
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0


func _reload_pet_sprites() -> void:
	var sid := "blob"
	if PetController.active_pet != null:
		sid = String(PetController.active_pet.species_id)
	_pet.is_pet = true
	_pet.setup_frames(SpriteFactoryScr.pet_frames(sid), 2.0)
	_pet.setup_collision(true)
	_apply_pet_condition_visual()


func _condition_from_pet(p) -> String:
	if p == null:
		return "healthy"
	var life := str(p.life_state)
	if life == "DEAD":
		return "dead"
	if life == "DYING" or p.hunger <= 0.0 or p.energy <= 5.0:
		return "weak"
	if life == "CRITICAL" or p.hunger < 20.0:
		return "hungry"
	if p.hunger < 40.0 or p.happiness < 30.0:
		return "hungry"
	return "healthy"


func _apply_pet_condition_visual() -> void:
	if _pet == null or PetController.active_pet == null:
		return
	var cond := _condition_from_pet(PetController.active_pet)
	_pet.set_condition(cond)
	match cond:
		"dead":
			_pet.play_anim(&"dead")
		"weak":
			_pet.play_anim(&"weak")
		"hungry":
			_pet.play_anim(&"hungry")
		_:
			if PetController.active_pet.is_sleeping():
				_pet.play_anim(&"sleep")
			elif PetController.active_pet.happiness >= 75.0:
				_pet.play_anim(&"happy")
			else:
				_pet.play_anim(&"idle")


func _wire_director() -> void:
	_director = CareDirectorScr.new()
	add_child(_director)
	var spots := {
		"feed": Vector2(270, 185),
		"play": Vector2(275, 190),
		"walk": Vector2(275, 190),
		"clean": Vector2(280, 185),
		"sleep": Vector2(290, 175),
		"wake": Vector2(290, 175),
	}
	_director.setup(_human, _pet, spots)
	_director.toast.connect(_show_toast)
	_director.choreography_finished.connect(func(_a, _r):
		_refresh_all()
		_apply_pet_condition_visual()
	)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)

	# --- Top-left: counter + hints ---
	var top := HBoxContainer.new()
	top.position = Vector2(8, 6)
	layer.add_child(top)
	_counter = Label.new()
	_counter.add_theme_font_size_override("font_size", 12)
	_counter.add_theme_color_override("font_color", Color(1, 1, 1))
	_counter.text = "Deaths 0 · Graves 0"
	top.add_child(_counter)

	_hint = Label.new()
	_hint.position = Vector2(8, 26)
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
	_hint.text = "WASD move · near pet · E care menu · ↑↓ select · Z/Enter confirm"
	layer.add_child(_hint)

	_toast = Label.new()
	_toast.position = Vector2(8, 46)
	_toast.add_theme_font_size_override("font_size", 12)
	_toast.modulate = Color(1, 1, 0.6)
	layer.add_child(_toast)

	# --- Top-right: needs progress bars (never over the pet) ---
	_stats_panel = PanelContainer.new()
	_stats_panel.visible = false
	# Anchor top-right-ish for 1280 UI; use fixed pos that works with default window
	_stats_panel.position = Vector2(1000, 8)
	# Also set for smaller viewports via set_anchors later if needed
	layer.add_child(_stats_panel)
	var stats_v := VBoxContainer.new()
	stats_v.add_theme_constant_override("separation", 4)
	_stats_panel.add_child(stats_v)
	_stat_title = Label.new()
	_stat_title.text = "Pet"
	_stat_title.add_theme_font_size_override("font_size", 13)
	_stat_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	stats_v.add_child(_stat_title)
	_stat_bars.clear()
	for stat in ["hunger", "energy", "happiness", "hygiene"]:
		var row := HBoxContainer.new()
		stats_v.add_child(row)
		var lab := Label.new()
		lab.text = stat.substr(0, 3).to_upper()
		lab.custom_minimum_size = Vector2(36, 0)
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
		row.add_child(lab)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(120, 14)
		bar.max_value = 100.0
		bar.show_percentage = false
		row.add_child(bar)
		_stat_bars[stat] = bar

	# Place stats panel using full rect margins after layout
	call_deferred("_place_stats_panel")

	# --- Pokemon-style care menu (bottom-left) ---
	_care_panel = PanelContainer.new()
	_care_panel.visible = false
	_care_panel.position = Vector2(12, 360)
	layer.add_child(_care_panel)
	var care_outer := VBoxContainer.new()
	care_outer.add_theme_constant_override("separation", 2)
	_care_panel.add_child(care_outer)
	var care_title := Label.new()
	care_title.text = "CARE"
	care_title.add_theme_font_size_override("font_size", 14)
	care_title.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	care_outer.add_child(care_title)
	var help := Label.new()
	help.text = "↑↓  Z/Enter  X/Esc"
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	care_outer.add_child(help)
	_care_list = VBoxContainer.new()
	_care_list.add_theme_constant_override("separation", 0)
	care_outer.add_child(_care_list)
	_care_labels.clear()
	var names := ["FEED", "WALK", "PLAY", "CLEAN", "SLEEP", "WAKE", "CANCEL"]
	for i in names.size():
		var lab2 := Label.new()
		lab2.add_theme_font_size_override("font_size", 14)
		lab2.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
		lab2.text = "  " + names[i]
		lab2.custom_minimum_size = Vector2(140, 20)
		_care_list.add_child(lab2)
		_care_labels.append(lab2)
	_refresh_care_cursor()

	# Nav top
	var nav := HBoxContainer.new()
	nav.position = Vector2(8, 68)
	layer.add_child(nav)
	for item in [["Town", "town"], ["Store", "pet_store"], ["Yard", "graveyard"]]:
		var b := Button.new()
		b.text = item[0]
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(func(): SceneRouter.go(item[1]))
		nav.add_child(b)

	_empty_panel = _panel("No pet yet — adopt to begin.")
	var adopt := Button.new()
	adopt.text = "Adopt Blob"
	adopt.pressed.connect(func():
		PetController.debug_adopt_blob("Mochi")
		_reload_pet_sprites()
		_show_toast("Mochi joined!")
		_refresh_all()
	)
	_empty_panel.get_child(0).add_child(adopt)
	layer.add_child(_empty_panel)
	_empty_panel.position = Vector2(150, 100)

	_death_panel = _panel("Pet has died. Hold Dig Grave.")
	_dig_progress = ProgressBar.new()
	_dig_progress.custom_minimum_size = Vector2(160, 12)
	_dig_progress.max_value = 100
	_death_panel.get_child(0).add_child(_dig_progress)
	var dig := Button.new()
	dig.text = "Hold Dig Grave"
	dig.button_down.connect(func():
		_digging = true
		_dig_accum = 0.0
		if _human:
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
	_death_panel.position = Vector2(150, 100)

	_debug = Label.new()
	_debug.visible = false
	_debug.position = Vector2(8, 200)
	_debug.add_theme_font_size_override("font_size", 10)
	_debug.modulate = Color(0.7, 1, 0.8)
	layer.add_child(_debug)


func _place_stats_panel() -> void:
	# Top-right of viewport
	if _stats_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_stats_panel.position = Vector2(vp.x - 200, 8)


func _panel(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	v.add_child(l)
	return p


func _refresh_care_cursor() -> void:
	var names := ["FEED", "WALK", "PLAY", "CLEAN", "SLEEP", "WAKE", "CANCEL"]
	for i in _care_labels.size():
		var lab: Label = _care_labels[i]
		if i == _care_cursor:
			lab.text = "▶ " + names[i]
			lab.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
		else:
			lab.text = "  " + names[i]
			lab.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16))


func _process(delta: float) -> void:
	_update_near_pet_ui()
	_place_stats_panel()
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
			_show_toast("Buried." if r.get("ok", false) else str(r.get("reason", "")))
			_refresh_all()
	# E: care menu near pet; else town door
	if Input.is_action_just_pressed("interact"):
		if _care_menu_open:
			_confirm_care_selection()
		elif _near_pet and PetController.active_pet != null and str(PetController.active_pet.life_state) != "DEAD":
			_open_care_menu()
		elif _human and _human.position.x < 40.0 and _human.position.y > 200.0:
			SceneRouter.go("town")


func _close_care_menu() -> void:
	_care_menu_open = false
	if _care_panel:
		_care_panel.visible = false
	# Resume player movement
	if _human and _director and not _director.is_busy():
		_human.set_busy(false)


func _open_care_menu() -> void:
	if not _near_pet or PetController.active_pet == null:
		_show_toast("Get closer to your pet, then press E")
		return
	var life := str(PetController.active_pet.life_state)
	if life == "DEAD":
		_show_toast("Your pet has passed — use Dig Grave")
		return
	_care_menu_open = true
	_care_cursor = 0
	_refresh_care_cursor()
	_care_panel.visible = true
	# Freeze player while menu open (Pokemon-style)
	if _human:
		_human.set_busy(true)
		_human.play_idle()
	_show_toast("↑↓ select · Z/Enter/E confirm · X/Esc cancel")


func _confirm_care_selection() -> void:
	if not _care_menu_open:
		return
	var action: String = str(_care_actions[_care_cursor])
	if action == "cancel":
		_close_care_menu()
		if _human and (_director == null or not _director.is_busy()):
			_human.set_busy(false)
		return
	_on_care(StringName(action))


func _update_near_pet_ui() -> void:
	if _human == null or _pet == null or not _pet.visible:
		_near_pet = false
		if _stats_panel:
			_stats_panel.visible = false
		if not _care_menu_open and _care_panel:
			_care_panel.visible = false
		return
	var dist := _human.global_position.distance_to(_pet.global_position)
	_near_pet = dist <= NEAR_PET_DIST and PetController.active_pet != null
	var life := ""
	if PetController.active_pet:
		life = str(PetController.active_pet.life_state)
	if not _near_pet and _care_menu_open:
		_close_care_menu()
		if _human and (_director == null or not _director.is_busy()):
			_human.set_busy(false)

	# Top-right bars: show when living pet exists (always visible, never over sprites)
	var show_stats := PetController.active_pet != null and life != "DEAD" and life != ""
	if _stats_panel:
		_stats_panel.visible = show_stats
	if show_stats and PetController.active_pet:
		var p = PetController.active_pet
		_stat_title.text = "%s  [%s]" % [p.name, _condition_from_pet(p)]
		_stat_bars["hunger"].value = p.hunger
		_stat_bars["energy"].value = p.energy
		_stat_bars["happiness"].value = p.happiness
		_stat_bars["hygiene"].value = p.hygiene
		for k in _stat_bars:
			_stat_bars[k].modulate = _bar_color(float(_stat_bars[k].value))

	if _near_pet and life != "DEAD" and life != "":
		_hint.text = "Near %s — E open CARE · ↑↓ · Z/Enter" % str(PetController.active_pet.name)
	elif PetController.active_pet == null:
		_hint.text = "Adopt a pet · WASD · E at door for town"
	elif life == "DEAD":
		_hint.text = "Your pet has passed — hold Dig Grave"
	else:
		_hint.text = "Walk near pet · E for CARE menu · WASD"


func _bar_color(v: float) -> Color:
	if v <= 5.0:
		return Color(1.0, 0.35, 0.35)
	if v < 25.0:
		return Color(1.0, 0.7, 0.3)
	if v < 50.0:
		return Color(1.0, 0.95, 0.4)
	return Color(0.55, 1.0, 0.55)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	# Pokemon-style menu navigation
	if _care_menu_open:
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_X:
			_close_care_menu()
			if _human and (_director == null or not _director.is_busy()):
				_human.set_busy(false)
			return
		if k.keycode == KEY_UP or k.keycode == KEY_W:
			_care_cursor = (_care_cursor - 1 + _care_actions.size()) % _care_actions.size()
			_refresh_care_cursor()
			return
		if k.keycode == KEY_DOWN or k.keycode == KEY_S:
			_care_cursor = (_care_cursor + 1) % _care_actions.size()
			_refresh_care_cursor()
			return
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_Z or k.keycode == KEY_SPACE:
			_confirm_care_selection()
			return
		# Optional number jump
		if k.keycode >= KEY_1 and k.keycode <= KEY_6:
			_care_cursor = k.keycode - KEY_1
			_refresh_care_cursor()
			_confirm_care_selection()
			return

	if k.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		_debug.visible = _debug_visible
		_update_debug()
	elif k.keycode == KEY_F7:
		_dbg(3600.0)
	elif k.keycode == KEY_F8:
		_dbg(3.0 * 86400.0)
	elif k.keycode == KEY_F9:
		_dbg(2.0 * 3600.0)


func _on_care(action: StringName) -> void:
	if not _near_pet and action != &"dig":
		_show_toast("Get closer to your pet")
		_close_care_menu()
		return
	if _director and _director.is_busy():
		_show_toast("…")
		return
	# Release menu freeze so care walk can run
	_care_menu_open = false
	if _care_panel:
		_care_panel.visible = false
	if _human:
		_human.set_busy(false)
	var r: Dictionary = _director.try_start_care(action)
	if not r.get("ok", false):
		_show_toast(str(r.get("reason", "no")))
		if _human and not _director.is_busy():
			_human.set_busy(false)


func _dbg(sec: float) -> void:
	TimeService.add_debug_offset_sec(sec)
	PetController.on_focus_resume()
	_show_toast("Time +%.0fs" % sec)
	_refresh_all()
	_apply_pet_condition_visual()


func _show_toast(msg: String) -> void:
	_toast.text = msg


func _on_pet_updated(_snap: Dictionary) -> void:
	_refresh_all()
	_apply_pet_condition_visual()


func _on_profile(snap: Dictionary) -> void:
	_counter.text = "Deaths %d · Graves %d" % [
		int(snap.get("total_pets_died", 0)), int(snap.get("total_graves_dug", 0))
	]


func _refresh_all() -> void:
	var has := PetController.active_pet != null
	var life := str(PetController.active_pet.life_state) if has else ""
	_empty_panel.visible = not has
	_death_panel.visible = has and life == "DEAD" and not PetController.active_pet.buried
	_pet.visible = has
	_on_profile(PetController.profile.to_view_dict(has))
	_apply_day_night(str(TimeService.local_day_phase()))
	_update_debug()
	_apply_pet_condition_visual()


func _apply_day_night(phase: String) -> void:
	match phase:
		"night":
			_day_overlay.color = Color(0.05, 0.08, 0.28, 0.4)
		"dusk":
			_day_overlay.color = Color(0.4, 0.15, 0.25, 0.22)
		"dawn":
			_day_overlay.color = Color(0.95, 0.55, 0.3, 0.12)
		_:
			_day_overlay.color = Color(0, 0, 0, 0)


func _update_debug() -> void:
	if not _debug_visible or _debug == null:
		return
	if PetController.active_pet:
		var p = PetController.active_pet
		_debug.text = "%s %s H=%.0f hold=%.0f cond=%s" % [
			p.name, str(p.life_state), p.hunger, p.zero_hold_sec, _condition_from_pet(p)
		]
	else:
		_debug.text = "no pet"
