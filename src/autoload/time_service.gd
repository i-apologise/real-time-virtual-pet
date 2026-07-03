extends Node
## Wall-clock access for sim and presentation.
## UTC for simulation authority; local datetime for day phase / UI only.

const _TimeUtils := preload("res://src/util/time_utils.gd")

var _clock_override: Callable = Callable()


func set_clock_override(clock: Callable) -> void:
	_clock_override = clock


func clear_clock_override() -> void:
	_clock_override = Callable()


func has_clock_override() -> bool:
	return _clock_override.is_valid()


func now_unix_utc() -> float:
	if _clock_override.is_valid():
		return float(_clock_override.call())
	return float(Time.get_unix_time_from_system())


func local_datetime() -> Dictionary:
	if _clock_override.is_valid():
		var unix := float(_clock_override.call())
		return Time.get_datetime_dict_from_unix_time(int(unix))
	return Time.get_datetime_dict_from_system()


func local_day_phase() -> StringName:
	var h: int = int(local_datetime().get("hour", 0))
	return _TimeUtils.phase_from_hour(h)


func is_local_night() -> bool:
	return local_day_phase() == &"night"


func is_local_day() -> bool:
	return local_day_phase() == &"day"
