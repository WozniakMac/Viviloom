class_name TraitHex
extends Control
## A hexagonal trait badge. Used as a clickable slot in Create a Sim and as a
## read-only badge in the Simology panel.

signal toggled(trait_id: String)

const TRAIT_COLORS := {
	"cheerful": Color(0.98, 0.78, 0.2),
	"gloomy": Color(0.35, 0.45, 0.8),
	"creative": Color(0.2, 0.7, 0.72),
	"genius": Color(0.55, 0.42, 0.85),
	"lazy": Color(0.6, 0.55, 0.45),
	"bookworm": Color(0.85, 0.45, 0.3),
	"neat": Color(0.3, 0.75, 0.85),
	"slob": Color(0.55, 0.5, 0.3),
	"active": Color(0.95, 0.5, 0.2),
	"romantic": Color(0.95, 0.45, 0.65),
	"loner": Color(0.45, 0.5, 0.6),
	"hot_headed": Color(0.85, 0.25, 0.2),
	"foodie": Color(0.8, 0.6, 0.25),
	"music_lover": Color(0.5, 0.35, 0.8),
	"ambitious": Color(0.85, 0.55, 0.15),
	"childish": Color(0.95, 0.6, 0.75),
	"goofball": Color(0.95, 0.75, 0.2),
	"self_assured": Color(0.25, 0.55, 0.85),
	"glutton": Color(0.8, 0.45, 0.3),
	"good": Color(0.45, 0.75, 0.4),
	"mean": Color(0.55, 0.2, 0.25),
	"outgoing": Color(0.2, 0.7, 0.75),
	"perfectionist": Color(0.4, 0.4, 0.75),
	"geek": Color(0.3, 0.6, 0.45),
}

var trait_id := ""
var picked := false
var blocked := false
var show_label := true
var clickable := false
var _hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_PASS
	if trait_id != "":
		tooltip_text = "%s\n%s" % [Traits.label(trait_id), Traits.description(trait_id)]
	mouse_entered.connect(func():
		_hover = true
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())


func _gui_input(e: InputEvent) -> void:
	if clickable and not blocked and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(trait_id)
		accept_event()


func _draw() -> void:
	var label_h := 20.0 if show_label else 0.0
	var c := Vector2(size.x * 0.5, (size.y - label_h) * 0.5)
	var r := minf(size.x * 0.5, (size.y - label_h) * 0.5) - 2.0
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + i * PI / 3.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var base: Color = TRAIT_COLORS.get(trait_id, UiTheme.ACCENT)
	var fill := Color.WHITE
	if picked:
		fill = base
	elif blocked:
		fill = Color(0.88, 0.9, 0.93)
	elif _hover and clickable:
		fill = UiTheme.HOVER
	draw_colored_polygon(pts, fill)
	var edge := UiTheme.GREEN if picked else (UiTheme.ACCENT if _hover and clickable and not blocked else UiTheme.PANEL_EDGE)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, edge, 3.0 if picked else 2.0, true)
	if trait_id == "":
		IconButton.draw_icon(self, "simology", c, r * 0.4, UiTheme.PANEL_EDGE)
		return
	var font := get_theme_default_font()
	var txt := Traits.label(trait_id).substr(0, 2)
	var fs := int(r * 0.7)
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var col := Color.WHITE if picked else (Color(0.7, 0.74, 0.8) if blocked else base.darkened(0.2))
	draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if show_label:
		var name := Traits.label(trait_id)
		var nfs := 12
		var ns := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs)
		while ns.x > size.x + 6.0 and nfs > 8:
			nfs -= 1
			ns = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs)
		draw_string(font, Vector2(size.x * 0.5 - ns.x * 0.5, size.y - 4.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, UiTheme.TEXT_SOFT if blocked else UiTheme.TEXT)
