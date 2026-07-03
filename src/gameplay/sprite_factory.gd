extends RefCounted
## Loads hand-authored 32x32 overworld PNGs (Pokemon-readable silhouettes).


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
	# Care actions: reuse down-facing frames with slight variation via idle/walk
	for action in ["feed", "play", "clean", "sleep", "wake", "dig"]:
		sf.add_animation(action)
		sf.set_animation_speed(action, 7.0)
		sf.set_animation_loop(action, false)
		sf.add_frame(action, _load("trainer_down_idle.png"))
		sf.add_frame(action, _load("trainer_down_walk1.png"))
		sf.add_frame(action, _load("trainer_down_walk2.png"))
		sf.add_frame(action, _load("trainer_down_idle.png"))
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
	for anim in ["idle", "hungry", "weak", "happy", "sad", "sleep", "eat", "play", "dead", "walk"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 5.0 if anim != "dead" else 1.0)
		sf.set_animation_loop(anim, anim not in ["dead", "eat"])
		var file_anim: String = anim
		# map missing variants to exported PNGs
		if anim == "sad" or anim == "hungry":
			file_anim = "hungry"
		elif anim == "weak":
			file_anim = "weak"
		elif anim == "eat" or anim == "play" or anim == "happy":
			file_anim = "happy"
		elif anim == "walk" or anim == "idle":
			file_anim = "idle"
		elif anim == "sleep":
			file_anim = "sleep"
		elif anim == "dead":
			file_anim = "dead"
		else:
			file_anim = "idle"
		var n := 1 if anim == "dead" else 2
		for i in n:
			var path := "%s_%s_%d.png" % [prefix, file_anim, i]
			if not ResourceLoader.exists("res://assets/sprites/" + path) and not FileAccess.file_exists("res://assets/sprites/" + path):
				# fallback idle
				path = "%s_idle_%d.png" % [prefix, i % 2]
			sf.add_frame(anim, _load(path))
	return sf


static func make_tile(kind: String) -> Texture2D:
	# Prefer procedural tiles still (small)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	match kind:
		"grass":
			for y in 16:
				for x in 16:
					var base := Color("48A838") if ((x / 2) + (y / 2)) % 2 == 0 else Color("3D9030")
					img.set_pixel(x, y, base)
			for t in [[2, 3], [9, 2], [5, 10], [12, 8], [3, 13], [14, 12]]:
				img.set_pixel(t[0], t[1], Color("5BC448"))
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
	# FileAccess fallback for first import
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			return ImageTexture.create_from_image(img)
	# transparent 32x32 fallback
	var blank := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	blank.fill(Color(1, 0, 1, 0.5))
	return ImageTexture.create_from_image(blank)
