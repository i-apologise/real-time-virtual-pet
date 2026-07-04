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

# Care action timer (center-top countdown)
var _care_timer_panel: PanelContainer
var _care_timer_label: Label
var _care_timer_bar: ProgressBar


# Door zones (world space)
const DOOR_TOWN := Rect2(0, 210, 36, 56)       # left wall → town
const DOOR_YARD := Rect2(200, 290, 80, 30)      # south mat → backyard


func _ready() -> void:
	y_sort_enabled = true
	_build_room()
	_build_actors()
	_apply_spawn()
	_build_hud()
	_wire_director()
	if not EventBus.pet_updated.is_connected(_on_pet_updated):
		EventBus.pet_updated.connect(_on_pet_updated)
	if not EventBus.profile_updated.is_connected(_on_profile):
		EventBus.profile_updated.connect(_on_profile)
	_refresh_all()


func _apply_spawn() -> void:
	if _human == null:
		return
	var spawn := SceneRouter.take_spawn("default")
	match spawn:
		"from_town":
			_human.position = Vector2(48, 236)
		"from_backyard", "from_yard", "from_graveyard":
			_human.position = Vector2(240, 270)
		_:
			_human.position = Vector2(120, 220)


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


func _add_decor_rect(rect: Rect2, color: Color, z: int = -80) -> ColorRect:
	## Visual-only furniture (no collision) so actors can stand on beds/bath floor.
	var r := ColorRect.new()
	r.color = color
	r.size = rect.size
	r.position = rect.position
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(r)
	return r


func _add_prop_sprite(tex: Texture2D, pos: Vector2, scale_mul: float = 2.0, z: int = -80) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.position = pos
	spr.scale = Vector2(scale_mul, scale_mul)
	spr.z_index = z
	_world.add_child(spr)


func _build_room() -> void:
	_world = Node2D.new()
	_world.y_sort_enabled = true
	_world.name = "World"
	add_child(_world)

	_tile_floor(Rect2(0, 0, 480, 320), "floor")
	# wallpaper strip under top wall
	_tile_floor(Rect2(14, 28, 452, 32), "wall")
	# walls (solid) — leave door gaps on west + south
	_add_static_rect(Rect2(0, 0, 480, 28), Color("D4C4A8"), -50)
	# left wall with town door gap (y 210–266)
	_add_static_rect(Rect2(0, 0, 14, 210), Color("C8B898"))
	_add_static_rect(Rect2(0, 266, 14, 54), Color("C8B898"))
	_add_static_rect(Rect2(466, 0, 14, 320), Color("C8B898"))
	# bottom wall with backyard door gap (x 200–280)
	_add_static_rect(Rect2(0, 306, 200, 14), Color("B8A888"))
	_add_static_rect(Rect2(280, 306, 200, 14), Color("B8A888"))

	# Windows on north wall
	_add_decor_rect(Rect2(120, 32, 36, 22), Color("7EC8E8"), -88)
	_add_decor_rect(Rect2(124, 36, 12, 14), Color("E8F8FF"), -87)
	_add_decor_rect(Rect2(140, 36, 12, 14), Color("D0F0FF"), -87)
	_add_decor_rect(Rect2(280, 32, 36, 22), Color("7EC8E8"), -88)
	_add_decor_rect(Rect2(284, 36, 12, 14), Color("E8F8FF"), -87)
	_add_decor_rect(Rect2(300, 36, 12, 14), Color("D0F0FF"), -87)

	# --- Human bed (layered blocks + pixel prop on top) ---
	_add_decor_rect(Rect2(40, 48, 76, 48), Color("5A4030"), -90)
	_add_decor_rect(Rect2(44, 52, 68, 40), Color("6BA0B8"), -89)
	_add_decor_rect(Rect2(48, 54, 22, 14), Color("F5F2EA"), -88)
	_add_decor_rect(Rect2(52, 70, 52, 18), Color("C45C4A"), -88)
	_add_static_rect(Rect2(38, 42, 80, 10), Color("3A4A52"), -50)  # headboard solid
	_add_prop_sprite(SpriteFactoryScr.prop_texture("human_bed"), Vector2(78, 74), 2.0, -84)

	# --- Bathroom (top-right) — walkable tiles; small fixtures ---
	_tile_floor(Rect2(352, 32, 104, 88), "bath_tile")
	_add_static_rect(Rect2(404, 40, 28, 22), Color("E8EEF2"))  # toilet
	_add_decor_rect(Rect2(408, 36, 20, 10), Color("F5F8FA"), -74)
	_add_static_rect(Rect2(360, 40, 30, 18), Color("7EC8E0"))  # sink
	_add_decor_rect(Rect2(366, 44, 18, 8), Color("A8E0F0"), -74)
	# bath partition line
	_add_decor_rect(Rect2(348, 32, 4, 90), Color("A0B8C0"), -86)

	# --- Pet bed + bowl (pixel props) ---
	_add_prop_sprite(SpriteFactoryScr.prop_texture("pet_bed"), Vector2(312, 180), 2.0, -88)
	_add_prop_sprite(SpriteFactoryScr.prop_texture("bowl"), Vector2(258, 188), 1.6, -80)

	# Center rug
	_add_prop_sprite(SpriteFactoryScr.prop_texture("rug"), Vector2(208, 232), 2.0, -92)

	# Town door (left) — mat + frame
	_add_decor_rect(Rect2(0, 212, 16, 52), Color("5A3A22"), -70)
	_add_decor_rect(Rect2(2, 216, 12, 44), Color("8B5A2B"), -69)
	_add_decor_rect(Rect2(12, 232, 4, 8), Color("D4AF37"), -68)  # knob
	_add_decor_rect(Rect2(14, 255, 22, 10), Color("6B4B2E"), -91)  # door mat

	# Backyard door (south) — connected to home yard
	_add_decor_rect(Rect2(208, 300, 64, 20), Color("5A3A22"), -70)
	_add_decor_rect(Rect2(212, 302, 56, 16), Color("3D7A3A"), -69)  # green hint = yard
	_add_decor_rect(Rect2(220, 288, 40, 14), Color("8B6914"), -91)  # doormat

	# Soft floor accent near bed
	_add_decor_rect(Rect2(40, 100, 72, 8), Color(0.85, 0.78, 0.65, 0.35), -93)

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
	_pet.move_speed = 95.0
	_pet.position = Vector2(300, 175)
	_world.add_child(_pet)
	_reload_pet_sprites()
	_pet.setup_collision(true)

	# Leash visual (updated by CareDirector)
	var leash := Line2D.new()
	leash.name = "Leash"
	leash.width = 2.5
	leash.default_color = Color("6D4C41")
	leash.visible = false
	leash.z_index = 50
	_world.add_child(leash)
	set_meta("leash_line", leash)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(2.15, 2.15)  # show more of the room
	_camera.position = Vector2(0, -6)
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
	# Spots sit on walkable floor near furniture (not inside solid colliders)
	var spots := {
		"bathroom": Vector2(372, 118),
		"bathroom_pet": Vector2(400, 120),
		"bowl": Vector2(258, 196),
		"pet_bed": Vector2(312, 188),
		"human_bed": Vector2(76, 108),
		"human_bed_side": Vector2(100, 112),
		"play": Vector2(210, 220),
		"walk_a": Vector2(150, 250),
		"walk_b": Vector2(390, 255),
		"walk_home": Vector2(230, 210),
		"feed": Vector2(250, 196),
		"clean": Vector2(372, 118),
		"sleep": Vector2(312, 188),
		"wake": Vector2(312, 188),
		"walk": Vector2(300, 188),
	}
	var leash: Line2D = get_meta("leash_line") as Line2D
	_director.setup(_human, _pet, spots, leash)
	_director.toast.connect(_show_toast)
	_director.timer_tick.connect(_on_care_timer)
	_director.timer_done.connect(_on_care_timer_done)
	_director.choreography_finished.connect(func(_a, _r):
		_hide_care_timer()
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

	# Nav shortcuts (doors still preferred)
	var nav := HBoxContainer.new()
	nav.position = Vector2(8, 68)
	layer.add_child(nav)
	var b_town := Button.new()
	b_town.text = "Town door"
	b_town.add_theme_font_size_override("font_size", 11)
	b_town.pressed.connect(func(): SceneRouter.go("town", "from_house"))
	nav.add_child(b_town)
	var b_yard := Button.new()
	b_yard.text = "Backyard"
	b_yard.add_theme_font_size_override("font_size", 11)
	b_yard.pressed.connect(func(): SceneRouter.go("graveyard", "from_house"))
	nav.add_child(b_yard)
	var b_store := Button.new()
	b_store.text = "Store"
	b_store.add_theme_font_size_override("font_size", 11)
	b_store.pressed.connect(func(): SceneRouter.go("pet_store", "from_town"))
	nav.add_child(b_store)

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

	_death_panel = _panel("Your pet has passed. Use the back door (south) into your backyard to dig a grave.")
	var go_yard := Button.new()
	go_yard.text = "Open backyard door"
	go_yard.pressed.connect(func(): SceneRouter.go("graveyard", "from_house"))
	_death_panel.get_child(0).add_child(go_yard)
	layer.add_child(_death_panel)
	_death_panel.position = Vector2(150, 100)
	# Dig no longer happens in the house
	_dig_progress = null

	_debug = Label.new()
	_debug.visible = false
	_debug.position = Vector2(8, 200)
	_debug.add_theme_font_size_override("font_size", 10)
	_debug.modulate = Color(0.7, 1, 0.8)
	layer.add_child(_debug)

	# --- Care timer (center-top) ---
	_care_timer_panel = PanelContainer.new()
	_care_timer_panel.visible = false
	_care_timer_panel.position = Vector2(520, 8)
	layer.add_child(_care_timer_panel)
	var timer_v := VBoxContainer.new()
	timer_v.add_theme_constant_override("separation", 4)
	_care_timer_panel.add_child(timer_v)
	_care_timer_label = Label.new()
	_care_timer_label.text = "Care 0.0s"
	_care_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_care_timer_label.add_theme_font_size_override("font_size", 14)
	_care_timer_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16))
	timer_v.add_child(_care_timer_label)
	_care_timer_bar = ProgressBar.new()
	_care_timer_bar.custom_minimum_size = Vector2(160, 12)
	_care_timer_bar.max_value = 1.0
	_care_timer_bar.value = 1.0
	_care_timer_bar.show_percentage = false
	timer_v.add_child(_care_timer_bar)
	call_deferred("_place_care_timer")


func _on_care_timer(seconds_left: float, total: float, label: String) -> void:
	if _care_timer_panel == null:
		return
	_care_timer_panel.visible = true
	_place_care_timer()
	var t := maxf(0.0, seconds_left)
	_care_timer_label.text = "%s  %.1fs" % [label, t]
	if total > 0.0:
		_care_timer_bar.max_value = total
		_care_timer_bar.value = t
	# Urgency color as time runs out
	if total > 0.0 and t / total < 0.25:
		_care_timer_bar.modulate = Color(1.0, 0.55, 0.4)
	else:
		_care_timer_bar.modulate = Color(0.55, 0.85, 1.0)


func _on_care_timer_done() -> void:
	_hide_care_timer()


func _hide_care_timer() -> void:
	if _care_timer_panel:
		_care_timer_panel.visible = false


func _place_care_timer() -> void:
	if _care_timer_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_care_timer_panel.position = Vector2(vp.x * 0.5 - 90.0, 8.0)


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


func _at_door(rect: Rect2) -> bool:
	if _human == null:
		return false
	return rect.has_point(_human.position)


func _process(delta: float) -> void:
	_update_near_pet_ui()
	_place_stats_panel()
	# Door proximity hints (backyard is attached to home)
	if _human and not _care_menu_open and not (_director and _director.is_busy()):
		if _at_door(DOOR_TOWN):
			_hint.text = "Town door — press E to leave home"
		elif _at_door(DOOR_YARD):
			_hint.text = "Backyard door — press E (graveyard is behind the house)"
	if Input.is_action_just_pressed("interact"):
		if _care_menu_open:
			_confirm_care_selection()
			return
		if _at_door(DOOR_TOWN):
			SceneRouter.go("town", "from_house")
			return
		if _at_door(DOOR_YARD):
			SceneRouter.go("graveyard", "from_house")
			return
		if _near_pet and PetController.active_pet != null and str(PetController.active_pet.life_state) != "DEAD":
			_open_care_menu()
		elif _near_pet and PetController.active_pet != null and str(PetController.active_pet.life_state) == "DEAD":
			_show_toast("Take them out the back door to the backyard")


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
		_show_toast("Take them to the backyard Graveyard to dig")
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

	# Don't overwrite door hints while standing on a door
	if _at_door(DOOR_TOWN) or _at_door(DOOR_YARD):
		return
	if _near_pet and life != "DEAD" and life != "":
		_hint.text = "Near %s — E open CARE · ↑↓ · Z/Enter" % str(PetController.active_pet.name)
	elif PetController.active_pet == null:
		_hint.text = "Adopt a pet · WASD · left door=Town · south door=Backyard"
	elif life == "DEAD":
		_hint.text = "Pet passed — south door to backyard · hold E at plot to dig"
	else:
		_hint.text = "Near pet for CARE · left door Town · south door Backyard"


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
