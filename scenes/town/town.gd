extends Node2D
## Town map: house, park, pet store. Solid bounds. Optional leashed pet escort.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const AmbientWalkerScr = preload("res://src/gameplay/ambient_walker.gd")
const UiThemeScr = preload("res://src/ui/ui_theme.gd")

const POI_RADIUS := 42.0
const LAYER_WORLD := 1
const WORLD_BOUNDS := Rect2(24, 24, 592, 352)

var _human: CharacterBody2D
var _pet: CharacterBody2D
var _leash: Line2D
var _label: Label
var _toast: Label
var _world: Node2D
var _pois: Array = []


func _ready() -> void:
	y_sort_enabled = true
	_build_world()
	_apply_spawn()
	_maybe_spawn_escort_pet()


func _apply_spawn() -> void:
	if _human == null:
		return
	var spawn := SceneRouter.take_spawn("default")
	match spawn:
		"from_house":
			_human.position = Vector2(232, 248)
		"from_store":
			_human.position = Vector2(396, 190)
		"from_park":
			_human.position = Vector2(120, 190)
		_:
			_human.position = Vector2(232, 248)
	_human.set_world_bounds(WORLD_BOUNDS)


func _tile_rect(area: Rect2, kind: String) -> void:
	var tex: Texture2D = SpriteFactoryScr.make_tile(kind)
	var y := int(area.position.y)
	while y < int(area.end.y):
		var x := int(area.position.x)
		while x < int(area.end.x):
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = Vector2(x + 8, y + 8)
			spr.z_index = -200
			_world.add_child(spr)
			x += 16
		y += 16


func _solid(rect: Rect2, color: Color, title: String = "", scene_id: String = "", spawn: String = "") -> void:
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
	var roof := ColorRect.new()
	roof.size = Vector2(rect.size.x + 6, 10)
	roof.position = Vector2(-rect.size.x * 0.5 - 3, -rect.size.y * 0.5 - 10)
	roof.color = color.darkened(0.22)
	roof.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(roof)
	var door := ColorRect.new()
	door.size = Vector2(14, 18)
	door.position = Vector2(-7, rect.size.y * 0.5 - 18)
	door.color = Color("4A3020")
	door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(door)
	if title != "":
		var lab := Label.new()
		lab.text = title
		lab.position = Vector2(-rect.size.x * 0.45, -rect.size.y * 0.5 - 26)
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color.WHITE)
		body.add_child(lab)
	_world.add_child(body)
	if scene_id != "":
		_pois.append({
			"pos": body.position + Vector2(0, rect.size.y * 0.5 + 14),
			"title": title,
			"scene_id": scene_id,
			"spawn": spawn,
		})


func _build_world() -> void:
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_tile_rect(Rect2(0, 0, 640, 400), "grass")
	_tile_rect(Rect2(40, 220, 560, 48), "path")
	_tile_rect(Rect2(100, 150, 40, 80), "path")
	_tile_rect(Rect2(360, 160, 40, 70), "path")

	_solid(Rect2(200, 150, 72, 56), Color("C48C5C"), "Your House", "habitat", "from_town")
	_solid(Rect2(360, 100, 80, 56), Color("5B8DEE"), "Pet Store", "pet_store", "from_town")
	_solid(Rect2(70, 90, 96, 64), Color("3DAA55"), "Pet Park", "park", "from_town")
	_solid(Rect2(520, 240, 56, 48), Color("8E6E7A"), "Neighbor", "", "")

	var sign := Label.new()
	sign.text = "Backyard → inside house, south door"
	sign.position = Vector2(170, 220)
	sign.add_theme_font_size_override("font_size", 10)
	sign.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
	_world.add_child(sign)

	# Thick world walls (prevent walking off map)
	_solid(Rect2(0, 0, 640, 18), Color("2A4A20"))
	_solid(Rect2(0, 382, 640, 18), Color("2A4A20"))
	_solid(Rect2(0, 0, 18, 400), Color("2A4A20"))
	_solid(Rect2(622, 0, 18, 400), Color("2A4A20"))

	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.is_pet = false
	_human.move_speed = 105.0
	_human.position = Vector2(232, 248)
	_world.add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)
	_human.setup_collision(false)
	_human.set_world_bounds(WORLD_BOUNDS)

	var cam := Camera2D.new()
	cam.zoom = Vector2(2.3, 2.3)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	_human.add_child(cam)
	cam.make_current()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 640
	cam.limit_bottom = 400

	_leash = Line2D.new()
	_leash.width = 2.8
	_leash.default_color = Color("6D4C41")
	_leash.visible = false
	_leash.z_index = 80
	_world.add_child(_leash)

	var ai1 = AmbientWalkerScr.new()
	_world.add_child(ai1)
	ai1.setup(Vector2(60, 270), Vector2(180, 270), 40.0)
	var ai2 = AmbientWalkerScr.new()
	_world.add_child(ai2)
	ai2.setup(Vector2(480, 200), Vector2(580, 280), 35.0)

	var layer := CanvasLayer.new()
	add_child(layer)
	# P3: shared product chrome (top context chip + toast)
	var top := PanelContainer.new()
	UiThemeScr.apply_panel(top, true)
	top.position = Vector2(10, 8)
	layer.add_child(top)
	_label = UiThemeScr.title_label("Town — WASD · E Enter building", 12)
	top.add_child(_label)
	_toast = UiThemeScr.toast_label("")
	_toast.position = Vector2(10, 48)
	layer.add_child(_toast)


func _maybe_spawn_escort_pet() -> void:
	if not PetController.escort_active:
		return
	if PetController.active_pet == null or str(PetController.active_pet.life_state) == "DEAD":
		PetController.escort_active = false
		return
	_pet = AnimatedActorScr.new()
	_pet.is_pet = true
	_pet.is_player_controlled = false
	_pet.move_speed = 100.0
	_pet.position = _human.position + Vector2(-22, 10)
	_world.add_child(_pet)
	var sid := String(PetController.active_pet.species_id)
	_pet.setup_frames(SpriteFactoryScr.pet_frames(sid), 2.0)
	_pet.setup_collision(true)
	_pet.set_collision_enabled(false)
	_pet.set_follow(_human, Vector2(-22, 10))
	_pet.set_world_bounds(WORLD_BOUNDS)
	_leash.visible = true
	_toast.text = "On leash — E enters buildings (pet follows). Unclip the leash at home."


func _process(delta: float) -> void:
	if _human == null:
		return
	if PetController.escort_active:
		PetController.tick_escort(delta)
		if _pet and _leash:
			_leash.visible = true
			_leash.points = PackedVector2Array([
				_world.to_local(_human.global_position + Vector2(4, -10)),
				_world.to_local(_pet.global_position + Vector2(0, -8)),
			])

	# Buildings first. Never end-walk in town — pet would vanish mid-outing.
	var near := ""
	var scene_id := ""
	var spawn := ""
	for poi in _pois:
		if _human.global_position.distance_to(poi["pos"]) <= POI_RADIUS:
			near = str(poi["title"])
			scene_id = str(poi["scene_id"])
			spawn = str(poi.get("spawn", ""))
			break

	if near != "":
		if PetController.escort_active:
			_label.text = "E Enter %s (pet follows)" % near
		else:
			_label.text = "E Enter %s" % near
		if scene_id != "" and Input.is_action_just_pressed("interact"):
			SceneRouter.go(scene_id, spawn)
		return

	if PetController.escort_active:
		_label.text = "On leash · min %.0fs · doors enter places · end walk at home" % maxf(
			0.0, PetController.ESCORT_MIN_SEC - PetController.escort_elapsed_sec
		)
		if Input.is_action_just_pressed("interact"):
			_toast.text = "Still on a walk — enter a building, or go home to unclip the leash."
		return

	_label.text = "Town — E Enter House · Park · Store"
