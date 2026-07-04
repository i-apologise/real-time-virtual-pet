extends RefCounted


func run() -> Dictionary:
	var Adv = load("res://src/sim/care_advisor.gd")
	var Pet = load("res://src/sim/pet_model.gd")
	var t0 := 1_700_000_000.0
	var pet = Pet.create_from_species(&"blob", "Tip", t0, 0)
	pet.hunger = 30.0
	pet.energy = 80.0
	pet.happiness = 70.0
	pet.hygiene = 80.0
	var sug: Dictionary = Adv.suggest(pet, t0)
	if str(sug.get("action", "")) != "feed":
		return {"ok": false, "message": "low hunger should suggest feed got %s" % sug}
	# cooldown
	pet.last_actions["feed"] = t0
	var cd: float = Adv.cooldown_for("feed", pet, t0 + 60.0)
	if cd < 500.0 or cd > 600.0:
		return {"ok": false, "message": "feed cd after 60s expect ~540 got %s" % cd}
	if Adv.format_cd(125.0) != "3m" and Adv.format_cd(125.0) != "2m":
		# ceil 125/60 = 3
		if Adv.format_cd(125.0) != "3m":
			return {"ok": false, "message": "format_cd 125 -> %s" % Adv.format_cd(125.0)}
	pet.is_sleeping()
	pet.start_sleep(t0)
	sug = Adv.suggest(pet, t0 + 1.0)
	if str(sug.get("action", "")) != "wake":
		return {"ok": false, "message": "sleeping suggests wake got %s" % sug}
	var meta := {"session_away_sec": 7200.0, "pre_catchup_last_sim": t0}
	pet.clear_sleep()
	var sum: Dictionary = Adv.session_summary(pet, meta, t0 + 7200.0)
	if str(sum.get("body", "")).find("away") < 0 and str(sum.get("away_label", "")) == "":
		return {"ok": false, "message": "session summary missing away %s" % sum}
	return {"ok": true, "message": "care advisor cooldowns/suggest/summary OK"}
