class_name Hud
extends CanvasLayer
## Live-mode HUD: controls hint, clock, and the selected Sim's needs panel.

var sim: Sim

var _clock_label: Label
var _name_label: Label
var _bars := {}
var _bar_styles := {}


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var hint := _outlined_label("Left-click: walk   WASD: pan   Q/E or middle-drag: rotate   Wheel: zoom")
	hint.position = Vector2(16, 16)
	root.add_child(hint)

	_clock_label = _outlined_label("")
	_clock_label.add_theme_font_size_override("font_size", 22)
	_clock_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.position = Vector2(-200, 12)
	_clock_label.size = Vector2(400, 30)
	root.add_child(_clock_label)

	root.add_child(_build_needs_panel())


func set_sim(s: Sim) -> void:
	sim = s


func _process(_delta: float) -> void:
	_clock_label.text = "%s  %s   Day %d" % [Clock.weekday_name(), Clock.time_string(), Clock.day()]
	if sim == null:
		return
	_name_label.text = "%s  ·  %s" % [sim.sim_name, sim.needs.mood()]
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

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_name_label)

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
