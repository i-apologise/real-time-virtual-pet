extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in 6: await process_frame
	var pc = root.get_node("PetController")
	var router = root.get_node("SceneRouter")
	if pc.active_pet == null:
		pc.debug_adopt_blob("Mochi")
	# force sleep
	pc.active_pet.start_sleep(Time.get_unix_time_from_system())
	router.go("habitat", "from_town")
	for i in 20: await process_frame
	var hab = current_scene
	# open menu
	if hab and hab.has_method("_open_care_menu"):
		# place human near pet
		var human = null
		var pet = null
		for n in hab.get_children():
			pass
		# find via groups - use recursive
		human = _find(hab, true, false)
		pet = _find(hab, false, true)
		if human and pet:
			human.global_position = pet.global_position + Vector2(-28, 8)
		for i in 5: await process_frame
		hab.call("_open_care_menu")
		for i in 8: await process_frame
	var img = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest_nav"))
	img.save_png("user://playtest_nav/ux_sleep_menu.png")
	print("saved sleep menu")
	quit(0)
func _find(n, player, is_pet):
	if n.get("is_player_controlled") == true and player:
		return n
	if n.get("is_pet") == true and is_pet and n.get("is_player_controlled") != true:
		return n
	for c in n.get_children():
		var r = _find(c, player, is_pet)
		if r: return r
	return null
