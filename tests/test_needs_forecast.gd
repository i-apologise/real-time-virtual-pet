extends RefCounted


func run() -> Dictionary:
	var Forecast = load("res://src/sim/needs_forecast.gd")
	var Pet = load("res://src/sim/pet_model.gd")
	var pet = Pet.create_from_species(&"blob", "Eta", 1_700_000_000.0, 0)
	pet.hunger = 80.0
	pet.energy = 80.0
	pet.happiness = 70.0
	pet.hygiene = 80.0
	var fc: Dictionary = Forecast.forecast(pet)
	var hn: float = float(fc.get("hunger_to_needy_sec", -1.0))
	# blob 8/h hunger: (80-40)/8 = 5h = 18000s
	if absf(hn - 18000.0) > 1.0:
		return {"ok": false, "message": "hunger_to_needy expected ~18000 got %s" % hn}
	var s: String = Forecast.format_eta(hn)
	if not ("5h" in s):
		return {"ok": false, "message": "format_eta expected 5h got %s" % s}
	if str(fc.get("summary", "")) == "":
		return {"ok": false, "message": "summary empty"}
	pet.hunger = 30.0
	fc = Forecast.forecast(pet)
	if float(fc.get("hunger_to_needy_sec", -1.0)) != 0.0:
		return {"ok": false, "message": "already needy should be 0"}
	return {"ok": true, "message": "needs forecast ETA OK"}
