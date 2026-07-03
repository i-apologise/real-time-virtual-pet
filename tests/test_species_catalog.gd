extends RefCounted
## Species catalog presence and rate differentiation.


func run() -> Dictionary:
	var SpeciesCatalog = preload("res://src/sim/species_catalog.gd")
	for sid in ["blob", "pup", "owl"]:
		if not SpeciesCatalog.has_species(StringName(sid)):
			return {"ok": false, "message": "missing species %s" % sid}
		var t: Dictionary = SpeciesCatalog.get_template(StringName(sid))
		if t.is_empty():
			return {"ok": false, "message": "empty template %s" % sid}
		if float(t.get("hunger_decay_per_hour", 0.0)) <= 0.0:
			return {"ok": false, "message": "bad hunger rate %s" % sid}
		if str(t.get("feed_need_label", "")) == "":
			return {"ok": false, "message": "missing feed label %s" % sid}

	var blob: Dictionary = SpeciesCatalog.get_template(&"blob")
	var pup: Dictionary = SpeciesCatalog.get_template(&"pup")
	if float(pup["hunger_decay_per_hour"]) <= float(blob["hunger_decay_per_hour"]):
		return {"ok": false, "message": "pup should be hungrier than blob"}

	var owl: Dictionary = SpeciesCatalog.get_template(&"owl")
	if float(owl["energy_sleep_regen_per_hour"]) <= float(blob["energy_sleep_regen_per_hour"]):
		return {"ok": false, "message": "owl should sleep-regen faster than blob"}

	if SpeciesCatalog.has_species(&"dragon"):
		return {"ok": false, "message": "unknown species should be false"}

	return {"ok": true, "message": "species catalog blob/pup/owl OK"}
