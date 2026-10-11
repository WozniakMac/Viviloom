class_name Neighbourhood
extends CanvasLayer
## The world map shown after Create a Sim: a drawn neighbourhood with a river, roads
## and trees. Homes that are for sale are outlined in green; hovering one shows its
## card, clicking selects it, and the moving truck buys it and moves the Sim in.

signal chosen(lot_id: String, price: int)

## id -> name, layout, price, beds, baths, description, map polygon centre.
const LOTS := {
	"cottage": {"name": "Maple Cottage", "price": 14800, "beds": 1, "baths": 1, "size": "24 × 20",
		"description": "A furnished starter home with a little bit of everything, easel included.", "at": Vector2(0.62, 0.62), "house": true},
	"studio": {"name": "Willow Studio", "price": 8600, "beds": 1, "baths": 1, "size": "24 × 20",
		"description": "A compact furnished home. Cheaper, cosier, fewer hobbies.", "at": Vector2(0.4, 0.42), "house": true},
	"empty": {"name": "Riverside Plot", "price": 2000, "beds": 0, "baths": 0, "size": "24 × 20",
		"description": "An empty lot by the water. Build your own dream home.", "at": Vector2(0.78, 0.3), "house": false},
}
## Homes that are already lived in (white outlines, not for sale).
const TAKEN := [Vector2(0.2, 0.7), Vector2(0.3, 0.2), Vector2(0.55, 0.18), Vector2(0.85, 0.75), Vector2(0.12, 0.38)]


class MapView:
	extends Control
	var owner_map: Neighbourhood
	var hovered := ""
	var selected := ""
	var funds := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func lot_rect(at: Vector2) -> PackedVector2Array:
		# Lots are drawn as diamonds, like a map seen at an angle.
		var c := at * size
		var w := size.x * 0.075
		var h := size.y * 0.075
		return PackedVector2Array([c + Vector2(0, -h), c + Vector2(w, 0), c + Vector2(0, h), c + Vector2(-w, 0)])

	func _lot_at(p: Vector2) -> String:
		for id in Neighbourhood.LOTS:
			if Geometry2D.is_point_in_polygon(p, lot_rect(Neighbourhood.LOTS[id]["at"])):
				return id
		return ""

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			var h := _lot_at((e as InputEventMouseMotion).position)
			if h != hovered:
				hovered = h
				owner_map.show_card(h if h != "" else selected)
				queue_redraw()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var h := _lot_at((e as InputEventMouseButton).position)
			if h != "":
				selected = h
				owner_map.select(h)
				queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.47, 0.7, 0.34))
		# Gentle lighter meadows.
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 14:
			draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(60, 160), Color(0.55, 0.78, 0.4, 0.35))
		# River.
		var river := PackedVector2Array()
		for i in 21:
			var t := i / 20.0
			river.append(Vector2(t * size.x, size.y * (0.52 + 0.12 * sin(t * 5.0)) - t * size.y * 0.15))
		draw_polyline(river, Color(0.32, 0.6, 0.78), 46.0, true)
		draw_polyline(river, Color(0.45, 0.72, 0.88), 30.0, true)
		# Roads.
		var road := Color(0.86, 0.84, 0.78)
		draw_line(Vector2(0, size.y * 0.86), Vector2(size.x, size.y * 0.8), road, 14.0, true)
		draw_line(Vector2(size.x * 0.48, 0), Vector2(size.x * 0.5, size.y), road, 12.0, true)
		draw_line(Vector2(size.x * 0.48, size.y * 0.3), Vector2(size.x, size.y * 0.22), road, 10.0, true)
		# Trees.
		for i in 70:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var near_lot := false
			for id in Neighbourhood.LOTS:
				near_lot = near_lot or p.distance_to(Neighbourhood.LOTS[id]["at"] * size) < size.x * 0.09
			for t in Neighbourhood.TAKEN:
				near_lot = near_lot or p.distance_to(t * size) < size.x * 0.08
			if near_lot:
				continue
			var r := rng.randf_range(9, 18)
			draw_circle(p + Vector2(3, 4), r, Color(0.1, 0.25, 0.1, 0.3))
			draw_circle(p, r, Color(0.2, 0.48, 0.2).lerp(Color(0.85, 0.55, 0.75), 0.25 if i % 9 == 0 else 0.0))
		for t in Neighbourhood.TAKEN:
			var poly := lot_rect(t)
			draw_colored_polygon(poly, Color(0.55, 0.75, 0.42))
			_house(t * size, Color(0.92, 0.9, 0.85), Color(0.45, 0.35, 0.35))
			var loop := poly.duplicate()
			loop.append(poly[0])
			draw_polyline(loop, Color(1, 1, 1, 0.85), 2.5, true)
		for id in Neighbourhood.LOTS:
			var info: Dictionary = Neighbourhood.LOTS[id]
			var poly := lot_rect(info["at"])
			draw_colored_polygon(poly, Color(0.6, 0.85, 0.45) if id != hovered else Color(0.7, 0.92, 0.55))
			if info["house"]:
				_house(info["at"] * size, Color(0.95, 0.93, 0.88) if id == "cottage" else Color(0.85, 0.9, 0.95), Color(0.35, 0.5, 0.6) if id == "cottage" else Color(0.6, 0.4, 0.3))
			var loop := poly.duplicate()
			loop.append(poly[0])
			var sel: bool = id == selected
			draw_polyline(loop, UiTheme.GREEN if not sel else Color.WHITE, 6.0 if sel else 3.5, true)
			# Price tag marker.
			var pin: Vector2 = info["at"] * size + Vector2(0, -size.y * 0.075 - 18)
			draw_circle(pin, 13, Color(0.98, 0.65, 0.15))
			draw_circle(pin, 13, Color.WHITE, false, 2.0)
			var font := get_theme_default_font()
			draw_string(font, pin + Vector2(-4, 5), "§", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	func _house(c: Vector2, wall: Color, roof: Color) -> void:
		var w := size.x * 0.035
		var h := size.y * 0.03
		draw_rect(Rect2(c + Vector2(-w, -h * 0.4), Vector2(w * 2, h * 1.2)), wall)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 1.15, -h * 0.4), c + Vector2(0, -h * 1.5), c + Vector2(w * 1.15, -h * 0.4)]), roof)
		draw_rect(Rect2(c + Vector2(-w * 0.2, h * 0.2), Vector2(w * 0.4, h * 0.6)), roof.darkened(0.2))


var _view: MapView
var _card: PanelContainer
var _card_title: Label
var _card_body: Label
var _truck: IconButton
var _funds := 0


func setup(funds: int) -> void:
	_funds = funds
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_view = MapView.new()
	_view.owner_map = self
	_view.funds = funds
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_view)

	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", UiTheme.panel_style(20, 10))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.position = Vector2(-190, 16)
	title.custom_minimum_size = Vector2(380, 0)
	root.add_child(title)
	var tv := VBoxContainer.new()
	title.add_child(tv)
	var t := UiTheme.title(Label.new(), 20)
	t.text = "Choose a Home"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t)
	var f := Label.new()
	f.text = "Household funds: %s" % Hud.money(funds)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_theme_font_size_override("font_size", 14)
	f.add_theme_color_override("font_color", UiTheme.GREEN_DARK)
	tv.add_child(f)

	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.position = Vector2(24, -24)
	_card.custom_minimum_size = Vector2(340, 0)
	_card.visible = false
	root.add_child(_card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	_card.add_child(cv)
	_card_title = UiTheme.title(Label.new(), 19)
	cv.add_child(_card_title)
	_card_body = Label.new()
	_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_body.custom_minimum_size = Vector2(316, 0)
	_card_body.add_theme_font_size_override("font_size", 14)
	_card_body.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	cv.add_child(_card_body)

	_truck = IconButton.make("truck", 76, "Pick a home first")
	_truck.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_truck.position = Vector2(-24 - 76, -24 - 76)
	_truck.disabled = true
	_truck.pressed.connect(_move_in)
	root.add_child(_truck)

	var hint := Label.new()
	hint.text = "Green outlines are for sale. Hover for details, click to choose, then press the moving truck."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.05, 0.8))
	hint.add_theme_constant_override("outline_size", 5)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-330, -40)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)


func show_card(id: String) -> void:
	_card.visible = id != ""
	if id == "":
		return
	var info: Dictionary = LOTS[id]
	_card_title.text = info["name"]
	var rooms := "Empty lot" if info["beds"] == 0 else "%d bed · %d bath" % [info["beds"], info["baths"]]
	_card_body.text = "%s  ·  %s\n%s\nPrice: %s%s" % [info["size"], rooms, info["description"], Hud.money(info["price"]),
		"" if info["price"] <= _funds else "  (not enough funds)"]


func select(id: String) -> void:
	show_card(id)
	var price: int = LOTS[id]["price"]
	_truck.disabled = price > _funds
	_truck.tooltip_text = "Move in to %s" % LOTS[id]["name"] if not _truck.disabled else "Not enough funds"
	_truck.queue_redraw()


func _move_in() -> void:
	if _view.selected == "" or _truck.disabled:
		return
	chosen.emit(_view.selected, LOTS[_view.selected]["price"])
	queue_free()


## Picks a lot directly (for scripted runs).
func choose(id: String) -> void:
	_view.selected = id
	select(id)
	_move_in()
