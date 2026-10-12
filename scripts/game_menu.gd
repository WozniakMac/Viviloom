class_name GameMenu
extends CanvasLayer
## The menu (Esc in game, or "..." on the title screen), laid out like the reference
## game's: a narrow white card titled MENU with a round close button, a column of
## pill buttons (unavailable ones greyed), and Quit Game alone in a band at the
## bottom. The game is paused while it's open.

signal save_pressed
signal load_pressed
signal main_menu_pressed
signal manage_pressed
signal closed

var _speed_before := 1
var _root: Control


## `in_game`: false on the title screen, where saving and leaving are greyed out.
func setup(has_save: bool, in_game := true) -> void:
	_speed_before = Clock.speed
	Clock.set_speed(0)
	layer = 10
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color.WHITE
	ps.set_corner_radius_all(12)
	ps.shadow_color = Color(0, 0, 0, 0.35)
	ps.shadow_size = 12
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(250, 0)
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	panel.add_child(v)

	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 46)
	v.add_child(head)
	var t := UiTheme.title(Label.new(), 22)
	t.text = "MENU"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_child(t)
	var x := IconButton.make("close", 24, "Back to the game (Esc)")
	x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	x.position = Vector2(-32, 8)
	x.pressed.connect(close)
	head.add_child(x)

	var items := [
		["Save", in_game, func(): _then(save_pressed)],
		["Save As...", false, Callable()],
		["Game Options", true, _open_options],
		["Help", true, _open_help],
		["Credits", true, _open_credits],
		["Achievements", in_game, _open_achievements],
		["Manage Households", in_game and has_save, func(): _then(manage_pressed)],
		["Main Menu", in_game, func(): _then(main_menu_pressed)],
	]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	var mc := MarginContainer.new()
	for side in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + side, 22)
	mc.add_theme_constant_override("margin_bottom", 12)
	mc.add_child(list)
	v.add_child(mc)
	for it in items:
		list.add_child(_pill(it[0], it[1], it[2]))

	# Quit sits alone in a grey band at the bottom, as in the reference.
	var band := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.86, 0.89, 0.95)
	bs.corner_radius_bottom_left = 12
	bs.corner_radius_bottom_right = 12
	bs.content_margin_left = 22
	bs.content_margin_right = 22
	bs.content_margin_top = 10
	bs.content_margin_bottom = 12
	band.add_theme_stylebox_override("panel", bs)
	v.add_child(band)
	band.add_child(_pill("Quit Game", true, func(): get_tree().quit()))

	await get_tree().process_frame
	panel.position = (_root.size - panel.size) * 0.5


func _pill(text: String, enabled: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", UiTheme.pill(Color.WHITE, Color(0.78, 0.82, 0.9), 17))
	b.add_theme_stylebox_override("disabled", UiTheme.pill(Color(0.97, 0.97, 0.98), Color(0.88, 0.9, 0.94), 17))
	b.add_theme_color_override("font_color", Color(0.12, 0.3, 0.7))
	b.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.8))
	b.disabled = not enabled
	if enabled and cb.is_valid():
		b.pressed.connect(cb)
	return b


func _then(sig: Signal) -> void:
	close()
	sig.emit()


func _open_options() -> void:
	var o := GameOptions.new()
	add_child(o)
	o.setup()


func _open_help() -> void:
	EventDialog.ask(self, null, "Help: Controls", "Live mode: click to walk or open pie menus; P, 0 or ` pause; 1 2 3 speeds; Space next Sim; Enter centre on the Sim; O needs, L skills, Y simology, R relationships, J career, G aspiration, I inventory; Home/End walls; Page Up/Down floors; Tab hides the interface.\n\nCamera: WASD pan (Shift faster), Q/E raise and lower, comma/period rotate, right-drag rotate, middle-drag pan, wheel or Z/X zoom.\n\nBuild/Buy: F2 buy, F3 build, F1 live; H hand, B wall, K sledgehammer, E eyedropper, R design tool; comma/period rotate, Delete sells.", ["Got it"] as Array[String])


func _open_achievements() -> void:
	var list: Array = get_parent().achievements() if get_parent().has_method("achievements") else []
	var lines: Array[String] = []
	var got := 0
	for a in list:
		if a[2]:
			got += 1
		lines.append("%s  %s: %s" % ["★" if a[2] else "☆", a[0], a[1]])
	EventDialog.ask(self, null, "Achievements (%d of %d)" % [got, list.size()], "
".join(lines), ["Close"] as Array[String])


func _open_credits() -> void:
	EventDialog.ask(self, null, "Credits", "OpenSims: an original life simulation made with Godot. Every model, sound and line of text was generated for this project.", ["Close"] as Array[String])


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Clock.set_speed(_speed_before)
	closed.emit()
	queue_free()
