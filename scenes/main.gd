extends Control
## Main shell — PetController status (PR B); F4 debug adopt blob.

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _status: Label = %StatusLabel
@onready var _phase: Label = %PhaseLabel
@onready var _hints: Label = %HintsLabel


func _ready() -> void:
	_title.text = "Real-Time Virtual Pet"
	_subtitle.text = "PR B — Save + PetController (sim live)"
	_refresh()
	if not EventBus.pet_updated.is_connected(_on_pet_updated):
		EventBus.pet_updated.connect(_on_pet_updated)
	if not EventBus.profile_updated.is_connected(_on_profile):
		EventBus.profile_updated.connect(_on_profile)
	print("[main] status=", PetController.get_status_line())


func _on_pet_updated(_snap: Dictionary) -> void:
	_refresh()


func _on_profile(_snap: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	_status.text = PetController.get_status_line()
	var phase: StringName = TimeService.local_day_phase()
	var unix: float = TimeService.now_unix_utc()
	_phase.text = "UTC now: %.0f  ·  local phase: %s" % [unix, str(phase)]
	var pet_line := "(no pet)"
	if PetController.active_pet != null:
		var p = PetController.active_pet
		pet_line = "%s [%s] H=%.0f E=%.0f A=%.0f Y=%.0f hold=%.0f" % [
			p.name, str(p.life_state), p.hunger, p.energy, p.happiness, p.hygiene, p.zero_hold_sec
		]
	_hints.text = (
		"Active: %s\nProfile deaths=%d graves=%d serial=%d\n"
		+ "Keys: F4 debug adopt blob · F5 feed · F6 burial if dead\n"
		+ "Only pets have needs; humans are invincible."
	) % [
		pet_line,
		PetController.profile.total_pets_died,
		PetController.profile.total_graves_dug,
		PetController.profile.next_pet_serial,
	]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	if k.keycode == KEY_F4:
		var r: Dictionary = PetController.debug_adopt_blob("Mochi")
		print("[main] debug adopt: ", r)
		_refresh()
	elif k.keycode == KEY_F5:
		var r2: Dictionary = PetController.request_care(&"feed")
		print("[main] feed: ", r2)
		_refresh()
	elif k.keycode == KEY_F6:
		var r3: Dictionary = PetController.complete_burial("")
		print("[main] burial: ", r3)
		_refresh()
