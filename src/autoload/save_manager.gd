extends Node
## JSON save/load schema v2. Fixed paths only. No user-supplied paths.

const SAVE_DIR := "user://saves"
const SAVE_PATH := "user://saves/pet_save.json"
const BAK_PATH := "user://saves/pet_save.bak"
const TMP_PATH := "user://saves/pet_save.tmp"
const SCHEMA_VERSION := 2
const APP_VERSION := "0.1.0-dev"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func create_default_save(now: float = -1.0) -> Dictionary:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	return {
		"schema_version": SCHEMA_VERSION,
		"active_pet": null,
		"player_profile": {
			"total_pets_died": 0,
			"total_graves_dug": 0,
			"next_pet_serial": 0,
			"graves": [],
		},
		"meta": {
			"last_sim_unix_utc": now,
			"max_seen_unix_utc": now,
			"timezone_offset_at_save_sec": _tz_offset_sec(),
			"created_unix_utc": now,
			"is_first_run": true,
			"app_version": APP_VERSION,
			"content_hash": "",
			"graveyard_cols": SimConfig.GRAVEYARD_COLS,
			"graveyard_rows_hint": SimConfig.GRAVEYARD_ROWS,
		},
	}


func load_save() -> Dictionary:
	if not has_save():
		return {"ok": false, "error": &"NO_SAVE"}
	var raw := _read_json_file(SAVE_PATH)
	if raw.is_empty():
		# try backup
		if FileAccess.file_exists(BAK_PATH):
			raw = _read_json_file(BAK_PATH)
		if raw.is_empty():
			return {"ok": false, "error": &"CORRUPT_SAVE"}
	var migrated: Dictionary = migrate(raw, int(raw.get("schema_version", 0)), SCHEMA_VERSION)
	if migrated.is_empty():
		return {"ok": false, "error": &"MIGRATE_FAILED"}
	return {"ok": true, "data": migrated}


func save_data(data: Dictionary) -> Dictionary:
	ensure_save_dir()
	var payload: Dictionary = data.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	if payload.has("meta") and payload["meta"] is Dictionary:
		payload["meta"]["timezone_offset_at_save_sec"] = _tz_offset_sec()
		payload["meta"]["app_version"] = APP_VERSION
	var text := JSON.stringify(payload, "\t")
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": &"WRITE_FAILED"}
	f.store_string(text)
	f.flush()
	f.close()
	# refresh bak from current save if present
	if FileAccess.file_exists(SAVE_PATH):
		var prev := FileAccess.get_file_as_string(SAVE_PATH)
		var bf := FileAccess.open(BAK_PATH, FileAccess.WRITE)
		if bf:
			bf.store_string(prev)
			bf.close()
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return {"ok": false, "error": &"DIR_FAILED"}
	if FileAccess.file_exists(SAVE_PATH):
		dir.remove("pet_save.json")
	var err := dir.rename("pet_save.tmp", "pet_save.json")
	if err != OK:
		# fallback copy
		var tf := FileAccess.open(TMP_PATH, FileAccess.READ)
		var sf := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if tf == null or sf == null:
			return {"ok": false, "error": &"RENAME_FAILED"}
		sf.store_string(tf.get_as_text())
		sf.close()
		tf.close()
	return {"ok": true}


## Scaffold for future versions; greenfield ships v2 only.
func migrate(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	if to_version != SCHEMA_VERSION:
		return {}
	if from_version == 0 or from_version == SCHEMA_VERSION:
		# Accept missing version as soft v2-shaped if keys present
		if not data.has("player_profile"):
			data["player_profile"] = create_default_save()["player_profile"]
		if not data.has("meta"):
			data["meta"] = create_default_save()["meta"]
		data["schema_version"] = SCHEMA_VERSION
		return data
	if from_version < SCHEMA_VERSION:
		# future: stepwise migrators
		data["schema_version"] = SCHEMA_VERSION
		return data
	return data


func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _tz_offset_sec() -> int:
	# Godot 4: get_time_zone_from_system returns bias in minutes on some versions
	var tz: Dictionary = Time.get_time_zone_from_system()
	if tz.has("bias"):
		return int(tz["bias"]) * 60
	return 0
