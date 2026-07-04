extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in 6: await process_frame
	var pc = root.get_node("PetController")
	var router = root.get_node("SceneRouter")
	if pc.active_pet == null or str(pc.active_pet.life_state) == "DEAD":
		pc.active_pet = null
		pc.debug_adopt_blob("Mochi")
	pc.active_pet.clear_sleep()
	pc.escort_active = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest_nav"))
	router.go("pet_store", "from_town")
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://playtest_nav/store.png")
	router.go("park", "from_town")
	for i in 18: await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://playtest_nav/park.png")
	pc.start_escort()
	router.go("town", "from_house")
	for i in 18: await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://playtest_nav/town_escort.png")
	print("shots ok")
	quit(0)
