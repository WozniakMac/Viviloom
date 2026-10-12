class_name Hud
extends CanvasLayer
## Live-mode HUD, laid out like a classic life-sim:
##   bottom-left   live portrait, vertical mood plate, moodlets, action queue, funds
##   bottom-centre pause / speed buttons and the clock
##   bottom-right  Needs / Skills / Simology panel opened from an icon tab bar
##   top-right     wall view and Live / Build buttons, notification cards below them

const NEED_LAYOUT: Array[String] = ["bladder", "fun", "hunger", "social", "energy", "hygiene"]
const NEED_COLORS := {
	"hunger": Color(0.95, 0.55, 0.2),
	"energy": Color(0.45, 0.45, 0.9),
	"bladder": Color(0.9, 0.78, 0.2),
	"hygiene": Color(0.25, 0.7, 0.9),
	"fun": Color(0.9, 0.4, 0.7),
	"social": Color(0.35, 0.75, 0.35),
}
signal menu_requested
## A household member's portrait was clicked.
signal sim_selected(sim: Sim)
signal phone_invite(townie: Sim)
signal phone_travel(destination: String)

const NOTICE_SECONDS := 7.0
const MAX_NOTICES := 4


## Need bar with a trend arrow: up while being refilled, down while dropping fast.
class NeedBar:
	extends Control
	var value := 100.0
	var trend := 0.0
	var base_decay := 5.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.84, 0.88, 0.94)
		bg.set_corner_radius_all(int(size.y / 2))
		draw_style_box(bg, r)
		if value <= 0.5:
			return
		var w := maxf(size.y, size.x * value / 100.0)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Hud.need_color(value)
		fill.set_corner_radius_all(int(size.y / 2))
		draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(w, size.y)))
		# Arrows: one to three, by how fast the need is moving.
		var n := 0
		var up := trend > 0.0
		if up:
			n = 1 if trend < 30.0 else (2 if trend < 120.0 else 3)
		elif -trend > base_decay * 1.15:
			n = 1 if -trend < base_decay * 2.0 else 2
		var h := size.y * 0.32
		for i in n:
			var cx := w - h * 1.6 - i * h * 1.7
			var cy := size.y * 0.5
			var pts := PackedVector2Array([Vector2(cx - h, cy + h * 0.6), Vector2(cx + h, cy + h * 0.6), Vector2(cx, cy - h * 0.8)]) if up \
				else PackedVector2Array([Vector2(cx - h, cy - h * 0.6), Vector2(cx + h, cy - h * 0.6), Vector2(cx, cy + h * 0.8)])
			draw_colored_polygon(pts, Color(1, 1, 1, 0.9))


## A queued action: a coloured circle with a progress ring. Hover shows an X;
## clicking cancels it.
class QueueIcon:
	extends Control
	signal clicked
	var action: Sim.SimAction
	var tint := Color.GRAY
	var initials := ""
	var _hover := false

	func _ready() -> void:
		mouse_entered.connect(func():
			_hover = true
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
			accept_event()

	func _get_tooltip(_at: Vector2) -> String:
		var t := action.label
		if action.autonomous:
			t += "  (their own idea)"
		return t + "\nClick to cancel"

	func _process(_d: float) -> void:
		if action.performing:
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		var col := tint if not action.autonomous else tint.lerp(Color(0.75, 0.78, 0.82), 0.55)
		draw_circle(c, r + 3.0, Color.WHITE)
		draw_circle(c, r, col)
		if action.performing:
			draw_arc(c, r + 1.0, -PI * 0.5, -PI * 0.5 + TAU * action.progress(), 32, UiTheme.GREEN, 4.0, true)
		var font := get_theme_default_font()
		var fs := int(r * 0.75)
		var ts := font.get_string_size(initials, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string_outline(font, c + Vector2(-ts.x * 0.5, fs * 0.35), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.35))
		draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.35), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if _hover:
			draw_circle(c, r, Color(0.8, 0.15, 0.1, 0.55))
			IconButton.draw_icon(self, "close", c, r * 0.6, Color.WHITE)


## Moodlet icon in its emotion's colour; the tooltip is built when shown so the
## time left stays current.
class MoodletIcon:
	extends Control
	var moodlet: Emotions.Moodlet

	func _get_tooltip(_at: Vector2) -> String:
		var m := moodlet
		var tip := "%s\n%s +%d" % [m.label, Emotions.label(m.emotion), m.weight]
		if m.description != "":
			tip += "\n" + m.description
		var left := Emotions.describe_time(m.remaining)
		if left != "":
			tip += "\n" + left
		return tip

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var st := StyleBoxFlat.new()
		st.bg_color = Emotions.color(moodlet.emotion)
		st.set_corner_radius_all(10)
		st.border_color = Color.WHITE
		st.set_border_width_all(3)
		st.shadow_color = Color(0, 0, 0, 0.25)
		st.shadow_size = 3
		draw_style_box(st, r)
		var font := get_theme_default_font()
		var txt := Hud.initials(moodlet.label)
		var fs := 15
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at := size * 0.5 + Vector2(-ts.x * 0.5, fs * 0.3)
		draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.3))
		draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		# Weight pips along the bottom.
		for i in mini(moodlet.weight, 4):
			draw_circle(Vector2(size.x * 0.5 + (i - (mini(moodlet.weight, 4) - 1) * 0.5) * 7.0, size.y - 9.0), 2.3, Color.WHITE)


## Friendship (green right / red left of centre) or romance (pink) bar.
class RelBar:
	extends Control
	var value := 0.0
	var centred := true

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.84, 0.88, 0.94)
		bg.set_corner_radius_all(int(size.y / 2))
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		if centred:
			var mid := size.x * 0.5
			var w := mid * absf(value) / 100.0
			var col := UiTheme.GREEN if value >= 0.0 else UiTheme.RED
			var x := mid if value >= 0.0 else mid - w
			draw_rect(Rect2(x, 1, w, size.y - 2), col)
			draw_line(Vector2(mid, 0), Vector2(mid, size.y), Color(1, 1, 1, 0.9), 2.0)
		else:
			draw_rect(Rect2(0, 1, size.x * value / 100.0, size.y - 2), Color(0.96, 0.45, 0.7))


## A thought bubble with one of the Sim's wants.
class WantBubble:
	extends Control
	var want: Array

	func _get_tooltip(_at: Vector2) -> String:
		return "%sWants to: %s\nDo it for +%d satisfaction." % ["", want[1], Aspirations.WANT_POINTS]

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var r := size.x * 0.42
		draw_circle(c + Vector2(0, 2), r, Color(0.05, 0.12, 0.3, 0.18))
		draw_circle(c, r, Color.WHITE)
		draw_arc(c, r, 0, TAU, 32, UiTheme.PANEL_EDGE, 1.5, true)
		# Little trailing bubbles, like a thought.
		draw_circle(Vector2(size.x * 0.32, size.y * 0.9), 4.0, Color.WHITE)
		draw_circle(Vector2(size.x * 0.22, size.y * 0.99), 2.5, Color.WHITE)
		var font := get_theme_default_font()
		# A one-word summary ("Paint", "Chat"...), shrunk to fit the bubble.
		var txt: String = (want[0] as String).capitalize()
		var fs := 14
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		while ts.x > r * 1.75 and fs > 8:
			fs -= 1
			ts = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.ACCENT)


## A household member: a circle in their shirt colour with their initial.
class MemberIcon:
	extends Control
	signal clicked
	var member: Sim
	var active := false

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
			accept_event()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r + 2.0, UiTheme.GREEN if active else Color.WHITE)
		draw_circle(c, r, member.shirt_color)
		draw_circle(c + Vector2(0, -r * 0.15), r * 0.45, member.skin_color)
		var font := get_theme_default_font()
		var t := member.sim_name.substr(0, 1)
		draw_string(font, c + Vector2(-5, r * 0.25), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, member.hair_color.darkened(0.3))
		if member.away:
			draw_circle(c, r, Color(0.2, 0.25, 0.35, 0.55))


var sim: Sim
var _household: Array = []
var pie_menu: PieMenu
var bubbles: Bubbles
var build: BuildMode

var _root: Control
var _live_ui: Array[Control] = []
var _clock_label: Label
var _date_label: Label
var _speed_buttons: Array[IconButton] = []
var _queue_box: HBoxContainer
var _portrait_rect: SimPortrait
var _mood_plate: Panel
var _mood_style: StyleBoxFlat
var _mood_label: Label
var _name_label: Label
var _funds_label: Label
var _moodlet_box: HFlowContainer
var _need_bars := {}
var _tabs: Array[IconButton] = []
var _pages: Array[Control] = []
var _info_panel: PanelContainer
var _info_title: Label
var _skills_box: VBoxContainer
var _skill_rows := {}
var _traits_box: VBoxContainer
var _rel_box: VBoxContainer
var _career_box: VBoxContainer
var _aspiration_box: VBoxContainer
var _wants_box: HBoxContainer
var aspirations: AspirationTracker
var _household_box: HBoxContainer
var _phone_panel: PanelContainer
var _phone_list: VBoxContainer
var _visitors: Visitors
var _destinations := {}
var _asp_refresh := 0.0
var work: Work
var _away_label: Label
var _rel_refresh := 0.0
var _lot: Lot
var _autonomy_button: Button
var _walls_button: IconButton
var _live_button: IconButton
var _build_button: IconButton
var _notices: VBoxContainer
var _hint: Label
var _hint_time := 25.0


func _ready() -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_top_right()
	_build_time_controls()
	_build_info_panel()
	_build_sim_cluster()

	_hint = Label.new()
	_hint.text = "Click the ground to walk, objects to interact.   WASD / Q E / Z X: camera   F3: build   V: walls"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.25, 0.8))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-400, 14)
	_hint.size = Vector2(800, 24)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)
	_live_ui.append(_hint)

	bubbles = Bubbles.new()
	bubbles.name = "Bubbles"
	_root.add_child(bubbles)
	_root.move_child(bubbles, 0)

	pie_menu = PieMenu.new()
	pie_menu.name = "PieMenu"
	_root.add_child(pie_menu)


# --- top right: modes, walls, notifications -------------------------------------

func _build_top_right() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.position = Vector2(-16, 14)
	bar.add_theme_constant_override("separation", 6)
	_root.add_child(bar)
	_walls_button = IconButton.make("walls", 44, "Walls (V)")
	bar.add_child(_walls_button)
	_live_button = IconButton.make("live", 52, "Live mode (F1)")
	_live_button.toggle_mode = true
	bar.add_child(_live_button)
	_build_button = IconButton.make("build", 52, "Build / buy mode (F3)")
	_build_button.toggle_mode = true
	bar.add_child(_build_button)
	var menu := IconButton.make("menu", 44, "Menu: save, load, quit (Esc)")
	menu.pressed.connect(func(): menu_requested.emit())
	bar.add_child(menu)

	_notices = VBoxContainer.new()
	_notices.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notices.position = Vector2(-16 - 330, 80)
	_notices.custom_minimum_size = Vector2(330, 0)
	_notices.add_theme_constant_override("separation", 8)
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_notices)


## A notification card in the top-right corner that fades out after a while.
func show_notice(text: String, title := "") -> void:
	Sfx.play("notice", -8.0)
	if title == "":
		title = sim.sim_name if sim != null else "Notice"
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(10, 10))
	card.custom_minimum_size = Vector2(330, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.title(Label.new(), 15)
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := IconButton.make("close", 22, "Dismiss")
	x.pressed.connect(card.queue_free)
	head.add_child(x)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	v.add_child(body)
	_notices.add_child(card)
	_notices.move_child(card, 0)
	while _notices.get_child_count() > MAX_NOTICES:
		var last := _notices.get_child(_notices.get_child_count() - 1)
		_notices.remove_child(last)
		last.queue_free()
	var tw := card.create_tween()
	tw.tween_interval(NOTICE_SECONDS)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(card.queue_free)


func set_build(b: BuildMode, lot: Lot) -> void:
	build = b
	_live_button.pressed.connect(build.exit)
	_build_button.pressed.connect(build.enter)
	_walls_button.pressed.connect(func():
		lot.wall_view = ((lot.wall_view + 1) % 3) as Lot.WallView
		refresh_walls_button(lot))
	build.funds_changed.connect(func(f: int): _funds_label.text = Hud.money(f))
	build.notice.connect(show_notice.bind("Build"))
	_funds_label.text = Hud.money(build.funds)
	refresh_walls_button(lot)


func refresh_walls_button(lot: Lot) -> void:
	_walls_button.tooltip_text = ["Walls up", "Walls cutaway", "Walls down"][lot.wall_view] + "  (V to change)"


# --- bottom centre: time ----------------------------------------------------------

func _build_time_controls() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(-110, -96)
	box.custom_minimum_size = Vector2(220, 0)
	box.add_theme_constant_override("separation", 4)
	_root.add_child(box)
	_live_ui.append(box)

	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiTheme.panel_style(26, 6))
	box.add_child(pill)
	var speeds := HBoxContainer.new()
	speeds.alignment = BoxContainer.ALIGNMENT_CENTER
	speeds.add_theme_constant_override("separation", 6)
	pill.add_child(speeds)
	var ids := ["pause", "play", "fast", "ultra"]
	var tips := ["Pause (P or 0)", "Normal speed (1)", "Fast (2)", "Ultra speed (3)"]
	for i in ids.size():
		var b := IconButton.make(ids[i], 40, tips[i])
		b.toggle_mode = true
		b.pressed.connect(Clock.set_speed.bind(i))
		speeds.add_child(b)
		_speed_buttons.append(b)
	Clock.speed_changed.connect(_on_speed_changed)
	_on_speed_changed(Clock.speed)

	var clock := PanelContainer.new()
	clock.add_theme_stylebox_override("panel", UiTheme.panel_style(14, 4))
	box.add_child(clock)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	clock.add_child(row)
	_clock_label = UiTheme.title(Label.new(), 17)
	row.add_child(_clock_label)
	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 13)
	_date_label.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	row.add_child(_date_label)


func _on_speed_changed(speed: int) -> void:
	for i in _speed_buttons.size():
		_speed_buttons[i].button_pressed = i == speed
		_speed_buttons[i].queue_redraw()


# --- bottom right: needs / skills / simology -----------------------------------------

func _build_info_panel() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.position = Vector2(-16, -16)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	_live_ui.append(col)

	_info_panel = PanelContainer.new()
	_info_panel.custom_minimum_size = Vector2(380, 0)
	col.add_child(_info_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_info_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_info_title = UiTheme.title(Label.new(), 18)
	_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_info_title)
	_autonomy_button = Button.new()
	_autonomy_button.toggle_mode = true
	_autonomy_button.button_pressed = true
	_autonomy_button.focus_mode = Control.FOCUS_NONE
	_autonomy_button.add_theme_font_size_override("font_size", 13)
	_autonomy_button.tooltip_text = "Let the Sim look after themselves when idle"
	_autonomy_button.add_theme_stylebox_override("pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
	_autonomy_button.add_theme_stylebox_override("hover_pressed", UiTheme.pill(UiTheme.GREEN.lightened(0.1), UiTheme.GREEN_DARK))
	_autonomy_button.toggled.connect(_on_autonomy_toggled)
	head.add_child(_autonomy_button)
	_on_autonomy_toggled(true)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	_pages.append(grid)
	for n in NEED_LAYOUT:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = Needs.LABELS[n]
		label.add_theme_font_size_override("font_size", 14)
		cell.add_child(label)
		var bar := NeedBar.new()
		bar.custom_minimum_size = Vector2(165, 18)
		bar.base_decay = Needs.DECAY_PER_HOUR[n]
		cell.add_child(bar)
		grid.add_child(cell)
		_need_bars[n] = bar

	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 8)
	v.add_child(_skills_box)
	_pages.append(_skills_box)
	_traits_box = VBoxContainer.new()
	_traits_box.add_theme_constant_override("separation", 10)
	v.add_child(_traits_box)
	_pages.append(_traits_box)
	_rel_box = VBoxContainer.new()
	_rel_box.add_theme_constant_override("separation", 10)
	v.add_child(_rel_box)
	_pages.append(_rel_box)
	_career_box = VBoxContainer.new()
	_career_box.add_theme_constant_override("separation", 10)
	v.add_child(_career_box)
	_pages.append(_career_box)
	_aspiration_box = VBoxContainer.new()
	_aspiration_box.add_theme_constant_override("separation", 8)
	v.add_child(_aspiration_box)
	_pages.append(_aspiration_box)

	var tabs_pill := PanelContainer.new()
	tabs_pill.add_theme_stylebox_override("panel", UiTheme.panel_style(26, 5))
	tabs_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(tabs_pill)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs_pill.add_child(tabs)
	var defs := [["aspiration", "Aspiration"], ["career", "Career"], ["skills", "Skills"], ["relationships", "Relationships"], ["simology", "Simology"], ["needs", "Needs"]]
	var page_of := {"needs": 0, "skills": 1, "simology": 2, "relationships": 3, "career": 4, "aspiration": 5}
	for d in defs:
		var b := IconButton.make(d[0], 42, d[1])
		b.toggle_mode = true
		b.pressed.connect(_on_tab.bind(page_of[d[0]]))
		tabs.add_child(b)
		_tabs.append(b)
	# _tabs is in visual order; map pages to buttons by icon.
	_show_page(0)


func _tab_for_page(index: int) -> IconButton:
	var id: String = ["needs", "skills", "simology", "relationships", "career", "aspiration"][index]
	for b in _tabs:
		if b.icon_id == id:
			return b
	return null


func _on_tab(index: int) -> void:
	# Clicking the open tab again folds the panel away.
	if _info_panel.visible and _pages[index].visible:
		_info_panel.visible = false
		for b in _tabs:
			b.button_pressed = false
			b.queue_redraw()
		return
	_show_page(index)


func _show_page(index: int) -> void:
	_info_panel.visible = true
	_info_title.text = ["Needs", "Skills", "Simology", "Relationships", "Career", "Aspiration"][index]
	if index == 5:
		_refresh_aspiration()
	if index == 4:
		_refresh_career()
	_autonomy_button.visible = index == 0
	for i in _pages.size():
		_pages[i].visible = i == index
	for b in _tabs:
		b.button_pressed = b == _tab_for_page(index)
		b.queue_redraw()


func _on_autonomy_toggled(on: bool) -> void:
	_autonomy_button.text = "Free Will: On" if on else "Free Will: Off"
	if sim != null:
		sim.autonomy_enabled = on


# --- bottom left: portrait, mood, moodlets, queue -----------------------------------

func _build_sim_cluster() -> void:
	var c := Control.new()
	c.name = "SimCluster"
	c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	c.position = Vector2(0, -262)
	c.size = Vector2(560, 262)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	_live_ui.append(c)

	# Wants float above the portrait; the queue sits to its right.
	_wants_box = HBoxContainer.new()
	_wants_box.position = Vector2(60, 6)
	_wants_box.add_theme_constant_override("separation", 6)
	c.add_child(_wants_box)

	_queue_box = HBoxContainer.new()
	_queue_box.position = Vector2(236, 62)
	_queue_box.add_theme_constant_override("separation", 4)
	_queue_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	c.add_child(_queue_box)

	# Vertical mood plate to the left of the portrait.
	_mood_plate = Panel.new()
	_mood_style = StyleBoxFlat.new()
	_mood_style.set_corner_radius_all(10)
	_mood_style.border_color = Color.WHITE
	_mood_style.set_border_width_all(2)
	_mood_plate.add_theme_stylebox_override("panel", _mood_style)
	_mood_plate.position = Vector2(14, 72)
	_mood_plate.size = Vector2(36, 166)
	_mood_plate.tooltip_text = "Mood: the strongest emotion from the moodlets."
	c.add_child(_mood_plate)
	_mood_label = Label.new()
	_mood_label.add_theme_font_size_override("font_size", 15)
	_mood_label.add_theme_color_override("font_color", Color.WHITE)
	_mood_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	_mood_label.add_theme_constant_override("outline_size", 3)
	_mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mood_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mood_label.size = Vector2(166, 36)
	_mood_label.pivot_offset = Vector2.ZERO
	_mood_label.rotation = -PI * 0.5
	_mood_label.position = Vector2(0, 166)
	_mood_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood_plate.add_child(_mood_label)

	# Live portrait of the active Sim, masked to a circle.
	_portrait_rect = SimPortrait.new()
	_portrait_rect.position = Vector2(56, 70)
	_portrait_rect.size = Vector2(170, 170)
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	c.add_child(_portrait_rect)
	_away_label = UiTheme.title(Label.new(), 16)
	_away_label.text = "At Work"
	_away_label.add_theme_color_override("font_color", Color.WHITE)
	_away_label.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.3, 0.9))
	_away_label.add_theme_constant_override("outline_size", 6)
	_away_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_away_label.position = Vector2(56, 142)
	_away_label.size = Vector2(170, 24)
	_away_label.visible = false
	c.add_child(_away_label)

	var name_pill := PanelContainer.new()
	name_pill.add_theme_stylebox_override("panel", UiTheme.pill(Color.WHITE, UiTheme.PANEL_EDGE, 12))
	name_pill.position = Vector2(76, 228)
	name_pill.custom_minimum_size = Vector2(130, 0)
	c.add_child(name_pill)
	_name_label = UiTheme.title(Label.new(), 14)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_pill.add_child(_name_label)

	_moodlet_box = HFlowContainer.new()
	_moodlet_box.position = Vector2(236, 128)
	_moodlet_box.size = Vector2(300, 100)
	_moodlet_box.add_theme_constant_override("h_separation", 4)
	_moodlet_box.add_theme_constant_override("v_separation", 4)
	_moodlet_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(_moodlet_box)

	var funds_pill := PanelContainer.new()
	funds_pill.add_theme_stylebox_override("panel", UiTheme.pill(Color.WHITE, UiTheme.PANEL_EDGE, 12))
	funds_pill.position = Vector2(236, 226)
	c.add_child(funds_pill)
	_funds_label = UiTheme.title(Label.new(), 15)
	_funds_label.add_theme_color_override("font_color", UiTheme.GREEN_DARK)
	_funds_label.tooltip_text = "Household funds"
	_funds_label.mouse_filter = Control.MOUSE_FILTER_PASS
	funds_pill.add_child(_funds_label)

	var phone := IconButton.make("phone", 38, "Phone: invite friends over or travel")
	phone.position = Vector2(14, 16)
	phone.pressed.connect(_toggle_phone)
	c.add_child(phone)
	_phone_panel = PanelContainer.new()
	_phone_panel.position = Vector2(14, -250)
	_phone_panel.custom_minimum_size = Vector2(300, 0)
	_phone_panel.visible = false
	c.add_child(_phone_panel)
	_phone_list = VBoxContainer.new()
	_phone_list.add_theme_constant_override("separation", 6)
	_phone_panel.add_child(_phone_list)

	_household_box = HBoxContainer.new()
	_household_box.position = Vector2(352, 218)
	_household_box.add_theme_constant_override("separation", 4)
	c.add_child(_household_box)


## Shows `s` in the portrait, queue, moodlets and panels (the active Sim).
func set_sim(s: Sim) -> void:
	if sim != null:
		sim.queue_changed.disconnect(_rebuild_queue)
		sim.emotions.changed.disconnect(_rebuild_moodlets)
		sim.panel_requested.disconnect(_on_panel_requested)
	sim = s
	sim.queue_changed.connect(_rebuild_queue)
	sim.emotions.changed.connect(_rebuild_moodlets)
	sim.panel_requested.connect(_on_panel_requested)
	_skill_rows.clear()
	for c in _skills_box.get_children():
		c.queue_free()
	_rebuild_queue()
	refresh_identity()
	_refresh_household()


## Notifications from any household member, active or not.
func watch_sim(s: Sim) -> void:
	s.action_failed.connect(func(t: String):
		if s == sim:
			show_notice(t, s.sim_name))
	s.announced.connect(func(t: String): show_notice(t, s.sim_name))


func _on_panel_requested(panel: String) -> void:
	if panel == "career":
		_show_page(4)


func set_phone(v: Visitors, destinations: Dictionary) -> void:
	_visitors = v
	_destinations = destinations


func _toggle_phone() -> void:
	_phone_panel.visible = not _phone_panel.visible
	if _phone_panel.visible:
		_fill_phone()


## The phone: invite a townie over, or travel to a community lot or home.
func _fill_phone() -> void:
	for ch in _phone_list.get_children():
		ch.queue_free()
	var t := UiTheme.title(Label.new(), 17)
	t.text = "Invite Over"
	_phone_list.add_child(t)
	if _visitors != null:
		for townie in _visitors.townies:
			var b := Button.new()
			var rel := sim.relationship_label(townie) if sim.relationships.has(townie) else "Haven't met"
			b.text = "%s  ·  %s  ·  %s" % [townie.sim_name, Ages.label(townie.age_stage), rel]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 13)
			b.disabled = not townie.away
			b.pressed.connect(func():
				_phone_panel.visible = false
				phone_invite.emit(townie))
			_phone_list.add_child(b)
	var t2 := UiTheme.title(Label.new(), 17)
	t2.text = "Travel"
	_phone_list.add_child(t2)
	var places := {"home": "Home"}
	for id in _destinations:
		places[id] = _destinations[id]["name"]
	for id in places:
		var b := Button.new()
		b.text = places[id]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func():
			_phone_panel.visible = false
			phone_travel.emit(id))
		_phone_list.add_child(b)
	# Grow upwards from the button.
	_phone_panel.reset_size()
	await get_tree().process_frame
	_phone_panel.position.y = 8 - _phone_panel.size.y


## Small portraits of the household; click one to control that Sim.
func set_household(members: Array) -> void:
	_household = members
	_refresh_household()


func _refresh_household() -> void:
	if _household_box == null:
		return
	for c in _household_box.get_children():
		c.queue_free()
	if _household.size() < 2:
		return
	for m in _household:
		var b := MemberIcon.new()
		b.member = m
		b.active = m == sim
		b.custom_minimum_size = Vector2(40, 40)
		b.tooltip_text = "%s%s" % [m.sim_name, "" if m == sim else "  (click to control)"]
		b.clicked.connect(func(): sim_selected.emit(m))
		_household_box.add_child(b)


## Name and traits, after they change in Create a Sim.
func refresh_identity() -> void:
	_name_label.text = sim.sim_name
	_rebuild_moodlets()
	_rebuild_traits()


func _rebuild_queue() -> void:
	for c in _queue_box.get_children():
		c.queue_free()
	for i in sim.queue.size():
		var a: Sim.SimAction = sim.queue[i]
		var icon := QueueIcon.new()
		icon.action = a
		icon.custom_minimum_size = Vector2(60, 60) if i == 0 else Vector2(44, 44)
		icon.size_flags_vertical = Control.SIZE_SHRINK_END
		icon.tint = _action_color(a)
		icon.initials = Hud.initials(a.label)
		icon.tooltip_text = a.label
		icon.clicked.connect(func(): sim.cancel(sim.queue.find(a)))
		_queue_box.add_child(icon)


func _action_color(a: Sim.SimAction) -> Color:
	if a.interaction == null:
		return Color(0.45, 0.6, 0.85)
	if a.interaction.skill != "":
		return Color(0.55, 0.42, 0.85)
	var best := ""
	var best_rate := 0.0
	for n in a.interaction.rates:
		if a.interaction.rates[n] > best_rate:
			best = n
			best_rate = a.interaction.rates[n]
	return NEED_COLORS.get(best, Color(0.45, 0.6, 0.85))


func _rebuild_moodlets() -> void:
	for c in _moodlet_box.get_children():
		c.queue_free()
	for m in sim.emotions.moodlets:
		var icon := MoodletIcon.new()
		icon.moodlet = m
		icon.custom_minimum_size = Vector2(46, 46)
		icon.tooltip_text = m.label
		_moodlet_box.add_child(icon)


func set_aspirations(t: AspirationTracker) -> void:
	if aspirations != null:
		aspirations.changed.disconnect(_rebuild_wants)
		aspirations.changed.disconnect(_refresh_aspiration)
	aspirations = t
	aspirations.changed.connect(_rebuild_wants)
	aspirations.changed.connect(_refresh_aspiration)
	_rebuild_wants()
	_refresh_aspiration()


func watch_aspirations(t: AspirationTracker) -> void:
	t.notice.connect(func(text: String, title: String): show_notice(text, title))


func _rebuild_wants() -> void:
	for c in _wants_box.get_children():
		c.queue_free()
	if aspirations == null:
		return
	for w in aspirations.wants:
		var b := WantBubble.new()
		b.want = w
		b.custom_minimum_size = Vector2(50, 56)
		b.tooltip_text = w[1]
		_wants_box.add_child(b)


## Aspiration tab: name, satisfaction, and milestones with their goals ticked off.
func _refresh_aspiration() -> void:
	if aspirations == null or not _pages[5].visible:
		return
	_asp_refresh = 1.0
	for c in _aspiration_box.get_children():
		c.queue_free()
	var a := sim.aspiration
	var info: Dictionary = Aspirations.INFO[a]
	var head := UiTheme.title(Label.new(), 17)
	head.text = info["label"]
	_aspiration_box.add_child(head)
	var sub := Label.new()
	sub.text = "%s · %s\nSatisfaction points: %d" % [info["category"], info["description"], aspirations.satisfaction]
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	_aspiration_box.add_child(sub)
	var store := Button.new()
	store.text = "Rewards Store"
	store.focus_mode = Control.FOCUS_NONE
	store.add_theme_stylebox_override("normal", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
	store.add_theme_color_override("font_color", Color.WHITE)
	store.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	store.pressed.connect(_open_store)
	_aspiration_box.add_child(store)
	var ms: Array = info["milestones"]
	for i in ms.size():
		var title := Label.new()
		var state := "Complete" if i < aspirations.milestone else ("Current" if i == aspirations.milestone else "Locked")
		title.text = "Milestone %d  ·  %s" % [i + 1, state]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", UiTheme.GREEN_DARK if i < aspirations.milestone else (UiTheme.TEXT if i == aspirations.milestone else UiTheme.TEXT_SOFT))
		_aspiration_box.add_child(title)
		if i != aspirations.milestone:
			continue
		for goal in ms[i]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var box := Panel.new()
			box.custom_minimum_size = Vector2(14, 14)
			box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var st := StyleBoxFlat.new()
			st.set_corner_radius_all(7)
			st.bg_color = UiTheme.GREEN if aspirations.goal_done(goal) else Color.WHITE
			st.border_color = UiTheme.GREEN_DARK if aspirations.goal_done(goal) else UiTheme.PANEL_EDGE
			st.set_border_width_all(2)
			box.add_theme_stylebox_override("panel", st)
			row.add_child(box)
			var gl := Label.new()
			gl.text = goal["text"]
			gl.add_theme_font_size_override("font_size", 13)
			row.add_child(gl)
			_aspiration_box.add_child(row)


## Spend satisfaction points on potions and perks.
func _open_store() -> void:
	for c in _aspiration_box.get_children():
		c.queue_free()
	var head := UiTheme.title(Label.new(), 17)
	head.text = "Rewards Store  ·  %d points" % aspirations.satisfaction
	_aspiration_box.add_child(head)
	for id in Rewards.ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var n := UiTheme.title(Label.new(), 14)
		n.text = Rewards.name_of(id)
		col.add_child(n)
		var d := Label.new()
		d.text = Rewards.INFO[id][2]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(250, 0)
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		col.add_child(d)
		var b := Button.new()
		b.text = "%d" % Rewards.price(id)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = aspirations.satisfaction < Rewards.price(id) or (Rewards.PERKS.has(id) and sim.perks.has(id))
		b.pressed.connect(func():
			show_notice(Rewards.buy(id, sim, aspirations), "Rewards Store")
			_open_store())
		row.add_child(b)
		_aspiration_box.add_child(row)
	var back := Button.new()
	back.text = "Back to Aspiration"
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_refresh_aspiration)
	_aspiration_box.add_child(back)
	_asp_refresh = 1e9


func set_work(w: Work) -> void:
	if work != null:
		work.changed.disconnect(_refresh_career)
	work = w
	work.changed.connect(_refresh_career)
	_refresh_career()


func watch_work(w: Work) -> void:
	w.notice.connect(func(text: String, title: String): show_notice(text, title))


## Career tab: the current job, or the list of careers to join.
func _refresh_career() -> void:
	if work == null:
		return
	for c in _career_box.get_children():
		c.queue_free()
	if not work.has_job():
		var intro := Label.new()
		intro.text = "%s doesn't have a job. Pick a career:" % sim.sim_name
		intro.add_theme_font_size_override("font_size", 14)
		intro.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		_career_box.add_child(intro)
		for c in Careers.ORDER:
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UiTheme.pill(Color.WHITE, UiTheme.PANEL_EDGE, 10))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			card.add_child(row)
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			var t := UiTheme.title(Label.new(), 15)
			t.text = Careers.label(c)
			col.add_child(t)
			var d := Label.new()
			d.text = "%s · §%d/h\n%s" % [Careers.title(c, 0), Careers.hourly(c, 0), Careers.schedule_text(c)]
			d.add_theme_font_size_override("font_size", 12)
			d.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
			col.add_child(d)
			card.tooltip_text = Careers.INFO[c]["description"]
			var join := Button.new()
			join.text = "Join"
			join.focus_mode = Control.FOCUS_NONE
			join.add_theme_stylebox_override("normal", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
			join.add_theme_color_override("font_color", Color.WHITE)
			join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			join.pressed.connect(work.join.bind(c))
			row.add_child(join)
			_career_box.add_child(card)
		return
	var c2 := work.career
	var head := UiTheme.title(Label.new(), 17)
	head.text = "%s  ·  Level %d" % [Careers.title(c2, work.level), work.level + 1]
	_career_box.add_child(head)
	var info := Label.new()
	var status: String = ["At home", "Heading to work", "At work"][work.state]
	info.text = "%s career · §%d/h\n%s\n%s" % [Careers.label(c2), Careers.hourly(c2, work.level), Careers.schedule_text(c2), status]
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	_career_box.add_child(info)
	var perf_label := Label.new()
	perf_label.text = "Performance"
	perf_label.add_theme_font_size_override("font_size", 13)
	_career_box.add_child(perf_label)
	var bar := NeedBar.new()
	bar.value = work.performance
	bar.custom_minimum_size = Vector2(340, 16)
	_career_box.add_child(bar)
	if work.level < Careers.max_level(c2):
		var skill: String = Careers.INFO[c2]["skill"]
		var next := Label.new()
		next.text = "Next: %s — needs full performance and %s %d (now %d). Good moods at the start of a shift help." % [Careers.title(c2, work.level + 1), Skills.label(skill), Careers.skill_for_promotion(work.level), sim.skills.level(skill)]
		next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next.custom_minimum_size = Vector2(340, 0)
		next.add_theme_font_size_override("font_size", 12)
		next.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		_career_box.add_child(next)
	var quit := Button.new()
	quit.text = "Quit Job"
	quit.focus_mode = Control.FOCUS_NONE
	quit.size_flags_horizontal = Control.SIZE_SHRINK_END
	quit.pressed.connect(work.quit)
	_career_box.add_child(quit)


## Lets the Relationships tab list everyone on the lot, not just Sims already met.
func set_others(lot: Lot) -> void:
	_lot = lot


func _refresh_relationships() -> void:
	for c in _rel_box.get_children():
		c.queue_free()
	var others: Array[Sim] = []
	for o in sim.relationships:
		if is_instance_valid(o):
			others.append(o)
	if _lot != null:
		for o in _lot.sims:
			if o != sim and not others.has(o):
				others.append(o)
	if others.is_empty():
		var none := Label.new()
		none.text = "%s hasn't met anyone yet. Click another Sim to socialize." % sim.sim_name
		none.add_theme_font_size_override("font_size", 14)
		none.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(350, 0)
		_rel_box.add_child(none)
		return
	for o in others:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var top := HBoxContainer.new()
		row.add_child(top)
		var name_label := UiTheme.title(Label.new(), 15)
		name_label.text = o.sim_name + ("" if o.visible else "  (away)")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		var kind := Label.new()
		kind.text = sim.relationship_label(o)
		kind.add_theme_font_size_override("font_size", 13)
		kind.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		top.add_child(kind)
		row.add_child(_rel_bar("Friendship", sim.friendship_with(o), true))
		if sim.romance_with(o) > 0.0:
			row.add_child(_rel_bar("Romance", sim.romance_with(o), false))
		_rel_box.add_child(row)


## A relationship bar: friendship runs -100..100 from the middle, romance 0..100.
func _rel_bar(label: String, value: float, centred: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(80, 0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	h.add_child(l)
	var bar := RelBar.new()
	bar.value = value
	bar.centred = centred
	bar.custom_minimum_size = Vector2(260, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.tooltip_text = "%s %d" % [label, int(value)]
	h.add_child(bar)
	return h


func _rebuild_traits() -> void:
	for c in _traits_box.get_children():
		c.queue_free()
	var age := UiTheme.title(Label.new(), 15)
	var stage: Dictionary = Ages.INFO[sim.age_stage]
	age.text = "%s  ·  day %d of %d" % [stage["label"], sim.age_days + 1, stage["days"]]
	if sim.pregnant_days >= 0:
		age.text += "  ·  expecting"
	_traits_box.add_child(age)
	var heading := Label.new()
	heading.text = "Traits"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	_traits_box.add_child(heading)
	for t in sim.traits:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var hex := TraitHex.new()
		hex.trait_id = t
		hex.picked = true
		hex.custom_minimum_size = Vector2(44, 44)
		hex.show_label = false
		row.add_child(hex)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var title := UiTheme.title(Label.new(), 15)
		title.text = Traits.label(t)
		col.add_child(title)
		var desc := Label.new()
		desc.text = Traits.description(t)
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(290, 0)
		col.add_child(desc)
		row.add_child(col)
		_traits_box.add_child(row)


func _refresh_skills() -> void:
	var known := sim.skills.known()
	if known.size() != _skill_rows.size() or _skills_box.get_child_count() == 0:
		for c in _skills_box.get_children():
			c.queue_free()
		_skill_rows.clear()
		if known.is_empty():
			var none := Label.new()
			none.text = "No skills yet. Cook, paint, study or play chess to start learning."
			none.add_theme_font_size_override("font_size", 14)
			none.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
			none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			none.custom_minimum_size = Vector2(350, 0)
			_skills_box.add_child(none)
		for sk in known:
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			var top := HBoxContainer.new()
			row.add_child(top)
			var name_label := Label.new()
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(name_label)
			var level_label := UiTheme.title(Label.new(), 14)
			top.add_child(level_label)
			# Ten segments, filled for each level reached.
			var segs := HBoxContainer.new()
			segs.add_theme_constant_override("separation", 3)
			row.add_child(segs)
			var cells: Array[Panel] = []
			for i in Skills.MAX_LEVEL:
				var p := Panel.new()
				p.custom_minimum_size = Vector2(32, 10)
				segs.add_child(p)
				cells.append(p)
			_skills_box.add_child(row)
			_skill_rows[sk] = [name_label, level_label, cells, row]
	for sk in _skill_rows:
		var lvl := sim.skills.level(sk)
		var parts: Array = _skill_rows[sk]
		(parts[0] as Label).text = Skills.label(sk)
		(parts[1] as Label).text = "Level %d" % lvl
		var prog := sim.skills.progress(sk)
		for i in Skills.MAX_LEVEL:
			var st := StyleBoxFlat.new()
			st.set_corner_radius_all(3)
			if i < lvl:
				st.bg_color = UiTheme.GREEN
			elif i == lvl:
				st.bg_color = Color(0.84, 0.88, 0.94).lerp(UiTheme.GREEN, prog * 0.6)
			else:
				st.bg_color = Color(0.84, 0.88, 0.94)
			(parts[2][i] as Panel).add_theme_stylebox_override("panel", st)
		(parts[3] as Control).tooltip_text = "%s: level %d of %d.\nLearns faster while %s." % [Skills.label(sk), lvl, Skills.MAX_LEVEL, Emotions.label(Skills.boosting_emotion(sk))]


# --- per frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock_label.text = Clock.time_string()
	_date_label.text = "%s · Day %d" % [Clock.weekday_name(), Clock.day()]
	if _hint_time > 0.0:
		_hint_time -= delta
		_hint.modulate.a = clampf(_hint_time / 3.0, 0.0, 1.0)
	var building := build != null and build.active
	for c in _live_ui:
		c.visible = not building and (c != _hint or _hint_time > 0.0)
	_live_button.button_pressed = not building
	_build_button.button_pressed = building
	_live_button.queue_redraw()
	_build_button.queue_redraw()
	if building and pie_menu.visible:
		pie_menu.close()
	if sim == null:
		return
	var emotion := sim.emotions.mood()
	var col := Emotions.color(emotion)
	_mood_label.text = sim.emotions.mood_label()
	_mood_style.bg_color = col
	_portrait_rect.ring_color = col.lerp(Color.WHITE, 0.25)
	_portrait_rect.sim = sim
	_away_label.visible = sim.away
	_portrait_rect.modulate = Color(0.75, 0.78, 0.85) if sim.away else Color.WHITE
	for n in NEED_LAYOUT:
		var bar: NeedBar = _need_bars[n]
		bar.value = sim.needs.get_value(n)
		bar.trend = sim.needs.trend.get(n, 0.0)
		bar.queue_redraw()
	_asp_refresh -= delta
	if _pages[5].visible and _asp_refresh <= 0.0:
		_asp_refresh = 1.0
		_refresh_aspiration()
	_rel_refresh -= delta
	if _pages[3].visible and _rel_refresh <= 0.0:
		_rel_refresh = 0.5
		_refresh_relationships()
	if _pages[1].visible:
		_refresh_skills()


static func initials(text: String) -> String:
	var out := ""
	for w in text.split(" ", false):
		if out.length() < 2 and w.length() > 0 and w[0] == w[0].to_upper():
			out += w.substr(0, 1)
	if out == "":
		out = text.substr(0, 2)
	return out


static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "§ " + ("-" if n < 0 else "") + s + out


## Need bar colour: green when full, yellow-green, orange, then red.
static func need_color(v: float) -> Color:
	if v >= 60.0:
		return Color(0.42, 0.78, 0.2).lerp(Color(0.6, 0.82, 0.22), (100.0 - v) / 40.0)
	if v >= 30.0:
		return Color(0.95, 0.75, 0.15).lerp(Color(0.6, 0.82, 0.22), (v - 30.0) / 30.0)
	return Color(0.88, 0.22, 0.15).lerp(Color(0.95, 0.6, 0.15), v / 30.0)
