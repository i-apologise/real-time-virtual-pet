class_name NeedsSimulator
extends RefCounted
## Authoritative catch-up + chunk integration. No hibernation. No soft floor in MVP.
## meta: Dictionary with last_sim_unix_utc, max_seen_unix_utc (mutated on COMMIT / max_seen).


static func run_catchup(pet: PetModel, meta: Dictionary, now: float) -> CatchupResult:
	var result := CatchupResult.new()
	if pet == null:
		result.stalled = true
		result.stall_reason = &"NO_PET"
		return result

	result.life_state_before = pet.life_state
	var last_sim: float = float(meta.get("last_sim_unix_utc", now))
	var max_seen: float = float(meta.get("max_seen_unix_utc", last_sim))

	# 4a reverse clock — NO COMMIT
	if now < last_sim:
		result.stalled = true
		result.stall_reason = &"TIME_WENT_BACKWARDS"
		result.events.append({"kind": &"TIME_WENT_BACKWARDS", "now": now, "last_sim": last_sim})
		meta["max_seen_unix_utc"] = maxf(max_seen, last_sim)
		result.life_state_after = pet.life_state
		return result

	# 4b behind historic peak — hard stall NO COMMIT
	if now < max_seen:
		result.stalled = true
		result.stall_reason = &"TIME_BEHIND_MAX_SEEN"
		result.events.append({"kind": &"TIME_BEHIND_MAX_SEEN", "now": now, "max_seen": max_seen})
		result.life_state_after = pet.life_state
		return result

	meta["max_seen_unix_utc"] = maxf(max_seen, now)

	# Already DEAD: no integrate; still COMMIT clock
	if pet.life_state == LifeState.DEAD:
		_commit_clock(meta, now)
		result.death_committed_this_call = false
		result.life_state_after = pet.life_state
		return result

	var raw_dt: float = now - last_sim
	var sim_dt: float = minf(raw_dt, SimConfig.MAX_CATCHUP_SEC)
	var sim_cursor: float = last_sim
	var species_cfg: Dictionary = SpeciesCatalog.rates_for(pet.species_id)
	if species_cfg.is_empty():
		species_cfg = SpeciesCatalog.rates_for(&"blob")

	var remaining: float = sim_dt
	var death_this := false
	while remaining > 0.0 and pet.life_state != LifeState.DEAD:
		var step: float = minf(remaining, SimConfig.CHUNK_SEC)
		var died: bool = apply_chunk_normal(pet, step, sim_cursor, species_cfg)
		if died:
			death_this = true
		sim_cursor += step
		remaining -= step
		result.integrated_sec += step

	if pet.life_state != LifeState.DEAD:
		DeathRules.recompute_life_state_from_stats(pet)

	_commit_clock(meta, now)

	result.death_committed_this_call = (
		result.life_state_before != LifeState.DEAD and pet.life_state == LifeState.DEAD
	)
	if result.death_committed_this_call:
		result.death_detail = {
			"died_unix_utc": pet.died_unix_utc,
			"cause": pet.death_cause,
			"name": pet.name,
			"pet_id": pet.id,
		}
		result.events.append({"kind": &"DEATH", "detail": result.death_detail})
	elif death_this:
		# defensive: commit_death true but state check should match
		pass

	result.life_state_after = pet.life_state
	return result


static func _commit_clock(meta: Dictionary, now: float) -> void:
	meta["last_sim_unix_utc"] = now
	meta["max_seen_unix_utc"] = maxf(float(meta.get("max_seen_unix_utc", now)), now)


## Integrate one chunk. Returns true if death newly committed.
static func apply_chunk_normal(
	pet: PetModel, step: float, sim_cursor: float, species_cfg: Dictionary
) -> bool:
	if pet.life_state == LifeState.DEAD:
		return false

	_integrate_needs(pet, step, species_cfg)
	pet.clamp_needs()
	_maybe_auto_wake(pet, sim_cursor + step)

	return DeathRules.apply_zero_hold_after_chunk(pet, step, sim_cursor)


static func _integrate_needs(pet: PetModel, step_sec: float, species_cfg: Dictionary) -> void:
	var hours: float = step_sec / 3600.0
	var sleeping: bool = pet.is_sleeping()

	var hunger_rate: float = float(species_cfg.get("hunger_decay_per_hour", 8.0))
	var energy_rate: float = float(species_cfg.get("energy_decay_per_hour", 5.0))
	var happiness_rate: float = float(species_cfg.get("happiness_decay_per_hour", 6.0))
	var hygiene_rate: float = float(species_cfg.get("hygiene_decay_per_hour", 4.0))
	var sleep_regen: float = float(
		species_cfg.get("energy_sleep_regen_per_hour", SimConfig.ENERGY_SLEEP_REGEN_PER_HOUR)
	)

	if sleeping:
		pet.energy += sleep_regen * hours
		pet.hunger -= hunger_rate * SimConfig.SLEEP_HUNGER_MULT * hours
		pet.happiness -= happiness_rate * SimConfig.SLEEP_HAPPINESS_MULT * hours
		pet.hygiene -= hygiene_rate * hours
	else:
		pet.hunger -= hunger_rate * hours
		pet.energy -= energy_rate * hours
		pet.hygiene -= hygiene_rate * hours
		# Happiness with cross-stat mults (awake only for extra pressure)
		var h_mult := 1.0
		if pet.hunger < SimConfig.CROSS_HUNGER_LOW:
			h_mult *= SimConfig.CROSS_HUNGER_HAPPINESS_MULT
		if pet.energy < SimConfig.CROSS_ENERGY_LOW:
			h_mult *= SimConfig.CROSS_ENERGY_HAPPINESS_MULT
		var happy_decay: float = happiness_rate * h_mult * hours
		if pet.hygiene < SimConfig.CROSS_HYGIENE_LOW:
			happy_decay += SimConfig.CROSS_HAPPINESS_EXTRA_PER_HOUR * hours
		pet.happiness -= happy_decay


static func _maybe_auto_wake(pet: PetModel, chunk_end_unix: float) -> void:
	if not pet.is_sleeping():
		return
	if pet.life_state == LifeState.DEAD:
		pet.clear_sleep()
		return
	# Use wall-clock span from when sleep started (persists across restarts).
	var elapsed: float = chunk_end_unix - pet.sleep_started_unix_utc
	if elapsed < 0.0:
		# Clock anomaly: keep sleeping until clocks make sense
		return
	# Hard cap always ends sleep (even if energy still low).
	if elapsed >= SimConfig.MAX_SLEEP_SEC:
		pet.clear_sleep()
		return
	# Energy-based auto-wake only after minimum rest — otherwise a nearly-full
	# energy pet "wakes" on the very next catch-up/reload.
	if elapsed >= SimConfig.MIN_SLEEP_SEC and pet.energy >= SimConfig.AUTO_WAKE_ENERGY:
		pet.clear_sleep()
