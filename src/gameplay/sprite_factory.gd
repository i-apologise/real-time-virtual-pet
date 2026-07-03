extends RefCounted
## Pokemon Red/Blue-style 16x16 overworld sprites (nearest-neighbor).
## Clear silhouettes: trainer, slime, puppy, owl — readable at a glance.


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
		sf.add_frame(idle, _tex(_trainer(dir, 0)))
		sf.add_frame(walk, _tex(_trainer(dir, 1)))
		sf.add_frame(walk, _tex(_trainer(dir, 0)))
		sf.add_frame(walk, _tex(_trainer(dir, 2)))
		sf.add_frame(walk, _tex(_trainer(dir, 0)))
	for action in ["feed", "play", "clean", "sleep", "wake", "dig"]:
		sf.add_animation(action)
		sf.set_animation_speed(action, 7.0)
		sf.set_animation_loop(action, false)
		for i in 4:
			sf.add_frame(action, _tex(_trainer_action(action, i)))
	return sf


static func pet_frames(species_id: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for anim in ["idle", "hungry", "weak", "happy", "sad", "sleep", "eat", "play", "dead", "walk"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 5.0 if anim != "dead" else 1.0)
		sf.set_animation_loop(anim, anim not in ["dead", "eat"])
		var n := 1 if anim == "dead" else 4
		for i in n:
			var img: Image
			match species_id:
				"pup":
					img = _puppy(anim, i)
				"owl":
					img = _owl(anim, i)
				_:
					img = _slime(anim, i)
			sf.add_frame(anim, _tex(img))
	return sf


static func make_tile(kind: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	match kind:
		"grass":
			# Classic overworld grass: two-tone checker with tufts
			for y in 16:
				for x in 16:
					var base := Color("48A838") if ((x / 2) + (y / 2)) % 2 == 0 else Color("3D9030")
					img.set_pixel(x, y, base)
			# tufts
			for t in [[2, 3], [9, 2], [5, 10], [12, 8], [3, 13], [14, 12]]:
				img.set_pixel(t[0], t[1], Color("5BC448"))
				img.set_pixel(t[0], t[1] + 1, Color("2E701F"))
		"path":
			for y in 16:
				for x in 16:
					img.set_pixel(x, y, Color("D8C898") if (x + y) % 3 != 0 else Color("C8B888"))
			# edge darker
			for i in 16:
				img.set_pixel(i, 0, Color("B8A070"))
				img.set_pixel(i, 15, Color("B8A070"))
		"floor":
			for y in 16:
				for x in 16:
					img.set_pixel(x, y, Color("E0C8A0") if (x / 4 + y / 4) % 2 == 0 else Color("D4BC94"))
		"wall":
			img.fill(Color("F0E0C8"))
			for x in 16:
				img.set_pixel(x, 15, Color("C8B090"))
				img.set_pixel(x, 0, Color("FFF8E8"))
		_:
			img.fill(Color.MAGENTA)
	return ImageTexture.create_from_image(img)


static func _tex(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)


# --- colors (SNES/GBC friendly palette) ---
const C_OUT := Color("101010")
const C_SKIN := Color("F8D0A0")
const C_SKIN_S := Color("E0A878")
const C_HAIR := Color("503018")
const C_CAP := Color("E03030")
const C_CAP_D := Color("A01818")
const C_SHIRT := Color("3068C8")
const C_SHIRT_S := Color("2048A0")
const C_PANTS := Color("284060")
const C_SHOE := Color("202020")
const C_WHITE := Color("F8F8F8")


## Pokemon-style 16x16 trainer (Red/Blue overworld readable).
## step: 0 idle, 1 left foot, 2 right foot
static func _trainer(dir: String, step: int) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# soft ground shadow (not full block)
	_p(img, 5, 14, Color(0, 0, 0, 0.25))
	_p(img, 6, 14, Color(0, 0, 0, 0.3))
	_p(img, 7, 14, Color(0, 0, 0, 0.3))
	_p(img, 8, 14, Color(0, 0, 0, 0.3))
	_p(img, 9, 14, Color(0, 0, 0, 0.3))
	_p(img, 10, 14, Color(0, 0, 0, 0.25))

	match dir:
		"down":
			_trainer_down(img, step)
		"up":
			_trainer_up(img, step)
		"left":
			_trainer_left(img, step)
		"right":
			_trainer_right(img, step)
	return img


static func _trainer_down(img: Image, step: int) -> void:
	# cap
	_rect(img, 4, 1, 8, 2, C_CAP)
	_rect(img, 3, 2, 10, 1, C_CAP)
	_rect(img, 5, 0, 6, 1, C_CAP_D)  # top
	# face
	_rect(img, 5, 3, 6, 4, C_SKIN)
	_p(img, 6, 4, C_OUT)  # eyes
	_p(img, 9, 4, C_OUT)
	_p(img, 7, 6, C_SKIN_S)  # nose shade
	# hair sides under cap
	_p(img, 4, 3, C_HAIR)
	_p(img, 11, 3, C_HAIR)
	# torso
	_rect(img, 4, 7, 8, 4, C_SHIRT)
	_rect(img, 5, 7, 6, 1, C_SHIRT_S)
	# arms
	_rect(img, 2, 8, 2, 3, C_SKIN)
	_rect(img, 12, 8, 2, 3, C_SKIN)
	_p(img, 2, 8, C_OUT)
	_p(img, 13, 8, C_OUT)
	# legs
	var lo := 0
	var ro := 0
	if step == 1:
		lo = 1
	elif step == 2:
		ro = 1
	_rect(img, 5, 11, 2, 3 + lo, C_PANTS)
	_rect(img, 9, 11, 2, 3 + ro, C_PANTS)
	_rect(img, 5, 13 + lo, 2, 1, C_SHOE)
	_rect(img, 9, 13 + ro, 2, 1, C_SHOE)
	# outline key edges
	_outline_silhouette(img)


static func _trainer_up(img: Image, step: int) -> void:
	_rect(img, 4, 1, 8, 2, C_CAP)
	_rect(img, 3, 2, 10, 1, C_CAP)
	_rect(img, 5, 0, 6, 1, C_CAP_D)
	# back of head hair
	_rect(img, 5, 3, 6, 3, C_HAIR)
	_rect(img, 4, 7, 8, 4, C_SHIRT)
	_rect(img, 2, 8, 2, 3, C_SKIN)
	_rect(img, 12, 8, 2, 3, C_SKIN)
	var lo := 1 if step == 1 else 0
	var ro := 1 if step == 2 else 0
	_rect(img, 5, 11, 2, 3 + lo, C_PANTS)
	_rect(img, 9, 11, 2, 3 + ro, C_PANTS)
	_rect(img, 5, 13 + lo, 2, 1, C_SHOE)
	_rect(img, 9, 13 + ro, 2, 1, C_SHOE)
	_outline_silhouette(img)


static func _trainer_left(img: Image, step: int) -> void:
	_rect(img, 4, 1, 7, 2, C_CAP)
	_rect(img, 3, 2, 8, 1, C_CAP)
	_rect(img, 5, 0, 5, 1, C_CAP_D)
	_rect(img, 4, 3, 5, 4, C_SKIN)
	_p(img, 5, 4, C_OUT)  # eye
	_p(img, 4, 3, C_HAIR)
	_rect(img, 5, 7, 5, 4, C_SHIRT)
	# front arm
	var arm_y := 8 + (1 if step == 1 else 0)
	_rect(img, 3, arm_y, 2, 3, C_SKIN)
	var leg := 1 if step != 0 else 0
	_rect(img, 6, 11, 2, 3 + leg, C_PANTS)
	_rect(img, 8, 11, 2, 3 - leg, C_PANTS)
	_rect(img, 6, 13 + leg, 2, 1, C_SHOE)
	_rect(img, 8, 13 - leg, 2, 1, C_SHOE)
	_outline_silhouette(img)


static func _trainer_right(img: Image, step: int) -> void:
	# mirror left by drawing right-facing
	_rect(img, 5, 1, 7, 2, C_CAP)
	_rect(img, 5, 2, 8, 1, C_CAP)
	_rect(img, 6, 0, 5, 1, C_CAP_D)
	_rect(img, 7, 3, 5, 4, C_SKIN)
	_p(img, 10, 4, C_OUT)
	_p(img, 11, 3, C_HAIR)
	_rect(img, 6, 7, 5, 4, C_SHIRT)
	var arm_y := 8 + (1 if step == 1 else 0)
	_rect(img, 11, arm_y, 2, 3, C_SKIN)
	var leg := 1 if step != 0 else 0
	_rect(img, 8, 11, 2, 3 + leg, C_PANTS)
	_rect(img, 6, 11, 2, 3 - leg, C_PANTS)
	_rect(img, 8, 13 + leg, 2, 1, C_SHOE)
	_rect(img, 6, 13 - leg, 2, 1, C_SHOE)
	_outline_silhouette(img)


static func _trainer_action(action: String, frame: int) -> Image:
	var img := _trainer("down", frame % 3)
	match action:
		"feed":
			# bowl in hands
			_rect(img, 9, 9 - frame % 2, 5, 3, Color("E8D060"))
			_rect(img, 10, 10 - frame % 2, 3, 1, Color("C8A040"))
			_p(img, 9, 9 - frame % 2, C_OUT)
		"play":
			# pokeball-like toy
			_rect(img, 11, 6 + frame % 3, 3, 3, Color("E03030"))
			_p(img, 12, 7 + frame % 3, C_WHITE)
			_p(img, 11, 6 + frame % 3, C_OUT)
		"clean":
			_rect(img, 1, 7 + frame % 2, 3, 5, Color("90D0F0"))
			_rect(img, 1, 6 + frame % 2, 3, 1, Color("F0F0F0"))
		"sleep", "wake":
			_p(img, 12, 2, C_WHITE)
			_p(img, 13, 1, C_WHITE)
			if frame % 2 == 0:
				_p(img, 14, 2, C_WHITE)
		"dig":
			_rect(img, 12, 8 + frame % 2, 2, 6, Color("8B6914"))
			_rect(img, 11, 13 + frame % 2, 4, 2, Color("606060"))
	return img


## Classic RPG green slime — round, shine, face (readable as a creature).
static func _slime(anim: String, frame: int) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bob := frame % 2 if anim in ["idle", "walk", "happy", "play"] else 0
	var body := Color("40C878")
	var body_d := Color("209050")
	var body_l := Color("70F0A0")
	if anim == "hungry":
		body = Color("88B070")
		body_d = Color("608050")
		body_l = Color("A0C890")
		bob = 0
	elif anim == "weak":
		body = Color("A09080")
		body_d = Color("706050")
		body_l = Color("C0B0A0")
		bob = 1
	elif anim == "dead":
		# flattened puddle
		_rect(img, 2, 10, 12, 4, Color("306848"))
		_rect(img, 3, 11, 10, 2, Color("40C878").darkened(0.4))
		_p(img, 5, 11, C_OUT)
		_p(img, 10, 11, C_OUT)
		_p(img, 7, 12, Color("503020"))
		_outline_silhouette(img)
		return img

	# shadow
	_rect(img, 4, 13, 8, 2, Color(0, 0, 0, 0.2))
	# body blob (dome)
	var y0 := 4 + bob
	_rect(img, 4, y0 + 2, 8, 7, body)
	_rect(img, 3, y0 + 3, 10, 5, body)
	_rect(img, 5, y0 + 1, 6, 1, body)
	_rect(img, 6, y0, 4, 1, body)
	# shade bottom
	_rect(img, 4, y0 + 7, 8, 2, body_d)
	# highlight (classic slime shine)
	if anim != "weak":
		_p(img, 6, y0 + 2, body_l)
		_p(img, 7, y0 + 2, body_l)
		_p(img, 6, y0 + 3, body_l)
	# eyes
	if anim == "sleep":
		_rect(img, 5, y0 + 4, 2, 1, C_OUT)
		_rect(img, 9, y0 + 4, 2, 1, C_OUT)
	elif anim == "weak" or anim == "hungry":
		_rect(img, 5, y0 + 4, 2, 1, C_OUT)  # half closed
		_rect(img, 9, y0 + 4, 2, 1, C_OUT)
		if anim == "weak":
			_p(img, 12, y0 + 2, Color("80C0F0"))  # sweat
	elif anim == "sad":
		_p(img, 5, y0 + 5, C_OUT)
		_p(img, 6, y0 + 4, C_OUT)
		_p(img, 9, y0 + 4, C_OUT)
		_p(img, 10, y0 + 5, C_OUT)
	else:
		_rect(img, 5, y0 + 3, 2, 3, C_OUT)
		_rect(img, 9, y0 + 3, 2, 3, C_OUT)
		_p(img, 5, y0 + 3, C_WHITE)  # eye shine
		_p(img, 9, y0 + 3, C_WHITE)
	# mouth
	if anim == "happy" or anim == "play":
		_rect(img, 7, y0 + 7, 2, 1, Color("803020"))
	elif anim == "eat":
		_rect(img, 6, y0 + 6 + frame % 2, 4, 2, Color("602010"))
	elif anim == "weak":
		# rib-like indent
		_p(img, 6, y0 + 6, body_d)
		_p(img, 9, y0 + 6, body_d)
	_outline_silhouette(img)
	return img


## Small dog — ears, snout, tail, legs (readable as a puppy).
static func _puppy(anim: String, frame: int) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fur := Color("E8A858")
	var fur_d := Color("C07830")
	var fur_l := Color("F8D090")
	var bob := frame % 2 if anim in ["idle", "walk", "happy", "play"] else 0
	if anim == "hungry":
		fur = Color("C8A878")
		fur_d = Color("A08050")
	elif anim == "weak":
		fur = Color("B09080")
		fur_d = Color("806050")
		bob = 1
	elif anim == "dead":
		_rect(img, 2, 9, 11, 4, fur.darkened(0.35))
		_rect(img, 12, 10, 3, 2, fur_d)  # tail
		_p(img, 4, 10, C_OUT)
		_p(img, 8, 10, C_OUT)
		_outline_silhouette(img)
		return img

	_rect(img, 4, 13, 7, 2, Color(0, 0, 0, 0.2))
	var y := 5 + bob
	# body
	_rect(img, 4, y + 3, 8, 5, fur)
	_rect(img, 5, y + 2, 6, 1, fur)
	# head
	_rect(img, 3, y, 7, 5, fur)
	# ears (pointy)
	_rect(img, 3, y - 2, 2, 3, fur_d)
	_rect(img, 8, y - 2, 2, 3, fur_d)
	_p(img, 3, y - 2, C_OUT)
	_p(img, 9, y - 2, C_OUT)
	# snout
	_rect(img, 4, y + 3, 4, 2, fur_l)
	_p(img, 5, y + 4, C_OUT)  # nose
	# eyes
	if anim == "sleep":
		_rect(img, 4, y + 2, 2, 1, C_OUT)
		_rect(img, 7, y + 2, 2, 1, C_OUT)
	elif anim in ["hungry", "weak"]:
		_rect(img, 4, y + 2, 2, 1, C_OUT)
		_rect(img, 7, y + 2, 2, 1, C_OUT)
	else:
		_rect(img, 4, y + 1, 2, 2, C_OUT)
		_rect(img, 7, y + 1, 2, 2, C_OUT)
		_p(img, 4, y + 1, C_WHITE)
	# legs
	var leg := 1 if (anim == "walk" or anim == "play") and frame % 2 == 0 else 0
	_rect(img, 5, y + 7, 2, 2 + leg, fur_d)
	_rect(img, 9, y + 7, 2, 2 - leg, fur_d)
	# tail
	var ty := y + 3 - (frame % 2 if anim != "weak" else 0)
	_rect(img, 12, ty, 3, 2, fur)
	if anim == "happy" or anim == "play":
		_rect(img, 12, ty - 1, 2, 1, fur)  # wag up
	if anim == "weak":
		_p(img, 6, y + 5, fur_d)
		_p(img, 8, y + 5, fur_d)
	_outline_silhouette(img)
	return img


## Owl — big head, beak, wing folds (readable bird).
static func _owl(anim: String, frame: int) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var f := Color("7B6BB8")
	var f_d := Color("4A3C80")
	var f_l := Color("A898D8")
	var belly := Color("E8DCC8")
	var bob := frame % 2 if anim in ["idle", "happy", "play"] else 0
	if anim == "hungry":
		f = Color("8A8098")
	elif anim == "weak":
		f = Color("908888")
		f_d = Color("606060")
		bob = 1
	elif anim == "dead":
		_rect(img, 3, 9, 10, 4, f.darkened(0.4))
		_p(img, 6, 10, C_OUT)
		_p(img, 9, 10, C_OUT)
		_outline_silhouette(img)
		return img

	_rect(img, 4, 13, 8, 2, Color(0, 0, 0, 0.2))
	var y := 3 + bob
	# head (large)
	_rect(img, 3, y, 10, 8, f)
	_rect(img, 4, y - 1, 8, 1, f)
	# ear tufts
	_rect(img, 3, y - 2, 2, 3, f_d)
	_rect(img, 11, y - 2, 2, 3, f_d)
	# face disc
	_rect(img, 4, y + 2, 8, 5, f_l)
	# eyes (big — owl signature)
	if anim == "sleep":
		_rect(img, 5, y + 4, 2, 1, C_OUT)
		_rect(img, 9, y + 4, 2, 1, C_OUT)
	elif anim in ["hungry", "weak"]:
		_rect(img, 5, y + 3, 2, 2, C_OUT)
		_rect(img, 9, y + 3, 2, 2, C_OUT)
	else:
		_rect(img, 5, y + 3, 2, 3, C_OUT)
		_rect(img, 9, y + 3, 2, 3, C_OUT)
		_p(img, 5, y + 3, C_WHITE)
		_p(img, 9, y + 3, C_WHITE)
	# beak
	_rect(img, 7, y + 5, 2, 2, Color("E8A020"))
	_p(img, 7, y + 5, Color("C08010"))
	# body/belly
	_rect(img, 5, y + 8, 6, 3, belly)
	# wings
	_rect(img, 2, y + 6, 2, 4, f_d)
	_rect(img, 12, y + 6, 2, 4, f_d)
	# feet
	_rect(img, 6, y + 11, 2, 1, Color("E8A020"))
	_rect(img, 9, y + 11, 2, 1, Color("E8A020"))
	if anim == "weak":
		_p(img, 13, y + 2, Color("80C0F0"))
	_outline_silhouette(img)
	return img


static func _p(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			_p(img, px, py, c)


## Black outline on non-transparent edge pixels (Pokemon-style crisp edge).
static func _outline_silhouette(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var mark: Array = []
	for y in h:
		for x in w:
			var a := img.get_pixel(x, y).a
			if a < 0.1:
				continue
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h or img.get_pixel(nx, ny).a < 0.1:
					mark.append(Vector2i(x, y))
					break
	for v in mark:
		var px: Color = img.get_pixel(v.x, v.y)
		# darken edge toward outline instead of full black fill on whole body
		img.set_pixel(v.x, v.y, px.darkened(0.45).lerp(C_OUT, 0.55))
