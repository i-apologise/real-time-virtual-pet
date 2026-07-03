extends RefCounted
## Loads 32x32 overworld PNGs (trainer, pets, action poses, dead states).


static func human_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for dir in ["down", "up", "left", "right"]:
		var idle := "idle_%s" % dir
		var walk := "walk_%s" % dir
		sf.add_animation(idle)
		sf.add_animation(walk)
		sf.set_animation_speed(idle, 2.0)
		sf.set_animation_speed(walk, 8.0)
		sf.set_animation_loop(idle, true)
		sf.set_animation_loop(walk, true)
		sf.add_frame(idle, _load("trainer_%s_idle.png" % dir))
		sf.add_frame(walk, _load("trainer_%s_walk1.png" % dir))
		sf.add_frame(walk, _load("trainer_%s_idle.png" % dir))
		sf.add_frame(walk, _load("trainer_%s_walk2.png" % dir))
		sf.add_frame(walk, _load("trainer_%s_idle.png" % dir))
	for action in ["feed", "play", "clean", "sleep", "wake", "dig"]:
		sf.add_animation(action)
		sf.set_animation_speed(action, 8.0)
		sf.set_animation_loop(action, false)
		for i in 4:
			var path := "trainer_act_%s_%d.png" % [action, i]
			if action == "walk":
				path = "trainer_act_play_%d.png" % i
			sf.add_frame(action, _load(path))
	# walk care uses play anim on human
	if not sf.has_animation("walk_care"):
		sf.add_animation("walk_care")
		sf.set_animation_speed("walk_care", 8.0)
		sf.set_animation_loop("walk_care", false)
		for i in 4:
			sf.add_frame("walk_care", _load("trainer_act_play_%d.png" % i))
	return sf


static func pet_frames(species_id: String) -> SpriteFrames:
	var prefix := "slime"
	match species_id:
		"pup":
			prefix = "puppy"
		"owl":
			prefix = "owl"
		_:
			prefix = "slime"
	var sf := SpriteFrames.new()
	for anim in ["idle", "hungry", "weak", "happy", "sad", "sleep", "eat", "play", "dead", "walk", "clean"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 6.0 if anim != "dead" else 1.0)
		sf.set_animation_loop(anim, anim not in ["dead", "eat", "clean", "play"])
		if anim == "dead":
			sf.add_frame(anim, _load("%s_dead_0.png" % prefix))
			continue
		# action-specific slime frames when available
		if prefix == "slime" and anim in ["eat", "play", "clean", "sleep"]:
			for i in 4:
				sf.add_frame(anim, _load("slime_act_%s_%d.png" % [anim, i]))
			continue
		var file_anim: String = anim
		if anim == "sad":
			file_anim = "hungry"
		elif anim in ["eat", "play", "happy", "clean"]:
			file_anim = "happy" if anim != "clean" else "idle"
		elif anim in ["walk", "idle"]:
			file_anim = "idle"
		elif anim == "sleep":
			file_anim = "sleep"
		elif anim == "weak":
			file_anim = "weak"
		elif anim == "hungry":
			file_anim = "hungry"
		else:
			file_anim = "idle"
		for i in 2:
			sf.add_frame(anim, _load("%s_%s_%d.png" % [prefix, file_anim, i]))
	return sf


static func make_tile(kind: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	match kind:
		"grass":
			for y in 16:
				for x in 16:
					var base := Color("48A838") if ((x / 2) + (y / 2)) % 2 == 0 else Color("3D9030")
					img.set_pixel(x, y, base)
		"path":
			for y in 16:
				for x in 16:
					img.set_pixel(x, y, Color("D8C898") if (x + y) % 3 != 0 else Color("C8B888"))
		"floor":
			for y in 16:
				for x in 16:
					img.set_pixel(x, y, Color("E0C8A0") if (x / 4 + y / 4) % 2 == 0 else Color("D4BC94"))
		"wall":
			img.fill(Color("F0E0C8"))
		_:
			img.fill(Color.MAGENTA)
	return ImageTexture.create_from_image(img)


static func _load(filename: String) -> Texture2D:
	var path := "res://assets/sprites/%s" % filename
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			return tex
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	var blank := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	blank.fill(Color(1, 0, 1, 0.4))
	return ImageTexture.create_from_image(blank)
