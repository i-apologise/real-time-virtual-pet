extends Control
## Boot host — opens habitat playable shell.


func _ready() -> void:
	print("[main] boot → habitat; status=", PetController.get_status_line())
	# Defer so tree is ready for change_scene
	call_deferred("_go_habitat")


func _go_habitat() -> void:
	if ResourceLoader.exists("res://scenes/habitat/habitat.tscn"):
		SceneRouter.go("habitat")
