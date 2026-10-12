class_name BuildMode
extends Node
## Build/buy mode: place, move, rotate and sell furniture, draw walls, add doors.
## Time is paused while it is open. It has its own tool bar along the bottom.

signal funds_changed(funds: int)
signal notice(text: String)
signal entered
## An object was put down (main uses this to cut stairwells).
signal placed(f: Furniture)
## The roof style or colour was changed (applies to every storey).
signal roof_changed(style: int, color: int)
## The foundation was added (height) or removed (0).
signal foundation_changed(height: float)
## Lot traits were picked (applies to every storey).
signal lot_traits_changed(traits: Array)

enum Tool { MOVE, WALL, DOOR, DELETE, PLACE, WINDOW, PAINT, FLOOR, POOL, FENCE, ROOM, ROOF, TERRAIN }

var lot: Lot
var sim: Sim
## Everyone in the household; they all stop what they're doing in build mode.
var household: Array = []
var camera: Camera3D
var active := false
var tool := Tool.MOVE
var funds := 20000
## Build mode only works on the household's own lot.
var allowed := true

var _held: Furniture = null
var _held_is_new := false
var _held_from := Vector2i.ZERO
var _held_from_rot := 0
var _held_rot := 0
var _held_cell := Vector2i.ZERO
var _wall_start: Variant = null
var _wall_end := Vector2i.ZERO
var _speed_before := 1

var _footprint: MeshInstance3D
var _footprint_mat: StandardMaterial3D
var _wall_preview: MeshInstance3D
var _edge_marker: MeshInstance3D
var _ui: CanvasLayer
var _tool_buttons := {}
var _category_buttons := {}
var _tiles := {}
var _tiles_box: HBoxContainer
var _tiles_scroll: ScrollContainer
var _funds_label: Label
var _thumbs: Thumbnails
## Selected wall and floor finishes (Finishes indices).
var wall_style := 1
var floor_style := 0
var _swatch_box: HFlowContainer
var _swatch_row: HBoxContainer
var _floor_start: Variant = null
var _floor_end := Vector2i.ZERO


## Overlays live under this node, which rises to the level being built on.
var _overlays: Node3D


func _ready() -> void:
	_overlays = Node3D.new()
	add_child(_overlays)
	_footprint = _overlay_box(Color(0.3, 0.9, 0.4, 0.45))
	_footprint_mat = _footprint.material_override
	_wall_preview = _overlay_box(Color(0.4, 0.7, 1.0, 0.55))
	_edge_marker = _overlay_box(Color(1.0, 0.85, 0.3, 0.7))
	_build_ui()
	_set_visible(false)


func enter() -> void:
	if active:
		return
	if not allowed:
		notice.emit("You can only build on your own lot.")
		return
	active = true
	_speed_before = maxi(Clock.speed, 1)
	Clock.set_speed(0)
	for m in household:
		m.clear_queue()
	set_tool(Tool.MOVE)
	_set_visible(true)
	entered.emit()


func exit() -> void:
	if not active:
		return
	_cancel_held()
	_wall_start = null
	active = false
	_set_visible(false)
	Clock.set_speed(_speed_before)


func set_tool(t: Tool) -> void:
	if t != Tool.PLACE:
		_cancel_held()
	_wall_start = null
	tool = t
	for k in _tool_buttons:
		(_tool_buttons[k] as Button).button_pressed = (k == t)
		(_tool_buttons[k] as Button).queue_redraw()
	_floor_start = null
	_show_swatches()
	_refresh_overlays(null)


## Starts placing a new object of `kind` from the catalogue.
func start_place(kind: String) -> void:
	if kind == "stairs" and lot.level > 0:
		notice.emit("Stairs go on the ground floor and lead up to the next one.")
		return
	set_tool(Tool.PLACE)
	var price: int = Catalog.INFO[kind][1]
	if price > funds:
		notice.emit("Not enough Simoleons for the %s." % Catalog.INFO[kind][0])
		return
	var f := Catalog.create(kind)
	lot.add_child(f)
	_pick_up(f, true)


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_refresh_overlays(_ground((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var p: Variant = _ground(mb.position)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(p, mb.position)
			elif (tool == Tool.WALL or tool == Tool.FENCE) and _wall_start != null:
				_finish_wall()
			elif tool == Tool.FLOOR and _floor_start != null:
				_finish_floor()
			elif tool == Tool.POOL and _floor_start != null:
				_finish_pool()
			elif tool == Tool.ROOM and _floor_start != null:
				_finish_room()
			elif tool == Tool.TERRAIN and _floor_start != null:
				_finish_terrain()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _held != null:
				_cancel_held()
			_wall_start = null
			_refresh_overlays(p)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_R, KEY_PERIOD:
				_rotate_held(1)
			KEY_COMMA:
				_rotate_held(-1)
			KEY_DELETE, KEY_BACKSPACE:
				if _held != null:
					_sell(_held)
			KEY_ESCAPE:
				_cancel_held()
				_wall_start = null
				_refresh_overlays(null)


func _on_press(p: Variant, screen_pos: Vector2) -> void:
	if p == null:
		return
	var pt: Vector3 = p
	match tool:
		Tool.MOVE, Tool.PLACE:
			if _held != null:
				_drop()
			elif tool == Tool.MOVE:
				var f := _furniture_under(screen_pos)
				if f != null:
					_pick_up(f, false)
		Tool.WALL, Tool.FENCE:
			_wall_start = _vertex(pt)
			_wall_end = _wall_start
		Tool.DOOR:
			var e := lot.edge_near(pt)
			if lot.fences.has(e):
				if not Lot.FENCE_STYLES[lot.fence_styles.get(e, 0)][3]:
					notice.emit("That fence style can't have a gate.")
				elif not lot.gates.has(e) and _spend(Catalog.GATE_PRICE):
					lot.add_gate(e)
			elif not lot.walls.has(e):
				notice.emit("Doors go on walls (or fences, as gates).")
			elif lot.doors.has(e):
				pass
			elif _spend(Catalog.DOOR_PRICE):
				lot.add_door(e)
		Tool.WINDOW:
			var e := lot.edge_near(pt)
			if not lot.walls.has(e):
				notice.emit("Windows go on walls.")
			elif lot.doors.has(e):
				notice.emit("That wall already has a door.")
			elif not lot.windows.has(e) and _spend(Finishes.WINDOW_PRICE):
				lot.add_window(e)
		Tool.PAINT:
			var e := lot.edge_near(pt)
			if lot.walls.has(e):
				# Shift paints every wall on the lot.
				var targets: Array = lot.walls.keys() if Input.is_key_pressed(KEY_SHIFT) else [e]
				var price: int = Finishes.WALLS[wall_style][3]
				for t in targets:
					if lot.wall_styles.get(t, 0) != wall_style:
						if not _spend(price):
							break
						lot.paint_wall(t, wall_style)
		Tool.FLOOR, Tool.POOL, Tool.ROOM, Tool.TERRAIN:
			_floor_start = lot.world_to_cell(pt)
			_floor_end = _floor_start
		Tool.DELETE:
			var f := _furniture_under(screen_pos)
			if f != null and f.kind == "pool":
				earn(POOL_TILE_PRICE * f.footprint.x * f.footprint.y)
				lot.remove_pool(f)
			elif f != null:
				lot.remove_furniture(f)
				_sell(f)
			else:
				var e := lot.edge_near(pt)
				if lot.walls.has(e):
					earn(Catalog.WALL_PRICE + (Catalog.DOOR_PRICE if lot.doors.has(e) else 0) + (Finishes.WINDOW_PRICE if lot.windows.has(e) else 0))
					lot.remove_wall(e)
				elif lot.fences.has(e):
					earn(Lot.FENCE_STYLES[lot.fence_styles.get(e, 0)][2] + (Catalog.GATE_PRICE if lot.gates.has(e) else 0))
					lot.remove_fence(e)
	_refresh_overlays(p)


func _finish_wall() -> void:
	var built := 0
	if tool == Tool.FENCE:
		for e in Lot.wall_run(_wall_start, _wall_end):
			if lot.fences.has(e) or lot.walls.has(e) or not lot.edge_in_bounds(e):
				continue
			var fprice: int = Lot.FENCE_STYLES[fence_style][2]
			if funds < fprice:
				notice.emit("Out of funds.")
				break
			if lot.add_fence(e, fence_style):
				_spend(fprice)
		_wall_start = null
		_wall_preview.visible = false
		return
	for e in Lot.wall_run(_wall_start, _wall_end):
		if lot.walls.has(e) or not lot.edge_in_bounds(e):
			continue
		if funds < Catalog.WALL_PRICE:
			notice.emit("Out of funds.")
			break
		if lot.add_wall(e):
			_spend(Catalog.WALL_PRICE)
			built += 1
	_wall_start = null
	_wall_preview.visible = false


func _floor_rect() -> Rect2i:
	var a: Vector2i = _floor_start
	var lo := Vector2i(mini(a.x, _floor_end.x), mini(a.y, _floor_end.y))
	var hi := Vector2i(maxi(a.x, _floor_end.x), maxi(a.y, _floor_end.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


const POOL_TILE_PRICE := 60


func _finish_pool() -> void:
	var r := _floor_rect()
	_floor_start = null
	_wall_preview.visible = false
	if r.size.x < 2 or r.size.y < 2:
		notice.emit("Pools need to be at least 2 by 2 tiles.")
		return
	var price := POOL_TILE_PRICE * r.size.x * r.size.y
	if price > funds:
		notice.emit("Not enough Simoleons for a pool that size.")
		return
	if lot.add_pool(r) == null:
		notice.emit("Pools need clear, open ground.")
		return
	_spend(price)
	Sfx.play("place")


## Terrain paint over the dragged rectangle (outdoor ground only shows it).
var terrain_style := 1
var fence_style := 0


func _finish_terrain() -> void:
	var r := _floor_rect()
	var price: int = Finishes.TERRAIN[terrain_style][3]
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var c := Vector2i(x, y)
			if not lot.in_bounds(c) or lot.terrain_tiles.get(c, 0) == terrain_style:
				continue
			if not _spend(price):
				break
			if terrain_style <= 0:
				lot.terrain_tiles.erase(c)
			else:
				lot.terrain_tiles[c] = terrain_style
	lot.paint_terrain(Vector2i(-1, -1), 0)
	_floor_start = null
	_wall_preview.visible = false


## Room tool: four walls around the dragged rectangle in one go.
func _finish_room() -> void:
	var r := _floor_rect()
	_floor_start = null
	_wall_preview.visible = false
	if r.size.x < 1 or r.size.y < 1:
		return
	var corners := [r.position, Vector2i(r.end.x, r.position.y), r.end, Vector2i(r.position.x, r.end.y)]
	for k in 4:
		for e in Lot.wall_run(corners[k], corners[(k + 1) % 4]):
			if lot.walls.has(e) or lot.fences.has(e) or not lot.edge_in_bounds(e):
				continue
			if funds < Catalog.WALL_PRICE:
				notice.emit("Out of funds.")
				return
			if lot.add_wall(e):
				_spend(Catalog.WALL_PRICE)


## Picks a roof style and colour for the whole house.
func set_roof(style: int, color: int) -> void:
	if style == lot.roof_style and color == lot.roof_color:
		return
	if not _spend(Lot.ROOF_PRICE):
		return
	roof_changed.emit(style, color)
	_show_swatches()


func _finish_floor() -> void:
	var r := _floor_rect()
	var price: int = Finishes.FLOORS[floor_style][3]
	var tiles: Array[Vector2i] = []
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var c := Vector2i(x, y)
			if lot.in_bounds(c) and lot.floor_tiles.get(c, -1) != floor_style:
				tiles.append(c)
	for c in tiles:
		if not _spend(price):
			break
		lot.floor_tiles[c] = floor_style
	lot.add_floor(Rect2i(), floor_style)
	_floor_start = null
	_wall_preview.visible = false


## While an object is held, its colour swatches appear above the catalogue.
func _show_object_swatches() -> void:
	if _swatch_row == null:
		return
	for c in _swatch_row.get_children():
		c.queue_free()
	_swatch_row.visible = _held != null and not _held.swatch_colors().is_empty()
	if not _swatch_row.visible:
		return
	var l := Label.new()
	l.text = "Colours:"
	l.add_theme_font_size_override("font_size", 13)
	_swatch_row.add_child(l)
	var cols := _held.swatch_colors()
	for i in cols.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.focus_mode = Control.FOCUS_NONE
		var st := StyleBoxFlat.new()
		st.bg_color = cols[i]
		st.set_corner_radius_all(15)
		st.border_color = UiTheme.GREEN if i == _held.variant else Color.WHITE
		st.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.pressed.connect(func():
			_held.set_variant(i)
			_show_object_swatches())
		_swatch_row.add_child(b)


func _pick_up(f: Furniture, is_new: bool) -> void:
	_held = f
	_held_is_new = is_new
	_held_from = f.cell
	_held_from_rot = f.rot_steps
	_held_rot = f.rot_steps
	if not is_new:
		lot.remove_furniture(f)
	f.set_ghost(true)
	_show_object_swatches()


func _drop() -> void:
	if not _can_drop():
		notice.emit("That doesn't fit there.")
		return
	if _held_is_new and not _held.get_meta("free", false) and not _spend(_held.price):
		return
	if _held.has_meta("free"):
		_held.remove_meta("free")
	lot.place_furniture(_held, _held_cell, _held_rot)
	Sfx.play("place")
	_held.set_ghost(false)
	placed.emit(_held)
	_held = null
	if tool == Tool.PLACE:
		set_tool(Tool.MOVE)
	_show_object_swatches()


func _cancel_held() -> void:
	if _held == null:
		return
	if _held_is_new:
		_held.queue_free()
	else:
		lot.place_furniture(_held, _held_from, _held_from_rot)
		_held.set_ghost(false)
	_held = null
	_footprint.visible = false
	_show_object_swatches()


func _sell(f: Furniture) -> void:
	Sfx.play("demolish")
	earn(f.price)
	if f == _held:
		_held = null
		_footprint.visible = false
	f.queue_free()


func _rotate_held(dir: int) -> void:
	if _held == null:
		return
	_held_rot = posmod(_held_rot + dir, 4)
	lot.position_furniture(_held, _held_cell, _held_rot)
	_update_footprint()


## Which side of tile `c` a hanging object goes on: the nearest one with a wall.
func _nearest_wall_side(c: Vector2i, pt: Vector3) -> int:
	var local := Vector2(pt.x - c.x, pt.z - c.y)
	var dist := [local.y, local.x, 1.0 - local.y, 1.0 - local.x]
	var best := -1
	for r in 4:
		if lot.walls.has(Lot.wall_edge_for(c, r)) and (best < 0 or dist[r] < dist[best]):
			best = r
	return best if best >= 0 else 0


## Hangs an item from a Sim's inventory (no charge); `placed` reports it.
func start_place_object(f: Furniture) -> void:
	set_tool(Tool.PLACE)
	f.set_meta("free", true)
	lot.add_child(f)
	_pick_up(f, true)


func _can_drop() -> bool:
	if _held.wall_mounted:
		return lot.can_hang(_held, _held_cell, _held_rot)
	var avoid: Array[Vector2i] = []
	for m in household:
		avoid.append(lot.world_to_cell(m.global_position))
	return lot.can_place(_held, _held_cell, _held_rot, avoid)


func _refresh_overlays(p: Variant) -> void:
	_edge_marker.visible = false
	_wall_preview.visible = false
	if not active:
		return
	if _held != null and p != null and _held.wall_mounted:
		var pt: Vector3 = p
		_held_cell = lot.world_to_cell(pt)
		_held_rot = _nearest_wall_side(_held_cell, pt)
		lot.position_furniture(_held, _held_cell, _held_rot)
		_footprint.visible = false
	elif _held != null and p != null:
		var pt: Vector3 = p
		var fp := _held.footprint if _held_rot % 2 == 0 else Vector2i(_held.footprint.y, _held.footprint.x)
		_held_cell = Vector2i(floori(pt.x - fp.x * 0.5 + 0.5), floori(pt.z - fp.y * 0.5 + 0.5))
		lot.position_furniture(_held, _held_cell, _held_rot)
		_update_footprint()
	if p == null:
		return
	var at: Vector3 = p
	match tool:
		Tool.WALL, Tool.FENCE:
			if _wall_start != null:
				_wall_end = _vertex(at)
				var run := Lot.wall_run(_wall_start, _wall_end)
				if not run.is_empty():
					var a := lot.edge_center(run[0])
					var b := lot.edge_center(run[run.size() - 1])
					var horizontal := run[0].z == 0
					var length := run.size() * Lot.CELL
					var h := Lot.FENCE_HEIGHT if tool == Tool.FENCE else Lot.WALL_HEIGHT
					_wall_preview.position = (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
					_wall_preview.scale = Vector3(length + Lot.WALL_THICKNESS, h, Lot.WALL_THICKNESS) if horizontal \
						else Vector3(Lot.WALL_THICKNESS, h, length + Lot.WALL_THICKNESS)
					_wall_preview.visible = true
			else:
				_show_vertex(_vertex(at))
		Tool.FLOOR, Tool.POOL, Tool.ROOM, Tool.TERRAIN:
			if _floor_start != null:
				_floor_end = lot.world_to_cell(at)
				var r := _floor_rect()
				_wall_preview.position = Vector3(r.position.x + r.size.x * 0.5, 0.03, r.position.y + r.size.y * 0.5)
				_wall_preview.scale = Vector3(r.size.x, 0.04, r.size.y)
				_wall_preview.visible = true
			else:
				var c := lot.world_to_cell(at)
				_edge_marker.position = Vector3(c.x + 0.5, 0.03, c.y + 0.5)
				_edge_marker.scale = Vector3(0.95, 0.04, 0.95)
				_edge_marker.visible = true
		Tool.DOOR, Tool.DELETE, Tool.WINDOW, Tool.PAINT:
			var e := lot.edge_near(at)
			if lot.walls.has(e) or (lot.fences.has(e) and tool in [Tool.DOOR, Tool.DELETE]):
				var c := lot.edge_center(e)
				_edge_marker.position = c + Vector3(0, 0.05, 0)
				_edge_marker.scale = Vector3(1.0, 0.08, 0.3) if e.z == 0 else Vector3(0.3, 0.08, 1.0)
				_edge_marker.visible = true


func _update_footprint() -> void:
	var fp := _held.rotated_footprint()
	_footprint.position = Vector3(_held_cell.x + fp.x * 0.5, 0.03, _held_cell.y + fp.y * 0.5)
	_footprint.scale = Vector3(fp.x - 0.05, 0.02, fp.y - 0.05)
	_footprint_mat.albedo_color = Color(0.3, 0.9, 0.4, 0.45) if _can_drop() else Color(0.95, 0.25, 0.2, 0.45)
	_footprint.visible = true


func _show_vertex(v: Vector2i) -> void:
	_edge_marker.position = Vector3(v.x, 0.05, v.y)
	_edge_marker.scale = Vector3(0.25, 0.1, 0.25)
	_edge_marker.visible = true


func _vertex(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(p.x), 0, lot.size.x), clampi(roundi(p.z), 0, lot.size.y))


func _spend(amount: int) -> bool:
	if amount > funds:
		notice.emit("Not enough funds.")
		return false
	funds -= amount
	funds_changed.emit(funds)
	return true


func earn(amount: int) -> void:
	funds += amount
	funds_changed.emit(funds)


func _ground(screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	return Plane(Vector3.UP, lot.base_y()).intersects_ray(origin, camera.project_ray_normal(screen_pos))


func _furniture_under(screen_pos: Vector2) -> Furniture:
	var origin := camera.project_ray_origin(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_pos) * 500.0)
	var hit := lot.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit.collider as Object).has_meta("furniture"):
		return null
	return (hit.collider as Object).get_meta("furniture") as Furniture


func _overlay_box(color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	_overlays.add_child(m)
	return m


## Builds on another level from now on.
func set_lot(l: Lot) -> void:
	_cancel_held()
	_wall_start = null
	_floor_start = null
	lot = l
	_overlays.position.y = l.base_y()
	_refresh_overlays(null)


func _set_visible(v: bool) -> void:
	_ui.visible = v
	if not v:
		_footprint.visible = false
		_wall_preview.visible = false
		_edge_marker.visible = false


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	# Tools along the top centre.
	var tools_pill := PanelContainer.new()
	tools_pill.add_theme_stylebox_override("panel", UiTheme.panel_style(28, 6))
	tools_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tools_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tools_pill.position = Vector2(-320, 14)
	root.add_child(tools_pill)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	tools_pill.add_child(tools)
	var tool_defs := [
		[Tool.MOVE, "move", "Move objects: click to pick up, click to put down. R rotates, Delete sells."],
		[Tool.WALL, "wall", "Wall tool: drag along the grid (§%d per segment)" % Catalog.WALL_PRICE],
		[Tool.FENCE, "fence", "Fences & half walls: pick a style below, then drag along the grid"],
		[Tool.ROOM, "room", "Room tool: drag a rectangle to build four walls at once (§%d per segment)" % Catalog.WALL_PRICE],
		[Tool.ROOF, "roof", "Roof & Foundation: choose the roof shape and colour, or raise the house (§%d)" % Lot.ROOF_PRICE],
		[Tool.DOOR, "door", "Door tool: click a wall to add a door (§%d), or a fence for a gate (§%d)" % [Catalog.DOOR_PRICE, Catalog.GATE_PRICE]],
		[Tool.WINDOW, "window", "Window tool: click a wall to add a window (§%d)" % Finishes.WINDOW_PRICE],
		[Tool.PAINT, "paint", "Wall paint: pick a finish below, click a wall (Shift: every wall)"],
		[Tool.FLOOR, "floor", "Floor tool: pick a finish below, drag over tiles"],
		[Tool.TERRAIN, "terrain", "Terrain paint: pick a ground finish below, drag over the yard"],
		[Tool.POOL, "pool", "Pool tool: drag out a swimming pool (§60 per tile)"],
		[Tool.DELETE, "sell", "Sledgehammer: click an object, wall or fence to sell it"],
	]
	for d in tool_defs:
		var b := IconButton.make(d[1], 46, d[2])
		b.toggle_mode = true
		b.pressed.connect(set_tool.bind(d[0]))
		tools.add_child(b)
		_tool_buttons[d[0]] = b
	var traits_btn := IconButton.make("lot_traits", 46, "Lot Traits: give this home up to %d traits" % LotTraits.MAX)
	traits_btn.pressed.connect(open_lot_traits)
	tools.add_child(traits_btn)
	_ui_root = root

	# Catalogue along the bottom: sections on the left, object tiles to the right.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(14, 10))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(240, 0)
	row.add_child(left)
	var title := UiTheme.title(Label.new(), 18)
	title.text = "Buy"
	left.add_child(title)
	var cats := GridContainer.new()
	cats.columns = 2
	cats.add_theme_constant_override("h_separation", 4)
	cats.add_theme_constant_override("v_separation", 4)
	left.add_child(cats)
	for c in Catalog.CATEGORIES:
		var b := Button.new()
		b.text = c[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(118, 0)
		b.pressed.connect(_show_category.bind(c[0]))
		cats.add_child(b)
		_category_buttons[c[0]] = b
	_funds_label = UiTheme.title(Label.new(), 17)
	_funds_label.add_theme_color_override("font_color", UiTheme.GREEN_DARK)
	left.add_child(_funds_label)
	funds_changed.connect(func(f: int): _funds_label.text = Hud.money(f))
	_funds_label.text = Hud.money(funds)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	# One row of catalogue cards that scrolls sideways (mouse wheel works too).
	_tiles_scroll = ScrollContainer.new()
	_tiles_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tiles_scroll.custom_minimum_size = Vector2(0, 146)
	_tiles_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_tiles_scroll)
	_tiles_box = HBoxContainer.new()
	_tiles_box.add_theme_constant_override("separation", 8)
	_tiles_scroll.add_child(_tiles_box)
	for kind in Catalog.KINDS:
		_tiles[kind] = _make_tile(kind)
		_tiles_box.add_child(_tiles[kind])
	_swatch_row = HBoxContainer.new()
	_swatch_row.add_theme_constant_override("separation", 6)
	_swatch_row.visible = false
	right.add_child(_swatch_row)
	right.move_child(_swatch_row, 0)
	_swatch_box = HFlowContainer.new()
	_swatch_box.add_theme_constant_override("h_separation", 8)
	_swatch_box.add_theme_constant_override("v_separation", 8)
	_swatch_box.visible = false
	right.add_child(_swatch_box)
	var help := Label.new()
	help.text = "Click an item to place it.  Right-click / Esc: cancel   R or , .: rotate   Delete: sell held object   F1: back to Live"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	right.add_child(help)
	_show_category("all")

	_thumbs = Thumbnails.new()
	add_child(_thumbs)
	_thumbs.ready_for.connect(func(kind: String, tex: Texture2D):
		(_tiles[kind].get_meta("image") as TextureRect).texture = tex)
	_thumbs.render_all.call_deferred(Catalog.KINDS)


## A catalogue card: thumbnail, name and price; hover shows details.
func _make_tile(kind: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 128)
	b.tooltip_text = Catalog.describe(kind)
	var normal := UiTheme.pill(Color.WHITE, UiTheme.PANEL_EDGE, 10)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", UiTheme.pill(UiTheme.HOVER, UiTheme.ACCENT, 10))
	b.add_theme_stylebox_override("pressed", UiTheme.pill(UiTheme.HOVER, UiTheme.GREEN, 10))
	b.pressed.connect(start_place.bind(kind))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 4
	v.offset_bottom = -4
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(80, 80)
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	var name_label := Label.new()
	name_label.text = Catalog.INFO[kind][0]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_label)
	var price := Label.new()
	price.text = "§ %d" % Catalog.INFO[kind][1]
	price.add_theme_font_size_override("font_size", 12)
	price.add_theme_color_override("font_color", UiTheme.GREEN_DARK)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(price)
	b.set_meta("image", img)
	return b


func _show_category(cat: String) -> void:
	for c in _category_buttons:
		(_category_buttons[c] as Button).button_pressed = c == cat
	for kind in _tiles:
		(_tiles[kind] as Control).visible = cat == "all" or Catalog.CATEGORY_OF[kind] == cat

## With the paint or floor tool, the catalogue shows finishes instead of objects.
func _show_swatches() -> void:
	if _swatch_box == null:
		return
	var painting := tool == Tool.PAINT or tool == Tool.FLOOR or tool == Tool.ROOF or tool == Tool.TERRAIN or tool == Tool.FENCE
	_tiles_scroll.visible = not painting
	_swatch_box.visible = painting
	for c in _swatch_box.get_children():
		c.queue_free()
	if not painting:
		return
	if tool == Tool.ROOF:
		_show_roof_swatches()
		return
	if tool == Tool.FENCE:
		for i in Lot.FENCE_STYLES.size():
			var fs: Array = Lot.FENCE_STYLES[i]
			var b := _roof_button(fs[0], fence_style == i, fs[1])
			b.tooltip_text = "%s\n§ %d per segment" % [fs[0], fs[2]]
			b.pressed.connect(func():
				fence_style = i
				_show_swatches())
			_swatch_box.add_child(b)
		return
	var list: Array = Finishes.WALLS if tool == Tool.PAINT else (Finishes.TERRAIN if tool == Tool.TERRAIN else Finishes.FLOORS)
	var current := wall_style if tool == Tool.PAINT else (terrain_style if tool == Tool.TERRAIN else floor_style)
	for i in list.size():
		var f: Array = list[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112, 96)
		b.tooltip_text = "%s\n§ %d per %s" % [f[0], f[3], "wall" if tool == Tool.PAINT else "tile"]
		var st := UiTheme.pill(Color.WHITE, UiTheme.GREEN if i == current else UiTheme.PANEL_EDGE, 10)
		st.set_border_width_all(3 if i == current else 1)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", UiTheme.pill(UiTheme.HOVER, UiTheme.ACCENT, 10))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 8
		v.offset_right = -8
		v.offset_top = 8
		v.offset_bottom = -6
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var chip := Panel.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = f[1]
		cs.set_corner_radius_all(6)
		chip.add_theme_stylebox_override("panel", cs)
		chip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(chip)
		var l := Label.new()
		l.text = f[0]
		l.add_theme_font_size_override("font_size", 11)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		b.pressed.connect(func():
			if tool == Tool.PAINT:
				wall_style = i
			elif tool == Tool.TERRAIN:
				terrain_style = i
			else:
				floor_style = i
			_show_swatches())
		_swatch_box.add_child(b)


## Roof tool: a button per shape, then a chip per colour, then the foundation.
func _show_roof_swatches() -> void:
	_show_roof_buttons()
	for raised in [false, true]:
		var b := _roof_button("Foundation" if raised else "No Foundation", (lot.foundation > 0.0) == raised, Color(0.66, 0.62, 0.56) if raised else Color(0.45, 0.68, 0.38))
		b.tooltip_text = "Raise the house on a stone foundation with steps (§%d)" % Lot.FOUNDATION_PRICE if raised else "Rooms sit on the ground"
		b.pressed.connect(func():
			if (lot.foundation > 0.0) == raised:
				return
			if raised and not _spend(Lot.FOUNDATION_PRICE):
				return
			foundation_changed.emit(Lot.FOUNDATION_HEIGHT if raised else 0.0)
			_show_swatches())
		_swatch_box.add_child(b)


func _show_roof_buttons() -> void:
	for i in Lot.ROOF_STYLE_NAMES.size():
		var b := _roof_button(Lot.ROOF_STYLE_NAMES[i], lot.roof_style == i, Color(0.92, 0.94, 0.98))
		var shape := RoofShape.new()
		shape.style = i
		shape.color = Lot.ROOF_COLORS[lot.roof_color][1]
		shape.set_anchors_preset(Control.PRESET_FULL_RECT)
		shape.offset_bottom = -22
		shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(shape)
		b.pressed.connect(func(): set_roof(i, lot.roof_color))
		_swatch_box.add_child(b)
	for i in Lot.ROOF_COLORS.size():
		var b := _roof_button(Lot.ROOF_COLORS[i][0], lot.roof_color == i, Lot.ROOF_COLORS[i][1])
		b.pressed.connect(func(): set_roof(lot.roof_style, i))
		_swatch_box.add_child(b)


func _roof_button(text: String, current: bool, chip_color: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 96)
	b.tooltip_text = "%s\n§ %d" % [text, Lot.ROOF_PRICE]
	var st := UiTheme.pill(Color.WHITE, UiTheme.GREEN if current else UiTheme.PANEL_EDGE, 10)
	st.set_border_width_all(3 if current else 1)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", UiTheme.pill(UiTheme.HOVER, UiTheme.ACCENT, 10))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var chip := Panel.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = chip_color
	cs.set_corner_radius_all(6)
	chip.add_theme_stylebox_override("panel", cs)
	chip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(chip)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	return b


## A little house silhouette with the given roof shape, for the Roof tool.
class RoofShape:
	extends Control
	var style := 0
	var color := Color.BROWN

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 8)
		var w := 30.0
		draw_rect(Rect2(c + Vector2(-w * 0.8, -6), Vector2(w * 1.6, 22)), Color(0.97, 0.95, 0.9))
		draw_rect(Rect2(c + Vector2(-5, 4), Vector2(10, 12)), Color(0.55, 0.38, 0.25))
		match style:
			Lot.RoofStyle.GABLE:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-w, -6), c + Vector2(0, -30), c + Vector2(w, -6)]), color)
			Lot.RoofStyle.HIP:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-w, -6), c + Vector2(-w * 0.35, -26), c + Vector2(w * 0.35, -26), c + Vector2(w, -6)]), color)
			Lot.RoofStyle.FLAT:
				draw_rect(Rect2(c + Vector2(-w * 0.9, -12), Vector2(w * 1.8, 6)), color.lerp(Color(0.75, 0.75, 0.75), 0.55))


var _ui_root: Control
var _traits_panel: PanelContainer

## The Lot Traits picker: toggle up to three, free of charge.
func open_lot_traits() -> void:
	if _traits_panel != null:
		_traits_panel.queue_free()
		_traits_panel = null
		return
	_traits_panel = PanelContainer.new()
	_traits_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(18, 14))
	_traits_panel.custom_minimum_size = Vector2(560, 0)
	_ui_root.add_child(_traits_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_traits_panel.add_child(v)
	var t := UiTheme.title(Label.new(), 22)
	t.text = "Lot Traits"
	v.add_child(t)
	var sub := Label.new()
	sub.text = "Pick up to %d. They shape life in this home." % LotTraits.MAX
	sub.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	v.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for id in LotTraits.ORDER:
		var info: Dictionary = LotTraits.INFO[id]
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = lot.lot_traits.has(id)
		b.text = info["label"]
		b.tooltip_text = info["description"]
		b.custom_minimum_size = Vector2(170, 44)
		b.add_theme_stylebox_override("pressed", UiTheme.pill(UiTheme.GREEN, UiTheme.GREEN_DARK, 22))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.toggled.connect(func(on: bool):
			var next: Array = lot.lot_traits.duplicate()
			if on and not next.has(id):
				if next.size() >= LotTraits.MAX:
					notice.emit("A lot can have up to %d traits. Remove one first." % LotTraits.MAX)
					b.set_pressed_no_signal(false)
					return
				next.append(id)
			elif not on:
				next.erase(id)
			lot_traits_changed.emit(next))
		grid.add_child(b)
	var close := Button.new()
	close.text = "Done"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(open_lot_traits)
	v.add_child(close)
	await get_tree().process_frame
	if _traits_panel != null:
		_traits_panel.position = (_ui_root.size - _traits_panel.size) * 0.5
