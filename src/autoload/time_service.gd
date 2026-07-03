extends Node
## Wall-clock access for sim and presentation.
## UTC for simulation authority; local datetime for day phase / UI only.

const _TimeUtils := preload("res://src/util/time_utils.gd")

var _clock_override: Callable = Callable()
## Debug-only additive offset (seconds). Used with F7/F8 playtest advance.
var debug_offset_sec: float = 0.0


func set_clock_override(clock: Callable) -> void:
	_clock_override = clock


func clear_clock_override() -> void:
	_clock_override = Callable()


func has_clock_override() -> bool:
	return _clock_override.is_valid()


func add_debug_offset_sec(delta: float) -> void:
	if not OS.is_debug_build() and not OS.has_feature("editor"):
		return
	debug_offset_sec += delta


func reset_debug_offset() -> void:
	debug_offset_sec = 0.0


func now_unix_utc() -> float:
	if _clock_override.is_valid():
		return float(_clock_override.call())
	return float(Time.get_unix_time_from_system()) + debug_offset_sec


func local_datetime() -> Dictionary:
	var unix := now_unix_utc()
	if _clock_override.is_valid() or debug_offset_sec != 0.0:
		return Time.get_datetime_dict_from_unix_time(int(unix))
	return Time.get_datetime_dict_from_system()


func local_day_phase() -> StringName:
	var h: int = int(local_datetime().get("hour", 0))
	return _TimeUtils.phase_from_hour(h)


func is_local_night() -> bool:
	return local_day_phase() == &"night"


func is_local_day() -> bool:
	return local_day_phase() == &"day"
