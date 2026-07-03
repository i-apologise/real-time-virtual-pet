extends Control
## Bootstrap main scene (PR1). Placeholder until town hub ships.

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _status: Label = %StatusLabel
@onready var _phase: Label = %PhaseLabel
@onready var _hints: Label = %HintsLabel


func _ready() -> void:
	_title.text = "Real-Time Virtual Pet"
	_subtitle.text = "PR1 bootstrap — Godot 4.3 project shell"
	_status.text = PetController.get_status_line()
	_phase.text = "Local phase: %s" % str(TimeService.local_day_phase())
	_hints.text = "Controls (planned): WASD move · E interact · care on action bar\nPOIs: House · Park · Store · Graveyard · AI homes\nOnly pets have needs; humans are invincible."
	print("[main] Real-Time Virtual Pet PR1 ready")
	print("[main] TimeService phase=", TimeService.local_day_phase())
	print("[main] SceneRouter house=", SceneRouter.describe_poi(SceneRouter.Poi.HOUSE))
