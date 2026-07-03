class_name PetModel
extends RefCounted
## Pure pet data + view/save dict helpers. No scene tree.

var id: String = ""
var name: String = ""
var species_id: StringName = &"blob"

var hunger: float = 80.0
var energy: float = 80.0
var happiness: float = 70.0
var hygiene: float = 80.0

var life_state: StringName = &"HEALTHY"
var zero_hold_sec: float = 0.0
var died_unix_utc: float = 0.0
var death_cause: StringName = &""
var buried: bool = false

## Source of truth for sleep; is_sleeping is derived.
var sleep_started_unix_utc: float = 0.0

var last_actions: Dictionary = {
	"feed": 0.0,
	"walk": 0.0,
	"play": 0.0,
	"clean": 0.0,
}
var total_care_actions: int = 0
var born_unix_utc: float = 0.0


func is_sleeping() -> bool:
	if life_state == LifeState.DEAD:
		return false
	return sleep_started_unix_utc > 0.0


func any_need_at_zero() -> bool:
	return hunger <= 0.0 or energy <= 0.0 or happiness <= 0.0 or hygiene <= 0.0


func zero_need_count() -> int:
	var n := 0
	if hunger <= 0.0:
		n += 1
	if energy <= 0.0:
		n += 1
	if happiness <= 0.0:
		n += 1
	if hygiene <= 0.0:
		n += 1
	return n


func min_need() -> float:
	return minf(hunger, minf(energy, minf(happiness, hygiene)))


func clamp_needs() -> void:
	var lo := SimConfig.STAT_MIN
	var hi := SimConfig.STAT_MAX
	if SimConfig.ENABLE_SOFT_FLOOR:
		lo = maxf(lo, SimConfig.STAT_FLOOR)
	hunger = clampf(hunger, lo, hi)
	energy = clampf(energy, lo, hi)
	happiness = clampf(happiness, lo, hi)
	hygiene = clampf(hygiene, lo, hi)


func clear_sleep() -> void:
	sleep_started_unix_utc = 0.0


func start_sleep(now_unix: float) -> void:
	sleep_started_unix_utc = now_unix


func duplicate_pet() -> PetModel:
	var p := PetModel.new()
	p.id = id
	p.name = name
	p.species_id = species_id
	p.hunger = hunger
	p.energy = energy
	p.happiness = happiness
	p.hygiene = hygiene
	p.life_state = life_state
	p.zero_hold_sec = zero_hold_sec
	p.died_unix_utc = died_unix_utc
	p.death_cause = death_cause
	p.buried = buried
	p.sleep_started_unix_utc = sleep_started_unix_utc
	p.last_actions = last_actions.duplicate(true)
	p.total_care_actions = total_care_actions
	p.born_unix_utc = born_unix_utc
	return p


func to_save_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"species_id": str(species_id),
		"hunger": hunger,
		"energy": energy,
		"happiness": happiness,
		"hygiene": hygiene,
		"life_state": str(life_state),
		"sleep_started_unix_utc": sleep_started_unix_utc,
		"zero_hold_sec": zero_hold_sec,
		"died_unix_utc": died_unix_utc,
		"death_cause": str(death_cause),
		"buried": buried,
		"born_unix_utc": born_unix_utc,
		"total_care_actions": total_care_actions,
		"last_actions": last_actions.duplicate(true),
	}


func to_view_dict(mood: StringName = &"NEUTRAL") -> Dictionary:
	var any_z := any_need_at_zero()
	var hold_remaining := -1.0
	if any_z and life_state != LifeState.DEAD:
		hold_remaining = maxf(0.0, SimConfig.DEATH_AT_ZERO_HOLD_SEC - zero_hold_sec)
	var cooldowns := {}
	for k in last_actions.keys():
		cooldowns[k] = float(last_actions[k])
	var species_display := str(species_id)
	var tmpl: Dictionary = SpeciesCatalog.get_template(species_id)
	if not tmpl.is_empty():
		species_display = str(tmpl.get("display_name", species_id))
	return {
		"id": id,
		"name": name,
		"species_id": str(species_id),
		"species_display": species_display,
		"hunger": hunger,
		"energy": energy,
		"happiness": happiness,
		"hygiene": hygiene,
		"life_state": life_state,
		"is_sleeping": is_sleeping(),
		"zero_hold_sec": zero_hold_sec,
		"death_hold_remaining_sec": hold_remaining,
		"died_unix_utc": died_unix_utc,
		"death_cause": death_cause,
		"buried": buried,
		"mood": mood,
		"action_cooldowns": cooldowns,
		"born_unix_utc": born_unix_utc,
	}


static func from_save_dict(d: Dictionary) -> PetModel:
	var p := PetModel.new()
	p.id = str(d.get("id", ""))
	p.name = str(d.get("name", ""))
	p.species_id = StringName(str(d.get("species_id", "blob")))
	p.hunger = float(d.get("hunger", SimConfig.DEFAULT_HUNGER))
	p.energy = float(d.get("energy", SimConfig.DEFAULT_ENERGY))
	p.happiness = float(d.get("happiness", SimConfig.DEFAULT_HAPPINESS))
	p.hygiene = float(d.get("hygiene", SimConfig.DEFAULT_HYGIENE))
	p.life_state = StringName(str(d.get("life_state", "HEALTHY")))
	p.sleep_started_unix_utc = float(d.get("sleep_started_unix_utc", 0.0))
	# Prefer sleep SOT; ignore stale is_sleeping if present
	p.zero_hold_sec = float(d.get("zero_hold_sec", 0.0))
	p.died_unix_utc = float(d.get("died_unix_utc", 0.0))
	p.death_cause = StringName(str(d.get("death_cause", "")))
	p.buried = bool(d.get("buried", false))
	p.born_unix_utc = float(d.get("born_unix_utc", 0.0))
	p.total_care_actions = int(d.get("total_care_actions", 0))
	var la: Variant = d.get("last_actions", {})
	if la is Dictionary:
		p.last_actions = {
			"feed": float(la.get("feed", 0.0)),
			"walk": float(la.get("walk", 0.0)),
			"play": float(la.get("play", 0.0)),
			"clean": float(la.get("clean", 0.0)),
		}
	if p.life_state == LifeState.DEAD:
		p.sleep_started_unix_utc = 0.0
	return p


## Factory used by adopt services / tests.
static func create_from_species(species_id: StringName, pet_name: String, now: float, serial: int) -> PetModel:
	if not SpeciesCatalog.has_species(species_id):
		return null
	var t: Dictionary = SpeciesCatalog.get_template(species_id)
	var pet := PetModel.new()
	pet.id = "pet_%d" % serial
	pet.name = pet_name
	pet.species_id = StringName(str(t.get("id", species_id)))
	pet.hunger = float(t.get("default_hunger", SimConfig.DEFAULT_HUNGER))
	pet.energy = float(t.get("default_energy", SimConfig.DEFAULT_ENERGY))
	pet.happiness = float(t.get("default_happiness", SimConfig.DEFAULT_HAPPINESS))
	pet.hygiene = float(t.get("default_hygiene", SimConfig.DEFAULT_HYGIENE))
	pet.life_state = LifeState.HEALTHY
	pet.sleep_started_unix_utc = 0.0
	pet.zero_hold_sec = 0.0
	pet.died_unix_utc = 0.0
	pet.death_cause = &""
	pet.buried = false
	pet.born_unix_utc = now
	pet.total_care_actions = 0
	return pet
