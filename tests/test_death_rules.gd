extends RefCounted
## Death hold, multi-zero, commit idempotency, life_state recompute.


func run() -> Dictionary:
	var PetModelScr: GDScript = preload("res://src/sim/pet_model.gd")
	var DeathRulesScr: GDScript = preload("res://src/sim/death_rules.gd")

	# Life state bands
	var pet = PetModelScr.new()
	pet.hunger = 80.0
	pet.energy = 80.0
	pet.happiness = 70.0
	pet.hygiene = 80.0
	DeathRulesScr.recompute_life_state_from_stats(pet)
	if str(pet.life_state) != "HEALTHY":
		return {"ok": false, "message": "expected HEALTHY got %s" % pet.life_state}

	pet.hunger = 30.0
	DeathRulesScr.recompute_life_state_from_stats(pet)
	if str(pet.life_state) != "NEEDY":
		return {"ok": false, "message": "expected NEEDY got %s" % pet.life_state}

	pet.hunger = 10.0
	DeathRulesScr.recompute_life_state_from_stats(pet)
	if str(pet.life_state) != "CRITICAL":
		return {"ok": false, "message": "expected CRITICAL got %s" % pet.life_state}

	pet.hunger = 0.0
	DeathRulesScr.recompute_life_state_from_stats(pet)
	if str(pet.life_state) != "DYING":
		return {"ok": false, "message": "expected DYING got %s" % pet.life_state}

	# Single-zero hold: 6h at rate 1.0 from already-at-zero
	var death_hold := 21600.0
	var chunk := 60.0
	pet = _zero_pet(PetModelScr, 0.0, 50.0, 50.0, 50.0)
	var cursor := 1_000_000.0
	var total_hold := 0.0
	var died := false
	while total_hold < death_hold + chunk and not died:
		died = bool(DeathRulesScr.apply_zero_hold_after_chunk(pet, chunk, cursor))
		cursor += chunk
		total_hold += chunk
	if not died or str(pet.life_state) != "DEAD":
		return {"ok": false, "message": "single-zero should die after ~6h hold"}
	if str(pet.death_cause) != "neglect":
		return {"ok": false, "message": "cause neglect expected"}
	var expected_end := 1_000_000.0 + death_hold
	if absf(float(pet.died_unix_utc) - expected_end) > chunk + 1.0:
		return {
			"ok": false,
			"message": "died_unix tolerance fail got %s expect ~%s" % [pet.died_unix_utc, expected_end]
		}

	# Idempotent commit
	if bool(DeathRulesScr.commit_death(pet, float(pet.died_unix_utc) + 999.0, &"neglect")):
		return {"ok": false, "message": "commit_death should be idempotent"}
	if float(pet.died_unix_utc) > expected_end + chunk:
		return {"ok": false, "message": "idempotent commit must not overwrite died_unix"}

	# Multi-zero: rate 2.0 → ~3h
	pet = _zero_pet(PetModelScr, 0.0, 0.0, 50.0, 50.0)
	cursor = 2_000_000.0
	died = false
	var integrated := 0.0
	while integrated < 4.0 * 3600.0 and not died:
		died = bool(DeathRulesScr.apply_zero_hold_after_chunk(pet, chunk, cursor))
		cursor += chunk
		integrated += chunk
	if not died:
		return {"ok": false, "message": "multi-zero should die within ~3h"}
	var multi_expect := 2_000_000.0 + (death_hold / 2.0)
	if absf(float(pet.died_unix_utc) - multi_expect) > chunk + 1.0:
		return {
			"ok": false,
			"message": "multi-zero death time got %s expect ~%s" % [pet.died_unix_utc, multi_expect]
		}

	# Clearing zeros resets hold
	pet = _zero_pet(PetModelScr, 0.0, 50.0, 50.0, 50.0)
	pet.zero_hold_sec = 3.0 * 3600.0
	pet.life_state = &"DYING"
	pet.hunger = 30.0
	DeathRulesScr.after_care_stats_changed(pet)
	if float(pet.zero_hold_sec) != 0.0:
		return {"ok": false, "message": "care clear should reset zero_hold_sec"}
	if str(pet.life_state) == "DEAD" or str(pet.life_state) == "DYING":
		return {"ok": false, "message": "after raise should leave DYING, got %s" % pet.life_state}

	return {"ok": true, "message": "death rules + life_state OK"}


func _zero_pet(PetModelScr: GDScript, h: float, e: float, ha: float, hy: float):
	var pet = PetModelScr.new()
	pet.id = "t"
	pet.name = "T"
	pet.species_id = &"blob"
	pet.hunger = h
	pet.energy = e
	pet.happiness = ha
	pet.hygiene = hy
	if h <= 0.0 or e <= 0.0 or ha <= 0.0 or hy <= 0.0:
		pet.life_state = &"DYING"
	else:
		pet.life_state = &"HEALTHY"
	pet.zero_hold_sec = 0.0
	return pet
