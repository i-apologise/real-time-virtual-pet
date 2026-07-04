class_name PlayerProfile
extends RefCounted
## Player counters + grave archive + light economy. total_pets_died is controller-owned only.

var total_pets_died: int = 0
var total_graves_dug: int = 0
var next_pet_serial: int = 0
var graves: Array = []  # Array of GraveRecord
## Soft currency earned from care; spent at pet store.
var care_points: int = 0
## Consumables / upgrades: premium_food (charges), soap (charges), chew_toy (0/1 permanent).
var inventory: Dictionary = {"premium_food": 0, "soap": 0, "chew_toy": 0}


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
		"care_points": care_points,
		"inventory": inventory.duplicate(true),
	}


func to_view_dict(has_active_pet: bool) -> Dictionary:
	return {
		"total_pets_died": total_pets_died,
		"total_graves_dug": total_graves_dug,
		"grave_count": graves.size(),
		"has_active_pet": has_active_pet,
		"care_points": care_points,
		"inventory": inventory.duplicate(true),
	}


static func from_save_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.total_pets_died = int(d.get("total_pets_died", 0))
	p.total_graves_dug = int(d.get("total_graves_dug", 0))
	p.next_pet_serial = int(d.get("next_pet_serial", 0))
	p.care_points = int(d.get("care_points", 0))
	var inv: Variant = d.get("inventory", {})
	if inv is Dictionary:
		p.inventory = {
			"premium_food": int(inv.get("premium_food", 0)),
			"soap": int(inv.get("soap", 0)),
			"chew_toy": int(inv.get("chew_toy", 0)),
		}
	p.graves = []
	var arr: Variant = d.get("graves", [])
	if arr is Array:
		for item in arr:
			if item is Dictionary:
				p.graves.append(GraveRecord.from_dict(item))
	return p


func add_care_points(n: int) -> void:
	care_points = maxi(0, care_points + n)


func try_spend(cost: int) -> bool:
	if care_points < cost:
		return false
	care_points -= cost
	return true


func inv_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_item(item_id: String, n: int = 1) -> void:
	inventory[item_id] = inv_count(item_id) + n


func consume_item(item_id: String, n: int = 1) -> bool:
	if inv_count(item_id) < n:
		return false
	inventory[item_id] = inv_count(item_id) - n
	return true


func find_grave_by_pet_id(pet_id: String) -> GraveRecord:
	for g in graves:
		if g is GraveRecord and g.pet_id == pet_id:
			return g
	return null
