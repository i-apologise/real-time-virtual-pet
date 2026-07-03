class_name PlayerProfile
extends RefCounted
## Player counters + grave archive. total_pets_died is controller-owned only.

var total_pets_died: int = 0
var total_graves_dug: int = 0
var next_pet_serial: int = 0
var graves: Array = []  # Array of GraveRecord


func to_save_dict() -> Dictionary:
	var graves_out: Array = []
	for g in graves:
		if g is GraveRecord:
			graves_out.append(g.to_dict())
		elif g is Dictionary:
			graves_out.append(g)
	return {
		"total_pets_died": total_pets_died,
		"total_graves_dug": total_graves_dug,
		"next_pet_serial": next_pet_serial,
		"graves": graves_out,
	}


func to_view_dict(has_active_pet: bool) -> Dictionary:
	return {
		"total_pets_died": total_pets_died,
		"total_graves_dug": total_graves_dug,
		"grave_count": graves.size(),
		"has_active_pet": has_active_pet,
	}


static func from_save_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.total_pets_died = int(d.get("total_pets_died", 0))
	p.total_graves_dug = int(d.get("total_graves_dug", 0))
	p.next_pet_serial = int(d.get("next_pet_serial", 0))
	p.graves = []
	var arr: Variant = d.get("graves", [])
	if arr is Array:
		for item in arr:
			if item is Dictionary:
				p.graves.append(GraveRecord.from_dict(item))
	return p


func find_grave_by_pet_id(pet_id: String) -> GraveRecord:
	for g in graves:
		if g is GraveRecord and g.pet_id == pet_id:
			return g
	return null
