extends Node
## Stub — PR2 will implement UTC clock + local day phase.
## Injectable clock for tests later.

func now_unix_utc() -> float:
	return Time.get_unix_time_from_system()


func local_day_phase() -> StringName:
	var h := Time.get_time_dict_from_system()["hour"] as int
	if h >= 5 and h < 11:
		return &"morning"
	if h >= 11 and h < 17:
		return &"day"
	if h >= 17 and h < 21:
		return &"dusk"
	return &"night"
