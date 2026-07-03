class_name GraveRecord
extends RefCounted
## Archived grave identity (historical only — no live rates).

var id: String = ""
var pet_id: String = ""
var name: String = ""
var species_id: StringName = &"blob"
var born_unix_utc: float = 0.0
var died_unix_utc: float = 0.0
var buried_unix_utc: float = 0.0
var cause: StringName = &"neglect"
var plot_index: int = 0
var plot_x: int = 0
var plot_y: int = 0
var epitaph: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id,
		"pet_id": pet_id,
		"name": name,
		"species_id": str(species_id),
		"born_unix_utc": born_unix_utc,
		"died_unix_utc": died_unix_utc,
		"buried_unix_utc": buried_unix_utc,
		"cause": str(cause),
		"plot_index": plot_index,
		"plot_x": plot_x,
		"plot_y": plot_y,
		"epitaph": epitaph,
	}


static func from_dict(d: Dictionary) -> GraveRecord:
	var g := GraveRecord.new()
	g.id = str(d.get("id", ""))
	g.pet_id = str(d.get("pet_id", ""))
	g.name = str(d.get("name", ""))
	g.species_id = StringName(str(d.get("species_id", "blob")))
	g.born_unix_utc = float(d.get("born_unix_utc", 0.0))
	g.died_unix_utc = float(d.get("died_unix_utc", 0.0))
	g.buried_unix_utc = float(d.get("buried_unix_utc", 0.0))
	g.cause = StringName(str(d.get("cause", "neglect")))
	g.plot_index = int(d.get("plot_index", 0))
	g.plot_x = int(d.get("plot_x", 0))
	g.plot_y = int(d.get("plot_y", 0))
	g.epitaph = str(d.get("epitaph", ""))
	return g
