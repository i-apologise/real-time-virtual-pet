extends RefCounted
## Builds simple pixel-style SpriteFrames at runtime (no external art pipeline).
## Call static methods via preload("res://src/gameplay/sprite_factory.gd").


static func human_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_dir_walk_idle(sf, Color(0.96, 0.82, 0.7), Color(0.25, 0.45, 0.85), Color(0.35, 0.28, 0.22))
	for action in ["feed", "play", "clean", "sleep", "wake", "dig"]:
		sf.add_animation(action)
		sf.set_animation_speed(action, 8.0)
		sf.set_animation_loop(action, false)
		for i in 4:
			sf.add_frame(action, _tex(_draw_human_action(action, i)))
	return sf


static func pet_frames(species_id: String) -> SpriteFrames:
	var body: Color
	match species_id:
		"pup":
			body = Color(0.95, 0.7, 0.4)
		"owl":
			body = Color(0.55, 0.45, 0.85)
		_:
			body = Color(0.45, 0.8, 0.7)
	var sf := SpriteFrames.new()
	for anim in ["idle", "happy", "sad", "sleep", "eat", "play", "dead", "walk"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 6.0 if anim != "dead" else 1.0)
		sf.set_animation_loop(anim, anim != "dead" and anim != "eat")
		var n := 4 if anim != "dead" else 1
		for i in n:
			sf.add_frame(anim, _tex(_draw_pet(body, anim, i)))
	return sf


static func _add_dir_walk_idle(sf: SpriteFrames, skin: Color, shirt: Color, hair: Color) -> void:
	for dir in ["down", "up", "left", "right"]:
		var idle := "idle_%s" % dir
		var walk := "walk_%s" % dir
		sf.add_animation(idle)
		sf.add_animation(walk)
		sf.set_animation_speed(idle, 4.0)
		sf.set_animation_speed(walk, 10.0)
		sf.set_animation_loop(idle, true)
		sf.set_animation_loop(walk, true)
		sf.add_frame(idle, _tex(_draw_human(skin, shirt, hair, dir, 0, false)))
		for step in 4:
			sf.add_frame(walk, _tex(_draw_human(skin, shirt, hair, dir, step, true)))


static func _tex(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)


static func _draw_human(skin: Color, shirt: Color, hair: Color, dir: String, step: int, walking: bool) -> Image:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var leg_off := 0
	if walking:
		leg_off = (1 if step % 2 == 0 else -1) * 2
	# shadow
	_fill_rect(img, 8, 42, 16, 4, Color(0, 0, 0, 0.25))
	# legs
	_fill_rect(img, 10, 30 + leg_off, 5, 12, Color(0.2, 0.22, 0.35))
	_fill_rect(img, 17, 30 - leg_off, 5, 12, Color(0.2, 0.22, 0.35))
	# body
	_fill_rect(img, 9, 16, 14, 16, shirt)
	# head
	_fill_rect(img, 10, 4, 12, 12, skin)
	_fill_rect(img, 10, 2, 12, 5, hair)
	# face dots by direction
	match dir:
		"left":
			_fill_rect(img, 12, 9, 2, 2, Color(0.1, 0.1, 0.12))
		"right":
			_fill_rect(img, 18, 9, 2, 2, Color(0.1, 0.1, 0.12))
		"up":
			pass
		_:
			_fill_rect(img, 13, 9, 2, 2, Color(0.1, 0.1, 0.12))
			_fill_rect(img, 17, 9, 2, 2, Color(0.1, 0.1, 0.12))
	# arms swing when walking
	if walking:
		var arm_y := 18 + leg_off
		_fill_rect(img, 6, arm_y, 4, 10, skin)
		_fill_rect(img, 22, 18 - leg_off, 4, 10, skin)
	else:
		_fill_rect(img, 6, 18, 4, 10, skin)
		_fill_rect(img, 22, 18, 4, 10, skin)
	return img


static func _draw_human_action(action: String, frame: int) -> Image:
	var img := _draw_human(
		Color(0.96, 0.82, 0.7), Color(0.25, 0.45, 0.85), Color(0.35, 0.28, 0.22), "down", frame, false
	)
	# prop / pose overlay
	match action:
		"feed":
			_fill_rect(img, 20, 22 - frame, 8, 6, Color(0.9, 0.85, 0.5))  # bowl
		"play":
			_fill_rect(img, 22, 14 + frame, 6, 6, Color(1.0, 0.4, 0.3))  # ball
		"clean":
			_fill_rect(img, 4, 14 + frame, 6, 10, Color(0.7, 0.9, 1.0))  # brush
		"sleep", "wake":
			_fill_rect(img, 22, 6, 6, 4, Color(1, 1, 1, 0.8 if frame % 2 == 0 else 0.3))
		"dig":
			_fill_rect(img, 22, 20 + frame, 4, 14, Color(0.5, 0.4, 0.3))  # shovel
	return img


static func _draw_pet(body: Color, anim: String, frame: int) -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bob := 0
	if anim == "idle" or anim == "walk" or anim == "happy" or anim == "play":
		bob = (frame % 2) * 2
	if anim == "sleep":
		bob = 2
	if anim == "dead":
		# flat on side
		_fill_rect(img, 4, 16, 24, 10, body.darkened(0.35))
		_fill_rect(img, 8, 18, 3, 3, Color(0.1, 0.1, 0.1))
		_fill_rect(img, 20, 18, 3, 3, Color(0.1, 0.1, 0.1))
		return img
	_fill_rect(img, 6, 8 + bob, 4, 4, Color(0, 0, 0, 0.2))  # soft shadow top
	_fill_rect(img, 4, 10 + bob, 24, 18, body)
	# ears for pup
	if body.r > 0.8:
		_fill_rect(img, 6, 6 + bob, 6, 6, body.darkened(0.1))
		_fill_rect(img, 20, 6 + bob, 6, 6, body.darkened(0.1))
	# eyes
	var eye_c := Color(0.08, 0.08, 0.1)
	if anim == "sleep":
		_fill_rect(img, 10, 16 + bob, 4, 2, eye_c)
		_fill_rect(img, 18, 16 + bob, 4, 2, eye_c)
	elif anim == "sad" or anim == "eat" and frame > 1:
		_fill_rect(img, 11, 15 + bob, 3, 3, eye_c)
		_fill_rect(img, 18, 15 + bob, 3, 3, eye_c)
	else:
		_fill_rect(img, 11, 14 + bob, 3, 4, eye_c)
		_fill_rect(img, 18, 14 + bob, 3, 4, eye_c)
	if anim == "happy" or anim == "play":
		_fill_rect(img, 14, 20 + bob, 4, 2, Color(0.2, 0.1, 0.1))  # smile
	if anim == "eat":
		_fill_rect(img, 13, 20 + bob + (frame % 2), 6, 3, Color(0.15, 0.1, 0.1))
	return img


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)
