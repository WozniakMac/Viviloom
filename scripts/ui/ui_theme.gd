class_name UiTheme
extends RefCounted
## The game's look: light panels with a cool blue tint, dark blue text, green for
## "good / selected", rounded pill buttons. Built in code and shared by every UI layer.

const PANEL := Color(0.96, 0.98, 1.0, 0.96)
const PANEL_EDGE := Color(0.72, 0.83, 0.95)
const TEXT := Color(0.11, 0.26, 0.55)
const TEXT_SOFT := Color(0.35, 0.47, 0.68)
const ACCENT := Color(0.2, 0.47, 0.88)
const HOVER := Color(0.86, 0.93, 1.0)
const GREEN := Color(0.36, 0.76, 0.24)
const GREEN_DARK := Color(0.2, 0.55, 0.15)
const RED := Color(0.86, 0.25, 0.2)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _make()
	return _theme


static func panel_style(radius := 12, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = PANEL_EDGE
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0.05, 0.12, 0.3, 0.25)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	return s


static func pill(bg: Color, border := PANEL_EDGE, radius := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func _make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15

	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	t.set_stylebox("normal", "Button", pill(Color.WHITE))
	t.set_stylebox("hover", "Button", pill(HOVER, ACCENT))
	t.set_stylebox("pressed", "Button", pill(ACCENT, ACCENT))
	t.set_stylebox("hover_pressed", "Button", pill(ACCENT.lightened(0.1), ACCENT))
	t.set_stylebox("disabled", "Button", pill(Color(0.92, 0.93, 0.95), Color(0.85, 0.87, 0.9)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.65, 0.7, 0.78))

	var edit := pill(Color.WHITE, PANEL_EDGE, 8)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", pill(Color.WHITE, ACCENT, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_SOFT)

	var tip := panel_style(8, 10)
	tip.bg_color = Color(1, 1, 1, 0.98)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)
	return t


## Sets an outline-free title look on a label.
static func title(l: Label, size := 20) -> Label:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT)
	return l
