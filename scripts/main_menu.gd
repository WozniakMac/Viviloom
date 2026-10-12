class_name MainMenu
extends CanvasLayer
## Title screen over a slowly orbiting view of the neighbourhood: the logo, a big
## "Play" (continue the saved game), "New Game" and "Quit".

signal play_pressed
signal new_game_pressed
signal manage_pressed

var can_continue := false


func setup(has_save: bool) -> void:
	can_continue = has_save
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# A soft blue wash on the left so the menu reads over the 3D scene.
	var wash := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.1, 0.25, 0.6, 0.85))
	grad.set_color(1, Color(0.1, 0.25, 0.6, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	wash.texture = gt
	wash.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	wash.custom_minimum_size = Vector2(700, 0)
	wash.size = Vector2(700, 900)
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wash)

	var col := VBoxContainer.new()
	col.position = Vector2(80, 140)
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)

	var logo := Logo.new()
	logo.custom_minimum_size = Vector2(420, 120)
	col.add_child(logo)

	var welcome := Label.new()
	welcome.text = "Welcome! Create Sims, build homes and tell their stories."
	welcome.add_theme_font_size_override("font_size", 18)
	welcome.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(welcome)
	col.add_child(_spacer(20))

	var play := _big_button("Play" if has_save else "New Game", true)
	play.pressed.connect(func():
		if has_save:
			play_pressed.emit()
		else:
			new_game_pressed.emit())
	col.add_child(play)
	if has_save:
		var manage := _big_button("Manage Households", false)
		manage.pressed.connect(func(): manage_pressed.emit())
		col.add_child(manage)
		var fresh := _big_button("New Game", false)
		fresh.pressed.connect(func(): new_game_pressed.emit())
		col.add_child(fresh)
	var quit := _big_button("Quit", false)
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _big_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(320, 56 if primary else 46)
	b.add_theme_font_size_override("font_size", 24 if primary else 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if primary:
		b.add_theme_stylebox_override("normal", UiTheme.pill(UiTheme.GREEN, Color.WHITE, 28))
		b.add_theme_stylebox_override("hover", UiTheme.pill(UiTheme.GREEN.lightened(0.15), Color.WHITE, 28))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		b.add_theme_stylebox_override("normal", UiTheme.pill(Color(1, 1, 1, 0.9), Color.WHITE, 24))
	return b


## The game's logo: name in white with a green diamond.
class Logo:
	extends Control

	func _draw() -> void:
		var font := get_theme_default_font()
		var c := Vector2(48, size.y * 0.5)
		IconButton.draw_icon(self, "live", c, 40.0, UiTheme.GREEN)
		draw_string_outline(font, Vector2(100, size.y * 0.5 + 26), "OpenSims", HORIZONTAL_ALIGNMENT_LEFT, -1, 76, 10, Color(0.05, 0.15, 0.4, 0.5))
		draw_string(font, Vector2(100, size.y * 0.5 + 26), "OpenSims", HORIZONTAL_ALIGNMENT_LEFT, -1, 76, Color.WHITE)
