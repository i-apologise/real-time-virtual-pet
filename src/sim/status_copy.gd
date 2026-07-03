class_name StatusCopy
extends RefCounted
## Priority status banner copy for HUD (presentation helper, pure).


static func status_for_pet(pet: PetModel) -> Dictionary:
	if pet == null:
		return {"message": "No pet — visit the Pet Store to adopt.", "priority": 50}
	if pet.life_state == LifeState.DEAD:
		if pet.buried:
			return {"message": "%s has been laid to rest." % pet.name, "priority": 95}
		return {
			"message": "%s has died. Dig a grave to say goodbye." % pet.name,
			"priority": 100,
		}
	if pet.life_state == LifeState.DYING or pet.any_need_at_zero():
		return {
			"message": "%s is failing — care for them now!" % pet.name,
			"priority": 90,
		}
	if pet.life_state == LifeState.CRITICAL:
		return {"message": "I need you urgently…", "priority": 80}
	if pet.is_sleeping():
		return {"message": "Zzz…", "priority": 60}
	if pet.life_state == LifeState.NEEDY:
		var worst := _worst_stat_name(pet)
		return {"message": "I'm %s…" % worst, "priority": 70}
	return {"message": "%s looks content." % pet.name, "priority": 0}


static func _worst_stat_name(pet: PetModel) -> String:
	var m: float = pet.min_need()
	if is_equal_approx(pet.hunger, m):
		return "hungry"
	if is_equal_approx(pet.energy, m):
		return "tired"
	if is_equal_approx(pet.happiness, m):
		return "lonely"
	return "messy"
