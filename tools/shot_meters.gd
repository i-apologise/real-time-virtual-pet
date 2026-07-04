extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in 6: await process_frame
	var pc = root.get_node("PetController")
	var router = root.get_node("SceneRouter")
	# Force a living pet for screenshots
	if pc.active_pet == null or str(pc.active_pet.life_state) == "DEAD":
		pc.active_pet = null
		pc.debug_adopt_blob("Mochi")
	pc.active_pet.clear_sleep()
	pc.active_pet.hunger = 55.0
	pc.active_pet.energy = 70.0
	pc.active_pet.happiness = 65.0
	pc.active_pet.hygiene = 75.0
	pc.active_pet.life_state = &"HEALTHY"
	pc.publish()
	router.go("habitat", "from_town")
	for i in 20: await process_frame
	var img = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest_nav"))
	img.save_png("user://playtest_nav/meters.png")
	var r = pc.request_care(&"feed")
	print("feed result ", r, " hunger=", pc.active_pet.hunger)
	for i in 12: await process_frame
	img = root.get_viewport().get_texture().get_image()
	img.save_png("user://playtest_nav/meters_after_feed.png")
	quit(0)
