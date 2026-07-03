extends Node
## Care: walk to pet (pet collision off) → play action anims → apply sim.

signal choreography_started(action: StringName)
signal choreography_finished(action: StringName, result: Dictionary)
signal toast(message: String)

enum State { IDLE, WALKING, ACTING }

var state: State = State.IDLE
var human: CharacterBody2D
var pet: CharacterBody2D
var care_spots: Dictionary = {}

var _pending_action: StringName = &""
var _finish_token: int = 0


func setup(p_human: CharacterBody2D, p_pet: CharacterBody2D, spots: Dictionary = {}) -> void:
	human = p_human
	pet = p_pet
	care_spots = spots
	if human and not human.arrived.is_connected(_on_human_arrived):
		human.arrived.connect(_on_human_arrived)


func is_busy() -> bool:
	return state != State.IDLE


func try_start_care(action: StringName) -> Dictionary:
	if state != State.IDLE:
		return {"ok": false, "reason": &"BUSY"}
	if human == null or pet == null:
		return {"ok": false, "reason": &"NO_ACTORS"}
	if PetController.active_pet == null:
		return {"ok": false, "reason": &"NO_ACTIVE_PET"}
	var life: String = str(PetController.active_pet.life_state)
	if life == "DEAD":
		return {"ok": false, "reason": &"PET_DEAD"}

	_pending_action = action
	state = State.WALKING
	human.set_busy(true)
	pet.set_busy(true)
	# Allow walking up to pet
	if pet.has_method("set_collision_enabled"):
		pet.set_collision_enabled(false)
	choreography_started.emit(action)

	var target: Vector2 = pet.global_position + Vector2(-24, 10)
	if care_spots.has(String(action)):
		target = care_spots[String(action)] as Vector2
	toast.emit("%s…" % str(action).capitalize())
	if human.global_position.distance_to(target) <= 16.0:
		call_deferred("_on_human_arrived")
	else:
		human.walk_to(target)
	return {"ok": true, "staging": true}


func _on_human_arrived() -> void:
	if state != State.WALKING:
		return
	state = State.ACTING
	var anim := _action_to_anim(_pending_action)
	if human.has_method("set_acting"):
		human.set_acting(true)
	human.play_anim(anim)
	_play_pet_reaction(_pending_action)
	_finish_token += 1
	var token := _finish_token
	# Hold action pose long enough to see (~1.2s)
	get_tree().create_timer(1.25).timeout.connect(func():
		if token == _finish_token:
			_finish_acting()
	, CONNECT_ONE_SHOT)


func _finish_acting() -> void:
	if state != State.ACTING:
		return
	state = State.IDLE
	var action := _pending_action
	_pending_action = &""
	var result: Dictionary = PetController.request_care(action)
	if human.has_method("set_acting"):
		human.set_acting(false)
	human.set_busy(false)
	pet.set_busy(false)
	if pet.has_method("set_collision_enabled"):
		pet.set_collision_enabled(true)
	human.play_idle()
	_sync_pet_mood_anim()
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
	match String(action):
		"feed":
			pet.play_anim(&"eat")
		"play", "walk":
			pet.play_anim(&"play")
		"clean":
			pet.play_anim(&"clean")
		"sleep":
			pet.play_anim(&"sleep")
		"wake":
			pet.play_anim(&"idle")
		_:
			pet.play_anim(&"idle")


func _sync_pet_mood_anim() -> void:
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
	elif life == "CRITICAL" or p.hunger < 25.0:
		pet.play_anim(&"hungry")
	elif p.happiness >= 70.0:
		pet.play_anim(&"happy")
	else:
		pet.play_anim(&"idle")
