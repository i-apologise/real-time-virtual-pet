extends Node2D
## Town hub: WASD human, POIs to house / store / park / graveyard / AI houses.

const SPEED := 180.0
const POI_RADIUS := 48.0

var _human: Node2D
var _label: Label
var _camera: Camera2D
var _pois: Array = []  # {pos, title, scene_id, node}
var _near_hint: String = ""


func _ready() -> void:
	_build_world()


func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.42, 0.22)
	bg.size = Vector2(1600, 1200)
	bg.position = Vector2(-200, -200)
	add_child(bg)

	_register_poi(Vector2(400, 500), "Player House", Color(0.6, 0.45, 0.3), "habitat")
	_register_poi(Vector2(700, 350), "Pet Store", Color(0.4, 0.55, 0.85), "pet_store")
	_register_poi(Vector2(250, 280), "Pet Park", Color(0.35, 0.7, 0.4), "habitat")
	_register_poi(Vector2(900, 520), "Graveyard", Color(0.35, 0.35, 0.38), "graveyard")
	_register_poi(Vector2(150, 520), "AI House A", Color(0.5, 0.4, 0.45), "")
	_register_poi(Vector2(1050, 300), "AI House B", Color(0.5, 0.4, 0.45), "")

	_human = Node2D.new()
	_human.position = Vector2(400, 560)
	var body := ColorRect.new()
	body.size = Vector2(24, 32)
	body.position = Vector2(-12, -32)
	body.color = Color(0.95, 0.85, 0.7)
	_human.add_child(body)
	add_child(_human)

	_camera = Camera2D.new()
	_camera.position = Vector2(0, -16)
	_human.add_child(_camera)
	_camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.text = "Town — WASD move · walk near POI and press E / Enter"
	layer.add_child(_label)
	var back := Button.new()
	back.text = "Open Habitat UI"
	back.position = Vector2(12, 40)
	back.pressed.connect(func(): SceneRouter.go("habitat"))
	layer.add_child(back)

	# Ambient AI humans (invincible flavor)
	_spawn_ambient(Vector2(160, 540), Color(0.8, 0.7, 0.65))
	_spawn_ambient(Vector2(1060, 320), Color(0.7, 0.75, 0.9))


func _register_poi(pos: Vector2, title: String, color: Color, scene_id: String) -> void:
	var holder := Node2D.new()
	holder.position = pos
	var rect := ColorRect.new()
	rect.size = Vector2(80, 60)
	rect.position = Vector2(-40, -60)
	rect.color = color
	holder.add_child(rect)
	var lab := Label.new()
	lab.text = title
	lab.position = Vector2(-40, -78)
	holder.add_child(lab)
	add_child(holder)
	_pois.append({"pos": pos, "title": title, "scene_id": scene_id, "node": holder})


func _spawn_ambient(pos: Vector2, color: Color) -> void:
	var n := Node2D.new()
	n.position = pos
	var body := ColorRect.new()
	body.size = Vector2(20, 28)
	body.position = Vector2(-10, -28)
	body.color = color
	n.add_child(body)
	var tag := Label.new()
	tag.text = "AI"
	tag.position = Vector2(-10, -44)
	tag.add_theme_font_size_override("font_size", 10)
	n.add_child(tag)
	add_child(n)


func _process(delta: float) -> void:
	if _human == null:
		return
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if dir != Vector2.ZERO:
		_human.position += dir.normalized() * SPEED * delta

	_near_hint = ""
	var nearest_scene := ""
	for poi in _pois:
		if _human.position.distance_to(poi["pos"]) <= POI_RADIUS:
			_near_hint = str(poi["title"])
			nearest_scene = str(poi["scene_id"])
			break
	if _near_hint != "":
		_label.text = "Near: %s — press E to enter · WASD move" % _near_hint
	else:
		_label.text = "Town — WASD move · approach POI · E enter · humans invincible"

	if nearest_scene != "" and Input.is_action_just_pressed("interact"):
		SceneRouter.go(nearest_scene)
