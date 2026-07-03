extends Control
## Big graveyard map: 20-col unbounded row-major plots.

const COLS := 20
const CELL := 56

var _scroll: ScrollContainer
var _grid: Control
var _info: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := Button.new()
	back.text = "Back to Habitat"
	back.pressed.connect(func(): SceneRouter.go("habitat"))
	top.add_child(back)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_info)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_grid = Control.new()
	_scroll.add_child(_grid)
	_rebuild()


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var graves: Array = PetController.profile.graves
	var max_index := maxi(COLS * 4 - 1, 0)  # at least 4 rows empty aesthetic
	for g in graves:
		if g is GraveRecord:
			max_index = maxi(max_index, g.plot_index)
	var rows: int = int(max_index / COLS) + 3
	_grid.custom_minimum_size = Vector2(COLS * CELL + 8, rows * CELL + 8)
	_info.text = "Graveyard · plots %dx~ · graves=%d · deaths=%d" % [
		COLS, PetController.profile.graves.size(), PetController.profile.total_pets_died
	]
	for y in range(rows):
		for x in range(COLS):
			var idx := y * COLS + x
			var cell := ColorRect.new()
			cell.position = Vector2(x * CELL + 4, y * CELL + 4)
			cell.size = Vector2(CELL - 6, CELL - 6)
			cell.color = Color(0.22, 0.28, 0.22)
			var grave: GraveRecord = null
			for g in graves:
				if g is GraveRecord and g.plot_index == idx:
					grave = g
					break
			if grave != null:
				cell.color = Color(0.35, 0.35, 0.4)
				var lab := Label.new()
				lab.text = grave.name
				lab.position = Vector2(4, 8)
				lab.add_theme_font_size_override("font_size", 10)
				cell.add_child(lab)
			_grid.add_child(cell)
