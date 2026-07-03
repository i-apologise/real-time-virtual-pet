class_name BurialService
extends RefCounted
## Pure burial archive helper. Does NOT increment total_pets_died.


static func auto_epitaph(pet: PetModel) -> String:
	var species_display := str(pet.species_id)
	var tmpl: Dictionary = SpeciesCatalog.get_template(pet.species_id)
	if not tmpl.is_empty():
		species_display = str(tmpl.get("display_name", pet.species_id))
	return "Here lies %s the %s. Gone too soon from neglect." % [pet.name, species_display]


## Archives grave, increments total_graves_dug only, marks pet.buried.
## Caller must set active_pet = null and save.
static func complete_burial(
	profile: PlayerProfile, pet: PetModel, now: float, epitaph: String = ""
) -> Dictionary:
	if pet == null or profile == null:
		return {"ok": false, "reason": &"INVALID_ARGS"}
	if pet.life_state != LifeState.DEAD:
		return {"ok": false, "reason": &"PET_NOT_DEAD"}
	if pet.buried:
		return {"ok": false, "reason": &"ALREADY_BURIED"}

	var plot_index: int = profile.total_graves_dug
	var cols: int = SimConfig.GRAVEYARD_COLS
	var plot_x: int = plot_index % cols
	var plot_y: int = int(plot_index / cols)
	var grave := GraveRecord.new()
	grave.id = "grave_%d" % plot_index
	grave.pet_id = pet.id
	grave.name = pet.name
	grave.species_id = pet.species_id
	grave.born_unix_utc = pet.born_unix_utc
	grave.died_unix_utc = pet.died_unix_utc
	grave.cause = pet.death_cause
	grave.plot_index = plot_index
	grave.plot_x = plot_x
	grave.plot_y = plot_y
	grave.epitaph = epitaph if epitaph != "" else auto_epitaph(pet)
	grave.buried_unix_utc = now
	profile.graves.append(grave)
	profile.total_graves_dug += 1
	pet.buried = true
	return {"ok": true, "grave": grave, "reason": &""}
