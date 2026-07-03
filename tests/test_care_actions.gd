extends RefCounted
## Care actions: cooldowns, dead reject, sleep gates, diminish, deltas.


func run() -> Dictionary:
	var PetModelScr: GDScript = preload("res://src/sim/pet_model.gd")
	var CareScr: GDScript = preload("res://src/sim/care_actions.gd")
	var DeathRulesScr: GDScript = preload("res://src/sim/death_rules.gd")
	var MoodScr: GDScript = preload("res://src/sim/mood_state_machine.gd")

	var t0 := 1_700_000_000.0
	var feed_cd := 600.0
	var pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)

	# Feed success
	var r: Dictionary = CareScr.try_feed(pet, t0)
	if not bool(r.get("ok", false)):
		return {"ok": false, "message": "feed fail %s" % r.get("reason")}
	if absf(float(pet.hunger) - 110.0) > 0.01 and absf(float(pet.hunger) - 100.0) > 0.01:
		# clamp to 100
		if float(pet.hunger) > 100.0:
			return {"ok": false, "message": "feed should clamp hunger <=100 got %s" % pet.hunger}
	# after clamp: 80+30=110 → 100
	if absf(float(pet.hunger) - 100.0) > 0.01:
		return {"ok": false, "message": "feed hunger expected 100 clamped got %s" % pet.hunger}
	if int(pet.total_care_actions) != 1:
		return {"ok": false, "message": "care counter"}

	# Cooldown
	r = CareScr.try_feed(pet, t0 + 60.0)
	if bool(r.get("ok", false)) or str(r.get("reason")) != "COOLDOWN":
		return {"ok": false, "message": "feed cooldown expected got %s" % r}

	# Diminishing within 30m after cooldown clears
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	CareScr.try_feed(pet, t0)
	var after_cd := t0 + feed_cd + 1.0
	r = CareScr.try_feed(pet, after_cd)
	if not bool(r.get("ok", false)):
		return {"ok": false, "message": "second feed after cd should work"}
	# first: 80+30 → clamp 100; second diminish +15 → 100 (still max) — use lower start
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	pet.hunger = 40.0
	CareScr.try_feed(pet, t0)  # +30 → 70
	r = CareScr.try_feed(pet, after_cd)  # +15 diminish → 85
	if not bool(r.get("ok", false)):
		return {"ok": false, "message": "diminish feed failed"}
	if absf(float(pet.hunger) - 85.0) > 0.5:
		return {"ok": false, "message": "diminish hunger expect 85 got %s" % pet.hunger}

	# Dead rejects all
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	DeathRulesScr.commit_death(pet, t0, &"neglect")
	for act in ["feed", "walk", "play", "clean", "sleep", "wake"]:
		r = CareScr.try_action(StringName(act), pet, t0 + 10.0, true)
		if bool(r.get("ok", false)) or str(r.get("reason")) != "PET_DEAD":
			return {"ok": false, "message": "%s should reject PET_DEAD got %s" % [act, r]}

	# Sleep gates feed
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	r = CareScr.try_sleep(pet, t0)
	if not bool(r.get("ok", false)) or not bool(pet.is_sleeping()):
		return {"ok": false, "message": "sleep should work"}
	r = CareScr.try_feed(pet, t0 + 1.0)
	if bool(r.get("ok", false)) or str(r.get("reason")) != "PET_SLEEPING":
		return {"ok": false, "message": "feed while sleeping rejected"}
	r = CareScr.try_wake(pet, t0 + 2.0)
	if not bool(r.get("ok", false)) or bool(pet.is_sleeping()):
		return {"ok": false, "message": "wake should clear sleep"}

	# Walk day bonus
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	var h0: float = float(pet.happiness)
	CareScr.try_walk(pet, t0, true)
	var day_gain: float = float(pet.happiness) - h0
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	h0 = float(pet.happiness)
	CareScr.try_walk(pet, t0, false)
	var night_gain: float = float(pet.happiness) - h0
	if day_gain <= night_gain:
		return {"ok": false, "message": "day walk should grant bonus happiness"}

	# Play energy gate
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	pet.energy = 5.0
	r = CareScr.try_play(pet, t0)
	if bool(r.get("ok", false)) or str(r.get("reason")) != "ENERGY_TOO_LOW":
		return {"ok": false, "message": "play energy gate"}

	# Clean dirty bonus
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	pet.hygiene = 20.0
	var happy0: float = float(pet.happiness)
	CareScr.try_clean(pet, t0)
	if float(pet.happiness) < happy0 + 4.9:
		return {"ok": false, "message": "clean dirty happiness bonus"}

	# Feed while DYING raises and recomputes
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	pet.hunger = 0.0
	pet.zero_hold_sec = 2.0 * 3600.0
	pet.life_state = &"DYING"
	r = CareScr.try_feed(pet, t0)
	if not bool(r.get("ok", false)):
		return {"ok": false, "message": "feed while dying"}
	if str(pet.life_state) == "DYING" or str(pet.life_state) == "DEAD":
		return {"ok": false, "message": "after feed life_state should improve got %s" % pet.life_state}
	if float(pet.zero_hold_sec) != 0.0:
		return {"ok": false, "message": "hold cleared"}

	# Mood smoke
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	if str(MoodScr.derive_mood(pet)) == "":
		return {"ok": false, "message": "mood empty"}
	pet.life_state = &"DEAD"
	if str(MoodScr.derive_mood(pet)) != "DEAD":
		return {"ok": false, "message": "mood DEAD"}

	# Save roundtrip sleep SOT
	pet = PetModelScr.create_from_species(&"blob", "Bo", t0, 0)
	pet.start_sleep(t0)
	var d: Dictionary = pet.to_save_dict()
	if d.has("is_sleeping"):
		return {"ok": false, "message": "save must not require is_sleeping field"}
	var p2 = PetModelScr.from_save_dict(d)
	if not bool(p2.is_sleeping()):
		return {"ok": false, "message": "from_save should derive sleeping"}

	return {"ok": true, "message": "care actions + mood + save dict OK"}
