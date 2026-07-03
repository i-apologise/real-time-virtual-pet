extends RefCounted

const NU := preload("res://src/util/name_utils.gd")


func run() -> Dictionary:
	if NU.NAME_MIN_LEN != 2 or NU.NAME_MAX_LEN != 16:
		return {"ok": false, "message": "NAME_MIN/MAX constants wrong"}

	if not NU.is_valid_name("Bo"):
		return {"ok": false, "message": "Bo should be valid"}
	if not NU.is_valid_name("SixteenCharsHere"):
		return {"ok": false, "message": "16-char should be valid"}
	if NU.is_valid_name("A"):
		return {"ok": false, "message": "1-char invalid"}
	if NU.is_valid_name(""):
		return {"ok": false, "message": "empty invalid"}
	if NU.is_valid_name("ThisNameIsWayTooLongXX"):
		return {"ok": false, "message": "too long invalid"}

	var clean: String = NU.sanitize_name("Hi\nThere\t")
	if clean != "HiThere":
		return {"ok": false, "message": "sanitize control failed: '%s'" % clean}

	if NU.sanitize_name("  Soft Blob  ") != "Soft Blob":
		return {"ok": false, "message": "edge trim / interior space failed"}
	if not NU.is_valid_name("  Soft Blob  "):
		return {"ok": false, "message": "Soft Blob after sanitize should be valid"}

	if NU.accepted_name_or_empty("x") != "":
		return {"ok": false, "message": "accepted_name_or_empty should reject short"}
	if NU.accepted_name_or_empty("  Mochi ") != "Mochi":
		return {"ok": false, "message": "accepted_name_or_empty should return sanitized"}

	if not NU.is_valid_name("CoolPet99"):
		return {"ok": false, "message": "alphanumeric should pass"}

	return {"ok": true, "message": "NameUtils min2 max16 sanitize OK"}
