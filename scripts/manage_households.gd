class_name ManageHouseholds
extends CanvasLayer
## Every household in the saved world: who's in it, where they live and their
## funds. Play any of them, start a new household alongside, or go back.

signal play(index: int)
signal new_household
signal back

## `summaries`: [{name, members, home, funds, last}] for each household.
func setup(summaries: Array) -> void:
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.12, 0.3, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := UiTheme.title(Label.new(), 24)
	t.text = "Manage Households"
	v.add_child(t)
	for i in summaries.size():
		var h: Dictionary = summaries[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.pill(Color.WHITE, UiTheme.GREEN if h.get("last", false) else UiTheme.PANEL_EDGE, 12))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var name := UiTheme.title(Label.new(), 17)
		name.text = h["name"] + ("  ·  last played" if h.get("last", false) else "")
		col.add_child(name)
		var info := Label.new()
		info.text = "%s\n%s  ·  %s" % [", ".join(PackedStringArray(h["members"])), h["home"], Hud.money(h["funds"])]
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		col.add_child(info)
		var play_btn := Button.new()
		play_btn.text = "Play"
		play_btn.focus_mode = Control.FOCUS_NONE
		play_btn.custom_minimum_size = Vector2(90, 40)
		play_btn.add_theme_stylebox_override("normal", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK))
		play_btn.add_theme_color_override("font_color", Color.WHITE)
		play_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		play_btn.pressed.connect(func(): play.emit(i))
		row.add_child(play_btn)
		v.add_child(card)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	var add := Button.new()
	add.text = "New Household"
	add.focus_mode = Control.FOCUS_NONE
	add.custom_minimum_size = Vector2(0, 40)
	add.pressed.connect(func(): new_household.emit())
	buttons.add_child(add)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.pressed.connect(func(): back.emit())
	buttons.add_child(back_btn)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) * 0.5
