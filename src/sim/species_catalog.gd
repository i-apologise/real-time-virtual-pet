class_name SpeciesCatalog
extends RefCounted
## Live species templates (Appendix B). Rates re-read each sim step — no pet snapshots.

const BLOB := &"blob"
const PUP := &"pup"
const OWL := &"owl"

const ALL_IDS: Array[StringName] = [BLOB, PUP, OWL]


static func has_species(species_id: StringName) -> bool:
	return species_id in ALL_IDS or str(species_id) in ["blob", "pup", "owl"]


static func get_template(species_id: StringName) -> Dictionary:
	var sid := StringName(str(species_id))
	match sid:
		BLOB, &"blob":
			return _blob()
		PUP, &"pup":
			return _pup()
		OWL, &"owl":
			return _owl()
		_:
			return {}


## Alias used by NeedsSimulator (design: SpeciesCatalog.rates_for / get).
static func rates_for(species_id: StringName) -> Dictionary:
	return get_template(species_id)


static func get_species(species_id: StringName) -> Dictionary:
	return get_template(species_id)


static func list_ids() -> Array[StringName]:
	return ALL_IDS.duplicate()


static func _blob() -> Dictionary:
	return {
		"id": BLOB,
		"display_name": "Cozy Blob",
		"hunger_decay_per_hour": 8.0,
		"energy_decay_per_hour": 5.0,
		"happiness_decay_per_hour": 6.0,
		"hygiene_decay_per_hour": 4.0,
		"energy_sleep_regen_per_hour": 12.0,
		"default_hunger": 80.0,
		"default_energy": 80.0,
		"default_happiness": 70.0,
		"default_hygiene": 80.0,
		"feed_need_label": "Low — feed ~every 8–10h",
		"play_need_label": "Low–Medium",
		"hardiness_label": "Hardy",
		"risk_blurb": "Forgiving starter. Still dies if ignored for about a day or more.",
		"temperament": "Calm, low-maintenance",
	}


static func _pup() -> Dictionary:
	return {
		"id": PUP,
		"display_name": "Needy Pup",
		"hunger_decay_per_hour": 14.0,
		"energy_decay_per_hour": 7.0,
		"happiness_decay_per_hour": 12.0,
		"hygiene_decay_per_hour": 6.0,
		"energy_sleep_regen_per_hour": 11.0,
		"default_hunger": 80.0,
		"default_energy": 80.0,
		"default_happiness": 70.0,
		"default_hygiene": 80.0,
		"feed_need_label": "High — feed ~every 4–6h",
		"play_need_label": "High",
		"hardiness_label": "Fragile",
		"risk_blurb": "Demanding companion. Neglect for much of a workday can become dangerous.",
		"temperament": "Energetic, attention-seeking",
	}


static func _owl() -> Dictionary:
	return {
		"id": OWL,
		"display_name": "Night Owl",
		"hunger_decay_per_hour": 10.0,
		"energy_decay_per_hour": 9.0,
		"happiness_decay_per_hour": 7.0,
		"hygiene_decay_per_hour": 5.0,
		"energy_sleep_regen_per_hour": 16.0,
		"default_hunger": 80.0,
		"default_energy": 75.0,
		"default_happiness": 70.0,
		"default_hygiene": 80.0,
		"feed_need_label": "Medium — feed ~every 6–8h",
		"play_need_label": "Medium",
		"hardiness_label": "Medium",
		"risk_blurb": "Tires quickly while awake; sleeps efficiently. Plan naps.",
		"temperament": "Nocturnal vibe, nap-friendly",
	}
