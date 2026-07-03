extends Node
## Stages care: human walks to target, plays care anim on human+pet, then applies sim.
## Instantiate via preload("res://src/gameplay/care_director.gd").new()

signal choreography_started(action: StringName)
signal choreography_finished(action: StringName, result: Dictionary)
signal toast(message: String)

enum State { IDLE, WALKING, ACTING }

var state: State = State.IDLE
var human: CharacterBody2D
var pet: CharacterBody2D
var care_spots: Dictionary = {}  # action -> Vector2

var _pending_action: StringName = &""
var _result: Dictionary = {}


func setup(p_human: CharacterBody2D, p_pet: CharacterBody2D, spots: Dictionary = {}) -> void:
	human = p_human
	pet = p_pet
	care_spots = spots
	if human and not human.arrived.is_connected(_on_human_arrived):
		human.arrived.connect(_on_human_arrived)
	if human and not human.anim_finished.is_connected(_on_human_anim_finished):
		human.anim_finished.connect(_on_human_anim_finished)


func is_busy() -> bool:
	return state != State.IDLE


func try_start_care(action: StringName) -> Dictionary:
	if state != State.IDLE:
		return {"ok": false, "reason": &"BUSY"}
	if human == null or pet == null:
		return {"ok": false, "reason": &"NO_ACTORS"}
	if PetController.active_pet == null:
		return {"ok": false, "reason": &"NO_ACTIVE_PET"}

	# Pre-validate without applying (dry call by attempting — CareActions mutates;
	# so we only gate obvious cases here; actual apply after anim)
	var life: String = str(PetController.active_pet.life_state)
	if life == "DEAD" and action != &"dig":
		return {"ok": false, "reason": &"PET_DEAD"}
	if action != &"wake" and action != &"dig" and PetController.active_pet.is_sleeping() and action != &"sleep":
		if action != &"sleep":
			pass  # CareActions will fail if needed

	_pending_action = action
	state = State.WALKING
	human.set_busy(true)
	pet.set_busy(true)
	choreography_started.emit(action)

	var target: Vector2 = pet.global_position + Vector2(-28, 8)
	if care_spots.has(String(action)):
		target = care_spots[String(action)] as Vector2
	toast.emit("%s…" % str(action).capitalize())
	if human.global_position.distance_to(target) <= 14.0:
		# Already close — skip walk path
		call_deferred("_on_human_arrived")
	else:
		human.walk_to(target)
	return {"ok": true, "staging": true}


func _on_human_arrived() -> void:
	if state != State.WALKING:
		return
	state = State.ACTING
	var anim := _action_to_anim(_pending_action)
	human.play_anim(anim)
	_play_pet_reaction(_pending_action)
	# Fallback timer if animation_finished unreliable for short clips
	get_tree().create_timer(0.85).timeout.connect(_finish_acting, CONNECT_ONE_SHOT)


func _on_human_anim_finished(anim_name: StringName) -> void:
	if state != State.ACTING:
		return
	var expected := _action_to_anim(_pending_action)
	if anim_name == expected or String(anim_name) in ["feed", "play", "clean", "sleep", "wake", "dig"]:
		_finish_acting()


func _finish_acting() -> void:
	if state != State.ACTING:
		return
	state = State.IDLE
	var action := _pending_action
	_pending_action = &""
	_result = {}
	if action == &"dig":
		# Dig is hold ritual in habitat; choreography optional visual only
		_result = {"ok": true, "staged_only": true}
	else:
		_result = PetController.request_care(action)
	human.set_busy(false)
	pet.set_busy(false)
	human.play_idle()
	_sync_pet_mood_anim()
	if _result.get("ok", false):
		toast.emit("%s done" % str(action).capitalize())
	else:
		toast.emit("%s failed: %s" % [str(action), str(_result.get("reason", ""))])
	choreography_finished.emit(action, _result)


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
		"dig":
			return &"dig"
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
			pet.play_anim(&"happy")
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
	elif life == "DYING" or life == "CRITICAL":
		pet.play_anim(&"sad")
	elif p.happiness >= 70.0:
		pet.play_anim(&"happy")
	else:
		pet.play_anim(&"idle")
