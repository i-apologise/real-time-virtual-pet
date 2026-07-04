extends Node2D
## Pokemon-style house: pixel tiles, collisions, near-pet stats only, care choreography.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const CareDirectorScr = preload("res://src/gameplay/care_director.gd")
const MoodStateMachineScr = preload("res://src/sim/mood_state_machine.gd")
const NeedsForecastScr = preload("res://src/sim/needs_forecast.gd")
const CareAdvisorScr = preload("res://src/sim/care_advisor.gd")

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
var _stat_value_labs: Dictionary = {}  # name -> Label "72"
var _stat_eta_labs: Dictionary = {}  # name -> Label "hungry in 3h"
var _stat_title: Label
var _stat_forecast: Label
var _stat_suggest: Label
var _prev_stats: Dictionary = {}  # for flash on change
var _flash_t: Dictionary = {}  # name -> remaining flash sec

# Session check-in banner (top-center, dismissible)
var _session_panel: PanelContainer
var _session_title: Label
var _session_body: Label
var _session_ttl: float = 0.0

# Pokemon-style vertical care menu (bottom-left)
var _care_panel: PanelContainer
var _care_list: VBoxContainer
var _care_labels: Array = []  # Label nodes
var _care_row_panels: Array = []  # PanelContainer per row (selection highlight)
var _care_actions: Array = ["feed", "walk", "play", "clean", "sleep", "wake", "cancel"]
var _care_cursor: int = 0
var _near_pet: bool = false
var _care_menu_open: bool = false
var _hud_layer: CanvasLayer

# Care action timer (center-top countdown)
var _care_timer_panel: PanelContainer
var _care_timer_label: Label
var _care_timer_bar: ProgressBar

# Sleep Zzz indicator (world-space label over pet)
var _zzz: Label
var _zzz_t: float = 0.0

# State-reactive room props
var _bowl_food: ColorRect
var _mess_nodes: Array = []
var _lamp_glow: ColorRect
var _window_night: Array = []
var _room_note: Label

# Mood / care emote bubble (bob + fade; temporary — not permanent like Zzz)
var _emote: Label
var _emote_ttl: float = 0.0
var _emote_passive_cd: float = 0.0
const EMOTE_DURATION := 2.6
const EMOTE_PASSIVE_CD := 7.5

# Care juice sparks (lightweight ColorRect bursts on successful care)
var _juice_sparks: Array = []  # {node, vel, life, max_life}


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
	call_deferred("_try_show_session_banner")


func _apply_spawn() -> void:
	if _human == null:
		return
	var spawn := SceneRouter.take_spawn("default")
	match spawn:
		"from_town":
			_human.position = Vector2(48, 236)
		"from_backyard", "from_yard", "from_graveyard":
			# Land at south backyard door mat (clear of walls)
			_human.position = Vector2(240, 275)
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
	# Food in bowl (toggled by hunger — empty when hungry)
	_bowl_food = _add_decor_rect(Rect2(252, 184, 14, 6), Color("F0C060"), -78)

	# Center rug
	_add_prop_sprite(SpriteFactoryScr.prop_texture("rug"), Vector2(208, 232), 2.0, -92)

	# Furniture pass: shelf, plant, nightstand, lamp
	_add_decor_rect(Rect2(430, 120, 28, 70), Color("6D4C41"), -88)  # bookcase
	_add_decor_rect(Rect2(434, 128, 20, 8), Color("E8DCC8"), -87)
	_add_decor_rect(Rect2(434, 142, 20, 8), Color("C8B8A0"), -87)
	_add_decor_rect(Rect2(434, 156, 20, 8), Color("E8DCC8"), -87)
	_add_decor_rect(Rect2(150, 120, 18, 22), Color("2E7D32"), -86)  # plant pot leaves
	_add_decor_rect(Rect2(154, 140, 10, 12), Color("8D6E63"), -85)
	_add_decor_rect(Rect2(100, 100, 22, 18), Color("5D4037"), -88)  # nightstand
	# Lamp (glow turns on at night)
	_add_decor_rect(Rect2(106, 88, 10, 14), Color("FFF8E1"), -84)
	_lamp_glow = _add_decor_rect(Rect2(98, 78, 26, 22), Color(1.0, 0.9, 0.5, 0.0), -83)
	# Window night shutter overlay (fades in at night)
	_window_night.clear()
	_window_night.append(_add_decor_rect(Rect2(120, 32, 36, 22), Color(0.05, 0.08, 0.2, 0.0), -86))
	_window_night.append(_add_decor_rect(Rect2(280, 32, 36, 22), Color(0.05, 0.08, 0.2, 0.0), -86))

	# Mess piles when hygiene low (hidden when clean)
	_mess_nodes.clear()
	_mess_nodes.append(_add_decor_rect(Rect2(180, 250, 22, 12), Color(0.45, 0.35, 0.25, 0.0), -76))
	_mess_nodes.append(_add_decor_rect(Rect2(340, 230, 18, 10), Color(0.4, 0.32, 0.22, 0.0), -76))
	_mess_nodes.append(_add_decor_rect(Rect2(200, 170, 14, 8), Color(0.5, 0.38, 0.28, 0.0), -76))

	_room_note = Label.new()
	_room_note.position = Vector2(160, 140)
	_room_note.add_theme_font_size_override("font_size", 11)
	_room_note.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25))
	_room_note.z_index = -50
	_room_note.text = ""
	_world.add_child(_room_note)

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


func _update_room_state() -> void:
	## Bowl, mess, lamp, window respond to pet needs + day phase.
	var p = PetController.active_pet
	var phase := str(TimeService.local_day_phase())
	var nightish := phase == "night" or phase == "dusk"
	if _lamp_glow:
		_lamp_glow.color = Color(1.0, 0.92, 0.55, 0.45 if nightish else 0.0)
	for w in _window_night:
		if w is ColorRect:
			(w as ColorRect).color = Color(0.05, 0.08, 0.22, 0.55 if phase == "night" else (0.25 if phase == "dusk" else 0.0))
	if p == null or str(p.life_state) == "DEAD":
		if _bowl_food:
			_bowl_food.color = Color("C0A070")
		for m in _mess_nodes:
			if m is ColorRect:
				(m as ColorRect).color.a = 0.0
		if _room_note:
			_room_note.text = ""
		return
	# Bowl full when well-fed
	if _bowl_food:
		if p.hunger >= 55.0:
			_bowl_food.color = Color("F5C84A")  # full kibble
			_bowl_food.visible = true
		elif p.hunger >= 30.0:
			_bowl_food.color = Color("D4A84A")
			_bowl_food.visible = true
		else:
			_bowl_food.color = Color(0.55, 0.45, 0.35, 0.9)  # empty bowl scrapings
	# Mess when dirty
	var mess_a := 0.0
	if p.hygiene < 25.0:
		mess_a = 0.85
	elif p.hygiene < 45.0:
		mess_a = 0.45
	for m in _mess_nodes:
		if m is ColorRect:
			var c: Color = (m as ColorRect).color
			c.a = mess_a
			(m as ColorRect).color = c
	if _room_note:
		if p.is_sleeping():
			_room_note.text = "Quiet house… Zzz"
		elif p.hunger < 30.0:
			_room_note.text = "Bowl looks empty…"
		elif p.hygiene < 30.0:
			_room_note.text = "Getting messy in here…"
		elif p.energy < 30.0:
			_room_note.text = "Someone needs a nap…"
		else:
			_room_note.text = ""


func _build_actors() -> void:
	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.is_pet = false
	_human.move_speed = 100.0
	_human.position = Vector2(120, 220)
	_world.add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)  # same scale as town AI
	_human.setup_collision(false)
	# Include south backyard door strip (y ~290–300)
	_human.set_world_bounds(Rect2(22, 40, 436, 265))

	_pet = AnimatedActorScr.new()
	_pet.is_player_controlled = false
	_pet.is_pet = true
	_pet.move_speed = 95.0
	_pet.position = Vector2(300, 175)
	_world.add_child(_pet)
	_reload_pet_sprites()
	_pet.setup_collision(true)
	_pet.set_world_bounds(Rect2(22, 40, 436, 265))

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
	if p.is_sleeping():
		return "sleeping"
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
	# AnimatedActor maps "sleeping" → sleep frames via set_condition
	if cond == "sleeping":
		_pet.set_condition("sleep")
	else:
		_pet.set_condition(cond)
	match cond:
		"dead":
			_pet.play_anim(&"dead")
		"sleeping":
			_pet.play_anim(&"sleep")
		"weak":
			_pet.play_anim(&"weak")
		"hungry":
			_pet.play_anim(&"hungry")
		_:
			if PetController.active_pet.happiness >= 75.0:
				_pet.play_anim(&"happy")
			else:
				_pet.play_anim(&"idle")
	_update_zzz()


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
	_director.choreography_finished.connect(func(a, r):
		_hide_care_timer()
		_refresh_all()
		_apply_pet_condition_visual()
		var ok := bool(r.get("ok", false)) or bool(r.get("applied", false))
		var audio := get_node_or_null("/root/AudioService")
		if audio and audio.has_method("play_care"):
			audio.play_care(a, ok)
		if ok:
			_spawn_care_juice(String(a))
			_show_care_success_emote(String(a))
		else:
			_show_emote("…", Color(0.65, 0.62, 0.7))
	)
	# Resume outdoor leash after town/park visit
	if PetController.escort_active and _pet and str(PetController.active_pet.life_state if PetController.active_pet else "") != "DEAD":
		_pet.visible = true
		_director.resume_escort_visuals()
		_show_toast("Still on leash — E near pet when ready to end walk")


func _style_panel_light() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.90)
	sb.border_color = Color(0.12, 0.10, 0.08)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb


func _style_row(selected: bool, disabled: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(0.85, 0.18, 0.14)
		sb.border_color = Color(0.45, 0.05, 0.05)
	elif disabled:
		sb.bg_color = Color(0.88, 0.86, 0.82)
		sb.border_color = Color(0.75, 0.72, 0.68)
	else:
		sb.bg_color = Color(0.96, 0.94, 0.88)
		sb.border_color = Color(0.75, 0.72, 0.65)
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	_hud_layer = layer
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
	_toast.add_theme_font_size_override("font_size", 13)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45))
	layer.add_child(_toast)

	# --- Top-right: needs bars + numbers + ETAs (never over the pet) ---
	_stats_panel = PanelContainer.new()
	_stats_panel.visible = false
	_stats_panel.add_theme_stylebox_override("panel", _style_panel_light())
	_stats_panel.position = Vector2(1000, 8)
	layer.add_child(_stats_panel)
	var stats_v := VBoxContainer.new()
	stats_v.add_theme_constant_override("separation", 6)
	_stats_panel.add_child(stats_v)
	_stat_title = Label.new()
	_stat_title.text = "Pet"
	_stat_title.add_theme_font_size_override("font_size", 14)
	_stat_title.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08))
	stats_v.add_child(_stat_title)
	_stat_forecast = Label.new()
	_stat_forecast.text = ""
	_stat_forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stat_forecast.custom_minimum_size = Vector2(220, 0)
	_stat_forecast.add_theme_font_size_override("font_size", 11)
	_stat_forecast.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18))
	stats_v.add_child(_stat_forecast)
	_stat_suggest = Label.new()
	_stat_suggest.text = "Suggested: —"
	_stat_suggest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stat_suggest.custom_minimum_size = Vector2(220, 0)
	_stat_suggest.add_theme_font_size_override("font_size", 12)
	_stat_suggest.add_theme_color_override("font_color", Color(0.55, 0.15, 0.12))
	stats_v.add_child(_stat_suggest)
	_stat_bars.clear()
	_stat_value_labs.clear()
	_stat_eta_labs.clear()
	var eta_hints := {
		"hunger": "hungry",
		"energy": "sleepy",
		"happiness": "lonely",
		"hygiene": "dirty",
	}
	for stat in ["hunger", "energy", "happiness", "hygiene"]:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 1)
		stats_v.add_child(block)
		var row := HBoxContainer.new()
		block.add_child(row)
		var lab := Label.new()
		lab.text = stat.substr(0, 3).to_upper()
		lab.custom_minimum_size = Vector2(36, 0)
		lab.add_theme_font_size_override("font_size", 12)
		lab.add_theme_color_override("font_color", Color(0.15, 0.12, 0.10))
		row.add_child(lab)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(110, 16)
		bar.max_value = 100.0
		bar.show_percentage = false
		row.add_child(bar)
		_stat_bars[stat] = bar
		var val := Label.new()
		val.text = "80"
		val.custom_minimum_size = Vector2(36, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_size_override("font_size", 13)
		val.add_theme_color_override("font_color", Color(0.10, 0.10, 0.12))
		row.add_child(val)
		_stat_value_labs[stat] = val
		var eta := Label.new()
		eta.text = "  %s in —" % eta_hints[stat]
		eta.add_theme_font_size_override("font_size", 10)
		eta.add_theme_color_override("font_color", Color(0.35, 0.32, 0.28))
		block.add_child(eta)
		_stat_eta_labs[stat] = eta

	call_deferred("_place_stats_panel")

	# --- High-contrast CARE menu (bottom-left) ---
	_care_panel = PanelContainer.new()
	_care_panel.visible = false
	_care_panel.add_theme_stylebox_override("panel", _style_panel_light())
	_care_panel.position = Vector2(16, 400)
	layer.add_child(_care_panel)
	var care_outer := VBoxContainer.new()
	care_outer.add_theme_constant_override("separation", 4)
	_care_panel.add_child(care_outer)
	var care_title := Label.new()
	care_title.text = "CARE"
	care_title.add_theme_font_size_override("font_size", 18)
	care_title.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
	care_outer.add_child(care_title)
	var help := Label.new()
	help.text = "↑↓ move · Z/Enter · X cancel"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18))
	care_outer.add_child(help)
	_care_list = VBoxContainer.new()
	_care_list.add_theme_constant_override("separation", 3)
	care_outer.add_child(_care_list)
	_care_labels.clear()
	_care_row_panels.clear()
	var names := ["FEED", "WALK", "PLAY", "CLEAN", "SLEEP", "WAKE", "CANCEL"]
	for i in names.size():
		var row_p := PanelContainer.new()
		row_p.custom_minimum_size = Vector2(168, 28)
		var lab2 := Label.new()
		lab2.add_theme_font_size_override("font_size", 16)
		lab2.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10))
		lab2.text = "  " + names[i]
		lab2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_p.add_child(lab2)
		_care_list.add_child(row_p)
		_care_labels.append(lab2)
		_care_row_panels.append(row_p)
	_refresh_care_cursor()
	call_deferred("_place_care_menu")

	# World-space Zzz (follows pet when sleeping)
	_zzz = Label.new()
	_zzz.text = "Zzz"
	_zzz.visible = false
	_zzz.add_theme_font_size_override("font_size", 18)
	_zzz.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	_zzz.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.15))
	_zzz.add_theme_constant_override("outline_size", 4)
	_zzz.z_index = 200
	_world.add_child(_zzz)

	# Temporary mood / care emote (heart, hungry, sad…)
	_emote = Label.new()
	_emote.text = ""
	_emote.visible = false
	_emote.add_theme_font_size_override("font_size", 16)
	_emote.add_theme_color_override("font_color", Color(1.0, 0.45, 0.55))
	_emote.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.08))
	_emote.add_theme_constant_override("outline_size", 4)
	_emote.z_index = 210
	_emote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world.add_child(_emote)

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
	_care_timer_panel.add_theme_stylebox_override("panel", _style_panel_light())
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

	# Session check-in banner (shown once after boot/resume with gap)
	_session_panel = PanelContainer.new()
	_session_panel.visible = false
	_session_panel.add_theme_stylebox_override("panel", _style_panel_light())
	layer.add_child(_session_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	_session_panel.add_child(sv)
	_session_title = Label.new()
	_session_title.add_theme_font_size_override("font_size", 16)
	_session_title.add_theme_color_override("font_color", Color(0.1, 0.08, 0.06))
	sv.add_child(_session_title)
	_session_body = Label.new()
	_session_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_session_body.custom_minimum_size = Vector2(320, 0)
	_session_body.add_theme_font_size_override("font_size", 12)
	_session_body.add_theme_color_override("font_color", Color(0.2, 0.18, 0.14))
	sv.add_child(_session_body)
	var dismiss := Button.new()
	dismiss.text = "Got it (Esc)"
	dismiss.pressed.connect(_hide_session_banner)
	sv.add_child(dismiss)


func _try_show_session_banner() -> void:
	var snap: Dictionary = PetController.consume_session_banner()
	if snap.is_empty():
		return
	if _session_panel == null:
		return
	_session_title.text = str(snap.get("title", "Check-in"))
	_session_body.text = str(snap.get("body", ""))
	_session_panel.visible = true
	_session_ttl = 14.0
	_place_session_banner()
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_menu"):
		audio.play_menu()


func _hide_session_banner() -> void:
	if _session_panel:
		_session_panel.visible = false
	_session_ttl = 0.0


func _place_session_banner() -> void:
	if _session_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_session_panel.position = Vector2(vp.x * 0.5 - 170.0, 48.0)


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
	# Top-right of viewport (wider for numbers + ETAs)
	if _stats_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_stats_panel.position = Vector2(vp.x - 260, 8)


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


func _action_enabled(action: String) -> bool:
	if action == "cancel":
		return true
	var p = PetController.active_pet
	if p == null:
		return false
	var now: float = TimeService.now_unix_utc()
	return CareAdvisorScr.action_blocked_reason(action, p, now) == &""


func _move_care_cursor(dir: int) -> void:
	## Skip greyed-out actions so the highlight always lands on something usable.
	var n := _care_actions.size()
	if n == 0:
		return
	for _i in n:
		_care_cursor = (_care_cursor + dir + n) % n
		if _action_enabled(str(_care_actions[_care_cursor])):
			break
	_refresh_care_cursor()
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play"):
		audio.play("ui_click", 1.0, -12.0)


func _refresh_care_cursor() -> void:
	var names := ["FEED", "WALK", "PLAY", "CLEAN", "SLEEP", "WAKE", "CANCEL"]
	var now: float = TimeService.now_unix_utc()
	var pet = PetController.active_pet
	for i in _care_labels.size():
		var lab: Label = _care_labels[i]
		var action: String = str(_care_actions[i])
		var enabled := _action_enabled(action)
		var selected := i == _care_cursor
		var suffix := ""
		if action != "cancel" and pet != null:
			var cd: float = CareAdvisorScr.cooldown_for(action, pet, now)
			var block: StringName = CareAdvisorScr.action_blocked_reason(action, pet, now)
			if block == &"COOLDOWN" and cd > 0.0:
				suffix = " · %s" % CareAdvisorScr.format_cd(cd)
			elif block == &"PET_SLEEPING":
				suffix = " · sleep"
			elif block == &"ENERGY_TOO_LOW":
				suffix = " · tired"
			elif block == &"NOT_SLEEPING":
				suffix = " · awake"
			elif block == &"ALREADY_SLEEPING":
				suffix = " · zzz"
			elif enabled and action in ["feed", "walk", "play", "clean"]:
				suffix = " · ready"
		var base: String = str(names[i]) + suffix
		if selected:
			lab.text = "▶ " + base
			lab.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95))
			lab.add_theme_font_size_override("font_size", 16)
		elif not enabled:
			lab.text = "  " + base
			lab.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
			lab.add_theme_font_size_override("font_size", 14)
		else:
			lab.text = "  " + base
			lab.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10))
			lab.add_theme_font_size_override("font_size", 15)
		if i < _care_row_panels.size():
			var row: PanelContainer = _care_row_panels[i]
			row.add_theme_stylebox_override("panel", _style_row(selected, not enabled))


func _place_care_menu() -> void:
	if _care_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	# Bottom-left, always on screen
	_care_panel.position = Vector2(16.0, maxf(80.0, vp.y - 320.0))


func _update_zzz() -> void:
	if _zzz == null or _pet == null:
		return
	var sleeping: bool = (
		PetController.active_pet != null
		and PetController.active_pet.is_sleeping()
		and str(PetController.active_pet.life_state) != "DEAD"
	)
	_zzz.visible = sleeping and _pet.visible
	if not sleeping:
		return
	# Bobbing Zzz above pet head
	var bob := sin(_zzz_t * 3.0) * 3.0
	_zzz.global_position = _pet.global_position + Vector2(-10, -42 + bob)
	# Cycle Z / Zz / Zzz for a cheap animation read
	var phase := int(_zzz_t * 2.0) % 3
	_zzz.text = ["Z", "Zz", "Zzz"][phase]


func _show_emote(text: String, color: Color = Color(1.0, 0.45, 0.55)) -> void:
	if _emote == null:
		return
	_emote.text = text
	_emote.add_theme_color_override("font_color", color)
	_emote.modulate = Color(1, 1, 1, 1)
	_emote.visible = true
	_emote_ttl = EMOTE_DURATION
	_emote_passive_cd = EMOTE_PASSIVE_CD


func _show_care_success_emote(action: String) -> void:
	match action:
		"feed":
			_show_emote("♥", Color(1.0, 0.35, 0.48))
		"play":
			_show_emote("★", Color(1.0, 0.85, 0.25))
		"clean":
			_show_emote("✦", Color(0.55, 0.85, 1.0))
		"walk":
			_show_emote("♪", Color(0.55, 0.9, 0.55))
		"sleep":
			# Zzz label already handles sleeping; brief tuck-in heart
			_show_emote("Zzz♥", Color(0.65, 0.8, 1.0))
		"wake":
			_show_emote("!", Color(1.0, 0.92, 0.4))
		_:
			_show_emote("♥", Color(1.0, 0.5, 0.6))


func _update_emote(delta: float) -> void:
	if _emote == null:
		return
	if _emote_ttl > 0.0:
		_emote_ttl -= delta
		var t := 1.0 - clampf(_emote_ttl / EMOTE_DURATION, 0.0, 1.0)
		# Rise slightly, bob, fade in last third
		var rise := -t * 14.0
		var bob := sin(_zzz_t * 5.0) * 2.5
		var alpha := 1.0
		if _emote_ttl < 0.9:
			alpha = clampf(_emote_ttl / 0.9, 0.0, 1.0)
		_emote.modulate.a = alpha
		if _pet and _pet.visible:
			_emote.global_position = _pet.global_position + Vector2(-12, -52.0 + rise + bob)
		if _emote_ttl <= 0.0:
			_emote.visible = false
			_emote.text = ""
	elif _emote.visible:
		_emote.visible = false

	# Passive needy mood emotes when no care emote is showing
	if _emote_passive_cd > 0.0:
		_emote_passive_cd -= delta
	_try_passive_mood_emote()


func _try_passive_mood_emote() -> void:
	if _emote_ttl > 0.0 or _emote_passive_cd > 0.0:
		return
	if _pet == null or not _pet.visible or PetController.active_pet == null:
		return
	var p = PetController.active_pet
	if str(p.life_state) == "DEAD":
		return
	if p.is_sleeping():
		return  # Zzz owns sleep presentation
	if _director and _director.is_busy():
		return
	# Needy reads first
	if p.hunger < 28.0:
		_show_emote("hungry…", Color(1.0, 0.72, 0.35))
		return
	if p.happiness < 28.0 or p.life_state == LifeState.CRITICAL or p.life_state == LifeState.DYING:
		_show_emote("sad…", Color(0.7, 0.72, 0.9))
		return
	if p.hygiene < 22.0:
		_show_emote("ew…", Color(0.75, 0.85, 0.55))
		return
	if p.energy < 22.0:
		_show_emote("tired…", Color(0.75, 0.8, 1.0))
		return


func _spawn_care_juice(action: String) -> void:
	## Lightweight sparkles around the pet on successful care (no GPUParticles dependency).
	if _pet == null or _world == null:
		return
	var origin: Vector2 = _pet.global_position + Vector2(0, -18)
	var base_col := Color(1.0, 0.9, 0.45, 0.95)
	match action:
		"feed":
			base_col = Color(1.0, 0.55, 0.35, 0.95)
		"play":
			base_col = Color(1.0, 0.85, 0.3, 0.95)
		"clean":
			base_col = Color(0.55, 0.85, 1.0, 0.95)
		"walk":
			base_col = Color(0.55, 0.95, 0.55, 0.95)
		"sleep":
			base_col = Color(0.7, 0.8, 1.0, 0.9)
		"wake":
			base_col = Color(1.0, 0.95, 0.55, 0.95)
	var n := 10
	for i in n:
		var spark := ColorRect.new()
		var sz := 3.0 + float(i % 3)
		spark.size = Vector2(sz, sz)
		spark.color = base_col
		spark.z_index = 190
		# Alternate a few "heart-ish" larger pixels for feed
		if action == "feed" and i % 3 == 0:
			spark.size = Vector2(4, 4)
			spark.color = Color(1.0, 0.35, 0.5, 0.95)
		_world.add_child(spark)
		spark.global_position = origin + Vector2(randf_range(-6, 6), randf_range(-4, 4))
		var ang := randf() * TAU
		var speed := randf_range(28.0, 72.0)
		var life := randf_range(0.45, 0.85)
		_juice_sparks.append({
			"node": spark,
			"vel": Vector2(cos(ang), sin(ang) - 0.55) * speed,
			"life": life,
			"max_life": life,
		})


func _update_care_juice(delta: float) -> void:
	if _juice_sparks.is_empty():
		return
	var i := 0
	while i < _juice_sparks.size():
		var s: Dictionary = _juice_sparks[i]
		var node: ColorRect = s.get("node") as ColorRect
		var life: float = float(s.get("life", 0.0)) - delta
		if node == null or not is_instance_valid(node) or life <= 0.0:
			if node and is_instance_valid(node):
				node.queue_free()
			_juice_sparks.remove_at(i)
			continue
		var vel: Vector2 = s.get("vel", Vector2.ZERO) as Vector2
		# Gravity + drag
		vel.y += 55.0 * delta
		vel *= 1.0 - 0.35 * delta
		s["vel"] = vel
		s["life"] = life
		node.global_position += vel * delta
		var max_life: float = maxf(0.001, float(s.get("max_life", 0.6)))
		var a := clampf(life / max_life, 0.0, 1.0)
		var c := node.color
		c.a = a * 0.95
		node.color = c
		_juice_sparks[i] = s
		i += 1


func _at_door(rect: Rect2) -> bool:
	if _human == null:
		return false
	return rect.has_point(_human.position)


func _process(delta: float) -> void:
	_zzz_t += delta
	_tick_stat_flashes(delta)
	if _session_ttl > 0.0:
		_session_ttl -= delta
		_place_session_banner()
		if _session_ttl <= 0.0:
			_hide_session_banner()
	_update_near_pet_ui()
	_update_zzz()
	_update_emote(delta)
	_update_care_juice(delta)
	_place_stats_panel()
	if _care_menu_open:
		_place_care_menu()
		# Live-refresh cooldowns while menu open
		if int(_zzz_t * 2.0) % 2 == 0:
			_refresh_care_cursor()
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
		# End outdoor leash walk near pet
		if PetController.escort_active and _near_pet and _director:
			_director.try_finish_escort()
			return
		if _at_door(DOOR_TOWN):
			SceneRouter.go("town", "from_house")
			return
		if _at_door(DOOR_YARD):
			if PetController.escort_active:
				_show_toast("Finish the walk first (E near pet) — or take them to Town")
				return
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
	if PetController.escort_active:
		_show_toast("On a walk — E near pet to end leash (or keep exploring town/park)")
		return
	var life := str(PetController.active_pet.life_state)
	if life == "DEAD":
		_show_toast("Take them out the back door to the backyard")
		return
	_care_menu_open = true
	# Cursor on suggested action (or WAKE while sleeping)
	var now_m: float = TimeService.now_unix_utc()
	var sug_m: Dictionary = CareAdvisorScr.suggest(PetController.active_pet, now_m)
	var sug_a := str(sug_m.get("action", ""))
	if sug_a != "" and _care_actions.has(sug_a):
		_care_cursor = _care_actions.find(sug_a)
	elif PetController.active_pet.is_sleeping():
		_care_cursor = maxi(0, _care_actions.find("wake"))
	else:
		_care_cursor = 0
	if PetController.active_pet.is_sleeping():
		_show_toast("They're sleeping (Zzz) — choose WAKE, or X to close")
	else:
		_show_toast("%s · ↑↓ · Z/Enter · X" % str(sug_m.get("label", "CARE")))
	_refresh_care_cursor()
	_place_care_menu()
	_care_panel.visible = true
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_menu"):
		audio.play_menu()
	if _human:
		_human.set_busy(true)
		_human.play_idle()


func _confirm_care_selection() -> void:
	if not _care_menu_open:
		return
	var action: String = str(_care_actions[_care_cursor])
	if action == "cancel":
		_close_care_menu()
		if _human and (_director == null or not _director.is_busy()):
			_human.set_busy(false)
		return
	if not _action_enabled(action):
		if PetController.active_pet and PetController.active_pet.is_sleeping():
			_show_toast("Zzz… wake them first — pick WAKE")
		elif action == "wake":
			_show_toast("They're already awake")
		else:
			_show_toast("Can't do that right now")
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
		_refresh_need_meters(PetController.active_pet)

	# Don't overwrite door hints while standing on a door
	if _at_door(DOOR_TOWN) or _at_door(DOOR_YARD):
		return
	if _near_pet and life != "DEAD" and life != "":
		if PetController.active_pet.is_sleeping():
			_hint.text = "%s is sleeping (Zzz) — E CARE · WAKE to feed/play" % str(PetController.active_pet.name)
		else:
			_hint.text = "Near %s — E open CARE · ↑↓ · Z/Enter" % str(PetController.active_pet.name)
	elif PetController.active_pet == null:
		_hint.text = "Adopt a pet · WASD · left door=Town · south door=Backyard"
	elif life == "DEAD":
		_hint.text = "Pet passed — south door to backyard · hold E at plot to dig"
	else:
		_hint.text = "Near pet for CARE · left door Town · south door Backyard"


func _refresh_need_meters(p) -> void:
	_update_room_state()
	var cond := _condition_from_pet(p)
	if cond == "sleeping":
		_stat_title.text = "%s  [Zzz sleeping]" % p.name
	else:
		_stat_title.text = "%s  [%s]" % [p.name, cond]

	var values := {
		"hunger": float(p.hunger),
		"energy": float(p.energy),
		"happiness": float(p.happiness),
		"hygiene": float(p.hygiene),
	}
	for k in values:
		var v: float = values[k]
		var prev: float = float(_prev_stats.get(k, v))
		if absf(v - prev) > 0.4:
			# Flash bar when care (or decay) changes a need
			_flash_t[k] = 0.85
		_prev_stats[k] = v
		if _stat_bars.has(k):
			_stat_bars[k].value = v
			var flash_left: float = float(_flash_t.get(k, 0.0))
			if flash_left > 0.0 and v > prev:
				_stat_bars[k].modulate = Color(0.45, 1.0, 0.55)  # green pop up
			elif flash_left > 0.0 and v < prev:
				_stat_bars[k].modulate = Color(1.0, 0.75, 0.4)
			else:
				_stat_bars[k].modulate = _bar_color(v)
		if _stat_value_labs.has(k):
			(_stat_value_labs[k] as Label).text = "%d" % int(round(v))

	# ETAs from species decay rates + suggested care
	var fc: Dictionary = NeedsForecastScr.forecast(p)
	if _stat_forecast:
		_stat_forecast.text = str(fc.get("summary", ""))
	if _stat_suggest:
		var sug: Dictionary = CareAdvisorScr.suggest(p, TimeService.now_unix_utc())
		var lab := str(sug.get("label", ""))
		var det := str(sug.get("detail", ""))
		_stat_suggest.text = lab if det == "" else "%s  (%s)" % [lab, det]
		# Urgent red-ish when dying/critical wording
		if lab.begins_with("Urgent"):
			_stat_suggest.add_theme_color_override("font_color", Color(0.75, 0.1, 0.08))
		else:
			_stat_suggest.add_theme_color_override("font_color", Color(0.55, 0.15, 0.12))
	if _stat_eta_labs.has("hunger"):
		var hn: float = float(fc.get("hunger_to_needy_sec", -1.0))
		(_stat_eta_labs["hunger"] as Label).text = "  hungry in %s" % NeedsForecastScr.format_eta(hn)
		(_stat_eta_labs["hunger"] as Label).modulate = (
			Color(1, 0.4, 0.35) if hn >= 0.0 and hn < 3600.0 else Color.WHITE
		)
	if _stat_eta_labs.has("energy"):
		if bool(fc.get("sleeping", false)):
			var full_in: float = float(fc.get("energy_full_in_sec", -1.0))
			(_stat_eta_labs["energy"] as Label).text = "  full energy in %s" % NeedsForecastScr.format_eta(full_in)
		else:
			var es: float = float(fc.get("energy_to_sleepy_sec", -1.0))
			(_stat_eta_labs["energy"] as Label).text = "  sleepy in %s" % NeedsForecastScr.format_eta(es)
			(_stat_eta_labs["energy"] as Label).modulate = (
				Color(1, 0.55, 0.3) if es >= 0.0 and es < 3600.0 else Color.WHITE
			)
	if _stat_eta_labs.has("happiness"):
		var hp: float = float(fc.get("happiness_to_needy_sec", -1.0))
		(_stat_eta_labs["happiness"] as Label).text = "  lonely in %s" % NeedsForecastScr.format_eta(hp)
	if _stat_eta_labs.has("hygiene"):
		var hy: float = float(fc.get("hygiene_to_needy_sec", -1.0))
		(_stat_eta_labs["hygiene"] as Label).text = "  dirty in %s" % NeedsForecastScr.format_eta(hy)


func _tick_stat_flashes(delta: float) -> void:
	for k in _flash_t.keys():
		_flash_t[k] = maxf(0.0, float(_flash_t[k]) - delta)


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
			_move_care_cursor(-1)
			return
		if k.keycode == KEY_DOWN or k.keycode == KEY_S:
			_move_care_cursor(1)
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

	if _session_panel and _session_panel.visible and (k.keycode == KEY_ESCAPE or k.keycode == KEY_X):
		_hide_session_banner()
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
		_show_toast("Still busy — wait a second")
		return
	# Pre-check so we never run a full walk then fail with PET_SLEEPING
	if not _action_enabled(String(action)):
		if PetController.active_pet and PetController.active_pet.is_sleeping():
			_show_toast("Zzz… wake them first — pick WAKE")
		else:
			_show_toast("Can't do that right now")
		return
	# Release menu freeze so care walk can run
	_care_menu_open = false
	if _care_panel:
		_care_panel.visible = false
	if _human:
		_human.set_busy(false)
	var r: Dictionary = _director.try_start_care(action)
	if not r.get("ok", false):
		var msg := str(r.get("message", ""))
		if msg == "":
			msg = str(r.get("reason", "Couldn't do that"))
		_show_toast(msg)
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
	_counter.text = "Deaths %d · Graves %d · ❤%d" % [
		int(snap.get("total_pets_died", 0)),
		int(snap.get("total_graves_dug", 0)),
		int(snap.get("care_points", PetController.profile.care_points if PetController.profile else 0)),
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
	_update_room_state()


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
