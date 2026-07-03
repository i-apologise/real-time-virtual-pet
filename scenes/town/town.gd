extends Node2D
## Town hub with sprite human, POIs, ambient AI walkers.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const AmbientWalkerScr = preload("res://src/gameplay/ambient_walker.gd")

const POI_RADIUS := 52.0

var _human: CharacterBody2D
var _label: Label
var _camera: Camera2D
var _pois: Array = []


func _ready() -> void:
	_build_world()


func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.48, 0.26)
	bg.size = Vector2(1400, 1000)
	bg.position = Vector2(-100, -100)
	bg.z_index = -20
	add_child(bg)
	# path
	var path := ColorRect.new()
	path.color = Color(0.55, 0.5, 0.4)
	path.size = Vector2(1200, 70)
	path.position = Vector2(50, 470)
	path.z_index = -15
	add_child(path)

	_register_poi(Vector2(400, 500), "House", Color(0.65, 0.48, 0.32), "habitat", Vector2(90, 70))
	_register_poi(Vector2(720, 360), "Pet Store", Color(0.4, 0.55, 0.88), "pet_store", Vector2(100, 80))
	_register_poi(Vector2(260, 300), "Park", Color(0.35, 0.72, 0.42), "habitat", Vector2(110, 70))
	_register_poi(Vector2(920, 520), "Graveyard", Color(0.38, 0.38, 0.4), "graveyard", Vector2(100, 70))
	_register_poi(Vector2(140, 540), "AI Home A", Color(0.52, 0.42, 0.48), "", Vector2(80, 60))
	_register_poi(Vector2(1080, 320), "AI Home B", Color(0.52, 0.42, 0.48), "", Vector2(80, 60))

	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.move_speed = 175.0
	_human.position = Vector2(400, 560)
	add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)

	_camera = Camera2D.new()
	_camera.position = Vector2(0, -20)
	_human.add_child(_camera)
	_camera.make_current()

	var ai1 = AmbientWalkerScr.new()
	add_child(ai1)
	ai1.setup(Vector2(120, 560), Vector2(280, 560), 50.0)
	var ai2 = AmbientWalkerScr.new()
	add_child(ai2)
	ai2.setup(Vector2(1000, 340), Vector2(1120, 400), 45.0)

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.text = "Town — WASD walk · E enter POI · AI neighbors wander (invincible)"
	layer.add_child(_label)
	var tip := Label.new()
	tip.position = Vector2(12, 36)
	tip.add_theme_font_size_override("font_size", 13)
	tip.modulate = Color(0.9, 0.95, 0.85)
	tip.text = "Enter House to care for your pet with full character animations"
	layer.add_child(tip)


func _register_poi(pos: Vector2, title: String, color: Color, scene_id: String, size: Vector2) -> void:
	var holder := Node2D.new()
	holder.position = pos
	var rect := ColorRect.new()
	rect.size = size
	rect.position = Vector2(-size.x * 0.5, -size.y)
	rect.color = color
	holder.add_child(rect)
	# roof accent
	var roof := ColorRect.new()
	roof.size = Vector2(size.x + 10, 14)
	roof.position = Vector2(-size.x * 0.5 - 5, -size.y - 14)
	roof.color = color.darkened(0.25)
	holder.add_child(roof)
	var lab := Label.new()
	lab.text = title
	lab.position = Vector2(-size.x * 0.4, -size.y - 32)
	lab.add_theme_font_size_override("font_size", 13)
	holder.add_child(lab)
	add_child(holder)
	_pois.append({"pos": pos, "title": title, "scene_id": scene_id})


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
		_label.text = "Near %s — press E to enter · WASD move" % near
		if scene_id != "" and Input.is_action_just_pressed("interact"):
			SceneRouter.go(scene_id)
	else:
		_label.text = "Town — WASD walk · approach a building · E enter"
