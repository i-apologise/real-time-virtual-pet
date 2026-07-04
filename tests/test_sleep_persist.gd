extends RefCounted
## Sleep must survive short restarts; high energy must not auto-wake before MIN_SLEEP.


func run() -> Dictionary:
	var Pet = load("res://src/sim/pet_model.gd")
	var Needs = load("res://src/sim/needs_simulator.gd")
	var Config = load("res://src/sim/sim_config.gd")
	var t0 := 1_700_000_000.0
	var pet = Pet.create_from_species(&"blob", "Mochi", t0, 1)
	pet.energy = 99.0  # nearly full — old bug auto-woke immediately
	pet.start_sleep(t0)
	if not pet.is_sleeping():
		return {"ok": false, "message": "should be sleeping after start_sleep"}

	# Simulate save/load
	var d: Dictionary = pet.to_save_dict()
	var pet2 = Pet.from_save_dict(d)
	if not pet2.is_sleeping():
		return {"ok": false, "message": "sleep must survive save dict, sleep_started=%s" % pet2.sleep_started_unix_utc}
	if absf(float(d.get("sleep_started_unix_utc", 0)) - t0) > 0.01:
		return {"ok": false, "message": "save missing sleep timestamp"}

	# Catch-up 5 minutes later: still sleeping despite high energy
	var meta := {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	var now := t0 + 300.0
	Needs.run_catchup(pet2, meta, now)
	if not pet2.is_sleeping():
		return {"ok": false, "message": "must still sleep after 5m with high energy (min sleep 30m)"}

	# After min sleep + high energy: may auto-wake
	meta = {"last_sim_unix_utc": now, "max_seen_unix_utc": now}
	var later := t0 + float(Config.MIN_SLEEP_SEC) + 60.0
	pet2.energy = 99.0
	Needs.run_catchup(pet2, meta, later)
	if pet2.is_sleeping():
		return {"ok": false, "message": "should auto-wake after MIN_SLEEP with high energy"}

	# Long sleep only (low energy): wake at MAX not before min with low energy path
	var pet3 = Pet.create_from_species(&"blob", "Nap", t0, 2)
	pet3.energy = 40.0
	pet3.start_sleep(t0)
	meta = {"last_sim_unix_utc": t0, "max_seen_unix_utc": t0}
	Needs.run_catchup(pet3, meta, t0 + 600.0)  # 10 min
	if not pet3.is_sleeping():
		return {"ok": false, "message": "low energy still sleeping at 10m"}

	return {"ok": true, "message": "sleep persists across save/short catch-up; min sleep gates auto-wake"}
