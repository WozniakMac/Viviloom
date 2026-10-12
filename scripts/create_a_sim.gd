class_name CreateASim
extends CanvasLayer
## Start-of-game screen for making the household's Sim, shown in a studio with a
## soft gradient backdrop: name and traits top-left (traits as hexagon slots),
## appearance swatches on the right, rotate arrows below the Sim and a green tick to
## finish. Edits apply to the Sim immediately.

signal view_requested(close_up: bool)
signal finished
signal member_selected(sim: Sim)
signal add_requested
signal remove_requested(sim: Sim)

const PALETTES := {
	"skin": [Color(0.96, 0.8, 0.69), Color(0.87, 0.69, 0.55), Color(0.76, 0.57, 0.42), Color(0.6, 0.42, 0.3), Color(0.45, 0.3, 0.2), Color(0.32, 0.21, 0.15)],
	"hair": [Color(0.08, 0.07, 0.07), Color(0.25, 0.16, 0.1), Color(0.5, 0.32, 0.17), Color(0.85, 0.7, 0.4), Color(0.7, 0.25, 0.12), Color(0.75, 0.75, 0.78)],
	"shirt": [Color(0.22, 0.47, 0.82), Color(0.2, 0.62, 0.38), Color(0.85, 0.3, 0.45), Color(0.95, 0.75, 0.2), Color(0.55, 0.35, 0.75), Color(0.92, 0.92, 0.9)],
	"pants": [Color(0.18, 0.2, 0.28), Color(0.3, 0.4, 0.62), Color(0.45, 0.35, 0.25), Color(0.12, 0.12, 0.12), Color(0.6, 0.58, 0.5), Color(0.5, 0.15, 0.2)],
	"eyes": [Color(0.25, 0.17, 0.1), Color(0.12, 0.08, 0.05), Color(0.2, 0.45, 0.75), Color(0.25, 0.55, 0.35), Color(0.5, 0.5, 0.55), Color(0.55, 0.4, 0.2)],
}
const PART_LABELS := {"skin": "Skin Tone", "hair": "Hair Colour", "eyes": "Eye Colour", "shirt": "Top", "pants": "Bottom"}
const RANDOM_NAMES: Array[String] = ["Ada", "Bruno", "Celia", "Dario", "Edie", "Felix", "Greta", "Hugo", "Iris", "Jonas", "Kira", "Leo", "Mila", "Nico", "Olga", "Pablo"]

var sim: Sim
var _name_edit: LineEdit
var _slots: Array[TraitHex] = []
var _choices := {}
var _picked: Array[String] = []
var _trait_info: Label
var _done: IconButton
var _swatches := {}
var _aspiration_pick: OptionButton
var _walk_pick: OptionButton
var _hair_buttons := {}
var _age_buttons := {}
var _outfit_buttons := {}
var _heavy_slider: HSlider
var _fit_slider: HSlider
var _face_sliders := {}
var _sleeve_buttons: Array[Button] = []
var _leg_buttons: Array[Button] = []
var _rng := RandomNumberGenerator.new()
var _household_row: HBoxContainer


func setup(p_sim: Sim) -> void:
	sim = p_sim
	_picked = sim.traits.duplicate()
	_build()
	_refresh()
	_pick_outfit(sim.outfit)


func _build() -> void:
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top-left: name and trait slots.
	var left := VBoxContainer.new()
	left.position = Vector2(24, 20)
	left.add_theme_constant_override("separation", 12)
	root.add_child(left)
	var name_pill := PanelContainer.new()
	name_pill.add_theme_stylebox_override("panel", UiTheme.panel_style(22, 8))
	left.add_child(name_pill)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_pill.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.text = sim.sim_name
	_name_edit.placeholder_text = "First name"
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(260, 36)
	_name_edit.add_theme_font_size_override("font_size", 18)
	_name_edit.text_changed.connect(func(t: String):
		sim.sim_name = t.strip_edges()
		_refresh())
	name_row.add_child(_name_edit)
	var dice := IconButton.make("dice", 38, "Randomize name, look and traits")
	dice.pressed.connect(randomize_sim)
	name_row.add_child(dice)

	# The lifelong aspiration, picked from a compact list under the name.
	_aspiration_pick = OptionButton.new()
	_aspiration_pick.focus_mode = Control.FOCUS_NONE
	_aspiration_pick.custom_minimum_size = Vector2(380, 34)
	_aspiration_pick.add_theme_font_size_override("font_size", 14)
	for a in Aspirations.ORDER:
		_aspiration_pick.add_item("Aspiration: %s  ·  %s" % [Aspirations.label(a), Aspirations.INFO[a]["category"]])
	_aspiration_pick.item_selected.connect(func(idx: int): _pick_aspiration(Aspirations.ORDER[idx]))
	left.add_child(_aspiration_pick)
	_pick_aspiration(sim.aspiration)
	_walk_pick = OptionButton.new()
	_walk_pick.focus_mode = Control.FOCUS_NONE
	_walk_pick.custom_minimum_size = Vector2(380, 34)
	_walk_pick.add_theme_font_size_override("font_size", 14)
	for w in Sim.WALK_STYLE_ORDER:
		_walk_pick.add_item("Walk Style: %s" % Sim.WALK_STYLES[w][0])
	_walk_pick.item_selected.connect(func(idx: int):
		sim.walk_style = Sim.WALK_STYLE_ORDER[idx]
		sim.preview_walk())
	left.add_child(_walk_pick)
	_walk_pick.select(Sim.WALK_STYLE_ORDER.find(sim.walk_style))

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 4)
	left.add_child(slots_row)
	for i in Traits.MAX_TRAITS:
		var h := TraitHex.new()
		h.custom_minimum_size = Vector2(70, 70)
		h.show_label = false
		h.clickable = true
		h.toggled.connect(_on_slot_clicked)
		slots_row.add_child(h)
		_slots.append(h)

	var picker := PanelContainer.new()
	picker.custom_minimum_size = Vector2(380, 0)
	left.add_child(picker)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	picker.add_child(pv)
	var pt := UiTheme.title(Label.new(), 18)
	pt.text = "Choose Traits"
	pv.add_child(pt)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	pv.add_child(grid)
	for t in Traits.ORDER:
		var h := TraitHex.new()
		h.trait_id = t
		h.clickable = true
		h.custom_minimum_size = Vector2(68, 74)
		h.toggled.connect(_on_trait_clicked)
		h.mouse_entered.connect(func(): _trait_info.text = "%s: %s" % [Traits.label(t), Traits.description(t)])
		grid.add_child(h)
		_choices[t] = h
	_trait_info = Label.new()
	_trait_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trait_info.custom_minimum_size = Vector2(350, 42)
	_trait_info.add_theme_font_size_override("font_size", 14)
	_trait_info.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	_trait_info.text = "Pick up to %d traits. They shape moods, skills and what your Sim likes to do." % Traits.MAX_TRAITS
	pv.add_child(_trait_info)

	# Body shape and outfit cut.
	var body := PanelContainer.new()
	body.custom_minimum_size = Vector2(380, 0)
	left.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	body.add_child(bv)
	var bt := UiTheme.title(Label.new(), 18)
	bt.text = "Body & Outfit"
	bv.add_child(bt)
	_heavy_slider = _slider(bv, "Weight")
	_fit_slider = _slider(bv, "Fitness")
	_heavy_slider.value_changed.connect(func(v: float): sim.set_body(v, sim.body_fit))
	_fit_slider.value_changed.connect(func(v: float): sim.set_body(sim.body_heavy, v))
	_sleeve_buttons = _choice_row(bv, "Sleeves", ["Short", "Long"], func(i: int): sim.set_outfit(i == 1, sim.shorts))
	_leg_buttons = _choice_row(bv, "Legs", ["Trousers", "Shorts", "Skirt"], func(i: int): sim.set_legs(["trousers", "shorts", "skirt"][i]))
	var face_panel := PanelContainer.new()
	face_panel.visible = false
	face_panel.custom_minimum_size = Vector2(380, 0)
	left.add_child(face_panel)
	var face_controls := VBoxContainer.new()
	face_controls.add_theme_constant_override("separation", 8)
	face_panel.add_child(face_controls)
	view_requested.connect(func(close_up: bool):
		body.visible = not close_up
		face_panel.visible = close_up)
	var face_title := UiTheme.title(Label.new(), 18)
	face_title.text = "Face"
	face_controls.add_child(face_title)
	for feature in sim.face_features:
		var labels := {"NoseWidth": "Nose", "JawWidth": "Jaw", "EyeSpacing": "Eyes", "LipFullness": "Lips"}
		var slider := _slider(face_controls, labels[feature])
		slider.min_value = -1.0
		slider.value = 0.0
		slider.value_changed.connect(func(value: float): sim.set_face_feature(feature, value))
		slider.drag_started.connect(func(): view_requested.emit(true))
		_face_sliders[feature] = slider
	_sync_body()

	# Right: appearance.
	var look := PanelContainer.new()
	look.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	look.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	look.position = Vector2(-24, 20)
	root.add_child(look)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	look.add_child(lv)
	var lt := UiTheme.title(Label.new(), 18)
	lt.text = "Appearance"
	lv.add_child(lt)
	var al := Label.new()
	al.text = "Age"
	al.add_theme_font_size_override("font_size", 14)
	al.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	lv.add_child(al)
	var arow := HFlowContainer.new()
	arow.add_theme_constant_override("h_separation", 4)
	arow.add_theme_constant_override("v_separation", 4)
	arow.custom_minimum_size = Vector2(250, 0)
	lv.add_child(arow)
	for stage in ["child", "teen", "young_adult", "adult", "elder"]:
		var ab := Button.new()
		ab.text = Ages.label(stage)
		ab.toggle_mode = true
		ab.focus_mode = Control.FOCUS_NONE
		ab.add_theme_font_size_override("font_size", 12)
		ab.add_theme_stylebox_override("pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		ab.add_theme_stylebox_override("hover_pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		ab.pressed.connect(_pick_age.bind(stage))
		arow.add_child(ab)
		_age_buttons[stage] = ab
	_pick_age(sim.age_stage)
	var ol := Label.new()
	ol.text = "Outfit"
	ol.add_theme_font_size_override("font_size", 14)
	ol.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	lv.add_child(ol)
	var orow := HFlowContainer.new()
	orow.add_theme_constant_override("h_separation", 4)
	orow.add_theme_constant_override("v_separation", 4)
	orow.custom_minimum_size = Vector2(250, 0)
	lv.add_child(orow)
	for cat in Sim.OUTFITS:
		var obtn := Button.new()
		obtn.text = Sim.OUTFIT_LABELS[cat]
		obtn.toggle_mode = true
		obtn.focus_mode = Control.FOCUS_NONE
		obtn.add_theme_font_size_override("font_size", 12)
		obtn.add_theme_stylebox_override("pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		obtn.add_theme_stylebox_override("hover_pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		obtn.pressed.connect(_pick_outfit.bind(cat))
		orow.add_child(obtn)
		_outfit_buttons[cat] = obtn
	var hl := Label.new()
	hl.text = "Hairstyle"
	hl.add_theme_font_size_override("font_size", 14)
	hl.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	lv.add_child(hl)
	var hrow := HFlowContainer.new()
	hrow.add_theme_constant_override("h_separation", 4)
	hrow.add_theme_constant_override("v_separation", 4)
	hrow.custom_minimum_size = Vector2(250, 0)
	lv.add_child(hrow)
	for style in Sim.HAIR_STYLES:
		var hb := Button.new()
		hb.text = "Tousled" if style == "curly" else style.capitalize()
		hb.toggle_mode = true
		hb.focus_mode = Control.FOCUS_NONE
		hb.custom_minimum_size = Vector2(0, 28)
		hb.add_theme_font_size_override("font_size", 12)
		hb.add_theme_stylebox_override("pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		hb.add_theme_stylebox_override("hover_pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		hb.pressed.connect(_pick_hair.bind(style))
		hrow.add_child(hb)
		_hair_buttons[style] = hb
	_pick_hair(sim.hair_style)
	for part in ["skin", "hair", "eyes", "shirt", "pants"]:
		var l := Label.new()
		l.text = PART_LABELS[part]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		lv.add_child(l)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		lv.add_child(row)
		_swatches[part] = []
		for c in PALETTES[part]:
			var sw := Button.new()
			sw.custom_minimum_size = Vector2(38, 38)
			sw.focus_mode = Control.FOCUS_NONE
			sw.toggle_mode = true
			sw.add_theme_stylebox_override("normal", _swatch_style(c, false))
			sw.add_theme_stylebox_override("hover", _swatch_style(c, true))
			sw.add_theme_stylebox_override("pressed", _swatch_style(c, true))
			sw.add_theme_stylebox_override("hover_pressed", _swatch_style(c, true))
			sw.pressed.connect(_on_swatch.bind(part, c))
			row.add_child(sw)
			_swatches[part].append([sw, c])

	var view_row := HBoxContainer.new()
	lv.add_child(view_row)
	for close_up in [true, false]:
		var view := Button.new()
		view.text = "Face view" if close_up else "Full body"
		view.pressed.connect(func(): view_requested.emit(close_up))
		view_row.add_child(view)

	# Bottom centre: turn the Sim.
	var turn := HBoxContainer.new()
	turn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	turn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	turn.position = Vector2(-60, -76)
	turn.add_theme_constant_override("separation", 24)
	root.add_child(turn)
	for d in [["rotate_left", 0.6], ["rotate_right", -0.6]]:
		var b := IconButton.make(d[0], 48, "Turn the Sim")
		b.pressed.connect(func(): _turn(d[1]))
		turn.add_child(b)

	# Bottom left: the household, with + to add another Sim.
	var hh := PanelContainer.new()
	hh.add_theme_stylebox_override("panel", UiTheme.panel_style(26, 6))
	hh.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hh.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hh.position = Vector2(24, -24)
	root.add_child(hh)
	_household_row = HBoxContainer.new()
	_household_row.add_theme_constant_override("separation", 6)
	hh.add_child(_household_row)

	# Bottom right: done.
	_done = IconButton.make("check", 72, "")
	_done.glyph_color = Color.WHITE
	_done.add_theme_stylebox_override("normal", UiTheme.pill(UiTheme.GREEN, Color.WHITE, 36))
	_done.add_theme_stylebox_override("hover", UiTheme.pill(UiTheme.GREEN.lightened(0.15), Color.WHITE, 36))
	_done.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_done.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_done.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_done.position = Vector2(-24 - 72, -24 - 72)
	_done.pressed.connect(_finish)
	root.add_child(_done)
	_sync_swatches()


## Shows the household along the bottom; the Sim being edited is outlined.
func set_household(members: Array, max_size: int) -> void:
	for c in _household_row.get_children():
		c.queue_free()
	for m in members:
		var icon := Hud.MemberIcon.new()
		icon.member = m
		icon.active = m == sim
		icon.custom_minimum_size = Vector2(48, 48)
		icon.tooltip_text = m.sim_name if m.sim_name != "" else "New Sim"
		icon.clicked.connect(func(): member_selected.emit(m))
		_household_row.add_child(icon)
	if members.size() < max_size:
		var add := IconButton.make("add", 48, "Add a Sim to the household")
		add.pressed.connect(func(): add_requested.emit())
		_household_row.add_child(add)
	if members.size() > 1:
		var rm := IconButton.make("close", 48, "Remove %s from the household" % sim.sim_name)
		rm.pressed.connect(func(): remove_requested.emit(sim))
		_household_row.add_child(rm)


## Switches the panels to another household member.
func edit(s: Sim) -> void:
	sim = s
	_picked = s.traits.duplicate()
	_name_edit.text = s.sim_name
	_pick_hair(s.hair_style)
	_sync_walk()
	_pick_age(s.age_stage)
	_pick_aspiration(s.aspiration)
	_pick_outfit(s.outfit)
	_sync_body()
	_sync_swatches()
	_refresh()


func randomize_sim_for(s: Sim) -> void:
	edit(s)
	randomize_sim()


func _swatch_style(c: Color, selected: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = c
	st.set_corner_radius_all(19)
	st.border_color = UiTheme.GREEN if selected else Color.WHITE
	st.set_border_width_all(4 if selected else 3)
	st.shadow_color = Color(0, 0, 0, 0.2)
	st.shadow_size = 2
	return st


func _on_swatch(part: String, c: Color) -> void:
	sim.set_part_color(part, c)
	_sync_swatches()


## Marks the swatch matching each part's current colour.
func _sync_swatches() -> void:
	var current := {"skin": sim.skin_color, "hair": sim.hair_color, "eyes": sim.eye_color, "shirt": sim.shirt_color, "pants": sim.pants_color}
	for part in _swatches:
		for pair in _swatches[part]:
			(pair[0] as Button).set_pressed_no_signal((pair[1] as Color).is_equal_approx(current[part]))


func _slider(parent: Control, label: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	return s


## A labelled row of toggle buttons where exactly one is pressed.
func _choice_row(parent: Control, label: String, options: Array, on_pick: Callable) -> Array[Button]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	row.add_child(l)
	var buttons: Array[Button] = []
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_stylebox_override("pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		b.add_theme_stylebox_override("hover_pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		b.pressed.connect(func():
			for k in buttons.size():
				buttons[k].set_pressed_no_signal(k == i)
			on_pick.call(i))
		row.add_child(b)
		buttons.append(b)
	return buttons


## Puts the body sliders and outfit buttons in line with the Sim being edited.
func _sync_body() -> void:
	_heavy_slider.set_value_no_signal(sim.body_heavy)
	_fit_slider.set_value_no_signal(sim.body_fit)
	for feature in _face_sliders:
		(_face_sliders[feature] as HSlider).set_value_no_signal(sim.face_features[feature])
	for k in 2:
		_sleeve_buttons[k].set_pressed_no_signal((k == 1) == sim.long_sleeves)
	var leg := 2 if sim.skirt else (1 if sim.shorts else 0)
	for k in 3:
		_leg_buttons[k].set_pressed_no_signal(k == leg)


## Shows and edits one outfit category; the swatches and cut apply to it.
func _pick_outfit(cat: String) -> void:
	sim.change_outfit(cat)
	for k in _outfit_buttons:
		(_outfit_buttons[k] as Button).button_pressed = k == cat
	_sync_swatches()
	_sync_body()


func _pick_age(stage: String) -> void:
	sim.age_days = 0
	sim.set_age(stage)
	for k in _age_buttons:
		(_age_buttons[k] as Button).button_pressed = k == stage


func _pick_hair(style: String) -> void:
	sim.set_hair_style(style)
	for k in _hair_buttons:
		(_hair_buttons[k] as Button).button_pressed = k == style


func _sync_walk() -> void:
	if _walk_pick != null:
		_walk_pick.select(Sim.WALK_STYLE_ORDER.find(sim.walk_style))


func _pick_aspiration(a: String) -> void:
	sim.aspiration = a
	_aspiration_pick.select(Aspirations.ORDER.find(a))
	_aspiration_pick.tooltip_text = Aspirations.INFO[a]["description"]


func _turn(amount: float) -> void:
	var tw := create_tween()
	tw.tween_property(sim, "rotation:y", sim.rotation.y + amount, 0.25).set_trans(Tween.TRANS_SINE)


func _on_trait_clicked(t: String) -> void:
	if _picked.has(t):
		_picked.erase(t)
	elif Traits.can_add(_picked, t):
		_picked.append(t)
	else:
		return
	sim.set_traits(_picked)
	_refresh()


## Clicking a filled slot removes that trait.
func _on_slot_clicked(t: String) -> void:
	if t != "":
		_on_trait_clicked(t)


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].trait_id = _picked[i] if i < _picked.size() else ""
		_slots[i].picked = i < _picked.size()
		_slots[i].tooltip_text = "Click to remove %s" % Traits.label(_picked[i]) if i < _picked.size() else "Empty trait slot"
		_slots[i].queue_redraw()
	for t in _choices:
		var h: TraitHex = _choices[t]
		h.picked = _picked.has(t)
		h.blocked = not h.picked and not Traits.can_add(_picked, t)
		h.queue_redraw()
	_done.disabled = sim.sim_name == "" or _picked.is_empty()
	_done.tooltip_text = "Give your Sim a name and at least one trait." if _done.disabled else "Done: move in!"
	_done.queue_redraw()


func randomize_sim() -> void:
	sim.sim_name = RANDOM_NAMES[_rng.randi() % RANDOM_NAMES.size()]
	_name_edit.text = sim.sim_name
	for part in PALETTES:
		var pal: Array = PALETTES[part]
		sim.set_part_color(part, pal[_rng.randi() % pal.size()])
	_picked.clear()
	var pool := Traits.ORDER.duplicate()
	while _picked.size() < Traits.MAX_TRAITS and not pool.is_empty():
		var t: String = pool.pop_at(_rng.randi() % pool.size())
		if Traits.can_add(_picked, t):
			_picked.append(t)
	sim.set_traits(_picked)
	_pick_aspiration(Aspirations.ORDER[_rng.randi() % Aspirations.ORDER.size()])
	_pick_hair(Sim.HAIR_STYLES[_rng.randi() % Sim.HAIR_STYLES.size()])
	sim.walk_style = Sim.WALK_STYLE_ORDER[_rng.randi() % Sim.WALK_STYLE_ORDER.size()]
	_sync_walk()
	sim.set_body(_rng.randf() * 0.7, _rng.randf() * 0.7)
	sim.set_outfit(_rng.randf() < 0.4, false)
	sim.set_legs(["trousers", "trousers", "shorts", "skirt"][_rng.randi() % 4])
	_sync_body()
	_sync_swatches()
	_refresh()


func _finish() -> void:
	if _done.disabled:
		return
	finished.emit()
	queue_free()


## A big inverted sphere and floor disc with a blue-to-green gradient, like a photo
## studio. Placed around `at`, far from the lot.
static func make_studio(at: Vector3) -> Node3D:
	var studio := Node3D.new()
	studio.name = "Studio"
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 left_color = vec3(0.16, 0.36, 0.78);
uniform vec3 right_color = vec3(0.12, 0.62, 0.5);
uniform vec3 glow_color = vec3(0.78, 0.92, 0.95);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - NODE_POSITION_WORLD; }
void fragment() {
	float t = clamp(world_pos.x / 16.0 + 0.5, 0.0, 1.0);
	vec3 col = mix(left_color, right_color, smoothstep(0.1, 0.9, t));
	float glow = exp(-pow(length(world_pos.xy - vec2(0.0, 1.2)) / 7.0, 2.0));
	ALBEDO = mix(col, glow_color, glow * 0.7);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 16.0
	sphere.height = 32.0
	dome.mesh = sphere
	dome.material_override = mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	studio.add_child(dome)
	# A floor that catches the Sim's shadow.
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(30, 30)
	var floor := MeshInstance3D.new()
	floor.layers = 8
	floor.mesh = floor_mesh
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.36, 0.55, 0.66)
	fm.roughness = 1.0
	floor.material_override = fm
	studio.add_child(floor)
	# Soft key light from the front so the face isn't in shadow.
	var key := OmniLight3D.new()
	key.position = Vector3(1.2, 2.4, 3.2)
	key.omni_range = 9.0
	key.light_energy = 0.9
	key.shadow_enabled = true
	key.light_cull_mask = 8
	key.light_color = Color(1.0, 0.97, 0.92)
	studio.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, 1.7, 2.0)
	fill.omni_range = 7.0
	fill.light_energy = 0.45
	fill.light_color = Color(0.84, 0.9, 1.0)
	fill.light_cull_mask = 8
	studio.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.5, 2.1, -1.5)
	rim.omni_range = 5.0
	rim.light_energy = 0.65
	rim.light_cull_mask = 8
	studio.add_child(rim)
	studio.position = at
	return studio
