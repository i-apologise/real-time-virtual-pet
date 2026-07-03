extends Node2D
## Backyard graveyard: walk to empty plot, hold E/Space to dig and bury.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")

const LAYER_WORLD := 1
const DIG_HOLD_SEC := 2.5
const PLOT_RADIUS := 40.0

var _human: CharacterBody2D
var _dead_pet: CharacterBody2D
var _camera: Camera2D
var _world: Node2D
var _label: Label
var _toast: Label
var _dig_bar: ProgressBar
var _dig_panel: PanelContainer
var _plot_pos: Vector2 = Vector2(320, 220)
var _near_plot: bool = false
var _digging: bool = false
var _dig_accum: float = 0.0
var _buried_this_visit: bool = false


func _ready() -> void:
	y_sort_enabled = true
	_build()
	_refresh_state()


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


func _build() -> void:
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_tile(Rect2(0, 0, 640, 400), "grass")
	_tile(Rect2(200, 160, 240, 120), "path")

	# fence borders
	_solid(Rect2(0, 0, 640, 16), Color("6B4E2E"))
	_solid(Rect2(0, 384, 640, 16), Color("6B4E2E"))
	_solid(Rect2(0, 0, 16, 400), Color("6B4E2E"))
	_solid(Rect2(624, 0, 16, 400), Color("6B4E2E"))

	# Existing headstones (already buried)
	_draw_existing_graves()

	# Open dig plot (backyard plot marker)
	var plot := ColorRect.new()
	plot.size = Vector2(48, 32)
	plot.position = _plot_pos - Vector2(24, 16)
	plot.color = Color("4A3C28")
	plot.z_index = -50
	plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(plot)
	var plot_l := Label.new()
	plot_l.text = "EMPTY PLOT"
	plot_l.position = _plot_pos + Vector2(-28, 18)
	plot_l.add_theme_font_size_override("font_size", 10)
	plot_l.add_theme_color_override("font_color", Color.WHITE)
	plot_l.z_index = -49
	_world.add_child(plot_l)

	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.move_speed = 105.0
	_human.position = Vector2(120, 300)
	_world.add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)
	_human.setup_collision(false)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(2.2, 2.2)
	_camera.position_smoothing_enabled = true
	_human.add_child(_camera)
	_camera.make_current()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 640
	_camera.limit_bottom = 400

	# Dead pet body near plot if unburied
	_dead_pet = AnimatedActorScr.new()
	_dead_pet.is_pet = true
	_dead_pet.is_player_controlled = false
	_dead_pet.position = _plot_pos + Vector2(-40, 0)
	_world.add_child(_dead_pet)

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(_label)
	_toast = Label.new()
	_toast.position = Vector2(8, 32)
	_toast.modulate = Color(1, 1, 0.7)
	layer.add_child(_toast)

	var back := Button.new()
	back.text = "Leave Graveyard"
	back.position = Vector2(8, 56)
	back.pressed.connect(func(): SceneRouter.go("habitat"))
	layer.add_child(back)

	_dig_panel = PanelContainer.new()
	_dig_panel.position = Vector2(200, 320)
	_dig_panel.visible = false
	layer.add_child(_dig_panel)
	var dv := VBoxContainer.new()
	_dig_panel.add_child(dv)
	var dl := Label.new()
	dl.text = "Hold E or Space to dig the grave"
	dv.add_child(dl)
	_dig_bar = ProgressBar.new()
	_dig_bar.custom_minimum_size = Vector2(200, 16)
	_dig_bar.max_value = 100
	dv.add_child(_dig_bar)


func _draw_existing_graves() -> void:
	var graves: Array = PetController.profile.graves
	var i := 0
	for g in graves:
		if not (g is GraveRecord):
			continue
		var pos := Vector2(80 + (i % 8) * 64, 80 + int(i / 8) * 70)
		var stone := ColorRect.new()
		stone.size = Vector2(28, 36)
		stone.position = pos
		stone.color = Color("8A8A90")
		stone.z_index = int(pos.y)
		stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(stone)
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
			_dead_pet.setup_frames(SpriteFactoryScr.pet_frames(sid), 2.0)
			_dead_pet.set_condition("dead")
			_dead_pet.play_anim(&"dead")
			_dead_pet.set_collision_enabled(false)
	if needs_burial:
		_label.text = "Backyard Graveyard — carry %s to the EMPTY PLOT · hold E to dig" % p.name
	else:
		_label.text = "Backyard Graveyard — rest in peace · Leave when ready"
		_dig_panel.visible = false


func _process(delta: float) -> void:
	if _human == null:
		return
	_near_plot = _human.global_position.distance_to(_plot_pos) <= PLOT_RADIUS
	var p = PetController.active_pet
	var needs_burial: bool = (
		p != null and str(p.life_state) == "DEAD" and not p.buried and not _buried_this_visit
	)

	if needs_burial and _near_plot:
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
				# keep digging pose
				if _human.get("_sprite") != null or true:
					_human.play_anim(&"dig")
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
		_dig_panel.visible = needs_burial and _near_plot
		if needs_burial and not _near_plot:
			_dig_accum = 0.0
			_dig_bar.value = 0.0
			_digging = false


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
		_toast.text = "Grave dug. %s is at rest." % pet_name
		if _dead_pet:
			_dead_pet.visible = false
		_dig_panel.visible = false
		_label.text = "Burial complete — Leave · adopt again at the Store"
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
		_toast.text = "Could not bury: %s" % str(r.get("reason", "fail"))
		_dig_bar.value = 0.0
