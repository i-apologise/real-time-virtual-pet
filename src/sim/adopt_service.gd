class_name AdoptService
extends RefCounted
## Pure adopt validation + pet creation. Caller assigns active_pet + meta clocks.


static func try_adopt(
	profile: PlayerProfile,
	active_pet: PetModel,
	species_id: StringName,
	raw_name: String,
	now: float
) -> Dictionary:
	if profile == null:
		return {"ok": false, "reason": &"INVALID_ARGS"}
	if active_pet != null:
		if active_pet.life_state == LifeState.DEAD and not active_pet.buried:
			return {"ok": false, "reason": &"MUST_BURY_FIRST"}
		return {"ok": false, "reason": &"HAS_ACTIVE_PET"}
	if not SpeciesCatalog.has_species(species_id):
		return {"ok": false, "reason": &"INVALID_SPECIES"}
	var accepted: String = NameUtils.accepted_name_or_empty(raw_name)
	if accepted == "":
		return {"ok": false, "reason": &"INVALID_NAME"}

	var serial: int = profile.next_pet_serial
	var pet: PetModel = PetModel.create_from_species(species_id, accepted, now, serial)
	if pet == null:
		return {"ok": false, "reason": &"INVALID_SPECIES"}
	profile.next_pet_serial = serial + 1
	return {"ok": true, "pet": pet, "reason": &""}
