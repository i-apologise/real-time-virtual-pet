extends RefCounted
## GBA/Pokemon-inspired top-down pixel frames (nearest-neighbor).


static func human_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_dir_walk_idle(sf)
	for action in ["feed", "play", "clean", "sleep", "wake", "dig"]:
		sf.add_animation(action)
		sf.set_animation_speed(action, 8.0)
		sf.set_animation_loop(action, false)
		for i in 4:
			sf.add_frame(action, _tex(_draw_human_action(action, i)))
	return sf


static func pet_frames(species_id: String) -> SpriteFrames:
	var body: Color
	var accent: Color
	match species_id:
		"pup":
			body = Color("E8A45A")
			accent = Color("C47A3A")
		"owl":
			body = Color("7B6BB5")
			accent = Color("4A3D7A")
		_:
			body = Color("5FCFB0")
			accent = Color("2E8B73")
	var sf := SpriteFrames.new()
	for anim in ["idle", "hungry", "weak", "happy", "sad", "sleep", "eat", "play", "dead", "walk"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 5.0 if anim != "dead" else 1.0)
		sf.set_animation_loop(anim, anim not in ["dead", "eat"])
		var n := 1 if anim == "dead" else 4
		for i in n:
			sf.add_frame(anim, _tex(_draw_pet(body, accent, anim, i)))
	return sf


static func make_tile(kind: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	match kind:
		"grass":
			img.fill(Color("5DBB4A"))
			for i in 12:
				var px := (i * 7) % 16
				var py := (i * 11) % 16
				img.set_pixel(px, py, Color("4AA338"))
				img.set_pixel((px + 1) % 16, py, Color("6ED655"))
		"path":
			img.fill(Color("C9B896"))
			for i in 8:
				img.set_pixel(i * 2, i, Color("B8A57E"))
		"floor":
			img.fill(Color("D4B896"))
			for x in 16:
				img.set_pixel(x, 0, Color("C4A882"))
				img.set_pixel(x, 15, Color("C4A882"))
		"wall":
			img.fill(Color("E8DCC8"))
			for y in 16:
				img.set_pixel(0, y, Color("D0C4B0"))
		_:
			img.fill(Color.MAGENTA)
	return ImageTexture.create_from_image(img)


static func _tex(img: Image) -> Texture2D:
	var t := ImageTexture.create_from_image(img)
	return t


static func _add_dir_walk_idle(sf: SpriteFrames) -> void:
	for dir in ["down", "up", "left", "right"]:
		var idle := "idle_%s" % dir
		var walk := "walk_%s" % dir
		sf.add_animation(idle)
		sf.add_animation(walk)
		sf.set_animation_speed(idle, 3.0)
		sf.set_animation_speed(walk, 9.0)
		sf.set_animation_loop(idle, true)
		sf.set_animation_loop(walk, true)
		sf.add_frame(idle, _tex(_draw_trainer(dir, 0, false)))
		for step in 4:
			sf.add_frame(walk, _tex(_draw_trainer(dir, step, true)))


## Classic top-down trainer silhouette (Pokemon gen-ish proportions).
static func _draw_trainer(dir: String, step: int, walking: bool) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color("F1C27D")
	var hair := Color("3D2914")
	var shirt := Color("3B6EA5")
	var pants := Color("2C3E50")
	var shoes := Color("1A1A1A")
	var leg := 0
	if walking:
		leg = 1 if step % 2 == 0 else -1
	# shadow
	_ellipse(img, 8, 22, 5, 2, Color(0, 0, 0, 0.22))
	# shoes/legs
	_fill(img, 5, 17 + leg, 3, 5, pants)
	_fill(img, 9, 17 - leg, 3, 5, pants)
	_fill(img, 5, 21 + leg, 3, 2, shoes)
	_fill(img, 9, 21 - leg, 3, 2, shoes)
	# torso
	_fill(img, 4, 10, 8, 8, shirt)
	# head
	_fill(img, 5, 3, 6, 7, skin)
	_fill(img, 4, 2, 8, 3, hair)
	# cap brim
	_fill(img, 4, 4, 8, 2, Color("C0392B"))
	# face
	match dir:
		"left":
			_fill(img, 6, 7, 1, 1, Color("1A1A1A"))
		"right":
			_fill(img, 9, 7, 1, 1, Color("1A1A1A"))
		"up":
			pass
		_:
			_fill(img, 6, 7, 1, 1, Color("1A1A1A"))
			_fill(img, 9, 7, 1, 1, Color("1A1A1A"))
	# arms
	var ay := 11 + (leg if walking else 0)
	_fill(img, 2, ay, 2, 5, skin)
	_fill(img, 12, 11 - (leg if walking else 0), 2, 5, skin)
	return img


static func _draw_human_action(action: String, frame: int) -> Image:
	var img := _draw_trainer("down", frame, false)
	match action:
		"feed":
			_fill(img, 11, 14 - frame % 2, 4, 3, Color("F5D76E"))
		"play":
			_fill(img, 12, 8 + frame % 3, 3, 3, Color("E74C3C"))
		"clean":
			_fill(img, 1, 9 + frame % 2, 3, 5, Color("AED6F1"))
		"sleep", "wake":
			_fill(img, 12, 2, 3, 2, Color(1, 1, 1, 0.7 if frame % 2 == 0 else 0.25))
		"dig":
			_fill(img, 12, 12 + frame % 2, 2, 7, Color("8B6914"))
	return img


## Creature body changes with condition: thin/pale when hungry, slump when weak.
static func _draw_pet(body: Color, accent: Color, anim: String, frame: int) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bob := 0
	if anim in ["idle", "walk", "happy", "play"]:
		bob = frame % 2
	var thin := anim in ["hungry", "weak", "critical"] or anim == "sad"
	var w := 8 if thin else 10
	var h := 7 if anim == "weak" else (8 if thin else 9)
	var ox := 8 - w / 2
	var oy := 5 + bob + (2 if anim == "weak" else 0)

	if anim == "dead":
		_ellipse(img, 8, 11, 7, 4, body.darkened(0.35))
		_fill(img, 5, 10, 2, 2, Color("1A1A1A"))
		_fill(img, 10, 10, 2, 2, Color("1A1A1A"))
		_fill(img, 7, 12, 3, 1, Color("5D4E37"))
		return img

	# shadow
	_ellipse(img, 8, 14, 5, 2, Color(0, 0, 0, 0.2))
	# body
	var col := body
	if anim == "hungry":
		col = body.lerp(Color("C4B59A"), 0.35)
	elif anim == "weak":
		col = body.lerp(Color("A08080"), 0.45).darkened(0.1)
	_ellipse(img, 8, oy + h / 2, w / 2 + 1, h / 2 + 1, col)
	# belly (smaller when hungry = looks gaunt)
	if not thin:
		_ellipse(img, 8, oy + h / 2 + 1, 3, 2, col.lightened(0.15))
	# ears/cheeks species accent
	_fill(img, ox, oy + 1, 2, 2, accent)
	_fill(img, ox + w - 2, oy + 1, 2, 2, accent)
	# eyes — tired when hungry/weak
	if anim == "sleep":
		_fill(img, 5, oy + 3, 2, 1, Color("1A1A1A"))
		_fill(img, 9, oy + 3, 2, 1, Color("1A1A1A"))
	elif anim == "weak" or anim == "hungry":
		_fill(img, 5, oy + 3, 2, 1, Color("1A1A1A"))  # half-lid
		_fill(img, 9, oy + 3, 2, 1, Color("1A1A1A"))
		# sweat drop when weak
		if anim == "weak" and frame % 2 == 0:
			_fill(img, 12, oy, 1, 2, Color("85C1E9"))
	elif anim == "sad":
		_fill(img, 5, oy + 4, 2, 2, Color("1A1A1A"))
		_fill(img, 9, oy + 4, 2, 2, Color("1A1A1A"))
	else:
		_fill(img, 5, oy + 3, 2, 2, Color("1A1A1A"))
		_fill(img, 9, oy + 3, 2, 2, Color("1A1A1A"))
		if anim == "happy" or anim == "play":
			_fill(img, 6, oy + 6, 4, 1, Color("5D3A3A"))
	if anim == "eat":
		_fill(img, 6, oy + 6 + frame % 2, 4, 2, Color("3D2914"))
	# ribs lines when starving weak
	if anim == "weak":
		_fill(img, 6, oy + 5, 4, 1, col.darkened(0.2))
		_fill(img, 6, oy + 7, 4, 1, col.darkened(0.2))
	return img


static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for py in range(cy - ry, cy + ry + 1):
		for px in range(cx - rx, cx + rx + 1):
			var dx := float(px - cx) / float(maxi(rx, 1))
			var dy := float(py - cy) / float(maxi(ry, 1))
			if dx * dx + dy * dy <= 1.0:
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, c)
