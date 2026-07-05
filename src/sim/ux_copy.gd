class_name UxCopy
extends RefCounted
## Human-readable strings for care failures and status (presentation only).


static func care_fail_message(reason: String, action: String = "") -> String:
	var a := action.capitalize() if action != "" else "That"
	match String(reason):
		"PET_SLEEPING":
			return "Zzz… wake them first (CARE → WAKE)"
		"ALREADY_SLEEPING":
			return "Already asleep — Zzz…"
		"NOT_SLEEPING":
			return "They're already awake"
		"PET_DEAD":
			return "They're gone — use the backyard to dig"
		"NO_ACTIVE_PET", "NO_ACTORS":
			return "No pet here — adopt at the Store"
		"BUSY":
			return "Still busy — wait a second"
		"COOLDOWN":
			return "%s needs a short rest — try again soon" % a
		"ENERGY_TOO_LOW":
			return "Too tired — let them sleep first"
		"UNKNOWN_ACTION":
			return "That action isn't available"
		"NOT_ENOUGH_POINTS":
			return "Need more care points (earn by caring at home / park)"
		"ALREADY_OWNED":
			return "You already own that item"
		"UNKNOWN_ITEM":
			return "That item isn't for sale"
		"HAS_ACTIVE_PET":
			return "You already have a living pet"
		"MUST_BURY_FIRST":
			return "Bury your pet in the backyard first"
		"INVALID_NAME":
			return "Name needs 2–16 letters"
		"INVALID_SPECIES":
			return "Pick a pen first"
		"INVALID_ARGS":
			return "Couldn't complete that"
		"PET_NOT_DEAD":
			return "Nothing to bury right now"
		"ALREADY_BURIED":
			return "Already laid to rest"
		_:
			if reason == "":
				return "Couldn't do that"
			# Never surface raw SCREAMING_SNAKE enums to players
			return "Couldn't do that right now"


static func first_care_points_tip() -> String:
	return "Earned care points (❤) — spend them at the Pet Store"


static func first_park_bonus_tip() -> String:
	return "Outdoor bonus active — park play earns extra happiness & ❤"


static func care_start_blocked(pet: PetModel, action: StringName) -> Dictionary:
	## Returns {ok:true} or {ok:false, reason, message} without mutating pet.
	if pet == null:
		return {"ok": false, "reason": &"NO_ACTIVE_PET", "message": care_fail_message("NO_ACTIVE_PET")}
	if pet.life_state == LifeState.DEAD:
		return {"ok": false, "reason": &"PET_DEAD", "message": care_fail_message("PET_DEAD")}
	var act := String(action)
	if pet.is_sleeping():
		if act == "wake":
			return {"ok": true}
		if act == "sleep":
			return {
				"ok": false,
				"reason": &"ALREADY_SLEEPING",
				"message": care_fail_message("ALREADY_SLEEPING"),
			}
		return {
			"ok": false,
			"reason": &"PET_SLEEPING",
			"message": care_fail_message("PET_SLEEPING", act),
		}
	if act == "wake":
		return {
			"ok": false,
			"reason": &"NOT_SLEEPING",
			"message": care_fail_message("NOT_SLEEPING"),
		}
	return {"ok": true}


static func action_available(pet: PetModel, action: String) -> bool:
	if pet == null or pet.life_state == LifeState.DEAD:
		return action == "cancel"
	if action == "cancel":
		return true
	if pet.is_sleeping():
		return action == "wake"
	if action == "wake":
		return false
	return true
