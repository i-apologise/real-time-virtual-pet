extends Node
## Fresh-start flow: tutorial (once) → adopt if no pet → otherwise town.


func _ready() -> void:
	if PetController.has_method("boot"):
		PetController.boot()
	call_deferred("_route")


func _route() -> void:
	var tutorial_done := _is_tutorial_done()
	var has_pet := PetController.active_pet != null

	# Fresh / no pet: teach then adopt first
	if not tutorial_done:
		SceneRouter.go("tutorial")
		return
	if not has_pet:
		SceneRouter.go("pet_store")
		return
	SceneRouter.go("town")


func _is_tutorial_done() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://onboarding.cfg") != OK:
		return false
	return bool(cfg.get_value("onboarding", "tutorial_done", false))
