extends RefCounted
## Scene scripts/resources exist and load.


func run() -> Dictionary:
	var paths := [
		"res://scenes/habitat/habitat.tscn",
		"res://scenes/habitat/habitat.gd",
		"res://scenes/graveyard/graveyard.tscn",
		"res://scenes/store/pet_store.tscn",
		"res://scenes/store/pet_store.gd",
		"res://scenes/town/town.tscn",
		"res://scenes/park/park.tscn",
		"res://scenes/park/park.gd",
		"res://scenes/main.tscn",
		"res://scenes/ui/tutorial.tscn",
	]
	for p in paths:
		if not ResourceLoader.exists(p):
			return {"ok": false, "message": "missing %s" % p}
		if load(p) == null:
			return {"ok": false, "message": "load failed %s" % p}
	var router_script: GDScript = load("res://src/autoload/scene_router.gd") as GDScript
	var node: Node = router_script.new() as Node
	var label: String = str(node.call("describe_poi", 1))
	node.free()
	if label != "Player House":
		return {"ok": false, "message": "poi label %s" % label}
	return {"ok": true, "message": "habitat/store/park/graveyard/town scenes load OK"}
