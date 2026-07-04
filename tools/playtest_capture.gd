extends SceneTree
## Automated playtest screenshots (no autoload identifiers — use /root nodes).

const OUT := "user://playtest_shots"

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var cfg := ConfigFile.new()
	cfg.set_value("onboarding", "tutorial_done", true)
	cfg.save("user://onboarding.cfg")
	call_deferred("_run")

func _pc() -> Node:
	return root.get_node_or_null("PetController")

func _router() -> Node:
	return root.get_node_or_null("SceneRouter")

func _run() -> void:
	# Wait for autoloads
	for i in 10:
		await process_frame
		if _pc() and _router():
			break
	var pc := _pc()
	var router := _router()
	print("pc=", pc, " router=", router)
	if pc == null or router == null:
		push_error("missing autoloads")
		quit(1)
		return
	if pc.get("active_pet") == null:
		pc.call("debug_adopt_blob", "Mochi")
	router.call("go", "habitat")
	for i in 12:
		await process_frame
	var habitat: Node = current_scene
	print("SCENE=", habitat)
	var human := _find_flag(habitat, "is_player_controlled", true)
	var pet := _find_pet(habitat)
	print("human=", human, " pet=", pet)
	if human and pet:
		human.global_position = pet.global_position + Vector2(-32, 10)
	for i in 5:
		await process_frame
	await _shot("01_habitat_near_pet")
	if habitat and habitat.has_method("_open_care_menu"):
		habitat.call("_open_care_menu")
		for i in 5:
			await process_frame
		await _shot("02_care_menu_open")
	if habitat and habitat.has_method("_on_care"):
		habitat.call("_on_care", &"clean")
		for i in 40:
			await process_frame
		await _shot("03_clean_bathroom")
		for i in 220:
			await process_frame
		await _shot("04_after_clean")
	if human and pet:
		human.global_position = pet.global_position + Vector2(-32, 10)
	for i in 4:
		await process_frame
	if habitat and habitat.has_method("_on_care"):
		habitat.call("_on_care", &"walk")
		for i in 60:
			await process_frame
		await _shot("05_leash_walk")
		for i in 240:
			await process_frame
		await _shot("06_after_walk")
	if human and pet:
		human.global_position = pet.global_position + Vector2(-32, 10)
	for i in 4:
		await process_frame
	if habitat and habitat.has_method("_on_care"):
		habitat.call("_on_care", &"sleep")
		for i in 50:
			await process_frame
		await _shot("07_sleep_beds")
		for i in 150:
			await process_frame
	router.call("go", "town")
	for i in 15:
		await process_frame
	await _shot("08_town")
	router.call("go", "pet_store")
	for i in 15:
		await process_frame
	await _shot("09_store")
	router.call("go", "graveyard")
	for i in 15:
		await process_frame
	await _shot("10_graveyard")
	router.call("go", "habitat")
	for i in 18:
		await process_frame
	await _shot("11_habitat_final")
	print("PLAYTEST_DONE ", ProjectSettings.globalize_path(OUT))
	quit(0)

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var vp := root.get_viewport()
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		print("SHOT_FAIL no tex ", name)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("SHOT_FAIL no img ", name)
		return
	# Godot 4 may not need flip; try both if blank
	var path := "%s/%s.png" % [OUT, name]
	var err := img.save_png(path)
	print("SHOT ", name, " err=", err, " ", img.get_width(), "x", img.get_height(), " mean=", _mean(img))

func _mean(img: Image) -> float:
	# sample a few pixels to detect black/blank
	var s := 0.0
	var n := 0
	for y in [img.get_height()/4, img.get_height()/2, 3*img.get_height()/4]:
		for x in [img.get_width()/4, img.get_width()/2, 3*img.get_width()/4]:
			var c := img.get_pixel(int(x), int(y))
			s += (c.r + c.g + c.b) / 3.0
			n += 1
	return s / float(maxi(n, 1))

func _find_flag(n: Node, prop: String, want) -> Node:
	if n == null:
		return null
	if n.get(prop) == want:
		return n
	for c in n.get_children():
		var r := _find_flag(c, prop, want)
		if r:
			return r
	return null

func _find_pet(n: Node) -> Node:
	if n == null:
		return null
	if n.get("is_pet") == true and n.get("is_player_controlled") != true:
		return n
	for c in n.get_children():
		var r := _find_pet(c)
		if r:
			return r
	return null
