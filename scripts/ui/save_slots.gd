class_name SaveSlots
extends CanvasLayer
## Load Game: every save slot with who lives there, their funds and when it was
## saved, newest first; pick one to continue to its households.

signal picked(slot: String)
signal back


func setup() -> void:
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.12, 0.3, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := UiTheme.title(Label.new(), 24)
	t.text = "LOAD GAME"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for slot in SaveGame.slots():
		var world := SaveGame.read(slot)
		var s: Dictionary = Main._summary(Main._household_part(world), false)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.pill(Color.WHITE, UiTheme.GREEN if slot == SaveGame.current_slot() else UiTheme.PANEL_EDGE, 12))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var name := UiTheme.title(Label.new(), 17)
		name.text = slot
		col.add_child(name)
		var info := Label.new()
		info.text = "%s  ·  %s\nSaved %s" % [s["name"], Hud.money(s["funds"]), SaveGame.modified_text(slot)]
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		col.add_child(info)
		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.focus_mode = Control.FOCUS_NONE
		load_btn.custom_minimum_size = Vector2(90, 40)
		load_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		load_btn.add_theme_stylebox_override("normal", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		load_btn.add_theme_color_override("font_color", Color.WHITE)
		load_btn.pressed.connect(func(): picked.emit(slot))
		row.add_child(load_btn)
		list.add_child(card)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.pressed.connect(func(): back.emit())
	v.add_child(back_btn)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) * 0.5
