class_name IconButton
extends Button
## A round button with a small vector icon drawn on top (no image assets needed).

var icon_id := ""
## Overrides the icon colour (otherwise dark blue, white while pressed).
var glyph_color: Variant = null


static func make(id: String, diameter := 40.0, tip := "") -> IconButton:
	var b := IconButton.new()
	b.icon_id = id
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(diameter, diameter)
	var r := int(diameter / 2.0)
	b.add_theme_stylebox_override("normal", UiTheme.pill(Color.WHITE, UiTheme.PANEL_EDGE, r))
	b.add_theme_stylebox_override("hover", UiTheme.pill(UiTheme.HOVER, UiTheme.ACCENT, r))
	b.add_theme_stylebox_override("pressed", UiTheme.pill(UiTheme.ACCENT, UiTheme.ACCENT, r))
	b.add_theme_stylebox_override("hover_pressed", UiTheme.pill(UiTheme.ACCENT.lightened(0.1), UiTheme.ACCENT, r))
	b.add_theme_stylebox_override("disabled", UiTheme.pill(Color(0.92, 0.93, 0.95), Color(0.85, 0.87, 0.9), r))
	return b


func _draw() -> void:
	var col: Color = glyph_color if glyph_color != null else (Color.WHITE if button_pressed else UiTheme.TEXT)
	if disabled:
		col = Color(0.7, 0.74, 0.8)
	draw_icon(self, icon_id, size * 0.5, minf(size.x, size.y) * 0.28, col)


## Draws icon `id` centred at `c` with half-size `s`.
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	match id:
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s), Vector2(s * 0.5, s * 2)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.2, -s), Vector2(s * 0.5, s * 2)), col)
		"play":
			_triangles(ci, c, s, 1, col)
		"fast":
			_triangles(ci, c, s, 2, col)
		"ultra":
			_triangles(ci, c, s, 3, col)
		"live":
			var top := c + Vector2(0, -s * 1.15)
			var bottom := c + Vector2(0, s * 1.15)
			var gem := col if col != UiTheme.TEXT else UiTheme.GREEN
			ci.draw_colored_polygon(PackedVector2Array([top, c + Vector2(s * 0.6, -s * 0.2), bottom, c + Vector2(-s * 0.6, -s * 0.2)]), gem)
			ci.draw_line(c + Vector2(-s * 0.6, -s * 0.2), c + Vector2(s * 0.6, -s * 0.2), Color(1, 1, 1, 0.6), 1.5)
		"build":
			# A house: roof and walls with a door.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.1), c + Vector2(0, -s), c + Vector2(s, -s * 0.1)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 1.1)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.3), Vector2(s * 0.4, s * 0.7)), Color(1, 1, 1, 0.85))
		"walls":
			# A wall cut down to half height: outline of the full wall, lower half solid.
			ci.draw_rect(Rect2(c - Vector2(s, s), Vector2(s * 2, s * 2)), col, false, 1.5)
			ci.draw_rect(Rect2(c + Vector2(-s, 0), Vector2(s * 2, s)), col)
			ci.draw_line(c + Vector2(-s, -s * 0.2), c + Vector2(s, -s * 0.2), col, 1.0)
		"needs":
			for i in 3:
				var w := s * (2.0 - i * 0.5)
				ci.draw_rect(Rect2(c + Vector2(-s, -s + i * s * 0.75), Vector2(w, s * 0.45)), col)
		"skills":
			for i in 3:
				var h := s * (0.8 + i * 0.6)
				ci.draw_rect(Rect2(c + Vector2(-s + i * s * 0.75, s - h), Vector2(s * 0.5, h)), col)
		"truck":
			# A moving truck: cargo box, cab and wheels.
			ci.draw_rect(Rect2(c + Vector2(-s * 1.1, -s * 0.7), Vector2(s * 1.3, s * 1.1)), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.3), c + Vector2(s * 0.8, -s * 0.3), c + Vector2(s * 1.1, s * 0.05), c + Vector2(s * 1.1, s * 0.4), c + Vector2(s * 0.3, s * 0.4)]), col)
			for x in [-0.7, 0.75]:
				ci.draw_circle(c + Vector2(s * x, s * 0.5), s * 0.24, col)
				ci.draw_circle(c + Vector2(s * x, s * 0.5), s * 0.1, Color.WHITE)
		"aspiration":
			# A five-pointed star.
			var pts := PackedVector2Array()
			for k in 10:
				var ang := -PI * 0.5 + k * PI / 5.0
				var rr := s * (1.1 if k % 2 == 0 else 0.45)
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
			ci.draw_colored_polygon(pts, col)
		"career":
			# A briefcase.
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.45), Vector2(s * 2, s * 1.4)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.85), Vector2(s * 0.8, s * 0.45)), col, false, 2.0)
			ci.draw_line(c + Vector2(-s, s * 0.1), c + Vector2(s, s * 0.1), Color(1, 1, 1, 0.8), 1.5)
		"relationships":
			for k in [[-0.45, UiTheme.PANEL_EDGE], [0.35, col]]:
				var off := Vector2(s * k[0], 0)
				var cc: Color = col if k[1] == col else col.lerp(Color.WHITE, 0.35)
				ci.draw_circle(c + off + Vector2(0, -s * 0.5), s * 0.36, cc)
				ci.draw_colored_polygon(PackedVector2Array([c + off + Vector2(-s * 0.6, s), c + off + Vector2(-s * 0.4, s * 0.05), c + off + Vector2(s * 0.4, s * 0.05), c + off + Vector2(s * 0.6, s)]), cc)
		"simology":
			ci.draw_circle(c + Vector2(0, -s * 0.5), s * 0.45, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.85, s), c + Vector2(-s * 0.55, s * 0.05), c + Vector2(s * 0.55, s * 0.05), c + Vector2(s * 0.85, s)]), col)
		"move":
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c, c + d * s, col, 2.0)
				var tip: Vector2 = c + d * s
				var side := Vector2(-d.y, d.x) * s * 0.3
				ci.draw_colored_polygon(PackedVector2Array([tip + d * s * 0.1, tip - d * s * 0.35 + side, tip - d * s * 0.35 - side]), col)
		"fence":
			for k in 4:
				var x := c.x - s * 0.75 + k * s * 0.5
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.16, c.y + s * 0.9), Vector2(x - s * 0.16, c.y - s * 0.5), Vector2(x, c.y - s * 0.85), Vector2(x + s * 0.16, c.y - s * 0.5), Vector2(x + s * 0.16, c.y + s * 0.9)]), col)
			for ry in [-0.2, 0.5]:
				ci.draw_rect(Rect2(Vector2(c.x - s, c.y + s * ry - s * 0.08), Vector2(s * 2, s * 0.16)), col)
		"wall":
			ci.draw_rect(Rect2(c - Vector2(s, s * 0.8), Vector2(s * 2, s * 1.6)), col)
			for row in 3:
				var y := c.y - s * 0.8 + (row + 1) * s * 0.53
				if row < 2:
					ci.draw_line(Vector2(c.x - s, y), Vector2(c.x + s, y), Color.WHITE, 1.2)
				var off := s * 0.5 if row % 2 == 0 else 0.0
				var x := c.x - s * 0.5 + off
				ci.draw_line(Vector2(x, y - s * 0.53), Vector2(x, y), Color.WHITE, 1.2)
		"door":
			ci.draw_rect(Rect2(c - Vector2(s * 0.65, s), Vector2(s * 1.3, s * 2)), col, false, 2.0)
			ci.draw_circle(c + Vector2(s * 0.35, 0), s * 0.12, col)
		"sell":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.5), Vector2(s * 1.4, s * 1.5)), col, false, 2.0)
			ci.draw_line(c + Vector2(-s, -s * 0.6), c + Vector2(s, -s * 0.6), col, 2.0)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.95), c + Vector2(s * 0.3, -s * 0.95), col, 2.0)
			for x in [-0.3, 0.0, 0.3]:
				ci.draw_line(c + Vector2(s * x, -s * 0.2), c + Vector2(s * x, s * 0.75), col, 1.5)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, 0), c + Vector2(-s * 0.2, s * 0.6), c + Vector2(s * 0.9, -s * 0.6)]), col, maxf(2.0, s * 0.3))
		"close":
			ci.draw_line(c + Vector2(-s, -s) * 0.7, c + Vector2(s, s) * 0.7, col, maxf(2.0, s * 0.25))
			ci.draw_line(c + Vector2(s, -s) * 0.7, c + Vector2(-s, s) * 0.7, col, maxf(2.0, s * 0.25))
		"dice":
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col, false, 2.0)
			for p in [Vector2(-0.4, -0.4), Vector2(0.4, 0.4), Vector2(0, 0), Vector2(0.4, -0.4), Vector2(-0.4, 0.4)]:
				ci.draw_circle(c + p * s, s * 0.13, col)
		"rotate_left", "rotate_right":
			var dir := -1.0 if id == "rotate_left" else 1.0
			ci.draw_arc(c, s * 0.8, PI * 1.1, PI * 1.9 + PI * 0.5, 16, col, 2.0)
			var end := c + Vector2(cos(PI * 0.4), sin(PI * 0.4)) * s * 0.8 if dir > 0.0 else c + Vector2(cos(PI * 1.1), sin(PI * 1.1)) * s * 0.8
			ci.draw_circle(end, s * 0.22, col)
		"add":
			ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, maxf(2.0, s * 0.3))
			ci.draw_line(c + Vector2(0, -s), c + Vector2(0, s), col, maxf(2.0, s * 0.3))
		"window":
			ci.draw_rect(Rect2(c - Vector2(s * 0.85, s), Vector2(s * 1.7, s * 2)), col, false, 2.0)
			ci.draw_line(c + Vector2(0, -s), c + Vector2(0, s), col, 2.0)
			ci.draw_line(c + Vector2(-s * 0.85, 0), c + Vector2(s * 0.85, 0), col, 2.0)
		"paint":
			# A paint roller.
			ci.draw_rect(Rect2(c + Vector2(-s, -s), Vector2(s * 1.6, s * 0.6)), col)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.6, -s * 0.7), c + Vector2(s * 0.95, -s * 0.7), c + Vector2(s * 0.95, -s * 0.1), c + Vector2(-s * 0.2, -s * 0.1), c + Vector2(-s * 0.2, s * 0.3)]), col, 2.0)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.32, s * 0.3), Vector2(s * 0.24, s * 0.75)), col)
		"floor":
			for i in 3:
				for j in 3:
					if (i + j) % 2 == 0:
						ci.draw_rect(Rect2(c + Vector2(-s + i * s * 0.67, -s + j * s * 0.67), Vector2(s * 0.62, s * 0.62)), col)
			ci.draw_rect(Rect2(c - Vector2(s, s), Vector2(s * 2, s * 2)), col, false, 1.5)
		"heart":
			ci.draw_circle(c + Vector2(-s * 0.45, -s * 0.25), s * 0.52, col)
			ci.draw_circle(c + Vector2(s * 0.45, -s * 0.25), s * 0.52, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.95, -s * 0.05), c + Vector2(s * 0.95, -s * 0.05), c + Vector2(0, s * 1.0)]), col)
		"smile":
			ci.draw_arc(c, s, 0, TAU, 24, col, 2.0, true)
			ci.draw_circle(c + Vector2(-s * 0.35, -s * 0.25), s * 0.13, col)
			ci.draw_circle(c + Vector2(s * 0.35, -s * 0.25), s * 0.13, col)
			ci.draw_arc(c + Vector2(0, s * 0.05), s * 0.5, 0.3, PI - 0.3, 12, col, 2.0, true)
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.55, s * 0.15), c + Vector2(-s * 0.05, s * 0.15), c + Vector2(-s * 0.25, s), c + Vector2(s * 0.55, -s * 0.2), c + Vector2(s * 0.05, -s * 0.2)]), col)
		"food":
			ci.draw_arc(c + Vector2(0, s * 0.1), s * 0.75, 0, PI, 16, col, 2.0, true)
			ci.draw_line(c + Vector2(-s, s * 0.1), c + Vector2(s, s * 0.1), col, 2.0)
			ci.draw_line(c + Vector2(-s * 0.3, -s), c + Vector2(-s * 0.3, -s * 0.2), col, 2.0)
			ci.draw_line(c + Vector2(s * 0.3, -s), c + Vector2(s * 0.3, -s * 0.2), col, 2.0)
		"zzz":
			var font := ThemeDB.fallback_font
			ci.draw_string(font, c + Vector2(-s * 0.9, s * 0.5), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 1.1), col)
			ci.draw_string(font, c + Vector2(-s * 0.2, s * 0.1), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 1.5), col)
		"drop":
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.6, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(-s * 0.55, s * 0.1), c + Vector2(s * 0.55, s * 0.1)]), col)
		"soap":
			ci.draw_circle(c + Vector2(-s * 0.35, s * 0.25), s * 0.5, col)
			ci.draw_arc(c + Vector2(s * 0.45, -s * 0.35), s * 0.42, 0, TAU, 16, col, 2.0, true)
			ci.draw_arc(c + Vector2(s * 0.5, s * 0.55), s * 0.25, 0, TAU, 12, col, 1.5, true)
		"phone":
			ci.draw_rect(Rect2(c - Vector2(s * 0.55, s), Vector2(s * 1.1, s * 2)), col)
			ci.draw_rect(Rect2(c - Vector2(s * 0.4, s * 0.75), Vector2(s * 0.8, s * 1.35)), Color.WHITE)
			ci.draw_circle(c + Vector2(0, s * 0.8), s * 0.12, Color.WHITE)
		"pool":
			ci.draw_rect(Rect2(c - Vector2(s, s * 0.7), Vector2(s * 2, s * 1.4)), col, false, 2.0)
			for k in 2:
				var y := c.y - s * 0.15 + k * s * 0.45
				var pts := PackedVector2Array()
				for i in 9:
					pts.append(Vector2(c.x - s * 0.8 + i * s * 0.2, y + sin(i * 1.6) * s * 0.12))
				ci.draw_polyline(pts, col, 1.8, true)
		"level_up", "level_down":
			var dirn := -1.0 if id == "level_up" else 1.0
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.8 * dirn), c + Vector2(-s * 0.8, -s * 0.2 * dirn), c + Vector2(s * 0.8, -s * 0.2 * dirn)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.8, (-s * 0.7 if dirn > 0 else s * 0.5)), Vector2(s * 1.6, s * 0.22)), col)
		"bulb":
			ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.62, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.28, s * 0.4), Vector2(s * 0.56, s * 0.45)), col)
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.7
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.85 + Vector2(0, -s * 0.2), c + Vector2(cos(a), sin(a)) * s * 1.15 + Vector2(0, -s * 0.2), col, 1.5)
		"target":
			ci.draw_arc(c, s, 0, TAU, 24, col, 2.0, true)
			ci.draw_arc(c, s * 0.55, 0, TAU, 20, col, 2.0, true)
			ci.draw_circle(c, s * 0.18, col)
		"rain":
			ci.draw_circle(c + Vector2(-s * 0.35, -s * 0.25), s * 0.42, col)
			ci.draw_circle(c + Vector2(s * 0.25, -s * 0.35), s * 0.5, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.75, -s * 0.3), Vector2(s * 1.4, s * 0.35)), col)
			for x in [-0.45, 0.0, 0.45]:
				ci.draw_line(c + Vector2(s * x, s * 0.3), c + Vector2(s * (x - 0.15), s * 0.85), col, 1.6)
		"spiral":
			var pts := PackedVector2Array()
			for i in 40:
				var a := i * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * s * (0.1 + i * 0.022))
			ci.draw_polyline(pts, col, 1.8, true)
		"steam":
			ci.draw_arc(c + Vector2(0, s * 0.25), s * 0.6, PI, TAU, 16, col, 2.0, true)
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.25), c + Vector2(s * 0.6, s * 0.25), col, 2.0)
			for x in [-0.4, 0.4]:
				ci.draw_line(c + Vector2(s * x, -s * 0.2), c + Vector2(s * (x * 1.4), -s * 0.9), col, 2.0)
		"blush":
			ci.draw_arc(c, s, 0, TAU, 24, col, 2.0, true)
			ci.draw_circle(c + Vector2(-s * 0.45, s * 0.15), s * 0.2, col)
			ci.draw_circle(c + Vector2(s * 0.45, s * 0.15), s * 0.2, col)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(-s * 0.1, -s * 0.3), col, 1.5)
			ci.draw_line(c + Vector2(s * 0.1, -s * 0.3), c + Vector2(s * 0.3, -s * 0.3), col, 1.5)
		"walk":
			ci.draw_circle(c + Vector2(s * 0.1, -s * 0.75), s * 0.22, col)
			ci.draw_line(c + Vector2(s * 0.05, -s * 0.5), c + Vector2(-s * 0.1, s * 0.15), col, 2.2)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.15), c + Vector2(-s * 0.45, s * 0.9), col, 2.2)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.15), c + Vector2(s * 0.35, s * 0.9), col, 2.2)
			ci.draw_line(c + Vector2(s * 0.0, -s * 0.3), c + Vector2(-s * 0.45, -s * 0.05), col, 2.0)
			ci.draw_line(c + Vector2(s * 0.0, -s * 0.3), c + Vector2(s * 0.45, -s * 0.15), col, 2.0)
		"inventory":
			# A backpack.
			ci.draw_rect(Rect2(c + Vector2(-s * 0.75, -s * 0.5), Vector2(s * 1.5, s * 1.5)), col)
			ci.draw_arc(c + Vector2(0, -s * 0.5), s * 0.45, PI, TAU, 12, col, 2.0, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.15), Vector2(s * 0.9, s * 0.5)), Color(1, 1, 1, 0.75), false, 1.5)
		"menu":
			for x in [-0.6, 0.0, 0.6]:
				ci.draw_circle(c + Vector2(x * s, 0), s * 0.2, col)
		_:
			pass


static func _triangles(ci: CanvasItem, c: Vector2, s: float, n: int, col: Color) -> void:
	var w := s * 1.1
	var total := w * n * 0.75 + w * 0.25
	var x0 := c.x - total * 0.5
	for i in n:
		var x := x0 + i * w * 0.75
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, c.y - s * 0.85), Vector2(x + w, c.y), Vector2(x, c.y + s * 0.85)]), col)
