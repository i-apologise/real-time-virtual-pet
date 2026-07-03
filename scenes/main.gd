extends Node
## Entry: boot controller then open town simulation.

func _ready() -> void:
	# Ensure controller booted
	if PetController.has_method("boot"):
		PetController.boot()
	# Prefer town as the living world; habitat for care
	SceneRouter.go("town")
