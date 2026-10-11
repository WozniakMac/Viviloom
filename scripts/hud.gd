class_name Hud
extends CanvasLayer
## Live-mode HUD: controls hint, clock, action queue, notices, pie menu, the Sim's
## portrait card (mood and moodlets) and the needs / skills / traits panel.

var sim: Sim
var pie_menu: PieMenu

var _clock_label: Label
var _name_label: Label
var _portrait: PanelContainer
var _mood_style: StyleBoxFlat
var _mood_label: Label
var _moodlet_box: HFlowContainer
var _moodlet_tiles := {}
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _skills_box: VBoxContainer
var _skill_rows := {}
var _traits_box: VBoxContainer
var _bars := {}
var _bar_styles := {}
var _queue_box: HBoxContainer
var _queue_buttons: Array[Button] = []
var _notice: Label
var _notice_time := 0.0
var _speed_buttons: Array[Button] = []
var _autonomy_button: Button
var _hint: Label
var _funds_label: Label
var _mode_buttons: Array[Button] = []
var _walls_button: Button
var build: BuildMode


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hint = _outlined_label("Click: walk / interact    Click queue: cancel    P, 1-3: speed    F3: build    V: walls    WASD, Q/E, wheel: camera")
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-400, -26)
	_hint.size = Vector2(800, 20)
	root.add_child(_hint)

	var top_right := HBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.position = Vector2(-16, 16)
	top_right.add_theme_constant_override("separation", 6)
	root.add_child(top_right)
	_funds_label = _outlined_label("")
	_funds_label.add_theme_font_size_override("font_size", 20)
	top_right.add_child(_funds_label)
	_walls_button = Button.new()
	_walls_button.focus_mode = Control.FOCUS_NONE
	_walls_button.tooltip_text = "Wall view (V)"
	_walls_button.custom_minimum_size = Vector2(130, 32)
	top_right.add_child(_walls_button)
	for m in [["Live", "Live mode (F1)"], ["Build", "Build mode (F3)"]]:
		var b := Button.new()
		b.text = m[0]
		b.tooltip_text = m[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(70, 32)
		top_right.add_child(b)
		_mode_buttons.append(b)

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

	root.add_child(_build_sim_panel())
	root.add_child(_build_portrait())

	pie_menu = PieMenu.new()
	pie_menu.name = "PieMenu"
	root.add_child(pie_menu)


func set_build(b: BuildMode, lot: Lot) -> void:
	build = b
	_mode_buttons[0].pressed.connect(build.exit)
	_mode_buttons[1].pressed.connect(build.enter)
	_walls_button.pressed.connect(func():
		lot.wall_view = ((lot.wall_view + 1) % 3) as Lot.WallView
		refresh_walls_button(lot))
	build.funds_changed.connect(func(f: int): _funds_label.text = "$%s" % _thousands(f))
	build.notice.connect(show_notice)
	_funds_label.text = "$%s" % _thousands(build.funds)
	refresh_walls_button(lot)


func refresh_walls_button(lot: Lot) -> void:
	_walls_button.text = ["Walls: Up", "Walls: Cutaway", "Walls: Down"][lot.wall_view]


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func set_sim(s: Sim) -> void:
	sim = s
	sim.queue_changed.connect(_rebuild_queue)
	sim.action_failed.connect(show_notice)
	sim.announced.connect(show_notice)
	sim.emotions.changed.connect(_rebuild_moodlets)
	_name_label.text = sim.sim_name
	_rebuild_queue()
	_rebuild_moodlets()
	_rebuild_traits()


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
	if build != null:
		_mode_buttons[0].button_pressed = not build.active
		_mode_buttons[1].button_pressed = build.active
		_hint.visible = not build.active
		_queue_box.visible = not build.active
		_portrait.visible = not build.active
		if build.active and pie_menu.visible:
			pie_menu.close()
	if sim == null:
		return
	_mood_label.text = sim.emotions.mood_label()
	_mood_style.bg_color = Emotions.color(sim.emotions.mood()).darkened(0.15)
	_refresh_moodlet_tooltips()
	_refresh_skills()
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


## Bottom-right panel with Needs / Skills / Traits tabs.
func _build_sim_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "SimPanel"
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(-16, -16)
	panel.custom_minimum_size = Vector2(360, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)
	for t in ["Needs", "Skills", "Traits"]:
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_page.bind(_tabs.size()))
		header.add_child(b)
		_tabs.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
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
	_pages.append(grid)
	for n in Needs.ORDER:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = Needs.LABELS[n]
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var bar := _bar(Vector2(160, 14))
		row.add_child(bar)
		grid.add_child(row)
		_bars[n] = bar
		_bar_styles[n] = bar.get_theme_stylebox("fill")

	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_skills_box)
	_pages.append(_skills_box)

	_traits_box = VBoxContainer.new()
	_traits_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_traits_box)
	_pages.append(_traits_box)
	_show_page(0)
	return panel


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tabs[i].button_pressed = i == index


## Bottom-left card: name, a mood plate in the emotion's colour, and moodlets.
func _build_portrait() -> Control:
	_portrait = PanelContainer.new()
	_portrait.name = "Portrait"
	_portrait.add_theme_stylebox_override("panel", _panel_style())
	_portrait.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_portrait.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_portrait.position = Vector2(16, -16)
	_portrait.custom_minimum_size = Vector2(300, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_portrait.add_child(vbox)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_name_label)

	var plate := PanelContainer.new()
	_mood_style = StyleBoxFlat.new()
	_mood_style.set_corner_radius_all(8)
	_mood_style.content_margin_left = 12
	_mood_style.content_margin_right = 12
	_mood_style.content_margin_top = 4
	_mood_style.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", _mood_style)
	plate.tooltip_text = "Mood is the strongest emotion among the moodlets below."
	vbox.add_child(plate)
	_mood_label = Label.new()
	_mood_label.add_theme_font_size_override("font_size", 17)
	_mood_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_mood_label.add_theme_constant_override("outline_size", 3)
	plate.add_child(_mood_label)

	_moodlet_box = HFlowContainer.new()
	_moodlet_box.add_theme_constant_override("h_separation", 6)
	_moodlet_box.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_moodlet_box)
	return _portrait


## One tile per moodlet, coloured by its emotion; hover for details.
func _rebuild_moodlets() -> void:
	for c in _moodlet_box.get_children():
		c.queue_free()
	_moodlet_tiles.clear()
	for m in sim.emotions.moodlets:
		var tile := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Emotions.color(m.emotion)
		st.set_corner_radius_all(8)
		st.border_color = Color(1, 1, 1, 0.7)
		st.set_border_width_all(2)
		st.set_content_margin_all(2)
		tile.add_theme_stylebox_override("panel", st)
		tile.custom_minimum_size = Vector2(44, 44)
		var text := Label.new()
		text.text = "%s\n+%d" % [_initials(m.label), m.weight]
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 12)
		text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		text.add_theme_constant_override("outline_size", 3)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(text)
		_moodlet_box.add_child(tile)
		_moodlet_tiles[m] = tile
	_refresh_moodlet_tooltips()


func _refresh_moodlet_tooltips() -> void:
	for m in _moodlet_tiles:
		var tip := "%s  (+%d %s)" % [m.label, m.weight, Emotions.label(m.emotion)]
		if m.description != "":
			tip += "\n" + m.description
		var left := Emotions.describe_time(m.remaining)
		if left != "":
			tip += "\n" + left
		(_moodlet_tiles[m] as Control).tooltip_text = tip


static func _initials(text: String) -> String:
	var out := ""
	for w in text.split(" ", false):
		if out.length() < 2:
			out += w.substr(0, 1).to_upper()
	return out


func _refresh_skills() -> void:
	var known := sim.skills.known()
	if known.size() != _skill_rows.size() or (known.is_empty() and _skills_box.get_child_count() == 0):
		for c in _skills_box.get_children():
			c.queue_free()
		_skill_rows.clear()
		if known.is_empty():
			var none := Label.new()
			none.text = "No skills yet. Cook, paint, study or play chess to learn."
			none.add_theme_font_size_override("font_size", 13)
			none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			none.custom_minimum_size = Vector2(330, 0)
			_skills_box.add_child(none)
		for sk in known:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var name_label := Label.new()
			name_label.custom_minimum_size = Vector2(130, 0)
			name_label.add_theme_font_size_override("font_size", 14)
			row.add_child(name_label)
			var bar := _bar(Vector2(170, 12))
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.35, 0.65, 0.95)
			row.add_child(bar)
			_skills_box.add_child(row)
			_skill_rows[sk] = [name_label, bar]
	for sk in _skill_rows:
		var lvl := sim.skills.level(sk)
		(_skill_rows[sk][0] as Label).text = "%s  %d" % [Skills.label(sk), lvl]
		var bar := _skill_rows[sk][1] as ProgressBar
		bar.value = sim.skills.progress(sk) * 100.0
		bar.tooltip_text = "Level %d of %d. Learns faster while %s." % [lvl, Skills.MAX_LEVEL, Emotions.label(Skills.boosting_emotion(sk))]


func _rebuild_traits() -> void:
	for c in _traits_box.get_children():
		c.queue_free()
	for t in sim.traits:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var title := Label.new()
		title.text = Traits.label(t)
		title.add_theme_font_size_override("font_size", 15)
		row.add_child(title)
		var desc := Label.new()
		desc.text = Traits.description(t)
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(330, 0)
		row.add_child(desc)
		_traits_box.add_child(row)


func _bar(min_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.show_percentage = false
	bar.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.22, 0.28)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.85)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	return style


func _outlined_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
