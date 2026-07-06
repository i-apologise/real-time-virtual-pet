class_name UiTheme
extends RefCounted
## Shared UI tokens + constructors for consistent product chrome (P0 foundation).

# --- Palette ---
const BG_PANEL := Color(0.99, 0.97, 0.90)
const BG_PANEL_ALT := Color(0.96, 0.94, 0.88)
const BG_DISABLED := Color(0.88, 0.86, 0.82)
const BG_SELECTED := Color(0.85, 0.18, 0.14)
const BORDER := Color(0.12, 0.10, 0.08)
const BORDER_SOFT := Color(0.75, 0.72, 0.65)
const BORDER_SELECTED := Color(0.45, 0.05, 0.05)
const TEXT_DARK := Color(0.12, 0.10, 0.08)
const TEXT_MUTED := Color(0.35, 0.32, 0.28)
const TEXT_ON_DARK := Color(0.98, 0.98, 0.96)
const TEXT_ON_SELECTED := Color(1.0, 1.0, 0.95)
const TEXT_ACCENT := Color(0.55, 0.15, 0.12)
const TEXT_TOAST := Color(1.0, 0.96, 0.55)
const TEXT_HINT_WORLD := Color(0.95, 0.95, 0.88)
const SHADOW := Color(0, 0, 0, 0.35)
const BAR_FILL_OK := Color(0.35, 0.72, 0.42)
const BAR_FILL_MID := Color(0.9, 0.75, 0.25)
const BAR_FILL_BAD := Color(0.85, 0.28, 0.22)
const BAR_BG := Color(0.85, 0.82, 0.76)


static func panel_style(shadow: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 6
	return sb


static func slim_bar_style() -> StyleBoxFlat:
	## Thin top chrome — avoids fat “dialog” panels in the corner.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.90, 0.94)
	sb.border_color = BORDER_SOFT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func slim_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = false
	b.custom_minimum_size = Vector2(0, 22)
	b.add_theme_font_size_override("font_size", 11)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func row_style(selected: bool, disabled: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = BG_SELECTED
		sb.border_color = BORDER_SELECTED
	elif disabled:
		sb.bg_color = BG_DISABLED
		sb.border_color = BORDER_SOFT
	else:
		sb.bg_color = BG_PANEL_ALT
		sb.border_color = BORDER_SOFT
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func apply_panel(panel: PanelContainer, shadow: bool = true) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(shadow))


static func title_label(text: String = "", size: int = 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT_DARK)
	return l


static func body_label(text: String = "", size: int = 12) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func world_hint_label(text: String = "", size: int = 12) -> Label:
	## On-canvas overlay text (over game world).
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT_ON_DARK)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l


static func toast_label(text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", TEXT_TOAST)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func accent_label(text: String = "", size: int = 12) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT_ACCENT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func themed_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_font_size_override("font_size", 12)
	return b


static func style_progress_bar(bar: ProgressBar, fill: Color = BAR_FILL_OK) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = BAR_BG
	bg.set_corner_radius_all(3)
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


static func fill_for_need(v: float) -> Color:
	if v <= 5.0:
		return BAR_FILL_BAD
	if v < 40.0:
		return BAR_FILL_MID
	return BAR_FILL_OK


static func margin_root(parent: Control, left: int = 12, top: int = 10, right: int = 12, bottom: int = 10) -> void:
	## Helper no-op placeholder for future margin containers.
	pass
