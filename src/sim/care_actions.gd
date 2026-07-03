class_name CareActions
extends RefCounted
## Instant care resolve with cooldowns. Alive-only; rejects DEAD / sleeping where required.


static func try_action(
	action: StringName,
	pet: PetModel,
	now: float,
	is_local_day: bool = false
) -> Dictionary:
	match String(action):
		"feed":
			return try_feed(pet, now)
		"walk":
			return try_walk(pet, now, is_local_day)
		"play":
			return try_play(pet, now)
		"clean":
			return try_clean(pet, now)
		"sleep":
			return try_sleep(pet, now)
		"wake":
			return try_wake(pet, now)
		_:
			return _fail(&"UNKNOWN_ACTION")


static func try_feed(pet: PetModel, now: float) -> Dictionary:
	var gate := _alive_awake_gate(pet)
	if not gate.get("ok", false):
		return gate
	var cd := _cooldown_remaining(pet, "feed", now, SimConfig.FEED_COOLDOWN_SEC)
	if cd > 0.0:
		return _fail(&"COOLDOWN", {"remaining_sec": cd})

	var hunger_was: float = pet.hunger
	var hunger_delta: float = SimConfig.FEED_HUNGER_DELTA
	var last_feed: float = float(pet.last_actions.get("feed", 0.0))
	if last_feed > 0.0 and (now - last_feed) < SimConfig.FEED_DIMINISH_WINDOW_SEC:
		hunger_delta *= SimConfig.FEED_DIMINISH_MULT

	var hygiene_delta: float = SimConfig.FEED_HYGIENE_DELTA
	var happiness_delta := 0.0
	if hunger_was < SimConfig.NEEDY_THRESHOLD:
		happiness_delta = SimConfig.FEED_HAPPINESS_IF_WAS_NEEDY

	pet.hunger += hunger_delta
	pet.hygiene += hygiene_delta
	pet.happiness += happiness_delta
	_finish_care(pet, "feed", now)
	return _ok(
		&"feed",
		{"hunger": hunger_delta, "hygiene": hygiene_delta, "happiness": happiness_delta}
	)


static func try_walk(pet: PetModel, now: float, is_local_day: bool = false) -> Dictionary:
	var gate := _alive_awake_gate(pet)
	if not gate.get("ok", false):
		return gate
	if pet.energy < SimConfig.WALK_MIN_ENERGY:
		return _fail(&"ENERGY_TOO_LOW", {"energy": pet.energy, "min": SimConfig.WALK_MIN_ENERGY})
	var cd := _cooldown_remaining(pet, "walk", now, SimConfig.WALK_COOLDOWN_SEC)
	if cd > 0.0:
		return _fail(&"COOLDOWN", {"remaining_sec": cd})

	var happy: float = SimConfig.WALK_HAPPINESS_DELTA
	if is_local_day:
		happy += SimConfig.WALK_DAY_BONUS_HAPPINESS
	var deltas := {
		"happiness": happy,
		"hunger": SimConfig.WALK_HUNGER_DELTA,
		"energy": SimConfig.WALK_ENERGY_DELTA,
		"hygiene": SimConfig.WALK_HYGIENE_DELTA,
	}
	pet.happiness += deltas["happiness"]
	pet.hunger += deltas["hunger"]
	pet.energy += deltas["energy"]
	pet.hygiene += deltas["hygiene"]
	_finish_care(pet, "walk", now)
	return _ok(&"walk", deltas)


static func try_play(pet: PetModel, now: float) -> Dictionary:
	var gate := _alive_awake_gate(pet)
	if not gate.get("ok", false):
		return gate
	if pet.energy < SimConfig.PLAY_MIN_ENERGY:
		return _fail(&"ENERGY_TOO_LOW", {"energy": pet.energy, "min": SimConfig.PLAY_MIN_ENERGY})
	var cd := _cooldown_remaining(pet, "play", now, SimConfig.PLAY_COOLDOWN_SEC)
	if cd > 0.0:
		return _fail(&"COOLDOWN", {"remaining_sec": cd})

	var deltas := {
		"happiness": SimConfig.PLAY_HAPPINESS_DELTA,
		"energy": SimConfig.PLAY_ENERGY_DELTA,
		"hunger": SimConfig.PLAY_HUNGER_DELTA,
	}
	pet.happiness += deltas["happiness"]
	pet.energy += deltas["energy"]
	pet.hunger += deltas["hunger"]
	_finish_care(pet, "play", now)
	return _ok(&"play", deltas)


static func try_clean(pet: PetModel, now: float) -> Dictionary:
	var gate := _alive_awake_gate(pet)
	if not gate.get("ok", false):
		return gate
	var cd := _cooldown_remaining(pet, "clean", now, SimConfig.CLEAN_COOLDOWN_SEC)
	if cd > 0.0:
		return _fail(&"COOLDOWN", {"remaining_sec": cd})

	var hygiene_was: float = pet.hygiene
	var hygiene_delta: float = SimConfig.CLEAN_HYGIENE_DELTA
	var happiness_delta := 0.0
	if hygiene_was < SimConfig.NEEDY_THRESHOLD:
		happiness_delta = SimConfig.CLEAN_HAPPINESS_IF_WAS_DIRTY
	pet.hygiene += hygiene_delta
	pet.happiness += happiness_delta
	_finish_care(pet, "clean", now)
	return _ok(&"clean", {"hygiene": hygiene_delta, "happiness": happiness_delta})


static func try_sleep(pet: PetModel, now: float) -> Dictionary:
	if pet.life_state == LifeState.DEAD:
		return _fail(&"PET_DEAD")
	if pet.is_sleeping():
		return _fail(&"ALREADY_SLEEPING")
	pet.start_sleep(now)
	DeathRules.recompute_life_state_from_stats(pet)
	return _ok(&"sleep", {})


static func try_wake(pet: PetModel, now: float) -> Dictionary:
	if pet.life_state == LifeState.DEAD:
		return _fail(&"PET_DEAD")
	if not pet.is_sleeping():
		return _fail(&"NOT_SLEEPING")
	pet.clear_sleep()
	DeathRules.recompute_life_state_from_stats(pet)
	return _ok(&"wake", {"now": now})


static func _alive_awake_gate(pet: PetModel) -> Dictionary:
	if pet == null:
		return _fail(&"NO_ACTIVE_PET")
	if pet.life_state == LifeState.DEAD:
		return _fail(&"PET_DEAD")
	if pet.is_sleeping():
		return _fail(&"PET_SLEEPING")
	return {"ok": true}


static func _cooldown_remaining(pet: PetModel, key: String, now: float, cd_sec: float) -> float:
	var last: float = float(pet.last_actions.get(key, 0.0))
	if last <= 0.0:
		return 0.0
	var elapsed: float = now - last
	if elapsed >= cd_sec:
		return 0.0
	return cd_sec - elapsed


static func _finish_care(pet: PetModel, key: String, now: float) -> void:
	pet.last_actions[key] = now
	pet.total_care_actions += 1
	DeathRules.after_care_stats_changed(pet)


static func _ok(action: StringName, deltas: Dictionary) -> Dictionary:
	return {"ok": true, "action": action, "deltas": deltas, "reason": &""}


static func _fail(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": false, "reason": reason, "deltas": {}}
	for k in extra.keys():
		d[k] = extra[k]
	return d
