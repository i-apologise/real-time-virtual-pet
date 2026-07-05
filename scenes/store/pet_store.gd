extends Node2D
## Walkable pet store: reception desk, clerk, species pens, adopt at counter.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const UiThemeScr = preload("res://src/ui/ui_theme.gd")
const UxCopyScr = preload("res://src/sim/ux_copy.gd")

const LAYER_WORLD := 1
const WORLD_BOUNDS := Rect2(28, 36, 584, 328)
const EXIT_DOOR := Rect2(300, 360, 48, 36)
const RECEPTION_ZONE := Rect2(250, 100, 140, 70)
const PEN_RADIUS := 48.0

var _human: CharacterBody2D
var _world: Node2D
var _label: Label
var _toast: Label
var _camera: Camera2D
var _pet: CharacterBody2D
var _leash: Line2D

# Pens: {pos, species_id, display, actor}
var _pens: Array = []
var _near_pen: Dictionary = {}
var _near_reception: bool = false

# Adopt UI overlay
var _ui_layer: CanvasLayer
var _adopt_panel: PanelContainer
var _name_edit: LineEdit
var _adopt_species: StringName = &""
var _adopt_title: Label
var _blocked_label: Label


func _ready() -> void:
	y_sort_enabled = true
	_build_store()
	_build_ui()
	_apply_spawn()
	_maybe_spawn_escort_pet()


func _apply_spawn() -> void:
	var _spawn := SceneRouter.take_spawn("default")
	if _human:
		_human.position = Vector2(320, 340)
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


func _label_at(text: String, pos: Vector2, size: int = 11, col: Color = Color(0.15, 0.12, 0.1)) -> void:
	var lab := Label.new()
	lab.text = text
	lab.position = pos
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", col)
	lab.z_index = -40
	_world.add_child(lab)


func _build_store() -> void:
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	# Floor: warm indoor tiles
	_tile(Rect2(0, 0, 640, 400), "floor")
	# Checkered aisle
	for i in 8:
		_decor(Rect2(300, 80 + i * 32, 40, 16), Color(0.92, 0.88, 0.8, 0.5), -95)

	# Outer walls
	_solid(Rect2(0, 0, 640, 28), Color("D8C8A8"))
	_solid(Rect2(0, 372, 300, 28), Color("C8B898"))
	_solid(Rect2(348, 372, 292, 28), Color("C8B898"))
	_solid(Rect2(0, 0, 24, 400), Color("C8B898"))
	_solid(Rect2(616, 0, 24, 400), Color("C8B898"))

	# Front door mat
	_decor(Rect2(300, 350, 48, 22), Color("5A3A22"), -70)
	_decor(Rect2(306, 354, 36, 14), Color("8B5A2B"), -69)
	_label_at("EXIT", Vector2(310, 368), 10, Color(0.9, 0.9, 0.85))

	# Windows on north wall
	_decor(Rect2(80, 32, 50, 28), Color("8EC8E8"), -88)
	_decor(Rect2(510, 32, 50, 28), Color("8EC8E8"), -88)

	# --- Reception desk (center-north) ---
	_solid(Rect2(250, 70, 140, 28), Color("6D4C41"))  # desk top
	_decor(Rect2(255, 98, 130, 36), Color("8D6E63"), -75)  # desk face
	_decor(Rect2(300, 78, 40, 18), Color("ECEFF1"), -74)  # counter papers
	_decor(Rect2(360, 82, 18, 12), Color("C62828"), -74)  # register
	_label_at("RECEPTION", Vector2(288, 58), 12, Color(0.2, 0.15, 0.1))
	_label_at("Adopt here · E", Vector2(278, 138), 10, Color(0.3, 0.25, 0.2))

	# Clerk NPC (static actor)
	var clerk := AnimatedActorScr.new()
	clerk.is_player_controlled = false
	clerk.position = Vector2(320, 78)
	_world.add_child(clerk)
	clerk.setup_frames(SpriteFactoryScr.human_frames(), 2.0)
	clerk.setup_collision(false)
	clerk.set_busy(true)
	clerk.play_idle()
	_label_at("Sam", Vector2(308, 48), 10, Color(0.15, 0.15, 0.2))

	# Poster wall
	_decor(Rect2(40, 80, 60, 80), Color("FFF8E1"), -92)
	_label_at("Adopt\ndon't\nshop\nfast", Vector2(48, 90), 10, Color(0.4, 0.2, 0.15))

	# --- Three species pens along sides ---
	_add_pen(Vector2(110, 220), &"blob", "Cozy Blob pen", Color("A5D6A7"))
	_add_pen(Vector2(320, 250), &"pup", "Needy Pup pen", Color("FFE0B2"))
	_add_pen(Vector2(520, 220), &"owl", "Night Owl pen", Color("C5CAE9"))

	# Shelves / food bags (decor)
	_solid(Rect2(40, 300, 50, 40), Color("8D6E63"))
	_label_at("Food", Vector2(48, 310), 10)
	_solid(Rect2(550, 300, 50, 40), Color("8D6E63"))
	_label_at("Toys", Vector2(558, 310), 10)

	# Player
	_human = AnimatedActorScr.new()
	_human.is_player_controlled = true
	_human.move_speed = 100.0
	_human.position = Vector2(320, 340)
	_world.add_child(_human)
	_human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)
	_human.setup_collision(false)
	_human.set_world_bounds(WORLD_BOUNDS)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(2.15, 2.15)
	_camera.position_smoothing_enabled = true
	_human.add_child(_camera)
	_camera.make_current()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 640
	_camera.limit_bottom = 400


func _add_pen(center: Vector2, species_id: StringName, title: String, mat_color: Color) -> void:
	# Pen floor mat
	_decor(Rect2(center.x - 50, center.y - 40, 100, 80), mat_color, -93)
	# Pen fence posts
	_solid(Rect2(center.x - 52, center.y - 42, 8, 84), Color("5D4037"))
	_solid(Rect2(center.x + 44, center.y - 42, 8, 84), Color("5D4037"))
	_solid(Rect2(center.x - 52, center.y - 42, 104, 8), Color("5D4037"))
	# Open front (south) so player approaches
	_label_at(title, Vector2(center.x - 40, center.y - 58), 11, Color(0.12, 0.1, 0.08))
	_label_at("E view", Vector2(center.x - 16, center.y + 36), 9, Color(0.25, 0.2, 0.15))

	var actor := AnimatedActorScr.new()
	actor.is_pet = true
	actor.is_player_controlled = false
	actor.position = center
	_world.add_child(actor)
	actor.setup_frames(SpriteFactoryScr.pet_frames(String(species_id)), 2.2)
	actor.setup_collision(true)
	actor.set_collision_enabled(false)
	actor.set_busy(true)
	actor.play_anim(&"happy" if String(species_id) != "owl" else &"idle")

	var t: Dictionary = SpeciesCatalog.get_template(species_id)
	_pens.append({
		"pos": center,
		"species_id": species_id,
		"display": str(t.get("display_name", species_id)),
		"actor": actor,
		"blurb": str(t.get("risk_blurb", "")),
		"feed": str(t.get("feed_need_label", "")),
		"play": str(t.get("play_need_label", "")),
		"hardy": str(t.get("hardiness_label", "")),
	})


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 40
	add_child(_ui_layer)

	var top := PanelContainer.new()
	UiThemeScr.apply_panel(top, true)
	top.position = Vector2(10, 8)
	_ui_layer.add_child(top)
	_label = UiThemeScr.title_label("Paw & Co. — E View pen · E Open reception", 12)
	top.add_child(_label)

	_toast = UiThemeScr.toast_label("")
	_toast.position = Vector2(10, 48)
	_ui_layer.add_child(_toast)

	var leave := UiThemeScr.themed_button("Leave store")
	leave.position = Vector2(10, 72)
	leave.pressed.connect(func(): SceneRouter.go("town", "from_store"))
	_ui_layer.add_child(leave)

	# Care-points shop (supplies) — P3 clear Shop card title
	var shop := PanelContainer.new()
	UiThemeScr.apply_panel(shop, true)
	shop.position = Vector2(10, 108)
	_ui_layer.add_child(shop)
	var shop_v := VBoxContainer.new()
	shop_v.add_theme_constant_override("separation", 6)
	shop.add_child(shop_v)
	var shop_title := UiThemeScr.title_label("Shop · Care points (❤)", 15)
	shop_title.name = "ShopTitle"
	shop_v.add_child(shop_title)
	set_meta("shop_title", shop_title)
	var shop_sub := UiThemeScr.accent_label("Spend points earned by caring at home & park", 11)
	shop_v.add_child(shop_sub)
	var inv_lab := UiThemeScr.body_label("", 11)
	inv_lab.name = "InvLab"
	shop_v.add_child(inv_lab)
	set_meta("inv_lab", inv_lab)
	for item in [
		["premium_food", "Premium Food · 12❤", "Next feed +15 hunger"],
		["soap", "Gentle Soap · 10❤", "Next clean +15 hygiene"],
		["chew_toy", "Chew Toy · 25❤", "Permanent play +6 happy"],
	]:
		var b := UiThemeScr.themed_button(str(item[1]))
		b.tooltip_text = str(item[2])
		var iid: String = str(item[0])
		b.pressed.connect(func(): _buy_item(iid))
		shop_v.add_child(b)
	_refresh_shop_labels()

	# Adopt modal — same chrome family
	_adopt_panel = PanelContainer.new()
	_adopt_panel.visible = false
	UiThemeScr.apply_panel(_adopt_panel, true)
	_adopt_panel.position = Vector2(360, 120)
	_ui_layer.add_child(_adopt_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_adopt_panel.add_child(v)
	_adopt_title = UiThemeScr.title_label("", 18)
	v.add_child(_adopt_title)
	_blocked_label = UiThemeScr.body_label("", 12)
	_blocked_label.custom_minimum_size = Vector2(280, 0)
	v.add_child(_blocked_label)
	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	var nl := UiThemeScr.title_label("Name:", 12)
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(160, 0)
	_name_edit.placeholder_text = "2–16 letters"
	name_row.add_child(_name_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var adopt_btn := UiThemeScr.themed_button("Adopt companion")
	adopt_btn.pressed.connect(_confirm_adopt)
	row.add_child(adopt_btn)
	var cancel := UiThemeScr.themed_button("Close")
	cancel.pressed.connect(func(): _adopt_panel.visible = false)
	row.add_child(cancel)

	call_deferred("_place_adopt_panel")


func _place_adopt_panel() -> void:
	if _adopt_panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_adopt_panel.position = Vector2(vp.x * 0.5 - 160, vp.y * 0.28)


func _living_pet_blocks() -> bool:
	return (
		PetController.active_pet != null
		and str(PetController.active_pet.life_state) != "DEAD"
	)


func _open_pen_info(pen: Dictionary) -> void:
	_adopt_species = pen["species_id"]
	_adopt_title.text = "Meet the %s" % pen["display"]
	var block := ""
	if _living_pet_blocks():
		block = (
			"You already have a living pet at home.\n"
			+ "You can only adopt again after they pass and you bury them.\n\n"
		)
	_blocked_label.text = (
		block
		+ "Feed need: %s\nPlay need: %s\nHardiness: %s\n\n%s\n\nTalk to Sam at Reception to finalize."
		% [pen["feed"], pen["play"], pen["hardy"], pen["blurb"]]
	)
	_name_edit.text = "Mochi" if str(_adopt_species) == "blob" else "Buddy"
	_name_edit.editable = not _living_pet_blocks()
	_place_adopt_panel()
	_adopt_panel.visible = true
	_toast.text = "Viewing %s — adopt at reception if ready" % pen["display"]


func _open_reception() -> void:
	if _adopt_species == &"":
		_toast.text = "Browse a pen first (E near a pet), then return to Reception"
		return
	_open_pen_info(_pen_by_species(_adopt_species))
	_toast.text = "Reception — name your companion and Adopt"


func _pen_by_species(sid: StringName) -> Dictionary:
	for p in _pens:
		if p["species_id"] == sid:
			return p
	return _pens[0] if not _pens.is_empty() else {}


func _refresh_shop_labels() -> void:
	var st: Label = get_meta("shop_title") as Label if has_meta("shop_title") else null
	var inv: Label = get_meta("inv_lab") as Label if has_meta("inv_lab") else null
	if st:
		st.text = "Shop · Care points: %d❤" % PetController.profile.care_points
	if inv:
		var p = PetController.profile
		inv.text = "Bag: food×%d  soap×%d  toy×%d" % [
			p.inv_count("premium_food"),
			p.inv_count("soap"),
			p.inv_count("chew_toy"),
		]


func _buy_item(item_id: String) -> void:
	var r: Dictionary = PetController.buy_store_item(item_id)
	if r.get("ok", false):
		_toast.text = "Bought %s · %d❤ left" % [item_id.replace("_", " "), int(r.get("care_points", 0))]
		var audio := get_node_or_null("/root/AudioService")
		if audio and audio.has_method("play"):
			audio.play("ui_click")
	else:
		var reason := str(r.get("reason", ""))
		if reason == "ALREADY_OWNED":
			_toast.text = "You already own a chew toy"
		else:
			_toast.text = UxCopyScr.care_fail_message(reason)
	_refresh_shop_labels()


func _confirm_adopt() -> void:
	if _living_pet_blocks():
		_toast.text = "Can't adopt while you have a living pet"
		return
	if _adopt_species == &"":
		_toast.text = "Pick a pen first"
		return
	var r: Dictionary = PetController.adopt_pet(_adopt_species, _name_edit.text)
	if r.get("ok", false):
		_toast.text = "Welcome home, %s!" % _name_edit.text
		_adopt_panel.visible = false
		var audio := get_node_or_null("/root/AudioService")
		if audio and audio.has_method("play"):
			audio.play("adopt")
		SceneRouter.go("habitat", "from_town")
	else:
		_toast.text = UxCopyScr.care_fail_message(str(r.get("reason", "")))
		var audio2 := get_node_or_null("/root/AudioService")
		if audio2 and audio2.has_method("play"):
			audio2.play("care_fail")


func _maybe_spawn_escort_pet() -> void:
	## Leashed walk used to drop the pet and freeze the walk timer in the store.
	if not PetController.escort_active:
		return
	if PetController.active_pet == null or str(PetController.active_pet.life_state) == "DEAD":
		PetController.escort_active = false
		return
	_leash = Line2D.new()
	_leash.width = 2.8
	_leash.default_color = Color("6D4C41")
	_leash.z_index = 80
	_world.add_child(_leash)
	_pet = AnimatedActorScr.new()
	_pet.is_pet = true
	_pet.is_player_controlled = false
	_pet.move_speed = 100.0
	_pet.position = _human.position + Vector2(-22, 10)
	_world.add_child(_pet)
	_pet.setup_frames(SpriteFactoryScr.pet_frames(String(PetController.active_pet.species_id)), 2.0)
	_pet.set_collision_enabled(false)
	_pet.set_follow(_human, Vector2(-22, 10))
	_pet.set_world_bounds(WORLD_BOUNDS)
	_leash.visible = true
	_toast.text = "On leash — shop or leave via EXIT (E). End walk outside (not on doors)."


func _process(delta: float) -> void:
	if _human == null:
		return
	_refresh_shop_labels()
	# Animate pen pets a little
	for pen in _pens:
		var a: Node = pen.get("actor")
		if a and a.has_method("play_anim") and randf() < 0.002:
			a.play_anim(&"happy" if randf() > 0.5 else &"idle")

	if PetController.escort_active:
		PetController.tick_escort(delta)
		if _pet and _leash:
			_leash.visible = true
			_leash.points = PackedVector2Array([
				_world.to_local(_human.global_position + Vector2(4, -10)),
				_world.to_local(_pet.global_position + Vector2(0, -8)),
			])

	_near_reception = RECEPTION_ZONE.has_point(_human.position)
	_near_pen = {}
	for pen in _pens:
		if _human.global_position.distance_to(pen["pos"]) <= PEN_RADIUS:
			_near_pen = pen
			break

	if _adopt_panel.visible:
		_label.text = "Choosing a companion — Close or Adopt"
		if Input.is_action_just_pressed("ui_cancel"):
			_adopt_panel.visible = false
		return

	# Exit / hotspots before any end-walk style E (pet always in range while leashed)
	if EXIT_DOOR.has_point(_human.position):
		_label.text = (
			"E Leave store → Town (pet follows)"
			if PetController.escort_active
			else "E Leave store → Town"
		)
		if Input.is_action_just_pressed("interact"):
			SceneRouter.go("town", "from_store")
		return

	if not _near_pen.is_empty():
		_label.text = "E View %s" % _near_pen["display"]
		if Input.is_action_just_pressed("interact"):
			_open_pen_info(_near_pen)
		return

	if _near_reception:
		_label.text = "E Open reception (adopt)"
		if Input.is_action_just_pressed("interact"):
			_open_reception()
		return

	if PetController.escort_active:
		_label.text = "On leash in store · min %.0fs · EXIT south · end walk in town/home" % maxf(
			0.0, PetController.ESCORT_MIN_SEC - PetController.escort_elapsed_sec
		)
	else:
		_label.text = "Store — E View pen · E Open reception · E Leave (south)"
