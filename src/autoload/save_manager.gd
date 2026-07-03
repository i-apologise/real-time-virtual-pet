extends Node
## Stub — PR5 will implement JSON save/load v2.

const SAVE_PATH := "user://saves/pet_save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
