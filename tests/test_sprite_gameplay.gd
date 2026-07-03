extends RefCounted

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const CareDirectorScr = preload("res://src/gameplay/care_director.gd")
const AnimatedActorScr = preload("res://src/gameplay/animated_actor.gd")


func run() -> Dictionary:
	var hf: SpriteFrames = SpriteFactoryScr.human_frames()
	if hf == null or not hf.has_animation("walk_down") or not hf.has_animation("feed"):
		return {"ok": false, "message": "human frames missing walk/feed"}
	var pf: SpriteFrames = SpriteFactoryScr.pet_frames("blob")
	if not pf.has_animation("idle") or not pf.has_animation("eat") or not pf.has_animation("dead"):
		return {"ok": false, "message": "pet frames incomplete"}
	var pup: SpriteFrames = SpriteFactoryScr.pet_frames("pup")
	if pup.get_frame_count("idle") < 1:
		return {"ok": false, "message": "pup frames empty"}

	# Director busy gate without scene tree actors
	var d = CareDirectorScr.new()
	if d.is_busy():
		return {"ok": false, "message": "director should start idle"}
	var r: Dictionary = d.try_start_care(&"feed")
	if r.get("ok", false):
		return {"ok": false, "message": "care without actors should fail"}

	return {"ok": true, "message": "SpriteFactory + CareDirector gates OK"}
