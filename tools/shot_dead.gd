extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in 6: await process_frame
	var pc = root.get_node("PetController")
	var router = root.get_node("SceneRouter")
	if pc.active_pet == null:
		pc.debug_adopt_blob("Mochi")
	var DeathRules = load("res://src/sim/death_rules.gd")
	var LifeState = load("res://src/sim/life_state.gd")
	var p = pc.active_pet
	DeathRules.mark_dead(p) if DeathRules.has_method("mark_dead") else null
	# try apply_death
	if DeathRules.has_method("apply_death_now"):
		DeathRules.apply_death_now(p)
	elif DeathRules.has_method("force_death"):
		DeathRules.force_death(p)
	else:
		p.life_state = &"DEAD"
		p.buried = false
	print("life=", p.life_state, " buried=", p.buried)
	router.go("graveyard", "from_house")
	for i in 20: await process_frame
	var img = root.get_viewport().get_texture().get_image()
	var path = "user://playtest_nav/dead_only.png"
	img.save_png(path)
	print("saved", ProjectSettings.globalize_path(path), " life=", p.life_state)
	# also habitat with dead
	router.go("habitat", "from_backyard")
	for i in 20: await process_frame
	img = root.get_viewport().get_texture().get_image()
	img.save_png("user://playtest_nav/dead_home.png")
	print("home dead saved")
	quit(0)
