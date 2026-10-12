class_name EventDialog
extends CanvasLayer
## A modal event card: a Sim's face on the left, a big capitalised title, a short
## message, optionally a text field, and stacked pill buttons. The world dims and
## time pauses until the player answers.

## Emitted with the index of the button pressed (and the text field's contents).
signal answered(choice: int, text: String)

var _speed_before := 1
var _edit: LineEdit


## `face` is a Sim whose portrait is shown (or null).
static func ask(parent: Node, face: Sim, title: String, message: String, buttons: Array[String], text_field := "") -> EventDialog:
	var d := EventDialog.new()
	parent.add_child(d)
	d._build(face, title, message, buttons, text_field)
	return d


func _build(face: Sim, title: String, message: String, buttons: Array[String], text_field: String) -> void:
	layer = 15
	_speed_before = Clock.speed
	Clock.set_speed(0)
	Sfx.play("notice", -4.0)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.15, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(12, 16))
	card.custom_minimum_size = Vector2(440, 0)
	root.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	if face != null:
		var portrait := SimPortrait.new()
		portrait.sim = face
		portrait.ring_color = UiTheme.PANEL_EDGE
		portrait.custom_minimum_size = Vector2(96, 96)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(portrait)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	top.add_child(text)
	var t := UiTheme.title(Label.new(), 22)
	t.text = title.to_upper()
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(320, 0)
	text.add_child(t)
	var m := Label.new()
	m.text = message
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size = Vector2(320, 0)
	m.add_theme_font_size_override("font_size", 15)
	m.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	text.add_child(m)
	if text_field != "":
		_edit = LineEdit.new()
		_edit.text = text_field
		_edit.select_all_on_focus = true
		_edit.custom_minimum_size = Vector2(0, 38)
		v.add_child(_edit)
		_edit.grab_focus.call_deferred()
	for i in buttons.size():
		var b := Button.new()
		b.text = buttons[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_answer.bind(i))
		v.add_child(b)
	await get_tree().process_frame
	card.position = (root.size - card.size) * 0.5


func _answer(i: int) -> void:
	Clock.set_speed(_speed_before)
	answered.emit(i, _edit.text.strip_edges() if _edit != null else "")
	queue_free()
