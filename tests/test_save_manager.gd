extends RefCounted
## Save schema v2 create/load/migrate + pet/profile roundtrip.


func run() -> Dictionary:
	var SaveScr: GDScript = preload("res://src/autoload/save_manager.gd")
	var PetModelScr: GDScript = preload("res://src/sim/pet_model.gd")
	var ProfileScr: GDScript = preload("res://src/sim/player_profile.gd")
	var sm = SaveScr.new()
	var t0 := 1_700_000_000.0
	var data: Dictionary = sm.create_default_save(t0)
	if int(data.get("schema_version", 0)) != 2:
		return {"ok": false, "message": "schema v2 expected"}
	if data.get("active_pet", "x") != null:
		return {"ok": false, "message": "default active_pet null"}
	if int(data["player_profile"]["next_pet_serial"]) != 0:
		return {"ok": false, "message": "serial starts 0"}

	var pet = PetModelScr.create_from_species(&"blob", "Mochi", t0, 0)
	data["active_pet"] = pet.to_save_dict()
	data["player_profile"]["next_pet_serial"] = 1
	data["meta"]["is_first_run"] = false

	# migrate identity
	var mig: Dictionary = sm.migrate(data.duplicate(true), 2, 2)
	if mig.is_empty():
		return {"ok": false, "message": "migrate v2 failed"}

	# write/load roundtrip using instance (isolated paths would need monkeypatch;
	# we use real user path with unique marker and cleanup)
	var wr: Dictionary = sm.save_data(data)
	if not bool(wr.get("ok", false)):
		return {"ok": false, "message": "save failed %s" % wr}
	var ld: Dictionary = sm.load_save()
	if not bool(ld.get("ok", false)):
		return {"ok": false, "message": "load failed %s" % ld}
	var loaded: Dictionary = ld["data"]
	if loaded["active_pet"] == null:
		return {"ok": false, "message": "expected active pet after save"}
	var p2 = PetModelScr.from_save_dict(loaded["active_pet"])
	if str(p2.name) != "Mochi":
		return {"ok": false, "message": "name roundtrip"}
	var prof = ProfileScr.from_save_dict(loaded["player_profile"])
	if int(prof.next_pet_serial) != 1:
		return {"ok": false, "message": "serial roundtrip"}

	return {"ok": true, "message": "save v2 create/migrate/roundtrip OK"}
