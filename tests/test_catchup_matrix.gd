extends RefCounted
## Golden catch-up / death / clock matrix (design PR 3).


func run() -> Dictionary:
	var PetModelScr: GDScript = preload("res://src/sim/pet_model.gd")
	var NeedsSimScr: GDScript = preload("res://src/sim/needs_simulator.gd")
	var CareScr: GDScript = preload("res://src/sim/care_actions.gd")
	var MoodScr: GDScript = preload("res://src/sim/mood_state_machine.gd")

	var t0 := 1_700_000_000.0
	var chunk := 60.0

	# --- 2h neglect: alive, needs drop ---
	var pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	var meta := {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	var now := t0 + 2.0 * 3600.0
	var res = NeedsSimScr.run_catchup(pet, meta, now)
	if str(pet.life_state) == "DEAD":
		return {"ok": false, "message": "2h neglect must not kill"}
	if float(pet.zero_hold_sec) != 0.0 and not bool(pet.any_need_at_zero()):
		return {"ok": false, "message": "2h: zero_hold should be 0 if no stat at 0"}
	if absf(float(pet.hunger) - 64.0) > 1.0:
		return {"ok": false, "message": "2h hunger expected ~64 got %s" % pet.hunger}
	if float(meta["last_sim_unix_utc"]) != now:
		return {"ok": false, "message": "2h: last_sim should commit to now"}
	if bool(res.death_committed_this_call):
		return {"ok": false, "message": "2h: death_committed must be false"}

	# --- 3d neglect: DEAD ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	now = t0 + 3.0 * 86400.0
	res = NeedsSimScr.run_catchup(pet, meta, now)
	if str(pet.life_state) != "DEAD":
		return {
			"ok": false,
			"message": "3d neglect must kill, state=%s hold=%s hunger=%s"
			% [pet.life_state, pet.zero_hold_sec, pet.hunger]
		}
	if str(pet.death_cause) != "neglect":
		return {"ok": false, "message": "3d: cause neglect"}
	if not bool(res.death_committed_this_call):
		return {"ok": false, "message": "3d: death_committed_this_call expected"}
	if float(pet.died_unix_utc) <= t0 or float(pet.died_unix_utc) > now:
		return {"ok": false, "message": "3d: died_unix out of range %s" % pet.died_unix_utc}
	if float(meta["last_sim_unix_utc"]) != now:
		return {"ok": false, "message": "3d: last_sim commit"}

	# --- 7d and 8d capped: DEAD, commit now ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	now = t0 + 7.0 * 86400.0
	res = NeedsSimScr.run_catchup(pet, meta, now)
	if str(pet.life_state) != "DEAD":
		return {"ok": false, "message": "7d must kill"}
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	now = t0 + 8.0 * 86400.0
	res = NeedsSimScr.run_catchup(pet, meta, now)
	if str(pet.life_state) != "DEAD":
		return {"ok": false, "message": "8d (capped 7d integrate) must still kill"}
	if float(meta["last_sim_unix_utc"]) != now:
		return {"ok": false, "message": "8d: last_sim=now after cap"}

	# --- Partial care prevents death ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	pet.hunger = 0.0
	pet.energy = 50.0
	pet.happiness = 50.0
	pet.hygiene = 50.0
	pet.life_state = &"DYING"
	pet.zero_hold_sec = 0.0
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	res = NeedsSimScr.run_catchup(pet, meta, t0 + 3.0 * 3600.0)
	if str(pet.life_state) == "DEAD":
		return {"ok": false, "message": "3h single-zero hold should not kill yet"}
	if float(pet.zero_hold_sec) < 3.0 * 3600.0 - chunk:
		return {"ok": false, "message": "expected ~3h hold got %s" % pet.zero_hold_sec}
	var care: Dictionary = CareScr.try_feed(pet, float(meta["last_sim_unix_utc"]))
	if not bool(care.get("ok", false)):
		return {"ok": false, "message": "feed should work while dying: %s" % care.get("reason")}
	if float(pet.zero_hold_sec) != 0.0:
		return {"ok": false, "message": "feed must reset zero_hold"}
	if str(pet.life_state) == "DEAD":
		return {"ok": false, "message": "feed must prevent death"}

	# --- Multi-zero accelerates via full catch-up ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	pet.hunger = 0.0
	pet.energy = 0.0
	pet.happiness = 50.0
	pet.hygiene = 50.0
	pet.life_state = &"DYING"
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	res = NeedsSimScr.run_catchup(pet, meta, t0 + 3.0 * 3600.0 + 120.0)
	if str(pet.life_state) != "DEAD":
		return {"ok": false, "message": "multi-zero ~3h should kill, hold=%s" % pet.zero_hold_sec}

	# --- Sleep does not prevent starvation death once at 0 ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	pet.hunger = 0.0
	pet.energy = 40.0
	pet.happiness = 50.0
	pet.hygiene = 50.0
	pet.life_state = &"DYING"
	pet.start_sleep(t0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	res = NeedsSimScr.run_catchup(pet, meta, t0 + 6.0 * 3600.0 + 120.0)
	if str(pet.life_state) != "DEAD":
		return {"ok": false, "message": "sleeping at hunger 0 must still die after 6h hold"}

	# --- Already DEAD catch-up ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	pet.life_state = &"DEAD"
	pet.died_unix_utc = t0 - 100.0
	pet.death_cause = &"neglect"
	pet.hunger = 0.0
	var frozen_h: float = float(pet.hunger)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	now = t0 + 2.0 * 86400.0
	res = NeedsSimScr.run_catchup(pet, meta, now)
	if bool(res.death_committed_this_call):
		return {"ok": false, "message": "already DEAD must not set death_committed"}
	if float(pet.hunger) != frozen_h:
		return {"ok": false, "message": "DEAD stats must freeze"}
	if float(meta["last_sim_unix_utc"]) != now:
		return {"ok": false, "message": "DEAD still commits clock"}

	# --- Reverse clock: no change ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	var h_before: float = float(pet.hunger)
	res = NeedsSimScr.run_catchup(pet, meta, t0 - 100.0)
	if not bool(res.stalled) or str(res.stall_reason) != "TIME_WENT_BACKWARDS":
		return {"ok": false, "message": "reverse should stall"}
	if float(pet.hunger) != h_before:
		return {"ok": false, "message": "reverse must not change stats"}
	if float(meta["last_sim_unix_utc"]) != t0:
		return {"ok": false, "message": "reverse must not commit last_sim"}

	# --- Behind max_seen hard stall ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0 + 10_000.0}
	h_before = float(pet.hunger)
	res = NeedsSimScr.run_catchup(pet, meta, t0 + 50.0)
	if not bool(res.stalled) or str(res.stall_reason) != "TIME_BEHIND_MAX_SEEN":
		return {"ok": false, "message": "behind max_seen should stall"}
	if float(pet.hunger) != h_before:
		return {"ok": false, "message": "max_seen stall must not integrate"}
	if float(meta["last_sim_unix_utc"]) != t0:
		return {"ok": false, "message": "max_seen stall no commit"}

	# --- Soft floor off: hunger reaches 0 ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	NeedsSimScr.run_catchup(pet, meta, t0 + 12.0 * 3600.0)
	if float(pet.hunger) > 0.5 and str(pet.life_state) != "DEAD":
		return {"ok": false, "message": "12h from 80 at 8/h should empty hunger, got %s" % pet.hunger}

	# --- Auto-wake after long sleep ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	pet.energy = 50.0
	pet.start_sleep(t0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	NeedsSimScr.run_catchup(pet, meta, t0 + 11.0 * 3600.0)
	if str(pet.life_state) != "DEAD" and bool(pet.is_sleeping()):
		return {"ok": false, "message": "11h sleep should auto-wake if still alive"}

	# --- View dict keys ---
	pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	var vd: Dictionary = pet.to_view_dict(MoodScr.derive_mood(pet))
	for k in [
		"id", "name", "species_id", "hunger", "energy", "happiness", "hygiene",
		"life_state", "is_sleeping", "zero_hold_sec", "mood"
	]:
		if not vd.has(k):
			return {"ok": false, "message": "view dict missing %s" % k}

	return {"ok": true, "message": "catch-up / death golden matrix OK"}
