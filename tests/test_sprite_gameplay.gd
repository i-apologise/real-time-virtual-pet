extends RefCounted

const SpriteFactoryScr = preload("res://src/gameplay/sprite_factory.gd")
const CareDirectorScr = preload("res://src/gameplay/care_director.gd")


func run() -> Dictionary:
	var hf: SpriteFrames = SpriteFactoryScr.human_frames()
	if hf == null or not hf.has_animation("walk_down") or not hf.has_animation("feed"):
		return {"ok": false, "message": "human frames missing walk/feed"}
	var pf: SpriteFrames = SpriteFactoryScr.pet_frames("blob")
	for need in ["idle", "hungry", "weak", "eat", "dead", "happy"]:
		if not pf.has_animation(need):
			return {"ok": false, "message": "pet missing anim %s" % need}
	var tile: Texture2D = SpriteFactoryScr.make_tile("grass")
	if tile == null:
		return {"ok": false, "message": "grass tile null"}

	var d = CareDirectorScr.new()
	if d.is_busy():
		return {"ok": false, "message": "director should start idle"}
	var r: Dictionary = d.try_start_care(&"feed")
	if r.get("ok", false):
		return {"ok": false, "message": "care without actors should fail"}

	return {"ok": true, "message": "Pokemon-style frames + tiles + director gates OK"}
