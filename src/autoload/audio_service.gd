extends Node
## Lightweight SFX player. Loads res://assets/audio/*.wav on demand.

const BUS := "Master"
const PATHS := {
	"ui_click": "res://assets/audio/ui_click.wav",
	"menu_open": "res://assets/audio/menu_open.wav",
	"door": "res://assets/audio/door.wav",
	"care_ok": "res://assets/audio/care_ok.wav",
	"care_fail": "res://assets/audio/care_fail.wav",
	"feed": "res://assets/audio/feed.wav",
	"sleep": "res://assets/audio/sleep.wav",
	"wake": "res://assets/audio/wake.wav",
	"walk_start": "res://assets/audio/walk_start.wav",
	"dig": "res://assets/audio/dig.wav",
	"bury": "res://assets/audio/bury.wav",
	"adopt": "res://assets/audio/adopt.wav",
	"step": "res://assets/audio/step.wav",
	"clean": "res://assets/audio/clean.wav",
	"ambient_soft": "res://assets/audio/ambient_soft.wav",
}

var _cache: Dictionary = {}  # id -> AudioStream
var _pool: Array = []  # AudioStreamPlayer nodes
var _ambient: AudioStreamPlayer
var _enabled: bool = true
var _sfx_volume_db: float = -6.0
var _ambient_volume_db: float = -22.0


func _ready() -> void:
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = BUS
	_ambient.volume_db = _ambient_volume_db
	add_child(_ambient)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = _sfx_volume_db
		add_child(p)
		_pool.append(p)


func set_enabled(v: bool) -> void:
	_enabled = v
	if not v and _ambient:
		_ambient.stop()


func play(id: String, pitch_scale: float = 1.0, volume_db: float = 999.0) -> void:
	if not _enabled:
		return
	var stream: AudioStream = _stream(id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _free_player()
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = _sfx_volume_db if volume_db > 100.0 else volume_db
	player.play()


func play_care(action: StringName, ok: bool) -> void:
	if not ok:
		play("care_fail")
		return
	match String(action):
		"feed":
			play("feed")
		"sleep":
			play("sleep")
		"wake":
			play("wake")
		"walk":
			play("care_ok")
		"clean":
			play("clean")
		"play":
			play("care_ok", 1.05)
		_:
			play("care_ok")


func play_door() -> void:
	play("door")


func play_menu() -> void:
	play("menu_open")


func start_ambient() -> void:
	if not _enabled:
		return
	var stream: AudioStream = _stream("ambient_soft")
	if stream == null:
		return
	# loop ambient
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambient.stream = stream
	_ambient.volume_db = _ambient_volume_db
	if not _ambient.playing:
		_ambient.play()


func stop_ambient() -> void:
	if _ambient:
		_ambient.stop()


func _stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path: String = str(PATHS.get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		# try raw file load
		var abs_path := ProjectSettings.globalize_path(path) if path != "" else ""
		if abs_path != "" and FileAccess.file_exists(abs_path):
			var f := FileAccess.open(abs_path, FileAccess.READ)
			if f:
				# Prefer ResourceLoader after import; fallback skip
				pass
		push_warning("AudioService: missing %s" % id)
		return null
	var s: AudioStream = load(path) as AudioStream
	if s:
		_cache[id] = s
	return s


func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if p is AudioStreamPlayer and not (p as AudioStreamPlayer).playing:
			return p
	# steal first
	if _pool.size() > 0:
		return _pool[0]
	return null
