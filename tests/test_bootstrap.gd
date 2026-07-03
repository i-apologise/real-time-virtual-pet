extends RefCounted
## PR1 smoke tests.


func run() -> Dictionary:
	var required_scripts := [
		"res://scenes/main.gd",
		"res://src/autoload/time_service.gd",
		"res://src/autoload/event_bus.gd",
		"res://src/autoload/save_manager.gd",
		"res://src/autoload/pet_controller.gd",
		"res://src/autoload/scene_router.gd",
		"res://tests/run_tests.gd",
	]
	for path in required_scripts:
		if not ResourceLoader.exists(path):
			return {"ok": false, "message": "missing %s" % path}
		if load(path) == null:
			return {"ok": false, "message": "load failed %s" % path}

	if not ResourceLoader.exists("res://scenes/main.tscn"):
		return {"ok": false, "message": "missing main.tscn"}

	if not _valid_name_len("Bo"):
		return {"ok": false, "message": "expected Bo valid"}
	if not _valid_name_len("SixteenCharsHere"):
		return {"ok": false, "message": "expected 16-char name valid"}
	if _valid_name_len("A") or _valid_name_len("") or _valid_name_len("ThisNameIsWayTooLongXX"):
		return {"ok": false, "message": "name length bounds failed"}

	var router_script: GDScript = load("res://src/autoload/scene_router.gd") as GDScript
	var node: Node = router_script.new() as Node
	var label: String = str(node.call("describe_poi", 1))
	node.free()
	if label != "Player House":
		return {"ok": false, "message": "SceneRouter.describe_poi mismatch: %s" % label}

	return {"ok": true, "message": "bootstrap layout + name len preview + SceneRouter OK"}


func _valid_name_len(s: String) -> bool:
	return s.length() >= 2 and s.length() <= 16
