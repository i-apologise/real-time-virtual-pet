extends RefCounted
## Adopt gates, burial counters, plot uniqueness, death counter separation.


func run() -> Dictionary:
	var ProfileScr: GDScript = preload("res://src/sim/player_profile.gd")
	var PetModelScr: GDScript = preload("res://src/sim/pet_model.gd")
	var AdoptScr: GDScript = preload("res://src/sim/adopt_service.gd")
	var BurialScr: GDScript = preload("res://src/sim/burial_service.gd")
	var DeathScr: GDScript = preload("res://src/sim/death_rules.gd")
	var NeedsScr: GDScript = preload("res://src/sim/needs_simulator.gd")

	var t0 := 1_700_000_000.0
	var profile = ProfileScr.new()

	# Adopt success
	var r: Dictionary = AdoptScr.try_adopt(profile, null, &"blob", "Bo", t0)
	if not bool(r.get("ok", false)):
		return {"ok": false, "message": "adopt failed %s" % r}
	var pet = r["pet"]
	if str(pet.id) != "pet_0":
		return {"ok": false, "message": "first id pet_0 got %s" % pet.id}
	if int(profile.next_pet_serial) != 1:
		return {"ok": false, "message": "serial should be 1 after adopt"}

	# Cannot adopt while living
	r = AdoptScr.try_adopt(profile, pet, &"pup", "Other", t0)
	if str(r.get("reason")) != "HAS_ACTIVE_PET":
		return {"ok": false, "message": "HAS_ACTIVE_PET expected"}

	# Invalid name / species
	r = AdoptScr.try_adopt(profile, null, &"blob", "X", t0)
	if str(r.get("reason")) != "INVALID_NAME":
		return {"ok": false, "message": "INVALID_NAME"}
	r = AdoptScr.try_adopt(profile, null, &"dragon", "OkName", t0)
	if str(r.get("reason")) != "INVALID_SPECIES":
		return {"ok": false, "message": "INVALID_SPECIES"}

	# Kill via catch-up and controller-style death counter
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	var meta := {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	var res = NeedsScr.run_catchup(pet, meta, t0 + 3.0 * 86400.0)
	if not bool(res.death_committed_this_call):
		return {"ok": false, "message": "expected death_committed"}
	# simulate controller
	if bool(res.death_committed_this_call):
		profile.total_pets_died += 1
	if int(profile.total_pets_died) != 1:
		return {"ok": false, "message": "deaths counter"}

	# Must bury before re-adopt
	r = AdoptScr.try_adopt(profile, pet, &"owl", "Night", t0)
	if str(r.get("reason")) != "MUST_BURY_FIRST":
		return {"ok": false, "message": "MUST_BURY_FIRST got %s" % r}

	# Burial: graves++ only, not deaths
	var deaths_before := int(profile.total_pets_died)
	r = BurialScr.complete_burial(profile, pet, t0 + 3.0 * 86400.0 + 10.0, "")
	if not bool(r.get("ok", false)):
		return {"ok": false, "message": "burial fail %s" % r}
	if int(profile.total_graves_dug) != 1:
		return {"ok": false, "message": "graves dug"}
	if int(profile.total_pets_died) != deaths_before:
		return {"ok": false, "message": "burial must not change deaths"}
	var grave = r["grave"]
	if int(grave.plot_index) != 0 or int(grave.plot_x) != 0 or int(grave.plot_y) != 0:
		return {"ok": false, "message": "first plot 0,0"}
	if str(grave.id) != "grave_0":
		return {"ok": false, "message": "grave_0 id"}

	# Second burial plot uniqueness (simulate another dead pet)
	var pet2 = PetModelScr.create_from_species(&"pup", "Pup", t0, 1)
	DeathScr.commit_death(pet2, t0 + 1.0, &"neglect")
	profile.total_pets_died += 1  # controller-style
	r = BurialScr.complete_burial(profile, pet2, t0 + 20.0)
	if not bool(r.get("ok", false)):
		return {"ok": false, "message": "second burial"}
	grave = r["grave"]
	if int(grave.plot_index) != 1 or int(grave.plot_x) != 1:
		return {"ok": false, "message": "second plot index/x"}
	if int(profile.total_graves_dug) != 2:
		return {"ok": false, "message": "two graves"}

	# Idempotent: already buried
	r = BurialScr.complete_burial(profile, pet2, t0 + 30.0)
	if str(r.get("reason")) != "ALREADY_BURIED":
		return {"ok": false, "message": "ALREADY_BURIED"}

	# Re-load already dead: death_committed false → counter stable
	var dead = PetModelScr.create_from_species(&"blob", "Z", t0, 2)
	DeathScr.commit_death(dead, t0, &"neglect")
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	res = NeedsScr.run_catchup(dead, meta, t0 + 100.0)
	if bool(res.death_committed_this_call):
		return {"ok": false, "message": "already dead no re-commit"}

	# After burial active cleared — adopt ok
	r = AdoptScr.try_adopt(profile, null, &"owl", "Hoot", t0 + 40.0)
	if not bool(r.get("ok", false)):
		return {"ok": false, "message": "re-adopt after burial"}
	if str(r["pet"].species_id) != "owl":
		return {"ok": false, "message": "owl species"}

	return {"ok": true, "message": "adopt/burial/counter separation OK"}
