class_name GameOptions
extends CanvasLayer
## The Game Options dialog, laid out like the reference game's: category tabs down
## the left (the open one green), grey section bars, blue labels beside each
## control, and Restore Defaults / Cancel Changes / Apply Changes along the bottom.

signal closed
signal applied

## tab -> [[section title, [[key, label, kind, options]...]]...]
## kinds: "check", "choice" (options = labels), "slider" (0..100), "path" (read-only)
const TABS := [
	["Graphics", [
		["Display", [["fullscreen", "Display Type", "choice", ["Windowed", "Fullscreen"]], ["vsync", "Vertical Sync", "check", []]]],
		["Graphics", [["quality", "Graphics Quality", "choice", ["Low", "Medium", "High", "Ultra"]]]],
	]],
	["Sound", [
		["Volume", [["master", "Master Volume", "slider", []], ["music", "Music", "slider", []], ["sfx", "Sound Effects", "slider", []], ["ambience", "Ambient Sounds", "slider", []]]],
	]],
	["Music", [
		["Music", [["music_on", "Play Background Music", "check", []]]],
	]],
	["Gameplay", [
		["Gameplay", [
			["free_will", "Free Will", "choice", ["Off", "Medium", "Full"]],
			["disable_selected_autonomy", "Disable Selected Sim's Autonomy", "check", []],
			["aging_played", "Auto Aging (Played Households)", "choice", ["No", "Yes"]],
			["aging_unplayed", "Auto Aging (Unplayed Households)", "check", []],
			["lifespan", "Sim Lifespan", "choice", ["Short", "Normal", "Long"]],
			["show_wants", "Show Wants", "check", []],
			["allow_burglars", "Allow Burglar Visits", "check", []],
		]],
	]],
	["Save Settings", [
		["Saving", [["autosave", "Autosave", "choice", ["Off", "Every 10 Minutes", "Every 30 Minutes", "Every 60 Minutes"]]]],
	]],
	["Environment", [
		["Lunar Cycle", [
			["lunar_cycle", "Lunar Cycle Length", "choice", ["4 Days", "8 Days (Default)", "16 Days"]],
			["lunar_fixed", "Set Fixed Phase", "choice", ["Off", "New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Third Quarter", "Waning Crescent"]],
			["lunar_effects_off", "Disable Lunar Effects", "check", []],
		]],
	]],
	["Camera", [
		["Camera", [["edge_scrolling", "Edge Scrolling", "check", []], ["sims3_camera", "The Sims 3 Camera", "check", []], ["invert_horizontal", "Invert Camera Rotation Horizontal", "check", []], ["invert_vertical", "Invert Camera Rotation Vertical", "check", []]]],
	]],
	["Screen Capture", [
		["Screenshots (C)", [["capture_ui", "Capture Interface", "check", []], ["capture_notice", "Show Notification After Screenshot", "check", []], ["capture_size", "Screenshot Size", "choice", ["Small", "Normal", "Large"]], ["", "Save Location", "path", []]]],
	]],
	["Tutorial & Tips", [
		["Tips", [["show_tips", "Show Tips", "check", []]]],
	]],
	["Other", [
		["Clock", [["clock_24h", "24-Hour Clock", "check", []]]],
	]],
	["Accessibility", [
		["Interface", [["ui_scale", "Interface Scale", "choice", ["Small", "Normal", "Large"]]]],
	]],
]

var _pending := {}
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer
var _current := 0


func setup() -> void:
	layer = 20
	if Settings.values.is_empty():
		Settings.load_file()
	_pending = Settings.values.duplicate()
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.15, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color.WHITE
	ps.set_corner_radius_all(14)
	ps.shadow_color = Color(0, 0, 0, 0.35)
	ps.shadow_size = 14
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(860, 600)
	root.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	# Title row: "GAME OPTIONS" centred with a round close button.
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 56)
	outer.add_child(head)
	var title := UiTheme.title(Label.new(), 26)
	title.text = "GAME OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_child(title)
	var x := IconButton.make("close", 30, "Close (Esc)")
	x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	x.position = Vector2(-44, 12)
	x.pressed.connect(close)
	head.add_child(x)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	outer.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(170, 0)
	tabs.add_theme_constant_override("separation", 2)
	body.add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i][0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 34)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_show_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.97, 0.98, 1.0)
	scroll.add_theme_stylebox_override("panel", cs)
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	# Bottom band with the three buttons.
	var band := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.86, 0.89, 0.95)
	bs.corner_radius_bottom_left = 14
	bs.corner_radius_bottom_right = 14
	bs.set_content_margin_all(10)
	band.add_theme_stylebox_override("panel", bs)
	outer.add_child(band)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	band.add_child(row)
	row.add_child(_band_button("Restore Defaults", func():
		_pending = Settings.DEFAULTS.duplicate()
		_show_tab(_current)))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	row.add_child(_band_button("Cancel Changes", func():
		_pending = Settings.values.duplicate()
		_show_tab(_current)))
	row.add_child(_band_button("Apply Changes", func():
		Settings.values = _pending.duplicate()
		Settings.save_file()
		Settings.apply(get_tree())
		applied.emit()))
	_show_tab(0)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) * 0.5


func _band_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200, 40)
	b.add_theme_stylebox_override("normal", UiTheme.pill(Color.WHITE, UiTheme.PANEL_EDGE, 20))
	b.pressed.connect(cb)
	return b


func _show_tab(i: int) -> void:
	_current = i
	for k in _tab_buttons.size():
		var on := k == i
		var st := StyleBoxFlat.new()
		st.bg_color = UiTheme.GREEN if on else Color.WHITE
		st.set_content_margin_all(6)
		_tab_buttons[k].add_theme_stylebox_override("normal", st)
		_tab_buttons[k].add_theme_stylebox_override("hover", st if on else UiTheme.pill(UiTheme.HOVER, UiTheme.HOVER, 0))
		_tab_buttons[k].add_theme_color_override("font_color", Color.WHITE if on else UiTheme.TEXT)
	for c in _content.get_children():
		c.queue_free()
	for section in TABS[i][1]:
		var bar := PanelContainer.new()
		var bst := StyleBoxFlat.new()
		bst.bg_color = Color(0.62, 0.67, 0.76)
		bst.set_content_margin_all(5)
		bar.add_theme_stylebox_override("panel", bst)
		var bl := Label.new()
		bl.text = section[0].to_upper()
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.add_theme_color_override("font_color", Color.WHITE)
		bl.add_theme_font_size_override("font_size", 13)
		bar.add_child(bl)
		_content.add_child(bar)
		for field in section[1]:
			_content.add_child(_field_row(field))


func _field_row(field: Array) -> Control:
	var key: String = field[0]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = field[1] + ":"
	l.custom_minimum_size = Vector2(300, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", Color(0.15, 0.4, 0.8))
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	match field[2]:
		"check":
			var c := CheckBox.new()
			c.focus_mode = Control.FOCUS_NONE
			c.button_pressed = _pending[key]
			c.toggled.connect(func(on: bool): _pending[key] = on)
			row.add_child(c)
		"choice":
			var o := OptionButton.new()
			o.focus_mode = Control.FOCUS_NONE
			o.custom_minimum_size = Vector2(220, 32)
			for opt in field[3]:
				o.add_item(opt)
			var v: Variant = _pending[key]
			o.select(int(v) if not v is bool else (1 if v else 0))
			o.item_selected.connect(func(idx: int):
				_pending[key] = (idx == 1) if Settings.DEFAULTS[key] is bool else idx)
			row.add_child(o)
		"path":
			var pl := Label.new()
			pl.text = ProjectSettings.globalize_path("user://screenshots")
			pl.add_theme_font_size_override("font_size", 12)
			pl.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
			row.add_child(pl)
			return row
		"slider":
			var s := HSlider.new()
			s.custom_minimum_size = Vector2(260, 24)
			s.min_value = 0
			s.max_value = 100
			s.value = _pending[key]
			s.value_changed.connect(func(val: float): _pending[key] = int(val))
			row.add_child(s)
	return row


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()
