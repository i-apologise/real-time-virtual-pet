extends RefCounted

const TU := preload("res://src/util/time_utils.gd")


func run() -> Dictionary:
	var cases := {
		0: &"night",
		4: &"night",
		5: &"dawn",
		7: &"dawn",
		8: &"day",
		12: &"day",
		17: &"day",
		18: &"dusk",
		20: &"dusk",
		21: &"night",
		23: &"night",
	}
	for hour in cases.keys():
		var got: StringName = TU.phase_from_hour(int(hour))
		var want: StringName = cases[hour]
		if got != want:
			return {"ok": false, "message": "hour %s expected %s got %s" % [hour, want, got]}

	if not TU.is_day_hour(10) or TU.is_night_hour(10):
		return {"ok": false, "message": "day hour flags wrong"}
	if not TU.is_night_hour(22) or TU.is_day_hour(22):
		return {"ok": false, "message": "night hour flags wrong"}

	if abs(TU.delta_seconds(100.0, 250.5) - 150.5) > 0.001:
		return {"ok": false, "message": "delta_seconds wrong"}

	if TU.clamp_forward_dt(-5.0, 100.0) != 0.0:
		return {"ok": false, "message": "negative dt should clamp to 0"}
	if TU.clamp_forward_dt(999.0, 100.0) != 100.0:
		return {"ok": false, "message": "max catchup clamp failed"}
	if TU.clamp_forward_dt(50.0, 100.0) != 50.0:
		return {"ok": false, "message": "in-range dt should pass"}

	var fmt: String = TU.format_duration(3661.0)
	if not ("1h" in fmt and "1m" in fmt):
		return {"ok": false, "message": "format_duration unexpected: %s" % fmt}

	var fixed := 1_700_000_000.0
	TimeService.set_clock_override(func() -> float: return fixed)
	if abs(TimeService.now_unix_utc() - fixed) > 0.001:
		TimeService.clear_clock_override()
		return {"ok": false, "message": "clock override failed"}
	if not TimeService.has_clock_override():
		TimeService.clear_clock_override()
		return {"ok": false, "message": "has_clock_override expected true"}
	TimeService.clear_clock_override()
	if TimeService.has_clock_override():
		return {"ok": false, "message": "clear_clock_override failed"}
	var live := TimeService.now_unix_utc()
	var sys := float(Time.get_unix_time_from_system())
	if abs(live - sys) > 2.0:
		return {"ok": false, "message": "live clock drift too large"}

	var phase: StringName = TimeService.local_day_phase()
	if phase != &"dawn" and phase != &"day" and phase != &"dusk" and phase != &"night":
		return {"ok": false, "message": "unexpected phase: %s" % str(phase)}

	return {"ok": true, "message": "TimeUtils + TimeService clock injection OK"}
