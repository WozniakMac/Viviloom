class_name PieMenu
extends Control
## A radial menu of interaction choices that opens around the cursor.
## Clicking outside the options closes it.

signal chosen(index: int)

const RADIUS := 110.0

var _items: Array[Control] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(at: Vector2, title: String, options: Array[String]) -> void:
	_clear()
	var vp := get_viewport_rect().size
	at = Vector2(clampf(at.x, RADIUS + 110, vp.x - RADIUS - 110), clampf(at.y, RADIUS + 40, vp.y - RADIUS - 40))

	var center := _make_label(title)
	_place(center, at)

	var n := options.size()
	for i in n:
		# Start at the top and go clockwise.
		var angle := -PI * 0.5 + TAU * i / maxi(n, 1)
		if n == 1:
			angle = -PI * 0.5
		var b := Button.new()
		b.text = options[i]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		var normal := _style(Color(0.13, 0.2, 0.33, 0.95))
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", _style(Color(0.22, 0.42, 0.7, 0.98)))
		b.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.55, 0.85, 1.0)))
		b.pressed.connect(_on_pressed.bind(i))
		_place(b, at + Vector2(cos(angle), sin(angle)) * RADIUS)
	visible = true


func close() -> void:
	_clear()
	visible = false


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


func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(18)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.border_color = Color(1, 1, 1, 0.5)
	s.set_border_width_all(1)
	return s


func _clear() -> void:
	for c in _items:
		c.queue_free()
	_items.clear()
