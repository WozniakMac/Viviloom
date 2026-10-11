class_name Hud
extends CanvasLayer
## Live-mode HUD: controls hint, clock, action queue, notices, pie menu and needs panel.

var sim: Sim
var pie_menu: PieMenu

var _clock_label: Label
var _name_label: Label
var _bars := {}
var _bar_styles := {}
var _queue_box: HBoxContainer
var _queue_buttons: Array[Button] = []
var _notice: Label
var _notice_time := 0.0
var _speed_buttons: Array[Button] = []
var _autonomy_button: Button


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var hint := _outlined_label("Click ground: walk   Click object: interact   Click queued action: cancel   P/0-3: speed   WASD: pan   Q/E: rotate   Wheel: zoom")
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(16, -36)
	root.add_child(hint)

	_queue_box = HBoxContainer.new()
	_queue_box.position = Vector2(16, 16)
	_queue_box.add_theme_constant_override("separation", 6)
	root.add_child(_queue_box)

	_notice = _outlined_label("")
	_notice.add_theme_font_size_override("font_size", 18)
	_notice.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.position = Vector2(-300, 84)
	_notice.size = Vector2(600, 30)
	root.add_child(_notice)

	_clock_label = _outlined_label("")
	_clock_label.add_theme_font_size_override("font_size", 22)
	_clock_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.position = Vector2(-200, 10)
	_clock_label.size = Vector2(400, 30)
	root.add_child(_clock_label)

	var speeds := HBoxContainer.new()
	speeds.set_anchors_preset(Control.PRESET_CENTER_TOP)
	speeds.position = Vector2(-96, 44)
	speeds.add_theme_constant_override("separation", 4)
	root.add_child(speeds)
	var labels := ["II", ">", ">>", ">>>"]
	var tips := ["Pause (P or 0)", "Normal speed (1)", "Fast (2)", "Very fast (3)"]
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.tooltip_text = tips[i]
		b.custom_minimum_size = Vector2(44, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(Clock.set_speed.bind(i))
		speeds.add_child(b)
		_speed_buttons.append(b)
	Clock.speed_changed.connect(_on_speed_changed)
	_on_speed_changed(Clock.speed)

	root.add_child(_build_needs_panel())

	pie_menu = PieMenu.new()
	pie_menu.name = "PieMenu"
	root.add_child(pie_menu)


func set_sim(s: Sim) -> void:
	sim = s
	sim.queue_changed.connect(_rebuild_queue)
	sim.action_failed.connect(show_notice)
	_rebuild_queue()


func _on_speed_changed(speed: int) -> void:
	for i in _speed_buttons.size():
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.25, 0.55, 0.3, 0.95) if i == speed else Color(0.12, 0.15, 0.22, 0.9)
		st.set_corner_radius_all(6)
		_speed_buttons[i].add_theme_stylebox_override("normal", st)


func _on_autonomy_toggled(on: bool) -> void:
	_autonomy_button.text = "Free will: On" if on else "Free will: Off"
	if sim != null:
		sim.autonomy_enabled = on


func show_notice(text: String) -> void:
	_notice.text = text
	_notice_time = 3.0
	_notice.modulate.a = 1.0


## The action queue, top-left. The first entry is what the Sim is doing now;
## clicking an entry cancels it.
func _rebuild_queue() -> void:
	for b in _queue_buttons:
		b.queue_free()
	_queue_buttons.clear()
	for i in sim.queue.size():
		var a: Sim.SimAction = sim.queue[i]
		var b := Button.new()
		b.text = a.label
		b.tooltip_text = "Click to cancel"
		b.focus_mode = Control.FOCUS_NONE
		var col := Color(0.2, 0.42, 0.68, 0.95) if i == 0 else Color(0.13, 0.17, 0.25, 0.9)
		if a.autonomous:
			col = col.lerp(Color(0.4, 0.4, 0.4, 0.9), 0.5)
		var st := StyleBoxFlat.new()
		st.bg_color = col
		st.set_corner_radius_all(8)
		st.set_content_margin_all(8)
		b.add_theme_stylebox_override("normal", st)
		var hover := st.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.7, 0.25, 0.25, 0.95)
		b.add_theme_stylebox_override("hover", hover)
		b.pressed.connect(func(): sim.cancel(sim.queue.find(a)))
		_queue_box.add_child(b)
		_queue_buttons.append(b)


func _process(delta: float) -> void:
	if _notice_time > 0.0:
		_notice_time -= delta
		_notice.modulate.a = clampf(_notice_time, 0.0, 1.0)
	_clock_label.text = "%s  %s   Day %d" % [Clock.weekday_name(), Clock.time_string(), Clock.day()]
	if sim == null:
		return
	_name_label.text = "%s  ·  %s" % [sim.sim_name, sim.needs.mood()]
	var cur := sim.current_action()
	if cur != null and not _queue_buttons.is_empty():
		var label := cur.label
		if cur.performing:
			label += "  %d%%" % int(cur.progress() * 100.0)
		_queue_buttons[0].text = label
	for n in Needs.ORDER:
		var v := sim.needs.get_value(n)
		(_bars[n] as ProgressBar).value = v
		(_bar_styles[n] as StyleBoxFlat).bg_color = Needs.bar_color(v)


func _build_needs_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "NeedsPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.85)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(-16, -16)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)
	_autonomy_button = Button.new()
	_autonomy_button.toggle_mode = true
	_autonomy_button.button_pressed = true
	_autonomy_button.focus_mode = Control.FOCUS_NONE
	_autonomy_button.tooltip_text = "Let the Sim look after themselves when idle"
	_autonomy_button.toggled.connect(_on_autonomy_toggled)
	header.add_child(_autonomy_button)
	_on_autonomy_toggled(true)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	for n in Needs.ORDER:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = Needs.LABELS[n]
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(150, 14)
		bar.show_percentage = false
		bar.max_value = 100.0
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.2, 0.22, 0.28)
		bg.set_corner_radius_all(4)
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		grid.add_child(row)
		_bars[n] = bar
		_bar_styles[n] = fill
	return panel


func _outlined_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
