extends CharacterBody2D
## Pixel actor with walk-to, care anims, optional pet follow.

signal arrived
signal anim_finished(anim_name: StringName)

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_PET := 4

@export var move_speed: float = 120.0
@export var is_player_controlled: bool = false
@export var is_pet: bool = false

var _sprite: AnimatedSprite2D
var _facing: String = "down"
var _busy: bool = false
var _acting: bool = false
var _walk_target: Variant = null
var _arrive_threshold: float = 12.0
var _collision: CollisionShape2D
var _condition: String = "healthy"
var _follow_target: Node2D = null  # leash follow
var _follow_offset: Vector2 = Vector2(-18, 6)
var _use_world_bounds: bool = false
var _world_bounds: Rect2 = Rect2(20, 20, 440, 280)


func set_world_bounds(rect: Rect2) -> void:
	## Keep actor on-map (camera limits alone do not stop walking off-screen).
	_use_world_bounds = true
	_world_bounds = rect


func clear_world_bounds() -> void:
	_use_world_bounds = false


func _clamp_to_world() -> void:
	if not _use_world_bounds:
		return
	global_position.x = clampf(global_position.x, _world_bounds.position.x, _world_bounds.end.x)
	global_position.y = clampf(global_position.y, _world_bounds.position.y, _world_bounds.end.y)


func setup_collision(as_pet: bool = false) -> void:
	is_pet = as_pet
	if _collision == null:
		_collision = CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 9.0 if as_pet else 9.0
		_collision.shape = shape
		_collision.position = Vector2(0, -2)
		add_child(_collision)
	if as_pet:
		collision_layer = LAYER_PET
		collision_mask = 0
		motion_mode = MOTION_MODE_FLOATING
	else:
		collision_layer = LAYER_PLAYER
		collision_mask = LAYER_WORLD | LAYER_PET


func set_collision_enabled(enabled: bool) -> void:
	if _collision:
		_collision.disabled = not enabled
	if not enabled:
		collision_layer = 0
	elif is_pet:
		collision_layer = LAYER_PET
	else:
		collision_layer = LAYER_PLAYER
		collision_mask = LAYER_WORLD | LAYER_PET


func setup_frames(frames: SpriteFrames, scale_mul: float = 2.0) -> void:
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.position = Vector2(0, -12)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(scale_mul, scale_mul)
	if not _sprite.animation_finished.is_connected(_on_anim_finished):
		_sprite.animation_finished.connect(_on_anim_finished)
	setup_collision(is_pet)
	play_idle()


func set_condition(condition: String) -> void:
	_condition = condition
	if _sprite == null:
		return
	match condition:
		"dead":
			# Art carries the look — keep full color on dead frames
			_sprite.modulate = Color.WHITE
		"sleep", "sleeping":
			_sprite.modulate = Color(0.92, 0.94, 1.0)  # soft cool tint while napping
		"critical", "dying", "weak":
			_sprite.modulate = Color(0.92, 0.72, 0.72)
		"hungry":
			_sprite.modulate = Color(0.95, 0.88, 0.75)
		_:
			_sprite.modulate = Color.WHITE


func set_busy(v: bool, cancel_motion: bool = true) -> void:
	_busy = v
	if v and cancel_motion:
		_walk_target = null
		_follow_target = null
	if not v:
		_acting = false


func set_acting(v: bool) -> void:
	_acting = v
	if not v and _sprite and _sprite.is_playing():
		# leave final pose; director / play_idle will decide next
		pass


func set_follow(target: Node2D, offset: Vector2 = Vector2(-18, 6)) -> void:
	_follow_target = target
	_follow_offset = offset
	_acting = false
	_walk_target = null
	if is_pet and _condition == "dead":
		_play_dead_pose()


func clear_follow() -> void:
	_follow_target = null
	velocity = Vector2.ZERO


func is_busy() -> bool:
	return _busy


func play_idle() -> void:
	if _sprite == null or _acting:
		return
	if is_pet:
		var anim := _pet_idle_anim()
		if _sprite.sprite_frames.has_animation(anim):
			# Sleep / dead always loop as ambient mood
			if String(anim) in ["sleep", "dead"]:
				_sprite.sprite_frames.set_animation_loop(anim, true)
			_sprite.play(anim)
		return
	var anim2 := "idle_%s" % _facing
	if _sprite.sprite_frames.has_animation(anim2):
		_sprite.play(anim2)


func _play_dead_pose() -> void:
	## Force limp/dead art while carried — must not switch to walk/idle.
	if _sprite == null:
		return
	if _sprite.sprite_frames.has_animation(&"dead"):
		_sprite.sprite_frames.set_animation_loop(&"dead", true)
		if _sprite.animation != &"dead":
			_sprite.play(&"dead")
	_acting = false


func _pet_idle_anim() -> StringName:
	match _condition:
		"dead":
			return &"dead"
		"sleep", "sleeping":
			return &"sleep"
		"critical", "dying", "weak":
			return &"weak"
		"hungry":
			return &"hungry"
		_:
			return &"idle"


func play_anim(anim: StringName) -> void:
	if _sprite == null:
		return
	if not _sprite.sprite_frames.has_animation(anim):
		push_warning("Missing anim: %s" % anim)
		return
	# Care actions: play once. Mood loops (sleep/dead/idle…): keep looping.
	var name_s := String(anim)
	var loop_mood := name_s in ["sleep", "dead", "idle", "hungry", "weak", "happy", "sad", "walk"]
	var one_shot := name_s in ["feed", "play", "clean", "wake", "dig", "eat"]
	# Human "sleep" pose during care is one-shot; pet sleep mood loops
	if is_pet and name_s == "sleep":
		one_shot = false
		loop_mood = true
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.sprite_frames.set_animation_loop(anim, loop_mood and not one_shot)
	_acting = one_shot
	_sprite.stop()
	_sprite.play(anim)


func walk_to(world_pos: Vector2) -> void:
	_walk_target = world_pos
	_acting = false
	_follow_target = null


func _on_anim_finished() -> void:
	if _sprite:
		anim_finished.emit(_sprite.animation)


func _physics_process(delta: float) -> void:
	z_index = int(global_position.y)

	# Leash / carry follow mode (pet or escort)
	if _follow_target != null and is_instance_valid(_follow_target):
		var goal: Vector2 = _follow_target.global_position + _follow_offset
		var to: Vector2 = goal - global_position
		var carried_dead := is_pet and _condition == "dead"
		# Body carried limp — slower, never play living walk cycle (looked "alive" on burial path)
		var speed := move_speed * (0.72 if carried_dead else 1.0)
		if to.length() > 6.0:
			var dir := to.normalized()
			velocity = dir * speed
			move_and_slide()
			_clamp_to_world()
			_update_facing(dir)
			if carried_dead:
				_play_dead_pose()
			else:
				var walk := "walk_%s" % _facing
				if is_pet and _sprite and _sprite.sprite_frames.has_animation("walk"):
					if _sprite.animation != &"walk" and not _acting:
						_sprite.play("walk")
				elif _sprite and _sprite.sprite_frames.has_animation(walk) and not _acting:
					if _sprite.animation != walk:
						_sprite.play(walk)
		else:
			velocity = Vector2.ZERO
			move_and_slide()
			_clamp_to_world()
			if carried_dead:
				_play_dead_pose()
			elif is_pet and not _acting:
				play_idle()
		return

	# Pet idle / walk_to only
	if is_pet and not is_player_controlled and _walk_target == null and not _acting:
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_to_world()
		return

	if _acting and _walk_target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_to_world()
		return

	if _busy and _walk_target == null and not _acting:
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_to_world()
		return

	var dir2 := Vector2.ZERO
	if _walk_target != null:
		var to2: Vector2 = (_walk_target as Vector2) - global_position
		if to2.length() <= _arrive_threshold:
			_walk_target = null
			velocity = Vector2.ZERO
			arrived.emit()
		else:
			dir2 = to2.normalized()
	elif is_player_controlled and not _busy and not _acting:
		if Input.is_action_pressed("move_up"):
			dir2.y -= 1
		if Input.is_action_pressed("move_down"):
			dir2.y += 1
		if Input.is_action_pressed("move_left"):
			dir2.x -= 1
		if Input.is_action_pressed("move_right"):
			dir2.x += 1
		if dir2 != Vector2.ZERO:
			dir2 = dir2.normalized()

	velocity = dir2 * move_speed
	move_and_slide()
	_clamp_to_world()

	if dir2 != Vector2.ZERO and not _acting:
		_update_facing(dir2)
		var walk2 := "walk_%s" % _facing
		if is_pet and _sprite and _sprite.sprite_frames.has_animation("walk"):
			if _sprite.animation != &"walk":
				_sprite.play("walk")
		elif _sprite and _sprite.sprite_frames.has_animation(walk2):
			if _sprite.animation != walk2:
				_sprite.play(walk2)
	elif not _busy and not _acting and _walk_target == null:
		if _sprite:
			var an := String(_sprite.animation)
			if an.begins_with("walk") or an == "walk":
				play_idle()


func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_facing = "right" if dir.x > 0.0 else "left"
	else:
		_facing = "down" if dir.y > 0.0 else "up"
