extends RefCounted
## Debug offset advances TimeService.now without breaking override path.


func run() -> Dictionary:
	# Autoload TimeService is available under project runs
	var before: float = TimeService.now_unix_utc()
	TimeService.add_debug_offset_sec(3600.0)
	var after: float = TimeService.now_unix_utc()
	if after - before < 3599.0:
		TimeService.reset_debug_offset()
		return {"ok": false, "message": "expected +1h offset"}
	TimeService.reset_debug_offset()
	var back: float = TimeService.now_unix_utc()
	if absf(back - before) > 2.0:
		return {"ok": false, "message": "reset offset failed"}
	return {"ok": true, "message": "debug clock offset OK"}
