class_name ClampUtils
extends RefCounted
## Pure clamp helpers for needs stats.


static func clamp_stat(v: float, lo: float = 0.0, hi: float = 100.0) -> float:
	return clampf(v, lo, hi)


static func clamp_stats_dict(d: Dictionary, lo: float = 0.0, hi: float = 100.0) -> void:
	for k in d.keys():
		d[k] = clampf(float(d[k]), lo, hi)
