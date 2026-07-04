class_name NeedsForecast
extends RefCounted
## Pure helpers: time-until need thresholds from current stats + species decay rates.


static func forecast(pet: PetModel) -> Dictionary:
	## Returns seconds until key thresholds (0 = already there, -1 = not applicable / infinite).
	var empty := {
		"hunger_to_needy_sec": -1.0,
		"hunger_to_critical_sec": -1.0,
		"hunger_to_zero_sec": -1.0,
		"energy_to_needy_sec": -1.0,
		"energy_to_critical_sec": -1.0,
		"energy_to_sleepy_sec": -1.0,
		"happiness_to_needy_sec": -1.0,
		"hygiene_to_needy_sec": -1.0,
		"sleeping": false,
		"summary": "",
	}
	if pet == null or pet.life_state == LifeState.DEAD:
		return empty

	var cfg: Dictionary = SpeciesCatalog.rates_for(pet.species_id)
	if cfg.is_empty():
		cfg = SpeciesCatalog.rates_for(&"blob")

	var sleeping: bool = pet.is_sleeping()
	var h_rate: float = float(cfg.get("hunger_decay_per_hour", 8.0))
	var e_rate: float = float(cfg.get("energy_decay_per_hour", 5.0))
	var happy_rate: float = float(cfg.get("happiness_decay_per_hour", 6.0))
	var hyg_rate: float = float(cfg.get("hygiene_decay_per_hour", 4.0))
	var sleep_regen: float = float(
		cfg.get("energy_sleep_regen_per_hour", SimConfig.ENERGY_SLEEP_REGEN_PER_HOUR)
	)

	# While sleeping, hunger/happiness/hygiene still decay (slower for some); energy rises.
	if sleeping:
		h_rate *= SimConfig.SLEEP_HUNGER_MULT
		happy_rate *= SimConfig.SLEEP_HAPPINESS_MULT
		e_rate = 0.0  # not decaying; regenerating

	var out := {
		"hunger_to_needy_sec": _sec_until_below(pet.hunger, h_rate, SimConfig.NEEDY_THRESHOLD),
		"hunger_to_critical_sec": _sec_until_below(pet.hunger, h_rate, SimConfig.CRITICAL_THRESHOLD),
		"hunger_to_zero_sec": _sec_until_below(pet.hunger, h_rate, 0.0),
		"energy_to_needy_sec": _sec_until_below(pet.energy, e_rate, SimConfig.NEEDY_THRESHOLD),
		"energy_to_critical_sec": _sec_until_below(pet.energy, e_rate, SimConfig.CRITICAL_THRESHOLD),
		# "Sleepy" when energy would hit 35 (recommend nap before needy)
		"energy_to_sleepy_sec": _sec_until_below(pet.energy, e_rate, 35.0),
		"happiness_to_needy_sec": _sec_until_below(pet.happiness, happy_rate, SimConfig.NEEDY_THRESHOLD),
		"hygiene_to_needy_sec": _sec_until_below(pet.hygiene, hyg_rate, SimConfig.NEEDY_THRESHOLD),
		"sleeping": sleeping,
		"energy_full_in_sec": -1.0,
	}

	if sleeping and sleep_regen > 0.0:
		# time until energy full / auto-wake threshold
		var target: float = minf(SimConfig.STAT_MAX, SimConfig.AUTO_WAKE_ENERGY)
		if pet.energy >= target:
			out["energy_full_in_sec"] = 0.0
		else:
			out["energy_full_in_sec"] = ((target - pet.energy) / sleep_regen) * 3600.0

	out["summary"] = _summary_line(out, pet)
	return out


static func _sec_until_below(current: float, decay_per_hour: float, threshold: float) -> float:
	if decay_per_hour <= 0.001:
		return -1.0
	if current <= threshold:
		return 0.0
	return ((current - threshold) / decay_per_hour) * 3600.0


static func format_eta(sec: float) -> String:
	if sec < 0.0:
		return "—"
	if sec <= 0.0:
		return "now"
	if sec < 60.0:
		return "<1m"
	if sec < 3600.0:
		return "%dm" % int(ceil(sec / 60.0))
	var h := int(sec / 3600.0)
	var m := int(fmod(sec, 3600.0) / 60.0)
	if h >= 48:
		return "%dd" % int(ceil(sec / 86400.0))
	if m <= 0:
		return "%dh" % h
	return "%dh%02dm" % [h, m]


static func _summary_line(fc: Dictionary, pet: PetModel) -> String:
	if bool(fc.get("sleeping", false)):
		var wake_in: float = float(fc.get("energy_full_in_sec", -1.0))
		if wake_in >= 0.0:
			return "Zzz · full energy in %s" % format_eta(wake_in)
		return "Zzz · sleeping"
	var parts: Array[String] = []
	var hn: float = float(fc.get("hunger_to_needy_sec", -1.0))
	var es: float = float(fc.get("energy_to_sleepy_sec", -1.0))
	var hp: float = float(fc.get("happiness_to_needy_sec", -1.0))
	if hn >= 0.0:
		parts.append("hungry in %s" % format_eta(hn))
	if es >= 0.0:
		parts.append("sleepy in %s" % format_eta(es))
	if hp >= 0.0 and hp < 6.0 * 3600.0:
		parts.append("lonely in %s" % format_eta(hp))
	if parts.is_empty():
		return "%s is content" % pet.name
	return " · ".join(parts)
