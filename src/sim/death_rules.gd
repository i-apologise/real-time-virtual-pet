class_name DeathRules
extends RefCounted
## Hold-at-zero death helpers. Pure pet mutation only — never touches profile.


static func recompute_life_state_from_stats(pet: PetModel) -> void:
	if pet.life_state == LifeState.DEAD:
		return
	var any_zero: bool = pet.any_need_at_zero()
	if any_zero:
		pet.life_state = LifeState.DYING
		return
	var mn: float = pet.min_need()
	if mn < SimConfig.CRITICAL_THRESHOLD:
		pet.life_state = LifeState.CRITICAL
	elif mn < SimConfig.NEEDY_THRESHOLD:
		pet.life_state = LifeState.NEEDY
	else:
		pet.life_state = LifeState.HEALTHY


## Pure pet mutation only. Returns true if this call newly transitioned into DEAD.
static func commit_death(pet: PetModel, died_at_unix: float, cause: StringName = &"neglect") -> bool:
	if pet.life_state == LifeState.DEAD:
		return false
	pet.life_state = LifeState.DEAD
	pet.died_unix_utc = died_at_unix
	pet.death_cause = cause
	pet.clear_sleep()
	pet.buried = false
	return true


## Update zero_hold after needs integrated for `step` seconds at end of chunk.
## Returns true if death was newly committed.
static func apply_zero_hold_after_chunk(pet: PetModel, step: float, sim_cursor: float) -> bool:
	if pet.life_state == LifeState.DEAD:
		return false
	var any_zero: bool = pet.any_need_at_zero()
	var zero_count: int = pet.zero_need_count()
	var hold_delta := 0.0
	if not any_zero:
		pet.zero_hold_sec = 0.0
		hold_delta = 0.0
	else:
		var hold_rate: float = (
			SimConfig.DEATH_MULTI_ZERO_HOLD_RATE if zero_count >= 2 else 1.0
		)
		hold_delta = step * hold_rate
		pet.zero_hold_sec += hold_delta

	if pet.zero_hold_sec >= SimConfig.DEATH_AT_ZERO_HOLD_SEC:
		var overshoot: float = pet.zero_hold_sec - SimConfig.DEATH_AT_ZERO_HOLD_SEC
		var frac := 1.0
		if hold_delta > 0.0:
			frac = clampf(1.0 - overshoot / hold_delta, 0.0, 1.0)
		var died_at: float = sim_cursor + step * frac
		return commit_death(pet, died_at, &"neglect")

	recompute_life_state_from_stats(pet)
	return false


## After care actions that may clear zeros.
static func after_care_stats_changed(pet: PetModel) -> void:
	if pet.life_state == LifeState.DEAD:
		return
	pet.clamp_needs()
	if not pet.any_need_at_zero():
		pet.zero_hold_sec = 0.0
	recompute_life_state_from_stats(pet)
