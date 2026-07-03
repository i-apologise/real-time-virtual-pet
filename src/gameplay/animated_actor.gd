extends CharacterBody2D
## 2D actor with AnimatedSprite2D, WASD optional, path walk-to.
## Instantiate via preload("res://src/gameplay/animated_actor.gd").new()

signal arrived
signal anim_finished(anim_name: StringName)

@export var move_speed: float = 140.0
@export var is_player_controlled: bool = false

var _sprite: AnimatedSprite2D
var _facing: String = "down"
var _busy: bool = false
var _walk_target: Variant = null  # Vector2 or null
var _arrive_threshold: float = 8.0


func setup_frames(frames: SpriteFrames, scale_mul: float = 2.0) -> void:
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = true
		_sprite.position = Vector2(0, -16)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(scale_mul, scale_mul)
	if not _sprite.animation_finished.is_connected(_on_anim_finished):
		_sprite.animation_finished.connect(_on_anim_finished)
	play_idle()


func set_busy(v: bool) -> void:
	_busy = v
	if v:
		_walk_target = null


func is_busy() -> bool:
	return _busy


func play_idle() -> void:
	if _sprite == null:
		return
	var anim := "idle_%s" % _facing
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
	elif _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")


func play_anim(anim: StringName) -> void:
	if _sprite and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func walk_to(world_pos: Vector2) -> void:
	_walk_target = world_pos


func _on_anim_finished() -> void:
	anim_finished.emit(_sprite.animation)


func _physics_process(delta: float) -> void:
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
		elif _sprite and _sprite.sprite_frames.has_animation("walk"):
			if _sprite.animation != &"walk":
				_sprite.play("walk")
	elif not _busy:
		# only idle if not playing a one-shot care anim
		if _sprite and not String(_sprite.animation).begins_with("idle") and _walk_target == null:
			if _sprite.sprite_frames.get_animation_loop(_sprite.animation) == false:
				pass  # let one-shot finish
			else:
				play_idle()
		elif _sprite and _walk_target == null and (
			String(_sprite.animation).begins_with("walk") or _sprite.animation == &"walk"
		):
			play_idle()


func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_facing = "right" if dir.x > 0.0 else "left"
	else:
		_facing = "down" if dir.y > 0.0 else "up"
