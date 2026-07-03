extends Node2D
## Back-and-forth AI human (invincible flavor) with walk sprites.

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")

var _sprite: AnimatedSprite2D
var _a: Vector2
var _b: Vector2
var _to_b: bool = true
var _speed: float = 55.0


func setup(a: Vector2, b: Vector2, speed: float = 55.0) -> void:
	_a = a
	_b = b
	_speed = speed
	global_position = a
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.position = Vector2(0, -16)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(1.6, 1.6)
	_sprite.sprite_frames = SpriteFactoryScr.human_frames()
	add_child(_sprite)
	_sprite.play("walk_right")
	var tag := Label.new()
	tag.text = "AI"
	tag.position = Vector2(-10, -40)
	tag.add_theme_font_size_override("font_size", 10)
	add_child(tag)


func _process(delta: float) -> void:
	var target := _b if _to_b else _a
	var dir := target - global_position
	if dir.length() < 8.0:
		_to_b = not _to_b
		return
	global_position += dir.normalized() * _speed * delta
	z_index = int(global_position.y)
	if _sprite:
		var anim := "walk_right" if dir.x >= 0.0 else "walk_left"
		if _sprite.animation != anim:
			_sprite.play(anim)
