class_name CareAdvisor
extends RefCounted
## Pure helpers: cooldowns remaining, suggested care, session summary for HUD.


static func cooldown_for(action: String, pet: PetModel, now: float) -> float:
	if pet == null:
		return 0.0
	match action:
		"feed":
			return _cd(pet, "feed", now, SimConfig.FEED_COOLDOWN_SEC)
		"walk":
			return _cd(pet, "walk", now, SimConfig.WALK_COOLDOWN_SEC)
		"play":
			return _cd(pet, "play", now, SimConfig.PLAY_COOLDOWN_SEC)
		"clean":
			return _cd(pet, "clean", now, SimConfig.CLEAN_COOLDOWN_SEC)
		_:
			return 0.0


static func _cd(pet: PetModel, key: String, now: float, cd_sec: float) -> float:
	var last: float = float(pet.last_actions.get(key, 0.0))
	if last <= 0.0:
		return 0.0
	var left: float = cd_sec - (now - last)
	return maxf(0.0, left)


static func format_cd(sec: float) -> String:
	if sec <= 0.0:
		return "ready"
	if sec < 60.0:
		return "%ds" % int(ceil(sec))
	var m := int(ceil(sec / 60.0))
	return "%dm" % m


static func action_blocked_reason(action: String, pet: PetModel, now: float) -> StringName:
	## Empty StringName = available (aside from menu cancel).
	if pet == null:
		return &"NO_PET"
	if pet.life_state == LifeState.DEAD:
		return &"PET_DEAD"
	if action == "cancel":
		return &""
	if action == "wake":
		return &"" if pet.is_sleeping() else &"NOT_SLEEPING"
	if action == "sleep":
		return &"ALREADY_SLEEPING" if pet.is_sleeping() else &""
	if pet.is_sleeping():
		return &"PET_SLEEPING"
	var cd := cooldown_for(action, pet, now)
	if cd > 0.0:
		return &"COOLDOWN"
	if action == "walk" and pet.energy < SimConfig.WALK_MIN_ENERGY:
		return &"ENERGY_TOO_LOW"
	if action == "play" and pet.energy < SimConfig.PLAY_MIN_ENERGY:
		return &"ENERGY_TOO_LOW"
	return &""


static func suggest(pet: PetModel, now: float) -> Dictionary:
	## {action, label, detail}
	if pet == null:
		return {"action": "", "label": "Adopt a pet at the Store", "detail": ""}
	if pet.life_state == LifeState.DEAD:
		if pet.buried:
			return {"action": "", "label": "Laid to rest — adopt again at the Store", "detail": ""}
		return {"action": "", "label": "Take them to the backyard · hold E to dig", "detail": "DEAD"}
	if pet.is_sleeping():
		if action_blocked_reason("wake", pet, now) == &"":
			return {"action": "wake", "label": "Suggested: WAKE", "detail": "They're sleeping (Zzz)"}
		return {"action": "", "label": "Sleeping…", "detail": "Zzz"}

	# Priority: critical zeros / dying first
	var life := str(pet.life_state)
	if life == "DYING" or pet.any_need_at_zero():
		var a := _first_ready(["feed", "clean", "play", "walk", "sleep"], pet, now)
		if a != "":
			return {
				"action": a,
				"label": "Urgent: %s" % a.to_upper(),
				"detail": "A need is at zero — care now",
			}
		return {"action": "sleep", "label": "Urgent: rest if you can", "detail": "Needs critical"}

	# Lowest need drives suggestion
	var order: Array = []
	if pet.hunger <= pet.energy and pet.hunger <= pet.happiness and pet.hunger <= pet.hygiene:
		order = ["feed", "play", "clean", "walk", "sleep"]
	elif pet.energy <= pet.happiness and pet.energy <= pet.hygiene:
		order = ["sleep", "feed", "play", "walk", "clean"]
	elif pet.hygiene <= pet.happiness:
		order = ["clean", "feed", "play", "walk", "sleep"]
	else:
		order = ["play", "walk", "feed", "clean", "sleep"]

	# If all high, suggest walk/play for bond
	if pet.min_need() >= 70.0:
		order = ["play", "walk", "feed", "clean", "sleep"]

	var pick := _first_ready(order, pet, now)
	if pick == "":
		# Everything on cooldown — show soonest ready
		var soon_a := "feed"
		var soon_t := 1e12
		for a2 in ["feed", "walk", "play", "clean"]:
			var t2 := cooldown_for(a2, pet, now)
			if t2 < soon_t:
				soon_t = t2
				soon_a = a2
		return {
			"action": soon_a,
			"label": "Next: %s in %s" % [soon_a.to_upper(), format_cd(soon_t)],
			"detail": "All ready care is cooling down",
		}
	var why := ""
	match pick:
		"feed":
			why = "Hunger %.0f" % pet.hunger
		"sleep":
			why = "Energy %.0f" % pet.energy
		"clean":
			why = "Hygiene %.0f" % pet.hygiene
		"play", "walk":
			why = "Happiness %.0f" % pet.happiness
		_:
			why = ""
	return {"action": pick, "label": "Suggested: %s" % pick.to_upper(), "detail": why}


static func _first_ready(order: Array, pet: PetModel, now: float) -> String:
	for a in order:
		if action_blocked_reason(str(a), pet, now) == &"":
			return str(a)
	return ""


static func session_summary(pet: PetModel, meta: Dictionary, now: float) -> Dictionary:
	## {title, body, away_sec, away_label}
	if pet == null:
		return {
			"title": "No pet yet",
			"body": "Visit the Pet Store to adopt a companion.",
			"away_sec": 0.0,
			"away_label": "",
		}
	var last_sim: float = float(meta.get("last_sim_unix_utc", now))
	# After catch-up, last_sim ≈ now; use max_seen gap if we stored previous — approximate with zero if fresh
	# Prefer meta key set before catch-up if available
	var away: float = float(meta.get("session_away_sec", 0.0))
	if away <= 0.0 and meta.has("pre_catchup_last_sim"):
		away = maxf(0.0, now - float(meta.get("pre_catchup_last_sim", now)))
	var away_label := _format_away(away)
	var st: Dictionary = StatusCopy.status_for_pet(pet)
	var sug: Dictionary = suggest(pet, now)
	var fc: Dictionary = NeedsForecast.forecast(pet)
	var lines: Array[String] = []
	lines.append(str(st.get("message", "")))
	if away >= 60.0:
		lines.append("You were away %s." % away_label)
	var sum := str(fc.get("summary", ""))
	if sum != "":
		lines.append(sum)
	var sug_l := str(sug.get("label", ""))
	if sug_l != "":
		lines.append(sug_l)
	var title := "%s · %s" % [pet.name, str(pet.life_state)]
	if pet.is_sleeping():
		title = "%s · SLEEPING (Zzz)" % pet.name
	return {
		"title": title,
		"body": "\n".join(lines),
		"away_sec": away,
		"away_label": away_label,
		"suggest": sug,
	}


static func _format_away(sec: float) -> String:
	if sec < 60.0:
		return "under a minute"
	if sec < 3600.0:
		return "%d min" % int(round(sec / 60.0))
	if sec < 86400.0:
		var h := int(sec / 3600.0)
		var m := int(fmod(sec, 3600.0) / 60.0)
		if m <= 0:
			return "%dh" % h
		return "%dh %dm" % [h, m]
	var d := int(sec / 86400.0)
	return "%d day%s" % [d, "s" if d != 1 else ""]
