extends Node
## Care flows: feed at bowl, clean in bathroom, leashed walk, sleep at pet bed.
## Always emits timer_tick so UI can show a countdown. Actions never loop forever.

signal choreography_started(action: StringName)
signal choreography_finished(action: StringName, result: Dictionary)
signal toast(message: String)
signal timer_tick(seconds_left: float, total: float, label: String)
signal timer_done

enum State { IDLE, GATHERING, ACTING, LEASH }

var state: State = State.IDLE
var human: CharacterBody2D
var pet: CharacterBody2D
var care_spots: Dictionary = {}
var leash_line: Line2D

var _action: StringName = &""
var _token: int = 0
var _human_ok: bool = false
var _pet_ok: bool = false
var _elapsed: float = 0.0
var _duration: float = 2.0
var _leash_leg: int = 0


func setup(p_human: CharacterBody2D, p_pet: CharacterBody2D, spots: Dictionary = {}, p_leash: Line2D = null) -> void:
	human = p_human
	pet = p_pet
	care_spots = spots
	leash_line = p_leash
	if human and not human.arrived.is_connected(_on_human_arrived):
		human.arrived.connect(_on_human_arrived)
	if pet and not pet.arrived.is_connected(_on_pet_arrived):
		pet.arrived.connect(_on_pet_arrived)
	set_process(false)


func is_busy() -> bool:
	return state != State.IDLE


func try_start_care(action: StringName) -> Dictionary:
	if state != State.IDLE:
		return {"ok": false, "reason": &"BUSY"}
	if human == null or pet == null or PetController.active_pet == null:
		return {"ok": false, "reason": &"NO_ACTORS"}
	if str(PetController.active_pet.life_state) == "DEAD":
		return {"ok": false, "reason": &"PET_DEAD"}

	_action = action
	_token += 1
	_human_ok = false
	_pet_ok = false
	_elapsed = 0.0
	_leash_leg = 0
	human.set_busy(true)
	pet.set_busy(true)
	if pet.has_method("set_collision_enabled"):
		pet.set_collision_enabled(false)
	if human.has_method("clear_follow"):
		human.clear_follow()
	if pet.has_method("clear_follow"):
		pet.clear_follow()
	if leash_line:
		leash_line.visible = false

	choreography_started.emit(action)
	_start_gather(action)
	return {"ok": true, "staging": true}


func _start_gather(action: StringName) -> void:
	state = State.GATHERING
	_elapsed = 0.0
	set_process(true)  # gather failsafe + early "Going…" timer
	match String(action):
		"clean":
			toast.emit("Bathroom time…")
			var bath: Vector2 = care_spots.get("bathroom", Vector2(370, 120)) as Vector2
			var bath_p: Vector2 = care_spots.get("bathroom_pet", bath + Vector2(28, 4)) as Vector2
			_walk_both(bath, bath_p)
		"walk":
			toast.emit("Getting the leash…")
			# Human to pet, pet stays put
			_pet_ok = true
			human.walk_to(pet.global_position + Vector2(-22, 8))
		"feed":
			toast.emit("Dinner time…")
			var bowl: Vector2 = care_spots.get("bowl", Vector2(250, 180)) as Vector2
			_walk_both(bowl + Vector2(-18, 2), bowl + Vector2(14, 4))
		"sleep":
			toast.emit("Bedtime…")
			var bed: Vector2 = care_spots.get("pet_bed", Vector2(310, 200)) as Vector2
			var hbed: Vector2 = care_spots.get("human_bed_side", bed + Vector2(-28, 4)) as Vector2
			_walk_both(hbed, bed)
		"play":
			toast.emit("Playtime…")
			var play: Vector2 = care_spots.get("play", Vector2(220, 200)) as Vector2
			_walk_both(play, play + Vector2(24, 0))
		"wake":
			toast.emit("Wakey wakey…")
			var bed2: Vector2 = care_spots.get("pet_bed", pet.global_position) as Vector2
			_pet_ok = true
			human.walk_to(bed2 + Vector2(-20, 6))
		_:
			_pet_ok = true
			human.walk_to(pet.global_position + Vector2(-24, 10))


func _walk_both(human_pos: Vector2, pet_pos: Vector2) -> void:
	_human_ok = false
	_pet_ok = false
	# walk_to after busy — do not re-busy pet (set_busy clears walk target)
	human.walk_to(human_pos)
	pet.set_busy(false, false)
	pet.walk_to(pet_pos)


func _on_human_arrived() -> void:
	if state != State.GATHERING and state != State.LEASH:
		return
	if state == State.LEASH:
		return
	_human_ok = true
	_try_begin_main()


func _on_pet_arrived() -> void:
	if state != State.GATHERING:
		return
	_pet_ok = true
	_try_begin_main()


func _try_begin_main() -> void:
	if not _human_ok or not _pet_ok:
		return
	if String(_action) == "walk":
		_begin_leash()
	else:
		_begin_timed_action()


func _begin_leash() -> void:
	state = State.LEASH
	_elapsed = 0.0
	_duration = 4.5
	_leash_leg = 0
	toast.emit("Leash walk!")
	if pet.has_method("set_follow"):
		pet.set_follow(human, Vector2(-22, 10))
	if human.has_method("set_acting"):
		human.set_acting(false)
	# Keep busy but allow walk_to (cancel_motion=false)
	human.set_busy(true, false)
	human.walk_to(care_spots.get("walk_a", Vector2(180, 230)) as Vector2)
	timer_tick.emit(_duration, _duration, "Walk")
	set_process(true)


func _begin_timed_action() -> void:
	state = State.ACTING
	_elapsed = 0.0
	_duration = _duration_for(_action)
	if human.has_method("set_acting"):
		human.set_acting(true)
	# Force non-looping care anim — timer always ends the action
	var anim := _action_to_anim(_action)
	human.play_anim(anim)
	_play_pet_reaction(_action)
	# Show full timer immediately
	timer_tick.emit(_duration, _duration, str(_action).capitalize())
	set_process(true)


func _duration_for(action: StringName) -> float:
	match String(action):
		"clean":
			return 2.8
		"feed":
			return 2.2
		"play":
			return 2.4
		"sleep":
			return 2.2
		"wake":
			return 1.3
		_:
			return 2.0


func _process(delta: float) -> void:
	# Failsafe: if gather stalls (blocked path), start action after timeout
	if state == State.GATHERING:
		_elapsed += delta
		timer_tick.emit(maxf(0.0, 6.0 - _elapsed), 6.0, "Going…")
		if _elapsed >= 6.0:
			_human_ok = true
			_pet_ok = true
			_try_begin_main()
		return

	if state == State.ACTING:
		_elapsed += delta
		timer_tick.emit(maxf(0.0, _duration - _elapsed), _duration, str(_action).capitalize())
		# Never re-loop care anims — play once; hold last frame until timer ends
		if _elapsed >= _duration:
			set_process(false)
			timer_done.emit()
			_complete_care()
		return

	if state == State.LEASH:
		_elapsed += delta
		_update_leash_visual()
		timer_tick.emit(maxf(0.0, _duration - _elapsed), _duration, "Walk")
		if _leash_leg == 0 and _elapsed >= 1.4:
			_leash_leg = 1
			human.walk_to(care_spots.get("walk_b", Vector2(360, 240)) as Vector2)
		elif _leash_leg == 1 and _elapsed >= 2.8:
			_leash_leg = 2
			human.walk_to(care_spots.get("walk_home", Vector2(220, 200)) as Vector2)
		if _elapsed >= _duration:
			if pet.has_method("clear_follow"):
				pet.clear_follow()
			if leash_line:
				leash_line.visible = false
			set_process(false)
			timer_done.emit()
			_complete_care()
		return


func _update_leash_visual() -> void:
	if leash_line == null or human == null or pet == null:
		return
	var parent := leash_line.get_parent() as Node2D
	if parent == null:
		return
	leash_line.visible = true
	leash_line.width = 2.5
	leash_line.default_color = Color("6D4C41")
	leash_line.points = PackedVector2Array([
		parent.to_local(human.global_position + Vector2(4, -10)),
		parent.to_local(pet.global_position + Vector2(0, -8)),
	])


func _complete_care() -> void:
	if state == State.IDLE:
		return
	state = State.IDLE
	var action := _action
	_action = &""
	if human.has_method("set_acting"):
		human.set_acting(false)
	if pet.has_method("clear_follow"):
		pet.clear_follow()
	if leash_line:
		leash_line.visible = false
	human.set_busy(false)
	pet.set_busy(false)
	if pet.has_method("set_collision_enabled"):
		pet.set_collision_enabled(true)
	human.play_idle()
	var result: Dictionary = PetController.request_care(action)
	_sync_pet_mood()
	if result.get("ok", false):
		toast.emit("%s done!" % str(action).capitalize())
	else:
		toast.emit("%s failed: %s" % [str(action), str(result.get("reason", ""))])
	choreography_finished.emit(action, result)


func _action_to_anim(action: StringName) -> StringName:
	match String(action):
		"feed":
			return &"feed"
		"play", "walk":
			return &"play"
		"clean":
			return &"clean"
		"sleep":
			return &"sleep"
		"wake":
			return &"wake"
		_:
			return &"feed"


func _play_pet_reaction(action: StringName) -> void:
	if pet == null:
		return
	# Ensure non-loop
	match String(action):
		"feed":
			pet.play_anim(&"eat")
		"play":
			pet.play_anim(&"play")
		"walk":
			pet.play_anim(&"walk")
		"clean":
			pet.play_anim(&"clean")
		"sleep":
			pet.play_anim(&"sleep")
		"wake":
			pet.play_anim(&"idle")
		_:
			pet.play_anim(&"idle")


func _sync_pet_mood() -> void:
	if pet == null or PetController.active_pet == null:
		return
	var p = PetController.active_pet
	var life := str(p.life_state)
	if life == "DEAD":
		pet.play_anim(&"dead")
	elif p.is_sleeping():
		pet.play_anim(&"sleep")
	elif life == "DYING" or p.hunger <= 0.0:
		pet.play_anim(&"weak")
	elif p.hunger < 25.0:
		pet.play_anim(&"hungry")
	elif p.happiness >= 70.0:
		pet.play_anim(&"happy")
	else:
		pet.play_anim(&"idle")
