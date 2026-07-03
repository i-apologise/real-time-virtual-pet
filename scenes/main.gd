extends Control
## Main shell — shows TimeService / NameUtils (PR2).

const NameUtils := preload("res://src/util/name_utils.gd")

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _status: Label = %StatusLabel
@onready var _phase: Label = %PhaseLabel
@onready var _hints: Label = %HintsLabel


func _ready() -> void:
	_title.text = "Real-Time Virtual Pet"
	_subtitle.text = "PR2 — TimeService + NameUtils"
	_status.text = PetController.get_status_line()
	var phase: StringName = TimeService.local_day_phase()
	var unix: float = TimeService.now_unix_utc()
	_phase.text = "UTC now: %.0f  ·  local phase: %s  ·  night=%s" % [
		unix, str(phase), str(TimeService.is_local_night())
	]
	var sample := "  Mochi\n"
	var ok: bool = NameUtils.is_valid_name(sample)
	_hints.text = (
		"NameUtils: sanitize => '%s' valid=%s (min %d max %d)\n"
		+ "Controls (planned): WASD move · E interact · care on action bar\n"
		+ "Only pets have needs; humans are invincible."
	) % [
		NameUtils.sanitize_name(sample),
		str(ok),
		NameUtils.NAME_MIN_LEN,
		NameUtils.NAME_MAX_LEN,
	]
	print("[main] phase=", phase, " unix=", unix)
	print("[main] name sample valid=", ok)
