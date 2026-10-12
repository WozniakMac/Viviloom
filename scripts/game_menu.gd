class_name GameMenu
extends CanvasLayer
## In-game menu (Esc or the "..." button): save, load, back to the title screen,
## or quit. The game is paused while it's open.

signal save_pressed
signal load_pressed
signal main_menu_pressed
signal closed

var _speed_before := 1


func setup(has_save: bool) -> void:
	_speed_before = Clock.speed
	Clock.set_speed(0)
	layer = 10
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(300, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title(Label.new(), 22)
	t.text = "Menu"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := IconButton.make("close", 28, "Back to the game (Esc)")
	x.pressed.connect(close)
	head.add_child(x)
	var music := Button.new()
	music.text = "Music: On" if Sfx.music_enabled else "Music: Off"
	music.focus_mode = Control.FOCUS_NONE
	music.custom_minimum_size = Vector2(0, 40)
	music.pressed.connect(func():
		Sfx.set_music_enabled(not Sfx.music_enabled)
		music.text = "Music: On" if Sfx.music_enabled else "Music: Off")
	for d in [["Save", save_pressed, true], ["Load", load_pressed, has_save], ["Main Menu", main_menu_pressed, true], ["Quit Game", null, true]]:
		var b := Button.new()
		b.text = d[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.disabled = not d[2]
		if d[1] == null:
			b.pressed.connect(func(): get_tree().quit())
		else:
			var sig: Signal = d[1]
			b.pressed.connect(func():
				close()
				sig.emit())
		v.add_child(b)
	v.add_child(music)
	v.move_child(music, v.get_child_count() - 2)
	# Centre after the panel has its size.
	await get_tree().process_frame
	panel.position = (root.size - panel.size) * 0.5


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Clock.set_speed(_speed_before)
	closed.emit()
	queue_free()
