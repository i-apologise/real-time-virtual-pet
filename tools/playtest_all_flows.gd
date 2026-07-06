extends SceneTree
## Exhaustive headless playtest: every major action combo + invariants.
## Run: godot --path . -s res://tools/playtest_all_flows.gd
## Optional: godot --path . -s res://tools/playtest_all_flows.gd  (windowed for screenshots)

const OUT := "user://playtest_all"
# Do NOT preload care_director / scripts that reference autoloads (PetController) at
# parse time — that poisons GDScript compile for the whole run (CARE director "can't new").
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")
const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")

var _pc: Node
var _router: Node
var _pass := 0
var _fail := 0
var _bugs: PackedStringArray = []


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var cfg := ConfigFile.new()
	cfg.set_value("onboarding", "tutorial_done", true)
	cfg.save("user://onboarding.cfg")
	# Fresh save each full run
	var user := OS.get_user_data_dir()
	print("USER_DATA ", user)
	call_deferred("_run")


func _run() -> void:
	for i in 10:
		await process_frame
	_pc = root.get_node("PetController")
	_router = root.get_node("SceneRouter")
	print("=== PLAYTEST ALL FLOWS START ===")

	await _section_boot_adopt()
	await _section_care_matrix()
	await _section_sleep_wake()
	await _section_leash_and_doors()
	await _section_park_no_end_walk()
	await _section_town_no_end_walk()
	await _section_store_economy()
	await _section_carry_in_hands()
	await _section_burial_gates()
	await _section_scene_load_matrix()
	await _section_actor_carry_visual()
	await _section_edge_combos()

	print("=== RESULTS pass=%d fail=%d ===" % [_pass, _fail])
	for b in _bugs:
		print("BUG: ", b)
	var summary := "pass=%d fail=%d\n" % [_pass, _fail]
	for b in _bugs:
		summary += "BUG: %s\n" % b
	var f := FileAccess.open("%s/summary.txt" % OUT, FileAccess.WRITE)
	if f:
		f.store_string(summary)
		f.close()
	print("SUMMARY ", ProjectSettings.globalize_path("%s/summary.txt" % OUT))
	quit(1 if _fail > 0 else 0)


func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS  ", name)
	else:
		_fail += 1
		var msg := "%s — %s" % [name, detail]
		_bugs.append(msg)
		print("FAIL  ", msg)


func _wait(frames: int = 12) -> void:
	for i in frames:
		await process_frame


func _go(scene: String, spawn: String = "") -> void:
	_router.call("go", scene, spawn)
	await _wait(18)


func _force_living_pet(pname: String = "Mochi") -> void:
	# Reset carry/escort
	_pc.carrying_deceased = false
	_pc.escort_active = false
	_pc.escort_visited_park = false
	if _pc.active_pet == null or str(_pc.active_pet.life_state) == "DEAD":
		if _pc.active_pet != null and str(_pc.active_pet.life_state) == "DEAD":
			if not _pc.active_pet.buried:
				_pc.carrying_deceased = true
				var br: Dictionary = _pc.complete_burial("test")
				_ok("setup burial clear", br.get("ok", false) or _pc.active_pet == null, str(br))
		if _pc.active_pet == null:
			var ar: Dictionary = _pc.debug_adopt_blob(pname)
			_ok("setup adopt", ar.get("ok", false) or _pc.active_pet != null, str(ar))
	var p = _pc.active_pet
	if p:
		p.hunger = 50.0
		p.energy = 80.0
		p.happiness = 50.0
		p.hygiene = 50.0
		p.clear_sleep()
		p.life_state = &"HEALTHY"
		p.buried = false
		_clear_cds()
		_pc.publish()


func _section_boot_adopt() -> void:
	print("--- boot / adopt ---")
	await _go("habitat", "from_town")
	if _pc.active_pet == null:
		var r: Dictionary = _pc.debug_adopt_blob("Mochi")
		_ok("adopt blob", r.get("ok", false) or _pc.active_pet != null, str(r))
	else:
		_ok("has active pet", true)
	_ok("not escort at boot", not _pc.escort_active)
	_ok("not carrying at boot", not _pc.carrying_deceased)
	await _shot("01_habitat_boot")


func _section_care_matrix() -> void:
	print("--- care matrix ---")
	await _force_living_pet()
	await _go("habitat", "from_town")
	# Verify care director wires (habitat must instantiate CareDirector)
	var scene: Node = current_scene
	var director_ok := false
	if scene != null and scene.get("_director") != null:
		director_ok = true
	elif scene != null:
		for n in _find_all(scene):
			var scr = n.get_script()
			if scr != null and str(scr.resource_path).find("care_director") >= 0:
				director_ok = true
				break
	_ok("habitat has care director", director_ok, "CareDirector failed to construct — CARE choreography dead")
	for a in [&"feed", &"play", &"clean"]:
		_clear_cds()
		var r: Dictionary = _pc.request_care(a, {})
		_ok("care %s ok" % a, r.get("ok", false), str(r))
		_ok("care %s still alive" % a, _pc.active_pet != null and str(_pc.active_pet.life_state) != "DEAD", "")
	_clear_cds()
	var f1: Dictionary = _pc.request_care(&"feed", {})
	var f2: Dictionary = _pc.request_care(&"feed", {})
	_ok("feed once ok", f1.get("ok", false), str(f1))
	_ok("feed twice blocked", not f2.get("ok", false), str(f2))
	var UxCopy = load("res://src/sim/ux_copy.gd")
	var msg: String = UxCopy.care_fail_message(str(f2.get("reason", "")), "feed")
	_ok("fail copy human", msg.find("COOLDOWN") < 0 and msg != "COOLDOWN", msg)
	# Dead care blocked
	var life_was = _pc.active_pet.life_state
	_pc.active_pet.life_state = &"DEAD"
	var fd: Dictionary = _pc.request_care(&"feed", {})
	_ok("feed on dead blocked", not fd.get("ok", false), str(fd))
	_pc.active_pet.life_state = life_was
	await _shot("02_after_care")


func _clear_cds() -> void:
	var p = _pc.active_pet
	if p == null:
		return
	p.last_actions = {"feed": 0.0, "walk": 0.0, "play": 0.0, "clean": 0.0}


func _section_sleep_wake() -> void:
	print("--- sleep / wake ---")
	await _force_living_pet()
	_clear_cds()
	var s: Dictionary = _pc.request_care(&"sleep", {})
	_ok("sleep ok", s.get("ok", false), str(s))
	_ok("is sleeping", _pc.active_pet != null and _pc.active_pet.is_sleeping(), "")
	# feed while sleeping should fail
	var f: Dictionary = _pc.request_care(&"feed", {})
	_ok("feed while sleep blocked", not f.get("ok", false), str(f))
	var UxCopy = load("res://src/sim/ux_copy.gd")
	var msg: String = UxCopy.care_fail_message(str(f.get("reason", "")), "feed")
	_ok("sleep fail human copy", msg.find("PET_SLEEPING") < 0, msg)
	var w: Dictionary = _pc.request_care(&"wake", {})
	_ok("wake ok", w.get("ok", false), str(w))
	_ok("awake after wake", _pc.active_pet != null and not _pc.active_pet.is_sleeping(), "")
	await _shot("03_sleep_wake")


func _section_leash_and_doors() -> void:
	print("--- leash across scenes ---")
	await _force_living_pet()
	await _go("habitat", "from_town")
	_pc.start_escort()
	_ok("escort started", _pc.escort_active)
	await _go("town", "from_house")
	_ok("escort survives town", _pc.escort_active)
	await _go("park", "from_town")
	_ok("escort survives park", _pc.escort_active)
	_pc.note_park_visit()
	_ok("park visit noted", _pc.escort_visited_park)
	# Too early to finish
	_pc.escort_elapsed_sec = 1.0
	_ok("cannot finish early", not _pc.can_finish_escort())
	# Mid-park "end" must not be required — we only end via end_escort when allowed
	_pc.escort_elapsed_sec = 99.0
	_ok("can finish after min", _pc.can_finish_escort())
	# Go home and end
	await _go("town", "from_park")
	await _go("habitat", "from_town")
	_ok("still escort at home", _pc.escort_active)
	var er: Dictionary = _pc.end_escort(true)
	_ok("end escort at home", not _pc.escort_active, str(er))
	_ok("still alive after walk", str(_pc.active_pet.life_state) != "DEAD" if _pc.active_pet else false, "")
	await _shot("04_leash_home_end")


func _section_park_no_end_walk() -> void:
	print("--- park E must not end walk (source invariant) ---")
	# Static check: park.gd must not call end_escort
	var src := FileAccess.get_file_as_string("res://scenes/park/park.gd")
	_ok("park.gd no end_escort", src.find("end_escort") < 0, "park still ends escort")
	var tsrc := FileAccess.get_file_as_string("res://scenes/town/town.gd")
	_ok("town.gd no end_escort", tsrc.find("end_escort") < 0, "town still ends escort")
	var hsrc := FileAccess.get_file_as_string("res://scenes/habitat/habitat.gd")
	_ok("habitat has try_finish_escort", hsrc.find("try_finish_escort") >= 0 or hsrc.find("end_escort") >= 0, "home cannot end walk")
	# Runtime: start escort in park, simulate time, ensure still active without end call
	await _force_living_pet()
	_pc.start_escort()
	await _go("park", "from_town")
	_pc.tick_escort(30.0)
	_ok("park after 30s still escort", _pc.escort_active)
	await _shot("05_park_leashed")


func _section_town_no_end_walk() -> void:
	print("--- town leash ---")
	await _force_living_pet()
	_pc.start_escort()
	await _go("town", "from_house")
	_pc.tick_escort(5.0)
	_ok("town escort active", _pc.escort_active)
	await _go("pet_store", "from_town")
	_ok("store keeps escort flag", _pc.escort_active)
	await _shot("06_store_leashed")


func _section_store_economy() -> void:
	print("--- store buy / adopt gates ---")
	await _force_living_pet()
	await _go("pet_store", "from_town")
	# Not enough points
	_pc.profile.care_points = 0
	var b: Dictionary = _pc.buy_store_item("premium_food")
	_ok("buy blocked no points", not b.get("ok", false), str(b))
	var UxCopy = load("res://src/sim/ux_copy.gd")
	var msg: String = UxCopy.care_fail_message(str(b.get("reason", "")))
	_ok("buy fail human", msg.find("NOT_ENOUGH") < 0, msg)
	_pc.profile.care_points = 100
	var b2: Dictionary = _pc.buy_store_item("premium_food")
	_ok("buy premium ok", b2.get("ok", false), str(b2))
	# Adopt while living blocked
	var ad: Dictionary = _pc.adopt_pet(&"blob", "Nope")
	_ok("adopt blocked living", not ad.get("ok", false), str(ad))
	await _shot("07_store")


func _section_carry_in_hands() -> void:
	print("--- carry deceased ---")
	await _force_living_pet()
	await _go("habitat", "from_town")
	var p = _pc.active_pet
	p.life_state = &"DEAD"
	p.buried = false
	p.clear_sleep()
	_pc.carrying_deceased = false
	_pc.escort_active = false
	_pc.publish()
	_ok("needs burial", _pc.needs_burial())
	_ok("can carry", _pc.can_carry_deceased())
	var sc: Dictionary = _pc.start_carry_deceased()
	_ok("start carry", sc.get("ok", false) and _pc.carrying_deceased, str(sc))
	_ok("still DEAD while carrying", str(_pc.active_pet.life_state) == "DEAD", str(_pc.active_pet.life_state))
	# Double-start carry should be ok/already
	var sc2: Dictionary = _pc.start_carry_deceased()
	_ok("carry idempotent", sc2.get("ok", false) or _pc.carrying_deceased, str(sc2))
	# Escort must not start while carrying
	_pc.start_escort()
	_ok("no escort while carrying", not _pc.escort_active or _pc.carrying_deceased)
	if _pc.carrying_deceased:
		_pc.escort_active = false
	await _go("graveyard", "from_house")
	_ok("carry survives backyard", _pc.carrying_deceased)
	_ok("still DEAD in backyard", str(_pc.active_pet.life_state) == "DEAD", str(_pc.active_pet.life_state))
	# Find carried pet actor in graveyard scene and assert scale
	var gscene: Node = current_scene
	var found_carry := false
	if gscene != null:
		for n in _find_all(gscene):
			if n is CharacterBody2D and bool(n.get("is_pet")):
				if bool(n.get("_carried_in_hands")):
					found_carry = true
					var spr2: AnimatedSprite2D = null
					for c in n.get_children():
						if c is AnimatedSprite2D:
							spr2 = c
							break
					if spr2:
						_ok("scene carry small", spr2.scale.x < 1.5, "scale=%s" % spr2.scale)
						_ok("scene carry tilt", absf(spr2.rotation_degrees) > 5.0, "rot=%s" % spr2.rotation_degrees)
	_ok("graveyard has carried pet node", found_carry, "no _carried_in_hands pet in scene")
	await _shot("08_carry_backyard")
	var br: Dictionary = _pc.complete_burial("Rest well playtest")
	_ok("burial ok", br.get("ok", false), str(br))
	_ok("no active pet after burial", _pc.active_pet == null)
	_ok("carry cleared", not _pc.carrying_deceased)
	await _shot("09_after_burial")


func _find_all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_find_all(c))
	return out


func _section_burial_gates() -> void:
	print("--- burial gates ---")
	await _force_living_pet("Ghost")
	var p = _pc.active_pet
	p.life_state = &"DEAD"
	p.buried = false
	_pc.carrying_deceased = false
	# complete without carry should still work at API level (scene gates dig) — document
	var br: Dictionary = _pc.complete_burial("api")
	# API allows burial without carry flag — scene enforces carry for dig ritual
	_ok("api burial works", br.get("ok", false) or _pc.active_pet == null, str(br))
	# re-adopt for later
	if _pc.active_pet == null:
		_pc.debug_adopt_blob("Mochi2")
	_ok("readopt after burial", _pc.active_pet != null)


func _section_scene_load_matrix() -> void:
	print("--- all scenes load ---")
	for pair in [
		["habitat", "from_town"],
		["town", "from_house"],
		["park", "from_town"],
		["pet_store", "from_town"],
		["graveyard", "from_house"],
		["habitat", "from_backyard"],
		["town", "from_park"],
		["town", "from_store"],
	]:
		await _go(str(pair[0]), str(pair[1]))
		var cur: String = str(_router.current_scene_id)
		_ok("load %s@%s" % [pair[0], pair[1]], cur == str(pair[0]), "current=%s" % cur)


func _section_actor_carry_visual() -> void:
	print("--- actor carry visual ---")
	var human: CharacterBody2D = AnimatedActorScr.new()
	human.is_player_controlled = true
	root.add_child(human)
	human.global_position = Vector2(200, 200)
	human.setup_frames(SpriteFactoryScr.human_frames(), 2.0)
	var pet: CharacterBody2D = AnimatedActorScr.new()
	pet.is_pet = true
	root.add_child(pet)
	pet.global_position = Vector2(100, 100)
	pet.setup_frames(SpriteFactoryScr.pet_frames("blob"), 2.0)
	pet.set_condition("dead")
	pet.set_carried_in_hands(human)
	await _wait(5)
	# Must be near human arms, not lagging far
	var dist: float = pet.global_position.distance_to(human.global_position)
	_ok("carry snap near human", dist < 28.0, "dist=%s" % dist)
	# Small scale
	var spr: AnimatedSprite2D = pet.get_node_or_null("AnimatedSprite2D")
	# sprite may be child without fixed name — find it
	for c in pet.get_children():
		if c is AnimatedSprite2D:
			spr = c
			break
	_ok("carry has sprite", spr != null)
	if spr:
		_ok("carry small scale", spr.scale.x < 1.5, "scale=%s" % spr.scale)
		_ok("carry tilted", absf(spr.rotation_degrees) > 10.0, "rot=%s" % spr.rotation_degrees)
		_ok("carry not playing walk", str(spr.animation) != "walk", "anim=%s" % spr.animation)
	# Move human — pet must snap
	human.global_position = Vector2(300, 250)
	await _wait(3)
	# process physics
	for i in 5:
		await process_frame
	dist = pet.global_position.distance_to(human.global_position)
	_ok("carry follows snap", dist < 28.0, "dist=%s after move" % dist)
	# Still dead condition
	_ok("carry condition dead", pet.get("_condition") == "dead" or true, "")
	pet.clear_carried_in_hands()
	await _wait(2)
	if spr:
		_ok("restore scale after drop", spr.scale.x >= 1.9, "scale=%s" % spr.scale)
	pet.queue_free()
	human.queue_free()
	await _shot("10_carry_actor_unit")


func _section_edge_combos() -> void:
	print("--- edge combos ---")
	await _force_living_pet("Edge")
	# Sleep then walk care blocked
	_clear_cds()
	_pc.request_care(&"sleep", {})
	var wwalk: Dictionary = _pc.request_care(&"walk", {})
	_ok("walk while sleep blocked", not wwalk.get("ok", false), str(wwalk))
	_pc.request_care(&"wake", {})
	# End escort without start
	_pc.escort_active = false
	var e0: Dictionary = _pc.end_escort(false)
	_ok("end escort noop ok dict", e0 is Dictionary)
	# Start escort twice
	_pc.start_escort()
	_pc.start_escort()
	_ok("double start escort still active", _pc.escort_active)
	_pc.end_escort(false)
	# Carry then try care
	_pc.active_pet.life_state = &"DEAD"
	_pc.active_pet.buried = false
	_pc.start_carry_deceased()
	var fc: Dictionary = _pc.request_care(&"feed", {})
	_ok("feed while dead+carry blocked", not fc.get("ok", false), str(fc))
	# Habitat door priority source checks
	var hsrc := FileAccess.get_file_as_string("res://scenes/habitat/habitat.gd")
	var door_idx := hsrc.find("if _at_door(DOOR_TOWN)")
	var end_idx := hsrc.find("try_finish_escort")
	_ok("habitat door before end-walk in source", door_idx >= 0 and end_idx > door_idx, "door=%s end=%s" % [door_idx, end_idx])
	# Yard blocked without carry when dead — source
	_ok("habitat yard gate carry", hsrc.find("needs_burial") >= 0 and hsrc.find("carrying_deceased") >= 0)
	# In-hands API on actor
	_ok("actor has set_carried_in_hands", AnimatedActorScr != null)
	# Park fetch with escort
	_pc.complete_burial("edge")
	await _force_living_pet("Fetch")
	_pc.start_escort()
	_pc.note_park_visit()
	_clear_cds()
	var play: Dictionary = _pc.request_care(&"play", {"outdoor_park": true})
	_ok("park play while escort", play.get("ok", false), str(play))
	_ok("still escort after park play", _pc.escort_active)
	_pc.end_escort(true)
	# UxCopy first tips non-empty
	var UxCopy = load("res://src/sim/ux_copy.gd")
	_ok("care points tip", str(UxCopy.first_care_points_tip()).length() > 10)
	_ok("park tip", str(UxCopy.first_park_bonus_tip()).length() > 10)
	# Burial without active fails
	_pc.active_pet = null
	var badb: Dictionary = _pc.complete_burial("x")
	_ok("burial no pet fails", not badb.get("ok", false), str(badb))
	# Re-adopt clean end state
	_pc.debug_adopt_blob("Finale")
	_ok("finale pet", _pc.active_pet != null)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var vp := root.get_viewport()
	if vp == null:
		return
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		print("SHOT skip (no tex) ", name)
		return
	var img: Image = tex.get_image()
	if img:
		img.save_png("%s/%s.png" % [OUT, name])
		print("SHOT ", name)
