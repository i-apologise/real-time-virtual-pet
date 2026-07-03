class_name TimeUtils
extends RefCounted
## Pure time helpers — no scene tree, no OS clock (pass values in).

## Design phases (local hour, presentation only; never use in passive decay).
## dawn: [5, 8)  day: [8, 18)  dusk: [18, 21)  night: otherwise
static func phase_from_hour(hour: int) -> StringName:
	var h := hour % 24
	if h < 0:
		h += 24
	if h >= 5 and h < 8:
		return &"dawn"
	if h >= 8 and h < 18:
		return &"day"
	if h >= 18 and h < 21:
		return &"dusk"
	return &"night"


static func is_night_hour(hour: int) -> bool:
	return phase_from_hour(hour) == &"night"


static func is_day_hour(hour: int) -> bool:
	return phase_from_hour(hour) == &"day"


## Elapsed seconds between two unix timestamps (can be negative if reversed).
static func delta_seconds(from_unix: float, to_unix: float) -> float:
	return to_unix - from_unix


## Clamp a non-negative duration to max_sec (for MAX_CATCHUP-style caps later).
static func clamp_forward_dt(raw_dt: float, max_sec: float) -> float:
	if raw_dt < 0.0:
		return 0.0
	if max_sec >= 0.0 and raw_dt > max_sec:
		return max_sec
	return raw_dt


## Human-readable duration for debug HUD (e.g. "2h 5m").
static func format_duration(seconds: float) -> String:
	var s := int(floor(abs(seconds)))
	var neg := seconds < 0.0
	var days := s / 86400
	s = s % 86400
	var hours := s / 3600
	s = s % 3600
	var mins := s / 60
	s = s % 60
	var parts: PackedStringArray = []
	if days > 0:
		parts.append("%dd" % days)
	if hours > 0:
		parts.append("%dh" % hours)
	if mins > 0:
		parts.append("%dm" % mins)
	if parts.is_empty() or (days == 0 and hours == 0 and mins == 0 and s > 0):
		parts.append("%ds" % s)
	var out := " ".join(parts)
	return ("-" + out) if neg else out
