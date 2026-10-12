class_name PieMenu
extends Control
## Interaction choices as small white pills in a ring around the click, as in the
## reference (checked against the running game): no title or centre disc; pills on
## the left are right-aligned towards the centre, those on the right left-aligned,
## and the top and bottom ones centred. Two options sit above and below. Clicking
## outside the options, or Esc, closes it.

signal chosen(index: int)

const RADIUS := 105.0

var _items: Array[Control] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(at: Vector2, title: String, options: Array[String], icons: Array[String] = []) -> void:
	Sfx.play("menu_open", -6.0)
	_clear()
	var vp := get_viewport_rect().size
	at = Vector2(clampf(at.x, RADIUS + 120, vp.x - RADIUS - 120), clampf(at.y, RADIUS + 60, vp.y - RADIUS - 60))

	tooltip_text = title

	var n := options.size()
	for i in n:
		# Start at the top and go clockwise; two options sit left and right.
		var angle := -PI * 0.5 + TAU * i / maxi(n, 1)
		if n == 2:
			angle = -PI * 0.5 if i == 0 else PI * 0.5
		var b := Button.new()
		b.text = options[i]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Color(0.1, 0.22, 0.5))
		var normal := UiTheme.pill(Color(1, 1, 1, 0.97), Color(0.85, 0.88, 0.94), 14)
		normal.content_margin_top = 3
		normal.content_margin_bottom = 3
		normal.content_margin_left = 14
		normal.content_margin_right = 14
		normal.shadow_color = Color(0.05, 0.12, 0.3, 0.3)
		normal.shadow_size = 4
		normal.shadow_offset = Vector2(0, 2)
		b.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = UiTheme.HOVER
		hover.border_color = UiTheme.ACCENT
		hover.set_border_width_all(2)
		b.add_theme_stylebox_override("hover", hover)
		var pressed := hover.duplicate() as StyleBoxFlat
		pressed.bg_color = UiTheme.ACCENT
		b.add_theme_stylebox_override("pressed", pressed)
		b.pressed.connect(_on_pressed.bind(i))
		if i < icons.size() and icons[i] != "":
			# A small icon on the left of the pill, like the reference's wrench.
			for st in ["normal", "hover", "pressed"]:
				(b.get_theme_stylebox(st) as StyleBoxFlat).content_margin_left = 30
			var glyph := Glyph.new()
			glyph.icon_id = icons[i]
			glyph.position = Vector2(7, 3)
			glyph.size = Vector2(18, 18)
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(glyph)
		_place(b, at + Vector2(cos(angle), sin(angle)) * Vector2(RADIUS * 1.15, RADIUS * 0.85))
		# Side pills hug the centre: their inner edge sits on the ring.
		var cx := cos(angle)
		if absf(cx) > 0.25:
			b.position.x += b.size.x * 0.5 * signf(cx) - 12.0 * signf(cx)
		# Pop in from the centre.
		var target := b.position
		b.position = at - b.size * 0.5
		b.modulate.a = 0.0
		var tw := b.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position", target, 0.16)
		tw.tween_property(b, "modulate:a", 1.0, 0.12)
	visible = true


func close() -> void:
	_clear()
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
		accept_event()


func _on_pressed(i: int) -> void:
	close()
	chosen.emit(i)


func _place(c: Control, center_pos: Vector2) -> void:
	add_child(c)
	_items.append(c)
	c.reset_size()
	c.position = center_pos - c.size * 0.5


func _clear() -> void:
	for c in _items:
		c.queue_free()
	_items.clear()


class Glyph:
	extends Control
	var icon_id := ""

	func _draw() -> void:
		IconButton.draw_icon(self, icon_id, size * 0.5, size.x * 0.42, Color(0.1, 0.22, 0.5))
