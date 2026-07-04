extends Node2D
## Visitable pet park: open green, paths, benches, fountain. Great for leashed walks.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const AmbientWalkerScr = preload("res://src/gameplay/ambient_walker.gd")

const LAYER_WORLD := 1
const WORLD_BOUNDS := Rect2(28, 28, 584, 344)
const EXIT_TO_TOWN := Rect2(280, 360, 80, 36)

var _human: CharacterBody2D
var _pet: CharacterBody2D
var _leash: Line2D
var _world: Node2D
var _label: Label
var _toast: Label


func _ready() -> void:
	y_sort_enabled = true
	_build()
	_apply_spawn()
	_maybe_escort()


func _apply_spawn() -> void:
	var spawn := SceneRouter.take_spawn("default")
	if _human:
		if spawn == "from_town":
			_human.position = Vector2(320, 340)
		else:
			_human.position = Vector2(320, 300)
		_human.set_world_bounds(WORLD_BOUNDS)


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
			spr.z_index = -200
			_world.add_child(spr)
			x += 16
		y += 16


func _solid(rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
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
	_tile(Rect2(280, 60, 80, 300), "path")
	_tile(Rect2(80, 180, 480, 40), "path")

	# Fence / bounds
	_solid(Rect2(0, 0, 640, 20), Color("4A6A30"))
	_solid(Rect2(0, 380, 640, 20), Color("4A6A30"))
	_solid(Rect2(0, 0, 20, 400), Color("4A6A30"))
	_solid(Rect2(620, 0, 20, 400), Color("4A6A30"))
	# Gate gap bottom
	_solid(Rect2(0, 380, 280, 20), Color("4A6A30"))
	_solid(Rect2(360, 380, 280, 20), Color("4A6A30"))

	# Fountain
	_decor(Rect2(300, 170, 40, 40), Color("6EC8E8"), -90)
	_decor(Rect2(308, 178, 24, 24), Color("A8E0F8"), -89)
	var fl := Label.new()
	fl.text = "Fountain"
	fl.position = Vector2(298, 212)
	fl.add_theme_font_size_override("font_size", 10)
	fl.add_theme_color_override("font_color", Color(0.15, 0.25, 0.35))
	_world.add_child(fl)

	# Benches
	_decor(Rect2(120, 140, 48, 16), Color("8B6914"), -85)
	_decor(Rect2(470, 140, 48, 16), Color("8B6914"), -85)
	_decor(Rect2(120, 250, 48, 16), Color("8B6914"), -85)
	_decor(Rect2(470, 250, 48, 16), Color("8B6914"), -85)

	# Trees (simple)
	for pos in [Vector2(80, 80), Vector2(540, 80), Vector2(90, 300), Vector2(530, 300), Vector2(200, 100), Vector2(420, 100)]:
		_solid(Rect2(pos.x, pos.y, 28, 28), Color("2E7D32"))
		_decor(Rect2(pos.x + 8, pos.y + 24, 12, 16), Color("5D4037"), -70)

	var title := Label.new()
	title.text = "PET PARK"
	title.position = Vector2(280, 36)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	_world.add_child(title)

	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.move_speed = 105.0
	_human.position = Vector2(320, 340)
	_world.add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)
	_human.setup_collision(false)
	_human.set_world_bounds(WORLD_BOUNDS)

	var cam := Camera2D.new()
	cam.zoom = Vector2(2.2, 2.2)
	cam.position_smoothing_enabled = true
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

	# Other pet owners
	var ai = AmbientWalkerScr.new()
	_world.add_child(ai)
	ai.setup(Vector2(150, 200), Vector2(250, 240), 32.0)

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.text = "Pet Park — walk the paths · south gate → Town"
	layer.add_child(_label)
	_toast = Label.new()
	_toast.position = Vector2(8, 30)
	_toast.modulate = Color(1, 1, 0.7)
	layer.add_child(_toast)
	var back := Button.new()
	back.text = "Leave to Town"
	back.position = Vector2(8, 54)
	back.pressed.connect(func(): SceneRouter.go("town", "from_park"))
	layer.add_child(back)
	var fetch := Button.new()
	fetch.text = "Play fetch (+park bonus)"
	fetch.position = Vector2(8, 88)
	fetch.pressed.connect(_try_park_play)
	layer.add_child(fetch)


func _maybe_escort() -> void:
	PetController.note_park_visit()
	if not PetController.escort_active:
		_toast.text = "Nice day for a stroll — bring a leashed pet from home (CARE → WALK)"
		return
	if PetController.active_pet == null:
		return
	_pet = AnimatedActorScr.new()
	_pet.is_pet = true
	_pet.move_speed = 100.0
	_pet.position = _human.position + Vector2(-22, 10)
	_world.add_child(_pet)
	_pet.setup_frames(SpriteFactoryScr.pet_frames(String(PetController.active_pet.species_id)), 2.0)
	_pet.set_collision_enabled(false)
	_pet.set_follow(_human, Vector2(-22, 10))
	_pet.set_world_bounds(WORLD_BOUNDS)
	_leash.visible = true
	_toast.text = "Leashed in the park! Explore · E near pet to finish walk (after min time)"


func _process(delta: float) -> void:
	if _human == null:
		return
	if PetController.escort_active:
		PetController.tick_escort(delta)
		if _pet and _leash:
			_leash.points = PackedVector2Array([
				_world.to_local(_human.global_position + Vector2(4, -10)),
				_world.to_local(_pet.global_position),
			])
		_label.text = "Park (leashed) · walk min %.0fs · E near pet to end · south gate Town" % maxf(
			0.0, PetController.ESCORT_MIN_SEC - PetController.escort_elapsed_sec
		)
		if Input.is_action_just_pressed("interact") and _pet:
			if _human.global_position.distance_to(_pet.global_position) < 56.0:
				if PetController.can_finish_escort():
					PetController.end_escort(true)
					_pet.clear_follow()
					_pet.queue_free()
					_pet = null
					_leash.visible = false
					_toast.text = "Great walk! Pet is happier."
				else:
					_toast.text = "A bit more walking… %.0fs" % maxf(
						0.0, PetController.ESCORT_MIN_SEC - PetController.escort_elapsed_sec
					)
				return

	if EXIT_TO_TOWN.has_point(_human.position):
		_label.text = "Town gate — press E"
		if Input.is_action_just_pressed("interact"):
			SceneRouter.go("town", "from_park")


func _try_park_play() -> void:
	## Outdoor play without full habitat choreography — park happiness bonus.
	if PetController.active_pet == null or str(PetController.active_pet.life_state) == "DEAD":
		_toast.text = "Bring a living pet (leash walk from home)"
		return
	if not PetController.escort_active and _pet == null:
		_toast.text = "Leash them at home (CARE → WALK) then visit the park"
		return
	PetController.note_park_visit()
	var r: Dictionary = PetController.request_care(&"play", {"outdoor_park": true})
	if r.get("ok", false):
		var pts := int(r.get("care_points_earned", 0))
		_toast.text = "Fetch! Happy park play · +%d care points" % pts
		var audio := get_node_or_null("/root/AudioService")
		if audio and audio.has_method("play_care"):
			audio.play_care(&"play", true)
	else:
		_toast.text = "Can't play: %s" % str(r.get("reason", "no"))
