extends Node
## Routes between tutorial / habitat / graveyard / store / town.

enum Poi { TOWN, HOUSE, PARK, STORE, GRAVEYARD }

const SCENE_PATHS := {
	"habitat": "res://scenes/habitat/habitat.tscn",
	"main": "res://scenes/main.tscn",
	"graveyard": "res://scenes/graveyard/graveyard.tscn",
	"pet_store": "res://scenes/store/pet_store.tscn",
	"town": "res://scenes/town/town.tscn",
	"tutorial": "res://scenes/ui/tutorial.tscn",
}

var current_scene_id: String = "main"


func describe_poi(poi: Poi) -> String:
	match poi:
		Poi.TOWN:
			return "Town"
		Poi.HOUSE:
			return "Player House"
		Poi.PARK:
			return "Pet Park"
		Poi.STORE:
			return "Pet Store"
		Poi.GRAVEYARD:
			return "Graveyard"
		_:
			return "Unknown"


func bind_host(_host: Node) -> void:
	pass


func go(scene_id: String) -> void:
	var path: String = str(SCENE_PATHS.get(scene_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		push_warning("SceneRouter: missing scene %s" % scene_id)
		return
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_warning("SceneRouter: failed to open %s err=%s" % [path, err])
		return
	current_scene_id = scene_id
