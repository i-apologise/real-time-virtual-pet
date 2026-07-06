extends Node2D
## Backyard attached to the house. Clear path + large house-door zone back inside.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const UiThemeScr = preload("res://src/ui/ui_theme.gd")
const UxCopyScr = preload("res://src/sim/ux_copy.gd")

const LAYER_WORLD := 1
const DIG_HOLD_SEC := 2.5
const PLOT_RADIUS := 44.0
const WORLD_BOUNDS := Rect2(28, 28, 584, 344)
## Large, walkable house return zone (north — matches home south door feel)
const HOUSE_DOOR_POS := Vector2(240, 70)
const HOUSE_DOOR_RADIUS := 52.0

var _human: CharacterBody2D
var _dead_pet: CharacterBody2D
var _camera: Camera2D
var _world: Node2D
var _label: Label
var _toast: Label
var _dig_bar: ProgressBar
var _dig_panel: PanelContainer
var _plot_pos: Vector2 = Vector2(360, 240)
var _near_plot: bool = false
var _near_house: bool = false
var _digging: bool = false
var _dig_accum: float = 0.0
var _buried_this_visit: bool = false


func _ready() -> void:
	y_sort_enabled = true
	_build()
	_apply_spawn()
	_refresh_state()


func _apply_spawn() -> void:
	if _human == null:
		return
	var spawn := SceneRouter.take_spawn("default")
	# Enter from house south door → appear just inside backyard at house connection
	match spawn:
		"from_house":
			_human.position = Vector2(240, 100)
		_:
			_human.position = Vector2(240, 100)
	_human.set_world_bounds(WORLD_BOUNDS)


func _go_house() -> void:
	if _digging:
		return
	if Engine.has_singleton("AudioService") or true:
		# AudioService is an autoload node, not Engine singleton
		pass
	if has_node("/root/AudioService"):
		get_node("/root/AudioService").play_door()
	SceneRouter.go("habitat", "from_backyard")


func _tile(area: Rect2, kind: String) -> void:
	var tex: Texture2D = SpriteFactoryScr.make_tile(kind)
	var y := int(area.position.y)
	while y < int(area.end.y):
		var x := int(area.position.x)
		while x < int(area.end.x):
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = Vector2(x + 8, y + 8)
			spr.z_index = -100
			_world.add_child(spr)
			x += 16
		y += 16


func _solid(rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.z_index = int(body.position.y)
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	vis.color = color
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(vis)
	_world.add_child(body)


func _decor(rect: Rect2, color: Color, z: int = -80) -> void:
	var r := ColorRect.new()
	r.color = color
	r.size = rect.size
	r.position = rect.position
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(r)


func _build() -> void:
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_tile(Rect2(0, 0, 640, 400), "grass")
	# Clear path from HOUSE DOOR (north) down to plot
	_tile(Rect2(210, 60, 60, 200), "path")
	_tile(Rect2(210, 220, 200, 48), "path")

	# Fence borders — gap at north for house door (no solid in doorway)
	_solid(Rect2(0, 0, 180, 18), Color("6B4E2E"))
	_solid(Rect2(300, 0, 340, 18), Color("6B4E2E"))  # gap 180–300 for house door
	_solid(Rect2(0, 382, 640, 18), Color("6B4E2E"))
	_solid(Rect2(0, 0, 18, 400), Color("6B4E2E"))
	_solid(Rect2(622, 0, 18, 400), Color("6B4E2E"))

	# House facade above the yard (visual only — NOT blocking the door walk zone)
	_decor(Rect2(160, 8, 160, 36), Color("C48C5C"), -60)
	_decor(Rect2(170, 14, 40, 24), Color("8EC8E8"), -59)  # window
	_decor(Rect2(270, 14, 40, 24), Color("8EC8E8"), -59)
	# Door opening (walkable) — mat + frame, no collision
	_decor(Rect2(210, 40, 60, 50), Color("5A3A22"), -55)
	_decor(Rect2(218, 48, 44, 40), Color("8B5A2B"), -54)
	_decor(Rect2(248, 64, 6, 10), Color("D4AF37"), -53)  # knob
	var house_lab := Label.new()
	house_lab.text = "HOUSE DOOR ↑  (E)"
	house_lab.position = Vector2(200, 92)
	house_lab.add_theme_font_size_override("font_size", 12)
	house_lab.add_theme_color_override("font_color", Color.WHITE)
	house_lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	house_lab.add_theme_constant_override("outline_size", 3)
	_world.add_child(house_lab)

	_draw_existing_graves()

	# Dig plot
	var plot := ColorRect.new()
	plot.size = Vector2(52, 36)
	plot.position = _plot_pos - Vector2(26, 18)
	plot.color = Color("4A3C28")
	plot.z_index = -50
	plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(plot)
	var plot_l := Label.new()
	plot_l.text = "EMPTY PLOT"
	plot_l.position = _plot_pos + Vector2(-32, 20)
	plot_l.add_theme_font_size_override("font_size", 11)
	plot_l.add_theme_color_override("font_color", Color.WHITE)
	_world.add_child(plot_l)

	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.move_speed = 105.0
	_human.position = Vector2(240, 100)
	_world.add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)
	_human.setup_collision(false)
	_human.set_world_bounds(WORLD_BOUNDS)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(2.2, 2.2)
	_camera.position_smoothing_enabled = true
	_human.add_child(_camera)
	_camera.make_current()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 640
	_camera.limit_bottom = 400

	_dead_pet = AnimatedActorScr.new()
	_dead_pet.is_pet = true
	_dead_pet.is_player_controlled = false
	_dead_pet.move_speed = 0.0
	_dead_pet.position = _human.position + Vector2(6, -14)
	_world.add_child(_dead_pet)

	var layer := CanvasLayer.new()
	add_child(layer)
	var top := PanelContainer.new()
	UiThemeScr.apply_panel(top, true)
	top.position = Vector2(10, 8)
	layer.add_child(top)
	_label = UiThemeScr.title_label("Backyard", 12)
	top.add_child(_label)
	_toast = UiThemeScr.toast_label("")
	_toast.position = Vector2(10, 48)
	layer.add_child(_toast)

	var back := UiThemeScr.themed_button("Enter house")
	back.position = Vector2(10, 72)
	back.pressed.connect(_go_house)
	layer.add_child(back)

	# P3: dig ritual uses shared modal chrome + themed progress bar
	_dig_panel = PanelContainer.new()
	_dig_panel.position = Vector2(200, 320)
	_dig_panel.visible = false
	UiThemeScr.apply_panel(_dig_panel, true)
	layer.add_child(_dig_panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	_dig_panel.add_child(dv)
	var dl := UiThemeScr.title_label("Hold E or Space to dig the grave", 13)
	dv.add_child(dl)
	var dh := UiThemeScr.body_label("Stay near the empty plot until the bar fills.", 11)
	dh.custom_minimum_size = Vector2(240, 0)
	dv.add_child(dh)
	_dig_bar = ProgressBar.new()
	_dig_bar.custom_minimum_size = Vector2(220, 18)
	_dig_bar.max_value = 100
	_dig_bar.show_percentage = false
	UiThemeScr.style_progress_bar(_dig_bar, UiThemeScr.BAR_FILL_MID)
	dv.add_child(_dig_bar)


func _draw_existing_graves() -> void:
	var graves: Array = PetController.profile.graves
	var i := 0
	for g in graves:
		if not (g is GraveRecord):
			continue
		var pos := Vector2(80 + (i % 8) * 64, 140 + int(i / 8) * 70)
		var stone := ColorRect.new()
		stone.size = Vector2(28, 36)
		stone.position = pos
		stone.color = Color("8A8A90")
		stone.z_index = int(pos.y)
		stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(stone)
		var top := ColorRect.new()
		top.size = Vector2(20, 10)
		top.position = pos + Vector2(4, -8)
		top.color = Color("9A9AA4")
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(top)
		var lab := Label.new()
		lab.text = g.name
		lab.position = pos + Vector2(-4, 36)
		lab.add_theme_font_size_override("font_size", 9)
		lab.add_theme_color_override("font_color", Color.WHITE)
		_world.add_child(lab)
		i += 1


func _refresh_state() -> void:
	var p = PetController.active_pet
	var needs_burial: bool = p != null and str(p.life_state) == "DEAD" and not p.buried
	if _dead_pet:
		_dead_pet.visible = needs_burial
		if needs_burial:
			var sid := String(p.species_id)
			# Same scale as home pet (2.0); carry mode shrinks further for in-hands pose
			_dead_pet.setup_frames(SpriteFactoryScr.pet_frames(sid), 2.0)
			_dead_pet.set_collision_enabled(false)
			if PetController.carrying_deceased and _human:
				_dead_pet.set_carried_in_hands(_human)
				_toast.text = "Carrying %s in your arms — walk to EMPTY PLOT · hold E to dig" % p.name
			else:
				if _dead_pet.has_method("clear_carried_in_hands"):
					_dead_pet.clear_carried_in_hands()
				elif _dead_pet.has_method("clear_follow"):
					_dead_pet.clear_follow()
				_dead_pet.position = Vector2(240, 120)
				_dead_pet.set_condition("dead")
				_dead_pet.play_anim(&"dead")
				_toast.text = "They aren't with you — go inside and E Carry them first"
	if needs_burial and PetController.carrying_deceased:
		_label.text = "Backyard — bring %s to EMPTY PLOT · hold E dig · north HOUSE DOOR" % p.name
	elif needs_burial:
		_label.text = "Backyard — body still inside · go home and carry them (E)"
	else:
		_label.text = "Backyard — walk north to HOUSE DOOR (E) or press Enter house"
		_dig_panel.visible = false


func _process(delta: float) -> void:
	if _human == null:
		return

	_near_house = _human.global_position.distance_to(HOUSE_DOOR_POS) <= HOUSE_DOOR_RADIUS
	_near_plot = _human.global_position.distance_to(_plot_pos) <= PLOT_RADIUS

	# Prefer house door when near it (don't start dig by accident on E tap)
	if _near_house and not _digging:
		_label.text = "House door — press E to go inside"
		if Input.is_action_just_pressed("interact"):
			_go_house()
			return

	var p = PetController.active_pet
	var needs_burial: bool = (
		p != null and str(p.life_state) == "DEAD" and not p.buried and not _buried_this_visit
	)

	# Dig only when you brought them (carrying) — the walk is the ritual
	var can_dig := needs_burial and PetController.carrying_deceased and _near_plot and not _near_house
	if can_dig:
		_dig_panel.visible = true
		_label.text = "At the plot — hold E or Space to dig %s's grave" % p.name
		var holding := Input.is_action_pressed("interact") or Input.is_key_pressed(KEY_SPACE)
		if holding:
			_digging = true
			_dig_accum += delta
			_dig_bar.value = clampf((_dig_accum / DIG_HOLD_SEC) * 100.0, 0.0, 100.0)
			if _human.has_method("set_busy"):
				_human.set_busy(true)
			if _human.has_method("play_anim"):
				_human.play_anim(&"dig")
			# dig scrape SFX occasionally
			if int(_dig_accum * 10) % 8 == 0 and has_node("/root/AudioService"):
				get_node("/root/AudioService").play("dig", 0.9 + randf() * 0.2, -10.0)
			if _dig_accum >= DIG_HOLD_SEC:
				_finish_dig()
		else:
			if _digging:
				_digging = false
				_dig_accum = 0.0
				_dig_bar.value = 0.0
				if _human.has_method("set_busy"):
					_human.set_busy(false)
				if _human.has_method("play_idle"):
					_human.play_idle()
	else:
		_dig_panel.visible = false
		if needs_burial and _near_plot and not PetController.carrying_deceased:
			_label.text = "Plot ready — but you must carry them from home first"
		if not _near_plot:
			_dig_accum = 0.0
			_dig_bar.value = 0.0
			if _digging:
				_digging = false
				if _human.has_method("set_busy"):
					_human.set_busy(false)


func _finish_dig() -> void:
	_digging = false
	_dig_accum = 0.0
	_dig_bar.value = 100.0
	if _human:
		_human.set_busy(false)
		_human.play_idle()
	var pet_name := "Pet"
	if PetController.active_pet != null:
		pet_name = PetController.active_pet.name
	var r: Dictionary = PetController.complete_burial("Rest well")
	if r.get("ok", false):
		_buried_this_visit = true
		if r.get("grave") is GraveRecord:
			pet_name = (r["grave"] as GraveRecord).name
		_toast.text = "Grave dug. %s is at rest. Walk north to HOUSE DOOR." % pet_name
		if has_node("/root/AudioService"):
			get_node("/root/AudioService").play("bury")
		if _dead_pet:
			_dead_pet.visible = false
		_dig_panel.visible = false
		_label.text = "Burial complete — HOUSE DOOR north (E) · adopt at Store"
		var stone := ColorRect.new()
		stone.size = Vector2(28, 36)
		stone.position = _plot_pos - Vector2(14, 28)
		stone.color = Color("9A9AA0")
		_world.add_child(stone)
		var lab := Label.new()
		lab.text = pet_name
		lab.position = _plot_pos + Vector2(-16, 12)
		lab.add_theme_font_size_override("font_size", 10)
		lab.add_theme_color_override("font_color", Color.WHITE)
		_world.add_child(lab)
	else:
		_toast.text = UxCopyScr.care_fail_message(str(r.get("reason", "")))
		_dig_bar.value = 0.0
		if has_node("/root/AudioService"):
			get_node("/root/AudioService").play("care_fail")
