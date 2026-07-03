class_name MoodStateMachine
extends RefCounted
## Presentation mood from stats / life_state (first match wins).

const DEAD := &"DEAD"
const SLEEPY := &"SLEEPY"
const DYING_MOOD := &"DYING_MOOD"
const SICKLY := &"SICKLY"
const ANGRY := &"ANGRY"
const SAD := &"SAD"
const BORED := &"BORED"
const ECSTATIC := &"ECSTATIC"
const HAPPY := &"HAPPY"
const NEUTRAL := &"NEUTRAL"


static func derive_mood(pet: PetModel) -> StringName:
	if pet.life_state == LifeState.DEAD:
		return DEAD
	if pet.is_sleeping():
		return SLEEPY
	if pet.life_state == LifeState.DYING or pet.any_need_at_zero():
		return DYING_MOOD
	if pet.life_state == LifeState.CRITICAL or pet.hunger < 15.0 or pet.energy < 15.0:
		return SICKLY
	if pet.hygiene < 20.0 and pet.happiness < 35.0:
		return ANGRY
	if pet.happiness < 30.0 or (pet.hunger < 25.0 and not pet.is_sleeping()):
		return SAD
	if pet.happiness < 50.0 and pet.energy >= 40.0 and pet.hunger >= 40.0:
		return BORED
	if (
		pet.happiness >= 80.0
		and pet.hygiene >= 50.0
		and pet.hunger >= 50.0
		and pet.energy >= 40.0
	):
		return ECSTATIC
	if pet.happiness >= 60.0:
		return HAPPY
	return NEUTRAL
