extends SceneTree

const OUT := "user://playtest_nav"

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var cfg := ConfigFile.new()
	cfg.set_value("onboarding", "tutorial_done", true)
	cfg.save("user://onboarding.cfg")
	call_deferred("_run")

func _run() -> void:
	for i in 8:
		await process_frame
	var pc := root.get_node("PetController")
	var router := root.get_node("SceneRouter")
	if pc.get("active_pet") == null:
		pc.call("debug_adopt_blob", "Mochi")
	router.call("go", "habitat", "from_town")
	for i in 15:
		await process_frame
	await _shot("01_home")
	router.call("go", "graveyard", "from_house")
	for i in 15:
		await process_frame
	await _shot("02_backyard_from_house")
	# force dead for art shot
	var pet = pc.get("active_pet")
	if pet:
		pet.life_state = "DEAD" if "DEAD" in str(pet.get("life_state")) or true else pet.life_state
		# set properly
		if pet.get("hunger") != null:
			pet.hunger = 0.0
		# direct dead if field exists
		if "life_state" in pet:
			pass
	# use request or force
	if pet and pet.has_method("to_dict"):
		# Force via reflection
		pet.set("life_state", pet.get("life_state"))
	# Kill via controller debug if any
	if pc.has_method("debug_force_dead"):
		pc.call("debug_force_dead")
	else:
		# set DEAD on active pet object
		var p = pc.active_pet
		if p:
			p.life_state = &"DEAD" if typeof(p.life_state) == TYPE_STRING_NAME else "DEAD"
			p.buried = false
	router.call("go", "graveyard", "from_house")
	for i in 20:
		await process_frame
	await _shot("03_dead_pet_backyard")
	router.call("go", "habitat", "from_backyard")
	for i in 15:
		await process_frame
	await _shot("04_home_from_yard")
	router.call("go", "town", "from_house")
	for i in 12:
		await process_frame
	await _shot("05_town")
	print("DONE ", ProjectSettings.globalize_path(OUT))
	quit(0)

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [OUT, name])
		print("SHOT ", name)
