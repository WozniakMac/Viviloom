class_name PieMenu
extends Control
## Interaction choices as white pills arranged in a ring around the cursor, with the
## object's name in the middle. Clicking outside the options closes it.

signal chosen(index: int)

const RADIUS := 105.0

var _items: Array[Control] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(at: Vector2, title: String, options: Array[String]) -> void:
	Sfx.play("menu_open", -6.0)
	_clear()
	var vp := get_viewport_rect().size
	at = Vector2(clampf(at.x, RADIUS + 120, vp.x - RADIUS - 120), clampf(at.y, RADIUS + 60, vp.y - RADIUS - 60))

	var center := Label.new()
	center.text = title
	center.add_theme_font_size_override("font_size", 15)
	center.add_theme_color_override("font_color", Color.WHITE)
	center.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.3, 0.85))
	center.add_theme_constant_override("outline_size", 5)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(center, at)

	var n := options.size()
	for i in n:
		# Start at the top and go clockwise; two options sit left and right.
		var angle := -PI * 0.5 + TAU * i / maxi(n, 1)
		if n == 2:
			angle = PI if i == 0 else 0.0
		var b := Button.new()
		b.text = options[i]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		var normal := UiTheme.pill(Color(1, 1, 1, 0.97), UiTheme.PANEL_EDGE, 18)
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
		_place(b, at + Vector2(cos(angle), sin(angle)) * Vector2(RADIUS * 1.25, RADIUS))
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
