extends SceneTree
## Zero-dependency test runner.
## Usage: godot --headless --path . -s res://tests/run_tests.gd

const TEST_SCRIPTS := [
	"res://tests/test_bootstrap.gd",
	"res://tests/test_time_utils.gd",
	"res://tests/test_name_utils.gd",
	"res://tests/test_species_catalog.gd",
	"res://tests/test_death_rules.gd",
	"res://tests/test_catchup_matrix.gd",
	"res://tests/test_care_actions.gd",
]


func _initialize() -> void:
	var failed := 0
	var passed := 0
	print("=== Real-Time Virtual Pet — test runner ===")
	for path in TEST_SCRIPTS:
		if not ResourceLoader.exists(path):
			print("FAIL  missing test script: ", path)
			failed += 1
			continue
		var script: GDScript = load(path) as GDScript
		if script == null:
			print("FAIL  could not load: ", path)
			failed += 1
			continue
		var inst = script.new()
		if not inst.has_method("run"):
			print("FAIL  no run() in: ", path)
			failed += 1
			continue
		var result: Variant = inst.call("run")
		if result is Dictionary and result.get("ok", false):
			print("PASS  ", path, " — ", result.get("message", "ok"))
			passed += 1
		else:
			var msg := str(result.get("message", result)) if result is Dictionary else str(result)
			print("FAIL  ", path, " — ", msg)
			failed += 1
	print("=== results: passed=%d failed=%d ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
