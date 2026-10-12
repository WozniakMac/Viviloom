class_name MainMenu
extends CanvasLayer
## Title screen over a slowly orbiting view of the neighbourhood: the logo, a big
## "Play" (continue the saved game), "New Game" and "Quit".

signal play_pressed
signal new_game_pressed
signal manage_pressed
signal options_pressed

var can_continue := false


func setup(has_save: bool, info := "") -> void:
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

	# Small logo in the top-left corner, as in the reference.
	var logo := Logo.new()
	logo.custom_minimum_size = Vector2(300, 80)
	logo.size = Vector2(300, 80)
	logo.scale = Vector2(0.6, 0.6)
	logo.position = Vector2(40, 20)
	root.add_child(logo)

	var col := VBoxContainer.new()
	col.position = Vector2(70, 230)
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	if info != "":
		# Who lives in the last-played home, like the reference's title screen.
		var who := Label.new()
		who.text = info
		who.add_theme_font_size_override("font_size", 17)
		who.add_theme_color_override("font_color", Color.WHITE)
		col.add_child(who)

	var play := _big_button("Resume Game" if has_save else "New Game", true)
	play.pressed.connect(func():
		if has_save:
			play_pressed.emit()
		else:
			new_game_pressed.emit())
	col.add_child(play)
	if has_save:
		var manage := _big_button("Load Game", false)
		manage.pressed.connect(func(): manage_pressed.emit())
		col.add_child(manage)
		var fresh := _big_button("New Game", false)
		fresh.pressed.connect(func(): new_game_pressed.emit())
		col.add_child(fresh)
	# Options and Quit live in the "..." menu at the top right, as in the reference.
	var dots := IconButton.make("menu", 46, "Menu")
	dots.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dots.position = Vector2(-70, 20)
	dots.pressed.connect(func(): options_pressed.emit())
	root.add_child(dots)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## Big white text links (the primary one with a plumbob), like the reference's title.
func _big_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = ("      " if primary else "") + text
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 58 if primary else 46)
	b.add_theme_font_size_override("font_size", 38 if primary else 30)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(0.75, 0.95, 0.75))
	b.add_theme_color_override("font_pressed_color", Color(0.6, 0.9, 0.6))
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.4, 0.6))
	b.add_theme_constant_override("outline_size", 6)
	if primary:
		var gem := Gem.new()
		gem.position = Vector2(4, 6)
		gem.size = Vector2(36, 46)
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(gem)
	return b


## The outlined plumbob beside "Resume Game".
class Gem:
	extends Control

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(w * 0.5, 0), Vector2(w, h * 0.5), Vector2(w * 0.5, h), Vector2(0, h * 0.5), Vector2(w * 0.5, 0)])
		draw_polyline(pts, Color.WHITE, 2.0, true)
		draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), Color.WHITE, 1.5, true)


## The game's logo: name in white with a green diamond.
class Logo:
	extends Control

	func _draw() -> void:
		var font := get_theme_default_font()
		var c := Vector2(48, size.y * 0.5)
		IconButton.draw_icon(self, "live", c, 40.0, UiTheme.GREEN)
		draw_string_outline(font, Vector2(100, size.y * 0.5 + 26), "OpenSims", HORIZONTAL_ALIGNMENT_LEFT, -1, 76, 10, Color(0.05, 0.15, 0.4, 0.5))
		draw_string(font, Vector2(100, size.y * 0.5 + 26), "OpenSims", HORIZONTAL_ALIGNMENT_LEFT, -1, 76, Color.WHITE)
