extends Node
## Orchestrates catch-up, care, adopt, burial, counters. Owns profile mutation on death.

var active_pet: PetModel = null
var profile: PlayerProfile = PlayerProfile.new()
var meta: Dictionary = {}
var _tick_accum: float = 0.0
var _autosave_accum: float = 0.0
var _booted: bool = false
var last_catchup_result: CatchupResult = null
var last_status: Dictionary = {"message": "", "priority": 0}
## Outdoor leash walk: pet sticks to human across scenes until walk ends.
var escort_active: bool = false
var escort_elapsed_sec: float = 0.0
var escort_visited_park: bool = false
const ESCORT_MIN_SEC := 10.0
## Emotional burial path: carry the body home → backyard (not a teleport).
var carrying_deceased: bool = false
## Set on each focus/boot catch-up for session summary UI.
var last_session_summary: Dictionary = {}
var _session_banner_pending: bool = false


func start_escort() -> void:
	if carrying_deceased:
		return
	escort_active = true
	escort_elapsed_sec = 0.0
	escort_visited_park = false


func note_park_visit() -> void:
	if escort_active:
		escort_visited_park = true


func tick_escort(delta: float) -> void:
	if escort_active:
		escort_elapsed_sec += delta


func can_finish_escort() -> bool:
	return escort_active and escort_elapsed_sec >= ESCORT_MIN_SEC


func end_escort(apply_walk_care: bool = true) -> Dictionary:
	## Clears escort. Optionally applies WALK care reward once (park bonus if visited).
	var park_bonus := escort_visited_park
	escort_active = false
	escort_visited_park = false
	var result := {"ok": true, "applied": false, "reason": &"", "outdoor_park": park_bonus}
	if apply_walk_care and active_pet != null and str(active_pet.life_state) != "DEAD":
		result = request_care(&"walk", {"outdoor_park": park_bonus})
		result["applied"] = bool(result.get("ok", false))
		result["outdoor_park"] = park_bonus
	return result


func can_carry_deceased() -> bool:
	return (
		active_pet != null
		and str(active_pet.life_state) == "DEAD"
		and not active_pet.buried
		and not carrying_deceased
		and not escort_active
	)


func start_carry_deceased() -> Dictionary:
	## Begin carrying the body — player walks them to the backyard plot.
	if not can_carry_deceased():
		if carrying_deceased:
			return {"ok": true, "reason": &"ALREADY_CARRYING"}
		return {"ok": false, "reason": &"CANNOT_CARRY"}
	if escort_active:
		end_escort(false)
	carrying_deceased = true
	return {"ok": true}


func stop_carry_deceased() -> void:
	carrying_deceased = false


func needs_burial() -> bool:
	return (
		active_pet != null
		and str(active_pet.life_state) == "DEAD"
		and not active_pet.buried
	)


func _ready() -> void:
	# Defer boot so autoloads (SaveManager, TimeService) are ready.
	call_deferred("boot")


func boot() -> void:
	if _booted:
		return
	_booted = true
	var now: float = TimeService.now_unix_utc()
	if not SaveManager.has_save():
		var data: Dictionary = SaveManager.create_default_save(now)
		_apply_save_data(data)
		var wr: Dictionary = SaveManager.save_data(_to_save_data())
		if not wr.get("ok", false):
			EventBus.save_failed.emit(wr.get("error", &"WRITE_FAILED"))
		EventBus.needs_onboarding.emit()
		EventBus.needs_adoption.emit()
		publish()
		return

	var loaded: Dictionary = SaveManager.load_save()
	if not loaded.get("ok", false):
		EventBus.load_failed.emit(loaded.get("error", &"CORRUPT_SAVE"))
		var data2: Dictionary = SaveManager.create_default_save(now)
		_apply_save_data(data2)
		publish()
		return

	_apply_save_data(loaded["data"])
	_repair_archive_state()
	if active_pet != null:
		_run_catchup_and_apply(now)
		_refresh_session_summary(true)
	else:
		EventBus.needs_adoption.emit()
	publish()


func _process(delta: float) -> void:
	if not _booted:
		return
	_tick_accum += delta
	_autosave_accum += delta
	if _tick_accum >= SimConfig.SIM_TICK_SEC:
		_tick_accum = 0.0
		if active_pet != null and active_pet.life_state != LifeState.DEAD:
			_run_catchup_and_apply(TimeService.now_unix_utc())
			publish()
	if _autosave_accum >= SimConfig.AUTOSAVE_SEC:
		_autosave_accum = 0.0
		_save_atomic()


func on_focus_resume() -> void:
	if active_pet != null:
		_run_catchup_and_apply(TimeService.now_unix_utc())
		_refresh_session_summary(true)
		publish()


func consume_session_banner() -> Dictionary:
	## Habitat shows once per boot/resume when pending.
	if not _session_banner_pending:
		return {}
	_session_banner_pending = false
	return last_session_summary.duplicate(true)


func _refresh_session_summary(from_resume: bool) -> void:
	var now: float = TimeService.now_unix_utc()
	last_session_summary = CareAdvisor.session_summary(active_pet, meta, now)
	if from_resume or bool(meta.get("show_session_banner", false)):
		_session_banner_pending = active_pet != null
	meta["show_session_banner"] = false


func get_status_line() -> String:
	if active_pet == null:
		return "No active pet — adopt at Pet Store (debug: F4 adopt blob)."
	var st: Dictionary = StatusCopy.status_for_pet(active_pet)
	return "%s | deaths=%d graves=%d | %s" % [
		active_pet.name,
		profile.total_pets_died,
		profile.total_graves_dug,
		st.get("message", ""),
	]


func request_care(action: StringName, ctx: Dictionary = {}) -> Dictionary:
	if active_pet == null:
		return {"ok": false, "reason": &"NO_ACTIVE_PET"}
	# Advance sim to now before care
	_run_catchup_and_apply(TimeService.now_unix_utc())
	if active_pet == null:
		return {"ok": false, "reason": &"NO_ACTIVE_PET"}
	var now: float = TimeService.now_unix_utc()
	var is_day: bool = TimeService.local_day_phase() == &"day"
	# Inventory / locale context
	var care_ctx: Dictionary = ctx.duplicate(true)
	if not care_ctx.has("outdoor_park"):
		care_ctx["outdoor_park"] = str(SceneRouter.current_scene_id) == "park"
	care_ctx["has_chew_toy"] = profile.inv_count("chew_toy") > 0
	# Consume charge items when used
	if String(action) == "feed" and profile.inv_count("premium_food") > 0:
		if profile.consume_item("premium_food"):
			care_ctx["use_premium_food"] = true
	if String(action) == "clean" and profile.inv_count("soap") > 0:
		if profile.consume_item("soap"):
			care_ctx["use_soap"] = true
	var result: Dictionary = CareActions.try_action(action, active_pet, now, is_day, care_ctx)
	if result.get("ok", false):
		# Soft currency for successful care
		var pts := _care_points_for(action, care_ctx)
		profile.add_care_points(pts)
		result["care_points_earned"] = pts
		result["care_points_total"] = profile.care_points
		# P4: one-shot discovery toasts (meta flags, presentation only)
		if pts > 0 and not bool(meta.get("seen_care_points_tip", false)):
			meta["seen_care_points_tip"] = true
			result["first_care_points_toast"] = true
		if bool(care_ctx.get("outdoor_park", false)) and not bool(meta.get("seen_park_bonus_tip", false)):
			meta["seen_park_bonus_tip"] = true
			result["first_park_bonus_toast"] = true
		EventBus.care_performed.emit(action, result)
		_save_atomic()
		publish()
	elif care_ctx.get("use_premium_food", false):
		# refund consume if care failed after we already took item (shouldn't often)
		profile.add_item("premium_food", 1)
	elif care_ctx.get("use_soap", false):
		profile.add_item("soap", 1)
	return result


func _care_points_for(action: StringName, ctx: Dictionary) -> int:
	var base := 4
	match String(action):
		"feed", "clean":
			base = 5
		"play":
			base = 6
		"walk":
			base = 7
		"sleep", "wake":
			base = 2
		_:
			base = 3
	if bool(ctx.get("outdoor_park", false)):
		base += 3
	return base


func buy_store_item(item_id: String) -> Dictionary:
	## Shop catalog prices.
	var catalog := {
		"premium_food": {"cost": 12, "label": "Premium Food", "desc": "Next feed +15 hunger"},
		"soap": {"cost": 10, "label": "Gentle Soap", "desc": "Next clean +15 hygiene"},
		"chew_toy": {"cost": 25, "label": "Chew Toy", "desc": "Permanent +6 happiness on play"},
	}
	if not catalog.has(item_id):
		return {"ok": false, "reason": &"UNKNOWN_ITEM"}
	if item_id == "chew_toy" and profile.inv_count("chew_toy") > 0:
		return {"ok": false, "reason": &"ALREADY_OWNED"}
	var cost: int = int(catalog[item_id]["cost"])
	if not profile.try_spend(cost):
		return {"ok": false, "reason": &"NOT_ENOUGH_POINTS", "need": cost, "have": profile.care_points}
	profile.add_item(item_id, 1)
	_save_atomic()
	publish()
	return {"ok": true, "item": item_id, "cost": cost, "care_points": profile.care_points}


func adopt_pet(species_id: StringName, raw_name: String) -> Dictionary:
	var now: float = TimeService.now_unix_utc()
	var result: Dictionary = AdoptService.try_adopt(profile, active_pet, species_id, raw_name, now)
	if not result.get("ok", false):
		return result
	active_pet = result["pet"]
	meta["last_sim_unix_utc"] = now
	meta["max_seen_unix_utc"] = maxf(float(meta.get("max_seen_unix_utc", now)), now)
	meta["is_first_run"] = false
	EventBus.pet_adopted.emit(active_pet.to_view_dict(MoodStateMachine.derive_mood(active_pet)))
	_save_atomic()
	publish()
	return result


## Debug / first-run stub until Pet Store UI (PR D / design 13).
func debug_adopt_blob(pet_name: String = "Mochi") -> Dictionary:
	return adopt_pet(&"blob", pet_name)


func complete_burial(epitaph: String = "") -> Dictionary:
	if active_pet == null:
		return {"ok": false, "reason": &"NO_ACTIVE_PET"}
	var now: float = TimeService.now_unix_utc()
	var result: Dictionary = BurialService.complete_burial(profile, active_pet, now, epitaph)
	if not result.get("ok", false):
		return result
	var grave: GraveRecord = result["grave"]
	active_pet = null
	carrying_deceased = false
	EventBus.burial_completed.emit(grave.to_dict())
	EventBus.needs_adoption.emit()
	_save_atomic()
	publish()
	return result


func publish() -> void:
	if active_pet != null:
		var mood: StringName = MoodStateMachine.derive_mood(active_pet)
		var snap: Dictionary = active_pet.to_view_dict(mood)
		var st: Dictionary = StatusCopy.status_for_pet(active_pet)
		last_status = st
		snap["status_message"] = st.get("message", "")
		snap["status_priority"] = st.get("priority", 0)
		snap["local_day_phase"] = TimeService.local_day_phase()
		EventBus.pet_updated.emit(snap)
		EventBus.pet_mood_changed.emit(mood)
	else:
		last_status = StatusCopy.status_for_pet(null)
		EventBus.pet_updated.emit({})
	EventBus.profile_updated.emit(profile.to_view_dict(active_pet != null))
	EventBus.status_message.emit(get_status_line())


func _run_catchup_and_apply(now: float) -> void:
	if active_pet == null:
		return
	# Record gap before commit so session summary can say "you were away X"
	var prev_last: float = float(meta.get("last_sim_unix_utc", now))
	var away: float = maxf(0.0, now - prev_last)
	meta["pre_catchup_last_sim"] = prev_last
	meta["session_away_sec"] = away
	if away >= 45.0:
		meta["show_session_banner"] = true
	var before: StringName = active_pet.life_state
	var result: CatchupResult = NeedsSimulator.run_catchup(active_pet, meta, now)
	last_catchup_result = result
	if result.stalled:
		EventBus.time_anomaly.emit(result.stall_reason, {"now": now})
	if result.death_committed_this_call:
		# Controller-owned profile mutation — exactly once per first DEAD transition
		profile.total_pets_died += 1
		EventBus.pet_died.emit(result.death_detail)
	if before != active_pet.life_state:
		EventBus.life_state_changed.emit(before, active_pet.life_state)
	_save_atomic()


func _repair_archive_state() -> void:
	if active_pet == null:
		return
	# Buried flag or already in graves → clear active slot
	var in_graves: bool = profile.find_grave_by_pet_id(active_pet.id) != null
	if active_pet.buried or (active_pet.life_state == LifeState.DEAD and in_graves):
		if not in_graves and active_pet.life_state == LifeState.DEAD:
			# create missing grave from pet fields
			BurialService.complete_burial(profile, active_pet, TimeService.now_unix_utc())
		active_pet = null
		_save_atomic()
		EventBus.needs_adoption.emit()


func _apply_save_data(data: Dictionary) -> void:
	var ap: Variant = data.get("active_pet", null)
	if ap == null or (ap is Dictionary and ap.is_empty()):
		active_pet = null
	elif ap is Dictionary:
		active_pet = PetModel.from_save_dict(ap)
	else:
		active_pet = null
	var pp: Variant = data.get("player_profile", {})
	if pp is Dictionary:
		profile = PlayerProfile.from_save_dict(pp)
	else:
		profile = PlayerProfile.new()
	var m: Variant = data.get("meta", {})
	if m is Dictionary:
		meta = m.duplicate(true)
	else:
		var now: float = TimeService.now_unix_utc()
		meta = {"last_sim_unix_utc": now, "max_seen_unix_utc": now}


func _to_save_data() -> Dictionary:
	var pet_dict = null
	if active_pet != null:
		pet_dict = active_pet.to_save_dict()
	return {
		"schema_version": SaveManager.SCHEMA_VERSION,
		"active_pet": pet_dict,
		"player_profile": profile.to_save_dict(),
		"meta": meta.duplicate(true),
	}


func _save_atomic() -> void:
	var wr: Dictionary = SaveManager.save_data(_to_save_data())
	if not wr.get("ok", false):
		EventBus.save_failed.emit(wr.get("error", &"WRITE_FAILED"))


func _notification(what: int) -> void:
	## Single handler: resume catch-up on focus; flush save on quit/background so sleep persists.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _booted:
			on_focus_resume()
	elif (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	):
		if _booted:
			_save_atomic()
