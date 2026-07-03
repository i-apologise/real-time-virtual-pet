extends CharacterBody2D
## Pixel actor: collision, Y-sort, walk/care anims. Pets can show condition visuals.

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
var _walk_target: Variant = null
var _arrive_threshold: float = 10.0
var _collision: CollisionShape2D
var _condition: String = "healthy"  # healthy | hungry | weak | critical | dead


func _ready() -> void:
	# Feet at origin for correct Y-sort (Pokemon-style)
	y_sort_enabled = false
	z_as_relative = true


func setup_collision(as_pet: bool = false) -> void:
	is_pet = as_pet
	if _collision == null:
		_collision = CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 10.0 if as_pet else 9.0
		_collision.shape = shape
		_collision.position = Vector2(0, -2)
		add_child(_collision)
	if as_pet:
		collision_layer = LAYER_PET
		collision_mask = 0  # pet doesn't push through walls itself (static-ish)
		# Still CharacterBody so we can move slightly; frozen mask
		motion_mode = MOTION_MODE_FLOATING
	else:
		collision_layer = LAYER_PLAYER
		collision_mask = LAYER_WORLD | LAYER_PET  # cannot walk through world or pet


func setup_frames(frames: SpriteFrames, scale_mul: float = 3.0) -> void:
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.position = Vector2(0, -8)
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
			_sprite.modulate = Color(0.55, 0.55, 0.6)
			_sprite.scale = _sprite.scale  # keep
		"critical", "dying":
			_sprite.modulate = Color(0.85, 0.55, 0.55)
		"weak", "hungry":
			_sprite.modulate = Color(0.95, 0.85, 0.7)
		_:
			_sprite.modulate = Color.WHITE


func set_busy(v: bool) -> void:
	_busy = v
	if v:
		_walk_target = null


func is_busy() -> bool:
	return _busy


func play_idle() -> void:
	if _sprite == null:
		return
	if is_pet:
		var anim := _pet_idle_anim()
		if _sprite.sprite_frames.has_animation(anim):
			_sprite.play(anim)
		elif _sprite.sprite_frames.has_animation("idle"):
			_sprite.play("idle")
		return
	var anim2 := "idle_%s" % _facing
	if _sprite.sprite_frames.has_animation(anim2):
		_sprite.play(anim2)


func _pet_idle_anim() -> StringName:
	match _condition:
		"dead":
			return &"dead"
		"critical", "dying":
			return &"weak"
		"hungry", "weak":
			return &"hungry"
		_:
			return &"idle"


func play_anim(anim: StringName) -> void:
	if _sprite and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func walk_to(world_pos: Vector2) -> void:
	_walk_target = world_pos


func _on_anim_finished() -> void:
	if _sprite:
		anim_finished.emit(_sprite.animation)


func _physics_process(_delta: float) -> void:
	# Y-sort: draw order by feet Y
	z_index = int(global_position.y)

	if is_pet and not is_player_controlled:
		# Pet stays put; still update z
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _busy and _walk_target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := Vector2.ZERO
	if _walk_target != null:
		var to: Vector2 = (_walk_target as Vector2) - global_position
		if to.length() <= _arrive_threshold:
			_walk_target = null
			velocity = Vector2.ZERO
			play_idle()
			arrived.emit()
		else:
			dir = to.normalized()
	elif is_player_controlled and not _busy:
		if Input.is_action_pressed("move_up"):
			dir.y -= 1
		if Input.is_action_pressed("move_down"):
			dir.y += 1
		if Input.is_action_pressed("move_left"):
			dir.x -= 1
		if Input.is_action_pressed("move_right"):
			dir.x += 1
		if dir != Vector2.ZERO:
			dir = dir.normalized()

	velocity = dir * move_speed
	move_and_slide()

	if dir != Vector2.ZERO:
		_update_facing(dir)
		var walk := "walk_%s" % _facing
		if _sprite and _sprite.sprite_frames.has_animation(walk):
			if _sprite.animation != walk:
				_sprite.play(walk)
	elif not _busy:
		if _sprite and _walk_target == null:
			var an := String(_sprite.animation)
			if an.begins_with("walk") or an == "walk":
				play_idle()
			elif _sprite.sprite_frames.has_animation(_sprite.animation) and not _sprite.sprite_frames.get_animation_loop(_sprite.animation):
				pass
			elif not an.begins_with("idle") and an not in ["feed", "play", "clean", "sleep", "wake", "dig", "eat", "hungry", "weak", "dead", "happy", "sad"]:
				play_idle()


func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_facing = "right" if dir.x > 0.0 else "left"
	else:
		_facing = "down" if dir.y > 0.0 else "up"
