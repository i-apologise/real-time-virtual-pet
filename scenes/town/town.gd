extends Node2D
## Pokemon-style town: grass tiles, solid buildings, sprite human, AI walkers.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const AmbientWalkerScr = preload("res://src/gameplay/ambient_walker.gd")

const POI_RADIUS := 42.0
const LAYER_WORLD := 1

var _human: CharacterBody2D
var _label: Label
var _world: Node2D
var _pois: Array = []


func _ready() -> void:
	y_sort_enabled = true
	_build_world()


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


func _solid(rect: Rect2, color: Color, title: String = "", scene_id: String = "") -> void:
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
	if title != "":
		var lab := Label.new()
		lab.text = title
		lab.position = Vector2(-rect.size.x * 0.4, -rect.size.y * 0.5 - 26)
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color.WHITE)
		body.add_child(lab)
	_world.add_child(body)
	# Interact point in front of building (south doorstep)
	_pois.append({
		"pos": body.position + Vector2(0, rect.size.y * 0.5 + 14),
		"title": title,
		"scene_id": scene_id,
	})


func _build_world() -> void:
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_tile_rect(Rect2(0, 0, 640, 400), "grass")
	_tile_rect(Rect2(40, 220, 560, 48), "path")

	_solid(Rect2(200, 160, 64, 52), Color("C48C5C"), "House", "habitat")
	_solid(Rect2(360, 100, 72, 56), Color("5B8DEE"), "Store", "pet_store")
	_solid(Rect2(80, 100, 80, 48), Color("3DAA55"), "Park", "habitat")
	_solid(Rect2(480, 180, 72, 52), Color("6B6B70"), "Backyard", "graveyard")
	_solid(Rect2(40, 240, 56, 48), Color("8E6E7A"), "AI A", "")
	_solid(Rect2(540, 90, 56, 48), Color("8E6E7A"), "AI B", "")

	# Map bounds
	_solid(Rect2(-16, 0, 16, 400), Color(0, 0, 0, 0))
	_solid(Rect2(640, 0, 16, 400), Color(0, 0, 0, 0))
	_solid(Rect2(0, -16, 640, 16), Color(0, 0, 0, 0))
	_solid(Rect2(0, 400, 640, 16), Color(0, 0, 0, 0))

	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.is_pet = false
	_human.move_speed = 105.0
	_human.position = Vector2(232, 240)
	_world.add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)
	_human.setup_collision(false)

	var cam := Camera2D.new()
	cam.zoom = Vector2(2.5, 2.5)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	_human.add_child(cam)
	cam.make_current()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 640
	cam.limit_bottom = 400

	var ai1 = AmbientWalkerScr.new()
	_world.add_child(ai1)
	ai1.setup(Vector2(60, 270), Vector2(180, 270), 40.0)
	var ai2 = AmbientWalkerScr.new()
	_world.add_child(ai2)
	ai2.setup(Vector2(520, 160), Vector2(600, 200), 35.0)

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.text = "Town — WASD · walk to a doorstep · E enter (can't walk through buildings)"
	layer.add_child(_label)


func _process(_delta: float) -> void:
	if _human == null:
		return
	var near := ""
	var scene_id := ""
	for poi in _pois:
		if _human.global_position.distance_to(poi["pos"]) <= POI_RADIUS:
			near = str(poi["title"])
			scene_id = str(poi["scene_id"])
			break
	if near != "":
		_label.text = "Near %s — press E" % near
		if scene_id != "" and Input.is_action_just_pressed("interact"):
			SceneRouter.go(scene_id)
	else:
		_label.text = "Town — WASD · doorsteps · E enter · solid buildings & AI"
